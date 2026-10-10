class_name TombFloors
## A dungeon's floors (design 9 Oct §FM.6, §FF.1; data/descent.json floors):
## floor one is the tomb as built (TombKit), the hearth room its root;
## floor two lies below it, reached by a stair down, built by the same
## generator in the same stone (floors.same_stone, §EX.1). Its stair up is
## floor one's stair down: one flight, dropping floors.drop_m.
##
##   the stair down  leaves a room near the far end of the spine (the one
##                   before the heart first, then back along it; failing
##                   those the heart, then the side ways' rooms, deepest
##                   first; never the hearth room), through a door centred
##                   in one of its side walls (§EX.2's doors), a flight
##                   straight on down. Gated by the fork (Fork,
##                   descent.json fork: a stone seal in its mouth until
##                   every torch on floor one burns). Never spine: §EX.5's
##                   way out stays the only spine past the heart.
##   floor two       grown from the room at the foot of that flight as
##                   floor one is from the hearth room (TombKit._branch):
##                   ways out of it through its other walls (opening
##                   exits_min..max less the stair's), the first the
##                   longest (plan.spine.rooms rooms), the others at most
##                   side_share of its rooms; rooms of the kit's kinds,
##                   each with its wall sconces (§EX.4), corridors with
##                   theirs, airways, its own residents in its niches and
##                   coffins (§FE), and no hearth (§EX.4: one per dungeon)
##                   and no heart (the heart is floor one's, with the way
##                   out past it).
##
## Pure: the layout in, the layout out. TombKit calls grow() once floor
## one's side ways are laid, so the room the stair leaves places its
## sconces, niches and coffins round its new door like any other; and
## fill() at the very end, floor two's holders, airways and residents with
## floor two's own dice, so nothing else on floor one changes (its lights,
## airways, residents, the boss's lair and tunnels are all placed on floor
## one only). Nothing on floor two overlaps anything on floor one in plan
## (TombKit's free test over every piece): one floor grid holds both
## levels (TombNav), and a floor-two flue rises past floor one, not
## through it.
##
## Each piece carries "floor" (0 floor one, 1 floor two; a piece without
## one is floor one's). lay.floors: [{"root" (the piece it grows from),
## "pieces" (ids), "branches" (floor two's ways, ids each; floor one's are
## lay.branches)}...]; lay.descent: {"host" (the floor-one room the stair
## leaves), "door" (the door into the flight: the stair's mouth, where the
## seal stands), "stair", "foot" (floor two's first room), "drop" (m),
## "top" (Vector3, the stair's mouth on floor one: the door's middle on its
## floor), "bottom" (the foot of the flight on floor two), "down" (Vector3,
## the way down the flight)}. No lay.descent when the dungeon has one
## floor (floors.count 1) or no room on floor one has space for the stair.

static var D: Dictionary = Tuning.table("descent")
static var FLOORS: Dictionary = D.get("floors", {})
## The boss's floor (design §FM.10 call 4, not answered): it stays on
## floor one as built, its lair hole where it was (BossGround), until Mike
## says whether the base layer is its home.
const BOSS_FLOOR := 0
## Ways on floor two count from here in their pieces' "branch" (floor
## one's are 0, the spine, and 1 up, its side ways).
const BRANCH_BASE := 100


## How many floors a dungeon has (descent.json floors.count: two for now;
## a third is not built, so at most two).
static func count() -> int:
	return clampi(int(FLOORS.get("count", 2)), 1, 2)


## The floors laid in `lay` ([0], or [0, 1] with floor two).
static func floors_of(lay: Dictionary) -> Array:
	var fl: Array = lay.get("floors", [])
	var out: Array = []
	for i in maxi(fl.size(), 1):
		out.append(i)
	return out


## The floor piece `pid` is on (0 floor one; a piece without "floor" is
## floor one's, as is anything off the layout).
static func floor_of(lay: Dictionary, pid: int) -> int:
	var pieces: Array = lay.get("pieces", [])
	if pid < 0 or pid >= pieces.size():
		return 0
	return int((pieces[pid] as Dictionary).get("floor", 0))


## The floor of lay.holders entry `h`.
static func holder_floor(lay: Dictionary, h: Dictionary) -> int:
	return floor_of(lay, int(h.get("piece", -1)))


## The floor `pos` (scene) stands on, or -1 off every piece.
static func floor_at(lay: Dictionary, pos: Vector3) -> int:
	var pid := TombKit.piece_at(lay, pos)
	return floor_of(lay, pid) if pid >= 0 else -1


## Indices into lay.holders of floor `f`'s holders.
static func holders_on(lay: Dictionary, f: int) -> Array:
	var out: Array = []
	var hs: Array = lay.get("holders", [])
	for i in hs.size():
		if holder_floor(lay, hs[i]) == f:
			out.append(i)
	return out


## Is every torch on floor `f` relit (crawler.json cleared.when
## every_light_on_floor_relit, §FF.2; the fork's test too, descent.json
## fork.when)? `fires`' holders stand in lay.holders' order. A floor with
## no torch at all is never lit.
static func floor_lit(fires: CrawlerFires, lay: Dictionary, f: int) -> bool:
	if fires == null:
		return false
	var hs: Array = lay.get("holders", [])
	var any := false
	for i in mini(fires.holders.size(), hs.size()):
		if holder_floor(lay, hs[i]) != f:
			continue
		any = true
		if not FireStore.is_lit(fires.holders[i]):
			return false
	return any


## How many torches on floor `f` are lit, and how many it has: Vector2i.
static func lit_on(fires: CrawlerFires, lay: Dictionary, f: int) -> Vector2i:
	var hs: Array = lay.get("holders", [])
	var lit := 0
	var all := 0
	if fires == null:
		return Vector2i.ZERO
	for i in mini(fires.holders.size(), hs.size()):
		if holder_floor(lay, hs[i]) != f:
			continue
		all += 1
		if FireStore.is_lit(fires.holders[i]):
			lit += 1
	return Vector2i(lit, all)


## How many wall sconces room `pc` should have (design §EX.4, crawler.json
## room_torches): the heart `heart`; else `small` with its long walls up to
## small_room_max_m, `large` longer, and `pillared` on pillars.
static func sconces_wanted(lay: Dictionary, pc: Dictionary) -> int:
	var rt: Dictionary = TombKit.RT
	# A big room's are its archetype's (design §FM.6's room pool, RoomPool).
	if pc.has("big_room"):
		return RoomPool.sconces_wanted(pc)
	if str(pc.get("room_kind", "")) == "heart":
		return int(rt.get("heart", 4))
	var long := maxf(float(pc.len), 2.0 * float(pc.half))
	var n := int(rt.get("small", 2)) if long <= float(rt.get("small_room_max_m", 8.0)) + 0.001 else int(rt.get("large", 4))
	return maxi(n, int(rt.get("pillared", 4))) if TombBuild.on_pillars(lay, pc) else n


# --- Laying it out ----------------------------------------------------------------

## The stair down and floor two (TombKit.layout, once floor one's side ways
## are laid): floor two's own dice, so floor one's are as they were.
static func grow(lay: Dictionary) -> void:
	lay["floors"] = [{"root": 0, "pieces": [], "branches": []}]
	var first := (lay.pieces as Array).size()
	if count() >= 2 and lay.has("heart"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(lay.seed), "floor two"])
		for host in _hosts(lay):
			for side in _walls(lay, host, rng):
				if _descend(lay, rng, host, str(side)):
					break
			if lay.has("descent"):
				break
		if lay.has("descent"):
			var foot: Dictionary = lay.pieces[int(lay.descent.foot)]
			var branches := _grow_ways(lay, rng, foot)
			lay.floors.append({"root": int(foot.id), "pieces": [], "branches": branches})
			for i in range(first, (lay.pieces as Array).size()):
				(lay.pieces[i] as Dictionary)["floor"] = 1
		else:
			push_warning("TombFloors: tomb %d has no room on floor one with space for the stair down: one floor" % int(lay.seed))
	for pc in lay.pieces:
		((lay.floors[int(pc.get("floor", 0))] as Dictionary).pieces as Array).append(int(pc.id))


## Floor two's own things (TombKit.layout, at the very end): its wall
## sconces and corridor sconces, every fire's vent again (floor two's
## sconces' flues with the rest), its airways and its residents, with its
## own dice.
static func fill(lay: Dictionary) -> void:
	if (lay.get("floors", []) as Array).size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "floor two", "fill"])
	TombKit._place_holders(lay, rng, 1)
	TombKit._place_vents(lay)
	TombKit._place_airways(lay, rng, 1)
	TombKit._place_residents(lay, 1)


## The floor-one rooms the stair down may leave, the likeliest first: the
## spine's rooms from the far end back (the one before the heart first,
## so the way down opens near the way up), then the heart, then the side
## ways' rooms, deepest first. Never the hearth room, nor a big room (the
## room pool's, RoomPool: its doors are its archetype's).
static func _hosts(lay: Dictionary) -> Array:
	var out: Array = []
	var spine: Array = lay.get("spine", [])
	for i in range(spine.size() - 1, -1, -1):
		var pc: Dictionary = lay.pieces[int(spine[i])]
		if str(pc.kind) == "room" and not str(pc.get("room_kind", "")) in ["hearth", "heart"] and not pc.has("big_room"):
			out.append(pc)
	if lay.has("heart"):
		out.append(lay.pieces[int(lay.heart)])
	var side: Array = []
	var branches: Array = lay.get("branches", [])
	for bi in range(1, branches.size()):
		for id in branches[bi]:
			var pc: Dictionary = lay.pieces[int(id)]
			if str(pc.kind) == "room" and not pc.has("big_room"):
				side.append(pc)
	side.sort_custom(func(a, b): return int(a.get("depth", 0)) > int(b.get("depth", 0)) or (int(a.get("depth", 0)) == int(b.get("depth", 0)) and int(a.id) < int(b.id)))
	out.append_array(side)
	return out


## Room `pc`'s walls with no door, its side walls first (in a seeded
## order), then its end and start walls.
static func _walls(lay: Dictionary, pc: Dictionary, rng: RandomNumberGenerator) -> Array:
	var used := {}
	for di in pc.doors:
		used[str(TombKit.door_side(pc, lay.doors[di])[0])] = true
	var sides: Array = ["left", "right"]
	if rng.randf() < 0.5:
		sides.reverse()
	sides.append_array(["end", "start"])
	var out: Array = []
	for s in sides:
		if not used.has(s):
			out.append(s)
	return out


## The stair down from room `host` through its wall `side` (a door centred
## on it), a flight straight on dropping floors.drop_m at the kit's stair
## slope in whole modules, and floor two's first room at its foot, sized
## like any room (a module less on a second and third try). Only where both
## fit clear of everything laid, and the room the stair leaves still has
## its wall sconces by the rule round its new door (§EX.4). True if laid.
static func _descend(lay: Dictionary, rng: RandomNumberGenerator, host: Dictionary, side: String) -> bool:
	var K: Dictionary = TombKit.K
	var mod := float(lay.module)
	var th := str(lay.theme)
	var drop := maxf(float(FLOORS.get("drop_m", 4.8)), 0.5)
	var run := ceilf(drop / maxf(float(K.get("stair_slope", 0.6)), 0.1) / mod - 1e-4) * mod
	var ch := TombKit.height_of(th, "corridor", float(K.get("corridor_h_m", 2.6)))
	var rh := TombKit.height_of(th, "room", float(K.get("room_h_m", 3.2)))
	var chalf := float(K.get("corridor_half_m", 1.0))
	var rspan := TombKit.module_span(K.get("room_m", []), 6.0, 11.0, mod)
	var wp := TombKit.wall_point(host, side, 0.0)
	var n: Vector2 = wp[1]
	var start: Vector2 = (wp[0] as Vector2) + n * (TombKit.WALL * 0.5)
	var y := float(host.y1)
	var stair := Delves.piece("stair", start, n, run, chalf, y, y - drop, ch)
	if not TombKit._free(lay, TombKit.outer(stair), [int(host.id)]):
		return false
	for attempt in 3:
		var nl := maxi(rng.randi_range(rspan.x, rspan.y) - attempt, rspan.x)
		var nw := maxi(rng.randi_range(rspan.x, rspan.y) - attempt, rspan.x)
		var room := Delves.piece("room", start + n * (run + TombKit.WALL), n, nl * mod, nw * mod * 0.5, y - drop, y - drop, rh)
		# The room touches only its stair (not added yet).
		if not TombKit._free(lay, TombKit.outer(room), []):
			continue
		var n_pieces := (lay.pieces as Array).size()
		var n_doors := (lay.doors as Array).size()
		var host_doors := (host.doors as Array).size()
		TombKit._add(lay, stair)
		TombKit._add(lay, room)
		TombKit._door(lay, wp[0], n, chalf - 0.1, y, minf(ch, float(host.h)) - 0.2, host, stair)
		TombKit._door(lay, start + n * (run + TombKit.WALL * 0.5), n, chalf - 0.1, y - drop, ch - 0.2, stair, room)
		# Its wall sconces round the new door (the generator's own rule): else
		# not here.
		if TombKit._room_sconces(lay, host).size() != sconces_wanted(lay, host):
			(lay.pieces as Array).resize(n_pieces)
			(lay.doors as Array).resize(n_doors)
			(host.doors as Array).resize(host_doors)
			return false
		for pc in [stair, room]:
			pc["branch"] = BRANCH_BASE
			pc["spine"] = false
			pc["depth"] = int(host.get("depth", 0)) + 1
		stair["descent"] = true
		room["room_kind"] = TombKit._room_kind(rng, float(room.half))
		room["branch_of"] = int(host.id)
		room["foot"] = true
		var mouth: Vector2 = wp[0]
		var bottom: Vector2 = start + n * run
		lay["descent"] = {"host": int(host.id), "door": n_doors, "stair": int(stair.id), "foot": int(room.id), "drop": drop,
			"top": Vector3(mouth.x, y, mouth.y), "bottom": Vector3(bottom.x, y - drop, bottom.y), "down": Vector3(n.x, 0.0, n.y)}
		return true
	return false


## Floor two's ways out of its first room `foot` (TombKit._branch, the
## generator floor one is grown by), through its walls but the one the
## stair comes in at: as many as the hearth room has less the stair's
## (opening exits_min..max), the first plan.spine.rooms rooms long (turning
## by kit.turn_chance like a side way: only floor one's spine runs straight
## on to the way out), the others at most plan.side_branches.side_share of
## its rooms each. Their ids, each way's (lay.branches stays floor one's).
static func _grow_ways(lay: Dictionary, rng: RandomNumberGenerator, foot: Dictionary) -> Array:
	var OPEN: Dictionary = TombKit.OPEN
	var PLAN: Dictionary = TombKit.PLAN
	var K: Dictionary = TombKit.K
	var sides: Array = ["end", "left", "right"]
	TombKit._shuffle(rng, sides)
	var want := maxi(TombKit._irange(rng, [int(OPEN.get("exits_min", 3)), int(OPEN.get("exits_max", 4))], 3, 4) - 1, 1)
	var main_rooms := maxi(TombKit._irange(rng, (PLAN.get("spine", {}) as Dictionary).get("rooms", [4, 5]), 4, 5), 1)
	var share := float((PLAN.get("side_branches", {}) as Dictionary).get("side_share", 0.6))
	var out: Array = []
	var main_n := 0
	for s in sides:
		if out.size() >= want:
			break
		var n := main_rooms
		if not out.is_empty():
			n = mini(TombKit._irange(rng, K.get("branch_rooms", [2, 3]), 2, 3), maxi(floori(share * main_n + 1e-4), 1))
		var before := (lay.branches as Array).size()
		var rooms := TombKit._branch(lay, rng, foot, str(s), n, BRANCH_BASE + 1 + out.size())
		if (lay.branches as Array).size() > before:
			out.append((lay.branches as Array).pop_back())
		if out.size() == 1 and main_n == 0:
			main_n = rooms.size()
	return out

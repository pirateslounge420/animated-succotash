class_name TombKit
## The sarcophagus tombs' layout (design 6 Oct §ET.3, §ET.5; §CJ.8:
## "generated, never hand-placed: assembled from the seed out of a kit of
## rooms"; data/crawler.json kit, plan, exit, holders, airways). Pure: the
## seed in, a dictionary out (TombBuild draws it, CrawlerMain lights and
## fills it).
##
## The hearth room sits at the origin, its floor at y 0: the lit hearth in
## its middle, a smoke shaft over it (§ET.6), the bundle of unlit torches
## by it and the rescuer across it. Every piece is an axis-aligned straight
## lane (Delves.piece: `c` the middle of its start edge, `dir` along it,
## `len`, `half` wide each side, floor y0 to y1, `h` to the ceiling); walls
## stand outside the lanes, Delves.WALL thick, and two pieces meet at a
## door in the wall between them. Nothing overlaps: a piece that would is
## tried shorter or turned, and a branch that can't go on ends at its last
## room.
##
## The plan (design §EX.2, crawler.json plan; the builders' module and
## heights from the theme's style, masonry.json styles by style_by_theme):
##   the module   rooms' sides, corridors and flights are whole numbers of
##                the style's module_m (the tomb's 2 m, its corridor's
##                width), the hearth room's sides snapped to it too; the
##                ceilings take the style's heights_m
##   the spine    of the three or four ways out of the hearth room
##                (opening.exits_min..max), one is grown first and longest
##                (plan.spine.rooms rooms): straight on through every room,
##                its two doors facing, the main axis; its last room is the
##                heart (§CJ.3), and past the heart it carries on to the
##                way out (§EX.5, `exits`), so it is never a dead end
##   the way out  a door centred in the heart's far wall, a long flight
##                climbing exit.rise_m in the tomb's stone, a landing, and
##                the old way in: an opening in the landing's far wall with
##                daylight beyond it (WayOut draws the daylight)
##   side ways    the other ways: at most plan.side_branches.side_share of
##                the spine's rooms each, each a chain corridor, room,
##                corridor, room... straight on through facing doors, but
##                turning left or right at a room by kit.turn_chance (free-
##                form turning stays); each ends in a room, never in a bare
##                corridor (a corridor is only laid with its room)
##   doors        centred on the wall they cut (plan.doors), so where a
##                room's two doors face each other you look straight
##                through it down the next passage to the next light
##
## Rooms are of the kit's kinds (crypt, catacomb, ossuary, collapsed; a
## crypt wants CRYPT_MIN_HALF); the spine's last is the heart (§CJ.3). The
## hearth room's hearth is the tomb's one hearth (design §EX.4); every
## other room has cold wall sconces in facing pairs (crawler.json
## room_torches), and every corridor longer than holders.sconce_first_m a
## wall sconce every sconce_every_m; stairs none (fire_holders.skip). The
## airways (airways.per_air by the theme's air): ordinary slots in corridor
## walls, strong marked mouths in room walls, both clear of the sconces.
## The residents (design §FE,
## residents.json): the tomb's skeletons rest in the catacombs' wall
## niches and the crypts' coffins, more toward the heart, and the heart's
## own coffin holds one (Mike's frame 9); none in the hearth room, none by
## the way through the rooms.
##
## Gates (§ET.4: relight gates, scroll gates; none built yet) go only on
## the side ways and on shortcuts, never on the spine: nothing may ever
## stand between the wake spot and a way out (§EX.5, crawler.json
## exit.never_gated). Every spine piece and door is marked `spine` for
## whoever builds them.

static var K: Dictionary = Tuning.table("crawler").get("kit", {})
static var RESIDENTS: Dictionary = Tuning.table("residents")
static var HOLD: Dictionary = Tuning.table("crawler").get("holders", {})
static var RT: Dictionary = Tuning.table("crawler").get("room_torches", {})
static var AIR: Dictionary = Tuning.table("crawler").get("airways", {})
static var OPEN: Dictionary = Tuning.table("crawler").get("opening", {})
static var THEMES: Dictionary = Tuning.table("crawler").get("themes", {})
static var PLAN: Dictionary = Tuning.table("crawler").get("plan", {})
static var EXIT: Dictionary = Tuning.table("crawler").get("exit", {})

const WALL := Delves.WALL
## A door's half width (the corridors' lanes are a little wider).
const DOOR_HALF := 0.75
## Clearance kept between pieces' walls.
const GAP := 0.25
const SIDES := ["end", "left", "right", "start"]
## A crypt's rows of coffins down both long walls leave an aisle clear
## between their askew lids only in a room this wide (half, m: 4 modules).
const CRYPT_MIN_HALF := 4.0
## The heart (§CJ.3), laid from its far wall, where the way out leaves: the
## dead's box lying across the room HEART_BOX_M in (its lid shoved off
## toward the way out, a walk left clear behind it), their goods before it
## at HEART_GOODS_M.
const HEART_BOX_M := 3.0
const HEART_GOODS_M := 4.25
## Where the heart's dead lie: the stone box across the room, its middle
## HEART_BOX_M from the far wall, the way out's door behind it (§EX.5;
## TombBuild draws it there; the heart's sconces flank it, design §EX.4).
const HEART_DEAD_M := HEART_BOX_M
## A wall sconce's half width along its wall (CrawlerFires' bracket and
## cup): kept room_torches.clear_m from a door's edge, a corner and an
## airway's surround.
const SCONCE_HALF := 0.15
## An airway's surround's half width along its wall (TombBuild draws it):
## strong, ordinary.
const AIRWAY_HALF := [0.63, 0.43]
## How far a room's sconces step along their wall at a time to clear a
## door (m).
const SHIFT_M := 0.25



static func _irange(rng: RandomNumberGenerator, v, lo: int, hi: int) -> int:
	if v is Array and (v as Array).size() == 2:
		return rng.randi_range(int(v[0]), int(v[1]))
	return rng.randi_range(lo, hi)


## The theme's style: the ruin type's whole kit (design §EX.1;
## masonry.json styles, picked by style_by_theme, default for the rest).
static func style_of(theme: String) -> Dictionary:
	var m := Tuning.table("masonry")
	var by: Dictionary = m.get("style_by_theme", {})
	return (m.get("styles", {}) as Dictionary).get(str(by.get(theme, by.get("default", ""))), {})


## The builders' module for `theme` (design §EX.2: the style's module_m;
## 2 m, the tomb corridor's width, where a style names none).
static func module_of(theme: String) -> float:
	return maxf(float(style_of(theme).get("module_m", 2.0)), 0.5)


## A ceiling from the style's short list (heights_m: corridor, room,
## hearth_room), else the kit's own `fallback`.
static func height_of(theme: String, kind: String, fallback: float) -> float:
	return float((style_of(theme).get("heights_m", {}) as Dictionary).get(kind, fallback))


## `v` m as a whole number of modules `m` (at least one).
static func snap(v: float, m: float) -> float:
	return maxf(roundf(v / m), 1.0) * m


## The whole modules `m` that fit in the kit's range `r` ([min, max] m;
## `lo`..`hi` without one): Vector2i(least, most), at least one.
static func module_span(r, lo: float, hi: float, m: float) -> Vector2i:
	if r is Array and (r as Array).size() == 2:
		lo = float(r[0])
		hi = float(r[1])
	var n0 := maxi(1, ceili(lo / m - 1e-4))
	return Vector2i(n0, maxi(n0, floori(hi / m + 1e-4)))


## The tomb for `seed_value`: {"seed", "theme", "module" (m), "pieces"
## [piece...], "doors" [door...], "hearth" (Vector3), "wake" ([Vector3,
## yaw]), "bundle" (Vector3), "rescuer" ([Vector3, yaw]), "holders"
## [{"kind": "sconce", "pos", "normal", "piece", "room" (a room's wall
## torch, not a corridor's)}...],
## "airways" [{"strong", "pos", "normal", "piece"}...], "heart" (piece
## id), "hearth_ways" (the ways out of the hearth room), "spine" (its piece
## ids in order, the way out's stair and landing last), "branches" ([piece
## ids] per way, the spine first), "exits" [way out...], "residents" (_place_residents)}. A piece has
## "id", "doors", "depth" (rooms from the hearth room), "branch" (0 the
## spine, -1 the hearth room) and "spine". A door is {"p" (Vector2, on the
## wall's middle line), "n" (Vector2, through the wall from `a` to `b`),
## "half", "y" (its floor), "h" (its opening), "a", "b" (piece ids; -1 for
## b: out of the tomb, a way out's opening), "spine"}. A way out is {"door"
## (its opening), "heart", "stair", "landing" (piece ids), "p" (Vector3,
## the opening's middle on its floor and the wall's middle line), "n"
## (Vector3, out through it), "half", "h", "y", "rise", "leads_to"}.
static func layout(seed_value: int, theme := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var th := theme if theme != "" else str(OPEN.get("first_theme", "tomb"))
	var mod := module_of(th)
	var lay := {"seed": seed_value, "theme": th, "module": mod, "pieces": [], "doors": [], "holders": [], "airways": [],
		"hearth_ways": 0, "spine": [], "branches": [], "exits": []}
	var hr: Dictionary = K.get("hearth_room", {})
	var hl := snap(float(hr.get("len_m", 9.0)), mod)
	var hw := snap(float(hr.get("width_m", 9.0)), mod) * 0.5
	var hearth_room := _add(lay, Delves.piece("room", Vector2(0.0, -hl * 0.5), Vector2(0, 1), hl, hw, 0.0, 0.0, height_of(th, "hearth_room", float(hr.get("h_m", 3.6)))))
	hearth_room["room_kind"] = "hearth"
	hearth_room["depth"] = 0
	hearth_room["branch"] = -1
	hearth_room["spine"] = true
	lay["hearth"] = Vector3.ZERO
	# The ways: three or four walls, in a seeded order; the first is the
	# spine (§EX.2), grown first so it always runs its full length.
	var want := _irange(rng, [int(OPEN.get("exits_min", 3)), int(OPEN.get("exits_max", 4))], 3, 4)
	var sides: Array = SIDES.duplicate()
	_shuffle(rng, sides)
	var sp: Dictionary = PLAN.get("spine", {})
	var spine_rooms := maxi(_irange(rng, sp.get("rooms", [4, 5]), 4, 5), 1)
	var spine := _branch(lay, rng, hearth_room, str(sides[0]), spine_rooms, 0)
	if not spine.is_empty():
		lay.hearth_ways = 1
		var heart: Dictionary = spine[-1]
		heart["room_kind"] = "heart"
		lay["heart"] = int(heart.id)
		# Past the heart, on: the way out (§EX.5), before the side ways
		# claim the ground.
		_way_out(lay, heart)
	# The side ways, shorter (plan.side_branches.side_share of the spine's
	# rooms at most). Gates (§ET.4), when built, go on these and on
	# shortcuts only; the spine and the way out stay open (exit.never_gated).
	var cap := maxi(floori(float((PLAN.get("side_branches", {}) as Dictionary).get("side_share", 0.6)) * spine.size() + 1e-4), 1)
	for i in range(1, sides.size()):
		if int(lay.hearth_ways) >= want:
			break
		var n := mini(_irange(rng, K.get("branch_rooms", [2, 3]), 2, 3), cap)
		if not _branch(lay, rng, hearth_room, str(sides[i]), n, (lay.branches as Array).size()).is_empty():
			lay.hearth_ways = int(lay.hearth_ways) + 1
	_wake_and_bundle(lay, rng, hearth_room)
	_place_holders(lay, rng)
	_place_vents(lay)
	_place_airways(lay, rng)
	# What lives in its dark (design §FE): where the residents rest (its
	# own dice).
	_place_residents(lay)
	# The boss's lair (design §EY.1; BossGround.place_lair, its own dice
	# too): a hole in the floor of a side room off the main way, never in a
	# grave a resident sleeps in or by its lid.
	lay["lair"] = BossGround.place_lair(lay)
	return lay


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func _add(lay: Dictionary, pc: Dictionary) -> Dictionary:
	pc["id"] = (lay.pieces as Array).size()
	pc["doors"] = []
	(lay.pieces as Array).append(pc)
	return pc


## The point on wall `side` of piece `pc`, `off` along that wall from its
## middle, on the wall's middle line, and the way out through it.
static func wall_point(pc: Dictionary, side: String, off: float) -> Array:
	var c: Vector2 = pc.c
	var d: Vector2 = pc.dir
	var p := Delves.perp(d)
	var length := float(pc.len)
	var half := float(pc.half)
	match side:
		"end":
			return [c + d * (length + WALL * 0.5) + p * off, d]
		"start":
			return [c - d * (WALL * 0.5) + p * off, -d]
		"left":
			return [c + d * (length * 0.5 + off) + p * (half + WALL * 0.5), p]
	return [c + d * (length * 0.5 + off) - p * (half + WALL * 0.5), -p]


## A piece's footprint with its walls and the gap kept round them.
static func outer(pc: Dictionary) -> Rect2:
	return Delves.rect_of(pc, WALL + GAP)


static func _free(lay: Dictionary, r: Rect2, skip: Array) -> bool:
	for q in lay.pieces:
		if (q.id as int) in skip:
			continue
		if outer(q).grow(-0.01).intersects(r.grow(-0.01)):
			return false
	return true


## One way out of `from` through its wall `side` (design §EX.2): a
## corridor (sometimes a flight of stairs down, never the first), a room,
## a corridor, a room... `n_rooms` rooms, sized in whole modules, every
## door centred on the wall it cuts. Branch 0, the spine, goes straight on
## through every room (its two doors facing: the main axis; its last room,
## the heart, at least plan.spine.heart_min_m long). A side way goes
## straight on too (plan.facing) but turns left or right at a room by
## kit.turn_chance, and turns where straight on won't fit. A piece that
## won't fit is tried shorter, a module at a time (a corridor down to one,
## a room down to the kit's least); a way that can't go on ends at its last
## room, never in a bare corridor (a corridor is only laid with its room).
## The rooms laid, in order.
static func _branch(lay: Dictionary, rng: RandomNumberGenerator, from: Dictionary, side: String, n_rooms: int, branch: int) -> Array:
	var spine := branch == 0
	var mod := float(lay.module)
	var th := str(lay.theme)
	var cspan := module_span(K.get("corridor_m", []), 5.0, 11.0, mod)
	var rspan := module_span(K.get("room_m", []), 6.0, 11.0, mod)
	var ch := height_of(th, "corridor", float(K.get("corridor_h_m", 2.6)))
	var rh := height_of(th, "room", float(K.get("room_h_m", 3.2)))
	var chalf := float(K.get("corridor_half_m", 1.0))
	var drop := float(K.get("stair_drop_m", 2.4))
	# A flight is long enough for its drop at the kit's slope, in modules.
	var flight := ceilf(drop / maxf(float(K.get("stair_slope", 0.6)), 0.1) / mod - 1e-4) * mod
	var heart_n := ceili(float((PLAN.get("spine", {}) as Dictionary).get("heart_min_m", 8.0)) / mod - 1e-4)
	var facing := bool(PLAN.get("facing", true))
	var ids: Array = []
	(lay.branches as Array).append(ids)
	var rooms: Array = []
	var cur := from
	var ways: Array = [side]
	for k in n_rooms:
		var heart := spine and k == n_rooms - 1
		var placed := false
		for way in ways:
			for attempt in 9:
				# A module less every third try (corridor, then room).
				var less := attempt / 3
				var wp := wall_point(cur, str(way), 0.0)
				var n: Vector2 = wp[1]
				var start: Vector2 = (wp[0] as Vector2) + n * (WALL * 0.5)
				var y := float(cur.y1)
				var stair := k > 0 and rng.randf() < float(K.get("stair_chance", 0.3))
				var clen := maxi(rng.randi_range(cspan.x, cspan.y) - less, 1) * mod
				var dy := 0.0
				if stair:
					dy = drop
					clen = maxf(clen, flight)
				var cor := Delves.piece("stair" if stair else "corridor", start, n, clen, chalf, y, y - dy, ch)
				var nl := maxi(rng.randi_range(rspan.x, rspan.y) - less, rspan.x)
				var nw := maxi(rng.randi_range(rspan.x, rspan.y) - less, rspan.x)
				if heart:
					nl = maxi(nl, heart_n)
				var rc: Vector2 = start + n * (clen + WALL)
				var room := Delves.piece("room", rc, n, nl * mod, nw * mod * 0.5, y - dy, y - dy, rh)
				if not _free(lay, outer(cor), [cur.id]):
					continue
				# The room touches only its corridor (not added yet): not even
				# the room the corridor leaves.
				if not _free(lay, outer(room), []):
					continue
				for pc in [cor, room]:
					_add(lay, pc)
					pc["branch"] = branch
					pc["spine"] = spine
					ids.append(int(pc.id))
				cor["depth"] = int(cur.get("depth", 0))
				room["depth"] = int(cur.get("depth", 0)) + 1
				room["room_kind"] = _room_kind(rng, float(room.half))
				room["branch_of"] = int(from.id)
				_door(lay, wp[0], n, float(cor.half) - 0.1, y, minf(ch, float(cur.h)) - 0.2, cur, cor)
				_door(lay, start + n * (clen + WALL * 0.5), n, float(cor.half) - 0.1, y - dy, ch - 0.2, cor, room)
				rooms.append(room)
				cur = room
				placed = true
				break
			if placed:
				break
		if not placed:
			break
		# On (§EX.2): straight through the wall facing the way in, the
		# spine always; a side way turns by turn_chance, and either turns
		# where straight on won't fit.
		var lr := "left" if rng.randf() < 0.5 else "right"
		var rl := "right" if lr == "left" else "left"
		var turn := (not spine or not facing) and rng.randf() < float(K.get("turn_chance", 0.45))
		ways = [lr, "end", rl] if turn else ["end", lr, rl]
	if ids.is_empty():
		(lay.branches as Array).pop_back()
	elif spine:
		lay.spine = ids.duplicate()
	return rooms


## The way out (design §EX.5; crawler.json exit): past the heart, from a
## door centred in its far wall (facing its way in), a long flight
## climbing exit.rise_m at the kit's stair slope (in whole modules), on
## into a landing (exit.landing_m: long, wide; snapped to modules) through
## a door, and the old way in: an opening centred in the landing's far
## wall, daylight beyond it (WayOut). Every piece of it is spine.
static func _way_out(lay: Dictionary, heart: Dictionary) -> void:
	var mod := float(lay.module)
	var th := str(lay.theme)
	var rise := float(EXIT.get("rise_m", 6.0))
	var run := ceilf(rise / maxf(float(K.get("stair_slope", 0.6)), 0.1) / mod - 1e-4) * mod
	var ch := height_of(th, "corridor", float(K.get("corridor_h_m", 2.6)))
	var chalf := float(K.get("corridor_half_m", 1.0))
	var lm: Array = EXIT.get("landing_m", [2.0, 4.0])
	var wp := wall_point(heart, "end", 0.0)
	var n: Vector2 = wp[1]
	var start: Vector2 = (wp[0] as Vector2) + n * (WALL * 0.5)
	var y := float(heart.y1)
	var stair := _add(lay, Delves.piece("stair", start, n, run, chalf, y, y + rise, ch))
	var landing := _add(lay, Delves.piece("landing", start + n * (run + WALL), n, snap(float(lm[0]), mod), snap(float(lm[1]), mod) * 0.5, y + rise, y + rise, ch))
	for pc in [stair, landing]:
		pc["branch"] = 0
		pc["spine"] = true
		pc["exit"] = true
		pc["depth"] = int(heart.depth)
		(lay.spine as Array).append(int(pc.id))
		((lay.branches as Array)[0] as Array).append(int(pc.id))
	_door(lay, wp[0], n, chalf - 0.1, y, minf(ch, float(heart.h)) - 0.2, heart, stair)
	_door(lay, start + n * (run + WALL * 0.5), n, chalf - 0.1, y + rise, ch - 0.2, stair, landing)
	# The opening: out of the tomb (b -1), the size of a door.
	var op := wall_point(landing, "end", 0.0)
	var d := {"p": op[0], "n": op[1], "half": DOOR_HALF + 0.15, "y": y + rise, "h": ch - 0.2, "a": int(landing.id), "b": -1, "spine": true, "exit": (lay.exits as Array).size()}
	d["id"] = (lay.doors as Array).size()
	(lay.doors as Array).append(d)
	(landing.doors as Array).append(d.id)
	var o2: Vector2 = op[0]
	(lay.exits as Array).append({"door": int(d.id), "heart": int(heart.id), "stair": int(stair.id), "landing": int(landing.id),
		"p": Vector3(o2.x, y + rise, o2.y), "n": Vector3(n.x, 0.0, n.y), "half": float(d.half), "h": float(d.h), "y": y + rise,
		"rise": rise, "leads_to": str(EXIT.get("leads_to", ""))})


static func _door(lay: Dictionary, p: Vector2, n: Vector2, half: float, y: float, h: float, a: Dictionary, b: Dictionary) -> void:
	var d := {"p": p, "n": n, "half": minf(half, DOOR_HALF + 0.15), "y": y, "h": h, "a": int(a.id), "b": int(b.id),
		"spine": bool(a.get("spine", false)) and bool(b.get("spine", false))}
	d["id"] = (lay.doors as Array).size()
	(lay.doors as Array).append(d)
	(a.doors as Array).append(d.id)
	(b.doors as Array).append(d.id)


## A room's kind by the kit's weights; a crypt only where its rows of
## coffins leave an aisle (CRYPT_MIN_HALF).
static func _room_kind(rng: RandomNumberGenerator, half: float) -> String:
	var kinds: Dictionary = (K.get("kinds", {"crypt": 1}) as Dictionary).duplicate()
	if half < CRYPT_MIN_HALF - 0.01 and kinds.size() > 1:
		kinds.erase("crypt")
	var total := 0.0
	for k in kinds:
		total += float(kinds[k])
	var r := rng.randf() * total
	for k in kinds:
		r -= float(kinds[k])
		if r <= 0.0:
			return str(k)
	return str(kinds.keys()[0])


## Which of piece `pc`'s walls (side, offset along it) door `d` is on.
static func door_side(pc: Dictionary, d: Dictionary) -> Array:
	var aa := Delves.along_across(pc, d.p)
	var length := float(pc.len)
	if aa.x <= 0.0:
		return ["start", aa.y]
	if aa.x >= length:
		return ["end", aa.y]
	return ["left" if aa.y > 0.0 else "right", aa.x - length * 0.5]


## Where you wake (a mat by the hearth, facing it), the bundle, the
## rescuer (across the hearth, facing it and you): clear of the room's
## doors.
static func _wake_and_bundle(lay: Dictionary, rng: RandomNumberGenerator, room: Dictionary) -> void:
	var res: Dictionary = Tuning.table("crawler").get("rescuer", {})
	var stand := float(res.get("stand_m", 2.1))
	# The way from the hearth with the most room: away from the doors.
	var best_a := 0.0
	var best_score := -INF
	for k in 16:
		var a := TAU * k / 16.0
		var v := Vector2(cos(a), sin(a))
		var score := 0.0
		for di in room.doors:
			var d: Dictionary = lay.doors[di]
			score += (d.p as Vector2).normalized().dot(v) * -1.0
		score += rng.randf() * 0.1
		if score > best_score:
			best_score = score
			best_a = a
	var v := Vector2(cos(best_a), sin(best_a))
	var wake := v * 2.4
	lay["wake"] = [Vector3(wake.x, 0.0, wake.y), atan2(wake.x, wake.y)]
	var side := Vector2(-v.y, v.x)
	var b := v * 0.9 + side * 0.85
	lay["bundle"] = Vector3(b.x, 0.0, b.y)
	# Across the hearth, a little way round it (rescuer.round_deg, §FH: it
	# sits, lower than the flame, so not straight across), on whichever
	# side keeps it and its things behind it farther from the doors.
	var ra := deg_to_rad(float(res.get("round_deg", 30.0)))
	var r := Vector2.ZERO
	var best_clear := -INF
	for sgn: float in [1.0, -1.0]:
		var rr := (-v * cos(ra) + side * (sin(ra) * sgn)) * stand
		var clear := INF
		for di in room.doors:
			var dp: Vector2 = (lay.doors[di] as Dictionary).p
			clear = minf(clear, minf(dp.distance_to(rr), dp.distance_to(rr * (1.0 + 1.3 / maxf(stand, 0.1)))))
		if clear > best_clear:
			best_clear = clear
			r = rr
	# Facing the hearth (a yaw of 0 faces -z): its front is -r.
	lay["rescuer"] = [Vector3(r.x, 0.0, r.y), atan2(r.x, r.y)]


## Cold fire-holders (design §EX.4; crawler.json room_torches, holders):
## the hearth room's hearth is the tomb's one hearth (room_torches
## hearth_rooms), so no other room gets one; every other room gets wall
## sconces (_room_sconces), and the corridors a sconce every
## sconce_every_m as built (stairs none, delves.json fire_holders.skip;
## delves.json's hearth rings by ruin still serve the open world).
static func _place_holders(lay: Dictionary, rng: RandomNumberGenerator) -> void:
	var skip: Array = (Tuning.table("delves").get("fire_holders", {}) as Dictionary).get("skip", ["stair"])
	for pc in lay.pieces:
		match str(pc.kind):
			"room":
				if str(pc.room_kind) == "hearth":
					continue
				(lay.holders as Array).append_array(_room_sconces(lay, pc))
			"corridor", "stair":
				if str(pc.kind) in skip:
					continue
				var first := float(HOLD.get("sconce_first_m", 4.0))
				var every := maxf(float(HOLD.get("sconce_every_m", 7.0)), 1.0)
				var a := first
				var sd := 1.0 if rng.randf() < 0.5 else -1.0
				while a < float(pc.len) - 1.0:
					var p := Delves.perp(pc.dir)
					var wall: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + p * sd * float(pc.half)
					var nrm := -Vector3(p.x, 0.0, p.y) * sd
					(lay.holders as Array).append({"kind": "sconce", "pos": Vector3(wall.x, Delves.floor_of(pc, a) + float(HOLD.get("sconce_h_m", 1.7)), wall.y), "normal": nrm, "piece": int(pc.id), "room": false})
					sd = -sd
					a += every


## The point on the inside face of wall `side` of piece `pc`, `off` along
## that wall from its middle (along the piece on its side walls, across it
## on its end walls), and the way into the piece from there.
static func face_point(pc: Dictionary, side: String, off: float) -> Array:
	var c: Vector2 = pc.c
	var d: Vector2 = pc.dir
	var p := Delves.perp(d)
	var length := float(pc.len)
	var half := float(pc.half)
	match side:
		"end":
			return [c + d * length + p * off, -d]
		"start":
			return [c + p * off, d]
		"left":
			return [c + d * (length * 0.5 + off) + p * half, -p]
	return [c + d * (length * 0.5 + off) - p * half, p]


## The inside length of wall `side` of piece `pc` (m).
static func wall_len(pc: Dictionary, side: String) -> float:
	return 2.0 * float(pc.half) if side in ["start", "end"] else float(pc.len)


## How far (x/z) `q` is from door `d`'s opening: the gap through its wall,
## `half` either side of its middle and the wall's thickness deep (0 in it).
static func door_gap(d: Dictionary, q: Vector2) -> float:
	var n: Vector2 = d.n
	var r := q - (d.p as Vector2)
	return Vector2(maxf(absf(r.dot(Delves.perp(n))) - float(d.half), 0.0), maxf(absf(r.dot(n)) - WALL * 0.5, 0.0)).length()


## A room's wall sconces (design §EX.4; crawler.json room_torches, the
## style's module_m). `small` of them in a room whose long walls are up to
## small_room_max_m long, `large` in a longer one: in facing pairs on the
## long walls (in a square room, the pair with fewer doors), a whole number
## of modules apart, the spacing nearest an even spread down the wall
## first. The heart gets heart_flank_dead on each side wall, a module
## apart, flanking the dead at its end (`heart` in all). Each keeps clear_m
## from its bracket's edge to every door's edge and to the corners; where a
## door is in the way the pairs step along the wall together (SHIFT_M at a
## time, nearest first, so a door in the middle of a wall ends up
## flanked), still facing and whole modules apart; failing that, at
## another whole-module spacing; failing that, each long wall finds its
## own places (the pairs then not quite facing); and only failing that,
## the other two walls.
static func _room_sconces(lay: Dictionary, pc: Dictionary) -> Array:
	var module := module_of(str(lay.theme))
	var length := float(pc.len)
	var width := 2.0 * float(pc.half)
	var clear := float(RT.get("clear_m", 0.6)) + SCONCE_HALF
	var doors: Array = []
	for di in pc.doors:
		doors.append(lay.doors[di])
	# Each plan: [walls, [offsets from the wall's middle...] in order].
	var plans: Array = []
	if str(pc.room_kind) == "heart":
		var per := maxi(int(RT.get("heart_flank_dead", 2)), 1)
		var lim := length * 0.5 - clear
		# A module apart (closer only in a heart too short for it).
		var s := module if (per - 1) * module <= 2.0 * lim else 2.0 * maxf(lim, 0.0) / maxf(per - 1, 1)
		# Centred on the dead, then kept off the corners as one group.
		var dead := length * 0.5 - HEART_DEAD_M
		var offs: Array = []
		var mid: Array = []
		for i in per:
			offs.append(dead + (i - (per - 1) * 0.5) * s)
			mid.append((i - (per - 1) * 0.5) * s)
		var shift := minf(lim - float(offs[-1]), 0.0) + maxf(-lim - float(offs[0]), 0.0)
		for i in per:
			offs[i] = float(offs[i]) + shift
		# If doors crowd the dead, the same pairs anywhere down the side walls.
		plans.append([["left", "right"], [offs, mid]])
	else:
		var n := int(RT.get("small", 2)) if maxf(length, width) <= float(RT.get("small_room_max_m", 8.0)) + 0.001 else int(RT.get("large", 4))
		var per := maxi(ceili(n * 0.5), 1)
		var pairs: Array = [["left", "right"], ["start", "end"]]
		if width > length + 0.001 or (absf(width - length) <= 0.001 and _doors_on(pc, doors, pairs[0]) > _doors_on(pc, doors, pairs[1])):
			pairs.reverse()
		for walls in pairs:
			var span := wall_len(pc, str(walls[0]))
			var lim := span * 0.5 - clear
			if lim < 0.0:
				continue
			# Whole modules apart: the spacing nearest an even spread down
			# the wall first, then the others, nearest it first.
			var ks: Array = [1]
			if per > 1:
				var k_max := floori(2.0 * lim / ((per - 1) * module) + 1e-4)
				var k0 := clampi(roundi(span / per / module), 1, maxi(k_max, 1))
				ks = range(1, maxi(k_max, 1) + 1)
				ks.sort_custom(func(x, y): return absi(int(x) - k0) < absi(int(y) - k0) or (absi(int(x) - k0) == absi(int(y) - k0) and int(x) > int(y)))
			var sets: Array = []
			for k in ks:
				var offs: Array = []
				for i in per:
					offs.append((i - (per - 1) * 0.5) * int(k) * module)
				sets.append(offs)
			plans.append([walls, sets])
	for plan in plans:
		var walls: Array = plan[0]
		# Facing: both walls clear at the same places.
		for offs in plan[1]:
			var at := _clear_offsets(pc, walls, offs, doors, clear)
			if not at.is_empty():
				return _sconces_on(pc, walls, at)
		# Else each wall finds its own.
		var out: Array = []
		for side in walls:
			for offs in plan[1]:
				var at := _clear_offsets(pc, [side], offs, doors, clear)
				if not at.is_empty():
					out.append_array(_sconces_on(pc, [side], at))
					break
		if out.size() == walls.size() * (plan[1][0] as Array).size():
			return out
	push_warning("TombKit: room %d (%s) has no wall clear of its doors for its sconces" % [int(pc.id), str(pc.room_kind)])
	return []


## How many of `doors` cut piece `pc`'s walls `walls`.
static func _doors_on(pc: Dictionary, doors: Array, walls: Array) -> int:
	var n := 0
	for d in doors:
		if str(door_side(pc, d)[0]) in walls:
			n += 1
	return n


## `offs` moved along walls `walls` of `pc` as one group (0 first, then
## SHIFT_M, -SHIFT_M, 2 SHIFT_M...) until every one is within its wall,
## clear of the corners and of every door by `clear` (m): the offsets, or
## [] if nowhere along the wall clears.
static func _clear_offsets(pc: Dictionary, walls: Array, offs: Array, doors: Array, clear: float) -> Array:
	var step := SHIFT_M
	var lim := wall_len(pc, str(walls[0])) * 0.5 - clear
	var lo := float(offs[0])
	var hi := float(offs[-1])
	var n := ceili((2.0 * lim + absf(hi - lo)) / step) + 1
	for j in 2 * n + 1:
		var t := step * ceili(j * 0.5) * (1.0 if j % 2 == 1 else -1.0)
		if hi + t > lim + 1e-4 or lo + t < -lim - 1e-4:
			continue
		var ok := true
		for side in walls:
			for off in offs:
				var q: Vector2 = face_point(pc, str(side), float(off) + t)[0]
				for d in doors:
					if door_gap(d, q) < clear:
						ok = false
		if ok:
			var out: Array = []
			for off in offs:
				out.append(float(off) + t)
			return out
	return []


## Holders for sconces at offsets `offs` along each of walls `walls` of
## room `pc` (room_torches.room_holder: wall sconces are what is built).
static func _sconces_on(pc: Dictionary, walls: Array, offs: Array) -> Array:
	var kind := str(RT.get("room_holder", "sconce"))
	if kind != "sconce":
		push_warning("crawler.json room_torches.room_holder %s: only wall sconces are built (design §EX.4)" % kind)
	var h := float(HOLD.get("sconce_h_m", 1.7))
	var out: Array = []
	for side in walls:
		for off in offs:
			var fp := face_point(pc, str(side), float(off))
			var at: Vector2 = fp[0]
			var nv: Vector2 = fp[1]
			out.append({"kind": "sconce", "pos": Vector3(at.x, Delves.floor_of(pc, Delves.along_across(pc, at).x) + h, at.y), "normal": Vector3(nv.x, 0.0, nv.y), "piece": int(pc.id), "room": true, "side": str(side), "off": float(off)})
	return out


## The vents (design §EV; smoke.json vents): every permanent fire the
## generator built (the hearth and each sconce; carried torches are
## exempt) gets its own vent from its piece's ceiling up to the surface,
## kinked where another piece of the tomb stands over it: a shaft for a
## hearth, ring or altar, a narrow flue for a sconce or brazier (§EV.1). So
## the one hearth's shaft is the tomb's one column of daylight (§EX.4).
## Each is {"kind", "type" ("shaft" / "flue"), "fire" (the fire's
## place), "fire_index" (-1 the hearth, else its holder's index), "piece",
## "mouth" (the vent's mouth in the ceiling's underside), "d" (its width,
## narrowing with depth), "depth" (the vent's length up to the surface),
## "sky" (a shaft with daylight left at that depth, §EV.2), "share" (the
## daylight left), "legs" ([[from, to]...], the runs, up and any sideways
## step), "top" (its opening at the surface), "outlet" (what it becomes on
## the surface once there is one, §EV.4 with §EW: smoke.json
## vents.surface)}.
static func _place_vents(lay: Dictionary) -> void:
	var V: Dictionary = vents_table()
	var fires: Array = [{"kind": "hearth", "pos": lay.hearth, "normal": Vector3.UP, "piece": 0, "index": -1}]
	for i in (lay.holders as Array).size():
		var h: Dictionary = lay.holders[i]
		fires.append({"kind": h.kind, "pos": h.pos, "normal": h.normal, "piece": h.piece, "index": i})
	var surface := float(V.get("surface_y_m", 9.0))
	var dl: Dictionary = V.get("daylight", {})
	var fade: Array = dl.get("fade_depth_m", [3.0, 25.0])
	var narrow := bool(dl.get("narrow_with_depth", true))
	var vents: Array = []
	for f in fires:
		var pc: Dictionary = lay.pieces[int(f.piece)]
		var fp: Vector3 = f.pos
		var vtype := vent_type(str(f.kind))
		var wr: Array = (V.get(vtype, {}) as Dictionary).get("width_m", [0.6, 1.2] if vtype == "shaft" else [0.15, 0.3])
		# The mouth: beside a fire on the floor for a shaft, straight over it
		# for a flue; over a sconce, just off its wall. Kept inside the
		# piece's ceiling.
		var m := Vector2(fp.x, fp.z)
		var d0 := float(wr[1])
		if str(f.kind) == "sconce":
			var nv: Vector3 = f.normal
			m += Vector2(nv.x, nv.z) * (d0 * 0.5 + 0.08)
		elif vtype == "shaft":
			var off: Array = V.get("mouth_offset_m", [0.7, 1.1])
			var orng := RandomNumberGenerator.new()
			orng.seed = hash([int(lay.seed), fp, "vent"])
			m += Vector2.RIGHT.rotated(orng.randf() * TAU) * orng.randf_range(float(off[0]), float(off[1]))
		var aa := Delves.along_across(pc, m)
		var ceil_y := Delves.floor_of(pc, clampf(aa.x, 0.0, float(pc.len))) + float(pc.h)
		var depth := maxf(surface - ceil_y, 0.0)
		# Narrower the deeper (§EV.2): the full width at the surface, the
		# least at the depth where the daylight is gone.
		var k := clampf(depth / maxf(float(fade[1]), 0.1), 0.0, 1.0) if narrow else 0.0
		var d := maxf(lerpf(float(wr[1]), float(wr[0]), k), 0.08)
		aa.x = clampf(aa.x, d * 0.5 + 0.05, float(pc.len) - d * 0.5 - 0.05)
		aa.y = clampf(aa.y, -float(pc.half) + d * 0.5 + 0.05, float(pc.half) - d * 0.5 - 0.05)
		m = (pc.c as Vector2) + (pc.dir as Vector2) * aa.x + Delves.perp(pc.dir) * aa.y
		ceil_y = Delves.floor_of(pc, aa.x) + float(pc.h)
		var mouth := Vector3(m.x, ceil_y, m.y)
		var kink: Dictionary = V.get("kink", {})
		var legs := _flue_legs(lay, int(pc.id), mouth, d, surface, kink, int((V.get("shaft", {}) as Dictionary).get("kinks", 2)))
		var top: Vector3 = (legs[-1] as Array)[1]
		var share := daylight_share(depth) if vtype == "shaft" or not bool(dl.get("shafts_only", true)) else 0.0
		vents.append({"kind": f.kind, "type": vtype, "fire": fp, "fire_index": int(f.index), "piece": int(pc.id), "mouth": mouth, "d": d,
			"depth": depth, "sky": share > 0.0, "share": share, "legs": legs, "top": top,
			"outlet": str((V.get("surface", {}) as Dictionary).get(vtype, ""))})
	lay["vents"] = vents


## smoke.json vents (design §EV).
static func vents_table() -> Dictionary:
	return Tuning.table("smoke").get("vents", {})


## "shaft" or "flue": which vent a fire of `kind` gets (smoke.json
## vents.shaft.for; design §EV.1). Anything else gets a flue.
static func vent_type(kind: String) -> String:
	var sh: Array = (vents_table().get("shaft", {}) as Dictionary).get("for", ["hearth", "old_hearth", "hearth_ring", "altar"])
	return "shaft" if kind in sh else "flue"


## The share of daylight left down a shaft `depth` m long (smoke.json
## vents.daylight.fade_depth_m: full to the first, none past the second,
## a straight line between).
static func daylight_share(depth: float) -> float:
	var fade: Array = (vents_table().get("daylight", {}) as Dictionary).get("fade_depth_m", [3.0, 25.0])
	var a := float(fade[0])
	var b := maxf(float(fade[1]), a + 0.01)
	return clampf(1.0 - (depth - a) / (b - a), 0.0, 1.0)


## The vent's runs from `mouth` up to the surface: straight up if no other
## piece of the tomb stands over it; else up kink.clear_m, a step sideways
## (up to kink.step_m) to clear rock, and on up (two bends; `kinks` under
## 2 keeps it straight, the rock taking it).
static func _flue_legs(lay: Dictionary, own: int, mouth: Vector3, d: float, surface: float, kink: Dictionary, kinks := 2) -> Array:
	var top := Vector3(mouth.x, surface, mouth.z)
	if kinks < 2 or _column_clear(lay, own, Vector2(mouth.x, mouth.z), d, mouth.y):
		return [[mouth, top]]
	var rise := mouth.y + float(kink.get("clear_m", 1.2))
	var step := float(kink.get("step_m", 2.5))
	for r in [step * 0.5, step]:
		for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var at := Vector2(mouth.x, mouth.z) + (dv as Vector2) * float(r)
			if _column_clear(lay, own, at, d, rise):
				var a := Vector3(mouth.x, rise, mouth.z)
				var b := Vector3(at.x, rise, at.y)
				return [[mouth, a], [a, b], [b, Vector3(at.x, surface, at.y)]]
	# Nowhere clear: straight up regardless (the rock keeps it).
	return [[mouth, top]]


## Does a flue `d` wide at (x/z) `p`, rising from `from_y`, keep clear of
## every other piece above that height?
static func _column_clear(lay: Dictionary, own: int, p: Vector2, d: float, from_y: float) -> bool:
	var r := Rect2(p - Vector2(d, d) * 0.5, Vector2(d, d))
	for pc in lay.pieces:
		if int(pc.id) == own:
			continue
		var top := maxf(float(pc.y0), float(pc.y1)) + float(pc.h) + Delves.SLAB
		if top <= from_y:
			continue
		if outer(pc).intersects(r):
			return false
	return true


## The airways (§ET.6): ordinary slots in corridor walls, strong marked
## mouths in room side walls, away from doors and sconces (room_torches
## clear_m between a mouth's surround and a sconce's bracket).
static func _place_airways(lay: Dictionary, rng: RandomNumberGenerator) -> void:
	var air := str((THEMES.get(lay.theme, {}) as Dictionary).get("air", "still"))
	var counts: Dictionary = (AIR.get("per_air", {}) as Dictionary).get(air, {"ordinary": 2, "strong": 1})
	var corridors: Array = []
	var rooms: Array = []
	for pc in lay.pieces:
		if str(pc.kind) == "corridor" and float(pc.len) >= 4.0:
			corridors.append(pc)
		elif str(pc.kind) == "room" and str(pc.room_kind) != "hearth":
			rooms.append(pc)
	_shuffle(rng, corridors)
	_shuffle(rng, rooms)
	var n_ord := int(counts.get("ordinary", 2))
	var made_o := 0
	for pc in corridors:
		if made_o >= n_ord:
			break
		var a := float(pc.len) * rng.randf_range(0.3, 0.7)
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		# The rolled wall, else the other one if a sconce is there.
		for s2: float in [sd, -sd]:
			if _airway_clear(lay, pc, a, s2, false):
				_airway(lay, pc, a, s2, false)
				made_o += 1
				break
	var n_strong := int(counts.get("strong", 1))
	var made := 0
	for pc in rooms:
		if made >= n_strong:
			break
		var a0 := float(pc.len) * rng.randf_range(0.35, 0.65)
		# A side wall with no door on it, the rolled spot or another along
		# it clear of the room's sconces.
		var placed := false
		for sd: float in [1.0, -1.0]:
			if placed:
				break
			var side := "left" if sd > 0.0 else "right"
			var used := false
			for di in pc.doors:
				if str(door_side(pc, lay.doors[di])[0]) == side:
					used = true
			if used:
				continue
			for a: float in [a0, float(pc.len) * 0.25, float(pc.len) * 0.75, float(pc.len) * 0.5, float(pc.len) * 0.35, float(pc.len) * 0.65]:
				if _airway_clear(lay, pc, a, sd, true):
					_airway(lay, pc, a, sd, true)
					made += 1
					placed = true
					break


## Is a strong (or ordinary) airway mouth `along` piece `pc`'s side wall
## `sd` (1 left, -1 right) clear of every sconce on that wall?
static func _airway_clear(lay: Dictionary, pc: Dictionary, along: float, sd: float, strong: bool) -> bool:
	var need := float(AIRWAY_HALF[0 if strong else 1]) + float(RT.get("clear_m", 0.6)) + SCONCE_HALF
	for h in lay.holders:
		if int(h.piece) != int(pc.id):
			continue
		var pos: Vector3 = h.pos
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		if absf(absf(aa.y) - float(pc.half)) < 0.05 and signf(aa.y) == sd and absf(aa.x - along) < need:
			return false
	return true


static func _airway(lay: Dictionary, pc: Dictionary, along: float, sd: float, strong: bool) -> void:
	var p := Delves.perp(pc.dir)
	var at: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + p * sd * float(pc.half)
	var y := Delves.floor_of(pc, along) + (1.2 if strong else 2.0)
	(lay.airways as Array).append({"strong": strong, "pos": Vector3(at.x, y, at.y), "normal": -Vector3(p.x, 0.0, p.y) * sd, "piece": int(pc.id)})


## Every piece's id that `pos` (scene, the tomb at the origin) stands in.
static func piece_at(lay: Dictionary, pos: Vector3) -> int:
	for pc in lay.pieces:
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		if aa.x >= -0.05 and aa.x <= float(pc.len) + 0.05 and absf(aa.y) <= float(pc.half) + 0.05:
			var fy := Delves.floor_of(pc, aa.x)
			if pos.y > fy - 1.0 and pos.y < fy + float(pc.h) + 0.5:
				return int(pc.id)
	return -1


# --- The residents' resting places (design §FE, residents.json) ---------------

## Is (along) on wall `side` of `pc` within `within` of one of its doors?
static func near_door(lay: Dictionary, pc: Dictionary, side: String, along: float, within: float) -> bool:
	for di in pc.doors:
		var s: Array = door_side(pc, lay.doors[di])
		if str(s[0]) == side and absf(float(s[1]) + float(pc.len) * 0.5 - along) < within:
			return true
	return false


## Is (along) within `within` of an airway on side `sd` of `pc`?
static func near_airway(lay: Dictionary, pc: Dictionary, sd: float, along: float, within: float) -> bool:
	for a in lay.airways:
		if int(a.piece) != int(pc.id):
			continue
		var aa := Delves.along_across(pc, Vector2((a.pos as Vector3).x, (a.pos as Vector3).z))
		if signf(aa.y) == sd and absf(aa.x - along) < within:
			return true
	return false


## A crypt's stone coffins (TombBuild draws them): rows down both long
## walls every 2.4 m, clear of the doors, airways and the room's fire, each 2.2 m long
## across the room from its wall (COFFIN_IN its middle's distance in from
## the wall): [{"along", "sd" (the wall's side, +1 left), "i"}...] in the
## order they are drawn. None in a room under 4.8 m wide.
const COFFIN_IN := 1.25
const COFFIN_SIZE := Vector3(0.95, 0.9, 2.2)


static func coffin_spots(lay: Dictionary, pc: Dictionary) -> Array:
	var out: Array = []
	if float(pc.half) < 2.4:
		return out
	for sd: float in [-1.0, 1.0]:
		# Set so the first sconce on this wall falls between two coffins
		# where that costs none (design §EX.4); a sconce over a coffin's
		# head is in reach from the gap beside it.
		for a in row(lay, pc, sd, 1.6, 2.4, float(pc.len) - 1.4, 1.2, 1.9, 1.4, 0.0):
			out.append({"along": a, "sd": sd, "i": out.size()})
	return out


## Whether the boss's lair took coffin spot `spot` of piece `piece`: in a
## crypt the hole is where a coffin stood, fallen through with the floor
## (BossGround.place_lair, never a resident's; TombBuild leaves it out).
static func lair_took(lay: Dictionary, piece: int, spot: int) -> bool:
	var l: Dictionary = lay.get("lair", {})
	return l.has("coffin") and int(l.get("piece", -1)) == piece and int(l.coffin) == spot


## A catacomb's niche stacks (three shelves each, down both long walls
## every 1.4 m, clear of the doors and airways, and of the room's fire,
## where one climbing out would step into it): [{"along", "sd", "i"}...].
static func niche_spots(lay: Dictionary, pc: Dictionary) -> Array:
	var out: Array = []
	for sd: float in [-1.0, 1.0]:
		# Set so the first sconce on this wall hangs where one stack would
		# be: no stack within NICHE_CLEAR of a sconce's bracket (§EX.4).
		for a in row(lay, pc, sd, 1.0, 1.4, float(pc.len) - 0.8, 0.0, 1.5, 1.2, NICHE_CLEAR):
			out.append({"along": a, "sd": sd, "i": out.size()})
	return out


## A niche stack keeps this far (m, middle to middle) from a sconce on its
## wall: a burial niche's frame's half width (TombBuild._burial_niche, its
## lintel 1.46 m), the sconce bracket's, a hand's gap.
const NICHE_CLEAR := 0.95


## A row of things down `pc`'s side wall `sd` (1 left, -1 right): every
## `pitch` m from `start` while short of `end`, clear of that wall's doors
## (`door_m`), airways (`air_m`) and room sconces (`sconce_m`, 0 for
## none). Or the same row set `phase` m off the wall's first sconce (so a
## sconce sits in a gap, or at a skipped place), where that holds as many
## (design §EX.4): the alongs.
static func row(lay: Dictionary, pc: Dictionary, sd: float, start: float, pitch: float, end: float, phase: float, door_m: float, air_m: float, sconce_m: float) -> Array:
	var side := "left" if sd > 0.0 else "right"
	var best: Array = []
	var starts: Array = [start]
	var s0 := first_sconce_along(lay, pc, sd)
	if not is_nan(s0):
		starts.push_front(s0 + phase - pitch * floorf((s0 + phase - start) / pitch))
	for a0 in starts:
		var out: Array = []
		var a := float(a0)
		while a < end:
			if not near_door(lay, pc, side, a, door_m) and not near_airway(lay, pc, sd, a, air_m) and not (sconce_m > 0.0 and near_sconce(lay, pc, sd, a, sconce_m)):
				out.append(a)
			a += pitch
		if out.size() > best.size():
			best = out
	return best


## The along of the first sconce on `pc`'s side wall `sd` (1 left, -1
## right), or NAN when that wall has none.
static func first_sconce_along(lay: Dictionary, pc: Dictionary, sd: float) -> float:
	var best := NAN
	for h in lay.get("holders", []):
		if int(h.piece) != int(pc.id) or str(h.kind) != "sconce":
			continue
		var aa := Delves.along_across(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z))
		if absf(absf(aa.y) - float(pc.half)) < 0.05 and signf(aa.y) == sd and (is_nan(best) or aa.x < best):
			best = aa.x
	return best


## Is there a sconce on `pc`'s side wall `sd` within `within` m of `along`?
static func near_sconce(lay: Dictionary, pc: Dictionary, sd: float, along: float, within: float) -> bool:
	for h in lay.get("holders", []):
		if int(h.piece) != int(pc.id) or str(h.kind) != "sconce":
			continue
		var aa := Delves.along_across(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z))
		if absf(absf(aa.y) - float(pc.half)) < 0.05 and signf(aa.y) == sd and absf(aa.x - along) < within:
			return true
	return false


## The heart's coffin (Mike's frame 9): its middle on the floor, its yaw
## (long across the room, HEART_BOX_M in from its far wall, the way out's
## door behind it, §EX.5), and the way it opens toward the room's way in.
const HEART_BOX := Vector3(1.05, 1.0, 2.3)
## A grave's rim over what its skeleton kneels on: the inside is filled to
## its height less this (bones and dust), so the head and an arm clear the
## rim (SkeletonRig rest_grave).
const GRAVE_RIM_OVER := 0.58


## The height inside a coffin `box_h` tall that a skeleton kneels on.
static func grave_floor(box_h: float) -> float:
	return maxf(box_h - GRAVE_RIM_OVER, 0.12)


static func heart_box(pc: Dictionary) -> Dictionary:
	var length := float(pc.len)
	var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * (length - HEART_DEAD_M)
	return {"pos": Vector3(q.x, Delves.floor_of(pc, length - HEART_DEAD_M), q.y), "yaw": atan2((pc.dir as Vector2).x, (pc.dir as Vector2).y) + PI * 0.5}


## The yaw that faces a figure (its front -z at yaw 0) along x/z `f`.
static func yaw_facing(f: Vector2) -> float:
	return atan2(-f.x, -f.y)


## The way through the rooms (design §EX.5 until the spine is built,
## §EX.2): in every piece, from each of its doors to its middle:
## [[Vector2, Vector2]...]. What a resting place keeps off (off_line_m).
static func walk_lines(lay: Dictionary) -> Array:
	var out: Array = []
	for pc in lay.pieces:
		var mid: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * float(pc.len) * 0.5
		for di in pc.doors:
			var d: Dictionary = lay.doors[di]
			var into: Vector2 = (d.n as Vector2) * (1.0 if int(d.b) == int(pc.id) else -1.0)
			out.append([(d.p as Vector2) + into * (WALL * 0.5 + 0.3), mid])
	return out


## How far x/z `p` is from the nearest of `lines` (walk_lines).
static func line_distance(lines: Array, p: Vector2) -> float:
	var best := INF
	for l in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## A resting place in piece `pc` (TombBuild draws it, Residents wakes it):
## {"kind" (the creature), "rests_in" ("wall_niche" / "grave"), "piece",
## "spot" (its coffin_spots / niche_spots index; -1 the heart's coffin),
## "pos" (where it rests: the shelf's top in a niche, the coffin's floor
## in a grave), "yaw" (it faces into the room), "out" (the floor where it
## stands once it has climbed out), "eye" (its head as it rests: what it
## wakes to), "depth"}.
static func rest_place(lay: Dictionary, pc: Dictionary, kind: String, rests_in: String, spot: Dictionary) -> Dictionary:
	var half := float(pc.half)
	var pv := Delves.perp(pc.dir)
	var fy := Delves.floor_of(pc, float(spot.get("along", 0.0)))
	var r := {"kind": kind, "rests_in": rests_in, "piece": int(pc.id), "spot": int(spot.get("i", -1)), "depth": int(pc.get("depth", 0))}
	if int(spot.get("i", -1)) < 0:
		# The heart's coffin: it kneels inside, slumped over the side that
		# faces the way in.
		var hb := heart_box(pc)
		var hp: Vector3 = hb.pos
		var toward := -(pc.dir as Vector2)
		var t3 := Vector3(toward.x, 0.0, toward.y)
		r["pos"] = Vector3(hp.x, hp.y + grave_floor(HEART_BOX.y), hp.z) + t3 * 0.12
		r["out"] = Vector3(hp.x, hp.y, hp.z) + t3 * (HEART_BOX.x * 0.5 + 0.65)
		r["yaw"] = yaw_facing(toward)
		r["eye"] = (r.pos as Vector3) + Vector3(0.0, 0.86, 0.0) + t3 * 0.45
		return r
	var a := float(spot.along)
	var sd := float(spot.sd)
	var inward := -pv * sd
	if rests_in == "grave":
		# A crypt coffin: kneeling inside near its inner end, slumped over it.
		var c: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - COFFIN_IN)
		var p := c + inward * (COFFIN_SIZE.z * 0.5 - 0.5)
		var o := c + inward * (COFFIN_SIZE.z * 0.5 + 0.6)
		r["pos"] = Vector3(p.x, fy + grave_floor(COFFIN_SIZE.y), p.y)
		r["out"] = Vector3(o.x, fy, o.y)
		r["eye"] = (r.pos as Vector3) + Vector3(0.0, 0.86, 0.0) + Vector3(inward.x, 0.0, inward.y) * 0.45
	else:
		# A niche: sitting hunched on the bottom shelf, facing the room.
		var p2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - 0.32)
		var o2: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + pv * sd * (half - 1.15)
		r["pos"] = Vector3(p2.x, fy + 0.5, p2.y)
		r["out"] = Vector3(o2.x, fy, o2.y)
		r["eye"] = Vector3(p2.x, fy + 0.5 + 0.62, p2.y) + Vector3(inward.x, 0.0, inward.y) * 0.24
	r["yaw"] = yaw_facing(inward)
	return r


## The residents' resting places (design §FE.1-2, residents.json): for the
## tomb, its skeletons (rests_in wall_niche and grave): per_dungeon of them
## when there are places enough, the heart's coffin holding one
## (heart_holds_one), the rest drawn room by room weighted by depth to the
## toward_heart power, none in the hearth room, none within off_line_m of
## the way through (walk_lines; the heart's coffin aside), none by the
## boss's hole (_by_lair), none within apart_m of another. Its own
## seed, so the rest of the tomb is as it was. lay.residents [rest_place...].
static func _place_residents(lay: Dictionary) -> void:
	lay["residents"] = []
	var kind := "skeleton"
	var cr: Dictionary = (RESIDENTS.get("creatures", {}) as Dictionary).get(kind, {})
	if cr.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lay.seed), "residents"])
	var lines := walk_lines(lay)
	var off := float(cr.get("off_line_m", 1.0))
	var apart := float(cr.get("apart_m", 2.0))
	var rests: Array = cr.get("rests_in", ["wall_niche", "grave"])
	var power := float(cr.get("toward_heart", 1.5))
	var heart: Dictionary = {}
	var cands: Array = []
	for pc in lay.pieces:
		if str(pc.kind) != "room":
			continue
		var places: Array = []
		match str(pc.get("room_kind", "")):
			"crypt":
				if "grave" in rests:
					for s in coffin_spots(lay, pc):
						places.append(rest_place(lay, pc, kind, "grave", s))
			"catacomb":
				if "wall_niche" in rests:
					for s in niche_spots(lay, pc):
						places.append(rest_place(lay, pc, kind, "wall_niche", s))
			"heart":
				if "grave" in rests and bool(cr.get("heart_holds_one", true)):
					heart = rest_place(lay, pc, kind, "grave", {"i": -1})
		for p in places:
			var at: Vector3 = p.pos
			if line_distance(lines, Vector2(at.x, at.z)) >= off and not _by_lair(lay, at):
				cands.append(p)
	var span: Array = cr.get("per_dungeon", [3, 6])
	var want := rng.randi_range(int(span[0]), int(span[1]))
	var picked: Array = []
	# The heart's always holds one (heart_holds_one): the way through the
	# heart goes round its coffin to the way out (§EX.5), so no line keeps
	# it empty.
	if not heart.is_empty():
		picked.append(heart)
	while picked.size() < want and not cands.is_empty():
		var total := 0.0
		for c in cands:
			total += pow(maxf(float(c.depth), 1.0), power)
		var roll := rng.randf() * total
		var pick := 0
		for i in cands.size():
			roll -= pow(maxf(float(cands[i].depth), 1.0), power)
			if roll <= 0.0:
				pick = i
				break
		var chosen: Dictionary = cands[pick]
		cands.remove_at(pick)
		var ok := true
		for q in picked:
			if (q.pos as Vector3).distance_to(chosen.pos) < apart:
				ok = false
				break
		if ok:
			picked.append(chosen)
	lay["residents"] = picked


## Is `at` by the boss's hole (lay.lair, BossGround.place_lair): within its
## r and 1.5 m of the stone broken round it, as FirePots keeps the found
## pot? Nothing rests there: its ring of collision would hide the place,
## and one climbing out would climb into it.
static func _by_lair(lay: Dictionary, at: Vector3) -> bool:
	var l: Dictionary = lay.get("lair", {})
	if l.is_empty():
		return false
	var c: Vector3 = l.pos
	return Vector2(at.x - c.x, at.z - c.z).length() < float(l.r) + 1.5


## The resting place in piece `piece` at spot `spot` (-1 the heart's
## coffin), or {} if nothing rests there (TombBuild).
static func resting_at(lay: Dictionary, piece: int, spot: int) -> Dictionary:
	for r in lay.get("residents", []):
		if int(r.piece) == piece and int(r.spot) == spot:
			return r
	return {}

extends SceneTree
## Floors and the fork (design 9 Oct §FM.6; queue 68; TombFloors, Fork,
## RelightGate; data/descent.json floors and fork), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/fork_check.gd
## FORK_SEEDS (env) sets how many seeds the layouts and the walks run over
## beyond 1, 7 and 42 (default 47: fifty in all, drawn from a fixed seed).
## Asserts:
##  1. the layouts (fifty seeds): descent.json floors.count floors (two);
##     the stair down a door centred in a side wall of a floor-one room
##     near the far end of the spine (never the hearth room), a flight
##     straight on down floors.drop_m in whole modules, never spine; floor
##     two all below the room it leaves, nothing of it over or under floor
##     one in plan, reached only through that door; floor one's plan the
##     tomb as built (every piece where a one-floor tomb of the seed has
##     it, only the room the stair leaves with a door more); every room on
##     floor two with its wall sconces by the rule, no hearth and no heart
##     there, its own residents; the boss's lair and tunnels on floor one;
##  2. the walks (the same seeds, the player's own body in each tomb's real
##     collision, the seal standing in the stair's mouth): the way out
##     reached from the wake spot with every holder cold (fork.gate_surface
##     false: never gated, §EX.5), and floor two not (the seal); the seal
##     gone (floor one lit), floor two's first room reached down the stair;
##  3. in the scene (SEED, as shipped): floor one's torches cold, the way
##     down sealed (a plain stone seal in the stair's mouth: its collision
##     across the doorway, the doorway shut on the floor grid and in the
##     graph of the light, no light or glow on it, §FG) and the surface
##     stair open; floor two's torches all lit first: floor two cleared on
##     its own (its line, its own count), floor one not, the way down still
##     sealed; floor one all lit but one: still sealed, no fork line; the
##     last one: the way down opens on the very tick the floor is cleared,
##     the seal sinking out of sight with its grinding, the log's line once,
##     after the floor's; the doorway open on the grid and the graph; the
##     boss driven home by floor one's last light, its lair where it was;
##     the surface stair open throughout;
##  4. down and back: your body walks from the room the stair leaves down
##     the flight onto floor two's floor, and back up to the matching
##     stair's mouth on floor one; one hearth in the dungeon, on floor one;
##  5. kept (design §FK.2, CrawlerSave; queue 63's save): once open, the
##     fork is kept open in the game's save with the relit holders
##     ("fork_open"); the scene closed and Continue opens the same tomb with
##     the way down open at once, quiet (no grinding, no line), the doorway
##     open to you, the floor grid and the graph;
##  6. fork.gate_surface true (a second scene): the way out's flight sealed
##     at its foot too until floor one is lit (its doorway blocked, the
##     way out not reached from the wake spot), then both seals open on the
##     same tick, and the log's line once.

var fails := 0
const DT := 1.0 / 60.0
## Seeds walked beyond 1, 7 and 42 (env FORK_SEEDS overrides).
const MORE_SEEDS := 47
## The walk's grid (m a cell), and how far over its floor your capsule is
## tried.
const CELL_M := 0.25
const LIFT_M := 0.1


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Residents.stay_asleep = true
	var seeds := _seeds()
	_layouts(seeds)
	await _walks(seeds)
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	await _scene(false)
	await _kept()
	OS.set_environment("SEED", str(seed_v))
	await _scene(true)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _seeds() -> Array:
	var n := MORE_SEEDS
	if OS.get_environment("FORK_SEEDS").is_valid_int():
		n = maxi(int(OS.get_environment("FORK_SEEDS")), 0)
	var out: Array = [1, 7, 42]
	var rng := RandomNumberGenerator.new()
	rng.seed = 68
	while out.size() < 3 + n:
		var s := rng.randi_range(1, 999999)
		if not out.has(s):
			out.append(s)
	return out


# --- 1. The layouts -------------------------------------------------------------

func _layouts(seeds: Array) -> void:
	var t0 := Time.get_ticks_msec()
	var want := TombFloors.count()
	var drop := float(TombFloors.FLOORS.get("drop_m", 4.8))
	var floors_ok := true
	var door_ok := true
	var flight_ok := true
	var below_ok := true
	var apart_ok := true
	var only_ok := true
	var asbuilt_ok := true
	var sconce_ok := true
	var hearth_ok := true
	var boss_ok := true
	var res2 := 0
	var res1 := 0
	var rooms2 := 0
	var hosts := {}
	var no_res: Array = []
	for s in seeds:
		var lay := TombKit.layout(int(s))
		var fl: Array = lay.get("floors", [])
		if fl.size() != want or (want >= 2 and not lay.has("descent")):
			floors_ok = false
			print("  seed %d: %d floors, descent %s" % [s, fl.size(), str(lay.has("descent"))])
			continue
		var dsc: Dictionary = lay.descent
		var host: Dictionary = lay.pieces[int(dsc.host)]
		var d: Dictionary = lay.doors[int(dsc.door)]
		var stair: Dictionary = lay.pieces[int(dsc.stair)]
		var foot: Dictionary = lay.pieces[int(dsc.foot)]
		var m := float(lay.module)
		# Where it leaves: a room of floor one past the hearth room, by a door
		# centred in one of its side walls (the spine's rooms: never across
		# their way through), not spine.
		var side: Array = TombKit.door_side(host, d)
		var key := "heart" if str(host.get("room_kind", "")) == "heart" else ("spine" if bool(host.get("spine", false)) else "side way")
		if key == "spine":
			var rooms: Array = []
			for id in lay.spine:
				if str(lay.pieces[id].kind) == "room":
					rooms.append(int(id))
			key = "the spine's room %d before the heart" % (rooms.size() - 1 - rooms.find(int(host.id)))
		hosts[key] = int(hosts.get(key, 0)) + 1
		if str(host.kind) != "room" or str(host.get("room_kind", "")) == "hearth" or int(host.get("floor", 0)) != 0 or absf(float(side[1])) > 0.01 \
				or (bool(host.get("spine", false)) and not str(side[0]) in ["left", "right"]) or bool(d.get("spine", false)) or bool(stair.get("spine", false)) \
				or int(d.a) != int(host.id) or int(d.b) != int(stair.id):
			door_ok = false
			print("  seed %d: the stair down leaves %s %d by its %s wall, %.2f m off its middle, spine %s" % [s, host.get("room_kind", host.kind), host.id, side[0], float(side[1]), str(d.get("spine"))])
		# The flight: straight on down drop_m, whole modules, into floor two's
		# first room.
		if str(stair.kind) != "stair" or absf(float(stair.y0) - float(host.y0)) > 0.01 or absf(float(stair.y0) - float(stair.y1) - drop) > 0.01 \
				or absf(float(stair.len) / m - roundf(float(stair.len) / m)) > 1e-3 or str(foot.kind) != "room" or absf(float(foot.y0) - float(stair.y1)) > 0.01:
			flight_ok = false
			print("  seed %d: the flight %s" % [s, str(stair)])
		# Floor two: below the room it leaves, apart from floor one in plan,
		# reached only through the stair's door.
		var f2: Array = (fl[1] as Dictionary).pieces
		for id in f2:
			var pc: Dictionary = lay.pieces[id]
			if maxf(float(pc.y0), float(pc.y1)) > float(host.y0) + 0.01 and int(id) != int(stair.id):
				below_ok = false
				print("  seed %d: floor two's %s %d at %.1f, over the floor it leaves (%.1f)" % [s, pc.kind, id, maxf(float(pc.y0), float(pc.y1)), float(host.y0)])
			for id1 in (fl[0] as Dictionary).pieces:
				if int(id) == int(stair.id) and int(id1) == int(host.id):
					continue
				if TombKit.outer(pc).grow(-0.02).intersects(TombKit.outer(lay.pieces[id1]).grow(-0.02)):
					apart_ok = false
					print("  seed %d: floor two's %d and floor one's %d overlap in plan" % [s, id, id1])
		var seen := _reach(lay, int(dsc.door))
		var seen_all := _reach(lay, -1)
		for id in f2:
			if seen.has(int(id)) or not seen_all.has(int(id)):
				only_ok = false
		# Floor one as built: every piece of a one-floor tomb of the seed where
		# it was; only the room the stair leaves has a door more.
		TombFloors.FLOORS["count"] = 1
		var one := TombKit.layout(int(s))
		TombFloors.FLOORS["count"] = want
		var f1: Array = (fl[0] as Dictionary).pieces
		if f1.size() != (one.pieces as Array).size():
			asbuilt_ok = false
		else:
			for id in f1:
				var a: Dictionary = lay.pieces[id]
				var b: Dictionary = one.pieces[id]
				var extra := 1 if int(id) == int(host.id) else 0
				if (a.c as Vector2) != (b.c as Vector2) or (a.dir as Vector2) != (b.dir as Vector2) or float(a.len) != float(b.len) or float(a.half) != float(b.half) \
						or float(a.y0) != float(b.y0) or str(a.get("room_kind", "")) != str(b.get("room_kind", "")) or (a.doors as Array).size() != (b.doors as Array).size() + extra:
					asbuilt_ok = false
					print("  seed %d: floor one's piece %d is not as a one-floor tomb lays it" % [s, id])
					break
		# Floor two's rooms: their wall sconces by the rule; no hearth, no
		# heart; the holders all sconces.
		var in_room := {}
		for h in lay.holders:
			if str(h.kind) != "sconce":
				hearth_ok = false
			if bool(h.get("room", false)):
				in_room[int(h.piece)] = int(in_room.get(int(h.piece), 0)) + 1
		for id in f2:
			var pc: Dictionary = lay.pieces[id]
			if str(pc.kind) != "room":
				continue
			rooms2 += 1
			if str(pc.get("room_kind", "")) in ["hearth", "heart"]:
				hearth_ok = false
				print("  seed %d: a %s on floor two" % [s, pc.room_kind])
			if int(in_room.get(int(id), 0)) != TombFloors.sconces_wanted(lay, pc):
				sconce_ok = false
				print("  seed %d: floor two's %s %d has %d sconces, wants %d" % [s, pc.room_kind, id, int(in_room.get(int(id), 0)), TombFloors.sconces_wanted(lay, pc)])
		# The room the stair leaves keeps its own.
		if int(in_room.get(int(host.id), 0)) != TombFloors.sconces_wanted(lay, host):
			sconce_ok = false
			print("  seed %d: the room the stair leaves has %d sconces" % [s, int(in_room.get(int(host.id), 0))])
		var n2 := 0
		for r in lay.residents:
			if TombFloors.floor_of(lay, int(r.piece)) == 1:
				n2 += 1
		res2 += n2
		res1 += (lay.residents as Array).size() - n2
		if n2 == 0:
			no_res.append(s)
		# The boss stays on floor one: its lair and its tunnels' holes.
		var l: Dictionary = lay.get("lair", {})
		if not l.is_empty() and TombFloors.floor_of(lay, int(l.piece)) != TombFloors.BOSS_FLOOR:
			boss_ok = false
		for hd in (lay.get("tunnels", {}) as Dictionary).get("holes", []):
			if TombFloors.floor_of(lay, int(hd.piece)) != TombFloors.BOSS_FLOOR:
				boss_ok = false
	var n_s := seeds.size()
	ok(floors_ok, "%d seeds: every dungeon has descent.json floors.count floors (%d), a stair down to the second" % [n_s, want])
	ok(door_ok, "the stair down leaves a floor-one room past the hearth room by a door centred in a side wall, never spine (left from: %s)" % str(hosts))
	ok(flight_ok, "a flight straight on down %.1f m (floors.drop_m) from that room's floor, in whole modules, into floor two's first room" % drop)
	ok(below_ok, "floor two lies below: every floor of it under the floor the stair leaves")
	ok(apart_ok, "nothing of floor two over or under floor one in plan (one floor grid holds both)")
	ok(only_ok, "floor two is reached only through the stair's door")
	ok(asbuilt_ok, "floor one is the tomb as built: every piece where a one-floor tomb of the seed lays it, only the room the stair leaves with a door more")
	ok(sconce_ok, "every room on floor two has its wall sconces by the rule, and the room the stair leaves keeps its own round its new door (%.1f rooms a floor two)" % (float(rooms2) / maxf(n_s, 1)))
	ok(hearth_ok, "no second hearth: no hearth or heart on floor two, every holder a wall sconce (§EX.4)")
	ok(res2 > 0 and no_res.size() <= n_s / 10, "floor two has its own residents (%.1f a floor, against floor one's %.1f; none in %d tombs)" % [float(res2) / maxf(n_s, 1), float(res1) / maxf(n_s, 1), no_res.size()])
	ok(boss_ok, "the boss's lair and every hole of its tunnels on floor one (TombFloors.BOSS_FLOOR; §FM.10 call 4 open)")
	print("  layouts: %d ms" % (Time.get_ticks_msec() - t0))


## The pieces reached from the hearth room through the doors, never
## through door `skip` (-1: through every door).
func _reach(lay: Dictionary, skip: int) -> Dictionary:
	var seen := {0: true}
	var stack := [0]
	while not stack.is_empty():
		var id: int = stack.pop_back()
		for di in lay.pieces[id].doors:
			if int(di) == skip:
				continue
			var d: Dictionary = lay.doors[di]
			for o in [int(d.a), int(d.b)]:
				if o >= 0 and not seen.has(o):
					seen[o] = true
					stack.append(o)
	return seen


# --- 2. The walks ---------------------------------------------------------------

func _walks(seeds: Array) -> void:
	var world_node := get_root().get_node("World")
	var t0 := Time.get_ticks_msec()
	var out_ok: Array = []
	var shut_ok: Array = []
	var down_ok: Array = []
	var down_m: Array = []
	var fails_out: Array = []
	var fails_shut: Array = []
	var fails_down: Array = []
	for s in seeds:
		var lay := TombKit.layout(int(s))
		if not lay.has("descent"):
			fails_down.append("%d: no stair down" % s)
			continue
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = Vector2i(4, 4)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_root().add_child(vp)
		var root := Node3D.new()
		vp.add_child(root)
		root.add_child(CrawlerMain.collision_body(TombBuild.build(lay, true)))
		var fires := CrawlerFires.new()
		fires.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(fires)
		fires.build(world_node, lay)
		var seat: Array = lay.rescuer
		var rr := RandomNumberGenerator.new()
		rr.seed = hash([int(lay.seed), "rescuer"])
		var pal := CloakedFigure.roll_palette(rr, CloakedFigure.tribe_family(int(lay.seed)))
		HearthFolk.make(root, "Rescuer", seat[0], float(seat[1]), float(CrawlerMain.RES.get("height_m", 1.62)), pal, "")
		# The fork as the game builds it: the seal in the stair's mouth (and
		# the way out's, with gate_surface).
		# (Processing: a disabled body leaves the physics world. Nothing is lit,
		# so it never opens by itself.)
		var fork := Fork.new()
		root.add_child(fork)
		fork.build(lay, fires)
		await physics_frame
		await physics_frame
		var space := vp.find_world_3d().direct_space_state
		var ex: Dictionary = lay.exits[0]
		var wk: Vector3 = (lay.wake as Array)[0]
		var foot_at := _foot_target(lay)
		var grid := _grid(lay, space)
		# The way out, every holder cold, the seal standing.
		var p_out := _path(lay, grid, wk, func(q: Vector3) -> bool: return WayOut.in_opening(ex, q), (ex.p as Vector3))
		if p_out.is_empty():
			fails_out.append("%d: no route" % s)
		else:
			var w := await _walk_body(lay, root, p_out, func(q: Vector3) -> bool: return WayOut.in_opening(ex, q))
			if bool(w.ok):
				out_ok.append(s)
			else:
				fails_out.append("%d: %s" % [s, w.why])
		# Floor two, the seal standing: no way there.
		var p_shut := _path(lay, grid, wk, func(q: Vector3) -> bool: return q.distance_to(foot_at) < 0.6, foot_at)
		if p_shut.is_empty():
			shut_ok.append(s)
		else:
			fails_shut.append(s)
		# The seal gone (floor one lit): floor two's first room, down the stair.
		fork.open_now(true)
		await physics_frame
		await physics_frame
		grid = _grid(lay, space)
		var p_down := _path(lay, grid, wk, func(q: Vector3) -> bool: return q.distance_to(foot_at) < 0.6, foot_at)
		if p_down.is_empty():
			fails_down.append("%d: no route" % s)
		else:
			var w2 := await _walk_body(lay, root, p_down, func(q: Vector3) -> bool: return Vector2(q.x - foot_at.x, q.z - foot_at.z).length() < 0.6 and absf(q.y - foot_at.y) < 0.4)
			if bool(w2.ok):
				down_ok.append(s)
				down_m.append(float(w2.m))
			else:
				fails_down.append("%d: %s" % [s, w2.why])
		NodeRelease.free_later(vp)
	down_m.sort()
	var med := float(down_m[down_m.size() / 2]) if not down_m.is_empty() else 0.0
	ok(fails_out.is_empty(), "%d seeds: with every holder cold and the seal standing, your body walks from the wake spot to the way out every time (fork.gate_surface false: never gated)%s" % [seeds.size(), "" if fails_out.is_empty() else ": " + ", ".join(fails_out)])
	ok(fails_shut.is_empty(), "and no way for your capsule from the wake spot to floor two while the seal stands (%d of %d)%s" % [shut_ok.size(), seeds.size(), "" if fails_shut.is_empty() else ": reached in " + str(fails_shut)])
	ok(fails_down.is_empty(), "the seal gone, your body walks from the wake spot down the stair into floor two's first room every time (median %.0f m)%s" % [med, "" if fails_down.is_empty() else ": " + ", ".join(fails_down)])
	print("  the walks: %d s for %d tombs" % [(Time.get_ticks_msec() - t0) / 1000, seeds.size()])


## Where the walk down aims: floor two's first room, a metre and a half in
## from the foot of the flight, on its floor.
static func _foot_target(lay: Dictionary) -> Vector3:
	var dsc: Dictionary = lay.descent
	var b: Vector3 = dsc.bottom
	var dn: Vector3 = dsc.down
	return b + dn * (Delves.WALL + 1.5)


## The walk grid (crawler_check's way: open where your capsule stands clear
## on the floor): {"astar", "fy" (each cell's floor), "w", "h", "o" (the
## corner)}.
func _grid(lay: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var g := CELL_M
	var bounds := Delves.rect_of(lay.pieces[0], 2.0)
	for pc in lay.pieces:
		bounds = bounds.merge(Delves.rect_of(pc, 2.0))
	bounds = bounds.grow(TombBuild.OUTSIDE_M + 1.0)
	var w := ceili(bounds.size.x / g) + 1
	var h := ceili(bounds.size.y / g) + 1
	var fy := PackedFloat32Array()
	fy.resize(w * h)
	fy.fill(NAN)
	var by_ray := PackedByteArray()
	by_ray.resize(w * h)
	for pc in lay.pieces:
		var rr := Delves.rect_of(pc, 0.0)
		var c0 := _cell(bounds, rr.position.x, rr.position.y)
		var c1 := _cell(bounds, rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := bounds.position + Vector2(i, j) * g
				var aa := Delves.along_across(pc, q)
				if aa.x < 0.0 or aa.x > float(pc.len) or absf(aa.y) > float(pc.half):
					continue
				fy[j * w + i] = Delves.floor_of(pc, aa.x)
				by_ray[j * w + i] = 1 if str(pc.kind) == "stair" else 0
	for d in lay.doors:
		var dp: Vector2 = d.p
		var dn: Vector2 = d.n
		var reach := Vector2(Delves.WALL * 0.5 + 0.05, Delves.WALL * 0.5 + (TombBuild.OUTSIDE_M if int(d.b) < 0 else 0.05))
		var ext := float(d.half) + 0.1
		var rr := Rect2(dp - dn * reach.x - Delves.perp(dn) * ext, Vector2.ZERO).expand(dp + dn * reach.y + Delves.perp(dn) * ext)
		var c0 := _cell(bounds, rr.position.x, rr.position.y)
		var c1 := _cell(bounds, rr.end.x, rr.end.y)
		for j in range(c0.y, c1.y + 1):
			for i in range(c0.x, c1.x + 1):
				var q := bounds.position + Vector2(i, j) * g
				var rel := q - dp
				var along := rel.dot(dn)
				if along < -reach.x or along > reach.y or absf(rel.dot(Delves.perp(dn))) > float(d.half):
					continue
				if is_nan(fy[j * w + i]):
					fy[j * w + i] = float(d.y)
					by_ray[j * w + i] = 1
	var qs := PhysicsShapeQueryParameters3D.new()
	qs.shape = CrawlerPlayer.body_shape()
	qs.collision_mask = 1
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(g, g)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var floor_at := PackedFloat32Array()
	floor_at.resize(w * h)
	floor_at.fill(NAN)
	for k in w * h:
		if is_nan(fy[k]):
			continue
		var c := Vector2i(k % w, k / w)
		var q := bounds.position + Vector2(c) * g
		var y := fy[k]
		if by_ray[k] == 1:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.0, q.y), Vector3(q.x, y - 0.8, q.y)))
			if hit.is_empty():
				continue
			y = (hit.position as Vector3).y
		floor_at[k] = y
		qs.transform = Transform3D(Basis.IDENTITY, Vector3(q.x, y + LIFT_M + CrawlerPlayer.STAND_HEIGHT * 0.5, q.y))
		if space.intersect_shape(qs, 1).is_empty():
			astar.set_point_solid(c, false)
	return {"astar": astar, "fy": floor_at, "w": w, "h": h, "o": bounds.position}


static func _cell(bounds: Rect2, x: float, z: float) -> Vector2i:
	return Vector2i(roundi((x - bounds.position.x) / CELL_M), roundi((z - bounds.position.y) / CELL_M))


## A route on `grid` from `from` to the open cell nearest `near` that
## `goal` holds for: [Vector3...] (cell middles on their floors), [] if
## your capsule has none.
func _path(_lay: Dictionary, grid: Dictionary, from: Vector3, goal: Callable, near: Vector3) -> Array:
	var astar: AStarGrid2D = grid.astar
	var w := int(grid.w)
	var h := int(grid.h)
	var o: Vector2 = grid.o
	var fy: PackedFloat32Array = grid.fy
	var start := Vector2i(roundi((from.x - o.x) / CELL_M), roundi((from.z - o.y) / CELL_M))
	if start.x < 0 or start.y < 0 or start.x >= w or start.y >= h or astar.is_point_solid(start):
		return []
	var best := Vector2i(-1, -1)
	var best_d := INF
	var r := 12
	var nc := Vector2i(roundi((near.x - o.x) / CELL_M), roundi((near.z - o.y) / CELL_M))
	for j in range(maxi(nc.y - r, 0), mini(nc.y + r, h - 1) + 1):
		for i in range(maxi(nc.x - r, 0), mini(nc.x + r, w - 1) + 1):
			var c := Vector2i(i, j)
			if astar.is_point_solid(c) or is_nan(fy[j * w + i]):
				continue
			var q := Vector3(o.x + i * CELL_M, fy[j * w + i], o.y + j * CELL_M)
			if not goal.call(q):
				continue
			var dd := q.distance_to(near)
			if dd < best_d:
				best_d = dd
				best = c
	if best.x < 0:
		return []
	var ids := astar.get_id_path(start, best, false)
	if ids.is_empty():
		return []
	var out: Array = []
	for c in ids:
		out.append(Vector3(o.x + c.x * CELL_M, fy[c.y * w + c.x], o.y + c.y * CELL_M))
	return out


## Your body along `path` until `arrived` holds where it stands (crawler
## _check's walk: CrawlerPlayer.step_body at a walk, its floor rules):
## {"ok", "m", "why"}.
func _walk_body(lay: Dictionary, root: Node3D, path: Array, arrived: Callable) -> Dictionary:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.shape = CrawlerPlayer.body_shape()
	cs.position = Vector3(0.0, CrawlerPlayer.STAND_HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	CrawlerPlayer.floor_rules(body)
	root.add_child(body)
	body.global_position = (path[0] as Vector3) + Vector3(0.0, 0.05, 0.0)
	await physics_frame
	var k := 0
	var walked := 0.0
	var best := INF
	var stall := 0
	var left := 0.0
	for i in range(1, path.size()):
		left += (path[i] as Vector3).distance_to(path[i - 1])
	var steps := int(left / maxf(CrawlerPlayer.WALK_SPEED, 0.5) * 60.0 * 2.0) + 600
	var result := {"ok": false, "m": 0.0, "why": "ran out of time"}
	for i in steps:
		var pos := body.global_position
		while k < path.size() - 1 and Vector2(pos.x - (path[k] as Vector3).x, pos.z - (path[k] as Vector3).z).length() < 0.35:
			k += 1
		var to: Vector3 = (path[k] as Vector3) - pos
		to.y = 0.0
		var wish := to.normalized() if to.length() > 0.02 else Vector3.ZERO
		CrawlerPlayer.step_body(body, wish, CrawlerPlayer.WALK_SPEED, DT)
		walked += body.global_position.distance_to(pos)
		if arrived.call(body.global_position):
			result = {"ok": true, "m": walked, "why": ""}
			break
		var togo := float(path.size() - k) * CELL_M + to.length()
		if togo < best - 0.05:
			best = togo
			stall = 0
		else:
			stall += 1
			if stall > 120:
				result = {"ok": false, "m": walked, "why": "stuck at %s (piece %d)" % [str(body.global_position.snapped(Vector3.ONE * 0.01)), TombKit.piece_at(lay, body.global_position)]}
				break
	body.queue_free()
	return result


# --- 3, 4, 5. In the scene ---------------------------------------------------------

func _scene(gate_surface: bool) -> void:
	var was: Variant = Fork.F.get("gate_surface", false)
	Fork.F["gate_surface"] = gate_surface
	print("== the scene, fork.gate_surface %s" % str(gate_surface))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	var lay := main.lay
	var fires := main.fires
	var res := main.residents
	var fork := main.fork
	var p := main.player
	p._invulnerable = 1.0e9
	main.boss.auto = false
	var dsc: Dictionary = lay.get("descent", {})
	if fork == null or fork.down == null or dsc.is_empty():
		ok(false, "the fork and the seal on the way down are built (%s)" % str(dsc))
		Fork.F["gate_surface"] = was
		main.queue_free()
		await process_frame
		return
	var down := fork.down
	var dd: Dictionary = lay.doors[int(dsc.door)]
	var sd := Fork.surface_door(lay)
	var sdd: Dictionary = lay.doors[sd]
	var line := str(Fork.F.get("log_line", ""))
	var log0 := GameLog.entries.size()
	if not gate_surface:
		await _cold(main, dd, sdd)
		await _floor_two_first(main)
	# Floor one, every torch but one.
	var f1 := TombFloors.holders_on(lay, 0)
	var last := int(f1[-1])
	for i in f1:
		if int(i) != last:
			_light(main, fires.holders[int(i)])
	await _frames(4)
	var shut_both := _blocked(main, dd) and (not gate_surface or _blocked(main, sdd))
	ok(not fork.opened and not down.opened and shut_both and _lines(line, log0) == 0 and not res.cleared_floors.has(0) and not main.boss.released,
		"floor one lit but one (%d of %d): the way down still sealed%s, no fork line, the floor not cleared, the boss still out" % [f1.size() - 1, f1.size(), " and the way out too" if gate_surface else ""])
	if gate_surface:
		var wk: Vector3 = (lay.wake as Array)[0]
		var grid := _grid(lay, main.player.get_world_3d().direct_space_state)
		var ex: Dictionary = lay.exits[0]
		var p_out := _path(lay, grid, wk, func(q: Vector3) -> bool: return WayOut.in_opening(ex, q), (ex.p as Vector3))
		ok(fork.surface != null and _blocked(main, sdd) and p_out.is_empty() and res.nav.door_shut(sdd), "fork.gate_surface true: the way out's flight sealed at its foot too (its doorway blocked and shut on the floor grid, no way for your capsule from the wake spot to the way out)")
	# The last light.
	main.boss.auto = true
	var cleared_frame := -1
	_light(main, fires.holders[last])
	for i in 6:
		await physics_frame
		# (physics_frame comes before the frame's physics steps: what is seen
		# now was done on the frame before.)
		if cleared_frame < 0 and res.cleared_floors.has(0):
			cleared_frame = Engine.get_physics_frames() - 1
	var same := fork.opened and down.opened_frame == fork.opened_frame and (not gate_surface or (fork.surface != null and fork.surface.opened_frame == fork.opened_frame))
	ok(same and down.opened_frame >= 0 and absi(down.opened_frame - cleared_frame) <= 0, "the last light on floor one: %s on the very tick the floor is cleared (fork tick %d, cleared %d)" % ["the way down and the way out open" if gate_surface else "the way down opens", fork.opened_frame, cleared_frame])
	ok(down.sounded == 1 and down.voice.playing and (not gate_surface or fork.surface.sounded == 1), "the seal grinds as it goes, heard down the passages (audio.json stone_seal, %.0f m)" % down.voice.max_distance)
	# The log: the line once, after the floor's.
	var at_fork := -1
	var at_clear := -1
	var n_fork := 0
	for k in range(log0, GameLog.entries.size()):
		var tx := str((GameLog.entries[k] as Dictionary).get("text", ""))
		if tx == line:
			n_fork += 1
			at_fork = k
		if tx == str(Residents.CLEARED.get("log_line", "")):
			at_clear = k
	ok(n_fork == 1 and at_clear >= 0 and at_fork > at_clear, "the log's line once (\"%s\"), after the floor's (\"%s\")" % [line, str(Residents.CLEARED.get("log_line", ""))])
	# Sinking, then gone.
	var mid_y := 0.0
	var t := 0.0
	while not down.is_gone and t < 10.0:
		await process_frame
		t += get_root().get_process_delta_time()
		if down.sunk > 0.3 and down.sunk < 0.7:
			mid_y = down.slab.position.y
	await _frames(2)
	ok(mid_y < -0.3 and down.is_gone and not down.slab.visible and not _blocked(main, dd) and (not gate_surface or (fork.surface.is_gone and not _blocked(main, sdd))), "you see it go: the seal sinks into the floor (%.2f m down half way) and is gone in %.1f s (fork.seal.open_s), the doorway clear%s" % [mid_y, t, ", the way out's too" if gate_surface else ""])
	ok(not res.nav.door_shut(dd) and not res.ground.shut.has(int(dd.id)) and not main.boss.ground.shut.has(int(dd.id)), "the doorway open again on the floor grid and in the light's graph")
	var path := res.nav.path(_inside(lay, int(dsc.host), dd, 1.4), _foot_target(lay), false)
	ok(TombNav.reaches(path, _foot_target(lay), 0.8), "the floor grid now runs from the room the stair leaves down onto floor two (%.0f m)" % TombNav.length_of(path))
	await _frames(10)
	ok(main.boss.released and TombFloors.floor_of(lay, int((lay.get("lair", {}) as Dictionary).get("piece", 0))) == TombFloors.BOSS_FLOOR, "the boss driven home by floor one's last light (released), its lair on floor one where it was")
	ok(_lines(line, log0) == 1, "and still the one line")
	if not gate_surface:
		ok(not _blocked(main, sdd) and fork.surface == null, "fork.gate_surface false: the surface stair open throughout, before and after (no seal at its foot)")
		await _down_and_up(main)
	Fork.F["gate_surface"] = was
	main.queue_free()
	await process_frame
	await process_frame


## Kept (§FK.2): the scene before opened the fork and closed (its save
## kept, CrawlerSave in memory, as the tools keep it); Continue opens the
## same tomb with the way down open at once, quiet.
func _kept() -> void:
	var at := CrawlerSave.place
	var kept_open := bool(CrawlerSave.kept_value(at, "fork_open", false))
	var relit := (CrawlerSave.dungeon(at).get("relit", []) as Array).size()
	OS.set_environment("SEED", "")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	await _frames(5)
	var fork := main.fork
	var dd: Dictionary = main.lay.doors[int(main.lay.descent.door)]
	ok(kept_open and relit > 0, "the fork kept open in the game's save with the lights relit (fork_open %s, %d holders relit kept)" % [str(kept_open), relit])
	ok(CrawlerSave.continued and fork != null and fork.opened and fork.down.is_gone and fork.down.sounded == 0 and _lines(str(Fork.F.get("log_line", "")), 0) == 0,
		"Continue: the same tomb, the way down open at once and quiet (the seal gone, no grinding, no line again)")
	ok(not _blocked(main, dd) and not main.residents.nav.door_shut(dd) and not main.residents.ground.shut.has(int(dd.id)), "its doorway open to you, the floor grid and the light's graph")
	main.queue_free()
	await process_frame
	await process_frame


## Floor one cold: the seal standing in the stair's mouth, plain and dark,
## and the surface stair open.
func _cold(main: CrawlerMain, dd: Dictionary, sdd: Dictionary) -> void:
	var fork := main.fork
	var down := fork.down
	var res := main.residents
	ok(TombFloors.lit_on(main.fires, main.lay, 0).x == 0 and not fork.opened and not down.opened, "floor one's torches cold (%d): the fork shut" % TombFloors.holders_on(main.lay, 0).size())
	ok(_blocked(main, dd), "the way down sealed: a stone seal across the stair's mouth (its collision fills the doorway)")
	ok(res.nav != null and res.nav.door_shut(dd) and res.ground.shut.has(int(dd.id)), "the doorway shut on the floor grid and in the light's graph (nothing walks or paths through the seal)")
	var lights := 0
	for l in fork.find_children("*", "Light3D", true, false):
		lights += 1
	var mat := down.slab.material_override
	ok(lights == 0 and mat == RuinBuilder.material_lit() and down.slab.visible, "nothing points to it (§FG): no light on it, the tomb's own lit stone, one plain slab")
	ok(not _blocked(main, sdd) and fork.surface == null, "the surface stair open (fork.gate_surface false: never gated, §EX.5)")


## Floor two's torches first, every one, floor one's cold: floor two
## cleared on its own, the way down still sealed.
func _floor_two_first(main: CrawlerMain) -> void:
	var lay := main.lay
	var fires := main.fires
	var res := main.residents
	var log0 := GameLog.entries.size()
	var f2 := TombFloors.holders_on(lay, 1)
	for i in f2:
		_light(main, fires.holders[int(i)])
	await _frames(4)
	var c2 := TombFloors.lit_on(fires, lay, 1)
	var counted := false
	for k in range(log0, GameLog.entries.size()):
		if str((GameLog.entries[k] as Dictionary).get("text", "")) == "%d of %d lights burn again." % [c2.y, c2.y]:
			counted = true
	ok(res.cleared_floors.has(1) and not res.cleared_floors.has(0) and not res.cleared and _lines(str(Residents.CLEARED.get("log_line", "")), log0) == 1,
		"floor two's torches all lit (%d), floor one's cold: floor two cleared on its own (its line once), floor one not" % f2.size())
	ok(counted, "the log counts floor two's lights as its own (\"%d of %d lights burn again.\")" % [c2.y, c2.y])
	ok(not main.fork.opened and _blocked(main, lay.doors[int(lay.descent.door)]) and not main.boss.released, "its torches count toward its own cleared test only: the way down still sealed, the boss still out")


## Down the stair onto floor two and back up to the matching stair's mouth
## on floor one, your own body.
func _down_and_up(main: CrawlerMain) -> void:
	var lay := main.lay
	var dsc: Dictionary = lay.descent
	var dd: Dictionary = lay.doors[int(dsc.door)]
	var p := main.player
	p.typing = false
	p.ui_open = false
	var top := _inside(lay, int(dsc.host), dd, 1.5)
	var bottom := _foot_target(lay)
	var r1 := await _walk_leg(p, top, bottom)
	var on2 := TombFloors.floor_at(lay, p.global_position)
	ok(bool(r1.ok) and on2 == 1 and absf(p.global_position.y - float((dsc.bottom as Vector3).y)) < 0.3, "your body walks down the stair onto floor two (at %s, floor %d, %.1f m below)" % [str(r1.at), on2 + 1, float((dsc.top as Vector3).y) - p.global_position.y])
	var r2 := await _walk_leg(p, bottom, top)
	var on1 := TombFloors.floor_at(lay, p.global_position)
	ok(bool(r2.ok) and on1 == 0 and Vector2(p.global_position.x - (dsc.top as Vector3).x, p.global_position.z - (dsc.top as Vector3).z).length() < 2.2, "and back up it to the matching stair's mouth on floor one (at %s, %.1f m from it)" % [str(r2.at), Vector2(p.global_position.x - (dsc.top as Vector3).x, p.global_position.z - (dsc.top as Vector3).z).length()])
	var hearths := 0
	var on_one := true
	for f in main.get_tree().get_nodes_in_group(Campfire.GROUP):
		var n := f as Node3D
		if n != null and n.has_meta("crawler_hearth"):
			hearths += 1
			if TombFloors.floor_at(lay, n.global_position + Vector3(0.0, 0.3, 0.0)) != 0:
				on_one = false
	ok(hearths == 1 and on_one, "one hearth in the dungeon (%d), on floor one: floor two has none (§EX.4)" % hearths)


## A point just inside piece `pid` through door `d`, `m` in, on its floor.
static func _inside(lay: Dictionary, pid: int, d: Dictionary, m: float) -> Vector3:
	var pc: Dictionary = lay.pieces[pid]
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var into := n2 if int(d.b) == pid else -n2
	var q := p2 + into * m
	return Vector3(q.x, Delves.floor_of(pc, Delves.along_across(pc, q).x), q.y)


## Is doorway `d` blocked (a ray across its gap, through the wall at
## chest height, hits something there)?
func _blocked(main: CrawlerMain, d: Dictionary) -> bool:
	var p2: Vector2 = d.p
	var n2: Vector2 = d.n
	var y := float(d.y) + 1.1
	var a := Vector3(p2.x - n2.x * 0.7, y, p2.y - n2.y * 0.7)
	var b := Vector3(p2.x + n2.x * 0.7, y, p2.y + n2.y * 0.7)
	var q := PhysicsRayQueryParameters3D.create(a, b, PropCollision.WORLD_LAYER)
	q.exclude = [main.player.get_rid()]
	q.hit_from_inside = true
	return not main.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## How many of the log's lines since `from` are `text`.
func _lines(text: String, from: int) -> int:
	var n := 0
	for k in range(from, GameLog.entries.size()):
		if str((GameLog.entries[k] as Dictionary).get("text", "")) == text:
			n += 1
	return n


## Holder `h` lit (the swing's catch, as a torch would).
func _light(main: CrawlerMain, h: Node3D) -> void:
	FireStore.swing_light(h, float(main.world.get("days")))
	for i in 600:
		FireStore.tick(self, DT, h.global_position)
		if FireStore.is_lit(h):
			return


## Walk the body from `from` to `to` like a player would (crawler_check's
## _walk_leg): {"ok", "m", "at"}.
func _walk_leg(p: CrawlerPlayer, from: Vector3, to: Vector3, max_s := 20.0) -> Dictionary:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	p.spawn_flat(from, atan2(-flat.x, -flat.y), 0.0)
	await _frames(3)
	Input.action_press("move_forward")
	var best := INF
	var since := 0
	var dodge := 0
	var side := 1.0
	var ok_ := false
	var start := p.global_position
	for i in int(max_s * 60.0):
		var here := p.global_position
		var go := Vector2(to.x - here.x, to.z - here.z)
		if go.length() < 0.45 and absf(here.y - to.y) < 0.7:
			ok_ = true
			break
		p._yaw = atan2(-go.x, -go.y)
		if dodge > 0:
			dodge -= 1
			if dodge == 0:
				Input.action_release("move_left")
				Input.action_release("move_right")
		elif since > 30:
			side = -side
			dodge = 26
			since = 0
			Input.action_press("move_left" if side < 0.0 else "move_right")
		await physics_frame
		var dd := Vector2(to.x - p.global_position.x, to.z - p.global_position.z).length()
		if dd < best - 0.05:
			best = dd
			since = 0
		else:
			since += 1
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	return {"ok": ok_, "m": start.distance_to(p.global_position), "at": p.global_position.snapped(Vector3.ONE * 0.01)}

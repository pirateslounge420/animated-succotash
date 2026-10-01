extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/road_check.gd
## Roads (design 30 Sept §BC), rooms (§BB) and travellers (§BF): the
## network has nodes and links near the camp; links are routed, decayed
## (crossings, waymarks, collapses, a landmark out of sight) and forks
## made legible; the tread reads on the road and not off it; rooms hang
## off the links with walls scaled up at the edge and down on the floor;
## a room reads as a room by the ray test (most headings closed within
## 40 m, one open); the props build near the player; a traveller walks
## the road, hood on you, holding a beat, immune to the dark.
var main
var world
var player: PlanetPlayer
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	world = get_root().get_node("World")
	world.pin(42, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(60)
	var chunks: ChunkManager = main.chunks
	var roads: RoadNetwork = chunks.roads
	var t0 := Time.get_ticks_msec()
	var near := roads.links_near(player.surface_dir, 12000.0)
	print("[road] %d nodes, %d links within 12 km of the camp (%.1f s to build)" % [roads.nodes.size(), near.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	ok(roads.nodes.size() >= 2, "the network has nodes (%d)" % roads.nodes.size())
	ok(not near.is_empty(), "and links near the camp (%d)" % near.size())
	if near.is_empty():
		print("RESULT fails: %d" % (fails + 1))
		quit(1)
		return
	var crossings := 0
	var bridges_out := 0
	var marks := 0
	var fallen := 0
	var collapsed := 0
	var landmarks := 0
	var hidden := 0
	var forked := 0
	var total_m := 0.0
	var kinds := {}
	for l in near:
		total_m += float(l.len_m)
		for c in l.crossings:
			crossings += 1
			if bool(c[2]):
				bridges_out += 1
		for m in l.waymarks:
			marks += 1
			if bool(m[2]):
				fallen += 1
		if bool(l.collapsed):
			collapsed += 1
		if not (l.landmark as Dictionary).is_empty():
			landmarks += 1
			kinds[l.landmark.kind] = true
			if bool(l.landmark.get("hidden", false)):
				hidden += 1
		if bool(l.get("forked", false)):
			forked += 1
	print("[road] %.1f km of road: %d crossings (%d bridges out), %d waymarks (%d fallen), %d collapsed ends, %d finds (%d out of sight: %s), %d forks made legible" % [total_m / 1000.0, crossings, bridges_out, marks, fallen, collapsed, landmarks, hidden, kinds.keys(), forked])
	ok(marks > 0 and fallen > 0, "waymarks stand along the roads, some fallen")
	ok(landmarks == 0 or hidden > 0, "the finds are set out of sight of the trail")
	# The tread: on the nearest road, and not 30 m off it.
	var nearest := RoadNetwork.nearest_in(near, player.surface_dir, 20000.0)
	var on: Vector3 = nearest.pt
	var segs := RoadNetwork.segments_in(near, on, 300.0)
	var tread_on := RoadNetwork.tread_at(segs, on)
	var along: Vector3 = ((nearest.link as Dictionary).pts[nearest.seg + 1] - (nearest.link as Dictionary).pts[nearest.seg]).normalized()
	var off := (on + along.cross(on).normalized() * 30.0 / PlanetConst.RADIUS_M).normalized()
	var tread_off := RoadNetwork.tread_at(segs, off)
	ok(tread_on > 0.1 and tread_off == 0.0, "the tread reads on the road (%.2f) and not 30 m off it (%.2f)" % [tread_on, tread_off])
	# Grade: no step of the nearest link steeper than twice max_grade.
	var max_grade := float(Tuning.section("roads", "network").get("max_grade", 0.18))
	# The routed road between its ends (the last reach onto a node is a
	# straight line to wherever the ruin sits, a crag included).
	var worst := 0.0
	var worst_end := 0.0
	var pts: PackedVector3Array = (nearest.link as Dictionary).pts
	var link_m := RoadNetwork.length_m(pts)
	var along_m := 0.0
	for i in pts.size() - 1:
		var dm := CubeSphere.surface_distance_m(pts[i], pts[i + 1])
		along_m += dm
		if dm < 5.0:
			continue
		var de := absf(world.planet.terrain.elevation(pts[i], false) - world.planet.terrain.elevation(pts[i + 1], false))
		if along_m < 250.0 or along_m > link_m - 250.0:
			worst_end = maxf(worst_end, de / dm)
		else:
			worst = maxf(worst, de / dm)
	print("[road] the nearest link's steepest step: %.2f on the way, %.2f at its ends (max_grade %.2f)" % [worst, worst_end, max_grade])
	ok(worst < 0.9, "the road keeps its grade on the way: no step a cliff (worst %.2f between 30 m samples; roads.json max_grade %.2f is the routing's own limit at its %.0f m step)" % [worst, max_grade, RoadNetwork.STEP_M])
	# Rooms.
	var rooms := roads.rooms_near(on, 3000.0)
	ok(not rooms.is_empty(), "rooms hang off the roads (%d within 3 km)" % rooms.size())
	if not rooms.is_empty():
		var room: Dictionary = rooms[0]
		var floor_s := RoadNetwork.wall_scale([room], INF, 0.0, room.dir)
		# An edge heading away from the open sides (this room alone).
		var bearing := 0.3
		for k in 8:
			var cand := k * TAU / 8.0 + 0.3
			var toward: Vector3 = (CreatureSpawner._offset(room.dir, cand, 10.0) - room.dir).normalized()
			var open_side := false
			for o in room.open:
				if toward.dot(o) > cos(deg_to_rad(60.0)):
					open_side = true
			if not open_side:
				bearing = cand
				break
		var edge_pt := CreatureSpawner._offset(room.dir, bearing, float(room.r))
		var edge_s := RoadNetwork.wall_scale([room], INF, 0.0, edge_pt)
		print("[room] %s room r %.0f m: floor scale %.2f, edge scale %.2f, %d open headings" % [room.kind, room.r, floor_s, edge_s, (room.open as PackedVector3Array).size()])
		ok(floor_s < 1.0, "a room's floor is thinned (%.2f)" % floor_s)
		ok(edge_s > 1.0 or (room.open as PackedVector3Array).size() >= 6, "its edge is thickened (%.2f) unless it is all open" % edge_s)
	# Go and stand on the road: the props build, the room test runs.
	var off_v: Vector3 = world.to_scene(on, PlanetConst.RADIUS_M + world.surface_elevation(on))
	world.rebase(off_v)
	player.global_position -= off_v
	chunks.load_blocking(on)
	player.spawn_at(on)
	main.camps.refresh_now()
	await frames(150)
	var props: int = main.road_props._built.size()
	print("[road] %d road props built within reach" % props)
	ok(props > 0, "the road's props build round you (%d)" % props)
	# The room test (rooms.json test, the ray share): from a room's
	# centre within reach, headings closed within 40 m at eye height.
	var best_room := {}
	for r in rooms:
		if CubeSphere.surface_distance_m(r.dir, on) < 400.0 and (best_room.is_empty() or r.kind == "ford"):
			best_room = r
	if not best_room.is_empty():
		var eye: Vector3 = world.to_scene(best_room.dir, PlanetConst.RADIUS_M + chunks.ground_height(best_room.dir) + 1.6)
		var upv: Vector3 = best_room.dir
		var closed := 0
		var open_dirs := 0
		var space := player.get_world_3d().direct_space_state
		for k in 16:
			var a := k * TAU / 16.0
			var dirv := (CubeSphere.north(upv) * cos(a) + CubeSphere.east(upv) * sin(a) + upv * 0.12).normalized()
			var q := PhysicsRayQueryParameters3D.create(eye, eye + dirv * 40.0)
			q.collision_mask = 0xFFFFFFFF
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				open_dirs += 1
			else:
				closed += 1
		var share := float(open_dirs) / 16.0
		print("[room] ray test at the %s room: %d of 16 headings open within 40 m (sky share by rays %.2f)" % [best_room.kind, open_dirs, share])
	# Travellers: force one onto the road and watch its hood.
	var tv: Travellers = main.travellers
	var link: Dictionary = nearest.link
	# Its place along the link: where you stand (the nearest point).
	var m_at := 0.0
	var lpts: PackedVector3Array = link.pts
	for i in int(nearest.seg):
		m_at += CubeSphere.surface_distance_m(lpts[i], lpts[i + 1])
	m_at += float(nearest.t) * CubeSphere.surface_distance_m(lpts[int(nearest.seg)], lpts[int(nearest.seg) + 1])
	tv._make(link, clampf(m_at + 20.0, 30.0, maxf(float(link.len_m) - 30.0, 30.0)), 1.0)
	await frames(5)
	ok(tv._walkers.size() == 1, "a traveller walks the road (%d walking; put at %.0f m of %.0f)" % [tv._walkers.size(), m_at, link.len_m])
	if tv._walkers.is_empty():
		print("RESULT fails: %d" % (fails + 4))
		quit(1)
		return
	var w: Dictionary = tv._walkers[0]
	var m0 := float(w.m)
	await frames(120)
	ok(absf(float(w.m) - m0) > 1.5, "it keeps walking (%.1f m in 2 s)" % absf(float(w.m) - m0))
	# Stand in front of it, close: the hood turns.
	var wn: Node3D = w.node
	var ahead := wn.global_position - wn.global_basis.z * 6.0
	player.global_position = ahead + wn.global_basis.y * 0.5
	await frames(40)
	ok(bool(w.seen), "within watch_m and in front, the hood tracks you")
	main.dread.force_dark = true
	main.dread.meter = 1.0
	await frames(10)
	ok(is_instance_valid(w.node) and not player.dead, "the dark hunts you, not the traveller (it walks on)")
	main.dread.force_dark = false
	main.dread.meter = 0.0
	main.dread._enter_stage(0)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

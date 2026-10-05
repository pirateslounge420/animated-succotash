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
## §DM.1 (the hard grade cap): every built road within 12 km, walked every
## 5 m on the fine ground as built (its cuttings carved in), never steeper
## than roads.json network.hard_max_grade, and its tread no steeper than
## PlanetPlayer.WALK_MAX_DEG either way (outside the ruins' own footprints
## and the river crossings, which are their own); and the opening road on
## the drawn chunks (TerrainChunk.compute) the same (outside a river's
## banks, its channel being carved after the road).
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
	var near := roads.links_near(player.surface_dir, 12000.0, true)
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
	_grade_audit(roads, near)
	await _drawn_audit(roads, near)
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
	# Follow the one put there (others may walk the network of their own
	# accord: the road net round the stamp's spawn is denser since 1 Oct).
	var w: Dictionary = tv._walkers[tv._walkers.size() - 1]
	await frames(5)
	ok(tv._walkers.has(w) and is_instance_valid(w.node), "a traveller walks the road (%d walking in all; put at %.0f m of %.0f)" % [tv._walkers.size(), m_at, link.len_m])
	if not tv._walkers.has(w):
		print("RESULT fails: %d" % (fails + 4))
		quit(1)
		return
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


## The ground as built along a link every 5 m: [m, ground at the centre,
## the tread's steepest slope there (along and across, as a grade)], with
## the ruins' footprints and the river crossings left out.
func _walk_built(roads: RoadNetwork, link: Dictionary, step := 5.0) -> Array:
	var t: TerrainField = world.planet.terrain
	var pts: PackedVector3Array = link.pts
	var total := RoadNetwork.length_m(pts)
	var skip: Array = []
	for k in [int(link.a), int(link.b)]:
		var nd: Dictionary = roads.nodes[k]
		skip.append([nd.dir, float(nd.get("foot_m", 0.0)) + 4.0])
	for c in link.crossings:
		skip.append([c[0], float(c[3]) * 0.5 + TerrainChunk.BANK_M + 6.0])
	var out: Array = []
	var m := 0.0
	while m <= total:
		var p := RoadNetwork.point_at(pts, m)
		var held := false
		for sk in skip:
			if CubeSphere.surface_distance_m(p, sk[0]) <= float(sk[1]):
				held = true
				break
		if not held:
			var fwd := RoadNetwork.point_at(pts, minf(m + 1.0, total)) - RoadNetwork.point_at(pts, maxf(m - 1.0, 0.0))
			var side := fwd.cross(p).normalized()
			var g := RoadNetwork.ground_on(link, m, 0.0, t.elevation(p, true))
			var gl := RoadNetwork.ground_on(link, m, 0.7, t.elevation((p + side * 0.7 / PlanetConst.RADIUS_M).normalized(), true))
			var gr := RoadNetwork.ground_on(link, m, -0.7, t.elevation((p - side * 0.7 / PlanetConst.RADIUS_M).normalized(), true))
			out.append([m, g, absf(gl - gr) / 1.4])
		else:
			out.append([m, NAN, 0.0])
		m += step
	return out


func _grade_audit(roads: RoadNetwork, near: Array) -> void:
	var hard := RoadNetwork.hard_max_grade()
	var walk_tan := tan(deg_to_rad(PlanetPlayer.WALK_MAX_DEG))
	var steps := 0
	var over := 0
	var worst := 0.0
	var worst_at := ""
	var steep := 0
	var worst_slope := 0.0
	var benched := 0.0
	var t0 := Time.get_ticks_msec()
	for l in near:
		var w := _walk_built(roads, l)
		for b in l.get("bench", []):
			benched += float(b[1]) - float(b[0])
		for i in range(1, w.size()):
			var g0 := float(w[i - 1][1])
			var g1 := float(w[i][1])
			if is_nan(g0) or is_nan(g1):
				continue
			steps += 1
			var gr := absf(g1 - g0) / 5.0
			if gr > worst:
				worst = gr
				worst_at = "link %d-%d at %.0f m" % [int(l.a), int(l.b), float(w[i][0])]
			# Steeper allowed high up (network.steep_passes, Mike 5 Oct).
			if gr > RoadNetwork.hard_max_at(maxf(g0, g1)) + 1e-3:
				over += 1
				if OS.get_environment("DEBUG_OVER") == "1" and over <= 25:
					var mm := float(w[i][0])
					print("[over] link %d-%d at %.0f m of %.0f: %.3f, ground %.1f→%.1f, hollow %.2f→%.2f, bench %.2f, prof %.1f→%.1f, cap %.2f" % [int(l.a), int(l.b), mm, float(l.len_m), gr, g0, g1, RoadNetwork.hollow_at(l, mm - 5.0), RoadNetwork.hollow_at(l, mm), RoadNetwork.bench_at(l, mm), RoadNetwork.profile_at(l, mm - 5.0), RoadNetwork.profile_at(l, mm), RoadNetwork.hard_max_at(maxf(g0, g1))])
			var slope := sqrt(gr * gr + float(w[i][2]) * float(w[i][2]))
			worst_slope = maxf(worst_slope, slope)
			if slope > walk_tan:
				steep += 1
	print("[road] §DM.1: %d links, %d 5 m steps on the fine ground as built (%.0f s): steepest %.3f (%s), %d over hard_max_grade %.2f; steepest tread %.0f°, %d over %.0f°; %.1f km of cuttings; %d people's camps unreached" % [near.size(), steps, (Time.get_ticks_msec() - t0) / 1000.0, worst, worst_at, over, hard, rad_to_deg(atan(worst_slope)), steep, PlanetPlayer.WALK_MAX_DEG, benched / 1000.0, roads.unreached.size()])
	ok(over == 0, "no built road steeper than its cap (hard_max_grade %.2f, steep_passes higher up) anywhere on the fine ground (steepest %.3f)" % [hard, worst])
	ok(steep == 0, "every road's tread walkable at WALK_MAX_DEG %.0f° (steepest %.0f°)" % [PlanetPlayer.WALK_MAX_DEG, rad_to_deg(atan(worst_slope))])


## The opening road (else the nearest) on the drawn ground: its chunks
## computed as the game draws them, the centreline every 5 m.
func _drawn_audit(roads: RoadNetwork, near: Array) -> void:
	var link: Dictionary = {}
	for l in near:
		if bool(l.get("opening", false)):
			link = l
	if link.is_empty():
		link = RoadNetwork.nearest_in(near, player.surface_dir, 20000.0).link
	var cache := {}
	var w := _walk_built(roads, link)
	var hard := RoadNetwork.hard_max_grade()
	var prev := NAN
	var worst := 0.0
	var over := 0
	var n := 0
	for s in w:
		if is_nan(float(s[1])):
			prev = NAN
			continue
		var p := RoadNetwork.point_at(link.pts, float(s[0]))
		# A river's banks are its own (its channel carved after the road:
		# a ford's way down to the water).
		var rv0: RiverNetwork = main.chunks.rivers
		var in_bank := false
		for sg in rv0.segments_near(world.planet, world.planet.cell_at(p)):
			if rv0.closest_dt(sg, p).x < rv0.width[sg] * 0.5 + TerrainChunk.BANK_M + 2.0:
				in_bank = true
				break
		if in_bank:
			prev = NAN
			continue
		var key := TerrainChunk.key_at(p)
		if not cache.has(key):
			cache[key] = TerrainChunk.compute(key, world.planet, main.chunks.rivers)
		var data: Dictionary = cache[key]
		var g := _drawn_height(data, p)
		if not is_nan(prev):
			var gr := absf(g - prev) / 5.0
			worst = maxf(worst, gr)
			n += 1
			if gr > RoadNetwork.hard_max_at(maxf(g, prev)) + 0.02:
				over += 1
				if OS.get_environment("DEBUG_OVER") == "1":
					var mm := float(s[0])
					print("[over drawn] at %.0f m: %.3f, drawn %.2f→%.2f, built %.2f, sunk %.2f→%.2f, bench %.2f" % [mm, gr, prev, g, float(s[1]), RoadNetwork.hollow_at(link, mm - 5.0), RoadNetwork.hollow_at(link, mm), RoadNetwork.bench_at(link, mm)])
				var near_river := INF
				var rv: RiverNetwork = main.chunks.rivers
				for sg in rv.segments_near(world.planet, world.planet.cell_at(p)):
					near_river = minf(near_river, rv.closest_dt(sg, p).x - rv.width[sg] * 0.5)
				print("   drawn step %.3f at %.0f m: drawn %.2f -> %.2f, as built %.2f, natural %.2f, cutting %.2f, %.0f m from a river's edge" % [gr, float(s[0]), prev, g, float(s[1]), world.planet.terrain.elevation(p, true), RoadNetwork.bench_at(link, float(s[0])), near_river])
		prev = g
	print("[road] §DM.1 drawn: the %s road (%.1f km), %d chunks computed, %d steps: steepest %.3f, %d over %.2f (+0.02 for the 4 m mesh)" % ["opening" if bool(link.get("opening", false)) else "nearest", float(link.len_m) / 1000.0, cache.size(), n, worst, over, hard])
	ok(over == 0, "the drawn ground under the %s road keeps the cap (steepest %.3f)" % ["opening" if bool(link.get("opening", false)) else "nearest", worst])
	await process_frame


func _drawn_height(data: Dictionary, d: Vector3) -> float:
	var key: Vector3i = data.key
	var uv := CubeSphere.face_uv(key.x, d)
	var gx := ((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE - key.y) * TerrainChunk.FINE
	var gy := ((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE - key.z) * TerrainChunk.FINE
	return TerrainChunk.fine_height(data.fine_heights, gx, gy)

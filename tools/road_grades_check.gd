extends SceneTree
## Run: STAMP=1 SEED=42 godot --headless --path . --fixed-fps 60 --script tools/road_grades_check.gd
## The roads' grades, holloways and holders (design 3 Oct §DM.2-4, Mike's
## 5 Oct calls: "make the roads a bit wider ... build out road grades,
## holloways, cairns and milestones"), on every link within 12 km of the
## camp:
##  - a road is kerbed for its last 400-800 m into a ruin, a camp or a
##    waypoint, a track from there to beyond_m, trodden beyond; its tread
##    (tread_info) is wider at a kerbed end than out on the trodden;
##  - every grade at least as wide as roads.json grades says (Mike's
##    widening);
##  - the trail vanishes only on the trodden, with a tell at both ends;
##  - a cairn at the bends, milestones on the track and kerbed stretches
##    with a notch per mile, the avenue's spots beside the kerbed run;
##  - the avenue's tree is one species per node, not native to its biome;
##  - holloways sink the tread (ground_on under the profile);
##  - near the player the kerb stones and milestones build (RoadProps);
##  - high ground lets a road climb steeper (network.steep_passes).

var main
var world
var player: PlanetPlayer
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	for i in 30:
		await physics_frame
	var roads: RoadNetwork = main.chunks.roads
	var near := roads.links_near(player.surface_dir, 12000.0, true)
	ok(not near.is_empty(), "links near the camp (%d)" % near.size())
	if near.is_empty():
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	var G: Dictionary = RoadNetwork.D.get("grades", {})
	var kerbed_ends := 0
	var kerbed_ok := 0
	var wider := 0
	var wider_of := 0
	var width_ok := true
	var vanish_n := 0
	var vanish_trodden := 0
	var tells := 0
	var bends := 0
	var miles := 0
	var miles_ok := 0
	var avenue := 0
	var hollows := 0
	var sunk_ok := 0
	var sunk_n := 0
	var lens := []
	for l in near:
		var total := float(l.len_m)
		lens.append(total)
		var g: Dictionary = l.get("grade", {})
		if g.is_empty():
			continue
		for name in ["trodden", "track", "kerbed"]:
			var r: Array = (G.get(name, {}) as Dictionary).get("width_m", [0, 9])
			var w := float((g.w as Dictionary)[name])
			width_ok = width_ok and w >= float(r[0]) - 1e-3 and w <= float(r[1]) + 1e-3
		for end in [0, 1]:
			var nd: Dictionary = roads.nodes[l.a if end == 0 else l.b]
			if not RoadNetwork.MAJOR_NODES.has(str(nd.kind)):
				continue
			kerbed_ends += 1
			var m := 20.0 if end == 0 else total - 20.0
			if RoadNetwork.grade_name_at(l, m) == "kerbed":
				kerbed_ok += 1
		# The tread: kerbed end vs the middle of a long link.
		if total > 3500.0 and (float(g.ka) >= 0.0 or float(g.kz) >= 0.0):
			var m_end := 30.0 if float(g.ka) >= 0.0 else total - 30.0
			var m_mid := total * 0.5
			var segs_end := RoadNetwork.segments_in([l], RoadNetwork.point_at(l.pts, m_end), 60.0)
			var segs_mid := RoadNetwork.segments_in([l], RoadNetwork.point_at(l.pts, m_mid), 60.0)
			var t_end := RoadNetwork.tread_info(segs_end, RoadNetwork.point_at(l.pts, m_end))
			var t_mid := RoadNetwork.tread_info(segs_mid, RoadNetwork.point_at(l.pts, m_mid))
			wider_of += 1
			if t_end.y > t_mid.y + 0.4 and t_end.z > t_mid.z:
				wider += 1
		for v in l.get("vanish", []):
			vanish_n += 1
			if RoadNetwork.grade_name_at(l, float(v[0])) == "trodden" and RoadNetwork.grade_name_at(l, float(v[1])) == "trodden":
				vanish_trodden += 1
		for wm in l.waymarks:
			match str(wm[3]) if wm.size() > 3 else "":
				"tell":
					tells += 1
				"bend":
					bends += 1
				"mile":
					miles += 1
					if wm.size() > 4 and int(wm[4]) >= 1:
						miles_ok += 1
		avenue += (l.get("avenue", PackedVector3Array()) as PackedVector3Array).size()
		for hw in l.get("hollow", []):
			hollows += 1
			var mm := (float(hw[0]) + float(hw[1])) * 0.5
			var prof := RoadNetwork.profile_at(l, mm)
			if is_nan(prof):
				continue
			sunk_n += 1
			var on := RoadNetwork.ground_on(l, mm, 0.0, prof + 5.0)
			if on < prof - float(hw[2]) * 0.8:
				sunk_ok += 1
			elif OS.get_environment("DEBUG_HW") == "1":
				print("[hw] link %d-%d %s at %.0f: prof %.2f on %.2f depth %.2f bench %.2f hollow %.2f len %.0f" % [l.a, l.b, str(hw), mm, prof, on, float(hw[2]), RoadNetwork.bench_at(l, mm), RoadNetwork.hollow_at(l, mm), float(l.len_m)])
	lens.sort()
	print("[grades] %d links (%.1f-%.1f km): %d major ends, %d kerbed at 20 m; %d/%d long links wider and more worn at their kerbed end; %d vanishings (%d on trodden), %d tells; %d bend cairns, %d milestones; %d avenue spots; %d holloways (%d/%d sunk)" % [near.size(), float(lens[0]) / 1000.0, float(lens[-1]) / 1000.0, kerbed_ends, kerbed_ok, wider, wider_of, vanish_n, vanish_trodden, tells, bends, miles, avenue, hollows, sunk_ok, sunk_n])
	ok(width_ok, "every grade's width in roads.json's (widened) range")
	ok(kerbed_ends > 0 and kerbed_ok == kerbed_ends, "kerbed into every ruin, camp or waypoint (%d/%d)" % [kerbed_ok, kerbed_ends])
	ok(wider_of == 0 or wider == wider_of, "the tread wider and more worn at a kerbed end than out on the trodden (%d/%d)" % [wider, wider_of])
	ok(vanish_trodden == vanish_n, "the trail vanishes only on the trodden (%d/%d)" % [vanish_trodden, vanish_n])
	ok(tells >= vanish_n * 2, "a tell at both ends of every vanishing (%d tells, %d vanishings)" % [tells, vanish_n])
	ok(bends > 0, "cairns at the bends (%d)" % bends)
	ok(miles > 0 and miles_ok == miles, "milestones with a notch per mile (%d)" % miles)
	ok(avenue > 0, "the avenue's spots beside the kerbed approaches (%d)" % avenue)
	ok(sunk_n == 0 or sunk_ok == sunk_n, "a holloway sinks the tread below the profile (%d/%d)" % [sunk_ok, sunk_n])
	# The avenue's tree: one per node, not native there.
	var map: PlanetData = world.planet
	var checked := 0
	var not_native := 0
	var names := {}
	for l in near:
		var nd: PackedVector3Array = l.get("avenue_node", PackedVector3Array())
		for d in nd:
			var sp := VegetationPlacer.avenue_species(map, d, true)
			if sp == null:
				continue
			checked += 1
			names[sp.name] = true
			if not sp.biomes.has(map.biome[map.cell_at(d)]):
				not_native += 1
			if VegetationPlacer.avenue_species(map, d, true) != sp:
				not_native -= 1000
	print("[grades] avenue trees: %s" % ", ".join(names.keys()))
	ok(checked > 0 and not_native == checked, "the avenue's tree is planted (not native to the node's biome) and the same every time (%d/%d)" % [not_native, checked])
	# Steep passes: the cap rises with height.
	var lo := RoadNetwork.hard_max_at(0.0)
	var hi := RoadNetwork.hard_max_at(600.0)
	ok(absf(lo - RoadNetwork.hard_max_grade()) < 1e-4 and hi > lo + 0.1, "steeper passes high up (cap %.2f low, %.2f at 600 m)" % [lo, hi])
	ok(rad_to_deg(atan(hi)) < PlanetPlayer.WALK_MAX_DEG - 10.0, "and still walkable (%.0f° under WALK_MAX_DEG %.0f°)" % [rad_to_deg(atan(hi)), PlanetPlayer.WALK_MAX_DEG])
	# The props near a kerbed end and a milestone: walk there and let
	# RoadProps build.
	var target := Vector3.ZERO
	var want_mile := Vector3.ZERO
	for l in near:
		var g: Dictionary = l.get("grade", {})
		if not g.is_empty() and target == Vector3.ZERO and float(g.ka) > 0.0:
			target = RoadNetwork.point_at(l.pts, 60.0)
		for wm in l.waymarks:
			if wm.size() > 3 and str(wm[3]) == "mile" and want_mile == Vector3.ZERO:
				want_mile = wm[0]
	var props: RoadProps = main.road_props
	ok(props != null, "RoadProps is running")
	if props != null and target != Vector3.ZERO:
		await _visit(target)
		var kerbs := 0
		for k in props._built:
			if str(k).begins_with("k:"):
				kerbs += 1
		ok(kerbs > 0, "kerb stones built along the kerbed run near the player (%d spans)" % kerbs)
	if props != null and want_mile != Vector3.ZERO:
		await _visit(want_mile)
		var near_mile := false
		for k in props._built:
			var n: Node3D = props._built[k]
			if is_instance_valid(n) and str(k).begins_with("w:") and world.dir_of(n.global_position).dot(want_mile) > cos(3.0 / PlanetConst.RADIUS_M):
				near_mile = true
		ok(near_mile, "a milestone stands where the mile falls")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _visit(d: Vector3) -> void:
	var r: float = PlanetConst.RADIUS_M + main.chunks.ground_height(d) + 2.0
	player.global_position = world.to_scene(d, r)
	player.velocity = Vector3.ZERO
	for i in 180:
		await process_frame

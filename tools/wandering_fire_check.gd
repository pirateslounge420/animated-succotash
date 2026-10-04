extends SceneTree
## The wandering fire (design 3 Oct §DP, uniques.json wandering_fire,
## WanderingFire), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/wandering_fire_check.gd
##  - exactly one group, in a desert biome;
##  - over ten days its night places are 2-6 km apart, never the same;
##  - by day the figures are moving and there is no fire;
##  - at night the fire is lit and all thirteen are within its radius;
##    the dread drains inside it;
##  - a cold ring at a past night's place;
##  - the log's line, once.

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var map: PlanetData = world.planet
	var wf: WanderingFire = main.wandering_fire
	var p0 := WanderingFire.night_at(map, 0)
	ok(p0 != Vector3.ZERO and WanderingFire.instance == wf, "one group on this world (one WanderingFire, its first night placed)")
	# Ten days of nights.
	var gaps: Array = []
	var all_in := true
	var min_pair := INF
	var nights: Array = []
	for k in 11:
		nights.append(WanderingFire.night_at(map, k))
	for k in 11:
		if not WanderingFire.in_country(map, nights[k]):
			all_in = false
		if k > 0:
			gaps.append(CubeSphere.surface_distance_m(nights[k - 1], nights[k]) / 1000.0)
		for j in k:
			min_pair = minf(min_pair, CubeSphere.surface_distance_m(nights[j], nights[k]))
	print("   first night AT=%.3f,%.3f in %s; the gaps (km): %s" % [rad_to_deg(CubeSphere.latitude(p0)), rad_to_deg(CubeSphere.longitude(p0)), BiomeTemplates.KEYS[map.biome[map.cell_at(p0)]], str(gaps.map(func(g): return snappedf(g, 0.1)))])
	ok(all_in, "every night in the hot desert or thorn scrub")
	ok(gaps.all(func(g): return g >= 2.0 and g <= 6.0), "night places 2-6 km apart over ten days")
	ok(min_pair > 1000.0, "never the same place twice (nearest two %.1f km apart)" % (min_pair / 1000.0))
	# --- By day: walking, no fire. ---
	var lon := CubeSphere.longitude(p0)
	var lat := CubeSphere.latitude(p0)
	world.days = Astro.days_at_solar_hour(world.days + 5.0, 12.0, lon, lat)
	var w := WanderingFire.where(world, world.days)
	await _stand(CreatureSpawner._offset(w.dir, 0.0, 30.0))
	for i in 30:
		await process_frame
	w = WanderingFire.where(world, world.days)
	var g0: Vector3 = wf.group_node().global_position if wf.group_node() != null else Vector3.INF
	for i in 180:
		await process_frame
	var g1: Vector3 = wf.group_node().global_position if wf.group_node() != null else Vector3.INF
	var moved := g0.distance_to(g1) if g0 != Vector3.INF and g1 != Vector3.INF else 0.0
	var fire_near := Campfire.lit_near(self, g1 if g1 != Vector3.INF else main.player.global_position, 20.0)
	print("   at noon: %s, the group moved %.2f m in 3 s; %d figures" % [str(w.state), moved, wf.figures().size()])
	ok(str(w.state) == "walk" and moved > 0.5 and wf.figures().size() == 13, "by day the thirteen are walking (%.2f m in 3 s)" % moved)
	ok(wf.fire_node() == null and not fire_near, "and no fire burns by them")
	# --- At night: the fire, the thirteen round it, the dread kept off. ---
	world.days = Astro.days_at_solar_hour(world.days, 21.0, lon, lat)
	w = WanderingFire.where(world, world.days)
	await _stand(CreatureSpawner._offset(w.dir, 1.0, 6.0))
	for i in 60:
		await process_frame
	var fire: Node3D = wf.fire_node()
	var lit := fire != null and FireStore.is_lit(fire)
	var radius := float(Dread.M.get("fire_radius_m", 14.0))
	var inside := 0
	if fire != null:
		for f in wf.figures():
			if (f as Node3D).global_position.distance_to(fire.global_position) < radius:
				inside += 1
	print("   at 21:00: %s, night %d; the fire %s (%s); %d of 13 within %.0f m" % [str(w.state), int(w.night), "lit" if lit else "NOT lit", FireStore.state_of(fire) if fire != null else "none", inside, radius])
	ok(str(w.state) == "night" and lit, "at night their fire burns")
	ok(inside == 13, "all thirteen within its radius (%d)" % inside)
	var dread: Dread = main.dread
	main.player.global_position = fire.global_position + (main.player.global_position - fire.global_position).normalized() * 4.0 if fire != null else main.player.global_position
	dread.force_dark = true
	dread.meter = 0.5
	for i in 120:
		await process_frame
	ok(dread.meter < 0.5, "the dread drains by their fire (0.50 -> %.3f)" % dread.meter)
	dread.force_dark = false
	dread.meter = 0.0
	# --- A cold ring at a past night. ---
	var past := WanderingFire.past_nights(world, world.days)
	ok(past.size() >= 4, "%d nights left behind" % past.size())
	if not past.is_empty():
		var k: int = past[past.size() - 2] if past.size() >= 2 else past[0]
		await _stand(CreatureSpawner._offset(WanderingFire.night_at(map, k), 0.5, 8.0))
		for i in 30:
			await process_frame
		var ring: Node3D = wf.ring_nodes().get(k)
		ok(ring != null and is_instance_valid(ring), "a cold ring at night %d's place (%s)" % [k, "built" if ring != null else "none"])
	# --- The log's line, once. ---
	var line := str(WanderingFire.E.get("log", ""))
	var n := GameLog.entries.filter(func(e): return e.text == line).size()
	await _stand(CreatureSpawner._offset(w.dir, 1.0, 6.0))
	for i in 30:
		await process_frame
	var n2 := GameLog.entries.filter(func(e): return e.text == line).size()
	ok(n == 1 and n2 == 1, "the log's line once (\"%s\"; %d, then %d after coming back)" % [line, n, n2])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _stand(d: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for i in 10:
		await process_frame

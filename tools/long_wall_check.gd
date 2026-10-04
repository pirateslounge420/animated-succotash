extends SceneTree
## The long wall (design 3 Oct §DS.1, ruins.json styles.long_wall,
## Monuments, RuinBuilder._long_wall_gate / _long_wall_piece, LongWalls),
## headless:
##   SEED=7731 godot --headless --path . --script tools/long_wall_check.gd
##  - the sites pass: every one where its gate holds (east_asia_temperate or
##    central_asia, steppe, cold desert and the mountains, never wet or flat
##    lowland), on a crest, never past per_world_max; its AT= and tally;
##  - its line 3-12 km along the crest, 5-8 m high, towers every 250-500 m,
##    broken in places;
##  - its gate tower has a delve with a heart and a way out;
##  - it streams: a piece a stretch, each within a castle's triangles;
##  - a road comes to its gate (the road network's node).

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.generate_now(seed_v)
	var map: PlanetData = world.planet
	RealmMap.warm(seed_v)
	var rivers := Encampment.rivers_for(map)
	Delves.setup_world(map, rivers)
	var t0 := Time.get_ticks_msec()
	var sites := Monuments.all_sites(map, "long_wall")
	var rep: Dictionary = Monuments.report.get("long_wall", {})
	print("   the sites pass (%.1f s): %s" % [(Time.get_ticks_msec() - t0) / 1000.0, str(rep)])
	var E := Monuments.entry("long_wall")
	var cap := int(E.get("per_world_max", 2))
	ok(sites.size() <= cap, "%d long walls, never more than %d" % [sites.size(), cap])
	ok(not sites.is_empty(), "at least one long wall on this world (%d crest cells passed)" % int(rep.get("passed", 0)))
	# The largest castle's triangles: the budget.
	var castle_max := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := Ruins.cells_per_face()
	var castles := 0
	for i in 4000:
		var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n))
		if not s.is_empty() and int(s.kind) == Ruins.Kind.CASTLE and castles < 12:
			castles += 1
			castle_max = maxi(castle_max, ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3)
	print("   the largest of %d castles: %d triangles" % [castles, castle_max])
	var broken := 0
	for site in sites:
		var line: PackedVector3Array = site.line
		var g := Monuments.gate(map, site.dir, "long_wall")
		var crest := 0
		var samples := 0
		var m := 0.0
		while m <= float(site.len_m):
			samples += 1
			if Monuments.ridge_axis(map, RoadNetwork.point_at(line, m)) >= 0.0:
				crest += 1
			m += 100.0
		var tw: Array = site.towers
		var gaps: Array = []
		for i in range(1, tw.size() - 1):
			gaps.append(float(tw[i + 1]) - float(tw[i]))
		var inner := gaps.slice(0, maxi(gaps.size() - 1, 0))
		var nb := (site.breaks as Array).size() + (site.fallen_towers as Array).size()
		if nb > 0:
			broken += 1
		var bk := BiomeTemplates.KEYS[map.biome[map.cell_at(site.dir)]]
		var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[map.cell_at(site.dir)], map.moisture[map.cell_at(site.dir)], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
		print("   a long wall: its gate AT=%.3f,%.3f in %s (%s), %.1f km, %.1f m high, %d towers, %d breaks (%s), %d towers fallen; %d of %d points along it on a crest; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, float(site.len_m) / 1000.0, float(site.wall_h), tw.size(), (site.breaks as Array).size(), ", ".join((site.breaks as Array).map(func(b): return str(b[2]))), (site.fallen_towers as Array).size(), crest, samples, g])
		ok(g == "" or g == "no_ridge", "its gate stands in its realm and biomes, not wet, not flat lowland (\"%s\")" % g)
		ok(crest * 2 >= samples, "it follows a crest (%d of %d points on one)" % [crest, samples])
		ok(float(site.len_m) >= 3000.0 and float(site.len_m) <= 12500.0, "%.1f km long, within 3-12" % (float(site.len_m) / 1000.0))
		ok(float(site.wall_h) >= 5.0 and float(site.wall_h) <= 8.0, "%.1f m high, within 5-8" % float(site.wall_h))
		ok(inner.all(func(x): return x >= 249.0 and x <= 501.0), "towers every 250-500 m (%s)" % str(gaps.map(func(x): return int(x))))
		var lay := Delves.layout(map, site)
		var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
		ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its gate tower's delve: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
		var gd := RuinBuilder.compute(map, site)
		var gt := (gd.v as PackedVector3Array).size() / 3
		ok(gt <= castle_max, "its gate: %d triangles, within the largest castle's %d" % [gt, castle_max])
		var sps := LongWalls.spans(site)
		var worst := 0
		var total := gt
		var t1 := Time.get_ticks_msec()
		for k in sps.size():
			var pd := RuinBuilder.compute(map, LongWalls.piece_site(site, k))
			var pt := (pd.v as PackedVector3Array).size() / 3
			worst = maxi(worst, pt)
			total += pt
		ok(sps.size() >= 6 and worst <= castle_max, "it streams in %d stretches, the largest %d triangles (all %d; %.1f s to build them all)" % [sps.size(), worst, total, (Time.get_ticks_msec() - t1) / 1000.0])
		# A road to its gate.
		var net := RoadNetwork.new(map, rivers)
		var near := net.links_near(site.dir, 400.0, true)
		var at_gate := near.filter(func(l): return CubeSphere.surface_distance_m((l.pts as PackedVector3Array)[0], site.dir) < 30.0 or CubeSphere.surface_distance_m((l.pts as PackedVector3Array)[(l.pts as PackedVector3Array).size() - 1], site.dir) < 30.0)
		ok(not at_gate.is_empty(), "%d road(s) come to its gate tower (the network's node there)" % at_gate.size())
	ok(sites.is_empty() or broken > 0, "broken in places (gaps, fallen stretches, a tower down)")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

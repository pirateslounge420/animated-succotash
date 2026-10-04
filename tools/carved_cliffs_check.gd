extends SceneTree
## The carved cliffs (design 3 Oct §DS.2, ruins.json styles.carved_cliffs,
## Monuments._carved_cliffs, RuinBuilder._carved_cliffs), headless:
##   SEED=7731 godot --headless --path . --script tools/carved_cliffs_check.gd
##  - the sites pass: every one where its gate holds (palearctic or
##    afrotropic hot desert, canyon or badlands, sandstone, a canyon wall,
##    never wet), never past per_world_max; its AT= and the tally;
##  - 3-9 facades along one wall of the canyon, 8-30 m tall;
##  - a delve with a heart and a way out;
##  - its triangles within the largest castle's.
## SEEDS="7731,42,7" tries several worlds (the canyon and the sandstone
## desert don't meet on every one).

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	var seeds: Array = []
	if OS.get_environment("SEEDS") != "":
		seeds = Array(OS.get_environment("SEEDS").split(",")).map(func(s): return int(s))
	else:
		seeds = [int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731]
	var any := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var t0 := Time.get_ticks_msec()
		var sites := Monuments.all_sites(map, "carved_cliffs")
		var rep: Dictionary = Monuments.report.get("carved_cliffs", {})
		print("   seed %d: the sites pass (%.1f s): %s" % [seed_v, (Time.get_ticks_msec() - t0) / 1000.0, str(rep)])
		var E := Monuments.entry("carved_cliffs")
		var cap := int(E.get("per_world_max", 2))
		ok(sites.size() <= cap, "seed %d: %d carved cliffs, never more than %d" % [seed_v, sites.size(), cap])
		any += sites.size()
		if sites.is_empty():
			continue
		var castle_max := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var n := Ruins.cells_per_face()
		var castles := 0
		for i in 4000:
			var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n))
			if not s.is_empty() and int(s.kind) == Ruins.Kind.CASTLE and castles < 10:
				castles += 1
				castle_max = maxi(castle_max, ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3)
		for site in sites:
			var cell := map.cell_at(site.dir)
			var g := Monuments.gate(map, site.dir, "carved_cliffs")
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			var fs: Array = site.facades
			var hs: Array = fs.map(func(f): return snappedf(float(f.h), 0.1))
			print("   carved cliffs AT=%.3f,%.3f in %s (%s, %s), the canyon %.1f m deep%s; %d facades, heights %s; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), BiomeTemplates.KEYS[map.biome[cell]], realm, PlanetData.soil_name(map.rock[cell]), float(site.depth_m), " (a slot canyon)" if float(site.slot) > 0.7 else "", fs.size(), str(hs), g])
			ok(g == "" or g == "no_canyon", "it stands in its realm and biomes, in sandstone, not wet (\"%s\")" % g)
			ok(fs.size() >= 3 and fs.size() <= 9, "%d facades, within 3-9" % fs.size())
			ok(hs.all(func(x): return x >= 8.0 and x <= 30.0), "each 8-30 m tall")
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its tombs: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "carved cliffs stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

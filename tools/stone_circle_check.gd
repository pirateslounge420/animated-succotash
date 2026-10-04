extends SceneTree
## The stone circles (design 3 Oct §DS.2, ruins.json styles.stone_circle,
## Monuments._stone_circle, RuinBuilder._stone_circle), headless:
##   SEED=7731 godot --headless --path . --script tools/stone_circle_check.gd
##  - the sites pass: every one where its gate holds (palearctic prairie,
##    wet meadow or bog, open ground, never forest or a slope), never past
##    per_world_max; AT= and the tally;
##  - 9-30 stones 2-7 m tall, some lintels, the ditch and bank;
##  - a souterrain where the seed gives one (a heart and a second mouth, no
##    fire-holders), else none (§CJ's one allowed exception);
##  - its triangles within the largest castle's.
## SEEDS="7731,8" tries several worlds.

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
		var sites := Monuments.all_sites(map, "stone_circle")
		var rep: Dictionary = Monuments.report.get("stone_circle", {})
		print("   seed %d: the sites pass (%.1f s): %s" % [seed_v, (Time.get_ticks_msec() - t0) / 1000.0, str(rep)])
		var E := Monuments.entry("stone_circle")
		var cap := int(E.get("per_world_max", 2))
		ok(sites.size() <= cap, "seed %d: %d stone circles, never more than %d" % [seed_v, sites.size(), cap])
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
			var g := Monuments.gate(map, site.dir, "stone_circle")
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			var stn: Array = site.stones
			var hs: Array = stn.map(func(x): return snappedf(float(x.h), 0.1))
			print("   a stone circle AT=%.3f,%.3f in %s (%s), %d stones %s (%d fallen), %d lintels, the ring %.1f m across; a souterrain: %s; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), BiomeTemplates.KEYS[map.biome[cell]], realm, stn.size(), str(hs), stn.filter(func(x): return bool(x.fallen)).size(), (site.lintels as Array).size(), float(site.ring_r) * 2.0, "yes" if bool(site.souterrain) else "no", g])
			ok(g == "", "it stands in its realm and biomes, on open ground, not in forest or on a slope (\"%s\")" % g)
			ok(stn.size() >= 9 and stn.size() <= 30 and hs.all(func(x): return x >= 2.0 and x <= 7.0), "%d stones 2-7 m tall" % stn.size())
			if not bool(site.souterrain):
				ok(not Delves.has_delve(site), "no souterrain on this one: no delve (the one allowed exception)")
				var tris0 := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
				ok(tris0 <= castle_max, "its triangles %d within the largest castle's %d" % [tris0, castle_max])
				continue
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its souterrain: %s, a second mouth %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			ok(bool(lay.get("no_fire", false)), "and no fire-holders in it")
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "stone circles stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

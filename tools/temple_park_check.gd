extends SceneTree
## The temple park (design 3 Oct §DW, ruins.json styles.temple_park,
## Monuments._temple_park, RuinBuilder._temple_park), headless:
##   SEED=7731 godot --headless --path . --script tools/temple_park_check.gd
##  - the sites pass: every one where its gate holds (indomalaya, tropical
##    dry forest or jungle, flat lowland, still water near, never a crag or
##    a slope), never within 5 km of a temple city, at most two a world;
##    its AT= and the tally;
##  - 200-400 m across; its ponds (two or more, each a hole in the ground
##    with water in it), its towers (the great one and at least one more);
##  - its relic crypt: a heart and a way out, the way down's open hole
##    short of the great tower's base;
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
	var E := Monuments.entry("temple_park")
	var any := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var sites := Monuments.all_sites(map, "temple_park")
		var rep: Dictionary = Monuments.report.get("temple_park", {})
		print("   seed %d: the sites pass: %s" % [seed_v, str(rep)])
		ok(sites.size() <= int(E.get("per_world_max", 2)), "seed %d: %d temple parks, never more than %d" % [seed_v, sites.size(), int(E.get("per_world_max", 2))])
		any += sites.size()
		if sites.is_empty():
			continue
		var cities := Monuments.all_sites(map, "temple_city")
		var castle_max := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var n := Ruins.cells_per_face()
		var castles := 0
		for i in 4000:
			var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n))
			if not s.is_empty() and not (s.kind is String) and int(s.kind) == Ruins.Kind.CASTLE and not s.has("style") and castles < 10:
				castles += 1
				castle_max = maxi(castle_max, ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3)
		for site in sites:
			var cell := map.cell_at(site.dir)
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			var bk: String = BiomeTemplates.KEYS[map.biome[cell]]
			var g := Monuments.gate(map, site.dir, "temple_park")
			var near_city := INF
			for c in cities:
				near_city = minf(near_city, CubeSphere.surface_distance_m(c.dir, site.dir))
			var counts := {}
			for pc in site.pieces:
				counts[str(pc[0])] = int(counts.get(str(pc[0]), 0)) + 1
			print("   temple park AT=%.3f,%.3f in %s (%s), %.0f m across, %s; the nearest temple city %.1f km; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, float(site.across_m), str(counts), near_city / 1000.0, g])
			ok(g == "", "its gate holds: realm, biomes, flat lowland, still water, not a crag, not near a temple city")
			ok(near_city >= 5000.0, "never within 5 km of a temple city (%.1f km)" % (near_city / 1000.0))
			ok(float(site.across_m) >= 200.0 and float(site.across_m) <= 400.0, "%.0f m across, within 200-400" % float(site.across_m))
			ok(int(counts.get("pond", 0)) >= 2 and int(counts.get("tower", 0)) >= 1, "%d ponds, the great tower and %d more" % [int(counts.get("pond", 0)), int(counts.get("tower", 0))])
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its relic crypt: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			var h0: Rect2 = (lay.holes as Array)[0]
			ok(h0.end.y <= float(site.stupa_z) - float(site.stupa_b), "the way down's hole ends at %.1f, short of the great tower's base at %.1f" % [h0.end.y, float(site.stupa_z) - float(site.stupa_b)])
			ok((lay.holes as Array).size() >= 1 + int(counts.get("pond", 0)), "every pond a hole in the ground (%d holes)" % (lay.holes as Array).size())
			var data := RuinBuilder.compute(map, site)
			ok(not ((data.water as Dictionary).v as PackedVector3Array).is_empty(), "water in its ponds (%d triangles)" % (((data.water as Dictionary).v as PackedVector3Array).size() / 3))
			var tris := (data.v as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d (root-trees: %d)" % [tris, castle_max, (data.root_trees as Array).size()])
	ok(any > 0, "temple parks stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

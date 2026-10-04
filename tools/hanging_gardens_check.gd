extends SceneTree
## The hanging gardens (design 3 Oct §DT, ruins.json styles.hanging_gardens,
## Monuments._hanging_gardens, HangingGardens, RuinBuilder._hanging_gardens),
## headless:
##   SEED=7731 godot --headless --path . --script tools/hanging_gardens_check.gd
##  - the sites pass: every one where its gate holds (palearctic or
##    central_asia, hot desert, oasis or steppe, a desert river's
##    floodplain, flat, a river on one side, never a crag), at most one a
##    world; its AT= and the tally;
##  - 4-7 terraces, 20-35 m high, 80-150 m across;
##  - its channel: water on every terrace, a fall at every wall, the ground
##    channel ending at the river;
##  - the garden: trees of garden.hand_carried on the upper terraces and of
##    garden.local below (by genus), standing on the terraces;
##  - its delve: a heart (the cistern) and a way out at the back by the
##    river, every gallery and stair inside the mound;
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
	var E := Monuments.entry("hanging_gardens")
	var garden: Dictionary = E.get("garden", {})
	var high_g: Array = (garden.get("hand_carried", []) as Array).map(func(b): return str(b).split(" ")[0])
	var low_g: Array = (garden.get("local", []) as Array).map(func(b): return str(b).split(" ")[0])
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var sites := Monuments.all_sites(map, "hanging_gardens")
		var rep: Dictionary = Monuments.report.get("hanging_gardens", {})
		print("   seed %d: the sites pass: %s" % [seed_v, str(rep)])
		ok(sites.size() <= int(E.get("per_world_max", 1)), "seed %d: %d hanging gardens, never more than %d" % [seed_v, sites.size(), int(E.get("per_world_max", 1))])
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
			if not s.is_empty() and not (s.kind is String) and int(s.kind) == Ruins.Kind.CASTLE and not s.has("style") and castles < 10:
				castles += 1
				castle_max = maxi(castle_max, ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3)
		for site in sites:
			var cell := map.cell_at(site.dir)
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			var bk: String = BiomeTemplates.KEYS[map.biome[cell]]
			var g := Monuments.gate(map, site.dir, "hanging_gardens")
			print("   hanging gardens AT=%.3f,%.3f in %s (%s), %d terraces, %.1f m high, %.0f m across, its water %.0f m from its back foot; gate here \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, int(site.terraces), float(site.height_m), float(site.across_m), (site.riv as Vector2).distance_to(Vector2(0.0, float(site.across_m) * 0.5)), g])
			var sp: Dictionary = E.spawn
			ok((sp.realm as Array).has(realm) and (sp.biomes as Array).has(bk), "it stands in its realm and biomes")
			ok(int(site.terraces) >= 4 and int(site.terraces) <= 7 and float(site.height_m) >= 20.0 and float(site.height_m) <= 35.0 and float(site.across_m) >= 80.0 and float(site.across_m) <= 150.0, "4-7 terraces, 20-35 m high, 80-150 m across")
			var data := RuinBuilder.compute(map, site)
			var wv: PackedVector3Array = (data.water as Dictionary).v
			var fv: PackedVector3Array = (data.falls as Dictionary).v
			var nfalls := fv.size() / 24
			ok(not wv.is_empty() and nfalls == int(site.terraces), "the channel: %d water triangles, %d falls (one a wall: %d)" % [wv.size() / 3, nfalls, int(site.terraces)])
			var end_d := Delves.to_dir(Delves.frame(map, site), (site.riv as Vector2).x, (site.riv as Vector2).y)
			var wp := Monuments.water_point(map, end_d, 60.0)
			ok(Monuments.river_m(map, end_d) < 15.0 or (not wp.is_empty() and float(wp.m) <= 60.0) or TerrainChunk._standing_water(map, end_d).x > map.terrain.elevation(end_d, true, false, false), "its ground channel ends at the water (%s)" % ("in it" if wp.is_empty() else "%.0f m from it" % float(wp.m)))
			var trees: Array = data.garden
			var hi_n := 0
			var lo_n := 0
			var wrong := 0
			for t in trees:
				var tsp: PlantSpecies = SpeciesDB.all()[int(t[1])]
				if high_g.has(tsp.genus):
					hi_n += 1
				elif low_g.has(tsp.genus):
					lo_n += 1
				else:
					wrong += 1
			ok(hi_n > 0 and lo_n > 0 and wrong == 0, "the garden gone wild: %d mountain trees (%s), %d of the river's own (%s), %d of neither" % [hi_n, ", ".join(high_g), lo_n, ", ".join(low_g), wrong])
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its galleries: %s; the cistern the heart, a way out at the back" % ", ".join(kinds))
			var tris := (data.v as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d (and %d trees)" % [tris, castle_max, trees.size()])
	ok(any > 0, "hanging gardens stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

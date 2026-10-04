extends SceneTree
## The old colonnade (design 3 Oct §DV, ruins.json styles.colonnade,
## Monuments._colonnade, Colonnade, RuinBuilder._colonnade), headless:
##   SEED=7731 godot --headless --path . --script tools/colonnade_check.gd
##  - the sites pass: every one where its gate holds (nearctic, floodplain
##    forest, maritime forest or temperate deciduous woods, humid, warm, on
##    a rise above water, never dry), at most three a world; AT= and tally;
##  - 20-30 columns 10-14 m, a few fallen; the cellar a hole in the ground
##    with water on its floor; the avenue of oaks, taller than the wild;
##  - its delve: the cistern (the heart) under the hill with cover, flooded,
##    and the stair out;
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
	var E := Monuments.entry("colonnade")
	var any := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var sites := Monuments.all_sites(map, "colonnade")
		var rep: Dictionary = Monuments.report.get("colonnade", {})
		print("   seed %d: the sites pass: %s" % [seed_v, str(rep)])
		ok(sites.size() <= int(E.get("per_world_max", 3)), "seed %d: %d colonnades, never more than %d" % [seed_v, sites.size(), int(E.get("per_world_max", 3))])
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
			var g := Monuments.gate(map, site.dir, "colonnade")
			print("   colonnade AT=%.3f,%.3f in %s (%s), %.1f C, moisture %.2f, %d columns %.1f m (%d fallen), the house %.0f by %.0f m, its avenue %.0f m; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, map.temp_c[cell], map.sample(map.moisture, site.dir), int(site.columns), float(site.cols_h), (site.fallen as Array).size(), float(site.house_w), float(site.house_l), float(site.avenue_m), g])
			ok(g == "", "its gate holds: realm, biomes, humid, warm, a rise above the water")
			ok(int(site.columns) >= 20 and int(site.columns) <= 30 and float(site.cols_h) >= 10.0 and float(site.cols_h) <= 14.0, "20-30 columns 10-14 m tall")
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its delve: %s, the cistern the heart, the stair out" % ", ".join(kinds))
			var fr := Delves.frame(map, site)
			var heart: Dictionary = lay.pieces[1]
			var short := Delves._short_of_cover(map, fr, heart, 0.0, float(heart.len))
			ok(short <= 0.0, "the cistern under the ground with cover (short by %.2f m)" % short)
			ok(((lay.holes as Array)[0] as Rect2).is_equal_approx(Colonnade.cellar(site)), "the cellar open to the sky (a hole in the ground)")
			var data := RuinBuilder.compute(map, site)
			ok(((data.water as Dictionary).v as PackedVector3Array).size() >= 12, "still water on the cellar's floor and in the cistern")
			var oaks: Array = data.garden
			var hts := oaks.map(func(t): return float(t[2]))
			var sp: PlantSpecies = SpeciesDB.all()[int(oaks[0][1])] if not oaks.is_empty() else null
			ok(not oaks.is_empty() and sp != null and hts.all(func(h): return h > sp.height_m.y), "the avenue: %d %s, taller than the wild (%.0f-%.0f m against its %.0f)" % [oaks.size(), sp.name if sp != null else "?", hts.min() if not hts.is_empty() else 0.0, hts.max() if not hts.is_empty() else 0.0, sp.height_m.y if sp != null else 0.0])
			var tris := (data.v as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "colonnades stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

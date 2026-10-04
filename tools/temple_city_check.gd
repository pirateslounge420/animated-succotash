extends SceneTree
## The temple city (design 3 Oct §DR, ruins.json styles.temple_city and
## root_trees, Monuments, RuinBuilder._temple_city), headless:
##   SEED=7731 godot --headless --path . --script tools/temple_city_check.gd
##  - the sites pass: every one where its gate holds (indomalaya, jungle or
##    monsoon forest, flat lowland, water near, no crag), never past
##    per_world_max; prints each one's AT= and the gate's tally;
##  - every one has a delve with a heart and a way out;
##  - its triangles within the largest castle's;
##  - root-trees on it (the place's own fig), and one or two on another
##    old monument in the wet tropics.

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
	Delves.setup_world(map, Encampment.rivers_for(map))
	var t0 := Time.get_ticks_msec()
	var sites := Monuments.all_sites(map, "temple_city")
	var rep: Dictionary = Monuments.report.get("temple_city", {})
	print("   the sites pass (%.1f s): %s" % [(Time.get_ticks_msec() - t0) / 1000.0, str(rep)])
	var cap := int(Monuments.entry("temple_city").get("per_world_max", 2))
	ok(sites.size() <= cap, "%d temple cities, never more than %d" % [sites.size(), cap])
	ok(not sites.is_empty(), "at least one temple city on this world (%d indomalayan jungle or monsoon cells passed)" % int(rep.get("passed", 0)))
	var all_gate := true
	for s in sites:
		var g := Monuments.gate(map, s.dir, "temple_city")
		print("   a temple city AT=%.3f,%.3f in %s, %.0f m across, %d enclosures; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(s.dir)), rad_to_deg(CubeSphere.longitude(s.dir)), BiomeTemplates.KEYS[map.biome[map.cell_at(s.dir)]], float(s.across_m), int(s.enclosures), g])
		if g != "":
			all_gate = false
	ok(all_gate, "every one stands where its gate holds")
	# Its delve, its triangles, its root-trees.
	var castle_max := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := Ruins.cells_per_face()
	var castles := 0
	var tropic_other := {}
	for i in 6000:
		var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n))
		if s.is_empty():
			continue
		if int(s.kind) == Ruins.Kind.CASTLE and castles < 12:
			castles += 1
			var d := RuinBuilder.compute(map, s)
			castle_max = maxi(castle_max, (d.v as PackedVector3Array).size() / 3)
		var bk: String = BiomeTemplates.KEYS[map.biome[map.cell_at(s.dir)]]
		if tropic_other.is_empty() and int(s.kind) in [Ruins.Kind.CASTLE, Ruins.Kind.TOWER, Ruins.Kind.PYRAMID, Ruins.Kind.AQUEDUCT] and bk in ["JUNGLE", "TROPICAL_RAINFOREST", "TROPICAL_DRY_FOREST", "CLOUD_FOREST"]:
			tropic_other = s
	print("   the largest of %d castles: %d triangles" % [castles, castle_max])
	for s in sites:
		var lay := Delves.layout(map, s)
		var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
		ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its delve: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
		var data := RuinBuilder.compute(map, s)
		var tris := (data.v as PackedVector3Array).size() / 3
		ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
		var rts: Array = data.get("root_trees", [])
		var names := {}
		for r in rts:
			names[(SpeciesDB.all()[int(r[1])] as PlantSpecies).binomial()] = true
		ok(rts.size() >= 3, "%d root-trees on it (%s)" % [rts.size(), ", ".join(names.keys())])
	if tropic_other.is_empty():
		print("   (no other monument in the wet tropics in the sample)")
	else:
		var rsp := RuinBuilder.root_species(map, tropic_other.dir)
		print("   the other monument's fig: %s" % (rsp.binomial() if rsp != null else "none passes its gate"))
		var d2 := RuinBuilder.compute(map, tropic_other)
		var r2: Array = d2.get("root_trees", [])
		ok(r2.size() >= 1 and r2.size() <= 2, "a %s in %s carries %d root-tree(s)" % [Ruins.KIND_NAMES[int(tropic_other.kind)], BiomeTemplates.KEYS[map.biome[map.cell_at(tropic_other.dir)]].to_lower(), r2.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

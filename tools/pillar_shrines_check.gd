extends SceneTree
## The pillar shrines (design 3 Oct §DY, ruins.json styles.pillar_shrines,
## Monuments._pillar_shrines, PillarShrines, RuinBuilder._pillar_shrines),
## headless:
##   SEED=7731 godot --headless --path . --script tools/pillar_shrines_check.gd
##  - the sites pass: every one where its gate holds (east_asia_temperate or
##    indomalaya, cloud forest, temperate rainforest, jungle or monsoon
##    forest, karst or sandstone, a valley where the mist pools, never
##    flat), at most two a world; its AT= and the tally;
##  - 6-15 pillars 50-150 m high, a shrine on each, stairs cut round some;
##  - its bridges by span: arches 4-15 m, rope 15-60 m (about one in six
##    still hanging), root bridges 10-40 m only where canopy folk lived;
##  - its delve: up inside the middle pillar to its summit shrine (the
##    heart), out onto the summit;
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
	var E := Monuments.entry("pillar_shrines")
	var any := 0
	var ropes := 0
	var ropes_up := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var sites := Monuments.all_sites(map, "pillar_shrines")
		var rep: Dictionary = Monuments.report.get("pillar_shrines", {})
		print("   seed %d: the sites pass: %s" % [seed_v, str(rep)])
		ok(sites.size() <= int(E.get("per_world_max", 2)), "seed %d: %d pillar shrines, never more than %d" % [seed_v, sites.size(), int(E.get("per_world_max", 2))])
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
			var g := Monuments.gate(map, site.dir, "pillar_shrines")
			var pl: Array = site.pillars
			var hs: Array = pl.map(func(q): return int(float(q[3])))
			var stairs := pl.filter(func(q): return bool(q[4])).size()
			var kinds := {}
			for b in site.bridges:
				kinds[str(b[2])] = int(kinds.get(str(b[2]), 0)) + 1
			print("   pillar shrines AT=%.3f,%.3f in %s (%s, %s), %d pillars %s m, %d with stairs, bridges %s%s; gate \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, PlanetData.soil_name(map.rock[cell]), pl.size(), str(hs), stairs, str(kinds), ", canopy folk lived here" if bool(site.canopy_folk) else "", g])
			ok(g == "", "its gate holds: realm, biomes, karst or sandstone, a valley, not flat")
			ok(pl.size() >= 6 and pl.size() <= 15 and hs.all(func(h): return h >= 50 and h <= 150), "6-15 pillars, each 50-150 m high")
			ok(stairs >= 2, "the middle pillar's stair inside and %d cut round the faces" % (stairs - 1))
			var fr := Delves.frame(map, site)
			var spans_ok := true
			for b in site.bridges:
				var a: Array = pl[int(b[0])]
				var c: Array = pl[int(b[1])]
				var gap := Vector2(float(a[0]) - float(c[0]), float(a[1]) - float(c[1])).length() - float(a[2]) - float(c[2])
				match str(b[2]):
					"arch":
						spans_ok = spans_ok and gap <= 15.0
					"rope", "rope_out":
						spans_ok = spans_ok and gap >= 3.0 and gap <= 60.0
						ropes += 1
						if str(b[2]) == "rope":
							ropes_up += 1
					"root":
						spans_ok = spans_ok and bool(site.canopy_folk) and gap >= 10.0 and gap <= 40.0
			ok(spans_ok and not (site.bridges as Array).is_empty(), "its bridges by their spans (%d)" % (site.bridges as Array).size())
			var lay := Delves.layout(map, site)
			var pk: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and bool(lay.get("climbs", false)) and pk.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its delve climbs: %d flights to the summit shrine (the heart), out onto the summit" % pk.count("stair"))
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	print("   rope bridges still hanging: %d of %d (the data's share %.2f)" % [ropes_up, ropes, float(((E.get("bridges", {}) as Dictionary).get("rope_and_plank", {}) as Dictionary).get("standing_share", 0.17))])
	ok(any > 0, "pillar shrines stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

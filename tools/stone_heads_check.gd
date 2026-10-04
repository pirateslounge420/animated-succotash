extends SceneTree
## The stone heads and the oceania realm (design 3 Oct §DS.3, ruins.json
## styles.stone_heads, RealmMap, Monuments._stone_heads,
## RuinBuilder._stone_heads), headless:
##   SEEDS=7731,8 godot --headless --path . --script tools/stone_heads_check.gd
##  - oceania: its province, its land, and the plant communities it has
##    (its own, or spread from the nearest land: §CS.4's short-biome rule);
##  - the sites pass: one at most, in oceania, on a treeless grass or shore
##    coast; AT= and the tally;
##  - 5-15 heads 4-10 m tall on the platform, facing inland, the sea behind;
##  - no tree may grow where they stand;
##  - the quarry's delve with a heart and a way out;
##  - its triangles within the largest castle's.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	var seeds: Array = Array(OS.get_environment("SEEDS").split(",")).map(func(s): return int(s)) if OS.get_environment("SEEDS") != "" else [int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731]
	var any := 0
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		# --- The realm. ---
		var prov := -1
		for i in RealmMap.PROVINCES:
			if RealmMap.world_of(i) == RealmMap.World.OCEANIA:
				prov = i
		var land := 0
		var realm_ok := true
		for c in map.cell_count:
			if map.water[c] == PlanetData.Water.NONE and RealmMap.province_at(map.dir[c]) == prov:
				land += 1
				if land % 50 == 0 and RealmMap.realm(RealmMap.World.OCEANIA, map.dir[c], map.temp_c[c], map.moisture[c], 0.0) != "oceania" and CubeSphere.latitude(map.dir[c]) > deg_to_rad(-60.0):
					realm_ok = false
		Communities.warm(map)
		var own := []
		var spread := []
		for key in Communities.dealt:
			var parts := str(key).split(":")
			if int(parts[0]) != prov:
				continue
			var e: Dictionary = Communities.dealt[key]
			var cname := str(Communities.all[int(e.community)].get("name", "?")) if int(e.community) >= 0 else "none"
			var bname: String = BiomeTemplates.KEYS[int(parts[1])]
			(own if bool(e.get("own", false)) else spread).append("%s: %s" % [bname, cname])
		print("   seed %d: oceania is province %d, %d land cells of %d (%.1f %%); its communities, own: %s; spread from the nearest land: %s" % [seed_v, prov, land, map.cell_count, 100.0 * land / map.cell_count, str(own), str(spread)])
		ok(prov >= 0 and land > 0 and realm_ok, "seed %d: oceania stands, its land reading \"oceania\"" % seed_v)
		# --- The heads. ---
		var sites := Monuments.all_sites(map, "stone_heads")
		print("   the sites pass: %s" % str(Monuments.report.get("stone_heads", {})))
		ok(sites.size() <= 1, "seed %d: %d rows of heads, never more than one" % [seed_v, sites.size()])
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
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			var heads: Array = site.heads
			var hs: Array = heads.map(func(h): return snappedf(float(h.h), 0.1))
			var sea := CreatureSpawner._offset(site.dir, float(site.inland) + PI, 40.0)
			var land_side := CreatureSpawner._offset(site.dir, float(site.inland), 40.0)
			var e_sea := map.terrain.elevation(CreatureSpawner._offset(site.dir, float(site.inland) + PI, 80.0), true, false, false)
			print("   the stone heads AT=%.3f,%.3f in %s (%s): %d heads %s, %d fallen, %d with topknots; the ground 80 m seaward %.1f m, 40 m inland %.1f m" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), BiomeTemplates.KEYS[map.biome[cell]], realm, heads.size(), str(hs), heads.filter(func(h): return bool(h.fallen)).size(), heads.filter(func(h): return bool(h.topknot)).size(), e_sea, map.terrain.elevation(land_side, true)])
			ok(realm == "oceania" and ["TALLGRASS_PRAIRIE", "SHORTGRASS_PRAIRIE", "BEACH", "ROCKY_SHORE"].has(BiomeTemplates.KEYS[map.biome[cell]]), "in oceania, on a grass or shore coast")
			ok(heads.size() >= 5 and heads.size() <= 15 and hs.all(func(x): return x >= 4.0 and x <= 10.0), "%d heads, 4-10 m tall" % heads.size())
			var sbr := Monuments.sea_bearing(map, site.dir)
			ok(not is_inf(sbr) and absf(wrapf(sbr - (float(site.inland) + PI), -PI, PI)) < deg_to_rad(50.0), "the sea behind them (its bearing %.0f°, their backs to %.0f°), facing inland" % [rad_to_deg(sbr), rad_to_deg(wrapf(float(site.inland) + PI, 0.0, TAU))])
			ok(Monuments.treeless(map, site.dir), "no tree of the catalogue may grow where they stand")
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "the quarry's cave: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "the stone heads stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

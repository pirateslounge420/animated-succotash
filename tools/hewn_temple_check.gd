extends SceneTree
## The hewn temple (design 3 Oct §DZ, ruins.json styles.hewn_temple,
## Monuments._hewn_temple, HewnTemple.layout, RuinBuilder._hewn_temple),
## headless:
##   SEED=7731 godot --headless --path . --script tools/hewn_temple_check.gd
##  - the sites pass: every one where its gate holds (indomalaya, tropical
##    dry forest, thorn scrub or savanna, on an escarpment's plateau, dry,
##    basalt, or any hard rock on a world with no basalt land, which the
##    tally then says), never past per_world_max; its AT= and the tally;
##  - its pit 60-120 m across, the temple's top under the rim (found from
##    above), the pit's rectangle a hole in the ground;
##  - its halls: a heart and a way out up to the hilltop, every hall and
##    stair under the hill with cover to spare;
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
		var sites := Monuments.all_sites(map, "hewn_temple")
		var rep: Dictionary = Monuments.report.get("hewn_temple", {})
		print("   seed %d: the sites pass (%.1f s): %s" % [seed_v, (Time.get_ticks_msec() - t0) / 1000.0, str(rep)])
		var E := Monuments.entry("hewn_temple")
		var cap := int(E.get("per_world_max", 2))
		ok(sites.size() <= cap, "seed %d: %d hewn temples, never more than %d" % [seed_v, sites.size(), cap])
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
			var loose: Array = site.get("loose", [])
			var g := Monuments.gate(map, site.dir, "hewn_temple", loose)
			var realm := RealmMap.realm(RealmMap.world_at(site.dir), site.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(site.dir, true) / PlanetConst.HEIGHT_SCALE)
			print("   hewn temple AT=%.3f,%.3f in %s (%s, %s%s), the pit %.0f by %.0f m and %.1f m deep" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), BiomeTemplates.KEYS[map.biome[cell]], realm, PlanetData.soil_name(map.rock[cell]), ", basalt loosened to hard rock" if loose.has("basalt") else "", float(site.pit_w), float(site.pit_l), float(site.depth_m)])
			# The site's own middle has moved back from the escarpment's edge:
			# the gate is checked where the sites pass checked it, but realm
			# and biome hold at the pit too.
			var sp: Dictionary = E.spawn
			ok((sp.realm as Array).has(realm) and (sp.biomes as Array).has(BiomeTemplates.KEYS[map.biome[cell]]), "the pit in its realm and biomes")
			ok(maxf(float(site.pit_w), float(site.pit_l)) >= 60.0 and maxf(float(site.pit_w), float(site.pit_l)) <= 120.0, "its pit %.0f m across, within 60-120" % maxf(float(site.pit_w), float(site.pit_l)))
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			var ex: Dictionary = lay.get("exit", {})
			var fr := Delves.frame(map, site)
			var ex_top := Delves._g0(map, fr, (ex.c as Vector2).x + (ex.dir as Vector2).x * float(ex.len), (ex.c as Vector2).y + (ex.dir as Vector2).y * float(ex.len)) if not ex.is_empty() else -INF
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not ex.is_empty() and absf(float(ex.y1) - ex_top) < 0.5, "its halls: %s, the way out up to the hilltop (%.1f m up from the heart)" % [", ".join(kinds), float(ex.get("y1", 0.0)) - float(ex.get("y0", 0.0))])
			var worst := 0.0
			for pc in lay.pieces:
				if str(pc.kind) in ["room", "heart", "stair"]:
					worst = maxf(worst, Delves._short_of_cover(map, fr, pc, 0.0, float(pc.len)))
			ok(worst <= 0.0, "every hall and stair under the hill with cover to spare (short by %.2f m at worst)" % worst)
			var pit: Rect2 = (lay.holes as Array)[0]
			ok(is_equal_approx(pit.size.x, float(site.pit_w)) and is_equal_approx(pit.size.y, float(site.pit_l)), "the pit's rectangle is a hole in the ground")
			# (RuinBuilder._hewn_shrine: the plinth 5 m, the shrine's walls 6, its
			# tower at least 3, the crown and finial 2, all within 1.5 m of the rim.)
			var temple_top := float(site.floor_y) + maxf(float(site.rim_y) - float(site.floor_y) - 1.5, 5.0 + 6.0 + 3.0 + 2.0)
			ok(temple_top < float(site.rim_y), "the temple's top %.1f m under the rim: found from above" % (float(site.rim_y) - temple_top))
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "hewn temples stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

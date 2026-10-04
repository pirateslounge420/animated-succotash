extends SceneTree
## The ruined abbey (design 3 Oct §DU, ruins.json styles.abbey,
## Monuments._abbey, RuinBuilder._abbey), headless:
##   SEED=7731 godot --headless --path . --script tools/abbey_check.gd
##  - the sites pass: every one where its gate holds (palearctic, temperate
##    deciduous, maritime forest, the moor or a rocky shore, cool and wet,
##    never hot or dry), at most two a world; its AT= and the tally;
##  - 40-90 m long, its tower, by the water where water is near;
##  - its crypt: a heart and a way out, the way down's open hole inside the
##    east wall;
##  - a haunted kind (ruins.json haunt.kinds) at about the data's share,
##    and one the birds and the owl live in (RuinSounds);
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
	var E := Monuments.entry("abbey")
	var any := 0
	# The haunt: the kind is on its list, and about its share are haunted.
	var haunted := 0
	for i in 400:
		if Haunt.haunted({"kind": Ruins.Kind.ABBEY, "seed": i * 7919}):
			haunted += 1
	var share := float((Tuning.table("ruins").get("haunt", {}) as Dictionary).get("share", 0.4))
	ok(absf(haunted / 400.0 - share) < 0.08, "the abbey is a haunted kind: %d of 400 haunted (the share %.2f)" % [haunted, share])
	ok(RuinSounds.TOWERED.has(Ruins.Kind.ABBEY), "birds nest in its tower by day, the owl in a window at night (RuinSounds)")
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var sites := Monuments.all_sites(map, "abbey")
		var rep: Dictionary = Monuments.report.get("abbey", {})
		print("   seed %d: the sites pass: %s" % [seed_v, str(rep)])
		ok(sites.size() <= int(E.get("per_world_max", 2)), "seed %d: %d abbeys, never more than %d" % [seed_v, sites.size(), int(E.get("per_world_max", 2))])
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
			var g := Monuments.gate(map, site.dir, "abbey")
			print("   abbey AT=%.3f,%.3f in %s (%s), %.0f m long, its tower %.0f m (%s)%s; gate here \"%s\"" % [rad_to_deg(CubeSphere.latitude(site.dir)), rad_to_deg(CubeSphere.longitude(site.dir)), bk, realm, float(site.length_m), float(site.tower_h), "whole" if bool(site.tower_whole) else "half fallen", ", by the water" if bool(site.get("by_water", false)) else "", g])
			var sp: Dictionary = E.spawn
			ok((sp.realm as Array).has(realm) and (sp.biomes as Array).has(bk) and (g == "" or g == "slope"), "it stands in its realm and biomes, cool and wet, not hot or dry")
			ok(float(site.length_m) >= 40.0 and float(site.length_m) <= 90.0, "%.0f m long, within 40-90" % float(site.length_m))
			var lay := Delves.layout(map, site)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its crypt: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			var h0: Rect2 = (lay.holes as Array)[0]
			ok(h0.end.y <= float(site.length_m) * 0.5 - 1.0 and h0.position.y >= -float(site.length_m) * 0.5, "the way down's hole %s inside the church (the east wall at z %.1f)" % [str(h0), float(site.length_m) * 0.5])
			var tris := ((RuinBuilder.compute(map, site).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(any > 0, "abbeys stand on %d of %d world(s) tried" % [1 if any > 0 else 0, seeds.size()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

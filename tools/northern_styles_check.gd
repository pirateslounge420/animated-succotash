extends SceneTree
## The tower house and the broch (design 3 Oct §DS, ruins.json
## styles.tower_house / styles.broch: styles of the castle and the tower,
## Ruins._northern_style, RuinBuilder._tower_house / _broch), headless:
##   SEED=7731 godot --headless --path . --script tools/northern_styles_check.gd
##  - every tower house and broch on the world sits where its spawn gate
##    holds (palearctic, its biomes, cool and wet, never hot; the broch on
##    a coast or a moor); their AT= lines;
##  - no castle in the hot desert takes the tower house;
##  - the keep 12-20 m, the broch 8-13 m on a base of 14-20 m;
##  - each has its delve with a heart and a way out, the way down's open
##    hole inside the keep (the tower house) or clear of the broch's wall;
##  - each within the largest plain castle's triangles.
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
	var found := {"tower_house": 0, "broch": 0}
	for seed_v in seeds:
		world.generate_now(seed_v)
		var map: PlanetData = world.planet
		RealmMap.warm(seed_v)
		var rivers := Encampment.rivers_for(map)
		Nests.setup(map, rivers)
		Delves.setup_world(map, rivers)
		var t0 := Time.get_ticks_msec()
		var n := Ruins.cells_per_face()
		var styled: Array = []
		var castles := 0
		var desert_castles := 0
		var desert_th := 0
		var castle_max := 0
		var counted := 0
		for f in 6:
			for i in n:
				for j in n:
					var s := Ruins.find(map, Vector3i(f, i, j))
					if s.is_empty() or s.kind is String:
						continue
					if not (int(s.kind) in [Ruins.Kind.CASTLE, Ruins.Kind.TOWER]):
						continue
					var bk: String = BiomeTemplates.KEYS[map.biome[map.cell_at(s.dir)]]
					if int(s.kind) == Ruins.Kind.CASTLE:
						castles += 1
						if bk == "HOT_DESERT":
							desert_castles += 1
							if str(s.get("style", "")) == "tower_house":
								desert_th += 1
						if not s.has("style") and counted < 12:
							counted += 1
							castle_max = maxi(castle_max, ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3)
					if str(s.get("style", "")) in ["tower_house", "broch"]:
						styled.append(s)
		print("   seed %d: %d castles (%d in the hot desert), %d tower houses and brochs (%.1f s); the largest of %d plain castles %d triangles" % [seed_v, castles, desert_castles, styled.size(), (Time.get_ticks_msec() - t0) / 1000.0, counted, castle_max])
		ok(desert_th == 0, "seed %d: no castle in the hot desert takes the tower house (%d of %d)" % [seed_v, desert_th, desert_castles])
		for s in styled:
			var st := str(s.style)
			found[st] += 1
			var cell := map.cell_at(s.dir)
			var bk: String = BiomeTemplates.KEYS[map.biome[cell]]
			var realm := RealmMap.realm(RealmMap.world_at(s.dir), s.dir, map.temp_c[cell], map.moisture[cell], map.terrain.elevation(s.dir, true) / PlanetConst.HEIGHT_SCALE)
			var g := Monuments.gate(map, s.dir, st)
			var sea := not is_inf(Monuments.sea_bearing(map, s.dir))
			var dims := "keep %.1f m" % float(s.keep_h) if st == "tower_house" else "%.1f m on a base of %.1f m" % [float(s.height_m), float(s.base_m)]
			print("   %s AT=%.3f,%.3f in %s (%s), %.1f C, moisture %.2f%s; %s" % [st, rad_to_deg(CubeSphere.latitude(s.dir)), rad_to_deg(CubeSphere.longitude(s.dir)), bk, realm, map.temp_c[cell], map.sample(map.moisture, s.dir), ", the sea near" if sea else "", dims])
			var sp: Dictionary = Monuments.entry(st).get("spawn", {})
			ok(g == "" and (sp.realm as Array).has(realm) and (sp.biomes as Array).has(bk), "it sits in its realm and biomes, cool and wet, not hot (gate \"%s\")" % g)
			if st == "tower_house":
				ok(int(s.kind) == Ruins.Kind.CASTLE and float(s.keep_h) >= 12.0 and float(s.keep_h) <= 20.0, "a castle's style, its keep 12-20 m")
			else:
				ok(int(s.kind) == Ruins.Kind.TOWER and float(s.height_m) >= 8.0 and float(s.height_m) <= 13.0 and float(s.base_m) >= 14.0 and float(s.base_m) <= 20.0, "a tower's style, 8-13 m on a base of 14-20 m")
			var lay := Delves.layout(map, s)
			var kinds: Array = (lay.get("pieces", []) as Array).map(func(p): return str(p.kind))
			ok(Delves.has_delve(s) and bool(lay.get("ok", false)) and kinds.has("heart") and not (lay.get("exit", {}) as Dictionary).is_empty(), "its delve: %s, a way out %s" % [", ".join(kinds), "yes" if not (lay.get("exit", {}) as Dictionary).is_empty() else "NO"])
			# The way down's open hole: inside the keep / clear of the broch.
			var h0: Rect2 = (lay.get("holes", []) as Array)[0]
			var inside_ok := true
			if st == "tower_house":
				var ix := float(s.keep_hx) - 1.0
				var iz := float(s.keep_hz) - 1.0
				inside_ok = h0.position.x >= -ix and h0.end.x <= ix and h0.position.y >= -iz and h0.end.y <= iz
				print("      the keep %.1f by %.1f m" % [2.0 * float(s.keep_hx), 2.0 * float(s.keep_hz)])
			else:
				for c: Vector2 in [h0.position, h0.end, Vector2(h0.position.x, h0.end.y), Vector2(h0.end.x, h0.position.y)]:
					if c.length() < float(s.outer_r) + 0.3:
						inside_ok = false
			ok(inside_ok, "the way down's hole %s %s" % [str(h0), "inside the keep" if st == "tower_house" else "clear of the broch's wall"])
			var tris := ((RuinBuilder.compute(map, s).v) as PackedVector3Array).size() / 3
			ok(tris <= castle_max, "its triangles %d within the largest castle's %d" % [tris, castle_max])
	ok(found.tower_house > 0, "%d tower house(s) on the world(s) tried" % found.tower_house)
	ok(found.broch > 0, "%d broch(es) on the world(s) tried" % found.broch)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

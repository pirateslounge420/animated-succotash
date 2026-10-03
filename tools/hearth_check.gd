extends SceneTree
## A few hearths in every biome, no two alike (design 3 Oct §CU;
## data/camps.json hearths; Hearths):
##   SEEDS="7731,42,7" godot --headless --path . --script tools/hearth_check.gd
## Per seed (the full planet), the sites pass's numbers: the hearths before
## it (every ruin and every nest with a camp or remains) and after; per land
## biome its ground, its target (max(per_land_biome_min, km2 /
## km2_per_hearth)), the candidates and the hearths kept, and the biomes
## left short (too few candidates to fill the target without repeating).
## Asserts:
##  - every land biome with candidates keeps at least per_land_biome_min
##    hearths (or all it has);
##  - no two hearths share the same people, nest, ruin kind and community;
##  - a ruin the pass doesn't keep has no living camp (Ruins.inhabited) and
##    a nest it doesn't keep holds no camp or remains;
## and in play (the first seed): the opening road's people's camp is kept.

var world
var main
var fails := 0


func _initialize() -> void:
	world = get_root().get_node("World")
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	world._load_dev_settings()
	world.use_postage_stamp(false)
	var seeds := (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else "7731,42,7").split(",")
	var cfg: Dictionary = Hearths.CFG
	var mn := int(cfg.get("per_land_biome_min", 2))
	for s in seeds:
		world.generate_now(int(s))
		var map: PlanetData = world.planet
		Encampment.rivers_for(map)
		Hearths.active = false
		Hearths._seed = -1
		WorldSave.data.erase("hearths")
		var t0 := Time.get_ticks_msec()
		Hearths.warm(world, [])
		var tot: Dictionary = Hearths.report.get("_total", {})
		print("\n[hearths] seed %s: %d hearths before the pass, %d after (%d ms)" % [s, int(tot.get("before", 0)), int(tot.get("after", 0)), Time.get_ticks_msec() - t0])
		var short: Array[String] = []
		var under_min: Array[String] = []
		var ids: Array = Hearths.report.keys().filter(func(k): return k is int)
		ids.sort_custom(func(a, b): return float(Hearths.report[a].area_km2) > float(Hearths.report[b].area_km2))
		for b in ids:
			var r: Dictionary = Hearths.report[b]
			print("[hearths]   %-22s %6.0f km2  want %2d  kept %2d  of %3d candidates%s" % [BiomeTemplates.KEYS[int(b)], float(r.area_km2), int(r.target), int(r.kept), int(r.candidates), ("  SHORT %d" % int(r.short)) if int(r.short) > 0 else ""])
			if int(r.short) > 0:
				short.append("%s (%d of %d)" % [BiomeTemplates.KEYS[int(b)], int(r.kept), int(r.target)])
			if int(r.kept) < mini(mn, int(r.candidates)) and not bool(r.get("exhausted", false)):
				under_min.append(BiomeTemplates.KEYS[int(b)])
		print("[hearths] seed %s: short biomes: %s" % [s, ", ".join(short) if not short.is_empty() else "none"])
		ok(under_min.is_empty(), "seed %s: every land biome with candidates keeps at least %d (or every distinct one it has)%s" % [s, mn, (": not " + ", ".join(under_min)) if not under_min.is_empty() else ""])
		_unique(map, int(s))
	# In play (the first camp rolled as in play, so it has its road).
	world.pin(int(seeds[0]), -1)
	Bow.need_capture = false
	WorldSave.read_only = true
	Hearths.active = false
	Hearths._seed = -1
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var od: Vector3 = world.opening.get("ruin", Vector3.ZERO)
	var at := Ruins.near(world.planet, od, 60.0) if od != Vector3.ZERO else []
	ok(not at.is_empty() and Ruins.inhabited(at[0]), "in play, seed %s: the opening road's people's camp is kept, lived in (%.1f km off)" % [seeds[0], float(world.opening.get("camp_m", INF)) / 1000.0])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## No two hearths alike, and what the pass drops holds no hearth.
func _unique(map: PlanetData, sd: int) -> void:
	var fields: Array = Hearths.CFG.get("never_repeat", ["people", "nest", "ruin_kind", "community"])
	var seen := {}
	var dup := 0
	var lived_dropped := 0
	var cpf := Ruins.cells_per_face()
	var rivers := Encampment.rivers_for(map)
	for f in 6:
		for i in cpf:
			for j in cpf:
				var s := Ruins.find(map, Vector3i(f, i, j))
				if s.is_empty():
					continue
				var key := "ruin:%d" % int(s.seed)
				if not Hearths.keep.has(key):
					if Ruins.inhabited(s):
						lived_dropped += 1
					continue
				var d: Vector3 = s.dir
				var b := map.biome[map.cell_at(d)]
				var c := {"people": Peoples.pick(map, rivers, d, "ruin") if Ruins.rolls_inhabited(s) else "", "nest": "", "ruin": Ruins.site_name(s), "community": Communities.at(d, b)}
				var combo := Hearths._combo(c, fields)
				if seen.has(combo):
					dup += 1
				seen[combo] = true
	var nest_dropped := 0
	for kind in Nests.KINDS:
		var cp := CreatureSpawner._cells_per_face(Nests.cell_m(kind))
		for f in 6:
			for i in cp:
				for j in cp:
					var n := Nests.find(kind, Vector3i(f, i, j))
					if n.is_empty():
						continue
					if not Hearths.keep.has(str(n.key)):
						if str(n.state) != "untouched":
							nest_dropped += 1
						continue
					var h: Vector3 = n.hearth
					var b := map.biome[map.cell_at(h)]
					var c := {"people": str(n.get("people", "")) if str(n.state) == "lived" else "", "nest": str(kind), "ruin": "", "community": Communities.at(h, b)}
					var combo := Hearths._combo(c, fields)
					if seen.has(combo):
						dup += 1
					seen[combo] = true
	ok(dup == 0, "seed %d: no two hearths share people, nest, ruin kind and community (%d hearths)" % [sd, seen.size()])
	ok(lived_dropped == 0 and nest_dropped == 0, "seed %d: a ruin or nest the pass drops holds no hearth (%d ruins, %d nests do)" % [sd, lived_dropped, nest_dropped])

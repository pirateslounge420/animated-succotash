extends SceneTree
## A ruin sounds like what lives in it (design 3 Oct §DI.3, data/audio.json
## ruins, RuinSounds), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/ruin_sound_check.gd
##  - a tower ruin at noon: at least one resident source, placed at the
##    ruin, and one plays;
##  - the same at 02:00: the owl or the scrabble, and no day bird;
##  - a swamp ruin (else a freshwater marsh, bog, fen or wet meadow) with
##    water: frogs and drips;
##  - an overrun ruin at noon: no residents, and the bed quiet (Overrun);
##  - the stone wind: 0 under 6 m/s at the opening, more above;
##  - every new kind (ruin_*) has a muffle, so it can be walked to.

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var rs: RuinSounds = main.ruin_sounds
	var map: PlanetData = world.planet
	var camp: Vector3 = main.camp.site
	# The new kinds.
	var muffled := true
	for k in ["ruin_birds", "ruin_bats", "ruin_owl", "ruin_scrabble", "ruin_drip", "ruin_frogs", "ruin_lizard"]:
		var row := Audio3D.row(k)
		if not (row.get("muffle") is Array):
			muffled = false
	ok(muffled, "every new kind (ruin_birds, _bats, _owl, _scrabble, _drip, _frogs, _lizard) has a muffle and a row")
	# --- A tower ruin. ---
	var tower := _ruin_where(map, camp, func(s: Dictionary) -> bool: return int(s.kind) == Ruins.Kind.TOWER and not Overrun.is_overrun(s) and _fits_birds(map, s))
	if tower.is_empty():
		tower = _ruin_where(map, camp, func(s: Dictionary) -> bool: return int(s.kind) == Ruins.Kind.TOWER and not Overrun.is_overrun(s))
	ok(not tower.is_empty(), "a tower ruin on this world")
	if not tower.is_empty():
		var node: Node3D = await _stand_by(tower)
		rs.override = {"hour": "day"}
		rs.refresh()
		var st: Dictionary = rs.state.ruins.get(node.name, {})
		var played := await _heard(rs, node.name, 14.0)
		var at_ruin := true
		for p in rs.playing():
			if p[0] == node.name and (p[2] as Vector3).distance_to(node.global_position) > float(tower.footprint_m) + 30.0:
				at_ruin = false
		print("   the tower (%s, %s, %.1f °C): lives here %s; at noon %s; heard %s" % [_at(tower), FireStore.biome_key(world, tower.dir), map.sample(map.temp_c, tower.dir), str(st.get("lives", [])), str(st.get("who", [])), str(played)])
		ok(not (st.get("who", []) as Array).is_empty() and at_ruin and not played.is_empty(), "a tower ruin at noon: %d resident sources at the ruin (%s), heard %s" % [(st.get("who", []) as Array).size(), ", ".join(st.get("who", [])), ", ".join(played)])
		rs.override = {"hour": "night"}
		rs.refresh()
		st = rs.state.ruins.get(node.name, {})
		var night: Array = st.get("who", [])
		ok((night.has("owl") or night.has("scrabble")) and not night.has("birds"), "the same at 02:00: %s, no day bird" % ", ".join(night))
		# The stone wind at its opening.
		rs.override = {"hour": "day", "wind_mps": 5.0, "near": 1.0}
		rs.refresh()
		var calm := RuinSounds.stone_wind
		rs.override = {"hour": "day", "wind_mps": 8.0, "near": 1.0}
		rs.refresh()
		var blowing := RuinSounds.stone_wind
		ok(calm == 0.0 and blowing > 0.0, "the stone wind: %.2f at 5 m/s at the opening, %.2f at 8 (from %.0f m/s)" % [calm, blowing, float((RuinSounds.D.get("bed", {}) as Dictionary).get("stone_wind_from_mps", 6.0))])
		rs.override = {}
	# --- A wetland ruin with water. ---
	var wet := _ruin_where(map, camp, func(s: Dictionary) -> bool: return BiomeTemplates.KEYS[map.biome[map.cell_at(s.dir)]] == "SWAMP" and not Overrun.is_overrun(s))
	if wet.is_empty():
		wet = _ruin_anywhere(map, func(s: Dictionary) -> bool: return ["SWAMP", "FRESHWATER_MARSH", "BOG", "FEN", "WET_MEADOW"].has(BiomeTemplates.KEYS[map.biome[map.cell_at(s.dir)]]) and map.sample(map.temp_c, s.dir) >= 8.0 and not Overrun.is_overrun(s))
	ok(not wet.is_empty(), "a wetland ruin on this world")
	if not wet.is_empty():
		var node: Node3D = await _stand_by(wet)
		rs.override = {"hour": "dusk"}
		rs.refresh()
		var st: Dictionary = rs.state.ruins.get(node.name, {})
		var who: Array = st.get("who", [])
		print("   the wet ruin (%s, %s %s, %.1f °C, moisture %.2f): %s" % [_at(wet), Ruins.KIND_NAMES[int(wet.kind)], FireStore.biome_key(world, wet.dir), map.sample(map.temp_c, wet.dir), map.sample(map.moisture, wet.dir), str(who)])
		ok(who.has("frogs") and who.has("drip"), "a %s ruin with water: frogs and drips (%s)" % [FireStore.biome_key(world, wet.dir).to_lower(), ", ".join(who)])
		rs.override = {}
	# --- An overrun ruin at noon (the real hour). ---
	var held := _ruin_where(map, camp, func(s: Dictionary) -> bool: return Overrun.is_overrun(s))
	ok(not held.is_empty(), "an overrun ruin on this world")
	if not held.is_empty():
		var node: Node3D = await _stand_by(held)
		world.days = Astro.days_at_solar_hour(world.days, 12.0, CubeSphere.longitude(held.dir), CubeSphere.latitude(held.dir))
		rs.override = {}
		for i in 400:
			await process_frame
		rs.refresh()
		var st: Dictionary = rs.state.ruins.get(node.name, {})
		print("   the overrun ruin (%s, %s): hour %s, lives here %s, now %s; Overrun.quiet %.2f" % [_at(held), Ruins.KIND_NAMES[int(held.kind)], rs.state.hour, str(st.get("lives", [])), str(st.get("who", [])), Overrun.quiet])
		ok((st.get("who", []) as Array).is_empty() and bool(st.get("silent", false)) and Overrun.quiet > 0.3, "an overrun ruin at noon: %d residents, the bed quiet (%.2f)" % [(st.get("who", []) as Array).size(), Overrun.quiet])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _at(s: Dictionary) -> String:
	return "AT=%.3f,%.3f" % [rad_to_deg(CubeSphere.latitude(s.dir)), rad_to_deg(CubeSphere.longitude(s.dir))]


func _fits_birds(map: PlanetData, s: Dictionary) -> bool:
	return RuinSounds._roster_has(map.sample(map.temp_c, s.dir), map.sample(map.moisture, s.dir), ["bird"], ["day", "any"])


## The ruin nearest the camp for which `want` holds (out to `reach_m`).
func _ruin_where(map: PlanetData, camp: Vector3, want: Callable, reach_m := 60000.0) -> Dictionary:
	var best := {}
	var bd := INF
	for c in CreatureSpawner._cells_around(camp, reach_m, Ruins.CELL_M):
		var s := Ruins.find(map, c)
		if s.is_empty() or not want.call(s):
			continue
		var dm := CubeSphere.surface_distance_m(s.dir, camp)
		if dm < bd:
			bd = dm
			best = s
	return best


## A ruin anywhere on the planet for which `want` holds (20,000 cells
## sampled), or {}.
func _ruin_anywhere(map: PlanetData, want: Callable) -> Dictionary:
	var n := Ruins.cells_per_face()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20000:
		var s := Ruins.find(map, Vector3i(rng.randi() % 6, rng.randi() % n, rng.randi() % n))
		if not s.is_empty() and want.call(s):
			return s
	return {}


## Stand beside the ruin `site` (built now) and give the frame a moment.
func _stand_by(site: Dictionary) -> Node3D:
	var d := CreatureSpawner._offset(site.dir, 0.3, float(site.footprint_m) + 6.0)
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	main.landmarks.build_ruin_at(site.dir)
	for i in 30:
		await process_frame
	for c in main.landmarks._ruins:
		var n: Node3D = main.landmarks._ruins[c]
		if is_instance_valid(n) and (n.get_meta("site", {}) as Dictionary).get("dir", Vector3.ZERO) == site.dir:
			return n
	return null


## Which residents of ruin `name` start playing within `secs`.
func _heard(rs: RuinSounds, name: String, secs: float) -> Array:
	var out: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame
		for p in rs.playing():
			if p[0] == name and bool(p[3]) and not out.has(p[1]):
				out.append(p[1])
		if not out.is_empty():
			break
	return out

extends SceneTree
## Old hearths (Mike, 2 Oct; OldHearths), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/old_hearth_check.gd
## Boots the game, goes to the nearest uninhabited ruin and the nearest
## nest holding remains, and asserts at each:
##  - a cold hearth stands there: a fire in the Campfire group, not lit,
##    holding no dread back, not yet a hearth you can take;
##  - a cold fire needs kindling (§CN; FireStore.swing_light, what the
##    torch's swing calls): not laid, it won't light; laid with wet
##    kindling that isn't wet_ok (dead twigs), it smokes and stays cold;
##    laid with wet birch bark (wet_ok) it lights; laid with dry kindling
##    it lights once the flame has taken; kindling with no fuel flares and
##    goes out; embers come back from dry fuel alone;
##  - lit, it holds the dark off (Campfire.lit_near) and can be made your
##    hearth (Hearth.can_set);
##  - it is kept: in the save once lit, and while you are away it burns
##    down on the clock (OldHearths.lit_at after an in-game hour: still
##    burning with fuel fed; out after a day untended);
##  - at the nearest uninhabited tomb (barrow, graveyard, desert pyramid
##    or mastaba) the stone lamps stand dark, come on once its hearth is
##    rekindled, and go out again when the fire dies (TOMB=barrow,
##    graveyard or pyramid picks the kind).

var main
var world
var player: PlanetPlayer
var fails := 0


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
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	var camp: Vector3 = main.camp.site
	var map: PlanetData = world.planet
	print("[old_hearth] seed %d · camp %s" % [seed_v, str(camp)])
	# The nearest uninhabited ruin.
	var ruin := {}
	for r in [20000.0, 60000.0, 200000.0]:
		var bd := INF
		for s in Ruins.near(map, camp, r):
			# (Only the ruins the hearths pass keeps have one, design §CU.)
			if Ruins.inhabited(s) or not Hearths.ruin_kept(s):
				continue
			var dd := CubeSphere.surface_distance_m(s.dir, camp)
			if dd < bd:
				bd = dd
				ruin = s
		if not ruin.is_empty():
			break
	if ruin.is_empty():
		print("SKIP  no uninhabited ruin within 200 km")
	else:
		var fd := Camps.ruin_fire_dir(map, ruin)
		await _check("ruin %s (%s, %.1f km)" % [str(Ruins.Kind.keys()[int(ruin.kind)]).to_lower(), str(ruin.get("style", "")), CubeSphere.surface_distance_m(ruin.dir, camp) / 1000.0], fd, ruin.dir)
	# The nearest nest holding remains.
	var nest := {}
	var nd := INF
	for n in Nests.near(camp, 150000.0):
		if str(n.state) == "remains" and CubeSphere.surface_distance_m(n.dir, camp) < nd:
			nd = CubeSphere.surface_distance_m(n.dir, camp)
			nest = n
	if nest.is_empty():
		print("SKIP  no nest holding remains within 150 km")
	else:
		await _check("nest %s remains (%.1f km)" % [nest.kind, nd / 1000.0], nest.hearth, nest.dir)
	await _tomb_check(map, camp)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _go(d: Vector3, look: Vector3) -> void:
	var stand := CreatureSpawner._offset(d, 0.7, 4.0)
	var off: Vector3 = world.to_scene(stand, PlanetConst.RADIUS_M + world.surface_elevation(stand))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(stand)
	player.spawn_at(stand, look)
	main.landmarks.build_ruin_at(d)
	for i in 30:
		await process_frame


func _check(label: String, d: Vector3, look: Vector3) -> void:
	await _go(d, look)
	var oh: OldHearths = main.old_hearths
	var fire: Node3D = null
	var t0 := Time.get_ticks_msec()
	while fire == null and Time.get_ticks_msec() - t0 < 30000:
		oh.refresh_now()
		fire = oh.nearest(world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d)), 12.0)
		await process_frame
	ok(fire != null, "%s: a cold hearth stands at its camp spot" % label)
	if fire == null:
		return
	ok(fire.is_in_group(Campfire.GROUP) and not FireStore.is_lit(fire), "%s: it is a fire, and cold (%s)" % [label, FireStore.state_of(fire)])
	ok(not Campfire.lit_near(self, fire.global_position, 3.0), "%s: cold, it holds no dread back" % label)
	ok(not Hearth.can_set(fire), "%s: cold, it can't be made your hearth" % label)
	var st0 := FireStore.store_of(fire)
	ok(FireStore.units_now(st0) >= 1.0, "%s: its charred branches count as fuel (%.1f units)" % [label, FireStore.units_now(st0)])
	var how := FireStore.swing_light(fire, world.days)
	ok(how == "not_laid" and not FireStore.is_lit(fire), "%s: not laid, the swing won't light it (%s)" % [label, how])
	var days: float = world.days
	FireStore.lay_kindling(fire, _wet(Kindling.make("dry_twigs"), days), days)
	how = FireStore.swing_light(fire, days)
	ok(how == "wet" and not FireStore.is_lit(fire), "%s: wet dead twigs smoke and it stays cold (%s)" % [label, how])
	st0.erase("kindling")
	FireStore.lay_kindling(fire, _wet(Kindling.make("birch_bark"), days), days)
	how = FireStore.swing_light(fire, days)
	await _until_lit(fire)
	ok(how in ["ok", "catching"] and FireStore.is_lit(fire), "%s: wet birch bark catches all the same (%s, %s)" % [label, how, FireStore.state_of(fire)])
	# Again from cold, with dry kindling.
	var keep_units: Array = (st0.units as Array).duplicate(true)
	st0.state = "out"
	st0.units = keep_units
	FireStore.apply(fire)
	FireStore.lay_kindling(fire, Kindling.make("dry_twigs"), days)
	how = FireStore.swing_light(fire, days)
	var t_catch := float(st0.get("catch_s", 0.0))
	await _until_lit(fire)
	ok(how in ["ok", "catching"] and FireStore.is_lit(fire), "%s: laid with dry twigs, it lights (%s; the flame took in %.2f s)" % [label, how, t_catch])
	# Kindling alone flares and goes out.
	var flare := {"units": [], "embers_min": 0.0, "state": "out", "tended": false}
	FireStore.stores["check_flare"] = flare
	var probe := Node3D.new()
	probe.set_meta("fuel_key", "check_flare")
	FireStore.lay_kindling(probe, Kindling.make("dead_leaves"), days)
	var fh := FireStore.swing_light(probe, days)
	var flared := FireStore.is_lit(probe)
	FireStore._take(flare, Kindling.burn_s("dead_leaves") + 0.1)
	ok(fh == "flare" and flared and FireStore.state_of(probe) == "out", "kindling with no fuel flares for %.0f s and goes out (%s)" % [Kindling.burn_s("dead_leaves"), fh])
	# Embers come back from dry fuel alone.
	flare.state = "embers"
	flare.embers_min = 10.0
	var fr := FireStore.add_fuel(probe, Inventory.make("fuel", {"fuel": "branch"}), days)
	ok(fr == "ok" and FireStore.is_lit(probe), "embers relight from dry fuel alone, no kindling (%s, %s)" % [fr, FireStore.state_of(probe)])
	FireStore.stores.erase("check_flare")
	probe.free()
	ok(Campfire.lit_near(self, fire.global_position, 3.0), "%s: lit, it holds the dark off" % label)
	ok(Hearth.can_set(fire), "%s: lit, it can be made your hearth" % label)
	oh.refresh_now()
	var key := str(fire.get_meta("fuel_key"))
	ok((WorldSave.data.get("old_hearths", {}) as Dictionary).has(key), "%s: kept in the save once lit" % label)
	# Feed it (a hardwood log, as the right click with fuel does).
	var st := FireStore.store_of(fire)
	for i in 3:
		(st.units as Array).append(["hardwood_log", FireStore.burn_min("hardwood_log")])
	var days0: float = world.days
	world.days = days0 + 1.0 / 24.0 # an in-game hour: 6 real minutes
	ok(OldHearths.lit_at(world, world.dir_of(fire.global_position)), "%s: fed, still burning an hour later (%s)" % [label, str(st.state)])
	world.days = days0 + 1.0 # a day untended
	ok(not OldHearths.lit_at(world, world.dir_of(fire.global_position)), "%s: out a day later, untended (%s)" % [label, str(FireStore.store_of(fire).state)])
	world.days = days0


func _wet(it: Dictionary, days: float) -> Dictionary:
	it["wet"] = true
	it["wet_days"] = days
	return it


func _until_lit(fire: Node3D) -> void:
	for i in 180:
		if FireStore.is_lit(fire):
			return
		await process_frame


func _tomb_check(map: PlanetData, camp: Vector3) -> void:
	var tomb := {}
	for r in [30000.0, 120000.0, 400000.0]:
		var bd := INF
		for s in Ruins.near(map, camp, r):
			var k := int(s.kind)
			var lamps := k == Ruins.Kind.BARROW or k == Ruins.Kind.GRAVEYARD or (k == Ruins.Kind.PYRAMID and str(s.get("style", "")) == "desert")
			var want := OS.get_environment("TOMB")
			if want != "" and str(Ruins.Kind.keys()[k]).to_lower() != want:
				continue
			if not lamps or Ruins.inhabited(s) or not Hearths.ruin_kept(s):
				continue
			var dd := CubeSphere.surface_distance_m(s.dir, camp)
			if dd < bd:
				bd = dd
				tomb = s
		if not tomb.is_empty():
			break
	if tomb.is_empty():
		print("SKIP  no uninhabited tomb within 400 km")
		return
	var label := "tomb %s (%s, %.1f km)" % [str(Ruins.Kind.keys()[int(tomb.kind)]).to_lower(), str(tomb.get("style", "")), CubeSphere.surface_distance_m(tomb.dir, camp) / 1000.0]
	var fd := Camps.ruin_fire_dir(map, tomb)
	await _go(fd, tomb.dir)
	var oh: OldHearths = main.old_hearths
	var node: Node3D = null
	var t0 := Time.get_ticks_msec()
	while node == null and Time.get_ticks_msec() - t0 < 30000:
		for c in main.landmarks.built_ruins():
			var n: Node3D = main.landmarks.built_ruins()[c]
			if is_instance_valid(n) and (n.get_meta("site", {}) as Dictionary).get("seed", 0) == tomb.seed:
				node = n
		await process_frame
	ok(node != null and node.has_meta("lamps"), "%s: built, with %d stone lamps" % [label, (node.get_meta("lamps", []) as Array).size() if node != null else 0])
	if node == null or not node.has_meta("lamps"):
		return
	oh.refresh_now()
	var fire := oh.hearth_of_ruin(null, node)
	ok(fire != null, "%s: its old hearth stands" % label)
	if fire == null:
		return
	for i in 10:
		await process_frame
	ok(_lamp_energy(node) == 0.0, "%s: the lamps stand dark while the hearth is cold" % label)
	FireStore.relight(fire)
	for i in 240:
		await process_frame
	ok(_lamp_energy(node) > 0.05, "%s: rekindled, the lamps burn (energy %.2f)" % [label, _lamp_energy(node)])
	var st := FireStore.store_of(fire)
	st.units = []
	st.state = "out"
	FireStore.apply(fire)
	for i in 240:
		await process_frame
	ok(_lamp_energy(node) == 0.0, "%s: the fire dead, the lamps go out with it" % label)


func _lamp_energy(node: Node3D) -> float:
	var e := 0.0
	for l in node.get_meta("lamps", []):
		var light: OmniLight3D = l[0]
		if light.visible:
			e += light.light_energy
	return e


extends SceneTree
## Old hearths (Mike, 2 Oct; OldHearths), headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/old_hearth_check.gd
## Boots the game, goes to the nearest uninhabited ruin and the nearest
## nest holding remains, and asserts at each:
##  - a cold hearth stands there: a fire in the Campfire group, not lit,
##    holding no dread back, not yet a hearth you can take;
##  - a lit torch rekindles it (FireStore.relight, as the right click
##    does), and lit it holds the dark off (Campfire.lit_near) and can be
##    made your hearth (Hearth.can_set);
##  - it is kept: in the save once lit, and while you are away it burns
##    down on the clock (OldHearths.lit_at after an in-game hour: still
##    burning with fuel fed; out after a day untended).

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
			if Ruins.inhabited(s):
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
	var how := FireStore.relight(fire)
	ok(how == "ok" and FireStore.is_lit(fire), "%s: a lit torch rekindles it (%s, %s)" % [label, how, FireStore.state_of(fire)])
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

extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script tools/dread_check.gd
## The ambient cut (design 30 Sept): the fuel store burns down and
## relights (§AX), the hearth is the opening camp (§AY), the log opens on
## Enter and keeps a note (§AZ), and the dark takes you: with no light on
## you the meter climbs through the stages, the hunter closes, "Taken by
## the dark" goes in the log and you wake at the hearth (§BA). Runs in
## the ambient profile (the default).
var main
var world
var player: PlanetPlayer
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func act(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	main._unhandled_input(e)


func key(code: Key, unicode: int = 0) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.unicode = unicode
	main.log_panel._input(e)


func _initialize() -> void:
	world = get_root().get_node("World")
	world.pin(42, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(120)
	ok(Tuning.profile() == "ambient", "the ambient profile (%s)" % Tuning.profile())

	# --- Fuel (§AX) ---
	var fire: Node3D = main.camp.fire()
	ok(FireStore.state_of(fire) == "flames" and bool(fire.get_meta("lit", false)), "the opening camp's fire burns (flames, lit)")
	var st := FireStore.store_of(fire)
	ok(FireStore.units_now(st) > 7.0, "it starts with the biome's units (%.1f)" % FireStore.units_now(st))
	st.units = [["branch", 0.00001]]
	await frames(5)
	ok(FireStore.state_of(fire) == "embers" and not bool(fire.get_meta("lit", true)), "the store burnt out: embers, not lit (%s)" % FireStore.state_of(fire))
	ok(not Campfire.lit_near(main.get_tree(), fire.global_position, 3.0), "lit_near() says no by the embers")
	st.embers_min = 0.00001
	await frames(5)
	ok(FireStore.state_of(fire) == "out", "embers gone: out (%s)" % FireStore.state_of(fire))
	ok(FireStore.relight(fire) == "no_fuel", "a torch on a dead, empty fire: nothing to burn")
	var log := Inventory.make("fuel", {"fuel": "hardwood_log", "carry_items": 2})
	ok(FireStore.add_fuel(fire, log, world.days) == "cold", "fuel on a dead fire stacks cold")
	ok(FireStore.relight(fire) == "ok" and FireStore.state_of(fire) in ["flames", "low"], "a lit torch relights it (%s)" % FireStore.state_of(fire))
	var full := 0
	for i in 20:
		if FireStore.add_fuel(fire, Inventory.make("fuel", {"fuel": "branch"}), world.days) == "full":
			full += 1
	ok(full > 0 and FireStore.units_now(FireStore.store_of(fire)) <= float(FireStore.F.get("store_max_units", 12)) + 0.01, "the store caps at store_max_units (%.1f)" % FireStore.units_now(FireStore.store_of(fire)))
	ok(GameLog.entries.any(func(e): return e.kind == "fire_out"), "the log has the fire going out")

	# --- Hearth (§AY) ---
	ok(Hearth.key == FireStore.key_of(main.camp.site) and Hearth.is_home(fire), "the first hearth is the opening camp's fire")

	# --- The log (§AZ) ---
	ok(not main.log_panel.visible, "the log is closed")
	act("log")
	await frames(2)
	ok(main.log_panel.visible and player.typing, "Enter opens the log; the keys are its")
	for ch in "wet night":
		key(KEY_NONE, ch.unicode_at(0))
	key(KEY_ENTER)
	await frames(2)
	var last: Dictionary = GameLog.entries[GameLog.entries.size() - 1]
	ok(last.kind == "note" and last.text == "wet night" and str(last.t).begins_with("Day "), "Enter keeps the note, stamped (%s · %s)" % [last.t, last.text])
	key(KEY_ESCAPE)
	await frames(2)
	ok(not main.log_panel.visible and not player.typing, "Esc closes it")
	ok(WorldSave.data.has("log") and WorldSave.data.has("hearth"), "the log and the hearth are in the world's save")

	# --- The dark (§BA) ---
	var dread: Dread = main.dread
	ok(dread.enabled and dread.meter == 0.0 and dread.stage == 0, "by the fire by day: quiet (meter %.2f)" % dread.meter)
	# 40 m off, no light on you, night forced.
	var off := CreatureSpawner._offset(main.camp.site, 1.0, 40.0)
	player.spawn_at(off, main.camp.site)
	dread.force_dark = true
	dread.meter = 0.0
	await frames(120)
	ok(dread.meter > 0.0, "in the dark past the grace the meter fills (%.3f after 2 s)" % dread.meter)
	dread.meter = 0.45
	await frames(5)
	ok(dread.stage == 2, "stage 2 at 0.4: behind you (%d)" % dread.stage)
	dread.meter = 0.85
	await frames(5)
	ok(dread.stage == 4 and dread._hunter != null and dread._hunter.visible, "stage 4: it follows in the open, a hunter in the world")
	var entry: Dictionary = dread._hunter_entry
	print("[dread] hunter: %s (%s) in %s" % [entry.get("creature", "the dark"), entry.get("pattern", "?"), FireStore.biome_key(world, player.surface_dir)])
	dread.meter = 1.0
	var t := 0
	while not player.dead and t < 1500:
		await frames(1)
		t += 1
	ok(player.dead, "stage 5 with no light: it closes and takes you (%.1f s)" % (t / 60.0))
	var death := GameLog.entries.filter(func(e): return e.kind == "death_cause")
	ok(not death.is_empty() and death[death.size() - 1].text == "Taken by the dark", "the log: Taken by the dark")
	dread.force_dark = false
	t = 0
	while player.dead and t < 900:
		await frames(1)
		t += 1
	await frames(30)
	ok(not player.dead and player.global_position.distance_to(fire.global_position) < 12.0, "you wake at the hearth (%.1f m from its fire)" % player.global_position.distance_to(fire.global_position))
	ok(dread.meter == 0.0 and dread.stage == 0 and dread._hunter == null, "the dark is gone: meter 0, no hunter")
	# By the fire the meter drains.
	dread.force_dark = true
	dread.meter = 0.5
	await frames(120)
	ok(dread.meter < 0.5, "by the lit fire the meter drains (%.3f)" % dread.meter)
	dread.force_dark = false

	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

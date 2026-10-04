extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script tools/dread_check.gd
## The ambient cut (design 30 Sept): the fuel store burns down and
## relights (§AX), the opening camp's fire made your hearth (§AY, §DE), the
## log opens on Enter and keeps a note (§AZ), and the dark takes you: with
## no light on you the meter climbs through the stages, the hunter closes,
## you wake at the hearth and the log has the dark's line (§BA, §DE). Runs in
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

	# --- Hearth (§AY, amended by §DE: none until you make one) ---
	ok(Hearth.dir == Vector3.ZERO and not Hearth.is_home(fire) and Hearth.can_set(fire), "no hearth until you make one, and the opening camp's lit fire can be made it")
	Hearth.set_home(world.dir_of(fire.global_position))
	ok(Hearth.is_home(fire), "made home, it is the hearth")

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
	ok(last.kind == "note" and last.text == "wet night" and str(last.t).begins_with("Y"), "Enter keeps the note, stamped (%s · %s)" % [last.t, last.text])
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
	dread.force_dark = false
	t = 0
	while player.dead and t < 900:
		await frames(1)
		t += 1
	await frames(30)
	ok(not player.dead and player.global_position.distance_to(fire.global_position) < 12.0, "you wake at the hearth (%.1f m from its fire)" % player.global_position.distance_to(fire.global_position))
	# Found alive (§DE): the cause line is camps.json wake_found's wording.
	var dark_line := str((LostDays.W.get("death_lines_found", {}) as Dictionary).get("dark", "Taken by the dark"))
	var death := GameLog.entries.filter(func(e): return e.kind == "death_cause")
	ok(not death.is_empty() and death[death.size() - 1].text == dark_line, "the log: %s" % (death[death.size() - 1].text if not death.is_empty() else "nothing"))
	ok(dread.meter == 0.0 and dread.stage == 0 and dread._hunter == null, "the dark is gone: meter 0, no hunter")
	# By the fire the meter drains.
	dread.force_dark = true
	dread.meter = 0.5
	await frames(120)
	ok(dread.meter < 0.5, "by the lit fire the meter drains (%.3f)" % dread.meter)
	dread.force_dark = false

	# --- The full-moon werewolf (design 3 Oct §DG) ---
	var thr := DayCycle.full_moon_illumination()
	var half := Dread.entry_for("TEMPERATE_DECIDUOUS", 0.5)
	ok(half.get("creature") == null, "a temperate deciduous forest at a lit share of 0.5: the fallback lurker (%s)" % str(half.get("creature")))
	var bright := Dread.entry_for("TEMPERATE_DECIDUOUS", 0.98)
	var v := Dread.speed_for(bright, 0.98)
	ok(str(bright.get("creature", "")) == "Werewolf" and is_equal_approx(v, 6.5 * 1.3), "at 0.98: the werewolf, %.2f m/s (6.5 x 1.3)" % v)
	ok(Dread.entry_for("TEMPERATE_DECIDUOUS", thr - 0.005).get("creature") == null and str(Dread.entry_for("TEMPERATE_DECIDUOUS", thr).get("creature", "")) == "Werewolf", "the hunter turns werewolf at %.2f lit, not before" % thr)
	var wolf := CreatureSpecies.find("Werewolf")
	if wolf != null:
		var at := func(m: float) -> bool:
			CreatureSpecies.moon_full = m
			return wolf.active_now(0.0)
		var a86: bool = at.call(0.86)
		var a96: bool = at.call(thr - 0.01)
		var a97: bool = at.call(thr)
		ok(not a86 and not a96 and a97, "active_now flips at %.2f, not 0.85 (0.86: %s, %.2f: %s, %.2f: %s)" % [thr, a86, thr - 0.01, a96, thr, a97])
	else:
		ok(false, "the Werewolf species exists")
	# From downwind: a steady 5 m/s wind, the side it keeps.
	dread._ensure_hunter()
	dread._hunter_entry = bright
	var dwd := CubeSphere.east(player.surface_dir) * 0.6 + CubeSphere.north(player.surface_dir) * 0.8
	Dread.wind_pin = dwd.normalized() * 5.0
	var down := dread.downwind_bearing()
	var within := 0
	var n_s := 600
	for i in n_s:
		var b := dread.pick_scent_bearing(1.0 / 60.0 * 10.0)
		if absf(angle_difference(b, down)) <= deg_to_rad(45.0):
			within += 1
	ok(float(within) / n_s >= 0.8, "with a steady 5 m/s wind the werewolf keeps within 45° of downwind in %d %% of %d samples" % [int(100.0 * within / n_s), n_s])
	Dread.wind_pin = Vector3.INF
	# A torch changes nothing about whether it notices you.
	var r_dark := Dread.dark_rate(0.6, false, bright)
	var r_torch := Dread.dark_rate(0.6, true, bright)
	var r_lurker := Dread.dark_rate(0.6, true, half)
	ok(Dread.by_scent(bright) and is_equal_approx(r_dark, r_torch) and r_lurker < r_dark, "it hunts by scent: its meter fills %.3f/min with a torch and %.3f without (the lurker's slows to %.3f by the torch)" % [r_torch, r_dark, r_lurker])

	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

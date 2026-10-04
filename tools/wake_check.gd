extends SceneTree
## Waking found by folk (design 3 Oct §DE, camps.json wake_found), on one
## pinned world, headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/wake_check.gd
##  - die 3 km from a lit home hearth (the opening camp, made home): you
##    wake there;
##  - with no hearth: at the nearest lit camp with folk from where you fell
##    (no candidate nearer that passes);
##  - with the home camp (a people's camp at a ruin) overrun: the nearest
##    instead, never the overrun ruin;
##  - over 20 rolls the lost days all fall in [1, 3] and are not all
##    equal; each death moved the clock by exactly its rolled span;
##  - the log holds the cause line ("Struck down by a wolf") then the
##    found line, in that order, both stamped at the waking;
##  - the body and its gear are still where you fell, the lit torch on it
##    burnt out;
##  - the camp's fire burnt about lost days x its daily burn (the catch-up
##    ran): the fuel gone from its store plus what its woodpile fed it.

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
	for i in 10:
		await process_frame
	var camp: Vector3 = main.camp.site
	print("[wake] seed %d" % seed_v)
	ok(Hearth.dir == Vector3.ZERO, "a new world has no hearth until you make one (§DE amends §AY)")

	# --- 1. Home: the opening camp made home, death 3 km off. ---
	Hearth.set_home(camp, false)
	var far := CreatureSpawner._offset(camp, 1.1, 3000.0)
	await _stand_at(far)
	var fell: Vector3 = main.player.surface_dir
	main.player.inventory.add(Inventory.make("torch", {"lit": true, "burn_left_min": 40.0}))
	var st: Dictionary = main.camp_sim.state_of("opening")
	var fed0 := float(st.get("wood_fed", 0.0))
	var min0 := _store_min(str(st.fire_key))
	var n_log := GameLog.entries.size()
	main.player.death_cause = "creature:Wolf"
	await _die()
	var woke := CubeSphere.surface_distance_m(main.player.surface_dir, camp)
	ok(str(main.last_wake.get("from", "")) == "home" and woke < 30.0, "die %.1f km from a lit home hearth: you wake there (%.0f m from its fire; %s)" % [CubeSphere.surface_distance_m(fell, camp) / 1000.0, woke, str(main.last_wake)])
	var L: Dictionary = LostDays.last
	var span := float(L.get("span", 0.0))
	ok(span >= 1.0 and span <= 3.0 and is_equal_approx(float(L.after) - float(L.before), span), "the clock moved by exactly the rolled span (%.4f days; %.4f -> %.4f)" % [span, float(L.before), float(L.after)])
	# The log: cause, then found, stamped at the waking.
	var new_lines: Array = GameLog.entries.slice(n_log)
	var cause_i := -1
	var found_i := -1
	for i in new_lines.size():
		if str(new_lines[i].kind) == "death_cause":
			cause_i = i
		elif str(new_lines[i].kind) == "found":
			found_i = i
	var keep: float = world.days
	world.days = float(L.after)
	var want_t: String = world.stamp_text(camp)
	world.days = keep
	ok(cause_i >= 0 and found_i == cause_i + 1, "the log holds the cause line then the found line, in that order (%s)" % str(new_lines.map(func(e): return "%s: %s" % [e.t, e.text])))
	if cause_i >= 0 and found_i >= 0:
		var c: Dictionary = new_lines[cause_i]
		var f: Dictionary = new_lines[found_i]
		ok(str(c.text) == "Struck down by a wolf" and str(f.text) == LostDays.found_line(span) and str(f.text).contains("Folk found you"), "found alive: '%s' then '%s'" % [c.text, f.text])
		ok(str(c.t) == want_t and str(f.t) == want_t, "both stamped at the waking (%s, %s; want %s)" % [c.t, f.t, want_t])
	# The body and its gear.
	var body: PlayerCorpse = null
	for c in PlayerCorpse.lying:
		if is_instance_valid(c) and CubeSphere.surface_distance_m(world.dir_of(c.global_position), fell) < 3.0:
			body = c
	var torch_out := false
	var n_items := 0
	if body != null:
		for it in LostDays._items(body):
			n_items += 1
			if str(it.get("kind", "")) == "torch" and bool(it.get("burnt", false)) and not bool(it.get("lit", true)):
				torch_out = true
	ok(body != null and n_items > 0, "the body is where you fell with its gear (%d things)" % n_items)
	ok(torch_out, "the lit torch on it burnt out in the lost days")
	ok(main.player.inventory.count() == 0 or not main.player.inventory.has_kind("torch"), "you woke empty-handed (%d things carried)" % main.player.inventory.count())
	# The camp's fire burnt through the lost days: what left its store,
	# plus what the woodpile fed it, in woodpile units (a branch's burning).
	var fed := float(st.get("wood_fed", 0.0)) - fed0
	var burnt := (min0 - _store_min(str(st.fire_key))) / FireStore.burn_min("branch") + fed
	var want := span * CampSim.burn_units_per_day()
	ok(absf(burnt - want) <= maxf(want * 0.2, 1.0), "the camp's fire burnt %.1f woodpile units over %.2f days (%.1f of them fed from the woodpile; its daily burn %.1f, so about %.1f)" % [burnt, span, fed, CampSim.burn_units_per_day(), want])

	# --- 2. No hearth: the nearest lit camp with folk. ---
	Hearth.clear()
	var far2 := CreatureSpawner._offset(camp, 4.0, 5000.0)
	await _stand_at(far2)
	var fell2: Vector3 = main.player.surface_dir
	var want2: Dictionary = main.camps.found_fire(fell2, camp)
	var nearer := _nearer_ok(fell2, camp, want2)
	main.player.death_cause = "fall"
	await _die()
	var woke2 := CubeSphere.surface_distance_m(main.player.surface_dir, want2.get("dir", camp))
	ok(not want2.is_empty() and str(main.last_wake.get("from", "")) == "nearest" and woke2 < 30.0, "no hearth: you wake at the nearest lit camp with folk, %s %.1f km from where you fell (%.0f m from its fire)" % [str(want2.get("key", "?")), CubeSphere.surface_distance_m(fell2, want2.get("dir", camp)) / 1000.0, woke2])
	ok(nearer == "", "no lit camp with folk is nearer to where you fell (%s)" % ("none" if nearer == "" else nearer))

	# --- 3. The home camp overrun: the nearest instead. ---
	var home_site := {}
	for r in Ruins.near(world.planet, camp, 40000.0):
		if Ruins.inhabited(r) and not Overrun.is_overrun(r):
			if home_site.is_empty() or CubeSphere.surface_distance_m(r.dir, camp) < CubeSphere.surface_distance_m(home_site.dir, camp):
				home_site = r
	ok(not home_site.is_empty(), "a people's camp at a ruin to make home (%.1f km from the opening camp)" % (CubeSphere.surface_distance_m(home_site.get("dir", camp), camp) / 1000.0))
	if not home_site.is_empty():
		var hf := Camps.ruin_fire_dir(world.planet, home_site)
		Hearth.set_home(hf, false)
		Overrun.saved()[Overrun.id_of(home_site)] = {"state": "overrun", "dir": [hf.x, hf.y, hf.z]}
		var far3 := CreatureSpawner._offset(hf, 2.5, 3000.0)
		await _stand_at(far3)
		var fell3: Vector3 = main.player.surface_dir
		var want3: Dictionary = main.camps.found_fire(fell3, camp)
		main.player.death_cause = "dark"
		await _die()
		var woke3: Vector3 = main.player.surface_dir
		ok(str(main.last_wake.get("home_fault", "")) == "overrun" and CubeSphere.surface_distance_m(woke3, hf) > 100.0 and CubeSphere.surface_distance_m(woke3, want3.get("dir", camp)) < 30.0,
			"home overrun: skipped (%s), you wake at the nearest instead, %s (%.0f m from its fire, %.1f km from the overrun home)" % [str(main.last_wake.get("home_fault", "")), str(want3.get("key", "?")), CubeSphere.surface_distance_m(woke3, want3.get("dir", camp)), CubeSphere.surface_distance_m(woke3, hf) / 1000.0])
		Overrun.saved().erase(Overrun.id_of(home_site))

	# --- 4. Twenty rolls. ---
	var spans: Array = []
	for i in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, i, world.days])
		spans.append(LostDays.roll(rng))
	var lo: float = spans.min()
	var hi: float = spans.max()
	ok(lo >= 1.0 and hi <= 3.0 and hi - lo > 0.1, "20 rolls of lost days all in [1, 3] and not all equal (%.2f to %.2f)" % [lo, hi])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Stand at surface direction `d`, its ground loaded (as main's waking).
func _stand_at(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(offset)
	main.player.global_position -= offset
	main.chunks.load_blocking(d)
	main.player.spawn_at(d, CreatureSpawner._offset(d, 0.0, 10.0))
	for i in 5:
		await process_frame


func _die() -> void:
	await main._on_player_died()
	for i in 10:
		await process_frame


## A candidate nearer to `d` than `got` that passes Camps.found_fault, or "".
func _nearer_ok(d: Vector3, opening: Vector3, got: Dictionary) -> String:
	var lim := CubeSphere.surface_distance_m(got.get("dir", d), d) - 1.0
	if CubeSphere.surface_distance_m(opening, d) < lim and main.camps.found_fault({"key": "opening", "dir": opening, "site": {}}) == "":
		return "the opening camp"
	for r in Ruins.near(world.planet, d, lim):
		if not (Ruins.inhabited(r) or Overrun.settled(r)):
			continue
		var fd := Camps.ruin_fire_dir(world.planet, r)
		if CubeSphere.surface_distance_m(fd, d) < lim and main.camps.found_fault({"key": Overrun.camp_key(world.planet, r), "dir": fd, "site": r}) == "":
			return "ruin camp %s" % Overrun.camp_key(world.planet, r)
	return ""


## The minutes of burning left in the fire store `key` (each unit holds
## its own minutes, whatever its kind; FireStore.burn takes them alike).
func _store_min(key: String) -> float:
	var fst: Dictionary = FireStore.stores.get(key, {})
	var m := 0.0
	for u in fst.get("units", []):
		m += float(u[1])
	return m

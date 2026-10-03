extends SceneTree
## Smoke from every hearth (design 3 Oct §CV, data/smoke.json, Smoke),
## headless, full planet:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/hearth_smoke_check.gd
## Asserts:
##  - the opening camp's fire sends up a column sized by its state
##    (hearth.by_state: flames, low, embers; out none);
##  - it leans with the wind (lean_deg_per_mps, up to max_lean_deg; still
##    under calm_below_mps), pools flat on a still dawn, is beaten down by
##    rain, and at night draws only its fire-lit foot;
##  - the far hearths within far.seen_to_m that aren't built are listed
##    and drawn from the sim's fire state, at least far.min_px wide;
##  - a barrow delve's first-room hearth and heart each have a stack on
##    the mound above (its form, a sooted lip), and their smoke leaves from
##    the stack's mouth, not underground; cold, no smoke;
##  - the swifts' clock: hunting by day, circling then pouring in at dusk,
##    in at night, pouring out at dawn, gone while the hearth burns and
##    until it has been cold return_after_cold_game_days;
##  - a wildfire's plume stands over a fresh scar, wide, tall and dark, and
##    is gone once it has burned out;
##  - every fire smokes by its flame's size (Mike, 3 Oct; hearth.by_flame):
##    every Campfire in the world, a fire you lay, a tomb lamp's thread, the
##    torch's burnt end's wisp (trailing as you walk), the pipe's brand; the
##    column the by_state row x size^exponent.

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


func _p(col: Node3D, key: String) -> Variant:
	return (col.get_meta("mat") as ShaderMaterial).get_shader_parameter(key)


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, -1)
	Bow.need_capture = false
	WorldSave.read_only = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	player.set_physics_process(false)
	var H: Dictionary = Smoke.H
	var fire: Node3D = main.camp.fire()
	for i in 5:
		await process_frame
	var col: Node3D = fire.get_meta("smoke_col") if fire.has_meta("smoke_col") else null
	ok(col != null, "the opening camp's fire has a smoke column")
	if col == null:
		_end()
		return
	var st := FireStore.store_of(fire)
	var keep := str(st.get("state", "flames"))
	Smoke.calm_dawn = false
	for state in ["flames", "low", "embers", "out"]:
		var want := Smoke.size_for(state)
		Smoke.update(col, fire.global_position, fire.global_basis.y, state, Vector3.ZERO, 0.0, 0.0, false)
		if state == "out":
			ok(not col.visible, "out: no smoke")
		else:
			ok(col.visible and is_equal_approx(float(_p(col, "top_m")), want.x) and is_equal_approx(float(_p(col, "width_m")), want.y), "%s: a column %.0f m tall, %.1f m wide, %.2f solid" % [state, want.x, want.y, want.z])
	var up: Vector3 = fire.global_basis.y.normalized()
	var east := up.cross(Vector3.FORWARD).normalized()
	var W: Dictionary = H.get("wind", {})
	for mps in [0.5, 3.0, 12.0]:
		Smoke.update(col, fire.global_position, up, "flames", east * mps, 0.0, 0.0, false)
		var lean: Vector3 = _p(col, "lean")
		var deg := rad_to_deg(atan(lean.length()))
		var want_deg := 0.0 if mps <= float(W.get("calm_below_mps", 1.0)) else minf(mps * float(W.get("lean_deg_per_mps", 8.0)), float(W.get("max_lean_deg", 70.0)))
		ok(absf(deg - want_deg) < 0.5 and (mps <= 1.0 or lean.normalized().dot(east) > 0.99), "a %.1f m/s wind leans it %.0f° downwind (want %.0f°)" % [mps, deg, want_deg])
	Smoke.update(col, fire.global_position, up, "flames", Vector3.ZERO, 0.0, 0.0, true)
	ok(float(_p(col, "pool")) > 0.5, "a still dawn: it pools flat at %.0f m" % float(_p(col, "pool_m")))
	Smoke.update(col, fire.global_position, up, "flames", east * 3.0, 0.0, 0.0, true)
	ok(float(_p(col, "pool")) < 0.5, "a breezy dawn: it doesn't pool")
	var rain: Dictionary = H.get("rain", {})
	Smoke.update(col, fire.global_position, up, "flames", Vector3.ZERO, float(rain.get("from_mm_h", 1.0)) + 1.0, 0.0, false)
	ok(is_equal_approx(float(_p(col, "top_m")), Smoke.size_for("flames").x * float(rain.get("top_scale", 0.5))), "rain beats it down to %.0f m" % float(_p(col, "top_m")))
	Smoke.update(col, fire.global_position, up, "flames", Vector3.ZERO, 0.0, 1.0, false)
	ok(float(_p(col, "night")) > 0.99, "at night only its fire-lit foot (%.0f m) draws" % float(_p(col, "fire_lit_m")))
	# In play: the column follows the fire's state.
	st["state"] = "low"
	Campfire.night = 0.0
	Smoke.tick_fire(fire)
	ok(is_equal_approx(float(_p(col, "top_m")), Smoke.size_for("low").x), "in play the column follows the fire's state (low: %.0f m)" % float(_p(col, "top_m")))
	st["state"] = keep
	await _small_fires(fire)
	# Far hearths.
	var pd: Vector3 = world.dir_of(player.global_position)
	var t_us := Time.get_ticks_usec()
	var far := Smoke.far_hearths(main, pd, float((H.get("far", {}) as Dictionary).get("seen_to_m", 3200.0)))
	var first_us := Time.get_ticks_usec() - t_us
	t_us = Time.get_ticks_usec()
	Smoke.far_hearths(main, pd, float((H.get("far", {}) as Dictionary).get("seen_to_m", 3200.0)))
	print("[smoke] the far-hearth search takes %.1f ms the first time, %.1f ms after (every %.1f s)" % [first_us / 1000.0, (Time.get_ticks_usec() - t_us) / 1000.0, Smoke.FAR_EVERY_S])
	print("[smoke] %d far hearths within %.1f km" % [far.size(), float((H.get("far", {}) as Dictionary).get("seen_to_m", 3200.0)) / 1000.0])
	var far_ok := true
	for f in far:
		if float(f[3]) < Camps.BUILD_M or float(f[3]) > 3200.0:
			far_ok = false
	ok(far_ok, "every far hearth is past the camps' build range and within sight")
	Smoke.far_columns(main, pd, 1.0)
	var shown := 0
	for c in Smoke._far_cols:
		if c.visible:
			shown += 1
	var lit := 0
	for f in far:
		if str(f[1]) in ["flames", "low", "embers", "flare"]:
			lit += 1
	ok(shown == mini(lit, Smoke.FAR_MAX), "the lit ones are drawn (%d of %d)" % [shown, lit])
	# From 1.5 km short of the opening road's camp, it is a far hearth.
	var ruin: Vector3 = world.opening.get("ruin", Vector3.ZERO)
	if ruin != Vector3.ZERO:
		var dm := CubeSphere.surface_distance_m(pd, ruin)
		var near_pt := ruin.slerp(pd, 1500.0 / maxf(dm, 1.0)).normalized()
		var far2 := Smoke.far_hearths(main, near_pt, 3200.0)
		var found := false
		for f in far2:
			if CubeSphere.surface_distance_m(f[0], ruin) < 200.0:
				found = true
				print("[smoke] 1.5 km from the road's camp: its hearth is a far hearth, %s, %.1f km off" % [f[1], float(f[3]) / 1000.0])
		ok(found, "1.5 km from the road's camp its hearth is drawn from the sim, though it isn't built (%d far hearths there)" % far2.size())
	await _stacks()
	_swifts()
	_plume(pd)
	_end()


func _stacks() -> void:
	var map: PlanetData = world.planet
	var camp: Vector3 = main.camp.site
	var site := {}
	for r in [40000.0, 150000.0, 400000.0]:
		var bd := INF
		for s in Ruins.near(map, camp, r):
			if not Delves.has_delve(s):
				continue
			var dd := CubeSphere.surface_distance_m(s.dir, camp)
			if dd < bd:
				bd = dd
				site = s
		if not site.is_empty():
			break
	if site.is_empty():
		print("SKIP  no barrow with a delve within 400 km")
		return
	var d: Vector3 = Delves.to_dir(Delves.frame(map, site), 0.0, -float(site.half_l) - 8.0)
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	player.global_position -= off
	main.chunks.load_blocking(d)
	player.spawn_at(d, site.dir)
	main.landmarks.build_ruin_at(d)
	var fires: Array = []
	var t0 := Time.get_ticks_msec()
	while fires.size() < 2 and Time.get_ticks_msec() - t0 < 40000:
		main.old_hearths.refresh_now()
		fires.clear()
		for k in main.old_hearths._built:
			var f: Node3D = main.old_hearths._built[k]
			if is_instance_valid(f) and f.has_meta("smoke_stack"):
				fires.append(f)
		await process_frame
	ok(fires.size() >= 2, "the barrow's first-room hearth and heart each have a stack (%d)" % fires.size())
	for f in fires:
		var stk: Node3D = f.get_meta("smoke_stack")
		var form := str(stk.get_meta("form"))
		var above: float = stk.global_position.distance_to(f.global_position)
		var up := stk.global_basis.y.normalized()
		var rise: float = (stk.global_position - f.global_position).dot(up)
		ok(form == Smoke.stack_form("barrow") and stk.get_node_or_null("Lip") != null and rise > 1.0, "%s: a %s with a sooted lip on the mound, %.1f m above the hearth" % [f.name, form, rise])
		var store := FireStore.store_of(f)
		var keep := str(store.get("state", "out"))
		store["state"] = "flames"
		Campfire.night = 0.0
		Smoke.tick_fire(f)
		var col: Node3D = f.get_meta("smoke_col")
		var base: Vector3 = _p(col, "base")
		var mouth := stk.global_position + up * float(stk.get_meta("mouth"))
		ok(col.visible and base.distance_to(mouth) < 0.05 and is_equal_approx(float(_p(col, "top_m")), Smoke.size_for("flames").x * float(Smoke.H.get("stack_scale", 0.7))), "%s lit: its smoke leaves the stack's mouth, %.0f m tall" % [f.name, float(_p(col, "top_m"))])
		store["state"] = "out"
		Smoke.tick_fire(f)
		ok(not col.visible, "%s cold: no smoke" % f.name)
		store["state"] = keep
		var _a := above


func _swifts() -> void:
	var lb: Dictionary = (Smoke.SW.get("lit_below", {}) as Dictionary)
	var back := float(lb.get("return_after_cold_game_days", 10))
	var seq := []
	for sun in [10.0, 1.5, 0.0, -1.5, -3.5, -6.0]:
		seq.append(str(Smoke.swift_mode(sun, false, 30.0, false).mode))
	print("[smoke] swifts at dusk, sun 10° .. -6°: %s" % ", ".join(seq))
	ok(seq == ["hunt", "circle", "circle", "circle", "enter", "in"], "at dusk they hunt, circle, pour in, and are in by dark")
	var dawn := []
	for sun in [-6.0, -3.0, 0.0, 3.0]:
		dawn.append(str(Smoke.swift_mode(sun, true, 30.0, false).mode))
	print("[smoke] swifts at dawn, sun -6° .. 3°: %s" % ", ".join(dawn))
	ok(dawn == ["in", "leave", "leave", "hunt"], "at dawn they pour out, then hunt")
	ok(str(Smoke.swift_mode(10.0, false, 30.0, true).mode) == "away" and str(Smoke.swift_mode(10.0, false, back - 1.0, false).mode) == "away" and str(Smoke.swift_mode(10.0, false, back + 1.0, false).mode) == "hunt", "light the hearth and they leave; they come back after %.0f days cold" % back)
	# A flock on a stack: out by day, in by night.
	var holder := Node3D.new()
	get_root().add_child(holder)
	var stk := Smoke.stack(holder, Vector3(0, 0, 0), Vector3.UP, "mound_vent", 5)
	var flock := Smoke.swift_flock(stk, 9)
	var n := flock.multimesh.instance_count
	var day := Smoke.fly_swifts(flock, Smoke.swift_mode(20.0, false, 30.0, false), 1.0)
	var night := Smoke.fly_swifts(flock, Smoke.swift_mode(-10.0, false, 30.0, false), 1.0)
	var half := Smoke.fly_swifts(flock, {"mode": "enter", "k": 0.5}, 1.0)
	ok(day == n and night == 0 and half > 0 and half < n, "a flock of %d: all out by day, %d still out halfway through pouring in, none at night" % [n, half])
	holder.free()


func _plume(pd: Vector3) -> void:
	var scar := {"dir": [pd.x, pd.y, pd.z], "along": 400.0, "across": 200.0, "heading": 0.0, "day": world.days, "why": "check"}
	CampSim.scars.append(scar)
	Campfire.night = 0.0
	Smoke.plumes(main, pd)
	var p: Node3D = Smoke._plume
	ok(p != null and p.visible and float(_p(p, "top_m")) >= float(Smoke.WP.get("top_m", 400.0)) * 0.99, "a fresh wildfire's plume stands %.0f m tall, %.0f m wide" % [float(_p(p, "top_m")), float(_p(p, "width_m")) * 2.0])
	scar.day = world.days - (Smoke.PLUME_GAME_H + 1.0) / 24.0
	Smoke.plumes(main, pd)
	ok(not p.visible, "and is gone once the fire has burned out")
	CampSim.scars.erase(scar)


## Every fire smokes by its flame's size (Mike, 3 Oct).
func _small_fires(fire: Node3D) -> void:
	var lacking := 0
	var fires := get_nodes_in_group(Campfire.GROUP)
	for f in fires:
		if not (f as Node).has_meta("smoke"):
			lacking += 1
	ok(lacking == 0, "every fire in the world smokes (%d fires, %d without)" % [fires.size(), lacking])
	var up: Vector3 = fire.global_basis.y.normalized()
	var d: Vector3 = world.dir_of(fire.global_position + fire.global_basis.x * 6.0)
	var laid: Node3D = main.player_fires.lay_fire(d, 2)
	for i in 3:
		await process_frame
	var lc = laid.get_meta("smoke_col") if laid.has_meta("smoke_col") else null
	var ls := Smoke.state_of(laid)
	ok(lc != null and (lc as Node3D).visible and is_equal_approx(float(_p(lc, "top_m")), Smoke.size_for(ls).x), "a fire you lay smokes like a camp's (%s: %.0f m)" % [ls, float(_p(lc, "top_m")) if lc != null else 0.0])
	Smoke.calm_dawn = false
	Smoke.wind = Vector3.ZERO
	Smoke.rain_mm_h = 0.0
	Campfire.night = 0.0
	var ex := float((Smoke.H.get("by_flame", {}) as Dictionary).get("exponent", 2.0))
	# A tomb lamp's flame (RuinBuilder's, 0.14 of a campfire's).
	var lamp := Torch.flame_node(0.14)
	main.add_child(lamp)
	lamp.global_position = fire.global_position + fire.global_basis.x * 3.0
	Torch.smoke_flame(lamp, up)
	var want := Smoke.size_for("flames") * Vector3(pow(0.14, ex), pow(0.14, ex), 1.0)
	var lcol: Node3D = lamp.get_meta("smoke_col")
	ok(lcol.visible and is_equal_approx(float(_p(lcol, "top_m")), want.x) and is_equal_approx(float(_p(lcol, "width_m")), want.y), "a lamp sends up a thread %.2f m tall, %.2f m wide" % [float(_p(lcol, "top_m")), float(_p(lcol, "width_m"))])
	lamp.visible = false
	ok(not lcol.is_visible_in_tree(), "and it goes with the flame")
	# The torch's burnt end: a wisp, trailing behind as you walk.
	var ember := Node3D.new()
	main.add_child(ember)
	ember.global_position = fire.global_position + fire.global_basis.x * 4.0 + up
	var walk := up.cross(Vector3.FORWARD).normalized() * 1.7
	Torch.smoke_ember(ember, up, -walk)
	var ecol: Node3D = ember.get_meta("smoke_col")
	var ts := float((Campfire.FL.get("torch", {}) as Dictionary).get("scale", 0.32))
	var lean: Vector3 = _p(ecol, "lean")
	ok(ecol.visible and is_equal_approx(float(_p(ecol, "top_m")), Smoke.size_for("embers").x * pow(ts, ex)) and float(_p(ecol, "top_m")) < 1.5, "the torch's burnt end sends up a wisp %.2f m tall, %.2f solid" % [float(_p(ecol, "top_m")), float(_p(ecol, "density"))])
	ok(lean.length() > 0.05 and lean.normalized().dot(-walk.normalized()) > 0.99, "walking, the wisp trails behind the torch (%.0f°)" % rad_to_deg(atan(lean.length())))
	Campfire.night = 1.0
	Torch.smoke_flame(lamp, up)
	ok(float(_p(lcol, "fire_lit_m")) < float((Smoke.H.get("night", {}) as Dictionary).get("fire_lit_m", 8.0)) * 0.5, "at night the lamp lights %.2f m of its thread" % float(_p(lcol, "fire_lit_m")))
	Campfire.night = 0.0
	lamp.queue_free()
	ember.queue_free()


func _end() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

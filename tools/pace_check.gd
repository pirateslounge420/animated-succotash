extends "res://tools/tech_check.gd"
## Walking pace on slopes (design 3 Oct §CR.5; data/world_scale.json pace):
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/pace_check.gd
## Asserts:
##  - PlanetPlayer.slope_pace follows Tobler's hiking function, scaled to
##    the flat walk: 54% of the flat speed at 10°, 28% at 20°, 13% at 30°
##    (the design's table), 1 on the flat, no downhill boost;
##  - an 885 m summit by a 20° route takes about 36 real minutes (6 game
##    hours) at the ambient walk, and a 500 m one about 3.4 game hours;
##  - in play, on the real ground near the opening camp: walking up a slope
##    the player goes at the flat walk times the pace for the grade ahead,
##    and sprinting likewise; on the way down no faster than the flat walk;
##  - ground steeper than walk_max_deg (45°) can't be walked up (the
##    floor's limit in the ambient profile).
## Also prints the mean pace over random walks on ordinary land (the
## walking-scale swells count too).


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	WorldSave.read_only = true
	var ws: Dictionary = Tuning.table("world_scale")
	var walk := PlanetPlayer.WALK_SPEED
	# --- The function ---------------------------------------------------
	var want := {10.0: 0.54, 20.0: 0.28, 30.0: 0.13}
	for deg in want:
		var f := PlanetPlayer.slope_pace(tan(deg_to_rad(deg)))
		ok(absf(f - want[deg]) < 0.01, "%.0f° up: %.1f%% of the flat speed (the design's %.0f%%)" % [deg, f * 100.0, want[deg] * 100.0])
	ok(is_equal_approx(PlanetPlayer.slope_pace(0.0), 1.0), "the flat: 100%")
	ok(PlanetPlayer.slope_pace(-0.05) <= 1.0 and PlanetPlayer.slope_pace(-0.3) < 1.0, "downhill: no boost (%.2f at -3°, %.2f at -17°)" % [PlanetPlayer.slope_pace(-0.05), PlanetPlayer.slope_pace(-0.3)])
	var day_real_min := DayCycle.day_length_min()
	for c in [[885.0, 20.0, 36.0, 6.0], [500.0, 20.0, 20.3, 3.4]]:
		var route: float = c[0] / sin(deg_to_rad(c[1]))
		var mins: float = route / (walk * PlanetPlayer.slope_pace(tan(deg_to_rad(c[1])))) / 60.0
		var game_h: float = mins / day_real_min * 24.0
		ok(absf(mins - c[2]) < 1.5 and absf(game_h - c[3]) < 0.3, "%.0f m by a %.0f° route: %.1f km, %.1f real min, %.1f game h (want about %.0f min, %.1f h)" % [c[0], c[1], route / 1000.0, mins, game_h, c[2], c[3]])
	print("[pace] walk %.1f m/s, sprint %.1f m/s; the flat walk the design assumed: %.1f m/s" % [walk, PlanetPlayer.SPRINT_SPEED, float((ws.get("pace", {}) as Dictionary).get("flat_walk_mps", 4.3))])
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(30)
	ok(absf(rad_to_deg(player.floor_max_angle) - float((ws.get("mountains", {}) as Dictionary).get("walk_max_deg", 45.0))) < 0.01,
		"ground steeper than %.0f° can't be walked up (the floor's limit: %.1f°)" % [float((ws.get("mountains", {}) as Dictionary).get("walk_max_deg", 45.0)), rad_to_deg(player.floor_max_angle)])
	_mean_pace()
	# --- In play, up a real slope ------------------------------------------
	var spot := _slope_near(player.surface_dir)
	if spot.is_empty():
		ok(false, "a slope of 8-20° within 4 km of the camp")
		_done()
		return
	print("[pace] a slope near the camp: %.1f° along %.0f m" % [rad_to_deg(atan(float(spot.s))), float(spot.len)])
	await goto(spot.dir)
	player.spawn_at(spot.dir, spot.up_to)
	await settle(spot.dir)
	for sprint in [false, true]:
		var r := await _walk(sprint, 1)
		ok(r.n > 0 and absf(float(r.speed) - float(r.want)) <= float(r.want) * 0.12,
			"%s uphill (grade %.1f°): %.2f m/s along the ground, the pace says %.2f m/s (%.0f%% of %.1f)" % ["sprinting" if sprint else "walking", rad_to_deg(atan(float(r.s))), float(r.speed), float(r.want), 100.0 * float(r.pace), PlanetPlayer.SPRINT_SPEED if sprint else walk])
		ok(float(r.speed) < (PlanetPlayer.SPRINT_SPEED if sprint else walk) * 0.9 and (not sprint or bool(r.sprinted)), "%s uphill is slower than on the flat" % ("sprinting" if sprint else "walking"))
		await settle(spot.dir)
	var down := await _walk(false, -1)
	ok(down.n > 0 and float(down.speed) <= walk * 1.02, "walking downhill (grade %.1f°): %.2f m/s, no faster than the flat walk (%.1f)" % [rad_to_deg(atan(float(down.s))), float(down.speed), walk])
	_done()


func _done() -> void:
	await release_all()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Walk (or sprint) uphill (way 1) or downhill (-1) for 3 s from where you
## stand: the mean speed along the ground after the first half second, and
## what the pace says for the grades you crossed.
func _walk(sprint: bool, way: int) -> Dictionary:
	var up_dir: Vector3 = player.surface_dir
	if way < 0:
		player.set_view(0.0, PI)
	else:
		player.set_view(0.0, 0.0)
	await frames(2)
	if sprint:
		await press("sprint")
	await press("move_forward")
	var dist := 0.0
	var want := 0.0
	var pace := 0.0
	var s := 0.0
	var n := 0
	var sprinted := false
	var last: Vector3 = player.global_position
	for i in 180:
		await frames(1)
		var here: Vector3 = player.global_position
		sprinted = sprinted or player.sprinting
		if i >= 30 and player.is_on_floor():
			var step := (here - last)
			dist += (step - player.up * step.dot(player.up)).length()
			var base := PlanetPlayer.SPRINT_SPEED if sprint else PlanetPlayer.WALK_SPEED
			want += base * player.pace_now * player.burden_speed() / 60.0
			pace += player.pace_now
			s += player.slope_ahead(-player.global_basis.z)
			n += 1
		last = here
	await release("move_forward")
	await release("sprint")
	await frames(10)
	var t := n / 60.0
	if sprint and not sprinted:
		print("[pace] (the sprint key didn't start a sprint)")
	return {"sprinted": sprinted, "n": n, "speed": dist / maxf(t, 1e-3), "want": want / maxf(t, 1e-3), "pace": pace / maxf(n, 1), "s": s / maxf(n, 1)}


## A spot near `d` where the ground climbs steadily (8-20°) for 20 m: its
## direction, the grade, and a point uphill to face.
func _slope_near(d: Vector3) -> Dictionary:
	var t: TerrainField = world.planet.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var best := {}
	for i in 4000:
		var p := CreatureSpawner._offset(d, rng.randf() * TAU, rng.randf_range(30.0, 4000.0))
		if t.elevation(p, true) < 2.0:
			continue
		for k in 8:
			var a := k * TAU / 8.0
			var q := CreatureSpawner._offset(p, a, 20.0)
			var s := (t.elevation(q, true) - t.elevation(p, true)) / 20.0
			if s < tan(deg_to_rad(8.0)) or s > tan(deg_to_rad(20.0)):
				continue
			# Steady: the halfway point on the line.
			var m := CreatureSpawner._offset(p, a, 10.0)
			var sm := (t.elevation(m, true) - t.elevation(p, true)) / 10.0
			if absf(sm - s) > 0.05:
				continue
			if best.is_empty() or absf(s - 0.25) < absf(float(best.s) - 0.25):
				best = {"dir": p, "up_to": CreatureSpawner._offset(p, a, 200.0), "s": s, "len": 20.0}
		if not best.is_empty() and absf(float(best.s) - 0.25) < 0.03:
			break
	return best


## The mean pace over straight random walks on land near the camp (both
## ways along each line), on the walking ground: what the swells and hills
## of ordinary land cost.
func _mean_pace() -> void:
	var t: TerrainField = world.planet.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sum := 0.0
	var n := 0
	var slowest := 1.0
	for w in 60:
		var p := CreatureSpawner._offset(player.surface_dir, rng.randf() * TAU, rng.randf_range(0.0, 20000.0))
		var a := rng.randf() * TAU
		var h0 := t.elevation(p, true)
		for k in 200:
			var q := CreatureSpawner._offset(p, a, 2.0)
			var h1 := t.elevation(q, true)
			if h0 > 1.0 and h1 > 1.0:
				var s := (h1 - h0) / 2.0
				var f := (PlanetPlayer.slope_pace(s) + PlanetPlayer.slope_pace(-s)) * 0.5
				sum += f
				n += 1
			p = q
			h0 = h1
	print("[pace] ordinary land within 20 km of the camp: on average %.0f%% of the flat speed (both ways along %d two-metre steps)" % [100.0 * sum / maxf(n, 1), n])

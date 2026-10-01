extends SceneTree
## The wanderer's body (PlayerBody): its cloak's numbers, headless, and
## (with a display) pictures of it in the game.
##
## Numbers (no window):
##   ~/bin/godot --headless --path . -s tools/wanderer_check.gd
## prints the meshes' build time and triangles, then drives a body on its
## own (a stand-in for the player: a parent turned to its up) through
## standing still, a sprint, wind from the side, a crouch and a quick turn,
## and prints the cloth's cost per step and where the hem goes: how far
## it trails behind and lifts at a sprint, how far downwind in wind, how
## high it sits over the ground crouched (0 = on the ground).
##
## Pictures (MODE=shots): starts the game and saves, to $OUT_DIR (default
## /tmp/shots): wanderer_front, _side, _back (day), _sprint, _crouch,
## _wind, _hood (straight into the hood, close), _fp_forward and _fp_down
## (first person). Prints the brightest pixel inside the hood's opening.
##   MODE=shots xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 960x540 -s tools/wanderer_check.gd

var out_dir := "/tmp/shots/"


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR").trim_suffix("/") + "/"
	if OS.get_environment("MODE") == "shots":
		_shots.call_deferred()
	else:
		_numbers.call_deferred()


# --- Numbers ------------------------------------------------------------------

var _rig: Node3D
var _body: PlayerBody


func _step(n: int, vel := Vector3.ZERO, wind := Vector3.ZERO, spin := 0.0) -> void:
	for i in n:
		if spin != 0.0:
			_rig.rotate_y(spin / 60.0)
		_body.set_velocity(_rig.global_basis * vel)
		_body.set_wind(wind)
		_body.set_motion(vel.length() / 8.8, 1.0 / 60.0)
		await physics_frame


func _report(label: String) -> void:
	var o := _body.hem_offset()
	var g := _body.hem_ground_gap()
	print("[wanderer] %-26s hem behind %+.3f m, up %+.3f m, side %+.3f m; hem over ground: lowest %.3f, mean %.3f m" % [label, o.z, o.y, o.x, g.x, g.y])


func _numbers() -> void:
	var t0 := Time.get_ticks_msec()
	_rig = Node3D.new()
	_rig.name = "Rig"
	get_root().add_child(_rig)
	_body = PlayerBody.new()
	_rig.add_child(_body)
	print("[wanderer] meshes built in %d ms (body ready in %d ms); %d triangles" % [PlayerBody.build_ms(), Time.get_ticks_msec() - t0, _body.triangles])
	await _step(180)
	_report("standing, settled:")
	var still := _body.hem_offset()
	var cost := PackedInt32Array()
	for i in 240:
		await _step(1, Vector3(0, 0, -8.8))
		cost.append(_body.sim_usec)
	_report("sprinting 8.8 m/s, 4 s:")
	var sprint := _body.hem_offset()
	await _step(60, Vector3(0, 0, -5.5))
	_report("walking 5.5 m/s:")
	await _step(180)
	_report("stopped, 3 s later:")
	await _step(240, Vector3.ZERO, Vector3(8.0, 0, 0))
	_report("wind 8 m/s from the left:")
	var wind := _body.hem_offset()
	await _step(120, Vector3.ZERO, Vector3(15.0, 0, 0))
	_report("wind 15 m/s from the left:")
	await _step(180)
	_body.set_crouch(1.0)
	await _step(150)
	_report("crouched:")
	var crouch := _body.hem_ground_gap()
	_body.set_crouch(0.0)
	await _step(150)
	_report("standing again:")
	await _step(45, Vector3.ZERO, Vector3.ZERO, PI / 0.75)
	_report("turning half round in 0.75 s:")
	await _step(120)
	# Arms posed (drawing the bow): the elbows straighten, so each hand is
	# on the arm's line, ARM_M from the shoulder (the spear and the climb
	# rely on it).
	for arm in _body.arms:
		arm.rotation.x = 1.35
	await _step(2)
	var off := 0.0
	for s in 2:
		var glove: Node3D = _body.arms[s].get_node("Elbow" + ("L" if s == 0 else "R"))
		var hand := glove.global_transform * Vector3(0, -0.29, -0.006)
		off = maxf(off, hand.distance_to(_body.arms[s].global_transform * Vector3(0, -PlayerBody.ARM_M, 0)))
	print("[wanderer] arms raised to aim: hand %.3f m from the arm's line at ARM_M" % off)
	for arm in _body.arms:
		arm.rotation.x = 0.06
	# The death pose (PlanetPlayer._dead_step): the body tips forward onto
	# the ground; the cloak falls onto it and nothing goes under the ground.
	for i in 90:
		_body.rotation.x = lerpf(_body.rotation.x, -PI * 0.5, 3.0 / 60.0)
		await _step(1)
	await _step(90)
	var lowest := INF
	var pts := _body.cloak_points()
	for i in range(PlayerBody.PINNED * PlayerBody.COLS, pts.size()):
		lowest = minf(lowest, (_body.transform * pts[i]).y)
	print("[wanderer] dead (body tipped %.0f deg): lowest free cloak point %.3f m over the ground" % [rad_to_deg(-_body.rotation.x), lowest])
	_body.rotation = Vector3.ZERO
	await _step(60)
	# Cost: every step of the sprint, sorted.
	var sorted := Array(cost)
	sorted.sort()
	var sum := 0
	for c in sorted:
		sum += c
	print("[wanderer] cloth step: mean %.0f us, median %d us, 95th percentile %d us, max %d us (%d steps)" % [
		float(sum) / sorted.size(), sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted[-1], sorted.size()])
	print("[wanderer] SUMMARY trail at sprint %.3f m (still %.3f), downwind at 8 m/s %.3f m (lift %+.3f), crouched hem lowest %.3f m mean %.3f m" % [
		sprint.z, still.z, wind.x, wind.y, crouch.x, crouch.y])
	quit()


# --- Pictures -----------------------------------------------------------------

var main
var world
var cam: Camera3D
var player: PlanetPlayer


func frames(n: int) -> void:
	for i in n:
		_hold_noon()
		await process_frame


func _hold_noon() -> void:
	world.days = Astro.days_at_solar_hour(world.days, 11.0, CubeSphere.longitude(player.surface_dir), CubeSphere.latitude(player.surface_dir))


func shot(sname: String, n := 3) -> Image:
	await frames(n)
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir + sname + ".png")
	print("saved ", sname)
	return img


## Look at the player from `dist` m away, `yaw` round from its front
## (0 = in front, PI/2 its right side, PI behind), at height `h`,
## looking at `target_h` on the body.
func orbit(yaw: float, dist: float, h: float, target_h: float, fov := 40.0) -> void:
	var b := player.global_basis
	var fwd := -b.z
	var dir := fwd.rotated(b.y, -yaw)
	var target := player.global_position + b.y * target_h
	var from := player.global_position + dir * dist + b.y * h
	cam.fov = fov
	cam.global_transform = Transform3D(Basis.looking_at((target - from).normalized(), b.y), from)
	cam.current = true


## Feed the body as if the player moved at `vel` (its own space) in
## `wind` (scene), from now on, and wait `n` physics steps. The player
## itself stands still (its physics is off: no input).
func _drive(n: int, vel: Vector3, wind := Vector3.ZERO) -> void:
	_feed_v = vel
	_feed_w = wind
	for i in n:
		await physics_frame


var _feed_v := Vector3.ZERO
var _feed_w := Vector3.ZERO


func _feed() -> void:
	var pb := player._body as PlayerBody
	pb.set_velocity(player.global_basis * _feed_v)
	pb.set_wind(_feed_w)
	pb.set_motion(_feed_v.length() / 8.8, 1.0 / 60.0)


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	world.pin(42, 0)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	main._weather_timer = 1e9
	main._local_weather = {"wind": Vector3.ZERO, "rain_mm_h": 0.0, "snow": false, "temp_c": 20.0, "storm": 0.0, "clear": 1.0, "cloud": 0.2}
	main.hud.visible = false
	player = main.player
	cam = Camera3D.new()
	cam.far = 30000
	cam.near = 0.05
	get_root().add_child(cam)
	player.set_physics_process(false)
	physics_frame.connect(_feed)
	var pb := player._body as PlayerBody
	await _drive(90, Vector3.ZERO)
	orbit(0.35, 3.2, 1.1, 0.85)
	await shot("wanderer_front")
	orbit(PI * 0.5, 3.2, 1.0, 0.85)
	await shot("wanderer_side")
	orbit(PI - 0.3, 3.2, 1.2, 0.85)
	await shot("wanderer_back")
	# Straight into the hood from 0.6 m, level with it.
	var b := player.global_basis
	var hood: Vector3 = pb.head.global_transform * Vector3(0, 0.12, -0.1)
	cam.fov = 40.0
	cam.global_transform = Transform3D(Basis.looking_at(-(-b.z), b.y), hood - b.z * 0.6)
	var img := await shot("wanderer_hood")
	var w := img.get_width()
	var h := img.get_height()
	var brightest := 0.0
	for y in range(int(h * 0.44), int(h * 0.56)):
		for x in range(int(w * 0.46), int(w * 0.54)):
			brightest = maxf(brightest, img.get_pixel(x, y).get_luminance())
	print("[wanderer] brightest pixel straight into the hood (central 8%% x 12%%): %.3f (0-1)" % brightest)
	await _drive(150, Vector3(0, 0, -8.8))
	orbit(PI * 0.5, 3.4, 1.0, 0.8)
	await shot("wanderer_sprint")
	await _drive(120, Vector3.ZERO)
	pb.set_crouch(1.0)
	await _drive(120, Vector3.ZERO)
	orbit(0.6, 3.0, 1.0, 0.5)
	await shot("wanderer_crouch")
	print("[wanderer] crouched hem over ground: lowest %.3f m, mean %.3f m" % [pb.hem_ground_gap().x, pb.hem_ground_gap().y])
	pb.set_crouch(0.0)
	await _drive(120, Vector3.ZERO)
	var wind := player.global_basis.x * -9.0
	await _drive(150, Vector3.ZERO, wind)
	orbit(0.25, 3.4, 1.1, 0.85)
	await shot("wanderer_wind")
	await _drive(60, Vector3.ZERO)
	# First person: the player's own camera at its eyes.
	player.first_person = true
	player._apply_view()
	cam.current = false
	player.camera().current = true
	player.set_view(0.0, 0.0)
	player._spring.rotation = Vector3(0.0, 0.0, 0.0)
	await shot("wanderer_fp_forward")
	player._spring.rotation = Vector3(-1.5, 0.0, 0.0)
	await shot("wanderer_fp_down")
	print("[wanderer] blob shadow: visible %s, layers %d, %.2f m under the eyes" % [player._blob.visible, player._blob.layers, player.camera().global_position.distance_to(player._blob.global_position)])
	player._spring.rotation = Vector3(-1.0, 0.0, 0.0)
	await shot("wanderer_fp_low")
	quit()

extends SceneTree
## The sun's flare (design 3 Oct §DB, look.json lens_flare, LensFlare),
## headless:
##   godot --headless --path . --script tools/flare_check.gd
## A camera on a flat test stage, the sun 30° up in front of it:
##  - nothing between: the flare's alpha is up after fade_s (0.15 s);
##  - a wall put between: back to 0 within fade_s;
##  - §CX's cover 0.9: 0; a cloud's shadow over you: 0;
##  - the sun below the horizon: 0; underground: 0;
##  - the sun just outside the frame: 0;
##  - each ring sits on the line from the sun through the frame's centre,
##    at its `at`, within a pixel;
##  - the core is cool by day and takes the sunset colour at 5° up.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	get_root().add_child(stage)
	var cam := Camera3D.new()
	cam.fov = 78.0
	stage.add_child(cam)
	cam.current = true
	cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
	var flare := LensFlare.new()
	get_root().add_child(flare)
	await process_frame
	var fade := float(LensFlare.F.get("fade_s", 0.15))
	var dt := 1.0 / 60.0
	var sun := Vector3(0.0, sin(deg_to_rad(30.0)), -cos(deg_to_rad(30.0))).normalized()
	var run := func(s: Vector3, elev: float, cover: float, cloud: float, under: bool, secs: float) -> float:
		for i in int(ceil(secs / dt)):
			flare.step(cam, s, elev, cover, cloud, under, dt)
		return flare.alpha
	var a: float = run.call(sun, 30.0, 0.1, 0.0, false, fade + dt)
	ok(a > 0.9, "the sun 30° up ahead, nothing between: alpha %.2f after %.2f s (%s)" % [a, fade, flare.why])
	# The rings on the sun-to-centre line.
	var line := flare.center_px - flare.sun_px
	var worst := 0.0
	var rings: Array = LensFlare.F.get("rings", [])
	for i in rings.size():
		var want: Vector2 = flare.sun_px + line * float((rings[i] as Dictionary).get("at", 1.0))
		worst = maxf(worst, (flare.ring_px[i] as Vector2).distance_to(want))
	ok(rings.size() >= 1 and worst <= 1.0, "the %d rings sit on the sun-to-centre line at their places (worst %.2f px off)" % [rings.size(), worst])
	ok(flare.core_color.r <= flare.core_color.b + 0.01, "by day the core is cool (%s)" % flare.core_color.to_html(false))
	# A wall between.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 1)
	shape.shape = box
	wall.add_child(shape)
	stage.add_child(wall)
	wall.global_position = Vector3(0, 6, -8)
	await physics_frame
	await physics_frame
	a = run.call(sun, 30.0, 0.1, 0.0, false, fade + dt)
	ok(a <= 0.0 and flare.why == "blocked", "a wall between: alpha %.2f within %.2f s (%s)" % [a, fade, flare.why])
	wall.queue_free()
	await physics_frame
	await physics_frame
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	a = run.call(sun, 30.0, 0.9, 0.0, false, fade + dt)
	ok(a <= 0.0, "§CX's cover 0.9: alpha %.2f (%s)" % [a, flare.why])
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	a = run.call(sun, 30.0, 0.5, 1.0, false, fade + dt)
	ok(a <= 0.0, "a cloud's shadow over you: alpha %.2f (%s)" % [a, flare.why])
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	var thin: float = run.call(sun, 30.0, 0.6, 0.0, false, 1.0)
	ok(thin > 0.0 and thin < 0.9, "thin cloud (cover 0.6) dims it to %.2f" % thin)
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	var low := Vector3(0.0, sin(deg_to_rad(-3.0)), -cos(deg_to_rad(-3.0))).normalized()
	a = run.call(low, -3.0, 0.1, 0.0, false, fade + dt)
	ok(a <= 0.0, "the sun below the horizon: alpha %.2f (%s)" % [a, flare.why])
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	a = run.call(sun, 30.0, 0.1, 0.0, true, fade + dt)
	ok(a <= 0.0, "underground: alpha %.2f (%s)" % [a, flare.why])
	# Just outside the frame: past half the horizontal field of view.
	var size := cam.get_viewport().get_visible_rect().size
	var hfov := rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov * 0.5)) * size.x / size.y))
	var off := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(-(hfov * 0.5 + 3.0)))
	off = (off * cos(deg_to_rad(10.0)) + Vector3.UP * sin(deg_to_rad(10.0))).normalized()
	run.call(sun, 30.0, 0.1, 0.0, false, 1.0)
	a = run.call(off, 10.0, 0.1, 0.0, false, fade + dt)
	ok(a <= 0.0 and flare.why == "off_frame", "the sun 3° outside the frame's edge: alpha %.2f (%s)" % [a, flare.why])
	var dusk := Vector3(0.0, sin(deg_to_rad(5.0)), -cos(deg_to_rad(5.0))).normalized()
	run.call(dusk, 5.0, 0.1, 0.0, false, 1.0)
	var sunset := Color.from_string(str((Tuning.section("look", "retro").get("colors", {}) as Dictionary).get("sunset_sun", "#FBF486")), Color.WHITE)
	ok(flare.core_color.is_equal_approx(sunset), "at 5° up the core takes the sunset sun's colour (%s)" % flare.core_color.to_html(false))
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

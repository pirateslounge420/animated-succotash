extends SceneTree
## Design 5 Oct §EE.1: a relit village goes amber, the wild stays blue.
##   STAMP=1 SEED=42 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method forward_plus --resolution 1280x720 -s tools/village_warmth_check.gd
## Needs a display (Godot's --headless has no renderer); it prints numbers
## only, no images. At 01:00 on the dev stamp, a stand-in village of 12
## hearths is registered 20-40 m ahead of the eye (VillageWarmth), and its
## lit fraction is stepped 0, 0.25, 0.5, 0.75, 1. Each step's frame is
## measured as tools/look/measure_look.py does: the warm share (saturated
## pixels, HSV saturation over 0.35, hue 330-60) and the blue share (195-265),
## the mean of two frames.
## PASS when: the dead village (0) is the frame with no village at all
## (within the frame's own flicker, measured as two no-village frames; and
## exactly: nothing reaches the shaders); the warm share never falls as the
## fraction rises and is clearly up at 1; and 1 km away, with every hearth
## lit, nothing reaches the grade or the ground there and the frame is
## today's within its own drift (no village, lit village, no village).

var main
var world
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var player: PlanetPlayer = main.player
	var d0: Vector3 = player.surface_dir
	_set_hour(d0, 1.0)
	for i in 90:
		await process_frame
	# Today's frame twice: how much it moves on its own (the camp's fire
	# flickers, smoke drifts) sets the tolerance.
	var b1 := await _measure()
	var b2 := await _measure()
	var base := (b1 + b2) * 0.5
	var noise := (b1 - b2).abs()
	print("[warmth] no village: warm %.4f blue %.4f (twice: %.4f / %.4f; grade warmth %.2f)" % [base.x, base.y, b1.x, b2.x, VillageWarmth.grade_warmth])
	# The stand-in village: 12 hearths in a fan ahead of the eye.
	var cam: Camera3D = get_root().get_viewport().get_camera_3d()
	var fwd := -cam.global_basis.z
	fwd = (fwd - d0 * fwd.dot(d0)).normalized()
	var side := fwd.cross(d0).normalized()
	var mid := (d0 + fwd * 30.0 / PlanetConst.RADIUS_M).normalized()
	var hearths: Array = []
	for i in 12:
		var along := 18.0 + 22.0 * float(i % 4) / 3.0
		var across := (float(i / 4) - 1.0) * 9.0 + (float(i % 2) - 0.5) * 2.0
		var hd := (d0 + (fwd * along + side * across) / PlanetConst.RADIUS_M).normalized()
		hearths.append([hd, PlanetConst.RADIUS_M + main.chunks.ground_height(hd)])
	VillageWarmth.register("test", mid, PlanetConst.RADIUS_M + main.chunks.ground_height(mid), 45.0, hearths)
	var shares := []
	var dead_exact := true
	for f: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		VillageWarmth.set_lit("test", f)
		var s := await _measure()
		if f == 0.0:
			dead_exact = VillageWarmth.grade_warmth == 0.0
			for h in hearths:
				if VillageWarmth.warm_at(world, world.to_scene(h[0], float(h[1]))) != 0.0:
					dead_exact = false
		shares.append(s)
		print("[warmth] lit %.2f: warm %.4f blue %.4f (grade warmth %.2f, lit fraction %.2f)" % [f, s.x, s.y, VillageWarmth.grade_warmth, VillageWarmth.lit_fraction("test")])
	var tol := Vector2(0.004, 0.01) + noise * 2.0
	ok(absf(shares[0].x - base.x) <= tol.x and absf(shares[0].y - base.y) <= tol.y, "a dead village is the frame with no village, within the frame's own flicker (warm %.4f vs %.4f, blue %.4f vs %.4f; tolerance %.4f / %.4f)" % [shares[0].x, base.x, shares[0].y, base.y, tol.x, tol.y])
	ok(dead_exact, "and exactly: dead, nothing reaches the shaders (grade warmth 0, surface ease 0 at the hearths)")
	var rising := true
	for i in range(1, shares.size()):
		if shares[i].x < shares[i - 1].x - 0.002:
			rising = false
	ok(rising, "the warm share rises with the lit fraction (%s)" % str(shares.map(func(v): return snappedf(v.x, 0.0001))))
	ok(shares[4].x >= shares[0].x + 0.05, "a fully lit village is clearly warm (%.4f against %.4f dead)" % [shares[4].x, shares[0].x])
	ok(shares[4].y < shares[0].y, "and less blue (%.4f against %.4f)" % [shares[4].y, shares[0].y])
	# 1 km away: every hearth still lit, the frame as today's.
	var far_d := (d0 - fwd * 1000.0 / PlanetConst.RADIUS_M).normalized()
	VillageWarmth.forget("test")
	player.spawn_at(far_d, (far_d - fwd * 30.0 / PlanetConst.RADIUS_M).normalized())
	for i in 300:
		await process_frame
	_set_hour(far_d, 1.0)
	for i in 20:
		await process_frame
	# No village, the lit village, no village again.
	var n1 := await _measure()
	VillageWarmth.register("test", mid, PlanetConst.RADIUS_M + main.chunks.ground_height(mid), 45.0, hearths)
	VillageWarmth.set_lit("test", 1.0)
	var far_lit := await _measure()
	var gw := VillageWarmth.grade_warmth
	var here_ease := VillageWarmth.warm_at(world, player.global_position)
	VillageWarmth.forget("test")
	var n2 := await _measure()
	var far_none := (n1 + n2) * 0.5
	var ftol := Vector2(0.004, 0.01) + (n1 - n2).abs() * 2.0
	print("[warmth] 1 km off: lit village %.4f / %.4f, no village %.4f / %.4f then %.4f / %.4f (grade warmth %.2f, surface ease here %.2f)" % [far_lit.x, far_lit.y, n1.x, n1.y, n2.x, n2.y, gw, here_ease])
	ok(gw == 0.0 and here_ease == 0.0, "1 km off, nothing of the lit village reaches the grade or the ground here (exact)")
	ok(absf(far_lit.x - far_none.x) <= ftol.x and absf(far_lit.y - far_none.y) <= ftol.y, "1 km off, the wild keeps today's look within its own drift (warm %.4f vs %.4f, blue %.4f vs %.4f; tolerance %.4f / %.4f)" % [far_lit.x, far_none.x, far_lit.y, far_none.y, ftol.x, ftol.y])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## Put the clock at local hour `h` where `d` is, on the game's own clock.
func _set_hour(d: Vector3, h: float) -> void:
	for k in 3:
		var now: float = world.local_clock(d).y
		world.days += fposmod(h - now, 24.0) / 24.0


## The mean warm and blue shares of two frames (measure_look.py's).
func _measure() -> Vector2:
	var acc := Vector2.ZERO
	for k in 2:
		for i in 6:
			await process_frame
		var img := get_root().get_viewport().get_texture().get_image()
		acc += _shares(img)
	return acc / 2.0


static func _shares(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var warm := 0
	var blue := 0
	var n := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := img.get_pixel(x, y)
			n += 1
			if c.s <= 0.35:
				continue
			var hue := c.h * 360.0
			if hue <= 60.0 or hue >= 330.0:
				warm += 1
			elif hue >= 195.0 and hue <= 265.0:
				blue += 1
	return Vector2(float(warm) / n, float(blue) / n)

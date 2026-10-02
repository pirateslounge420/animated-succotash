extends SceneTree
## The fixed dev viewpoint: the same frame every time, for judging the
## look between changes (a harness frame, design §CG: label it so, with the
## tool, seed, camera, the cloud GPU and the import cache present or
## hidden). Seed 42 (SEED to change it) on the full planet, the first
## camp (spawn 0), you waking on the fire's north side (the folk across
## it; Encampment.fixed_side) and the random numbers seeded. The camera
## stands 9 m south of the fire, 2.4 m up, looking north across it at you
## (third person, the wanderer visible), tipped 7 degrees down. The
## weather is held clear and still.
## Saves one frame per requested local solar hour.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/dev_view.gd
##
## HOURS: comma-separated local solar hours (default "12,0": noon and
## midnight). YEAR_DAY: the day of the year (0 = northern spring
## equinox; default tomorrow). DEBUG=1: the F3 overlay on the frame.
## HUD=1: the whole HUD (H's full HUD: every readout, pinned or not);
## SPEED (m/s) and METER (0-1) feed its readouts;
## SETTINGS=1 opens the settings panel; LOOK_NAME="binomial|common name"
## puts a name under the crosshair. OUT_DIR (default /tmp/shots), TAG: file name prefix
## (default "devview"): writes <TAG>_<hh>h.png, the internal frame
## (design §Y: 854x480 by default). SCREEN=1 also writes
## <TAG>_<hh>h_window.png, the window as it shows on the screen (the
## frame upscaled, nearest-neighbour); FULLSCREEN=1 makes the window
## fullscreen first; FP=1 looks through your own eyes (first person,
## the crosshair up) instead of the fixed camera; VISTA=1 looks level
## from 40 m up toward the longest view (the distance haze) (under xvfb there's no window manager: use
## --resolution 1920x1080 --position 0,0 instead). INTEGER=0: the
## fractional upscale for this run. Prints the sun's
## elevation, the light's elevation and the mean brightness of each frame.
## SPAWN=n: the n-th camp instead of the first (other ground to judge).
## VISTA_M=m with VISTA=1: that far up instead of 40 m (over the canopy,
## to see the far trees; PITCH=-0.2 tips it down).
## SUNWARD=1 with VISTA=1: face the sun's bearing instead (the sunset sky).
## CLOUD=x: the held weather's cloud cover (default 0.15).

var out_dir := "/tmp/shots"


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	if OS.get_environment("FULLSCREEN") == "1":
		get_root().mode = Window.MODE_FULLSCREEN
	var integer_env := OS.get_environment("INTEGER")
	var world = get_root().get_node("World")
	# The dev frame's pins, set here (design 1 Oct §CB): SEED / SPAWN env,
	# else seed 42 and the first camp.
	world.pin(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42, int(OS.get_environment("SPAWN")) if OS.get_environment("SPAWN") != "" else 0)
	seed(42)
	Encampment.fixed_side = 0.0
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	# INTEGER=0: fractional upscale for this run (the saved setting untouched).
	if integer_env == "0":
		get_root().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	var clear := {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": float(OS.get_environment("CLOUD")) if OS.get_environment("CLOUD") != "" else 0.15}
	main._weather_timer = 1e9
	main._local_weather = clear
	main._weather_eased = clear.duplicate()
	# DEBUG=1 shows the F3 overlay (clock, phase, daylight at this
	# latitude) and nothing else of the HUD.
	if OS.get_environment("DEBUG") == "1":
		for c in main.hud.get_children():
			if c is CanvasItem:
				c.visible = false
		main.hud.toggle_debug()
		main.hud._debug.add_theme_font_size_override("font_size", 13)
		main.hud._debug.add_theme_constant_override("outline_size", 5)
	elif OS.get_environment("HUD") != "1":
		main.hud.visible = false
	else:
		# The whole HUD: H's full HUD, every readout pinned or not.
		main.hud.toggle()
	var player: PlanetPlayer = main.player
	# AT=x,y,z: stand at that surface direction instead of the camp (a
	# waterfall, a road), looking north.
	if OS.get_environment("AT") != "":
		var at := OS.get_environment("AT").split(",")
		var d := Vector3(float(at[0]), float(at[1]), float(at[2])).normalized()
		var off: Vector3 = main.world.to_scene(d, PlanetConst.RADIUS_M + main.world.surface_elevation(d))
		main.world.rebase(off)
		player.global_position -= off
		main.chunks.load_blocking(d)
		var look := CreatureSpawner._offset(d, float(OS.get_environment("AT_YAW")) if OS.get_environment("AT_YAW") != "" else 0.0, 30.0)
		if OS.get_environment("LOOK_AT") != "":
			var la := OS.get_environment("LOOK_AT").split(",")
			look = Vector3(float(la[0]), float(la[1]), float(la[2])).normalized()
		player.spawn_at(d, look)
		for i in 30:
			await process_frame
	# WAIT_DETAIL=1: hold the frame until the camp's chunk draws its trees
	# at the near level (leaf cards, not the far pictures), as play does
	# within a few seconds on a GPU; the software renderer takes longer.
	if OS.get_environment("WAIT_DETAIL") == "1":
		var ck: Vector3i = TerrainChunk.key_at(main.camp.site)
		for i in 4000:
			var c: TerrainChunk = main.chunks.chunks.get(ck, null)
			if c != null and c.plant_lod(c) != PlantMeshes.LOD_FAR:
				print("[dev_view] detail in after %d frames" % i)
				break
			await process_frame
	player.set_physics_process(false)
	# HUD=1 keeps the HUD (speedometer, clock); SPEED (m/s) and METER (0-1)
	# light the readouts up (the player's physics is held still).
	if OS.get_environment("SPEED") != "":
		player.velocity = -player.global_basis.z * float(OS.get_environment("SPEED"))
	if OS.get_environment("METER") != "":
		player.meter.value = float(OS.get_environment("METER"))
	# SETTINGS=1 (with HUD=1): the settings panel open over the frame.
	# LOOK_NAME: a name under the crosshair ("binomial|common name").
	if OS.get_environment("SETTINGS") == "1":
		main.settings_panel.open()
	if OS.get_environment("LOOK_NAME") != "":
		player.look.set_process(false)
		player.look.text = OS.get_environment("LOOK_NAME").replace("|", "\n")
	# HEADLOOK: the wanderer's look, "yaw,pitch" in degrees from where it
	# faces (+ left, + up), to show the hood-first head-look.
	if OS.get_environment("HEADLOOK") != "":
		var hl := OS.get_environment("HEADLOOK").split(",")
		(player._body as PlayerBody).set_look(deg_to_rad(float(hl[0])), deg_to_rad(float(hl[1]) if hl.size() > 1 else 0.0))
	player.first_person = false
	player._apply_view()
	var pd: Vector3 = main.camp.site
	var n := CubeSphere.north(pd)
	var ground: float = main.chunks.ground_height(pd)
	var target: Vector3 = world.to_scene(pd, PlanetConst.RADIUS_M + ground + 1.0)
	var eye_d: Vector3 = (pd - n * 9.0 / PlanetConst.RADIUS_M).normalized()
	var eye: Vector3 = world.to_scene(eye_d, PlanetConst.RADIUS_M + main.chunks.ground_height(eye_d) + 2.4)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.1
	cam.far = 30000.0
	get_root().add_child(cam)
	var look := (target - eye).normalized()
	look = (look - pd * look.dot(pd)).normalized()
	look = (look * cos(deg_to_rad(7.0)) - pd * sin(deg_to_rad(7.0))).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(look, pd), eye)
	# CLOSE=1: a close-up of the wanderer from 3.5 m, same side.
	if OS.get_environment("CLOSE") == "1":
		var pp := player.global_position + player.global_basis.y * 1.2
		var from := pp + (eye - pp).normalized() * 3.5
		from += player.global_basis.y * (0.3 - (from - pp).dot(player.global_basis.y))
		cam.fov = 45.0
		cam.global_transform = Transform3D(Basis.looking_at((pp - from).normalized(), pd), from)
	# VISTA=1: from 40 m above the same spot, level, toward the lowest
	# horizon of 12 headings (the longest view): for the distance haze.
	if OS.get_environment("VISTA") == "1":
		var up_m := float(OS.get_environment("VISTA_M")) if OS.get_environment("VISTA_M") != "" else 40.0
		var hi: Vector3 = world.to_scene(pd, PlanetConst.RADIUS_M + ground + up_m)
		var best_h := n
		var best_e := INF
		for k in 12:
			var hh: Vector3 = n.rotated(pd, TAU * k / 12.0)
			var far_e: float = main.chunks.ground_height((pd + hh * 400.0 / PlanetConst.RADIUS_M).normalized())
			if far_e < best_e:
				best_e = far_e
				best_h = hh
		cam.fov = 70.0
		cam.global_transform = Transform3D(Basis.looking_at(best_h, pd), hi)
	cam.current = true
	# FP=1: your own eyes instead (first person, the crosshair showing).
	if OS.get_environment("FP") == "1":
		cam.current = false
		player.first_person = true
		player._apply_view()
		player.camera().current = true
	# PITCH=x without FP: the view camera tipped up by x (radians).
	if OS.get_environment("PITCH") != "" and OS.get_environment("FP") != "1":
		cam.rotate_object_local(Vector3.RIGHT, float(OS.get_environment("PITCH")))
	var hours := (OS.get_environment("HOURS") if OS.get_environment("HOURS") != "" else "12,0").split(",")
	var tag := OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "devview"
	var lon := CubeSphere.longitude(pd)
	var base: float = floor(world.days) + 1.0
	# YEAR_DAY: jump to that day of the year (0 = the northern spring
	# equinox) instead of tomorrow.
	if OS.get_environment("YEAR_DAY") != "":
		base += fposmod(float(OS.get_environment("YEAR_DAY")) - Astro.year_day(base), DayCycle.year_days())
	for h in hours:
		var hour := float(h)
		var days := Astro.days_at_solar_hour(base, hour, lon, CubeSphere.latitude(pd))
		for k in 20:
			world.days = days
			main.hud._readout_timer = 0.0
			# PITCH=x (radians, with FP=1): look up or down (1.5: nearly
			# straight up, the zenith); held every frame over the opening's.
			if OS.get_environment("PITCH") != "" and OS.get_environment("FP") == "1":
				player.set_view(float(OS.get_environment("PITCH")), 0.0)
			await process_frame
			# SUNWARD=1 (with VISTA): turn toward the sun's bearing, the view
			# tipped up 8 degrees: the sunset sky and the sun's disc.
			if OS.get_environment("SUNWARD") == "1" and OS.get_environment("VISTA") == "1":
				var sd: Vector3 = main.sky.sun_dir
				var flat := (sd - pd * sd.dot(pd)).normalized()
				cam.global_transform = Transform3D(Basis.looking_at(flat.rotated(flat.cross(pd).normalized(), deg_to_rad(8.0)), pd), cam.global_position)
		var img := get_root().get_texture().get_image()
		var path := out_dir.path_join("%s_%02dh.png" % [tag, int(hour)])
		img.save_png(path)
		if OS.get_environment("SCREEN") == "1":
			await process_frame
			var shot := DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
			if shot != null:
				var wp := DisplayServer.window_get_position()
				var ws := DisplayServer.window_get_size()
				var cut := shot.get_region(Rect2i(wp, ws).intersection(Rect2i(Vector2i.ZERO, shot.get_size())))
				cut.save_png(path.get_basename() + "_window.png")
				print("[devview] window %s at %s, internal %s, %.2fx %s" % [ws, wp, img.get_size(), Display.scale(), "integer" if get_root().content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER else "fractional"])
		var sum := 0.0
		var cnt := 0
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				sum += img.get_pixel(x, y).get_luminance()
				cnt += 1
		var sky: SkySystem = main.sky
		var light_el := rad_to_deg(Astro.elevation(sky.sun.global_basis.z, pd))
		print("[devview] sun shadows %s, bias %.2f, normal bias %.2f, splits %d, max %.0f m" % [sky.sun.shadow_enabled, sky.sun.shadow_bias, sky.sun.shadow_normal_bias, sky.sun.directional_shadow_mode, sky.sun.directional_shadow_max_distance])
		print("[devview] %05.2f h: sun %.1f deg, sun light %.1f deg, mean brightness %.3f -> %s" % [hour, sky.sun_elevation_deg, light_el, sum / cnt, path])
	quit()

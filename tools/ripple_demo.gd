extends SceneTree
## Ripples check (the water ripple system, RippleSim): boots the game on
## the dev postage-stamp planet (data/dev.json: seed 42, the first camp),
## finds wading water near the camp and plays a short sequence at night
## (local 23:00), seen through the player's own third-person camera:
##   0-4 s      the player wades along the shore: a ring from every step
##              and a continuous wake from his legs;
##   4-5 s      he draws and looses an arrow into the water: its ring;
##   5.8-8.8 s  he wades back through the rings (they overlap);
##   8-13 s     rain on the water: every drop rings it, while he wades on.
## Stills mode (the default) plays it again at dusk (18:20, no rain, 9 s)
## and briefly at noon, saves stills of the named moments, prints what the
## CPU readers (Ripples.height_at) estimate next to the simulated buffer
## after one splash, and the ripple system's CPU cost.
##
## Run from the project folder:
##   stills (quick: the 3D view is drawn only for the stills):
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 --fixed-fps 30 -s tools/ripple_demo.gd
##   recording (Godot's movie maker; the night sequence only, 13 s; the
##   loading frames come first, plain grey with the 3D view off, and the
##   sequence starts at the frame printed as "[ripples] sequence starts at
##   movie frame N": trim there):
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 --write-movie /tmp/shots/ripples_night.avi --fixed-fps 30 -s tools/ripple_demo.gd
##   then, with N from that line (ffmpeg):
##     ffmpeg -i /tmp/shots/ripples_night.avi -vf "select=gte(n\,N),setpts=PTS-STARTPTS" -an -c:v libx264 -pix_fmt yuv420p -crf 18 /tmp/shots/ripples_night.mp4
##   the compatibility renderer: --rendering-method gl_compatibility
##   frame cost, ripples on vs off: add "-- --perf" (no stills; 150 frames
##   each way, twice; "-- --perf=40" for 40, quicker on a busy machine).
## Writes stills to $OUT_DIR (default /tmp/shots):
## ripples_<night|dusk|noon>_<moment>.png.

const FPS := 30.0
const SEQUENCE_S := 13.0
## Seconds after spawning in the water before the sequence starts, so the
## splash of dropping in has died away (the 3D view isn't drawn then).
const SETTLE_S := 8.0
## The camera's pitch (radians, down) while wading, and while aiming:
## nearly level, so the arrow comes down ~8 m out (12 m from the camera),
## clear of the rings round the player's feet (at -0.22 it landed 3 m
## out, among them and half hidden by the player).
const PITCH := -0.38
const AIM_PITCH := -0.05
## Named stills: time (s) -> moment.
const STILLS := {2.0: "wading", 3.8: "wake", 5.8: "arrow", 7.2: "overlap", 10.5: "rain", 12.5: "rain_wading"}

var out_dir := "/tmp/shots"
var world: Node
var main: Node
var sim: RippleSim
var player: PlanetPlayer
var perf := false
var perf_frames := 150
var movie := false
var spot := Vector3.ZERO # wading spot (surface direction)
var shore := Vector3.ZERO # dry land behind it
var along := Vector3.ZERO # along the shore (tangent)
var out_to := Vector3.ZERO # toward open water (tangent)
var level := 0.0 # water level at the spot


func _initialize() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		out_dir = env_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	for a in OS.get_cmdline_user_args():
		if a == "--perf" or a.begins_with("--perf="):
			perf = true
			if "=" in a:
				perf_frames = maxi(10, int(a.get_slice("=", 1)))
	# Movie Maker mode (--write-movie is the engine's own argument, so it
	# isn't in OS.get_cmdline_args()).
	movie = OS.has_feature("movie")
	world = get_root().get_node("World")
	# Loading and settling don't need the 3D view drawn (much faster on a
	# software renderer); it's switched on for what's recorded or saved.
	get_root().disable_3d = true
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_run.call_deferred()


func _run() -> void:
	while not main._playing:
		await process_frame
	main._weather_timer = 1e9
	var calm := {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": 0.25}
	main._local_weather = calm.duplicate()
	main._weather_eased = calm.duplicate()
	main.hud.visible = false
	Bow.need_capture = false
	sim = main.ripples
	player = main.player
	if not await _find_water():
		print("[ripples] FAIL: no open wading water near the first camp")
		quit(1)
		return
	print("[ripples] water at the spot: level %.2f m, ground %.2f m; ripples running: %s" % [
		level, main.chunks.ground_height(spot), sim.running])
	if perf:
		await _settle(23.0)
		get_root().disable_3d = false
		await _perf()
		quit()
		return
	await _settle(23.0)
	if movie:
		# The movie writer adds one frame per engine frame: the first with the
		# 3D view on is this one (checked against the recording).
		var start := Engine.get_process_frames()
		print("[ripples] sequence starts at movie frame %d (%.2f s into the recording)" % [start, start / FPS])
	var cost := await _sequence("night", true)
	print("[ripples] RippleSim.update_ripples: %.0f us a frame on average; up to %d stamps a step" % [cost.x, int(cost.y)])
	if movie:
		quit()
		return
	await _settle(18.33)
	await _sequence("dusk", false, 9.0)
	await _settle(12.0)
	await _sequence("noon", false, 6.0)
	await _compare()
	quit()


## Put the player back in the water at the spot, facing open water, at
## local hour `hour`, and wait (not drawn) until the water is calm.
func _settle(hour: float) -> void:
	get_root().disable_3d = true
	_rain(0.0)
	_set_hour(hour)
	player.spawn_at(spot, _p(30.0, 0.0))
	player.set_view(PITCH, 0.0)
	for i in int(SETTLE_S * FPS):
		await process_frame


## The sequence (see the header), `until` s of it. Returns the average
## update_ripples cost (us) and the most stamps a step.
func _sequence(tag: String, wet: bool, until := SEQUENCE_S) -> Vector2:
	if movie:
		get_root().disable_3d = false
	var cost := 0
	var stamps := 0
	var frames := int(until * FPS)
	for f in frames:
		var t := f / FPS
		_script(t, f, wet)
		await process_frame
		cost += sim.last_update_us
		stamps = maxi(stamps, sim.last_stamps)
		for s in STILLS:
			var moment: String = STILLS[s]
			if f == int(float(s) * FPS) and not movie and (wet or not moment.begins_with("rain")):
				await _still("%s_%s" % [tag, moment])
	for a in ["move_left", "move_right", "shoot"]:
		Input.action_release(a)
	return Vector2(float(cost) / maxi(frames, 1), stamps)


func _script(t: float, f: int, wet: bool) -> void:
	if f == 0:
		Input.action_press("move_right")
	if f == int(4.0 * FPS):
		Input.action_release("move_right")
		Input.action_press("shoot")
	if t >= 4.0 and t <= 4.5:
		# Raise the aim, so the arrow lands out in the open.
		player.set_view(lerpf(PITCH, AIM_PITCH, (t - 4.0) / 0.5), 0.0)
	if f == int(5.0 * FPS):
		Input.action_release("shoot")
	if t >= 5.3 and t <= 5.8:
		player.set_view(lerpf(AIM_PITCH, PITCH, (t - 5.3) / 0.5), 0.0)
	if f == int(5.8 * FPS):
		Input.action_press("move_left")
	if f == int(8.8 * FPS):
		Input.action_release("move_left")
	if f == int(10.0 * FPS):
		Input.action_press("move_right")
	if f == int(12.2 * FPS):
		Input.action_release("move_right")
	if wet and f == int(8.0 * FPS):
		_rain(6.0)


## Draw this frame's 3D view and save it.
func _still(name: String) -> void:
	get_root().disable_3d = false
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/ripples_%s.png" % [out_dir, name])
	get_root().disable_3d = true


## The CPU readers' estimate (height_at) next to the simulated buffer
## (read back from the GPU, fine in a tool) after one splash in calm
## water, out from it.
func _compare() -> void:
	# Let the sequence's rings die away (and leave the readers' memory).
	for i in int(float(sim.cfg.readers.source_life_s) * FPS):
		await process_frame
	Ripples.splash(_at(_p(12.0, 5.0), 0.0), 65.0, 3.0)
	for i in int(1.6 * FPS):
		await process_frame
	var state: Image = sim._vps[(sim._frame - 1) % 2].get_texture().get_image()
	var line := "[ripples] 1.6 s after a splash, height (m) simulated / estimated:"
	for r in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		var p := _at(_p(12.0 + r, 5.0), 0.0)
		var t := sim._texel(sim._plane(p))
		var c := state.get_pixel(roundi(t.x), roundi(t.y))
		var n := roundi(c.r * 255.0) * 256 + roundi(c.g * 255.0)
		var h := (n - 65536 if n >= 32768 else n) / 32767.0 * 0.5
		line += " %.1f m: %+.4f / %+.4f;" % [r, h, sim.height_at(p)]
	print(line)
	print("[ripples] disturbance_at 1.5 m out: %.4f m" % sim.disturbance_at(_at(_p(13.5, 5.0), 0.0)))


## A surface direction `ahead` m out from the shore toward open water and
## `side` m along the shore.
func _p(ahead: float, side: float) -> Vector3:
	return (shore + (out_to * ahead + along * side) / PlanetConst.RADIUS_M).normalized()


## Scene position on the water (plus `h` m) over a surface direction.
func _at(d: Vector3, h: float) -> Vector3:
	return world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.water_level_at(d) + h)


func _set_hour(h: float) -> void:
	world.days = Astro.days_at_solar_hour(world.days, h, CubeSphere.longitude(spot), CubeSphere.latitude(spot))


func _rain(mm_h: float) -> void:
	for w in [main._local_weather, main._weather_eased]:
		w["rain_mm_h"] = mm_h
		w["cloud"] = 0.8 if mm_h > 0.0 else 0.25


## Wading water near the first camp: a spot 0.35-0.8 m deep with dry
## land 10 m one way and open water fanning out the other (on the
## blueprint's terrain), nearest the camp's fire first; the first whose
## view out over the water and wading path have no tree trunks standing
## in them (wetland trees grow in the shallows). Loads it.
func _find_water() -> bool:
	var map: PlanetData = world.planet
	# The fire, not the player's place by it (a different side each game).
	var c: Vector3 = main.camp.site
	var rejected: Array[Vector3] = []
	for r in range(30, 3000, 30):
		for i in 72:
			var a := i * TAU / 72.0
			var d := CreatureSpawner._offset(c, a, float(r))
			var wl := TerrainChunk._standing_water(map, d).x
			var depth := wl - map.terrain.elevation(d, true)
			if depth < 0.35 or depth > 0.8:
				continue
			if rejected.any(func(q: Vector3) -> bool: return CubeSphere.surface_distance_m(q, d) < 20.0):
				continue
			# Which way is land? Probe round the spot for dry land one way
			# and open water in a fan out the other way.
			for j in 16:
				var b := j * TAU / 16.0
				var land := CreatureSpawner._offset(d, b, 10.0)
				if map.terrain.elevation(land, true) < TerrainChunk._standing_water(map, land).x + 0.4:
					continue
				var open := true
				for probe in [[0.0, 25.0], [0.0, 40.0], [0.5, 20.0], [-0.5, 20.0], [0.8, 12.0], [-0.8, 12.0]]:
					var q := CreatureSpawner._offset(d, b + PI + float(probe[0]), float(probe[1]))
					if TerrainChunk._standing_water(map, q).x - map.terrain.elevation(q, true) < 0.5:
						open = false
				if not open:
					continue
				spot = d
				shore = CreatureSpawner._offset(d, b, 7.0)
				var t := d - shore
				out_to = (t - shore * shore.dot(t)).normalized()
				along = shore.cross(out_to).normalized()
				await _goto(d)
				var trunks := _trunks_in_view()
				if trunks == 0:
					print("[ripples] wading spot %.0f m from the camp's fire, %.2f m deep (%d passed over for trunks in view)" % [
						r, depth, rejected.size()])
					return true
				rejected.append(d)
				break
			if rejected.size() >= 16:
				return false
	return false


## Tree trunks standing where the demo looks or wades: out over the water
## within 50 degrees either side up to 35 m, and along the shore 9 m each
## way.
func _trunks_in_view() -> int:
	var here := _at(spot, 0.0)
	var n := 0
	for ch in main.chunks.chunks.values():
		var chunk := ch as TerrainChunk
		for i in chunk.trees.size():
			if float(chunk.trees[i][1]) < 2.0:
				continue
			var rel := chunk.tree_base(i) - here
			var ahead := rel.dot(out_to)
			var side := absf(rel.dot(along))
			if ahead > -3.0 and ahead < 35.0 and side < 9.0 + maxf(ahead, 0.0) * 1.2:
				n += 1
	return n


## Go to `d` (the player too, so the chunks stream round it) and wait
## until they're loaded.
func _goto(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 2.0)
	world.rebase(offset)
	player.global_position -= offset
	main.chunks.load_blocking(d)
	player.spawn_at(d, _p(30.0, 0.0))
	for k in 120:
		await process_frame
		if k > 30 and main.chunks._pending.is_empty():
			break
	level = main.chunks.water_level_at(d)


## Frame cost with the ripples busy (splashes and a wake every frame) and
## with the simulation off, same view, `perf_frames` frames each, twice.
func _perf() -> void:
	var vp_rids := []
	for vp in sim._vps + [sim._view_vp]:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
		vp_rids.append(vp.get_viewport_rid())
	RenderingServer.viewport_set_measure_render_time(get_root().get_viewport_rid(), true)
	for on in [true, false, true, false]:
		sim.cfg.enabled = on
		for i in mini(20, perf_frames):
			await process_frame
		var gpu_sim := 0.0
		var gpu_main := 0.0
		var update_us := 0
		var t0 := Time.get_ticks_usec()
		for f in perf_frames:
			if f % 20 == 0:
				Ripples.splash(_at(_p(12.0, (f % 60) / 10.0 - 3.0), 0.0), 65.0, 3.0)
			Ripples.wake(777, _at(_p(14.0, -6.0 + f * 0.08), 0.0), 70.0, 2.4)
			await process_frame
			for rid in vp_rids:
				gpu_sim += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			gpu_main += RenderingServer.viewport_get_measured_render_time_gpu(get_root().get_viewport_rid())
			update_us += sim.last_update_us
		var total := Time.get_ticks_usec() - t0
		var n := float(perf_frames)
		print("[ripples] perf, ripples %s: %.1f ms a frame; GPU: ripple viewports %.2f ms, main view %.1f ms (lavapipe: relative only); update_ripples %.0f us" % [
			"on " if on else "off", total / n / 1000.0, gpu_sim / n, gpu_main / n, update_us / n])

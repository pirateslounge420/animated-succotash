extends SceneTree
## Phase 0 check (spec Part C: "a 20-min time-lapse shows sun and moon
## crossing with no snapping"). Steps the dev clock through whole days and
##   1. logs, frame by frame at 30 fps, everything the sky sets (sun and
##      moon elevation, sky zenith and horizon color, ambient light, fog
##      color, sun and moon light, stars, the mansion glyph, the clouds'
##      light direction), and fails if any of it changes more in one frame
##      than the limits in LIMITS (a snap). It also times each phase and
##      runs the same day again with the weather changing in sudden steps,
##      to check the easing;
##   2. with a display, renders a contact sheet of 16 frames across the
##      day from a fixed camera at the first camp (the debug overlay on
##      each), and a graph of the day: sun and moon elevation, ambient
##      light, the sky's turning speed and the sky colors, over the four
##      phases.
##
## Run from the project folder:
##   numbers only (seconds, no window):
##     ~/bin/godot --headless -s tools/p0_timelapse.gd
##   numbers, contact sheet and graph (any GPU, or software Vulkan):
##     xvfb-run -a -s "-screen 0 960x540x24" ~/bin/godot --rendering-method forward_plus --resolution 960x540 -s tools/p0_timelapse.gd
## Writes to $OUT_DIR (default /tmp/shots): p0_timelapse.csv (one row per
## second of the equator run), p0_timelapse_sheet.png, p0_curves.png.
## Exit code 1 if a limit is exceeded.

## Largest change allowed in one 1/30 s frame. Colors are 0-1 per channel
## (1/255 = 0.0039); energies are shares of full strength; angles in degrees.
const LIMITS := {
	"sun_el": 0.05, "moon_el": 0.05,
	"zenith": 0.004, "horizon": 0.004, "fog": 0.004, "ambient_color": 0.004,
	"ambient": 0.004, "sun_energy": 0.0047, "moon_energy": 0.0047, # energies: share of full strength (0.004 of the old 0.85 sun)
	"stars": 0.01, "sun_disc": 0.01, "glyph": 0.03, "cloud_dir": 0.2,
	"sky_speed": 0.01,
}
## The mansion glyph may only change pattern while this faint or fainter.
const GLYPH_SWAP_MAX := 0.01
const FPS := 30.0
const SHEET_FRAMES := 16

var out_dir := "/tmp/shots"
var world: Node
var failures: Array[String] = []
var curve := [] # equator run, one sample per real second (for the graph)
var day_s := 1200.0


func _initialize() -> void:
	var env_out := OS.get_environment("OUT_DIR")
	if env_out != "":
		out_dir = env_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	world = get_root().get_node("World")
	_run.call_deferred()


func _run() -> void:
	# (World reads data/dev.json in its _ready, after _initialize.)
	day_s = world.day_length_s
	print("[p0] day length %.1f real min (dev mode %s); phases (min of a %.0f-min day): %s" % [day_s / 60.0, world.dev_mode, DayCycle.day_length_min(), DayCycle.phase_minutes()])
	# 1. Numbers, on a stand-alone sky (no planet needed).
	var clear := {"cloud": 0.25, "storm": 0.0, "wind": Vector3(2, 0, 1), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0}
	_sweep("equator, clear", 0.0, 0.0, 13.0, 2.0, clear, false, true)
	_sweep("50N, clear", 50.0, 0.7, 13.0, 1.0, clear, false, false)
	_sweep("equator, stepped weather", 0.0, 0.0, 13.0, 1.0, clear, true, false)
	_moon_check()
	_inverse_check()
	if failures.is_empty():
		print("[p0] PASS: no frame-to-frame jump above the limits")
	else:
		for f in failures:
			print("[p0] FAIL: ", f)
	if DisplayServer.get_name() == "headless":
		print("[p0] headless: skipping the contact sheet and graph")
		quit(0 if failures.is_empty() else 1)
		return
	await _contact_sheet()
	await _graph()
	quit(0 if failures.is_empty() else 1)


# --- 1. Frame-by-frame sweep --------------------------------------------------

func _dir(lat_deg: float, lon: float) -> Vector3:
	var lat := deg_to_rad(lat_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


func _sample(sky: SkySystem) -> Dictionary:
	var m := sky.sky_material
	return {
		"sun_el": sky.sun_elevation_deg,
		"moon_el": sky.moon_elevation_deg,
		"zenith": m.get_shader_parameter("zenith_color"),
		"horizon": m.get_shader_parameter("horizon_color"),
		"fog": sky.environment.fog_light_color,
		"ambient_color": sky.environment.ambient_light_color,
		"ambient": sky.environment.ambient_light_energy,
		# As a share of full strength (data/look.json sets full), so the
		# limits mean the same whatever the lights' strength.
		"sun_energy": sky.sun.light_energy / maxf(sky.sun_max_energy, 1e-4),
		"moon_energy": sky.moon.light_energy / maxf(sky.moon_max_energy, 1e-4),
		"stars": float(m.get_shader_parameter("star_visibility")),
		"sun_disc": float(m.get_shader_parameter("sun_visible")),
		"glyph": float(m.get_shader_parameter("glyph_visibility")),
		"cloud_dir": sky.cloud_light_dir,
		"daylight": sky.daylight,
	}


static func _diff(a, b) -> float:
	if a is Color:
		var ca: Color = a
		var cb: Color = b
		return maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b))
	if a is Vector3:
		return rad_to_deg((a as Vector3).angle_to(b))
	return absf(float(a) - float(b))


## Runs `n_days` of the dev clock at 30 fps through a stand-alone
## SkySystem at a latitude/longitude, recording per-frame changes.
## `stepped`: the weather jumps (as the live weather does when it's
## resampled or steps), fed through the same easing main.gd uses.
func _sweep(label: String, lat_deg: float, lon: float, start_days: float, n_days: float, weather: Dictionary, stepped: bool, keep_curve: bool) -> void:
	var sky := SkySystem.new()
	get_root().add_child(sky)
	var up := _dir(lat_deg, lon)
	var east := CubeSphere.east(up)
	var north := CubeSphere.north(up)
	var dt := 1.0 / FPS
	var frames := int(n_days * day_s * FPS)
	var days := start_days
	var eased := {}
	var target := weather.duplicate()
	var prev := {}
	var max_d := {}
	var at := {}
	var cross := [] # clock times the sun crosses -tw, +tw
	var tw := DayCycle.twilight_deg()
	var prev_el := NAN
	var swaps := 0
	var swap_vis := 0.0
	var shown := -1
	var csv: FileAccess = null
	if keep_curve:
		csv = FileAccess.open(out_dir.path_join("p0_timelapse.csv"), FileAccess.WRITE)
		csv.store_line("real_s,clock_h,solar_h,phase,sun_el,moon_el,zenith_r,zenith_g,zenith_b,horizon_r,horizon_g,horizon_b,fog_r,fog_g,fog_b,ambient,sun_energy,moon_energy,stars,glyph,turn_rate")
	for f in frames:
		var t := f * dt
		if stepped:
			# A sudden new weather sample every 12.5 s (the live weather steps
			# every in-game quarter hour: 12.5 s on the 20-minute dev day),
			# with big swings in cloud, storm and wind.
			var k := int(t / 12.5)
			target["cloud"] = [0.1, 0.9, 0.3, 1.0, 0.0, 0.6][k % 6]
			target["storm"] = [0.0, 0.7, 0.0, 0.9, 0.0, 0.2][k % 6]
			target["wind"] = Vector3(8, 0, -3) if k % 2 == 0 else Vector3(-4, 0, 6)
		WeatherSim.ease_toward(eased, target, dt, DayCycle.weather_smoothing_s())
		var lat := deg_to_rad(lat_deg)
		var sky_days := Astro.apparent_days(days, lon, lat)
		sky.update_sky(up, east, north, sky_days, eased, 0.2, dt)
		var s := _sample(sky)
		s["sky_speed"] = DayCycle.turn_rate(fposmod(Astro.time_of_day(days) + lon / TAU, 1.0), lat, Astro.declination(days))
		if sky._shown_mansion != shown:
			if shown >= 0:
				swaps += 1
				swap_vis = maxf(swap_vis, float(prev.get("glyph", 0.0)))
			shown = sky._shown_mansion
		if not prev.is_empty():
			for key in LIMITS:
				var d := _diff(s[key], prev[key])
				if d > float(max_d.get(key, -1.0)):
					max_d[key] = d
					at[key] = t
		prev = s
		var el: float = s.sun_el
		if not is_nan(prev_el):
			for lvl in [-tw, tw]:
				if (prev_el - lvl) * (el - lvl) < 0.0:
					cross.append([t, lvl, el > prev_el])
		prev_el = el
		if keep_curve and f % int(FPS) == 0:
			var clock := fposmod(Astro.time_of_day(days) + lon / TAU, 1.0)
			var row := {"t": t, "clock": clock, "sun_el": el, "moon_el": s.moon_el, "zenith": s.zenith, "horizon": s.horizon, "fog": s.fog,
				"ambient": s.ambient, "sun_energy": s.sun_energy, "moon_energy": s.moon_energy, "daylight": s.daylight, "rate": DayCycle.turn_rate(clock)}
			curve.append(row)
			var z: Color = s.zenith
			var h: Color = s.horizon
			var fg: Color = s.fog
			csv.store_line("%.0f,%.4f,%.4f,%s,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%.3f,%.4f" % [
				t, clock * 24.0, Astro.local_hours(sky_days, lon), DayCycle.phase_at(clock).name, el, s.moon_el,
				z.r, z.g, z.b, h.r, h.g, h.b, fg.r, fg.g, fg.b, s.ambient, s.sun_energy, s.moon_energy, s.stars, s.glyph, DayCycle.turn_rate(clock)])
		days += dt / day_s
	if csv:
		csv.close()
	sky.free()
	print("[p0] --- %s: %d frames (%.1f dev days) ---" % [label, frames, n_days])
	for key in LIMITS:
		var ok: bool = float(max_d.get(key, 0.0)) <= float(LIMITS[key])
		print("  %-13s max step %.5f (limit %.4f) at %6.1f s %s" % [key, max_d.get(key, 0.0), LIMITS[key], at.get(key, 0.0), "ok" if ok else "SNAP"])
		if not ok:
			failures.append("%s: %s jumped %.5f in one frame at %.1f s (limit %.4f)" % [label, key, max_d[key], at[key], LIMITS[key]])
	print("  mansion glyph: %d change(s), glyph visibility when swapped at most %.4f (limit %.2f) %s" % [swaps, swap_vis, GLYPH_SWAP_MAX, "ok" if swap_vis <= GLYPH_SWAP_MAX else "POP"])
	if swap_vis > GLYPH_SWAP_MAX:
		failures.append("%s: the mansion glyph changed while visible (%.3f)" % [label, swap_vis])
	# Phase lengths from the sun's crossings of +-twilight_deg.
	var scale := DayCycle.day_length_min() / (day_s / 60.0)
	var names := {}
	for i in cross.size() - 1:
		var a: Array = cross[i]
		var b: Array = cross[i + 1]
		var rising: bool = a[2]
		var name := ""
		if a[1] < 0.0 and rising:
			name = "dawn"
		elif a[1] > 0.0 and rising:
			name = "day"
		elif a[1] > 0.0 and not rising:
			name = "dusk"
		else:
			name = "night"
		if not names.has(name):
			names[name] = (float(b[0]) - float(a[0])) / 60.0
	var parts := []
	for n in ["day", "dusk", "night", "dawn"]:
		if names.has(n):
			parts.append("%s %.2f real min (%.1f of a %.0f-min day)" % [n, names[n], names[n] * scale, DayCycle.day_length_min()])
	print("  phases: ", ", ".join(parts))


## days_at_solar_hour (the game opens at 17:00 solar time at the camp)
## must land on the asked-for hour: warp(unwarp(h)) == h.
func _inverse_check() -> void:
	var worst := 0.0
	for lat in [0.0, 0.8]:
		for i in 480:
			var h := 24.0 * i / 480.0
			var d := Astro.days_at_solar_hour(13.0, h, 0.9, lat)
			var back := Astro.local_hours(Astro.apparent_days(d, 0.9, lat), 0.9)
			worst = maxf(worst, absf(fposmod(back - h + 12.0, 24.0) - 12.0))
	print("[p0] start-hour inverse: worst error %.9f hours (17:00 -> %.4f)" % [worst, Astro.local_hours(Astro.apparent_days(Astro.days_at_solar_hour(13.0, 17.0, 0.9), 0.9), 0.9)])
	if worst > 1e-6:
		failures.append("days_at_solar_hour is off by %.9f hours" % worst)


## The moon: its cycle, and the mansion following it.
func _moon_check() -> void:
	var cycle := DayCycle.moon_cycle_days()
	var changes := 0
	var last := Astro.mansion_index(0.0)
	var steps := 20000
	for i in range(1, steps + 1):
		var d := cycle * float(i) / steps
		var m := Astro.mansion_index(d)
		if m != last:
			changes += 1
			last = m
	print("[p0] moon: %.1f-day cycle; mansion changes %d times per cycle (every %.2f days); full moon at day %.2f; rises ~%.0f min of game time later each day" % [
		cycle, changes, cycle / maxf(changes, 1), cycle * 0.5, 24.0 * 60.0 / cycle])
	if changes != 28:
		failures.append("moon: the mansion changed %d times in one cycle (want 28)" % changes)


# --- 2. Contact sheet --------------------------------------------------------

var main
var cam: Camera3D


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _contact_sheet() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var fixed := {"wind": Vector3(2, 0, 1), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": 0.2}
	main._weather_timer = 1e9
	main._local_weather = fixed
	main._weather_eased = fixed.duplicate()
	var hud: Hud = main.hud
	for c in hud.get_children():
		if c is CanvasItem:
			c.visible = false
	hud.toggle_debug()
	hud._debug.add_theme_font_size_override("font_size", 22)
	hud._debug.add_theme_constant_override("outline_size", 8)
	var pd: Vector3 = main.player.surface_dir
	main.player.visible = false
	cam = Camera3D.new()
	cam.far = 30000.0
	cam.near = 0.1
	cam.fov = 62.0
	get_root().add_child(cam)
	# From above the camp's treetops, toward open low ground (the sea if
	# it's near), leaning east so sunrise and moonrise are in view; tilted
	# up so the sky fills most of the frame with a band of land below.
	var m: PlanetData = world.planet
	var e := CubeSphere.east(pd)
	var n := CubeSphere.north(pd)
	var best_dir := e
	var best_score := INF
	for k in 24:
		var a := k * TAU / 24.0
		var flat := n * cos(a) + e * sin(a)
		var q := (pd + flat * 2500.0 / PlanetConst.RADIUS_M).normalized()
		var score := maxf(m.terrain.elevation(q, true), 0.0) - 25.0 * flat.dot(e)
		if score < best_score:
			best_score = score
			best_dir = flat
	var eye: Vector3 = world.to_scene(pd, PlanetConst.RADIUS_M + main.chunks.ground_height(pd) + 40.0)
	var look := (best_dir * cos(deg_to_rad(8.0)) + pd * sin(deg_to_rad(8.0))).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(look, pd), eye)
	cam.current = true
	# One day forward from local midnight (a steady clock, so the moon
	# and mansion move on as they would).
	var lon := CubeSphere.longitude(pd)
	var start := floorf(world.days) + fposmod(-lon / TAU, 1.0)
	var shots: Array[Image] = []
	for i in SHEET_FRAMES:
		var clock := float(i) / SHEET_FRAMES
		var days := start + clock
		for k in 12:
			world.days = days
			hud._readout_timer = 0.0
			await process_frame
		var img := get_root().get_texture().get_image()
		img.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		shots.append(img)
		print("[p0] frame %d: clock %s, sun %.1f°" % [i, Hud._hhmm(clock * 24.0), main.sky.sun_elevation_deg])
	var sheet := Image.create(480 * 4, 270 * 4, false, Image.FORMAT_RGB8)
	for i in shots.size():
		shots[i].convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shots[i], Rect2i(0, 0, 480, 270), Vector2i((i % 4) * 480, (i / 4) * 270))
	var path := out_dir.path_join("p0_timelapse_sheet.png")
	sheet.save_png(path)
	print("[p0] saved ", path)
	main.queue_free()
	cam.queue_free()
	await _frames(3)


# --- 3. Graph of the day -----------------------------------------------------

const PHASE_COLORS := {"night": Color(0.08, 0.09, 0.2), "dawn": Color(0.32, 0.2, 0.3), "day": Color(0.2, 0.3, 0.45), "dusk": Color(0.36, 0.22, 0.2)}


func _graph() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_root().add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var plot := Control.new()
	plot.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(plot)
	plot.draw.connect(_draw_graph.bind(plot))
	await _frames(4)
	var path := out_dir.path_join("p0_curves.png")
	get_root().get_texture().get_image().save_png(path)
	print("[p0] saved ", path)


func _draw_graph(c: Control) -> void:
	var font := ThemeDB.fallback_font
	var size := c.get_viewport_rect().size
	var x0 := 60.0
	var x1 := size.x - 20.0
	var top := 40.0
	var y_bot := size.y - 150.0 # bottom of the line plot; color strips below
	# Plot one dev day (the first of the equator run).
	var rows := curve.filter(func(r): return r.t < day_s)
	var n := rows.size()
	var xt := func(i: int) -> float: return x0 + (x1 - x0) * float(i) / maxf(n - 1, 1)
	# Phase bands.
	var i0 := 0
	for i in range(1, n + 1):
		var cur: String = DayCycle.phase_at(rows[i0].clock).name
		if i == n or DayCycle.phase_at(rows[i].clock).name != cur:
			c.draw_rect(Rect2(xt.call(i0), top, xt.call(i - 1) - xt.call(i0) + 1.0, y_bot - top), PHASE_COLORS[cur])
			var ph := DayCycle.phase_at(rows[i0].clock)
			c.draw_string(font, Vector2(xt.call(i0) + 4.0, top + 16.0), "%s %.0f min" % [cur, float(ph.length) * DayCycle.day_length_min()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
			i0 = i
	# Horizon and +-twilight lines (for elevation, -90..90 over the plot).
	var ye := func(deg: float) -> float: return lerpf(y_bot, top, (deg + 90.0) / 180.0)
	for deg in [-DayCycle.twilight_deg(), 0.0, DayCycle.twilight_deg()]:
		c.draw_line(Vector2(x0, ye.call(deg)), Vector2(x1, ye.call(deg)), Color(1, 1, 1, 0.25 if deg != 0.0 else 0.5), 1.0)
	var series := [
		["sun elevation (-90..90°)", Color(1.0, 0.8, 0.2), func(r): return ye.call(r.sun_el)],
		["moon elevation", Color(0.7, 0.8, 1.0), func(r): return ye.call(r.moon_el)],
		["ambient energy (0..0.6)", Color(0.4, 1.0, 0.5), func(r): return lerpf(y_bot, top, r.ambient / 0.6)],
		["sun light (0..1)", Color(1.0, 0.5, 0.2), func(r): return lerpf(y_bot, top, r.sun_energy)],
		["sky turning speed (0..2x)", Color(1.0, 0.4, 0.9), func(r): return lerpf(y_bot, top, r.rate / 2.0)],
	]
	for s in series:
		var pts := PackedVector2Array()
		for i in n:
			pts.append(Vector2(xt.call(i), s[2].call(rows[i])))
		c.draw_polyline(pts, s[1], 2.0, true)
	c.draw_rect(Rect2(x0 + 6.0, top + 26.0, 196.0, 16.0 * series.size() + 8.0), Color(0.03, 0.03, 0.05, 0.85))
	var ly := top + 42.0
	for s in series:
		c.draw_string(font, Vector2(x0 + 12.0, ly), s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, s[1])
		ly += 16.0
	# Color strips: zenith, horizon, fog.
	var strips := [["zenith", "zenith"], ["horizon", "horizon"], ["fog", "fog"]]
	var sy := y_bot + 12.0
	for st in strips:
		for i in n:
			var col: Color = rows[i][st[1]]
			c.draw_line(Vector2(xt.call(i), sy), Vector2(xt.call(i), sy + 26.0), col, 2.0)
		c.draw_string(font, Vector2(4.0, sy + 18.0), st[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		sy += 30.0
	# Time axis: real minutes of the dev day and the solar clock.
	for m in range(0, int(day_s / 60.0) + 1, 2):
		var x: float = x0 + (x1 - x0) * m * 60.0 / day_s
		c.draw_line(Vector2(x, y_bot), Vector2(x, y_bot + 4.0), Color.WHITE)
		c.draw_string(font, Vector2(x - 8.0, size.y - 34.0), "%d" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	c.draw_string(font, Vector2(x0, size.y - 14.0), "real minutes of the %.0f-min dev day, from midnight (equator)" % (day_s / 60.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.8))
	c.draw_string(font, Vector2(x0, 24.0), "Day cycle: phases in minutes of the %.0f-min game day; lines = sun & moon elevation, ambient, sun light, sky speed" % DayCycle.day_length_min(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

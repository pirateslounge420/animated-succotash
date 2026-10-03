extends SceneTree
## Rain falls only from a raincloud you can see (design 3 Oct §CX; Mike's
## 14:34 play: rain from a clear sky), headless:
##   godot --headless --path . --script tools/weather_cover_check.gd
## Asserts:
##  - on a real planet (SEED, default 7731), over many places and hours,
##    rain falls only where the cover overhead is at least
##    WeatherSim.RAIN_COVER.x, and the HUD says "Overcast", "Rain" or
##    "Storm" wherever it falls;
##  - one cover value: the low deck's drawn cover is the weather's cloud;
##  - the cloud builds before the rain and the rain stops before the cloud
##    clears (a shower eased in and out the way Main eases the weather);
##  - the cloud shells' flat panels never sag under the layer's altitude,
##    on the 4,000 km, 400 km and 40 km planets (CloudLayers chord_k).

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	var world = get_root().get_node("World")
	world._load_dev_settings()
	world.use_postage_stamp(false)
	var sd := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.generate_now(sd)
	var ws: WeatherSim = world.weather
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rainy := 0
	var bad := 0
	var bad_word := 0
	var worst := 1.0
	var n := 0
	for step in 48:
		ws.step(0.5, Vector3(cos(step * 0.26), 0.3, sin(step * 0.26)).normalized())
		for k in 400:
			var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var w := ws.local_weather(d, 10.0)
			n += 1
			var rain := float(w.get("rain_mm_h", 0.0))
			if rain > 0.01:
				rainy += 1
				var c := float(w.get("cloud", 0.0))
				worst = minf(worst, c)
				if c < WeatherSim.RAIN_COVER.x:
					bad += 1
				var word := Hud._weather_word(w, 0.0)
				if not (word.begins_with("Overcast") or word.contains("ain") or word.contains("now") or word.contains("Storm")):
					bad_word += 1
	ok(rainy > 0, "it rains somewhere (%d of %d samples)" % [rainy, n])
	ok(bad == 0, "rain only under a thick deck: the thinnest cover it fell from is %.2f (want %.2f or more)" % [worst, WeatherSim.RAIN_COVER.x])
	ok(bad_word == 0, "wherever it rains the HUD says so (%d samples said otherwise)" % bad_word)
	# The order: a shower eased in and out as Main does.
	var cur := {}
	var tau := 6.0
	var rain_started_at := -1.0
	var rain_stopped_at := -1.0
	var cloud_at_start := 0.0
	var cloud_at_stop := 0.0
	var t := 0.0
	var target := {"cloud": 0.05, "rain_rate": 0.0}
	for i in 2400:
		t = i * 0.05
		if t > 5.0 and t < 60.0:
			target = {"cloud": 0.95, "rain_rate": 3.0}
		elif t >= 60.0:
			target = {"cloud": 0.05, "rain_rate": 0.0}
		WeatherSim.ease_toward(cur, target, 0.05, tau)
		var rate := float(cur.get("rain_rate", 0.0)) * WeatherSim.rain_gate(float(cur.cloud))
		if rate > 0.05 and rain_started_at < 0.0:
			rain_started_at = t
			cloud_at_start = float(cur.cloud)
		if t > 60.0 and rate <= 0.05 and rain_stopped_at < 0.0:
			rain_stopped_at = t
			cloud_at_stop = float(cur.cloud)
	ok(rain_started_at > 5.0 and cloud_at_start >= WeatherSim.RAIN_COVER.x, "the cloud builds first: rain starts %.1f s in, under cover %.2f" % [rain_started_at - 5.0, cloud_at_start])
	ok(rain_stopped_at > 60.0 and cloud_at_stop >= WeatherSim.RAIN_COVER.x - 0.05, "the rain stops before the cloud clears: %.1f s after, cover still %.2f" % [rain_stopped_at - 60.0, cloud_at_stop])
	# The shells.
	var mesh := CloudLayers._unit_sphere(64)
	var k := 1.0 / CloudLayers._min_plane_distance(mesh)
	var lowest := CloudLayers._min_plane_distance(mesh) * k
	for r in [637000.0, 63662.0, 6366.0]:
		var alt := 150.0
		var sag: float = (r + alt) * (1.0 - lowest)
		var bulge: float = (r + alt) * (k - 1.0)
		ok(sag <= 0.01, "on a planet of radius %.1f km the 150 m deck never dips under 150 m (lowest point %+.2f m; corners %.1f m up)" % [r / 1000.0, -sag, bulge])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

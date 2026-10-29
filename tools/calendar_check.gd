extends SceneTree
## The crawler's calendar (design §GE, §GK.1.2; queue 114; CrawlerCalendar,
## crawler.json calendar), headless:
##   godot --headless --path . --script tools/calendar_check.gd
## Asserts:
##  1. one shared year, no latitude (§GK.1.2): the hub and every realm kind
##     give the same phase minutes on every 5th day of the year, and the
##     same sun at the same moment;
##  2. the phase minutes match tools/reference/daylight_reference.py's 35°
##     within 1 minute at both solstices and an equinox (summer
##     74.4/18/33.6/18, equinox 61.3/18/46.7/18, winter 50.6/18/57.4/18);
##  3. dawn and dusk are 18 minutes every day of a fast-forwarded year;
##  4. the sky agrees: the noon sun stands 90 - 35 + tilt degrees up at the
##     June solstice, 90 - 35 - tilt at December's, at the hub and in a
##     realm alike; the shafts' daylight (Vents.sun_deg) is the same sun;
##  5. a fast-forwarded year passes spring, summer, autumn, winter in that
##     order, and is spring again after 365 days;
##  6. winter by biome (§GE.5.4, kept by §GK.1.2): plants drop leaves only
##     where the winter is not a dry season (the hub keeps them; temperate
##     realms drop them);
##  7. in the game (SEED=7): a new game starts at year day 0 at dusk on
##     the hub; the log's stamp says the season; Continue keeps the saved
##     day and hour;
##  8. the open world untouched: with the calendar's statics at rest the
##     one-clock sun is the old equator-equinox one.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _mins(lat_deg: float, yd: float) -> Dictionary:
	var days := yd - DayCycle.year_start_day()
	var st := CrawlerCalendar.stylised(deg_to_rad(lat_deg), Astro.declination(days))
	return {"day": st.day, "dusk": st.dusk, "night": st.night, "dawn": st.dawn}


func _near(m: Dictionary, want: Array, tol := 1.0) -> bool:
	return absf(m.day - want[0]) <= tol and absf(m.dusk - want[1]) <= tol and absf(m.night - want[2]) <= tol and absf(m.dawn - want[3]) <= tol


func _say(m: Dictionary) -> String:
	return "%.1f/%.1f/%.1f/%.1f" % [m.day, m.dusk, m.night, m.dawn]


func _sun_noon(lat_deg: float, yd: float) -> float:
	SkySystem.one_clock_lat = deg_to_rad(lat_deg)
	SkySystem.one_clock_year = true
	SkySystem.one_clock_warp = CrawlerCalendar.warp
	var days := yd - DayCycle.year_start_day()
	var best := -90.0
	for i in 200:
		var t := floorf(days) + 0.4 + 0.2 * i / 199.0
		best = maxf(best, rad_to_deg(asin(clampf(SkySystem.one_clock_sun(t, Vector3.UP, Vector3.RIGHT).y, -1.0, 1.0))))
	return best


func _run() -> void:
	var year := DayCycle.year_days()
	var tilt := rad_to_deg(DayCycle.axial_tilt())
	var ref := CrawlerCalendar.reference_deg()
	var kinds := ["hub"]
	for k in (CrawlerCalendar.C.get("winter_by_biome", {}) as Dictionary):
		kinds.append(str(k))
	# 1. One shared year: every place the same.
	var differ := []
	var d := 0.0
	while d < year:
		var days := d - DayCycle.year_start_day()
		var m0 := CrawlerCalendar.phase_minutes(days, "hub")
		for k in kinds:
			var m := CrawlerCalendar.phase_minutes(days, k)
			if not _near(m, [m0.day, m0.dusk, m0.night, m0.dawn], 0.001):
				differ.append([k, d])
		d += 5.0
	SkySystem.one_clock_warp = CrawlerCalendar.warp
	SkySystem.one_clock_year = true
	CrawlerCalendar.set_place("hub")
	var sun_h := Surface.sun_deg_at(40.37)
	CrawlerCalendar.set_place("ice")
	var sun_i := Surface.sun_deg_at(40.37)
	CrawlerCalendar.set_place("hub")
	ok(differ.is_empty() and absf(sun_h - sun_i) < 1e-4, "the hub and every realm (%s) share the phase minutes every 5th day and the sun (%.3f° at the hub, %.3f° in the ice realm); differ: %s" % [", ".join(kinds), sun_h, sun_i, str(differ.slice(0, 3))])
	# 2. The reference's 35° numbers.
	var s35 := _mins(ref, year * 0.25)
	var e35 := _mins(ref, 0.0)
	var w35 := _mins(ref, year * 0.75)
	ok(absf(ref - 35.0) < 0.001, "the one reference is 35° (calendar.reference_deg %.1f)" % ref)
	ok(_near(s35, [74.4, 18.0, 33.6, 18.0]), "June solstice %s ~ 74.4/18/33.6/18" % _say(s35))
	ok(_near(e35, [61.3, 18.0, 46.7, 18.0]), "spring equinox %s ~ 61.3/18/46.7/18 (the reference script's own at 35°; §GK.1.2's table rounds it to 60/18/48/18)" % _say(e35))
	ok(_near(w35, [50.6, 18.0, 57.4, 18.0]), "December solstice %s ~ 50.6/18/57.4/18" % _say(w35))
	# 3. Dawn and dusk every day.
	var bad := []
	for yd in int(year):
		var m := _mins(ref, float(yd))
		if absf(m.dawn - 18.0) > 0.5 or absf(m.dusk - 18.0) > 0.5:
			bad.append([yd, _say(m)])
	ok(bad.is_empty(), "dawn and dusk 18 minutes every day of the year (bad: %s)" % str(bad.slice(0, 3)))
	# 4. The sky.
	var up_s := _sun_noon(ref, year * 0.25)
	var up_w := _sun_noon(ref, year * 0.75)
	ok(absf(up_s - (90.0 - ref + tilt)) < 1.5 and absf(up_w - (90.0 - ref - tilt)) < 1.5, "the noon sun %.1f° up in June, %.1f° in December (want %.1f, %.1f)" % [up_s, up_w, 90.0 - ref + tilt, 90.0 - ref - tilt])
	var same_below := true
	for i in 24:
		var t := 40.0 + i / 24.0
		if absf(Vents.sun_deg(t) - Surface.sun_deg_at(t)) > 1e-4:
			same_below = false
	ok(same_below, "the shafts' daylight reads the same sun as the surfaces, hour by hour")
	SkySystem.one_clock_lat = 0.0
	SkySystem.one_clock_year = false
	SkySystem.one_clock_warp = Callable()
	# 5. The seasons in order.
	var order := []
	var t := 0.0
	while t <= year + 0.01:
		var nm := str(CrawlerCalendar.season(t - DayCycle.year_start_day() + 0.0, "temperate").name)
		if order.is_empty() or order[-1] != nm:
			order.append(nm)
		t += 1.0
	ok(order.slice(0, 5) == ["spring", "summer", "autumn", "winter", "spring"] or order.slice(0, 6) == ["winter", "spring", "summer", "autumn", "winter", "spring"], "a year runs %s" % str(order))
	var first := str(CrawlerCalendar.season(1.0 - DayCycle.year_start_day() + Seasons._num("calendar", "lag_days", 20.0)).name)
	var again := str(CrawlerCalendar.season(1.0 - DayCycle.year_start_day() + Seasons._num("calendar", "lag_days", 20.0) + year).name)
	ok(first == again and first == "spring", "spring again after %d days (%s, %s)" % [int(year), first, again])
	# 6. Winter by biome.
	ok(not CrawlerCalendar.drops_leaves("hub") and CrawlerCalendar.drops_leaves("temperate") and CrawlerCalendar.drops_leaves("cold") and not CrawlerCalendar.drops_leaves("desert") and not CrawlerCalendar.drops_leaves("tropical"), "leaves drop in temperate and cold areas, kept in the hub, desert and tropics (hub winter: %s)" % CrawlerCalendar.winter_of("hub"))
	# 8. The open world's sun untouched at rest.
	var same := true
	for i in 24:
		var days := 13.62 + i / 24.0
		var hh := TAU * (DayCycle.warp(fposmod(days, 1.0), 0.0, 0.0) - 0.5)
		var old := (Vector3.UP * cos(hh) - Vector3.RIGHT * sin(hh)).normalized()
		if SkySystem.one_clock_sun(days, Vector3.UP, Vector3.RIGHT).distance_to(old) > 1e-4:
			same = false
	ok(same, "with the calendar at rest the one-clock sun is the old equator-equinox one")
	# 7. In the game.
	WorldSave.read_only = true
	Boss.pool_off = true
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while not main.on_surface and w < 3000:
		await process_frame
		w += 1
	for i in 5:
		await process_frame
	var days0 := float(main.world.get("days"))
	var yd0 := Astro.year_day(days0)
	var ph := CrawlerCalendar.phase_at(fposmod(days0, 1.0), CrawlerCalendar.lat(), CrawlerCalendar.decl(days0))
	ok(yd0 < 1.0 and ph == "dusk" and CrawlerCalendar.place == "hub", "a new game: year day %.2f, %s, on the hub" % [yd0, ph])
	# The sky's sun walks the day the clock says: sampled over the day, the
	# minutes it spends up, in the band and below match the stylised ones.
	var la := CrawlerCalendar.lat()
	var de := CrawlerCalendar.decl(days0)
	var cnt := {"day": 0, "dusk": 0, "night": 0, "dawn": 0}
	for i in 1440:
		cnt[CrawlerCalendar.phase_at(i / 1440.0, la, de)] += 1
	var stm := CrawlerCalendar.stylised(la, de)
	ok(absf(cnt.day * 0.1 - float(stm.day)) < 0.5 and absf(cnt.dusk * 0.1 - 18.0) < 0.5, "the clock's phases over a day: %s (minutes x10)" % str(cnt))
	ok(GameLog.now_text.begins_with("Spring day "), "the log's stamp says the season: \"%s\" (seasons.json lags the equinox by lag_days)" % GameLog.now_text)
	main.world.days = days0 + 40.3
	CrawlerSave.save()
	var kept := float(main.world.get("days"))
	main.queue_free()
	await process_frame
	await process_frame
	OS.set_environment("SEED", "")
	var main2: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main2)
	w = 0
	while not main2.on_surface and w < 3000:
		await process_frame
		w += 1
	var days2 := float(main2.world.get("days"))
	ok(CrawlerSave.continued and absf(days2 - kept) < 0.01, "Continue keeps the saved day and hour (%.3f -> %.3f, %s)" % [kept, days2, CrawlerCalendar.stamp(days2)])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

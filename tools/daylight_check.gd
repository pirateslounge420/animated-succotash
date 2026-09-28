extends SceneTree
## The derived day (design reconciliation Session 2 section F): axial
## tilt, sun declination, and day / dusk / night / dawn at a latitude
## through the year. Prints a table for the equator, 45 degrees and 75
## degrees at the spring equinox and both solstices (daylight hours on
## the 24-hour clock, and each phase in minutes of the 144-minute day),
## the noon elevation of the full moon at 45 N in summer and winter, and
## FAILS if:
##   - the equator on an equinox isn't the reference (phase_min),
##   - any place's phases don't add up to the whole day,
##   - 45 N summer isn't longer than 45 N winter,
##   - 75 N isn't midnight sun in June and polar night in December
##     (the sun counts as up down to -3.6 degrees, PlanetConst, so polar
##     night starts past about 70 degrees),
##   - the winter full moon at 45 N doesn't ride higher than the summer one.
##
##   ~/bin/godot --headless --path . -s tools/daylight_check.gd

var fails := 0


func _initialize() -> void:
	var total := DayCycle.day_length_min()
	var year := DayCycle.year_days()
	var dates := {"March equinox": 0.0, "June solstice": year * 0.25, "December solstice": year * 0.75}
	print("[daylight] tilt %.1f deg, year %d days, day %.0f min, twilight %.0f deg" % [rad_to_deg(DayCycle.axial_tilt()), int(year), total, DayCycle.twilight_deg()])
	print("[daylight] %-9s %-18s %6s  %7s %6s %6s %6s %6s" % ["latitude", "date", "decl", "daylt h", "day", "dusk", "night", "dawn"])
	var rows := {}
	for lat_deg in [0.0, 45.0, 75.0]:
		for date in dates:
			var decl := asin(sin(DayCycle.axial_tilt()) * sin(TAU * float(dates[date]) / year))
			var lat := deg_to_rad(lat_deg)
			var pm := DayCycle.phase_minutes_at(lat, decl)
			var dh := DayCycle.daylight_hours(lat, decl)
			rows["%d %s" % [int(lat_deg), date]] = [pm, dh]
			print("[daylight] %-9s %-18s %+5.1f°  %7.1f %6.1f %6.1f %6.1f %6.1f" % ["%d° N" % int(lat_deg), date, rad_to_deg(decl), dh, pm.day, pm.dusk, pm.night, pm.dawn])
			var sum: float = pm.day + pm.dusk + pm.night + pm.dawn
			ok(absf(sum - total) < 0.05, "%d° %s: the phases add up to the day (%.2f of %.0f min)" % [int(lat_deg), date, sum, total])
	var ref: Dictionary = DayCycle.phase_minutes()
	var eq: Dictionary = rows["0 March equinox"][0]
	ok(absf(eq.day - float(ref.day)) < 0.2 and absf(eq.night - float(ref.night)) < 0.2 and absf(eq.dawn - float(ref.dawn)) < 0.2 and absf(eq.dusk - float(ref.dusk)) < 0.2,
		"the equator on an equinox is the reference %s/%s/%s/%s" % [ref.day, ref.dusk, ref.night, ref.dawn])
	ok(rows["45 June solstice"][1] > rows["45 December solstice"][1] + 4.0, "45° N: summer days longer than winter ones")
	ok(rows["75 June solstice"][1] > 23.99 and rows["75 December solstice"][1] < 0.01, "75° N: midnight sun in June, polar night in December")
	ok(rows["0 June solstice"][0].dusk < rows["45 June solstice"][0].dusk, "twilight lingers longer away from the equator")
	# The full moon at local midnight, 45 N: highest in winter.
	var up := Vector3(0.0, sin(deg_to_rad(45.0)), cos(deg_to_rad(45.0))) # longitude 0
	var cycle := DayCycle.moon_cycle_days()
	var heights := {}
	for season in ["summer", "winter"]:
		var target := year * (0.25 if season == "summer" else 0.75)
		# The full moon nearest the solstice, at the local midnight of that day.
		var best := 0.0
		var best_d := INF
		for k in 30:
			var full := cycle * (0.5 + k)
			if absf(Astro.year_day(full) - target) < best_d:
				best_d = absf(Astro.year_day(full) - target)
				best = full
		var midnight: float = floor(best)
		var el := rad_to_deg(Astro.elevation(Astro.moon_dir(midnight), up))
		heights[season] = el
	print("[daylight] full moon at midnight, 45° N: summer %.1f°, winter %.1f° up" % [heights.summer, heights.winter])
	ok(heights.winter > heights.summer + 20.0, "winter full moons ride high, summer ones low")
	_seasons()
	print("[daylight] RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func ok(cond: bool, what: String) -> void:
	print("[daylight] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


## Seasons through the year at 45 N, 45 S and 5 N: the season every 15
## days, its temperature swing and moisture; and how long each change of
## season lasts.
func _seasons() -> void:
	var year := DayCycle.year_days()
	for lat_deg in [45.0, -45.0, 5.0]:
		var lat := deg_to_rad(lat_deg)
		var line := ""
		for i in range(0, int(year), 30):
			var d := float(i) - DayCycle.year_start_day()
			line += " %d:%s %+.0f°C x%.2f |" % [i, Seasons.label(d, lat).replace(" → ", ">"), Seasons.temp_offset_c(d, lat), Seasons.moisture_mult(d, lat)]
		print("[daylight] seasons at %+.0f°:%s" % [lat_deg, line])
	# Transition lengths and settled stretches at 45 N, by the day.
	var lat45 := deg_to_rad(45.0)
	var runs := []
	var prev := ""
	var run := 0
	for i in int(year) * 2:
		var s := Seasons.at(float(i) - DayCycle.year_start_day(), lat45)
		var kind := "settled " + String(s.name) if s.settled else "change %s>%s" % [s.name if float(s.t) < 0.5 else _prev_name(s.next), s.next if float(s.t) < 0.5 else s.next]
		if kind != prev:
			if prev != "" and i > int(year):
				runs.append([prev, run])
			prev = kind
			run = 0
		run += 1
	var ok_len := true
	var text := ""
	for r in runs:
		text += " %s %d d," % r
		if String(r[0]).begins_with("change") and absi(int(r[1]) - int(Seasons.data().calendar.transition_days)) > 1:
			ok_len = false
	print("[daylight] 45° N through the year:%s" % text)
	ok(ok_len and runs.size() >= 6, "each change of season lasts transition_days (%s)" % Seasons.data().calendar.transition_days)
	var w_s := Seasons.temp_offset_c(year * 0.25 + 20.0 - DayCycle.year_start_day(), lat45)
	var w_n := Seasons.temp_offset_c(year * 0.25 + 20.0 - DayCycle.year_start_day(), -lat45)
	ok(w_s > 5.0 and w_n < -5.0, "June: summer in the north (%+.1f °C), winter in the south (%+.1f °C)" % [w_s, w_n])
	var wet := Seasons.moisture_mult(year * 0.25 + 20.0 - DayCycle.year_start_day(), deg_to_rad(5.0))
	var dry := Seasons.moisture_mult(year * 0.75 + 20.0 - DayCycle.year_start_day(), deg_to_rad(5.0))
	ok(wet > dry * 1.5, "5° N: a wet summer (x%.2f) and a dry winter (x%.2f)" % [wet, dry])


func _prev_name(name: String) -> String:
	return Seasons.NAMES[(Seasons.NAMES.find(name) + 3) % 4]

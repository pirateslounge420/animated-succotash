extends SceneTree
## Day 1 and one clock (design 1 Oct §CG), on one world (SEED, pinned) and
## at Mike's 23:11 spawn (12.7°N, 140.1°W) on the same world's sky:
##  - a new world opens on Day 1 at §CY's dawn;
##  - Day 1 through the first day and evening, Day 2 just after the
##    clock face passes 00:00 where you stand;
##  - the HUD line, the clock face and the log's stamp agree to the minute
##    (the face read as main feeds it, where the player stands);
##  - the sky didn't move: the spawn's world.days is START_DAYS taken to
##    the dawn (§CY.1; it was the afternoon), so the first night's moon is
##    still near full;
##  - a save from before (no first_local_day) opens on Day 1 and keeps it;
##    a save that began three days earlier reads Day 4;
##  - the year (design 3 Oct §DD, hud.json calendar): day 1 reads "Day 1
##    of Year 1", day 365 "Day 365 of Year 1", day 366 "Day 1 of Year 2";
##    the log's stamp and the HUD line agree on day, year and minute at
##    three times;
##  - dread's fill under moonlight 0, 0.5 and 1 is the dark rate, halfway,
##    and the moon rate (§DD, Dread.fill_rate).
## The night frames' lumas (§DD look.json moon_nights) are rendered:
## tools/moon_nights.sh.
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/day_check.gd
## (tools/day_check.sh runs four seeds at spread longitudes.)

var fails := 0
var main: Node
var world: Node


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 10:
		await process_frame
	var camp: Vector3 = main.player.surface_dir
	print("[day] seed %d · camp at %.1f°%s %.1f°%s" % [seed_v, absf(rad_to_deg(CubeSphere.latitude(camp))), "N" if CubeSphere.latitude(camp) >= 0.0 else "S",
		absf(rad_to_deg(CubeSphere.longitude(camp))), "E" if CubeSphere.longitude(camp) >= 0.0 else "W"])
	# The log's first line, as the world opened.
	var first := GameLog.world_line()
	ok(first.contains("— day 1"), "the log's first line says day 1 (%s)" % first)
	await _place("the camp", camp, true)
	var mike := _dir(12.7, -140.1)
	await _place("Mike's 23:11 spawn", mike, false)
	# A save from before this (no first_local_day): Day 1, and kept.
	WorldSave.data.erase("first_local_day")
	main.open_clock(camp)
	ok(WorldSave.data.has("first_local_day") and int(world.local_clock(camp).x) == 1, "a save from before opens on Day 1 and keeps its first day (%s)" % str(WorldSave.data.get("first_local_day")))
	# A save that began three days before this boot's first day.
	WorldSave.data["first_local_day"] = float(world.first_local_day) - 3.0
	main.open_clock(camp)
	ok(int(world.local_clock(camp).x) == 4, "a save that began three days earlier reads %s (Day 4)" % world.clock_text(camp))
	await _calendar(camp)
	_dread_by_moon()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## A direction from latitude and longitude in degrees (the inverse of
## CubeSphere.latitude / longitude: y up, longitude atan2(x, z)).
func _dir(lat_deg: float, lon_deg: float) -> Vector3:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


## One place: open the world's clock there as a new world, walk the clock
## through the first day and evening to just past midnight.
func _place(label: String, d: Vector3, here: bool) -> void:
	WorldSave.data.erase("first_local_day")
	var before := Astro.days_at_solar_hour(World.START_DAYS, _start_h(d), CubeSphere.longitude(d), CubeSphere.latitude(d))
	main.open_clock(d)
	ok(is_equal_approx(world.days, before), "%s (%.1f°, %.1f°): the sky's clock is START_DAYS taken to the dawn (%.4f)" % [label, rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)), world.days])
	var c: Vector2 = world.local_clock(d)
	var lat := CubeSphere.latitude(d)
	var decl := Astro.declination(World.START_DAYS)
	var dawn_h := DayCycle.phase_start_hour("dawn", lat, decl)
	var into: float = fposmod(c.y - dawn_h, 24.0) / 24.0 * (world.day_length_s / 60.0)
	ok(int(c.x) == 1 and into >= 0.0 and into < 3.0, "%s: wakes on Day 1 in the first minutes of dawn (%s, %.1f real min after dawn begins)" % [label, world.clock_text(d), into])
	var day1_ok := true
	var agree_ok := true
	var steps := 0
	var last := ""
	var wrapped := ""
	var moon := -1.0
	while steps < 400:
		var h: float = world.local_clock(d).y
		var step := 1.0 / 1440.0 if h > 23.6 else 1.0 / 96.0
		world.days += step
		steps += 1
		c = world.local_clock(d)
		if moon < 0.0 and c.y >= 23.0:
			moon = Astro.moon_illumination(world.days)
		var hud := await _hud_line(d, here)
		var stamp: String = main._now_text(d)
		var face := _face(here, d)
		if not _agree(hud, stamp, face):
			agree_ok = false
			print("   %s: HUD '%s' · stamp '%s' · face %s" % [label, hud, stamp, face])
		if int(c.x) == 1:
			last = stamp
			continue
		wrapped = stamp
		break
	ok(day1_ok and last.begins_with("Y1 D1 23:"), "%s: Day 1 through the day and evening (last %s)" % [label, last])
	ok(wrapped.begins_with("Y1 D2 00:0"), "%s: Day 2 just after the face passes 00:00 (%s)" % [label, wrapped])
	ok(agree_ok, "%s: the HUD line, the clock face and the log stamp agree to the minute (%d readings)" % [label, steps])
	ok(moon > 0.9, "%s: the first night's moon %d%% lit (near full, as before)" % [label, int(round(moon * 100.0))])


func _start_h(d: Vector3) -> float:
	return world.dawn_start_hour(CubeSphere.latitude(d), Astro.declination(World.START_DAYS), world.day_length_s)


## The HUD's time line at `d`: where the player stands, the one main's
## frame wrote; elsewhere the HUD asked directly for that place.
func _hud_line(d: Vector3, here: bool) -> String:
	if here:
		main.hud._readout_timer = 0.0
		# The world's clock runs one fixed frame (--fixed-fps 60) before
		# main reads it: wind it back that much so main's frame sees `keep`.
		var keep: float = world.days
		world.days = keep - (1.0 / 60.0) / world.day_length_s
		await process_frame
		world.days = keep
	main.hud._readout_timer = 0.0
	main.hud.update_readout(world, d, 0.0, {}, false, 0.0)
	return str(main.hud._part_text["time"])


## The clock face's time ("HH:MM"): as main feeds it where the player
## stands (Readouts.clock_h), else the same clock at `d`.
func _face(here: bool, d: Vector3) -> String:
	var h: float = main.hud.readouts.clock_h if here else world.local_clock(d).y
	var m := int(floor(h * 60.0))
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


## The HUD line ("Day 1 of Year 1 · 23:05 · Night"), the log's stamp
## ("Y1 D1 23:05") and the face ("23:05") name the same day, year and
## minute.
func _agree(hud: String, stamp: String, face: String) -> bool:
	var parts := stamp.split(" ")
	if parts.size() < 3:
		return false
	var y := int(parts[0].substr(1))
	var d := int(parts[1].substr(1))
	return hud.begins_with("Day %d of Year %d · %s" % [d, y, parts[2]]) and parts[2] == face


## The year joins the day count (§DD).
func _calendar(camp: Vector3) -> void:
	var yd := int(round(DayCycle.year_days()))
	var fmt := str(Tuning.section("hud", "calendar").get("time_format", ""))
	for want in [[1, "Day 1 of Year 1"], [yd, "Day %d of Year 1" % yd], [yd + 1, "Day 1 of Year 2"], [2 * yd + 5, "Day 5 of Year 3"]]:
		var got: String = world.calendar_text(fmt, int(want[0]), 12.0)
		ok(got == want[1], "day count %d reads '%s' (want '%s')" % [want[0], got, want[1]])
	# Three times on the world's clock: the stamp and the HUD agree.
	var base: float = world.days
	var all_ok := true
	var seen: Array = []
	for add in [0.0, 0.37, float(yd) + 0.81]:
		world.days = base + add
		var hud := await _hud_line(camp, true)
		var stamp: String = main._now_text(camp)
		var face := _face(true, camp)
		seen.append("%s | %s" % [stamp, hud])
		all_ok = all_ok and _agree(hud, stamp, face)
	world.days = base
	ok(all_ok and str(seen[2]).contains("of Year 2"), "the log stamp and the HUD agree at three times, one a year on (%s)" % "; ".join(seen))


## Dread's fill follows the moonlight between the dark and moon rates (§DD).
func _dread_by_moon() -> void:
	var dark := float(Dread.M.get("fill_per_min_dark", 0.2))
	var moon := float(Dread.M.get("fill_per_min_moon", 0.14))
	var r0 := Dread.fill_rate(0.0)
	var r5 := Dread.fill_rate(0.5)
	var r1 := Dread.fill_rate(1.0)
	ok(is_equal_approx(r0, dark) and is_equal_approx(r5, (dark + moon) * 0.5) and is_equal_approx(r1, moon),
		"dread's fill at moonlight 0 / 0.5 / 1: %.3f / %.3f / %.3f per min (dark %.3f, moon %.3f)" % [r0, r5, r1, dark, moon])

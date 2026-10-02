extends SceneTree
## Day 1 and one clock (design 1 Oct §CG), on one world (SEED, pinned) and
## at Mike's 23:11 spawn (12.7°N, 140.1°W) on the same world's sky:
##  - a new world opens on Day 1 in §BX's afternoon;
##  - Day 1 through the first afternoon and evening, Day 2 just after the
##    clock face passes 00:00 where you stand;
##  - the HUD line, the clock face and the log's stamp agree to the minute
##    (the face read as main feeds it, where the player stands);
##  - the sky didn't move: the spawn's world.days is START_DAYS taken to
##    the afternoon as before, so the first night's moon is unchanged;
##  - a save from before (no first_local_day) opens on Day 1 and keeps it;
##    a save that began three days earlier reads Day 4.
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
	var first := str(GameLog.entries[0].get("text", "")) if not GameLog.entries.is_empty() else ""
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
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## A direction from latitude and longitude in degrees (the inverse of
## CubeSphere.latitude / longitude: y up, longitude atan2(x, z)).
func _dir(lat_deg: float, lon_deg: float) -> Vector3:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))


## One place: open the world's clock there as a new world, walk the clock
## through the first afternoon and evening to just past midnight.
func _place(label: String, d: Vector3, here: bool) -> void:
	WorldSave.data.erase("first_local_day")
	var before := Astro.days_at_solar_hour(World.START_DAYS, _start_h(d), CubeSphere.longitude(d), CubeSphere.latitude(d))
	main.open_clock(d)
	ok(is_equal_approx(world.days, before), "%s (%.1f°, %.1f°): the sky's clock is START_DAYS taken to the afternoon, as before (%.4f)" % [label, rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d)), world.days])
	var c: Vector2 = world.local_clock(d)
	ok(int(c.x) == 1 and c.y > 12.0 and c.y < 19.0, "%s: wakes on Day 1 in the afternoon (%s)" % [label, world.clock_text(d)])
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
		var hm := stamp.substr(stamp.find("·") + 2, 5)
		if hud.begins_with(stamp) == false or face != hm:
			agree_ok = false
			print("   %s: HUD '%s' · stamp '%s' · face %s" % [label, hud, stamp, face])
		if int(c.x) == 1:
			last = stamp
			continue
		wrapped = stamp
		break
	ok(day1_ok and last.begins_with("Day 1 · 23:"), "%s: Day 1 through the afternoon and evening (last %s)" % [label, last])
	ok(wrapped.begins_with("Day 2 · 00:0"), "%s: Day 2 just after the face passes 00:00 (%s)" % [label, wrapped])
	ok(agree_ok, "%s: the HUD line, the clock face and the log stamp agree to the minute (%d readings)" % [label, steps])
	ok(moon > 0.9, "%s: the first night's moon %d%% lit (near full, as before)" % [label, int(round(moon * 100.0))])


func _start_h(d: Vector3) -> float:
	var lat := CubeSphere.latitude(d)
	var dusk_h := DayCycle.phase_start_hour("dusk", lat, Astro.declination(World.START_DAYS))
	var rule: Dictionary = Tuning.section("roads", "opening_road").get("spawn", {})
	return fposmod(dusk_h - float(rule.get("real_min_before_dusk", 22.0)) / (world.day_length_s / 60.0) * 24.0, 24.0)


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

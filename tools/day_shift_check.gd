extends SceneTree
## The world getting ready at dawn and dusk (design §GF; queue 115;
## DayShift, data/day_shift.json), headless:
##   godot --headless --path . --script tools/day_shift_check.gd
## Asserts:
##  1. keyed to the sun: over a fast-forwarded day at the hub, a 40° area
##     (temperate) and a 62° one (ice), an actor's evening and morning
##     changes fall inside the day_shift sun windows; at 62° the dusk
##     change comes at a different clock hour in summer and winter (so not
##     a clock hour);
##  2. in the game (SEED=7), the hub driven through a dusk and a dawn in
##     fast-forward:
##     - at noon day flowers open and night bloomers shut, the birds out
##       and every bat in the stair mouth, every folk light out, the
##       hearth banked; at midnight the reverse, the hearth built up;
##     - in the twilight both shifts are out at once (birds and bats);
##     - every folk light comes on through the dusk, each in its own
##       moment (no two within per_light_gap_s), the candles after the
##       torches and lamps; every keeper walks a round and sits again;
##       at dawn all go out;
##     - the ground life: by its shift (none of a day shift about at
##       midnight);
##  3. nothing underground: down the stair the dungeon has no DayShift
##     and the camp's routines stop;
##  4. Continue keeps the state: a game saved at midnight opens with its
##     lights lit and its bats out.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## The clock hour (0-24) of the evening change (share crossing 0.5,
## sinking) for an actor with no offset at `kind` on year day `yd`, and
## the sun's height then.
func _evening(kind: String, yd: float) -> Vector2:
	CrawlerCalendar.set_place(kind)
	var base := floorf(yd - DayCycle.year_start_day())
	var prev := 0.0
	for i in range(0, 2881):
		var t := base + i / 2880.0
		var s := Surface.sun_deg_at(t)
		var up := Surface.sun_deg_at(t + 0.002) > s
		var sh := DayShift.share_at(s, 0.0, up)
		if not up and prev < 0.5 and sh >= 0.5:
			return Vector2(fposmod(t, 1.0) * 24.0, s)
		prev = sh
	return Vector2(-1, 0)


func _morning(kind: String, yd: float) -> Vector2:
	CrawlerCalendar.set_place(kind)
	var base := floorf(yd - DayCycle.year_start_day())
	var prev := 1.0
	for i in range(0, 2881):
		var t := base + i / 2880.0
		var s := Surface.sun_deg_at(t)
		var up := Surface.sun_deg_at(t + 0.002) > s
		var sh := DayShift.share_at(s, 0.0, up)
		if up and prev >= 0.5 and sh < 0.5:
			return Vector2(fposmod(t, 1.0) * 24.0, s)
		prev = sh
	return Vector2(-1, 0)


## The world's days on `base`'s day when the hub's sun is at `deg`,
## going down (or up).
func _when(base: float, deg: float, down: bool) -> float:
	for i in range(0, 2881):
		var t := floorf(base) + i / 2880.0
		var s := Surface.sun_deg_at(t)
		var s2 := Surface.sun_deg_at(t + 1.0 / 2880.0)
		if (down and s >= deg and s2 < deg) or (not down and s <= deg and s2 > deg):
			return t
	return base


func _run() -> void:
	var S: Dictionary = DayShift.D.get("sun_deg", {})
	var lo := float(S.get("dusk_end", -8.0))
	var hi := float(S.get("dusk_start", 4.0))
	# 1.
	for kind in ["hub", "temperate", "ice"]:
		for yd in [0.0, 91.25, 273.75]:
			var e := _evening(kind, yd)
			var m := _morning(kind, yd)
			ok(e.x >= 0.0 and e.y <= hi and e.y >= lo and m.x >= 0.0 and m.y <= hi and m.y >= lo, "%s, year day %.0f: dusk change at %.2f h (sun %.1f°), dawn at %.2f h (sun %.1f°), both inside %.0f..%.0f°" % [kind, yd, e.x, e.y, m.x, m.y, lo, hi])
	var e62s := _evening("ice", 91.25)
	var e62w := _evening("ice", 273.75)
	ok(absf(e62s.x - e62w.x) > 0.5, "62°: the dusk change at %.2f h in summer, %.2f h in winter: the sun, not the clock" % [e62s.x, e62w.x])
	# 2. In the game.
	WorldSave.read_only = true
	Boss.pool_off = true
	OS.set_environment("SEED", "7")
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while not main.on_surface and w < 3000:
		await process_frame
		w += 1
	await process_frame
	var hub := main.surface as HubCamp
	var ds := hub.day_shift
	ok(ds != null and ds.lights.size() >= 1 + 5 * 2 + 3, "the hub's routines: %d folk lights (hearth, 5 torches, 5 lamps, 3 candles)" % (ds.lights.size() if ds != null else 0))
	ds.set_process(false)
	main.set_process(false)
	var day0 := floorf(float(main.world.get("days"))) + 1.0
	# Noon.
	main.world.days = day0 + 0.5
	ds.settle_now()
	for i in 600:
		ds.tick(0.5)
	var dl := ds.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit))
	ok(ds.bloom_open("day") > 0.95 and ds.bloom_open("night") < 0.05 and ds.birds_out() == ds._birds.size() and ds.bats_out() == 0 and dl.is_empty() and ds._hearth_k < 0.5,
		"noon: day flowers open %.2f, night bloomers %.2f, birds out %d/%d, bats out %d, lights lit %d, hearth %.2f" % [ds.bloom_open("day"), ds.bloom_open("night"), ds.birds_out(), ds._birds.size(), ds.bats_out(), dl.size(), ds._hearth_k])
	var day_up := hub.life.animals.filter(func(a): return DayShift.shift_of(a.sp) == "day")
	print("  ground life at the hub: %s" % str(hub.life.animals.map(func(a): return "%s:%s" % [a.sp.name, DayShift.shift_of(a.sp)])))
	# Through the dusk, in real time steps on the world's clock.
	var t0 := _when(day0, hi + 4.0, true)
	var t1 := _when(day0, lo - 4.0, true)
	main.world.days = t0
	var step := 0.25
	var per_day := float(main.world.get("day_length_s"))
	var both := false
	ds.lit_log.clear()
	while float(main.world.get("days")) < t1 + 600.0 / per_day:
		main.world.days = float(main.world.get("days")) + step / per_day
		ds.tick(step)
		if ds.birds_out() > 0 and ds.bats_out() > 0:
			both = true
	ok(both, "the twilight: birds and bats out at once")
	var on := ds.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit))
	ok(on.size() == ds.lights.size() - 1, "after dusk every folk light is lit (%d of %d)" % [on.size(), ds.lights.size() - 1])
	var gap := float((DayShift.D.get("folk_lights", {}) as Dictionary).get("per_light_gap_s", 8.0))
	var tight := []
	for i in range(1, ds.lit_log.size()):
		if float(ds.lit_log[i][0]) - float(ds.lit_log[i - 1][0]) < gap - 0.01:
			tight.append([ds.lit_log[i - 1], ds.lit_log[i]])
	ok(tight.is_empty() and ds.lit_log.size() == on.size(), "one at a time, at least %.0f s apart: %s" % [gap, str(ds.lit_log.map(func(e): return "%.0fs %s" % [e[0], e[1]]))])
	var cand := ds.lit_log.filter(func(e): return str(e[1]).begins_with("candle"))
	var last_tl := ds.lit_log.filter(func(e): return not str(e[1]).begins_with("candle"))
	ok(not cand.is_empty() and float(cand[0][0]) > float(last_tl[-1][0]), "the candles last, after the torches and lamps")
	var sitting := ds._rounds.values().filter(func(r): return not bool(r.walking))
	var walked := ds._rounds.values().filter(func(r): return (r.motion as FolkMotion).walked > 3.0)
	ok(sitting.size() == ds._rounds.size() and walked.size() == ds._rounds.size(), "every keeper walked a round (%s m over %s rounds, the whole run) and sat again" % [str(ds._rounds.values().map(func(r): return snappedf((r.motion as FolkMotion).walked, 0.1))), str(ds._rounds.values().map(func(r): return int(r.get("rounds", 0))))])
	# Midnight.
	main.world.days = day0 + 1.0
	for i in 400:
		main.world.days = float(main.world.get("days")) + 0.5 / per_day
		ds.tick(0.5)
	ok(ds.bloom_open("night") > 0.95 and ds.bloom_open("day") < 0.05 and ds.birds_out() == 0 and ds.bats_out() == ds._bats.size() and ds._hearth_k > 0.95,
		"midnight: night bloomers open %.2f, day flowers %.2f, birds out %d, bats out %d/%d, hearth %.2f" % [ds.bloom_open("night"), ds.bloom_open("day"), ds.birds_out(), ds.bats_out(), ds._bats.size(), ds._hearth_k])
	var day_vis := hub.life.animals.filter(func(a): return DayShift.shift_of(a.sp) == "day" and (a.root as Node3D).visible)
	hub.life._process(0.1)
	day_vis = hub.life.animals.filter(func(a): return DayShift.shift_of(a.sp) == "day" and (a.root as Node3D).visible and str(a.state) != "to_cover")
	ok(day_vis.is_empty(), "midnight: no day-shift ground creature about (%d of %d asleep in cover or going)" % [day_up.size() - day_vis.size(), day_up.size()])
	# Save at midnight (lights lit), for Continue.
	CrawlerSave.save()
	# Dawn.
	var d0 := _when(day0 + 1.0, lo - 4.0, false)
	var d1 := _when(day0 + 1.0, hi + 4.0, false)
	var lit_mid := ds.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit)).size()
	main.world.days = d0
	while float(main.world.get("days")) < d1 + 600.0 / per_day:
		main.world.days = float(main.world.get("days")) + step / per_day
		ds.tick(step)
	var still := ds.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit))
	ok(lit_mid == ds.lights.size() - 1 and still.is_empty() and ds._hearth_k < 0.5, "dawn: all %d lights put out, the hearth banked (%.2f)" % [lit_mid, ds._hearth_k])
	# 3. Underground.
	main.world.days = day0 + 1.0
	await main.go_down()
	var under := main.find_children("*", "DayShift", true, false).filter(func(n): return (n as Node).is_inside_tree())
	ok(under.is_empty() and not hub.is_inside_tree(), "underground: no routine runs (the camp out of the tree, no DayShift below)")
	# 4. Continue.
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
	for i in 3:
		await process_frame
	var ds2 := (main2.surface as HubCamp).day_shift
	var lit2 := ds2.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit)).size()
	ok(CrawlerSave.continued and lit2 == ds2.lights.size() - 1 and ds2.bats_out() > 0, "Continue at midnight: %d of %d lights lit, %d bats out" % [lit2, ds2.lights.size() - 1, ds2.bats_out()])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

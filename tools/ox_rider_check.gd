extends SceneTree
## The old man on his ox (design 3 Oct §DQ, uniques.json
## road_regulars.ox_rider, OxRider), headless:
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/ox_rider_check.gd
##  - exactly one rider, on a great range's road over its pass;
##  - over ten simulated days his place advances along the road toward
##    the pass and stops at dusk (still overnight);
##  - the ox's pace is under the walk;
##  - the hood turns for a passing player and the body never breaks stride;
##  - the dark never hunts him;
##  - the gate camp stands at the pass with a lit hearth;
##  - with no tome text, no tome lies there (and with a test text, one does).

const TEST_FILE := "user://tao_test.txt"

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
	var map: PlanetData = world.planet
	var r := OxRider.road(map, main.chunks.rivers, main.chunks.roads)
	var orr: OxRider = main.ox_rider
	print("   the plan: %s; tried (range, elev m, routed, a dip): %s in %.1f s" % [str(OxRider.report.get("passes", 0)) + " crossings", str(OxRider.report.get("tried", [])), float(OxRider.report.get("s", 0.0))])
	ok(not r.is_empty() and OxRider.instance == orr, "one rider on this world (one OxRider, his road routed)")
	if r.is_empty():
		print("RESULT fails: %d" % fails)
		quit(1)
		return
	var g: Dictionary = map.terrain.great_ranges[int(r.range)]
	var pd: Vector3 = r.pass
	var rel := pd - (g.center as Vector3) * pd.dot(g.center)
	var across := absf(rel.dot(g.side)) * PlanetConst.RADIUS_M
	var hi := 0.0
	for leg in r.legs:
		for p in (leg.pts as PackedVector3Array):
			hi = maxf(hi, map.terrain.elevation(p, true))
	print("   range %d (summit %.0f m): the pass AT=%.3f,%.3f at %.0f m, %.0f m off the crest line; the road %.0f + %.0f m, its highest point %.0f m" % [int(r.range), float(g.summit_target_m), rad_to_deg(CubeSphere.latitude(pd)), rad_to_deg(CubeSphere.longitude(pd)), float(r.pass_m), across, float(r.len[0]), float(r.len[1]), hi])
	ok(across < 60.0 and float(r.pass_m) > 60.0, "his road crosses a great range at its pass (on the crest, %.0f m up)" % float(r.pass_m))
	var west_t := -CubeSphere.east(pd)
	var heading := ((r.west as Vector3) - (r.east as Vector3))
	ok(heading.dot(west_t) > 0.0, "he rides westward over it")
	ok(main.chunks.roads.links.any(func(l): return str(l.get("own", "")).begins_with("ox:")), "his road is on the network (its tread drawn like any)")
	# --- Ten days. ---
	var lon := CubeSphere.longitude(pd)
	var lat := CubeSphere.latitude(pd)
	var day0 := int(floorf(float(world.START_DAYS) + lon / TAU))
	var hours := [6.0, 9.0, 12.0, 15.0, 17.4, 18.5, 22.0]
	var mono := true
	var still := true
	var toward := true
	var crossings := {}
	var prev_m := -1.0
	var prev_cross := -1
	var per_day: Array = []
	var mps := 0.0
	for k in 10:
		var ms: Array = []
		for h in hours:
			var t := Astro.days_at_solar_hour(float(day0 + k), h, lon, lat)
			var w := OxRider.where(world, t)
			ms.append(float(w.m))
			mps = maxf(mps, float(w.mps))
			crossings[int(w.crossing)] = true
			if int(w.crossing) == prev_cross and float(w.m) < prev_m - 0.01:
				mono = false
			if h >= 17.5 and str(w.state) != "stop":
				still = false
			if int(w.crossing) == prev_cross and float(w.m) <= float(r.len[0]) and prev_m >= 0.0 and float(w.m) > prev_m + 1.0:
				var d_now := CubeSphere.surface_distance_m(w.dir, pd)
				var d_was := CubeSphere.surface_distance_m(OxRider.point(r, prev_m), pd)
				if d_now > d_was + 30.0:
					toward = false
			prev_m = float(w.m)
			prev_cross = int(w.crossing)
		if absf(float(ms[5]) - float(ms[6])) > 0.01 or absf(float(ms[4]) - float(ms[5])) > float(r.total) * 0.02:
			still = false
		per_day.append([snappedf(float(ms[0]), 1.0), snappedf(float(ms[4]), 1.0)])
	print("   ten days [dawn m, dusk m]: %s; %d crossing(s), %d days each" % [str(per_day), crossings.size(), int(OxRider.where(world, world.days).days_per_crossing)])
	ok(mono, "by day his place only advances along the road")
	ok(toward, "up to the pass, every step brings him nearer it")
	ok(still, "at dusk he stops where he is, and stays till dawn")
	var walk := float(PlanetPlayer.WALK_SPEED)
	ok(mps < walk and mps > 0.2, "the ox's pace %.2f m/s, under the walk (%.1f m/s)" % [mps, walk])
	# --- Pass him on the road at midday. ---
	var t_noon := Astro.days_at_solar_hour(float(day0 + 1), 12.0, lon, lat)
	world.days = t_noon
	var w0 := OxRider.where(world, world.days)
	var ahead := OxRider.point(r, minf(float(w0.m) + 9.0, float(r.total)))
	await _stand(ahead)
	for i in 30:
		await process_frame
	var rider := orr.rider_node()
	ok(rider != null and orr.figure() != null and not orr.ox_parts().is_empty(), "built near you: the ox, and the old man astride it (%s)" % ("pose " + orr.figure().pose if orr.figure() != null else "none"))
	var watched := false
	var p0: Vector3 = rider.global_position if rider != null else Vector3.ZERO
	var m0: float = OxRider.where(world, world.days).m
	for i in 150:
		await process_frame
		if orr.watching():
			watched = true
	var m1: float = OxRider.where(world, world.days).m
	var moved := rider.global_position.distance_to(p0) if rider != null else 0.0
	ok(watched, "his hood turns to you as you pass")
	ok(m1 > m0 and moved > 0.5, "and the ox never breaks stride (%.2f m on in 2.5 s)" % moved)
	# --- The dark ignores him. ---
	var dread: Dread = main.dread
	dread.force_dark = true
	var hunted := false
	for i in 120:
		await process_frame
		var q := dread.quarry(1.0 / 60.0)
		if not q.is_empty() and str(q.what) != "player" and str(q.what) != "torch" and str(q.what) != "last":
			hunted = true
	dread.force_dark = false
	ok(not hunted and bool(Dread.RULES.get("ignore_travellers", true)), "the dark never hunts him (it hunts only you)")
	# --- The gate. ---
	var gs := OxRider.gate_site(map)
	await _stand(CreatureSpawner._offset(gs.hearth, 0.3, 9.0))
	main.camps.refresh_now()
	for i in 60:
		await process_frame
	var camp: Node3D = main.camps._camps.get(OxRider.GATE_KEY)
	var lit := camp != null and Campfire.lit_near(self, camp.global_position, 6.0)
	var folk: int = (CampSim.instance.states.get(OxRider.GATE_KEY, {}).get("folk", []) as Array).size() if CampSim.instance != null else 0
	print("   the gate: %s; the keeper's camp %s, %d folk, its hearth %s" % ["built" if orr.gate_node() != null else "none", "built" if camp != null else "none", folk, "lit" if lit else "NOT lit"])
	ok(orr.gate_node() != null and camp != null and lit, "a gatehouse at the pass and the keeper's camp, its hearth lit")
	ok(folk >= 1 and folk <= 2, "one or two folk keep it (%d)" % folk)
	ok(not Tomes.ready("tao") and orr.tome_node() == null, "no tome text yet, so no tome lies there")
	var f := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	f.store_string("The Book of the Way\n---\n1.\nThe Tao that can be trodden is not the enduring and unchanging Tao.\n")
	f.close()
	Tomes.override = {"tao": {"text_file": TEST_FILE, "filled": true}}
	for i in 10:
		await process_frame
	var tome := orr.tome_node()
	ok(tome != null and str(tome.item.get("tome", "")) == "tao", "with its text in, the Book of the Way lies at the keeper's door")
	Tomes.override = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	var line := str(OxRider.E.get("log", ""))
	var n := GameLog.entries.filter(func(e): return e.text == line).size()
	ok(n == 1, "the log's line once (\"%s\")" % line)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _stand(d: Vector3) -> void:
	var off: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	world.rebase(off)
	main.player.global_position -= off
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for i in 10:
		await process_frame

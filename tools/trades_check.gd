extends SceneTree
## What a camp needs and the trades that follow (design 5 Oct §EI), headless:
##   STAMP=1 SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/trades_check.gd
## At every camp site within 12 km of the opening camp (the inhabited
## ruins and the lived-in nests), for every people, at the exchange rung
## with a maker, checks:
##  - the present trades are a subset of the people's huts.trades, in
##    trades.order, never more than show_max;
##  - a camp with no clay within reach never shows pottery;
##  - textiles never appears without cordage_basketry and leather_hide;
##  - a non-generalist trade never appears at a camp with no maker;
## and at a camp at storage over game days:
##  - at least trips_per_day water trips every game day, and the water pot
##    stands by its hearth once the first is made;
##  - a shelter patch every mend_job_days, +-1;
## and that a present trade's visible props are on its bench, the kiln
## standing only with pottery.

var fails := 0
var world
var main


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open("user://worlds")
	if dir:
		for f in dir.get_files():
			dir.remove(f)
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	for i in 120:
		await physics_frame
	print("[trades] seed %d" % seed_v)
	Workshop.instant = true
	_trades()
	_needs()
	await _visible()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _sites() -> Array:
	var out: Array = []
	var map: PlanetData = world.planet
	var camp_d: Vector3 = main.camp.site
	out.append(camp_d)
	for r in Ruins.near(map, camp_d, 12000.0):
		if Ruins.inhabited(r):
			out.append(r.dir)
	for n in Nests.near(camp_d, 12000.0):
		if str(n.get("people", "")) != "":
			out.append(n.hearth if n.has("hearth") else n.dir)
	return out


func _state(key: String, d: Vector3, pid: String, rung: int, maker: bool) -> Dictionary:
	var cs: CampSim = main.camp_sim
	var folk: Array = []
	for i in 10:
		folk.append({"sex": "m" if i % 2 == 0 else "f", "stage": "child" if i >= 8 else "adult", "born": 0.0, "role": "", "seed": i})
	folk[0].role = "headman"
	folk[1].role = "plantkeeper"
	if maker:
		folk[2].role = "maker"
	var st := cs._new_state(key, d, pid, FireStore.biome_key(world, d), hash([key]), folk, folk.size())
	st.rung = rung
	st.wood = 40.0
	return st


func _trades() -> void:
	var map: PlanetData = world.planet
	var rivers: RiverNetwork = main.chunks.rivers
	var sites := _sites()
	var order: Array = []
	for r in Trades.order():
		order.append(str(r.id))
	var show_max := int(Trades.T.get("show_max", 3))
	var bad_subset: Array = []
	var bad_order: Array = []
	var bad_max: Array = []
	var clay_bad: Array = []
	var textile_bad: Array = []
	var maker_bad: Array = []
	var no_clay := 0
	var camps := 0
	var tally := {}
	for si in sites.size():
		var d: Vector3 = sites[si]
		for pid in Peoples.ids():
			var st := _state("tr:%d:%s" % [si, pid], d, str(pid), 4, true)
			Trades.update(st, map, rivers)
			camps += 1
			var tr: Array = st.trades
			var listed: Array = (Peoples.get_people(str(pid)).get("huts", {}) as Dictionary).get("trades", [])
			for t in tr:
				tally[t] = int(tally.get(t, 0)) + 1
				if not listed.has(t):
					bad_subset.append("%s %s" % [pid, t])
			var idx: Array = tr.map(func(t): return order.find(t))
			var sorted := idx.duplicate()
			sorted.sort()
			if idx != sorted:
				bad_order.append("%s %s" % [pid, str(tr)])
			if tr.size() > show_max:
				bad_max.append("%s %d" % [pid, tr.size()])
			var facts: Dictionary = st.reach_facts
			if not bool(facts.clay):
				no_clay += 1
				if tr.has("pottery"):
					clay_bad.append(str(pid))
			if tr.has("textiles") and not (tr.has("cordage_basketry") and tr.has("leather_hide")):
				textile_bad.append(str(pid))
			# No maker: no trade that makes one.
			var st2 := _state("trn:%d:%s" % [si, pid], d, str(pid), 4, false)
			Trades.update(st2, map, rivers)
			for t in st2.trades:
				if not bool(Trades.row(str(t)).get("generalist", true)):
					maker_bad.append("%s %s" % [pid, t])
	# A place with no clay, forced, for every people that lists pottery.
	var forced := 0
	for pid in Peoples.ids():
		var listed: Array = (Peoples.get_people(str(pid)).get("huts", {}) as Dictionary).get("trades", [])
		if not listed.has("pottery"):
			continue
		var st3 := _state("trc:%s" % pid, sites[0], str(pid), 4, true)
		st3["reach_facts"] = {"fibre": true, "bark": true, "oil": true, "resin": true, "timber": true, "clay": false, "stone": true, "coast": false, "fresh": false}
		Trades.update(st3, map, rivers)
		forced += 1
		if (st3.trades as Array).has("pottery"):
			clay_bad.append("%s (forced no clay)" % pid)
	print("  %d camps at %d sites; trades shown: %s; %d had no clay in reach (+%d forced)" % [camps, sites.size(), str(tally), no_clay, forced])
	ok(bad_subset.is_empty(), "every camp's trades are its people's huts.trades %s" % str(bad_subset.slice(0, 6)))
	ok(bad_order.is_empty(), "every camp's trades come in trades.order %s" % str(bad_order.slice(0, 6)))
	ok(bad_max.is_empty(), "no camp shows more than show_max (%d) trades %s" % [show_max, str(bad_max.slice(0, 6))])
	ok(clay_bad.is_empty() and forced > 0, "no camp with no clay in reach shows pottery %s" % str(clay_bad.slice(0, 6)))
	ok(textile_bad.is_empty(), "textiles never without cordage_basketry and leather_hide %s" % str(textile_bad))
	ok(maker_bad.is_empty(), "no camp without a maker shows pottery, textiles or the lighting trade %s" % str(maker_bad.slice(0, 6)))
	ok(tally.size() >= 3, "the trades vary with the land (%d of 7 seen)" % tally.size())


## Game days at a storage camp: water trips a day, the shelter's mends.
func _needs() -> void:
	var cs: CampSim = main.camp_sim
	var d: Vector3 = main.camp.site
	var st := cs.ensure("needs:check", CreatureSpawner._offset(d, 1.0, 400.0), "river", FireStore.biome_key(world, d), 4242, 6)
	st.rung = 2
	st.food = 200.0
	st.wood = 40.0
	var per := cs.water_trips_per_day(st)
	var days: float = floor(float(world.days)) + 1.0
	var th := CampSim.tick_days()
	var per_day: Array = []
	var last_day := -999
	for k in int(45.0 / th):
		st.food = 200.0
		st.wood = 40.0
		cs._tick(st, days)
		var w: Dictionary = st.water
		if int(w.day) != last_day:
			if last_day != -999:
				per_day.append(int(w.prev))
			last_day = int(w.day)
		days += th
	# The first local day was joined part way through.
	per_day = per_day.slice(1)
	var short: Array = per_day.filter(func(n): return int(n) < int(((CampSim.SIM.needs as Dictionary).water as Dictionary).trips_per_day))
	ok(per_day.size() >= 40 and short.is_empty(), "a storage camp makes at least trips_per_day (%d; %d for its folk) water trips every game day over %d days %s" % [int(((CampSim.SIM.needs as Dictionary).water as Dictionary).trips_per_day), per, per_day.size(), str(short.slice(0, 5))])
	var md := float(((CampSim.SIM.needs as Dictionary).shelter as Dictionary).mend_job_days)
	var mends: Array = st.get("mend_days", [])
	var gaps: Array = []
	for i in range(1, mends.size()):
		gaps.append(snappedf(float(mends[i]) - float(mends[i - 1]), 0.01))
	var off: Array = gaps.filter(func(g): return absf(float(g) - md) > 1.0)
	ok(gaps.size() >= 3 and off.is_empty(), "a shelter patch lands every mend_job_days (%.0f) +-1: gaps %s, %d patches" % [md, str(gaps), int(st.get("patches", 0))])


## Built camps: the water pot by the hearth, the trades' pieces on their
## benches, the kiln only with pottery.
func _visible() -> void:
	var camps: Camps = main.camps
	var pd: Vector3 = world.dir_of(main.player.global_position)
	var built: Array = []
	var pot_bad: Array = []
	var piece_bad: Array = []
	var kiln_bad: Array = []
	var k := 0
	for pid in Peoples.ids():
		var key := "trv:%s" % pid
		var d := CreatureSpawner._offset(pd, TAU * k / Peoples.ids().size(), 70.0)
		k += 1
		var cs: CampSim = main.camp_sim
		var st := cs.ensure(key, d, str(pid), FireStore.biome_key(world, d), hash([key]), 8)
		st.rung = 4
		(st.folk as Array)[2].role = "maker"
		st.wood = 40.0
		st.erase("reach_facts")
		Trades.update(st, world.planet, main.chunks.rivers)
		st["water"] = {"day": 0, "n": 1, "prev": 2, "total": 3}
		var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + main.chunks.ground_height(d))
		var root: Node3D = camps._build(at, "tribal", hash([key, "s"]), key)
		built.append(root)
		CampNeeds.live(root, st, camps._needs_ctx(root, main.player.global_position))
		var potn: Node3D = root.get_node_or_null("WaterPot")
		if potn == null or not potn.visible or Vector2(potn.position.x, potn.position.z).length() > 4.0:
			pot_bad.append(str(pid))
		var ws: Node3D = root.get_meta("workshop") if root.has_meta("workshop") else null
		if ws == null:
			piece_bad.append("%s: no workshop" % pid)
			continue
		for b in ["soft", "hard"]:
			var want := Trades.visible_for(st, b)
			var have: Array = ((ws.get_meta("benches") as Dictionary)[b] as Node3D).get_meta("trade", [])
			if want != have:
				piece_bad.append("%s %s: %s vs %s" % [pid, b, str(want), str(have)])
		var hu := Workshop.huts(Peoples.get_people(str(pid)))
		var want_kiln := not (hu.get("kiln", []) as Array).is_empty() and (st.trades as Array).has("pottery")
		if want_kiln != ws.has_meta("kiln"):
			kiln_bad.append("%s: kiln %s, pottery %s" % [pid, str(ws.has_meta("kiln")), str((st.trades as Array).has("pottery"))])
		print("  %s: %s" % [pid, str(st.trades)])
	ok(pot_bad.is_empty(), "the water pot stands by the hearth at every camp that has made a trip %s" % str(pot_bad))
	ok(piece_bad.is_empty(), "every present trade's visible props are on its bench %s" % str(piece_bad.slice(0, 5)))
	ok(kiln_bad.is_empty(), "the kiln stands only with pottery, where the people build one %s" % str(kiln_bad))
	for r in built:
		(r as Node).queue_free()
	await process_frame

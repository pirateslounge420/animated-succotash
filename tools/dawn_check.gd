extends SceneTree
## The morning start and what came with it (Mike, 6 Nov):
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/dawn_check.gd
##  1. a new game starts at dawn: the sun just up, no keeper's torch or
##     lamp alight
##  2. the water lies below its banks, no keeper stands in it, and the
##     water's edge is dry ground beside it
##  3. holding Tab opens the options once; a tap does not; scrolling during
##     the hold keeps it the left hand's
##  4. through a dusk: every keeper's torch is dark until it has been to
##     the fire, and comes alight there
##  5. bats do not fly circles: their distance from the camp keeps changing
##     and no two take the same path

var fails := 0


func ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface or main.leaving:
		await process_frame
	await _frames(30)
	var hub := main.surface as HubCamp
	var ds: DayShift = hub.day_shift
	var view: HubWorkView = hub.work_view
	var L := hub.land
	var days := float(main.world.get("days"))
	var sun := Surface.sun_deg_at(days)
	# 1. Dawn.
	ok(sun > 0.0 and sun < 5.0 and Surface.sun_deg_at(days + 0.01) > sun, "the game starts at dawn (sun %.1f deg, rising)" % sun)
	var alight := ds.lights.filter(func(l): return str(l.kind) in ["torch", "lamp"] and bool(l.lit))
	ok(alight.is_empty() and view.torches_lit() == 0, "nothing alight in the morning (%d lights, %d torches)" % [alight.size(), view.torches_lit()])
	# 2. The water.
	var y := L.river_y
	ok(y != INF and hub.get_node_or_null("River") != null, "the hub has its water (level %.2f)" % y)
	var wet := 0
	var high := 0
	var banks := 0
	var low_bank := 0
	for i in 6000:
		var a := float(i) * 2.399963
		var q: Vector2 = L.pond + Vector2.from_angle(a) * sqrt(float(i) / 6000.0) * 70.0
		var c := L.river_cut(q)
		if c >= 0.999:
			wet += 1
			if L.height_at(q.x, q.y) > y:
				high += 1
		elif c > 0.0 and c < 0.08:
			# The rim of the water's sheet: where it would show if it floated.
			banks += 1
			if L.height_at(q.x, q.y) < y:
				low_bank += 1
	ok(wet > 100 and high < wet / 20, "the bed lies under the water (%d of %d points above it)" % [high, wet])
	ok(banks > 20 and low_bank == 0, "the ground round it stands above the water, so it never floats (%d of %d below it)" % [low_bank, banks])
	var bank_at: Vector2 = L.pond + Vector2(-L.n.y, L.n.x) * 15.0
	var pond_bank := L.height_at(bank_at.x, bank_at.y)
	ok(pond_bank - y > 0.2, "the pond lies %.2f m under its banks" % (pond_bank - y))
	var fp: Vector3 = hub.camp.pos
	var edge := hub.river_near(fp)
	ok(edge.y >= y - 0.3 and edge.y < y + 1.0 and Vector2(edge.x - fp.x, edge.z - fp.z).length() < 30.0, "the water's edge is a short walk from the fire (%.1f m)" % Vector2(edge.x - fp.x, edge.z - fp.z).length())
	ok(hub.sites.all(func(st): return L.river_cut(Vector2((st.at as Vector3).x, (st.at as Vector3).z)) < 0.5), "no keeper's site in the water")
	# 3. Tab.
	var hands: Hands = main.player.hands
	Input.action_press("other_hand")
	await _frames(6)
	Input.action_release("other_hand")
	await _frames(50)
	ok(not main.settings_panel.visible, "a tap of Tab opens nothing")
	Input.action_press("other_hand")
	await _frames(10)
	var step := InputEventAction.new()
	step.action = "hand_next"
	step.pressed = true
	hands.tab_spent = true
	await _frames(60)
	ok(not main.settings_panel.visible, "scrolling during the hold keeps Tab the left hand's")
	Input.action_release("other_hand")
	await _frames(4)
	Input.action_press("other_hand")
	await _frames(50)
	ok(main.settings_panel.visible, "holding Tab opens the options")
	Input.action_release("other_hand")
	await _frames(10)
	ok(main.settings_panel.visible, "and they stay open when you let go")
	main._toggle_settings(false)
	await _frames(4)
	# 4. Through a dusk.
	var t := days
	while not (Surface.sun_deg_at(t) > -6.0 and Surface.sun_deg_at(t + 0.0005) <= -6.0):
		t += 0.0005
	main.world.days = t
	var keepers: Array = ds._rounds.keys()
	var lit_at := {}
	var seen_dark := {}
	for i in 5000:
		await process_frame
		for k in keepers:
			var e: Dictionary = view._torch.get(k, {})
			if e.is_empty() or lit_at.has(k):
				continue
			var f: Node3D = (ds._rounds[k] as Dictionary).folk
			if (e.light as Node3D).visible:
				lit_at[k] = Vector2(f.global_position.x - fp.x, f.global_position.z - fp.z).length()
			elif (e.root as Node3D).visible:
				seen_dark[k] = true
		if lit_at.size() == view._torch.size():
			break
	ok(lit_at.size() == view._torch.size(), "every keeper's torch came alight (%d of %d)" % [lit_at.size(), view._torch.size()])
	ok(lit_at.values().all(func(d): return d < 3.0), "each at the fire (%s m)" % str(lit_at.values().map(func(d): return snappedf(d, 0.1))))
	ok(seen_dark.size() == view._torch.size(), "each carried it dark on the way (%d of %d)" % [seen_dark.size(), view._torch.size()])
	# 5. The bats, out in the dark.
	while ds.bats_out() < ds._bats.size():
		await process_frame
	await _frames(300)
	var track := {}
	for i in 900:
		await process_frame
		for b in ds._bats.slice(0, 4):
			if not track.has(b.id):
				track[b.id] = []
			(track[b.id] as Array).append(b.at)
	var all_vary := true
	var turns := 0
	var line := ""
	for id in track:
		var ps: Array = track[id]
		var rs: Array = ps.map(func(p): return Vector2((p as Vector3).x - ds._center.x, (p as Vector3).z - ds._center.z).length())
		var lo: float = rs.min()
		var hi: float = rs.max()
		line += " %.0f-%.0f" % [lo, hi]
		all_vary = all_vary and hi - lo > 6.0
		for i in range(10, ps.size() - 10, 10):
			var d1: Vector3 = ps[i] - ps[i - 10]
			var d2: Vector3 = ps[i + 10] - ps[i]
			if d1.length() > 0.1 and d2.length() > 0.1 and d1.normalized().dot(d2.normalized()) < 0.5:
				turns += 1
	ok(all_vary, "each bat's distance from the camp keeps changing (m:%s)" % line)
	ok(turns > 20, "they jink: %d sharp turns in 15 s among 4 bats (a circle has none)" % turns)
	print("RESULT fails: %d" % fails)
	print("dawn_check: %d fails" % fails)
	quit(1 if fails > 0 else 0)

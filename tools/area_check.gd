extends SceneTree
## Fire travel to the first area (design §GD.1.2-4; queue 113;
## CrawlerAreas, crawler.json areas), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/area_check.gd
## Asserts, from a new game (SEED=7):
##  1. not linked yet; at the hub fire the interact button takes you (the
##     cook-shaman's stand-in) to the first area: on its surface, beside its
##     main hearth, the hearth cold, a lit brand in your hand; the area
##     sized from areas.first.across_m;
##  2. the cold hearth brings you home this session (never stranded);
##  3. back again, your torch's flame held to the hearth lights it: the
##     hearth burns, the link is in the save;
##  4. the ruin's mouth: down the area's stair into the first ruin, and its
##     way out brings you back up onto the area's surface by the mouth;
##  5. hub -> area -> hub by the linked fire, with no errors;
##  6. Continue keeps the link: the next session's hub fire takes you to
##     the area, its hearth already burning.

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(main: CrawlerMain) -> void:
	var w := 0
	while main.leaving and w < 2000:
		await process_frame
		w += 1
	await _frames(5)


func _boot(seed_env: String) -> CrawlerMain:
	OS.set_environment("SEED", seed_env)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	var w := 0
	while (not main.on_surface or main.leaving) and w < 3000:
		await process_frame
		w += 1
	await _frames(5)
	return main


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	var main := await _boot("7")
	main.player.set_physics_process(false)
	var hub := main.surface as HubCamp
	ok(hub != null and not CrawlerAreas.linked() and main.areas.can_go(), "a new game: on the hub, the first area not linked, the shaman's stand-in open")
	# 1. Through the fire.
	ok(main.areas.interact(), "the interact button at the hub fire takes it")
	await _settle(main)
	var area := main.surface
	ok(main.on_surface and area != null and not (area is HubCamp) and area == main.area_node, "you step out in the first area")
	var hp := area.area_hearth.global_position
	var pp := main.player.global_position
	ok(Vector2(pp.x - hp.x, pp.z - hp.z).length() < 4.0 and not area.hearth_lit(), "beside its main hearth (%.1f m), cold" % Vector2(pp.x - hp.x, pp.z - hp.z).length())
	ok(main.player.torch.lit(), "a lit brand from the hub fire in your hand")
	var ar: Array = CrawlerAreas.first().get("across_m", [300.0, 600.0])
	ok(area.across_m >= float(ar[0]) and area.across_m <= float(ar[1]) and area.land.inside(Vector2(hp.x, hp.z), 0.0), "the area %.0f m across (areas.first.across_m), the hearth on its floor, %.0f m from the middle" % [area.across_m, Vector2(hp.x, hp.z).distance_to(area.land.center)])
	# 2. Home from the cold hearth (this session's link).
	ok(main.areas.interact(), "the cold hearth's button")
	await _settle(main)
	ok(main.surface == main.hub_node, "brings you home to the hub (never stranded)")
	# 3. Back, and light it with the torch.
	main.areas.interact()
	await _settle(main)
	var t := main.player.torch
	if not t.lit():
		t.light()
	var off := t.flame_position() - main.player.global_position
	var stand := hp + Vector3(0.0, 0.3, 0.0) - off
	stand.y = area.land.height_at(stand.x, stand.z)
	main.player.global_position = stand
	await _frames(3)
	var d := t.flame_position().distance_to(hp + Vector3(0.0, 0.3, 0.0))
	for i in 10:
		main.areas._process(0.2)
	ok(area.hearth_lit() and CrawlerAreas.linked() and bool(((CrawlerSave.data.get("areas", {}) as Dictionary).get("first", {}) as Dictionary).get("linked", false)), "the torch's flame held to it (%.2f m): the hearth burns, the link is saved" % d)
	# 4. The ruin's mouth and back.
	await main.go_down()
	await _settle(main)
	ok(not main.on_surface and main.tomb != null and main.tomb.is_inside_tree(), "down the area's ruin entrance into the first ruin")
	await main.go_up()
	await _settle(main)
	var st: Dictionary = area.stair
	pp = main.player.global_position
	ok(main.surface == area and Vector2(pp.x, pp.z).distance_to(st.mouth as Vector2) < 8.0, "the ruin's way out: back up on the area's surface by the mouth (%.1f m)" % Vector2(pp.x, pp.z).distance_to(st.mouth as Vector2))
	# 5. Linked: area -> hub -> area -> hub.
	main.player.global_position = hp + (Vector3(2.0, 0.0, 0.0))
	ok(main.areas.interact(), "at the lit hearth: home")
	await _settle(main)
	ok(main.surface == main.hub_node, "on the hub")
	ok(main.areas.interact(), "at the hub fire, linked: to the area")
	await _settle(main)
	ok(main.surface == area and area.hearth_lit(), "at the area, its hearth burning")
	main.player.global_position = hp + (Vector3(2.0, 0.0, 0.0))
	main.areas.interact()
	await _settle(main)
	ok(main.surface == main.hub_node and main.areas.travels == 6, "and home again (%d crossings)" % main.areas.travels)
	CrawlerSave.save()
	# 6. Continue.
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	main2.player.set_physics_process(false)
	ok(CrawlerSave.continued and CrawlerAreas.linked() and main2.surface is HubCamp, "Continue: on the hub, the link kept")
	main2.areas.interact()
	await _settle(main2)
	ok(main2.surface == main2.area_node and main2.area_node.hearth_lit(), "and the fire takes you to the area, its hearth already burning")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

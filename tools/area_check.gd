extends SceneTree
## The shaman's song to the first realm (design §GH, queue 116; §GD.1.2-4,
## queue 113;
## CrawlerAreas, crawler.json areas), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/area_check.gd
## Asserts, from a new game (SEED=7):
##  1. not linked yet; at the hub fire the interact button takes you (the
##     cook-shaman's stand-in) to the first area: on its surface, beside its
##     main hearth, the hearth cold, the torch you carry lit by the fire; the area
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
	# Songs are learned from plants since §GK.2 (song_keys_check); here the
	# desert's is taught up front.
	SongKeys.learn(SongKeys.realm_of("cactus"))
	main.player.set_physics_process(false)
	# A torch from the firekeeper's stack in your pack (Mike, 28 Oct: the fire
	# lights a torch you carry and hands out none, TorchSupply).
	main.player.inventory.add(Inventory.make("torch"))
	var hub := main.surface as HubCamp
	var ar_ := main.areas
	ok(hub != null and ar_.can_go() and CrawlerAreas.known() == [SongKeys.realm_of("cactus")], "a new game: on the hub, the desert's song known")
	# 1. Sit; the song, its colour, its glimpse.
	ok(ar_.interact() and ar_.sitting, "the interact button at the hub fire sits you down")
	for i in 120:
		await process_frame
	var light := hub.fire.get_node_or_null("Light") as OmniLight3D
	var want := CrawlerAreas.realm_colour(SongKeys.realm_of("cactus"))
	ok(ar_.song_playing() and ar_.realm == SongKeys.realm_of("cactus"), "the shaman sings the first realm's song")
	ok(light != null and light.light_color.is_equal_approx(want), "the flames take its colour (#%s)" % want.to_html(false))
	ok(ar_.glimpse_shown() > 0.9 and main.area_node != null and main.area_node.get_parent() == ar_._glimpse_vp, "its glimpse opens in the fire (shown %.2f, the realm in its own world)" % ar_.glimpse_shown())
	ar_.scroll(1)
	await process_frame
	ok(ar_.realm == SongKeys.realm_of("cactus") and ar_.song_playing() and CrawlerAreas.known().size() == 1, "scrolling with one realm known: a list of one")
	# 2. Standing up changes nothing.
	ar_.stand()
	await _frames(3)
	ok(not ar_.sitting and main.surface == hub and not ar_.song_playing() and not light.light_color.is_equal_approx(want) and main.area_node.get_parent() == null and main.player.is_physics_processing(), "standing up: no song, the fire its own colour again, the realm put away, you free to walk")
	# 3. Sit and step in: the realm's hearth, unlit (the song is the key).
	ar_.interact()
	await _frames(10)
	ar_.interact()
	await _settle(main)
	var area := main.surface
	ok(main.on_surface and area == main.area_node and not (area is HubCamp), "stepping into the fire: you come out in the first realm")
	var hp := area.area_hearth.global_position
	var pp := main.player.global_position
	ok(Vector2(pp.x - hp.x, pp.z - hp.z).length() < 4.0 and not area.hearth_lit(), "beside its hearth (%.1f m), unlit: travel no longer waits on it" % Vector2(pp.x - hp.x, pp.z - hp.z).length())
	ok(main.player.torch.lit(), "the hub fire lights the torch you carry")
	var ar: Array = CrawlerAreas.first().get("across_m", [300.0, 600.0])
	ok(area.across_m >= float(ar[0]) and area.across_m <= float(ar[1]), "the realm %.0f m across (areas.first.across_m)" % area.across_m)
	# 4. Home by its (unlit) hearth.
	ok(ar_.interact(), "the hearth's button")
	await _settle(main)
	ok(main.surface == main.hub_node, "brings you home to the hub fire")
	# 5. Back, and reclaim it with the torch.
	ar_.interact()
	await _frames(5)
	ar_.interact()
	await _settle(main)
	var t := main.player.torch
	if not t.lit():
		t.light()
	var off := t.flame_position() - main.player.global_position
	var stand := hp + Vector3(0.0, 0.3, 0.0) - off
	stand.y = area.land.height_at(stand.x, stand.z)
	main.player.global_position = stand
	await _frames(3)
	for i in 10:
		ar_._process(0.2)
	ok(area.hearth_lit() and CrawlerAreas.linked(), "your torch held to it: the hearth burns, reclaimed and saved")
	# 6. The ruin's mouth and back.
	await main.go_down()
	await _settle(main)
	ok(not main.on_surface and main.tomb != null and main.tomb.is_inside_tree(), "down the realm's ruin entrance into the first ruin")
	await main.go_up()
	await _settle(main)
	var st: Dictionary = area.stair
	pp = main.player.global_position
	ok(main.surface == area and Vector2(pp.x, pp.z).distance_to(st.mouth as Vector2) < 8.0, "the ruin's way out: back up by the mouth (%.1f m)" % Vector2(pp.x, pp.z).distance_to(st.mouth as Vector2))
	main.player.global_position = hp + Vector3(2.0, 0.0, 0.0)
	ar_.interact()
	await _settle(main)
	ok(main.surface == main.hub_node and ar_.travels == 4, "and home again (%d crossings)" % ar_.travels)
	# 7. No powder.
	var lines := GameLog.entries.map(func(e): return str(e.text)).filter(func(x): return x.to_lower().contains("powder"))
	ok(not FileAccess.get_file_as_string("res://data/crawler.json").to_lower().contains("powder") and lines.is_empty(), "no powder left in the crawler's data or log")
	CrawlerSave.save()
	# 8. Continue.
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	main2.player.set_physics_process(false)
	ok(CrawlerSave.continued and CrawlerAreas.linked() and main2.surface is HubCamp, "Continue: on the hub, the realm reclaimed")
	main2.areas.interact()
	await _frames(5)
	main2.areas.interact()
	await _settle(main2)
	ok(main2.surface == main2.area_node and main2.area_node.hearth_lit(), "the song takes you there, its hearth still burning")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

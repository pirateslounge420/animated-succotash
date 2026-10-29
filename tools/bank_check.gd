extends SceneTree
## The male shaman, the song home, the bank and the pile where you fall
## (design §GI.1-2, §GJ; queue 117), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/bank_check.gd
## Asserts, from a new game (SEED=7):
##  1. the hub's shaman is male (his build, a beard), and the hub's and
##     realms' data and the log say nothing of "she" or "her";
##  2. the bank: deposit and withdraw a find;
##  3. a find carried home by the hearth song is still yours at the hub;
##  4. carry things and die in the ruin: you wake at the hub fire with
##     nothing, the bank untouched, a pile kept where you fell;
##  5. die again on the realm's surface: a second pile;
##  6. Continue: the bank and both piles kept; back by the song, each pile
##     is there and gives everything back when you walk to it.

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
	main.player.set_physics_process(false)
	return main


func _to_realm(main: CrawlerMain) -> void:
	var hub := main.hub_node as HubCamp
	var sp := hub.arrival()
	main.player.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.player.set_physics_process(false)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	await _settle(main)
	main.player.set_physics_process(false)


func _slot(inv: Inventory, kind: String) -> int:
	for k in inv.carried.size():
		if inv.carried[k] is Dictionary and str(inv.carried[k].kind) == kind:
			return k
	return -1


func _kinds(inv: Inventory) -> Array:
	var out := []
	for it in inv.carried + inv.strip:
		if it is Dictionary:
			out.append(str(it.kind))
	out.sort()
	return out


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	var main := await _boot("7")
	# Songs are learned from plants since §GK.2 (song_keys_check); here the
	# desert's is taught up front.
	SongKeys.learn(SongKeys.realm_of("cactus"))
	var hub := main.surface as HubCamp
	# 1. He.
	var cj := FileAccess.get_file_as_string("res://data/crawler.json")
	var d: Dictionary = JSON.parse_string(cj)
	var txt := (JSON.stringify(d.hub) + JSON.stringify(d.areas)).to_lower()
	var re := RegEx.create_from_string("\\\\b(she|her|herself)\\\\b")
	ok(bool(hub.shaman.get_meta("male", false)) and hub.shaman.body.head.get_node_or_null("Beard") != null, "the hub's shaman is a man (a beard under the hood)")
	ok(re.search(txt) == null, "the hub's and realms' data say nothing of she or her")
	# 2. The bank.
	var inv := main.player.inventory
	inv.add(Inventory.make("scroll"))
	var bp := hub.bank_node.global_position
	main.player.spawn_flat(bp + Vector3(1.2, 0.0, 0.0), 0.0, 0.0)
	main.player.set_physics_process(false)
	ok(main.areas.interact() and main.bank_panel.visible, "the interact button by the store opens the bank")
	var i: int = _slot(inv, "scroll")
	ok(CrawlerBank.deposit(inv, "carried", i) and CrawlerBank.items().size() == 1 and not inv.has_kind("scroll"), "deposit: the scroll into the bank")
	ok(CrawlerBank.withdraw(inv, 0) and inv.has_kind("scroll") and CrawlerBank.items().is_empty(), "withdraw: back in your pack")
	i = _slot(inv, "scroll")
	CrawlerBank.deposit(inv, "carried", i)
	main.bank_panel.close()
	# 3. A find carried home by the song.
	await _to_realm(main)
	inv.add(Inventory.make("tome"))
	# Two tome fragments from this game's ruin (Mike, 27 Oct: pages drop
	# until you get them back to the hub).
	var frags: Array = TomePages.plan(main.lay, []).map(func(d): return str(d.fragment))
	var page_a: String = frags[0] if frags.size() > 0 else ""
	# (This ruin may lay only one: a stand-in id then, as good as any to the save.)
	var page_b: String = frags[1] if frags.size() > 1 else "check_page_b"
	if page_a != "":
		TomePages.keep(page_a)
	var hp := main.area_node.area_hearth.global_position
	main.player.global_position = hp + Vector3(2.0, 0.0, 0.0)
	main.areas.interact()
	await _settle(main)
	ok(main.surface == main.hub_node and inv.has_kind("tome") and main.areas.home_songs == 1, "the hearth song carries you home, the tome still yours")
	ok(page_a == "" or (TomePages.held().has(page_a) and not TomePages.carried().has(page_a)), "a tome page carried home by the song is yours for good (%s)" % page_a)
	# 4. Carry things and die in the ruin.
	await _to_realm(main)
	inv.add(Inventory.make("fish"))
	await main.go_down()
	await _settle(main)
	# Deeper in, on the hearth room's floor (not the landing you come down to).
	var wk: Array = main.lay.wake
	main.player.global_position = wk[0]
	if page_b != "":
		TomePages.keep(page_b)
	var died_at := main.player.global_position
	var carried_before := _kinds(inv)
	main._on_taken()
	await _frames(10)
	ok(page_b == "" or (not TomePages.held().has(page_b) and TomePages.held().has(page_a) and TomePages.in_piles().has(page_b)), "the page not yet home drops in the pile (%s); the one brought home stays yours" % page_b)
	ok(main.on_surface and main.surface == main.hub_node and inv.count() == 0 and _kinds(inv).is_empty() and not main.player.torch.lit(), "taken in the ruin: you wake at the hub fire with nothing (lost %s)" % str(carried_before))
	ok(CrawlerBank.items().size() == 1 and str(CrawlerBank.items()[0].kind) == "scroll", "the bank untouched (the scroll)")
	var p1: Array = CrawlerAreas.piles()
	ok(p1.size() == 1 and str(p1[0].where) == "ruin" and Vector3(float(p1[0].pos[0]), float(p1[0].pos[1]), float(p1[0].pos[2])).distance_to(died_at) < 0.1, "one pile, where you fell in the ruin")
	# 5. Die again on the realm's surface.
	await _to_realm(main)
	inv.add(Inventory.make("herb_bundle"))
	# Away from the hearth, out on the realm's floor.
	var ar2 := main.area_node
	var h2 := ar2.area_hearth.global_position
	var out := h2 + (Vector3(ar2.land.center.x, h2.y, ar2.land.center.y) - h2).normalized() * 15.0
	out.y = ar2.land.height_at(out.x, out.z)
	main.player.global_position = out
	var died2 := main.player.global_position
	main._on_taken()
	await _frames(10)
	ok(CrawlerAreas.piles().size() == 2 and str(CrawlerAreas.piles()[1].where) == "surface" and main.surface == main.hub_node, "dying again leaves a second pile (on the realm's surface)")
	CrawlerSave.save()
	# 6. Continue.
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	var inv2 := main2.player.inventory
	ok(CrawlerSave.continued and CrawlerBank.items().size() == 1 and CrawlerAreas.piles().size() == 2, "Continue: the bank and both piles kept")
	await _to_realm(main2)
	var sp_pile: Node3D = main2.areas._pile_nodes.get(str(CrawlerAreas.piles()[1].id))
	ok(sp_pile != null and sp_pile.is_inside_tree() and sp_pile.get_node_or_null("OmniLight3D") != null or (sp_pile != null and sp_pile.is_inside_tree()), "back by the song: the pile on the surface is there, glowing")
	main2.player.global_position = sp_pile.global_position + Vector3(0.5, 0.0, 0.0)
	main2.areas._pickups()
	ok(inv2.has_kind("herb_bundle") and CrawlerAreas.piles().size() == 1, "walk to it: all of it back (%s), one pile left" % str(_kinds(inv2)))
	await main2.go_down()
	await _settle(main2)
	var r_pile: Node3D = main2.areas._pile_nodes.get(str(CrawlerAreas.piles()[0].id))
	ok(r_pile != null and r_pile.is_inside_tree(), "down in the ruin: the first pile waits where you fell")
	main2.player.global_position = r_pile.global_position + Vector3(0.4, 0.0, 0.0)
	main2.areas._pickups()
	ok(inv2.has_kind("fish") and CrawlerAreas.piles().is_empty(), "and gives it all back (%s); no piles left" % str(_kinds(inv2)))
	ok(page_b == "" or (TomePages.held().has(page_b) and TomePages.carried().has(page_b)), "the dropped page is back with you, carried until you get it home")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

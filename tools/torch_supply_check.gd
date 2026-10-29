extends SceneTree
## Torches are scarce, found or made, never resupplied (Mike, 27-28 Oct;
## TorchSupply, torch.json crawler_burn.supply), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/torch_supply_check.gd
## Asserts, from a new game (SEED=7):
##  1. the firekeeper's stack at his site holds hub.start torches; the
##     interact button there takes one; days later it has not filled again;
##  2. with no torch of your own the song gives you none;
##  3. the realm has its caches, branches and resin, away from its hearth;
##     each taken is gone, and days later is still gone;
##  4. with a branch and resin, at the firekeeper's empty stack, the
##     interact button binds a torch and uses them up; with nothing to bind
##     it does nothing;
##  5. the ruin's bundle is laid once: what you took stays taken, and
##     Continue keeps it, the stack and the realm's finds.

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


func _torches(inv: Inventory) -> int:
	return Torch.carried_count(inv)


func _drop_torches(main: CrawlerMain) -> void:
	var inv := main.player.inventory
	if main.player.torch.lit():
		main.player.torch.put_out("check")
	for k in inv.carried.size():
		if inv.carried[k] is Dictionary and str(inv.carried[k].kind) == "torch":
			inv.carried[k] = null


func _take_all(main: CrawlerMain, s: Dictionary) -> int:
	var ts := main.torch_supply
	main.player.global_position = (s.node as Node3D).global_position + Vector3(0.6, 0.0, 0.0)
	var n := 0
	while ts.left_of(s) > 0 and n < 10:
		ts.take()
		n += 1
	return n


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	var S := TorchSupply.S
	var H: Dictionary = S.get("hub", {})
	var main := await _boot("7")
	# Songs are learned from plants since §GK.2 (song_keys_check); here the
	# desert's is taught up front.
	SongKeys.learn(SongKeys.realm_of("cactus"))
	var ts := main.torch_supply
	var hub := main.hub_node as HubCamp
	var inv := main.player.inventory
	await _frames(3)
	# 1. The firekeeper's stack.
	var stack: Dictionary = {}
	for s in ts._stacks:
		if str(s.kind) == "hub":
			stack = s
	var site_at := Vector3.INF
	for site in hub.sites:
		if str(site.keeper) == str(H.get("keeper")):
			site_at = site.at
	ok(not stack.is_empty() and (stack.node as Node3D).global_position.distance_to(site_at) < 3.0, "the firekeeper's stack lies at his site")
	var start := int(H.get("start", 3))
	ok(ts.left_of(stack) == start, "a new game finds %d torches in it" % ts.left_of(stack))
	_drop_torches(main)
	main.player.global_position = (stack.node as Node3D).global_position + Vector3(0.8, 0.0, 0.0)
	ok(ts.take() and _torches(inv) == 1 and ts.left_of(stack) == start - 1, "the interact button there takes one")
	var d0 := float(main.world.get("days"))
	main.world.days = d0 + 5.2
	await _frames(2)
	ok(ts.left_of(stack) == start - 1, "five days on it has not filled again (%d)" % ts.left_of(stack))
	# 2. No free brand.
	_drop_torches(main)
	var sp := hub.arrival()
	main.player.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.player.set_physics_process(false)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	await _settle(main)
	main.player.set_physics_process(false)
	ok(main.surface == main.area_node and not main.player.torch.lit() and _torches(inv) == 0, "with no torch of your own the song gives you none")
	# 3. The realm's finds.
	await _frames(3)
	var hp := main.area_node.area_hearth.global_position
	var all_ok := true
	var by := {}
	for kind in TorchSupply.KINDS:
		var F := TorchSupply.find_data(kind)
		var list := ts._stacks.filter(func(s): return str(s.where) == "first" and str(s.kind) == kind)
		by[kind] = list
		var far := list.all(func(s): return Vector2((s.node as Node3D).global_position.x - hp.x, (s.node as Node3D).global_position.z - hp.z).length() >= float(F.get("from_hearth_m", 20.0)) - 0.1)
		all_ok = all_ok and list.size() == int(F.get("count", 1)) and far
	ok(all_ok, "the realm has its finds, away from its hearth (%s)" % str(TorchSupply.KINDS.map(func(k): return "%d %s" % [(by[k] as Array).size(), k])))
	var n_cache := _take_all(main, by.cache[0])
	ok(n_cache >= 1 and ts.left_of(by.cache[0]) == 0 and _torches(inv) == n_cache, "a cache's %d torch(es) taken, it is empty" % n_cache)
	_drop_torches(main)
	_take_all(main, by.branch[0])
	_take_all(main, by.resin[0])
	ok(TorchSupply.carried_of(inv, "branch") == 1 and TorchSupply.carried_of(inv, "resin") >= 1, "a dry branch and resin picked up (%d, %d)" % [TorchSupply.carried_of(inv, "branch"), TorchSupply.carried_of(inv, "resin")])
	var t0 := float(main.world.get("days"))
	main.world.days = t0 + 10.0
	ok(ts.left_of(by.cache[0]) == 0 and ts.left_of(by.branch[0]) == 0 and ts.left_of(by.resin[0]) == 0, "ten days on, nothing taken has come back")
	# 4. Bind a torch at the firekeeper's site.
	var hpos := main.area_node.area_hearth.global_position
	main.player.global_position = hpos + Vector3(2.0, 0.0, 0.0)
	main.player.torch.light("check")
	main.areas.interact()
	await _settle(main)
	main.player.set_physics_process(false)
	_drop_torches(main)
	for s in ts._stacks:
		if str(s.kind) == "hub":
			stack = s
	_take_all(main, stack)
	_drop_torches(main)
	var res0 := TorchSupply.carried_of(inv, "resin")
	main.player.global_position = (stack.node as Node3D).global_position + Vector3(0.8, 0.0, 0.0)
	ok(ts.left_of(stack) == 0 and ts.take() and _torches(inv) == 1 and TorchSupply.carried_of(inv, "branch") == 0 and TorchSupply.carried_of(inv, "resin") == res0 - 1, "at the firekeeper's empty stack a branch and resin are bound into a torch")
	ok(not ts.take() and _torches(inv) == 1, "with no branch left, nothing to bind")
	# 5. The ruin's bundle.
	var sp2 := hub.arrival()
	main.player.spawn_flat(sp2.pos, float(sp2.yaw), 0.0)
	main.player.set_physics_process(false)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	await _settle(main)
	await main.go_down()
	await _settle(main)
	main.player.set_physics_process(false)
	_drop_torches(main)
	var full := main.fires.bundle_left
	main.player.global_position = main.fires.bundle.global_position + Vector3(0.5, 0.0, 0.0)
	main.take_torch()
	ok(main.fires.bundle_left == full - 1, "one from the ruin's bundle (%d left)" % main.fires.bundle_left)
	CrawlerSave.save()
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	ok(CrawlerSave.continued and main2.fires.bundle_left == full - 1, "Continue: the ruin's bundle as you left it (%d), never laid again" % main2.fires.bundle_left)
	var cl: Array = TorchSupply.finds("first", "cache")
	ok(int(TorchSupply.hub_stack().left) == 0 and int(cl[0].left) == 0, "and the firekeeper's stack and the emptied cache still empty")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

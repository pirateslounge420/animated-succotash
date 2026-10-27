extends SceneTree
## Torches are scarce (Mike, 27 Oct; TorchSupply, torch.json
## crawler_burn.supply), headless:
##   godot --headless --path . --fixed-fps 60 --script tools/torch_supply_check.gd
## Asserts, from a new game (SEED=7):
##  1. the firekeeper's stack at his site holds start torches; the interact
##     button there takes one; a day on, he has bound per_day more, never past
##     max;
##  2. with no torch of your own the song's brand is short (brand_burn_min);
##  3. the realm has its caches, away from its hearth; one emptied fills
##     again restock_days later, not before;
##  4. the ruin's bundle is laid once: what you took stays taken, and
##     Continue keeps it and the stack.

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


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	var S := TorchSupply.S
	var H: Dictionary = S.get("hub", {})
	var main := await _boot("7")
	var ts := main.torch_supply
	var hub := main.hub_node as HubCamp
	await _frames(3)
	# 1. The firekeeper's stack.
	var stack: Dictionary = {}
	for s in ts._stacks:
		if str(s.where) == "hub":
			stack = s
	var site_at := Vector3.INF
	for site in hub.sites:
		if str(site.keeper) == str(H.get("keeper")):
			site_at = site.at
	ok(not stack.is_empty() and (stack.node as Node3D).global_position.distance_to(site_at) < 3.0, "the firekeeper's stack lies at his site")
	ok(ts.left_of(stack) == int(H.get("start", 2)), "a new game finds %d torches in it" % ts.left_of(stack))
	_drop_torches(main)
	main.player.global_position = (stack.node as Node3D).global_position + Vector3(0.8, 0.0, 0.0)
	var before := _torches(main.player.inventory)
	ok(ts.take() and _torches(main.player.inventory) == before + 1 and ts.left_of(stack) == int(H.get("start", 2)) - 1, "the interact button there takes one")
	var d0 := floorf(float(main.world.get("days")))
	main.world.days = d0 + 1.2
	await _frames(2)
	ok(ts.left_of(stack) == mini(int(H.get("start", 2)) - 1 + int(H.get("per_day", 2)), int(H.get("max", 3))), "a day on he has bound more (%d, at most %d)" % [ts.left_of(stack), int(H.get("max", 3))])
	main.world.days = d0 + 6.2
	await _frames(2)
	ok(ts.left_of(stack) == int(H.get("max", 3)), "never past max, however long you are away (%d)" % ts.left_of(stack))
	# 2. The short brand.
	_drop_torches(main)
	var sp := hub.arrival()
	main.player.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.player.set_physics_process(false)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	await _settle(main)
	main.player.set_physics_process(false)
	var held := main.player.torch.item()
	ok(main.surface == main.area_node and main.player.torch.lit() and float(held.get("burn_left_min", 99.0)) <= float(S.get("brand_burn_min", 3.0)) + 0.01, "with no torch of your own the song's brand is short (%.1f min of %.0f)" % [float(held.get("burn_left_min", 99.0)), Torch.full_burn_min()])
	# 3. The realm's caches.
	await _frames(3)
	var C: Dictionary = S.get("caches", {})
	var cs := ts._stacks.filter(func(s): return str(s.where) == "first")
	var hp := main.area_node.area_hearth.global_position
	var far := cs.all(func(s): return Vector2((s.node as Node3D).global_position.x - hp.x, (s.node as Node3D).global_position.z - hp.z).length() >= float(C.get("from_hearth_m", 35.0)) - 0.1)
	ok(cs.size() == int(C.get("count", 4)) and far, "the realm has %d caches, all away from its hearth" % cs.size())
	var c0: Dictionary = cs[0]
	_drop_torches(main)
	main.player.global_position = (c0.node as Node3D).global_position + Vector3(0.6, 0.0, 0.0)
	var n0 := ts.left_of(c0)
	for i in n0:
		ts.take()
	ok(n0 >= 1 and ts.left_of(c0) == 0 and _torches(main.player.inventory) == n0, "a cache's %d torch(es) taken, it is empty" % n0)
	var t0 := float(main.world.get("days"))
	main.world.days = t0 + float(C.get("restock_days", 2.0)) * 0.5
	ok(ts.left_of(c0) == 0, "half the wait on, still empty")
	main.world.days = t0 + float(C.get("restock_days", 2.0)) + 0.1
	ok(ts.left_of(c0) >= 1, "restock_days on, it has filled again (%d)" % ts.left_of(c0))
	# 4. The ruin's bundle.
	await main.go_down()
	await _settle(main)
	main.player.set_physics_process(false)
	_drop_torches(main)
	var full := main.fires.bundle_left
	main.player.global_position = main.fires.bundle.global_position + Vector3(0.5, 0.0, 0.0)
	main.take_torch()
	ok(main.fires.bundle_left == full - 1, "one from the ruin's bundle (%d left)" % main.fires.bundle_left)
	var hub_left := int(TorchSupply.hub_stack().left)
	CrawlerSave.save()
	main.queue_free()
	await _frames(3)
	var main2 := await _boot("")
	ok(CrawlerSave.continued and main2.fires.bundle_left == full - 1, "Continue: the ruin's bundle as you left it (%d), never laid again" % main2.fires.bundle_left)
	ok(int(TorchSupply.hub_stack().left) == hub_left, "and the firekeeper's stack as you left it")
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

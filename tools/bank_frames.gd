extends SceneTree
## The male shaman, the bank, a lost pile and the song home (design §GI,
## §GJ, queue 117), rendered once:
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/bank_frames.gd
## Frames to OUT (default user://bank_frames/): 01 the shaman close, 02 the
## bank's store-basket with its panel open, 03 a pile glowing in the dark
## of the ruin, 04 the song home (the wash), 05 home at the hub fire.

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  frame %s" % name)


func _look(p: CrawlerPlayer, eye: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	p.spawn_flat(eye, atan2(-flat.x, -flat.z), atan2(target.y - (eye.y + 1.55), maxf(flat.length(), 0.01)))


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	OS.set_environment("SEED", "7")
	out = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://bank_frames")
	DirAccess.make_dir_recursive_absolute(out)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface or main.leaving:
		await process_frame
	var p := main.player
	p.set_physics_process(false)
	var hub := main.surface as HubCamp
	var sh := hub.shaman.global_position
	var fp: Vector3 = hub.camp.pos
	var eye := sh + (Vector3(fp.x, sh.y, fp.z) - sh).normalized() * 1.6
	eye.y = hub.land.height_at(eye.x, eye.z)
	_look(p, eye, sh + Vector3(0, 1.0, 0))
	await _shot("01_shaman")
	var bp := hub.bank_node.global_position
	var e2 := bp + (Vector3(fp.x, bp.y, fp.z) - bp).normalized() * 2.0
	e2.y = hub.land.height_at(e2.x, e2.z)
	_look(p, e2, bp + Vector3(0, 0.4, 0))
	p.inventory.add(Inventory.make("scroll"))
	p.inventory.add(Inventory.make("tome"))
	main.bank_panel.open()
	CrawlerBank.deposit(p.inventory, "carried", 0)
	main.bank_panel.refresh()
	await _shot("02_bank")
	main.bank_panel.close()
	# To the realm, down into the ruin, and die there with something on you.
	var sp := hub.arrival()
	p.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	while main.leaving:
		await process_frame
	p.inventory.add(Inventory.make("fish"))
	await main.go_down()
	while main.leaving:
		await process_frame
	var wk: Array = main.lay.wake
	p.global_position = wk[0]
	await _frames(5)
	main._on_taken()
	await _frames(10)
	# Back by the song and down to the pile, the torch out.
	p.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.areas.interact()
	await _frames(3)
	main.areas.interact()
	while main.leaving:
		await process_frame
	await main.go_down()
	while main.leaving:
		await process_frame
	p.set_physics_process(false)
	if p.torch.lit():
		p.torch.douse()
	main.areas.live = false
	var pile: Node3D = main.areas._pile_nodes.values()[0]
	var pp := pile.global_position
	var to_h := (main.fires.hearth.global_position - pp)
	to_h.y = 0.0
	var e3 := pp + to_h.normalized() * 2.2
	e3.y = pp.y
	_look(p, e3, pp + Vector3(0, 0.2, 0))
	await _shot("03_pile_in_the_dark")
	main.areas.live = true
	# Up and home by the song.
	await main.go_up()
	while main.leaving:
		await process_frame
	var hp := main.area_node.area_hearth.global_position
	p.global_position = hp + Vector3(2.0, 0.0, 0.0)
	main.areas.to_hub()
	await _frames(30)
	await _shot("04_song_home")
	while main.leaving:
		await process_frame
	await _shot("05_home")
	print("[bank_frames] %s" % out)
	quit(0)

extends SceneTree
## The walkabout for queue 124 and 125 (design §GO.7, §GO.10-11), rendered
## once:
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path . --rendering-method forward_plus \
##     --resolution 960x540 -s tools/fire_pipe_frames.gd
## (on a Mac, the same without xvfb-run: a window opens while it renders).
## Frames to OUT (default user://pipe_frames/<seed>/):
##   124  01 on the log, 02 packing the pipe, 03 the ember in the tongs,
##        04 the coloured smoke (damiana), 05 the same at its peak (the sky
##        tinted)
##   125  06 the bard from far off (following the music), 07 the bard
##        close, 08 the oracle found, 09 the vision, 10 the camp's work by
##        day (a keeper at a station), 11 a cast at the fire
## SETTLE= frames to wait first (150).

var out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("  frame %s" % name)


func _look(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), atan2(target.y - (at.y + 1.55), maxf(flat.length(), 0.01)))


func _settle(main: CrawlerMain) -> void:
	await _frames(3)
	var w := 0
	while main.leaving and w < 3000:
		await process_frame
		w += 1
	await _frames(30)


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	if OS.get_environment("SEED") == "":
		OS.set_environment("SEED", "7")
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://pipe_frames/" + OS.get_environment("SEED"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface:
		await process_frame
	await _frames(int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE").is_valid_int() else 150)
	var hub := main.surface as HubCamp
	var p := main.player
	var pipe := main.fire_pipe
	p.set_physics_process(false)
	pipe.set_process(false)
	# 124: on a log, packing, the ember, the smoke.
	p.inventory.add(FirePipe.pinch("damiana"))
	var bi := 0
	for i in hub.benches.size():
		if (hub.benches[i].at as Vector3).distance_to(hub.shaman.global_position) > 3.5:
			bi = i
			break
	pipe.sit(bi)
	pipe.tick(0.05)
	await _shot("01_on_the_log")
	main.areas.interact()
	var P: Dictionary = FirePipe.seat_data().get("pose", {})
	for i in int(float(P.get("pack_s", 1.6)) * 0.7 / 0.05):
		pipe.tick(0.05)
	await _shot("02_packing")
	while pipe.state != "ember":
		pipe.tick(0.05)
	for i in int(float(P.get("ember_s", 2.2)) * 0.6 / 0.05):
		pipe.tick(0.05)
	await _shot("03_ember_tongs")
	while pipe.state != "smoke":
		pipe.tick(0.05)
	for i in 40:
		pipe.tick(0.05)
		await process_frame
	await _shot("04_smoke_damiana")
	for i in int(float(FirePipe.herb_data("damiana").onset_s) / 0.1):
		pipe.tick(0.1)
		await process_frame
	await _shot("05_peak_sky_tint")
	pipe.stand(false)
	for i in 40:
		pipe.tick(0.1)
	pipe.set_process(true)
	# 125: the desert's bard and oracle.
	SongWeb.learn("cactus")
	main.areas.to_area("first")
	await _settle(main)
	var rf := main.realm_folk
	rf.tick(0.1)
	await _frames(10)
	var area := main.surface
	var bp := rf.bard.global_position
	var far := bp + (Vector3(area.land.center.x, 0, area.land.center.y) - Vector3(bp.x, 0, bp.z)).normalized() * 45.0
	_look(p, Vector3(far.x, area.land.height_at(far.x, far.z), far.z), bp + Vector3(0, 1.0, 0))
	await _shot("06_bard_far")
	var near := bp + rf.bard.front() * 3.0
	_look(p, Vector3(near.x, area.land.height_at(near.x, near.z), near.z), bp + Vector3(0, 1.0, 0))
	await _shot("07_bard_close")
	var op := rf.oracle.global_position
	var on := op + rf.oracle.front() * 3.2
	_look(p, Vector3(on.x, area.land.height_at(on.x, on.z), on.z), op + Vector3(0, 0.8, 0))
	await _shot("08_oracle")
	p.global_position = op + Vector3(1.0, 0, 0)
	main.areas.interact()
	for i in 20:
		rf.tick(0.1)
	await _shot("09_vision")
	while rf.vision_t >= 0.0:
		rf.tick(0.2)
	# Home, a keeper at work by day, then a cast at the fire.
	p.global_position = area.area_hearth.global_position + Vector3(1.5, 0, 0)
	main.areas.interact()
	await _settle(main)
	hub = main.surface as HubCamp
	var wv := hub.work_view
	var per_day := float(main.world.get("day_length_s"))
	var guard := 0
	while guard < 2000 and not (str(wv.sim.phase().part) == "day" and wv.sim.keepers.values().any(func(k): return str(k.mode) == "work" and str(k.key) != "shaman")):
		main.world.days = float(main.world.get("days")) + 6.0 / per_day
		wv.step()
		guard += 1
	for i in 120:
		await process_frame
	var worker := ""
	for k in wv.sim.keepers:
		if str(wv.sim.keepers[k].mode) == "work" and k != "shaman":
			worker = str(k)
	if worker != "":
		var f: HearthFolk = wv._folk[worker]
		var fp: Vector3 = hub.camp.pos
		var eye := f.global_position + (Vector3(fp.x, f.global_position.y, fp.z) - f.global_position).normalized() * 4.0
		_look(p, Vector3(eye.x, hub.land.height_at(eye.x, eye.z), eye.z), f.global_position + Vector3(0, 0.7, 0))
		await _shot("10_keeper_at_work_" + worker)
	pipe.sit(bi)
	main.library.open_key()
	for i in 6:
		main.areas.interact()
	await _shot("11_iching_cast")
	print("[pipe_frames] %s" % out_dir)
	quit(0)

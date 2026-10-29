extends SceneTree
## The shaman's song to the first realm (design §GH, §GK.2-3, queue 116;
## §GD.1.2-4, queue 113), rendered once:
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/area_frames.gd
## Frames to OUT (default user://area_frames/): 00 the platter of key plants
## by the hub fire, 01 sitting at the hub fire (the cactus given),
## 02 the song's colour and the glimpse in the flames, 03 stepping in (the
## wash), 04 the arrival at the realm's hearth, 05 the hearth lit, 06 the
## ruin mouth, 07 the root growing in the desert.

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


func _look(p: CrawlerPlayer, land: SurfaceGround, eye: Vector3, target: Vector3) -> void:
	var at := Vector3(eye.x, land.height_at(eye.x, eye.z), eye.z)
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), atan2(target.y - (at.y + 1.55), maxf(flat.length(), 0.01)))


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	OS.set_environment("SEED", "7")
	out = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://area_frames")
	DirAccess.make_dir_recursive_absolute(out)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface or main.leaving:
		await process_frame
	var p := main.player
	p.set_physics_process(false)
	var hub := main.surface as HubCamp
	# The platter of three key plants by the fire (§GK.2).
	for i in 5:
		await process_frame
	var plat := main.song_keys._platter
	var pp := plat.global_position
	var fp: Vector3 = hub.camp.pos
	var away := Vector3(pp.x - fp.x, 0.0, pp.z - fp.z).normalized()
	var e0 := pp + away * 1.0
	e0.y = hub.land.height_at(e0.x, e0.z)
	var to0 := Vector2(pp.x - e0.x, pp.z - e0.z)
	p.spawn_flat(e0, atan2(-to0.x, -to0.y), atan2(pp.y - (e0.y + 1.55), to0.length()))
	await _shot("00_platter")
	# Take the cactus, give it to the shaman: he sings the desert's song.
	main.song_keys.take()
	if not p.inventory.has_kind("key_cutting"):
		p.inventory.add(SongKeys.cutting("cactus"))
	main.song_keys.give()
	await _shot("01_sitting")
	for i in 150:
		await process_frame
	await _shot("02_song_and_glimpse")
	main.areas.step_in()
	for i in 40:
		await process_frame
	await _shot("03_stepping_in")
	while main.leaving:
		await process_frame
	await _shot("04_arrival")
	var area := main.surface
	var hp := area.area_hearth.global_position
	var c := Vector3(area.land.center.x, hp.y, area.land.center.y)
	_look(p, area.land, hp + (c - hp).normalized() * 3.5, hp + Vector3(0, 0.3, 0))
	area.light_hearth()
	await _shot("05_hearth_lit")
	var m: Vector2 = area.stair.mouth
	var sn: Vector2 = area.stair.n
	_look(p, area.land, Vector3(m.x + sn.x * 9.0, 0, m.y + sn.y * 9.0), Vector3(m.x, area.land.base_y, m.y))
	await _shot("06_ruin_mouth")
	# A key plant growing in the desert (the root, §GK.2).
	for g in main.song_keys._growing:
		if str(g.key) == "root":
			var q: Vector3 = (g.node as Node3D).global_position
			_look(p, area.land, q + Vector3(1.6, 0.0, 0.6), q + Vector3(0, 0.15, 0))
			await _shot("07_root_plant")
	print("[area_frames] %s" % out)
	quit(0)

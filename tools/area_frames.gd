extends SceneTree
## The shaman's song to the first realm (design §GH, queue 116; §GD.1.2-4,
## queue 113), rendered once:
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/area_frames.gd
## Frames to OUT (default user://area_frames/): 01 sitting at the hub fire,
## 02 the song's colour and the glimpse in the flames, 03 stepping in (the
## wash), 04 the arrival at the realm's hearth, 05 the hearth lit, 06 the
## ruin mouth.

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
	# Sit at the fire (from the spawn), the song and its glimpse.
	var sp := hub.arrival()
	p.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.areas.interact()
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
	print("[area_frames] %s" % out)
	quit(0)

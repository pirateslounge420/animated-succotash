extends SceneTree
## Fire travel to the first area (design §GD.1.2-4, queue 113), rendered
## once:
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/area_frames.gd
## Frames to OUT (default user://area_frames/): 01 the hub fire, 02 its
## flames in the area's colour, 03 the wash, 04 the cold hearth, 05 it lit,
## 06 the area's surface toward its middle, 07 the ruin mouth.

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
	var fp: Vector3 = hub.camp.pos
	var n: Vector2 = hub.frame.n
	_look(p, hub.land, fp + Vector3(n.x, 0, n.y) * 4.0, fp + Vector3(0, 0.8, 0))
	await _shot("01_hub_fire")
	var kept := main.areas._tint_fire(hub.fire, CrawlerAreas.colour())
	await _shot("02_flames_turn")
	main.areas._untint_fire(kept)
	main._fade.visible = true
	main._fade.color = Color(CrawlerAreas.colour().r, CrawlerAreas.colour().g, CrawlerAreas.colour().b, 0.7)
	await _shot("03_wash")
	main._fade.visible = false
	var sp := hub.arrival()
	p.spawn_flat(sp.pos, float(sp.yaw), 0.0)
	main.areas.interact()
	while main.leaving:
		await process_frame
	var area := main.surface
	var hp := area.area_hearth.global_position
	var c := Vector3(area.land.center.x, hp.y, area.land.center.y)
	var back := hp + (hp - c).normalized() * -3.5
	_look(p, area.land, hp + (c - hp).normalized() * 3.5, hp + Vector3(0, 0.3, 0))
	await _shot("04_cold_hearth")
	area.light_hearth()
	await _shot("05_hearth_lit")
	_look(p, area.land, hp + (c - hp).normalized() * 3.0, c + Vector3(0, 2.0, 0))
	await _shot("06_area_surface")
	var m: Vector2 = area.stair.mouth
	var sn: Vector2 = area.stair.n
	_look(p, area.land, Vector3(m.x + sn.x * 9.0, 0, m.y + sn.y * 9.0), Vector3(m.x, area.land.base_y, m.y))
	await _shot("07_ruin_mouth")
	print("[area_frames] %s" % out)
	quit(0)

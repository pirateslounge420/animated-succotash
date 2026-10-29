extends SceneTree
## The camp cauldron's brews, rendered once each at full (CauldronFX;
## Mike, 26 Oct):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/cauldron_frames.gd
## Frames to OUT (default user://cauldron_frames/): one per brew, from a
## few steps off, the pot against the dark. ONLY=<brew> just that one.

func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	OS.set_environment("SEED", "7")
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://cauldron_frames")
	DirAccess.make_dir_recursive_absolute(out)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface:
		await process_frame
	await _frames(20)
	var hub := main.surface as HubCamp
	var p := main.player
	p.set_physics_process(false)
	var fx := hub.cauldron_fx
	var at := fx.global_position
	var n: Vector2 = hub.frame.n
	var eye := Vector3(at.x + n.x * 3.2, hub.land.height_at(at.x + n.x * 3.2, at.z + n.y * 3.2), at.z + n.y * 3.2)
	var flat := Vector3(at.x - eye.x, 0.0, at.z - eye.z)
	p.spawn_flat(eye, atan2(-flat.x, -flat.z), atan2(at.y + 0.6 - (eye.y + 1.55), flat.length()))
	for key: String in CauldronFX.brews():
		if OS.get_environment("ONLY") != "" and key != OS.get_environment("ONLY"):
			continue
		fx.start(key, true)
		fx.advance(fx.brew_s() + 0.01)
		await _frames(int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE").is_valid_int() else 90)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(key + ".png"))
		print("  frame %s" % key)
	print("[cauldron_frames] %s" % out)
	quit(0)

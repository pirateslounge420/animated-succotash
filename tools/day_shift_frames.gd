extends SceneTree
## The hub at dusk as the lights come on (design §GF, queue 115), rendered
## once:
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-method forward_plus \
##     --resolution 640x360 -s tools/day_shift_frames.gd
## From behind the spawn, looking over the fire at the camp: at the start
## (3 minutes into dusk), then the routine fast-forwarded on the world's
## clock (DayShift.tick, no frames drawn between) to 2, 4 and 7 minutes
## later, and midnight. Frames to OUT (default user://day_shift_frames/).

func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ff(main: CrawlerMain, ds: DayShift, seconds: float) -> void:
	var per_day := float(main.world.get("day_length_s"))
	var t := 0.0
	while t < seconds:
		main.world.days = float(main.world.get("days")) + 0.25 / per_day
		ds.tick(0.25)
		t += 0.25


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	OS.set_environment("SEED", "7")
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://day_shift_frames")
	DirAccess.make_dir_recursive_absolute(out)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface:
		await process_frame
	await _frames(5)
	var hub := main.surface as HubCamp
	var ds := hub.day_shift
	ds.set_process(false)
	main.set_process(false)
	var p := main.player
	p.set_physics_process(false)
	var fp: Vector3 = hub.camp.pos
	var n: Vector2 = hub.frame.n
	var eye := Vector3(fp.x + n.x * 9.0, 0.0, fp.z + n.y * 9.0)
	eye.y = hub.land.height_at(eye.x, eye.z) + 1.5
	var flat := Vector3(fp.x - eye.x, 0.0, fp.z - eye.z)
	p.spawn_flat(eye, atan2(-flat.x, -flat.z), -0.12)
	var shots := [["01_dusk_start", 0.0], ["02_dusk_2min", 120.0], ["03_dusk_4min", 120.0], ["04_dusk_7min", 180.0], ["05_night", 900.0]]
	for s in shots:
		await _ff(main, ds, float(s[1]))
		await _frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(str(s[0]) + ".png"))
		var lit := ds.lights.filter(func(l): return str(l.kind) != "hearth" and bool(l.lit)).size()
		print("  frame %s: %d lights lit, sun %.1f°, bats out %d, birds out %d" % [s[0], lit, ds.sun(), ds.bats_out(), ds.birds_out()])
	print("[day_shift_frames] %s" % out)
	quit(0)

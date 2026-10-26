extends SceneTree
## The hub camp's walkabout (design §GC.1-2, queue 112), rendered once:
##   xvfb-run -a -s "-screen 0 960x540x24" godot --path . --rendering-method forward_plus \
##     --resolution 960x540 -s tools/hub_frames.gd
## Frames to OUT (default user://hub_frames/<seed>/): 01 the spawn at dusk,
## 02 the cook-shaman at the cauldron, 03 a keeper's site, 04 the
## fisher-weaver's site and the river, 05 the way down behind the fire.
## SETTLE= frames to wait first (200); FIRE_ONLY=1 just 01 and 02.

var out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("  frame %s" % name)


func _look(p: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	p.spawn_flat(at, atan2(-flat.x, -flat.z), atan2(target.y - (at.y + 1.55), maxf(flat.length(), 0.01)))


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	if OS.get_environment("SEED") == "":
		OS.set_environment("SEED", "7")
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else ProjectSettings.globalize_path("user://hub_frames/" + OS.get_environment("SEED"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	root.add_child(main)
	while not main.on_surface:
		await process_frame
	await _frames(int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE").is_valid_int() else 200)
	var hub := main.surface as HubCamp
	var p := main.player
	p.set_physics_process(false)
	await _shot("01_spawn_dusk")
	var sh := hub.shaman.global_position
	var fp: Vector3 = hub.camp.pos
	var from := sh + (Vector3(fp.x, sh.y, fp.z) - sh).normalized().rotated(Vector3.UP, 0.5) * 3.2
	_look(p, Vector3(from.x, hub.land.height_at(from.x, from.z), from.z), sh + Vector3(0, 0.8, 0))
	await _shot("02_cook_shaman")
	# FIRE_ONLY=1: just the two views of the fire (tuning its light).
	if OS.get_environment("FIRE_ONLY") != "":
		quit(0)
		return
	for st in hub.sites:
		var a: Vector3 = st.at
		var to := (Vector3(fp.x, a.y, fp.z) - a).normalized()
		var eye := a + to * 5.0
		_look(p, Vector3(eye.x, hub.land.height_at(eye.x, eye.z), eye.z), a + Vector3(0, 0.8, 0))
		await _shot("03_site_" + str(st.keeper))
	var down: Vector2 = hub.stair.mouth
	var n: Vector2 = hub.stair.n
	var e2 := Vector2(fp.x, fp.z) + n * 3.0
	_look(p, Vector3(e2.x, hub.land.height_at(e2.x, e2.y), e2.y), Vector3(down.x, hub.land.base_y, down.y) - Vector3(n.x, 0, n.y) * 2.0)
	await _shot("05_way_down")
	print("[hub_frames] %s" % out_dir)
	quit(0)

extends SceneTree
## Frame-time bench for the performance pass (design §W): the fixed dev
## viewpoint (seed 42, first camp, clear weather) at 15:00, the frame
## held still for WARM frames, then MEASURE frames timed with the same
## numbers as the F2 readout (PerfReadout): real frame ms, the root
## viewport's cpu and gpu render ms, and the shadow pass's draws and
## primitives; then the same with the sun's shadows off, so the shadow
## pass's own ms is the difference. Needs a real renderer (not
## --headless):
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1708x960 -s tools/perf_bench.gd
##
## In this container the GPU is a software rasterizer (llvmpipe), so the
## absolute ms are far above a real GPU's; compare runs with each other.
## LABEL names the run in the printed line. LINES=1080 (or 720, 960)
## overrides the internal frame for this run only, to compare with what
## design §Y replaced.

## Frames to settle, then to measure (WARM / MEASURE override: the
## software rasterizer here is slow).
var WARM := int(OS.get_environment("WARM")) if OS.get_environment("WARM") != "" else 120
var MEASURE := int(OS.get_environment("MEASURE")) if OS.get_environment("MEASURE") != "" else 240


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = get_root().get_node("World")
	world.spawn_choice = 0
	seed(42)
	Encampment.fixed_side = 0.0
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var clear := {"wind": Vector3(1, 0, 0.5), "rain_mm_h": 0.0, "snow": false, "temp_c": 18.0, "storm": 0.0, "clear": 1.0, "cloud": 0.15}
	main._weather_timer = 1e9
	main._local_weather = clear
	main._weather_eased = clear.duplicate()
	var pd: Vector3 = main.player.surface_dir
	var base: float = floor(world.days) + 1.0
	world.days = Astro.days_at_solar_hour(base, 15.0, CubeSphere.longitude(pd), CubeSphere.latitude(pd))
	if OS.get_environment("LINES") != "":
		var h := int(OS.get_environment("LINES"))
		get_root().content_scale_size = Vector2i(int(round(h * 16.0 / 9.0)), h)
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var sun: DirectionalLight3D = main.sky.sun
	var on := await _measure(vp, WARM)
	on = await _measure(vp, MEASURE)
	sun.shadow_enabled = false
	await _measure(vp, mini(30, WARM))
	var off := await _measure(vp, MEASURE)
	sun.shadow_enabled = true
	var label := OS.get_environment("LABEL")
	print("[perf] %s internal %s: frame %.1f ms, scripts %.1f, cpu %.1f, gpu %.1f | shadows off: frame %.1f, gpu %.1f | shadow pass ≈ %.1f ms gpu, %d draws, %dk tris; total draws %d, %dk tris" % [
		label, get_root().content_scale_size, on.frame, on.proc, on.cpu, on.gpu, off.frame, off.gpu, on.gpu - off.gpu, on.sdraws, on.sprims / 1000, on.draws, on.prims / 1000])
	quit()


func _measure(vp: RID, n: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var cpu := 0.0
	var gpu := 0.0
	var sd := 0
	var sp := 0
	var dr := 0
	var pr := 0
	var proc := 0.0
	for i in n:
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		sd += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		sp += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		dr += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		pr += RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		proc += (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	return {"frame": (Time.get_ticks_usec() - t0) / 1000.0 / n, "cpu": cpu / n, "gpu": gpu / n,
		"sdraws": sd / n, "sprims": sp / n, "draws": dr / n, "prims": pr / n, "proc": proc / n}

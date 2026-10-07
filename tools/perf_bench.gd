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
	# SCENE=crawler_hearth (design 6 Oct §FH, §ER): Torchfire 1's hearth
	# room, not the open world.
	if OS.get_environment("SCENE") == "crawler_hearth":
		await _crawler_hearth()
		quit(0)
		return
	var world = get_root().get_node("World")
	world.pin(42, 0)
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
	# PRESETS=1 (design §BU): the frame time at each pixel-size preset
	# (look.json render.presets), the sun's shadows as set, then quit.
	if OS.get_environment("PRESETS") == "1":
		for pname in Display.presets():
			Settings.set_value("display.preset", pname)
			Settings.set_value("display.lines", 0)
			Display.apply()
			await _measure(vp, mini(60, WARM))
			var r := await _measure(vp, MEASURE)
			print("[perf] preset %s %s: frame %.1f ms (%.0f fps), scripts %.1f, cpu %.1f, gpu %.1f ms" % [pname, Display.internal_size(), r.frame, 1000.0 / maxf(r.frame, 0.01), r.proc, r.cpu, r.gpu])
		quit(0)
		return
	# SCENE=rainforest_camp (design 6 Oct §ER.1): the camp view Mike measured
	# at ~7 fps: a camp at the ruin nearest the rainforest nearest the
	# opening, 15:00, from 9 m off its fire; rain on, then rain off.
	if OS.get_environment("SCENE") == "rainforest_camp":
		await _rainforest_camp(world, main, vp)
		quit(0)
		return
	# SCENE=hilly (design §ER.1 step 7/12): occlusion culling off and on in
	# the hilliest view near the opening (OCCLUSION=1 builds the occluders).
	if OS.get_environment("SCENE") == "hilly":
		await _hilly(world, main, vp)
		quit(0)
		return
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


## Torchfire 1's hearth room (design 6 Oct §FH, §ER): SEED's tomb (7 by
## default) at the default internal frame, measured from the mat where you
## wake, looking across the hearth at the one who found you; the same with
## the rescuer hidden and stopped (its own cost is the difference); and
## from 1.6 m in front of the rescuer, where it fills the frame. One line
## each, LABEL first.
func _crawler_hearth() -> void:
	WorldSave.read_only = true
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var p := main.player
	p.set_physics_process(false)
	var w: Array = main.lay.wake
	p.spawn_flat(w[0], float(w[1]), -0.32)
	var r: Node3D = main.rescuer
	var label := OS.get_environment("LABEL")
	var say := func(what: String, m: Dictionary) -> void:
		print("[perf] %s crawler hearth %s, internal %s: frame %.1f ms (%.0f fps), scripts %.2f, cpu %.2f, gpu %.2f ms; %d draws, %dk tris" % [
			label, what, get_root().content_scale_size, m.frame, 1000.0 / maxf(m.frame, 0.01), m.proc, m.cpu, m.gpu, m.draws, m.prims / 1000])
	await _measure(vp, WARM)
	say.call("waking view", await _measure(vp, MEASURE))
	r.visible = false
	r.process_mode = Node.PROCESS_MODE_DISABLED
	await _measure(vp, mini(60, WARM))
	say.call("waking view, rescuer hidden", await _measure(vp, MEASURE))
	r.visible = true
	r.process_mode = Node.PROCESS_MODE_INHERIT
	var rp: Vector3 = (main.lay.rescuer as Array)[0]
	var ry := float((main.lay.rescuer as Array)[1])
	var front := Vector3(-sin(ry), 0.0, -cos(ry))
	var at := rp + front * 1.6
	p.spawn_flat(at, atan2(front.x, front.z), -0.15)
	await _measure(vp, mini(60, WARM))
	say.call("1.6 m in front of the rescuer", await _measure(vp, MEASURE))


## The rainforest camp view (§ER.1): found, built, measured rain on and
## rain off. Prints one line each, LABEL first.
func _rainforest_camp(world, main, vp: RID) -> void:
	var map: PlanetData = world.planet
	var want := BiomeTemplates.KEYS.find("TROPICAL_RAINFOREST")
	var pd: Vector3 = main.player.surface_dir
	var best := Vector3.ZERO
	var best_m := INF
	for i in map.cell_count:
		if map.biome[i] != want:
			continue
		var inner := true
		for k in 4:
			var nb := map.neighbor(i, k)
			if nb >= 0 and map.biome[nb] != want:
				inner = false
		if not inner:
			continue
		var m := CubeSphere.surface_distance_m(map.dir[i], pd)
		if m < best_m:
			best_m = m
			best = map.dir[i]
	if best == Vector3.ZERO:
		print("[perf] no tropical rainforest on this planet")
		return
	var rs := Ruins.near(map, best, 3000.0)
	var c: Vector3 = (rs[0] as Dictionary).dir if not rs.is_empty() else best
	c = CreatureSpawner._offset(c, 0.7, 14.0)
	var key := "ruin:perf"
	var cs: CampSim = main.camp_sim
	var pid := Peoples.pick(map, main.chunks.rivers, c, "ruin")
	var st := cs.ensure(key, c, pid, FireStore.biome_key(world, c), 5252, 7)
	st.state = "living"
	var stand := CreatureSpawner._offset(c, 2.2, 9.0)
	main.player.spawn_at(stand, c)
	main.chunks.load_blocking(stand)
	for i in 30:
		await process_frame
	var at: Vector3 = world.to_scene(c, PlanetConst.RADIUS_M + main.chunks.ground_height(c))
	main.camps._camps[key] = main.camps._build(at, "tribal", 5252, key)
	var base: float = floor(world.days) + 1.0
	world.days = Astro.days_at_solar_hour(base, 15.0, CubeSphere.longitude(c), CubeSphere.latitude(c))
	print("[perf] rainforest camp %.1f km from the opening (%s, %s), the %s folk" % [best_m / 1000.0, FireStore.biome_key(world, c), str(rs.size()) + " ruins near", pid])
	var label := OS.get_environment("LABEL")
	for wet in [true, false]:
		var w := {"wind": Vector3(2, 0, 1), "rain_mm_h": 8.0 if wet else 0.0, "snow": false, "temp_c": 25.0, "storm": 0.6 if wet else 0.0, "clear": 0.05, "cloud": 0.95}
		main._weather_timer = 1e9
		main._local_weather = w
		main._weather_eased = w.duplicate()
		await _measure(vp, WARM)
		var r := await _measure(vp, MEASURE)
		if wet:
			# The rain's own cost (§ER.1 step 4): the same storm, the streaks
			# hidden.
			main.rain_overlay.visible = false
			await _measure(vp, mini(WARM, 4))
			var dry := await _measure(vp, MEASURE)
			main.rain_overlay.visible = true
			print("[perf] %s rain streaks alone: gpu %.2f ms (with %.2f, without %.2f)" % [label, r.gpu - dry.gpu, r.gpu, dry.gpu])
		print("[perf] %s rainforest camp, rain %s: frame %.1f ms (%.1f fps), scripts %.1f, cpu %.1f, gpu %.2f ms | visible %d draws, %dk tris | shadow %d draws, %dk tris" % [
			label, "on " if wet else "off", r.frame, 1000.0 / maxf(r.frame, 0.01), r.proc, r.cpu, r.gpu, r.draws, r.prims / 1000, r.sdraws, r.sprims / 1000])
	_census(main)


## The hilliest view within 25 km of the opening (the biggest rise from a
## point to the highest of eight points 300 m round it), stood at the low
## point facing the rise, at 15:00 in clear weather: frame, cpu, gpu and
## triangles with the viewport's occlusion culling off, then on.
func _hilly(world, main, vp: RID) -> void:
	var pd: Vector3 = main.player.surface_dir
	var east := CubeSphere.east(pd)
	var north := CubeSphere.north(pd)
	var best := -1.0
	var at := pd
	var look := pd
	for a in range(-25, 26):
		for b in range(-25, 26):
			var d: Vector3 = (pd + (east * a + north * b) * 1000.0 / PlanetConst.RADIUS_M).normalized()
			var e: float = world.surface_elevation(d)
			if e < PlanetConst.SEA_LEVEL_M + 2.0:
				continue
			for k in 8:
				var ang := TAU * k / 8.0
				var q: Vector3 = (d + (CubeSphere.east(d) * cos(ang) + CubeSphere.north(d) * sin(ang)) * 300.0 / PlanetConst.RADIUS_M).normalized()
				var rise: float = world.surface_elevation(q) - e
				if rise > best:
					best = rise
					at = d
					look = q
	print("[perf] hilly view: a %.0f m rise over 300 m, %.1f km from the opening" % [best, CubeSphere.surface_distance_m(pd, at) / 1000.0])
	main.player.spawn_at(at, look)
	main.chunks.load_blocking(at)
	var base: float = floor(world.days) + 1.0
	world.days = Astro.days_at_solar_hour(base, 15.0, CubeSphere.longitude(at), CubeSphere.latitude(at))
	for i in 60:
		await process_frame
	var label := OS.get_environment("LABEL")
	for occ in [false, true]:
		get_root().use_occlusion_culling = occ
		await _measure(vp, WARM)
		var r := await _measure(vp, MEASURE)
		print("[perf] %s hilly, occlusion %s: frame %.1f ms, scripts %.1f, cpu %.2f, gpu %.2f ms | visible %d draws, %dk tris" % [
			label, "on " if occ else "off", r.frame, r.proc, r.cpu, r.gpu, r.draws, r.prims / 1000])
	var n := 0
	for o in get_root().find_children("*", "OccluderInstance3D", true, false):
		n += 1
	print("[perf] %d occluders in the scene" % n)


## What's in the scene: mesh instances, multimesh instances and their
## triangles, lights (and how many cast shadows), particles, scripts.
func _census(main) -> void:
	var mi := 0
	var mi_tris := 0
	var mm := 0
	var mm_inst := 0
	var mm_tris := 0
	var lights := 0
	var shadowed := 0
	var parts := 0
	var procs := {}
	for n in get_root().find_children("*", "", true, false):
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree() and (n as MeshInstance3D).mesh != null:
			mi += 1
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).is_visible_in_tree() and (n as MultiMeshInstance3D).multimesh != null:
			mm += 1
			mm_inst += (n as MultiMeshInstance3D).multimesh.visible_instance_count if (n as MultiMeshInstance3D).multimesh.visible_instance_count >= 0 else (n as MultiMeshInstance3D).multimesh.instance_count
		elif n is Light3D and (n as Light3D).is_visible_in_tree():
			lights += 1
			if (n as Light3D).shadow_enabled:
				shadowed += 1
		elif n is GPUParticles3D or n is CPUParticles3D:
			parts += 1
		if n.get_script() != null and (n.is_processing() or n.is_physics_processing()):
			var sn := str((n.get_script() as Script).resource_path.get_file())
			procs[sn] = int(procs.get(sn, 0)) + 1
	_tri_census()
	print("[perf] census: %d mesh instances, %d multimeshes (%d instances), %d lights (%d with shadows), %d particle systems" % [mi, mm, mm_inst, lights, shadowed, parts])
	var top := procs.keys()
	top.sort_custom(func(a, b): return int(procs[a]) > int(procs[b]))
	print("[perf] processing scripts: %s" % str(top.slice(0, 12).map(func(k): return "%s x%d" % [k, procs[k]])))


## Triangles in view by where they come from: every visible mesh and
## multimesh inside its visibility range and the camera's frustum (whole
## nodes, as the renderer culls them), grouped by its nearest scripted
## ancestor and its own name. Prints the top 25.
var _tri_cache := {}

func _mesh_tris(m: Mesh) -> int:
	if m == null:
		return 0
	var id := m.get_rid()
	if _tri_cache.has(id):
		return _tri_cache[id]
	var t := 0
	if m is ArrayMesh:
		for s in m.get_surface_count():
			var il := (m as ArrayMesh).surface_get_array_index_len(s)
			t += (il if il > 0 else (m as ArrayMesh).surface_get_array_len(s)) / 3
	else:
		t = m.get_faces().size() / 3
	_tri_cache[id] = t
	return t


func _tri_census() -> void:
	var cam := get_root().get_camera_3d()
	if cam == null:
		return
	var planes := cam.get_frustum()
	var eye := cam.global_position
	var groups := {}
	var total := 0
	for n in get_root().find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or g.get_world_3d() != get_root().world_3d:
			continue
		var tris := 0
		var aabb: AABB
		if g is MeshInstance3D:
			tris = _mesh_tris((g as MeshInstance3D).mesh)
			aabb = (g as MeshInstance3D).get_aabb()
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mmesh := (g as MultiMeshInstance3D).multimesh
			var cnt := mmesh.visible_instance_count if mmesh.visible_instance_count >= 0 else mmesh.instance_count
			tris = _mesh_tris(mmesh.mesh) * cnt
			aabb = mmesh.get_aabb()
		else:
			continue
		if tris == 0:
			continue
		var wa: AABB = g.global_transform * aabb
		var c := wa.get_center()
		var r := wa.size.length() * 0.5
		var d := maxf(0.0, c.distance_to(eye) - r)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		if d > cam.far:
			continue
		var out := false
		for pl in planes:
			if pl.distance_to(c) > r:
				out = true
				break
		if out:
			continue
		var owner_name := "?"
		var a: Node = g.get_parent()
		while a != null:
			if a.get_script() != null:
				owner_name = str((a.get_script() as Script).resource_path.get_file())
				break
			a = a.get_parent()
		var nm := str(g.name)
		if nm.begins_with("@"):
			nm = "%s>%s" % [str(g.get_parent().name).rstrip("0123456789_@"), nm.get_slice("@", 1)]
		var k := "%s/%s%s" % [owner_name, nm.rstrip("0123456789_@"), " (mm)" if g is MultiMeshInstance3D else ""]
		var e: Array = groups.get(k, [0, 0])
		e[0] += tris
		e[1] += 1
		groups[k] = e
		total += tris
	var keys := groups.keys()
	keys.sort_custom(func(x, y): return groups[x][0] > groups[y][0])
	print("[perf] triangle census: %dk in range and frustum (whole nodes)" % (total / 1000))
	for k in keys.slice(0, 40):
		print("[perf]   %7dk  %4d nodes  %s" % [groups[k][0] / 1000, groups[k][1], k])


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

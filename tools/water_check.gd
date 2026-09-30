extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/water_check.gd
## Water (design 30 Sept §BE): waterfalls generate (RiverNetwork.falls)
## and render (a chunk's "Waterfalls" mesh has its sheets, a roar on
## each); the current flows downstream along a river (Current.flow_at);
## in the water the player drifts with it; wading drags. Prints the
## nearest fall's surface direction for a look (dev_view AT=x,y,z).
var main
var world
var player: PlanetPlayer
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(60)
	var chunks: ChunkManager = main.chunks
	var rivers: RiverNetwork = chunks.rivers
	var map: PlanetData = world.planet
	ok(rivers != null and rivers.a.size() > 0, "the river network has segments (%d)" % (rivers.a.size() if rivers else 0))
	# --- Waterfalls generate ---
	var n_falls := 0
	var segs_with := 0
	var nearest := -1
	var nearest_m := INF
	var nearest_fall := []
	var spawn := player.surface_dir
	for s in rivers.a.size():
		var fs := rivers.falls(s)
		if fs.is_empty():
			continue
		segs_with += 1
		n_falls += fs.size()
		var dm := CubeSphere.surface_distance_m(rivers.a[s], spawn)
		if dm < nearest_m:
			nearest_m = dm
			nearest = s
			nearest_fall = fs[0]
	ok(n_falls > 0, "waterfalls generate: %d falls on %d segments" % [n_falls, segs_with])
	if nearest < 0:
		print("RESULT fails: %d" % (fails + 1))
		quit(1)
		return
	var pa := rivers.a[nearest]
	var fd := (pa + (rivers.b[nearest] - pa) * float(nearest_fall[0])).normalized()
	var drop := float(nearest_fall[1]) - float(nearest_fall[2])
	print("[water] nearest fall %.0f m from the camp, %.1f m drop, AT=%.6f,%.6f,%.6f" % [nearest_m, drop, fd.x, fd.y, fd.z])
	# A viewpoint 28 m downstream of the lip, looking back up at it.
	var down := (rivers.b[nearest] - pa).normalized()
	var view := (fd + down * 28.0 / PlanetConst.RADIUS_M).normalized()
	print("[water] view: AT=%.6f,%.6f,%.6f LOOK_AT=%.6f,%.6f,%.6f" % [view.x, view.y, view.z, fd.x, fd.y, fd.z])
	# --- It renders: go there, the chunk's Waterfalls mesh has it ---
	var off: Vector3 = world.to_scene(fd, PlanetConst.RADIUS_M + world.surface_elevation(fd))
	world.rebase(off)
	player.global_position -= off
	chunks.load_blocking(fd)
	player.spawn_at(fd)
	await frames(30)
	var chunk: TerrainChunk = chunks.chunk_at(fd)
	var sheet: MeshInstance3D = chunk.get_node_or_null("Waterfalls") if chunk else null
	var verts := 0
	if sheet and sheet.mesh:
		verts = sheet.mesh.surface_get_array_len(0)
	ok(sheet != null and verts > 0, "the chunk at the fall has a Waterfalls mesh (%d vertices)" % verts)
	var roars := 0
	if chunk:
		for c in chunk.get_children():
			if c is AudioStreamPlayer3D and c.name == "Roar":
				roars += 1
	ok(roars > 0, "each fall roars (%d waterfall sources in the chunk)" % roars)
	# --- Current ---
	var flow := Current.flow_at(rivers, map, (pa + (rivers.b[nearest] - pa) * 0.5).normalized())
	ok(float(flow.speed) > 0.0 and (flow.dir as Vector3).length() > 0.9, "the river flows: %.2f m/s, a %s" % [flow.speed, flow.kind])
	var downstream: Vector3 = (rivers.b[nearest] - rivers.a[nearest]).normalized()
	ok((flow.dir as Vector3).dot(downstream) > 0.5, "downstream (dot %.2f)" % (flow.dir as Vector3).dot(downstream))
	var dry := Current.flow_at(rivers, map, CreatureSpawner._offset(fd, 0.0, 400.0))
	ok(float(dry.speed) == 0.0 or str(dry.kind) == "none" or float(dry.dist_m) < 40.0, "no flow 400 m from the river (%s)" % dry.kind)
	# --- Drift: in the middle of a wide, deep reach, hands off ---
	var widest := nearest
	for s in rivers.a.size():
		if rivers.width[s] > rivers.width[widest] and CubeSphere.surface_distance_m(rivers.a[s], fd) < 1500.0 and rivers.falls(s).is_empty():
			widest = s
	var mid := (rivers.a[widest] + (rivers.b[widest] - rivers.a[widest]) * 0.5).normalized()
	off = world.to_scene(mid, PlanetConst.RADIUS_M + world.surface_elevation(mid))
	world.rebase(off)
	player.global_position -= off
	chunks.load_blocking(mid)
	player.spawn_at(mid)
	await frames(90)
	var p0 := player.global_position
	var d0: Vector3 = world.dir_of(p0)
	await frames(180)
	var moved := CubeSphere.surface_distance_m(d0, world.dir_of(player.global_position))
	var f2 := Current.flow_at(rivers, map, d0)
	print("[water] in the %s (%.1f m wide, %.2f m/s): swimming %s, drifted %.2f m in 3 s, kind %s" % [f2.kind, rivers.width[widest], f2.speed, player.swimming, moved, player.current_kind])
	ok(not player.swimming or moved > 0.5, "swimming, you drift with the current (%.2f m in 3 s)" % moved)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

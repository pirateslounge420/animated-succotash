extends SceneTree
## Run (full planet): SEED=<n> BIOMES=JUNGLE,TEMPERATE_DECIDUOUS,SAVANNA godot --headless --path . --fixed-fps 60 --script tools/scene_load_check.gd
## How much the world asks the GPU to draw where you stand, by biome: the
## plant instances and triangles in the loaded chunks (instance_count x the
## mesh's triangles, before culling), the leaf cards' share, and the
## species that cost the most. A headless frame time means nothing (no
## GPU here); these counts are what a real GPU has to chew through.
var main
var world
var player: PlanetPlayer
var fails := 0
## Plant triangles allowed loaded round a site (BUDGET_M env, millions).
var BUDGET := (float(OS.get_environment("BUDGET_M")) if OS.get_environment("BUDGET_M") != "" else 25.0) * 1e6


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, -1)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(20)
	var map: PlanetData = world.planet
	var chunks: ChunkManager = main.chunks
	var all := SpeciesDB.all()
	var want := (OS.get_environment("BIOMES") if OS.get_environment("BIOMES") != "" else "JUNGLE,TEMPERATE_DECIDUOUS,SAVANNA").split(",")
	for key in want:
		var bid := BiomeTemplates.id_of_key(key)
		var cells: Array = []
		for c in map.cell_count:
			if map.biome[c] == bid and map.water[c] == PlanetData.Water.NONE:
				cells.append(c)
		if cells.is_empty():
			print("[load] %s: no cell on this planet" % key)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, key])
		var d: Vector3 = map.dir[cells[rng.randi() % cells.size()]]
		var off_v: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
		world.rebase(off_v)
		player.global_position -= off_v
		chunks.load_blocking(d)
		player.spawn_at(d)
		await frames(300)
		var inst_total := 0
		var tri_total := 0
		var by_sp := {}
		var by_kind := {}
		var tri_cache := {}
		var stack: Array = [get_root()]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for ch in n.get_children():
				stack.append(ch)
			if not n.has_meta("species") or not n is GeometryInstance3D or not (n as GeometryInstance3D).visible:
				continue
			var mesh: Mesh = null
			var count := 1
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
				mesh = (n as MultiMeshInstance3D).multimesh.mesh
				count = (n as MultiMeshInstance3D).multimesh.visible_instance_count
				if count < 0:
					count = (n as MultiMeshInstance3D).multimesh.instance_count
			elif n is MeshInstance3D:
				mesh = (n as MeshInstance3D).mesh
			if mesh == null:
				continue
			var tris: int = tri_cache.get(mesh, -1)
			if tris < 0:
				tris = 0
				for s in mesh.get_surface_count():
					var arr := mesh.surface_get_arrays(s)
					var idx = arr[Mesh.ARRAY_INDEX]
					tris += (idx.size() / 3) if idx != null and idx.size() > 0 else ((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
				tri_cache[mesh] = tris
			var kind := "other"
			if n.has_meta("band_group"):
				kind = ["full+shadow", "full", "light"][int(n.get_meta("band_group"))]
			elif n.has_meta("far_only"):
				kind = "picture"
			elif n.has_meta("young"):
				kind = "young"
			var krow: Array = by_kind.get(kind, [0, 0])
			krow[0] += count
			krow[1] += count * tris
			by_kind[kind] = krow
			var idx_sp := int(n.get_meta("species"))
			var name := all[idx_sp].name if idx_sp >= 0 and idx_sp < all.size() else "?"
			var row: Array = by_sp.get(name, [0, 0])
			row[0] += count
			row[1] += count * tris
			by_sp[name] = row
			inst_total += count
			tri_total += count * tris
		var names := by_sp.keys()
		names.sort_custom(func(a, b): return by_sp[a][1] > by_sp[b][1])
		print("[load] %s at %s: %d plant instances, %.1f M triangles (before culling), %d species" % [key, str(d), inst_total, tri_total / 1e6, names.size()])
		var kinds_txt := []
		for kk in by_kind:
			kinds_txt.append("%s %d plants %.1f M" % [kk, by_kind[kk][0], by_kind[kk][1] / 1e6])
		print("[load]    by drawing: %s" % ", ".join(kinds_txt))
		for i in mini(8, names.size()):
			var nm: String = names[i]
			print("[load]    %-34s %7d plants  %6.2f M tris  (%d per plant)" % [nm, by_sp[nm][0], by_sp[nm][1] / 1e6, by_sp[nm][1] / maxi(by_sp[nm][0], 1)])
		# The budget (1 Oct, Mike's Mac: 157 M in a jungle lagged).
		var ok := tri_total <= BUDGET
		print(("PASS  " if ok else "FAIL  ") + "%s: %.1f M plant triangles loaded, within the %.0f M budget" % [key, tri_total / 1e6, BUDGET / 1e6])
		if not ok:
			fails += 1
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

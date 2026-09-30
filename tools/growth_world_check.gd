extends SceneTree
## Growth in the running game (design §AR): finds a forest on the dev
## planet and checks what's placed there: the understory's young (seedlings
## and saplings of the stand's own species, by stage), the stand's young
## cohort growing young layouts (saplings and young trees among the trees),
## shade leaves (the leaf size packed in each plant's custom data: bigger
## under the canopy), the HUD naming a sapling; with TIMING=1, how long a
## chunk's undergrowth takes to place with and without the young (YOUNG=0).
##
##   STAMP=1 RENDER_CHUNKS=2 godot --headless --path . --fixed-fps 60 --script tools/growth_world_check.gd
##   (TIMING=1 for the timing alone)

var main
var world
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func goto(d: Vector3) -> void:
	var offset: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d) + 2.0)
	world.rebase(offset)
	main.player.global_position -= offset
	main.chunks.load_blocking(d)
	main.player.spawn_at(d)
	for k in 400:
		await process_frame
		if k > 60 and main.chunks._pending.is_empty():
			break


func _young_mmis() -> Array:
	var out: Array = []
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null or chunk.detail_node == null:
			continue
		for ch in chunk.detail_node.get_children():
			if ch is MultiMeshInstance3D and ch.has_meta("young") and (ch as MultiMeshInstance3D).multimesh != null:
				out.append(ch)
	return out


func _run() -> void:
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	await frames(30)
	var map: PlanetData = world.planet
	var want := [BiomeTemplates.TEMPERATE_DECIDUOUS, BiomeTemplates.TAIGA, BiomeTemplates.TEMPERATE_RAINFOREST,
		BiomeTemplates.TROPICAL_RAINFOREST, BiomeTemplates.JUNGLE, BiomeTemplates.CLOUD_FOREST, BiomeTemplates.FLOODPLAIN_FOREST]
	var cands: Array = []
	for c in map.biome.size():
		if map.biome[c] in want:
			cands.append(c)
	seed(11)
	cands.shuffle()
	var found := false
	for tries in mini(cands.size(), 20):
		await goto(map.dir[cands[tries]])
		if _young_mmis().size() > 0:
			found = true
			print("      a forest with young at %s (%s), after %d tries" % [str(map.dir[cands[tries]]), BiomeTemplates.name_of(map.biome[cands[tries]]), tries + 1])
			break
	ok(found, "found a forest whose floor has young trees")
	if not found:
		print("RESULT fails: %d" % fails)
		quit()
		return
	# How long a chunk's undergrowth takes, with and without the young (first,
	# before the walk to a sapling loads more).
	# (TIMING=1 in the environment: only this, the rest another run: the
	# two passes over a chunk take memory the game at a forest can't spare
	# in a small container.)
	var timing := OS.get_environment("TIMING") == "1"
	var here_key := TerrainChunk.key_at(main.player.surface_dir)
	var here: TerrainChunk = main.chunks.chunks.get(here_key)
	if here != null and timing:
		var t0 := Time.get_ticks_usec()
		var with_young := VegetationPlacer.compute_detail(here_key, map, here.data, here.hosts)
		var t1 := Time.get_ticks_usec()
		VegetationPlacer.YOUNG = false
		var without := VegetationPlacer.compute_detail(here_key, map, here.data, here.hosts)
		var t2 := Time.get_ticks_usec()
		VegetationPlacer.YOUNG = true
		var n_young := 0
		for k in with_young:
			if int(k) >= PlantGrowth.JUV_KEY:
				n_young += (with_young[k] as PackedFloat32Array).size() / VegetationPlacer.STRIDE
		with_young = {}
		without = {}
		print("      a chunk's undergrowth: %.0f ms with the young (%d of them), %.0f ms without" % [(t1 - t0) / 1000.0, n_young, (t2 - t1) / 1000.0])
		ok((t1 - t0) < (t2 - t1) * 2.5 + 200000, "the young add less than 1.5x the rest of the undergrowth's time (+0.2 s)")
		print("RESULT fails: %d" % fails)
		quit()
		return
	# The understory's young, by stage.
	var by_code := {}
	var species := {}
	var leaf_sum := 0.0
	var leaf_n := 0
	var shade_n := 0
	# In the shade (big shade leaves: 1.15x and up) and in the light.
	var shade_seedlings := 0
	var shade_saplings := 0
	for mmi in _young_mmis():
		var code: int = mmi.get_meta("young")
		var n: int = mmi.multimesh.instance_count
		by_code[code] = int(by_code.get(code, 0)) + n
		species[SpeciesDB.all()[int(mmi.get_meta("species"))].name] = true
		var buf: PackedFloat32Array = mmi.multimesh.buffer
		for i in n:
			var l := PlantGrowth.leaf_of(buf[i * 20 + 17])
			leaf_sum += l
			leaf_n += 1
			if l > 1.1:
				shade_n += 1
			if l >= 1.15:
				if code == 1:
					shade_seedlings += 1
				elif code <= 3:
					shade_saplings += 1
	print("      understory young by stage code (1 seedling, 2/3 sapling open/forest, 4/5 young tree): %s; species: %s" % [str(by_code), str(species.keys())])
	ok(int(by_code.get(1, 0)) > 0, "seedlings on the forest floor (%d)" % int(by_code.get(1, 0)))
	ok(int(by_code.get(2, 0)) + int(by_code.get(3, 0)) > 0, "and saplings (%d)" % (int(by_code.get(2, 0)) + int(by_code.get(3, 0))))
	ok(shade_seedlings > shade_saplings, "in the shade, seedlings outnumber saplings (most die young or wait): %d vs %d" % [shade_seedlings, shade_saplings])
	ok(leaf_n > 0 and float(shade_n) / leaf_n > 0.25, "a good share of the young grow shade leaves (%d of %d bigger than 1.1x; mean %.2fx)" % [shade_n, leaf_n, leaf_sum / maxf(leaf_n, 1)])
	# The stand's young cohort: young layouts among the trees.
	var young_trees := 0
	var saplings := 0
	var all_trees := 0
	var ratio_ok := true
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null:
			continue
		for t in chunk.trees:
			all_trees += 1
			var pick: int = t[4]
			if pick < 0:
				continue
			var slot := TreeLayouts.layout_of(pick) / TreeLayouts.COUNT
			if slot > 0:
				young_trees += 1
				if slot == 2:
					saplings += 1
				var sp: PlantSpecies = SpeciesDB.all()[int(t[2])]
				if float(t[1]) > sp.height_m.y * 1.45 * 0.75:
					ratio_ok = false
	print("      trees round here: %d, young %d (%d of them saplings)" % [all_trees, young_trees, saplings])
	ok(young_trees > 0 and young_trees < all_trees * 0.35, "the stand's young cohort grows young layouts (%d of %d trees)" % [young_trees, all_trees])
	ok(ratio_ok, "every young tree is under three quarters of its species' grown height")
	# Shade leaves on the trees: canopy trees under emergents, the young.
	var tree_leaf := {"young": [0.0, 0], "grown": [0.0, 0]}
	for c in main.chunks.chunks.values():
		var chunk := c as TerrainChunk
		if chunk == null:
			continue
		for key in chunk.tree_mm:
			var mm: MultiMesh = chunk.tree_mm[key]
			if mm == null:
				continue
			var buf := mm.buffer
			for i in mm.instance_count:
				var l := PlantGrowth.leaf_of(buf[i * 20 + 17])
				(tree_leaf["grown"] as Array)[0] += l
				(tree_leaf["grown"] as Array)[1] += 1
	print("      trees' mean leaf size %.2fx over %d" % [float(tree_leaf.grown[0]) / maxf(tree_leaf.grown[1], 1), tree_leaf.grown[1]])
	ok(int(tree_leaf.grown[1]) > 0 and float(tree_leaf.grown[0]) / tree_leaf.grown[1] < float(leaf_sum) / maxf(leaf_n, 1), "trees in the sun carry smaller leaves than the young in their shade")
	# The HUD names a sapling (or a seedling): stand by one, look at it.
	var target: MultiMeshInstance3D = null
	var tk := -1
	var best := INF
	var pp: Vector3 = main.player.global_position
	for mmi in _young_mmis():
		if int(mmi.get_meta("young")) < 2:
			continue
		var b0: PackedFloat32Array = mmi.multimesh.buffer
		for i in mmi.multimesh.instance_count:
			var p: Vector3 = mmi.global_transform * Vector3(b0[i * 20 + 3], b0[i * 20 + 7], b0[i * 20 + 11])
			if p.distance_to(pp) < best:
				best = p.distance_to(pp)
				target = mmi
				tk = i
	if target != null:
		var buf := target.multimesh.buffer
		var j := tk * 20
		var base := target.global_transform * Vector3(buf[j + 3], buf[j + 7], buf[j + 11])
		var h := Vector3(buf[j + 1], buf[j + 5], buf[j + 9]).length()
		var up: Vector3 = world.dir_of(base)
		var side := CubeSphere.north(up)
		main.player.spawn_at(world.dir_of(base + side * 2.0))
		await frames(60)
		var from := base + side * 2.0 + up * clampf(h * 0.5, 0.3, 1.5)
		var aim := (base + up * h * 0.5 - from).normalized()
		var found_name: Array = main.player.look._plant_on_ray(from, aim, 4.0, main.player.global_position)
		var name_s: String = found_name[0] if not found_name.is_empty() else ""
		ok(name_s.contains("sapling") or name_s.contains("seedling") or name_s.contains("young tree"), "the HUD names it by its stage: \"%s\"" % name_s.replace("\n", " / "))
	print("RESULT fails: %d" % fails)
	quit()

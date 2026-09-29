extends SceneTree
## Time to compute chunks round the first camp as in play (terrain, trees,
## undergrowth), for comparing placement changes. NO_CATALOGUES=1 loads the
## biome files only (SpeciesDB), to see what the catalogues cost;
## TROPICAL=1 times an Asian tropical forest instead of the camp.
##
##   ~/bin/godot --headless --path . --script tools/chunk_time.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = get_root().get_node("World")
	world.spawn_choice = 0
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var map: PlanetData = main.chunks.map
	var d0: Vector3 = main.player.surface_dir
	# TROPICAL=1: an Asian tropical forest instead (the most catalogue
	# species compete there: the worst case).
	if OS.get_environment("TROPICAL") == "1":
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for k in 200000:
			var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var b: String = BiomeTemplates.KEYS[map.biome[map.cell_at(d)]]
			if (b == "TROPICAL_RAINFOREST" or b == "JUNGLE") and RealmMap.world_at(d) == RealmMap.World.ASIA and map.sample(map.temp_c, d) > 22.0:
				d0 = d
				print("[chunks] Asian %s at %.1f, %.1f" % [b, rad_to_deg(CubeSphere.latitude(d)), rad_to_deg(CubeSphere.longitude(d))])
				break
	var face := CubeSphere.face_of(d0)
	var uv := CubeSphere.face_uv(face, d0)
	var ci := int((uv.x + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE)
	var cj := int((uv.y + 1.0) * 0.5 * TerrainChunk.CHUNKS_PER_FACE)
	var t_terrain := 0
	var t_plants := 0
	var t_prepare := 0
	var t_dapple := 0
	var dappled := 0
	var n := 0
	for dj in range(-3, 3):
		for di in range(-3, 3):
			var key := TerrainChunk.key_of(face, ci + di, cj + dj)
			var t0 := Time.get_ticks_usec()
			var data := TerrainChunk.compute(key, map, main.chunks.rivers)
			var t1 := Time.get_ticks_usec()
			var base := VegetationPlacer.compute_base(key, map, data)
			VegetationPlacer.compute_detail(key, map, data, base.hosts)
			var t2 := Time.get_ticks_usec()
			TerrainChunk.set_anchor(data)
			var placed := VegetationPlacer.prepare(base.plants, data.center, data.anchor_r, base.hosts, key, map.terrain.world_seed)
			var t3 := Time.get_ticks_usec()
			if CanopyDapple.bake(data.center, placed) != null:
				dappled += 1
			t_dapple += Time.get_ticks_usec() - t3
			t_terrain += t1 - t0
			t_plants += t2 - t1
			t_prepare += t3 - t2
			n += 1
	print("[chunks] %d species; %d chunks round the camp: terrain %.0f ms, plants %.0f ms, prepare %.0f ms, dappled shade %.0f ms each (%d with a shade map)" % [SpeciesDB.all().size(), n, t_terrain / 1000.0 / n, t_plants / 1000.0 / n, t_prepare / 1000.0 / n, t_dapple / 1000.0 / n, dappled])
	quit()

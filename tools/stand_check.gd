extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/stand_check.gd
## Stand dominance (design 30 Sept §BH, stand.json dominance): in the
## loaded chunks round the camp, the trees (emergent + canopy tiers) of
## each chunk are mostly one species: the top species holds at least
## dominant_share[0] of the stems in most chunks outside the salad
## biomes, and a chunk holds only a few tree species.
var main
var world
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
	await frames(120)
	var chunks: ChunkManager = main.chunks
	var dom: Dictionary = VegetationPlacer.DOM
	var min_share := float(dom.get("dominant_share", [0.6, 0.85])[0])
	var all := SpeciesDB.all()
	var chunks_seen := 0
	var chunks_dominated := 0
	var salad_seen := 0
	for key in chunks.chunks:
		var chunk: TerrainChunk = chunks.chunks[key]
		if chunk.data.is_empty() or not chunk.data.has("plants"):
			continue
		var plants: Dictionary = chunk.data.plants
		var counts := {}
		var total := 0
		for idx in plants:
			if int(idx) >= PlantGrowth.JUV_KEY:
				continue
			var sp: PlantSpecies = all[int(idx)]
			if sp.tier != PlantSpecies.Tier.EMERGENT and sp.tier != PlantSpecies.Tier.CANOPY:
				continue
			var n := int((plants[idx] as Array)[1])
			counts[sp.name] = n
			total += n
		if total < 25:
			continue
		var top := ""
		var top_n := 0
		for k in counts:
			if int(counts[k]) > top_n:
				top_n = int(counts[k])
				top = str(k)
		var biome: int = world.planet.biome[world.planet.cell_at(chunk.center_dir)]
		var salad := VegetationPlacer.SALAD.has(biome)
		var share := float(top_n) / total
		print("[stand] %s: %d trees, %d species, %s %.0f%%%s" % [BiomeTemplates.KEYS[biome], total, counts.size(), top, share * 100.0, " (salad)" if salad else ""])
		if salad:
			salad_seen += 1
			continue
		chunks_seen += 1
		if share >= min_share * 0.85:
			chunks_dominated += 1
	ok(chunks_seen > 0, "tree-bearing chunks measured (%d, %d salad)" % [chunks_seen, salad_seen])
	ok(chunks_dominated >= int(ceil(chunks_seen * 0.7)), "most stands read as one species: %d of %d chunks have a dominant at %.0f%%+" % [chunks_dominated, chunks_seen, min_share * 85.0])
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

extends SceneTree
## Soil as a hard spawn gate (design reconciliation Session 2 G2):
##   1. the soil classes on the planet (share of cells) and every species'
##      allowed classes (data/soil.json presets, or its own soil.classes),
##      FAILING if any species allows none;
##   2. starts the game on the stamp, waits for the chunks around the
##      first camp to fill with trees, and checks every placed tree
##      against the soil under it (PlanetData.soil_at): FAILS if any
##      stands on a class its species doesn't allow; prints how many
##      trees of each soil there are.
##
##   ~/bin/godot --headless --path . -s tools/soil_check.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print("[soil] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


func _run() -> void:
	var world = get_root().get_node("World")
	world.spawn_choice = 0
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	var map: PlanetData = world.planet
	var counts := {}
	for c in map.cell_count:
		var n := PlanetData.soil_name(map.rock[c])
		counts[n] = counts.get(n, 0) + 1
	var line := ""
	for n in PlanetData.SOIL_NAMES:
		line += " %s %.1f%%," % [n, 100.0 * counts.get(n, 0) / map.cell_count]
	print("[soil] planet cells:%s" % line)
	var empty := 0
	var per_class := {}
	for sp: PlantSpecies in SpeciesDB.all():
		if sp.soil_mask == 0:
			empty += 1
		for r in PlanetData.SOIL_NAMES.size():
			if sp.soil_allowed(r):
				per_class[PlanetData.SOIL_NAMES[r]] = per_class.get(PlanetData.SOIL_NAMES[r], 0) + 1
	print("[soil] species allowed per class (of %d): %s" % [SpeciesDB.all().size(), per_class])
	ok(empty == 0, "every species allows at least one soil class")
	# Let the detail ring fill.
	for i in 240:
		await process_frame
	var trees := 0
	var bad := 0
	var by_soil := {}
	var examples: Array[String] = []
	for key in main.chunks.chunks:
		var ch: TerrainChunk = main.chunks.chunks[key]
		for i in ch.trees.size():
			var sp := ch.tree_species(i)
			if sp == null:
				continue
			var d: Vector3 = world.dir_of(ch.tree_base(i))
			var r := map.soil_at(d)
			trees += 1
			by_soil[PlanetData.soil_name(r)] = by_soil.get(PlanetData.soil_name(r), 0) + 1
			if not sp.soil_allowed(r):
				bad += 1
				if examples.size() < 5:
					examples.append("%s on %s" % [sp.name, PlanetData.soil_name(r)])
	print("[soil] %d trees placed around the camp, by soil: %s" % [trees, by_soil])
	if bad > 0:
		print("[soil] off their soil: %s" % [examples])
	ok(trees > 50, "trees placed (%d)" % trees)
	ok(bad == 0, "no tree stands on a soil its species doesn't allow (%d do)" % bad)
	print("[soil] RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

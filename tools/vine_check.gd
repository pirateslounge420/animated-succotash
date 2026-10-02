extends SceneTree
## Vines on every surface (design 1 Oct §CE; data/vines.json): at a site
## in each biome asked (BIOMES, default a temperate forest and a jungle)
## on the full planet, which surfaces carry a vine species — trunks of
## living trees, dead wood, cliffs (hanging patches), the ground
## (creeping patches) and the nearest ruin of that biome (walls, heaps
## and its tumbled boulders) — and that a
## restored ruin is cut back (rung 1 half, rung 2 bare) and a fresh
## abandoned one has none yet.
##   SEED=7731 godot --headless --path . --fixed-fps 60 --script tools/vine_check.gd

var fails := 0
var world
var main
var player


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	world = get_root().get_node("World")
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7731
	world.pin(seed_v, 0)
	Bow.need_capture = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	player = main.player
	await frames(20)
	var map: PlanetData = world.planet
	var chunks: ChunkManager = main.chunks
	var biomes := ["TEMPERATE_DECIDUOUS", "TROPICAL_RAINFOREST"]
	if OS.get_environment("BIOMES") != "":
		biomes = Array(OS.get_environment("BIOMES").split(","))
	var all := SpeciesDB.all()
	for key in biomes:
		var bid := BiomeTemplates.KEYS.find(key)
		# A land cell of the biome where a vine species fits.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_v, key, "vines"])
		var cells: Array = []
		for c in map.cell_count:
			if map.biome[c] == bid and map.water[c] == PlanetData.Water.NONE:
				cells.append(c)
		var site := -1
		for k in 200:
			if cells.is_empty():
				break
			var c: int = cells[rng.randi() % cells.size()]
			if VineCover.species_at(map.dir[c], bid, map.temp_c[c], map.moisture[c], map.elevation[c], map.rock[c]) != null:
				site = c
				break
		if site < 0:
			ok(false, "%s: a site where a vine species fits" % key)
			continue
		var d: Vector3 = map.dir[site]
		var off_v: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
		world.rebase(off_v)
		player.global_position -= off_v
		chunks.load_blocking(d)
		player.spawn_at(d)
		await frames(240)
		# Trees: custom data (moss, vines + leaf code, rustle, bare) of every tree in
		# the loaded chunks; bare 1 is dead wood.
		var trunks := 0
		var trunks_vined := 0
		var dead := 0
		var dead_vined := 0
		var patches := {"hang": 0, "creep": 0}
		var vine_names := {}
		for ch in chunks.chunks.values():
			var chunk := ch as TerrainChunk
			if chunk == null:
				continue
			for e in chunk._bands.values():
				if not (e as Dictionary).has("mmis"):
					continue
				var buf: PackedFloat32Array = e.buf
				for i in int(e.n):
					var k := i * 20
					# Custom g carries the vines with the leaf-size code.
					var v := PlantGrowth.vines_of(buf[k + 17])
					if buf[k + 19] >= 0.99:
						dead += 1
						dead_vined += 1 if v > 0.0 else 0
					else:
						trunks += 1
						trunks_vined += 1 if v > 0.0 else 0
			if chunk.detail_node == null:
				continue
			for n in chunk.detail_node.get_children():
				if n is MultiMeshInstance3D and n.has_meta("vine"):
					var form := "hang" if str(n.name).ends_with("_hang") else "creep"
					var cnt: int = int(chunk._bands[n].n) if chunk._bands.has(n) else (n as MultiMeshInstance3D).multimesh.instance_count
					patches[form] += cnt
					var nm: String = all[int(n.get_meta("species"))].name
					vine_names[nm] = int(vine_names.get(nm, 0)) + cnt
		print("[vines] %s at %s (%.1f °C, moisture %.2f): trunks %d of %d vined, dead wood %d of %d, cliff patches %d, ground patches %d; species %s" % [
			key, str(d), map.temp_c[site], map.moisture[site], trunks_vined, trunks, dead_vined, dead, patches.hang, patches.creep, str(vine_names)])
		ok(trunks_vined > 0, "%s: vines on living trunks (%d of %d)" % [key, trunks_vined, trunks])
		ok(patches.hang + patches.creep > 0, "%s: vine patches on cliffs or the ground (%d hanging, %d creeping)" % [key, patches.hang, patches.creep])
		# The nearest ruin of this biome: built, dressed as Landmarks
		# dresses it, then cut back by a restoring camp.
		var ruin := {}
		var ruin_c := Vector3i.ZERO
		var best := INF
		for c in CreatureSpawner._cells_around(d, 60000.0, Ruins.CELL_M):
			var s := Ruins.find(map, c)
			if s.is_empty() or map.biome[map.cell_at(s.dir)] != bid:
				continue
			var dist := CubeSphere.surface_distance_m(s.dir, d)
			if dist < best:
				best = dist
				ruin = s
				ruin_c = c
		if ruin.is_empty():
			print("[vines] %s: no ruin of this biome within 60 km; ruin vines not tried here" % key)
			continue
		var data := RuinBuilder.compute(map, ruin)
		var node := RuinBuilder.make_node(data, world)
		get_root().add_child(node)
		main.landmarks._dress_vines(node, ruin_c, data)
		var vn := node.get_node_or_null("Vines") as MultiMeshInstance3D
		var full := vn.multimesh.instance_count if vn != null else 0
		var bn := node.get_node_or_null("Vines_boulder") as MultiMeshInstance3D
		var on_rocks := bn.multimesh.instance_count if bn != null else 0
		var anchors: Array = data.get("vine_anchors", [])
		var sp := VineCover.species_at(ruin.dir, bid, map.sample(map.temp_c, ruin.dir), map.sample(map.moisture, ruin.dir), map.terrain.elevation(ruin.dir, true), map.soil_at(ruin.dir))
		var counts := []
		for leg in [1, 2]:
			var probe := Node3D.new()
			probe.name = node.name
			var mmi := VineCover.ruin_patches(probe, anchors, sp, map.sample(map.moisture, ruin.dir), map.sample(map.temp_c, ruin.dir), 40.0, leg)
			counts.append(mmi.multimesh.instance_count if mmi != null else 0)
			probe.free()
		var fresh := Node3D.new()
		fresh.name = node.name
		var fresh_mmi := VineCover.ruin_patches(fresh, anchors, sp, map.sample(map.moisture, ruin.dir), map.sample(map.temp_c, ruin.dir), 0.0, 0)
		var fresh_n: int = fresh_mmi.multimesh.instance_count if fresh_mmi != null else 0
		fresh.free()
		print("[vines] %s: ruin (%s) %.1f km off, %d ivy strands, %s on %d; %d tumbled boulders, vines on %d; restored rung 1: %d, rung 2: %d; just abandoned: %d" % [
			key, Ruins.Kind.keys()[ruin.kind], best / 1000.0, anchors.size(), sp.name if sp != null else "no vine species", full, (data.get("boulder_anchors", []) as Array).size(), on_rocks, counts[0], counts[1], fresh_n])
		if sp != null and not anchors.is_empty():
			ok(full > 0, "%s: vines over the ruin's walls and heaps (%d)" % [key, full])
			ok(counts[0] < full and counts[1] == 0, "%s: a restoring camp cuts them back (%d -> %d -> %d)" % [key, full, counts[0], counts[1]])
			ok(fresh_n == 0, "%s: a just-abandoned camp has none yet (the forest takes it back over time)" % key)
		node.queue_free()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

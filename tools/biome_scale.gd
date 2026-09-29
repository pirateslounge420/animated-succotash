extends SceneTree
## How big the biomes are (from play, 2026-09-29: "the biomes change too
## fast"; "every playthrough needs at least one continent of each biome").
## For each seed, generates the planet (the full 4,000 km one; STAMP=1 the
## dev postage stamp instead) and prints, per major biome band (data/dev.json
## "stamp"."bands", land bands only):
##   - its share of the land and its area (km2);
##   - its largest single region (cells joined edge to edge) in km2 and
##     across (the diameter of a disc of that area, km);
##   - how far you walk in a straight line, on average, before the biome
##     changes (random straight walks over land, stepping a tenth of a
##     cell).
## And which bands have no region of at least MIN_REGION_KM2 (env; default
## 25 km2, a 5 x 5 km block: an hour's walk across).
##
##   ~/bin/godot --headless --path . --script tools/biome_scale.gd
## SEEDS="42,7,1234" (default), STAMP=1, MIN_REGION_KM2=25.

var world: Node


func _initialize() -> void:
	world = get_root().get_node("World")
	_run.call_deferred()


func _run() -> void:
	world._load_dev_settings()
	var seeds := (OS.get_environment("SEEDS") if OS.get_environment("SEEDS") != "" else "42,7,1234").split(",")
	var min_km2 := float(OS.get_environment("MIN_REGION_KM2")) if OS.get_environment("MIN_REGION_KM2") != "" else 25.0
	world.use_postage_stamp(OS.get_environment("STAMP") == "1")
	var bands: Dictionary = (world.dev.get("stamp", {}) as Dictionary).get("bands", {})
	# Biome id -> band name (land bands: no water, no ocean).
	var band_of := {}
	for band in bands:
		if band in ["Ocean", "Rivers", "Lakes"]:
			continue
		for key in bands[band]:
			var id := BiomeTemplates.id_of_key(str(key))
			if id >= 0:
				band_of[id] = band
	for s in seeds:
		var t0 := Time.get_ticks_msec()
		world.generate_now(int(s))
		var map: PlanetData = world.planet
		var km2 := (map.cell_m() / 1000.0) * (map.cell_m() / 1000.0)
		print("[biomes] seed %s: %.0f km around, %d cells of %.2f km, generated in %d ms" % [s, PlanetConst.CIRCUMFERENCE_M / 1000.0, map.cell_count, map.cell_m() / 1000.0, Time.get_ticks_msec() - t0])
		var band_cell := PackedInt32Array()
		band_cell.resize(map.cell_count)
		var names: Array = bands.keys().filter(func(b): return not (b in ["Ocean", "Rivers", "Lakes"]))
		var land := 0
		for c in map.cell_count:
			var b = band_of.get(map.biome[c])
			band_cell[c] = names.find(b) if b != null and map.water[c] != PlanetData.Water.OCEAN else -1
			land += 1 if band_cell[c] >= 0 else 0
		# Regions: flood fill over the cell neighbours.
		var seen := PackedByteArray()
		seen.resize(map.cell_count)
		var total := {}
		var largest := {}
		for c in map.cell_count:
			var b := band_cell[c]
			if b < 0 or seen[c] == 1:
				continue
			var size := 0
			var stack := PackedInt32Array([c])
			seen[c] = 1
			while not stack.is_empty():
				var x := stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				size += 1
				for k in 4:
					var nb := map.neighbor(x, k)
					if nb >= 0 and seen[nb] == 0 and band_cell[nb] == b:
						seen[nb] = 1
						stack.append(nb)
			total[b] = int(total.get(b, 0)) + size
			largest[b] = maxi(int(largest.get(b, 0)), size)
		# Straight walks: mean run before the band changes.
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var runs := {}
		var step_m := map.cell_m() * 0.1
		for w in 600:
			var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var b0 := band_cell[map.cell_at(d)]
			if b0 < 0:
				continue
			var heading := CubeSphere.north(d).rotated(d, rng.randf() * TAU)
			var walked := 0.0
			while walked < 200000.0:
				var ax := d.cross(heading).normalized()
				d = d.rotated(ax, step_m / PlanetConst.RADIUS_M).normalized()
				heading = (heading - d * heading.dot(d)).normalized()
				walked += step_m
				if band_cell[map.cell_at(d)] != b0:
					break
			(runs.get_or_add(b0, []) as Array).append(walked)
		var missing: Array[String] = []
		for i in names.size():
			var n := int(total.get(i, 0))
			var big := int(largest.get(i, 0)) * km2
			var r: Array = runs.get(i, [])
			var mean := 0.0
			for v in r:
				mean += v
			mean = mean / r.size() if not r.is_empty() else 0.0
			print("  %-28s %4.1f%% of land, %7.0f km2, largest region %6.0f km2 (%4.1f km across), a straight walk stays %5.1f km" % [
				names[i], 100.0 * n / maxf(land, 1), n * km2, big, 2.0 * sqrt(big / PI), mean / 1000.0])
			if big < min_km2:
				missing.append(names[i])
		print("[biomes] seed %s: %d land bands without a region of %.0f km2: %s" % [s, missing.size(), min_km2, ", ".join(missing) if not missing.is_empty() else "none"])
	quit()

class_name TerrainPass
## Pass 1: samples TerrainField at every blueprint cell center (no fine
## detail layer; cells are ~1 km) and derives slope.
## Reads: nothing. Writes: elevation, slope.


static func run(map: PlanetData) -> void:
	var dirs := map.dir
	var elev := PackedFloat32Array()
	elev.resize(map.cell_count)
	for c in map.cell_count:
		elev[c] = map.terrain.elevation(dirs[c])

	var slope := PackedFloat32Array()
	slope.resize(map.cell_count)
	for c in map.cell_count:
		var steepest := 0.0
		for k in 4:
			var n := map.neighbors[c * 8 + k]
			var run_m := (dirs[c] - dirs[n]).length() * PlanetConst.RADIUS_M
			if run_m > 0.0:
				steepest = maxf(steepest, absf(elev[c] - elev[n]) / run_m)
		slope[c] = steepest

	map.elevation = elev
	map.slope = slope

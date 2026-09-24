class_name HydrologyPass
## Water on the planet, in two steps because rivers need rainfall and the
## weather simulation needs to know where the seas and lakes are:
##
## basins() — before weather:
##   * Ocean = below-sea-level regions large enough to be seas; small
##     below-sea basins stay inland (they become lakes below).
##   * Priority-flood depression filling (Barnes et al. 2014) from the
##     ocean inward. Every inland basin fills to its spill level, so lakes
##     get a real surface height, and every land cell gets a downstream
##     neighbor (flow_to) so water always reaches the sea.
##   * Distance to the coast.
##
## rivers() — after climate:
##   * Discharge = rainfall summed downstream along flow_to.
##   * The highest-discharge land cells become rivers.
##   * Salinity: ocean salt; lakes fresh unless their basin is hot and dry
##     enough to evaporate more than it gets (salt lakes / salt flats);
##     river mouths brackish.
##   * Distance to any water, used by vegetation ("water gradient") and
##     biome rules.

## Below-sea regions smaller than this many cells are inland basins, not sea.
const OCEAN_MIN_CELLS := 300
## A cell is lake if filling raised it more than this.
const LAKE_MIN_DEPTH_M := 3.0
const FILL_EPSILON_M := 0.01
## Share of land cells that carry a river.
const RIVER_LAND_FRACTION := 0.035
const SALT_LAKE_MAX_PRECIP_MM := 350.0
const SALT_LAKE_MIN_TEMP_C := 8.0

const _BUCKET_MIN_M := -5000.0
const _BUCKET_COUNT := 12000 # 1 m buckets from -5000 to +7000


static func basins(map: PlanetData) -> void:
	var n := map.cell_count
	var elev := map.elevation
	var nbrs := map.neighbors
	var water := PackedByteArray()
	water.resize(n)
	var salinity := PackedByteArray()
	salinity.resize(n)

	_mark_oceans(map, water)

	# Priority flood with a bucket queue (1 m buckets). Keys only ever
	# increase, so a bucket queue is a valid priority queue here.
	var filled := elev.duplicate()
	var visited := PackedByteArray()
	visited.resize(n)
	var flow_to := PackedInt32Array()
	flow_to.resize(n)
	flow_to.fill(-1)
	var order := PackedInt32Array()
	var buckets: Array = []
	buckets.resize(_BUCKET_COUNT)
	for b in _BUCKET_COUNT:
		buckets[b] = []

	var seeded := 0
	for c in n:
		if water[c] == PlanetData.Water.OCEAN:
			filled[c] = PlanetConst.SEA_LEVEL_M
			visited[c] = 1
			buckets[_bucket(0.0)].append(c)
			seeded += 1
	if seeded == 0:
		# Waterworld guard: drain everything to the lowest point.
		var lowest := 0
		for c in n:
			if elev[c] < elev[lowest]:
				lowest = c
		visited[lowest] = 1
		buckets[_bucket(elev[lowest])].append(lowest)

	for b in _BUCKET_COUNT:
		var bucket: Array = buckets[b]
		var i := 0
		while i < bucket.size():
			var c: int = bucket[i]
			i += 1
			order.append(c)
			for k in 8:
				var nb := nbrs[c * 8 + k]
				if visited[nb] == 1:
					continue
				visited[nb] = 1
				var key := maxf(elev[nb], filled[c] + FILL_EPSILON_M)
				filled[nb] = key
				flow_to[nb] = c
				buckets[_bucket(key)].append(nb)
		buckets[b] = [] # free memory as we go

	var water_level := PackedFloat32Array()
	water_level.resize(n)
	for c in n:
		if water[c] == PlanetData.Water.OCEAN:
			water_level[c] = PlanetConst.SEA_LEVEL_M
			salinity[c] = PlanetData.Salinity.SALT
		elif filled[c] - elev[c] > LAKE_MIN_DEPTH_M:
			water[c] = PlanetData.Water.LAKE
			water_level[c] = filled[c]
		else:
			water_level[c] = elev[c]

	map.water = water
	map.salinity = salinity
	map.water_level = water_level
	map.flow_to = flow_to
	map.flow_order = order
	map.coast_dist_km = _distance_from(map, water, true)


static func _bucket(key: float) -> int:
	return clampi(int(key - _BUCKET_MIN_M), 0, _BUCKET_COUNT - 1)


static func _mark_oceans(map: PlanetData, water: PackedByteArray) -> void:
	var n := map.cell_count
	var elev := map.elevation
	var nbrs := map.neighbors
	var comp_seen := PackedByteArray()
	comp_seen.resize(n)
	for start in n:
		if comp_seen[start] == 1 or elev[start] >= PlanetConst.SEA_LEVEL_M:
			continue
		var members := PackedInt32Array([start])
		comp_seen[start] = 1
		var head := 0
		while head < members.size():
			var c := members[head]
			head += 1
			for k in 4:
				var nb := nbrs[c * 8 + k]
				if comp_seen[nb] == 0 and elev[nb] < PlanetConst.SEA_LEVEL_M:
					comp_seen[nb] = 1
					members.append(nb)
		if members.size() >= OCEAN_MIN_CELLS:
			for c in members:
				water[c] = PlanetData.Water.OCEAN


static func rivers(map: PlanetData) -> void:
	var n := map.cell_count
	var water := map.water.duplicate()
	var salinity := map.salinity.duplicate()
	var water_level := map.water_level.duplicate()
	var elev := map.elevation
	var flow_to := map.flow_to
	var order := map.flow_order
	var nbrs := map.neighbors

	# Discharge: each cell's own rainfall (m/yr per cell) plus everything
	# upstream of it. Walk from the headwaters down (reverse flood order).
	var accum := PackedFloat32Array()
	accum.resize(n)
	for c in n:
		if water[c] != PlanetData.Water.OCEAN:
			accum[c] = maxf(map.precip_mm[c], 0.0) / 1000.0
	for idx in range(order.size() - 1, -1, -1):
		var c := order[idx]
		var t := flow_to[c]
		if t >= 0 and water[c] != PlanetData.Water.OCEAN:
			accum[t] += accum[c]

	var land_accum := PackedFloat32Array()
	for c in n:
		if water[c] == PlanetData.Water.NONE:
			land_accum.append(accum[c])
	land_accum.sort()
	var threshold := INF
	if not land_accum.is_empty():
		threshold = land_accum[int((1.0 - RIVER_LAND_FRACTION) * (land_accum.size() - 1))]

	for c in n:
		if water[c] == PlanetData.Water.NONE and accum[c] >= threshold:
			water[c] = PlanetData.Water.RIVER
			water_level[c] = elev[c]

	# River mouths are brackish.
	for c in n:
		if water[c] != PlanetData.Water.RIVER:
			continue
		for k in 8:
			if water[nbrs[c * 8 + k]] == PlanetData.Water.OCEAN:
				salinity[c] = PlanetData.Salinity.BRACKISH
				break

	_mark_salt_lakes(map, water, salinity)

	map.water = water
	map.salinity = salinity
	map.water_level = water_level
	map.flow_accum = accum
	map.water_dist_km = _distance_from(map, water, false)


## A lake whose basin is hot and dry evaporates more than it receives and
## turns salt, like the Great Salt Lake or the Dead Sea.
static func _mark_salt_lakes(map: PlanetData, water: PackedByteArray, salinity: PackedByteArray) -> void:
	var nbrs := map.neighbors
	var seen := PackedByteArray()
	seen.resize(map.cell_count)
	for start in map.cell_count:
		if seen[start] == 1 or water[start] != PlanetData.Water.LAKE:
			continue
		var members := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		var precip_sum := 0.0
		var temp_sum := 0.0
		while head < members.size():
			var c := members[head]
			head += 1
			precip_sum += map.precip_mm[c]
			temp_sum += map.temp_c[c]
			for k in 8:
				var nb := nbrs[c * 8 + k]
				if seen[nb] == 0 and water[nb] == PlanetData.Water.LAKE:
					seen[nb] = 1
					members.append(nb)
		var count := float(members.size())
		var salty := precip_sum / count < SALT_LAKE_MAX_PRECIP_MM and temp_sum / count > SALT_LAKE_MIN_TEMP_C
		var s := PlanetData.Salinity.SALT if salty else PlanetData.Salinity.FRESH
		for c in members:
			salinity[c] = s


## Multi-source BFS distance in km from ocean cells (ocean_only) or from
## any water. Counts 8-neighbor steps, so diagonals are slightly short;
## fine for gradients.
static func _distance_from(map: PlanetData, water: PackedByteArray, ocean_only: bool) -> PackedFloat32Array:
	var nbrs := map.neighbors
	var dist := PackedFloat32Array()
	dist.resize(map.cell_count)
	dist.fill(INF)
	var queue := PackedInt32Array()
	for c in map.cell_count:
		var is_source := water[c] == PlanetData.Water.OCEAN if ocean_only else water[c] != PlanetData.Water.NONE
		if is_source:
			dist[c] = 0.0
			queue.append(c)
	var step := map.cell_km()
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for k in 8:
			var nb := nbrs[c * 8 + k]
			if dist[nb] > dist[c] + step:
				dist[nb] = dist[c] + step
				queue.append(nb)
	return dist

extends RefCounted
class_name WaterPass
## Pass 2: fills everything at/below sea level as ocean/lake, then traces
## rivers flowing downhill from high ground toward the sea.
##
## Reads map.height (pass 1). Writes map.water_type.

const RIVER_SOURCE_MIN_HEIGHT := 14.0
const RIVER_SOURCE_COUNT := 14
const RIVER_MAX_STEPS := 400

const NEIGHBORS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]


static func generate(map: WorldMapData) -> void:
	_flood_fill_ocean(map)
	_mark_lakes(map)
	_trace_rivers(map)


## BFS flood fill from the map border: any below-sea-level cell reachable
## from the border through other below-sea-level cells is open ocean.
static func _flood_fill_ocean(map: WorldMapData) -> void:
	var visited := PackedByteArray()
	visited.resize(map.resolution * map.resolution)
	var queue: Array[Vector2i] = []

	for x in range(map.resolution):
		_try_enqueue_ocean(map, visited, queue, x, 0)
		_try_enqueue_ocean(map, visited, queue, x, map.resolution - 1)
	for y in range(map.resolution):
		_try_enqueue_ocean(map, visited, queue, 0, y)
		_try_enqueue_ocean(map, visited, queue, map.resolution - 1, y)

	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		map.water_type[map.index(cell.x, cell.y)] = WorldMapData.WaterType.OCEAN
		for offset in NEIGHBORS_4:
			var n := cell + offset
			_try_enqueue_ocean(map, visited, queue, n.x, n.y)


static func _try_enqueue_ocean(map: WorldMapData, visited: PackedByteArray, queue: Array[Vector2i], x: int, y: int) -> void:
	if not map.in_bounds(x, y):
		return
	var idx := map.index(x, y)
	if visited[idx] == 1:
		return
	if map.height[idx] > map.sea_level:
		return
	visited[idx] = 1
	queue.append(Vector2i(x, y))


## Any remaining below-sea-level cell the ocean flood fill never reached
## is an enclosed basin -- a lake.
static func _mark_lakes(map: WorldMapData) -> void:
	for i in range(map.height.size()):
		if map.height[i] <= map.sea_level and map.water_type[i] == WorldMapData.WaterType.NONE:
			map.water_type[i] = WorldMapData.WaterType.LAKE


static func _trace_rivers(map: WorldMapData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.world_seed + 100
	for source in _pick_river_sources(map, rng):
		_trace_single_river(map, source)


static func _pick_river_sources(map: WorldMapData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y in range(map.resolution):
		for x in range(map.resolution):
			if map.height[map.index(x, y)] >= RIVER_SOURCE_MIN_HEIGHT:
				candidates.append(Vector2i(x, y))
	var sources: Array[Vector2i] = []
	if candidates.is_empty():
		return sources
	for i in range(RIVER_SOURCE_COUNT):
		sources.append(candidates[rng.randi() % candidates.size()])
	return sources


## Steepest-descent walk from a source cell until it reaches existing
## water, the map edge, or a local minimum it can't descend from further.
static func _trace_single_river(map: WorldMapData, start: Vector2i) -> void:
	var current := start
	var visited_this_river := {}
	for step in range(RIVER_MAX_STEPS):
		var idx := map.index(current.x, current.y)
		var wt: int = map.water_type[idx]
		if wt == WorldMapData.WaterType.OCEAN or wt == WorldMapData.WaterType.LAKE:
			return
		if wt == WorldMapData.WaterType.NONE:
			map.water_type[idx] = WorldMapData.WaterType.RIVER
		visited_this_river[current] = true

		var next := _lowest_neighbor(map, current)
		if next == current or visited_this_river.has(next):
			return # dead end / loop -- ends as an inland terminus
		current = next


static func _lowest_neighbor(map: WorldMapData, cell: Vector2i) -> Vector2i:
	var best := cell
	var best_height := map.height[map.index(cell.x, cell.y)]
	for offset in NEIGHBORS_8:
		var n := cell + offset
		if not map.in_bounds(n.x, n.y):
			continue
		var h := map.height[map.index(n.x, n.y)]
		if h < best_height:
			best_height = h
			best = n
	return best

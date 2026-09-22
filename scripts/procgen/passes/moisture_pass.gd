extends RefCounted
class_name MoisturePass
## Pass 4: moisture spreads outward from water bodies (pass 2's ocean/
## lake/river cells), decaying with distance, then gets reduced by a
## rain-shadow effect on the leeward side of mountain ridges relative to
## a prevailing wind direction -- this is what makes one side of a
## mountain range moist and the other dry (DESIGN.md section 3).
## fog_chance rides along: high on the moist, windward (un-shadowed)
## side; low in a rain shadow even where some residual moisture remains.
##
## Reads map.height (pass 1) and map.water_type (pass 2). Writes
## map.moisture and map.fog_chance.

const DISTANCE_DECAY := 0.05 # higher = moisture fades faster with distance from water
const RIDGE_DROP_THRESHOLD := 2.0 # how far below the tallest ridge-so-far before shadowing starts
const SHADOW_FALLOFF_HEIGHT := 18.0
const MIN_SHADOW_FACTOR := 0.08

## Prevailing wind blows in +X: moisture picked up on the low-X (west)
## side is carried east and rained out on windward slopes before it can
## reach the far side of a ridge.
const WIND_DIR := Vector2i(1, 0)

const NEIGHBORS_4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(map: WorldMapData) -> void:
	var distance_to_water := _distance_to_water(map)
	var shadow_factor := _rain_shadow_factor(map)

	for i in range(map.height.size()):
		var base_moisture := exp(-distance_to_water[i] * DISTANCE_DECAY)
		if map.water_type[i] != WorldMapData.WaterType.NONE:
			base_moisture = 1.0
		var moisture := clampf(base_moisture * shadow_factor[i], 0.0, 1.0)
		map.moisture[i] = moisture
		map.fog_chance[i] = clampf(moisture * lerpf(0.15, 1.0, shadow_factor[i]), 0.0, 1.0)


## Multi-source BFS distance (in grid cells) from every water cell.
static func _distance_to_water(map: WorldMapData) -> PackedFloat32Array:
	var n := map.resolution * map.resolution
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)

	var queue: Array[Vector2i] = []
	for y in range(map.resolution):
		for x in range(map.resolution):
			var idx := map.index(x, y)
			if map.water_type[idx] != WorldMapData.WaterType.NONE:
				dist[idx] = 0.0
				queue.append(Vector2i(x, y))

	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var cell_idx := map.index(cell.x, cell.y)
		for offset in NEIGHBORS_4:
			var n_cell := cell + offset
			if not map.in_bounds(n_cell.x, n_cell.y):
				continue
			var n_idx := map.index(n_cell.x, n_cell.y)
			if dist[n_idx] > dist[cell_idx] + 1.0:
				dist[n_idx] = dist[cell_idx] + 1.0
				queue.append(n_cell)
	return dist


## Marches along the wind direction for each row, tracking the tallest
## ridge crossed so far. A cell well below that running peak is in its
## rain shadow (leeward side); a cell still climbing toward it, or at a
## new peak, is windward/unshadowed.
static func _rain_shadow_factor(map: WorldMapData) -> PackedFloat32Array:
	var factor := PackedFloat32Array()
	factor.resize(map.resolution * map.resolution)

	# This march assumes a horizontal (+/-X) wind; a vertical wind would
	# swap the x/y roles below.
	var x_start := 0
	var x_step := 1
	if WIND_DIR.x < 0:
		x_start = map.resolution - 1
		x_step = -1

	for y in range(map.resolution):
		var running_peak := -INF
		var x := x_start
		for _i in range(map.resolution):
			var idx := map.index(x, y)
			var h := map.height[idx]
			if h >= running_peak:
				running_peak = h
				factor[idx] = 1.0
			else:
				var drop := running_peak - h - RIDGE_DROP_THRESHOLD
				factor[idx] = clampf(1.0 - drop / SHADOW_FALLOFF_HEIGHT, MIN_SHADOW_FACTOR, 1.0)
			x += x_step
	return factor

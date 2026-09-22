extends RefCounted
class_name HeightmapPass
## Pass 1: terrain height from a seed.
##
## Two noise layers combine: a low-frequency layer shapes the overall
## continent (so the map has land and sea, not uniform noise), and a
## ridged-fractal layer adds mountain ridges on top. Ridged noise
## naturally produces the kind of linear mountain chains that make the
## rain-shadow behavior in MoisturePass visually obvious to verify.
##
## Reads nothing (first pass). Writes map.height.

const CONTINENT_FREQUENCY := 0.006
const CONTINENT_AMPLITUDE := 18.0
const CONTINENT_BASE := 6.0 # lifts most of the map near/above sea level

const RIDGE_FREQUENCY := 0.02
const RIDGE_AMPLITUDE := 22.0

const DETAIL_FREQUENCY := 0.08
const DETAIL_AMPLITUDE := 3.0


static func generate(map: WorldMapData) -> void:
	var continent_noise := FastNoiseLite.new()
	continent_noise.seed = map.world_seed
	continent_noise.frequency = CONTINENT_FREQUENCY
	continent_noise.fractal_octaves = 4

	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = map.world_seed + 1
	ridge_noise.frequency = RIDGE_FREQUENCY
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.fractal_octaves = 3

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = map.world_seed + 2
	detail_noise.frequency = DETAIL_FREQUENCY

	for y in range(map.resolution):
		for x in range(map.resolution):
			var wp := map.cell_world_pos(x, y)
			var continent := continent_noise.get_noise_2d(wp.x, wp.y) * CONTINENT_AMPLITUDE + CONTINENT_BASE
			var ridge := ridge_noise.get_noise_2d(wp.x, wp.y) * RIDGE_AMPLITUDE
			# Only let ridges add height where the continent is already
			# reasonably high, so oceans don't sprout mountain spikes.
			var ridge_mask := clampf(inverse_lerp(-2.0, 10.0, continent), 0.0, 1.0)
			var detail := detail_noise.get_noise_2d(wp.x, wp.y) * DETAIL_AMPLITUDE
			map.height[map.index(x, y)] = continent + ridge * ridge_mask + detail

extends Node
## Shared procedural-generation configuration and math.
##
## Central source of truth for world seed, chunk size, and the noise/biome
## parameters described in DESIGN.md section 3 (heightmap, moisture,
## temperature -> biome lookup, plus river carving in 3.2). Terrain
## generation and gameplay systems (e.g. the boat) both read height/river
## queries from here so they never disagree about where dry land, banks,
## and navigable water are.

const CHUNK_SIZE: int = 64

enum Biome {
	FOREST,
	MOUNTAINS,
	DESERT,
	OCEAN,
	PLAINS,
	SNOW_TUNDRA,
	SWAMP,
}

## World-space height (Y) that river water sits at. Land generally sits
## above this; the riverbed is carved below it.
const WATER_LEVEL: float = 0.0
const RIVERBED_DEPTH: float = 2.0

## Land (Plains) heightmap shaping.
const LAND_BASE_HEIGHT: float = 2.0
const LAND_HEIGHT_AMPLITUDE: float = 3.0
const LAND_NOISE_FREQUENCY: float = 0.04

## River path: a gentle meander along X, offset in Z. Kept as simple
## trig + noise so both terrain generation and boat current queries can
## evaluate it cheaply at any world position without shared mesh data.
const RIVER_BASE_Z: float = 0.0
const RIVER_AMPLITUDE: float = 12.0
const RIVER_FREQUENCY: float = 0.02
const RIVER_HALF_WIDTH: float = 4.0
const RIVER_BANK_SMOOTH: float = 3.0
const RIVER_NAVIGABLE_THRESHOLD: float = 0.6

var _height_noise: FastNoiseLite


func _ready() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = 1
	_height_noise.frequency = LAND_NOISE_FREQUENCY


## River centerline Z position for a given world X.
func river_center_z(x: float) -> float:
	return RIVER_BASE_Z + sin(x * RIVER_FREQUENCY) * RIVER_AMPLITUDE


## 0.0 (dry land) -> 1.0 (river centerline), smoothed across the bank
## width so land-to-water is a gradient rather than a cliff.
func river_mask(x: float, z: float) -> float:
	var dist := absf(z - river_center_z(x))
	return 1.0 - smoothstep(RIVER_HALF_WIDTH, RIVER_HALF_WIDTH + RIVER_BANK_SMOOTH, dist)


## Dry-land height before any river carving is applied.
func land_height(x: float, z: float) -> float:
	return LAND_BASE_HEIGHT + _height_noise.get_noise_2d(x, z) * LAND_HEIGHT_AMPLITUDE


## Final terrain height at a world XZ position: land height blended down
## into the riverbed by river_mask.
func height_at(x: float, z: float) -> float:
	var mask := river_mask(x, z)
	var riverbed := WATER_LEVEL - RIVERBED_DEPTH
	return lerp(land_height(x, z), riverbed, mask)


## True where the river is deep/wide enough for a boat.
func is_navigable(x: float, z: float) -> bool:
	return river_mask(x, z) > RIVER_NAVIGABLE_THRESHOLD


## Current direction (normalized, horizontal) a boat drifts along at this
## position: the tangent of the river centerline.
func current_direction_at(x: float, _z: float) -> Vector3:
	var dz_dx := cos(x * RIVER_FREQUENCY) * RIVER_AMPLITUDE * RIVER_FREQUENCY
	return Vector3(1.0, 0.0, dz_dx).normalized()

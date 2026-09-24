extends RefCounted
class_name BiomePass
## Pass 5: looks up a biome from height, temperature, and moisture at
## each cell (docs/implementation-notes.md section 3.1). Three layers, checked in order:
##
##  1. Water cells are Ocean (salt) or Lake (fresh) directly.
##  2. Low, ocean-adjacent land is Beach, regardless of climate.
##  3. Elevated land (height >= MOUNTAIN_BASE_HEIGHT) goes through an
##     altitude zonation ladder -- snow cap, then bare alpine rock, then
##     dwarf/subalpine forest, then (if moist enough) cloud forest --
##     that bottoms out into the same lowland table as (4) once it's
##     warm enough at that elevation, so a mountain's own base reads as
##     ordinary jungle/forest/etc, matching real montane zonation.
##  4. Everything else is a Whittaker-style temperature/moisture lookup
##     into the lowland table (forest/jungle/savanna/prairie/desert/
##     swamp/marsh/bog).
##
## The altitude ladder is keyed on *temperature*, not raw height: since
## TemperaturePass already folds latitude and elevation lapse into one
## value, this makes the snow line sit lower (in absolute height) on a
## polar mountain than an equatorial one for free, without this pass
## needing to know about latitude itself.
##
## Reads map.height (1), map.water_type (2), map.temperature (3), and
## map.moisture (4). Writes map.biome (WorldGenConfig.Biome values).

const MOUNTAIN_BASE_HEIGHT := 12.0

const BEACH_MAX_HEIGHT := 3.0
const BEACH_OCEAN_SEARCH_RADIUS := 2

## Altitude-band temperature ceilings, checked coldest-first. A cell at
## or above MOUNTAIN_BASE_HEIGHT falls into the first band whose ceiling
## it's under.
const SNOW_BAND_MAX_TEMP := 0.12
const ALPINE_BAND_MAX_TEMP := 0.28
const DWARF_BAND_MAX_TEMP := 0.42
const CLOUD_BAND_MAX_TEMP := 0.6
const CLOUD_FOREST_MIN_MOISTURE := 0.45


static func generate(map: WorldMapData) -> void:
	for y in range(map.resolution):
		for x in range(map.resolution):
			map.biome[map.index(x, y)] = _classify(map, x, y)


static func _classify(map: WorldMapData, x: int, y: int) -> int:
	var idx := map.index(x, y)
	var wt: int = map.water_type[idx]
	if wt == WorldMapData.WaterType.OCEAN:
		return WorldGenConfig.Biome.OCEAN
	if wt == WorldMapData.WaterType.LAKE:
		return WorldGenConfig.Biome.LAKE

	var h := map.height[idx]
	var t := map.temperature[idx]
	var m := map.moisture[idx]

	if h < BEACH_MAX_HEIGHT and _near_ocean(map, x, y):
		return WorldGenConfig.Biome.BEACH

	if h >= MOUNTAIN_BASE_HEIGHT:
		return _classify_mountain_band(t, m)

	return _classify_lowland(t, m)


static func _near_ocean(map: WorldMapData, x: int, y: int) -> bool:
	var r := BEACH_OCEAN_SEARCH_RADIUS
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx := x + dx
			var ny := y + dy
			if not map.in_bounds(nx, ny):
				continue
			if map.water_type[map.index(nx, ny)] == WorldMapData.WaterType.OCEAN:
				return true
	return false


## Coldest/highest first: snow cap -> bare alpine rock -> dwarf/subalpine
## forest -> cloud forest (only if moist enough) -> falls through to the
## lowland table once it's warm enough at this elevation to be "the base
## of the mountain."
static func _classify_mountain_band(t: float, m: float) -> int:
	if t < SNOW_BAND_MAX_TEMP:
		return WorldGenConfig.Biome.SNOW_TUNDRA
	if t < ALPINE_BAND_MAX_TEMP:
		return WorldGenConfig.Biome.MOUNTAINS
	if t < DWARF_BAND_MAX_TEMP:
		return WorldGenConfig.Biome.DWARF_FOREST
	if t < CLOUD_BAND_MAX_TEMP:
		if m >= CLOUD_FOREST_MIN_MOISTURE:
			return WorldGenConfig.Biome.CLOUD_FOREST
		return WorldGenConfig.Biome.DWARF_FOREST
	return _classify_lowland(t, m)


## Whittaker-style temperature/moisture lookup for non-elevated (or
## warm-enough-at-elevation) land.
static func _classify_lowland(t: float, m: float) -> int:
	if t < 0.2:
		return WorldGenConfig.Biome.SNOW_TUNDRA
	elif t < 0.45: # cool
		if m < 0.3:
			return WorldGenConfig.Biome.PRAIRIE
		elif m < 0.75:
			return WorldGenConfig.Biome.FOREST
		return WorldGenConfig.Biome.BOG
	elif t < 0.75: # temperate
		if m < 0.25:
			return WorldGenConfig.Biome.DESERT
		elif m < 0.55:
			return WorldGenConfig.Biome.PRAIRIE
		elif m < 0.8:
			return WorldGenConfig.Biome.FOREST
		return WorldGenConfig.Biome.MARSH
	else: # hot
		if m < 0.3:
			return WorldGenConfig.Biome.DESERT
		elif m < 0.55:
			return WorldGenConfig.Biome.SAVANNA
		elif m < 0.8:
			return WorldGenConfig.Biome.JUNGLE
		return WorldGenConfig.Biome.SWAMP

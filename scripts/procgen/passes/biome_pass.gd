extends RefCounted
class_name BiomePass
## Pass 5: looks up a biome from the (temperature, moisture) pair at
## each cell -- a Whittaker-diagram-style table, per DESIGN.md section 3.
## Water cells become Ocean directly; cells above MOUNTAIN_HEIGHT become
## Mountains regardless of climate (elevation dominates biome at that
## scale, matching the Mountains entry in DESIGN.md's biome table).
##
## Reads map.height (1), map.water_type (2), map.temperature (3), and
## map.moisture (4). Writes map.biome (WorldGenConfig.Biome values).

const MOUNTAIN_HEIGHT := 20.0


static func generate(map: WorldMapData) -> void:
	for i in range(map.height.size()):
		map.biome[i] = _classify(map, i)


static func _classify(map: WorldMapData, i: int) -> int:
	var wt: int = map.water_type[i]
	if wt == WorldMapData.WaterType.OCEAN or wt == WorldMapData.WaterType.LAKE:
		return WorldGenConfig.Biome.OCEAN

	if map.height[i] >= MOUNTAIN_HEIGHT:
		return WorldGenConfig.Biome.MOUNTAINS

	var t := map.temperature[i]
	var m := map.moisture[i]

	if t < 0.2:
		return WorldGenConfig.Biome.SNOW_TUNDRA
	elif t < 0.45:
		return WorldGenConfig.Biome.FOREST if m >= 0.35 else WorldGenConfig.Biome.PLAINS
	elif t < 0.75:
		if m < 0.25:
			return WorldGenConfig.Biome.DESERT
		elif m < 0.55:
			return WorldGenConfig.Biome.PLAINS
		return WorldGenConfig.Biome.FOREST
	else:
		if m < 0.3:
			return WorldGenConfig.Biome.DESERT
		elif m < 0.6:
			return WorldGenConfig.Biome.PLAINS
		return WorldGenConfig.Biome.SWAMP

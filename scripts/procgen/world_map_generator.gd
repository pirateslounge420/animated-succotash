extends RefCounted
class_name WorldMapGenerator
## Single entry point for the world-generation pipeline in DESIGN.md
## section 3: height -> water -> temperature -> moisture -> biome ->
## foliage, each pass reading only the outputs of the passes before it.
## Other systems (rendering, gameplay, future chunk streaming) should
## call generate() rather than invoking individual passes directly.


static func generate(
	p_seed: int,
	resolution: int = 128,
	world_size: float = 512.0,
	sea_level: float = 0.0,
	foliage_types: Array[FoliageType] = []
) -> WorldMapData:
	var map := WorldMapData.new(resolution, world_size, sea_level, p_seed)

	HeightmapPass.generate(map)
	WaterPass.generate(map)
	TemperaturePass.generate(map)
	MoisturePass.generate(map)
	BiomePass.generate(map)
	FoliagePass.generate(map, foliage_types, p_seed + 1000)

	return map

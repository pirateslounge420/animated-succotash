extends RefCounted
class_name FoliagePass
## Pass 6: placeholder foliage spawn points. Each FoliageType declares
## the temperature/moisture range it tolerates (not a biome ID -- per
## docs/implementation-notes.md, foliage responds to the underlying climate directly, kept
## independent from BiomePass's table so foliage rules can be tuned
## without touching biome classification, or vice versa). Never spawns
## on water or above the treeline.
##
## Reads map.height (1), map.water_type (2), map.temperature (3), and
## map.moisture (4). Does NOT read map.biome (5). Writes
## map.foliage_spawns.

const TREELINE_HEIGHT := 17.0


static func generate(map: WorldMapData, foliage_types: Array[FoliageType], rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	map.foliage_spawns.clear()
	for y in range(map.resolution):
		for x in range(map.resolution):
			var idx := map.index(x, y)
			if map.water_type[idx] != WorldMapData.WaterType.NONE:
				continue
			if map.height[idx] >= TREELINE_HEIGHT:
				continue

			var t := map.temperature[idx]
			var m := map.moisture[idx]
			for foliage_type in foliage_types:
				if not foliage_type.matches(t, m):
					continue
				if rng.randf() > foliage_type.density:
					continue
				var pos := map.cell_world_pos(x, y)
				var jitter := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * map.cell_size
				map.foliage_spawns.append({
					"position": Vector3(pos.x + jitter.x, map.height[idx], pos.y + jitter.y),
					"type": foliage_type,
				})

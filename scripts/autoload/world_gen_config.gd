extends Node
## Shared procedural-generation configuration.
##
## Central place for world seed, chunk size, and the noise/biome
## parameters described in DESIGN.md section 3 (heightmap, moisture,
## temperature -> biome lookup). Terrain/biome generation scripts read
## from here rather than hardcoding their own noise settings.

const CHUNK_SIZE: int = 32

enum Biome {
	FOREST,
	MOUNTAINS,
	DESERT,
	OCEAN,
	PLAINS,
	SNOW_TUNDRA,
	SWAMP,
}

# TODO: world seed, noise layer setup, biome lookup table.

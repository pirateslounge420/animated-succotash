extends RefCounted
class_name WorldMapData
## Plain data container for a generated world region. Each generation
## pass (see scripts/procgen/passes/) reads some of these arrays and
## writes exactly one of them, in this order:
##   1. height        (HeightmapPass)
##   2. water_type     (WaterPass)
##   3. temperature    (TemperaturePass)
##   4. moisture, fog_chance (MoisturePass)
##   5. biome          (BiomePass)
##   6. foliage_spawns (FoliagePass)
##
## All arrays are flat, indexed by index(x, y) = y * resolution + x.

## OCEAN is salt water; LAKE and RIVER are fresh water. Nothing currently
## simulates salinity mechanically -- this distinction exists so biome/
## foliage/POI rules (and the fresh-vs-salt cues in docs/implementation-notes.md, e.g. Beach
## forms next to OCEAN specifically, not any water) can key off it.
enum WaterType { NONE, OCEAN, LAKE, RIVER }

var resolution: int
var world_size: float
var cell_size: float
var sea_level: float
var world_seed: int

var height: PackedFloat32Array
var water_type: PackedByteArray
var temperature: PackedFloat32Array
var moisture: PackedFloat32Array
var fog_chance: PackedFloat32Array
var biome: PackedByteArray

## Array of {"position": Vector3, "type": FoliageType} entries.
var foliage_spawns: Array = []


func _init(p_resolution: int, p_world_size: float, p_sea_level: float, p_seed: int) -> void:
	resolution = p_resolution
	world_size = p_world_size
	cell_size = world_size / float(resolution)
	sea_level = p_sea_level
	world_seed = p_seed

	var n := resolution * resolution
	height = PackedFloat32Array()
	height.resize(n)
	water_type = PackedByteArray()
	water_type.resize(n)
	temperature = PackedFloat32Array()
	temperature.resize(n)
	moisture = PackedFloat32Array()
	moisture.resize(n)
	fog_chance = PackedFloat32Array()
	fog_chance.resize(n)
	biome = PackedByteArray()
	biome.resize(n)


func index(x: int, y: int) -> int:
	return y * resolution + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < resolution and y >= 0 and y < resolution


## Cell (x, y)'s center in world-space XZ; height comes from height[].
func cell_world_pos(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * cell_size, (y + 0.5) * cell_size)

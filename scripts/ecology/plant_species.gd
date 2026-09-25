class_name PlantSpecies
extends RefCounted
## One plant species record (DESIGN.md "Vegetation > Species data").
## Plants read climate, not biome names: a species grows wherever the local
## temperature, moisture, altitude and soil suit it, so biomes emerge and
## blend. Density peaks in the middle of each band and fades to zero at
## its edges, so neighboring species' ranges overlap and fade.

enum Tier { EMERGENT, CANOPY, SHRUB, GROUND, EPIPHYTE }

## Placeholder silhouettes, built by PlantMeshes. Real models replace these.
enum Shape {
	CONIFER, BROADLEAF, GNARLED, EMERGENT, UMBRELLA, PALM, CYPRESS, MANGROVE,
	ROSETTE, SPIKE_ROSETTE, SHRUB, TUSSOCK, GRASS, REED, FERN, TREE_FERN,
	CACTUS, CUSHION, MOSS, HANGING_MOSS, EPIPHYTE_CLUMP, LIANA, KNEES, THERMOPHILE_MAT,
	BAMBOO,
}

## Special conditions (optional).
enum Needs {
	NONE,
	STANDING_WATER, # roots in shallow standing water (cypress, mangrove, reeds)
	RIVER_BANK, # within reach of a river or lake shore
	DRY_GROUND, # never in standing water
	SALT_WATER, # tolerates or needs brackish/salt water
	HOT_GROUND, # thermal areas near volcanic hot springs
}

var name: String
var tier: Tier
var shape: Shape
var temp_c := Vector2(-50.0, 50.0) # band, °C (mean annual)
var moisture := Vector2(0.0, 1.0) # band, 0-1 effective moisture
var altitude_m := Vector2(-INF, INF) # optional band, meters
var density := 1.0 # peak relative abundance
var soils := {} # PlanetData.Rock -> factor; rocks not listed use soil_default
var soil_default := 0.6
var needs: Array[Needs] = []
var height_m := Vector2(1.0, 2.0) # size range for jitter
var color := Color(0.3, 0.5, 0.25)
var accent := Color(0.35, 0.25, 0.15) # trunk/stem/flower
## Water depth range (m) this species can root in, if STANDING_WATER.
var water_depth_m := Vector2(0.05, 1.5)
var source := "" # research note / citation from DESIGN.md


## Smooth band membership: 1 in the middle, easing to 0 at the edges.
static func band(x: float, range_v: Vector2) -> float:
	if range_v.x == -INF and range_v.y == INF:
		return 1.0
	if x <= range_v.x or x >= range_v.y:
		return 0.0
	var mid := (range_v.x + range_v.y) * 0.5
	var half := (range_v.y - range_v.x) * 0.5
	var t := (x - mid) / half
	return 1.0 - t * t * t * t


func soil_factor(rock: int) -> float:
	return soils.get(rock, soil_default)


func has_need(n: Needs) -> bool:
	return needs.has(n)


## Climate suitability at a site, before clumping and dominance.
func suitability(temp: float, moist: float, altitude: float, rock: int) -> float:
	return density * band(temp, temp_c) * band(moist, moisture) * band(altitude, altitude_m) * soil_factor(rock)

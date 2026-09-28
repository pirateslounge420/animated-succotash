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
	FOREST_FLOOR, # under or in the gaps of a forest (a forest biome)
}

var name: String
## The binomial (spec D4): real, or invented for placeholder plants.
var genus := ""
var species := ""
var tier: Tier
var shape: Shape
var temp_c := Vector2(-50.0, 50.0) # band, °C (mean annual)
var moisture := Vector2(0.0, 1.0) # band, 0-1 effective moisture
var altitude_m := Vector2(-INF, INF) # optional band, meters
var density := 1.0 # peak relative abundance
var soils := {} # PlanetData.Rock -> factor; rocks not listed use soil_default
var soil_default := 0.6
## The soil classes it grows on, as bits (1 << PlanetData.Rock): a hard
## gate (data/soil.json); outside them it never spawns.
var soil_mask := 0xFF
var needs: Array[Needs] = []
var _need_bits := -1
var height_m := Vector2(1.0, 2.0) # size range for jitter
var color := Color(0.3, 0.5, 0.25)
var accent := Color(0.35, 0.25, 0.15) # trunk/stem/flower
## Water depth range (m) this species can root in, if STANDING_WATER.
var water_depth_m := Vector2(0.05, 1.5)
var source := "" # research note / citation from DESIGN.md
## How leafy its crown is, 0-1 (`leaf_density` in the table; -1: the
## shape's default, leaf_density_of()): how many leaf clusters a branchy
## tree carries along its limbs (PlantMeshes).
var leaf_density := -1.0
## How its wood behaves as a handhold (catch and swing; Handholds): the
## entry's own `handhold` block, if it has one.
var handhold := {}
## The biogeographic realms it's native to (design §AA, the realm gate:
## RealmMap). Empty: not gated (every biome-file plant, and catalogue
## entries without a `realm`). Tagged, it grows only where the place's
## realm is one of these and the place's biome has an association for it.
var realms := PackedStringArray()
## Loaded from a catalogue (data/plants/), not a biome file.
var from_catalogue := false


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


func soil_allowed(rock: int) -> bool:
	return (soil_mask >> rock) & 1 == 1


func has_need(n: Needs) -> bool:
	return needs.has(n)


## The needs as bits (1 << Needs value), worked out once: placement asks
## for several of them per candidate site.
func need_bits() -> int:
	if _need_bits < 0:
		_need_bits = 0
		for n in needs:
			_need_bits |= 1 << n
	return _need_bits


## Suitability at a site, before clumping and dominance. Three co-equal
## gates first (design reconciliation Session 2 G2): temperature, moisture
## and soil class; a species outside any of them is 0. Then the weights:
## the two climate bands, the soil preference within its classes, and
## altitude.
func suitability(temp: float, moist: float, altitude: float, rock: int) -> float:
	var bt := band(temp, temp_c)
	if bt <= 0.0:
		return 0.0
	var bm := band(moist, moisture)
	if bm <= 0.0 or not soil_allowed(rock):
		return 0.0
	return density * bt * bm * maxf(soil_factor(rock), 0.05) * band(altitude, altitude_m)


## The crown's leafiness, 0-1: the table's `leaf_density`, else the shape's
## default (dense beech-like broadleaves, open umbrella crowns).
func leaf_density_of() -> float:
	if leaf_density >= 0.0:
		return leaf_density
	match shape:
		Shape.BROADLEAF:
			return 0.8
		Shape.GNARLED:
			return 0.7
		Shape.EMERGENT:
			return 0.7
		Shape.UMBRELLA:
			return 0.6
		Shape.CYPRESS:
			return 0.85
	return 0.75


## "Genus species" (the HUD shows it for the plant under the crosshair),
## or "" if the table gives none.
func binomial() -> String:
	return ("%s %s" % [genus, species]).strip_edges()

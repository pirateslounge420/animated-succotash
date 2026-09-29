class_name PlanetConst
## Planet-wide constants from DESIGN.md "Overview" and "Biome Sizing".
## Distances are meters, temperatures °C, time in real seconds.

## The full planet: 1/10 of Earth's circumference (design §I, LOCKED
## 2026-09-29: landmass, height (HEIGHT_SCALE 0.1) and time (the 144-min
## day) all share the one 1/10 ratio; 400 km / 1/100 before).
const FULL_CIRCUMFERENCE_M := 4000000.0

## Geography (continents, mountain belts, volcanoes, rock regions, the
## weather grid, the blueprint's distances and slopes) is laid out on a
## planet of this size, the one its noise scales, climate and passes were
## tuned on. The planet actually built is a scale model of it sideways
## (GEO_SCALE, heights unchanged): 10x on the full 4,000 km planet, so its
## continents and biome regions are ten times wider; 0.1x on the dev
## postage stamp (data/dev.json, World). Everything at walking scale
## (ground detail, plants, creatures, the player, ruins) is at its real
## size either way. Geographic code measures with GEO_RADIUS_M
## (CubeSphere.geo_distance_m); scene and walking code with RADIUS_M.
## (With the layout at the full 4,000 km, the same noise drew ten times as
## many continents a tenth the size: an archipelago of coast, desert and
## mountain, with no forest band on seed 42.)
const GEO_CIRCUMFERENCE_M := 400000.0
const GEO_RADIUS_M := GEO_CIRCUMFERENCE_M / TAU # ~63,662 m

## The planet actually built: FULL_CIRCUMFERENCE_M unless the dev postage
## stamp is on (set_circumference, before generation). These are static
## vars, not consts, for that reason; nothing else may write them.
static var CIRCUMFERENCE_M := FULL_CIRCUMFERENCE_M
static var RADIUS_M := CIRCUMFERENCE_M / TAU
## Real meters per geographic meter (10 on the full planet).
static var GEO_SCALE := CIRCUMFERENCE_M / GEO_CIRCUMFERENCE_M


## Size the planet (meters around). Call before generating; everything
## sized from it (chunk grid, walking-scale grids) follows.
static func set_circumference(circumference_m: float) -> void:
	CIRCUMFERENCE_M = circumference_m
	RADIUS_M = CIRCUMFERENCE_M / TAU
	GEO_SCALE = CIRCUMFERENCE_M / GEO_CIRCUMFERENCE_M
	TerrainChunk.fit_to_planet()

## Elevation 0 is sea level; elevations are meters above/below it.
const SEA_LEVEL_M := 0.0

## Vertical scale: heights are 1/10 of Earth's (Everest would stand ~900
## m), the same 1/10 as distances and time. Data and rules keep real-world numbers
## (species altitude bands, biome thresholds, cloud altitudes) and
## multiply them by this, so a mountain that would be 4 km on Earth is
## 400 m here and has the climate of a 4 km mountain.
const HEIGHT_SCALE := 0.1

## Earth's environmental lapse rate (6.5 °C/km) per scaled meter: climbing
## 100 m here cools the air as much as 1 km on Earth.
const LAPSE_RATE_C_PER_M := 0.0065 / HEIGHT_SCALE

## The day's length and its four phases (day 45, dusk 20, night 35, dawn
## 20 real minutes of a 120-minute day), the twilight band and the moon's
## 29.5-day cycle are data: data/sky/day_cycle.json, read by DayCycle.
## data/dev.json can shorten the day while developing (World).

## The sun counts as "up" (HUD, the sun light) once its center is this
## far below the horizon, as on Earth, where refraction and the sun's own
## disc make it appear risen before its center clears the horizon.
const SUNRISE_ELEVATION_DEG := -3.6

## Walking pace (6 km/h, a brisk hike), also the pace DESIGN.md's biome
## walk-across times assume.
const WALK_SPEED_MPS := 6.0 * 1000.0 / 3600.0

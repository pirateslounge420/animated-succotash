class_name PlanetConst
## Planet-wide constants from DESIGN.md "Overview" and "Biome Sizing".
## Distances are meters, temperatures °C, time in real seconds.

## The full planet, read from data/world_scale.json planet.circumference_m
## (design 3 Oct §CR, LOCKED: 1/100 Earth, 400 km around, the geography's
## own layout size, so GEO_SCALE is 1; heights stay 1/10 (HEIGHT_SCALE) and
## time stays 1/10 (the 144-min day). Things at walking scale keep their
## real size; only the gaps between them shrink. 4,000 km (§I, 29 Sept)
## before; the size is one data value so the two can be compared in play.
static var FULL_CIRCUMFERENCE_M := _full_circumference()


static func _full_circumference() -> float:
	var p = Tuning.table("world_scale").get("planet", {})
	var c := float((p as Dictionary).get("circumference_m", 400000.0)) if p is Dictionary else 400000.0
	return c if c > 1000.0 else 400000.0


## Geography (continents, mountain belts, volcanoes, rock regions, the
## weather grid, the blueprint's distances and slopes) is laid out on a
## planet of this size, the one its noise scales, climate and passes were
## tuned on. The planet actually built is a scale model of it sideways
## (GEO_SCALE, heights unchanged): 1x on the full planet (§CR: built at the
## layout's own size), 0.1x on the dev postage stamp (data/dev.json,
## World); 10x on the 4,000 km planet if world_scale.json asks for it. Everything at walking scale
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
## Real meters per geographic meter (1 on the full planet, §CR).
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

## The day's length and its four phases (a 144-minute day, 6 real minutes
## an in-game hour; at the equator on an equinox: day 07-17 60 minutes,
## dusk 17-20 18, night 20-04 48, dawn 04-07 18), the twilight band and the moon's
## 29.5-day cycle are data: data/sky/day_cycle.json, read by DayCycle.
## data/dev.json can shorten the day while developing (World).

## The sun counts as "up" (HUD, the sun light) once its center is this
## far below the horizon, as on Earth, where refraction and the sun's own
## disc make it appear risen before its center clears the horizon.
const SUNRISE_ELEVATION_DEG := -3.6

## Walking pace (6 km/h, a brisk hike), also the pace DESIGN.md's biome
## walk-across times assume.
const WALK_SPEED_MPS := 6.0 * 1000.0 / 3600.0

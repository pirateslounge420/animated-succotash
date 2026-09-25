class_name PlanetConst
## Planet-wide constants from DESIGN.md "Overview" and "Biome Sizing".
## Distances are meters, temperatures °C, time in real seconds.

## 1/100th of Earth's circumference.
const CIRCUMFERENCE_M := 400000.0
const RADIUS_M := CIRCUMFERENCE_M / TAU # ~63,662 m

## Elevation 0 is sea level; elevations are meters above/below it.
const SEA_LEVEL_M := 0.0

## Real-world environmental lapse rate. Kept at Earth's value so species
## altitude bands can use real-world numbers.
const LAPSE_RATE_C_PER_M := 0.0065

## 120 real minutes per in-game day (12x faster than Earth: five real
## minutes per in-game hour), split into four phases at the equator:
## dawn 15, day 50, dusk 15 and night 40 minutes. Daylight outlasts full
## darkness, as on an Earth equinox. Astro.apparent_days() warps the sky's
## turning so each phase takes exactly that long.
const DAY_LENGTH_S := 120.0 * 60.0
const DAWN_MIN := 15.0
const DAY_MIN := 50.0
const DUSK_MIN := 15.0
const NIGHT_MIN := 40.0
## Dawn and dusk run while the sun is within this many degrees of the
## horizon (from -10 to +10 degrees).
const TWILIGHT_DEG := 10.0

## The sun counts as "up" (HUD, the sun light) once its center is this
## far below the horizon, as on Earth, where refraction and the sun's own
## disc make it appear risen before its center clears the horizon.
const SUNRISE_ELEVATION_DEG := -3.6
const MOON_CYCLE_DAYS := 28

## Walking pace used for the spec's biome walk-across times.
const WALK_SPEED_MPS := 4.5 * 1000.0 / 3600.0

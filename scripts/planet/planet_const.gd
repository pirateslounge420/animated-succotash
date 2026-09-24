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

## 48 real minutes per in-game day (two real minutes per in-game hour).
const DAY_LENGTH_S := 48.0 * 60.0

## The sun counts as "up" once its center is this far below the horizon,
## as on Earth, where refraction and the sun's own disc make it appear
## risen before its center clears the horizon (-0.83 degrees there). It's
## larger here for the stylized sun, so night comes out slightly shorter
## than day: about 25 vs 23 real minutes at the equator.
const SUNRISE_ELEVATION_DEG := -3.6
const MOON_CYCLE_DAYS := 28

## Walking pace used for the spec's biome walk-across times.
const WALK_SPEED_MPS := 4.5 * 1000.0 / 3600.0

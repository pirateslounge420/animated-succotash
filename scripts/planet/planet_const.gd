class_name PlanetConst
## Planet-wide constants from DESIGN.md "Overview" and "Biome Sizing".
## Distances are meters, temperatures °C, time in real seconds.

## 1/100th of Earth's circumference.
const CIRCUMFERENCE_M := 400000.0
const RADIUS_M := CIRCUMFERENCE_M / TAU # ~63,662 m

## Elevation 0 is sea level; elevations are meters above/below it.
const SEA_LEVEL_M := 0.0

## Vertical scale: heights are 1/10 of Earth's (Everest would stand ~900
## m), while distances are 1/100. Data and rules keep real-world numbers
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

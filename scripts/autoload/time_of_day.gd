extends Node
## Drives the world's day/night clock.
##
## Full cycle = 120 in-game minutes: 70 minutes day, 50 minutes night,
## with dawn/dusk as the gradient transition between the two (docs/implementation-notes.md
## section 4) rather than fixed phases of their own — the transition
## emerges naturally from sun_elevation_deg() crossing the horizon, so
## nothing here hardcodes a separate "dawn"/"dusk" state.
##
## Exposes a single normalized `time_of_day` (0.0-1.0 across the full
## cycle) and emits `time_changed` so sky/lighting/gameplay systems can
## react without polling.

signal time_changed(time_of_day: float)

const DAY_MINUTES: float = 70.0
const NIGHT_MINUTES: float = 50.0
const CYCLE_MINUTES: float = DAY_MINUTES + NIGHT_MINUTES
const CYCLE_SECONDS: float = CYCLE_MINUTES * 60.0

## Fraction of the cycle that is daytime; time_of_day < this is day.
const DAY_FRACTION: float = DAY_MINUTES / CYCLE_MINUTES

const MAX_SUN_ELEVATION_DEG: float = 75.0
const NIGHT_SUN_DEPTH_DEG: float = 40.0
const MAX_MOON_ELEVATION_DEG: float = 55.0

## Multiplies the passage of time; 1.0 = a real-time 120-minute cycle.
## Bump this in the inspector to speed up testing/iteration.
@export var time_scale: float = 1.0

## 0.0 = sunrise, DAY_FRACTION = sunset, 1.0 = next sunrise. Starts at a
## friendly mid-morning default rather than exactly sunrise.
var time_of_day: float = 0.2


func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + (delta * time_scale) / CYCLE_SECONDS, 1.0)
	time_changed.emit(time_of_day)


func is_day() -> bool:
	return time_of_day < DAY_FRACTION


## Sun elevation in degrees, continuous across the *entire* cycle
## (negative = below the horizon at night) so color/lighting blends never
## need to special-case the day/night boundary.
func sun_elevation_deg() -> float:
	if is_day():
		var day_t := time_of_day / DAY_FRACTION
		return sin(day_t * PI) * MAX_SUN_ELEVATION_DEG
	var night_fraction := 1.0 - DAY_FRACTION
	var night_t := (time_of_day - DAY_FRACTION) / night_fraction
	return -sin(night_t * PI) * NIGHT_SUN_DEPTH_DEG


## Moon elevation in degrees; only meaningful at night (0 during the day).
## Callers gate visibility with is_day() rather than relying on sign.
func moon_elevation_deg() -> float:
	if is_day():
		return 0.0
	var night_fraction := 1.0 - DAY_FRACTION
	var night_t := (time_of_day - DAY_FRACTION) / night_fraction
	return sin(night_t * PI) * MAX_MOON_ELEVATION_DEG

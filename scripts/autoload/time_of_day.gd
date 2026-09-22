extends Node
## Drives the world's day/night clock.
##
## Full cycle = 120 in-game minutes: 70 minutes day, 50 minutes night,
## with dawn/dusk as the gradient transition between the two (see
## DESIGN.md, section 4) rather than fixed phases of their own.
##
## Exposes a single normalized `time_of_day` (0.0-1.0 across the full
## cycle) that other systems (sky, lighting, gameplay) subscribe to via
## `time_changed` instead of polling.

signal time_changed(time_of_day: float)

const DAY_MINUTES: float = 70.0
const NIGHT_MINUTES: float = 50.0
const CYCLE_MINUTES: float = DAY_MINUTES + NIGHT_MINUTES

# TODO: advance time_of_day each frame and emit time_changed.

class_name SuperMeter
extends RefCounted
## The super meter (design reconciliation §S; numbers in data/movement.json
## "super_meter" and data/combat.json "overcharge"): movement mastery
## turned into combat power.
##
## Filling it: a run of PERFECT techs (a tap wall jump inside its window,
## a landing roll, letting go of a swing) fills it, each one more than the
## last while the series lasts (fill_per_perfect, plus chain_bonus_per_link
## for every perfect before it in the series); so does landing a hit on a
## creature (fill_per_hit, fill_per_critical for a critical; Hits). A
## missed or late tech (a press after the window, a cling, a heavy landing
## without the roll, a snapped branch, an impact) breaks the series: the
## meter keeps what it has but stops growing until the next perfect one.
##
## Spending it: with any meter, a tool held past its full charge keeps
## charging for the overcharge's extra_s; released then, it's a super shot
## (Bow, Spear) and the meter empties (no partial spends). Released before
## the overcharge completes: a normal full shot, the meter kept. The meter
## never decays; dying empties it (reset_on_death).

static var NUMS := Tuning.section("movement", "super_meter")

## 0-1.
var value := 0.0
## Perfect techs in the current series.
var series := 0
## Counters, for tests and the log.
var perfects := 0
var spends := 0


func has() -> bool:
	return value > 0.0


## A perfect tech (`kind` for the log: "wall_jump", "roll", "swing").
func perfect(_kind: String) -> void:
	value = minf(value + float(NUMS.get("fill_per_perfect", 0.04)) + float(NUMS.get("chain_bonus_per_link", 0.01)) * series, 1.0)
	series += 1
	perfects += 1


## A missed or late tech: the series is over (the meter keeps its fill).
func broke() -> void:
	series = 0


## A landed hit on a creature.
func hit(critical: bool) -> void:
	value = minf(value + float(NUMS.get("fill_per_critical" if critical else "fill_per_hit", 0.06)), 1.0)


## An overcharge released: the meter empties.
func spend() -> void:
	value = 0.0
	series = 0
	spends += 1


func died() -> void:
	if bool(NUMS.get("reset_on_death", true)):
		value = 0.0
	series = 0


## The overcharge numbers for a tool ("bow", "spear", "fishing") merged
## over the shared ones.
static func overcharge(tool: String) -> Dictionary:
	var o := Tuning.section("combat", "overcharge").duplicate()
	var per = o.get(tool, {})
	if per is Dictionary:
		o.merge(per, true)
	return o

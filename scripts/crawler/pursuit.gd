class_name Pursuit
extends RefCounted
## A hunter's chase, and how it ends (design 6 Oct §FD, §FE.1; the crawler,
## Torchfire 1). Anything that hunts you (the boss now, the residents
## later) holds one. The chase is on from the moment the hunter notices you
## (notice()) or its strike lands (hit()), and while it is on the hunter is
## registered with Harm as pursuing you, so your hits don't heal
## (harm.json fd.recover_starts). It ends when the hunter gives you up, by
## its own mix of residents.json rules.gives_up, its numbers in its own
## gives_up block (bosses.json bosses.<world>.gives_up,
## residents.json creatures.<name>.gives_up), checked every step():
##   distance_m      you got farther from it than this;
##   out_of_sight_s  it hasn't perceived you for this long (seen you or
##                   your flame, or heard you: the hunter's own senses say,
##                   its notice rule);
##   hide            true: hiding works on it: out of its sight line behind
##                   cover (§FC.2) you are as lost to it as anywhere out of
##                   sight; false: it finds you behind cover (the clock
##                   waits while you are only hidden from it);
##   torch_doused    true: your torch going out while it chases you loses
##                   you at once (dousing it, prompt 54; deep water).
## Each rule a block leaves out never ends the chase. Where a chase may go
## in the light is the light's own since Mike's note of 7 Oct: the snake and
## the skeletons, their strike landed or not, stand only where the light
## on the floor is at most residents.json rules.chase_light_cap (LightField:
## the light's edge, never close to a fire). has_hit (its strike landed
## this chase, may_enter) is kept for what has no light on the floor (a
## test floor) and the tools.

## residents.json rules: chase_enters_light, back_to_dark_s (§FD).
static var RULES: Dictionary = Tuning.section("residents", "rules")

## The hunter (registered with Harm while the chase is on).
var hunter: Object
## Its gives_up block.
var rules: Dictionary
## The chase is on.
var on := false
## Its strike has landed this chase: it may follow you into the light.
var has_hit := false
## How long it hasn't perceived you (s).
var unseen_s := 0.0
## Why it gave you up last: "distance", "out_of_sight", "torch_doused",
## or "" (tools, the log).
var why := ""
var _torch_was_lit := false


func _init(p_hunter: Object, p_rules: Dictionary) -> void:
	hunter = p_hunter
	rules = p_rules


## It noticed you: the chase is on (or goes on, the clock back to zero).
## `torch_lit`: your torch is lit now (so putting it out later counts).
func notice(torch_lit := false) -> void:
	if not on:
		on = true
		has_hit = false
		why = ""
		_torch_was_lit = torch_lit
	unseen_s = 0.0
	_tell_harm(true)


## Its strike landed: it has its teeth in you (§FD).
func hit(torch_lit := false) -> void:
	notice(torch_lit)
	has_hit = true


## One step of the chase. `perceives`: it sees or hears you now by its own
## senses; `dist_m`: how far you are from it; `torch_lit`: your torch is
## lit in hand; `hidden`: you are out of its sight line only because of
## cover (crouched behind it, §FC.2) and would be in its sight otherwise.
## Returns true on the step it gives you up.
func step(delta: float, perceives: bool, dist_m: float, torch_lit: bool, hidden := false) -> bool:
	if not on:
		return false
	# Still after you (says so again if Harm was reset under it: a wake).
	_tell_harm(true)
	if rules.has("distance_m") and dist_m > float(rules.distance_m):
		return give_up("distance")
	if bool(rules.get("torch_doused", false)) and _torch_was_lit and not torch_lit:
		return give_up("torch_doused")
	_torch_was_lit = torch_lit
	if perceives or (hidden and not bool(rules.get("hide", true))):
		unseen_s = 0.0
	else:
		unseen_s += delta
	if rules.has("out_of_sight_s") and unseen_s >= float(rules.out_of_sight_s):
		return give_up("out_of_sight")
	return false


## May it step into a room or corridor stretch that is lit, with no light
## on the floor to go by? Its prowling never does; a chase does, once its
## strike has landed (§FD, rules.chase_enters_light; with the light on the
## floor, the chase's cap decides instead: Residents.may_be_at).
func may_enter(lit: bool) -> bool:
	return not lit or (on and has_hit and bool(RULES.get("chase_enters_light", true)))


## Given you up in the light, `path_m` from the nearest dark: how fast it
## goes (m/s, never slower than its own `speed_mps`) to be back in the
## dark within rules.back_to_dark_s (§FD), with a tenth of it to spare.
static func back_to_dark_mps(path_m: float, speed_mps: float) -> float:
	var s := float(RULES.get("back_to_dark_s", 4.0))
	return maxf(speed_mps, path_m / maxf(s * 0.9, 0.1))


## It gives you up (or is called off: its release, the wake): Harm no
## longer counts it.
func give_up(reason := "") -> bool:
	var was := on
	on = false
	has_hit = false
	unseen_s = 0.0
	why = reason
	_tell_harm(false)
	return was


## Harm keeps the list of who is chasing you (Harm.pursue).
func _tell_harm(on: bool) -> void:
	if Harm.instance != null and is_instance_valid(Harm.instance):
		Harm.instance.pursue(hunter, on)

class_name BossState
extends RefCounted
## One state in a boss's behaviour pool (design 9 Oct §FM.1; data/boss_pool.json
## pools.<boss>.<id>): a small unit the boss runs while the pool has it in
## charge, with enter, tick and exit (BossPool draws which, Boss runs it).
##
## A state is found by its id: a script named <id>.gd in
## scripts/crawler/boss_states/ that extends BossState (rounds.gd is the
## first), or one registered in code with BossPool.register(id, script).
## Its numbers are its own entry in the pool (`def`: weight, dwell_s and
## whatever else it reads), so Mike tunes it in boss_pool.json.
##
## What a state may never do (rule.never_breaks; Boss keeps it so whatever
## a state does):
##   the rule's own moments are never its: the chase (hunt, the torch's
##       hold, the strike, watching at the light's edge), leaving the light,
##       a fire pot (stunned, fleeing, down its hole, rising), you taken,
##       the last light. The moment one begins the state is over (exit),
##       and the pool is asked again only once the boss is free of it.
##   it strikes only through Boss.begin_strike(): the strike as built
##       (queue 57's CreatureStrike), its tell and its wind-up first,
##       after your lit torch has held it (the torch's delay).
##   it never stays in the light: a room or stretch lit round it, or one
##       it goes into, ends it, and the boss leaves for the dark as built.
##   it never waits on the way out (Boss.on_way_out): kept still there for
##       more than Boss.EXIT_WAIT_S, it is over.

## Its id (the key in boss_pool.json pools.<boss>) and its entry there.
var id := ""
var def: Dictionary = {}
## Set true to end itself: the pool draws the next state on the boss's
## next free tick (Boss.end_state() says the same).
var done := false
## Why it was last over (Boss sets it before exit: "dwell", "done", "rule",
## "light", "exit", "swap" or "cut"; queue 66).
var why := ""


## May it be drawn now (its needs: "watched", a doorway near...)? Asked at
## every draw; a state left out is not drawn that time.
func can_enter(_boss: Boss) -> bool:
	return true


## May it cut in (queue 66): the moment its needs begin to hold (can_enter
## turning true: the freeze, when you first catch sight of it from far
## off), the pool weighs it against the state in charge, by their weights,
## and it takes over or not (BossPool.draw_cut_in). Never in one of the
## rule's own moments.
func cuts_in() -> bool:
	return false


## How loud its tell is while it is in charge and the boss's own state is
## one of its own (dB; -INF silent). Boss's built states keep their own
## levels (Boss._sound_tick).
func tell_db(_boss: Boss) -> float:
	return -INF


## Taking charge. `from`: the state before it ("" at the start).
func enter(_boss: Boss, _from: String) -> void:
	pass


## Every tick it is in charge (after the boss's light and its strike's
## clock; never in one of the rule's own moments).
func tick(_boss: Boss, _delta: float) -> void:
	pass


## Handing over (its dwell ran out, it ended itself, or one of the rule's
## own moments began): tidy its own things (a tint, a sound). It never
## moves the boss or sets its state here: the next state, or the rule, has
## it now.
func exit(_boss: Boss) -> void:
	pass


## A light caught somewhere while it is in charge, the boss's own node
## still dark (its node lit round it, the boss leaves for the dark and the
## state is over): its way may run into the light now, so it can think
## again.
func lights_changed(_boss: Boss) -> void:
	pass


## The boss's built behaviour ('rounds', queue 49), which Boss's guards
## leave alone: the boss check holds it to the rule.
func built() -> bool:
	return false

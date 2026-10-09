class_name BossPool
extends RefCounted
## A boss's behaviour pool (design 9 Oct §FM.1, Mike: every boss has "a
## group of different behaviors that each boss can cycle through on RNG
## level", so you can never pin down its algorithm; data/boss_pool.json).
## Built in queue 65; Boss asks it for its next state.
##
##   its states  the boss's own entry, pools.<boss id>: each key a state's
##               id, each value its weight, its dwell_s and the state's own
##               numbers. A state is found by its id (BossState: a script
##               scripts/crawler/boss_states/<id>.gd, or registered in code
##               with register()); an id no code registers is skipped with
##               one warning (once a run), never a crash. A boss with no
##               entry, or none of whose states is found, has its built
##               behaviour only ('rounds').
##   the draw    (rule.draw weighted) a weighted random pick from its own
##               states, never a fixed sequence; never the same state twice
##               running unless it is the only one that may come
##               (rule.repeat_gap: the last that many draws are left out);
##               a state whose needs don't hold now (BossState.can_enter)
##               is left out of that draw.
##   live        (rule.live_rng) the dice are the pool's own, not seeded
##               from the game seed, so loading a save doesn't replay them
##               (the dungeon itself is seeded, §FK.2); live_rng false seeds
##               them from the game seed and the boss.
##   its dwell   dwell_s [min, max]: how long a drawn state lasts before the
##               next draw (Boss ends it sooner when it ends itself or one of
##               the rule's own moments begins).

const FILE := "res://data/boss_pool.json"
## Where a state's script is found by its id.
const STATES_DIR := "res://scripts/crawler/boss_states/"
## A state's dwell when its entry has none (the data's rounds).
const DWELL_DEFAULT := [20.0, 50.0]

static var DATA: Dictionary = _json(FILE)
static var RULE: Dictionary = DATA.get("rule", {})

## Registered states: id -> a Script extending BossState, or a Callable
## that makes one (register()).
static var _registry: Dictionary = {}
## Scripts found in STATES_DIR by id (null: none there).
static var _found: Dictionary = {}
## The warnings given (tools): id -> how many times (one at most).
static var warned: Dictionary = {}

## Whose pool (a boss id, or a name for a test pool).
var boss_id := ""
## Its live states, in the data's order, their weights, and their entries.
var ids: Array[String] = []
var weights: Array[float] = []
var defs: Dictionary = {}
## One unit per live state, its own (id -> BossState).
var units: Dictionary = {}
## The ids in its entry that no code registers (skipped).
var skipped: Array[String] = []
var repeat_gap := 1
var rng := RandomNumberGenerator.new()
## The last draws, newest last (for repeat_gap), and how many draws so far.
var recent: Array[String] = []
var draws := 0


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("BossPool: %s is missing" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("BossPool: %s is not valid JSON" % path)
		return {}
	return parsed


## Register state `id`: `what` a Script extending BossState, or a Callable
## that returns a new BossState. Overrides a script of the same id in
## STATES_DIR. A prompt adding a boss's states either drops <id>.gd files
## in STATES_DIR (found on their own) or calls this before the boss is
## built.
static func register(id: String, what: Variant) -> void:
	_registry[id] = what


static func unregister(id: String) -> void:
	_registry.erase(id)


## Is there code for state `id` (registered, or a script in STATES_DIR)?
static func is_registered(id: String) -> bool:
	return _registry.has(id) or _script_for(id) != null


## Its script in STATES_DIR, if there is one (looked for once).
static func _script_for(id: String) -> Script:
	if not _found.has(id):
		var s: Script = null
		# Only a plain id names a file (letters, digits, underscores).
		if id.is_valid_identifier():
			var path := STATES_DIR + id + ".gd"
			if ResourceLoader.exists(path):
				s = load(path) as Script
		_found[id] = s
	return _found[id]


## A new unit for state `id`, or null if no code registers it (or it isn't
## a BossState).
static func make_unit(id: String) -> BossState:
	var what: Variant = _registry.get(id, null)
	if what == null:
		what = _script_for(id)
	var u: Variant = null
	if what is Callable:
		u = (what as Callable).call()
	elif what is Script:
		u = (what as Script).new()
	if u is BossState:
		return u
	return null


## Boss `boss_id`'s pool from boss_pool.json pools (its built behaviour
## only, 'rounds', when it has no entry there). `game_seed` seeds the dice
## only when rule.live_rng is false.
static func for_boss(p_boss_id: String, game_seed := 0) -> BossPool:
	var pools: Dictionary = DATA.get("pools", {})
	var states: Variant = pools.get(p_boss_id, null)
	if not states is Dictionary or (states as Dictionary).is_empty():
		states = {"rounds": {"weight": 1, "dwell_s": DWELL_DEFAULT}}
	return from_dict(states, RULE, p_boss_id, game_seed)


## A pool from `states` ({id: entry}) under `rule` (boss_pool.json's
## shape): the checks build test pools with this.
static func from_dict(states: Dictionary, rule: Dictionary = RULE, label := "", game_seed := 0) -> BossPool:
	var p := BossPool.new()
	p.boss_id = label
	p.repeat_gap = maxi(int(rule.get("repeat_gap", 1)), 0)
	if bool(rule.get("live_rng", true)):
		p.rng.randomize()
	else:
		p.rng.seed = hash([game_seed, label, "boss_pool"])
	for k in states:
		var id := str(k)
		var e: Variant = states[k]
		if not e is Dictionary:
			_warn(id, "BossPool: %s's state '%s' is not an entry; skipped" % [label, id])
			continue
		var w := float((e as Dictionary).get("weight", 1.0))
		if w <= 0.0:
			continue
		var u := make_unit(id)
		if u == null:
			# The data names a state no code registers yet: skipped, said once.
			p.skipped.append(id)
			_warn(id, "BossPool: no code registers state '%s' (boss_pool.json pools.%s); skipped (§FM.1)" % [id, label])
			continue
		u.id = id
		u.def = e
		p.ids.append(id)
		p.weights.append(w)
		p.defs[id] = e
		p.units[id] = u
	if p.ids.is_empty():
		# Nothing it can do of its own: its built behaviour.
		var r := make_unit("rounds")
		if r != null:
			r.id = "rounds"
			r.def = {"weight": 1, "dwell_s": DWELL_DEFAULT}
			p.ids.append("rounds")
			p.weights.append(1.0)
			p.defs["rounds"] = r.def
			p.units["rounds"] = r
	return p


## One warning a run for state `id`.
static func _warn(id: String, text: String) -> void:
	if warned.has(id):
		return
	warned[id] = 1
	push_warning(text)


## Its unit for state `id` (null if it has none).
func unit(id: String) -> BossState:
	return units.get(id, null)


func has_state(id: String) -> bool:
	return units.has(id)


## The next state (rule.draw weighted): from its live states that may come
## now (`can`, a Callable(id) -> bool; every one when left out), the last
## repeat_gap draws left out unless nothing else may come, picked by weight
## with its own dice. "" when none may come.
func draw(can: Callable = Callable()) -> String:
	var cands: Array[int] = []
	for i in ids.size():
		if can.is_valid() and not bool(can.call(ids[i])):
			continue
		cands.append(i)
	if cands.is_empty():
		return ""
	var gap := mini(repeat_gap, recent.size())
	while gap > 0:
		var last := recent.slice(recent.size() - gap)
		var keep: Array[int] = []
		for i in cands:
			if not ids[i] in last:
				keep.append(i)
		if not keep.is_empty():
			cands = keep
			break
		gap -= 1
	var total := 0.0
	for i in cands:
		total += weights[i]
	var r := rng.randf() * total
	var pick := cands[cands.size() - 1]
	for i in cands:
		r -= weights[i]
		if r < 0.0:
			pick = i
			break
	var id := ids[pick]
	recent.append(id)
	while recent.size() > maxi(repeat_gap, 1):
		recent.pop_front()
	draws += 1
	return id


## How long state `id` lasts (s): its dwell_s, [min, max] on its own dice
## (a single number is itself).
func dwell(id: String) -> float:
	var v: Variant = (defs.get(id, {}) as Dictionary).get("dwell_s", DWELL_DEFAULT)
	if v is Array and (v as Array).size() == 2:
		var lo := float(v[0])
		var hi := float(v[1])
		return rng.randf_range(minf(lo, hi), maxf(lo, hi))
	if v is float or v is int:
		return float(v)
	return rng.randf_range(float(DWELL_DEFAULT[0]), float(DWELL_DEFAULT[1]))


## Its live states' ids that are only the built behaviour ('rounds')?
func only_rounds() -> bool:
	return ids.size() == 1 and ids[0] == "rounds"

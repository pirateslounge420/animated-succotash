class_name HubWork
extends RefCounted
## The keepers' real work at the hub (design §GM, queue 122; §GO.1-3,
## queue 123; data/hub_work.json). Mike, 30 Oct: "anytime they take action
## it should be to actually do something for the camp or to make
## something - not just moving thru the motions". Mike, 1 Nov (§GO): the
## camp starts bare and earns its growth; every resource moves through a
## real, visible supply chain.
##
## This is the camp's life alone, no nodes: HubWorkView shows it (the
## keepers walking, the props filling and emptying). It runs the same
## headless, at speed, and for the catch-up when you come home (§GM.9).
##
##   store     the camp's goods (stocks + stocks_chains): count, target,
##             cap, owner, the prop that shows it
##   sources   where raw things come from, running down and regrowing
##             (dead wood, game, the trap and the net, wild patches, the
##             garden bed, the river, the clay pit, the flint bank)
##   tools     each one once, at its spot; taken while in use, worn by use,
##             broken at its spot and reordered from its maker (§GM.2, §GM.5)
##   items     a source trip brings one thing home, and it goes through its
##             chain stage by stage, station to station, carried on foot
##             (§GO.3); it ends as store goods (or, food, at tonight's fire)
##   upgrades  finished goods grow the camp (§GO.1.4): a hide cover on a
##             lean-to, a waterskin, bedding, horn cups, painted posts
##   planner   each keeper, a few times a minute: an order waiting, else a
##             chain item ready for them, else an upgrade whose goods are
##             in the store, else the stock they own that is shortest, else
##             leftovers to work, else rest (§GM.1, §GM.7); the
##             day's shape by the sun (§GM.8); the dusk and dawn rounds are
##             DayShift's (the keepers sit at their seats for them)
##   use       each night the fires burn wood, each evening the meal takes
##             food, pots crack, fresh food spoils (§GM.1.3)
##
## Time is real minutes of play (`t`, the 144-minute day), taken from the
## world's clock (days0 + t / day_min). Every work step's end is logged
## with what it changed (log); the checks fail any that changed nothing.

static var D: Dictionary = Tuning.table("hub_work")
static var DS: Dictionary = Tuning.table("day_shift")

const FOOD := ["fresh_food", "smoked_meat", "dried_fish", "roots_greens", "raw_meat"]

var t := 0.0
var days0 := 0.0
var day_min := 144.0
var store := {}
var meta := {}
var sources := {}
var tools := {}
var orders: Array = []
var items: Array = []
var upgrades := {}
var keepers := {}
## Spot name ("keeper.spot", "hearth", "bench.<keeper>", "edge", ...) ->
## where it is (world).
var spots := {}
var log: Array = []
var log_max := 0
var ended: Array = []
var produced := {}
var rng := RandomNumberGenerator.new()
var _next := 1
## Real life to hunt (HubWorkView): () -> Vector3 of an animal in reach,
## or Vector3.INF; and kill_fn(at) takes it.
var prey_fn := Callable()
var kill_fn := Callable()
## Per game day (int of the world's days): {keeper: {"light", "rest", "work"}}.
var days := {}
var _cache := {}
## Recipes left to dry, smoke or fire (wait_min): [{"at", "out", "by", "act"}].
var batches: Array = []
## The sun's part at the last tick (day events fire on its changes), and
## the daylight count (rest is tallied per daylight).
var _last_part := ""
var day_no := 0
## The camp's band (design §GO.10.1, queue 125): the instruments you have
## learned from the realms' bards (HubWorkView sets it from the save), and
## those the maker has built: {instrument: the keeper who plays it}.
var band_learned: Array = []
var band_made := {}
var S: Dictionary = D.get("sim", {})


# --- Setting up --------------------------------------------------------------------

## A new camp (§GO.1): the start's store, every source full, every tool
## whole at its spot, no items, no upgrades.
func fresh(seed_value: int, p_days: float, p_day_min := 144.0) -> void:
	rng.seed = hash([seed_value, "hub work"])
	days0 = p_days
	day_min = p_day_min
	t = 0.0
	_meta()
	var st: Dictionary = (D.get("start", {}) as Dictionary).get("stocks", {})
	for g in meta:
		store[g] = float(st.get(g, 0.0)) if D.has("start") else float((meta[g] as Dictionary).get("start", 0.0))
	for id in _sources():
		var s: Dictionary = _sources()[id]
		sources[id] = {"left": float(s.get("count", 0.0)), "trap": 0.0, "water_days": 0}
	for id in _tools():
		tools[id] = {"uses": int((_tools()[id] as Dictionary).get("uses", 0)), "broken": false, "by": ""}
	for k in keeper_keys():
		keepers[k] = _keeper(k)


func _meta() -> void:
	meta.clear()
	for block in ["stocks", "stocks_chains", "stocks_band"]:
		var b: Dictionary = D.get(block, {})
		for g in b:
			meta[g] = b[g]


static func keeper_keys() -> Array:
	var out: Array = (D.get("spots", {}) as Dictionary).keys()
	out.append("shaman")
	return out


func _keeper(k: String) -> Dictionary:
	return {"key": k, "at": _home(k), "steps": [], "left": 0.0, "mode": "idle", "carry": {}, "tool": "", "item": -1, "away": false, "taken": {}}


func _home(k: String) -> String:
	return "hearth" if k == "shaman" else k + ".seat"


static func _sources() -> Dictionary:
	return D.get("sources", {})


static func _tools() -> Dictionary:
	return D.get("tools", {})


static func chains() -> Dictionary:
	return D.get("chains", {})


## Spots (world) from the hub, and where the camp's own spots are; then
## every keeper set down at their seat.
func place(p_spots: Dictionary) -> void:
	spots = p_spots
	for k in keepers:
		var kp: Dictionary = keepers[k]
		if not spots.has(str(kp.at)):
			kp.at = _home(k)


# --- The clock and the sun -------------------------------------------------------------

func now_days() -> float:
	return days0 + t / day_min


static func _sun(d: float) -> float:
	return Surface.sun_deg_at(d)


## Where the day is at `d` (the world's days): {"part": day | dusk |
## night | dawn, "frac" (0-1 through the daylight, day only), "to_dusk"
## (minutes), "light" (the daylight's length, minutes), "since_dark"
## (minutes since the dusk ended, night only)}.
func phase(d := -1.0) -> Dictionary:
	if d < 0.0:
		d = now_days()
	var SD: Dictionary = DS.get("sun_deg", {})
	var hi := float(SD.get("dusk_start", 4.0))
	var lo := float(SD.get("dusk_end", -8.0))
	var s := _sun(d)
	var up := _sun(d + 0.002) > s
	var step := 0.5 / day_min
	if s >= hi:
		var c: Dictionary = _cache.get("day", {})
		if c.is_empty() or d < float(c.rise) or d > float(c.set):
			var a := d
			while _sun(a - step) >= hi and d - a < 1.0:
				a -= step
			var b := d
			while _sun(b + step) >= hi and b - d < 1.0:
				b += step
			c = {"rise": a, "set": b}
			_cache["day"] = c
		var light := (float(c.set) - float(c.rise)) * day_min
		return {"part": "day", "frac": clampf((d - float(c.rise)) * day_min / maxf(light, 1.0), 0.0, 1.0), "to_dusk": (float(c.set) - d) * day_min, "light": light}
	if s <= lo:
		var c2: Dictionary = _cache.get("night", {})
		if c2.is_empty() or d < float(c2.dark) or d > float(c2.dark) + 1.0:
			var a2 := d
			while _sun(a2 - step) <= lo and d - a2 < 1.0:
				a2 -= step
			c2 = {"dark": a2}
			_cache["night"] = c2
		return {"part": "night", "since_dark": (d - float(c2.dark)) * day_min}
	return {"part": "dawn" if up else "dusk"}


func _hour(ph: Dictionary) -> String:
	if str(ph.part) != "day":
		return "evening"
	var f := float(ph.frac)
	return "morning" if f < 0.4 else ("midday" if f < 0.6 else ("afternoon" if f < 0.8 else "late_afternoon"))


# --- Running --------------------------------------------------------------------------

## Step the camp `dt` real minutes on (in pieces no longer than `piece`).
func advance(dt: float, piece := 0.25) -> void:
	while dt > 1e-6:
		var h := minf(dt, piece)
		_tick(h)
		dt -= h


## Catch up to the world's `to_days` after time away (§GM.9), at most
## away.catch_up_days_max days, in minute steps. The minutes simulated.
func catch_up(to_days: float) -> float:
	var mx := float((D.get("away", {}) as Dictionary).get("catch_up_days_max", 10)) * day_min
	var want := (to_days - now_days()) * day_min
	if want <= 0.0:
		return 0.0
	if want > mx:
		# Only the last stretch is lived; the clock jumps over the rest.
		t += want - mx
		want = mx
	advance(want, 1.0)
	return want


func _tick(h: float) -> void:
	var ph := phase()
	_daily(ph)
	_trap(h)
	_batches()
	var dk := day_no
	if not days.has(dk):
		days[dk] = {}
	for k in keepers:
		var kp: Dictionary = keepers[k]
		var dd: Dictionary = days[dk]
		if not dd.has(k):
			dd[k] = {"light": 0.0, "rest": 0.0, "work": 0.0}
		if str(ph.part) == "day":
			dd[k].light = float(dd[k].light) + h
			if _resting(kp):
				dd[k].rest = float(dd[k].rest) + h
			else:
				dd[k].work = float(dd[k].work) + h
		var left := h
		var guard := 0
		while left > 1e-6 and guard < 40:
			guard += 1
			if (kp.steps as Array).is_empty():
				_plan(k, ph)
				if (kp.steps as Array).is_empty():
					break
			left = _run(k, left, ph)
	t += h


func _resting(kp: Dictionary) -> bool:
	if (kp.steps as Array).is_empty():
		return true
	return str((kp.steps as Array)[0].do) in ["rest", "round", "meal", "sleep"]


## The day's work worked so far today (minutes).
func _worked(k: String) -> float:
	var dd: Dictionary = days.get(day_no, {})
	return float((dd.get(k, {}) as Dictionary).get("work", 0.0))


## Run keeper `k`'s steps for up to `left` minutes; the minutes left over.
func _run(k: String, left: float, ph: Dictionary) -> float:
	var kp: Dictionary = keepers[k]
	var st: Dictionary = (kp.steps as Array)[0]
	if not st.has("t_left"):
		if not _begin(k, st):
			_abort(k)
			# A short pause before it looks again.
			kp.steps = [{"do": "rest", "kind": "sit_own_fire", "min": 1.0, "spot": str(kp.at)}]
			return left
	# The open-ended ones end when the day moves on.
	match str(st.do):
		"round":
			if str(ph.part) in ["dusk", "dawn"]:
				return 0.0
			_pop(k)
			return left
		"meal":
			if str(ph.part) == "night" and float(ph.get("since_dark", 0.0)) < float(S.get("evening_min", 12.0)):
				return 0.0
			_pop(k)
			return left
		"sleep":
			if str(ph.part) == "night":
				return 0.0
			_pop(k)
			return left
		"rest":
			# Rest gives way to the evening and the rounds.
			if str(ph.part) != "day" or (float(ph.get("frac", 0.0)) >= float(S.get("before_dusk_frac", 0.86)) and str(st.get("kind", "")) != "early_hearth"):
				_pop(k)
				return left
	var tl := float(st.t_left)
	if tl > left:
		st.t_left = tl - left
		return 0.0
	_end(k, st)
	_pop(k)
	return left - tl


func _pop(k: String) -> void:
	var kp: Dictionary = keepers[k]
	(kp.steps as Array).pop_front()
	if (kp.steps as Array).is_empty():
		kp.mode = "idle"
		kp.taken = {}


func dist(a: String, b: String) -> float:
	if not spots.has(a) or not spots.has(b):
		return 0.0
	var p: Vector3 = spots[a]
	var q: Vector3 = spots[b]
	return Vector2(p.x - q.x, p.z - q.z).length()


func walk_min(a: String, b: String) -> float:
	return dist(a, b) / maxf(float(S.get("walk_mps", 1.1)), 0.1) / 60.0


## A step starting: its time, and what it takes. False: it can't (the
## inputs or the tool are gone); the plan is dropped.
func _begin(k: String, st: Dictionary) -> bool:
	var kp: Dictionary = keepers[k]
	match str(st.do):
		"go", "carry":
			st.t_left = walk_min(str(kp.at), str(st.to))
			if str(st.do) == "carry" and str(st.get("what", "")) == "goods":
				var g: Dictionary = st.goods
				if not has_all(g):
					return false
				_take(g)
				kp.taken = _sum(kp.taken, g)
				kp.carry = g
			if str(st.do) == "carry" and str(st.get("what", "")) == "item":
				var it := item(int(st.item))
				if it.is_empty() or str(it.get("held", "")) not in ["", k]:
					return false
				it.held = k
				kp.item = int(st.item)
		"take_tool":
			var tl: Dictionary = tools.get(str(st.tool), {})
			if tl.is_empty() or bool(tl.broken) or str(tl.by) not in ["", k]:
				return false
			tl.by = k
			st.t_left = 0.0
		"put_tool":
			st.t_left = 0.0
		"work":
			var need: Dictionary = (st.get("in", {}) as Dictionary).duplicate()
			if float(st.get("fuel", 0.0)) > 0.0:
				need["firewood"] = float(need.get("firewood", 0.0)) + float(st.fuel)
			if not has_all(need):
				return false
			if str(st.get("tool", "")) != "":
				var tl2: Dictionary = tools.get(str(st.tool), {})
				if tl2.is_empty() or bool(tl2.broken) or str(tl2.by) not in ["", k]:
					return false
				tl2.by = k
			_take(need)
			kp.taken = _sum(kp.taken, need)
			st["took"] = need
			st.t_left = float(st.get("min", 1.0))
			kp.mode = "work"
		"away":
			st.t_left = float(st.get("min", 1.0))
			kp.away = true
			kp.mode = "away"
		"rest":
			st.t_left = float(st.get("min", 8.0))
			kp.mode = "rest"
		"round", "meal", "sleep":
			st.t_left = 1e9
			kp.mode = str(st.do)
	return true


func _end(k: String, st: Dictionary) -> void:
	var kp: Dictionary = keepers[k]
	match str(st.do):
		"go":
			kp.at = str(st.to)
		"carry":
			kp.at = str(st.to)
			_end_carry(k, st)
		"put_tool":
			var tl: Dictionary = tools.get(str(st.tool), {})
			if not tl.is_empty() and str(tl.by) == k:
				tl.by = ""
		"work":
			kp.taken = {}
			_end_work(k, st)
			var tid := str(st.get("tool", ""))
			if tid != "" and tools.has(tid) and str(tools[tid].by) == k:
				var later := false
				for s2 in (kp.steps as Array).slice(1):
					later = later or (str(s2.do) == "put_tool" and str(s2.get("tool", "")) == tid)
				if not later:
					tools[tid].by = ""
		"away":
			kp.away = false
			if str(st.get("then", "")) == "hunt":
				_hunt_home(k, st)
			elif str(st.get("then", "")) == "net":
				_net_home(k, st)


## Drop keeper `k`'s plan: what was taken goes back, tools to their spots,
## an item carried stays where it was.
func _abort(k: String) -> void:
	var kp: Dictionary = keepers[k]
	_give(kp.taken, false)
	kp.taken = {}
	kp.carry = {}
	for id in tools:
		if str(tools[id].by) == k:
			tools[id].by = ""
	if int(kp.item) >= 0:
		var it := item(int(kp.item))
		if not it.is_empty():
			it.held = ""
	kp.item = -1
	kp.away = false
	kp.steps = []
	kp.mode = "idle"


# --- The store ----------------------------------------------------------------------

func count(g: String) -> float:
	return float(store.get(g, 0.0))


func target(g: String) -> float:
	return float((meta.get(g, {}) as Dictionary).get("target", 0.0))


func cap(g: String) -> float:
	return float((meta.get(g, {}) as Dictionary).get("cap", 999.0))


func owner(g: String) -> String:
	return str((meta.get(g, {}) as Dictionary).get("owner", ""))


func has_all(g: Dictionary) -> bool:
	for k in g:
		if count(k) + 1e-6 < float(g[k]):
			return false
	return true


func _take(g: Dictionary) -> void:
	for k in g:
		store[k] = maxf(count(k) - float(g[k]), 0.0)


## Into the store; past a good's cap the rest goes back to the land
## (§GO.4: given back, the fields). What went back, by good.
func _give(g: Dictionary, count_it := true) -> Dictionary:
	var back := {}
	for k in g:
		var n := float(g[k])
		var room := cap(k) - count(k)
		var put := minf(n, maxf(room, 0.0))
		store[k] = count(k) + put
		if put < n - 1e-6:
			back[k] = n - put
		if count_it:
			produced[k] = float(produced.get(k, 0.0)) + put
	return back


static func _sum(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	for k in b:
		o[k] = float(o.get(k, 0.0)) + float(b[k])
	return o


func _log(k: String, act: String, kind: String, delta: Dictionary) -> void:
	var e := {"t": snappedf(t, 0.01), "k": k, "act": act, "kind": kind, "delta": delta}
	log.append(e)
	if log_max > 0 and log.size() > log_max:
		log.pop_front()


# --- Items in the chains --------------------------------------------------------------

func item(id: int) -> Dictionary:
	for it in items:
		if int(it.id) == id:
			return it
	return {}


static func stage_of(it: Dictionary) -> Dictionary:
	var stg: Array = (chains().get(str(it.chain), {}) as Dictionary).get("stages", [])
	var i := int(it.stage)
	return stg[i] if i >= 0 and i < stg.size() else {}


## A stage's station, as a spot.
static func station(stg: Dictionary) -> String:
	var at := str(stg.get("at", ""))
	if at == "hearth" or at.contains("."):
		return at
	return "hearth" if str(stg.get("by", "")) == "shaman" else "%s.%s" % [stg.get("by", ""), at]


## A new item of `chain` at spot `at` holding `goods` (the chain's extra
## added), at its first stage or `stage_id`.
func new_item(chain: String, at: String, goods: Dictionary, stage_id := "", by := "") -> Dictionary:
	var C: Dictionary = chains().get(chain, {})
	var g := goods.duplicate()
	for x in (C.get("extra", {}) as Dictionary):
		g[x] = float(g.get(x, 0.0)) + float(C.extra[x])
	var si := 0
	var stg: Array = C.get("stages", [])
	for i in stg.size():
		if str(stg[i].get("id", "")) == stage_id:
			si = i
	var it := {"id": _next, "chain": chain, "stage": si, "at": at, "goods": g, "ready": t, "held": "", "moves": [[snappedf(t, 0.01), "enter", at, by]], "shown": "raw"}
	_next += 1
	items.append(it)
	return it


## What an item will give the store, all stages done (the planner's
## pending count): its goods run through the converts still ahead.
func yield_of(it: Dictionary) -> Dictionary:
	var g: Dictionary = (it.goods as Dictionary).duplicate()
	var stg: Array = (chains().get(str(it.chain), {}) as Dictionary).get("stages", [])
	for i in range(int(it.stage), stg.size()):
		var cv: Dictionary = stg[i].get("convert", {})
		for f in cv:
			if g.has(f):
				var to: Array = cv[f]
				g[str(to[0])] = float(g.get(str(to[0]), 0.0)) + float(g[f]) * float(to[1])
				g.erase(f)
		for o in (stg[i].get("out", {}) as Dictionary):
			g[o] = float(g.get(o, 0.0)) + float(stg[i].out[o])
	return g


func pending(g: String) -> float:
	var n := 0.0
	for it in items:
		n += float(yield_of(it).get(g, 0.0))
	for b in batches:
		n += float((b.out as Dictionary).get(g, 0.0))
	return n


## A stage worked: its outputs and leftovers in, its converts done, goods
## not kept go to the store; the fresh choice (§GO.3.1); then the next
## stage (its wait first), or the item ends with everything in the store.
func _finish_stage(k: String, it: Dictionary) -> Dictionary:
	var stg := stage_of(it)
	var before := store.duplicate()
	var g: Dictionary = it.goods
	var back := {}
	for s in (stg.get("short_to_store", {}) as Dictionary):
		var n := minf(float(stg.short_to_store[s]), float(g.get(s, 0.0)))
		if n > 0.0 and count(s) < target(s):
			back.merge(_give({s: n}))
			g[s] = float(g[s]) - n
			if float(g[s]) <= 1e-6:
				g.erase(s)
	var cv: Dictionary = stg.get("convert", {})
	for f in cv:
		if g.has(f):
			var to: Array = cv[f]
			g[str(to[0])] = float(g.get(str(to[0]), 0.0)) + float(g[f]) * float(to[1])
			g.erase(f)
	back.merge(_give(stg.get("out", {})))
	var end := ""
	var fc: Dictionary = stg.get("fresh_choice", {})
	if not fc.is_empty() and g.has(str(fc.good)) and _food_short():
		g[str(fc.to)] = float(g.get(str(fc.to), 0.0)) + float(g[str(fc.good)])
		g.erase(str(fc.good))
		end = "fresh"
	var last := int(it.stage) + 1 >= ((chains().get(str(it.chain), {}) as Dictionary).get("stages", []) as Array).size()
	if end == "" and not last:
		var keep: Array = stg.get("keep", [])
		if not keep.is_empty():
			var rest := {}
			for x in g.keys():
				if not keep.has(x):
					rest[x] = g[x]
					g.erase(x)
			back.merge(_give(rest))
	it.shown = str(stg.get("show", ""))
	(it.moves as Array).append([snappedf(t, 0.01), "done", str(stg.get("id", "")), k])
	if end != "" or last:
		back.merge(_give(g))
		var res := "fresh" if end == "fresh" else "store"
		if not back.is_empty():
			res += "+fields"
		_end_item(it, res, g.duplicate())
	else:
		it.stage = int(it.stage) + 1
		it.ready = t + float(stg.get("wait_h", 0.0)) * float(S.get("hour_min", 6.0))
	var delta := _diff(before, store)
	delta["item:%d" % int(it.id)] = str(stg.get("id", ""))
	if not back.is_empty():
		delta["fields"] = back
	return delta


func _end_item(it: Dictionary, how: String, goods: Dictionary) -> void:
	(it.moves as Array).append([snappedf(t, 0.01), "end", how, ""])
	ended.append({"id": int(it.id), "chain": str(it.chain), "end": how, "goods": goods, "moves": it.moves})
	items.erase(it)


func _diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := {}
	for k in b:
		var d := float(b[k]) - float(a.get(k, 0.0))
		if absf(d) > 1e-6:
			o[k] = snappedf(d, 0.001)
	return o


## Is tonight's meal short (the food in store less than a meal takes)?
func _food_short() -> bool:
	if count("meal") >= 1.0:
		return false
	var lines := 0
	for f in FOOD:
		if count(f) >= 1.0:
			lines += 1
	return lines < 2


# --- The planner ------------------------------------------------------------------------

func _plan(k: String, ph: Dictionary) -> void:
	var kp: Dictionary = keepers[k]
	var part := str(ph.part)
	var home := _home(k)
	if part in ["dusk", "dawn"]:
		if str(kp.at) != home:
			kp.steps = [{"do": "go", "to": home}]
		else:
			kp.steps = [{"do": "round"}]
		return
	if part == "night":
		var evening := float(ph.get("since_dark", 0.0)) < float(S.get("evening_min", 12.0))
		var bench := "bench." + k
		if evening and str(kp.at) != bench and k != "shaman":
			kp.steps = [{"do": "go", "to": bench}, {"do": "meal"}]
		elif evening:
			kp.steps = [{"do": "meal"}]
		else:
			var bed := home if k == "shaman" else k + ".shelter"
			kp.steps = [{"do": "go", "to": bed}, {"do": "sleep"}] if str(kp.at) != bed else [{"do": "sleep"}]
		return
	# Daylight.
	var frac := float(ph.frac)
	var fit := float(ph.to_dusk) - 1.0
	if frac >= float(S.get("before_dusk_frac", 0.86)):
		var late := _before_dusk(k, fit)
		if not late.is_empty():
			kp.steps = late
			return
		if str(kp.at) != home:
			kp.steps = [{"do": "go", "to": home}]
		else:
			kp.steps = [{"do": "rest", "kind": "early_hearth", "min": maxf(fit, 1.0), "spot": home}]
		return
	var tired := _worked(k) >= float(S.get("work_share_max", 0.7)) * float(ph.light)
	if not tired:
		for f in [_plan_order, _plan_band, _plan_item, _plan_upgrade, _plan_stock, _plan_leftover]:
			var steps: Array = f.call(k, ph)
			if not steps.is_empty() and _est(k, steps) <= fit:
				kp.steps = steps
				return
	kp.steps = _rest(k, ph, fit)


## Before dusk (§GM.8.4): the woodcutter carries firewood to the main
## hearth for the night; the shaman cooks the meal.
func _before_dusk(k: String, fit: float) -> Array:
	if k == "woodcutter_firekeeper":
		var want := minf(_hearth_burn(), cap("hearth_wood")) - count("hearth_wood")
		var n := minf(floorf(want), count("firewood"))
		if n >= 1.0:
			return [{"do": "go", "to": k + ".woodpile"}, {"do": "carry", "what": "goods", "goods": {"firewood": n}, "to": "hearth", "into": {"hearth_wood": n}}]
	if k == "shaman" and count("meal") < 1.0:
		var cook := _cook_steps()
		if not cook.is_empty():
			return cook
	return []


func _cook_steps() -> Array:
	var R: Dictionary = (D.get("recipes", {}) as Dictionary).get("cook_meal", {})
	var take := {}
	var lines := 0
	for f in FOOD:
		var want := float((R.get("in", {}) as Dictionary).get(f, 1.0 if f == "fresh_food" else 0.0))
		if f == "fresh_food":
			want = count(f)
		var n := minf(want, count(f))
		if n >= 1.0 or (f == "fresh_food" and n > 0.0):
			take[f] = n
			lines += 1
	if lines < 2 or count("water") < 1.0:
		return []
	take["water"] = 1.0
	return [{"do": "work", "act": "cook_meal", "kind": "cook", "in": take, "out": {"meal": 1.0}, "tool": str(R.get("tool", "")), "min": float(R.get("work_min", 15.0))}]


func _hearth_burn() -> float:
	return float(((D.get("use", {}) as Dictionary).get("firewood_per_night", {}) as Dictionary).get("hearth", 4.0))


## Minutes a plan should take (its walks and work).
func _est(k: String, steps: Array) -> float:
	var at := str(keepers[k].at)
	var m := 0.0
	for st in steps:
		if st.has("to"):
			m += walk_min(at, str(st.to))
			at = str(st.to)
		m += float(st.get("min", 0.0))
	return m


static func tool_spot(id: String) -> String:
	var T: Dictionary = _tools().get(id, {})
	var camp := str(T.get("camp", ""))
	var sp := str(T.get("spot", ""))
	if camp == "shaman" or sp in ["hearth", "in_hand"]:
		return "hearth" if camp == "shaman" else "%s.seat" % camp
	return "%s.%s" % [camp, sp]


func usable(id: String, k: String) -> bool:
	var tl: Dictionary = tools.get(id, {})
	return not tl.is_empty() and not bool(tl.broken) and str(tl.by) in ["", k]


## Wrap `body` (steps done at the work's place) with taking `tool_ids`
## from their spots first and putting them back after (§GM.2).
func _with_tools(tool_ids: Array, body: Array) -> Array:
	var pre: Array = []
	var post: Array = []
	for id in tool_ids:
		if str(id) == "" or str((_tools().get(str(id), {}) as Dictionary).get("spot", "")) == "in_hand":
			continue
		var sp := tool_spot(str(id))
		pre.append_array([{"do": "go", "to": sp}, {"do": "take_tool", "tool": str(id)}])
		post.push_front({"do": "put_tool", "tool": str(id)})
		post.push_front({"do": "go", "to": sp})
	return pre + body + post


# 1. An order for a tool (§GM.5): made at the knapping stone (or the
# maker's own spot) and carried over to the tool's spot.
func _plan_order(k: String, _ph: Dictionary) -> Array:
	for o in orders:
		if str(o.by) != k:
			continue
		var T: Dictionary = _tools().get(str(o.tool), {})
		var from: Dictionary = T.get("from", {})
		if not has_all(from):
			continue
		var F: Dictionary = D.get("flake", {})
		var at := "%s.%s" % [k, F.get("at", "knapping_stone")] if k == "knapper_potter" else k + ".seat"
		var use: Array = (F.get("tools", []) as Array).filter(func(x): return usable(str(x), k)) if k == "knapper_potter" else []
		var body: Array = [{"do": "go", "to": at}, {"do": "work", "act": "make_" + str(o.tool), "kind": "order", "order": int(o.id), "in": from, "min": float(F.get("work_min_per_part", 10.0)), "tool": str(use[0]) if not use.is_empty() else ""}]
		var steps := _with_tools(use.slice(1), body)
		steps.append({"do": "carry", "what": "tool", "tool": str(o.tool), "order": int(o.id), "to": tool_spot(str(o.tool))})
		return steps
	return []


# 1b. An instrument for the band (§GO.10.1): learned from a bard, its
# material set down in the store, the maker builds it.
func _plan_band(k: String, _ph: Dictionary) -> Array:
	var I: Dictionary = Tuning.table("realm_folk").get("instruments", {})
	for id in band_learned:
		var ins: Dictionary = I.get(str(id), {})
		if ins.is_empty() or band_made.has(str(id)) or str(ins.get("made_by", "knapper_potter")) != k:
			continue
		var mat := {str(ins.get("material", "")): 1.0}
		if not has_all(mat):
			continue
		var at := _spot_of(k, "knapping_stone" if k == "knapper_potter" else "seat")
		return [{"do": "go", "to": at}, {"do": "work", "act": "make_" + str(id), "kind": "band", "instrument": str(id), "in": mat, "min": float(ins.get("work_min", 12.0))}]
	return []


# 2. A chain item ready for this keeper's next stage (carried to its
# station first), or one this keeper must deliver to the shaman.
func _plan_item(k: String, _ph: Dictionary) -> Array:
	for it in items:
		if float(it.ready) > t + 1e-6 or str(it.held) != "":
			continue
		var stg := stage_of(it)
		var by := str(stg.get("by", ""))
		var st := station(stg)
		var need: Dictionary = (stg.get("in", {}) as Dictionary).duplicate()
		if float(stg.get("fuel", 0.0)) > 0.0:
			need["firewood"] = float(need.get("firewood", 0.0)) + float(stg.fuel)
		if not has_all(need):
			continue
		if str(it.at) != st:
			# The shaman never leaves the fire: whoever worked it last brings it.
			var carrier := by
			if by == "shaman":
				var mv: Array = it.moves
				carrier = str(mv[mv.size() - 1][3]) if mv.size() > 0 else ""
				if carrier == "" or carrier == "shaman":
					carrier = str(stage_of({"chain": it.chain, "stage": maxi(int(it.stage) - 1, 0)}).get("by", ""))
			if carrier != k:
				continue
			if by != k:
				return [{"do": "go", "to": str(it.at)}, {"do": "carry", "what": "item", "item": int(it.id), "to": st}]
		elif by != k:
			continue
		var tool := str(stg.get("tool", ""))
		if tool != "" and not usable(tool, k):
			continue
		var body: Array = []
		if str(it.at) != st:
			body = [{"do": "go", "to": str(it.at)}, {"do": "carry", "what": "item", "item": int(it.id), "to": st}]
		else:
			body = [{"do": "go", "to": st}]
		body.append({"do": "work", "act": "%s_%s" % [it.chain, stg.get("id", "")], "kind": "stage", "item": int(it.id), "in": stg.get("in", {}), "fuel": float(stg.get("fuel", 0.0)), "tool": tool, "min": float(stg.get("work_h", 0.5)) * float(S.get("hour_min", 6.0))})
		if tool == "" or tool_spot(tool) == st:
			return body
		# The tool fetched first, carried with the item, put back after.
		var pre: Array = [{"do": "go", "to": tool_spot(tool)}, {"do": "take_tool", "tool": tool}]
		return pre + body + [{"do": "go", "to": tool_spot(tool)}, {"do": "put_tool", "tool": tool}]
	return []


# 4. The stock this keeper owns that is shortest against its target.
func _plan_stock(k: String, ph: Dictionary) -> Array:
	var short: Array = []
	for g in meta:
		if owner(g) != k or target(g) <= 0.0:
			continue
		var have := count(g) + pending(g)
		if have < target(g):
			short.append([have / target(g), g])
	short.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for s in short:
		var steps := _make(k, str(s[1]), ph, float(s[0]), 0)
		if not steps.is_empty():
			return steps
	return []


## The steps that raise good `g` for keeper `k`: a recipe of theirs with
## its inputs at hand, else a source trip, else (one level) whatever of
## theirs makes a missing input.
func _make(k: String, g: String, ph: Dictionary, ratio: float, depth: int) -> Array:
	var R: Dictionary = D.get("recipes", {})
	var replaced := _replaced()
	for id in R:
		var r: Dictionary = R[id]
		if str(r.get("by", "")) != k or replaced.has(id) or id in ["cook_meal"] or not (r.get("out", {}) as Dictionary).has(g):
			continue
		if not has_all(_recipe_need(r)):
			if depth == 0:
				for x in (r.get("in", {}) as Dictionary):
					if count(x) < float(r.in[x]) and owner(x) == k:
						var sub := _make(k, x, ph, ratio, 1)
						if not sub.is_empty():
							return sub
			continue
		var tool := str(r.get("tool", ""))
		if tool != "" and not usable(tool, k):
			continue
		return _with_tools([tool], [{"do": "go", "to": _spot_of(k, str(r.get("at", "seat")))}, {"do": "work", "act": id, "kind": "recipe", "in": r.get("in", {}), "fuel": float(r.get("fuel", 0.0)), "out": r.get("out", {}), "wait": float(r.get("wait_min", 0.0)), "min": float(r.get("work_min", 5.0))}])
	var trips_ok := float(ph.frac) < float(S.get("morning_frac", 0.4)) or ratio < 0.5
	for sid in _sources():
		if not source_yield(sid).has(g) or _source_by(sid) != k:
			continue
		var trip := _trip(k, sid, trips_ok)
		if not trip.is_empty():
			return trip
	return []


func _recipe_need(r: Dictionary) -> Dictionary:
	var need: Dictionary = (r.get("in", {}) as Dictionary).duplicate()
	if float(r.get("fuel", 0.0)) > 0.0:
		need["firewood"] = float(need.get("firewood", 0.0)) + float(r.fuel)
	return need


func _replaced() -> Array:
	var out: Array = []
	for c in chains():
		out.append_array((chains()[c] as Dictionary).get("replaces", []))
	return out


func _spot_of(k: String, sp: String) -> String:
	if k == "shaman" or sp in ["cauldron", "hearth"]:
		return "hearth"
	return "%s.%s" % [k, sp]


## What a source gives a trip, with upgrades' effects (§GO.1.4).
func _source_gives(sid: String) -> Dictionary:
	var g: Dictionary = ((_sources().get(sid, {}) as Dictionary).get("gives", {}) as Dictionary).duplicate()
	for u in upgrades:
		var U: Dictionary = (D.get("upgrades", {}) as Dictionary).get(str(u).get_slice("@", 0), {})
		var sg: Dictionary = ((U.get("effect", {}) as Dictionary).get("source_gives", {}) as Dictionary).get(sid, {})
		for x in sg:
			g[x] = float(sg[x])
	return g


## What a trip to `sid` ends as in the store, its chain run through.
func source_yield(sid: String) -> Dictionary:
	var c := chain_of(sid)
	var g := _source_gives(sid)
	if c == "":
		return g
	for x in ((chains()[c] as Dictionary).get("extra", {}) as Dictionary):
		g[x] = float(g.get(x, 0.0)) + float(chains()[c].extra[x])
	return yield_of({"chain": c, "stage": 0, "goods": g})


static func _source_by(sid: String) -> String:
	var g: Dictionary = (_sources().get(sid, {}) as Dictionary).get("gives", {})
	for x in g:
		var o := str((((D.get("stocks", {}) as Dictionary).get(x, {})) as Dictionary).get("owner", ""))
		if o != "":
			return o
	return ""


static func chain_of(sid: String) -> String:
	for c in chains():
		if ((chains()[c] as Dictionary).get("from", []) as Array).has(sid):
			return c
	return ""


## A trip to source `sid` by keeper `k` (the tools it needs taken along).
func _trip(k: String, sid: String, trips_ok: bool) -> Array:
	var sd: Dictionary = _sources().get(sid, {})
	var s: Dictionary = sources.get(sid, {})
	var need_tools: Array = []
	if sd.has("tool"):
		need_tools.append(str(sd.tool))
	need_tools.append_array(sd.get("tools", []))
	if sid == "game":
		# The hunter takes whichever of spear and bow is whole.
		var whole := need_tools.filter(func(x): return usable(str(x), k))
		if whole.is_empty():
			return []
		need_tools = [whole[0]]
	for x in need_tools:
		if not usable(str(x), k):
			return []
	var wm := float(sd.get("work_min", 5.0))
	match sid:
		"fish_trap":
			if float(s.trap) < 1.0:
				return []
			return _with_tools([], [{"do": "go", "to": "fisher_weaver.river"}, {"do": "work", "act": "check_trap", "kind": "source", "src": sid, "tool": need_tools[0], "min": wm}])
		"garden_bed":
			# Tended once a day with water from the river (§GM.4), harvested when ripe.
			if int(s.water_days) < int(sd.get("ripe_every_days", 2)):
				if int(s.get("tended", -1)) == int(floor(now_days())) or count("water") < 1.0:
					return []
				return _with_tools([], [{"do": "go", "to": "forager_herbalist.garden_bed"}, {"do": "work", "act": "tend_garden", "kind": "tend", "src": sid, "in": {"water": 1.0}, "tool": need_tools[0], "min": wm}])
			return [{"do": "go", "to": "forager_herbalist.garden_bed"}, {"do": "work", "act": "harvest_garden", "kind": "source", "src": sid, "tool": need_tools[0], "min": wm}]
		"river_net":
			if not trips_ok:
				return []
			var pre := _with_tools(need_tools, [])
			# The dugout out on the river (gone from the bank).
			var half := pre.size() / 2
			return pre.slice(0, half) + [{"do": "go", "to": "fisher_weaver.bank"}, {"do": "away", "min": wm, "then": "net", "src": sid, "tool": "net"}] + pre.slice(half)
		"game":
			if not trips_ok or float(s.left) < 1.0:
				return []
			var prey: Vector3 = prey_fn.call() if prey_fn.is_valid() else Vector3.INF
			if prey != Vector3.INF:
				spots["prey"] = prey
				return _with_tools(need_tools, [{"do": "go", "to": "prey"}, {"do": "work", "act": "hunt", "kind": "source", "src": sid, "tool": need_tools[0], "min": wm, "prey": true}])
			return _with_tools(need_tools, [{"do": "go", "to": "edge"}, {"do": "away", "min": float(sd.get("off_screen_min", 40.0)), "then": "hunt", "src": sid, "tool": need_tools[0]}])
	if sd.has("count") and float(s.left) < 1.0:
		return []
	if not trips_ok and chain_of(sid) != "":
		return []
	var at := _source_spot(sid)
	return _with_tools(need_tools, [{"do": "go", "to": at}, {"do": "work", "act": "gather_" + sid, "kind": "source", "src": sid, "tool": need_tools[0] if not need_tools.is_empty() else "", "min": wm}])


## Where a source is worked from: one of its places in the clearing.
func _source_spot(sid: String) -> String:
	match sid:
		"clay_pit":
			return "knapper_potter.clay_pit"
		"flint_bank":
			return "flint_bank"
		"river_water":
			return "river_water"
	var opts: Array = spots.keys().filter(func(x): return str(x).begins_with(sid + "."))
	if opts.is_empty():
		return _home(_source_by(sid))
	return str(opts[rng.randi_range(0, opts.size() - 1)])


# 5. Leftovers worked when there are enough (carving fish bones).
func _plan_leftover(k: String, _ph: Dictionary) -> Array:
	var R: Dictionary = D.get("chain_recipes", {})
	for id in R:
		var r: Dictionary = R[id]
		if str(r.get("by", "")) != k or not has_all(r.get("in", {})):
			continue
		var full := false
		for o in (r.get("out", {}) as Dictionary):
			full = full or count(o) >= cap(o)
		if full:
			continue
		var tool := str(r.get("tool", ""))
		if tool != "" and not usable(tool, k):
			continue
		return _with_tools([tool], [{"do": "go", "to": _spot_of(k, str(r.get("at", "seat")))}, {"do": "work", "act": id, "kind": "recipe", "in": r.get("in", {}), "out": r.get("out", {}), "min": float(r.get("work_min", 5.0))}])
	return []


# 3. Growing the camp (§GO.1.4), in upgrade_order, as soon as its goods
# are in the store (the camp earns its growth).
func _plan_upgrade(k: String, _ph: Dictionary) -> Array:
	var U: Dictionary = D.get("upgrades", {})
	for uid in D.get("upgrade_order", U.keys()):
		var u: Dictionary = U.get(str(uid), {})
		if str(u.get("by", "")) != k or not has_all(u.get("in", {})):
			continue
		var where: Array = []
		if bool(u.get("per_keeper", false)):
			for kk in keeper_keys():
				if kk != "shaman":
					where.append(kk)
		else:
			where.append("")
		for kk in where:
			var key := str(uid) if str(kk) == "" else "%s@%s" % [uid, kk]
			if upgrades.has(key):
				continue
			var at := str(u.get("at", "seat"))
			var spot := at if at.contains(".") or at == "hearth" else ("%s.%s" % [kk, at] if str(kk) != "" else "%s.%s" % [k, at])
			return [{"do": "go", "to": spot}, {"do": "work", "act": "build_" + key, "kind": "upgrade", "upgrade": key, "in": u.get("in", {}), "min": float(u.get("work_h", 1.0)) * float(S.get("hour_min", 6.0))}]
	return []


## Rest (§GM.7): by weight and the hour, for a while.
func _rest(k: String, ph: Dictionary, fit: float) -> Array:
	var C: Dictionary = (D.get("rest", {}) as Dictionary).get("choices", {})
	var hour := _hour(ph)
	var pool: Array = []
	var total := 0.0
	for c in C:
		var hrs: Array = (C[c] as Dictionary).get("hours", [])
		if not hrs.is_empty() and not hrs.has(hour):
			continue
		if k == "shaman" and c != "sit_own_fire" and c != "pipe":
			continue
		total += float((C[c] as Dictionary).get("weight", 1.0))
		pool.append(c)
	var pick := "sit_own_fire"
	var r := rng.randf() * total
	for c in pool:
		r -= float((C[c] as Dictionary).get("weight", 1.0))
		if r <= 0.0:
			pick = str(c)
			break
	var R: Dictionary = D.get("rest", {})
	var m := minf(rng.randf_range(float(R.get("min_min", 8.0)), float(R.get("max_min", 30.0))), maxf(fit, 1.0))
	var spot := _home(k)
	match pick:
		"visit_keeper":
			var others := keeper_keys().filter(func(x): return x != k and x != "shaman")
			spot = str(others[rng.randi_range(0, others.size() - 1)]) + ".seat" if not others.is_empty() else spot
		"nap_shelter":
			spot = k + ".shelter"
		"river_edge":
			spot = "fisher_weaver.river"
		"early_hearth":
			spot = "bench." + k
	if k == "shaman":
		spot = "hearth"
	if spot != str(keepers[k].at):
		return [{"do": "go", "to": spot}, {"do": "rest", "kind": pick, "min": m, "spot": spot}]
	return [{"do": "rest", "kind": pick, "min": m, "spot": spot}]


# --- Ends of work -----------------------------------------------------------------------

func _wear(id: String, k: String) -> Dictionary:
	if id == "":
		return {}
	var tl: Dictionary = tools.get(id, {})
	if tl.is_empty() or int((_tools().get(id, {}) as Dictionary).get("uses", 0)) <= 0:
		return {}
	tl.uses = int(tl.uses) - 1
	if int(tl.uses) > 0:
		return {}
	# Broken at its spot (§GM.2.2), and reordered from its maker (§GM.5).
	tl.broken = true
	if str(tl.by) == k:
		tl.by = ""
	var T: Dictionary = _tools().get(id, {})
	var o := {"id": _next, "tool": id, "by": str(T.get("made_by", "knapper_potter")), "from": T.get("from", {}), "t": t}
	_next += 1
	orders.append(o)
	_log(k, "broke_" + id, "event", {"tool:" + id: "broken"})
	return {"tool:" + id: "broken"}


func _end_work(k: String, st: Dictionary) -> void:
	var before := store.duplicate()
	var delta := {}
	var extra := {}
	match str(st.get("kind", "")):
		"recipe", "cook":
			if float(st.get("wait", 0.0)) > 0.0:
				# Hands off (smoking, firing): it comes out later (§GM.5).
				batches.append({"at": t + float(st.wait), "out": st.get("out", {}), "by": k, "act": str(st.get("act", ""))})
				extra["batch"] = str(st.get("act", ""))
			else:
				var back := _give(st.get("out", {}))
				if not back.is_empty():
					extra["fields"] = back
			if str(st.get("kind", "")) == "cook":
				extra["meal"] = "cooked"
		"stage":
			var it := item(int(st.item))
			if not it.is_empty():
				it.held = ""
				extra = _finish_stage(k, it)
		"source":
			extra = _finish_source(k, st)
		"tend":
			var s: Dictionary = sources.get(str(st.src), {})
			s.water_days = int(s.water_days) + 1
			s["tended"] = int(floor(now_days()))
			extra["garden"] = "watered"
		"order":
			for o in orders:
				if int(o.id) == int(st.order):
					o["made"] = true
			keepers[k].carry = {"tool": str(_order(int(st.order)).get("tool", ""))}
			extra["made"] = str(_order(int(st.order)).get("tool", ""))
		"upgrade":
			upgrades[str(st.upgrade)] = true
			extra["upgrade"] = str(st.upgrade)
		"band":
			var ins: Dictionary = (Tuning.table("realm_folk").get("instruments", {}) as Dictionary).get(str(st.instrument), {})
			band_made[str(st.instrument)] = str(ins.get("player", "fisher_weaver"))
			extra["band"] = str(st.instrument)
	delta = _diff(before, store)
	for k2 in (st.get("took", {}) as Dictionary):
		delta[k2] = snappedf(float(delta.get(k2, 0.0)) - float(st.took[k2]), 0.001)
		if absf(float(delta[k2])) < 1e-6:
			delta.erase(k2)
	delta.merge(extra, true)
	delta.merge(_wear(str(st.get("tool", "")), k), true)
	_log(k, str(st.get("act", "")), str(st.get("kind", "")), delta)


func _order(id: int) -> Dictionary:
	for o in orders:
		if int(o.id) == id:
			return o
	return {}


func _end_carry(k: String, st: Dictionary) -> void:
	var kp: Dictionary = keepers[k]
	match str(st.get("what", "")):
		"goods":
			kp.taken = {}
			kp.carry = {}
			var into: Dictionary = st.get("into", {})
			var back := _give(into, false)
			var d := _sum({}, into)
			for g in (st.goods as Dictionary):
				d[g] = -float(st.goods[g])
			if not back.is_empty():
				d["fields"] = back
			_log(k, "carry_to_" + str(st.to), "carry", d)
		"item":
			var it := item(int(st.item))
			kp.item = -1
			if not it.is_empty():
				it.at = str(st.to)
				it.held = ""
				(it.moves as Array).append([snappedf(t, 0.01), "carried", str(st.to), k])
				_log(k, "carry_%s_to_%s" % [it.chain, st.to], "carry", {"item:%d" % int(it.id): str(st.to)})
		"tool":
			# The new tool set at its spot, whole (the order done).
			var id := str(st.tool)
			kp.carry = {}
			if tools.has(id):
				tools[id].broken = false
				tools[id].uses = int((_tools().get(id, {}) as Dictionary).get("uses", 0))
				tools[id].by = ""
			orders = orders.filter(func(o): return int(o.id) != int(st.order))
			_log(k, "deliver_" + id, "carry", {"tool:" + id: "whole"})


## A source trip's end: its goods as a new chain item at the station it
## starts at (or straight into the store, where no chain takes it).
func _finish_source(k: String, st: Dictionary) -> Dictionary:
	var sid := str(st.src)
	var sd: Dictionary = _sources().get(sid, {})
	var s: Dictionary = sources.get(sid, {})
	var g := _source_gives(sid)
	match sid:
		"fish_trap":
			var n := floorf(float(s.trap))
			s.trap = float(s.trap) - n
			var d := {}
			for i in int(n):
				var it := new_item("fish", "fisher_weaver.river", g, "", k)
				d["item:%d" % int(it.id)] = "fish"
			return d
		"garden_bed":
			s.water_days = 0
			var F: Dictionary = (D.get("feeds", {}) as Dictionary).get(sid, {})
			var fed: Dictionary = F.get("take", {})
			if has_all(fed):
				_take(fed)
				for x in (F.get("bonus", {}) as Dictionary):
					g[x] = float(g.get(x, 0.0)) + float(F.bonus[x])
			var it2 := new_item(chain_of(sid), "forager_herbalist.garden_bed", g, "", k)
			return {"item:%d" % int(it2.id): it2.chain}
		"game":
			if bool(st.get("prey", false)) and kill_fn.is_valid():
				kill_fn.call(spots.get("prey", Vector3.INF))
	if sd.has("count"):
		s.left = maxf(float(s.left) - 1.0, 0.0)
	var c := chain_of(sid)
	if c == "":
		var back := _give(g)
		return {"fields": back} if not back.is_empty() else {}
	var at := str(keepers[k].at)
	if at == "prey":
		at = "kill.%d" % _next
		spots[at] = spots.get("prey", Vector3.ZERO)
	var it3 := new_item(c, at, g, "", k)
	return {"item:%d" % int(it3.id): c}


## Home from the off-screen hunt (§GM.4): a kill at the odds the game left
## gives, over his shoulder at the camp's edge.
func _hunt_home(k: String, st: Dictionary) -> void:
	var sd: Dictionary = _sources().get("game", {})
	var s: Dictionary = sources.get("game", {})
	var odds := float(sd.get("off_screen_success", 0.5)) * float(s.left) / maxf(float(sd.get("count", 1.0)), 1.0)
	if rng.randf() < odds:
		s.left = maxf(float(s.left) - 1.0, 0.0)
		var it := new_item("hunt", "edge", _source_gives("game"), "", k)
		_log(k, "hunt_home", "source", {"item:%d" % int(it.id): "hunt"})
		_wear(str(st.get("tool", "")), k)
	else:
		_log(k, "hunt_home_empty", "away", {})


func _net_home(k: String, _st: Dictionary) -> void:
	var sd: Dictionary = _sources().get("river_net", {})
	if rng.randf() < float(sd.get("success", 0.7)):
		var d := {}
		for i in int(float((sd.get("gives", {}) as Dictionary).get("raw_fish", 1.0))):
			var it := new_item("fish", "fisher_weaver.bank", {"raw_fish": 1.0}, "", k)
			d["item:%d" % int(it.id)] = "fish"
		_log(k, "net_home", "source", d)
		_wear("net", k)
	else:
		_log(k, "net_home_empty", "away", {})


# --- Every day -------------------------------------------------------------------------

func _trap(h: float) -> void:
	var sd: Dictionary = _sources().get("fish_trap", {})
	var s: Dictionary = sources.get("fish_trap", {})
	if s.is_empty():
		return
	s.trap = minf(float(s.trap) + float(sd.get("fills_per_day", 2.0)) * h / day_min, float(sd.get("max_in_trap", 3.0)))


## What the camp uses (§GM.1.3), once each: the night's fires at dark, the
## meal at the start of the evening, and at dawn the hearth's ash and
## charcoal, the sources' regrowth, cracked pots and spoiled food.
func _daily(ph: Dictionary) -> void:
	var part := str(ph.part)
	var was := _last_part
	_last_part = part
	if was == "" or was == part:
		return
	var U: Dictionary = D.get("use", {})
	if part == "night":
		var F: Dictionary = U.get("firewood_per_night", {})
		var lamps := 0.0
		for k in keeper_keys():
			if k == "shaman":
				continue
			var mult := 1.0
			for u in upgrades:
				if str(u).ends_with("@" + k):
					mult *= float((((D.get("upgrades", {}) as Dictionary).get(str(u).get_slice("@", 0), {}) as Dictionary).get("effect", {}) as Dictionary).get("lamp_burn_mult", 1.0))
			lamps += float(F.get("each_lamp", 0.5)) * mult + float(F.get("each_torch_post", 0.5))
		var hearth := float(F.get("hearth", 4.0))
		var from_hw := minf(hearth, count("hearth_wood"))
		var before := store.duplicate()
		store["hearth_wood"] = count("hearth_wood") - from_hw
		var rest := hearth - from_hw + lamps
		_cache["burned"] = from_hw + minf(rest, count("firewood"))
		_cache["short"] = maxf(rest - count("firewood"), 0.0)
		store["firewood"] = maxf(count("firewood") - rest, 0.0)
		_log("woodcutter_firekeeper", "night_fires", "use", _diff(before, store))
		# The evening meal (§GM.8.6).
		var before2 := store.duplicate()
		if count("meal") >= 1.0:
			store["meal"] = count("meal") - 1.0
		else:
			# No pot cooked: they eat what there is (§GM.10: nobody starves).
			var eat := 0
			for f in FOOD:
				if count(f) >= 1.0 and eat < 2:
					store[f] = count(f) - 1.0
					eat += 1
		_log("shaman", "evening_meal", "use", _diff(before2, store))
	elif part == "day" and was == "dawn":
		day_no += 1
		var before3 := store.duplicate()
		if float(_cache.get("burned", 0.0)) > 0.0:
			_give(D.get("hearth_leftovers", {}))
		for sid in _sources():
			var sd: Dictionary = _sources()[sid]
			if sd.has("count"):
				sources[sid].left = minf(float(sources[sid].left) + float(sd.get("regrow_per_day", 0.0)), float(sd.count))
		var crack := float(U.get("pot_crack_chance_per_day", 0.0))
		for i in int(count("fired_pots")):
			if rng.randf() < crack:
				store["fired_pots"] = count("fired_pots") - 1.0
		if count("fresh_food") > 0.0:
			# Fresh food keeps a day; the rest goes to the fields (§GO.3).
			var n := count("fresh_food")
			store["fresh_food"] = 0.0
			_give({"compost": n})
		_log("forager_herbalist", "dawn", "use", _diff(before3, store))


func _batches() -> void:
	for b in batches.duplicate():
		if float(b.at) <= t:
			batches.erase(b)
			var back := _give(b.out)
			var d := (b.out as Dictionary).duplicate()
			if not back.is_empty():
				d["fields"] = back
			_log(str(b.by), str(b.act) + "_done", "event", d)


# --- Bringing (§GO.2) -------------------------------------------------------------------

## A thing the player sets down in the camp store: into its chain (its
## first stage, or the bring entry's), at the store. True if it went in.
func bring(what: String) -> bool:
	var B: Dictionary = (D.get("bring", {}) as Dictionary).get(what, {})
	if B.is_empty():
		return false
	var c := str(B.get("chain", ""))
	if c == "":
		_give(B.get("goods", {}))
		_log("player", "bring_" + what, "bring", B.get("goods", {}))
		return true
	var it := new_item(c, "store", B.get("goods", {}), str(B.get("stage", "")), "player")
	_log("player", "bring_" + what, "bring", {"item:%d" % int(it.id): c})
	return true


# --- The save ---------------------------------------------------------------------------

## The camp as kept (§FK): what each keeper is doing is dropped (they start
## again from their seats), everything else stays.
func to_dict() -> Dictionary:
	var kp := {}
	for k in keepers:
		kp[k] = str(_home(k))
	var its: Array = []
	for it in items:
		var c: Dictionary = it.duplicate(true)
		c.held = ""
		its.append(c)
	var tl := {}
	for id in tools:
		tl[id] = {"uses": int(tools[id].uses), "broken": bool(tools[id].broken), "by": ""}
	return {"v": 1, "t": t, "days0": days0, "store": store.duplicate(), "sources": sources.duplicate(true), "tools": tl, "orders": orders.duplicate(true), "items": its, "upgrades": upgrades.duplicate(), "next": _next, "batches": batches.duplicate(true), "band": band_made.duplicate(), "part": _last_part, "day_no": day_no, "seed": rng.seed, "rng": rng.state}


func from_dict(d: Dictionary, p_day_min := 144.0) -> void:
	day_min = p_day_min
	_meta()
	t = float(d.get("t", 0.0))
	days0 = float(d.get("days0", 0.0))
	store = {}
	for g in meta:
		store[g] = float((d.get("store", {}) as Dictionary).get(g, 0.0))
	sources = (d.get("sources", {}) as Dictionary).duplicate(true)
	for id in _sources():
		if not sources.has(id):
			sources[id] = {"left": float((_sources()[id] as Dictionary).get("count", 0.0)), "trap": 0.0, "water_days": 0}
	tools = {}
	for id in _tools():
		var kt: Dictionary = (d.get("tools", {}) as Dictionary).get(id, {})
		tools[id] = {"uses": int(kt.get("uses", (_tools()[id] as Dictionary).get("uses", 0))), "broken": bool(kt.get("broken", false)), "by": ""}
	orders = (d.get("orders", []) as Array).duplicate(true)
	items = []
	for it in (d.get("items", []) as Array):
		var c: Dictionary = (it as Dictionary).duplicate(true)
		c.id = int(c.id)
		c.stage = int(c.stage)
		items.append(c)
	upgrades = (d.get("upgrades", {}) as Dictionary).duplicate()
	_next = int(d.get("next", 1))
	batches = (d.get("batches", []) as Array).duplicate(true)
	band_made = (d.get("band", {}) as Dictionary).duplicate()
	_last_part = str(d.get("part", ""))
	day_no = int(d.get("day_no", 0))
	rng.seed = int(d.get("seed", 1))
	if d.has("rng"):
		rng.state = int(d.rng)
	keepers = {}
	for k in keeper_keys():
		keepers[k] = _keeper(k)


# --- For the checks and the view -------------------------------------------------------------

## Keeper `k`'s step now ({} none).
func step_of(k: String) -> Dictionary:
	var s: Array = (keepers.get(k, {}) as Dictionary).get("steps", [])
	return s[0] if not s.is_empty() else {}


## The rest share of daylight over the days run, per keeper (days with
## at least `min_light` minutes of daylight seen).
func rest_share(min_light := 30.0) -> Dictionary:
	var out := {}
	for k in keeper_keys():
		var r := 0.0
		var l := 0.0
		for dk in days:
			var e: Dictionary = (days[dk] as Dictionary).get(k, {})
			if float(e.get("light", 0.0)) >= min_light:
				r += float(e.rest)
				l += float(e.light)
		out[k] = r / l if l > 0.0 else 0.0
	return out

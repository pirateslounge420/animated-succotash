class_name CampSim
extends Node
## Camps are alive (design 30 Sept §BL–§BN, camps.json sim). Every camp
## banks two things you can see, a woodpile and a food store; its folk
## run a safe daytime loop (out within gather_reach_m, back, drop it in,
## feed the fire, eat); the fire is the link (FireStore §AX draws from
## the camp's wood); population is gated by food, births need both sexes
## and a surplus and a slow clock; the ladder fire -> food -> storage ->
## specialist -> exchange is camp state; a fire kept low for nights
## lets the dark walk in and the survivors walk to the nearest fire;
## starvation moves them; an empty camp goes to ruin and the forest.
## Every number is camps.json sim (first guesses, tune by play).
##
## Stop at exchange (design 5 Oct §EI.4, sim.trades.ceiling and never):
## nothing in this sim ever makes a market, money, a chief, a wall, a
## standing hunter who does not also gather, or metal. Two camps with
## different trades trade along the road, and that is the ceiling. The
## needs (§EI.1, _needs) and the trades (Trades) give the restraint rule
## an economy to be restrained with; neither adds a store, a stat or a
## rank.
##
## The sim is a store plus a timestamp: it ticks every tick_game_h of
## game time and on load resolves the ticks it missed (WorldSave), for
## every camp the player has come upon, so camps grow while unloaded.
## A camp's state (states[key]) is made the first time the camp is
## built (Camps, Encampment), timed from the world's start, and caught
## up at once: the camp has been living all along.

static var SIM: Dictionary = Tuning.section("camps", "sim")
static var instance: CampSim = null
## True while the lost days run (design 3 Oct §DE, LostDays): every camp's
## fire burns as if unloaded, the scene's frames not running meanwhile.
static var away := false

var world: Node
var chunks: ChunkManager
var states := {}
var _time_acc := 0.0


func setup(p_world: Node, p_chunks: ChunkManager) -> void:
	world = p_world
	chunks = p_chunks
	instance = self
	var saved = WorldSave.data.get("camps", null)
	if saved is Dictionary:
		for k in saved:
			if saved[k] is Dictionary:
				states[k] = saved[k]
	WorldSave.data["camps"] = states
	load_scars()


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func tick_days() -> float:
	return float(SIM.get("tick_game_h", 1.0)) / 24.0


## The state of camp `key`, made now if it is new: the people, the folk
## (3-5, men and women), the first store, timed from the world's start
## and caught up (the camp has been living while you were not there).
func ensure(key: String, d: Vector3, people_id: String, biome_key: String, seed_value: int, start_folk := -1) -> Dictionary:
	if states.has(key):
		var st: Dictionary = states[key]
		catch_up(st)
		return st
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "camp_sim"])
	var pop: Dictionary = SIM.get("population", {})
	var sb = pop.get("start", [3, 5])
	var n := start_folk if start_folk > 0 else rng.randi_range(int(sb[0]), int(sb[1]))
	var folk: Array = []
	for i in n:
		# Men and women: the first two one of each, then the roll.
		var sex := "m" if i == 0 else ("f" if i == 1 else ("m" if rng.randf() < 0.5 else "f"))
		folk.append({"sex": sex, "stage": "adult", "born": 0.0, "role": "", "seed": rng.randi()})
	var st := _new_state(key, d, people_id, biome_key, seed_value, folk, n)
	states[key] = st
	_seed_fire(st)
	catch_up(st)
	return st


func _new_state(key: String, d: Vector3, people_id: String, biome_key: String, seed_value: int, folk: Array, n: int) -> Dictionary:
	var store: Dictionary = SIM.get("store", {})
	var st := {
		"key": key, "dir": [d.x, d.y, d.z], "people": people_id, "biome": biome_key, "seed": seed_value,
		"folk": folk, "wood": float(store.get("wood_units_per_night", 4.0)) * 2.0, "food": float(n) * 2.0,
		"woods": 1.0, "rung": 0, "last_tick": minf(float(PlantGrowth.EPOCH_DAYS), world.days), "born_day": minf(float(PlantGrowth.EPOCH_DAYS), world.days),
		"fire_low_nights": 0, "low_tonight": false, "food_short_days": 0.0, "state": "living", "blood": false,
		"seeds": 0, "plot": false, "weir": false, "surplus_days": 0.0, "last_birth": minf(float(PlantGrowth.EPOCH_DAYS), world.days),
		"met_headman": false, "dry_days": 0.0, "scar": false, "inherits": [], "fire_key": FireStore.key_of(d),
		"reach_m": float((SIM.get("loop", {}) as Dictionary).get("gather_reach_m", 300.0)), "log": [],
	}
	return st


## The fire's own store (FireStore) for a camp not yet built: made from
## the camp's wood so it burns while unloaded.
func _seed_fire(st: Dictionary) -> void:
	var fk := str(st.fire_key)
	if FireStore.stores.has(fk):
		return
	var kind := _fuel_kind(st)
	var units: Array = []
	for i in int(FireStore.F.get("starts_with_units", 8)):
		units.append([kind, FireStore.burn_min(kind)])
	FireStore.stores[fk] = {"units": units, "embers_min": 0.0, "state": "flames", "tended": true}


func _fuel_kind(st: Dictionary) -> String:
	var people := Peoples.get_people(str(st.people))
	var kinds := Peoples.fuel_kinds(people)
	return str(kinds[0]) if not kinds.is_empty() else "branch"


func state_of(key: String) -> Dictionary:
	return states.get(key, {})


## What a camp squatting in a ruin inherits (§BQ, ruin.signatures[]
## .inherits): the weir works from the first season, the clay pit is
## dug (the maker sooner), the midden's ground feeds. Once.
func inherit(st: Dictionary, people: Dictionary) -> void:
	if bool(st.get("inherited", false)) or not str(st.key).begins_with("ruin:"):
		return
	st.inherited = true
	var got: Array = []
	for sig in (people.get("ruin", {}) as Dictionary).get("signatures", []):
		var inh := str(sig.get("inherits", "")).to_lower()
		got.append(str(sig.get("id", "")))
		if inh.find("weir") >= 0 or inh.find("eel") >= 0 or inh.find("fish") >= 0:
			st.weir = true
		if inh.find("clay") >= 0 or inh.find("kiln") >= 0 or inh.find("pit") >= 0:
			st.surplus_days = float(st.surplus_days) + 5.0
		if inh.find("earth") >= 0 or inh.find("grows") >= 0 or inh.find("midden") >= 0:
			st.food = float(st.food) + 3.0
		if inh.find("first season") >= 0 or inh.find("day one") >= 0:
			st.rung = maxi(int(st.rung), 1)
	st.inherits = got
	WorldSave.mark_dirty()


func _process(delta: float) -> void:
	if world == null:
		return
	_time_acc += delta
	if _time_acc < 0.5:
		return
	_time_acc = 0.0
	for k in states:
		catch_up(states[k])
	Overrun.check_nest_dens(self, world.days)
	settlers(world.days)


## Resolve every tick the camp missed up to now.
func catch_up(st: Dictionary) -> void:
	var td := tick_days()
	if float(st.last_tick) > world.days:
		st.last_tick = world.days
	var guard := 0
	while float(st.last_tick) + td <= world.days and guard < 20000:
		st.last_tick = float(st.last_tick) + td
		_tick(st, float(st.last_tick))
		guard += 1
	if guard > 0:
		WorldSave.mark_dirty()


func _dir(st: Dictionary) -> Vector3:
	var a: Array = st.dir
	return Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()


func clock_h(st: Dictionary, days: float) -> float:
	return fposmod(Astro.time_of_day(days) + CubeSphere.longitude(_dir(st)) / TAU, 1.0) * 24.0


## The three life stages (§BM, Mike: sim.births.stages, in order child ->
## teen -> adult): a child does not gather, a teen gathers at half rate
## and cannot be a specialist, an adult does both. Stage lengths are in
## game days; the last stage has none.
static func stages() -> Dictionary:
	return (SIM.get("births", {}) as Dictionary).get("stages", {"adult": {"gathers": true, "gather_rate": 1.0, "can_be_specialist": true, "rig_scale": 1.0}})


static func stage_of(f: Dictionary) -> String:
	if f.has("stage"):
		return str(f.stage)
	return "child" if bool(f.get("child", false)) else "adult"


static func stage_row(f: Dictionary) -> Dictionary:
	return stages().get(stage_of(f), {})


## The stage a folk of this age (game days) is in: the rows in order,
## each lasting its game_days; the last lasts forever.
static func stage_for_age(age_days: float) -> String:
	var rows := stages()
	var left := age_days
	var last := "adult"
	for k in rows:
		last = str(k)
		var row: Dictionary = rows[k]
		if not row.has("game_days"):
			return last
		if left < float(row.game_days):
			return last
		left -= float(row.game_days)
	return last


static func is_adult(f: Dictionary) -> bool:
	return not stage_row(f).has("game_days")


static func gather_rate_of(f: Dictionary) -> float:
	var row := stage_row(f)
	if not bool(row.get("gathers", true)):
		return 0.0
	var rate := float(row.get("gather_rate", 1.0))
	if str(f.get("role", "")) != "":
		# A role, not a job: the specialist still gathers, at a share.
		rate *= float((SIM.get("population", {}) as Dictionary).get("specialist_gather_rate", 0.5))
	return rate


func adults(st: Dictionary) -> int:
	var n := 0
	for f in st.folk:
		if is_adult(f):
			n += 1
	return n


## Gatherer-strength: adults count one, teens their gather_rate, children
## nothing, specialists a share (population.specialist_gather_rate).
func gatherers(st: Dictionary) -> float:
	var n := 0.0
	for f in st.folk:
		n += gather_rate_of(f)
	return n


## What the fire burns in a game day, in woodpile units (a woodpile unit
## is one branch's worth of burning; FireStore's tended rate applies).
static func burn_units_per_day() -> float:
	var ff: Dictionary = FireStore.F
	return DayCycle.day_length_min() * float(ff.get("burn_scale", 1.0)) * float(ff.get("tended_burn_scale", 0.35)) / maxf(FireStore.burn_min("branch"), 0.5)


## What the folk eat in a game day (children a share of an adult).
func eat_per_day(st: Dictionary) -> float:
	var store: Dictionary = SIM.get("store", {})
	var pop: Dictionary = SIM.get("population", {})
	var eat := 0.0
	for f in st.folk:
		eat += float(store.get("food_units_per_folk_day", 1.0)) * (float(pop.get("child_eats", 0.5)) if stage_of(f) == "child" else 1.0)
	return eat


func folk_count(st: Dictionary) -> int:
	return (st.folk as Array).size()


## One tick of tick_game_h at game day `days` (its end).
func _tick(st: Dictionary, days: float) -> void:
	if str(st.state) != "living":
		_tick_empty(st, days)
		return
	var h := clock_h(st, days)
	var th := float(SIM.get("tick_game_h", 1.0))
	var loop: Dictionary = SIM.get("loop", {})
	var store: Dictionary = SIM.get("store", {})
	var pop: Dictionary = SIM.get("population", {})
	var restraint: Dictionary = SIM.get("restraint", {})
	var gh = loop.get("gather_hours", [7, 17])
	var night := h < 6.0 or h >= 19.0
	# --- The loop: gather by day ---
	if h >= float(gh[0]) and h < float(gh[1]):
		var hours := gatherers(st) * th # gatherer-hours this tick
		var gh_len := maxf(float(gh[1]) - float(gh[0]), 1.0)
		var wood_target := float(store.get("wood_days_target", 5.0)) * float(store.get("wood_units_per_night", 4.0))
		var food_target := float(store.get("food_days_target", 7.0)) * float(store.get("food_units_per_folk_day", 1.0)) * folk_count(st)
		var wood_rate := float(loop.get("wood_per_gatherer_h", 0.5))
		var food_rate := float(loop.get("food_per_gatherer_h", 0.3))
		if bool(st.get("weir", false)) or bool(st.get("plot", false)):
			food_rate *= float(pop.get("fundamental_food_scale", 1.6))
		# Hours each store needs this tick: what the fire burns and the
		# folk eat per gather hour, and a quarter more to refill, when
		# the store is under its target; the spare hours go to food (a
		# surplus is the ladder), then wood.
		var wood_h := 0.0
		var food_h := 0.0
		if float(st.wood) < wood_target:
			wood_h = burn_units_per_day() / gh_len * th / wood_rate * 1.25
		if float(st.food) < food_target:
			food_h = eat_per_day(st) / gh_len * th / food_rate * 1.25
		var need := wood_h + food_h
		if need > hours and need > 0.0:
			wood_h *= hours / need
			food_h *= hours / need
		elif float(st.food) < food_target * 1.2:
			food_h += hours - need
		elif float(st.wood) < wood_target:
			wood_h += hours - need
		if wood_h > 0.0:
			# What the woods within reach still give (restraint): the take
			# thins them; they grow back a share a day.
			var cap := float(restraint.get("woods_units_in_reach", 150.0))
			var take := wood_h * wood_rate * clampf(float(st.woods), 0.05, 1.0)
			take = minf(take, maxf(wood_target - float(st.wood), 0.0))
			st.wood = float(st.wood) + take
			st.woods = clampf(float(st.woods) - take / cap, 0.0, 1.0)
		if food_h > 0.0:
			st.food = minf(float(st.food) + food_h * food_rate, food_target * 1.2)
	# The woods grow back a share of what stands within reach a day,
	# slower once stripped; a stripped wood means a longer walk.
	var regrow := float(restraint.get("regrow_per_game_day", 0.06)) * th / 24.0 * (0.3 + 0.7 * float(st.woods))
	st.woods = clampf(float(st.woods) + regrow, 0.0, 1.0)
	if bool(loop.get("reach_grows_when_stripped", true)):
		var base := float(loop.get("gather_reach_m", 300.0))
		st.reach_m = base + (1.0 - float(st.woods)) * float(restraint.get("reach_grow_per_stripped_day_m", 25.0)) * 4.0
	# --- Eat ---
	var eat := eat_per_day(st) * th / 24.0
	st.food = maxf(float(st.food) - eat, 0.0)
	if float(st.food) <= 0.0:
		st.food_short_days = float(st.food_short_days) + th / 24.0
	else:
		st.food_short_days = maxf(float(st.food_short_days) - th / 24.0, 0.0)
	# The camp book (§ED.3): the woodpile running low (under a night's
	# burning) and the store emptying or filling again, each once as it
	# turns.
	var night_wood := float(store.get("wood_units_per_night", 4.0))
	if float(st.wood) < night_wood and not bool(st.get("wood_low", false)):
		st["wood_low"] = true
		_note(st, "The woodpile is low.", days, "woodpile_low")
	elif float(st.wood) > night_wood * 2.0:
		st["wood_low"] = false
	if float(st.food) <= 0.0 and not bool(st.get("store_empty", false)):
		st["store_empty"] = true
		_note(st, "The store is empty.", days, "store_change")
	elif float(st.food) > float(store.get("food_units_per_folk_day", 1.0)) * folk_count(st) * 2.0 and bool(st.get("store_empty", false)):
		st["store_empty"] = false
		_note(st, "There is food in the store again.", days, "store_change")
	# --- The fire: burn while unloaded, feed from the woodpile ---
	var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
	if fst.is_empty():
		_seed_fire(st)
		fst = FireStore.stores.get(str(st.fire_key), {})
	if not _fire_loaded(st):
		FireStore.burn(fst, th * DayCycle.day_length_min() / 24.0)
	var below := float(store.get("feed_fire_below_units", 3.0))
	if FireStore.units_now(fst) < below and float(st.wood) > 0.0 and str(fst.state) != "out":
		var kind := _fuel_kind(st)
		var feed := minf(float(store.get("feed_units_per_tick", 2.0)), float(st.wood))
		# A woodpile unit is a branch's worth of burning, whatever the
		# people burn: reeds go on by the armful, a log is one.
		var minutes := feed * FireStore.burn_min("branch")
		var per := maxf(FireStore.burn_min(kind), 0.5)
		while minutes > 0.0:
			(fst.units as Array).append([kind, minf(per, minutes)])
			minutes -= per
		st.wood = maxf(float(st.wood) - feed, 0.0)
		st["wood_fed"] = float(st.get("wood_fed", 0.0)) + feed
		if str(fst.state) == "embers":
			fst.state = "low"
		if str(fst.state) in ["flames", "low"]:
			fst.state = "low" if FireStore.share(fst) < float(FireStore.F.get("low_share", 0.25)) else "flames"
	# A camp fire's embers linger sim.embers_game_h (longer than the
	# player's own), so a camp can be saved with an armful of fuel.
	if str(fst.state) == "embers" and float(fst.embers_min) > 0.0 and not bool(fst.get("camp_embers", false)):
		fst.embers_min = float(SIM.get("embers_game_h", 2.0)) * DayCycle.day_length_min() / 24.0
		fst.camp_embers = true
	if str(fst.state) != "embers":
		fst.erase("camp_embers")
	# Low tonight: any night hour with the fire low, embers or out.
	if night and (str(fst.state) != "flames"):
		st.low_tonight = true
	_wildfire_tick(st, days, th)
	if h >= 6.0 and h < 6.0 + th:
		# Dawn: the night is counted.
		if bool(st.low_tonight):
			st.fire_low_nights = int(st.fire_low_nights) + 1
		else:
			st.fire_low_nights = 0
		st.low_tonight = false
		_dawn(st, days)
		if str(st.state) == "living":
			_relight_from_ember(st, days, th)
	_ladder(st, days)
	_needs(st, days, h, th)
	if world != null:
		Trades.update(st, world.get("planet"), chunks.rivers if chunks != null else null)


## The fundamentals made visible (design 5 Oct §EI.1, sim.needs): water
## trips (trips_per_day for each ten folk, at even hours of the gather
## day; st.water: today's count, yesterday's, the total; the pot lands by
## the hearth after the first, store.pieces.water_pot_by_hearth) and a
## shelter mend every mend_job_days in the gather hours (st.patches, one
## patch each). No store number changes: water is never short.
func _needs(st: Dictionary, days: float, h: float, th: float) -> void:
	var nd: Dictionary = SIM.get("needs", {})
	var gh: Array = (SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var g0 := float(gh[0])
	var span := float(gh[1]) - g0
	var day := int(floor(days + CubeSphere.longitude(_dir(st)) / TAU))
	var w: Dictionary = st.get("water", {})
	if int(w.get("day", -999)) != day:
		var prev := int(w.get("n", 0)) if int(w.get("day", -999)) == day - 1 else 0
		w = {"day": day, "n": 0, "prev": prev, "total": int(w.get("total", 0))}
	var n := water_trips_per_day(st)
	for k in n:
		var at := g0 + (k + 0.5) * span / n
		if h >= at and h < at + th and int(w.n) <= k:
			w.n = int(w.n) + 1
			w.total = int(w.total) + 1
	st["water"] = w
	var md := float((nd.get("shelter", {}) as Dictionary).get("mend_job_days", 10))
	if not st.has("mend_last"):
		st["mend_last"] = days
	if days - float(st.mend_last) >= md and h >= g0 and h < g0 + span:
		st["patches"] = int(st.get("patches", 0)) + 1
		st["mend_last"] = days
		var log: Array = st.get("mend_days", [])
		log.append(days)
		while log.size() > 8:
			log.pop_front()
		st["mend_days"] = log


## A camp's water trips a day: needs.water.trips_per_day, again for every
## ten folk past the first ten.
func water_trips_per_day(st: Dictionary) -> int:
	var per := int(((SIM.get("needs", {}) as Dictionary).get("water", {}) as Dictionary).get("trips_per_day", 2))
	return per * maxi(1, int(ceil(folk_count(st) / 10.0)))


## A dead fire the folk still tend relights at dawn from the woodpile:
## they keep an ember (no fire is made, §BL); a save from before the loop,
## every fire out by day 14, comes back this way at its first caught-up
## dawn. After the night is counted, so a camp the dark took in the night
## does not light its fire first (the relit-fire return would bring folk
## back to it).
func _relight_from_ember(st: Dictionary, days: float, _th: float) -> void:
	var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
	var store: Dictionary = SIM.get("store", {})
	if fst.is_empty() or str(fst.state) != "out" or float(st.wood) <= 0.0 or not bool(fst.get("tended", true)):
		return
	var kind := _fuel_kind(st)
	var feed := minf(float(store.get("feed_units_per_tick", 2.0)), float(st.wood))
	var minutes := feed * FireStore.burn_min("branch")
	var per := maxf(FireStore.burn_min(kind), 0.5)
	while minutes > 0.0:
		(fst.units as Array).append([kind, minf(per, minutes)])
		minutes -= per
	st.wood = maxf(float(st.wood) - feed, 0.0)
	st["wood_fed"] = float(st.get("wood_fed", 0.0)) + feed
	fst.embers_min = 0.0
	fst.state = "low" if FireStore.share(fst) < float(FireStore.F.get("low_share", 0.25)) else "flames"
	_note(st, "They have lit the fire again from an ember.", days, "hearth_relit")


## Once a day at dawn: the surplus counted, the stages advancing, a
## birth now and then (§BM), then what the night did (§BL collapse).
func _dawn(st: Dictionary, days: float) -> void:
	var store: Dictionary = SIM.get("store", {})
	var births: Dictionary = SIM.get("births", {})
	var pop: Dictionary = SIM.get("population", {})
	var target := float(store.get("food_days_target", 7.0)) * float(store.get("food_units_per_folk_day", 1.0)) * folk_count(st)
	if float(st.food) >= target * 0.8:
		st.surplus_days = float(st.surplus_days) + 1.0
	else:
		st.surplus_days = 0.0
	# The stages: a child becomes a teen, a teen an adult, by age.
	for f in st.folk:
		if not is_adult(f):
			var was := stage_of(f)
			var now := stage_for_age(days - float(f.get("born", days)))
			if now != was:
				f.stage = now
				_note(st, "One of the children is grown enough to gather." if now == "teen" else "One of them has come of age.", days)
	# A birth: a man and a woman, a surplus, a slow clock, room under the
	# ceiling (forage_cap, a fundamental or a crop adds, village_cap).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.seed), int(days), "birth"])
	var men := 0
	var women := 0
	for f in st.folk:
		if not is_adult(f):
			continue
		if str(f.get("sex", "m")) == "m":
			men += 1
		else:
			women += 1
	var both := (men > 0 and women > 0) or not bool(births.get("needs_both_sexes", true))
	var every = births.get("every_game_days", [20, 40])
	var due := days - float(st.last_birth) >= rng.randf_range(float(every[0]), float(every[1]))
	if both and due and float(st.surplus_days) >= float(births.get("needs_surplus_days", 10)) and folk_count(st) < cap(st):
		var first := "adult"
		for k in stages():
			first = str(k)
			break
		(st.folk as Array).append({"sex": "m" if rng.randf() < 0.5 else "f", "stage": first, "born": days, "role": "", "seed": rng.randi()})
		st.last_birth = days
		_note(st, "A child was born at the fire.", days, "birth")
	_night_after(st, days)


## The camp's ceiling: forage_cap, a fundamental (the weir) or a crop
## (the plot) adding, never past village_cap (§BM).
func cap(st: Dictionary) -> int:
	var pop: Dictionary = SIM.get("population", {})
	var c := int(pop.get("forage_cap", 6))
	if bool(st.get("weir", false)):
		c += int(pop.get("fundamental_adds", 6))
	if bool(st.get("plot", false)):
		c += int(pop.get("crop_adds", 4))
	return mini(c, int(pop.get("village_cap", 50)))


## The ladder as camp state (§BM): fire -> food -> storage -> specialist
## -> exchange; only ever up (a camp goes backwards from the dark or
## the woods, not from the ladder). At storage the headman and the
## plantkeeper appear; the maker where the people's site allows one and
## there is surplus; exchange when a neighbour has a different maker.
func _ladder(st: Dictionary, days: float) -> void:
	var gates: Dictionary = SIM.get("ladder_gates", {})
	var store: Dictionary = SIM.get("store", {})
	var people := Peoples.get_people(str(st.people))
	var rung := int(st.rung)
	var per_day := float(store.get("food_units_per_folk_day", 1.0)) * folk_count(st)
	if rung < 1 and float(st.food) >= per_day * float(gates.get("food_days_for_food", 1.0)):
		rung = 1
	if rung >= 1:
		_fundamental(st, people)
	if rung < 2 and rung >= 1 and float(st.surplus_days) >= float(gates.get("surplus_days_for_storage", 10)):
		rung = 2
		_give_role(st, "headman", "m")
		_give_role(st, "plantkeeper", "f")
		_note(st, "The camp keeps a store now.", days, "store_change")
	if rung == 2:
		# The specialist: the first who does not gather (the maker), where
		# the site allows and there is surplus and enough hands.
		var maker: Dictionary = (people.get("specialists", {}) as Dictionary).get("maker", {})
		if not maker.is_empty() and adults(st) >= int(gates.get("folk_for_specialist", 8)) and float(st.surplus_days) >= float(gates.get("surplus_days_for_storage", 10)):
			rung = 3
			_give_role(st, "maker", "")
			_note(st, "A %s works at the camp now." % str(maker.get("craft", "maker")), days)
	if rung == 3:
		var km := float(gates.get("neighbour_km_for_exchange", 15.0))
		var mine := str(((people.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
		for k in states:
			var other: Dictionary = states[k]
			if other == st or int(other.get("rung", 0)) < 3 or str(other.get("state", "")) != "living":
				continue
			var op := Peoples.get_people(str(other.people))
			var theirs := str(((op.get("specialists", {}) as Dictionary).get("maker", {}) as Dictionary).get("craft", ""))
			if theirs != mine and CubeSphere.surface_distance_m(_dir(st), _dir(other)) <= km * 1000.0:
				rung = 4
				_note(st, "The road carries their %s to a neighbour." % mine, days, "store_change")
				break
	if rung != int(st.rung):
		st.rung = rung
		WorldSave.mark_dirty()


## The people's fundamental (§BM), crop and fish_run only: the weir at
## the food rung (at once where a ruin's weir line is inherited); the
## plot once seeds are in the store and one of them takes in this soil
## and climate (the site decides what sticks: wrong seeds just sit).
func _fundamental(st: Dictionary, people: Dictionary) -> void:
	var fund := str(people.get("fundamental", "forage"))
	if fund == "fish_run" and not bool(st.get("weir", false)):
		st.weir = true
	if fund == "crop" and not bool(st.get("plot", false)):
		var seeds: Array = st.get("seed_species", [])
		for idx in seeds:
			if _seed_takes(st, int(idx)):
				st.plot = true
				st.plot_species = int(idx)
				break


## Does species `idx` take at the camp's site: the wild placer's own
## suitability (climate bands, soil), no water needed.
func _seed_takes(st: Dictionary, idx: int) -> bool:
	var all := SpeciesDB.all()
	if idx < 0 or idx >= all.size():
		return false
	var sp: PlantSpecies = all[idx]
	var map: PlanetData = world.planet
	var d := _dir(st)
	var cell := map.cell_at(d)
	var e := map.terrain.elevation(d, false)
	var t := map.sample(map.temp_c, d) + (map.sample(map.elevation, d) - e) * PlanetConst.LAPSE_RATE_C_PER_M
	return sp.suitability(t, map.sample(map.moisture, d), e, int(map.rock[cell])) > 0.0


func _give_role(st: Dictionary, role: String, prefer_sex: String) -> void:
	for f in st.folk:
		if str(f.get("role", "")) == role:
			return
	var pick = null
	for f in st.folk:
		if not bool(stage_row(f).get("can_be_specialist", true)) or str(f.get("role", "")) != "":
			continue
		if pick == null or (prefer_sex != "" and str(f.get("sex", "")) == prefer_sex and str(pick.get("sex", "")) != prefer_sex):
			pick = f
	if pick != null:
		pick.role = role


## A line for the log, only when the camp is within earshot (the log is
## what you saw, not what the world did).
## `event`: the camp book's kind of line (§ED.3, camp_books.json
## lines.events; CampBook.write), written whether you are near or not.
func _note(st: Dictionary, text: String, days: float, event := "") -> void:
	CampBook.write(st, event, text, days)
	if world == null or Torch.instance == null or not is_instance_valid(Torch.instance):
		return
	var pp: Vector3 = Torch.instance.player.global_position if Torch.instance.player else Vector3.ZERO
	var at: Vector3 = world.to_scene(_dir(st), PlanetConst.RADIUS_M + world.surface_elevation(_dir(st)))
	if at.distance_to(pp) < 60.0 and absf(days - world.days) < 0.5:
		GameLog.add(text, "camp")


## What the night did (§BL, §BA): a fire kept low for
## fire_low_nights_to_taken nights lets the dark walk in: taken_per_night
## folk a night, the survivors walk to the nearest lit fire and join it
## (survivor_lost_chance_per_night on the way); food short for
## starve_moves_after_days moves them, no blood. Camps never harm each
## other.
func _night_after(st: Dictionary, days: float) -> void:
	var col: Dictionary = SIM.get("collapse", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.seed), int(days), "night"])
	if int(st.fire_low_nights) >= int(col.get("fire_low_nights_to_taken", 2)):
		var tb = col.get("taken_per_night", [1, 3])
		var taken := mini(rng.randi_range(int(tb[0]), int(tb[1])), folk_count(st))
		for i in taken:
			(st.folk as Array).pop_back()
		st.blood = true
		_note(st, "The dark took %d of them in the night." % taken, days, "gatherer_lost")
		if folk_count(st) > 0 and bool(col.get("survivors_walk_to_nearest_fire", true)):
			_walk_away(st, days, true, rng)
		elif folk_count(st) == 0:
			_abandon(st, days, "taken")
		return
	if float(st.food_short_days) >= float(col.get("starve_moves_after_days", 6)):
		_note(st, "They have gone, hungry, to a neighbour's fire.", days, "folk_left_for_fire")
		_walk_away(st, days, false, rng)


## The folk leave for the nearest living camp with a lit fire: some are
## lost on the way (the dark), the rest join it with what they carry.
func _walk_away(st: Dictionary, days: float, fled: bool, rng: RandomNumberGenerator) -> void:
	var col: Dictionary = SIM.get("collapse", {})
	var dest := _nearest_lit(st)
	var folk: Array = st.folk
	if not dest.is_empty():
		var km := CubeSphere.surface_distance_m(_dir(st), _dir(dest)) / 1000.0
		var nights := maxi(1, int(ceil(km / 20.0)))
		var arrived: Array = []
		for f in folk:
			var lost := false
			for n in nights:
				if rng.randf() < float(col.get("survivor_lost_chance_per_night", 0.35)) * (1.0 if fled else 0.4):
					lost = true
					break
			if not lost:
				f.role = ""
				arrived.append(f)
		(dest.folk as Array).append_array(arrived)
		# Where they went, for coming back (§CN part 4).
		st.went_to = str(dest.get("key", ""))
		st.survivors = arrived.size()
		# What they carry: a share of the store goes with them.
		dest.wood = float(dest.wood) + float(st.wood) * 0.3
		dest.food = float(dest.food) + float(st.food) * 0.5
		var dcap := cap(dest)
		while (dest.folk as Array).size() > int((SIM.get("population", {}) as Dictionary).get("village_cap", 50)):
			(dest.folk as Array).pop_back()
		dest.folk_joined = days
		if dcap >= 0:
			pass
	st.folk = []
	_abandon(st, days, "fled" if fled else "left")


func _nearest_lit(st: Dictionary) -> Dictionary:
	var best := {}
	var best_m := INF
	for k in states:
		var o: Dictionary = states[k]
		if o == st or str(o.get("state", "")) != "living":
			continue
		var fst: Dictionary = FireStore.stores.get(str(o.fire_key), {})
		if fst.is_empty() or str(fst.get("state", "")) in ["out"]:
			continue
		var dm := CubeSphere.surface_distance_m(_dir(st), _dir(o))
		if dm < best_m:
			best_m = dm
			best = o
	return best


## An empty camp (§BL abandon): a ruin after ruin_after_game_days, the
## forest taking it back over forest_takes_game_days; the needful things
## left lie by the fire (Camps lays them). `why`: taken, fled, left,
## burnt.
func _abandon(st: Dictionary, days: float, why: String) -> void:
	st.state = "abandoned"
	st.abandoned_day = days
	st.why = why
	st.folk = []
	WorldSave.mark_dirty()


## Folk come back to a cleared ruin (design 2 Oct §CN, sim.overrun
## settlers): once the den is cleared (Overrun) and the ruin's surface
## hearth has burnt for arrive_after_game_h, its survivors come back if it
## fell within survivors_if_fell_within_game_days (from the camp they fled
## to), else a few folk walk over from the nearest living camp within
## else_from_nearest_camp.within_km at camp_at_share_of_cap of its cap or
## more. Then it is a living camp again (the sim, §BL), its ruin restored
## (§BQ) and a hearth you can take (§AY); if it goes dark again it is
## overrun again (relapse).
func settlers(days: float) -> void:
	var sv := Overrun.saved()
	var map: PlanetData = world.get("planet") if world != null else null
	var sets: Dictionary = Overrun.CAMPS_SIM.get("settlers", {})
	for id in sv.keys():
		var e: Dictionary = sv[id]
		if str(e.get("state", "")) != "cleared":
			continue
		var site := Overrun.site_of(map, str(id), e)
		var key := str(e.get("key", ""))
		if key == "" and not site.is_empty():
			key = Overrun.camp_key(map, site)
			e["key"] = key
		if key == "":
			continue
		# The surface hearth burning: the camp's own fire, or the ruin's
		# old hearth.
		var lit := false
		if states.has(key):
			var fst: Dictionary = FireStore.stores.get(str(states[key].fire_key), {})
			lit = str(fst.get("state", "")) in ["flames", "low"]
		if not lit and not site.is_empty():
			if not e.has("fire_dir"):
				var fd := Camps.ruin_fire_dir(map, site)
				e["fire_dir"] = [fd.x, fd.y, fd.z]
			var fa: Array = e.fire_dir
			lit = OldHearths.lit_at(world, Vector3(float(fa[0]), float(fa[1]), float(fa[2])).normalized(), 30.0)
		if not lit:
			e.erase("lit_since")
			continue
		if not e.has("lit_since"):
			e["lit_since"] = maxf(days, float(e.get("day", days)))
			continue
		if (days - float(e.lit_since)) * 24.0 < float(sets.get("arrive_after_game_h", 12.0)):
			continue
		var got := _settlers_for(e, days, str(id))
		if (got.folk as Array).is_empty():
			continue
		var fa2: Array = e.get("fire_dir", e.get("dir", []))
		var d := Vector3(float(fa2[0]), float(fa2[1]), float(fa2[2])).normalized() if fa2.size() == 3 else _dir_of_den(e)
		# The hearth that was lit for them is the camp's fire: its own
		# store, at its own place.
		var hk := OldHearths.key_near(d, 30.0)
		if hk != "":
			var ha: Array = (FireStore.stores.get(hk, (WorldSave.data.get("old_hearths", {}) as Dictionary).get(hk, {})) as Dictionary).get("dir", [])
			if ha.size() == 3:
				d = Vector3(float(ha[0]), float(ha[1]), float(ha[2])).normalized()
		settle(key, d, str(got.people), FireStore.biome_key(world, d), int(id) if str(id).is_valid_int() else hash(id), got.folk, days)
		e["state"] = "settled"
		e["settled_day"] = days
		e.erase("lit_since")
		WorldSave.mark_dirty()
		_note_near(d, str(Overrun.LOG.get("settled", "Folk have come to the fire.")), 250.0)


func _dir_of_den(e: Dictionary) -> Vector3:
	var a: Array = e.get("dir", [0, 1, 0])
	return Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()


## Who comes: {"folk": [...], "people"}. Survivors from where they fled,
## if it fell lately and they are still there; else 2-4 from the nearest
## camp near its ceiling; else nobody yet.
func _settlers_for(e: Dictionary, days: float, id: String) -> Dictionary:
	var sets: Dictionary = Overrun.CAMPS_SIM.get("settlers", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, int(days), "settlers"])
	var fell := float(e.get("fell", -1.0))
	if fell >= 0.0 and days - fell <= float(sets.get("survivors_if_fell_within_game_days", 30)):
		var src: Dictionary = states.get(str(e.get("went_to", "")), {})
		if not src.is_empty() and str(src.get("state", "")) == "living":
			var n := mini(int(e.get("survivors", 0)), (src.folk as Array).size() - 1)
			if n > 0:
				return {"folk": _take_folk(src, n), "people": str(e.get("people", src.people))}
	var near: Dictionary = sets.get("else_from_nearest_camp", {})
	var d := _dir_of_den(e)
	var best := {}
	var best_m := float(near.get("within_km", 40)) * 1000.0
	for k in states:
		var o: Dictionary = states[k]
		if str(o.get("state", "")) != "living":
			continue
		if float(folk_count(o)) < float(near.get("camp_at_share_of_cap", 0.6)) * float(cap(o)):
			continue
		var dm := CubeSphere.surface_distance_m(d, _dir(o))
		if dm < best_m:
			best_m = dm
			best = o
	if best.is_empty():
		return {"folk": [], "people": ""}
	var fb = near.get("folk", [2, 4])
	var n2 := mini(rng.randi_range(int(fb[0]), int(fb[1])), folk_count(best) - 1)
	return {"folk": _take_folk(best, n2) if n2 > 0 else [], "people": str(best.people)}


## `n` folk leave camp `src` (adults first).
func _take_folk(src: Dictionary, n: int) -> Array:
	var out: Array = []
	var folk: Array = src.folk
	for i in range(folk.size() - 1, -1, -1):
		if out.size() >= n:
			break
		if is_adult(folk[i]):
			out.append(folk[i])
			folk.remove_at(i)
	for f in out:
		f.role = ""
	return out


## A camp begun now by `folk` at `key` (§CN: folk come back): a living
## state timed from today (not caught up from the world's start), its fire
## the hearth that was lit for them, tended now.
func settle(key: String, d: Vector3, people_id: String, biome_key: String, seed_value: int, folk: Array, days: float) -> Dictionary:
	var st: Dictionary = states.get(key, {})
	if st.is_empty():
		st = _new_state(key, d, people_id, biome_key, seed_value, folk, folk.size())
		st.born_day = days
		st.last_birth = days
		states[key] = st
	st.folk = folk
	st.people = people_id
	st.state = "living"
	st.blood = false
	st.why = ""
	st.overrun = false
	st.fire_low_nights = 0
	st.food_short_days = 0.0
	st.food = maxf(float(st.get("food", 0.0)), float(folk.size()) * 2.0)
	st.wood = maxf(float(st.get("wood", 0.0)), 4.0)
	st.last_tick = days
	st.erase("abandoned_day")
	var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
	if not fst.is_empty():
		fst["tended"] = true
	WorldSave.mark_dirty()
	return st


func _note_near(d: Vector3, text: String, within_m: float) -> void:
	if world == null or Torch.instance == null or not is_instance_valid(Torch.instance) or Torch.instance.player == null:
		return
	var at: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + world.surface_elevation(d))
	if at.distance_to(Torch.instance.player.global_position) < within_m:
		GameLog.add(text, "camp")


## Survivors may come back to a relit fire: an abandoned camp whose fire
## someone lit again, within a few days, is lived in again by the
## nearest camp's spare folk (two of them).
func _tick_empty(st: Dictionary, days: float) -> void:
	var ab: Dictionary = SIM.get("abandon", {})
	var since := days - float(st.get("abandoned_day", days))
	if str(st.state) == "abandoned":
		var fst: Dictionary = FireStore.stores.get(str(st.fire_key), {})
		# (Never one the dark holds: §CN, sim.overrun sim_resettles false.)
		if not fst.is_empty() and str(fst.get("state", "")) in ["flames", "low"] and since < 10.0 and str(st.get("why", "")) != "burnt" and not bool(st.get("overrun", false)):
			var src := _nearest_lit(st)
			if not src.is_empty() and (src.folk as Array).size() >= 4:
				var back: Array = []
				for i in 2:
					back.append((src.folk as Array).pop_back())
				st.folk = back
				st.state = "living"
				st.blood = false
				st.food = 4.0
				st.fire_low_nights = 0
				_note(st, "Folk have come back to the relit fire.", days, "hearth_relit")
				return
		if since >= float(ab.get("ruin_after_game_days", 60)):
			st.state = "ruin"
			# A camp the dark took, with a den: the dark moves in (§CN).
			if world != null and Overrun.camp_fell(world.get("planet"), st, days):
				st.overrun = true
	elif str(st.state) == "ruin":
		if since >= float(ab.get("forest_takes_game_days", 365)):
			st.state = "gone"


# --- Wildfire (§BL, sim.wildfire; §BS: nothing here moves terrain) ----------------

static var scars: Array = [] # [{dir, along, across, heading, day, biome}]


static func load_scars() -> void:
	var saved = WorldSave.data.get("scars", null)
	scars = saved if saved is Array else []
	WorldSave.data["scars"] = scars


## Rare: a fire-prone biome, a dry spell of dry_spell_game_days from the
## weather sim, and an ignition (lightning in a storm, or a lit torch
## lying in dry grass: PlantedTorch). Then the burn.
func _wildfire_tick(st: Dictionary, days: float, th: float) -> void:
	var wf: Dictionary = SIM.get("wildfire", {})
	if not bool(wf.get("rare", true)) and false:
		return
	var prone: Array = wf.get("fire_prone_biomes", [])
	if not prone.has(str(st.biome)):
		return
	var d := _dir(st)
	var wx: Dictionary = world.weather.local_weather(d, world.surface_elevation(d)) if world.weather != null else {}
	if float(wx.get("rain_mm_h", 0.0)) < float(wf.get("dry_rain_mm_h", 0.2)) and not bool(wx.get("snow", false)):
		st.dry_days = float(st.dry_days) + th / 24.0
	else:
		st.dry_days = 0.0
	if float(st.dry_days) < float(wf.get("dry_spell_game_days", 20)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(st.seed), int(days * 24.0), "spark"])
	var ignited := ""
	if float(wx.get("storm", 0.0)) > 0.5 and rng.randf() < float(wf.get("lightning_chance_per_storm_h", 0.02)) * th:
		ignited = "lightning"
	for pt in PlantedTorch.all:
		if is_instance_valid(pt) and pt.lying and pt.lit() and CubeSphere.surface_distance_m(world.dir_of(pt.global_position), d) < float(st.reach_m):
			ignited = "a torch dropped in the grass"
	if ignited == "":
		return
	start_fire(d, wx, ignited, days)


## The burn: spread by wind through fuel (an ellipse downwind, longer
## for a stronger wind and a drier spell), a scar the placer reads
## (standing dead wood, fire-followers next season), the camps in its
## path walking away to rebuild a valley over.
func start_fire(d: Vector3, wx: Dictionary, why: String, days: float) -> void:
	var wf: Dictionary = SIM.get("wildfire", {})
	var sp = wf.get("spread_m", [150, 600])
	var wind: Vector3 = wx.get("wind", Vector3.ZERO) if wx.get("wind") is Vector3 else Vector3.ZERO
	var w := wind.length()
	var along := lerpf(float(sp[0]), float(sp[1]), clampf(w / 12.0, 0.0, 1.0))
	var across := lerpf(float(sp[0]) * 0.8, float(sp[1]) * 0.45, clampf(w / 12.0, 0.0, 1.0))
	var heading := 0.0
	if w > 0.1:
		var t := (wind - d * wind.dot(d)).normalized()
		heading = atan2(t.dot(CubeSphere.east(d)), t.dot(CubeSphere.north(d)))
	var centre := CreatureSpawner._offset(d, heading, along * 0.5)
	var scar := {"dir": [centre.x, centre.y, centre.z], "along": along, "across": across, "heading": heading, "day": days, "why": why}
	scars.append(scar)
	WorldSave.mark_dirty()
	GameLog.add("Fire on the land: %s." % why, "wildfire")
	# The camps in its path walk away and rebuild a valley over (an empty
	# ruin site within 6 km with no camp on it), carrying what they have.
	for k in states.keys():
		var st: Dictionary = states[k]
		if str(st.get("state", "")) != "living" or not in_scar(_dir(st), scar, days, 0.0):
			continue
		_walk_from_fire(st, days)


static func in_scar(p: Vector3, scar: Dictionary, days: float, pad_m: float) -> bool:
	var a: Array = scar.dir
	var c := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	var rel := (p - c * p.dot(c))
	var east := CubeSphere.east(c)
	var north := CubeSphere.north(c)
	var hdg := float(scar.heading)
	var fwd := north * cos(hdg) + east * sin(hdg)
	var side := fwd.cross(c).normalized()
	var x := (p - c).dot(fwd) * PlanetConst.RADIUS_M
	var y := (p - c).dot(side) * PlanetConst.RADIUS_M
	var ax := float(scar.along) * 0.5 + pad_m
	var ay := float(scar.across) * 0.5 + pad_m
	return (x * x) / (ax * ax) + (y * y) / (ay * ay) <= 1.0


## How burnt the ground at `p` is now (1 fresh, 0 healed), for the placer
## and the terrain colour.
static func scar_at(p: Vector3, days: float) -> float:
	var lasts := float((SIM.get("wildfire", {}) as Dictionary).get("scar_lasts_game_days", 365))
	var best := 0.0
	for scar in scars:
		if in_scar(p, scar, days, 0.0):
			best = maxf(best, 1.0 - clampf((days - float(scar.day)) / lasts, 0.0, 1.0))
	return best


func _walk_from_fire(st: Dictionary, days: float) -> void:
	var map: PlanetData = world.planet
	var best := Vector3.ZERO
	var best_m := INF
	for r in Ruins.near(map, _dir(st), 6000.0):
		var dm := CubeSphere.surface_distance_m(r.dir, _dir(st))
		if dm < 800.0:
			continue
		var taken := false
		for k in states:
			if CubeSphere.surface_distance_m(_dir(states[k]), r.dir) < 100.0 and str(states[k].get("state", "")) == "living":
				taken = true
		if not taken and dm < best_m:
			best_m = dm
			best = r.dir
	var folk: Array = st.folk
	var wood := float(st.wood) * 0.5
	var food := float(st.food) * 0.7
	_abandon(st, days, "burnt")
	st.scar = true
	if best == Vector3.ZERO:
		return
	var nk := "moved:%s" % str(FireStore.key_of(best))
	var ns := ensure(nk, best, str(st.people), FireStore.biome_key(world, best), hash([nk, int(days)]), maxi(folk.size(), 1))
	ns.folk = folk
	ns.wood = wood
	ns.food = food
	ns.moved_from = str(st.key)
	_note(st, "The camp walked away from the fire to rebuild a valley over.", days, "folk_left_for_fire")


## How far the forest has taken an empty camp back (0 fresh .. 1 gone),
## for the placer's clearing and the props.
func reclaim(st: Dictionary) -> float:
	if str(st.get("state", "living")) == "living":
		return 0.0
	var ab: Dictionary = SIM.get("abandon", {})
	return clampf((world.days - float(st.get("abandoned_day", world.days))) / float(ab.get("forest_takes_game_days", 365)), 0.0, 1.0)


## Is the camp's fire in the scene (FireStore.tick burns it there)?
func _fire_loaded(st: Dictionary) -> bool:
	if away:
		return false
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		if (f as Node).get_meta("fuel_key", "") == str(st.fire_key):
			return true
	return false


# --- The player's part (§BL: the player's gathering goes into the same store) ---

func add_wood(st: Dictionary, units: float) -> void:
	st.wood = float(st.wood) + units
	WorldSave.mark_dirty()


func add_food(st: Dictionary, units: float) -> void:
	st.food = float(st.food) + units
	WorldSave.mark_dirty()


## Seeds, tubers or cuttings brought by the player: the species is what
## matters (the site decides whether it takes, _fundamental).
func add_seeds(st: Dictionary, sp_idx: int) -> void:
	st.seeds = int(st.seeds) + 1
	if not st.has("seed_species"):
		st.seed_species = []
	if not (st.seed_species as Array).has(sp_idx):
		(st.seed_species as Array).append(sp_idx)
	WorldSave.mark_dirty()


## Food units a thing in the pack is worth on the store (0: not food).
static func food_units(it: Dictionary) -> float:
	match str(it.get("kind", "")):
		"fruit", "mushroom", "fish", "herb_bundle":
			return 1.0
	return 0.0


## Wood units a thing in the pack is worth (0: not fuel).
static func wood_units(it: Dictionary) -> float:
	if str(it.get("kind", "")) != "fuel":
		return 0.0
	return float(FireStore.burn_min(str(it.get("fuel", "branch")))) / maxf(FireStore.burn_min("branch"), 1.0)


## A plant sample that would plant: a seed head, a cutting, berries.
static func is_seed(it: Dictionary) -> bool:
	return str(it.get("kind", "")) == "plant_sample" and str(it.get("part", "")) in ["seed", "cutting", "berries"]

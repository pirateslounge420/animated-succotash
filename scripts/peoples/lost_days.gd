class_name LostDays
## The days lost when folk find you out cold (design 3 Oct §DE, camps.json
## wake_found.lost_days). A span, uniform between the two numbers in game
## days, and the world runs it for real, through the same paths it runs
## for time away: the clock (and with it the moon, the season and the
## plants' growth, PlantGrowth.now_days), the weather stepped as World
## steps it, every camp's ticks (CampSim.catch_up, its fire burning and
## fed from the woodpile as if unloaded), the old hearths (from their
## "seen"), every other fire's store burning down (the ones you laid),
## the lamps (gone past their "until"), the torches stood or lying, and
## the torch on your body. Flagged in §DE against §CW: this is the one
## thing that moves the clock past you.

static var W: Dictionary = Tuning.table("camps").get("wake_found", {})
## The last run (tools): {"span", "before", "after"} in game days.
static var last := {}


## A span of lost days from `rng`: uniform in wake_found.lost_days.
static func roll(rng: RandomNumberGenerator) -> float:
	var r: Array = W.get("lost_days", [1.0, 3.0])
	return rng.randf_range(float(r[0]), float(r[1]))


## Run the world on by `span` game days. `main` is the game (its world,
## camp_sim); `corpse` is your body (its torch burns out), or null.
static func run(main: Node, span: float, corpse: PlayerCorpse = null) -> void:
	var world: Node = main.world
	var before: float = world.days
	var real_s: float = span * DayCycle.day_length_min() * 60.0
	# The clock: the moon, the season and the plants follow it.
	world.days = before + span
	PlantGrowth.now_days = world.days
	world.run_weather(span * 24.0)
	# Every camp's ticks, every camp fire as if unloaded.
	var camp_keys := {}
	var cs: CampSim = main.camp_sim
	if cs != null:
		CampSim.away = true
		for k in cs.states:
			var st: Dictionary = cs.states[k]
			camp_keys[str(st.get("fire_key", ""))] = true
			cs.catch_up(st)
		Overrun.check_nest_dens(cs, world.days)
		cs.settlers(world.days)
		CampSim.away = false
	# The other fires: an old hearth from when it was last seen, any other
	# store (the fires you laid) burnt down by the real minutes, in steps.
	for key in FireStore.stores:
		if camp_keys.has(key):
			continue
		var fst: Dictionary = FireStore.stores[key]
		if fst.has("seen"):
			OldHearths.catch_up(world, fst)
			continue
		var minutes := real_s / 60.0
		var step := maxf(1.0, minutes / 200.0)
		while minutes > 0.0 and str(fst.get("state", "out")) != "out":
			FireStore.burn(fst, minf(step, minutes))
			minutes -= step
		for f in main.get_tree().get_nodes_in_group(Campfire.GROUP):
			if (f as Node).get_meta("fuel_key", "") == key:
				FireStore.apply(f)
	# Torches: stood or lying, and the one on your body.
	for p in PlantedTorch.all:
		if is_instance_valid(p) and p.lit():
			Torch.burn_step(p.item, real_s, {}, false)
			p._apply()
	if corpse != null and is_instance_valid(corpse):
		for it in _items(corpse):
			Torch.burn_step(it, real_s, {}, false)
	WorldSave.mark_dirty()
	last = {"span": span, "before": before, "after": float(world.days)}


## Every item on the body: what it carried and what it wore.
static func _items(corpse: PlayerCorpse) -> Array:
	var out: Array = []
	for it in corpse.carried:
		if it is Dictionary:
			out.append(it)
	for slot in corpse.worn:
		for it in corpse.worn[slot]:
			if it is Dictionary:
				out.append(it)
	return out


## The found line (wake_found.log): {days} as a word, log_one_day for one.
static func found_line(span: float) -> String:
	var n := int(round(span))
	if n <= 1:
		return str(W.get("log_one_day", "Folk found you out cold and carried you to their fire. A day has passed."))
	var words := ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var w: String = words[n] if n < words.size() else str(n)
	return str(W.get("log", "Folk found you out cold and carried you to their fire. {days} days have passed.")).replace("{days}", w)


## The cause line for a player found alive (wake_found.death_lines_found):
## "Struck down by a wolf", "Taken in the dark", "Fell"; the log's own
## death_lines where it has none.
static func cause_line(cause: String) -> String:
	var lines: Dictionary = W.get("death_lines_found", {})
	if cause.begins_with("creature:"):
		return str(lines.get("creature", "Struck down by a {creature}")).replace("{creature}", cause.substr(9).to_lower())
	if lines.has(cause):
		return str(lines[cause])
	var built: Dictionary = Tuning.section("hud", "log").get("death_lines", {})
	return str(built.get(cause, "Died" if cause == "" else cause.capitalize()))

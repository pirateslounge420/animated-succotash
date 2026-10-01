class_name FireStore
## Fire is fuel (design 30 Sept §AX, data/fuel.json). Every campfire has a
## store that burns down: flames -> low -> embers -> out. The store is a
## list of fuel units, each a kind (fuel.json kinds) and the real minutes
## it has left; the front unit burns first. Empty store: embers, which
## stay relightable for embers_min, then the fire is out. A dead fire
## comes back only from a lit torch (relight); embers catch from dry fuel
## put on them. Folk tending their fire (the camps, the opening camp, the
## mythic folk's fires) burn it at tended_burn_scale until §BJ builds real
## tending; the player's own fires would burn at full rate.
##
## The state lives here, keyed by the fire's place on the planet (a camp
## is rebuilt as you come and go; the fire remembers). Campfire.build
## registers each fire; main ticks them; Campfire.flicker draws the burn
## level (meta "burn") and lit_near() reads meta "lit" (flames or low:
## embers give no safety, no torch and no dread drain).

static var D := Tuning.table("fuel")
static var F: Dictionary = D.get("fire", {})
static var KINDS: Dictionary = D.get("kinds", {})
## key -> {"units": [[kind, min_left], ...], "embers_min", "state", "tended"}
static var stores := {}
## Fires to tell the log about, once each: key -> last state logged.
static var _logged := {}


## A stable key for the fire at surface direction `d` (about 3 m cells).
static func key_of(d: Vector3) -> String:
	return "%d,%d,%d" % [roundi(d.x * 2.0e5), roundi(d.y * 2.0e5), roundi(d.z * 2.0e5)]


static func biome_key(world, d: Vector3) -> String:
	var map: PlanetData = world.get("planet") if world != null else null
	if map == null or map.biome.is_empty():
		return ""
	var id: int = map.biome[map.cell_at(d)]
	return BiomeTemplates.KEYS[id] if id >= 0 and id < BiomeTemplates.KEYS.size() else ""


## What the biome at `d` offers: kind -> abundance 0-1 (empty: nothing
## burns there, a camp there dies).
static func offers(world, d: Vector3) -> Dictionary:
	var b = (D.get("biomes", {}) as Dictionary).get(biome_key(world, d), {})
	return b if b is Dictionary else {}


static func burn_min(kind: String) -> float:
	return float((KINDS.get(kind, {}) as Dictionary).get("burn_min", 5.0))


static func pretty(kind: String) -> String:
	return kind.replace("_", " ")


## The kind the folk here would have stacked: the offered kind that burns
## longest for its abundance; "branch" where nothing is offered.
static func best_kind(world, d: Vector3) -> String:
	var best := "branch"
	var best_v := 0.0
	var off := offers(world, d)
	for k in off:
		var v := burn_min(str(k)) * float(off[k])
		if v > best_v:
			best_v = v
			best = str(k)
	return best


## Campfire.build calls this: the fire's store, made on its first visit.
static func register(fire: Node3D, world, d: Vector3, tended := true) -> void:
	var key := key_of(d)
	fire.set_meta("fuel_key", key)
	if not stores.has(key):
		var st := {"units": [], "embers_min": 0.0, "state": "flames", "tended": tended}
		var kind := best_kind(world, d)
		for i in int(F.get("starts_with_units", 8)):
			(st.units as Array).append([kind, burn_min(kind)])
		stores[key] = st
	apply(fire)


static func store_of(fire: Node3D) -> Dictionary:
	if fire == null or not fire.has_meta("fuel_key"):
		return {}
	return stores.get(fire.get_meta("fuel_key"), {})


static func state_of(fire: Node3D) -> String:
	return str(store_of(fire).get("state", "flames"))


## Fuel in the store, in units (a half-burnt log is half a unit).
static func units_now(st: Dictionary) -> float:
	var n := 0.0
	for u in st.get("units", []):
		n += clampf(float(u[1]) / maxf(burn_min(str(u[0])), 0.1), 0.0, 1.0)
	return n


static func share(st: Dictionary) -> float:
	return units_now(st) / maxf(float(F.get("store_max_units", 12)), 1.0)


static func is_lit(fire: Node3D) -> bool:
	return state_of(fire) in ["flames", "low"]


## Burn every fire in the scene down over `delta` seconds. `near` is the
## player's position: only fires within earshot go in the log.
static func tick(tree: SceneTree, delta: float, near: Vector3) -> void:
	# The shinobi profile keeps its fires burning (design §AT: two games).
	if Tuning.profile() != "ambient":
		return
	for f in tree.get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire == null or not fire.is_inside_tree():
			continue
		var st := store_of(fire)
		if st.is_empty():
			continue
		var before := str(st.state)
		burn(st, delta / 60.0)
		if str(st.state) != before:
			apply(fire)
			if fire.global_position.distance_to(near) < 40.0:
				_log_state(fire.get_meta("fuel_key"), str(st.state))


## Burn a store down by `minutes` of real time (the scene tick each
## frame; CampSim for a camp's fire while it is unloaded).
static func burn(st: Dictionary, minutes: float) -> void:
	var units: Array = st.units
	var state := str(st.state)
	if not units.is_empty() and state != "out":
		var rate := float(F.get("burn_scale", 1.0)) * (float(F.get("tended_burn_scale", 0.35)) if bool(st.get("tended", true)) else 1.0)
		var left := minutes * rate
		while left > 0.0 and not units.is_empty():
			var take := minf(left, float(units[0][1]))
			units[0][1] = float(units[0][1]) - take
			left -= take
			if float(units[0][1]) <= 0.0:
				units.pop_front()
		if units.is_empty():
			st.state = "embers"
			st.embers_min = float(F.get("embers_min", 20.0))
		else:
			st.state = "low" if share(st) < float(F.get("low_share", 0.25)) else "flames"
	elif state == "embers":
		st.embers_min = float(st.embers_min) - minutes
		if float(st.embers_min) <= 0.0:
			st.state = "out"


static func _log_state(key: String, state: String) -> void:
	if _logged.get(key, "") == state:
		return
	_logged[key] = state
	match state:
		"embers":
			GameLog.add("The fire has burnt down to embers.", "fire_embers")
		"out":
			GameLog.add("The fire is out.", "fire_out")
		"flames", "low":
			GameLog.add("The fire is lit.", "fire_lit")


## Fuel `it` (an item of kind fuel) onto `fire`. Returns "ok", "full"
## (nothing taken), "hiss" (wet fuel that failed to catch on embers: the
## unit is lost) or "cold" (a dead fire took the fuel but stays dead:
## it needs a flame). `days` is the world clock, for drying.
static func add_fuel(fire: Node3D, it: Dictionary, days: float) -> String:
	var st := store_of(fire)
	if st.is_empty():
		return "full"
	if units_now(st) > float(F.get("store_max_units", 12)) - 0.999:
		return "full"
	var kind := str(it.get("fuel", "branch"))
	var wet: Dictionary = D.get("wet", {})
	var is_wet := bool(it.get("wet", false)) and (days - float(it.get("wet_days", days))) * 24.0 < float(wet.get("dry_h_game", 6.0))
	var minutes := burn_min(kind) * (float(wet.get("burn_scale", 0.4)) if is_wet else 1.0)
	var state := str(st.state)
	if state == "embers":
		if is_wet and randf() > float(wet.get("light_chance", 0.3)):
			return "hiss"
		if bool((F.get("relight", {}) as Dictionary).get("from_dry_fuel_on_embers", true)):
			st.state = "low"
	(st.units as Array).append([kind, minutes])
	if str(st.state) in ["flames", "low"]:
		st.state = "low" if share(st) < float(F.get("low_share", 0.25)) else "flames"
	apply(fire)
	if str(st.state) != state:
		_log_state(fire.get_meta("fuel_key"), str(st.state))
	return "cold" if str(st.state) == "out" else "ok"


## A lit torch held to embers or a dead fire. Returns "ok", "no_fuel"
## (nothing there to burn) or "lit" (it was burning already).
static func relight(fire: Node3D) -> String:
	var st := store_of(fire)
	if st.is_empty() or str(st.state) in ["flames", "low"]:
		return "lit"
	if (st.units as Array).is_empty():
		return "no_fuel"
	st.state = "low" if share(st) < float(F.get("low_share", 0.25)) else "flames"
	apply(fire)
	_log_state(fire.get_meta("fuel_key"), str(st.state))
	return "ok"


## The burn level 0-1 the fire draws at (Campfire.flicker), and "lit".
static func apply(fire: Node3D) -> void:
	var st := store_of(fire)
	var state := str(st.get("state", "flames"))
	var burn := 1.0
	match state:
		"low":
			burn = 0.55
		"embers":
			burn = 0.12
		"out":
			burn = 0.0
	fire.set_meta("burn", burn)
	fire.set_meta("lit", state in ["flames", "low"])
	var flames := fire.get_node_or_null("Flames") as Node3D
	if flames:
		flames.visible = burn > 0.2
	for n in ["GroundWarm", "GroundGlow"]:
		var g := fire.get_node_or_null(n) as Node3D
		if g:
			g.visible = burn > 0.2
	var coals := fire.get_node_or_null("Coals") as MeshInstance3D
	if coals:
		var m := coals.get_surface_override_material(0) as StandardMaterial3D
		if m == null:
			m = coals.material_override as StandardMaterial3D
		if m:
			m = m.duplicate()
			var c := Campfire.COALS if burn > 0.2 else (Campfire.COALS.darkened(0.45) if state == "embers" else Color(0.12, 0.11, 0.1))
			m.albedo_color = c
			m.emission_enabled = burn > 0.0
			m.emission = c
			m.emission_energy_multiplier = 1.0 if burn > 0.2 else 0.5
			coals.material_override = m


## The nearest campfire (lit or not) within `radius` m of `pos`.
static func nearest(tree: SceneTree, pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for f in tree.get_nodes_in_group(Campfire.GROUP):
		var fire := f as Node3D
		if fire and fire.is_inside_tree():
			var dd := fire.global_position.distance_to(pos)
			if dd < best_d:
				best_d = dd
				best = fire
	return best

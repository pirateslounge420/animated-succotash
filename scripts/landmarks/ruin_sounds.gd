class_name RuinSounds
extends Node
## A ruin sounds like what lives in it (design 3 Oct §DI.3, data/audio.json
## ruins), inside §BG's two systems.
##
## Residents are SOURCES: for each built ruin within NEAR_M, each resident
## its place has (the climate and, where it holds one, the creature roster)
## calls from its part of the ruin at its hours (audio.json ruins.residents'
## hours, by the sun, SoundBed._hour_word), on an Audio3D player AT that
## part, now and then (EVERY_S), never a positionless loop:
##   tower_top  birds nesting (the roster's day birds that fit the place's
##              climate: the songbird's chirps, the toucan's calls);
##   vault      bats pouring out at dusk and streaming back at dawn (a
##              ruin with a delve, a tower or a keep);
##   window     an owl at night (a ruin 5 m or more high);
##   below      something small scrabbling in the dark at dusk and night
##              (the roster's night ground and canopy animals that fit);
##   cistern    frogs where frogs live and dripping, at any hour, where the
##              ruin has water (a wetland, standing water, the crag
##              fortress's cistern);
##   walls      lizards rustling in warm dry stone by day.
## The roster has no bats, owls or lizards yet: those three go by the
## climate alone (OWL_MIN_C, BAT_MIN_C, LIZARD_*), until it does.
## An overrun ruin's residents fall silent by day (delves.json overrun
## tells: sound_bed_quiet); at night the shapes and the hunter's call stay
## as Overrun builds them. The ghost (§DI.4) makes no sound.
##
## The ruin's own BED (positionless; SoundBed reads these): wind in the
## stones, a low moan when the wind at its opening (the window or the top,
## Wind.at) passes bed.stone_wind_from_mps; drips where it has water; the
## hush of a closed hall (the outdoor bed lowered by the enclosure, near a
## ruin). Each by how near the ruin is (BED_NEAR_M).
## Not written, on purpose: Minecraft's cave groans (§BG; Mike's call).

static var D: Dictionary = Audio3D.table().get("ruins", {})
const NEAR_M := 150.0
const BED_NEAR_M := Vector2(30.0, 90.0)
const REFRESH_S := 0.5
## Seconds between one resident's calls: [min, max].
const EVERY_S := {
	"birds": Vector2(3.0, 9.0), "bats": Vector2(2.0, 5.0), "owl": Vector2(9.0, 22.0),
	"scrabble": Vector2(5.0, 12.0), "frogs": Vector2(2.0, 5.0), "drip": Vector2(1.2, 3.5),
	"lizards": Vector2(6.0, 15.0),
}
## The residents: name -> [part, stream, audio kind].
const RESIDENTS := {
	"birds": ["tower_top", "chirp", "ruin_birds"],
	"bats": ["vault", "bats", "ruin_bats"],
	"owl": ["window", "owl", "ruin_owl"],
	"scrabble": ["below", "scrabble", "ruin_scrabble"],
	"frogs": ["cistern", "croak", "ruin_frogs"],
	"drip": ["cistern", "drip", "ruin_drip"],
	"lizards": ["walls", "lizard", "ruin_lizard"],
}
const BAT_MIN_C := 2.0
const OWL_MIN_C := -15.0
const LIZARD_MIN_C := 18.0
const LIZARD_MAX_MOISTURE := 0.5
## Ruins with a top birds nest in and a vault under them.
const TOWERED := [Ruins.Kind.TOWER, Ruins.Kind.CASTLE, Ruins.Kind.AQUEDUCT, Ruins.Kind.PYRAMID, Ruins.Kind.CRAG_FORTRESS, Ruins.Kind.ABBEY]

## The bed's three, for SoundBed (0-1).
static var stone_wind := 0.0
static var drips := 0.0
static var hush := 0.0

var main: Node
var world: Node
var chunks: ChunkManager
var player: Node3D
var sky: SkySystem
var landmarks: Landmarks
## Tools: "hour" (dawn/day/dusk/night), "wind_mps" (at the opening),
## "near" (bed nearness 0-1).
var override := {}
## The last refresh (tools): {"hour", "ruins": {ruin name: {"site", "who":
## [resident names], "silent": bool, "parts": {part: local}}}, "wind_mps"}.
var state := {}
var _on := {} # ruin instance id -> {"node", "who": {name: {"player", "next"}}}
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_main: Node) -> void:
	main = p_main
	world = main.world
	chunks = main.chunks
	player = main.player
	sky = main.sky
	landmarks = main.landmarks
	_rng.seed = 41


## The hours a part's residents keep (audio.json ruins.residents).
static func hours_of(part: String) -> Array:
	for r in D.get("residents", []):
		if str(r.get("part", "")) == part:
			return r.get("hours", ["any"])
	return ["any"]


## The stone wind's gain at the opening, by the wind there (m/s): 0 under
## bed.stone_wind_from_mps, full 4 m/s over it.
static func stone_wind_gain(mps: float) -> float:
	var from := float((D.get("bed", {}) as Dictionary).get("stone_wind_from_mps", 6.0))
	return smoothstep(from, from + 4.0, mps)


## The ruin's parts in its own frame (from its drawn mesh's bounds, and its
## delve's door where it has one): {part: Vector3}.
static func parts_of(node: Node3D) -> Dictionary:
	var site: Dictionary = node.get_meta("site", {})
	var aabb := AABB()
	for c in node.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.name != "Delve" and mi.name != "FarLOD" and mi.mesh != null:
			aabb = mi.get_aabb()
			break
	var cx := aabb.get_center().x
	var cz := aabb.get_center().z
	var top := aabb.end.y
	var base := maxf(aabb.position.y, -1.0)
	var height := top - base
	var hx := aabb.size.x * 0.5
	var out := {"height": height}
	out.tower_top = Vector3(cx, top - 0.5, cz)
	out.window = Vector3(cx + hx * 0.8, base + height * 0.65, cz)
	var vault := Vector3(cx, 0.5, cz)
	var lay: Dictionary = node.get_meta("delve", {})
	if lay.has("door_out"):
		vault = (lay.door_out as Vector3) + Vector3(0.0, 1.0, 0.0)
	elif not lay.is_empty():
		vault = Vector3(0.0, 0.8, -float(site.get("half_l", 0.0)) - 0.8)
	out.vault = vault
	out.below = vault - Vector3(0.0, 0.5, 0.0)
	out.cistern = Vector3(cx, 0.3, cz)
	if lay.has("well"):
		out.cistern = (lay.well as Vector3) + Vector3(0.0, 0.3, 0.0)
	# The sunward wall (warm stone): toward the equator.
	var d: Vector3 = site.get("dir", Vector3.UP)
	var eq := CubeSphere.north(d) * (-1.0 if CubeSphere.latitude(d) >= 0.0 else 1.0)
	var basis := node.global_basis.orthonormalized() if node.is_inside_tree() else Basis()
	var local_eq := basis.inverse() * eq
	local_eq.y = 0.0
	local_eq = local_eq.normalized() if local_eq.length() > 0.01 else Vector3.RIGHT
	out.walls = Vector3(cx, 1.0, cz) + local_eq * maxf(hx, aabb.size.z * 0.5) * 0.9
	return out


## Who lives in this ruin (whatever the hour): [resident names].
func residents_of(node: Node3D, parts: Dictionary) -> Array:
	var site: Dictionary = node.get_meta("site", {})
	var d: Vector3 = site.dir
	var map: PlanetData = world.planet
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var kind := int(site.get("kind", -1))
	var lay: Dictionary = node.get_meta("delve", {})
	var out: Array = []
	if TOWERED.has(kind) and _roster_has(t, m, ["bird"], ["day", "any"]):
		out.append("birds")
	if (TOWERED.has(kind) or not lay.is_empty()) and t >= BAT_MIN_C:
		out.append("bats")
	if float(parts.get("height", 0.0)) >= 5.0 and t >= OWL_MIN_C:
		out.append("owl")
	if _roster_has(t, m, ["rodent", "quadruped"], ["night", "any"], ["ground", "canopy"]):
		out.append("scrabble")
	if has_water(node):
		out.append("drip")
		# (Frogs where frogs live: the roster's, else a mild wet place,
		# never brackish water.)
		var salty := ["SALT_MARSH", "MANGROVE", "ESTUARY"].has(BiomeTemplates.KEYS[map.biome[map.cell_at(d)]])
		if not salty and (_roster_has(t, m, ["frog"], ["night", "any", "day"]) or (t >= 8.0 and m >= 0.55)):
			out.append("frogs")
	if t >= LIZARD_MIN_C and m <= LIZARD_MAX_MOISTURE:
		out.append("lizards")
	return out


## Does the roster hold a member of `bodies` active at `actives` (in
## `roles`, any if empty) that fits temperature `t` and moisture `m`?
static func _roster_has(t: float, m: float, bodies: Array, actives: Array, roles := []) -> bool:
	for sp in CreatureSpecies.all():
		if not bodies.has(sp.body) or not actives.has(sp.active):
			continue
		if not roles.is_empty() and not roles.has(sp.role):
			continue
		if t >= sp.temp_c.x and t <= sp.temp_c.y and m >= sp.moisture.x and m <= sp.moisture.y:
			return true
	return false


## Water in the ruin: a wetland, standing water over its middle, a
## boardwalk's marsh, or the crag fortress's cistern.
func has_water(node: Node3D) -> bool:
	var site: Dictionary = node.get_meta("site", {})
	var d: Vector3 = site.dir
	if int(site.get("kind", -1)) == Ruins.Kind.BOARDWALK:
		return true
	# The hanging gardens' channel (§DT).
	if int(site.get("kind", -1)) == Ruins.Kind.HANGING_GARDENS:
		return true
	if (node.get_meta("delve", {}) as Dictionary).has("well"):
		return true
	var map: PlanetData = world.planet
	if VegetationPlacer.WETLANDS.has(map.biome[map.cell_at(d)]):
		return true
	if chunks != null and chunks.chunk_at(d) != null:
		return chunks.water_level_at(d) > chunks.ground_height(d) + 0.05
	return false


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH_S
		refresh()
	for id in _on:
		var r: Dictionary = _on[id]
		for name in r.who:
			var w: Dictionary = r.who[name]
			w.next = float(w.next) - delta
			if float(w.next) <= 0.0:
				var ev: Vector2 = EVERY_S.get(name, Vector2(5.0, 10.0))
				w.next = _rng.randf_range(ev.x, ev.y)
				var p: AudioStreamPlayer3D = w.player
				if is_instance_valid(p):
					p.stream = SoundSynth.stream(str(RESIDENTS[name][1]), _rng.randi())
					p.pitch_scale = _rng.randf_range(0.92, 1.08)
					p.play()


## The hour word now at the player (or override.hour).
func hour_now() -> String:
	if override.has("hour"):
		return str(override.hour)
	var d: Vector3 = world.dir_of(player.global_position)
	return SoundBed._hour_word(float(world.local_clock(d).y), sky.sun_elevation_deg if sky != null else NAN)


## Who calls, where, now; the bed's three.
func refresh() -> void:
	var hour := hour_now()
	var pp := player.global_position
	var pd: Vector3 = world.dir_of(pp)
	var seen := {}
	state = {"hour": hour, "ruins": {}}
	var bed_near := 0.0
	var bed_wind := 0.0
	var bed_water := 0.0
	for c in landmarks._ruins:
		var node: Node3D = landmarks._ruins[c]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var site: Dictionary = node.get_meta("site", {})
		if site.is_empty():
			continue
		var dist := CubeSphere.surface_distance_m(site.dir, pd)
		if dist > NEAR_M + float(site.get("footprint_m", 10.0)):
			continue
		var id := node.get_instance_id()
		seen[id] = true
		var parts: Dictionary = node.get_meta("ruin_parts", {})
		if parts.is_empty():
			parts = parts_of(node)
			node.set_meta("ruin_parts", parts)
		var who: Array = node.get_meta("ruin_residents", [])
		if not node.has_meta("ruin_residents"):
			who = residents_of(node, parts)
			# (Kept once its ground is loaded: the standing water reads it.)
			if chunks == null or chunks.chunk_at(site.dir) != null:
				node.set_meta("ruin_residents", who)
		# Silent by day when overrun (§CN's tell).
		var silent := Overrun.is_overrun(site) and (hour == "day" or hour == "dawn") and bool(D.get("overrun_quiet_by_day", true))
		var now: Array = []
		if not silent:
			for name in who:
				var hrs := hours_of(str(RESIDENTS[name][0]))
				if hrs.has("any") or hrs.has(hour):
					now.append(name)
		if not _on.has(id):
			_on[id] = {"node": node, "who": {}}
		var r: Dictionary = _on[id]
		for name in r.who.keys():
			if not now.has(name):
				var w: Dictionary = r.who[name]
				if is_instance_valid(w.player):
					w.player.queue_free()
				r.who.erase(name)
		for name in now:
			if r.who.has(name):
				continue
			var p := Audio3D.make(str(RESIDENTS[name][2]), node, "Resident_" + str(name))
			p.position = parts[RESIDENTS[name][0]]
			var ev: Vector2 = EVERY_S.get(name, Vector2(5.0, 10.0))
			r.who[name] = {"player": p, "next": _rng.randf_range(0.2, ev.y * 0.5)}
		state.ruins[node.name] = {"site": site, "who": now, "lives": who, "silent": silent, "parts": parts, "dist": dist}
		# The bed: the nearest ruin's.
		var near := 1.0 - smoothstep(BED_NEAR_M.x, BED_NEAR_M.y, maxf(dist - float(site.get("footprint_m", 10.0)), 0.0))
		if near > bed_near:
			bed_near = near
			var opening: Vector3 = node.global_transform * (parts.window if float(parts.get("height", 0.0)) >= 5.0 else parts.tower_top)
			var up: Vector3 = node.global_basis.y.normalized()
			var z := maxf((parts.window as Vector3).y, 2.0)
			bed_wind = float(override.wind_mps) if override.has("wind_mps") else Wind.at(opening, up, z).length()
			bed_water = 1.0 if who.has("drip") else 0.0
	for id in _on.keys():
		if not seen.has(id):
			var r: Dictionary = _on[id]
			for name in r.who:
				var w: Dictionary = r.who[name]
				if is_instance_valid(w.player):
					w.player.queue_free()
			_on.erase(id)
	if override.has("near"):
		bed_near = float(override.near)
	state.wind_mps = bed_wind
	state.near = bed_near
	stone_wind = stone_wind_gain(bed_wind) * bed_near
	drips = bed_water * bed_near
	var enclosed := sky.enclosure() if sky != null else 0.0
	hush = (enclosed * 0.6 * bed_near) if bool((D.get("bed", {}) as Dictionary).get("enclosed_hush", true)) else 0.0


## The residents playing now: [[ruin name, resident, scene position]].
func playing() -> Array:
	var out: Array = []
	for id in _on:
		var r: Dictionary = _on[id]
		for name in r.who:
			var w: Dictionary = r.who[name]
			if is_instance_valid(w.player):
				out.append([r.node.name, name, (w.player as Node3D).global_position, (w.player as AudioStreamPlayer3D).playing])
	return out

class_name DayShift
extends Node3D
## The world gets ready at dawn and dusk (design §GF; queue 115;
## data/day_shift.json). A child of a surface (Surface or HubCamp): every
## routine fires on the local sun's height (Surface.sun_deg_at, the place's
## latitude, §GE.5), never on a clock hour, and every actor adds its own
## offset (sun_deg.actor_jitter_deg) so the change spreads across the
## twilight. Nothing underground (day_shift.underground false): the
## dungeon has no DayShift.
##
##   share      0 day - 1 night for one actor: where the sun stands in the
##              evening window (dusk_start -> dusk_end, sinking) or the
##              morning one (dawn_start -> dawn_end, rising), shifted by the
##              actor's jitter
##   flowers    the blooms tagged "bloom" (meta habit day / night / always)
##              open and close over flowers.open_close_s; night bloomers
##              draw moths
##   creatures  the ground life walks to cover and sleeps, or comes out
##              (SurfaceLife.awake_fn); a flock of birds roosts at dusk;
##              bats pour out of their roost (a ruin's stair mouth; at the
##              hub, a crevice at the cliff foot) at dusk
##              and go back in at dawn; moths come to the lit torches
##   sound      dusk: birds thin, then night insects, frogs by water, owls;
##              dawn: a chorus, then the night fades (crossfade_s)
##   folk       the hub's keepers light their own lights in turn, on foot,
##              each from a flame already burning: the cook-shaman builds
##              up the hearth, each keeper fetches a flame from it, lights
##              their torch post and the lamp in their shelter and sits
##              again, never two lights in the same per_light_gap_s; the
##              shaman lights the candles by the hearth last; at dawn they
##              put them out and the hearth is banked, not out

static var D: Dictionary = Tuning.table("day_shift")

var surface: Surface
var world: Node
var hub: HubCamp
var _seed := 0
var _blooms: Array = []        # [{"node", "habit", "id", "open"}]
var _moths: Array = []         # [{"p": CPUParticles3D, "id", "light": Node or null, "bloom": bool}]
var _bats: Array = []          # [{"n", "id", "state", "a", "r", "y", "t"}]
var _birds: Array = []         # [{"n", "id", "state", "at", "goal", "t", "roost"}]
var _mouth := Vector3.ZERO
var _center := Vector3.ZERO
## The folk's lights: [{"id", "kind", "owner", "parts", "light", "energy", "at", "lit"}].
var lights: Array = []
## The keepers walking their rounds: owner -> {"motion", "seat", "yaw", "steps", "i", "wait"}.
var _rounds := {}
var last_lit_s := -1e9
var lit_log: Array = []        # [[clock_s, id, on]] (checks)
var clock_s := 0.0
var _hearth_k := 0.35
var _sounds := {}
var _vol := {}
var _owl_t := 20.0
var _chirp_t := 1.0
var _rng := RandomNumberGenerator.new()
var _started := false


func setup(p_surface: Surface, p_world: Node, seed_value: int) -> void:
	name = "DayShift"
	surface = p_surface
	world = p_world
	hub = p_surface as HubCamp
	_seed = seed_value
	_rng.seed = hash([seed_value, "day shift"])
	_mouth = p_surface.bat_roost()
	_center = hub.camp.pos if hub != null else Vector3(p_surface.land.center.x, p_surface.land.base_y, p_surface.land.center.y)


# --- The sun and each actor's share --------------------------------------------------

func days() -> float:
	return float(world.get("days"))


func sun() -> float:
	return Surface.sun_deg_at(days())


func rising() -> bool:
	return Surface.sun_deg_at(days() + 0.002) > sun()


## An actor's own offset (degrees), from its id and the surface's seed.
func jitter(id: String) -> float:
	var j := float((D.get("sun_deg", {}) as Dictionary).get("actor_jitter_deg", 2.5))
	var h := float(posmod(hash([_seed, id]), 10007)) / 10006.0
	return lerpf(-j, j, h)


## 0 day - 1 night for an actor with offset `j` at sun height `s`.
static func share_at(s: float, j: float, up: bool) -> float:
	var S: Dictionary = D.get("sun_deg", {})
	var a := float(S.get("dawn_end", 4.0)) if up else float(S.get("dusk_start", 4.0))
	var b := float(S.get("dawn_start", -8.0)) if up else float(S.get("dusk_end", -8.0))
	return clampf((a + j - s) / maxf(a - b, 0.01), 0.0, 1.0)


func share(id := "") -> float:
	return share_at(sun(), jitter(id) if id != "" else 0.0, rising())


func is_night(id: String) -> bool:
	return share(id) >= 0.5


## Is a creature of `shift` ("day", "night", "twilight", "any") about now?
func awake_for(shift: String, id: String) -> bool:
	var s := share(id)
	match shift:
		"day":
			return s < 0.5
		"night", "full_moon":
			return s >= 0.5
		"twilight":
			return s > 0.15 and s < 0.85
	return true


# --- Building what it drives --------------------------------------------------------

func build() -> void:
	var C: Dictionary = D.get("crawler", {})
	if hub != null:
		_hub_blooms(C)
		_hub_lights()
	_flock(C)
	_bat_colony(C)
	_sound()
	if surface.life != null:
		surface.life.awake_fn = func(a: Dictionary) -> bool:
			var sp: CreatureSpecies = a.sp
			return awake_for(shift_of(sp), str(a.root.name))
		var covers: Array = []
		if surface.plants != null:
			for t in surface.plants.trees_placed:
				covers.append(t[0])
		surface.life.covers = covers


## A creature's shift: its own tag (active), else day_shift.creatures
## default_by_kind by a word in its name, else day.
static func shift_of(sp: CreatureSpecies) -> String:
	if sp.active in ["day", "night", "twilight", "full_moon"]:
		return "night" if sp.active == "full_moon" else sp.active
	# Untagged, or "any" (no hours of its own): by its kind, when the data
	# names it (deer twilight, owls night...), else about all the time.
	var by: Dictionary = (D.get("creatures", {}) as Dictionary).get("default_by_kind", {})
	var nm := sp.name.to_lower()
	for k in by:
		if nm.contains(str(k)):
			return str(by[k])
	return "any" if sp.active == "any" else "day"


func _hub_blooms(C: Dictionary) -> void:
	# The herbalist's bed (HubCamp tags each bloom), and clumps of night
	# bloomers (moonflower, datura) about the camp.
	var stack: Array = [hub]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.has_meta("bloom_habit"):
			_blooms.append({"node": n, "habit": str(n.get_meta("bloom_habit")), "id": str(n.get_path()), "open": 1.0, "scale": (n as Node3D).scale})
	var clumps := int(C.get("night_bloomer_clumps", 4))
	var genus: Array = (D.get("flowers", {}) as Dictionary).get("night", ["Datura"])
	for i in clumps:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(7.0, 16.0)
		var p := Vector2(_center.x, _center.z) + Vector2(cos(a), sin(a)) * r
		if not surface.land.inside(p, 25.0) or surface.land.in_wash(p) > 0.05:
			continue
		var root := Node3D.new()
		root.name = "NightBloomers_%d" % i
		root.position = Vector3(p.x, surface.land.height_at(p.x, p.y), p.y)
		root.set_meta("genus", str(genus[i % genus.size()]))
		add_child(root)
		for k in 6:
			var q := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))
			var h := _rng.randf_range(0.5, 1.0)
			var stem := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.012
			cm.bottom_radius = 0.018
			cm.height = h
			stem.mesh = cm
			stem.material_override = _flat("#2f6b2a", 0.6)
			stem.position = q + Vector3(0, h * 0.5, 0)
			root.add_child(stem)
			var fl := MeshInstance3D.new()
			var tr := CylinderMesh.new()
			tr.top_radius = 0.11
			tr.bottom_radius = 0.02
			tr.height = 0.2
			tr.radial_segments = 8
			fl.mesh = tr
			fl.material_override = _flat("#eef0ff", 0.3, 0.5)
			fl.position = q + Vector3(0, h + 0.08, 0)
			fl.rotation = Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
			root.add_child(fl)
			_blooms.append({"node": fl, "habit": "night", "id": "%s_%d" % [root.name, k], "open": 1.0, "scale": fl.scale})
		_moths.append({"p": _moth_cloud(root, Vector3(0, 1.0, 0)), "id": str(root.name), "light": null, "bloom": true})


var _flats := {}


func _flat(hex: String, rough: float, glow := 0.0) -> StandardMaterial3D:
	var k := "%s%.2f%.2f" % [hex, rough, glow]
	if not _flats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = rough
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = glow
		_flats[k] = m
	return _flats[k]


func _moth_cloud(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Moths"
	p.amount = int((D.get("crawler", {}) as Dictionary).get("moths_per_light", 10))
	p.lifetime = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.orbit_velocity_min = 0.4
	p.orbit_velocity_max = 0.9
	p.tangential_accel_min = -1.0
	p.tangential_accel_max = 1.0
	p.damping_min = 0.5
	p.damping_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color("#d8cfa8")
	q.material = m
	p.mesh = q
	p.position = at
	p.emitting = false
	parent.add_child(p)
	return p


func _hub_lights() -> void:
	# In data's order: the hearth, the torch holders, the lamps, the candles.
	lights.append({"id": "hearth", "kind": "hearth", "owner": "shaman", "parts": [], "light": hub.fire.get_node_or_null("Light"), "energy": 0.0, "at": hub.camp.pos, "lit": true})
	for e in hub.folk_lights:
		var l: Dictionary = (e as Dictionary).duplicate()
		l["lit"] = false
		var ol := l.light as OmniLight3D
		l["energy"] = ol.light_energy if ol != null else 0.0
		lights.append(l)
	var rank := {"hearth": 0, "torch": 1, "lamp": 2, "candle": 3}
	lights.sort_custom(func(a, b): return int(rank.get(a.kind, 9)) < int(rank.get(b.kind, 9)))
	for l in lights:
		if str(l.kind) == "torch":
			_moths.append({"p": _moth_cloud(self, (l.at as Vector3) + Vector3(0, 0.4, 0)), "id": str(l.id), "light": l, "bloom": false})
	for k in hub.keeper_folk:
		var f := k as HearthFolk
		var m := FolkMotion.new(f)
		m.ground = surface.land.height_at
		_rounds[str(f.get_meta("keeper"))] = {"motion": m, "folk": f, "seat": f.global_position, "yaw": f.rotation.y, "steps": [], "i": 0, "wait": 0.0, "walking": false}


## The state now, at once, for each light whose owner's change is long
## past (a Continue or a surface you come back up onto): lit at night, out
## by day; the rest are left to the folk's rounds.
func settle_now() -> void:
	for l in lights:
		var s := share(str(l.owner))
		if s >= 0.98 or s <= 0.02:
			_set_lit(l, s >= 0.5, false)
	var hs := share("shaman")
	_hearth_k = 1.0 if hs >= 0.5 else float((D.get("crawler", {}) as Dictionary).get("hearth_banked", 0.35))
	_apply_hearth()
	for b in _blooms:
		b.open = _bloom_target(b)
		_show_bloom(b)


func _set_lit(l: Dictionary, on: bool, log_it := true) -> void:
	if str(l.kind) == "hearth":
		return
	l.lit = on
	var ol := l.light as OmniLight3D
	if ol != null:
		ol.visible = on
	for p in l.parts:
		var mi := p as MeshInstance3D
		if mi != null:
			mi.visible = on
	if log_it:
		last_lit_s = clock_s
		lit_log.append([clock_s, str(l.id), on])


func _apply_hearth() -> void:
	if hub == null or hub.fire == null:
		return
	var l := hub.fire.get_node_or_null("Light") as OmniLight3D
	if l != null:
		if not hub.fire.has_meta("base_energy"):
			hub.fire.set_meta("base_energy", l.light_energy)
		l.light_energy = float(hub.fire.get_meta("base_energy")) * _hearth_k
	for c in hub.fire.find_children("Card*", "", true, false):
		var mi := c as MeshInstance3D
		if mi != null and mi.material_override is ShaderMaterial:
			(mi.material_override as ShaderMaterial).set_shader_parameter("low", clampf((1.0 - _hearth_k) * 0.9, 0.0, 0.9))


# --- Birds and bats -----------------------------------------------------------------

func _bird_mesh(col: String, span: float) -> Node3D:
	var n := Node3D.new()
	for s in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(span, 0.02, span * 0.45)
		w.mesh = pm
		w.material_override = _flat(col, 0.6)
		w.position = Vector3(s * span * 0.5, 0, 0)
		w.name = "Wing" + ("L" if s < 0 else "R")
		n.add_child(w)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = span * 0.18
	sm.height = span * 0.5
	body.mesh = sm
	body.material_override = _flat(col, 0.5)
	n.add_child(body)
	return n


func _flock(C: Dictionary) -> void:
	var trees: Array = surface.plants.trees_placed if surface.plants != null else []
	for i in int(C.get("birds", 10)):
		var n := _bird_mesh("#3a3048", 0.22)
		n.name = "Bird_%d" % i
		add_child(n)
		var roost := _center + Vector3(_rng.randf_range(-20, 20), 8.0, _rng.randf_range(-20, 20))
		if not trees.is_empty():
			var t: Array = trees[_rng.randi_range(0, trees.size() - 1)]
			var q: Vector2 = t[0]
			roost = Vector3(q.x, surface.land.height_at(q.x, q.y) + float(t[1]) * 0.85, q.y)
		_birds.append({"n": n, "id": "bird_%d" % i, "state": "out", "at": roost + Vector3(0, 6, 0), "goal": roost, "t": 0.0, "roost": roost, "a": _rng.randf() * TAU, "r": _rng.randf_range(8.0, 22.0), "y": _rng.randf_range(7.0, 14.0)})


func _bat_colony(C: Dictionary) -> void:
	if _mouth == Vector3.ZERO:
		return
	for i in int(C.get("bats", 12)):
		var n := _bird_mesh("#141420", 0.3)
		n.name = "Bat_%d" % i
		n.visible = false
		add_child(n)
		_bats.append({"n": n, "id": "bat_%d" % i, "state": "in", "a": _rng.randf() * TAU, "r": _rng.randf_range(10.0, 26.0), "y": _rng.randf_range(6.0, 14.0), "t": 0.0, "at": _mouth})


func birds_out() -> int:
	return _birds.filter(func(b): return str(b.state) != "roosting").size()


func bats_out() -> int:
	return _bats.filter(func(b): return str(b.state) != "in").size()


func _fly(delta: float) -> void:
	var flap := sin(clock_s * 18.0)
	for b in _birds:
		var n: Node3D = b.n
		var night := is_night(str(b.id))
		match str(b.state):
			"out":
				b.a = float(b.a) + delta * 0.25
				b.at = _center + Vector3(cos(float(b.a)) * float(b.r), float(b.y), sin(float(b.a)) * float(b.r))
				if night:
					b.state = "to_roost"
			"to_roost":
				b.at = (b.at as Vector3).move_toward(b.roost, delta * 5.0)
				if (b.at as Vector3).distance_to(b.roost) < 0.2:
					b.state = "roosting"
			"roosting":
				if not night:
					b.state = "out"
		n.visible = str(b.state) != "roosting"
		n.position = b.at
		for w in n.get_children():
			if w.name.begins_with("Wing"):
				(w as Node3D).rotation.z = flap * 0.6 * (1.0 if w.name.ends_with("R") else -1.0)
	for b in _bats:
		var n: Node3D = b.n
		var night := is_night(str(b.id))
		match str(b.state):
			"in":
				if night:
					b.state = "emerging"
					b.at = _mouth
			"emerging":
				var target := _center + Vector3(cos(float(b.a)) * float(b.r), float(b.y), sin(float(b.a)) * float(b.r))
				b.at = (b.at as Vector3).move_toward(target, delta * 6.0)
				if (b.at as Vector3).distance_to(target) < 0.3:
					b.state = "out"
			"out":
				b.a = float(b.a) + delta * 0.6
				var jit := sin(clock_s * 3.1 + float(b.r)) * 1.2
				b.at = _center + Vector3(cos(float(b.a)) * float(b.r), float(b.y) + jit, sin(float(b.a)) * float(b.r))
				if not night:
					b.state = "returning"
			"returning":
				b.at = (b.at as Vector3).move_toward(_mouth, delta * 6.0)
				if (b.at as Vector3).distance_to(_mouth) < 0.3:
					b.state = "in"
		n.visible = str(b.state) != "in"
		n.position = b.at
		for w in n.get_children():
			if w.name.begins_with("Wing"):
				(w as Node3D).rotation.z = sin(clock_s * 26.0 + float(b.r)) * 0.8 * (1.0 if w.name.ends_with("R") else -1.0)


# --- Flowers and moths --------------------------------------------------------------

func _bloom_target(b: Dictionary) -> float:
	match str(b.habit):
		"day":
			return 0.0 if is_night(str(b.id)) else 1.0
		"night":
			return 1.0 if is_night(str(b.id)) else 0.0
	return 1.0


func _show_bloom(b: Dictionary) -> void:
	var n := b.node as Node3D
	var k := lerpf(0.3, 1.0, float(b.open))
	var s0: Vector3 = b.scale
	n.scale = Vector3(s0.x * k, s0.y * lerpf(1.4, 1.0, float(b.open)) * k, s0.z * k)


func bloom_open(habit: String) -> float:
	var sum := 0.0
	var n := 0
	for b in _blooms:
		if str(b.habit) == habit:
			sum += float(b.open)
			n += 1
	return sum / n if n > 0 else -1.0


func _flowers(delta: float) -> void:
	var rate := delta / maxf(float((D.get("flowers", {}) as Dictionary).get("open_close_s", 90.0)), 0.1)
	for b in _blooms:
		b.open = move_toward(float(b.open), _bloom_target(b), rate)
		_show_bloom(b)
	for m in _moths:
		var on := is_night(str(m.id))
		if m.light != null:
			on = on and bool((m.light as Dictionary).lit)
		(m.p as CPUParticles3D).emitting = on


# --- Sound ----------------------------------------------------------------------------

func _sound() -> void:
	for pair in [["birds", "birds_far_loop"], ["frogs", "frogs_loop"]]:
		var a := AudioStreamPlayer.new()
		a.name = "Shift_" + str(pair[0])
		a.stream = SoundSynth.stream(str(pair[1]), 1)
		a.bus = AudioMix.bus("ambience")
		a.volume_db = -80.0
		add_child(a)
		_sounds[pair[0]] = a
	for k in ["owl", "chirp"]:
		var a := AudioStreamPlayer.new()
		a.name = "Shift_" + k
		a.bus = AudioMix.bus("ambience")
		add_child(a)
		_sounds[k] = a


## The layers' targets (0-1) at night share `s` (dusk order: birds thin,
## then insects, frogs where there is water, owls; dawn: a chorus first).
func sound_targets(s: float, up: bool) -> Dictionary:
	var water := hub != null and hub.get_node_or_null("River") != null
	var t := {
		"birds": 1.0 - smoothstep(0.0, 0.35, s),
		"day": 1.0 - smoothstep(0.1, 0.45, s),
		"night": smoothstep(0.2, 0.55, s),
		"frogs": smoothstep(0.4, 0.75, s) if water else 0.0,
		"owls": smoothstep(0.7, 1.0, s),
		"chorus": 0.0,
	}
	if up:
		# The dawn chorus: birds first, loud, while it is still dusky.
		t.chorus = smoothstep(0.85, 0.6, s) * (1.0 - smoothstep(0.3, 0.05, s))
		t.birds = maxf(t.birds, t.chorus)
	return t


func _sound_tick(delta: float) -> void:
	var s := share()
	var t := sound_targets(s, rising())
	var tau := maxf(float((D.get("sound", {}) as Dictionary).get("crossfade_s", 120.0)) * 0.25, 0.1)
	var k := 1.0 - exp(-delta / tau)
	for key in t:
		_vol[key] = lerpf(float(_vol.get(key, t[key])), float(t[key]), k)
	var S2: Dictionary = Surface.S.get("sound", {})
	_set_vol(surface._sounds.get("day"), float(S2.get("day_db", -26.0)), _vol.day)
	_set_vol(surface._sounds.get("night"), float(S2.get("night_db", -23.0)), _vol.night)
	_set_vol(_sounds.get("birds"), -24.0 + 6.0 * float(_vol.chorus), _vol.birds)
	_set_vol(_sounds.get("frogs"), -22.0, _vol.frogs)
	_owl_t -= delta
	if _owl_t <= 0.0:
		_owl_t = _rng.randf_range(18.0, 45.0)
		if float(_vol.owls) > 0.3:
			_one_shot("owl", "owl", -20.0)
	_chirp_t -= delta
	if _chirp_t <= 0.0:
		_chirp_t = lerpf(6.0, 0.6, float(_vol.chorus)) * _rng.randf_range(0.6, 1.4)
		if float(_vol.chorus) > 0.2 or (float(_vol.birds) > 0.5 and _rng.randf() < 0.3):
			_one_shot("chirp", "chirp", -22.0)


func _set_vol(a: Variant, db: float, share_v: float) -> void:
	var p := a as AudioStreamPlayer
	if p == null:
		return
	if not p.playing and share_v > 0.01 and p.stream != null:
		p.play()
	p.volume_db = db + linear_to_db(maxf(share_v, 0.001))


func _one_shot(key: String, kind: String, db: float) -> void:
	var a := _sounds.get(key) as AudioStreamPlayer
	if a == null:
		return
	a.stream = SoundSynth.stream(kind, _rng.randi_range(0, SoundSynth.VARIANTS - 1))
	a.volume_db = db
	a.play()


# --- The folk's rounds --------------------------------------------------------------

func _folk(delta: float) -> void:
	if hub == null:
		return
	var C: Dictionary = D.get("crawler", {})
	var gap := float((D.get("folk_lights", {}) as Dictionary).get("per_light_gap_s", 8.0))
	# The cook-shaman: the hearth built up at dusk, banked at dawn; the
	# candles last, from it.
	var want_k := 1.0 if is_night("shaman") else float(C.get("hearth_banked", 0.35))
	if absf(_hearth_k - want_k) > 0.001:
		_hearth_k = move_toward(_hearth_k, want_k, delta / maxf(float(C.get("hearth_change_s", 20.0)), 0.1))
		_apply_hearth()
	var night_shaman := is_night("shaman")
	for l in lights:
		if str(l.kind) != "candle" or bool(l.lit) == night_shaman:
			continue
		# Candles only once every lamp is lit (data's order), or out at dawn.
		if night_shaman and lights.any(func(o): return str(o.kind) in ["torch", "lamp"] and not bool(o.lit)):
			continue
		if clock_s - last_lit_s >= gap:
			_set_lit(l, night_shaman)
	# Each keeper.
	for owner in _rounds:
		var r: Dictionary = _rounds[owner]
		var mine := lights.filter(func(o): return str(o.owner) == owner and str(o.kind) in ["torch", "lamp"])
		if mine.is_empty():
			continue
		var night := is_night(owner)
		var m: FolkMotion = r.motion
		if not bool(r.walking):
			var need := mine.filter(func(o): return bool(o.lit) != night)
			if need.is_empty():
				continue
			_plan_round(owner, r, need, night)
		if bool(r.walking):
			_walk_round(owner, r, delta, gap)
		m.update(delta)


## A keeper's round: up from the seat, (at dusk) to the hearth for a flame,
## to each light in order, back to the seat.
func _plan_round(owner: String, r: Dictionary, need: Array, night: bool) -> void:
	var steps: Array = []
	var seat: Vector3 = r.seat
	if night:
		var fp: Vector3 = hub.camp.pos
		var to_seat := Vector3(seat.x - fp.x, 0.0, seat.z - fp.z).normalized()
		steps.append({"go": fp + to_seat * 1.3, "do": "flame"})
	for l in need:
		var at: Vector3 = l.at
		var off := Vector3(at.x - seat.x, 0.0, at.z - seat.z)
		var stand := at - off.normalized() * 0.6 if off.length() > 0.7 else at
		steps.append({"go": Vector3(stand.x, at.y, stand.z), "do": "light" if night else "out", "light": l})
	steps.append({"go": seat, "do": "sit"})
	r.steps = steps
	r.i = 0
	r.walking = true
	r["rounds"] = int(r.get("rounds", 0)) + 1
	r.wait = 0.0
	var m: FolkMotion = r.motion
	var f: HearthFolk = r.folk
	m.rise_from_seat(Vector3(f.global_position.x, surface.land.height_at(f.global_position.x, f.global_position.z), f.global_position.z))
	m.stand_up()
	m.walk_to(PackedVector3Array([steps[0].go]))


func _walk_round(owner: String, r: Dictionary, delta: float, gap: float) -> void:
	var m: FolkMotion = r.motion
	var steps: Array = r.steps
	var i := int(r.i)
	if i >= steps.size():
		r.walking = false
		return
	if not m.walk(delta, float((D.get("crawler", {}) as Dictionary).get("walk_mps", 1.1)), 240.0):
		return
	var st: Dictionary = steps[i]
	# The sun moved on while it walked (a round begun at one dusk and
	# still under way): it does what the sun says now, not what it set out
	# to do.
	var night_now := is_night(owner)
	if str(st.do) in ["light", "out"]:
		st["do"] = "light" if night_now else "out"
	elif str(st.do) == "flame" and not night_now:
		st["do"] = "skip"
	match str(st.do):
		"flame":
			r.wait = float(r.wait) + delta
			if float(r.wait) < 1.2:
				m.reach_point(1, hub.camp.pos + Vector3(0, 0.4, 0))
				return
			m.release(1)
		"light", "out":
			var l: Dictionary = st.light
			var want := str(st.do) == "light"
			if bool(l.lit) != want:
				m.reach_point(1, (l.at as Vector3) + Vector3(0, 1.0, 0))
				if clock_s - last_lit_s < gap:
					return
				_set_lit(l, want)
			m.release(1)
		"sit":
			m.sit_at(r.seat - Vector3(0.0, float(HearthFolk.RES.get("seat_h_m", 0.32)) - HearthFolk.SEAT_TOP * (r.folk as HearthFolk).k, 0.0), float(r.yaw))
			(r.folk as HearthFolk).global_position = r.seat
			r.walking = false
			return
	r.i = i + 1
	r.wait = 0.0
	if int(r.i) < steps.size():
		m.walk_to(PackedVector3Array([(steps[int(r.i)] as Dictionary).go]))


func _process(delta: float) -> void:
	if surface == null or not surface.is_inside_tree():
		return
	if not _started:
		_started = true
		settle_now()
	tick(delta)


## One step of everything (the checks drive it with their own delta).
func tick(delta: float) -> void:
	clock_s += delta
	_flowers(delta)
	_fly(delta)
	_folk(delta)
	_sound_tick(delta)

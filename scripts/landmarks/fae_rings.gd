class_name FaeRings
extends Node
## Fairy rings and the fae (design 5 Oct §EO.3–§EO.5; data/fae.json).
##
## Rings: a ring of mushrooms (Mushroom) in a share of the terrain chunks
## (ring_look.chance_per_chunk), rolled from the world seed and the chunk,
## so a ring is always where it was; never in water nor on a steep slope.
## Built while their chunk is within view_m of you, freed beyond.
##
## The fae: sit inside a ring (crouched and still: the game has no sit
## action yet, fae.json sitting) for rings.sit_seconds_min and, if it is
## their hour (bands: day fae while the sun is up, night fae while it is
## down and the moon lit enough), three small earth fairies come: no
## cloak, glowing, each with a small light, wings beating, shedding
## glowing pixel specks. How close they come and how long they stay is
## the ring's hidden trust (trust: one more each time they come, kept in
## the world's save, never shown): at first a flicker far off, at last
## close round you. Stand up or walk off while they are out and they
## scatter. Once a sitting: sit again for them to come again.
##
## The gifts (§EO.5: a free warm light for a while, leading you to a
## hidden lair door, scattering if rushed) are not built: gift_light and
## lead_to_lair are stubs that read fae.json gifts and return false.

static var F: Dictionary = Tuning.table("fae")
## The checks: the band ignores the sun and the moon ("" off, "any").
static var force_band := ""
## The checks: arrivals and departures at once.
static var instant := false
## The walkabout's frames: the fae out stay out (as if you sat on, still).
static var hold := false

## Rolled rings dropped, by why (the checks read it).
static var dropped := {"wet": 0, "steep": 0}
## How far out rings are built (m).
const VIEW_M := 320.0
const ARRIVE_S := 1.6
const LEAVE_S := 1.2

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var sky: SkySystem
var _root: Node3D
## chunk key -> ring spec ({} none)
var _specs := {}
## ring id -> its node
var rings := {}
var _timer := 0.0
## The ring you are sitting in now ("" none), and for how long (s).
var sit_ring := ""
var sit_t := 0.0
var _came_this_sit := false
## The fae out now: {ring, node, figs: [Node3D], t, stay, r, leaving, lt, trust}
var visit := {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	_root = Node3D.new()
	_root.name = "FaeRings"
	world.world_root.add_child(_root)


# --- Rings ----------------------------------------------------------------------

static func ring_look() -> Dictionary:
	return F.get("ring_look", {})


## The ring in a chunk (key, middle `cd`), or {} for none.
static func spec_for(seed_value: int, key: Vector3i, cd: Vector3, ch: ChunkManager) -> Dictionary:
	var L := ring_look()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, key, "fairy_ring"])
	if rng.randf() >= float(L.get("chance_per_chunk", 0.12)):
		return {}
	var rr: Array = L.get("radius_m", [1.4, 2.6])
	var radius := rng.randf_range(float(rr[0]), float(rr[1]))
	var d := CreatureSpawner._offset(cd, rng.randf() * TAU, rng.randf_range(0.0, TerrainChunk.CHUNK_M * 0.4))
	# Dry, and near flat across the ring.
	var g0 := ch.ground_height(d)
	if ch.water_level_at(d) > g0 - 0.05:
		dropped.wet += 1
		return {}
	var rise := 0.0
	for k in 4:
		var e := CreatureSpawner._offset(d, k * PI * 0.5, radius)
		if ch.water_level_at(e) > ch.ground_height(e) - 0.05:
			dropped.wet += 1
			return {}
		rise = maxf(rise, absf(ch.ground_height(e) - g0))
	if rad_to_deg(atan(rise / radius)) > float(L.get("max_slope_deg", 18.0)):
		dropped.steep += 1
		return {}
	var mm: Array = L.get("mushrooms", [11, 19])
	var caps: Array = L.get("cap_colours", ["#C8B08A"])
	var bands: Dictionary = F.get("bands", {})
	return {"id": "%d_%d_%d" % [key.x, key.y, key.z], "dir": d, "radius": radius,
		"n": rng.randi_range(int(mm[0]), int(mm[1])), "cap": Color(str(caps[rng.randi() % caps.size()])),
		"band": "night" if rng.randf() < float(bands.get("night_share", 0.5)) else "day", "seed": rng.randi()}


## Build ring `s` under `parent`: one mesh of its mushrooms, its frame's
## +Y the ground's up at its middle.
static func build_ring(parent: Node3D, s: Dictionary, w: Node, ch: ChunkManager) -> Node3D:
	var L := ring_look()
	var d: Vector3 = s.dir
	var n := Node3D.new()
	n.name = "FairyRing"
	parent.add_child(n)
	var at: Vector3 = w.to_scene(d, PlanetConst.RADIUS_M + ch.ground_height(d))
	n.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), at)
	var inv := n.global_transform.affine_inverse()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed)
	var hh: Array = L.get("height_m", [0.06, 0.14])
	var b := Workshop.Build.new()
	var stem := Color(str(L.get("stem_colour", "#D8D0BC")))
	var gill := Color(str(L.get("gill_colour", "#7A6A58")))
	var count := int(s.n)
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var r := float(s.radius) * rng.randf_range(0.92, 1.08)
		var md := CreatureSpawner._offset(d, a, r)
		var p: Vector3 = inv * w.to_scene(md, PlanetConst.RADIUS_M + ch.ground_height(md))
		Mushroom.add(b, p, Vector3.UP, rng.randf_range(float(hh[0]), float(hh[1])), (s.cap as Color).darkened(rng.randf_range(0.0, 0.12)), stem, gill, rng)
		# Now and then a little one beside it.
		if rng.randf() < 0.35:
			Mushroom.add(b, p + Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)), Vector3.UP, float(hh[0]) * 0.7, s.cap, stem, gill, rng)
	n.add_child(b.node("Mushrooms"))
	n.set_meta("spec", s)
	n.set_meta("tris", b.tris())
	return n


func _refresh() -> void:
	var pd: Vector3 = world.dir_of(player.global_position)
	var seed_value := int(world.planet.terrain.world_seed)
	var want := {}
	for key in chunks.chunks:
		var c: TerrainChunk = chunks.chunks[key]
		if CubeSphere.surface_distance_m(c.center_dir, pd) > VIEW_M + TerrainChunk.CHUNK_M:
			continue
		if not _specs.has(key):
			_specs[key] = spec_for(seed_value, key, c.center_dir, chunks)
		var s: Dictionary = _specs[key]
		if s.is_empty() or CubeSphere.surface_distance_m(s.dir, pd) > VIEW_M:
			continue
		want[s.id] = s
	for id in rings.keys():
		if not want.has(id) and not (not visit.is_empty() and visit.ring == id):
			(rings[id] as Node).queue_free()
			rings.erase(id)
	for id in want:
		if not rings.has(id):
			rings[id] = build_ring(_root, want[id], world, chunks)


# --- Sitting, trust, bands ---------------------------------------------------------

## The ring you are inside ({} none).
func ring_at(pos: Vector3) -> Dictionary:
	var pd: Vector3 = world.dir_of(pos)
	var inside := float(ring_look().get("sit_inside", 0.9))
	for id in rings:
		var s: Dictionary = (rings[id] as Node).get_meta("spec")
		if CubeSphere.surface_distance_m(s.dir, pd) <= float(s.radius) * inside:
			return s
	return {}


## Sitting: crouched and still (fae.json sitting).
func sitting() -> bool:
	var still := float((F.get("sitting", {}) as Dictionary).get("still_mps", 0.3))
	return player.crouching and player.velocity.length() < still


static func trust_of(id: String) -> int:
	return int(((WorldSave.data.get("fae_trust", {}) as Dictionary).get(id, {}) as Dictionary).get("t", 0))


## One more trust at ring `id`, at most once every grows_every_game_h.
static func grow_trust(id: String, days: float) -> void:
	var T: Dictionary = F.get("trust", {})
	var all: Dictionary = WorldSave.data.get("fae_trust", {})
	var r: Dictionary = all.get(id, {"t": 0, "d": -1.0e9})
	if days - float(r.get("d", -1.0e9)) < float(T.get("grows_every_game_h", 2.0)) / 24.0:
		return
	r["t"] = mini(int(r.get("t", 0)) + 1, int(T.get("max", 5)))
	r["d"] = days
	all[id] = r
	WorldSave.data["fae_trust"] = all
	WorldSave.mark_dirty()


## Is it ring `s`'s fae's hour? Day fae while the sun is up here; night
## fae while it is down and the moon lit at least night_moon_min_lit (when
## the moon's phase sets the band).
func band_open(s: Dictionary) -> bool:
	if force_band == "any":
		return true
	var up: Vector3 = player.up
	var day := sky != null and sky.sun_dir.dot(up) > 0.0
	if str(s.band) == "day":
		return day
	if day:
		return false
	var rings_d: Dictionary = F.get("rings", {})
	if bool(rings_d.get("moon_phase_sets_band", true)):
		return Astro.moon_illumination(world.days) >= float((F.get("bands", {}) as Dictionary).get("night_moon_min_lit", 0.25))
	return true


func _process(delta: float) -> void:
	if world == null or player == null or chunks == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_refresh()
	var s := ring_at(player.global_position)
	var in_sit := not s.is_empty() and sitting()
	if in_sit and str(s.id) == sit_ring:
		sit_t += delta
	else:
		sit_ring = str(s.id) if in_sit else ""
		sit_t = 0.0
		_came_this_sit = false
	if visit.is_empty():
		if in_sit and not _came_this_sit and sit_t >= float((F.get("rings", {}) as Dictionary).get("sit_seconds_min", 10)) and band_open(s):
			_came_this_sit = true
			come(s)
	else:
		# Rushed: you stood or walked off while they were out.
		if not hold and not bool(visit.leaving) and (not in_sit or str(s.id) != str(visit.ring)):
			_leave(true)
		_fly(delta)


# --- The fae ------------------------------------------------------------------------

static func fae_look() -> Dictionary:
	return F.get("fae_look", {})


## The fae come to ring `s` (its trust before this visit sets how close
## and how long), and the ring's trust grows.
func come(s: Dictionary) -> void:
	var T: Dictionary = F.get("trust", {})
	var tr := trust_of(str(s.id))
	var k := clampf(float(tr) / maxf(float(T.get("max", 5)), 1.0), 0.0, 1.0)
	var ss: Array = T.get("stay_s", [4.0, 45.0])
	var ring: Node3D = rings.get(s.id)
	if ring == null:
		return
	var node := Node3D.new()
	node.name = "Fae"
	ring.add_child(node)
	var figs: Array = []
	for i in int((F.get("fae", {}) as Dictionary).get("count", 3)):
		figs.append(fairy(node, str(s.band), i))
	visit = {"ring": s.id, "node": node, "figs": figs, "t": 0.0, "stay": lerpf(float(ss[0]), float(ss[1]), k),
		"r": lerpf(float(T.get("far_m", 9.0)), float(T.get("near_m", 1.2)), k), "leaving": false, "lt": 0.0, "trust": tr,
		"a0": randf() * TAU, "scatter": false}
	grow_trust(str(s.id), world.days)
	_fly(0.0)


func _leave(scatter: bool) -> void:
	if visit.is_empty() or bool(visit.leaving):
		return
	visit.leaving = true
	visit.scatter = scatter
	visit.lt = 0.0


## Where the fae are this frame: arriving from out past the ring, circling
## at the trust's distance (bobbing, wings beating), then away; scattered,
## they dart off fast.
func _fly(delta: float) -> void:
	var L := fae_look()
	visit.t = float(visit.t) + delta
	if bool(visit.leaving):
		visit.lt = float(visit.lt) + delta * (2.5 if bool(visit.scatter) else 1.0)
	elif float(visit.t) >= float(visit.stay) and not hold:
		_leave(false)
	var arrive := 1.0 if instant else clampf(float(visit.t) / ARRIVE_S, 0.0, 1.0)
	var gone := 1.0 if instant and bool(visit.leaving) else clampf(float(visit.lt) / LEAVE_S, 0.0, 1.0)
	if gone >= 1.0:
		(visit.node as Node).queue_free()
		visit = {}
		return
	var fh: Array = L.get("fly_height_m", [0.5, 1.5])
	var speed := float(L.get("speed_mps", 1.4))
	var r := float(visit.r)
	var figs: Array = visit.figs
	for i in figs.size():
		var f: Node3D = figs[i]
		var a := float(visit.a0) + float(visit.t) * speed / maxf(r, 0.6) + TAU * i / figs.size()
		var rr := r * (1.0 + 0.12 * sin(float(visit.t) * 1.3 + i)) + (1.0 - _ease(arrive)) * 8.0 + _ease(gone) * 10.0
		var y := lerpf(float(fh[0]), float(fh[1]), 0.5 + 0.5 * sin(float(visit.t) * 0.9 + i * 2.1)) + _ease(gone) * 3.0
		f.position = Vector3(cos(a) * rr, y, sin(a) * rr)
		var sc := _ease(arrive) * (1.0 - _ease(gone))
		f.scale = Vector3.ONE * maxf(sc, 0.001)
		var light: OmniLight3D = f.get_meta("light")
		light.light_energy = float(L.get("light_energy", 0.7)) * sc
		var hz := float(L.get("wing_hz", 14.0))
		for w in f.get_meta("wings", []):
			(w as Node3D).rotation.z = float((w as Node3D).get_meta("side")) * (0.35 + 0.55 * sin(float(visit.t) * hz * TAU))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## One small earth fairy under `parent`: no cloak; a glowing body, head
## and two pairs of wings, a small light, and its specks.
static func fairy(parent: Node3D, band: String, i: int) -> Node3D:
	var L := fae_look()
	var cols: Dictionary = L.get("colours", {})
	var col := Color(str(cols.get(band, "#E6F2A0")))
	var size := float(L.get("size_m", 0.14))
	var f := Node3D.new()
	f.name = "Fairy%d" % i
	parent.add_child(f)
	CreatureBodies.ball(f, Vector3(0.16, 0.3, 0.14) * size, Vector3(0, 0.0, 0), col, 2.0)
	CreatureBodies.ball(f, Vector3.ONE * 0.14 * size, Vector3(0, 0.4 * size, 0), col.lightened(0.2), 2.4)
	var wings: Array = []
	for side in [-1.0, 1.0]:
		for tier in 2:
			var piv := Node3D.new()
			piv.position = Vector3(side * 0.08 * size, (0.12 - tier * 0.18) * size, 0.05 * size)
			piv.set_meta("side", side)
			f.add_child(piv)
			CreatureBodies.ball(piv, Vector3(0.34 - tier * 0.1, 0.2 - tier * 0.05, 0.02) * size, Vector3(side * (0.3 - tier * 0.08) * size, 0, 0), col.lerp(Color.WHITE, 0.5), 1.0)
			wings.append(piv)
	f.set_meta("wings", wings)
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = float(L.get("light_range_m", 2.6))
	light.light_energy = float(L.get("light_energy", 0.7))
	light.shadow_enabled = false
	f.add_child(light)
	f.set_meta("light", light)
	# The specks: square glowing pixels drifting off behind it.
	var pt := CPUParticles3D.new()
	pt.name = "Specks"
	var q := QuadMesh.new()
	var sm := float(L.get("speck_m", 0.025))
	q.size = Vector2(sm, sm)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.6
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	pt.mesh = q
	pt.local_coords = false
	pt.lifetime = float(L.get("speck_life_s", 1.4))
	pt.amount = maxi(int(float(L.get("specks_per_s", 12)) * pt.lifetime), 1)
	pt.direction = Vector3.ZERO
	pt.spread = 180.0
	pt.gravity = Vector3.ZERO
	pt.initial_velocity_min = 0.03
	pt.initial_velocity_max = 0.12
	pt.damping_min = 0.05
	pt.damping_max = 0.1
	pt.scale_amount_min = 0.6
	pt.scale_amount_max = 1.0
	pt.emitting = true
	f.add_child(pt)
	f.set_meta("specks", pt)
	return f


# --- The gifts (§EO.5, not built) ---------------------------------------------------

## [NOT WIRED YET — design §EO.5] After you restore an overrun village
## (§CN), the fae may give one free warm light for a while
## (gifts.free_light, free_light_game_h). A stub: nothing calls it, and it
## gives nothing (false).
static func gift_light(_village_id: String, _days: float) -> bool:
	var g: Dictionary = F.get("gifts", {})
	return false and not g.is_empty()


## [NOT WIRED YET — design §EO.5] The fae lead you to a hidden doorway
## into a fairy lair under a restored village (gifts.lead_to_lair; rare
## and uneven: lairs_per_village), scattering if you rush or crowd them
## (scatter_if_rushed, lead_patience_s). A stub: false.
static func lead_to_lair(_village_id: String) -> bool:
	var g: Dictionary = F.get("gifts", {})
	return false and bool(g.get("lead_to_lair", false))

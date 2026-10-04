class_name WanderingFire
extends Node
## The wandering fire: thirteen in the desert (design 3 Oct §DP,
## uniques.json uniques.wandering_fire). The second one-of-a-kind and the
## first that moves: thirteen cloaked figures on the shared rig at folk
## scale, one set apart by an undyed pale robe (the_one.robe), the twelve
## in the desert folk's palette. One group per world, in the hot desert
## and thorn scrub (where.biomes); never a camp, never a ruin.
##
## They move as a number (a pure function of the clock, so the trail is
## real wherever you are): night k they sit at nights()[k], each a day's
## walk (DAY_KM, 2-6 km) from the last, turning to stay in their country.
## By day (WALK_FROM to WALK_TO local) they walk from last night's place
## to tonight's, carrying their flame as a coal in a clay pot (an ember
## carrier: no light); at dusk (LIGHT_AT) they lay a fire there from what
## the desert gives (a FireStore like any: fuel, embers, out; a safe
## circle, §BA; a coal free to take, §CQ.4) and sit round it; at dawn
## they walk on and leave the ring. Every past night's place keeps a cold
## ring of stones and ash. The log's line the first time you come near.

const WALK_FROM := 6.5
const WALK_TO := 17.5
const LIGHT_AT := 18.0
const DAY_KM := Vector2(2.5, 5.0)
const BUILD_M := 400.0
const DROP_M := 520.0
const RING_BUILD_M := 260.0
const SIT_R := 2.6
const NEAR_M := 25.0
const MAX_NIGHTS := 400

static var E: Dictionary = _load()
static var _nights := PackedVector3Array()
static var _origin := Vector3.ZERO
static var _for_seed := -1
static var _mutex := Mutex.new()
static var instance: WanderingFire = null

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var _root: Node3D
var _group: Node3D = null
var _group_state := ""
var _fire: Node3D = null
var _fire_night := -1
var _rings := {} # night index -> Node3D
var _figs: Array = []


static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/uniques.json"))
	return (parsed.get("uniques", {}) as Dictionary).get("wandering_fire", {}) if parsed is Dictionary else {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_root = Node3D.new()
	_root.name = "WanderingFire"
	world.world_root.add_child(_root)


func _exit_tree() -> void:
	if instance == self:
		instance = null


# --- The itinerary (pure) ------------------------------------------------------------

static func biomes() -> Array:
	return (E.get("where", {}) as Dictionary).get("biomes", ["HOT_DESERT", "THORN_SCRUB"])


static func in_country(map: PlanetData, d: Vector3) -> bool:
	var c := map.cell_at(d)
	if map.water[c] != PlanetData.Water.NONE or not biomes().has(BiomeTemplates.KEYS[map.biome[c]]):
		return false
	var e := map.terrain.elevation(d, true)
	# Dry ground: above the sea and out of any pool, salt lake or oasis.
	return e > 2.0 and TerrainChunk._standing_water(map, d).x < e - 0.1


## Where night `k` is (k from 0, the world's first night), or Vector3.ZERO
## when the world has no desert for them.
static func night_at(map: PlanetData, k: int) -> Vector3:
	_mutex.lock()
	if _for_seed != int(map.terrain.world_seed):
		_nights = PackedVector3Array()
		_origin = _find_origin(map)
		_for_seed = int(map.terrain.world_seed)
		if _origin != Vector3.ZERO:
			_nights.append(_origin)
	if _origin == Vector3.ZERO:
		_mutex.unlock()
		return Vector3.ZERO
	k = clampi(k, 0, MAX_NIGHTS)
	while _nights.size() <= k:
		_nights.append(_next(map, _nights.size()))
	var out := _nights[k]
	_mutex.unlock()
	return out


static func _find_origin(map: PlanetData) -> Vector3:
	var keys := biomes()
	var cells := PackedInt32Array()
	for c in map.cell_count:
		if keys.has(BiomeTemplates.KEYS[map.biome[c]]) and map.water[c] == PlanetData.Water.NONE:
			cells.append(c)
	if cells.is_empty():
		return Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "wandering_fire"])
	for t in 40:
		var p: Vector3 = map.dir[cells[rng.randi() % cells.size()]]
		# Deep in their country: the ground round it theirs too.
		var ok := in_country(map, p)
		for k in 6:
			ok = ok and in_country(map, CreatureSpawner._offset(p, k * TAU / 6.0, 6000.0))
		if ok:
			return p
	return map.dir[cells[rng.randi() % cells.size()]]


## Night k from night k-1: a day's walk on, turning to stay in their
## country; never back onto a night already passed.
static func _next(map: PlanetData, k: int) -> Vector3:
	var prev := _nights[k - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map.terrain.world_seed, "wandering_fire", k])
	var heading := rng.randf() * TAU
	if k >= 2:
		var a := _nights[k - 2]
		var t := prev - a * prev.dot(a)
		heading = atan2(t.dot(CubeSphere.east(a)), t.dot(CubeSphere.north(a))) + rng.randf_range(-0.7, 0.7)
	var dist := rng.randf_range(DAY_KM.x, DAY_KM.y) * 1000.0
	for j in 12:
		var turn := (1.0 if j % 2 == 0 else -1.0) * (j / 2) * PI / 6.0
		var p := CreatureSpawner._offset(prev, heading + turn, dist)
		if not in_country(map, p):
			continue
		var fresh := true
		for i in range(maxi(0, k - 30), k):
			if CubeSphere.surface_distance_m(_nights[i], p) < 1500.0:
				fresh = false
		if fresh:
			return p
	# Hemmed in: the far side of where they are, a little more than 2 km.
	return CreatureSpawner._offset(prev, heading + PI, DAY_KM.x * 1000.0)


## The world's day count at the group's first night, by their own clock.
static func first_day(world_node: Node) -> int:
	return int(floorf(float(world_node.START_DAYS) + CubeSphere.longitude(night_at(world_node.planet, 0)) / TAU))


## Where they are at `days`: {"state" ("walk", "arrived", "night"),
## "night" (tonight's / last night's index), "dir" (where the group
## stands), "from", "to", "bearing" (the way they walk)}; {} with no group.
static func where(world_node: Node, days: float) -> Dictionary:
	var map: PlanetData = world_node.planet
	var p0 := night_at(map, 0)
	if p0 == Vector3.ZERO:
		return {}
	var c := Astro.local_clock(days, CubeSphere.longitude(p0), CubeSphere.latitude(p0))
	var k := int(c.x) - first_day(world_node)
	var h := c.y
	var out := {}
	if h < WALK_FROM:
		out = {"state": "night", "night": maxi(k - 1, 0)}
	elif h >= LIGHT_AT:
		out = {"state": "night", "night": maxi(k, 0)}
	elif h >= WALK_TO or k <= 0:
		out = {"state": "arrived" if k > 0 else "night", "night": maxi(k, 0)}
	else:
		var a := night_at(map, k - 1)
		var b := night_at(map, k)
		var f := clampf((h - WALK_FROM) / (WALK_TO - WALK_FROM), 0.0, 1.0)
		out = {"state": "walk", "night": k, "from": a, "to": b, "dir": a.slerp(b, f)}
	if not out.has("dir"):
		out.dir = night_at(map, int(out.night))
	var n := int(out.night)
	var a2 := night_at(map, maxi(n - 1, 0))
	var b2 := night_at(map, n)
	var t := b2 - a2 * b2.dot(a2)
	out.bearing = atan2(t.dot(CubeSphere.east(a2)), t.dot(CubeSphere.north(a2))) if t.length() > 1e-9 else 0.0
	return out


## The nights already left behind at `days`: [index...] (their cold rings).
static func past_nights(world_node: Node, days: float) -> Array:
	var w := where(world_node, days)
	if w.is_empty():
		return []
	# Tonight's fire is burning (or not yet laid); every night before it
	# left its ring at dawn.
	return range(0, int(w.night))


# --- In play -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or player == null or world.planet == null:
		return
	var w := where(world, world.days)
	if w.is_empty():
		return
	var pd: Vector3 = player.surface_dir
	var gd: Vector3 = w.dir
	var near := CubeSphere.surface_distance_m(gd, pd) < BUILD_M
	# The group.
	var want_state := str(w.state)
	if near and (_group == null or _group_state != want_state):
		_free_group()
		_build_group(w)
	elif not near and _group != null and CubeSphere.surface_distance_m(gd, pd) > DROP_M:
		_free_group()
	if _group != null:
		_place_group(w, delta)
	# Their fire: at night, where they sit; out and gone at dawn.
	var night := int(w.night)
	if str(w.state) == "night" and near:
		if _fire == null or _fire_night != night:
			_free_fire()
			_fire = _make_fire(night_at(world.planet, night))
			_fire_night = night
	else:
		_free_fire()
	# The cold rings near you.
	for i in past_nights(world, world.days):
		if i == night and str(w.state) == "night":
			continue
		var rd := night_at(world.planet, i)
		var close := CubeSphere.surface_distance_m(rd, pd) < RING_BUILD_M
		if close and not _rings.has(i):
			_rings[i] = _make_ring(rd, i)
	for i in _rings.keys():
		var rn: Node3D = _rings[i]
		if not is_instance_valid(rn) or rn.global_position.distance_to(player.global_position) > RING_BUILD_M + 80.0:
			if is_instance_valid(rn):
				NodeRelease.free_later(rn)
			_rings.erase(i)
	# The log's line, once.
	if _group != null and _group.global_position.distance_to(player.global_position) < NEAR_M:
		GameLog.add_once("wandering_fire", str(E.get("log", "Thirteen sit round a fire in the sand.")), "found")


func group_node() -> Node3D:
	return _group


func fire_node() -> Node3D:
	return _fire


func ring_nodes() -> Dictionary:
	return _rings


func figures() -> Array:
	return _figs


func _ground(d: Vector3) -> Vector3:
	return world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))


func _build_group(w: Dictionary) -> void:
	_group = Node3D.new()
	_group.name = "Thirteen"
	_root.add_child(_group)
	_group_state = str(w.state)
	_figs.clear()
	var seated := _group_state == "night"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(world.planet.terrain.world_seed), "thirteen"])
	var robe: Dictionary = ((E.get("figures", {}) as Dictionary).get("the_one", {}) as Dictionary).get("robe", {})
	for i in 13:
		var main: Color
		var trim: Color
		if i == 0:
			main = Color(str(robe.get("colour", "#E8E0D0")))
			trim = Color(str(robe.get("edge", "#C9BBA6")))
		else:
			# The desert folk's palette: sand, ochre, dun, indigo.
			var pal := [Color(0.62, 0.52, 0.36), Color(0.55, 0.4, 0.26), Color(0.48, 0.43, 0.34), Color(0.3, 0.32, 0.48), Color(0.58, 0.46, 0.3)]
			main = pal[rng.randi() % pal.size()]
			trim = main.darkened(0.25)
		var b := CloakedFigure.build(rng.randf_range(1.62, 1.8), main, trim, seated)
		var fig: Node3D = b.root
		fig.name = "One" if i == 0 else "Fig%d" % i
		var holder := Node3D.new()
		holder.name = "H%d" % i
		_group.add_child(holder)
		holder.add_child(fig)
		BlobShadow.make(holder, 0.4, 0.5)
		# The ember carrier: a clay pot one of them carries by day.
		if i == 4 and not seated:
			var pot := CreatureBodies.box(holder, Vector3(0.22, 0.2, 0.22), Vector3(0.32, 0.85, -0.1), Color(0.42, 0.24, 0.14))
			pot.name = "EmberPot"
		_figs.append(holder)


func _free_group() -> void:
	if _group != null:
		NodeRelease.free_later(_group)
	_group = null
	_group_state = ""
	_figs.clear()


## Each figure's place: round the fire at night (facing it), in a loose
## file along the way by day (walking).
func _place_group(w: Dictionary, delta: float) -> void:
	var gd: Vector3 = w.dir
	var st := str(w.state)
	_group.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(gd), gd), _ground(gd))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in _figs.size():
		var h: Node3D = _figs[i]
		var fd: Vector3
		var face: Vector3
		if st == "night" or st == "arrived":
			var a := TAU * i / 13.0
			fd = CreatureSpawner._offset(gd, a, SIT_R if st == "night" else SIT_R + 1.5)
			face = _ground(gd) - _ground(fd)
		else:
			var back := 1.0 + i * 1.5
			fd = CreatureSpawner._offset(CreatureSpawner._offset(gd, float(w.bearing) + PI, back), float(w.bearing) + PI * 0.5, rng.randf_range(-0.9, 0.9))
			face = _ground(CreatureSpawner._offset(fd, float(w.bearing), 5.0)) - _ground(fd)
		var pos := _ground(fd)
		var up := fd
		face = (face - up * face.dot(up)).normalized()
		if face.length() < 0.1:
			face = CubeSphere.north(fd)
		h.global_transform = Transform3D(Basis.looking_at(face, up), pos)
		var body := h.get_child(0)
		if body != null and body.has_method("set_motion"):
			body.call("set_motion", 0.35 if st == "walk" else 0.0, delta)


func _make_fire(d: Vector3) -> Node3D:
	var fire := Campfire.build(_root, world, chunks, d, false)
	fire.global_position = _ground(d)
	fire.name = "WanderingFire"
	fire.set_meta("smoke", 1.0)
	fire.set_meta("hearth_ok", false)
	# Laid tonight from what the desert gives, lit from their coal.
	var st := FireStore.store_of(fire)
	if not st.is_empty() and not FireStore.is_lit(fire):
		var kind := FireStore.best_kind(world, d)
		st.units = []
		for i in 8:
			(st.units as Array).append([kind, FireStore.burn_min(kind)])
		st.state = "flames"
		st.embers_min = 0.0
	FireStore.apply(fire)
	return fire


func _free_fire() -> void:
	if _fire != null:
		NodeRelease.free_later(_fire)
	_fire = null
	_fire_night = -1


## A night's cold ring: a ring of stones round a patch of ash.
func _make_ring(d: Vector3, i: int) -> Node3D:
	var n := Node3D.new()
	n.name = "ColdRing%d" % i
	_root.add_child(n)
	n.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(d), d), _ground(d))
	n.set_meta("night", i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([i, "ring"])
	for k in 8:
		var a := TAU * k / 8.0 + rng.randf_range(-0.15, 0.15)
		var stone := MeshInstance3D.new()
		var size := Vector3(rng.randf_range(0.28, 0.4), rng.randf_range(0.16, 0.24), rng.randf_range(0.24, 0.34))
		stone.mesh = RuinBuilder.rock_mesh(size, rng.randi(), Color(0.5, 0.44, 0.36))
		stone.material_override = RuinBuilder.material()
		stone.position = Vector3(cos(a) * 0.7, size.y * 0.15, sin(a) * 0.7)
		n.add_child(stone)
	var ash := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.6
	cm.height = 0.04
	cm.radial_segments = 10
	ash.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.15)
	ash.material_override = mat
	ash.position = Vector3(0.0, 0.02, 0.0)
	n.add_child(ash)
	return n

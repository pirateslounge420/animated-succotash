class_name CreatureSpawner
extends Node
## Spawns creatures around the player (DESIGN.md "Creature Spawning").
## Terrain generates first, vegetation reads the terrain, then creatures
## read both: every check below looks at the actual spot (temperature in °C
## at that exact height, moisture, trees, ground cover, water), never at
## biome names.
##
## Three spawn tiers:
##   interaction   Beetles exist only once you turn over a fallen log (E
##                 within 2 m). Logs lie in forests near trees; some hide
##                 insects if the climate suits them.
##   ambient       Each species has a planet-wide jittered grid with one
##                 candidate spot per circle of `one_per_radius_m`. Spots
##                 within ACTIVE_RADIUS_M of the player whose habitat fits
##                 get a creature while its time of day lasts; it fades
##                 away when you leave. The same spot always gives the same
##                 answer, so wildlife is "always there" without simulating
##                 anything out of range.
##   long range    Mythical territories (Territories) on a coarse grid: dormant (nothing
##                 exists) far away, aware (heard, pacing, unseen) at
##                 medium range, visible close. Their calls are muffled and
##                 poorly directional far off, sharpening as you approach.
##
## Pack hunters (wolves) are tethered to dens: cave mouths on steep, cold
## slopes. Packs rest by day, patrol their territory at night, howl in
## call-and-response (pack members, then neighboring packs), and close in
## around you once they notice you, then drift home when you leave.

const ACTIVE_RADIUS_M := 140.0
const DESPAWN_RADIUS_M := 175.0
const MAX_AMBIENT := 70
const DEN_SEARCH_M := 900.0
const PACK_SPAWN_M := 420.0
const PACK_DESPAWN_M := 520.0
const AWARE_M := 1000.0
const VISIBLE_M := 220.0
const LOG_REACH_M := 2.3
const FACE_M := PlanetConst.CIRCUMFERENCE_M / 4.0

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var map: PlanetData
## Text for the on-screen prompt ("E: turn over the log"), or "".
var prompt := ""

var _root: Node3D
var _species: Array[CreatureSpecies] = []
var _ambient_ids: Array[int] = []
var _pack_ids: Array[int] = []
var _mythic_ids: Array[int] = []
var _beetle: CreatureSpecies
var _rr := 0
var _ambient := {} # Vector4i -> Creature
var _checked := {} # Vector4i -> habitat result ({} = unsuitable)
var _cooldown := {} # Vector4i -> time it may respawn
var _dens := {} # Vector4i -> den record (see _find_den)
var _den_checked := {}
var _territories := {} # Vector4i -> territory record
var _terr_checked := {}
var _logs: Array = [] # {"node", "dir", "bugs", "flipped", "chunk"}
var _bugs: Array[Creature] = []
var _calls: Array = [] # pending howls: [time, Creature or den key]
var _time := 0.0
var _slow := 0.0
var _daylight := 1.0
var _message := ""
var _message_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	map = world.planet
	_root = Node3D.new()
	_root.name = "Creatures"
	world.world_root.add_child(_root)
	_species = CreatureSpecies.all()
	for i in _species.size():
		var sp := _species[i]
		match sp.role:
			"pack":
				_pack_ids.append(i)
			"mythical":
				_mythic_ids.append(i)
			"insect":
				_beetle = sp
			_:
				if sp.spawn == "ambient":
					_ambient_ids.append(i)
	chunks.chunk_loaded.connect(_add_logs)
	chunks.chunk_unloaded.connect(_drop_logs)
	for c in chunks.chunks.values():
		_add_logs(c)


func update_creatures(delta: float, daylight: float) -> void:
	if player == null:
		return
	_time += delta
	_daylight = daylight
	var pd := player.surface_dir
	var ctx := {"player_dir": pd, "looking_at": _looked_at()}

	# One ambient species per frame (round robin), dens and territories a
	# few times a second.
	if not _ambient_ids.is_empty():
		_rr = (_rr + 1) % _ambient_ids.size()
		_refresh_ambient(_ambient_ids[_rr], pd)
	_slow -= delta
	if _slow <= 0.0:
		_slow = 0.5
		_refresh_dens(pd)
		_refresh_territories(pd)
		if _checked.size() > 30000:
			_checked.clear()

	for key in _ambient.keys():
		var c: Creature = _ambient[key]
		if not c.leaving and (c.distance_to(pd) > DESPAWN_RADIUS_M or not c.species.active_now(daylight)):
			c.leave()
		c.tick(delta, ctx)
	for b in _bugs.duplicate():
		b.tick(delta, ctx)
	_update_packs(delta, pd, ctx)
	_update_territories(delta, pd, ctx)
	_run_calls()
	_update_prompt(delta)


## Turn over (or roll back) the nearest fallen log within reach.
func interact(pos: Vector3) -> void:
	var lg := _nearest_log(pos)
	if lg.is_empty():
		return
	var node: Node3D = lg.node
	var trunk: Node3D = node.get_node("Log")
	lg.flipped = not lg.flipped
	var tw := create_tween().set_parallel(true)
	tw.tween_property(trunk, "rotation:z", PI * 0.85 if lg.flipped else 0.0, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_property(trunk, "position:x", -0.45 if lg.flipped else 0.0, 0.6)
	(node.get_node("Patch") as Node3D).visible = lg.flipped
	if not lg.flipped:
		return
	if lg.bugs and _beetle:
		var n := _rng.randi_range(6, 12)
		for i in n:
			var b := Creature.new()
			_root.add_child(b)
			var d: Vector3 = lg.dir
			var off := CubeSphere.north(d).rotated(d, _rng.randf() * TAU) * _rng.randf_range(0.0, 0.4)
			b.setup(_beetle, world, chunks, self, (d + off / PlanetConst.RADIUS_M).normalized(), _rng.randi())
			b.heading = off.normalized() if off.length() > 0.01 else b.heading
			b.finished.connect(func(c: Creature) -> void:
				_bugs.erase(c)
				c.queue_free())
			_bugs.append(b)
		lg.bugs = false
		_say("Beetles scatter from under the log")
	else:
		_say("Nothing under this one")


func cooldown(c: Creature) -> void:
	for key in _ambient:
		if _ambient[key] == c:
			_cooldown[key] = _time + 120.0


## A tree to perch in near `d`, from the loaded chunk's canopy/emergent
## trees. Skips `exclude`; if `away_from` is set, prefers trees far from
## it. Returns {"dir", "base", "height"} or {}.
func host_near(d: Vector3, radius: float, exclude: Dictionary, away_from: Vector3) -> Dictionary:
	var chunk := chunks.chunk_at(d)
	if chunk == null:
		return {}
	var best := {}
	var best_score := -INF
	for h in chunk.hosts:
		var hd: Vector3 = h[0]
		var dist := CubeSphere.surface_distance_m(d, hd)
		if dist > radius or h[2] < 3.0:
			continue
		if not exclude.is_empty() and hd.is_equal_approx(exclude.dir):
			continue
		var score := _rng.randf()
		if away_from != Vector3.ZERO:
			score += CubeSphere.surface_distance_m(hd, away_from) * 0.1
		if score > best_score:
			best_score = score
			best = {"dir": hd, "base": h[1], "height": h[2]}
	return best


# --- Ambient wildlife ----------------------------------------------------------

func _refresh_ambient(sp_idx: int, pd: Vector3) -> void:
	var sp := _species[sp_idx]
	if not sp.active_now(_daylight) or _ambient.size() >= MAX_AMBIENT:
		return
	var cell := sp.one_per_radius_m * sqrt(PI)
	var n := _cells_per_face(cell)
	for c in _cells_around(pd, ACTIVE_RADIUS_M, cell):
		var key := Vector4i(sp_idx, c.x, c.y, c.z)
		if _ambient.has(key) or _cooldown.get(key, -1.0) > _time:
			continue
		var d := _cell_point(c, n, sp_idx)
		if CubeSphere.surface_distance_m(d, pd) > ACTIVE_RADIUS_M or chunks.chunk_at(d) == null:
			continue
		if not _checked.has(key):
			_checked[key] = _habitat(sp, d, key)
		var info: Dictionary = _checked[key]
		if info.is_empty():
			continue
		var cr := Creature.new()
		_root.add_child(cr)
		cr.setup(sp, world, chunks, self, info.dir, hash(key))
		if info.has("host"):
			cr.set_host(info.host)
		cr.finished.connect(_on_ambient_finished.bind(key))
		_ambient[key] = cr


func _on_ambient_finished(c: Creature, key: Vector4i) -> void:
	if _ambient.get(key) == c:
		_ambient.erase(key)
	c.queue_free()


## Habitat check at a candidate spot. Returns {"dir", "host"?} or {}.
func _habitat(sp: CreatureSpecies, d: Vector3, key: Vector4i) -> Dictionary:
	var chunk := chunks.chunk_at(d)
	var h := chunk.height_at(d)
	var w := chunk.water_at(d)
	var t := _temp_at(d, h)
	var m := map.sample(map.moisture, d)
	if not sp.climate_ok(t, m, h):
		return {}
	match sp.role:
		"ground", "swarm":
			if w > h + 0.05:
				return {}
			var cover := float(sp.needs.get("ground_cover", 0.0))
			if cover > 0.0 and _ground_cover(t, m) < cover:
				return {}
			if sp.needs.has("water_within_m") and not _water_within(d, float(sp.needs.water_within_m)):
				return {}
			return {"dir": d}
		"canopy":
			var host := host_near(d, 16.0, {}, Vector3.ZERO)
			if host.is_empty():
				return {}
			return {"dir": host.dir, "host": host}
		"water_edge":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(key)
			var open: bool = sp.needs.get("open_water", false)
			for i in 20:
				var p := _offset(d, rng.randf() * TAU, sqrt(rng.randf()) * 35.0)
				var depth := chunks.water_level_at(p) - chunks.ground_height(p)
				var fits := depth > 0.6 if open else (depth > 0.05 and depth < 0.45)
				if fits and (not sp.needs.get("salt", false) or _salty(p)):
					return {"dir": p}
			return {}
	return {}


func _temp_at(d: Vector3, h: float) -> float:
	return map.sample(map.temp_c, d) + (map.sample(map.elevation, d) - h) * PlanetConst.LAPSE_RATE_C_PER_M


## Rough undergrowth density 0-1 from the same climate the plants read.
static func _ground_cover(t: float, m: float) -> float:
	return clampf((m - 0.12) / 0.45, 0.0, 1.0) * smoothstep(-8.0, 4.0, t)


func _water_within(d: Vector3, r: float) -> bool:
	if map.sample(map.water_dist_km, d) * 1000.0 < r * 0.5:
		return true
	for ring in [0.35, 0.7, 1.0]:
		for k in 10:
			var p := _offset(d, k * TAU / 10.0 + ring, r * ring)
			if chunks.water_level_at(p) > chunks.ground_height(p) + 0.05:
				return true
	return false


func _salty(d: Vector3) -> bool:
	var c := map.cell_at(d)
	if map.water[c] == PlanetData.Water.OCEAN or map.salinity[c] != PlanetData.Salinity.FRESH:
		return true
	# Sea water inside the chunk (coastline finer than the blueprint).
	return chunks.ground_height(d) < PlanetConst.SEA_LEVEL_M and absf(chunks.water_level_at(d) - PlanetConst.SEA_LEVEL_M) < 0.05


# --- Planet-wide spawn grids ---------------------------------------------------

static func _cells_per_face(cell_m: float) -> int:
	return maxi(1, int(round(FACE_M / cell_m)))


## Grid cells (face, i, j) within `radius` of `d`, crossing cube-face edges.
static func _cells_around(d: Vector3, radius: float, cell_m: float) -> Array:
	var n := _cells_per_face(cell_m)
	var out := {}
	var step := cell_m * 0.5
	var reach := radius + cell_m
	var k := int(ceil(reach / step))
	var e := CubeSphere.east(d)
	var no := CubeSphere.north(d)
	for a in range(-k, k + 1):
		for b in range(-k, k + 1):
			var off := Vector2(a, b) * step
			if off.length() > reach:
				continue
			var p := (d + (e * off.x + no * off.y) / PlanetConst.RADIUS_M).normalized()
			var f := CubeSphere.face_of(p)
			var uv := CubeSphere.face_uv(f, p)
			out[Vector3i(f, clampi(int((uv.x + 1.0) * 0.5 * n), 0, n - 1), clampi(int((uv.y + 1.0) * 0.5 * n), 0, n - 1))] = true
	return out.keys()


## The one jittered candidate spot of a grid cell.
static func _cell_point(c: Vector3i, n: int, salt: int) -> Vector3:
	var h := hash(Vector4i(salt, c.x, c.y, c.z))
	var jx := float(h & 0xffff) / 65535.0
	var jy := float((h >> 16) & 0xffff) / 65535.0
	var u := -1.0 + 2.0 * (c.y + 0.1 + 0.8 * jx) / n
	var v := -1.0 + 2.0 * (c.z + 0.1 + 0.8 * jy) / n
	return CubeSphere.to_dir(c.x, u, v)


## The point `meters` away from `d` on bearing `angle` (0 north, PI/2 east).
static func _offset(d: Vector3, angle: float, meters: float) -> Vector3:
	var t := CubeSphere.north(d) * cos(angle) + CubeSphere.east(d) * sin(angle)
	return (d + t * meters / PlanetConst.RADIUS_M).normalized()


# --- Pack hunters --------------------------------------------------------------

func _refresh_dens(pd: Vector3) -> void:
	for i in _pack_ids:
		var sp := _species[i]
		var cell := sp.one_per_radius_m * sqrt(PI)
		var n := _cells_per_face(cell)
		for c in _cells_around(pd, DEN_SEARCH_M, cell):
			var key := Vector4i(i, c.x, c.y, c.z)
			if _dens.has(key):
				continue
			if not _den_checked.has(key):
				_den_checked[key] = _find_den(sp, _cell_point(c, n, 9000 + i), key)
			var den: Dictionary = _den_checked[key]
			if den.is_empty() or CubeSphere.surface_distance_m(den.dir, pd) > DEN_SEARCH_M:
				continue
			den = den.duplicate()
			den.wolves = []
			den.state = "home"
			den.howl_t = randf_range(5.0, 25.0)
			den.patrol_t = 0.0
			den.keep_away = 24.0
			den.prop = _den_prop(den)
			_dens[key] = den
	for key in _dens.keys():
		var den: Dictionary = _dens[key]
		if CubeSphere.surface_distance_m(den.dir, pd) > DEN_SEARCH_M + 150.0:
			for w in den.wolves:
				w.queue_free()
			den.prop.queue_free()
			_dens.erase(key)


## A cave mouth on a steep, cold slope within the cell, or {}.
func _find_den(sp: CreatureSpecies, center: Vector3, key: Vector4i) -> Dictionary:
	if map.sample(map.temp_c, center) > sp.temp_c.y + 15.0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var best := {}
	var best_slope := 0.45 # about 24 degrees
	for i in 24:
		var p := _offset(center, rng.randf() * TAU, sqrt(rng.randf()) * 200.0)
		var e := map.terrain.elevation(p, true)
		if e < 3.0:
			continue
		var t := _temp_at(p, e)
		if t < sp.temp_c.x or t > sp.temp_c.y:
			continue
		var ea := CubeSphere.east(p)
		var no := CubeSphere.north(p)
		var gx := (map.terrain.elevation(_offset(p, PI * 0.5, 10.0), true) - map.terrain.elevation(_offset(p, -PI * 0.5, 10.0), true)) / 20.0
		var gy := (map.terrain.elevation(_offset(p, 0.0, 10.0), true) - map.terrain.elevation(_offset(p, PI, 10.0), true)) / 20.0
		var slope := Vector2(gx, gy).length()
		if slope > best_slope:
			best_slope = slope
			var downhill := -(ea * gx + no * gy)
			best = {"species": sp, "dir": p, "facing": downhill.normalized(), "seed": hash(key)}
	return best


func _den_prop(den: Dictionary) -> Node3D:
	var d: Vector3 = den.dir
	var root := Node3D.new()
	root.name = "WolfDen"
	_root.add_child(root)
	# Stand on the slope itself (tilted to the ground), bedded in a little.
	var ea := CubeSphere.east(d)
	var no := CubeSphere.north(d)
	var gx := (chunks.ground_height(_offset(d, PI * 0.5, 3.0)) - chunks.ground_height(_offset(d, -PI * 0.5, 3.0))) / 6.0
	var gy := (chunks.ground_height(_offset(d, 0.0, 3.0)) - chunks.ground_height(_offset(d, PI, 3.0))) / 6.0
	var normal := (d - ea * gx - no * gy).normalized()
	root.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d) - 0.6)
	var fwd: Vector3 = den.facing
	fwd = fwd - normal * fwd.dot(normal)
	if fwd.length() < 0.1:
		fwd = no - normal * no.dot(normal)
	root.global_basis = Basis.looking_at(fwd.normalized(), normal)
	var rock := Color(0.42, 0.42, 0.45)
	# Two boulders and a lintel slab framing a dark hole in the slope.
	var stones := [[Vector3(1.9, 2.8, 2.2), Vector3(-1.7, 1.0, 0.2), Vector3(0, 0, 0.12), rock, false],
		[Vector3(1.8, 2.5, 2.2), Vector3(1.7, 0.9, 0.3), Vector3(0, 0, -0.15), rock.darkened(0.1), false],
		[Vector3(5.0, 1.1, 2.4), Vector3(0, 2.5, 0.4), Vector3(0.1, 0, 0), rock.lightened(0.05), true]]
	for k in stones.size():
		var st: Array = stones[k]
		var mi := MeshInstance3D.new()
		mi.mesh = RuinBuilder.rock_mesh(st[0], den.seed + k, st[3], st[4])
		mi.material_override = RuinBuilder.material()
		mi.position = st[1]
		mi.rotation = st[2]
		root.add_child(mi)
	CreatureBodies.ball(root, Vector3(1.6, 1.3, 1.2), Vector3(0, 0.9, 0.6), Color(0.03, 0.03, 0.05))
	CreatureBodies.box(root, Vector3(4.6, 0.25, 1.4), Vector3(0, 3.05, 0.4), Color(0.92, 0.94, 0.98))
	var voice := AudioStreamPlayer3D.new()
	voice.stream = SoundSynth.stream("howl", den.seed)
	voice.unit_size = 40.0
	voice.max_distance = 1500.0
	voice.position = Vector3(0, 1.5, -1.0)
	root.add_child(voice)
	den.voice = voice
	return root


func _update_packs(delta: float, pd: Vector3, ctx: Dictionary) -> void:
	for key in _dens:
		var den: Dictionary = _dens[key]
		var sp: CreatureSpecies = den.species
		var home_dist := CubeSphere.surface_distance_m(den.dir, pd)
		var territory := sp.territory_m
		var notice := float(sp.pack.get("notice_m", 60.0))
		_fidelity(den.voice, home_dist)

		# Spawn the pack when you're near enough to meet it.
		if den.wolves.is_empty() and home_dist < PACK_SPAWN_M:
			var rng := RandomNumberGenerator.new()
			rng.seed = den.seed
			var size: Array = sp.pack.get("size", [3, 5])
			for i in rng.randi_range(int(size[0]), int(size[1])):
				var w := Creature.new()
				_root.add_child(w)
				w.setup(sp, world, chunks, self, _offset(den.dir, rng.randf() * TAU, rng.randf_range(4.0, 14.0)), den.seed + i)
				w.mode = "rest"
				w.goal = w.dir
				w.ring_offset = i * TAU / 5.0
				den.wolves.append(w)
		elif not den.wolves.is_empty() and home_dist > PACK_DESPAWN_M:
			for w in den.wolves:
				w.queue_free()
			den.wolves = []
			den.state = "home"

		var wolves: Array = den.wolves
		var nearest := INF
		for w in wolves:
			nearest = minf(nearest, w.distance_to(pd))
			_fidelity(w.voice, w.distance_to(pd))

		# Howling: the pack calls, members answer, neighbors answer back.
		den.howl_t -= delta
		if den.howl_t <= 0.0:
			den.howl_t = randf_range(30.0, 70.0) if _daylight < 0.3 else randf_range(100.0, 220.0)
			_howl(key)

		match den.state:
			"home":
				den.patrol_t -= delta
				if den.patrol_t <= 0.0:
					den.patrol_t = randf_range(10.0, 25.0)
					var night := _daylight < 0.3
					var center: Vector3 = den.dir if not night else _offset(den.dir, randf() * TAU, randf_range(0.2, 0.9) * territory)
					for w in wolves:
						w.goal = _offset(center, randf() * TAU, randf_range(2.0, 9.0))
						w.goal_speed = sp.speed_mps * (0.35 if night else 0.2)
						w.mode = "go"
				if nearest < notice or home_dist < notice * 0.6:
					den.state = "close_in"
					den.keep_away = 26.0
					_howl(key)
			"close_in":
				den.keep_away = maxf(9.0, den.keep_away - delta * 0.8)
				for i in wolves.size():
					var w: Creature = wolves[i]
					# Spread around you, each wolf in its own slot.
					var slot := CubeSphere.north(pd).rotated(pd, i * TAU / wolves.size() + _time * 0.03)
					w.goal = (pd + slot * den.keep_away / PlanetConst.RADIUS_M).normalized()
					w.goal_speed = sp.speed_mps * 0.55
					w.mode = "go"
				if home_dist > territory * 1.6 or nearest > notice * 2.2:
					den.state = "retreat"
					for w in wolves:
						w.goal = _offset(den.dir, randf() * TAU, randf_range(3.0, 10.0))
						w.goal_speed = sp.speed_mps * 0.5
						w.mode = "go"
			"retreat":
				var all_home := true
				for w in wolves:
					all_home = all_home and w.distance_to(den.dir) < 16.0
				if all_home:
					den.state = "home"
					den.patrol_t = randf_range(20.0, 40.0)
		for w in wolves:
			w.tick(delta, ctx)


func _howl(key: Vector4i) -> void:
	var den: Dictionary = _dens[key]
	var wolves: Array = den.wolves
	if wolves.is_empty():
		den.voice.play()
	else:
		wolves[0].say()
		for i in range(1, wolves.size()):
			_calls.append([_time + randf_range(1.2, 4.5) * i * 0.6, wolves[i]])
	# Neighboring packs answer.
	for other in _dens:
		if other != key and CubeSphere.surface_distance_m(_dens[other].dir, den.dir) < 2500.0 and randf() < 0.7:
			_calls.append([_time + randf_range(5.0, 10.0), other])


func _run_calls() -> void:
	var i := 0
	while i < _calls.size():
		var c: Array = _calls[i]
		if c[0] > _time:
			i += 1
			continue
		_calls.remove_at(i)
		var target = c[1]
		if target is Vector4i:
			if _dens.has(target):
				var den: Dictionary = _dens[target]
				if den.wolves.is_empty():
					den.voice.play()
				else:
					den.wolves[0].say()
		elif is_instance_valid(target):
			target.say()


# --- Mythical creatures --------------------------------------------------------

func _refresh_territories(pd: Vector3) -> void:
	if _mythic_ids.is_empty():
		return
	for c in _cells_around(pd, AWARE_M, Territories.CELL_M):
		var key := Vector4i(-1, c.x, c.y, c.z)
		if _territories.has(key):
			continue
		if not _terr_checked.has(key):
			_terr_checked[key] = Territories.find(map, c)
		var t: Dictionary = _terr_checked[key]
		if t.is_empty() or CubeSphere.surface_distance_m(t.dir, pd) > AWARE_M:
			continue
		t = t.duplicate()
		t.state = "dormant"
		t.creature = null
		t.camp = null
		t.call_t = randf_range(3.0, 10.0)
		t.pace_t = 0.0
		t.hidden_until = 0.0
		_territories[key] = t
	for key in _territories.keys():
		var t: Dictionary = _territories[key]
		if CubeSphere.surface_distance_m(t.dir, pd) > AWARE_M + 200.0:
			_set_dormant(t)
			_territories.erase(key)


func _update_territories(delta: float, pd: Vector3, ctx: Dictionary) -> void:
	for key in _territories:
		var t: Dictionary = _territories[key]
		var sp: CreatureSpecies = t.species
		var dist := CubeSphere.surface_distance_m(t.dir, pd)
		var want := "dormant"
		if sp.active_now(_daylight) and dist < AWARE_M and _time >= t.hidden_until:
			want = "visible" if dist < VISIBLE_M else "aware"
		if want == "dormant":
			_set_dormant(t)
			continue
		if t.creature == null or not is_instance_valid(t.creature):
			_wake(t)
		var cr: Creature = t.creature
		if t.camp:
			_flicker(t.camp)
		_fidelity(cr.voice, cr.distance_to(pd))
		t.call_t -= delta
		if t.call_t <= 0.0:
			t.call_t = randf_range(12.0, 35.0)
			cr.say()
		if want != t.state:
			t.state = want
			cr.set_visible_body(want == "visible")
		var to_player := cr.distance_to(pd)
		if want == "aware":
			_pace(t, cr, delta)
		else:
			match sp.temperament:
				"hostile":
					# Stalks at a distance, freezes when looked at, and is
					# gone if you get close.
					cr.mode = "stalk"
					cr.keep_away_m = 38.0
					if to_player < 12.0:
						_set_dormant(t)
						t.hidden_until = _time + 40.0
						continue
				"friendly":
					if to_player < 45.0:
						cr.mode = "go"
						cr.goal = _offset(pd, _bearing(pd, cr.dir), 3.5)
						cr.goal_speed = sp.speed_mps * 0.6
					else:
						_rest_or_pace(t, cr, delta)
				_:
					if sp.shape == "wisp" and to_player < 15.0:
						# Drifts ahead, leading you on.
						cr.mode = "go"
						cr.goal = _offset(cr.dir, _bearing(cr.dir, pd) + PI, 10.0)
						cr.goal_speed = sp.speed_mps
					elif to_player < 70.0:
						cr.mode = "watch"
					else:
						_rest_or_pace(t, cr, delta)
		cr.tick(delta, ctx)


func _wake(t: Dictionary) -> void:
	var sp: CreatureSpecies = t.species
	var cr := Creature.new()
	_root.add_child(cr)
	var camp_dir: Vector3 = t.dir
	cr.setup(sp, world, chunks, self, _offset(camp_dir, randf() * TAU, 3.0 if sp.campfire else 10.0), t.seed)
	cr.home = camp_dir
	cr.mode = "rest"
	cr.goal = cr.dir
	cr.set_visible_body(false)
	cr.finished.connect(func(c: Creature) -> void: c.queue_free())
	t.creature = cr
	t.state = "aware"
	if sp.campfire and t.camp == null:
		t.camp = _campfire(camp_dir, sp.accent)


func _set_dormant(t: Dictionary) -> void:
	if t.creature and is_instance_valid(t.creature):
		t.creature.queue_free()
	t.creature = null
	if t.camp:
		t.camp.queue_free()
		t.camp = null
	t.state = "dormant"


func _pace(t: Dictionary, cr: Creature, delta: float) -> void:
	t.pace_t -= delta
	if t.pace_t <= 0.0:
		t.pace_t = randf_range(12.0, 30.0)
		cr.mode = "go"
		cr.goal = _offset(t.dir, randf() * TAU, randf() * t.species.territory_m * 0.5)
		cr.goal_speed = t.species.speed_mps * 0.4


## Folk with a campfire sit by it; others pace their territory.
func _rest_or_pace(t: Dictionary, cr: Creature, delta: float) -> void:
	if t.species.campfire:
		cr.mode = "go"
		cr.goal = _offset(t.dir, 0.8, 2.2)
		cr.goal_speed = t.species.speed_mps * 0.5
	else:
		_pace(t, cr, delta)


## Bearing angle (around `from`, measured from north) toward `to`.
static func _bearing(from: Vector3, to: Vector3) -> float:
	var t := to - from * from.dot(to)
	return atan2(t.dot(CubeSphere.east(from)), t.dot(CubeSphere.north(from)))


## Campfire: stones, logs, flames and a warm light (DESIGN.md: the warm
## "pop" against the blue night).
func _campfire(d: Vector3, warm: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	_root.add_child(root)
	root.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	root.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	for i in 8:
		var a := i * TAU / 8.0
		CreatureBodies.box(root, Vector3(0.28, 0.18, 0.22), Vector3(cos(a) * 0.62, 0.09, sin(a) * 0.62), Color(0.4, 0.4, 0.42)).rotation.y = a
	for i in 3:
		var l := CreatureBodies.cone(root, 0.06, 0.06, 0.9, Vector3(0, 0.12, 0), Color(0.3, 0.2, 0.12))
		l.rotation = Vector3(PI * 0.5, i * TAU / 3.0, 0)
	var flames := Node3D.new()
	flames.name = "Flames"
	flames.position = Vector3(0, 0.15, 0)
	root.add_child(flames)
	CreatureBodies.cone(flames, 0.28, 0.0, 0.7, Vector3(0, 0.35, 0), Color(1.0, 0.45, 0.12), 6.0)
	CreatureBodies.cone(flames, 0.16, 0.0, 0.5, Vector3(0.06, 0.28, 0.04), Color(1.0, 0.85, 0.35), 8.0)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = warm.lerp(Color(1.0, 0.55, 0.2), 0.5)
	light.light_energy = 3.2
	light.omni_range = 16.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	# A log to sit on.
	var seat := CreatureBodies.cone(root, 0.18, 0.18, 1.5, Vector3(0, 0.18, 2.0), Color(0.36, 0.25, 0.16))
	seat.rotation.z = PI * 0.5
	return root


func _flicker(camp: Node3D) -> void:
	var f := _time * 9.0
	var k := 0.85 + 0.1 * sin(f) + 0.07 * sin(f * 2.3 + 1.0) + 0.05 * sin(f * 5.1)
	(camp.get_node("Flames") as Node3D).scale = Vector3(1.0, k, 1.0)
	(camp.get_node("Light") as OmniLight3D).light_energy = 3.2 * k


## Long-range calls: muffled and nearly mono far away, clear and properly
## positioned close by.
static func _fidelity(p: AudioStreamPlayer3D, dist: float) -> void:
	if p == null:
		return
	var near := clampf(1.0 - (dist - 60.0) / 700.0, 0.0, 1.0)
	p.attenuation_filter_cutoff_hz = lerpf(700.0, 20000.0, near * near)
	p.panning_strength = lerpf(0.05, 1.0, near)


## Hostile mythicals the camera is pointed at (they freeze while watched).
func _looked_at() -> Dictionary:
	var out := {}
	var cam := player.camera()
	if cam == null:
		return out
	var fwd := -cam.global_basis.z
	for key in _territories:
		var cr = _territories[key].creature
		if cr != null and is_instance_valid(cr) and cr.species.temperament == "hostile":
			var to: Vector3 = cr.global_position + cr.global_basis.y * cr.species.size_m * 0.6 - cam.global_position
			if to.length() < 250.0 and to.normalized().dot(fwd) > 0.93:
				out[cr] = true
	return out


# --- Fallen logs (interaction tier) --------------------------------------------

func _add_logs(chunk: TerrainChunk) -> void:
	if chunk.hosts.size() < 4:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(chunk.face, chunk.ci, chunk.cj)) + 17
	var count := mini(1 + chunk.hosts.size() / 10, 4)
	for i in count:
		var h: Array = chunk.hosts[rng.randi() % chunk.hosts.size()]
		var d := _offset(h[0], rng.randf() * TAU, rng.randf_range(2.5, 6.0))
		if chunk.key_at(d) != Vector3i(chunk.face, chunk.ci, chunk.cj):
			continue
		var gh := chunk.height_at(d)
		if chunk.water_at(d) > gh + 0.02:
			continue
		var node := _log_node(rng)
		chunk.add_child(node)
		node.position = world.to_scene_relative(d, PlanetConst.RADIUS_M + gh + 0.12, chunk.position)
		var up := d
		var along := CubeSphere.north(d).rotated(d, rng.randf() * TAU)
		# The log's local Z runs along its length, Y up.
		node.basis = Basis(up.cross(along).normalized(), up, along) * Basis.IDENTITY
		var bugs := false
		if _beetle:
			var t := _temp_at(d, gh)
			bugs = _beetle.climate_ok(t, map.sample(map.moisture, d), gh) and rng.randf() < 0.75
		_logs.append({"node": node, "dir": d, "bugs": bugs, "flipped": false, "chunk": chunk})


func _drop_logs(chunk: TerrainChunk) -> void:
	_logs = _logs.filter(func(l: Dictionary) -> bool: return l.chunk != chunk)


func _log_node(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "FallenLog"
	var length := rng.randf_range(1.4, 2.4)
	var bark := Color(0.34, 0.25, 0.17).lerp(Color(0.3, 0.3, 0.26), rng.randf())
	var log_node := Node3D.new()
	log_node.name = "Log"
	root.add_child(log_node)
	var trunk := CreatureBodies.cone(log_node, 0.16, 0.14, length, Vector3.ZERO, bark)
	trunk.rotation.x = PI * 0.5
	var moss := CreatureBodies.box(log_node, Vector3(0.18, 0.05, length * 0.7), Vector3(0, 0.14, 0.1), Color(0.3, 0.5, 0.2))
	moss.rotation.z = 0.2
	CreatureBodies.box(log_node, Vector3(0.12, 0.12, 0.3), Vector3(0.14, 0.02, -length * 0.3), bark.darkened(0.2)).rotation.y = 0.8
	# Dark damp soil, revealed when the log is rolled away.
	var patch := CreatureBodies.box(root, Vector3(0.45, 0.02, length * 0.9), Vector3(0, -0.12, 0), Color(0.16, 0.12, 0.09))
	patch.name = "Patch"
	patch.visible = false
	return root


func _nearest_log(pos: Vector3) -> Dictionary:
	var best := {}
	var best_d := LOG_REACH_M
	for l in _logs:
		var node: Node3D = l.node
		if not is_instance_valid(node):
			continue
		var d := node.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = l
	return best


func _say(text: String) -> void:
	_message = text
	_message_t = 3.0


func _update_prompt(delta: float) -> void:
	if _message_t > 0.0:
		_message_t -= delta
		prompt = _message
		return
	var lg := _nearest_log(player.global_position)
	if lg.is_empty():
		prompt = ""
	else:
		prompt = "E: roll the log back" if lg.flipped else "E: turn over the log"

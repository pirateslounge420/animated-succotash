class_name Landmarks
extends Node
## Set pieces and magical places around the player:
##
## * Ruins (Ruins, RuinBuilder) are built out to BUILD_M, well past the
##   terrain chunks, so their silhouettes rise out of the fog bands ahead
##   and draw the wanderer toward them. Geometry is computed on worker
##   threads and dropped again beyond DROP_M.
## * The bioluminescent night palette (MagicSites): the nearest glowing
##   sites go to every world shader (Look: look_sites), which light up
##   water, moss and plant tips there after dark; a small pool of teal and
##   cobalt OmniLights makes the glow actually light the scene; and when
##   the player stands inside a site at night, SkySystem and PostGrade
##   darken the moonlight and push contrast so it reads like neon against
##   black.

const BUILD_M := 2600.0
const DROP_M := 3000.0
const SITE_RADIUS_M := 1600.0
const LIGHT_COUNT := 6
const LIGHT_REACH_M := 260.0
const TEAL := Color(0.1, 1.0, 0.85)
const COBALT := Color(0.2, 0.4, 1.0)

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var sky: SkySystem
var post: PostGrade
var map: PlanetData
## 0-1: how deep the player stands inside a glowing site.
var magic := 0.0
## Name of the ruin the player is at, or "".
var nearby := ""

var _root: Node3D
var _ruin_cells := {} # Vector3i -> site dict or {}
var _ruins := {} # Vector3i -> Node3D
var _pending := {} # Vector3i -> task id
var _done: Array = []
var _mutex := Mutex.new()
var _sites: Array = []
var _lights: Array[OmniLight3D] = []
var _anchors: Array = [] # [scene position, color]
var _timer := 0.0
var _glow := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer, p_sky: SkySystem, p_post: PostGrade) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	sky = p_sky
	post = p_post
	map = world.planet
	_root = Node3D.new()
	_root.name = "Landmarks"
	world.world_root.add_child(_root)
	for i in LIGHT_COUNT:
		var l := OmniLight3D.new()
		l.omni_range = 18.0
		l.omni_attenuation = 1.3
		l.shadow_enabled = false
		l.visible = false
		_root.add_child(l)
		_lights.append(l)


func _exit_tree() -> void:
	for task in _pending.values():
		WorkerThreadPool.wait_for_task_completion(task)


func update_landmarks(delta: float, daylight: float) -> void:
	var pd := player.surface_dir
	_glow = 1.0 - smoothstep(0.08, 0.55, daylight)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh_ruins(pd)
		_refresh_sites(pd)
	_attach_ruins()

	# How deep inside a site the player is (ponds count a bit less).
	magic = 0.0
	nearby = ""
	for s in _sites:
		var d := CubeSphere.surface_distance_m(s.dir, pd)
		var r: float = s.radius_m
		magic = maxf(magic, smoothstep(r * 1.1, r * 0.45, d) * (1.0 if s.kind >= 1.0 else 0.7))
		if s.type == "ruin" and d < r:
			nearby = s.get("name", "Ruins")
	sky.magic = magic
	post.set_magic(magic)

	for i in _lights.size():
		var l := _lights[i]
		if i < _anchors.size() and _glow > 0.02:
			l.visible = true
			l.light_color = _anchors[i][1]
			l.light_energy = 0.9 * _glow * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.0017 + i * 1.7))
		else:
			l.visible = false


# --- Ruins ---------------------------------------------------------------------

func _refresh_ruins(pd: Vector3) -> void:
	for c in CreatureSpawner._cells_around(pd, BUILD_M, Ruins.CELL_M):
		if not _ruin_cells.has(c):
			_ruin_cells[c] = Ruins.find(map, c)
		var site: Dictionary = _ruin_cells[c]
		if site.is_empty() or _ruins.has(c) or _pending.has(c):
			continue
		if CubeSphere.surface_distance_m(site.dir, pd) < BUILD_M:
			_pending[c] = WorkerThreadPool.add_task(_compute.bind(c, site))
	for c in _ruins.keys():
		var site: Dictionary = _ruin_cells[c]
		if CubeSphere.surface_distance_m(site.dir, pd) > DROP_M:
			NodeRelease.free_later(_ruins[c])
			_ruins.erase(c)


func _compute(c: Vector3i, site: Dictionary) -> void:
	var data := RuinBuilder.compute(map, site)
	_mutex.lock()
	_done.append([c, data])
	_mutex.unlock()


func _attach_ruins() -> void:
	_mutex.lock()
	var item = _done.pop_front() if not _done.is_empty() else null
	_mutex.unlock()
	if item == null:
		return
	var c: Vector3i = item[0]
	WorkerThreadPool.wait_for_task_completion(_pending[c])
	_pending.erase(c)
	if _ruins.has(c):
		return
	var node := RuinBuilder.make_node(item[1], world)
	_root.add_child(node)
	node.global_transform = RuinBuilder.placement(item[1], world)
	_ruins[c] = node


## The ruins built right now: grid cell -> node (meta "site",
## "shelters", "camp_spot").
func built_ruins() -> Dictionary:
	return _ruins


## Inside a camp shelter (a tepee or under a lean-to, RuinBuilder._camp)
## at scene position `pos`? Keeps the rain off.
func sheltered_at(pos: Vector3) -> bool:
	for c in _ruins:
		var node: Node3D = _ruins[c]
		var shelters: Array = node.get_meta("shelters", [])
		if shelters.is_empty():
			continue
		var local := node.global_transform.affine_inverse() * pos
		for sh in shelters:
			var center: Vector3 = sh[0]
			var r: float = sh[1]
			var h: float = sh[2]
			if Vector2(local.x - center.x, local.z - center.z).length() < r * 0.85 and local.y > center.y - 1.0 and local.y < center.y + h * 0.8:
				return true
	return false


## Ruins (from the cache) within `radius` m of `d`.
func ruins_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in CreatureSpawner._cells_around(d, radius, Ruins.CELL_M):
		if not _ruin_cells.has(c):
			_ruin_cells[c] = Ruins.find(map, c)
		var r: Dictionary = _ruin_cells[c]
		if not r.is_empty() and CubeSphere.surface_distance_m(r.dir, d) < radius + r.footprint_m:
			out.append(r)
	return out


# --- Glowing sites -------------------------------------------------------------

func _refresh_sites(pd: Vector3) -> void:
	_sites = MagicSites.near(map, pd, SITE_RADIUS_M, ruins_near(pd, SITE_RADIUS_M))
	for s in _sites:
		s.dist = CubeSphere.surface_distance_m(s.dir, pd) - s.radius_m
		if s.type == "ruin":
			for r in ruins_near(s.dir, 1.0):
				if r.dir.is_equal_approx(s.dir):
					s.name = Ruins.KIND_NAMES[r.kind]
	_sites.sort_custom(func(a, b): return a.dist < b.dist)
	var kinds := PackedFloat32Array()
	var count := mini(_sites.size(), 8)
	var vecs := PackedVector4Array()
	for i in 8:
		if i < count:
			var s: Dictionary = _sites[i]
			var p: Vector3 = world.to_scene(s.dir, PlanetConst.RADIUS_M + chunks.ground_height(s.dir))
			vecs.append(Vector4(p.x, p.y, p.z, s.radius_m))
			kinds.append(s.kind)
		else:
			vecs.append(Vector4.ZERO)
			kinds.append(0.0)
	Look.apply({"look_sites": vecs, "look_site_kind": kinds, "look_site_count": count})
	_place_lights(pd)


## Light anchors near the player: over glowing water at ponds, around the
## stones at ruins, among the trees at mythical places.
func _place_lights(pd: Vector3) -> void:
	var cands: Array = []
	for s in _sites:
		if s.dist > LIGHT_REACH_M:
			continue
		match s.type:
			"ruin", "mythical":
				var ring: float = s.radius_m * 0.35
				for k in 5:
					var d := CreatureSpawner._offset(s.dir, k * TAU / 5.0 + 0.4, ring if k > 0 else 0.0)
					cands.append([d, chunks.ground_height(d) + 1.2])
			"pond":
				# Grid of points on the water within reach of the player.
				var step := 45.0
				var f := CubeSphere.face_of(pd)
				var q := step / (CreatureSpawner.FACE_M * 0.5) # grid step in face coordinates
				var uv := CubeSphere.face_uv(f, pd)
				for gx in range(-4, 5):
					for gy in range(-4, 5):
						# A grid fixed to the planet, so lights stay put as you walk.
						var d := CubeSphere.to_dir(f, (round(uv.x / q) + gx) * q, (round(uv.y / q) + gy) * q)
						if CubeSphere.surface_distance_m(d, s.dir) > s.radius_m:
							continue
						var water := chunks.water_level_at(d)
						if water > chunks.ground_height(d) + 0.15:
							cands.append([d, water + 0.7])
	cands.sort_custom(func(a, b): return CubeSphere.surface_distance_m(a[0], pd) < CubeSphere.surface_distance_m(b[0], pd))
	_anchors = []
	for i in mini(cands.size(), LIGHT_COUNT):
		var c: Array = cands[i]
		_lights[i].global_position = world.to_scene(c[0], PlanetConst.RADIUS_M + c[1])
		_anchors.append([c[0], TEAL if i % 2 == 0 else COBALT])

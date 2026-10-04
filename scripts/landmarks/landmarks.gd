class_name Landmarks
extends Node
## Set pieces and magical places around the player:
##
## * Ruins (Ruins, RuinBuilder) are built out to BUILD_M, well past the
##   terrain chunks, so their silhouettes rise out of the fog bands ahead
##   and draw the wanderer toward them. Geometry is computed on worker
##   threads and dropped again beyond DROP_M.
## * Nests (design 1 Oct §CK, Nests, NestBuilder): the cave mouths,
##   grottos, cenote lips, overhangs, cairn lanes and springs, built within
##   NEST_BUILD_M the same way, with an old camp's remains (§BQ signatures,
##   RuinMarks) laid at the hearth of a nest that holds them.
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
## Nests are built nearer than ruins: their pieces are small.
const NEST_BUILD_M := 900.0
const NEST_DROP_M := 1100.0
var _ruin_cells := {} # Vector3i -> site dict or {}
var _nests := {} # nest key -> Node3D
## The sacred fig's figure and stones (design 1 Oct §CL), built near it.
var _fig_node: Node3D = null
const FIG_BUILD_M := 600.0
var _nest_sites := {} # nest key -> nest dict
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
		_refresh_nests(pd)
		_refresh_fig(pd)
		_refresh_sites(pd)
	_attach_ruins()
	_build_ruin_collision(pd)
	_tick_columns(delta)

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


func _compute(c, site: Dictionary) -> void:
	var data := NestBuilder.compute_nest(map, site) if c is String else RuinBuilder.compute(map, site)
	_mutex.lock()
	_done.append([c, data])
	_mutex.unlock()


# --- The sacred fig (§CL) ----------------------------------------------------

func _refresh_fig(pd: Vector3) -> void:
	var f := Uniques.sacred_fig(map)
	if f.is_empty():
		return
	var dist := CubeSphere.surface_distance_m(f.dir, pd)
	if _fig_node == null and dist < FIG_BUILD_M:
		_fig_node = Uniques.build(world, chunks, f)
		_root.add_child(_fig_node)
		# Placed again after entering the tree (the floating origin).
		var fd: Vector3 = f.figure
		_fig_node.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(fd), fd), world.to_scene(fd, PlanetConst.RADIUS_M + chunks.ground_height(fd)))
	elif _fig_node != null and dist > FIG_BUILD_M + 200.0:
		NodeRelease.free_later(_fig_node)
		_fig_node = null
	if dist < 25.0:
		GameLog.add_once("sacred_fig", str(Uniques.fig_entry().get("log", "Someone sits beneath the old fig, very still.")), "found")


## The sacred fig's node (the figure and stones) if built.
func fig_node() -> Node3D:
	return _fig_node


# --- Nests (§CK) -------------------------------------------------------------

func _refresh_nests(pd: Vector3) -> void:
	for n in Nests.near(pd, NEST_BUILD_M):
		var key: String = n.key
		_nest_sites[key] = n
		if _nests.has(key) or _pending.has(key):
			continue
		if CubeSphere.surface_distance_m(n.dir, pd) < NEST_BUILD_M:
			_pending[key] = WorkerThreadPool.add_task(_compute.bind(key, n))
	for key in _nests.keys():
		var n: Dictionary = _nest_sites[key]
		if CubeSphere.surface_distance_m(n.dir, pd) > NEST_DROP_M:
			NodeRelease.free_later(_nests[key])
			_nests.erase(key)


## A nest's node attached: its remains, if it holds an old camp's (the
## §BQ signatures of the people who lived there, laid at the hearth spot),
## and vines over its rock (§CE).
func _attach_nest(key: String, data: Dictionary) -> void:
	var node := NestBuilder.make_nest(data, world)
	_root.add_child(node)
	node.global_transform = RuinBuilder.placement(data, world)
	_nests[key] = node
	var nest: Dictionary = data.nest
	if str(nest.get("state", "")) == "remains":
		var sigs := Nests.remains_signatures(nest)
		if not sigs.is_empty():
			var at := {"dir": nest.hearth, "seed": nest.seed, "footprint_m": 4.0}
			# Laid round the hearth spot, within a few paces of it.
			RuinMarks.dress(node, at, world, chunks, {"ruin": {"signatures": sigs}}, -1, 3.5)
	_dress_vines(node, Vector3i.ZERO, data, key)


## The nests built right now: key -> node (meta "nest").
func built_nests() -> Dictionary:
	return _nests


# --- The columns (design 3 Oct §DX) ------------------------------------------------

## The causeway's log line, once (§BC: nothing says whether anyone made it).
const CAUSEWAY_LINE := "A road of stone steps goes down into the sea."
const CAUSEWAY_LINE_M := 30.0
## The swell's period at the sea cave (s, [min, max]): one boom a swell.
const SWELL_S := Vector2(7.0, 11.0)
## The sea cave's boom (tools): {"key", "dist", "max_m", "booms", "heard"}.
var boom_state := {}
var _swell_rng := RandomNumberGenerator.new()


## Each frame: the causeway's line when you reach it; the sea cave's boom
## with the swell, a source at the cave's back (§BG) that plays only while
## you are within its max_distance (audio.json sea_cave_boom), so it is
## heard from the clifftop before the way down is found; and the night
## roster asleep in its den by day (§CH), out by night.
func _tick_columns(delta: float) -> void:
	var pp := player.global_position
	var pd := player.surface_dir
	var day := sky != null and sky.sun_elevation_deg > -4.0
	for key in _nests:
		var node: Node3D = _nests[key]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var n: Dictionary = node.get_meta("nest", {})
		if str(n.get("kind", "")) != "columnar_basalt":
			continue
		if str(n.get("variant", "")) == "" and CubeSphere.surface_distance_m(n.dir, pd) < CAUSEWAY_LINE_M:
			GameLog.add_once("causeway", CAUSEWAY_LINE, "found")
		if node.has_meta("boom"):
			_tick_boom(node, n, pp, delta)
		if node.has_meta("den"):
			_den_sleeper(node, n, day)


func _tick_boom(node: Node3D, n: Dictionary, pp: Vector3, delta: float) -> void:
	var boom := node.get_node_or_null("Boom") as AudioStreamPlayer3D
	if boom == null:
		boom = Audio3D.make("sea_cave_boom", node, "Boom")
		boom.position = node.get_meta("boom")
		node.set_meta("boom_t", _swell_rng.randf_range(0.5, SWELL_S.x))
		node.set_meta("booms", 0)
	var t := float(node.get_meta("boom_t", 1.0)) - delta
	var dist := boom.global_position.distance_to(pp)
	var heard := dist < boom.max_distance
	if t <= 0.0:
		t = _swell_rng.randf_range(SWELL_S.x, SWELL_S.y)
		if heard:
			boom.stream = SoundSynth.stream("boom", _swell_rng.randi())
			boom.pitch_scale = _swell_rng.randf_range(0.9, 1.05)
			boom.play()
			node.set_meta("booms", int(node.get_meta("booms", 0)) + 1)
	node.set_meta("boom_t", t)
	boom_state = {"key": str(n.key), "dist": dist, "max_m": boom.max_distance, "booms": int(node.get_meta("booms", 0)), "heard": heard}


## The den's sleeper: by day a creature of the night roster lies on the
## ledge at the cave's back; by night it is out (the spawner's own).
func _den_sleeper(node: Node3D, n: Dictionary, day: bool) -> void:
	var sl := node.get_node_or_null("DenSleeper") as Node3D
	if day and sl == null:
		var who := Overrun.roster_holder(map, n.dir, str(n.key))
		sl = Overrun.body_for(str(who.get("creature", "")))
		sl.name = "DenSleeper"
		sl.set_meta("creature", str(who.get("creature", "")))
		node.add_child(sl)
		sl.position = node.get_meta("den")
		sl.rotation.y = PI * 0.5
	elif not day and sl != null:
		sl.queue_free()


func _attach_ruins() -> void:
	_mutex.lock()
	var item = _done.pop_front() if not _done.is_empty() else null
	_mutex.unlock()
	if item == null:
		return
	if item[0] is String:
		var nk: String = item[0]
		if _pending.has(nk):
			WorkerThreadPool.wait_for_task_completion(_pending[nk])
			_pending.erase(nk)
		if not _nests.has(nk):
			_attach_nest(nk, item[1])
		return
	var c: Vector3i = item[0]
	if _pending.has(c):
		WorkerThreadPool.wait_for_task_completion(_pending[c])
		_pending.erase(c)
	if _ruins.has(c):
		return
	var node := RuinBuilder.make_node(item[1], world)
	_root.add_child(node)
	node.global_transform = RuinBuilder.placement(item[1], world)
	_ruins[c] = node
	# Ruins remember (design 30 Sept §BQ): the people who lived here left
	# their craft's signatures; a squatting camp's ladder makes them
	# legible (RuinMarks).
	var site: Dictionary = node.get_meta("site", {})
	if not site.is_empty():
		var pid := Peoples.pick(map, chunks.rivers, site.dir, "ruin")
		var rung := -1
		if CampSim.instance != null:
			var st := CampSim.instance.state_of("ruin:%s" % str(c))
			if not st.is_empty() and str(st.get("state", "")) == "living":
				rung = int(st.get("rung", 0))
		RuinMarks.dress(node, site, world, chunks, Peoples.get_people(pid), rung)
		node.set_meta("marks_rung", rung)
	_dress_vines(node, c, item[1])
	Overgrowth.dress(node, item[1])


## A vine species over the ruin's walls and heaps (§CE), hung from the ivy
## strands' tops (RuinBuilder's vine_anchors), and draped over its tumbled
## boulders (boulder_anchors, surfaces.boulder): as much as the climate
## and the ruin's age allow. A camp living in it cuts them back as its ladder
## clears the heap (legibility: rung 1 half, rung 2 bare); an abandoned
## camp is taken back as the forest takes it (CampSim.reclaim).
func _dress_vines(node: Node3D, c: Vector3i, data: Dictionary, nest_key := "") -> void:
	var site: Dictionary = data.get("site", {})
	var anchors: Array = data.get("vine_anchors", [])
	var rocks: Array = data.get("boulder_anchors", [])
	if site.is_empty() or (anchors.is_empty() and rocks.is_empty()):
		return
	var d: Vector3 = site.dir
	var t := map.sample(map.temp_c, d)
	var m := map.sample(map.moisture, d)
	var h := map.terrain.elevation(d, true)
	var sp := VineCover.species_at(d, map.biome[map.cell_at(d)], t, m, h, map.soil_at(d))
	if sp == null:
		return
	var full := float((VineCover.D.get("ruins", {}) as Dictionary).get("full_after_years", 40.0))
	var age := full
	var legibility := 0
	if CampSim.instance != null:
		var st := CampSim.instance.state_of(nest_key if nest_key != "" else "ruin:%s" % str(c))
		if not st.is_empty():
			if str(st.get("state", "")) == "living":
				var rung := int(st.get("rung", 0))
				legibility = 0 if rung < 1 else (1 if rung < 2 else 2)
			else:
				age = full * CampSim.instance.reclaim(st)
	# A ruin's overgrowth (design 3 Oct §DI) chose its hanging places.
	if data.has("og") and nest_key == "":
		Overgrowth.dress_vines(map, node, data, age, legibility)
		return
	VineCover.ruin_patches(node, anchors, sp, m, t, age, legibility)
	VineCover.ruin_patches(node, rocks, sp, m, t, age, legibility, "boulder")


## Build the ruin around surface direction `d` now, if there is one and
## it isn't built yet (not on a worker, one a frame): you wake by its fire
## after a death (Camps.wake_fire), so it has to be there when you do.
func build_ruin_at(d: Vector3) -> void:
	for c in CreatureSpawner._cells_around(d, Ruins.CELL_M, Ruins.CELL_M):
		if not _ruin_cells.has(c):
			_ruin_cells[c] = Ruins.find(map, c)
		var site: Dictionary = _ruin_cells[c]
		if site.is_empty() or _ruins.has(c):
			continue
		if CubeSphere.surface_distance_m(site.dir, d) > float(site.footprint_m) + 60.0:
			continue
		var data = null
		if _pending.has(c):
			# Already on a worker: wait for it and take its result.
			WorkerThreadPool.wait_for_task_completion(_pending[c])
			_pending.erase(c)
			_mutex.lock()
			for k in _done.size():
				if _done[k][0] == c:
					data = _done[k][1]
					_done.remove_at(k)
					break
			_mutex.unlock()
		if data == null:
			data = RuinBuilder.compute(map, site)
		var node := RuinBuilder.make_node(data, world)
		_root.add_child(node)
		node.global_transform = RuinBuilder.placement(data, world)
		_ruins[c] = node
		_dress_vines(node, c, data)
		Overgrowth.dress(node, data)


## Collision for ruins the player is near (COLLIDE_M), a piece a frame
## (RuinBuilder.build_collision_part).
const COLLIDE_M := 400.0


func _build_ruin_collision(pd: Vector3) -> void:
	for group in [_ruins, _nests]:
		for c in group:
			var node: Node3D = group[c]
			if not RuinBuilder.wants_collision(node):
				continue
			var site: Dictionary = node.get_meta("site")
			if CubeSphere.surface_distance_m(site.dir, pd) < COLLIDE_M + float(site.footprint_m):
				RuinBuilder.build_collision_part(node)
				return


## The ruins built right now: grid cell -> node (meta "site",
## "shelters", "camp_spot").
func built_ruins() -> Dictionary:
	return _ruins


## Inside a camp shelter (a tepee or under a lean-to, RuinBuilder._camp)
## at scene position `pos`? Keeps the rain off.
func sheltered_at(pos: Vector3) -> bool:
	for node: Node3D in _ruins.values() + _nests.values():
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
					s.name = Ruins.site_name(r)
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
				var q := step / (CreatureSpawner.face_m() * 0.5) # grid step in face coordinates
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

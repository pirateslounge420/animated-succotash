class_name LongWalls
extends Node
## The long walls' stretches (design 3 Oct §DS.1, Monuments' long_wall
## sites): the first linear monument besides the aqueduct, streamed like
## the roads, not one mesh. The gate (its tower, gateway, stair and delve)
## is the site Ruins.find gives and Landmarks builds; every other stretch,
## tower to tower (site.towers), is a piece of its own (piece_site()),
## computed by RuinBuilder on a worker when you come within BUILD_M of it
## and freed past DROP_M, its collision built when you're near.
## Plants keep off the wall's line (clearings_near).

const BUILD_M := 650.0
const DROP_M := 900.0
const COLLIDE_M := 300.0
const SAMPLE_M := 40.0

static var instance: LongWalls = null

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var _root: Node3D
var _pieces := {} # key -> Node3D
var _pending := {} # key -> task id
var _done: Array = []
var _mutex := Mutex.new()
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_root = Node3D.new()
	_root.name = "LongWalls"
	world.world_root.add_child(_root)


func _exit_tree() -> void:
	for k in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.clear()
	if instance == self:
		instance = null


## The stretches of a wall: [[m0, m1]...], tower to tower.
static func spans(site: Dictionary) -> Array:
	var tw: Array = site.towers
	var out: Array = []
	for i in tw.size() - 1:
		out.append([float(tw[i]), float(tw[i + 1])])
	return out


## Stretch `k` of `site` as a site of its own for RuinBuilder: its middle,
## its frame along its chord, the wall's measurements.
static func piece_site(site: Dictionary, k: int) -> Dictionary:
	var sp: Array = spans(site)[k]
	var line: PackedVector3Array = site.line
	var m0 := float(sp[0])
	var m1 := float(sp[1])
	var mid := RoadNetwork.point_at(line, (m0 + m1) * 0.5)
	var a := RoadNetwork.point_at(line, m0)
	var b := RoadNetwork.point_at(line, m1)
	var t := b - a
	t = t - mid * t.dot(mid)
	var bearing := atan2(t.dot(CubeSphere.east(mid)), t.dot(CubeSphere.north(mid))) if t.length() > 1e-9 else 0.0
	var out := {"dir": mid, "kind": Ruins.Kind.LONG_WALL, "seed": hash([site.seed, "piece", k]), "style": "long_wall", "piece": [m0, m1], "piece_k": k,
		"heading": bearing - PI * 0.5, "footprint_m": (m1 - m0) * 0.5 + 10.0, "clear": []}
	for key in ["line", "wall_h", "thick_m", "breaks", "fallen_towers", "gate_m", "gate_span", "towers", "len_m"]:
		out[key] = site[key]
	return out


## The nearest the stretch m0..m1 of `site` comes to `d` (sampled).
static func span_distance(site: Dictionary, m0: float, m1: float, d: Vector3) -> float:
	var line: PackedVector3Array = site.line
	var best := INF
	var m := m0
	while true:
		best = minf(best, CubeSphere.surface_distance_m(RoadNetwork.point_at(line, m), d))
		if m >= m1:
			break
		m = minf(m + SAMPLE_M, m1)
	return best


## Plants kept off the walls near `d` (VegetationPlacer's clearings):
## [[dir, radius]...] along the line where the wall stands, and round
## each tower.
static func clearings_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	for site in Monuments.all_sites(map, "long_wall"):
		if CubeSphere.surface_distance_m(site.dir, d) > float(site.len_m) + radius:
			continue
		var line: PackedVector3Array = site.line
		var r := float(site.thick_m) * 0.5 + 1.5
		var m := 0.0
		var total := float(site.len_m)
		while m <= total:
			var p := RoadNetwork.point_at(line, m)
			var dist := CubeSphere.surface_distance_m(p, d)
			if dist < radius + r:
				var gap := false
				for b in site.breaks:
					if str(b[2]) == "gap" and m >= float(b[0]) and m <= float(b[1]):
						gap = true
						break
				if not gap:
					out.append([p, r])
			# Far from here: stride ahead.
			m += 6.0 if dist < radius + 60.0 else maxf(6.0, dist - radius - 30.0)
		for tm in site.towers:
			var tp := RoadNetwork.point_at(line, float(tm))
			if CubeSphere.surface_distance_m(tp, d) < radius + 8.0:
				out.append([tp, 7.0])
	return out


func _process(delta: float) -> void:
	if world == null or player == null or world.planet == null:
		return
	_attach()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var map: PlanetData = world.planet
	var pd: Vector3 = player.surface_dir
	for site in Monuments.all_sites(map, "long_wall"):
		if CubeSphere.surface_distance_m(site.dir, pd) > float(site.len_m) + DROP_M:
			continue
		var sps := spans(site)
		for k in sps.size():
			var key := "%d:%d" % [int(site.seed), k]
			var dist := span_distance(site, float(sps[k][0]), float(sps[k][1]), pd)
			if dist < BUILD_M and not _pieces.has(key) and not _pending.has(key):
				var ps := piece_site(site, k)
				_pending[key] = WorkerThreadPool.add_task(_compute.bind(key, map, ps))
			elif dist > DROP_M and _pieces.has(key):
				NodeRelease.free_later(_pieces[key])
				_pieces.erase(key)
	# Collision for the stretches you're near, a part a tick.
	for key in _pieces:
		var node: Node3D = _pieces[key]
		if not RuinBuilder.wants_collision(node):
			continue
		var s: Dictionary = node.get_meta("site")
		if span_distance(s, float(s.piece[0]), float(s.piece[1]), pd) < COLLIDE_M:
			RuinBuilder.build_collision_part(node)
			break


func _compute(key: String, map: PlanetData, ps: Dictionary) -> void:
	var data := RuinBuilder.compute(map, ps)
	_mutex.lock()
	_done.append([key, data])
	_mutex.unlock()


func _attach() -> void:
	_mutex.lock()
	var item = _done.pop_front() if not _done.is_empty() else null
	_mutex.unlock()
	if item == null:
		return
	var key: String = item[0]
	if _pending.has(key):
		WorkerThreadPool.wait_for_task_completion(_pending[key])
		_pending.erase(key)
	if _pieces.has(key):
		return
	var node := RuinBuilder.make_node(item[1], world)
	node.name = "LongWall_" + key.replace(":", "_")
	_root.add_child(node)
	node.global_transform = RuinBuilder.placement(item[1], world)
	_pieces[key] = node


## The stretches built right now: key -> node (meta "site").
func built() -> Dictionary:
	return _pieces


## Build every stretch within `radius` of `d` now (the tools).
func build_now(d: Vector3, radius: float) -> void:
	var map: PlanetData = world.planet
	for site in Monuments.all_sites(map, "long_wall"):
		var sps := spans(site)
		for k in sps.size():
			var key := "%d:%d" % [int(site.seed), k]
			if _pieces.has(key) or span_distance(site, float(sps[k][0]), float(sps[k][1]), d) > radius:
				continue
			if _pending.has(key):
				WorkerThreadPool.wait_for_task_completion(_pending[key])
				_pending.erase(key)
				continue
			_compute(key, map, piece_site(site, k))
	while true:
		_mutex.lock()
		var empty := _done.is_empty()
		_mutex.unlock()
		if empty:
			break
		_attach()

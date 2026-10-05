class_name VillageLife
extends Node
## The villages in play (design 5 Oct §EE; Villages, VillagePlan,
## VillageBuilder). Each is built on a worker when you come within build_m
## of it and freed past drop_m (villages.json prototype). While it stands:
##   - its hearths are OldHearths' (kind "village"): cold, relit only by a
##     carried flame and kindling (§CN, §CQ: fire is carried, never made);
##     they burn and go out by FireStore's rules like any old hearth;
##   - a house whose hearth burns lights its windows; the village's lit
##     fraction (VillageWarmth) warms the frame round it, hearth by hearth
##     (§EE.1);
##   - a square whose hearth is cold is choked with brambles along its
##     walls and has nowhere to put your back (§EG.4); lit, the brambles
##     burn back and its benches stand there again.
## The plan and the build follow from the site; only the fires are saved
## (WorldSave "old_hearths").

static var P: Dictionary = Tuning.section("villages", "prototype")
static var instance: VillageLife = null

var world: Node
var chunks: ChunkManager
var player: Node3D
var _root: Node3D
var _built := {} # id -> Node3D
var _pending := {} # id -> task id
var _done: Array = []
var _mutex := Mutex.new()
var _timer := 0.0
var _sync_t := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	_root = Node3D.new()
	_root.name = "Villages"
	world.world_root.add_child(_root)


func _exit_tree() -> void:
	for k in _pending:
		WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.clear()
	for id in _built:
		VillageWarmth.forget(id)
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if world == null or player == null or world.planet == null:
		return
	_attach()
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_stream()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.25
		sync()


func _stream() -> void:
	var map: PlanetData = world.planet
	var pd: Vector3 = world.dir_of(player.global_position)
	var build_m := float(P.get("build_m", 900.0))
	var drop_m := float(P.get("drop_m", 1200.0))
	for s in Villages.near(map, pd, build_m):
		var id := str(s.id)
		if not _built.has(id) and not _pending.has(id):
			_pending[id] = WorkerThreadPool.add_task(_compute.bind(id, map, s))
	for id in _built.keys():
		var node: Node3D = _built[id]
		var s: Dictionary = node.get_meta("site")
		if CubeSphere.surface_distance_m(s.dir, pd) > drop_m:
			VillageWarmth.forget(id)
			NodeRelease.free_later(node)
			_built.erase(id)


func _compute(id: String, map: PlanetData, s: Dictionary) -> void:
	var data := VillageBuilder.compute(map, s)
	_mutex.lock()
	_done.append([id, data])
	_mutex.unlock()


func _attach() -> void:
	_mutex.lock()
	var item = _done.pop_front() if not _done.is_empty() else null
	_mutex.unlock()
	if item == null:
		return
	var id: String = item[0]
	if _pending.has(id):
		WorkerThreadPool.wait_for_task_completion(_pending[id])
		_pending.erase(id)
	if _built.has(id):
		return
	var data: Dictionary = item[1]
	var node := VillageBuilder.make_node(data, world)
	_root.add_child(node)
	node.global_transform = VillageBuilder.placement(data, world)
	_built[id] = node
	_register(node, data)
	sync()


## Hand the village to VillageWarmth: its middle, its reach, its hearths.
func _register(node: Node3D, data: Dictionary) -> void:
	var s: Dictionary = data.site
	var plan := Villages.plan_of(world.planet, s)
	var base_r := PlanetConst.RADIUS_M + float(data.base_e)
	var hs: Array = []
	for i in plan.hearths.size():
		var loc: Vector3 = data.hearths[i]
		hs.append([plan.dir_at(Vector2(loc.x, loc.z)), base_r + loc.y])
	var mid := plan.dir_at(plan.core)
	VillageWarmth.register(str(s.id), mid, base_r + plan.ground(plan.core), float(VillagePlan.PL.get("radius_m", 78.0)), hs)
	node.set_meta("hearth_dirs", hs)


## Build every village within `radius` of `d` now (the tools).
func build_now(d: Vector3, radius: float) -> void:
	var map: PlanetData = world.planet
	for s in Villages.near(map, d, radius):
		var id := str(s.id)
		if _built.has(id):
			continue
		if _pending.has(id):
			WorkerThreadPool.wait_for_task_completion(_pending[id])
			_pending.erase(id)
		else:
			_compute(id, map, s)
	while true:
		_mutex.lock()
		var empty := _done.is_empty()
		_mutex.unlock()
		if empty:
			break
		_attach()


## The villages built now: id -> node.
func built() -> Dictionary:
	return _built


## The village hearths within `radius` of `d` for OldHearths: [dir, node,
## local spot, chimney node or null] each.
func hearths_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	for id in _built:
		var node: Node3D = _built[id]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var s: Dictionary = node.get_meta("site")
		if CubeSphere.surface_distance_m(s.dir, d) > radius + 100.0:
			continue
		var plan := Villages.plan_of(world.planet, s)
		var locs: Array = node.get_meta("hearths")
		var dirs: Array = node.get_meta("hearth_dirs", [])
		var chims: Array = node.get_meta("chimneys")
		for i in locs.size():
			var hd: Vector3 = dirs[i][0] if i < dirs.size() else plan.dir_at(Vector2(locs[i].x, locs[i].z))
			if CubeSphere.surface_distance_m(hd, d) > radius:
				continue
			var h: Dictionary = plan.hearths[i]
			var chim: Node3D = chims[int(h.of)] if h.kind == "house" else null
			out.append([hd, node, locs[i], chim])
	return out


## Is the old hearth at `d` burning? (Its store, caught up; none = cold.)
func hearth_lit(d: Vector3) -> bool:
	var key := FireStore.key_of(d)
	var st: Dictionary = FireStore.stores.get(key, (WorldSave.data.get("old_hearths", {}) as Dictionary).get(key, {}))
	if st.is_empty():
		return false
	OldHearths.catch_up(world, st)
	return str(st.get("state", "out")) in ["flames", "low"]


## Bring every built village in line with its fires: windows, warmth,
## brambles and benches, and the log.
func sync() -> void:
	for id in _built:
		var node: Node3D = _built[id]
		if not is_instance_valid(node):
			continue
		var s: Dictionary = node.get_meta("site")
		var plan := Villages.plan_of(world.planet, s)
		var dirs: Array = node.get_meta("hearth_dirs", [])
		var wins: Array = node.get_meta("windows")
		var sq: Array = node.get_meta("squares")
		var n_lit := 0
		for i in dirs.size():
			var lit := hearth_lit(dirs[i][0])
			VillageWarmth.set_hearth(id, i, lit)
			if lit:
				n_lit += 1
			var h: Dictionary = plan.hearths[i]
			if h.kind == "house":
				var w: MeshInstance3D = wins[int(h.of)]
				w.visible = lit
			elif h.kind == "square":
				var parts: Array = sq[int(h.of)]
				var br: MeshInstance3D = parts[0]
				var body: StaticBody3D = parts[1]
				var bench: MeshInstance3D = parts[2]
				if br.visible == lit:
					br.visible = not lit
					body.collision_layer = 0 if lit else PropCollision.WORLD_LAYER
					bench.visible = lit
					if lit:
						GameLog.add_once("village_square:%s:%d" % [id, int(h.of)], "The brambles in the square burn back from the fire.", "village")
		var near := CubeSphere.surface_distance_m(world.dir_of(player.global_position), s.dir) < 70.0
		if near:
			GameLog.add_once("village_seen:%s" % id, "An empty village: a cold hearth in every house.", "village")
		if n_lit > 0 and near:
			GameLog.add_once("village_lit:%s" % id, "A window glows in the dead village.", "village")
		if n_lit == dirs.size() and n_lit > 0:
			GameLog.add_once("village_all:%s" % id, "Every hearth in the village burns.", "village")

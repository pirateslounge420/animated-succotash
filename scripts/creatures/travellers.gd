class_name Travellers
extends Node
## Travellers on the road (design 30 Sept §BF, data/travellers.json): rare
## cloaked figures walking the roads, day and night, never off them, who
## never stop and never speak. The hood tracks you from watch_m (the §B
## head-look rig, capped at the hood: the body never breaks stride), holds
## hold_s after you pass, then turns back to the road. They walk unharmed
## through the dark (Dread hunts only you). Where they are going comes
## later: at a road's end they turn back out of sight, or go.

static var D := Tuning.table("travellers")

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
var _root: Node3D
var _walkers: Array = [] # {"node", "body", "link", "m", "dir", "hold", "seen"}
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	_root = Node3D.new()
	_root.name = "Travellers"
	world.world_root.add_child(_root)
	_rng.randomize()


func _process(delta: float) -> void:
	if world == null or chunks == null or chunks.roads == null or player == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.0
		_spawn_pass()
	for w in _walkers.duplicate():
		_walk(w, delta)


## Keep the expected number on the roads within earshot: per_km_of_road
## times the road within 700 m, a walker put down out of sight.
func _spawn_pass() -> void:
	var pd: Vector3 = world.dir_of(player.global_position)
	var near := chunks.roads.links_near(pd, 700.0)
	var km := 0.0
	for link in near:
		km += float(link.get("len_m", 0.0)) / 1000.0
	var expected := km * float(D.get("per_km_of_road", 0.08))
	if _walkers.size() >= maxi(1, int(ceil(expected))) or near.is_empty():
		return
	if _rng.randf() > expected * 0.35:
		return
	var link: Dictionary = near[_rng.randi() % near.size()]
	var len_m := float(link.get("len_m", 0.0))
	if len_m < 120.0:
		return
	for attempt in 6:
		var m := _rng.randf_range(20.0, len_m - 20.0)
		var at := RoadNetwork.point_at(link.pts, m)
		var dist := CubeSphere.surface_distance_m(at, pd)
		if dist > 140.0 and dist < 600.0:
			_make(link, m, 1.0 if _rng.randf() < 0.5 else -1.0)
			return


func _make(link: Dictionary, m: float, dir: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([link.id, m, "traveller"])
	var pal := CloakedFigure.roll_palette(rng, CloakedFigure.tribe_family(rng.randi()))
	if rng.randf() < 0.35:
		pal = [Color(0.36, 0.36, 0.38), Color(0.28, 0.27, 0.3)]
	var cb := CloakedFigure.build(1.72, pal[0], pal[1])
	var body: Node3D = cb.root
	var node := Node3D.new()
	node.name = "Traveller"
	_root.add_child(node)
	node.add_child(body)
	var w := {"node": node, "body": body, "link": link, "m": m, "dir": dir, "hold": 0.0, "seen": false}
	_walkers.append(w)
	_put(w)


func _put(w: Dictionary) -> void:
	var link: Dictionary = w.link
	var pts: PackedVector3Array = link.pts
	var at := RoadNetwork.point_at(pts, float(w.m))
	var ahead := RoadNetwork.point_at(pts, clampf(float(w.m) + 3.0 * float(w.dir), 0.0, float(link.len_m)))
	var fwd := ahead - at
	fwd = (fwd - at * fwd.dot(at))
	if fwd.length() < 1e-9:
		fwd = CubeSphere.north(at)
	var node: Node3D = w.node
	node.global_position = world.to_scene(at, PlanetConst.RADIUS_M + chunks.ground_height(at))
	node.global_basis = Basis.looking_at(fwd.normalized(), at)


func _walk(w: Dictionary, delta: float) -> void:
	var link: Dictionary = w.link
	var speed := float(D.get("speed_mps", 1.4))
	w.m = float(w.m) + speed * delta * float(w.dir)
	var len_m := float(link.len_m)
	var node: Node3D = w.node
	var dist := node.global_position.distance_to(player.global_position)
	if float(w.m) <= 0.0 or float(w.m) >= len_m:
		# The road's end: gone if out of sight, else back the way it came.
		if dist > 160.0:
			_free(w, "road's end out of sight")
			return
		w.dir = -float(w.dir)
		w.m = clampf(float(w.m), 0.0, len_m)
	if dist > 900.0:
		_free(w, "far off (%.0f m)" % dist)
		return
	_put(w)
	var body: Node3D = w.body
	if body.has_method("set_motion"):
		body.call("set_motion", 0.75, delta)
	# The hood tracks you (capped at the hood: no torso), holds hold_s
	# after you pass, then back to the road.
	var hl: Dictionary = D.get("head_look", {})
	var watch := float(hl.get("watch_m", 18.0))
	var to := player.global_position - node.global_position
	var local := node.global_basis.orthonormalized().inverse() * to.normalized()
	var yaw := atan2(-local.x, -local.z)
	var head_max := deg_to_rad(minf(float(hl.get("head_max_deg", 70.0)), float(PlayerBody.HEAD_LOOK.get("head_max_deg", 45.0))))
	var in_front := absf(yaw) < deg_to_rad(110.0)
	if dist < watch and in_front:
		w.hold = float(hl.get("hold_s", 1.5))
		w.seen = true
	elif bool(w.seen):
		w.hold = float(w.hold) - delta
		if float(w.hold) <= 0.0:
			w.seen = false
	if body.has_method("set_look"):
		if bool(w.seen):
			body.call("set_look", clampf(yaw, -head_max, head_max), clampf(asin(clampf(local.y, -1.0, 1.0)), -0.3, 0.3))
		else:
			body.call("set_look", 0.0, 0.0)


func _free(w: Dictionary, why := "") -> void:
	if OS.get_environment("ROAD_DEBUG") == "1":
		print("[travellers] gone: %s (m %.0f of %.0f)" % [why, float(w.m), float((w.link as Dictionary).len_m)])
	_walkers.erase(w)
	if is_instance_valid(w.node):
		(w.node as Node).queue_free()

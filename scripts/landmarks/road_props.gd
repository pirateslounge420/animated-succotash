class_name RoadProps
extends Node
## What the roads left behind (design 30 Sept §BC, roads.json decay and
## landmarks), built round the player as the links come into reach and
## freed as they go: waymarks (a cairn, a standing stone, a post; a share
## fallen), bridges out with both stone abutments standing (a deck where
## the bridge still stands), stepping stones at a ford, rubble where a
## trail ends at a collapse, the off-road finds (a standing stone, a
## spring with its own quiet water), and the rooms' thresholds (§BB): a
## pair of boulders flanking the road where it enters a room. The lone
## old tree is the placer's (VegetationPlacer._place_road_trees).

const BUILD_M := 450.0
const DROP_M := 650.0
const STONE := Color(0.42, 0.44, 0.48)
const WOOD := Color(0.36, 0.27, 0.17)

var world: Node
var chunks: ChunkManager
var player: Node3D
var _root: Node3D
var _built := {} # key -> Node3D
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	_root = Node3D.new()
	_root.name = "RoadProps"
	world.world_root.add_child(_root)


func _process(delta: float) -> void:
	if world == null or chunks == null or chunks.roads == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.8
	var pd: Vector3 = world.dir_of(player.global_position)
	var roads: RoadNetwork = chunks.roads
	var want := {}
	for link in roads.links_near(pd, BUILD_M):
		var id: int = link.id
		var marks: Array = link.get("waymarks", [])
		for i in marks.size():
			var m: Array = marks[i]
			if CubeSphere.surface_distance_m(m[0], pd) < BUILD_M:
				want["w:%d:%d" % [id, i]] = ["waymark", m, link]
		var cr: Array = link.get("crossings", [])
		for i in cr.size():
			var c: Array = cr[i]
			if CubeSphere.surface_distance_m(c[0], pd) < BUILD_M:
				want["c:%d:%d" % [id, i]] = ["crossing", c, link]
		if bool(link.get("collapsed", false)):
			var pts: PackedVector3Array = link.pts
			var end := pts[pts.size() - 1]
			if CubeSphere.surface_distance_m(end, pd) < BUILD_M:
				want["x:%d" % id] = ["collapse", [end, pts[maxi(pts.size() - 2, 0)]], link]
		var lm: Dictionary = link.get("landmark", {})
		if not lm.is_empty() and str(lm.kind) != "old_tree" and CubeSphere.surface_distance_m(lm.dir, pd) < BUILD_M:
			want["l:%d" % id] = ["landmark", lm, link]
	for room in roads.rooms_near(pd, BUILD_M):
		var rk := "r:%s" % str(room.dir)
		want[rk] = ["threshold", room, null]
	for key in want:
		if _built.has(key):
			continue
		var w: Array = want[key]
		var node := _build(str(w[0]), w[1], w[2], key)
		if node != null:
			_built[key] = node
	for key in _built.keys():
		var node: Node3D = _built[key]
		if not is_instance_valid(node) or node.global_position.distance_to(player.global_position) > DROP_M:
			if is_instance_valid(node):
				NodeRelease.free_later(node)
			_built.erase(key)


func _place(d: Vector3, lift := 0.0) -> Node3D:
	var n := Node3D.new()
	_root.add_child(n)
	n.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d) + lift)
	n.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	return n


func _rng_for(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng


func _build(kind: String, item, link, key: String) -> Node3D:
	var rng := _rng_for(key)
	match kind:
		"waymark":
			return _waymark(item, rng)
		"crossing":
			return _crossing(item, link, rng)
		"collapse":
			return _collapse(item, rng)
		"landmark":
			return _landmark(item, rng)
		"threshold":
			return _threshold(item, rng)
	return null


## A cairn (stacked stones), a standing stone, a stone step, an abutment
## block, a notched tree or a post; fallen: tipped over, its stones
## spilled. The lost-and-found tells (design 30 Sept night §BY) are
## waymarks too, always standing.
func _waymark(m: Array, rng: RandomNumberGenerator) -> Node3D:
	var n := _place(m[0])
	var fallen: bool = m[2]
	var body := PropCollision.body(n)
	match str(m[1]):
		"cairn":
			var y := 0.0
			for i in (3 if fallen else 5):
				var s := Vector3(rng.randf_range(0.35, 0.55), 0.22, rng.randf_range(0.3, 0.5)) * (1.0 - i * 0.12)
				var pos := Vector3(0, y + s.y * 0.5, 0)
				if fallen and i >= 1:
					pos = Vector3(rng.randf_range(-0.8, 0.8), 0.1, rng.randf_range(-0.8, 0.8))
				var b := CreatureBodies.box(n, s, pos, STONE.darkened(rng.randf() * 0.2))
				b.rotation.y = rng.randf() * TAU
				y += s.y * 0.9
			PropCollision.capsule(body, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), 0.35, 0.6)
		"standing_stone":
			var b := CreatureBodies.box(n, Vector3(0.5, 2.0, 0.32), Vector3(0, 1.0, 0), STONE)
			if fallen:
				b.rotation = Vector3(deg_to_rad(80.0), rng.randf() * TAU, 0)
				b.position = Vector3(0, 0.2, 0.7)
			else:
				b.rotation = Vector3(deg_to_rad(rng.randf_range(-6.0, 6.0)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-4.0, 4.0)))
			PropCollision.capsule(body, b.transform, 0.3, 1.6)
		"stone_step":
			# A flat step set into the slope, a second one half a stride on.
			for i in 2:
				var s := Vector3(rng.randf_range(0.8, 1.1), 0.18, rng.randf_range(0.45, 0.6))
				var b := CreatureBodies.box(n, s, Vector3(rng.randf_range(-0.15, 0.15), 0.06 + i * 0.16, -i * 0.55), STONE.darkened(0.1 + rng.randf() * 0.15))
				b.rotation.y = rng.randf_range(-0.2, 0.2)
			PropCollision.capsule(body, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(0, 0.15, -0.3)), 0.3, 1.2)
		"abutment":
			# A lone dressed block, what is left of a wall or a bridge foot.
			var b := CreatureBodies.box(n, Vector3(1.5, 1.0, 1.1), Vector3(0, 0.45, 0), STONE.darkened(rng.randf() * 0.15))
			b.rotation = Vector3(0, rng.randf() * TAU, deg_to_rad(rng.randf_range(-5.0, 5.0)))
			PropCollision.capsule(body, Transform3D(Basis.IDENTITY, b.position), 0.6, 1.3)
		"notched_tree":
			# A dead stem with a pale blaze cut at eye height.
			var stem := CreatureBodies.cone(n, 0.24, 0.16, 2.8, Vector3(0, 1.4, 0), WOOD.darkened(0.15), 0.0, 7)
			stem.rotation.z = deg_to_rad(rng.randf_range(-4.0, 4.0))
			CreatureBodies.box(n, Vector3(0.22, 0.34, 0.06), Vector3(0, 1.5, -0.21), Color(0.78, 0.7, 0.52))
			PropCollision.capsule(body, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0)), 0.24, 2.8)
		_:
			var post := CreatureBodies.cone(n, 0.07, 0.05, 1.7, Vector3(0, 0.85, 0), WOOD, 0.0, 6)
			if fallen:
				post.rotation = Vector3(deg_to_rad(84.0), rng.randf() * TAU, 0)
				post.position = Vector3(0, 0.08, 0.5)
			else:
				post.rotation.z = deg_to_rad(rng.randf_range(-9.0, 9.0))
			PropCollision.capsule(body, post.transform, 0.07, 1.6)
	return n


## A bridge (both abutments always; the deck when it still stands) or a
## ford's stepping stones, across the river the road meets at `c`.
func _crossing(c: Array, link: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var at: Vector3 = c[0]
	var rw := float(c[3])
	var pts: PackedVector3Array = link.pts
	var r := RoadNetwork.nearest_seg(RoadNetwork.segments_in([link], at, 60.0), at, 30.0)
	var along: Vector3 = r.along if not r.is_empty() else CubeSphere.north(at)
	along = (along - at * along.dot(at)).normalized()
	var water: float = chunks.water_level_at(at)
	var n := Node3D.new()
	_root.add_child(n)
	n.global_position = world.to_scene(at, PlanetConst.RADIUS_M + water)
	n.global_basis = Basis.looking_at(along, at)
	var body := PropCollision.body(n)
	if str(c[1]) == "ford":
		var count := maxi(3, int(rw / 1.6))
		for i in count:
			var z := (i - (count - 1) * 0.5) * 1.5
			var s := Vector3(rng.randf_range(0.6, 0.9), 0.3, rng.randf_range(0.6, 0.9))
			var b := CreatureBodies.box(n, s, Vector3(rng.randf_range(-0.3, 0.3), 0.05, -z), STONE.darkened(0.15))
			b.rotation.y = rng.randf() * TAU
			PropCollision.capsule(body, b.transform, 0.4, 0.5)
		return n
	# The bridge: an abutment on each bank, the deck between if it stands.
	var half := rw * 0.5 + 1.2
	for side in [-1.0, 1.0]:
		var ab := CreatureBodies.box(n, Vector3(2.4, 1.6, 1.6), Vector3(0, 0.6, side * half), STONE)
		PropCollision.capsule(body, Transform3D(Basis.IDENTITY, ab.position), 0.9, 2.2)
	if not bool(c[2]):
		var deck := CreatureBodies.box(n, Vector3(2.2, 0.25, rw + 2.4), Vector3(0, 1.32, 0), WOOD)
		PropCollision.capsule(body, Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), deck.position), 1.1, rw + 2.4)
		for side in [-1.0, 1.0]:
			CreatureBodies.box(n, Vector3(0.08, 0.7, rw + 2.4), Vector3(side * 1.05, 1.8, 0), WOOD)
	return n


## Rubble where the trail ends: a spill of stones across the way.
func _collapse(ends: Array, rng: RandomNumberGenerator) -> Node3D:
	var n := _place(ends[0])
	var body := PropCollision.body(n)
	for i in 7:
		var s := Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.4, 0.9), rng.randf_range(0.5, 1.2))
		var b := CreatureBodies.box(n, s, Vector3(rng.randf_range(-2.2, 2.2), s.y * 0.4, rng.randf_range(-1.5, 1.5)), STONE.darkened(rng.randf() * 0.25))
		b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		PropCollision.capsule(body, Transform3D(Basis.IDENTITY, b.position), maxf(s.x, s.z) * 0.45, s.y)
	return n


## An off-road find: a standing stone taller than the waymarks, or a
## spring: a ring of stones round a pool with its own quiet water.
func _landmark(lm: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var n := _place(lm.dir)
	var body := PropCollision.body(n)
	match str(lm.kind):
		"spring":
			for i in 9:
				var a := i * TAU / 9.0
				var s := Vector3(0.5, 0.3, 0.4)
				var b := CreatureBodies.box(n, s, Vector3(cos(a) * 1.6, 0.15, sin(a) * 1.6), STONE)
				b.rotation.y = -a
				PropCollision.capsule(body, Transform3D(Basis.IDENTITY, b.position), 0.25, 0.4)
			var pool := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 1.4
			pm.bottom_radius = 1.4
			pm.height = 0.05
			pm.radial_segments = 18
			pool.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.32, 0.5, 0.85)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.1
			pool.material_override = mat
			pool.position = Vector3(0, 0.08, 0)
			n.add_child(pool)
			var v := Audio3D.make("water_flow", n, "Spring")
			v.stream = SoundSynth.stream("water_loop", rng.randi() % SoundSynth.VARIANTS)
			v.volume_db = -14.0
			v.position = Vector3(0, 0.3, 0)
			v.play(rng.randf() * 2.0)
		_:
			var b := CreatureBodies.box(n, Vector3(0.9, 3.2, 0.6), Vector3(0, 1.6, 0), STONE.darkened(0.1))
			b.rotation = Vector3(deg_to_rad(rng.randf_range(-5.0, 5.0)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-3.0, 3.0)))
			PropCollision.capsule(body, b.transform, 0.5, 2.6)
	return n


## A room's threshold (design §BB): where the road crosses the room's
## edge, a boulder either side of the way, a gap between.
func _threshold(room: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var roads: RoadNetwork = chunks.roads
	var rr := float(room.r)
	var segs := RoadNetwork.segments_in(roads.links_near(room.dir, rr + 30.0), room.dir, rr + 30.0)
	var n := Node3D.new()
	_root.add_child(n)
	n.global_position = world.to_scene(room.dir, PlanetConst.RADIUS_M + chunks.ground_height(room.dir))
	var made := 0
	var th: Dictionary = RoadNetwork.ROOMS.get("threshold", {})
	var wb = th.get("width_m", [1.5, 4.0])
	for s in segs:
		var pa: Vector3 = s[0]
		var pb: Vector3 = s[1]
		var da := CubeSphere.surface_distance_m(pa, room.dir)
		var db := CubeSphere.surface_distance_m(pb, room.dir)
		if (da < rr) == (db < rr):
			continue
		var t := clampf((rr - da) / maxf(db - da, 0.01), 0.0, 1.0)
		var at := pa.slerp(pb, t)
		var along := (pb - pa)
		along = (along - at * along.dot(at)).normalized()
		var right := along.cross(at).normalized()
		var gap := rng.randf_range(float(wb[0]), float(wb[1])) * 0.5 + float((s[2] as Dictionary).get("width_m", 2.0)) * 0.5
		for side in [-1.0, 1.0]:
			var d: Vector3 = (at + right * side * gap / PlanetConst.RADIUS_M).normalized()
			var b := Node3D.new()
			n.add_child(b)
			b.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
			b.global_basis = Basis.looking_at(along, d)
			var sz := Vector3(rng.randf_range(1.0, 1.6), rng.randf_range(0.9, 1.5), rng.randf_range(1.0, 1.5))
			var rock := CreatureBodies.box(b, sz, Vector3(0, sz.y * 0.4, 0), STONE.darkened(rng.randf() * 0.2))
			rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
			PropCollision.capsule(PropCollision.body(b), Transform3D(Basis.IDENTITY, rock.position), maxf(sz.x, sz.z) * 0.45, sz.y)
		made += 1
		if made >= 4:
			break
	return n

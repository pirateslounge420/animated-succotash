class_name TreeContact
extends Node3D
## The player among the trees (trunk colliders live on TerrainChunk, on
## physics layer TerrainChunk.TREE_LAYER):
##   * `under_canopy`: standing under a crown (inside its radius, below its
##     top), for rain shelter;
##   * brushing through a crown (small trees, or climbing into a big one)
##     or bumping a trunk rustles it: a leafy rustle sound and a quick
##     shake of that one tree (MultiMesh custom data .b, which the foliage
##     shader turns into a shiver). The rustle plays at that tree's crown,
##     where it stays (its players are top level: they don't ride along
##     with the player);
##   * climbing (spec Phase 1 (ii)): the trees' branch graphs (BranchGraphs,
##     read only) through graph_of() / nearest_graph() / nearest_holdable(),
##     `climb` (TreeClimb) moving the hands from handhold to handhold, and
##     the effort you hear: a breath at the head as each reach starts, the
##     bark rasping under a hand as it takes hold (ClimbSounds, from 3D
##     players at the hands and the head, so they sound where they happen
##     and fade with distance). A tree is found by its graph's key, so it
##     is the same tree with the same handholds when you come back to it.
## Nearby trunks come from one physics query a few times a second, not a
## trigger volume per tree (thousands of them).

const QUERY_RADIUS_M := 16.0
const QUERY_INTERVAL_S := 0.15
const RUSTLE_S := 1.4

var under_canopy := false
## The hands on a tree's branch graph while the player climbs one.
var climb := TreeClimb.new()

var _query := PhysicsShapeQueryParameters3D.new()
var _timer := 0.0
var _inside := {} # "chunk_id:tree" -> true, crowns the body is in
var _rustling: Array = [] # {mm, inst, base, t}
var _cooldown := {} # "chunk_id:tree" -> msec when it may rustle again
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
# Climbing: a voice at each hand (bark) and one at the head (breath).
var _hand_voices: Array[AudioStreamPlayer3D] = []
var _breath: AudioStreamPlayer3D
var _sound_n := 0


func _ready() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = QUERY_RADIUS_M
	_query.shape = sphere
	_query.collision_mask = TerrainChunk.TREE_LAYER
	for i in 2:
		var v := AudioStreamPlayer3D.new()
		Audio3D.apply(v, "rustle")
		v.volume_db = -4.0
		v.top_level = true
		add_child(v)
		_voices.append(v)
	for i in 2:
		var h := Audio3D.make("climb_hand", self, "HandL" if i == 0 else "HandR")
		h.volume_db = -6.0
		_hand_voices.append(h)
	_breath = Audio3D.make("climb_breath", self, "Breath")
	_breath.volume_db = -9.0


# --- Branch graphs (climbing) ------------------------------------------------------

## The branch graph of tree `i` of `chunk` (null if it has none now: out
## of NEAR range, not built yet, or a tree without wood to hold, such as
## bamboo or a cactus). Looked up by the graph's key, so a tree you come
## back to has the same graph (the same handholds).
func graph_of(chunk: TerrainChunk, i: int) -> BranchGraph:
	var g := BranchGraphs.find(chunk.graph_key(i))
	return g if g != null and g.valid() else null


## The graph with the player-holdable handhold nearest `scene_pos` within
## `max_m`, or null.
func nearest_graph(scene_pos: Vector3, max_m: float) -> BranchGraph:
	var n := BranchGraphs.nearest(scene_pos, max_m, TreeClimb.GRIP_R_M)
	return n[0] if not n.is_empty() else null


## The handhold of `g` nearest `scene_pos` that the player can hold (wood
## at least TreeClimb.GRIP_R_M thick), or -1.
func nearest_holdable(g: BranchGraph, scene_pos: Vector3) -> int:
	return g.nearest(scene_pos, TreeClimb.GRIP_R_M)


## After TreeClimb.step(): the sounds of this step's reach. A breath out as
## a reach starts (every reach along a limb, every other one on the trunk)
## and the bark brushing the hand that lets go; the bark rasping under the
## hand that takes hold, and now and then a breath in. `head` is where the
## player's mouth is (scene).
func climb_sounds(head: Vector3) -> void:
	_breath.global_position = head
	if climb.let_go >= 0:
		var h := climb.let_go
		_play(_hand_voices[h], "release", climb.hands[h], -12.0)
		if climb.pose != "trunk" or climb.reaches % 2 == 0:
			_play(_breath, "breath_out", head, -9.0 if climb.pose == "trunk" else -6.0)
	if climb.took >= 0:
		var h := climb.took
		_play(_hand_voices[h], "scrape", climb.hands[h], -5.0)
		if climb.reaches % 3 == 2 and not _breath.playing:
			_play(_breath, "breath_in", head, -14.0)


func _play(v: AudioStreamPlayer3D, kind: String, at: Vector3, db: float) -> void:
	_sound_n += 1
	v.stream = ClimbSounds.stream(kind, _sound_n)
	v.global_position = at
	v.volume_db = db
	v.pitch_scale = randf_range(0.92, 1.08)
	v.play()


## Per frame, with the player's scene position.
func update_contact(delta: float, pos: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = QUERY_INTERVAL_S
		_scan(pos, space)
	_animate(delta)


func _scan(pos: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	_query.transform = Transform3D(Basis(), pos)
	# Several shapes per tree (stacked trunk cylinders, limb capsules).
	var hits := space.intersect_shape(_query, 256)
	var under := false
	var now_inside := {}
	for hit in hits:
		var body: Object = hit.collider
		var chunk := (body as Node).get_parent() as TerrainChunk if body is Node else null
		if chunk == null:
			continue
		var i := chunk.tree_for_shape(body, hit.shape)
		if i < 0:
			continue
		var h: float = chunk.trees[i][1]
		var dims := PlantMeshes.tree_dims(chunk.tree_species(i).shape)
		var crown_r := dims.z * h
		if crown_r <= 0.0:
			continue
		var upv := chunk.tree_up(i)
		var rel := pos - chunk.tree_base(i)
		var y := rel.dot(upv)
		var horiz := (rel - upv * y).length()
		if horiz < crown_r and y < h and y > -2.0:
			under = true
		# The body (feet to head) inside the crown's band.
		if horiz < crown_r * 0.85 and y + 1.7 > h * dims.w and y < h:
			var key := "%d:%d" % [chunk.get_instance_id(), i]
			now_inside[key] = true
			if not _inside.has(key):
				rustle(chunk, i, 1.0)
	_inside = now_inside
	under_canopy = under


## The player ran into a trunk (a slide collision with a tree body).
func bumped(body: Object, shape_idx: int, speed: float) -> void:
	var chunk := (body as Node).get_parent() as TerrainChunk if body is Node else null
	if chunk == null:
		return
	var i := chunk.tree_for_shape(body, shape_idx)
	if i >= 0:
		rustle(chunk, i, clampf(speed / 4.0, 0.35, 1.0))


## Shake one tree and play a rustle from its crown.
func rustle(chunk: TerrainChunk, i: int, strength: float) -> void:
	var key := "%d:%d" % [chunk.get_instance_id(), i]
	var now := Time.get_ticks_msec()
	if _cooldown.get(key, 0) > now:
		return
	_cooldown[key] = now + 900
	if _cooldown.size() > 200:
		_cooldown.clear()
	var t: Array = chunk.trees[i]
	# The MultiMesh drawing the tree now (a layout's, near the player).
	var drawn := chunk.tree_instance(i)
	if not drawn.is_empty():
		var mm: MultiMesh = drawn[0]
		var inst: int = drawn[1]
		_rustling.append({"mm": mm, "inst": inst, "base": mm.get_instance_custom_data(inst), "t": strength})
	var h: float = t[1]
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = SoundSynth.stream("rustle", i)
	v.pitch_scale = randf_range(0.9, 1.1)
	v.volume_db = lerpf(-14.0, -3.0, strength)
	v.global_position = chunk.tree_base(i) + chunk.tree_up(i) * minf(h * 0.7, 3.0)
	v.play()


func _animate(delta: float) -> void:
	var alive: Array = []
	for r in _rustling:
		r.t -= delta / RUSTLE_S
		var c: Color = r.base
		c.b = maxf(r.t, 0.0)
		(r.mm as MultiMesh).set_instance_custom_data(r.inst, c)
		if r.t > 0.0:
			alive.append(r)
	_rustling = alive

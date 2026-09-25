class_name TreeContact
extends Node3D
## The player among the trees (trunk colliders live on TerrainChunk, on
## physics layer TerrainChunk.TREE_LAYER):
##   * `under_canopy`: standing under a crown (inside its radius, below its
##     top), for rain shelter;
##   * brushing through a crown (small trees, or climbing into a big one)
##     or bumping a trunk rustles it: a leafy rustle sound and a quick
##     shake of that one tree (MultiMesh custom data .b, which the foliage
##     shader turns into a shiver).
## Nearby trunks come from one physics query a few times a second, not a
## trigger volume per tree (thousands of them).

const QUERY_RADIUS_M := 16.0
const QUERY_INTERVAL_S := 0.15
const RUSTLE_S := 1.4

var under_canopy := false

var _query := PhysicsShapeQueryParameters3D.new()
var _timer := 0.0
var _inside := {} # "chunk_id:tree" -> true, crowns the body is in
var _rustling: Array = [] # {mm, inst, base, t}
var _cooldown := {} # "chunk_id:tree" -> msec when it may rustle again
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0


func _ready() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = QUERY_RADIUS_M
	_query.shape = sphere
	_query.collision_mask = TerrainChunk.TREE_LAYER
	for i in 2:
		var v := AudioStreamPlayer3D.new()
		v.unit_size = 6.0
		v.max_distance = 60.0
		v.volume_db = -4.0
		add_child(v)
		_voices.append(v)


## Per frame, with the player's scene position.
func update_contact(delta: float, pos: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = QUERY_INTERVAL_S
		_scan(pos, space)
	_animate(delta)


func _scan(pos: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	_query.transform = Transform3D(Basis(), pos)
	var hits := space.intersect_shape(_query, 64)
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
	var mm: MultiMesh = chunk.tree_mm.get(t[2])
	if mm != null and t.size() > 3:
		var inst: int = t[3]
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

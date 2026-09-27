class_name PondCrawlerHitboxes
extends Node3D
## The Pond Crawler's hitboxes (spec D5: "everything has a proper
## hitbox"): capsules and spheres that ride on its visible body parts (the
## lump, the hood, and each arm's bones through BoneAttachment3D). Each
## part is two things at once:
##   * a physics shape (on LAYER, all in one StaticBody3D moved with the
##     body), so the player can't walk through the body or its limbs
##     (PlanetPlayer's collision mask includes LAYER).
##     Static, not animatable: a swinging arm pushes you out of its way
##     but never hands you its speed;
##   * an exact ray test (segment_hit()), so an arrow hits the part it
##     visibly meets and sticks in that part, moving with it
##     (CreatureSpawner.creature_on_segment, Arrow). An arrow's own world
##     ray skips LAYER, so the physics copy never steals the hit.
## The owner calls update() once a frame after posing its body.
##
## Kept to the crawler on purpose: Phase 1's shared hitbox helper lands
## with the other rigs, and the crawler moves onto it then. Everything the
## crawler asks of this class is in PondCrawler._make_hitboxes(),
## set_visible_body(), hurt() and tick(); the only other users are the
## hooks in CreatureSpawner.creature_on_segment(), Arrow and PlanetPlayer.

## Physics layer of the crawler's hitboxes (layer 5, bit value 16; terrain
## and ruins are layer 1, trees add layer 2).
const LAYER := 1 << 4


class Part:
	var name := ""
	## The node it rides on: its shape follows it, arrows stick to it.
	var node: Node3D
	## Ends of the capsule's core segment in `node`'s space (a == b: a
	## sphere), and its radius in that space.
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var radius := 0.1
	var shape_node: CollisionShape3D
	# The same in scene space, as of the last update().
	var wa := Vector3.ZERO
	var wb := Vector3.ZERO
	var wr := 0.1


var parts: Array[Part] = []
var _body: StaticBody3D
var _active := true


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	# Placed in scene space every update() (its parent's scale and sway
	# stay out of the physics engine's way).
	_body.top_level = true
	_body.collision_layer = LAYER
	_body.collision_mask = 0
	add_child(_body)
	for p in parts:
		_add_shape(p)


## A capsule around the segment a..b (in `node`'s space).
func add_capsule(part_name: String, node: Node3D, a: Vector3, b: Vector3, radius: float) -> Part:
	var p := Part.new()
	p.name = part_name
	p.node = node
	p.a = a
	p.b = b
	p.radius = radius
	parts.append(p)
	if _body:
		_add_shape(p)
	return p


## A sphere at `center` (in `node`'s space).
func add_sphere(part_name: String, node: Node3D, center: Vector3, radius: float) -> Part:
	return add_capsule(part_name, node, center, center, radius)


func _add_shape(p: Part) -> void:
	var cs := CollisionShape3D.new()
	cs.name = p.name
	if p.a.is_equal_approx(p.b):
		cs.shape = SphereShape3D.new()
	else:
		cs.shape = CapsuleShape3D.new()
	_body.add_child(cs)
	p.shape_node = cs


## Off (dead, hidden): no physics, no arrow hits.
func set_active(on: bool) -> void:
	_active = on
	if _body:
		_body.collision_layer = LAYER if on else 0


func is_active() -> bool:
	return _active


## Follow the parts' nodes (call after the body is posed each frame).
func update() -> void:
	if _body == null:
		return
	var center := Vector3.ZERO
	for p in parts:
		var xf := _node_xf(p.node)
		p.wa = xf * p.a
		p.wb = xf * p.b
		p.wr = p.radius * xf.basis.get_scale().x
		center += (p.wa + p.wb) * 0.5
	if parts.is_empty():
		return
	center /= parts.size()
	_body.global_transform = Transform3D(Basis.IDENTITY, center)
	for p in parts:
		var cs := p.shape_node
		var mid := (p.wa + p.wb) * 0.5 - center
		if cs.shape is SphereShape3D:
			(cs.shape as SphereShape3D).radius = p.wr
			cs.transform = Transform3D(Basis.IDENTITY, mid)
		else:
			var axis := p.wb - p.wa
			var length := axis.length()
			var cap := cs.shape as CapsuleShape3D
			cap.radius = p.wr
			cap.height = length + 2.0 * p.wr
			cs.transform = Transform3D(_basis_y(axis / maxf(length, 1e-6)), mid)


## A part node's scene transform. A bone's is read from its skeleton right
## now (a BoneAttachment3D only catches up when the skeleton next
## updates, a frame late).
static func _node_xf(n: Node3D) -> Transform3D:
	var ba := n as BoneAttachment3D
	if ba and ba.bone_idx >= 0:
		var sk := ba.get_parent() as Skeleton3D
		if sk:
			return sk.global_transform * sk.get_bone_global_pose(ba.bone_idx)
	return n.global_transform


## The part the segment p0..p1 (scene space) meets first:
## {"t": fraction along p0..p1, "part": Part, "node": the part's node,
## "point": scene position}, or {} for a miss.
func segment_hit(p0: Vector3, p1: Vector3) -> Dictionary:
	if not _active:
		return {}
	var d := p1 - p0
	var length := d.length()
	if length < 1e-6:
		return {}
	var rd := d / length
	var best := INF
	var hit: Part = null
	for p in parts:
		var t := ray_capsule(p0, rd, p.wa, p.wb, p.wr)
		if t >= 0.0 and t <= length and t < best:
			best = t
			hit = p
	if hit == null:
		return {}
	return {"t": best / length, "part": hit, "node": hit.node, "point": p0 + rd * best}


## Distance along the unit ray (ro, rd) to a capsule's surface (segment
## pa..pb, radius r; pa == pb for a sphere), 0 if the ray starts inside,
## or -1 for a miss (Inigo Quilez's closed form).
static func ray_capsule(ro: Vector3, rd: Vector3, pa: Vector3, pb: Vector3, r: float) -> float:
	var ba := pb - pa
	var oa := ro - pa
	var baba := ba.dot(ba)
	if baba < 1e-10:
		return _ray_sphere(ro, rd, pa, r)
	# Starting inside: a hit right away.
	var h0 := clampf(oa.dot(ba) / baba, 0.0, 1.0)
	if (oa - ba * h0).length_squared() < r * r:
		return 0.0
	var bard := ba.dot(rd)
	var baoa := ba.dot(oa)
	var rdoa := rd.dot(oa)
	var oaoa := oa.dot(oa)
	var a := baba - bard * bard
	var b := baba * rdoa - baoa * bard
	var c := baba * oaoa - baoa * baoa - r * r * baba
	var h := b * b - a * c
	if a > 1e-10 and h >= 0.0:
		var t := (-b - sqrt(h)) / a
		var y := baoa + t * bard
		if y > 0.0 and y < baba:
			return t
	# The rounded ends.
	var best := -1.0
	for end in [pa, pb]:
		var t := _ray_sphere(ro, rd, end, r)
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
	return best


static func _ray_sphere(ro: Vector3, rd: Vector3, c: Vector3, r: float) -> float:
	var oc := ro - c
	var b := oc.dot(rd)
	var cc := oc.dot(oc) - r * r
	if cc < 0.0:
		return 0.0
	var h := b * b - cc
	if h < 0.0:
		return -1.0
	var t := -b - sqrt(h)
	return t if t >= 0.0 else -1.0


## A basis whose Y axis is `y` (unit), for a capsule along it.
static func _basis_y(y: Vector3) -> Basis:
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)

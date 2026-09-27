class_name Hitboxes
## Collision shapes on creatures (spec D5: "Everything has a proper hitbox
## ... no ghost-through"). Each part is its own kinematic body
## (AnimatableBody3D, moved by the animation, not by physics) with one
## capsule, sphere or box, made a child of the node it belongs to (a leg's
## pivot, the head), so the shapes follow the pose exactly.
##
## Two kinds of body, on two physics layers:
##   parts     capsule(), sphere(), box(): on LAYER (physics layer 3)
##             only. What aims and shoots includes LAYER in its ray mask
##             (Arrow; the bow's aim ray and the spear too): a ray that
##             meets a part hurts the creature it belongs to (creature_of():
##             Arrow sticks in that part and rides along with it) rather
##             than burying itself as if in the ground. The player moves
##             against layer 1 only, so it never snags on a leg.
##   blocker   blocker(): one simple body per creature on BLOCK_LAYER (1,
##             the world's layer), for the player to bump into (no walking
##             through a horse). Tucked inside the parts, so a ray always
##             meets a part first; if one ever reaches it, creature_of()
##             still names the creature.
## Shapes may sit under a uniformly scaled body (a creature's size, its
## fade-in).

## Physics layer 3 (bit value 4): creature parts.
const LAYER := 4
## Physics layer 1 (bit value 1): the world's, which the player moves
## against (terrain, trees, ruins); creature blockers.
const BLOCK_LAYER := 1


## A capsule from `a` to `b` (in `parent`'s space), `radius` thick.
static func capsule(creature: Node, parent: Node3D, a: Vector3, b: Vector3, radius: float) -> AnimatableBody3D:
	return _part(creature, parent, _capsule_shape(a, b, radius), _capsule_xf(a, b), LAYER)


static func sphere(creature: Node, parent: Node3D, center: Vector3, radius: float) -> AnimatableBody3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return _part(creature, parent, shape, Transform3D(Basis.IDENTITY, center), LAYER)


static func box(creature: Node, parent: Node3D, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> AnimatableBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _part(creature, parent, shape, Transform3D(basis, center), LAYER)


## The creature's one body the player bumps into: a capsule from `a` to
## `b` (in `parent`'s space, usually the torso), `radius` thick. Keep it
## inside the parts.
static func blocker(creature: Node, parent: Node3D, a: Vector3, b: Vector3, radius: float) -> AnimatableBody3D:
	var body := _part(creature, parent, _capsule_shape(a, b, radius), _capsule_xf(a, b), BLOCK_LAYER)
	body.name = "Blocker"
	return body


static func _capsule_shape(a: Vector3, b: Vector3, radius: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = a.distance_to(b) + 2.0 * radius
	return shape


## A capsule's frame: its Y axis along a..b, centered between them.
static func _capsule_xf(a: Vector3, b: Vector3) -> Transform3D:
	var axis := b - a
	var length := axis.length()
	var y := axis / length if length > 1e-6 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


static func _part(creature: Node, parent: Node3D, shape: Shape3D, xf: Transform3D, layer: int) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "Hitbox"
	body.sync_to_physics = false
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("creature", creature)
	body.set_meta("layer", layer)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
	parent.add_child(body)
	return body


## The creature a collider (a physics query's "collider") belongs to, or
## null if it isn't one of a creature's bodies.
static func creature_of(collider: Object) -> Node:
	if collider == null or not collider.has_meta("creature"):
		return null
	var c = collider.get_meta("creature")
	return c if is_instance_valid(c) else null


## Switch a creature's bodies on or off (off when it dies: nothing to
## bump into or shoot while it falls and fades).
static func set_active(bodies: Array, on: bool) -> void:
	for b in bodies:
		if is_instance_valid(b):
			(b as CollisionObject3D).collision_layer = int(b.get_meta("layer", LAYER)) if on else 0

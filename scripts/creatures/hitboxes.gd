class_name Hitboxes
## Collision shapes on creatures (spec D5: "Everything has a proper hitbox
## ... no ghost-through"). Each part is its own body with one capsule,
## sphere, box or hull, made a child of the node it belongs to (a leg's
## pivot, the head), so the shapes follow the pose exactly: moved by the
## animation, not by physics. They're static bodies (StaticBody3D), moved
## by setting their transform like any node: to rays and to the player
## that's the same as a kinematic body that doesn't sync to physics, and
## a moving static body costs the physics step about a sixth of what a
## moving kinematic one does (it isn't checked against the terrain's and
## the other static bodies every step).
##
## Two kinds of body, on two physics layers:
##   parts     capsule(), sphere(), box(), hull(): on LAYER (physics layer 3)
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
##
## Cost: a part that moves costs the physics step about a microsecond
## (measured: 520 parts on 40 walking bodies, ~0.5 ms a step), whatever
## its layer; one taken out of the space costs next to nothing. So
## set_active(false) takes bodies out of the space, and the owners keep
## them out while nothing could hit them: hidden, dead, fading, or
## farther than ACTIVE_M from the player and from any arrow in flight
## (Arrow.near()).

## Physics layer 3 (bit value 4): creature parts.
const LAYER := 4
## Physics layer 1 (bit value 1): the world's, which the player moves
## against (terrain, trees, ruins); creature blockers.
const BLOCK_LAYER := 1
## Bodies are in the physics space only within this many meters of the
## player (or of an arrow in flight: ARROW_WAKE_M).
const ACTIVE_M := 90.0
const ARROW_WAKE_M := 25.0


## A capsule from `a` to `b` (in `parent`'s space), `radius` thick.
static func capsule(creature: Node, parent: Node3D, a: Vector3, b: Vector3, radius: float) -> StaticBody3D:
	return _part(creature, parent, _capsule_shape(a, b, radius), _capsule_xf(a, b), LAYER)


static func sphere(creature: Node, parent: Node3D, center: Vector3, radius: float) -> StaticBody3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return _part(creature, parent, shape, Transform3D(Basis.IDENTITY, center), LAYER)


static func box(creature: Node, parent: Node3D, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _part(creature, parent, shape, Transform3D(basis, center), LAYER)


## A convex hull round `points` (in `parent`'s space): a tapering piece,
## a robe or a hat's cone.
static func hull(creature: Node, parent: Node3D, points: PackedVector3Array) -> StaticBody3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return _part(creature, parent, shape, Transform3D.IDENTITY, LAYER)


## The creature's one body the player bumps into: a capsule from `a` to
## `b` (in `parent`'s space, usually the torso), `radius` thick. Keep it
## inside the parts.
static func blocker(creature: Node, parent: Node3D, a: Vector3, b: Vector3, radius: float) -> StaticBody3D:
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


static func _part(creature: Node, parent: Node3D, shape: Shape3D, xf: Transform3D, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Hitbox"
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
## bump into or shoot while it falls and fades). Off, they're out of the
## physics space altogether (disabled, so they cost the step nothing) and
## on no layer.
static func set_active(bodies: Array, on: bool) -> void:
	for b in bodies:
		if is_instance_valid(b):
			var body := b as CollisionObject3D
			body.collision_layer = int(b.get_meta("layer", LAYER)) if on else 0
			body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Might anything hit a body at `pos` now: the player within ACTIVE_M, or
## an arrow in flight within ARROW_WAKE_M?
static func wanted_at(pos: Vector3, player_pos: Vector3) -> bool:
	return pos.distance_to(player_pos) < ACTIVE_M or Arrow.near(pos, ARROW_WAKE_M)

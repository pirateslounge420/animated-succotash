class_name PropCollision
## Collision for props (spec D5: everything has a proper hitbox, no
## ghost-through, no invisible walls): campfire stones and logs, seat logs,
## leaning spears, fallen logs, den stones, rock shelters, and the round
## parts of ruins (boulders, giant trunks, grave mounds). Each gets a
## simple shape fitted to what's drawn: a capsule along a log or a spear
## shaft, a convex hull round a boulder (RuinBuilder.rock_hull()), a box
## only for a block.
##
## The shapes go on a StaticBody3D in WORLD_LAYER, the layer the ground
## and ruins are on, so the player walks into them, arrows stick in them
## and the camera's spring arm stops at them just as at the ground.

## Physics layer 1: the ground, ruins and props.
const WORLD_LAYER := 1

## Shapes shared by props of the same size (every campfire's stones and
## logs), keyed by their measurements.
static var _shared := {}


## A static body for a prop's shapes, under `parent` (at its origin: the
## shapes are placed in `parent`'s space).
static func body(parent: Node3D, node_name := "Collision") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = WORLD_LAYER
	# Static: it never needs to detect anything itself.
	b.collision_mask = 0
	parent.add_child(b)
	return b


## A capsule `length` m long end to end and `radius` thick, running along
## `xf`'s Y axis through its origin (as a CreatureBodies.cone mesh does).
static func capsule(b: CollisionObject3D, xf: Transform3D, radius: float, length: float) -> CollisionShape3D:
	var key := "capsule_%.3f_%.3f" % [radius, length]
	if not _shared.has(key):
		var c := CapsuleShape3D.new()
		c.radius = radius
		c.height = maxf(length, radius * 2.0)
		_shared[key] = c
	return _add(b, _shared[key], Transform3D(xf.basis.orthonormalized(), xf.origin))


## A capsule from end `a` to end `c`, `radius` thick.
static func capsule_between(b: CollisionObject3D, a: Vector3, c: Vector3, radius: float) -> CollisionShape3D:
	var y := (c - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return capsule(b, Transform3D(Basis(x, y, x.cross(y)), (a + c) * 0.5), radius, a.distance_to(c))


## A box of `size` placed by `xf`.
static func box(b: CollisionObject3D, xf: Transform3D, size: Vector3) -> CollisionShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return _add(b, s, Transform3D(xf.basis.orthonormalized(), xf.origin))


## The convex hull of `points` (in the space `xf` places them in).
static func hull(b: CollisionObject3D, points: PackedVector3Array, xf := Transform3D()) -> CollisionShape3D:
	var s := ConvexPolygonShape3D.new()
	s.points = points
	return _add(b, s, xf)


static func _add(b: CollisionObject3D, shape: Shape3D, xf: Transform3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	b.add_child(cs)
	return cs

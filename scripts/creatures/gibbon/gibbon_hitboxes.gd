class_name GibbonHitboxes
extends Node3D
## The gibbon's hitboxes (spec D5: "everything has a proper hitbox"): a
## capsule or sphere per body part, fitted to the sculpted body (hips,
## chest, head, and per side the upper arm, forearm, hand, thigh and
## shin), all in one kinematic body that follows the posed bones every
## frame (update(), after GibbonRig.apply()).
##
## The body is on LAYER only, physics layer 3, named "creature_hitboxes"
## in project.godot: not layer 1, the world's, which the player moves
## against, so a gibbon swinging past never snags the player. Rays that
## don't filter layers (the bow's aim, the arrow's flight) do meet it; the
## body carries the gibbon as its "creature" meta and part_name() names
## the part a ray met, for the shared hitbox code to route hits by when
## it lands. Kept to the gibbon until then.

## Physics layer 3 (bit value 4), "creature_hitboxes".
const LAYER := 1 << 2

## Parts: [name, bone, a, b, radius], a and b the ends of the capsule's
## core in the rest pose (skeleton space, GibbonBody.joints()); a == b is
## a sphere. Sized to the sculpted shapes they cover.
static func parts() -> Array:
	var out := [
		["hips", GibbonBody.ROOT, Vector3(0, -0.16, 0.012), Vector3(0, -0.07, 0.01), 0.072],
		["chest", GibbonBody.CHEST, Vector3(0, -0.02, 0.004), Vector3(0, 0.13, 0.004), 0.092],
		["head", GibbonBody.HEAD, Vector3(0, 0.285, -0.012), Vector3(0, 0.285, -0.012), 0.072],
	]
	for s in 2:
		var side := "L" if s == 0 else "R"
		var a := GibbonBody.arm_dir(s)
		out.append(["upper_arm_" + side, GibbonBody.UPPER[s], GibbonBody.shoulder(s), GibbonBody.elbow(s), 0.04])
		out.append(["forearm_" + side, GibbonBody.FORE[s], GibbonBody.elbow(s), GibbonBody.wrist(s), 0.03])
		out.append(["hand_" + side, GibbonBody.HAND[s], GibbonBody.wrist(s) + a * 0.02, GibbonBody.knuckle(s) + a * 0.03, 0.027])
		out.append(["thigh_" + side, GibbonBody.THIGH[s], GibbonBody.hip(s), GibbonBody.knee(s), 0.04])
		out.append(["shin_" + side, GibbonBody.SHIN[s], GibbonBody.knee(s), GibbonBody.ankle(s) + Vector3(0, -0.02, -0.03), 0.03])
	return out


var body: AnimatableBody3D
var _skel: Skeleton3D
var _shapes: Array[CollisionShape3D] = []
var _bones := PackedInt32Array()
## Each shape's transform relative to its bone's posed frame.
var _offsets: Array[Transform3D] = []
var _names := PackedStringArray()


## Builds the body for the skeleton `skel` (GibbonBody.build()) of
## `creature`.
func setup(creature: Node, skel: Skeleton3D) -> void:
	name = "Hitboxes"
	_skel = skel
	body = AnimatableBody3D.new()
	body.name = "HitBody"
	# Moved by the rig, not by physics; placed in scene space every frame.
	body.sync_to_physics = false
	body.top_level = true
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.set_meta("creature", creature)
	add_child(body)
	var joints := GibbonBody.joints()
	for p in parts():
		var bone: int = p[1]
		var a: Vector3 = p[2]
		var b: Vector3 = p[3]
		var r: float = p[4]
		var cs := CollisionShape3D.new()
		cs.name = p[0]
		var xf := Transform3D(Basis.IDENTITY, (a + b) * 0.5 - joints[bone])
		if a.distance_to(b) < 1e-4:
			var sph := SphereShape3D.new()
			sph.radius = r
			cs.shape = sph
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = r
			cap.height = a.distance_to(b) + 2.0 * r
			cs.shape = cap
			# Capsules run along their local Y.
			var y := (b - a).normalized()
			var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
			xf.basis = Basis(x, y, x.cross(y))
		body.add_child(cs)
		_shapes.append(cs)
		_bones.append(bone)
		_offsets.append(xf)
		_names.append(p[0])


## Follow the pose: call once a frame after the rig has set the bones.
func update() -> void:
	if body == null or not is_inside_tree():
		return
	body.global_transform = _skel.global_transform
	for k in _shapes.size():
		_shapes[k].transform = _skel.get_bone_global_pose(_bones[k]) * _offsets[k]


## The part a ray or shape query met (its `shape` index), or "".
func part_name(shape_index: int) -> String:
	return _names[shape_index] if shape_index >= 0 and shape_index < _names.size() else ""


func set_active(on: bool) -> void:
	if body:
		body.collision_layer = LAYER if on else 0

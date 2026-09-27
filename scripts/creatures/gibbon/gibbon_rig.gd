class_name GibbonRig
extends RefCounted
## Poses the gibbon's skeleton (GibbonBody) every frame from a handful of
## targets, all in the body's own frame (the skeleton's space: center of
## mass at the origin, facing -Z):
##   - each arm reaches its grip target with two-bone IK (shoulder to
##     elbow to wrist, the elbow bending toward a pole), the hand turned
##     so its palm faces the wood and the finger hook curled round it; a
##     holding hand's grip point lands exactly on its target;
##   - the chest bends and twists a little, the head turns toward a look
##     direction;
##   - the legs are set directly: hip flex and splay, knee, ankle.
## Every bone's rotation is worked out in skeleton space, then turned into
## the rotation relative to its parent that Skeleton3D wants.

var skel: Skeleton3D
var rest: PackedVector3Array

## Inputs, set by Gibbon before apply(). Per side (0 left, 1 right):
## where the wood should sit in the hand, the way the elbow points, the
## way the palm faces, and how far the fingers are curled (0 open, 1
## hooked round the wood).
var grip: Array[Vector3] = [Vector3(-0.3, 0.3, 0), Vector3(0.3, 0.3, 0)]
var pole: Array[Vector3] = [Vector3(-1, 0, 0.5), Vector3(1, 0, 0.5)]
var palm: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, -1)]
var curl: Array[float] = [0.3, 0.3]
## Chest bend (x forward, y twist, z to the side), radians.
var chest := Vector3.ZERO
## Where the head looks (skeleton space; zero: straight ahead).
var look := Vector3.ZERO
## Per side: hip flex (thigh forward), hip splay (outward), knee bend,
## ankle flex (toes up), radians.
var hip_flex: Array[float] = [0.3, 0.3]
var hip_splay: Array[float] = [0.1, 0.1]
var knee: Array[float] = [0.5, 0.5]
var ankle: Array[float] = [0.0, 0.0]

## Where each hand's grip point ended up (skeleton space), after apply().
var grip_out: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]

var _glob: Array[Basis] = []


func _init(skeleton: Skeleton3D) -> void:
	skel = skeleton
	rest = GibbonBody.joints()
	_glob.resize(GibbonBody.BONES.size())


func apply() -> void:
	for b in _glob.size():
		_glob[b] = Basis.IDENTITY
	var c_rot := Basis.from_euler(chest)
	_glob[GibbonBody.CHEST] = c_rot
	var chest_at := rest[GibbonBody.CHEST]
	# Head: toward `look`, no more than ~70 degrees off the chest's facing.
	var fwd := c_rot * Vector3.FORWARD
	var up := c_rot * Vector3.UP
	var want := fwd if look.length_squared() < 1e-6 else look.normalized()
	if want.angle_to(fwd) > 1.2:
		want = fwd.slerp(want, 1.2 / want.angle_to(fwd)).normalized()
	if absf(want.dot(up)) < 0.98:
		_glob[GibbonBody.HEAD] = Basis.looking_at(want, up)
	else:
		_glob[GibbonBody.HEAD] = c_rot
	for s in 2:
		_arm(s, c_rot, chest_at)
		_leg(s)
	for b in _glob.size():
		var parent: int = GibbonBody.BONES[b][1]
		var local := _glob[b] if parent < 0 else _glob[parent].inverse() * _glob[b]
		skel.set_bone_pose_rotation(b, local.get_rotation_quaternion())


func _arm(s: int, c_rot: Basis, chest_at: Vector3) -> void:
	var sh := chest_at + c_rot * (rest[GibbonBody.UPPER[s]] - chest_at)
	var target := grip[s]
	# The hand carries on from the line shoulder to grip; the wrist sits
	# GRIP_M short of the wood.
	var h := (target - sh).normalized()
	var w := target - h * GibbonBody.GRIP_M
	var a := GibbonBody.UPPER_M
	var b := GibbonBody.FORE_M
	var el := _two_bone(sh, w, a, b, pole[s])
	var up_dir := (el - sh).normalized()
	var wr := el + (w - el).normalized() * b
	var fore_dir := (wr - el).normalized()
	# Palm: facing the wood, square to the hand.
	var hand_dir := (target - wr).normalized() if target.distance_to(wr) > 1e-3 else fore_dir
	var p := palm[s] - hand_dir * palm[s].dot(hand_dir)
	if p.length_squared() < 1e-6:
		p = c_rot * Vector3.FORWARD
		p -= hand_dir * p.dot(hand_dir)
	p = p.normalized()
	# The elbow's crease faces away from where it points; the forearm
	# turns halfway from that to the palm (the forearm's twist).
	var crease := -(pole[s] - up_dir * pole[s].dot(up_dir))
	if crease.length_squared() < 1e-6:
		crease = p
	crease = crease.normalized()
	var fore_z := (crease + p).normalized() if (crease + p).length_squared() > 1e-4 else p
	var rest_dir := GibbonBody.arm_dir(s)
	_glob[GibbonBody.UPPER[s]] = _frame(up_dir, crease) * _frame(rest_dir, GibbonBody.PALM_N).inverse()
	_glob[GibbonBody.FORE[s]] = _frame(fore_dir, fore_z) * _frame(rest_dir, GibbonBody.PALM_N).inverse()
	var hand_rot := _frame(hand_dir, p) * _frame(rest_dir, GibbonBody.PALM_N).inverse()
	_glob[GibbonBody.HAND[s]] = hand_rot
	# Fingers hook toward the palm, round the wood.
	var axis := rest_dir.cross(GibbonBody.PALM_N).normalized()
	_glob[GibbonBody.FINGERS[s]] = hand_rot * Basis(axis, clampf(curl[s], 0.0, 1.0) * 1.9)
	grip_out[s] = wr + hand_dir * GibbonBody.GRIP_M


func _leg(s: int) -> void:
	var sx := 1.0 if s == 1 else -1.0
	var thigh := Basis(Vector3.RIGHT, hip_flex[s]) * Basis(Vector3.BACK, hip_splay[s] * sx)
	_glob[GibbonBody.THIGH[s]] = thigh
	var shin := thigh * Basis(Vector3.RIGHT, -knee[s])
	_glob[GibbonBody.SHIN[s]] = shin
	_glob[GibbonBody.FOOT[s]] = shin * Basis(Vector3.RIGHT, ankle[s])


## An orthonormal frame with +Y along `y` and +Z as near `z` as can be.
static func _frame(y: Vector3, z: Vector3) -> Basis:
	var yy := y.normalized()
	var zz := z - yy * z.dot(yy)
	if zz.length_squared() < 1e-8:
		zz = yy.cross(Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.UP)
	zz = zz.normalized()
	var xx := yy.cross(zz)
	return Basis(xx, yy, zz)


## Two-bone IK: the elbow for a shoulder at `s` reaching a wrist at `w`
## with segments `a` and `b`, bending toward `pole`. Out of reach, the arm
## points straight at the target.
static func _two_bone(s: Vector3, w: Vector3, a: float, b: float, pole_dir: Vector3) -> Vector3:
	var d := w - s
	var len_d := d.length()
	var u := d / maxf(len_d, 1e-5)
	var dist := clampf(len_d, absf(a - b) + 1e-3, a + b - 1e-4)
	var cos_s := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var sin_s := sqrt(1.0 - cos_s * cos_s)
	var p := pole_dir - u * pole_dir.dot(u)
	if p.length_squared() < 1e-8:
		p = u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT)
	p = p.normalized()
	return s + u * (a * cos_s) + p * (a * sin_s)

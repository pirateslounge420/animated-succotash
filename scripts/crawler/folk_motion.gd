class_name FolkMotion
extends RefCounted
## A hearth folk moved with the rig's own animations (design 6 Oct §ET.9:
## one rig, one animation set; §FH; queue 72, the shaman's harvest and
## brew, data/brew.json). It rises from its stone and sits back down (the
## rig's seated pose, PlayerBody.seated, and its crouch, set_crouch and
## set_tuck), walks a way (the rig's walk cycle, from the velocity it is
## handed, the cloak swinging as it starts, turns and stops), turns,
## crouches, and reaches an arm toward a point (the arm's pivot turned to
## it, as PlanetPlayer reaches the player's arms for a handhold; the elbow
## straightens by itself, PlayerBody._pose_arms_rest). Nothing new in the
## rig, and no words (§ED).

## The arm's pivot turns that far toward its point in REACH_S, and back.
const REACH_S := 0.45
## Where a stick (or a cutting) passes through the left fist, in the left
## forearm's own space: HearthFolk.FIST mirrored.
const FIST_L := Vector3(0.008, -0.325, -0.012)

var f: HearthFolk
## The arms' rest turns (the rig's own: ARM_REST, mirrored for the left).
var _rest: Array = []
## Each arm (0 left, 1 right): its reach now (0 rest .. 1 on its point),
## the reach it is going to, and its point (scene).
var _w: Array = [0.0, 0.0]
var _want: Array = [0.0, 0.0]
var _at: Array = [Vector3.ZERO, Vector3.ZERO]
## The way being walked (scene points on the ground) and the point next.
var path := PackedVector3Array()
var _next := 0
## The ground under its feet: `ground` (x, z) -> y when set (the surface),
## else floor_y (the hearth room's flat floor).
var floor_y := 0.0
var ground := Callable()
## Metres walked (the checks).
var walked := 0.0


func _init(p_f: HearthFolk) -> void:
	f = p_f
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		_rest.append(Vector3(PlayerBody.ARM_REST.x, 0.0, PlayerBody.ARM_REST.z * sx))


## The rig's yaw (radians about up; 0 faces -z) that faces `dir` (flat).
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Which way it faces now (flat).
func front() -> Vector3:
	var fr := -f.global_basis.z
	fr.y = 0.0
	return fr.normalized() if fr.length() > 1e-4 else Vector3.FORWARD


## Up off its stone, standing on the floor where it is (its feet at `at`,
## scene): the seated pose gives way to the rig's crouch at once, which
## eases out when stand_up() is called.
func rise_from_seat(at: Vector3) -> void:
	f.body.seated = false
	f.body.set_tuck(1.0)
	f.body.set_crouch(1.0)
	f.global_position = at


## Straighten up out of the crouch (the rig eases it).
func stand_up() -> void:
	f.body.set_crouch(0.0)


## Crouch (0 .. 1, the rig's own, eased).
func crouch(amount: float) -> void:
	f.body.set_crouch(amount)


## Back on its stone, its feet at `at` (scene, the floor) facing `yaw`, as
## HearthFolk.make sat it.
func sit_at(at: Vector3, yaw: float) -> void:
	f.body.seated = true
	f.body.set_crouch(0.0)
	f.body.set_velocity(Vector3.ZERO)
	f.global_position = at + Vector3(0.0, float(HearthFolk.RES.get("seat_h_m", 0.32)) - HearthFolk.SEAT_TOP * f.k, 0.0)
	f.rotation = Vector3(0.0, yaw, 0.0)


## Stand at `at` (scene; its feet), off any stone.
func stand_at(at: Vector3) -> void:
	f.body.seated = false
	f.global_position = Vector3(at.x, _ground_y(at), at.z)


func _ground_y(p: Vector3) -> float:
	return float(ground.call(p.x, p.z)) if ground.is_valid() else floor_y


## Walk `pts` (scene) from where it stands.
func walk_to(pts: PackedVector3Array) -> void:
	path = pts
	_next = 0


## One step along the way at `speed` m/s, turning toward the next point at
## `dps` degrees a second (slower while it turns a corner); the rig strides
## from the velocity it is handed. True once at the way's end (standing
## still there).
func walk(delta: float, speed: float, dps: float) -> bool:
	if _next >= path.size():
		f.body.set_velocity(Vector3.ZERO)
		return true
	var p := f.global_position
	var to := path[_next] - p
	to.y = 0.0
	var dist := to.length()
	if dist < 0.04:
		_next += 1
		return walk(delta, speed, dps) if _next < path.size() else _stop()
	var dir := to / dist
	var off := absf(turn_toward(dir, delta, dps))
	# Slower round a corner, still to turn on the spot past a right angle.
	var v := speed * clampf(cos(off), 0.0, 1.0)
	var step := minf(v * delta, dist)
	var np := p + dir * step
	np.y = _ground_y(np)
	f.global_position = np
	walked += step
	f.body.set_velocity(dir * (step / maxf(delta, 1e-4)))
	return false


func _stop() -> bool:
	f.body.set_velocity(Vector3.ZERO)
	return true


## Turn toward `dir` (flat) at `dps` degrees a second: the angle left after
## this step (radians).
func turn_toward(dir: Vector3, delta: float, dps: float) -> float:
	var want := yaw_of(dir)
	var now := f.rotation.y
	var d := wrapf(want - now, -PI, PI)
	var most := deg_to_rad(dps) * delta
	f.rotation.y = now + clampf(d, -most, most)
	return wrapf(want - f.rotation.y, -PI, PI)


## Has it turned to face `dir` (within `tol_deg`)?
func faces(dir: Vector3, tol_deg := 4.0) -> bool:
	return absf(wrapf(yaw_of(dir) - f.rotation.y, -PI, PI)) <= deg_to_rad(tol_deg)


## Reach arm `side` (0 left, 1 right) toward `point` (scene).
func reach(side: int, point: Vector3) -> void:
	_want[side] = 1.0
	_at[side] = point


## Keep the reaching arm on a moving point.
func reach_point(side: int, point: Vector3) -> void:
	_at[side] = point


## Let arm `side` come back to rest.
func release(side: int) -> void:
	_want[side] = 0.0


## How far arm `side` is reached (0 .. 1).
func reached(side: int) -> float:
	return smoothstep(0.0, 1.0, float(_w[side]))


## Each physics step: the arms ease toward their points or back to rest.
func update(delta: float) -> void:
	if f == null or not is_instance_valid(f) or f.body == null:
		return
	for s in 2:
		_w[s] = move_toward(float(_w[s]), float(_want[s]), delta / REACH_S)
		var arm: Node3D = f.body.arms[s]
		var w := reached(s)
		var rest := Basis.from_euler(_rest[s])
		if w <= 0.0:
			arm.rotation = _rest[s]
			continue
		var aim := _aim_basis(arm, _at[s])
		var q := Quaternion(rest.orthonormalized()).slerp(Quaternion(aim.orthonormalized()), w)
		arm.transform.basis = Basis(q)


## The arm's turn that points its hand (ARM_M down its -Y) at `point`, in
## the rig's own space (PlanetPlayer._reach_arms' way, never stretched).
func _aim_basis(arm: Node3D, point: Vector3) -> Basis:
	var inv := f.body.global_transform.affine_inverse()
	var d := inv * point - arm.position
	if d.length() < 1e-3:
		return Basis.from_euler(Vector3.ZERO)
	var y := -d.normalized()
	var x := Vector3.RIGHT - y * y.dot(Vector3.RIGHT)
	x = x.normalized() if x.length() > 0.1 else y.cross(Vector3.BACK).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## The forearm node of arm `side` (its elbow pivot: "ElbowL" / "ElbowR").
func elbow(side: int) -> Node3D:
	var arm: Node3D = f.body.arms[side]
	return arm.get_node_or_null("ElbowL" if side == 0 else "ElbowR") as Node3D


## Where a thing held in arm `side`'s fist sits (scene).
func fist(side: int) -> Vector3:
	var e := elbow(side)
	if e == null:
		return f.global_position + Vector3.UP
	return e.global_transform * (FIST_L if side == 0 else HearthFolk.FIST)


## The rig's scale in the scene (its height against the player's rig).
func scale() -> float:
	return f.body.global_basis.get_scale().x

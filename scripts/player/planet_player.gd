class_name PlanetPlayer
extends CharacterBody3D
## Third-person explorer on a round planet. Gravity pulls toward the
## planet's center, so "up" is recomputed every frame and the body turns to
## stand upright wherever it is.
##
## Speeds: walking uses the spec's 4.5 km/h pace (the one DESIGN.md's biome
## walk-across times assume); hold run to jog; fast_travel is a debug
## speed for crossing the prototype quickly. The player swims when in
## water deeper than chest height.
##
## Mouse or right stick turns the camera; click the game window to capture
## the mouse, press release_mouse (Esc) to free it.

const GRAVITY := 9.8
const WALK_SPEED := PlanetConst.WALK_SPEED_MPS
const RUN_SPEED := 4.2
const FAST_TRAVEL_SPEED := 60.0
const SWIM_SPEED := 1.6
const JUMP_SPEED := 4.6
const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6

var world: Node
var chunks: ChunkManager
var up := Vector3.UP
var surface_dir := Vector3.UP
var swimming := false

var _yaw := 0.0 # camera heading around local up, radians
var _facing := Vector3.FORWARD # direction the body faces
var _pitch := -0.25
var _heading := Vector3.FORWARD # tangent direction the camera faces
var _spring: SpringArm3D
var _camera: Camera3D
var _body: Node3D


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_body = _build_body()
	add_child(_body)

	_spring = SpringArm3D.new()
	_spring.spring_length = 4.5
	_spring.margin = 0.2
	_spring.position = Vector3(0, 1.5, 0)
	_spring.add_excluded_object(get_rid())
	add_child(_spring)
	_camera = Camera3D.new()
	_camera.far = 30000.0
	_camera.near = 0.1
	_camera.fov = 70.0
	_camera.current = true
	_spring.add_child(_camera)


func camera() -> Camera3D:
	return _camera


## Stand on the ground at a surface direction.
func spawn_at(d: Vector3) -> void:
	surface_dir = d
	var ground := chunks.ground_height(d)
	var water := chunks.water_level_at(d)
	global_position = world.to_scene(d, PlanetConst.RADIUS_M + maxf(ground, water) + 1.0)
	up = d
	_heading = CubeSphere.north(d)
	velocity = Vector3.ZERO
	_orient()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.3, 0.6)


func _physics_process(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		_yaw -= stick.x * STICK_SENSITIVITY * delta
		_pitch = clampf(_pitch - stick.y * STICK_SENSITIVITY * delta, -1.3, 0.6)

	surface_dir = world.dir_of(global_position)
	up = surface_dir
	up_direction = up

	# Carry the camera heading across the curved surface: re-project it onto
	# the new tangent plane each frame so it doesn't drift as "up" changes.
	_heading = (_heading - up * _heading.dot(up)).normalized()
	if _heading.length() < 0.5:
		_heading = CubeSphere.north(up)
	var cam_forward := _heading.rotated(up, _yaw)
	var cam_right := cam_forward.cross(up)

	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var wish := (cam_right * input.x + cam_forward * input.y)
	var speed := WALK_SPEED
	if Input.is_action_pressed("run"):
		speed = RUN_SPEED
	if Input.is_action_pressed("fast_travel"):
		speed = FAST_TRAVEL_SPEED

	var radius: float = world.radius_of(global_position)
	var water := chunks.water_level_at(surface_dir)
	var depth := (PlanetConst.RADIUS_M + water) - radius
	swimming = depth > 1.2
	if swimming and not Input.is_action_pressed("fast_travel"):
		speed = minf(speed, SWIM_SPEED)

	var vertical := up * velocity.dot(up)
	var horizontal := wish * speed
	if swimming:
		# Float up to the surface, head above water.
		vertical = up * clampf((depth - 1.2) * 2.0, -2.0, 2.0)
		if Input.is_action_pressed("jump"):
			vertical += up * 1.5
	elif is_on_floor():
		vertical = Vector3.ZERO
		if Input.is_action_just_pressed("jump"):
			vertical = up * JUMP_SPEED
	else:
		vertical -= up * GRAVITY * delta
	velocity = horizontal + vertical
	move_and_slide()

	# Safety net: never fall through unloaded ground.
	var ground := chunks.ground_height(surface_dir)
	if radius < PlanetConst.RADIUS_M + ground - 2.0:
		global_position = world.to_scene(surface_dir, PlanetConst.RADIUS_M + ground + 0.5)
		velocity = Vector3.ZERO

	if wish.length() > 0.1:
		_face(wish.normalized(), delta)
	_orient()
	_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)


func _face(dir: Vector3, delta: float) -> void:
	_facing = _facing.slerp(dir, clampf(delta * 10.0, 0.0, 1.0)).normalized()


## Keep the body upright on the sphere, facing `_facing`.
func _orient() -> void:
	var fwd := (_facing - up * _facing.dot(up))
	if fwd.length() < 0.01:
		fwd = CubeSphere.north(up)
	fwd = fwd.normalized()
	global_basis = Basis.looking_at(fwd, up)


## The spring arm is a child of the body, so express the camera heading
## relative to where the body faces.
func _yaw_relative_to_body(cam_forward: Vector3) -> float:
	var body_fwd := -global_basis.z
	return atan2(body_fwd.cross(cam_forward).dot(up), body_fwd.dot(cam_forward))


## Simple low-poly explorer: tunic, head, hood. Placeholder for a real model.
func _build_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	var tunic := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.2
	cm.radial_segments = 6
	cm.rings = 2
	tunic.mesh = cm
	tunic.position = Vector3(0, 0.75, 0)
	tunic.material_override = _flat(Color(0.55, 0.35, 0.22))
	root.add_child(tunic)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.19
	sm.height = 0.38
	sm.radial_segments = 6
	sm.rings = 3
	head.mesh = sm
	head.position = Vector3(0, 1.5, 0)
	head.material_override = _flat(Color(0.85, 0.66, 0.5))
	root.add_child(head)
	var pack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.45, 0.2)
	pack.mesh = bm
	pack.position = Vector3(0, 1.0, 0.3)
	pack.material_override = _flat(Color(0.35, 0.28, 0.2))
	root.add_child(pack)
	return root


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m

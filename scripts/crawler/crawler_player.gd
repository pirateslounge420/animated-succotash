class_name CrawlerPlayer
extends PlanetPlayer
## You, underground (design 6 Oct §ET): the open world's player
## (PlanetPlayer) on flat stone instead of a round planet. Free movement
## stays (§AU, §ET.8; grid-step is an open call, §ET.10): WASD walk, W W
## or the sprint button to sprint (movement.json's speeds), Shift crouch,
## Space jump, the mouse looks, first person only. The torch is the one
## tool (Q: torch in hand or bare hands; left click swings it, §CN); no
## bow, no spear, no fists, no climbing, no combat (§ET.1). Gravity is
## straight down (-y): the tomb is its own flat world, no planet under it.
## Footsteps sound on stone. Nothing hurts you in this slice.

## How far the bundle and the holders answer the interact button (m).
const REACH_M := 1.8


func _ready() -> void:
	floor_max_angle = deg_to_rad(WALK_MAX_DEG)
	floor_snap_length = 0.4
	up = Vector3.UP
	up_direction = Vector3.UP
	surface_dir = Vector3.UP
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.35
	_shape.height = STAND_HEIGHT
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	_shape_node.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_shape_node)
	# No body drawn in first person; an empty one keeps the crouch's
	# scaling (PlanetPlayer._set_crouch) happy.
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_spring = SpringArm3D.new()
	_spring.spring_length = 0.0
	_spring.margin = 0.05
	_spring.add_excluded_object(get_rid())
	add_child(_spring)
	_camera = Camera3D.new()
	_camera.far = 400.0
	_camera.near = 0.05
	_camera.fov = FOV
	_camera.current = true
	_spring.add_child(_camera)
	first_person = true
	footsteps = Footsteps.new()
	footsteps.name = "Footsteps"
	add_child(footsteps)
	voice = Audio3D.make("player_voice", self, "Voice")
	voice.position = Vector3(0, 1.3, 0)
	torch = Torch.new()
	torch.name = "Torch"
	add_child(torch)
	torch.setup(self)
	_apply_view()


## Stand at `pos` (scene), facing `yaw` (radians, 0 looks down -z).
func spawn_flat(pos: Vector3, yaw: float, pitch := -0.2) -> void:
	global_position = pos + Vector3(0.0, 0.05, 0.0)
	_yaw = yaw
	_pitch = pitch
	velocity = Vector3.ZERO
	rotation = Vector3(0.0, _yaw, 0.0)
	_spring.rotation = Vector3(_pitch, 0.0, 0.0)


func set_view(pitch: float, yaw: float) -> void:
	_pitch = clampf(pitch, -PITCH_MAX, PITCH_MAX)
	_yaw = yaw
	rotation = Vector3(0.0, _yaw, 0.0)
	if _spring != null:
		_spring.rotation = Vector3(_pitch, 0.0, 0.0)


## The water at your feet (m): none in the tombs yet (the flooded
## stretches come with §CJ.6), so dry unless a check sets it.
var water_depth_m := -INF


func water_depth() -> float:
	return water_depth_m


## Q: the torch in hand, or bare hands (putting a lit torch away puts it
## out, §AW).
func swap_weapon() -> void:
	if weapon == "torch":
		torch.stow()
		weapon = "hands"
	elif inventory.has_kind("torch"):
		weapon = "torch"
	torch.block_until_release()


func _unhandled_input(event: InputEvent) -> void:
	if ui_open and event is InputEventMouseButton:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click that takes the mouse doesn't also swing the torch.
		torch.block_until_release()
	elif event.is_action_pressed("weapon_swap"):
		swap_weapon()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_MAX, PITCH_MAX)


func _physics_process(delta: float) -> void:
	if typing or ui_open:
		for a in TYPING_ACTIONS:
			if InputMap.has_action(a):
				Input.action_release(a)
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		_yaw -= stick.x * STICK_SENSITIVITY * delta
		_pitch = clampf(_pitch - stick.y * STICK_SENSITIVITY * delta, -PITCH_MAX, PITCH_MAX)
	rotation = Vector3(0.0, _yaw, 0.0)
	_spring.rotation = Vector3(_pitch, 0.0, 0.0)
	var fwd := -global_basis.z
	var right := global_basis.x
	_heading = fwd
	_look = fwd.rotated(right, _pitch)
	_update_stance()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (right * input.x - fwd * input.y).limit_length(1.0)
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * speed
	var rate := ACCEL_MPS2 if wish.length() > 0.05 else FRICTION_MPS2
	if is_on_floor() or wish.length() > 0.05:
		flat = flat.move_toward(target, rate * delta * (1.0 if is_on_floor() else 0.25))
	var vy := velocity.y
	if is_on_floor():
		vy = minf(vy, 0.0)
		if Input.is_action_pressed("jump") and not crouching:
			vy = JUMP_SPEED
	else:
		vy -= (GRAVITY_UP if vy > 0.0 else GRAVITY_DOWN) * delta
		vy = maxf(vy, -MAX_FALL_MPS)
	velocity = Vector3(flat.x, vy, flat.z)
	var before := global_position
	move_and_slide()
	var moved := Vector3(global_position.x - before.x, 0.0, global_position.z - before.z).length()
	footsteps.step_update(self, moved, is_on_floor(), delta)
	var move_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	moving_state(move_speed)
	torch.update_torch(delta)


## What the body would be doing (for the steps and the snuff rules).
func moving_state(move_speed: float) -> void:
	if not is_on_floor():
		anim_state = "air"
	elif move_speed < 0.1:
		anim_state = "crouch" if crouching else "idle"
	elif crouching:
		anim_state = "crouch_walk"
	else:
		anim_state = "sprint" if sprinting else "walk"
	noise_level = 1.0 if anim_state == "sprint" else (0.1 if crouching else 0.35)

class_name CrawlerPlayer
extends PlanetPlayer
## You, underground (design 6 Oct §ET): the open world's player
## (PlanetPlayer) on flat stone instead of a round planet. Free movement
## stays (§AU, §ET.8; grid-step is an open call, §ET.10): WASD walk, W W
## or the sprint button to sprint (movement.json's speeds), Shift held to
## sneak (§FC.1, below), Space jump, the mouse looks, first person only.
## Two hands (§FB, Hands): the mouse wheel takes the torch out or puts it
## away (a lit one put away goes out), and held, Tab turns the wheel to
## the left hand and its strip of left-hand things; Q does nothing here.
## Left click swings the torch (§CN); F smothers it and you keep holding
## it (§FC.3); no bow, no spear, no fists, no climbing, no combat (§ET.1).
## Gravity is straight down (-y): the tomb is its own flat world, no planet
## under it. Footsteps sound on stone. Nothing hurts you in this slice.

## How far the bundle and the holders answer the interact button (m).
const REACH_M := 1.8

## The two hands (§FB): the wheel, Tab and the wheel, the left hand's strip.
var hands: Hands

## Sneaking (design §FC.1, data/stealth.json sneak): Shift held, the
## crouch as built (crouch speed, a tenth of the noise), finished: the view
## eases down to crouched eye height and back up over camera_ease_s (a
## smoothstep, never a snap) while the collision changes at once; a
## crouched step plays at footstep_volume of a walking step's; and on the
## floor the ledge guard (Minecraft's) keeps you from walking off a drop
## deeper than ledge_drop_m. Let go of Shift and you can step off.
static var SNEAK: Dictionary = Tuning.table("stealth").get("sneak", {})
static var EASE_S := float(SNEAK.get("camera_ease_s", 0.18))
static var LEDGE_GUARD := bool(SNEAK.get("ledge_guard", true))
static var LEDGE_DROP_M := float(SNEAK.get("ledge_drop_m", 0.5))
## The guard's probe stands this far inside the capsule's rim, so its ray
## never grazes the lip's own corner (m).
const LEDGE_SKIN_M := 0.02
## How high above your feet the probe starts, so a step or a stair rising
## ahead still counts as ground (m).
const LEDGE_UP_M := 0.45

## The view's crouch, 0 standing to 1 crouched, moving at 1 / EASE_S a
## second; the eye follows its smoothstep (eye_height).
var _crouch_k := 0.0
## Ticks the ledge guard has cut a move (the checks read it).
var ledge_holds := 0


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
	footsteps.crouch_share = float(SNEAK.get("footstep_volume", 0.25))
	add_child(footsteps)
	var key := str(SNEAK.get("key", "crouch"))
	crouch_action = key if InputMap.has_action(key) else "crouch"
	voice = Audio3D.make("player_voice", self, "Voice")
	voice.position = Vector3(0, 1.3, 0)
	torch = Torch.new()
	torch.name = "Torch"
	add_child(torch)
	torch.setup(self)
	hands = Hands.new()
	hands.name = "Hands"
	add_child(hands)
	hands.setup(self)
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


## The next thing in the right hand, as one turn of the wheel (§FB,
## Hands; putting a lit torch away puts it out, §AW). Q no longer calls it
## here (hands.json q_swaps).
func swap_weapon() -> void:
	hands.cycle("right", 1)


func _unhandled_input(event: InputEvent) -> void:
	if ui_open and event is InputEventMouseButton:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Controls.is_wheel(event):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click that takes the mouse doesn't also swing the torch.
		torch.block_until_release()
	elif hands.wheel_input(event):
		# The wheel steps a hand; with Tab held, the other one (§FB).
		pass
	elif event.is_action_pressed("weapon_swap") and Hands.q_swaps():
		swap_weapon()
	elif event.is_action_pressed("douse") and not ui_open and not dead:
		# F (design 6 Oct §FC.3): smother the lit torch in hand.
		torch.douse()
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
	_crouch_k = move_toward(_crouch_k, 1.0 if crouching else 0.0, delta / maxf(EASE_S, 0.001))
	_spring.position.y = eye_height()
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
	_ledge_guard(delta)
	var before := global_position
	move_and_slide()
	var moved := Vector3(global_position.x - before.x, 0.0, global_position.z - before.z).length()
	footsteps.step_update(self, moved, is_on_floor(), delta)
	var move_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	_loud_t = maxf(_loud_t - delta, 0.0)
	moving_state(move_speed)
	torch.update_torch(delta)
	hands.update(delta)


## A loud moment (a swing landing on a creature, §FA.1): it holds over
## your steps' noise for LOUD_HOLD_S, so whatever listens hears it.
const LOUD_HOLD_S := 0.5
var _loud := 0.0
var _loud_t := 0.0


func make_noise(level: float) -> void:
	_loud = maxf(_loud if _loud_t > 0.0 else 0.0, level)
	_loud_t = LOUD_HOLD_S
	noise_level = maxf(noise_level, level)


## What the body would be doing (for the steps, and how loud you are).
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
	if _loud_t > 0.0:
		noise_level = maxf(noise_level, _loud)


## Your eyes' height over your feet now (m): standing, crouched, or on the
## way between (§FC.1).
func eye_height() -> float:
	return lerpf(EYE_Y, CROUCH_EYE_Y, smoothstep(0.0, 1.0, _crouch_k))


func eye_position() -> Vector3:
	return global_position + up * eye_height()


## The crouch's collision changes at once (PlanetPlayer._set_crouch); the
## view keeps to its ease. Standing up waits for headroom as built, so the
## eye never rises into a low ceiling.
func _apply_view() -> void:
	super._apply_view()
	if _spring != null:
		_spring.position.y = eye_height()


## The ledge guard (design §FC.1, Minecraft's): sneaking on the floor, no
## move may carry you off a drop deeper than LEDGE_DROP_M. This tick's move
## is tried a share at a time, x and then z, against the ground under the
## capsule's leading edge, and a share that would leave support is cut
## back to the lip: pushing at an edge stops you there, pushing along it
## slides you. Not in the air, and not standing.
func _ledge_guard(delta: float) -> void:
	if not LEDGE_GUARD or not crouching or not is_on_floor() or delta <= 0.0:
		return
	var step := Vector3(velocity.x, 0.0, velocity.z) * delta
	if step.length_squared() < 1e-12:
		return
	var at := global_position
	var dx := _clip_move(at, Vector3(step.x, 0.0, 0.0))
	var dz := _clip_move(at + dx, Vector3(0.0, 0.0, step.z))
	var both := dx + dz
	# Round an outside corner, each share alone may stay on while the two
	# together carry the leading edge off its tip.
	if dx.x != 0.0 and dz.z != 0.0:
		both = _clip_move(at, both)
	if not both.is_equal_approx(step):
		ledge_holds += 1
	velocity.x = both.x / delta
	velocity.z = both.z / delta


## The part of move `v` from `at` that keeps ground under the leading edge:
## all of it, none (the edge already at the lip), or cut back to the lip.
func _clip_move(at: Vector3, v: Vector3) -> Vector3:
	if v.length_squared() < 1e-12:
		return Vector3.ZERO
	var dir := v.normalized()
	if _supported(at + v, dir):
		return v
	if not _supported(at, dir):
		return Vector3.ZERO
	var lo := 0.0
	var hi := 1.0
	for i in 6:
		var mid := (lo + hi) * 0.5
		if _supported(at + v * mid, dir):
			lo = mid
		else:
			hi = mid
	return v * lo


## Ground under the capsule's leading edge (toward `dir`) were your feet at
## `at`: anything solid from LEDGE_UP_M above your feet to LEDGE_DROP_M
## below them.
func _supported(at: Vector3, dir: Vector3) -> bool:
	var q := at + dir * (_shape.radius - LEDGE_SKIN_M)
	var ray := PhysicsRayQueryParameters3D.create(q + up * LEDGE_UP_M, q - up * LEDGE_DROP_M, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

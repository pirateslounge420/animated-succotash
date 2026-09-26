class_name PlanetPlayer
extends CharacterBody3D
## Third-person explorer on a round planet. Gravity pulls toward the
## planet's center, so "up" is recomputed every frame and the body turns to
## stand upright wherever it is.
##
## Movement (Controls has the bindings):
##   walk     6 km/h (PlanetConst.WALK_SPEED_MPS, the pace DESIGN.md's
##            biome walk-across times assume)
##   sprint   double-tap forward and keep holding it (or hold the pad's
##            left stick in); ends when forward is released
##   crouch   hold crouch (Shift): lower, slower and nearly silent
##   jump     hold to keep jumping each time you land
##   swim     in water deeper than chest height
##   climb    E facing a tree trunk: W/S up and down, A/D around it, E or
##            jump to let go (capped just into the crown)
## There is no fast travel: the world is crossed on foot.
##
## Trees (TreeContact): trunks block you, crowns you brush through or
## trunks you bump rustle, and standing under a crown is `under_canopy`
## (rain shelter).
##
## `noise_level` (0 silent .. 1 sprinting) is what wildlife hears
## (CreatureSpawner scales how close creatures let you come by it), and
## `still_time` how long you've stood still (wary animals calm down).
##
## Animation hook: `anim_state` names the current pose ("idle", "walk",
## "sprint", "crouch", "crouch_walk", "air", "swim", "climb"). The body
## (PlayerBody, an elf in a robe) is still unrigged placeholder geometry
## with Head and ArmL/ArmR pivots; a rigged model's animation tree would
## read this (and `crouching`, `sprinting`, `climbing`) instead of the
## state being re-derived.
##
## Mouse or right stick turns the camera; click the game window to capture
## the mouse, press release_mouse (Esc) to free it.

const GRAVITY := 9.8
const WALK_SPEED := PlanetConst.WALK_SPEED_MPS
const SPRINT_SPEED := 5.5
const CROUCH_SPEED := 0.8
const SWIM_SPEED := 1.6
const JUMP_SPEED := 4.6
## Two forward presses closer together than this start a sprint.
const DOUBLE_TAP_S := 0.3
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const CAMERA_Y := 1.5
const CROUCH_CAMERA_Y := 0.95
const CLIMB_SPEED := 1.1
const CLIMB_REACH_M := 1.6
const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6

var world: Node
var chunks: ChunkManager
var up := Vector3.UP
var surface_dir := Vector3.UP
var swimming := false
var sprinting := false
var crouching := false
var climbing := false
## 0 (silent) .. 1 (sprinting): how far off wildlife notices you.
var noise_level := 0.1
## Seconds since the player last moved.
var still_time := 0.0
## Current pose for animation (see the class notes).
var anim_state := "idle"
## Context prompt ("E: climb the tree"), or "".
var prompt := ""
var trees: TreeContact
var footsteps: Footsteps

var _yaw := 0.0 # camera heading around local up, radians
var _facing := Vector3.FORWARD # direction the body faces
var _pitch := -0.25
var _heading := Vector3.FORWARD # tangent direction the camera faces
var _spring: SpringArm3D
var _camera: Camera3D
var _body: PlayerBody
var _shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _last_forward_ms := -100000
var _sprint_latched := false
var _climb_chunk: TerrainChunk
var _climb_tree := -1
var _climb_y := 0.0
var _climb_out := Vector3.ZERO # unit, from the trunk's axis out to the player
var _prompt_timer := 0.0
var _shake := 0.0


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	_shape = CapsuleShape3D.new()
	_shape.radius = 0.35
	_shape.height = STAND_HEIGHT
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	_shape_node.position = Vector3(0, STAND_HEIGHT * 0.5, 0)
	add_child(_shape_node)
	_body = PlayerBody.new()
	add_child(_body)

	_spring = SpringArm3D.new()
	_spring.spring_length = 4.5
	_spring.margin = 0.2
	_spring.position = Vector3(0, CAMERA_Y, 0)
	_spring.add_excluded_object(get_rid())
	add_child(_spring)
	_camera = Camera3D.new()
	# Far enough for the high cloud layer to reach the horizon (~35 km).
	_camera.far = 60000.0
	_camera.near = 0.1
	_camera.fov = 70.0
	_camera.current = true
	_spring.add_child(_camera)
	trees = TreeContact.new()
	trees.name = "TreeContact"
	add_child(trees)
	footsteps = Footsteps.new()
	footsteps.name = "Footsteps"
	add_child(footsteps)


func camera() -> Camera3D:
	return _camera


## Stand on the ground at a surface direction, facing `look_toward` (a
## surface direction) if given.
func spawn_at(d: Vector3, look_toward := Vector3.ZERO) -> void:
	surface_dir = d
	var ground := chunks.ground_height(d)
	var water := chunks.water_level_at(d)
	global_position = world.to_scene(d, PlanetConst.RADIUS_M + maxf(ground, water) + 1.0)
	up = d
	_heading = CubeSphere.north(d)
	if look_toward != Vector3.ZERO:
		var t := look_toward - d * d.dot(look_toward)
		if t.length() > 1e-9:
			_heading = t.normalized()
	_facing = _heading
	_yaw = 0.0
	velocity = Vector3.ZERO
	_orient()


## Shake the camera (a close thunderclap); `amount` 0-1 fades over a
## second.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Point the camera: `pitch` (radians, negative looks down) and `yaw`
## relative to where the body faces.
func set_view(pitch: float, yaw: float) -> void:
	_pitch = clampf(pitch, -1.3, 0.6)
	_yaw = yaw


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
	_update_prompt(delta, cam_forward)
	_shake = maxf(_shake - delta * 1.1, 0.0)
	_camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	if climbing:
		_climb_step(delta)
		_orient()
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		_update_noise(delta, 0.0)
		trees.update_contact(delta, global_position, get_world_3d().direct_space_state)
		return

	var radius: float = world.radius_of(global_position)
	var water := chunks.water_level_at(surface_dir)
	var depth := (PlanetConst.RADIUS_M + water) - radius
	swimming = depth > 1.2

	_update_stance()
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var wish := (cam_right * input.x + cam_forward * input.y)
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if swimming:
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
		# Held jump keeps jumping each time you land.
		if Input.is_action_pressed("jump") and not crouching:
			vertical = up * JUMP_SPEED
	else:
		vertical -= up * GRAVITY * delta
	velocity = horizontal + vertical
	move_and_slide()
	for k in get_slide_collision_count():
		var col := get_slide_collision(k)
		var body := col.get_collider()
		if body is CollisionObject3D and (body as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER:
			trees.bumped(body, col.get_collider_shape_index(), horizontal.length())
	trees.update_contact(delta, global_position, get_world_3d().direct_space_state)
	var moved := get_real_velocity() - up * get_real_velocity().dot(up)
	footsteps.step_update(self, moved.length() * delta, is_on_floor(), delta)

	# Safety net: never fall through unloaded ground.
	var ground := chunks.ground_height(surface_dir)
	if radius < PlanetConst.RADIUS_M + ground - 2.0:
		global_position = world.to_scene(surface_dir, PlanetConst.RADIUS_M + ground + 0.5)
		velocity = Vector3.ZERO

	if wish.length() > 0.1:
		_face(wish.normalized(), delta)
	_orient()
	_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
	_update_noise(delta, horizontal.length())


# --- Climbing ---------------------------------------------------------------

## The climbable tree trunk right in front of the player: [chunk, index],
## or [].
func tree_ahead(forward: Vector3) -> Array:
	var from := global_position + up * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, from + forward * CLIMB_REACH_M, TerrainChunk.TREE_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider is Node:
		return []
	var chunk := (hit.collider as Node).get_parent() as TerrainChunk
	if chunk == null:
		return []
	var i := chunk.tree_for_shape(hit.collider, hit.shape)
	if i < 0 or chunk.trees[i][1] < 3.0 or not PlantMeshes.climbable(chunk.tree_species(i).shape):
		return []
	return [chunk, i]


## Start climbing the tree in front of you, if there is one.
func try_climb() -> bool:
	if climbing or swimming:
		return false
	var t := tree_ahead(_camera_forward())
	if t.is_empty():
		return false
	_climb_chunk = t[0]
	_climb_tree = t[1]
	var base := _climb_chunk.tree_base(_climb_tree)
	var tup := _climb_chunk.tree_up(_climb_tree)
	var rel := global_position - base
	_climb_y = maxf(rel.dot(tup), 0.3)
	_climb_out = (rel - tup * rel.dot(tup)).normalized()
	climbing = true
	crouching = false
	_set_crouch(false)
	velocity = Vector3.ZERO
	trees.rustle(_climb_chunk, _climb_tree, 0.6)
	return true


## Let go: drop straight down, or push off the trunk (jump).
func stop_climb(push := false) -> void:
	if not climbing:
		return
	climbing = false
	velocity = (_climb_out * 2.5 + up * 2.5) if push else Vector3.ZERO
	_climb_chunk = null
	_climb_tree = -1


func _climb_step(delta: float) -> void:
	# The chunk streamed out or left the detail ring (no trunks to hold).
	if not is_instance_valid(_climb_chunk) or not _climb_chunk.has_tree_colliders():
		stop_climb()
		return
	var h: float = _climb_chunk.trees[_climb_tree][1]
	var dims := PlantMeshes.tree_dims(_climb_chunk.tree_species(_climb_tree).shape)
	var base := _climb_chunk.tree_base(_climb_tree)
	var tup := _climb_chunk.tree_up(_climb_tree)
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	_climb_y += input.y * CLIMB_SPEED * delta
	if _climb_y < 0.25 and input.y < 0.0:
		stop_climb()
		return
	_climb_y = minf(_climb_y, h * 0.9)
	var r := clampf(dims.x * h * 0.85, 0.1, 1.6) * lerpf(1.0, 0.6, clampf(_climb_y / h, 0.0, 1.0))
	_climb_out = _climb_out.rotated(tup, -input.x * CLIMB_SPEED * delta / (r + 0.4))
	_climb_out = (_climb_out - tup * _climb_out.dot(tup)).normalized()
	global_position = base + tup * _climb_y + _climb_out * (r + 0.4)
	velocity = Vector3.ZERO
	_facing = -_climb_out
	if Input.is_action_just_pressed("jump"):
		stop_climb(true)


func _camera_forward() -> Vector3:
	return _heading.rotated(up, _yaw)


func _update_prompt(delta: float, forward: Vector3) -> void:
	_prompt_timer -= delta
	if _prompt_timer > 0.0:
		return
	_prompt_timer = 0.2
	if climbing:
		prompt = "W/S climb · A/D around the trunk · E or Space let go"
	elif not swimming and not tree_ahead(forward).is_empty():
		prompt = "E: climb the tree"
	else:
		prompt = ""


## Sprint (double-tap forward, held; or the pad's sprint button) and crouch
## (held). Crouching cancels a sprint; standing up waits for headroom.
func _update_stance() -> void:
	if Input.is_action_just_pressed("move_forward"):
		var now := Time.get_ticks_msec()
		if now - _last_forward_ms < int(DOUBLE_TAP_S * 1000.0):
			_sprint_latched = true
		_last_forward_ms = now
	if not Input.is_action_pressed("move_forward"):
		_sprint_latched = false
	var want_crouch := Input.is_action_pressed("crouch") and not swimming
	if want_crouch != crouching:
		if want_crouch or _headroom():
			_set_crouch(want_crouch)
	sprinting = not crouching and (_sprint_latched or Input.is_action_pressed("sprint"))


func _set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_shape.height = h
	_shape_node.position = Vector3(0, h * 0.5, 0)
	_spring.position = Vector3(0, CROUCH_CAMERA_Y if on else CAMERA_Y, 0)
	_body.scale = Vector3(1.0, h / STAND_HEIGHT, 1.0)


## Room to stand up (nothing solid over a crouched player's head)?
func _headroom() -> bool:
	return not test_move(global_transform, up * (STAND_HEIGHT - CROUCH_HEIGHT + 0.05))


## How loud the player is, eased so a moment's sprint lingers a little,
## plus stillness and the animation state.
func _update_noise(delta: float, move_speed: float) -> void:
	var moving := move_speed > 0.1
	still_time = 0.0 if moving or not is_on_floor() else still_time + delta
	var target := 0.08
	if swimming:
		target = 0.45
		anim_state = "swim"
	elif climbing:
		target = 0.3
		anim_state = "climb"
	elif not is_on_floor():
		target = 0.5
		anim_state = "air"
	elif crouching:
		target = 0.12 if moving else 0.0
		anim_state = "crouch_walk" if moving else "crouch"
	elif sprinting and moving:
		target = 1.0
		anim_state = "sprint"
	elif moving:
		target = 0.4
		anim_state = "walk"
	else:
		anim_state = "idle"
	noise_level = lerpf(noise_level, target, clampf(delta * (6.0 if target > noise_level else 1.5), 0.0, 1.0))
	# Robe and hair trail behind as you go.
	_body.set_motion(move_speed / SPRINT_SPEED, delta)


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


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
##            left stick in); ends when forward is released, the bow is
##            drawn or the spear raised
##   crouch   hold crouch (Shift): lower, slower and nearly silent
##   jump     hold to keep jumping each time you land
##   swim     in water deeper than chest height
##   climb    E facing a tree trunk takes the nearest handhold of its
##            branch graph you can hold (TreeContact, TreeClimb): W/S hand
##            over hand up and down the trunk, A/D round it, push toward a
##            limb at a fork to climb onto it and along it to shimmy out,
##            toward another limb within reach to reach across; slow, a
##            beat between reaches, breath and bark at the hands, never a
##            swing or a leap. E lets go, jump pushes off. A tree without
##            a graph (bamboo; one not yet in NEAR range) is climbed the
##            old way: W/S up and down its trunk, A/D around it, capped
##            just into the crown.
## Speed has momentum: it builds up and bleeds off rather than snapping, and
## in the air you keep it (ACCEL_MPS2 and the constants below it).
## There is no fast travel: the world is crossed on foot.
##
## Trees (TreeContact): trunks block you, crowns you brush through or
## trunks you bump rustle, and standing under a crown is `under_canopy`
## (rain shelter).
##
## Water (Ripples): wading, swimming and dropping in ring the water
## (_water_contacts).
##
## Weapons (spec D5): the Bow and the Spear; `weapon` says which is in
## hand, weapon_swap (Q, the pad's Y) swaps them (swap_weapon()).
##
## `noise_level` (0 silent .. 1 sprinting) is what wildlife hears
## (CreatureSpawner scales how close creatures let you come by it; loosing
## an arrow, thrusting or throwing the spear raise it for a moment,
## make_noise()), and `still_time` how long you've stood still (wary
## animals calm down).
##
## Animation hook: `anim_state` names the current pose ("idle", "walk",
## "sprint", "crouch", "crouch_walk", "air", "swim", "climb"). The body
## (PlayerBody, an elf in a robe) is unrigged placeholder geometry with
## Head and ArmL/ArmR pivots. Drop a rigged model in as
## assets/models/player.glb (ModelLibrary) and it replaces the elf, its
## clips playing by this state (ModelAnimator).
##
## Mouse or right stick turns the camera; click the game window to capture
## the mouse, press release_mouse (Esc) to free it.

const GRAVITY := 9.8
const WALK_SPEED := PlanetConst.WALK_SPEED_MPS
const SPRINT_SPEED := 5.5
const CROUCH_SPEED := 0.8
const SWIM_SPEED := 1.6
const JUMP_SPEED := 4.6
## Momentum (spec D5: the F-Zero GX / Melee spirit). On the ground speed
## builds at ACCEL_MPS2 and bleeds off at FRICTION_MPS2: a sprint takes
## about half a second to reach and a short slide to stop, and turns at
## speed are wider. In the air you keep your momentum and only steer
## (AIR_ACCEL_MPS2), so a sprinting jump carries. Water is slow both ways.
const ACCEL_MPS2 := 11.0
const FRICTION_MPS2 := 18.0
const AIR_ACCEL_MPS2 := 3.0
const SWIM_ACCEL_MPS2 := 4.0
## Two forward presses closer together than this start a sprint.
const DOUBLE_TAP_S := 0.3
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const CAMERA_Y := 1.5
const CROUCH_CAMERA_Y := 0.95
const CLIMB_SPEED := 1.1
const CLIMB_REACH_M := 1.6
## First person: eye height standing and crouched.
const EYE_Y := 1.6
const CROUCH_EYE_Y := 0.98
## Hit points; falls faster than FALL_SAFE_MPS (about a 6 m drop) hurt.
const MAX_HP := 100.0
const FALL_SAFE_MPS := 11.0
const FALL_DAMAGE_PER_MPS := 7.0
## After a hit, health comes back at REGEN_PER_S once REGEN_DELAY_S pass.
const REGEN_DELAY_S := 8.0
const REGEN_PER_S := 2.0
## Visual layer of the player's own body and its blob shadow: hidden from
## the camera in first person.
const BODY_LAYER := 1 << 10
## Blob shadow radius (m).
const BLOB_R := 0.55
const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.6

signal hurt(amount: float)
signal died

var world: Node
var chunks: ChunkManager
## Set by main: who arrows can hit.
var spawner: CreatureSpawner
var camps: Camps
var hp := MAX_HP
var dead := false
var first_person := false
var bow: Bow
var spear: Spear
## What the crosshair rests on, named (the HUD shows its binomial).
var look: LookTarget
## The weapon in hand: "bow" or "spear" (swap_weapon()).
var weapon := "bow"
var _since_hit := 99.0
var _invulnerable := 0.0
var _fall_speed := 0.0
## Horizontal momentum (m/s, along the ground): what the movement keys
## steer, as opposed to knockback and gravity.
var _move := Vector3.ZERO
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
## The player's own voice (hurt): 3D at the chest (Audio3D "player_voice").
var voice: AudioStreamPlayer3D

var _yaw := 0.0 # camera heading around local up, radians
var _facing := Vector3.FORWARD # direction the body faces
var _pitch := -0.25
var _heading := Vector3.FORWARD # tangent direction the camera faces
var _spring: SpringArm3D
var _camera: Camera3D
## The body: an imported model (ModelLibrary "player") if there is one,
## else the elf (PlayerBody).
var _body: Node3D
var _animator: ModelAnimator
## Soft shadow on the ground under the player (BlobShadow).
var _blob: MeshInstance3D
var _shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _last_forward_ms := -100000
var _sprint_latched := false
var _climb_chunk: TerrainChunk
var _climb_tree := -1
var _climb_y := 0.0
var _climb_out := Vector3.ZERO # unit, from the trunk's axis out to the player
## Climbing a branch graph (TreeContact.climb) rather than the old trunk
## climb; the first moments ease the body from where it stood onto the
## tree.
var _climb_graph := false
var _climb_from := Vector3.ZERO
var _climb_ease := 1.0
var _prompt_timer := 0.0
var _shake := 0.0
var _knock := Vector3.ZERO
var _aim_blend := 0.0
## Water contacts (Ripples): in the water last frame, and the swimming
## stroke's timer and hand.
var _in_water := false
var _stroke_t := 0.0
var _stroke_hand := 0


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
	var model := ModelLibrary.load_model("player")
	if model:
		model.name = "Body"
		_body = model
		_animator = model.get_node_or_null("Animator")
	else:
		_body = PlayerBody.new()
	add_child(_body)
	_set_layers(_body)
	_blob = BlobShadow.make(self, BLOB_R)
	_blob.layers = BODY_LAYER

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
	voice = Audio3D.make("player_voice", self, "Voice")
	voice.position = Vector3(0, 1.3, 0)
	bow = Bow.new()
	bow.name = "Bow"
	add_child(bow)
	bow.setup(self)
	_set_layers(bow)
	spear = Spear.new()
	spear.name = "Spear"
	add_child(spear)
	spear.setup(self)
	look = LookTarget.new()
	look.name = "LookTarget"
	add_child(look)
	look.setup(self, chunks)
	_apply_view()


func camera() -> Camera3D:
	return _camera


## Where the crosshair is, for the bow and the spear alike: the first
## thing a ray along the view meets (the world, trees, creatures' and
## people's parts, Hitboxes), else 400 m along it. The ray starts where the
## picture is centered: over the shoulder while aiming, the camera's
## h_offset shifts the picture, not the camera, so a ray from the camera
## itself would land 0.55 m beside the crosshair.
func crosshair_point() -> Vector3:
	var cam := camera()
	var from := cam.global_position + cam.global_basis.x * cam.h_offset + cam.global_basis.y * cam.v_offset
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0)
	q.exclude = [get_rid()]
	q.collision_mask |= Hitboxes.LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else from + dir * 400.0


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
	_move = Vector3.ZERO
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
		# The click that takes the mouse doesn't also draw the bow.
		bow.block_until_release()
		spear.block_until_release()
	elif event.is_action_pressed("weapon_swap"):
		swap_weapon()
	elif event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("toggle_view"):
		first_person = not first_person
		_apply_view()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -_pitch_limit(), 0.6 if not first_person else 1.45)


func _physics_process(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		_yaw -= stick.x * STICK_SENSITIVITY * delta
		_pitch = clampf(_pitch - stick.y * STICK_SENSITIVITY * delta, -_pitch_limit(), 0.6 if not first_person else 1.45)

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
	_update_health(delta)
	bow.update_bow(delta)
	spear.update_spear(delta)
	_update_camera(delta)
	if dead:
		_dead_step(delta)
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		return
	if climbing:
		_climb_step(delta)
		_orient()
		_update_blob(chunks.ground_height(surface_dir))
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		_update_noise(delta, 0.0)
		trees.update_contact(delta, global_position, get_world_3d().direct_space_state)
		return

	var radius: float = world.radius_of(global_position)
	var water := chunks.water_level_at(surface_dir)
	var depth := (PlanetConst.RADIUS_M + water) - radius
	swimming = depth > 1.2
	# How fast you were coming down (a splash into water).
	var sink := -velocity.dot(up)

	_update_stance()
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var wish := (cam_right * input.x + cam_forward * input.y)
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if aiming():
		# Drawing a bow (or raising the spear), you creep (as in Minecraft).
		speed = minf(speed, WALK_SPEED * 0.45)
	if swimming:
		speed = minf(speed, SWIM_SPEED)

	# Momentum: steer the current speed toward what the keys ask for rather
	# than jumping to it. Braking and reversing use friction; speeding up
	# and turning use acceleration. Off the ground, no key means no braking.
	var target := wish * speed
	var rate := ACCEL_MPS2
	if swimming:
		rate = SWIM_ACCEL_MPS2
	elif not is_on_floor():
		rate = AIR_ACCEL_MPS2
		if wish.length() < 0.1:
			target = _move
	elif target.length() < _move.length() or target.dot(_move) < 0.0:
		rate = FRICTION_MPS2
	_move -= up * _move.dot(up) # stay along the ground as "up" turns
	_move = _move.move_toward(target, rate * delta)
	# Last frame's own vertical motion, without the knock-back (added fresh
	# below each frame; carried over too, a hit's upward shove compounded
	# every airborne frame and flung the player tens of meters up). The
	# knock-back never enters _move, so it doesn't build up sideways either.
	var vertical := up * (velocity - _knock).dot(up)
	var horizontal := _move
	if swimming:
		# Float up to the surface, head above water.
		vertical = up * clampf((depth - 1.2) * 2.0, -2.0, 2.0)
		if Input.is_action_pressed("jump"):
			vertical += up * 1.5
	elif is_on_floor():
		vertical = Vector3.ZERO
		_land()
		# Held jump keeps jumping each time you land.
		if Input.is_action_pressed("jump") and not crouching:
			vertical = up * JUMP_SPEED
	else:
		vertical -= up * GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -vertical.dot(up))
	if swimming:
		_fall_speed = 0.0
	velocity = horizontal + vertical + _knock
	_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	move_and_slide()
	for k in get_slide_collision_count():
		var col := get_slide_collision(k)
		# Running into a wall or a trunk stops the part of your momentum
		# that goes into it; the rest slides along.
		var n := col.get_normal()
		if n.dot(up) < 0.7 and _move.dot(n) < 0.0:
			_move -= n * _move.dot(n)
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
	_water_contacts(delta, water, ground, moved.length(), sink)

	if first_person or aiming() or spear.busy():
		# Aiming (or seeing through your own eyes): face where you look.
		_face(cam_forward, delta * 2.0)
	elif wish.length() > 0.1:
		_face(wish.normalized(), delta)
	_orient()
	_update_blob(ground)
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


## Start climbing the tree in front of you, if there is one: on its
## branch graph from the nearest handhold you can hold, or (no graph) the
## old way up its trunk.
func try_climb() -> bool:
	if climbing or swimming:
		return false
	var t := tree_ahead(_camera_forward())
	if t.is_empty():
		return false
	_climb_chunk = t[0]
	_climb_tree = t[1]
	var g := trees.graph_of(_climb_chunk, _climb_tree)
	var hold := trees.nearest_holdable(g, global_position + up * STAND_HEIGHT) if g else -1
	_climb_graph = hold >= 0
	if _climb_graph:
		trees.climb.start(g, hold, global_position, up)
		_climb_from = global_position
		_climb_ease = 0.0
		_climb_out = trees.climb.push_dir
	var base := _climb_chunk.tree_base(_climb_tree)
	var tup := _climb_chunk.tree_up(_climb_tree)
	var rel := global_position - base
	_climb_y = maxf(rel.dot(tup), 0.3)
	_climb_out = (rel - tup * rel.dot(tup)).normalized()
	climbing = true
	crouching = false
	_set_crouch(false)
	velocity = Vector3.ZERO
	_move = Vector3.ZERO
	trees.rustle(_climb_chunk, _climb_tree, 0.6)
	return true


## Let go: drop straight down, or push off the trunk (jump).
func stop_climb(push := false) -> void:
	if not climbing:
		return
	climbing = false
	if _climb_graph:
		_climb_out = trees.climb.push_dir
		_rest_arms()
	_climb_graph = false
	velocity = (_climb_out * 2.5 + up * 2.5) if push else Vector3.ZERO
	_move = _climb_out * 2.5 if push else Vector3.ZERO
	_climb_chunk = null
	_climb_tree = -1


func _climb_step(delta: float) -> void:
	if _climb_graph:
		_graph_climb_step(delta)
		return
	# The chunk streamed out or left the detail ring (no trunks to hold).
	if not is_instance_valid(_climb_chunk) or not _climb_chunk.has_tree_colliders():
		stop_climb()
		return
	_fall_speed = 0.0
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


## On a branch graph: TreeClimb moves the hands; the body goes where it
## says (eased there from where you stood as you take hold), faces the
## way it says, and the elf's arms reach for the hands.
func _graph_climb_step(delta: float) -> void:
	_fall_speed = 0.0
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var fwd := _camera_forward()
	var c := trees.climb
	# "drop": down at the foot of the tree, step off; "lost": the tree
	# went (its chunk streamed out).
	if c.step(delta, input, fwd, fwd.cross(up), up) != "":
		stop_climb()
		return
	_climb_ease = minf(_climb_ease + delta / 0.4, 1.0)
	global_position = _climb_from.lerp(c.feet, smoothstep(0.0, 1.0, _climb_ease)) if _climb_ease < 1.0 else c.feet
	velocity = Vector3.ZERO
	if c.facing.length() > 0.1:
		_face(c.facing.normalized(), delta * 0.6)
	_climb_out = c.push_dir
	_orient()
	_reach_arms(c.hands)
	trees.climb_sounds(global_position + up * EYE_Y)
	if Input.is_action_just_pressed("jump"):
		stop_climb(true)


## The elf's arms reach for `hands` (scene; left, right): each arm points
## from its shoulder at its hand and stretches or shortens a little to put
## the hand on it (the elf has no elbows). An imported model plays its
## "climb" clip instead.
func _reach_arms(hands: Array[Vector3]) -> void:
	if not _body is PlayerBody:
		return
	var inv := _body.global_transform.affine_inverse()
	var arms := (_body as PlayerBody).arms
	for s in 2:
		var arm := arms[s]
		var d := inv * hands[s] - arm.position
		var length := d.length()
		if length < 1e-3:
			continue
		var y := -d / length
		var x := Vector3.RIGHT - y * y.dot(Vector3.RIGHT)
		x = x.normalized() if x.length() > 0.1 else y.cross(Vector3.BACK).normalized()
		var z := x.cross(y)
		arm.transform.basis = Basis(x, y * clampf(length / TreeClimb.ARM_M, 0.4, 1.3), z)


## Where each of the elf's hands is (scene), for tests.
func hand_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _body is PlayerBody:
		for arm in (_body as PlayerBody).arms:
			out.append(arm.global_transform * Vector3(0, -TreeClimb.ARM_M, 0))
	return out


## The arms back at the sides (letting go of a tree).
func _rest_arms() -> void:
	if not _body is PlayerBody:
		return
	var arms := (_body as PlayerBody).arms
	for s in 2:
		arms[s].transform.basis = Basis.IDENTITY
		arms[s].rotation = Vector3(0.06, 0.0, 0.13 * (1.0 if s == 1 else -1.0))


func _camera_forward() -> Vector3:
	return _heading.rotated(up, _yaw)


func _update_prompt(delta: float, forward: Vector3) -> void:
	_prompt_timer -= delta
	if _prompt_timer > 0.0:
		return
	_prompt_timer = 0.2
	if climbing and _climb_graph:
		prompt = trees.climb.prompt
	elif climbing:
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
	if not Input.is_action_pressed("move_forward") or aiming():
		_sprint_latched = false
	var want_crouch := Input.is_action_pressed("crouch") and not swimming
	if want_crouch != crouching:
		if want_crouch or _headroom():
			_set_crouch(want_crouch)
	sprinting = not crouching and not aiming() and (_sprint_latched or Input.is_action_pressed("sprint"))


func _set_crouch(on: bool) -> void:
	crouching = on
	var h := CROUCH_HEIGHT if on else STAND_HEIGHT
	_shape.height = h
	_shape_node.position = Vector3(0, h * 0.5, 0)
	_apply_view()
	_body.scale = Vector3(1.0, h / STAND_HEIGHT, 1.0)


# --- Health -----------------------------------------------------------------

## Hit for `amount` by something at scene position `from_pos` (a bite, a
## blow): knocked back a little, and the camera jolts.
func take_hit(amount: float, from_pos: Vector3) -> void:
	if dead or _invulnerable > 0.0:
		return
	var away := global_position - from_pos
	away = (away - up * away.dot(up)).normalized()
	_knock = away * 5.0 + up * 2.5
	_damage(amount)


func _damage(amount: float) -> void:
	if dead or _invulnerable > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_since_hit = 0.0
	shake(clampf(amount / 30.0, 0.2, 0.8))
	voice.stream = SoundSynth.stream("hurt", randi())
	voice.play()
	hurt.emit(amount)
	if hp <= 0.0:
		dead = true
		bow.drawing = false
		spear.cancel()
		stop_climb()
		died.emit()


## Back on your feet at full health (main.respawn()); a few seconds'
## grace before anything can hurt you again.
func revive() -> void:
	dead = false
	hp = MAX_HP
	_since_hit = 99.0
	_invulnerable = 3.0
	_fall_speed = 0.0
	_knock = Vector3.ZERO
	_body.rotation = Vector3.ZERO


func _update_health(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_since_hit += delta
	if not dead and _since_hit > REGEN_DELAY_S and hp < MAX_HP:
		hp = minf(hp + REGEN_PER_S * delta, MAX_HP)


## Landing: a hard enough fall hurts.
func _land() -> void:
	if _fall_speed > FALL_SAFE_MPS:
		_damage((_fall_speed - FALL_SAFE_MPS) * FALL_DAMAGE_PER_MPS)
	_fall_speed = 0.0


## Dead: you slump to the ground and lie still (main respawns you).
func _dead_step(delta: float) -> void:
	velocity = -up * GRAVITY * 0.5 if not is_on_floor() else Vector3.ZERO
	move_and_slide()
	_body.rotation.x = lerpf(_body.rotation.x, -PI * 0.5, clampf(delta * 3.0, 0.0, 1.0))
	_orient()


# --- View ---------------------------------------------------------------------

## Third person (the camera on a spring arm behind you) or first person
## (at your eyes, your own body hidden from the camera but still casting
## its shadow).
func _apply_view() -> void:
	if _spring == null:
		return
	if first_person:
		_spring.spring_length = 0.0
		_spring.position = Vector3(0, CROUCH_EYE_Y if crouching else EYE_Y, 0)
		_camera.cull_mask &= ~BODY_LAYER
		_pitch = clampf(_pitch, -_pitch_limit(), 1.45)
	else:
		_spring.spring_length = 4.5
		_spring.position = Vector3(0, CROUCH_CAMERA_Y if crouching else CAMERA_Y, 0)
		_camera.cull_mask |= BODY_LAYER
		_pitch = clampf(_pitch, -_pitch_limit(), 0.6)


func _pitch_limit() -> float:
	return 1.45 if first_person else 1.3


## Per frame: shake, and in third person the over-the-shoulder aim while
## drawing (the camera closes in and steps right); a slight zoom at full
## draw.
func _update_camera(delta: float) -> void:
	_shake = maxf(_shake - delta * 1.1, 0.0)
	var over_shoulder := aiming() and not first_person
	_aim_blend = move_toward(_aim_blend, 1.0 if over_shoulder else 0.0, delta * 5.0)
	if not first_person:
		_spring.spring_length = lerpf(4.5, 2.4, _aim_blend)
	_camera.h_offset = 0.55 * _aim_blend + randf_range(-1.0, 1.0) * _shake * 0.12
	_camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	_camera.fov = lerpf(70.0, 60.0, aim_power())
	# The elf raises both arms to aim the bow, the right one to hold and
	# throw the spear (an imported model has its own clips); on a branch
	# graph they hold the tree (_reach_arms()).
	if _body is PlayerBody and not (climbing and _climb_graph):
		var spear_arm := spear.arm_angle()
		for arm in (_body as PlayerBody).arms:
			var want := 1.35 if bow.drawing else 0.06
			if arm.name == "ArmR" and not is_nan(spear_arm):
				want = spear_arm
			arm.rotation.x = lerpf(arm.rotation.x, want, clampf(delta * 10.0, 0.0, 1.0))


## Keep the blob shadow on the ground (`ground`: its height at the
## player's spot): it shrinks as you jump or climb and is gone in deep
## water or high up.
func _update_blob(ground: float) -> void:
	var h: float = world.radius_of(global_position) - (PlanetConst.RADIUS_M + ground)
	_blob.visible = not swimming and h < 3.0
	if _blob.visible:
		var k := maxf(1.0 - maxf(h, 0.0) / 3.0, 0.001)
		_blob.position.y = BlobShadow.LIFT - h
		_blob.scale = Vector3(BLOB_R * k, 1.0, BLOB_R * k)


## Water contacts (Ripples): dropping into water (a jump or a fall)
## splashes with the whole body, harder the faster you come down, while
## wading in from the bank is just a step; wading legs drag a wake, and
## each step plants a splash (Footsteps, foot_splash()); a swimmer's body
## drags a wake and the hands splash as they stroke. Masses, the drop
## speed and the stroke's rhythm: data/water/ripples.json "contacts".
func _water_contacts(delta: float, water: float, ground: float, speed: float, sink: float) -> void:
	var r: float = world.radius_of(global_position)
	var surface_r := PlanetConst.RADIUS_M + water
	var wet := water > ground + 0.03 and r < surface_r + 0.02
	if not wet or not Ripples.near(global_position):
		_in_water = wet
		return
	var surface := global_position + up * (surface_r - r)
	var mass := RippleSim.contact("player_kg")
	if not _in_water:
		if sink > RippleSim.contact("player_drop_mps"):
			Ripples.splash(surface, mass, sink)
		else:
			Ripples.splash(surface, RippleSim.contact("player_foot_kg"), maxf(speed, 1.0))
	_in_water = true
	var key := get_instance_id() * 8
	var right := global_basis.x
	if swimming:
		Ripples.wake(key, surface, mass, speed)
		_stroke_t -= delta
		if speed > 0.3 and _stroke_t <= 0.0:
			_stroke_t = RippleSim.contact("player_stroke_s")
			_stroke_hand = 1 - _stroke_hand
			var side := 0.3 if _stroke_hand == 0 else -0.3
			Ripples.splash(surface - global_basis.z * 0.5 + right * side, RippleSim.contact("player_hand_kg"), speed + 1.0)
	else:
		Ripples.wake(key + 1, surface - right * 0.12, mass * 0.5, speed)
		Ripples.wake(key + 2, surface + right * 0.12, mass * 0.5, speed)


## A foot coming down in water (Footsteps, each step while wading): a
## small splash, the feet taking turns by `n`.
func foot_splash(n: int) -> void:
	var r: float = world.radius_of(global_position)
	var surface := global_position + up * (PlanetConst.RADIUS_M + chunks.water_level_at(surface_dir) - r)
	var side := 0.12 if n % 2 == 0 else -0.12
	Ripples.splash(surface + global_basis.x * side, RippleSim.contact("player_foot_kg"), maxf(get_real_velocity().length(), 1.0))


## Put a body (and all it holds) on the player's own visual layer.
static func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = BODY_LAYER
	for c in n.get_children():
		_set_layers(c)


## Room to stand up (nothing solid over a crouched player's head)?
func _headroom() -> bool:
	return not test_move(global_transform, up * (STAND_HEIGHT - CROUCH_HEIGHT + 0.05))


# --- Weapons ------------------------------------------------------------------

## Drawing the bow or raising the spear (you creep, no sprint, the camera
## comes over your shoulder).
func aiming() -> bool:
	return bow.drawing or spear.raising


## 0-1: how hard the drawn bow or raised spear would fly.
func aim_power() -> float:
	if bow.drawing:
		return bow.power()
	return spear.power() if spear.raising else 0.0


## Bow to spear and back (weapon_swap), dropping any draw; holding
## `shoot` through a swap does nothing until it's let go.
func swap_weapon() -> void:
	bow.drawing = false
	bow.charge = 0.0
	spear.cancel()
	bow.block_until_release()
	spear.block_until_release()
	weapon = "spear" if weapon == "bow" else "bow"


## A sudden loud moment (loosing an arrow, a thrust, a throw): the noise
## wildlife hears jumps to at least `level` and eases back down.
func make_noise(level: float) -> void:
	noise_level = maxf(noise_level, level)


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
	# Robe and hair trail behind as you go (the elf); an imported model
	# plays the clip for the pose.
	if _body is PlayerBody:
		(_body as PlayerBody).set_motion(move_speed / SPRINT_SPEED, delta)
	elif _animator:
		var rate := 1.0
		if anim_state == "walk" or anim_state == "sprint" or anim_state == "crouch_walk":
			rate = clampf(move_speed / (SPRINT_SPEED if anim_state == "sprint" else WALK_SPEED), 0.6, 1.6)
		_animator.set_state(anim_state, rate)


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


class_name PlanetPlayer
extends CharacterBody3D
## Explorer on a round planet, seen in first person by default (V or F5:
## third person). Gravity pulls toward the
## planet's center, so "up" is recomputed every frame and the body turns to
## stand upright wherever it is.
##
## Movement (Controls has the bindings):
##   walk     5.5 m/s (the designer's first play: the old sprint became
##            the walk; DESIGN.md's walk-across times still use
##            PlanetConst.WALK_SPEED_MPS, 6 km/h)
##   sprint   8.8 m/s, 1.6 times the walk: double-tap forward and keep
##            holding it (or hold the pad's
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

## Every tunable movement number comes from data/movement.json (Tuning;
## the designer edits the table, spec A2). The feel is Melee's spacies:
## heavy gravity with a fast-fall, a short snappy jump, fast ground
## acceleration with a little traction slide on stop (longer on snow, ice
## and wet ground), an instant turn-around with a brief skid, air control
## that steers only a little way off your take-off speed (a jump commits
## you), a couple of frames of landing squat (more after a fall of more
## than a body length); a sprint carries into a longer slide and a longer
## jump. See the table's "_help" for each number.
static var GRAVITY := Tuning.num("movement", "air", "gravity_mps2")
static var WALK_SPEED := Tuning.num("movement", "speed", "walk_mps")
static var SPRINT_SPEED := Tuning.num("movement", "speed", "sprint_mps")
static var CROUCH_SPEED := Tuning.num("movement", "speed", "sneak_mps")
## Creeping with the bow drawn or the spear raised (on the ground).
static var AIM_SPEED := Tuning.num("movement", "speed", "aim_mps")
static var SWIM_SPEED := Tuning.num("movement", "speed", "swim_mps")
static var JUMP_SPEED := Tuning.num("movement", "air", "jump_mps")
static var SPRINT_JUMP := Tuning.num("movement", "air", "sprint_jump")
static var FAST_FALL_MPS := Tuning.num("movement", "air", "fast_fall_mps")
static var MAX_FALL_MPS := Tuning.num("movement", "air", "max_fall_mps")
static var ACCEL_MPS2 := Tuning.num("movement", "ground", "accel_mps2")
static var FRICTION_MPS2 := Tuning.num("movement", "ground", "friction_mps2")
static var TURNAROUND_KEEP := Tuning.num("movement", "ground", "turnaround_keep")
static var TURNAROUND_MIN_MPS := Tuning.num("movement", "ground", "turnaround_min_mps")
static var AIR_ACCEL_MPS2 := Tuning.num("movement", "air", "air_accel_mps2")
static var AIR_STEER_MPS := Tuning.num("movement", "air", "air_steer_mps")
static var SWIM_ACCEL_MPS2 := Tuning.num("movement", "speed", "swim_accel_mps2")
static var SQUAT_S := Tuning.num("movement", "landing", "squat_s")
static var HEAVY_SQUAT_S := Tuning.num("movement", "landing", "heavy_squat_s")
static var HEAVY_FALL_M := Tuning.num("movement", "landing", "heavy_fall_m")
static var SQUAT_DIP_M := Tuning.num("movement", "landing", "dip_m")
## Wall jump (right click in the air by a steep face; _wall_jump()).
static var WJ_WINDOW_S := Tuning.num("movement", "wall_jump", "window_s")
static var WJ_SPEED := Tuning.num("movement", "wall_jump", "speed_mps")
static var WJ_ANGLE := deg_to_rad(Tuning.num("movement", "wall_jump", "angle_deg"))
static var WJ_DECAY := Tuning.num("movement", "wall_jump", "chain_decay")
static var WJ_STEEP := Tuning.num("movement", "wall_jump", "min_wall_steepness")
static var WJ_NOISE_M := Tuning.num("movement", "wall_jump", "noise_m")
## How long a hand takes to reach for something and come back (grab_toward).
static var GRAB_S := Tuning.num("movement", "climb", "grab_s")
## Unstick rule (_unstick): barely moving (under STUCK_MPS) while pushing
## against two or more colliders for STUCK_S, you're nudged UNSTICK_M free.
static var STUCK_S := Tuning.num("movement", "unstick", "stall_s")
static var STUCK_MPS := Tuning.num("movement", "unstick", "stall_mps")
static var UNSTICK_M := Tuning.num("movement", "unstick", "nudge_m")
static var JAM_S := Tuning.num("movement", "unstick", "ground_jam_s")
## The camera looks all the way up and all the way down, in first person and
## orbiting in third (a hair short of vertical so the view never flips).
const PITCH_MAX := PI * 0.5 - 0.002
static var DOUBLE_TAP_S := Tuning.num("movement", "speed", "double_tap_s")
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const CAMERA_Y := 1.5
const CROUCH_CAMERA_Y := 0.95
static var CLIMB_SPEED := Tuning.num("movement", "climb", "simple_mps")
static var CLIMB_REACH_M := Tuning.num("movement", "climb", "reach_m")
## First person: eye height standing and crouched.
const EYE_Y := 1.6
const CROUCH_EYE_Y := 0.98
## Hit points; a drop of more than FALL_SAFE_M hurts (by the height, so a
## fast-fall out of a hop doesn't).
const MAX_HP := 100.0
static var FALL_SAFE_M := Tuning.num("movement", "fall_damage", "safe_m")
static var FALL_DAMAGE_PER_M := Tuning.num("movement", "fall_damage", "per_m")
## Health never comes back on its own: only resting by a lit fire
## (_update_health()), and cooked food and camp medicine (heal()).
## data/combat.json "healing" has the numbers.
## Visual layer of the player's own body and its blob shadow: hidden from
## the camera in first person.
const BODY_LAYER := 1 << 10
## Blob shadow radius (m).
const BLOB_R := 0.55
static var MOUSE_SENSITIVITY := Tuning.num("movement", "camera", "mouse_sensitivity")
static var STICK_SENSITIVITY := Tuning.num("movement", "camera", "stick_sensitivity")

signal hurt(amount: float)
signal died

var world: Node
var chunks: ChunkManager
## Set by main: who arrows can hit.
var spawner: CreatureSpawner
var camps: Camps
var hp := MAX_HP
var dead := false
var first_person := true
var _grab_at := Vector3.ZERO
## Movement state (Melee-spacie feel, wall jump).
var _takeoff := Vector3.ZERO
var _jumped := false
var _was_on_floor := true
var _squat_t := 0.0
var _squat_len := 0.0
var _squat_dip := 0.0
var _traction := 1.0
var _traction_t := 0.0
var _wall_t := INF
var _wall_n := Vector3.ZERO
var _wall_in := Vector3.ZERO
var _wj_chain := 0
var _kick_t := 0.0
static var KICK_S := Tuning.num("movement", "wall_jump", "kick_s")
## How wet the ground is from rain, 0-1 (main sets it from the weather).
var ground_wet := 0.0
## Counters the tests read.
var skids := 0
var landings := 0
var wall_jumps := 0
var _stuck_t := 0.0
## How many times the unstick rule has freed you (tests read it).
var unsticks := 0
var _grab_t := 0.0
var bow: Bow
var spear: Spear
## What the crosshair rests on, named (the HUD shows its binomial).
var look: LookTarget
## What you carry and wear (Inventory; the screen on I). Past the movement
## table's burden.free_items carried things you're slower, climb slower
## and are louder (burden_*()).
var inventory := Inventory.new()
## The inventory screen is open (main sets it): the mouse is free for it.
var ui_open := false
## The dotted arc of where the shot will go, while drawing or raising.
var aim_arc: AimArc
## The weapon in hand: "bow" or "spear" (swap_weapon()).
var weapon := "bow"
var _since_hit := 99.0
## Resting at a fire (_update_health()): a lit campfire within reach, and
## healing now; health healed so far by each source (tests, heal()).
var near_fire := false
var resting := false
var healed_by := {}
var _fire_check_t := 0.0
var _invulnerable := 0.0
var _fall_speed := 0.0
## Distance from the planet's center at the top of this fall (the highest
## point since you last stood, swam, climbed or wall-jumped).
var _fall_top := -INF
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
	aim_arc = AimArc.new()
	aim_arc.name = "AimArc"
	aim_arc.player = self
	add_child(aim_arc)
	# Your bow and spear, worn (the inventory's ranged and melee slots).
	inventory.wear(Inventory.make("bow"))
	inventory.wear(Inventory.make("spear"))
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
	_pitch = clampf(pitch, -PITCH_MAX, PITCH_MAX)
	_yaw = yaw


func _unhandled_input(event: InputEvent) -> void:
	# A screen that wants the mouse (the inventory) is open: clicks are its.
	if ui_open and event is InputEventMouseButton:
		return
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
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_MAX, PITCH_MAX)


func _physics_process(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		_yaw -= stick.x * STICK_SENSITIVITY * delta
		_pitch = clampf(_pitch - stick.y * STICK_SENSITIVITY * delta, -PITCH_MAX, PITCH_MAX)

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
	aim_arc.update_arc()
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
	var on_floor := is_on_floor()
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if aiming() and on_floor:
		# Drawing a bow (or raising the spear) on the ground, you creep; in
		# the air it changes nothing (a jump or wall jump carries on).
		speed = minf(speed, AIM_SPEED)
	if swimming:
		speed = minf(speed, SWIM_SPEED)
	speed *= burden_speed()
	if on_floor:
		_traction_t -= delta
		if _traction_t <= 0.0:
			_traction_t = 0.2
			_traction = _traction_under()

	# Momentum, Melee-spacie: fast ground acceleration and a short traction
	# slide on stop (slidier on sand, snow, ice and wet ground); pushing the
	# other way at speed skids briefly, then goes; in the air you steer only
	# a little way off your take-off speed, so a jump commits you; landing,
	# a couple of frames of squat with no steering.
	var target := wish * speed
	var rate := ACCEL_MPS2 * _traction
	_move -= up * _move.dot(up) # stay along the ground as "up" turns
	if swimming:
		rate = SWIM_ACCEL_MPS2
	elif not on_floor:
		if _was_on_floor and not _jumped:
			_takeoff = _move # ran off a ledge
		var air_speed := maxf(_takeoff.length(), speed)
		var steer := (wish * air_speed - _takeoff).limit_length(AIR_STEER_MPS) if wish.length() > 0.1 else Vector3.ZERO
		target = _takeoff + steer
		rate = AIR_ACCEL_MPS2
	else:
		if _squat_t > 0.0:
			target = Vector3.ZERO
		elif wish.length() > 0.1 and _move.length() > TURNAROUND_MIN_MPS and wish.normalized().dot(_move.normalized()) < -0.5:
			# Turn-around: a brief skid, then off the other way.
			_move *= TURNAROUND_KEEP
			skids += 1
			footsteps.scuff(self)
		if target.length() < _move.length() or target.dot(_move) < 0.0:
			rate = FRICTION_MPS2 * _traction
	_move = _move.move_toward(target, rate * delta)
	# Last frame's own vertical motion, without the knock-back (added fresh
	# below each frame; carried over too, a hit's upward shove compounded
	# every airborne frame and flung the player tens of meters up). The
	# knock-back never enters _move, so it doesn't build up sideways either.
	var vy := (velocity - _knock).dot(up)
	var horizontal := _move
	if swimming:
		# Float up to the surface, head above water.
		vy = clampf((depth - 1.2) * 2.0, -2.0, 2.0)
		if Input.is_action_pressed("jump"):
			vy += 1.5
		_jumped = false
	elif on_floor:
		vy = 0.0
		if not _was_on_floor:
			_land()
		_jumped = false
		_wj_chain = 0
		_squat_t = maxf(_squat_t - delta, 0.0)
		# Held jump keeps jumping each time you land (after the squat).
		if Input.is_action_pressed("jump") and not crouching and _squat_t <= 0.0:
			vy = JUMP_SPEED * (SPRINT_JUMP if sprinting else 1.0)
			_takeoff = _move
			_jumped = true
	else:
		vy -= GRAVITY * delta
		# Fast-fall: crouch (down) after the apex drops you at once.
		if Input.is_action_pressed("crouch") and vy < 0.5:
			vy = minf(vy, -FAST_FALL_MPS)
		vy = maxf(vy, -MAX_FALL_MPS)
		_fall_speed = maxf(_fall_speed, -vy)
		_fall_top = maxf(_fall_top, radius)
	if swimming:
		_fall_speed = 0.0
	if swimming or on_floor:
		_fall_top = radius
	# Wall jump (right click) off a face touched in the air just now.
	if Input.is_action_just_pressed("wall_jump") and not on_floor and not swimming:
		var kick := _wall_jump()
		if kick != Vector3.INF:
			horizontal = _move
			vy = kick.dot(up)
	_was_on_floor = on_floor
	velocity = horizontal + up * vy + _knock
	_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	var before := horizontal
	move_and_slide()
	_wall_t += delta
	for k in get_slide_collision_count():
		var col := get_slide_collision(k)
		# Running into a wall or a trunk stops the part of your momentum
		# that goes into it; the rest slides along.
		var n := col.get_normal()
		if n.dot(up) < 0.7 and _move.dot(n) < 0.0:
			_move -= n * _move.dot(n)
			if not is_on_floor() and _takeoff.dot(n) < 0.0:
				_takeoff -= n * _takeoff.dot(n)
		# A steep face touched in the air: a wall jump may kick off it for
		# WJ_WINDOW_S (cliff, trunk, ruin wall, boulder).
		if absf(n.dot(up)) < WJ_STEEP and not is_on_floor():
			_wall_n = n
			# The approach: what you were moving at when you first met it
			# (after that the slide has already turned you along it).
			if _wall_t > delta * 1.5 or _wall_in == Vector3.ZERO:
				_wall_in = before if before.length() > 0.5 else -n
			_wall_t = 0.0
		var body := col.get_collider()
		if body is CollisionObject3D and (body as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER:
			trees.bumped(body, col.get_collider_shape_index(), horizontal.length())
	_update_squat(delta)
	trees.update_contact(delta, global_position, get_world_3d().direct_space_state)
	var moved := get_real_velocity() - up * get_real_velocity().dot(up)
	_unstick(delta, wish, moved)
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
		trees.climb.speed_scale = burden_climb()
		_graph_climb_step(delta)
		return
	# The chunk streamed out or left the detail ring (no trunks to hold).
	if not is_instance_valid(_climb_chunk) or not _climb_chunk.has_tree_colliders():
		stop_climb()
		return
	_fall_speed = 0.0
	_fall_top = -INF
	var h: float = _climb_chunk.trees[_climb_tree][1]
	var dims := PlantMeshes.tree_dims(_climb_chunk.tree_species(_climb_tree).shape)
	var base := _climb_chunk.tree_base(_climb_tree)
	var tup := _climb_chunk.tree_up(_climb_tree)
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	_climb_y += input.y * CLIMB_SPEED * burden_climb() * delta
	if _climb_y < 0.25 and input.y < 0.0:
		stop_climb()
		return
	_climb_y = minf(_climb_y, h * 0.9)
	var r := clampf(dims.x * h * 0.85, 0.1, 1.6) * lerpf(1.0, 0.6, clampf(_climb_y / h, 0.0, 1.0))
	_climb_out = _climb_out.rotated(tup, -input.x * CLIMB_SPEED * burden_climb() * delta / (r + 0.4))
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
	_fall_top = -INF
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
	var hands := c.hands.duplicate()
	if _grab_t > 0.0:
		_grab_t -= delta
		var s := 0 if hands[0].distance_to(_grab_at) < hands[1].distance_to(_grab_at) else 1
		hands[s] = hands[s].lerp(_grab_at, sin(clampf(1.0 - _grab_t / GRAB_S, 0.0, 1.0) * PI))
	_reach_arms(hands)
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


## Unstick rule: pressed against two or more colliders at once (a trunk
## and a bush stem, say), trying to move and barely moving for STUCK_S, the
## capsule is nudged UNSTICK_M out along the nearest free direction to the
## one you're pushing (of 16 round you, tested with test_move), or up if
## none is free. Never while swimming or climbing.
func _unstick(delta: float, wish: Vector3, moved: Vector3) -> void:
	# Stuck is: touching something and going nowhere, either
	#  - wedged between two or more walls (a trunk and a shrub's stem),
	#  - held off the ground by something (under a root, in a fork), or
	#  - caught on a crease of the ground's own collision mesh.
	# One trunk or wall head-on, standing, isn't being stuck: you just turn.
	if swimming or climbing or dead or get_slide_collision_count() == 0:
		_stuck_t = 0.0
		return
	var normals: Array[Vector3] = []
	var away := Vector3.ZERO
	for k in get_slide_collision_count():
		var n := get_slide_collision(k).get_normal()
		if n.dot(up) < 0.7:
			away += n
			if normals.all(func(m: Vector3) -> bool: return m.dot(n) < 0.85):
				normals.append(n)
	var walls := normals.size() # distinct walls, not contacts
	var real := get_real_velocity()
	var still := moved.length() < STUCK_MPS and absf(real.dot(up)) < STUCK_MPS
	var pushing := wish.length() > 0.1
	var floor_now := is_on_floor()
	var kind := ""
	if walls >= 2:
		kind = "wedge" if pushing or not floor_now else ""
	elif not floor_now:
		kind = "hung"
	elif walls == 0 and pushing:
		kind = "crease"
	if kind == "" or not still:
		_stuck_t = 0.0
		return
	_stuck_t += delta
	# Caught on the ground alone, free yourself almost at once (a hitch you
	# barely feel); otherwise after STUCK_S.
	if _stuck_t < (JAM_S if kind == "crease" else STUCK_S):
		return
	_stuck_t = 0.0
	unsticks += 1
	# Which way out: where you're pushing, else away from what holds you.
	var want := wish - up * wish.dot(up)
	if want.length() < 0.1:
		want = away - up * away.dot(up)
	if want.length() < 0.1:
		want = -_camera_forward()
	want = want.normalized()
	var side := want.cross(up).normalized()
	var best := Vector3.ZERO
	var best_dot := -INF
	# Tried from a hair above the ground, so the ground itself isn't in the way.
	var lifted := global_transform.translated(up * 0.05)
	for k in 16:
		var a := TAU * k / 16.0
		var d := (want * cos(a) + side * sin(a)).normalized()
		if test_move(lifted, d * UNSTICK_M):
			continue
		if d.dot(want) > best_dot:
			best_dot = d.dot(want)
			best = d
	if best == Vector3.ZERO:
		global_position += up * 0.3
	elif kind == "crease":
		# Off the ground's crease: a hop of a couple of frames' travel,
		# keeping your speed, so it reads as a stumble, not a jump.
		global_position += up * 0.05 + best * clampf(_move.length() * delta * 2.0, 0.1, UNSTICK_M)
	else:
		global_position += up * 0.05 + best * UNSTICK_M
		_move = best * minf(_move.length(), WALK_SPEED * 0.5)
	if kind == "hung":
		velocity -= up * velocity.dot(up)


## Where your reach is measured from: your chest, or while climbing the
## middle of your two hands (you take things from the tree).
func reach_from() -> Vector3:
	if climbing and _climb_graph:
		var c := trees.climb
		return (c.hands[0] + c.hands[1]) * 0.5
	return global_position + up * 0.9


## Take something at `point`: while climbing, the hand nearer it lets go of
## the wood and reaches for it for a moment (GRAB_S) while the other hand
## holds on.
func grab_toward(point: Vector3) -> void:
	_grab_at = point
	_grab_t = GRAB_S


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
		# Game time, not the wall clock (a slow frame doesn't break the tap).
		var now := int(Engine.get_physics_frames() * 1000 / Engine.physics_ticks_per_second)
		if now - _last_forward_ms < int(DOUBLE_TAP_S * 1000.0):
			_sprint_latched = true
		_last_forward_ms = now
	# Drawing the bow or raising the spear no longer ends a sprint (it
	# slows you on the ground instead: the movement step).
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
	_fall_top = -INF
	_knock = Vector3.ZERO
	_body.rotation = Vector3.ZERO


## No regeneration. Resting at a fire heals: standing or crouching still
## on the ground (not climbing, swimming or aiming) for rest_still_s
## within rest_radius_m of a lit campfire (Campfire.lit_near(), checked a
## few times a second), health comes back at rest_hp_per_s
## (data/combat.json "healing").
func _update_health(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_since_hit += delta
	var rules := Hits.healing()
	_fire_check_t -= delta
	if _fire_check_t <= 0.0:
		_fire_check_t = 0.25
		near_fire = Campfire.lit_near(get_tree(), global_position, float(rules.rest_radius_m))
	resting = near_fire and not dead and not climbing and not swimming and not aiming() \
		and is_on_floor() and still_time >= float(rules.rest_still_s)
	if resting and hp < MAX_HP:
		heal(float(rules.rest_hp_per_s) * delta, "rest")


## Health back (up to MAX_HP): `amount` from `source` ("rest" at a fire;
## hooks for Phase 10's inventory: "cooked_food" and "camp_medicine",
## whose usual amounts are data/combat.json healing.sources, heal_for()).
## Returns what was actually healed.
func heal(amount: float, source: String) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var before := hp
	hp = minf(hp + amount, MAX_HP)
	healed_by[source] = float(healed_by.get(source, 0.0)) + hp - before
	return hp - before


## A healing source's usual amount (data/combat.json healing.sources;
## 0 for one it doesn't list).
static func heal_for(source: String) -> float:
	return float((Hits.healing().sources as Dictionary).get(source, 0.0))


## Landing: a hard enough fall hurts.
func _land() -> void:
	var fell := maxf(_fall_top - world.radius_of(global_position), 0.0) if _fall_top > -INF else 0.0
	if fell > FALL_SAFE_M:
		_damage((fell - FALL_SAFE_M) * FALL_DAMAGE_PER_M)
	# A couple of frames of landing squat after a jump or a real drop; more
	# after a fall of more than a body length. Running over a bump (off the
	# ground for a frame or two) isn't a landing.
	if _jumped or fell > Tuning.num("movement", "landing", "min_drop_m"):
		_squat_t = HEAVY_SQUAT_S if fell > HEAVY_FALL_M else SQUAT_S
		_squat_len = _squat_t
		landings += 1
	_fall_speed = 0.0
	_fall_top = -INF


## Wall jump: in the air within WJ_WINDOW_S of touching a steep face,
## kick off it back the way you came (the reversed approach, turned away
## from the face if it pointed along it), angled WJ_ANGLE up at WJ_SPEED;
## each further wall jump before you land keeps WJ_DECAY of the last one's
## upward speed. A short kick of the body and a scuff creatures hear.
## Returns the kick's velocity, or INF if there was no wall to kick off.
func _wall_jump() -> Vector3:
	if climbing or _wall_t > WJ_WINDOW_S:
		return Vector3.INF
	var n_h := _wall_n - up * _wall_n.dot(up)
	n_h = n_h.normalized() if n_h.length() > 0.1 else -_camera_forward()
	var away := -(_wall_in - up * _wall_in.dot(up))
	away = away.normalized() if away.length() > 0.1 else n_h
	if away.dot(n_h) < 0.3:
		away = (away + n_h * (0.3 - away.dot(n_h)) * 2.0).normalized()
	var h := away * WJ_SPEED * cos(WJ_ANGLE)
	var v := WJ_SPEED * sin(WJ_ANGLE) * pow(WJ_DECAY, _wj_chain)
	_move = h
	_takeoff = h
	_jumped = true
	_fall_speed = 0.0
	_fall_top = -INF
	_wj_chain += 1
	_wall_t = INF
	_kick_t = KICK_S
	wall_jumps += 1
	make_noise(0.55)
	NoiseEvents.emit(global_position, WJ_NOISE_M)
	footsteps.scuff(self)
	return h + up * v


## What's underfoot, as traction (movement table): slidier on sand, snow,
## ice, shallow water and rain-soaked ground.
func _traction_under() -> float:
	var t: Dictionary = Tuning.section("movement", "traction")
	var mat := Footsteps.material_under(self)
	var c: int = world.planet.cell_at(surface_dir)
	var b: int = world.planet.biome[c]
	if b == BiomeTemplates.ICE_SHEET or b == BiomeTemplates.GLACIER or b == BiomeTemplates.SEA_ICE:
		mat = "ice"
	var k := float(t.get(mat, t.get("default", 1.0)))
	if mat != "water" and mat != "ice":
		k = lerpf(k, minf(k, float(t.get("wet", 0.5))), ground_wet)
	return maxf(k, 0.05)


## The landing squat (the view dips, the body sinks a little) and the wall
## jump's kick (the body tips back), eased per frame.
func _update_squat(delta: float) -> void:
	var dip := 0.0
	if _squat_len > 0.0 and _squat_t > 0.0:
		dip = sin(PI * (1.0 - _squat_t / _squat_len)) * SQUAT_DIP_M * (_squat_len / maxf(SQUAT_S, 0.01)) * 0.5
		dip = minf(dip, SQUAT_DIP_M * 2.0)
	_squat_dip = move_toward(_squat_dip, dip, delta * 3.0)
	_kick_t = maxf(_kick_t - delta, 0.0)
	if _body != null and not dead:
		_body.position = Vector3(0, -_squat_dip, 0)
		var lean := minf(inventory.over() * Tuning.num("movement", "burden", "lean_per_item"), 0.3)
		_body.rotation.x = (-0.45 * sin(PI * _kick_t / KICK_S) if _kick_t > 0.0 else 0.0) + lean


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
		_pitch = clampf(_pitch, -PITCH_MAX, PITCH_MAX)
	else:
		_spring.spring_length = 4.5
		_spring.position = Vector3(0, CROUCH_CAMERA_Y if crouching else CAMERA_Y, 0)
		_camera.cull_mask |= BODY_LAYER
		_pitch = clampf(_pitch, -PITCH_MAX, PITCH_MAX)


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

## Overburdened (Inventory.over(): carried things past the free handful):
## your speed, climbing speed and loudness as shares of normal.
func burden_speed() -> float:
	var b := Tuning.section("movement", "burden")
	return maxf(1.0 - inventory.over() * float(b.get("slow_per_item", 0.08)), float(b.get("min_speed", 0.6)))


func burden_climb() -> float:
	return maxf(1.0 - inventory.over() * Tuning.num("movement", "burden", "climb_slow_per_item"), 0.3)


func burden_noise() -> float:
	return 1.0 + inventory.over() * Tuning.num("movement", "burden", "noise_per_item")


## Drawing the bow or raising the spear (slower on the ground, the camera
## comes over your shoulder; a sprint or a jump carries on).
func aiming() -> bool:
	return bow.drawing or spear.raising


## How far the aim wanders now, in degrees (combat table "aim"): a little
## standing, more at a run, least at the top of a jump, more the faster
## you're rising or falling.
func aim_sway_deg() -> float:
	var a := Tuning.section("combat", "aim")
	var vy := velocity.dot(up)
	var deg: float
	if is_on_floor() or climbing or swimming:
		var run := clampf(_move.length() / maxf(SPRINT_SPEED, 0.1), 0.0, 1.0)
		deg = lerpf(float(a.get("still_deg", 0.3)), float(a.get("moving_deg", 1.2)), run)
	else:
		deg = float(a.get("apex_deg", 0.0)) + absf(vy) * float(a.get("per_vertical_mps_deg", 0.45))
	return minf(deg, float(a.get("max_deg", 4.0)))


## `dir` turned by the aim's wander now: a slow, smooth drift, so the aim
## arc shows it and the shot follows the arc.
func sway(dir: Vector3) -> Vector3:
	var deg := aim_sway_deg()
	if deg <= 0.001:
		return dir
	var t := Time.get_ticks_msec() * 0.001 * Tuning.num("combat", "aim", "rate")
	var side := dir.cross(up)
	side = side.normalized() if side.length() > 0.01 else dir.cross(Vector3.RIGHT).normalized()
	var lift := side.cross(dir).normalized()
	var ax := sin(t * 1.7) * 0.6 + sin(t * 3.1 + 1.3) * 0.4
	var ay := sin(t * 2.3 + 0.7) * 0.6 + sin(t * 1.1 + 2.1) * 0.4
	return dir.rotated(lift, deg_to_rad(deg) * ax).rotated(side, deg_to_rad(deg) * ay).normalized()


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
	# Overburdened, everything you do is louder (the pack knocks and rattles).
	target = minf(target * burden_noise(), 1.0) if target > 0.0 else 0.0
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


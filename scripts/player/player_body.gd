class_name PlayerBody
extends Node3D
## The player's body: the wanderer. Short (about 1.57 m to the hood's
## crown), hooded and cloaked in the spirit of a Fire Emblem mage; the
## face is never seen.
##
## Look (spec R1a: blue plus one warm accent, nothing pure black): a deep
## ultramarine cloak to the shins, open down the front, with a darker
## lining and a rust band round the hem (the one warm accent). A short
## capelet over the shoulders, and a deep hood whose opening is a hollow
## in shadow: its inside is a dark indigo that no light reaches (drawn as
## a flat dark color, not lit), and there is no head or face in it. Wide
## sleeves in the cloak's blue, dark slate gloves; the hands rest in front
## at the belt. Under the cloak a slate-blue tunic with a belt, a cool
## grey satchel at the front right hip, dark trousers, dark boots.
##
## Built like the sculpted creatures (SculptedBodies' signed-distance
## shapes, surface nets, creases baked into the vertex colors): the
## tunic, legs, boots, sleeves, gloves and satchel. The hood and capelet
## are smooth surfaces of revolution (the hood needs its hollow). Colors
## are sRGB, taken linear; shaders/player.gdshader lights it like the
## creatures, with Look's weave texture on cloth and a coarse grain over
## everything.
##
## Rig (every part rides a pivot; PlanetPlayer poses `arms`):
##   Hips      at the hip joint; drops and moves back to crouch
##     LegL/R > KneeL/R > AnkleL/R: thigh, shin and boot, foot. A walk
##              cycle from the body's own velocity (strides lengthen with
##              speed), knees forward to crouch.
##     Torso   leans forward with speed and crouch
##       Head  the hood
##   ArmL/R    at the shoulders (children of the body, following the
##             torso): the upper sleeve. PlanetPlayer rotates them: both
##             forward to draw the bow, the right one for the spear, both
##             toward the handholds when climbing (it may stretch them).
##     ElbowL/R the forearm, bell sleeve and glove. At rest the elbows
##             bend so the hands rest in front; once PlanetPlayer poses an
##             arm, its elbow straightens, so the hand is ARM_M down the
##             arm's -Y, where the spear and the climbing expect it.
##   Cloak     the cloth (below).
##
## The cloak is cloth, simulated on the CPU (_simulate()): ROWS x COLS
## points, the top two rows pinned to the neck and shoulders, the rest
## moved by Verlet steps under gravity (the player's up, not world Y),
## the frame's own acceleration and turning (it swings as you start, stop
## and turn), air drag against the body's velocity and the wind (it trails
## behind at a sprint and lifts and flutters downwind), a soft pull toward
## its drape (it settles when still), distance constraints (stretch hard,
## compression soft, so it can bunch), and collisions with the torso,
## arms, legs, satchel and the ground plane under the feet (crouched, the
## hem drapes and spreads on the ground). The points go to the cloak's
## shader as an array; its vertex stage draws a smooth double-sided sheet
## through them (Catmull-Rom), with folds deepening toward the hem, the
## lining inside and a rust hem. The simulation skips while the body is
## far and off screen.
##
## Inputs, each frame (PlanetPlayer): set_motion() (0 still .. 1 sprint),
## set_velocity() (scene m/s), set_wind() (scene m/s, WeatherFX's
## `wind_vector`), set_crouch() (0 .. 1), set_tuck() (the one crouch pose,
## snapped: a landing squat, a wall-jump wind-up, a cling, a roll).
##
## The ninja run (movement table "run_pose"): the torso pitches forward
## with speed (lean_walk_deg at a walk to lean_sprint_deg at a sprint),
## more while speeding up, back a little while stopping; the hips lean
## into turns; the hood counter-rotates to stay level. (The trailing arms
## are PlanetPlayer's, which owns the arms.)
##
## First person: the hood, capelet, tunic, upper sleeves and the cloak
## above the chest stay on PlanetPlayer.BODY_LAYER (hidden from the
## eyes); the forearms and gloves, the cloak from the chest down, the
## satchel, legs and boots are on VIEW_LAYER, which the first-person
## camera sees: looking down you see your hands, the cloak's front edges
## and ring, and your boots. Nothing it sees comes within 0.3 m of the
## eyes (the camera's near plane is 0.1 m). By default the first-person
## camera hides VIEW_LAYER too (the designer found the cloak's edges got
## in the way): movement "camera" first_person_body brings it back.
##
## Faces -Z, +Y up, feet at y = 0.

# --- Proportions (m, standing) -------------------------------------------------

const HIP_Y := 0.76
const HIP_X := 0.085
const THIGH_M := 0.35
const SHIN_M := 0.34
## The shoulder joints (the arm pivots), over the feet and out from the
## middle (TreeClimb reaches for holds from here).
const SHOULDER_Y := 1.26
const SHOULDER_X := 0.175
const UPPER_ARM_M := 0.30
## How much longer the forearm's sleeve (and so the hand) sits than the
## first cut of the rig: arms that reach to mid-thigh, in proportion.
const FOREARM_EXTRA := 0.03
## Shoulder to the middle of the hand, arm straight (where a hand holds
## the spear or a handhold).
const ARM_M := 0.62
## The neck (the Head pivot) over the hips.
const NECK_UP := 0.54
## Arms' rest pose (the right arm; the left mirrors z), and the elbows'.
const ARM_REST := Vector3(0.06, 0.0, 0.13)
const ELBOW_REST := Vector3(1.1, 0.0, -0.35)

## Render layer of the parts the first-person camera sees (see the class
## notes).
const VIEW_LAYER := 1 << 11

# --- Colors (sRGB) --------------------------------------------------------------

const CLOAK := Color("222a6c") # deep ultramarine, toward indigo
const LINING := Color("161a4c")
const RUST := Color("a4492b") # the one warm accent: the hem band
const TUNIC := Color("4a5079")
const TROUSERS := Color("363a55")
const BOOT := Color("3e3643")
const GLOVE := Color("4c4764")
const SATCHEL := Color("5b5872")
const STRAP := Color("3b3850")
const CLASP := Color("6f7390")
## The hood's hollow: flat, unlit.
const HOLLOW := Color("0d0f2f")

## Materials (UV.x in the shader).
enum { LEATHER_K, CLOTH_K, TRIM_K, HOLLOW_K }

# --- The cloak ------------------------------------------------------------------

const COLS := 16
const ROWS := 8
## Rows pinned to the body (neck, shoulders).
const PINNED := 2
## Rows above this one are hidden in first person (BODY_LAYER).
const SPLIT_ROW := 2
## Rest rings, neck to hem: [y (standing), half-width, half-depth, back
## offset, half the front opening (rad)].
const CLOAK_RINGS := [
	[1.28, 0.105, 0.095, 0.0, 0.14],
	[1.235, 0.25, 0.155, 0.005, 0.2],
	[1.07, 0.285, 0.19, 0.012, 0.28],
	[0.895, 0.3, 0.21, 0.02, 0.32],
	[0.72, 0.31, 0.225, 0.026, 0.36],
	[0.545, 0.322, 0.24, 0.032, 0.39],
	[0.37, 0.335, 0.255, 0.038, 0.42],
	[0.2, 0.35, 0.27, 0.045, 0.45],
]
## Pull toward the drape per row (1/s^2): firm near the shoulders, loose
## at the hem.
const DRAPE_K := [0.0, 0.0, 14.0, 10.0, 7.5, 6.0, 5.0, 4.0]
const GRAVITY := 9.8
## Air drag (1/s): at a sprint (8.8 m/s) the hem trails well back.
const DRAG := 0.85
## Velocity kept per step (Verlet).
const DAMP := 0.985
## Flutter in moving air (m/s^2 per m/s of air).
const FLUTTER := 0.45
const CLOTH_R := 0.018 # how far the cloth keeps off what it lies on
const SIM_HZ := 60.0
## Render sub-steps per simulated cell (around, down).
const SUB_U := 3
const SUB_V := 3
## The cloth's folds: how many round the cloak.
const FOLDS := 9.0

var head: Node3D
var arms: Array[Node3D] = []
## Triangles in the whole body (for the budget).
var triangles := 0
## Cloth cost: the last step and a running average (microseconds).
var sim_usec := 0
var sim_usec_avg := 0.0
## Whether the cloth stepped this frame (it skips far off screen).
var simulating := false

var _mat: ShaderMaterial
var _cloth_mat: ShaderMaterial
var _hips: Node3D
var _torso: Node3D
var _legs: Array[Node3D] = []
## Climbing (PlanetPlayer sets it; from play: legs planted on the tree, not
## dangling): "" off; "trunk" hugging steep wood, knees up, the feet braced
## on the bark and stepping as you go; "straddle" astride a limb (sitting
## on it too); "cling" on a wall, a rock or a trunk (right click held):
## tucked, feet braced, hands up on the face, still (from play: only the
## cloak in the wind and the head as you look round move). `climb_travel`:
## how far the body has moved on the wood (m), which steps the feet.
var climb_pose := ""
var climb_travel := 0.0
var _knees: Array[Node3D] = []
var _ankles: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _view_parts: Array[GeometryInstance3D] = []
var _body_parts: Array[GeometryInstance3D] = []

var _motion := 0.0
var _vel := Vector3.ZERO
var _vel_prev := Vector3.ZERO
var _vel_fresh := false
var _wind := Vector3.ZERO
## A cloaked figure nobody hands a wind (set_wind) samples its own: the
## gust at it, sheltered by the crowns over it (design §DA, Wind.cloak_at).
var _own_wind := true
## False for a cloaked figure that isn't the player (CloakedFigure): its
## parts stay on the ordinary render layer (the first-person split is the
## player's own).
var is_player := true
## Sitting (camp folk): hips on a seat, thighs forward, shins down.
var seated := false
## A pose of its own (design 1 Oct §CL): "meditate", seated cross-legged
## on the ground, back straight, head a little bowed, hands toward the
## lap, still but for its breath. "" otherwise.
var pose := ""
## "ride" (§DQ): the beast's step, -1..1, rocking the rider's hips.
var ride_sway := 0.0
## Stride length as a share of the player's: bigger figures take longer,
## slower strides, smaller ones quicker, shorter ones (set to the scale).
var stride_scale := 1.0
## The trailing arms' elbow bend (radians), set by whoever trails them
## (PlanetPlayer's ninja run): added to the elbows over their rest pose.
var trail_elbow := 0.0

## Head-look (design reconciliation Session 2 section B; data/look.json
## "head_look"): small turns of the look turn the hood first, the
## shoulders shifting a little with it; past head_max_deg the torso
## follows; pitch tilts the hood alone within pitch_max_deg. So a figure
## pinned to a trunk still reads as looking around. The player sets its
## look (set_look(), from the third-person camera); other figures look at
## the player's head (watch_point) when it's within watch_m and in front
## of them, and otherwise glance about now and then.
static var HEAD_LOOK := Tuning.section("look", "head_look")
## The player's head (scene), each frame, for other figures to look at.
static var watch_point := Vector3(INF, INF, INF)
var _look_in := Vector2.ZERO # wanted (yaw, pitch), radians; yaw + = left
var _plant_lean := 0.0
var _plant_hem := 0.0
var _look_set := false
var _head_yaw := 0.0
var _head_pitch := 0.0
var _torso_yaw := 0.0
var _idle_seed := 0.0
var _crouch_target := 0.0
var _crouch := 0.0
var _tuck := 0.0
var _lean := 0.0
var _turn_lean := 0.0
var _fwd_speed_prev := 0.0
var _fwd_prev := Vector3.FORWARD
var _phase := 0.0
var _stride := 0.0
var _time := 0.0

# Cloth state, body space.
var _x := PackedVector3Array()
var _xp := PackedVector3Array()
var _rest := PackedVector3Array() # standing drape, body space
var _len_v := PackedFloat32Array() # to the point above
var _len_h := PackedFloat32Array() # to the next column
var _out := PackedVector3Array() # per column: outward (flutter)
var _basis_prev := Basis.IDENTITY
var _cloth_ready := false
var _skipped := true
# Colliders this step (body space).
var _cap_a := PackedVector3Array() # capsules: one end, the other minus it,
var _cap_ab := PackedVector3Array() # 1 / its length squared, radius and
var _cap_il2 := PackedFloat32Array() # bounds
var _cap_r := PackedFloat32Array()
var _cap_lo := PackedVector3Array()
var _cap_hi := PackedVector3Array()
var _torso_o := Vector3.ZERO
var _torso_x := Vector3.RIGHT
var _torso_y := Vector3.UP
var _torso_z := Vector3.BACK
var _satchel_c := Vector3.ZERO
var _ground_p := Vector3.ZERO
var _ground_n := Vector3.UP

static var _meshes := {}


func _init() -> void:
	name = "Body"
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/player.gdshader")
	Look.register(_mat)
	_mat.set_shader_parameter("look_tex_weave", Look.texture("weave"))
	_cloth_mat = ShaderMaterial.new()
	_cloth_mat.shader = _mat.shader
	Look.register(_cloth_mat)
	_cloth_mat.set_shader_parameter("look_tex_weave", Look.texture("weave"))
	_cloth_mat.set_shader_parameter("cloth", true)
	if _meshes.is_empty():
		_build_meshes()
	_build_rig()
	_init_cloth()


func _ready() -> void:
	# PlanetPlayer puts everything under the body on its BODY_LAYER once
	# it's added; sort the parts after that.
	_apply_layers.call_deferred()


## Per frame: how fast the player is going, 0 (still) to 1 (sprinting):
## how far the body leans into the run.
func set_motion(speed_frac: float, delta: float) -> void:
	_motion = lerpf(_motion, clampf(speed_frac, 0.0, 1.0), clampf(delta * 3.0, 0.0, 1.0))


## Per frame: the player's velocity (scene space, m/s). The cloak feels
## its changes (swinging as you start, stop and turn) and the air it
## moves through (trailing behind); the legs stride by it.
func set_velocity(v: Vector3) -> void:
	_vel = v
	_vel_fresh = true


## The wind at the player (scene space, m/s; WeatherFX's wind_vector):
## the cloak lifts and flutters downwind.
func set_wind(wind_vector: Vector3) -> void:
	_wind = wind_vector
	_own_wind = false


## A cloaked figure's own colors (not the player's): the cloth in `main`,
## the trim in `trim` (sRGB), each keeping its shading.
func set_palette(main: Color, trim: Color) -> void:
	for m in [_mat, _cloth_mat]:
		m.set_shader_parameter("recolor", true)
		m.set_shader_parameter("main_color", _rgb(_lin(main)))
		m.set_shader_parameter("trim_color", _rgb(_lin(trim)))
		m.set_shader_parameter("base_lum", _lin(CLOAK).get_luminance())
		m.set_shader_parameter("trim_lum", _lin(RUST).get_luminance())


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## The torso, hips and legs' pivots (hitboxes ride them).
func torso() -> Node3D:
	return _torso


func legs() -> Array[Node3D]:
	return _legs


## The planted foot (design §J bounds): every landing, bounce and kick
## plants the other one; the torso leans foot_lean_deg toward it (the
## cloak's hem swings with the torso) and eases back. The camera never
## follows it.
func plant(side: int) -> void:
	var deg := float(Tuning.num("movement", "bounds", "foot_lean_deg"))
	_plant_lean = deg_to_rad(deg) * (1.0 if side == 1 else -1.0)
	_plant_hem = deg_to_rad(float(Tuning.num("movement", "bounds", "hem_swing_deg"))) * (1.0 if side == 1 else -1.0)


## Where the player looks, relative to the body's facing (radians: yaw,
## + to the left; pitch, + up). Only the player calls this.
func set_look(yaw: float, pitch: float) -> void:
	_look_in = Vector2(yaw, pitch)
	_look_set = true


## The look this frame (radians, relative to facing): the player's as
## set; anyone else's toward the player's head when near and in front,
## else an idle glance.
func _wanted_look() -> Vector2:
	if is_player or _look_set:
		return _look_in
	var watch := float(HEAD_LOOK.get("watch_m", 12.0))
	if watch_point.x != INF and is_inside_tree():
		var eye := head.global_position
		var to := watch_point - eye
		if to.length() < watch * maxf(scale.x, 0.5) and to.length() > 0.3:
			var l := global_basis.orthonormalized().inverse() * to.normalized()
			var yaw := atan2(-l.x, -l.z)
			if absf(yaw) < deg_to_rad(120.0):
				return Vector2(yaw, asin(clampf(l.y, -1.0, 1.0)))
	# Idle: a slow glance one way or the other every few seconds.
	if _idle_seed == 0.0:
		_idle_seed = float(get_instance_id() % 997) + 1.0
	var t := _time * 0.35 + _idle_seed
	var glance := smoothstep(0.55, 0.9, sin(t * 0.7)) - smoothstep(0.55, 0.9, sin(t * 0.7 + 2.4))
	return Vector2(glance * deg_to_rad(float(HEAD_LOOK.get("idle_deg", 35.0))), 0.05 * sin(t * 1.3))


## Split the look between hood and torso, eased: the hood takes up to
## head_max_deg (the shoulders a share of it), the torso the rest up to
## torso_max_deg; pitch is the hood's alone.
func _update_look(delta: float) -> void:
	var want := _wanted_look() if _look_enabled() else Vector2.ZERO
	var head_max := deg_to_rad(float(HEAD_LOOK.get("head_max_deg", 45.0)))
	var torso_max := deg_to_rad(float(HEAD_LOOK.get("torso_max_deg", 50.0)))
	var share := float(HEAD_LOOK.get("shoulder_share", 0.2))
	var yaw := clampf(want.x, -head_max - torso_max, head_max + torso_max)
	var head_part := clampf(yaw, -head_max, head_max)
	var torso_want := (yaw - head_part) + head_part * share
	var pitch_max := deg_to_rad(float(HEAD_LOOK.get("pitch_max_deg", 30.0)))
	var hr := clampf(delta * float(HEAD_LOOK.get("head_rate", 9.0)), 0.0, 1.0)
	var tr := clampf(delta * float(HEAD_LOOK.get("torso_rate", 4.0)), 0.0, 1.0)
	_torso_yaw = lerpf(_torso_yaw, torso_want, tr)
	_head_yaw = lerpf(_head_yaw, yaw, hr)
	_head_pitch = lerpf(_head_pitch, clampf(want.y, -pitch_max, pitch_max), hr)
	if is_player and is_inside_tree():
		watch_point = head.global_position + global_basis.y * 0.1


func _look_enabled() -> bool:
	return bool(HEAD_LOOK.get("enabled", true))


## 0 standing .. 1 crouched: the knees bend, the body folds forward and
## the cloak's hem settles on the ground. Eased here.
func set_crouch(amount: float) -> void:
	_crouch_target = clampf(amount, 0.0, 1.0)


## The crouch pose right now, 0 .. 1, not eased in (a couple of frames of
## squat before a kick must show at once); it eases out by itself.
func set_tuck(amount: float) -> void:
	_tuck = maxf(_tuck, clampf(amount, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_time += delta
	if not _vel_fresh:
		# Nobody's feeding the velocity (dead, a test): let it die away.
		_vel = _vel.lerp(Vector3.ZERO, clampf(delta * 4.0, 0.0, 1.0))
	_vel_fresh = false
	_pose(delta)
	var t0 := Time.get_ticks_usec()
	simulating = _should_simulate()
	if simulating:
		if _skipped:
			_reset_cloth()
		_simulate(delta)
		_cloth_mat.set_shader_parameter("cloak_nodes", _x)
		sim_usec = Time.get_ticks_usec() - t0
		sim_usec_avg = lerpf(sim_usec_avg, float(sim_usec), 0.05) if sim_usec_avg > 0.0 else float(sim_usec)
	_skipped = not simulating
	_basis_prev = global_basis.orthonormalized()
	_vel_prev = _vel


func _should_simulate() -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var d := cam.global_position.distance_to(global_position)
	if d > 80.0:
		return false
	return d < 25.0 or cam.is_position_in_frustum(global_position + global_basis.y * 0.8)


# --- Pose ------------------------------------------------------------------------

## The legs' stride, the crouch, the lean, the elbows and where the arms
## hang from.
func _pose(delta: float) -> void:
	_crouch = move_toward(_crouch, _crouch_target, delta * 4.0)
	var c := maxf(smoothstep(0.0, 1.0, _crouch), _tuck)
	_tuck = move_toward(_tuck, 0.0, delta * 6.0)
	var local_v := global_basis.orthonormalized().inverse() * _vel
	var speed := Vector2(local_v.x, local_v.z).length()
	# The ninja run: lean with speed and acceleration, into turns.
	var rp := Tuning.section("movement", "run_pose")
	var walk: float = Tuning.num("movement", "speed", "walk_mps")
	var sprint: float = Tuning.num("movement", "speed", "sprint_mps")
	var lean_deg := float(rp.get("lean_walk_deg", 5.0)) * clampf(speed / maxf(walk, 0.1), 0.0, 1.0)
	if speed > walk:
		lean_deg = lerpf(float(rp.get("lean_walk_deg", 5.0)), float(rp.get("lean_sprint_deg", 20.0)), clampf((speed - walk) / maxf(sprint - walk, 0.1), 0.0, 1.0))
	var fwd_speed := -local_v.z
	var accel := (fwd_speed - _fwd_speed_prev) / maxf(delta, 1e-4)
	_fwd_speed_prev = fwd_speed
	if accel > 2.0:
		lean_deg += float(rp.get("lean_accel_deg", 8.0)) * clampf(accel / 20.0, 0.0, 1.0)
	elif accel < -2.0 and speed > 0.3:
		lean_deg -= float(rp.get("lean_stop_deg", 4.0)) * clampf(-accel / 20.0, 0.0, 1.0) + lean_deg * 0.5
	_lean = lerpf(_lean, deg_to_rad(lean_deg), clampf(delta * 8.0, 0.0, 1.0))
	var fwd := -global_basis.z.normalized()
	var turn := _fwd_prev.signed_angle_to(fwd, global_basis.y.normalized()) / maxf(delta, 1e-4)
	_fwd_prev = fwd
	var turn_to := clampf(-turn * speed / 12.0, -1.0, 1.0) * deg_to_rad(float(rp.get("turn_lean_deg", 10.0)))
	_turn_lean = lerpf(_turn_lean, turn_to, clampf(delta * 6.0, 0.0, 1.0))
	# Strides: one step per half cycle, longer the faster you go.
	var step_m := (0.55 + 0.12 * speed / maxf(stride_scale, 0.1)) * stride_scale
	_phase = wrapf(_phase + speed / step_m * PI * delta, 0.0, TAU)
	_stride = move_toward(_stride, clampf(speed * 0.1, 0.0, 0.55) * (1.0 - 0.5 * c), delta * 2.0)
	var a := _stride
	var bob := 0.018 * a * absf(sin(_phase * 2.0))
	_hips.position = Vector3(0.0, HIP_Y - 0.34 * c - bob, 0.1 * c)
	# The planted foot's lilt (plant()), easing out over a stride.
	_plant_lean = move_toward(_plant_lean, 0.0, delta * 0.35)
	_plant_hem = move_toward(_plant_hem, 0.0, delta * 0.7)
	_hips.rotation = Vector3(0.0, _plant_hem * 0.25, _turn_lean + _plant_lean)
	if pose == "meditate":
		# Cross-legged on the ground: thighs out to the sides, shins folded
		# under; the only movement is the breath, a slow rise of the chest.
		var breath := sin(_time * TAU / 5.5)
		_hips.position = Vector3(0.0, 0.14, 0.0)
		_torso.rotation = Vector3(0.02 + 0.015 * breath, 0.0, 0.0)
		_torso.scale = Vector3(1.0 + 0.008 * breath, 1.0 + 0.012 * breath, 1.0 + 0.01 * breath)
		head.rotation = Vector3(0.22, 0.0, 0.0)
		for s in 2:
			var sx := -1.0 if s == 0 else 1.0
			_legs[s].rotation = Vector3(1.45, 0.0, 1.05 * sx)
			_knees[s].rotation = Vector3(-2.7, 0.0, 0.0)
			_ankles[s].rotation = Vector3(0.0, 0.0, 0.0)
		_pose_arms_rest(0.0)
		for s in 2:
			_elbows[s].rotation = Vector3(-1.25, 0.0, 0.35 * (1.0 if s == 0 else -1.0))
		return
	if pose == "ride":
		# Astride a beast (design 3 Oct §DQ): hips where they stand, thighs
		# forward and out round its back, shins hanging; the back upright,
		# rocking a little with the beast's steps (`ride_sway`, set by
		# whoever leads it). The hood still turns by the look.
		_hips.position = Vector3(0.0, HIP_Y, 0.0)
		_hips.rotation = Vector3(0.0, 0.0, 0.03 * ride_sway)
		_update_look(delta)
		_torso.rotation = Vector3(-0.06 + 0.02 * absf(ride_sway), _torso_yaw * 0.5, 0.0)
		head.rotation = Vector3(0.08 + _head_pitch, _head_yaw - _torso_yaw * 0.5, 0.0)
		for s in 2:
			var sx := -1.0 if s == 0 else 1.0
			_legs[s].rotation = Vector3(0.75, 0.0, 0.55 * sx)
			_knees[s].rotation = Vector3(-1.05, 0.0, 0.0)
			_ankles[s].rotation = Vector3(0.25, 0.0, 0.0)
		_pose_arms_rest(0.0)
		for s in 2:
			_elbows[s].rotation = Vector3(-0.9, 0.0, 0.25 * (1.0 if s == 0 else -1.0))
		return
	if seated:
		# On a seat at knee height: thighs forward, shins down, a little
		# hunched toward the fire.
		_hips.position = Vector3(0.0, SHIN_M + 0.06, 0.05)
		_update_look(delta)
		_torso.rotation = Vector3(-0.18, _torso_yaw * 0.5, 0.0)
		head.rotation = Vector3(0.12 + _head_pitch, _head_yaw - _torso_yaw * 0.5, 0.0)
		for s in 2:
			_legs[s].rotation = Vector3(1.5, 0.0, 0.08 * (-1.0 if s == 0 else 1.0))
			_knees[s].rotation = Vector3(-1.45, 0.0, 0.0)
			_ankles[s].rotation = Vector3(0.0, 0.0, 0.0)
		_pose_arms_rest(0.0)
		return
	if climb_pose != "":
		_climb_legs(delta)
		return
	_update_look(delta)
	_torso.rotation = Vector3(-0.5 * c - _lean, _torso_yaw, 0.0)
	# The hood stays level: it turns back by the torso's lean; it turns by
	# the look (what the torso hasn't already taken) and tilts by its pitch.
	head.rotation = Vector3(0.5 * c * 0.5 + _lean + _head_pitch, _head_yaw - _torso_yaw, 0.0)
	for s in 2:
		var ph := _phase + PI * s
		var swing := a * sin(ph)
		var lift := a * 1.5 * maxf(cos(ph), 0.0) # the knee bends as the leg swings through
		_legs[s].rotation = Vector3(1.3 * c + swing, 0.0, 0.0)
		_knees[s].rotation = Vector3(-2.05 * c - lift - 0.05, 0.0, 0.0)
		_ankles[s].rotation = Vector3(0.75 * c + 0.5 * lift - 0.3 * swing, 0.0, 0.0)
	_pose_arms_rest(a)


## The legs on the tree (climb_pose): a foot steps up every STEP_M of
## travel, the other braced; the hips close in to the wood, the body leant
## into it. (The arms are the climb's: PlanetPlayer reaches them.)
const CLIMB_STEP_M := 0.35


func _climb_legs(delta: float) -> void:
	_update_look(delta)
	if climb_pose == "cling":
		# Still: the torso doesn't turn after the look, the feet don't step;
		# only the head turns (as far as head_max_deg).
		var head_max := deg_to_rad(float(HEAD_LOOK.get("head_max_deg", 45.0)))
		_hips.position = Vector3(0.0, HIP_Y - 0.3, 0.12)
		_hips.rotation = Vector3.ZERO
		_torso.rotation = Vector3(0.2, 0.0, 0.0)
		head.rotation = Vector3(_head_pitch - 0.1, clampf(_head_yaw, -head_max, head_max), 0.0)
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			_legs[s].rotation = Vector3(1.0 + 0.25 * s, 0.0, 0.25 * side)
			_knees[s].rotation = Vector3(-1.6 - 0.2 * s, 0.0, 0.0)
			_ankles[s].rotation = Vector3(0.6, 0.0, 0.0)
		return
	var ph := climb_travel / CLIMB_STEP_M * PI
	_hips.position = Vector3(0.0, HIP_Y - 0.12, 0.0)
	_hips.rotation = Vector3.ZERO
	match climb_pose:
		"trunk":
			_torso.rotation = Vector3(0.12, _torso_yaw * 0.5, 0.0)
		"straddle":
			_hips.position = Vector3(0.0, HIP_Y - 0.3, 0.05)
			_torso.rotation = Vector3(-0.1, _torso_yaw, 0.0)
		_:
			_torso.rotation = Vector3(0.05, _torso_yaw * 0.5, 0.0)
	head.rotation = Vector3(_head_pitch, _head_yaw - _torso_yaw * 0.5, 0.0)
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		# 0 .. 1: this foot high (just stepped up) .. low (pushing).
		var k := 0.5 + 0.5 * sin(ph + PI * s)
		match climb_pose:
			"trunk":
				_legs[s].rotation = Vector3(0.75 + 0.55 * k, 0.0, 0.2 * side)
				_knees[s].rotation = Vector3(-1.45 - 0.5 * k, 0.0, 0.0)
				_ankles[s].rotation = Vector3(0.55 + 0.2 * k, 0.0, 0.0)
			"straddle":
				_legs[s].rotation = Vector3(1.25, 0.0, 0.6 * side)
				_knees[s].rotation = Vector3(-1.35, 0.0, 0.0)
				_ankles[s].rotation = Vector3(0.35, 0.0, 0.0)
			_:
				_legs[s].rotation = Vector3(1.05 + 0.2 * k, 0.0, 0.12 * side)
				_knees[s].rotation = Vector3(-1.9, 0.0, 0.0)
				_ankles[s].rotation = Vector3(0.5, 0.0, 0.0)


## Where the legs are in their stride, 0 .. TAU (the left leg forward at
## PI/2): arms keep time with it.
func stride_phase() -> float:
	return _phase


## Shoulders ride the torso; an arm nobody has posed rests bent, hands in
## front, swaying a little with the stride `a`.
func _pose_arms_rest(a: float) -> void:
	var tt := _torso.transform
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		var arm := arms[s]
		arm.position = _hips.transform * (tt * Vector3(SHOULDER_X * sx, SHOULDER_Y - HIP_Y, 0.0))
		var rest_y := Basis.from_euler(Vector3(ARM_REST.x, 0.0, ARM_REST.z * sx)).y
		var off := arm.transform.basis.y.normalized().angle_to(rest_y)
		var w := 1.0 - smoothstep(0.08, 0.25, off)
		var sway := 0.12 * a * sin(_phase + PI * (1 - s)) + 0.03 * sin(_time * 1.3 + s)
		_elbows[s].rotation = Vector3((ELBOW_REST.x + sway) * w + trail_elbow, 0.0, ELBOW_REST.z * sx * w)


# --- The cloak ------------------------------------------------------------------

func _init_cloth() -> void:
	var n := ROWS * COLS
	_x.resize(n)
	_xp.resize(n)
	_rest.resize(n)
	_len_v.resize(n)
	_len_h.resize(n)
	_out.resize(COLS)
	for r in ROWS:
		for c in COLS:
			_rest[r * COLS + c] = _ring_point(r, c, 0.0)
	for c in COLS:
		var p := _rest[(ROWS - 1) * COLS + c]
		_out[c] = Vector3(p.x, 0.0, p.z).normalized()
	for r in ROWS:
		for c in COLS:
			var i := r * COLS + c
			_len_v[i] = _rest[i].distance_to(_rest[i - COLS]) if r > 0 else 0.0
			_len_h[i] = _rest[i].distance_to(_rest[i + 1]) if c < COLS - 1 else 0.0
	_reset_cloth()
	_cloth_mat.set_shader_parameter("cloak_nodes", _x)


## A point of the cloak's standing drape: row `r`, column `c` (0 the
## right front edge, round the back to COLS - 1 the left front edge),
## `off` out from the surface.
static func _ring_point(r: int, c: float, off: float) -> Vector3:
	var ring: Array = CLOAK_RINGS[r]
	var gap: float = ring[4]
	var phi := gap + (TAU - 2.0 * gap) * c / (COLS - 1)
	var rx: float = ring[1] + off
	var rz: float = ring[2] + off
	return Vector3(sin(phi) * rx, ring[0], -cos(phi) * rz + float(ring[3]))


func _reset_cloth() -> void:
	var hip_off := _hips.position - Vector3(0, HIP_Y, 0)
	var tt := _hips.transform * _torso.transform
	for r in ROWS:
		for c in COLS:
			var i := r * COLS + c
			var p := _rest[i]
			if r < PINNED:
				p = tt * (p - Vector3(0, HIP_Y, 0))
			else:
				p += hip_off
			_x[i] = p
			_xp[i] = p
	_basis_prev = global_basis.orthonormalized() if is_inside_tree() else Basis.IDENTITY


func _simulate(delta: float) -> void:
	var dt := 1.0 / SIM_HZ
	var dt2 := dt * dt
	var basis := global_basis.orthonormalized()
	var inv := basis.inverse()
	var parent := get_parent() as Node3D
	var up_w := parent.global_basis.y.normalized() if parent else Vector3.UP
	var grav := inv * (-up_w * GRAVITY)
	# The frame's own acceleration (felt as a push the other way) and the
	# air it moves through, in body space.
	var acc := (_vel - _vel_prev) / maxf(delta, 1e-4)
	acc = acc.limit_length(30.0)
	if _own_wind and is_inside_tree():
		_wind = Wind.cloak_at(global_position, up_w)
	var air := inv * (_wind - _vel)
	var steady := grav + inv * (-acc) + air * DRAG
	# The frame turned: free points keep their heading in the world.
	var turn := inv * _basis_prev
	var turned := not turn.is_equal_approx(Basis.IDENTITY)
	if turned and turn.get_euler().length() > 1.0:
		_reset_cloth()
		turned = false
	_colliders(parent)
	var hip_off := _hips.position - Vector3(0, HIP_Y, 0)
	var tt := _hips.transform * _torso.transform
	var air_speed := Vector2(air.x, air.z).length()
	var x := _x
	var xp := _xp
	var rest := _rest
	var outs := _out
	var len_v := _len_v
	var len_h := _len_h
	var keep := DAMP - DRAG * dt # drag against the cloth's own motion
	# Pinned rows follow the torso.
	for i in PINNED * COLS:
		var p := tt * (rest[i] - Vector3(0, HIP_Y, 0))
		x[i] = p
		xp[i] = p
	for r in range(PINNED, ROWS):
		var k: float = DRAPE_K[r]
		var fl := FLUTTER * air_speed * float(r - 1) / (ROWS - 2)
		var ph := _time * 7.3 + r * 0.9
		var ph2 := _time * 12.1
		for c in COLS:
			var i := r * COLS + c
			var p := x[i]
			var q := xp[i]
			if turned:
				p = turn * p
				q = turn * q
			var f := steady + (rest[i] + hip_off - p) * k
			f += outs[c] * (fl * (sin(ph + c * 1.7) + 0.35 * sin(ph2 + c * 2.9)))
			xp[i] = p
			x[i] = p + (p - q) * keep + f * dt2
	# Constraints: hold the cloth's lengths (stretch firmly, compress
	# softly so it can bunch), twice.
	for it in 2:
		for r in range(PINNED, ROWS):
			var pinned_above := r == PINNED
			for c in COLS:
				var i := r * COLS + c
				var d := x[i] - x[i - COLS]
				var l := d.length()
				if l > 1e-6:
					var e := (l - len_v[i]) / l
					if e < 0.0:
						e *= 0.25
					if pinned_above:
						x[i] -= d * e
					else:
						x[i] -= d * (e * 0.5)
						x[i - COLS] += d * (e * 0.5)
				if c < COLS - 1:
					var dh := x[i + 1] - x[i]
					var lh := dh.length()
					if lh > len_h[i]:
						var eh := (lh - len_h[i]) / lh * 0.5
						x[i] += dh * eh
						x[i + 1] -= dh * eh
	# Collisions: out of the torso (an elliptic column, hips to shoulders),
	# the satchel, the arms and legs (capsules), and up out of the ground,
	# where it also sticks a little (friction).
	var to := _torso_o
	var tx := _torso_x
	var ty := _torso_y
	var tz := _torso_z
	var sc := _satchel_c
	var sr := 0.095 + CLOTH_R
	var gp := _ground_p
	var gn := _ground_n
	var ca := _cap_a
	var cab := _cap_ab
	var cil := _cap_il2
	var cr := _cap_r
	var clo := _cap_lo
	var chi := _cap_hi
	var ncap := ca.size()
	var near := PackedInt32Array()
	for i in range(PINNED * COLS, ROWS * COLS):
		if i % COLS == 0:
			# The capsules this row can reach (by height).
			var ylo := INF
			var yhi := -INF
			for k in COLS:
				var y := x[i + k].y
				ylo = minf(ylo, y)
				yhi = maxf(yhi, y)
			near.clear()
			for j in ncap:
				if clo[j].y <= yhi and chi[j].y >= ylo:
					near.append(j)
		var p := x[i]
		var d := p - to
		var h := d.dot(ty)
		if h > -0.2 and h < 0.62:
			var rx := 0.2 + CLOTH_R + 0.05 * clampf((h - 0.35) * 5.0, 0.0, 1.0) - 0.03 * clampf(1.0 - absf(h - 0.1) * 6.667, 0.0, 1.0)
			var rz := 0.155 + CLOTH_R
			var dx := d.dot(tx)
			var dz := d.dot(tz)
			var e := (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz)
			if e < 1.0 and e > 1e-6:
				var kk := 1.0 / sqrt(e) - 1.0
				p += tx * (dx * kk) + tz * (dz * kk)
		var ds := p - sc
		if ds.length_squared() < sr * sr:
			p = sc + ds.normalized() * sr
		for j in near:
			var lo := clo[j]
			var hi := chi[j]
			if p.y < lo.y or p.y > hi.y or p.x < lo.x or p.x > hi.x or p.z < lo.z or p.z > hi.z:
				continue
			var a := ca[j]
			var ab := cab[j]
			var t := clampf((p - a).dot(ab) * cil[j], 0.0, 1.0)
			var cp := a + ab * t
			var dc := p - cp
			var rr := cr[j]
			var l2 := dc.length_squared()
			if l2 < rr * rr and l2 > 1e-10:
				p = cp + dc * (rr / sqrt(l2))
		var g := (p - gp).dot(gn) - CLOTH_R
		if g < 0.0:
			p -= gn * g
			var slide := p - xp[i]
			xp[i] += (slide - gn * slide.dot(gn)) * 0.6
		x[i] = p
	_x = x
	_xp = xp


## Where the colliders are this step (body space).
func _colliders(parent: Node3D) -> void:
	var ht := _hips.transform
	var tt := ht * _torso.transform
	_torso_o = tt.origin
	_torso_x = tt.basis.x.normalized()
	_torso_y = tt.basis.y.normalized()
	_torso_z = tt.basis.z.normalized()
	_satchel_c = ht * Vector3(0.1, -0.08, -0.175)
	_cap_a.clear()
	_cap_ab.clear()
	_cap_il2.clear()
	_cap_r.clear()
	_cap_lo.clear()
	_cap_hi.clear()
	for s in 2:
		var arm := arms[s]
		var at := arm.transform
		var et := at * _elbows[s].transform
		var sh := at.origin
		var el := et.origin
		var wr := et * Vector3(0, -0.24 - FOREARM_EXTRA, 0)
		_add_cap(sh, el, 0.075)
		_add_cap(el, wr, 0.08)
		var lt := ht * _legs[s].transform
		var kt := lt * _knees[s].transform
		_add_cap(lt.origin, kt.origin, 0.1)
		_add_cap(kt.origin, kt * Vector3(0, -SHIN_M, 0), 0.08)
	# The ground under the feet: the player's origin and up, in body space.
	var inv := transform.affine_inverse()
	_ground_p = inv * Vector3.ZERO
	_ground_n = (inv.basis * Vector3.UP).normalized()
	if parent == null:
		_ground_n = Vector3.UP


func _add_cap(a: Vector3, b: Vector3, r: float) -> void:
	var rr := r + CLOTH_R
	var m := Vector3.ONE * rr
	_cap_a.append(a)
	_cap_ab.append(b - a)
	_cap_il2.append(1.0 / maxf((b - a).length_squared(), 1e-8))
	_cap_r.append(rr)
	_cap_lo.append(a.min(b) - m)
	_cap_hi.append(a.max(b) + m)


## The hem's height over the ground plane (m): [lowest, mean].
func hem_ground_gap() -> Vector2:
	var lo := INF
	var sum := 0.0
	for c in COLS:
		var g := (_x[(ROWS - 1) * COLS + c] - _ground_p).dot(_ground_n)
		lo = minf(lo, g)
		sum += g
	return Vector2(lo, sum / COLS)


## The hem's mean offset from its standing drape (body space: +z behind,
## +y up), and the mean of its back half alone.
func hem_offset() -> Vector3:
	var hip_off := _hips.position - Vector3(0, HIP_Y, 0)
	var sum := Vector3.ZERO
	for c in COLS:
		var i := (ROWS - 1) * COLS + c
		sum += _x[i] - (_rest[i] + hip_off)
	return sum / COLS


## The cloth points (body space), for tests.
func cloak_points() -> PackedVector3Array:
	return _x


# --- Rig ----------------------------------------------------------------------

func _build_rig() -> void:
	_hips = _pivot(self, "Hips", Vector3(0, HIP_Y, 0))
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		var side := "L" if s == 0 else "R"
		var leg := _pivot(_hips, "Leg" + side, Vector3(HIP_X * sx, 0, 0))
		_part(leg, "thigh", "Thigh", true)
		var knee := _pivot(leg, "Knee" + side, Vector3(0, -THIGH_M, 0))
		_part(knee, "shin", "Shin", true)
		var ankle := _pivot(knee, "Ankle" + side, Vector3(0, -SHIN_M, 0))
		_part(ankle, "foot", "Foot", true)
		_legs.append(leg)
		_knees.append(knee)
		_ankles.append(ankle)
	_part(_hips, "satchel", "Satchel", true)
	_torso = _pivot(_hips, "Torso", Vector3.ZERO)
	_part(_torso, "chest", "Chest", false)
	_part(_torso, "waist", "Waist", false)
	_part(_torso, "capelet", "Capelet", false)
	head = _pivot(_torso, "Head", Vector3(0, NECK_UP, 0))
	_part(head, "hood", "Hood", false)
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		var side := "L" if s == 0 else "R"
		var arm := _pivot(self, "Arm" + side, Vector3(SHOULDER_X * sx, SHOULDER_Y, 0.0))
		arm.rotation = Vector3(ARM_REST.x, 0.0, ARM_REST.z * sx)
		_part(arm, "upper_arm", "Sleeve", false)
		var elbow := _pivot(arm, "Elbow" + side, Vector3(0, -UPPER_ARM_M, 0))
		elbow.rotation = Vector3(ELBOW_REST.x, 0.0, ELBOW_REST.z * sx)
		_part(elbow, "forearm", "Forearm", true)
		_part(elbow, "glove_" + side, "Glove", true)
		arms.append(arm)
		_elbows.append(elbow)
	for which in ["cloak_upper", "cloak_lower"]:
		var mi := MeshInstance3D.new()
		mi.name = "Cloak" if which == "cloak_lower" else "CloakTop"
		mi.mesh = _meshes[which]
		mi.material_override = _cloth_mat
		add_child(mi)
		(_view_parts if which == "cloak_lower" else _body_parts).append(mi)
		triangles += _meshes[which].get_meta("tris", 0)


func _pivot(parent: Node3D, pname: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = at
	parent.add_child(n)
	return n


func _part(parent: Node3D, key: String, pname: String, view: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.name = pname
	mi.mesh = _meshes[key]
	mi.material_override = _mat
	parent.add_child(mi)
	(_view_parts if view else _body_parts).append(mi)
	triangles += _meshes[key].get_meta("tris", 0)


func _apply_layers() -> void:
	if not is_player:
		return
	for p in _view_parts:
		p.layers = VIEW_LAYER
	for p in _body_parts:
		p.layers = PlanetPlayer.BODY_LAYER


# --- Meshes -------------------------------------------------------------------

## Every part's mesh, built once and shared (a few hundred ms).
static func _build_meshes() -> void:
	var t0 := Time.get_ticks_msec()
	_meshes["chest"] = _sculpt(_chest_spec())
	_meshes["waist"] = _sculpt(_waist_spec())
	_meshes["thigh"] = _sculpt(_thigh_spec())
	_meshes["shin"] = _sculpt(_shin_spec())
	_meshes["foot"] = _sculpt(_foot_spec())
	_meshes["satchel"] = _sculpt(_satchel_spec())
	_meshes["upper_arm"] = _sculpt(_upper_arm_spec())
	_meshes["forearm"] = _sculpt(_forearm_spec())
	_meshes["glove_L"] = _sculpt(_glove_spec(-1.0))
	_meshes["glove_R"] = _sculpt(_glove_spec(1.0))
	_meshes["hood"] = _hood_mesh()
	_meshes["capelet"] = _capelet_mesh()
	_meshes["cloak_upper"] = _cloak_mesh(0, SPLIT_ROW)
	_meshes["cloak_lower"] = _cloak_mesh(SPLIT_ROW, ROWS - 1)
	_meshes["ms"] = Time.get_ticks_msec() - t0


## How long the meshes took to build (ms).
static func build_ms() -> int:
	return _meshes.get("ms", 0)


static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


## A signed-distance part meshed by SculptedBodies (smooth unions,
## creases darkened), as a plain mesh on its pivot.
static func _sculpt(s: SculptedBodies.Spec) -> ArrayMesh:
	for pr in s.prims + s.paints:
		pr.color = _lin(pr.color)
	var d: Dictionary = SculptedBodies._mesh_arrays(s, s.cell)
	var arrays: Array = d.arrays
	arrays[Mesh.ARRAY_TEX_UV2] = null
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("tris", d.tris)
	return mesh


## Tunic chest, shoulders and neck (torso space: the hip joint at 0).
static func _chest_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.036
	s.cap(Vector3(0, 0.18, 0.005), Vector3(0, 0.4, 0.0), 0.125, 0.135, 0, TUNIC, 0.06, CLOTH_K)
	s.ell(Vector3(0, 0.33, -0.01), Vector3(0.15, 0.12, 0.1), 0, TUNIC, 0.05, Basis.IDENTITY, CLOTH_K)
	s.ell(Vector3(0, 0.46, 0.0), Vector3(0.19, 0.055, 0.095), 0, TUNIC, 0.05, Basis.IDENTITY, CLOTH_K)
	s.cap(Vector3(0, 0.47, 0.0), Vector3(0, 0.6, -0.005), 0.05, 0.045, 0, HOLLOW, 0.03, HOLLOW_K) # in the hood's shadow
	s.paint(Vector3(0, 0.47, -0.09), Vector3(0.07, 0.05, 0.05), TUNIC.darkened(0.3), 0.02)
	return s


## Belly, belt and the tunic's short skirt over the hips.
static func _waist_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.03
	s.cap(Vector3(0, 0.0, 0.0), Vector3(0, 0.2, -0.005), 0.14, 0.125, 0, TUNIC, 0.05, CLOTH_K)
	s.ell(Vector3(0, -0.03, 0.005), Vector3(0.165, 0.075, 0.13), 0, TUNIC.darkened(0.08), 0.04, Basis.IDENTITY, CLOTH_K)
	s.cap(Vector3(0, -0.02, 0.005), Vector3(0, -0.24, 0.01), 0.15, 0.165, 0, TUNIC.darkened(0.08), 0.03, CLOTH_K) # skirt
	s.paint(Vector3(0, -0.27, 0.01), Vector3(0.25, 0.035, 0.25), TUNIC.darkened(0.35), 0.01) # its hem
	s.paint(Vector3(0, 0.07, 0.0), Vector3(0.2, 0.02, 0.2), STRAP, 0.006, Basis.IDENTITY, LEATHER_K)
	s.ell(Vector3(0, 0.07, -0.135), Vector3(0.024, 0.02, 0.012), 0, CLASP, 0.006, Basis.IDENTITY, LEATHER_K)
	return s


## Leg pivot space: the hip joint at 0, the leg down -Y.
static func _thigh_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.03
	s.cap(Vector3(0, 0.02, 0.0), Vector3(0, -THIGH_M, 0.0), 0.078, 0.058, 0, TROUSERS, 0.04, CLOTH_K)
	s.ell(Vector3(0, -THIGH_M, -0.008), Vector3(0.056, 0.05, 0.055), 0, TROUSERS, 0.03, Basis.IDENTITY, CLOTH_K)
	return s


static func _shin_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.024
	s.cap(Vector3(0, 0.0, 0.0), Vector3(0, -0.17, 0.004), 0.056, 0.05, 0, TROUSERS, 0.03, CLOTH_K)
	s.cap(Vector3(0, -0.13, 0.004), Vector3(0, -SHIN_M + 0.01, 0.0), 0.056, 0.048, 0, BOOT, 0.02, LEATHER_K)
	s.ell(Vector3(0, -0.13, 0.004), Vector3(0.062, 0.022, 0.062), 0, BOOT.darkened(0.15), 0.012, Basis.IDENTITY, LEATHER_K)
	return s


## Ankle pivot space: the ankle at 0, the sole at -0.07.
static func _foot_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.018
	s.ell(Vector3(0, -0.028, -0.05), Vector3(0.048, 0.04, 0.1), 0, BOOT, 0.03, Basis.IDENTITY, LEATHER_K)
	s.ell(Vector3(0, -0.025, 0.018), Vector3(0.045, 0.043, 0.045), 0, BOOT, 0.03, Basis.IDENTITY, LEATHER_K)
	s.cap(Vector3(0, 0.03, 0.0), Vector3(0, -0.02, -0.01), 0.048, 0.046, 0, BOOT, 0.03, LEATHER_K)
	s.paint(Vector3(0, -0.075, -0.03), Vector3(0.07, 0.014, 0.16), BOOT.darkened(0.35), 0.006)
	return s


## Hips space: at the front right hip, hung from the belt.
static func _satchel_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.016
	var b := Basis(Vector3.UP, -0.45)
	var c := Vector3(0.1, -0.08, -0.175)
	s.ell(c, Vector3(0.085, 0.07, 0.038), 0, SATCHEL, 0.03, b, LEATHER_K)
	s.ell(c + b * Vector3(0, 0.03, -0.022), Vector3(0.082, 0.045, 0.014), 0, SATCHEL.darkened(0.18), 0.01, b, LEATHER_K) # flap
	s.ell(c + b * Vector3(0, 0.0, -0.038), Vector3(0.013, 0.016, 0.006), 0, CLASP, 0.004, b, LEATHER_K) # toggle
	for sd: float in [-1.0, 1.0]:
		s.cap(c + b * Vector3(0.05 * sd, 0.05, -0.005), c + b * Vector3(0.05 * sd, 0.15, 0.02), 0.011, 0.011, 0, STRAP, 0.008, LEATHER_K)
	return s


## Arm pivot space: the shoulder at 0, the arm down -Y. A wide sleeve.
static func _upper_arm_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.024
	s.ell(Vector3(0, -0.035, 0.0), Vector3(0.064, 0.06, 0.066), 0, CLOAK, 0.04, Basis.IDENTITY, CLOTH_K)
	s.cap(Vector3(0, -0.02, 0.0), Vector3(0, -UPPER_ARM_M - 0.01, 0.0), 0.068, 0.062, 0, CLOAK, 0.04, CLOTH_K)
	s.paint(Vector3(0.0, -0.16, 0.07), Vector3(0.03, 0.12, 0.03), CLOAK.darkened(0.2), 0.03) # a crease behind
	return s


## Elbow pivot space: a bell sleeve open at the wrist, its dark lining
## showing.
static func _forearm_spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.022
	s.ell(Vector3(0, 0.0, 0.0), Vector3(0.064, 0.06, 0.064), 0, CLOAK, 0.03, Basis.IDENTITY, CLOTH_K)
	var e := FOREARM_EXTRA
	s.cap(Vector3(0, 0.0, 0.0), Vector3(0, -0.2 - e, 0.0), 0.062, 0.084, 0, CLOAK, 0.03, CLOTH_K)
	s.ell(Vector3(0, -0.205 - e, 0.0), Vector3(0.078, 0.014, 0.078), 0, LINING, 0.008, Basis.IDENTITY, CLOTH_K)
	s.paint(Vector3(0, -0.21 - e, 0.0), Vector3(0.1, 0.012, 0.1), LINING.darkened(0.3), 0.006)
	s.paint(Vector3(0.0, -0.1 - e * 0.5, 0.07), Vector3(0.035, 0.1, 0.03), CLOAK.darkened(0.2), 0.03)
	return s


## Elbow pivot space: a gloved hand out of the sleeve, the palm flat and
## facing in, fingers loosely curled, the thumb forward (`sx` the side).
static func _glove_spec(sx: float) -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = 0.012
	var d := Vector3(0, -FOREARM_EXTRA, 0)
	s.cap(Vector3(0, -0.19, 0.0) + d, Vector3(0, -0.25, -0.004) + d, 0.029, 0.027, 0, GLOVE, 0.012, LEATHER_K)
	s.ell(Vector3(0.0, -0.285, -0.006) + d, Vector3(0.022, 0.047, 0.036), 0, GLOVE, 0.016, Basis.IDENTITY, LEATHER_K)
	s.cap(Vector3(0.0, -0.315, -0.012) + d, Vector3(-0.012 * sx, -0.345, 0.0) + d, 0.02, 0.016, 0, GLOVE, 0.012, LEATHER_K)
	s.cap(Vector3(-0.012 * sx, -0.268, -0.03) + d, Vector3(-0.018 * sx, -0.3, -0.05) + d, 0.012, 0.01, 0, GLOVE, 0.008, LEATHER_K)
	s.paint(Vector3(0, -0.245, 0.0) + d, Vector3(0.035, 0.01, 0.035), GLOVE.darkened(0.3), 0.005) # cuff seam
	return s


# --- Surfaces of revolution (hood, capelet) --------------------------------

## Vertices of a part (one mesh).
class Geo:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()


## The hood (Head space: the neck at 0), round the forward axis, back to
## front then back inside: [z (+ behind), half-width, half-height, height
## of the middle, part (0 outside, 1 the lip, 2 the hollow)].
const HOOD_RINGS := [
	[0.15, 0.045, 0.06, 0.15, 0],
	[0.115, 0.095, 0.12, 0.135, 0],
	[0.05, 0.126, 0.15, 0.13, 0],
	[-0.02, 0.133, 0.156, 0.127, 0],
	[-0.085, 0.128, 0.151, 0.124, 0],
	[-0.125, 0.118, 0.141, 0.122, 1],
	[-0.13, 0.104, 0.127, 0.121, 1],
	[-0.105, 0.096, 0.119, 0.119, 2],
	[-0.035, 0.09, 0.11, 0.117, 2],
	[0.03, 0.064, 0.085, 0.117, 2],
]


static func _hood_mesh() -> ArrayMesh:
	var g := Geo.new()
	var n := HOOD_RINGS.size()
	_lathe(g, n, 28, func(i: int, a: float) -> Array:
		var h: Array = HOOD_RINGS[i]
		var part: int = h[4]
		var up := sin(a)
		var ry: float = h[2]
		if part == 0:
			# A soft peak over the crown and a fold down each side.
			ry *= 1.0 + 0.1 * pow(maxf(up, 0.0), 3.0)
		var rx: float = h[1] * (1.0 + (0.03 * sin(3.0 * a + 0.5) if part == 0 else 0.0))
		var z: float = h[0]
		if i >= 4 and i <= 7:
			z -= 0.03 * up # the brim overhangs at the top
		var p := Vector3(cos(a) * rx, float(h[3]) + up * ry, z)
		var col: Color
		var kind := CLOTH_K
		match part:
			0:
				var crease := 0.5 - 0.5 * sin(3.0 * a + 0.5)
				col = CLOAK * (1.1 - 0.25 * crease) * (0.85 + 0.15 * clampf(up + 0.6, 0.0, 1.0))
			1:
				# The brim's edge catches the light; inside it, the lining.
				col = CLOAK * 1.25 if i == 5 else LINING * 0.8
			_:
				col = HOLLOW
				kind = HOLLOW_K
		return [p, _lin(col), kind],
		Vector3(0, 0.17, 0.19), Vector3(0, 0.117, 0.065))
	return _geo_mesh(g)


## The capelet over the shoulders (torso space), a ragged hem hanging a
## little lower front and back, lined.
const CAPELET_RINGS := [
	[0.52, 0.115, 0.1, 0.0],
	[0.5, 0.2, 0.14, 0.0],
	[0.465, 0.265, 0.17, 0.005],
	[0.41, 0.3, 0.195, 0.01],
	[0.34, 0.312, 0.205, 0.012],
	[0.345, 0.294, 0.187, 0.012],
]


static func _capelet_mesh() -> ArrayMesh:
	var g := Geo.new()
	var n := CAPELET_RINGS.size()
	_lathe(g, n, 36, func(i: int, a: float) -> Array:
		var r: Array = CAPELET_RINGS[i]
		var y: float = r[0]
		var k := 1.0
		if i >= n - 2:
			y += -0.03 * absf(sin(a)) + 0.012 * sin(7.0 * a + 1.0)
			k = 1.0 + 0.035 * sin(7.0 * a + 1.0)
		var p := Vector3(cos(a) * r[1] * k, y, sin(a) * r[2] * k + float(r[3]))
		var crease := 0.5 - 0.5 * sin(7.0 * a + 1.0)
		var col := CLOAK * (1.0 - 0.2 * crease * float(i) / (n - 1)) * (0.75 if i == n - 2 else 1.0)
		if i == n - 1:
			col = LINING
		return [p, _lin(col), CLOTH_K],
		Vector3(0, 0.54, 0), Vector3(0, 0.44, 0))
	# Clasp at the throat.
	_lathe(g, 4, 10, func(i: int, a: float) -> Array:
		var phi := PI * (i + 1) / 5.0
		var s := sin(phi)
		return [Vector3(0, 0.5, -0.1) + Vector3(cos(a) * s * 0.022, cos(phi) * 0.022, sin(a) * s * 0.01), _lin(CLASP), LEATHER_K],
		Vector3(0, 0.522, -0.1), Vector3(0, 0.478, -0.1))
	return _geo_mesh(g)


## A closed, smooth-shaded surface round a (possibly bent) axis: `rings`
## rings of `radial` points, closed by poles at `top` and `bottom`.
## f.call(ring, angle) -> [position, color (linear), material].
static func _lathe(g: Geo, rings: int, radial: int, f: Callable, top: Vector3, bottom: Vector3) -> void:
	var start := g.verts.size()
	var first := g.idx.size()
	var p0: Array = f.call(0, 0.0)
	_vert(g, top, p0[1], p0[2])
	for i in rings:
		for k in radial:
			var p: Array = f.call(i, TAU * k / radial)
			_vert(g, p[0], p[1], p[2])
	var pl: Array = f.call(rings - 1, 0.0)
	_vert(g, bottom, pl[1], pl[2])
	var last := g.verts.size() - 1
	for k in radial:
		var k1 := (k + 1) % radial
		g.idx.append_array([start, start + 1 + k, start + 1 + k1])
		for r in rings - 1:
			var a0 := start + 1 + r * radial
			var a1 := a0 + radial
			g.idx.append_array([a0 + k, a1 + k1, a0 + k1, a0 + k, a1 + k, a1 + k1])
		var lb := start + 1 + (rings - 1) * radial
		g.idx.append_array([lb + k, last, lb + k1])
	# Face the part outward. Godot draws a triangle whose (v1 - v0) x
	# (v2 - v0) points away from the camera, so that cross product must
	# point in.
	var mid := Vector3.ZERO
	for v in range(start, g.verts.size()):
		mid += g.verts[v]
	mid /= g.verts.size() - start
	var out_sum := 0.0
	for t in range(first, g.idx.size(), 3):
		var a := g.verts[g.idx[t]]
		var fn := (g.verts[g.idx[t + 1]] - a).cross(g.verts[g.idx[t + 2]] - a)
		out_sum += fn.dot((a + g.verts[g.idx[t + 1]] + g.verts[g.idx[t + 2]]) / 3.0 - mid)
	if out_sum > 0.0:
		for t in range(first, g.idx.size(), 3):
			var tmp := g.idx[t + 1]
			g.idx[t + 1] = g.idx[t + 2]
			g.idx[t + 2] = tmp


static func _vert(g: Geo, p: Vector3, c: Color, kind: int) -> void:
	g.verts.append(p)
	g.colors.append(c)
	g.uv.append(Vector2(kind, 0.0))


## Smooth normals, then the mesh.
static func _geo_mesh(g: Geo) -> ArrayMesh:
	var normals := PackedVector3Array()
	normals.resize(g.verts.size())
	for t in range(0, g.idx.size(), 3):
		var a := g.verts[g.idx[t]]
		var fn := (g.verts[g.idx[t + 1]] - a).cross(g.verts[g.idx[t + 2]] - a)
		for q in 3:
			normals[g.idx[t + q]] -= fn # faces are wound inward (see _lathe)
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g.verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = g.colors
	arrays[Mesh.ARRAY_TEX_UV] = g.uv
	arrays[Mesh.ARRAY_INDEX] = g.idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("tris", g.idx.size() / 3)
	return mesh


# --- The cloak's sheet ----------------------------------------------------------

## The cloak between rows `r0` and `r1` as a sheet the cloth shader lays
## through the simulated points: an outer face and the lining (CUSTOM0.y
## +1, -1), the hem's edge (2) and the two front edges (3 right, 4 left).
## UV2 is the point on the grid (column, row); CUSTOM0.x how far off the
## middle of the cloth (half its thickness plus the fold), CUSTOM0.z the
## fold's slope along the columns (to tilt the normal). VERTEX is only the
## standing drape (the shader moves it).
static func _cloak_mesh(r0: int, r1: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var idx := PackedInt32Array()
	var nu := (COLS - 1) * SUB_U + 1
	var nv := (r1 - r0) * SUB_V + 1
	var half := 0.006
	var hem := r1 == ROWS - 1
	var add := func(gu: float, gv: float, off: float, mode: float, slope: float, col: Color, kind: int) -> int:
		var p := _grid_point(gu, gv, off)
		verts.append(p)
		normals.append(Vector3(p.x, 0.0, p.z).normalized() * signf(mode if absf(mode) < 1.5 else 1.0))
		colors.append(_lin(col))
		uv.append(Vector2(kind, 0.0))
		uv2.append(Vector2(gu, gv))
		custom.append_array([off, mode, slope, 0.0])
		return verts.size() - 1
	# Faces.
	for side: float in [1.0, -1.0]:
		var grid := PackedInt32Array()
		for j in nv:
			var gv := r0 + float(j) / SUB_V
			for i in nu:
				var gu := float(i) / SUB_U
				var fold := _fold(gu, gv)
				var col: Color
				var kind := CLOTH_K
				var band := gv > ROWS - 1 - 0.3
				if band:
					col = RUST * (1.0 - 0.18 * _crease(gu))
					kind = TRIM_K
				elif side > 0.0:
					col = CLOAK * (1.0 - 0.45 * _crease(gu) * _fold_amp(gv) / _fold_amp(ROWS - 1))
					if gv < 1.6:
						col *= 0.85 # in the capelet's shade
				else:
					col = LINING * (1.0 - 0.2 * _crease(gu))
				grid.append(add.call(gu, gv, side * half + fold.x, side, fold.y, col, kind))
		for j in nv - 1:
			for i in nu - 1:
				var a := grid[j * nu + i]
				var b := grid[j * nu + i + 1]
				var c := grid[(j + 1) * nu + i]
				var d := grid[(j + 1) * nu + i + 1]
				var o := normals[a]
				_tri(idx, verts, a, b, d, o)
				_tri(idx, verts, a, d, c, o)
	# Edges: the hem (on the lower part), and both front edges.
	if hem:
		var gv := float(r1)
		var e_out := PackedInt32Array()
		var e_in := PackedInt32Array()
		for i in nu:
			var gu := float(i) / SUB_U
			var fold := _fold(gu, gv)
			var col := RUST * 0.8
			e_out.append(add.call(gu, gv, half + fold.x, 2.0, 0.0, col, TRIM_K))
			e_in.append(add.call(gu, gv, -half + fold.x, 2.0, 0.0, col, TRIM_K))
		for i in nu - 1:
			_tri(idx, verts, e_out[i], e_out[i + 1], e_in[i + 1], Vector3.DOWN)
			_tri(idx, verts, e_out[i], e_in[i + 1], e_in[i], Vector3.DOWN)
	for edge in 2:
		var i := 0 if edge == 0 else nu - 1
		var gu := float(i) / SUB_U
		var e_out := PackedInt32Array()
		var e_in := PackedInt32Array()
		for j in nv:
			var gv := r0 + float(j) / SUB_V
			var fold := _fold(gu, gv)
			var band := gv > ROWS - 1 - 0.3
			var col := RUST * 0.85 if band else LINING * 1.2
			e_out.append(add.call(gu, gv, half + fold.x, 3.0 + edge, 0.0, col, TRIM_K if band else CLOTH_K))
			e_in.append(add.call(gu, gv, -half + fold.x, 3.0 + edge, 0.0, col, TRIM_K if band else CLOTH_K))
		# Outward at the right front edge (column 0) is toward -u.
		var p0 := _grid_point(gu, r0 + 0.5, 0.0)
		var p1 := _grid_point(gu + (0.1 if edge == 0 else -0.1), r0 + 0.5, 0.0)
		var o := (p0 - p1).normalized()
		for j in nv - 1:
			_tri(idx, verts, e_out[j], e_out[j + 1], e_in[j + 1], o)
			_tri(idx, verts, e_out[j], e_in[j + 1], e_in[j], o)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	# The shader moves every vertex anywhere within reach of the body.
	mesh.custom_aabb = AABB(Vector3(-1.6, -1.2, -1.6), Vector3(3.2, 3.2, 3.2))
	mesh.set_meta("tris", idx.size() / 3)
	return mesh


## Append triangle a, b, c wound to face `out` (see _lathe).
static func _tri(idx: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, out: Vector3) -> void:
	var fn := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if fn.dot(out) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


## The standing drape at a point of the grid (bilinear between rings).
static func _grid_point(gu: float, gv: float, off: float) -> Vector3:
	var r := clampi(int(floor(gv)), 0, ROWS - 2)
	var t := gv - r
	var a := _ring_point(r, gu, off)
	var b := _ring_point(r + 1, gu, off)
	return a.lerp(b, t)


static func _fold_amp(gv: float) -> float:
	return 0.003 + 0.022 * pow(clampf(gv / (ROWS - 1), 0.0, 1.0), 1.3)


static func _crease(gu: float) -> float:
	return 0.5 - 0.5 * sin(FOLDS * TAU * gu / (COLS - 1) + 0.6)


## The fold's offset from the cloth's middle and its slope along the
## columns: [offset, d offset / d column].
static func _fold(gu: float, gv: float) -> Vector2:
	var w := FOLDS * TAU / (COLS - 1)
	var amp := _fold_amp(gv)
	var ph := w * gu + 0.6
	# Folds fade out at the front edges so the edges hang clean.
	var edge := clampf(minf(gu, COLS - 1 - gu) / 0.6, 0.0, 1.0)
	return Vector2(amp * sin(ph) * edge, amp * w * cos(ph) * edge)

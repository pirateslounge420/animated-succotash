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
## (PlayerBody, the short hooded wanderer in a cloak) has its own simple
## rig (hips, knees, torso, shoulder pivots) and a cloth cloak. Drop a
## rigged model in as assets/models/player.glb (ModelLibrary) and it
## replaces the wanderer, its
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
## Gravity rising and falling (design §J, retuned from play 2026-09-29):
## nearly the same pull both ways, a little heavier falling, so a jump is
## short and snappy and nothing floats.
static var GRAVITY_UP := Tuning.num("movement", "air", "gravity_up_mps2")
static var GRAVITY_DOWN := Tuning.num("movement", "air", "gravity_down_mps2")
## Letting go of jump while still rising cuts the rise to this share (a
## tap is a hop, a hold the full bound).
static var JUMP_CUT := Tuning.num("movement", "air", "jump_release_cut")
## In flight the body turns with the look (design §R): no air steering,
## the facing never touches the velocity.
static var BODY_TURNS_FREE := bool(Tuning.num("movement", "air", "body_turns_free"))
## Every contact re-aims momentum to the look (design §R): the kept share
## by turn angle, the tech's factor, the physics limit.
static var REDIRECT := Tuning.section("movement", "redirect")
static var SANITY_MPS := Tuning.num("movement", "redirect", "sanity_mps")
## The branch bounce (design §J).
static var BOUNCE := Tuning.section("movement", "bounce")
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
## Right click, the tech button (_tech()): on a steep face, a wall jump
## (tap) or a cling (hold); near a branch or vine, catch and swing. Timed
## in physics frames (the game runs locked at 60), so a hitch can't widen
## the window.
static var WJ_WINDOW_F := int(Tuning.num("movement", "wall_jump", "window_frames"))
static var WJ_TAP_F := int(Tuning.num("movement", "wall_jump", "tap_frames"))
static var WJ_SPEED := Tuning.num("movement", "wall_jump", "speed_mps")
static var WJ_ANGLE := deg_to_rad(Tuning.num("movement", "wall_jump", "angle_deg"))
static var WJ_GAIN := Tuning.num("movement", "wall_jump", "chain_gain")
static var WJ_CAP := int(Tuning.num("movement", "wall_jump", "chain_cap"))
static var WJ_MAX := Tuning.num("movement", "wall_jump", "max_mps")
static var WJ_STEEP := Tuning.num("movement", "wall_jump", "min_wall_steepness")
static var WJ_NOISE_M := Tuning.num("movement", "wall_jump", "noise_m")
static var CLING_S := Tuning.num("movement", "wall_jump", "cling_hold_s")
static var CLING_JUMP := Tuning.num("movement", "wall_jump", "cling_jump_scale")
static var CLING_SLIDE := Tuning.num("movement", "wall_jump", "cling_slide_mps")
## Crawling over the face you cling to (WASD), and the leap off it: up as
## steep as you look, between these (radians).
static var CLING_CRAWL := float(Tuning.section("movement", "wall_jump").get("cling_crawl_mps", 1.6))
static var CLING_AIM_MIN := deg_to_rad(float(Tuning.section("movement", "wall_jump").get("cling_aim_min_deg", 12.0)))
static var CLING_AIM_MAX := deg_to_rad(float(Tuning.section("movement", "wall_jump").get("cling_aim_max_deg", 80.0)))
## Landing roll (crouch at touchdown after a big fall; _start_roll()).
static var ROLL_WINDOW_F := int(Tuning.num("movement", "roll", "window_frames"))
static var ROLL_SAFE_M := Tuning.num("movement", "roll", "safe_m")
static var ROLL_DAMAGE := Tuning.num("movement", "roll", "damage_scale")
static var ROLL_CARRY := Tuning.num("movement", "roll", "carry")
static var ROLL_MAX_MPS := Tuning.num("movement", "roll", "max_mps")
static var ROLL_LEN_PER_M := Tuning.num("movement", "roll", "len_per_m")
static var ROLL_LEN_CAP := Tuning.num("movement", "roll", "len_cap_m")
static var ROLL_LEN_MIN := Tuning.num("movement", "roll", "min_len_m")
## Hitting something at speed without a tech (impact).
static var IMPACT_SAFE := Tuning.num("movement", "impact", "safe_mps")
static var IMPACT_PER := Tuning.num("movement", "impact", "per_mps")
## Catch and swing on branches and vines (_try_catch()).
static var CATCH_M := Tuning.num("movement", "swing", "catch_reach_m")
static var SWING_MAX_R := Tuning.num("movement", "swing", "max_branch_radius_m")
static var SWING_MIN_R := Tuning.num("movement", "swing", "min_radius_m")
static var SWING_CARRY := Tuning.num("movement", "swing", "release_carry")
static var SWING_G := Tuning.num("movement", "swing", "gravity_scale")
static var SWING_SNAP_KEEP := Tuning.num("movement", "swing", "snap_speed_keep")
static var SWING_FLEX_HZ := Tuning.num("movement", "swing", "flex_hz")
static var SWING_FLEX_DAMP := Tuning.num("movement", "swing", "flex_damping")
static var SWING_FLEX_GAIN := Tuning.num("movement", "swing", "flex_gain")
static var SWING_LOAD_PER := Tuning.num("movement", "swing", "load_per_item")
static var SWING_GIVE_S := Tuning.num("movement", "swing", "give_way_s")
static var SWING_HANG_DAMP := Tuning.num("movement", "swing", "hang_damping")
static var SWING_MIN_MPS := Tuning.num("movement", "swing", "min_air_mps")
## Over your run speed on the ground and pushing on, you slow only this.
static var OVERSPEED_DECAY := Tuning.num("movement", "overspeed", "decay_mps2")
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
## The player's height against the rig (movement table "body"): the
## capsule, the eyes and the camera scale with the body.
static var BODY_K := Tuning.num("movement", "body", "player_scale")
static var STAND_HEIGHT := 1.7 * BODY_K
static var CROUCH_HEIGHT := 1.05 * BODY_K
static var CAMERA_Y := 1.5 * BODY_K
static var CROUCH_CAMERA_Y := 0.95 * BODY_K
static var CLIMB_SPEED := Tuning.num("movement", "climb", "simple_mps")
static var CLIMB_REACH_M := Tuning.num("movement", "climb", "reach_m")
## First person: eye height standing (data/look.json retro.eye_m, design
## §AG 7: 1.4 m) and crouched (the same share of it as before).
## (Never above the eyes of the body you are: a person's eyes are about
## 0.93 of their height, the hood top 1.57 m x player_scale.)
static var EYE_Y := minf(float(Tuning.section("look", "retro").get("eye_m", 1.45 * BODY_K)), 1.57 * BODY_K * 0.93)
static var CROUCH_EYE_Y := EYE_Y * 0.9 / 1.45
## Field of view (retro.fov_deg, §AG 7: 78); aiming narrows it by the
## same share as before (70 -> 60).
static var FOV := float(Tuning.section("look", "retro").get("fov_deg", 70.0))
static var AIM_FOV := FOV * 60.0 / 70.0
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
## Frames since a steep face was touched in the air (_tech()), its normal,
## the approach (velocity when first met), whether it's a tree, where.
var _wall_f := 9999
var _wall_n := Vector3.ZERO
var _wall_in := Vector3.ZERO
var _wall_tree := false
var _wall_limb := false
var _wall_p := Vector3.ZERO
var _wj_chain := 0
var _kick_t := 0.0
static var KICK_S := Tuning.num("movement", "wall_jump", "kick_frames") / 60.0
## Clinging to a face (right click held): frames held, time left.
var clinging := false
var _cling_f := 0
var _cling_left := 0.0
## Swinging from a handhold: the graph, the pivot handhold, rope length
## (pivot to the body's middle), time on it.
var swinging := false
var _sw_graph: BranchGraph
var _sw_i := -1
var _sw_len := 0.0
var _sw_t := 0.0
## What the handhold is like (Handholds.props()), how far it's bent and
## how fast it's springing (scene m, m/s), and how long it's been
## overloaded.
var _sw_props := {}
var _sw_off := Vector3.ZERO
var _sw_off_v := Vector3.ZERO
var _sw_over_t := 0.0
## Handholds snapped under you (tests).
var snaps := 0
## The landing roll: time left and its length, direction and speed; a
## heavy landing waiting (frames) for a late crouch, and its fall.
var _rolling := 0.0
var _roll_total := 0.0
var _roll_dir := Vector3.ZERO
var _roll_speed := 0.0
var _roll_wait_f := 0
var _pending_fell := 0.0
var _pending_fall_v := 0.0
var _crouch_press_f := -9999
## An impact waiting (frames) to see if a tech saves it, and its damage.
var _impact_f := 0
var _impact_dmg := 0.0
## How wet the ground is from rain, 0-1 (main sets it from the weather).
var ground_wet := 0.0
## Counters the tests read.
var skids := 0
var landings := 0
## Branch bounces and contact redirects (design §J, §R), for tests.
var bounces := 0
var redirects := 0
## The camera's look (scene, 3D), each physics frame: where contacts
## re-aim momentum.
var _look := Vector3.FORWARD
## A ground jump still rising with jump held (letting go cuts it).
var _rising_jump := false
## The frame right click was last pressed in the air (a bounce's early
## press), and a bounce still open after touchdown (frames left, the fall).
var _tech_press_f := -9999
var _bounce_wait_f := 0
var _bounce_fell := 0.0
var _bounce_fall_v := 0.0
## Height (radius) where you last took off under your own power (a jump,
## a kick, a bounce, a swing release, running off an edge); INF unknown.
## Fall damage counts only the drop below it: your own rise never hurts.
var _takeoff_r := INF
## The planted foot (0 left, 1 right): every landing, bounce and kick
## alternates it (design §J bounds).
var _foot := 0
var wall_jumps := 0
var clings := 0
var swings := 0
var rolls := 0
var impacts := 0
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
## The super meter (design §S): perfect techs and landed hits fill it; an
## overcharged bow or spear spends it (SuperMeter).
var meter := SuperMeter.new()
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
## Perched (design §V): sitting on top of a limb or on the crown of a
## tree, hands free: look, shoot the bow, throw the spear or cast the
## fishing pole from there (each tool gates on `not climbing`, which a
## perch is not), drop back to climbing with the stick, or jump off into
## a bound.
## Entered with crouch while climbing where TreeClimb.perch_hold() allows.
var perched := false
var _perch_key := 0
var _perch_hold := -1
## Tucked in against the trunk (not on top of the wood): where, in the
## tree's frame; INF when sitting on top.
var _perch_local := Vector3.INF
var _perch_wait_f := 0
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
## else the wanderer (PlayerBody).
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
## The ninja run's trailing arms, 0 .. 1 (_update_camera()).
var _arm_trail := 0.0
## Water contacts (Ripples): in the water last frame, and the swimming
## stroke's timer and hand.
var _in_water := false
var _stroke_t := 0.0
var _stroke_hand := 0


func _ready() -> void:
	Hits.on_hit = func(critical: bool) -> void: meter.hit(critical)
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
		_body.scale = Vector3.ONE * BODY_K
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
	_camera.fov = FOV
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


## Where your eyes are (scene): lower crouched or perched, tucked in (what
## animals look for through the leaves, CreatureSpawner).
func eye_position() -> Vector3:
	return global_position + up * (CROUCH_EYE_Y if crouching or perched else EYE_Y)


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
	_look = cam_forward.rotated(cam_right.normalized(), _pitch)
	_update_prompt(delta, cam_forward)
	_update_health(delta)
	bow.update_bow(delta)
	spear.update_spear(delta)
	aim_arc.update_arc()
	_update_camera(delta)
	_update_climb_legs()
	if dead:
		_dead_step(delta)
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		return
	if _wake_t > 0.0:
		# Lying by the fire, then getting up.
		_wake_t = maxf(_wake_t - delta, 0.0)
		var up_k := smoothstep(0.55, 1.0, 1.0 - _wake_t / _wake_total)
		_body.rotation = Vector3(-PI * 0.5 * (1.0 - up_k), 0.0, 0.0)
		_body.position = Vector3(0, 0.2 * (1.0 - up_k), 0)
		velocity = Vector3.ZERO
		_orient()
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
	if perched:
		_perch_step(delta, cam_forward)
		_update_blob(chunks.ground_height(surface_dir))
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		_update_noise(delta, 0.0)
		return

	var radius: float = world.radius_of(global_position)
	var water := chunks.water_level_at(surface_dir)
	var depth := (PlanetConst.RADIUS_M + water) - radius
	swimming = depth > 1.2
	# How fast you were coming down (a splash into water).
	var sink := -velocity.dot(up)

	_update_stance()
	if Input.is_action_just_pressed("crouch"):
		_crouch_press_f = Engine.get_physics_frames()
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var wish := (cam_right * input.x + cam_forward * input.y)
	var on_floor := is_on_floor()
	if clinging or swinging:
		if clinging:
			_cling_step(delta)
		else:
			_swing_step(delta, cam_forward)
		_wall_f += 1
		_update_squat(delta)
		_face((-_wall_n - up * _wall_n.dot(up)).normalized() if clinging and _wall_n != Vector3.ZERO else (cam_forward if first_person else _facing), delta * 2.0)
		_orient()
		_update_blob(chunks.ground_height(surface_dir))
		_spring.rotation = Vector3(_pitch, _yaw_relative_to_body(cam_forward), 0.0)
		_update_noise(delta, velocity.length())
		trees.update_contact(delta, global_position, get_world_3d().direct_space_state)
		return
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
		if _rolling > 0.0:
			# Rolling: no steering, the roll's speed along its way.
			target = _roll_dir * _roll_speed
			_move = target
		elif _squat_t > 0.0:
			target = Vector3.ZERO
		elif wish.length() > 0.1 and _move.length() > SPRINT_SPEED * burden_speed() + 0.1 and speed >= WALK_SPEED * burden_speed() - 0.01 and wish.normalized().dot(_move.normalized()) > 0.7:
			# Faster than your run (out of a roll, a chain, a swing) and
			# pushing on: momentum carries, bleeding off slowly.
			target = wish.normalized() * maxf(speed, _move.length() - OVERSPEED_DECAY * delta)
			rate = ACCEL_MPS2 * 4.0
		elif wish.length() > 0.1 and _move.length() > TURNAROUND_MIN_MPS and wish.normalized().dot(_move.normalized()) < -0.5:
			# Turn-around: a brief skid, then off the other way.
			_move *= TURNAROUND_KEEP
			skids += 1
			footsteps.scuff(self)
		if _rolling <= 0.0 and (target.length() < _move.length() - 0.01 or target.dot(_move) < 0.0):
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
		# The branch bounce (design §J): right click pressed within the
		# window before touchdown, or just after it, turns the landing into
		# a bound toward the look.
		var bounced := false
		if not _was_on_floor:
			var fell_gross := maxf(_fall_top - radius, 0.0) if _fall_top > -INF else 0.0
			if fell_gross >= float(BOUNCE.get("min_fall_m", 1.0)) and Engine.get_physics_frames() - _tech_press_f <= int(BOUNCE.get("window_frames", 14)):
				bounced = _bounce(_fall_speed)
			else:
				if fell_gross >= float(BOUNCE.get("min_fall_m", 1.0)):
					_bounce_wait_f = int(BOUNCE.get("window_frames", 14))
					_bounce_fall_v = _fall_speed
				_land()
		elif _bounce_wait_f > 0:
			_bounce_wait_f -= 1
			if Input.is_action_just_pressed("wall_jump"):
				_bounce_wait_f = 0
				bounced = _bounce(_bounce_fall_v)
		if bounced:
			vy = JUMP_SPEED * float(BOUNCE.get("up_scale", 1.0))
	if on_floor and not swimming and vy > 0.0:
		pass # bounced this frame: in the air again below
	elif on_floor and not swimming:
		_jumped = false
		_wj_chain = 0
		_squat_t = maxf(_squat_t - delta, 0.0)
		_rolling = maxf(_rolling - delta, 0.0)
		# A heavy landing waits a few frames for a late crouch (a roll);
		# else the fall damage lands.
		if _roll_wait_f > 0:
			if Input.is_action_just_pressed("crouch"):
				_roll_wait_f = 0
				_start_roll(_pending_fell, _pending_fall_v)
			else:
				_roll_wait_f -= 1
				if _roll_wait_f == 0:
					# A heavy landing without the roll: the series is over,
					# and the landing costs its miss (design §R miss_scale).
					meter.broke()
					_move *= float(REDIRECT.get("miss_scale", 0.5))
					_fall_damage(_pending_fell)
		# Held jump keeps jumping each time you land (after the squat).
		if Input.is_action_pressed("jump") and not crouching and _squat_t <= 0.0 and _rolling <= 0.0:
			vy = JUMP_SPEED * (SPRINT_JUMP if sprinting else 1.0)
			_takeoff = _move
			_jumped = true
			_rising_jump = true
			_takeoff_r = radius
	elif not swimming and not on_floor:
		if _was_on_floor and not _jumped:
			_takeoff_r = radius # ran off an edge
		# Let go of jump while rising and the rise is cut (a tap is a hop);
		# gravity_up rising, gravity_down falling (design §J).
		if _rising_jump and vy > 0.0 and not Input.is_action_pressed("jump"):
			vy *= JUMP_CUT
			_rising_jump = false
		if vy <= 0.0:
			_rising_jump = false
		vy -= (GRAVITY_UP if vy > 0.0 else GRAVITY_DOWN) * delta
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
	# Right click on the ground facing a wall, a rock or a trunk within
	# reach: onto it, clinging (from play).
	if Input.is_action_just_pressed("wall_jump") and on_floor and not swimming and _bounce_wait_f <= 0 and _ground_cling(cam_forward):
		_was_on_floor = false
		return
	# Right click in the air: the tech (wall jump / cling / catch).
	if Input.is_action_just_pressed("wall_jump") and not on_floor and not swimming:
		_tech_press_f = Engine.get_physics_frames()
		if _tech(cam_forward):
			# Spent on the wall jump, cling or catch: not a bounce as well.
			_tech_press_f = -9999
			_was_on_floor = false
			_update_squat(delta)
			return
	_was_on_floor = on_floor
	velocity = horizontal + up * vy + _knock
	_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	var before := horizontal
	var before_v := velocity
	move_and_slide()
	_wall_f += 1
	# An impact waiting for a tech that never came: it hurts now.
	if _impact_f > 0:
		_impact_f -= 1
		if _impact_f == 0:
			impacts += 1
			meter.broke()
			_damage(_impact_dmg)
			_impact_dmg = 0.0
	for k in get_slide_collision_count():
		var col := get_slide_collision(k)
		# Running into a wall or a trunk stops the part of your momentum
		# that goes into it; the rest slides along.
		var n := col.get_normal()
		if n.dot(up) < 0.7 and _move.dot(n) < 0.0:
			_move -= n * _move.dot(n)
			if not is_on_floor() and _takeoff.dot(n) < 0.0:
				_takeoff -= n * _takeoff.dot(n)
		# A steep face touched in the air: right click within WJ_WINDOW_F
		# frames plants on it (cliff, trunk, ruin wall, boulder).
		if absf(n.dot(up)) < WJ_STEEP and not is_on_floor():
			_wall_n = n
			# The approach: what you were moving at when you first met it
			# (after that the slide has already turned you along it).
			if _wall_f > 1 or _wall_in == Vector3.ZERO:
				_wall_in = before if before.length() > 0.5 else -n
			_wall_f = 0
			_wall_p = col.get_position()
			var wb := col.get_collider()
			_wall_tree = wb is CollisionObject3D and ((wb as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER) != 0
			var wchunk := (wb as Node).get_parent() as TerrainChunk if wb is Node else null
			_wall_limb = wchunk != null and wchunk.is_limb_shape(wb, col.get_collider_shape_index())
		# Straight into a wall, trunk or rock too fast: an impact, unless a
		# tech comes within the window.
		if n.dot(up) < 0.7:
			var into := -before_v.dot(n)
			if into > IMPACT_SAFE and _impact_f == 0:
				_impact_dmg = (into - IMPACT_SAFE) * IMPACT_PER
				_impact_f = WJ_WINDOW_F + WJ_TAP_F
		var body := col.get_collider()
		if body is CollisionObject3D and (body as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER:
			trees.bumped(body, col.get_collider_shape_index(), horizontal.length())
	# Right click pressed a moment before the face came, and still held:
	# the cling takes as you meet it (from play: let go to leap, hold again
	# at the right time to catch the next surface).
	if _wall_f == 0 and not clinging and not is_on_floor() and not swimming and Input.is_action_pressed("wall_jump") \
			and Engine.get_physics_frames() - _tech_press_f <= WJ_WINDOW_F:
		if _tech(cam_forward):
			_tech_press_f = -9999
			_update_squat(delta)
			return
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

	if first_person or aiming() or spear.busy() or (BODY_TURNS_FREE and not is_on_floor() and not swimming):
		# Aiming (or seeing through your own eyes), or in flight (design
		# §R: the body turns freely with the look, a moonwalk if you turn
		# round; it never touches the velocity): face where you look.
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
	if climbing or perched or swimming:
		return false
	var t := tree_ahead(_camera_forward())
	if t.is_empty():
		# The reach ray missed (a leaning trunk, a fork of stems at chest
		# height): the nearest tree whose wood is within reach anyway
		# (from play: taking hold didn't always work).
		var ng := trees.nearest_graph(global_position + up * 1.1, CLIMB_REACH_M)
		if ng != null and ng.valid() and ng.chunk is TerrainChunk:
			var i := ng.key & 0xFFFFF
			var ch := ng.chunk as TerrainChunk
			if i < ch.trees.size() and ch.trees[i][1] >= 3.0 and PlantMeshes.climbable(ch.tree_species(i).shape):
				t = [ch, i]
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
	# Round the trunk: D takes you to your right as you face it.
	_climb_out = _climb_out.rotated(tup, input.x * CLIMB_SPEED * burden_climb() * delta / (r + 0.4))
	_climb_out = (_climb_out - tup * _climb_out.dot(tup)).normalized()
	global_position = base + tup * _climb_y + _climb_out * (r + 0.4)
	velocity = Vector3.ZERO
	_facing = -_climb_out
	if Input.is_action_just_pressed("jump"):
		stop_climb(true)


## The body's legs on the tree (PlayerBody.climb_pose): hugging the trunk
## or steep wood, astride a limb, or knees up under thin wood; ducked in
## against the trunk like hugging it, perched on top astride.
var _climb_last := Vector3.INF


func _update_climb_legs() -> void:
	if not _body is PlayerBody:
		return
	var pb := _body as PlayerBody
	var pose := ""
	if clinging:
		pose = "cling"
	elif climbing:
		pose = trees.climb.pose if _climb_graph else "trunk"
	elif perched:
		pose = "trunk" if _perch_local != Vector3.INF else "straddle"
	pb.climb_pose = pose
	if pose == "":
		_climb_last = Vector3.INF
		return
	if _climb_last != Vector3.INF and climbing and not clinging:
		pb.climb_travel += minf(global_position.distance_to(_climb_last), 0.5)
	_climb_last = global_position


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
	_climb_ease = minf(_climb_ease + delta / 0.25, 1.0)
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
	# Each arm to the hand on its own side (the arms never cross).
	if (hands[1] - hands[0]).dot(global_basis.x) < 0.0:
		var h0: Vector3 = hands[0]
		hands[0] = hands[1]
		hands[1] = h0
	_reach_arms(hands)
	trees.climb_sounds(global_position + up * EYE_Y)
	# Shift perches (or ducks) as soon as the hands have landed: pressed
	# mid-reach, it waits for it (up to half a second).
	if Input.is_action_just_pressed("crouch"):
		_perch_wait_f = 30
	if _perch_wait_f > 0:
		_perch_wait_f -= 1
		if c.perch_hold() >= 0:
			_perch_wait_f = 0
			start_perch(c.perch_hold())
			return
	if Input.is_action_just_pressed("jump"):
		stop_climb(true)


## Sit on top of handhold `i` of the tree you're climbing, or duck in
## against the trunk where you are (TreeClimb.perch_on_top()): climbing
## ends, the hands are free (the bow, the spear and the pole work),
## crouched, the body pinned to the wood (in the tree's frame, so the
## floating origin can't move it).
func start_perch(i: int) -> void:
	var c := trees.climb
	if c.g == null or not c.g.valid():
		return
	_perch_key = c.key
	_perch_hold = i
	_perch_local = Vector3.INF if c.perch_on_top(i) else c.g.frame().affine_inverse() * global_position
	climbing = false
	_climb_graph = false
	perched = true
	_rest_arms()
	_set_crouch(true)
	velocity = Vector3.ZERO
	_move = Vector3.ZERO
	_facing = c.facing.normalized() if c.facing.length() > 0.1 else _facing
	trees.rustle(_climb_chunk, _climb_tree, 0.3)


## Off the perch: back onto the wood (`climb`: take hold again where you
## sat), a jump off into a bound (`jump`), or just a drop.
func stop_perch(jump := false, climb := false) -> void:
	if not perched:
		return
	perched = false
	_set_crouch(false)
	var g := BranchGraphs.find(_perch_key)
	if climb and g != null and g.valid() and _perch_hold >= 0 and _perch_hold < g.size():
		trees.climb.start(g, _perch_hold, global_position, up)
		_climb_from = global_position
		_climb_ease = 0.0
		_climb_graph = true
		climbing = true
		velocity = Vector3.ZERO
		_move = Vector3.ZERO
		return
	var fwd := (_facing - up * _facing.dot(up)).normalized()
	if jump:
		velocity = fwd * 3.0 + up * JUMP_SPEED
		_move = fwd * 3.0
		_jumped = true
		_rising_jump = true
		_takeoff = _move
		_takeoff_r = world.radius_of(global_position)
	else:
		velocity = Vector3.ZERO
		_move = Vector3.ZERO
	_climb_chunk = null
	_climb_tree = -1


func _perch_step(delta: float, cam_forward: Vector3) -> void:
	var g := BranchGraphs.find(_perch_key)
	if g == null or not g.valid() or _perch_hold < 0 or _perch_hold >= g.size():
		stop_perch()
		return
	_fall_speed = 0.0
	_fall_top = -INF
	if _perch_local != Vector3.INF:
		global_position = g.frame() * _perch_local
	else:
		global_position = g.pos(_perch_hold) + up * (g.radius[_perch_hold] + 0.02)
	velocity = Vector3.ZERO
	_move = Vector3.ZERO
	# You turn with the look, so aiming turns you on the spot.
	_face(cam_forward, delta * 0.8)
	_orient()
	if Input.is_action_just_pressed("jump"):
		stop_perch(true)
		return
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if input.length() > 0.5 and not aiming():
		stop_perch(false, true)


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
		arm.transform.basis = Basis(x, y * clampf(length / PlayerBody.ARM_M, 0.4, 1.3), z)


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
	if not floor_now:
		kind = "hung"
	elif walls == 0 and pushing:
		kind = "crease"
	elif pushing:
		kind = "wedge"
	if kind == "" or not still:
		_stuck_t = 0.0
		return
	_stuck_t += delta
	# Caught on the ground alone, free yourself almost at once (a hitch you
	# barely feel); otherwise after STUCK_S.
	if _stuck_t < (JAM_S if kind == "crease" else STUCK_S):
		return
	_stuck_t = 0.0
	# Which way out: where you're pushing, else away from what holds you.
	var want := wish - up * wish.dot(up)
	if want.length() < 0.1:
		want = away - up * away.dot(up)
	if want.length() < 0.1:
		want = -_camera_forward()
	want = want.normalized()
	# Pushing against a trunk or a wall you could simply turn away from
	# isn't being stuck: only when backing off is blocked too (between two
	# trunks, in the V of a tree's roots).
	if kind == "wedge" and walls >= 1 and not test_move(global_transform.translated(up * 0.05), -want * 0.15):
		return
	unsticks += 1
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
			out.append(arm.global_transform * Vector3(0, -PlayerBody.ARM_M, 0))
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
	if perched:
		prompt = "Perched · left click: shoot, throw or cast · Q swap tool · move: back onto the wood · Space: jump off"
	elif climbing and _climb_graph:
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
	if _body is PlayerBody:
		(_body as PlayerBody).set_crouch(1.0 if on else 0.0)
	else:
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


## A spear thrust met the world (a trunk, a wall, a rock) closing at
## `closing` m/s along `dir` (design §K: it cuts both ways): an impact on
## you, on the movement.impact curve, and your momentum into it stops.
func thrust_impact(closing: float, dir: Vector3) -> void:
	var into := _move.dot(dir)
	if into > 0.0:
		_move -= dir * into
	if closing <= IMPACT_SAFE:
		return
	impacts += 1
	meter.broke()
	_damage((closing - IMPACT_SAFE) * IMPACT_PER)


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
		meter.died()
		bow.drawing = false
		spear.cancel()
		stop_climb()
		stop_perch()
		died.emit()


## Back on your feet at full health (main.respawn()); a few seconds'
## grace before anything can hurt you again.
## Waking by the fire after dying: lying there for `seconds`, then up.
func wake(seconds: float) -> void:
	_wake_t = seconds
	_wake_total = maxf(seconds, 0.01)


var _wake_t := 0.0
var _wake_total := 1.0


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
	resting = near_fire and not dead and not climbing and not perched and not swimming and not aiming() \
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
	var r_now: float = world.radius_of(global_position)
	# The drop that counts: from the top of the fall, but never from above
	# where you took off under your own power (a bound 19 m up and back
	# down onto the same ground doesn't hurt; a 30 m cliff still does).
	var top := minf(_fall_top, _takeoff_r) if _takeoff_r < INF else _fall_top
	var fell := maxf(top - r_now, 0.0) if _fall_top > -INF else 0.0
	_takeoff_r = INF
	# Every contact re-aims momentum to the look (design §R): what's kept
	# falls off with the turn.
	var h := _move - up * _move.dot(up)
	var look_h := _look - up * _look.dot(up)
	if h.length() > 0.5 and look_h.length() > 0.1:
		_move = look_h.normalized() * minf(h.length() * _keep(h, look_h, 0), SANITY_MPS)
		redirects += 1
	_plant_foot()
	if fell > HEAVY_FALL_M:
		# A heavy landing: crouch pressed just before touchdown rolls now;
		# else wait a few frames for a late one before the fall hurts.
		if Engine.get_physics_frames() - _crouch_press_f <= ROLL_WINDOW_F:
			_start_roll(fell, _fall_speed)
			landings += 1
			_fall_speed = 0.0
			_fall_top = -INF
			return
		_roll_wait_f = ROLL_WINDOW_F
		_pending_fell = fell
		_pending_fall_v = _fall_speed
	# A couple of frames of landing squat after a jump or a real drop; more
	# after a fall of more than a body length. Running over a bump (off the
	# ground for a frame or two) isn't a landing.
	if _jumped or fell > Tuning.num("movement", "landing", "min_drop_m"):
		_squat_t = HEAVY_SQUAT_S if fell > HEAVY_FALL_M else SQUAT_S
		_squat_len = _squat_t
		landings += 1
	_fall_speed = 0.0
	_fall_top = -INF


## The branch bounce (design §J): a perfect landing on top of a branch,
## ledge or the ground, right click inside the window. The fall turns into
## forward speed toward the look (carry of the fall speed, times gain; the
## run you had kept by the turn's angle) and you bound off again
## (bounce.up_scale of a jump). A chain link, a perfect for the super
## meter; a fall that would hurt is softened like a roll's.
func _bounce(fall_v: float) -> bool:
	var h := _move - up * _move.dot(up)
	var look_h := _look - up * _look.dot(up)
	var dir := look_h.normalized() if look_h.length() > 0.1 else (h.normalized() if h.length() > 0.5 else -global_basis.z)
	var spd := (h.length() * _keep(h, dir, 1) + float(BOUNCE.get("carry", 0.8)) * fall_v) * float(BOUNCE.get("gain", 1.05))
	_move = dir * minf(spd, SANITY_MPS)
	_takeoff = _move
	var r_now: float = world.radius_of(global_position)
	var top := minf(_fall_top, _takeoff_r) if _takeoff_r < INF else _fall_top
	var fell := maxf(top - r_now, 0.0) if _fall_top > -INF else 0.0
	if fell > ROLL_SAFE_M:
		_damage((fell - FALL_SAFE_M) * FALL_DAMAGE_PER_M * ROLL_DAMAGE)
	_roll_wait_f = 0
	_squat_t = 0.0
	_jumped = true
	_rising_jump = false
	_takeoff_r = r_now
	_wj_chain = mini(_wj_chain + 1, WJ_CAP)
	_fall_speed = 0.0
	_fall_top = -INF
	bounces += 1
	landings += 1
	redirects += 1
	meter.perfect("bounce")
	_plant_foot()
	_kick_t = KICK_S
	footsteps.scuff(self)
	make_noise(0.5)
	return true


## The share of speed kept turning from `from` to `to` (design §R,
## movement "redirect" keep_by_angle, interpolated by the angle between
## them in degrees), times the tech's factor: `tech` 1 perfect
## (perfect_gain), -1 missed (miss_scale), 0 plain.
func _keep(from: Vector3, to: Vector3, tech: int) -> float:
	if from.length() < 0.01 or to.length() < 0.01:
		return 1.0
	var ang := rad_to_deg(from.angle_to(to))
	var pts: Array = REDIRECT.get("keep_by_angle", [[0, 1.0], [180, 0.0]])
	var k := float(pts[pts.size() - 1][1])
	for i in range(1, pts.size()):
		var a0 := float(pts[i - 1][0])
		var a1 := float(pts[i][0])
		if ang <= a1:
			k = lerpf(float(pts[i - 1][1]), float(pts[i][1]), clampf((ang - a0) / maxf(a1 - a0, 1e-3), 0.0, 1.0))
			break
	if tech > 0:
		k *= float(REDIRECT.get("perfect_gain", 1.05))
	elif tech < 0:
		k *= float(REDIRECT.get("miss_scale", 0.5))
	return k


## Plant the next foot (design §J bounds): the body lilts toward it.
func _plant_foot() -> void:
	if not bool(Tuning.num("movement", "bounds", "alternate_feet")):
		return
	_foot = 1 - _foot
	if _body is PlayerBody:
		(_body as PlayerBody).plant(_foot)


## Fall damage for a drop of `fell` metres (over FALL_SAFE_M).
func _fall_damage(fell: float) -> void:
	if fell > FALL_SAFE_M:
		_damage((fell - FALL_SAFE_M) * FALL_DAMAGE_PER_M)


## The ninja landing roll after a fall of `fell` m coming down at `fall_v`
## m/s: no damage up to ROLL_SAFE_M, a share of it beyond; the fall turns
## into forward speed; ROLL_LEN_PER_M metres of roll per metre fallen.
func _start_roll(fell: float, fall_v: float) -> void:
	meter.perfect("roll")
	if fell > ROLL_SAFE_M:
		_damage((fell - FALL_SAFE_M) * FALL_DAMAGE_PER_M * ROLL_DAMAGE)
	var h := _move - up * _move.dot(up)
	# The roll goes where you look (design §R), a perfect contact.
	var look_h := _look - up * _look.dot(up)
	_roll_dir = look_h.normalized() if look_h.length() > 0.1 else (h.normalized() if h.length() > 0.5 else (_facing - up * _facing.dot(up)).normalized())
	var kept := h.length() * _keep(h, _roll_dir, 1) if h.length() > 0.5 else h.length()
	_roll_speed = minf(maxf(kept, WALK_SPEED) + ROLL_CARRY * fall_v, ROLL_MAX_MPS)
	var length := clampf(ROLL_LEN_PER_M * fell, ROLL_LEN_MIN, ROLL_LEN_CAP)
	_rolling = length / maxf(_roll_speed, 0.1)
	_roll_total = _rolling
	_move = _roll_dir * _roll_speed
	_squat_t = 0.0
	_roll_wait_f = 0
	rolls += 1
	make_noise(0.35)


## Right click in the air. A steep face touched within WJ_WINDOW_F frames:
## plant on it (a tap becomes a wall jump, a hold a cling), unless it's a
## branch too thin to kick off; then (or with no face) catch a branch or
## vine in reach and swing. True if something happened.
func _tech(cam_forward: Vector3) -> bool:
	var on_wall := _wall_f <= WJ_WINDOW_F and not climbing
	if on_wall and _wall_tree:
		# A limb touched (not the trunk): caught and swung on if it's thin
		# enough; bamboo culms always.
		var near := BranchGraphs.nearest(_wall_p, 0.5)
		if not near.is_empty() and _catchable(near[0], near[1]):
			var g0: BranchGraph = near[0]
			var bamboo := g0.species >= 0 and SpeciesDB.all()[g0.species].shape == PlantSpecies.Shape.BAMBOO
			if _wall_limb or bamboo:
				on_wall = false
	if not on_wall and _wall_f > WJ_WINDOW_F and _wall_f < WJ_WINDOW_F * 4:
		# Pressed after the window: a late tech ends the series.
		meter.broke()
	if on_wall:
		clinging = true
		clings += 1
		_cling_f = 0
		_cling_miss_f = 0
		_cling_left = CLING_S
		_wall_speed = maxf(_wall_in.length(), (velocity - up * velocity.dot(up)).length())
		_move = Vector3.ZERO
		_takeoff = Vector3.ZERO
		velocity = Vector3.ZERO
		_impact_f = 0
		_impact_dmg = 0.0
		_kick_t = 2.0 / 60.0 # the crouch before the kick
		return true
	return _try_catch(cam_forward)


## Right click on the ground: a steep face (a wall, a rock, a trunk)
## within CLING_REACH_M ahead at chest height, then a hop onto it and a
## cling. True if it took.
const CLING_REACH_M := 0.9


func _ground_cling(cam_forward: Vector3) -> bool:
	var fwd := (cam_forward - up * cam_forward.dot(up)).normalized()
	# A fan of rays (knee to head, a little either side): a leaning trunk
	# or a fork isn't where one ray at the chest would look.
	var hit := {}
	for y in [1.0, 0.6, 1.4]:
		for turn in [0.0, 0.35, -0.35]:
			var from: Vector3 = global_position + up * y
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd.rotated(up, turn) * CLING_REACH_M)
			q.exclude = [get_rid()]
			var h := get_world_3d().direct_space_state.intersect_ray(q)
			if not h.is_empty() and absf((h.normal as Vector3).dot(up)) < WJ_STEEP:
				hit = h
				break
		if not hit.is_empty():
			break
	if hit.is_empty():
		return false
	var n: Vector3 = hit.normal
	if absf(n.dot(up)) >= WJ_STEEP:
		return false
	_wall_n = n
	_wall_p = hit.position
	_wall_in = -n
	_wall_f = 0
	var wb: Object = hit.collider
	_wall_tree = wb is CollisionObject3D and ((wb as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER) != 0
	var wchunk := (wb as Node).get_parent() as TerrainChunk if wb is Node else null
	_wall_limb = wchunk != null and wchunk.is_limb_shape(wb, int(hit.shape))
	global_position += up * 0.3
	# Up against it: the ray met it up to CLING_REACH_M off, and a cling
	# a hand's breadth away loses the face on its first move.
	move_and_collide(-n * CLING_REACH_M)
	if not _tech(cam_forward) or not clinging:
		return false
	# Past the planting frames at once: a grab, not a kick.
	_cling_f = WJ_TAP_F + 1
	return true


## A handhold you catch and swing on rather than kick off: a vine, a
## bamboo culm, or a limb (not the trunk) thinner than SWING_MAX_R.
func _catchable(g: BranchGraph, i: int) -> bool:
	if g.radius[i] <= 0.0:
		return false
	if g.is_vine(i):
		return true
	var sp: PlantSpecies = SpeciesDB.all()[g.species] if g.species >= 0 else null
	if sp != null and sp.shape == PlantSpecies.Shape.BAMBOO:
		return true
	return g.limb[i] > 0 and g.radius[i] <= SWING_MAX_R


## Frames a cling rides out without touching its face, and the count.
const CLING_MISS_F := 8
var _cling_miss_f := 0


## Approach speed at the face (a wall jump keeps it if it's more).
var _wall_speed := 0.0


## Holding a face (right click held): a tap (let go within WJ_TAP_F
## frames) kicks off it, a full wall jump that chains; held longer it's a
## cling: WASD crawls over the face (CLING_CRAWL); it holds still when you
## don't (CLING_SLIDE 0) and for as long as you like (CLING_S 0). Letting go of right click (or jump) leaps
## off toward where you look, as steep as you look, at CLING_JUMP of a
## kick, starting the chain over; crouch drops you off it instead.
func _cling_step(delta: float) -> void:
	_cling_f += 1
	var jump := Input.is_action_just_pressed("jump")
	var drop := Input.is_action_just_pressed("crouch") and _cling_f > WJ_TAP_F
	if jump or drop or not Input.is_action_pressed("wall_jump"):
		clinging = false
		if drop:
			velocity = _wall_n * 0.5
			_wj_chain = 0
			meter.broke()
		elif _cling_f <= WJ_TAP_F:
			velocity = _wall_jump(1.0, true)
			meter.perfect("wall_jump")
		else:
			# Out of a cling: it springs you off toward where you look,
			# up or level as you look (from play), but it wasn't the tap.
			velocity = _wall_jump(CLING_JUMP, false, true)
			meter.broke()
		_fall_top = world.radius_of(global_position)
		return
	# (CLING_S 0: no limit; from play, no slipping off.)
	_cling_left -= delta
	if CLING_S > 0.0 and _cling_left <= 0.0:
		# Worn out: slide off the face.
		clinging = false
		velocity = _wall_n * 0.8 - up * 1.0
		_wj_chain = 0
		return
	# Planted (a tap's first frames): held still, whatever the contact.
	if _cling_f <= WJ_TAP_F:
		velocity = Vector3.ZERO
		_kick_t = 2.0 / 60.0
		return
	# Held to the face: WASD crawls over it, up and down and round a trunk
	# (from play); left alone you hold still.
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var n := _wall_n
	var wall_up := up - n * up.dot(n)
	wall_up = wall_up.normalized() if wall_up.length() > 0.1 else up
	var cam_r := _camera_forward().cross(up)
	var wall_r := cam_r - n * cam_r.dot(n)
	wall_r = wall_r.normalized() if wall_r.length() > 0.1 else wall_up.cross(n)
	var crawl := (wall_up * input.y + wall_r * input.x) * CLING_CRAWL
	if input.length() < 0.2 and CLING_SLIDE <= 0.0:
		# Left alone it holds still (from play: no slip-down). Pressing
		# into a round trunk would slide you round and down it.
		velocity = Vector3.ZERO
		_kick_t = 2.0 / 60.0
		_fall_top = world.radius_of(global_position)
		return
	velocity = -n * 1.5 + crawl - (up * CLING_SLIDE if input.length() < 0.2 and CLING_SLIDE > 0.0 else Vector3.ZERO)
	move_and_slide()
	var touching := false
	for k in get_slide_collision_count():
		var cn := get_slide_collision(k).get_normal()
		if absf(cn.dot(up)) < WJ_STEEP:
			touching = true
			# Round a trunk or a boulder: the face turns under you.
			_wall_n = _wall_n.lerp(cn, 0.5).normalized()
	if input.length() > 0.2:
		_face((-_wall_n - up * _wall_n.dot(up)).normalized(), delta * 3.0)
	# Down onto the ground ends it (not crawling up off it: just off the
	# ground the feet still read as on it); so does losing the face for
	# more than a few frames (crawling up a trunk, the flared foot's
	# collider gives way to the next one's narrower one, a hand's breadth
	# in, and the cling let go there).
	_cling_miss_f = 0 if touching else _cling_miss_f + 1
	if (is_on_floor() and input.y <= 0.2) or _cling_miss_f > CLING_MISS_F:
		clinging = false
		velocity = Vector3.ZERO
	_kick_t = 2.0 / 60.0
	_fall_top = world.radius_of(global_position)


## Catch a handhold in reach and swing: moving at least SWING_MIN_MPS, a
## handhold within CATCH_M of your hands on wood between SWING_MIN_R and
## SWING_MAX_R thick (or a vine), ahead of you and not below, toward where
## you look. A vine swings from where it hangs. True if caught.
func _try_catch(cam_forward: Vector3) -> bool:
	if velocity.length() < SWING_MIN_MPS or climbing:
		return false
	var hands := global_position + up * 1.6
	var travel := velocity.normalized()
	var best := []
	var best_score := INF
	for e in BranchGraphs.handholds_within(hands, CATCH_M, SWING_MIN_R):
		var g: BranchGraph = e[0]
		var i: int = e[1]
		if not _catchable(g, i):
			continue
		var to: Vector3 = g.pos(i) - hands
		if to.dot(up) < -0.4:
			continue
		var dn := to.normalized() if to.length() > 0.01 else travel
		var score := float(e[2]) - 0.4 * dn.dot(travel) - 0.4 * dn.dot(cam_forward)
		if score < best_score:
			best_score = score
			best = [g, i]
	if best.is_empty():
		return false
	var g: BranchGraph = best[0]
	var props := Handholds.props(g, best[1])
	if velocity.length() > float(props.break_speed_mps):
		# Too fast for it: it snaps, and you fly on, slower.
		_snap(g, best[1])
		velocity *= SWING_SNAP_KEEP
		_move = velocity - up * velocity.dot(up)
		_takeoff = _move
		return true
	_sw_graph = g
	_sw_props = props
	_sw_i = _sw_graph.vine_top(best[1]) if _sw_graph.is_vine(best[1]) else best[1]
	_sw_len = maxf(_sw_graph.pos(_sw_i).distance_to(global_position + up * 0.9), 0.8)
	_sw_t = 0.0
	_sw_over_t = 0.0
	# It bends under you the way you were going.
	_sw_off = Vector3.ZERO
	_sw_off_v = velocity * float(props.flex) * SWING_FLEX_GAIN
	trees.rustle_at(_sw_graph.pos(_sw_i))
	swinging = true
	swings += 1
	_impact_f = 0
	_impact_dmg = 0.0
	return true


## A pendulum from the handhold, at the speed you came in with: gravity
## pulls, the rope holds the body's middle at _sw_len. Let go (release
## right click, or jump) and you fly on with SWING_CARRY of the speed; a
## chain link. Lets go by itself after SWING_MAX_S; hitting something at
## speed is an impact.
func _swing_step(delta: float, cam_forward: Vector3) -> void:
	_sw_t += delta
	if _sw_graph == null or not _sw_graph.valid() or _sw_i < 0 or _sw_i >= _sw_graph.size():
		_end_swing()
		return
	if Input.is_action_just_pressed("jump") or not Input.is_action_pressed("wall_jump"):
		# Let go and fly on: a perfect swing release, thrown toward the look.
		meter.perfect("swing")
		_end_swing(true)
		return
	if _sw_graph.radius[_sw_i] <= 0.0:
		_end_swing()
		return
	# Too fast for it (a hard swing), or hanging heavier than it bears for
	# a moment: it gives way.
	var load := 1.0 + SWING_LOAD_PER * inventory.count()
	_sw_over_t = _sw_over_t + delta if load > float(_sw_props.hold_load) else 0.0
	if velocity.length() > float(_sw_props.break_speed_mps) or _sw_over_t > SWING_GIVE_S:
		_snap(_sw_graph, _sw_i)
		velocity *= SWING_SNAP_KEEP
		meter.broke()
		_end_swing()
		return
	# The wood springs back toward where it grew.
	var w := TAU * SWING_FLEX_HZ
	_sw_off_v += (-w * w * _sw_off - 2.0 * SWING_FLEX_DAMP * w * _sw_off_v) * delta
	_sw_off += _sw_off_v * delta
	var piv := _sw_graph.pos(_sw_i) + _sw_off
	var p := global_position + up * 0.9
	var v := (velocity - up * GRAVITY * SWING_G * delta) * (1.0 - SWING_HANG_DAMP * delta)
	var nxt := p + v * delta
	nxt = piv + (nxt - piv).normalized() * _sw_len
	velocity = (nxt - p) / delta
	var before_v := velocity
	move_and_slide()
	for k in get_slide_collision_count():
		var n := get_slide_collision(k).get_normal()
		var into := -before_v.dot(n)
		if into > IMPACT_SAFE:
			impacts += 1
			meter.broke()
			_damage((into - IMPACT_SAFE) * IMPACT_PER)
			_end_swing()
			return
	# Both hands on the handhold.
	_reach_arms([piv - global_basis.x * 0.08, piv + global_basis.x * 0.08] as Array[Vector3])
	_fall_top = world.radius_of(global_position)


## Off the handhold. `released`: let go on purpose, so the swing's speed
## is re-aimed to the look (design §R), a perfect contact.
func _end_swing(released := false) -> void:
	swinging = false
	_rest_arms()
	if released and velocity.length() > 0.5:
		velocity = _look.normalized() * minf(velocity.length() * _keep(velocity, _look, 1), SANITY_MPS)
		redirects += 1
	velocity *= SWING_CARRY
	# Let go on the rebound and the spring gives its snapback as a push.
	var snap_back := float(_sw_props.get("snapback", 0.0))
	if snap_back > 0.0 and _sw_off_v.dot(velocity) > 0.0:
		var push := _sw_off_v * snap_back
		velocity += push
		if push.length() > 1.0:
			footsteps.effect(self, "whip")
	_sw_off = Vector3.ZERO
	_sw_off_v = Vector3.ZERO
	_move = velocity - up * velocity.dot(up)
	_takeoff = _move
	_jumped = true
	_rising_jump = false
	_wj_chain += 1
	_fall_top = world.radius_of(global_position)
	_takeoff_r = _fall_top


## Handhold `i` of `g` breaks: a crack (dry wood) or a tearing snap, and
## it's gone from the graph.
func _snap(g: BranchGraph, i: int) -> void:
	g.snap(i)
	snaps += 1
	footsteps.effect(self, "crack")
	make_noise(0.6)


## Wall jump (from a tap on a face, _cling_step()): kick off it back the
## way you came (the reversed approach, turned away from the face if it
## pointed along it), angled WJ_ANGLE up at WJ_SPEED or your approach
## speed if faster, times `scale`; `chained` jumps build by WJ_GAIN each,
## up to WJ_CAP of them (WJ_MAX only a sanity limit); unchained (out of a
## cling) starts the chain over. A kick of the body and a scuff creatures
## hear. Returns the kick's velocity.
func _wall_jump(scale := 1.0, chained := true, aimed := false) -> Vector3:
	var n_h := _wall_n - up * _wall_n.dot(up)
	n_h = n_h.normalized() if n_h.length() > 0.1 else -_camera_forward()
	# The kick goes where you look (design §R), bounded by the wall: look
	# into it and you kick off its mirror; never along it tighter than
	# 0.3 of the way out.
	var look_h := _look - up * _look.dot(up)
	var away := look_h.normalized() if look_h.length() > 0.1 else n_h
	if away.dot(n_h) < 0.0:
		away = (away - n_h * 2.0 * away.dot(n_h)).normalized()
	if away.dot(n_h) < 0.3:
		away = (away + n_h * (0.3 - away.dot(n_h)) * 2.0).normalized()
	# What survives: your approach turned off the wall (its mirror), kept
	# by the angle from there to the kick (a tap is a perfect contact).
	var inc := _wall_in - up * _wall_in.dot(up)
	var natural := inc - n_h * 2.0 * inc.dot(n_h)
	var kept := _wall_speed * _keep(natural, away, 1 if chained else 0)
	redirects += 1
	# A kick's own speed at least; chained jumps (no ground, no cling
	# between) build on it, up to WJ_CAP of them.
	var gain := pow(WJ_GAIN, mini(_wj_chain, WJ_CAP)) if chained else 1.0
	var spd := minf(maxf(WJ_SPEED, kept) * gain * scale, minf(WJ_MAX, SANITY_MPS))
	# `aimed` (letting go of a cling): up or level as you look, between
	# CLING_AIM_MIN and CLING_AIM_MAX above level.
	var ang := WJ_ANGLE
	if aimed:
		ang = clampf(asin(clampf(_look.normalized().dot(up), -1.0, 1.0)), CLING_AIM_MIN, CLING_AIM_MAX)
	var h := away * spd * cos(ang)
	var v := spd * sin(ang)
	_move = h
	_takeoff = h
	_jumped = true
	_rising_jump = false
	_takeoff_r = world.radius_of(global_position)
	_plant_foot()
	_fall_speed = 0.0
	_fall_top = -INF
	_wj_chain = _wj_chain + 1 if chained else 0
	_wall_f = 9999
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
		# One crouch pose for everything that needs it: the landing squat,
		# the kick's first two frames, a cling, a roll.
		if _body is PlayerBody and (_squat_t > 0.0 or clinging or _rolling > 0.0 or _kick_t > KICK_S - 2.0 / 60.0):
			(_body as PlayerBody).set_tuck(1.0 if clinging or _rolling > 0.0 else 0.7)
		var lean := minf(inventory.over() * Tuning.num("movement", "burden", "lean_per_item"), 0.3)
		var kick := -0.45 * sin(PI * _kick_t / KICK_S) if _kick_t > 0.0 and not clinging else 0.0
		# In first person the view never tumbles (the camera hangs off the
		# player, not the body, and keeps the look direction): it only dips
		# a little, in a landing squat or a roll.
		if first_person and _spring != null:
			var eye_dip := _squat_dip
			if _rolling > 0.0 and _roll_total > 0.0:
				eye_dip += SQUAT_DIP_M * 2.0 * sin(PI * (1.0 - _rolling / _roll_total))
			_spring.position.y = (CROUCH_EYE_Y if crouching else EYE_Y) - eye_dip
		if _rolling > 0.0 and _roll_total > 0.0:
			# The roll: the tucked body turns head over heels about its
			# middle, once, the cloak wrapping round.
			var spin := -TAU * (1.0 - _rolling / _roll_total)
			var b := Basis(Vector3.RIGHT, spin)
			var mid := Vector3(0, 0.45, 0) * _body.scale.y
			_body.transform = Transform3D(b.scaled(_body.scale), mid - b * mid)
		else:
			_body.position = Vector3(0, -_squat_dip, 0)
			_body.rotation = Vector3(kick + lean, 0.0, 0.0)


## Dead: you slump to the ground and lie still (main respawns you).
func _dead_step(delta: float) -> void:
	velocity = -up * GRAVITY * 0.5 if not is_on_floor() else Vector3.ZERO
	move_and_slide()
	_body.rotation.x = lerpf(_body.rotation.x, -PI * 0.5, clampf(delta * 3.0, 0.0, 1.0))
	_orient()


# --- View ---------------------------------------------------------------------

## Third person (the camera on a spring arm behind you) or first person
## (at your eyes, your own body hidden from the camera but still casting
## its shadow). In first person the whole body is hidden, cloak, hands and
## boots too, unless movement "camera" first_person_body is on (then the
## parts on PlayerBody.VIEW_LAYER show: hands, the cloak's front, boots).
func _apply_view() -> void:
	if _spring == null:
		return
	var hidden := BODY_LAYER
	if not bool(Tuning.num("movement", "camera", "first_person_body")):
		hidden |= PlayerBody.VIEW_LAYER
	if first_person:
		_spring.spring_length = 0.0
		_spring.position = Vector3(0, CROUCH_EYE_Y if crouching else EYE_Y, 0)
		_camera.cull_mask &= ~hidden
		_pitch = clampf(_pitch, -PITCH_MAX, PITCH_MAX)
	else:
		_spring.spring_length = 4.5
		_spring.position = Vector3(0, CROUCH_CAMERA_Y if crouching else CAMERA_Y, 0)
		_camera.cull_mask |= hidden
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
	_camera.fov = lerpf(FOV, AIM_FOV, aim_power())
	# The elf raises both arms to aim the bow, the right one to hold and
	# throw the spear (an imported model has its own clips); on a branch
	# graph they hold the tree (_reach_arms()).
	if _body is PlayerBody and not (climbing and _climb_graph) and not swinging:
		var spear_arm := spear.arm_angle()
		# The ninja run: between walk and sprint speed, with nothing in
		# hand to do, the arms trail back, a beat behind (through jumps
		# too); any action takes them at once, and they ease back in after.
		var rp := Tuning.section("movement", "run_pose")
		var acting := bow.drawing or not is_nan(spear_arm) or climbing or clinging or aiming()
		var hs := (velocity - up * velocity.dot(up)).length()
		var trail_to := 0.0 if acting or not is_on_floor() and hs < WALK_SPEED else smoothstep(WALK_SPEED, SPRINT_SPEED, hs)
		if acting:
			_arm_trail = 0.0
		elif trail_to > _arm_trail:
			_arm_trail = move_toward(_arm_trail, trail_to, delta / maxf(float(rp.get("blend_in_s", 0.3)), 0.01))
		else:
			_arm_trail = lerpf(_arm_trail, trail_to, clampf(delta / maxf(float(rp.get("arm_lag_s", 0.1)), 0.01), 0.0, 1.0))
		# Trailing: back and a little out from the sides, elbows a touch
		# bent, each arm bobbing with the opposite leg's stride.
		var pb := _body as PlayerBody
		var trail_rad := deg_to_rad(float(rp.get("arm_trail_deg", 76.0)))
		var bob_rad := deg_to_rad(float(rp.get("arm_bob_deg", 6.0)))
		var spread_rad := deg_to_rad(float(rp.get("arm_spread_deg", 14.0)))
		pb.trail_elbow = deg_to_rad(float(rp.get("elbow_bend_deg", 14.0))) * _arm_trail
		var k := clampf(delta * (30.0 if acting else 14.0), 0.0, 1.0)
		for arm in pb.arms:
			var s := 0 if arm.name == "ArmL" else 1
			var sx := -1.0 if s == 0 else 1.0
			var back := -(trail_rad + bob_rad * sin(pb.stride_phase() + PI * (1 - s)))
			var want := 1.35 if bow.drawing else lerpf(0.06, back, _arm_trail)
			if s == 1 and not is_nan(spear_arm):
				want = spear_arm
			var spread := lerpf(0.13, spread_rad, _arm_trail) * sx
			if clinging:
				# Both hands up on the face, held there.
				want = 2.55
				spread = 0.3 * sx
			arm.rotation.x = lerpf(arm.rotation.x, want, k)
			arm.rotation.z = lerpf(arm.rotation.z, spread, k)
	elif _body is PlayerBody:
		# The hands are on the wood: no trailing bend in the elbows.
		(_body as PlayerBody).trail_elbow = 0.0
		_arm_trail = 0.0
	# Head-look (third person only; first person draws no body): the hood
	# follows where the camera looks, the torso past head_max_deg, even
	# pinned to a trunk or a wall.
	if _body is PlayerBody:
		var pb2 := _body as PlayerBody
		if first_person or dead or _camera == null:
			pb2.set_look(0.0, 0.0)
		else:
			var f := _body.global_basis.orthonormalized().inverse() * -_camera.global_basis.z
			pb2.set_look(atan2(-f.x, -f.z), asin(clampf(f.y, -1.0, 1.0)))


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

## Wearing a `kind` of item in equipment `slot` (a bow as ranged, a spear
## as melee): lost with everything else when you die, until you find your
## body again.
func wears(slot: String, kind: String) -> bool:
	var it = inventory.worn_in(slot)
	return it != null and str(it.get("kind", "")) == kind


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
		(_body as PlayerBody).set_velocity(velocity)
		(_body as PlayerBody).set_wind(WeatherFX.plant_wind)
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


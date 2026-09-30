class_name Spear
extends Node3D
## The player's spear (spec D5; agreed at Go): weapon_swap (Q, the pad's
## Y) swaps it with the bow (PlanetPlayer.weapon). With the spear in hand:
##   tap `shoot`   thrust: a jab about REACH_M ahead, a sphere cast from
##                 the chest along the aim (the world, trees, and the
##                 creatures' and people's parts, Hitboxes) that hurts the
##                 creature whose part it meets (placeholder damage);
##   hold `shoot`  raise it over the shoulder, release to throw it at
##                 whatever is under the crosshair (as the bow aims). The
##                 longer it's raised the harder it flies, on the bow's
##                 curve over RAISE_S. It flies much slower than an arrow,
##                 so it's thrown lofted to come down on the crosshair
##                 (_loft()): a visible arc, and a weak throw at something
##                 far falls short. It sticks where it hits (ThrownSpear).
## There is one spear. Thrown, the hand is empty until you walk up to it
## and press interact (right click) within PICK_M (main: after letting go of a tree,
## before turning a log): from the ground, a trunk, a carcass or the
## water. Taking it back puts it in your hand.
##
## Thrusting and throwing are loud (PlanetPlayer.make_noise(), what
## wildlife hears round you), and so is where it lands (NoiseEvents).
## Raising it, like drawing the bow, never slows you (design §N); a throw
## doesn't touch your momentum, and the spear carries it (inherit_velocity).
##
## In hand it's held upright in the right hand; raised, level over the
## shoulder along the aim; with the bow in hand it's slung across the
## back. First person, it's in view to the right.

const LENGTH := 1.9
## The hand, this far back from the tip.
const GRIP_M := 1.15
## A press shorter than this is a thrust; held longer, the spear rises.
static var TAP_S := Tuning.num("combat", "spear", "tap_s")
static var RAISE_S := Tuning.num("combat", "spear", "raise_s")
static var MIN_POWER := Tuning.num("combat", "spear", "min_power")
static var MIN_SPEED := Tuning.num("combat", "spear", "min_speed_mps")
static var MAX_SPEED := Tuning.num("combat", "spear", "max_speed_mps")
static var THROW_DAMAGE := Tuning.num("combat", "spear", "throw_damage")
static var REACH_M := Tuning.num("combat", "spear", "reach_m")
static var THRUST_S := Tuning.num("combat", "spear", "thrust_s")
static var THRUST_DAMAGE := Tuning.num("combat", "spear", "thrust_damage")
static var PICK_M := Tuning.num("combat", "spear", "pick_m")
## The player's noise (PlanetPlayer.noise_level) as it thrusts or throws,
## and how far a thrust's knock is heard where it lands (NoiseEvents).
static var NOISE := Tuning.num("combat", "spear", "noise")
static var THRUST_NOISE_M := Tuning.num("combat", "spear", "thrust_noise_m")

const SHAFT := Color(0.5, 0.36, 0.22)
const HEAD := Color(0.3, 0.3, 0.33)
const BINDING := Color(0.66, 0.56, 0.4)

var player: PlanetPlayer
var raising := false
## Super throws (tests).
var super_shots := 0
## The last thrust's closing speed on what it met, m/s (tests).
var last_closing := 0.0
## Seconds raised.
var charge := 0.0
## Out in the world (flying, stuck or lying there), or null (it's yours).
var thrown: ThrownSpear = null
## "Right click: take the spear back" within reach of it, else "".
var prompt := ""

var _press := -1.0 # seconds `shoot` has been held, -1 when not
var _thrust := 0.0 # thrust under way, 1 .. 0
var _blocked := false # the click that captured the mouse doesn't count
var _prompt_t := 0.0
var _mesh: Node3D # third-person spear, on the player
var _view: Node3D # first-person spear, on the camera
var _voice: AudioStreamPlayer3D


func setup(p: PlanetPlayer) -> void:
	player = p
	_mesh = mesh()
	p.add_child(_mesh)
	_view = Node3D.new()
	_view.name = "SpearView"
	p.camera().add_child(_view)
	var vs := mesh()
	vs.name = "Spear"
	_view.add_child(vs)
	Bow._no_shadow(_view)
	_voice = Audio3D.make("spear", self, "Voice")
	_carry()


## A spear: a long wooden shaft and a knapped stone head bound on with
## sinew, pointing along -Z from its tip at the origin.
static func mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "Spear"
	var shaft := CreatureBodies.cone(root, 0.017, 0.014, LENGTH - 0.12, Vector3(0, 0, (LENGTH + 0.12) * 0.5), SHAFT, 0.0, 6)
	shaft.rotation.x = PI * 0.5
	var head := CreatureBodies.cone(root, 0.034, 0.0, 0.2, Vector3(0, 0, 0.1), HEAD, 0.0, 4)
	head.rotation.x = -PI * 0.5
	head.scale = Vector3(1.0, 1.0, 0.45) # a flat blade
	var bind := CreatureBodies.cone(root, 0.022, 0.022, 0.09, Vector3(0, 0, 0.24), BINDING, 0.0, 6)
	bind.rotation.x = PI * 0.5
	return root


## The spear is in your hand (selected, and not out in the world).
func held() -> bool:
	return player.weapon == "spear" and thrown == null and player.wears("melee", "spear")


## Raised to throw, or mid-thrust: the body turns to the aim.
func busy() -> bool:
	return raising or _thrust > 0.0


## 0-1: how hard a throw would fly right now.
func power() -> float:
	var t := charge / RAISE_S
	return minf((t * t + 2.0 * t) / 3.0, 1.0)


func block_until_release() -> void:
	_blocked = true


## Weapon swapped away: nothing raised.
func cancel() -> void:
	raising = false
	charge = 0.0
	_press = -1.0


## Per physics frame, from PlanetPlayer.
func update_spear(delta: float) -> void:
	if thrown != null and not is_instance_valid(thrown):
		# Gone with whatever it was in: it's yours again (a safety net).
		thrown = null
	var down := Input.is_action_pressed("shoot")
	var held_now := down and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Bow.need_capture)
	if not down:
		_blocked = false
	var can := held() and not player.dead and not player.climbing and not player.swimming
	_thrust = maxf(_thrust - delta / THRUST_S, 0.0)
	if held_now and can and not _blocked:
		_press = maxf(_press, 0.0) + delta
		if not raising and _press >= TAP_S and _thrust <= 0.0:
			raising = true
			charge = 0.0
			_play("bow_draw", 0.7)
		if raising:
			var cap := RAISE_S + float(SuperMeter.overcharge("spear").get("extra_s", 1.0)) if player.meter.has() else RAISE_S * 1.5
			var was_over := overcharge() >= 1.0
			charge = minf(charge + delta, cap)
			if overcharge() >= 1.0 and not was_over:
				_play("bow_draw", 0.5) # the shaft hums: overcharged
	else:
		if _press >= 0.0 and can and not _blocked:
			if raising:
				if power() >= MIN_POWER:
					throw(overcharge() >= 1.0)
			elif _thrust <= 0.0:
				thrust()
		cancel()
	_prompt_t -= delta
	if _prompt_t <= 0.0:
		_prompt_t = 0.2
		prompt = ("%s: take the spear back" % Controls.interact_word()) if in_reach() else ""
	_carry()


## 0-1: how far into the overcharge the raise is (design §S; 0 without
## meter or before the full raise; 1 = a super throw on release).
func overcharge() -> float:
	if not raising or not player.meter.has():
		return 0.0
	return clampf((charge - RAISE_S) / maxf(float(SuperMeter.overcharge("spear").get("extra_s", 1.0)), 0.01), 0.0, 1.0)


## Where the crosshair is (PlanetPlayer.crosshair_point()).
func _aim_point() -> Vector3:
	return player.crosshair_point()


## Jab: a sphere cast REACH_M from the chest toward the crosshair; the
## first thing it meets takes the blow, harder the faster you close on it
## (design §K, combat "strike"); the world meeting it hurts you instead.
func thrust() -> void:
	_thrust = 1.0
	player.make_noise(NOISE)
	_play("bow_release", 0.55)
	var from := player.global_position + player.up * (0.85 if player.crouching else 1.3)
	var dir := _aim_point() - from
	if dir.length() < 0.2:
		dir = -player.camera().global_basis.z
	dir = dir.normalized()
	var space := player.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.12
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = dir * REACH_M
	q.collision_mask = 0xFFFFFFFF # the world and Hitboxes.LAYER
	q.exclude = [player.get_rid()]
	var frac := space.cast_motion(q)
	if frac.is_empty() or frac[1] >= 1.0:
		return
	q.transform = Transform3D(Basis.IDENTITY, from + dir * REACH_M * frac[1])
	q.motion = Vector3.ZERO
	var rest := space.get_rest_info(q)
	var at: Vector3 = rest.get("point", from + dir * REACH_M * frac[1])
	var collider: Object = instance_from_id(rest.collider_id) if rest.has("collider_id") else null
	var shape := int(rest.get("shape", 0))
	var who := Hitboxes.creature_of(collider)
	last_closing = maxf((player.velocity - (Hits.velocity_of(who) if who else Vector3.ZERO)).dot(dir), 0.0)
	if who:
		# Momentum in melee (design §K): the closing speed adds damage on
		# the impact curve, and at kill_mps it kills anything not a mythic.
		# A creature is hurt in the part it met, a camp person complains
		# (Hits).
		var amount := THRUST_DAMAGE + Hits.strike_bonus(last_closing)
		if Hits.strike_kills(last_closing, who):
			amount = Hits.kill_amount(who, Hits.part_of(collider, shape), amount)
		Hits.strike(collider, shape, amount, player.global_position, at, player.camps)
	elif collider != null:
		# A trunk, a wall, a rock: a spear tip is a wall with a point on
		# it, and so is the world (design §K, it cuts both ways).
		player.thrust_impact(last_closing, dir)
	_play("arrow_hit", 0.7)
	NoiseEvents.emit(at, THRUST_NOISE_M)


## Let it fly toward the crosshair.
## Where a spear thrown now would leave from and how fast, as [start,
## velocity] (the throw itself and the aim arc, AimArc, both use it).
func launch() -> Array:
	var p := power()
	var cam := player.camera()
	var from: Vector3
	if player.first_person:
		from = cam.global_position + cam.global_basis.x * 0.25 - cam.global_basis.z * 0.4
	else:
		from = player.global_position + player.up * 1.75 + player.global_basis.x * 0.25 - player.global_basis.z * 0.3
	var speed := lerpf(MIN_SPEED, MAX_SPEED, p)
	var dir := player.sway(_loft(from, _aim_point(), speed))
	return [from, dir * speed + player.velocity * Tuning.num("combat", "spear", "inherit_velocity")]


## Throw it; `is_super`: an overcharged throw (design §S): critical,
## damage_scale, faster, falling less, a red streak; the meter empties.
func throw(is_super := false) -> void:
	var p := power()
	player.make_noise(NOISE)
	var shot := launch()
	var from: Vector3 = shot[0]
	var vel: Vector3 = shot[1]
	var s := ThrownSpear.new()
	s.world = player.world
	s.chunks = player.chunks
	s.camps = player.camps
	s.exclude = [player.get_rid()]
	s.damage = THROW_DAMAGE * p
	if is_super:
		var oc := SuperMeter.overcharge("spear")
		s.damage = THROW_DAMAGE * float(oc.get("damage_scale", 3.0))
		vel *= float(oc.get("speed_scale", 1.3))
		s.super_shot = true
		s.gravity_scale = 1.0 / maxf(float(oc.get("range_scale", 1.5)), 0.01)
		player.meter.spend()
		super_shots += 1
	player.world.world_root.add_child(s)
	s.launch(from, vel)
	thrown = s
	raising = false
	charge = 0.0
	_play("bow_release", 0.6)


## The direction to throw from `from` at `speed` to come down on
## `target`: the flatter of the two arcs that reach it; out of reach, the
## farthest-reaching one (45°) toward it.
func _loft(from: Vector3, target: Vector3, speed: float) -> Vector3:
	var up: Vector3 = player.world.dir_of(from)
	var d := target - from
	var h := d.dot(up)
	var across := d - up * h
	var x := across.length()
	if x < 0.5:
		return d.normalized()
	var g := ThrownSpear.GRAVITY
	var v2 := speed * speed
	var disc := v2 * v2 - g * (g * x * x + 2.0 * h * v2)
	var angle := PI * 0.25
	if disc >= 0.0:
		angle = atan((v2 - sqrt(disc)) / (g * x))
	return (across / x * cos(angle) + up * sin(angle)).normalized()


## Near enough to take it back: its shaft within PICK_M of your chest,
## once it has come to rest.
func in_reach() -> bool:
	if thrown == null or not is_instance_valid(thrown) or not thrown.landed or player.dead:
		return false
	# From your chest, or climbing, from your hands on the tree.
	var chest := player.reach_from()
	var tip := thrown.global_position
	var butt := tip + thrown.global_basis.z.normalized() * LENGTH
	return Geometry3D.get_closest_point_to_segment(chest, tip, butt).distance_to(chest) < PICK_M


## Take it back (in hand).
func pick_up() -> bool:
	if not in_reach():
		return false
	NodeRelease.free_later(thrown)
	thrown = null
	player.weapon = "spear"
	prompt = ""
	_play("arrow_hit", 1.3)
	return true


## The spear: slung on the back while the bow's in hand, upright in the
## right hand, level along the aim when raised or thrusting; in view in
## first person; nowhere when it's out in the world.
func _carry() -> void:
	var fp := player.first_person
	var have := thrown == null and player.wears("melee", "spear")
	_mesh.visible = have and not fp
	_view.visible = have and fp and held()
	if not have:
		return
	var jab := sin(_thrust * PI) if _thrust > 0.0 else 0.0
	if fp:
		var vs: Node3D = _view.get_node("Spear")
		if raising:
			_place(vs, Vector3(0.3, 0.1, 0.1), Vector3(-0.04, -0.03, -1.0))
		elif _thrust > 0.0:
			_place(vs, Vector3(0.22, -0.2, -0.2 - 0.55 * jab), Vector3(-0.1, 0.03, -1.0))
		else:
			_place(vs, Vector3(0.32, -0.36, -0.3), Vector3(-0.05, 0.75, -0.65))
		return
	if not held():
		# Across the back, the point up over the left shoulder.
		_place(_mesh, Vector3(0.02, 1.15, 0.3), Vector3(-0.4, 0.9, 0.08))
		return
	var hand := _hand()
	var aim := player.global_basis.inverse() * (-player.camera().global_basis.z)
	if raising:
		_place(_mesh, hand, aim)
	elif _thrust > 0.0:
		_place(_mesh, hand + aim * 0.35 * jab, aim)
	else:
		_place(_mesh, hand, Vector3(0.0, 0.88, -0.48))


## The right hand, in the player's space.
func _hand() -> Vector3:
	var body := player.get_node_or_null("Body")
	if body is PlayerBody:
		var arm: Node3D = (body as PlayerBody).arms[1]
		return player.to_local(arm.to_global(Vector3(0, -PlayerBody.ARM_M, 0)))
	if raising:
		return Vector3(0.28, 1.9, 0.2)
	return Vector3(0.3, 0.85 if _thrust <= 0.0 else 1.35, -0.2 - 0.3 * _thrust)


## The right arm's pose for the elf (PlanetPlayer._update_camera): up and
## back to throw, straight out to thrust; NAN when the spear doesn't say.
func arm_angle() -> float:
	if not held():
		return NAN
	if raising:
		return 3.5
	if _thrust > 0.0:
		return 1.45
	return 0.35


## Put a spear (tip at its origin, pointing -Z) with its grip at `grip`,
## pointing along `point`.
static func _place(n: Node3D, grip: Vector3, point: Vector3) -> void:
	var f := point.normalized()
	var hint := Vector3.UP if absf(f.y) < 0.95 else Vector3.BACK
	n.transform = Transform3D(Basis.looking_at(f, hint), grip + f * GRIP_M)


func _play(kind: String, pitch: float) -> void:
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.pitch_scale = pitch * randf_range(0.95, 1.05)
	_voice.play()

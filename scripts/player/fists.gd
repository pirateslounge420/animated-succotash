class_name Fists
extends Node3D
## Bare hands (Mike, 29 Sept 2026: "should give the option for a player to
## defend themself if they dont have gear"): with no tool in hand (you
## woke by a fire with nothing, your spear is out in the world, or Q
## brought your hands up), left click (`shoot`) strikes:
##   tap   a jab: a quick punch about REACH_M ahead (a sphere cast from
##         the chest toward the crosshair, like the spear's thrust);
##   hold  wind a haymaker up (WIND_S to full), release to throw it: more
##         damage, a longer reach, a heavier knock.
## Momentum is the weapon here as everywhere (design §K): closing speed on
## what you hit adds the strike bonus (combat "strike"), share MOMENTUM of
## it; at kill_mps a blow kills anything that isn't a mythic. Punch a
## trunk or a rock at speed and it's you that's hurt (thrust_impact). The
## numbers: data/combat.json "fists".
##
## In first person your fist is in view low on the right, drawn back as
## you wind up and driven out on the blow; the wanderer's right arm does
## the same in third person.

static var TAP_S := Tuning.num("combat", "fists", "tap_s")
static var WIND_S := Tuning.num("combat", "fists", "wind_s")
static var REACH_M := Tuning.num("combat", "fists", "reach_m")
static var DAMAGE := Tuning.num("combat", "fists", "damage")
static var HEAVY_DAMAGE := Tuning.num("combat", "fists", "heavy_damage")
static var MOMENTUM := Tuning.num("combat", "fists", "momentum_share")
static var STRIKE_S := Tuning.num("combat", "fists", "strike_s")
static var NOISE := Tuning.num("combat", "fists", "noise")

const GLOVE := Color("#5a4636")

var player: PlanetPlayer
var winding := false
## Seconds wound up.
var charge := 0.0
## Blows thrown and landed (tests), and the last one's closing speed.
var blows := 0
var landed := 0
var last_closing := 0.0

var _press := -1.0
var _strike := 0.0 # a blow under way, 1 .. 0
var _heavy := false
var _blocked := false
var _view: Node3D
var _voice: AudioStreamPlayer3D


func setup(p: PlanetPlayer) -> void:
	player = p
	_view = Node3D.new()
	_view.name = "FistView"
	p.camera().add_child(_view)
	_view.add_child(fist_mesh())
	Bow._no_shadow(_view)
	_voice = Audio3D.make("spear", self, "Voice")
	_carry()


## Your hands are what's in them (PlanetPlayer.in_hand()).
func held() -> bool:
	return player.in_hand() == "hands"


## 0-1: how hard a haymaker would land now.
func power() -> float:
	return clampf(charge / maxf(WIND_S, 0.05), 0.0, 1.0)


func block_until_release() -> void:
	_blocked = true


func cancel() -> void:
	winding = false
	charge = 0.0
	_press = -1.0


## Winding up or mid-blow: the body turns to the aim.
func busy() -> bool:
	return winding or _strike > 0.0


## The right arm's pose for the elf (PlanetPlayer._update_camera): drawn
## back winding up, straight out on the blow; NAN when the hands are empty
## of nothing to do.
func arm_angle() -> float:
	if not held() or player.climbing:
		return NAN
	if winding:
		return 0.6
	if _strike > 0.0:
		return lerpf(0.9, 1.55, sin(_strike * PI))
	return NAN


## Per physics frame, from PlanetPlayer.
func update_fists(delta: float) -> void:
	var down := Input.is_action_pressed("shoot")
	var held_now := down and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Bow.need_capture)
	if not down:
		_blocked = false
	var can := held() and not player.dead and not player.climbing and not player.swimming
	_strike = maxf(_strike - delta / maxf(STRIKE_S, 0.05), 0.0)
	if held_now and can and not _blocked:
		_press = maxf(_press, 0.0) + delta
		if not winding and _press >= TAP_S and _strike <= 0.0:
			winding = true
			charge = 0.0
		if winding:
			charge = minf(charge + delta, WIND_S)
	else:
		if _press >= 0.0 and can and not _blocked and _strike <= 0.0:
			strike(power() if winding else 0.0, winding)
		cancel()
	_carry()


## A blow at `p` power (0 a jab .. 1 a full haymaker): a sphere cast from
## the chest along the aim; the first thing it meets takes it.
func strike(p: float, heavy: bool) -> void:
	_strike = 1.0
	_heavy = heavy
	blows += 1
	player.make_noise(NOISE)
	_play("whip", 1.5 if not heavy else 1.1)
	var from := player.global_position + player.up * (0.85 if player.crouching else 1.3)
	var dir := player.crosshair_point() - from
	if dir.length() < 0.2:
		dir = -player.camera().global_basis.z
	dir = dir.normalized()
	var reach := REACH_M * (1.2 if heavy else 1.0)
	var space := player.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.14
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = dir * reach
	q.collision_mask = 0xFFFFFFFF # the world and Hitboxes.LAYER
	q.exclude = [player.get_rid()]
	var frac := space.cast_motion(q)
	if frac.is_empty() or frac[1] >= 1.0:
		return
	q.transform = Transform3D(Basis.IDENTITY, from + dir * reach * frac[1])
	q.motion = Vector3.ZERO
	var rest := space.get_rest_info(q)
	var at: Vector3 = rest.get("point", from + dir * reach * frac[1])
	var collider: Object = instance_from_id(rest.collider_id) if rest.has("collider_id") else null
	var shape := int(rest.get("shape", 0))
	var who := Hitboxes.creature_of(collider)
	last_closing = maxf((player.velocity - (Hits.velocity_of(who) if who else Vector3.ZERO)).dot(dir), 0.0)
	if who:
		var amount := lerpf(DAMAGE, HEAVY_DAMAGE, p) + Hits.strike_bonus(last_closing) * MOMENTUM
		if Hits.strike_kills(last_closing, who):
			amount = Hits.kill_amount(who, Hits.part_of(collider, shape), amount)
		Hits.strike(collider, shape, amount, player.global_position, at, player.camps)
		landed += 1
		_play("arrow_hit", 0.55)
	elif collider != null:
		player.thrust_impact(last_closing, dir)
		_play("arrow_hit", 0.8)
	NoiseEvents.emit(at, 4.0)


## The fist in view: low right at rest, drawn back and down winding up,
## driven out along the aim on the blow.
func _carry() -> void:
	_view.visible = player.first_person and held() and not player.climbing
	if not _view.visible:
		return
	var rest := Vector3(0.24, -0.3, -0.42)
	var back := Vector3(0.28, -0.34, -0.2)
	var out := Vector3(0.08, -0.14, -0.78 if _heavy else -0.68)
	var pos := rest
	if winding:
		pos = rest.lerp(back, smoothstep(0.0, 1.0, power()))
	elif _strike > 0.0:
		pos = rest.lerp(out, sin(_strike * PI))
	_view.position = pos
	_view.rotation = Vector3(0.1, 0.25, -0.35)


## A gloved fist: the fingers curled over, the thumb across, a wrist.
static func fist_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "Fist"
	var knuckles := CreatureBodies.box(root, Vector3(0.075, 0.06, 0.07), Vector3(0, 0, 0), GLOVE)
	knuckles.name = "Knuckles"
	var thumb := CreatureBodies.box(root, Vector3(0.025, 0.025, 0.05), Vector3(-0.04, -0.02, -0.005), GLOVE.darkened(0.12))
	thumb.name = "Thumb"
	var wrist := CreatureBodies.box(root, Vector3(0.055, 0.05, 0.09), Vector3(0, -0.005, 0.075), GLOVE.darkened(0.2))
	wrist.name = "Wrist"
	return root


func _play(kind: String, pitch: float) -> void:
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.pitch_scale = pitch * randf_range(0.95, 1.05)
	_voice.play()

class_name Bow
extends Node3D
## The player's bow, as simple as Minecraft's: hold `shoot` (left mouse,
## or the pad's right trigger) to draw, release to loose. Power follows
## Minecraft's curve on the time drawn, (t² + 2t) / 3 over a one-second
## draw, capped at 1: a tap barely lobs an arrow, a full draw sends it at
## MAX_SPEED with full damage and a chance of a critical hit. Too short a
## draw (power under MIN_POWER) looses nothing. Walking slows while
## drawing. It's in hand while PlanetPlayer.weapon is "bow" (Q swaps it
## with the Spear); loosing is loud (PlanetPlayer.make_noise()).
##
## The arrow flies from the bow toward whatever is under the crosshair
## (a ray from the camera, over every layer: the world, trees, and the
## creatures' and people's hitbox parts, Hitboxes), so it lands where you
## aim at any range, then falls away with distance.
##
## Overcharge (design §S, SuperMeter): with any super meter, holding past
## the full draw keeps drawing for the overcharge's extra_s; released
## then, the arrow is a super shot (critical, damage_scale, speed_scale,
## falls range_scale less, pierces the first body, a red streak) and the
## meter empties. Released before, a normal full shot, meter kept. The
## nocked arrow's tip glows red while overcharged.
##
## The bow is carried slung on the back, raised when you draw; in first
## person it's in view in front of you and the string comes back as you
## draw.

static var DRAW_S := Tuning.num("combat", "bow", "draw_s")
static var MAX_SPEED := Tuning.num("combat", "bow", "max_speed_mps")
static var MIN_POWER := Tuning.num("combat", "bow", "min_power")
static var DAMAGE := Tuning.num("combat", "bow", "damage")
static var MAX_ARROWS := int(Tuning.num("combat", "bow", "max_arrows"))

var player: PlanetPlayer
## Seconds drawn (0 when not drawing).
var charge := 0.0
var drawing := false
## Super shots loosed (tests).
var super_shots := 0

var _bow: Node3D # third-person bow, on the player
var _view: Node3D # first-person bow, on the camera
var _nocked: Node3D # the arrow on the string in view
var _voice: AudioStreamPlayer3D
var _blocked := false # the click that captured the mouse doesn't draw
## The arrow on the string has caught (§ED.7 fire arrow), until it's loosed.
var nock_lit := false
## How near a flame the drawn arrow's head catches (m).
const FIRE_REACH_M := 1.6
## Draw only while the mouse is captured (off in automated tests, where
## there's no mouse to capture).
static var need_capture := true


func setup(p: PlanetPlayer) -> void:
	player = p
	_bow = BowMesh.build(1.3)
	p.add_child(_bow)
	_view = Node3D.new()
	_view.name = "BowView"
	p.camera().add_child(_view)
	var vb := BowMesh.build(0.62)
	vb.name = "Bow"
	_view.add_child(vb)
	_nocked = BowMesh.arrow(0.42)
	vb.add_child(_nocked)
	# The draw's creak and the release: 3D at the hands.
	_voice = Audio3D.make("bow", self, "Voice")
	_voice.position = Vector3(0, 1.35, -0.3)
	for n in [_bow, _view]:
		_no_shadow(n)
	_carry()


## 0-1: how far into the overcharge the draw is (0 without meter or
## before the full draw; 1 = a super shot on release).
func overcharge() -> float:
	if not drawing or not player.meter.has():
		return 0.0
	return clampf((charge - DRAW_S) / maxf(float(SuperMeter.overcharge("bow").get("extra_s", 1.2)), 0.01), 0.0, 1.0)


## 0-1: how hard an arrow would fly right now.
func power() -> float:
	var t := charge / DRAW_S
	return minf((t * t + 2.0 * t) / 3.0, 1.0)


## Don't start a draw from this press (the click that captured the mouse).
func block_until_release() -> void:
	_blocked = true


## Per physics frame, from PlanetPlayer.
func update_bow(delta: float) -> void:
	var held := Input.is_action_pressed("shoot") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not need_capture)
	if not Input.is_action_pressed("shoot"):
		_blocked = false
	var can := player.weapon == "bow" and player.wears("ranged", "bow") and not player.dead and not player.climbing and not player.swimming
	if held and can and not _blocked:
		if not drawing:
			drawing = true
			charge = 0.0
			_play("bow_draw")
		# The fire arrow (design 4 Oct §ED.7, technique fire_arrow): once
		# learned, a drawn arrow held near any flame catches.
		if not nock_lit and Techniques.knows("fire_arrow") and Torch.flame_near(player.get_tree(), _nock_point(), FIRE_REACH_M):
			nock_lit = true
			_play("torch_light")
		var was_over := overcharge() >= 1.0
		var cap := DRAW_S + float(SuperMeter.overcharge("bow").get("extra_s", 1.2)) if player.meter.has() else DRAW_S * 1.5
		charge = minf(charge + delta, cap)
		if overcharge() >= 1.0 and not was_over:
			_play("bow_draw") # the bow creaks: overcharged
	elif drawing:
		var is_super := overcharge() >= 1.0
		drawing = false
		if can and power() >= MIN_POWER:
			_loose(is_super)
		charge = 0.0
		nock_lit = false
	_carry()


## Where an arrow loosed now would leave from and how fast, as [start,
## velocity] (the shot itself and the aim arc, AimArc, both use it).
func launch() -> Array:
	var p := power()
	var cam := player.camera()
	var from: Vector3
	if player.first_person:
		from = cam.global_position - cam.global_basis.z * 0.5 - player.up * 0.08
	else:
		from = player.global_position + player.up * 1.35 - player.global_basis.z * 0.55
	# Aim at what's under the crosshair.
	# The aim wanders a little (steadiest at a jump's apex): the arc shows
	# it, and the arrow follows the arc.
	var dir := player.sway((player.crosshair_point() - from).normalized())
	return [from, dir * MAX_SPEED * p + player.velocity * Tuning.num("combat", "bow", "inherit_velocity")]


func _loose(is_super := false) -> void:
	var p := power()
	var shot := launch()
	var from: Vector3 = shot[0]
	var vel: Vector3 = shot[1]
	var arrow := Arrow.new()
	arrow.world = player.world
	arrow.chunks = player.chunks
	arrow.camps = player.camps
	arrow.shooter = player
	var dmg := DAMAGE * p
	if p >= 1.0:
		dmg *= 1.0 + randf() * Tuning.num("combat", "bow", "crit_extra") # a critical hit, now and then
	if is_super:
		# The super shot: the meter's spend.
		var oc := SuperMeter.overcharge("bow")
		dmg = DAMAGE * float(oc.get("damage_scale", 3.0))
		vel *= float(oc.get("speed_scale", 1.3))
		arrow.super_shot = true
		arrow.gravity_scale = 1.0 / maxf(float(oc.get("range_scale", 1.5)), 0.01)
		arrow.pierce = 1 if bool(oc.get("pierce", true)) else 0
		player.meter.spend()
		super_shots += 1
	arrow.damage = dmg
	arrow.lit = nock_lit
	player.world.world_root.add_child(arrow)
	arrow.launch(from, vel)
	_play("bow_release")
	# Loud enough for wildlife round you to hear (PlanetPlayer.noise_level).
	player.make_noise(Spear.NOISE)
	# Only so many arrows lie about.
	var arrows: Array = player.world.world_root.get_children().filter(func(n): return n is Arrow)
	for i in maxi(0, arrows.size() - MAX_ARROWS):
		arrows[i].queue_free()


## Where the drawn arrow's head is: just ahead of your hands.
func _nock_point() -> Vector3:
	return player.reach_from() - player.global_basis.z * 0.6


## Where the bow is: slung on the back, raised and drawn in the left hand,
## or in view (first person).
func _carry() -> void:
	var d := power() if drawing else 0.0
	var fp := player.first_person
	var have := player.wears("ranged", "bow")
	_view.visible = have and fp and player.weapon == "bow"
	_bow.visible = have and not fp
	if fp:
		# In view: low left at rest, raised to the middle and canted when
		# drawn, the string (and arrow) coming back toward you.
		# Held in the left hand: low left at rest, lifted toward the middle
		# and canted a little when drawn, the string toward you.
		var rest := Vector3(-0.3, -0.26, -0.62)
		var aim := Vector3(-0.1, -0.08, -0.6)
		var k := 1.0 if drawing else 0.0
		_view.position = rest.lerp(aim, k)
		_view.rotation = Vector3(0.0, 0.12 * (1.0 - k), 0.3 * (1.0 - k) + 0.18 * k)
		var vb: Node3D = _view.get_node("Bow")
		BowMesh.set_draw(vb, d)
		_nocked.visible = drawing
		# Overcharged: the arrow glints red.
		var glint := overcharge() >= 1.0
		for mi in _nocked.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _red() if glint else null
		var nock: Vector3 = vb.get_meta("nock")
		_nocked.position = nock + Vector3(0, 0, -0.42)
	else:
		if drawing:
			_bow.position = Vector3(0.12, 1.35, -0.55)
			_bow.rotation = Vector3(0.0, 0.0, -0.15)
		else:
			_bow.position = Vector3(0.05, 1.15, 0.24)
			_bow.rotation = Vector3(0.0, PI, 0.7)
		BowMesh.set_draw(_bow, d)


func _play(kind: String) -> void:
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.play()


## The first-person bow shouldn't throw a floating shadow.
static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


static var _red_mat: StandardMaterial3D


## The overcharge's red glint (combat "overcharge" tracer_color).
static func _red() -> StandardMaterial3D:
	if _red_mat == null:
		_red_mat = StandardMaterial3D.new()
		_red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_red_mat.albedo_color = Color(Color(str(SuperMeter.overcharge("").get("tracer_color", "#FF2A2A"))), 0.55)
	return _red_mat

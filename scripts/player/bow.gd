class_name Bow
extends Node3D
## The player's bow, as simple as Minecraft's: hold `shoot` (left mouse,
## or the pad's right trigger) to draw, release to loose. Power follows
## Minecraft's curve on the time drawn, (t² + 2t) / 3 over a one-second
## draw, capped at 1: a tap barely lobs an arrow, a full draw sends it at
## MAX_SPEED with full damage and a chance of a critical hit. Too short a
## draw (power under MIN_POWER) looses nothing. Walking slows while
## drawing.
##
## The arrow flies from the bow toward whatever is under the crosshair
## (a ray from the camera), so it lands where you aim at any range, then
## falls away with distance.
##
## The bow is carried slung on the back, raised when you draw; in first
## person it's in view in front of you and the string comes back as you
## draw.

const DRAW_S := 1.0
const MAX_SPEED := 55.0
const MIN_POWER := 0.1
const DAMAGE := 30.0
const MAX_ARROWS := 40

var player: PlanetPlayer
## Seconds drawn (0 when not drawing).
var charge := 0.0
var drawing := false

var _bow: Node3D # third-person bow, on the player
var _view: Node3D # first-person bow, on the camera
var _nocked: Node3D # the arrow on the string in view
var _voice: AudioStreamPlayer3D
var _blocked := false # the click that captured the mouse doesn't draw
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
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 4.0
	add_child(_voice)
	for n in [_bow, _view]:
		_no_shadow(n)
	_carry()


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
	var can := not player.dead and not player.climbing and not player.swimming
	if held and can and not _blocked:
		if not drawing:
			drawing = true
			charge = 0.0
			_play("bow_draw")
		charge = minf(charge + delta, DRAW_S * 1.5)
	elif drawing:
		drawing = false
		if can and power() >= MIN_POWER:
			_loose()
		charge = 0.0
	_carry()


func _loose() -> void:
	var p := power()
	var cam := player.camera()
	var from: Vector3
	if player.first_person:
		from = cam.global_position - cam.global_basis.z * 0.5 - player.up * 0.08
	else:
		from = player.global_position + player.up * 1.35 - player.global_basis.z * 0.55
	# Aim at what's under the crosshair.
	var aim_from := cam.global_position
	var aim_dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(aim_from, aim_from + aim_dir * 400.0)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit.position if not hit.is_empty() else aim_from + aim_dir * 400.0
	var dir := (target - from).normalized()
	var arrow := Arrow.new()
	arrow.world = player.world
	arrow.chunks = player.chunks
	arrow.spawner = player.spawner
	arrow.camps = player.camps
	arrow.exclude = [player.get_rid()]
	var dmg := DAMAGE * p
	if p >= 1.0:
		dmg *= 1.0 + randf() * 0.5 # a critical hit, now and then
	arrow.damage = dmg
	player.world.world_root.add_child(arrow)
	arrow.launch(from, dir * MAX_SPEED * p + player.velocity * 0.5)
	_play("bow_release")
	# Only so many arrows lie about.
	var arrows: Array = player.world.world_root.get_children().filter(func(n): return n is Arrow)
	for i in maxi(0, arrows.size() - MAX_ARROWS):
		arrows[i].queue_free()


## Where the bow is: slung on the back, raised and drawn in the left hand,
## or in view (first person).
func _carry() -> void:
	var d := power() if drawing else 0.0
	var fp := player.first_person
	_view.visible = fp
	_bow.visible = not fp
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

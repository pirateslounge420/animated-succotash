class_name FishingPole
extends Node3D
## The player's fishing pole (design §N, §T: the third tool): Q brings it
## to hand after the bow and the spear. Hold `shoot` (left mouse) to wind
## up and release to cast: the charge sets how far the float flies, a tap
## dropping it at your feet and a full wind-up (combat "fishing" wind_s)
## sending it cast_max_m out along your look, with your own speed carried
## into it (inherit_velocity). It lands where it lands: on water it rides
## the surface and rocks there, on the ground it lies, against a trunk or
## a rock it snags. The line runs from the pole's tip to the float,
## sagging with its slack. With the line out, hold `shoot` to reel it in
## (reel_mps), or scroll the wheel: down reels in, up lets line out (to
## line_max_m); walking off drags the float after you on a taut line. The
## float coming home ends the cast. Bites and fish are Phase 10: for now
## the cast and the line are all there is.
##
## Swapping away, climbing, swimming or dying brings the line in at once.
## The pole rides slung across the back while another tool's in hand,
## held out in the right hand when it's the one, raised back over the
## shoulder while winding; in first person it's in view, tip up and out.

## The pole, butt to tip (m); the hand holds it GRIP_M up from the butt.
const LENGTH := 2.4
const GRIP_M := 0.32
## How far below the tip the float dangles when the line's in.
const DANGLE_M := 0.45
## A wheel notch reels in or lets out this share of a second's reeling.
const NOTCH := 0.35
## The float's flight: gravity (m/s²) and the line's drag (per second).
const GRAVITY := 9.8
const DRAG := 0.35
## Casting's noise (PlanetPlayer.make_noise): a swish and a plop.
const NOISE := 0.22

const CANE := Color("#b99c5c")
const NODE_C := Color("#7a6232")
const WRAP := Color("#5c3e24")
const REEL := Color("#3a3a3c")
const LINE := Color("#e9e8df")
const FLOAT_TOP := Color("#c8281e")
const FLOAT_BOTTOM := Color("#f2efe6")

var player: PlanetPlayer
var winding := false
## Seconds wound (0 when not winding).
var charge := 0.0
## The float is out (cast and not yet reeled home).
var out := false
## In flight, on the water, snagged on something (else lying on land).
var flying := false
var in_water := false
var snagged := false
## How much line is out (m).
var line_m := 0.0
## Casts made (tests).
var casts := 0

var _mesh: Node3D # third-person pole, on the player
var _view: Node3D # first-person pole, on the camera
var _float: Node3D # the float, in the world (rides the floating origin)
var _line: MeshInstance3D
var _im := ImmediateMesh.new()
var _vel := Vector3.ZERO
var _blocked := false
var _cast_anim := 0.0
var _bob_t := 0.0
var _voice: AudioStreamPlayer3D
var _splash: AudioStreamPlayer3D


func setup(p: PlanetPlayer) -> void:
	player = p
	_mesh = mesh()
	p.add_child(_mesh)
	_view = Node3D.new()
	_view.name = "PoleView"
	p.camera().add_child(_view)
	var vp := mesh()
	vp.name = "Pole"
	_view.add_child(vp)
	Bow._no_shadow(_view)
	_float = _float_mesh()
	_float.name = "PoleFloat"
	_float.visible = false
	_line = MeshInstance3D.new()
	_line.name = "PoleLine"
	_line.top_level = true
	_line.mesh = _im
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = LINE
	_line.material_override = mat
	add_child(_line)
	_voice = Audio3D.make("spear", self, "Voice")
	_carry()


func _exit_tree() -> void:
	if is_instance_valid(_float):
		_float.queue_free()


## The pole is in your hand (selected, and yours).
func held() -> bool:
	return player.weapon == "pole" and player.wears("pole", "fishing_pole")


## 0-1: how far a cast would fly now (the bow's curve on the wind-up).
func power() -> float:
	var t := charge / maxf(Tuning.num("combat", "fishing", "wind_s"), 0.05)
	return minf((t * t + 2.0 * t) / 3.0, 1.0)


func block_until_release() -> void:
	_blocked = true


## Swapped away: nothing wound, the line comes in.
func cancel() -> void:
	winding = false
	charge = 0.0
	reel_home()


## The right arm's pose for the elf (PlanetPlayer._update_camera): up and
## back while winding, out in front holding it; NAN when it's not in hand.
func arm_angle() -> float:
	if not held() or player.climbing:
		return NAN
	if winding:
		return 3.1
	if _cast_anim > 0.0:
		return lerpf(1.1, 3.1, _cast_anim)
	return 0.95


## Per physics frame, from PlanetPlayer.
func update_pole(delta: float) -> void:
	var down := Input.is_action_pressed("shoot")
	var held_now := down and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not Bow.need_capture)
	if not down:
		_blocked = false
	var can := held() and not player.dead and not player.climbing and not player.swimming
	_cast_anim = maxf(_cast_anim - delta * 5.0, 0.0)
	if not can:
		winding = false
		charge = 0.0
		if out:
			reel_home()
	elif out:
		# Line out: holding the button reels it in.
		if held_now and not _blocked and not flying:
			reel(-Tuning.num("combat", "fishing", "reel_mps") * delta)
	elif held_now and not _blocked:
		if not winding:
			winding = true
			charge = 0.0
		charge = minf(charge + delta, Tuning.num("combat", "fishing", "wind_s") * 1.5)
	elif winding:
		winding = false
		cast()
		charge = 0.0
	_step_float(delta)
	_carry()
	_draw_line()


## The wheel: `metres` of line in (negative) or out (positive).
func reel(metres: float) -> void:
	if not out or flying:
		return
	line_m = clampf(line_m + metres, 0.0, Tuning.num("combat", "fishing", "line_max_m"))
	if metres < 0.0:
		snagged = false
	if line_m < 1.0:
		reel_home()


## A wheel notch: in (-1) or out (+1).
func notch(sign_: int) -> void:
	reel(float(sign_) * Tuning.num("combat", "fishing", "reel_mps") * NOTCH)


## The float home at the tip: the cast is over.
func reel_home() -> void:
	out = false
	flying = false
	in_water = false
	snagged = false
	line_m = 0.0
	if is_instance_valid(_float):
		_float.visible = false


## Let the float fly: from the tip, along the look lifted into an arc, as
## far as the wind-up says (cast_min_m .. cast_max_m on the level).
func cast() -> void:
	var f := Tuning.section("combat", "fishing")
	var p := power()
	var from := tip()
	var look := -player.camera().global_basis.z
	var up: Vector3 = player.world.dir_of(from)
	var across := look - up * look.dot(up)
	if across.length() < 0.05:
		across = -player.global_basis.z
	across = across.normalized()
	# The look's own pitch, lifted: a cast goes up and out.
	var pitch := clampf(asin(clampf(look.dot(up), -1.0, 1.0)) + deg_to_rad(22.0), deg_to_rad(8.0), deg_to_rad(65.0))
	var reach := lerpf(float(f.get("cast_min_m", 1.0)), float(f.get("cast_max_m", 28.0)), p)
	# The wind-up sets the speed: a full one reaches about cast_max_m on the
	# level at a 35 degree lob (a little more for the line's drag); the look
	# sets the angle, so a flat cast falls shorter and a cast off a height
	# flies farther. A tap barely flicks it (the float drops by your feet).
	var speed := sqrt(reach * GRAVITY / sin(deg_to_rad(70.0))) * lerpf(0.25, 1.2, smoothstep(0.0, 0.3, p))
	_vel = (across * cos(pitch) + up * sin(pitch)) * speed + player.velocity * float(f.get("inherit_velocity", 1.0))
	if not is_instance_valid(_float.get_parent()) or _float.get_parent() == null:
		player.world.world_root.add_child(_float)
	_float.global_position = from
	_float.visible = true
	out = true
	flying = true
	in_water = false
	snagged = false
	line_m = float(f.get("line_max_m", 40.0))
	casts += 1
	_cast_anim = 1.0
	player.make_noise(NOISE)
	_play("whip", 0.8)


## The pole's tip, in the scene: the pole in view in first person, the one
## in hand in third.
func tip() -> Vector3:
	var n: Node3D = _view.get_node("Pole") if player.first_person and _view.visible else _mesh
	return n.global_transform * Vector3(0, 0, -LENGTH)


## Where the float is (scene), or the tip's dangle when the line's in.
func float_position() -> Vector3:
	if out and is_instance_valid(_float):
		return _float.global_position
	return tip() - player.up * DANGLE_M


func _step_float(delta: float) -> void:
	if not out or not is_instance_valid(_float):
		return
	var world = player.world
	var chunks: ChunkManager = player.chunks
	var pos := _float.global_position
	if flying:
		var up: Vector3 = world.dir_of(pos)
		_vel -= up * GRAVITY * delta
		_vel *= maxf(1.0 - DRAG * delta, 0.0)
		var nxt := pos + _vel * delta
		var q := PhysicsRayQueryParameters3D.create(pos, nxt)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			# A trunk, a rock, the ground's collision: it stops there.
			_float.global_position = hit.position + (hit.normal as Vector3) * 0.03
			flying = false
			var hd: Vector3 = world.dir_of(hit.position)
			snagged = (hit.normal as Vector3).dot(hd) < 0.6
			_land(hit.position)
			return
		var nd: Vector3 = world.dir_of(nxt)
		var ground: float = chunks.ground_height(nd)
		var water: float = chunks.water_level_at(nd)
		var surface := maxf(ground, water)
		if world.radius_of(nxt) < PlanetConst.RADIUS_M + surface:
			_float.global_position = world.to_scene(nd, PlanetConst.RADIUS_M + surface)
			flying = false
			in_water = water > ground
			_land(_float.global_position)
			return
		_float.global_position = nxt
		return
	# Landed: the line can't be longer than it is; a taut line drags the
	# float after the tip, over the ground or the water.
	var t := tip()
	var off := pos - t
	if off.length() > line_m:
		snagged = false
		pos = t + off.normalized() * line_m
		var d: Vector3 = world.dir_of(pos)
		var ground2: float = chunks.ground_height(d)
		var water2: float = chunks.water_level_at(d)
		in_water = water2 > ground2
		pos = world.to_scene(d, PlanetConst.RADIUS_M + maxf(ground2, water2))
		if in_water:
			Ripples.wake(get_instance_id(), pos, 0.05, 1.0)
	if pos.distance_to(t) < 1.0:
		reel_home()
		return
	# Riding the water: it rocks on the ripples.
	_bob_t += delta
	var bob := Vector3.ZERO
	if in_water:
		var up2: Vector3 = world.dir_of(pos)
		bob = up2 * (0.012 * sin(_bob_t * 2.3) + Ripples.height_at(pos))
		pos = world.to_scene(world.dir_of(pos), PlanetConst.RADIUS_M + chunks.water_level_at(world.dir_of(pos)))
	_float.global_position = pos + bob
	_float.global_basis = Basis(Quaternion(Vector3.UP, world.dir_of(pos)))


func _land(at: Vector3) -> void:
	line_m = minf(tip().distance_to(at) + 0.5, Tuning.num("combat", "fishing", "line_max_m"))
	if in_water:
		Ripples.splash(at, 0.05, 6.0)
		_play("step_water", 1.5)
	elif not snagged:
		_play("step_grass", 1.4)


## The line: tip to float, sagging by its slack (a hanging curve), or the
## short dangle when it's in.
func _draw_line() -> void:
	_im.clear_surfaces()
	var show := held() or out
	_line.visible = show
	if is_instance_valid(_float):
		_float.visible = out
	if not show:
		return
	var a := tip()
	var b := float_position()
	var up := player.up
	var dist := a.distance_to(b)
	var slack := maxf(line_m - dist, 0.0) if out and not flying else 0.0
	var sag := clampf(dist * 0.04 + slack * 0.45, 0.0, 6.0) if out and not flying else 0.0
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := 16 if out else 2
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) - up * sag * 4.0 * t * (1.0 - t)
		_im.surface_set_color(LINE)
		_im.surface_add_vertex(p)
	_im.surface_end()


## Slung across the back, held out in the right hand, wound back over the
## shoulder; in view in first person.
func _carry() -> void:
	var fp := player.first_person
	var have := player.wears("pole", "fishing_pole")
	_mesh.visible = have and not fp
	_view.visible = have and fp and held()
	if not have:
		return
	var snap := _cast_anim * _cast_anim
	if fp:
		var vp: Node3D = _view.get_node("Pole")
		if winding:
			_place(vp, Vector3(0.34, -0.26, -0.22), Vector3(0.02, 0.95, 0.3))
		else:
			_place(vp, Vector3(0.3, -0.34, -0.34), Vector3(-0.06, lerpf(0.5, 0.95, snap), lerpf(-0.86, 0.3, snap)))
		return
	if not held():
		# Across the back, the tip up over the right shoulder.
		_place(_mesh, Vector3(-0.12, 0.72, 0.26), Vector3(0.35, 0.93, 0.1))
		return
	var hand := _hand()
	if winding:
		_place(_mesh, hand, Vector3(0.05, 0.9, 0.42))
	else:
		_place(_mesh, hand, Vector3(0.0, lerpf(0.55, 0.9, snap), lerpf(-0.84, 0.42, snap)))


## The right hand, in the player's space.
func _hand() -> Vector3:
	var body := player.get_node_or_null("Body")
	if body is PlayerBody:
		var arm: Node3D = (body as PlayerBody).arms[1]
		return player.to_local(arm.to_global(Vector3(0, -PlayerBody.ARM_M, 0)))
	return Vector3(0.3, 1.0, -0.25)


## Put a pole (butt at its origin, tip along -Z) with its grip at `grip`,
## pointing along `point`.
static func _place(n: Node3D, grip: Vector3, point: Vector3) -> void:
	var f := point.normalized()
	var hint := Vector3.UP if absf(f.y) < 0.95 else Vector3.BACK
	n.transform = Transform3D(Basis.looking_at(f, hint), grip - f * GRIP_M)


## A fishing pole: a tapering cane with darker nodes, a wrapped grip and a
## small reel, butt at the origin, tip along -Z.
static func mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "Pole"
	var cane := CreatureBodies.cone(root, 0.016, 0.005, LENGTH, Vector3(0, 0, -LENGTH * 0.5), CANE, 0.0, 6)
	cane.rotation.x = -PI * 0.5
	for k in 4:
		var z := -0.55 - 0.45 * k
		var r := lerpf(0.017, 0.007, (0.55 + 0.45 * k) / LENGTH)
		var ring := CreatureBodies.cone(root, r, r, 0.03, Vector3(0, 0, z), NODE_C, 0.0, 6)
		ring.rotation.x = PI * 0.5
	var wrap := CreatureBodies.cone(root, 0.021, 0.019, 0.34, Vector3(0, 0, -0.19), WRAP, 0.0, 6)
	wrap.rotation.x = PI * 0.5
	var reel := CreatureBodies.cone(root, 0.034, 0.034, 0.028, Vector3(0, -0.045, -0.2), REEL, 0.0, 8)
	reel.rotation.z = PI * 0.5
	return root


## The float: a little red-over-white ball (drawn a size up so it reads on
## the water).
static func _float_mesh() -> Node3D:
	var root := Node3D.new()
	for half in 2:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.045
		s.height = 0.045
		s.is_hemisphere = true
		s.radial_segments = 8
		s.rings = 3
		mi.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = FLOAT_TOP if half == 0 else FLOAT_BOTTOM
		m.roughness = 0.8
		mi.material_override = m
		if half == 1:
			mi.rotation.x = PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _play(kind: String, pitch: float) -> void:
	_voice.stream = SoundSynth.stream(kind, randi())
	_voice.pitch_scale = pitch * randf_range(0.95, 1.05)
	_voice.play()

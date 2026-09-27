class_name NightRider
extends Creature
## One Night Rider (data/creatures/creatures.json "Night rider"): a dark
## horse and its hooded rider (NightRiderBody), moved and posed here. A
## NightRiderPair steers it (want_dir, want_speed) and keeps the two
## together; it is a Creature, so arrows hurt it (hurt()) and it dies,
## topples and fades like any other.
##
## Heavy momentum: speed eases toward what's wanted at `accel_mps2`, and the
## heading turns no tighter than a circle of `turn_radius_m` (a few body
## lengths), with inertia in the turn itself, so it sweeps round in wide
## arcs and can't dodge. Nearly stopped, it can still turn slowly on the
## spot.
##
## Gait: a slow four-beat walk only, never a trot or a gallop. The hooves
## land in turn (left hind, left fore, right hind, right fore, a quarter
## cycle apart). Each hoof is placed by two-bone IK on the leg's nested
## pivots (shoulder or hip, knee or hock): in stance it sweeps back exactly
## as fast as the body moves on, so planted hooves never slide; in swing it
## lifts a hand's width, the knee or hock folding, and sets down softly
## (no spray). The stride grows with speed and the cadence a little; the
## head dips as each fore hoof lands, the body bobs a centimeter or two
## and rolls a touch, the rider sways with it and the tail swings. Hooves
## follow the ground under each of them; the body pitches to the slope.
##
## Each landing is a soft thud (NightRiderSounds "hoof", 3D at that hoof);
## a hoof in water sends Ripples.splash on landing and a Ripples.wake while
## it wades. It wades up to WADE_MAX_M and won't step deeper.
##
## Tuning is the species' "gait" entry (stride_m, stance, lift_m,
## turn_radius_m, accel_mps2, head_dip_deg, bob_m); the walking speed is
## its speed_mps.

const WADE_MAX_M := 0.7
## How fast the turn rate itself can change (rad/s per s): the inertia of
## a heavy body swinging round.
const TURN_ACCEL := 0.12
## Turn rate when (nearly) stopped: turning on the spot, slowly.
const SPOT_TURN := 0.06
## Stance phase at which a hoof has come down (sound, ripples).
const CONTACT := 0.06
## Weight on one hoof (Ripples sizes a ring from it).
const HOOF_MASS_KG := 180.0

var walk_mps := 1.1
var stride_m := 1.15
var stance := 0.62
var lift_m := 0.13
var turn_radius_m := 8.0
var accel_mps2 := 0.25
var head_dip := deg_to_rad(7.0)
var bob_m := 0.015

## Steering (NightRiderPair sets these every tick): the surface direction
## to head for (ZERO: keep the heading) and the speed wanted.
var want_dir := Vector3.ZERO
var want_speed := 0.0
## Now: speed along the heading (m/s), turn rate (rad/s), meters walked
## in all, and the gait cycle (0-1; the left hind lands at 0).
var speed := 0.0
var turn_rate := 0.0
var travelled := 0.0
var phase := 0.0
## A gait phase to keep to (the pair sets the follower's: the leader's
## plus the offset), nudging the cadence a little; < 0: free.
var phase_ref := -1.0
## Seconds it has been held up by water too deep ahead (the pair then
## picks another way).
var blocked_t := 0.0

## NightRiderBody.build()'s result: root, pivots, bones, eyes.
var body := {}

var _legs: Array = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_i := 0
var _scale_m := 1.0 # meters of this body per meter of NightRiderBody's
var _pitch := 0.0
var _lift_amp := 0.0
var _clock := 0.0


func setup(sp: CreatureSpecies, p_world: Node, p_chunks: ChunkManager, p_spawner: Node, d: Vector3, seed_value: int) -> void:
	species = sp
	world = p_world
	chunks = p_chunks
	spawner = p_spawner
	hp = sp.hp_max()
	dir = d
	home = d
	_rng.seed = seed_value
	name = "NightRider"
	heading = CubeSphere.north(d)
	walk_mps = sp.speed_mps
	var g: Dictionary = sp.data.get("gait", {})
	stride_m = float(g.get("stride_m", stride_m))
	stance = clampf(float(g.get("stance", stance)), 0.5, 0.8)
	lift_m = float(g.get("lift_m", lift_m))
	turn_radius_m = maxf(float(g.get("turn_radius_m", turn_radius_m)), 1.0)
	accel_mps2 = maxf(float(g.get("accel_mps2", accel_mps2)), 0.01)
	head_dip = deg_to_rad(float(g.get("head_dip_deg", 7.0)))
	bob_m = float(g.get("bob_m", bob_m))
	_scale_m = sp.size_m / NightRiderBody.REF_HEIGHT
	NightRiderBody.wait_ready(sp)
	body = NightRiderBody.build(sp)
	_body = body.root
	add_child(_body)
	_parts = {"root": _body, "legs": [], "wings": [], "tail": null, "light": null}
	_body.scale = Vector3.ONE * 0.001
	_blob_size = Vector2(0.5, 1.2) * _scale_m
	_blob = BlobShadow.make(self, _blob_size.x, _blob_size.y)
	for i in 3:
		# Falloff and distance muffling: the table's "rider_hooves" (Audio3D).
		_voices.append(Audio3D.make("rider_hooves", self))
	for i in NightRiderBody.LEGS.size():
		var ch := NightRiderBody.leg_chain(body.bones, i)
		var names: Array = NightRiderBody.LEGS[i]
		var hip: Vector3 = ch.hip
		var u0: Vector3 = ch.joint - hip
		var v0: Vector3 = ch.foot - ch.joint
		_legs.append({"upper": body.pivots[names[0]], "lower": body.pivots[names[1]],
			"hip": hip, "joint": ch.joint, "foot": ch.foot,
			"a": Vector2(u0.y, u0.z).length(), "b": Vector2(v0.y, v0.z).length(),
			"ang_u0": atan2(u0.z, u0.y), "ang_v0": atan2(v0.z, v0.y),
			"fore": (names[0] as String).begins_with("Fore"), "offset": i * 0.25,
			"last_ph": -1.0, "key": get_instance_id() * 8 + i})
	hitboxes = _make_hitboxes()
	mode = "walk"


## Already walking at `v` (m/s) when it appears: no run-up.
func set_walking(v: float) -> void:
	speed = v
	want_speed = v
	_lift_amp = clampf(v / walk_mps, 0.0, 1.0)


## Fully there at once (no fade-in), e.g. riding in from out of view.
func appear_now() -> void:
	_fade = 1.0
	place_now()


## Stand where `dir` and `heading` say and pose the legs now, rather than
## on the next tick (a new rider is otherwise at its parent's origin for a
## frame, and anything reading its position gets that).
func place_now() -> void:
	_place_rider(1.0) # a whole second's easing: the pitch settles at once
	_pose(0.0)


## Body length, nose to tail (m).
func body_length_m() -> float:
	return 2.55 * _scale_m


func hurt(amount: float, from_pos: Vector3) -> void:
	super.hurt(amount, from_pos)
	if dead:
		Hitboxes.set_active(hitboxes, false)
		for e in body.get("eyes", []):
			(e as Node3D).visible = false


func tick(delta: float, ctx: Dictionary) -> void:
	if done:
		return
	_clock += delta
	if dead:
		_dead_t += delta
		speed = 0.0
		turn_rate = 0.0
		if _dead_t > 14.0 and not leaving:
			leave()
		_fade = move_toward(_fade, 0.0 if leaving else 1.0, delta)
		if leaving and _fade <= 0.0:
			done = true
			finished.emit(self)
			return
		_place_rider(delta)
		# Topples onto its side, legs gone slack.
		_body.rotation.z = lerpf(_body.rotation.z, PI * 0.5, clampf(delta * 2.5, 0.0, 1.0))
		_lift_amp = move_toward(_lift_amp, 0.0, delta)
		_pose(delta)
		return
	_steer(delta)
	_move(delta)
	_fade = move_toward(_fade, 0.0 if leaving else 1.0, delta * 0.8)
	if leaving and _fade <= 0.0:
		done = true
		finished.emit(self)
		return
	_place_rider(delta)
	_pose(delta)


# --- Movement ------------------------------------------------------------------

## Turn toward want_dir no faster than the turning circle allows, the turn
## rate itself easing (inertia); ease the speed toward want_speed, slowing
## for a sharp turn.
func _steer(delta: float) -> void:
	var ang := 0.0
	if want_dir != Vector3.ZERO and distance_to(want_dir) > 0.3:
		ang = heading.signed_angle_to(_tangent_to(want_dir), dir)
	var max_rate := maxf(speed / turn_radius_m, SPOT_TURN)
	var want_rate := clampf(ang * 0.6, -max_rate, max_rate)
	turn_rate = move_toward(turn_rate, want_rate, TURN_ACCEL * delta)
	heading = heading.rotated(dir, turn_rate * delta)
	var target := want_speed * clampf(1.0 - absf(ang) / PI, 0.3, 1.0)
	var rate := accel_mps2 if target > speed else accel_mps2 * 1.5
	speed = move_toward(speed, target, rate * delta)


func _move(delta: float) -> void:
	if speed > 0.001:
		var step := speed * delta
		var next := (dir + heading * step / PlanetConst.RADIUS_M).normalized()
		if _water_at(next) - _ground_at(next) < WADE_MAX_M:
			dir = next
			travelled += step
			blocked_t = 0.0
		else:
			speed = 0.0
			blocked_t += delta
	elif want_speed <= 0.0:
		blocked_t = 0.0
	heading = (heading - dir * heading.dot(dir)).normalized()


## Stand on the ground: the body pitched to the slope between the fore
## and hind hooves, faded in and out by scale, bobbing with the gait.
func _place_rider(delta: float) -> void:
	var r := PlanetConst.RADIUS_M
	var hf := chunks.ground_height((dir + heading * 0.55 * _scale_m / r).normalized())
	var hb := chunks.ground_height((dir - heading * 0.635 * _scale_m / r).normalized())
	var pitch_to := clampf(atan2(hf - hb, 1.185 * _scale_m), -0.45, 0.45)
	_pitch = lerpf(_pitch, pitch_to, clampf(delta * 3.0, 0.0, 1.0))
	var base := lerpf(_ground_at(dir), (hf + hb) * 0.5, 0.7)
	global_position = world.to_scene(dir, r + base)
	var fwd := heading - dir * heading.dot(dir)
	if fwd.length_squared() < 1e-8:
		fwd = CubeSphere.north(dir)
	global_basis = Basis.looking_at(fwd.normalized(), dir) * Basis(Vector3.RIGHT, _pitch)
	_update_blob()
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_body.scale = Vector3.ONE * species.size_m * maxf(_fade, 0.001) * (1.0 + 0.05 * _flash)


# --- The gait ------------------------------------------------------------------

func _pose(delta: float) -> void:
	var v := maxf(speed, 0.0)
	# Turning on the spot still steps (the hooves travel round).
	var step_v := v + absf(turn_rate) * 1.2 * _scale_m
	var rel := clampf(step_v / walk_mps, 0.0, 1.4)
	var cadence := 0.0
	if rel > 0.02:
		cadence = walk_mps / (stride_m * _scale_m) * clampf(0.55 + 0.45 * rel, 0.55, 1.15)
		if phase_ref >= 0.0:
			# Keep step with the reference (the stride adapts, so hooves
			# still don't slide).
			cadence *= 1.0 + clampf(0.8 * wrapf(phase_ref - phase, -0.5, 0.5), -0.2, 0.2)
		phase = fposmod(phase + cadence * delta, 1.0)
	_lift_amp = move_toward(_lift_amp, clampf(rel, 0.0, 1.0), delta * 1.5)
	# In stance a hoof sweeps back as far as the body moves on meanwhile,
	# so it stays put on the ground (in body units: meters / size_m).
	var s := species.size_m
	var s_now := s * maxf(_fade, 0.001)
	var sweep := v * stance / cadence / s if cadence > 0.0 else 0.0
	var lift := lift_m * _scale_m / s * _lift_amp
	var xf := global_transform * _body.transform
	for leg in _legs:
		var ph := fposmod(phase - float(leg.offset), 1.0)
		var z := 0.0
		var y := 0.0
		if ph < stance:
			z = lerpf(-0.5, 0.5, ph / stance) * sweep
		else:
			var u := (ph - stance) / (1.0 - stance)
			z = lerpf(0.5, -0.5, smoothstep(0.08, 1.0, u)) * sweep
			y = pow(sin(PI * pow(u, 0.85)), 1.3) * lift
		var foot: Vector3 = leg.foot
		var target := foot + Vector3(0.0, y, z)
		# The ground under this hoof, against the body's own ground plane.
		var on_plane := xf * Vector3(foot.x, 0.0, target.z)
		var gd: Vector3 = world.dir_of(on_plane)
		var ground := chunks.ground_height(gd)
		if not dead:
			target.y += clampf((ground - (world.radius_of(on_plane) - PlanetConst.RADIUS_M)) / s_now, -0.3 / NightRiderBody.REF_HEIGHT, 0.3 / NightRiderBody.REF_HEIGHT)
		_ik(leg, target)
		_hoof_events(leg, ph, gd, ground, v)
	# Head, body, rider, tail.
	var dip := 0.0
	for leg in _legs:
		if leg.fore:
			var ph := fposmod(phase - float(leg.offset), 1.0)
			if ph < 0.4:
				dip += sin(PI * ph / 0.4)
	dip *= head_dip * _lift_amp
	var breathe := sin(_clock * 1.25) * 0.012
	var pv: Dictionary = body.pivots
	(pv.Neck as Node3D).rotation.x = -dip * 0.7 + breathe
	(pv.Head as Node3D).rotation.x = -dip * 0.45 - breathe * 0.5
	var bob := bob_m * _scale_m * _lift_amp * sin(TAU * (4.0 * phase + 0.15))
	_body.position = Vector3(0.0, bob, 0.0)
	var roll := 0.012 * _lift_amp * sin(TAU * phase)
	if not dead:
		_body.rotation.z = roll
	(pv.Rider as Node3D).rotation = Vector3(-0.025 * _lift_amp * sin(TAU * (2.0 * phase + 0.1)), 0.0, -roll * 0.7)
	(pv.RiderHead as Node3D).rotation.x = 0.02 * _lift_amp * sin(TAU * (4.0 * phase + 0.35)) + breathe * 0.5
	var reins := 0.035 * _lift_amp * sin(TAU * (2.0 * phase + 0.3))
	(pv.ArmL as Node3D).rotation.x = reins
	(pv.ArmR as Node3D).rotation.x = reins
	(pv.Tail as Node3D).rotation = Vector3(-0.06 * _lift_amp, 0.1 * _lift_amp * sin(TAU * phase) + 0.04 * sin(_clock * 0.6), 0.0)


## Two-bone IK in the leg's side plane: turn the upper pivot (shoulder or
## hip) and the lower (knee or hock) so the hoof reaches `t` (body units).
## Fore knees bend forward, hind hocks back. Out of reach, the leg points
## at it straight: the hoof comes down onto the ground there or leaves it
## (landing, push-off) without sliding.
func _ik(leg: Dictionary, t: Vector3) -> void:
	var hip: Vector3 = leg.hip
	var rel := Vector2(t.y - hip.y, t.z - hip.z)
	var a: float = leg.a
	var b: float = leg.b
	var d := clampf(rel.length(), absf(a - b) + 1e-4, (a + b) * 0.9995)
	var th := atan2(rel.y, rel.x)
	var phi := acos(clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0))
	var alpha := th + phi if leg.fore else th - phi
	var jp := Vector2(cos(alpha), sin(alpha)) * a
	var tp := Vector2(cos(th), sin(th)) * d
	var lv := tp - jp
	var beta := atan2(lv.y, lv.x)
	var up_rot := wrapf(alpha - float(leg.ang_u0), -PI, PI)
	var low_rot := wrapf(beta - float(leg.ang_v0) - up_rot, -PI, PI)
	(leg.upper as Node3D).rotation = Vector3(up_rot, 0.0, 0.0)
	(leg.lower as Node3D).rotation = Vector3(low_rot, 0.0, 0.0)


## A hoof landing: a soft thud there, a splash if it's in water; wading, a
## wake.
func _hoof_events(leg: Dictionary, ph: float, gd: Vector3, ground: float, v: float) -> void:
	var last: float = leg.last_ph
	leg.last_ph = ph
	if last < 0.0:
		return # first pose: nothing has landed yet
	var water := chunks.water_level_at(gd)
	var wet := water > ground + 0.05
	var landed := (last < CONTACT and ph >= CONTACT) or (last > ph and ph >= CONTACT and ph < 0.5)
	if not landed and not wet:
		return
	var lower: Node3D = leg.lower
	var hoof_pos := lower.global_transform * ((leg.foot as Vector3) - (leg.joint as Vector3))
	if landed and _lift_amp > 0.2 and _fade > 0.5:
		var p := _voices[_voice_i]
		_voice_i = (_voice_i + 1) % _voices.size()
		p.global_position = hoof_pos
		p.stream = NightRiderSounds.stream("hoof", _rng.randi())
		p.pitch_scale = _rng.randf_range(0.9, 1.06) / sqrt(_scale_m)
		p.volume_db = lerpf(-14.0, -3.0, clampf(_lift_amp, 0.0, 1.0)) + (2.0 if wet else 0.0)
		p.play()
		if wet:
			Ripples.splash(world.to_scene(gd, PlanetConst.RADIUS_M + water), HOOF_MASS_KG, v + 0.6)
	if wet and v > 0.05:
		Ripples.wake(int(leg.key), world.to_scene(gd, PlanetConst.RADIUS_M + water), HOOF_MASS_KG, v)


# --- Hitboxes -------------------------------------------------------------------

## Capsules and a sphere matching the visible body (spec D5), each riding
## its bone's pivot: barrel, neck, head, each leg's upper and lower part,
## tail; the rider's body, hood and arms (Hitboxes' parts: what arrows
## hit). Plus the one body the player bumps into: a capsule through the
## horse's barrel, inside the barrel's part (Hitboxes.blocker). Meters in
## NightRiderBody's frame.
func _make_hitboxes() -> Array:
	var h := NightRiderBody.REF_HEIGHT
	var pv: Dictionary = body.pivots
	var bones: Dictionary = body.bones
	var out: Array = []
	var cap := func(bone: String, a: Vector3, b: Vector3, r: float) -> void:
		var at: Vector3 = bones[bone].world
		out.append(Hitboxes.capsule(self, pv[bone], a / h - at, b / h - at, r / h))
	cap.call("Root", Vector3(0, 1.2, -0.72), Vector3(0, 1.25, 0.78), 0.4)
	cap.call("Neck", Vector3(0, 1.4, -0.64), Vector3(0, 1.93, -0.97), 0.2)
	cap.call("Head", Vector3(0, 1.93, -1.07), Vector3(0, 1.56, -1.38), 0.13)
	cap.call("Tail", Vector3(0, 1.45, 0.92), Vector3(0, 0.8, 1.1), 0.12)
	for i in NightRiderBody.LEGS.size():
		var names: Array = NightRiderBody.LEGS[i]
		var x := 0.19 * (-1.0 if (names[0] as String).ends_with("L") else 1.0)
		if (names[0] as String).begins_with("Fore"):
			cap.call(names[0], Vector3(x, 1.1, -0.53), Vector3(x, 0.56, -0.55), 0.105)
			cap.call(names[1], Vector3(x, 0.52, -0.55), Vector3(x, 0.08, -0.55), 0.09)
		else:
			cap.call(names[0], Vector3(x, 1.05, 0.62), Vector3(x, 0.58, 0.73), 0.115)
			cap.call(names[1], Vector3(x, 0.53, 0.72), Vector3(x, 0.08, 0.64), 0.09)
	cap.call("Rider", Vector3(0, 1.66, -0.1), Vector3(0, 2.15, -0.13), 0.25)
	for arm in ["ArmL", "ArmR"]:
		var sx := -1.0 if arm == "ArmL" else 1.0
		cap.call(arm, Vector3(0.25 * sx, 2.1, -0.13), Vector3(0.15 * sx, 1.8, -0.47), 0.09)
	var hat: Vector3 = bones.RiderHead.world
	out.append(Hitboxes.sphere(self, pv.RiderHead, Vector3(0, 2.4, -0.13) / h - hat, 0.19 / h))
	var rat: Vector3 = bones.Root.world
	out.append(Hitboxes.blocker(self, pv.Root, Vector3(0, 1.2, -0.6) / h - rat, Vector3(0, 1.25, 0.66) / h - rat, 0.34 / h))
	return out

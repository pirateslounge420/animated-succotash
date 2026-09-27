class_name PondCrawler
extends Creature
## The Pond Crawler (data/creatures/creatures.json "Pond Crawler"): a
## mythic of swamp and bog water, out at night. A rounded hooded lump with
## one large blue slit eye that is a real point light (PondCrawlerBody),
## walking on two long arms with splayed fingers: wading, never swimming.
##
## Physics: the hands are contact points. A planted hand rests on the pond
## floor (the ground under the water); a step lifts it out of the water in
## an arc and brings it down again, and where it breaks the surface on the
## way down it fires a ripple (Ripples.splash, sized by the hand's mass and
## speed) and a soft wet slap (3D sound at that spot). The body is not
## animated: it hangs from the planted hands, pulled toward a point behind
## them by a spring with little damping, so it lags, overshoots and sways,
## leans onto the supporting arm while the other is up, and bobs as it
## breathes. Its slow drift through the water trails a wide wake
## (Ripples.wake, the body's mass at its waterline, every frame it's in the
## water). The arms reach the hands by two-bone IK (shoulder, elbow high
## and outward, wrist); a planted hand lies flat on the floor, fingers
## splayed, and curls as it lifts.
##
## Behavior (spec: aggressive at close range, otherwise still):
##   wait    mostly motionless in the water: tiny sway, a slow re-plant of
##           one hand now and then (a single ring), the eye a narrow slit
##   drift   rarely, a few slow arm-over-arm steps to another spot nearby
##   lurch   the player came within `notice_m` (scaled by how loud they
##           are, like wolf packs): a fast arm-over-arm crawl toward them,
##           hands lifting before the last one lands, so rings stack and
##           overlap; the eye opens wide
##   strike  within reach: its steps hold until a hand is down, and that
##           hand rears up and slams down where the player stands
##           (CreatureSpawner.player_hit, the species' `bite`)
##   return  the player got away: back to where it waited
## It never leaves wadeable water (`water_bound`): every plant, and the
## body, must be over water `wade_m` deep, inside its `biome_lock`; at the
## edge it stops (no step that gets nowhere) and reaches. Shot, it turns
## on you (Creature.hurt: angry) and hunts within 70 m; killed, the eye
## goes out and it slumps into the water, then fades.
##
## Hitboxes (spec D5, the shared Hitboxes helper): the lump, hood, both
## upper arms, forearms and hands are capsules and spheres riding the
## skeleton and the arm bones (_make_hitboxes()): an arrow's ray meets the
## part it hits and sticks in it. The player bumps into a blocker in the
## lump, so it can't walk through the body.
##
## It is never spawned in normal play (`"spawn": "disabled"`, until
## Phase 7); debug_spawn() places one (tools/pond_crawler_demo.gd).
## Tunables are the species' "rig" object in the data (DEFAULTS below).

const DEFAULTS := {
	"notice_m": 26.0,
	"strike_m": 2.4,
	"wait_step_s": 2.2,
	"lurch_step_s": 0.55,
	"lurch_overlap": 0.4,
	"stride_m": 0.6,
	"lift_m": 0.35,
	"lurch_lift_m": 0.65,
	"body_kg": 110.0,
	"hand_kg": 6.0,
	"wade_m": [0.08, 1.3],
	"eye_light_m": 5.5,
	"eye_light_energy": 0.8,
	"drift_every_s": [20.0, 50.0],
	"replant_every_s": [5.0, 12.0],
}

## The body's center rides this high over the floor (REF meters), and
## never lower than LIFT over the water surface (the face and eye stay out
## of the water: it wades, it doesn't swim).
const RIDE := 0.45
const LIFT := 0.02
const STRIKE_S := 0.42
const STRIKE_LIFT := 1.0
## A step moves a hand at least this far (REF meters), else it isn't
## taken (_step).
const MIN_STEP := 0.2

## A hand: where it's planted (palm on the floor, parent-local, so the
## floating origin never moves it) and its swing.
class Hand:
	var sd := -1.0
	var plant := Vector3.ZERO
	## The fingers' direction when planted (scene space, tangent).
	var fwd := Vector3.FORWARD
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var from_fwd := Vector3.FORWARD
	var to_fwd := Vector3.FORWARD
	var t := 1.0
	var dur := 1.0
	var lift := 0.4
	var swinging := false
	var strike := false
	## Carries the body (planted in wadeable water).
	var wet := true
	## Current palm point (parent-local) and its height over the water.
	var pos := Vector3.ZERO
	var above := -1.0
	var voice: AudioStreamPlayer3D

## Rig tunables (DEFAULTS, overridden by the data's "rig").
var rig := {}
## Everything each ripple call carried, for tools to check the wiring
## (Ripples itself is a no-op until the ripple simulation is attached):
## counters plus the last few splashes [time, scene pos, kg, m/s] and the
## last wake [time, key, scene pos, kg, m/s].
var ripple_stats := {"splash": 0, "wake": 0, "splash_kg": Vector2(INF, 0), "splash_mps": Vector2(INF, 0),
	"wake_kg": Vector2(INF, 0), "wake_mps": Vector2(INF, 0)}
var last_splashes: Array = []
var last_wake: Array = []
## Whether movement keeps to the species' biome_lock (tools may relax it
## when no swamp or bog water is at hand).
var lock_biome := true
## Which way it faces when placed (a direction along the ground; set
## before setup()), or ZERO for a random heading.
var facing := Vector3.ZERO

var _k := 1.0 # size_m / REF_HEIGHT
var _skel: Skeleton3D
var _bones := {}
var _meshes: Array[MeshInstance3D] = []
var _eye_light: OmniLight3D
var _hands: Array[Hand] = []
var _body_l := Vector3.ZERO # body center, parent-local
var _vel := Vector3.ZERO
var _acc := Vector3.ZERO
var _roll := 0.0
var _pitch := 0.0
var _roll_v := 0.0
var _pitch_v := 0.0
var _goal_l := Vector3.ZERO
var _home_l := Vector3.ZERO
var _clock := 0.0
var _replant_t := 5.0
var _drift_t := 30.0
var _lost_t := 0.0
var _strike_cd := 0.0
## Lurching with the player within strike reach (_think).
var _in_reach := false
## No way on toward the goal (the water ends ahead): it stops there
## (_hands_step), looking again every _retry_t; a hand out of place that
## has nowhere better to go waits _settle_t.
var _blocked := false
var _retry_t := 0.0
var _settle_t := 0.0
var _eye_open := 0.5
var _blink_t := 4.0
var _eye_flash := 0.0
var _dead_eye := 1.0
var _wade := Vector2(0.08, 1.3)
var _rest := {} # rest joints (skeleton space) per side


func setup(sp: CreatureSpecies, p_world: Node, p_chunks: ChunkManager, p_spawner: Node, d: Vector3, seed_value: int) -> void:
	species = sp
	world = p_world
	chunks = p_chunks
	spawner = p_spawner
	hp = sp.hp_max()
	dir = d
	home = d
	_rng.seed = seed_value
	name = sp.name.replace(" ", "_")
	rig = DEFAULTS.duplicate()
	rig.merge(sp.data.get("rig", {}), true)
	var wade: Array = rig.wade_m
	_wade = Vector2(float(wade[0]), float(wade[1]))
	heading = CubeSphere.north(d).rotated(d, _rng.randf() * TAU)
	var f := facing - d * facing.dot(d)
	if f.length_squared() > 1e-8:
		heading = f.normalized()
	mode = "wait"
	var b := PondCrawlerBody.build(sp)
	_body = b.root
	_k = b.scale
	_skel = b.skeleton
	_bones = b.bones
	_meshes.assign(b.meshes)
	add_child(_body)
	_eye_light = PondCrawlerBody.make_light(sp, float(rig.eye_light_m), float(rig.eye_light_energy))
	_eye_light.position = PondCrawlerBody.EYE_LIGHT * _k
	add_child(_eye_light)
	_parts = {"root": _body, "legs": [], "wings": [], "tail": null, "light": _eye_light}
	for sd: float in [-1.0, 1.0]:
		var s0 := PondCrawlerBody.mirror(PondCrawlerBody.SHOULDER, sd)
		var e0 := PondCrawlerBody.mirror(PondCrawlerBody.ELBOW, sd)
		var w0 := PondCrawlerBody.mirror(PondCrawlerBody.WRIST, sd)
		var p0 := PondCrawlerBody.mirror(PondCrawlerBody.PALM, sd)
		var dir0 := (w0 - s0).normalized()
		var pole := (e0 - s0) - dir0 * (e0 - s0).dot(dir0)
		_rest[sd] = {"s": s0, "e": e0, "w": w0, "palm": p0, "l1": s0.distance_to(e0), "l2": e0.distance_to(w0),
			"pole": pole.normalized(), "n0": (e0 - s0).cross(w0 - e0).normalized(),
			"hand": _frame(PondCrawlerBody.hand_fwd(sd), Vector3.UP)}
	_make_hitboxes(b.attach)
	# Start in the water where it was put: the body there, both hands
	# planted in front of it.
	_body_l = _to_l(world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d)))
	_body_l = _to_l(_body_target(_to_g(_body_l), true))
	_home_l = _body_l
	_goal_l = _body_l
	for sd: float in [-1.0, 1.0]:
		var h := Hand.new()
		h.sd = sd
		h.fwd = _plant_fwd(sd)
		var spot := _find_plant(h, _to_g(_body_l), 0.0, 1.0)
		if spot == Vector3.INF:
			spot = _floor_point(_neutral(sd, _to_g(_body_l)))
		h.plant = _to_l(spot)
		h.pos = h.plant
		h.wet = _wadeable(spot, _wade.x)
		# Falloff and distance muffling: the table's "crawler_hands" (Audio3D).
		h.voice = AudioStreamPlayer3D.new()
		h.voice.name = "Plant" + PondCrawlerBody.side_name(sd)
		h.voice.top_level = true
		Audio3D.apply(h.voice, "crawler_hands")
		add_child(h.voice)
		_hands.append(h)
	_body_l = _to_l(_body_target(_to_g(_body_l), false))
	_replant_t = _rng.randf_range(1.5, 3.0)
	_drift_t = _rand_range(rig.drift_every_s)
	_blink_t = _rng.randf_range(2.0, 6.0)
	_fade = 1.0
	_pose(0.0)


## Hitboxes (Hitboxes): the lump and hood (rigid with the body, on the
## skeleton), and each arm's upper arm, forearm and hand, riding their
## bones (`attach`: bone name -> BoneAttachment3D), each part named for
## what it is; then the blocker the player bumps into, inside the lump.
## Points are in each node's own space, REF meters (the body's scale
## applies).
func _make_hitboxes(attach: Dictionary) -> void:
	hitboxes.clear()
	_hitbox("Lump", Hitboxes.capsule(self, _skel, Vector3(0, -0.05, 0.32), Vector3(0, -0.05, -0.12), 0.52))
	_hitbox("Hood", Hitboxes.sphere(self, _skel, Vector3(0, 0.46, -0.16), 0.42))
	for sd: float in [-1.0, 1.0]:
		var n := PondCrawlerBody.side_name(sd)
		var r: Dictionary = _rest[sd]
		_hitbox("UpperArm" + n, Hitboxes.capsule(self, attach["Shoulder" + n], Vector3.ZERO, r.e - r.s, 0.095))
		_hitbox("Forearm" + n, Hitboxes.capsule(self, attach["Elbow" + n], Vector3.ZERO, r.w - r.e, 0.07))
		var fwd := PondCrawlerBody.hand_fwd(sd)
		_hitbox("Hand" + n, Hitboxes.capsule(self, attach["Wrist" + n], r.palm - r.w - fwd * 0.04, r.palm - r.w + fwd * 0.2, 0.09))
	_hitbox("Blocker", Hitboxes.blocker(self, _skel, Vector3(0, -0.05, 0.28), Vector3(0, -0.05, -0.08), 0.44))


func _hitbox(part: String, body: StaticBody3D) -> void:
	body.name = part
	hitboxes.append(body)


## Show or hide it (its light too).
func set_visible_body(v: bool) -> void:
	_body.visible = v
	_eye_light.visible = v
	Hitboxes.set_active(hitboxes, v and not dead)


func tick(delta: float, ctx: Dictionary) -> void:
	if done:
		return
	delta = clampf(delta, 0.0, 0.1)
	_clock += delta
	if dead:
		_dead_step(delta)
	else:
		_think(delta, ctx)
		_steer(delta)
		_hands_step(delta)
	_body_step(delta)
	_pose(delta)
	_wake()
	if leaving:
		_fade = move_toward(_fade, 0.0, delta * 0.8)
		_body.scale = Vector3.ONE * _k * maxf(_fade, 0.001)
		_eye_light.light_energy *= _fade
		if _fade <= 0.0:
			done = true
			finished.emit(self)


## Shot: it flares and turns on you (Creature.hurt sets `angry`, since it
## bites); killed, it slumps (_dead_step).
func hurt(amount: float, from_pos: Vector3) -> void:
	super.hurt(amount, from_pos)
	if dead:
		Hitboxes.set_active(hitboxes, false)
		return
	_eye_flash = 1.0
	var away := _to_g(_body_l) - from_pos
	_vel += away.normalized() * 0.6
	_set_mode("lurch")


# --- Thinking ----------------------------------------------------------------------

## Change what it's doing: a new goal, so an old dead end is forgotten.
func _set_mode(m: String) -> void:
	if m != mode:
		mode = m
		_blocked = false
		_retry_t = 0.0


func _think(delta: float, ctx: Dictionary) -> void:
	var pp := _player_pos()
	var body := _to_g(_body_l)
	var to_player := INF if pp == Vector3.INF else _flat(pp - body).length()
	var noise: float = ctx.get("player_noise", 0.4)
	var notice := float(rig.notice_m) * (0.45 + 1.1 * noise)
	_strike_cd -= delta
	if angry > 0.0:
		angry -= delta
	var hunting := angry > 0.0 and to_player < 70.0
	if mode == "lurch":
		_lost_t = 0.0 if hunting or to_player < notice * 1.8 else _lost_t + delta
		if _lost_t > 5.0:
			_set_mode("return")
			_goal_l = _home_l
	elif to_player < notice or hunting:
		_set_mode("lurch")
		_lost_t = 0.0
		_eye_flash = maxf(_eye_flash, 0.6)
	_in_reach = mode == "lurch" and to_player < float(rig.strike_m) * _k
	match mode:
		"lurch":
			# Up to arm's length from the player (the hands reach them).
			_goal_l = _to_l(_wadeable_toward(body, pp, 1.5 * _k))
			if _in_reach and _strike_cd <= 0.0:
				_strike(pp)
		"wait":
			_goal_l = _body_l
			_drift_t -= delta
			if _drift_t <= 0.0:
				_drift_t = _rand_range(rig.drift_every_s)
				var g := _wadeable_near(_to_g(_home_l), 3.5)
				if g != Vector3.INF:
					_goal_l = _to_l(g)
					_set_mode("drift")
		"drift", "return":
			# There, or no way on (the water ends first): it waits here.
			if _blocked or _flat(_to_g(_goal_l) - body).length() < 0.4:
				_set_mode("wait")
				_goal_l = _body_l


## Turn toward where it's going (toward the player when lurching), slowly
## unless it's hunting.
func _steer(delta: float) -> void:
	var body := _to_g(_body_l)
	var up: Vector3 = world.dir_of(body)
	var target := _to_g(_goal_l)
	if mode == "lurch" and _player_pos() != Vector3.INF:
		target = _player_pos()
	var v := _flat_at(target - body, up)
	heading = _flat_at(heading, up).normalized()
	if v.length() < 0.3:
		return
	var ang := heading.signed_angle_to(v.normalized(), up)
	var rate := 1.6 if mode == "lurch" else 0.4
	heading = heading.rotated(up, clampf(ang, -rate * delta, rate * delta)).normalized()


# --- Hands -------------------------------------------------------------------------

func _hands_step(delta: float) -> void:
	for h in _hands:
		if h.swinging:
			_swing(h, delta)
	# The player within reach and a strike ready: no new steps, so the next
	# hand to come down stays down to strike with (_think). Lurching, the
	# next hand lifts as the last one lands, and none would ever be free.
	if _in_reach and _strike_cd <= 0.0:
		return
	var lurch := mode == "lurch"
	var overlap := float(rig.lurch_overlap)
	var free := true
	for h in _hands:
		if h.swinging and (not lurch or h.t < overlap):
			free = false
	if not free:
		return
	# A hand planted on the bank (a strike) goes straight back to water.
	for h in _hands:
		if not h.swinging and not h.wet and _step(h, 0.0, float(rig.lurch_step_s), float(rig.lurch_lift_m)):
			return
	var body := _to_g(_body_l)
	_retry_t -= delta
	_settle_t -= delta
	var moving := mode in ["lurch", "drift", "return"] and _flat(_to_g(_goal_l) - body).length() > 0.35
	if moving and _retry_t <= 0.0:
		# The hand lagging furthest behind steps first; if it can't get any
		# further, the other one tries.
		var busy := false
		for h in _by_lag():
			if h.swinging:
				busy = true
			elif lurch:
				# Stride from the species' speed: each hand covers a stride
				# per swing, so the body keeps pace at speed_mps.
				var stride := minf(species.speed_mps * float(rig.lurch_step_s) / _k, 1.6)
				if _step(h, stride, float(rig.lurch_step_s), float(rig.lurch_lift_m)):
					_blocked = false
					return
			elif _step(h, float(rig.stride_m), float(rig.wait_step_s), float(rig.lift_m)):
				_blocked = false
				return
		if busy:
			return
		# Neither hand gets any further (the water ends ahead): it stops
		# there, settles (below) and looks for a way on again in a moment.
		# A drift or a return ends here (_think).
		_blocked = true
		_retry_t = 0.5
	elif moving and not _blocked:
		return
	# Still: a hand far out of place (it turned, or the body settled) goes
	# back where it rests, if there's a better spot for it.
	var target := _body_target(body, false)
	var worst: Hand = null
	var worst_off := 0.45 * _k
	for h in _hands:
		var off := _flat(_to_g(h.plant) - _neutral(h.sd, target)).length()
		if not h.swinging and off > worst_off:
			worst = h
			worst_off = off
	if worst and _settle_t <= 0.0:
		if _step(worst, 0.0, float(rig.wait_step_s) * (0.5 if lurch else 1.0), float(rig.lift_m)):
			return
		_settle_t = 0.5
	_replant_t -= delta
	if _replant_t <= 0.0:
		# Now and then one hand lifts and re-plants, a handspan off.
		_replant_t = _rand_range(rig.replant_every_s)
		_step(_hands[_rng.randi() % 2], 0.12, float(rig.wait_step_s), float(rig.lift_m), true)


## The hands in the order they step: the one lagging furthest behind
## (along the heading) first.
func _by_lag() -> Array[Hand]:
	var body := _to_g(_body_l)
	var out: Array[Hand] = _hands.duplicate()
	out.sort_custom(func(a: Hand, b: Hand) -> bool:
		return (_to_g(a.plant) - body).dot(heading) < (_to_g(b.plant) - body).dot(heading))
	return out


## Start a step: lift `h` and swing it `stride` m ahead of where it rests,
## over `dur` s, clearing the water by `lift` m. False (and the hand
## stays put) if there's nowhere for it, or nowhere better than where it
## is (a `jitter` re-plant always goes).
func _step(h: Hand, stride: float, dur: float, lift: float, jitter := false) -> bool:
	# Measured from where the hands are pulling the body, not from where
	# it lags behind (else every stride comes up short).
	var body := _body_target(_to_g(_body_l), false, true)
	var ahead := stride
	if stride > 0.0:
		# Don't reach past where it's going (the body follows half a stride).
		ahead = minf(stride * _k, 2.0 * _flat(_to_g(_goal_l) - body).length())
	var spot := _find_plant(h, body, ahead * 0.75, 1.0 if not jitter else 0.0)
	if jitter and spot != Vector3.INF:
		var up: Vector3 = world.dir_of(spot)
		var side := heading.cross(up)
		var j := spot + side * _rng.randf_range(-stride, stride) * _k + heading * _rng.randf_range(-stride, stride) * _k
		if _wadeable(j, _wade.x):
			spot = _floor_point(j)
	if spot == Vector3.INF:
		# Nowhere to put it (the water ends): stay put.
		return false
	if not jitter and _flat(spot - _to_g(h.plant)).length() < MIN_STEP * _k:
		# Nowhere better (at the water's edge the best spot ahead is where
		# the hand already is): stay put rather than paw in place.
		return false
	h.from = h.plant
	h.to = _to_l(spot)
	h.from_fwd = h.fwd
	h.to_fwd = _plant_fwd(h.sd)
	h.t = 0.0
	h.dur = maxf(dur, 0.2)
	h.lift = lift * _k
	h.swinging = true
	h.strike = false
	h.above = -1.0
	return true


## Rear up and slam a hand down where the player stands.
func _strike(pp: Vector3) -> void:
	var body := _to_g(_body_l)
	var up: Vector3 = world.dir_of(body)
	var side := heading.cross(up)
	var sd := 1.0 if (pp - body).dot(side) > 0.0 else -1.0
	var h: Hand = _hands[0] if sd < 0.0 else _hands[1]
	if h.swinging:
		h = _hands[1] if sd < 0.0 else _hands[0]
		if h.swinging:
			return
	_strike_cd = 1.7
	var spot := _floor_point(pp)
	# Within the arm's reach.
	var sh := _shoulder_g(h.sd)
	var reach := (float(_rest[h.sd].l1) + float(_rest[h.sd].l2)) * _k * 0.95
	if spot.distance_to(sh) > reach:
		spot = _floor_point(sh + (spot - sh).normalized() * reach)
	h.from = h.plant
	h.to = _to_l(spot)
	h.from_fwd = h.fwd
	h.to_fwd = _flat_at(pp - body, up).normalized()
	h.t = 0.0
	h.dur = STRIKE_S
	h.lift = STRIKE_LIFT * _k
	h.swinging = true
	h.strike = true
	h.above = -1.0


## Advance a swing: up out of the water, over, and down. Breaking the
## surface on the way down is the plant's ripple and sound.
func _swing(h: Hand, delta: float) -> void:
	var prev := _to_g(h.pos)
	h.t = minf(h.t + delta / h.dur, 1.0)
	var a := _to_g(h.from)
	var b := _to_g(h.to)
	var base := a.lerp(b, smoothstep(0.12, 0.88, h.t))
	var up: Vector3 = world.dir_of(base)
	var probe := _probe(base)
	var clear := maxf(probe.y - probe.x, 0.0) + h.lift
	var p := base + up * clear * pow(sin(PI * h.t), 0.7)
	h.pos = _to_l(p)
	h.fwd = h.from_fwd.slerp(h.to_fwd, smoothstep(0.2, 0.9, h.t)) if h.from_fwd.dot(h.to_fwd) > -0.99 else h.to_fwd
	var at := _probe(p)
	var above: float = world.radius_of(p) - PlanetConst.RADIUS_M - at.y
	if h.above > 0.0 and above <= 0.0 and h.t > 0.5 and at.y > at.x + 0.01:
		var speed := p.distance_to(prev) / maxf(delta, 1e-4)
		_splash(h, world.to_scene(world.dir_of(p), PlanetConst.RADIUS_M + at.y), speed)
	h.above = above
	if h.t >= 1.0:
		h.swinging = false
		h.plant = h.to
		h.pos = h.plant
		h.fwd = h.to_fwd
		h.wet = _wadeable(b, _wade.x)
		if h.strike:
			h.strike = false
			var pp := _player_pos()
			if pp != Vector3.INF and _flat(pp - b).length() < 1.1 * _k and absf(world.radius_of(pp) - world.radius_of(b)) < 2.2:
				spawner.player_hit(species.bite, b)


func _splash(h: Hand, pos: Vector3, speed: float) -> void:
	var kg := float(rig.hand_kg) * _k * _k * _k
	Ripples.splash(pos, kg, speed)
	_count("splash", kg, speed)
	last_splashes.append([_clock, pos, kg, speed])
	if last_splashes.size() > 64:
		last_splashes.pop_front()
	h.voice.stream = plant_sound(_rng.randi())
	h.voice.global_position = pos
	h.voice.volume_db = lerpf(-14.0, -3.0, clampf(speed / 5.0, 0.0, 1.0))
	h.voice.pitch_scale = _rng.randf_range(0.85, 1.1) / pow(_k, 0.3)
	h.voice.play()


func _count(kind: String, kg: float, speed: float) -> void:
	ripple_stats[kind] += 1
	var mk: Vector2 = ripple_stats[kind + "_kg"]
	var ms: Vector2 = ripple_stats[kind + "_mps"]
	ripple_stats[kind + "_kg"] = Vector2(minf(mk.x, kg), maxf(mk.y, kg))
	ripple_stats[kind + "_mps"] = Vector2(minf(ms.x, speed), maxf(ms.y, speed))


## The body's drift: a wake at its waterline, every frame it's in water.
func _wake() -> void:
	var body := _to_g(_body_l)
	var at := _probe(body)
	var bottom: float = world.radius_of(body) - PlanetConst.RADIUS_M - 0.4 * _k
	if at.y <= at.x + 0.01 or bottom > at.y:
		return
	var up: Vector3 = world.dir_of(body)
	var speed := _flat_at(_vel, up).length()
	var kg := float(rig.body_kg) * _k * _k * _k
	var key := get_instance_id() * 8
	var pos: Vector3 = world.to_scene(up, PlanetConst.RADIUS_M + at.y)
	Ripples.wake(key, pos, kg, speed)
	_count("wake", kg, speed)
	last_wake = [_clock, key, pos, kg, speed]


# --- Body --------------------------------------------------------------------------

## Where the planted hands hold the body: behind their middle, leaning onto
## the supporting hand while the other is up, at wading height (or
## `settle`: just the height at `at`). A swinging hand pulls it along as
## it reaches; `plan` counts it where it will land (for planning steps).
func _body_target(at: Vector3, settle: bool, plan := false) -> Vector3:
	var c := at
	if not settle:
		var sum := Vector3.ZERO
		var n := 0.0
		var lean := 0.0
		for h in _hands:
			if not h.wet and not h.swinging:
				continue
			var p := _to_g(h.plant)
			if h.swinging and plan:
				p = _to_g(h.to)
			elif h.swinging:
				p = _to_g(h.from).lerp(_to_g(h.to), smoothstep(0.25, 1.0, h.t))
				lean -= h.sd * sin(PI * h.t)
			sum += p
			n += 1.0
		if n > 0.0:
			var up0: Vector3 = world.dir_of(at)
			var mid := sum / n
			c = mid - _flat_at(heading, up0).normalized() * _ahead()
			c += heading.cross(up0).normalized() * lean * 0.09 * _k
			# Stay over wadeable water: slide back toward the hands if the
			# spot behind them is dry.
			if not _wadeable(c, _wade.x + 0.05):
				var alt := mid - _flat_at(heading, up0).normalized() * _ahead() * 0.4
				c = alt if _wadeable(alt, _wade.x + 0.05) else at
	var up: Vector3 = world.dir_of(c)
	var probe := _probe(c)
	var h := maxf(probe.x + RIDE * _k, probe.y + LIFT * _k)
	if dead:
		h = probe.x + 0.12 * _k
	# Breathing.
	h += sin(_clock * 0.8) * 0.012 * _k
	return world.to_scene(up, PlanetConst.RADIUS_M + h)


## The body follows its target through a loose spring (it sways), and
## tilts with its acceleration, leaning onto the planted arm.
func _body_step(delta: float) -> void:
	var pos := _to_g(_body_l)
	var target := _body_target(pos, false)
	var w := 5.0 if mode == "lurch" else 3.2
	var z := 0.42
	var acc := (target - pos) * w * w - _vel * 2.0 * z * w
	_vel += acc * delta
	var next := pos + _vel * delta
	var up: Vector3 = world.dir_of(pos)
	# Never out of the water: sideways motion onto dry ground is dropped.
	if not dead and not _wadeable(next, _wade.x * 0.5):
		var flat := _flat_at(_vel, up)
		_vel -= flat
		next = pos + _vel * delta
	_body_l = _to_l(next)
	_acc = acc
	var fwd := _flat_at(heading, up).normalized()
	var side := fwd.cross(up)
	var lean := 0.0
	for h in _hands:
		if h.swinging:
			lean -= h.sd * sin(PI * h.t)
	# Leaning into its pull, and onto the planted arm while the other is up.
	var roll_t := clampf(-acc.dot(side) * 0.03, -0.25, 0.25) - lean * 0.07
	var pitch_t := clampf(-acc.dot(fwd) * 0.025, -0.2, 0.2) + sin(_clock * 0.8 + 0.6) * 0.02
	if dead:
		pitch_t = -0.35
		roll_t = 0.2
	# Angular springs: a little wobble.
	var aw := 6.0
	_roll_v += ((roll_t - _roll) * aw * aw - _roll_v * 2.0 * 0.3 * aw) * delta
	_pitch_v += ((pitch_t - _pitch) * aw * aw - _pitch_v * 2.0 * 0.3 * aw) * delta
	_roll += _roll_v * delta
	_pitch += _pitch_v * delta


func _dead_step(delta: float) -> void:
	_dead_t += delta
	_dead_eye = move_toward(_dead_eye, 0.0, delta * 0.7)
	for h in _hands:
		if h.swinging:
			_swing(h, delta)
	if _dead_t > 14.0 and not leaving:
		leave()


# --- Pose --------------------------------------------------------------------------

## Place the body, bend the arms to the hands, open or narrow the eye.
func _pose(delta: float) -> void:
	var pos := _to_g(_body_l)
	var up: Vector3 = world.dir_of(pos)
	var fwd := _flat_at(heading, up).normalized()
	var basis := Basis.looking_at(fwd, up) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, _roll)
	global_transform = Transform3D(basis, pos)
	dir = up
	var inv := _skel.global_transform.affine_inverse()
	var up_sk := (inv.basis * up).normalized()
	for h in _hands:
		_reach(h, inv, up_sk)
	_eye_step(delta)


## Two-bone IK: shoulder and elbow bend so the wrist lands where the palm
## goes; the elbow keeps high and outward (the rest pose's bend). A planted
## hand lies flat along its fingers' direction; a lifted one hangs from the
## forearm, fingers curled.
func _reach(h: Hand, inv: Transform3D, up_sk: Vector3) -> void:
	var r: Dictionary = _rest[h.sd]
	var n := PondCrawlerBody.side_name(h.sd)
	# The palm's center sits its own thickness over the floor point.
	var palm := inv * _to_g(h.pos) + up_sk * (PondCrawlerBody.PALM.y - PondCrawlerBody.FLOOR_Y)
	var fwd_sk := inv.basis * h.fwd
	fwd_sk = (fwd_sk - up_sk * fwd_sk.dot(up_sk))
	if fwd_sk.length_squared() < 1e-6:
		fwd_sk = Vector3.FORWARD
	var rw_plant := _frame(fwd_sk.normalized(), up_sk) * (r.hand as Basis).transposed()
	var s0: Vector3 = r.s
	var e0: Vector3 = r.e
	var w0: Vector3 = r.w
	var p0: Vector3 = r.palm
	var target := palm - rw_plant * (p0 - w0)
	var l1: float = r.l1
	var l2: float = r.l2
	var d := target - s0
	var dist := d.length()
	var dn := d / maxf(dist, 1e-6)
	dist = clampf(dist, absf(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var hh := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pole: Vector3 = (r.pole as Vector3) + up_sk * 0.25
	var pp := pole - dn * pole.dot(dn)
	if pp.length_squared() < 1e-8:
		pp = up_sk - dn * up_sk.dot(dn)
	var e := s0 + dn * a + pp.normalized() * hh
	var w := s0 + dn * dist
	var nrm := (e - s0).cross(w - e)
	if nrm.length_squared() < 1e-10:
		nrm = r.n0
	nrm = nrm.normalized()
	var n0: Vector3 = r.n0
	var rs := _frame2(e - s0, nrm) * _frame2(e0 - s0, n0).transposed()
	var re := _frame2(w - e, nrm) * _frame2(w0 - e0, n0).transposed()
	var lift := sin(PI * h.t) if h.swinging else 0.0
	var rw := Quaternion(rw_plant.orthonormalized()).slerp(Quaternion(re.orthonormalized()), clampf(lift * 1.3, 0.0, 1.0))
	_skel.set_bone_pose_rotation(_bones["Shoulder" + n], Quaternion(rs.orthonormalized()))
	_skel.set_bone_pose_rotation(_bones["Elbow" + n], Quaternion((rs.transposed() * re).orthonormalized()))
	_skel.set_bone_pose_rotation(_bones["Wrist" + n], (Quaternion(re.orthonormalized()).inverse() * rw).normalized())
	# Fingers: flat and splayed when planted, curled when lifted, spread
	# wide as a strike comes down; limp when dead.
	var curl := lift * 0.7
	if h.strike and h.t > 0.5:
		curl = -0.25
	if dead:
		curl = 0.5 * (1.0 - _dead_eye)
	for j in PondCrawlerBody.FINGERS.size():
		var axis := Vector3.UP.cross(PondCrawlerBody.finger_dir(h.sd, j)).normalized()
		var c := curl * (0.6 if j == 0 else 1.0)
		_skel.set_bone_pose_rotation(_bones["Finger%s%d" % [n, j]], Quaternion(axis, c))


## The slit eye: narrow while it waits (with a slow blink now and then),
## wide when it lurches, flaring when hit; its light follows.
func _eye_step(delta: float) -> void:
	var want := 0.6 + 0.08 * sin(_clock * 0.37)
	match mode:
		"lurch":
			want = 1.05
		"drift", "return":
			want = 0.6
	_blink_t -= delta
	if _blink_t <= 0.0:
		if _blink_t < -0.16:
			_blink_t = _rng.randf_range(4.0, 11.0)
		elif mode == "wait" or mode == "drift":
			want = 0.06
	_eye_flash = maxf(_eye_flash - delta * 1.5, 0.0)
	want += _eye_flash * 0.5
	_eye_open = lerpf(_eye_open, want, clampf(delta * (14.0 if want < _eye_open else 5.0), 0.0, 1.0))
	var open := _eye_open * _dead_eye
	for mi in _meshes:
		PondCrawlerBody.set_eye(mi, open, _dead_eye)
	_eye_light.light_energy = float(rig.eye_light_energy) * clampf(0.3 + 0.7 * open, 0.0, 1.6) * _dead_eye


# --- Where things are ----------------------------------------------------------------

func _to_g(l: Vector3) -> Vector3:
	return (get_parent() as Node3D).global_transform * l


func _to_l(g: Vector3) -> Vector3:
	return (get_parent() as Node3D).global_transform.affine_inverse() * g


func _player_pos() -> Vector3:
	if spawner == null or spawner.get("player") == null:
		return Vector3.INF
	var p: Node3D = spawner.player
	return p.global_position


## Ground and water height (m above the planet's radius) under a scene
## point: Vector2(ground, water).
func _probe(g: Vector3) -> Vector2:
	var d: Vector3 = world.dir_of(g)
	return Vector2(chunks.ground_height(d), chunks.water_level_at(d))


## The floor (ground, under any water) under a scene point.
func _floor_point(g: Vector3) -> Vector3:
	var d: Vector3 = world.dir_of(g)
	return world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))


## Water `min_depth` to wade_m deep over the spot, in its biome lock.
func _wadeable(g: Vector3, min_depth: float) -> bool:
	var d: Vector3 = world.dir_of(g)
	var depth := chunks.water_level_at(d) - chunks.ground_height(d)
	if depth < min_depth or depth > _wade.y:
		return false
	if lock_biome and not species.biome_lock.is_empty():
		var map: PlanetData = world.planet
		return species.biome_ok(map.biome[map.cell_at(d)])
	return true


## `v` flattened onto the tangent plane at `up`.
func _flat_at(v: Vector3, up: Vector3) -> Vector3:
	return v - up * v.dot(up)


func _flat(v: Vector3) -> Vector3:
	return _flat_at(v, dir)


## How far ahead of the body the hands rest.
func _ahead() -> float:
	return -PondCrawlerBody.PALM.z * _k


## A hand's resting spot (its palm, not yet on the floor) for a body at
## `body`.
func _neutral(sd: float, body: Vector3) -> Vector3:
	var up: Vector3 = world.dir_of(body)
	var fwd := _flat_at(heading, up).normalized()
	var side := fwd.cross(up)
	return body + fwd * _ahead() + side * sd * absf(PondCrawlerBody.PALM.x) * _k


## Which way a hand planted now points its fingers (scene space).
func _plant_fwd(sd: float) -> Vector3:
	var up := dir
	var fwd := _flat_at(heading, up).normalized()
	var hf := PondCrawlerBody.hand_fwd(sd)
	return fwd.rotated(up, atan2(-hf.x, -hf.z)).normalized()


## Where to put hand `h` next: its resting spot `ahead` m further on,
## else the nearest wadeable spot to it within the arm's reach (turning a
## little, then shortening). Vector3.INF if there's none.
func _find_plant(h: Hand, body: Vector3, ahead: float, spread: float) -> Vector3:
	var up: Vector3 = world.dir_of(body)
	var fwd := _flat_at(heading, up).normalized()
	var reach := (float(_rest[h.sd].l1) + float(_rest[h.sd].l2)) * _k * 0.93
	for scale: float in [1.0, 0.6, 0.3, 0.0]:
		for turn: float in [0.0, 0.3 * spread, -0.3 * spread, 0.6 * spread, -0.6 * spread]:
			var future := body + fwd.rotated(up, turn) * ahead * scale * 0.67
			var spot := _neutral(h.sd, body) + fwd * ahead * scale
			if turn != 0.0:
				spot = body + (spot - body).rotated(up, turn)
			if not _wadeable(spot, _wade.x):
				continue
			var fl := _floor_point(spot)
			if fl.distance_to(_shoulder_g(h.sd, future)) <= reach:
				return fl
	return Vector3.INF


## A shoulder's scene position (for a body at `body`, default where it is).
func _shoulder_g(sd: float, body := Vector3.INF) -> Vector3:
	var s0: Vector3 = _rest[sd].s
	if body == Vector3.INF:
		return _skel.global_transform * s0
	var up: Vector3 = world.dir_of(body)
	var fwd := _flat_at(heading, up).normalized()
	return body + (fwd.cross(up) * s0.x + up * s0.y - fwd * s0.z) * _k


## The wadeable spot closest to `to` (stopping `short` m before it) on
## the way there from `from`.
func _wadeable_toward(from: Vector3, to: Vector3, short := 0.0) -> Vector3:
	if to == Vector3.INF:
		return from
	var best := from
	var span := from.distance_to(to)
	if span <= short:
		return from
	var end := from.lerp(to, (span - short) / span)
	var n := int(ceil((span - short) / 0.5))
	for i in range(1, n + 1):
		var p := from.lerp(end, float(i) / n)
		if not _wadeable(p, _wade.x + 0.05):
			break
		best = p
	return best


## A random wadeable spot within `radius` m of `center`, or INF.
func _wadeable_near(center: Vector3, radius: float) -> Vector3:
	var up: Vector3 = world.dir_of(center)
	var north := CubeSphere.north(up)
	for i in 12:
		var off := north.rotated(up, _rng.randf() * TAU) * sqrt(_rng.randf()) * radius * _k
		var p := center + off
		if _wadeable(p, _wade.x + 0.1):
			return p
	return Vector3.INF


func _rand_range(v) -> float:
	var a: Array = v
	return _rng.randf_range(float(a[0]), float(a[1]))


## An orthonormal basis looking along `fwd` (-Z) with `up` (+Y).
static func _frame(fwd: Vector3, up: Vector3) -> Basis:
	var z := -fwd.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


## An orthonormal basis with X along `v` and Y along `n` (made square to it).
static func _frame2(v: Vector3, n: Vector3) -> Basis:
	var x := v.normalized()
	var y := (n - x * n.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


# --- Sound ------------------------------------------------------------------------

const PLANT_VARIANTS := 6
static var _plant_sounds := {}


## A soft wet plant: a low slap into the water, a swash of filtered noise
## dying away, and a few bubbles (SoundSynth's style: synthesized, no
## files). Seeded variants so no two plants sound quite alike.
static func plant_sound(variant: int) -> AudioStreamWAV:
	var v := posmod(variant, PLANT_VARIANTS)
	if _plant_sounds.has(v):
		return _plant_sounds[v]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pond_crawler_plant_%d" % v)
	var rate := SoundSynth.RATE
	var s := PackedFloat32Array()
	s.resize(int(rng.randf_range(0.45, 0.6) * rate))
	var f0 := rng.randf_range(80.0, 115.0)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var bubbles: Array = []
	for b in rng.randi_range(2, 4):
		bubbles.append([rng.randf_range(0.03, 0.22), rng.randf_range(260.0, 480.0), rng.randf_range(1.4, 2.2), rng.randf_range(0.05, 0.1), rng.randf_range(0.2, 0.4)])
	for i in s.size():
		var t := float(i) / rate
		phase += TAU * f0 * (1.0 - 0.4 * minf(t / 0.15, 1.0)) / rate
		var slap := sin(phase) * exp(-t * 18.0) * minf(t / 0.006, 1.0)
		var x := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, x, 0.14)
		lp2 = lerpf(lp2, lp, 0.35)
		var swash := lp2 * 2.2 * exp(-t * 8.0) * minf(t / 0.015, 1.0)
		var bub := 0.0
		for bb in bubbles:
			var bt: float = t - bb[0]
			if bt > 0.0 and bt < bb[3]:
				# A rising chirp: phase of a linear sweep.
				var fa: float = bb[1]
				var fb: float = fa * bb[2]
				var ph: float = TAU * (fa * bt + (fb - fa) * bt * bt / (2.0 * bb[3]))
				bub += sin(ph) * exp(-bt * 28.0) * bb[4] * minf(bt / 0.004, 1.0)
		s[i] = slap * 0.8 + swash + bub
	var wav := SoundSynth._to_wav(s)
	_plant_sounds[v] = wav
	return wav


# --- Placing one (debug; it never spawns on its own before Phase 7) ------------------

## A Pond Crawler waiting in the water at surface direction `d` (which
## should be wadeable swamp or bog water, with its chunks loaded: see
## find_pool()), handed to `spawner` to tick and to be shot at. For tools
## and debugging: data/creatures/README.md. Dev mode's F7 (DevSpawn)
## calls this in its turn, in the nearest water it can wade.
## `lock` false lets it wade outside its biome lock (for a tool that had to
## settle for other wetland water); `facing` turns it that way (else it
## faces a random way).
static func debug_spawn(spawner: CreatureSpawner, d: Vector3, seed_value := 1, lock := true, facing := Vector3.ZERO) -> PondCrawler:
	var sp := CreatureSpecies.find("Pond Crawler")
	if sp == null:
		push_warning("PondCrawler: no \"Pond Crawler\" in creatures.json")
		return null
	var cr := PondCrawler.new()
	cr.lock_biome = lock
	cr.facing = facing
	spawner.adopt(cr)
	cr.setup(sp, spawner.world, spawner.chunks, spawner, d, seed_value)
	return cr


## Blueprint cells of the species' biome lock (else any wetland), nearest
## first, within `max_m` of `near`: [[cell, meters], ...].
static func wetland_cells(map: PlanetData, near: Vector3, max_m: float, biomes: PackedInt32Array) -> Array:
	var out: Array = []
	for c in map.cell_count:
		if map.biome[c] in biomes and map.water[c] == PlanetData.Water.NONE:
			var m := CubeSphere.surface_distance_m(near, map.dir[c])
			if m < max_m:
				out.append([c, m])
	out.sort_custom(func(x, y): return x[1] < y[1])
	return out


## The best spot to put a crawler within `radius_m` of `near` (a surface
## direction), in the loaded chunks: water it can wade (`wade` depth
## range, about knee-deep preferred) with open water around it.
## Vector3.ZERO if there's none.
static func find_pool(chunks: ChunkManager, near: Vector3, radius_m: float, wade: Vector2, step_m := 2.0) -> Vector3:
	var north := CubeSphere.north(near)
	var east := CubeSphere.east(near)
	var best := Vector3.ZERO
	var best_score := -INF
	var n := int(radius_m / step_m)
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			var off := Vector2(i, j) * step_m
			if off.length() > radius_m:
				continue
			var d := (near + (east * off.x + north * off.y) / PlanetConst.RADIUS_M).normalized()
			if chunks.chunk_at(d) == null:
				continue
			var depth := chunks.water_level_at(d) - chunks.ground_height(d)
			if depth < maxf(wade.x, 0.3) or depth > wade.y:
				continue
			# Open water around it: how far each of 12 bearings stays wadeable.
			var open := INF
			for k in 12:
				var bearing := north.rotated(d, k * TAU / 12.0)
				var run := 0.0
				while run < 12.0:
					var q := (d + bearing * (run + 1.0) / PlanetConst.RADIUS_M).normalized()
					var dq := chunks.water_level_at(q) - chunks.ground_height(q)
					if dq < wade.x or dq > wade.y:
						break
					run += 1.0
				open = minf(open, run)
			# Knee-deep water is best: most of it shows, and every hand
			# plant breaks the surface.
			var score := minf(open, 8.0) - absf(depth - 0.5) * 6.0 - off.length() * 0.01
			if score > best_score:
				best_score = score
				best = d
	return best

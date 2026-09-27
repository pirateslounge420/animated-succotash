class_name NightRiderPair
extends RefCounted
## Night Riders go as a pair (the species' herd_min / herd_max, 2): a
## leader, and a follower riding in its tracks `trail_body_lengths` behind
## (nose to nose), its gait `phase_offset` of a cycle out of step with the
## leader's, so the two sets of hoofbeats never fall together (all in the
## species' "pair" entry). Each rider (NightRider) does its own heavy
## movement and gait; this steers them.
##
## The leader:
##   patrol  wanders at a walk: a waypoint 40-80 m ahead, never more than
##           about 50 degrees off its heading (no sharp turns), within
##           territory_m of home, on dry ground, in its biome_lock (when
##           home is in it); tree trunks ahead are steered round early
##           (the turning circle is wide)
##   route   walks the given waypoints in order (demos; the dev spawn's
##           first pass), then patrols; water too deep to wade on the way
##           ends the route early (a patrol then picks a dry waypoint,
##           any way round)
##   hunt    rides at you: at night once you're within notice_m (farther
##           when you're loud), or once either is shot (Creature.hurt makes
##           it angry). Still only a walk. In reach (reach_m) it stops and
##           strikes every strike_s (CreatureSpawner.player_hit, the
##           species' bite; no balancing here). Past give_up_m it turns
##           back to patrolling.
## The follower steers for a point just ahead of the one on the leader's
## track a gap behind it, and eases its speed to hold the gap. If the
## leader dies the follower leads.
##
## Tuning: "pair" {trail_body_lengths, phase_offset}, "hunt" {notice_m,
## give_up_m, reach_m, strike_s}, territory_m.

signal finished(pair: NightRiderPair)

## The leader's track is kept as points this far apart.
const TRACK_STEP_M := 0.2

var species: CreatureSpecies
var world: Node
var chunks: ChunkManager
var spawner: Node
var riders: Array[NightRider] = []
var state := "patrol"
## Waypoints (surface directions) for "route".
var route: Array = []
var home := Vector3.UP
## False: never hunts (demos).
var aggressive := true
var done := false
## Center to center, leader to follower (m).
var gap_m := 5.1
var phase_offset := 0.4

var _track: Array = [] # the leader's track: [dir, meters it had walked]
var _leader: NightRider
var _waypoint := Vector3.ZERO
var _waypoint_t := 0.0
var _avoid_bias := 0.0
var _avoid_hold := 0.0
var _avoid_t := 0.0
var _strike_cd := 0.0
var _hunt := {}
var _rng := RandomNumberGenerator.new()


## A pair at surface direction `d` (the leader), riding along `heading`;
## the follower is placed on the line behind. `walking` > 0: already
## walking at that speed (m/s).
static func spawn(sp: CreatureSpecies, p_world: Node, p_chunks: ChunkManager, p_spawner: Node, parent: Node3D, d: Vector3, heading: Vector3, seed_value: int, walking := 0.0) -> NightRiderPair:
	var pair := NightRiderPair.new()
	pair.species = sp
	pair.world = p_world
	pair.chunks = p_chunks
	pair.spawner = p_spawner
	pair.home = d
	pair._rng.seed = seed_value
	pair._hunt = sp.data.get("hunt", {})
	var pr: Dictionary = sp.data.get("pair", {})
	pair.phase_offset = float(pr.get("phase_offset", 0.4))
	pair.gap_m = float(pr.get("trail_body_lengths", 2.0)) * 2.55 * sp.size_m / NightRiderBody.REF_HEIGHT
	var t := (heading - d * heading.dot(d)).normalized()
	var count := clampi(sp.herd.y, 1, 4)
	for i in count:
		var at := (d - t * pair.gap_m * i / PlanetConst.RADIUS_M).normalized()
		var r := NightRider.new()
		parent.add_child(r)
		r.setup(sp, p_world, p_chunks, p_spawner, at, seed_value + i * 7919)
		r.heading = (t - at * t.dot(at)).normalized()
		r.phase = fposmod(pair.phase_offset * i, 1.0)
		if walking > 0.0:
			r.set_walking(walking)
		r.place_now()
		r.finished.connect(pair._on_finished)
		r.hurt_by_player.connect(pair._on_hurt)
		pair.riders.append(r)
	pair._restart_track()
	return pair


## The dev spawn, callable from code (the dev F7 key, tools): a pair
## riding across the view of someone at surface direction `from` looking
## along `facing` (any vector; its level part counts). It appears about
## 30 m ahead and 22 m to one side, already walking, rides across and on,
## then patrols (at night it comes for you unless `aggressive` is false).
## The line is picked dry where it can be (nearer or farther, from either
## side). `mythics` owns it and ticks it. Null if the data has no "Night
## rider". The first one waits for the body mesh if it isn't built yet
## (about 4 s; in dev mode Mythics builds it at startup).
static func debug_spawn(mythics: Mythics, from: Vector3, facing: Vector3, aggressive := true) -> NightRiderPair:
	var sp := CreatureSpecies.find("Night rider")
	if sp == null:
		return null
	var fwd := facing - from * facing.dot(from)
	fwd = fwd.normalized() if fwd.length_squared() > 1e-8 else CubeSphere.north(from)
	var right := fwd.cross(from).normalized()
	var r := PlanetConst.RADIUS_M
	var at := func(ahead: float, across: float) -> Vector3:
		return (from + (fwd * ahead + right * across) / r).normalized()
	# Dry (or no more than ankle deep) along the stretch you'll see.
	var dry := func(ahead: float, sgn: float) -> bool:
		for across in range(-22, 31, 8):
			var p: Vector3 = at.call(ahead, across * sgn)
			if mythics.chunks.water_level_at(p) > mythics.chunks.ground_height(p) + 0.3:
				return false
		return true
	var ahead := 30.0
	var sgn := 1.0
	var found := false
	for a: float in [30.0, 20.0, 45.0, 14.0, 60.0]:
		for s: float in [1.0, -1.0]:
			if not found and dry.call(a, s):
				ahead = a
				sgn = s
				found = true
	return mythics.spawn_night_riders(at.call(ahead, -22.0 * sgn), right * sgn, [at.call(ahead, 60.0 * sgn)], sp.speed_mps, aggressive)


## Every rider fades out and is gone (the pair finishes).
func dismiss() -> void:
	for r in riders:
		r.leave()


## Gone at once.
func free_now() -> void:
	for r in riders:
		if is_instance_valid(r):
			r.queue_free()
	riders.clear()
	done = true


## Every living rider fully there at once (no fade-in).
func appear_now() -> void:
	for r in riders:
		r.appear_now()


func tick(delta: float, ctx: Dictionary) -> void:
	if done:
		return
	var leader := _lead()
	if leader == null:
		for r in riders.duplicate():
			r.tick(delta, ctx)
		return
	if leader != _leader:
		_leader = leader
		_restart_track()
	var pd: Vector3 = ctx.player_dir
	_update_state(leader, ctx, delta)
	_steer_leader(leader, pd, delta)
	_record(leader)
	var k := 0
	for r in riders:
		if r == leader or r.dead:
			continue
		k += 1
		_steer_follower(r, leader, k)
	_strikes(pd, delta)
	for r in riders.duplicate():
		r.tick(delta, ctx)


func _lead() -> NightRider:
	for r in riders:
		if is_instance_valid(r) and not r.dead and not r.done:
			return r
	return null


func _update_state(leader: NightRider, ctx: Dictionary, delta: float) -> void:
	var angry := false
	for r in riders:
		r.angry = maxf(r.angry - delta, 0.0)
		angry = angry or (r.angry > 0.0 and not r.dead)
	var dist := leader.distance_to(ctx.player_dir)
	var night := float(ctx.get("daylight", 0.0)) < 0.3
	# Later on a side the leader's been blinded on (Creature.sight_toward()).
	var notice := float(_hunt.get("notice_m", 40.0)) * (0.6 + 0.8 * float(ctx.get("player_noise", 0.4))) * leader.sight_toward(ctx.player_dir)
	if aggressive and (angry or (night and dist < notice)):
		state = "hunt"
	elif state == "hunt" and dist > float(_hunt.get("give_up_m", 90.0)):
		state = "patrol"
		_waypoint = Vector3.ZERO


func _steer_leader(leader: NightRider, pd: Vector3, delta: float) -> void:
	var target := Vector3.ZERO
	var want := leader.walk_mps
	match state:
		"hunt":
			target = pd
			# Rein in early enough to stop at arm's length (it's heavy).
			var stopping := leader.speed * leader.speed / (3.0 * leader.accel_mps2)
			if leader.distance_to(pd) < float(_hunt.get("reach_m", 2.6)) + stopping + 0.2:
				want = 0.0
		"route":
			while not route.is_empty() and leader.distance_to(route[0]) < 6.0:
				route.pop_front()
			# Held up by deep water: give the route up and patrol.
			if leader.blocked_t > 2.0:
				route.clear()
			if route.is_empty():
				state = "patrol"
			else:
				target = route[0]
	if state == "patrol":
		_waypoint_t -= delta
		# Held up by deep water: another waypoint, any way round (not
		# more often than every 20 s: it turns slowly).
		var stuck := leader.blocked_t > 2.0 and _waypoint_t < 70.0
		if _waypoint == Vector3.ZERO or leader.distance_to(_waypoint) < 8.0 or _waypoint_t <= 0.0 or stuck:
			_waypoint = _pick_waypoint(leader, stuck)
			_waypoint_t = 90.0
		target = _waypoint
	leader.want_dir = _avoid(leader, target, delta)
	leader.want_speed = want


## Steer round tree trunks ahead (rays on the trunk layer, a few times a
## second): turn toward the freer side early, the turning circle being
## wide.
func _avoid(leader: NightRider, target: Vector3, delta: float) -> Vector3:
	_avoid_hold -= delta
	_avoid_t -= delta
	if _avoid_t <= 0.0 and leader.is_inside_tree():
		_avoid_t = 0.25
		var space := leader.get_world_3d().direct_space_state
		var up := leader.dir
		var from := leader.global_position + up * 1.0
		var free: Array[float] = []
		for ang: float in [0.0, -0.5, 0.5]:
			var d := leader.heading.rotated(up, ang)
			var q := PhysicsRayQueryParameters3D.create(from, from + d * (11.0 if ang == 0.0 else 7.0), TerrainChunk.TREE_LAYER)
			var hit := space.intersect_ray(q)
			free.append(INF if hit.is_empty() else from.distance_to(hit.position))
		if free[0] < INF:
			_avoid_bias = 0.8 if free[2] >= free[1] else -0.8
			_avoid_hold = 1.2
		elif free[1] < 4.0:
			_avoid_bias = 0.4
			_avoid_hold = 0.6
		elif free[2] < 4.0:
			_avoid_bias = -0.4
			_avoid_hold = 0.6
	if _avoid_hold <= 0.0 or target == Vector3.ZERO:
		return target
	var t := leader._tangent_to(target).rotated(leader.dir, _avoid_bias)
	return (leader.dir + t * 20.0 / PlanetConst.RADIUS_M).normalized()


## The next patrol waypoint: ahead-ish (`anywhere`: any bearing), in the
## territory, dry, in the biome (if home is).
func _pick_waypoint(leader: NightRider, anywhere := false) -> Vector3:
	var map: PlanetData = world.planet
	var check_biome := species.biome_ok(map.biome[map.cell_at(home)])
	var bearing := CreatureSpawner._bearing(leader.dir, (leader.dir + leader.heading * 0.001).normalized())
	var spread := PI if anywhere else 0.9
	for attempt in 12:
		var p := CreatureSpawner._offset(leader.dir, bearing + _rng.randf_range(-spread, spread), _rng.randf_range(40.0, 80.0))
		if CubeSphere.surface_distance_m(p, home) > species.territory_m:
			continue
		if chunks.water_level_at(p) > chunks.ground_height(p) + 0.3:
			continue
		if check_biome and not species.biome_ok(map.biome[map.cell_at(p)]):
			continue
		return p
	if leader.distance_to(home) > 30.0:
		return home
	return CreatureSpawner._offset(leader.dir, bearing + PI * 0.5, 60.0)


# --- The follower ----------------------------------------------------------------

func _restart_track() -> void:
	_track.clear()
	var leader := _lead()
	if leader == null:
		return
	var back := riders.size() * gap_m + 10.0
	var n := int(back / TRACK_STEP_M)
	for i in range(n, -1, -1):
		var s := -i * TRACK_STEP_M
		_track.append([(leader.dir + leader.heading * s / PlanetConst.RADIUS_M).normalized(), leader.travelled + s])


func _record(leader: NightRider) -> void:
	if _track.is_empty() or leader.travelled - float(_track[-1][1]) >= TRACK_STEP_M:
		_track.append([leader.dir, leader.travelled])
	var keep_from := leader.travelled - riders.size() * gap_m - 30.0
	while _track.size() > 2 and float(_track[1][1]) < keep_from:
		_track.pop_front()


## The point on the leader's track where it had walked `s` meters.
func _track_at(s: float) -> Vector3:
	if s <= float(_track[0][1]):
		return _track[0][0]
	for i in range(_track.size() - 1, 0, -1):
		var s0: float = _track[i - 1][1]
		if s >= s0:
			var s1: float = _track[i][1]
			var f := clampf((s - s0) / maxf(s1 - s0, 1e-6), 0.0, 1.0)
			return (_track[i - 1][0] as Vector3).slerp(_track[i][0], f).normalized()
	return _track[-1][0]


## How far along the leader's track a spot is (the nearest track point).
func _track_s(d: Vector3) -> float:
	var best := INF
	var best_s := 0.0
	for p in _track:
		var dd := (p[0] as Vector3).distance_squared_to(d)
		if dd < best:
			best = dd
			best_s = p[1]
	return best_s


func _steer_follower(r: NightRider, leader: NightRider, k: int) -> void:
	var s_goal := leader.travelled - gap_m * k
	r.want_dir = _track_at(minf(s_goal + 2.0, leader.travelled))
	var behind := (leader.travelled - _track_s(r.dir)) - gap_m * k
	r.want_speed = clampf(leader.speed + 0.5 * behind, 0.0, r.walk_mps * 1.2)
	# Out of step with the leader by the pair's phase offset.
	r.phase_ref = fposmod(leader.phase + phase_offset * k, 1.0)


# --- Hunting ---------------------------------------------------------------------

func _strikes(pd: Vector3, delta: float) -> void:
	_strike_cd -= delta
	if state != "hunt" or _strike_cd > 0.0:
		return
	var reach := float(_hunt.get("reach_m", 2.6))
	for r in riders:
		if r.dead or r.done or r.distance_to(pd) > reach:
			continue
		_strike_cd = float(_hunt.get("strike_s", 2.0))
		if spawner and spawner.has_method("player_hit") and species.bite > 0.0:
			spawner.player_hit(species.bite, r.global_position)
		return


## One of them was shot: both turn on you.
func _on_hurt(_c: Creature, _killed: bool) -> void:
	for r in riders:
		if not r.dead:
			r.angry = 40.0
	if aggressive:
		state = "hunt"


func _on_finished(c: Creature) -> void:
	riders.erase(c)
	if is_instance_valid(c):
		NodeRelease.free_later(c)
	if riders.is_empty():
		done = true
		finished.emit(self)

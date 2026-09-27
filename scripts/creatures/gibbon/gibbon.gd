class_name Gibbon
extends Node3D
## A gibbon (spec Phase 1 (iii)): R3's gibbon-type monkey of the warm, wet
## canopy, travelling through the trees by brachiation along their branch
## graphs (BranchGraph, found through BranchGraphs, read only).
##
## How it moves:
##   - It hangs from one hand at a handhold and swings as a pendulum from
##     the top of the wood down to its center of mass (HANG_M: arm plus
##     body), under gravity with a little damping. It pumps the swing up
##     (tucking and kicking its legs) when it wants a bigger one, and
##     brakes it when it wants to slow down.
##   - At the right point of a forward swing it lets go and flies
##     ballistically to the next handhold, catching it with the other hand
##     (GibbonPlanner.solve() picks the release and catch angles, launch()
##     the exact throw; the pulling arm may add a little speed). Short
##     gaps need no flight: the free hand closes on the next handhold as
##     the body swings under it.
##   - The next handhold comes from BranchGraphs.handholds_within(): wood
##     it can hang from, in the direction it travels, that a swing can
##     reach, preferring handholds further along its route, the next ones
##     along the same limb when the gap is short, and swings that keep the
##     momentum it has (a big swing takes a long leap; near its goal it
##     slows by choosing short ones).
##   - The hand holding on stays exactly on the handhold (GibbonRig's arm
##     IK) and the body swings below it.
## What it does: picks a goal handhold 10-38 m off through the canopy
## (GibbonPlanner.search()), travels there along the route, pauses, now
## and then pulls up to sit on a thick limb, turns round when its next
## goal is behind it, and hoots (GibbonHoot, 3D sound). No combat, no
## ecology ledger. Nothing spawns it in normal play (creatures.json:
## "spawn": "disabled"); debug_spawn() places one.
##
## Its whole state is kept relative to handholds (a swing angle under a
## grip, a flight relative to the handhold it will catch), and handhold
## positions come from the graphs every frame, so the floating origin
## never disturbs it.

## Grip (the top of the wood) to the center of mass while hanging (m):
## shoulder to grip nearly straight, plus the shoulder's height above the
## center of mass (GibbonBody).
const HANG_M := 0.78
const G := GibbonPlanner.G
## Swing damping (1/s), across-the-plane sway damping, the pumping
## push (rad/s^2) and the braking when it wants a smaller swing (1/s).
const DAMP := 0.1
const LAT_DAMP := 2.4
const PUMP := 3.2
const BRAKE := 1.4
## A hanging body leans away from the holding arm (so the arm comes
## down near its middle) and turns so the free shoulder leads (rad).
const LEAN := 0.3
const TWIST := 0.5
## Shoulder to grip point (m): the reach at which a free hand closes on
## a handhold, and the most a holding arm stretches (GibbonRig's arm is
## 0.62 m with the hand).
const ARM_REACH := 0.61
const ARM_MAX := 0.612
## The most swing a catch leaves it with (radians): the arm and shoulder
## soak up the rest of a long, dropping leap.
const CATCH_AMP := 1.35
## Goals: this far away (m, across the ground), and the route's lookahead.
const GOAL_MIN_M := 10.0
const GOAL_MAX_M := 38.0
const LOOKAHEAD_M := 4.0
## Sitting: center of mass above the top of the wood (m).
const SEAT_H := 0.2
## Blob shadow only this close to the ground (m).
const BLOB_H := 3.0
## Hoots: full volume within HOOT_UNIT_M, gone past HOOT_MAX_M.
const HOOT_UNIT_M := 12.0
const HOOT_MAX_M := 160.0

var species: CreatureSpecies
## Seeds its choices (0: a fresh seed each time).
var seed_value := 0
## Draws the chosen handholds, the flight arcs and the route (for stills
## and the dev overlay).
var debug := false
## "hang" (swinging or pausing under a grip), "fly", "pull_up", "sit",
## "drop" (sit back down to a hang), "turn" (turning round on the grip).
var mode := "hang"
var voice: AudioStreamPlayer3D
## Counters for tests and the overlay.
var stats := {"leaps": 0, "reaches": 0, "misses": 0, "goals": 0, "sits": 0, "turns": 0, "hoots": 0, "longest_leap_m": 0.0}

var _rng := RandomNumberGenerator.new()
var _built := false
var _parts := {}
var _skel: Skeleton3D
var _rig: GibbonRig
var _hit: GibbonHitboxes
var _blob_anchor: Node3D
var _blob: MeshInstance3D
var _blob_t := 0.0

# The wood it holds, which hand holds it (0 left, 1 right) and the up it
# hangs by (the tree frame's +Y).
var _g: BranchGraph
var _i := -1
var _hand := 1
var _up := Vector3.UP
# The swing: its plane (horizontal, the way it swings forward), the angle
# from straight down in the plane (forward positive) and across it, their
# rates, the hang length now (it eases to HANG_M after a close catch) and
# the amplitude it wants.
var _fwd := Vector3.FORWARD
# The way the body faces (horizontal): it turns toward the swing's plane
# rather than snapping when a catch sends it off in a new direction.
var _face := Vector3.FORWARD
var _theta := 0.0
var _omega := 0.0
var _psi := 0.0
var _psi_v := 0.0
var _r := HANG_M
var _amp_want := 0.0
# The next handhold and the move to it (GibbonPlanner.solve()); forward
# swings that ended without making it; handholds given up on here.
var _tg: BranchGraph
var _ti := -1
var _plan := {}
var _missed := 0
var _blocked: Array = []
# Flight: start (relative to the grip it will catch) and velocity, time
# so far and in all, the body's turn from release to catch.
var _fl_p0 := Vector3.ZERO
var _fl_v0 := Vector3.ZERO
var _fl_t := 0.0
var _fl_len := 0.0
var _fl_b0 := Basis.IDENTITY
var _fl_b1 := Basis.IDENTITY
# Route: [graph, index] pairs, the distance along it at each, where each
# handhold is on it (graph -> {index: position}) and how far along it is.
var _route: Array = []
var _route_s := PackedFloat32Array()
var _route_at := {}
var _route_k := 0
var _reroute_t := 0.0
# Behaviour.
var _mode_t := 0.0
var _pause_t := 0.0
var _sit_next := false
var _sit_t := 0.0
var _hoot_t := 0.0
var _hooting := 0.0
var _look_t := 0.0
var _look := Vector3.ZERO
var _swing_clock := 0.0
# Transitions (pull up, drop, turn): the center of mass at the start, a
# control point and the end, relative to the top of the wood; the body's
# turn.
var _tr_len := 1.0
var _tr_c0 := Vector3.ZERO
var _tr_c1 := Vector3.ZERO
var _tr_mid := Vector3.ZERO
var _tr_b0 := Basis.IDENTITY
var _tr_b1 := Basis.IDENTITY
var _turn_from := Vector3.FORWARD
var _turn_to := Vector3.FORWARD
# Sitting: where (relative to the handhold's top), facing, the free hand's
# spot on the wood.
var _sit_off := Vector3.ZERO
var _sit_f := Vector3.FORWARD
# Posing: the body (scene), its smoothed lean and twist, per hand where
# it let go from and how long ago and its loose pose (skeleton space,
# eased), the legs.
var _com := Vector3.ZERO
var _body_b := Basis.IDENTITY
var _lean := 0.0
var _twist := 0.0
var _let_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _let_t: Array[float] = [9.0, 9.0]
var _loose: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _legs := PackedFloat32Array([0.4, 0.15, 0.6, 0.2, 0.4, 0.15, 0.6, 0.2])
# Debug drawing.
var _dbg_mi: MeshInstance3D
var _dbg_im: ImmediateMesh
var _dbg_arcs: Array = [] # PackedVector3Array per flight (scene)
var _dbg_picks := PackedVector3Array()
var _dbg_cands: Array = [] # [scene position, chosen-able]
var _dbg_pred := PackedVector3Array()


## Hangs a gibbon (a child of `parent`) on the nearest handhold it can
## hang from, of the branch graphs registered near `near_pos`. The dev
## spawn key calls this. null if no tree has a graph within 200 m.
static func debug_spawn(parent: Node, near_pos: Vector3) -> Gibbon:
	var at := _hangable_near(near_pos, 60.0)
	if at.is_empty():
		at = _hangable_near(near_pos, 200.0)
	if at.is_empty():
		push_warning("Gibbon.debug_spawn: no branch graph within 200 m")
		return null
	var gib := Gibbon.new()
	gib.name = "Gibbon"
	parent.add_child(gib)
	gib.hang_on(at[0], at[1])
	return gib


static func _hangable_near(p: Vector3, radius: float) -> Array:
	for h in BranchGraphs.handholds_within(p, radius, BranchGraph.MIN_RADIUS_M):
		var g: BranchGraph = h[0]
		var i: int = h[1]
		if GibbonPlanner.hangable(g, i, _up_of(g)):
			return [g, i]
	return []


static func _up_of(g: BranchGraph) -> Vector3:
	return g.frame().basis.y.normalized()


func _ready() -> void:
	if species == null:
		species = CreatureSpecies.find("Gibbon")
	_rng.seed = seed_value if seed_value != 0 else hash([Time.get_ticks_usec(), get_instance_id()])
	GibbonBody.prewarm()
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.unit_size = HOOT_UNIT_M
	voice.max_distance = HOOT_MAX_M
	voice.volume_db = -4.0
	voice.position = Vector3(0.0, 0.27, -0.05)
	add_child(voice)
	_blob_anchor = Node3D.new()
	_blob_anchor.name = "BlobAnchor"
	_blob_anchor.top_level = true
	add_child(_blob_anchor)
	_blob = BlobShadow.make(_blob_anchor, 0.2, 0.24)
	_blob.visible = false
	_hoot_t = _rng.randf_range(3.0, 9.0)
	var w := get_node_or_null("/root/World")
	if w and w.has_signal("origin_shifted"):
		w.origin_shifted.connect(_on_origin_shifted)
	_try_build()


## Start hanging from handhold `i` of `g`, still, facing across the wood.
func hang_on(g: BranchGraph, i: int) -> void:
	_g = g
	_i = i
	_up = _up_of(g)
	_hand = 1
	var t := g.dir(i)
	var across := _up.cross(t)
	if across.length_squared() < 1e-6:
		across = _up.cross(Vector3.RIGHT if absf(_up.x) < 0.9 else Vector3.FORWARD)
	_fwd = across.normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
	_face = _fwd
	_theta = 0.0
	_omega = 0.0
	_psi = 0.0
	_psi_v = 0.0
	_r = HANG_M
	_tg = null
	_plan = {}
	_route = []
	_route_at = {}
	mode = "hang"
	_mode_t = 0.0
	_lean = LEAN
	_twist = -TWIST
	_pause(_rng.randf_range(1.0, 2.0))


## Travel to a goal now (overrides its own choice): a handhold it must be
## able to reach through the canopy. False if there's no way.
func go_to(g: BranchGraph, i: int) -> bool:
	if _g == null or mode != "hang":
		return false
	var s := GibbonPlanner.search(_g, _i, _up, HANG_M, 80.0, g, i)
	if s == null:
		return false
	var path := s.path_to(s.node_of(g, i))
	if path.size() < 2:
		return false
	_set_route(path)
	_pause_t = 0.0
	_sit_next = false
	_tg = null
	return true


## Where it is: the handhold it holds (or will catch), [graph, index].
func grip() -> Array:
	return [_tg, _ti] if mode == "fly" else [_g, _i]


func center_of_mass() -> Vector3:
	return _com


func _try_build() -> void:
	if _built or not GibbonBody.ready():
		return
	var coat := species.color if species else GibbonBody.COAT
	var pale := species.accent if species else GibbonBody.PALE
	_parts = GibbonBody.build(coat, pale)
	if _parts.is_empty():
		return
	add_child(_parts.root)
	_skel = _parts.skeleton
	_rig = GibbonRig.new(_skel)
	_hit = GibbonHitboxes.new()
	add_child(_hit)
	_hit.setup(self, _skel)
	_built = true


func _process(delta: float) -> void:
	if not _built:
		_try_build()
	if _g == null:
		return
	if not _g.valid() or (mode == "fly" and (_tg == null or not _tg.valid())):
		# Its tree left NEAR range (or the tree it was leaping to did).
		queue_free()
		return
	var dt := minf(delta, 0.05)
	_mode_t += dt
	_up = _up_of(_g)
	match mode:
		"hang":
			_hang_step(dt)
		"fly":
			_fly_step(dt)
		"pull_up", "drop":
			_transition_step(dt)
		"sit":
			_sit_step(dt)
		"turn":
			_turn_step(dt)
	_voice_step(dt)
	_pose(dt)
	if _built:
		_rig.apply()
		_hit.update()
	_blob_step(dt)
	if debug:
		_draw_debug()
	elif _dbg_mi:
		_dbg_mi.visible = false


# --- Hanging and swinging ---------------------------------------------------------

func _hang_step(dt: float) -> void:
	if _pause_t > 0.0:
		_pause_t -= dt
		_amp_want = 0.0
		if _pause_t <= 0.0 and _amplitude() > 0.35:
			# Let the swing die down first.
			_pause_t = 0.3
		if _pause_t <= 0.0:
			_end_pause()
			if mode != "hang":
				return
	elif _tg == null or not _tg.valid():
		if not _choose_next():
			_arrive(false)
	_swing(dt)
	if mode != "hang" or _tg == null or _pause_t > 0.0:
		return
	if _plan.contact:
		_try_reach()
	else:
		_try_release()


## The pendulum, in a few substeps: gravity, damping, the pump or brake,
## and a sway across the plane that dies away.
func _swing(dt: float) -> void:
	var amp := _amplitude()
	var gr := G / _r
	var steps := 4
	var h := dt / steps
	var was := _omega
	for k in steps:
		var push := 0.0
		if _amp_want > amp + 0.03:
			if absf(_omega) < 0.05 and absf(_theta) < 0.05:
				_omega += 0.7
			push = signf(_omega) * PUMP * clampf((_amp_want - amp) / 0.25, 0.25, 1.0)
		elif amp > _amp_want + 0.08:
			push = -_omega * BRAKE
		_omega += (-gr * sin(_theta) - DAMP * _omega + push) * h
		_theta += _omega * h
		_psi_v += (-gr * sin(_psi) - LAT_DAMP * _psi_v) * h
		_psi += _psi_v * h
	_theta = clampf(_theta, -2.4, 2.4)
	_psi = clampf(_psi, -1.0, 1.0)
	_r = move_toward(_r, HANG_M, dt * 1.2)
	_swing_clock += dt
	# A forward swing that ended without making its move.
	if was > 0.0 and _omega <= 0.0 and _tg != null and _pause_t <= 0.0:
		_missed += 1
		if _missed >= 3:
			stats.misses += 1
			_blocked.append([_tg, _ti])
			_tg = null
			_plan = {}


## Energy of the swing as an amplitude (radians from straight down).
func _amplitude() -> float:
	var e := 0.5 * pow(_r * _omega, 2.0) + G * _r * (1.0 - cos(_theta)) + 0.5 * pow(_r * _psi_v, 2.0)
	return acos(clampf(1.0 - e / (G * _r), -1.0, 1.0))


## Unit vector from the grip to the center of mass, and its derivatives
## by the swing angle and the sway angle.
func _swing_dirs() -> Array[Vector3]:
	var side := _fwd.cross(_up)
	var st := sin(_theta)
	var ct := cos(_theta)
	var sp := sin(_psi)
	var cp := cos(_psi)
	var d := _fwd * (st * cp) + side * sp - _up * (ct * cp)
	var d_th := _fwd * (ct * cp) + _up * (st * cp)
	var d_ps := -_fwd * (st * sp) + side * cp + _up * (ct * sp)
	return [d, d_th, d_ps]


func _swing_velocity() -> Vector3:
	var dd := _swing_dirs()
	return (dd[1] * _omega + dd[2] * _psi_v) * _r


## The swing that puts the center of mass at `c` moving at `v` under the
## current grip, in the vertical plane along `f`.
func _set_swing_from(c: Vector3, v: Vector3, f: Vector3) -> void:
	var grip_p := _pivot(_g, _i)
	_fwd = f
	var side := _fwd.cross(_up)
	var rel := c - grip_p
	_r = clampf(rel.length(), HANG_M * 0.35, HANG_M)
	var n := rel.normalized()
	_psi = asin(clampf(n.dot(side), -1.0, 1.0))
	_theta = atan2(n.dot(_fwd), -n.dot(_up))
	var dd := _swing_dirs()
	var cp := cos(_psi)
	_omega = v.dot(dd[1]) / (_r * maxf(cp * cp, 0.2))
	_psi_v = v.dot(dd[2]) / _r


## Where the pendulum hangs from: the top of the wood.
func _pivot(g: BranchGraph, i: int) -> Vector3:
	return GibbonPlanner.top(g, i, _up)


## Where a holding hand's grip point goes: round the wood, just under its
## top (thin wood sits in the middle of the hooked hand).
func _hand_point(g: BranchGraph, i: int) -> Vector3:
	var t := g.dir(i)
	var side := _up - t * _up.dot(t)
	if side.length_squared() < 1e-6:
		return g.pos(i)
	return g.pos(i) + side.normalized() * maxf(g.radius[i] - 0.03, 0.0)


func _horizontal(v: Vector3) -> Vector3:
	return v - _up * v.dot(_up)


## Flight: at the right point of a forward swing, let go if a throw from
## here reaches the catch.
func _try_release() -> void:
	var th: float = _plan.theta
	if _omega <= 0.0 or _theta < th - 0.2 or _theta > th + 0.45:
		return
	var grip2 := _pivot(_tg, _ti)
	var c: Vector3 = _hang_frame()[0]
	var v := _swing_velocity()
	var catch_p := _catch_point(grip2)
	var sol := GibbonPlanner.launch(c, v, catch_p, _up, GibbonPlanner.BOOST_MAX)
	if sol.is_empty():
		return
	var v0: Vector3 = sol[0]
	var tf: float = sol[1]
	var free := 1 - _hand
	mode = "fly"
	_mode_t = 0.0
	_fl_p0 = c - grip2
	_fl_v0 = v0
	_fl_t = 0.0
	_fl_len = tf
	_fl_b0 = _body_b
	# The body at the catch: under the new grip from the other hand.
	var f2 := _horizontal(grip2 - _pivot(_g, _i)).normalized()
	var w := (grip2 - catch_p).normalized()
	var lean_to := LEAN * (1.0 if free == 1 else -1.0)
	var twist_to := -TWIST * (1.0 if free == 1 else -1.0)
	_fl_b1 = _body_basis(w, f2.rotated(_up, twist_to), lean_to)
	_let_go(_hand)
	stats.leaps += 1
	stats.longest_leap_m = maxf(stats.longest_leap_m, _horizontal(grip2 - _pivot(_g, _i)).length())
	var arc := PackedVector3Array()
	for k in 17:
		var tk := tf * k / 16.0
		arc.append(c + v0 * tk - _up * (0.5 * G * tk * tk))
	_dbg_arcs.append(arc)
	if _dbg_arcs.size() > 8:
		_dbg_arcs.pop_front()
	_dbg_pred = PackedVector3Array()


## The center of mass at the catch: an arm's reach from the new grip,
## behind and below it (the plan's catch angle).
func _catch_point(grip2: Vector3) -> Vector3:
	var f2 := _horizontal(grip2 - _pivot(_g, _i)).normalized()
	var phi: float = _plan.phi
	var cr := HANG_M * GibbonPlanner.REACH * 0.93
	return grip2 - f2 * (cr * sin(phi)) - _up * (cr * cos(phi))


## Contact: the free hand closes on the next handhold as the body swings
## under it.
func _try_reach() -> void:
	var free := 1 - _hand
	var h2 := _hand_point(_tg, _ti)
	var frame := _hang_frame()
	var c: Vector3 = frame[0]
	var b: Basis = frame[1]
	var sh := c + b * _shoulder_local(free)
	if sh.distance_to(h2) > ARM_REACH:
		return
	if (c - _pivot(_tg, _ti)).dot(_up) > -0.2 * HANG_M:
		return
	var v := _swing_velocity()
	_let_go(_hand)
	_g = _tg
	_i = _ti
	_hand = free
	_tg = null
	_plan = {}
	stats.reaches += 1
	v = _absorb(c, v)
	var fh := _horizontal(v)
	_set_swing_from(c, v, fh.normalized() if fh.length() > 0.3 else _fwd)
	_on_new_grip(c, v)


## The velocity a catch leaves (under the grip it now holds): no more
## than a swing of CATCH_AMP.
func _absorb(c: Vector3, v: Vector3) -> Vector3:
	var rel := c - _pivot(_g, _i)
	var r := clampf(rel.length(), HANG_M * 0.35, HANG_M)
	var cos_t := clampf(-rel.dot(_up) / maxf(rel.length(), 1e-4), -1.0, 1.0)
	var room := G * r * (cos_t - cos(CATCH_AMP))
	if room <= 0.0:
		return Vector3.ZERO
	var k := 0.5 * v.length_squared()
	return v * sqrt(room / k) if k > room else v


func _let_go(s: int) -> void:
	_let_from[s] = _hand_point(_g, _i)
	_let_t[s] = 0.0
	_loose[s] = Vector3.ZERO


# --- Flight --------------------------------------------------------------------

func _fly_step(dt: float) -> void:
	_fl_t += dt
	if _fl_t >= _fl_len:
		_catch()


func _fly_com() -> Vector3:
	var t := minf(_fl_t, _fl_len)
	return _pivot(_tg, _ti) + _fl_p0 + _fl_v0 * t - _up * (0.5 * G * t * t)


func _catch() -> void:
	var t := _fl_len
	var grip2 := _pivot(_tg, _ti)
	var c := grip2 + _fl_p0 + _fl_v0 * t - _up * (0.5 * G * t * t)
	var v := _fl_v0 - _up * (G * t)
	var came_from := _pivot(_g, _i)
	_g = _tg
	_i = _ti
	_hand = 1 - _hand
	_tg = null
	_plan = {}
	mode = "hang"
	_mode_t = 0.0
	_lean = LEAN * (1.0 if _hand == 1 else -1.0)
	_twist = -TWIST * (1.0 if _hand == 1 else -1.0)
	_dbg_picks.append(grip2)
	if _dbg_picks.size() > 12:
		_dbg_picks.remove_at(0)
	v = _absorb(c, v)
	var f := _horizontal(grip2 - came_from)
	_set_swing_from(c, v, f.normalized() if f.length() > 0.2 else _fwd)
	_face = _fwd
	_on_new_grip(c, v)


# --- Choosing the next handhold ---------------------------------------------------

## A new grip: move along the route, arrive, or pick the next handhold
## (swinging on in its direction).
func _on_new_grip(c: Vector3, v: Vector3) -> void:
	_blocked = []
	_missed = 0
	if _route.is_empty():
		_arrive(true)
		return
	var goal: Array = _route[_route.size() - 1]
	if (goal[0] == _g and goal[1] == _i) or _pivot(_g, _i).distance_to(_pivot(goal[0], goal[1])) < 1.2:
		stats.goals += 1
		_arrive(true)
		return
	var k := _route_index(_g, _i)
	if k >= 0:
		_route_k = k
	elif not _reroute():
		# Off its route with no way on to the goal from here.
		_arrive(false)
		return
	if not _choose_next(c, v):
		if not _reroute() or not _choose_next(c, v):
			_arrive(false)


## Picks the next handhold from BranchGraphs.handholds_within() and the
## move to it; swings on in its direction. False if there's none.
func _choose_next(c := Vector3.INF, v := Vector3.INF) -> bool:
	var here := _pivot(_g, _i)
	if c == Vector3.INF:
		c = here + _swing_dirs()[0] * _r
		v = _swing_velocity()
	var travel := _travel_dir(here)
	var amp_now := _amplitude()
	# The way its momentum carries it, and how strongly.
	var vh := _horizontal(v)
	var carry := clampf(vh.length() / 2.0, 0.0, 1.0)
	var vdir := vh.normalized() if vh.length() > 0.05 else Vector3.ZERO
	var want := _cruise_amp()
	var pref := lerpf(want, amp_now, 0.5) if amp_now > want and _route_left() > 5.0 else want
	var cands := BranchGraphs.handholds_within(here, GibbonPlanner.LOOK_M, BranchGraph.MIN_RADIUS_M)
	var pool := []
	_dbg_cands = []
	# Handholds further along its route, whichever way the route turns;
	# off the route, only ones in the direction it travels that bring it
	# nearer the route ahead (looser if there are none).
	for strict in [0.3, -0.2, -2.0]:
		for e in cands:
			var g: BranchGraph = e[0]
			var i: int = e[1]
			if (g == _g and i == _i) or not GibbonPlanner.hangable(g, i, _up) or _is_blocked(g, i):
				continue
			var p := _pivot(g, i)
			var d := p - here
			var y := d.dot(_up)
			var hv := d - _up * y
			var x := hv.length()
			if x < 0.4:
				continue
			var dir := hv / x
			var rk := _route_index(g, i)
			var on_route := rk > _route_k
			if not on_route and (rk >= 0 or (travel != Vector3.ZERO and dir.dot(travel) < strict)):
				continue
			if not GibbonPlanner.can_cross(x, y, HANG_M):
				continue
			var prog := _progress(g, i, p, here)
			if not on_route and prog <= 0.0:
				continue
			var score := prog + 0.8 * carry * dir.dot(vdir)
			# Along the same limb, the next handholds out or in.
			if g == _g and g.limb[i] == _g.limb[_i] and x < 1.8:
				score += 0.5
			pool.append([score, g, i, x, y, dir, p])
		if not pool.is_empty():
			break
	if pool.is_empty():
		return false
	pool.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var best: Array = []
	var best_plan := {}
	var best_score := -INF
	for pass_i in 2:
		for k in mini(pool.size(), 10):
			var e: Array = pool[k]
			var plan := GibbonPlanner.solve(e[3], e[4], HANG_M, pref, amp_now if amp_now > 0.3 else -1.0)
			if plan.is_empty():
				continue
			var need: float = plan.amp
			# Reachable from the swing it has (plus a swing's pumping), or,
			# failing any, after building one up.
			if pass_i == 0 and not plan.contact and need > amp_now + 0.55:
				continue
			var score: float = e[0] - 0.8 * float(plan.cost)
			_dbg_cands.append([e[6], true])
			if score > best_score:
				best_score = score
				best = e
				best_plan = plan
		if not best.is_empty():
			break
	if best.is_empty():
		return false
	_tg = best[1]
	_ti = best[2]
	_plan = best_plan
	_missed = 0
	_amp_want = maxf(float(best_plan.amp) + (0.04 if not best_plan.contact else 0.02), 0.2)
	_set_swing_from(c, v, best[5])
	_predict_arc()
	return true


func _is_blocked(g: BranchGraph, i: int) -> bool:
	for b in _blocked:
		if b[0] == g and b[1] == i:
			return true
	return false


## How much a handhold moves it on: meters along the route if it's on it
## (further along is better), else how much nearer the route ahead it is.
func _progress(g: BranchGraph, i: int, p: Vector3, here: Vector3) -> float:
	if _route.is_empty():
		return 0.0
	var k := _route_index(g, i)
	if k >= 0:
		return _route_s[k] - _route_s[_route_k] if k > _route_k else -1.0 - (_route_s[_route_k] - _route_s[k])
	# Off the route: only when nothing on it will do.
	var ahead := _lookahead()
	return (here.distance_to(ahead) - p.distance_to(ahead)) * 0.7 - 1.5


## The swing it likes at its speed (radians), smaller near its goal.
func _cruise_amp() -> float:
	var sp := species.speed_mps if species else 3.0
	var a := clampf(0.35 + sp * 0.2, 0.5, 1.3)
	var left := _route_left()
	if left < 5.0:
		a = lerpf(0.4, a, left / 5.0)
	return a


func _predict_arc() -> void:
	_dbg_pred = PackedVector3Array()
	if _plan.is_empty() or _plan.contact:
		return
	var here := _pivot(_g, _i)
	var th: float = _plan.theta
	var a: float = _plan.amp
	var r := here + (_fwd * sin(th) - _up * cos(th)) * HANG_M
	var s := sqrt(maxf(2.0 * G * HANG_M * (cos(th) - cos(a)), 0.0)) + float(_plan.boost)
	var v := (_fwd * cos(th) + _up * sin(th)) * s
	var tau: float = _plan.tau
	for k in 13:
		var t := tau * k / 12.0
		_dbg_pred.append(r + v * t - _up * (0.5 * G * t * t))


# --- Route and goals -----------------------------------------------------------

func _set_route(path: Array) -> void:
	_route = path
	_route_s = PackedFloat32Array()
	_route_at = {}
	var s := 0.0
	var prev := Vector3.INF
	for k in path.size():
		var g: BranchGraph = path[k][0]
		var i: int = path[k][1]
		var p := _pivot(g, i)
		if prev != Vector3.INF:
			s += prev.distance_to(p)
		prev = p
		_route_s.append(s)
		if not _route_at.has(g):
			_route_at[g] = {}
		_route_at[g][i] = k
	_route_k = 0


func _route_index(g: BranchGraph, i: int) -> int:
	if not _route_at.has(g):
		return -1
	return _route_at[g].get(i, -1)


func _route_left() -> float:
	if _route.is_empty():
		return 0.0
	return _route_s[_route_s.size() - 1] - _route_s[_route_k]


## The route a few meters on from where it is (or its end).
func _lookahead() -> Vector3:
	var want := _route_s[_route_k] + LOOKAHEAD_M
	for k in range(_route_k, _route.size()):
		if _route_s[k] >= want:
			return _pivot(_route[k][0], _route[k][1])
	var last: Array = _route[_route.size() - 1]
	return _pivot(last[0], last[1])


## The way it's heading (horizontal), or zero when the way on is straight
## up or down.
func _travel_dir(here: Vector3) -> Vector3:
	if _route.is_empty():
		return Vector3.ZERO
	var h := _horizontal(_lookahead() - here)
	return h / h.length() if h.length() > 0.5 else Vector3.ZERO


## Off its route (a reach that went elsewhere) or stuck on it: route
## again from here to the goal. False if there's no way.
func _reroute() -> bool:
	if _route.is_empty() or _swing_clock - _reroute_t < 0.5:
		return false
	_reroute_t = _swing_clock
	var goal: Array = _route[_route.size() - 1]
	var s := GibbonPlanner.search(_g, _i, _up, HANG_M, 80.0, goal[0], goal[1])
	if s == null:
		return false
	var path := s.path_to(s.node_of(goal[0], goal[1]))
	if path.size() < 2:
		return false
	_set_route(path)
	return true


## A goal through the canopy: a handhold GOAL_MIN_M-GOAL_MAX_M away that
## it can reach and get back from (so it never strands itself on a limb
## it can only drop out of), mostly ahead of it when `ahead`, now and then
## on thick wood it can sit on; failing that, anywhere it can get to 3 m
## or more away.
func _pick_goal(ahead: bool) -> bool:
	var here := _pivot(_g, _i)
	var s := GibbonPlanner.search(_g, _i, _up, HANG_M, GOAL_MAX_M + 12.0)
	if s == null:
		return false
	var back := GibbonPlanner.search(_g, _i, _up, HANG_M, GOAL_MAX_M + 12.0, null, -1, true)
	var best := -1
	for band in [Vector2(GOAL_MIN_M, GOAL_MAX_M), Vector2(3.0, GOAL_MAX_M + 12.0)]:
		var best_score := -INF
		for n in s.node_g.size():
			if not s.reached(n):
				continue
			var g: BranchGraph = s.graphs[s.node_g[n]]
			if band.x >= GOAL_MIN_M and not back.reached(back.node_of(g, s.node_i[n])):
				continue
			var d := _horizontal(s.node_p[n] - here)
			var dist := d.length()
			if dist < band.x or dist > band.y:
				continue
			var score := _rng.randf()
			if ahead:
				score += 0.8 * d.normalized().dot(_fwd)
			if GibbonPlanner.sittable(g, s.node_i[n], _up):
				score += 0.35
			if score > best_score:
				best_score = score
				best = n
		if best >= 0:
			break
	if best < 0:
		return false
	_set_route(s.path_to(best))
	return _route.size() >= 2


# --- Behaviour: pauses, sitting, turning, hoots ---------------------------------

func _pause(seconds: float) -> void:
	_pause_t = seconds
	_amp_want = 0.0


## At its goal (or stuck): stop, look round, maybe hoot, maybe sit.
func _arrive(reached: bool) -> void:
	_tg = null
	_plan = {}
	_dbg_pred = PackedVector3Array()
	_route = []
	_route_at = {}
	_pause(_rng.randf_range(1.6, 3.2) if reached else _rng.randf_range(0.8, 1.6))
	_sit_next = reached and GibbonPlanner.sittable(_g, _i, _up) and _rng.randf() < 0.6
	if reached and _rng.randf() < 0.6:
		_hoot_t = minf(_hoot_t, _rng.randf_range(0.4, 1.2))


func _end_pause() -> void:
	if _sit_next:
		_sit_next = false
		_start_pull_up()
		return
	if not _pick_goal(_rng.randf() < 0.7) and not _pick_goal(false):
		_pause(2.0)
		return
	var travel := _travel_dir(_pivot(_g, _i))
	if travel != Vector3.ZERO and travel.dot(_fwd) < -0.2 and _amplitude() < 0.35:
		_start_turn(travel)


func _start_turn(to: Vector3) -> void:
	mode = "turn"
	_mode_t = 0.0
	_tr_len = 1.0
	_turn_from = _fwd
	_turn_to = to
	stats.turns += 1


func _turn_step(dt: float) -> void:
	_amp_want = 0.0
	_swing(dt)
	var u := smoothstep(0.0, 1.0, _mode_t / _tr_len)
	var a := _turn_from.signed_angle_to(_turn_to, _up)
	_fwd = _turn_from.rotated(_up, a * u).normalized()
	if _mode_t >= _tr_len:
		_fwd = _turn_to
		mode = "hang"
		_mode_t = 0.0
		_choose_next()


## Pull up from the hang to sit on top of the wood, beside the holding
## hand, facing across the wood the way it faces.
func _start_pull_up() -> void:
	var top := _pivot(_g, _i)
	var t := _g.dir(_i)
	var across := _horizontal(_up.cross(t)).normalized()
	if across.dot(_fwd) < 0.0:
		across = -across
	_sit_f = across
	# The body sits to the free hand's side of the holding hand.
	var x := _sit_f.cross(_up)
	var along := _horizontal(t).normalized()
	if along.dot(x) < 0.0:
		along = -along
	var sx := 1.0 if _hand == 1 else -1.0
	_sit_off = -along * (0.13 * sx) + _up * SEAT_H + _sit_f * 0.02
	var frame := _hang_frame()
	_tr_c0 = frame[0] - top
	_tr_b0 = frame[1]
	_tr_c1 = _sit_off
	_tr_b1 = _body_basis(_up, _sit_f, 0.0)
	_tr_mid = _sit_f * 0.38 - _up * 0.05
	_tr_len = 1.1
	mode = "pull_up"
	_mode_t = 0.0
	stats.sits += 1


func _transition_step(_dt: float) -> void:
	if _mode_t < _tr_len:
		return
	if mode == "pull_up":
		mode = "sit"
		_mode_t = 0.0
		_sit_t = _rng.randf_range(3.5, 6.5)
		if _rng.randf() < 0.5:
			_hoot_t = minf(_hoot_t, _rng.randf_range(0.8, 2.0))
	else:
		mode = "hang"
		_mode_t = 0.0
		_theta = 0.35
		_omega = 0.0
		_psi = 0.0
		_psi_v = 0.0
		_r = HANG_M
		_pause(_rng.randf_range(0.5, 1.2))


func _sit_step(_dt: float) -> void:
	if _mode_t >= _sit_t:
		# Drop back to a hang from the holding hand, swinging forward.
		var top := _pivot(_g, _i)
		_theta = 0.35
		_psi = 0.0
		_r = HANG_M
		var frame := _hang_frame()
		_tr_c0 = _sit_off
		_tr_b0 = _body_basis(_up, _sit_f, 0.0)
		_tr_c1 = frame[0] - top
		_tr_b1 = frame[1]
		_tr_mid = _sit_f * 0.4 - _up * 0.1
		_tr_len = 0.8
		mode = "drop"
		_mode_t = 0.0


func _voice_step(dt: float) -> void:
	_hooting = maxf(_hooting - dt, 0.0)
	_hoot_t -= dt
	if _hoot_t <= 0.0:
		var calm := mode == "sit" or _pause_t > 0.0
		hoot("song" if calm and _rng.randf() < 0.6 else "hoot")
		_hoot_t = _rng.randf_range(12.0, 28.0)


## Call: "hoot" (a few contact notes) or "song" (the great call).
func hoot(kind := "hoot") -> void:
	var s := GibbonHoot.stream(kind, _rng.randi_range(0, GibbonHoot.VARIANTS - 1))
	if s == null or voice == null:
		return
	voice.stream = s
	voice.pitch_scale = _rng.randf_range(0.95, 1.06)
	voice.play()
	_hooting = s.get_length() / voice.pitch_scale
	stats.hoots += 1


# --- Posing ---------------------------------------------------------------------

## The body's orientation: its long axis along `y` (center of mass toward
## the shoulders), facing `facing` as nearly as it can, leaning `lean`
## (radians, positive: the top toward the body's left).
func _body_basis(y: Vector3, facing: Vector3, lean: float) -> Basis:
	var yy := y.normalized()
	var f := facing - yy * facing.dot(yy)
	if f.length_squared() < 1e-6:
		f = _fwd - yy * _fwd.dot(yy)
		if f.length_squared() < 1e-6:
			f = yy.cross(Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.FORWARD)
	f = f.normalized()
	var x := f.cross(yy)
	var b := Basis(x, yy, x.cross(yy))
	return b * Basis(Vector3.BACK, lean)


## The hanging body: center of mass and orientation under the grip. The
## holding arm can't stretch past ARM_MAX, so the body hangs no lower
## than the arm reaches.
func _hang_frame() -> Array:
	var d := _swing_dirs()[0]
	var c := _pivot(_g, _i) + d * _r
	var b := _body_basis(-d, _face.rotated(_up, _twist), _lean)
	var hp := _hand_point(_g, _i)
	var sh := c + b * _shoulder_local(_hand)
	var over := sh.distance_to(hp) - ARM_MAX
	if over > 0.0:
		c += (hp - sh).normalized() * over
	return [c, b]


## A shoulder in the body's frame, with the chest's bend (GibbonRig).
func _shoulder_local(s: int) -> Vector3:
	var sh := GibbonBody.shoulder(s)
	var ch := _rig.chest if _rig else Vector3.ZERO
	if ch == Vector3.ZERO:
		return sh
	return GibbonBody.CHEST_AT + Basis.from_euler(ch) * (sh - GibbonBody.CHEST_AT)


func _pose(dt: float) -> void:
	var c := _com
	var b := _body_b
	var k := clampf(dt * 5.0, 0.0, 1.0)
	match mode:
		"hang", "turn":
			_lean = move_toward(_lean, LEAN * (1.0 if _hand == 1 else -1.0), dt * 2.0)
			_twist = move_toward(_twist, -TWIST * (1.0 if _hand == 1 else -1.0), dt * 2.0)
			var turn := _face.signed_angle_to(_fwd, _up)
			_face = _face.rotated(_up, clampf(turn, -dt * 4.0, dt * 4.0)).normalized()
			var frame := _hang_frame()
			c = frame[0]
			b = frame[1]
		"fly":
			c = _fly_com()
			var u := smoothstep(0.0, 1.0, _fl_t / maxf(_fl_len, 1e-3))
			b = Basis(_fl_b0.get_rotation_quaternion().slerp(_fl_b1.get_rotation_quaternion(), u))
		"pull_up", "drop":
			# Up in front of the wood and onto it, or back down: a curve
			# through the control point.
			var u := smoothstep(0.0, 1.0, _mode_t / _tr_len)
			var a := _tr_c0.lerp(_tr_mid, u)
			c = _pivot(_g, _i) + a.lerp(_tr_mid.lerp(_tr_c1, u), u)
			b = Basis(_tr_b0.get_rotation_quaternion().slerp(_tr_b1.get_rotation_quaternion(), u))
		"sit":
			c = _pivot(_g, _i) + _sit_off
			b = _body_basis(_up, _sit_f, 0.0)
	_com = c
	_body_b = b.orthonormalized()
	global_transform = Transform3D(_body_b, _com)
	if _built:
		_pose_rig(dt, k)


## The rig's targets (skeleton space) for this frame.
func _pose_rig(dt: float, k: float) -> void:
	var inv := Transform3D(_body_b, _com).affine_inverse()
	var bt := _body_b.transposed()
	var fwd_b := bt * _face.rotated(_up, _twist)
	for s in 2:
		_let_t[s] += dt
		var sx := 1.0 if s == 1 else -1.0
		var shoulder := GibbonBody.shoulder(s)
		var target := Vector3.ZERO
		var pole := Vector3(sx * 0.8, -0.1, 0.5)
		var palm := Vector3(0, 0, -1)
		var curl := 1.0
		var holding := false
		match mode:
			"hang", "turn":
				holding = s == _hand
			"pull_up", "drop":
				holding = s == _hand
			"sit":
				holding = true
		if holding:
			var wood_p := _sit_hand(s) if mode == "sit" else _hand_point(_g, _i)
			target = inv * wood_p
			palm = bt * _grip_palm(wood_p, s)
			if mode == "sit":
				# Long arms folded beside the hips, elbows back and up.
				pole = Vector3(sx * 0.35, 0.45, 0.8)
		else:
			# Free: reaching for the next handhold (or the wood it will sit
			# on), or hanging loose.
			var loose := shoulder + Vector3(sx * 0.1, -0.52, -0.12 + 0.12 * sin(_swing_clock * 1.3 + s))
			var reach_w := 0.0
			var reach_p := Vector3.ZERO
			if mode == "fly":
				var u := clampf(_fl_t / maxf(_fl_len, 1e-3), 0.0, 1.0)
				if s == _hand:
					# The hand that let go trails behind and up.
					loose = shoulder + (-fwd_b * 0.4 + Vector3(sx * 0.35, 0.5, 0.0)).normalized() * 0.56
				else:
					loose = shoulder + (fwd_b * 0.35 + Vector3(sx * 0.25, 0.4, 0.0)).normalized() * 0.58
					reach_p = inv * _hand_point(_tg, _ti)
					reach_w = smoothstep(0.1, 1.0, u)
			elif mode == "pull_up" or mode == "drop":
				var u := _mode_t / _tr_len
				reach_p = inv * _sit_hand(s)
				reach_w = smoothstep(0.25, 0.75, u) if mode == "pull_up" else 1.0 - smoothstep(0.0, 0.5, u)
			elif _tg != null and (mode == "hang" or mode == "turn") and _pause_t <= 0.0:
				reach_p = inv * _hand_point(_tg, _ti)
				var sh_scene := _com + _body_b * shoulder
				var dist := sh_scene.distance_to(_hand_point(_tg, _ti))
				reach_w = 1.0 - smoothstep(0.7, 1.9, dist)
				if not _plan.is_empty() and not _plan.contact:
					# Wind up for the throw: reach forward on the forward swing.
					var th: float = _plan.theta
					reach_w = maxf(reach_w, 0.75 * smoothstep(th - 1.2, th, _theta) * (1.0 if _omega > 0.0 else 0.4))
				loose = shoulder + (fwd_b * 0.45 + Vector3(sx * 0.2, 0.25, 0.0)).normalized() * 0.55
			# The loose pose eases from one to the next; a reach is exact.
			if _loose[s] == Vector3.ZERO:
				_loose[s] = loose
			_loose[s] = _loose[s].lerp(loose, clampf(dt * 7.0, 0.0, 1.0))
			target = _loose[s].lerp(reach_p, reach_w) if reach_w > 0.0 else _loose[s]
			pole = Vector3(sx * 0.7, -0.5, 0.35)
			palm = Vector3(-sx * 0.3, -0.2, -1.0).normalized()
			curl = lerpf(0.45, 0.15, reach_w)
			if mode == "fly" and s != _hand:
				curl = lerpf(0.15, 1.0, smoothstep(0.8, 1.0, _fl_t / maxf(_fl_len, 1e-3)))
				if reach_w > 0.9:
					palm = bt * _grip_palm(_hand_point(_tg, _ti), s)
		# A hand that just let go eases from the wood to its new pose.
		if not holding and _let_t[s] < 0.3:
			target = (inv * _let_from[s]).lerp(target, smoothstep(0.0, 0.3, _let_t[s]))
		_rig.grip[s] = target
		_rig.pole[s] = pole
		_rig.palm[s] = palm
		_rig.curl[s] = curl
	_pose_legs_head(dt, k, fwd_b)


## The palm faces the wood from the body's side, square to the hand.
func _grip_palm(wood_p: Vector3, s: int) -> Vector3:
	var g := _tg if (mode == "fly" and s != _hand) else _g
	var i := _ti if (mode == "fly" and s != _hand) else _i
	var t := g.dir(i)
	var sh := _com + _body_b * GibbonBody.shoulder(s)
	var hand := (wood_p - sh).normalized()
	var p := hand.cross(t)
	if p.length_squared() < 1e-6:
		return _fwd
	p = p.normalized()
	return p if p.dot(_face.rotated(_up, _twist)) >= 0.0 else -p


## Where a sitting hand rests on the wood: the holding hand at the grip,
## the other a little along the wood on the far side of the body.
func _sit_hand(s: int) -> Vector3:
	var p := _hand_point(_g, _i)
	if s == _hand:
		return p
	var along := _horizontal(_g.dir(_i)).normalized()
	var x := _sit_f.cross(_up)
	if along.dot(x) < 0.0:
		along = -along
	var sx := 1.0 if s == 1 else -1.0
	return p + along * (0.26 * sx)


func _pose_legs_head(dt: float, k: float, fwd_b: Vector3) -> void:
	# [hip flex, splay, knee, ankle] the legs want now.
	var want := [0.35, 0.12, 0.55, 0.25]
	var chest := Vector3(0.06, 0.0, 0.0)
	match mode:
		"hang", "turn":
			if _pause_t > 0.0 or _tg == null:
				var sway := 0.08 * sin(_swing_clock * 1.7)
				want = [0.3 + sway, 0.12, 0.5 - sway, 0.25]
			else:
				# Tucked, tucking tighter through the bottom of the swing.
				var amp := maxf(_amplitude(), 0.2)
				var low := 1.0 - clampf(absf(_theta) / amp, 0.0, 1.0)
				want = [0.9 + 0.45 * low, 0.2, 1.1 + 0.5 * low, 0.3]
				chest = Vector3(0.1 * low, 0.0, 0.0)
		"fly":
			var u := clampf(_fl_t / maxf(_fl_len, 1e-3), 0.0, 1.0)
			want = [1.3 - 0.4 * u, 0.28, 1.6 - 0.6 * u, 0.35]
			chest = Vector3(-0.12, 0.0, 0.0)
		"pull_up", "drop", "sit":
			var u := 1.0
			if mode == "pull_up":
				u = smoothstep(0.2, 1.0, _mode_t / _tr_len)
			elif mode == "drop":
				u = 1.0 - smoothstep(0.0, 0.6, _mode_t / _tr_len)
			want = [lerpf(0.9, 1.45, u), lerpf(0.15, 0.35, u), lerpf(1.1, 1.55, u), 0.3]
			chest = Vector3(lerpf(0.1, 0.18, u), 0.0, 0.0)
	var kl := clampf(dt * 8.0, 0.0, 1.0)
	for s in 2:
		for j in 4:
			_legs[s * 4 + j] = lerpf(_legs[s * 4 + j], float(want[j]), kl)
		_rig.hip_flex[s] = _legs[s * 4]
		_rig.hip_splay[s] = _legs[s * 4 + 1]
		_rig.knee[s] = _legs[s * 4 + 2]
		_rig.ankle[s] = _legs[s * 4 + 3]
	_rig.chest = _rig.chest.lerp(chest, k)
	# The head: toward the next handhold, round about when it rests, up
	# while it calls.
	var bt := _body_b.transposed()
	var look := fwd_b
	if _tg != null and (mode == "fly" or _pause_t <= 0.0):
		look = bt * (_hand_point(_tg, _ti) - (_com + _body_b * Vector3(0, 0.28, 0))).normalized()
	elif mode == "sit" or _pause_t > 0.0:
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = _rng.randf_range(1.2, 3.0)
			_look = Vector3(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.3, 0.35), -1.0).normalized()
		look = _look
	if _hooting > 0.0:
		look = (fwd_b + Vector3(0, 0.9, 0)).normalized()
	_rig.look = _rig.look.lerp(look, clampf(dt * 6.0, 0.0, 1.0)) if _rig.look != Vector3.ZERO else look


# --- Blob shadow ----------------------------------------------------------------

## A soft shadow under it only when it's within BLOB_H of the ground (a
## ray down against the world's layer; tree trunks don't count).
func _blob_step(dt: float) -> void:
	_blob_t -= dt
	if _blob_t > 0.0 or not is_inside_tree():
		return
	_blob_t = 0.1
	var from := _com
	var q := PhysicsRayQueryParameters3D.create(from, from - _up * (BLOB_H + 0.5), 1)
	if _hit and _hit.body:
		q.exclude = [_hit.body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var show := not hit.is_empty()
	if show and hit.collider is CollisionObject3D and (hit.collider as CollisionObject3D).collision_layer & TerrainChunk.TREE_LAYER:
		show = false
	var h := 0.0
	if show:
		# From its lowest point (feet or seat), not its middle.
		h = from.distance_to(hit.position) - 0.4
		show = h < BLOB_H
	_blob.visible = show
	if show:
		var kk := clampf(1.0 - h / BLOB_H, 0.05, 1.0)
		var f := _horizontal(_fwd).normalized()
		_blob_anchor.global_transform = Transform3D(Basis.looking_at(f, _up), hit.position)
		_blob.scale = Vector3(0.2 * kk + 0.04, 1.0, 0.24 * kk + 0.04)


# --- Debug drawing --------------------------------------------------------------

## Lines drawn over everything: the route ahead (green), the handholds it
## weighed at its last choice (teal ticks), the handholds it caught
## (orange), its next one (magenta), its planned throw (white) and its
## last flights (yellow), and the pendulum from grip to center of mass.
func _draw_debug() -> void:
	if _dbg_mi == null:
		_dbg_im = ImmediateMesh.new()
		_dbg_mi = MeshInstance3D.new()
		_dbg_mi.name = "Debug"
		_dbg_mi.top_level = true
		_dbg_mi.mesh = _dbg_im
		_dbg_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 10
		_dbg_mi.material_override = m
		add_child(_dbg_mi)
	_dbg_mi.visible = true
	_dbg_mi.global_transform = Transform3D.IDENTITY
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _com + _up * 5.0
	var im := _dbg_im
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.3, 1.0, 0.4)
	var teal := Color(0.3, 0.9, 1.0)
	var orange := Color(1.0, 0.55, 0.1)
	var magenta := Color(1.0, 0.2, 0.9)
	var yellow := Color(1.0, 0.95, 0.2)
	var white := Color(1.0, 1.0, 1.0)
	for kk in range(_route_k, _route.size() - 1):
		_ribbon(im, eye, _pivot(_route[kk][0], _route[kk][1]), _pivot(_route[kk + 1][0], _route[kk + 1][1]), 0.025, green)
	for c in _dbg_cands:
		_cross(im, eye, c[0], 0.07, teal)
	for p in _dbg_picks:
		_cross(im, eye, p, 0.16, orange)
	for arc in _dbg_arcs:
		for kk in arc.size() - 1:
			_ribbon(im, eye, arc[kk], arc[kk + 1], 0.035, yellow)
	for kk in _dbg_pred.size() - 1:
		if kk % 2 == 0:
			_ribbon(im, eye, _dbg_pred[kk], _dbg_pred[kk + 1], 0.03, white)
	if _tg != null:
		_cross(im, eye, _pivot(_tg, _ti), 0.28, magenta)
	if mode == "hang" or mode == "turn":
		_ribbon(im, eye, _pivot(_g, _i), _com, 0.02, yellow)
	im.surface_end()


static func _ribbon(im: ImmediateMesh, eye: Vector3, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var dir := b - a
	if dir.length_squared() < 1e-8:
		return
	var side := dir.cross(eye - a).normalized() * (w * maxf(1.0, eye.distance_to(a) * 0.08))
	im.surface_set_color(col)
	for p in [a - side, a + side, b + side, a - side, b + side, b - side]:
		im.surface_add_vertex(p)


static func _cross(im: ImmediateMesh, eye: Vector3, p: Vector3, s: float, col: Color) -> void:
	var to_eye := (eye - p).normalized()
	var u := to_eye.cross(Vector3.UP if absf(to_eye.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := to_eye.cross(u)
	_ribbon(im, eye, p - u * s, p + u * s, 0.02, col)
	_ribbon(im, eye, p - v * s, p + v * s, 0.02, col)


func _on_origin_shifted(offset: Vector3) -> void:
	for a in _dbg_arcs.size():
		var arc: PackedVector3Array = _dbg_arcs[a]
		for kk in arc.size():
			arc[kk] -= offset
		_dbg_arcs[a] = arc
	for kk in _dbg_picks.size():
		_dbg_picks[kk] -= offset
	for kk in _dbg_pred.size():
		_dbg_pred[kk] -= offset
	for c in _dbg_cands:
		c[0] -= offset
	for h in 2:
		_let_from[h] -= offset
	_com -= offset

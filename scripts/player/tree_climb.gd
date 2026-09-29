class_name TreeClimb
extends RefCounted
## The player on a tree's branch graph (spec Phase 1 (ii)): climbing the
## trunk hand over hand and shimmying out along thick limbs, slowly and
## with effort, never swinging, never leaping. TreeContact owns one;
## PlanetPlayer drives it while it climbs a tree that has a graph and puts
## the body and the hands where it says.
##
## Two hands, each on a hold: a handhold of the graph (BranchGraph, wood at
## least GRIP_R_M thick) and, on a trunk or other steep wood, an angle
## round it. One hand moves at a time: on steep wood a reach takes the
## rear hand past the front one to the next hold the way you push (hand
## over hand); along a limb and round a trunk the hands shuffle instead,
## never crossing. The body follows the middle of the hands. After each reach comes a beat before the next: the effort is
## in that rhythm (no stamina meter); `let_go` and `took` tell TreeContact
## when to breathe and when the bark rasps under a hand.
##
## Controls (PlanetPlayer passes the stick and the camera's heading):
##   trunk   W/S up and down the trunk's handholds, which follow its lean
##           and bend; A/D round it. Where a limb forks off on your side,
##           pushing toward it (the camera looking out along it) takes you
##           onto it.
##   limb    push along it (camera-relative) to shimmy out or back in; push
##           toward another limb of the tree within REACH_M to reach across
##           to it; A/D go round it (over the top, down its side, under
##           it), and you stay on that side as you shimmy along. You hang under wood thinner than STRADDLE_R_M and
##           straddle thicker, flatter wood; you stop where the wood gets
##           thinner than a grip.
## Holds are kept in the tree's own frame (BranchGraph.local), so neither
## the floating origin nor the chunk disturbs them; `key` finds the tree's
## graph again if it is rebuilt (the same tree, the same handholds).

## Wood the player can hold (radius, m): BranchGraphView's green.
const GRIP_R_M := 0.06
## Reaching across to another limb: handholds this near the hand (m).
const REACH_M := 1.2
## The body's speed while a reach is under way (m/s) and the beat after
## each reach (s): with a handhold every ~0.5 m, about 0.5 m/s up a trunk
## and about 0.3 m/s along a limb (the hands shuffle there, so the body
## moves on every other reach).
static var TRUNK_MPS := Tuning.num("movement", "climb", "graph_trunk_mps")
static var LIMB_MPS := Tuning.num("movement", "climb", "graph_limb_mps")
static var TRUNK_BEAT_S := Tuning.num("movement", "climb", "trunk_beat_s")
static var LIMB_BEAT_S := Tuning.num("movement", "climb", "limb_beat_s")
static var MIN_REACH_S := Tuning.num("movement", "climb", "min_reach_s")
## A reach round the trunk moves the body about this far (m).
const AROUND_M := 0.45
## The hands on the trunk sit this far apart (m of bark).
const HANDS_APART_M := 0.24
## Wood steeper than this (|tangent . up|) is climbed like a trunk.
const CLING_SLOPE := 0.7
## Body: shoulder height over the feet and arm length (PlayerBody, at the
## player's scale); the body's middle off the bark when hugging steep
## wood, how far the hands are over the shoulders then and when hanging
## (m).
static var SHOULDER_Y := PlayerBody.SHOULDER_Y * PlanetPlayer.BODY_K
static var ARM_M := PlayerBody.ARM_M * PlanetPlayer.BODY_K
const HUG_M := 0.26
const TRUNK_REACH_Y := 0.3
const HANG_REACH_Y := 0.5
## Straddling: wood at least this thick and no steeper than STRADDLE_SLOPE;
## the hips over the feet and the hands ahead of the hips (m).
const STRADDLE_R_M := 0.08
const STRADDLE_SLOPE := 0.55
const HIP_Y := 0.85
const STRADDLE_AHEAD_M := 0.2
## Along a limb the hands shuffle: the rear hand catches up to the front
## one when they are further apart than this (m).
const CATCH_UP_M := 0.3
## Each reach carries the moving hand at least this far the way you push.
const MIN_GAIN_M := 0.1
## Going down, the hands stop this high over the tree's foot (m): lower,
## you step off.
const LOWEST_HOLD_M := 1.3

var key := 0
var g: BranchGraph
## "trunk" (hugging steep wood), "hang" or "straddle".
var pose := "trunk"
## Per hand (0 left, 1 right): the handhold it holds and its angle round
## the wood (steep wood; radians, in the tree frame).
var hold := PackedInt32Array([-1, -1])
var angle := PackedFloat32Array([0.0, 0.0])
## The hand in the air (-1: none).
var reaching := -1
## The hand that took the last hold: its wood sets the pose.
var lead := 1
## Reaches made, and a line per hold taken (tests).
var reaches := 0
var holds_log: Array[String] = []
## This step: the hand that let go / took hold (-1: none), for sounds.
var let_go := -1
var took := -1
## What the HUD shows while climbing.
var prompt := ""
## Climbing speed as a share of normal (1; less when overburdened,
## PlanetPlayer.burden_climb()).
var speed_scale := 1.0
## Outputs, scene space: where the feet go, which way the body faces
## (horizontal), where each hand is, which way a push-off goes.
var feet := Vector3.ZERO
var facing := Vector3.FORWARD
var hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var push_dir := Vector3.FORWARD

# The reach under way: where the hand set off from (tree frame), its new
# hold, how far along (0..1) and over how long (s); the beat after it.
var _from := Vector3.ZERO
var _to_i := -1
var _to_a := 0.0
var _u := 0.0
var _len := 0.0
var _beat := 0.0
# The way along a limb it last moved (tree frame, horizontal): it faces
# that way hanging or straddling.
var _along := Vector3.FORWARD
var _up_l := Vector3.UP
# The way the body faces (tree frame, horizontal).
var _face_l := Vector3.FORWARD
# Round a limb (from play: wood thick enough to climb is thick enough to
# go round): where you are round it, radians from its top (0 on top, PI
# underneath); NAN until A/D first takes you round, then kept as you
# shimmy along; back to NAN on steep wood.
var _limb_rel := NAN
# The way the stick is taking the hands (tree frame), and the stick then.
var _dir := Vector3.ZERO
var _dir_input := Vector2.ZERO


## Take hold of handhold `i` of `graph` (E at a trunk), from where the
## player stands (`player_pos`, scene). On steep wood the other hand holds
## the handhold below, if there is one.
func start(graph: BranchGraph, i: int, player_pos: Vector3, up: Vector3) -> void:
	g = graph
	key = graph.key
	var f := g.frame()
	_up_l = (f.basis.inverse() * up).normalized()
	var p := f.affine_inverse() * player_pos
	reaching = -1
	_beat = 0.0
	reaches = 0
	holds_log.clear()
	lead = 1
	_limb_rel = NAN
	if _cling(i):
		var a := _angle_of(i, p)
		var d := HANDS_APART_M * 0.5 / maxf(g.radius[i], 0.1)
		var below := _next_along(i, -1.0)
		hold = PackedInt32Array([below if below >= 0 and g.local[below].dot(_up_l) > LOWEST_HOLD_M else i, i])
		angle = PackedFloat32Array([a - d, a + d])
	else:
		hold = PackedInt32Array([i, i])
		angle = PackedFloat32Array([0.0, 0.0])
		_along = _horizontal(g.tangent[i])
		if _along.length() < 0.1:
			_along = _horizontal(g.local[i])
		_along = _along.normalized() if _along.length() > 1e-3 else Vector3.FORWARD
	holds_log.append("grab %s" % describe(i))
	_update_outputs(f, up)


## One step: `input` the move stick (x right, y forward), `fwd` and `right`
## the camera's horizontal heading (scene). Returns "" while holding on,
## "drop" when you climbed down to the foot of the tree (step off), "lost"
## if the tree is gone.
func step(dt: float, input: Vector2, fwd: Vector3, right: Vector3, up: Vector3) -> String:
	let_go = -1
	took = -1
	var now := BranchGraphs.find(key)
	if now != null and now != g and now.valid():
		g = now
	if g == null or not g.valid():
		return "lost"
	var f := g.frame()
	var inv := f.basis.inverse()
	_up_l = (inv * up).normalized()
	prompt = ""
	if reaching >= 0:
		_u += dt / _len
		if _u >= 1.0:
			hold[reaching] = _to_i
			angle[reaching] = _to_a
			lead = reaching
			took = reaching
			reaching = -1
			reaches += 1
			_beat = (TRUNK_BEAT_S if _cling(_to_i) else LIMB_BEAT_S) / speed_scale
			holds_log.append("hand %s -> %s" % ["L" if took == 0 else "R", describe(_to_i)])
	elif _beat > 0.0:
		_beat -= dt
	elif input.length() > 0.3:
		var move := _choose(input, inv * fwd, inv * right)
		if move.size() == 1:
			return move[0]
		if move.size() == 3:
			_start_reach(move[0], move[1], move[2])
	_update_outputs(f, up)
	if prompt == "":
		var ph := perch_hold()
		var perch := (" · Shift perch" if perch_on_top(ph) else " · Shift duck") if ph >= 0 else ""
		if pose == "trunk":
			prompt = "W/S climb · A/D round · push toward a limb to take it%s · E let go · Space push off" % perch
		else:
			prompt = "Push along the limb to shimmy, toward another to reach across%s · E let go · Space push off" % perch
	return ""


## The wood you could perch on from where you are (design §V; from play:
## Shift perches or ducks anywhere in a tree): whatever you hold, once a
## reach has landed. On a limb or branch you sit on top of it; on the
## trunk or steep wood you tuck in against it (perch_on_top()). The
## handhold, or -1.
func perch_hold() -> int:
	if reaching >= 0 or g == null:
		return -1
	var i := hold[lead]
	return i if i >= 0 else -1


## Perching at handhold `i` sits on top of it (a limb, flattish wood) rather
## than tucking in against it (the trunk, steep wood).
func perch_on_top(i: int) -> bool:
	if _round(i):
		return absf(_limb_rel) < 0.9
	return not _cling(i) or (g.limb[i] == 0 and _next_along(i, 1.0) < 0)


## A handhold in words, for the log: its number, trunk or limb, how thick
## and how high over the tree's foot.
func describe(i: int) -> String:
	return "%d (%s, r %.2f m, %.1f m up)" % [i, "trunk" if g.limb[i] == 0 else "limb %d" % g.limb[i], g.radius[i], g.local[i].dot(_up_l)]


## How far a hand is from the wood it holds (m, scene), for tests: 0 on
## the bark (or on the top of the wood).
func hand_on_wood(h: int, scene_p: Vector3) -> float:
	if h == reaching:
		return 0.0
	var p := g.frame().affine_inverse() * scene_p
	var i := hold[h]
	var d := p - g.local[i]
	var t := g.tangent[i]
	var radial := (d - t * d.dot(t)).length()
	return absf(radial - g.radius[i])


# --- Choosing a reach -------------------------------------------------------------

## The reach the stick asks for: [hand, handhold, angle], or ["drop"], or
## [] (nothing that way; `prompt` says why).
##
## The stick and the camera give a direction in the tree's frame (kept
## while you hold the stick the same way): on the trunk, up (W) or down
## (S) blended with where the camera looks, so W climbs while you face the
## trunk and takes the limb you look out along at a fork; on a limb, the
## way you push across the ground (W with a little up). Every reach must
## carry the moving hand at least MIN_GAIN_M further that way, so the
## hands can't go back and forth while you hold the stick.
func _choose(input: Vector2, fwd_l: Vector3, right_l: Vector3) -> Array:
	var screen := _horizontal(fwd_l * input.y + right_l * input.x)
	screen = screen.normalized() if screen.length() > 1e-3 else Vector3.ZERO
	var li := hold[lead]
	# (Steep wood, a stem out of a fork or an upright limb, climbs like
	# the trunk: W up it.)
	var on_trunk := g.limb[li] == 0 or _cling(li) or (pose == "trunk" and g.limb[hold[1 - lead]] == 0)
	var tup := g.tangent[li] if g.tangent[li].dot(_up_l) >= 0.0 else -g.tangent[li]
	var dir: Vector3
	# Looking out from the trunk (not at it), W goes out that way: onto a
	# limb there; else up.
	var out_l := _horizontal(_around(li, _body_angle())) if _cling(li) else Vector3.ZERO
	var looking_out := on_trunk and out_l.length() > 1e-3 and screen.dot(out_l.normalized()) > 0.3
	if looking_out:
		dir = screen + tup * 0.25 * input.y
	elif on_trunk and absf(input.x) > 0.3 and absf(input.y) > 0.3:
		# A diagonal: the reach is up (or down) the wood, and the swing
		# round it comes below; aimed sideways, it stepped off onto a limb.
		dir = tup * signf(input.y) + screen * 0.3
	elif on_trunk:
		dir = tup * input.y + screen * 1.2
	else:
		dir = screen + _up_l * input.y * 0.4
	if dir.length() < 1e-3:
		return []
	dir = dir.normalized()
	# Hold the direction while the stick and the camera stay put.
	if _dir.dot(dir) > 0.95 and _dir_input.dot(input.normalized()) > 0.95:
		dir = _dir
	else:
		_dir = dir
		_dir_input = input.normalized()
	# At the foot of the trunk, down steps off.
	if on_trunk and input.y < -0.3 and absf(input.y) >= absf(input.x):
		var low := 0 if g.local[hold[0]].dot(_up_l) <= g.local[hold[1]].dot(_up_l) else 1
		if g.limb[hold[low]] == 0:
			var j := _next_along(hold[low], -1.0)
			if j < 0 or g.local[j].dot(_up_l) < LOWEST_HOLD_M:
				return ["drop"]
	# Round a limb: A/D (more than W/S) takes you round it, over the top,
	# down its side, underneath.
	# (A diagonal, W and D alike, goes along the limb.)
	if not on_trunk and absf(input.x) > 0.3 and absf(input.x) > absf(input.y) + 0.2:
		return _round_limb(input.x, right_l)
	var move := _toward(dir, on_trunk)
	if move.is_empty() and looking_out and input.y > 0.3:
		move = _toward(tup, on_trunk)
	# Up the trunk and nothing that way (the trunk ends at a fork, or thins
	# out under the crown): carry on up whatever goes on up from here, the
	# stem or limb that climbs most steeply, whichever side it leaves on
	# (from play: at a fork W used to stop dead).
	if move.is_empty() and on_trunk and input.y > 0.3:
		move = _upward()
	# Down the same way: from a limb's foot back onto the trunk, or down
	# whatever goes on down from here.
	if move.is_empty() and on_trunk and input.y < -0.3:
		move = _upward(-1.0)
	# Diagonal on steep wood (W and D together, and the other three): the
	# reach up or down also swings round the wood toward that side, so you
	# spiral up and round in one move (from play).
	if not move.is_empty() and move.size() == 3 and on_trunk and absf(input.x) > 0.3 and absf(input.y) > 0.3:
		var j: int = move[1]
		if _cling(j):
			var ba := _body_angle()
			var rightward := (_around(li, ba + 0.1) - _around(li, ba)).dot(right_l)
			var sgn := signf(input.x) * (1.0 if rightward >= 0.0 else -1.0)
			move[2] = float(move[2]) + sgn * AROUND_M * 3.0 / (maxf(g.radius[j], 0.1) + HUG_M)
	if not move.is_empty():
		return move
	# Round the trunk: the hand on that side goes first, the other follows
	# up beside it (they never cross).
	if on_trunk and absf(input.x) > 0.3 and absf(input.x) >= absf(input.y) and _cling(li):
		# Which way round the angle goes on screen: D always takes you to
		# the camera's right, A to its left, whichever way the wood's
		# angle runs. The hand furthest that way leads.
		var ba := _body_angle()
		var rightward := (_around(li, ba + 0.1) - _around(li, ba)).dot(right_l)
		var sgn := signf(input.x) * (1.0 if rightward >= 0.0 else -1.0)
		var lead_h := 1 if wrapf(angle[1] - angle[0], -PI, PI) * sgn >= 0.0 else 0
		var i := hold[lead_h]
		if not _cling(i):
			return []
		var r := maxf(g.radius[i], 0.1)
		var apart := angle[lead_h] - angle[1 - lead_h]
		var close := HANDS_APART_M / r
		if apart * sgn > close * 1.2 or hold[1 - lead_h] != i:
			return [1 - lead_h, i, angle[lead_h] - sgn * close]
		return [lead_h, i, angle[lead_h] + sgn * AROUND_M * 2.0 / (r + HUG_M)]
	if prompt == "" and on_trunk and input.y > 0.3:
		prompt = "The trunk is too thin to climb any higher: push toward a limb"
	return []


## The best reach the way `dir` goes (tree frame, unit): on steep wood the
## rear hand reaches past the front one (hand over hand); along a flatter
## limb the hands shuffle (the rear one catches up, then the front one
## reaches on). The new hold: along the wood, across a fork onto a limb (on
## your side of a trunk), or across the air to another limb within REACH_M.
## [] if there's none.
func _toward(dir: Vector3, on_trunk: bool) -> Array:
	var p: Array[Vector3] = [_hand_point(0), _hand_point(1)]
	var a0 := p[0].dot(dir)
	var a1 := p[1].dot(dir)
	var front := 0 if a0 > a1 + 0.02 else (1 if a1 > a0 + 0.02 else _side_hand(dir))
	var rear := 1 - front
	var shuffle := not _cling(hold[front])
	if shuffle and hold[front] != hold[rear] and (p[front] - p[rear]).length() > CATCH_UP_M:
		return [rear, hold[front], angle[front]]
	var mover := front if shuffle else rear
	if not shuffle and hold[0] == hold[1]:
		mover = 1 - lead
	var out := _horizontal(_around(hold[front], _body_angle())).normalized() if _cling(hold[front]) else Vector3.ZERO
	var base := hold[front]
	var linked := g.links[base]
	var best := []
	var best_s := -INF
	var thin := false
	for j in _reachable(base, true):
		if j == hold[0] or j == hold[1]:
			continue
		var is_link := linked.has(j)
		var same := g.limb[j] == g.limb[base]
		var a := _hold_angle(j, p[front])
		if same and _cling(j) and _cling(hold[mover]):
			# Up or down steep wood: to the mover's own side.
			var d := HANDS_APART_M * 0.5 / maxf(g.radius[j], 0.1)
			a = _body_angle() + (d if mover == 1 else -d)
		var q := _point(j, a, mover)
		if (q - p[mover]).dot(dir) < MIN_GAIN_M:
			continue
		var s := (g.local[j] - g.local[base]).normalized().dot(dir)
		if same:
			s += 0.1
		else:
			# (Not back onto the trunk sideways or up; down a steep limb
			# to its foot, yes: onto the trunk it grows from.)
			if on_trunk and g.limb[j] == 0 and dir.dot(_up_l) > -0.3:
				continue
			# Onto a limb from a trunk: one on your side, the way it leads.
			if out != Vector3.ZERO and g.limb[j] != 0:
				var way := _horizontal(g.local[j] - g.local[base]) + (_horizontal(g.tangent[j]) if is_link else Vector3.ZERO)
				if way.length() > 0.02 and way.normalized().dot(out) < -0.1:
					continue
				if is_link and way.length() > 0.3:
					s = maxf(s, way.normalized().dot(dir))
			s -= 0.05 if is_link else 0.15
		if s < (0.3 if is_link else 0.5):
			continue
		if g.radius[j] < GRIP_R_M:
			thin = thin or (is_link and same)
			continue
		if s > best_s:
			best_s = s
			best = [mover, j, a]
	if best.is_empty() and thin:
		prompt = "Too thin to hold any further out"
	return best


## The steepest way on up (`sgn` 1) or down (-1) from the holds you have:
## a handhold within reach, thick enough to grip, at least UP_ON of the way
## up (down); the other hand reaches for it. [] if there's none.
const UP_ON := 0.35


func _upward(sgn := 1.0) -> Array:
	var p: Array[Vector3] = [_hand_point(0), _hand_point(1)]
	var top := 0 if p[0].dot(_up_l) * sgn >= p[1].dot(_up_l) * sgn else 1
	var base := hold[top]
	var best := []
	var best_s := UP_ON
	for j in _reachable(base, true):
		if j == hold[0] or j == hold[1] or g.radius[j] < GRIP_R_M:
			continue
		var d := g.local[j] - g.local[base]
		if d.length() < 0.05:
			continue
		var s := d.normalized().dot(_up_l) * sgn
		if s > best_s:
			best_s = s
			best = [1 - top, j, _hold_angle(j, p[top])]
	return best


## One step round the limb held (`x` the stick's right, `right_l` the
## camera's right): the other hand reaches round to the new angle, the body
## follows (_pose_of()). [hand, handhold, angle].
func _round_limb(x: float, right_l: Vector3) -> Array:
	var li := hold[lead]
	if is_nan(_limb_rel):
		_limb_rel = 0.0 if pose == "straddle" else PI
	var a_now := _top_angle(li) + _limb_rel
	var rightward := (_around(li, a_now + 0.1) - _around(li, a_now)).dot(right_l)
	var sgn := signf(x) * (1.0 if rightward >= 0.0 else -1.0)
	_limb_rel = wrapf(_limb_rel + sgn * AROUND_M * 2.0 / (maxf(g.radius[li], 0.1) + HUG_M), -PI, PI)
	return [1 - lead, li, _top_angle(li) + _limb_rel]


## The angle round limb handhold `i` of its top (straight up from its axis).
func _top_angle(i: int) -> float:
	var t := g.tangent[i]
	var side := _up_l - t * t.dot(_up_l)
	if side.length_squared() < 1e-6:
		return 0.0
	return _angle_of(i, g.local[i] + side.normalized())


## Round a limb (_limb_rel set): the hold's angle is where you are round it.
func _round(i: int) -> bool:
	return not _cling(i) and not is_nan(_limb_rel)


## The hand on the side of the body that `dir` (tree frame) points to.
func _side_hand(dir: Vector3) -> int:
	return 1 if dir.dot(_face_l.cross(_up_l)) >= 0.0 else 0


## Handholds a hand on `i` can move to: its links along the wood (and
## across forks), and, reaching across, handholds of other limbs within
## REACH_M. Includes thin ones when `thin` (to say they're too thin).
func _reachable(i: int, thin := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	for j in g.links[i]:
		if thin or g.radius[j] >= GRIP_R_M:
			out.append(j)
	var p := g.local[i]
	for j in g.size():
		if g.limb[j] != g.limb[i] and g.radius[j] >= GRIP_R_M and not out.has(j) and g.local[j].distance_to(p) <= REACH_M:
			out.append(j)
	return out


## The next handhold along the same wood from `i`, up (`sgn` > 0: the way
## the wood grows) or down, down from a limb's first handhold back onto
## the wood it forks from; -1 if there's none thick enough.
func _next_along(i: int, sgn: float) -> int:
	var best := -1
	var best_d := -INF
	for pass_i in 2:
		for j in g.links[i]:
			if (g.limb[j] == g.limb[i]) != (pass_i == 0) or g.radius[j] < GRIP_R_M:
				continue
			var d := (g.local[j] - g.local[i]).dot(g.tangent[i]) * sgn
			if d > 0.0 and d > best_d:
				best_d = d
				best = j
		if best >= 0 or sgn > 0.0:
			break
	return best


func _start_reach(h: int, i: int, a: float) -> void:
	var mid0 := (_hand_point(0) + _hand_point(1)) * 0.5
	var to := _point(i, a, h)
	var mid1 := (to + _hand_point(1 - h)) * 0.5
	var steep := _cling(i) and _cling(hold[1 - h])
	_len = maxf(mid0.distance_to(mid1) / ((TRUNK_MPS if steep else LIMB_MPS) * speed_scale), MIN_REACH_S / speed_scale)
	# Along a limb it faces the way it goes.
	if not _cling(i):
		var way := _horizontal(to - _hand_point(1 - h))
		if way.length() > 0.1:
			_along = way.normalized()
	_from = _hand_point(h)
	_to_i = i
	_to_a = a
	_u = 0.0
	reaching = h
	let_go = h


# --- Where things are ---------------------------------------------------------------

func _update_outputs(f: Transform3D, up: Vector3) -> void:
	# Both hands back on steep wood: no longer round a limb.
	if reaching < 0 and _cling(hold[0]) and _cling(hold[1]):
		_limb_rel = NAN
	var p0 := _current_hand(0)
	var p1 := _current_hand(1)
	hands[0] = f * p0
	hands[1] = f * p1
	var mid := (p0 + p1) * 0.5
	var wood := _to_i if reaching >= 0 else hold[lead]
	pose = _pose_of(wood)
	var feet_l: Vector3
	var face_l: Vector3
	var push_l: Vector3
	match pose:
		"trunk":
			# Hugging the wood, off the bark between the hands (which may be
			# on two limbs while one reaches across).
			var ri := wood if (_cling(wood) or _round(wood)) else hold[1 - lead]
			var out := _around(ri, _body_angle())
			var c := mid + out * HUG_M
			# The shoulders under the hands, lower for a hand far above.
			var above := clampf(0.55 - absf((p1 - p0).dot(_up_l)) * 0.5, -0.2, TRUNK_REACH_Y)
			feet_l = c - _up_l * (SHOULDER_Y + above)
			face_l = -_horizontal(out)
			push_l = _horizontal(out)
		"hang":
			# Side on to the wood under it, shoulders along the line of the
			# hands (the right hand on the right), hanging as low as the
			# arms let it with both hands on.
			var half := (p1 - p0) * 0.5
			var half_h := _horizontal(half)
			var drop := sqrt(maxf(ARM_M * ARM_M - pow(maxf(half_h.length() - 0.205, 0.0), 2.0), 0.0)) - absf(half.dot(_up_l))
			feet_l = mid - _up_l * (SHOULDER_Y + clampf(drop, 0.05, HANG_REACH_Y))
			face_l = _face_l
			if half_h.length() > 0.12:
				face_l = _up_l.cross(half_h).normalized()
			push_l = -face_l
		_:
			var hips := mid - _along * STRADDLE_AHEAD_M
			feet_l = hips - _up_l * HIP_Y
			face_l = _along
			push_l = _along.cross(_up_l)
	feet = f * feet_l
	if face_l.length() > 1e-3:
		_face_l = face_l.normalized()
		facing = (f.basis * _face_l).normalized()
	if push_l.length() > 1e-3:
		push_dir = (f.basis * push_l).normalized()
	facing -= up * facing.dot(up)
	push_dir -= up * push_dir.dot(up)


func _pose_of(i: int) -> String:
	if _cling(i):
		return "trunk"
	if _round(i):
		# Round a limb: astride it on top, hanging under it, hugging its
		# side between.
		var r := absf(_limb_rel)
		if r < 0.9:
			return "straddle"
		if r > 2.3:
			return "hang"
		return "trunk"
	if g.radius[i] >= STRADDLE_R_M and absf(g.tangent[i].dot(_up_l)) < STRADDLE_SLOPE:
		return "straddle"
	return "hang"


## Is handhold `i` on the trunk or wood as steep, climbed hugging it?
func _cling(i: int) -> bool:
	return g.limb[i] == 0 or absf(g.tangent[i].dot(_up_l)) > CLING_SLOPE


## A hand now (tree frame): on its hold, or on its way to the next one,
## lifted clear of the bark in between.
func _current_hand(h: int) -> Vector3:
	if h != reaching:
		return _hand_point(h)
	var u := smoothstep(0.0, 1.0, _u)
	var to := _point(_to_i, _to_a, h)
	var lift := _around(_to_i, _to_a) if _cling(_to_i) else _up_l
	return _from.lerp(to, u) + lift * (0.1 * sin(u * PI))


func _hand_point(h: int) -> Vector3:
	return _point(hold[h], angle[h], h)


## Where hand `h` holds handhold `i` (tree frame): on steep wood on the
## bark at angle `a`; on a limb on the top of the wood, a little to its
## own side.
func _point(i: int, a: float, h: int) -> Vector3:
	if _cling(i) or (_round(i) and pose == "trunk"):
		return g.local[i] + _around(i, a) * g.radius[i]
	var t := g.tangent[i]
	var side := _up_l - t * t.dot(_up_l)
	var top := g.local[i] + (side.normalized() * g.radius[i] if side.length_squared() > 1e-6 else Vector3.ZERO)
	var across := _along.cross(_up_l)
	return top + across * (0.05 if h == 1 else -0.05)


## The angle a new hold on `j` takes: facing a hand coming from `from`.
func _hold_angle(j: int, from: Vector3) -> float:
	if _round(j):
		return _top_angle(j) + _limb_rel
	return _angle_of(j, from) if _cling(j) else 0.0


## The body's angle round the trunk: between the hands on steep wood.
func _body_angle() -> float:
	var s := 0.0
	var c := 0.0
	var n := 0
	for h in 2:
		if _cling(hold[h]) or _round(hold[h]):
			s += sin(angle[h])
			c += cos(angle[h])
			n += 1
	if n == 0:
		return 0.0
	return atan2(s, c)


## Out from the wood's axis at handhold `i`, at angle `a` round it (unit,
## tree frame): the angles are measured the same way all along a trunk,
## from the tree frame's +X.
func _around(i: int, a: float) -> Vector3:
	var t := g.tangent[i]
	var ref := Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.BACK
	var e1 := (ref - t * t.dot(ref)).normalized()
	var e2 := t.cross(e1)
	return e1 * cos(a) + e2 * sin(a)


## The angle round the wood at `i` of a point `p` (tree frame).
func _angle_of(i: int, p: Vector3) -> float:
	var t := g.tangent[i]
	var ref := Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.BACK
	var e1 := (ref - t * t.dot(ref)).normalized()
	var e2 := t.cross(e1)
	var d := p - g.local[i]
	return atan2(d.dot(e2), d.dot(e1))


func _horizontal(v: Vector3) -> Vector3:
	return v - _up_l * v.dot(_up_l)

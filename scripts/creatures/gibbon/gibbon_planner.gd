class_name GibbonPlanner
## Where the gibbon swings to next (spec Phase 1 (iii)): which handholds
## it can hang from, the release that carries it from one swing to a
## catch on the next handhold, and a route through the canopy. Plain
## functions over the branch graphs (BranchGraphs, read only); the
## gibbon (Gibbon) keeps its own state.
##
## The swing is a pendulum hanging from the grip (the top of the wood,
## where the hooked fingers rest) down to the body's center of mass, `l`
## meters. A release at swing angle theta (from straight down, forward
## positive) with the swing's amplitude `amp` gives the body a speed of
## sqrt(2 g l (cos theta - cos amp)) along the arc, and it flies
## ballistically from there. It catches the next handhold with the free
## hand when its center of mass comes within an arm's reach (`l`) of it,
## from below and behind: the angle `phi` behind straight down at the
## catch. solve() inverts that: for a handhold x m ahead and y m up, every
## pair of release angle and catch angle on a coarse grid gives one
## flight time and one launch speed; the pair needing a swing nearest the
## one the gibbon wants wins. Short gaps need no flight at all: the free
## hand closes on the next handhold while the body swings under the grip
## ("contact"), as gibbons do at a walk.

const G := 9.8
## Wood it hangs from: at least BranchGraph.MIN_RADIUS_M, at most this
## thick (m). Thicker wood it can sit on but not hook a hand round.
const HANG_R_MAX := 0.15
## Thinnest wood it sits on (m).
const SIT_R_MIN := 0.06
## Wood steeper than this (|tangent . up|) is for climbing, not swinging
## from: trunks and near-vertical limbs.
const STEEP := 0.85
## How far it looks for its next handhold, and its leap limits: the
## longest horizontal gap, the most height it can gain in one leap, the
## deepest drop it leaps down (m).
const LOOK_M := 6.5
const LEAP_MAX_M := 5.8
const RISE_MAX_M := 1.0
const DROP_MAX_M := 3.5
## The widest swing it builds (95 degrees from straight down), and the
## widest it swings without an extra push from the arm at the release.
const AMP_MAX := 1.658
const AMP_EASY := 1.40
## The most extra speed the pulling arm adds at a release (m/s): what
## turns a swing into a 5-6 m leap.
const BOOST_MAX := 2.2
## Its reach at a catch, as a share of the hang length.
const REACH := 1.0
## A free hand reaches from the shoulder, not the center of mass: the
## shoulder sits this far up the body from the center of mass, and the
## arm reaches this far from it (in the swing's plane; the shoulder is a
## little off to the side). For contact moves.
const SHOULDER_M := 0.17
const ARM_M := 0.57
## Flight times it will commit to (s).
const TAU_MIN := 0.12
const TAU_MAX := 1.35
## Route costs: meters of leap cost this many meters of wood, plus a flat
## cost per leap, so it keeps to the wood while the wood goes its way.
const AIR_COST := 1.3
const LEAP_COST := 0.8

## Grid of which (x, y) gaps a leap or contact can cover, filled lazily
## for the standard hang length (route()).
static var _feasible := PackedByteArray()
static var _feasible_l := -1.0
const FEAS_DX := 0.25
const FEAS_NX := 25 # x 0 .. 6 m
const FEAS_NY := 19 # y -3.5 .. +1.0 m


## Can it hang from handhold `i` (the wood's thickness and slope)?
static func hangable(g: BranchGraph, i: int, up: Vector3) -> bool:
	var r := g.radius[i]
	if r < BranchGraph.MIN_RADIUS_M - 1e-4 or r > HANG_R_MAX:
		return false
	return absf(g.dir(i).dot(up)) < STEEP


## Can it sit on handhold `i`?
static func sittable(g: BranchGraph, i: int, up: Vector3) -> bool:
	return g.radius[i] >= SIT_R_MIN and absf(g.dir(i).dot(up)) < 0.5


## The grip: the top of the wood at handhold `i`, where the fingers hook
## over it (scene position).
static func top(g: BranchGraph, i: int, up: Vector3) -> Vector3:
	var t := g.dir(i)
	var side := up - t * up.dot(t)
	if side.length_squared() < 1e-6:
		return g.pos(i)
	return g.pos(i) + side.normalized() * g.radius[i]


## Energy per kilogram of a swing of amplitude `amp` on a hang of `l` m.
static func swing_energy(amp: float, l: float) -> float:
	return G * l * (1.0 - cos(amp))


## The amplitude of a swing with energy `e` per kilogram (radians; past
## horizontal it keeps growing on the same scale).
static func amplitude(e: float, l: float) -> float:
	return acos(clampf(1.0 - e / (G * l), -1.0, 1.0))


## How to get from a swing under the current grip to a catch on a
## handhold `x` m ahead (horizontally) and `y` m up (negative: below).
## `l` is the hang length and `amp_want` the swing the gibbon would like
## to keep (radians): big while it travels, small as it slows. Returns {}
## when the handhold is out of reach, else {"contact", "theta", "amp",
## "boost", "tau", "phi", "cost"}: contact (no flight: the free hand
## reaches it mid-swing), the release angle and the swing amplitude it
## needs (radians), the extra push at the release (m/s), the flight time
## (s), where the body is at the catch (radians behind straight below the
## new grip) and how much the gibbon dislikes it (lower is better).
## `amp_have` is the swing it has now (radians, -1: none): a throw may
## keep it and let the pulling arm make up the speed, so momentum carries
## into the next leap without another swing to build it.
static func solve(x: float, y: float, l: float, amp_want: float, amp_have := -1.0) -> Dictionary:
	var best := {}
	var best_cost := INF
	var reach := l * REACH
	var target := Vector2(x, y)
	# Contact: the smallest swing that brings the body within reach of it,
	# below it.
	var step := deg_to_rad(5.0)
	var amp := deg_to_rad(8.0)
	while amp <= AMP_EASY:
		var th := 0.0
		var ok := false
		while th <= amp:
			var p := Vector2(l * sin(th), -l * cos(th))
			var rel := p - target
			var sh := p * ((l - SHOULDER_M) / l)
			if (sh - target).length() <= ARM_M and rel.y < -0.2 * l:
				ok = true
				break
			th += step
		if ok:
			var cost := maxf(0.0, amp - amp_want) * 1.5 + 0.1 * amp
			best = {"contact": true, "theta": th, "amp": amp, "boost": 0.0, "tau": 0.0, "phi": 0.0, "cost": cost}
			best_cost = cost
			break
		amp += step
	# Flight: every release angle (8-80 degrees) and catch angle (-10 to
	# 62 degrees behind straight below) on a coarse grid.
	var catch_r := reach * 0.93
	for ti in 19:
		var th := deg_to_rad(8.0 + 4.0 * ti)
		var r := Vector2(l * sin(th), -l * cos(th))
		var ct := cos(th)
		var tt := tan(th)
		# The swing must reach past the release; an easy swing if that's
		# enough, and the arm's pull makes up any speed it lacks.
		var a_lo := th + 0.05
		var a_cap := maxf(AMP_EASY, minf(a_lo, AMP_MAX))
		for phi_i in 10:
			var phi := deg_to_rad(-10.0 + 8.0 * phi_i)
			var c := Vector2(x - catch_r * sin(phi), y - catch_r * cos(phi))
			var dx := c.x - r.x
			if dx < 0.08:
				continue
			var tau2 := 2.0 * (dx * tt - (c.y - r.y)) / G
			if tau2 < TAU_MIN * TAU_MIN or tau2 > TAU_MAX * TAU_MAX:
				continue
			var tau := sqrt(tau2)
			var s := dx / (ct * tau)
			var cos_a := ct - s * s / (2.0 * G * l)
			var need := acos(cos_a) if cos_a >= -1.0 else PI
			var a := clampf(need, a_lo, a_cap)
			var boost := 0.0
			if need > a:
				boost = s - sqrt(maxf(2.0 * G * l * (ct - cos(a)), 0.0))
				if boost > BOOST_MAX:
					continue
			# It mustn't come down onto the wood from above on the way.
			if not _clear_path(r, Vector2(s * ct, s * sin(th)), tau, target, l):
				continue
			var rest := absf(phi - deg_to_rad(22.0)) * 0.6 + tau * 0.4
			var cost := absf(a - amp_want) * 1.5 + boost * 0.7 + rest
			# Or the swing it has, with the arm's pull.
			if amp_have >= a_lo and amp_have < a:
				var b2 := s - sqrt(maxf(2.0 * G * l * (ct - cos(amp_have)), 0.0))
				var c2 := absf(amp_have - amp_want) * 1.5 + b2 * 0.7 + rest
				if b2 <= BOOST_MAX and c2 < cost:
					a = amp_have
					boost = b2
					cost = c2
			if cost < best_cost:
				best_cost = cost
				best = {"contact": false, "theta": th, "amp": a, "boost": boost, "tau": tau, "phi": phi, "cost": cost}
	return best


## False if the flight from `r` at `v` for `tau` s passes within reach of
## the target before the catch while above it (it would land on the wood).
static func _clear_path(r: Vector2, v: Vector2, tau: float, target: Vector2, l: float) -> bool:
	for k in range(1, 8):
		var t := tau * k / 8.0
		var p := r + v * t + Vector2(0.0, -0.5 * G * t * t)
		var rel := p - target
		if rel.length() < l * 0.9 and rel.y > -0.2 * l:
			return false
	return true


## Can a gap of `x` m ahead and `y` m up be crossed with a hang of `l` m
## (by a leap or a reach)? Looked up in a grid filled once.
static func can_cross(x: float, y: float, l: float) -> bool:
	if x > LEAP_MAX_M or y > RISE_MAX_M or y < -DROP_MAX_M:
		return false
	if _feasible_l != l:
		_fill_feasible(l)
	var i := clampi(int(round(x / FEAS_DX)), 0, FEAS_NX - 1)
	var j := clampi(int(round((y + DROP_MAX_M) / FEAS_DX)), 0, FEAS_NY - 1)
	return _feasible[j * FEAS_NX + i] == 1


static func _fill_feasible(l: float) -> void:
	_feasible.resize(FEAS_NX * FEAS_NY)
	for j in FEAS_NY:
		for i in FEAS_NX:
			var x := i * FEAS_DX
			var y := -DROP_MAX_M + j * FEAS_DX
			# Checked a little beyond the cell (the grid rounds), so a gap
			# the grid allows is one the swing can really make.
			var ok := x >= 0.3 and not solve(x + 0.12, y + (0.12 if y > 0.0 else -0.12), l, AMP_EASY).is_empty()
			_feasible[j * FEAS_NX + i] = 1 if ok else 0
	_feasible_l = l


## The launch velocity that carries the body from `c` to `target` under
## gravity with the flight time whose velocity is nearest `vel`, as
## [velocity, time], or [] if even that one needs more than a small turn
## of the swing's direction or more than `extra` m/s more speed.
static func launch(c: Vector3, vel: Vector3, target: Vector3, up: Vector3, extra: float) -> Array:
	var best := []
	var best_d := INF
	var t := TAU_MIN
	while t <= TAU_MAX + 0.2:
		var v := (target - c) / t + up * (0.5 * G * t)
		var d := (v - vel).length_squared()
		if d < best_d:
			best_d = d
			best = [v, t]
		t += 0.02
	if best.is_empty():
		return []
	var v_need: Vector3 = best[0]
	var speed := vel.length()
	if speed < 0.4:
		return []
	if v_need.length() - speed > extra + 0.25 or v_need.length() < speed * 0.7:
		return []
	if vel.angle_to(v_need) > 0.3:
		return []
	return best


# --- Route ---------------------------------------------------------------------

## A route through the canopy from handhold (from_g, from_i) to (to_g,
## to_i), as [graph, index] pairs: along the wood between handholds it
## can hang from, and across open air to another limb or tree wherever a
## swing can cross the gap (can_cross()). A* over the handholds of the
## graphs within `radius_m` of the start. [] if there is no way.
static func route(from_g: BranchGraph, from_i: int, to_g: BranchGraph, to_i: int, up: Vector3, l: float, radius_m := 80.0) -> Array:
	var s := search(from_g, from_i, up, l, radius_m, to_g, to_i)
	if s == null:
		return []
	return s.path_to(s.node_of(to_g, to_i))


## Where it can get to from handhold (from_g, from_i): the same network
## as route(), searched outward from the start over the graphs within
## `radius_m` (Dijkstra), or toward (to_g, to_i) only (A*, stopping there)
## when that is given. With `reverse`, where it can get back to the start
## FROM instead (leaps drop further than they climb, so the two differ).
## null if it can't hang at the start.
static func search(from_g: BranchGraph, from_i: int, up: Vector3, l: float, radius_m := 60.0, to_g: BranchGraph = null, to_i := -1, reverse := false) -> Search:
	var s := Search.new()
	var start_p := top(from_g, from_i, up)
	s.graphs = BranchGraphs.near(start_p, radius_m)
	if not s.graphs.has(from_g):
		s.graphs.append(from_g)
	if to_g != null and not s.graphs.has(to_g):
		s.graphs.append(to_g)
	# Horizontal axes at the start, for the grid.
	var e1 := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := up.cross(e1)
	var grid := {} # Vector2i cell -> Array of nodes
	const CELL := 3.0
	for gi in s.graphs.size():
		var g := s.graphs[gi]
		for i in g.size():
			if not hangable(g, i, up):
				continue
			var n := s.node_g.size()
			s.node_g.append(gi)
			s.node_i.append(i)
			var p := top(g, i, up)
			s.node_p.append(p)
			s.index[Vector2i(gi, i)] = n
			var rel := p - start_p
			var cell := Vector2i(floori(rel.dot(e1) / CELL), floori(rel.dot(e2) / CELL))
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(n)
	var src := s.node_of(from_g, from_i)
	var dst := s.node_of(to_g, to_i) if to_g != null else -1
	if src < 0 or (to_g != null and dst < 0):
		return null
	var count := s.node_g.size()
	s.cost.resize(count)
	s.cost.fill(INF)
	s.came.resize(count)
	s.came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(count)
	var goal_p := s.node_p[dst] if dst >= 0 else Vector3.ZERO
	var heap := _Heap.new()
	s.cost[src] = 0.0
	heap.push(s.node_p[src].distance_to(goal_p) if dst >= 0 else 0.0, src)
	while not heap.empty():
		var n := heap.pop()
		if closed[n] == 1:
			continue
		if n == dst:
			break
		closed[n] = 1
		var gi := s.node_g[n]
		var g := s.graphs[gi]
		var p := s.node_p[n]
		# Along the wood.
		for j in g.links[s.node_i[n]]:
			var m: int = s.index.get(Vector2i(gi, j), -1)
			if m >= 0 and closed[m] == 0:
				_relax(heap, s.cost, s.came, n, m, s.cost[n] + p.distance_to(s.node_p[m]), s.node_p[m].distance_to(goal_p) if dst >= 0 else 0.0)
		# Across the air, to another limb or tree.
		var rel := p - start_p
		var cx := floori(rel.dot(e1) / CELL)
		var cy := floori(rel.dot(e2) / CELL)
		var limb := g.limb[s.node_i[n]]
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var cell_nodes = grid.get(Vector2i(cx + dx, cy + dy))
				if cell_nodes == null:
					continue
				for m: int in cell_nodes:
					if closed[m] == 1 or (s.node_g[m] == gi and g.limb[s.node_i[m]] == limb):
						continue
					var d := s.node_p[m] - p
					var y := d.dot(up)
					var x := (d - up * y).length()
					if x < 0.5 or not can_cross(x, -y if reverse else y, l):
						continue
					_relax(heap, s.cost, s.came, n, m, s.cost[n] + d.length() * AIR_COST + LEAP_COST, s.node_p[m].distance_to(goal_p) if dst >= 0 else 0.0)
	return s


## The result of search(): the handholds it can hang from (nodes), and
## the cheapest way to each from the start.
class Search:
	var graphs: Array[BranchGraph] = []
	## Per node: which graph (index into `graphs`), which handhold, where
	## it grips (the top of the wood), the cost of getting there (INF: no
	## way found) and the node it comes from (-1 at the start).
	var node_g := PackedInt32Array()
	var node_i := PackedInt32Array()
	var node_p := PackedVector3Array()
	var cost := PackedFloat32Array()
	var came := PackedInt32Array()
	var index := {} # Vector2i(graph, handhold) -> node

	func node_of(g: BranchGraph, i: int) -> int:
		return index.get(Vector2i(graphs.find(g), i), -1)

	func reached(n: int) -> bool:
		return n >= 0 and cost[n] < INF

	## The way to node `n` as [graph, index] pairs from the start, or [].
	func path_to(n: int) -> Array:
		if not reached(n):
			return []
		var out := []
		var k := n
		while k >= 0:
			out.push_front([graphs[node_g[k]], node_i[k]])
			k = came[k]
		return out


static func _relax(heap: _Heap, cost: PackedFloat32Array, came: PackedInt32Array, from: int, to: int, c: float, h: float) -> void:
	if c < cost[to]:
		cost[to] = c
		came[to] = from
		heap.push(c + h, to)


## A binary min-heap of (priority, node).
class _Heap:
	var keys := PackedFloat32Array()
	var vals := PackedInt32Array()

	func empty() -> bool:
		return vals.is_empty()

	func push(k: float, v: int) -> void:
		keys.append(k)
		vals.append(v)
		var i := vals.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if keys[p] <= keys[i]:
				break
			_swap(i, p)
			i = p

	func pop() -> int:
		var top_v := vals[0]
		var last := vals.size() - 1
		_swap(0, last)
		keys.resize(last)
		vals.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var s := i
			if l < last and keys[l] < keys[s]:
				s = l
			if r < last and keys[r] < keys[s]:
				s = r
			if s == i:
				break
			_swap(i, s)
			i = s
		return top_v

	func _swap(a: int, b: int) -> void:
		var tk := keys[a]
		keys[a] = keys[b]
		keys[b] = tk
		var tv := vals[a]
		vals[a] = vals[b]
		vals[b] = tv

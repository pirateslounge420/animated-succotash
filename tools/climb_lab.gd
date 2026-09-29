extends SceneTree
## Climbing on tree skeletons offline (no world, a few seconds): TreeClimb
## driven with the stick on the branch graphs of several species, the camera
## looking at the wood held, the way climb_check drives it in game. Per tree:
##   - W from the foot: how high before it stalls (and what's in reach there);
##   - S from there: back down to the foot (the climb steps off);
##   - W+D from halfway: up and round at once;
##   - out along the lowest thick limb and round it with D.
## Deterministic, so a change to TreeClimb shows on the same trees.
##
##   ~/bin/godot --headless --path . --script tools/climb_lab.gd
## SPECIES="Acacia,Oak" to pick; LAYOUTS=2 for more layouts per species.
## BRANCHES=1: instead, every branch off the trunk thick enough to hold
## (from play: "any branch that branches off should be accessible"): from
## the trunk beside its foot, looking out along it, W; does it take you out
## along it to where it gets too thin? Prints each miss and a score per
## tree; fails below BRANCH_PASS of them reached.

const SPECIES := ["Acacia", "Beach she-oak", "Miombo tree", "Oak", "Beech", "Baobab", "Paper birch", "Scots pine"]
const DT := 1.0 / 60.0
## Share of a tree's holdable branches W must take you out along.
const BRANCH_PASS := 0.9

var fails := 0
var holder: Node3D
var trace := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TreeLayouts.use_seed(42)
	holder = Node3D.new()
	get_root().add_child(holder)
	var names: Array = SPECIES if OS.get_environment("SPECIES") == "" else Array(OS.get_environment("SPECIES").split(","))
	var layouts := int(OS.get_environment("LAYOUTS")) if OS.get_environment("LAYOUTS") != "" else 1
	for n in names:
		var sp := SpeciesDB.find(n)
		if sp == null or not TreeArch.grows(sp):
			print("[lab] %s: not grown from architecture" % n)
			continue
		var idx := SpeciesDB.index_of(sp)
		for lay in layouts:
			var h: float = lerpf(float(sp.height_m.x), float(sp.height_m.y), 0.6) if sp.height_m is Vector2 else 18.0
			var g := TreeLayouts.graph(idx, lay * 3, h)
			if g == null:
				print("[lab] %s: no graph" % n)
				continue
			g.chunk = holder
			g.xform = Transform3D.IDENTITY
			g.key = hash([n, lay])
			BranchGraphs.add(g)
			if OS.get_environment("BRANCHES") == "1":
				_branches(n, g)
			else:
				_tree(n, g)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The climber on graph `g`: holding its lowest trunk handhold, facing it
## from the north.
func _grab(g: BranchGraph) -> TreeClimb:
	var c := TreeClimb.new()
	var low := -1
	for i in g.size():
		if g.limb[i] == 0 and g.local[i].y > 1.0 and (low < 0 or g.local[i].y < g.local[low].y):
			low = i
	c.start(g, low, g.local[low] + Vector3(0, -1.0, g.radius[low] + 0.45), Vector3.UP)
	return c


## Hold `input` for `s` seconds, the camera looking at the body's own
## wood (from the feet toward the held handhold), `look` turning it (a
## horizontal direction in the tree frame, or ZERO: at the wood).
## Returns the highest and lowest the feet got.
func _hold(c: TreeClimb, input: Vector2, s: float, look := Vector3.ZERO) -> Vector2:
	var hi := -INF
	var lo := INF
	# The camera held still while the stick is (as in play): set once, at
	# the wood on the trunk, the way the body faces on a limb.
	if look == Vector3.ZERO and c.pose != "trunk":
		look = c.facing
	elif look == Vector3.ZERO:
		# At the wood, the way the body faces it (from the feet it swung
		# aside once the feet hung down along a leaning trunk).
		look = c.facing if c.facing.length() > 0.1 else Vector3.FORWARD
	for f in int(s / DT):
		var fwd := look
		var right := fwd.cross(Vector3.UP).normalized()
		if trace > 0 and c.reaching < 0 and c._beat <= 0.0:
			trace -= 1
			var m := c._choose(input, fwd, right)
			print("        at %s/%s (angles %.2f %.2f, lead %d), fwd %s: choose %s -> %s" % [c.hold[0], c.hold[1], c.angle[0], c.angle[1], c.lead, fwd.snapped(Vector3.ONE * 0.01), input, m])
		var r := c.step(DT, input, fwd, right, Vector3.UP)
		hi = maxf(hi, c.feet.y)
		lo = minf(lo, c.feet.y)
		if r != "":
			c.set_meta("ended", r)
			break
	return Vector2(hi, lo)


func _tree(n: String, g: BranchGraph) -> void:
	print("[lab] %s, %.1f m, %d handholds" % [n, g.height_m, g.size()])
	# Up.
	var c := _grab(g)
	var got := _hold(c, Vector2(0, 1), 60.0)
	var top := got.x
	print("    W: up to %.1f m of %.1f, stopped at %s, %s" % [top, g.height_m, c.describe(c.hold[c.lead]), c.pose])
	if top < g.height_m * 0.6:
		var hi_i: int = c.hold[0] if g.local[c.hold[0]].y >= g.local[c.hold[1]].y else c.hold[1]
		for j in c._reachable(hi_i, true):
			var dd: Vector3 = g.local[j] - g.local[hi_i]
			if dd.length() > 0.05:
				print("      in reach: %s, %.2f m away, %.2f of the way up%s" % [c.describe(j), dd.length(), dd.normalized().y, "" if g.radius[j] >= TreeClimb.GRIP_R_M else " (too thin)"])
		var fw: Vector3 = g.local[c.hold[c.lead]] - c.feet
		fw.y = 0.0
		fw = fw.normalized()
		print("      holds L %s at %.2f, R %s at %.2f, lead %d; choose W: %s; upward: %s; last: %s" % [c.describe(c.hold[0]), c.angle[0], c.describe(c.hold[1]), c.angle[1], c.lead, c._choose(Vector2(0, 1), fw, fw.cross(Vector3.UP)), c._upward(), c.holds_log.slice(-4)])
	ok(top > g.height_m * 0.45, "%s: W climbs into the crown (%.1f of %.1f m)" % [n, top, g.height_m])
	# Down.
	trace = 30 if OS.get_environment("TRACE") == "down" else 0
	got = _hold(c, Vector2(0, -1), 90.0)
	var ended: String = c.get_meta("ended", "")
	print("    S: down to %.1f m (%s), at %s" % [got.y, ended if ended != "" else "still on", c.describe(c.hold[c.lead])])
	if not (ended == "drop" or got.y < 1.5):
		print("      last reaches: %s" % [c.holds_log.slice(-8)])
		print("      holds: L %s at %.2f, R %s at %.2f; lead %d; feet %.2f" % [c.describe(c.hold[0]), c.angle[0], c.describe(c.hold[1]), c.angle[1], c.lead, c.feet.y])
		var lo_i: int = c.hold[0] if g.local[c.hold[0]].y <= g.local[c.hold[1]].y else c.hold[1]
		for j in c._reachable(lo_i, true):
			var dd: Vector3 = g.local[j] - g.local[lo_i]
			if dd.length() > 0.05:
				print("      in reach below: %s, %.2f m away, %.2f of the way up, link %s" % [c.describe(j), dd.length(), dd.normalized().y, g.links[lo_i].has(j)])
		print("      choose S: %s; upward(-1): %s; prompt '%s'" % [c._choose(Vector2(0, -1), -c.facing, (-c.facing).cross(Vector3.UP)), c._upward(-1.0), c.prompt])
	ok(ended == "drop" or got.y < 1.5, "%s: S climbs back down to the foot" % n)
	# Diagonal from halfway up the trunk (taken hold of there).
	var mid := -1
	for i in g.size():
		if g.limb[i] == 0 and g.radius[i] >= TreeClimb.GRIP_R_M and (mid < 0 or absf(g.local[i].y - top * 0.5) < absf(g.local[mid].y - top * 0.5)):
			mid = i
	c = TreeClimb.new()
	c.start(g, mid, g.local[mid] + Vector3(0, -1.0, g.radius[mid] + 0.45), Vector3.UP)
	_hold(c, Vector2(0, 1), 1.0)
	var a0 := c.feet.y
	var w0: int = c.hold[c.lead]
	trace = 8 if OS.get_environment("TRACE") == "diag" else 0
	# (The camera held still, as in play: looking at the wood from where
	# you start.)
	var look0: Vector3 = g.local[w0] - c.feet
	look0.y = 0.0
	# (Added up step by step round the wood's own axis: once past half a
	# turn, start to end alone reads short.)
	var turned := rad_to_deg(absf(_round_during(c, Vector2(0.7071, 0.7071), 3.0, look0.normalized())))
	print("    W+D from %.1f m (%s): %.1f m higher, %.0f deg round, now %s" % [a0, c.describe(w0), c.feet.y - a0, turned, c.describe(c.hold[c.lead])])
	ok(c.feet.y - a0 > 0.3 and turned > 15.0, "%s: W+D climbs up and round" % n)
	# Round the trunk with D alone, from halfway up: all the way round, and
	# on, whichever way the trunk leans or twists (from play). Measured
	# round the wood's own axis at the hold, step by step.
	c = TreeClimb.new()
	c.start(g, mid, g.local[mid] + Vector3(0, -1.0, g.radius[mid] + 0.45), Vector3.UP)
	# (The camera held still: round the back of the trunk D must carry on
	# the same way round.)
	var total := _round_during(c, Vector2(1, 0), 15.0, c.facing)
	print("    D round the trunk for 15 s from %.1f m: %.0f deg round, at %s (lean %.0f deg)" % [g.local[mid].y, rad_to_deg(absf(total)), c.describe(c.hold[c.lead]), rad_to_deg(g.tangent[mid].angle_to(Vector3.UP))])
	ok(absf(total) > TAU, "%s: D goes all the way round the trunk (%.0f deg)" % [n, rad_to_deg(absf(total))])
	# Out along the lowest thick level limb on the trunk, and round it.
	var best := -1
	for i in g.size():
		if g.limb[i] == 0 or g.radius[i] < TreeClimb.STRADDLE_R_M or absf(g.tangent[i].y) > 0.6:
			continue
		var from_trunk := false
		for j in g.links[i]:
			from_trunk = from_trunk or g.limb[j] == 0
		if from_trunk and g.local[i].y > 1.5 and (best < 0 or g.local[i].y < g.local[best].y):
			best = i
	if best < 0:
		print("    no thick level limb off the trunk")
		return
	c = _grab(g)
	var th := Vector3(g.tangent[best].x, 0, g.tangent[best].z).normalized()
	# Round to its side of the trunk and up to it.
	c.start(g, g.links[best][0] if g.limb[g.links[best][0]] == 0 else best, g.local[best] - th * 0.1 + Vector3(0, -1.2, 0) + th * (g.radius[best] + 0.5), Vector3.UP)
	trace = 12 if OS.get_environment("TRACE") == "out" else 0
	_hold(c, Vector2(0, 1), 8.0, th)
	var on := g.limb[c.hold[c.lead]] != 0 and not c._cling(c.hold[c.lead])
	print("    out along limb at %s: now %s, %s" % [c.describe(best), c.describe(c.hold[c.lead]), c.pose])
	ok(on, "%s: W looking out along a thick limb takes you out onto it" % n)
	if on:
		var poses := {}
		var lean := 0.0
		for k in 16:
			_hold(c, Vector2(1, 0), 10 * DT, th)
			poses[c.pose] = true
			if not is_nan(c._limb_rel):
				lean = maxf(lean, absf(c._limb_rel))
		print("    D round it: poses %s, leaning %.0f deg" % [poses.keys(), rad_to_deg(lean)])
		ok(lean > 0.3 and poses.keys() == ["straddle"], "%s: D leans you round the limb, still astride" % n)


## Each limb's parent limb (the one its first handhold forks from; -1 for
## the trunk) and its handholds, outward in order.
func _limbs(g: BranchGraph) -> Array:
	var parent := {}
	var holds := {}
	for i in g.size():
		var l := g.limb[i]
		if not holds.has(l):
			holds[l] = []
			parent[l] = -1
			for j in g.links[i]:
				if g.limb[j] != l and j < i:
					parent[l] = g.limb[j]
		holds[l].append(i)
	return [parent, holds]


## Is limb `l` limb `top` or grown from it?
func _within(l: int, top: int, parent: Dictionary) -> bool:
	var k := 0
	while l >= 0 and k < 64:
		if l == top:
			return true
		l = parent.get(l, -1)
		k += 1
	return false


func _branches(n: String, g: BranchGraph) -> void:
	var lp := _limbs(g)
	var parent: Dictionary = lp[0]
	var holds: Dictionary = lp[1]
	var tried := 0
	var reached := 0
	for l in holds:
		if l == 0 or parent[l] != 0 or l >= BranchGraph.VINE_LIMB:
			continue
		var hs: Array = holds[l]
		var r0: int = hs[0]
		if g.radius[r0] < TreeClimb.GRIP_R_M:
			continue
		if OS.get_environment("LIMB") != "" and l != int(OS.get_environment("LIMB")):
			continue
		var t := -1
		for j in g.links[r0]:
			if g.limb[j] == 0:
				t = j
		if t < 0 or g.local[t].y < TreeClimb.LOWEST_HOLD_M + 0.3:
			continue
		# Its tip: the last handhold out along it still thick enough.
		var tip := r0
		for i in hs:
			if g.radius[i] >= TreeClimb.GRIP_R_M:
				tip = i
			else:
				break
		var reach: float = (g.local[tip] - g.local[r0]).length()
		# (A stub: less than a metre to hold, nothing to go out along.)
		if reach < 1.0:
			continue
		tried += 1
		# Two natural looks: toward its tip, and the way it leaves the
		# trunk (they differ on a stem bending up out of a crown's fork).
		var looks: Array[Vector3] = []
		for way: Vector3 in [g.local[tip] - g.local[t], g.local[r0] - g.local[t] + g.tangent[r0]]:
			var lk := Vector3(way.x, 0, way.z)
			if lk.length() > 1e-3:
				looks.append(lk.normalized())
		var depth := _depth_from(g, r0, l, parent)
		var got := "no way to look along it"
		for look in looks:
			var res := _branch_try(g, t, r0, tip, reach, look, depth)
			if res == "":
				got = ""
				break
			got = res
		if got == "":
			reached += 1
		else:
			print("    miss: limb %d (r %.2f m, %.1f m up, %.1f m long to r %.2f, rising %.2f): %s" % [l, g.radius[r0], g.local[r0].y, reach, g.radius[tip], g.tangent[r0].y, got])
	var share := float(reached) / maxf(tried, 1.0)
	print("[lab] %s: %d of %d branches off the trunk reached along (%.0f %%)" % [n, reached, tried, share * 100.0])
	ok(tried == 0 or share >= BRANCH_PASS, "%s: W takes you out along the branches off the trunk (%d/%d)" % [n, reached, tried])


## Handholds of limb `l` and what grows from it, by links out from `r0`.
func _depth_from(g: BranchGraph, r0: int, l: int, parent: Dictionary) -> Dictionary:
	var depth := {r0: 0}
	var q := [r0]
	while not q.is_empty():
		var i: int = q.pop_front()
		for j in g.links[i]:
			if not depth.has(j) and _within(g.limb[j], l, parent):
				depth[j] = depth[i] + 1
				q.append(j)
	return depth


## How many holds on from `i`, outward, to the nearest end (thick enough).
func _to_end(g: BranchGraph, i: int, depth: Dictionary) -> int:
	var n := 0
	while n < 200:
		var nxt := -1
		for j in g.links[i]:
			if depth.has(j) and depth[j] > depth[i] and g.radius[j] >= TreeClimb.GRIP_R_M:
				nxt = j
		if nxt < 0:
			return n
		i = nxt
		n += 1
	return n


## From the trunk beside a branch's foot, looking `look`, W: "" if it takes
## you out along the branch to an end, else what happened.
func _branch_try(g: BranchGraph, t: int, r0: int, tip: int, reach: float, look: Vector3, depth: Dictionary) -> String:
	var c := TreeClimb.new()
	c.start(g, t, g.local[t] + Vector3(0, -1.0, 0) + look * (g.radius[t] + 0.45), Vector3.UP)
	trace = 10 if OS.get_environment("TRACE") == "out" else 0
	if trace > 0:
		print("      from %s, the branch's foot %s; look %s" % [c.describe(t), c.describe(r0), look.snapped(Vector3.ONE * 0.01)])
	# W until it stops getting you anywhere (4 s without a hold further
	# out along it, by links), or 3 minutes.
	var on := false
	var at_end := false
	var best := INF
	var far := -1
	var still := 0.0
	for k in 360:
		_hold(c, Vector2(0, 1), 0.5, look)
		var i: int = c.hold[c.lead]
		still += 0.5
		if depth.has(i):
			on = true
			best = minf(best, g.local[i].distance_to(g.local[tip]))
			# Out at an end of it: a hold with nothing thick enough further
			# out (a limb forks, so it has several ends; W takes the one
			# looked at). Held on, W may then reach across to wood nearby
			# (TreeClimb: the air between limbs), so ever, not last.
			if _to_end(g, i, depth) == 0:
				at_end = true
			if depth[i] > far:
				far = depth[i]
				still = 0.0
		if c.has_meta("ended") or still > 4.0:
			break
	var fin: int = c.hold[c.lead]
	if OS.get_environment("LIMB") != "":
		print("      last: %s" % [c.holds_log.slice(-6)])
	if on and (at_end or best < maxf(0.6, reach * 0.2)):
		return ""
	return "%s; now %s" % [("stopped %.1f m out, %d holds short of an end" % [(g.local[fin] - g.local[r0]).length(), _to_end(g, fin, depth)]) if on and depth.has(fin) else ("on it, then off it" if on else "never on it"), c.describe(fin)]


## The feet's offset from the wood held (tree frame).
func _round_off(c: TreeClimb) -> Vector3:
	return c.feet - c.g.local[c.hold[c.lead]]


## Hold `input` for `s` seconds, the camera still, looking `look`; how far
## round the wood (radians, signed) the feet went, added up every quarter
## second about the wood's own axis at the hold.
func _round_during(c: TreeClimb, input: Vector2, s: float, look: Vector3) -> float:
	var total := 0.0
	var prev := _round_off(c)
	for k in int(s / 0.25):
		_hold(c, input, 0.25, look)
		var now := _round_off(c)
		var tt: Vector3 = c.g.tangent[c.hold[c.lead]]
		var a := prev - tt * prev.dot(tt)
		var b := now - tt * now.dot(tt)
		total += a.signed_angle_to(b, tt)
		prev = now
	return total

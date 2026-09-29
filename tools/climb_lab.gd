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

const SPECIES := ["Acacia", "Beach she-oak", "Miombo tree", "Oak", "Beech", "Baobab", "Paper birch", "Scots pine"]
const DT := 1.0 / 60.0

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
		var to: Vector3 = c.g.local[c.hold[c.lead]] - c.feet
		to.y = 0.0
		look = to.normalized() if to.length() > 0.05 else -c.facing
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
	var p0: Vector3 = c.feet - g.local[c.hold[c.lead]]
	p0.y = 0.0
	var a0 := c.feet.y
	var w0: int = c.hold[c.lead]
	trace = 8 if OS.get_environment("TRACE") == "diag" else 0
	# (The camera held still, as in play: looking at the wood from where
	# you start.)
	var look0: Vector3 = g.local[w0] - c.feet
	look0.y = 0.0
	_hold(c, Vector2(0.7071, 0.7071), 3.0, look0.normalized())
	var p1: Vector3 = c.feet - g.local[c.hold[c.lead]]
	p1.y = 0.0
	var turned := rad_to_deg(p0.angle_to(p1))
	print("    W+D from %.1f m (%s): %.1f m higher, %.0f deg round, now %s" % [a0, c.describe(w0), c.feet.y - a0, turned, c.describe(c.hold[c.lead])])
	ok(c.feet.y - a0 > 0.3 and turned > 15.0, "%s: W+D climbs up and round" % n)
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
	_hold(c, Vector2(0, 1), 8.0, th)
	var on := g.limb[c.hold[c.lead]] != 0 and not c._cling(c.hold[c.lead])
	print("    out along limb at %s: now %s, %s" % [c.describe(best), c.describe(c.hold[c.lead]), c.pose])
	ok(on, "%s: W looking out along a thick limb takes you out onto it" % n)
	if on:
		var poses := {}
		for k in 16:
			_hold(c, Vector2(1, 0), 10 * DT, th)
			poses[c.pose] = true
		print("    D round it: %s" % [poses.keys()])
		ok(poses.size() >= 2, "%s: D goes round the limb" % n)

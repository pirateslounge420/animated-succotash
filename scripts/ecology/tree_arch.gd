class_name TreeArch
## A tree's skeleton grown from its species' `architecture` block (design
## §AK; docs/design/TREE_ARCHITECTURE.md §5, PLANT_SCHEMA §8), in the unit
## frame TreeLayouts uses (trunk foot at the origin, the tree 1 tall):
##
##   * the trunk: tapered (taper_exponent: the radius falls as the
##     remaining height to the power (k - 1) / 2: 1 a column, 2 a
##     paraboloid, 3 a cone), sinuous (sinuosity), its foot flared
##     (root_flare) and finned (buttress: low / high); stout or slender by
##     habit (a baobab's bottle, a spruce's pole);
##   * where it forks (fork_height_frac: low in the range when open-grown,
##     high in a stand) into codominant stems, parent² = Σ stems²
##     (Leonardo); excurrent trees keep a leader to the top instead;
##   * the order-1 branches, by the model's program: tiered whorls
##     (massart, aubreville), a spiral one per node (rauh, attims, roux,
##     scarrone, champagnat, mangenot), arching and drooping (troll,
##     weeping), or none along the stems but repeated forking at their
##     ends (leeuwenberg, koriba, schoute: sympodial and candelabra
##     crowns); spacing_m apart (whorl pitch), branch_angle_deg from the
##     vertical, as long as the crown's form wants at that height;
##   * then orders 2 and 3 (twigs) along each branch by the leaf
##     arrangement's phyllotaxis, each child Leonardo-thin (0.62 of its
##     parent there), its tip curving up, or down by canopy.droop;
##   * open-grown (a lone tree: live_crown_ratio[0], wide, low) or
##     forest-grown (in a stand: live_crown_ratio[1], narrow, a clear bole
##     with self-pruned stubs and collars below the crown when
##     self_prune);
##   * dead_limbs of the order-1 limbs (more of the low ones) dead: bare,
##     twigless, drawn grey;
##   * leaf anchors only on the outer twigs (the outer 30-40 % of each
##     branch; the inner crown hollow), by arrangement, thinned by
##     canopy.gap and grouped by canopy.layering; forest-grown crowns keep
##     them on the top and outer face (§AL);
##   * palms and tree ferns (corner, holttum, tomlinson): a column and
##     fronds from the crown point, each frond a rachis with its leaflets
##     (anchors) along both sides; tree ferns hang a skirt of dead fronds.
##
## Every number is a range centre jittered ±20 % per layout. Budgets keep
## a layout within MAX_* pieces (design §W). Pure function of the world
## seed, species and layout (thread-safe: its own RNG).
##
## Young trees (design §AR; `slot` 1 a young tree about half grown, 2 a
## sapling about a fifth grown: TreeLayouts' young layouts) grow as their
## species' young form (growth.juvenile): a whip (one slender leader, short
## laterals, a narrow crown), a cone (a leader and whorls or tiers longest
## at the foot, down to the ground), several stems from the base
## (multi_stem), or for palms, cycads and tree ferns the stemless rosette of
## the establishment years (a sapling: fronds straight from the ground,
## the first ones undivided when its juvenile leaves differ) and then a
## short trunk. Young trees keep their leader (whatever the adult's
## habit), carry their crowns low (a sapling's to the ground), fewer
## orders, no deadwood, no buttresses and no flare, are slimmer, and their
## leaf clusters are larger for their size (leaves don't shrink with the
## tree).

const S := PlantSpecies.Shape
const K := TreeLayouts.Kind
const MAX_L1 := 26
## Whorled conifers (massart, aubreville) carry many short limbs.
const MAX_L1_WHORL := 72
const MAX_L2 := 90
const MAX_TWIGS := 260
const MAX_ANCHORS := 320
const SEGMENTS := 5

## Shapes that keep their own meshes (solid or special) even with a block.
const OWN_SHAPES := [S.CACTUS, S.BAMBOO, S.LIANA, S.MANGROVE, S.KNEES]


## Does this species grow its wood from its architecture block?
static func grows(sp: PlantSpecies) -> bool:
	if sp.arch.is_empty():
		return false
	if not (sp.tier == PlantSpecies.Tier.EMERGENT or sp.tier == PlantSpecies.Tier.CANOPY):
		return false
	if sp.shape in OWN_SHAPES:
		return false
	return str(sp.arch.get("habit", "")) != "shrub"


static func _pair(v, fallback: Vector2) -> Vector2:
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return fallback


class _G:
	var sk: TreeLayouts.Skeleton
	var rng := RandomNumberGenerator.new()
	var sp: PlantSpecies
	var model := "rauh"
	var habit := "decurrent"
	var forest := false
	var h_m := 20.0 # the species' typical height
	var crown_base := 0.3
	var crown_r := 0.35
	var angle := Vector2(0.7, 1.1) # radians from vertical
	var taper_e := 0.25
	var sinu := 0.3
	var spacing := 0.05
	var max_order := 3
	var droop := 0.1
	var gap := 0.3
	var layering := "clumped"
	var arrangement := "alternate"
	var dead_share := 0.2
	var self_prune := false
	var cluster_r := 0.02
	var up := Vector3.UP
	## A young layout's slot (0 grown) and the species' young form.
	var slot := 0
	var juv := "whip"
	## Its share of the piece budgets (MAX_*): a young tree is simpler
	## wood, and understory saplings are many.
	var budget := 1.0

	func j(v: float) -> float:
		return v * rng.randf_range(0.8, 1.2)

	## A piece from `from` along `dir` for `length`, radius r0 -> r1, the tip
	## curving up by `lift` (share of its length; negative droops) and
	## wandering by the sinuosity.
	func piece(from: Vector3, dir: Vector3, length: float, r0: float, r1: float, lift: float, kind: int,
			order: int, parent: int, limb: int, dead := false) -> int:
		var pc := TreeLayouts.Piece.new()
		pc.kind = kind
		pc.order = order
		pc.parent = parent
		pc.limb = limb
		pc.dead = dead
		var side := dir.cross(up)
		side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
		var side2 := dir.cross(side).normalized()
		var ph := rng.randf() * TAU
		var wob := sinu * length * 0.06
		for i in SEGMENTS + 1:
			var t := float(i) / SEGMENTS
			var p := from + dir * length * t + up * lift * length * t * t
			if i > 0 and i < SEGMENTS:
				p += (side * sin(ph + t * 5.0) + side2 * cos(ph * 1.3 + t * 4.0)) * wob * sin(PI * t)
			pc.add(p, lerpf(r0, r1, t))
		return sk.add(pc)

	## The trunk (or a stem) from `from`, `length` tall along `dir`: tapered
	## by taper_e from r0 to r1, flared at a foot.
	func trunk(from: Vector3, dir: Vector3, length: float, r0: float, r1: float, flare: bool, parent: int) -> int:
		var pc := TreeLayouts.Piece.new()
		pc.kind = K.TRUNK
		pc.order = 0
		pc.parent = parent
		var side := dir.cross(Vector3.FORWARD)
		side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
		var side2 := dir.cross(side).normalized()
		var ph := rng.randf() * TAU
		var n := 8
		for i in n + 1:
			var t := float(i) / n
			var p := from + dir * length * t
			p += (side * sin(ph + t * 4.0) + side2 * cos(ph * 0.7 + t * 3.3)) * sinu * 0.012 * sin(PI * t)
			var r := r1 + (r0 - r1) * pow(1.0 - t, taper_e)
			if flare and t < 0.12:
				r *= lerpf(1.55, 1.0, t / 0.12)
			pc.add(p, r)
		return sk.add(pc)


static func grow(sp: PlantSpecies, idx: int, layout: int, world_seed: int, forest: bool, slot := 0) -> TreeLayouts.Skeleton:
	var a: Dictionary = sp.arch
	var g := _G.new()
	g.sp = sp
	g.slot = slot
	g.juv = sp.juvenile
	g.budget = [1.0, 0.55, 0.3][clampi(slot, 0, 2)]
	g.rng.seed = hash([world_seed, idx, layout, "arch"]) if slot == 0 else hash([world_seed, idx, layout, "arch", slot])
	g.sk = TreeLayouts.Skeleton.new()
	g.sk.arch = true
	g.sk.open = not forest
	g.sk.sway = 0.8
	g.sk.vines = 4
	g.forest = forest
	g.model = str(a.get("model", "rauh"))
	g.habit = str(a.get("habit", "decurrent"))
	g.h_m = maxf((sp.height_m.x + sp.height_m.y) * 0.5, 2.0)
	var young := slot > 0
	if young:
		# The young tree's own height, for its leaves' size and its spacing.
		g.h_m = maxf(g.h_m * (0.5 if slot == 1 else 0.2), 0.8)
	g.droop = float(sp.canopy.get("droop", 0.1))
	g.gap = float(sp.canopy.get("gap", 0.3))
	g.layering = str(sp.canopy.get("layering", "clumped"))
	g.arrangement = sp.leaf_arrangement if sp.leaf_arrangement != "" else "alternate"
	g.dead_share = float(a.get("dead_limbs", 0.2)) * (0.0 if slot == 2 else (0.3 if slot == 1 else 1.0))
	g.self_prune = bool(a.get("self_prune", false)) and slot != 2
	g.sinu = float(a.get("sinuosity", 0.3))
	# A leaf cluster: a few leaves across, a card a quarter to one and a
	# half meters wide.
	g.cluster_r = clampf(sp.leaf_m * 2.5, 0.22, 1.4) / g.h_m
	if g.habit in ["palm", "tree_fern"] or int(a.get("orders", 3)) <= 0 or g.model in ["corner", "holttum"]:
		_palm(g, a)
		return g.sk
	var lcr := _pair(a.get("live_crown_ratio"), Vector2(0.7, 0.4))
	g.crown_base = clampf(1.0 - g.j(lcr.y if forest else lcr.x), 0.03, 0.85)
	if young:
		# Low crowns: a sapling's to the ground, a young tree in a stand
		# already shedding its lowest limbs.
		var ylcr := (0.92 if not forest else 0.78) if slot == 2 else (0.85 if not forest else 0.62)
		g.crown_base = clampf(1.0 - ylcr * g.rng.randf_range(0.95, 1.05), 0.02, 0.5)
	var ang := _pair(a.get("branch_angle_deg"), Vector2(40, 65))
	g.angle = Vector2(deg_to_rad(ang.x), deg_to_rad(ang.y))
	if young:
		# Young shoots climb more steeply.
		g.angle *= 0.85
	g.taper_e = maxf(float(a.get("taper_exponent", 1.5)) - 1.0, 0.0) * 0.5
	# (A young tree's limbs come closer for its size: at most an eighth of
	# its height apart, so a sapling is leafy up its whole leader.)
	g.spacing = clampf(float(a.get("spacing_m", 1.0)) / g.h_m, 0.015, 0.12 if young else 0.25)
	g.max_order = clampi(int(a.get("orders", 4)), 2, 3)
	if slot == 2:
		g.max_order = 2
	var form := str(sp.canopy.get("form", "rounded"))
	var rc := 0.36
	match form:
		"spreading":
			rc = 0.5
		"umbrella", "palmate_crown":
			rc = 0.55
		"conical":
			rc = 0.22
		"columnar":
			rc = 0.12
		"irregular":
			rc = 0.38
		"weeping":
			rc = 0.4
	if g.habit == "columnar":
		rc = minf(rc, 0.14)
	if young:
		# A young crown is narrow: a whip's narrowest, a cone's broad at the
		# foot.
		match g.juv:
			"cone":
				rc = clampf(rc, 0.18, 0.3) * (0.95 if slot == 2 else 1.0)
			"multi_stem":
				rc *= 0.8
			_:
				rc *= 0.5 if slot == 2 else 0.68
	g.crown_r = g.j(rc) * (0.72 if forest else 1.1)
	# Slenderness (height over foot diameter) by habit; forest-grown slimmer.
	# (Height over the foot's diameter: an open-grown oak ~22, a spruce
	# ~45, a baobab ~4.)
	var slender := 22.0
	match g.habit:
		"excurrent", "columnar":
			slender = 45.0
		"umbrella":
			slender = 30.0
		"candelabra":
			slender = 4.5
		"multi_stem":
			slender = 35.0
	slender *= 1.4 if forest else 1.0
	if young:
		# Young trees are whips: tall for their girth.
		slender = maxf(slender, 30.0) * (2.2 if slot == 2 else 1.5)
	var r0 := 0.5 / g.j(slender)
	var flare := bool(a.get("root_flare", true)) and not young
	if not young:
		_fins(g, str(a.get("buttress", "none")), r0)

	var fork_v = a.get("fork_height_frac")
	var excurrent := g.habit in ["excurrent", "columnar"] or fork_v == null
	if young:
		# A young tree keeps its leader, whatever the adult's habit; a
		# multi-stemmed one comes up as several stems from the base.
		excurrent = g.juv != "multi_stem"
		if not excurrent:
			fork_v = [0.03, 0.09]
	var stems: Array[int] = []
	if excurrent:
		var leader := g.trunk(Vector3.ZERO, Vector3.UP, 0.97, r0, r0 * 0.08, flare, -1)
		stems.append(leader)
	else:
		var fr := _pair(fork_v, Vector2(0.2, 0.4))
		var f := lerpf(fr.x, fr.y, g.rng.randf_range(0.55, 1.0) if forest else g.rng.randf_range(0.0, 0.5))
		if g.habit == "multi_stem" or (young and g.juv == "multi_stem"):
			f = minf(f, 0.12)
		var r_f := r0 * pow(1.0 - f, g.taper_e) * 0.85
		var base := g.trunk(Vector3.ZERO, Vector3.UP, f, r0, r_f, flare, -1)
		var n_stems := 2 if g.model in ["schoute"] else g.rng.randi_range(2, 3)
		if g.habit == "candelabra":
			n_stems = g.rng.randi_range(4, 6)
		var az := g.rng.randf() * TAU
		for k in n_stems:
			var a_st := az + TAU * (k + g.rng.randf_range(-0.2, 0.2)) / n_stems
			var tilt := g.angle.x * (0.9 if g.habit == "candelabra" else 0.55) * g.rng.randf_range(0.7, 1.2)
			if g.habit == "umbrella":
				tilt = g.angle.y * 0.8
			var d := Vector3(cos(a_st) * sin(tilt), cos(tilt), sin(a_st) * sin(tilt)).normalized()
			var reach := (1.0 - f) * (0.55 if g.habit == "candelabra" else 0.95)
			var len_st := reach / maxf(d.y, 0.3)
			# Leonardo at the fork: the stems share the trunk's section.
			var r_st := r_f / sqrt(float(n_stems))
			# (A forking crown's stems stay thick to the fork at their tips.)
			var r_tip := r_st * (0.65 if g.model in ["leeuwenberg", "koriba", "schoute"] else 0.12)
			var st := g.trunk(Vector3(0, f, 0), d, len_st, r_st, r_tip, false, base)
			stems.append(st)
	# Order 1: along the stems (lateral programs) or forking at their ends.
	var forking := g.model in ["leeuwenberg", "koriba", "schoute"]
	var l1: Array[int] = []
	var limb_no := 0
	for st in stems:
		var pc: TreeLayouts.Piece = g.sk.pieces[st]
		if forking:
			for c in _fork(g, st, 1, pc.pts[pc.pts.size() - 1], (pc.pts[pc.pts.size() - 1] - pc.pts[pc.pts.size() - 2]).normalized(), pc.rad[pc.rad.size() - 1]):
				limb_no += 1
				g.sk.pieces[c].limb = limb_no
				l1.append(c)
			continue
		for c in _laterals_on_stem(g, st, excurrent):
			limb_no += 1
			g.sk.pieces[c].limb = limb_no
			l1.append(c)
	# Deadwood: a share of the limbs, the low ones likelier.
	for c in l1:
		var pc: TreeLayouts.Piece = g.sk.pieces[c]
		var low := 1.0 - clampf(pc.pts[0].y, 0.0, 1.0)
		if g.rng.randf() < g.dead_share * (0.5 + low):
			pc.dead = true
	# Orders 2 and 3, breadth first, within budget.
	var level := l1
	for order in range(2, g.max_order + 1):
		level = _order(g, level, order, int((MAX_L2 if order == 2 else MAX_TWIGS) * g.budget))
	_anchors(g)
	return g.sk


## Order-1 branches along a stem: whorls or a spiral from the crown base up,
## as long as the crown's form wants there; stubs below it when self-pruned.
static func _laterals_on_stem(g: _G, st: int, excurrent: bool) -> Array[int]:
	var out: Array[int] = []
	var pc: TreeLayouts.Piece = g.sk.pieces[st]
	var total := pc.length()
	var whorl := g.model in ["massart", "aubreville"]
	var y_top := pc.pts[pc.pts.size() - 1].y
	var s := 0.0
	var az := g.rng.randf() * TAU
	var step := g.spacing
	# Budget: fewer, wider-spaced limbs on a tall crown.
	var count_est := total * (1.0 - g.crown_base) / step * (4.5 if whorl else 1.0)
	var cap := int((MAX_L1_WHORL if whorl else MAX_L1) * g.budget)
	if count_est > cap:
		step *= count_est / cap
	# A broad crown (not a single leader, not whorls) stands on a few big
	# scaffold limbs, thick where they leave the stem and slow to taper,
	# that carry the rest (from play: the trees that look best are the
	# ones with big main branches, and they're the ones you can climb and
	# perch on): 5-8 of them over the crown's length on each stem.
	var scaffold := not excurrent and not whorl
	if scaffold:
		var crown_len := maxf(total * (1.0 - clampf((g.crown_base - pc.pts[0].y) / maxf(y_top - pc.pts[0].y, 1e-3), 0.0, 0.9)), 0.05)
		step = maxf(step, crown_len / g.rng.randi_range(5, 8))
	while s < total * 0.97:
		var q := pc.at(s)
		var p: Vector3 = q[0]
		var r_here: float = q[2]
		var y_rel := p.y
		if y_rel < g.crown_base:
			# Below the crown: self-pruned stubs (collars) in a stand.
			if g.forest and g.self_prune and y_rel > 0.08 and g.rng.randf() < 0.55:
				var sd := Vector3(cos(az), 0.15, sin(az)).normalized()
				out_stub(g, st, p, sd, r_here)
			az += 2.39996
			s += step * g.rng.randf_range(0.8, 1.2)
			continue
		var n := g.rng.randi_range(4, 6) if whorl else 1
		# How long the crown wants a limb here (0 at the crown's foot, 1 at
		# its top): a cone for excurrent crowns, a dome for the rest.
		var u := inverse_lerp(g.crown_base, maxf(y_top, g.crown_base + 0.05), y_rel)
		var prof := (1.0 - u) * 0.9 + 0.1 if excurrent else sin(PI * clampf(u * 0.85 + 0.15, 0.0, 1.0))
		if g.slot > 0 and g.juv != "cone" and excurrent:
			# A young whip: short laterals all the way up, a little longer
			# in the middle, not the adult's cone.
			prof = 0.45 + 0.55 * sin(PI * clampf(u * 0.8 + 0.1, 0.0, 1.0))
		for k in n:
			var a := az + TAU * k / n + g.rng.randf_range(-0.25, 0.25)
			var ang := g.rng.randf_range(g.angle.x, g.angle.y)
			var d := Vector3(cos(a) * sin(ang), cos(ang), sin(a) * sin(ang)).normalized()
			var length := g.crown_r * prof / maxf(sin(ang), 0.35) * g.rng.randf_range(0.8, 1.15)
			# (The top whorls stay short, but they're there: a spire of
			# shoots to the leader's tip, not a bare pole.)
			length = maxf(length, 0.025)
			var lift := 0.18 - g.droop * 0.4
			if g.model == "troll" or g.habit == "weeping":
				lift = -0.25 - g.droop * 0.5
			var r_c := r_here * g.rng.randf_range(0.45, 0.6)
			var r_tip := r_c * 0.35
			if scaffold:
				r_c = r_here * g.rng.randf_range(0.62, 0.78)
				r_tip = r_c * 0.45
				length *= 1.1
			out.append(g.piece(p, d, length, r_c, r_tip, lift, K.LIMB, 1, st, 0))
		az += 2.39996 if not whorl else g.rng.randf_range(0.4, 1.0)
		s += step * g.rng.randf_range(0.8, 1.2)
	return out


## Stubs' limb numbers start here (past any real limb's).
const STUB_LIMB := 100000


## A self-pruned stub: a short dead piece with its collar.
static func out_stub(g: _G, parent: int, p: Vector3, d: Vector3, r_here: float) -> void:
	var r := r_here * 0.3
	var i := g.piece(p, d, g.rng.randf_range(0.012, 0.03), r * 1.3, r, 0.0, K.BRANCH, 1, parent, 0, true)
	# Its own limb (not 0, the trunk's): a climber took a stub for the
	# trunk and stopped on it.
	g.sk.pieces[i].limb = STUB_LIMB + i


## Sympodial / dichotomous crowns: `order` pieces forking from a tip.
static func _fork(g: _G, parent: int, order: int, at: Vector3, dir: Vector3, r_parent: float) -> Array[int]:
	var out: Array[int] = []
	var n := 2 if g.model == "schoute" else g.rng.randi_range(2, 3)
	var az := g.rng.randf() * TAU
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
	var side2 := dir.cross(side).normalized()
	for k in n:
		var a := az + TAU * k / n
		var spread := g.rng.randf_range(g.angle.x, g.angle.y) * 0.8
		var d := (dir * cos(spread) + (side * cos(a) + side2 * sin(a)) * sin(spread)).normalized()
		var length := g.crown_r * (0.55 if g.habit == "candelabra" else 0.7) * g.rng.randf_range(0.8, 1.15)
		# Leonardo: the tip's section shared among the forks.
		var r_c := r_parent / sqrt(float(n))
		out.append(g.piece(at, d, length, r_c, r_c * 0.7, 0.15, K.LIMB, order, parent, 0))
	return out


## One order of branching over the pieces of the order above: children
## along the outer part of each parent at a spacing that keeps the whole
## order within `budget`, by the leaf arrangement's phyllotaxis; forking
## programs fork again at the tips instead.
static func _order(g: _G, parents: Array[int], order: int, budget: int) -> Array[int]:
	var out: Array[int] = []
	var forking := g.model in ["leeuwenberg", "koriba", "schoute"]
	var start_f := 0.25 if order == 2 else 0.4
	var total := 0.0
	for pi in parents:
		var pc: TreeLayouts.Piece = g.sk.pieces[pi]
		if pc.dead and order > 2:
			continue
		total += pc.length() * (1.0 - start_f)
	var pairs_n := 2.0 if g.arrangement in ["opposite", "decussate"] else 1.0
	var step := maxf(g.spacing * pow(0.45, order - 1), total * pairs_n * 1.1 / maxf(float(budget), 1.0))
	var kind := K.BRANCH if order == 2 else K.TWIG
	# In a shuffled order, so that if the budget runs out it runs out
	# evenly over the crown, not all at the top.
	var queue: Array[int] = parents.duplicate()
	for i in range(queue.size() - 1, 0, -1):
		var jj := g.rng.randi_range(0, i)
		var t := queue[i]
		queue[i] = queue[jj]
		queue[jj] = t
	for pi in queue:
		var pc: TreeLayouts.Piece = g.sk.pieces[pi]
		if pc.dead and order > 2:
			continue
		var length := pc.length()
		if forking and order == 2:
			var tip := pc.pts[pc.pts.size() - 1]
			var d0 := (tip - pc.pts[pc.pts.size() - 2]).normalized()
			for c in _fork(g, pi, order, tip, d0, pc.rad[pc.rad.size() - 1]):
				var cp: TreeLayouts.Piece = g.sk.pieces[c]
				cp.kind = K.BRANCH
				cp.limb = pc.limb
				cp.dead = pc.dead
				out.append(c)
		var s := length * start_f
		var rot := g.rng.randf() * TAU
		var turn := 2.39996
		match g.arrangement:
			"opposite", "decussate", "distichous", "alternate":
				turn = PI
			"whorled":
				turn = TAU / 3.0
		while s < length * 0.96:
			var q := pc.at(s)
			var p: Vector3 = q[0]
			var tan: Vector3 = q[1]
			var r_here: float = q[2]
			var side := tan.cross(Vector3.UP)
			side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
			var side2 := tan.cross(side).normalized()
			var pairs := 2 if g.arrangement in ["opposite", "decussate"] else 1
			for k in pairs:
				var a := rot + PI * k
				var spread := deg_to_rad(g.rng.randf_range(35.0, 55.0))
				var d := (tan * cos(spread) + (side * cos(a) + side2 * sin(a)) * sin(spread)).normalized()
				# Shorter toward the parent's tip.
				var u := s / length
				var cl := length * g.rng.randf_range(0.4, 0.6) * (1.0 - 0.55 * u)
				if order >= 3:
					cl = minf(cl, maxf(g.cluster_r * 3.0, length * 0.3))
				if cl < 0.006:
					continue
				# Leonardo: parent² = continuing² + child².
				var r_c := r_here * 0.62
				var lift := 0.22 - g.droop * 0.6 * float(order - 1)
				if g.model == "troll" or g.habit == "weeping":
					lift -= 0.3
				var c := g.piece(p, d, cl, r_c, r_c * 0.5, lift, kind, order, pi, pc.limb, pc.dead)
				out.append(c)
				if out.size() >= budget:
					return out
			rot += turn + g.rng.randf_range(-0.3, 0.3)
			s += step * g.rng.randf_range(0.8, 1.25)
	return out


## Leaf anchors on the outermost living wood (design §AL): along the outer
## 60 % of each twig (the finest order grown), at a cluster's spacing,
## side to side by the arrangement; thinned by canopy.gap, grouped by
## layering; forest-grown crowns keep the top and the outer face.
static func _anchors(g: _G) -> void:
	_place_anchors(g)
	_size_clusters(g, g.crown_r)


## Clusters big enough that the crown, seen from outside, is 1 - gap
## covered (§AJ 2): the crown's silhouette area (a dome of crown_r, a bit
## more for its depth) shared among the anchors; never smaller than the
## leaf-based size, at most an eighth of the tree.
static func _size_clusters(g: _G, crown_r: float, fit := true) -> void:
	var n := g.sk.anchors.size()
	if n == 0:
		return
	var target := PI * crown_r * crown_r * 1.6 * (1.0 - g.gap)
	var r := clampf(sqrt(target / (n * PI * 0.8)), g.cluster_r, 0.125)
	for an in g.sk.anchors:
		an[5] = r * g.rng.randf_range(0.85, 1.15)
	# (A palm's crown is its fronds: their leaflets stay full, the gaps are
	# between the fronds.)
	if fit:
		_fit_gap(g)


## Then all scaled together until, looking straight up from under the
## crown, the share of sky that gets through is the species' canopy.gap
## (§AJ 4, the see-through test): the clusters seen from below rastered on
## a small grid, each passing `gap` of the light (its cards are cut out to
## it), overlaps multiplying; the mean over the middle of the crown's
## footprint (where you'd stand and look up), by bisection on the scale.
static func _fit_gap(g: _G) -> void:
	var an: Array = g.sk.anchors
	var reach := 0.0
	for a in an:
		var p: Vector3 = a[0]
		reach = maxf(reach, Vector2(p.x, p.z).length())
	if reach < 1e-3:
		return
	var lo := 0.4
	var hi := 3.0
	for it in 9:
		var mid := (lo + hi) * 0.5
		if _sky_share(an, reach, mid, g.gap) > g.gap:
			lo = mid
		else:
			hi = mid
	var k := (lo + hi) * 0.5
	for a in an:
		a[5] = minf(float(a[5]) * k, 0.2)


const FIT_N := 24


## The share of sky seen from below through the middle of the footprint
## (radius `reach` * 0.75) with every cluster's radius times `k`.
static func _sky_share(an: Array, reach: float, k: float, gap: float) -> float:
	var n := FIT_N
	var cell := reach * 2.0 / n
	var trans := PackedFloat32Array()
	trans.resize(n * n)
	trans.fill(1.0)
	for a in an:
		var p: Vector3 = (a[0] as Vector3) + (a[2] as Vector3) * float(a[5]) * 0.45
		var rr: float = float(a[5]) * 0.9 * k
		var cx := (p.x + reach) / cell
		var cz := (p.z + reach) / cell
		var rp := rr / cell
		for z in range(maxi(0, int(cz - rp)), mini(n, int(cz + rp) + 1)):
			for x in range(maxi(0, int(cx - rp)), mini(n, int(cx + rp) + 1)):
				var dx := x + 0.5 - cx
				var dz := z + 0.5 - cz
				if dx * dx + dz * dz <= rp * rp:
					trans[z * n + x] *= gap
	var sum := 0.0
	var cnt := 0
	var r2 := (n * 0.5 * 0.75) * (n * 0.5 * 0.75)
	for z in n:
		for x in n:
			var dx := x + 0.5 - n * 0.5
			var dz := z + 0.5 - n * 0.5
			if dx * dx + dz * dz <= r2:
				sum += trans[z * n + x]
				cnt += 1
	return sum / maxf(cnt, 1)


static func _place_anchors(g: _G) -> void:
	var finest := 0
	for pc in g.sk.pieces:
		if not pc.dead and pc.kind != K.TRUNK:
			finest = maxi(finest, pc.order)
	var total := 0.0
	for pc in g.sk.pieces:
		if pc.order == finest and not pc.dead:
			total += pc.length() * 0.6
	var max_anchors := int(MAX_ANCHORS * g.budget)
	var step := maxf(g.cluster_r * 1.5, total / max_anchors)
	var keep := clampf(1.0 - g.gap * 0.45, 0.3, 1.0)
	# Twigs in a shuffled order: if the anchors run out, they run out
	# evenly over the crown.
	var twigs: Array[int] = []
	for pi in g.sk.pieces.size():
		var pc: TreeLayouts.Piece = g.sk.pieces[pi]
		if pc.order == finest and not pc.dead:
			twigs.append(pi)
	for i in range(twigs.size() - 1, 0, -1):
		var jj := g.rng.randi_range(0, i)
		var t := twigs[i]
		twigs[i] = twigs[jj]
		twigs[jj] = t
	for pi in twigs:
		var pc: TreeLayouts.Piece = g.sk.pieces[pi]
		var length := pc.length()
		var s := length
		var flip := 1.0
		while s >= length * 0.4:
			var q := pc.at(s)
			var p: Vector3 = q[0]
			var tan: Vector3 = q[1]
			s -= step * g.rng.randf_range(0.8, 1.2)
			if g.rng.randf() > keep:
				continue
			var outer := Vector2(p.x, p.z).length() / maxf(g.crown_r, 0.05)
			match g.layering:
				"clumped":
					if _cell_noise(p, 0.09) < 0.3:
						continue
				"tiered":
					if fposmod(p.y / maxf(g.spacing * 2.0, 0.04), 1.0) > 0.62:
						continue
				"sparse":
					if g.rng.randf() < 0.35:
						continue
			if g.forest and p.y < g.crown_base + (1.0 - g.crown_base) * 0.35 and outer < 0.55:
				continue
			var side := tan.cross(Vector3.UP)
			side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
			var sides: Array[float] = [flip]
			if g.arrangement in ["opposite", "decussate", "whorled"]:
				sides = [1.0, -1.0]
			for sd in sides:
				var hang := (side * sd + Vector3.UP * (0.45 - g.droop)).normalized()
				g.sk.anchors.append([p, tan, hang, pi, clampf(outer, 0.0, 1.0), g.cluster_r * g.rng.randf_range(0.85, 1.15)])
			flip = -flip
			if g.sk.anchors.size() >= max_anchors:
				return


## A 0-1 value per cell of `size` around p (clumps of leaves).
static func _cell_noise(p: Vector3, size: float) -> float:
	var c := Vector3i((p / size).floor())
	return float(absi(hash(c)) % 1000) / 1000.0


## Buttress fins at the foot: low (1-3 m) or high (3-9 m) planks.
static func _fins(g: _G, kind: String, r0: float) -> void:
	if kind == "none" or kind == "":
		return
	var n := g.rng.randi_range(4, 6)
	var hgt := (2.0 if kind.begins_with("low") else 6.0) / g.h_m
	var az := g.rng.randf() * TAU
	for k in n:
		var a := az + TAU * k / n + g.rng.randf_range(-0.3, 0.3)
		g.sk.fins.append([Vector3(cos(a), 0.0, sin(a)), g.j(hgt), r0 * g.rng.randf_range(2.5, 4.5)])


## Palms and tree ferns: the column (a stem or a few, tomlinson) and the
## fronds from its crown point: each a rachis (a thin frond piece) arching
## out and drooping (canopy.droop), its leaflets anchored along both sides;
## a tree fern's dead fronds hang as a skirt below.
static func _palm(g: _G, a: Dictionary) -> void:
	var fern := g.habit == "tree_fern"
	var n_stems := g.rng.randi_range(2, 3) if g.model == "tomlinson" and g.habit == "multi_stem" else 1
	var r0 := 0.5 / g.j(70.0 if not fern else 35.0)
	# Young (design §AR): a sapling is the stemless rosette of the
	# establishment years, fronds straight from the ground, fewer and more
	# upright, the first ones undivided (eophylls) when its juvenile leaves
	# differ; a young tree a short trunk under a smaller crown.
	var eophylls := g.slot == 2 and str(g.sp.growth.get("juvenile_leaves", "same")) == "different"
	for sidx in n_stems:
		var lean := Vector3.ZERO if n_stems == 1 else Vector3(g.rng.randf_range(-0.25, 0.25), 0.0, g.rng.randf_range(-0.25, 0.25))
		var top_h := 0.82 if not fern else 0.8
		if n_stems > 1:
			top_h *= g.rng.randf_range(0.7, 1.0)
		if g.slot == 2:
			top_h = 0.03
		elif g.slot == 1:
			top_h *= 0.5
		var d := (Vector3.UP + lean).normalized()
		var st := g.trunk(Vector3(lean.x, 0, lean.z) * 0.1, d, top_h, r0 * (1.2 if not fern else 1.0), r0 * 0.85, bool(a.get("root_flare", true)), -1)
		var pc: TreeLayouts.Piece = g.sk.pieces[st]
		var top := pc.pts[pc.pts.size() - 1]
		var n := g.rng.randi_range(14, 20) if not fern else g.rng.randi_range(10, 15)
		var frond_l := (0.26 if not fern else 0.36) * g.rng.randf_range(0.85, 1.15)
		var droop := clampf(g.droop, 0.0, 1.0)
		var el_hi := 70.0
		var el_lo := -5.0
		if g.slot == 2:
			n = g.rng.randi_range(5, 8)
			frond_l = 0.9 * g.rng.randf_range(0.85, 1.1)
			droop *= 0.5
			el_hi = 80.0
			el_lo = 32.0
		elif g.slot == 1:
			n = g.rng.randi_range(9, 13)
			frond_l = 0.45 * g.rng.randf_range(0.85, 1.1)
			el_hi = 75.0
			el_lo = 8.0
		for k in n:
			var az := TAU * k * 0.382 + g.rng.randf_range(-0.2, 0.2)
			# Young fronds stand up in the middle, old ones splay and hang.
			var el := lerpf(deg_to_rad(el_hi), deg_to_rad(el_lo), float(k) / n)
			var fd := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)).normalized()
			# (Arching: the older, lower fronds bow more toward their tips.)
			var arch_k := -(droop * 0.9 + 0.35 * float(k) / n)
			var f := g.piece(top, fd, frond_l * g.rng.randf_range(0.85, 1.1), r0 * 0.35, r0 * 0.08, arch_k, K.TWIG, 1, st, k + 1)
			var fp: TreeLayouts.Piece = g.sk.pieces[f]
			fp.frond = true
			var length := fp.length()
			var s := length * 0.15
			# A clump of stems (a date palm's suckers) shares one tree's
			# anchor budget (MAX_ANCHORS): leaflets sit farther apart.
			var step := maxf(g.cluster_r * 1.2, length / 14.0) * float(n_stems)
			if eophylls:
				# An undivided first leaf: a few broad leaflets make a strap.
				step *= 2.2
			while s < length * 0.98:
				var q := fp.at(s)
				var p: Vector3 = q[0]
				var tan: Vector3 = q[1]
				var side := tan.cross(Vector3.UP)
				side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
				# Leaflets both sides, hanging in a V below the rachis.
				for sd in [1.0, -1.0]:
					var hang: Vector3 = (side * sd + Vector3.DOWN * 0.45).normalized()
					g.sk.anchors.append([p, tan, hang, f, 1.0, g.cluster_r * g.rng.randf_range(0.9, 1.1)])
				s += step
		# A tree fern's skirt: dead fronds hanging against the trunk.
		if fern and g.dead_share > 0.0 and g.slot == 0:
			for k in int(n * g.dead_share):
				var az := g.rng.randf() * TAU
				var fd := Vector3(cos(az) * 0.35, -1.0, sin(az) * 0.35).normalized()
				g.piece(top - Vector3(0, 0.02, 0), fd, frond_l * 0.7, r0 * 0.25, r0 * 0.1, 0.0, K.TWIG, 1, st, 0, true)
	g.sk.vines = 0
	var crown := (0.26 if not fern else 0.36) if g.slot == 0 else (0.45 if g.slot == 1 else 0.8)
	_size_clusters(g, crown, false)
	if eophylls:
		for an in g.sk.anchors:
			an[5] = float(an[5]) * 1.6

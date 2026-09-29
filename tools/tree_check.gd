extends SceneTree
## Trees grown from their architecture (design §AK, §AL; TreeArch), checked
## headless on the skeletons themselves:
##   - every woody tree species in the tree tiers with a block grows from
##     it, within budget;
##   - every leaf anchor lies on the wood of its piece, and that piece is
##     a twig (order 3+) or a palm frond, never the trunk (no floating
##     leaves, §AL 1);
##   - Leonardo: no child is thicker where it leaves its parent than the
##     parent is there;
##   - open-grown layouts carry their crown lower than forest-grown ones;
##     forest-grown self-pruning species leave stubs below the crown;
##   - dead limbs carry no leaves;
##   - model programs: a massart conifer has whorls, a palm has fronds and
##     no branches, a leeuwenberg crown forks;
##   - handholds come from the skeleton (a branch graph for an oak) and
##     never lie on twigs.
## Prints a line per sample species (pieces by order, anchors, crown base).
##
##   ~/bin/godot --headless --path . --script tools/tree_check.gd

const SAMPLE := ["Oak", "Beech", "Spruce", "Scots pine", "Coconut palm", "Baobab", "Paper birch"]

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TreeLayouts.use_seed(42)
	var all := SpeciesDB.all()
	var growing := 0
	var over := 0
	var floating := 0
	var not_twig := 0
	var leonardo := 0
	var dead_leaves := 0
	var anchors_total := 0
	var leo_by := {}
	for idx in all.size():
		var sp: PlantSpecies = all[idx]
		if not TreeArch.grows(sp):
			continue
		growing += 1
		for layout in [0, TreeLayouts.COUNT / 2]:
			var sk := TreeLayouts.skeleton(idx, layout)
			var counts := {}
			for pc in sk.pieces:
				counts[pc.order] = int(counts.get(pc.order, 0)) + 1
			if int(counts.get(2, 0)) > TreeArch.MAX_L2 + 10 or int(counts.get(3, 0)) > TreeArch.MAX_TWIGS + 10 or sk.anchors.size() > TreeArch.MAX_ANCHORS + 2:
				over += 1
			for an in sk.anchors:
				anchors_total += 1
				var pc: TreeLayouts.Piece = sk.pieces[an[3]]
				if _dist_to(pc, an[0]) > 1e-4:
					floating += 1
				if pc.kind == TreeLayouts.Kind.TRUNK or (pc.order < 2 and not pc.frond):
					not_twig += 1
				if pc.dead:
					dead_leaves += 1
			for pc in sk.pieces:
				if pc.parent < 0:
					continue
				var parent: TreeLayouts.Piece = sk.pieces[pc.parent]
				if pc.rad[0] > _radius_at(parent, pc.pts[0]) * 1.05 + 1e-6 and pc.kind != TreeLayouts.Kind.TRUNK:
					leonardo += 1
					var k := "%s o%d %s" % [sp.arch.get("model"), pc.order, "frond" if pc.frond else ("dead" if pc.dead else "")]
					leo_by[k] = int(leo_by.get(k, 0)) + 1
	print("[trees] %d species grow from their architecture; %d anchors checked" % [growing, anchors_total])
	ok(growing > 140, "the tree-tier species with architecture blocks grow from them (%d)" % growing)
	ok(over == 0, "every layout within budget (%d over)" % over)
	ok(floating == 0, "every leaf anchor lies on its wood (%d off it)" % floating)
	ok(not_twig == 0, "leaves hang only on twigs or fronds (%d on thicker wood)" % not_twig)
	if not leo_by.is_empty():
		print("[trees] Leonardo breaks: %s" % leo_by)
	ok(leonardo == 0, "Leonardo: no child thicker than its parent where it leaves it (%d)" % leonardo)
	ok(dead_leaves == 0, "dead limbs are bare (%d anchors on deadwood)" % dead_leaves)

	for name in SAMPLE:
		var sp := SpeciesDB.find(name)
		if sp == null or not TreeArch.grows(sp):
			print("[trees] %s: not grown from architecture" % name)
			continue
		var idx := SpeciesDB.index_of(sp)
		var open_sk := TreeLayouts.skeleton(idx, 0)
		var forest_sk := TreeLayouts.skeleton(idx, TreeLayouts.COUNT / 2)
		print("[trees] %-13s %-11s %-11s open: %s, crown from %.2f; forest: %s, crown from %.2f, %d stubs" % [name, sp.arch.get("model"), sp.arch.get("habit"),
			_by_order(open_sk), _crown_base(open_sk), _by_order(forest_sk), _crown_base(forest_sk), _stubs(forest_sk)])
	var oak := SpeciesDB.find("Oak")
	var oi := SpeciesDB.index_of(oak)
	ok(_crown_base(TreeLayouts.skeleton(oi, 0)) < _crown_base(TreeLayouts.skeleton(oi, TreeLayouts.COUNT / 2)), "an open-grown oak carries its crown lower than one in a stand")
	var pine := SpeciesDB.find("Scots pine")
	ok(_stubs(TreeLayouts.skeleton(SpeciesDB.index_of(pine), TreeLayouts.COUNT / 2)) > 0, "a forest-grown Scots pine (self-pruning) has stubs below its crown")
	var spruce := SpeciesDB.find("Spruce")
	ok(_whorls(TreeLayouts.skeleton(SpeciesDB.index_of(spruce), 0)) >= 5, "a spruce (massart) grows whorls (%d)" % _whorls(TreeLayouts.skeleton(SpeciesDB.index_of(spruce), 0)))
	var palm := SpeciesDB.find("Coconut palm")
	var psk := TreeLayouts.skeleton(SpeciesDB.index_of(palm), 0)
	var fronds := 0
	var limbs := 0
	for pc in psk.pieces:
		fronds += 1 if pc.frond else 0
		limbs += 1 if pc.kind == TreeLayouts.Kind.LIMB else 0
	ok(fronds >= 12 and limbs == 0, "a coconut palm: a column and %d fronds, no branches" % fronds)
	# Handholds from the skeleton.
	var g := TreeLayouts.graph(oi, 0, 18.0)
	ok(g != null and g.local.size() > 20, "an 18 m oak's branch graph comes from its skeleton (%d handholds)" % (g.local.size() if g else 0))
	var holds := TreeLayouts.unit_handholds(oi, 0, 18.0)
	var twig_holds := 0
	var sk := TreeLayouts.skeleton(oi, 0)
	for p in (holds[0] as PackedVector3Array):
		var best := INF
		var best_kind := -1
		for pc in sk.pieces:
			var dd := _dist_to(pc, p)
			if dd < best:
				best = dd
				best_kind = pc.kind
		if best_kind == TreeLayouts.Kind.TWIG:
			twig_holds += 1
	ok(twig_holds == 0, "no handhold on a twig (%d)" % twig_holds)
	# Colliders (design §AM 1): limbs and branches; twigs of 4 cm and up
	# only on their own (the 30 m ring); nothing on fronds.
	var limbs_n := TreeLayouts.collider_segments(sk, 18.0, false, true).size()
	var twigs_n := TreeLayouts.collider_segments(sk, 18.0, false, true, true).size()
	var twigs_big := TreeLayouts.collider_segments(sk, 40.0, false, true, true).size()
	print("[trees] an 18 m oak: %d limb and branch capsules, %d twig capsules (4 cm and up, within 30 m); at 40 m, %d twig capsules" % [limbs_n, twigs_n, twigs_big])
	ok(limbs_n > 60, "orders 1-2 get capsules (%d)" % limbs_n)
	ok(twigs_big > twigs_n, "only a big tree's twigs are thick enough to stand on (%d at 40 m, %d at 18 m)" % [twigs_big, twigs_n])
	var palm_twigs := TreeLayouts.collider_segments(psk, 20.0, false, true, true).size()
	ok(palm_twigs == 0, "no capsules on a palm's fronds (%d)" % palm_twigs)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The wood's radius where `p` projects onto the piece (interpolated).
func _radius_at(pc: TreeLayouts.Piece, p: Vector3) -> float:
	var best := INF
	var r := pc.rad[0]
	for i in pc.pts.size() - 1:
		var a := pc.pts[i]
		var ab := pc.pts[i + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
		var d := (a + ab * t).distance_to(p)
		if d < best:
			best = d
			r = lerpf(pc.rad[i], pc.rad[i + 1], t)
	return r


func _dist_to(pc: TreeLayouts.Piece, p: Vector3) -> float:
	var best := INF
	for i in pc.pts.size() - 1:
		var a := pc.pts[i]
		var b := pc.pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best


func _by_order(sk: TreeLayouts.Skeleton) -> String:
	var c := {}
	for pc in sk.pieces:
		c[pc.order] = int(c.get(pc.order, 0)) + 1
	var keys := c.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("o%d %d" % [k, c[k]])
	return "%s, %d anchors" % [", ".join(parts), sk.anchors.size()]


## The height of the lowest living order-1 limb (the live crown's foot).
func _crown_base(sk: TreeLayouts.Skeleton) -> float:
	var lo := 1.0
	for pc in sk.pieces:
		if pc.order == 1 and not pc.dead and pc.kind == TreeLayouts.Kind.LIMB:
			lo = minf(lo, pc.pts[0].y)
	return lo


func _stubs(sk: TreeLayouts.Skeleton) -> int:
	var n := 0
	for pc in sk.pieces:
		if pc.order == 1 and pc.dead and pc.kind == TreeLayouts.Kind.BRANCH:
			n += 1
	return n


## Heights where three or more order-1 limbs leave the stem together.
func _whorls(sk: TreeLayouts.Skeleton) -> int:
	var at := {}
	for pc in sk.pieces:
		if pc.order == 1 and pc.kind == TreeLayouts.Kind.LIMB:
			var k := int(round(pc.pts[0].y * 1000.0))
			at[k] = int(at.get(k, 0)) + 1
	var n := 0
	for k in at:
		n += 1 if int(at[k]) >= 3 else 0
	return n

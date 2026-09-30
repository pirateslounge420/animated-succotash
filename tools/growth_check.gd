extends SceneTree
## Plant growth at real rates, the young and shade leaves (design §AR;
## PlantGrowth, TreeArch's young layouts, PlantMeshes' young meshes), with
## no world: the researched curves hit their data, the stages, the
## understory's young by light (a tolerant fir's seedling bank in the
## shade, a pine's young only in the gaps), a young tree growing on with
## the clock, leaf sizes (shade bigger, and the custom data's packing),
## the young layouts' picks, and young skeletons and meshes for every
## young form (a whip, a cone, several stems, a palm's stemless rosette).
##
##   godot --headless --path . --script tools/growth_check.gd

var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _find(binomial: String) -> PlantSpecies:
	for sp in SpeciesDB.all():
		if sp.binomial() == binomial:
			return sp
	return null


func _run() -> void:
	var all := SpeciesDB.all()
	# Every species has a curve that reaches its data.
	var worst := 0.0
	var with_data := 0
	var steep := PackedStringArray()
	for sp in all:
		var hy = sp.growth.get("height_years")
		if not (hy is Array) or sp.growth.has("stages"):
			continue
		with_data += 1
		# (A curve of this family can't rise from half to 90 % in under
		# half as long again: those few get the steepest one.)
		if float(hy[1]) / float(hy[0]) < 1.5:
			steep.append(sp.name)
			continue
		worst = maxf(worst, absf(PlantGrowth.fraction(sp, float(hy[0])) - 0.5))
		worst = maxf(worst, absf(PlantGrowth.fraction(sp, float(hy[1])) - 0.9))
	ok(with_data > 900, "researched growth for %d species" % with_data)
	ok(worst < 0.02, "every curve passes through half height and 90%% at its researched years (worst off by %.3f; too steep to fit: %s)" % [worst, ", ".join(steep)])
	var pine := _find("Pinus sylvestris")
	var fir := _find("Abies balsamea")
	if fir == null:
		for sp in all:
			if sp.genus == "Abies" and sp.shade_tol >= 0.75:
				fir = sp
				break
	ok(pine != null and fir != null, "a light-hungry pine and a shade-tolerant fir to compare (%s, %s)" % [pine.name if pine else "?", fir.name if fir else "?"])
	if pine == null or fir == null:
		print("RESULT fails: %d" % fails)
		quit()
		return
	ok(pine.shade_tol < 0.3 and fir.shade_tol >= 0.75, "Scots pine is shade-intolerant, the fir tolerant (%.2f, %.2f)" % [pine.shade_tol, fir.shade_tol])
	ok(PlantGrowth.age_of(pine, PlantGrowth.fraction(pine, 20.0)) - 20.0 < 0.01, "age_of undoes fraction")
	# Stages.
	var h := 30.0
	ok(PlantGrowth.stage_of(pine, 0.02, 2.0, h) == PlantGrowth.Stage.SEEDLING, "a 60 cm pine is a seedling")
	ok(PlantGrowth.stage_of(pine, 0.2, 10.0, h) == PlantGrowth.Stage.SAPLING, "a 6 m pine is a sapling")
	ok(PlantGrowth.stage_of(pine, 0.5, 30.0, h) == PlantGrowth.Stage.POLE, "a 15 m pine is a young tree")
	ok(PlantGrowth.stage_of(pine, 0.95, 120.0, h) == PlantGrowth.Stage.MATURE, "a 29 m pine of 120 years is grown")
	ok(PlantGrowth.stage_of(pine, 0.98, pine.lifespan_y.x, h) == PlantGrowth.Stage.OLD, "and old past three quarters of its life")
	# The understory's young by light: 2,000 spots each.
	var counts := {}
	for sp in [pine, fir]:
		for light in [0.08, 0.8]:
			var n := 0
			var saplings := 0
			for i in 2000:
				var now := PlantGrowth.understory(sp, hash([sp.name, i, light]), light, 25.0)
				if not now.is_empty():
					n += 1
					if int(now[1]) == PlantGrowth.Stage.SAPLING:
						saplings += 1
			counts["%s %.2f" % [sp.name, light]] = [n, saplings]
	print("      understory occupants of 2000 spots [plants, saplings]: %s" % str(counts))
	var fir_shade: Array = counts["%s 0.08" % fir.name]
	var pine_shade: Array = counts["%s 0.08" % pine.name]
	var pine_gap: Array = counts["%s 0.80" % pine.name]
	ok(int(fir_shade[0]) > int(pine_shade[0]) * 2, "under a closed canopy the fir keeps a seedling bank, the pine barely any (%d vs %d)" % [fir_shade[0], pine_shade[0]])
	ok(int(pine_gap[1]) > int(pine_shade[1]) + 20, "in a gap the pine has saplings (%d vs %d in the shade)" % [pine_gap[1], pine_shade[1]])
	# A young tree grows on with the clock (a decade of game years).
	var d := Vector3(0.3, 0.8, 0.52).normalized()
	PlantGrowth.now_days = PlantGrowth.EPOCH_DAYS
	var h0: float = PlantGrowth.young_tree(pine, d, 30.0)[0]
	PlantGrowth.now_days = PlantGrowth.EPOCH_DAYS + 3650.0
	var h1: float = PlantGrowth.young_tree(pine, d, 30.0)[0]
	PlantGrowth.now_days = PlantGrowth.EPOCH_DAYS
	ok(h1 > h0 + 0.5, "a young pine is taller ten game years on (%.1f m -> %.1f m: 3.65 real days a year of its life)" % [h0, h1])
	# Leaf size: shade leaves bigger, sun leaves smaller; the packing.
	var shade_l := PlantGrowth.leaf_scale(fir, 0.05)
	var sun_l := PlantGrowth.leaf_scale(fir, 1.0)
	ok(shade_l > 1.3 and sun_l < 0.9, "a fir's leaves: %.2fx in deep shade, %.2fx in full sun" % [shade_l, sun_l])
	ok(PlantGrowth.leaf_scale(pine, 0.05) < shade_l, "the tolerant species change more (pine %.2fx)" % PlantGrowth.leaf_scale(pine, 0.05))
	var green := PlantGrowth.encode_green(0.37, PlantGrowth.leaf_code(shade_l))
	ok(absf(PlantGrowth.vines_of(green) - 0.37) < 1e-4 and absf(PlantGrowth.leaf_of(green) - shade_l) < 0.026, "vines and leaf size share the custom data's green (%.3f -> %.2f, %.2fx)" % [green, PlantGrowth.vines_of(green), PlantGrowth.leaf_of(green)])
	ok(PlantGrowth.leaf_of(0.5) == 1.0, "an old buffer (vines only) reads as full-size leaves")
	ok(absf(PlantGrowth.vines_of(PlantGrowth.encode_green(1.0, 16)) - 1.0) < 1e-4, "full vines survive the top code")
	# Picks carry a young slot and give it back.
	var picks_ok := true
	for p in 2 * TreeLayouts.COUNT:
		for slot in TreeLayouts.SLOTS:
			var q := TreeLayouts.with_slot(p, slot)
			var sub := p % TreeLayouts.COUNT
			if slot > 0:
				sub = 0 if sub < TreeLayouts.COUNT / 2 else TreeLayouts.COUNT / 2
			if TreeLayouts.layout_of(q) != sub + slot * TreeLayouts.COUNT or TreeLayouts.is_mirrored(q) != (p >= TreeLayouts.COUNT):
				picks_ok = false
	ok(picks_ok, "every pick at every young slot reads back its layout (open- or forest-grown) and mirroring")
	ok(TreeLayouts.layout_of(-1) == -1 and not TreeLayouts.is_mirrored(-1), "no pick is no layout")
	# Young skeletons and meshes, one species per young form.
	var forms := {}
	for sp in all:
		if TreeArch.grows(sp) and not forms.has(sp.juvenile):
			forms[sp.juvenile] = sp
	print("      young forms among the trees: %s" % str(forms.keys()))
	var idx_of := func(sp: PlantSpecies) -> int: return SpeciesDB.index_of(sp)
	for form in forms:
		var sp: PlantSpecies = forms[form]
		var idx: int = idx_of.call(sp)
		var grown := TreeLayouts.skeleton(idx, 0)
		var sap := TreeLayouts.skeleton(idx, 2 * TreeLayouts.COUNT)
		var pole := TreeLayouts.skeleton(idx, TreeLayouts.COUNT)
		ok(sap.pieces.size() > 0 and sap.anchors.size() > 0 and pole.anchors.size() > 0,
			"%s (%s): a sapling (%d pieces, %d leaf clusters) and a young tree (%d pieces)" % [sp.name, form, sap.pieces.size(), sap.anchors.size(), pole.pieces.size()])
		ok(_dead(sap) == 0 and sap.fins.is_empty(), "%s's sapling has no deadwood and no buttresses" % sp.name)
		if form == "establishment":
			ok(_trunk_top(sap) < 0.1 and _trunk_top(grown) > 0.5, "%s's sapling is a stemless rosette (trunk to %.2f; grown %.2f)" % [sp.name, _trunk_top(sap), _trunk_top(grown)])
		elif form in ["whip", "cone"]:
			ok(_leader(sap), "%s's sapling keeps one leader" % sp.name)
			ok(_crown_base(sap) < 0.22, "%s's open-grown sapling carries its crown low (from %.2f of its height; grown %.2f)" % [sp.name, _crown_base(sap), _crown_base(grown)])
		elif form == "multi_stem":
			ok(_stems(sap) >= 2, "%s's sapling comes up as %d stems" % [sp.name, _stems(sap)])
		var arrays := PlantMeshes.young_arrays(sp, 2, PlantMeshes.LOD_NEAR)
		var seedling := PlantMeshes.young_arrays(sp, 1, PlantMeshes.LOD_NEAR)
		ok((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 30 and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 9000 and (seedling[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 10,
			"%s: sapling mesh %d vertices, seedling %d" % [sp.name, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (seedling[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()])
	# Cards carry their middles (for the shade leaf size).
	var any_card := false
	var centred := true
	for sp in all:
		if sp.tier == PlantSpecies.Tier.SHRUB and sp.shape == PlantSpecies.Shape.SHRUB:
			var arr := PlantMeshes.arrays_for(sp, PlantMeshes.LOD_NEAR)
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			var cu: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				if absf(uv2[i].x - 2.0) < 0.01:
					any_card = true
					if Vector3(cu[i * 4], cu[i * 4 + 1], cu[i * 4 + 2]).distance_to(v[i]) > 1.0:
						centred = false
			break
	ok(any_card and centred, "a shrub's leaf cards know their middles")
	print("RESULT fails: %d" % fails)
	quit()


func _dead(sk: TreeLayouts.Skeleton) -> int:
	var n := 0
	for pc in sk.pieces:
		if pc.dead and pc.kind != TreeLayouts.Kind.BRANCH:
			n += 1
	return n


func _trunk_top(sk: TreeLayouts.Skeleton) -> float:
	var top := 0.0
	for pc in sk.pieces:
		if pc.kind == TreeLayouts.Kind.TRUNK:
			top = maxf(top, pc.pts[pc.pts.size() - 1].y)
	return top


func _leader(sk: TreeLayouts.Skeleton) -> bool:
	var trunks := 0
	for pc in sk.pieces:
		if pc.kind == TreeLayouts.Kind.TRUNK:
			trunks += 1
	return trunks == 1


func _stems(sk: TreeLayouts.Skeleton) -> int:
	var n := 0
	for pc in sk.pieces:
		if pc.kind == TreeLayouts.Kind.TRUNK and pc.parent >= 0:
			n += 1
	return n


## The height where the lowest living limb leaves the stem.
func _crown_base(sk: TreeLayouts.Skeleton) -> float:
	var low := 1.0
	for pc in sk.pieces:
		if pc.kind == TreeLayouts.Kind.LIMB and not pc.dead:
			low = minf(low, pc.pts[0].y)
	return low

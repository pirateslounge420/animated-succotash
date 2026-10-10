extends SceneTree
## The BULB plant shape (design §FM.13 item 3, queue 77), headless:
##   godot --headless --path . --script tools/bulb_check.gd
## Asserts:
##  - PlantSpecies.Shape has BULB (and still SPIKE_ROSETTE), and an entry's
##    shape string "bulb" reads as it;
##  - leshoma's entry in data/sacred/sacred_plants.json says "bulb" (the
##    data-driven one-liner), and leshoma is built straight from it the way
##    SpeciesDB builds a catalogue entry (SpeciesDB.species_in_file), with
##    data/sacred still not loaded: SpeciesDB has the same species before
##    and after, leshoma has no index and none of them comes from
##    data/sacred (the open world and the §CC trim untouched); its
##    appearance, leaf and bark blocks read;
##  - no tiles, the shared untiled material; not grass in the wind and drawn
##    at one scale every way (the fan isn't stretched); the far level its
##    own model (PlantMeshes.own_far), never the one-quad picture;
##  - at the hero, near and far levels: every face painted (UV2.x -1: no
##    leaf card, hull or far picture), the fan's top at y 1 (unit frame),
##    the bulb's foot under the ground line;
##  - the leaf fan (everything above the neck and its frayed tunics) thin
##    across: its depth (z) under a quarter of its width (x) before the
##    random turn, at both levels (the far level keeps it in one plane),
##    spread to both sides;
##  - a bulb at the base: round at the ground line (as wide in x as in z),
##    widest within a fifth of its radius of the ground line, still full
##    half way up its top half and closing into a neck above that, its foot
##    under the ground: about half out of the ground; drawn at the middle of
##    height_m as broad as appearance.trunk.notes says (15-25 cm across);
##    brown (bark.color, pulled toward the bark brown as the plant shader
##    draws bark: BulbMesh.painted_bark), its foot shaded toward navy when
##    pre-lit; its sides lit outward; still;
##  - the leaves (BulbMesh.layout): as many as appearance.leaf.notes says
##    (8-16), alternating sides (two ranks), each in its own plane, its tip
##    in the mesh at every level and in the same place at every level (the
##    silhouette doesn't pop: every leaf kept far off); drawn at the middle
##    of height_m each as long as appearance.leaf.size_cm says, about its
##    length over the leaf block's aspect wide; stiff (a gentle arch);
##    blunt (its end still TIP_BLUNT of its width); some twisted a little,
##    as the notes say, none more than TWIST_DEG;
##  - one leaf alone (built as the plant builds it): about as wide as the
##    layout says, thin (a lens across), its edges rippled out of the blade
##    by about RIPPLE of its width, rising and falling, at the near levels
##    and flat far off; its front faces appearance.leaf.colour, its back
##    appearance.leaf.underside; its sway 0 at its foot rising to
##    LEAF_SWAY at its tip; lit outward;
##  - the far level keeps the face-on silhouette: its widths up the plant
##    within 10 % of the near level's widest (a cut either side), in fewer
##    triangles than the near level, the near in fewer than the hero;
##  - the leafy form only (queue 77: Torchfire 1 has no year to bloom in,
##    §FK.3): no vertex in the flower's colour at any level;
##  - the fan's plane turns at random per instance: one mesh shared by every
##    plant (mesh_for), the placer's yaw spread over the whole turn
##    (VegetationPlacer._emit), and prepare() turning a plant by it;
##  - every SPIKE_ROSETTE unchanged: every loaded SPIKE_ROSETTE species
##    builds at the hero, near and far levels exactly the spike rosette's
##    leafy ball and spike, rebuilt here as PlantMeshes._build draws it, and
##    its far level is still the one-quad picture.

const S := PlantSpecies.Shape
const LEVELS := [PlantMeshes.LOD_HERO, PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]
## Heights the silhouette is cut at, up the plant.
const CUTS := 60

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	var n0 := SpeciesDB.all().size()
	var probe := SpeciesDB.species_from_entry({"name": "bulb_check probe", "shape": "bulb"}, PlantSpecies.Tier.GROUND)
	ok(S.keys().has("BULB") and S.keys().has("SPIKE_ROSETTE") and probe != null and probe.shape == S.BULB,
		"PlantSpecies.Shape has BULB (and still SPIKE_ROSETTE), and an entry's shape \"bulb\" reads as it")
	var e := _sacred_entry("leshoma")
	ok(str(e.get("shape", "")) == "bulb", "leshoma's entry in data/sacred/sacred_plants.json says shape \"%s\" (the data-driven one-liner)" % str(e.get("shape", "")))
	var sp := SpeciesDB.species_in_file(SpeciesDB.SACRED_PATH, "leshoma")
	ok(sp != null and sp.shape == S.BULB, "leshoma builds from its data/sacred entry as a BULB (%s)" % (sp.binomial() if sp else "missing"))
	if sp == null:
		_done()
		return
	var from_sacred := 0
	for s in SpeciesDB.all():
		if s.files.has(SpeciesDB.SACRED_PATH.get_file()):
			from_sacred += 1
	ok(SpeciesDB.all().size() == n0 and SpeciesDB.index_of(sp) == -1 and SpeciesDB.find(sp.name) == null and from_sacred == 0,
		"data/sacred is still not loaded: %d species before and after building leshoma, it has no index, and none of them comes from data/sacred (%d)" % [n0, from_sacred])
	var bark: Dictionary = e.get("bark", {})
	ok(sp.height_m == Vector2(0.3, 0.5) and sp.from_catalogue and not sp.appearance.is_empty() and sp.leaf_aspect == 12.0
		and sp.leaf_apex == "obtuse" and sp.leaf_arrangement == "distichous" and str(sp.bark.get("color", "")) == str(bark.get("color", "-")),
		"leshoma is built as a catalogue entry: height_m %s, its appearance block, its leaf block (aspect %.0f, apex %s, %s) and its bark block (%s)" % [sp.height_m, sp.leaf_aspect, sp.leaf_apex, sp.leaf_arrangement, str(sp.bark.get("color", ""))])
	_check_bulb(sp, e)
	_turns(sp)
	_spike_rosettes()
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


func _check_bulb(sp: PlantSpecies, e: Dictionary) -> void:
	var look := BulbMesh.look_of(sp)
	var leaves := BulbMesh.layout(sp, look)
	var app: Dictionary = sp.appearance
	var leaf_app: Dictionary = app.get("leaf", {})
	var trunk_app: Dictionary = app.get("trunk", {})
	var flower_app: Dictionary = app.get("flower", {})
	var prelit := Prelit.on()
	var hmid := (sp.height_m.x + sp.height_m.y) * 0.5
	ok(sp.tiles.is_empty() and PlantMeshes.material_for(sp) == PlantMeshes.material(),
		"leshoma: no tiles, the shared untiled material (painted, no leaf tiles)")
	ok(Wind.kind_of(sp) == 0 and not VegetationPlacer.HERB_SPREAD.has(sp.shape) and PlantMeshes.own_far(sp),
		"leshoma: not grass in the wind (wind kind %d), drawn at one scale every way (the fan isn't stretched), and its far level is its own model, never the one-quad picture" % Wind.kind_of(sp))
	# Its size in metres (as built, before the top is scaled to 1): the raw
	# near model gives the top, so a unit-frame length times the drawn height
	# is metres.
	var raw := PlantMeshes._Builder.new()
	raw.mat = BulbMesh.PAINTED
	BulbMesh._bulb(raw, look, false, prelit)
	for leaf in leaves:
		BulbMesh._leaf(raw, leaf, look, false, prelit)
	var top_m := 0.0
	for p in raw.v:
		top_m = maxf(top_m, p.y)
	var k := 1.0 / maxf(top_m, 1e-6) # metres as built -> unit frame
	var r_u: float = float(look.bulb_r) * k
	var neck_u := BulbMesh.NECK_TOP * r_u
	# Above the neck's frayed tunics (their tips at most 1.56 bulb radii up).
	var fan_from := 1.65 * r_u
	# bark.color as the shader draws bark by day (BulbMesh.painted_bark).
	var bark_col := Color.from_string(str(sp.bark.get("color", "")), Color.BLACK)
	var bulb_col := BulbMesh.painted_bark(bark_col)
	var leaf_col := Color.from_string(str(leaf_app.get("colour", "")), Color.BLACK)
	var flower_col := Color.from_string(str(flower_app.get("colour", "")), Color.BLACK)
	var tips := {}
	var profiles := {}
	var tris := {}
	for lod in LEVELS:
		var a := PlantMeshes.arrays_for(sp, lod)
		var lt := "leshoma (level %d)" % lod
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var mats := _mats(a)
		tris[lod] = v.size() / 3
		ok(v.size() > 18 and mats.keys() == [-1.0],
			"%s: %d triangles, every face painted (UV2.x -1: no leaf card, hull or far picture) %s" % [lt, v.size() / 3, str(mats)])
		var lo := INF
		var hi := -INF
		for p in v:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		ok(absf(hi - 1.0) < 1e-3 and lo < -0.3 * r_u,
			"%s: the fan's top at y %.4f (unit frame: drawn at %.2f-%.2f m it stands %.2f-%.2f m, inside height_m); the bulb's foot %.3f under the ground line" % [lt, hi, sp.height_m.x, sp.height_m.y, hi * sp.height_m.x, hi * sp.height_m.y, -lo])
		# The fan: thin across, before the random turn.
		var fx := Vector2(INF, -INF)
		var fz := Vector2(INF, -INF)
		for p in v:
			if p.y > fan_from:
				fx = Vector2(minf(fx.x, p.x), maxf(fx.y, p.x))
				fz = Vector2(minf(fz.x, p.z), maxf(fz.y, p.z))
		var width := fx.y - fx.x
		var depth := fz.y - fz.x
		ok(width > 0.3 and depth < 0.25 * width,
			"%s: the leaf fan (above %.2f, the neck's tunics) is thin across: depth %.3f against width %.3f (%.2f, under a quarter), before the random turn" % [lt, fan_from, depth, width, depth / maxf(width, 1e-6)])
		ok(fx.x < -0.25 * width and fx.y > 0.25 * width,
			"%s: the fan spreads to both sides of the neck (%.3f to %.3f)" % [lt, fx.x, fx.y])
		# The bulb: round at the ground line, widest there, full half way up
		# its top half, closing into a neck, its foot under the ground.
		var g := _section(v, 0.0)
		var gx := _extent(g, Vector2(1, 0))
		var gz := _extent(g, Vector2(0, 1))
		var widest := 0.0
		var wy := 0.0
		for j in 40:
			var y := lerpf(-0.55, 1.1, (j + 0.5) / 40.0) * r_u
			var w := _diameter(_section(v, y))
			if w > widest:
				widest = w
				wy = y
		var half_up := _diameter(_section(v, 0.5 * r_u))
		var neck_w := _diameter(_section(v, 1.1 * r_u))
		ok(absf(gx - gz) < 0.15 * gx and absf(wy) <= 0.2 * r_u and half_up >= 0.7 * widest and neck_w <= 0.4 * widest and neck_w > 0.0 and lo < -0.5 * r_u,
			"%s: a bulb at the base, about half out of the ground: round at the ground line (%.3f by %.3f), widest (%.3f) %.2f of its radius from the ground line, still %.0f %% of that half way up its top half, closing into a neck (%.0f %% at 1.1 radii), its foot %.2f radii under" % [lt, gx, gz, widest, wy / r_u, half_up / widest * 100.0, neck_w / widest * 100.0, -lo / r_u])
		var bulb_cm := gx * hmid * 100.0
		var across := BulbMesh.mean_range(str(trunk_app.get("notes", "")), "cm\\s+across")
		ok(bulb_cm >= 15.0 and bulb_cm <= 25.0 and absf(across - 20.0) < 1e-3,
			"%s: drawn at %.2f m, the bulb is %.1f cm across at the ground line (appearance.trunk.notes: 15-25 cm across)" % [lt, hmid, bulb_cm])
		# Its colour: brown, the foot toward navy, lit outward, still.
		var sum := Color(0, 0, 0)
		var n_b := 0
		var foot_b := 0.0
		var n_f := 0
		var out_n := 0
		var side_n := 0
		var still := true
		for i in v.size():
			var p := v[i]
			if p.y > 1.12 * r_u:
				continue
			if col[i].a > 1e-4:
				still = false
			if p.y > 0.3 * r_u:
				sum += col[i]
				n_b += 1
			elif p.y < 0.05 * r_u and p.y > -0.3 * r_u:
				foot_b += col[i].b / maxf(col[i].r, 1e-3)
				n_f += 1
			if p.y > 0.0 and p.y < 0.5 * r_u:
				var radial := Vector3(p.x, 0.0, p.z)
				if radial.length() > 0.5 * r_u:
					side_n += 1
					if nrm[i].dot(radial.normalized()) > 0.5:
						out_n += 1
		var mean := sum / maxf(n_b, 1)
		foot_b /= maxf(n_f, 1)
		var navy_ok := (not prelit) or foot_b > bulb_col.b / maxf(bulb_col.r, 1e-3) + 0.05
		ok(n_b > 0 and mean.r > mean.g and mean.g > mean.b and _cdist(mean, bulb_col) < 0.2 and navy_ok and still,
			"%s: the bulb is brown, bark.color %s drawn as bark (%s; its top half %s, tunic bands and the frayed neck paler), its foot shaded%s; it holds still" % [lt, bark_col.to_html(false), bulb_col.to_html(false), Color(mean.r, mean.g, mean.b).to_html(false), (" toward navy (%.2f blue over red against %.2f)" % [foot_b, bulb_col.b / maxf(bulb_col.r, 1e-3)]) if prelit else ""])
		ok(side_n > 0 and out_n >= int(side_n * 0.9), "%s: lit outward: the bulb's sides face out (%d of %d corners)" % [lt, out_n, side_n])
		# Every leaf's tip, where the layout puts it.
		var found := PackedVector3Array()
		var missing := 0
		for leaf in leaves:
			var tip := _tip(leaf, look) * k
			var best := INF
			var at := Vector3.ZERO
			for p in v:
				var dd := p.distance_to(tip)
				if dd < best:
					best = dd
					at = p
			if best > 0.002:
				missing += 1
			found.append(at)
		tips[lod] = found
		ok(missing == 0, "%s: every one of the %d leaves has its blunt tip in the mesh where the layout puts it (%d missing)" % [lt, leaves.size(), missing])
		# The leafy form only: no flower colour anywhere.
		var pink := 0
		for c in col:
			if _cdist(c, flower_col) < 0.2:
				pink += 1
		ok(pink == 0, "%s: the leafy form only: no corner within 0.2 of the flower's colour %s (no bloom season in Torchfire 1, §FK.3)" % [lt, flower_col.to_html(false)])
		profiles[lod] = _profile(v)
	# The silhouette doesn't pop: every leaf's tip in the same place.
	var drift := 0.0
	for lod in LEVELS:
		var f: PackedVector3Array = tips[lod]
		var h: PackedVector3Array = tips[PlantMeshes.LOD_NEAR]
		for i in f.size():
			drift = maxf(drift, f[i].distance_to(h[i]))
	ok(drift < 1e-4, "every leaf's tip at the same place at the hero, near and far levels (%.6f apart at most): every leaf kept far off, the silhouette doesn't pop" % drift)
	# The far level keeps the face-on silhouette, in fewer triangles (the
	# frayed tunics round the neck, a near detail, aside).
	var near: PackedFloat32Array = profiles[PlantMeshes.LOD_NEAR]
	var far: PackedFloat32Array = profiles[PlantMeshes.LOD_FAR]
	var worst := 0.0
	var top_w := 0.0
	for j in near.size():
		top_w = maxf(top_w, near[j])
	for j in near.size():
		var yj := (j + 0.5) / CUTS
		if yj > 1.1 * r_u and yj < fan_from:
			continue
		var lo := INF
		var hi := -INF
		for jj in range(maxi(j - 1, 0), mini(j + 2, near.size())):
			lo = minf(lo, near[jj])
			hi = maxf(hi, near[jj])
		worst = maxf(worst, maxf(lo - far[j], far[j] - hi))
	ok(worst <= 0.1 * top_w and int(tris[PlantMeshes.LOD_FAR]) < int(tris[PlantMeshes.LOD_NEAR]) and int(tris[PlantMeshes.LOD_NEAR]) < int(tris[PlantMeshes.LOD_HERO]),
		"the far level keeps the face-on silhouette: its widths up the plant within %.1f %% of the near level's widest (a cut either side; the neck's shreds aside), in %d triangles (near %d, hero %d)" % [maxf(worst, 0.0) / maxf(top_w, 1e-6) * 100.0, tris[PlantMeshes.LOD_FAR], tris[PlantMeshes.LOD_NEAR], tris[PlantMeshes.LOD_HERO]])
	_check_leaves(sp, look, leaves, leaf_app, k, hmid)
	_check_one_leaf(look, leaves, leaf_col, Color.from_string(str(leaf_app.get("underside", "")), Color.BLACK), prelit)


## The layout's leaves against the entry.
func _check_leaves(sp: PlantSpecies, look: Dictionary, leaves: Array[Dictionary], leaf_app: Dictionary, k: float, hmid: float) -> void:
	var span := BulbMesh.count_in(str(leaf_app.get("notes", "")))
	var sides_ok := true
	var left := 0
	var right := 0
	var zs := {}
	var flat := true
	for i in leaves.size():
		var leaf: Dictionary = leaves[i]
		if float(leaf.side) != (1.0 if i % 2 == 0 else -1.0):
			sides_ok = false
		if float(leaf.side) > 0.0:
			right += 1
		else:
			left += 1
		zs[snappedf(float((leaf.foot as Vector3).z), 1e-6)] = true
		for q in BulbMesh.centerline(leaf, 8):
			if absf((q[0] as Vector3).z - (leaf.foot as Vector3).z) > 1e-7 or absf((q[1] as Vector3).z) > 1e-7:
				flat = false
	ok(span == Vector2i(8, 16) and leaves.size() >= span.x and leaves.size() <= span.y,
		"leshoma has %d leaves: appearance.leaf.notes says %d-%d" % [leaves.size(), span.x, span.y])
	ok(sides_ok and left >= 4 and right >= 4 and zs.size() == leaves.size() and flat,
		"two ranks in one plane: the leaves lean left and right in turn (%d and %d), each in its own plane (%d planes; every centerline flat in it)" % [left, right, zs.size()])
	var size: Array = leaf_app.get("size_cm", [0, 0])
	var lengths := PackedFloat32Array()
	var ratio_ok := true
	var stiff := true
	var most_arch := 0.0
	var twisted := 0
	var most_twist := 0.0
	for leaf in leaves:
		lengths.append(float(leaf.length) * k * hmid * 100.0)
		var r := float(leaf.width) / float(leaf.length) * sp.leaf_aspect
		if r < 0.75 or r > 1.3:
			ratio_ok = false
		var lean: Vector2 = leaf.lean
		most_arch = maxf(most_arch, rad_to_deg(lean.y - lean.x))
		if lean.y - lean.x > deg_to_rad(35.0) or lean.y > deg_to_rad(70.0) or lean.y < lean.x - deg_to_rad(5.0):
			stiff = false
		if absf(float(leaf.twist)) > 1e-6:
			twisted += 1
			most_twist = maxf(most_twist, rad_to_deg(absf(float(leaf.twist))))
	var shortest: float = Array(lengths).min()
	var longest: float = Array(lengths).max()
	ok(shortest >= float(size[0]) and longest <= float(size[1]) and ratio_ok,
		"drawn at %.2f m, the leaves are %.1f-%.1f cm long (appearance.leaf.size_cm %s), each about its length over the leaf block's aspect (%.0f) wide" % [hmid, shortest, longest, str(size), sp.leaf_aspect])
	ok(stiff and bool(look.blunt) and BulbMesh.TIP_BLUNT >= 0.5,
		"stiff and blunt: each leaf arches at most %.0f degrees from foot to tip, none past 70 from upright; its end still %.2f of its width (the leaf block's apex obtuse)" % [most_arch, BulbMesh.TIP_BLUNT])
	ok(bool(look.twisted) and twisted >= 1 and twisted <= int(leaves.size() * 0.6) and most_twist <= BulbMesh.TWIST_DEG.y + 1e-3,
		"sometimes twisted a little (the notes say twisted): %d of %d leaves, %.0f degrees by the tip at most" % [twisted, leaves.size(), most_twist])


## One leaf alone, built as the plant builds it, near and far: its width,
## thickness, rippled edges, colours, sway and normals.
func _check_one_leaf(look: Dictionary, leaves: Array[Dictionary], leaf_col: Color, under_col: Color, prelit: bool) -> void:
	# The outermost leaf that isn't twisted (its plane is z = its foot's).
	var leaf: Dictionary = {}
	for i in range(leaves.size() - 1, -1, -1):
		if absf(float(leaves[i].twist)) < 1e-6:
			leaf = leaves[i]
			break
	if leaf.is_empty():
		ok(false, "an untwisted leaf to measure")
		return
	var w: float = leaf.width
	var z0: float = (leaf.foot as Vector3).z
	for far in [false, true]:
		var one := PlantMeshes._Builder.new()
		one.mat = BulbMesh.PAINTED
		BulbMesh._leaf(one, leaf, look, far, prelit)
		var line := BulbMesh.centerline(leaf, BulbMesh.FINE)
		var tag := "one leaf (%s)" % ("far" if far else "near")
		var half := 0.0
		var end_half := 0.0
		var thick := 0.0
		var up := 0
		var down := 0
		var lift := 0.0
		var front_ok := 0
		var front_n := 0
		var back_ok := 0
		var back_n := 0
		var sway_foot := 0.0
		var sway_tip := 0.0
		var out_n := 0
		var n_n := 0
		for i in one.v.size():
			var p := one.v[i]
			# Where along the leaf (the nearest centerline point) and across.
			var best := INF
			var bi := 0
			for j in line.size():
				var dd := Vector2(p.x - (line[j][0] as Vector3).x, p.y - (line[j][0] as Vector3).y).length()
				if dd < best:
					best = dd
					bi = j
			var s := float(bi) / BulbMesh.FINE
			var pc: Vector3 = line[bi][0]
			var tan: Vector3 = line[bi][1]
			var sd := Vector3(tan.y, -tan.x, 0.0)
			var across := (p - pc).dot(sd)
			var out := p.z - z0
			if s > 0.3 and s < 0.8:
				half = maxf(half, absf(across))
			if s >= 0.97:
				end_half = maxf(end_half, absf(across))
			if absf(across) < 0.05 * w:
				thick = maxf(thick, absf(out))
			if s > 0.5 and absf(across) > 0.3 * w:
				lift = maxf(lift, absf(out))
				if out > 0.1 * w:
					up += 1
				elif out < -0.1 * w:
					down += 1
			if s < 0.02:
				sway_foot = maxf(sway_foot, one.c[i].a)
			sway_tip = maxf(sway_tip, one.c[i].a)
			# Colours on the blade's faces past the foot's shade, at its edges.
			if s > 0.35 and s < 0.85 and absf(across) > 0.4 * w:
				if one.n[i].z > 0.5:
					front_n += 1
					if _cdist(one.c[i], leaf_col) < 0.01:
						front_ok += 1
				elif one.n[i].z < -0.5:
					back_n += 1
					if _cdist(one.c[i], under_col) < 0.01:
						back_ok += 1
			# Lit outward: the normal points away from the centerline here.
			var off := p - pc
			off -= tan * off.dot(tan)
			if off.length() > 1e-5:
				n_n += 1
				if one.n[i].dot(off) > 0.0:
					out_n += 1
		ok(half >= 0.4 * w and half <= 0.6 * w and end_half >= 0.45 * 0.5 * w and thick <= 0.06 * w,
			"%s: %.1f cm wide (the layout's %.1f), its end still %.1f cm across (blunt), %.1f mm thick (a closed strap, a lens across)" % [tag, half * 2.0 * 100.0, w * 100.0, end_half * 2.0 * 100.0, thick * 2.0 * 1000.0])
		if far:
			ok(lift <= 0.06 * w and up == 0 and down == 0,
				"%s: no ripples far off: its edges in the blade (%.1f mm out at most)" % [tag, lift * 1000.0])
		else:
			ok(lift >= 0.12 * w and lift <= 0.2 * w and up >= 2 and down >= 2,
				"%s: its edges rippled: the margins rise and fall out of the blade by %.1f mm (%.2f of its width; RIPPLE %.2f), %d corners up and %d down" % [tag, lift * 1000.0, lift / w, BulbMesh.RIPPLE, up, down])
		ok(front_n > 0 and front_ok == front_n and back_n > 0 and back_ok == back_n,
			"%s: its front appearance.leaf.colour %s (%d of %d edge corners facing front), its back appearance.leaf.underside %s (%d of %d)" % [tag, leaf_col.to_html(false), front_ok, front_n, under_col.to_html(false), back_ok, back_n])
		ok(sway_foot < 0.01 and absf(sway_tip - BulbMesh.LEAF_SWAY) < 0.01,
			"%s: sway %.2f at its foot, %.2f at its tip (stiff: LEAF_SWAY %.2f)" % [tag, sway_foot, sway_tip, BulbMesh.LEAF_SWAY])
		ok(n_n > 0 and out_n >= int(n_n * 0.95), "%s: lit outward: %d of %d corners face away from the leaf's middle" % [tag, out_n, n_n])


## The leaf's tip apex, in metres as built (the end of its centerline and a
## short blunt point past it; never rippled there).
func _tip(leaf: Dictionary, look: Dictionary) -> Vector3:
	var line := BulbMesh.centerline(leaf, BulbMesh.FINE)
	var end: Vector3 = line[line.size() - 1][0]
	var tan: Vector3 = line[line.size() - 1][1]
	var tip_w := BulbMesh.TIP_BLUNT if bool(look.blunt) else BulbMesh.TIP_POINTED
	var hw := float(leaf.width) * 0.5 * tip_w
	return end + tan * hw * (0.8 if bool(look.blunt) else 3.0)


## The fan's plane turns at random per instance: one shared mesh, the
## placer's yaw over the whole turn, and prepare() turning a plant by it.
func _turns(sp: PlantSpecies) -> void:
	var shared := PlantMeshes.mesh_for(sp, PlantMeshes.LOD_NEAR) == PlantMeshes.mesh_for(sp, PlantMeshes.LOD_NEAR)
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 64:
		VegetationPlacer._emit(out, 0, Vector3.UP, 1000.0, rng, 0.4)
	var arr: PackedFloat32Array = out.get(0, PackedFloat32Array())
	var quarters := [0, 0, 0, 0]
	for i in arr.size() / VegetationPlacer.STRIDE:
		var yaw := arr[i * VegetationPlacer.STRIDE + 4]
		quarters[int(fposmod(yaw, TAU) / (TAU * 0.25)) % 4] += 1
	# prepare() turns a plant by its yaw round its up (a loaded ground plant
	# stands in: data/sacred isn't loaded).
	var host: PlantSpecies = null
	for s in SpeciesDB.all():
		if s.tier == PlantSpecies.Tier.GROUND and s.shape == S.SPIKE_ROSETTE:
			host = s
			break
	var turned := -1.0
	if host != null:
		var idx := SpeciesDB.index_of(host)
		var d := Vector3(0.3, 0.9, 0.2).normalized()
		var plants := PackedFloat32Array()
		for yaw in [0.0, 1.0]:
			plants.append_array([d.x, d.y, d.z, 1000.0, yaw, 0.0, 0.0, 0.4, 0.0, 0.0, 0.0, float(PlantGrowth.Stage.MATURE)])
		var res := VegetationPlacer.prepare({idx: plants}, d, 1000.0)
		if res.has(idx):
			var buf: PackedFloat32Array = res[idx][0]
			var x0 := Vector3(buf[0], buf[4], buf[8]).normalized()
			var m := VegetationPlacer.MM_STRIDE
			var x1 := Vector3(buf[m], buf[m + 4], buf[m + 8]).normalized()
			turned = x0.angle_to(x1)
	ok(shared and quarters.min() >= 8 and absf(turned - 1.0) < 0.01,
		"the fan's plane turns at random per instance: one mesh for every plant (mesh_for), the placer's yaw over the whole turn (64 plants, %s a quarter turn), and prepare() turns a plant by it (yaw 1.00 rad -> %.2f)" % [str(quarters), turned])


## Every SPIKE_ROSETTE as it was: each loaded species' hero, near and far
## models exactly the spike rosette's leafy ball and spike (rebuilt here as
## PlantMeshes._build draws it), and its far level the one-quad picture.
func _spike_rosettes() -> void:
	var n := 0
	var drawn := 0
	var bad := PackedStringArray()
	var pictures := 0
	for sp in SpeciesDB.all():
		if sp.shape != S.SPIKE_ROSETTE:
			continue
		n += 1
		var idx := SpeciesDB.index_of(sp)
		if not TreeArch.grows(sp) and sp.aroid.is_empty():
			drawn += 1
			for lod in LEVELS:
				var got: Array = PlantMeshes._build(sp, idx, lod) if lod == PlantMeshes.LOD_FAR else PlantMeshes.arrays_for(sp, lod)
				if not _same(got, _spike_ref(sp, idx, lod)):
					bad.append("%s L%d" % [sp.name, lod])
		var far: PackedVector3Array = PlantMeshes.arrays_for(sp, PlantMeshes.LOD_FAR)[Mesh.ARRAY_VERTEX]
		if not PlantMeshes.own_far(sp) and (far.size() == 6 or not PlantMeshes.IMPOSTORS):
			pictures += 1
	ok(n > 0 and drawn == n and bad.is_empty() and pictures == n,
		"every SPIKE_ROSETTE unchanged: %d species build their hero, near and far models exactly as the spike rosette's leafy ball and spike, and their far level is still the one-quad picture (%d)%s" % [n, pictures, "" if bad.is_empty() else (": " + ", ".join(bad))])


## The spike rosette as PlantMeshes._build draws it (queue 77 leaves it as
## it was): its leafy ball at the foot and its spike.
func _spike_ref(sp: PlantSpecies, idx: int, lod: int) -> Array:
	var b := PlantMeshes._Builder.new()
	b.far = lod == PlantMeshes.LOD_FAR
	b.hero = lod == PlantMeshes.LOD_HERO
	b.freq = PlantMeshes.CROWN_FREQ[lod]
	b.wood = sp.accent
	b.rng.seed = idx * 7919 + 11
	b.blob(Vector3(0, 0.12, 0), Vector3(0.22, 0.13, 0.22), sp.color, 0.1)
	b.cone(Vector3(0, 0.2, 0), 0.07, 0.8, 6, sp.accent, 0.2, 0.6)
	return b.commit_arrays()


func _same(a: Array, b: Array) -> bool:
	for key in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0]:
		if a[key] != b[key]:
			return false
	return true


## Triangles by material (UV2.x, to a quarter).
func _mats(a: Array) -> Dictionary:
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var out := {}
	for t in range(0, uv2.size(), 3):
		var key := snappedf(uv2[t].x, 0.25)
		out[key] = int(out.get(key, 0)) + 1
	return out


## The mesh's cross-section at height y: where its triangles' edges cross
## the level plane, in x-z.
func _section(v: PackedVector3Array, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in range(0, v.size(), 3):
		for ed in [[v[t], v[t + 1]], [v[t + 1], v[t + 2]], [v[t + 2], v[t]]]:
			var p: Vector3 = ed[0]
			var q: Vector3 = ed[1]
			if (p.y - y) * (q.y - y) < 0.0:
				var x := p.lerp(q, (y - p.y) / (q.y - p.y))
				out.append(Vector2(x.x, x.z))
	return out


## A cross-section's extent along `d`.
func _extent(pts: PackedVector2Array, d: Vector2) -> float:
	if pts.size() < 2:
		return 0.0
	var lo := INF
	var hi := -INF
	for p in pts:
		var s := p.dot(d)
		lo = minf(lo, s)
		hi = maxf(hi, s)
	return hi - lo


## A cross-section's width: the most, over 36 directions, between its
## farthest points.
func _diameter(pts: PackedVector2Array) -> float:
	var best := 0.0
	for k in 36:
		best = maxf(best, _extent(pts, Vector2(cos(PI * k / 36.0), sin(PI * k / 36.0))))
	return best


## The face-on silhouette: the mesh's x extent at CUTS heights up it.
func _profile(v: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in CUTS:
		out.append(_extent(_section(v, (j + 0.5) / CUTS), Vector2(1, 0)))
	return out


func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _sacred_entry(id: String) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(SpeciesDB.SACRED_PATH))
	if doc is Dictionary:
		for tier in doc.get("plants", {}):
			for en in doc.plants[tier]:
				if en is Dictionary and str(en.get("id", "")) == id:
					return en
	return {}

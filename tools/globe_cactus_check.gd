extends SceneTree
## The GLOBE_CACTUS plant shape (design §FM.13 item 2, queue 76), headless:
##   godot --headless --path . --script tools/globe_cactus_check.gd
## Asserts:
##  - PlantSpecies.Shape has GLOBE_CACTUS and an entry's shape string
##    "globe_cactus" reads as it;
##  - peyote is built straight from its data/sacred entry the way SpeciesDB
##    builds a catalogue entry (SpeciesDB.species_in_file), and data/sacred
##    is still not loaded: SpeciesDB has the same species before and after,
##    and none of them comes from data/sacred (the open world and the §CC
##    trim untouched);
##  - the queue's check, at the hero, near and far levels: drawn at any
##    height in height_m, the mesh stands no taller than height_m above the
##    ground line, and it is at least three times as wide as it is tall
##    above the ground;
##  - every face painted flesh (UV2.x -1: no leaf card, hull or far picture;
##    no leaf tiles, leaf type none, the shared untiled material), sway 0,
##    the wind's still kind, drawn at one scale every way;
##  - the oldest head (built alone, upright): a flattened dome as tall as
##    height_m (its buried foot to its crown is the unit frame's 1) and,
##    drawn at the middle of height_m, as wide as stem.diameter_cm; sunk to
##    its rim (widest at the ground line, most of its height under it); its
##    ribs, counted round its outline just above the ground, a count in
##    stem.ribs; each rib cut into bumps by cross-furrows (the near and hero
##    levels dip and rise along a rib's crest; the far level, smooth along
##    it, doesn't); a wool tuft (stem.areole_colour) on every bump above
##    the ground; a woolly boss at the centre, its top the head's highest
##    point;
##  - several heads (three or more) in a tight clump: every pup pressed
##    against a neighbour, a woolly boss standing on every head;
##  - no spines: spine_cm is [0, 0]; a probe of the same entry with spines
##    grows exactly three triangles a spine, spines_per_areole on every
##    tuft, spine_cm long;
##  - the flower: peyote blooms, so a small bell in flower.colour, about
##    fruiting.flower_size_cm across, stands in the oldest head's woolly
##    crown at the near and hero levels; the far level has none, nor has a
##    probe that names no flower;
##  - painted: stem.colour, easing toward stem.secondary on the bumps'
##    crests; the furrows darker and, pre-lit, bluer (occlusion toward navy,
##    §ES.2); lit outward: the boss's top faces up, the rim's crests out;
##  - the far level keeps the flat button: its widths up the part above the
##    ground within 15 % of the near level's widest (the flower aside), its
##    top the near level's boss top, in fewer triangles;
##  - every CACTUS unchanged: every CACTUS species (the Trichocereus among
##    them) still CACTUS, its hero, near and far meshes the same as before
##    this pass (geometry digests recorded from the code before queue 76),
##    the San Pedro a column: narrow and tall.

const S := PlantSpecies.Shape
const LEVELS := [PlantMeshes.LOD_HERO, PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]
## Every CACTUS species' meshes as built before queue 76 (fde9da0): vertex
## count and an md5 of positions, normals, UV2 and CUSTOM0 (colours left out,
## so a palette or pre-lit change doesn't trip it), by level. All CACTUS
## species share their geometry (only their colours differ). The far level is
## the one-quad picture (IMPOSTORS on, the default). If CACTUS is ever changed
## on purpose, record these again.
const CACTUS_DIGESTS := {
	PlantMeshes.LOD_HERO: "282:854228b78258aba76dca60189726e22d",
	PlantMeshes.LOD_NEAR: "186:ea934b218f081446ecde3bd8c21dedaf",
	PlantMeshes.LOD_FAR: "6:51724d6a1d68982e9da6be402b92f998",
}
## Heights the cross-section is cut at.
const CUTS := 60

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _run() -> void:
	var all := SpeciesDB.all()
	var n0 := all.size()
	# The shape and its string.
	var probe := SpeciesDB.species_from_entry({"name": "globe_cactus_check probe", "shape": "globe_cactus"}, PlantSpecies.Tier.GROUND)
	ok(PlantSpecies.Shape.keys().has("GLOBE_CACTUS") and probe != null and probe.shape == S.GLOBE_CACTUS,
		"PlantSpecies.Shape has GLOBE_CACTUS, and an entry's shape \"globe_cactus\" reads as it")

	# Peyote from its data/sacred entry, never loaded.
	var pey := SpeciesDB.species_in_file(SpeciesDB.SACRED_PATH, "peyote")
	ok(pey != null and pey.shape == S.GLOBE_CACTUS, "peyote builds from its data/sacred entry as a GLOBE_CACTUS (%s)" % (pey.name if pey else "missing"))
	if pey == null:
		_done()
		return
	var from_sacred := 0
	for sp in SpeciesDB.all():
		if sp.files.has(SpeciesDB.SACRED_PATH.get_file()):
			from_sacred += 1
	ok(SpeciesDB.all().size() == n0 and SpeciesDB.index_of(pey) == -1 and SpeciesDB.find(pey.name) == null and from_sacred == 0,
		"data/sacred is still not loaded: %d species before and after building peyote, it has no index, and none of them comes from data/sacred (%d)" % [n0, from_sacred])
	var e := _sacred_entry("peyote")
	ok(pey.height_m == Vector2(0.02, 0.07) and pey.color.is_equal_approx(Color.from_string(str(e.get("color", "")), Color.BLACK))
		and pey.leaf_type == "none" and pey.realms.has("nearctic") and pey.biomes.has(BiomeTemplates.id_of_key("HOT_DESERT"))
		and pey.biomes.has(BiomeTemplates.id_of_key("THORN_SCRUB")) and pey.tier == PlantSpecies.Tier.GROUND
		and pey.from_catalogue and not pey.appearance.is_empty(),
		"peyote is built as a catalogue entry: height_m %s, its colour, leaf type '%s', realm %s, its two biomes, the ground tier, its appearance block" % [pey.height_m, pey.leaf_type, pey.realms])

	var look := GlobeCactusMesh.look_of(pey)
	var heads := GlobeCactusMesh.layout(pey, look)
	var stem: Dictionary = pey.appearance.get("stem", {})
	var prelit := Prelit.on()
	ok(pey.tiles.is_empty() and PlantMeshes.material_for(pey) == PlantMeshes.material(),
		"peyote: leaf type none, no tiles, the shared untiled material (no leaf tiles)")
	ok(Wind.kind_of(pey) == 0 and not VegetationPlacer.HERB_SPREAD.has(pey.shape) and PlantMeshes.own_far(pey),
		"peyote: the wind's still kind (it never bows), drawn at one scale every way, and its far level its own model (never the one-quad picture)")

	# The queue's check, and the faces, at every level.
	var tris := {}
	for lod in LEVELS:
		var a := PlantMeshes.arrays_for(pey, lod)
		var lt := "peyote (level %d)" % lod
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
		tris[lod] = v.size() / 3
		var swaying := 0
		for c in col:
			if c.a > 1e-4:
				swaying += 1
		var mats := _mats(a)
		ok(v.size() > 0 and mats.keys() == [-1.0] and swaying == 0,
			"%s: %d triangles, every face painted flesh (UV2.x -1: no leaf card, hull or far picture), sway 0 (%s)" % [lt, v.size() / 3, str(mats)])
		var top := -INF
		var bottom := INF
		var above := PackedVector2Array()
		for p in v:
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
			if p.y >= 0.0:
				above.append(Vector2(p.x, p.z))
		var wide := _diameter(above)
		var hmid := (pey.height_m.x + pey.height_m.y) * 0.5
		var low_enough := true
		for hh in [pey.height_m.x, hmid, pey.height_m.y]:
			# Drawn at hh (the instance's scale): its height over the ground line.
			if top * float(hh) > float(hh) + 1e-6 or top * float(hh) > pey.height_m.y + 1e-6:
				low_enough = false
		ok(low_enough and top > 0.0 and wide >= 3.0 * top,
			"%s: %.3f over the ground line (unit frame; drawn at %.2f-%.2f m it stands %.1f-%.1f cm over it, no taller than height_m), %.3f across: %.1f times as wide as it is tall above the ground" % [lt, top, pey.height_m.x, pey.height_m.y, top * pey.height_m.x * 100.0, top * pey.height_m.y * 100.0, wide, wide / maxf(top, 1e-6)])
		ok(bottom < -0.5 * top, "%s: most of it is below the ground line (down to %.3f, %.3f over it)" % [lt, bottom, top])

	# The clump.
	var pressed := true
	var gaps := PackedStringArray()
	for k in range(1, heads.size()):
		var best := INF
		for j in heads.size():
			if j != k:
				var fk: Vector3 = heads[k].foot
				var fj: Vector3 = heads[j].foot
				best = minf(best, Vector2(fk.x - fj.x, fk.z - fj.z).length() - float(heads[k].radius) - float(heads[j].radius))
		gaps.append("%.3f" % best)
		if best > 0.0:
			pressed = false
	ok(heads.size() >= 3 and pressed,
		"several heads in a tight clump: %d heads, every pup pressed against a neighbour (rim to rim %s, under 0: overlapping)" % [heads.size(), ", ".join(gaps)])
	var near_a := PlantMeshes.arrays_for(pey, PlantMeshes.LOD_NEAR)
	var near_v: PackedVector3Array = near_a[Mesh.ARRAY_VERTEX]
	var near_c: PackedColorArray = near_a[Mesh.ARRAY_COLOR]
	var wool: Color = look.wool
	var bosses := 0
	for h in heads:
		var hd: Dictionary = h
		var ax: Vector3 = hd.axis
		var ft: Vector3 = hd.foot
		var rb := GlobeCactusMesh.BOSS_R * float(hd.radius) * 1.05
		var apex := ft + ax * (GlobeCactusMesh.surface(hd, look, 0.0, 0.0, 0.0, false).y + GlobeCactusMesh.BOSS_H * rb)
		for i in near_v.size():
			if near_v[i].distance_to(apex) < 1e-3 and _cdist(near_c[i], wool) < 0.01:
				bosses += 1
				break
	ok(bosses == heads.size(), "a woolly boss (areole_colour %s) stands in the crown of every head (%d of %d)" % [wool.to_html(false), bosses, heads.size()])
	var ribs_seen := PackedStringArray()
	var ribs_ok := true
	var rr: Vector2i = look.ribs
	for h in heads:
		ribs_seen.append(str(h.ribs))
		if int(h.ribs) < rr.x or int(h.ribs) > rr.y:
			ribs_ok = false
	ok(ribs_ok and int(heads[0].ribs) >= int(heads[heads.size() - 1].ribs),
		"rib counts from stem.ribs %s: %s, oldest first (the pups fewer)" % [str(stem.get("ribs")), ", ".join(ribs_seen)])

	# The oldest head alone, upright at the origin.
	for lod in LEVELS:
		_oldest(pey, look, heads[0], lod, prelit)

	# No spines; a probe with spines grows them.
	var tufts := 0
	for h in heads:
		tufts += int(h.ribs) * (int(h.bumps) - 1)
	var spiny_e := e.duplicate(true)
	spiny_e.name = "globe_cactus_check spiny"
	var spiny_stem: Dictionary = spiny_e.appearance.stem
	spiny_stem.spine_cm = [1, 2]
	spiny_stem.spines_per_areole = [2, 4]
	spiny_stem.spine_colour = "#B04A20"
	var spiny := SpeciesDB.species_from_entry(spiny_e, PlantSpecies.Tier.GROUND)
	var sp_look := GlobeCactusMesh.look_of(spiny)
	var sp_a := PlantMeshes.arrays_for(spiny, PlantMeshes.LOD_NEAR)
	var sp_v: PackedVector3Array = sp_a[Mesh.ARRAY_VERTEX]
	var sp_c: PackedColorArray = sp_a[Mesh.ARRAY_COLOR]
	var spine_col := Color.from_string("#B04A20", Color.BLACK)
	var spine_v := 0
	var longest := 0.0
	var shortest := INF
	for t in range(0, sp_v.size(), 3):
		if _cdist(sp_c[t], spine_col) < 0.01 and _cdist(sp_c[t + 1], spine_col) < 0.01 and _cdist(sp_c[t + 2], spine_col) < 0.01:
			spine_v += 3
			var edge := maxf(sp_v[t].distance_to(sp_v[t + 1]), maxf(sp_v[t + 1].distance_to(sp_v[t + 2]), sp_v[t + 2].distance_to(sp_v[t])))
			longest = maxf(longest, edge)
			shortest = minf(shortest, edge)
	var want_len: float = sp_look.spine_len
	ok(int(look.spines) == 0 and GlobeCactusMesh._pair(stem.get("spine_cm"), -Vector2.ONE) == Vector2.ZERO and int(sp_look.spines) == 3
		and sp_v.size() / 3 - int(tris[PlantMeshes.LOD_NEAR]) == 3 * int(sp_look.spines) * tufts
		and spine_v == 9 * int(sp_look.spines) * tufts and shortest > 0.95 * want_len and longest < 1.05 * want_len,
		"no spines: peyote's spine_cm is %s; the same entry with spine_cm [1, 2] and 2-4 to an areole grows %d spines (%d to each of %d tufts, three triangles each: %d more than peyote's %d), each %.3f-%.3f long (spine_cm's middle: %.3f, unit frame)" % [str(stem.get("spine_cm")), spine_v / 9, int(sp_look.spines), tufts, sp_v.size() / 3 - int(tris[PlantMeshes.LOD_NEAR]), int(tris[PlantMeshes.LOD_NEAR]), shortest, longest, want_len])

	# The flower: peyote blooms; a probe that names no flower doesn't.
	var fcol: Color = look.flower
	var bare_e := e.duplicate(true)
	bare_e.name = "globe_cactus_check flowerless"
	(bare_e.appearance as Dictionary).erase("flower")
	(bare_e.fruiting as Dictionary).erase("flower_colour")
	var bare := SpeciesDB.species_from_entry(bare_e, PlantSpecies.Tier.GROUND)
	var hmid2 := (pey.height_m.x + pey.height_m.y) * 0.5
	var size_cm := float(pey.fruiting.get("flower_size_cm", 0.0))
	var main_ax: Vector3 = heads[0].axis
	var main_ft: Vector3 = heads[0].foot
	var main_rb := GlobeCactusMesh.BOSS_R * float(heads[0].radius) * 1.05
	var boss_top := GlobeCactusMesh.surface(heads[0], look, 0.0, 0.0, 0.0, false).y + GlobeCactusMesh.BOSS_H * main_rb
	var rim_col := fcol.lerp(look.flower_2, GlobeCactusMesh.FLOWER_RIM)
	for lod in LEVELS:
		var a := PlantMeshes.arrays_for(pey, lod)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bell := PackedVector2Array()
		var rim := PackedVector2Array()
		var in_crown := true
		for i in v.size():
			var is_bell := _cdist(c[i], fcol) < 0.01
			var is_rim := _cdist(c[i], rim_col) < 0.01
			if is_bell or is_rim:
				var off := v[i] - main_ft
				var along := off.dot(main_ax)
				var across := (off - main_ax * along).length()
				if is_bell:
					bell.append(Vector2(v[i].x, v[i].z))
				else:
					rim.append(Vector2(v[i].x, v[i].z))
				if across > float(look.flower_r) * 1.02 or along < boss_top - GlobeCactusMesh.FLOWER_SINK * GlobeCactusMesh.FLOWER_H * float(look.flower_r) - 1e-4:
					in_crown = false
		var bare_v: PackedVector3Array = PlantMeshes.arrays_for(bare, lod)[Mesh.ARRAY_VERTEX]
		var bare_c: PackedColorArray = PlantMeshes.arrays_for(bare, lod)[Mesh.ARRAY_COLOR]
		var bare_pink := 0
		for i in bare_v.size():
			if _cdist(bare_c[i], fcol) < 0.15:
				bare_pink += 1
		if lod == PlantMeshes.LOD_FAR:
			ok(bell.is_empty() and rim.is_empty() and bare_pink == 0, "peyote (level %d): no flower far off (as LOD strips detail), nor on the probe without one" % lod)
		else:
			var across_cm := _diameter(rim) * hmid2 * 100.0
			ok(bool(look.blooms) and bell.size() > 0 and rim.size() > 0 and in_crown and absf(across_cm - size_cm) < 0.1 * size_cm and bare_pink == 0 and bare_v.size() < v.size(),
				"peyote (level %d): it blooms (appearance.flower.colour %s), so a bell of it stands in the oldest head's woolly crown, %.1f cm across drawn at %.3f m (fruiting.flower_size_cm %.1f); the probe that names no flower has none (%d pinkish corners)" % [lod, fcol.to_html(false), across_cm, hmid2, size_cm, bare_pink])
	var solo_e := e.duplicate(true)
	solo_e.name = "globe_cactus_check solitary"
	(solo_e.appearance.trunk as Dictionary)["form"] = "solitary"
	var solo := SpeciesDB.species_from_entry(solo_e, PlantSpecies.Tier.GROUND)
	ok(GlobeCactusMesh.layout(solo).size() == 1 and str(pey.appearance.trunk.get("form", "")) == "clumping",
		"peyote's appearance.trunk.form is 'clumping' (the clump); an entry that says 'solitary' draws one head")

	# The far level keeps the flat button: the near level without its flower
	# (the same heads, built with none) against the far level.
	var nb := PlantMeshes._Builder.new()
	nb.mat = GlobeCactusMesh.FLESH
	for h in heads:
		GlobeCactusMesh.head(nb, h, look, false, false, prelit, false)
	var near_nf: PackedVector3Array = nb.v
	var far_v: PackedVector3Array = PlantMeshes.arrays_for(pey, PlantMeshes.LOD_FAR)[Mesh.ARRAY_VERTEX]
	var top_n := 0.0
	var top_f := 0.0
	for p in near_nf:
		top_n = maxf(top_n, p.y)
	for p in far_v:
		top_f = maxf(top_f, p.y)
	var widest_n := 0.0
	var worst := 0.0
	var cuts := 8
	var wn := PackedFloat32Array()
	var wf := PackedFloat32Array()
	for j in cuts:
		var y := top_n * (j + 0.5) / cuts
		wn.append(_diameter(_section(near_nf, y)))
		wf.append(_diameter(_section(far_v, y)))
		widest_n = maxf(widest_n, wn[j])
	for j in cuts:
		worst = maxf(worst, absf(wn[j] - wf[j]))
	ok(worst <= 0.15 * widest_n and absf(top_f - top_n) < 0.01 and int(tris[PlantMeshes.LOD_FAR]) < int(tris[PlantMeshes.LOD_NEAR]),
		"the far level keeps the flat button: its widths up the part above the ground within %.0f %% of the near level's widest (%s against %s), its top %.3f (the near level's boss %.3f), %d triangles against %d" % [worst / maxf(widest_n, 1e-6) * 100.0, _list(wf), _list(wn), top_f, top_n, int(tris[PlantMeshes.LOD_FAR]), int(tris[PlantMeshes.LOD_NEAR])])

	_cactus_unchanged()
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## The oldest head at level `lod`, built alone, upright at the origin (its
## own frame: the rim on y 0), without its flower.
func _oldest(sp: PlantSpecies, look: Dictionary, h0: Dictionary, lod: int, prelit: bool) -> void:
	var lt := "the oldest head (level %d)" % lod
	var far := lod == PlantMeshes.LOD_FAR
	var h := h0.duplicate()
	h.axis = Vector3.UP
	h.foot = Vector3.ZERO
	var b := PlantMeshes._Builder.new()
	b.mat = GlobeCactusMesh.FLESH
	b.hero = lod == PlantMeshes.LOD_HERO
	b.far = far
	GlobeCactusMesh.head(b, h, look, far, b.hero, prelit, false)
	var a := b.commit_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var wool: Color = look.wool
	var body: Color = look.body
	var sec: Color = look.secondary
	# Its own surface (not the wool): every triangle with no wool corner.
	var keep := PackedByteArray()
	var surf := PackedVector3Array()
	for t in range(0, v.size(), 3):
		var w := false
		for k in 3:
			if _cdist(col[t + k], wool) < 0.2:
				w = true
		keep.append(0 if w else 1)
		if not w:
			surf.append_array([v[t], v[t + 1], v[t + 2]])
	var lo := INF
	var hi := -INF
	for p in surf:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var hmid := (sp.height_m.x + sp.height_m.y) * 0.5
	# Widest where: the cross-section up the whole head.
	var wy := 0.0
	var ww := 0.0
	for j in 100:
		var y := lerpf(lo, hi, (j + 0.5) / 100.0)
		var w := _diameter(_section(surf, y))
		if w > ww:
			ww = w
			wy = y
	var rim_w := maxf(_diameter(_section(surf, 1e-4)), _diameter(_section(surf, -1e-4)))
	var dia := GlobeCactusMesh._pair((sp.appearance.stem as Dictionary).get("diameter_cm"), Vector2.ZERO)
	var rim_cm := rim_w * hmid * 100.0
	ok(absf((hi - lo) - 1.0) < 0.03 and hi < 0.5 * (hi - lo) and absf(wy) <= 0.03 and rim_cm >= dia.x and rim_cm <= dia.y and absf(rim_cm - (dia.x + dia.y) * 0.5) < 0.1 * (dia.x + dia.y) * 0.5,
		"%s: a flattened dome as tall as height_m (%.3f, buried foot %.3f to crown %.3f), sunk to its rim (widest at y %.3f, %.0f %% of it under the ground line); drawn at %.3f m it is %.1f cm across (stem.diameter_cm %s)" % [lt, hi - lo, lo, hi, wy, -lo / (hi - lo) * 100.0, hmid, rim_cm, str(dia)])
	# Its ribs: round its outline just above the ground.
	var lobes := _lobes(_section(surf, 0.02 * hi))
	ok(lobes == int(h.ribs), "%s: %d ribs round its outline just above the ground (its count %d, from stem.ribs %s)" % [lt, lobes, int(h.ribs), str(look.ribs)])
	# The bumps: along a rib's crest (the corners at its turn), its height
	# dips into a cross-furrow and rises out of it (convex runs) on the near
	# and hero levels; the far level is smooth along it.
	var turn: float = h.turn
	var dir := Vector3(-cos(turn), 0.0, sin(turn)) # PlantMeshes' corner at angle `turn` on an upright head
	var rr: float = h.radius
	var rb := GlobeCactusMesh.BOSS_R * rr * 1.05
	var ys := PackedFloat32Array()
	var steps := 120
	var r_from := rb * 1.25
	var r_to := rr * 0.97
	for i in steps + 1:
		var r := lerpf(r_from, r_to, float(i) / steps)
		ys.append(_height_at(v, keep, dir.x * r, dir.z * r))
	var convex := 0
	var inside := false
	var dr := (r_to - r_from) / steps
	for i in range(2, steps - 1):
		var d2 := ys[i + 2] - 2.0 * ys[i] + ys[i - 2]
		var cv := d2 > 2e-5
		if cv and not inside:
			convex += 1
		inside = cv
	var furrows := int(h.bumps) - 1
	if far:
		ok(convex == 0, "%s: smooth along a rib's crest (no bumps far off): %d dips" % [lt, convex])
	else:
		ok(convex == furrows, "%s: each rib cut into bumps: along its crest the height dips into %d cross-furrows and rises out of them (%d bumps, the outermost halved by the ground; %.3f a step)" % [lt, convex, int(h.bumps), dr])
	# The tufts and the boss.
	var tips := PackedVector2Array()
	var boss_top := -INF
	var top_i := 0
	for i in v.size():
		if v[i].y > v[top_i].y:
			top_i = i
		if _cdist(col[i], wool) < 0.005:
			var rxz := Vector2(v[i].x, v[i].z)
			if rxz.length() > rb * 1.5:
				tips.append(rxz)
			else:
				boss_top = maxf(boss_top, v[i].y)
	var tufts := 0 if tips.is_empty() else _clusters(tips, 0.01)
	var top_wool := _cdist(col[top_i], wool) < 0.005 and Vector2(v[top_i].x, v[top_i].z).length() < rb
	if far:
		ok(tufts == 0 and top_wool, "%s: its woolly boss (its highest point, areole_colour) and no tufts far off" % lt)
	else:
		ok(tufts == int(h.ribs) * furrows and top_wool and nrm[top_i].y > 0.8,
			"%s: a wool tuft (areole_colour) on every bump above the ground (%d: %d ribs x %d) and a woolly boss at the centre, its top the head's highest point, facing up (%.2f)" % [lt, tufts, int(h.ribs), furrows, nrm[top_i].y])
	# Painted: the crests toward the secondary, the furrows darker and bluer.
	var crest_c := body.lerp(sec, GlobeCactusMesh.CREST_SHARE)
	var crests := 0
	var dark_l := INF
	var dark_c := body
	for t in range(0, v.size(), 3):
		if keep[t / 3] == 0:
			continue
		for k in 3:
			var c := col[t + k]
			if v[t + k].y < 0.2 * hi:
				continue
			if _cdist(c, crest_c) < 0.003:
				crests += 1
			if c.get_luminance() < dark_l:
				dark_l = c.get_luminance()
				dark_c = c
	var navy := (not prelit) or dark_c.b / maxf(dark_c.r, 1e-3) > body.b / maxf(body.r, 1e-3)
	ok((far or crests > 0) and dark_l < 0.85 * body.get_luminance() and navy,
		"%s: stem.colour %s easing to %s on the crests (%d crest corners at %.0f %% of stem.secondary %s), the furrows darker (%.2f of its lightness)%s" % [lt, body.to_html(false), crest_c.to_html(false), crests, GlobeCactusMesh.CREST_SHARE * 100.0, sec.to_html(false), dark_l / maxf(body.get_luminance(), 1e-3), (" and bluer (%.2f against %.2f blue over red: occlusion toward navy)" % [dark_c.b / maxf(dark_c.r, 1e-3), body.b / maxf(body.r, 1e-3)]) if prelit else ""])
	# Lit outward: the rim's crests face out.
	var outn := 0
	var rim_n := 0
	for i in v.size():
		var rxz := Vector2(v[i].x, v[i].z)
		if absf(v[i].y) < 1e-4 and rxz.length() > rr * 0.98:
			rim_n += 1
			if Vector2(nrm[i].x, nrm[i].z).dot(rxz.normalized()) > 0.5:
				outn += 1
	ok(rim_n > 0 and outn == rim_n, "%s: lit outward: the rim's crests face out (%d of %d corners)" % [lt, outn, rim_n])


## Every CACTUS species still CACTUS, built as before this pass; the San
## Pedro a column.
func _cactus_unchanged() -> void:
	var cacti := 0
	var bad := PackedStringArray()
	for sp in SpeciesDB.all():
		if sp.shape != S.CACTUS:
			continue
		cacti += 1
		for lod in LEVELS:
			if lod == PlantMeshes.LOD_FAR and not PlantMeshes.IMPOSTORS:
				continue
			var d := _digest(PlantMeshes.arrays_for(sp, lod))
			if d != CACTUS_DIGESTS[lod]:
				bad.append("%s L%d %s" % [sp.name, lod, d])
	var trich := 0
	var trich_cactus := 0
	for sp in SpeciesDB.all():
		if sp.genus == "Trichocereus":
			trich += 1
			if sp.shape == S.CACTUS:
				trich_cactus += 1
	ok(cacti > 0 and bad.is_empty() and trich > 0 and trich_cactus == trich,
		"every CACTUS unchanged: %d CACTUS species (all %d Trichocereus among them) build the same hero, near and far meshes as before queue 76%s" % [cacti, trich, "" if bad.is_empty() else (": " + ", ".join(bad))])
	var sp := SpeciesDB.find("Trichocereus pachanoi")
	if sp == null:
		ok(false, "the San Pedro (Trichocereus pachanoi) is loaded")
		return
	var v: PackedVector3Array = PlantMeshes.arrays_for(sp, PlantMeshes.LOD_NEAR)[Mesh.ARRAY_VERTEX]
	var top := 0.0
	for p in v:
		top = maxf(top, p.y)
	var widest := 0.0
	for j in CUTS:
		widest = maxf(widest, _diameter(_section(v, top * (j + 0.5) / CUTS)))
	ok(sp.shape == S.CACTUS and absf(top - 1.0) < 1e-3 and widest < 0.6 * top,
		"the San Pedro (Trichocereus pachanoi) is still the CACTUS column: %.2f tall (unit frame), %.2f at its widest" % [top, widest])


## A mesh's geometry digest: vertex count and an md5 of positions, normals,
## UV2 and CUSTOM0 (colours left out).
func _digest(a: Array) -> String:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var cu: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
	var parts := PackedStringArray()
	parts.append(str(v.size()))
	for i in v.size():
		parts.append("%d,%d,%d|%d,%d,%d|%d,%d|%d,%d,%d,%d" % [roundi(v[i].x * 1e4), roundi(v[i].y * 1e4), roundi(v[i].z * 1e4),
			roundi(nrm[i].x * 1e3), roundi(nrm[i].y * 1e3), roundi(nrm[i].z * 1e3), roundi(uv2[i].x * 1e3), roundi(uv2[i].y * 1e3),
			roundi(cu[i * 4] * 1e3), roundi(cu[i * 4 + 1] * 1e3), roundi(cu[i * 4 + 2] * 1e3), roundi(cu[i * 4 + 3] * 1e3)])
	return "%d:%s" % [v.size(), ";".join(parts).md5_text()]


## Triangles by material (UV2.x, to a quarter).
func _mats(a: Array) -> Dictionary:
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
	var out := {}
	for t in range(0, uv2.size(), 3):
		var k := snappedf(uv2[t].x, 0.25)
		out[k] = int(out.get(k, 0)) + 1
	return out


## The mesh's cross-section at height y: where its triangles' edges cross
## the level plane, in x-z.
func _section(v: PackedVector3Array, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in range(0, v.size(), 3):
		for e in [[v[t], v[t + 1]], [v[t + 1], v[t + 2]], [v[t + 2], v[t]]]:
			var p: Vector3 = e[0]
			var q: Vector3 = e[1]
			if (p.y - y) * (q.y - y) < 0.0:
				var x := p.lerp(q, (y - p.y) / (q.y - p.y))
				out.append(Vector2(x.x, x.z))
	return out


## A cross-section's width: the most, over 36 directions, between its
## farthest points.
func _diameter(pts: PackedVector2Array) -> float:
	if pts.size() < 2:
		return 0.0
	var best := 0.0
	for k in 36:
		var d := Vector2(cos(PI * k / 36.0), sin(PI * k / 36.0))
		var lo := INF
		var hi := -INF
		for p in pts:
			var s := p.dot(d)
			lo = minf(lo, s)
			hi = maxf(hi, s)
		best = maxf(best, hi - lo)
	return best


## Lobes round a cross-section about the origin: its points by angle, the
## times their distance rises through the middle of its range.
func _lobes(pts: PackedVector2Array) -> int:
	if pts.size() < 6:
		return 0
	var by: Array = []
	var lo := INF
	var hi := -INF
	for p in pts:
		by.append([fposmod(atan2(p.y, p.x), TAU), p.length()])
		lo = minf(lo, p.length())
		hi = maxf(hi, p.length())
	by.sort_custom(func(x, y): return x[0] < y[0])
	var mid := (lo + hi) * 0.5
	var ups := 0
	for i in by.size():
		var a: float = by[i][1]
		var b: float = by[(i + 1) % by.size()][1]
		if a < mid and b >= mid:
			ups += 1
	return ups


## The highest of the kept triangles (`keep`, one a triangle) over (x, z),
## or -INF where none is.
func _height_at(v: PackedVector3Array, keep: PackedByteArray, x: float, z: float) -> float:
	var best := -INF
	for t in range(0, v.size(), 3):
		if keep[t / 3] == 0:
			continue
		var a := v[t]
		var b := v[t + 1]
		var c := v[t + 2]
		var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(den) < 1e-12:
			continue
		var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / den
		var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / den
		var l3 := 1.0 - l1 - l2
		if l1 < -1e-6 or l2 < -1e-6 or l3 < -1e-6:
			continue
		best = maxf(best, l1 * a.y + l2 * b.y + l3 * c.y)
	return best


## How many separate groups points fall into (points nearer than `gap`
## join).
func _clusters(pts: PackedVector2Array, gap: float) -> int:
	var group := PackedInt32Array()
	group.resize(pts.size())
	group.fill(-1)
	var n := 0
	for i in pts.size():
		if group[i] >= 0:
			continue
		group[i] = n
		var stack := [i]
		while not stack.is_empty():
			var k: int = stack.pop_back()
			for j in pts.size():
				if group[j] < 0 and pts[j].distance_to(pts[k]) < gap:
					group[j] = n
					stack.append(j)
		n += 1
	return n


func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _list(a: PackedFloat32Array) -> String:
	var s := PackedStringArray()
	for x in a:
		s.append("%.2f" % x)
	return " ".join(s)


func _sacred_entry(id: String) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(SpeciesDB.SACRED_PATH))
	if doc is Dictionary:
		for tier in doc.get("plants", {}):
			for e in doc.plants[tier]:
				if e is Dictionary and str(e.get("id", "")) == id:
					return e
	return {}

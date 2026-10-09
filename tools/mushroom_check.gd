extends SceneTree
## The MUSHROOM plant shape (design §FM.13 item 1, queue 75), headless:
##   godot --headless --path . --script tools/mushroom_check.gd
## Asserts:
##  - PlantSpecies.Shape has MUSHROOM and an entry's shape string
##    "mushroom" reads as it;
##  - teonanácatl is built straight from its data/sacred entry the way
##    SpeciesDB builds a catalogue entry (SpeciesDB.species_in_file), and
##    data/sacred is still not loaded: SpeciesDB has the same species before
##    and after, and none of them comes from data/sacred (the open world and
##    the §CC trim untouched);
##  - the fly agaric and Caesar's mushroom load from their biome files as
##    MUSHROOM, and every loaded MUSHROOM species builds through mesh_for at
##    the near and far levels (the path VegetationPlacer and LitterField
##    take) from flesh alone;
##  - for each of the three, at the hero, near and far levels: every face is
##    a fungus's flesh (UV2.x -1: no leaf card, hull or far picture; no leaf
##    tiles, leaf type none, the shared untiled material), sway 0 and the
##    wind's still kind; the top is y = 1 (unit frame), the foot just under
##    the ground line, so drawn at any height in height_m its height is
##    inside height_m; the cap is cap.colour at its top and eases toward
##    cap.secondary at the rim, the gills under it are dark (and bluer,
##    pre-lit: occlusion toward navy); three fruit bodies (three stalks
##    through the plant at a third of its height), slightly leaning; the
##    cap's top faces up and the stalk's sides face out;
##  - teonanácatl's widest point (its cross-section, cut exactly from the
##    triangles at 60 heights, widest across) is in its top third at every
##    level (a cap, not a rosette); the Amanitas' is printed (INFO): their
##    younger caps are broad and sit lower, as a group of toadstools does;
##  - the far level keeps the cap-on-stalk silhouette: its cross-section
##    widths up the plant are the near level's a cut either side (within
##    15 % of the widest), widest at the same height (within 0.08);
##  - the cap's form as cap.form (or cap.notes) names it: teonanácatl conic
##    to bell with a low nipple, the fly agaric hemispherical to flat,
##    Caesar's domed to flat; the oldest cap as tall over its half-width as
##    its last form draws it (a bell at least 0.8, a flat cap at most 0.65);
##  - drawn at the middle of height_m, the middle body's cap is as broad as
##    cap.size_cm says and its stalk thin under it (0.07-0.25 of the cap
##    across; teonanácatl's 1-3 mm, its entry's refs).

const S := PlantSpecies.Shape
const LEVELS := [PlantMeshes.LOD_HERO, PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]
## The forms each entry's cap.form (Caesar's: cap.notes, "domed, then
## flat") names, youngest to oldest, and whether it has a low nipple.
const FORMS_OF := {
	"Psilocybe mexicana": ["conic", "bell", true],
	"Fly agaric": ["hemispherical", "flat", false],
	"Caesar's mushroom": ["convex", "flat", false],
}
## Heights the cross-section is cut at, up the plant.
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
	var probe := SpeciesDB.species_from_entry({"name": "mushroom_check probe", "shape": "mushroom"}, PlantSpecies.Tier.GROUND)
	ok(PlantSpecies.Shape.keys().has("MUSHROOM") and probe != null and probe.shape == S.MUSHROOM,
		"PlantSpecies.Shape has MUSHROOM, and an entry's shape \"mushroom\" reads as it")

	# Teonanácatl from its data/sacred entry, never loaded.
	var teo := SpeciesDB.species_in_file(SpeciesDB.SACRED_PATH, "teonanacatl")
	ok(teo != null and teo.shape == S.MUSHROOM, "teonanácatl builds from its data/sacred entry as a MUSHROOM (%s)" % (teo.name if teo else "missing"))
	if teo == null:
		_done()
		return
	var from_sacred := 0
	for sp in SpeciesDB.all():
		if sp.files.has(SpeciesDB.SACRED_PATH.get_file()):
			from_sacred += 1
	ok(SpeciesDB.all().size() == n0 and SpeciesDB.index_of(teo) == -1 and SpeciesDB.find(teo.name) == null and from_sacred == 0,
		"data/sacred is still not loaded: %d species before and after building teonanácatl, it has no index, and none of them comes from data/sacred (%d)" % [n0, from_sacred])
	var teo_e := _sacred_entry("teonanacatl")
	ok(teo.height_m == Vector2(0.04, 0.12) and teo.color.is_equal_approx(Color.from_string(str(teo_e.get("color", "")), Color.BLACK))
		and teo.leaf_type == "none" and teo.realms.has("neotropic") and teo.biomes.has(BiomeTemplates.id_of_key("CLOUD_FOREST"))
		and teo.biomes.has(BiomeTemplates.id_of_key("WET_MEADOW")) and teo.from_catalogue and not teo.appearance.is_empty(),
		"teonanácatl is built as a catalogue entry: height_m %s, its colour, leaf type '%s', realm %s, its two biomes, its appearance block" % [teo.height_m, teo.leaf_type, teo.realms])

	# The Amanitas, loaded from their biome files.
	var fly := SpeciesDB.find("Fly agaric")
	var caesar := SpeciesDB.find("Caesar's mushroom")
	ok(fly != null and fly.shape == S.MUSHROOM and fly.genus == "Amanita" and fly.files.has("04_taiga.json"),
		"the fly agaric (Amanita muscaria) loads from 04_taiga.json as a MUSHROOM")
	ok(caesar != null and caesar.shape == S.MUSHROOM and caesar.genus == "Amanita" and caesar.files.has("12_mediterranean_scrub.json"),
		"Caesar's mushroom (Amanita caesarea) loads from 12_mediterranean_scrub.json as a MUSHROOM")
	var loaded := 0
	var bad_loaded: Array[String] = []
	for sp in SpeciesDB.all():
		if sp.shape != S.MUSHROOM:
			continue
		loaded += 1
		for lod in [PlantMeshes.LOD_NEAR, PlantMeshes.LOD_FAR]:
			var m := PlantMeshes.mesh_for(sp, lod)
			if m == null or m.get_surface_count() == 0 or _mats(m.surface_get_arrays(0)).keys() != [-1.0]:
				bad_loaded.append("%s L%d" % [sp.name, lod])
	ok(loaded >= 2 and bad_loaded.is_empty(), "every loaded MUSHROOM species (%d) builds through mesh_for at the near and far levels from flesh alone (%s)" % [loaded, ", ".join(bad_loaded) if not bad_loaded.is_empty() else "all"])

	for sp in [teo, fly, caesar]:
		if sp != null:
			_check(sp, sp == teo)
	_done()


func _done() -> void:
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## One mushroom species at every level (`top_third`: assert its widest point
## is in its top third, the queue's check for teonanácatl).
func _check(sp: PlantSpecies, top_third: bool) -> void:
	var tag := sp.name
	var look := MushroomMesh.look_of(sp)
	var app: Dictionary = sp.appearance
	var cap: Dictionary = app.get("cap", {})
	var under: Dictionary = app.get("underside", {})
	var cap_col := Color.from_string(str(cap.get("colour", "")), Color.BLACK)
	var sec_col := Color.from_string(str(cap.get("secondary", "")), Color.BLACK)
	var gill_col := Color.from_string(str(under.get("colour", "")), Color.BLACK)
	var prelit := Prelit.on()
	ok(sp.leaf_type == "none" and sp.tiles.is_empty() and PlantMeshes.material_for(sp) == PlantMeshes.material(),
		"%s: leaf type none, no tiles, the shared untiled material (no leaf tiles)" % tag)
	ok(Wind.kind_of(sp) == 0 and not VegetationPlacer.HERB_SPREAD.has(sp.shape),
		"%s: the wind's still kind (it doesn't bow) and drawn at one scale every way (the cap keeps its shape)" % tag)
	var bodies := MushroomMesh.layout(sp, look)
	var leans: Array[float] = []
	for body in bodies:
		leans.append(rad_to_deg((body.axis as Vector3).angle_to(Vector3.UP)))
	ok(bodies.size() >= 2 and bodies.size() <= 5 and leans.max() <= 15.0 and leans.max() >= 3.0,
		"%s: %d fruit bodies to a plant, slightly leaning (%s degrees)" % [tag, bodies.size(), ", ".join(PackedStringArray(leans.map(func(x): return "%.1f" % x)))])
	var profiles := {}
	var widest := {}
	for lod in LEVELS:
		var a := PlantMeshes.arrays_for(sp, lod)
		var lt := "%s (level %d)" % [tag, lod]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var mats := _mats(a)
		var swaying := 0
		for c in col:
			if c.a > 1e-4:
				swaying += 1
		ok(v.size() > 0 and mats.keys() == [-1.0] and swaying == 0,
			"%s: %d triangles, every face a fungus's flesh (UV2.x -1: no leaf card, hull or far picture), sway 0 (%s)" % [lt, v.size() / 3, str(mats)])
		var lo := INF
		var hi := -INF
		var apex := 0
		for i in v.size():
			lo = minf(lo, v[i].y)
			if v[i].y > hi:
				hi = v[i].y
				apex = i
		var hmid := (sp.height_m.x + sp.height_m.y) * 0.5
		var inside := true
		for h in [sp.height_m.x, hmid, sp.height_m.y]:
			# Drawn at h (the instance's scale), its height above the ground
			# line (y 0; the foot sunk just under it).
			var drawn: float = hi * float(h)
			if drawn < sp.height_m.x - 1e-6 or drawn > sp.height_m.y + 1e-6:
				inside = false
		ok(absf(hi - 1.0) < 1e-3 and lo < 0.0 and lo > -0.06 and inside,
			"%s: top at y %.4f (unit frame), the foot %.3f under the ground line: drawn at %.2f-%.2f m it stands %.2f-%.2f m, inside height_m" % [lt, hi, -lo, sp.height_m.x, sp.height_m.y, hi * sp.height_m.x, hi * sp.height_m.y])
		# The cross-section up the plant, widest across.
		var prof := _profile(v, hi)
		profiles[lod] = prof
		var wi := 0
		for j in prof.size():
			if prof[j] > prof[wi]:
				wi = j
		var wy := (wi + 0.5) / CUTS
		widest[lod] = wy
		if top_third:
			ok(wy >= 2.0 / 3.0, "%s: its widest point (%.3f across, unit frame) is at %.2f of its height, in its top third: a cap, not a rosette" % [lt, prof[wi], wy])
		else:
			print("INFO  %s: widest point at %.2f of its height (%.3f across)" % [lt, wy, prof[wi]])
		# The cap's colour at its top and toward the secondary at the rim.
		var rim := MushroomMesh._ao(cap_col.lerp(sec_col, float(look.rim_share)), 0.88, prelit)
		var rims := 0
		for c in col:
			if _cdist(c, rim) < 0.003:
				rims += 1
		var apex_col := col[apex]
		var fleck_top: bool = _cdist(apex_col, sec_col) < 0.01 and bool(look.flecked)
		ok((fleck_top or _cdist(apex_col, cap_col) < 0.01) and rims >= 3 * 4 and _cdist(rim, sec_col) < _cdist(cap_col, sec_col),
			"%s: the cap is cap.colour %s at its top%s and eases toward cap.secondary %s at the rim (%d rim corners)" % [lt, cap_col.to_html(false), " (a white fleck on the very top)" if fleck_top else "", sec_col.to_html(false), rims])
		# The gills: faces turned down under the caps, dark (and bluer).
		var gl := 0.0
		var gb := 0.0
		var gn := 0
		for i in v.size():
			if nrm[i].y < -0.5 and v[i].y > 0.3:
				gl += col[i].get_luminance()
				gb += col[i].b / maxf(col[i].r, 1e-3)
				gn += 1
		gl /= maxf(gn, 1)
		gb /= maxf(gn, 1)
		var navy_ok := (not prelit) or gb > gill_col.b / maxf(gill_col.r, 1e-3)
		ok(gn > 0 and gl < 0.75 * gill_col.get_luminance() and navy_ok,
			"%s: the gills under the caps are dark: %d corners at %.2f of underside.colour's lightness%s" % [lt, gn, gl / maxf(gill_col.get_luminance(), 1e-3), (", bluer (occlusion toward navy, %.2f against %.2f blue over red)" % [gb, gill_col.b / maxf(gill_col.r, 1e-3)]) if prelit else ""])
		# Three stalks through the plant at a third of its height.
		var stalks := _clusters(_section(v, hi / 3.0), 3.0 * float(look.r_stalk) / hi)
		ok(stalks == bodies.size(), "%s: %d stalks cross a third of its height (%d fruit bodies)" % [lt, stalks, bodies.size()])
		# Outward: the top of the cap faces up, the middle stalk's sides out
		# (its middle ring; the far stalk has none, only its foot and top).
		var c_axis: Vector3 = (bodies[0].axis as Vector3)
		var outn := 0
		var stalk_v := 0
		var rs := float(bodies[0].stalk_r) / hi
		for i in v.size():
			if v[i].y < 0.2 or v[i].y > 0.5:
				continue
			var on_axis := c_axis * (v[i].y / c_axis.y)
			var radial := v[i] - on_axis
			radial -= c_axis * radial.dot(c_axis)
			if radial.length() < 2.5 * rs and radial.length() > 1e-6:
				stalk_v += 1
				if nrm[i].dot(radial.normalized()) > 0.5:
					outn += 1
		if lod == PlantMeshes.LOD_FAR:
			ok(nrm[apex].y > 0.8, "%s: lit outward: the cap's top faces up (%.2f)" % [lt, nrm[apex].y])
		else:
			ok(nrm[apex].y > 0.8 and stalk_v > 0 and outn >= int(stalk_v * 0.9),
				"%s: lit outward: the cap's top faces up (%.2f), the middle stalk's sides face out (%d of %d)" % [lt, nrm[apex].y, outn, stalk_v])
	# The far level keeps the near level's silhouette.
	var near: PackedFloat32Array = profiles[PlantMeshes.LOD_NEAR]
	var far: PackedFloat32Array = profiles[PlantMeshes.LOD_FAR]
	var worst := 0.0
	var top_w := 0.0
	for j in near.size():
		top_w = maxf(top_w, near[j])
	for j in near.size():
		# Against the near widths a cut either side (a rim's edge, tilted
		# with its lean, may fall a hair higher on the fewer-sided far cap).
		var lo := INF
		var hi := -INF
		for k in range(maxi(j - 1, 0), mini(j + 2, near.size())):
			lo = minf(lo, near[k])
			hi = maxf(hi, near[k])
		worst = maxf(worst, maxf(lo - far[j], far[j] - hi))
	ok(worst <= 0.15 * top_w and absf(float(widest[PlantMeshes.LOD_FAR]) - float(widest[PlantMeshes.LOD_NEAR])) <= 0.08,
		"%s: the far level keeps the cap-on-stalk silhouette: its widths up the plant within %.0f %% of the near level's widest (a cut either side), widest at %.2f against %.2f" % [tag, maxf(worst, 0.0) / maxf(top_w, 1e-6) * 100.0, widest[PlantMeshes.LOD_FAR], widest[PlantMeshes.LOD_NEAR]])
	# The middle body's cap and stalk, drawn at the middle of height_m.
	var hmid := (sp.height_m.x + sp.height_m.y) * 0.5
	var one := PlantMeshes._Builder.new()
	one.mat = MushroomMesh.FLESH
	MushroomMesh._body(one, bodies[0], look, false, prelit)
	var ov := one.v
	var otop := 0.0
	for p in ov:
		otop = maxf(otop, p.y)
	var cap_w := 0.0
	var rim_y := 0.0
	for j in CUTS:
		var w := _diameter(_section(ov, otop * (j + 0.5) / CUTS))
		if w > cap_w:
			cap_w = w
			rim_y = otop * (j + 0.5) / CUTS
	var stalk_w := _diameter(_section(ov, otop * 0.4))
	# The cap's form, as cap.form (or cap.notes) names it: its words, and
	# the middle (oldest) body's cap as tall over its half-width as that
	# form's last word draws it.
	var want: Array = FORMS_OF.get(sp.name, [])
	var forms: PackedStringArray = look.forms
	var tall := (otop - rim_y) / maxf(cap_w * 0.5, 1e-6)
	var last: String = forms[forms.size() - 1]
	var shape_ok := tall >= 0.8 if last in ["conic", "bell", "hemispherical"] else tall <= 0.65
	var named := str(cap.get("form", ""))
	if MushroomMesh.forms_in(named).is_empty():
		named = "cap.notes: " + str(cap.get("notes", ""))
	ok(Array(forms) == want.slice(0, want.size() - 1) and bool(look.nipple) == bool(want[want.size() - 1]) and shape_ok,
		"%s: the cap reads '%s' as %s%s; the oldest cap stands %.2f of its half-width tall" % [tag, named.left(60), " to ".join(forms), " with a low nipple" if look.nipple else "", tall])
	var cap_cm := cap_w / otop * hmid * 100.0
	var stalk_mm := stalk_w / otop * hmid * 1000.0
	var size: Array = cap.get("size_cm", [0, 0])
	var ratio := stalk_w / maxf(cap_w, 1e-6)
	var thin := ratio >= 0.07 and ratio <= 0.25
	if sp.genus == "Psilocybe":
		thin = thin and stalk_mm >= 1.0 and stalk_mm <= 3.0
	ok(cap_cm >= float(size[0]) and cap_cm <= float(size[1]) and thin,
		"%s: drawn %.2f m tall, the middle body's cap is %.1f cm across (cap.size_cm %s) on a stalk %.1f mm thick (%.2f of the cap)" % [tag, hmid, cap_cm, str(size), stalk_mm, ratio])


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


## Widths at CUTS heights up a mesh `top` tall.
func _profile(v: PackedVector3Array, top: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in CUTS:
		out.append(_diameter(_section(v, top * (j + 0.5) / CUTS)))
	return out


## How many separate groups a cross-section's points fall into (points
## nearer than `gap` join).
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


func _sacred_entry(id: String) -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(SpeciesDB.SACRED_PATH))
	if doc is Dictionary:
		for tier in doc.get("plants", {}):
			for e in doc.plants[tier]:
				if e is Dictionary and str(e.get("id", "")) == id:
					return e
	return {}

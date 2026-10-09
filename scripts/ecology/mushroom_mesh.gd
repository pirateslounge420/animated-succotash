class_name MushroomMesh
## The MUSHROOM plant shape (design §FM.13 item 1, queue 75): a few fruit
## bodies to a plant, each a cap on a stalk, drawn from the entry's own
## appearance block (PlantSpecies.appearance), so teonanácatl, the fly
## agaric and Caesar's mushroom stop being drawn as a leaf rosette.
## PlantMeshes._build calls build() for every MUSHROOM species.
##
##   * The cap's form from appearance.cap.form, read for its words: conic,
##     bell (campanulate), hemispherical, convex (domed), flat, funnel, and
##     a low nipple (umbo). "conic to bell" gives the youngest body the
##     first form and the oldest mostly the second, as caps open with age.
##     cap.notes are read when the form names none (Caesar's: "domed, then
##     flat"); convex when neither does.
##   * The cap's breadth from cap.size_cm against the plant's height
##     (height_m), both at the middle of their ranges; the stalk's thickness
##     from the cap's breadth (STALK_OF_CAP of it: a thread under
##     teonanácatl's little bell, a stout post under a fly agaric's plate);
##     the stalk's height is what height_m leaves under the cap.
##   * The cap in cap.colour, easing toward cap.secondary at the rim; a
##     flecked cap (cap.texture flecked, warty, scaly or spotted) carries
##     flecks of the secondary (the fly agaric's white warts); the gills in
##     underside.colour, deep in the cap's shade; the stalk in stipe.colour.
##   * Occlusion baked toward navy (Prelit.ao_tint, §ES.2), never grey: the
##     gills under the cap, the stalk just under the cap, the foot in the
##     grass (PlantMeshes' own darker foot is left off these faces).
##   * A swollen foot where the text says bulb or bulbous, a white sack
##     round it where it says volva, a skirt where it says skirt, ring or
##     annulus (never "no ring").
##
## Painted (§ES): diffuse only, no textures, no leaf tiles (leaf type none):
## every face is material FLESH (UV2.x -1: the foliage shader's bark rules,
## closed and lit outward, cast from its far faces, without the bark tile,
## the bark-brown pull or moss), sway 0 (a mushroom doesn't bow in the
## wind). Unit frame like every plant mesh: the tallest body's top is
## y = 1, so an instance is as tall as its scale, inside height_m.
##
## Three bodies at every level, the oldest in the middle leaning a little
## and two younger, nearly as tall, round it leaning out (small caps, like
## teonanácatl's, all sit in the plant's top third; broad ones, like the
## Amanitas', reach lower, as a group of toadstools does), from the same
## draws at every level, so the silhouette doesn't pop; the far level
## (PlantMeshes.own_far: never the one-quad picture) keeps every cap on its
## stalk with fewer sides, and drops the flecks and the skirt (PLANT_SCHEMA
## §5: LOD strips detail, never the structure).

## UV2.x of a fungus's flesh (foliage.gdshader).
const FLESH := -1.0
## Cap forms: h, its height over its radius; e, the profile's exponent (the
## profile runs from the rim (r R, y 0) to the apex (0, h R) as
## r = R cos(a)^e, y = h R sin(a)^e: e 2 a straight-sided cone, 1 a
## half-ellipse, under 1 a squarer, fuller crown); dip, how far below the
## rim's top a funnel's middle sinks (in cap heights).
const FORMS := {
	"conic": {"h": 1.15, "e": 1.6, "dip": 0.0},
	"bell": {"h": 0.95, "e": 0.9, "dip": 0.0},
	"hemispherical": {"h": 0.85, "e": 1.0, "dip": 0.0},
	"convex": {"h": 0.55, "e": 1.0, "dip": 0.0},
	"flat": {"h": 0.3, "e": 0.6, "dip": 0.0},
	"funnel": {"h": 0.32, "e": 0.6, "dip": 1.3},
}
## The words that name each form in cap.form (in the order they stand).
const WORDS := [
	["conic", "conic"], ["witch", "conic"],
	["campanulate", "bell"], ["bell", "bell"],
	["hemispher", "hemispherical"],
	["convex", "convex"], ["dome", "convex"], ["cushion", "convex"],
	["flat", "flat"], ["plane", "flat"], ["expanded", "flat"], ["parasol", "flat"],
	["funnel", "funnel"], ["vase", "funnel"], ["depressed", "funnel"],
]
const NIPPLE_WORDS := ["nipple", "umbo", "papill"]
## Cap textures that carry flecks of cap.secondary.
const FLECKED := ["fleck", "wart", "scaly", "spotted"]
## The stalk's radius over its cap's (real stipes run about a tenth of the
## cap across: Psilocybe mexicana 1-3 mm under 0.5-3 cm, the fly agaric
## 1-2 cm under 8-20 cm), and the thinnest it gets (unit frame), so it
## stays a line at 64 px.
const STALK_OF_CAP := 0.11
const STALK_MIN := 0.011
## The bodies, oldest first: [height (share of the tallest), how far
## through its forms (0 the first named, 1 the last), cap radius (share of
## the plant's), flecks near]. The younger stand nearly as tall, so a
## small-capped group is widest in its top third (a cap on a stalk, read at
## 64 px; tools/mushroom_check.gd).
const BODIES := [[1.0, 0.8, 1.0, 12], [0.9, 0.45, 0.84, 9], [0.8, 0.1, 0.7, 6]]
## How far a cap's colour eases toward its secondary at the rim (less on a
## flecked cap, whose secondary is its flecks').
const RIM_SHARE := 0.35
const RIM_SHARE_FLECKED := 0.2
## A volva's colour (the entries give none: nearly all are white).
const VOLVA_COLOR := Color(0.92, 0.9, 0.85)
## The foot in the grass's shade (unit frame: below FOOT_AO_Y, down to
## FOOT_AO at the ground), as PlantMeshes darkens every plant's foot, but
## toward navy.
const FOOT_AO_Y := 0.14
const FOOT_AO := 0.58


## Build `sp`'s mushrooms into `b` (PlantMeshes._build; `far`: the far
## level).
static func build(b: PlantMeshes._Builder, sp: PlantSpecies, far: bool) -> void:
	var look := look_of(sp)
	var start := b.v.size()
	var mat_was := b.mat
	b.mat = FLESH
	var prelit := Prelit.on()
	for body in layout(sp, look):
		_body(b, body, look, far, prelit)
	b.mat = mat_was
	# The tallest top to y = 1 (unit frame), every part scaled alike.
	var top := 0.0
	for i in range(start, b.v.size()):
		top = maxf(top, b.v[i].y)
	if top > 1e-4:
		for i in range(start, b.v.size()):
			b.v[i] = b.v[i] / top
	for i in range(start, b.v.size()):
		var y := b.v[i].y
		if y >= 0.0 and y < FOOT_AO_Y:
			b.c[i] = _ao(b.c[i], lerpf(FOOT_AO, 1.0, smoothstep(0.0, FOOT_AO_Y, y)), prelit)


## What the entry says about its mushrooms, read once: the cap's radius
## and the stalk's (unit frame, before the top is scaled to 1), the forms
## named, a nipple, flecks, the foot, the skirt, and the colours.
static func look_of(sp: PlantSpecies) -> Dictionary:
	var app: Dictionary = sp.appearance
	var cap: Dictionary = app.get("cap", {}) if app.get("cap") is Dictionary else {}
	var under: Dictionary = app.get("underside", {}) if app.get("underside") is Dictionary else {}
	var stipe: Dictionary = app.get("stipe", {}) if app.get("stipe") is Dictionary else {}
	var form := str(cap.get("form", ""))
	var notes := str(cap.get("notes", ""))
	var forms := forms_in(form)
	if forms.is_empty():
		forms = forms_in(notes)
	if forms.is_empty():
		forms = PackedStringArray(["convex"])
	var text := ("%s %s %s %s" % [form, notes, str(app.get("habit", "")), str(app.get("silhouette", ""))]).to_lower()
	var nipple := false
	for w in NIPPLE_WORDS:
		if form.to_lower().contains(w) or notes.to_lower().contains(w):
			nipple = true
	var ring := RegEx.create_from_string("(?<!no )(?<!fairy )\\b(ring|annulus)\\b")
	var size = cap.get("size_cm", [])
	var cap_cm := (float(size[0]) + float(size[1])) * 0.5 if size is Array and size.size() == 2 else 5.0
	var h_cm := (sp.height_m.x + sp.height_m.y) * 50.0
	var r_cap := clampf(cap_cm * 0.5 / maxf(h_cm, 0.1), 0.05, 0.9)
	var texture := str(cap.get("texture", "")).to_lower()
	var flecked := false
	for w in FLECKED:
		if texture.contains(w):
			flecked = true
	var cap_col := _col(cap.get("colour"), sp.color)
	return {
		"forms": forms,
		"nipple": nipple,
		"r_cap": r_cap,
		"r_stalk": maxf(r_cap * STALK_OF_CAP, STALK_MIN),
		"flecked": flecked,
		"bulb": text.contains("bulb"),
		"volva": text.contains("volva"),
		"skirt": text.contains("skirt") or ring.search(text) != null,
		"cap": cap_col,
		"secondary": _col(cap.get("secondary"), cap_col.lightened(0.3)),
		"gills": _col(under.get("colour"), cap_col.darkened(0.3)),
		"stalk": _col(stipe.get("colour"), sp.accent),
		"rim_share": RIM_SHARE_FLECKED if flecked else RIM_SHARE,
	}


## The cap forms a text names, in the order they stand ("small conic to
## bell-shaped cap" -> conic, bell), each once in a row.
static func forms_in(text: String) -> PackedStringArray:
	var t := text.to_lower()
	var hits: Array = []
	for w in WORDS:
		var at := t.find(w[0])
		while at >= 0:
			hits.append([at, w[1]])
			at = t.find(w[0], at + 1)
	hits.sort_custom(func(x, y): return x[0] < y[0])
	var out := PackedStringArray()
	for h in hits:
		if out.is_empty() or out[out.size() - 1] != h[1]:
			out.append(h[1])
	return out


## A form's numbers `t` of the way from the first form named to the last.
static func form_at(forms: PackedStringArray, t: float) -> Dictionary:
	var f0: Dictionary = FORMS[forms[0]]
	var f1: Dictionary = FORMS[forms[forms.size() - 1]]
	return {"h": lerpf(f0.h, f1.h, t), "e": lerpf(f0.e, f1.e, t), "dip": lerpf(f0.dip, f1.dip, t)}


## The fruit bodies, the same at every level (from the species, never the
## level), oldest first, unit frame before the top is scaled to 1: foot,
## axis (leaning), height along it, cap radius, form numbers, stalk radius,
## turn, fleck count and fleck seed. The oldest stands in the middle
## leaning a little any way; the younger two stand round it, spaced so
## their caps clear its cap, leaning outward.
static func layout(sp: PlantSpecies, look := {}) -> Array[Dictionary]:
	if look.is_empty():
		look = look_of(sp)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sp.name, sp.genus, sp.species, "mushroom"])
	var r_cap: float = look.r_cap
	var phi0 := rng.randf() * TAU
	var out: Array[Dictionary] = []
	for k in BODIES.size():
		var spec: Array = BODIES[k]
		var hk: float = float(spec[0]) * (1.0 if k == 0 else rng.randf_range(0.97, 1.0))
		var rk: float = r_cap * float(spec[2])
		var foot := Vector3.ZERO
		var lean_dir: Vector3
		var lean: float
		if k == 0:
			var a0 := rng.randf() * TAU
			lean_dir = Vector3(cos(a0), 0.0, sin(a0))
			lean = deg_to_rad(rng.randf_range(2.0, 5.0))
		else:
			var a := phi0 + (k - 1) * TAU * 0.42 + rng.randf_range(-0.35, 0.35)
			lean_dir = Vector3(cos(a), 0.0, sin(a))
			foot = lean_dir * ((r_cap + rk) * 0.75 + 3.0 * float(look.r_stalk))
			lean = deg_to_rad(rng.randf_range(6.0, 11.0))
		out.append({
			"foot": foot,
			"axis": (Vector3.UP * cos(lean) + lean_dir * sin(lean)).normalized(),
			"height": hk,
			"cap_r": rk,
			"form": form_at(look.forms, float(spec[1])),
			"stalk_r": maxf(rk * STALK_OF_CAP, STALK_MIN),
			"turn": rng.randf() * TAU,
			"flecks": int(spec[3]),
			"seed": rng.randi(),
		})
	return out


## The cap's outer profile, rim to apex: [radius, height above the rim]
## at each of `steps` (shares of the quarter turn), nipple and funnel
## included.
static func cap_profile(rk: float, f: Dictionary, nip: float, steps: Array) -> PackedVector2Array:
	var h: float = f.h * rk
	var e: float = f.e
	var out := PackedVector2Array()
	for s in steps:
		var a := float(s) * PI * 0.5
		var r := rk * pow(cos(a), e) if float(s) < 1.0 else 0.0
		var y := h * pow(sin(a), e)
		y -= float(f.dip) * h * pow(clampf(1.0 - r / rk, 0.0, 1.0), 0.8)
		y += nip * exp(-pow(r / (0.25 * rk), 2.0))
		out.append(Vector2(r, y))
	return out


static func _body(b: PlantMeshes._Builder, body: Dictionary, look: Dictionary, far: bool, prelit: bool) -> void:
	var foot: Vector3 = body.foot
	var u: Vector3 = body.axis
	var length: float = body.height
	var rk: float = body.cap_r
	var f: Dictionary = body.form
	var rs: float = body.stalk_r
	var turn: float = body.turn
	var s1 := u.cross(Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var s2 := u.cross(s1).normalized()
	var nip := 0.14 * rk if look.nipple else 0.0
	var steps := [0.0, 0.45, 0.8, 1.0] if far else ([0.0, 0.3, 0.55, 0.78, 0.9, 1.0] if nip > 0.0 else [0.0, 0.3, 0.55, 0.78, 1.0])
	var prof := cap_profile(rk, f, nip, steps)
	var cap_top := 0.0
	for p in prof:
		cap_top = maxf(cap_top, p.y)
	var h: float = f.h * rk
	# The rim, the gills' reach up under the cap (deeper in a tall cap), and
	# the stalk's top a little above them, inside the cap.
	var y_rim := maxf(length - cap_top, length * 0.25)
	var g := h * lerpf(0.15, 0.5, clampf((float(f.h) - 0.3) / 0.85, 0.0, 1.0))
	var stalk_top := y_rim + g * 1.3
	var o_cap := foot + u * y_rim
	var cap_sides := 7 if far else b.sides(10)
	var stalk_sides := 4 if far else b.sides(6)
	# The cap: its colour easing toward the secondary at the rim, the rim's
	# lower edge a touch shaded.
	var cols := PackedColorArray()
	for i in prof.size():
		var w := 1.0 - sin(float(steps[i]) * PI * 0.5)
		var c: Color = (look.cap as Color).lerp(look.secondary, float(look.rim_share) * w * w)
		cols.append(_ao(c, 0.88 if i == 0 else 1.0, prelit))
	lathe(b, o_cap, u, s1, s2, prof, cols, cap_sides, turn)
	# The gills, from where the stalk enters out to the rim, deep in shade.
	var r_in := rs * 0.86 * 0.85
	var gills := PackedVector2Array([Vector2(r_in, g), Vector2(rk * 0.985, 0.0)]) if far \
		else PackedVector2Array([Vector2(r_in, g), Vector2(lerpf(r_in, rk, 0.55), g * 0.55), Vector2(rk * 0.985, 0.0)])
	var gcols := PackedColorArray()
	for i in gills.size():
		gcols.append(_ao(look.gills, lerpf(0.35, 0.6, float(i) / (gills.size() - 1)), prelit))
	lathe(b, o_cap, u, s1, s2, gills, gcols, cap_sides, turn)
	# The stalk: a swollen foot (more where the entry says bulbous), a
	# slight taper up, darker just under the cap (the more, the broader the
	# cap over it), closed underneath.
	var foot_k := 1.8 if look.bulb else 1.25
	var y_f := -maxf(0.02, rs * foot_k * 0.3)
	var ao_top := lerpf(0.82, 0.58, clampf(rk / maxf(stalk_top, 1e-3) * 2.0, 0.0, 1.0))
	var stalk := PackedVector2Array([Vector2(rs * foot_k, y_f)])
	var scols := PackedColorArray([_ao(look.stalk, 1.0, prelit)])
	if look.bulb and not far:
		stalk.append(Vector2(rs * lerpf(foot_k, 1.0, 0.6), stalk_top * 0.06))
		scols.append(_ao(look.stalk, 1.0, prelit))
	if not far:
		stalk.append(Vector2(rs, stalk_top * 0.45))
		scols.append(_ao(look.stalk, 1.0, prelit))
	stalk.append(Vector2(rs * 0.86, stalk_top))
	scols.append(_ao(look.stalk, ao_top, prelit))
	lathe(b, foot, u, s1, s2, stalk, scols, stalk_sides, turn * 0.5)
	var under_c := _ao(look.stalk, 0.7, prelit)
	lathe(b, foot, u, s1, s2, PackedVector2Array([Vector2(0.0, y_f), Vector2(rs * foot_k, y_f)]), PackedColorArray([under_c, under_c]), stalk_sides, turn * 0.5)
	if look.volva:
		# A white sack round the foot, open at the top (Caesar's egg).
		var vc := _ao(VOLVA_COLOR, 1.0, prelit)
		var vprof := PackedVector2Array([Vector2(rs * 2.1, y_f), Vector2(rs * 1.75, stalk_top * 0.15)]) if far \
			else PackedVector2Array([Vector2(rs * 2.1, y_f), Vector2(rs * 2.0, stalk_top * 0.08), Vector2(rs * 1.75, stalk_top * 0.15)])
		var vcols := PackedColorArray()
		for i in vprof.size():
			vcols.append(vc if i > 0 else _ao(VOLVA_COLOR, 0.8, prelit))
		lathe(b, foot, u, s1, s2, vprof, vcols, stalk_sides, turn)
	if far:
		return
	if look.skirt:
		# The skirt hanging from high on the stalk.
		var ys := stalk_top * 0.7
		lathe(b, foot, u, s1, s2, PackedVector2Array([Vector2(rs * 1.9, ys - stalk_top * 0.06), Vector2(rs * 1.08, ys)]),
			PackedColorArray([_ao(look.stalk, 0.85, prelit), _ao(look.stalk, 0.75, prelit)]), stalk_sides, turn)
	if look.flecked:
		_flecks(b, o_cap, u, s1, s2, rk, f, nip, int(body.flecks), int(body.seed), _ao(look.secondary, 1.0, prelit))


## Flecks on the cap (the fly agaric's warts): low five-sided studs of
## the secondary colour standing on its upper surface.
static func _flecks(b: PlantMeshes._Builder, o_cap: Vector3, u: Vector3, s1: Vector3, s2: Vector3, rk: float, f: Dictionary, nip: float, count: int, seed_v: int, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var below := o_cap - u * rk * 0.5
	for i in count:
		var s := rng.randf_range(0.18, 0.9)
		var phi := rng.randf() * TAU
		var d := s1 * cos(phi) + s2 * sin(phi)
		var at := func(t: float) -> Vector3:
			var p := cap_profile(rk, f, nip, [t])[0]
			return o_cap + u * p.y + d * p.x
		var p0: Vector3 = at.call(s)
		var t1: Vector3 = at.call(minf(s + 0.02, 0.999)) - at.call(maxf(s - 0.02, 0.0))
		var t2 := u.cross(d)
		var n := t1.cross(t2).normalized()
		if n.dot(p0 - below) < 0.0:
			n = -n
		var size := rk * rng.randf_range(0.07, 0.11)
		var n1 := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var n2 := n.cross(n1).normalized()
		lathe(b, p0, n, n1, n2, PackedVector2Array([Vector2(size, -rk * 0.01), Vector2(0.0, size * 0.45)]), PackedColorArray([col, col]), 5, rng.randf() * TAU)


## A surface of revolution round `axis` from `origin`: `prof` [radius,
## height] ring by ring, `cols` a colour per ring, `sides` round, turned
## by `turn`; one smoothing part, sway 0. Rings go the way that leaves the
## solid on the profile's left (up a stalk, rim to apex over a cap, from
## the stalk out to the rim under it), so the builder's winding
## (_Builder.tri3) gives outward normals; a ring of radius 0 closes the
## surface to a point.
static func lathe(b: PlantMeshes._Builder, origin: Vector3, axis: Vector3, s1: Vector3, s2: Vector3, prof: PackedVector2Array, cols: PackedColorArray, sides: int, turn := 0.0) -> void:
	b.part += 1
	var rings: Array = []
	for i in prof.size():
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides + turn
			ring.append(origin + axis * prof[i].y + (s1 * cos(a) + s2 * sin(a)) * prof[i].x)
		rings.append(ring)
	for i in prof.size() - 1:
		var lo: PackedVector3Array = rings[i]
		var hi: PackedVector3Array = rings[i + 1]
		for k in sides:
			var k1 := (k + 1) % sides
			if prof[i].x > 1e-6:
				b.tri3(lo[k], hi[k1], lo[k1], cols[i], cols[i + 1], cols[i], 0.0, 0.0, 0.0)
			if prof[i + 1].x > 1e-6:
				b.tri3(lo[k], hi[k], hi[k1], cols[i], cols[i + 1], cols[i + 1], 0.0, 0.0, 0.0)


## A colour from the entry ("#b0723a"), else `fallback`.
static func _col(v, fallback: Color) -> Color:
	return Color.from_string(str(v), fallback) if v is String and str(v).begins_with("#") else fallback


## `c` shaded by occlusion `ao` (1 open): toward navy when pre-lit (§ES.2),
## else plainly darker.
static func _ao(c: Color, ao: float, prelit: bool) -> Color:
	if ao >= 0.999:
		return c
	return Prelit.ao_tint(c, ao) if prelit else Color(c.r * ao, c.g * ao, c.b * ao, c.a)

class_name BulbMesh
## The BULB plant shape (design §FM.13 item 3, queue 77): a bare brown
## bulb half out of the ground and, from its neck, a flat upright fan of
## strap leaves in one plane (two ranks), drawn from the entry's own
## appearance block (PlantSpecies.appearance) and its bark block (the
## bulb's tunics, PlantSpecies.bark), so leshoma stops being drawn as a
## spike rosette. PlantMeshes._build calls build() for every BULB species.
##
##   * The bulb: as broad as appearance.trunk.notes says ("15-25 cm
##     across": the middle; BULB_OF_HEIGHT of the plant's height when they
##     give none), widest at the ground line (y 0), so its top half sits
##     bare above the ground and the rest is under it, closing into a neck
##     (PROFILE). Painted in bark.color (pulled toward the game's bark
##     brown as the plant shader pulls every bark: painted_bark), its
##     papery tunics in bands (every other ring BAND darker), the dome's
##     shoulder and the neck toward bark.color_2 where the tunics tear and
##     fray, and a few shreds of tunic standing round the neck's top.
##   * The leaves: as many as appearance.leaf.notes says ("8-16 ...
##     straps": one count for the species, inside that), each a strap as
##     long as appearance.leaf.size_cm says (the middle; the inner, younger
##     ones YOUNG_LENGTH of that) and as broad as its length over the leaf
##     block's aspect; stiff (a gentle arch, more with canopy.droop); blunt
##     where the leaf block's apex is obtuse (or the notes say blunt): a
##     rounded end; its edges rippled where appearance.leaf.margin or the
##     notes say wavy, undulate or rippled (the margins rise and fall out
##     of the blade, its width swells and narrows with them); a few of
##     them twisted a little where the notes say twisted.
##   * Two ranks in one plane: one leaf leans left, the next right, each
##     pair leaning farther out than the pair inside it (the outermost,
##     oldest, LEAN_OUTER from upright at its foot and its tip, the
##     innermost LEAN_INNER), every leaf in the mesh's x-y plane, each in
##     its own sliver of depth (z), so no two blades lie in one plane: a
##     flat upright fan, a line seen edge-on. Its front face
##     appearance.leaf.colour, its back appearance.leaf.underside, a darker
##     midrib toward vein_colour; the feet in the neck's shade.
##   * The fan's plane turns at random per instance: the mesh is shared by
##     every plant of the species, and each placer turns its plants by a
##     random yaw round their up (VegetationPlacer._emit; species_row.gd's
##     TURN_DEG sets it by hand), so one fan faces you and the next shows
##     you its edge.
##
## Painted (§ES): diffuse only, no textures, no leaf tiles. Every face is
## the plant shader's painted flesh (UV2.x -1, MushroomMesh.FLESH: bark's
## rules, closed and lit outward, cast from its far faces, in its own
## colour without the bark tile, the bark-brown pull or moss), so each leaf
## is a closed strap, a thin lens across. Occlusion baked toward navy (or
## olive on a green: Prelit.ao_tint, §ES.2), never grey: the bulb's foot in
## the ground, the leaves' feet in the neck (PlantMeshes' own darker foot
## is left off these faces). The bulb holds still; the leaves sway a little
## at their tips (LEAF_SWAY: stiff). Unit frame like every plant mesh: the
## fan's top is y = 1, so an instance is as tall as its scale, inside
## height_m.
##
## The far level (PlantMeshes.own_far: never the one-quad picture, which
## turns to face the camera and would draw a fan seen edge-on as a fan)
## keeps every leaf on the same line in the one plane (PLANT_SCHEMA §5: LOD
## strips detail, never the structure), with fewer segments, no ripples
## and no shreds, and fewer sides and rings to the bulb.
##
## Not drawn: the flower head (a round head of narrow pink trumpets on a
## short thick stalk, sitting on the bulb before the leaves, in its bloom
## season). Torchfire 1 has one clock and no year (§FK.3), so there is no
## season to show it in, and the open world, which has one, doesn't load
## data/sacred (§FM.9): the leafy form only, as queue 77 allows.

## UV2.x of a painted face (foliage.gdshader's flesh; MushroomMesh.FLESH).
const PAINTED := -1.0
## The bulb's breadth when the entry's notes give none (a share of the
## plant's height).
const BULB_OF_HEIGHT := 0.45
## The bulb's profile, [radius, height] in bulb radii, from its foot under
## the ground up to its neck's top: widest at the ground line, the top half
## bare above it, closing into the neck. The far level keeps FAR_ROWS.
const PROFILE := [[0.0, -0.62], [0.55, -0.58], [0.88, -0.38], [1.0, -0.06], [0.97, 0.16],
	[0.84, 0.42], [0.62, 0.66], [0.4, 0.86], [0.31, 1.06], [0.27, 1.3]]
const FAR_ROWS := [0, 2, 3, 5, 7, 9]
## The neck's top (bulb radii above the ground line; PROFILE's last row),
## and how far under it the leaves' feet start, inside the neck.
const NECK_TOP := 1.3
const FOOT_DEPTH := 0.15
## Every other ring of tunics above the ground this much darker; the share
## of the tunics' pale colour (bark.color_2) at the frayed neck (less on
## the dome's shoulder, where the outer tunics tear).
const BAND := 0.9
const NECK_CREAM := 0.45
## Shreds of frayed tunic standing round the neck's top (near levels).
const SHREDS := 6
## Occlusion: the bulb's foot in the ground (at and under the ground line),
## the neck's top under the fan.
const FOOT_AO := 0.55
const NECK_AO := 0.7
## Leaves when the notes give no count.
const LEAVES := Vector2i(8, 16)
## Lean from upright (degrees) at a leaf's foot (x) and tip (y): the
## innermost (youngest) pair and the outermost (oldest).
const LEAN_INNER := Vector2(3.0, 8.0)
const LEAN_OUTER := Vector2(30.0, 60.0)
## The innermost leaves' length against the outermost's.
const YOUNG_LENGTH := 0.78
## A leaf's width over its length when the leaf block gives no aspect.
const WIDTH_OF_LENGTH := 0.085
## The leaf's width at its foot (a share of its width); where its blunt (or
## pointed) end starts narrowing (a share of its length) and how narrow it
## gets there.
const FOOT_WIDTH := 0.75
const TIP_FROM := 0.86
const TIP_BLUNT := 0.55
const TIP_POINTED := 0.2
## A leaf's half-thickness over its width (a stiff, fleshy strap), and how
## far apart the leaves' planes stand (in leaf thicknesses).
const THICK_OF_WIDTH := 0.05
const STACK := 1.4
## The rippled edge: how far the margins rise and fall out of the blade and
## how much its width swells and narrows with them (shares of its width),
## from RIPPLE_FROM of the way up the leaf (eased in over a quarter more).
const RIPPLE := 0.17
const RIPPLE_WIDTH := 0.08
const RIPPLE_FROM := 0.3
## The share of leaves twisted where the notes say twisted, and how far a
## twisted one turns by its tip (degrees).
const TWIST_SHARE := 0.35
const TWIST_DEG := Vector2(10.0, 28.0)
## Sway at a leaf's tip (stiff leaves: a little); the bulb holds still.
const LEAF_SWAY := 0.35
## The midrib's colour: how far toward vein_colour, front and back.
const MIDRIB := 0.45
const MIDRIB_BACK := 0.3
## Occlusion at a leaf's foot, eased off over its first LEAF_AO_LEN.
const LEAF_AO := 0.55
const LEAF_AO_LEN := 0.3
## The centerline's integration steps (every level's segment count divides
## it, so the levels sample one curve).
const FINE := 48
## Colours when the entry gives none.
const BULB_BROWN := Color(0.48, 0.35, 0.24)
const BULB_CREAM := Color(0.85, 0.78, 0.61)
## The plant shader pulls every bark toward its warm brown by day
## (shaders/palette.gdshaderinc: pal_bark, 70 %, keeping half of the
## colour's brightness difference from pal_ref_luma) but leaves painted
## flesh its own colour, so the bulb's tunics (the entry's bark block) take
## that pull here, and read as the game's bark brown under the blue sky
## rather than a pale pink. The palette's numbers, copied: change them
## with it.
const BARK_BROWN := Color(0.72, 0.39, 0.18)
const BARK_PULL := 0.7
const PAL_REF_LUMA := 0.4
## Words in appearance.leaf.margin / notes for a rippled edge, and the leaf
## block's blunt apexes.
const RIPPLE_WORDS := ["wavy", "undulat", "ripple", "crisp"]
const BLUNT_APEX := ["obtuse", "rounded", "truncate", "retuse", "emarginate"]


## Build `sp`'s bulb and its fan into `b` (PlantMeshes._build; `far`: the
## far level).
static func build(b: PlantMeshes._Builder, sp: PlantSpecies, far: bool) -> void:
	var look := look_of(sp)
	var start := b.v.size()
	var mat_was := b.mat
	b.mat = PAINTED
	var prelit := Prelit.on()
	_bulb(b, look, far, prelit)
	for leaf in layout(sp, look):
		_leaf(b, leaf, look, far, prelit)
	b.mat = mat_was
	# The fan's top to y = 1 (unit frame), every part scaled alike.
	var top := 0.0
	for i in range(start, b.v.size()):
		top = maxf(top, b.v[i].y)
	if top > 1e-4:
		for i in range(start, b.v.size()):
			b.v[i] = b.v[i] / top


## What the entry says about its bulb and leaves, read once, in metres as
## drawn at the middle of height_m (before the top is scaled to 1): the
## bulb's radius, the leaves' count, length and width, rippled, blunt,
## twisted, the arch, and the colours.
static func look_of(sp: PlantSpecies) -> Dictionary:
	var app: Dictionary = sp.appearance
	var trunk: Dictionary = app.get("trunk", {}) if app.get("trunk") is Dictionary else {}
	var leaf: Dictionary = app.get("leaf", {}) if app.get("leaf") is Dictionary else {}
	var notes := str(leaf.get("notes", ""))
	var words := ("%s %s" % [notes, str(leaf.get("margin", ""))]).to_lower()
	var h_m := maxf((sp.height_m.x + sp.height_m.y) * 0.5, 0.05)
	var across := mean_range(str(trunk.get("notes", "")), "cm\\s+across")
	var length := _mean_cm(leaf.get("size_cm"))
	if length <= 0.0:
		length = (sp.leaf_size_m.x + sp.leaf_size_m.y) * 0.5 if sp.leaf_size_m.y > 0.0 else h_m * 0.8
	var rippled := false
	for w in RIPPLE_WORDS:
		if words.contains(w):
			rippled = true
	var droop := clampf(float(sp.canopy.get("droop", 0.25)), 0.0, 1.0)
	var leaf_col := _col(leaf.get("colour"), sp.color)
	return {
		"bulb_r": across * 0.005 if across > 0.0 else h_m * BULB_OF_HEIGHT * 0.5,
		"count": count_in(notes),
		"length": length,
		"width": length / sp.leaf_aspect if sp.leaf_aspect > 1.0 else length * WIDTH_OF_LENGTH,
		"rippled": rippled,
		"blunt": sp.leaf_apex in BLUNT_APEX or words.contains("blunt"),
		"twisted": words.contains("twist"),
		"arch": lerpf(0.6, 1.4, clampf(droop / 0.5, 0.0, 1.0)),
		"leaf": leaf_col,
		"under": _col(leaf.get("underside"), leaf_col.lightened(0.1)),
		"vein": _col(leaf.get("vein_colour"), leaf_col.darkened(0.15)),
		"bulb": painted_bark(_col(sp.bark.get("color"), BULB_BROWN)),
		"tunic": painted_bark(_col(sp.bark.get("color_2"), BULB_CREAM)),
		"seed": hash([sp.name, sp.genus, sp.species, "bulb"]),
	}


## The middle of the first "a-b <unit>" range in a text ("15-25 cm
## across" -> 20), or -1.
static func mean_range(text: String, unit: String) -> float:
	var re := RegEx.create_from_string("(\\d+(?:\\.\\d+)?)\\s*(?:-|–|to)\\s*(\\d+(?:\\.\\d+)?)\\s*" + unit)
	var m := re.search(text)
	if m == null:
		return -1.0
	return (float(m.get_string(1)) + float(m.get_string(2))) * 0.5


## The leaf count a text gives ("8-16 stiff, blunt ... straps" -> 8, 16),
## else LEAVES.
static func count_in(text: String) -> Vector2i:
	var re := RegEx.create_from_string("(\\d+)\\s*(?:-|–|to)\\s*(\\d+)\\b[^.;\\d]*?\\b(?:straps?|leaves|leaf|blades?)\\b")
	var m := re.search(text.to_lower())
	if m == null:
		return LEAVES
	var lo := maxi(int(m.get_string(1)), 2)
	return Vector2i(lo, maxi(int(m.get_string(2)), lo))


## The leaves, the same at every level (from the species, never the
## level), innermost first, in metres before the top is scaled to 1: side
## (+1 leaning toward +x, -1 toward -x, alternating: the two ranks), pair
## (0 the innermost), foot (inside the neck, its z the leaf's own sliver of
## depth), lean (radians from upright at the foot and the tip), length,
## width, twist (radians by the tip) and the ripple's phase.
static func layout(sp: PlantSpecies, look := {}) -> Array[Dictionary]:
	if look.is_empty():
		look = look_of(sp)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(look.seed)
	var span: Vector2i = look.count
	var n := clampi(roundi(lerpf(span.x, span.y, 0.35 + 0.3 * rng.randf())), span.x, span.y)
	var pairs := ceili(n * 0.5)
	var r: float = look.bulb_r
	var neck_r: float = float(PROFILE[PROFILE.size() - 1][0]) * r
	var dz := float(look.width) * THICK_OF_WIDTH * 2.0 * STACK
	var out: Array[Dictionary] = []
	for i in n:
		var pair := i / 2
		var side := 1.0 if i % 2 == 0 else -1.0
		var t := float(pair) / maxf(pairs - 1, 1)
		var lean0 := lerpf(LEAN_INNER.x, LEAN_OUTER.x, t)
		var foot_deg := lean0 + rng.randf_range(-2.0, 2.0)
		var tip_deg := foot_deg + (lerpf(LEAN_INNER.y, LEAN_OUTER.y, t) - lean0) * float(look.arch) + rng.randf_range(-4.0, 4.0)
		var length := float(look.length) * lerpf(YOUNG_LENGTH, 1.0, smoothstep(0.0, 1.0, t)) * rng.randf_range(0.93, 1.05)
		# As broad as its own length over the aspect.
		var width := float(look.width) * length / float(look.length) * rng.randf_range(0.9, 1.1)
		# Drawn every time, so the layout doesn't hang on whether it twists.
		var u := rng.randf()
		var tw := rng.randf_range(TWIST_DEG.x, TWIST_DEG.y)
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		out.append({
			"side": side,
			"pair": pair,
			"foot": Vector3(side * neck_r * 0.35 * t, (NECK_TOP - FOOT_DEPTH) * r, side * (pair + 0.5) * dz),
			"lean": Vector2(deg_to_rad(foot_deg), deg_to_rad(tip_deg)),
			"length": length,
			"width": width,
			"twist": deg_to_rad(tw) * sgn if bool(look.twisted) and u < TWIST_SHARE else 0.0,
			"phase": rng.randi() % 2,
		})
	return out


## A leaf's centerline at `segs` + 1 points, foot to tip (shares of its
## length 0, 1/segs ... 1): [point, tangent] each, in its own plane (z its
## foot's), integrated over FINE steps so every level samples one curve.
static func centerline(leaf: Dictionary, segs: int) -> Array:
	var p: Vector3 = leaf.foot
	var lean: Vector2 = leaf.lean
	var side: float = leaf.side
	var step: float = float(leaf.length) / FINE
	var per := maxi(FINE / maxi(segs, 1), 1)
	var out: Array = [[p, _dir(lean, side, 0.0)]]
	for k in FINE:
		p += _dir(lean, side, (k + 0.5) / FINE) * step
		if (k + 1) % per == 0:
			out.append([p, _dir(lean, side, float(k + 1) / FINE)])
	return out


## The way a leaf runs `s` of the way up it: its lean eased from the foot's
## to the tip's (the arch toward the tip), toward its side.
static func _dir(lean: Vector2, side: float, s: float) -> Vector3:
	var a := lerpf(lean.x, lean.y, pow(s, 1.4))
	return Vector3(side * sin(a), cos(a), 0.0)


## A leaf's segments at a level.
static func segments(b: PlantMeshes._Builder, far: bool) -> int:
	return 3 if far else (8 if b.hero else 6)


static func _bulb(b: PlantMeshes._Builder, look: Dictionary, far: bool, prelit: bool) -> void:
	var r: float = look.bulb_r
	var sides := 6 if far else b.sides(8)
	var prof := PackedVector2Array()
	var cols := PackedColorArray()
	var rows: Array = []
	if far:
		for i in FAR_ROWS:
			rows.append(PROFILE[i])
	else:
		rows = PROFILE
	for k in rows.size():
		var y := float(rows[k][1])
		prof.append(Vector2(float(rows[k][0]) * r, y * r))
		var c: Color = look.bulb
		# Bands of tunic, every other ring darker above the ground.
		if y > 0.0 and k % 2 == 1:
			c = Color(c.r * BAND, c.g * BAND, c.b * BAND)
		# Paler where the tunics tear (the shoulder) and fray (the neck).
		c = c.lerp(look.tunic, NECK_CREAM * smoothstep(0.5, 1.15, y))
		cols.append(_ao(c, lerpf(FOOT_AO, 1.0, smoothstep(-0.1, 0.4, y)), prelit))
	# Round the up axis, its rings turned the way MushroomMesh's are (so the
	# lathe's winding gives outward normals).
	var s1 := Vector3.UP.cross(Vector3.FORWARD).normalized()
	var s2 := Vector3.UP.cross(s1).normalized()
	MushroomMesh.lathe(b, Vector3.ZERO, Vector3.UP, s1, s2, prof, cols, sides)
	# The neck's top, closed (the leaves rise through it).
	var top := prof[prof.size() - 1]
	var cap := _ao((look.bulb as Color).lerp(look.tunic, 0.5), NECK_AO, prelit)
	MushroomMesh.lathe(b, Vector3.ZERO, Vector3.UP, s1, s2, PackedVector2Array([top, Vector2(0.0, top.y - 0.05 * r)]),
		PackedColorArray([cap, cap]), sides)
	if not far:
		_shreds(b, look, prelit)


## Shreds of frayed tunic round the neck's top: thin four-sided slivers
## leaning a little out, brown at the foot and pale at the tip.
static func _shreds(b: PlantMeshes._Builder, look: Dictionary, prelit: bool) -> void:
	var r: float = look.bulb_r
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(look.seed), "shreds"])
	var y0 := (NECK_TOP - 0.16) * r
	var rad := float(PROFILE[PROFILE.size() - 1][0]) * r * 1.02
	var foot_c := _ao((look.bulb as Color).lerp(look.tunic, 0.3), 0.8, prelit)
	var tip_c: Color = look.tunic
	for k in SHREDS:
		var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / SHREDS
		var out := Vector3(cos(a), 0.0, sin(a))
		var across := Vector3(-sin(a), 0.0, cos(a))
		var foot := out * rad + Vector3(0.0, y0, 0.0)
		var tip := foot + (out * rng.randf_range(0.25, 0.55) + Vector3.UP).normalized() * r * rng.randf_range(0.28, 0.42)
		var w := r * 0.07
		var p0 := foot - across * w
		var p1 := foot + across * w
		var p2 := foot - out * w * 0.8
		var mid := (p0 + p1 + p2 + tip) * 0.25
		b.part += 1
		_tri(b, p0, p1, tip, foot_c, foot_c, tip_c, mid)
		_tri(b, p1, p2, tip, foot_c, foot_c, tip_c, mid)
		_tri(b, p2, p0, tip, foot_c, foot_c, tip_c, mid)
		_tri(b, p0, p2, p1, foot_c, foot_c, foot_c, mid)


## One leaf: a closed strap along its centerline, four corners across (its
## two edges and its midrib front and back), the front faces one smooth
## part, the back another, the end its own.
static func _leaf(b: PlantMeshes._Builder, leaf: Dictionary, look: Dictionary, far: bool, prelit: bool) -> void:
	var segs := segments(b, far)
	var line := centerline(leaf, segs)
	var width: float = leaf.width
	var twist: float = leaf.twist
	var tip_w := TIP_BLUNT if bool(look.blunt) else TIP_POINTED
	var leaf_c: Color = look.leaf
	var under_c: Color = look.under
	var vein_c: Color = look.vein
	var rings: Array = [] # [edge -side, midrib front, edge +side, midrib back, centre, out of the blade]
	var front: Array = [] # [edge colour, midrib colour]
	var back: Array = []
	var sway := PackedFloat32Array()
	var hw_end := 0.0
	for c in line.size():
		var s := float(c) / segs
		var pc: Vector3 = line[c][0]
		var tan: Vector3 = line[c][1]
		# Across the leaf in the fan's plane, and out of it; turned about
		# the leaf by its twist so far up.
		var sd := Vector3(tan.y, -tan.x, 0.0)
		var nm := Vector3(0.0, 0.0, 1.0)
		var turn := twist * s
		var sd2 := sd * cos(turn) + nm * sin(turn)
		var nm2 := nm * cos(turn) - sd * sin(turn)
		var hw := width * 0.5 * lerpf(FOOT_WIDTH, 1.0, smoothstep(0.0, 0.2, s))
		if s > TIP_FROM:
			hw *= lerpf(1.0, tip_w, smoothstep(TIP_FROM, 1.0, s))
		var lift := 0.0
		if bool(look.rippled) and not far and c > 0 and c < segs:
			var amp := smoothstep(RIPPLE_FROM, RIPPLE_FROM + 0.25, s)
			var sgn := 1.0 if (c + int(leaf.phase)) % 2 == 0 else -1.0
			lift = RIPPLE * width * amp * sgn
			hw *= 1.0 + RIPPLE_WIDTH * amp * sgn
		hw_end = hw
		var th := width * THICK_OF_WIDTH * lerpf(1.0, 0.6, s)
		rings.append([pc - sd2 * hw + nm2 * lift, pc + nm2 * th, pc + sd2 * hw + nm2 * lift, pc - nm2 * th, pc, nm2])
		var ao := lerpf(LEAF_AO, 1.0, smoothstep(0.0, LEAF_AO_LEN, s))
		front.append([_ao(leaf_c, ao, prelit), _ao(leaf_c.lerp(vein_c, MIDRIB), ao, prelit)])
		back.append([_ao(under_c, ao, prelit), _ao(under_c.lerp(vein_c, MIDRIB_BACK), ao, prelit)])
		sway.append(LEAF_SWAY * s * s)
	# The front (edge, midrib front, edge) and the back (edge, midrib back,
	# edge), each one smooth part, each facing out of its side of the blade
	# (a rippled quad is skewed, but always faces its side).
	for face in 2:
		b.part += 1
		var cs: Array = front if face == 0 else back
		var mid_i := 1 if face == 0 else 3
		var way := 1.0 if face == 0 else -1.0
		for c in segs:
			var ra: Array = rings[c]
			var rz: Array = rings[c + 1]
			var out: Vector3 = ((ra[5] as Vector3) + (rz[5] as Vector3)).normalized() * way
			for e in [0, 2]:
				_quad(b, ra[e], ra[mid_i], rz[mid_i], rz[e], cs[c][0], cs[c][1], cs[c + 1][1], cs[c + 1][0],
					sway[c], sway[c], sway[c + 1], sway[c + 1], out)
	# The end: blunt (a short rounded point) or pointed, its faces out from
	# the last ring's middle (it is never rippled there).
	b.part += 1
	var last: Array = rings[segs]
	var tan_end: Vector3 = line[segs][1]
	var tip: Vector3 = (last[4] as Vector3) + tan_end * hw_end * (0.8 if bool(look.blunt) else 3.0)
	var f_end: Array = front[segs]
	var b_end: Array = back[segs]
	var s_end: float = sway[segs]
	_tri(b, last[0], last[1], tip, f_end[0], f_end[1], f_end[0], last[4], s_end)
	_tri(b, last[1], last[2], tip, f_end[1], f_end[0], f_end[0], last[4], s_end)
	_tri(b, last[2], last[3], tip, b_end[0], b_end[1], b_end[0], last[4], s_end)
	_tri(b, last[3], last[0], tip, b_end[1], b_end[0], b_end[0], last[4], s_end)


## A quad (two triangles) wound so its normal faces `out`.
static func _quad(b: PlantMeshes._Builder, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		c0: Color, c1: Color, c2: Color, c3: Color, s0: float, s1: float, s2: float, s3: float, out: Vector3) -> void:
	_face(b, p0, p1, p2, c0, c1, c2, s0, s1, s2, out)
	_face(b, p0, p2, p3, c0, c2, c3, s0, s2, s3, out)


## A triangle of one sway (0: still) of a closed convex part (a shred, a
## leaf's end), facing out from `centre`, a point inside the part.
static func _tri(b: PlantMeshes._Builder, p0: Vector3, p1: Vector3, p2: Vector3, c0: Color, c1: Color, c2: Color,
		centre: Vector3, sway := 0.0) -> void:
	_face(b, p0, p1, p2, c0, c1, c2, sway, sway, sway, (p0 + p1 + p2) / 3.0 - centre)


## The builder's tri3 for a painted face, wound so its normal faces `out`
## (tri3 turns a painted face's normal outward from its winding:
## (p1 - p0) x (p2 - p0) pointing in).
static func _face(b: PlantMeshes._Builder, p0: Vector3, p1: Vector3, p2: Vector3, c0: Color, c1: Color, c2: Color,
		s0: float, s1: float, s2: float, out: Vector3) -> void:
	if (p1 - p0).cross(p2 - p0).dot(out) > 0.0:
		b.tri3(p0, p2, p1, c0, c2, c1, s0, s2, s1)
	else:
		b.tri3(p0, p1, p2, c0, c1, c2, s0, s1, s2)


## A bark colour as the plant shader draws bark by day (its pull toward the
## warm brown, BARK_BROWN), painted in: the bulb's tunics.
static func painted_bark(c: Color) -> Color:
	var luma := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var k := lerpf(1.0, luma / PAL_REF_LUMA, 0.5)
	return c.lerp(Color(BARK_BROWN.r * k, BARK_BROWN.g * k, BARK_BROWN.b * k), BARK_PULL)


## A colour from the entry ("#7aa298"), else `fallback`.
static func _col(v, fallback: Color) -> Color:
	return Color.from_string(str(v), fallback) if v is String and str(v).begins_with("#") else fallback


## Metres from a [low, high] size_cm (its middle), or -1.
static func _mean_cm(v) -> float:
	if v is Array and (v as Array).size() == 2:
		return (float(v[0]) + float(v[1])) * 0.005
	return -1.0


## `c` shaded by occlusion `ao` (1 open): toward navy (olive on a green)
## when pre-lit (§ES.2), else plainly darker.
static func _ao(c: Color, ao: float, prelit: bool) -> Color:
	if ao >= 0.999:
		return c
	return Prelit.ao_tint(c, ao) if prelit else Color(c.r * ao, c.g * ao, c.b * ao, c.a)

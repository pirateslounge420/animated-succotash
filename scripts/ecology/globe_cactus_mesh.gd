class_name GlobeCactusMesh
## The GLOBE_CACTUS plant shape (design §FM.13 item 2, queue 76): a low
## ribbed button sunk to its rim in the ground, a tight clump of them to a
## plant, drawn from the entry's own appearance block
## (PlantSpecies.appearance), so peyote stops being drawn as the CACTUS
## column (CACTUS itself is unchanged). PlantMeshes._build calls build()
## for every GLOBE_CACTUS species.
##
##   * Each head is a flattened dome as wide as appearance.stem.diameter_cm
##     and as tall as height_m (the oldest head, both at the middle of their
##     ranges; the pups smaller), sunk to its rim: the rim, its widest, on
##     the ground line, ABOVE of its height over it as the crown, the rest
##     (most of it) a buried body under it.
##   * Its ribs from stem.ribs: the oldest head the middle of the range, the
##     pups fewer, in Fibonacci steps where the range spans them (the
##     entry's growth note: peyote adds ribs 5, 8, 13 as it ages), the
##     furrows between them stem.rib_depth of the radius deep at the rim.
##     Cross-furrows cut each rib into rounded bumps, the outermost halved
##     by the ground.
##   * A tuft of wool (stem.areole_colour) on every bump above the ground
##     and a woolly boss at the centre; spines (stem.spine_cm long,
##     spines_per_areole of them, spine_colour) only where spine_cm is more
##     than [0, 0] (peyote has none).
##   * stem.colour, easing toward stem.secondary on the bumps' crests;
##     occlusion baked toward navy (Prelit.ao_tint, §ES.2), never grey, in
##     the furrows, at the ground line and down the buried body
##     (PlantMeshes' own darker foot is left off these faces, as off a
##     mushroom's).
##   * A small bell (appearance.flower.colour, its secondary at the rim and
##     in the throat; fruiting.flower_size_cm across) in the woolly crown of
##     the oldest head, only where the entry blooms (it names a flower
##     colour).
##   * Several heads in a tight clump (CLUMP), pressed together, the pups
##     leaning out a little; one head where appearance.trunk.form says
##     "solitary".
##
## Painted (§ES): diffuse only, no textures, no leaf tiles (leaf type none):
## every face is painted flesh (UV2.x -1, MushroomMesh's material: the
## foliage shader's bark rules in its own colour, without the bark tile,
## the bark-brown pull or moss), sway 0 (it never bows in the wind). Unit
## frame: the oldest head's whole height (crown and buried body) is 1, so
## drawn at any height in height_m it is that tall, its rim on the ground
## line (y 0) and ABOVE of it over the ground.
##
## The same heads, ribs and bumps at every level (from the species, never
## the level), so nothing pops: the hero level rounds each rib with three
## corners, the near level two. The far level (PlantMeshes.own_far: never
## the one-quad picture, which would stand a flat button on its edge) keeps
## each flat ribbed button and its woolly boss and drops the bumps, the
## tufts, the spines and the flower (PLANT_SCHEMA §5: LOD strips detail,
## never the structure).

## UV2.x of painted flesh (foliage.gdshader; MushroomMesh.FLESH).
const FLESH := -1.0
## The share of a head's height over the ground line: its crown, above the
## rim. The rest, most of it, is the buried body.
const ABOVE := 0.3
## The crown's profile, rim to centre, is a superellipse of this exponent in
## its own radius and height (1 a half-ellipse; under 1 a flatter top on a
## rounder shoulder); the buried body's, rim to foot.
const CROWN_E := 0.72
const BODY_E := 1.0
## The woolly centre sinks this share of the crown's height, over about
## this share of the radius.
const DIP := 0.15
const DIP_R := 0.22
## A cross-furrow's depth, as a share of a rib furrow's.
const CROSS := 0.6
## The ribs fade out this far (radians of the polar angle) down the buried
## body, and its one ring between the rim and the foot.
const BODY_FADE := 0.7
const BODY_RING := 0.5
## The woolly boss: its radius (share of the head's; the bumps start at its
## edge, this share of the crown's arc out from the centre) and its height
## (share of its own radius).
const BOSS_R := 0.2
const BOSS_H := 0.5
## A wool tuft: its radius as a share of its bump's half-width, its height
## as a share of its radius.
const TUFT_R := 0.42
const TUFT_H := 0.55
## The heads, oldest first: [radius and height (shares of the oldest's),
## where in stem.ribs its rib count sits (0 the fewest, 1 the most), bumps
## along each rib (the outermost halved by the ground)].
const CLUMP := [[1.0, 0.5, 4], [0.74, 0.3, 3], [0.6, 0.12, 2], [0.46, 0.0, 2]]
## How tight the clump is: a pup's centre this share of the two radii from
## the oldest head's (under 1: pressed together).
const TIGHT := 0.9
## The secondary colour's share on a bump's crest; occlusion in a rib's
## furrow, at the ground line, and at the foot of the buried body.
const CREST_SHARE := 0.6
const FURROW_AO := 0.62
const RIM_AO := 0.72
const BODY_AO := 0.5
## The flower: its height over its rim's radius, how much of it sinks into
## the wool, and how far its rim eases toward the flower's secondary.
const FLOWER_H := 0.85
const FLOWER_SINK := 0.3
const FLOWER_RIM := 0.45
## At most this many spines to an areole (the rest left off), and their
## thinnest (unit frame).
const MAX_SPINES := 6
const SPINE_R := 0.004
## Rib counts take these steps where stem.ribs spans one.
const FIB := [3, 5, 8, 13, 21, 34]
## Steps the crown's arc is measured in.
const ARC_STEPS := 48


## Build `sp`'s heads into `b` (PlantMeshes._build; `far`: the far level).
static func build(b: PlantMeshes._Builder, sp: PlantSpecies, far: bool) -> void:
	var look := look_of(sp)
	var mat_was := b.mat
	b.mat = FLESH
	var prelit := Prelit.on()
	var heads := layout(sp, look)
	for k in heads.size():
		head(b, heads[k], look, far, b.hero, prelit, k == 0 and bool(look.blooms))
	b.mat = mat_was


## What the entry says about its heads, read once: the oldest head's radius
## (unit frame), the rib range and depth, the spines, whether it clumps and
## blooms, the flower's size, and the colours.
static func look_of(sp: PlantSpecies) -> Dictionary:
	var app: Dictionary = sp.appearance
	var stem: Dictionary = app.get("stem", {}) if app.get("stem") is Dictionary else {}
	var fl: Dictionary = app.get("flower", {}) if app.get("flower") is Dictionary else {}
	var trunk: Dictionary = app.get("trunk", {}) if app.get("trunk") is Dictionary else {}
	var h_cm := maxf((sp.height_m.x + sp.height_m.y) * 50.0, 0.1)
	var dia := _mid(stem.get("diameter_cm"), h_cm * 1.8)
	var ribs := _pair(stem.get("ribs"), Vector2(5, 13))
	var lo := clampi(roundi(minf(ribs.x, ribs.y)), 3, 34)
	var hi := clampi(roundi(maxf(ribs.x, ribs.y)), lo, 34)
	var spine_cm := _pair(stem.get("spine_cm"), Vector2.ZERO)
	var per := _pair(stem.get("spines_per_areole"), Vector2.ZERO)
	var body := _col(stem.get("colour"), sp.color)
	var wool := _col(stem.get("areole_colour"), Color(0.93, 0.9, 0.81))
	var flower_v = fl.get("colour", sp.fruiting.get("flower_colour", ""))
	var fcol := _col(flower_v, sp.accent)
	return {
		"radius": clampf(dia * 0.5 / h_cm, 0.3, 4.0),
		"ribs": Vector2i(lo, hi),
		"rib_depth": clampf(float(stem.get("rib_depth", 0.25)), 0.0, 0.6),
		"spines": mini(roundi((per.x + per.y) * 0.5), MAX_SPINES) if maxf(spine_cm.x, spine_cm.y) > 0.0 else 0,
		"spine_len": (spine_cm.x + spine_cm.y) * 0.5 / h_cm,
		"clumping": str(trunk.get("form", "clumping")) != "solitary",
		"body": body,
		"secondary": _col(stem.get("secondary"), body.lightened(0.2)),
		"wool": wool,
		"spine": _col(stem.get("spine_colour"), wool),
		"blooms": flower_v is String and str(flower_v).begins_with("#"),
		"flower": fcol,
		"flower_2": _col(fl.get("secondary"), fcol.lightened(0.5)),
		"flower_r": clampf(float(sp.fruiting.get("flower_size_cm", 2.0)) * 0.5 / h_cm, 0.02, 1.0),
	}


## The heads, the same at every level (from the species, never the level),
## oldest first, unit frame: foot (the rim's centre, on the ground line),
## axis (leaning), radius, whole height, ribs, bumps, turn (where its first
## rib stands) and a seed. The oldest stands in the middle; the pups stand
## round it pressed against it (TIGHT), clear of each other, leaning out.
static func layout(sp: PlantSpecies, look := {}) -> Array[Dictionary]:
	if look.is_empty():
		look = look_of(sp)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sp.name, sp.genus, sp.species, "globe_cactus"])
	var r0: float = look.radius
	var specs: Array = CLUMP if bool(look.clumping) else [CLUMP[0]]
	var a0 := rng.randf() * TAU
	var out: Array[Dictionary] = []
	for k in specs.size():
		var spec: Array = specs[k]
		var share := float(spec[0])
		var rk := r0 * share
		var foot := Vector3.ZERO
		var lean_dir := Vector3.RIGHT
		var lean := 0.0
		if k == 0:
			var a := rng.randf() * TAU
			lean_dir = Vector3(cos(a), 0.0, sin(a))
			lean = deg_to_rad(rng.randf_range(0.0, 3.0))
		else:
			var a := a0 + (k - 1) * TAU * 0.37 + rng.randf_range(-0.3, 0.3)
			var dist := (r0 + rk) * TIGHT
			for attempt in 24:
				var at := Vector3(cos(a), 0.0, sin(a)) * dist
				var clear := true
				for o in out:
					var of: Vector3 = o.foot
					if Vector2(at.x - of.x, at.z - of.z).length() < (rk + float(o.radius)) * TIGHT:
						clear = false
				if clear:
					break
				a += TAU / 24.0
			lean_dir = Vector3(cos(a), 0.0, sin(a))
			foot = lean_dir * dist
			lean = deg_to_rad(rng.randf_range(2.0, 5.0))
		out.append({
			"foot": foot,
			"axis": (Vector3.UP * cos(lean) + lean_dir * sin(lean)).normalized(),
			"radius": rk,
			"height": share,
			"ribs": rib_count(look.ribs, float(spec[1])),
			"bumps": int(spec[2]),
			"turn": rng.randf() * TAU,
			"seed": rng.randi(),
		})
	return out


## The rib count `t` of the way through `ribs` (fewest, most), on a
## Fibonacci step where the range spans one (the nearer, the larger on a
## tie), else rounded.
static func rib_count(ribs: Vector2i, t: float) -> int:
	var want := lerpf(float(ribs.x), float(ribs.y), t)
	var best := -1
	for f in FIB:
		if f >= ribs.x and f <= ribs.y and (best < 0 or absf(f - want) <= absf(best - want)):
			best = f
	return best if best > 0 else clampi(roundi(want), 3, 34)


## The crown's arc from its centre to its rim, in its radius, for a crown
## `ratio` as tall as its radius (measured as drawn, squashed).
static func crown_arc(ratio: float) -> float:
	var total := 0.0
	var prev := Vector2(0.0, ratio)
	for i in range(1, ARC_STEPS + 1):
		var t := PI * 0.5 * i / ARC_STEPS
		var p := Vector2(pow(sin(t), CROWN_E), ratio * pow(cos(t), CROWN_E))
		total += p.distance_to(prev)
		prev = p
	return total


## The polar angles (0 the crown's centre, PI/2 its rim) where the crown's
## arc out from its centre reaches each share in `shares` (crown_arc).
static func crown_angles(ratio: float, shares: PackedFloat32Array) -> PackedFloat32Array:
	var th := PackedFloat32Array([0.0])
	var arc := PackedFloat32Array([0.0])
	var prev := Vector2(0.0, ratio)
	for i in range(1, ARC_STEPS + 1):
		var t := PI * 0.5 * i / ARC_STEPS
		var p := Vector2(pow(sin(t), CROWN_E), ratio * pow(cos(t), CROWN_E))
		arc.append(arc[arc.size() - 1] + p.distance_to(prev))
		th.append(t)
		prev = p
	var total := arc[arc.size() - 1]
	var out := PackedFloat32Array()
	for s in shares:
		var want := clampf(s, 0.0, 1.0) * total
		var j := 1
		while j < arc.size() - 1 and arc[j] < want:
			j += 1
		out.append(lerpf(th[j - 1], th[j], clampf((want - arc[j - 1]) / maxf(arc[j] - arc[j - 1], 1e-9), 0.0, 1.0)))
	return out


## The smooth head's profile in its own unit radius and height (r, y) at
## polar angle `th`: the crown's superellipse above the rim, the buried
## body's under it.
static func _base(th: float) -> Vector2:
	if th <= PI * 0.5:
		return Vector2(pow(maxf(sin(th), 0.0), CROWN_E), pow(maxf(cos(th), 0.0), CROWN_E))
	return Vector2(pow(maxf(sin(th), 0.0), BODY_E), -pow(maxf(-cos(th), 0.0), BODY_E))


## The smooth profile's outward normal there (in its unit radius and
## height).
static func _base_normal(th: float) -> Vector2:
	if th < 1e-3:
		return Vector2(0.0, 1.0)
	if th > PI - 1e-3:
		return Vector2(0.0, -1.0)
	var t := _base(minf(th + 1e-3, PI)) - _base(maxf(th - 1e-3, 0.0))
	return Vector2(-t.y, t.x).normalized()


## A point of head `h`'s surface in its own frame: Vector4(r out from its
## axis, y up it from the rim, how deep in a furrow 0-1, how far up a
## bump's crest 0-1). `th`: the polar angle (0 the crown's centre, PI/2 the
## rim, PI the buried body's foot); `s`: the share of the crown's arc out
## from its centre (the crown's only); `u`: across a rib (0 its crest, ±0.5
## the furrows beside it); `bumps`: the cross-furrows cut. The ribs and
## bumps are cut into the smooth head along its normal in its own unit
## radius and height, then drawn to its radius and its crown's (or body's)
## height: a furrow as deep as stem.rib_depth of the radius at the rim and
## as much of the crown's height on top.
static func surface(h: Dictionary, look: Dictionary, th: float, s: float, u: float, bumps: bool) -> Vector4:
	var crown := th <= PI * 0.5
	var c_u := pow(cos(PI * u), 2.0)
	var c_v := 1.0
	var fade := 1.0
	if crown:
		fade = smoothstep(0.0, BOSS_R * 1.1, s)
		if bumps and s > BOSS_R:
			var q := (s - BOSS_R) / (1.0 - BOSS_R) * (float(h.bumps) - 0.5)
			c_v = pow(cos(PI * (q - floorf(q) - 0.5)), 2.0)
	else:
		fade = 1.0 - smoothstep(PI * 0.5, PI * 0.5 + BODY_FADE, th)
	var d := ((1.0 - c_u) + CROSS * c_u * (1.0 - c_v)) * fade
	var p := _base(th) - _base_normal(th) * float(look.rib_depth) * d
	var rr: float = h.radius
	var hc: float = float(h.height) * ABOVE
	var hb: float = float(h.height) * (1.0 - ABOVE)
	var r := maxf(p.x, 0.0) * rr
	var y := p.y * (hc if crown else hb)
	if crown:
		y -= DIP * hc * exp(-pow(r / (DIP_R * rr), 2.0))
	return Vector4(r, y, d, c_u * c_v)


## Head `h` into `b`: its surface (buried foot, rim, crown), its woolly
## boss, and at the near and hero levels a wool tuft (and its spines) on
## every bump above the ground, and the flower where `flower`.
static func head(b: PlantMeshes._Builder, h: Dictionary, look: Dictionary, far: bool, hero: bool, prelit: bool, flower: bool) -> void:
	var n: int = h.ribs
	var m: int = h.bumps
	var per := 3 if hero and not far else 2
	var sides := n * per
	var ax: Vector3 = h.axis
	var s1 := ax.cross(Vector3.FORWARD if absf(ax.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var s2 := ax.cross(s1).normalized()
	var foot: Vector3 = h.foot
	var turn: float = h.turn
	var rr: float = h.radius
	var hc: float = float(h.height) * ABOVE
	var hb: float = float(h.height) * (1.0 - ABOVE)
	# The crown's rings out from the boss to the rim (arc shares), rim first:
	# a crest and a furrow to a bump, the outermost crest on the rim.
	var shares := PackedFloat32Array([1.0, 0.5])
	if not far:
		shares = PackedFloat32Array()
		var mm := float(m) - 0.5
		for j in range(m - 1, -1, -1):
			shares.append(BOSS_R + (1.0 - BOSS_R) * (j + 0.5) / mm)
			shares.append(BOSS_R + (1.0 - BOSS_R) * j / mm)
	var ths := crown_angles(hc / rr, shares)
	# Rings bottom to top: the buried foot (a point), a ring under the rim
	# (not far), the rim and the crown's rings, the crown's centre (a point).
	var at_th := PackedFloat32Array([PI])
	var at_s := PackedFloat32Array([1.0])
	if not far:
		at_th.append(PI * 0.5 + BODY_RING)
		at_s.append(1.0)
	for i in shares.size():
		at_th.append(ths[i])
		at_s.append(shares[i])
	at_th.append(0.0)
	at_s.append(0.0)
	var rings: Array = []
	var cols: Array = []
	var points: Array = []
	for i in at_th.size():
		var point := i == 0 or i == at_th.size() - 1
		var ring := PackedVector3Array()
		var ring_c := PackedColorArray()
		for k in sides:
			var u := float(k % per) / per
			if u > 0.5:
				u -= 1.0
			var q := surface(h, look, at_th[i], at_s[i], 0.0 if point else u, not far)
			var phi := turn + TAU * k / sides
			ring.append(foot + ax * q.y + (s1 * cos(phi) + s2 * sin(phi)) * q.x)
			ring_c.append(_paint(look, q, at_th[i] <= PI * 0.5, hc, hb, prelit))
		rings.append(ring)
		cols.append(ring_c)
		points.append(point)
	grid(b, rings, cols, points)
	# The woolly boss in the crown's centre.
	var top: Vector4 = surface(h, look, 0.0, 0.0, 0.0, false)
	var rb := BOSS_R * rr * 1.05
	var hbs := BOSS_H * rb
	var wool: Color = look.wool
	var o_boss := foot + ax * top.y
	if far:
		MushroomMesh.lathe(b, o_boss, ax, s1, s2, PackedVector2Array([Vector2(rb, -0.35 * hbs), Vector2(0.0, hbs)]),
			PackedColorArray([_ao(wool, 0.82, prelit), wool]), 5, turn)
		return
	MushroomMesh.lathe(b, o_boss, ax, s1, s2, PackedVector2Array([Vector2(rb, -0.35 * hbs), Vector2(0.72 * rb, 0.55 * hbs), Vector2(0.0, hbs)]),
		PackedColorArray([_ao(wool, 0.82, prelit), _ao(wool, 0.95, prelit), wool]), 9 if hero else 6, turn)
	# A tuft on every bump's crest above the ground (the rim's crests are
	# halved by it), its spines round it where the entry has any.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h.seed)
	var bump_len := crown_arc(hc / rr) * rr * (1.0 - BOSS_R) / (float(m) - 0.5)
	for j in m - 1:
		var s := BOSS_R + (1.0 - BOSS_R) * (j + 0.5) / (float(m) - 0.5)
		var th := crown_angles(hc / rr, PackedFloat32Array([s]))[0]
		var q := surface(h, look, th, s, 0.0, true)
		var bn := _base_normal(th)
		var nl := Vector2(bn.x / rr, bn.y / hc).normalized()
		var tr := TUFT_R * 0.5 * minf(TAU * q.x / n, bump_len)
		for i in n:
			var phi := turn + TAU * i / n
			var out := s1 * cos(phi) + s2 * sin(phi)
			var p := foot + ax * q.y + out * q.x
			var nrm := (ax * nl.y + out * nl.x).normalized()
			tuft(b, p, nrm, tr, wool, hero, prelit)
			if int(look.spines) > 0:
				_spines(b, p + nrm * TUFT_H * tr * 0.5, nrm, int(look.spines), float(look.spine_len), look.spine, rng)
	if flower:
		_flower(b, foot + ax * (top.y + hbs), ax, s1, s2, look, hero, prelit, turn)


## A wool tuft: a low cone of `col` standing on the surface at `p` along
## `nrm`, `r` across at its foot (sunk a little), 3 sides (5 at the hero
## level).
static func tuft(b: PlantMeshes._Builder, p: Vector3, nrm: Vector3, r: float, col: Color, hero: bool, prelit: bool) -> void:
	var t1 := nrm.cross(Vector3.FORWARD if absf(nrm.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := nrm.cross(t1).normalized()
	MushroomMesh.lathe(b, p, nrm, t1, t2, PackedVector2Array([Vector2(r, -0.3 * r), Vector2(0.0, TUFT_H * r)]),
		PackedColorArray([_ao(col, 0.88, prelit), col]), 5 if hero else 3)


## `count` spines `length` long from an areole at `p`, fanned 40-70° out
## from its normal `nrm`, thin three-sided cones of `col`.
static func _spines(b: PlantMeshes._Builder, p: Vector3, nrm: Vector3, count: int, length: float, col: Color, rng: RandomNumberGenerator) -> void:
	var t1 := nrm.cross(Vector3.FORWARD if absf(nrm.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := nrm.cross(t1).normalized()
	var a0 := rng.randf() * TAU
	for k in count:
		var a := a0 + TAU * k / count + rng.randf_range(-0.3, 0.3)
		var tilt := deg_to_rad(rng.randf_range(40.0, 70.0))
		var dir := (nrm * cos(tilt) + (t1 * cos(a) + t2 * sin(a)) * sin(tilt)).normalized()
		var d1 := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var d2 := dir.cross(d1).normalized()
		MushroomMesh.lathe(b, p, dir, d1, d2, PackedVector2Array([Vector2(maxf(SPINE_R, length * 0.03), 0.0), Vector2(0.0, length)]),
			PackedColorArray([col, col]), 3)


## The flower: a small open bell standing in the boss whose top is at
## `top`, along `ax`: flower colour outside easing toward the secondary at
## its rim, the secondary in its throat, deep in shade at the bottom.
static func _flower(b: PlantMeshes._Builder, top: Vector3, ax: Vector3, s1: Vector3, s2: Vector3, look: Dictionary, hero: bool, prelit: bool, turn: float) -> void:
	var fr: float = look.flower_r
	var fh := FLOWER_H * fr
	var o := top - ax * FLOWER_SINK * fh
	var c1: Color = look.flower
	var c2: Color = look.flower_2
	var sides := 9 if hero else 6
	MushroomMesh.lathe(b, o, ax, s1, s2, PackedVector2Array([Vector2(0.3 * fr, 0.0), Vector2(0.62 * fr, 0.5 * fh), Vector2(fr, fh)]),
		PackedColorArray([_ao(c1, 0.8, prelit), c1, c1.lerp(c2, FLOWER_RIM)]), sides, turn)
	MushroomMesh.lathe(b, o, ax, s1, s2, PackedVector2Array([Vector2(0.94 * fr, 0.97 * fh), Vector2(0.45 * fr, 0.5 * fh), Vector2(0.0, 0.22 * fh)]),
		PackedColorArray([c2, _ao(c2, 0.8, prelit), _ao(c2, 0.6, prelit)]), sides, turn)


## A closed surface through rings of corners (bottom to top, each going
## round as MushroomMesh.lathe's do, so the builder's winding gives outward
## normals), a colour per corner; a ring marked in `points` is one point
## (all its corners at it) and closes the surface there. One smoothing part,
## sway 0.
static func grid(b: PlantMeshes._Builder, rings: Array, cols: Array, points: Array) -> void:
	b.part += 1
	for i in rings.size() - 1:
		var lo: PackedVector3Array = rings[i]
		var hi: PackedVector3Array = rings[i + 1]
		var cl: PackedColorArray = cols[i]
		var ch: PackedColorArray = cols[i + 1]
		var sides := lo.size()
		for k in sides:
			var k1 := (k + 1) % sides
			if not bool(points[i]):
				b.tri3(lo[k], hi[k1], lo[k1], cl[k], ch[k1], cl[k1], 0.0, 0.0, 0.0)
			if not bool(points[i + 1]):
				b.tri3(lo[k], hi[k], hi[k1], cl[k], ch[k], ch[k1], 0.0, 0.0, 0.0)


## A head's colour at surface point `q` (surface()): stem colour, easing
## toward the secondary up a bump's crest; shaded toward navy in the
## furrows, near the ground line, and down the buried body.
static func _paint(look: Dictionary, q: Vector4, crown: bool, hc: float, hb: float, prelit: bool) -> Color:
	var c: Color = (look.body as Color).lerp(look.secondary, CREST_SHARE * q.w)
	var ao := lerpf(FURROW_AO, 1.0, 1.0 - q.z)
	if crown:
		ao *= lerpf(RIM_AO, 1.0, smoothstep(0.0, 0.5 * hc, q.y))
	else:
		ao *= lerpf(RIM_AO, BODY_AO, clampf(-q.y / maxf(hb, 1e-4), 0.0, 1.0))
	return _ao(c, ao, prelit)


static func _pair(v, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return fallback


static func _mid(v, fallback: float) -> float:
	var p := _pair(v, Vector2(fallback, fallback))
	return (p.x + p.y) * 0.5


## A colour from the entry ("#5a8c86"), else `fallback`.
static func _col(v, fallback: Color) -> Color:
	return Color.from_string(str(v), fallback) if v is String and str(v).begins_with("#") else fallback


## `c` shaded by occlusion `ao` (1 open): toward navy when pre-lit (§ES.2),
## else plainly darker.
static func _ao(c: Color, ao: float, prelit: bool) -> Color:
	if ao >= 0.999:
		return c
	return Prelit.ao_tint(c, ao) if prelit else Color(c.r * ao, c.g * ao, c.b * ao, c.a)

class_name FittedStone
## Fitted-stone walls (Mike, 6 Oct, LOCKED: the dungeon's walls; data/
## dungeon/masonry.json): a wall's seen face cut into irregular polygonal
## stones, Incan ashlar, Sacsayhuamán. The face's plane is partitioned into
## Voronoi cells round seed points jittered off a running-bond grid
## (presets: cell_m, aspect, jitter), each cell clipped to its neighbours'
## bisectors and to the wall, so neighbours share their edges exactly; each
## cell is one stone of real geometry (no normal maps, LOOK_REFERENCE):
##
##   its foot     the cell inset by half a joint, a little behind the
##                wall's face, down in the joint
##   its bevel    a rounded edge bevel_m wide rising to the face
##   its face     proud_m in front of the wall's face, pillowed: a middle
##                ring higher, the middle highest (pillow_m), the normals
##                bending out from the middle so the light rounds it
##
## Behind the stones, the joint's back (joint_depth_m behind the face):
## dark, in the joints' shadow. A minority are settled (settle_share: out
## or in, a slight turn, now and then sunk a little). The overgrowth by the
## place's damp (humidity()): moss in the joints and on the shaded lower
## wall, vines from the wall's top and from cracks; where it's dry, drifted
## dust in the corners and along the foot. Everything goes into a
## RuinBuilder's arrays (TombBuild), drawn with the ruin material's fitted
## stone (kind 6: the stone's grain without the painted cracks; the
## joints are real now).

static var M: Dictionary = Tuning.table("masonry")
## The ruin material's kinds (shaders/ruin.gdshader, UV.x).
const FITTED_M := 6
const DUST_M := 5


static func preset() -> Dictionary:
	var ps: Dictionary = M.get("presets", {})
	# "fitted-small" (Mike's message) and "fitted_small" (§EU.5) are one.
	var name := str(M.get("preset", "megalithic")).replace("-", "_")
	return ps.get(name, ps.get("megalithic", {}))


static func overgrowth() -> Dictionary:
	return M.get("overgrowth", {})


## 0-1: how damp the tomb is at `pos` (scene): the theme's base, wandering
## smoothly from place to place, wetter each flight down (masonry.json
## humidity).
static func humidity(theme: String, seed_value: int, pos: Vector3) -> float:
	var h: Dictionary = M.get("humidity", {})
	var by: Dictionary = h.get("by_theme", {})
	var base := float(by.get(theme, by.get("default", 0.5)))
	var sc := maxf(float(h.get("scale_m", 16.0)), 1.0)
	var n := _noise(Vector2(pos.x, pos.z) / sc, seed_value) * 2.0 - 1.0
	var flights := maxf(-pos.y, 0.0) / maxf(float((Tuning.table("crawler").get("kit", {}) as Dictionary).get("stair_drop_m", 2.4)), 0.1)
	return clampf(base + float(h.get("vary", 0.35)) * n + float(h.get("per_flight", 0.06)) * flights, 0.0, 1.0)


## Smooth value noise 0-1 on a unit lattice.
static func _noise(p: Vector2, s: int) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _hash(i, s)
	var b := _hash(i + Vector2(1, 0), s)
	var c := _hash(i + Vector2(0, 1), s)
	var d := _hash(i + Vector2(1, 1), s)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _hash(p: Vector2, s: int) -> float:
	return float(posmod(hash([int(p.x), int(p.y), s]), 100000)) / 100000.0


## Moss share 0-1 for damp `hum` (overgrowth.wet_from..wet_full).
static func moss_of(hum: float) -> float:
	var o := overgrowth()
	return float(o.get("density", 1.0)) * smoothstep(float(o.get("wet_from", 0.45)), float(o.get("wet_full", 0.85)), hum)


## The Voronoi cells of a `length` x `height` wall face (u along, v up from
## 0): [[site, polygon (PackedVector2Array, counter-clockwise)]...].
static func cells(length: float, height: float, rng: RandomNumberGenerator) -> Array:
	var p := preset()
	var ch := maxf(float(p.get("cell_m", 0.9)), 0.1)
	var cw := ch * maxf(float(p.get("aspect", 1.4)), 0.3)
	var jit := clampf(float(p.get("jitter", 0.8)), 0.0, 1.0)
	var nx := maxi(1, int(round(length / cw)))
	var ny := maxi(1, int(round(height / ch)))
	var w := length / nx
	var h := height / ny
	var sites: Array = []
	for j in ny:
		# A running bond, loosened by the jitter.
		var shift := (0.25 if j % 2 == 1 else -0.25) * (1.0 - jit)
		for i in nx:
			var x := clampf((i + 0.5 + shift + rng.randf_range(-0.5, 0.5) * jit) * w, 0.02, length - 0.02)
			var y := clampf((j + 0.5 + rng.randf_range(-0.5, 0.5) * jit * 0.8) * h, 0.02, height - 0.02)
			sites.append([Vector2(x, y), i, j])
	var out: Array = []
	for si in sites:
		var s: Vector2 = si[0]
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, height), Vector2(0, height)])
		for sk in sites:
			if sk == si or absi(int(sk[1]) - int(si[1])) > 2 or absi(int(sk[2]) - int(si[2])) > 2:
				continue
			var o: Vector2 = sk[0]
			poly = _clip(poly, (s + o) * 0.5, o - s)
			if poly.size() < 3:
				break
		if poly.size() >= 3:
			out.append([s, poly])
	return out


## Convex polygon `poly` cut to the side of the line through `m` away from
## `toward` (Sutherland-Hodgman, one plane).
static func _clip(poly: PackedVector2Array, m: Vector2, toward: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := (a - m).dot(toward)
		var db := (b - m).dot(toward)
		if da <= 0.0:
			out.append(a)
		if (da <= 0.0) != (db <= 0.0):
			out.append(a + (b - a) * (da / (da - db)))
	return out


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var area := 0.0
	var c := Vector2.ZERO
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var cr := a.x * b.y - b.x * a.y
		area += cr
		c += (a + b) * cr
	if absf(area) < 1e-6:
		c = Vector2.ZERO
		for q in poly:
			c += q
		return c / poly.size()
	return c / (3.0 * area)


static func _area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5


## The nearest edge from `c` inside `poly`.
static func _inradius(poly: PackedVector2Array, c: Vector2) -> float:
	var r := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := (b - a)
		if e.length() < 1e-5:
			continue
		r = minf(r, absf((c - a).cross(e.normalized())))
	return r


## Dress one wall face with fitted stones. The face's plane: `o` (scene, at
## y 0) + `u` * along + up * y + `n` * out (n: out of the wall, into the
## room); `length` along, stones from y `y0` to `y1`, the floor at
## `floor_y`; `hum` the damp there. Returns the stones laid.
static func face(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, floor_y: float, hum: float, rng: RandomNumberGenerator) -> int:
	if length < 0.3 or y1 - y0 < 0.3:
		return 0
	var p := preset()
	var og := overgrowth()
	var joint := float(p.get("joint_m", 0.012))
	var jd := float(p.get("joint_depth_m", 0.06))
	var bevel := float(p.get("bevel_m", 0.07))
	var proud := float(p.get("proud_m", 0.04))
	var pillow := float(p.get("pillow_m", 0.05))
	var tint := Color(str(p.get("tint", "#ffffff")))
	var moss_k := moss_of(hum)
	var jmoss := moss_k * float(og.get("joint_moss", 0.9))
	var low_m := maxf(float(og.get("low_wall_m", 1.3)), 0.1)
	var low_moss := float(og.get("low_moss", 0.65)) * moss_k
	var was_mat := b.mat
	b.mat = FITTED_M
	var at := func(uv: Vector2, w: float) -> Vector3:
		return o + u * uv.x + Vector3.UP * (y0 + uv.y) + n * w
	# The joints' back: one dark sheet behind the stones.
	var back: Color = Prelit.ao_tint((b.palette[1] as Color).darkened(0.25), 0.3)
	back.a = jmoss
	var inside := o + Vector3.UP * (y0 + y1) * 0.5 - n * 2.0
	var q0: Vector3 = at.call(Vector2(0, 0), -jd)
	var q1: Vector3 = at.call(Vector2(length, 0), -jd)
	var q2: Vector3 = at.call(Vector2(length, y1 - y0), -jd)
	var q3: Vector3 = at.call(Vector2(0, y1 - y0), -jd)
	b._tri_n(q0, q1, q2, n, n, n, back, back, back, inside + u * length * 0.5)
	b._tri_n(q0, q2, q3, n, n, n, back, back, back, inside + u * length * 0.5)
	var laid := 0
	var settle := float(p.get("settle_share", 0.15))
	var rot_max := deg_to_rad(float(p.get("settle_rot_deg", 2.5)))
	for cell in cells(length, y1 - y0, rng):
		var poly: PackedVector2Array = cell[1]
		if _area(poly) < 0.004:
			continue
		var c := _centroid(poly)
		var r_in := _inradius(poly, c)
		if r_in < joint * 0.5 + 0.01:
			continue
		# Settled: out or in, a slight turn, now and then sunk.
		var off := 0.0
		var rot := 0.0
		if rng.randf() < settle:
			off = rng.randf_range(-1.0, 1.0) * float(p.get("settle_out_m", 0.03))
			rot = rng.randf_range(-1.0, 1.0) * rot_max
		var sink := float(p.get("sink_m", 0.03)) if rng.randf() < float(p.get("sink_share", 0.05)) else 0.0
		var cs := c - Vector2(0, sink)
		var s0 := maxf(0.2, 1.0 - joint * 0.5 / r_in)
		var s1 := maxf(0.12, 1.0 - (joint * 0.5 + bevel) / r_in)
		var col: Color = (b.palette[rng.randi() % b.palette.size()] as Color).darkened(rng.randf_range(0.0, 0.14))
		col = Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
		var patch := rng.randf_range(0.5, 1.3)
		var foot_col: Color = Prelit.ao_tint(col, 0.55)
		foot_col.a = jmoss * 0.85
		var nv := poly.size()
		var r0: Array[Vector3] = []
		var r1: Array[Vector3] = []
		var rm: Array[Vector3] = []
		var n0: Array[Vector3] = []
		var n1: Array[Vector3] = []
		var nm: Array[Vector3] = []
		var c1: Array[Color] = []
		var cm: Array[Color] = []
		for k in nv:
			var d := (poly[k] - c).rotated(rot)
			var radial := (u * d.x + Vector3.UP * d.y).normalized()
			r0.append(at.call(cs + d * s0, -jd * 0.45 + off))
			r1.append(at.call(cs + d * s1, proud + off))
			rm.append(at.call(cs + d * s1 * 0.55, proud + pillow * 0.72 + off))
			n0.append((n * 0.35 + radial).normalized())
			n1.append((n + radial * 0.6).normalized())
			nm.append((n + radial * 0.28).normalized())
			c1.append(_mossy(col, (r1[k] as Vector3).y - floor_y, low_m, low_moss * patch))
			cm.append(_mossy(col, (rm[k] as Vector3).y - floor_y, low_m, low_moss * patch))
		var top: Vector3 = at.call(cs, proud + pillow + off)
		var ct := _mossy(col, top.y - floor_y, low_m, low_moss * patch)
		var behind := top - n * 1.0
		for k in nv:
			var k2 := (k + 1) % nv
			# The bevel, from the joint up to the face.
			b._tri_n(r0[k], r0[k2], r1[k2], n0[k], n0[k2], n1[k2], foot_col, foot_col, c1[k2], behind)
			b._tri_n(r0[k], r1[k2], r1[k], n0[k], n1[k2], n1[k], foot_col, c1[k2], c1[k], behind)
			# The face's outer ring and its pillowed middle.
			b._tri_n(r1[k], r1[k2], rm[k2], n1[k], n1[k2], nm[k2], c1[k], c1[k2], cm[k2], behind)
			b._tri_n(r1[k], rm[k2], rm[k], n1[k], nm[k2], nm[k], c1[k], cm[k2], cm[k], behind)
			b._tri_n(rm[k], rm[k2], top, nm[k], nm[k2], n, cm[k], cm[k2], ct, behind)
		laid += 1
	b.mat = was_mat
	_vines(b, o, u, n, length, y0, y1, moss_k, proud + pillow, rng)
	_dust(b, o, u, n, length, floor_y, hum, rng)
	return laid


## A stone's colour with the lower wall's moss in its alpha (the ruin
## shader's moss), fading up the wall.
static func _mossy(col: Color, above_floor: float, low_m: float, amount: float) -> Color:
	var c := col
	c.a = clampf(amount * (1.0 - smoothstep(0.0, low_m, above_floor)), 0.0, 1.0)
	return c


## Vines (damp only): from the wall's top under the ceiling, and from
## cracks in its upper half, hanging down.
static func _vines(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, y0: float, y1: float, moss_k: float, out_m: float, rng: RandomNumberGenerator) -> void:
	if moss_k < 0.05:
		return
	var og := overgrowth()
	var count := int(floor(length * float(og.get("vines_per_m", 0.22)) * moss_k + rng.randf()))
	var lens: Array = og.get("vine_len_m", [0.6, 2.2])
	var was := b.mat
	b.mat = RuinBuilder.LEAF_M
	for i in count:
		var along := rng.randf_range(0.2, maxf(length - 0.2, 0.25))
		var from_top := rng.randf() < 0.6
		var y := y1 - 0.05 if from_top else lerpf(y0 + (y1 - y0) * 0.45, y1 - 0.3, rng.randf())
		var l := rng.randf_range(float(lens[0]), float(lens[1])) * (0.5 + 0.5 * moss_k)
		l = minf(l, y - y0 - 0.1)
		if l < 0.3:
			continue
		var top := o + u * along + Vector3.UP * y + n * out_m
		vine(b, top, u, n, l, rng)
	b.mat = was


## One creeping vine from `top` down the wall (`u` along it, `n` out of
## it), `length` long: a thin stem wandering down over the stones in short
## steps, small leaves off it to either side, a few at its tip.
static func vine(b: RuinBuilder, top: Vector3, u: Vector3, n: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	var steps := maxi(2, int(length / 0.22))
	var p := top
	var drift := rng.randf_range(-0.6, 0.6)
	var stem := RuinBuilder.IVY.darkened(0.25)
	var behind := top - n * 1.0
	for i in steps:
		drift = clampf(drift + rng.randf_range(-0.5, 0.5), -1.0, 1.0)
		var q := p + Vector3.UP * (-length / steps) + u * drift * 0.07 + n * rng.randf_range(-0.01, 0.01)
		var side := u * 0.022
		b._tri_n(p - side, p + side, q + side, n, n, n, stem, stem, stem, behind)
		b._tri_n(p - side, q + side, q - side, n, n, n, stem, stem, stem, behind)
		# Leaves: a small one to each side now and then, more near the tip.
		var k := float(i) / steps
		if rng.randf() < 0.55 + 0.35 * k:
			var sd := 1.0 if rng.randf() < 0.5 else -1.0
			var lc := RuinBuilder.IVY.lerp(RuinBuilder.IVY_LIGHT, rng.randf())
			var s := rng.randf_range(0.06, 0.11)
			var base := (p + q) * 0.5
			var tip := base + u * sd * s * 1.4 + Vector3.UP * s * 0.3 + n * 0.03
			b._tri_n(base, tip + Vector3.UP * s * 0.45, tip - Vector3.UP * s * 0.45, n, n, n, lc, lc.lightened(0.08), lc, behind)
		p = q


## Dust (dry only): drifts against the foot of the wall, the biggest in
## its corners.
static func _dust(b: RuinBuilder, o: Vector3, u: Vector3, n: Vector3, length: float, floor_y: float, hum: float, rng: RandomNumberGenerator) -> void:
	var og := overgrowth()
	var dry_below := float(og.get("dry_below", 0.32))
	if hum >= dry_below:
		return
	var k := 1.0 - hum / maxf(dry_below, 0.01)
	var hs: Array = og.get("dust_h_m", [0.04, 0.16])
	var col := Color(str(og.get("dust_color", "#a89a7c")))
	var was_solid := b.solid
	var was_mat := b.mat
	b.solid = false
	b.mat = DUST_M
	var spots: Array = [0.2, length - 0.2]
	var count := int(floor(length * float(og.get("dust_per_m", 0.35)) * k + rng.randf()))
	for i in count:
		spots.append(rng.randf_range(0.3, maxf(length - 0.3, 0.35)))
	for i in spots.size():
		var corner := i < 2
		var h := rng.randf_range(float(hs[0]), float(hs[1])) * (1.6 if corner else 1.0) * (0.5 + 0.5 * k)
		var along := float(spots[i])
		var c := o + u * along + Vector3.UP * floor_y + n * 0.12
		b.boulder(c, Vector3(rng.randf_range(0.35, 0.8), h, rng.randf_range(0.22, 0.4)), Basis(u, Vector3.UP, u.cross(Vector3.UP)).orthonormalized(), col.darkened(rng.randf_range(0.0, 0.12)), 0.0)
	b.solid = was_solid
	b.mat = was_mat

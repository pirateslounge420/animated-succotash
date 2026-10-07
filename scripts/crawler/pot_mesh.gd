class_name PotMesh
## The fire pot as a thing you can see (design 6 Oct night §FA.3; §FJ.5,
## Mike: "the clay pot bomb sounds good"): a small sealed pot of fired
## clay, the Byzantine ceramic fire grenade's shape, about 15 cm to the
## tip of its wick. A round belly on a narrow foot, a short neck, its
## mouth stopped with a plug, and a twist of fibre for a wick standing out
## of the plug. The oil shows without a word: a tar pot's plug is black
## pitch, run down over the shoulder in a few drips; a light-oil pot's is
## a pale clay-and-wax seal on clean clay.
##
## Mid-poly and flat-faced (8 sides, §ES), painted not lit: vertex colours,
## the occlusion under the belly and in the neck pulled toward the scene's
## navy (Prelit.ao_tint), drawn with the tomb's own matte material
## (RuinBuilder.material_lit: Lambert, no specular, only fire lights it),
## so in torchlight it reads like the clay urns among the grave goods.
## Its origin is its foot.

const SIDES := 8
## Fired terracotta (items.json pot's colour).
const CLAY := Color("#9c5a36")
const PITCH := Color("#17110C")
const SEAL := Color("#c9b78f")
const WICK := Color("#8a6a3e")
## The profile from the foot up: [radius m, height m, part, occlusion
## (1 open .. 0 shut in)]. "plug" takes the oil's plug colour.
const RINGS := [
	[0.000, 0.000, "clay", 0.45],
	[0.026, 0.000, "clay", 0.5],
	[0.046, 0.016, "clay", 0.62],
	[0.060, 0.045, "clay", 0.9],
	[0.057, 0.072, "clay", 1.0],
	[0.042, 0.094, "clay", 0.95],
	[0.021, 0.106, "clay", 0.7],
	[0.025, 0.114, "clay", 0.85],
	[0.022, 0.118, "plug", 0.9],
	[0.000, 0.124, "plug", 1.0],
]
## The wick: a thin four-sided twist from the plug's crown to its tip.
const WICK_FOOT := Vector3(0.0, 0.12, 0.0)
const WICK_TIP := Vector3(0.006, 0.152, 0.002)
const WICK_R := 0.0045
## A tar pot's drips: the sides the pitch has run down, and the ring it
## reaches on each.
const DRIPS := {1: 3, 4: 4, 6: 3}

static var _meshes := {}


## Where the wick's flame sits (local, the pot at its own size).
static func wick_tip() -> Vector3:
	return WICK_TIP


## The pot's mesh with `oil`'s plug ("tar" or "light_oil"), cached.
static func mesh(oil: String) -> ArrayMesh:
	if _meshes.has(oil):
		return _meshes[oil]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tar := oil == "tar"
	var plug := PITCH if tar else SEAL
	for i in RINGS.size() - 1:
		var r0: Array = RINGS[i]
		var r1: Array = RINGS[i + 1]
		for s in SIDES:
			var a0 := TAU * s / SIDES
			var a1 := TAU * (s + 1) / SIDES
			var p00 := _at(r0, a0)
			var p01 := _at(r0, a1)
			var p10 := _at(r1, a0)
			var p11 := _at(r1, a1)
			var c0 := _col(r0, plug, tar and DRIPS.has(s) and i >= int(DRIPS[s]))
			var c1 := _col(r1, plug, tar and DRIPS.has(s) and i + 1 >= int(DRIPS[s]))
			# Outward across the profile: away from the axis as it rises,
			# down under the foot, up over the plug.
			var mid := (a0 + a1) * 0.5
			var hint := Vector3(cos(mid), 0.0, sin(mid)) * (float(r1[1]) - float(r0[1])) + Vector3.UP * -(float(r1[0]) - float(r0[0]))
			if float(r0[0]) > 0.0001:
				_tri(st, p00, p01, p11, c0, c0, c1, hint)
			if float(r1[0]) > 0.0001:
				_tri(st, p00, p11, p10, c0, c1, c1, hint)
	# The wick.
	var axis := (WICK_TIP - WICK_FOOT).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	var side2 := axis.cross(side).normalized()
	var ring_lo: Array[Vector3] = []
	var ring_hi: Array[Vector3] = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var off := (side * cos(a) + side2 * sin(a)) * WICK_R
		ring_lo.append(WICK_FOOT + off)
		ring_hi.append(WICK_TIP + off * 0.7)
	var wl := Prelit.ao_tint(WICK, 0.8)
	var wh := WICK.lightened(0.08)
	for k in 4:
		var j := (k + 1) % 4
		var out := ((ring_lo[k] + ring_lo[j]) * 0.5 - WICK_FOOT).normalized()
		_tri(st, ring_lo[k], ring_lo[j], ring_hi[j], wl, wl, wh, out)
		_tri(st, ring_lo[k], ring_hi[j], ring_hi[k], wl, wh, wh, out)
	_tri(st, ring_hi[0], ring_hi[1], ring_hi[2], wh, wh, wh, axis)
	_tri(st, ring_hi[0], ring_hi[2], ring_hi[3], wh, wh, wh, axis)
	var m := st.commit()
	_meshes[oil] = m
	return m


## A pot to put in the scene: its mesh in the tomb's matte material, no
## shadow of its own (a hand's worth of clay).
static func node(oil: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Pot"
	mi.mesh = mesh(oil)
	mi.material_override = RuinBuilder.material_lit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _at(ring: Array, a: float) -> Vector3:
	return Vector3(cos(a) * float(ring[0]), float(ring[1]), sin(a) * float(ring[0]))


## A ring's painted colour: the clay (or the plug), its occlusion toward
## the scene's shade; pitch where a drip has run.
static func _col(ring: Array, plug: Color, dripped: bool) -> Color:
	var c := plug if str(ring[2]) == "plug" else (PITCH.lightened(0.05) if dripped else CLAY)
	return Prelit.ao_tint(c, float(ring[3]))


## One flat triangle facing `hint`'s way, in the material the tomb's
## shader reads as a plain grain (RuinBuilder.HIDE_M), no moss.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	var uv := Vector2(float(RuinBuilder.HIDE_M), 0.0)
	for v in [[a, ca], [b, cb], [c, cc]]:
		st.set_normal(n)
		st.set_uv(uv)
		var col: Color = v[1]
		st.set_color(Color(col.r, col.g, col.b, 0.0))
		st.add_vertex(v[0])

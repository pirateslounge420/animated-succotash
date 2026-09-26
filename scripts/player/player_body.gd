class_name PlayerBody
extends Node3D
## The player's placeholder body: an elf wanderer in a long robe. It's
## built procedurally, like CreatureBodies, but as a few merged meshes,
## not a node per part.
##
## Look: lean, long chestnut hair to mid-back with two locks framing the
## face down over the chest, a leather headband and a feather, and pointed
## ears angled out and back past the hair. A single-piece robe of woven
## plant fiber in moss green flares to the ankles. Its folds are painted into the vertex colors as creases, and
## a leather band trims the hem. A grey-brown fur mantle covers the
## shoulders, with a necklace of bone and wooden beads and a tooth pendant.
## A hide belt with a bone toggle holds a satchel on the right hip, and
## boot toes show under the hem. Colors are earthy, for a tribal traveler,
## not nobility.
##
## Technique: every part is a smooth-shaded surface of revolution
## (_lathe) with its color, material and sway baked per vertex into four
## meshes, so the body costs four draw calls:
##   Body     robe, hem, mantle, belt, satchel, beads, boots;
##   Head     at the neck: face, eyes, ears, hair, headband, feather;
##   ArmL/R   at the shoulders: sleeve and hand.
## The pivots are there for the rigged model or animation to come
## (PlanetPlayer.anim_state names the pose). shaders/player.gdshader lights
## it like the creatures and adds each material's low-res texture. Robe
## hem, sleeve ends and hair trail and flutter by `set_motion()`.
##
## Faces -Z, +Y up, feet at y = 0, about 1.75 m tall.

const SKIN := Color(0.8, 0.63, 0.48)
const ROBE := Color(0.42, 0.52, 0.28) # moss-green woven fiber
const HIDE := Color(0.46, 0.32, 0.2)
const DARK_HIDE := Color(0.3, 0.2, 0.13)
const FUR := Color(0.55, 0.47, 0.37)
const HAIR := Color(0.55, 0.32, 0.16) # chestnut
const BONE := Color(0.87, 0.83, 0.71)
const WOOD := Color(0.47, 0.3, 0.17)
const OCHRE := Color(0.66, 0.33, 0.18)
const EYE := Color(0.13, 0.2, 0.14) # dark green-hazel
const EYE_WHITE := Color(0.9, 0.87, 0.8)

enum { SKIN_K, WEAVE_K, FUR_K, LEATHER_K, BONE_K, HAIR_K }

## Rings of the robe, neck to hem: [half-width, half-depth, y, z offset
## (the skirt hangs back a little), sway].
const ROBE_RINGS := [
	[0.065, 0.065, 1.5, 0.0, 0.0],
	[0.12, 0.1, 1.46, 0.0, 0.0],
	[0.2, 0.125, 1.39, 0.0, 0.0],
	[0.19, 0.125, 1.27, 0.0, 0.0],
	[0.165, 0.11, 1.12, 0.0, 0.0],
	[0.15, 0.105, 1.0, 0.0, 0.0],
	[0.18, 0.13, 0.88, 0.005, 0.05],
	[0.215, 0.165, 0.62, 0.015, 0.3],
	[0.25, 0.2, 0.36, 0.03, 0.65],
	[0.285, 0.245, 0.12, 0.045, 0.92],
	[0.29, 0.25, 0.03, 0.05, 1.0],
]
const PLEATS := 5.0
const HEAD_RINGS := 13
const HEAD_RADIAL := 22

var head: Node3D
var arms: Array[Node3D] = []
## Triangles in the whole body (for the budget).
var triangles := 0

var _mat: ShaderMaterial
var _motion := 0.0


func _init() -> void:
	name = "Body"
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/player.gdshader")
	Look.register(_mat)
	_mat.set_shader_parameter("look_tex_weave", Look.texture("weave"))
	_mat.set_shader_parameter("look_tex_fur", Look.texture("fur"))
	_build_torso()
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.55, 0)
	add_child(head)
	_build_head()
	for s: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if s < 0.0 else "ArmR"
		arm.position = Vector3(0.205 * s, 1.385, 0.0)
		arm.rotation = Vector3(0.06, 0.0, 0.13 * s)
		add_child(arm)
		_build_arm(arm)
		arms.append(arm)


## Per frame: how fast the player is going, 0 (still) to 1 (sprinting).
## The robe hem, sleeve ends and hair trail behind, eased.
func set_motion(speed_frac: float, delta: float) -> void:
	_motion = lerpf(_motion, clampf(speed_frac, 0.0, 1.0), clampf(delta * 3.0, 0.0, 1.0))
	_mat.set_shader_parameter("motion", _motion)


# --- Parts -------------------------------------------------------------------

func _build_torso() -> void:
	var g := Geo.new()
	# The robe: pleats deepen toward the hem, creases painted darker, a
	# wrap seam down the front, shade under the mantle and belt.
	var robe_ys: Array[float] = [1.5, 1.46, 1.39, 1.27, 1.12, 1.0, 0.88, 0.62, 0.36, 0.14]
	_lathe(g, robe_ys.size(), 30, func(i: int, a: float) -> Array:
		var y := robe_ys[i]
		var p := _robe_at(y, a, 1.0)
		var sway: float = p[1]
		var crease := 0.5 - 0.5 * sin(PLEATS * a + 0.8 * sway + 0.4)
		var shade := 1.0 - 0.28 * pow(sway, 0.6) * crease
		if y > 1.2 and y < 1.3:
			shade *= 0.8 # under the fur
		elif absf(y - 1.0) < 0.13:
			shade *= 0.9 # around the belt
		# The wrap's overlap, left of center in front, below the belt.
		if y < 1.0 and absf(wrapf(a - (1.5 * PI + 0.45), -PI, PI)) < 0.2:
			shade *= 0.72
		return [p[0], ROBE * shade, sway],
		WEAVE_K, Vector3(0, 1.52, 0), Vector3(0, 0.12, 0.03))
	# Leather hem band, just outside the robe's last rings.
	var hem_ys: Array[float] = [0.2, 0.12, 0.045]
	_lathe(g, hem_ys.size(), 30, func(i: int, a: float) -> Array:
		var p := _robe_at(hem_ys[i], a, 1.03)
		var crease := 0.5 - 0.5 * sin(PLEATS * a + 0.8 * float(p[1]) + 0.4)
		return [p[0], HIDE * (1.0 - 0.22 * crease) * (0.85 if i == 2 else 1.0), p[1]],
		LEATHER_K, Vector3(0, 0.21, 0.04), Vector3(0, 0.07, 0.05))
	# Fur mantle over the shoulders, ragged at its lower edge and hanging
	# a little lower front and back.
	var mantle := [[0.085, 0.08, 1.555], [0.17, 0.14, 1.51], [0.25, 0.18, 1.44], [0.275, 0.195, 1.36], [0.255, 0.185, 1.29]]
	_lathe(g, mantle.size(), 36, func(i: int, a: float) -> Array:
		var m: Array = mantle[i]
		var r := 1.0
		var y: float = m[2]
		if i == mantle.size() - 1:
			r = 1.0 + 0.05 * sin(9.0 * a)
			y += -0.05 * absf(sin(a)) + 0.02 * sin(7.0 * a + 1.0)
		var shade := 0.72 if i == mantle.size() - 1 else 1.0 - 0.05 * i
		return [Vector3(cos(a) * m[0] * r, y, sin(a) * m[1] * r + 0.01), FUR * shade, 0.12 if i == mantle.size() - 1 else 0.0],
		FUR_K, Vector3(0, 1.57, 0.01), Vector3(0, 1.28, 0.01))
	# Belt, its bone toggle and two hanging ends.
	var belt := [[0.157, 0.111, 1.03], [0.165, 0.118, 1.0], [0.157, 0.111, 0.97]]
	_lathe(g, belt.size(), 28, func(i: int, a: float) -> Array:
		var b: Array = belt[i]
		return [Vector3(cos(a) * b[0], b[2], sin(a) * b[1]), DARK_HIDE, 0.0],
		LEATHER_K, Vector3(0, 1.035, 0), Vector3(0, 0.965, 0))
	_ellipsoid(g, Vector3(0.035, 1.0, -0.122), Vector3(0.03, 0.011, 0.011), BONE, BONE_K, 10, 4)
	_ellipsoid(g, Vector3(0.05, 0.91, -0.118), Vector3(0.016, 0.075, 0.006), DARK_HIDE, LEATHER_K, 8, 4, Basis(Vector3.FORWARD, 0.12), 0.25)
	_ellipsoid(g, Vector3(0.075, 0.92, -0.112), Vector3(0.014, 0.065, 0.006), DARK_HIDE, LEATHER_K, 8, 4, Basis(Vector3.FORWARD, -0.1), 0.25)
	# Satchel on the right hip, slightly behind.
	var out := Vector3(0.92, 0, 0.4).normalized()
	var sb := Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)
	_ellipsoid(g, out * 0.215 + Vector3(0, 0.86, 0.01), Vector3(0.075, 0.085, 0.035), HIDE.darkened(0.08), LEATHER_K, 16, 7, sb, 0.15)
	_ellipsoid(g, out * 0.245 + Vector3(0, 0.905, 0.01), Vector3(0.07, 0.035, 0.012), HIDE.darkened(0.25), LEATHER_K, 12, 4, sb, 0.15)
	# Necklace on the mantle: bone and wood beads and a tooth.
	var beads := [[-0.058, 1.415, BONE], [0.058, 1.415, BONE], [-0.03, 1.375, WOOD], [0.03, 1.375, WOOD]]
	for b: Array in beads:
		var c: Color = b[2]
		_ellipsoid(g, Vector3(b[0], b[1], -0.19), Vector3.ONE * 0.013, c, BONE_K, 8, 4)
	_cone(g, Vector3(0, 1.365, -0.195), Vector3(0, -1, -0.15), 0.05, Vector3(0.012, 0, 0.008), BONE, BONE_K, 8, Vector3.FORWARD)
	# Boot toes under the hem.
	for s: float in [-1.0, 1.0]:
		_ellipsoid(g, Vector3(0.085 * s, 0.035, -0.19), Vector3(0.048, 0.036, 0.075), DARK_HIDE, LEATHER_K, 14, 7)
	_add(self, g, "Robe")


func _build_head() -> void:
	var g := Geo.new()
	# Neck, mostly hidden by the mantle.
	var neck := [[0.043, 0.041, 0.06], [0.046, 0.044, -0.06]]
	_lathe(g, 2, 16, func(i: int, a: float) -> Array:
		var n: Array = neck[i]
		return [Vector3(cos(a) * n[0], n[2], sin(a) * n[1]), SKIN * 0.82, 0.0],
		SKIN_K, Vector3(0, 0.06, 0), Vector3(0, -0.06, 0))
	# The head: an egg narrowing to a long jaw and a pointed chin.
	_lathe(g, HEAD_RINGS, HEAD_RADIAL, func(i: int, a: float) -> Array:
		var p := _head_at(i, a)
		return [p, SKIN * (1.0 - 0.1 * clampf((0.12 - p.y) / 0.115, 0.0, 1.0)), 0.0],
		SKIN_K, Vector3(0, 0.237, 0), Vector3(0, 0.014, -0.026))
	# Slanted eyes, brows, a small nose, ochre paint on the cheeks.
	for s: float in [-1.0, 1.0]:
		var eb := Basis(Vector3.FORWARD, 0.22 * s)
		_ellipsoid(g, Vector3(0.032 * s, 0.132, -0.088), Vector3(0.019, 0.01, 0.007), EYE_WHITE, SKIN_K, 10, 4, eb)
		_ellipsoid(g, Vector3(0.03 * s, 0.132, -0.093), Vector3(0.009, 0.0095, 0.005), EYE, SKIN_K, 8, 4, eb)
		_ellipsoid(g, Vector3(0.034 * s, 0.153, -0.091), Vector3(0.021, 0.004, 0.007), HAIR, HAIR_K, 8, 3, Basis(Vector3.FORWARD, 0.3 * s))
		_ellipsoid(g, Vector3(0.047 * s, 0.1, -0.078), Vector3(0.018, 0.0045, 0.006), OCHRE, SKIN_K, 8, 3, Basis(Vector3.UP, -0.55 * s))
	_cone(g, Vector3(0, 0.133, -0.093), Vector3(0, -0.55, -1), 0.032, Vector3(0.012, 0, 0.01), SKIN * 0.95, SKIN_K, 8, Vector3.UP)
	# Hair: a shell over the head, tucked under the skin where the face
	# and jaw show (the surfaces' crossing draws the hairline), a long fall
	# down the back to the shoulder blades, a leather headband and a
	# feather tied at the back.
	_lathe(g, HEAD_RINGS, HEAD_RADIAL, func(i: int, a: float) -> Array:
		var p := _head_at(i, a)
		var front := -sin(a)
		var face := clampf((front - 0.3) / 0.3, 0.0, 1.0) * clampf((0.19 - p.y) / 0.02, 0.0, 1.0)
		var jaw := clampf((0.3 - sin(a)) / 0.3, 0.0, 1.0) * clampf((0.085 - p.y) / 0.02, 0.0, 1.0)
		var grow := lerpf(1.07 + 0.05 * clampf(sin(a), 0.0, 1.0), 0.86, maxf(face, jaw))
		var c := Vector3(0, 0.12, 0)
		return [c + (p - c) * grow + Vector3(0, 0.006, 0.004), HAIR, 0.0],
		HAIR_K, Vector3(0, 0.25, 0.004), Vector3(0, 0.03, 0.01))
	var fall := 9
	_lathe(g, fall, 16, func(i: int, a: float) -> Array:
		var t := float(i) / (fall - 1)
		var c := Vector3(0, 0.12 - 0.46 * t, 0.07 + 0.19 * pow(t, 0.8))
		var strand := 1.0 + 0.1 * sin(4.0 * a) * t
		var p := c + Vector3(cos(a) * 0.088 * (1.0 - 0.35 * t) * strand, 0, sin(a) * 0.032 * (1.0 - 0.3 * t))
		return [p, HAIR * (1.0 - 0.15 * t), t],
		HAIR_K, Vector3(0, 0.16, 0.06), Vector3(0, -0.36, 0.265))
	var band := [[0.073, 0.087, 0.197], [0.079, 0.093, 0.185], [0.075, 0.089, 0.173]]
	_lathe(g, band.size(), HEAD_RADIAL, func(i: int, a: float) -> Array:
		var b: Array = band[i]
		return [Vector3(cos(a) * b[0], b[2], sin(a) * b[1] + 0.004), DARK_HIDE, 0.0],
		LEATHER_K, Vector3(0, 0.2, 0.004), Vector3(0, 0.17, 0.004))
	var fb := Basis(Vector3.RIGHT, 0.5) * Basis(Vector3.BACK, -0.3)
	_ellipsoid(g, Vector3(-0.06, 0.1, 0.115), Vector3(0.004, 0.055, 0.014), BONE, BONE_K, 8, 5, fb, 0.6)
	_ellipsoid(g, Vector3(-0.047, 0.052, 0.14), Vector3(0.0045, 0.014, 0.011), HAIR, HAIR_K, 8, 3, fb, 0.8)
	# Two long locks from the temples, over the mantle, down the chest.
	for s: float in [-1.0, 1.0]:
		_lock(g, s)
	# Pointed ears: up, back and a little out, past the hair.
	for s: float in [-1.0, 1.0]:
		_ear(g, s)
	_add(head, g, "Head")


## A lock of hair falling from the temple on side `s`, out over the
## mantle and down the chest, a flat tapering strand.
func _lock(g: Geo, s: float) -> void:
	var path: Array[Vector3] = [Vector3(0.078, 0.11, -0.035), Vector3(0.1, 0.02, -0.08),
		Vector3(0.125, -0.08, -0.148), Vector3(0.13, -0.19, -0.178), Vector3(0.126, -0.3, -0.182),
		Vector3(0.118, -0.42, -0.16)]
	_lathe(g, path.size(), 10, func(i: int, a: float) -> Array:
		var t := float(i) / (path.size() - 1)
		var c := path[i] * Vector3(s, 1, 1)
		var w := 0.04 * (1.0 - 0.45 * t)
		return [c + Vector3(cos(a) * w, 0, sin(a) * 0.012), HAIR * (1.0 - 0.1 * t), t * 0.7],
		HAIR_K, Vector3(0.07 * s, 0.13, -0.03), Vector3(0.114 * s, -0.45, -0.155))


## A point on the head's surface: ring `i` (of HEAD_RINGS, top to
## bottom) at angle `a`, in head space.
static func _head_at(i: int, a: float) -> Vector3:
	var phi := PI * (i + 1) / (HEAD_RINGS + 1)
	var y := 0.115 * cos(phi)
	var s := sin(phi)
	var low := clampf(-y / 0.115, 0.0, 1.0)
	var x := cos(a) * s * 0.082 * (1.0 - 0.3 * low)
	var z := sin(a) * s * 0.098 * (1.0 - 0.12 * low) - 0.012 * low
	return Vector3(x, 0.12 + y, z)


func _ear(g: Geo, s: float) -> void:
	var base := Vector3(0.084 * s, 0.122, 0.004)
	var dir := Vector3(0.75 * s, 0.5, 0.45).normalized()
	var length := 0.09
	var basis := _basis_y(dir, Vector3(s, 0, -0.35))
	var prof := [[0.024, 0.0], [0.03, 0.3], [0.014, 0.72]]
	_lathe(g, prof.size(), 10, func(i: int, a: float) -> Array:
		var p: Array = prof[i]
		return [base + basis * Vector3(cos(a) * p[0], float(p[1]) * length, sin(a) * 0.008), SKIN * (0.9 if i == 0 else 1.0), 0.0],
		SKIN_K, base + basis * Vector3(0, length, 0), base - basis * Vector3(0, 0.01, 0))


func _build_arm(arm: Node3D) -> void:
	var g := Geo.new()
	# A long sleeve widening to a bell at the wrist.
	var sleeve := [[0.058, 0.055, 0.02, 0.0], [0.062, 0.06, -0.12, 0.0], [0.068, 0.066, -0.3, 0.1], [0.1, 0.095, -0.47, 0.5], [0.112, 0.105, -0.55, 1.0]]
	_lathe(g, sleeve.size(), 20, func(i: int, a: float) -> Array:
		var sl: Array = sleeve[i]
		var sway: float = sl[3]
		var crease := 0.5 - 0.5 * sin(3.0 * a + 1.0)
		var shade := (1.0 - 0.25 * sway * crease) * (0.85 if i == 0 else 1.0)
		return [Vector3(cos(a) * sl[0], sl[2], sin(a) * sl[1]), ROBE * shade, sway],
		WEAVE_K, Vector3(0, 0.06, 0), Vector3(0, -0.51, 0))
	_ellipsoid(g, Vector3(0, -0.6, -0.005), Vector3(0.036, 0.052, 0.042), SKIN, SKIN_K, 14, 7)
	_add(arm, g, "Sleeve")


# --- Geometry ------------------------------------------------------------------

## Vertices of the parts merged into one mesh.
class Geo:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()


## The robe's surface at height `y` and angle `a` (0 = +X, 1.5 PI = front),
## `grow` times its radius: [position, sway].
static func _robe_at(y: float, a: float, grow: float) -> Array:
	var i := 0
	while i < ROBE_RINGS.size() - 2 and ROBE_RINGS[i + 1][2] > y:
		i += 1
	var r0: Array = ROBE_RINGS[i]
	var r1: Array = ROBE_RINGS[i + 1]
	var t := clampf((r0[2] - y) / (r0[2] - r1[2]), 0.0, 1.0)
	var rx := lerpf(r0[0], r1[0], t)
	var rz := lerpf(r0[1], r1[1], t)
	var oz := lerpf(r0[3], r1[3], t)
	var sway := lerpf(r0[4], r1[4], t)
	# Pleats: the fabric in and out around the skirt, deeper lower down,
	# with a gentle wave in the hem so it doesn't read as a stiff cone.
	var pleat := 1.0 + 0.065 * pow(sway, 0.7) * sin(PLEATS * a + 0.8 * sway + 0.4)
	pleat += 0.03 * sway * sin(3.0 * a + 2.0)
	return [Vector3(cos(a) * rx * pleat * grow, y, sin(a) * rz * pleat * grow + oz), sway]


## A closed, smooth-shaded surface around a (possibly bent) axis:
## `rings` rings of `radial` points, top to bottom, closed by poles at
## `top` and `bottom`. f.call(ring, angle) -> [position, color, sway].
static func _lathe(g: Geo, rings: int, radial: int, f: Callable, kind: int, top: Vector3, bottom: Vector3) -> void:
	var start := g.verts.size()
	var first := g.idx.size()
	var p0: Array = f.call(0, 0.0)
	_vert(g, top, p0[1], kind, p0[2])
	for i in rings:
		for k in radial:
			var p: Array = f.call(i, TAU * k / radial)
			_vert(g, p[0], p[1], kind, p[2])
	var pl: Array = f.call(rings - 1, 0.0)
	_vert(g, bottom, pl[1], kind, pl[2])
	var last := g.verts.size() - 1
	for k in radial:
		var k1 := (k + 1) % radial
		g.idx.append_array([start, start + 1 + k, start + 1 + k1])
		for r in rings - 1:
			var a0 := start + 1 + r * radial
			var a1 := a0 + radial
			g.idx.append_array([a0 + k, a1 + k1, a0 + k1, a0 + k, a1 + k, a1 + k1])
		var lb := start + 1 + (rings - 1) * radial
		g.idx.append_array([lb + k, last, lb + k1])
	# Face the part outward. Godot draws a triangle whose (v1 - v0) x
	# (v2 - v0) points away from the camera, so that cross product must
	# point in.
	var mid := Vector3.ZERO
	for v in range(start, g.verts.size()):
		mid += g.verts[v]
	mid /= g.verts.size() - start
	var out_sum := 0.0
	for t in range(first, g.idx.size(), 3):
		var a := g.verts[g.idx[t]]
		var fn := (g.verts[g.idx[t + 1]] - a).cross(g.verts[g.idx[t + 2]] - a)
		out_sum += fn.dot((a + g.verts[g.idx[t + 1]] + g.verts[g.idx[t + 2]]) / 3.0 - mid)
	if out_sum > 0.0:
		for t in range(first, g.idx.size(), 3):
			var tmp := g.idx[t + 1]
			g.idx[t + 1] = g.idx[t + 2]
			g.idx[t + 2] = tmp


static func _vert(g: Geo, p: Vector3, c: Color, kind: int, sway: float) -> void:
	g.verts.append(p)
	# Raw, like the terrain's and ruins' vertex colors (the world's grade
	# is tuned for those; converted to linear the elf read near black).
	g.colors.append(c)
	g.uv.append(Vector2(kind, sway))


static func _ellipsoid(g: Geo, c: Vector3, r: Vector3, col: Color, kind: int, radial: int, rings: int, basis := Basis(), sway := 0.0) -> void:
	_lathe(g, rings, radial, func(i: int, a: float) -> Array:
		var phi := PI * (i + 1) / (rings + 1)
		var s := sin(phi)
		return [c + basis * Vector3(cos(a) * s * r.x, cos(phi) * r.y, sin(a) * s * r.z), col, sway],
		kind, c + basis * Vector3(0, r.y, 0), c - basis * Vector3(0, r.y, 0))


## A cone from `base` along `dir`: `r` is its base's half-width (x) and
## half-depth (z); `hint` sets which way the depth faces.
static func _cone(g: Geo, base: Vector3, dir: Vector3, length: float, r: Vector3, col: Color, kind: int, radial: int, hint: Vector3) -> void:
	var basis := _basis_y(dir.normalized(), hint)
	_lathe(g, 1, radial, func(_i: int, a: float) -> Array:
		return [base + basis * Vector3(cos(a) * r.x, 0, sin(a) * r.z), col, 0.0],
		kind, base + basis * Vector3(0, length, 0), base)


## A basis with Y along `y` and Z as close to `hint` as it can be.
static func _basis_y(y: Vector3, hint: Vector3) -> Basis:
	var x := y.cross(hint).normalized()
	return Basis(x, y, x.cross(y).normalized())


## Smooth normals, then the mesh on its own MeshInstance3D under `parent`.
func _add(parent: Node3D, g: Geo, part: String) -> void:
	var normals := PackedVector3Array()
	normals.resize(g.verts.size())
	for t in range(0, g.idx.size(), 3):
		var a := g.verts[g.idx[t]]
		var fn := (g.verts[g.idx[t + 1]] - a).cross(g.verts[g.idx[t + 2]] - a)
		for q in 3:
			normals[g.idx[t + q]] -= fn # faces are wound inward (see _lathe)
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g.verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = g.colors
	arrays[Mesh.ARRAY_TEX_UV] = g.uv
	arrays[Mesh.ARRAY_INDEX] = g.idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = part
	mi.mesh = mesh
	mi.material_override = _mat
	parent.add_child(mi)
	triangles += g.idx.size() / 3

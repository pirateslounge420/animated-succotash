class_name FruitMeshes
## The unit meshes of flowers, fruit and the pollinators that visit them
## (FruitCrop; design §AS), drawn with the aroid parts' shader
## (shaders/aroid_part.gdshader: COLOR the main colour, the instance's
## custom data the second colour and a mode). Low poly with smooth normals,
## the GameCube look. Built once, shared.
##
##   flower(form, count): a spray of `count` flowers of one form, each 1
##     across (the instance scales them to the species' flower size),
##     facing +Y; UV.x 1 on the middle (stamens, a tube's throat: the
##     second colour, mode 10). Forms: cup, star, bell, tube, pea, brush,
##     ball, catkin, spike, panicle, cone, tiny.
##   bud(): a closed flower bud.
##   fruit(shape): one fruit hanging from its stalk at the origin, 1 long
##     down -Y. Shapes: round, ovoid, elongated, pod, coiled, winged, star,
##     cone.
##   visitor(kind): a pollinator's body (1 long along +Z); wing(): one wing
##     (a flat blade out along +X from the body's side).
##   stalk(): an agave's or a yucca's flower stalk, 1 long up +Y.

const SIDES := 8
static var _cache := {}


static func flower(form: String, count := 1) -> Mesh:
	var key := "flower:%s:%d" % [form, count]
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		for k in maxi(count, 1):
			# A spray: the first in the middle, the rest round it, tipped out.
			var off := Vector3.ZERO
			var tilt := Basis.IDENTITY
			if k > 0:
				var a := TAU * (k - 1) / maxf(count - 1, 1) + rng.randf_range(-0.3, 0.3)
				off = Vector3(cos(a), rng.randf_range(-0.35, 0.05), sin(a)) * 0.85
				tilt = Basis(Vector3(-sin(a), 0, cos(a)), rng.randf_range(0.35, 0.7))
			var s := 1.0 if k == 0 else rng.randf_range(0.75, 0.95)
			_flower_one(st, form, Transform3D(tilt.scaled(Vector3.ONE * s), off), rng)
		st.generate_normals()
		_cache[key] = st.commit()
	return _cache[key]


static func bud() -> Mesh:
	if not _cache.has("bud"):
		_cache["bud"] = _lathe_mesh([[0.0, 0.0], [0.15, 0.3], [0.5, 0.42], [0.85, 0.28], [1.0, 0.0]], Vector3.UP, 0.0)
	return _cache["bud"]


static func fruit(shape: String) -> Mesh:
	var key := "fruit:" + shape
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match shape:
			"ovoid":
				_ellipsoid(st, Vector3(0, -0.54, 0), Vector3(0.36, 0.48, 0.36), 2)
			"elongated":
				_lathe(st, [[0.0, 0.03], [0.08, 0.13], [0.3, 0.17], [0.7, 0.16], [0.92, 0.11], [1.0, 0.02]], Vector3.DOWN, 0.0)
			"pod":
				var t := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.3)), Vector3.ZERO)
				_lathe(st, [[0.0, 0.02], [0.06, 0.11], [0.5, 0.13], [0.94, 0.1], [1.0, 0.02]], Vector3.DOWN, 0.0, t)
			"coiled":
				_coil(st)
			"winged":
				_ellipsoid(st, Vector3(0, -0.85, 0), Vector3(0.11, 0.14, 0.09), 1)
				_blade(st, Vector3(0, -0.8, 0), Vector3(0.22, -0.05, 0), 0.5)
			"star":
				_star_fruit(st)
			"cone":
				_lathe(st, [[0.0, 0.05], [0.12, 0.26], [0.35, 0.36], [0.6, 0.34], [0.85, 0.22], [1.0, 0.03]], Vector3.DOWN, 0.0)
			_:
				_ellipsoid(st, Vector3(0, -0.52, 0), Vector3(0.48, 0.48, 0.48), 2)
		# The stalk it hangs by.
		_lathe(st, [[0.0, 0.025], [0.1, 0.02]], Vector3.DOWN, 0.0)
		st.generate_normals()
		_cache[key] = st.commit()
	return _cache[key]


## A pollinator's body, 1 long along +Z, by kind: a bee's plump abdomen,
## a moth's or butterfly's slim body, a bird's or bat's with a head.
static func visitor(kind: String) -> Mesh:
	var key := "visitor:" + kind
	if not _cache.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			"bird", "bat":
				_ellipsoid(st, Vector3(0, 0, -0.05), Vector3(0.2, 0.2, 0.42), 1)
				_ellipsoid(st, Vector3(0, 0.06, 0.38), Vector3(0.13, 0.13, 0.13), 1)
				if kind == "bird":
					# The long bill of a nectar bird.
					_lathe(st, [[0.0, 0.03], [1.0, 0.004]], Vector3.BACK, 0.0, Transform3D(Basis.from_scale(Vector3(1, 1, 0.35)), Vector3(0, 0.05, 0.48)))
			"butterfly", "moth":
				_ellipsoid(st, Vector3.ZERO, Vector3(0.09, 0.09, 0.5), 1)
			_:
				# Head, thorax, banded abdomen.
				_ellipsoid(st, Vector3(0, 0, 0.36), Vector3(0.14, 0.14, 0.13), 1)
				_ellipsoid(st, Vector3(0, 0, 0.16), Vector3(0.17, 0.17, 0.16), 1)
				_ellipsoid(st, Vector3(0, 0, -0.18), Vector3(0.2, 0.2, 0.32), 1)
		st.generate_normals()
		_cache[key] = st.commit()
	return _cache[key]


## A flower stalk (an agave's, a yucca's): a tapering pole up +Y, 1 long,
## radius 1 at its foot (the instance scales it).
static func stalk() -> Mesh:
	if not _cache.has("stalk"):
		_cache["stalk"] = _lathe_mesh([[0.0, 1.0], [0.6, 0.75], [1.0, 0.35]], Vector3.UP, 0.0)
	return _cache["stalk"]


## One wing: a flat rounded blade out along +X from the origin, 1 long.
static func wing() -> Mesh:
	if not _cache.has("wing"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(0, 0, 0.12), Vector3(0.35, 0, 0.3), Vector3(0.8, 0, 0.22), Vector3(1.0, 0, 0.0), Vector3(0.8, 0, -0.2), Vector3(0.35, 0, -0.24), Vector3(0, 0, -0.1)]
		for i in range(1, pts.size() - 1):
			for v in [pts[0], pts[i], pts[i + 1]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(v)
		_cache["wing"] = st.commit()
	return _cache["wing"]


# --- Flowers --------------------------------------------------------------------

static func _flower_one(st: SurfaceTool, form: String, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	match form:
		"cup", "star", "pea":
			var n := 5 if form != "pea" else 3
			var lift := 0.28 if form == "cup" else (0.06 if form == "star" else 0.35)
			var w := 0.26 if form == "cup" else (0.14 if form == "star" else 0.3)
			var a0 := rng.randf() * TAU
			for k in n:
				var a := a0 + TAU * k / n
				var out := Vector3(cos(a), 0, sin(a))
				var side := Vector3(-sin(a), 0, cos(a))
				var tip := out * 0.5 + Vector3.UP * lift
				var mid := out * 0.3 + Vector3.UP * lift * 0.5
				var base := Vector3.UP * 0.02
				_quad(st, xf, base, mid + side * w * 0.5, tip, mid - side * w * 0.5, 0.0)
			# The middle: stamens.
			_disc(st, xf, Vector3.UP * 0.05, 0.12, 1.0)
		"bell":
			_lathe(st, [[0.0, 0.05], [0.25, 0.24], [0.7, 0.34], [1.0, 0.46]], Vector3.DOWN, 0.0, xf)
			_lathe(st, [[0.05, 0.03], [0.95, 0.4]], Vector3.DOWN, 1.0, xf)
		"tube":
			_lathe(st, [[0.0, 0.1], [0.5, 0.12], [1.0, 0.2], [1.25, 0.38], [1.35, 0.5]], Vector3.UP, 0.0, xf)
			_lathe(st, [[0.3, 0.08], [1.0, 0.16], [1.3, 0.44]], Vector3.UP, 1.0, xf)
		"brush":
			# A puff of stamens, pale at the foot.
			for k in 22:
				var d := Vector3(rng.randfn(), absf(rng.randfn()) + 0.4, rng.randfn()).normalized()
				_spike(st, xf, Vector3.ZERO, d * 0.5, 0.035)
			_ellipsoid(st, Vector3(0, 0.02, 0), Vector3(0.1, 0.08, 0.1), 0, xf, 1.0)
		"ball":
			_ellipsoid(st, Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.5), 1, xf)
		"catkin":
			_lathe(st, [[0.0, 0.08], [0.2, 0.2], [2.4, 0.18], [3.0, 0.05]], Vector3.DOWN, 0.0, xf)
		"spike":
			_lathe(st, [[0.0, 0.22], [0.4, 0.3], [1.4, 0.18], [2.0, 0.02]], Vector3.UP, 0.0, xf)
		"panicle":
			for k in 7:
				var y := 0.3 + 0.28 * k
				var r := 0.5 * (1.0 - float(k) / 7.0)
				var a := 2.39996 * k
				_ellipsoid(st, Vector3(cos(a) * r, y, sin(a) * r), Vector3(0.16, 0.16, 0.16), 0, xf)
			_spike(st, xf, Vector3.ZERO, Vector3(0, 2.2, 0), 0.04)
		"cone":
			_lathe(st, [[0.0, 0.1], [0.25, 0.3], [0.9, 0.28], [1.4, 0.03]], Vector3.UP, 0.0, xf)
		_:
			# "tiny": a knot of small florets.
			for k in 5:
				var d := Vector3(rng.randfn(), absf(rng.randfn()), rng.randfn()).normalized() * 0.28
				_ellipsoid(st, d + Vector3(0, 0.2, 0), Vector3(0.14, 0.14, 0.14), 0, xf)


static func _quad(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvx: float) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_uv(Vector2(uvx, 0))
		st.add_vertex(xf * v)


static func _disc(st: SurfaceTool, xf: Transform3D, at: Vector3, r: float, uvx: float) -> void:
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		for v in [at + Vector3.UP * 0.03, at + Vector3(cos(a1), 0, sin(a1)) * r, at + Vector3(cos(a0), 0, sin(a0)) * r]:
			st.set_uv(Vector2(uvx, 0))
			st.add_vertex(xf * v)


static func _spike(st: SurfaceTool, xf: Transform3D, from: Vector3, to: Vector3, w: float) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized() * w
	var side2 := axis.cross(side).normalized() * w
	for s in [side, side2]:
		for v in [from - s, to, from + s]:
			st.set_uv(Vector2(1.0, 0))
			st.add_vertex(xf * v)


# --- Shapes ----------------------------------------------------------------------

static func _lathe_mesh(profile: Array, dir: Vector3, uvx: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_lathe(st, profile, dir, uvx)
	st.generate_normals()
	return st.commit()


## A surface of revolution along `dir` (UP or DOWN, or BACK for a bill):
## `profile` [[distance along, radius]...].
static func _lathe(st: SurfaceTool, profile: Array, dir: Vector3, uvx: float, xf := Transform3D.IDENTITY) -> void:
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	var side2 := dir.cross(side).normalized()
	for i in profile.size() - 1:
		var y0 := float(profile[i][0])
		var r0 := float(profile[i][1])
		var y1 := float(profile[i + 1][0])
		var r1 := float(profile[i + 1][1])
		for k in SIDES:
			var a0 := TAU * k / SIDES
			var a1 := TAU * (k + 1) / SIDES
			var d0 := side * cos(a0) + side2 * sin(a0)
			var d1 := side * cos(a1) + side2 * sin(a1)
			var p00 := dir * y0 + d0 * r0
			var p01 := dir * y0 + d1 * r0
			var p10 := dir * y1 + d0 * r1
			var p11 := dir * y1 + d1 * r1
			for v in [p00, p10, p11, p00, p11, p01]:
				st.set_uv(Vector2(uvx, (v as Vector3).dot(dir)))
				st.add_vertex(xf * v)


static func _ellipsoid(st: SurfaceTool, c: Vector3, radii: Vector3, level: int, xf := Transform3D.IDENTITY, uvx := 0.0) -> void:
	var sphere: Array = PlantMeshes.icosphere(level)
	var verts: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	for f in range(0, faces.size(), 3):
		for j in 3:
			var u := verts[faces[f + j]]
			st.set_uv(Vector2(uvx, u.y * 0.5 + 0.5))
			st.add_vertex(xf * (c + u * radii))


## A twisted pod (umbrella thorn): a tube wound one and a half turns.
static func _coil(st: SurfaceTool) -> void:
	var n := 18
	var ring := 5
	var rings: Array = []
	for i in n + 1:
		var t := float(i) / n
		var a := t * TAU * 1.5
		var c := Vector3(cos(a) * 0.28, -t * 0.9, sin(a) * 0.28)
		var r := 0.07 * sin(PI * clampf(t * 1.1, 0.05, 1.0)) + 0.02
		var pts: Array = []
		for k in ring:
			var b := TAU * k / ring
			var out := Vector3(cos(a), 0, sin(a))
			pts.append(c + (out * cos(b) + Vector3.UP * sin(b)) * r)
		rings.append(pts)
	for i in n:
		for k in ring:
			var k1 := (k + 1) % ring
			for v in [rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k], rings[i + 1][k1], rings[i][k1]]:
				st.set_uv(Vector2(0, 0))
				st.add_vertex(v)


## A samara's wing: a flat blade from `root` out along `along`.
static func _blade(st: SurfaceTool, root: Vector3, along: Vector3, length: float) -> void:
	var dir := along.normalized()
	var w := Vector3(0, 0, 0.12)
	var tip := root + Vector3.UP * length + dir * 0.1
	for v in [root - w * 0.3, tip - w, tip + w, root - w * 0.3, tip + w, root + w * 0.3]:
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v)


## A star fruit: five ribs down its length.
static func _star_fruit(st: SurfaceTool) -> void:
	var n := 10
	var levels := [0.0, 0.2, 0.5, 0.8, 1.0]
	var widths := [0.05, 0.6, 1.0, 0.7, 0.05]
	var rings: Array = []
	for li in levels.size():
		var pts: Array = []
		for k in n:
			var a := TAU * k / n
			var r: float = (0.28 if k % 2 == 0 else 0.12) * float(widths[li])
			pts.append(Vector3(cos(a) * r, -float(levels[li]) - 0.05, sin(a) * r))
		rings.append(pts)
	for li in levels.size() - 1:
		for k in n:
			var k1 := (k + 1) % n
			for v in [rings[li][k], rings[li + 1][k], rings[li + 1][k1], rings[li][k], rings[li + 1][k1], rings[li][k1]]:
				st.set_uv(Vector2(0, 0))
				st.add_vertex(v)

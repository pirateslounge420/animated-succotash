class_name RuinBuilder
## Builds a ruin (Ruins.find() site) as one low-poly mesh plus collision,
## with a plain-box far LOD past LOD_M.
##
## Everything is stacked stone blocks, bevelled, worn and irregular, so
## collapse comes for free: each
## column of a wall or tower stops at its own jagged height, breaches drop
## whole stretches to stumps, window and door gaps are missing blocks, and
## fallen blocks lie in rubble at the foot. Moss creeps over every upward
## face and the lowest courses, ivy hangs in strands from broken tops, and
## vertex alpha marks moss for the night glow (shaders/ruin.gdshader).
##
## Silhouettes carry: castles ring a hilltop with a tall keep, towers stand
## 14-22 m, aqueducts stride level across the ground on tall piers.
## Other countries have their own (Ruins): igloo clusters in snow, a
## treehouse village of platforms and rope bridges on giant jungle trees,
## a boardwalk on stilts out to a cabin in the marsh. Ruins
## are built up to ~2.6 km out, beyond the terrain chunks, so their bases
## run down into a buried mound or deep footings and never float over the
## coarser far terrain.

const COURSE_M := 0.85
# Weathered grey-blue stone (the references' castles), darker than bare
# rock so walls hold their shape in full sun.
const STONES := [Color(0.48, 0.48, 0.47), Color(0.42, 0.43, 0.45), Color(0.52, 0.51, 0.47), Color(0.38, 0.39, 0.41), Color(0.47, 0.47, 0.5)]
const MOSS := Color(0.2, 0.44, 0.14)
const IVY := Color(0.1, 0.32, 0.12)
const IVY_LIGHT := Color(0.2, 0.46, 0.16)
const EARTH := Color(0.36, 0.3, 0.22)
const GRASS := Color(0.3, 0.52, 0.2)

## Share of ruins where survivors of the old civilization have camped:
## tepees and lean-tos of poles and woven vines, and a cold fire ring.
const CAMP_CHANCE := 0.35
const WOOD := Color(0.4, 0.3, 0.2)
const HIDE := Color(0.55, 0.42, 0.3)
const OLD_WOOD := Color(0.36, 0.32, 0.26) # weathered grey-brown planks
const BARK := Color(0.34, 0.3, 0.24)
const JUNGLE_LEAF := Color(0.16, 0.42, 0.16)
const THATCH := Color(0.55, 0.47, 0.28)
const SNOW := Color(0.7, 0.77, 0.86) # packed snow blocks, cooler than a snowfield so they read
const ROPE := Color(0.42, 0.36, 0.24)

## Distance where the drawn blocks give way to the plain-box LOD, and the
## hysteresis round it.
const LOD_M := 150.0
const LOD_MARGIN_M := 15.0

## Surface materials (vertex UV.x; shaders/ruin.gdshader picks the
## texture): set `mat` before adding a part.
const STONE_M := 0
const WOOD_M := 1
const SNOW_M := 2
const THATCH_M := 3
const LEAF_M := 4
const HIDE_M := 5

static var _material: ShaderMaterial

var map: PlanetData
var site: Dictionary
var rng := RandomNumberGenerator.new()
var up: Vector3
var ex: Vector3 # local +x
var ez: Vector3 # local +z (right-handed with ex, up)
var base_e := 0.0
## 0-1 how damp the site is (blueprint moisture): dry ruins are bare
## stone, wet ones are thick with moss and draped in ivy.
var wet := 0.5

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _m := PackedVector2Array() # material per vertex (x)
## The material new geometry gets.
var mat := STONE_M
## Collision triangles: plain boxes, much cheaper than the drawn blocks.
var _cv := PackedVector3Array()
## Far LOD (past LOD_M): plain boxes too, in the blocks' face colors, and
## the mound as is; no ivy.
var _lv := PackedVector3Array()
var _ln := PackedVector3Array()
var _lc := PackedColorArray()
var _lm := PackedVector2Array()
## Camp shelters, [local center (on the ground), radius, height]: standing
## inside one keeps the rain off (Landmarks.sheltered_at).
var _shelters: Array = []
var _tower_r := 0.0
var _stub_angle := 0.0
## Where a living camp's fire goes (local, on the ground or floor), if the
## ruin is inhabited (Ruins.inhabited()); Camps builds it.
var _camp_spot := Vector3.ZERO


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/ruin.gdshader")
		Look.register(_material)
	return _material


## Build a ruin's geometry. Pure and thread-safe (reads the planet data
## only), so Landmarks runs it on a worker thread; make_node() turns the
## result into nodes on the main thread.
static func compute(p_map: PlanetData, p_site: Dictionary) -> Dictionary:
	var b := RuinBuilder.new()
	b.map = p_map
	b.site = p_site
	b.rng.seed = p_site.seed
	b.up = p_site.dir
	var a: float = p_site.heading + PI * 0.5
	b.ex = CubeSphere.north(b.up) * cos(a) + CubeSphere.east(b.up) * sin(a)
	b.ez = b.ex.cross(b.up).normalized()
	b.base_e = p_map.terrain.elevation(b.up, true)
	b.wet = smoothstep(0.2, 0.8, p_map.sample(p_map.moisture, b.up))
	match p_site.kind:
		Ruins.Kind.CASTLE:
			b._castle()
		Ruins.Kind.TOWER:
			b._lone_tower()
		Ruins.Kind.AQUEDUCT:
			b._aqueduct()
		Ruins.Kind.IGLOO:
			b._igloos()
		Ruins.Kind.TREEHOUSE:
			b._treehouse()
		Ruins.Kind.BOARDWALK:
			b._boardwalk()
	# Its own roll, so a camp never changes the ruin itself. (Only the stone
	# ruins: the others are dwellings already.)
	var camp_rng := RandomNumberGenerator.new()
	camp_rng.seed = hash([p_site.seed, "camp"])
	var survivors: bool = p_site.kind <= Ruins.Kind.AQUEDUCT and camp_rng.randf() < CAMP_CHANCE
	if survivors:
		b.rng = camp_rng
		b._camp(p_site.kind)
	elif p_site.kind <= Ruins.Kind.AQUEDUCT:
		b._stone_camp_spot()
	return {"site": p_site, "v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv,
		"lv": b._lv, "ln": b._ln, "lc": b._lc, "lm": b._lm, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e,
		"shelters": b._shelters, "camp_spot": b._camp_spot}


## A lone rock mesh (den stones and the like): a boulder, or a bevelled
## block when `block` is set. Drawn with the ruin material.
static func rock_mesh(size: Vector3, p_seed: int, col: Color, block := false) -> ArrayMesh:
	var b := RuinBuilder.new()
	b.rng.seed = p_seed
	if block:
		b.box(Transform3D(), size, col, 0.2, 0.14, 0.08)
	else:
		b.boulder(Vector3.ZERO, size * 0.5, Basis(), col, 0.35)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b._v
	arrays[Mesh.ARRAY_NORMAL] = b._n
	arrays[Mesh.ARRAY_COLOR] = b._c
	arrays[Mesh.ARRAY_TEX_UV] = b._m
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Main thread: mesh and collision (see placement()).
static func make_node(data: Dictionary, world: Node) -> Node3D:
	var site: Dictionary = data.site
	var root := Node3D.new()
	root.name = Ruins.KIND_NAMES[site.kind].replace(" ", "")
	root.set_meta("site", site)
	root.set_meta("shelters", data.get("shelters", []))
	root.set_meta("camp_spot", data.get("camp_spot", Vector3.ZERO))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_TEX_UV] = data.m
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material()
	mi.visibility_range_end = LOD_M
	mi.visibility_range_end_margin = LOD_MARGIN_M
	root.add_child(mi)
	arrays[Mesh.ARRAY_VERTEX] = data.lv
	arrays[Mesh.ARRAY_NORMAL] = data.ln
	arrays[Mesh.ARRAY_COLOR] = data.lc
	arrays[Mesh.ARRAY_TEX_UV] = data.lm
	var far_mesh := ArrayMesh.new()
	far_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var far := MeshInstance3D.new()
	far.name = "FarLOD"
	far.mesh = far_mesh
	far.material_override = material()
	far.visibility_range_begin = LOD_M
	far.visibility_range_begin_margin = LOD_MARGIN_M
	root.add_child(far)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.cv)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	return root


## Where the node goes, in scene space (set it after adding the node to
## the tree: its parent may have been shifted by the floating origin).
static func placement(data: Dictionary, world: Node) -> Transform3D:
	return Transform3D(Basis(data.ex, data.up, data.ez), world.to_scene(data.up, PlanetConst.RADIUS_M + data.base_e))


## Ground height at local (x, z), relative to the ruin's origin.
func ground(x: float, z: float) -> float:
	var d := (up + (ex * x + ez * z) / PlanetConst.RADIUS_M).normalized()
	return map.terrain.elevation(d, true) - base_e


# --- Primitives ----------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	_v.append_array([a, b, c])
	_n.append_array([nrm, nrm, nrm])
	_c.append_array([col, col, col])
	_add_mat()


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)


## A quad whose normal points away from `inside` (winding fixed to match).
func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot((a + c) * 0.5 - inside) < 0.0:
		_quad(a, d, c, b, col)
	else:
		_quad(a, b, c, d, col)


## A box. `moss` (0-1) greens the top face fully and the sides partly;
## the same value goes to vertex alpha for the glow. Edges are bevelled
## by `bevel` m, and each chamfer's two sides keep their faces' normals,
## so shading rolls smoothly over the edge like worn stone. Corners are
## jittered by up to `wear` m.
func box(xf: Transform3D, size: Vector3, col: Color, moss: float, bevel := 0.09, wear := 0.05) -> void:
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.45)
	var top := col.lerp(MOSS, moss)
	top.a = moss
	var side := col.lerp(MOSS, moss * 0.3)
	side.a = moss * 0.4
	var bottom := col.darkened(0.3)
	bottom.a = 0.0
	var o := xf.origin
	var jit: Array[Vector3] = []
	for i in 8:
		jit.append(Vector3(rng.randf_range(-wear, wear), rng.randf_range(-wear, wear), rng.randf_range(-wear, wear)))
	# Vertex (corner i, face axis a): the corner pulled in by b along the
	# other two axes.
	var vert := func(i: int, a: int) -> Vector3:
		var sg := Vector3(1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0)
		var p := sg * h + jit[i]
		for k in 3:
			if k != a:
				p[k] -= sg[k] * b
		return xf * p
	var fnorm := func(i: int, a: int) -> Vector3:
		var nv := Vector3.ZERO
		nv[a] = 1.0 if (i >> a) & 1 else -1.0
		return (xf.basis * nv).normalized()
	var face_col := func(i: int, a: int) -> Color:
		if a == 1:
			return top if i & 2 else bottom
		return side
	# Faces.
	for a in 3:
		for sgn in [0, 1]:
			# This face's 4 corners, in order round it.
			var u := (a + 1) % 3
			var w := (a + 2) % 3
			var ring: Array[int] = []
			for q in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				ring.append((sgn << a) | (q[0] << u) | (q[1] << w))
			var ps: Array[Vector3] = []
			var ns: Array[Vector3] = []
			var cs: Array[Color] = []
			for i in ring:
				ps.append(vert.call(i, a))
				ns.append(fnorm.call(i, a))
				cs.append(face_col.call(i, a))
			_quad_n(ps, ns, cs, o)
	# Edge chamfers: between face (a, sa) and face (c, sc), along axis k.
	for a in 3:
		for c in range(a + 1, 3):
			var k := 3 - a - c
			for sa in [0, 1]:
				for sc in [0, 1]:
					var i0: int = (sa << a) | (sc << c)
					var i1: int = i0 | (1 << k)
					var ps: Array[Vector3] = [vert.call(i0, a), vert.call(i1, a), vert.call(i1, c), vert.call(i0, c)]
					var ns: Array[Vector3] = [fnorm.call(i0, a), fnorm.call(i1, a), fnorm.call(i1, c), fnorm.call(i0, c)]
					var cs: Array[Color] = [face_col.call(i0, a), face_col.call(i1, a), face_col.call(i1, c), face_col.call(i0, c)]
					_quad_n(ps, ns, cs, o)
	# Corner triangles.
	for i in 8:
		var ps: Array[Vector3] = [vert.call(i, 0), vert.call(i, 1), vert.call(i, 2)]
		var ns: Array[Vector3] = [fnorm.call(i, 0), fnorm.call(i, 1), fnorm.call(i, 2)]
		var cs: Array[Color] = [face_col.call(i, 0), face_col.call(i, 1), face_col.call(i, 2)]
		_tri_n(ps[0], ps[1], ps[2], ns[0], ns[1], ns[2], cs[0], cs[1], cs[2], o)
	_collision_box(xf, h)
	_lod_box(xf, h, top, side, bottom)


## A quad (4 corners in order round it) with per-vertex normals and
## colors, wound to face away from `inside`.
func _quad_n(ps: Array[Vector3], ns: Array[Vector3], cs: Array[Color], inside: Vector3) -> void:
	_tri_n(ps[0], ps[1], ps[2], ns[0], ns[1], ns[2], cs[0], cs[1], cs[2], inside)
	_tri_n(ps[0], ps[2], ps[3], ns[0], ns[2], ns[3], cs[0], cs[2], cs[3], inside)


func _tri_n(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color, inside: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) < 0.0:
		_v.append_array([a, c, b])
		_n.append_array([na, nc, nb])
		_c.append_array([ca, cc, cb])
	else:
		_v.append_array([a, b, c])
		_n.append_array([na, nb, nc])
		_c.append_array([ca, cb, cc])
	_add_mat()


func _add_mat() -> void:
	var m := Vector2(mat, 0.0)
	_m.append_array([m, m, m])


## Smooth shading for everything added since `start`: vertices at the
## same spot share the average of their faces' normals.
func _smooth_from(start: int) -> void:
	var acc := {}
	for t in range(start, _v.size(), 3):
		var fn := (_v[t + 1] - _v[t]).cross(_v[t + 2] - _v[t])
		for k in 3:
			var key := Vector3i(_v[t + k] * 100.0)
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	for i in range(start, _v.size()):
		var sum: Vector3 = acc[Vector3i(_v[i] * 100.0)]
		if sum.length_squared() > 1e-10:
			_n[i] = sum.normalized()


func _collision_box(xf: Transform3D, h: Vector3) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_cv.append_array([p[f[0]], p[f[1]], p[f[2]], p[f[0]], p[f[2]], p[f[3]]])


## A far-LOD box: 12 flat-shaded triangles, top/side/bottom colored.
func _lod_box(xf: Transform3D, h: Vector3, top: Color, side: Color, bottom: Color) -> void:
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	# Faces -z, +z, -y, +y, -x, +x.
	var axes := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for k in 6:
		var f: Array = faces[k]
		var nrm: Vector3 = (xf.basis * axes[k]).normalized()
		var col := top if k == 3 else (bottom if k == 2 else side)
		for t in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = p[f[t[0]]]
			var b: Vector3 = p[f[t[1]]]
			var c: Vector3 = p[f[t[2]]]
			if (b - a).cross(c - a).dot(nrm) < 0.0:
				_lv.append_array([a, c, b])
			else:
				_lv.append_array([a, b, c])
			_ln.append_array([nrm, nrm, nrm])
			_lc.append_array([col, col, col])
			_lm.append_array([Vector2(mat, 0.0), Vector2(mat, 0.0), Vector2(mat, 0.0)])


## A rough stone: a noise-displaced icosphere, smooth shaded, mossy on top.
func boulder(center: Vector3, radii: Vector3, basis: Basis, col: Color, moss: float) -> void:
	var sphere: Array = PlantMeshes.icosphere(1)
	var verts: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var ph := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for u in verts:
		var bump := 0.16 * sin(u.x * 2.3 + ph.x) * sin(u.z * 2.9 + ph.y) + 0.08 * sin(u.y * 5.1 + ph.z)
		pos.append(center + basis * (u * radii * (1.0 + bump)))
	for f in range(0, faces.size(), 3):
		var fn := (pos[faces[f + 1]] - pos[faces[f]]).cross(pos[faces[f + 2]] - pos[faces[f]])
		for k in 3:
			nrm[faces[f + k]] += fn
	var cols := PackedColorArray()
	for i in verts.size():
		nrm[i] = nrm[i].normalized()
		var m := moss * smoothstep(0.1, 0.7, nrm[i].y)
		var c := col.lerp(MOSS, m)
		c.a = m
		cols.append(c)
	for f in range(0, faces.size(), 3):
		var a := faces[f]
		var b2 := faces[f + 1]
		var d := faces[f + 2]
		_tri_n(pos[a], pos[b2], pos[d], nrm[a], nrm[b2], nrm[d], cols[a], cols[b2], cols[d], center)
	_collision_box(Transform3D(basis, center), radii * 0.8)
	var top := col.lerp(MOSS, moss)
	top.a = moss
	var side := col.lerp(MOSS, moss * 0.2)
	side.a = moss * 0.2
	_lod_box(Transform3D(basis, center), radii * 0.85, top, side, col)


## A block at a position, its length (size.x) running along `dir`
## (horizontal), with a little crumble. `above` (m above the ground) bakes
## ambient occlusion into the lowest courses.
func block(center: Vector3, dir: Vector3, size: Vector3, moss: float, wobble := 0.04, above := 99.0) -> void:
	var x := dir.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var basis := Basis(x, Vector3.UP, z)
	basis = basis.rotated(Vector3.UP, rng.randf_range(-wobble, wobble)).rotated(x, rng.randf_range(-wobble, wobble) * 0.5)
	var col: Color = STONES[rng.randi() % STONES.size()]
	col = col.lightened(rng.randf_range(-0.06, 0.06))
	col = col.darkened(0.4 * exp(-maxf(above, 0.0) / 1.3))
	# Irregular masonry: blocks a little longer or shorter, shallower or
	# lower than the course, and nudged along it, so joints don't line up.
	var sz := size * Vector3(rng.randf_range(0.82, 1.1), rng.randf_range(0.9, 1.0), rng.randf_range(0.92, 1.04))
	var c := center + x * rng.randf_range(-0.12, 0.12) * size.x
	box(Transform3D(basis, c), sz, col, _growth(moss), rng.randf_range(0.06, 0.13), rng.randf_range(0.02, 0.07))


## Moss amount for this site: sparse where it's dry, thick where it's wet.
func _growth(moss: float) -> float:
	return clampf(moss * (0.3 + 1.1 * wet), 0.0, 1.0)


## Ivy hanging from `top` down a face with outward normal `out`: often
## missing on dry ruins, longer and doubled into curtains on wet ones.
func ivy(top: Vector3, out: Vector3, length: float) -> void:
	if rng.randf() > 0.3 + 0.7 * wet:
		return
	length *= 0.7 + 0.6 * wet
	_ivy_strand(top, out, length)
	var along := Vector3.UP.cross(out).normalized()
	for k in 2:
		if rng.randf() < wet * 0.6:
			_ivy_strand(top + along * rng.randf_range(-1.2, 1.2), out, length * rng.randf_range(0.5, 1.0))


func _ivy_strand(top: Vector3, out: Vector3, length: float) -> void:
	var side := Vector3.UP.cross(out).normalized() * rng.randf_range(0.25, 0.45)
	var o := out.normalized() * 0.08
	var steps := maxi(1, int(length / 0.8))
	var prev_l := top + o - side
	var prev_r := top + o + side
	for i in steps:
		var y := -length * float(i + 1) / steps
		var sway := side * rng.randf_range(-0.4, 0.4)
		var taper := 1.0 - 0.6 * float(i + 1) / steps
		var l := top + o + Vector3(0, y, 0) - side * taper + sway
		var r := top + o + Vector3(0, y, 0) + side * taper + sway
		var col := IVY.lerp(IVY_LIGHT, rng.randf())
		col.a = 1.0
		_quad(prev_l, prev_r, r, l, col)
		# A leaf sticking out.
		if rng.randf() < 0.6:
			var c := (prev_l + r) * 0.5 + o
			var s := rng.randf_range(0.18, 0.3)
			_tri(c, c + out.normalized() * s + Vector3(0, s, 0), c + side.normalized() * s, col.lightened(0.1))
		prev_l = l
		prev_r = r


## Fallen blocks strewn around a point.
func rubble(center: Vector3, spread: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		var size := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var col: Color = STONES[rng.randi() % STONES.size()]
		var p := Vector3(x, ground(x, z) + size.y * 0.3, z)
		if rng.randf() < 0.55:
			# A tumbled block, edges knocked round.
			box(Transform3D(basis, p), size, col, _growth(rng.randf_range(0.3, 0.9)), 0.16, 0.1)
		else:
			boulder(p, size * 0.55, basis, col.darkened(0.05), _growth(rng.randf_range(0.3, 0.9)))


# --- Walls and towers ------------------------------------------------------------

## A straight wall of stacked blocks from a to b (local xz), `height` tall.
## Breaches: [[t0, t1], ...] stretches (0-1 along the wall) collapsed to
## stumps. Returns the number of fallen courses (for rubble).
func wall(a: Vector2, b: Vector2, height: float, thick: float, breaches: Array, ivy_chance := 0.3) -> int:
	var along := b - a
	var length := along.length()
	var dir3 := Vector3(along.x, 0, along.y) / length
	var out := Vector3(dir3.z, 0, -dir3.x)
	var cols := maxi(1, int(ceil(length / 1.5)))
	var bw := length / cols
	var fallen := 0
	for i in cols:
		var t := (i + 0.5) / cols
		var p := a + along * t
		var g := ground(p.x, p.y)
		var h := height - rng.randf_range(0.0, 2.2) * COURSE_M
		for br in breaches:
			if t > br[0] and t < br[1]:
				# V-shaped gap: full height at its edges, stumps in the middle.
				var depth := minf(t - br[0], br[1] - t) / maxf(br[1] - br[0], 0.01) * 2.0
				h = minf(h, lerpf(height, rng.randf_range(0.0, 1.2), smoothstep(0.0, 0.6, depth)))
		h = maxf(h, 0.0)
		fallen += int((height - h) / COURSE_M)
		# Footing down into the ground, then courses.
		block(Vector3(p.x, g - 1.2, p.y), dir3, Vector3(bw, 1.6, thick * 1.1), 0.0, 0.0)
		var y := g - 0.4
		var k := 0
		while y + COURSE_M * 0.5 < g + h:
			if y > g + 1.0 and rng.randf() < 0.04:
				y += COURSE_M
				k += 1
				continue
			var moss := 0.15 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
			block(Vector3(p.x, y + COURSE_M * 0.5, p.y), dir3, Vector3(bw * 0.97, COURSE_M * 0.96, thick), moss, 0.04, y - g)
			y += COURSE_M
			k += 1
		if h > 1.0 and rng.randf() < ivy_chance:
			var top := Vector3(p.x, g + h, p.y)
			ivy(top + out * thick * 0.5, out, rng.randf_range(1.2, minf(5.0, h)))
			if rng.randf() < 0.5:
				ivy(top - out * thick * 0.5, -out, rng.randf_range(1.0, minf(4.0, h)))
	return fallen


## A round tower of block rings, `height` tall, with one side slumped.
func round_tower(center: Vector2, radius: float, height: float, door_angle: float) -> void:
	var segs := maxi(8, int(TAU * radius / 1.4))
	var slump_a := rng.randf() * TAU
	var slump := rng.randf_range(0.2, 0.5)
	var fallen := 0
	for i in segs:
		var a := TAU * i / segs
		var p := center + Vector2(cos(a), sin(a)) * radius
		var tangent := Vector3(-sin(a), 0, cos(a))
		var out := Vector3(cos(a), 0, sin(a))
		var g := ground(p.x, p.y)
		var closeness := (cos(a - slump_a) + 1.0) * 0.5
		var h := height * (1.0 - slump * smoothstep(0.4, 1.0, closeness)) - rng.randf_range(0.0, 2.5)
		fallen += int((height - h) / COURSE_M)
		var bw := TAU * radius / segs
		block(Vector3(p.x, g - 1.2, p.y), tangent, Vector3(bw * 1.05, 1.6, 1.5), 0.0, 0.0)
		var y := g - 0.4
		var door := absf(angle_difference(a, door_angle)) < 0.35
		var window_row := rng.randi_range(6, 10)
		while y + COURSE_M * 0.5 < g + h:
			var course := int((y - g) / COURSE_M)
			var gap := (door and y < g + 2.4) or (course % window_row == 0 and course > 3 and rng.randf() < 0.35)
			if not gap:
				var moss := 0.12 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
				block(Vector3(p.x, y + COURSE_M * 0.5, p.y), tangent, Vector3(bw * 1.02, COURSE_M * 0.96, 1.3), moss, 0.04, y - g)
			y += COURSE_M
		if h > 2.0 and rng.randf() < 0.35:
			ivy(Vector3(p.x, g + h, p.y) + out * 0.65, out, rng.randf_range(2.0, minf(7.0, h)))
	rubble(Vector3(center.x + cos(slump_a) * (radius + 2.0), 0, center.y + sin(slump_a) * (radius + 2.0)), 3.5, mini(fallen / 6, 16))


## A buried earth mound (motte) under a structure: keeps it from floating
## over the coarse far terrain and gives castles their raised hilltop.
func mound(radius_top: float, radius_bottom: float, depth: float, rise: float) -> void:
	var sides := 12
	var top_pts: Array = []
	var bot_pts: Array = []
	for i in sides:
		var a := TAU * i / sides + rng.randf_range(-0.08, 0.08)
		var rt := radius_top * rng.randf_range(0.92, 1.05)
		top_pts.append(Vector3(cos(a) * rt, rise + rng.randf_range(-0.3, 0.2), sin(a) * rt))
		bot_pts.append(Vector3(cos(a) * radius_bottom, -depth, sin(a) * radius_bottom))
	# Match the local ground so the motte reads as part of the hill.
	var grass := TerrainChunk._biome_blend(map, up).lerp(GRASS, 0.15)
	grass.a = 0.05 # hardly any glowing moss on the grassy motte
	var earth := grass.darkened(0.3).lerp(EARTH, 0.4)
	earth.a = 0.0
	var c := Vector3(0, rise, 0)
	var inside := Vector3(0, -depth * 0.5, 0)
	var start := _v.size()
	for i in sides:
		var j := (i + 1) % sides
		_face(c, top_pts[j], top_pts[i], top_pts[i], grass, inside)
		_face(top_pts[i], top_pts[j], bot_pts[j], bot_pts[i], earth.lerp(grass, 0.25), inside)
	_smooth_from(start)
	_cv.append_array(_v.slice(start))
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))


# --- Structures -------------------------------------------------------------------

func _castle() -> void:
	mound(24.0, 36.0, 32.0, 0.35)
	# Curtain wall: an octagon with two breaches and a gate gap.
	var r := 17.0
	var pts: Array = []
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	var breach_sides := [rng.randi() % 8, rng.randi() % 8]
	var gate := rng.randi() % 8
	var fallen := 0
	for i in 8:
		var breaches: Array = []
		if i in breach_sides:
			var s := rng.randf_range(0.15, 0.55)
			breaches.append([s, s + rng.randf_range(0.25, 0.4)])
		if i == gate:
			breaches.append([0.4, 0.6])
		fallen += wall(pts[i], pts[(i + 1) % 8], rng.randf_range(6.0, 7.5), 1.6, breaches)
		if i in breach_sides:
			var mid: Vector2 = (pts[i] + pts[(i + 1) % 8]) * 0.5
			rubble(Vector3(mid.x * 1.12, 0, mid.y * 1.12), 4.0, 12)
	# Corner towers on alternate corners.
	for i in range(0, 8, 2):
		round_tower(pts[i], 2.8, rng.randf_range(8.5, 11.5), rng.randf() * TAU)
	# The keep: a tall square tower, one corner fallen in.
	var k := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
	var hs := 4.5
	var keep_h := rng.randf_range(15.0, 19.0)
	var corners := [k + Vector2(-hs, -hs), k + Vector2(hs, -hs), k + Vector2(hs, hs), k + Vector2(-hs, hs)]
	var broken := rng.randi() % 4
	for i in 4:
		var br: Array = []
		if i == broken:
			br = [[0.55, 1.05]]
		elif i == (broken + 3) % 4:
			br = [[-0.05, 0.35]]
		wall(corners[i], corners[(i + 1) % 4], keep_h, 1.3, br, 0.45)
	var fall_corner: Vector2 = corners[(broken + 1) % 4]
	rubble(Vector3(fall_corner.x * 1.3, 0, fall_corner.y * 1.3), 5.0, 22)
	rubble(Vector3.ZERO, 14.0, mini(fallen / 4, 30))


func _lone_tower() -> void:
	mound(6.0, 10.0, 14.0, 0.0)
	_tower_r = rng.randf_range(3.2, 4.2)
	round_tower(Vector2.ZERO, _tower_r, rng.randf_range(14.0, 22.0), rng.randf() * TAU)
	# A stump of an old wall running off from it.
	var a := rng.randf() * TAU
	_stub_angle = a
	var end := Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 16.0)
	wall(Vector2(cos(a), sin(a)) * 3.8, end, rng.randf_range(2.0, 4.0), 1.2, [[0.5, 1.1]], 0.4)


## Arches striding level across the ground on piers; some spans fallen.
func _aqueduct() -> void:
	var length: float = site.length_m
	var spacing := 7.5
	var piers := int(length / spacing) + 1
	var x0 := -spacing * (piers - 1) * 0.5
	var top := -INF
	for i in piers:
		top = maxf(top, ground(x0 + i * spacing, 0.0))
	top += rng.randf_range(9.0, 12.0)
	var spring := top - 3.6
	var fallen_span := []
	for i in piers - 1:
		fallen_span.append(rng.randf() < 0.22 or i == 0 and rng.randf() < 0.5 or i == piers - 2 and rng.randf() < 0.5)
	var along := Vector3(1, 0, 0)
	for i in piers:
		var x := x0 + i * spacing
		var g := ground(x, 0.0)
		# Deep footing (hidden underground next to the chunks; keeps the
		# silhouette grounded against the coarser far terrain).
		box(Transform3D(Basis.IDENTITY, Vector3(x, g - 18.0, 0)), Vector3(2.0, 34.0, 2.4), STONES[1], 0.0)
		var both_fallen: bool = (i == 0 or fallen_span[i - 1]) and (i == piers - 1 or fallen_span[mini(i, piers - 2)])
		var h := spring - g + 0.4
		if both_fallen:
			h *= rng.randf_range(0.2, 0.7)
		var y := g - 0.4
		while y < g + h:
			var moss := 0.1 + 0.5 * exp(-(y - g) / 2.0) + rng.randf_range(0.0, 0.25)
			block(Vector3(x, y + COURSE_M * 0.5, 0), along, Vector3(1.8, COURSE_M * 0.96, 2.2), moss, 0.03, y - g)
			y += COURSE_M
		if both_fallen:
			rubble(Vector3(x + rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 3.0, 8)
	# Arches, spandrels and the channel on top.
	for i in piers - 1:
		var xa := x0 + i * spacing + 0.9
		var xb := x0 + (i + 1) * spacing - 0.9
		if fallen_span[i]:
			# Broken arch stubs on both sides.
			for s in [0, 1]:
				var xs: float = xa if s == 0 else xb
				var dirx := 1.0 if s == 0 else -1.0
				for k in rng.randi_range(1, 2):
					var ang := PI * 0.5 * (k + 0.5) / 4.0
					var rr := (xb - xa) * 0.5
					var cx := xs + dirx * (rr - cos(ang) * rr)
					block(Vector3(cx, spring + sin(ang) * rr, 0), along, Vector3(0.9, 0.7, 2.1), 0.5)
			continue
		var cx := (xa + xb) * 0.5
		var rr := (xb - xa) * 0.5
		var stones := 9
		for k in stones:
			var ang := PI * (k + 0.5) / stones
			var p := Vector3(cx - cos(ang) * rr, spring + sin(ang) * rr, 0)
			var tangent := Vector3(sin(ang), cos(ang), 0)
			var basis := Basis(tangent, tangent.cross(Vector3(0, 0, 1)).normalized() * -1.0, Vector3(0, 0, 1)).orthonormalized()
			var col: Color = STONES[rng.randi() % STONES.size()]
			box(Transform3D(basis, p), Vector3(rr * PI / stones * 1.05, 0.7, 2.1), col, 0.35)
		# Spandrel courses from the arch crown up to the deck.
		var y := spring + rr * 0.55
		while y < top - 0.5:
			for part in [xa + (xb - xa) * 0.18, xb - (xb - xa) * 0.18, cx]:
				if part == cx and y < spring + rr + 0.2:
					continue
				block(Vector3(part, y + COURSE_M * 0.5, 0), along, Vector3((xb - xa) * 0.36, COURSE_M * 0.96, 2.2), 0.3)
			y += COURSE_M
		# Channel: floor and two low side walls, mossy and ivy-draped.
		block(Vector3(cx, top, 0), along, Vector3(spacing, 0.5, 2.4), 0.8, 0.02)
		for sz in [-1.0, 1.0]:
			if rng.randf() < 0.85:
				block(Vector3(cx, top + 0.55, sz * 1.0), along, Vector3(spacing * rng.randf_range(0.6, 1.0), 0.6, 0.4), 0.9, 0.05)
			if rng.randf() < 0.55:
				ivy(Vector3(cx + rng.randf_range(-2.5, 2.5), top + 0.2, sz * 1.25), Vector3(0, 0, sz), rng.randf_range(2.0, 6.0))


# --- Camps ----------------------------------------------------------------------

## Where a living camp would sit in a stone ruin without a survivors'
## camp: in a castle's courtyard, at a tower's foot away from its wall
## stub, under one of an aqueduct's arches.
func _stone_camp_spot() -> void:
	var p := Vector2.ZERO
	var floor_y := 0.0
	match site.kind:
		Ruins.Kind.CASTLE:
			var a := rng.randf() * TAU
			p = Vector2(cos(a), sin(a)) * 10.5
			floor_y = 0.35
		Ruins.Kind.TOWER:
			var a := _stub_angle + PI + rng.randf_range(-0.8, 0.8)
			p = Vector2(cos(a), sin(a)) * (_tower_r + 4.5)
		Ruins.Kind.AQUEDUCT:
			var length: float = site.length_m
			var spacing := 7.5
			var piers := int(length / spacing) + 1
			var x0 := -spacing * (piers - 1) * 0.5
			p = Vector2(x0 + (rng.randi() % (piers - 1) + 0.5) * spacing, 0.0)
	_camp_spot = Vector3(p.x, maxf(ground(p.x, p.y), floor_y), p.y)


## Survivors' camp in the ruin: one to three shelters (tepees or lean-tos)
## in a castle's courtyard, at a tower's foot (away from its wall stub) or
## under an aqueduct's arches, and a cold fire ring.
func _camp(kind: int) -> void:
	var spots: Array[Vector2] = []
	var count := rng.randi_range(1, 3)
	match kind:
		Ruins.Kind.CASTLE:
			var a0 := rng.randf() * TAU
			for i in count:
				var a := a0 + i * rng.randf_range(0.7, 1.1)
				spots.append(Vector2(cos(a), sin(a)) * rng.randf_range(11.5, 12.5))
		Ruins.Kind.TOWER:
			count = mini(count, 2)
			for i in count:
				var a := _stub_angle + PI + (i - 0.5 * (count - 1)) * 0.9
				spots.append(Vector2(cos(a), sin(a)) * (_tower_r + 3.6))
		Ruins.Kind.AQUEDUCT:
			var length: float = site.length_m
			var spacing := 7.5
			var piers := int(length / spacing) + 1
			var x0 := -spacing * (piers - 1) * 0.5
			for i in mini(count, piers - 1):
				var span := rng.randi() % (piers - 1)
				spots.append(Vector2(x0 + (span + 0.5) * spacing, rng.randf_range(-1.0, 1.0)))
	var floor_y := 0.35 if kind == Ruins.Kind.CASTLE else 0.0
	for i in spots.size():
		var p := spots[i]
		if kind == Ruins.Kind.AQUEDUCT or rng.randf() < 0.65:
			tepee(p, rng.randf_range(1.4, 1.8), rng.randf_range(2.8, 3.5), floor_y)
		else:
			lean_to(p, rng.randf() * TAU, floor_y)
	# The cold fire ring beside the first shelter: along the courtyard or
	# round the tower (clear of keep and walls), across the aqueduct's line
	# (clear of the piers).
	var s0 := spots[0]
	var beside := Vector2(0.0, 2.8 * (1.0 if s0.y <= 0.0 else -1.0)) if kind == Ruins.Kind.AQUEDUCT else Vector2(-s0.y, s0.x).normalized() * 3.0
	var fire := s0 + beside
	_camp_spot = Vector3(fire.x, maxf(ground(fire.x, fire.y), floor_y), fire.y)
	# An inhabited ruin gets a burning fire there (Camps); otherwise the
	# old ring of stones round cold ash.
	if not Ruins.inhabited(site):
		fire_ring(fire, floor_y)


## A tepee: poles leaning in to a crossing at the top, covered in woven
## vines and hide panels, with a door gap.
func tepee(center: Vector2, r: float, h: float, floor_y := 0.0) -> void:
	var g := maxf(ground(center.x, center.y), floor_y)
	var apex := Vector3(center.x, g + h, center.y)
	var poles := 7
	var a0 := rng.randf() * TAU
	var feet: Array[Vector3] = []
	for i in poles:
		var a := a0 + TAU * i / poles + rng.randf_range(-0.08, 0.08)
		var foot := Vector3(center.x + cos(a) * r, 0.0, center.y + sin(a) * r)
		foot.y = maxf(ground(foot.x, foot.z), floor_y) - 0.1
		feet.append(foot)
		var along := (apex - foot).normalized()
		_pole(foot, apex + along * rng.randf_range(0.35, 0.6), 0.09)
	# Cover: panels between neighboring poles up to near the top; one gap
	# is the door.
	var inside := Vector3(center.x, g + h * 0.4, center.y)
	var start := _v.size()
	var door := rng.randi() % poles
	for i in poles:
		if i == door:
			continue
		var a := feet[i]
		var b := feet[(i + 1) % poles]
		var ta := a.lerp(apex, 0.86)
		var tb := b.lerp(apex, 0.86)
		var vine := rng.randf() < 0.6
		var col := IVY.lerp(IVY_LIGHT, rng.randf()) if vine else HIDE.lightened(rng.randf_range(-0.08, 0.08))
		col.a = 0.75 if vine else 0.1
		mat = LEAF_M if vine else HIDE_M
		_face(a, b, tb, ta, col, inside)
	mat = STONE_M
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	_collision_box(Transform3D(Basis.IDENTITY, Vector3(center.x, g + h * 0.3, center.y)), Vector3(r * 0.6, h * 0.3, r * 0.6))
	_shelters.append([Vector3(center.x, g, center.y), r, h])


## A lean-to: two forked uprights and a ridge pole, a roof of vine thatch
## sloping down to the ground behind.
func lean_to(center: Vector2, heading: float, floor_y := 0.0) -> void:
	var fwd := Vector3(cos(heading), 0.0, sin(heading))
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var w := rng.randf_range(2.4, 3.2)
	var hh := rng.randf_range(1.7, 2.1)
	var depth := rng.randf_range(2.0, 2.6)
	var c := Vector3(center.x, 0.0, center.y)
	var tops: Array[Vector3] = []
	for s: float in [-0.5, 0.5]:
		var foot: Vector3 = c + side * w * s
		foot.y = maxf(ground(foot.x, foot.z), floor_y) - 0.1
		var top: Vector3 = foot + Vector3(0, hh + 0.1, 0)
		_pole(foot, top + Vector3(0, 0.25, 0), 0.1)
		tops.append(top)
	_pole(tops[0] - side * 0.3, tops[1] + side * 0.3, 0.08)
	var backs: Array[Vector3] = []
	for t in tops:
		var back := t - fwd * depth
		back.y = maxf(ground(back.x, back.z), floor_y) - 0.05
		backs.append(back)
		_pole(t, back, 0.07)
	var start := _v.size()
	var col := IVY.lerp(IVY_LIGHT, rng.randf())
	col.a = 0.75
	mat = LEAF_M
	_face(tops[0], tops[1], backs[1], backs[0], col, c + Vector3(0, -3.0, 0) - fwd * depth * 0.5)
	mat = STONE_M
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	var mid := (tops[0] + tops[1] + backs[0] + backs[1]) * 0.25
	_collision_box(Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), mid), Vector3(w * 0.5, hh * 0.3, depth * 0.35))
	var floor_c := c - fwd * depth * 0.5
	floor_c.y = maxf(ground(floor_c.x, floor_c.z), floor_y)
	_shelters.append([floor_c, maxf(w, depth) * 0.5, hh])


## A straight pole (a thin, barely bevelled wooden block).
func _pole(a: Vector3, b: Vector3, thick: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var basis := Basis(x, y, x.cross(y))
	var col := WOOD.lightened(rng.randf_range(-0.08, 0.08))
	var was := mat
	mat = WOOD_M
	box(Transform3D(basis, (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick), col, 0.1, 0.02, 0.01)
	mat = was


## A ring of stones around old ash.
func fire_ring(center: Vector2, floor_y := 0.0) -> void:
	var g := maxf(ground(center.x, center.y), floor_y)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.15, 0.15)
		var p := Vector3(center.x + cos(a) * 0.55, g + 0.08, center.y + sin(a) * 0.55)
		boulder(p, Vector3(0.16, 0.11, 0.14), Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)), STONES[rng.randi() % STONES.size()], 0.1)
	var ash := Color(0.16, 0.15, 0.14)
	ash.a = 0.0
	box(Transform3D(Basis.IDENTITY, Vector3(center.x, g + 0.01, center.y)), Vector3(0.8, 0.04, 0.8), ash, 0.0, 0.01, 0.0)


# --- Snow country: igloos ---------------------------------------------------------

## One to three igloos, some fallen in, a windbreak of snow blocks and a
## drying rack of poles and hides.
func _igloos() -> void:
	var spots: Array[Vector2] = [Vector2.ZERO]
	for i in rng.randi_range(0, 2):
		var a := rng.randf() * TAU
		spots.append(Vector2(cos(a), sin(a)) * rng.randf_range(6.5, 8.0))
	var doors: Array[float] = []
	for p in spots:
		doors.append(rng.randf() * TAU)
		igloo(p, rng.randf_range(2.1, 2.7), doors[-1], rng.randf() < 0.45)
	# The camp fire: 4.8 m out from the middle igloo, as far as can be from
	# the others and clear of its entrance tunnel.
	var best_a := 0.0
	var best_clear := -INF
	for k in 12:
		var a := TAU * k / 12.0
		if absf(angle_difference(a, doors[0])) < 0.6:
			continue
		var q := Vector2(cos(a), sin(a)) * 4.8
		var clear := INF
		for p in spots.slice(1):
			clear = minf(clear, q.distance_to(p))
		if clear > best_clear:
			best_clear = clear
			best_a = a
	var fire := Vector2(cos(best_a), sin(best_a)) * 4.8
	_camp_spot = Vector3(fire.x, ground(fire.x, fire.y), fire.y)
	# Windbreak: a low curved wall on one side.
	var wa := rng.randf() * TAU
	mat = SNOW_M
	for k in 9:
		var a := wa + (k - 4) * 0.15
		var p := Vector2(cos(a), sin(a)) * 10.0
		var g := ground(p.x, p.y)
		var tangent := Vector3(-sin(a), 0, cos(a))
		for j in rng.randi_range(1, 3):
			var basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)).rotated(Vector3.UP, rng.randf_range(-0.08, 0.08))
			box(Transform3D(basis, Vector3(p.x, g + 0.2 + j * 0.42, p.y)), Vector3(1.4, 0.42, 0.5), SNOW.darkened(rng.randf_range(0.0, 0.08)), 0.0, 0.05, 0.04)
	mat = STONE_M
	# Drying rack: two posts and a bar, hides hung over it.
	var ra := best_a + PI * 0.5 + rng.randf_range(-0.3, 0.3)
	var rc := Vector2(cos(ra), sin(ra)) * 7.5
	var side := Vector2(-sin(ra), cos(ra))
	var ends: Array[Vector3] = []
	for s in [-1.0, 1.0]:
		var q: Vector2 = rc + side * 1.1 * s
		var g := ground(q.x, q.y)
		_pole(Vector3(q.x, g - 0.3, q.y), Vector3(q.x, g + 1.7, q.y), 0.1)
		ends.append(Vector3(q.x, g + 1.6, q.y))
	_pole(ends[0], ends[1], 0.07)
	mat = HIDE_M
	for k in 2:
		var t := 0.3 + 0.4 * k
		var top := ends[0].lerp(ends[1], t)
		var col := HIDE.lightened(rng.randf_range(-0.1, 0.1))
		col.a = 0.0
		var w := Vector3(side.x, 0, side.y) * 0.35
		var drop := Vector3(0, -rng.randf_range(0.9, 1.3), 0)
		var fwd := Vector3(cos(ra), 0, sin(ra)) * 0.12
		_face(top - w, top + w, top + w + drop + fwd, top - w + drop + fwd, col, top - fwd * 4.0)
		_face(top - w, top + w, top + w + drop - fwd, top - w + drop - fwd, col, top + fwd * 4.0)
	mat = STONE_M


## A dome of snow-block rings leaning in, with a door and an entrance
## tunnel (crouch height). `fallen`: the cap has caved in.
func igloo(center: Vector2, r: float, door_a: float, fallen: bool) -> void:
	mat = SNOW_M
	var g := ground(center.x, center.y) - 0.15
	var c3 := Vector3(center.x, g, center.y)
	var rings := 6
	var arc := r * PI * 0.5 / rings
	var cap_a := rng.randf() * TAU
	var tumbled := 0
	for k in rings:
		var phi := (k + 0.5) * PI * 0.5 / (rings + 0.3)
		var rr := r * cos(phi)
		var y := r * sin(phi)
		var n := maxi(4, int(TAU * rr / 0.75))
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			if absf(angle_difference(a, door_a)) < 0.42 and y < 1.35:
				continue
			if fallen and k >= rings - 3 and absf(angle_difference(a, cap_a)) < 1.0 + 0.35 * (k - rings + 3):
				tumbled += 1
				continue
			var out := Vector3(cos(a), 0, sin(a))
			var tangent := Vector3(-sin(a), 0, cos(a))
			var normal := (out * cos(phi) + Vector3.UP * sin(phi)).normalized()
			var basis := Basis(tangent, normal, tangent.cross(normal)).orthonormalized()
			var col := SNOW.darkened(rng.randf_range(0.0, 0.07))
			col.a = 0.0
			box(Transform3D(basis, c3 + out * rr + Vector3(0, y, 0)), Vector3(TAU * rr / n * 0.96, 0.38, arc * 0.95), col, 0.0, 0.05, 0.03)
	if not fallen:
		box(Transform3D(Basis.IDENTITY, c3 + Vector3(0, r * 0.98, 0)), Vector3(0.9, 0.3, 0.9), SNOW, 0.0, 0.08, 0.02)
	# Entrance tunnel: arches of blocks out from the door.
	var outd := Vector3(cos(door_a), 0, sin(door_a))
	var side := Vector3(-sin(door_a), 0, cos(door_a))
	for t in 3:
		var dist := r + 0.25 + t * 0.52
		for j in 7:
			var ang := PI * j / 6.0
			var radial := side * cos(ang) + Vector3.UP * sin(ang)
			var p := c3 + outd * dist + radial * 1.1 + Vector3(0, 0.15, 0)
			var basis := Basis(outd, radial, outd.cross(radial)).orthonormalized()
			box(Transform3D(basis, p), Vector3(0.5, 0.3, 0.5), SNOW.darkened(rng.randf_range(0.0, 0.06)), 0.0, 0.05, 0.03)
	# Fallen blocks inside and round the foot.
	for i in mini(tumbled, 10):
		var a := cap_a + rng.randf_range(-1.0, 1.0)
		var d := rng.randf_range(0.0, r + 1.2)
		var p := Vector3(center.x + cos(a) * d, 0, center.y + sin(a) * d)
		p.y = ground(p.x, p.z) + 0.1
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
		box(Transform3D(basis, p), Vector3(0.7, 0.36, 0.5), SNOW.darkened(0.05), 0.0, 0.07, 0.05)
	mat = STONE_M
	if not fallen:
		_shelters.append([Vector3(center.x, g + 0.15, center.y), r, r])


# --- Jungle: treehouses -----------------------------------------------------------

## Three or four giant trees in a ring, each with a plank platform high up
## (two with huts), joined by sagging rope bridges (one sometimes snapped),
## and a ramp spiralling up round the first from the ground.
func _treehouse() -> void:
	var n := rng.randi_range(3, 4)
	var trees: Array = [] # [pos 2D, trunk r, deck y, deck r, ground y]
	var a0 := rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * i / n + rng.randf_range(-0.2, 0.2)
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 10.0)
		var tr := rng.randf_range(1.0, 1.35)
		var g := ground(p.x, p.y)
		giant_tree(Vector3(p.x, g, p.y), tr, rng.randf_range(26.0, 34.0))
		trees.append([p, tr, g + rng.randf_range(8.0, 11.0), tr + rng.randf_range(2.2, 2.7), g])
	# Where bridges and the ramp meet each deck (angles, for the railings).
	var openings: Array = []
	for i in n:
		openings.append([])
	var broken := rng.randi() % n if rng.randf() < 0.5 else -1
	for i in n:
		var j := (i + 1) % n
		if n == 3 and i == 2 and rng.randf() < 0.5:
			continue
		var pa: Vector2 = trees[i][0]
		var pb: Vector2 = trees[j][0]
		var d := (pb - pa).normalized()
		openings[i].append(d.angle())
		openings[j].append((-d).angle())
		var sa: Vector2 = pa + d * float(trees[i][3])
		var sb: Vector2 = pb - d * float(trees[j][3])
		rope_bridge(Vector3(sa.x, trees[i][2], sa.y), Vector3(sb.x, trees[j][2], sb.y), i == broken)
	# The ramp arrives on the first deck's outer side.
	var p0: Vector2 = trees[0][0]
	var out_a := p0.angle()
	# The camp fire on the ground in the middle, a little away from the
	# ramp's tree.
	var fire := -p0.normalized() * 2.0
	_camp_spot = Vector3(fire.x, ground(fire.x, fire.y), fire.y)
	openings[0].append(out_a)
	spiral_ramp(p0, float(trees[0][3]) + 0.75, float(trees[0][2]), float(trees[0][4]), out_a)
	for i in n:
		var t: Array = trees[i]
		platform(t[0], t[1], t[2], t[3], openings[i])
		if i == 1 or (i == 2 and rng.randf() < 0.6):
			# A hut on the deck, away from the bridges.
			var ha := (t[0] as Vector2).angle() + PI + rng.randf_range(-0.5, 0.5)
			hut(t[0], t[1], t[2], ha)


## A huge buttressed trunk with limbs, a leafy crown and hanging vines.
func giant_tree(base: Vector3, r: float, h: float) -> void:
	mat = WOOD_M
	var sides := 12
	var rings: Array = [] # [y, radius]
	for k in 9:
		var t := float(k) / 8.0
		var y := h * 0.78 * t
		var rad := r * (1.0 - 0.45 * t) * (1.0 + 0.7 * exp(-y / 1.2))
		rings.append([y, rad])
	var col := BARK.lightened(rng.randf_range(-0.05, 0.05))
	col.a = 0.1 # a hint of moss
	var start := _v.size()
	var tw := rng.randf() * TAU
	for k in rings.size() - 1:
		var y0: float = rings[k][0]
		var y1: float = rings[k + 1][0]
		var r0: float = rings[k][1]
		var r1: float = rings[k + 1][1]
		for i in sides:
			var a := TAU * i / sides + tw
			var b := TAU * (i + 1) / sides + tw
			var ps: Array[Vector3] = [base + Vector3(cos(a) * r0, y0, sin(a) * r0), base + Vector3(cos(b) * r0, y0, sin(b) * r0),
				base + Vector3(cos(b) * r1, y1, sin(b) * r1), base + Vector3(cos(a) * r1, y1, sin(a) * r1)]
			_face(ps[0], ps[1], ps[2], ps[3], col, base + Vector3(0, (y0 + y1) * 0.5, 0))
	_smooth_from(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	for k in 3:
		var yk := h * 0.26 * k
		_collision_box(Transform3D(Basis.IDENTITY, base + Vector3(0, yk + h * 0.13, 0)), Vector3(r, h * 0.13, r) * (1.0 - 0.15 * k))
	# Buttress roots.
	for k in rng.randi_range(4, 5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0, sin(a))
		box(Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), base + out * (r + 0.9) + Vector3(0, 0.6, 0)), Vector3(2.2, 1.4, 0.3), col, 0.4, 0.1, 0.05)
	# Limbs and the crown.
	var top := base + Vector3(0, h * 0.78, 0)
	for k in rng.randi_range(3, 4):
		var a := rng.randf() * TAU
		var from := base + Vector3(0, h * rng.randf_range(0.6, 0.75), 0)
		var to := from + Vector3(cos(a) * h * 0.22, h * 0.14, sin(a) * h * 0.22)
		_limb(from, to, r * 0.32)
		_crown_blob(to + Vector3(0, 1.5, 0), rng.randf_range(4.0, 5.5))
	_crown_blob(top + Vector3(0, 2.5, 0), rng.randf_range(6.0, 7.5))
	mat = STONE_M
	# Vines hanging from the limbs.
	for k in 4:
		var a := rng.randf() * TAU
		var p := base + Vector3(cos(a) * r * 2.5, h * rng.randf_range(0.55, 0.7), sin(a) * r * 2.5)
		_ivy_strand(p, Vector3(cos(a), 0, sin(a)), rng.randf_range(5.0, 11.0))


func _limb(a: Vector3, b: Vector3, thick: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var col := BARK.darkened(0.05)
	col.a = 0.1
	box(Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), Vector3(thick, a.distance_to(b), thick), col, 0.3, 0.12, 0.05)


func _crown_blob(c: Vector3, radius: float) -> void:
	var was := mat
	mat = LEAF_M
	var col := JUNGLE_LEAF.lightened(rng.randf_range(-0.06, 0.08))
	boulder(c, Vector3(radius, radius * 0.6, radius), Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)), col, 0.0)
	mat = was


## A round deck of planks round a trunk at height y, with knee braces
## below and a post-and-rope railing, open at `openings` (angles).
func platform(p: Vector2, tr: float, y: float, pr: float, openings: Array) -> void:
	mat = WOOD_M
	var rot := rng.randf() * PI
	var ax := Vector3(cos(rot), 0, sin(rot))
	var az := Vector3(-sin(rot), 0, cos(rot))
	var c := Vector3(p.x, y, p.y)
	var o := -pr + 0.18
	while o < pr:
		var half := sqrt(maxf(pr * pr - o * o, 0.0))
		var hole := sqrt(maxf((tr + 0.05) * (tr + 0.05) - o * o, 0.0))
		var spans: Array = [[-half, half]] if hole <= 0.0 else [[-half, -hole], [hole, half]]
		for sp in spans:
			var l: float = sp[1] - sp[0]
			if l < 0.3 or rng.randf() < 0.05:
				continue
			var mid: float = (sp[0] + sp[1]) * 0.5
			var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
			box(Transform3D(Basis(ax, Vector3.UP, ax.cross(Vector3.UP)), c + ax * mid + az * o), Vector3(l, 0.08, 0.32), col, 0.15, 0.02, 0.01)
		o += 0.36
	# Knee braces from the trunk to the rim.
	for k in 4:
		var a := rot + TAU * k / 4.0 + PI * 0.25
		var dirv := Vector3(cos(a), 0, sin(a))
		_pole(c + dirv * tr + Vector3(0, -2.6, 0), c + dirv * (pr - 0.3) + Vector3(0, -0.1, 0), 0.16)
	# Railing.
	var posts := maxi(6, int(TAU * pr / 1.5))
	var prev := Vector3.ZERO
	var prev_ok := false
	for k in posts + 1:
		var a := TAU * k / posts
		var open := false
		for oa in openings:
			if absf(angle_difference(a, float(oa))) < 0.45:
				open = true
		var q := c + Vector3(cos(a), 0, sin(a)) * (pr - 0.1)
		if open:
			prev_ok = false
			continue
		if k < posts:
			_pole(q, q + Vector3(0, 1.05, 0), 0.08)
		var top := q + Vector3(0, 0.95, 0)
		if prev_ok:
			_rope(prev, top)
		prev = top
		prev_ok = true
	mat = STONE_M
	_shelters.append([c, pr, 0.0]) # a place, not a roof (height 0: no shelter)


## A thatched hut on a deck, against the trunk.
func hut(p: Vector2, tr: float, y: float, a: float) -> void:
	mat = WOOD_M
	var out := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a))
	var c := Vector3(p.x, y, p.y) + out * (tr + 1.3)
	var hw := 1.1
	var hd := 0.9
	var wall_h := 1.9
	# Board walls on three sides, the door side (outward) half open.
	for s in [-1.0, 1.0]:
		var n := 6
		for k in n:
			var t := (k + 0.5) / n * 2.0 - 1.0
			var bpos: Vector3 = c + side * hw * s + out * hd * t + Vector3(0, wall_h * 0.5, 0)
			if rng.randf() < 0.1:
				continue
			box(Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), bpos), Vector3(0.28, wall_h, 0.06), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.1, 0.01, 0.01)
	for k in 7:
		var t := (k + 0.5) / 7.0 * 2.0 - 1.0
		if absf(t) < 0.35:
			continue # the doorway
		var bpos: Vector3 = c + out * hd + side * hw * t + Vector3(0, wall_h * 0.5, 0)
		box(Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), bpos), Vector3(0.28, wall_h, 0.06), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.1, 0.01, 0.01)
	# Thatched roof: two slopes meeting over the middle.
	mat = THATCH_M
	var ridge := c + Vector3(0, wall_h + 0.8, 0)
	var tc := THATCH.lightened(rng.randf_range(-0.06, 0.06))
	tc.a = 0.2
	for s in [-1.0, 1.0]:
		var eave: Vector3 = c + side * (hw + 0.35) * s + Vector3(0, wall_h - 0.1, 0)
		var mid: Vector3 = (ridge + eave) * 0.5
		var slope_dir: Vector3 = (eave - ridge).normalized()
		var basis := Basis(out, slope_dir.cross(out).normalized() * (-1.0 if s < 0.0 else 1.0), slope_dir).orthonormalized()
		box(Transform3D(Basis(out, slope_dir.cross(out).normalized(), slope_dir), mid), Vector3((hd + 0.4) * 2.0, 0.14, ridge.distance_to(eave) + 0.2), tc, 0.0, 0.05, 0.04)
	mat = STONE_M
	_shelters.append([c, hw, wall_h])


## A sagging rope bridge from deck edge `a` to deck edge `b`: planks on
## two ropes, a rope rail each side. `snapped`: it has broken in the
## middle and the halves hang down.
func rope_bridge(a: Vector3, b: Vector3, snapped: bool) -> void:
	mat = WOOD_M
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := flat.length()
	var dir := flat / length
	var side := Vector3(-dir.z, 0, dir.x)
	var sag := 0.08 * length
	var n := int(length / 0.42)
	var deck := func(t: float) -> Vector3:
		return a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
	var prev_rail: Array = []
	for k in n + 1:
		var t := float(k) / n
		var p: Vector3 = deck.call(t)
		if snapped and absf(t - 0.5) < 0.12:
			continue
		if snapped:
			# Each half hangs from its own deck, swinging down.
			var h := clampf((0.5 - absf(t - 0.5)) / 0.38, 0.0, 1.0)
			var anchor := a if t < 0.5 else b
			var reach := absf(t - (0.0 if t < 0.5 else 1.0)) * length
			p = anchor + dir * (reach * (1.0 - h) * (1.0 if t < 0.5 else -1.0)) + Vector3(0, -reach * h, 0)
		var next: Vector3 = deck.call(minf(t + 0.01, 1.0))
		var along := (next - p).normalized() if not snapped else dir
		if rng.randf() > 0.06:
			var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
			box(Transform3D(Basis(side, along.cross(side).normalized() * -1.0, along).orthonormalized(), p), Vector3(1.2, 0.07, 0.26), col, 0.1, 0.02, 0.01)
		# Rope rails: posts of rope every few planks.
		var rails: Array = [p + side * 0.62 + Vector3(0, 0.95, 0), p - side * 0.62 + Vector3(0, 0.95, 0)]
		if not prev_rail.is_empty() and not snapped:
			_rope(prev_rail[0], rails[0])
			_rope(prev_rail[1], rails[1])
			if k % 3 == 0:
				_rope(p + side * 0.6, rails[0])
				_rope(p - side * 0.6, rails[1])
		prev_rail = rails
	mat = STONE_M


## A ramp of planks spiralling round a deck from the ground up to it,
## arriving at angle `end_a` (radius `ramp_r` from the trunk), on posts.
func spiral_ramp(p: Vector2, ramp_r: float, deck_y: float, g: float, end_a: float) -> void:
	mat = WOOD_M
	var slope := 0.42
	var length := (deck_y - g) / slope
	var step := 0.55
	var n := int(length / step)
	var c := Vector3(p.x, 0, p.y)
	for k in n:
		var d0 := length - k * step
		var d1 := length - (k + 1) * step
		var a0 := end_a - d0 / ramp_r
		var a1 := end_a - d1 / ramp_r
		var q0 := c + Vector3(cos(a0) * ramp_r, deck_y - d0 * slope, sin(a0) * ramp_r)
		var q1 := c + Vector3(cos(a1) * ramp_r, deck_y - d1 * slope, sin(a1) * ramp_r)
		var along := (q1 - q0).normalized()
		var out := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var up2 := along.cross(out).normalized()
		if up2.y < 0.0:
			up2 = -up2
		var col := OLD_WOOD.lightened(rng.randf_range(-0.08, 0.06))
		box(Transform3D(Basis(out, up2, out.cross(up2)).orthonormalized(), (q0 + q1) * 0.5), Vector3(1.2, 0.08, step * 1.08), col, 0.1, 0.02, 0.01)
		if k % 4 == 2:
			var foot := (q0 + q1) * 0.5 + out * 0.5
			var fg := ground(foot.x, foot.z)
			if foot.y - fg > 0.8:
				_pole(Vector3(foot.x, fg - 0.3, foot.z), foot + Vector3(0, -0.05, 0), 0.12)
	mat = STONE_M


## A thin rope segment.
func _rope(a: Vector3, b: Vector3) -> void:
	var was := mat
	mat = WOOD_M
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var col := ROPE
	col.a = 0.0
	_tri_box(Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), Vector3(0.04, a.distance_to(b), 0.04), col)
	mat = was


## A plain box with no bevel, collision or LOD (ropes and the like).
func _tri_box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_face(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, xf.origin)


# --- Marsh: boardwalk and cabin ---------------------------------------------------

## A plank walk on posts wandering across the marsh, planks missing and one
## stretch sunk under the water, dead snags beside it, and a stilt cabin
## at the far end.
func _boardwalk() -> void:
	var length: float = site.length_m
	var n := int(length / 1.6)
	var pts: Array[Vector2] = []
	var z := 0.0
	var dz := 0.0
	for i in n + 1:
		dz = clampf(dz + rng.randf_range(-0.2, 0.2), -0.35, 0.35)
		z = clampf(z + dz, -2.2, 2.2)
		if absf(z) >= 2.2:
			dz = -dz * 0.5
		pts.append(Vector2(-length * 0.5 + i * length / n, z))
	var deck_y := -INF
	for q in pts:
		deck_y = maxf(deck_y, ground(q.x, q.y))
	deck_y += 0.45
	# The camp fire on the dry ground where the walk begins.
	var fire := pts[0] + Vector2(-4.0, 0.0)
	_camp_spot = Vector3(fire.x, ground(fire.x, fire.y), fire.y)
	var sunk0 := rng.randi_range(int(n * 0.3), int(n * 0.6))
	var sunk1 := sunk0 + rng.randi_range(2, 4)
	mat = WOOD_M
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var ga := ground(a.x, a.y)
		# Up from the ground at the start, level after, dipping where sunk.
		var ya := minf(deck_y, ga + 0.1 + i * 0.25)
		var yb := minf(deck_y, ground(b.x, b.y) + 0.1 + (i + 1) * 0.25)
		if i >= sunk0 and i < sunk1:
			ya = minf(ya, ga - 0.12)
			yb = minf(yb, ground(b.x, b.y) - 0.12)
		var a3 := Vector3(a.x, ya, a.y)
		var b3 := Vector3(b.x, yb, b.y)
		var along := (b3 - a3).normalized()
		var flat := Vector3(along.x, 0, along.z).normalized()
		var side := Vector3(-flat.z, 0, flat.x)
		var up2 := along.cross(side).normalized() * -1.0
		if up2.y < 0.0:
			up2 = -up2
		var planks := int(a3.distance_to(b3) / 0.34)
		for k in planks:
			if rng.randf() < 0.08:
				continue
			var t := (k + 0.5) / planks
			var col := OLD_WOOD.lightened(rng.randf_range(-0.1, 0.06))
			col.a = 0.25
			var basis := Basis(side, up2, side.cross(up2)).rotated(up2, rng.randf_range(-0.05, 0.05))
			box(Transform3D(basis, a3.lerp(b3, t)), Vector3(1.5, 0.07, 0.28), col, 0.25, 0.02, 0.015)
		# Stringers under the planks.
		for s in [-0.5, 0.5]:
			var off: Vector3 = side * s + Vector3(0, -0.1, 0)
			box(Transform3D(Basis(side, up2, side.cross(up2)), (a3 + b3) * 0.5 + off), Vector3(0.14, 0.12, a3.distance_to(b3)), OLD_WOOD.darkened(0.15), 0.3, 0.02, 0.01)
		# Posts every other point, a few standing proud of the deck.
		if i % 2 == 0:
			for s in [-0.72, 0.72]:
				var q: Vector3 = a3 + side * s
				var extra := rng.randf_range(0.2, 0.9) if rng.randf() < 0.4 else 0.1
				_pole(Vector3(q.x, ground(q.x, q.z) - 0.8, q.z), q + Vector3(0, extra, 0), 0.17)
	mat = STONE_M
	# Dead snags standing in the marsh.
	for k in rng.randi_range(3, 6):
		var t := rng.randf()
		var q: Vector2 = pts[int(t * n)] + Vector2(0, rng.randf_range(3.0, 6.0) * (1.0 if rng.randf() < 0.5 else -1.0))
		var g := ground(q.x, q.y)
		var col := OLD_WOOD.darkened(0.25)
		_limb(Vector3(q.x, g - 0.5, q.y), Vector3(q.x + rng.randf_range(-0.4, 0.4), g + rng.randf_range(2.5, 6.0), q.y + rng.randf_range(-0.4, 0.4)), rng.randf_range(0.25, 0.4))
	# The cabin at the end.
	var e := pts[n]
	var d := (pts[n] - pts[n - 1]).normalized()
	cabin(e + d * 2.6, d.angle(), deck_y + 0.1)


## A plank cabin on stilts, the door facing back along `heading`, a
## window, boards missing and part of the thatch fallen in.
func cabin(center: Vector2, heading: float, floor_y: float) -> void:
	mat = WOOD_M
	var fwd := Vector3(cos(heading), 0, sin(heading))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var c := Vector3(center.x, floor_y, center.y)
	var hl := 2.2 # half length (along fwd)
	var hw := 1.7
	var wall_h := 2.2
	# Stilts and floor.
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector3 = c + fwd * hl * 0.9 * sx + side * hw * 0.9 * sz
			_pole(Vector3(q.x, ground(q.x, q.z) - 0.8, q.z), q + Vector3(0, -0.05, 0), 0.2)
	var o := -hw + 0.17
	while o < hw:
		box(Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), c + side * o), Vector3(hl * 2.0, 0.08, 0.32), OLD_WOOD.lightened(rng.randf_range(-0.08, 0.05)), 0.2, 0.02, 0.01)
		o += 0.34
	# Walls: vertical boards; the doorway faces back along the walk, a
	# window in one side, some boards gone.
	var slump := rng.randi() % 4
	for w in 4:
		var normal := [-fwd, fwd, side, -side][w] as Vector3
		var tangent := normal.cross(Vector3.UP)
		var half := hw if w < 2 else hl
		var reach := hl if w < 2 else hw
		var boards := int(half * 2.0 / 0.3)
		for k in boards:
			var t := ((k + 0.5) / boards * 2.0 - 1.0) * half
			if w == 0 and absf(t) < 0.45:
				continue # doorway
			if rng.randf() < 0.08:
				continue
			var h := wall_h * (0.55 if w == slump and t > 0.0 else 1.0) * rng.randf_range(0.92, 1.0)
			var base := c + normal * reach + tangent * t
			var col := OLD_WOOD.lightened(rng.randf_range(-0.1, 0.05))
			col.a = 0.2
			if w == 2 and absf(t) < 0.5:
				# Window: a gap between a low and a high board.
				box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, 0.5, 0)), Vector3(0.28, 1.0, 0.06), col, 0.2, 0.01, 0.01)
				box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, 1.9, 0)), Vector3(0.28, 0.6, 0.06), col, 0.2, 0.01, 0.01)
				continue
			box(Transform3D(Basis(tangent, Vector3.UP, normal), base + Vector3(0, h * 0.5, 0)), Vector3(0.28, h, 0.06), col, 0.2, 0.01, 0.01)
	# Roof: two thatch slopes along the length, one fallen in at one end.
	mat = THATCH_M
	var ridge := c + Vector3(0, wall_h + 1.1, 0)
	for s in [-1.0, 1.0]:
		var eave: Vector3 = c + side * (hw + 0.4) * s + Vector3(0, wall_h - 0.05, 0)
		var slope_dir: Vector3 = (eave - ridge).normalized()
		var basis := Basis(fwd, slope_dir.cross(fwd).normalized(), slope_dir).orthonormalized()
		var tc := THATCH.darkened(rng.randf_range(0.0, 0.15))
		tc.a = 0.35
		for part in 3:
			if s > 0.0 and part == 2 and rng.randf() < 0.7:
				continue # caved in
			var t := (part - 1.0) * (hl + 0.4) * 2.0 / 3.0
			box(Transform3D(basis, (ridge + eave) * 0.5 + fwd * t), Vector3((hl + 0.4) * 2.0 / 3.0, 0.14, ridge.distance_to(eave) + 0.25), tc, 0.0, 0.05, 0.04)
	mat = STONE_M
	_shelters.append([c, minf(hl, hw), wall_h])

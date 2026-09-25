class_name PlantMeshes
## Low-poly placeholder meshes per plant shape (DESIGN.md: prototype uses
## greybox geometry; real models replace these). Each mesh is 1 unit tall
## (instances scale it to the species' height), grows along +Y from the
## origin (hanging plants grow down along -Y), is smooth shaded (normals
## averaged within each part: a trunk, a crown lobe, a frond), and carries
## vertex color RGB plus a sway weight in alpha (0 at the roots, 1 at the
## crown) that shaders/foliage.gdshader uses for wind.

const S := PlantSpecies.Shape

static var _cache := {} # species index -> ArrayMesh
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if not _material:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/foliage.gdshader")
		Look.register(_material)
	return _material


## Crown lobe detail: icosphere subdivisions (1: 80 triangles, 2: 320).
## Once keeps trees inside the PS2/GameCube budget (~150-400 each).
const CROWN_SUBDIV := 1

static var _ico := {}


## Unit icosphere [vertices, triangle indices], subdivided `level` times,
## wound so (b - a) x (c - a) points outward like the other parts.
static func icosphere(level: int) -> Array:
	if _ico.has(level):
		return _ico[level]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array()
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(p.normalized())
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4,
		11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5,
		2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for l in level:
		var mid := {}
		var next := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var m: Array[int] = []
			for e in [[faces[f], faces[f + 1]], [faces[f + 1], faces[f + 2]], [faces[f + 2], faces[f]]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not mid.has(key):
					mid[key] = verts.size()
					verts.append((verts[e[0]] + verts[e[1]]).normalized())
				m.append(mid[key])
			next.append_array([faces[f], m[0], m[2], faces[f + 1], m[1], m[0], faces[f + 2], m[2], m[1], m[0], m[1], m[2]])
		faces = next
	# Wind every face outward.
	for f in range(0, faces.size(), 3):
		var a := verts[faces[f]]
		if (verts[faces[f + 1]] - a).cross(verts[faces[f + 2]] - a).dot(a) < 0.0:
			var tmp := faces[f + 1]
			faces[f + 1] = faces[f + 2]
			faces[f + 2] = tmp
	_ico[level] = [verts, faces]
	return _ico[level]


## A tree shape's proportions, as fractions of its height: Vector4(trunk
## radius, trunk collider height, crown radius, crown bottom). Trunk
## colliders, climbing, rain shelter and rustling read these; a crown
## radius of 0 means no crown to shelter under or brush through.
static func tree_dims(shape: int) -> Vector4:
	match shape:
		S.CONIFER:
			return Vector4(0.04, 0.35, 0.28, 0.15)
		S.BROADLEAF:
			return Vector4(0.05, 0.6, 0.42, 0.45)
		S.GNARLED:
			return Vector4(0.075, 0.45, 0.5, 0.46)
		S.EMERGENT:
			return Vector4(0.03, 0.85, 0.3, 0.8)
		S.UMBRELLA:
			return Vector4(0.045, 0.7, 0.65, 0.72)
		S.PALM:
			return Vector4(0.03, 0.9, 0.42, 0.75)
		S.CYPRESS:
			return Vector4(0.06, 0.62, 0.22, 0.42)
		S.MANGROVE:
			return Vector4(0.2, 0.35, 0.5, 0.53)
		S.BAMBOO:
			return Vector4(0.06, 0.6, 0.2, 0.4)
		S.ROSETTE:
			return Vector4(0.07, 0.75, 0.25, 0.7)
		S.SPIKE_ROSETTE:
			return Vector4(0.2, 0.3, 0.0, 0.0)
		S.CACTUS:
			return Vector4(0.08, 1.0, 0.0, 0.0)
	return Vector4(0.05, 0.5, 0.35, 0.4)


## Can you climb it? Trees with a trunk and branches, not cacti or rosettes.
static func climbable(shape: int) -> bool:
	return shape in [S.CONIFER, S.BROADLEAF, S.GNARLED, S.EMERGENT, S.UMBRELLA, S.PALM, S.CYPRESS, S.MANGROVE, S.BAMBOO]


## `far`: the light version for trees beyond the ring nearest the player
## (once-subdivided lobes become icosahedra, trunks 5-sided, no branches
## or leaf cards).
static func mesh_for(sp: PlantSpecies, far := false) -> ArrayMesh:
	var idx := SpeciesDB.index_of(sp)
	var key := idx * 2 + int(far)
	if _cache.has(key):
		return _cache[key]
	var b := _Builder.new()
	b.far = far
	var leaf := sp.color
	var wood := sp.accent
	b.wood = wood
	b.rng.seed = idx * 7919 + 11
	if sp.shape == S.CACTUS:
		b.wood = leaf # ribbed: the bark streaks read as cactus ribs
	match sp.shape:
		S.CONIFER:
			b.trunk(0.04, 0.3, 0.0, 0.2)
			var cs := 6 if far else 8
			b.cone(Vector3(0, 0.15, 0), 0.3, 0.45, cs, leaf.darkened(0.1), 0.2, 0.6)
			b.cone(Vector3(0, 0.4, 0), 0.23, 0.4, cs, leaf, 0.5, 0.85)
			b.cone(Vector3(0, 0.65, 0), 0.15, 0.35, cs, leaf.lightened(0.08), 0.8, 1.0)
			# Old-man's-beard lichen in wet conifer forest.
			b.vines(5, Color(0.55, 0.6, 0.45))
		S.BROADLEAF:
			b.trunk(0.05, 0.62, 0.04, 0.3)
			b.branches(2, 0.36, 0.2, 0.62, 0.3)
			b.crown(Vector3(0, 0.7, 0), Vector3(0.36, 0.3, 0.36), 5, leaf, 0.8)
			b.vines(5, leaf.darkened(0.3))
		S.GNARLED:
			b.trunk(0.075, 0.42, 0.12, 0.2)
			b.branches(3, 0.3, 0.26, 0.5, 0.25)
			b.crown(Vector3(0.08, 0.66, 0), Vector3(0.42, 0.2, 0.34), 5, leaf, 0.8)
			b.vines(6, leaf.darkened(0.3))
		S.EMERGENT:
			b.trunk(0.03, 0.9, 0.03, 0.5)
			b.branches(2, 0.75, 0.16, 0.9, 0.5)
			b.crown(Vector3(0, 0.91, 0), Vector3(0.26, 0.1, 0.26), 3, leaf, 1.0)
			b.vines(4, leaf.darkened(0.3))
		S.UMBRELLA:
			b.trunk(0.045, 0.7, 0.06, 0.3)
			b.branches(3, 0.55, 0.3, 0.8, 0.3)
			b.crown(Vector3(0.04, 0.82, 0), Vector3(0.6, 0.1, 0.55), 5, leaf, 1.0)
			b.vines(5, leaf.darkened(0.3))
		S.PALM:
			b.cylinder(Vector3.ZERO, 0.03, 0.92, 5, wood, 0.0, 0.6, Vector3(0.08, 1, 0).normalized())
			for k in 7:
				var a := TAU * k / 7.0
				b.frond(Vector3(0.07, 0.92, 0), Vector3(cos(a), -0.35, sin(a)), 0.45, 0.07, leaf, 1.0)
		S.CYPRESS:
			b.cone(Vector3.ZERO, 0.12, 0.25, 8, wood, 0.0, 0.1)
			b.trunk(0.045, 0.62, 0.0, 0.4)
			b.crown(Vector3(0, 0.72, 0), Vector3(0.17, 0.3, 0.17), 3, leaf, 0.9)
			b.vines(4, Color(0.5, 0.55, 0.42))
		S.MANGROVE:
			for k in 5:
				var a := TAU * k / 5.0
				b.strut(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(0, 0.3, 0), 0.02, wood)
			b.cylinder(Vector3(0, 0.28, 0), 0.04, 0.4, 8, wood, 0.1, 0.4)
			b.crown(Vector3(0, 0.75, 0), Vector3(0.4, 0.22, 0.4), 3, leaf, 0.9)
			b.vines(5, leaf.darkened(0.3))
		S.ROSETTE:
			b.cylinder(Vector3.ZERO, 0.07, 0.75, 6, wood, 0.0, 0.3)
			for k in 10:
				var a := TAU * k / 10.0
				b.frond(Vector3(0, 0.78, 0), Vector3(cos(a), 0.7, sin(a)), 0.25, 0.06, leaf, 1.0)
		S.SPIKE_ROSETTE:
			b.blob(Vector3(0, 0.12, 0), Vector3(0.22, 0.13, 0.22), leaf, 0.1)
			b.cone(Vector3(0, 0.2, 0), 0.07, 0.8, 6, wood, 0.2, 0.6)
		S.SHRUB:
			b.crown(Vector3(0, 0.45, 0), Vector3(0.5, 0.45, 0.5), 2, leaf, 0.6, 1)
		S.TUSSOCK:
			for k in 9:
				var a := TAU * k / 9.0
				b.blade(Vector3.ZERO, Vector3(cos(a) * 0.45, 1, sin(a) * 0.45), 0.07, leaf, 1.0)
		S.GRASS:
			for k in 5:
				var a := TAU * k / 5.0 + 0.4
				b.blade(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), Vector3(cos(a) * 0.25, 1, sin(a) * 0.25), 0.06, leaf, 1.0)
			if wood.s > 0.3 and wood.v > 0.6:
				b.blob(Vector3(0.1, 0.95, 0), Vector3(0.08, 0.08, 0.08), wood, 1.0)
				b.blob(Vector3(-0.12, 0.85, 0.08), Vector3(0.07, 0.07, 0.07), wood, 1.0)
		S.REED:
			for k in 6:
				var a := TAU * k / 6.0
				b.blade(Vector3(cos(a) * 0.05, 0, sin(a) * 0.05), Vector3(cos(a) * 0.12, 1, sin(a) * 0.12), 0.03, leaf, 1.0)
			b.cylinder(Vector3(0, 0.72, 0), 0.025, 0.15, 5, wood, 0.9, 1.0)
		S.FERN:
			for k in 7:
				var a := TAU * k / 7.0
				b.frond(Vector3.ZERO, Vector3(cos(a), 1.1, sin(a)), 0.9, 0.2, leaf, 1.0)
			if wood.r > 0.8:
				b.blob(Vector3(0, 0.6, 0), Vector3(0.1, 0.1, 0.1), wood, 1.0)
		S.TREE_FERN:
			b.cylinder(Vector3.ZERO, 0.05, 0.75, 6, wood, 0.0, 0.5)
			for k in 8:
				var a := TAU * k / 8.0
				b.frond(Vector3(0, 0.75, 0), Vector3(cos(a), 0.25, sin(a)), 0.4, 0.09, leaf, 1.0)
		S.CACTUS:
			b.cylinder(Vector3.ZERO, 0.07, 1.0, 7, leaf, 0.0, 0.05)
			b.cylinder(Vector3(0.06, 0.4, 0), 0.04, 0.2, 6, leaf, 0.02, 0.05, Vector3(1, 0.15, 0).normalized())
			b.cylinder(Vector3(0.24, 0.43, 0), 0.04, 0.3, 6, leaf, 0.05, 0.08)
			b.cylinder(Vector3(-0.06, 0.55, 0), 0.035, 0.15, 6, leaf, 0.02, 0.05, Vector3(-1, 0.2, 0).normalized())
			b.cylinder(Vector3(-0.2, 0.58, 0), 0.035, 0.22, 6, leaf, 0.05, 0.08)
		S.CUSHION:
			b.blob(Vector3(0, 0.45, 0), Vector3(1.5, 0.55, 1.5), leaf, 0.2)
			if wood.v > 0.8:
				b.blob(Vector3(0.5, 0.9, 0.3), Vector3(0.25, 0.2, 0.25), leaf.lightened(0.2), 0.3)
		S.MOSS:
			b.disc(Vector3(0, 0.2, 0), 6.0, 0.8, 7, leaf, 0.0)
		S.HANGING_MOSS:
			for k in 5:
				var a := TAU * k / 5.0
				b.strand(Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), 1.0 - 0.15 * (k % 3), 0.07, leaf)
		S.EPIPHYTE_CLUMP:
			for k in 6:
				var a := TAU * k / 6.0
				b.frond(Vector3.ZERO, Vector3(cos(a), 0.9, sin(a)), 0.7, 0.2, wood, 0.8)
			b.blob(Vector3(0, 0.55, 0), Vector3(0.22, 0.22, 0.22), leaf, 1.0)
		S.LIANA:
			for k in 3:
				b.strand(Vector3((k - 1) * 0.02, 0, 0), 1.0 - 0.2 * k, 0.012, leaf)
		S.KNEES:
			b.cone(Vector3.ZERO, 0.25, 1.0, 5, leaf, 0.0, 0.0)
		S.THERMOPHILE_MAT:
			b.disc(Vector3(0, 0.3, 0), 40.0, 0.6, 9, leaf, 0.0)
			b.disc(Vector3(0, 0.7, 0), 22.0, 0.6, 9, wood, 0.0)
		S.BAMBOO:
			b.bamboo(wood, leaf)
		_:
			b.blob(Vector3(0, 0.5, 0), Vector3(0.4, 0.5, 0.4), leaf, 0.8)
	var mesh := b.commit()
	_cache[key] = mesh
	return mesh


class _Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array() # card texture coordinates
	var uv2 := PackedVector2Array() # x: material (0 bark, 1 leaves, 2 card)
	var wood := Color.BLACK # this species' wood color: cylinders/cones in it are bark
	var mat := 1.0
	var rng := RandomNumberGenerator.new()
	## Smoothing group of each vertex: normals are averaged over vertices
	## at the same spot in the same part; -1 keeps the vertex's own normal.
	var parts := PackedInt32Array()
	var part := 0
	var far := false
	## Vine strands: UV2.y holds each strand's 0-1 key; the foliage shader
	## shows the strands whose key is under the plant's vine amount.
	var strand_key := 0.0
	## Where vines can hang from: [center, radii] per crown lobe or cone.
	var hang_from: Array = []

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, sa: float, sb: float, sd: float) -> void:
		tri3(a, b, d, col, col, col, sa, sb, sd)

	func tri3(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, sa: float, sb: float, sd: float) -> void:
		var nrm := (b - a).cross(d - a).normalized()
		v.append_array([a, b, d])
		n.append_array([nrm, nrm, nrm])
		c.append_array([Color(ca, sa), Color(cb, sb), Color(cd, sd)])
		uv.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var m := Vector2(mat, strand_key)
		uv2.append_array([m, m, m])
		parts.append_array([part, part, part])

	## A leaf-cluster card (alpha cutout), square with half-size `s`, facing
	## `facing`, spun randomly.
	func card(center: Vector3, facing: Vector3, s: float, col: Color, sway: float) -> void:
		var f := facing.normalized()
		var t1 := f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := f.cross(t1)
		var spin := rng.randf() * TAU
		var a1 := (t1 * cos(spin) + t2 * sin(spin)) * s
		var a2 := (-t1 * sin(spin) + t2 * cos(spin)) * s
		var p := [center - a1 - a2, center + a1 - a2, center + a1 + a2, center - a1 + a2]
		var q := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var nrm := f
		for idx in [[0, 1, 2], [0, 2, 3]]:
			for k in idx:
				v.append(p[k])
				n.append(nrm)
				c.append(Color(col, sway))
				uv.append(q[k])
				uv2.append(Vector2(2.0, 0.0))
				parts.append(-1)

	func cylinder(base: Vector3, r: float, h: float, sides: int, col: Color, s0: float, s1: float, axis := Vector3.UP) -> void:
		var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var side2 := axis.cross(side).normalized()
		var top := base + axis * h
		mat = 0.0 if col.is_equal_approx(wood) else 1.0
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var o0 := (side * cos(a0) + side2 * sin(a0)) * r
			var o1 := (side * cos(a1) + side2 * sin(a1)) * r
			tri(base + o0, top + o1, base + o1, col, s0, s1, s0)
			tri(base + o0, top + o0, top + o1, col, s0, s1, s1)
		mat = 1.0

	func cone(base: Vector3, r: float, h: float, sides: int, col: Color, s0: float, s1: float) -> void:
		var tip := base + Vector3(0, h, 0)
		var is_wood := col.is_equal_approx(wood)
		mat = 0.0 if is_wood else 1.0
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p0 := base + Vector3(cos(a0), 0, sin(a0)) * r
			var p1 := base + Vector3(cos(a1), 0, sin(a1)) * r
			tri(p0, tip, p1, col, s0, s1, s0)
		# The underside is its own flat part (a hard edge at the skirt).
		part += 1
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			tri(base + Vector3(cos(a1), 0, sin(a1)) * r, base, base + Vector3(cos(a0), 0, sin(a0)) * r, col.darkened(0.25), s0, s0, s0)
		mat = 1.0
		if not is_wood:
			hang_from.append([base + Vector3(0, h * 0.2, 0), Vector3(r, h * 0.2, r)])
		# Foliage cones get ragged leaf cards around their skirt.
		if not is_wood and r > 0.1 and not far:
			for k in 4:
				var a := TAU * (k + rng.randf()) / 4.0
				var out := Vector3(cos(a), 0.0, sin(a))
				var y := rng.randf_range(0.1, 0.5) * h
				var rr := r * (1.0 - y / h)
				card(base + out * rr * 0.95 + Vector3(0, y, 0), out + Vector3(0, 0.6, 0), r * 0.42, col, lerpf(s0, s1, y / h))

	## Low-poly ellipsoid (a squashed octahedron split once).
	func blob(center: Vector3, radii: Vector3, col: Color, sway: float) -> void:
		part += 1
		var pts := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		var faces := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
		for f in faces:
			var a: Vector3 = pts[f[0]]
			var b2: Vector3 = pts[f[1]]
			var d: Vector3 = pts[f[2]]
			var ab := (a + b2).normalized()
			var bd := (b2 + d).normalized()
			var da := (d + a).normalized()
			for t in [[a, ab, da], [ab, b2, bd], [da, bd, d], [ab, bd, da]]:
				var u0: Vector3 = t[0]
				var u1: Vector3 = t[1]
				var u2: Vector3 = t[2]
				# Lighter toward the top, per vertex (a smooth gradient).
				tri3(center + u0 * radii, center + u1 * radii, center + u2 * radii,
					col * (0.85 + 0.15 * u0.y), col * (0.85 + 0.15 * u1.y), col * (0.85 + 0.15 * u2.y), sway, sway, sway)
		# Leaf-cluster cards around the crown break up the round silhouette.
		var mean_r := (radii.x + radii.y + radii.z) / 3.0
		if mean_r >= 0.12:
			var count := 10 if mean_r < 0.3 else 16
			for i in count:
				var d := Vector3(rng.randfn(), rng.randfn() * 0.8 + 0.25, rng.randfn()).normalized()
				var lit := 0.85 + 0.15 * d.y
				card(center + d * radii * 0.92, d, mean_r * 0.55, col * lit, sway)

	var trunk_top := Vector3.ZERO
	var trunk_h := 0.5
	var trunk_bend := 0.0

	## Trunk: 8-sided, tapering to `top_frac` of the base radius, bending
	## sideways by `bend` at the top, with a flared foot. Sways from 0 at
	## the ground to `s1` at the top.
	func trunk(r: float, h: float, bend: float, s1: float, top_frac := 0.45) -> void:
		var rings := [[0.0, 1.7], [0.05, 1.15], [0.45, 1.0], [1.0, 1.0]]
		if far:
			rings = [[0.0, 1.5], [0.4, 1.0], [1.0, 1.0]]
		var pts: Array = []
		for ring in rings:
			var t: float = ring[0]
			var rr := r * lerpf(1.0, top_frac, t) * float(ring[1])
			var off := Vector3(bend * t * t, 0, bend * 0.3 * t * t)
			pts.append([Vector3(0, t * h, 0) + off, rr, lerpf(0.0, s1, t)])
		tube(pts, 5 if far else 8, wood)
		trunk_top = pts[pts.size() - 1][0]
		trunk_h = h
		trunk_bend = bend

	## `count` branches leaving the trunk between heights y0 and y1, angled
	## up and out, ending inside the crown.
	func branches(count: int, y0: float, reach: float, y1: float, sway: float) -> void:
		if far:
			return
		for k in count:
			var a := TAU * (k + rng.randf_range(0.0, 0.5)) / count
			var y := lerpf(y0, minf(y1, trunk_h * 0.9), rng.randf())
			var tt := y / trunk_h
			var start := Vector3(trunk_bend * tt * tt, y, trunk_bend * 0.3 * tt * tt)
			var out := Vector3(cos(a), 0.0, sin(a))
			var end := start + out * reach + Vector3(0, reach * rng.randf_range(0.7, 1.1), 0)
			tube([[start, 0.022, sway * 0.6], [end, 0.01, sway]], 5, wood)

	## A tube along a polyline: `pts` = [[center, radius, sway], ...].
	func tube(pts: Array, sides: int, col: Color) -> void:
		mat = 0.0 if col.is_equal_approx(wood) else 1.0
		part += 1
		var rings: Array = []
		for i in pts.size():
			var p: Vector3 = pts[i][0]
			var next_p: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
			var prev_p: Vector3 = pts[maxi(i - 1, 0)][0]
			var axis := (next_p - prev_p).normalized()
			var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
			var side2 := axis.cross(side).normalized()
			var ring: Array = []
			for k in sides:
				var a := TAU * k / sides
				ring.append(p + (side * cos(a) + side2 * sin(a)) * float(pts[i][1]))
			rings.append(ring)
		for i in pts.size() - 1:
			var s0: float = pts[i][2]
			var s1: float = pts[i + 1][2]
			for k in sides:
				var k1 := (k + 1) % sides
				tri(rings[i][k], rings[i + 1][k1], rings[i][k1], col, s0, s1, s0)
				tri(rings[i][k], rings[i + 1][k], rings[i + 1][k1], col, s0, s1, s1)
		mat = 1.0

	## A crown of `lobes` overlapping, noise-displaced icospheres: one big
	## lobe at `center`, the rest clustered around its upper half. Faces
	## buried inside another lobe are dropped (the triangles go to the
	## silhouette). Leaf cards sit on the outer surface to rag the outline.
	func crown(center: Vector3, radii: Vector3, lobes: int, col: Color, sway: float, subdiv := PlantMeshes.CROWN_SUBDIV) -> void:
		if far:
			subdiv = maxi(subdiv - 1, 0)
		var specs: Array = [[center, radii, col]]
		for k in lobes - 1:
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / maxf(lobes - 1, 1)
			var dir := Vector3(cos(a), rng.randf_range(0.05, 0.45), sin(a)).normalized()
			var tone := col.lightened(0.08) if k % 2 == 0 else col.darkened(0.06)
			specs.append([center + dir * radii * 0.62, radii * rng.randf_range(0.5, 0.7), tone])
		for sp in specs:
			hang_from.append([sp[0], sp[1]])
		for i in specs.size():
			var others: Array = specs.duplicate()
			others.remove_at(i)
			lobe(specs[i][0], specs[i][1], specs[i][2], sway, subdiv, others)

	## One icosphere lobe with a lumpy surface and top-lit vertex shading;
	## faces inside any of `others` ([center, radii, ...]) are skipped.
	func lobe(center: Vector3, radii: Vector3, col: Color, sway: float, subdiv: int, others := []) -> void:
		part += 1
		var sphere: Array = PlantMeshes.icosphere(subdiv)
		var verts: PackedVector3Array = sphere[0]
		var faces: PackedInt32Array = sphere[1]
		var ph := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var disp := PackedVector3Array()
		var shade := PackedColorArray()
		for u in verts:
			var bump := 0.11 * sin(u.x * 3.1 + ph.x) * sin(u.y * 2.7 + ph.y) + 0.07 * sin(u.z * 4.3 + u.x * 1.7 + ph.z)
			disp.append(center + u * radii * (1.0 + bump))
			shade.append(col * (0.82 + 0.18 * u.y))
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b2 := faces[f + 1]
			var d := faces[f + 2]
			if _buried((disp[a] + disp[b2] + disp[d]) / 3.0, others):
				continue
			tri3(disp[a], disp[b2], disp[d], shade[a], shade[b2], shade[d], sway, sway, sway)
		var mean_r := (radii.x + radii.y + radii.z) / 3.0
		if mean_r >= 0.1 and not far:
			for i in 3:
				# Outward and mostly sideways or up: where the silhouette is.
				var d := Vector3(rng.randfn(), rng.randfn() * 0.6 + 0.3, rng.randfn()).normalized()
				var p := center + d * radii * 0.95
				if not _buried(p, others):
					card(p, d, mean_r * 0.55, col * (0.85 + 0.15 * d.y), sway)

	## Inside one of the lobes in `others` (with a margin for the bumps)?
	func _buried(p: Vector3, others: Array) -> bool:
		for o in others:
			if ((p - (o[0] as Vector3)) / ((o[1] as Vector3) * 0.86)).length() < 1.0:
				return true
		return false

	## Hanging vines (lianas, or beard lichen on conifers): `count` strands
	## from under the crown toward the ground, each two crossed ribbons in
	## three swaying segments. Hidden unless the site is wet (shader).
	func vines(count: int, col: Color) -> void:
		if far or hang_from.is_empty():
			return
		mat = 3.0
		for k in count:
			strand_key = (k + 0.5) / count
			part += 1
			var h: Array = hang_from[rng.randi() % hang_from.size()]
			var c: Vector3 = h[0]
			var rr: Vector3 = h[1]
			var a := rng.randf() * TAU
			var top := c + Vector3(cos(a) * rr.x * 0.75, -rr.y * 0.45, sin(a) * rr.z * 0.75)
			var length := minf(rng.randf_range(0.25, 0.5), top.y - 0.06)
			if length < 0.08:
				continue
			var w := 0.016
			var prev := top
			for seg in 3:
				var t1 := float(seg + 1) / 3.0
				var p := top + Vector3(sin(a + t1 * 2.0) * 0.03, -length * t1, cos(a + t1 * 2.0) * 0.03)
				var s0 := lerpf(0.8, 1.0, float(seg) / 3.0)
				var s1 := lerpf(0.8, 1.0, t1)
				var tone := col.darkened(0.1 * seg)
				for side in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
					tri(prev - side, p - side * 0.7, p + side * 0.7, tone, s0, s1, s1)
					tri(prev - side, p + side * 0.7, prev + side, tone, s0, s1, s0)
				prev = p
		strand_key = 0.0
		mat = 1.0

	## A bamboo clump: culms in a tight cluster (about an eighth of the
	## height across), rising straight and arching outward near the top,
	## each with feathery leaf sprays (cards) along its upper part. Culms
	## are material 4: the foliage shader rings them with nodes. The whole
	## clump sways, most at the tips.
	func bamboo(culm: Color, leaf: Color) -> void:
		var count := 4 if far else 7
		var sides := 5
		for k in count:
			var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / count
			var r0 := rng.randf_range(0.015, 0.06)
			var base := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
			var out := Vector3(cos(a), 0.0, sin(a))
			var h := rng.randf_range(0.72, 1.0)
			var lean := rng.randf_range(0.08, 0.2)
			var radius := rng.randf_range(0.006, 0.009)
			var pts: Array = []
			var rings := [0.0, 0.5, 0.8, 1.0] if not far else [0.0, 0.6, 1.0]
			for t in rings:
				# Straight low down, arching out toward the tip.
				var bend := out * lean * pow(t, 2.2) * h
				pts.append([base + Vector3(0, t * h, 0) + bend - Vector3(0, lean * 0.4 * pow(t, 3.0) * h, 0), radius * lerpf(1.0, 0.55, t), lerpf(0.0, 1.0, t)])
			mat = 4.0
			part += 1
			var rs: Array = []
			for i in pts.size():
				var p: Vector3 = pts[i][0]
				var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
				var prv: Vector3 = pts[maxi(i - 1, 0)][0]
				var axis := (nxt - prv).normalized()
				var s1 := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
				var s2 := axis.cross(s1).normalized()
				var ring: Array = []
				for j in sides:
					var ang := TAU * j / sides
					ring.append(p + (s1 * cos(ang) + s2 * sin(ang)) * float(pts[i][1]))
				rs.append(ring)
			for i in pts.size() - 1:
				var sw0: float = pts[i][2]
				var sw1: float = pts[i + 1][2]
				for j in sides:
					var j1 := (j + 1) % sides
					tri(rs[i][j], rs[i + 1][j1], rs[i][j1], culm, sw0, sw1, sw0)
					tri(rs[i][j], rs[i + 1][j], rs[i + 1][j1], culm, sw0, sw1, sw1)
			mat = 1.0
			# Feathery leaf sprays down the upper two-thirds of the culm,
			# small and many, drooping outward.
			var sprays := 2 if far else 5
			for n in sprays:
				var t := lerpf(0.38, 1.0, (n + rng.randf()) / sprays)
				var seg := int(t * (pts.size() - 1))
				var f := t * (pts.size() - 1) - seg
				var c: Vector3 = (pts[seg][0] as Vector3).lerp(pts[mini(seg + 1, pts.size() - 1)][0], f)
				var side := Vector3(rng.randfn(), 0.0, rng.randfn()).normalized()
				var dir := (out * 0.8 + side * 0.7 + Vector3(0, rng.randf_range(-0.35, 0.15), 0)).normalized()
				var size := h * rng.randf_range(0.045, 0.07) * (1.6 if far else 1.0)
				card(c + dir * size * 0.8, dir, size, leaf * rng.randf_range(0.8, 1.05), t)

	## Flat leaf from `base` outward along `dir`, drooping at the tip.
	func frond(base: Vector3, dir: Vector3, length: float, width: float, col: Color, sway: float) -> void:
		part += 1
		var d := dir.normalized()
		var side := d.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized() * width
		var mid := base + d * length * 0.55
		var tip := base + d * length + Vector3(0, -length * 0.15, 0)
		tri(base, mid + side, mid - side, col, sway * 0.4, sway, sway)
		tri(mid - side, mid + side, tip, col.lightened(0.05), sway, sway, sway)

	## Thin grass blade from base to tip.
	func blade(base: Vector3, tip: Vector3, width: float, col: Color, sway: float) -> void:
		part += 1
		var side := (tip - base).cross(Vector3.FORWARD).normalized() * width
		if side.length() < 1e-4:
			side = Vector3(width, 0, 0)
		tri(base - side, tip, base + side, col, 0.0, sway, 0.0)

	## Straight root/strut from a to b.
	func strut(a: Vector3, b2: Vector3, r: float, col: Color) -> void:
		var axis := (b2 - a)
		cylinder(a, r, axis.length(), 4, col, 0.0, 0.1, axis.normalized())

	## Hanging strand from `top` down by `length`, sways fully.
	func strand(top: Vector3, length: float, width: float, col: Color) -> void:
		part += 1
		var bottom := top + Vector3(0, -length, 0)
		var s := Vector3(width, 0, 0)
		var s2 := Vector3(0, 0, width)
		tri(top - s, bottom, top + s, col, 0.4, 1.0, 0.4)
		tri(top - s2, bottom, top + s2, col.darkened(0.1), 0.4, 1.0, 0.4)

	## Flat irregular patch on the ground.
	func disc(center: Vector3, r: float, h: float, sides: int, col: Color, sway: float) -> void:
		part += 1
		var top := center + Vector3(0, h, 0)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var r0 := r * (0.75 + 0.25 * sin(a0 * 3.0))
			var r1 := r * (0.75 + 0.25 * sin(a1 * 3.0))
			var p0 := center + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p1 := center + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			tri(p0, top, p1, col, sway, sway, sway)

	func commit() -> ArrayMesh:
		# Baked ambient occlusion: the base of each plant (trunk foot, grass
		# roots) is darker, the way it would be in its own shadow. Hanging
		# plants grow down from their origin (y < 0) and are left alone.
		for i in v.size():
			var y := v[i].y
			if y >= 0.0 and y < 0.14:
				var k := lerpf(0.58, 1.0, smoothstep(0.0, 0.14, y))
				c[i] = Color(c[i].r * k, c[i].g * k, c[i].b * k, c[i].a)
		_smooth()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

	## Smooth shading: every vertex of a part gets the area-weighted mean
	## of the face normals meeting at its position in that part.
	func _smooth() -> void:
		var acc := {}
		var keys: Array = []
		keys.resize(v.size())
		for t in range(0, v.size(), 3):
			var fn := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
			for k in 3:
				var i := t + k
				if parts[i] < 0:
					continue
				var q := Vector3i(v[i] * 20000.0)
				var key := Vector4i(parts[i], q.x, q.y, q.z)
				keys[i] = key
				acc[key] = acc.get(key, Vector3.ZERO) + fn
		for i in v.size():
			if parts[i] < 0:
				continue
			var sum: Vector3 = acc[keys[i]]
			if sum.length_squared() > 1e-12:
				n[i] = sum.normalized()

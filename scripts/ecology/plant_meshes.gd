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


static func mesh_for(sp: PlantSpecies) -> ArrayMesh:
	var idx := SpeciesDB.index_of(sp)
	if _cache.has(idx):
		return _cache[idx]
	var b := _Builder.new()
	var leaf := sp.color
	var wood := sp.accent
	b.wood = wood
	b.rng.seed = idx * 7919 + 11
	if sp.shape == S.CACTUS:
		b.wood = leaf # ribbed: the bark streaks read as cactus ribs
	match sp.shape:
		S.CONIFER:
			b.cylinder(Vector3.ZERO, 0.035, 0.3, 5, wood, 0.0, 0.2)
			b.cone(Vector3(0, 0.15, 0), 0.3, 0.45, 7, leaf.darkened(0.1), 0.2, 0.6)
			b.cone(Vector3(0, 0.4, 0), 0.23, 0.4, 7, leaf, 0.5, 0.85)
			b.cone(Vector3(0, 0.65, 0), 0.15, 0.35, 7, leaf.lightened(0.08), 0.8, 1.0)
		S.BROADLEAF:
			b.cylinder(Vector3.ZERO, 0.045, 0.5, 6, wood, 0.0, 0.3)
			b.blob(Vector3(0, 0.68, 0), Vector3(0.34, 0.3, 0.34), leaf, 0.8)
			b.blob(Vector3(0.14, 0.8, 0.05), Vector3(0.22, 0.2, 0.22), leaf.lightened(0.1), 1.0)
			b.blob(Vector3(-0.12, 0.76, -0.1), Vector3(0.2, 0.18, 0.2), leaf.darkened(0.08), 1.0)
		S.GNARLED:
			b.cylinder(Vector3.ZERO, 0.07, 0.3, 5, wood, 0.0, 0.2)
			b.cylinder(Vector3(0.05, 0.28, 0), 0.05, 0.25, 5, wood, 0.2, 0.4, Vector3(0.3, 1, 0).normalized())
			b.blob(Vector3(0.12, 0.7, 0), Vector3(0.38, 0.2, 0.32), leaf, 0.8)
			b.blob(Vector3(-0.15, 0.62, 0.1), Vector3(0.25, 0.16, 0.25), leaf.darkened(0.1), 0.9)
		S.EMERGENT:
			b.cylinder(Vector3.ZERO, 0.025, 0.85, 6, wood, 0.0, 0.5)
			b.blob(Vector3(0, 0.9, 0), Vector3(0.24, 0.1, 0.24), leaf, 1.0)
			b.blob(Vector3(0.12, 0.93, 0.08), Vector3(0.16, 0.08, 0.16), leaf.lightened(0.08), 1.0)
		S.UMBRELLA:
			b.cylinder(Vector3.ZERO, 0.04, 0.6, 5, wood, 0.0, 0.3, Vector3(0.1, 1, 0).normalized())
			b.blob(Vector3(0.05, 0.82, 0), Vector3(0.6, 0.1, 0.55), leaf, 1.0)
		S.PALM:
			b.cylinder(Vector3.ZERO, 0.03, 0.92, 5, wood, 0.0, 0.6, Vector3(0.08, 1, 0).normalized())
			for k in 7:
				var a := TAU * k / 7.0
				b.frond(Vector3(0.07, 0.92, 0), Vector3(cos(a), -0.35, sin(a)), 0.45, 0.07, leaf, 1.0)
		S.CYPRESS:
			b.cone(Vector3.ZERO, 0.12, 0.25, 6, wood, 0.0, 0.1)
			b.cylinder(Vector3(0, 0.2, 0), 0.04, 0.5, 6, wood, 0.1, 0.4)
			b.blob(Vector3(0, 0.72, 0), Vector3(0.16, 0.3, 0.16), leaf, 0.9)
		S.MANGROVE:
			for k in 5:
				var a := TAU * k / 5.0
				b.strut(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(0, 0.3, 0), 0.02, wood)
			b.cylinder(Vector3(0, 0.28, 0), 0.04, 0.35, 5, wood, 0.1, 0.4)
			b.blob(Vector3(0, 0.75, 0), Vector3(0.4, 0.22, 0.4), leaf, 0.9)
		S.ROSETTE:
			b.cylinder(Vector3.ZERO, 0.07, 0.75, 6, wood, 0.0, 0.3)
			for k in 10:
				var a := TAU * k / 10.0
				b.frond(Vector3(0, 0.78, 0), Vector3(cos(a), 0.7, sin(a)), 0.25, 0.06, leaf, 1.0)
		S.SPIKE_ROSETTE:
			b.blob(Vector3(0, 0.12, 0), Vector3(0.22, 0.13, 0.22), leaf, 0.1)
			b.cone(Vector3(0, 0.2, 0), 0.07, 0.8, 6, wood, 0.2, 0.6)
		S.SHRUB:
			b.blob(Vector3(0, 0.45, 0), Vector3(0.5, 0.45, 0.5), leaf, 0.6)
			b.blob(Vector3(0.2, 0.6, 0.12), Vector3(0.32, 0.3, 0.32), leaf.lightened(0.08), 0.9)
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
		_:
			b.blob(Vector3(0, 0.5, 0), Vector3(0.4, 0.5, 0.4), leaf, 0.8)
	var mesh := b.commit()
	_cache[idx] = mesh
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

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, sa: float, sb: float, sd: float) -> void:
		tri3(a, b, d, col, col, col, sa, sb, sd)

	func tri3(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, sa: float, sb: float, sd: float) -> void:
		var nrm := (b - a).cross(d - a).normalized()
		v.append_array([a, b, d])
		n.append_array([nrm, nrm, nrm])
		c.append_array([Color(ca, sa), Color(cb, sb), Color(cd, sd)])
		uv.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var m := Vector2(mat, 0.0)
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
		# Foliage cones get ragged leaf cards around their skirt.
		if not is_wood and r > 0.1:
			for k in 6:
				var a := TAU * (k + rng.randf()) / 6.0
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

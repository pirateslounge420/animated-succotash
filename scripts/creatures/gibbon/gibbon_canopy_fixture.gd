class_name GibbonCanopyFixture
## A synthetic rainforest canopy for building and testing the gibbon
## (spec Phase 1 (iii)) before the real branch graphs exist. It fills the
## BranchGraph contract exactly the way the tree code will: one graph per
## tree, handholds in the tree's own frame, links along the wood, all
## registered with BranchGraphs under one Node3D "chunk".
##
## Eight trees 15-30 m tall stand 5-9 m apart in two staggered rows, so
## their crowns overlap like a rainforest's. Each has a trunk and 3-5
## limbs (a few with a side branch), handholds every ~0.5 m, the wood
## tapering from 0.25 m (the trunk's foot) to 0.035 m (twig tips).
##
## With `visuals` on it also draws the wood (tapered tubes along the
## handholds) and a few leafy lobes above each limb, in the plants' own
## material (PlantMeshes, the foliage shader), so the test canopy looks
## like the forest. Nothing here collides: it's a test prop, not a tree.

## Tree layout: rows along +X, the second row offset half a step.
const ROW_STEP_M := 6.6
const ROW_GAP_M := 5.8
const JITTER_M := 0.8
## Wood colors (sRGB): the rainforest's bark accent and canopy leaves
## (data/biomes/19_tropical_rainforest.json), pulled onto the R1a
## palette by the foliage shader.
const BARK := Color("#5c422e")
const LEAVES := Color("#146624")


## Builds the canopy under `parent` and registers its graphs. Returns the
## chunk node (its graphs are in `chunk.get_meta("graphs")`, its leafy
## lobes as [center, radii] in the chunk's frame in "lobes", for cameras
## to keep clear of). The chunk's
## +Y is up: `place` puts it on the ground with its basis turned to the
## local up, and `ground` (chunk x, z as a Vector2 -> the ground's height
## in the chunk, m), if given, stands each trunk on uneven ground. The
## trees run along the chunk's +X, the two rows at z 0 and ROW_GAP_M.
static func build(parent: Node3D, seed_value := 7, count := 8, visuals := true, place := Transform3D.IDENTITY, ground := Callable()) -> Node3D:
	var chunk := Node3D.new()
	chunk.name = "GibbonCanopy"
	parent.add_child(chunk)
	chunk.transform = place
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var graphs: Array[BranchGraph] = []
	var lobes: Array = []
	# Canopy heights: most trees in the 20-28 m layer, one emergent and
	# one understory tree, so crowns meet but not all at one height.
	var heights := [24.0, 21.0, 27.0, 18.0, 25.0, 30.0, 22.0, 16.0, 26.0, 20.0]
	for t in count:
		var row := t % 2
		var col := t / 2
		var at := Vector3(col * ROW_STEP_M + row * ROW_STEP_M * 0.5, 0.0, row * ROW_GAP_M)
		at += Vector3(rng.randf_range(-JITTER_M, JITTER_M), 0.0, rng.randf_range(-JITTER_M, JITTER_M))
		if ground.is_valid():
			at.y = float(ground.call(Vector2(at.x, at.z))) - 0.3
		var h: float = heights[t % heights.size()] + rng.randf_range(-1.0, 1.0)
		var g := BranchGraph.new()
		g.key = hash([seed_value, t, "gibbon_fixture"])
		g.species = -1
		g.height_m = h
		g.chunk = chunk
		g.xform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
		_grow(g, h, rng)
		BranchGraphs.add(g)
		graphs.append(g)
		if visuals:
			chunk.add_child(_tree_mesh(g, rng, lobes))
	chunk.set_meta("graphs", graphs)
	chunk.set_meta("lobes", lobes)
	chunk.tree_exiting.connect(func() -> void:
		for g in graphs:
			BranchGraphs.remove(g.key))
	return chunk


## Trunk handholds, then the limbs and their side branches.
static func _grow(g: BranchGraph, h: float, rng: RandomNumberGenerator) -> void:
	var base_r := 0.25
	var top_r := 0.09
	var n := int(h / BranchGraph.SPACING_M)
	for k in n + 1:
		var y := float(k) * h / n
		_add(g, Vector3(0, y, 0), Vector3.UP, lerpf(base_r, top_r, y / h), 0)
		if k > 0:
			_link(g, k - 1, k)
	var limbs := rng.randi_range(3, 5)
	var yaw0 := rng.randf() * TAU
	var limb_id := 1
	for l in limbs:
		var yaw := yaw0 + TAU * l / limbs + rng.randf_range(-0.35, 0.35)
		var y0 := h * rng.randf_range(0.58, 0.84)
		var trunk_i := int(round(y0 / h * n))
		var r0 := lerpf(base_r, top_r, y0 / h) * rng.randf_range(0.5, 0.62)
		var length := rng.randf_range(4.6, 7.2)
		var rise := deg_to_rad(rng.randf_range(16.0, 38.0))
		var out := Vector3(cos(yaw), 0, sin(yaw))
		var first := _limb(g, Vector3(0, y0, 0), out, rise, -0.14, length, r0, limb_id, rng)
		_link(g, trunk_i, first)
		var this_limb := limb_id
		limb_id += 1
		# Side branches off the outer half of some limbs.
		var sides := rng.randi_range(0, 2)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		for s in sides:
			side = -side
			var along := rng.randf_range(0.4, 0.7)
			var fork := _nearest_on_limb(g, this_limb, along)
			if fork < 0:
				continue
			var t: Vector3 = g.tangent[fork]
			var flat := Vector3(t.x, 0, t.z).normalized()
			var dir := flat.rotated(Vector3.UP, side * rng.randf_range(0.6, 1.1))
			var b_first := _limb(g, g.local[fork], dir, deg_to_rad(rng.randf_range(5.0, 22.0)), -0.1,
				rng.randf_range(1.6, 3.0), maxf(g.radius[fork] * 0.7, 0.05), limb_id, rng)
			_link(g, fork, b_first)
			limb_id += 1


## One limb from `from` outward along `out` (horizontal), rising at
## `rise` at first and bending by `bend` (radians per meter, negative:
## drooping) toward the tip. Radius tapers from r0 to the thinnest wood.
## Returns the index of its first handhold.
static func _limb(g: BranchGraph, from: Vector3, out: Vector3, rise: float, bend: float, length: float, r0: float, limb_id: int, rng: RandomNumberGenerator) -> int:
	var steps := int(length / BranchGraph.SPACING_M)
	var p := from
	var first := -1
	var prev := -1
	var wobble := rng.randf_range(-0.08, 0.08)
	# Start just outside the trunk's bark.
	var s0 := 0.45
	for k in steps:
		var s := s0 + k * BranchGraph.SPACING_M
		var elev := rise + bend * s
		var dir := (out.rotated(Vector3.UP, wobble * s) * cos(elev) + Vector3.UP * sin(elev)).normalized()
		p = (from + out * s0) if k == 0 else p + dir * BranchGraph.SPACING_M
		var r := lerpf(r0, BranchGraph.MIN_RADIUS_M, clampf(s / length, 0.0, 1.0))
		var i := _add(g, p, dir, r, limb_id)
		if prev >= 0:
			_link(g, prev, i)
		else:
			first = i
		prev = i
	return first


static func _nearest_on_limb(g: BranchGraph, limb_id: int, along: float) -> int:
	var ids: Array[int] = []
	for i in g.size():
		if g.limb[i] == limb_id:
			ids.append(i)
	if ids.size() < 3:
		return -1
	return ids[clampi(int(along * ids.size()), 1, ids.size() - 2)]


static func _add(g: BranchGraph, p: Vector3, t: Vector3, r: float, limb_id: int) -> int:
	g.local.append(p)
	g.tangent.append(t.normalized())
	g.radius.append(maxf(r, BranchGraph.MIN_RADIUS_M))
	g.limb.append(limb_id)
	g.links.append(PackedInt32Array())
	return g.local.size() - 1


static func _link(g: BranchGraph, a: int, b: int) -> void:
	g.links[a].append(b)
	g.links[b].append(a)


# --- Looks ---------------------------------------------------------------------

## The tree as one mesh in the plants' material: tapered tubes along each
## piece of wood (bark, no sway: thick wood doesn't move) and leafy lobes
## over the limbs (leaves, swaying), in the tree's frame.
static func _tree_mesh(g: BranchGraph, rng: RandomNumberGenerator, lobes: Array) -> MeshInstance3D:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	# Wood: walk each limb (the trunk is limb 0) as a polyline.
	var by_limb := {}
	for i in g.size():
		if not by_limb.has(g.limb[i]):
			by_limb[g.limb[i]] = []
		by_limb[g.limb[i]].append(i)
	for l in by_limb:
		var ids: Array = by_limb[l]
		var pts := PackedVector3Array()
		var rads := PackedFloat32Array()
		if l != 0:
			# Root each limb in the wood it grows from.
			for j in g.links[ids[0]]:
				if g.limb[j] != l:
					pts.append(g.local[j])
					rads.append(g.radius[ids[0]])
					break
		for i in ids:
			pts.append(g.local[i])
			rads.append(g.radius[i])
		# A short tapered tip past the last handhold.
		var last: int = ids[ids.size() - 1]
		pts.append(g.local[last] + g.tangent[last] * 0.35)
		rads.append(0.012)
		_tube(pts, rads, 9 if l == 0 else 6, BARK, v, nrm, col, uv2, idx)
	# Leaves: lobes over the outer two thirds of each limb, and a top.
	var sphere: Array = PlantMeshes.geosphere(2)
	for l in by_limb:
		if l == 0:
			continue
		var ids: Array = by_limb[l]
		var n := ids.size()
		var k := int(n * 0.35)
		while k < n:
			var i: int = ids[k]
			# Above the wood, clear of a monkey hanging under it or sitting
			# on it (a sitting head is ~0.55 m up; lobes are half as tall
			# as they are wide).
			var c: Vector3 = g.local[i] + Vector3.UP * rng.randf_range(1.5, 1.9)
			var rad := rng.randf_range(1.1, 1.7) * (0.8 if n < 8 else 1.0)
			_lobe(sphere, c, Vector3(rad, rad * 0.5, rad), LEAVES.lerp(Color("#2a7a30"), rng.randf()), v, nrm, col, uv2, idx)
			lobes.append([g.xform * c, Vector3(rad, rad * 0.5, rad)])
			k += rng.randi_range(3, 5)
	var top: Vector3 = g.local[0] + Vector3.UP * g.height_m
	_lobe(sphere, top + Vector3.UP * 0.6, Vector3(2.0, 1.2, 2.0), LEAVES, v, nrm, col, uv2, idx)
	lobes.append([g.xform * (top + Vector3.UP * 0.6), Vector3(2.0, 1.2, 2.0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "FixtureTree"
	mi.mesh = mesh
	mi.material_override = PlantMeshes.material()
	mi.transform = g.xform
	return mi


## A tube through `pts` with radii `rads`, `sides` around, wound so Godot
## draws it from outside.
static func _tube(pts: PackedVector3Array, rads: PackedFloat32Array, sides: int, c: Color, v: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, uv2: PackedVector2Array, idx: PackedInt32Array) -> void:
	var base := v.size()
	var n := pts.size()
	# A frame carried along the tube (no twisting between rings).
	var a := Vector3.ZERO
	for k in n:
		var t: Vector3 = (pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]).normalized()
		if k == 0:
			a = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		else:
			a = (a - t * a.dot(t)).normalized()
		var b := t.cross(a)
		for s in sides:
			var ang := TAU * s / sides
			var d := a * cos(ang) + b * sin(ang)
			v.append(pts[k] + d * rads[k])
			nrm.append(d)
			col.append(Color(c.r, c.g, c.b, 0.0))
			uv2.append(Vector2(0.0, 0.0))
	for k in n - 1:
		for s in sides:
			var i0 := base + k * sides + s
			var i1 := base + k * sides + (s + 1) % sides
			var j0 := i0 + sides
			var j1 := i1 + sides
			idx.append_array([i0, j1, i1, i0, j0, j1])
	_wind_outward(v, nrm, idx, base)


static func _lobe(sphere: Array, center: Vector3, radii: Vector3, c: Color, v: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, uv2: PackedVector2Array, idx: PackedInt32Array) -> void:
	var base := v.size()
	var sv: PackedVector3Array = sphere[0]
	var si: PackedInt32Array = sphere[1]
	for p in sv:
		v.append(center + p * radii)
		nrm.append((p / radii).normalized())
		col.append(Color(c.r, c.g, c.b, 1.0))
		uv2.append(Vector2(1.0, 0.0))
	for i in si:
		idx.append(base + i)
	_wind_outward(v, nrm, idx, base)


## Godot draws triangles whose (b - a) x (c - a) points inward as front
## faces; flip any that don't agree with their normals.
static func _wind_outward(v: PackedVector3Array, nrm: PackedVector3Array, idx: PackedInt32Array, first_vertex: int) -> void:
	var start := 0
	while start < idx.size() and idx[start] < first_vertex:
		start += 3
	for t in range(start, idx.size(), 3):
		var a := v[idx[t]]
		var cr := (v[idx[t + 1]] - a).cross(v[idx[t + 2]] - a)
		if cr.dot(nrm[idx[t]] + nrm[idx[t + 1]] + nrm[idx[t + 2]]) > 0.0:
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp

class_name FarShell
extends Node3D
## Coarse whole-planet terrain and sea shells, for the long view distances
## DESIGN.md asks for. The planet is small (a standing player's horizon is
## ~465 m away), but mountains poke above it from many kilometers off. The
## streamed chunks cover the near ground; these shells draw everything
## beyond, sampled from the same TerrainField so they line up. The shells
## sit a little below the true surface and are cut away near the camera,
## so they never poke through the detailed chunks.
##
## The node sits at the planet center; being a child of World.world_root,
## it moves with the floating origin.

## Quads per cube-face edge (~1.6 km). 96 until design 6 Oct §ER.1: past
## the render distance the fog is full, so the shells only show as pale
## silhouettes against the sky, and 64 draws those the same for less than
## half the triangles.
const RES := 64
const SINK_M := 30.0

var _terrain_mat: ShaderMaterial
var _sea_mat: ShaderMaterial
## How far off a face's ground may be and still be drawn (m): an 885 m
## summit is over the horizon from eye height past ~11 km on this planet.
const SEEN_M := 12000.0
## Each face's 9 x 9 sample directions (update_faces()).
var _face_samples: Array[PackedVector3Array] = []
var _faces_at := Vector3.ZERO


## Show only the faces with ground within SEEN_M of `d` (the player's
## surface direction); a sample spacing's slack (~1/8 of a face) on top.
func update_faces(d: Vector3) -> void:
	if _face_samples.is_empty() or (_faces_at != Vector3.ZERO and _faces_at.distance_to(d) * PlanetConst.RADIUS_M < 2000.0):
		return
	_faces_at = d
	# (Plus half a sample spacing's diagonal: a face's nearest ground can
	# lie between its samples.)
	var reach := (SEEN_M + PlanetConst.CIRCUMFERENCE_M / 4.0 / 8.0 * 0.71) / PlanetConst.RADIUS_M
	var show := []
	for f in 6:
		var near := false
		for p in _face_samples[f]:
			if p.angle_to(d) < reach:
				near = true
				break
		show.append(near)
	for ch in get_children():
		if ch.has_meta("face"):
			(ch as Node3D).visible = show[int(ch.get_meta("face"))]


func build(world: Node) -> void:
	var map: PlanetData = world.planet
	position = world.planet_center()
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/far_terrain.gdshader")
	_sea_mat = ShaderMaterial.new()
	# The sea has its own shader, in the near water's palette (flat day
	# blue, the same night glow), so the two meet without a band.
	_sea_mat.shader = preload("res://shaders/far_sea.gdshader")
	_sea_mat.set_shader_parameter("hide_radius", 600.0)
	_sea_mat.set_shader_parameter("water_color", TerrainChunk.WATER)
	Look.register(_terrain_mat)
	Look.register(_sea_mat)

	# One node per cube face (§ER.1), and only the faces with ground within
	# SEEN_M of you drawn (update_faces()): nothing farther shows over the
	# horizon, and a face's box is planet-sized, so the camera never culls
	# it alone.
	for pair in [[true, "FarTerrain", _terrain_mat], [false, "FarSea", _sea_mat]]:
		var faces := _sphere_mesh(map, pair[0])
		for f in faces.size():
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [pair[1], f]
			mi.mesh = faces[f]
			mi.material_override = pair[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("face", f)
			add_child(mi)
	for f in 6:
		var pts := PackedVector3Array()
		for j in 9:
			for i in 9:
				pts.append(CubeSphere.to_dir(f, -1.0 + 2.0 * i / 8.0, -1.0 + 2.0 * j / 8.0))
		_face_samples.append(pts)


## The shell, one mesh per cube face.
func _sphere_mesh(map: PlanetData, terrain: bool) -> Array[ArrayMesh]:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var n := RES + 1
	for f in 6:
		var base := verts.size()
		for j in n:
			for i in n:
				var d := CubeSphere.to_dir(f, -1.0 + 2.0 * i / RES, -1.0 + 2.0 * j / RES)
				var r := PlanetConst.RADIUS_M - 8.0
				if terrain:
					r = PlanetConst.RADIUS_M + map.terrain.elevation(d, false) - SINK_M
					colors.append(TerrainChunk._biome_blend(map, d))
				verts.append(d * r)
				normals.append(d)
		for j in RES:
			for i in RES:
				var a := base + j * n + i
				indices.append_array([a, a + n + 1, a + 1, a, a + n, a + n + 1])
	if terrain:
		normals = _smooth_normals(verts, indices)
	var out: Array[ArrayMesh] = []
	var nv := n * n
	var ni := RES * RES * 6
	for f in 6:
		var fi := indices.slice(f * ni, (f + 1) * ni)
		for k in fi.size():
			fi[k] -= f * nv
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts.slice(f * nv, (f + 1) * nv)
		arrays[Mesh.ARRAY_NORMAL] = normals.slice(f * nv, (f + 1) * nv)
		if terrain:
			arrays[Mesh.ARRAY_COLOR] = colors.slice(f * nv, (f + 1) * nv)
		arrays[Mesh.ARRAY_INDEX] = fi
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.append(mesh)
	return out


## Smooth vertex normals: each vertex averages the (area-weighted) normals
## of the triangles around it, so distant slopes shade instead of reading
## as one flat radial tone.
static func _smooth_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(verts.size())
	for k in range(0, indices.size(), 3):
		var a := indices[k]
		var b := indices[k + 1]
		var c := indices[k + 2]
		var fn := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if fn.dot(verts[a]) < 0.0:
			fn = -fn
		out[a] += fn
		out[b] += fn
		out[c] += fn
	for i in out.size():
		out[i] = out[i].normalized() if out[i].length_squared() > 0.0 else verts[i].normalized()
	return out

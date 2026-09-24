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

const RES := 96 # quads per cube-face edge (~1 km)
const SINK_M := 30.0

var _terrain_mat: ShaderMaterial
var _sea_mat: ShaderMaterial


func build(world: Node) -> void:
	var map: PlanetData = world.planet
	position = world.planet_center()
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/far_terrain.gdshader")
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = preload("res://shaders/far_terrain.gdshader")
	_sea_mat.set_shader_parameter("is_sea", true)
	_sea_mat.set_shader_parameter("hide_radius", 600.0)
	Look.register(_terrain_mat)
	Look.register(_sea_mat)

	var land := MeshInstance3D.new()
	land.name = "FarTerrain"
	land.mesh = _sphere_mesh(map, true)
	land.material_override = _terrain_mat
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)

	var sea := MeshInstance3D.new()
	sea.name = "FarSea"
	sea.mesh = _sphere_mesh(map, false)
	sea.material_override = _sea_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


func _sphere_mesh(map: PlanetData, terrain: bool) -> ArrayMesh:
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
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if terrain:
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

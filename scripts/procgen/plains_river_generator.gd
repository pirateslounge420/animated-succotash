extends Node3D
## Generates one Plains chunk with a carved, navigable river (docs/implementation-notes.md
## section 3.2) as its own greybox mesh + collision + water plane.
##
## Flat/faceted low-poly shading (no shared vertices between triangles)
## and vertex-color blending stand in for real art per the "prototype
## uses greybox/primitive geometry" note in docs/implementation-notes.md section 8.

const LAND_COLOR := Color(0.35, 0.55, 0.25)
const BANK_COLOR := Color(0.65, 0.55, 0.35)
const RIVERBED_COLOR := Color(0.15, 0.35, 0.45)

@export var chunk_size: float = 64.0
@export var resolution: int = 48
@export var origin_x: float = -32.0
@export var origin_z: float = -32.0


func _ready() -> void:
	_generate_terrain()
	_generate_water()


func _vertex_color(x: float, z: float) -> Color:
	var mask := WorldGenConfig.river_mask(x, z)
	if mask < 0.5:
		return LAND_COLOR.lerp(BANK_COLOR, mask * 2.0)
	return BANK_COLOR.lerp(RIVERBED_COLOR, (mask - 0.5) * 2.0)


func _add_vertex(st: SurfaceTool, x: float, z: float) -> void:
	var y := WorldGenConfig.height_at(x, z)
	st.set_color(_vertex_color(x, z))
	st.add_vertex(Vector3(x, y, z))


func _generate_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step := chunk_size / float(resolution)
	for iz in range(resolution):
		for ix in range(resolution):
			var x0 := origin_x + ix * step
			var x1 := origin_x + (ix + 1) * step
			var z0 := origin_z + iz * step
			var z1 := origin_z + (iz + 1) * step

			# Two triangles per grid cell. Vertices are not shared between
			# triangles/cells, so generate_normals() below produces flat,
			# faceted shading (the low-poly look called for in docs/implementation-notes.md
			# section 2) instead of smoothed terrain.
			_add_vertex(st, x0, z0)
			_add_vertex(st, x0, z1)
			_add_vertex(st, x1, z0)

			_add_vertex(st, x1, z0)
			_add_vertex(st, x0, z1)
			_add_vertex(st, x1, z1)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	add_child(static_body)


func _generate_water() -> void:
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(chunk_size, chunk_size)

	var water_instance := MeshInstance3D.new()
	water_instance.name = "WaterPlane"
	water_instance.mesh = water_mesh
	water_instance.position = Vector3(
		origin_x + chunk_size * 0.5,
		WorldGenConfig.WATER_LEVEL,
		origin_z + chunk_size * 0.5
	)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.45, 0.65, 0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic = 0.1
	water_instance.material_override = material

	add_child(water_instance)

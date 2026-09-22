extends Node3D
## Renders a generated WorldMapData for visual validation of the
## world-gen pipeline (DESIGN.md section 3) -- a single flat mesh over
## the whole generated region, vertex-colored by whichever display_mode
## is selected, plus placeholder foliage markers (MultiMesh boxes, not
## real models -- see FoliageType). This is a validation tool, not a
## gameplay chunk: real gameplay will stream chunks (DESIGN.md roadmap
## item 6), querying the same WorldMapGenerator/passes.
##
## Press 1-5 at runtime to switch what the vertex color represents
## (biome / height / temperature / moisture / fog chance) without
## regenerating the underlying data -- this is the fastest way to
## confirm the moisture rain-shadow pattern is behaving: switch to
## MOISTURE (4) and look for a clear wet/dry split across any mountain
## ridge.

enum DisplayMode { BIOME, HEIGHT, TEMPERATURE, MOISTURE, FOG_CHANCE }

@export var world_seed: int = 1
@export var resolution: int = 128
@export var world_size: float = 512.0
@export var sea_level: float = 0.0
@export var display_mode: DisplayMode = DisplayMode.BIOME

var _map: WorldMapData
var _mesh_instance: MeshInstance3D
var _biome_colors: Dictionary = {}

const RIVER_COLOR := Color(0.25, 0.5, 0.75)
const RIVER_CARVE_DEPTH := 0.6

const HEIGHT_DISPLAY_MIN := -10.0
const HEIGHT_DISPLAY_MAX := 30.0

const TEMPERATURE_COLD := Color(0.2, 0.4, 0.9)
const TEMPERATURE_HOT := Color(0.9, 0.25, 0.15)

const MOISTURE_DRY := Color(0.6, 0.45, 0.25)
const MOISTURE_WET := Color(0.15, 0.35, 0.75)


func _ready() -> void:
	_biome_colors = {
		WorldGenConfig.Biome.FOREST: Color(0.25, 0.5, 0.22),
		WorldGenConfig.Biome.MOUNTAINS: Color(0.55, 0.53, 0.5),
		WorldGenConfig.Biome.DESERT: Color(0.82, 0.68, 0.4),
		WorldGenConfig.Biome.OCEAN: Color(0.15, 0.35, 0.55),
		WorldGenConfig.Biome.PLAINS: Color(0.55, 0.68, 0.3),
		WorldGenConfig.Biome.SNOW_TUNDRA: Color(0.85, 0.88, 0.92),
		WorldGenConfig.Biome.SWAMP: Color(0.35, 0.4, 0.28),
	}

	var foliage_types := DefaultFoliageTypes.get_all()
	_map = WorldMapGenerator.generate(world_seed, resolution, world_size, sea_level, foliage_types)

	_build_mesh()
	_build_water_plane()
	_build_foliage_markers()
	_print_debug_summary()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var new_mode := -1
		match event.physical_keycode:
			KEY_1: new_mode = DisplayMode.BIOME
			KEY_2: new_mode = DisplayMode.HEIGHT
			KEY_3: new_mode = DisplayMode.TEMPERATURE
			KEY_4: new_mode = DisplayMode.MOISTURE
			KEY_5: new_mode = DisplayMode.FOG_CHANCE
		if new_mode != -1 and new_mode != display_mode:
			display_mode = new_mode
			print("[WorldMapView] display_mode = %s" % DisplayMode.keys()[display_mode])
			_rebuild_visual_mesh()


func _color_for_cell(idx: int) -> Color:
	match display_mode:
		DisplayMode.HEIGHT:
			var h01 := clampf(inverse_lerp(HEIGHT_DISPLAY_MIN, HEIGHT_DISPLAY_MAX, _map.height[idx]), 0.0, 1.0)
			return Color(h01, h01, h01)
		DisplayMode.TEMPERATURE:
			return TEMPERATURE_COLD.lerp(TEMPERATURE_HOT, _map.temperature[idx])
		DisplayMode.MOISTURE:
			return MOISTURE_DRY.lerp(MOISTURE_WET, _map.moisture[idx])
		DisplayMode.FOG_CHANCE:
			var f := _map.fog_chance[idx]
			return Color(f, f, f)
		_: # BIOME
			if _map.water_type[idx] == WorldMapData.WaterType.RIVER:
				return RIVER_COLOR
			return _biome_colors.get(_map.biome[idx], Color.MAGENTA)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for y in range(_map.resolution - 1):
		for x in range(_map.resolution - 1):
			_add_quad(st, x, y)

	st.generate_normals()
	var mesh := st.commit()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "WorldMapMesh"
	_mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	var static_body := StaticBody3D.new()
	static_body.name = "WorldMapCollision"
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	add_child(static_body)


## Rebuilds only the visual mesh + its collision (not the underlying
## WorldMapData), used when display_mode changes at runtime.
func _rebuild_visual_mesh() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	var collision := get_node_or_null("WorldMapCollision")
	if collision:
		collision.queue_free()
	_build_mesh()


func _add_quad(st: SurfaceTool, x: int, y: int) -> void:
	var i00 := _map.index(x, y)
	var i10 := _map.index(x + 1, y)
	var i01 := _map.index(x, y + 1)
	var i11 := _map.index(x + 1, y + 1)

	var p00 := _vertex_pos(x, y, i00)
	var p10 := _vertex_pos(x + 1, y, i10)
	var p01 := _vertex_pos(x, y + 1, i01)
	var p11 := _vertex_pos(x + 1, y + 1, i11)

	_add_vertex(st, p00, i00)
	_add_vertex(st, p01, i01)
	_add_vertex(st, p10, i10)

	_add_vertex(st, p10, i10)
	_add_vertex(st, p01, i01)
	_add_vertex(st, p11, i11)


func _vertex_pos(x: int, y: int, idx: int) -> Vector3:
	var wp := _map.cell_world_pos(x, y)
	var h := _map.height[idx]
	if _map.water_type[idx] == WorldMapData.WaterType.RIVER:
		h -= RIVER_CARVE_DEPTH # shallow local channel, follows the terrain slope
	return Vector3(wp.x, h, wp.y)


func _add_vertex(st: SurfaceTool, pos: Vector3, idx: int) -> void:
	st.set_color(_color_for_cell(idx))
	st.add_vertex(pos)


## A flat plane at sea level for oceans/lakes. Rivers are represented by
## vertex color + a shallow carve in the terrain mesh itself (see
## _vertex_pos), not this plane, since they sit well above sea level.
func _build_water_plane() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(_map.world_size, _map.world_size)

	var mi := MeshInstance3D.new()
	mi.name = "SeaPlane"
	mi.mesh = plane
	mi.position = Vector3(_map.world_size * 0.5, _map.sea_level, _map.world_size * 0.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.65, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic = 0.1
	mi.material_override = mat

	add_child(mi)


func _build_foliage_markers() -> void:
	var foliage_root := Node3D.new()
	foliage_root.name = "FoliageMarkers"
	add_child(foliage_root)

	var by_type: Dictionary = {}
	for spawn in _map.foliage_spawns:
		var t: FoliageType = spawn["type"]
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(spawn["position"])

	for foliage_type in by_type.keys():
		_build_marker_multimesh(foliage_root, foliage_type, by_type[foliage_type])


func _build_marker_multimesh(parent: Node3D, foliage_type: FoliageType, positions: Array) -> void:
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.4, foliage_type.marker_height, 0.4)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = marker_mesh
	multimesh.instance_count = positions.size()

	for i in range(positions.size()):
		var pos: Vector3 = positions[i]
		pos.y += foliage_type.marker_height * 0.5
		multimesh.set_instance_transform(i, Transform3D(Basis(), pos))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Foliage_%s" % foliage_type.type_name.replace(" ", "")
	mmi.multimesh = multimesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = foliage_type.marker_color
	mmi.material_override = mat
	parent.add_child(mmi)


func _print_debug_summary() -> void:
	var biome_counts: Dictionary = {}
	var biome_names := WorldGenConfig.Biome.keys()
	for b in _map.biome:
		biome_counts[b] = biome_counts.get(b, 0) + 1
	var water_counts: Dictionary = {}
	for wt in _map.water_type:
		water_counts[wt] = water_counts.get(wt, 0) + 1

	print("[WorldMapView] seed=%d resolution=%d world_size=%.0f" % [world_seed, resolution, world_size])
	for b in biome_counts.keys():
		print("  biome %s: %d cells" % [biome_names[b], biome_counts[b]])
	print("  water_type counts (0=NONE,1=OCEAN,2=LAKE,3=RIVER): %s" % [water_counts])
	print("  foliage_spawns: %d" % _map.foliage_spawns.size())

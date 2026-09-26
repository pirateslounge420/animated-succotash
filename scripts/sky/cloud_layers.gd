class_name CloudLayers
extends Node3D
## Three cloud layers as transparent shells around the planet (see
## shaders/cloud_layer.gdshader), each with its own altitude and speed:
##
##   layer  kind                         altitude range     speed x real
##   low    cumulus / stratus            500-2,000 m        4x
##   mid    altocumulus                  2,000-7,000 m      3x
##   high   cirrus (jet stream)          5,000-13,000 m     2x
##
## Altitudes are tunable per layer (clamped to the range), as are the
## speed multipliers. The table is real clouds; in the world everything is
## times `height_scale`, the terrain's vertical scale (PlanetConst:
## 1/10), so the layers sit at 50-200 m, 200-700 m and 500-1,300 m. Cloud
## sizes and drift scale with it too, so from the ground the sky looks as
## it would under real clouds.
##
## Speeds: the local surface wind scaled to the layer's real-world speed
## (winds strengthen with height; the high layer rides the jet stream),
## times the layer's multiplier. The multipliers are well below the 12x
## time compression of the day on purpose: at full time scale clouds would
## blur past.
##
## Peaks above the low layer break through it; `above_low()` tells the
## game when the player is up there (thin, cold, exposed air).
##
## The node sits at the planet center under World.world_root, so it moves
## with the floating origin.

const LOW := 0
const MID := 1
const HIGH := 2

@export var height_scale := PlanetConst.HEIGHT_SCALE
## [min, max] altitude per layer at height_scale 1, meters.
const RANGES := [Vector2(500.0, 2000.0), Vector2(2000.0, 7000.0), Vector2(5000.0, 13000.0)]
@export var altitude_m := PackedFloat32Array([1500.0, 3800.0, 8500.0])
@export var speed_mult := PackedFloat32Array([4.0, 3.0, 2.0])

## Real-world wind at the layer from the surface wind: factor x surface +
## extra m/s along it (jet stream for the high layer).
const WIND_FACTOR := [1.4, 2.0, 2.5]
const WIND_EXTRA_MPS := [0.0, 4.0, 20.0]
## Cloud size at height_scale 1, meters.
const FEATURE_M := [650.0, 700.0, 2600.0]
## Haze on the clouds eases in between these distances at height_scale 1.
const FOG_EASE_M := Vector2(3000.0, 30000.0)
const MAX_ALPHA := [0.95, 0.85, 0.55]

var world: Node
var _mats: Array[ShaderMaterial] = []
var _nodes: Array[MeshInstance3D] = []
var _drift := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]


func build(p_world: Node) -> void:
	world = p_world
	position = world.planet_center()
	var mesh := _unit_sphere(40)
	for layer in 3:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/cloud_layer.gdshader")
		mat.set_shader_parameter("kind", layer)
		mat.set_shader_parameter("feature_m", FEATURE_M[layer] * height_scale)
		mat.set_shader_parameter("fog_ease_m", FOG_EASE_M * height_scale)
		mat.set_shader_parameter("max_alpha", MAX_ALPHA[layer])
		Look.register(mat)
		var mi := MeshInstance3D.new()
		mi.name = ["LowClouds", "MidClouds", "HighClouds"][layer]
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1e6
		add_child(mi)
		_mats.append(mat)
		_nodes.append(mi)


## Altitude of a layer in meters above sea level (clamped to its range).
func altitude(layer: int) -> float:
	var r: Vector2 = RANGES[layer] * height_scale
	return clampf(altitude_m[layer] * height_scale, r.x, r.y)


## True when a point `elevation_m` high stands above the low layer.
func above_low(elevation_m: float) -> bool:
	return elevation_m > altitude(LOW)


## Per frame. `up` is the viewer's local up (planet frame), `camera_alt`
## its height above sea level, `weather` WeatherSim.local_weather(),
## `light`/`shade` the cloud tones from SkySystem and `light_dir` the
## direction (planet frame) of what lights them, the sun or the moon.
func update_clouds(delta: float, up: Vector3, camera_alt: float, weather: Dictionary, light: Color, shade: Color, light_dir := Vector3.UP) -> void:
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	var cloud := float(weather.get("cloud", 0.0))
	var storm := float(weather.get("storm", 0.0))
	var dir := wind.normalized() if wind.length() > 0.1 else CubeSphere.east(up)
	# Cover: low clouds follow the local weather (fair weather keeps a
	# scatter of separate small puffs); mid and high are patchier and
	# thinner.
	var covers := [clampf(0.2 + 0.6 * cloud + 0.3 * storm, 0.0, 0.95),
		clampf(0.12 + 0.35 * cloud + 0.2 * storm, 0.0, 0.9),
		clampf(0.2 + 0.2 * cloud, 0.0, 0.7)]
	# Farther layers draw first (they sort as one object at the planet
	# center, so order them by hand).
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return absf(altitude(a) - camera_alt) > absf(altitude(b) - camera_alt))
	for layer in 3:
		var speed: float = wind.length() * WIND_FACTOR[layer] + WIND_EXTRA_MPS[layer]
		# Real wind at the layer, scaled with the cloud sizes: the same
		# angular speed across the sky as real clouds at real altitude.
		_drift[layer] += dir * speed * speed_mult[layer] * height_scale * delta
		var mat := _mats[layer]
		mat.set_shader_parameter("radius", PlanetConst.RADIUS_M + altitude(layer))
		mat.set_shader_parameter("cover", covers[layer])
		mat.set_shader_parameter("drift", -_drift[layer])
		mat.set_shader_parameter("wind_axis", dir)
		mat.set_shader_parameter("light_color", light)
		mat.set_shader_parameter("shade_color", shade)
		mat.set_shader_parameter("light_dir", light_dir)
		mat.set_shader_parameter("camera_above", 1.0 if camera_alt > altitude(layer) else 0.0)
		mat.render_priority = order.find(layer)


## Unit sphere as a cube-sphere of `res` quads per face edge, normals out.
static func _unit_sphere(res: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := res + 1
	for f in 6:
		var base := verts.size()
		for j in n:
			for i in n:
				verts.append(CubeSphere.to_dir(f, -1.0 + 2.0 * i / res, -1.0 + 2.0 * j / res))
		for j in res:
			for i in res:
				var a := base + j * n + i
				idx.append_array([a, a + n + 1, a + 1, a, a + n, a + n + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

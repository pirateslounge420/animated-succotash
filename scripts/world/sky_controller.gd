extends Node3D
## Drives sky gradient, sun light, fog, and a simple low-poly visual moon
## from TimeOfDay, targeting the lighting keys in DESIGN.md section 4 and
## the night mood reference in section 2.1 (deep blue-violet night, warm
## light reserved for fire/hearths, oversized graphic moon, blue-violet-
## to-orange dusk banding).

@export var sun_light_path: NodePath
@export var moon_pivot_path: NodePath
@export var world_environment_path: NodePath

const SUN_AZIMUTH_DEG: float = -30.0
const MOON_AZIMUTH_DEG: float = 150.0

const DAY_SKY_TOP := Color(0.30, 0.62, 0.92)
const DAY_SKY_HORIZON := Color(0.75, 0.85, 0.95)
const NIGHT_SKY_TOP := Color(0.04, 0.05, 0.14)
const NIGHT_SKY_HORIZON := Color(0.08, 0.08, 0.22)
const TWILIGHT_HORIZON := Color(0.85, 0.45, 0.25)

const DAY_SUN_COLOR := Color(1.0, 0.97, 0.9)
const TWILIGHT_SUN_COLOR := Color(1.0, 0.5, 0.28)
const NIGHT_SUN_COLOR := Color(0.4, 0.45, 0.7)

const DAY_FOG_COLOR := Color(0.8, 0.87, 0.95)
const NIGHT_FOG_COLOR := Color(0.05, 0.05, 0.16)

const DAY_SUN_ENERGY: float = 1.2
const NIGHT_SUN_ENERGY: float = 0.05

var _sun_light: DirectionalLight3D
var _moon_pivot: Node3D
var _moon_mesh: MeshInstance3D
var _environment: Environment


func _ready() -> void:
	_sun_light = get_node(sun_light_path)
	_moon_pivot = get_node(moon_pivot_path)
	_moon_mesh = _moon_pivot.get_node("MoonMesh")
	var world_env: WorldEnvironment = get_node(world_environment_path)
	_environment = world_env.environment

	TimeOfDay.time_changed.connect(_on_time_changed)
	_on_time_changed(TimeOfDay.time_of_day)


func _on_time_changed(_t: float) -> void:
	var sun_elev := TimeOfDay.sun_elevation_deg()
	# 0 well below the horizon -> 1 once comfortably above it.
	var day_amount := smoothstep(-5.0, 15.0, sun_elev)
	# Peaks at 1 right at the horizon, fades out by +/-20 degrees either
	# side -- this is what puts the orange band at the horizon during
	# both sunrise and sunset without a separate dawn/dusk state.
	var twilight_amount := 1.0 - smoothstep(0.0, 20.0, absf(sun_elev))

	_sun_light.rotation_degrees = Vector3(-sun_elev, SUN_AZIMUTH_DEG, 0.0)
	var base_sun_color := NIGHT_SUN_COLOR.lerp(DAY_SUN_COLOR, day_amount)
	_sun_light.light_color = base_sun_color.lerp(TWILIGHT_SUN_COLOR, twilight_amount)
	_sun_light.light_energy = lerpf(NIGHT_SUN_ENERGY, DAY_SUN_ENERGY, day_amount)

	if _environment and _environment.sky and _environment.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat: ProceduralSkyMaterial = _environment.sky.sky_material
		sky_mat.sky_top_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, day_amount)
		var base_horizon := NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, day_amount)
		sky_mat.sky_horizon_color = base_horizon.lerp(TWILIGHT_HORIZON, twilight_amount)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color

	if _environment:
		_environment.fog_light_color = NIGHT_FOG_COLOR.lerp(DAY_FOG_COLOR, day_amount)

	var moon_elev := TimeOfDay.moon_elevation_deg()
	var moon_visible := not TimeOfDay.is_day() and moon_elev > 0.0
	_moon_mesh.visible = moon_visible
	if moon_visible:
		_moon_pivot.rotation_degrees = Vector3(-moon_elev, MOON_AZIMUTH_DEG, 0.0)

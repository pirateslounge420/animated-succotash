class_name WeatherFX
extends Node3D
## What the live weather looks like where the player stands (DESIGN.md
## "Weather System > Physical expression"):
##   * rain or snow particles around the camera; intensity reads the local
##     precipitation, rain above freezing and snow below;
##   * the local wind tilts the falling particles, so storm rain blows
##     sideways instead of falling straight down;
##   * the same wind drives foliage sway (PlantMeshes' shared material).
##
## Keep this node at the scene origin (not under World.world_root); it
## moves its emitters to the camera each frame.

const RAIN_MAX := 3000
const SNOW_MAX := 1500

var rain: GPUParticles3D
var snow: GPUParticles3D
var local: Dictionary = {}


func _ready() -> void:
	rain = _emitter(RAIN_MAX, _rain_mesh(), 1.1, true)
	snow = _emitter(SNOW_MAX, _snow_mesh(), 7.0, false)
	add_child(rain)
	add_child(snow)


## GPU particles: intensity is `amount_ratio`, which changes how many
## particles emit without restarting the emitter.
func _emitter(amount: int, mesh: Mesh, lifetime: float, align: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.amount_ratio = 0.0
	p.lifetime = lifetime
	p.draw_pass_1 = mesh
	p.local_coords = false
	p.emitting = false
	# Always drawn round the camera; never culled by its bounds.
	p.visibility_aabb = AABB(Vector3(-40, -60, -40), Vector3(80, 80, 80))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(22, 1, 22)
	m.direction = Vector3.DOWN
	m.spread = 3.0
	m.particle_flag_align_y = align
	p.process_material = m
	return p


func _rain_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	return q


func _snow_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	return q


## weather: WeatherSim.local_weather() at the player. up: local up.
func update_fx(camera_pos: Vector3, up: Vector3, weather: Dictionary) -> void:
	local = weather
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	var rate: float = weather.get("rain_mm_h", 0.0)
	var storm: float = weather.get("storm", 0.0)
	var cold: bool = weather.get("snow", false)
	var intensity := clampf(rate / 2.5 + storm * 0.6, 0.0, 1.0)
	var basis := Basis.looking_at(-_tangent(up), up)
	var origin := camera_pos + up * 14.0

	for p in [rain, snow]:
		p.global_transform = Transform3D(basis, origin)
	var active: GPUParticles3D = snow if cold else rain
	var idle: GPUParticles3D = rain if cold else snow
	idle.emitting = false
	active.emitting = intensity > 0.05
	active.amount_ratio = intensity

	# Fall along gravity plus the wind: the stronger the wind, the more the
	# streaks lean.
	var fall_speed := 9.0 if not cold else 1.2
	var drift := wind * (0.6 if not cold else 0.35)
	var velocity := -up * fall_speed + drift
	var m: ParticleProcessMaterial = active.process_material
	m.direction = active.global_basis.inverse() * velocity.normalized()
	m.initial_velocity_min = velocity.length() * 0.9
	m.initial_velocity_max = velocity.length() * 1.1
	m.gravity = -up * (2.0 if not cold else 0.2) + drift * 0.1

	PlantMeshes.material().set_shader_parameter("wind_vector", wind)


static func _tangent(up: Vector3) -> Vector3:
	return CubeSphere.north(up)

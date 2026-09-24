class_name SkySystem
extends Node3D
## Sun, moon, sky, ambient light and fog (DESIGN.md "Lighting & Day-Night
## Cycle"). Builds its own WorldEnvironment and two DirectionalLight3Ds.
##
## Call update_sky() every frame with the viewer's local up (players walk
## around a sphere, so "up" and therefore sun elevation depend on where
## they stand), the world clock in days, and the local weather.
##
## * Sun and moon are real lights. Each one's brightness and color follow
##   its own elevation above the local horizon: dim and warm when low,
##   full strength high up, nothing once it's a few degrees below.
## * The moon moves like Earth's (Astro.MoonMode.ORBITAL), so sun and moon
##   genuinely share the dawn/dusk sky on most days, each lighting the
##   world from its own side.
## * Sky, ambient and fog colors are continuous functions of sun
##   elevation (a smooth gradient, no discrete keyframe switching), with
##   moonlight lifting the night palette in proportion to the moon's phase
##   and height.
## * The moon's brightness follows its 28-day phase, and today's mansion
##   glyph is drawn beside it in its guardian beast's color.

const SKY_SHADER := preload("res://shaders/sky.gdshader")

@export var moon_mode: Astro.MoonMode = Astro.MoonMode.ORBITAL
@export var sun_max_energy := 1.25
@export var moon_max_energy := 0.62

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial

## Outputs other systems read (water, post effect, creatures).
var sun_dir := Vector3.UP
var moon_dir := Vector3.DOWN
var sun_elevation_deg := 45.0
var moon_elevation_deg := -45.0
var daylight := 1.0 # 0 at night, 1 in full day
var moonlight := 0.0 # 0-1, includes phase

var _zenith := Gradient.new()
var _horizon := Gradient.new()
var _cloud_offset := Vector2.ZERO
var _last_mansion := -1

## Elevation (degrees) -> palette keys. Day is Frutiger Aero: saturated aqua.
## Night is deep cobalt and violet.
const _ELEV_MIN := -18.0
const _ELEV_MAX := 40.0
const _KEYS := [
	[-18.0, Color(0.02, 0.035, 0.13), Color(0.07, 0.07, 0.24)],
	[-8.0, Color(0.05, 0.06, 0.22), Color(0.26, 0.14, 0.36)],
	[-2.0, Color(0.12, 0.16, 0.42), Color(0.75, 0.36, 0.32)],
	[3.0, Color(0.22, 0.38, 0.72), Color(1.0, 0.62, 0.32)],
	[12.0, Color(0.16, 0.5, 0.95), Color(0.62, 0.82, 0.98)],
	[40.0, Color(0.08, 0.44, 0.98), Color(0.55, 0.86, 1.0)],
]


func _ready() -> void:
	var offsets := PackedFloat32Array()
	var zeniths := PackedColorArray()
	var horizons := PackedColorArray()
	for key in _KEYS:
		offsets.append(inverse_lerp(_ELEV_MIN, _ELEV_MAX, key[0]))
		zeniths.append(key[1])
		horizons.append(key[2])
	_zenith.offsets = offsets
	_zenith.colors = zeniths
	_horizon.offsets = offsets
	_horizon.colors = horizons

	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.35
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.1
	environment.adjustment_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = false
	moon.directional_shadow_max_distance = 200.0
	add_child(moon)


## up/east/north: the viewer's local frame. weather: WeatherSim.local_weather().
## fog_amount: 0-1 local fog likelihood from the planet (cloud forests,
## coasts). delta: frame time for cloud drift.
func update_sky(up: Vector3, east: Vector3, north: Vector3, days: float, weather: Dictionary, fog_amount: float, delta: float) -> void:
	sun_dir = Astro.sun_dir(days)
	moon_dir = Astro.moon_dir(days, moon_mode)
	sun_elevation_deg = rad_to_deg(Astro.elevation(sun_dir, up))
	moon_elevation_deg = rad_to_deg(Astro.elevation(moon_dir, up))
	var illumination := Astro.moon_illumination(days)
	var phase := Astro.moon_elongation(days)

	var rise := PlanetConst.SUNRISE_ELEVATION_DEG
	var sun_up := smoothstep(rise, 6.0, sun_elevation_deg)
	var moon_up := smoothstep(-3.0, 8.0, moon_elevation_deg)
	daylight = smoothstep(-6.0, 10.0, sun_elevation_deg)
	moonlight = moon_up * (0.12 + 0.88 * illumination)

	# Lights.
	_aim(sun, sun_dir, up)
	_aim(moon, moon_dir, up)
	var sun_col := _sun_color(sun_elevation_deg)
	sun.light_color = sun_col
	sun.light_energy = sun_max_energy * sun_up * (1.0 - 0.55 * float(weather.get("cloud", 0.0)))
	var moon_col := Color(0.75, 0.72, 0.86).lerp(Color(0.5, 0.62, 1.0), smoothstep(0.0, 25.0, moon_elevation_deg))
	moon.light_color = moon_col
	moon.light_energy = moon_max_energy * moonlight * (1.0 - 0.5 * float(weather.get("cloud", 0.0)))
	sun.shadow_enabled = sun.light_energy > 0.05
	moon.shadow_enabled = not sun.shadow_enabled and moon.light_energy > 0.04
	sun.visible = sun.light_energy > 0.001
	moon.visible = moon.light_energy > 0.001

	# Palette: continuous in sun elevation, lifted by moonlight at night.
	var t := inverse_lerp(_ELEV_MIN, _ELEV_MAX, clampf(sun_elevation_deg, _ELEV_MIN, _ELEV_MAX))
	var zenith := _zenith.sample(t)
	var horizon := _horizon.sample(t)
	var night := 1.0 - daylight
	var lift := moonlight * night
	zenith += Color(0.03, 0.05, 0.16) * lift
	horizon += Color(0.04, 0.05, 0.15) * lift
	var storm := float(weather.get("storm", 0.0))
	var cloud := float(weather.get("cloud", 0.0))
	zenith = zenith.lerp(Color(0.45, 0.48, 0.55) * (0.15 + 0.85 * daylight), storm * 0.7)

	sky_material.set_shader_parameter("up_dir", up)
	sky_material.set_shader_parameter("east_dir", east)
	sky_material.set_shader_parameter("north_dir", north)
	sky_material.set_shader_parameter("zenith_color", zenith)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("ground_color", horizon.darkened(0.6))
	sky_material.set_shader_parameter("sun_dir", sun_dir)
	sky_material.set_shader_parameter("sun_color", sun_col)
	sky_material.set_shader_parameter("sun_visible", smoothstep(-2.0, 1.0, sun_elevation_deg) * (1.0 - cloud * 0.8))
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("moon_phase", phase)
	sky_material.set_shader_parameter("moon_brightness", (0.35 + 0.65 * night) * (1.0 - cloud * 0.6))
	var stars := (1.0 - smoothstep(-10.0, -2.0, sun_elevation_deg)) * (1.0 - cloud)
	sky_material.set_shader_parameter("star_visibility", stars)
	sky_material.set_shader_parameter("star_rotation", Astro.subsolar_longitude(days))
	sky_material.set_shader_parameter("glyph_visibility", stars * smoothstep(-2.0, 5.0, moon_elevation_deg))

	var mansion := Astro.mansion_index(days)
	if mansion != _last_mansion:
		_last_mansion = mansion
		var pattern: Array = LunarMansions.stars(mansion)
		var packed := PackedVector2Array()
		packed.resize(LunarMansions.MAX_STARS)
		for i in pattern.size():
			packed[i] = pattern[i]
		sky_material.set_shader_parameter("glyph_stars", packed)
		sky_material.set_shader_parameter("glyph_count", pattern.size())
		sky_material.set_shader_parameter("glyph_color", LunarMansions.tint(mansion))

	# Clouds: coverage from the live weather, drifting with the wind.
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	_cloud_offset += Vector2(wind.dot(east), wind.dot(north)) * delta * 0.004
	sky_material.set_shader_parameter("cloud_cover", clampf(0.12 + 0.75 * cloud + 0.3 * storm, 0.0, 0.98))
	sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
	var lit := sun_col * sun_up + moon_col * moon_up * 0.35 * illumination
	sky_material.set_shader_parameter("cloud_light", (Color(0.1, 0.12, 0.2) + lit).clamp())
	sky_material.set_shader_parameter("cloud_shadow", zenith.darkened(0.35).lerp(Color(0.3, 0.32, 0.38) * daylight, storm * 0.6))

	# Ambient tracks the sky continuously.
	# By day ambient is a soft, near-white sky fill so materials keep their
	# colors. At night the world should read as drowned in cobalt/violet,
	# never black: even a moonless night keeps a starlight floor, and a full
	# moon lifts it well above that.
	# The night fill is a pale blue-lavender rather than a saturated blue:
	# leaves and soil reflect little blue, so pure blue light would leave
	# them black. (Colors are sRGB; the renderer converts them to linear.)
	var amb_day := horizon.lerp(Color.WHITE, 0.45)
	var amb_night := Color(0.42, 0.47, 0.82).lerp(Color(0.55, 0.6, 0.95), lift)
	environment.ambient_light_color = amb_night.lerp(amb_day, daylight)
	environment.ambient_light_energy = lerpf(1.0 + 0.8 * lift, 0.55, daylight)

	# Fog: long views on clear days; mist on cloud forests, coasts, storms
	# and a little at night for depth.
	environment.fog_light_color = horizon
	environment.fog_density = 0.00025 + fog_amount * 0.004 + storm * 0.0025 + night * 0.0007

	# Grade: glossy and saturated by day, deeper and cooler at night.
	environment.adjustment_saturation = lerpf(1.15, 1.3, daylight)
	environment.adjustment_contrast = lerpf(1.12, 1.03, daylight)


func _aim(light: DirectionalLight3D, body_dir: Vector3, up: Vector3) -> void:
	var travel := -body_dir
	var hint := up if absf(travel.dot(up)) < 0.99 else up.cross(Vector3.RIGHT).normalized()
	light.global_transform = Transform3D(Basis.looking_at(travel, hint), light.global_position)


static func _sun_color(elev_deg: float) -> Color:
	var low := Color(1.0, 0.5, 0.25)
	var mid := Color(1.0, 0.8, 0.6)
	var high := Color(1.0, 0.97, 0.9)
	if elev_deg < 10.0:
		return low.lerp(mid, smoothstep(-2.0, 10.0, elev_deg))
	return mid.lerp(high, smoothstep(10.0, 30.0, elev_deg))

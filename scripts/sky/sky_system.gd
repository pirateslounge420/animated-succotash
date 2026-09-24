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
@export var sun_max_energy := 0.9
@export var moon_max_energy := 0.5
## 0-1: how deep the viewer is inside a magical site (Landmarks sets it).
var magic := 0.0

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

## Elevation (degrees) -> palette keys [elevation, zenith, horizon]. Day
## is a deep, near-cartoon ultramarine overhead over a Frutiger Aero aqua
## horizon band (N64/PS1-era punch rather than a pale realistic blue).
## Night is deep cobalt and violet.
const _ELEV_MIN := -18.0
const _ELEV_MAX := 40.0
const _KEYS := [
	[-18.0, Color(0.01, 0.02, 0.09), Color(0.04, 0.05, 0.19)],
	[-8.0, Color(0.03, 0.04, 0.2), Color(0.2, 0.09, 0.34)],
	[-2.0, Color(0.08, 0.1, 0.42), Color(0.85, 0.3, 0.33)],
	[3.0, Color(0.12, 0.24, 0.72), Color(1.0, 0.55, 0.22)],
	[12.0, Color(0.06, 0.26, 0.84), Color(0.34, 0.78, 1.0)],
	[40.0, Color(0.05, 0.19, 0.78), Color(0.28, 0.74, 1.0)],
]
## Night magic: inside a glowing site the moonlight dims and the air goes
## near-black so the bioluminescence reads like neon against black.
const MAGIC_DARKEN := 0.6


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
	# Linear: keep colors as saturated as authored (filmic curves wash them
	# toward realism).
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.0 # the sky shader draws its own banded haze
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
	var dark_magic := magic * (1.0 - daylight)

	# Lights.
	_aim(sun, sun_dir, up)
	_aim(moon, moon_dir, up)
	var sun_col := _sun_color(sun_elevation_deg)
	sun.light_color = sun_col
	sun.light_energy = sun_max_energy * sun_up * (1.0 - 0.55 * float(weather.get("cloud", 0.0)))
	var moon_col := Color(0.75, 0.72, 0.86).lerp(Color(0.5, 0.62, 1.0), smoothstep(0.0, 25.0, moon_elevation_deg))
	moon.light_color = moon_col
	moon.light_energy = moon_max_energy * moonlight * (1.0 - 0.5 * float(weather.get("cloud", 0.0))) * (1.0 - MAGIC_DARKEN * dark_magic)
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
	zenith = zenith.lerp(Color(0.0, 0.01, 0.04), dark_magic * 0.6)
	horizon = horizon.lerp(Color(0.01, 0.03, 0.1), dark_magic * 0.5)
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
	sky_material.set_shader_parameter("cloud_cover", clampf(0.1 + 0.55 * cloud + 0.35 * storm, 0.0, 0.95))
	sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
	var lit := sun_col * sun_up + moon_col * moon_up * 0.35 * illumination
	sky_material.set_shader_parameter("cloud_light", (Color(0.1, 0.12, 0.2) + lit).clamp())
	sky_material.set_shader_parameter("cloud_shadow", zenith.darkened(0.35).lerp(Color(0.3, 0.32, 0.38) * daylight, storm * 0.6))

	# Ambient tracks the sky continuously.
	# By day the fill is sky-tinted (shadows go blue-ish, the colored-shadow
	# look of the era) but kept low so sunlit colors stay saturated instead
	# of clipping to white. At night the world is drowned in cobalt/violet,
	# never black: a starlight floor, lifted by the moon. The night fill is
	# blue-lavender rather than pure blue, since leaves and soil reflect
	# little blue and would otherwise go black.
	var amb_day := zenith.lerp(horizon, 0.6).lerp(Color.WHITE, 0.35)
	var amb_night := Color(0.3, 0.34, 0.85).lerp(Color(0.42, 0.46, 0.92), lift)
	environment.ambient_light_color = amb_night.lerp(amb_day, daylight)
	environment.ambient_light_energy = lerpf(0.3 + 0.3 * lift, 0.4, daylight) * (1.0 - MAGIC_DARKEN * dark_magic)

	# Fog and mist (drawn in bands by the world shaders, see Look): a
	# light haze that gives depth to long daytime views; thicker at night
	# and in cloud forests, on coasts and in storms, with ground mist
	# pooling in low places after dark.
	var fog_color := horizon.lerp(zenith, 0.25)
	fog_color = fog_color.lerp(Color(0.015, 0.03, 0.12), dark_magic * 0.6)
	var density := 0.0004 + fog_amount * 0.003 + storm * 0.002 + night * 0.0014
	var mist := clampf(0.35 * night + fog_amount * 0.6 + storm * 0.3, 0.0, 1.0)
	environment.fog_light_color = fog_color
	environment.fog_density = density
	Look.apply({
		"look_fog_color": fog_color,
		"look_fog_density": density,
		"look_mist": mist,
		"look_up": up,
		"look_night": night,
		"look_glow": 1.0 - smoothstep(0.08, 0.55, daylight),
	})
	sky_material.set_shader_parameter("fog_color", fog_color)

	# Grade: punchy and saturated by day, deeper and cooler at night.
	environment.adjustment_saturation = lerpf(1.05, 1.18, daylight)
	environment.adjustment_contrast = lerpf(1.12, 1.08, daylight)


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

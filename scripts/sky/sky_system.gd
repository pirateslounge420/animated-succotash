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
@export var sun_max_energy := 1.05
@export var moon_max_energy := 0.8
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
	environment.tonemap_exposure = 0.9 # a touch under, so nothing reads washed out
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.0 # the sky shader draws its own banded haze
	# Glow: punchy blown highlights on light sources (campfires, lanterns,
	# glowing water and moss, the sun, glints on water), which are pushed
	# well above the HDR threshold. No global bloom term, so ordinary
	# daylight surfaces stay crisp.
	environment.glow_enabled = true
	environment.glow_intensity = 1.0
	environment.glow_strength = 1.1
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_hdr_scale = 2.5
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for level in 7:
		environment.set_glow_level(level, 1.0 if level >= 1 and level <= 4 else 0.0)
	environment.adjustment_enabled = true
	# Ambient occlusion (Forward+ only; the compatibility renderer ignores
	# it): darkens crevices, the ground under canopy, trunk bases and the
	# joints between ruin blocks, which the flat ambient fill otherwise
	# leaves evenly lit. A little of it also dims direct light so it still
	# reads in full sun.
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 3.0
	environment.ssao_power = 1.8
	environment.ssao_detail = 0.5
	environment.ssao_horizon = 0.06
	environment.ssao_sharpness = 0.98
	environment.ssao_light_affect = 0.35

	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	# Hard, crisp shadows (the GameCube look), not soft PCF penumbras:
	# unfiltered shadow maps, a big atlas, and the shadow range pulled in so
	# its resolution goes to what's near the player.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.directional_shadow_atlas_set_size(4096, true)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = false
	add_child(moon)
	for light in [sun, moon]:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 160.0
		light.shadow_blur = 0.0
		light.light_angular_distance = 0.0
		# Enough bias that hard, unfiltered maps don't streak lit ground
		# with acne (at 2.0, flat sand under a high sun showed ring-shaped
		# moire out to ~30 m); mostly normal bias, so contact shadows stay
		# tight.
		light.shadow_bias = 0.06
		light.shadow_normal_bias = 5.0


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
	var moon_col := Color(0.7, 0.7, 0.9).lerp(Color(0.42, 0.56, 1.0), smoothstep(0.0, 25.0, moon_elevation_deg))
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
	# Even a clear day carries big fair-weather cumulus (the references
	# always have them); weather adds more.
	sky_material.set_shader_parameter("cloud_cover", clampf(0.34 + 0.45 * cloud + 0.3 * storm, 0.0, 0.95))
	sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
	var lit := sun_col * sun_up + moon_col * moon_up * 0.35 * illumination
	sky_material.set_shader_parameter("cloud_light", (Color(0.14, 0.16, 0.24) + lit * 1.1).clamp())
	# Fair-weather cumulus stay white with pale blue-grey undersides (not
	# sky-blue shapes); storms darken them.
	var cloud_under := Color(0.72, 0.78, 0.95).lerp(zenith, 0.25) * (0.35 + 0.65 * daylight)
	sky_material.set_shader_parameter("cloud_shadow", cloud_under.lerp(Color(0.3, 0.32, 0.38) * daylight, storm * 0.6))

	# Ambient tracks the sky continuously.
	# By day the fill is sky-tinted (shadows go blue-ish, the colored-shadow
	# look of the era) but kept low so sunlit colors stay saturated instead
	# of clipping to white. At night the world is drowned in cobalt/violet,
	# never black: a starlight floor, lifted by the moon. The night fill is
	# blue-lavender rather than pure blue, since leaves and soil reflect
	# little blue and would otherwise go black.
	# By day the fill is neutral: the color of shade comes from the world
	# shaders' light() instead (Look: blocked or averted sun comes back
	# tinted teal, multiplying each surface's own color, so forests stay
	# green in shade instead of going grey or violet).
	var amb_day := Color(0.8, 0.82, 0.85)
	var amb_night := Color(0.3, 0.34, 0.85).lerp(Color(0.42, 0.46, 0.92), lift)
	environment.ambient_light_color = amb_night.lerp(amb_day, daylight)
	environment.ambient_light_energy = lerpf(0.18 + 0.2 * lift, 0.26, daylight) * (1.0 - MAGIC_DARKEN * dark_magic)

	# Fog and mist (drawn in bands by the world shaders, see Look): a
	# light haze that gives depth to long daytime views; thicker at night
	# and in cloud forests, on coasts and in storms, with ground mist
	# pooling in low places after dark.
	# Atmospheric perspective: distance fades into blue haze by day and
	# deep cobalt at night, so near, middle and far read as separate layers.
	var fog_color := horizon.lerp(zenith, 0.5).lerp(Color(0.04, 0.07, 0.3), night * 0.55)
	fog_color = fog_color.lerp(Color(0.015, 0.03, 0.12), dark_magic * 0.6)
	var density := 0.0008 + fog_amount * 0.003 + storm * 0.002 + night * 0.0012
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
		"look_rim_color": moon_col.lerp(Color(0.4, 0.5, 1.0), 0.5) * (0.35 + 0.65 * moonlight),
		# Shade: teal under the sun, cobalt under the moon.
		"look_shadow_tint": Color(0.28, 0.62, 0.78).lerp(Color(0.22, 0.34, 0.95), night),
	})
	sky_material.set_shader_parameter("fog_color", fog_color)

	# Grade: a punchy, crushed curve day and night (deep shadows, bright
	# highlights, little midtone, like Melee or PSO), saturated by day.
	environment.adjustment_saturation = lerpf(1.2, 1.42, daylight)
	environment.adjustment_contrast = lerpf(1.32, 1.28, daylight)


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

class_name SkySystem
extends Node3D
## Sun, moon, sky, ambient light and fog (DESIGN.md "Lighting & Day-Night
## Cycle"). Builds its own WorldEnvironment and two DirectionalLight3Ds.
##
## Call update_sky() every frame with the viewer's local up (players walk
## around a sphere, so "up" and therefore sun elevation depend on where
## they stand), the world clock in days, and the local weather.
##
## * Sun and moon are real lights casting hard shadow maps (no blur), and
##   by day the sun is the only one doing any work: ambient is low and deep
##   blue, sky light and reflections are off (data/look.json; design
##   reconciliation Session 2 section C). Each light's brightness and color
##   follow its own elevation: dim and warm when low, full strength high
##   up, nothing once it's a few degrees below. Its direction is raked: the
##   elevation squeezed under look "light" rake_max_deg, so shadows run
##   long even at noon (the disc in the sky stays true).
## * The moon moves like Earth's (Astro.MoonMode.ORBITAL), so sun and moon
##   genuinely share the dawn/dusk sky on most days, each lighting the
##   world from its own side.
## * Sky, ambient and fog colors are continuous functions of sun
##   elevation (a smooth gradient, no discrete keyframe switching), with
##   moonlight lifting the night palette in proportion to the moon's phase
##   and height.
## * The moon's brightness follows its 29.5-day phase, and the glyph of
##   the mansion it stands in is drawn beside it in its guardian beast's
##   color; when the moon moves into the next mansion the glyph fades out
##   and the new one fades in.
## * The sky is a painted skybox (SkyPaint bakes its cloud and star
##   panoramas once): this feeds it the cloud cover from the (eased)
##   weather, the clouds' colors for the hour and their slow drift.
## * Sky colors are the R1a palette (docs/WORLD_SYSTEMS_SPEC.md): pure
##   saturated blue by day, ultramarine at night, night fog that dissolves
##   distance to blue, periwinkle moonlight. _scene_color() undoes the
##   environment's exposure so the hex values land on screen before the
##   post grade (PostGrade's day and night presets, data/look.json).
## * Nothing snaps: the sky's turning speed eases between phases
##   (DayCycle), the weather arriving here is eased (main.gd), the lights
##   fade to exactly zero before they're switched off, and the clouds'
##   light turns from the sun to the moon over a band of sun elevations.

const SKY_SHADER := preload("res://shaders/sky.gdshader")

@export var moon_mode: Astro.MoonMode = Astro.MoonMode.ORBITAL
@export var sun_max_energy := 1.35
@export var moon_max_energy := 1.1
## Moonlight never drops below this share of full (thin phases, playable nights).
const MOON_FLOOR := 0.05
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
## Direction the clouds are lit from: the sun's, turning to the moon's as
## the sun sets (DayCycle.cloud_light_band), and back at sunrise.
var cloud_light_dir := Vector3.UP
var daylight := 1.0 # 0 at night, 1 in full day
var moonlight := 0.0 # 0-1, includes phase

var _zenith := Gradient.new()
var _horizon := Gradient.new()
## Cloud tones (lit tops, shaded undersides) for CloudLayers.

var cloud_light := Color.WHITE
var cloud_shade := Color(0.7, 0.75, 0.9)
var _shown_mansion := -1
var _glyph_fade := 1.0 # 0-1, dips to 0 while the glyph changes mansion

## The R1a palette (docs/WORLD_SYSTEMS_SPEC.md), as it should read on
## screen: day sky zenith -> horizon, night sky zenith -> horizon, night
## fog, and the moonlight's color.
const DAY_ZENITH := Color("#1436FF")
const DAY_HORIZON := Color("#4C7CFF")
const NIGHT_ZENITH := Color("#0A14A0")
const NIGHT_HORIZON := Color("#1B2ED8")
const NIGHT_FOG := Color("#1E30C0")
const MOONLIGHT := Color("#8FA8FF")
## The night fill: ultramarine, lifted a little by the moon.
const FILL_NIGHT := Color("#3A4CFF")
const FILL_MOON := Color("#6480FF")

## Elevation (degrees) -> palette keys [elevation, zenith, horizon], as
## seen on screen. Day is pure saturated blue; at dusk and dawn a warm
## band (rose, then orange) stays low on the horizon while the sky above
## goes ultramarine; night is bright ultramarine.
const _ELEV_MIN := -18.0
const _ELEV_MAX := 40.0
const _KEYS := [
	[-18.0, NIGHT_ZENITH, NIGHT_HORIZON],
	[-8.0, Color("#0E1AB4"), Color("#2C34DC")],
	[-2.0, Color("#1428C8"), Color("#D84C60")],
	[3.0, Color("#1432E8"), Color("#FF8C3A")],
	[12.0, DAY_ZENITH, DAY_HORIZON],
	[40.0, DAY_ZENITH, DAY_HORIZON],
]
## Turns per second the painted clouds drift round the viewer, at rest
## and per m/s of wind.
const CLOUD_TURN := Vector2(0.0002, 0.00006)
var _cloud_scroll := 0.0
## Night magic: inside a glowing site the moonlight dims and the air goes
## near-black so the bioluminescence reads like neon against black.
const MAGIC_DARKEN := 0.6
## The light and the two grade presets (data/look.json; design
## reconciliation Session 2 section C: dark and moody, day included). The
## sun does all the work; ambient is low and deep blue, which is all a
## shadow gets, so shadows read blue. Shadows are hard-edged shadow maps.
static var LIGHT := Tuning.section("look", "light")
static var DAY := Tuning.section("look", "day")
static var NIGHT := Tuning.section("look", "night")
## Night fog density (per meter) added to the day's haze: about 40% at
## 200 m, so the middle distance goes blue and the far distance dissolves.
const FOG_NIGHT := 0.0017


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
	# The painted clouds and starfield, baked once on the GPU.
	var paint := SkyPaint.new()
	paint.name = "SkyPaint"
	add_child(paint)
	paint.bake()
	sky_material.set_shader_parameter("cloud_pano", paint.clouds)
	sky_material.set_shader_parameter("star_pano", paint.stars)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The sky lights nothing: no sky ambient, no sky reflections.
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Linear: keep colors as saturated as authored (filmic curves wash them
	# toward realism).
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 0.9 # a touch under, so nothing reads washed out
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.0 # the sky shader draws its own banded haze
	# The grade is PostGrade's two presets, not the environment's.
	environment.adjustment_enabled = false
	# Lambert under one hard sun over a low blue ambient, and nothing
	# screen-space on top: no glow halos, no ambient occlusion, no
	# screen-space reflections or indirect light.
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.ssr_enabled = false
	environment.sdfgi_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	# Hard shadow maps from the sun (and the moon at night): no blur, no
	# soft filtering (project setting soft_shadow_filter_quality 0), a
	# point light source.
	sun_max_energy = float(LIGHT.get("sun_energy", sun_max_energy))
	moon_max_energy = float(LIGHT.get("moon_energy", moon_max_energy))
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	add_child(moon)
	for light in [sun, moon]:
		light.shadow_enabled = bool(LIGHT.get("shadows", true))
		light.shadow_blur = 0.0
		light.light_angular_distance = 0.0
		var splits := int(LIGHT.get("shadow_splits", 4))
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if splits <= 1 else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if splits == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
		light.directional_shadow_max_distance = float(LIGHT.get("shadow_max_m", 90.0))
		light.directional_shadow_fade_start = 0.9
		light.shadow_bias = float(LIGHT.get("shadow_bias", 0.04))
		light.shadow_normal_bias = float(LIGHT.get("shadow_normal_bias", 1.2))


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
	# Steep, like the real moon (opposition surge): a half moon gives about
	# a tenth of full moonlight; a floor keeps thin phases faintly lit.
	moonlight = moon_up * maxf(pow(illumination, 3.3), MOON_FLOOR)
	var dark_magic := magic * (1.0 - daylight)

	# Lights: raking, never flat overhead (the disc in the sky stays true).
	_aim(sun, _rake(sun_dir, up, north), up)
	_aim(moon, _rake(moon_dir, up, north), up)
	var sun_col := _sun_color(sun_elevation_deg)
	sun.light_color = sun_col
	sun.light_energy = sun_max_energy * sun_up * (1.0 - 0.55 * float(weather.get("cloud", 0.0)))
	# Periwinkle (R1a: moonlit stone and snow read #8FA8FF), paler and
	# greyer when the moon is low.
	var moon_col := Color(0.7, 0.72, 0.92).lerp(MOONLIGHT, smoothstep(0.0, 25.0, moon_elevation_deg))
	moon.light_color = moon_col
	# Moonlight is lost in daylight.
	moon.light_energy = moon_max_energy * moonlight * (1.0 - daylight) * (1.0 - 0.5 * float(weather.get("cloud", 0.0))) * (1.0 - MAGIC_DARKEN * dark_magic)
	# Both energies fall smoothly to exactly zero (the smoothsteps above)
	# before the light is switched off, so switching never shows.
	sun.visible = sun.light_energy > 0.0
	moon.visible = moon.light_energy > 0.0

	# Palette: continuous in sun elevation, lifted a little by moonlight at
	# night. Worked out as screen colors, then turned into scene colors.
	var t := inverse_lerp(_ELEV_MIN, _ELEV_MAX, clampf(sun_elevation_deg, _ELEV_MIN, _ELEV_MAX))
	var zenith := _zenith.sample(t)
	var horizon := _horizon.sample(t)
	var night := 1.0 - daylight
	var lift := moonlight * night
	zenith += Color(0.01, 0.02, 0.06) * lift
	horizon += Color(0.01, 0.02, 0.05) * lift
	var storm := float(weather.get("storm", 0.0))
	var cloud := float(weather.get("cloud", 0.0))
	# Storms grey the day sky; at night they deepen it, still blue.
	zenith = zenith.lerp(Color(0.45, 0.48, 0.55).lerp(Color(0.07, 0.1, 0.4), night), storm * 0.7)
	# Dusk and dawn: the gradient hugs the horizon, so the warm band stays
	# low and the sky above goes ultramarine.
	var warm_band := smoothstep(-12.0, -4.0, sun_elevation_deg) * (1.0 - smoothstep(4.0, 12.0, sun_elevation_deg))
	sky_material.set_shader_parameter("horizon_sharpness", lerpf(2.5, 5.0, warm_band))

	sky_material.set_shader_parameter("up_dir", up)
	sky_material.set_shader_parameter("east_dir", east)
	sky_material.set_shader_parameter("north_dir", north)
	zenith = zenith.lerp(Color(0.0, 0.01, 0.04), dark_magic * 0.6)
	horizon = horizon.lerp(Color(0.01, 0.03, 0.1), dark_magic * 0.5)
	sky_material.set_shader_parameter("zenith_color", _scene_color(zenith))
	sky_material.set_shader_parameter("horizon_color", _scene_color(horizon))
	sky_material.set_shader_parameter("ground_color", _scene_color(horizon.darkened(0.6)))
	sky_material.set_shader_parameter("sun_dir", sun_dir)
	sky_material.set_shader_parameter("sun_color", sun_col)
	sky_material.set_shader_parameter("sun_visible", smoothstep(-2.0, 1.0, sun_elevation_deg) * (1.0 - cloud * 0.8))
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("moon_phase", phase)
	sky_material.set_shader_parameter("moon_brightness", (0.35 + 0.65 * night) * (1.0 - cloud * 0.6))
	sky_material.set_shader_parameter("day_amount", smoothstep(-2.0, 8.0, sun_elevation_deg))
	var stars := (1.0 - smoothstep(-10.0, -2.0, sun_elevation_deg)) * (1.0 - cloud)
	sky_material.set_shader_parameter("star_visibility", stars)
	sky_material.set_shader_parameter("star_rotation", Astro.subsolar_longitude(days))
	_update_glyph(days, stars * smoothstep(-2.0, 5.0, moon_elevation_deg), delta)

	# Cloud tones for CloudLayers: lit by sun and moon; fair-weather clouds
	# stay white with pale blue-grey undersides, storms darken them.
	var lit := sun_col * sun_up + moon_col * moon_up * 0.35 * illumination
	cloud_light = (Color(0.14, 0.16, 0.24) + lit * 1.1).clamp()
	var cloud_under := Color(0.72, 0.78, 0.95).lerp(zenith, 0.25) * (0.35 + 0.65 * daylight)
	cloud_shade = cloud_under.lerp(Color(0.3, 0.32, 0.38) * daylight, storm * 0.6)

	# The painted clouds: fair weather keeps a few banks and streaks;
	# cloud and storm grow them to an overcast. By night their bellies
	# sink toward the sky's ultramarine.
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	_cloud_scroll = fposmod(_cloud_scroll + delta * (CLOUD_TURN.x + CLOUD_TURN.y * wind.length()), 1.0)
	sky_material.set_shader_parameter("cloud_scroll", _cloud_scroll)
	sky_material.set_shader_parameter("bank_cover", clampf(0.25 + 0.6 * cloud + 0.25 * storm, 0.0, 1.0))
	sky_material.set_shader_parameter("streak_cover", clampf(0.3 + 0.35 * cloud, 0.0, 1.0))
	# In twilight the sun still paints them rose after it's down; storms
	# grey them.
	var twilight := smoothstep(-12.0, -3.0, sun_elevation_deg) * (1.0 - smoothstep(-1.0, 6.0, sun_elevation_deg))
	var painted_lit := cloud_light.lerp(Color(1.0, 0.5, 0.55), twilight * 0.8)
	painted_lit = painted_lit.lerp(Color(0.62, 0.65, 0.72) * (0.3 + 0.7 * daylight), storm * 0.7)
	sky_material.set_shader_parameter("cloud_lit", painted_lit)
	sky_material.set_shader_parameter("cloud_shade", cloud_shade.lerp(_scene_color(zenith) * 1.3, night * 0.9))
	# Their light's direction turns from the moon to the sun across the
	# band, at an even pace. The two can point nearly opposite (a full
	# moon), so it swings over through the local up: moon -> up -> sun.
	var band := DayCycle.cloud_light_band()
	var to_sun := smoothstep(band.x, band.y, sun_elevation_deg)
	var a_moon := moon_dir.angle_to(up)
	var a_sun := up.angle_to(sun_dir)
	var split := a_moon / maxf(a_moon + a_sun, 1e-4)
	if to_sun < split:
		cloud_light_dir = _turn(moon_dir, up, to_sun / maxf(split, 1e-4))
	else:
		cloud_light_dir = _turn(up, sun_dir, (to_sun - split) / maxf(1.0 - split, 1e-4))

	# Ambient: low and deep blue, day and night (data/look.json): it's all
	# a shadow gets, so shadows are deep and blue, never grey. The moon
	# lifts the night's a little.
	var amb_day := Color(str(DAY.get("ambient_color", "#2C4AA8")))
	var amb_night := Color(str(NIGHT.get("ambient_color", "#1C2A8C"))).lerp(FILL_MOON, lift * 0.3)
	var e_day := float(DAY.get("ambient_energy", 0.16))
	var e_night := float(NIGHT.get("ambient_energy", 0.2)) * (1.0 + 0.4 * lift)
	environment.ambient_light_color = amb_night.lerp(amb_day, daylight)
	environment.ambient_light_energy = lerpf(e_night, e_day, daylight) * (1.0 - MAGIC_DARKEN * dark_magic)

	# Fog and mist (drawn by the world shaders, see Look): a light haze
	# that gives depth to long daytime views; thicker at night and in cloud
	# forests, on coasts and in storms, with ground mist pooling in low
	# places after dark. Atmospheric perspective: by day distance fades
	# into the sky's own horizon blue (a little deeper at dusk, so the
	# warm band stays in the sky); at night into the R1a night fog, a
	# bright ultramarine, so distance dissolves to blue, never black.
	var fog_color := horizon.lerp(zenith, 0.5 * warm_band).lerp(NIGHT_FOG, night)
	fog_color = _scene_color(fog_color).lerp(Color(0.015, 0.03, 0.12), dark_magic * 0.6)
	var density := 0.0008 + fog_amount * 0.003 + storm * 0.002 + night * FOG_NIGHT
	var mist := clampf(0.5 * night + fog_amount * 0.6 + storm * 0.3, 0.0, 1.0)
	environment.fog_light_color = fog_color
	environment.fog_density = density
	Look.apply({
		"look_leaf_shadow_m": float(LIGHT.get("leaf_shadow_m", 1e6)),
		"look_fog_color": fog_color,
		"look_fog_density": density,
		"look_mist": mist,
		"look_up": up,
		"look_night": night,
		"look_glow": 1.0 - smoothstep(0.08, 0.55, daylight),
	})
	sky_material.set_shader_parameter("fog_color", fog_color)


## The scene color that comes out on screen as `c` (sRGB): undoes the
## environment's adjustment (saturation about the mean, then contrast
## about mid-grey, applied to the sRGB image) and its exposure, so the
## palette's hex values read true on screen before the post grade.
func _scene_color(c: Color) -> Color:
	var s := environment.adjustment_saturation if environment.adjustment_enabled else 1.0
	var k := environment.adjustment_contrast if environment.adjustment_enabled else 1.0
	var m := (c.r + c.g + c.b) / 3.0
	var v := Vector3(c.r, c.g, c.b)
	v = Vector3(m, m, m) + (v - Vector3(m, m, m)) / s
	v = Vector3(0.5, 0.5, 0.5) + (v - Vector3(0.5, 0.5, 0.5)) / k
	var lin := Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0)).srgb_to_linear()
	var e := environment.tonemap_exposure
	return Color(lin.r / e, lin.g / e, lin.b / e).linear_to_srgb()


## The mansion glyph beside the moon. When the moon enters the next
## mansion the old glyph fades out, the new one is swapped in unseen and
## fades in (DayCycle.glyph_fade_s each way); if the glyph isn't showing
## at that moment it simply swaps.
func _update_glyph(days: float, visibility: float, delta: float) -> void:
	var want := Astro.mansion_index(days)
	var step := delta / DayCycle.glyph_fade_s()
	if want != _shown_mansion:
		if _shown_mansion < 0 or visibility * _glyph_fade < 0.002:
			_set_glyph(want)
		else:
			_glyph_fade = move_toward(_glyph_fade, 0.0, step)
			if _glyph_fade <= 0.0:
				_set_glyph(want)
	else:
		_glyph_fade = move_toward(_glyph_fade, 1.0, step)
	sky_material.set_shader_parameter("glyph_visibility", visibility * smoothstep(0.0, 1.0, _glyph_fade))


func _set_glyph(mansion: int) -> void:
	_shown_mansion = mansion
	var pattern: Array = LunarMansions.stars(mansion)
	var packed := PackedVector2Array()
	packed.resize(LunarMansions.MAX_STARS)
	for i in pattern.size():
		packed[i] = pattern[i]
	sky_material.set_shader_parameter("glyph_stars", packed)
	sky_material.set_shader_parameter("glyph_count", pattern.size())
	sky_material.set_shader_parameter("glyph_color", LunarMansions.tint(mansion))


## From `a` toward `b` by `t` (0-1) along the great circle, evenly.
static func _turn(a: Vector3, b: Vector3, t: float) -> Vector3:
	var angle := a.angle_to(b)
	if angle < 1e-4:
		return b
	var axis := a.cross(b)
	if axis.length() < 1e-4: # opposite: any perpendicular will do
		axis = a.cross(Vector3.RIGHT if absf(a.x) < 0.9 else Vector3.FORWARD)
	return a.rotated(axis.normalized(), angle * clampf(t, 0.0, 1.0))


## Where a light shines from: `dir` (toward the body) with its elevation
## squeezed smoothly under look "light" rake_max_deg, so it rakes across
## the ground even at noon. Near overhead the body's bearing is lost, so
## the light leans rake_bias toward the equator side (away from the north
## pole's direction here), more the higher it stands; at the horizon it is
## the body's own bearing. Below the horizon: unchanged (the light is off).
static func _rake(dir: Vector3, up: Vector3, north: Vector3) -> Vector3:
	var el := asin(clampf(dir.dot(up), -1.0, 1.0))
	if el <= 0.0:
		return dir
	var cap := deg_to_rad(float(LIGHT.get("rake_max_deg", 38.0)))
	var el2 := cap * tanh(el / cap)
	var h := dir - up * dir.dot(up)
	h -= (north - up * north.dot(up)).normalized() * float(LIGHT.get("rake_bias", 0.45)) * smoothstep(0.0, deg_to_rad(40.0), el)
	if h.length() < 1e-5:
		return dir
	h = h.normalized()
	return (h * cos(el2) + up * sin(el2)).normalized()


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


## A meteor's flash (SkyEvents): a brief tint of its color over the land,
## added to the ambient on top of what update_sky() set this frame.
func event_flash(amount: float, color: Color) -> void:
	if amount > 0.001:
		environment.ambient_light_color = environment.ambient_light_color.lerp(color, amount * 0.6)
		environment.ambient_light_energy += amount * 0.5

class_name GlossyLook
## The crawler's glossy look (design §GB, 25 Oct; queue 111; data/look.json
## "glossy"): high contrast, smooth and glossy, a dream lit at night.
## Picked by look.json glossy.crawler_preset ("glossy", the default, or
## "pixel", §ES/§EU's 3D pixel art, kept as it was); LOOK=pixel or
## LOOK=glossy in the environment overrides it for one run. The open world
## never turns it on.
##
## Under glossy:
## - the frame is the window's own size (Display: canvas_items stretch, so
##   the 3D draws at full resolution and only the HUD is laid out at
##   854x480 and scaled smoothly); the post grade keeps its grade but runs
##   no dither, grain, bleed or posterising;
## - the ruin stone (RuinBuilder.material_lit(): walls, floors, the hearth,
##   pots, gates) is ruin.gdshader built with GLOSSY: linear, mipmapped,
##   anisotropic tiles, a bump drawn from each tile's own brightness,
##   low roughness (wetter floors), specular and a rim;
## - the WorldEnvironment tonemaps ACES, blooms only bright and emissive
##   things, pushes contrast and saturation and grades the darks to
##   #07071a and indigo (§GB.3); the haze is indigo and heavier;
## - a soft cobalt back light rides ahead of your eye;
## - the flame card is smooth (no texel grid, no bands), one amber (§EX.6).

static var active := false
static var _stone: ShaderMaterial = null
static var _flame: Shader = null


static func G() -> Dictionary:
	return Tuning.section("look", "glossy")


## Whether the crawler should run glossy (the environment's LOOK first).
static func wanted() -> bool:
	var env := OS.get_environment("LOOK").strip_edges().to_lower()
	if env == "glossy" or env == "pixel":
		return env == "glossy"
	return str(G().get("crawler_preset", "glossy")) == "glossy"


static func preset_name() -> String:
	return "glossy" if active else "pixel"


## The HUD's layout size under glossy.
static func hud_size() -> Vector2i:
	var a: Array = G().get("hud_reference", [854, 480])
	return Vector2i(int(a[0]), int(a[1]))


## The ruin stone under glossy: ruin.gdshader with GLOSSY defined, per-pixel
## lit, specular on, its tiles sampled linear with every mip.
static func stone_material() -> ShaderMaterial:
	if _stone != null:
		return _stone
	var code := (preload("res://shaders/ruin.gdshader") as Shader).code
	code = code.replace("vertex_lighting, ", "").replace(", specular_disabled", ", specular_schlick_ggx")
	code = code.replace("filter_nearest_mipmap,", "filter_linear_mipmap_anisotropic,")
	code = code.replace("shader_type spatial;", "shader_type spatial;\n#define GLOSSY")
	var sh := Shader.new()
	sh.code = code
	_stone = ShaderMaterial.new()
	_stone.shader = sh
	var s: Dictionary = G().get("stone", {})
	_stone.set_shader_parameter("gloss_normal_depth", float(s.get("normal_depth_m", 0.012)))
	_stone.set_shader_parameter("gloss_rough", Vector3(float(s.get("roughness_wall", 0.38)), float(s.get("roughness_floor", 0.22)), float(s.get("roughness_moss", 0.75))))
	_stone.set_shader_parameter("gloss_specular", float(s.get("specular", 0.6)))
	_stone.set_shader_parameter("gloss_rim", Vector2(float(s.get("rim", 0.35)), float(s.get("rim_tint", 0.4))))
	Look.register(_stone)
	return _stone


## The flame card's shader under glossy: smooth, no texel grid, no bands.
static func flame_shader() -> Shader:
	if _flame == null:
		_flame = Shader.new()
		_flame.code = (preload("res://shaders/flame.gdshader") as Shader).code.replace("shader_type spatial;", "shader_type spatial;\n#define SMOOTH_FIRE").replace("look_grain_soft : filter_nearest,", "look_grain_soft : filter_linear,")
	return _flame


static func flame_soft_edge() -> float:
	return float((G().get("fire", {}) as Dictionary).get("soft_edge", 0.35))


## The indigo haze: {"density", "color"} (FloorFog's haze under glossy).
static func haze_density() -> float:
	return float((G().get("fog", {}) as Dictionary).get("density", 0.06))


static func haze_color() -> Color:
	return Color(str((G().get("fog", {}) as Dictionary).get("color", "#1a1a6e")))


## The WorldEnvironment's glossy settings (crawler_main._environment).
static func environment(env: Environment) -> void:
	var e: Dictionary = G().get("environment", {})
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if str(e.get("tonemap", "aces")) == "filmic" else Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(e.get("exposure", 1.1))
	env.background_color = haze_color()
	var gl: Dictionary = e.get("glow", {})
	env.glow_enabled = bool(gl.get("enabled", true))
	env.glow_hdr_threshold = float(gl.get("hdr_threshold", 0.9))
	env.glow_intensity = float(gl.get("intensity", 0.9))
	env.glow_strength = float(gl.get("strength", 1.0))
	env.glow_bloom = float(gl.get("bloom", 0.05))
	var levels: Array = gl.get("levels", [2, 3, 4, 5])
	for i in range(1, 8):
		env.set_glow_level(i - 1, 1.0 if levels.has(i) or levels.has(float(i)) else 0.0)
	match str(gl.get("blend", "softlight")):
		"additive":
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		"screen":
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		_:
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = float(e.get("contrast", 1.2))
	env.adjustment_saturation = float(e.get("saturation", 1.3))
	env.adjustment_brightness = float(e.get("brightness", 1.0))
	var stops: Array = e.get("grade", [])
	if stops.size() >= 2:
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for st: Array in stops:
			offs.append(float(st[0]))
			cols.append(Color(str(st[1])))
		var g := Gradient.new()
		g.offsets = offs
		g.colors = cols
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 256
		env.adjustment_color_correction = gt
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = haze_density()
	env.fog_light_color = haze_color()
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.fog_height_density = 0.0
	var v: Dictionary = (G().get("fog", {}) as Dictionary).get("volumetric", {})
	env.volumetric_fog_enabled = bool(v.get("enabled", false))
	env.volumetric_fog_density = float(v.get("density", 0.015))
	env.volumetric_fog_albedo = Color(str(v.get("albedo", "#2b3fd1")))
	env.volumetric_fog_length = float(v.get("length_m", 48.0))


## The post grade under glossy: the WorldEnvironment grades instead; the
## post keeps the fire's whites (§EX.6) and harm, and runs no dither,
## grain, bleed or 5-bit levels.
static func post(p: PostGrade) -> void:
	var m := p._rect.material as ShaderMaterial
	m.set_shader_parameter("dither", 0.0)
	m.set_shader_parameter("grain", 0.0)
	m.set_shader_parameter("bleed", 0.0)
	m.set_shader_parameter("levels", 255.0)
	m.set_shader_parameter("env_graded", 1.0)


## The cobalt back light, carried by `camera` (none when energy is 0).
static func back_light(camera: Camera3D) -> OmniLight3D:
	var b: Dictionary = G().get("back_light", {})
	var energy := float(b.get("energy", 0.45))
	if camera == null or energy <= 0.0:
		return null
	var l := OmniLight3D.new()
	l.name = "GlossyBackLight"
	l.light_color = Color(str(b.get("color", "#2b3fd1")))
	l.light_energy = energy
	l.light_specular = 1.0
	l.omni_range = float(b.get("range_m", 9.0))
	l.shadow_enabled = false
	var o: Array = b.get("offset_m", [0.0, 0.6, 3.0])
	l.position = Vector3(float(o[0]), float(o[1]), -float(o[2]))
	camera.add_child(l)
	return l

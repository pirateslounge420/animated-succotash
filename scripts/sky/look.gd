class_name Look
## The art-direction knobs every world material shares (shaders/
## look.gdshaderinc): banded fog and mist, and the bioluminescent glow.
## Materials register once; SkySystem pushes new values each frame.
##
## Also owns the world's textures, painted at startup on a worker thread
## (LookTextures: 256 px, painted, drawn linear-filtered with mipmaps so
## they're gently soft, never pixel-art). The
## shaders add the large-scale light and dark over them with the grain.
## They modulate the vertex colors (0.5 = unchanged, so one texture serves
## every species and biome color):
##   grain      64 px soft grain (large-scale light and dark, moss patches)
##   grass      streaky blades, light and dark
##   dirt       pebbles and clods (soil, paths)
##   sand       fine grains in soft wind ripples (beaches, deserts)
##   water      a net of bright caustic lines over a mottled base
##   bark       vertical streaks and dark grooves
##   leaves     a dense leafy surface for crowns
##   leaf_card  a ragged leaf cluster with alpha, for cutout cards
##   stone      mottled, cracked blocks (ruins, rock faces)
##   weave      woven plant fiber, over-under strands (the player's robe)
##   fur        soft short strokes hanging down (fur trim and mantles)

static var _materials: Array[ShaderMaterial] = []
static var _params := {}
static var _grain: ImageTexture
static var _textures := {}

const GRAIN_SIZE := 64


## Add a material to the shared look (call on the main thread): its
## textures. The per-frame values are global shader uniforms (apply()).
static func register(mat: ShaderMaterial) -> ShaderMaterial:
	if not _materials.has(mat):
		_materials.append(mat)
		mat.set_shader_parameter("look_grain", grain())
		# The same grain, smoothly filtered: large-scale light and dark.
		mat.set_shader_parameter("look_grain_soft", grain())
		for name in ["grass", "dirt", "sand", "bark", "leaves", "leaf_card", "stone", "water"]:
			mat.set_shader_parameter("look_tex_" + name, texture(name))
	return mat


## Set some of the shared values (others keep their last ones). They're
## global shader uniforms (project settings, [shader_globals]), so each is
## one write however many materials there are. Colors go in linear (the
## shaders read them as plain vec3s); "look_sites" (8 Vector4: scene
## position, radius) and "look_site_kind" (8 floats) are unpacked into
## look_site_0..7 and look_site_kind_a/b.
static func apply(params: Dictionary) -> void:
	_params.merge(params, true)
	for k in params:
		var v = params[k]
		match k:
			"look_sites":
				var sites: PackedVector4Array = v
				for i in 8:
					RenderingServer.global_shader_parameter_set("look_site_%d" % i, sites[i] if i < sites.size() else Vector4.ZERO)
			"look_site_kind":
				var kinds: PackedFloat32Array = v
				var kk := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
				for i in mini(kinds.size(), 8):
					kk[i] = kinds[i]
				RenderingServer.global_shader_parameter_set("look_site_kind_a", Vector4(kk[0], kk[1], kk[2], kk[3]))
				RenderingServer.global_shader_parameter_set("look_site_kind_b", Vector4(kk[4], kk[5], kk[6], kk[7]))
			_:
				if v is Color:
					var c := (v as Color).srgb_to_linear()
					v = Vector3(c.r, c.g, c.b)
				RenderingServer.global_shader_parameter_set(k, v)


## 64 x 64 grayscale grain around 0.5: soft, painterly light and dark
## with a little cellular clumping, stretched big by the shaders.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	var img := Image.create(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_L8)
	var soft := FastNoiseLite.new()
	soft.seed = 7
	soft.frequency = 0.12
	var cells := FastNoiseLite.new()
	cells.seed = 8
	cells.frequency = 0.2
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in GRAIN_SIZE:
		for x in GRAIN_SIZE:
			# Tileable: sample the noise on a torus.
			var a := TAU * x / GRAIN_SIZE
			var b := TAU * y / GRAIN_SIZE
			var p := Vector3(cos(a) * 8.0, sin(a) * 8.0 + cos(b) * 8.0, sin(b) * 8.0)
			var v := 0.5 + 0.3 * soft.get_noise_3dv(p) + 0.12 * cells.get_noise_3dv(p) + rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


const NAMES := ["grass", "dirt", "sand", "water", "bark", "leaves", "leaf_card", "stone", "weave", "fur"]
static var _images := {}
static var _images_mutex := Mutex.new()
static var _task := -1


## Start painting every texture on a worker thread (call early, e.g. while
## the planet generates); texture() waits for it if it's still going.
static func prepare() -> void:
	if _task >= 0:
		return
	_task = WorkerThreadPool.add_task(func() -> void:
		for n in NAMES:
			var img := LookTextures.make(n)
			_images_mutex.lock()
			_images[n] = img
			_images_mutex.unlock())


## Wait for the painting task (a worker task must be waited on once, or
## it's left dangling at exit).
static func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2


## One of the named world textures (see the class notes).
static func texture(name: String) -> ImageTexture:
	if _textures.has(name):
		return _textures[name]
	finish()
	var img: Image = _images.get(name)
	if img == null:
		img = LookTextures.make(name)
	var tex := ImageTexture.create_from_image(img)
	_textures[name] = tex
	return tex

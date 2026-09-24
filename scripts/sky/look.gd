class_name Look
## The art-direction knobs every world material shares (shaders/
## look.gdshaderinc): banded fog and mist, and the bioluminescent glow.
## Materials register once; SkySystem pushes new values each frame.
##
## Also owns the one texture the world uses: a deliberately low-res (32 px),
## nearest-filtered grain that gives flat vertex colors a crunchy,
## hand-painted PS1/GameCube surface instead of smooth PBR detail.

static var _materials: Array[ShaderMaterial] = []
static var _params := {}
static var _grain: ImageTexture

const GRAIN_SIZE := 32


## Add a material to the shared look (call on the main thread).
static func register(mat: ShaderMaterial) -> ShaderMaterial:
	if not _materials.has(mat):
		_materials.append(mat)
		for k in _params:
			mat.set_shader_parameter(k, _params[k])
		mat.set_shader_parameter("look_grain", grain())
	return mat


## Set some of the shared uniforms (others keep their last values).
static func apply(params: Dictionary) -> void:
	_params.merge(params, true)
	for mat in _materials:
		for k in params:
			mat.set_shader_parameter(k, params[k])


## 32 x 32 grayscale grain around 1.0: blotchy 2-4 px clusters of lighter
## and darker, like a tiny hand-painted stone/soil texture stretched big.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	var img := Image.create(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_L8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.22
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in GRAIN_SIZE:
		for x in GRAIN_SIZE:
			# Tileable: sample the noise on a torus.
			var a := TAU * x / GRAIN_SIZE
			var b := TAU * y / GRAIN_SIZE
			var n := noise.get_noise_3d(cos(a) * 8.0, sin(a) * 8.0 + cos(b) * 8.0, sin(b) * 8.0)
			var v := 0.5 + 0.35 * n + rng.randf_range(-0.08, 0.08)
			img.set_pixel(x, y, Color(v, v, v))
	_grain = ImageTexture.create_from_image(img)
	return _grain

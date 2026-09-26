class_name Look
## The art-direction knobs every world material shares (shaders/
## look.gdshaderinc): banded fog and mist, and the bioluminescent glow.
## Materials register once; SkySystem pushes new values each frame.
##
## Also owns the world's textures, all generated here at startup: 128 px
## and nearest-filtered, so texels stay crisp, but dense with painted
## detail (hundreds of grass blades, leaves, pebbles per tile), like
## hand-painted N64/PS2-era surfaces rather than realism. The shaders add
## the large-scale light and dark over them with the grain, smoothly
## filtered. They modulate the vertex colors
## (0.5 = unchanged, so one texture serves every species and biome color):
##   grain      32 px blotchy grain (general crunch, glow-moss patches)
##   grass      streaky blades, light and dark
##   dirt       pebbles and clods (sand, soil, paths)
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

const GRAIN_SIZE := 32


## Add a material to the shared look (call on the main thread).
static func register(mat: ShaderMaterial) -> ShaderMaterial:
	if not _materials.has(mat):
		_materials.append(mat)
		for k in _params:
			mat.set_shader_parameter(k, _params[k])
		mat.set_shader_parameter("look_grain", grain())
		# The same grain, smoothly filtered: large-scale light and dark.
		mat.set_shader_parameter("look_grain_soft", grain())
		for name in ["grass", "dirt", "bark", "leaves", "leaf_card", "stone"]:
			mat.set_shader_parameter("look_tex_" + name, texture(name))
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
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


const TEX := 128
## Detail counts are tuned per 64 x 64 px; scaled by area to TEX.
const AREA := (TEX * TEX) / (64 * 64)


## One of the named world textures (see the class notes), built on first use.
static func texture(name: String) -> ImageTexture:
	if _textures.has(name):
		return _textures[name]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var img: Image
	match name:
		"grass":
			img = _grass(rng)
		"dirt":
			img = _dirt(rng)
		"bark":
			img = _bark(rng)
		"leaves":
			img = _leaves(rng, false)
		"leaf_card":
			img = _leaves(rng, true)
		"weave":
			img = _weave(rng)
		"fur":
			img = _fur(rng)
		_:
			img = _stone(rng)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[name] = tex
	return tex


static func _noise(seed_value: int, freq: float, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.noise_type = kind
	return n


## Tileable noise: sample on a torus. `sx`, `sy` stretch each axis.
static func _torus(n: FastNoiseLite, x: float, y: float, sx := 1.0, sy := 1.0) -> float:
	var a := TAU * x / TEX
	var b := TAU * y / TEX
	return n.get_noise_3d(cos(a) * 10.0 * sx, sin(a) * 10.0 * sx + cos(b) * 10.0 * sy, sin(b) * 10.0 * sy)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, TEX), posmod(y, TEX), c)


static func _grass(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var base := _noise(11, 0.18)
	for y in TEX:
		for x in TEX:
			var v := 0.46 + 0.07 * _torus(base, x, y)
			img.set_pixel(x, y, Color(v, v, v * 0.97))
	# Blades: short strokes leaning mostly upward, light tips and dark gaps.
	for i in 520 * AREA:
		var x := rng.randf() * TEX
		var y := rng.randf() * TEX
		var ang := -PI * 0.5 + rng.randf_range(-0.3, 0.3)
		var length := rng.randi_range(5, 14)
		var light := rng.randf() < 0.58
		var v := rng.randf_range(0.58, 0.74) if light else rng.randf_range(0.26, 0.38)
		var col := Color(v * 1.04, v, v * 0.9) if light else Color(v * 0.95, v, v * 1.05)
		for k in length:
			_put(img, int(x + cos(ang) * k), int(y + sin(ang) * k), col.lightened(0.04 * k / length) if light else col)
	return img


static func _dirt(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var clods := _noise(21, 0.3, FastNoiseLite.TYPE_CELLULAR)
	var soft := _noise(22, 0.12)
	for y in TEX:
		for x in TEX:
			var v := 0.48 + 0.09 * _torus(clods, x, y) + 0.06 * _torus(soft, x, y)
			img.set_pixel(x, y, Color(v * 1.03, v, v * 0.94))
	# Pebbles of a few sizes, lit on top and shadowed underneath, and dark
	# crumbs and twigs between them.
	for i in 65 * AREA:
		var cx := rng.randf() * TEX
		var cy := rng.randf() * TEX
		var r := rng.randf_range(0.5, 1.6) if rng.randf() < 0.9 else rng.randf_range(1.6, 2.8)
		var v := rng.randf_range(0.56, 0.74)
		var tone := Color(v, v * 0.98, v * 0.92)
		var ri := int(ceil(r)) + 1
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var d := Vector2(dx, dy).length()
				if d > r:
					if d < r + 1.0 and dy > 0:
						_put(img, int(cx) + dx, int(cy) + dy, Color(0.3, 0.29, 0.27)) # shadow
					continue
				# Lit from the upper left.
				var lit := clampf(0.5 - (dx + dy) / (2.0 * r + 0.01) * 0.5, 0.0, 1.0)
				_put(img, int(cx) + dx, int(cy) + dy, tone.darkened(0.25 * (1.0 - lit)).lightened(0.1 * lit))
	for i in 40 * AREA:
		var x := rng.randf() * TEX
		var y := rng.randf() * TEX
		var ang := rng.randf() * TAU
		var dark := Color(0.27, 0.24, 0.21)
		for k in rng.randi_range(1, 6):
			_put(img, int(x + cos(ang) * k), int(y + sin(ang) * k), dark)
	return img


static func _bark(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var streak := _noise(31, 0.2)
	for y in TEX:
		for x in TEX:
			# Stretched along y: long vertical streaks.
			var v := 0.5 + 0.13 * _torus(streak, x, y, 1.0, 0.12)
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.93))
	# Dark wandering grooves with a lit edge beside each.
	var x0 := 0.0
	while x0 < TEX:
		var x := x0
		for y in TEX:
			x += rng.randf_range(-0.6, 0.6)
			_put(img, int(x), y, Color(0.22, 0.2, 0.19))
			_put(img, int(x) + 1, y, Color(0.66, 0.63, 0.58))
		x0 += rng.randf_range(7.0, 14.0)
	return img


## Leaves: overlapping small leaf shapes, light ones catching the sun and
## dark gaps between. `card` = a ragged cluster on transparency.
static func _leaves(rng: RandomNumberGenerator, card: bool) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var bg := Color(0.38, 0.38, 0.38, 0.0 if card else 1.0)
	img.fill(bg)
	var center := Vector2(TEX, TEX) * 0.5
	var count := (900 if card else 330) * AREA
	for i in count:
		var p := Vector2(rng.randf() * TEX, rng.randf() * TEX)
		if card:
			# Denser in the middle, ragged at the rim, nothing at the edges.
			var r := p.distance_to(center) / (TEX * 0.46)
			if r > 1.0 or rng.randf() < r * r:
				continue
		var ang := rng.randf() * TAU
		var w := rng.randf_range(2.0, 3.6) * (1.25 if card else 1.0)
		var h := rng.randf_range(1.0, 1.8) * (1.25 if card else 1.0)
		var v := rng.randf_range(0.5, 0.85)
		var col := Color(v * rng.randf_range(0.94, 1.06), v, v * rng.randf_range(0.88, 1.0), 1.0)
		var ax := Vector2(cos(ang), sin(ang))
		var ay := Vector2(-ax.y, ax.x)
		for dy in range(-3, 4):
			for dx in range(-4, 5):
				var q := Vector2(dx, dy)
				var u := q.dot(ax) / w
				var t := q.dot(ay) / h
				if u * u + t * t <= 1.0:
					var px := int(p.x) + dx
					var py := int(p.y) + dy
					if card and (px < 0 or py < 0 or px >= TEX or py >= TEX):
						continue
					# Leaves are a touch darker toward their lower edge.
					_put(img, px, py, col.darkened(0.12 * clampf(t, 0.0, 1.0)))
	return img


static func _stone(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var cells := _noise(41, 0.09, FastNoiseLite.TYPE_CELLULAR)
	cells.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var edges := _noise(41, 0.09, FastNoiseLite.TYPE_CELLULAR)
	edges.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var mottle := _noise(42, 0.35)
	for y in TEX:
		for x in TEX:
			var v := 0.5 + 0.1 * _torus(cells, x, y) + 0.08 * _torus(mottle, x, y) + rng.randf_range(-0.04, 0.04)
			# Cracks along the cell borders.
			var e := _torus(edges, x, y)
			if e < -0.93:
				v *= 0.62
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.97))
	return img


## Woven plant fiber: strands 4 px wide going over and under in a basket
## weave, each strand a slightly different shade, with a few stray fibers.
static func _weave(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var mottle := _noise(51, 0.15)
	var shade: Array[float] = []
	for i in TEX / 4:
		shade.append(rng.randf_range(-0.05, 0.05))
	for y in TEX:
		for x in TEX:
			var cx := x / 4
			var cy := y / 4
			var over := (cx + cy) % 2 == 0
			# Along the strand a soft ridge; the gaps between strands dark.
			var across := (y % 4) if over else (x % 4)
			var v := 0.52 + shade[cy if over else cx] + 0.05 * _torus(mottle, x, y)
			v += 0.06 if across == 1 or across == 2 else -0.08
			if not over:
				v -= 0.04
			img.set_pixel(x, y, Color(v * 1.02, v, v * 0.93))
	for i in 14 * AREA:
		var x := rng.randf() * TEX
		var y := rng.randf() * TEX
		var ang := rng.randf() * TAU
		for k in rng.randi_range(4, 8):
			_put(img, int(x + cos(ang) * k), int(y + sin(ang) * k), Color(0.64, 0.62, 0.55))
	return img


## Fur: a soft mottled base under short strokes hanging mostly downward,
## light tips over dark roots.
static func _fur(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var soft := _noise(61, 0.14)
	for y in TEX:
		for x in TEX:
			var v := 0.45 + 0.08 * _torus(soft, x, y)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.95))
	for i in 700 * AREA:
		var x := rng.randf() * TEX
		var y := rng.randf() * TEX
		var ang := PI * 0.5 + rng.randf_range(-0.45, 0.45)
		var length := rng.randi_range(3, 7)
		var v := rng.randf_range(0.3, 0.72)
		for k in length:
			var t := float(k) / length
			_put(img, int(x + cos(ang) * k), int(y + sin(ang) * k), Color(v, v * 0.97, v * 0.93).lightened(0.12 * t))
	return img

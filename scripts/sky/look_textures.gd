class_name LookTextures
## The world's textures, painted at startup (Look.texture() hands them
## out): 256 px, dense with painted detail (blades, leaves, pebbles,
## cracks drawn as shaded sprites), drawn nearest-filtered with mipmaps so
## texels stay crisp under the sharpening grade. Each
## is centered on mid-grey (0.5 = no change: the shaders multiply them
## by the vertex colors, so one texture serves every species and biome).
##
## Built from native pieces so it's quick: FastNoiseLite's seamless noise
## images for the soft layers, and small anti-aliased sprites (blades,
## leaves, pebbles, strokes) stamped with Image.blend_rect, wrapping at
## the edges so every texture tiles.

const TEX := 256


## Every texture by name (see Look's class notes for what each is).
static func make(name: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var img: Image
	match name:
		"grass":
			img = _grass(rng)
		"dirt":
			img = _dirt(rng)
		"sand":
			img = _sand(rng)
		"water":
			img = _water(rng)
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
	return img


# --- Building blocks --------------------------------------------------------------

## A tileable noise field, TEX x TEX floats in 0..1: `cycles` blobs across
## the tile.
static func _field(seed_value: int, cycles: float, octaves := 3, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		cell_return := FastNoiseLite.RETURN_CELL_VALUE) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = kind
	n.frequency = cycles / TEX
	n.fractal_octaves = octaves
	if octaves <= 1:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_return_type = cell_return
	var bytes := n.get_seamless_image(TEX, TEX, false, false, 0.1, true).get_data()
	var out := PackedFloat32Array()
	out.resize(TEX * TEX)
	for i in TEX * TEX:
		out[i] = bytes[i] / 255.0
	return out


## An opaque image of values (grey, times `tint`).
static func _image(v: PackedFloat32Array, tint := Color(1, 1, 1)) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(TEX * TEX * 4)
	for i in TEX * TEX:
		var x := clampf(v[i], 0.0, 1.0)
		bytes[i * 4] = int(clampf(x * tint.r, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 1] = int(clampf(x * tint.g, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 2] = int(clampf(x * tint.b, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 3] = 255
	return Image.create_from_data(TEX, TEX, false, Image.FORMAT_RGBA8, bytes)


## Blend a sprite over `img` with its top-left at (x, y), wrapping round
## the tile's edges.
static func _stamp(img: Image, sprite: Image, x: int, y: int) -> void:
	var size := sprite.get_size()
	var rect := Rect2i(Vector2i.ZERO, size)
	for ox in [0, -TEX, TEX]:
		for oy in [0, -TEX, TEX]:
			var px: int = posmod(x, TEX) + ox
			var py: int = posmod(y, TEX) + oy
			if px + size.x > 0 and px < TEX and py + size.y > 0 and py < TEX:
				img.blend_rect(sprite, rect, Vector2i(px, py))


## A grass blade (or a fur stroke): a tapered, slightly curved stroke `len`
## px long and `w` wide at the root, leaning `lean` px and bowing `bow` px
## sideways, shading from `root` to `tip`; anti-aliased. `down` hangs it
## from the top (fur) instead of growing up from the bottom.
static func _blade(len: int, w: float, lean: float, bow: float, root: float, tip: float, tint: Color, down := false) -> Image:
	var pad := int(ceil(absf(lean) + absf(bow) + w)) + 2
	var width := pad * 2 + 1
	var img := Image.create(width, len + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in len + 2:
		var t := clampf(1.0 - (y - 1.0) / maxf(len - 1.0, 1.0), 0.0, 1.0) # 0 root .. 1 tip
		if down:
			t = 1.0 - t
		var cx := pad + 0.5 + lean * t + bow * 4.0 * t * (1.0 - t)
		var hw := lerpf(w * 0.5, 0.2, t)
		var v := lerpf(root, tip, t)
		for x in width:
			var a := clampf(hw - absf(x + 0.5 - cx) + 0.5, 0.0, 1.0)
			if t <= 0.0 or t >= 1.0:
				a *= 0.5
			if a > 0.0:
				img.set_pixel(x, y, Color(v * tint.r, v * tint.g, v * tint.b, a))
	return img


## A leaf `size` px long at `angle`: pointed at both ends (half-width
## narrowing as 1 - u^2 along it), lighter on its upper side and toward
## its tip, a faint midrib; anti-aliased edge.
static func _leaf(size: float, angle: float, v: float, tint: Color) -> Image:
	var r := int(ceil(size)) + 2
	var img := Image.create(r * 2 + 1, r * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ax := Vector2(cos(angle), sin(angle))
	var ay := Vector2(-ax.y, ax.x)
	var half := size * 0.5
	var b := size * 0.2
	for y in r * 2 + 1:
		for x in r * 2 + 1:
			var q := Vector2(x - r, y - r)
			var u := q.dot(ax) / half # -1 stem .. 1 tip
			var across := q.dot(ay)
			if absf(u) >= 1.0:
				continue
			var hw := b * (1.0 - u * u)
			var cover := clampf(hw - absf(across) + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var rib := clampf(1.0 - absf(across) / 0.8, 0.0, 1.0) * (1.0 - absf(u))
			var shade := v * (1.0 + 0.16 * clampf(-q.y / size * 2.0, -1.0, 1.0)) * (0.92 + 0.14 * (u * 0.5 + 0.5)) * (1.0 - 0.1 * rib)
			img.set_pixel(x, y, Color(shade * tint.r, shade * tint.g, shade * tint.b, cover))
	return img


## A pebble: a disc lit from the upper left with a soft shadow below it.
static func _pebble(radius: float, v: float) -> Image:
	var r := int(ceil(radius)) + 3
	var img := Image.create(r * 2 + 1, r * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in r * 2 + 1:
		for x in r * 2 + 1:
			var q := Vector2(x - r, y - r)
			var d := q.length() / radius
			# Shadow: offset down-right, soft.
			var sd := (q - Vector2(radius * 0.25, radius * 0.4)).length() / radius
			var sh := clampf((1.15 - sd) * 2.0, 0.0, 1.0) * 0.55
			var cover := clampf((1.0 - d) * radius + 0.5, 0.0, 1.0)
			var lit := clampf(0.5 - (q.x + q.y) / (2.0 * radius) * 0.6, 0.0, 1.0)
			var tone := v * (0.85 + 0.3 * lit)
			cover *= 0.85
			var c := Color(0.2, 0.19, 0.18).lerp(Color(tone, tone * 0.98, tone * 0.93), cover)
			var alpha := maxf(cover, sh)
			if alpha > 0.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	return img


## A soft round blob of value `v` (crumbs, specks).
static func _blob(radius: float, v: float, tint := Color(1, 1, 1)) -> Image:
	var r := int(ceil(radius)) + 1
	var img := Image.create(r * 2 + 1, r * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in r * 2 + 1:
		for x in r * 2 + 1:
			var d := Vector2(x - r, y - r).length()
			var a := clampf(radius - d + 0.5, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(v * tint.r, v * tint.g, v * tint.b, a))
	return img


# --- The textures ------------------------------------------------------------------

## Grass: soft mottled ground under two layers of painted blades, dark
## ones first and sunlit ones over them.
static func _grass(rng: RandomNumberGenerator) -> Image:
	var base := _field(11, 5.0)
	var fine := _field(12, 22.0, 2)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for i in TEX * TEX:
		v[i] = 0.38 + 0.1 * base[i] + 0.06 * fine[i]
	var img := _image(v, Color(1.0, 1.0, 0.96))
	var dark: Array[Image] = []
	var light: Array[Image] = []
	for k in 16:
		var lean := rng.randf_range(-7.0, 7.0)
		var bow := rng.randf_range(-3.0, 3.0)
		dark.append(_blade(rng.randi_range(14, 30), rng.randf_range(2.2, 3.4), lean, bow,
			rng.randf_range(0.24, 0.3), rng.randf_range(0.34, 0.42), Color(0.95, 1.0, 1.04)))
		light.append(_blade(rng.randi_range(16, 36), rng.randf_range(2.0, 3.2), lean, bow,
			rng.randf_range(0.46, 0.54), rng.randf_range(0.66, 0.78), Color(1.04, 1.0, 0.88)))
	for i in 900:
		var s: Image = dark[rng.randi() % dark.size()]
		_stamp(img, s, rng.randi() % TEX, rng.randi() % TEX)
	for i in 1300:
		var s: Image = light[rng.randi() % light.size()]
		_stamp(img, s, rng.randi() % TEX, rng.randi() % TEX)
	return img


## Dirt: soft clods and patches, pebbles of a few sizes lit from above
## with their shadows, dark crumbs between.
static func _dirt(rng: RandomNumberGenerator) -> Image:
	var clods := _field(21, 12.0, 3)
	var soft := _field(22, 4.0)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for i in TEX * TEX:
		v[i] = 0.38 + 0.14 * clods[i] + 0.1 * soft[i]
	var img := _image(v, Color(1.03, 1.0, 0.93))
	var pebbles: Array[Image] = []
	for k in 12:
		var small := k < 9
		pebbles.append(_pebble(rng.randf_range(1.5, 3.2) if small else rng.randf_range(3.2, 5.5), rng.randf_range(0.5, 0.62)))
	for i in 110:
		var s: Image = pebbles[rng.randi() % pebbles.size()]
		_stamp(img, s, rng.randi() % TEX, rng.randi() % TEX)
	var crumb := _blob(1.3, 0.24, Color(1.0, 0.95, 0.9))
	for i in 90:
		_stamp(img, crumb, rng.randi() % TEX, rng.randi() % TEX)
	return img


## Sand: soft wind ripples, bent, with a fine grain and scattered specks.
static func _sand(rng: RandomNumberGenerator) -> Image:
	var warp := _field(71, 3.0)
	var soft := _field(72, 8.0)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for y in TEX:
		for x in TEX:
			var i := y * TEX + x
			var ph := TAU * (8.0 * y / TEX + 1.2 * (warp[i] - 0.5))
			var ripple := sin(ph) + 0.35 * sin(2.0 * ph + 1.0)
			v[i] = 0.45 + 0.06 * ripple + 0.08 * (soft[i] - 0.5) + rng.randf_range(-0.02, 0.02)
	var img := _image(v, Color(1.02, 1.0, 0.95))
	var light := _blob(0.9, 0.66, Color(1.02, 1.0, 0.94))
	var dark := _blob(0.9, 0.34, Color(1.0, 0.97, 0.92))
	for i in 220:
		_stamp(img, light if rng.randf() < 0.6 else dark, rng.randi() % TEX, rng.randi() % TEX)
	return img


## Stone: soft-edged blocks of slightly different tone, painterly light
## and dark over them, and gentle cracks where blocks meet.
static func _stone(rng: RandomNumberGenerator) -> Image:
	var cells := _field(41, 7.0, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_CELL_VALUE)
	var edges := _field(41, 7.0, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var mottle := _field(42, 18.0, 2)
	var blotch := _field(43, 3.0)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for i in TEX * TEX:
		var x := 0.5 + 0.16 * (cells[i] - 0.5) + 0.1 * (mottle[i] - 0.5) + 0.14 * (blotch[i] - 0.5)
		var crack := 1.0 - smoothstep(0.015, 0.09, edges[i])
		x *= 1.0 - 0.34 * crack
		# A lit lip just beside each crack.
		x += 0.035 * (smoothstep(0.06, 0.1, edges[i]) - smoothstep(0.1, 0.16, edges[i]))
		v[i] = x + rng.randf_range(-0.012, 0.012)
	return _image(v, Color(1.0, 0.99, 0.97))


## Bark: long vertical fibers and dark wandering grooves with a lit edge.
static func _bark(rng: RandomNumberGenerator) -> Image:
	var streak := FastNoiseLite.new()
	streak.seed = 31
	streak.frequency = 0.2
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for y in TEX:
		for x in TEX:
			# Sampled on a torus, stretched along y: long fibers.
			var a := TAU * x / TEX
			var b := TAU * y / TEX
			var n := streak.get_noise_3d(cos(a) * 14.0, sin(a) * 14.0 + cos(b) * 1.6, sin(b) * 1.6)
			v[y * TEX + x] = 0.5 + 0.12 * n
	# Grooves.
	var x0 := 0.0
	while x0 < TEX:
		var wander := FastNoiseLite.new()
		wander.seed = rng.randi()
		wander.frequency = 0.02
		var width := rng.randf_range(1.6, 3.0)
		for y in TEX:
			var b := TAU * y / TEX
			var gx := x0 + 3.0 * wander.get_noise_2d(cos(b) * 20.0, sin(b) * 20.0)
			for dx in range(-4, 5):
				var x := int(floor(gx)) + dx
				var d := absf(x + 0.5 - gx)
				var i := y * TEX + posmod(x, TEX)
				if d < width:
					v[i] = lerpf(v[i], 0.24, clampf(width - d, 0.0, 1.0) * 0.9)
				elif d < width + 1.5 and x > gx:
					v[i] = lerpf(v[i], 0.64, 0.5 * clampf(width + 1.5 - d, 0.0, 1.0))
		x0 += rng.randf_range(12.0, 26.0)
	return _image(v, Color(1.0, 0.97, 0.93))


## Leaves: overlapping leaves, lit from above, dark gaps between; `card`:
## a ragged cluster on transparency, denser in the middle.
static func _leaves(rng: RandomNumberGenerator, card: bool) -> Image:
	var img: Image
	if card:
		img = Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.38, 0.38, 0.38, 0.0))
	else:
		var soft := _field(91, 6.0)
		var v := PackedFloat32Array()
		v.resize(TEX * TEX)
		for i in TEX * TEX:
			v[i] = 0.26 + 0.1 * soft[i]
		img = _image(v)
	var sprites: Array[Image] = []
	for k in 48:
		var size := rng.randf_range(10.0, 17.0) * (1.15 if card else 1.0)
		# Shaded leaves deeper in the crown, sunlit ones on top.
		var tone := rng.randf_range(0.34, 0.5) if k < 16 else rng.randf_range(0.5, 0.82)
		var tint := Color(rng.randf_range(0.93, 1.05), 1.0, rng.randf_range(0.84, 0.98))
		sprites.append(_leaf(size, rng.randf() * TAU, tone, tint))
	var center := Vector2(TEX, TEX) * 0.5
	var count := 420 if card else 900
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 6:
		tries += 1
		var p := Vector2(rng.randf() * TEX, rng.randf() * TEX)
		if card:
			var r := p.distance_to(center) / (TEX * 0.44)
			if r > 1.0 or rng.randf() < r * r:
				continue
		# Dark leaves first (placed early), light ones over them.
		var s: Image = sprites[rng.randi() % 16] if placed < count * 0.35 else sprites[16 + rng.randi() % (sprites.size() - 16)]
		var half := s.get_size() / 2
		if card:
			# Cards don't wrap: keep leaves off the edges.
			var pos := Vector2i(p) - half
			if pos.x < 0 or pos.y < 0 or pos.x + s.get_width() > TEX or pos.y + s.get_height() > TEX:
				continue
			img.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), pos)
		else:
			_stamp(img, s, int(p.x) - half.x, int(p.y) - half.y)
		placed += 1
	return img


## Woven plant fiber: 8 px strands over and under in a basket weave, each
## a soft rounded ridge in its own shade, with a few stray fibers.
static func _weave(rng: RandomNumberGenerator) -> Image:
	var mottle := _field(51, 6.0)
	var strand := 8
	var shade := PackedFloat32Array()
	for i in TEX / strand:
		shade.append(rng.randf_range(-0.05, 0.05))
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for y in TEX:
		for x in TEX:
			var cx := x / strand
			var cy := y / strand
			var over := (cx + cy) % 2 == 0
			var across := float((y % strand) if over else (x % strand)) + 0.5
			var ridge := sin(across / strand * PI) # 0 at the gaps, 1 mid-strand
			var i := y * TEX + x
			v[i] = 0.4 + shade[cy if over else cx] + 0.06 * (mottle[i] - 0.5) + 0.18 * ridge - (0.03 if not over else 0.0)
	var img := _image(v, Color(1.02, 1.0, 0.93))
	var fiber := _blade(12, 1.2, 6.0, 1.0, 0.62, 0.66, Color(1.02, 1.0, 0.92))
	for i in 24:
		_stamp(img, fiber, rng.randi() % TEX, rng.randi() % TEX)
	return img


## Fur: a soft base under short strokes hanging down, light tips over dark
## roots.
static func _fur(rng: RandomNumberGenerator) -> Image:
	var soft := _field(61, 6.0)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for i in TEX * TEX:
		v[i] = 0.38 + 0.12 * soft[i]
	var img := _image(v, Color(1.0, 0.98, 0.95))
	var strokes: Array[Image] = []
	for k in 20:
		var root := rng.randf_range(0.28, 0.42)
		strokes.append(_blade(rng.randi_range(8, 16), rng.randf_range(1.6, 2.6), rng.randf_range(-3.0, 3.0), rng.randf_range(-1.5, 1.5),
			root, root + rng.randf_range(0.18, 0.34), Color(1.0, 0.97, 0.93), true))
	for i in 1700:
		var s: Image = strokes[rng.randi() % strokes.size()]
		_stamp(img, s, rng.randi() % TEX, rng.randi() % TEX)
	return img


## Water: soft bright caustic lines where cells of noise meet, over a
## gently mottled base.
static func _water(rng: RandomNumberGenerator) -> Image:
	var cells := _field(81, 7.0, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE2_SUB)
	var mottle := _field(82, 4.0)
	var v := PackedFloat32Array()
	v.resize(TEX * TEX)
	for i in TEX * TEX:
		var line := 1.0 - smoothstep(0.0, 0.14, cells[i])
		v[i] = 0.4 + 0.12 * (mottle[i] - 0.5) + 0.32 * line + rng.randf_range(-0.01, 0.01)
	return _image(v)

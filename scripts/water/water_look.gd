class_name WaterLook
extends RefCounted
## Water's colours by family (design §BU step 4, Mike: glowier than its
## surroundings but biome-matched; data/look.json `water`): each water
## family (clear, river, lake, swamp, sea, reef, desert, tropics) has a
## base and a highlight colour; a chunk's water takes the family of the
## biome at its middle, anything unmapped the default family. The glow
## (day and night) and the scrolling caustic tile are shared. One
## material per family and salt/fresh, made on first use.
##
## 1 Oct look pass (water `_help_tune`): the day body is the shared `base`
## (and `calm` for still fresh water) blended toward the family's base by
## `biome_tint`; glints (the shared `glint` toward the family's highlight)
## flare where two layers of glint_texture() pass `glint_cover`.

static var W: Dictionary = Tuning.section("look", "water")
static var _by_biome := {}
static var _materials := {}
static var _glint: ImageTexture


static func family_of(biome_key: String) -> String:
	if _by_biome.is_empty():
		var fams: Dictionary = W.get("by_family", {})
		for f in fams:
			for b in (fams[f] as Dictionary).get("biomes", []):
				_by_biome[str(b)] = str(f)
	return str(_by_biome.get(biome_key, W.get("default_family", "river")))


static func family(name: String) -> Dictionary:
	var fams: Dictionary = W.get("by_family", {})
	return fams.get(name, fams.get(str(W.get("default_family", "river")), {}))


## The base colour of a family (the far sea uses the sea family's).
static func base_color(name: String) -> Color:
	return Color(str(family(name).get("base", "#2A58C8")))


## `a` toward `b` by `k`, mixed in linear light (sRGB in and out).
static func _mix(a: Color, b: Color, k: float) -> Color:
	return a.srgb_to_linear().lerp(b.srgb_to_linear(), k).linear_to_srgb()


## A family's day body: the shared base toward the family's own (`calm`:
## the calm navy toward the family's base dimmed to calm's brightness).
static func body_color(name: String, calm: bool) -> Color:
	var fb := Color(str(family(name).get("base", "#2A58C8")))
	var tint := float(W.get("biome_tint", 0.25))
	var base := Color(str(W.get("base", fb.to_html(false))))
	if not calm:
		return _mix(base, fb, tint)
	var c := Color(str(W.get("calm", "#00284C")))
	var dim := c.srgb_to_linear().get_luminance() / maxf(base.srgb_to_linear().get_luminance(), 1e-4)
	var fl := fb.srgb_to_linear()
	return _mix(c, Color(fl.r * dim, fl.g * dim, fl.b * dim).linear_to_srgb(), tint)


## The far sea's albedo (FarShell, lit only): the near sea's day body as
## it reads under the noon sun (glow, and the self-lit share over a lit
## blue of about 0.87), so no band shows where the chunks' water ends.
static func far_sea_color() -> Color:
	var s := float(W.get("self_lit", 0.6))
	var k := float(W.get("glow", 1.35)) * (1.0 - s + s / 0.87)
	var l := body_color("sea", false).srgb_to_linear()
	return Color(minf(l.r * k, 1.0), minf(l.g * k, 1.0), minf(l.b * k, 1.0)).linear_to_srgb()


## The glints' noise: two octaves of tiling value noise (8 and 16 cells
## over 64 px), its values spread evenly over 0-1 by rank so a cover of c
## on the product of two layers lights about 1 - c + c ln c of the water;
## nearest-filtered with mipmaps (the mips average toward 0.5, so far
## water stops glinting instead of shimmering). Also the falls' streaks.
static func glint_texture() -> ImageTexture:
	if _glint:
		return _glint
	const N := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 90127
	var v := PackedFloat32Array()
	v.resize(N * N)
	for oct: Array in [[8, 1.0], [16, 0.5]]:
		var cells: int = oct[0]
		var lat := PackedFloat32Array()
		lat.resize(cells * cells)
		for i in lat.size():
			lat[i] = rng.randf()
		var px := float(N) / cells
		for y in N:
			for x in N:
				var fx := x / px
				var fy := y / px
				var x0 := floori(fx)
				var y0 := floori(fy)
				var x1 := (x0 + 1) % cells
				var y1 := (y0 + 1) % cells
				var tx := smoothstep(0.0, 1.0, fx - x0)
				var ty := smoothstep(0.0, 1.0, fy - y0)
				var a := lerpf(lat[y0 * cells + x0], lat[y0 * cells + x1], tx)
				var b := lerpf(lat[y1 * cells + x0], lat[y1 * cells + x1], tx)
				v[y * N + x] += lerpf(a, b, ty) * float(oct[1])
	var order := range(N * N)
	order.sort_custom(func(i: int, j: int) -> bool: return v[i] < v[j])
	var img := Image.create(N, N, false, Image.FORMAT_L8)
	for r in order.size():
		var i: int = order[r]
		var g := (r + 0.5) / (N * N)
		img.set_pixel(i % N, floori(i / float(N)), Color(g, g, g))
	img.generate_mipmaps()
	_glint = ImageTexture.create_from_image(img)
	return _glint


## The water material for the biome at a chunk's middle.
static func material(biome_key: String, salt: bool) -> ShaderMaterial:
	var fam := "sea" if salt and W.get("by_family", {}).has("sea") else family_of(biome_key)
	var key := fam + ("/salt" if salt else "/fresh")
	if _materials.has(key):
		return _materials[key]
	var row := family(fam)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	var hi := Color(str(row.get("highlight", "#9FD8FF")))
	m.set_shader_parameter("water_color", body_color(fam, false))
	m.set_shader_parameter("calm_color", body_color(fam, true))
	m.set_shader_parameter("calm_share", 0.0 if salt else float(W.get("calm_share", 1.0)))
	m.set_shader_parameter("highlight_color", hi)
	m.set_shader_parameter("glint_color", _mix(Color(str(W.get("glint", "#8EFCFF"))), hi, float(W.get("biome_tint", 0.25))))
	for k in ["self_lit", "body_mottle", "glint_hdr", "glint_cover", "glint_cover_calm", "glint_night"]:
		if W.has(k):
			m.set_shader_parameter(k, float(W[k]))
	m.set_shader_parameter("glint_tex", glint_texture())
	m.set_meta("salt", salt)
	m.set_shader_parameter("glow_day", float(W.get("glow", 1.35)))
	m.set_shader_parameter("glow_night", float((W.get("night", {}) as Dictionary).get("glow", 1.6)))
	m.set_shader_parameter("caustic_tile_m", float(W.get("caustic_tile_m", 1.5)))
	m.set_shader_parameter("caustic_scroll", float(W.get("caustic_scroll_mps", 0.25)))
	Look.register(m)
	_materials[key] = m
	return m


## Every family material made so far (TerrainChunk passes the storm's
## rain on to them).
static func all_materials() -> Array:
	return _materials.values()


## The waterfall sheet's colours and scroll (look.json water.waterfall).
static func set_waterfall(m: ShaderMaterial) -> void:
	var wf: Dictionary = W.get("waterfall", {})
	m.set_shader_parameter("sheet_color", Color(str(wf.get("sheet", "#B8E8FF"))))
	m.set_shader_parameter("shadow_color", Color(str(wf.get("shadow", "#4A8AE0"))))
	m.set_shader_parameter("foam_color", Color(str(wf.get("foam", "#F0FFFF"))))
	m.set_shader_parameter("streak_tile_m", float(wf.get("streak_tile_m", 1.6)))
	m.set_shader_parameter("streak_stretch", float(wf.get("streak_stretch", 7.5)))
	m.set_shader_parameter("streak_scroll", float(wf.get("streak_scroll_mps", 2.5)))
	m.set_shader_parameter("streak_hdr", float(wf.get("streak_hdr", 0.6)))
	m.set_shader_parameter("glow_day", float(W.get("glow", 1.35)))
	m.set_shader_parameter("self_lit", float(W.get("self_lit", 0.6)))
	m.set_shader_parameter("glint_tex", glint_texture())
	m.set_shader_parameter("glow_night", float((W.get("night", {}) as Dictionary).get("glow", 1.6)))


## The mist cards at a fall's foot (look.json water.waterfall.mist).
static func mist() -> Dictionary:
	return (W.get("waterfall", {}) as Dictionary).get("mist", {})

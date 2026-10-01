class_name WaterLook
extends RefCounted
## Water's colours by family (design §BU step 4, Mike: glowier than its
## surroundings but biome-matched; data/look.json `water`): each water
## family (clear, river, lake, swamp, sea, reef, desert, tropics) has a
## base and a highlight colour; a chunk's water takes the family of the
## biome at its middle, anything unmapped the default family. The glow
## (day and night) and the scrolling caustic tile are shared. One
## material per family and salt/fresh, made on first use.

static var W: Dictionary = Tuning.section("look", "water")
static var _by_biome := {}
static var _materials := {}


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


## The water material for the biome at a chunk's middle.
static func material(biome_key: String, salt: bool) -> ShaderMaterial:
	var fam := "sea" if salt and W.get("by_family", {}).has("sea") else family_of(biome_key)
	var key := fam + ("/salt" if salt else "/fresh")
	if _materials.has(key):
		return _materials[key]
	var row := family(fam)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	m.set_shader_parameter("water_color", Color(str(row.get("base", "#2A58C8"))))
	m.set_shader_parameter("highlight_color", Color(str(row.get("highlight", "#9FD8FF"))))
	m.set_shader_parameter("glow_day", float(W.get("glow", 1.35)))
	m.set_shader_parameter("glow_night", float((W.get("night", {}) as Dictionary).get("glow", 1.6)))
	m.set_shader_parameter("caustic_tile_m", float(W.get("caustic_tile_m", 1.5)))
	m.set_shader_parameter("caustic_scroll", float(W.get("caustic_scroll_mps", 0.25)))
	Look.register(m)
	_materials[key] = m
	return m


## The waterfall sheet's colours and scroll (look.json water.waterfall).
static func set_waterfall(m: ShaderMaterial) -> void:
	var wf: Dictionary = W.get("waterfall", {})
	m.set_shader_parameter("sheet_color", Color(str(wf.get("sheet", "#B8E8FF"))))
	m.set_shader_parameter("shadow_color", Color(str(wf.get("shadow", "#4A8AE0"))))
	m.set_shader_parameter("foam_color", Color(str(wf.get("foam", "#F0FFFF"))))
	m.set_shader_parameter("streak_tile_m", float(wf.get("streak_tile_m", 0.6)))
	m.set_shader_parameter("streak_scroll", float(wf.get("streak_scroll_mps", 2.5)))
	m.set_shader_parameter("glow_night", float((W.get("night", {}) as Dictionary).get("glow", 1.6)))

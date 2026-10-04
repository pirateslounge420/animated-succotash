class_name PostGrade
extends CanvasLayer
## Full-screen grade (shaders/post_grade.gdshader): the day and night
## presets from data/look.json, crossfaded by `night`, with look.json
## `grade` (the navy and olive toning, the cyan-white lights, the oranges
## and golds the grade leaves alone; look pass, 1 Oct); color bleed, film
## grain and the ordered dither always, at data/look.json retro's
## `bleed`, `grain`, `dither` and `bits_per_channel` (§AG: a hard 5-bit
## dither, at the 480-line internal frame). Set `night` and `magic` 0-1;
## set_dither(0) turns the dither off.

var _rect: ColorRect


func _ready() -> void:
	layer = -1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/post_grade.gdshader")
	_rect.material = mat
	add_child(_rect)
	var day := Tuning.section("look", "day")
	var night := Tuning.section("look", "night")
	# Each preset key, and its value when the preset leaves it out.
	var keys := {"exposure": 1.0, "mids": 1.0, "saturation": 1.0, "teal": 0.0, "shadow_tint_amount": 0.0, "highlight_amount": 0.0, "olive_amount": 0.0, "contrast": 1.0, "vignette": 0.0}
	for key: String in keys:
		mat.set_shader_parameter(key, Vector2(float(day.get(key, keys[key])), float(night.get(key, keys[key]))))
	for pair in [["day", day], ["night", night]]:
		mat.set_shader_parameter("shadow_color_" + pair[0], _rgb(pair[1].get("shadow_color", "#06186C")))
		mat.set_shader_parameter("highlight_color_" + pair[0], _rgb(pair[1].get("highlight_color", "#D8F8FF")))
	var g := Tuning.section("look", "grade")
	mat.set_shader_parameter("olive_color", _rgb(g.get("olive_color", "#1E300A")))
	mat.set_shader_parameter("olive_greenness", _vec2(g.get("olive_greenness", [0.05, 0.3])))
	mat.set_shader_parameter("shadow_range", _vec2(g.get("shadow_range", [0.02, 0.3])))
	mat.set_shader_parameter("highlight_from", float(g.get("highlight_from", 0.5)))
	mat.set_shader_parameter("protect_hue", _vec2(g.get("protect_hue_deg", [-20.0, 62.0])))
	mat.set_shader_parameter("protect_feather", float(g.get("protect_feather_deg", 10.0)))
	mat.set_shader_parameter("protect_chroma", _vec2(g.get("protect_chroma", [0.12, 0.25])))
	var retro := Tuning.section("look", "retro")
	mat.set_shader_parameter("dither", float(retro.get("dither", 0.25)))
	mat.set_shader_parameter("bleed", float(retro.get("bleed", 0.6)))
	mat.set_shader_parameter("grain", float(retro.get("grain", 0.025)))
	mat.set_shader_parameter("levels", pow(2.0, float(retro.get("bits_per_channel", 5))) - 1.0)
	var fl := Color(str((retro.get("colors", {}) as Dictionary).get("shadow_floor", "#080C4A")))
	mat.set_shader_parameter("shadow_floor", Vector3(fl.r, fl.g, fl.b))


## A look.json hex colour as a display-space (sRGB) vector for the grade.
static func _rgb(hex: Variant) -> Vector3:
	var c := Color(str(hex))
	return Vector3(c.r, c.g, c.b)


static func _vec2(a: Variant) -> Vector2:
	var arr: Array = a if a is Array else [0.0, 1.0]
	return Vector2(float(arr[0]), float(arr[1]))


func set_night(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("night", v)


## The shadow floor for this frame (§BD: the hour's floor colour, black
## where the player stands enclosed) and the night's pull of the darks to
## the floor's hue (§BU).
func set_floor(floor_rgb: Vector3, pull: float, pull_luma: float) -> void:
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("shadow_floor", floor_rgb)
	m.set_shader_parameter("night_pull", pull)
	m.set_shader_parameter("pull_luma", pull_luma)


func set_magic(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("magic", v)


## Hurt (design 4 Oct §EA, Harm): the frame's edges darkened and its
## colour drained toward the dark's navy, 0-1 each.
func set_harm(vignette: float, desaturate: float) -> void:
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("harm_vignette", vignette)
	m.set_shader_parameter("harm_desat", desaturate)


func set_dither(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("dither", v)

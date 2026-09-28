class_name PostGrade
extends CanvasLayer
## Full-screen grade (shaders/post_grade.gdshader): the day and night
## presets from data/look.json, crossfaded by `night`; slight color
## bleed, faint film grain and a light ordered dither always. Set `night`
## and `magic` 0-1; set_dither(0) turns the dither off (default 0.25).

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
	for key in ["exposure", "mids", "saturation", "teal", "shadow_tint_amount", "contrast", "vignette"]:
		mat.set_shader_parameter(key, Vector2(float(day.get(key, 1.0)), float(night.get(key, 1.0))))
	for pair in [["shadow_tint_day", day], ["shadow_tint_night", night]]:
		var t: Array = pair[1].get("shadow_tint", [1.0, 1.0, 1.0])
		mat.set_shader_parameter(pair[0], Vector3(float(t[0]), float(t[1]), float(t[2])))


func set_night(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("night", v)


func set_magic(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("magic", v)


func set_dither(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("dither", v)

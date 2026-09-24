class_name PostGrade
extends CanvasLayer
## Full-screen night grade (shaders/post_grade.gdshader). Set `night` 0-1.

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


func set_night(v: float) -> void:
	(_rect.material as ShaderMaterial).set_shader_parameter("night", v)

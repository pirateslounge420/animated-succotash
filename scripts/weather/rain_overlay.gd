class_name RainOverlay
extends CanvasLayer
## Rain drawn as long straight vertical streaks in the internal frame
## (design §BU, 1 Oct; the one rain, a single full-frame pass, §ER.1): a full-screen canvas under the post grade
## (shaders/rain_streaks.gdshader), fed the local rain and storm each
## weather tick by Main. Dense in a storm, thinned under cover, leaning
## with the wind. Replaces the rain particles (WeatherFX keeps the snow).

var _rect: ColorRect
var _intensity := 0.0
var _target := 0.0


func _ready() -> void:
	layer = -2 # under PostGrade (-1): graded and dithered with the scene
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/rain_streaks.gdshader")
	_rect.material = mat
	_rect.visible = false
	add_child(_rect)


## weather: WeatherSim.local_weather() at the player; wind in m/s;
## sheltered: under a crown or a roof.
func update_rain(weather: Dictionary, sheltered: bool, cam_right: Vector3) -> void:
	var rate := float(weather.get("rain_mm_h", 0.0))
	var storm := float(weather.get("storm", 0.0))
	var cold := bool(weather.get("snow", false))
	_target = 0.0 if cold else clampf(rate / 2.5 + storm * 0.6, 0.0, 1.0)
	var wind: Vector3 = weather.get("wind", Vector3.ZERO)
	var lean := clampf(wind.dot(cam_right) / 25.0, -0.4, 0.4)
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("lean", lean)
	m.set_shader_parameter("sheltered", 1.0 if sheltered else 0.0)
	# The frame's own lines (the pixel-size preset, Display; 480 by
	# default), so a streak is one pixel wide at any.
	m.set_shader_parameter("lines", float(Display.lines()))


func _process(delta: float) -> void:
	_intensity = lerpf(_intensity, _target, clampf(delta * 1.5, 0.0, 1.0))
	_rect.visible = _intensity > 0.02
	(_rect.material as ShaderMaterial).set_shader_parameter("intensity", _intensity)

class_name HarmRing
extends ColorRect
## The red ring round the edge of the view (design 6 Oct §FD, §FJ.3; Harm
## owns it in the crawler, on a canvas layer of its own): hit 1's ring,
## darker and a little deeper on hit 2 (harm.json fd.hit_1_edge and
## hit_2_edge), eased by Harm. Drawn at the internal frame like the rest of
## the HUD (§Y), in stepped bands (shaders/harm_ring.gdshader). It gives
## off no light: it is paint on the frame, never a glow.

## The ring now (tools read these): its colour, alpha at the rim and depth
## as a share of the frame's short side.
var ring_color := Color(0, 0, 0, 0)
var alpha := 0.0
var width_frac := 0.0


func _init() -> void:
	color = Color(1, 1, 1, 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/harm_ring.gdshader")
	material = m
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	(material as ShaderMaterial).set_shader_parameter("frame_px", size)


## Show the ring (`a` the alpha at its rim, `w` its depth as a share of the
## frame's short side); none at 0.
func show_ring(c: Color, a: float, w: float) -> void:
	ring_color = c
	alpha = a
	width_frac = w
	visible = a > 0.002 and w > 0.0005
	if not visible:
		return
	var m := material as ShaderMaterial
	m.set_shader_parameter("ring_color", Color(c, 1.0))
	m.set_shader_parameter("alpha", clampf(a, 0.0, 1.0))
	m.set_shader_parameter("width_frac", w)


## The ring's depth in the frame's pixels now (tools: at 480 lines).
func depth_px() -> float:
	return width_frac * minf(size.x, size.y)

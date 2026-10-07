class_name CrawlerHarmView
extends Control
## Harm on screen in the crawler (design 4 Oct §EA, §EC; data/harm.json),
## the open world's way (StatusHud) without the rest of its HUD: a hit's
## dark navy flash in from the frame's edges, and on the third hit the
## frame closing to black and "Good night" in red. Drawn inside the
## 480-line frame like the rest of the HUD (§Y), wordless otherwise
## (§ET.3). It only reads Harm (its flash, black and text_alpha); the
## stage's darkened edges and drained colour are the grade's (PostGrade,
## Harm sets them).

var _label: Label


func _ready() -> void:
	name = "Harm"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)


## The words showing now ("" none; the checks).
func taken_text() -> String:
	return _label.text if _label.visible else ""


func _process(_delta: float) -> void:
	var h := Harm.instance
	# Shown only while it has something to draw (unhurt, the crosshair is
	# the HUD's one thing, §EX.7).
	visible = h != null and (h.flash > 0.0 or h.black > 0.0 or h.text_alpha > 0.0)
	if not visible:
		return
	var tk: Dictionary = Harm.D.get("taken", {})
	_label.text = str(tk.get("text", "Good night"))
	HudText.size(_label, int(tk.get("text_size_px", 40)))
	_label.add_theme_color_override("font_color", Color(str(tk.get("text_color", "#C81E1E"))))
	_label.modulate.a = h.text_alpha
	_label.visible = h.text_alpha > 0.0
	queue_redraw()


func _draw() -> void:
	var h := Harm.instance
	if h == null:
		return
	var ef: Dictionary = (Harm.D.get("hit_feedback", {}) as Dictionary).get("edge_flash", {})
	var a := h.flash * float(ef.get("alpha", 0.55))
	if a > 0.0:
		# A hit (§EC): dark navy in from the edges, thickest at the rim.
		var col := Color(str(ef.get("color", "#0A1440")))
		var ew := size.x * 0.16
		var eh := size.y * 0.16
		for band in 4:
			var t := float(band) / 4.0
			var c2 := Color(col, a * (1.0 - t))
			var bx := ew * t
			var by := eh * t
			var bw := ew / 4.0
			var bh := eh / 4.0
			draw_rect(Rect2(bx, by, bw, size.y - 2.0 * by), c2)
			draw_rect(Rect2(size.x - bx - bw, by, bw, size.y - 2.0 * by), c2)
			draw_rect(Rect2(bx + bw, by, size.x - 2.0 * (bx + bw), bh), c2)
			draw_rect(Rect2(bx + bw, size.y - by - bh, size.x - 2.0 * (bx + bw), bh), c2)
	if h.black > 0.0:
		# Black, as near as the frame goes: the darkest navy.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.006, 0.02, h.black))

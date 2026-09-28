class_name SettingsPanel
extends Control
## The settings panel (O or F10): a small plain box in the R1a palette
## with the HUD switches (design §L: the speedometer and the clock, both on
## by default). Click a line to switch it; O, F10 or Esc closes. The world
## doesn't pause.

const ITEMS := [["hud.speedometer", "Speedometer"], ["hud.clock", "Clock (watch face)"]]
const PANEL := Color(0.035, 0.055, 0.19, 0.88)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const W := 300.0
const ROW := 26.0

var _rows: Array = [] # [Rect2, key]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


## A click: switch the line under it. True if it hit one.
func click(at: Vector2) -> bool:
	for r in _rows:
		if (r[0] as Rect2).has_point(at):
			Settings.set_bool(r[1], not Settings.get_bool(r[1]))
			queue_redraw()
			return true
	return false


func _draw() -> void:
	_rows.clear()
	var font := ThemeDB.fallback_font
	var h := 44.0 + ROW * ITEMS.size() + 24.0
	var r := Rect2(Vector2(size.x * 0.5 - W * 0.5, size.y * 0.5 - h * 0.5), Vector2(W, h))
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	draw_string(font, r.position + Vector2(16, 26), "Settings", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	for i in ITEMS.size():
		var row := Rect2(r.position + Vector2(12, 40 + ROW * i), Vector2(W - 24, ROW - 4))
		_rows.append([row, ITEMS[i][0]])
		var on := Settings.get_bool(ITEMS[i][0])
		draw_string(font, row.position + Vector2(4, 16), ("[x] " if on else "[ ] ") + str(ITEMS[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT if on else DIM)
	draw_string(font, Vector2(r.position.x + 16, r.end.y - 10), "click to switch · O or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)

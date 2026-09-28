class_name SettingsPanel
extends Control
## The settings panel (O or F10): a small plain box in the R1a palette.
## The HUD switches (design §L: the speedometer and the clock, both on by
## default) and the display (design §Y, Display: internal lines 480 or 720,
## 16:9 or 4:3 letterboxed, integer scaling). Click a line to switch it;
## O, F10 or Esc closes. The world doesn't pause. Sizes at the 480-line
## reference, like all the HUD.

## [key, label, kind]: "bool" switches; "lines" and "aspect" step through
## Display's choices.
const ITEMS := [
	["hud.speedometer", "Speedometer", "bool"],
	["hud.clock", "Clock (watch face)", "bool"],
	["display.lines", "Internal lines", "lines"],
	["display.aspect", "Aspect", "aspect"],
	["display.integer", "Integer scaling", "bool"],
]
const PANEL := Color(0.035, 0.055, 0.19, 0.88)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const W := 200.0
const ROW := 16.0

var _rows: Array = [] # [Rect2, item]


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
			_switch(r[1])
			queue_redraw()
			return true
	return false


func _switch(item: Array) -> void:
	var key: String = item[0]
	match str(item[2]):
		"lines":
			var i := Display.LINE_CHOICES.find(Display.lines())
			Settings.set_value(key, Display.LINE_CHOICES[(i + 1) % Display.LINE_CHOICES.size()])
		"aspect":
			var j := Display.ASPECTS.find(Display.aspect())
			Settings.set_value(key, Display.ASPECTS[(j + 1) % Display.ASPECTS.size()])
		_:
			Settings.set_bool(key, not _on(item))
	if key.begins_with("display."):
		Display.apply()


func _on(item: Array) -> bool:
	if item[0] == "display.integer":
		return Display.integer()
	return Settings.get_bool(item[0])


func _shown(item: Array) -> String:
	match str(item[2]):
		"lines":
			return "%s: %d" % [item[1], Display.lines()]
		"aspect":
			return "%s: %s" % [item[1], Display.aspect()]
	return ("[x] " if _on(item) else "[ ] ") + str(item[1])


func _draw() -> void:
	_rows.clear()
	var font := ThemeDB.fallback_font
	var h := 28.0 + ROW * ITEMS.size() + 16.0
	var r := Rect2(Vector2(size.x * 0.5 - W * 0.5, size.y * 0.5 - h * 0.5), Vector2(W, h))
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	draw_string(font, r.position + Vector2(10, 17), "Settings", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	for i in ITEMS.size():
		var item: Array = ITEMS[i]
		var row := Rect2(r.position + Vector2(8, 26 + ROW * i), Vector2(W - 16, ROW - 2))
		_rows.append([row, item])
		var lit: bool = item[2] != "bool" or _on(item)
		draw_string(font, row.position + Vector2(2, 10), _shown(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TEXT if lit else DIM)
	draw_string(font, Vector2(r.position.x + 10, r.end.y - 6), "click to switch · O or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, DIM)

class_name SettingsPanel
extends Control
## The settings panel (O or F10): a small plain box in the R1a palette.
## The HUD: every element can be switched on or off, so you choose what's
## on your screen (2026-09-29, from play; design §L's speedometer and
## clock among them, all on by default). The display (design §Y, Display:
## internal lines 480 or 720, 16:9 or 4:3 letterboxed, integer scaling) and
## the sun's shadows by day (design §AG 6 A/B, SkySystem.day_shadows()).
## Click a line to switch it; O, F10 or Esc closes. The world doesn't
## pause. Sizes at the 480-line reference, like all the HUD (HudText.px()).

## [key, label, kind]: "bool" switches; "lines" and "aspect" step through
## Display's choices; "chunks" is the render distance (ChunkManager; click
## the left half for fewer, the right half for more); "head" is a section
## title.
const ITEMS := [
	["", "HUD", "head"],
	["hud.speedometer", "Speedometer", "bool"],
	["hud.clock", "Clock (watch face)", "bool"],
	["hud.health", "Health bar", "bool"],
	["hud.weapon", "Weapon in hand", "bool"],
	["hud.reticle", "Crosshair dot", "bool"],
	["hud.names", "Names (plants, animals)", "bool"],
	["hud.damage", "Damage numbers", "bool"],
	["hud.prompts", "Prompts (E: ...)", "bool"],
	["hud.subtitles", "Subtitles", "bool"],
	["", "Display", "head"],
	["display.render_chunks", "Render distance", "chunks"],
	["display.lines", "Internal lines", "lines"],
	["display.aspect", "Aspect", "aspect"],
	["display.integer", "Integer scaling", "bool"],
	["display.day_shadows", "Sun shadows by day", "bool"],
]
const PANEL := Color(0.035, 0.055, 0.19, 0.88)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const W := 300.0
const ROW := 20.0

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
			_switch(r[1], at.x < (r[0] as Rect2).get_center().x)
			queue_redraw()
			return true
	return false


func _switch(item: Array, left := false) -> void:
	var key: String = item[0]
	match str(item[2]):
		"chunks":
			var n := ChunkManager.render_chunks() + (-1 if left else 1)
			Settings.set_value(key, clampi(n, ChunkManager.RENDER_MIN, ChunkManager.RENDER_MAX))
			return
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
	if item[0] == "display.day_shadows":
		return SkySystem.day_shadows()
	return Settings.get_bool(item[0])


func _shown(item: Array) -> String:
	match str(item[2]):
		"lines":
			return "%s: %d" % [item[1], Display.lines()]
		"aspect":
			return "%s: %s" % [item[1], Display.aspect()]
		"chunks":
			var n := ChunkManager.render_chunks()
			return "< %s: %d (%d m) >" % [item[1], n, roundi(ChunkManager.render_reach_m(n) / 10.0) * 10]
	return ("[x] " if _on(item) else "[ ] ") + str(item[1])


func _draw() -> void:
	_rows.clear()
	var font := ThemeDB.fallback_font
	var px := HudText.px(20)
	var h := 30.0 + ROW * ITEMS.size() + 26.0
	var r := Rect2(Vector2(size.x * 0.5 - W * 0.5, size.y * 0.5 - h * 0.5), Vector2(W, h))
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	draw_string(font, r.position + Vector2(10, 22), "Settings", HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT)
	for i in ITEMS.size():
		var item: Array = ITEMS[i]
		var row := Rect2(r.position + Vector2(8, 30 + ROW * i), Vector2(W - 16, ROW - 2))
		if item[2] == "head":
			draw_string(font, row.position + Vector2(2, 15), str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, EDGE)
			draw_line(row.position + Vector2(60, 10), Vector2(row.end.x, row.position.y + 10), Color(EDGE, 0.3), 1.0)
			continue
		_rows.append([row, item])
		var lit: bool = item[2] != "bool" or _on(item)
		draw_string(font, row.position + Vector2(14, 15), _shown(item), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if lit else DIM)
	draw_string(font, Vector2(r.position.x + 10, r.end.y - 8), "click to switch - O or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, px, DIM)

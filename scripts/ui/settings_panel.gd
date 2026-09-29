class_name SettingsPanel
extends Control
## The settings panel (O or F10): a small plain box in the R1a palette.
## The HUD: every element can be switched on or off, so you choose what's
## on your screen (2026-09-29, from play; design §L's speedometer and
## clock among them, all on by default). The display (design §Y, Display:
## internal lines 480 or 720, 16:9 or 4:3 letterboxed, integer scaling) and
## the sun's shadows by day (design §AG 6 A/B, SkySystem.day_shadows()).
## Audio: volume sliders (AudioMix) for everything, the footsteps and the
## climbing (from play: those two were too loud; they start at half).
## Click a line to switch it, or a slider's bar to set it (drag along it;
## click left or right of the bar for 10 % less or more); O, F10 or Esc
## closes. The world doesn't pause. Sizes at the 480-line reference, like
## all the HUD (HudText.px()).

## [key, label, kind]: "bool" switches; "lines" and "aspect" step through
## Display's choices; "chunks" is the render distance (ChunkManager; click
## the left half for fewer, the right half for more); "slider" a volume
## (AudioMix, 0-100 %); "head" is a section title.
const ITEMS := [
	["", "HUD", "head"],
	["hud.speedometer", "Speedometer", "bool"],
	["hud.clock", "Clock (pocket watch)", "bool"],
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
	["", "Audio", "head"],
	["audio.master", "Volume", "slider"],
	["audio.footsteps", "Footsteps", "slider"],
	["audio.climbing", "Climbing", "slider"],
]
const PANEL := Color(0.035, 0.055, 0.19, 0.88)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const W := 300.0
const ROW := 20.0
## A slider's bar: where it starts in its row and how wide it is (px).
const BAR_X := 118.0
const BAR_W := 120.0

var _rows: Array = [] # [Rect2, item]
## The slider being dragged (its item), while the button is held.
var _dragging: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


## A click: switch the line under it (or set the slider). True if it hit
## one.
func click(at: Vector2) -> bool:
	_dragging = []
	for r in _rows:
		var row: Rect2 = r[0]
		if row.has_point(at):
			if str(r[1][2]) == "slider":
				_slide(r[1], row, at.x, true)
			else:
				_switch(r[1], at.x < row.get_center().x)
			queue_redraw()
			return true
	return false


## The mouse moved with the button held: a slider picked up by the click
## follows it.
func drag(at: Vector2) -> void:
	if _dragging.is_empty() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = []
		return
	for r in _rows:
		if r[1] == _dragging:
			_slide(r[1], r[0], at.x, false)
			queue_redraw()


## Set slider `item` from a click (or a drag) at `x`: on the bar, the level
## there (in 5 % steps; picks the slider up to drag); left or right of it,
## 10 % less or more.
func _slide(item: Array, row: Rect2, x: float, clicked: bool) -> void:
	var key: String = item[0]
	var x0 := row.position.x + BAR_X
	var pct := AudioMix.percent(key)
	if x >= x0 - 3.0 and x <= x0 + BAR_W + 3.0 or not clicked:
		pct = roundi(clampf((x - x0) / BAR_W, 0.0, 1.0) * 20.0) * 5
		_dragging = item
	elif x < x0:
		pct -= 10
	else:
		pct += 10
	AudioMix.set_percent(key, pct)


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
		if item[2] == "slider":
			_draw_slider(font, px, row, item)
			continue
		var lit: bool = item[2] != "bool" or _on(item)
		draw_string(font, row.position + Vector2(14, 15), _shown(item), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if lit else DIM)
	draw_string(font, Vector2(r.position.x + 10, r.end.y - 8), "click to set - O or Esc closes", HORIZONTAL_ALIGNMENT_LEFT, -1, px, DIM)


## A volume slider: its name, a bar filled to its level, the level.
func _draw_slider(font: Font, px: int, row: Rect2, item: Array) -> void:
	var pct := AudioMix.percent(str(item[0]))
	draw_string(font, row.position + Vector2(14, 15), str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if pct > 0 else DIM)
	var bar := Rect2(row.position + Vector2(BAR_X, 6), Vector2(BAR_W, 6))
	draw_rect(bar, Color(DIM, 0.25))
	draw_rect(Rect2(bar.position, Vector2(roundf(BAR_W * pct / 100.0), bar.size.y)), Color(EDGE, 0.85))
	draw_rect(bar, Color(EDGE, 0.55), false, 1.0)
	draw_string(font, row.position + Vector2(BAR_X + BAR_W + 8, 15), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if pct > 0 else DIM)

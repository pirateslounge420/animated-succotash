class_name BootMenu
extends Control
## The crawler's first screen when a game is kept (design 7 Oct §FK.2,
## crawler.json persistence.continue; queue 63; the boot scene shows it):
## two plain lines on the dark, in the settings panel's box, palette and
## font, no art. Continue opens the last game where you left it (the line
## under it says which tomb, and how many of its lights burn); New game
## rolls a new seed and a new world, and asks once more first, as
## Settings' New game does. Click a line, or Up and Down (W and S) and
## then Enter, Space or E; Esc is Continue. `picked` says which.

signal picked(which: String)

## [id, label].
const LINES := [["continue", "Continue"], ["new", "New game"]]
## New game picked once (the next pick starts it).
const ARMED_TEXT := "Start a new game? This world is put away. (again)"
const ROW := 26.0
const MIN_W := 300.0

## The line under the pointer or the keys (an index into LINES).
var at := 0
## New game picked once: the next pick of it starts it.
var armed := false
## The kept game, in a line (CrawlerSave.summary).
var note := ""
var _rows: Array = [] # [Rect2, id]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## Pick line `id`: Continue at once; New game on its second pick (the
## first arms it). True when `picked` went out.
func pick(id: String) -> bool:
	if id == "new" and not armed:
		armed = true
		at = _index("new")
		queue_redraw()
		return false
	picked.emit(id)
	return true


## What line `i` says now.
func text_of(i: int) -> String:
	if str(LINES[i][0]) == "new" and armed:
		return ARMED_TEXT
	return str(LINES[i][1])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for r in _rows:
			if (r[0] as Rect2).has_point(event.position):
				var i := _index(str(r[1]))
				if i != at:
					at = i
					queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for r in _rows:
			if (r[0] as Rect2).has_point(event.position):
				at = _index(str(r[1]))
				pick(str(r[1]))
				accept_event()
				return


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if event.is_action_pressed("ui_up") or key == KEY_W:
		at = posmod(at - 1, LINES.size())
	elif event.is_action_pressed("ui_down") or key == KEY_S:
		at = posmod(at + 1, LINES.size())
	elif event.is_action_pressed("ui_accept") or key == KEY_E:
		pick(str(LINES[at][0]))
	elif event.is_action_pressed("ui_cancel"):
		pick("continue")
	else:
		return
	queue_redraw()
	get_viewport().set_input_as_handled()


func _index(id: String) -> int:
	for i in LINES.size():
		if str(LINES[i][0]) == id:
			return i
	return 0


func _draw() -> void:
	_rows.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.01))
	var font := ThemeDB.fallback_font
	var px := HudText.px(20)
	# Wide enough for its longest line.
	var w := MIN_W
	for i in LINES.size():
		w = maxf(w, font.get_string_size("> " + text_of(i), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 44.0)
	if note != "":
		w = maxf(w, font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 60.0)
	w = minf(w, maxf(size.x - 16.0, MIN_W))
	var h := 20.0 + ROW * (LINES.size() + (1 if note != "" else 0))
	var box := Rect2((size * 0.5 - Vector2(w, h) * 0.5).round(), Vector2(w, h))
	draw_rect(box, SettingsPanel.PANEL)
	draw_rect(box, Color(SettingsPanel.EDGE, 0.55), false, 1.0)
	var y := box.position.y + 10.0
	for i in LINES.size():
		var id := str(LINES[i][0])
		var row := Rect2(Vector2(box.position.x + 8.0, y), Vector2(w - 16.0, ROW - 2.0))
		_rows.append([row, id])
		draw_string(font, row.position + Vector2(14, 18), ("> " if i == at else "  ") + text_of(i), HORIZONTAL_ALIGNMENT_LEFT, -1, px, SettingsPanel.TEXT if i == at else SettingsPanel.DIM)
		y += ROW
		if id == "continue" and note != "":
			draw_string(font, Vector2(row.position.x + 36.0, y + 16.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, px, SettingsPanel.DIM)
			y += ROW

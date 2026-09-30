class_name LogPanel
extends Control
## The log (design 30 Sept §AZ, hud.json "log"): Enter opens it, a
## Minecraft-chat panel low on the left of the 480-line frame, newest line
## at the bottom, every line stamped in game time from the clock. What
## goes in (GameLog): deaths with their cause, the torch lit / guttering /
## out, a fire lit / embers / out, the hearth set, a camp found, a biome
## first entered, dawn and dusk, and your own notes: type in the box at
## the bottom and Enter keeps it (note_max_chars). Esc (or Enter on an
## empty box) closes. Scroll with the wheel or Page Up / Page Down. No
## other chat, no commands. The world goes on while it's open; the keys
## are the box's. Persists per world (GameLog, WorldSave).

const PANEL := Color(0.035, 0.055, 0.19, 0.84)
const EDGE := Color("#C8D8F0")
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const STAMP := Color(0.78, 0.7, 0.5)
const NOTE := Color(0.85, 0.92, 0.75)
const DEATH := Color(1.0, 0.62, 0.5)
const W := 520.0
const PAD := 8.0

static var D: Dictionary = Tuning.section("hud", "log")

## Lines scrolled up from the newest.
var _scroll := 0
var _note := ""
var _blink := 0.0
var _px := 20
var _line_h := 22.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_px = HudText.px(float(D.get("font_px", 20)))
	_line_h = _px * 1.1


func open() -> void:
	visible = true
	_scroll = 0
	_note = ""
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_blink += delta
		queue_redraw()


## The keys are the box's while it's open: text into the note, Enter
## keeps it (or closes on an empty box), Esc closes, the wheel and Page
## Up / Down scroll.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				close()
			KEY_ENTER, KEY_KP_ENTER:
				if _note.strip_edges() == "":
					close()
				else:
					GameLog.add(_note.strip_edges(), "note")
					_note = ""
					_scroll = 0
			KEY_BACKSPACE:
				_note = _note.left(_note.length() - 1)
			KEY_PAGEUP:
				_scroll = mini(_scroll + int(D.get("lines_visible", 8)), maxi(GameLog.entries.size() - 1, 0))
			KEY_PAGEDOWN:
				_scroll = maxi(_scroll - int(D.get("lines_visible", 8)), 0)
			_:
				if k.unicode >= 32 and _note.length() < int(D.get("note_max_chars", 120)):
					_note += char(k.unicode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = mini(_scroll + 1, maxi(GameLog.entries.size() - 1, 0))
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = maxi(_scroll - 1, 0)
			get_viewport().set_input_as_handled()


## "Day 3 · 03:40" -> ["Day 3", "03:40"].
static func _split_stamp(t: String) -> Array:
	var parts := t.split(" · ")
	return [parts[0], parts[1]] if parts.size() >= 2 else ["", t]


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var n := int(D.get("lines_visible", 8))
	var h := PAD * 2.0 + _line_h * (n + 1) + 6.0
	var r := Rect2(Vector2(PAD, size.y - h - 40.0), Vector2(minf(W, size.x - PAD * 2.0), h))
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	# The lines, newest at the bottom, a dim day line where the day
	# changes.
	var entries := GameLog.entries
	var rows: Array = []
	var last_day := ""
	for e in entries:
		var st := _split_stamp(str(e.get("t", "")))
		if st[0] != last_day and st[0] != "":
			rows.append([str(st[0]), "", "day"])
			last_day = st[0]
		rows.append([str(st[1]), str(e.get("text", "")), str(e.get("kind", ""))])
	var last := rows.size() - 1 - _scroll
	var y := r.position.y + PAD + _line_h * n - 6.0
	for i in n:
		var idx := last - i
		if idx < 0:
			break
		var row: Array = rows[idx]
		var kind := str(row[2])
		if kind == "day":
			draw_string(font, Vector2(r.position.x + PAD, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _px, DIM)
		else:
			var col := TEXT
			if kind == "note":
				col = NOTE
			elif kind == "death_cause":
				col = DEATH
			draw_string(font, Vector2(r.position.x + PAD, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _px, STAMP)
			draw_string(font, Vector2(r.position.x + PAD + _px * 3.2, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x - PAD * 2.0 - _px * 3.2), _px, col)
		y -= _line_h
	# The note box.
	var box := Rect2(Vector2(r.position.x + PAD * 0.5, r.end.y - PAD - _line_h), Vector2(r.size.x - PAD, _line_h))
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(box, Color(EDGE, 0.35), false, 1.0)
	var caret := "_" if fmod(_blink, 1.0) < 0.55 else " "
	var shown := (_note if _note != "" else "") + caret
	draw_string(font, box.position + Vector2(6, _line_h - 6.0), shown, HORIZONTAL_ALIGNMENT_LEFT, int(box.size.x - 12), _px, TEXT if _note != "" else DIM)
	if _note == "":
		draw_string(font, box.position + Vector2(18, _line_h - 6.0), "write a note · Enter keeps it · Esc closes", HORIZONTAL_ALIGNMENT_LEFT, int(box.size.x - 24), _px, Color(DIM, 0.6))

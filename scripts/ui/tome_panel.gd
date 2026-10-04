class_name TomePanel
extends Control
## Reading a tome (design 3 Oct §DL, Tomes): R with a tome carried opens
## it, a panel built like the log's (in the internal frame, the HUD's font
## and colours): its title page, then one page at a time (one hexagram a
## page for the I Ching). Left / right (or A / D) turn the page, Esc or R
## closes. Nothing else on screen changes and the clock keeps running
## (§CW).

const W := 560.0
const PAD := 12.0

var tome_id := ""
## 0 the title page, 1.. the pages.
var page := 0
var _book := {}
var _px := 20
var _line_h := 22.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_px = HudText.px(float(LogPanel.D.get("font_px", 20)))
	_line_h = _px * 1.1


## Open tome `id` at its title page. False if its text isn't in.
func open(id: String) -> bool:
	_book = Tomes.book(id)
	if _book.is_empty():
		return false
	tome_id = id
	page = 0
	visible = true
	queue_redraw()
	return true


func close() -> void:
	visible = false


func page_count() -> int:
	return (_book.get("pages", []) as Array).size()


## Turn by `by` pages, never past the title page or the last.
func turn(by: int) -> void:
	page = clampi(page + by, 0, page_count())
	queue_redraw()


## What the panel shows now: [heading, body].
func shown() -> Array:
	if page == 0:
		return [str(_book.get("title", "")), "%d pages" % page_count()]
	var p: Dictionary = _book.pages[page - 1]
	return [str(p.heading), str(p.text)]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE, KEY_R:
				close()
			KEY_LEFT, KEY_A:
				turn(-1)
			KEY_RIGHT, KEY_D:
				turn(1)
			_:
				return
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := minf(W, size.x - PAD * 2.0)
	var s := shown()
	var body := LogPanel.wrap_text(str(s[1]), font, _px, w - PAD * 2.0)
	var n := int(clampf(body.size(), 6, 16))
	var h := PAD * 2.0 + _line_h * (n + 3)
	var r := Rect2(Vector2((size.x - w) * 0.5, maxf(PAD, (size.y - h) * 0.5)), Vector2(w, h))
	draw_rect(r, LogPanel.PANEL)
	draw_rect(r, Color(LogPanel.EDGE, 0.55), false, 1.0)
	var y := r.position.y + PAD + _line_h
	draw_string(font, Vector2(r.position.x + PAD, y), str(s[0]), HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, LogPanel.STAMP)
	y += _line_h * 1.5
	for i in mini(body.size(), 16):
		draw_string(font, Vector2(r.position.x + PAD, y), body[i], HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, LogPanel.TEXT)
		y += _line_h
	var foot := "%s · %d / %d · ← → turn · Esc closes" % [str(_book.get("title", "")), page, page_count()]
	draw_string(font, Vector2(r.position.x + PAD, r.end.y - PAD), foot, HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, LogPanel.DIM)

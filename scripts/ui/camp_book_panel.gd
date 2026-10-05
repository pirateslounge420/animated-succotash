class_name CampBookPanel
extends Control
## Reading a camp book (design 4 Oct §ED.3, CampBook): right click at the
## altar by a camp's hearth opens it, in the internal frame and the HUD's
## font like the log, but on the book's own yellowed page: the folk's
## lines, each stamped in game time, the newest ink dark and the older
## browned, PAGE_LINES a page, opened at the newest page. A rumour, when
## there is one, is the last line, and opening the book copies it into
## your log (once per ruin). Left / right (A / D) turn the page; Esc or a
## right click closes. The clock keeps running.

const W := 560.0
const PAD := 14.0

var camp_key := ""
var page := 0
var _lines: Array = []
var _title := "The camp book"
var _px := 20
var _line_h := 22.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_px = HudText.px(float(LogPanel.D.get("font_px", 20)))
	_line_h = _px * 1.15


## Open the book of camp `key` (CampSim state `st`) at its newest page.
func open(world, key: String, st: Dictionary) -> void:
	camp_key = key
	_lines = CampBook.lines_of(world, st)
	var people := Peoples.get_people(str(st.get("people", "")))
	var pname := str(people.get("name", ""))
	_title = "The camp book" + (" of the %s" % pname if pname != "" else "")
	page = maxi(page_count() - 1, 0)
	visible = true
	# The rumour goes into your log (copy_to_log), once per ruin.
	if bool((CampBook.D.get("rumour", {}) as Dictionary).get("copy_to_log", true)):
		for l in _lines:
			if bool(l.get("rumour", false)):
				GameLog.add_once(str(l.get("key", "rumour")), str(l.text), "rumour")
	queue_redraw()


func close() -> void:
	visible = false


func page_count() -> int:
	return maxi(1, int(ceil(float(_lines.size()) / CampBook.PAGE_LINES)))


func turn(by: int) -> void:
	page = clampi(page + by, 0, page_count() - 1)
	queue_redraw()


## The lines on the page shown now.
func shown() -> Array:
	return _lines.slice(page * CampBook.PAGE_LINES, (page + 1) * CampBook.PAGE_LINES)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				close()
			KEY_LEFT, KEY_A:
				turn(-1)
			KEY_RIGHT, KEY_D:
				turn(1)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := minf(W, size.x - PAD * 2.0)
	var h := PAD * 2.0 + _line_h * (CampBook.PAGE_LINES * 2 + 3)
	h = minf(h, size.y - PAD * 2.0)
	var r := Rect2(Vector2((size.x - w) * 0.5, maxf(PAD, (size.y - h) * 0.5)), Vector2(w, h))
	draw_rect(r, CampBook.PAGE)
	draw_rect(r, CampBook.INK_OLD, false, 2.0)
	var y := r.position.y + PAD + _line_h
	draw_string(font, Vector2(r.position.x + PAD, y), _title, HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, CampBook.INK_OLD.darkened(0.2))
	y += _line_h * 1.4
	var stamp_w := _px * 5.4
	if _lines.is_empty():
		draw_string(font, Vector2(r.position.x + PAD, y), "Nothing written yet.", HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, CampBook.INK_OLD)
	for l in shown():
		var col: Color = l.get("ink", CampBook.INK_FRESH)
		var rows := LogPanel.wrap_text(str(l.text), font, _px, w - PAD * 2.0 - stamp_w)
		draw_string(font, Vector2(r.position.x + PAD, y), str(l.get("stamp", "")), HORIZONTAL_ALIGNMENT_LEFT, int(stamp_w), int(_px * 0.85), col.lerp(CampBook.PAGE, 0.35))
		for row in rows:
			if y > r.end.y - _line_h * 1.5:
				break
			draw_string(font, Vector2(r.position.x + PAD + stamp_w, y), row, HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0 - stamp_w), _px, col)
			y += _line_h
	var foot := "%d / %d · ← → turn · Esc closes" % [page + 1, page_count()]
	draw_string(font, Vector2(r.position.x + PAD, r.end.y - PAD), foot, HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, CampBook.INK_OLD)

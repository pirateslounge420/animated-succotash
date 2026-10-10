class_name TomePanel
extends Control
## Reading a tome (design 3 Oct §DL, Tomes): R with a tome carried opens
## it, a panel built like the log's (in the internal frame, the HUD's font
## and colours): its title page, then one page at a time (one hexagram a
## page for the I Ching). Left / right (or A / D) turn the page, Esc or R
## closes. Nothing else on screen changes and the clock keeps running
## (§CW).
##
## Collected pages (design 9 Oct §FM.5, queue 73; Torchfire 1's crawler, R
## with pages held, TomePages): open_held opens a split tome on the pages
## you hold of it, its title page saying how much ("pages 1 to 5 of 12",
## Tomes.held_line), then only those pages, in the book's order (the page
## number in the foot). A tome whose text isn't in opens at its title page
## only. With pages of more than one book, up / down (or W / S) go to the
## next. Two levels, the title page and the pages; nothing above them.

const W := 560.0
const PAD := 12.0

var tome_id := ""
## 0 the title page, 1.. the pages.
var page := 0
var _book := {}
var _px := 20
var _line_h := 22.0
## Open on the pages you hold of a split tome (open_held), not a whole one:
## the fragments in hand, the book's page numbers they hold (with its text
## in; none without), its title page's line, and the books you hold pages
## of (up / down).
var held_mode := false
var held_ids: Array = []
var held_pages: Array = []
var held_line := ""
var held_books: Array = []
var _title := ""


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
	held_mode = false
	_title = str(_book.get("title", ""))
	page = 0
	visible = true
	queue_redraw()
	return true


## Open split tome `id` on the pages the fragments `fragment_ids` hold of
## it (design §FM.5, queue 73), at its title page: its title (the text's,
## else the data's) and how much you hold; then only the pages you hold,
## once its text is in (without it, the title page only). False for a tome
## found whole, or with none of its pages held but `even_none`.
func open_held(id: String, fragment_ids: Array, even_none := false) -> bool:
	if not Tomes.split(id) or (not even_none and not _holds_any(id, fragment_ids)):
		return false
	_book = Tomes.book(id)
	tome_id = id
	held_mode = true
	held_ids = fragment_ids.duplicate()
	held_pages = Tomes.pages_held(id, fragment_ids) if not _book.is_empty() else []
	held_line = Tomes.held_line(id, fragment_ids)
	held_books = books_held(fragment_ids)
	_title = str(_book.get("title", Tomes.entry(id).get("title", "")))
	page = 0
	visible = true
	queue_redraw()
	return true


## Do the fragments `fragment_ids` hold any of split tome `id`'s (its text
## in or not)?
static func _holds_any(id: String, fragment_ids: Array) -> bool:
	for f in Tomes.fragments_of(id):
		if fragment_ids.has(str(f.id)):
			return true
	return false


## The split tomes `fragment_ids` hold pages of, in tomes.json's order.
static func books_held(fragment_ids: Array) -> Array:
	var out: Array = []
	for t in Tomes.entries():
		var id := str(t.get("id", ""))
		if Tomes.split(id) and _holds_any(id, fragment_ids):
			out.append(id)
	return out


## The next (`by` 1) or previous (-1) book you hold pages of, at its title
## page (open_held).
func next_book(by: int) -> void:
	if not held_mode or held_books.size() < 2:
		return
	var i := held_books.find(tome_id)
	open_held(str(held_books[posmod(i + by, held_books.size())]), held_ids)


func close() -> void:
	visible = false


func page_count() -> int:
	if held_mode:
		return held_pages.size()
	return (_book.get("pages", []) as Array).size()


## Turn by `by` pages, never past the title page or the last.
func turn(by: int) -> void:
	page = clampi(page + by, 0, page_count())
	queue_redraw()


## The book's page number shown now (0 the title page).
func book_page() -> int:
	if page == 0:
		return 0
	return int(held_pages[page - 1]) if held_mode else page


## What the panel shows now: [heading, body].
func shown() -> Array:
	if page == 0:
		return [_title, held_line if held_mode else "%d pages" % page_count()]
	var p: Dictionary = _book.pages[book_page() - 1]
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
			KEY_UP, KEY_W:
				# The pages of another book you hold (open_held).
				if not held_mode:
					return
				next_book(-1)
			KEY_DOWN, KEY_S:
				if not held_mode:
					return
				next_book(1)
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
	draw_string(font, Vector2(r.position.x + PAD, r.end.y - PAD), foot(), HORIZONTAL_ALIGNMENT_LEFT, int(w - PAD * 2.0), _px, LogPanel.DIM)


## The panel's foot line: a whole tome's "title · 3 / 64"; the pages you
## hold of a split one by the book's own page number ("title · page 17 of
## 64", the title page "title · title page"), and up / down when you hold
## pages of more than one book.
func foot() -> String:
	if not held_mode:
		return "%s · %d / %d · ← → turn · Esc closes" % [str(_book.get("title", "")), page, page_count()]
	var at := "title page" if page == 0 else "page %d of %d" % [book_page(), Tomes.total_pages(tome_id)]
	return "%s · %s · %sEsc closes" % [_title, at, ("← → turn · " if page_count() > 0 else "") + ("↑ ↓ book · " if held_books.size() > 1 else "")]

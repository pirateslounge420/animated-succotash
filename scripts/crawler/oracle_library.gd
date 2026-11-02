class_name OracleLibrary
extends CanvasLayer
## The oracle's library (design §GO.11, queue 125; data/library.json): the
## realms' sacred texts, a collection to read, not a puzzle. The oracles
## give them (RealmFolk); they are kept in the save
## (CrawlerSave.data.library, game-wide, never lost).
##
##   reading   at the hub the read-tome key opens your library: a simple
##             page view (left and right turn pages and texts, Esc closes)
##   the cast  seated on a log by the hub fire (FirePipe) holding the
##             I Ching, the read-tome key sets out three coins: interact
##             tosses them, six times, bottom line first (heads 3, tails 2:
##             6 old yin and 9 old yang change); then the hexagram, its
##             changing lines and the changed hexagram, with their
##             readings (placeholders until Mike fills in his translation).
##             Reflection only: nothing in the world changes.
##
## Every text's content is data; no religious figure is depicted unless the
## data says so, and the Quran's keeper is never a depiction of Muhammad
## (§GO.11.5).

static var D: Dictionary = Tuning.table("library")

var main: CrawlerMain
var _panel: PanelContainer
var _label: RichTextLabel
var mode := ""
var _text := 0
var _page := 0
## The cast in hand: the line values tossed so far (6..9), bottom first.
var lines: Array = []
var coins: Array = []
var rng := RandomNumberGenerator.new()


func setup(p_main: CrawlerMain) -> void:
	name = "Library"
	main = p_main
	layer = 7
	rng.randomize()
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 360)
	_panel.position = Vector2(-260, -180)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.12, 0.94)
	sb.border_color = Color(0.75, 0.68, 0.5)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.add_theme_color_override("default_color", Color(0.92, 0.88, 0.78))
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false


static func texts() -> Dictionary:
	return D.get("texts", {})


static func title(id: String) -> String:
	return str((texts().get(id, {}) as Dictionary).get("title", id))


## The texts you hold, in the order you were given them.
static func held() -> Array:
	return ((CrawlerSave.data.get("library", []) as Array)).duplicate()


static func has(id: String) -> bool:
	return held().has(id)


## Text `id` into your library (True if new).
static func give(id: String) -> bool:
	if id == "" or not texts().has(id) or has(id):
		return false
	var l: Array = CrawlerSave.data.get("library", [])
	l.append(id)
	CrawlerSave.data["library"] = l
	CrawlerSave.save()
	return true


# --- The I Ching (§GO.11.2) ----------------------------------------------------------------

static func iching() -> Dictionary:
	return D.get("iching", {})


## One toss of three coins: [the coins (3 heads, 2 tails), the line 6..9].
static func toss(r: RandomNumberGenerator) -> Array:
	var c: Array = []
	var sum := 0
	for i in 3:
		var v := 3 if r.randi_range(0, 1) == 1 else 2
		c.append(v)
		sum += v
	return [c, sum]


## Yang (1) or yin (0) of line value `v`, before (or, `changed`, after)
## its change.
static func yang(v: int, changed := false) -> int:
	match v:
		6:
			return 1 if changed else 0
		9:
			return 0 if changed else 1
		7:
			return 1
	return 0


## The King Wen number of six lines (bottom first, 1 yang).
static func number(bits: Array) -> int:
	var I := iching()
	var order: Array = I.get("trigram_order", [])
	var tg: Dictionary = I.get("trigrams", {})
	var lo := -1
	var up := -1
	var b := bits.map(func(x): return int(x))
	for i in order.size():
		var t: Array = (tg.get(str(order[i]), []) as Array).map(func(x): return int(x))
		if t == b.slice(0, 3):
			lo = i
		if t == b.slice(3, 6):
			up = i
	if lo < 0 or up < 0:
		return 0
	return int(((I.get("king_wen", []) as Array)[up] as Array)[lo])


static func hexagram(n: int) -> Dictionary:
	return ((iching().get("hexagrams", {}) as Dictionary).get(str(n), {}) as Dictionary)


## A whole cast of six line values (bottom first): {"n", "changing" (the
## lines' places, 1-6), "to" (the changed hexagram, 0 if none change)}.
static func read_cast(vals: Array) -> Dictionary:
	var a: Array = []
	var b: Array = []
	var ch: Array = []
	for i in vals.size():
		a.append(yang(int(vals[i])))
		b.append(yang(int(vals[i]), true))
		if int(vals[i]) in [6, 9]:
			ch.append(i + 1)
	return {"n": number(a), "changing": ch, "to": number(b) if not ch.is_empty() else 0}


# --- The panels ---------------------------------------------------------------------------------

## The read-tome key (CrawlerMain): on a log with the I Ching, the cast;
## at the hub, the library. True if it opened something.
func open_key() -> bool:
	if _panel.visible:
		close()
		return true
	if main.fire_pipe != null and main.fire_pipe.seated and has("i_ching"):
		open_cast()
		return true
	if main.on_surface and main.surface is HubCamp and not held().is_empty():
		open_read()
		return true
	return false


func open_read() -> void:
	mode = "read"
	_text = clampi(_text, 0, maxi(held().size() - 1, 0))
	_page = 0
	_panel.visible = true
	_draw()


func open_cast() -> void:
	mode = "cast"
	lines = []
	coins = []
	_panel.visible = true
	GameLog.add(str(iching().get("log_open", "You set three coins on the log beside you.")), "world")
	_draw()


func close() -> void:
	mode = ""
	_panel.visible = false


## A toss in the cast (interact while it is open: CrawlerAreas.interact
## asks here first). True if taken.
func cast_once() -> bool:
	if mode != "cast":
		return false
	if lines.size() >= 6:
		lines = []
		coins = []
	var t := toss(rng)
	coins = t[0]
	lines.append(int(t[1]))
	if lines.size() == 6:
		var r := read_cast(lines)
		GameLog.add(str(iching().get("log_cast", "Hexagram {n}, {name}.")).format({"n": r.n, "name": str(hexagram(int(r.n)).get("name", ""))}), "world")
		if int(r.to) > 0:
			GameLog.add(str(iching().get("log_changed", "Changing to hexagram {n}, {name}.")).format({"n": r.to, "name": str(hexagram(int(r.to)).get("name", ""))}), "world")
	_draw()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif mode == "read" and (event.is_action_pressed("move_right") or event.is_action_pressed("move_left")):
		turn(1 if event.is_action_pressed("move_right") else -1)
		get_viewport().set_input_as_handled()


## Turn a page (past the last, on to the next text).
func turn(dir: int) -> void:
	var h := held()
	if h.is_empty():
		return
	var pages: Array = (texts().get(str(h[_text]), {}) as Dictionary).get("pages", [])
	_page += dir
	if _page >= maxi(pages.size(), 1):
		_text = (_text + 1) % h.size()
		_page = 0
	elif _page < 0:
		_text = posmod(_text - 1, h.size())
		_page = maxi(((texts().get(str(h[_text]), {}) as Dictionary).get("pages", []) as Array).size() - 1, 0)
	_draw()


static func _line_art(v: int) -> String:
	match v:
		6:
			return "━━━  ✕  ━━━"
		7:
			return "━━━━━━━━━━━"
		8:
			return "━━━━   ━━━━"
		9:
			return "━━━━━◯━━━━━"
	return ""


func _draw() -> void:
	var s := ""
	if mode == "read":
		var h := held()
		var id := str(h[_text]) if not h.is_empty() else ""
		var T: Dictionary = texts().get(id, {})
		var pages: Array = T.get("pages", [])
		s = "[center][b]%s[/b]\n[i]%s · %s[/i][/center]\n\n" % [str(T.get("title", id)), str(T.get("keeper", "")), str(T.get("source", ""))]
		s += str(pages[_page]) if _page < pages.size() else "(no pages yet)"
		s += "\n\n[center][color=#8a8070]%d / %d   ·   ← →  turn   ·   Esc  close[/color][/center]" % [_page + 1, maxi(pages.size(), 1)]
	elif mode == "cast":
		s = "[center][b]I Ching[/b]\n[color=#8a8070]interact: toss three coins (%d of 6)   ·   Esc: close[/color][/center]\n\n" % lines.size()
		if not coins.is_empty():
			s += "[center]%s[/center]\n\n" % "   ".join(coins.map(func(c): return "heads" if int(c) == 3 else "tails"))
		for i in range(lines.size() - 1, -1, -1):
			s += "[center]%s   %d[/center]\n" % [_line_art(int(lines[i])), int(lines[i])]
		if lines.size() == 6:
			var r := read_cast(lines)
			var hx := hexagram(int(r.n))
			s += "\n[center][b]%d  %s[/b][/center]\n%s\n" % [int(r.n), str(hx.get("name", "")), str(hx.get("reading", ""))]
			if int(r.to) > 0:
				var hx2 := hexagram(int(r.to))
				s += "[center]changing lines %s → [b]%d  %s[/b][/center]\n%s" % [", ".join(r.changing.map(func(x): return str(x))), int(r.to), str(hx2.get("name", "")), str(hx2.get("reading", ""))]
	_label.text = s

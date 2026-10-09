class_name SettingsPanel
extends Control
## The settings panel (O or F10): a small plain box in the R1a palette.
## The HUD: every element can be switched on or off, so you choose what's
## on your screen (2026-09-29, from play; design §L's speedometer and
## clock among them, all on by default). The display (design §Y, Display:
## the pixel size, painted 270, chunky 360, default 480, half_hd 540 or
## fine 720 lines, the most, or auto; 16:9 or 4:3 letterboxed; integer
## scaling) and
## the sun's shadows by day (design §AG 6 A/B, SkySystem.day_shadows()).
## Audio: volume sliders (AudioMix) for everything, the footsteps and the
## climbing (from play: those two were too loud; they start at half).
## Click a line to switch it, or a slider's bar to set it (drag along it;
## click left or right of the bar for 10 % less or more); O, F10 or Esc
## closes. The world doesn't pause. Sizes at the 480-line reference, like
## all the HUD (HudText.px()).
##
## Two tabs at the top: these settings, and Controls (design 6 Oct §FB,
## ControlsPage): every action's keys and buttons, rebound by clicking one
## and pressing the new input, with the wheel's hand and a reset.

## [key, label, kind]: "bool" switches; "preset" and "aspect" step through
## Display's choices; "render" is the render distance in metres
## (ChunkManager.RENDER_STEPS_M, design §ER.1; click
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
	["hud.prompts", "Prompts (Right click: ...)", "bool"],
	["hud.subtitles", "Subtitles", "bool"],
	["", "World", "head"],
	["world.new", "New world", "action"],
	["", "Display", "head"],
	["display.render_m", "Render distance", "render"],
	["display.preset", "Pixel size", "preset"],
	["display.aspect", "Aspect", "aspect"],
	["display.integer", "Integer scaling", "bool"],
	["display.day_shadows", "Shadows: near hard cast (off: blobs only)", "bool"],
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
## A line's height: 19 so the whole panel (474 px) fits the 480-line frame.
const ROW := 19.0
## A slider's bar: where it starts in its row and how wide it is (px).
const BAR_X := 118.0
const BAR_W := 120.0

var _rows: Array = [] # [Rect2, item]
## The slider being dragged (its item), while the button is held.
var _dragging: Array = []
## An "action" line clicked once, waiting for its second click.
var _armed := ""
## The page shown: "settings" (ITEMS) or "controls" (ControlsPage, §FB).
var page := "settings"
var controls := ControlsPage.new()
## The tabs: [page, its name].
const TABS := [["settings", "Settings"], ["controls", "Controls"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_armed = ""
	controls.cancel()


## While an action on the Controls page waits for its new input, the next
## key or button pressed is its, before anything else hears it (Esc lets
## it go and leaves the panel open).
func _input(event: InputEvent) -> void:
	if not visible or page != "controls" or controls.waiting == "":
		return
	if controls.capture(event):
		get_viewport().set_input_as_handled()
		queue_redraw()


## The panel's box for the page shown, in the middle of the frame.
func panel_rect() -> Rect2:
	var sz := ControlsPage.size() if page == "controls" else Vector2(W, 30.0 + ROW * ITEMS.size() + 26.0)
	return Rect2((size * 0.5 - sz * 0.5).round(), sz)


## The tabs' boxes in panel `r`: [[Rect2, page], ...].
func tab_rects(r: Rect2) -> Array:
	var out: Array = []
	for i in TABS.size():
		out.append([Rect2(r.position + Vector2(6.0 + 84.0 * i, 4.0), Vector2(80.0, 24.0)), TABS[i][0]])
	return out


## A click: switch the line under it (or set the slider). True if it hit
## one.
func click(at: Vector2) -> bool:
	_dragging = []
	var pr := panel_rect()
	for t in tab_rects(pr):
		if (t[0] as Rect2).has_point(at):
			if page != str(t[1]):
				page = str(t[1])
				_armed = ""
				controls.cancel()
			queue_redraw()
			return true
	if page == "controls":
		var hit := controls.click(at, pr)
		queue_redraw()
		return hit
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
	if page != "settings" or _dragging.is_empty() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
	if str(item[2]) == "action":
		# Asked once (design 1 Oct §CB): the first click arms the line,
		# the second does it.
		if _armed == key:
			_armed = ""
			var scene := get_tree().current_scene
			if key == "world.new" and scene != null and scene.has_method("start_new_world"):
				scene.call("start_new_world")
		else:
			_armed = key
		return
	_armed = ""
	match str(item[2]):
		"render":
			Settings.set_value(key, ChunkManager.step_render_m(left))
			return
		"preset":
			Display.cycle_preset(left)
			return
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
		"action":
			# In the crawler a world is a game (design 7 Oct §FK.2,
			# CrawlerSave): New game rolls a new seed and a new world, and
			# Continue opens the new one from then on.
			var game: bool = item[0] == "world.new" and GameMode.crawler_running
			if _armed == item[0]:
				return "Start a new game? This world is put away. (click again)" if game else "Start a new world? This one stays saved. (click again)"
			return "> %s" % ("New game" if game else item[1])
		"preset":
			return "< %s: %s >" % [item[1], Display.preset_label()]
		"aspect":
			return "%s: %s" % [item[1], Display.aspect()]
		"render":
			return "< %s: %d m >" % [item[1], roundi(ChunkManager.render_m())]
	return ("[x] " if _on(item) else "[ ] ") + str(item[1])


func _draw() -> void:
	_rows.clear()
	var font := ThemeDB.fallback_font
	var px := HudText.px(20)
	var r := panel_rect()
	draw_rect(r, PANEL)
	draw_rect(r, Color(EDGE, 0.55), false, 1.0)
	# The tabs: the page shown bright and underlined, the other dim.
	for t in tab_rects(r):
		var tr: Rect2 = t[0]
		var on := str(t[1]) == page
		var name := "Settings" if str(t[1]) == "settings" else "Controls"
		draw_string(font, tr.position + Vector2(4, 18), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if on else DIM)
		if on:
			draw_line(tr.position + Vector2(4, 22), tr.position + Vector2(4 + font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, 22), Color(EDGE, 0.8), 1.0)
	if page == "controls":
		controls.draw(self, font, px, r)
		return
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
	draw_string(font, Vector2(r.position.x + 10, r.end.y - 8), "click to set - %s or %s closes" % [Controls.first_name("settings", "O"), Controls.first_name("release_mouse", "Esc")], HORIZONTAL_ALIGNMENT_LEFT, -1, px, DIM)


## A volume slider: its name, a bar filled to its level, the level.
func _draw_slider(font: Font, px: int, row: Rect2, item: Array) -> void:
	var pct := AudioMix.percent(str(item[0]))
	draw_string(font, row.position + Vector2(14, 15), str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if pct > 0 else DIM)
	var bar := Rect2(row.position + Vector2(BAR_X, 6), Vector2(BAR_W, 6))
	draw_rect(bar, Color(DIM, 0.25))
	draw_rect(Rect2(bar.position, Vector2(roundf(BAR_W * pct / 100.0), bar.size.y)), Color(EDGE, 0.85))
	draw_rect(bar, Color(EDGE, 0.55), false, 1.0)
	draw_string(font, row.position + Vector2(BAR_X + BAR_W + 8, 15), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT if pct > 0 else DIM)

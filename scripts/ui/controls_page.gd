class_name ControlsPage
extends RefCounted
## Settings' Controls page (design 6 Oct §FB; SettingsPanel's second tab):
## every action in Controls with its keys and mouse buttons, the wheel
## among them, in two columns: the actions both games use and the
## crawler's two hands on the left, the open world's own keys and the dev
## keys on the right. Click an action, then press its new key or button
## (Esc cancels): it takes that one input in place of its keys and
## buttons (a pad's stay), saved for this player (Controls.bind,
## user://controls.cfg) and in force at once and at every start. "Wheel
## drives" gives the plain wheel to the right hand or the left
## (Controls.wheel_drives). "Reset to defaults", asked once (click it
## again), puts everything back. An input two actions share in one game
## (pressing it does both) is drawn amber on both (Controls.clashes).
## Sizes at the 480-line reference, like the rest of the panel.

## [kind, what]: "head" a title; "bind" an action; "wheel" the
## wheel_drives switch; "reset" everything back to the defaults.
const COLUMNS := [
	[
		["head", "Moving"],
		["bind", "move_forward"],
		["bind", "move_back"],
		["bind", "move_left"],
		["bind", "move_right"],
		["bind", "jump"],
		["bind", "crouch"],
		["bind", "sprint"],
		["head", "Hands"],
		["bind", "shoot"],
		["bind", "interact"],
		["bind", "hand_next"],
		["bind", "hand_prev"],
		["bind", "other_hand"],
		["wheel", ""],
		["bind", "douse"],
		["head", "Screens"],
		["bind", "log"],
		# Both games' since queue 73 (§FM.5: the crawler's pages you hold).
		["bind", "read_tome"],
		["bind", "settings"],
		["bind", "release_mouse"],
	],
	[
		["head", "Open world only"],
		["bind", "inventory"],
		["bind", "inventory_drop"],
		["bind", "toggle_map"],
		["bind", "toggle_view"],
		["bind", "weapon_swap"],
		["bind", "toggle_hud"],
		["bind", "toggle_debug"],
		["head", "Dev keys"],
		["bind", "dev_perf"],
		["bind", "dev_pixel"],
		["bind", "dev_items"],
		["bind", "toggle_collision_view"],
		["bind", "toggle_branch_view"],
		["bind", "dev_spawn"],
		["bind", "dev_howl"],
		["bind", "dev_new_world"],
		["reset", ""],
	],
]
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.62, 0.68, 0.82)
const EDGE := Color("#C8D8F0")
## An input two actions share in one game.
const CLASH := Color(1.0, 0.72, 0.4)
## The panel (px at 480 lines; it fits a 4:3 frame's 640): its width,
## the tabs' strip at the top, a row, the foot line; a column's width and
## where its inputs start (VT323 is 8 px a letter at 20 px: the longest
## name, "Swing (right hand)", and the longest inputs, "Enter, Num Enter",
## fit).
const W := 616.0
const TOP := 30.0
const ROW := 20.0
const FOOT := 24.0
const COL_W := 296.0
const KEYS_X := 166.0

## The action waiting for its new input ("" none), and the reset line
## clicked once, waiting for its second click.
var waiting := ""
var armed := false


static func rows_per_column() -> int:
	var n := 0
	for col in COLUMNS:
		n = maxi(n, (col as Array).size())
	return n


static func size() -> Vector2:
	return Vector2(W, TOP + ROW * rows_per_column() + FOOT)


## Every line of the page in panel `r`: [[Rect2, entry], ...].
func rows_in(r: Rect2) -> Array:
	var out: Array = []
	for c in COLUMNS.size():
		var col: Array = COLUMNS[c]
		for i in col.size():
			var at := r.position + Vector2(8.0 + c * (COL_W + 8.0), TOP + ROW * i)
			out.append([Rect2(at, Vector2(COL_W, ROW - 2.0)), col[i]])
	return out


## Every action on the page (the checks: each once).
static func actions() -> Array:
	var out: Array = []
	for col in COLUMNS:
		for e in col:
			if str(e[0]) == "bind":
				out.append(str(e[1]))
	return out


## A click at `at` in panel `r`: wait for an action's new input, switch
## the wheel's hand, or reset (on the second click). True if it hit a line.
func click(at: Vector2, r: Rect2) -> bool:
	for row in rows_in(r):
		if not (row[0] as Rect2).has_point(at):
			continue
		var e: Array = row[1]
		match str(e[0]):
			"bind":
				waiting = str(e[1])
				armed = false
			"wheel":
				waiting = ""
				armed = false
				var opts: Array = Tuning.table("hands").get("wheel_drives_options", ["right", "left"])
				Controls.set_wheel_drives(str(opts[(opts.find(Controls.wheel_drives()) + 1) % opts.size()]))
			"reset":
				waiting = ""
				if armed:
					armed = false
					Controls.reset()
				else:
					armed = true
			_:
				return false
		return true
	return false


## While an action waits: the next key or mouse button pressed is its new
## input (Esc lets it go unchanged). True if the event was taken (nothing
## else should hear it); a pad's input and the mouse's motion pass by.
func capture(event: InputEvent) -> bool:
	if waiting == "":
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.physical_keycode == KEY_ESCAPE or (k.physical_keycode == KEY_NONE and k.keycode == KEY_ESCAPE):
				waiting = ""
			else:
				Controls.bind(waiting, k)
				waiting = ""
		return true
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			Controls.bind(waiting, event)
			waiting = ""
		return true
	return false


func cancel() -> void:
	waiting = ""
	armed = false


func draw(ci: CanvasItem, font: Font, px: int, r: Rect2) -> void:
	var clash_any := false
	for row in rows_in(r):
		var rect: Rect2 = row[0]
		var e: Array = row[1]
		var base := rect.position + Vector2(0.0, 15.0)
		match str(e[0]):
			"head":
				ci.draw_string(font, base + Vector2(2.0, 0.0), str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, EDGE)
				var x0 := rect.position.x + 10.0 + font.get_string_size(str(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				ci.draw_line(Vector2(x0, rect.position.y + 10.0), Vector2(rect.end.x, rect.position.y + 10.0), Color(EDGE, 0.3), 1.0)
			"bind":
				var action := str(e[1])
				ci.draw_string(font, base + Vector2(14.0, 0.0), str(Controls.NAMES.get(action, action)), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT)
				var cell := Rect2(rect.position + Vector2(KEYS_X - 4.0, 0.0), Vector2(rect.size.x - KEYS_X + 4.0, rect.size.y))
				var keys := Controls.label(action)
				var col := TEXT if keys != "—" else DIM
				if waiting == action:
					keys = "press now"
					col = EDGE
					ci.draw_rect(cell, Color(EDGE, 0.12))
					ci.draw_rect(cell, Color(EDGE, 0.7), false, 1.0)
				elif not Controls.clashes(action).is_empty():
					col = CLASH
					clash_any = true
				ci.draw_string(font, base + Vector2(KEYS_X, 0.0), _fit(font, px, keys, cell.size.x - 6.0), HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
			"wheel":
				ci.draw_string(font, base + Vector2(14.0, 0.0), "< Wheel drives: %s hand >" % Controls.wheel_drives(), HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT)
			"reset":
				ci.draw_string(font, base + Vector2(14.0, 0.0), "Reset all? (click again)" if armed else "> Reset to defaults", HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT)
	var foot := "amber: one key on two actions; click one to change it" if clash_any else "click one, then press its new key or button - Esc cancels"
	ci.draw_string(font, Vector2(r.position.x + 10.0, r.end.y - 8.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, px, CLASH if clash_any else DIM)


## `s` cut to fit `w` px ("Enter, Num En.." ).
static func _fit(font: Font, px: int, s: String, w: float) -> String:
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= w:
		return s
	var t := s
	while t.length() > 1 and font.get_string_size(t + "..", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w:
		t = t.left(t.length() - 1)
	return t + ".."

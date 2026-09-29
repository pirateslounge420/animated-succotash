class_name Readouts
extends Control
## The two always-on HUD readouts (design §L; numbers and colors in
## data/hud.json): the speedometer and the watch-face clock. They're HUD
## parts (Hud): pinned by default, each switched in the settings panel
## (Settings "hud.speedometer", "hud.clock", their pins); the Hud says
## each frame which show and how (share, mark). Small and quiet; they sit
## in their corners (hud.json layout) at the 720-line reference size and
## grow with the window like all the HUD (project stretch: scale = height
## / 720).
##
## Speedometer: your speed in mph and km/h (m/s too in dev mode), dim
## below dim_below_mps and brightening toward bright_at_mps (the momentum
## ceiling, 120 km/h), so it only asserts itself when you're fast. Its
## glow warms from glow_cold to glow_warm as the super meter fills.
##
## Clock: a classic 12-hour clock face (design §AQ, from play: "more like a
## classic 12-hour clock"; it was a pilot's watch with a 24-hour ring and
## dawn and dusk marks). A round face with a rim, twelve hour marks (the
## quarters bolder), pixel numerals at 12, 3, 6 and 9 drawn on the frame's
## own pixel grid (the HUD font can't go that small and stay crisp), a
## short broad hour hand that goes round twice a day, a long thin minute
## hand once a game hour (6 real minutes), and a cap on the pin.

static var HUD := {}

var speed_mps := 0.0
var meter := 0.0
## Local clock, hours 0-24 (the hands read it on a 12-hour face).
var clock_h := 0.0
var dev := false
## The bottom of the HUD's top-right text (the place readout), so a
## readout in that corner sits just below it instead of under it.
var top_right_below := 0.0
## Set by the Hud each frame (its pins, H's full HUD, pinning with the
## mouse): each dial's share of its own alpha (0: not drawn) and the alpha
## of the pin mark before it (0: none).
var share := {"speedometer": 1.0, "clock": 1.0}
var mark := {"speedometer": 0.0, "clock": 0.0}
## Pinning (Hud): the speedometer at its bright_alpha even at rest, so you
## can see what you're pinning.
var pinning := false
var _shown := 0.0


func _ready() -> void:
	HUD = Tuning.table("hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Per frame from Hud.
func feed(p_speed: float, p_meter: float, p_clock_h: float, p_dev: bool, delta: float) -> void:
	speed_mps = p_speed
	meter = p_meter
	clock_h = p_clock_h
	dev = p_dev
	var sm := float(_sec("speedometer").get("smoothing_s", 0.15))
	_shown = lerpf(_shown, speed_mps, clampf(delta / maxf(sm, 0.01), 0.0, 1.0))
	queue_redraw()


func _sec(name: String) -> Dictionary:
	var s = HUD.get(name, {})
	return s if s is Dictionary else {}


## Where a readout of size `sz` sits for its layout corner.
func _corner(which: String, sz: Vector2) -> Vector2:
	var layout := _sec("layout")
	var m := float(layout.get("margin_px", 14))
	match str(layout.get(which, "top_right")):
		"top_left":
			return Vector2(m, m)
		"bottom_left":
			return Vector2(m, size.y - m - sz.y)
		"bottom_right":
			return Vector2(size.x - m - sz.x, size.y - m - sz.y)
	return Vector2(size.x - m - sz.x, maxf(m, top_right_below + m * 0.5))


func _draw() -> void:
	if float(share.get("speedometer", 0.0)) > 0.0:
		_draw_speed(float(share.speedometer), float(mark.get("speedometer", 0.0)))
	if float(share.get("clock", 0.0)) > 0.0:
		_draw_clock(float(share.clock), float(mark.get("clock", 0.0)))


## Where the speedometer is drawn now (screen px, the internal frame), or
## an empty rect when it isn't: the Hud's click target for its pin. While
## pinning it takes in the pin mark's cell before it.
func speedometer_rect() -> Rect2:
	if float(share.get("speedometer", 0.0)) <= 0.0 or not is_visible_in_tree():
		return Rect2()
	return get_global_transform_with_canvas() * _with_mark(_speed_box())


## Where the clock is drawn now (as speedometer_rect()).
func clock_rect() -> Rect2:
	if float(share.get("clock", 0.0)) <= 0.0 or not is_visible_in_tree():
		return Rect2()
	return get_global_transform_with_canvas() * _with_mark(_clock_box())


func _speed_px() -> int:
	return HudText.px(float(_sec("speedometer").get("size_px", 13)))


func _speed_lines() -> Array[String]:
	var s := _sec("speedometer")
	var v := _shown
	var r := maxf(float(s.get("mph_round", 1)), 1.0)
	var lines: Array[String] = ["%d mph" % int(round(v * 2.23694 / r) * r), "%d km/h" % int(round(v * 3.6))]
	if dev and bool(s.get("dev_shows_mps", true)):
		lines.append("%.1f m/s" % v)
	return lines


## The speedometer's lines' box in its corner (local px).
func _speed_box() -> Rect2:
	var font := ThemeDB.fallback_font
	var px := _speed_px()
	var lines := _speed_lines()
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var box := Vector2(w, px * 1.35 * lines.size())
	return Rect2(_corner("speedometer", box), box)


## The clock face's box in its corner (local px).
func _clock_box() -> Rect2:
	var d := float(_sec("clock").get("size_px", 44))
	return Rect2(_corner("clock", Vector2(d, d)), Vector2(d, d))


## A dial's box with, while pinning, the pin mark's cell before it.
func _with_mark(box: Rect2) -> Rect2:
	return box.grow_side(SIDE_LEFT, _mark_w()) if pinning else box


## The pin mark's size: the Hud's body text.
func _mark_px() -> int:
	return HudText.px(float(_sec("text").get("base_px", 20)))


## The width of "• " (the mark and its space).
func _mark_w() -> float:
	return ThemeDB.fallback_font.get_string_size("• ", HORIZONTAL_ALIGNMENT_LEFT, -1, _mark_px()).x


## The pin mark ("•", hud.json pins.mark_color) before a dial while
## pinning (Hud), at `alpha` (0: none): its middle at `mid_y`, a space
## short of `left`.
func _draw_mark(left: float, mid_y: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var px := _mark_px()
	# VT323's bullet stands 0.16-0.32 em above the baseline.
	var at := Vector2(left - _mark_w(), mid_y + px * 0.24)
	var col := Color(str(_sec("pins").get("mark_color", "#FFD23A")))
	draw_string_outline(font, at, "•", HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(0.05, 0.07, 0.15, alpha))
	draw_string(font, at, "•", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, alpha))


## `k`: the Hud's share of its alpha; `mk`: its pin mark's alpha.
func _draw_speed(k: float, mk: float) -> void:
	var s := _sec("speedometer")
	var font := ThemeDB.fallback_font
	var px := _speed_px()
	var v := _shown
	var lines := _speed_lines()
	var line_h := px * 1.35
	var box := _speed_box()
	# Dim when slow, brighter toward the ceiling; while pinning, bright
	# (you're choosing it, not reading it).
	var a := float(s.get("bright_alpha", 0.9))
	if not pinning:
		a = lerpf(float(s.get("dim_alpha", 0.22)), a, smoothstep(float(s.get("dim_below_mps", 6.0)), float(s.get("bright_at_mps", 33.3)), v))
	a *= k
	var glow := Color(str(s.get("glow_cold", "#4C7CFF"))).lerp(Color(str(s.get("glow_warm", "#FFD23A"))), clampf(meter, 0.0, 1.0))
	var first_x := box.end.x
	for i in lines.size():
		var p := box.position + Vector2(box.size.x - font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, line_h * (i + 1) - px * 0.3)
		if i == 0:
			first_x = p.x
		draw_string_outline(font, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, Color(glow, a * 0.6))
		draw_string(font, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.93, 0.95, 1.0, a))
	# The mark before the first line, like a bullet.
	_draw_mark(first_x, box.position.y + line_h * 0.5, mk)


## Pixel numerals for the clock face, 3 x 5 cells ("#" lit): the frame is
## 480 lines, and at a 44 px face the HUD font's smallest crisp size (20 px)
## wouldn't fit, so the four quarter numerals are drawn cell by cell.
const DIGITS := {
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", ".##", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}


## `k`: the Hud's share of its alpha; `mk`: its pin mark's alpha.
func _draw_clock(k: float, mk: float) -> void:
	var c := _sec("clock")
	var box := _clock_box()
	var d := box.size.x
	var a0 := float(c.get("alpha", 0.6))
	var a := a0 * k
	# On the pixel grid, so the rim and the numerals stay crisp.
	var mid := (box.position + box.size * 0.5).round()
	var r := floorf(d * 0.5)
	var ring := Color(Color(str(c.get("ring_color", "#4C7CFF"))), minf(a0 + 0.15, 1.0) * k)
	var hand := Color(Color(str(c.get("hand_color", "#7FB0FF"))), minf(a0 + 0.35, 1.0) * k)
	var numeral := Color(Color(str(c.get("numeral_color", c.get("hand_color", "#7FB0FF")))), minf(a0 + 0.3, 1.0) * k)
	_draw_mark(box.position.x, mid.y, mk)
	# The face and its rim.
	draw_circle(mid, r, Color(Color(str(c.get("face_color", "#0A1250"))), a * 0.85))
	draw_arc(mid, r - 0.5, 0.0, TAU, 64, ring, maxf(1.5, d / 24.0))
	# The hour marks: a tick at each hour; at 12, 3, 6 and 9 a numeral
	# (or, with numerals off, a longer, bolder tick).
	var numerals := str(c.get("numerals", "quarters")) == "quarters"
	var cell := maxf(1.0, floorf(d / 40.0))
	for h in 12:
		var ang := _angle12(float(h))
		var dir := Vector2(sin(ang), -cos(ang))
		if h % 3 == 0:
			if numerals:
				_draw_numeral("12" if h == 0 else str(h), mid + dir * r * 0.66, cell, numeral)
			else:
				draw_line(mid + dir * r * 0.68, mid + dir * r * 0.9, ring, maxf(2.0, d / 18.0))
		else:
			draw_line(mid + dir * r * 0.78, mid + dir * r * 0.9, ring, 1.0)
	if bool(c.get("minute_marks", false)):
		for m in 60:
			if m % 5 != 0:
				var ma := TAU * m / 60.0
				draw_rect(Rect2((mid + Vector2(sin(ma), -cos(ma)) * r * 0.86).floor(), Vector2.ONE), Color(ring, ring.a * 0.6))
	# The hands: a short broad hour hand (twice round a day) and a long thin
	# minute hand (once a game hour), each with a little tail past the pin.
	# (Never thinner than a pixel at the tip: unsmoothed, a tapered sliver
	# would drop out and the hand read short.)
	var ha := _angle12(clock_h)
	_draw_hand(mid, ha, r * 0.55, r * 0.14, maxf(3.0, d / 13.0), maxf(1.6, d / 26.0), hand)
	var ma := TAU * fposmod(clock_h, 1.0)
	var mdir := Vector2(sin(ma), -cos(ma))
	var mw := 1.0 if d < 60.0 else 2.0
	draw_line(mid - mdir * r * 0.18, mid + mdir * r * 0.84, hand, mw)
	draw_circle(mid, maxf(1.5, d / 22.0), hand)


## One hand: a tapered bar from `tail` behind the pin (`w_base` wide) to
## `length` out (`w_tip` wide).
func _draw_hand(mid: Vector2, ang: float, length: float, tail: float, w_base: float, w_tip: float, col: Color) -> void:
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var back := mid - dir * tail
	var tip := mid + dir * length
	draw_colored_polygon(PackedVector2Array([back + side * w_base * 0.5, tip + side * w_tip * 0.5,
		tip - side * w_tip * 0.5, back - side * w_base * 0.5]), col)


## A numeral (DIGITS) centred at `at`, each lit cell `cell` px square.
func _draw_numeral(text: String, at: Vector2, cell: float, col: Color) -> void:
	var w := (text.length() * 4 - 1) * cell
	var origin := (at - Vector2(w, 5.0 * cell) * 0.5).round()
	for i in text.length():
		var rows: Array = DIGITS.get(text[i], [])
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(origin + Vector2((i * 4 + x) * cell, y * cell), Vector2(cell, cell)), col)


## The angle (radians, clockwise from 12 o'clock) of hour `h` on a
## 12-hour dial.
static func _angle12(h: float) -> float:
	return TAU * fposmod(h, 12.0) / 12.0

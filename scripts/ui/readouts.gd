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
## Clock: an old railway pocket watch (design §AQ, from play: "more like an
## OG pocket watch face", after the designer's own watch): a polished steel
## case with its crown at 12, a white enamel dial, a minute track round the
## edge (a tick a minute, a square every five), bold black numerals 1-12,
## the 24-hour numerals 13-24 small and red inside them, black skeleton
## hands (the hour hand twice round a day, the minute hand once a game
## hour: 6 real minutes) and a thin red seconds hand (once a game minute:
## 6 real seconds) on a red cap. No dawn or dusk marks. Every figure is
## drawn cell by cell on the 480-line frame's own pixel grid (the HUD font
## can't go that small and stay crisp). hud.json clock switches the parts.

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


## The clock's box in its corner (local px): the watch case, and its
## crown above it.
func _clock_box() -> Rect2:
	var c := _sec("clock")
	var d := float(c.get("size_px", 80))
	var h := d + (_crown_h(d) if bool(c.get("case", true)) else 0.0)
	return Rect2(_corner("clock", Vector2(d, h)), Vector2(d, h))


## How far the crown and its pendant stand above the case (px).
static func _crown_h(d: float) -> float:
	return maxf(5.0, roundf(d * 0.09))


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


## Pixel figures for the dial, "#" lit, the 1s narrower as a watch dial
## sets them: DIGITS_BOLD (5 x 7, two-cell strokes: the black railway
## numerals) and DIGITS_SMALL (3 x 5: the red 24-hour ones).
const DIGITS_BOLD := {
	"0": [".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###."],
	"1": [".##", "###", ".##", ".##", ".##", ".##", ".##"],
	"2": [".###.", "##.##", "...##", "..##.", ".##..", "##...", "#####"],
	"3": ["####.", "...##", "...##", ".###.", "...##", "...##", "####."],
	"4": ["...##", "..###", ".#.##", "##.##", "#####", "...##", "...##"],
	"5": ["#####", "##...", "####.", "...##", "...##", "##.##", ".###."],
	"6": [".###.", "##...", "##...", "####.", "##.##", "##.##", ".###."],
	"7": ["#####", "...##", "..##.", "..##.", ".##..", ".##..", ".##.."],
	"8": [".###.", "##.##", "##.##", ".###.", "##.##", "##.##", ".###."],
	"9": [".###.", "##.##", "##.##", ".####", "...##", "...##", ".###."],
}
const DIGITS_SMALL := {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#", "##", ".#", ".#", ".#"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}


## `k`: the Hud's share of its alpha; `mk`: its pin mark's alpha.
func _draw_clock(k: float, mk: float) -> void:
	var c := _sec("clock")
	var box := _clock_box()
	var d := float(c.get("size_px", 80))
	var a := float(c.get("alpha", 0.95)) * k
	var with_case := bool(c.get("case", true))
	var top := _crown_h(d) if with_case else 0.0
	# On the pixel grid, so the case and the figures stay crisp.
	var mid := (box.position + Vector2(d * 0.5, top + d * 0.5)).round()
	var r_case := floorf(d * 0.5)
	var rim := maxf(2.0, roundf(d / 26.0)) if with_case else 0.0
	var rd := r_case - rim
	var tone := func(key: String, fallback: String, alpha := 1.0) -> Color:
		return Color(Color(str(c.get(key, fallback))), a * alpha)
	var ink: Color = tone.call("numeral_color", "#141414")
	var red: Color = tone.call("accent_color", "#C8281E")
	var dial: Color = tone.call("dial_color", "#E9E6DE")
	_draw_mark(box.position.x, mid.y, mk)
	if with_case:
		_draw_case(mid, r_case, rim, top, tone)
	draw_circle(mid, rd, dial)
	# The minute track round the edge: a tick a minute, a square every five.
	if bool(c.get("minute_track", true)):
		var track: Color = tone.call("track_color", "#2A2A2A", 0.85)
		for m in 60:
			var ma := TAU * m / 60.0
			var dir := Vector2(sin(ma), -cos(ma))
			if m % 5 == 0:
				draw_rect(Rect2((mid + dir * (rd - 2.5) - Vector2.ONE).round(), Vector2(2, 2)), ink)
			else:
				draw_rect(Rect2((mid + dir * (rd - 1.8)).floor(), Vector2.ONE), track)
	# The hours: bold black 1-12 (all, the quarters, or none), and inside
	# them the 24-hour numerals in red.
	var which := str(c.get("numerals", "all"))
	for h in 12:
		var ang := _angle12(float(h))
		var dir := Vector2(sin(ang), -cos(ang))
		var hour := 12 if h == 0 else h
		if which == "all" or (which == "quarters" and h % 3 == 0):
			_draw_figures(str(hour), mid + dir * rd * 0.7, DIGITS_BOLD, ink)
		elif which == "none" or which == "quarters":
			draw_line(mid + dir * rd * 0.7, mid + dir * rd * 0.84, ink, 2.0 if h % 3 == 0 else 1.0)
		if bool(c.get("hours_24", true)):
			_draw_figures(str(hour + 12), mid + dir * rd * 0.44, DIGITS_SMALL, red)
	# The hands: black skeleton hands (a pale line down the middle of each),
	# the hour hand short and broad, the minute hand long; a thin red seconds
	# hand with its counterweight; a black hub under a red cap.
	var hand: Color = tone.call("hand_color", "#141414")
	_draw_hand(mid, _angle12(clock_h), rd * 0.52, rd * 0.12, maxf(3.0, roundf(d / 20.0)), 2.0, hand, dial)
	_draw_hand(mid, TAU * fposmod(clock_h, 1.0), rd * 0.8, rd * 0.12, 3.0, 1.6, hand, dial)
	draw_circle(mid, maxf(2.0, d / 28.0), hand)
	if bool(c.get("seconds_hand", true)):
		var sa := TAU * fposmod(clock_h * 60.0, 1.0)
		var sdir := Vector2(sin(sa), -cos(sa))
		draw_line(mid - sdir * rd * 0.24, mid + sdir * rd * 0.88, red, 1.0)
		draw_circle(mid - sdir * rd * 0.2, 1.2, red)
	draw_circle(mid, maxf(1.2, d / 40.0), red)


## The case: a polished steel ring (dark edge, bright body, a highlight up
## on the left and shade down on the right, the way the light sits on a
## domed case) and the pendant and knurled crown at 12.
func _draw_case(mid: Vector2, r: float, rim: float, top: float, tone: Callable) -> void:
	var steel: Color = tone.call("case_color", "#C5CAD0")
	var dark: Color = tone.call("case_dark", "#5B6068")
	var light: Color = tone.call("case_light", "#F4F6F8")
	# The pendant (a short neck) and the crown on it, above the case.
	var neck_w := maxf(3.0, roundf(r * 0.14))
	var neck_h := maxf(2.0, roundf(top * 0.4))
	var crown_w := maxf(6.0, roundf(r * 0.28))
	var crown_h := top - neck_h
	var neck := Rect2(Vector2(mid.x - floorf(neck_w * 0.5), mid.y - r - neck_h + 1.0), Vector2(neck_w, neck_h))
	draw_rect(neck.grow(1.0), dark)
	draw_rect(neck, steel)
	var crown := Rect2(Vector2(mid.x - floorf(crown_w * 0.5), neck.position.y - crown_h), Vector2(crown_w, crown_h))
	draw_rect(crown.grow(1.0), dark)
	draw_rect(crown, steel)
	# Knurling: the crown's ridges.
	var x := crown.position.x + 1.0
	while x < crown.end.x - 0.5:
		draw_rect(Rect2(Vector2(x, crown.position.y), Vector2(1, crown_h)), Color(dark, dark.a * 0.8))
		x += 2.0
	draw_rect(Rect2(crown.position, Vector2(crown_w, 1)), light)
	# The ring.
	draw_circle(mid, r, dark)
	draw_circle(mid, r - 1.0, steel)
	var band := maxf(rim - 1.5, 1.0)
	draw_arc(mid, r - 1.0 - band * 0.5, deg_to_rad(195.0), deg_to_rad(285.0), 16, light, 1.0)
	draw_arc(mid, r - 1.0 - band * 0.5, deg_to_rad(15.0), deg_to_rad(105.0), 16, Color(dark, dark.a * 0.7), 1.0)
	# The bezel's inner edge, where the crystal meets the dial.
	draw_circle(mid, r - rim + 0.5, Color(dark, dark.a * 0.9))


## One skeleton hand: a black tapered bar from `tail` behind the pin
## (`w_base` wide) to `length` out (`w_tip` wide; never under a pixel, or
## the unsmoothed tip drops out and the hand reads short), with a line of
## `inner` down its middle when it's broad enough to show one.
func _draw_hand(mid: Vector2, ang: float, length: float, tail: float, w_base: float, w_tip: float, col: Color, inner: Color) -> void:
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var back := mid - dir * tail
	var tip := mid + dir * length
	draw_colored_polygon(PackedVector2Array([back + side * w_base * 0.5, tip + side * w_tip * 0.5,
		tip - side * w_tip * 0.5, back - side * w_base * 0.5]), col)
	if w_base >= 3.0:
		draw_line(mid + dir * length * 0.3, mid + dir * length * 0.82, inner, 1.0)


## Figures (`font`: DIGITS_BOLD or DIGITS_SMALL) centred at `at`, one px a
## cell, a px between figures.
func _draw_figures(text: String, at: Vector2, font: Dictionary, col: Color) -> void:
	var w := -1.0
	var h := 0.0
	for ch in text:
		var rows: Array = font.get(ch, [])
		if rows.is_empty():
			continue
		w += float((rows[0] as String).length()) + 1.0
		h = maxf(h, float(rows.size()))
	var origin := (at - Vector2(w, h) * 0.5).round()
	var x0 := 0.0
	for ch in text:
		var rows: Array = font.get(ch, [])
		if rows.is_empty():
			continue
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(origin + Vector2(x0 + x, y), Vector2.ONE), col)
		x0 += float((rows[0] as String).length()) + 1.0


## The angle (radians, clockwise from 12 o'clock) of hour `h` on a
## 12-hour dial.
static func _angle12(h: float) -> float:
	return TAU * fposmod(h, 12.0) / 12.0

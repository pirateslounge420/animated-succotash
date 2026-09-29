class_name Readouts
extends Control
## The two always-on HUD readouts (design §L; numbers and colors in
## data/hud.json): the speedometer and the watch-face clock. Both on by
## default, each switched in the settings panel (Settings "hud.speedometer",
## "hud.clock"). Small and quiet; they sit in their corners (hud.json
## layout) at the 720-line reference size and grow with the window like
## all the HUD (project stretch: scale = height / 720).
##
## Speedometer: your speed in mph and km/h (m/s too in dev mode), dim
## below dim_below_mps and brightening toward bright_at_mps (the momentum
## ceiling, 120 km/h), so it only asserts itself when you're fast. Its
## glow warms from glow_cold to glow_warm as the super meter fills.
##
## Clock: a watch face, not digits. One hour hand goes round once in 12
## hours; the inner ring reads 12, 1..11 and the outer ring the same
## places as 24, 13..23 (a pilot's watch), so one sweep reads both. A thin
## minute hand goes round once a game hour (6 real minutes). Two warm
## marks on the outer ring stand at today's dawn and dusk here (DayCycle,
## derived from latitude and season, design §F): they move through the
## year and as you travel.

static var HUD := {}

var speed_mps := 0.0
var meter := 0.0
## Local clock, hours 0-24, and today's dawn/dusk start hours here (-1:
## none today: polar night or midnight sun).
var clock_h := 0.0
var dawn_h := -1.0
var dusk_h := -1.0
var dev := false
## The bottom of the HUD's top-right text (the place readout), so a
## readout in that corner sits just below it instead of under it.
var top_right_below := 0.0
var _shown := 0.0


func _ready() -> void:
	HUD = Tuning.table("hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Per frame from Hud.
func feed(p_speed: float, p_meter: float, p_clock_h: float, p_dawn_h: float, p_dusk_h: float, p_dev: bool, delta: float) -> void:
	speed_mps = p_speed
	meter = p_meter
	clock_h = p_clock_h
	dawn_h = p_dawn_h
	dusk_h = p_dusk_h
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
	if Settings.get_bool("hud.speedometer", bool(_sec("speedometer").get("on_by_default", true))):
		_draw_speed()
	if Settings.get_bool("hud.clock", bool(_sec("clock").get("on_by_default", true))):
		_draw_clock()


func _draw_speed() -> void:
	var s := _sec("speedometer")
	var font := ThemeDB.fallback_font
	var px := HudText.px(float(s.get("size_px", 13)))
	var v := _shown
	var mph := v * 2.23694
	var kmh := v * 3.6
	var r := maxf(float(s.get("mph_round", 1)), 1.0)
	var lines: Array[String] = ["%d mph" % int(round(mph / r) * r), "%d km/h" % int(round(kmh))]
	if dev and bool(s.get("dev_shows_mps", true)):
		lines.append("%.1f m/s" % v)
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var line_h := px * 1.35
	var box := Vector2(w, line_h * lines.size())
	var at := _corner("speedometer", box)
	# Dim when slow, brighter toward the ceiling.
	var k := smoothstep(float(s.get("dim_below_mps", 6.0)), float(s.get("bright_at_mps", 33.3)), v)
	var a := lerpf(float(s.get("dim_alpha", 0.22)), float(s.get("bright_alpha", 0.9)), k)
	var glow := Color(str(s.get("glow_cold", "#4C7CFF"))).lerp(Color(str(s.get("glow_warm", "#FFD23A"))), clampf(meter, 0.0, 1.0))
	for i in lines.size():
		var p := at + Vector2(box.x - font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, line_h * (i + 1) - px * 0.3)
		draw_string_outline(font, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, Color(glow, a * 0.6))
		draw_string(font, p, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.93, 0.95, 1.0, a))


func _draw_clock() -> void:
	var c := _sec("clock")
	var d := float(c.get("size_px", 44))
	var a := float(c.get("alpha", 0.55))
	var at := _corner("clock", Vector2(d, d))
	var mid := at + Vector2(d, d) * 0.5
	var r := d * 0.5
	var ring := Color(Color(str(c.get("ring_color", "#4C7CFF"))), a)
	var hand := Color(Color(str(c.get("hand_color", "#7FB0FF"))), minf(a + 0.3, 1.0))
	var mark := Color(Color(str(c.get("mark_color", "#FFD23A"))), minf(a + 0.35, 1.0))
	draw_circle(mid, r, Color(Color(str(c.get("face_color", "#0A1250"))), a * 0.8))
	draw_arc(mid, r, 0.0, TAU, 48, ring, 1.5)
	draw_arc(mid, r * 0.62, 0.0, TAU, 40, Color(ring, a * 0.6), 1.0)
	# Hour ticks: the outer ring's 24 (13..24 at the same places as the
	# inner 1..12) and the inner ring's 12; the quarters longer.
	for h in 12:
		var ang := _angle12(float(h))
		var dir := Vector2(sin(ang), -cos(ang))
		var long := h % 3 == 0
		draw_line(mid + dir * r * (0.8 if long else 0.87), mid + dir * r * 0.97, ring, 1.5 if long else 1.0)
		draw_line(mid + dir * r * 0.55, mid + dir * r * 0.62, Color(ring, a * 0.7), 1.0)
	# Dawn and dusk on the outer ring, where they fall today here.
	if bool(c.get("dawn_dusk_marks", true)):
		for hm in [dawn_h, dusk_h]:
			if hm >= 0.0:
				var ang := _angle12(hm)
				var dir := Vector2(sin(ang), -cos(ang))
				draw_line(mid + dir * r * 0.72, mid + dir * r * 1.08, mark, 2.5)
		# Night in the lower half of the day? A small warm dot: PM.
		if clock_h >= 12.0:
			draw_circle(mid + Vector2(0, r * 0.32), 1.6, mark)
	# The hands.
	var ha := _angle12(clock_h)
	draw_line(mid, mid + Vector2(sin(ha), -cos(ha)) * r * 0.5, hand, 2.2)
	var ma := TAU * fposmod(clock_h, 1.0)
	draw_line(mid, mid + Vector2(sin(ma), -cos(ma)) * r * 0.82, Color(hand, hand.a * 0.8), 1.0)
	draw_circle(mid, 1.8, hand)


## The angle (radians, clockwise from 12 o'clock) of hour `h` on a
## 12-hour dial.
static func _angle12(h: float) -> float:
	return TAU * fposmod(h, 12.0) / 12.0

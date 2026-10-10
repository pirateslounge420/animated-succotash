class_name BrewVision
extends Control
## A brew's vision on screen (design 9 Oct §FM.7; queue 72; data/brew.json
## plants.<id>.vision): a placeholder, set per plant (a different experience
## for each plant, never a harder one; what a brew does is not locked). A
## tint over the whole frame (strength) and thicker in bands from its edges
## (edge), pulsing at pulse_hz down to (1 - pulse_depth) of itself; it eases
## in over fade_in_s from the moment you drink, holds until last_s (a first
## guess of 120 seconds), then fades over fade_s. Drawn in the 480-line
## frame like the rest of the HUD (§Y; CrawlerHarmView's banded edges),
## under the crosshair and the panels.
##
## It only draws (§FM.3): no light, no rule, no sense, no timer and no
## number of the game reads it or is changed by it, and nothing of it is
## saved (§FM.4).

## The bands from each edge (the era's stepped vignette, as the harm view's).
const BANDS := 5
## How deep the bands reach in from the edges (a share of the frame).
const EDGE_SHARE := 0.2

## The vision now: its plant, its block, its clock (s since you drank),
## running or not.
var plant := ""
var v: Dictionary = {}
var t := 0.0
var active := false
## Visions begun this session (the checks).
var started := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Begin `p_plant`'s vision (its brew.json vision block) now.
func start(p_plant: String, p_v: Dictionary) -> void:
	plant = p_plant
	v = p_v
	t = 0.0
	active = true
	started += 1
	visible = true
	queue_redraw()


func stop() -> void:
	active = false
	visible = false
	t = 0.0


## The vision's whole length (s): held until last_s, then fade_s.
func length_s() -> float:
	return maxf(float(v.get("last_s", 120.0)), 0.0) + maxf(float(v.get("fade_s", 10.0)), 0.0)


## Its strength now, 0 .. 1: easing in, held, fading.
func envelope() -> float:
	if not active:
		return 0.0
	var fin := maxf(float(v.get("fade_in_s", 4.0)), 0.001)
	var last := maxf(float(v.get("last_s", 120.0)), 0.0)
	var fade := maxf(float(v.get("fade_s", 10.0)), 0.001)
	var e := smoothstep(0.0, fin, t)
	if t > last:
		e *= 1.0 - smoothstep(last, last + fade, t)
	return clampf(e, 0.0, 1.0)


## Its pulse now (1 at its height, 1 - pulse_depth at its low).
func pulse() -> float:
	var hz := maxf(float(v.get("pulse_hz", 0.18)), 0.0)
	var depth := clampf(float(v.get("pulse_depth", 0.5)), 0.0, 1.0)
	return 1.0 - depth * 0.5 * (1.0 - cos(TAU * hz * t))


## The tint over the whole frame now (its alpha; 0 when none).
func level() -> float:
	return clampf(float(v.get("strength", 0.16)), 0.0, 1.0) * envelope() * pulse() if active else 0.0


## The tint's colour.
func tint() -> Color:
	return Color(str(v.get("tint", "#9c80ff")))


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	if t >= length_s():
		stop()
		return
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var col := tint()
	var e := envelope() * pulse()
	var a := clampf(float(v.get("strength", 0.16)), 0.0, 1.0) * e
	if a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(col, a))
	var ea := clampf(float(v.get("edge", 0.32)), 0.0, 1.0) * e
	if ea <= 0.0:
		return
	var ew := size.x * EDGE_SHARE
	var eh := size.y * EDGE_SHARE
	for band in BANDS:
		var k := float(band) / BANDS
		var c2 := Color(col, ea * (1.0 - k))
		var bx := ew * k
		var by := eh * k
		var bw := ew / BANDS
		var bh := eh / BANDS
		draw_rect(Rect2(bx, by, bw, size.y - 2.0 * by), c2)
		draw_rect(Rect2(size.x - bx - bw, by, bw, size.y - 2.0 * by), c2)
		draw_rect(Rect2(bx + bw, by, size.x - 2.0 * (bx + bw), bh), c2)
		draw_rect(Rect2(bx + bw, size.y - by - bh, size.x - 2.0 * (bx + bw), bh), c2)

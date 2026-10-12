class_name Compass
extends Control
## The crawler's heading strip (design 12 Oct §FW; queue 101; data/hud.json
## compass): a thin strip at the top of the frame showing which way you
## face. span_deg of arc is laid across width_frac of the frame, centred on
## your facing; a tick every tick_every_deg; the cardinal points as pixel
## glyphs (labels "cardinal": N E S W) or north alone ("north_only"). As
## you turn the points slide past; the point you face sits on the frame's
## middle column to the pixel.
##
## Drawn as the crosshair is (Reticle, §EX.7, §Y): cell by cell on the
## frame's own pixel grid, inside the 480-line internal frame and nearest-
## scaled with it, sizes at the 480 reference times HudText.scale(), every
## mark on a one-pixel dark navy edge, in compass.color (the reticle's cold
## blue, never warm). It gives off no light and nothing reads it.
##
## One north everywhere (§FW): -z is north and +x east, in the ruin, in a
## tunnel and on the surface (SurfaceGround's compass; the sun rises in the
## east). heading_deg is set by the scene from the camera's facing
## (heading_of): 0 north, 90 east, 180 south, 270 west.
##
## shrine_notches (§FV.2): on a surface only, a small notch under the strip
## for each bearing in `notches` (the scene fills it with the open shrine
## mouths' directions). No names, no distances, no route (§FM.8: not a
## map); the sacred plant and the boss are never marked.
##
## It shows in phase two's blackout (in_blackout: nothing about the fires
## touches it) and is never tinted by a brew (under_brew "untinted": it is
## drawn above BrewVision in the UI layer, past the grade). The Settings
## switch Compass (hud.compass, on by default) and compass.on turn it off.

static var C := Tuning.section("hud", "compass")
## The dark edge round every mark (the crosshair's).
const EDGE := Reticle.EDGE
## The cardinal glyphs, 3 x 5 pixels, rows top down ("#" lit).
const GLYPHS := {
	"N": ["#.#", "###", "###", "#.#", "#.#"],
	"E": ["###", "#..", "##.", "#..", "###"],
	"S": [".##", "#..", ".#.", "..#", "##."],
	"W": ["#.#", "#.#", "###", "###", "#.#"],
}
const POINTS := {"N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0}

## Off while the scene says so (a panel open).
var shown := true
## Your facing now (degrees, 0 north, clockwise).
var heading_deg := 0.0
## Bearings (degrees) with an open shrine mouth: the surface's (§FV.2).
var notches: Array = []
var _key: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## On screen now: compass.on, shown, in the tree and the switch on.
func showing() -> bool:
	return bool(C.get("on", true)) and shown and is_visible_in_tree() and Settings.get_bool("hud.compass")


## The heading (degrees, 0 north = -z, 90 east = +x) a camera basis faces.
static func heading_of(basis: Basis) -> float:
	var f := -basis.z
	if Vector2(f.x, f.z).length() < 1e-5:
		f = basis.y if -basis.z.y > 0.0 else -basis.y
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


## Its colour (hud.json compass.color).
static func color() -> Color:
	return Color(str(C.get("color", "#7FB0FF")))


func _process(_delta: float) -> void:
	var key := [showing(), roundi(heading_deg * 8.0), get_viewport_rect().size, HudText.scale(), notches.duplicate()]
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	if not showing():
		return
	draw_strip(self, heading_deg, notches)


## Draw the strip on `ci` facing `heading` with `p_notches`: the edge, then
## the marks.
static func draw_strip(ci: CanvasItem, heading: float, p_notches: Array = []) -> void:
	var cl := cells(Vector2i(ci.get_viewport_rect().size.round()), heading, p_notches)
	for r: Rect2i in cl.edge:
		ci.draw_rect(Rect2(r), EDGE)
	var col := color()
	for r: Rect2i in cl.marks:
		ci.draw_rect(Rect2(r), col)


## The strip on a frame `frame` pixels big facing `heading`, at `k` (the
## frame's lines over the 480 reference; HudText.scale() when left out):
## {"strip": its box, "mid": the middle column, "ppd": pixels a degree,
## "points": {letter: the column its glyph is centred on, for the points in
## view}, "ticks": [columns], "notch_x": [columns], "marks": the lit pixels
## and "edge": the dark edge one pixel round them, each as whole-pixel runs
## along the rows}.
static func cells(frame: Vector2i, heading: float, p_notches: Array = [], k := -1.0) -> Dictionary:
	if k < 0.0:
		k = HudText.scale()
	var g := maxi(roundi(k), 1)
	var w := maxi(roundi(float(C.get("width_frac", 0.33)) * frame.x), 8)
	var h := maxi(roundi(float(C.get("height_px", 9)) * k), 5 * g + 2)
	var mid := frame.x / 2
	var top := maxi(roundi(3.0 * k), 2)
	if str(C.get("place", "top_centre")) == "bottom_centre":
		top = frame.y - top - h - 3 * g
	var x0 := mid - w / 2
	var strip := Rect2i(x0, top, w, h)
	var span := clampf(float(C.get("span_deg", 120.0)), 10.0, 360.0)
	var ppd := float(w) / span
	var every := maxf(float(C.get("tick_every_deg", 45.0)), 1.0)
	var labels := str(C.get("labels", "cardinal"))
	var on := {}
	var out := {"strip": strip, "mid": mid, "ppd": ppd, "points": {}, "ticks": [], "notch_x": []}
	# The column a bearing falls on, or -1 when it's off the strip.
	var col_of := func(b: float, half_w: int) -> int:
		var d := fposmod(b - heading + 180.0, 360.0) - 180.0
		var x := mid + roundi(d * ppd)
		if x - half_w < x0 or x + half_w >= x0 + w:
			return -1
		return x
	# The ticks: a short line up from the strip's foot.
	var tick_h := maxi(roundi(h * 0.34), g)
	var n_ticks := int(round(360.0 / every))
	for i in n_ticks:
		var b := i * every
		var is_point := false
		for p in POINTS:
			if absf(fposmod(b - float(POINTS[p]) + 180.0, 360.0) - 180.0) < 0.01 and (labels == "cardinal" or p == "N"):
				is_point = true
		if is_point:
			continue
		var x: int = col_of.call(b, 0)
		if x < 0:
			continue
		out.ticks.append(x)
		for y in range(top + h - tick_h, top + h):
			on[Vector2i(x, y)] = true
	# The points: their glyphs, centred on their column, at the strip's
	# middle height.
	var gy := top + (h - 5 * g) / 2
	for p: String in POINTS:
		if labels == "north_only" and p != "N":
			continue
		var x: int = col_of.call(float(POINTS[p]), (3 * g) / 2 + 1)
		if x < 0:
			continue
		out.points[p] = x
		var rows: Array = GLYPHS[p]
		var gx := x - (3 * g) / 2
		for ry in 5:
			var row: String = rows[ry]
			for rx in 3:
				if row[rx] == "#":
					for sy in g:
						for sx in g:
							on[Vector2i(gx + rx * g + sx, gy + ry * g + sy)] = true
	# The notches (§FV.2): a small mark under the strip per open mouth.
	if bool(C.get("shrine_notches", true)):
		for b in p_notches:
			var x: int = col_of.call(float(b), g)
			if x < 0:
				continue
			out.notch_x.append(x)
			for y in range(top + h + 1, top + h + 1 + 2 * g):
				for dx in range(-(g / 2), g - g / 2):
					on[Vector2i(x + dx, y)] = true
	var px: Array[Rect2i] = []
	for p: Vector2i in on:
		px.append(Rect2i(p, Vector2i.ONE))
	out["marks"] = Reticle._runs(on)
	out["edge"] = Reticle._runs(Reticle._edge_of(px))
	return out


## The open shrine mouths' bearings over the ruin `ruin` (ruin_compass.json
## ruins.<ruin>.exits): until shrine mouths are built (§FV.2, queue 100) a
## direction counts only when the neighbour it leads to is built (its
## status starting "built"); none are yet, so none.
static var _exits := {}


static func open_exits(ruin: String) -> Array:
	if _exits.has(ruin):
		return _exits[ruin]
	var RC: Dictionary = Surface._json("res://data/ruin_compass.json")
	var ruins: Dictionary = RC.get("ruins", {})
	var ex: Dictionary = (ruins.get(ruin, {}) as Dictionary).get("exits", {})
	var out: Array = []
	for dir: String in ex:
		var to: Dictionary = ruins.get(str(ex[dir]), {})
		var b = {"north": 0.0, "east": 90.0, "south": 180.0, "west": 270.0}.get(dir, null)
		if b != null and str(to.get("status", "")).begins_with("built"):
			out.append(float(b))
	_exits[ruin] = out
	return out

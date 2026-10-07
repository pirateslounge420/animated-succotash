class_name Reticle
extends Control
## The crosshair (data/hud.json reticle; design §W, §Y): four arms round
## the frame's middle pixel, each size_px / 2 long and thickness_px wide,
## gap_px clear pixels out from the middle, in `color`, each on a
## one-pixel dark edge. Drawn cell by cell on the frame's own pixel grid
## (whole-pixel rects, the way the clock is), inside the internal frame
## and nearest-scaled with it, so it is crisp and the same on all four
## sides at every pixel-size preset. Its sizes are at the 480-line
## reference and follow the frame's lines like the HUD's text
## (HudText.scale(): arms 3, gap 2 at 270 lines), never under a pixel;
## the edge is always one. One crosshair: the open world's StatusHud
## draws it through draw_cross() too, so the two can't drift apart.
##
## As a node it is the crawler's whole HUD (design 6 Oct §EX.7,
## crawler.json hud): shown in first person while the Settings switch
## hud.reticle (Crosshair dot) is on; the scene hides it while a panel
## covers the middle of the frame. No words (§ET.3). It gives off no
## light: its layer is drawn over the finished frame, past the grade, the
## dither and the bloom.
##
## While you sneak (design §FC.1, stealth.json sneak.reticle; the scene
## sets `sneak`) the arms close into a small ring round the same middle,
## ring_px out (at the 480 reference, following the frame's lines like the
## arms), in the arms' colour and width on the same one-pixel dark edge,
## all of it dimmed to dim. Standing, the cross is back.

static var RETICLE := Tuning.section("hud", "reticle")
static var SNEAK_LOOK: Dictionary = (Tuning.table("stealth").get("sneak", {}) as Dictionary).get("reticle", {})
## The dark edge round every arm (StatusHud's ink, at 70 %).
const EDGE := Color(0.05, 0.07, 0.15, 0.7)

## Off while the scene says so (a panel open).
var shown := true
## Sneaking: the sneak's look instead of the cross.
var sneak := false
## What the last draw showed (_process redraws when it changes).
var _key: Array = []
## cells() and ring_cells() for the last frame and scale asked.
static var _cells_key: Array = []
static var _cells: Dictionary = {}
static var _ring_key: Array = []
static var _ring: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## On screen now: shown, in the tree and the Settings switch on.
func showing() -> bool:
	return shown and is_visible_in_tree() and Settings.get_bool("hud.reticle")


## What it draws now: "cross", "ring" (sneaking) or "none" (the checks).
func shape_now() -> String:
	if not showing():
		return "none"
	return "ring" if sneak and str(SNEAK_LOOK.get("shape", "ring")) == "ring" else "cross"


## Its strength now: whole, or the sneak's dim.
func alpha_now() -> float:
	return float(SNEAK_LOOK.get("dim", 0.75)) if sneak else 1.0


## Redrawn only when what it shows changes: the switch, a panel, the
## sneak, the pixel-size preset.
func _process(_delta: float) -> void:
	var key := [showing(), sneak, get_viewport_rect().size, HudText.scale()]
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	match shape_now():
		"ring":
			draw_ring(self, alpha_now())
		"cross":
			draw_cross(self, alpha_now())


## Its colour (hud.json reticle.color).
static func color() -> Color:
	return Color(str(RETICLE.get("color", "#7FB0FF")))


## Draw the crosshair on `ci` (a canvas item in the internal frame): the
## edge, then the arms over it, at `alpha` of their strength.
static func draw_cross(ci: CanvasItem, alpha := 1.0) -> void:
	var cl := cells(Vector2i(ci.get_viewport_rect().size.round()))
	var e := Color(EDGE, EDGE.a * alpha)
	for r: Rect2i in cl.edge:
		ci.draw_rect(Rect2(r), e)
	var col := color()
	col.a *= alpha
	for r: Rect2i in cl.arms:
		ci.draw_rect(Rect2(r), col)


## Draw the sneak's ring on `ci` the same way: its edge, then the ring.
static func draw_ring(ci: CanvasItem, alpha := 1.0) -> void:
	var rc := ring_cells(Vector2i(ci.get_viewport_rect().size.round()))
	var e := Color(EDGE, EDGE.a * alpha)
	for r: Rect2i in rc.edge:
		ci.draw_rect(Rect2(r), e)
	var col := color()
	col.a *= alpha
	for r: Rect2i in rc.ring:
		ci.draw_rect(Rect2(r), col)


## The crosshair on a frame `frame` pixels big, its sizes at `k` (the
## frame's lines over the 480 reference; HudText.scale() when left out):
## {"middle": the middle pixel; "arm", "gap", "width": its sizes in
## pixels; "arms": [left, right, up, down] as whole-pixel rects; "edge":
## the dark edge one pixel round them, each pixel once, in runs along the
## rows}.
static func cells(frame: Vector2i, k := -1.0) -> Dictionary:
	if k < 0.0:
		k = HudText.scale()
	var key := [frame, k]
	if key == _cells_key:
		return _cells
	var arm := maxi(roundi(float(RETICLE.get("size_px", 10)) * 0.5 * k), 1)
	var gap := maxi(roundi(float(RETICLE.get("gap_px", 3)) * k), 0)
	var w := maxi(roundi(float(RETICLE.get("thickness_px", 1)) * k), 1)
	# The frame's sides are even, so its centre is a pixel corner: the
	# middle pixel is the one below and right of it. The band the arms
	# run along is w pixels: on the middle pixel when w is odd, on the
	# centre itself when even.
	var mid := frame / 2
	var lo := mid - Vector2i(w / 2, w / 2)
	var hi := lo + Vector2i(w - 1, w - 1)
	var arms: Array[Rect2i] = [
		Rect2i(lo.x - gap - arm, lo.y, arm, w),
		Rect2i(hi.x + gap + 1, lo.y, arm, w),
		Rect2i(lo.x, lo.y - gap - arm, w, arm),
		Rect2i(lo.x, hi.y + gap + 1, w, arm),
	]
	# The edge: every pixel next to an arm (sides and corners) that isn't
	# one, once, so where two edges would meet it isn't drawn twice.
	var on := {}
	for a in arms:
		for y in range(a.position.y, a.end.y):
			for x in range(a.position.x, a.end.x):
				on[Vector2i(x, y)] = true
	var ring := {}
	for a in arms:
		var g := a.grow(1)
		for y in range(g.position.y, g.end.y):
			for x in range(g.position.x, g.end.x):
				var p := Vector2i(x, y)
				if not on.has(p):
					ring[p] = true
	_cells_key = key
	_cells = {"middle": mid, "arm": arm, "gap": gap, "width": w, "arms": arms, "edge": _runs(ring)}
	return _cells


## The sneak's ring on a frame `frame` pixels big, at `k` (as cells()):
## {"middle": the middle pixel; "radius", "width": its sizes in pixels;
## "ring": its pixels and "edge": the dark edge one pixel round them,
## inside and out, each as whole-pixel runs along the rows}. The ring is
## the outer `width` pixels of the disk of every pixel whose centre lies
## within radius + 1/2 of the arms' crossing, peeled a pixel at a time, so
## it is one clean pixel line, the same on all four sides.
static func ring_cells(frame: Vector2i, k := -1.0) -> Dictionary:
	if k < 0.0:
		k = HudText.scale()
	var key := [frame, k]
	if key == _ring_key:
		return _ring
	var w := maxi(roundi(float(RETICLE.get("thickness_px", 1)) * k), 1)
	var rad := maxi(roundi(float(SNEAK_LOOK.get("ring_px", 4)) * k), w + 1)
	var mid := frame / 2
	var lo := mid - Vector2i(w / 2, w / 2)
	# Where the arms' band crosses: the middle pixel's centre when the
	# width is odd, the frame's centre when even.
	var c := Vector2(lo) + Vector2(w, w) * 0.5
	var disk := {}
	for y in range(lo.y - rad - 1, lo.y + w + rad + 1):
		for x in range(lo.x - rad - 1, lo.x + w + rad + 1):
			if (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c) <= float(rad) + 0.5:
				disk[Vector2i(x, y)] = true
	var inner := disk
	for i in w:
		var kept := {}
		for p: Vector2i in inner:
			if inner.has(p + Vector2i.LEFT) and inner.has(p + Vector2i.RIGHT) and inner.has(p + Vector2i.UP) and inner.has(p + Vector2i.DOWN):
				kept[p] = true
		inner = kept
	var on := {}
	for p: Vector2i in disk:
		if not inner.has(p):
			on[p] = true
	var edge := {}
	for p: Vector2i in on:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var q := p + Vector2i(dx, dy)
				if not on.has(q):
					edge[q] = true
	_ring_key = key
	_ring = {"middle": mid, "radius": rad, "width": w, "ring": _runs(on), "edge": _runs(edge)}
	return _ring


## A set of pixels (Vector2i keys) as whole-pixel runs along the rows.
static func _runs(px: Dictionary) -> Array[Rect2i]:
	var pts: Array = px.keys()
	pts.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array[Rect2i] = []
	for p: Vector2i in pts:
		if not out.is_empty() and out[-1].position.y == p.y and out[-1].end.x == p.x:
			var last: Rect2i = out[-1]
			last.size.x += 1
			out[-1] = last
		else:
			out.append(Rect2i(p, Vector2i.ONE))
	return out

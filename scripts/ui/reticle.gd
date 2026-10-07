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
## sets `sneak`) the cross loses its up and down arms and keeps only its
## two level ones (shape dashes; Mike, 7 Oct: "take away the vertical
## dashes and just leave horizontal dashes to signify sneak state"), on
## the same one-pixel dark edge, dimmed to dim. Standing, the cross is
## back. (Shape ring, the first look, closed the arms into a small ring
## ring_px out.)
##
## A hit (Mike, 7 Oct: "if you get a hit on a creature tho, there will be
## an X shape in the diagonal spaces between the regular crosshair to
## signify a successful hit"; hud.json reticle.hit_marker): when your swing
## meets a creature (Torch, CreatureStrike.swing_lands) or your pot's fire
## reaches one (FirePots.mark_hit: the burst at once, its tar burning on
## every burn_every_s; Mike, 7 Oct: "anytime a creature gets hit from
## something initiated from the player"), hit() shows an X for show_s:
## four short diagonals in the corners between the arms, from_px out from
## the middle and length_px long (at the 480 reference), in the
## crosshair's colour on its dark edge. It never warms or shows anything
## else (Mike: what you can light is the player's to find out).

static var RETICLE := Tuning.section("hud", "reticle")
static var SNEAK_LOOK: Dictionary = (Tuning.table("stealth").get("sneak", {}) as Dictionary).get("reticle", {})
## The dark edge round every arm (StatusHud's ink, at 70 %).
const EDGE := Color(0.05, 0.07, 0.15, 0.7)

## Off while the scene says so (a panel open).
var shown := true
## Sneaking: the sneak's look instead of the cross.
var sneak := false
## Hits so far (hit()); the last count this crosshair showed, and how
## long its X shows still (s).
static var hits := 0
var _hits_seen := 0
var _hit_left := 0.0
## What the last draw showed (_process redraws when it changes).
var _key: Array = []
## cells() and ring_cells() for the last frame and scale asked.
static var _cells_key: Array = []
static var _cells: Dictionary = {}
static var _ring_key: Array = []
static var _ring: Dictionary = {}
static var _dash_key: Array = []
static var _dash: Dictionary = {}
static var _x_key: Array = []
static var _x: Dictionary = {}
static var HIT: Dictionary = RETICLE.get("hit_marker", {})


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hits before this crosshair was made aren't its to show.
	_hits_seen = hits


## On screen now: shown, in the tree and the Settings switch on.
func showing() -> bool:
	return shown and is_visible_in_tree() and Settings.get_bool("hud.reticle")


## What it draws now: "cross", "dashes" or "ring" (sneaking, by
## sneak.reticle.shape) or "none" (the checks).
func shape_now() -> String:
	if not showing():
		return "none"
	if sneak:
		var sh := str(SNEAK_LOOK.get("shape", "dashes"))
		if sh in ["dashes", "ring"]:
			return sh
	return "cross"


## Its strength now: whole, or the sneak's dim.
func alpha_now() -> float:
	return float(SNEAK_LOOK.get("dim", 0.75)) if sneak else 1.0


## A hit on a creature (Torch's swing, FirePots' burst): the X shows on
## every crosshair for hit_marker.show_s.
static func hit() -> void:
	hits += 1


## Its X showing now (checks).
func hit_showing() -> bool:
	return showing() and _hit_left > 0.0


## Redrawn only when what it shows changes: the switch, a panel, the
## sneak, the pixel-size preset, a hit's X.
func _process(delta: float) -> void:
	if hits != _hits_seen:
		_hits_seen = hits
		_hit_left = float(HIT.get("show_s", 0.3))
	else:
		_hit_left = maxf(_hit_left - delta, 0.0)
	var key := [showing(), sneak, get_viewport_rect().size, HudText.scale(), _hit_left > 0.0]
	if key != _key:
		_key = key
		queue_redraw()


func _draw() -> void:
	match shape_now():
		"dashes":
			draw_dashes(self, alpha_now())
		"ring":
			draw_ring(self, alpha_now())
		"cross":
			draw_cross(self, alpha_now())
	if hit_showing():
		draw_x(self, alpha_now(), shape_now())


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


## Draw the sneak's dashes on `ci` the same way: their edge, then them.
static func draw_dashes(ci: CanvasItem, alpha := 1.0) -> void:
	var dc := dash_cells(Vector2i(ci.get_viewport_rect().size.round()))
	var e := Color(EDGE, EDGE.a * alpha)
	for r: Rect2i in dc.edge:
		ci.draw_rect(Rect2(r), e)
	var col := color()
	col.a *= alpha
	for r: Rect2i in dc.arms:
		ci.draw_rect(Rect2(r), col)


## Draw a hit's X on `ci` the same way, over the crosshair's `under`
## shape: its edge, then its diagonals.
static func draw_x(ci: CanvasItem, alpha := 1.0, under := "cross") -> void:
	var xc := x_cells(Vector2i(ci.get_viewport_rect().size.round()), -1.0, under)
	var e := Color(EDGE, EDGE.a * alpha)
	for r: Rect2i in xc.edge:
		ci.draw_rect(Rect2(r), e)
	var col := color()
	col.a *= alpha
	for r: Rect2i in xc.x:
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


## The sneak's dashes on a frame `frame` pixels big, at `k` (as cells()):
## the crosshair's two level arms alone, {"middle", "arm", "gap", "width",
## "arms" [left, right], "edge" (the dark edge one pixel round them, each
## pixel once, in runs along the rows)}.
static func dash_cells(frame: Vector2i, k := -1.0) -> Dictionary:
	if k < 0.0:
		k = HudText.scale()
	var key := [frame, k]
	if key == _dash_key:
		return _dash
	var cl := cells(frame, k)
	var arms: Array[Rect2i] = [cl.arms[0], cl.arms[1]]
	_dash_key = key
	_dash = {"middle": cl.middle, "arm": cl.arm, "gap": cl.gap, "width": cl.width, "arms": arms, "edge": _runs(_edge_of(arms))}
	return _dash


## A hit's X on a frame `frame` pixels big, at `k` (as cells()), over the
## crosshair's `under` shape ("cross", "dashes" or "ring"): {"middle",
## "from", "length", "x": its pixels (four diagonals, from `from` to
## from + length - 1 pixels out from the middle band's corner along each,
## `width` wide), "edge": the dark edge one pixel round them, less what
## the shape under it draws already (so no pixel is darkened twice)}, each
## as runs along the rows.
static func x_cells(frame: Vector2i, k := -1.0, under := "cross") -> Dictionary:
	if k < 0.0:
		k = HudText.scale()
	var key := [frame, k, under]
	if key == _x_key:
		return _x
	var cl := cells(frame, k)
	var from := maxi(roundi(float(HIT.get("from_px", 3)) * k), 1)
	var length := maxi(roundi(float(HIT.get("length_px", 4)) * k), 1)
	var w := int(cl.width)
	var mid: Vector2i = cl.middle
	var lo := mid - Vector2i(w / 2, w / 2)
	var on := {}
	for d in range(from, from + length):
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				for j in w:
					# Each diagonal w pixels thick, out from the middle band's
					# corner on its side.
					var bx := lo.x + (w - 1 if sx > 0 else 0)
					var by := lo.y + (w - 1 if sy > 0 else 0)
					on[Vector2i(bx + sx * d, by + sy * d + (j if sy > 0 else -j))] = true
	var px: Array[Rect2i] = []
	for p: Vector2i in on:
		px.append(Rect2i(p, Vector2i.ONE))
	var drawn: Array = []
	match under:
		"cross":
			drawn = cl.arms + cl.edge
		"dashes":
			var dc := dash_cells(frame, k)
			drawn = dc.arms + dc.edge
		"ring":
			var rc := ring_cells(frame, k)
			drawn = rc.ring + rc.edge
	var edge := _edge_of(px)
	for r: Rect2i in drawn:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				edge.erase(Vector2i(x, y))
	_x_key = key
	_x = {"middle": mid, "from": from, "length": length, "x": _runs(on), "edge": _runs(edge)}
	return _x


## The pixels one round `rects` (sides and corners) that none of them
## covers, each once (Vector2i keys).
static func _edge_of(rects: Array[Rect2i]) -> Dictionary:
	var on := {}
	for a in rects:
		for y in range(a.position.y, a.end.y):
			for x in range(a.position.x, a.end.x):
				on[Vector2i(x, y)] = true
	var edge := {}
	for a in rects:
		var g := a.grow(1)
		for y in range(g.position.y, g.end.y):
			for x in range(g.position.x, g.end.x):
				var p := Vector2i(x, y)
				if not on.has(p):
					edge[p] = true
	return edge


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

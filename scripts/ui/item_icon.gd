class_name ItemIcon
## The little pictures of items (the inventory screen): drawn, not
## textured, in the item's own colors (a plant sample in its species'
## leaf and stem/flower colors), about `r` pixels in radius round `c`.

const INK := Color(0.05, 0.07, 0.15, 0.9)


static func draw_icon(ci: CanvasItem, c: Vector2, r: float, it: Dictionary) -> void:
	var cols := Inventory.colors(it)
	var main: Color = cols[0]
	var second: Color = cols[1]
	var icon := str(Inventory.kind_info(it.kind).get("icon", "sample"))
	if icon == "sample":
		icon = str(it.get("part", "cutting"))
	var w := maxf(1.0, r * 0.12)
	match icon:
		"cutting":
			# A stem with three leaves.
			ci.draw_line(c + Vector2(-r * 0.2, r * 0.9), c + Vector2(r * 0.15, -r * 0.8), second, w * 1.4)
			for k in 3:
				var p := c + Vector2(-r * 0.12 + k * r * 0.12, r * 0.4 - k * r * 0.5)
				_leaf(ci, p, r * 0.5, -0.7 if k % 2 == 0 else 0.7, main)
		"seed":
			# A nodding seed head on a stalk.
			ci.draw_line(c + Vector2(0, r * 0.9), c + Vector2(r * 0.1, -r * 0.3), second.lightened(0.2), w)
			for k in 7:
				var p := c + Vector2(r * 0.1 + sin(k * 1.3) * r * 0.18, -r * 0.35 - k * r * 0.08)
				ci.draw_circle(p, r * 0.13, main.lerp(Color(0.85, 0.75, 0.45), 0.5))
		"leaf":
			_leaf(ci, c, r * 1.1, -0.5, main)
			ci.draw_line(c + Vector2(-r * 0.55, r * 0.35), c + Vector2(r * 0.5, -r * 0.3), main.darkened(0.35), w)
		"column":
			# A cut column of cactus: ribbed, with a pale cut face on top.
			var rect := Rect2(c - Vector2(r * 0.4, r * 0.85), Vector2(r * 0.8, r * 1.7))
			ci.draw_rect(rect, main)
			for k in 3:
				var x := rect.position.x + rect.size.x * (0.25 + k * 0.25)
				ci.draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y), main.darkened(0.3), w)
			ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, r * 0.22)), main.lightened(0.45))
		"bundle":
			# Stems tied with a band.
			for k in 5:
				var dx := (k - 2) * r * 0.16
				ci.draw_line(c + Vector2(dx * 0.4, r * 0.9), c + Vector2(dx * 1.6, -r * 0.7), second, w)
				ci.draw_circle(c + Vector2(dx * 1.6, -r * 0.75), r * 0.2, main)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.15), Vector2(r * 0.6, r * 0.22)), Color(0.72, 0.36, 0.2))
		"fish":
			ci.draw_colored_polygon(_ellipse(c + Vector2(-r * 0.1, 0), r * 0.75, r * 0.38), main)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.55, 0), c + Vector2(r * 0.95, -r * 0.35), c + Vector2(r * 0.95, r * 0.35)]), main.darkened(0.2))
			ci.draw_circle(c + Vector2(-r * 0.55, -r * 0.08), r * 0.08, INK)
		"mushroom":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.16, -r * 0.1), Vector2(r * 0.32, r * 0.9)), Color(0.9, 0.86, 0.76))
			var cap := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				cap.append(c + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.6))
			ci.draw_colored_polygon(cap, main)
		"pole":
			# The fishing pole: a long cane with a line hanging from the tip.
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.7, -r * 0.8), main, w * 1.3)
			ci.draw_line(c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.75, r * 0.2), Color(0.9, 0.88, 0.8), maxf(1.0, w * 0.5))
			ci.draw_arc(c + Vector2(r * 0.75, r * 0.3), r * 0.1, 0.0, TAU, 8, Color(0.55, 0.56, 0.6), maxf(1.0, w * 0.5))
		"bow":
			ci.draw_arc(c + Vector2(-r * 0.5, 0), r * 0.95, -PI * 0.42, PI * 0.42, 14, main, w * 1.6)
			var t := c + Vector2(-r * 0.5, 0) + Vector2(cos(PI * 0.42), sin(PI * 0.42)) * r * 0.95
			var b := c + Vector2(-r * 0.5, 0) + Vector2(cos(-PI * 0.42), sin(-PI * 0.42)) * r * 0.95
			ci.draw_line(t, b, Color(0.9, 0.88, 0.8), maxf(1.0, w * 0.5))
		"spear":
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.55, -r * 0.55), main, w * 1.4)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.45, -r * 0.65), c + Vector2(r * 0.95, -r * 0.95), c + Vector2(r * 0.65, -r * 0.45)]), Color(0.55, 0.56, 0.6))
		"amulet":
			ci.draw_arc(c + Vector2(0, -r * 0.2), r * 0.6, PI * 0.1, PI * 0.9, 10, Color(0.7, 0.6, 0.45), w)
			ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.3, main)
		"ring":
			ci.draw_arc(c, r * 0.55, 0.0, TAU, 20, main, w * 1.8)
		"fruit":
			_fruit(ci, c, r, it, main, w)
		"pot":
			# A round-bellied pot with a neck (a camp's gift, §EJ.4).
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, r * 0.2), r * 0.7, r * 0.6), main)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.65), Vector2(r * 0.6, r * 0.35)), main.darkened(0.15))
			if str(it.get("kind", "")) == "fire_pot":
				# A fire pot (§FA.3, §FJ.5; the left hand's strip, §FB): its
				# mouth stopped with its oil's plug, tar's black pitch or light
				# oil's pale seal (PotMesh), the wick standing out of it, lit
				# in the fire's amber once it has caught.
				var plug := PotMesh.PITCH if str(it.get("oil", "tar")) == "tar" else PotMesh.SEAL
				ci.draw_rect(Rect2(c + Vector2(-r * 0.34, -r * 0.82), Vector2(r * 0.68, r * 0.26)), plug)
				var tip := c + Vector2(r * 0.3, -r * 1.12)
				ci.draw_line(c + Vector2(0, -r * 0.82), tip, PotMesh.WICK.lightened(0.35), maxf(1.0, w * 1.2))
				if bool(it.get("lit", false)):
					ci.draw_circle(tip, r * 0.2, Torch.fire_color())
		"torch":
			# A stick and its burnt end; lit, the end glows in the fire's
			# amber (§EX.6). A spent one is a stick.
			var tip := c + Vector2(r * 0.42, -r * 0.62)
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.88), tip, Color(0.45, 0.31, 0.17), w * 1.8)
			if bool(it.get("lit", false)):
				ci.draw_circle(tip + Vector2(r * 0.06, -r * 0.1), r * 0.36, Torch.fire_color())
				ci.draw_circle(tip + Vector2(r * 0.04, -r * 0.06), r * 0.18, Color("#FEFC54"))
			elif not bool(it.get("burnt", false)):
				ci.draw_circle(tip, r * 0.2, Color(0.12, 0.08, 0.06))
		"bowl":
			# A bowl with the stew showing.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, -r * 0.1), c + Vector2(r * 0.85, -r * 0.1), c + Vector2(r * 0.45, r * 0.6), c + Vector2(-r * 0.45, r * 0.6)]), main)
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, -r * 0.1), r * 0.8, r * 0.18), Color(0.55, 0.36, 0.2))
		"cord":
			# A hank of cord: loops bound in the middle.
			for k in 3:
				ci.draw_arc(c, r * (0.35 + 0.18 * k), 0.0, TAU, 16, main.darkened(0.08 * k), w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.8), Vector2(r * 0.24, r * 1.6)), main.darkened(0.3))
		"basket":
			# A basket: weave lines across a tapered body.
			var bpts := PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.4), c + Vector2(r * 0.75, -r * 0.4), c + Vector2(r * 0.5, r * 0.75), c + Vector2(-r * 0.5, r * 0.75)])
			ci.draw_colored_polygon(bpts, main)
			for k in 3:
				var y := -r * 0.15 + k * r * 0.3
				ci.draw_line(c + Vector2(-r * 0.68 + k * 0.08 * r, y), c + Vector2(r * 0.68 - k * 0.08 * r, y), main.darkened(0.3), maxf(1.0, w * 0.7))
		_:
			ci.draw_circle(c, r * 0.6, main)


## A picked fruit by its shape (FruitCrop): on a short stalk with a leaf,
## a cone or a winged key as themselves.
static func _fruit(ci: CanvasItem, c: Vector2, r: float, it: Dictionary, col: Color, w: float) -> void:
	var stalk := Color(0.36, 0.27, 0.16)
	match str(it.get("shape", "round")):
		"cone":
			var pts := PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.45, -r * 0.1), c + Vector2(r * 0.3, r * 0.6), c + Vector2(0, r * 0.85), c + Vector2(-r * 0.3, r * 0.6), c + Vector2(-r * 0.45, -r * 0.1)])
			ci.draw_colored_polygon(pts, col)
			for k in 4:
				var y := -r * 0.45 + k * r * 0.33
				ci.draw_line(c + Vector2(-r * 0.35, y), c + Vector2(r * 0.35, y + r * 0.12), col.darkened(0.35), maxf(1.0, w * 0.6))
			return
		"winged":
			ci.draw_circle(c + Vector2(-r * 0.35, r * 0.4), r * 0.2, col.darkened(0.15))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, r * 0.3), c + Vector2(r * 0.8, -r * 0.7), c + Vector2(r * 0.55, -r * 0.2), c + Vector2(-r * 0.2, r * 0.5)]), col.lightened(0.15))
			return
		"elongated", "pod":
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, r * 0.15), r * 0.28, r * 0.75), col)
		"ovoid":
			ci.draw_colored_polygon(_ellipse(c + Vector2(0, r * 0.15), r * 0.5, r * 0.65), col)
		_:
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.6, col)
	# A glint, the stalk and a leaf.
	ci.draw_circle(c + Vector2(-r * 0.22, -r * 0.08), r * 0.1, col.lightened(0.45))
	ci.draw_line(c + Vector2(0, -r * 0.4), c + Vector2(r * 0.12, -r * 0.85), stalk, maxf(1.0, w))
	_leaf(ci, c + Vector2(r * 0.35, -r * 0.72), r * 0.5, -0.4, Color(0.34, 0.55, 0.24))


## An open hand, its fingers up (an empty hand on the hands' strip,
## HandStrip, §FB), as pixel art: HAND at a whole-number scale for the
## size `r` (2 at the strip's 480-line cell, 1 at 270), so its fingers
## stay apart. A left hand seen from the back, its thumb out to the right;
## mirrored for the right hand.
const HAND := [
	"....#....",
	"..#.#.#..",
	"#.#.#.#..",
	"#.#.#.#..",
	"#######.#",
	"#######.#",
	"#########",
	"########.",
	".######..",
	"..#####..",
]


static func draw_hand(ci: CanvasItem, c: Vector2, r: float, col: Color, right_hand := false) -> void:
	var w: int = (HAND[0] as String).length()
	var s := maxf(1.0, floorf(r * 2.0 / w))
	var top := (c - Vector2(w, HAND.size()) * s * 0.5).round()
	for y in HAND.size():
		var line: String = HAND[y]
		for x in w:
			if line[x] == "#":
				var px := (w - 1 - x) if right_hand else x
				ci.draw_rect(Rect2(top + Vector2(px, y) * s, Vector2(s, s)), col)


static func _leaf(ci: CanvasItem, at: Vector2, length: float, tilt: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 10
	for k in n + 1:
		var t := float(k) / n
		pts.append(Vector2(t * length, sin(t * PI) * length * 0.28))
	for k in range(n - 1, 0, -1):
		var t := float(k) / n
		pts.append(Vector2(t * length, -sin(t * PI) * length * 0.28))
	var xf := Transform2D(tilt, at - Vector2(cos(tilt), sin(tilt)) * length * 0.5)
	ci.draw_colored_polygon(xf * pts, col)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

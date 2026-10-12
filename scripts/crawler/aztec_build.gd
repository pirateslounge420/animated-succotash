class_name AztecBuild
## The Aztec temple's own stone work (design 10 Oct §FN.1, queue 80;
## data/room_pool.json archetypes aztec_blood_altar, aztec_calendar_room;
## data/aztec_temple.json calendar), for RoomPoolBuild.dress, in the
## temple's one stone (§EX.1: RuinStyle, masonry.json aztec_temple), painted
## per §ES (diffuse, cut-back toward navy, never grey):
##
##   round_room   a round chamber: the square room's corners filled in
##                coursed blocks, its walls a polygon (shape sides), the
##                stone behind each corner face collision
##   altar_drum   the round sacrificial stone (temalacatl) with a carved
##                ring at its rim and its foot, the stain dried near-black
##                brown on its top (never bright red: fire is the one warm
##                accent); no bodies
##   bowl         a stone bowl (cuauhxicalli) beside it
##   offerings    small carved stones round the altar's foot
##   day_signs    the tonalpohualli's 20 day-sign panels in relief, each
##                with its sign's glyph and its day's number 1-13 in dots
##
## Static, on the builder's own dice (TombBuild.rng), so the same seed draws
## the same room; a sign's glyph on its own number, so it is the same in
## every temple.


## A round chamber (room_pool.json shape round): the square room's corners
## filled in its stone, so its walls run as a polygon of `sides` (a
## multiple of four: a face on each wall's middle, the wall itself, where
## its doors and sconces are, and the rest across the corners). Each corner
## face is coursed blocks of the style's stone, drawn; the stone behind
## them is collision (prisms from the polygon to the corner).
static func round_room(b: TombBuild, pc: Dictionary, sides: int) -> void:
	var sides4 := maxi(sides / 4, 2) * 4
	var half := float(pc.half)
	var length := float(pc.len)
	var a := minf(half, length * 0.5)
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var c := b._at(pc, length * 0.5, 0.0)
	var y0 := float(pc.y0)
	var y1 := y0 + float(pc.h)
	var step := TAU / float(sides4)
	var edge := 2.0 * a * tan(step * 0.5)
	var r_v := a / cos(step * 0.5)
	var per_q := sides4 / 4
	var courses := maxi(int(ceil((y1 - y0) / 0.5)), 1)
	var ch := (y1 - y0) / courses
	var was_solid := b.solid
	var was_foot := b.foot_y
	b._stone_mode()
	b.solid = false
	for k in sides4:
		if k % per_q == 0:
			continue
		var phi := step * k
		var n := u * cos(phi) + v * sin(phi)
		var t := Vector3.UP.cross(n)
		var bs := Basis(t, Vector3.UP, n)
		var mid := c + n * (a + 0.2)
		for q in courses:
			b.foot_y = y0 + ch * q
			var cuts: Array = [0.0, 0.5, 1.0] if q % 2 == 0 else [0.0, 0.25, 0.75, 1.0]
			for i in cuts.size() - 1:
				var s0 := (float(cuts[i]) - 0.5) * edge
				var s1 := (float(cuts[i + 1]) - 0.5) * edge
				var p := mid + t * ((s0 + s1) * 0.5) + Vector3.UP * (y0 + ch * (q + 0.5) - c.y)
				b.box(Transform3D(bs, p), Vector3(s1 - s0 - 0.012, ch - 0.012, 0.4), RuinStyle.stone(b.rng), b._growth(0.06), 0.035, 0.012)
	b.solid = was_solid
	b.foot_y = was_foot
	# The stone behind the faces: in each corner, a prism under each corner
	# face (from its two vertices to the corner), and one each side where
	# the polygon leaves the wall.
	var far := a + 0.3
	for sa: float in [-1.0, 1.0]:
		for sc: float in [-1.0, 1.0]:
			var corner := _w(c, u, v, sa * far, sc * far)
			for j in per_q:
				var q0 := Vector2(cos(step * (j + 0.5)), sin(step * (j + 0.5))) * r_v
				var q1 := Vector2(cos(step * (j + 1.5)), sin(step * (j + 1.5))) * r_v
				if j < per_q - 1:
					b._prism(PackedVector2Array([_w(c, u, v, sa * q0.x, sc * q0.y), _w(c, u, v, sa * q1.x, sc * q1.y), corner]), y0, y1)
			var e0 := Vector2(cos(step * 0.5), sin(step * 0.5)) * r_v
			var e1 := Vector2(cos(step * (per_q - 0.5)), sin(step * (per_q - 0.5))) * r_v
			b._prism(PackedVector2Array([_w(c, u, v, sa * e0.x, sc * e0.y), _w(c, u, v, sa * far, sc * e0.y), corner]), y0, y1)
			b._prism(PackedVector2Array([_w(c, u, v, sa * e1.x, sc * e1.y), _w(c, u, v, sa * e1.x, sc * far), corner]), y0, y1)


## A point `x` along and `y` across from `c` (on axes `u`, `v`), on the
## ground plane (x, z).
static func _w(c: Vector3, u: Vector3, v: Vector3, x: float, y: float) -> Vector2:
	var p := c + u * x + v * y
	return Vector2(p.x, p.z)


## The round chamber's corner faces, for the checks: the polygon's inside
## (its apothem, m) and how many faces, or {} for a room that isn't round.
static func round_of(pc: Dictionary) -> Dictionary:
	var shape: Dictionary = RoomPool.archetype(str(pc.get("big_room", ""))).get("shape", {})
	if str(shape.get("kind", "")) != "round":
		return {}
	return {"apothem": minf(float(pc.half), float(pc.len) * 0.5), "sides": maxi(int(shape.get("sides", 12)) / 4, 2) * 4}


## A drum of stone (a polygon of `sides`, its faces `r` from its middle),
## standing on `base` from its foot up `h`: a block on each face, `depth`
## deep (its whole radius by default), drawn; its collision a prism when
## `solid`. `col` its stone (a Color), or null for the style's, stone by
## stone.
static func _drum(b: TombBuild, base: Vector3, r: float, h: float, sides: int, solid: bool, col: Variant = null, depth := -1.0) -> void:
	var step := TAU / float(sides)
	var edge := 2.0 * r * tan(step * 0.5)
	var d := r if depth <= 0.0 else minf(depth, r)
	var was_solid := b.solid
	b.solid = false
	for k in sides:
		var phi := step * k
		var n := Vector3(cos(phi), 0.0, sin(phi))
		var t := Vector3.UP.cross(n)
		var cc: Color = col if col is Color else RuinStyle.stone(b.rng)
		b.box(Transform3D(Basis(t, Vector3.UP, n), base + n * (r - d * 0.5) + Vector3.UP * (h * 0.5)), Vector3(edge + 0.01, h, d), cc, b._growth(0.04), 0.025, 0.006)
	b.solid = was_solid
	if solid:
		var poly := PackedVector2Array()
		var rv := r / cos(step * 0.5)
		for k in sides:
			var phi := step * (k + 0.5)
			poly.append(Vector2(base.x + cos(phi) * rv, base.z + sin(phi) * rv))
		b._prism(poly, base.y, base.y + h)


## The round sacrificial stone (temalacatl) in the blood altar's middle: a
## low drum (radius_m, high_m) with a carved ring round its rim and another
## at its foot, and on its top the stain, dried near-black brown (stain;
## never bright red: fire is the one warm accent), a drip of it down the
## side toward the bowl. It lies on the stone (rule.on_top). No bodies
## (aztec_temple.json chambers.blood_altar no_gore).
static func altar_drum(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var r := float(sd.get("radius_m", 0.8))
	var h := float(sd.get("high_m", 0.55))
	var p := b._at(pc, float(sd.get("along_m", float(pc.len) * 0.5)), float(sd.get("across_m", 0.0)))
	b._stone_mode()
	var was_foot := b.foot_y
	b.foot_y = p.y
	_drum(b, p, r, h, 16, true)
	_drum(b, p + Vector3.UP * (h - 0.16), r + 0.035, 0.08, 16, false, RuinStyle.stone(b.rng), 0.12)
	_drum(b, p, r + 0.05, 0.07, 16, false, RuinStyle.stone(b.rng), 0.12)
	b.foot_y = was_foot
	var stain := Color(str(sd.get("stain", "#2b1a14")))
	b._other_mode()
	var was_solid := b.solid
	b.solid = false
	var top := p + Vector3.UP * (h + 0.006)
	for k in 3:
		var rot := Basis(Vector3.UP, k * PI / 3.0 + b.rng.randf_range(-0.2, 0.2))
		b.box(Transform3D(rot, top + rot * Vector3(r * 0.08, 0.0, 0.0)), Vector3(r * 0.95, 0.012, r * 0.95), stain, 0.0, 0.0, 0.0)
	var side: Vector3 = -(TombBuild._axes(pc)[1] as Vector3)
	b.box(Transform3D(Basis(Vector3.UP.cross(side).normalized(), Vector3.UP, side), p + side * (r + 0.004) + Vector3.UP * (h * 0.62)), Vector3(0.16, h * 0.7, 0.012), stain, 0.0, 0.0, 0.0)
	b.solid = was_solid
	b._stone_mode()


## A stone bowl (cuauhxicalli) beside the altar: a short drum, its hollow
## cut dark in its top (toward navy, §ES), across_m off the middle line on
## the drip's side.
static func bowl(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var r := float(sd.get("radius_m", 0.32))
	var h := float(sd.get("high_m", 0.42))
	var p := b._at(pc, float(sd.get("along_m", float(pc.len) * 0.5)), -float(sd.get("across_m", 1.5)))
	b._stone_mode()
	var was_foot := b.foot_y
	b.foot_y = p.y
	var col := RuinStyle.stone(b.rng)
	_drum(b, p, r, h, 10, true, col)
	b.foot_y = was_foot
	var cut: Color = col if TombBuild.bare else Prelit.ao_tint(col, 0.3)
	var was_solid := b.solid
	b.solid = false
	b.box(Transform3D(Basis.IDENTITY, p + Vector3.UP * (h + 0.003)), Vector3(r * 1.3, 0.008, r * 1.3), cut, 0.0, 0.0, 0.0)
	b.solid = was_solid


## Offerings round the altar's foot (as the Templo Mayor's were: small
## carved stones and figures, count of them), the style's stone, drawn only.
static func offerings(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var p := b._at(pc, float(sd.get("along_m", float(pc.len) * 0.5)), 0.0)
	var r0 := 0.8
	for st in RoomPool.archetype(str(pc.big_room)).get("stands", []):
		if str((st as Dictionary).get("kind", "")) == "altar_drum":
			r0 = float((st as Dictionary).get("radius_m", 0.8))
	var was_solid := b.solid
	var was_foot := b.foot_y
	b.solid = false
	b.foot_y = p.y
	b._stone_mode()
	for i in int(sd.get("count", 9)):
		var ang := b.rng.randf_range(0.0, TAU)
		var dist := r0 + b.rng.randf_range(0.18, 0.5)
		var sz := Vector3(b.rng.randf_range(0.07, 0.16), b.rng.randf_range(0.06, 0.2), b.rng.randf_range(0.07, 0.14))
		var q := p + Vector3(cos(ang), 0.0, sin(ang)) * dist + Vector3.UP * (sz.y * 0.5)
		b.box(Transform3D(Basis(Vector3.UP, b.rng.randf_range(0.0, TAU)), q), sz, RuinStyle.stone(b.rng), 0.0, 0.015, 0.006)
	b.solid = was_solid
	b.foot_y = was_foot


## The tonalpohualli (aztec_temple.json calendar.day_signs, in order): a
## panel for each of the 20 day signs, carved in relief on `walls`
## (per_row a row, rows_up_m their middles over the floor, panel_m [wide,
## high]), each with its sign's glyph over its day's number in dots (the
## count's first twenty days: 1 to 13, then 1 to 7 again). Flavour, nothing
## to operate. Drawn only. Returns how many panels it carved.
static func day_signs(b: TombBuild, pc: Dictionary, sd: Dictionary) -> int:
	var signs: Array = (Tuning.table("aztec_temple").get("calendar", {}) as Dictionary).get("day_signs", [])
	var walls: Array = sd.get("walls", ["left", "right"])
	var per_row := maxi(int(sd.get("per_row", 5)), 1)
	var rows: Array = sd.get("rows_up_m", [2.15, 1.05])
	var size: Array = sd.get("panel_m", [0.95, 0.95])
	var length := float(pc.len)
	var was_solid := b.solid
	var was_plain := b.plain
	b.solid = false
	b._stone_mode()
	var i := 0
	for w in walls:
		for row in rows:
			for k in per_row:
				if i >= signs.size():
					break
				var off := length * float(k + 1) / float(per_row + 1) - length * 0.5
				var fp := TombKit.face_point(pc, str(w), off)
				var at: Vector2 = fp[0]
				var nv: Vector2 = fp[1]
				var n := Vector3(nv.x, 0.0, nv.y)
				var t := Vector3.UP.cross(n).normalized()
				var y := Delves.floor_of(pc, Delves.along_across(pc, at).x) + float(row)
				_panel(b, Vector3(at.x, y, at.y), t, n, float(size[0]), float(size[1]), int((signs[i] as Dictionary).get("n", i + 1)), i % 13 + 1)
				i += 1
	b.solid = was_solid
	b.plain = was_plain
	return i


## The day signs a calendar room carves: [{"sign" (1-20), "dots" (1-13)}]
## in the order they are laid (the checks).
static func calendar_plan(pc: Dictionary) -> Array:
	var out: Array = []
	for st in RoomPool.archetype(str(pc.get("big_room", ""))).get("stands", []):
		var sd: Dictionary = st
		if str(sd.get("kind", "")) != "day_signs":
			continue
		var signs: Array = (Tuning.table("aztec_temple").get("calendar", {}) as Dictionary).get("day_signs", [])
		var slots := (sd.get("walls", []) as Array).size() * (sd.get("rows_up_m", []) as Array).size() * maxi(int(sd.get("per_row", 5)), 1)
		for i in mini(slots, signs.size()):
			out.append({"sign": int((signs[i] as Dictionary).get("n", i + 1)), "dots": i % 13 + 1})
	return out


## One day-sign panel at `o` (its middle on the wall's face, `n` out of the
## wall, `t` along it): a slab standing proud, a raised frame round a field
## cut back (toward navy), the sign's glyph (raised blocks on a 5 x 5 grid
## mirrored across its middle, drawn on the sign's own number) over a row
## of `dots` raised dots.
static func _panel(b: TombBuild, o: Vector3, t: Vector3, n: Vector3, pw: float, ph: float, sign_n: int, dots: int) -> void:
	var bs := Basis(t, Vector3.UP, n)
	var col := RuinStyle.stone(b.rng)
	var cut: Color = col if TombBuild.bare else Prelit.ao_tint(col, 0.2)
	# The slab, 0.1 m proud of the wall's face (clear of its stones' relief).
	b.plain = false
	b.box(Transform3D(bs, o + n * 0.04), Vector3(pw, ph, 0.12), col, 0.0, 0.025, 0.006)
	b.plain = true
	var face := o + n * 0.1
	var fw := 0.06
	# The frame, 4 cm proud of the slab; the field inside it cut back dark.
	b.box(Transform3D(bs, face + n * 0.02 + Vector3.UP * (ph * 0.5 - fw * 0.5)), Vector3(pw, fw, 0.04), col, 0.0)
	b.box(Transform3D(bs, face + n * 0.02 - Vector3.UP * (ph * 0.5 - fw * 0.5)), Vector3(pw, fw, 0.04), col, 0.0)
	for sg: float in [-1.0, 1.0]:
		b.box(Transform3D(bs, face + n * 0.02 + t * sg * (pw * 0.5 - fw * 0.5)), Vector3(fw, ph - 2.0 * fw, 0.04), col, 0.0)
	b.box(Transform3D(bs, face + n * 0.004), Vector3(pw - 2.0 * fw, ph - 2.0 * fw, 0.008), cut, 0.0)
	# The glyph: raised blocks on a 5 x 5 grid, mirrored across its middle,
	# on the sign's own dice, 5 cm proud of the field.
	var g := RandomNumberGenerator.new()
	g.seed = hash(["day sign", sign_n])
	var cell := (pw - 2.0 * fw) * 0.75 / 5.0
	var gy := ph * 0.1
	for row in 5:
		for colm in 3:
			if g.randf() < 0.55 or (row == 2 and colm == 2):
				var mirror: Array = [1.0] if colm == 2 else [-1.0, 1.0]
				for sg: float in mirror:
					var x := (float(colm) - 2.0) * cell * sg
					var yy := gy + (2.0 - float(row)) * cell
					b.box(Transform3D(bs, face + n * 0.025 + t * x + Vector3.UP * yy), Vector3(cell * 0.9, cell * 0.9, 0.05), col, 0.0)
	# The day's number in dots, a row under the glyph.
	var dot := 0.05
	var gap := minf((pw - 2.0 * fw - 0.04) / 13.0, 0.075)
	var dy := -ph * 0.5 + fw + 0.1
	for k in dots:
		var x := (float(k) - (dots - 1) * 0.5) * gap
		b.box(Transform3D(bs, face + n * 0.02 + t * x + Vector3.UP * dy), Vector3(dot, dot, 0.04), col, 0.0)
	b.plain = false

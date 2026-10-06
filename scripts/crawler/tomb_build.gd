class_name TombBuild
extends RuinBuilder
## Draws a tomb (TombKit.layout) in the ruins' own stone (design 6 Oct
## §ET.5, §ES: RuinBuilder's dry-stone blocks, flagstones and slabs, the
## same bevels, wear and moss as every ruin on the surface): each room
## four walls with its doors cut through, a paved floor and a slab
## ceiling; each corridor two walls; each flight of stairs RuinBuilder's
## delve stair (steps over a ramp, a stepped ceiling); every door a
## threshold flag and a lintel. Then each room's kind (§CJ.8's kit):
##
##   hearth     the smoke shaft over the hearth (§ET.6: every hearth's
##              smoke leaves by an airway), a reed mat where you wake
##   crypt      stone coffins in rows along the walls, lids askew
##   catacomb   bone niches: shelves down both long walls, the dead's
##              bones and skulls on them
##   ossuary    bones heaped in the corners
##   collapsed  a ceiling slab come down in one corner, and its rubble
##   heart      the deepest room (§CJ.3): ochre on the ceiling, the dead's
##              goods, and at its end the mossy stone box with a skeleton
##              leaning out of it (Mike's frame 9)
##
## and the airways' carved surrounds (§ET.6). Flat: the tomb is its own
## world, the hearth room's floor at y 0 (no planet under it). Pure; the
## arrays come back for CrawlerMain to make into a mesh and collision.

## The floor under what is being dressed (RuinBuilder.ground() for its
## rubble and goods): the tomb has no ground but its floors.
var _floor := 0.0
var _lay: Dictionary = {}


func ground(_x: float, _z: float) -> float:
	return _floor


func surface(_x: float, _z: float) -> float:
	return _floor


## The tomb's geometry: RuinBuilder's arrays ({"v", "n", "c", "m", "cv",
## "ch"}; local is scene, the tomb at the origin), and "shaft_top" (the
## smoke shaft's mouth over the hearth).
static func build(lay: Dictionary) -> Dictionary:
	var b := TombBuild.new()
	b._lay = lay
	b.rng.seed = hash([int(lay.seed), "stone"])
	b.up = Vector3.UP
	b.ex = Vector3.RIGHT
	b.ez = Vector3.BACK
	# Damp: the tombs are deep and still (crawler.json themes.tomb).
	b.wet = 0.75
	for pc in lay.pieces:
		match str(pc.kind):
			"room":
				b._room(pc)
			"corridor":
				b._corridor(pc)
			"stair":
				b._delve_stair(pc, 0.0, false, 0.0, 0.0)
	for d in lay.doors:
		b._doorway(d)
	for pc in lay.pieces:
		if str(pc.kind) == "room":
			b._floor = float(pc.y0)
			b._dress(pc)
	for a in lay.airways:
		b._airway_surround(a)
	return {"v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch}


## Door gaps on each wall of `pc`: side -> [[offset, half]] (offsets as
## _dwall_gaps wants them: along for the side walls, across for the ends).
func _gaps(pc: Dictionary) -> Dictionary:
	var gaps := {"start": [], "end": [], "left": [], "right": []}
	for di in pc.doors:
		var d: Dictionary = _lay.doors[di]
		var s: Array = TombKit.door_side(pc, d)
		var off := float(s[1])
		if str(s[0]) in ["left", "right"]:
			off += float(pc.len) * 0.5
		(gaps[s[0]] as Array).append([off, float(d.half) + 0.05])
	return gaps


func _room(pc: Dictionary) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var hw := half + Delves.WALL * 0.5
	var top := y + h + Delves.SLAB
	var gaps := _gaps(pc)
	_dwall_gaps(pc, hw, -Delves.WALL, length + Delves.WALL, gaps.left, y - 0.6, top, true)
	_dwall_gaps(pc, -hw, -Delves.WALL, length + Delves.WALL, gaps.right, y - 0.6, top, true)
	_dwall_gaps(pc, -Delves.WALL * 0.5, -half, half, gaps.start, y - 0.6, top, false)
	_dwall_gaps(pc, length + Delves.WALL * 0.5, -half, half, gaps.end, y - 0.6, top, false)
	# The ceiling: slabs across, ochre in the heart (§BQ); the hearth
	# room's has the smoke shaft's mouth in its middle.
	var ochre := str(pc.get("room_kind", "")) == "heart"
	var hole := Rect2()
	if str(pc.get("room_kind", "")) == "hearth":
		hole = Rect2(-0.7, -0.7, 1.4, 1.4)
		_shaft(Vector2.ZERO, 0.7, y + h, 4.5)
	var n := maxi(1, int(ceil(length / 1.5)))
	var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
	var pv := Delves.perp(pc.dir)
	var bs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, d3).orthonormalized()
	for i in n:
		var a0 := length * i / n
		var a1 := length * (i + 1) / n
		var col: Color = palette[rng.randi() % palette.size()]
		if ochre:
			col = col.lerp(Color(0.62, 0.3, 0.14), 0.55)
		var w := 2.0 * (half + Delves.WALL) + 0.1
		# Cut round the shaft: the slab in pieces either side of the hole.
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		var slab_r := Rect2(mid - Vector2(w, a1 - a0) * 0.5, Vector2(w, a1 - a0)) if absf(d3.z) > 0.5 else Rect2(mid - Vector2(a1 - a0, w) * 0.5, Vector2(a1 - a0, w))
		if hole.has_area() and slab_r.intersects(hole):
			for part in _minus(slab_r, hole):
				var r: Rect2 = part
				box(Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, y + h + Delves.SLAB * 0.5, r.get_center().y)), Vector3(r.size.x, Delves.SLAB, r.size.y), col.darkened(0.1), 0.0, 0.08, 0.03)
			continue
		box(Transform3D(bs, Vector3(mid.x, y + h + Delves.SLAB * 0.5, mid.y)), Vector3(w, Delves.SLAB, a1 - a0 + 0.05), col.darkened(0.1), 0.0, 0.08, 0.03)
	_pave(Delves.rect_of(pc, 0.05), y)


## Rectangle `r` less `cut` (axis-aligned, `cut` inside `r` or across it):
## up to four pieces.
static func _minus(r: Rect2, cut: Rect2) -> Array:
	var out: Array = []
	var c := r.intersection(cut)
	if not c.has_area():
		return [r]
	if c.position.x > r.position.x:
		out.append(Rect2(r.position.x, r.position.y, c.position.x - r.position.x, r.size.y))
	if c.end.x < r.end.x:
		out.append(Rect2(c.end.x, r.position.y, r.end.x - c.end.x, r.size.y))
	if c.position.y > r.position.y:
		out.append(Rect2(c.position.x, r.position.y, c.size.x, c.position.y - r.position.y))
	if c.end.y < r.end.y:
		out.append(Rect2(c.position.x, c.end.y, c.size.x, r.end.y - c.end.y))
	return out


## The smoke shaft (§ET.6): a square flue `inner` m half wide from the
## ceiling at `y` up `rise` m, open at the top, into the dark.
func _shaft(c: Vector2, inner: float, y: float, rise: float) -> void:
	var t := 0.4
	var o := inner + t * 0.5
	for k in 4:
		var horiz := k < 2
		var s := 1.0 if k % 2 == 0 else -1.0
		var p := c + (Vector2(0.0, s * o) if horiz else Vector2(s * o, 0.0))
		var size := Vector3(2.0 * (inner + t), rise, t) if horiz else Vector3(t, rise, 2.0 * inner)
		box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + rise * 0.5, p.y)), size, palette[k % palette.size()].darkened(0.15), 0.0, 0.06, 0.03)


func _corridor(pc: Dictionary) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var hw := half + Delves.WALL * 0.5
	var top := y + h + Delves.SLAB
	for sd: float in [-1.0, 1.0]:
		_dwall(_pp(pc, 0.0, sd * hw), _pp(pc, length, sd * hw), y - 0.6, top)
	var n := maxi(1, int(ceil(length / 1.4)))
	var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
	var pv := Delves.perp(pc.dir)
	var bs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, d3).orthonormalized()
	for i in n:
		var a0 := length * i / n
		var a1 := length * (i + 1) / n
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		box(Transform3D(bs, Vector3(mid.x, y + h + Delves.SLAB * 0.5, mid.y)), Vector3(2.0 * (half + Delves.WALL) + 0.1, Delves.SLAB, a1 - a0 + 0.05), (palette[rng.randi() % palette.size()] as Color).darkened(0.1), 0.0, 0.08, 0.03)
	_pave(Delves.rect_of(pc, 0.05), y)


## A door through a wall: the threshold flag across the wall's thickness
## and the lintel over the opening, up to the taller side's wall top.
func _doorway(d: Dictionary) -> void:
	var p: Vector2 = d.p
	var nv: Vector2 = d.n
	var half := float(d.half)
	var y := float(d.y)
	var a: Dictionary = _lay.pieces[int(d.a)]
	var b: Dictionary = _lay.pieces[int(d.b)]
	var top := maxf(float(a.y0) + float(a.h), float(b.y0) + float(b.h)) + Delves.SLAB
	top = maxf(top, maxf(float(a.y1) + float(a.h), float(b.y1) + float(b.h)) + Delves.SLAB)
	var along_n := absf(nv.x) > 0.5
	var size2 := Vector2(Delves.WALL + 0.12, 2.0 * half + 0.1) if along_n else Vector2(2.0 * half + 0.1, Delves.WALL + 0.12)
	_pave(Rect2(p - size2 * 0.5, size2), y)
	var lb := y + float(d.h)
	if top > lb + 0.1:
		var size3 := Vector3(size2.x, top - lb, size2.y)
		box(Transform3D(Basis.IDENTITY, Vector3(p.x, (lb + top) * 0.5, p.y)), size3, (palette[2] as Color).darkened(0.05), 0.0, 0.08, 0.03)


## A point in piece `pc` at (along, across), on its floor, as a Vector3.
func _at(pc: Dictionary, along: float, across: float, lift := 0.0) -> Vector3:
	var q := _pp(pc, along, across)
	return Vector3(q.x, Delves.floor_of(pc, along) + lift, q.y)


## Is (along) on a side wall of `pc` near a door on that side?
func _near_door(pc: Dictionary, side: String, along: float, within: float) -> bool:
	for di in pc.doors:
		var s: Array = TombKit.door_side(pc, _lay.doors[di])
		if str(s[0]) == side and absf(float(s[1]) + float(pc.len) * 0.5 - along) < within:
			return true
	return false


## Is (along) near an airway on that side of `pc`?
func _near_airway(pc: Dictionary, sd: float, along: float, within: float) -> bool:
	for a in _lay.airways:
		if int(a.piece) != int(pc.id):
			continue
		var aa := Delves.along_across(pc, Vector2((a.pos as Vector3).x, (a.pos as Vector3).z))
		if signf(aa.y) == sd and absf(aa.x - along) < within:
			return true
	return false


func _dress(pc: Dictionary) -> void:
	var half := float(pc.half)
	var length := float(pc.len)
	var pv := Delves.perp(pc.dir)
	match str(pc.get("room_kind", "")):
		"hearth":
			# The mat you wake on (§ET.3): woven reeds, flat on the floor.
			var w: Array = _lay.get("wake", [Vector3.ZERO, 0.0])
			var wp: Vector3 = w[0]
			solid = false
			box(Transform3D(Basis(Vector3.UP, float(w[1])), wp + Vector3(0.0, 0.03, 0.0)), Vector3(0.9, 0.05, 1.9), THATCH.darkened(0.25), 0.0, 0.02, 0.01)
			solid = true
			# The rescuer's few things by the wall behind them: a water jar,
			# a bedroll.
			var r: Array = _lay.get("rescuer", [Vector3.ZERO, 0.0])
			var rp: Vector3 = r[0]
			var back := Vector3(rp.x, 0.0, rp.z).normalized() * 1.3
			boulder(rp + back + Vector3(0.0, 0.3, 0.0), Vector3(0.22, 0.3, 0.22), Basis.IDENTITY, CLAY, 0.0)
			solid = false
			box(Transform3D(Basis(Vector3.UP, float(r[1]) + 0.4), rp + back + Vector3(0.8, 0.12, 0.2)), Vector3(0.5, 0.24, 1.4), HIDE.darkened(0.2), 0.0, 0.06, 0.03)
			solid = true
		"crypt":
			if half < 2.4:
				return
			var yaw := atan2(pv.x, pv.y)
			for sd: float in [-1.0, 1.0]:
				var side := "left" if sd > 0.0 else "right"
				var a := 1.6
				while a < length - 1.4:
					if not _near_door(pc, side, a, 1.9) and not _near_airway(pc, sd, a, 1.4):
						_sarcophagus(_at(pc, a, sd * (half - 1.25)), yaw, palette[rng.randi() % palette.size()])
						if rng.randf() < 0.35:
							_grave_goods(_at(pc, a + 0.9, sd * (half - 2.3), 0.03), 0.3, 1)
					a += 2.4
		"catacomb":
			for sd: float in [-1.0, 1.0]:
				var side := "left" if sd > 0.0 else "right"
				var a := 1.0
				while a < length - 0.8:
					if not _near_door(pc, side, a, 1.5) and not _near_airway(pc, sd, a, 1.2):
						for k in 3:
							var sh := _at(pc, a, sd * (half - 0.22), 0.45 + 0.55 * k)
							box(Transform3D(Basis(Vector3.UP, atan2(pv.x, pv.y)), sh), Vector3(1.1, 0.1, 0.44), palette[1], _growth(0.15), 0.03, 0.01)
							if rng.randf() < 0.7:
								_grave_goods(sh + Vector3(0.0, 0.06, 0.0), 0.15, 1)
					a += 1.4
		"ossuary":
			for k in 4:
				var ca := 0.9 if k < 2 else length - 0.9
				var cs := (half - 0.9) * (1.0 if k % 2 == 0 else -1.0)
				var side := "left" if cs > 0.0 else "right"
				if _near_door(pc, side, ca, 1.8):
					continue
				_grave_goods(_at(pc, ca, cs, 0.03), 0.6, 6)
		"collapsed":
			# The corner farthest from the doors.
			var best := Vector2(length * 0.8, half * 0.6)
			var best_d := -INF
			for k in 4:
				var q := Vector2(length * (0.22 if k < 2 else 0.78), half * (0.6 if k % 2 == 0 else -0.6))
				var dmin := INF
				for di in pc.doors:
					var d: Dictionary = _lay.doors[di]
					dmin = minf(dmin, (Delves.along_across(pc, d.p) - q).length())
				if dmin > best_d:
					best_d = dmin
					best = q
			var p := _at(pc, best.x, best.y)
			box(Transform3D(Basis.from_euler(Vector3(0.45, rng.randf() * TAU, 0.2)), p + Vector3(0.0, 0.8, 0.0)), Vector3(2.6, 0.45, 1.5), palette[2], _growth(0.4), 0.12, 0.08)
			rubble(p, 1.4, 6)
		"heart":
			var yaw := atan2((pc.dir as Vector2).x, (pc.dir as Vector2).y) + PI * 0.5
			_heart_box(_at(pc, length - 1.6, 0.0), yaw)
			_grave_goods(_at(pc, length * 0.35, 0.0, 0.03), 1.4, 6)


## The heart's coffin (Mike's frame 9): a mossy stone box, its lid shoved
## half off, the one buried there leaning out over its side: skull, ribs,
## an arm hanging down the stone.
func _heart_box(p: Vector3, yaw: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var col: Color = palette[3]
	box(Transform3D(bs, p + Vector3(0.0, 0.5, 0.0)), Vector3(1.05, 1.0, 2.3), col.darkened(0.05), 0.75, 0.08, 0.03)
	# The lid, shoved off one side and down against the box.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.12, 0.42)), p + bs * Vector3(-0.85, 0.72, 0.15)), Vector3(1.1, 0.18, 2.35), col.lightened(0.04), 0.85, 0.06, 0.02)
	solid = false
	# The skeleton: ribs leaning out over the rim, the skull past them, an
	# arm down the outside.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.42, 1.1, 0.55)), Vector3(0.38, 0.14, 0.3), BONE, 0.0, 0.03, 0.01)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.38, 1.12, 0.22)), Vector3(0.34, 0.08, 0.12), BONE.darkened(0.05), 0.0, 0.02, 0.01)
	boulder(p + bs * Vector3(0.72, 1.02, 0.62), Vector3(0.12, 0.13, 0.15), bs, BONE, 0.0)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, 0.15)), p + bs * Vector3(0.6, 0.62, 0.35)), Vector3(0.05, 0.62, 0.05), BONE, 0.0, 0.015, 0.005)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.3, 0.0, 0.1)), p + bs * Vector3(0.62, 0.22, 0.42)), Vector3(0.05, 0.3, 0.05), BONE, 0.0, 0.015, 0.005)
	solid = true


## An airway's carved surround (§ET.6): a slot in the wall's face with
## stones round it; a strong mouth's bigger, with a lintel stone carved
## with a mark (two notches), so it reads as a marked mouth.
func _airway_surround(a: Dictionary) -> void:
	var nrm: Vector3 = a.normal
	var pos: Vector3 = a.pos
	var strong := bool(a.strong)
	var w := 0.9 if strong else 0.5
	var h := 0.6 if strong else 0.25
	var t := 0.18
	var right := Vector3.UP.cross(nrm).normalized()
	var bs := Basis(right, Vector3.UP, nrm)
	var c := pos + nrm * 0.06
	var col: Color = (palette[2] as Color).lightened(0.06)
	solid = false
	for sd: float in [-1.0, 1.0]:
		box(Transform3D(bs, c + right * sd * (w * 0.5 + t * 0.5)), Vector3(t, h + 2.0 * t, 0.16), col, 0.0, 0.04, 0.02)
		box(Transform3D(bs, c + Vector3.UP * sd * (h * 0.5 + t * 0.5)), Vector3(w, t, 0.16), col, 0.0, 0.04, 0.02)
	if strong:
		# The mark: two notches cut in the lintel, darker.
		for k: float in [-0.15, 0.15]:
			box(Transform3D(bs, c + Vector3.UP * (h * 0.5 + t * 0.5) + right * k + nrm * 0.08), Vector3(0.05, t * 0.7, 0.02), col.darkened(0.6), 0.0, 0.0, 0.0)
	solid = true

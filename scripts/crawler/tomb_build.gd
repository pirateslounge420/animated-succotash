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
##   heart      the spine's last room (§CJ.3): ochre on the ceiling, the
##              dead's goods, and toward its far end the mossy stone box
##              with a skeleton leaning out of it (Mike's frame 9), lying
##              across the room with the way out beyond it
##
## and the way out (§EX.5): the long flight up past the heart, the landing
## at its top, and in the landing's far wall the opening, its threshold
## stone running on into a strip of floor outside, closed beyond the
## daylight (WayOut) so nobody walks off the world. The heart's dead lie
## TombKit.HEART_BOX_M in from its far wall, their goods before them, so
## the walk goes round them to the way out's door behind them.
## The airways' carved surrounds (§ET.6). Flat: the tomb is its own world,
## the hearth room's floor at y 0 (no planet under it). Pure; the arrays
## come back for CrawlerMain to make into a mesh and collision.
##
## Where a skeleton rests (TombKit residents, design §FE) its place is
## drawn for it: a crypt coffin open, its lid shoved off onto the floor; a
## catacomb niche framed with jambs and a lintel, its middle shelf gone;
## the heart's box hollow. The skeleton itself is a sprite (Residents).

## The floor under what is being dressed (RuinBuilder.ground() for its
## rubble and goods): the tomb has no ground but its floors.
var _floor := 0.0
var _lay: Dictionary = {}
## The masonry's own seed (masonry.json seed; 0: from the tomb's).
var _mseed := 0
## How far a flight's walked slope rides over its steps' line (RuinBuilder.
## ramp_lift): over a threshold's overhang at the top of the steepest
## flight (6 cm at the kit's slope, 0.6) and its stone's settle.
const RAMP_LIFT_M := 0.05
## Fitted stones laid and wall faces dressed (checks).
var stones := 0
var faces := 0
## Every dressed wall face, for what lives on the stone (design §FG:
## GlowMoss, WallLife): {"o" (the face's plane at y 0), "u" (along it),
## "n" (out of it, into the tomb), "length", "y0", "y1" (the stones'
## span), "floor_y", "seed" (its stones' own seed: FittedStone.cells with
## an RNG seeded so gives its stones again), "probe" (a point in front of
## its middle, on the floor), "cells" (its stones' polygons in (along, up
## from y0): where its joints run), "heights" (each stone's face off the
## wall's face: Vector2(rim, pillowed middle))}.
var wall_faces: Array = []
## Coffins laid in the crypts and bone-niche bays in the catacombs (checks).
var coffins := 0
var niches := 0
## The collision alone (build's collision_only).
var _collision_only := false


func ground(_x: float, _z: float) -> float:
	return _floor


func surface(_x: float, _z: float) -> float:
	return _floor


## The tomb's geometry: RuinBuilder's arrays ({"v", "n", "c", "m", "cv",
## "ch"}; local is scene, the tomb at the origin), and "shaft_top" (the
## smoke shaft's mouth over the hearth). `collision_only` (the checks'
## walks): the fitted stones' faces and the soot, which are drawn only and
## never touch the builder's own dice (FittedStone.face), are left out, so
## the collision ("cv", "ch") is the game's exactly.
static func build(lay: Dictionary, collision_only := false) -> Dictionary:
	var b := TombBuild.new()
	b._lay = lay
	b._collision_only = collision_only
	b.rng.seed = hash([int(lay.seed), "stone"])
	b.up = Vector3.UP
	b.ex = Vector3.RIGHT
	b.ez = Vector3.BACK
	# Every flight walkable both ways (§EX.5: the way out climbs one): its
	# slope rides a little over the steps' line, so the threshold stone
	# at the top of a steep flight is never a lip to climb.
	b.ramp_lift = RAMP_LIFT_M
	# Damp: the tombs are deep and still (crawler.json themes.tomb).
	b.wet = 0.75
	# The walls' masonry: the preset and climate by the tomb's theme.
	FittedStone.theme = str(lay.get("theme", "tomb"))
	var ms := int(FittedStone.M.get("seed", 0))
	b._mseed = ms if ms != 0 else hash([int(lay.seed), "masonry"])
	for pc in lay.pieces:
		match str(pc.kind):
			"room", "landing":
				b._room(pc)
			"corridor":
				b._corridor(pc)
			"stair":
				b._delve_stair(pc, 0.0, false, 0.0, 0.0)
	for d in lay.doors:
		b._doorway(d)
	for v in lay.get("vents", []):
		b._flue(v)
	for pc in lay.pieces:
		if str(pc.kind) == "room":
			b._floor = float(pc.y0)
			b._dress(pc)
	if not (lay.get("lair", {}) as Dictionary).is_empty():
		b._lair_hole(lay.lair)
	for a in lay.airways:
		b._airway_surround(a)
	if not collision_only:
		b._soot(lay)
	return {"v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch, "stones": b.stones, "faces": b.faces, "walls": b.wall_faces, "coffins": b.coffins, "niches": b.niches}


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
	# The ceiling: slabs across, ochre in the heart (§BQ), cut round its
	# fires' flues (the vents rule, Vents).
	_ceiling(pc, str(pc.get("room_kind", "")) == "heart")
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


## Rectangle `r` less every one of `cuts`.
static func _minus_all(r: Rect2, cuts: Array) -> Array:
	var parts: Array = [r]
	for cut in cuts:
		var next: Array = []
		for q in parts:
			next.append_array(_minus(q, cut))
		parts = next
	return parts


## A piece's ceiling: slabs across it, `ochre` in the heart, cut round the
## mouths of its fires' flues (TombKit vents).
func _ceiling(pc: Dictionary, ochre: bool) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var holes: Array = []
	for v in _lay.get("vents", []):
		if int(v.piece) == int(pc.id):
			var m: Vector3 = v.mouth
			var r := float(v.d) * 0.5
			holes.append(Rect2(m.x - r, m.z - r, 2.0 * r, 2.0 * r))
	var n := maxi(1, int(ceil(length / 1.5)))
	var d3 := Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y)
	var pv := Delves.perp(pc.dir)
	var bs := Basis(Vector3(pv.x, 0.0, pv.y), Vector3.UP, d3).orthonormalized()
	var w := 2.0 * (half + Delves.WALL) + 0.1
	for i in n:
		var a0 := length * i / n
		var a1 := length * (i + 1) / n
		var col: Color = palette[rng.randi() % palette.size()]
		if ochre:
			col = col.lerp(Color(0.62, 0.3, 0.14), 0.55)
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		var span := a1 - a0 + 0.05
		var slab_r := Rect2(mid - Vector2(w, span) * 0.5, Vector2(w, span)) if absf(d3.z) > 0.5 else Rect2(mid - Vector2(span, w) * 0.5, Vector2(span, w))
		var cut := false
		for hole in holes:
			if slab_r.intersects(hole):
				cut = true
		if cut:
			for part in _minus_all(slab_r, holes):
				var r: Rect2 = part
				if r.size.x < 0.02 or r.size.y < 0.02:
					continue
				box(Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, y + h + Delves.SLAB * 0.5, r.get_center().y)), Vector3(r.size.x, Delves.SLAB, r.size.y), col.darkened(0.1), 0.0, 0.08, 0.03)
			continue
		box(Transform3D(bs, Vector3(mid.x, y + h + Delves.SLAB * 0.5, mid.y)), Vector3(w, Delves.SLAB, span), col.darkened(0.1), 0.0, 0.08, 0.03)


## A vent's flue (the vents rule): a square stone tube from the ceiling's
## top up to the surface, through each of its legs (a kink steps it
## sideways where something stood over the fire), open at the top.
func _flue(v: Dictionary) -> void:
	var r := float(v.d) * 0.5
	var legs: Array = v.legs
	for i in legs.size():
		var leg: Array = legs[i]
		var a: Vector3 = leg[0]
		var b2: Vector3 = leg[1]
		if absf(b2.y - a.y) > 0.01:
			_shaft(Vector2(a.x, a.z), r, a.y, b2.y - a.y)
		else:
			# A sideways step: a low passage between the two rises, roofed.
			var mid := (a + b2) * 0.5
			var along := Vector3(b2.x - a.x, 0.0, b2.z - a.z)
			var size := Vector3(absf(along.x) + 2.0 * r + 0.8, 0.4, absf(along.z) + 2.0 * r + 0.8)
			box(Transform3D(Basis.IDENTITY, mid + Vector3(0.0, 2.0 * r + 0.2, 0.0)), size, (palette[1] as Color).darkened(0.3), 0.0, 0.05, 0.02)
			box(Transform3D(Basis.IDENTITY, mid - Vector3(0.0, 0.2, 0.0)), size, (palette[1] as Color).darkened(0.3), 0.0, 0.05, 0.02)


## A fitted-stone wall (design §EU; FittedStone, masonry.json): a
## run of wall from a to b (x/z), y_bot to y_top, `thick` thick. Its core
## is one plain block (its ends the jambs at the doors), its collision a
## plain box; every face that looks into a piece of the tomb is dressed
## with fitted stones, overgrown as its climate allows.
func _dwall(a: Vector2, b2: Vector2, y_bot: float, y_top: float, thick: float = 0.6) -> void:
	var along := b2 - a
	var length := along.length()
	if length < 0.15 or y_top <= y_bot + 0.05:
		return
	var jd := float(FittedStone.relief().get("joint_depth_m", 0.06))
	var dir2 := along / length
	var u := Vector3(dir2.x, 0.0, dir2.y)
	var bs := Basis(u, Vector3.UP, u.cross(Vector3.UP))
	var mid2 := (a + b2) * 0.5
	var center := Vector3(mid2.x, (y_bot + y_top) * 0.5, mid2.y)
	var was_solid := solid
	solid = false
	plain = true
	var core_col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(0.08)
	box(Transform3D(bs, center), Vector3(length + 0.02, y_top - y_bot, maxf(thick - 2.0 * jd - 0.02, 0.1)), core_col, 0.0)
	plain = false
	solid = was_solid
	_collision_box(Transform3D(bs, center), Vector3(length * 0.5, (y_top - y_bot) * 0.5, thick * 0.5))
	if _collision_only:
		return
	var floor_y := y_bot + 0.6
	var y1 := y_top - Delves.SLAB + 0.05
	for sd: float in [-1.0, 1.0]:
		var n2 := Vector2(dir2.y, -dir2.x) * sd
		var probe := mid2 + n2 * (thick * 0.5 + 0.45)
		if not _looks_into(probe, floor_y + 1.0):
			continue
		var n := Vector3(n2.x, 0.0, n2.y)
		var o := Vector3(a.x, 0.0, a.y) + n * (thick * 0.5)
		var cl := FittedStone.climate_at(str(_lay.get("theme", "tomb")), int(_lay.seed), Vector3(probe.x, floor_y, probe.y))
		# Every wall face its own seed (partition.seed_per_face), so nothing
		# mirrors across a corridor.
		var mr := RandomNumberGenerator.new()
		mr.seed = hash([_mseed, snappedf(a.x, 0.01), snappedf(a.y, 0.01), snappedf(b2.x, 0.01), snappedf(b2.y, 0.01), sd, snappedf(y_bot, 0.01)])
		var laid := {}
		stones += FittedStone.face(self, o, u, n, length, floor_y - 0.1, y1, floor_y, cl, mr, laid)
		faces += 1
		wall_faces.append({"o": o, "u": u, "n": n, "length": length, "y0": floor_y - 0.1, "y1": y1, "floor_y": floor_y, "seed": mr.seed, "probe": Vector3(probe.x, floor_y, probe.y), "cells": laid.get("cells", []), "heights": laid.get("heights", PackedVector2Array())})


## Is (x/z) `p` at height `y` inside a piece of the tomb (a wall facing
## it is seen)?
func _looks_into(p: Vector2, y: float) -> bool:
	for pc in _lay.pieces:
		var aa := Delves.along_across(pc, p)
		if aa.x > -0.05 and aa.x < float(pc.len) + 0.05 and absf(aa.y) < float(pc.half) + 0.05:
			var fy := Delves.floor_of(pc, aa.x)
			if y > fy - 1.5 and y < fy + float(pc.h) + 1.5:
				return true
	return false


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
	_ceiling(pc, false)
	_pave(Delves.rect_of(pc, 0.05), y)


## A door through a wall: the threshold flag across the wall's thickness
## and the lintel over the opening, up to the taller side's wall top. A
## way out's opening (b -1, §EX.5) runs its threshold on outside.
func _doorway(d: Dictionary) -> void:
	var p: Vector2 = d.p
	var nv: Vector2 = d.n
	var half := float(d.half)
	var y := float(d.y)
	var a: Dictionary = _lay.pieces[int(d.a)]
	var b: Dictionary = _lay.pieces[int(d.b)] if int(d.b) >= 0 else a
	var top := maxf(float(a.y0) + float(a.h), float(b.y0) + float(b.h)) + Delves.SLAB
	top = maxf(top, maxf(float(a.y1) + float(a.h), float(b.y1) + float(b.h)) + Delves.SLAB)
	var along_n := absf(nv.x) > 0.5
	var size2 := Vector2(Delves.WALL + 0.12, 2.0 * half + 0.1) if along_n else Vector2(2.0 * half + 0.1, Delves.WALL + 0.12)
	_pave(Rect2(p - size2 * 0.5, size2), y)
	var lb := y + float(d.h)
	if top > lb + 0.1:
		var size3 := Vector3(size2.x, top - lb, size2.y)
		box(Transform3D(Basis.IDENTITY, Vector3(p.x, (lb + top) * 0.5, p.y)), size3, (palette[2] as Color).darkened(0.05), 0.0, 0.08, 0.03)
	if int(d.b) < 0:
		_outside(d, top)


## Beyond a way out's opening (design §EX.5): the floor runs on OUTSIDE_M
## past the wall under the daylight (WayOut hangs it OUTSIDE_M out), the
## wall's stone carried on out either side so the daylight's edges never
## show, and a stop past the daylight (collision only): stepping into the
## opening is the way out, so nobody walks on into nothing. Nothing roofs
## it: looking up the flight, your eye passes up through the opening, and
## it must meet the daylight there, not the underside of a stone.
const OUTSIDE_M := 1.2
## How far over the opening's head the daylight and its stone reach (m).
const OUTSIDE_UP_M := 2.0


func _outside(d: Dictionary, top: float) -> void:
	var p: Vector2 = d.p
	var nv: Vector2 = d.n
	var y := float(d.y)
	var half := float(d.half)
	var side := Delves.perp(nv)
	var wall := Delves.WALL * 0.5
	# The floor outside: from the wall's outer face past the daylight.
	var f0 := p + nv * wall
	var f1 := p + nv * (wall + OUTSIDE_M + 0.3)
	var fr := Rect2(f0 - side * (half + 0.9), Vector2.ZERO).expand(f0 + side * (half + 0.9)).expand(f1 - side * (half + 0.9)).expand(f1 + side * (half + 0.9))
	_pave(fr, y)
	# The opening's reveal: the wall's stone on out past the daylight,
	# either side of it, as high as the daylight reaches.
	var depth := OUTSIDE_M + 0.3
	var mid := p + nv * (wall + depth * 0.5)
	var u3 := Vector3(side.x, 0.0, side.y)
	var n3 := Vector3(nv.x, 0.0, nv.y)
	var bs := Basis(u3, Vector3.UP, n3)
	var col: Color = (palette[2] as Color).darkened(0.1)
	var up_to := maxf(top, y + float(d.h) + OUTSIDE_UP_M + 0.2)
	for sd: float in [-1.0, 1.0]:
		var c := mid + side * sd * (half + 0.05 + 0.45)
		box(Transform3D(bs, Vector3(c.x, (y - 0.3 + up_to) * 0.5, c.y)), Vector3(0.9, up_to - y + 0.3, depth), col, 0.0, 0.06, 0.02)
	# The stop, past the daylight.
	var s := p + nv * (wall + OUTSIDE_M + 0.15)
	_collision_box(Transform3D(bs, Vector3(s.x, y + 1.5, s.y)), Vector3(half + 0.2, 1.6, 0.1))


## A point in piece `pc` at (along, across), on its floor, as a Vector3.
func _at(pc: Dictionary, along: float, across: float, lift := 0.0) -> Vector3:
	var q := _pp(pc, along, across)
	return Vector3(q.x, Delves.floor_of(pc, along) + lift, q.y)


## Is (along) on a side wall of `pc` near a door on that side?
func _near_door(pc: Dictionary, side: String, along: float, within: float) -> bool:
	return TombKit.near_door(_lay, pc, side, along, within)


## The bay before each of a room's wall sconces (design §EX.4), kept clear
## of the clutter laid at random (a collapse's slab and rubble, bone heaps,
## grave goods) so you can always step up to it and swing the flame:
## BAY_HALF either side of it along its wall, BAY_DEEP out into the room
## (where you stand to swing at it, your body's width round that). Coffins
## and niches are laid in rows instead, set round the sconces
## (TombKit.coffin_spots, niche_spots).
const BAY_HALF := 0.65
const BAY_DEEP := 1.6


## How far grave goods reach past the spread they're laid in (RuinBuilder.
## _grave_goods: a second urn 0.45 m off the first, 0.2 m round).
const GOODS_REACH := 0.7


## Room `pc`'s sconce bays: Rect2s in its (along, across).
func _bays(pc: Dictionary) -> Array:
	var out: Array = []
	var dv: Vector2 = pc.dir
	var pv := Delves.perp(dv)
	for h in _lay.holders:
		if int(h.piece) != int(pc.id) or str(h.kind) != "sconce":
			continue
		var pos: Vector3 = h.pos
		var nrm: Vector3 = h.normal
		var aa := Delves.along_across(pc, Vector2(pos.x, pos.z))
		var n2 := Vector2(Vector2(nrm.x, nrm.z).dot(dv), Vector2(nrm.x, nrm.z).dot(pv))
		var t2 := Vector2(-n2.y, n2.x) * BAY_HALF
		out.append(Rect2(aa - t2, Vector2.ZERO).expand(aa + t2).expand(aa + n2 * BAY_DEEP - t2).expand(aa + n2 * BAY_DEEP + t2))
	return out


## Does `r` (room `pc`'s along, across) reach into one of `bays`?
static func _in_bay(bays: Array, r: Rect2) -> bool:
	for b in bays:
		if (b as Rect2).intersects(r):
			return true
	return false


func _dress(pc: Dictionary) -> void:
	var half := float(pc.half)
	var length := float(pc.len)
	var pv := Delves.perp(pc.dir)
	var bays := _bays(pc)
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
			# The low stone they sit on by the fire (§FH, HearthFolk), the
			# room's own stone, as the rest of its dressing.
			var seat := HearthFolk.seat(rp, float(r[1]))
			box(seat.xf, seat.size, (palette[2] as Color).darkened(0.05), 0.0, 0.04, 0.02)
		"crypt":
			# The coffins (TombKit.coffin_spots); one a skeleton rests in
			# lies open (residents, §FE).
			var yaw := atan2(pv.x, pv.y)
			for s in TombKit.coffin_spots(_lay, pc):
				# The boss's lair is where this one stood (TombKit.lair_took):
				# it fell through with the floor (_lair_hole).
				if TombKit.lair_took(_lay, int(pc.id), int(s.i)):
					continue
				var a := float(s.along)
				var sd := float(s.sd)
				coffins += 1
				var col: Color = palette[rng.randi() % palette.size()]
				if TombKit.resting_at(_lay, int(pc.id), int(s.i)).is_empty():
					_sarcophagus(_at(pc, a, sd * (half - TombKit.COFFIN_IN)), yaw, col)
				else:
					# Its lid falls toward the room's middle, clear of the end
					# walls' doors (the coffin's +x looks back toward the
					# room's start), unless that lays it before a sconce
					# (_lid_side).
					var at := _at(pc, a, sd * (half - TombKit.COFFIN_IN))
					_open_coffin(at, yaw, col, TombKit.COFFIN_SIZE, _lid_side(pc, at, yaw, TombKit.COFFIN_SIZE, -1.0 if a < length * 0.5 else 1.0, bays))
				if rng.randf() < 0.35 and not _in_bay(bays, Rect2(a + 0.9 - GOODS_REACH, sd * (half - 2.3) - GOODS_REACH, 2.0 * GOODS_REACH, 2.0 * GOODS_REACH)):
					_grave_goods(_at(pc, a + 0.9, sd * (half - 2.3), 0.03), 0.3, 1)
		"catacomb":
			# The niche stacks (TombKit.niche_spots); the one a skeleton sits
			# in is a burial niche.
			for s in TombKit.niche_spots(_lay, pc):
				var a := float(s.along)
				var sd := float(s.sd)
				niches += 1
				if not TombKit.resting_at(_lay, int(pc.id), int(s.i)).is_empty():
					_burial_niche(pc, a, sd)
					continue
				for k in 3:
					var sh := _at(pc, a, sd * (half - 0.22), 0.45 + 0.55 * k)
					box(Transform3D(Basis(Vector3.UP, atan2(pv.x, pv.y)), sh), Vector3(1.1, 0.1, 0.44), palette[1], _growth(0.15), 0.03, 0.01)
					if rng.randf() < 0.7:
						_grave_goods(sh + Vector3(0.0, 0.06, 0.0), 0.15, 1)
		"ossuary":
			for k in 4:
				var ca := 0.9 if k < 2 else length - 0.9
				var cs := (half - 0.9) * (1.0 if k % 2 == 0 else -1.0)
				var side := "left" if cs > 0.0 else "right"
				if _near_door(pc, side, ca, 1.8) or _in_bay(bays, Rect2(ca - 0.6 - GOODS_REACH, cs - 0.6 - GOODS_REACH, 1.2 + 2.0 * GOODS_REACH, 1.2 + 2.0 * GOODS_REACH)):
					continue
				_grave_goods(_at(pc, ca, cs, 0.03), 0.6, 6)
		"collapsed":
			# The corner farthest from the doors and the sconces' bays.
			var best := Vector2(length * 0.8, half * 0.6)
			var best_d := -INF
			for k in 4:
				var q := Vector2(length * (0.22 if k < 2 else 0.78), half * (0.6 if k % 2 == 0 else -0.6))
				var dmin := INF
				for di in pc.doors:
					var d: Dictionary = _lay.doors[di]
					dmin = minf(dmin, (Delves.along_across(pc, d.p) - q).length())
				for b in bays:
					var r: Rect2 = b
					dmin = minf(dmin, (q - q.clamp(r.position, r.end)).length())
				if dmin > best_d:
					best_d = dmin
					best = q
			var p := _at(pc, best.x, best.y)
			# The slab, turned (or broken smaller) until it keeps out of the
			# sconces' bays, and its rubble the same.
			var yaw0 := rng.randf() * TAU
			for k in 8:
				var size := Vector3(2.6, 0.45, 1.5) * (1.0 if k < 4 else 0.65)
				var yaw := yaw0 + PI * 0.5 * (k % 4)
				if not _in_bay(bays, _slab_foot(pc, p, size, yaw)):
					box(Transform3D(Basis.from_euler(Vector3(0.45, yaw, 0.2)), p + Vector3(0.0, 0.8, 0.0)), size, palette[2], _growth(0.4), 0.12, 0.08)
					break
			_rubble_clear(pc, p, 1.4, 6, bays)
		"heart":
			# The dead lie across the room toward its far end, their goods
			# before them, the way out beyond them (§EX.5): the walk goes
			# round them on either side and along the far wall behind the
			# lid to the door (TombKit.heart_box, HEART_*).
			var hb := TombKit.heart_box(pc)
			_heart_box(hb.pos, float(hb.yaw), not TombKit.resting_at(_lay, int(pc.id), -1).is_empty())
			# The dead's goods before them (HEART_GOODS_M from the far wall),
			# spread no nearer the sconces' bays than they reach.
			var g := Vector2(length - TombKit.HEART_GOODS_M, 0.0)
			var room_for := 0.6 + GOODS_REACH
			for b in bays:
				var r: Rect2 = b
				room_for = minf(room_for, (g - g.clamp(r.position, r.end)).length())
			_grave_goods(_at(pc, g.x, g.y, 0.03), clampf(room_for - GOODS_REACH, 0.3, 0.6), 6)


## The side (+1 / -1 along the coffin's x) an open coffin's lid falls to
## (_open_coffin): `prefer` (toward the room's middle) unless the lid would
## lie in a sconce's bay (design §EX.4), then the other side if that's
## clear.
func _lid_side(pc: Dictionary, p: Vector3, yaw: float, size: Vector3, prefer: float, bays: Array) -> float:
	for sd: float in [prefer, -prefer]:
		var c := p + Basis(Vector3.UP, yaw) * Vector3(sd * (size.x * 0.5 + 0.5), 0.0, 0.0)
		if not _in_bay(bays, _slab_foot(pc, c, Vector3(size.x + 0.1, 0.0, size.z + 0.5), yaw)):
			return sd
	return prefer


## A fallen slab's footprint at `p`, `size`, turned `yaw` (its tilt
## aside): a Rect2 in room `pc`'s (along, across), a little over.
func _slab_foot(pc: Dictionary, p: Vector3, size: Vector3, yaw: float) -> Rect2:
	var bs := Basis(Vector3.UP, yaw)
	var r := Rect2(Delves.along_across(pc, Vector2(p.x, p.z)), Vector2.ZERO)
	for c in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		var w: Vector3 = p + bs * (Vector3(size.x, 0.0, size.z) * 0.5 * (c as Vector3))
		r = r.expand(Delves.along_across(pc, Vector2(w.x, w.z)))
	return r.grow(0.1)


## RuinBuilder.rubble, kept out of `bays` (room `pc`'s sconce bays): a
## block or boulder that would land in one isn't laid.
func _rubble_clear(pc: Dictionary, center: Vector3, spread: float, count: int, bays: Array) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		var size := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var col: Color = palette[rng.randi() % palette.size()]
		var block := rng.randf() < 0.55
		var moss := _growth(rng.randf_range(0.3, 0.9))
		var rr := maxf(size.x, size.z) * 0.5
		if _in_bay(bays, Rect2(Delves.along_across(pc, Vector2(x, z)) - Vector2(rr, rr), Vector2(rr, rr) * 2.0)):
			continue
		var p := Vector3(x, ground(x, z) + size.y * 0.3, z)
		var was := foot_y
		foot_y = p.y - size.y * 0.3
		if block:
			# A tumbled block, edges knocked round.
			box(Transform3D(basis, p), size, col, moss, 0.16, 0.1)
		else:
			boulder(p, size * 0.55, basis, col.darkened(0.05), moss)
		foot_y = was


## The heart's coffin (Mike's frame 9): a mossy stone box, its lid shoved
## half off, the one buried there leaning out over its side: skull, ribs,
## an arm hanging down the stone. When that one is a resident (`open`,
## residents.json skeleton heart_holds_one) the box is hollow and the
## skeleton is its sprite (Residents), not stone.
func _heart_box(p: Vector3, yaw: float, open := false) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var col: Color = palette[3]
	if open:
		_open_box(bs, p, TombKit.HEART_BOX, col.darkened(0.05), 0.75)
	else:
		box(Transform3D(bs, p + Vector3(0.0, 0.5, 0.0)), Vector3(1.05, 1.0, 2.3), col.darkened(0.05), 0.75, 0.08, 0.03)
	# The lid, shoved off one side and down against the box.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.12, 0.42)), p + bs * Vector3(-0.85, 0.72, 0.15)), Vector3(1.1, 0.18, 2.35), col.lightened(0.04), 0.85, 0.06, 0.02)
	if open:
		return
	solid = false
	# The skeleton: ribs leaning out over the rim, the skull past them, an
	# arm down the outside.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.42, 1.1, 0.55)), Vector3(0.38, 0.14, 0.3), BONE, 0.0, 0.03, 0.01)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.38, 1.12, 0.22)), Vector3(0.34, 0.08, 0.12), BONE.darkened(0.05), 0.0, 0.02, 0.01)
	boulder(p + bs * Vector3(0.72, 1.02, 0.62), Vector3(0.12, 0.13, 0.15), bs, BONE, 0.0)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, 0.15)), p + bs * Vector3(0.6, 0.62, 0.35)), Vector3(0.05, 0.62, 0.05), BONE, 0.0, 0.015, 0.005)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.3, 0.0, 0.1)), p + bs * Vector3(0.62, 0.22, 0.42)), Vector3(0.05, 0.3, 0.05), BONE, 0.0, 0.015, 0.005)
	solid = true


## An open stone box `size` (x wide, y tall, z long, in `bs`) standing on
## `p`: four walls round a dark hollow filled up to where a skeleton
## kneels (TombKit.grave_floor: its head and an arm clear the rim), a
## grave (residents.json skeleton rests_in).
func _open_box(bs: Basis, p: Vector3, size: Vector3, col: Color, moss: float) -> void:
	var t := 0.1
	var fill := TombKit.grave_floor(size.y)
	box(Transform3D(bs, p + Vector3(0.0, fill * 0.5, 0.0)), Vector3(size.x, fill, size.z), col.darkened(0.45), moss * 0.5, 0.03, 0.02)
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(bs, p + bs * Vector3(sx * (size.x - t) * 0.5, size.y * 0.5, 0.0)), Vector3(t, size.y, size.z), col, moss, 0.04, 0.02)
	for sz: float in [-1.0, 1.0]:
		box(Transform3D(bs, p + bs * Vector3(0.0, size.y * 0.5, sz * (size.z - t) * 0.5)), Vector3(size.x - 2.0 * t, size.y, t), col, moss, 0.04, 0.02)


## A crypt coffin a skeleton rests in (§FE.2: it climbs out of its grave):
## _sarcophagus's box, open, and its lid shoved off its `side` long side
## (+1 its +x), down on the floor against it. Draws on the same rolls as
## _sarcophagus, so the rest of the room is as it would be.
func _open_coffin(p: Vector3, yaw: float, col: Color, size: Vector3, side: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	_open_box(bs, p, size, col.darkened(0.05), _growth(0.15))
	var turn := rng.randf_range(-0.25, 0.25)
	rng.randf_range(-0.15, 0.15)
	var slide := rng.randf_range(-0.2, 0.2)
	# Tipped so its edge by the box rests up against it.
	var lid := bs * Basis(Vector3.UP, turn * 0.3) * Basis(Vector3.BACK, -side * 0.38)
	box(Transform3D(lid, p + bs * Vector3(side * (size.x * 0.5 + 0.5), 0.27, slide)), Vector3(size.x + 0.1, 0.2, size.z + 0.1), col.lightened(0.05), _growth(0.2), 0.06, 0.02)


## A burial niche a skeleton sits in (§FE.2: it climbs out of the wall):
## the catacomb's shelf stack at `along` on side `sd` of `pc` with its
## middle shelf gone and its bottom shelf deeper, framed by two jambs and a
## lintel standing out from the wall, so it reads as cut into it.
func _burial_niche(pc: Dictionary, along: float, sd: float) -> void:
	var half := float(pc.half)
	var pv := Delves.perp(pc.dir)
	var bs := Basis(Vector3.UP, atan2(pv.x, pv.y))
	box(Transform3D(bs, _at(pc, along, sd * (half - 0.3), 0.45)), Vector3(1.1, 0.1, 0.6), palette[1], _growth(0.15), 0.03, 0.01)
	var top := _at(pc, along, sd * (half - 0.22), 1.55)
	box(Transform3D(bs, top), Vector3(1.1, 0.1, 0.44), palette[1], _growth(0.15), 0.03, 0.01)
	if rng.randf() < 0.7:
		_grave_goods(top + Vector3(0.0, 0.06, 0.0), 0.15, 1)
	var fc: Color = (palette[2] as Color).darkened(0.05)
	for e: float in [-1.0, 1.0]:
		box(Transform3D(bs, _at(pc, along + e * 0.64, sd * (half - 0.32), 0.85)), Vector3(0.18, 1.7, 0.64), fc, _growth(0.2), 0.04, 0.02)
	box(Transform3D(bs, _at(pc, along, sd * (half - 0.32), 1.78)), Vector3(1.46, 0.22, 0.64), fc, _growth(0.25), 0.04, 0.02)


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


const SOOT_CELL := 2.0


## Soot (design §EV.1; smoke.json vents.soot): the smoke's stain painted
## into the stone round every vent's mouth (the ceiling's slabs, the
## stones, the vent's own walls there) and up a sconce's wall from its
## flame, streak_m long (rolled per vent): the vertex colours pulled toward
## navy-black soot (outlets.soot, §CV.3), mottled, the moss burnt off. It
## is stone, so it stays when the fire is out (stays_when_cold).
func _soot(lay: Dictionary) -> void:
	var so: Dictionary = TombKit.vents_table().get("soot", {})
	var amount := clampf(float(so.get("amount", 0.85)), 0.0, 1.0)
	if amount <= 0.0:
		return
	var cs := str(so.get("color", "outlets.soot"))
	if not cs.begins_with("#"):
		cs = str(((Tuning.table("smoke").get("outlets", {}) as Dictionary).get("soot", {}) as Dictionary).get("colour", "#0A0C20"))
	var black := Color(cs)
	var streak: Array = so.get("streak_m", [0.8, 2.0])
	var srcs: Array = []
	for v in lay.get("vents", []):
		var m: Vector3 = v.mouth
		var sr := RandomNumberGenerator.new()
		sr.seed = hash([int(lay.seed), m, "soot"])
		var l := sr.randf_range(float(streak[0]), float(streak[1]))
		var r := l * 0.5 * clampf(float(v.d) / 0.9, 0.55, 1.4)
		srcs.append([0, m, r, float(v.d) * 0.5])
		if str(v.kind) == "sconce":
			var f: Vector3 = v.fire
			var nrm := Vector3(m.x - f.x, 0.0, m.z - f.z).normalized()
			srcs.append([1, f, nrm, minf(l, m.y - f.y + 0.1)])
	# Each source in the cells of a coarse x/z grid it reaches, so each
	# vertex tests only the sources near it.
	var buckets := {}
	for s2 in srcs:
		var c2: Vector3 = s2[1]
		var reach := (float(s2[2]) + float(s2[3]) + 0.1) if int(s2[0]) == 0 else 0.6
		for gx in range(floori((c2.x - reach) / SOOT_CELL), floori((c2.x + reach) / SOOT_CELL) + 1):
			for gz in range(floori((c2.z - reach) / SOOT_CELL), floori((c2.z + reach) / SOOT_CELL) + 1):
				var key := Vector2i(gx, gz)
				if not buckets.has(key):
					buckets[key] = []
				(buckets[key] as Array).append(s2)
	for i in _v.size():
		var p := _v[i]
		var near = buckets.get(Vector2i(floori(p.x / SOOT_CELL), floori(p.z / SOOT_CELL)))
		if near == null:
			continue
		var k := 0.0
		for s2 in near:
			if int(s2[0]) == 0:
				var m2: Vector3 = s2[1]
				var dy := p.y - m2.y
				if dy < -0.45 or dy > 0.9:
					continue
				# From the vent's rim out across the ceiling.
				var dh := maxf(Vector2(p.x - m2.x, p.z - m2.z).length() - float(s2[3]), 0.0)
				k = maxf(k, smoothstep(float(s2[2]), float(s2[2]) * 0.25, dh) * (1.0 - smoothstep(-0.1, -0.45, dy) * 0.0))
			else:
				var f2: Vector3 = s2[1]
				var nv: Vector3 = s2[2]
				var rel := p - f2
				if absf(rel.dot(nv)) > 0.5:
					continue
				var lat := (rel - nv * rel.dot(nv) - Vector3.UP * rel.y).length()
				var up := rel.y
				if up < -0.1 or up > float(s2[3]):
					continue
				k = maxf(k, smoothstep(0.42, 0.12, lat) * (1.0 - up / maxf(float(s2[3]), 0.1) * 0.6))
		if k <= 0.0:
			continue
		var mottle := 0.75 + 0.5 * float(posmod(hash(Vector3i(roundi(p.x * 12.0), roundi(p.y * 12.0), roundi(p.z * 12.0))), 1000)) / 1000.0
		var c := _c[i]
		var a := c.a
		c = c.lerp(black, clampf(amount * k * mottle, 0.0, 0.95))
		c.a = a * (1.0 - k)
		_c[i] = c


## The lair (design §EY.1, §EY.2; bosses.json lair; BossGround.place_lair):
## the floor of a side room broken through into the dark below, where the
## boss goes home: flags tipped down round its mouth (the mouth's black is
## the boss's, Boss), broken stone thrown out round it, a few small bones.
## Its stone is the tomb's own (the palette the walls are cut from). Not a
## way down (lair.enterable false): a ring of collision round the mouth
## keeps you at its edge, and the floor under it is whole.
func _lair_hole(l: Dictionary) -> void:
	var c: Vector3 = l.pos
	var r := float(l.r)
	var keep_rng := rng
	rng = RandomNumberGenerator.new()
	rng.seed = hash([int(_lay.seed), "lair_hole"])
	solid = false
	# The mouth itself is no stone: a black void the boss draws (Boss), as
	# the airways' slots are.
	# The broken edge: flags round the mouth, tipped down into it.
	var n_flags := 9
	for k in n_flags:
		var a := TAU * (k + rng.randf_range(-0.25, 0.25)) / n_flags
		var out := Vector3(cos(a), 0.0, sin(a))
		var tangent := Vector3(-out.z, 0.0, out.x)
		var tip := rng.randf_range(0.35, 0.7)
		# Long side round the rim (local z along the tangent), the inner edge
		# tipped down into the dark.
		var size := Vector3(rng.randf_range(0.3, 0.42), 0.12, rng.randf_range(0.42, 0.62))
		var bs := Basis(tangent, tip) * Basis(Vector3.UP, atan2(tangent.x, tangent.z))
		var p := c + out * (r + 0.08) + Vector3(0.0, 0.02, 0.0)
		var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(rng.randf_range(0.05, 0.2))
		# Freshly broken: no moss.
		box(Transform3D(bs, p), size, col, 0.0, 0.03, 0.02)
	# Stone thrown out round it, and the small bones of what it ate.
	for k in 10:
		var a := rng.randf() * TAU
		var d := r + rng.randf_range(0.35, 1.2)
		var p := c + Vector3(cos(a), 0.0, sin(a)) * d
		var rad := Vector3(rng.randf_range(0.06, 0.16), rng.randf_range(0.04, 0.1), rng.randf_range(0.06, 0.15))
		boulder(p + Vector3(0.0, rad.y * 0.6, 0.0), rad, Basis(Vector3.UP, rng.randf() * TAU), (palette[rng.randi() % palette.size()] as Color).darkened(0.1), 0.0)
	for k in 5:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (r + rng.randf_range(0.3, 1.0))
		box(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0.0, 0.025, 0.0)), Vector3(rng.randf_range(0.12, 0.26), 0.035, 0.035), BONE.darkened(rng.randf_range(0.1, 0.3)), 0.0, 0.01, 0.005)
	solid = true
	rng = keep_rng
	# You stand at its edge, never in it.
	var ring := PackedVector3Array()
	for k in 12:
		var a := TAU * k / 12.0
		var q := c + Vector3(cos(a), 0.0, sin(a)) * (r + 0.05)
		ring.append(q + Vector3(0.0, -0.3, 0.0))
		ring.append(q + Vector3(0.0, 1.8, 0.0))
	_ch.append(ring)

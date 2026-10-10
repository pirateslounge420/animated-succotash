class_name RoomPoolBuild
## Draws what is a big room's own (design 9 Oct §FM.6's room pool; RoomPool,
## data/room_pool.json archetypes) for TombBuild, in the ruin's one stone
## (§EX.1: RuinStyle; the style's fitted flags, its block steps, its
## niches), painted per §ES (diffuse, the shade in the vertex colours, the
## joints and hollows toward navy, never grey). Its walls, doors, wall
## sconces, corbel course, beams and ceiling slabs are TombBuild's own, as
## in any room; this is the rest:
##
##   lay_floor     a big room's floor, and one that steps (a stepped hall's
##                 rise to its dais, a sunken court's flights down and up):
##                 each level run the style's fitted flags (merged bigger,
##                 room_pool.json build.flags_scale: queue 48's way to keep
##                 a room inside its triangles), each change of level a row
##                 of the style's block steps across the room (a step one
##                 block, settled like the walls, §EX.3), every edge's face
##                 where the step's slope is halfway up it; under it the
##                 floor's collision, level boxes and a slope up each flight
##                 (RuinBuilder._dramp), as the kit's stairs are walked
##   hidden_holes  the walls' stone that would stand hidden behind the steps
##                 and under the terraces, left out of their faces
##   niche_pillar  a pillar a sconce is cut into (the pillar hall's): the
##                 style's trapezoid niche in its face toward the hall's
##                 middle (sconce niche_cup; the cup is TombBuild's and the
##                 flame CrawlerFires'), and its flue slot up the pillar's
##                 face through its cap, sooted (design §EV.1: every wall
##                 torch shows the way its smoke goes)
##   dress         what stands in it: the stepped hall's seat on its dais,
##                 the sunken court's stela and the stone heads set into its
##                 walls (Chavín de Huántar's tenon heads)
##
## Static, on the builder's own dice (TombBuild.rng), so the same seed
## draws the same room.

## How deep a step's top stone reaches back from its face where a level run
## begins (m): the nosing block at a flight's top or a dais's edge.
const NOSING_M := 0.45
## How far a step's block goes down under the lower level (m).
const SUNK_M := 0.12


## The floor of big room `pc` (a "profile": RoomPool.runs): its flags, its
## steps and its collision.
static func lay_floor(b: TombBuild, pc: Dictionary) -> void:
	var half := float(pc.half)
	var length := float(pc.len)
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var r := RoomPool.runs(pc)
	var flats: Array = r.flats
	var slopes: Array = r.slopes
	var th := str(b._lay.get("theme", "tomb"))
	var cl := FittedStone.climate_at(th, int(b._lay.seed), b._at(pc, length * 0.5, 0.0))
	var fr := RandomNumberGenerator.new()
	fr.seed = hash([b._mseed, int(pc.id), "floor"])
	var wear := b._wear(pc)
	# A step every 0.3 m of rise, as the kit's stairs (TombBuild._stair).
	var step_h := 0.3
	# Bigger flags than a room's (queue 48's remedy for a room past its
	# triangles: merge the floor's small cells; room_pool.json build).
	var scale := maxf(float((RoomPool.D.get("build", {}) as Dictionary).get("flags_scale", 1.0)), 0.5)
	# Each slope's steps: [from, to, y_from, y_to, n (steps), s (each step's
	# depth along)].
	var flights: Array = []
	for sl in slopes:
		var n := maxi(int(round(absf(float(sl[3]) - float(sl[2])) / step_h)), 1)
		flights.append([float(sl[0]), float(sl[1]), float(sl[2]), float(sl[3]), n, (float(sl[1]) - float(sl[0])) / n])
	b._stone_mode()
	var tf := Time.get_ticks_usec()
	if not b._collision_only:
		# The level runs: the style's flags, from the step's face before to
		# the step's face after (or the nosing stone on a level's high edge).
		for f in flats:
			var a0 := float(f[0])
			var a1 := float(f[1])
			var y := float(f[2])
			var x0 := -0.05
			var x1 := length + 0.05
			for fl in flights:
				var s := float(fl[5])
				if absf(float(fl[1]) - a0) < 1e-3:
					# A flight ends where this run begins: its last face is half
					# a step back; if it climbed to here, its nosing is ours.
					x0 = a0 - s * 0.5 + (NOSING_M if float(fl[3]) > float(fl[2]) else 0.0)
				if absf(float(fl[0]) - a1) < 1e-3:
					x1 = a1 + s * 0.5 - (NOSING_M if float(fl[3]) < float(fl[2]) else 0.0)
			if x1 - x0 < 0.3:
				continue
			var o2 := RuinBuilder._pp(pc, x0, -(half + 0.05))
			var fo := Vector3(o2.x, y, o2.y)
			var x_at := x0
			b.flags_laid += FittedStone.flags(b, fo, u, v, x1 - x0, 2.0 * half + 0.1, cl, fr,
				func(x: float, yy: float) -> float: return float(wear.call(x + x_at, yy - half - 0.05)), [], scale)
		# The steps: each change of level a row of blocks across the room,
		# its face where the flight's slope is halfway up that step.
		for fl in flights:
			var a := float(fl[0])
			var ya := float(fl[2])
			var n := int(fl[4])
			var s := float(fl[5])
			var d := (float(fl[3]) - ya) / n
			for k in n:
				var edge := a + (k + 0.5) * s
				var lo_y := ya + d * k
				var hi_y := ya + d * (k + 1)
				var from := edge
				var to := edge
				if d > 0.0:
					# Up: the block on the far side of the face, to the next face
					# or a nosing's depth into the level beyond.
					to = edge + (s if k < n - 1 else NOSING_M)
				else:
					# Down: the block on the near side, back to the face before or
					# a nosing's depth into the level it leaves.
					hi_y = ya + d * k
					lo_y = ya + d * (k + 1)
					from = edge - (s if k > 0 else NOSING_M)
				_step_row(b, pc, from, to, lo_y, hi_y)
	b._took("floors", tf)
	# The floor's collision: a box under each level run, a slope up each
	# flight, walked as the kit's stairs are. On the profile's own line (no
	# ramp_lift: that rides a flight's slope over the threshold stone at its
	# top, and a step here has none), so the floor is where Delves.floor_of
	# says, and no slope ends in a lip above the level beyond it.
	var was_lift := b.ramp_lift
	b.ramp_lift = 0.0
	for f in flats:
		# A hand past each end, overlapping what it meets, but never into a
		# slope that climbs onto it: there the box's edge would stand proud
		# of the slope just short of its top, a lip to stumble on.
		var a0 := float(f[0]) - 0.05
		var a1 := float(f[1]) + 0.05
		for fl in flights:
			if absf(float(fl[1]) - float(f[0])) < 1e-3 and float(fl[3]) > float(fl[2]):
				a0 = float(f[0])
			if absf(float(fl[0]) - float(f[1])) < 1e-3 and float(fl[2]) > float(fl[3]):
				a1 = float(f[1])
		var c := RuinBuilder._pp(pc, (a0 + a1) * 0.5, 0.0)
		var bs := Basis(u, Vector3.UP, u.cross(Vector3.UP))
		b._collision_box(Transform3D(bs, Vector3(c.x, float(f[2]) - 0.15, c.y)), Vector3((a1 - a0) * 0.5, 0.15, half + 0.05))
	for fl in flights:
		var p_from := RuinBuilder._pp(pc, float(fl[0]), 0.0)
		var p_to := RuinBuilder._pp(pc, float(fl[1]), 0.0)
		var y_from := float(fl[2])
		var y_to := float(fl[3])
		var lo := Vector3(p_from.x, y_from, p_from.y) if y_from < y_to else Vector3(p_to.x, y_to, p_to.y)
		var hi := Vector3(p_to.x, y_to, p_to.y) if y_from < y_to else Vector3(p_from.x, y_from, p_from.y)
		b._dramp(lo, hi, 2.0 * half + 0.1)
	b.ramp_lift = was_lift


## The stone of big room `pc`'s wall `side` that would only stand hidden,
## behind its steps or under its terraces and dais: holes for the dressed
## face (TombBuild._stone_wall's `hidden`), in the face's own (along its
## run, y - `y0f`, the face's foot): under each level run up to its floor,
## under each flight up to its lower end, a hand short (the flags' joints
## and the step blocks' foot stay walled). [] where nothing is hidden.
static func hidden_holes(pc: Dictionary, side: String, y0f: float) -> Array:
	var out: Array = []
	var m := 0.06
	var length := float(pc.len)
	var half := float(pc.half)
	if side in ["start", "end"]:
		var top := Delves.floor_of(pc, 0.0 if side == "start" else length) - y0f - m
		if top > 0.05:
			out.append(_rect(-0.3, -0.3, 2.0 * half + 0.3, top))
		return out
	# The side walls run from a wall's thickness before the room's start.
	var w := Delves.WALL
	var r := RoomPool.runs(pc)
	for f in r.flats:
		var top := float(f[2]) - y0f - m
		if top > 0.05:
			out.append(_rect(float(f[0]) + w, -0.3, float(f[1]) + w, top))
	for sl in r.slopes:
		var top := minf(float(sl[2]), float(sl[3])) - y0f - m
		if top > 0.05:
			out.append(_rect(float(sl[0]) + w, -0.3, float(sl[1]) + w, top))
	return out


## A rectangle, counter-clockwise (a face's hole).
static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## A row of step blocks across room `pc` from `from` to `to` along it, its
## top at `hi_y`, down past `lo_y`: blocks 1.2-2.2 m long, each its own
## stone, a few settled a little (masonry.json settle), drawn only.
static func _step_row(b: TombBuild, pc: Dictionary, from: float, to: float, lo_y: float, hi_y: float) -> void:
	var half := float(pc.half)
	var ax := TombBuild._axes(pc)
	var v: Vector3 = ax[1]
	var bs := Basis(v, Vector3.UP, v.cross(Vector3.UP))
	var st: Dictionary = FittedStone.M.get("settle", {})
	var share := float(st.get("share", 0.15))
	var depth := to - from
	if depth < 0.05:
		return
	var h := hi_y - lo_y + SUNK_M
	var was_solid := b.solid
	var was_foot := b.foot_y
	b.solid = false
	b.foot_y = lo_y
	var at := -half
	while at < half - 0.01:
		var l := b.rng.randf_range(1.2, 2.2)
		if half - (at + l) < 0.8:
			l = half - at
		var drop := b.rng.randf_range(0.0, float(st.get("dropped_m", 0.05)) * 0.4) if b.rng.randf() < share else 0.0
		var mid := b._at(pc, (from + to) * 0.5, at + l * 0.5)
		var c := Vector3(mid.x, hi_y - h * 0.5 - drop, mid.z)
		b.box(Transform3D(bs.rotated(Vector3.UP, b.rng.randf_range(-0.01, 0.01)), c), Vector3(l - 0.012, h, depth + 0.02), RuinStyle.stone(b.rng), b._growth(0.05), 0.04, 0.015)
		at += l
	b.solid = was_solid
	b.foot_y = was_foot


## A pillar of room `pc` a sconce is cut into (the pillar hall's, RoomPool
## room_plan "niches"): standing at `p3` (its middle on its floor), `side`
## square, its shaft from `z0` up to `top` under its cap (`cap_h`), the
## niche in its face whose way out is `face_aa` (along, across): the style's
## trapezoid niche (sconce niche_w_m, niche_h_m, niche_d_m, niches
## top_share), its sill under the holder's cup, and over it the flue slot,
## its flue's width, up the shaft and through the cap (§EV.1; its vent's
## mouth is in the ceiling just before the face, TombKit._place_vents). The
## builder's own dice; drawn only (its collision is TombBuild's hulls).
static func niche_pillar(b: TombBuild, pc: Dictionary, p3: Vector3, side: float, z0: float, top: float, cap_h: float, face_aa: Vector2) -> void:
	var ax := TombBuild._axes(pc)
	var n := ((ax[0] as Vector3) * face_aa.x + (ax[1] as Vector3) * face_aa.y).normalized()
	var t := Vector3.UP.cross(n).normalized()
	var bs := Basis(t, Vector3.UP, n)
	var c := Vector3(p3.x, 0.0, p3.z)
	var sc := TombBuild.sconce_niche()
	var fw := float(sc.w)
	var tw := fw * float(sc.top)
	var nd := float(sc.d)
	# The holder whose niche this is: its cup sets the niche's sill.
	var face := c + n * (side * 0.5)
	var hold: Dictionary = {}
	for h in b._lay.holders:
		if int(h.piece) == int(pc.id) and Vector2((h.pos as Vector3).x - face.x, (h.pos as Vector3).z - face.z).length() < 0.05:
			hold = h
			break
	var y0 := (hold.pos as Vector3).y - float((sc.cup as Vector3).y) if not hold.is_empty() else p3.y + 1.61
	var y1 := y0 + float(sc.h)
	# The flue slot: its vent's width (TombBuild._flue_slot_op's rule), as
	# deep as keeps it clear of the beam over the row.
	var ws := float((TombKit.vents_table().get("flue", {}) as Dictionary).get("width_m", [0.15, 0.3])[0])
	for vt in b._lay.get("vents", []):
		if not hold.is_empty() and str(vt.kind) == "sconce" and (vt.fire as Vector3).is_equal_approx(hold.pos):
			ws = float(vt.d)
			break
	ws = clampf(ws, 0.12, tw - 0.06)
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var sd := clampf(side * 0.5 - bw * 0.5 - 0.03, 0.06, nd)
	var s0 := y1 + TombBuild.FLUE_SLOT_LIP_M
	b._stone_mode()
	var was_solid := b.solid
	b.solid = false
	var was_foot := b.foot_y
	b.foot_y = p3.y
	# The shaft under the niche: a drum or two.
	if y0 - z0 > 0.1:
		var drums := clampi(int(round((y0 - z0) / 0.72)), 1, 3)
		var z := z0
		for k in drums:
			var zb := y0 if k == drums - 1 else z + (y0 - z) / float(drums - k) * b.rng.randf_range(0.9, 1.1)
			b.box(Transform3D(bs * Basis.from_euler(Vector3(0.0, b.rng.randf_range(-0.03, 0.03), 0.0)), c + Vector3.UP * ((z + zb) * 0.5)), Vector3(side, zb - z + 0.006, side), RuinStyle.stone(b.rng), b._growth(0.08), 0.035, 0.012)
			z = zb
	b.foot_y = was_foot
	# Round the niche: the stone behind it and either side of it.
	_cut_band(b, c, bs, n, t, side, fw, nd, y0, y1)
	# The stone between the niche and its slot.
	b.box(Transform3D(bs, c + Vector3.UP * (y1 + s0) * 0.5), Vector3(side, s0 - y1 + 0.006, side), RuinStyle.stone(b.rng), 0.0, 0.02, 0.008)
	# Round the slot, up to the cap.
	_cut_band(b, c, bs, n, t, side, ws, sd, s0, top)
	# The cap, cut through by the slot (it reaches 0.07 out round the shaft).
	var cw := side + 0.14
	var cd := 0.07 + sd
	b.box(Transform3D(bs, c + Vector3.UP * (top + cap_h * 0.5) - n * (cd * 0.5)), Vector3(cw, cap_h, cw - cd), RuinStyle.stone(b.rng), 0.0, 0.035, 0.01)
	for sg: float in [-1.0, 1.0]:
		var wside := (cw - ws) * 0.5
		b.box(Transform3D(bs, c + Vector3.UP * (top + cap_h * 0.5) + n * (cw * 0.5 - cd * 0.5) + t * sg * (ws * 0.5 + wside * 0.5)), Vector3(wside, cap_h, cd), RuinStyle.stone(b.rng), 0.0, 0.03, 0.01)
	# The niche's inside and the slot's (sooted), as a wall's are cut
	# (TombBuild._hollow): on the face, its middle at the pillar's.
	var o := c + n * (side * 0.5)
	var nv := Vector2(n.x, n.z)
	b._hollow(o, t, n, {"c": 0.0, "fw": fw, "tw": tw, "y0": y0, "y1": y1, "depth": nd, "n": nv, "sconce": true})
	_trapezoid_front(b, o, t, n, fw, tw, y0, y1)
	b._hollow(o, t, n, {"c": 0.0, "fw": ws, "tw": ws, "y0": s0, "y1": top + cap_h, "depth": sd, "n": nv, "flue": true})
	# The slot runs on open past the cap, beside the beam, into its vent's
	# mouth in the ceiling (the slot's record reaches the ceiling, as a
	# wall's does).
	if not b.flue_slots.is_empty():
		var rec: Dictionary = b.flue_slots[-1]
		var tp: Vector3 = rec.top
		rec["top"] = Vector3(tp.x, float(pc.y0) + float(pc.h), tp.z)
	b.solid = was_solid
	b._stone_mode()


## The stone round an opening `w` wide and `depth` deep cut into a pillar's
## face (its middle `c` on the floor plane, `side` square, `n` out of the
## face, `t` along it), from `ya` to `yb`: the block behind the opening and
## one either side of it, each set back SET_BACK_M from the opening's own
## inside faces (TombBuild._hollow draws those), so no two faces lie in one
## plane.
static func _cut_band(b: TombBuild, c: Vector3, bs: Basis, n: Vector3, t: Vector3, side: float, w: float, depth: float, ya: float, yb: float) -> void:
	if yb - ya < 0.01:
		return
	var hgt := yb - ya + 0.006
	var mid := (ya + yb) * 0.5
	var deep := depth + SET_BACK_M
	var back := side - deep
	b.box(Transform3D(bs, c + Vector3.UP * mid - n * (deep * 0.5)), Vector3(side, hgt, back), RuinStyle.stone(b.rng), 0.0, 0.02, 0.008)
	var wside := (side - w) * 0.5 - SET_BACK_M
	for sg: float in [-1.0, 1.0]:
		b.box(Transform3D(bs, c + Vector3.UP * mid + n * (side * 0.5 - deep * 0.5) + t * sg * (side * 0.5 - wside * 0.5)), Vector3(wside, hgt, deep), RuinStyle.stone(b.rng), 0.0, 0.02, 0.008)


## How far the stone round a pillar's niche or slot stands back from the
## opening's inside faces (m).
const SET_BACK_M := 0.012


## The face's stone in the niche's top corners, where its trapezoid narrows
## (the opening cut square through the stones either side): two thin
## triangles on the face at `o` (`t` along it, `n` out of it).
static func _trapezoid_front(b: TombBuild, o: Vector3, t: Vector3, n: Vector3, fw: float, tw: float, y0: float, y1: float) -> void:
	if fw - tw < 0.005:
		return
	var col := RuinStyle.stone(b.rng)
	var lift := n * 0.004
	for sg: float in [-1.0, 1.0]:
		var p0 := o + t * sg * (fw * 0.5) + Vector3.UP * y0 + lift
		var p1 := o + t * sg * (fw * 0.5) + Vector3.UP * y1 + lift
		var p2 := o + t * sg * (tw * 0.5) + Vector3.UP * y1 + lift
		b._tri_n(p0, p1, p2, n, n, n, col, col, col, o - n * 1.0)


## What stands in big room `pc` (its archetype's stands): the stepped
## hall's seat, the sunken court's stela and tenon heads. The style's stone.
static func dress(b: TombBuild, pc: Dictionary) -> void:
	for st in RoomPool.archetype(str(pc.big_room)).get("stands", []):
		var sd: Dictionary = st
		match str(sd.get("kind", "")):
			"seat":
				_seat(b, pc, sd)
			"stela":
				_stela(b, pc, sd)
			"tenon_heads":
				_tenon_heads(b, pc, sd)
	b._stone_mode()


## A stone seat on the dais, facing down the hall (an Inca usnu's: a seat
## block and its back, cut from the room's stone), along_m in, across the
## middle; size_m [across, high (its back's top), deep].
static func _seat(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var size: Array = sd.get("size_m", [1.6, 1.1, 0.75])
	var w := float(size[0])
	var tall := float(size[1])
	var deep := float(size[2])
	var along := float(sd.get("along_m", float(pc.len) - 2.5))
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var bs := Basis(v, Vector3.UP, v.cross(Vector3.UP))
	var p := b._at(pc, along, 0.0)
	b._stone_mode()
	var was_foot := b.foot_y
	b.foot_y = p.y
	# The seat block, then its back on the far side (toward the end wall).
	b.box(Transform3D(bs, p + Vector3.UP * 0.225), Vector3(w, 0.45, deep), RuinStyle.stone(b.rng), b._growth(0.1), 0.05, 0.02)
	b.box(Transform3D(bs, p + u * (deep * 0.5 - 0.11) + Vector3.UP * (tall * 0.5)), Vector3(w, tall, 0.22), RuinStyle.stone(b.rng), b._growth(0.12), 0.05, 0.02)
	# Its arms, low blocks either end of it.
	for sg: float in [-1.0, 1.0]:
		b.box(Transform3D(bs, p + v * sg * (w * 0.5 - 0.11) + Vector3.UP * 0.35), Vector3(0.22, 0.7, deep), RuinStyle.stone(b.rng), b._growth(0.1), 0.04, 0.02)
	b.foot_y = was_foot


## The court's stela: a tall carved stone standing on a low plinth in the
## court, its broad faces toward the doors (along_m in, across the middle;
## size_m [wide, high, thick]); carved bands across its faces, cut in, in
## the stone's own shade.
static func _stela(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var size: Array = sd.get("size_m", [0.7, 2.4, 0.4])
	var w := float(size[0])
	var tall := float(size[1])
	var thick := float(size[2])
	var along := float(sd.get("along_m", float(pc.len) * 0.5))
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var bs := Basis(v, Vector3.UP, v.cross(Vector3.UP))
	var p := b._at(pc, along, 0.0)
	b._stone_mode()
	var was_foot := b.foot_y
	b.foot_y = p.y
	b.box(Transform3D(bs, p + Vector3.UP * 0.08), Vector3(w + 0.36, 0.16, thick + 0.36), RuinStyle.stone(b.rng), b._growth(0.25), 0.04, 0.02)
	var col := RuinStyle.stone(b.rng)
	b.box(Transform3D(bs.rotated(Vector3.UP, b.rng.randf_range(-0.03, 0.03)), p + Vector3.UP * (0.16 + tall * 0.5)), Vector3(w, tall, thick), col, b._growth(0.15), 0.05, 0.02)
	b.foot_y = was_foot
	# The carving: bands cut across both broad faces, darker in the cut.
	var cut: Color = col if TombBuild.bare else Prelit.ao_tint(col, 0.45)
	var was_solid := b.solid
	b.solid = false
	for face: float in [-1.0, 1.0]:
		for k in 5:
			var hy := 0.16 + tall * (0.2 + 0.15 * k)
			b.box(Transform3D(bs, p + Vector3.UP * hy + u * face * (thick * 0.5 + 0.004)), Vector3(w * (0.78 if k % 2 == 0 else 0.5), 0.04, 0.012), cut, 0.0, 0.0, 0.0)
	b.solid = was_solid


## Stone heads set into the court's walls, high over its floor (Chavín de
## Huántar's tenon heads): on each of `walls` at each along_m, up_m over the
## floor there; each a block size_m [wide, high, jut] standing out of the
## wall, with a brow and, cut in, its eyes and mouth. Drawn only (out of
## reach).
static func _tenon_heads(b: TombBuild, pc: Dictionary, sd: Dictionary) -> void:
	var half := float(pc.half)
	var up := float(sd.get("up_m", 2.6))
	# Each head's block: size_m [wide, high, how far it juts from the wall].
	var size: Array = sd.get("size_m", [0.3, 0.36, 0.34])
	var w := float(size[0])
	var hh := float(size[1])
	var jut := float(size[2])
	var ax := TombBuild._axes(pc)
	var u: Vector3 = ax[0]
	var v: Vector3 = ax[1]
	var was_solid := b.solid
	b.solid = false
	b._stone_mode()
	for wall in sd.get("walls", ["left", "right"]):
		var sg := 1.0 if str(wall) == "left" else -1.0
		var into := -v * sg
		var bs := Basis(u, Vector3.UP, into)
		for a in sd.get("along_m", []):
			var floor_p := b._at(pc, float(a), sg * half)
			var face := floor_p + Vector3.UP * up
			var col := RuinStyle.stone(b.rng)
			b.box(Transform3D(bs, face + into * (jut * 0.5 - 0.04)), Vector3(w, hh, jut + 0.08), col, 0.0, 0.05, 0.02)
			# Its brow, a slab over its eyes.
			b.box(Transform3D(bs, face + into * (jut - 0.02) + Vector3.UP * hh * 0.28), Vector3(w * 1.12, hh * 0.19, 0.1), RuinStyle.stone(b.rng), 0.0, 0.02, 0.01)
			# Its eyes and mouth, cut in: hollows, toward navy (§ES).
			var cut: Color = col if TombBuild.bare else Prelit.ao_tint(col, 0.25)
			for e: float in [-1.0, 1.0]:
				b.box(Transform3D(bs, face + into * (jut + 0.004) + u * e * w * 0.23 + Vector3.UP * hh * 0.1), Vector3(w * 0.2, hh * 0.11, 0.012), cut, 0.0, 0.0, 0.0)
			b.box(Transform3D(bs, face + into * (jut + 0.004) - Vector3.UP * hh * 0.28), Vector3(w * 0.47, hh * 0.08, 0.012), cut, 0.0, 0.0, 0.0)
	b.solid = was_solid

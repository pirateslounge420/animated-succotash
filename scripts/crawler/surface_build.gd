class_name SurfaceBuild
extends TombBuild
## The surface's stone (design 9 Oct §FM.7; §EV.4; §FG; worlds.json
## surface.stairhead, stacks and finds; Surface builds it, on the ground
## SurfaceGround lays): cut from the tomb's own stone (§EX.1: one ruin, one
## stone; RuinStyle, FittedStone, the tomb's style), weathered as the
## surface's climate allows (the biome's: dry in the desert, so no moss and
## sand drifted at the walls' feet, §EU.4), never the general palette.
##
##   the stairhead  the ruin over the stair (§EX.5's old way in, continued):
##                  directly over the tomb's opening a stair of block steps
##                  climbs `drop_m` along the way out, between fitted walls,
##                  out of the ground, under a trapezoid portal (the Inca
##                  door: jambs under one lintel, §EX.3) with stubs of its
##                  front wall either side; round it a yard of fitted flags
##                  (yard_m along and across) inside low broken walls
##                  (wall_m), open ahead where you come out; at the stair's
##                  foot a dark doorway, the way on down. You arrive on the
##                  yard out_m past the portal, facing out; walking back down
##                  the steps past down_at_m takes you down (Surface)
##   the stacks     every vent's top (§EV.4, smoke.json vents.surface): a
##                  shaft's stack by ruin kind (outlets.by_ruin; the tomb's a
##                  mound vent, outlets.forms) of stones round a dark mouth,
##                  its lip sooted; a flue's small sooted slot in the ground
##                  (slot_m long and wide, its soot soot_m round)
##   the finds      never required (§FG): ruin remains (a broken run of
##                  fitted wall, fallen blocks, a lintel lying), old camp
##                  marks (a ring of field stones round old ash, charred
##                  sticks, fallen poles), and litter (sherds, a broken pot,
##                  bones), on the open ground clear of the stairhead
##
## Pure: the ground and the layout in, RuinBuilder's arrays out ({"v", "n",
## "c", "m", "cv", "ch"}, scene space), with "stair", "stacks", "slots" and
## "finds" for Surface and the checks.

var land: SurfaceGround
var P: Dictionary = {}
## {"bottom", "mouth", "arrive" (x/z), "n" (x/z out), "side" (x/z), "y"
## (the yard's level), "drop", "run", "half", "yard" (Rect2), "portal_h"}.
var stair: Dictionary = {}
## [{"vent" (index into lay.vents), "foot", "mouth" (Vector3), "form"}].
var stacks: Array = []
## [{"vent", "at" (Vector3)}].
var slots: Array = []
## [{"kind" (remains, camp, litter), "at" (Vector3)}].
var finds: Array = []
## Where the yard's stone stands (x/z rects), kept out of the finds.
var _taken: Array = []


func ground(x: float, z: float) -> float:
	return land.height_at(x, z) if land != null else 0.0


func surface(x: float, z: float) -> float:
	return ground(x, z)


## A face is dressed where it looks into the stairwell (the piece) or out
## into the open air (above the ground), never where it is buried.
func _looks_into(p: Vector2, y: float) -> bool:
	if super._looks_into(p, y):
		return true
	return land != null and land.height_at(p.x, p.y) < y - 0.3


## The stairhead's frame from tomb `lay`'s way out (its first exit) and
## surface `p`: the stair climbs from directly over the opening along the
## way out.
static func stair_frame(lay: Dictionary, p: Dictionary, level: float) -> Dictionary:
	var ex: Dictionary = (lay.get("exits", []) as Array)[0] if not (lay.get("exits", []) as Array).is_empty() else {"p": Vector3.ZERO, "n": Vector3.BACK}
	var n3: Vector3 = ex.n
	var n2 := Vector2(n3.x, n3.z).normalized()
	var bottom := Vector2((ex.p as Vector3).x, (ex.p as Vector3).z)
	var S: Dictionary = p.get("stairhead", {})
	var drop := clampf(float(S.get("drop_m", 4.2)), 1.5, 12.0)
	var slope := maxf(float(TombKit.K.get("stair_slope", 0.6)), 0.2)
	var run := ceilf(drop / slope / 0.5) * 0.5
	var mouth := bottom + n2 * run
	var A: Dictionary = p.get("arrive", {})
	var half := clampf(float(S.get("half_m", 1.1)), 0.6, 2.5)
	var ym: Array = S.get("yard_m", [12.0, 10.0])
	var cell := clampf(float((p.get("ground", {}) as Dictionary).get("cell_m", 4.0)), 1.0, 16.0)
	var yl := maxf(float(ym[0]), run * 0.5 + 6.0)
	# Wide and long enough to cover the dip the stairwell's cut leaves in the
	# ground round it (SurfaceGround.carve_stair: a grid cell either side).
	var yw := maxf(float(ym[1]), maxf(2.0 * half + 4.0, 2.0 * cell + 2.0))
	# The yard: from behind the stair's foot to past where you arrive,
	# centred on the stair's line.
	var back := bottom - n2 * (Delves.WALL + 0.6 + cell + 0.5)
	var front := mouth + n2 * maxf(maxf(float(A.get("out_m", 2.4)) + 3.0, cell + 1.4), yl - run - 1.6)
	var side := Vector2(n2.y, -n2.x)
	var r := Rect2(back + side * yw * 0.5, Vector2.ZERO).expand(back - side * yw * 0.5).expand(front + side * yw * 0.5).expand(front - side * yw * 0.5)
	return {"bottom": bottom, "mouth": mouth, "arrive": mouth + n2 * float(A.get("out_m", 2.4)), "n": n2, "side": side, "y": level,
		"drop": drop, "run": run, "half": half, "yard": r, "front": front, "back": back, "portal_h": 2.3, "exit": ex}


## Build it all on ground `g` over tomb `lay`, surface `p`, seeded
## `seed_value`.
static func make(g: SurfaceGround, lay: Dictionary, p: Dictionary, seed_value: int) -> Dictionary:
	var b := SurfaceBuild.new()
	b.land = g
	b.P = p
	var th := str(lay.get("theme", "tomb"))
	b.stair = stair_frame(lay, p, g.base_y)
	# The stairwell is the one piece whose walls look in (TombBuild's own
	# test); everything else stands in the open air.
	var st: Dictionary = b.stair
	var piece := Delves.piece("stair", st.bottom, st.n, float(st.run), float(st.half), float(st.y) - float(st.drop), float(st.y), float(st.drop) + 2.4)
	piece["id"] = 0
	piece["doors"] = []
	b._lay = {"seed": seed_value, "theme": th, "pieces": [piece], "doors": []}
	b.rng.seed = hash([seed_value, "surface stone"])
	b.up = Vector3.UP
	b.ex = Vector3.RIGHT
	b.ez = Vector3.BACK
	b.ramp_lift = RAMP_LIFT_M
	# Dry: the desert's air (no moss; the fitted stone's climate below).
	b.wet = 0.05
	FittedStone.theme = th
	RuinStyle.theme = th
	b.palette = RuinStyle.tones(th)
	b.shade = 0.0
	b._mseed = hash([seed_value, "surface masonry"])
	# The tomb's stone, weathered in the surface's climate (the world's
	# biome, Surface.climate), not the tomb's damp: for this build only.
	var kept: Variant = FittedStone._climates.get(th)
	var cl := Surface.climate()
	FittedStone._climates[th] = {"moisture": (cl.moisture as Vector2).x * 0.5 + (cl.moisture as Vector2).y * 0.5, "temp_c": (cl.temp_c as Vector2).x * 0.5 + (cl.temp_c as Vector2).y * 0.5, "from": "surface"}
	b._stone_mode()
	b._stairhead()
	b._stacks(lay)
	b._finds(seed_value)
	if kept == null:
		FittedStone._climates.erase(th)
	else:
		FittedStone._climates[th] = kept
	return {"v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch, "stones": b.stones, "faces": b.faces,
		"stair": b.stair, "stacks": b.stacks, "slots": b.slots, "finds": b.finds, "doors": b.doors_built, "tags": b._runs}


# --- The stairhead ----------------------------------------------------------------

func _stairhead() -> void:
	var st := stair
	var n2: Vector2 = st.n
	var side: Vector2 = st.side
	var n3 := Vector3(n2.x, 0.0, n2.y)
	var s3 := Vector3(side.x, 0.0, side.y)
	var y := float(st.y)
	var drop := float(st.drop)
	var run := float(st.run)
	var half := float(st.half)
	var bottom: Vector2 = st.bottom
	var mouth: Vector2 = st.mouth
	var wall := Delves.WALL
	var S: Dictionary = P.get("stairhead", {})
	var wm: Array = S.get("wall_m", [0.35, 1.7])
	_stone_mode()
	# The stairwell's walls: from below its foot up to the yard, the whole
	# run and a little past it each way (their faces into the stairwell
	# dressed, the backs buried); over them a low parapet round three sides,
	# in the open air.
	var w_off := half + wall * 0.5
	var a0 := bottom - n2 * (wall + 0.6)
	var a1 := mouth + n2 * 0.25
	for sd: float in [-1.0, 1.0]:
		_stone_wall(a0 + side * sd * w_off, a1 + side * sd * w_off, y - drop - 0.6, y)
		_stone_wall(a0 + side * sd * w_off, a1 + side * sd * w_off, y - 0.25, y + 0.45)
	# The end wall at its foot, with the dark doorway in it: the way on down.
	var foot := bottom - n2 * 0.6
	var d := {"p": foot, "n": -n2, "half": half - 0.15, "y": y - drop, "h": 2.2, "a": -1, "b": 0, "id": 0}
	var f := _door_frame(d)
	var e0 := foot - side * (half + wall)
	var e1 := foot + side * (half + wall)
	var along := (foot - e0).dot(side)
	_stone_wall(e0, e1, y - drop - 0.6, y, [{"kind": "door", "c": along, "f": f}], wall)
	_stone_wall(e0 - side * 0.3, e1 + side * 0.3, y - 0.25, y + 0.45, [], wall)
	_doorway(d)
	# Beyond the doorway: the dark (a black face a step back, and stone
	# behind it you can't walk through).
	_other_mode()
	var bk := foot - n2 * (wall * 0.5 + 0.9)
	var c3 := Vector3(bk.x, y - drop + 1.15, bk.y)
	var black := Color(0.0, 0.0, 0.01)
	_quad(c3 - s3 * (half + 0.2) - Vector3(0, 1.25, 0), c3 + s3 * (half + 0.2) - Vector3(0, 1.25, 0), c3 + s3 * (half + 0.2) + Vector3(0, 1.25, 0), c3 - s3 * (half + 0.2) + Vector3(0, 1.25, 0), black)
	_quad(c3 - s3 * (half + 0.2) + Vector3(0, 1.25, 0), c3 + s3 * (half + 0.2) + Vector3(0, 1.25, 0), c3 + s3 * (half + 0.2) - Vector3(0, 1.25, 0), c3 - s3 * (half + 0.2) - Vector3(0, 1.25, 0), black)
	_collision_box(Transform3D(Basis(s3, Vector3.UP, n3), Vector3(bk.x, y - drop + 1.5, bk.y)), Vector3(half + 0.3, 1.6, 0.3))
	_stone_mode()
	# The floor at its foot, before the doorway.
	var land_r := _rect(foot + n2 * 0.05, bottom + n2 * 0.9, half + 0.05)
	_pave(land_r, y - drop)
	# The steps, each one block (drawn), the ramp under them (walked).
	var steps := maxi(4, int(round(drop / 0.3)))
	var bs := Basis(s3, Vector3.UP, s3.cross(Vector3.UP))
	solid = false
	for k in steps:
		var t0 := run * k / steps
		var t1 := run * (k + 1) / steps
		var top := y - drop + drop * (k + 1) / steps
		var mid := bottom + n2 * (t0 + t1) * 0.5
		box(Transform3D(bs, Vector3(mid.x, top - 0.25, mid.y)), Vector3(2.0 * half + 0.3, 0.5, t1 - t0 + 0.02), RuinStyle.stone(rng), _growth(0.02), 0.04, 0.015)
	solid = true
	_dramp(Vector3(bottom.x, y - drop, bottom.y), Vector3(mouth.x, y, mouth.y), 2.0 * half)
	# The portal over the stair's mouth (the Inca door, §EX.3), with stubs
	# of its front wall either side, broken off.
	var pd := {"p": mouth, "n": n2, "half": half + 0.1, "y": y, "h": float(st.portal_h), "a": -1, "b": 0, "id": 1}
	_doorway(pd)
	var pf := _door_frame(pd)
	var reach := float(pf.lhalf) + 0.1
	for sd: float in [-1.0, 1.0]:
		var s0 := mouth + side * sd * reach
		var s1 := mouth + side * sd * (reach + rng.randf_range(1.2, 2.4))
		_stone_wall(s0, s1, y - 0.3, y + rng.randf_range(1.0, float(pf.lt) - y - 0.2), [], wall)
	# The yard: fitted flags round the stairwell (it is cut out), and its low
	# broken walls, open ahead where you come out.
	var yard: Rect2 = st.yard
	var cut := _rect(bottom - n2 * (wall + 0.7), mouth + n2 * 0.3, half + wall + 0.05)
	for r: Rect2 in _minus(yard.grow(-0.4), cut):
		if r.size.x > 0.3 and r.size.y > 0.3:
			_pave(r, y)
	_taken.append(yard.grow(1.0))
	var corners := [yard.position, Vector2(yard.end.x, yard.position.y), yard.end, Vector2(yard.position.x, yard.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b2: Vector2 = corners[(i + 1) % 4]
		var mid2 := (a + b2) * 0.5
		var dirw := (b2 - a).normalized()
		# The front wall (across the way out, ahead of the portal) is open in
		# its middle: the way out of the yard.
		var front := absf(dirw.dot(n2)) < 0.3 and (mid2 - mouth).dot(n2) > 0.0
		var len_w := a.distance_to(b2)
		var t := 0.0
		while t < len_w - 0.3:
			var seg := minf(rng.randf_range(1.6, 3.6), len_w - t)
			var gap := rng.randf() < 0.28
			var c_t := t + seg * 0.5
			var at := a + dirw * c_t
			if front and absf((at - mouth).dot(side)) < half + 1.6:
				gap = true
			if not gap:
				var h := rng.randf_range(float(wm[0]), float(wm[1]))
				_stone_wall(a + dirw * t, a + dirw * (t + seg), y - 0.3, y + h, [], 0.6)
				if rng.randf() < 0.5:
					rubble(Vector3(at.x, y, at.y) + Vector3((mid2 - yard.get_center()).normalized().x, 0.0, (mid2 - yard.get_center()).normalized().y) * 1.1, 0.8, rng.randi_range(1, 3))
			t += seg + rng.randf_range(0.0, 0.5)
	# A few blocks fallen from the walls about the yard.
	for k in rng.randi_range(2, 4):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1.0, 3.0)
		var cpos := yard.get_center() + Vector2(cos(ang), sin(ang)) * Vector2(yard.size.x * 0.5 + dist, yard.size.y * 0.5 + dist)
		if (cpos - st.arrive).length() > 3.0:
			rubble(Vector3(cpos.x, ground(cpos.x, cpos.y), cpos.y), 0.9, rng.randi_range(1, 2))


## An axis-aligned rect along the stair's line from `a` to `b` (x/z),
## `half` either side of it.
static func _rect(a: Vector2, b: Vector2, half: float) -> Rect2:
	var dir := (b - a).normalized()
	var side := Vector2(dir.y, -dir.x)
	return Rect2(a + side * half, Vector2.ZERO).expand(a - side * half).expand(b + side * half).expand(b - side * half)


# --- The vents' tops ----------------------------------------------------------------

## Every vent's top on the ground (§EV.4): a shaft's stack (outlets.by_ruin:
## the tomb's mound vent), a flue's sooted slot.
func _stacks(lay: Dictionary) -> void:
	var O: Dictionary = (Tuning.table("smoke").get("outlets", {}) as Dictionary)
	var V: Dictionary = (Tuning.table("smoke").get("vents", {}) as Dictionary)
	var surf: Dictionary = V.get("surface", {})
	var soot := Color(str((O.get("soot", {}) as Dictionary).get("colour", "#0A0C20")))
	var K: Dictionary = P.get("stacks", {})
	var vents: Array = lay.get("vents", [])
	for i in vents.size():
		var v: Dictionary = vents[i]
		var top: Vector3 = v.top
		var gy := ground(top.x, top.z)
		if bool(v.get("sky", false)):
			var form := str((O.get("by_ruin", {}) as Dictionary).get(str((Tuning.table("crawler").get("themes", {}).get(str(lay.get("theme", "tomb")), {}) as Dictionary).get("ruin_kind", "tomb")), (O.get("by_ruin", {}) as Dictionary).get("default", "mound_vent")))
			if str(surf.get("shaft", "outlets.by_ruin")) != "outlets.by_ruin":
				form = str(surf.get("shaft"))
			var mouth_y := _stack(Vector3(top.x, gy, top.z), float(v.d), form, soot, (O.get("forms", {}) as Dictionary).get(form, {}))
			stacks.append({"vent": i, "foot": Vector3(top.x, gy, top.z), "mouth": Vector3(top.x, mouth_y, top.z), "form": form, "d": float(v.d)})
			_taken.append(Rect2(Vector2(top.x, top.z) - Vector2(2.5, 2.5), Vector2(5.0, 5.0)))
		else:
			var pc: Dictionary = lay.pieces[int(v.piece)] if int(v.get("piece", -1)) >= 0 and int(v.piece) < (lay.pieces as Array).size() else {}
			var dir: Vector2 = pc.get("dir", Vector2(1.0, 0.0))
			_slot(Vector3(top.x, gy, top.z), dir, K, soot)
			slots.append({"vent": i, "at": Vector3(top.x, gy, top.z)})


## A shaft's stack (smoke.json outlets.forms[form]): stones round a dark
## mouth `d` wide, height_m tall, the top course sooted; returns the mouth's
## height (y).
func _stack(foot: Vector3, d: float, form: String, soot: Color, f: Dictionary) -> float:
	var hr: Array = f.get("height_m", [0.8, 1.4])
	var h := maxf(rng.randf_range(float(hr[0]), float(hr[1])), 0.3)
	var w := maxf(float(f.get("width_m", 0.9)), d)
	if float(hr[1]) <= 0.0:
		# An open ring (no stack): a ring of stones about the hole.
		h = 0.25
	var ring_r := w * 0.5 + 0.22
	var stones := 8
	_stone_mode()
	var was_foot := foot_y
	foot_y = foot.y
	var courses := maxi(1, int(round(h / 0.4)))
	for c in courses:
		var y0 := foot.y - 0.2 + h * c / courses
		var y1 := foot.y - 0.2 + h * (c + 1) / courses + 0.2 / courses
		var off := rng.randf() * TAU
		for k in stones:
			var ang := off + TAU * k / stones
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var col := RuinStyle.stone(rng)
			if c == courses - 1 and bool(f.get("soot_lip", true)):
				# The lip: soot on the stone (on top, not a second stone).
				col = col.lerp(soot, 0.8)
			var bs := Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir)
			box(Transform3D(bs, foot + dir * ring_r + Vector3(0.0, (y0 + y1) * 0.5 - foot.y, 0.0)), Vector3(TAU * ring_r / stones + 0.06, y1 - y0, 0.42), col, _growth(0.02), 0.06, 0.03)
	foot_y = was_foot
	# Never a way in (smoke.json vents.passable false): its core solid to the
	# lip, so nothing steps down into its mouth.
	_collision_box(Transform3D(Basis.IDENTITY, foot + Vector3(0.0, h * 0.5 - 0.2, 0.0)), Vector3(ring_r, h * 0.5, ring_r))
	# A few stones heaped at its foot, the mound it stands in.
	rubble(foot, w + 0.6, rng.randi_range(2, 4))
	# The dark mouth inside it.
	_other_mode()
	var r := w * 0.5 + 0.02
	var top := foot.y + h - 0.12
	var dark := Color(0.005, 0.005, 0.015)
	for k in 12:
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		_tri(Vector3(foot.x, top, foot.z), Vector3(foot.x + cos(a1) * r, top, foot.z + sin(a1) * r), Vector3(foot.x + cos(a0) * r, top, foot.z + sin(a0) * r), dark)
	_stone_mode()
	return foot.y + h


## A flue's slot in the ground: a narrow dark slit between two small
## stones, soot round it on the ground.
func _slot(at: Vector3, dir: Vector2, K: Dictionary, soot: Color) -> void:
	var sm: Array = K.get("slot_m", [0.55, 0.2])
	var ln := float(sm[0])
	var wd := float(sm[1])
	var u := Vector3(dir.x, 0.0, dir.y).normalized()
	if u.length() < 0.5:
		u = Vector3.RIGHT
	var s := u.cross(Vector3.UP).normalized()
	# The soot: a dark ragged patch lying on the ground.
	_other_mode()
	var sr := float(K.get("soot_m", 0.6))
	var c0 := Vector3(at.x, ground(at.x, at.z) + 0.02, at.z)
	var pts: Array[Vector3] = []
	for k in 9:
		var ang := TAU * k / 9.0
		var rr := sr * rng.randf_range(0.6, 1.0)
		var q := Vector3(at.x + cos(ang) * rr * 1.3, 0.0, at.z + sin(ang) * rr)
		q = Vector3(q.x, ground(q.x, q.z) + 0.02, q.z)
		pts.append(q)
	var sc := soot.lerp(TerrainChunk.SAND, 0.18)
	for k in 9:
		_tri(c0, pts[(k + 1) % 9], pts[k], sc)
	# The slit: black, a hand down.
	var dark := Color(0.004, 0.004, 0.012)
	var hy := c0.y + 0.005
	_quad(c0 - u * ln * 0.5 - s * wd * 0.5 + Vector3(0, 0.005, 0), c0 + u * ln * 0.5 - s * wd * 0.5 + Vector3(0, 0.005, 0), c0 + u * ln * 0.5 + s * wd * 0.5 + Vector3(0, 0.005, 0), c0 - u * ln * 0.5 + s * wd * 0.5 + Vector3(0, 0.005, 0), dark)
	# Its two lining stones.
	_stone_mode()
	solid = false
	var bs := Basis(u, Vector3.UP, s)
	for sd: float in [-1.0, 1.0]:
		var col := RuinStyle.stone(rng).lerp(soot, 0.55)
		box(Transform3D(bs, Vector3(c0.x, hy + 0.03, c0.z) + s * sd * (wd * 0.5 + 0.09)), Vector3(ln + 0.12, 0.12, 0.17), col, 0.0, 0.03, 0.01)
	solid = true


# --- The finds (§FG: never required) ----------------------------------------------

func _finds(seed_value: int) -> void:
	var F: Dictionary = P.get("finds", {})
	var frng := RandomNumberGenerator.new()
	frng.seed = hash([seed_value, "surface finds"])
	var within: Array = F.get("within_m", [40.0, 460.0])
	var apart := float(F.get("apart_m", 30.0))
	var clear := float(F.get("clear_of_stair_m", 24.0))
	var spots: Array = []
	var center: Vector2 = land.center
	var plan := []
	var rr: Array = F.get("remains", [3, 5])
	var cr: Array = F.get("camps", [1, 2])
	var lr: Array = F.get("litter", [5, 9])
	for k in frng.randi_range(int(rr[0]), int(rr[1])):
		plan.append("remains")
	for k in frng.randi_range(int(cr[0]), int(cr[1])):
		plan.append("camp")
	for k in frng.randi_range(int(lr[0]), int(lr[1])):
		plan.append("litter")
	for kind in plan:
		var best := Vector2.INF
		var best_score := -INF
		# A few tries; the remains like high ground, a camp the wash's bank.
		for t in 14:
			var ang := frng.randf() * TAU
			var dist := lerpf(float(within[0]), float(within[1]), sqrt(frng.randf()))
			var q := center + Vector2(cos(ang), sin(ang)) * dist
			if not land.on_floor(q, 30.0) or land.slope_at(q.x, q.y) > 0.28 or land.in_wash(q) > 0.05:
				continue
			if (q - (stair.arrive as Vector2)).length() < clear or (q - center).length() < clear:
				continue
			var ok := true
			for s in spots:
				if (s as Vector2).distance_to(q) < (apart if kind != "litter" else apart * 0.4):
					ok = false
					break
			for r: Rect2 in _taken:
				if r.grow(2.0).has_point(q):
					ok = false
					break
			if not ok:
				continue
			var score := 0.0
			match kind:
				"remains":
					score = land.height_at(q.x, q.y)
				"camp":
					score = -absf(land.wash_at(q).x - 14.0)
				_:
					score = frng.randf()
			if score > best_score:
				best_score = score
				best = q
		if best == Vector2.INF:
			continue
		spots.append(best)
		var at := Vector3(best.x, ground(best.x, best.y), best.y)
		match kind:
			"remains":
				_remains(at, frng)
			"camp":
				_old_camp(at, frng)
			_:
				_litter(at, frng)
		finds.append({"kind": kind, "at": at})


## Ruin remains: a broken run of fitted wall (two or three stretches, each
## its own height), fallen blocks at its foot, sometimes a lintel lying.
func _remains(at: Vector3, frng: RandomNumberGenerator) -> void:
	_stone_mode()
	var ang := frng.randf() * TAU
	var dir := Vector2(cos(ang), sin(ang))
	var total := frng.randf_range(3.0, 7.0)
	var a := Vector2(at.x, at.z) - dir * total * 0.5
	var t := 0.0
	while t < total - 0.4:
		var seg := minf(frng.randf_range(1.2, 2.8), total - t)
		var p0 := a + dir * t
		var p1 := a + dir * (t + seg)
		var lo := minf(ground(p0.x, p0.y), ground(p1.x, p1.y))
		var hi := maxf(ground(p0.x, p0.y), ground(p1.x, p1.y))
		_stone_wall(p0, p1, lo - 0.3, hi + frng.randf_range(0.4, 1.7), [], 0.6)
		t += seg + (frng.randf_range(0.6, 1.6) if frng.randf() < 0.35 else 0.0)
	# A corner turning off it, now and then.
	if frng.randf() < 0.5:
		var turn := Vector2(-dir.y, dir.x) * (1.0 if frng.randf() < 0.5 else -1.0)
		var c0 := a + dir * total
		var c1 := c0 + turn * frng.randf_range(1.5, 3.5)
		var lo2 := minf(ground(c0.x, c0.y), ground(c1.x, c1.y))
		_stone_wall(c0, c1, lo2 - 0.3, lo2 + frng.randf_range(0.3, 1.0), [], 0.6)
	rubble(at + Vector3(-dir.y, 0.0, dir.x) * 1.2, total * 0.4, frng.randi_range(3, 6))
	if frng.randf() < 0.55:
		# A lintel, fallen and lying askew.
		var lp := at + Vector3(-dir.y, 0.0, dir.x) * frng.randf_range(1.5, 2.5)
		var lb := Basis(Vector3.UP, frng.randf() * TAU).rotated(Vector3(dir.x, 0.0, dir.y), frng.randf_range(-0.15, 0.15))
		var was := foot_y
		foot_y = ground(lp.x, lp.z)
		box(Transform3D(lb, Vector3(lp.x, ground(lp.x, lp.z) + 0.2, lp.z)), Vector3(2.1, 0.42, 0.6), RuinStyle.stone(rng), _growth(0.05), 0.06, 0.03)
		foot_y = was
	_taken.append(Rect2(Vector2(at.x, at.z) - Vector2(total, total) * 0.6, Vector2(total, total) * 1.2))


## Old camp marks: a ring of field stones round old ash, charred sticks in
## it, poles fallen beside it, a sherd or two.
func _old_camp(at: Vector3, frng: RandomNumberGenerator) -> void:
	_other_mode()
	var g := ground(at.x, at.z)
	var was_foot := foot_y
	foot_y = g
	for i in 8:
		var ang := TAU * i / 8.0 + frng.randf_range(-0.15, 0.15)
		var p := Vector3(at.x + cos(ang) * 0.6, 0.0, at.z + sin(ang) * 0.6)
		p.y = ground(p.x, p.z) + 0.07
		var col := TerrainChunk.ROCK.lerp(TALUS_STONE, frng.randf_range(0.0, 0.6)).darkened(frng.randf_range(0.0, 0.2))
		boulder(p, Vector3(0.17, 0.11, 0.14), Basis.from_euler(Vector3(0.0, frng.randf() * TAU, 0.0)), col, 0.0)
	# The ash, and the charred ends of the last fire.
	var ash := Color(0.2, 0.19, 0.18)
	ash.a = 0.0
	solid = false
	box(Transform3D(Basis.IDENTITY, Vector3(at.x, g + 0.01, at.z)), Vector3(0.85, 0.04, 0.85), ash, 0.0, 0.01, 0.0)
	for k in frng.randi_range(2, 4):
		var b := Basis(Vector3.UP, frng.randf() * TAU)
		box(Transform3D(b, Vector3(at.x + frng.randf_range(-0.2, 0.2), g + 0.05, at.z + frng.randf_range(-0.2, 0.2))), Vector3(0.45, 0.06, 0.06), CHAR, 0.0, 0.01, 0.005)
	solid = true
	foot_y = was_foot
	# The poles of an old shelter, fallen.
	var heading := frng.randf() * TAU
	for k in frng.randi_range(2, 3):
		var a := heading + frng.randf_range(-0.3, 0.3)
		var c := Vector3(at.x, 0.0, at.z) + Vector3(cos(a), 0.0, sin(a)) * frng.randf_range(1.6, 2.6)
		var dirp := Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5))
		var p0 := c - dirp * 1.1
		var p1 := c + dirp * 1.1
		p0.y = ground(p0.x, p0.z) + 0.05
		p1.y = ground(p1.x, p1.z) + 0.05
		_pole(p0, p1, 0.08)
	_litter(at + Vector3(frng.randf_range(-2.0, 2.0), 0.0, frng.randf_range(-2.0, 2.0)), frng, 2)


## Litter: sherds of a broken pot, the pot itself half buried, bones.
func _litter(at: Vector3, frng: RandomNumberGenerator, n := 0) -> void:
	_other_mode()
	var was_solid := solid
	solid = false
	var count := n if n > 0 else frng.randi_range(2, 5)
	for k in count:
		var p := at + Vector3(frng.randf_range(-1.2, 1.2), 0.0, frng.randf_range(-1.2, 1.2))
		p.y = ground(p.x, p.z)
		match frng.randi() % 4:
			0, 1:
				# A sherd, lying flat-ish.
				var b := Basis.from_euler(Vector3(frng.randf_range(-0.25, 0.25), frng.randf() * TAU, frng.randf_range(-0.25, 0.25)))
				box(Transform3D(b, p + Vector3(0.0, 0.02, 0.0)), Vector3(frng.randf_range(0.08, 0.18), 0.02, frng.randf_range(0.06, 0.14)), CLAY.lightened(frng.randf_range(-0.05, 0.1)), 0.0, 0.005, 0.004)
			2:
				# A pot, broken, half in the sand.
				boulder(p + Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.13, 0.16), Basis.from_euler(Vector3(frng.randf_range(0.3, 0.9), frng.randf() * TAU, 0.0)), CLAY.darkened(0.08), 0.0)
			_:
				# Bones, bleached.
				for j in 2:
					var bb := Basis(Vector3.UP, frng.randf() * TAU)
					box(Transform3D(bb, p + Vector3(frng.randf_range(-0.2, 0.2), 0.03, frng.randf_range(-0.2, 0.2))), Vector3(0.36, 0.05, 0.05), BONE, 0.0, 0.015, 0.008)
	solid = was_solid
	_stone_mode()


## Field stones' second tone (talus rock) and the charred sticks' black.
const TALUS_STONE := Color(0.46, 0.33, 0.24)
const CHAR := Color(0.09, 0.07, 0.06)

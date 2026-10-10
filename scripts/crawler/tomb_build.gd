class_name TombBuild
extends RuinBuilder
## Draws a tomb (TombKit.layout) in its ruin type's one stone (design 6 Oct
## §EX.1, §EX.3; masonry.json styles and style_by_theme, through RuinStyle):
## every built surface is cut from the style's stone, one tint with its own
## small spread, with the walls' joint occlusion (the scene's shade, navy;
## §ES.2), so a room reads as cut from one quarry by one people's hands:
##
##   walls     fitted stone (§EU, FittedStone), every face its own seed; the
##             door frames and the niches are cut out of it, the stones
##             round them fitted to their edges
##   floors    fitted flags: the walls' cutter laid flat, bigger stones,
##             barely pillowed, the joints packed with grit, worn smooth
##             down the middle of a passage and along the ways a room was
##             crossed (floor fitted_flags)
##   ceilings  long single lintel slabs wall to wall, each its own width,
##             settled like the walls, cut round the vents' mouths; in a
##             room one corbel course steps in over the walls first, and a
##             room wider than a slab can span gets four pillars carrying
##             two beams; the hearth room always, its four pillars round the
##             hearth, the shaft open between them (ceiling lintel_slabs,
##             max_span_m, hearth_room four_pillars)
##   doors     trapezoids, narrower at the top (doors top_share), framed by
##             jamb stones under one monolithic lintel, the threshold one
##             stone: the Inca signature
##   niches    the same trapezoid: a sconce's (a stone cup in it; the flame
##             is CrawlerFires'), the catacomb's bone niches
##   holes     the boss's own (Mike's note of 7 Oct; lay.tunnels,
##             BossGround.place_tunnels): round-topped, at the foot of a
##             wall, cut into its fitted stone like the niches, dark inside,
##             a few fallen stones and the scratches of its scales before
##             them; the wall's collision stays whole across them
##   stairs    each step one block, settled like the walls (block_steps)
##   dressing  coffins, the heart's box, the fallen slab, rubble, the
##             hearth's kerb, the airways' carved surrounds, the vents' flues
##
## On top of the stone, not a second stone (rule.on_top): the heart's ochre
## (§BQ), soot (§EV.1), moss and drift (§EU.4). Bone, clay, reed and cloth
## are other materials and stay as they are. Each room's kind (§CJ.8's kit):
##
##   hearth     the smoke shaft over the hearth (§ET.6), a reed mat where you
##              wake, the rescuer's few things
##   crypt      stone coffins in rows along the walls, lids askew
##   catacomb   bone niches in both long walls, the dead's bones and skulls
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

## The heart's ochre (§BQ: "ochre on the ceiling"): paint on the stone.
const OCHRE := Color(0.62, 0.3, 0.14)
## What the geometry is, for the checks (tag runs [first vertex, kind]):
## the style's stone, or another material (bone, clay, gold, reed, hide).
## Vines and drifts are told apart by their material (LEAF_M, DUST_M).
const T_NONE := 0
const T_STONE := 1
const T_OTHER := 2
## The checks: the stone as cut (no joint or contact shade, ochre, soot,
## moss or drift), and RuinBuilder's palette poisoned, so that any read of
## it shows (rule.no_general_palette).
static var bare := false
static var poison := false
const POISON := Color(1.0, 0.0, 1.0)
const SIDES := ["left", "right", "start", "end"]

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
## Fitted stones laid and wall faces dressed, floor flags and ceiling slabs
## laid (checks).
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
## The wall torches' flue slots as cut (_flue_slot_op; checks): [{"bottom",
## "top" (its middle on the wall's face, scene), "w", "depth", "n" (out of
## the wall)}...].
var flue_slots: Array = []
## The collision alone (build's collision_only).
var _collision_only := false
var flags_laid := 0
var slabs_laid := 0
## Per room (piece id): its plan (_plan_room): corbel course, pillars,
## beams, the slabs' way and the spans.
var plans: Dictionary = {}
## The doors as built: [{"id", "foot", "top", "h"}] (the trapezoid).
var doors_built: Array = []
## The catacombs' bone niches: piece id -> [[along, side, sill y]...].
var _bones: Dictionary = {}
var _runs: Array = []
var _tag_now := -1
## Where the build's time went (ms by part; the checks report it).
var ms := {}


func ground(_x: float, _z: float) -> float:
	return _floor


func surface(_x: float, _z: float) -> float:
	return _floor


## The tomb's geometry: RuinBuilder's arrays ({"v", "n", "c", "m", "cv",
## "ch"}; local is scene, the tomb at the origin), what was laid, the
## rooms' plans (pillars, spans), the doors as built and the tag runs.
## `collision_only` (the checks' walks): what is drawn only and never
## touches the builder's own dice (the fitted stones of the walls, floors
## and ceilings, FittedStone; the soot) is left out, so the collision ("cv",
## "ch") is the game's exactly.
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
	# The ruin's style (§EX.1): its walls' masonry and its one stone.
	var th := str(lay.get("theme", "tomb"))
	FittedStone.theme = th
	RuinStyle.theme = th
	b.palette = [POISON, POISON, POISON, POISON, POISON] if poison else RuinStyle.tones(th)
	b.shade = 0.0
	var ms := int(FittedStone.M.get("seed", 0))
	b._mseed = ms if ms != 0 else hash([int(lay.seed), "masonry"])
	b._stone_mode()
	var t := Time.get_ticks_usec()
	for pc in lay.pieces:
		if str(pc.kind) in ["room", "landing"]:
			b.plans[int(pc.id)] = b._plan_room(pc)
	# The catacombs' niches, round the pillars (TombKit.niche_spots).
	for pc in lay.pieces:
		if str(pc.get("room_kind", "")) == "catacomb":
			b._bones[int(pc.id)] = b._bone_columns(pc)
	t = b._took("plans", t)
	for pc in lay.pieces:
		match str(pc.kind):
			"room", "landing":
				b._room(pc)
			"corridor":
				b._corridor(pc)
			"stair":
				b._stair(pc)
	t = Time.get_ticks_usec()
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
	b._kerbs(lay)
	for h in lay.holders:
		if str(h.kind) == "sconce":
			b._sconce_cup(h)
	for a in lay.airways:
		b._airway_surround(a)
	t = b._took("doors_and_dressing", t)
	if not bare and not collision_only:
		b._soot(lay)
	b._took("soot", t)
	return {"v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch, "stones": b.stones, "faces": b.faces,
		"walls": b.wall_faces, "coffins": b.coffins, "niches": b.niches,
		"flags": b.flags_laid, "slabs": b.slabs_laid, "plans": b.plans, "doors": b.doors_built, "flue_slots": b.flue_slots, "tags": b._runs, "ms": b.ms}


## Adds the time since `t0` (usec) to part `part` (ms); returns now.
func _took(part: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	ms[part] = float(ms.get(part, 0.0)) + (now - t0) / 1000.0
	return now


## What the geometry from here on is (the checks' tag runs).
func _tag(t: int) -> void:
	if t != _tag_now:
		_runs.append([_v.size(), t])
		_tag_now = t


## The style's stone: the fitted material (the stone's grain, no painted
## cracks), tagged stone.
func _stone_mode() -> void:
	_tag(T_STONE)
	mat = FittedStone.FITTED_M


## Another material (bone, clay, gold, reed, hide): as it always was drawn.
func _other_mode() -> void:
	_tag(T_OTHER)
	mat = STONE_M


## A moss amount, or none while the checks look at the stone as cut.
func _moss(m: float) -> float:
	return 0.0 if bare else m


func _growth(moss: float) -> float:
	return 0.0 if bare else super(moss)


## The contact shade (RuinBuilder._contact: a block's foot, its underside,
## a doorway's jambs) pulled toward the scene's shade colour, navy, as the
## walls' joints are (Prelit.ao_tint, §ES.2), not toward black; none while
## the checks look at the stone as cut.
func _contact(vs: PackedVector3Array, cs: PackedColorArray, ns: PackedVector3Array, o: Vector3) -> float:
	var grounded := not is_nan(foot_y) and FOOT > 0.0 and not bare
	var inward := Vector3.ZERO
	if inside > 0.0 and inside_at != Vector3.INF:
		inward = Vector3(inside_at.x - o.x, 0.0, inside_at.z - o.z).normalized()
	var under_k := maxf(1.0 - UNDER, 0.01)
	for i in 8:
		for a in 3:
			var sgn := (i >> a) & 1
			var n := ns[a * 2 + sgn]
			var c := cs[i * 3 + a]
			var keep := 1.0
			if a == 1 and sgn == 0:
				# box() took the underside toward black: back to the stone,
				# then into the shade with the rest.
				c = Color(c.r / under_k, c.g / under_k, c.b / under_k, c.a)
				keep *= under_k
			if bare:
				cs[i * 3 + a] = c
				continue
			if grounded:
				keep *= 1.0 - FOOT * exp(-maxf(vs[i * 3 + a].y - foot_y, 0.0) / FOOT_M)
			if inward != Vector3.ZERO and n.dot(inward) > 0.6:
				keep *= 1.0 - inside
			if jamb > 0.0 and a == 0:
				keep *= 1.0 - jamb
			if not (a == 1 and sgn == 0):
				keep *= 1.0 - UNDER * smoothstep(0.3, 0.8, -n.y)
			cs[i * 3 + a] = Prelit.ao_tint(c, keep) if keep < 1.0 else c
	return FOOT * exp(-maxf(o.y - foot_y, 0.0) / FOOT_M) if grounded else 0.0


## Where `p` (scene) is along and across piece `pc`.
static func _aa(pc: Dictionary, p: Vector3) -> Vector2:
	return Delves.along_across(pc, Vector2(p.x, p.z))


## A piece's own axes: along (dir) and across (perp), in the scene.
static func _axes(pc: Dictionary) -> Array:
	var d: Vector2 = pc.dir
	var pv := Delves.perp(d)
	return [Vector3(d.x, 0.0, d.y), Vector3(pv.x, 0.0, pv.y)]


# --- The rooms' plans ---------------------------------------------------------

## A room's plan for its stone (design §EX.3): its corbel course, where its
## ceiling is carried, its catacomb niches and its collapsed corner. The
## slabs span the room's shorter way from corbel to corbel; past
## max_span_m, and in the hearth room always (hearth_room four_pillars),
## four pillars a whole number of modules apart round the room's middle
## (round the hearth) carry two beams the slabs rest on. The pillars keep
## clear of the doors' ways in, the hearth and what lies round it, the
## vents' columns and the room's own things; the dressing keeps clear of
## the pillars.
func _plan_room(pc: Dictionary) -> Dictionary:
	var half := float(pc.half)
	var length := float(pc.len)
	var rc: Dictionary = RuinStyle.val("ceiling.rooms", {})
	var courses := corbel_courses(_lay, pc)
	var step := float(rc.get("corbel_step_m", 0.3)) * courses
	var ch := float(rc.get("corbel_h_m", 0.36)) * courses
	# A big room's plan is its archetype's, hand-built (design §FM.6's room
	# pool, RoomPool): its pillars, a beam down each row, the slabs across.
	if pc.has("big_room"):
		return RoomPool.room_plan(_lay, pc, step, ch)
	var kind := str(pc.get("room_kind", ""))
	var plan := {"step": step, "corbel_h": ch, "pillars": [], "beams": [], "s_axis": 1, "spans": {}}
	if kind == "collapsed":
		plan["corner"] = _collapse_corner(pc, [])
	var sx := length - 2.0 * step
	var sy := 2.0 * half - 2.0 * step
	var s_axis := 1 if sy <= sx else 0
	plan["s_axis"] = s_axis
	if not on_pillars(_lay, pc):
		plan["spans"] = {"slab": minf(sx, sy), "beam": 0.0}
		return plan
	var mid := Vector2(length * 0.5, 0.0)
	if kind == "hearth":
		mid = _aa(pc, _lay.get("hearth", Vector3.ZERO))
	var side := RuinStyle.num("pillars.side_m", 0.6)
	var module := RuinStyle.module_m()
	var bays: Array = RuinStyle.val("pillars.bays_modules", [2, 3, 4])
	var avoid := _avoid(pc, plan)
	var axes: Array = [s_axis, 1 - s_axis]
	# Every pair of bays (the same both ways first), each way of laying
	# the beams: the first that stands with everything clear; else the one
	# that keeps what must be clear (the hearth's things, the fires, the
	# dead, the vents' columns) and crowds the doors' ways in least; else the
	# one that crowds least.
	var pairs: Array = []
	for bay in bays:
		pairs.append([float(bay), float(bay)])
	for i in bays.size():
		for j in bays.size():
			if i != j:
				pairs.append([float(bays[i]), float(bays[j])])
	# A single module's spacing (pillars a module apart, close round the
	# middle) only where nothing wider stands clear: last, and both ways
	# narrow the very last.
	var narrow := func(pr: Array) -> int: return int(float(pr[0]) < 1.5) + int(float(pr[1]) < 1.5)
	var ranked: Array = []
	for k in 3:
		for pr in pairs:
			if narrow.call(pr) == k:
				ranked.append(pr)
	pairs = ranked
	var chosen := {}
	var best := {}
	var best_score := -INF
	for pr in pairs:
		for ax in axes:
			var cand := _pillar_plan(pc, mid, float(pr[0]) * module * 0.5, float(pr[1]) * module * 0.5, int(ax), step)
			if cand.is_empty():
				continue
			var room: Vector2 = _plan_room_left(cand, avoid, side)
			if room.x >= 0.0 and room.y >= 0.0:
				chosen = cand
				break
			var score := (100.0 + room.y) if room.x >= 0.0 else room.x
			if score > best_score:
				best_score = score
				best = cand
		if not chosen.is_empty():
			break
	var doors_clear := not chosen.is_empty()
	if chosen.is_empty():
		chosen = best
	if chosen.is_empty():
		# Nothing stands in it: the slabs span as they can (the checks say).
		plan["spans"] = {"slab": minf(sx, sy), "beam": 0.0}
		return plan
	plan.merge(chosen, true)
	var left: Vector2 = _plan_room_left(chosen, avoid, side)
	plan["clear"] = left.x >= 0.0
	plan["doors_clear"] = doors_clear
	# The collapsed corner, now the pillars stand: one clear of them.
	if kind == "collapsed":
		plan["corner"] = _collapse_corner(pc, chosen.pillars)
	return plan


## How many corbel courses room `pc` of layout `lay` has (ceiling.rooms
## corbel_courses): none where one would hang over a doorway's head with
## less than CORBEL_OVER_DOOR_M of lintel under it (the way out's landing,
## at the corridors' height: it would cross the tops of its doorways).
static func corbel_courses(lay: Dictionary, pc: Dictionary) -> int:
	var th := str(lay.get("theme", ""))
	var rc: Dictionary = RuinStyle.val("ceiling.rooms", {}, th)
	var courses := maxi(int(rc.get("corbel_courses", 1)), 0)
	var door_top := 0.0
	for di in pc.doors:
		var dd: Dictionary = lay.doors[di]
		door_top = maxf(door_top, float(dd.y) + float(dd.h) - float(pc.y0))
	if float(pc.h) - float(rc.get("corbel_h_m", 0.36)) * courses < door_top + CORBEL_OVER_DOOR_M:
		courses = 0
	return courses


## Does room `pc` of layout `lay` want pillars (design §EX.3): its slabs'
## shorter span past its corbel course over the style's max_span_m, or the
## hearth room's four (hearth_room four_pillars)? The layout's alone, so
## the kit gives a room on pillars its four wall torches before it is
## built (TombKit._room_sconces; Mike, 7 Oct). (_plan_room stands them;
## where no spacing fits, a room that wants them has none.)
static func on_pillars(lay: Dictionary, pc: Dictionary) -> bool:
	if str(pc.get("kind", "")) not in ["room", "landing"]:
		return false
	# A big room stands on its archetype's pillars (RoomPool).
	if pc.has("big_room"):
		return not RoomPool.pillars(str(pc.big_room)).is_empty()
	var th := str(lay.get("theme", ""))
	if str(pc.get("room_kind", "")) == "hearth" and str(RuinStyle.val("hearth_room", "", th)) == "four_pillars":
		return true
	var step := float((RuinStyle.val("ceiling.rooms", {}, th) as Dictionary).get("corbel_step_m", 0.3)) * corbel_courses(lay, pc)
	var sx := float(pc.len) - 2.0 * step
	var sy := 2.0 * float(pc.half) - 2.0 * step
	return minf(sx, sy) > RuinStyle.num("max_span_m", 6.0, th)


## How far a pillar's base stands out round the pillar (m; its drums are
## pillars.side_m), and the gap kept between a base and a coffin (more
## than TombKit.coffin_spots allows, so a plan that keeps clear never loses
## one).
const PILLAR_BASE_OVER := 0.08
## The least lintel left under a corbel course over a doorway's head (m);
## a room or landing lower than that has none (_plan_room).
const CORBEL_OVER_DOOR_M := 0.3
const COFFIN_GAP := 0.12


## Where a fallen room `pc` of layout `lay` will have its slab and rubble
## (_collapse: [the corner (along, across), how far its rubble spreads,
## the slab's length]), before the tomb is built (BossGround keeps the
## lair off it).
static func collapse_for(lay: Dictionary, pc: Dictionary) -> Array:
	var keep_theme := RuinStyle.theme
	RuinStyle.theme = str(lay.get("theme", keep_theme))
	var b := TombBuild.new()
	b._lay = lay
	var plan := b._plan_room(pc)
	var out := b._collapse(pc, plan.pillars, b._bays(pc))
	RuinStyle.theme = keep_theme
	return out


## The pillars room `pc` of layout `lay` will stand on, in the scene (x/z),
## [] where it has none. A plan is the layout's alone (no dice, nothing
## built), so the boss's lair keeps off them before the tomb is built
## (BossGround.place_lair).
static func pillars_for(lay: Dictionary, pc: Dictionary) -> Array:
	if str(pc.kind) != "room":
		return []
	var keep_theme := RuinStyle.theme
	RuinStyle.theme = str(lay.get("theme", keep_theme))
	var b := TombBuild.new()
	b._lay = lay
	var plan := b._plan_room(pc)
	RuinStyle.theme = keep_theme
	var out: Array = []
	for q: Vector2 in plan.pillars:
		out.append(_pp(pc, q.x, q.y))
	return out


## Four pillars at `mid` +- (ps along the slabs' way `ax`, pb the other way),
## carrying two beams the other way: {"pillars" [(along, across)...],
## "beams" [[at, from, to]...] (at: along `ax`; from, to: the other way,
## corbel to corbel), "s_axis", "spans" {"slab", "beam"}}, or {} where a
## pillar would stand within a passage of a wall or a span pass max_span_m.
func _pillar_plan(pc: Dictionary, mid: Vector2, ps: float, pb: float, ax: int, step: float) -> Dictionary:
	var half := float(pc.half)
	var length := float(pc.len)
	var side := RuinStyle.num("pillars.side_m", 0.6)
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var max_span := RuinStyle.num("max_span_m", 6.0)
	var lo := Vector2(0.0, -half)
	var hi := Vector2(length, half)
	var bx := 1 - ax
	var pillars: Array = []
	for i: float in [-1.0, 1.0]:
		for j: float in [-1.0, 1.0]:
			var q := Vector2.ZERO
			q[ax] = mid[ax] + i * ps
			q[bx] = mid[bx] + j * pb
			pillars.append(q)
	for q: Vector2 in pillars:
		for k in 2:
			if q[k] - side * 0.5 - lo[k] < 0.9 or hi[k] - (q[k] + side * 0.5) < 0.9:
				return {}
	var s0 := lo[ax] + step
	var s1 := hi[ax] - step
	var b0 := lo[bx] + step
	var b1 := hi[bx] - step
	var slab := maxf(maxf((mid[ax] - ps - bw * 0.5) - s0, 2.0 * ps - bw), s1 - (mid[ax] + ps + bw * 0.5))
	var beam := maxf(maxf((mid[bx] - pb) - b0, 2.0 * pb), b1 - (mid[bx] + pb))
	if slab > max_span + 1e-3 or beam > max_span + 1e-3:
		return {}
	var beams: Array = []
	for i: float in [-1.0, 1.0]:
		beams.append([mid[ax] + i * ps, b0, b1])
	return {"pillars": pillars, "beams": beams, "s_axis": ax, "spans": {"slab": slab, "beam": beam}, "bay": [ps, pb]}


## What a room's pillars keep clear of (its along/across): what must be
## clear, the fires on its floor and the hearth room's mat, where you wake,
## the bundle and the rescuer, the heart's box, a crypt's coffins, the
## wall torches' bays (circles and rects), the vents' columns (holes: the
## beams keep clear of them too); and, where the room allows, the ways in
## from its doors (doors: their sight lines). Not the boss's hole nor the
## burial places: they keep off the pillars (pillars_for; BossGround
## .place_lair, TombKit.coffin_spots, niche_spots).
func _avoid(pc: Dictionary, plan: Dictionary) -> Dictionary:
	var circles: Array = []
	var rects: Array = []
	var holes: Array = []
	var ways: Array = []
	var half := float(pc.half)
	var length := float(pc.len)
	for di in pc.doors:
		var d: Dictionary = _lay.doors[di]
		var s: Array = TombKit.door_side(pc, d)
		var w := float(d.half) + 0.05
		var deep := 2.6
		match str(s[0]):
			"start":
				ways.append(Rect2(0.0, float(s[1]) - w, deep, 2.0 * w))
			"end":
				ways.append(Rect2(length - deep, float(s[1]) - w, deep, 2.0 * w))
			"left":
				ways.append(Rect2(float(s[1]) + length * 0.5 - w, half - deep, 2.0 * w, deep))
			"right":
				ways.append(Rect2(float(s[1]) + length * 0.5 - w, -half, 2.0 * w, deep))
	for hd in _lay.holders:
		if int(hd.piece) == int(pc.id) and str(hd.kind) != "sconce":
			circles.append([_aa(pc, hd.pos), 0.95])
	for v in _lay.get("vents", []):
		if int(v.piece) == int(pc.id):
			var m := _aa(pc, v.mouth)
			var r := float(v.d) * 0.5 + 0.15
			holes.append(Rect2(m - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)))
	match str(pc.get("room_kind", "")):
		"hearth":
			circles.append([_aa(pc, _lay.get("hearth", Vector3.ZERO)), 0.95])
			var w: Array = _lay.get("wake", [Vector3.ZERO, 0.0])
			var wp: Vector3 = w[0]
			var axis := Vector3(sin(float(w[1])), 0.0, cos(float(w[1])))
			for k: float in [-0.7, 0.0, 0.7]:
				circles.append([_aa(pc, wp + axis * k), 0.45])
			# Where you wake: room for the body itself.
			circles.append([_aa(pc, wp), 0.6])
			circles.append([_aa(pc, _lay.get("bundle", Vector3.ZERO)), 0.45])
			var r2: Array = _lay.get("rescuer", [Vector3.ZERO, 0.0])
			circles.append([_aa(pc, r2[0]), 0.5])
		"heart":
			# The dead's box across the room HEART_BOX_M from the far wall,
			# its lid shoved off, and their goods before them (TombKit).
			var hb := TombKit.HEART_BOX
			var a0 := length - TombKit.HEART_GOODS_M - 0.6 - GOODS_REACH
			var a1 := length - TombKit.HEART_BOX_M + hb.x * 0.5 + 1.1
			rects.append(Rect2(a0, -hb.z * 0.5 - 0.3, a1 - a0, hb.z + 0.6))
	# A crypt's coffins' rows (TombKit.coffin_rows; where a pillar can't
	# keep off one, that coffin isn't laid: TombKit.coffin_spots) and the
	# wall torches' bays (§EX.4: where you stand to light one): kept clear
	# by the pillar's base itself, no hand's breadth round it.
	var coffins: Array = []
	if str(pc.get("room_kind", "")) == "crypt":
		var cs := TombKit.COFFIN_SIZE
		for c in TombKit.coffin_rows(_lay, pc):
			var m := Vector2(float(c.along), float(c.sd) * (half - TombKit.COFFIN_IN))
			coffins.append(Rect2(m - Vector2(cs.x, cs.z) * 0.5, Vector2(cs.x, cs.z)).grow(COFFIN_GAP))
	return {"circles": circles, "rects": rects, "holes": holes, "ways": ways, "bays": _bays(pc), "coffins": coffins}


## Do a plan's pillars (their bases and a hand's breadth) and beams keep
## clear of everything in `avoid`, the doors' ways in too?
func _plan_clear(cand: Dictionary, avoid: Dictionary, side: float) -> bool:
	var left: Vector2 = _plan_room_left(cand, avoid, side)
	return left.x >= 0.0 and left.y >= 0.0


## How much room a plan leaves (m): (x) the least clearance between its
## pillars (their bases and a hand's breadth; the bases alone for the bays
## and the coffins) and what must be clear, -10 where a beam crosses a
## vent's column; (y) the least clearance from the doors' ways in.
## Negative where one crowds.
func _plan_room_left(cand: Dictionary, avoid: Dictionary, side: float) -> Vector2:
	var hs := side * 0.5 + 0.2
	var hb := side * 0.5 + PILLAR_BASE_OVER
	var least := INF
	var ways := INF
	for q: Vector2 in cand.pillars:
		var base := Rect2(q - Vector2(hb, hb), Vector2(2.0 * hb, 2.0 * hb))
		# A torch's bay counts three times a coffin: where every spacing
		# crowds something, a coffin gives way (TombKit.coffin_spots) before
		# the way to a torch does.
		for r: Rect2 in avoid.get("bays", []):
			least = minf(least, _rect_gap(r, base) * 3.0)
		for r: Rect2 in avoid.get("coffins", []):
			least = minf(least, _rect_gap(r, base))
		var sq := Rect2(q - Vector2(hs, hs), Vector2(2.0 * hs, 2.0 * hs))
		for c in avoid.circles:
			var cc: Vector2 = c[0]
			var near := Vector2(clampf(cc.x, sq.position.x, sq.end.x), clampf(cc.y, sq.position.y, sq.end.y))
			least = minf(least, near.distance_to(cc) - float(c[1]))
		for r: Rect2 in avoid.rects + avoid.holes:
			least = minf(least, _rect_gap(r, sq))
		for r: Rect2 in avoid.get("ways", []):
			ways = minf(ways, _rect_gap(r, sq))
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var ax := int(cand.s_axis)
	for bm in cand.beams:
		var br := Rect2(float(bm[0]) - bw * 0.5 - 0.05, float(bm[1]), bw + 0.1, float(bm[2]) - float(bm[1])) if ax == 0 else Rect2(float(bm[1]), float(bm[0]) - bw * 0.5 - 0.05, float(bm[2]) - float(bm[1]), bw + 0.1)
		for r: Rect2 in avoid.holes:
			if r.intersects(br):
				least = -10.0
	return Vector2(least, ways)


## The gap between two rectangles (negative: how far they overlap).
static func _rect_gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), maxf(a.position.y - b.end.y, b.position.y - a.end.y))


## The pillars of the room `pc` stands in, in the scene (x/z).
func _pillars_xz(pc: Dictionary) -> Array:
	var out: Array = []
	for q: Vector2 in (plans.get(int(pc.id), {}) as Dictionary).get("pillars", []):
		out.append(_pp(pc, q.x, q.y))
	return out


## Is `p` (scene) at least `r` from every pillar of room `pc`?
func _clear_of_pillars(pc: Dictionary, p: Vector3, r: float) -> bool:
	for q: Vector2 in _pillars_xz(pc):
		if q.distance_to(Vector2(p.x, p.z)) < r:
			return false
	return true


## The catacomb's niches at TombKit.niche_spots (clear of its doors,
## airways, sconces and pillars): two bone niches (niches.bone) to a
## column, or one tall burial niche where a skeleton sits (residents, §FE;
## niches.burial): [[along, side (+1 left, -1 right), the hole's foot y,
## burial]...] (a burial niche's hole starts under its sill stone's top).
func _bone_columns(pc: Dictionary) -> Array:
	var out: Array = []
	var sills: Array = bone_niche().sills
	for s in TombKit.niche_spots(_lay, pc):
		var a := float(s.along)
		var sd := float(s.sd)
		var fy := Delves.floor_of(pc, a)
		if not TombKit.resting_at(_lay, int(pc.id), int(s.i)).is_empty():
			out.append([a, sd, fy + BURIAL_SILL_M - BURIAL_SILL_T, true])
			continue
		for sl in sills:
			out.append([a, sd, fy + float(sl), false])
	return out


## The collapsed room's corner (along, across): the one farthest from its
## doors' ways in, the pillars' bases kept clear where the room allows.
func _collapse_corner(pc: Dictionary, pillars: Array) -> Vector2:
	return _collapse(pc, pillars, _bays(pc))[0]


## The collapse (a fallen slab and its rubble, in one corner): [where
## (along, across), how far its rubble spreads, the slab's length], sized
## to leave a passage from every door (1.7 m from a point a metre inside
## it), clear of the pillars and out of the sconces' `bays` (§EX.4: you
## step up to a wall torch to light it).
func _collapse(pc: Dictionary, pillars: Array, bays: Array = []) -> Array:
	var half := float(pc.half)
	var length := float(pc.len)
	var inner: Array = []
	for di in pc.doors:
		var d: Dictionary = _lay.doors[di]
		var aa := Delves.along_across(pc, d.p)
		var into := Vector2(0.5 * length, 0.0) - aa
		inner.append(aa + (Vector2(signf(into.x), 0.0) if TombKit.door_side(pc, d)[0] in ["start", "end"] else Vector2(0.0, signf(into.y))) * 1.0)
	var spots: Array = []
	for fa: float in [0.22, 0.78, 0.16, 0.84, 0.5]:
		for fc: float in [0.6, -0.6, 0.72, -0.72, 0.84, -0.84]:
			spots.append(Vector2(length * fa, half * fc))
	spots.append(Vector2(length * 0.12, 0.0))
	spots.append(Vector2(length * 0.88, 0.0))
	var best := Vector2(length * 0.8, half * 0.6)
	var best_d := 0.0
	var best_p := INF
	var best_score := -INF
	for q: Vector2 in spots:
		var dmin := INF
		for p2: Vector2 in inner:
			dmin = minf(dmin, p2.distance_to(q))
		var pmin := INF
		for p: Vector2 in pillars:
			pmin = minf(pmin, p.distance_to(q))
		var bmin := INF
		for r: Rect2 in bays:
			bmin = minf(bmin, (q - q.clamp(r.position, r.end)).length())
		# Far from the doors (up to a point), well clear of the pillars, and
		# out of the bays.
		var score := minf(dmin, 4.0) + minf(pmin - 1.6, 0.0) * 3.0 + minf(bmin - 1.6, 0.0) * 3.0
		if score > best_score:
			best_score = score
			best = q
			best_d = dmin
			best_p = minf(pmin, bmin + 0.15)
	var spread := clampf(minf(best_d - 1.7, best_p - 0.45), 0.4, 1.4)
	return [best, spread, clampf(minf(best_d - 1.2, best_p + 0.6), 1.2, 2.6)]


# --- Walls, doors and niches ----------------------------------------------------

## A room: its four walls with their door frames and niches, its fitted
## floor, its ceiling.
func _room(pc: Dictionary) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var length := float(pc.len)
	var plan: Dictionary = plans[int(pc.id)]
	var top := y + h + Delves.SLAB
	var face_top := y + h - float(plan.corbel_h) + 0.05
	var mid := _pp(pc, length * 0.5, 0.0)
	# The walls stand on the room's lowest floor (a sunken court's court,
	# design §FM.6's room pool; any other room's own).
	var y_lo := RoomPool.lowest(pc)
	for side in SIDES:
		var line := _side_line(pc, side)
		var a: Vector2 = line[0]
		var b2: Vector2 = line[1]
		var ops: Array = []
		for di in pc.doors:
			var d: Dictionary = _lay.doors[di]
			var s: Array = TombKit.door_side(pc, d)
			if str(s[0]) == side:
				ops.append({"kind": "door", "c": _run_c(pc, side, float(s[1])), "f": _door_frame(d)})
		ops.append_array(_niche_ops(pc, side))
		ops.append_array(_burrow_ops(pc, side))
		# Only the room's own face is dressed (its back is rock, or a
		# corridor's lane where the door frame's own stones are all that
		# shows), and it stops under the room's corbel course.
		var sd_in := _inner_sd(a, b2, mid)
		var nf := wall_faces.size()
		# (A big room's stone that would only stand hidden behind its steps
		# or under its terraces is left out, RoomPoolBuild.hidden_holes.)
		var hid: Array = RoomPoolBuild.hidden_holes(pc, side, y_lo - 0.1) if pc.has("profile") else []
		_stone_wall(a, b2, y_lo - 0.6, top, ops, Delves.WALL, {sd_in: face_top}, sd_in, hid)
		# On a big room's stepped floor, what lives on its walls (GlowMoss,
		# WallLife) keeps over its highest floor, never inside a step.
		if pc.has("profile"):
			for fi in range(nf, wall_faces.size()):
				(wall_faces[fi] as Dictionary)["floor_y"] = RoomPool.highest(pc)
	# A big room's floor (RoomPoolBuild: its flags, merged bigger, and a
	# stepped floor's blocks; its collision); else the room's fitted flags.
	if pc.has("big_room"):
		RoomPoolBuild.lay_floor(self, pc)
	else:
		_pave_flags(pc)
	_room_ceiling(pc, plan)


## A room's wall `side`: its line [a, b] (x/z, the wall's middle): the side
## walls run past the corners, the end walls between them.
func _side_line(pc: Dictionary, side: String) -> Array:
	var half := float(pc.half)
	var length := float(pc.len)
	var hw := half + Delves.WALL * 0.5
	match side:
		"left":
			return [_pp(pc, -Delves.WALL, hw), _pp(pc, length + Delves.WALL, hw)]
		"right":
			return [_pp(pc, -Delves.WALL, -hw), _pp(pc, length + Delves.WALL, -hw)]
		"start":
			return [_pp(pc, -Delves.WALL * 0.5, -half), _pp(pc, -Delves.WALL * 0.5, half)]
	return [_pp(pc, length + Delves.WALL * 0.5, -half), _pp(pc, length + Delves.WALL * 0.5, half)]


## Where an opening `off` along a room's wall `side` (TombKit.door_side's
## offset: along from the wall's middle for the side walls, across for the
## ends) is along that wall's run (_side_line, from its a).
func _run_c(pc: Dictionary, side: String, off: float) -> float:
	if side in ["left", "right"]:
		return off + float(pc.len) * 0.5 + Delves.WALL
	return off + float(pc.half)


## Which face of the wall a -> b (+1 or -1, as _stone_wall counts them) looks
## toward `toward`.
static func _inner_sd(a: Vector2, b2: Vector2, toward: Vector2) -> float:
	var d := (b2 - a).normalized()
	return 1.0 if Vector2(d.y, -d.x).dot(toward - (a + b2) * 0.5) > 0.0 else -1.0


## The niches in a room's wall `side`: the catacomb's bone niches down its
## long walls, and the sconces of its wall torches (§EX.4, where it has them).
func _niche_ops(pc: Dictionary, side: String) -> Array:
	var ops: Array = []
	var half := float(pc.half)
	if side in ["left", "right"]:
		var sdw := 1.0 if side == "left" else -1.0
		var bn := bone_niche()
		var bur := burial_niche()
		for e in _bones.get(int(pc.id), []):
			if float(e[1]) != sdw:
				continue
			var w := float(bur.w) if bool(e[3]) else float(bn.w)
			var h := float(bur.h) + BURIAL_SILL_T if bool(e[3]) else float(bn.h)
			ops.append({"kind": "niche", "c": float(e[0]) + Delves.WALL, "fw": w, "tw": w * float(bn.top),
				"y0": float(e[2]), "y1": float(e[2]) + h, "depth": float(bur.d) if bool(e[3]) else float(bn.d), "n": -Delves.perp(pc.dir) * sdw, "bone": true})
	for hd in _lay.holders:
		if str(hd.kind) != "sconce" or int(hd.piece) != int(pc.id):
			continue
		var aa := _aa(pc, hd.pos)
		var on := ""
		if absf(aa.y) >= half - 0.06:
			on = "left" if aa.y > 0.0 else "right"
		elif aa.x <= 0.06:
			on = "start"
		elif aa.x >= float(pc.len) - 0.06:
			on = "end"
		if on == side:
			var op := _sconce_op(hd, aa.x + Delves.WALL if side in ["left", "right"] else aa.y + half)
			ops.append(op)
			# Its flue slot up the wall to under the corbel course (whose
			# stone over it is left out, _corbels).
			var plan: Dictionary = plans.get(int(pc.id), {})
			ops.append(_flue_slot_op(hd, op, float(pc.y0) + float(pc.h) - float(plan.get("corbel_h", 0.0)) + 0.05))
	return ops


## A sconce's niche in its wall (design §EX.3 sconce niche_cup): niche_w_m
## wide at its foot, narrower at its top (niches.top_share), niche_h_m high,
## its sill under the cup the flame stands in.
func _sconce_op(hd: Dictionary, c: float) -> Dictionary:
	var sc := sconce_niche()
	var pos: Vector3 = hd.pos
	var nrm: Vector3 = hd.normal
	var y0 := pos.y - float((sc.cup as Vector3).y)
	return {"kind": "niche", "c": c, "fw": float(sc.w), "tw": float(sc.w) * float(sc.top), "y0": y0, "y1": y0 + float(sc.h),
		"depth": float(sc.d), "n": Vector2(nrm.x, nrm.z), "sconce": true}


## The flue slot over a sconce's niche `niche` (design §EV.1: "a narrow
## flue slot in the wall above it"; Mike, 7 Oct: the torches in the wall's
## niches have their vents above them): a narrow upright slot cut into the
## wall from just over the niche's top up to the wall face's top `top_y`,
## where its vent's mouth opens in the ceiling against the wall
## (TombKit._place_vents), the vent's own width (narrower the deeper,
## within the niche's top), as deep into the wall as the niche, dark
## inside and sooted (_soot), so each wall torch shows the way its smoke
## goes.
func _flue_slot_op(hd: Dictionary, niche: Dictionary, top_y: float) -> Dictionary:
	var w := float((TombKit.vents_table().get("flue", {}) as Dictionary).get("width_m", [0.15, 0.3])[0])
	for v in _lay.get("vents", []):
		if str(v.kind) == "sconce" and (v.fire as Vector3).is_equal_approx(hd.pos):
			w = float(v.d)
			break
	w = clampf(w, 0.12, float(niche.tw) - 0.06)
	var y0 := float(niche.y1) + FLUE_SLOT_LIP_M
	return {"kind": "niche", "c": float(niche.c), "fw": w, "tw": w, "y0": y0, "y1": maxf(top_y, y0 + 0.3),
		"depth": float(niche.depth), "n": niche.n, "flue": true}


## The stone left between a sconce's niche and its flue slot over it (m).
const FLUE_SLOT_LIP_M := 0.05


## The style's sconce (design §EX.3 sconce niche_cup): {"w", "h", "d" (the
## niche's width, height and depth), "top" (its top's share of its foot),
## "cup" (the cup's size)}.
static func sconce_niche() -> Dictionary:
	var sc: Dictionary = RuinStyle.val("sconce", {})
	var cup: Array = sc.get("cup_m", [0.22, 0.09, 0.18])
	return {"w": float(sc.get("niche_w_m", 0.4)), "h": float(sc.get("niche_h_m", 0.55)), "d": float(sc.get("niche_d_m", 0.26)),
		"top": RuinStyle.num("niches.top_share", 0.8), "cup": Vector3(float(cup[0]), float(cup[1]), float(cup[2]))}


## How far into its niche a sconce's flame stands, from the wall's face.
static func sconce_inset() -> float:
	return float(sconce_niche().d) * 0.45


## The style's hearth pit (design §EX.1's fire-holders; Mike, 7 Oct: "a
## fire pit made into the ground instead of just having a campfire sitting
## right on the floor"; masonry.json styles hearth, method sunk_pit):
## {"sides", "r" (its middle to its lining's face), "depth", "kerb_w",
## "proud" (the kerb over the floor), "guard" (the unseen guard's top over
## the floor), "ash"}; {} where the style's hearth is the old ring on the
## floor.
static func pit() -> Dictionary:
	var hp: Dictionary = RuinStyle.val("hearth", {})
	if str(hp.get("method", "")) != "sunk_pit":
		return {}
	return {"sides": maxi(int(hp.get("sides", 12)), 3), "r": maxf(float(hp.get("r_m", 0.62)), 0.3), "depth": maxf(float(hp.get("depth_m", 0.32)), 0.05),
		"kerb_w": maxf(float(hp.get("kerb_w_m", 0.24)), 0.05), "proud": float(hp.get("kerb_proud_m", 0.03)), "guard": float(hp.get("guard_m", 0.45)),
		"ash": Color(str(hp.get("ash", "#2a2422")))}


## The pit's outline at `apothem` m from `c` (x/z), its `sides` corners
## counter-clockwise in x/z, a side square to the room's walls first (so a
## four-sided pit lies square in the room).
static func pit_poly(c: Vector3, apothem: float, sides: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rv := apothem / cos(PI / sides)
	for k in sides:
		var a := (k + 0.5) * TAU / sides
		out.append(Vector2(c.x + cos(a) * rv, c.z + sin(a) * rv))
	return FittedStone.ccw(out)


## The catacomb's bone niches (niches.bone): {"w", "h", "d", "top", "sills"
## (their sills' heights over the floor)}.
static func bone_niche() -> Dictionary:
	var bn: Dictionary = RuinStyle.val("niches.bone", {})
	return {"w": float(bn.get("w_m", 0.9)), "h": float(bn.get("h_m", 0.5)), "d": float(bn.get("depth_m", 0.38)),
		"top": RuinStyle.num("niches.top_share", 0.8), "sills": bn.get("sills_m", [0.45, 1.25])}


## The catacomb's burial niche, where a skeleton sits (niches.burial; §FE):
## {"w" (its foot's width), "h" (from the sill stone's top), "d"}.
static func burial_niche() -> Dictionary:
	var bb: Dictionary = RuinStyle.val("niches.burial", {})
	return {"w": float(bb.get("w_m", 1.0)), "h": float(bb.get("h_m", 1.25)), "d": float(bb.get("depth_m", 0.38))}


## The burial niche's sill stone: its top over the floor (where TombKit
## .rest_place sits the skeleton, fy + 0.5), its thickness, and how far it
## stands out from the wall's face (the skeleton sits 0.32 m out).
const BURIAL_SILL_M := 0.5
const BURIAL_SILL_T := 0.12
const BURIAL_OUT_M := 0.62


## The room a door's wall belongs to (every door is in a room's wall).
func _door_room(d: Dictionary) -> Dictionary:
	for id in [int(d.a), int(d.b)]:
		if id < 0:
			continue
		var pc: Dictionary = _lay.pieces[id]
		if str(pc.kind) in ["room", "landing"]:
			return pc
	return {}


## A door's frame (design §EX.3 doors): the opening `fw` wide at its foot
## and `tw` (doors.top_share of it) at its top, `h` high from its floor `y`;
## the jamb stones `jw` wide up its sides; the lintel over it from the
## opening's top to `lt`, reaching `lhalf` either side of its middle. The
## lintel meets the room's corbel course where less than a course of wall
## would be left between them.
func _door_frame(d: Dictionary) -> Dictionary:
	var dr: Dictionary = RuinStyle.val("doors", {})
	var fw := 2.0 * float(d.half)
	var trap := str(dr.get("shape", "trapezoid")) == "trapezoid"
	var tw := fw * (clampf(float(dr.get("top_share", 0.85)), 0.3, 1.0) if trap else 1.0)
	var jw := float(dr.get("jamb_w_m", 0.32))
	var y := float(d.y)
	var h := float(d.h)
	var lt := y + h + float(dr.get("lintel_h_m", 0.42))
	var room := _door_room(d)
	if not room.is_empty():
		var under := float(room.y0) + float(room.h) - float((plans.get(int(room.id), {}) as Dictionary).get("corbel_h", 0.0))
		if under - lt < 0.2:
			lt = under + 0.02
	# (Never under the doorway's head: a lintel always has some height.)
	lt = maxf(lt, y + h + 0.12)
	return {"fw": fw, "tw": tw, "jw": jw, "y": y, "h": h, "lt": lt, "lhalf": tw * 0.5 + jw + float(dr.get("bearing_m", 0.25))}


## A run of fitted-stone wall (design §EU, §EX.3) from a to b (x/z), y_bot
## to y_top, `thick` thick, with its openings `ops` (along the run from a,
## at "c"): {"kind": "door", "f": its frame}, cut through both faces, and
## {"kind": "niche", "fw", "tw", "y0", "y1", "depth", "n" (the face it is
## cut into)}. `tops`: a face's own top (side -> y), where a room's corbel
## course sits on it; `only`: the one face to dress (0: each face that looks
## into a piece). Its core is plain blocks behind the stones (round the
## door frames, whose stones are their own, and the niches), its collision
## plain boxes; every face that looks into a piece of the tomb is dressed
## with fitted stones, the openings cut out, overgrown as its climate
## allows. `hidden`: more holes for the dressed face `only` (its own
## (along, y - y0)), stone that would only stand hidden (behind a big
## room's steps, RoomPoolBuild.hidden_holes): left out.
func _stone_wall(a: Vector2, b2: Vector2, y_bot: float, y_top: float, ops: Array = [], thick: float = Delves.WALL, tops: Dictionary = {}, only := 0.0, hidden: Array = []) -> void:
	var along := b2 - a
	var length := along.length()
	if length < 0.15 or y_top <= y_bot + 0.05:
		return
	_stone_mode()
	var jd := float(FittedStone.relief().get("joint_depth_m", 0.06))
	var dir2 := along / length
	var u := Vector3(dir2.x, 0.0, dir2.y)
	var nx := u.cross(Vector3.UP)
	var bs := Basis(u, Vector3.UP, nx)
	var a3 := Vector3(a.x, 0.0, a.y)
	var floor_y := y_bot + 0.6
	var whole := Rect2(0.0, y_bot, length, y_top - y_bot)
	var frames: Array = []
	var recesses: Array = []
	for op in ops:
		if str(op.kind) == "door":
			var f: Dictionary = op.f
			var fh := float(f.fw) * 0.5 + float(f.jw)
			frames.append(Rect2(float(op.c) - fh, y_bot - 0.01, 2.0 * fh, float(f.lt) - y_bot + 0.01))
		else:
			recesses.append(Rect2(float(op.c) - float(op.fw) * 0.5 - 0.03, float(op.y0) - 0.03, float(op.fw) + 0.06, float(op.y1) - float(op.y0) + 0.06))
	var ct := maxf(thick - 2.0 * jd - 0.02, 0.1)
	var was_solid := solid
	solid = false
	plain = true
	var core_col := RuinStyle.joint(0.3, bare)
	for r: Rect2 in _minus_all(whole, frames + recesses):
		if r.size.x > 0.01 and r.size.y > 0.01:
			box(Transform3D(bs, a3 + u * r.get_center().x + Vector3.UP * r.get_center().y), Vector3(r.size.x + 0.02, r.size.y, ct), core_col, 0.0)
	# Behind each niche (and each of the boss's holes), what is left of the
	# core.
	for op in ops:
		if not str(op.kind) in ["niche", "burrow"]:
			continue
		var n2v: Vector2 = op.n
		var sdn := signf(Vector3(n2v.x, 0.0, n2v.y).dot(nx))
		var back_w := thick * 0.5 - float(op.depth)
		var span := back_w + ct * 0.5
		if span > 0.02:
			var cen := a3 + u * float(op.c) + Vector3.UP * (float(op.y0) + float(op.y1)) * 0.5 + nx * sdn * (back_w - ct * 0.5) * 0.5
			box(Transform3D(bs, cen), Vector3(float(op.fw) + 0.06, float(op.y1) - float(op.y0) + 0.06, span), core_col, 0.0)
	plain = false
	solid = was_solid
	for r: Rect2 in _minus_all(whole, frames):
		if r.size.x > 0.01 and r.size.y > 0.01:
			_collision_box(Transform3D(bs, a3 + u * r.get_center().x + Vector3.UP * r.get_center().y), Vector3(r.size.x * 0.5, r.size.y * 0.5, thick * 0.5))
	var y0 := floor_y - 0.1
	var y1_all := y_top - Delves.SLAB + 0.05
	for sd: float in [-1.0, 1.0]:
		var n2 := Vector2(dir2.y, -dir2.x) * sd
		var probe := (a + b2) * 0.5 + n2 * (thick * 0.5 + 0.45)
		if (only != 0.0 and sd != only) or not _looks_into(probe, floor_y + 1.0):
			continue
		var n := Vector3(n2.x, 0.0, n2.y)
		var o := a3 + n * (thick * 0.5)
		var holes: Array = []
		var clear: Array = []
		for op in ops:
			if str(op.kind) == "door":
				var f: Dictionary = op.f
				holes.append_array(_frame_holes(float(op.c), f, y0))
				clear.append([float(op.c) - float(f.lhalf), float(op.c) + float(f.lhalf)])
			elif (op.n as Vector2).dot(n2) > 0.9:
				if str(op.kind) == "burrow":
					holes.append(_arch(float(op.c), float(op.fw), float(op.y0) - y0, float(op.y1) - y0))
				else:
					holes.append(_trapezoid(float(op.c), float(op.fw), float(op.tw), float(op.y0) - y0, float(op.y1) - y0))
				clear.append([float(op.c) - float(op.fw) * 0.5 - 0.15, float(op.c) + float(op.fw) * 0.5 + 0.15])
		if sd == only:
			holes.append_array(hidden)
		var cl := FittedStone.climate_at(str(_lay.get("theme", "tomb")), int(_lay.seed), Vector3(probe.x, floor_y, probe.y))
		# Every wall face its own seed (partition.seed_per_face), so nothing
		# mirrors across a corridor.
		var mr := RandomNumberGenerator.new()
		mr.seed = hash([_mseed, snappedf(a.x, 0.01), snappedf(a.y, 0.01), snappedf(b2.x, 0.01), snappedf(b2.y, 0.01), sd, snappedf(y_bot, 0.01)])
		var tf := Time.get_ticks_usec()
		var y1 := float(tops.get(sd, y1_all))
		var laid := {}
		if not _collision_only:
			stones += FittedStone.face(self, o, u, n, length, y0, y1, floor_y, cl, mr, holes, clear, laid)
		_took("wall_faces", tf)
		faces += 1
		# For what lives on the stone (§FG: GlowMoss, WallLife): the face and
		# its stones as laid, cut round its openings.
		wall_faces.append({"o": o, "u": u, "n": n, "length": length, "y0": y0, "y1": y1, "floor_y": floor_y, "seed": mr.seed,
			"probe": Vector3(probe.x, floor_y, probe.y), "cells": laid.get("cells", []), "heights": laid.get("heights", PackedVector2Array())})
		for op in ops:
			if str(op.kind) == "niche" and (op.n as Vector2).dot(n2) > 0.9:
				_hollow(o, u, n, op)
			elif str(op.kind) == "burrow" and (op.n as Vector2).dot(n2) > 0.9:
				_burrow(o, u, n, op)
	_stone_mode()


## A plain run of fitted-stone wall (no openings): RuinBuilder's callers
## get the tomb's stone too.
func _dwall(a: Vector2, b2: Vector2, y_bot: float, y_top: float, thick: float = 0.6) -> void:
	_stone_wall(a, b2, y_bot, y_top, [], thick)


## A trapezoid (counter-clockwise) `fw` wide at y0 and `tw` at y1, its
## middle at x `c`.
static func _trapezoid(c: float, fw: float, tw: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(c - fw * 0.5, y0), Vector2(c + fw * 0.5, y0), Vector2(c + tw * 0.5, y1), Vector2(c - tw * 0.5, y1)])


## A door frame's holes in a face (its own coordinates, y up from `y0`): the
## frame's outer trapezoid (the opening and its jamb stones) from under the
## face's foot to the opening's top, and the lintel's rectangle over it.
func _frame_holes(c: float, f: Dictionary, y0: float) -> Array:
	var y := float(f.y)
	var h := maxf(float(f.h), 0.1)
	var lean := (float(f.fw) - float(f.tw)) * 0.5 / h
	var foot := y0 - 0.06
	var w0 := float(f.fw) * 0.5 + float(f.jw) - lean * (foot - y)
	var w1 := float(f.tw) * 0.5 + float(f.jw)
	var hi := y + h - y0
	var lh := float(f.lhalf)
	return [PackedVector2Array([Vector2(c - w0, foot - y0), Vector2(c + w0, foot - y0), Vector2(c + w1, hi), Vector2(c - w1, hi)]),
		PackedVector2Array([Vector2(c - lh, hi - 0.005), Vector2(c + lh, hi - 0.005), Vector2(c + lh, float(f.lt) - y0), Vector2(c - lh, float(f.lt) - y0)])]


## A niche's inside (design §EX.3 niches: the trapezoid): its sill, its
## battered sides, its top and its back, `depth` into the wall from the face
## at `o` (n out of it), the style's stone, darker the deeper.
func _hollow(o: Vector3, u: Vector3, n: Vector3, op: Dictionary) -> void:
	_stone_mode()
	var c := float(op.c)
	var fw := float(op.fw) * 0.5
	var tw := float(op.tw) * 0.5
	var y0 := float(op.y0)
	var y1 := float(op.y1)
	var d := float(op.depth)
	var col := RuinStyle.stone(rng)
	var mouth: Color = col if bare else Prelit.ao_tint(col, 0.8)
	var deep: Color = col if bare else Prelit.ao_tint(col, 0.42)
	if bool(op.get("flue", false)) and not bare:
		# A flue slot is caked with the smoke's soot inside (§EV.1, outlets
		# soot), so it shows dark over its lit niche: the way the smoke goes.
		# The soot lies on the stone (rule.on_top), drawn as the drifts are
		# (DUST_M), so the night's pull of the stone toward slate doesn't
		# lift it (ruin.gdshader).
		var soot := Color(str(((Tuning.table("smoke").get("outlets", {}) as Dictionary).get("soot", {}) as Dictionary).get("colour", "#0A0C20")))
		mouth = col.lerp(soot, 0.85)
		deep = soot
		_tag(T_OTHER)
		mat = FittedStone.DUST_M
	mouth.a = 0.0
	deep.a = 0.0
	var w0 := 0.01
	var bl0 := o + u * (c - fw) + Vector3.UP * y0 + n * w0
	var br0 := o + u * (c + fw) + Vector3.UP * y0 + n * w0
	var tr0 := o + u * (c + tw) + Vector3.UP * y1 + n * w0
	var tl0 := o + u * (c - tw) + Vector3.UP * y1 + n * w0
	var bld := bl0 - n * (d + w0)
	var brd := br0 - n * (d + w0)
	var trd := tr0 - n * (d + w0)
	var tld := tl0 - n * (d + w0)
	var hollow := o + u * c + Vector3.UP * (y0 + y1) * 0.5 - n * d * 0.5
	if bool(op.get("flue", false)):
		flue_slots.append({"bottom": o + u * c + Vector3.UP * y0, "top": o + u * c + Vector3.UP * y1, "w": 2.0 * fw, "depth": d, "n": n})
	_inside_quad([bl0, br0, brd, bld], [mouth, mouth, deep, deep], Vector3.UP, hollow)
	_inside_quad([tl0, tr0, trd, tld], [mouth, mouth, deep, deep], Vector3.DOWN, hollow)
	var nl := (tl0 - bl0).cross(n).normalized()
	_inside_quad([bl0, tl0, tld, bld], [mouth, mouth, deep, deep], nl if nl.dot(hollow - bl0) > 0.0 else -nl, hollow)
	var nr := (tr0 - br0).cross(n).normalized()
	_inside_quad([br0, tr0, trd, brd], [mouth, mouth, deep, deep], nr if nr.dot(hollow - br0) > 0.0 else -nr, hollow)
	_inside_quad([bld, brd, trd, tld], [deep, deep, deep, deep], n, hollow)
	_stone_mode()


## The boss's own holes in piece `pc`'s wall `side` (Mike's note of 7 Oct:
## "they may have their own tunnels"; BossGround.place_tunnels, lay
## tunnels): each an opening for _stone_wall, round-topped, from the floor
## up h_m, w_m wide, cut depth_m in (along the wall's run from its `a`).
func _burrow_ops(pc: Dictionary, side: String) -> Array:
	var ops: Array = []
	var holes: Array = (_lay.get("tunnels", {}) as Dictionary).get("holes", [])
	for i in holes.size():
		var h: Dictionary = holes[i]
		if int(h.piece) != int(pc.id) or str(h.side) != side:
			continue
		var c := _run_c(pc, side, float(h.off)) if str(pc.kind) in ["room", "landing"] else float(h.off) + float(pc.len) * 0.5
		var fy := float((h.pos as Vector3).y)
		var n: Vector3 = h.n
		ops.append({"kind": "burrow", "c": c, "fw": float(h.w), "tw": float(h.w), "y0": fy - 0.02, "y1": fy + float(h.h), "depth": float(h.depth), "n": Vector2(n.x, n.z), "hole": i})
	return ops


## A round-topped opening (counter-clockwise, convex): `w` wide, its middle
## at `c`, from `yb` up to `yt`, the top a half circle.
static func _arch(c: float, w: float, yb: float, yt: float) -> PackedVector2Array:
	var r := w * 0.5
	var spring := maxf(yt - r, yb + 0.02)
	var out := PackedVector2Array([Vector2(c - r, yb), Vector2(c + r, yb)])
	var steps := 8
	for k in steps + 1:
		var a := PI * float(k) / steps
		out.append(Vector2(c + r * cos(a), spring + r * sin(a)))
	return out


## The inside of one of the boss's holes (Mike's note of 7 Oct; op from
## _burrow_ops) cut into a wall's face at `o` (n out of it): its sill on
## the floor, its sides and round vault going depth_m in, darker the
## deeper, and its back (the boss hangs its dark in front of it, Boss), in
## the style's stone; round its foot a few loose stones, and the scratches
## of scales on the floor before it. None of it solid: the wall's collision
## stays whole across the hole, so you can't fit. Its own dice (the
## builder's are kept for the rest of the tomb).
func _burrow(o: Vector3, u: Vector3, n: Vector3, op: Dictionary) -> void:
	var keep_rng := rng
	rng = RandomNumberGenerator.new()
	rng.seed = hash([int(_lay.seed), "burrow", int(op.get("hole", 0))])
	var was_solid := solid
	solid = false
	_stone_mode()
	var c := float(op.c)
	var w := float(op.fw)
	var fy := float(op.y0) + 0.02
	var yt := float(op.y1)
	var d := float(op.depth)
	var col := RuinStyle.stone(rng)
	var mouth: Color = col if bare else Prelit.ao_tint(col, 0.7)
	var deep: Color = col if bare else Prelit.ao_tint(col, 0.3)
	mouth.a = 0.0
	deep.a = 0.0
	var arch := _arch(c, w, fy, yt)
	var w0 := 0.01
	var at := func(q: Vector2, depth: float) -> Vector3:
		return o + u * q.x + Vector3.UP * q.y + n * (w0 - depth)
	var mid := Vector2(c, (fy + yt) * 0.5)
	var hollow: Vector3 = at.call(mid, d * 0.5)
	# The sides and the vault: the outline but its foot, taken in.
	var nv := arch.size()
	for k in range(1, nv):
		var p: Vector2 = arch[k]
		var q: Vector2 = arch[(k + 1) % nv]
		var e := (q - p)
		var inward := Vector2(-e.y, e.x).normalized()
		if inward.dot(mid - (p + q) * 0.5) < 0.0:
			inward = -inward
		var nrm := (u * inward.x + Vector3.UP * inward.y).normalized()
		_inside_quad([at.call(p, 0.0), at.call(q, 0.0), at.call(q, d + w0), at.call(p, d + w0)], [mouth, mouth, deep, deep], nrm, hollow)
	# The sill, on the floor from the face in.
	_inside_quad([at.call(arch[0], 0.0), at.call(arch[1], 0.0), at.call(arch[1], d + w0), at.call(arch[0], d + w0)], [mouth, mouth, deep, deep], Vector3.UP, hollow)
	# The back: the outline at its depth, facing out.
	var back_mid: Vector3 = at.call(Vector2(c, (fy + yt) * 0.5), d + w0)
	var behind := back_mid - n * 1.0
	for k in nv:
		var p2: Vector2 = arch[k]
		var q2: Vector2 = arch[(k + 1) % nv]
		_tri_n(back_mid, at.call(p2, d + w0), at.call(q2, d + w0), n, n, n, deep, deep, deep, behind)
	# A few stones fallen at its foot, either side of its mouth.
	var foot := o + u * c + Vector3.UP * fy
	for k in rng.randi_range(3, 5):
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var p3 := foot + u * sgn * rng.randf_range(w * 0.5 + 0.08, w * 0.5 + 0.45) + n * rng.randf_range(0.05, 0.4)
		var size := Vector3(rng.randf_range(0.07, 0.14), rng.randf_range(0.04, 0.08), rng.randf_range(0.06, 0.12))
		var bs := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
		var sc := RuinStyle.stone(rng)
		box(Transform3D(bs, p3 + Vector3.UP * size.y * 0.4), size, sc if bare else Prelit.ao_tint(sc, 0.85), 0.0, 0.02, 0.01)
	# Its scales' scratches: thin grooves on the floor before it, fanning out
	# from its mouth, in the floor's shade.
	for k in rng.randi_range(4, 6):
		var ang := rng.randf_range(-0.35, 0.35)
		var along := n.rotated(Vector3.UP, ang)
		var start := foot + u * rng.randf_range(-w * 0.35, w * 0.35) + n * rng.randf_range(0.02, 0.12)
		var length := rng.randf_range(0.3, 0.6)
		var gb := Basis(along.cross(Vector3.UP).normalized(), Vector3.UP, along)
		var gc := RuinStyle.stone(rng)
		box(Transform3D(gb, start + along * length * 0.5 + Vector3.UP * 0.011), Vector3(0.014, 0.01, length), gc if bare else Prelit.ao_tint(gc, 0.45), 0.0, 0.0, 0.0)
	solid = was_solid
	rng = keep_rng
	_stone_mode()


## A quad of a hollow's inside, facing the hollow (normal `nrm`).
func _inside_quad(ps: Array, cs: Array, nrm: Vector3, hollow: Vector3) -> void:
	var mid: Vector3 = (ps[0] + ps[1] + ps[2] + ps[3]) * 0.25
	var behind := mid - (hollow - mid)
	_tri_n(ps[0], ps[1], ps[2], nrm, nrm, nrm, cs[0], cs[1], cs[2], behind)
	_tri_n(ps[0], ps[2], ps[3], nrm, nrm, nrm, cs[0], cs[2], cs[3], behind)


## A door (design §EX.3 doors, the Inca signature): the threshold one stone
## across the opening and through the wall; the jambs battered, narrower at
## the top (doors top_share), each three stones of the style stacked up its
## side, the doorway's shade in their faces (jamb); and over them one
## monolithic lintel.
func _doorway(d: Dictionary) -> void:
	var f := _door_frame(d)
	var p: Vector2 = d.p
	var nv: Vector2 = d.n
	var t := Vector3(-nv.y, 0.0, nv.x)
	var bs := Basis(t, Vector3.UP, t.cross(Vector3.UP))
	var thick := Delves.WALL
	var y := float(f.y)
	var h := float(f.h)
	var fw := float(f.fw)
	var tw := float(f.tw)
	var jw := float(f.jw)
	var c3 := Vector3(p.x, y, p.y)
	_stone_mode()
	var was_foot := foot_y
	foot_y = y
	# The threshold stone stands a hair proud of the flags; what you walk on
	# is flush with the floor (a lip of a centimetre stops a body coming at
	# it on the slant).
	var was_solid := solid
	solid = false
	box(Transform3D(bs, c3 + Vector3(0.0, 0.012 - 0.15, 0.0)), Vector3(fw + 0.24, 0.3, thick + 0.08), RuinStyle.stone(rng), _growth(0.04), 0.03, 0.01)
	solid = was_solid
	_collision_box(Transform3D(bs, c3 + Vector3(0.0, -0.15, 0.0)), Vector3((fw + 0.24) * 0.5, 0.15, (thick + 0.08) * 0.5))
	var lean := atan2((fw - tw) * 0.5, h)
	for sd: float in [-1.0, 1.0]:
		var cuts: Array[float] = [0.0, 0.34 + rng.randf_range(-0.06, 0.06), 0.68 + rng.randf_range(-0.06, 0.06), 1.0]
		for k in 3:
			var ya := y - 0.1 if k == 0 else y + h * cuts[k]
			var yb := y + h * cuts[k + 1]
			var ym := (ya + yb) * 0.5
			var open := fw * 0.5 - (fw - tw) * 0.5 * (ym - y) / h
			jamb = JAMB
			box(Transform3D(bs * Basis(Vector3.BACK, sd * lean), c3 + t * sd * (open + jw * 0.5) + Vector3.UP * (ym - y)),
				Vector3(jw, (yb - ya) / cos(lean) + 0.012, thick + 0.04), RuinStyle.stone(rng), _growth(0.06), 0.035, 0.012)
			jamb = 0.0
	foot_y = was_foot
	var lt := float(f.lt)
	box(Transform3D(bs, c3 + Vector3.UP * ((h + lt - y) * 0.5)), Vector3(2.0 * float(f.lhalf), lt - y - h, thick + 0.05), RuinStyle.stone(rng), _growth(0.04), 0.05, 0.015)
	doors_built.append({"id": int(d.id), "foot": fw, "top": tw, "h": h})
	# A way out's opening (b -1, §EX.5): its floor and stone run on outside.
	if int(d.b) < 0:
		var pa: Dictionary = _lay.pieces[int(d.a)]
		_outside(d, maxf(float(pa.y0), float(pa.y1)) + float(pa.h) + Delves.SLAB)


# --- Floors and ceilings --------------------------------------------------------

## A piece's floor (design §EX.3 floor fitted_flags): FittedStone's flags,
## worn down the middle of a passage and along the ways a room was crossed;
## one collision slab under them.
func _pave_flags(pc: Dictionary) -> void:
	var y := float(pc.y0)
	var half := float(pc.half)
	var length := float(pc.len)
	var ax := _axes(pc)
	var o2 := _pp(pc, -0.05, -(half + 0.05))
	var wear := _wear(pc)
	var cl := FittedStone.climate_at(str(_lay.get("theme", "tomb")), int(_lay.seed), _at(pc, length * 0.5, 0.0))
	var fr := RandomNumberGenerator.new()
	fr.seed = hash([_mseed, int(pc.id), "floor"])
	_stone_mode()
	var tf := Time.get_ticks_usec()
	# The hearth's pit (pit(); _hearth_pit lines it): its outline, kerb and
	# all, kept out of the hearth room's flags and their collision.
	var hole := PackedVector2Array()
	var pt := pit()
	if str(pc.get("room_kind", "")) == "hearth" and not pt.is_empty():
		hole = pit_poly(_lay.get("hearth", Vector3.ZERO), float(pt.r) + float(pt.kerb_w), int(pt.sides))
	var fo := Vector3(o2.x, y, o2.y)
	if not _collision_only:
		var holes: Array = []
		if not hole.is_empty():
			var local := PackedVector2Array()
			var au: Vector3 = ax[0]
			var av: Vector3 = ax[1]
			for q in hole:
				var d3 := Vector3(q.x, y, q.y) - fo
				local.append(Vector2(d3.dot(au), d3.dot(av)))
			holes.append(FittedStone.ccw(local))
		flags_laid += FittedStone.flags(self, fo, ax[0], ax[1], length + 0.1, 2.0 * half + 0.1, cl, fr,
			func(x: float, yy: float) -> float: return float(wear.call(x - 0.05, yy - half - 0.05)), holes)
	_took("floors", tf)
	var r := Delves.rect_of(pc, 0.05)
	if hole.is_empty():
		_collision_box(Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, y - 0.15, r.get_center().y)), Vector3(r.size.x * 0.5, 0.15, r.size.y * 0.5))
		return
	# The floor round the pit: the room's slab less the pit, in convex
	# pieces (the pit's own floor and guard are _hearth_pit's).
	var rect := FittedStone.ccw(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	for poly: PackedVector2Array in FittedStone.cut(rect, [hole]):
		_prism(poly, y - 0.3, y)


## A convex prism of collision (RuinBuilder's hull points): x/z outline
## `poly`, from `y0` up to `y1`.
func _prism(poly: PackedVector2Array, y0: float, y1: float) -> void:
	var pts := PackedVector3Array()
	for q in poly:
		pts.append(Vector3(q.x, y0, q.y))
		pts.append(Vector3(q.x, y1, q.y))
	_ch.append(pts)


## Flags over a rectangle (RuinBuilder's callers): the tomb's fitted flags,
## unworn, with their collision.
func _pave(r: Rect2, y: float, _skip := Rect2()) -> void:
	var fr := RandomNumberGenerator.new()
	fr.seed = hash([_mseed, r.position, "pave"])
	_stone_mode()
	if not _collision_only:
		flags_laid += FittedStone.flags(self, Vector3(r.position.x, y, r.position.y), Vector3.RIGHT, Vector3.BACK, r.size.x, r.size.y,
			FittedStone.climate_at(str(_lay.get("theme", "tomb")), int(_lay.seed), Vector3(r.get_center().x, y, r.get_center().y)), fr,
			func(_x: float, _y: float) -> float: return 0.0)
	_collision_box(Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, y - 0.15, r.get_center().y)), Vector3(r.size.x * 0.5, 0.15, r.size.y * 0.5))


## Where feet went across piece `pc` (floor wear): a Callable (along,
## across) -> 0-1. A corridor's or stair's middle (floor.wear.band of its
## half width); a room's ways from each door to what it holds (the hearth,
## the dead at the heart's end, else its middle).
func _wear(pc: Dictionary) -> Callable:
	var half := float(pc.half)
	var band := maxf(RuinStyle.num("floor.wear.band", 0.7), 0.05)
	if str(pc.kind) != "room":
		return func(_al: float, ac: float) -> float: return 1.0 - smoothstep(0.15, 1.0, absf(ac) / (half * band))
	var length := float(pc.len)
	var focus := Vector2(length * 0.5, 0.0)
	match str(pc.get("room_kind", "")):
		"hearth":
			focus = _aa(pc, _lay.get("hearth", Vector3.ZERO))
		"heart":
			focus = Vector2(length - 2.7, 0.0)
	var ways: Array = []
	for di in pc.doors:
		var d: Dictionary = _lay.doors[di]
		ways.append([Delves.along_across(pc, d.p), focus])
	return func(al: float, ac: float) -> float:
		var q := Vector2(al, ac)
		var best := INF
		for w in ways:
			var a2: Vector2 = w[0]
			var b2: Vector2 = w[1]
			var ab := b2 - a2
			var t := clampf((q - a2).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
			best = minf(best, q.distance_to(a2 + ab * t))
		return 1.0 - smoothstep(0.3, 1.2, best)


## A corridor's or stair's ceiling, or any piece's without a corbel course:
## lintel slabs across it, wall to wall (ceiling passages lintel_slabs);
## ochre in the heart (§BQ).
func _ceiling(pc: Dictionary, ochre: bool) -> void:
	var half := float(pc.half)
	_slab_ceiling(pc, 1, [[-half - 0.25, half + 0.25]], -0.05, float(pc.len) + 0.05, ochre)


## A room's ceiling (design §EX.3 ceiling): the corbel course stepping in
## over its walls (rooms.corbel_courses, corbel_step_m), the pillars and
## beams where its plan has them, and the lintel slabs spanning its shorter
## way, corbel to corbel or onto the beams; ochre in the heart (§BQ).
func _room_ceiling(pc: Dictionary, plan: Dictionary) -> void:
	var half := float(pc.half)
	var length := float(pc.len)
	var step := float(plan.step)
	var ch := float(plan.corbel_h)
	if ch > 0.0:
		_corbels(pc, step, ch)
	_pillars_and_beams(pc, plan)
	var ax := int(plan.s_axis)
	var lo := Vector2(step, -half + step)
	var hi := Vector2(length - step, half - step)
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var cuts: Array[float] = [lo[ax]]
	var at: Array[float] = []
	for bm in plan.beams:
		at.append(float(bm[0]))
	at.sort()
	for s in at:
		cuts.append(s - bw * 0.5)
		cuts.append(s + bw * 0.5)
	cuts.append(hi[ax])
	var regions: Array = []
	for i in range(0, cuts.size() - 1, 2):
		regions.append([cuts[i] - 0.1, cuts[i + 1] + 0.1])
	_slab_ceiling(pc, ax, regions, lo[1 - ax] - 0.1, hi[1 - ax] + 0.1, str(pc.get("room_kind", "")) == "heart")


## Lintel slabs over piece `pc` (design §EX.3 ceiling lintel_slabs): each of
## `regions` ([from, to] along axis `ax`, the way the slabs span: 0 along
## the piece, 1 across) laid with single slabs from b_lo to b_hi the other
## way, each slab_w_m wide (each its own, the joints a little out of
## true), cut round the vents' mouths; behind them the joints' back; the
## collision one slab over the piece, the mouths left open.
func _slab_ceiling(pc: Dictionary, ax: int, regions: Array, b_lo: float, b_hi: float, ochre: bool) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var ws: Array = RuinStyle.val("ceiling.slab_w_m", [0.5, 0.9])
	var w0 := maxf(float(ws[0]), 0.1)
	var w1 := maxf(float(ws[1]), w0)
	var sr := RandomNumberGenerator.new()
	sr.seed = hash([_mseed, int(pc.id), "slabs"])
	var cells: Array = []
	var backs: Array = []
	for reg in regions:
		var s0 := float(reg[0])
		var s1 := float(reg[1])
		if s1 - s0 < 0.05:
			continue
		var joints: Array = [[b_lo, b_lo]]
		var b := b_lo
		while true:
			var w := sr.randf_range(w0, w1)
			if b + w > b_hi - w0 * 0.6:
				break
			b += w
			joints.append([b + sr.randf_range(-0.03, 0.03), b + sr.randf_range(-0.03, 0.03)])
		joints.append([b_hi, b_hi])
		for i in joints.size() - 1:
			var j0: Array = joints[i]
			var j1: Array = joints[i + 1]
			if ax == 1:
				cells.append(PackedVector2Array([Vector2(float(j0[0]), s0), Vector2(float(j1[0]), s0), Vector2(float(j1[1]), s1), Vector2(float(j0[1]), s1)]))
			else:
				cells.append(PackedVector2Array([Vector2(s0, float(j0[0])), Vector2(s1, float(j0[1])), Vector2(s1, float(j1[1])), Vector2(s0, float(j1[0]))]))
		backs.append(Rect2(b_lo, s0, b_hi - b_lo, s1 - s0) if ax == 1 else Rect2(s0, b_lo, s1 - s0, b_hi - b_lo))
	var holes: Array = []
	var hole_rects: Array = []
	for v in _lay.get("vents", []):
		if int(v.piece) != int(pc.id):
			continue
		var m := _aa(pc, v.mouth)
		var r := float(v.d) * 0.5
		holes.append(FittedStone.ccw(PackedVector2Array([m + Vector2(-r, -r), m + Vector2(r, -r), m + Vector2(r, r), m + Vector2(-r, r)])))
		hole_rects.append(Rect2(m - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)))
	var cut_backs: Array = []
	for r: Rect2 in backs:
		cut_backs.append_array(_minus_all(r, hole_rects))
	var ax3 := _axes(pc)
	var c2: Vector2 = pc.c
	var fo := Vector3(c2.x, y + h, c2.y)
	_stone_mode()
	var from := _v.size()
	var tf := Time.get_ticks_usec()
	if not _collision_only:
		slabs_laid += FittedStone.slabs(self, fo, ax3[0], ax3[1], Vector3.DOWN, cells, sr, holes, cut_backs)
	_took("ceilings", tf)
	if ochre and not bare:
		for i in range(from, _v.size()):
			var col := _c[i]
			var al := col.a
			col = col.lerp(OCHRE, 0.55)
			col.a = al
			_c[i] = col
	var bs := Basis(ax3[0], Vector3.UP, (ax3[0] as Vector3).cross(Vector3.UP))
	for r: Rect2 in _minus_all(Rect2(-0.05, -half - Delves.WALL, length + 0.1, 2.0 * (half + Delves.WALL)), hole_rects):
		if r.size.x > 0.01 and r.size.y > 0.01:
			var cen: Vector3 = fo + ax3[0] * r.get_center().x + ax3[1] * r.get_center().y + Vector3.UP * Delves.SLAB * 0.5
			var hx := r.size.x * 0.5
			var hz := r.size.y * 0.5
			_collision_box(Transform3D(bs, cen), Vector3(hx, Delves.SLAB * 0.5, hz))


## The corbel course (design §EX.3 ceiling rooms): one course of the
## style's stones along the top of every wall, stepping `step` in, `ch`
## high: the end walls' corner to corner, the side walls' between them; a
## gap left where a vent rises from the ceiling beside its wall.
func _corbels(pc: Dictionary, step: float, ch: float) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var embed := 0.25
	var yc := y + h - ch * 0.5 + 0.01
	var sm: Array = FittedStone.preset().get("stone_m", [0.25, 0.6])
	var lens := [float(sm[0]) * 1.6, float(sm[1]) * 1.8]
	var ax := _axes(pc)
	var d3: Vector3 = ax[0]
	var p3: Vector3 = ax[1]
	var gaps: Array = []
	for v in _lay.get("vents", []):
		if int(v.piece) == int(pc.id):
			gaps.append([_aa(pc, v.mouth), float(v.d) * 0.5 + 0.06])
	_stone_mode()
	var was_solid := solid
	solid = false
	# The end walls: across the room's whole width, into the side walls.
	for e: float in [0.0, 1.0]:
		var al := 0.0 if e == 0.0 else length
		var out := d3 if e == 0.0 else -d3
		_course(pc, Vector2(al, -half - embed), Vector2(al, half + embed), out, step, embed, yc, ch, lens, gaps, 1)
	# The side walls: between the end walls' corbels.
	for sd: float in [-1.0, 1.0]:
		_course(pc, Vector2(step, sd * half), Vector2(length - step, sd * half), -p3 * sd, step, embed, yc, ch, lens, gaps, 0)
	solid = was_solid


## One course of corbel stones along a wall's face, from a to b (along,
## across in piece `pc`), each reaching `reach` out of the wall (`out`) and
## `back` into it, `height` high round y `yc`, each its own length; none
## where `gaps` ([middle (along, across), half width]) cross it (`k`: the
## course runs along axis k).
func _course(pc: Dictionary, a: Vector2, b2: Vector2, out: Vector3, reach: float, back: float, yc: float, height: float, lens: Array, gaps: Array, k: int) -> void:
	var total := a.distance_to(b2)
	if total < 0.1:
		return
	var p0 := _pp(pc, a.x, a.y)
	var p1 := _pp(pc, b2.x, b2.y)
	var u3 := Vector3(p1.x - p0.x, 0.0, p1.y - p0.y) / total
	var bs := Basis(u3, Vector3.UP, u3.cross(Vector3.UP))
	var st: Dictionary = FittedStone.M.get("settle", {})
	var share := float(st.get("share", 0.15))
	var bevel := float(FittedStone.relief().get("bevel_m", 0.03)) * 1.3
	var at := 0.0
	while at < total - 0.01:
		var l := rng.randf_range(float(lens[0]), float(lens[1]))
		if total - (at + l) < float(lens[0]) * 0.7:
			l = total - at
		var drop := rng.randf_range(0.0, 0.025) if rng.randf() < share else 0.0
		var col := RuinStyle.stone(rng)
		var mid := a.lerp(b2, (at + l * 0.5) / total)
		var skip := false
		for g in gaps:
			var gc: Vector2 = g[0]
			if absf(gc[1 - k] - mid[1 - k]) < reach + back and absf(gc[k] - mid[k]) < l * 0.5 + float(g[1]):
				skip = true
		if not skip:
			var cen := Vector3(p0.x, yc - drop, p0.y) + u3 * (at + l * 0.5) + out * ((reach - back) * 0.5)
			box(Transform3D(bs, cen), Vector3(l - 0.012, height, reach + back), col, 0.0, bevel, 0.01)
		at += l


## The pillars and beams (design §EX.3 max_span_m, hearth_room
## four_pillars): each pillar a base, drums and a cap of the style's stone,
## a little settled; each beam one stone from wall to wall over two of
## them, the slabs resting on it.
func _pillars_and_beams(pc: Dictionary, plan: Dictionary) -> void:
	if (plan.pillars as Array).is_empty() and (plan.beams as Array).is_empty():
		return
	var y := float(pc.y0)
	var h := float(pc.h)
	# (A big room's pillars may be its archetype's own side, RoomPool.)
	var side := float(plan.get("side", RuinStyle.num("pillars.side_m", 0.6)))
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5)
	var bh := RuinStyle.num("pillars.beam_h_m", 0.45)
	var ax := _axes(pc)
	var room_bs := Basis(ax[0], Vector3.UP, (ax[0] as Vector3).cross(Vector3.UP))
	var beam_bot := y + h - bh
	var cap_h := 0.24
	var niches: Dictionary = plan.get("niches", {})
	_stone_mode()
	var was_foot := foot_y
	var was_solid0 := solid
	for pi in (plan.pillars as Array).size():
		var q: Vector2 = plan.pillars[pi]
		var p3 := _at(pc, q.x, q.y)
		# Each pillar stands on its own floor (a big room's steps; any other
		# room's is the room's).
		var fy := p3.y
		# Its collision solid blocks as drawn: the base, the shaft and the
		# cap (convex hulls, so a ray or a point inside one finds it:
		# TombNav's casts down, the boss's room to coil; and a line of
		# sight past the shaft isn't stopped short of it).
		for blk in [[side * 0.5 + PILLAR_BASE_OVER, -0.05, 0.22], [side * 0.5, 0.22, beam_bot - cap_h - fy], [side * 0.5 + 0.07, beam_bot - cap_h - fy, beam_bot - fy]]:
			var hb := float(blk[0])
			var hull := PackedVector3Array()
			for k in 8:
				hull.append(p3 + room_bs * Vector3(hb if k & 1 else -hb, 0.0, hb if k & 2 else -hb) + Vector3.UP * (float(blk[1]) if k & 4 == 0 else float(blk[2])))
			_ch.append(hull)
		solid = false
		foot_y = fy
		box(Transform3D(room_bs.rotated(Vector3.UP, rng.randf_range(-0.02, 0.02)), p3 + Vector3.UP * 0.11), Vector3(side + 2.0 * PILLAR_BASE_OVER, 0.22, side + 2.0 * PILLAR_BASE_OVER), RuinStyle.stone(rng), _growth(0.2), 0.04, 0.01)
		var z := fy + 0.22
		var top := beam_bot - cap_h
		# A pillar a sconce is cut into (a big room's pillar hall, RoomPool):
		# its shaft and cap round the niche and its flue slot.
		if niches.has(pi):
			RoomPoolBuild.niche_pillar(self, pc, p3, side, z, top, cap_h, niches[pi])
			foot_y = was_foot
			continue
		var drums := clampi(int(round((top - z) / 0.72)), 2, 6)
		for k in drums:
			var zb := top if k == drums - 1 else z + (top - z) / float(drums - k) * rng.randf_range(0.9, 1.1)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.012, 0.012)))
			box(Transform3D(room_bs * tilt, p3 + Vector3.UP * ((z + zb) * 0.5 - fy)), Vector3(side, zb - z + 0.006, side), RuinStyle.stone(rng), _growth(0.08), 0.035, 0.012)
			z = zb
		foot_y = was_foot
		box(Transform3D(room_bs, p3 + Vector3.UP * (top + cap_h * 0.5 - fy)), Vector3(side + 0.14, cap_h, side + 0.14), RuinStyle.stone(rng), 0.0, 0.035, 0.01)
	solid = was_solid0
	var was_solid := solid
	solid = false
	var sx := int(plan.s_axis)
	# The vents' columns: a beam breaks round one (it never shuts a shaft).
	var holes: Array = []
	for v in _lay.get("vents", []):
		if int(v.piece) == int(pc.id):
			var m := _aa(pc, v.mouth)
			var r := float(v.d) * 0.5 + 0.05
			holes.append(Rect2(m - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)))
	for bm in plan.beams:
		var at := float(bm[0])
		var runs: Array = [[float(bm[1]) - 0.3, float(bm[2]) + 0.3]]
		for hr: Rect2 in holes:
			var lo2 := hr.position.y if sx == 0 else hr.position.x
			var hi2 := hr.end.y if sx == 0 else hr.end.x
			var cross_lo := hr.position.x if sx == 0 else hr.position.y
			var cross_hi := hr.end.x if sx == 0 else hr.end.y
			if cross_hi < at - bw * 0.5 or cross_lo > at + bw * 0.5:
				continue
			var next: Array = []
			for rn in runs:
				if hi2 <= float(rn[0]) or lo2 >= float(rn[1]):
					next.append(rn)
					continue
				if lo2 > float(rn[0]):
					next.append([float(rn[0]), lo2])
				if hi2 < float(rn[1]):
					next.append([hi2, float(rn[1])])
			runs = next
		var run: Vector3 = ax[1] if sx == 0 else ax[0]
		var bs := Basis(run, Vector3.UP, run.cross(Vector3.UP))
		for rn in runs:
			var b0 := float(rn[0])
			var b1 := float(rn[1])
			if b1 - b0 < 0.3:
				continue
			var mid := Vector2(at, (b0 + b1) * 0.5) if sx == 0 else Vector2((b0 + b1) * 0.5, at)
			var p3 := _at(pc, mid.x, mid.y)
			box(Transform3D(bs, Vector3(p3.x, beam_bot + bh * 0.5 + 0.012, p3.z)), Vector3(b1 - b0, bh, bw), RuinStyle.stone(rng), 0.0, 0.05, 0.015)
	solid = was_solid


# --- Corridors and stairs -------------------------------------------------------

func _corridor(pc: Dictionary) -> void:
	var y := float(pc.y0)
	var h := float(pc.h)
	var half := float(pc.half)
	var length := float(pc.len)
	var hw := half + Delves.WALL * 0.5
	var top := y + h + Delves.SLAB
	for sd: float in [-1.0, 1.0]:
		var ops: Array = []
		for hd in _lay.holders:
			if str(hd.kind) != "sconce" or int(hd.piece) != int(pc.id):
				continue
			var aa := _aa(pc, hd.pos)
			if signf(aa.y) == sd:
				var op := _sconce_op(hd, aa.x)
				ops.append(op)
				# Its flue slot up the wall into the ceiling (the face's top).
				ops.append(_flue_slot_op(hd, op, y + h + 0.05))
		ops.append_array(_burrow_ops(pc, "left" if sd > 0.0 else "right"))
		_stone_wall(_pp(pc, 0.0, sd * hw), _pp(pc, length, sd * hw), y - 0.6, top, ops)
	_pave_flags(pc)
	_ceiling(pc, false)


## A flight of stairs (design §EX.3 stairs block_steps): walls of fitted
## stone stepping down with it, a stepped ceiling of the style's slabs,
## each step one block of the stone settled like the walls, and a ramp
## (collision only) under them to walk.
func _stair(pc: Dictionary) -> void:
	var length := float(pc.len)
	var half := float(pc.half)
	var h := float(pc.h)
	var y0 := float(pc.y0)
	var y1 := float(pc.y1)
	var hw := half + Delves.WALL * 0.5
	var ax := _axes(pc)
	var bs := Basis(ax[1], Vector3.UP, (ax[1] as Vector3).cross(Vector3.UP))
	var seg := 1.2
	var a := 0.0
	_stone_mode()
	while a < length - 0.01:
		var b := minf(a + seg, length)
		var fa := lerpf(y0, y1, a / length)
		var fb := lerpf(y0, y1, b / length)
		var lo := minf(fa, fb)
		var hi := maxf(fa, fb)
		var top := hi + h + Delves.SLAB + absf(fb - fa) + 0.3
		for sd: float in [-1.0, 1.0]:
			_stone_wall(_pp(pc, a, sd * hw), _pp(pc, b, sd * hw), lo - 0.6, top)
		# The ceiling over this stretch: two slabs, thick enough to overlap
		# the next stretch's (no slit to the void between them).
		var thick := Delves.SLAB + absf(fb - fa) + 0.3
		var cut := lerpf(a, b, rng.randf_range(0.4, 0.6))
		for part in [[a, cut], [cut, b]]:
			var p0 := float(part[0])
			var p1 := float(part[1])
			var mid := _pp(pc, (p0 + p1) * 0.5, 0.0)
			box(Transform3D(bs, Vector3(mid.x, hi + h + thick * 0.5, mid.y)), Vector3(2.0 * (half + Delves.WALL) + 0.1, thick, p1 - p0 + 0.03), RuinStyle.stone(rng), 0.0, 0.05, 0.02)
		a = b
	# The steps, each one block (drawn), the ramp under them (walked on).
	var st: Dictionary = FittedStone.M.get("settle", {})
	var share := float(st.get("share", 0.15))
	var tilts: Array = st.get("tilt_deg", [0.0, 4.0])
	var rise := absf(y1 - y0)
	var steps := maxi(3, int(round(rise / 0.3)))
	solid = false
	for k in steps:
		var a0 := length * k / steps
		var a1 := length * (k + 1) / steps
		var ytop := lerpf(y0, y1, (k + (0.0 if y1 < y0 else 1.0)) / steps)
		var mid := _pp(pc, (a0 + a1) * 0.5, 0.0)
		var sb := bs
		var drop := 0.0
		if rng.randf() < share:
			drop = rng.randf_range(0.0, float(st.get("dropped_m", 0.05)) * 0.5)
			sb = bs.rotated(Vector3.UP, deg_to_rad(rng.randf_range(float(tilts[0]), float(tilts[1]))) * 0.4 * (1.0 if rng.randf() < 0.5 else -1.0))
		box(Transform3D(sb, Vector3(mid.x, ytop - 0.25 - drop, mid.y)), Vector3(2.0 * half + 0.3, 0.5, a1 - a0 + 0.02), RuinStyle.stone(rng), _growth(0.05), 0.04, 0.015)
	solid = true
	var lo_p := _pp(pc, length if y1 < y0 else 0.0, 0.0)
	var hi_p := _pp(pc, 0.0 if y1 < y0 else length, 0.0)
	_dramp(Vector3(lo_p.x, minf(y0, y1), lo_p.y), Vector3(hi_p.x, maxf(y0, y1), hi_p.y), 2.0 * half)


## RuinBuilder's delve stair, in the tomb: the tomb's own block stair.
func _delve_stair(pc: Dictionary, off: float, first: bool, open_to: float, floor_top: float) -> void:
	if off == 0.0 and not first:
		_stair(pc)
	else:
		super(pc, off, first, open_to, floor_top)


# --- Vents ----------------------------------------------------------------------

## A vent's flue (the vents rule): a square stone tube from the ceiling up
## to the surface, through each of its legs (a kink steps it sideways where
## something stood over the fire), open at the top: the style's stone.
func _flue(v: Dictionary) -> void:
	var r := float(v.d) * 0.5
	var legs: Array = v.legs
	_stone_mode()
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
			for dy: float in [2.0 * r + 0.2, -0.2]:
				var col := RuinStyle.stone(rng)
				box(Transform3D(Basis.IDENTITY, mid + Vector3(0.0, dy, 0.0)), size, col if bare else col.darkened(0.3), 0.0, 0.05, 0.02)


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
		var col := RuinStyle.stone(rng)
		box(Transform3D(Basis.IDENTITY, Vector3(p.x, y + rise * 0.5, p.y)), size, col if bare else col.darkened(0.15), 0.0, 0.06, 0.03)


# --- What each room holds -------------------------------------------------------

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


## A point in piece `pc` at (along, across), on its floor, as a Vector3.
func _at(pc: Dictionary, along: float, across: float, lift := 0.0) -> Vector3:
	var q := _pp(pc, along, across)
	return Vector3(q.x, Delves.floor_of(pc, along) + lift, q.y)


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


## Beyond a way out's opening (design §EX.5): the floor runs on OUTSIDE_M
## past the wall under the daylight (WayOut hangs it OUTSIDE_M out), the
## wall's stone (the style's, §EX.1) carried on out either side so the
## daylight's edges never show, and a stop past the daylight (collision
## only): stepping into the
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
	var up_to := maxf(top, y + float(d.h) + OUTSIDE_UP_M + 0.2)
	_stone_mode()
	for sd: float in [-1.0, 1.0]:
		var c := mid + side * sd * (half + 0.05 + 0.45)
		box(Transform3D(bs, Vector3(c.x, (y - 0.3 + up_to) * 0.5, c.y)), Vector3(0.9, up_to - y + 0.3, depth), RuinStyle.stone(rng), 0.0, 0.06, 0.02)
	# The stop, past the daylight.
	var s := p + nv * (wall + OUTSIDE_M + 0.15)
	_collision_box(Transform3D(bs, Vector3(s.x, y + 1.5, s.y)), Vector3(half + 0.2, 1.6, 0.1))


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
	# What stands in a big room is its archetype's (design §FM.6's room
	# pool, RoomPoolBuild).
	if pc.has("big_room"):
		RoomPoolBuild.dress(self, pc)
		return
	var half := float(pc.half)
	var length := float(pc.len)
	var pv := Delves.perp(pc.dir)
	var bays := _bays(pc)
	match str(pc.get("room_kind", "")):
		"hearth":
			# The mat you wake on (§ET.3): woven reeds, flat on the floor.
			var w: Array = _lay.get("wake", [Vector3.ZERO, 0.0])
			var wp: Vector3 = w[0]
			_other_mode()
			solid = false
			box(Transform3D(Basis(Vector3.UP, float(w[1])), wp + Vector3(0.0, 0.03, 0.0)), Vector3(0.9, 0.05, 1.9), THATCH.darkened(0.25), 0.0, 0.02, 0.01)
			solid = true
			# The rescuer's few things by the wall behind them (clear of the
			# pillars): a water jar, a bedroll.
			var r: Array = _lay.get("rescuer", [Vector3.ZERO, 0.0])
			var rp: Vector3 = r[0]
			var out := Vector3(rp.x, 0.0, rp.z).normalized()
			var side3 := Vector3(-out.z, 0.0, out.x)
			var spot := rp + out * 1.3
			for cand: Vector3 in [rp + out * 1.3, rp + out * 0.9 + side3 * 0.9, rp + out * 0.9 - side3 * 0.9, rp + side3 * 1.2, rp - side3 * 1.2]:
				if _clear_of_pillars(pc, cand, 1.0) and _clear_of_pillars(pc, cand + Vector3(0.8, 0.0, 0.2), 1.0):
					spot = cand
					break
			boulder(spot + Vector3(0.0, 0.3, 0.0), Vector3(0.22, 0.3, 0.22), Basis.IDENTITY, CLAY, 0.0)
			solid = false
			box(Transform3D(Basis(Vector3.UP, float(r[1]) + 0.4), spot + Vector3(0.8, 0.12, 0.2)), Vector3(0.5, 0.24, 1.4), HIDE.darkened(0.2), 0.0, 0.06, 0.03)
			solid = true
			# The low stone they sit on by the fire (§FH, HearthFolk), cut from
			# the room's own stone (§EX.1), as the rest of its dressing.
			_stone_mode()
			var seat := HearthFolk.seat(rp, float(r[1]))
			box(seat.xf, seat.size, RuinStyle.stone(rng), _growth(0.05), 0.04, 0.02)
		"crypt":
			# The coffins (TombKit.coffin_spots: rows set round the sconces,
			# none where a pillar stands); one a skeleton rests in lies open
			# (residents, §FE). The style's stone (§EX.1).
			var yaw := atan2(pv.x, pv.y)
			var keep: Array = bays + _pillar_rects(pc)
			for s in TombKit.coffin_spots(_lay, pc):
				# The boss's lair is where this one stood (TombKit.lair_took):
				# it fell through with the floor (_lair_hole).
				if TombKit.lair_took(_lay, int(pc.id), int(s.i)):
					continue
				var a := float(s.along)
				var sd := float(s.sd)
				coffins += 1
				var at := _at(pc, a, sd * (half - TombKit.COFFIN_IN))
				if TombKit.resting_at(_lay, int(pc.id), int(s.i)).is_empty():
					_coffin(at, yaw)
				else:
					# Its lid falls toward the room's middle, clear of the end
					# walls' doors (the coffin's +x looks back toward the
					# room's start), unless that lays it before a sconce or
					# against a pillar (_lid_side).
					_open_coffin(at, yaw, TombKit.COFFIN_SIZE, _lid_side(pc, at, yaw, TombKit.COFFIN_SIZE, -1.0 if a < length * 0.5 else 1.0, keep))
				if rng.randf() < 0.35 and not _in_bay(bays, Rect2(a + 0.9 - GOODS_REACH, sd * (half - 2.3) - GOODS_REACH, 2.0 * GOODS_REACH, 2.0 * GOODS_REACH)):
					_goods(_at(pc, a + 0.9, sd * (half - 2.3), 0.03), 0.3, 1, pc)
		"catacomb":
			# The bone niches cut into its long walls (TombKit.niche_spots,
			# _bone_columns, _niche_ops), the dead's bones on their sills; the
			# one a skeleton sits in is a burial niche, one tall niche over
			# the sill stone it sits on (_burial_sill).
			niches += TombKit.niche_spots(_lay, pc).size()
			var bn := bone_niche()
			for e in _bones.get(int(pc.id), []):
				if bool(e[3]):
					_burial_sill(pc, float(e[0]), float(e[1]))
					continue
				if rng.randf() < 0.75:
					var q := _pp(pc, float(e[0]), float(e[1]) * (half + float(bn.d) * 0.5))
					_niche_bones(Vector3(q.x, float(e[2]) + 0.01, q.y), Vector3((pc.dir as Vector2).x, 0.0, (pc.dir as Vector2).y))
		"ossuary":
			for k in 4:
				var ca := 0.9 if k < 2 else length - 0.9
				var cs := (half - 0.9) * (1.0 if k % 2 == 0 else -1.0)
				var side := "left" if cs > 0.0 else "right"
				if _near_door(pc, side, ca, 1.8) or _in_bay(bays, Rect2(ca - 0.6 - GOODS_REACH, cs - 0.6 - GOODS_REACH, 1.2 + 2.0 * GOODS_REACH, 1.2 + 2.0 * GOODS_REACH)):
					continue
				var at3 := _at(pc, ca, cs, 0.03)
				if not _clear_of_pillars(pc, at3, 1.3):
					at3 = _at(pc, ca + (-0.35 if k < 2 else 0.35), cs * 1.1, 0.03)
					if not _clear_of_pillars(pc, at3, 1.1):
						continue
				_other_mode()
				_grave_goods(at3, 0.6, 6)
				_stone_mode()
		"collapsed":

			var col: Array = _collapse(pc, (plans.get(int(pc.id), {}) as Dictionary).get("pillars", []), bays)
			var q: Vector2 = col[0]
			var p := _at(pc, q.x, q.y)
			_stone_mode()
			# The fallen slab along the wall it lies nearest, tipped against it.
			var ax3 := _axes(pc)
			var along_wall: Vector3 = ax3[0] if absf(q.y) / half > minf(q.x, length - q.x) / (length * 0.5) else ax3[1]
			var yaw := atan2(along_wall.x, along_wall.z) + PI * 0.5 + rng.randf_range(-0.2, 0.2)
			box(Transform3D(Basis.from_euler(Vector3(0.45, yaw, 0.2)), p + Vector3(0.0, 0.62, 0.0)), Vector3(float(col[2]), 0.32, 0.8), RuinStyle.stone(rng), _growth(0.4), 0.05, 0.03)
			rubble(p, float(col[1]), 7)
		"heart":
			# The dead lie across the room toward its far end, their goods
			# before them, the way out beyond them (§EX.5): the walk goes
			# round them on either side and along the far wall behind the
			# lid to the door (TombKit.heart_box, HEART_*).
			var hb := TombKit.heart_box(pc)
			_heart_box(hb.pos, float(hb.yaw), not TombKit.resting_at(_lay, int(pc.id), -1).is_empty())
			# The dead's goods before them (HEART_GOODS_M from the far wall),
			# spread no nearer the sconces' bays than they reach, and clear
			# of the pillars (_goods).
			var g := Vector2(length - TombKit.HEART_GOODS_M, 0.0)
			var room_for := 0.6 + GOODS_REACH
			for b in bays:
				var r: Rect2 = b
				room_for = minf(room_for, (g - g.clamp(r.position, r.end)).length())
			_goods(_at(pc, g.x, g.y, 0.03), clampf(room_for - GOODS_REACH, 0.3, 0.6), 6, pc)


## The side (+1 / -1 along the coffin's x) an open coffin's lid falls to
## (_open_coffin): `prefer` (toward the room's middle) unless the lid would
## lie in one of `keep` (a sconce's bay, design §EX.4; a pillar's base),
## then the other side if that's clear.
func _lid_side(pc: Dictionary, p: Vector3, yaw: float, size: Vector3, prefer: float, keep: Array) -> float:
	for sd: float in [prefer, -prefer]:
		var c := p + Basis(Vector3.UP, yaw) * Vector3(sd * (size.x * 0.5 + 0.5), 0.0, 0.0)
		if not _in_bay(keep, _slab_foot(pc, c, Vector3(size.x + 0.1, 0.0, size.z + 0.5), yaw)):
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


## Room `pc`'s pillars' bases (with a hand round them) as Rect2s in its
## (along, across): what a fallen lid keeps off.
func _pillar_rects(pc: Dictionary) -> Array:
	var out: Array = []
	var hs := RuinStyle.num("pillars.side_m", 0.6) * 0.5 + 0.18
	for q: Vector2 in (plans.get(int(pc.id), {}) as Dictionary).get("pillars", []):
		out.append(Rect2(q - Vector2(hs, hs), Vector2(2.0 * hs, 2.0 * hs)))
	return out


## Grave goods round `c` (RuinBuilder._grave_goods: urns, bones, a skull,
## gold), each kept clear of the room's pillars and, where given, of
## `open_at` (the way in to the heart's dead).
func _goods(c: Vector3, spread: float, count: int, pc: Dictionary, open_at := Vector3.INF) -> void:
	_other_mode()
	for i in count:
		var p := c
		var ok := false
		for t in 6:
			p = c + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
			if _clear_of_pillars(pc, p, 0.95) and (open_at == Vector3.INF or Vector2(p.x - open_at.x, p.z - open_at.z).length() >= 1.2):
				ok = true
				break
		if ok:
			_grave_goods(p, 0.0, 1)
	_stone_mode()


## The dead's bones in a niche (the catacomb's): a skull, a few long bones
## along it (`along`), small enough for the niche.
func _niche_bones(p: Vector3, along: Vector3) -> void:
	_other_mode()
	var was_shade := shade
	shade = 0.0
	solid = false
	var yaw := atan2(along.x, along.z)
	for k in rng.randi_range(1, 3):
		box(Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.25, 0.25)), p + along * rng.randf_range(-0.2, 0.2) + Vector3(0.0, 0.03 + 0.05 * k, 0.0)), Vector3(0.05, 0.05, 0.42), BONE.darkened(rng.randf_range(0.0, 0.1)), 0.0, 0.015, 0.005)
	if rng.randf() < 0.7:
		boulder(p + along * rng.randf_range(-0.28, 0.28) + Vector3(0.0, 0.1, 0.0), Vector3(0.1, 0.09, 0.12), Basis(Vector3.UP, rng.randf() * TAU), BONE, 0.0)
	solid = true
	shade = was_shade
	_stone_mode()


## A stone coffin at `p` (on the floor), long along `yaw`, its lid pushed
## askew: the style's stone.
func _coffin(p: Vector3, yaw: float) -> void:
	_stone_mode()
	box(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0.0, 0.45, 0.0)), Vector3(0.95, 0.9, 2.2), RuinStyle.stone(rng), _growth(0.15), 0.08, 0.02)
	var lid := Basis(Vector3.UP, yaw + rng.randf_range(-0.25, 0.25))
	box(Transform3D(lid, p + Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.2, 0.2))), Vector3(1.05, 0.2, 2.3), RuinStyle.stone(rng), _growth(0.2), 0.06, 0.02)


## RuinBuilder's coffin, in the tomb: the style's stone, whatever colour it
## was asked for.
func _sarcophagus(p: Vector3, yaw: float, _col: Color) -> void:
	_coffin(p, yaw)


## Rubble (a collapsed room's): fallen stones of the walls and pieces of a
## ceiling slab, tumbled: the style's stone.
func rubble(center: Vector3, spread: float, count: int) -> void:
	_stone_mode()
	var sm: Array = FittedStone.preset().get("stone_m", [0.25, 0.6])
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var slab := rng.randf() < 0.35
		var s := rng.randf_range(float(sm[0]), float(sm[1]))
		var size := Vector3(rng.randf_range(0.5, 0.95), rng.randf_range(0.14, 0.24), rng.randf_range(0.35, 0.6)) if slab else Vector3(s, s * rng.randf_range(0.6, 0.85), s * rng.randf_range(0.7, 1.0))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var p := Vector3(center.x + cos(a) * r, _floor + size.y * 0.35, center.z + sin(a) * r)
		var was := foot_y
		foot_y = _floor
		var was_solid := solid
		solid = size.length() > 0.55
		box(Transform3D(basis, p), size, RuinStyle.stone(rng), _growth(rng.randf_range(0.3, 0.9)), 0.05, 0.03)
		solid = was_solid
		foot_y = was


## The heart's coffin (Mike's frame 9): a mossy stone box, its lid shoved
## half off, the one buried there leaning out over its side: skull, ribs,
## an arm hanging down the stone. When that one is a resident (`open`,
## residents.json skeleton heart_holds_one) the box is hollow and the
## skeleton is its sprite (Residents), not stone.
func _heart_box(p: Vector3, yaw: float, open := false) -> void:
	var bs := Basis(Vector3.UP, yaw)
	_stone_mode()
	if open:
		_open_box(bs, p, TombKit.HEART_BOX, RuinStyle.stone(rng), _moss(0.75))
	else:
		box(Transform3D(bs, p + Vector3(0.0, 0.5, 0.0)), Vector3(1.05, 1.0, 2.3), RuinStyle.stone(rng), _moss(0.75), 0.08, 0.03)
	# The lid, shoved off one side and down against the box.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.12, 0.42)), p + bs * Vector3(-0.85, 0.72, 0.15)), Vector3(1.1, 0.18, 2.35), RuinStyle.stone(rng), _moss(0.85), 0.06, 0.02)
	if open:
		return
	_other_mode()
	solid = false
	# The skeleton: ribs leaning out over the rim, the skull past them, an
	# arm down the outside.
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.42, 1.1, 0.55)), Vector3(0.38, 0.14, 0.3), BONE, 0.0, 0.03, 0.01)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, -0.75)), p + bs * Vector3(0.38, 1.12, 0.22)), Vector3(0.34, 0.08, 0.12), BONE.darkened(0.05), 0.0, 0.02, 0.01)
	boulder(p + bs * Vector3(0.72, 1.02, 0.62), Vector3(0.12, 0.13, 0.15), bs, BONE, 0.0)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.0, 0.0, 0.15)), p + bs * Vector3(0.6, 0.62, 0.35)), Vector3(0.05, 0.62, 0.05), BONE, 0.0, 0.015, 0.005)
	box(Transform3D(bs * Basis.from_euler(Vector3(0.3, 0.0, 0.1)), p + bs * Vector3(0.62, 0.22, 0.42)), Vector3(0.05, 0.3, 0.05), BONE, 0.0, 0.015, 0.005)
	solid = true
	_stone_mode()


## The hearth's kerb (design §EX.1: the hearth's surround is the style's
## stone): the hearth's pit where the style sinks it (_hearth_pit, Mike 7
## Oct); else, and round any other fire on the floor (a hearth ring), nine
## stones in a ring where the campfire's own ring stones were
## (CrawlerFires hides those; their collision stays).
func _kerbs(lay: Dictionary) -> void:
	var fires: Array = []
	if pit().is_empty():
		fires.append(lay.get("hearth", Vector3.ZERO))
	else:
		_hearth_pit(lay.get("hearth", Vector3.ZERO))
	for hd in lay.holders:
		if str(hd.kind) != "sconce":
			fires.append(hd.pos)
	_stone_mode()
	var was_solid := solid
	var was_foot := foot_y
	solid = false
	for f: Vector3 in fires:
		var n := 9
		var ph := rng.randf() * TAU
		foot_y = f.y
		for i in n:
			var a := ph + TAU * i / n + rng.randf_range(-0.08, 0.08)
			var rr := 0.62 + rng.randf_range(-0.03, 0.03)
			var size := Vector3(rng.randf_range(0.26, 0.34), rng.randf_range(0.15, 0.2), rng.randf_range(0.18, 0.24))
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.06, 0.06)))
			box(Transform3D(Basis(Vector3.UP, -a - PI * 0.5) * tilt, f + Vector3(cos(a) * rr, size.y * 0.5 - 0.01, sin(a) * rr)), size, RuinStyle.stone(rng), _growth(0.05), 0.03, 0.01)
	foot_y = was_foot
	solid = was_solid


## How far the kerb overhangs the pit's lining (m), and how deep the kerb
## stones go under the floor (m).
const PIT_LIP_M := 0.05
const PIT_KERB_DEEP_M := 0.14


## The hearth's pit (pit(); Mike, 7 Oct: "a fire pit made into the ground
## instead of just having a campfire sitting right on the floor"; the
## Andean tomb's after the Mito tradition's sunken hearths): a polygon of
## `sides` sunk `depth` m into the floor at `c`, the floor's flags cut round
## it (_pave_flags). Round its lip the kerb, one stone a side set into the
## floor, its top pillowed and kerb_proud_m proud of the flags, overhanging
## the lining a hand; under it the lining, a block a side, going toward the
## scene's shade (navy) as it goes down; the joints' back under the kerb;
## and at its foot a bed of ash, where CrawlerFires sets the fire. All the
## style's stone but the ash, on the pit's own dice. Collision: the pit's
## floor, and the guard round its lip up to guard_m over the floor (under
## every eye: you stand at its edge, a thrown pot falls in).
func _hearth_pit(c: Vector3) -> void:
	var pt := pit()
	var n := int(pt.sides)
	var a := float(pt.r)
	var kw := float(pt.kerb_w)
	var proud := float(pt.proud)
	var fy := c.y
	var foot := fy - float(pt.depth)
	var lip := pit_poly(c, a - PIT_LIP_M, n)
	var lining := pit_poly(c, a, n)
	var outer := pit_poly(c, a + kw, n)
	var pr := RandomNumberGenerator.new()
	pr.seed = hash([int(_lay.seed), "hearth_pit"])
	var was_solid := solid
	var was_foot := foot_y
	var was_rng := rng
	rng = pr
	solid = false
	foot_y = foot
	_stone_mode()
	var rl := FittedStone.relief()
	var joint := float(rl.get("joint_m", 0.012))
	var jd := float(rl.get("joint_depth_m", 0.06))
	var back := RuinStyle.joint(0.3, bare)
	back.a = 0.0
	var mid := Vector3(c.x, foot, c.z)
	for k in n:
		var k2 := (k + 1) % n
		var l0 := Vector3(lip[k].x, fy, lip[k].y)
		var l1 := Vector3(lip[k2].x, fy, lip[k2].y)
		var o0 := Vector3(outer[k].x, fy, outer[k].y)
		var o1 := Vector3(outer[k2].x, fy, outer[k2].y)
		var inward := (Vector3(c.x, fy, c.z) - (l0 + l1) * 0.5).normalized()
		# The joints' back under the kerb (between its stones, and between
		# it and the flags cut round it).
		var below := Vector3(0.0, -jd, 0.0)
		_tri_n(l0 + below, o0 + below, o1 + below, Vector3.UP, Vector3.UP, Vector3.UP, back, back, back, mid - Vector3.UP)
		_tri_n(l0 + below, o1 + below, l1 + below, Vector3.UP, Vector3.UP, Vector3.UP, back, back, back, mid - Vector3.UP)
		# The kerb stone: its top pillowed as a flag's, settled a little.
		var col := RuinStyle.stone(pr)
		var off := pr.randf_range(-0.006, 0.006)
		var poly := FittedStone.ccw(PackedVector2Array([lip[k], lip[k2], outer[k2], outer[k]]))
		var foot_col: Color = col if bare else Prelit.ao_tint(col, 0.55)
		foot_col.a = 0.0
		FittedStone.stone(self, Vector3(0.0, fy, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.UP, poly, col, foot_col, proud, 0.02, 0.04, joint, jd, off, 0.0, Vector2.ZERO, Vector3(0, 0, -1), false)
		# Its face over the pit, down to the lining.
		var top_y := fy - jd * 0.45 + off
		var face_col: Color = col if bare else Prelit.ao_tint(col, 0.8)
		var deep_col: Color = col if bare else Prelit.ao_tint(col, 0.6)
		var dl0 := l0.lerp(l1, joint / maxf(l0.distance_to(l1), 0.01))
		var dl1 := l1.lerp(l0, joint / maxf(l0.distance_to(l1), 0.01))
		_quad_i(Vector3(dl0.x, top_y, dl0.z), Vector3(dl1.x, top_y, dl1.z), Vector3(dl1.x, fy - PIT_KERB_DEEP_M, dl1.z), Vector3(dl0.x, fy - PIT_KERB_DEEP_M, dl0.z),
			inward, inward, inward, inward, face_col, face_col, deep_col, deep_col, mid - inward * 4.0)
		# The lining under it: one block of the side, its face on the pit's
		# outline, into the shade as it goes down.
		var s0 := Vector3(lining[k].x, 0.0, lining[k].y)
		var s1 := Vector3(lining[k2].x, 0.0, lining[k2].y)
		var along := s1 - s0
		var side_len := along.length()
		var h := fy - PIT_KERB_DEEP_M - foot + 0.02
		var thick := 0.2
		var lc := RuinStyle.stone(pr)
		if not bare:
			lc = Prelit.ao_tint(lc, 0.5)
		var lm := (s0 + s1) * 0.5 - inward * (thick * 0.5) + Vector3(0.0, foot + h * 0.5 - 0.02, 0.0)
		var yaw := atan2(along.x, along.z)
		box(Transform3D(Basis(Vector3.UP, yaw + PI * 0.5) * Basis.from_euler(Vector3(0.0, 0.0, pr.randf_range(-0.03, 0.03))), lm), Vector3(side_len - joint * 2.0, h, thick), lc, 0.0, 0.025, 0.008)
		# The guard round the lip (collision only): the kerb's own footprint,
		# from the pit's floor to guard_m over the floor, each side reaching a
		# little past its corners into the next, so no seam opens between them.
		var sl := (lip[k2] - lip[k]).normalized() * 0.03
		var so := (outer[k2] - outer[k]).normalized() * 0.03
		_prism(FittedStone.ccw(PackedVector2Array([lip[k] - sl, lip[k2] + sl, outer[k2] + so, outer[k] - so])), foot, fy + float(pt.guard))
	# The bed of ash at its foot (not stone), and its collision.
	_other_mode()
	var ash: Color = pt.ash
	for k in n:
		var k2 := (k + 1) % n
		var p0 := Vector3(lining[k].x, foot + 0.005, lining[k].y)
		var p1 := Vector3(lining[k2].x, foot + 0.005, lining[k2].y)
		var cm := Vector3(c.x, foot + 0.02, c.z)
		_tri_n(p0, p1, cm, Vector3.UP, Vector3.UP, Vector3.UP, ash, ash, ash.lightened(0.08), cm - Vector3.UP)
	_stone_mode()
	_prism(outer, foot - 0.3, foot)
	rng = was_rng
	foot_y = was_foot
	solid = was_solid


## A sconce's cup (design §EX.3 sconce niche_cup): a small block of the
## style's stone on its niche's sill; the coals and the flame stand in it
## (CrawlerFires).
func _sconce_cup(hd: Dictionary) -> void:
	var sc := sconce_niche()
	var pos: Vector3 = hd.pos
	var nrm: Vector3 = hd.normal
	var cup: Vector3 = sc.cup
	var right := Vector3.UP.cross(nrm).normalized()
	_stone_mode()
	var was_solid := solid
	solid = false
	box(Transform3D(Basis(right, Vector3.UP, right.cross(Vector3.UP)), pos - nrm * sconce_inset() - Vector3(0.0, cup.y * 0.5, 0.0)), cup, RuinStyle.stone(rng), 0.0, 0.025, 0.006)
	solid = was_solid


## An open stone box `size` (x wide, y tall, z long, in `bs`) standing on
## `p`: four walls of the style's stone `col` round a hollow filled up to
## where a skeleton kneels (TombKit.grave_floor: its head and an arm clear
## the rim), the fill in the hollow's shade (as cut in a bare build), a
## grave (residents.json skeleton rests_in).
func _open_box(bs: Basis, p: Vector3, size: Vector3, col: Color, moss: float) -> void:
	_stone_mode()
	var t := 0.1
	var fill := TombKit.grave_floor(size.y)
	box(Transform3D(bs, p + Vector3(0.0, fill * 0.5, 0.0)), Vector3(size.x, fill, size.z), col if bare else Prelit.ao_tint(col, 0.45), moss * 0.5, 0.03, 0.02)
	for sx: float in [-1.0, 1.0]:
		box(Transform3D(bs, p + bs * Vector3(sx * (size.x - t) * 0.5, size.y * 0.5, 0.0)), Vector3(t, size.y, size.z), col, moss, 0.04, 0.02)
	for sz: float in [-1.0, 1.0]:
		box(Transform3D(bs, p + bs * Vector3(0.0, size.y * 0.5, sz * (size.z - t) * 0.5)), Vector3(size.x - 2.0 * t, size.y, t), col, moss, 0.04, 0.02)


## A crypt coffin a skeleton rests in (§FE.2: it climbs out of its grave):
## _coffin's box, open, and its lid shoved off its `side` long side (+1 its
## +x), down on the floor against it; the style's stone. Draws on the same
## rolls as _coffin, so the rest of the room is as it would be.
func _open_coffin(p: Vector3, yaw: float, size: Vector3, side: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	_open_box(bs, p, size, RuinStyle.stone(rng), _growth(0.15))
	var turn := rng.randf_range(-0.25, 0.25)
	rng.randf_range(-0.15, 0.15)
	var slide := rng.randf_range(-0.2, 0.2)
	# Tipped so its edge by the box rests up against it.
	var lid := bs * Basis(Vector3.UP, turn * 0.3) * Basis(Vector3.BACK, -side * 0.38)
	box(Transform3D(lid, p + bs * Vector3(side * (size.x * 0.5 + 0.5), 0.27, slide)), Vector3(size.x + 0.1, 0.2, size.z + 0.1), RuinStyle.stone(rng), _growth(0.2), 0.06, 0.02)


## A burial niche a skeleton sits in (§FE.2: it climbs out of the wall):
## one tall trapezoid niche cut into the catacomb's wall where a column of
## bone niches would be (_bone_columns, _niche_ops; niches.burial), and
## the sill stone it sits hunched on, the style's stone, from the niche's
## back out into the room (TombKit.rest_place sits it BURIAL_OUT_M less a
## little out from the wall, BURIAL_SILL_M over the floor).
func _burial_sill(pc: Dictionary, along: float, sd: float) -> void:
	var half := float(pc.half)
	var pv := Delves.perp(pc.dir)
	var bs := Basis(Vector3.UP, atan2(pv.x, pv.y))
	var bur := burial_niche()
	var deep := float(bur.d) + BURIAL_OUT_M
	_stone_mode()
	box(Transform3D(bs, _at(pc, along, sd * (half - BURIAL_OUT_M + deep * 0.5), BURIAL_SILL_M - BURIAL_SILL_T * 0.5)), Vector3(float(bur.w) + 0.12, BURIAL_SILL_T, deep), RuinStyle.stone(rng), _growth(0.15), 0.03, 0.01)


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
	_stone_mode()
	solid = false
	var lintel := RuinStyle.stone(rng)
	for sd: float in [-1.0, 1.0]:
		box(Transform3D(bs, c + right * sd * (w * 0.5 + t * 0.5)), Vector3(t, h + 2.0 * t, 0.16), RuinStyle.stone(rng), 0.0, 0.04, 0.02)
		box(Transform3D(bs, c + Vector3.UP * sd * (h * 0.5 + t * 0.5)), Vector3(w, t, 0.16), lintel if sd > 0.0 else RuinStyle.stone(rng), 0.0, 0.04, 0.02)
	if strong:
		# The mark: two notches cut in the lintel, in their own shade.
		for k: float in [-0.15, 0.15]:
			box(Transform3D(bs, c + Vector3.UP * (h * 0.5 + t * 0.5) + right * k + nrm * 0.08), Vector3(0.05, t * 0.7, 0.02), lintel if bare else Prelit.ao_tint(lintel, 0.3), 0.0, 0.0, 0.0)
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
## Its stone is the tomb's own (§EX.1, RuinStyle: the tipped flags in the
## scene's shade as they go down, none of it on a pillar). Not a way down
## (lair.enterable false): a ring of collision round the mouth keeps you
## at its edge, and the floor under it is whole.
func _lair_hole(l: Dictionary) -> void:
	var c: Vector3 = l.pos
	var r := float(l.r)
	var pc: Dictionary = _lay.pieces[int(l.piece)]
	var side := RuinStyle.num("pillars.side_m", 0.6)
	var keep_rng := rng
	rng = RandomNumberGenerator.new()
	rng.seed = hash([int(_lay.seed), "lair_hole"])
	solid = false
	var was_foot := foot_y
	foot_y = c.y
	_stone_mode()
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
		var col := RuinStyle.stone(rng)
		var dark := rng.randf_range(0.05, 0.2)
		# Going down into the dark: toward the scene's shade (navy), as the
		# joints do; a bare build keeps the stone as cut.
		if not bare:
			col = Prelit.ao_tint(col, 1.0 - dark)
		# Freshly broken: no moss.
		box(Transform3D(bs, p), size, col, 0.0, 0.03, 0.02)
	# Pieces of the broken flags thrown out round it, and the small bones
	# of what it ate, none where a pillar stands.
	for k in 10:
		var a := rng.randf() * TAU
		var d := r + rng.randf_range(0.35, 1.2)
		var p := c + Vector3(cos(a), 0.0, sin(a)) * d
		var rad := Vector3(rng.randf_range(0.06, 0.16), rng.randf_range(0.04, 0.1), rng.randf_range(0.06, 0.15))
		var bs := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35)))
		var col := RuinStyle.stone(rng)
		if _clear_of_pillars(pc, p, side * 0.71 + rad.length()):
			box(Transform3D(bs, p + Vector3(0.0, rad.y * 0.7, 0.0)), rad * 2.0, col, 0.0, 0.03, 0.02)
	_other_mode()
	for k in 5:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0.0, sin(a)) * (r + rng.randf_range(0.3, 1.0))
		var bs := Basis(Vector3.UP, rng.randf() * TAU)
		var size := Vector3(rng.randf_range(0.12, 0.26), 0.035, 0.035)
		var col := BONE.darkened(rng.randf_range(0.1, 0.3))
		if _clear_of_pillars(pc, p, side * 0.71 + 0.15):
			box(Transform3D(bs, p + Vector3(0.0, 0.025, 0.0)), size, col, 0.0, 0.01, 0.005)
	_stone_mode()
	foot_y = was_foot
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

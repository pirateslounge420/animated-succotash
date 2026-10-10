class_name TomePages
extends Node3D
## Tomes as collected pages (design 9 Oct §FM.5, queue 73; data/tomes.json
## tomes[].fragments and find, data/descent.json floors.base_layer), in
## Torchfire 1's crawler. One per dungeon, built with it (CrawlerMain) and
## kept out of the tree with it while you are up on the surface.
##
## A tome split into fragments (Tomes.fragments_of: a run of its pages
## each) is found a fragment at a time, each its own pickup. They lie on
## the dungeon's base layer, its last floor (floor two; floor one in a
## dungeon of one floor), by find's own rule (Tomes.layer_fragments, as at
## the open world's delve hearts): the base layer's hearts are the rooms at
## the far ends of its ways (hearts_of), and of them find.share_of_hearts
## hold one, seeded on the dungeon's seed and the heart, never two of the
## same in one dungeon, so different pages of a book lie in different
## dungeons, or in different parts of one. A fragment lies on the floor of
## its room by the far wall (or a side wall), where someone left it: a
## rolled scroll of its pages, tied, in the tomb's matte material, lit only
## by fire and pointing at nothing (§FG). Never in a chest.
##
## Right click (interact) beside one takes it: yours for good, kept in the
## game's save (CrawlerSave.data "tome_pages", written at once), so it never
## lies anywhere again in this game, in this dungeon or any other. The log
## says so ("You found pages of a tome: ..."). R reads what you hold, out of
## the dungeon too (CrawlerMain.read_pages, TomePanel.open_held): the book's
## title page says how much of it you hold ("pages 1 to 5 of 12"), then its
## pages you hold; a book whose text isn't in yet opens at its title page
## only. Flavour only (§DL, §FM.5): no systems, no scoring, nothing else
## reads them. A tome with no fragments list never lies here.

## The save's key for the fragments you hold (CrawlerSave.data).
const KEEP := "tome_pages"
## The scroll (m): its roll's radius and half its length, its end knobs'
## radius and how far they stand out, the tie's half width and how proud.
const ROLL_R := 0.034
const ROLL_HALF := 0.13
const KNOB_R := 0.021
const KNOB_OUT := 0.024
const TIE_HALF := 0.012
const TIE_OVER := 0.003
const SIDES := 8
## Its colours: old paper (items.json scroll), the knobs' dark wood (items.json
## tome), the faded cord.
const PAPER := Color("#d8cfa8")
const WOOD := Color("#5a4632")
const CORD := Color("#7a3a2a")

static var _mesh: ArrayMesh

var lay: Dictionary
var player: CrawlerPlayer
## What lies here now: [{"fragment", "room" (piece id), "node", "pos"}...].
var lying: Array = []
## Laid out (the stone was in the physics world and every spot tried):
## the checks wait on it.
var placed := false
## Fragments taken here this visit (the checks).
var taken := 0
var _voice: AudioStreamPlayer3D


## How far from pages you can take them (m, your feet to them): the found
## pot's (FirePots.take_found).
static func reach_m() -> float:
	return CrawlerPlayer.REACH_M + 0.4


# --- What you hold (the game's save) ------------------------------------------------

## The fragments you hold in this game (CrawlerSave.data "tome_pages"):
## their ids, each once.
static func held() -> Array:
	var out: Array = []
	var v: Variant = CrawlerSave.data.get(KEEP, [])
	if v is Array:
		for x in v:
			if not out.has(str(x)):
				out.append(str(x))
	return out


## Fragment `fid` is yours: kept in the game's save, written now.
static func keep(fid: String) -> void:
	var h := held()
	if h.has(fid):
		return
	h.append(fid)
	h.sort()
	CrawlerSave.data[KEEP] = h
	CrawlerSave.save()


# --- Where they lie (pure: the layout in) --------------------------------------------

## The floor tomes lie on (descent.json floors.base_layer "last_floor"): the
## dungeon's last floor.
static func base_floor(p_lay: Dictionary) -> int:
	var fl := TombFloors.floors_of(p_lay)
	return int(fl[fl.size() - 1])


## The base layer's hearts: the room at the far end of each of its ways
## (floor two's own ways; on floor one, lay.branches, the spine's end the
## heart), its deepest room, never the hearth room or a big room. Piece ids,
## in the ways' order.
static func hearts_of(p_lay: Dictionary) -> Array:
	var f := base_floor(p_lay)
	var ways: Array = p_lay.get("branches", [])
	if f > 0:
		ways = ((p_lay.get("floors", []) as Array)[f] as Dictionary).get("branches", [])
	var out: Array = []
	for w in ways:
		var best := -1
		var best_d := -1
		for id in w:
			var pc: Dictionary = p_lay.pieces[int(id)]
			if str(pc.kind) != "room" or int(pc.get("floor", 0)) != f or str(pc.get("room_kind", "")) == "hearth" or pc.has("big_room"):
				continue
			var d := int(pc.get("depth", 0))
			if d > best_d or (d == best_d and int(pc.id) > best):
				best_d = d
				best = int(pc.id)
		if best >= 0 and not out.has(best):
			out.append(best)
	return out


## What lies in dungeon `p_lay` with the fragments `p_held` held: one
## {"fragment", "room"} per heart that holds a fragment you don't hold.
static func plan(p_lay: Dictionary, p_held: Array) -> Array:
	var hearts := hearts_of(p_lay)
	var frs := Tomes.layer_fragments(int(p_lay.get("seed", 0)), hearts.size())
	var out: Array = []
	for k in hearts.size():
		var fid := str(frs[k])
		if fid != "" and not p_held.has(fid):
			out.append({"fragment": fid, "room": int(hearts[k])})
	return out


# --- In the dungeon -----------------------------------------------------------------

func build(p_lay: Dictionary, p_player: CrawlerPlayer) -> void:
	lay = p_lay
	player = p_player
	name = "TomePages"
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.unit_size = 2.0
	add_child(_voice)
	# The spots are tried against the stone once it is in the physics world.
	_place.call_deferred()


## Lay each fragment due here on the floor of its room (_spot), unless you
## hold it.
func _place() -> void:
	if not is_inside_tree():
		placed = true
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		placed = true
		return
	for d in plan(lay, held()):
		var pc: Dictionary = lay.pieces[int(d.room)]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(lay.seed), "tome page", str(d.fragment)])
		var at := _spot(pc)
		if not (at.pos as Vector3).is_finite():
			push_warning("TomePages: no clear floor in room %d of tomb %d for %s" % [int(d.room), int(lay.seed), str(d.fragment)])
			continue
		var n := Node3D.new()
		n.name = "Pages_" + str(d.fragment)
		n.set_meta("fragment", str(d.fragment))
		add_child(n)
		n.global_position = at.pos
		# Along the wall it lies by, a little askew.
		n.rotation.y = atan2(-(at.along as Vector2).y, (at.along as Vector2).x) + rng.randf_range(-0.45, 0.45)
		n.add_child(scroll_node())
		lying.append({"fragment": str(d.fragment), "room": int(d.room), "node": n, "pos": at.pos})
	placed = true


## A clear spot on room `pc`'s floor for pages: by its far wall's middle
## first (where there's no door), then its side walls, then further in; the
## floor under it where the room's floor is, clear of the stone (a coffin, a
## pillar, rubble), of the room's torches, its airways, the boss's hole, and
## a resting place's floor. {"pos", "along" (the wall's way, x/z)}; "pos"
## is INF where no spot is clear.
func _spot(pc: Dictionary) -> Dictionary:
	var length := float(pc.len)
	var half := float(pc.half)
	var dir: Vector2 = pc.dir
	var side_v := Delves.perp(dir)
	var sides := {}
	for di in pc.doors:
		sides[str(TombKit.door_side(pc, lay.doors[di])[0])] = true
	var tries: Array = []
	if not sides.has("end"):
		tries.append_array([[length - 0.6, 0.0, side_v], [length - 0.6, half * 0.4, side_v], [length - 0.6, -half * 0.4, side_v]])
	for sd: float in [1.0, -1.0]:
		if not sides.has("left" if sd > 0.0 else "right"):
			tries.append([length * 0.6, sd * (half - 0.55), dir])
			tries.append([length * 0.4, sd * (half - 0.55), dir])
	tries.append_array([[length - 0.9, half * 0.5, side_v], [length - 0.9, -half * 0.5, side_v], [length * 0.7, 0.0, side_v], [length * 0.5, half * 0.5, dir], [length * 0.5, -half * 0.5, dir]])
	var space := get_world_3d().direct_space_state
	var ex: Array[RID] = []
	if player != null:
		ex.append(player.get_rid())
	for tr in tries:
		var q2: Vector2 = (pc.c as Vector2) + dir * float(tr[0]) + side_v * float(tr[1])
		var y := Delves.floor_of(pc, float(tr[0]))
		var p := Vector3(q2.x, y, q2.y)
		if not _clear_of_things(p):
			continue
		var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.4, p - Vector3.UP * 0.5)
		down.collision_mask = PropCollision.WORLD_LAYER
		down.exclude = ex
		var hit := space.intersect_ray(down)
		if hit.is_empty() or absf((hit.position as Vector3).y - y) > 0.06:
			continue
		var ball := SphereShape3D.new()
		ball.radius = 0.24
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = ball
		sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.32)
		sq.collision_mask = PropCollision.WORLD_LAYER
		sq.exclude = ex
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		return {"pos": hit.position, "along": tr[2]}
	return {"pos": Vector3.INF, "along": Vector2.RIGHT}


## Is `p` (a floor point) clear of the room's torches (1.3 m), its airways
## (1.2 m), the boss's hole and the stone broken round it, and every
## resting place's floor (0.9 m: where a skeleton climbs out)?
func _clear_of_things(p: Vector3) -> bool:
	for h in lay.get("holders", []):
		if (h.pos as Vector3).distance_to(p) < 1.3:
			return false
	for a in lay.get("airways", []):
		if Vector2((a.pos as Vector3).x - p.x, (a.pos as Vector3).z - p.z).length() < 1.2:
			return false
	var lair: Dictionary = lay.get("lair", {})
	if not lair.is_empty() and Vector2((lair.pos as Vector3).x - p.x, (lair.pos as Vector3).z - p.z).length() < float(lair.r) + 1.5:
		return false
	for r in lay.get("residents", []):
		for k in ["out", "pos"]:
			if (r as Dictionary).has(k) and absf((r[k] as Vector3).y - p.y) < 1.5 and Vector2((r[k] as Vector3).x - p.x, (r[k] as Vector3).z - p.z).length() < 0.9:
				return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.ui_open or player.typing or player.dead:
		return
	if event.is_action_pressed("interact") and take() != "":
		get_viewport().set_input_as_handled()


## Right click beside pages lying here (within reach_m of your feet, the
## nearest): yours, kept in the game's save at once, gone from the floor,
## the log's line and the paper's rustle. The fragment taken, or "".
func take() -> String:
	if player == null:
		return ""
	var best := -1
	var best_d := reach_m()
	for i in lying.size():
		var n: Node3D = lying[i].node
		if n == null or not is_instance_valid(n):
			continue
		var d := player.global_position.distance_to(n.global_position)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return ""
	var one: Dictionary = lying[best]
	var fid := str(one.fragment)
	keep(fid)
	(one.node as Node3D).queue_free()
	lying.remove_at(best)
	taken += 1
	GameLog.add(log_line(fid), "tome")
	if _voice != null and _voice.is_inside_tree():
		_voice.global_position = one.pos
		_voice.stream = SoundSynth.stream("rustle", taken + int(lay.get("seed", 0)))
		_voice.pitch_scale = 1.35
		_voice.volume_db = -10.0
		Audio3D.play(_voice)
	return fid


## The log's line for fragment `fid` taken (hud.json log_more: tome):
## "You found pages of a tome: The Book of Changes, pages 1 to 15 of 64."
static func log_line(fid: String) -> String:
	var f := Tomes.fragment(fid)
	var id := str(f.get("tome", ""))
	return "You found pages of a tome: %s, %s." % [str(Tomes.entry(id).get("title", "a tome")), Tomes.held_line(id, [fid])]


# --- The scroll ---------------------------------------------------------------------

## The pages as a thing you can see: a rolled scroll on the floor, its
## roll's axis level (local x), its foot at the origin; in the tomb's matte
## material (RuinBuilder.material_lit: only fire lights it), no shadow of
## its own, no light, no collision.
static func scroll_node() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Scroll"
	mi.mesh = scroll_mesh()
	mi.material_override = RuinBuilder.material_lit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The scroll's mesh (cached): the paper roll, 8-sided and flat-faced
## (§ES), a knob of dark wood standing out at each end, and a cord tied
## round its middle; painted, not lit (vertex colours, the underside's
## occlusion toward the scene's navy, Prelit.ao_tint), as the found pot is.
static func scroll_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0.0, ROLL_R, 0.0)
	_tube(st, c, -ROLL_HALF, ROLL_HALF, ROLL_R, PAPER, true)
	for sg: float in [-1.0, 1.0]:
		var x0 := ROLL_HALF * sg
		var x1 := (ROLL_HALF + KNOB_OUT) * sg
		_tube(st, c, minf(x0, x1), maxf(x0, x1), KNOB_R, WOOD, true)
	_tube(st, c, -TIE_HALF, TIE_HALF, ROLL_R + TIE_OVER, CORD, false)
	_mesh = st.commit()
	return _mesh


## An 8-sided tube round the x axis through `c`, from x0 to x1, radius r,
## in colour `col`, its ends capped if `caps`.
static func _tube(st: SurfaceTool, c: Vector3, x0: float, x1: float, r: float, col: Color, caps: bool) -> void:
	for s in SIDES:
		var a0 := TAU * s / SIDES + PI / SIDES
		var a1 := TAU * (s + 1) / SIDES + PI / SIDES
		var o0 := Vector3(0.0, sin(a0), cos(a0)) * r
		var o1 := Vector3(0.0, sin(a1), cos(a1)) * r
		var p00 := c + Vector3(x0, 0.0, 0.0) + o0
		var p01 := c + Vector3(x0, 0.0, 0.0) + o1
		var p10 := c + Vector3(x1, 0.0, 0.0) + o0
		var p11 := c + Vector3(x1, 0.0, 0.0) + o1
		var out := (o0 + o1).normalized()
		_tri(st, p00, p10, p11, col, out)
		_tri(st, p00, p11, p01, col, out)
		if caps:
			_tri(st, c + Vector3(x0, 0.0, 0.0), p00, p01, col, Vector3.LEFT)
			_tri(st, c + Vector3(x1, 0.0, 0.0), p10, p11, col, Vector3.RIGHT)


## One flat triangle facing `hint`'s way, painted with its occlusion (the
## faces toward the floor darker), in the material the tomb's shader reads
## as a plain grain (RuinBuilder.HIDE_M), no moss.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var painted := Prelit.ao_tint(col, 0.45 + 0.55 * (n.y * 0.5 + 0.5))
	var uv := Vector2(float(RuinBuilder.HIDE_M), 0.0)
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(uv)
		st.set_color(Color(painted.r, painted.g, painted.b, 0.0))
		st.add_vertex(v)

class_name RoomPool
## The room pool (design 9 Oct §FM.6, Phantasy Star Online style; data/
## room_pool.json): a few hand-built archetypal big rooms drawn into each
## dungeon among the kit's generic rooms and paths (TombKit), by the
## dungeon's seed. It adds to §EX.2's plan and replaces nothing: the spine
## still runs from the hearth room through the heart to the way out, the
## side ways still end in rooms, the hearth room is still the one hearth
## (§EX.4), and a big room takes the place of one generic room on floor
## one's spine or a side way (its corridor in is the kit's own).
##
##   how many   big_rooms.per_dungeon [least, most], on the pool's own dice
##              (the dungeon's seed and "room pool"), so the kit's dice run
##              as before up to the first slot a big room is due at
##   which      archetypes whose ruin_kinds hold the theme's (crawler.json
##              themes.<theme>.ruin_kind), shuffled on those dice; none
##              twice in a dungeon (no_repeat_in_a_dungeon)
##   where      the floor's room slots that may take one (placed_on: the
##              spine's rooms short of the room before the heart, which is
##              the exit's last stretch with the heart, the way out's flight
##              and landing; and every side way's rooms), counted in the
##              order the kit lays them (the spine first, then each side
##              way); the slots drawn on the same dice; a big room that
##              won't fit where it is drawn tries the next slot on. A tomb
##              left short of the least, or whose big rooms left the boss no
##              lair with its tunnel's hole (keeps_lair), is laid again with
##              them due from the first slot (TombKit.layout).
##
## An archetype (room_pool.json archetypes.<id>) is hand-built: its floor in
## whole modules (width_modules, length_modules), the walls a way may go on
## through (doors_on; a way always comes in through its start wall, in the
## middle), its floor (flat, steps_up to a dais, sunken one stair below its
## doors), its headroom (a heights_m entry of the style over its highest
## floor; the ceiling is level), its pillars (rows across, a beam along each
## row, the slabs spanning across onto them, §EX.3's max_span_m), its
## sconces (on its walls, or cut into its pillars' faces) and what stands in
## it (TombBuild draws them through RoomPoolBuild).
##
## A big room's piece carries "big_room" and "room_kind" (its id), and a
## floor that isn't flat a "profile" (Delves.floor_of reads it: the floor
## along the room, [(along, y)...], each flight a slope under its steps as
## the kit's stairs are); its y0 and y1 are the floor at its way in, its h
## the level ceiling over that. Pure and static.

const FILE := "res://data/room_pool.json"
static var D: Dictionary = _json(FILE)
static var BIG: Dictionary = D.get("big_rooms", {})
static var ARCH: Dictionary = D.get("archetypes", {})


## A data file's table ({} when missing or not JSON), as BossPool reads its.
static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("RoomPool: %s is missing" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("RoomPool: %s is not valid JSON" % path)
		return {}
	return parsed


## Archetype `id`'s data, or {}.
static func archetype(id: String) -> Dictionary:
	return ARCH.get(id, {})


## The theme's ruin kind (crawler.json themes.<theme>.ruin_kind; the theme
## itself where it names none).
static func ruin_kind(theme: String) -> String:
	var th: Dictionary = (Tuning.table("crawler").get("themes", {}) as Dictionary).get(theme, {})
	return str(th.get("ruin_kind", theme))


## The archetypes a ruin of `theme` may draw, in the data's order.
static func for_theme(theme: String) -> Array:
	var rk := ruin_kind(theme)
	var out: Array = []
	for id in ARCH:
		var kinds: Array = (ARCH[id] as Dictionary).get("ruin_kinds", [])
		if rk in kinds:
			out.append(str(id))
	return out


## [least, most] big rooms in a dungeon (big_rooms.per_dungeon).
static func span() -> Vector2i:
	var s: Array = BIG.get("per_dungeon", [1, 2])
	return Vector2i(int(s[0]), maxi(int(s[1]), int(s[0])))


# --- The pool's dice ---------------------------------------------------------------

## The pool for a dungeon (TombKit.layout, once it has rolled the spine's
## rooms `spine_rooms` and how many ways leave the hearth room `want`): how
## many and which archetypes, and the slots they are due at, on the pool's
## own dice. `eager`: due from the first slot on (the second laying of a
## tomb left short). {} when the theme draws none. {"picks" [ids in the
## order they are due], "at" [the slot each is due at, ascending], "slot"
## (slots seen so far), "next" (the next pick due), "placed" [piece ids]}.
static func plan(seed_value: int, theme: String, spine_rooms: int, want: int, eager := false) -> Dictionary:
	var kinds := for_theme(theme)
	if kinds.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "room pool"])
	var sp := span()
	var n := clampi(rng.randi_range(sp.x, sp.y), 0, kinds.size())
	if not bool(BIG.get("no_repeat_in_a_dungeon", true)):
		push_warning("room_pool.json big_rooms.no_repeat_in_a_dungeon false: an archetype still appears once per dungeon (design §FM.6)")
	_shuffle(rng, kinds)
	var picks := kinds.slice(0, n)
	# The slots: the spine's that may take one, then about two a side way.
	var slots := maxi(spine_slots(spine_rooms), 0) + 2 * maxi(want - 1, 1)
	if str(BIG.get("placed_on", "spine_or_branch")) == "spine":
		slots = maxi(spine_slots(spine_rooms), 1)
	elif str(BIG.get("placed_on", "spine_or_branch")) == "branch":
		slots = 2 * maxi(want - 1, 1)
	var order: Array = range(maxi(slots, n))
	_shuffle(rng, order)
	var at: Array = order.slice(0, n)
	at.sort()
	if eager:
		at = range(n)
	return {"picks": picks, "at": at, "slot": 0, "next": 0, "placed": []}


## How many of the spine's `spine_rooms` rooms may take a big room: all but
## the heart and the room before it (the exit's last stretch).
static func spine_slots(spine_rooms: int) -> int:
	return maxi(spine_rooms - 2, 0)


## May room slot `k` of `n_rooms` on way `branch` (0 the spine, then the
## side ways; floor two's ways are TombFloors.BRANCH_BASE and up) take a
## big room (placed_on)?
static func slot_ok(branch: int, k: int, n_rooms: int) -> bool:
	if branch < 0 or branch >= TombFloors.BRANCH_BASE:
		return false
	var on := str(BIG.get("placed_on", "spine_or_branch"))
	if branch == 0:
		return on != "branch" and k < spine_slots(n_rooms)
	return on != "spine"


## The archetype due at the slot now in hand, or "".
static func due(pool: Dictionary) -> String:
	if pool.is_empty() or int(pool.next) >= (pool.picks as Array).size():
		return ""
	return str(pool.picks[int(pool.next)]) if int(pool.slot) >= int(pool.at[int(pool.next)]) else ""


## A slot that may take one has been laid (`room`: the big room laid in it,
## or {} for a generic room).
static func passed(pool: Dictionary, room: Dictionary) -> void:
	if pool.is_empty():
		return
	pool.slot = int(pool.slot) + 1
	if room.has("big_room"):
		(pool.placed as Array).append(int(room.id))
		pool.next = int(pool.next) + 1


## Did `lay` get fewer big rooms than per_dungeon's least, with archetypes
## its theme may draw?
static func short(lay: Dictionary) -> bool:
	if for_theme(str(lay.get("theme", ""))).is_empty():
		return false
	return (lay.get("big_rooms", []) as Array).size() < mini(span().x, for_theme(str(lay.theme)).size())


## Did `lay`'s big rooms leave the boss its lair (design §EY.1: the last
## light drives it back into its lair), in a room its tunnels start from
## (BossGround.place_lair, place_tunnels: neither takes a big room)? A big
## room on a side way can take the dead end the lair would have had, and
## the rooms left may have no floor for it, or no wall for its hole. True
## where it drew none.
static func keeps_lair(lay: Dictionary) -> bool:
	if (lay.get("big_rooms", []) as Array).is_empty():
		return true
	if (lay.get("lair", {}) as Dictionary).is_empty():
		return false
	if BossGround.tunnels_def().is_empty():
		return true
	for h in (lay.get("tunnels", {}) as Dictionary).get("holes", []):
		if bool((h as Dictionary).get("lair", false)):
			return true
	return false


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# --- An archetype's shape ----------------------------------------------------------

## Its floor (m): Vector2(length along the way in, width), whole modules
## `mod` of the style.
static func footprint(id: String, mod: float) -> Vector2:
	var a := archetype(id)
	return Vector2(maxi(int(a.get("length_modules", 5)), 1) * mod, maxi(int(a.get("width_modules", 5)), 1) * mod)


## The floor along it from its way in, over the floor there: [(along, up)...]
## (piecewise straight; a flight's slope under its steps), for a room
## `length` m long. Flat: [] (no profile).
static func floor_steps(id: String, length: float) -> PackedVector2Array:
	var f: Dictionary = archetype(id).get("floor", {})
	var out := PackedVector2Array()
	match str(f.get("kind", "flat")):
		"steps_up":
			var x := clampf(float(f.get("lower_m", 3.0)), 0.5, length)
			var y := 0.0
			var n := maxi(int(f.get("steps", 4)), 1)
			var rise := float(f.get("rise_m", 0.3))
			var run := maxf(float(f.get("run_m", 0.5)), 0.1)
			var tread := maxf(float(f.get("tread_m", 1.5)), 0.3)
			out.append(Vector2(0.0, 0.0))
			out.append(Vector2(x, 0.0))
			for i in n:
				x += run
				y += rise
				out.append(Vector2(x, y))
				if i < n - 1:
					x += tread
					out.append(Vector2(x, y))
			if x < length - 0.01:
				out.append(Vector2(length, y))
		"sunken":
			var t := maxf(float(f.get("terrace_m", 1.0)), 0.3)
			var run := maxf(float(f.get("run_m", 2.0)), 0.3)
			var drop := float(f.get("drop_m", 1.2))
			out.append(Vector2(0.0, 0.0))
			out.append(Vector2(t, 0.0))
			out.append(Vector2(t + run, -drop))
			out.append(Vector2(length - t - run, -drop))
			out.append(Vector2(length - t, 0.0))
			out.append(Vector2(length, 0.0))
	return out


## The ceiling over its way in's floor (m): the style's heights_m entry its
## headroom names, over its highest floor.
static func height(id: String, theme: String, fallback: float, length: float) -> float:
	var top := 0.0
	for q in floor_steps(id, length):
		top = maxf(top, q.y)
	return TombKit.height_of(theme, str(archetype(id).get("headroom", "room")), fallback) + top


## The walls a way may go on through from it.
static func ways_on(id: String) -> Array:
	return archetype(id).get("doors_on", ["end", "left", "right"])


## Lay archetype `id` on `room` (a room piece the kit has sized to it, its
## floor at its way in): its id, its kind and its floor.
static func make(room: Dictionary, id: String) -> void:
	room["big_room"] = id
	room["room_kind"] = id
	var steps := floor_steps(id, float(room.len))
	if steps.is_empty():
		return
	var pf := PackedVector2Array()
	for q in steps:
		pf.append(Vector2(q.x, float(room.y0) + q.y))
	room["profile"] = pf


# --- The floor's heights -----------------------------------------------------------

## Its lowest floor (a sunken court's court), or the piece's lower end.
static func lowest(pc: Dictionary) -> float:
	var y := minf(float(pc.y0), float(pc.y1))
	var pf: Variant = pc.get("profile")
	if pf is PackedVector2Array:
		for q in pf as PackedVector2Array:
			y = minf(y, q.y)
	return y


## Its highest floor (a stepped hall's dais), or the piece's upper end.
static func highest(pc: Dictionary) -> float:
	var y := maxf(float(pc.y0), float(pc.y1))
	var pf: Variant = pc.get("profile")
	if pf is PackedVector2Array:
		for q in pf as PackedVector2Array:
			y = maxf(y, q.y)
	return y


## The ceiling's underside over `along`: a big room's level ceiling (its h
## over its way in's floor); any other piece's its floor and its h.
static func ceiling_at(pc: Dictionary, along: float) -> float:
	if pc.has("profile"):
		return float(pc.y0) + float(pc.h)
	return Delves.floor_of(pc, along) + float(pc.h)


## The level runs of its floor: [[from, to, y]...] along it (a flat room:
## the whole of it), and the slopes between them: [[from, to, y_from,
## y_to]...].
static func runs(pc: Dictionary) -> Dictionary:
	var flats: Array = []
	var slopes: Array = []
	var pf: Variant = pc.get("profile")
	if not pf is PackedVector2Array or (pf as PackedVector2Array).size() < 2:
		flats.append([0.0, float(pc.len), float(pc.y0)])
		return {"flats": flats, "slopes": slopes}
	var p := pf as PackedVector2Array
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		if b.x - a.x < 1e-4:
			continue
		if absf(b.y - a.y) < 1e-4:
			flats.append([a.x, b.x, a.y])
		else:
			slopes.append([a.x, b.x, a.y, b.y])
	return {"flats": flats, "slopes": slopes}


# --- Its plan for the builder (TombBuild._plan_room) --------------------------------

## The pillars' side (m): the archetype's, else the style's.
static func pillar_side(id: String, theme: String) -> float:
	var pl: Dictionary = archetype(id).get("pillars", {})
	return float(pl.get("side_m", RuinStyle.num("pillars.side_m", 0.6, theme)))


## Its pillars in its (along, across), row by row within each along:
## index = along index * rows + row index.
static func pillars(id: String) -> Array:
	var pl: Dictionary = archetype(id).get("pillars", {})
	var rows: Array = pl.get("rows_m", [])
	var out: Array = []
	for a in pl.get("along_m", []):
		for r in rows:
			out.append(Vector2(float(a), float(r)))
	return out


## Room `pc`'s plan (TombBuild's shape, _plan_room): the corbel course
## (`step`, `corbel_h`: TombBuild works them out), its pillars, a beam down
## each row of them from corbel to corbel (s_axis 1: the slabs span across
## onto them), the spans, and "niches": the pillars a sconce is cut into
## (pillar index -> the face's way out, (along, across)).
static func room_plan(lay: Dictionary, pc: Dictionary, step: float, corbel_h: float) -> Dictionary:
	var id := str(pc.big_room)
	var th := str(lay.get("theme", "tomb"))
	var half := float(pc.half)
	var length := float(pc.len)
	var bw := RuinStyle.num("pillars.beam_w_m", 0.5, th)
	var plan := {"step": step, "corbel_h": corbel_h, "pillars": pillars(id), "beams": [], "s_axis": 1, "spans": {}, "big": id,
		"side": pillar_side(id, th), "niches": {}}
	var pl: Dictionary = archetype(id).get("pillars", {})
	var rows: Array = pl.get("rows_m", [])
	var alongs: Array = pl.get("along_m", [])
	if rows.is_empty() or alongs.is_empty():
		plan["s_axis"] = 1 if 2.0 * half <= length else 0
		plan["spans"] = {"slab": minf(length, 2.0 * half) - 2.0 * step, "beam": 0.0}
		return plan
	for r in rows:
		(plan.beams as Array).append([float(r), step, length - step])
	# The slabs across: wall's corbel to a beam's edge, and beam to beam.
	var cuts: Array = [-half + step]
	var rs: Array = rows.duplicate()
	rs.sort()
	for r in rs:
		cuts.append(float(r) - bw * 0.5)
		cuts.append(float(r) + bw * 0.5)
	cuts.append(half - step)
	var slab := 0.0
	for i in range(0, cuts.size() - 1, 2):
		slab = maxf(slab, float(cuts[i + 1]) - float(cuts[i]))
	# The beams along: corbel to a pillar's middle, and pillar to pillar.
	var al: Array = alongs.duplicate()
	al.sort()
	var beam := maxf(float(al[0]) - step, (length - step) - float(al[-1]))
	for i in range(1, al.size()):
		beam = maxf(beam, float(al[i]) - float(al[i - 1]))
	plan["spans"] = {"slab": slab, "beam": beam}
	for s in archetype(id).get("sconces", []):
		if (s as Dictionary).has("pillar"):
			var pi: Array = s.pillar
			var idx := int(pi[0]) * rows.size() + int(pi[1])
			var q: Vector2 = (plan.pillars as Array)[idx]
			(plan.niches as Dictionary)[idx] = Vector2(0.0, -signf(q.y) if absf(q.y) > 1e-3 else 1.0)
	return plan


# --- Its sconces (TombKit._place_holders) --------------------------------------------

## How many sconces it has (its archetype's).
static func sconces_wanted(pc: Dictionary) -> int:
	return (archetype(str(pc.get("big_room", ""))).get("sconces", []) as Array).size()


## Its wall torches as holders (TombKit's shape: {"kind": "sconce", "pos"
## (on the wall's or pillar's face, sconce_h_m over the floor there),
## "normal" (out of the face), "piece", "room": true, "side", "off"}; a
## pillar's: side "pillar", "pillar" [along index, row index]).
static func sconces(lay: Dictionary, pc: Dictionary) -> Array:
	var id := str(pc.big_room)
	var th := str(lay.get("theme", "tomb"))
	var h := float(TombKit.HOLD.get("sconce_h_m", 1.7))
	var length := float(pc.len)
	var out: Array = []
	var pl: Dictionary = archetype(id).get("pillars", {})
	var rows: Array = pl.get("rows_m", [])
	var alongs: Array = pl.get("along_m", [])
	var side := pillar_side(id, th)
	for s in archetype(id).get("sconces", []):
		var sd: Dictionary = s
		if sd.has("wall"):
			var wall := str(sd.wall)
			var off := float(sd.get("along_m", length * 0.5)) - length * 0.5 if wall in ["left", "right"] else float(sd.get("across_m", 0.0))
			out.append_array(TombKit._sconces_on(pc, [wall], [off]))
		elif sd.has("pillar"):
			var pi: Array = sd.pillar
			var a := float(alongs[int(pi[0])])
			var r := float(rows[int(pi[1])])
			# Its face toward the hall's middle line (face aisle).
			var toward := -signf(r) if absf(r) > 1e-3 else 1.0
			var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * a + Delves.perp(pc.dir) * (r + toward * side * 0.5)
			var nv: Vector2 = Delves.perp(pc.dir) * toward
			out.append({"kind": "sconce", "pos": Vector3(q.x, Delves.floor_of(pc, a) + h, q.y), "normal": Vector3(nv.x, 0.0, nv.y), "piece": int(pc.id),
				"room": true, "side": "pillar", "off": a - length * 0.5, "pillar": [int(pi[0]), int(pi[1])]})
	return out

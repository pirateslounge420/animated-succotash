class_name Library
## The library (design 5 Oct §EN; camps.json → sim.library,
## sim.specialists.record_keeper; camp_books.json record_keeper, memory,
## object.placement_eh). Not a record room: a keep of treasured knowledge.
## At every camp at or past the storage rung, a small hut (or, at a ruin,
## a lean-to against an old wall) 4-8 m from the fire, never in the
## workshop, built in the people's own way (huts.library) with:
##   - the camp book on a shelf (it leaves the altar by the hearth; reading
##     it is unchanged, CampBook);
##   - on one wall, up to tomes_max found tomes: at a camp in or beside a
##     ruin, the ruin's delve tome (§DL) while the player has not taken it,
##     readable here (TomePanel) and never taken off the shelf;
##   - on the other wall, the winter count: a hide (or the people's own
##     surface: a slab, a skin, a mat) with one small painted picture a game
##     year of the camp's life, the year's biggest event by the
##     winter_count.events order (the first in the list that happened that
##     year), spiralling out from the middle; no text, pixel glyphs at 16
##     texels a metre (GLYPHS, never a font);
##   - beside it the knot cord: one knot a living folk, coloured by stage
##     (undyed, ochre, indigo), re-tied as the folk change.
## The record-keeper, the fourth face (CampSim gives the role with the
## headman at storage), keeps it: by day at the shelf with the quill
## (always within writes_after_event_game_h of a camp-book line), or
## walking the camp to look at something (the woodpile, the store, the
## newest child, a hide on its frame, the fire) and back, or sitting with a
## tome; at dusk to the fire like everyone. They give the §EJ.4 gift.
## A camp that goes dark keeps its library (survives_abandonment): the
## hide gets one black square and no more years; the knots stay as they
## were. Nothing names what happened (§BQ).

static var L: Dictionary = (Tuning.section("camps", "sim").get("library", {}) as Dictionary)
static var BOOKS: Dictionary = {}
## A pixel a texel; the hide's size in texels.
const TEXELS_PER_M := 16
const HIDE_W := 24
const HIDE_H := 20
const GLYPH_PITCH := 4
## The checks: walks at once.
static var instant := false
## The tomes on library shelves now: [node, tome id].
static var shelves: Array = []
const READ_M := 2.2

## The pictures: 3x3 texels each, "#" painted. No letters, no numerals:
## a small figure, half a flame, a stump, a ring, antlers, two figures, a
## figure lying, a black band, three wavy lines, the black square; a quiet
## year a single dot.
const GLYPHS := {
	"birth": [".#.", "###", "#.#"],
	"fire_low": ["..#", ".##", "###"],
	"woods_stripped": ["...", "###", ".#."],
	"ruin_restored": ["###", "#.#", "###"],
	"hunt_large": ["#.#", "###", ".#."],
	"camp_grew": ["#.#", "#.#", "#.#"],
	"folk_lost": ["...", "###", "#.."],
	"wildfire": ["###", "###", "..."],
	"soak_found": ["#.#", ".#.", "#.#"],
	"dead_camp_last": ["###", "###", "###"],
	"quiet": ["...", ".#.", "..."],
}


static func _data() -> Dictionary:
	if BOOKS.is_empty():
		BOOKS = Tuning.table("camp_books")
	return BOOKS


static func record_keeper() -> Dictionary:
	return (_data().get("record_keeper", {}) as Dictionary)


static func events_order() -> Array:
	return ((L.get("winter_count", {}) as Dictionary).get("events", []) as Array)


## Days in a game year (sky/day_cycle.json year_days).
static func year_days() -> float:
	return DayCycle.year_days()


static func wanted(st: Dictionary) -> bool:
	return int(st.get("rung", 0)) >= Trades.rung_of(str(L.get("rung", "storage")))


# --- The sim: the winter count -----------------------------------------------------

## The camp's year (0 the first) at game day `days`.
static func year_of(st: Dictionary, days: float) -> int:
	return int(floor((days - float(st.get("born_day", days))) / year_days()))


## An event of the winter count's list happened at camp `st` now.
static func event(st: Dictionary, ev: String, days: float) -> void:
	if not events_order().has(ev) or bool(st.get("winter_closed", false)):
		return
	var y := year_of(st, days)
	var ye: Dictionary = st.get("year_events", {})
	var k := str(y)
	if not ye.has(k):
		ye[k] = {}
	(ye[k] as Dictionary)[ev] = int((ye[k] as Dictionary).get(ev, 0)) + 1
	st["year_events"] = ye


## The picture for year `y`: the first event of the order that happened.
static func glyph_of_year(st: Dictionary, y: int) -> String:
	var ev: Dictionary = (st.get("year_events", {}) as Dictionary).get(str(y), {})
	for e in events_order():
		if int(ev.get(str(e), 0)) > 0:
			return str(e)
	return "quiet"


## Once a tick (CampSim): each year that has ended gets its picture; the
## library is remembered once the camp has reached its rung.
static func tick(st: Dictionary, days: float) -> void:
	if wanted(st):
		st["library"] = true
	if bool(st.get("winter_closed", false)):
		return
	var w: Array = st.get("winter", [])
	var y := year_of(st, days)
	while w.size() < y:
		w.append(glyph_of_year(st, w.size()))
	st["winter"] = w


## The camp goes dark (CampSim._abandon): the last picture is the black
## square, no more years; the knots as they were.
static func close(st: Dictionary, days: float) -> void:
	if bool(st.get("winter_closed", false)):
		return
	tick(st, days)
	var w: Array = st.get("winter", [])
	w.append("dead_camp_last")
	st["winter"] = w
	st["winter_closed"] = true
	var knots: Array = []
	for f in st.get("folk", []):
		knots.append(CampSim.stage_of(f))
	st["knots_at_end"] = knots


## The knots: one a living folk (or as they were when the camp went dark),
## its stage.
static func knots_of(st: Dictionary) -> Array:
	if bool(st.get("winter_closed", false)):
		return st.get("knots_at_end", [])
	var out: Array = []
	for f in st.get("folk", []):
		out.append(CampSim.stage_of(f))
	return out


static func knot_colour(stage: String) -> Color:
	var by: Dictionary = ((L.get("knot_cord", {}) as Dictionary).get("colour_by_stage", {}) as Dictionary)
	match str(by.get(stage, "undyed")):
		"ochre":
			return Color(0.78, 0.52, 0.18)
		"indigo":
			return Color(0.2, 0.24, 0.52)
	return Color(0.86, 0.8, 0.66)


# --- The hut ---------------------------------------------------------------------------

## The hut's surface for the winter count from the people's huts.library
## phrase: a slab, a skin, a mat, plaster, bark; a hide by default.
static func surface_of(people: Dictionary) -> String:
	var s := str((people.get("huts", {}) as Dictionary).get("library", "")).to_lower()
	var i := s.find("winter-count")
	var tail := s.substr(i) if i >= 0 else s
	for k in ["slab", "plaster", "bark", "reed mat", "mat", "sealskin", "skin", "hide"]:
		if tail.find(k) >= 0:
			return str(k)
	return "hide"


static func surface_colour(surface: String) -> Color:
	match surface:
		"slab":
			return Color(0.62, 0.5, 0.4)
		"plaster":
			return Color(0.86, 0.84, 0.78)
		"bark":
			return Color(0.5, 0.36, 0.24)
		"reed mat", "mat":
			return Color(0.72, 0.62, 0.38)
		"sealskin":
			return Color(0.48, 0.44, 0.4)
	return Color(0.76, 0.64, 0.46)


## Build the library under camp `root` (origin the fire) for camp `st`.
## `ctx`: people, pal, rng, body, avoid ([pos, r] in root's frame), ruin
## (bool: a lean-to on an old wall), world, chunks, ground (Callable),
## tomes (Array of tome ids for the shelf), key. Returns the node (meta
## "shelf_book", "hide", "cord").
static func build(root: Node3D, st: Dictionary, ctx: Dictionary) -> Node3D:
	var people: Dictionary = ctx.people
	var pal: Array = ctx.get("pal", [])
	var rng: RandomNumberGenerator = ctx.rng
	var ground: Callable = ctx.ground
	# The walls and roof in the people's own workshop materials (§EL's
	# look: the shelter's tints, its wall and roof kinds), square-cut like
	# the workshop hut.
	var lk := Workshop.look(people, pal)
	var wall: Color = lk.wall
	var roof: Color = lk.roof
	var wk := int(lk.wk)
	var rk := int(lk.rk)
	var lean := bool(ctx.get("ruin", false)) or str((people.get("huts", {}) as Dictionary).get("library", "")).find("lean-to") >= 0
	# 4-8 m from the fire, clear of everything round it (the workshop too).
	var spot := Workshop.choose_spot(rng, ctx.get("avoid", []), Vector3.ZERO, 4.0 + 1.2, 8.0, false)
	var at: Vector3 = spot.get("pos", Vector3(5.5, 0, 0))
	var n := Node3D.new()
	n.name = "Library"
	root.add_child(n)
	at.y = float(ground.call(at)) if ground.is_valid() else 0.0
	n.position = at
	# Its open side (+z) to the fire, the back wall away from it.
	n.basis = Basis.looking_at(Vector3(at.x, 0, at.z).normalized(), Vector3.UP)
	var body: StaticBody3D = ctx.body
	var W := 2.4
	var D := 2.0
	var H := 2.0
	var b := Workshop.Build.new()
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	if lean:
		# The old wall at the back (the ruin's stone), the roof leaning on
		# it down to two posts at the front.
		var stone: Color = (ctx.get("stones", RuinBuilder.STONES) as Array)[0]
		b.ybox(Vector3(0, (H + 0.5) * 0.5 - 0.1, -D * 0.5 - 0.2), Vector3(W + 0.6, H + 0.6, 0.45), 0.0, stone, Workshop.STONE, true)
		for sx in [-1.0, 1.0]:
			b.ybox(Vector3(sx * W * 0.5, 0.88, D * 0.5), Vector3(0.1, 1.86, 0.1), 0.0, wall.darkened(0.2), Workshop.WOOD, true)
		# (The low edge above eye height: you see in under it.)
		b.beam(Vector3(0, H + 0.45, -D * 0.5 - 0.1), Vector3(0, 1.85, D * 0.5 + 0.25), X, W + 0.4, 0.08, roof, rk)
		# A screen each side, under the roof: the winter count hangs on the
		# right one, the tome shelf on the left.
		for sx in [-1.0, 1.0]:
			b.ybox(Vector3(sx * (W * 0.5 + 0.05), 0.85, -0.25), Vector3(0.08, 1.7, D - 0.5), 0.0, wall, wk, true)
	else:
		# A small hut: back and side walls, the front open, a pitched roof.
		b.ybox(Vector3(0, H * 0.5 - 0.05, -D * 0.5), Vector3(W, H + 0.1, 0.12), 0.0, wall, wk, true)
		for sx in [-1.0, 1.0]:
			b.ybox(Vector3(sx * W * 0.5, H * 0.5 - 0.05, 0), Vector3(0.12, H + 0.1, D), 0.0, wall.darkened(0.06), wk, true)
		for sx in [-1.0, 1.0]:
			b.beam(Vector3(sx * (W * 0.5 + 0.2), H - 0.1, 0), Vector3(0, H + 0.6, 0), Z, D + 0.4, 0.08, roof, rk)
	# The shelf on the back wall: the camp book on it, a stool before it.
	var shelf_y := 0.85
	b.ybox(Vector3(0, shelf_y, -D * 0.5 + 0.26), Vector3(1.2, 0.06, 0.34), 0.0, CampProps.WOOD.darkened(0.1), Workshop.WOOD, true)
	b.ybox(Vector3(0, 0.18, -D * 0.5 + 0.95), Vector3(0.32, 0.36, 0.32), 0.0, CampProps.WOOD, Workshop.WOOD)
	# The tome wall (left): a shelf for up to tomes_max, upright on it.
	b.ybox(Vector3(-W * 0.5 + 0.2, 1.2, -0.1), Vector3(0.3, 0.05, 1.2), 0.0, CampProps.WOOD.darkened(0.15), Workshop.WOOD, true)
	n.add_child(b.node("Walls"))
	for bx in b.boxes:
		PropCollision.box(body, n.transform * (bx[0] as Transform3D), bx[1])
	n.set_meta("tris", b.tris())
	var book := CampBook.place_on(n, Vector3(0, shelf_y + 0.03, -D * 0.5 + 0.26), str(ctx.get("key", "")), rng)
	n.set_meta("shelf_book", book)
	n.set_meta("seat", {"pos": n.transform * Vector3(0, 0.36, -D * 0.5 + 0.95), "face": n.basis * Vector3(0, 0, -1)})
	var tomes: Array = ctx.get("tomes", [])
	var shown := 0
	for t in tomes.slice(0, int(L.get("tomes_max", 6))):
		var tbb := Workshop.Build.new()
		tbb.ybox(Vector3.ZERO, Vector3(0.07, 0.28, 0.2), 0.0, Color(0.36, 0.2, 0.12).lightened(0.05 * shown), Workshop.HIDE)
		var tb := tbb.node("Tome")
		n.add_child(tb)
		tb.position = Vector3(-W * 0.5 + 0.22, 1.37, -0.5 + shown * 0.12)
		tb.set_meta("tome", str(t))
		shelves.append([tb, str(t)])
		shown += 1
	n.set_meta("tomes", tomes.slice(0, int(L.get("tomes_max", 6))))
	# The winter count (right wall) and the knot cord beside it.
	var surface := surface_of(people)
	var hide := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(float(HIDE_W) / TEXELS_PER_M, float(HIDE_H) / TEXELS_PER_M)
	hide.mesh = qm
	hide.name = "WinterCount"
	hide.position = Vector3(W * 0.5 - 0.09, 1.15, -0.15)
	hide.rotation.y = -PI * 0.5
	# Lit like the camp's other props (the model shader, nearest texels),
	# not a bare material that the sun would blow out white.
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/model.gdshader")
	hm.set_shader_parameter("use_texture", true)
	Look.register(hm)
	hide.material_override = hm
	n.add_child(hide)
	hide.set_meta("surface", surface)
	n.set_meta("hide", hide)
	paint(hide, st)
	var cord := Node3D.new()
	cord.name = "KnotCord"
	cord.position = Vector3(W * 0.5 - 0.1, 1.7, 0.55)
	n.add_child(cord)
	n.set_meta("cord", cord)
	retie(cord, st)
	n.set_meta("door", n.transform * Vector3(0, 0, D * 0.5 + 0.6))
	return n


## Paint the winter count onto `hide` from camp `st`: the surface, one
## picture a year from the middle out (a square spiral), the dead camp's
## black square last.
static func paint(hide: MeshInstance3D, st: Dictionary) -> void:
	var img := Image.create(HIDE_W, HIDE_H, false, Image.FORMAT_RGBA8)
	var base := surface_colour(str(hide.get_meta("surface", "hide")))
	img.fill(base)
	# The edge of the skin, darker.
	for x in HIDE_W:
		img.set_pixel(x, 0, base.darkened(0.25))
		img.set_pixel(x, HIDE_H - 1, base.darkened(0.25))
	for y in HIDE_H:
		img.set_pixel(0, y, base.darkened(0.25))
		img.set_pixel(HIDE_W - 1, y, base.darkened(0.25))
	var w: Array = st.get("winter", [])
	var cells := spiral(w.size())
	for i in w.size():
		var g := str(w[i])
		var rows: Array = GLYPHS.get(g, GLYPHS.quiet)
		var ink := Color(0.06, 0.05, 0.05) if g == "dead_camp_last" else Color(0.55, 0.16, 0.08)
		var c: Vector2i = cells[i]
		var ox := HIDE_W / 2 - 1 + c.x * GLYPH_PITCH
		var oy := HIDE_H / 2 - 1 + c.y * GLYPH_PITCH
		for ry in 3:
			for rx in 3:
				if str(rows[ry])[rx] == "#":
					var px := ox + rx
					var py := oy + ry
					if px > 0 and py > 0 and px < HIDE_W - 1 and py < HIDE_H - 1:
						img.set_pixel(px, py, ink)
	(hide.material_override as ShaderMaterial).set_shader_parameter("albedo_texture", ImageTexture.create_from_image(img))
	hide.set_meta("glyphs", w.size())
	hide.set_meta("painted", w.duplicate())


## The first `n` cells of a square spiral from the middle: (0,0), (1,0),
## (1,1), (0,1), (-1,1), ...
static func spiral(n: int) -> Array:
	var out: Array = []
	var x := 0
	var y := 0
	var dx := 1
	var dy := 0
	var leg := 1
	var walked := 0
	var turns := 0
	while out.size() < n:
		out.append(Vector2i(x, y))
		x += dx
		y += dy
		walked += 1
		if walked == leg:
			walked = 0
			var t := dx
			dx = -dy
			dy = t
			turns += 1
			if turns % 2 == 0:
				leg += 1
	return out


## Tie the cord: one knot a folk, coloured by stage, top to bottom.
static func retie(cord: Node3D, st: Dictionary) -> void:
	for c in cord.get_children():
		cord.remove_child(c)
		c.queue_free()
	var knots := knots_of(st)
	var length := 0.25 + knots.size() * 0.07
	CreatureBodies.box(cord, Vector3(0.012, length, 0.012), Vector3(0, -length * 0.5, 0), Color(0.62, 0.55, 0.42)).name = "Cord"
	for i in knots.size():
		var k := CreatureBodies.box(cord, Vector3(0.035, 0.035, 0.035), Vector3(0, -0.12 - i * 0.07, 0), knot_colour(str(knots[i])))
		k.name = "Knot"
		k.set_meta("stage", str(knots[i]))
	cord.set_meta("knots", knots.duplicate())


## Keep the library true to the sim (Camps, every few seconds): the hide
## repainted when a year's picture is added, the cord re-tied when the
## folk change.
static func refresh(lib: Node3D, st: Dictionary) -> void:
	var hide: MeshInstance3D = lib.get_meta("hide")
	if hide != null and is_instance_valid(hide) and (hide.get_meta("painted", []) as Array) != (st.get("winter", []) as Array):
		paint(hide, st)
	var cord: Node3D = lib.get_meta("cord")
	if cord != null and is_instance_valid(cord) and (cord.get_meta("knots", []) as Array) != knots_of(st):
		retie(cord, st)


## The tome on a library shelf within reach of `pos`: {"node", "tome"} or {}.
static func tome_in_reach(pos: Vector3) -> Dictionary:
	var best := {}
	var best_m := READ_M
	for i in range(shelves.size() - 1, -1, -1):
		var n = shelves[i][0]
		if not is_instance_valid(n):
			shelves.remove_at(i)
			continue
		var dm := (n as Node3D).global_position.distance_to(pos)
		if dm < best_m:
			best_m = dm
			best = {"node": n, "tome": str(shelves[i][1])}
	return best


## The tomes the camp has rescued: at a camp in or beside a ruin, its
## delve's heart tome (§DL) while the player has not taken it.
static func tomes_for(site: Dictionary) -> Array:
	if site.is_empty() or not Delves.has_delve(site):
		return []
	var t := Tomes.heart_tome(int(site.get("seed", 0)))
	if t == "" or (WorldSave.data.get("delve_finds", []) as Array).has(int(site.get("seed", 0))):
		return []
	return [t]


# --- The record-keeper -----------------------------------------------------------------

## The record-keeper's day (Camps, a frame): in the gather hours, at the
## library: writing at the shelf (always just after a camp-book line), or
## out to look at one thing and back, or sitting with a tome. `holders` the
## camp's folk at the fire; returns them without the record-keeper while
## the library has them. `looks` maps a looks_at name to a root-frame
## point.
static func live(root: Node3D, st: Dictionary, holders: Array, h: float, days: float, time: float, delta: float, looks: Dictionary) -> Array:
	var lib: Node3D = root.get_meta("library") if root.has_meta("library") else null
	if lib == null or not is_instance_valid(lib) or str(st.get("state", "")) != "living":
		return holders
	var rk := -1
	var folk: Array = st.get("folk", [])
	for i in folk.size():
		if str((folk[i] as Dictionary).get("role", "")) == "record_keeper":
			rk = i
	var gh: Array = (CampSim.SIM.get("loop", {}) as Dictionary).get("gather_hours", [7, 17])
	var day := h >= float(gh[0]) and h < float(gh[1])
	var hd: Node3D = null
	for hv in holders:
		if is_instance_valid(hv) and int((hv as Node3D).get_meta("folk_i", -1)) == rk:
			hd = hv
	if hd == null:
		return holders
	var speed := float((CampSim.SIM.get("jobs", {}) as Dictionary).get("walk_mps", 1.3))
	var lv: Dictionary = hd.get_meta("rk", {})
	var seat: Dictionary = lib.get_meta("seat")
	var at_shelf := Transform3D(Basis.looking_at(seat.face, Vector3.UP), (seat.pos as Vector3) + Vector3(0, -0.14, 0))
	if lv.is_empty():
		if not day or bool(hd.get_meta("sharing", false)) or not hd.has_meta("home"):
			return holders
		lv = {"leg": "to_lib", "t": 0.0, "from": hd.transform}
		Workshop._stand(hd, true)
		FireCircle._props(hd, "")
		hd.set_meta("idle", "")
	lv.t = float(lv.t) + (1.0e6 if instant else delta)
	match str(lv.leg):
		"to_lib":
			if Sharing._move(hd, lv.from, at_shelf, float(lv.t), speed, delta):
				hd.transform = at_shelf
				Workshop._stand(hd, false)
				lv.leg = "at"
				lv.t = 0.0
				lv.idle = ""
		"at":
			if not day:
				lv.leg = "home"
				lv.t = 0.0
				lv["from"] = hd.transform
				_quill(hd, false)
				Workshop._stand(hd, true)
			else:
				var idle := idle_now(st, days, time)
				if idle != str(lv.get("idle", "")):
					lv.idle = idle
					_quill(hd, idle == "write_at_shelf")
					_tome(hd, idle == "sit_with_tome", lib)
					if idle == "walk_camp_look_at_things":
						var names: Array = record_keeper().get("looks_at", [])
						var there: Array = names.filter(func(x): return looks.has(str(x)))
						if not there.is_empty():
							var p: Vector3 = looks[str(there[int(time / 37.0) % there.size()])]
							var from := hd.transform
							var dir := (p - from.origin)
							dir.y = 0.0
							var stand := p - dir.normalized() * 1.4 if dir.length() > 1.5 else from.origin
							lv.leg = "look"
							lv.t = 0.0
							lv["from"] = from
							lv["look_to"] = Transform3D(Basis.looking_at(dir.normalized() if dir.length() > 0.01 else from.basis.z, Vector3.UP), stand)
							lv["look_at"] = str(there[int(time / 37.0) % there.size()])
							Workshop._stand(hd, true)
				# The pose: head down over the page, a hand moving.
				var arms: Array = hd.get_meta("arms", [])
				if arms.size() >= 2 and str(lv.idle) != "walk_camp_look_at_things":
					(arms[1] as Node3D).rotation.x = lerpf((arms[1] as Node3D).rotation.x, 0.9 + (0.12 * sin(time * 3.0) if str(lv.idle) == "write_at_shelf" else 0.0), clampf(delta * 5.0, 0.0, 1.0))
				var head = hd.get_meta("head") if hd.has_meta("head") else null
				if head != null:
					(head as Node3D).rotation.x = lerpf((head as Node3D).rotation.x, 0.45, clampf(delta * 3.0, 0.0, 1.0))
		"look":
			if Sharing._move(hd, lv.from, lv.look_to, float(lv.t), speed, delta):
				hd.transform = lv.look_to
				# Stands, the hood tips toward the thing, then back.
				var head = hd.get_meta("head") if hd.has_meta("head") else null
				if head != null:
					(head as Node3D).rotation.x = lerpf((head as Node3D).rotation.x, 0.5, clampf(delta * 3.0, 0.0, 1.0))
				if float(lv.t) * speed > hd.transform.origin.distance_to((lv.from as Transform3D).origin) + 4.0 * speed or instant:
					lv.leg = "back"
					lv.t = 0.0
					lv["from"] = hd.transform
		"back":
			if Sharing._move(hd, lv.from, at_shelf, float(lv.t), speed, delta):
				hd.transform = at_shelf
				Workshop._stand(hd, false)
				lv.leg = "at"
				lv.t = 0.0
				lv.idle = "walk_done"
		"home":
			var home: Transform3D = hd.get_meta("home")
			if Sharing._move(hd, lv.from, home, float(lv.t), speed, delta):
				hd.transform = home
				hd.set_meta("base_yaw", hd.rotation.y)
				Workshop._stand(hd, false)
				_tome(hd, false, lib)
				hd.remove_meta("rk")
				return holders
	hd.set_meta("rk", lv)
	var out: Array = []
	for hv in holders:
		if hv != hd:
			out.append(hv)
	return out


## What the record-keeper is doing at the library now: writing within
## writes_after_event_game_h of the book's newest line; otherwise turn
## and turn about, about 40 s each.
static func idle_now(st: Dictionary, days: float, time: float) -> String:
	var book: Array = st.get("book", [])
	if not book.is_empty() and days - float((book[book.size() - 1] as Dictionary).get("d", -1e9)) <= float(record_keeper().get("writes_after_event_game_h", 2.0)) / 24.0:
		return "write_at_shelf"
	var idles: Array = record_keeper().get("idles", ["write_at_shelf", "walk_camp_look_at_things", "sit_with_tome"])
	return str(idles[int(time / 40.0) % idles.size()])


static func _quill(h: Node3D, on: bool) -> void:
	var old = h.get_meta("quill") if h.has_meta("quill") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	h.remove_meta("quill")
	var arms: Array = h.get_meta("arms", [])
	if on and arms.size() >= 2:
		var q := CreatureBodies.cone(arms[1], 0.006, 0.002, 0.24, Vector3(0, -PlayerBody.ARM_M - 0.05, 0.05), Color(0.86, 0.84, 0.78), 0.0, 5)
		q.rotation.x = 0.6
		h.set_meta("quill", q)


static func _tome(h: Node3D, on: bool, lib: Node3D) -> void:
	var old = h.get_meta("tome_held") if h.has_meta("tome_held") else null
	if old != null and is_instance_valid(old):
		(old as Node).queue_free()
	h.remove_meta("tome_held")
	var arms: Array = h.get_meta("arms", [])
	if on and arms.size() >= 2:
		var t := CreatureBodies.box(arms[0], Vector3(0.22, 0.04, 0.28), Vector3(0.1, -PlayerBody.ARM_M - 0.04, 0.06), Color(0.36, 0.2, 0.12))
		h.set_meta("tome_held", t)

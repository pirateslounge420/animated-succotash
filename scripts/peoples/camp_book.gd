class_name CampBook
extends RefCounted
## The camp book (design 4 Oct §ED.3, data/camp_books.json). Folk stay
## mute; every camp keeps one book on an altar by its hearth: a bound book
## or a scroll, yellowed pages, a quill and an ink pot beside it. The books
## are relics of the old builders; the folk who inherited the hearth keep
## writing in them.
##
## It is the camp sim's only readout. CampSim writes a line for every event
## it already emits whose kind lines.events lists (a birth, folk the dark
## took who never came back, the woodpile running low, the store changing,
## the hearth relit, folk leaving for another fire), stamped with the game
## time it happened (CampSim state "book": [{"d", "e", "text"}], at most
## max_pages pages of PAGE_LINES). Fresh ink is dark; a line browns over
## age_brown_days (ink()).
##
## The newest line may be a rumour: with an overrun ruin (§CN) within
## rumour.range_m of the camp, worded from its smoke (§CV): no fire lit
## there, no_smoke; a fire burning there that has not cleared it,
## thin_smoke. Reading the book (right click at the altar, CampBookPanel)
## copies the rumour into your log, once per ruin.

static var D: Dictionary = Tuning.table("camp_books")
const PAGE_LINES := 8
const REACH_M := 2.6
const PAGE := Color(0.82, 0.74, 0.52)
const INK_FRESH := Color(0.1, 0.08, 0.07)
const INK_OLD := Color(0.47, 0.31, 0.15)

## The books standing now: [node, camp key].
static var books: Array = []


static func events() -> Array:
	return (D.get("lines", {}) as Dictionary).get("events", [])


static func max_lines() -> int:
	return int((D.get("lines", {}) as Dictionary).get("max_pages", 12)) * PAGE_LINES


## Write `text` (event kind `event`) in camp `st`'s book at game day
## `days`, if the book keeps that kind of line.
static func write(st: Dictionary, event: String, text: String, days: float) -> void:
	if event == "" or not events().has(event):
		return
	if not st.has("book") or not st.book is Array:
		st["book"] = []
	var b: Array = st.book
	# The same line again the same day (a catch-up re-running an hour) is
	# one line.
	if not b.is_empty() and str(b[b.size() - 1].get("text", "")) == text and absf(float(b[b.size() - 1].get("d", 0.0)) - days) < 0.5:
		return
	b.append({"d": days, "e": event, "text": text})
	while b.size() > max_lines():
		b.pop_front()


## The ink of a line written `age_days` ago: fresh dark, brown by
## age_brown_days.
static func ink(age_days: float) -> Color:
	var k := clampf(age_days / maxf(float((D.get("lines", {}) as Dictionary).get("age_brown_days", 30.0)), 0.01), 0.0, 1.0)
	return INK_FRESH.lerp(INK_OLD, k)


## The rumour for the camp at `d` (a ruin overrun within range_m, worded
## from its smoke), {"text", "key"} or {}.
static func rumour(map: PlanetData, d: Vector3) -> Dictionary:
	var R: Dictionary = D.get("rumour", {})
	var range_m := float(R.get("range_m", 3000.0))
	var best := {}
	var best_m := INF
	for r in Ruins.near(map, d, range_m):
		if not Overrun.is_overrun(r):
			continue
		var dm := CubeSphere.surface_distance_m(d, r.dir)
		if dm < best_m and dm > 60.0:
			best_m = dm
			best = r
	if best.is_empty():
		return {}
	var name := "old " + Ruins.site_name(best).to_lower().replace("old ", "").replace("ruined ", "")
	var words := str(R.get("thin_smoke" if _fire_lit_at(best.dir, 45.0) else "no_smoke", "No smoke from the {ruin} for a season."))
	return {"text": words.replace("{ruin}", name), "key": "rumour:" + Overrun.id_of(best), "dir": best.dir}


## A fire burning (flames or low) within `m` of `d` (FireStore keys are the
## fires' directions, about 3 m cells).
static func _fire_lit_at(d: Vector3, m: float) -> bool:
	for k in FireStore.stores:
		var st: Dictionary = FireStore.stores[k]
		if not str(st.get("state", "")) in ["flames", "low"]:
			continue
		var p := str(k).split(",")
		if p.size() != 3:
			continue
		var fd := Vector3(float(p[0]), float(p[1]), float(p[2])) / 2.0e5
		if fd.length() < 0.5:
			continue
		if CubeSphere.surface_distance_m(fd.normalized(), d) < m:
			return true
	return false


## What the book shows: [{"text", "stamp", "ink": Color, "rumour": bool}],
## oldest first, the rumour last.
static func lines_of(world, st: Dictionary) -> Array:
	var out: Array = []
	var da: Array = st.get("dir", [0.0, 1.0, 0.0])
	var d := Vector3(float(da[0]), float(da[1]), float(da[2])).normalized()
	for e in st.get("book", []):
		var at := float(e.get("d", 0.0))
		out.append({"text": str(e.text), "stamp": world.stamp_at(d, at) if world != null else "", "ink": ink(float(world.days) - at if world != null else 0.0), "rumour": false})
	var r := rumour(world.planet, d) if world != null else {}
	if not r.is_empty():
		out.append({"text": str(r.text), "stamp": world.stamp_text(d), "ink": INK_FRESH, "rumour": true, "key": r.key})
	return out


# --- The book by the hearth --------------------------------------------------

## A small altar (or a shelf of stone) by the fire at `fire_local` in
## `root`'s frame, `r_m` out at bearing `a`, on the ground there; on it the
## book open (or a scroll), a quill and an ink pot. Registered for reading.
static func place(root: Node3D, world, chunks: ChunkManager, key: String, rng: RandomNumberGenerator, r_m := 3.8) -> Node3D:
	var forms: Array = (D.get("object", {}) as Dictionary).get("forms", ["bound book", "scroll"])
	var form := str(forms[rng.randi() % maxi(forms.size(), 1)]) if not forms.is_empty() else "bound book"
	var a := rng.randf() * TAU
	var local := Vector3(cos(a), 0, sin(a)) * r_m
	var g: Vector3 = root.to_global(local)
	var d: Vector3 = world.dir_of(g)
	var ground: Vector3 = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	var n := Node3D.new()
	n.name = "CampBook"
	root.add_child(n)
	n.position = root.to_local(ground)
	n.basis = Basis.looking_at(-local.normalized(), Vector3.UP)
	var body := PropCollision.body(n)
	var stone := Color(0.44, 0.43, 0.4)
	# The altar: a squat block, a slab on it.
	CreatureBodies.box(n, Vector3(0.62, 0.72, 0.46), Vector3(0, 0.3, 0), stone.darkened(0.08))
	CreatureBodies.box(n, Vector3(0.74, 0.1, 0.56), Vector3(0, 0.71, 0), stone)
	PropCollision.box(body, Transform3D(Basis.IDENTITY, Vector3(0, 0.38, 0)), Vector3(0.7, 0.76, 0.52))
	var top := 0.77
	if form == "scroll":
		var roll := CreatureBodies.cone(n, 0.045, 0.045, 0.42, Vector3(0, top + 0.045, 0.02), PAGE.darkened(0.06), 0.0, 8)
		roll.rotation.z = PI * 0.5
		CreatureBodies.box(n, Vector3(0.36, 0.008, 0.22), Vector3(0, top + 0.004, 0.14), PAGE)
	else:
		# Open on the slab: a dark cover, two yellowed pages.
		CreatureBodies.box(n, Vector3(0.44, 0.02, 0.3), Vector3(0, top + 0.01, 0), Color(0.24, 0.13, 0.08))
		for sx: float in [-1.0, 1.0]:
			var pg := CreatureBodies.box(n, Vector3(0.2, 0.025, 0.27), Vector3(sx * 0.105, top + 0.03, 0), PAGE)
			pg.rotation.z = -sx * 0.08
	# The quill and the ink pot.
	var pot := CreatureBodies.cone(n, 0.035, 0.028, 0.06, Vector3(0.27, top + 0.03, -0.14), Color(0.08, 0.08, 0.1), 0.0, 8)
	pot.name = "InkPot"
	var quill := CreatureBodies.cone(n, 0.006, 0.002, 0.26, Vector3(0.24, top + 0.08, -0.08), Color(0.86, 0.84, 0.78), 0.0, 5)
	quill.rotation = Vector3(0.9, 0.0, 0.5)
	n.set_meta("camp_key", key)
	n.set_meta("form", form)
	books.append([n, key])
	return n


## The book on a library shelf (design 5 Oct §EN, placement_eh): the book
## open (or a scroll), the quill and the ink pot at `at` in `parent`'s
## frame, no altar. Registered for reading like the altar's.
static func place_on(parent: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Node3D:
	var forms: Array = (D.get("object", {}) as Dictionary).get("forms", ["bound book", "scroll"])
	var form := str(forms[rng.randi() % maxi(forms.size(), 1)]) if not forms.is_empty() else "bound book"
	var n := Node3D.new()
	n.name = "CampBook"
	parent.add_child(n)
	n.position = at
	if form == "scroll":
		var roll := CreatureBodies.cone(n, 0.045, 0.045, 0.42, Vector3(0, 0.045, 0.02), PAGE.darkened(0.06), 0.0, 8)
		roll.rotation.z = PI * 0.5
	else:
		CreatureBodies.box(n, Vector3(0.44, 0.02, 0.3), Vector3(0, 0.01, 0), Color(0.24, 0.13, 0.08))
		for sx: float in [-1.0, 1.0]:
			var pg := CreatureBodies.box(n, Vector3(0.2, 0.025, 0.27), Vector3(sx * 0.105, 0.03, 0), PAGE)
			pg.rotation.z = -sx * 0.08
	var pot := CreatureBodies.cone(n, 0.035, 0.028, 0.06, Vector3(0.36, 0.03, 0.0), Color(0.08, 0.08, 0.1), 0.0, 8)
	pot.name = "InkPot"
	var quill := CreatureBodies.cone(n, 0.006, 0.002, 0.26, Vector3(0.33, 0.08, 0.04), Color(0.86, 0.84, 0.78), 0.0, 5)
	quill.rotation = Vector3(0.9, 0.0, 0.5)
	n.set_meta("camp_key", key)
	n.set_meta("form", form)
	n.set_meta("shelf", true)
	books.append([n, key])
	return n


## The book within reach of `pos` (scene), or {}: {"node", "key"}.
static func in_reach(pos: Vector3) -> Dictionary:
	var best := {}
	var best_m := REACH_M
	for i in range(books.size() - 1, -1, -1):
		var n = books[i][0]
		if not is_instance_valid(n):
			books.remove_at(i)
			continue
		var dm := (n as Node3D).global_position.distance_to(pos)
		if dm < best_m:
			best_m = dm
			best = {"node": n, "key": str(books[i][1])}
	return best

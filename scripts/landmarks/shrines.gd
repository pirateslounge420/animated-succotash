class_name Shrines
extends Node
## The shrine and the sealed scroll (design 3 Oct §DK, data/shrines.json
## shrine, scroll and log). Built behind the hidden places' shrine mouths
## (§DJ, HiddenPlaces: the burning shrine, and the oak door under its
## great tree):
##
##   the court    flagstones over the ground's hole round the way down, a
##                low parapet each side of it (Delves' holes: the ground is
##                4 m quads, so a hole opens a little past what it needs);
##   the hall     a long narrow stair down into the hill (a §BB corridor:
##                dark, the torchlight the only light), shrine.sconces
##                (6-8) torches in brackets along its walls, lit when you
##                first come and burning without fuel (what they burn is
##                open, shrine.light), never smoking (§CV);
##   the altar    a room at the hall's foot, the sealed scroll on its altar,
##                and behind the altar a solid wall;
##   below        behind that wall, steps down to a room (the barrow
##                delve's stair and heart kit, for now: what lies deeper is
##                open).
##
## The pattern lock: each shrine has a seeded pattern of lit and dark
## sconces (never all lit, never all dark). Right click a lit sconce to
## smother it; the torch's swing lights a dark one (§CN, no kindling).
## When the hall matches, the wall behind the altar gives way (log.opened),
## once. A wrong pattern does nothing: no hint, no counter, no UI.
##
## The scroll: right click takes it (log.taken). Carry it (hands empty) and
## right click a folk to show it: anyone but the reader turns it over and
## hands it back (log.shown). The reader (scroll.readers, first guess
## "headman_far", a stand-in): the headman, else the first sitter, of the
## nearest lived-in camp scroll.reader_far_km (5-60 km) from the shrine.
## They ask where you found it (log.asked_where), then read it: a passage
## (scroll.passage_first_guess) and the pattern as a sentence, kept whole
## in the log (hud.json log_more.keep_deciphered_whole); the item becomes
## "Opened scroll". Saved per world (WorldSave "shrines").

static var S: Dictionary = Tuning.table("shrines")
static var SHRINE: Dictionary = S.get("shrine", {})
static var SCROLL: Dictionary = S.get("scroll", {})
static var LOG: Dictionary = S.get("log", {})
static var instance: Shrines = null
static var _layouts := {}
static var _mutex := Mutex.new()

## The hidden places' kits with a shrine behind them.
const KITS := ["burning_shrine", "oak_door"]
const HALL_HALF := 0.9
const HALL_H := 2.6
const ROOM_L := 6.0
const ROOM_HALF := 2.4
const ROOM_H := 3.2
## Reach for smothering a sconce (right click).
const SCONCE_REACH_M := 2.4
const ORDINALS := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]

var world: Node
var chunks: ChunkManager
var player: PlanetPlayer
## Built shrines: place key -> {"node", "place", "lay", "sconces": [Node3D],
## "wall": Node3D or null, "scroll": WorldItem or null}.
var built := {}


func setup(p_world: Node, p_chunks: ChunkManager, p_player: PlanetPlayer) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	instance = self
	if not WorldSave.data.get("shrines", null) is Dictionary:
		WorldSave.data["shrines"] = {}


func _exit_tree() -> void:
	if instance == self:
		instance = null


# --- The layout (pure) -------------------------------------------------------------

## Where a place's way down starts (its mouth): the burning shrine's place
## itself; the oak door's at the foot of its tree, on its door side.
static func trunk_r(place: Dictionary) -> float:
	return clampf(float((place.tree as Array)[1]) * 0.03, 0.6, 1.4) if place.has("tree") else 0.0


## Where the hall's roof begins (its facade), as a surface direction: the
## oak door's at its tree's foot.
static func facade_dir(map: PlanetData, place: Dictionary) -> Vector3:
	var lay := layout(map, place)
	return Delves.to_dir(lay.fr, 0.0, 0.5 + float(lay.open_to))


## The shrine behind hidden place `place` (a burning shrine or an oak
## door), worked out once and cached: {"site" (the delve frame's site:
## dir, heading, seed), "fr", "base_e", "pieces" ([hall, room, stair,
## heart] as Delves pieces), "holes" ([Rect2]), "open_to" (how far down
## the hall is open to the sky), "sconces" ([Vector3, side] local),
## "pattern" ([bool]), "altar", "scroll", "wall" (local Vector3s)}.
static func layout(map: PlanetData, place: Dictionary) -> Dictionary:
	var key := str(place.key)
	_mutex.lock()
	var hit = _layouts.get(key)
	_mutex.unlock()
	if hit != null:
		return hit
	var lay := _make_layout(map, place)
	_mutex.lock()
	_layouts[key] = lay
	_mutex.unlock()
	return lay


static func _make_layout(map: PlanetData, place: Dictionary) -> Dictionary:
	if str(place.kit) != "oak_door":
		return _layout_at(map, place, place.dir)
	# The oak door: the open steps in front of the tree, the roofed hall
	# from its foot on under it.
	var tr := trunk_r(place)
	var lay := _layout_at(map, place, CreatureSpawner._offset(place.dir, float(place.facing), tr + 7.0))
	return _layout_at(map, place, CreatureSpawner._offset(place.dir, float(place.facing), tr + 1.0 + float(lay.open_to)))


static func _layout_at(map: PlanetData, place: Dictionary, mouth: Vector3) -> Dictionary:
	var heading := Delves.grid_heading(mouth, float(place.facing))
	var site := {"dir": mouth, "heading": heading, "seed": int(place.seed), "kind": "shrine", "shrine": true, "key": str(place.key)}
	var fr := Delves.frame(map, site)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(place.seed), "shrine"])
	var hall_len := rng.randf_range(16.0, 21.0)
	var y0 := Delves._g0(map, fr, 0.0, 0.5) + 0.05
	var slope := 0.32
	var pieces: Array = []
	for attempt in 14:
		var y1 := y0 - hall_len * slope
		var hall := Delves.piece("stair", Vector2(0.0, 0.5), Vector2(0.0, 1.0), hall_len, HALL_HALF, y0, y1, HALL_H)
		var zr := 0.5 + hall_len
		var room := Delves.piece("room", Vector2(0.0, zr), Vector2(0.0, 1.0), ROOM_L, ROOM_HALF, y1, y1, ROOM_H)
		var run := 3.0 / Delves.SLOPE
		var stair := Delves.piece("stair", Vector2(0.0, zr + ROOM_L), Vector2(0.0, 1.0), run, 0.85, y1, y1 - 3.0, Delves.H_STAIR)
		var heart := Delves.piece("heart", Vector2(0.0, zr + ROOM_L + run), Vector2(0.0, 1.0), 6.0, 3.0, y1 - 3.0, y1 - 3.0, Delves.H_HEART)
		pieces = [hall, room, stair, heart]
		var deficit := 0.0
		for k in range(1, pieces.size()):
			var pc: Dictionary = pieces[k]
			deficit = maxf(deficit, Delves._short_of_cover(map, fr, pc, 0.0, float(pc.len)))
		if deficit <= 0.0:
			break
		if slope < 0.6:
			slope += 0.04
		else:
			hall_len += 2.0
	var hall: Dictionary = pieces[0]
	var room: Dictionary = pieces[1]
	var open_to := Delves._hole1_len(map, fr, hall)
	var lay := {"ok": true, "site": site, "fr": fr, "base_e": fr.base_e, "pieces": pieces, "y0": y0, "open_to": open_to,
		"holes": [Delves.rect_of(hall, 0.0, -0.4, open_to + 0.5)]}
	# The sconces along the hall, sides in turn, the first nearest the mouth.
	var sc: Array = SHRINE.get("sconces", [6, 8])
	var n := rng.randi_range(int(sc[0]), int(sc[1]))
	var out: Array = []
	for i in n:
		var a := lerpf(2.0, float(hall.len) - 1.0, (i + 0.5) / n)
		var side := 1.0 if i % 2 == 0 else -1.0
		out.append([Vector3(side * (HALL_HALF - 0.06), Delves.floor_of(hall, a) + 1.55, 0.5 + a), side])
	lay.sconces = out
	# The pattern: seeded, never all lit (how you find it), never all dark.
	var pattern: Array = []
	for attempt in 50:
		pattern.clear()
		for i in n:
			pattern.append(rng.randf() < 0.5)
		if pattern.has(true) and pattern.has(false):
			break
	if not pattern.has(false):
		pattern[0] = false
	if not pattern.has(true):
		pattern[n - 1] = true
	lay.pattern = pattern
	var yr := float(room.y0)
	var z_end := float((room.c as Vector2).y) + ROOM_L
	lay.altar = Vector3(0.0, yr, z_end - 1.5)
	lay.scroll = Vector3(0.0, yr + 1.02, z_end - 1.5)
	lay.wall = Vector3(0.0, yr, z_end)
	return lay


## The pattern as the reader says it: "The first, the fourth and the
## sixth burn. The rest are dark."
static func pattern_words(pattern: Array) -> String:
	var lit: Array = []
	for i in pattern.size():
		if bool(pattern[i]):
			lit.append("the " + str(ORDINALS[i]) if i < ORDINALS.size() else "the %dth" % (i + 1))
	var list := ""
	if lit.size() == 1:
		list = lit[0]
	else:
		list = ", ".join(lit.slice(0, lit.size() - 1)) + " and " + str(lit[lit.size() - 1])
	return (list.substr(0, 1).to_upper() + list.substr(1)) + (" burns." if lit.size() == 1 else " burn.") + " The rest are dark."


## The shrines' holes in the ground near `d` (Delves.chunk_holes):
## [{"fr", "holes"}].
static func holes_near(map: PlanetData, d: Vector3, radius: float) -> Array:
	var out: Array = []
	if RoadNetwork.instance == null or map == null:
		return out
	for pl in HiddenPlaces.near(RoadNetwork.instance, d, radius + 40.0):
		if str(pl.kit) in KITS:
			var lay := layout(map, pl)
			out.append({"fr": lay.fr, "holes": lay.holes})
	return out


# --- The reader ----------------------------------------------------------------------

## The camp whose reader reads this shrine's scroll: the nearest lived-in
## camp (an inhabited ruin's, not overrun) between reader_far_km[0] and
## [1] from the shrine. {"key" ("ruin:<cell>"), "dir", "km"} or {}.
static func reader_camp(map: PlanetData, place: Dictionary) -> Dictionary:
	var far: Array = SCROLL.get("reader_far_km", [5.0, 60.0])
	var lo := float(far[0]) * 1000.0
	var hi := float(far[1]) * 1000.0
	var best := {}
	var bd := INF
	for c in CreatureSpawner._cells_around(place.dir, hi, Ruins.CELL_M):
		var s := Ruins.find(map, c)
		if s.is_empty() or not Ruins.inhabited(s) or Overrun.is_overrun(s):
			continue
		var dm := CubeSphere.surface_distance_m(s.dir, place.dir)
		if dm < lo or dm > hi or dm >= bd:
			continue
		bd = dm
		best = {"key": "ruin:%s" % str(c), "dir": s.dir, "km": dm / 1000.0, "site": s}
	return best


## Is `folk` (a camp's sitter; its camp node its parent) the reader of
## `place`'s scroll: at the reader camp, its headman, else its first
## sitter when it has no headman?
static func is_reader(map: PlanetData, place: Dictionary, folk: Node3D) -> bool:
	var rc := reader_camp(map, place)
	if rc.is_empty() or folk == null:
		return false
	var cn := folk.get_parent() as Node3D
	if cn == null or str(cn.get_meta("key", "")) != str(rc.key):
		return false
	var sitters: Array = cn.get_meta("sitters", [])
	for s in sitters:
		if (s as Node3D).get_meta("role", "") == "headman":
			return s == folk
	return not sitters.is_empty() and sitters[0] == folk


# --- State -----------------------------------------------------------------------------

## The saved state of the shrine `key`: {"lit": [bool], "opened", "taken"}.
static func state(key: String, n: int) -> Dictionary:
	var all: Dictionary = WorldSave.data.get("shrines", {})
	if not WorldSave.data.get("shrines", null) is Dictionary:
		WorldSave.data["shrines"] = all
	if not all.has(key):
		var lit: Array = []
		for i in n:
			lit.append(true)
		all[key] = {"lit": lit, "opened": false, "taken": false}
	return all[key]


# --- In play -------------------------------------------------------------------------

## Build the shrine behind hidden place `pl` into the hidden place's node
## `root` (HiddenPlaces.build): the court, hall, rooms (a RuinBuilder node
## carrying the delve, for the dark and Delves.locate), the sconces, the
## altar and its scroll, and the wall.
func build_into(root: Node3D, pl: Dictionary) -> void:
	var map: PlanetData = world.planet
	var lay := layout(map, pl)
	var data := RuinBuilder.compute_shrine(map, lay.site, lay)
	var node := RuinBuilder.make_node(data, world)
	node.name = "Shrine"
	root.add_child(node)
	node.global_transform = RuinBuilder.placement(data, world)
	node.set_meta("shrine", str(pl.key))
	# Its collision at once (it is small).
	while RuinBuilder.wants_collision(node):
		RuinBuilder.build_collision_part(node)
	var off := float(data.get("delve_off", 0.0))
	var st := state(str(pl.key), (lay.sconces as Array).size())
	var entry := {"node": node, "place": pl, "lay": lay, "sconces": [], "wall": null, "scroll": null, "off": off}
	for i in (lay.sconces as Array).size():
		var s: Array = lay.sconces[i]
		var lp: Vector3 = s[0]
		var sn := _sconce(node, Vector3(lp.x, lp.y - off, lp.z), float(s[1]))
		sn.set_meta("shrine", str(pl.key))
		sn.set_meta("index", i)
		_set_lit(sn, bool((st.lit as Array)[i]))
		(entry.sconces as Array).append(sn)
	# The altar.
	var al: Vector3 = lay.altar
	var altar := lit_block(Vector3(1.6, 1.0, 0.9), int(pl.seed), Color(0.4, 0.4, 0.43))
	altar.name = "Altar"
	altar.position = Vector3(al.x, al.y - off + 0.5, al.z)
	node.add_child(altar)
	PropCollision.box(node.get_node("Collision") as StaticBody3D, Transform3D(Basis(), altar.position), Vector3(1.6, 1.0, 0.9))
	# The wall behind the altar (gone once opened).
	if not bool(st.opened):
		entry.wall = _wall(node, lay, off)
	# The scroll on the altar (once).
	if not bool(st.taken):
		var sp: Vector3 = node.global_transform * Vector3((lay.scroll as Vector3).x, (lay.scroll as Vector3).y - off, (lay.scroll as Vector3).z)
		var d: Vector3 = world.dir_of(sp)
		var pd: Vector3 = pl.dir
		var it := WorldItem.drop(Inventory.make("scroll", {"shrine": str(pl.key), "sealed": true, "at": [pd.x, pd.y, pd.z], "pattern": (lay.pattern as Array).duplicate()}), world, d, world.radius_of(sp) - PlanetConst.RADIUS_M)
		it.set_meta("shrine_scroll", str(pl.key))
		entry.scroll = it
	built[str(pl.key)] = entry


## A stone block for the shrine's inside, lit per pixel like the delve's
## own mesh (RuinBuilder.make_node turns its faces the same way).
static func lit_block(size: Vector3, seed_v: int, col: Color) -> MeshInstance3D:
	var src := RuinBuilder.rock_mesh(size, seed_v, col, true)
	var arrays := src.surface_get_arrays(0)
	RuinBuilder._flip_winding(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = RuinBuilder.material_lit()
	return mi


## Free the shrine of `key` (its node goes with the hidden place's).
func drop(key: String) -> void:
	var e: Dictionary = built.get(key, {})
	if not e.is_empty() and e.scroll != null and is_instance_valid(e.scroll):
		(e.scroll as Node).queue_free()
	built.erase(key)


## A sconce: a stone bracket on the wall (no metal, §EH), a torch in it, its flame and
## light (a Torch flame: one shader for every fire; never smoking).
func _sconce(parent: Node3D, at: Vector3, side: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Sconce"
	parent.add_child(n)
	n.position = at
	var bracket := lit_block(Vector3(0.3, 0.1, 0.1), 7, Color(0.34, 0.33, 0.31))
	bracket.position = Vector3(-side * 0.13, -0.12, 0.0)
	n.add_child(bracket)
	var stick := CreatureBodies.cone(n, 0.035, 0.028, 0.5, Vector3(-side * 0.22, 0.05, 0.0), Color(0.28, 0.19, 0.11))
	stick.rotation.z = side * 0.25
	var flame := Torch.flame_node()
	flame.name = "Flame"
	flame.position = Vector3(-side * 0.28, 0.33, 0.0)
	n.add_child(flame)
	var light := Torch.light_node()
	light.name = "Light"
	light.omni_range = 6.5
	light.light_energy *= 0.75
	light.position = Vector3(-side * 0.45, 0.35, 0.0)
	n.add_child(light)
	return n


func _set_lit(sn: Node3D, on: bool) -> void:
	sn.set_meta("lit", on)
	(sn.get_node("Flame") as Node3D).visible = on
	(sn.get_node("Light") as Light3D).visible = on


static func is_lit(sn: Node3D) -> bool:
	return bool(sn.get_meta("lit", false))


## The wall across the altar room's end (the way down behind it).
func _wall(node: Node3D, lay: Dictionary, off: float) -> Node3D:
	var w: Vector3 = lay.wall
	var size := Vector3(2.0 * 0.85 + 0.5, Delves.H_STAIR + 0.4, Delves.WALL)
	var mi := lit_block(size, 11, Color(0.38, 0.39, 0.42))
	mi.name = "Wall"
	mi.position = Vector3(w.x, w.y - off + size.y * 0.5 - 0.05, w.z + Delves.WALL * 0.5)
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = PropCollision.WORLD_LAYER
	mi.add_child(body)
	PropCollision.box(body, Transform3D(), size)
	return mi


## The sconce within reach of `pos` (lit if `lit`, else dark), or null.
func sconce_near(pos: Vector3, radius: float, lit: bool) -> Node3D:
	for k in built:
		for sn in built[k].sconces:
			if is_instance_valid(sn) and is_lit(sn) == lit and (sn as Node3D).global_position.distance_to(pos) < radius:
				return sn
	return null


## Right click a lit sconce: smother it (no smoke, no log).
func smother(sn: Node3D) -> void:
	_switch(sn, false)


## The torch's swing lights a dark sconce (§CN).
func light(sn: Node3D) -> void:
	_switch(sn, true)


func _switch(sn: Node3D, on: bool) -> void:
	_set_lit(sn, on)
	var key := str(sn.get_meta("shrine", ""))
	var e: Dictionary = built.get(key, {})
	if e.is_empty():
		return
	var st := state(key, (e.sconces as Array).size())
	(st.lit as Array)[int(sn.get_meta("index", 0))] = on
	WorldSave.mark_dirty()
	check(key)


## Does the hall of `key` match its pattern? Then the wall gives way, once.
## True if it opened now.
func check(key: String) -> bool:
	var e: Dictionary = built.get(key, {})
	if e.is_empty():
		return false
	var st := state(key, (e.sconces as Array).size())
	if bool(st.opened):
		return false
	var pattern: Array = e.lay.pattern
	for i in pattern.size():
		if bool((st.lit as Array)[i]) != bool(pattern[i]):
			return false
	st.opened = true
	WorldSave.mark_dirty()
	if e.wall != null and is_instance_valid(e.wall):
		(e.wall as Node).queue_free()
	e.wall = null
	GameLog.add(str(LOG.get("opened", "The wall behind the altar gives way. Steps go down.")), "shrine")
	return true


## The scroll from `key`'s altar was taken (Main).
static func took(key: String) -> void:
	var all: Dictionary = WorldSave.data.get("shrines", {})
	if all.has(key):
		all[key].taken = true
	else:
		state(key, 0).taken = true
	WorldSave.mark_dirty()
	GameLog.add(str(LOG.get("taken", "You took the scroll from the altar.")), "scroll")


## Show `it` (a scroll) to `folk`: the reader asks, then reads it whole and
## it is opened; anyone else hands it back. Returns "read", "shown" or
## "read_before".
static func show_to(map: PlanetData, it: Dictionary, folk: Node3D) -> String:
	var at: Array = it.get("at", [])
	var place := {"dir": Vector3(float(at[0]), float(at[1]), float(at[2]))} if at.size() == 3 else {}
	if not bool(it.get("sealed", true)):
		GameLog.add(str(LOG.get("shown", "They turn the scroll over and hand it back.")), "shown")
		return "read_before"
	if place.is_empty() or not is_reader(map, place, folk):
		GameLog.add(str(LOG.get("shown", "They turn the scroll over and hand it back.")), "shown")
		return "shown"
	GameLog.add(str(LOG.get("asked_where", "\"Where did you find this?\"")), "asked")
	var lines: Array = SCROLL.get("passage_first_guess", [])
	var text := "\n".join(lines.map(func(l): return str(l))) + "\n" + pattern_words(it.get("pattern", []))
	GameLog.add(text, "deciphered")
	it["sealed"] = false
	it["title"] = "Opened scroll"
	WorldSave.mark_dirty()
	return "read"

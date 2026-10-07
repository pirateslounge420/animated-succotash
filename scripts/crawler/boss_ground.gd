class_name BossGround
extends RefCounted
## A boss's ground (design 6 Oct §EY.1, §EY.2; data/bosses.json rule): the
## tomb (TombKit.layout) as a graph of rooms and corridor stretches, each
## lit or dark. A room is one node. A corridor or a flight of stairs is cut
## at each of its wall sconces into stretches, each a node. Two nodes touch
## at a door (the door's middle, on its floor) or at a sconce (the
## corridor's middle line there). The boss's ground is every dark node:
##
##   a room       lit once every torch in it is lit (rule.room_relit_when
##                all_torches_lit, §EX.4's two or four); the hearth room is
##                lit from the start and never its ground. A room with no
##                torch of its own takes its light from round it, as a
##                stretch does.
##   a stretch    lit when every end of it is: a lit sconce, or a door into
##                a lit node ("a corridor stretch between two lit sconces
##                counts as lit", and a lit room's doorway is a light as
##                good as a sconce). An end with nothing there (a dead end,
##                the way out's daylight) never darkens it.
##
## So every holder is some node's light, and the ground reaches nothing at
## the last one (the release, §EY.2). update() recomputes it from the
## holders' lit flags on every relight. Pure: the layout in, the graph out;
## the boss walks it (Boss). The lair's place is chosen here too
## (place_lair), so the generator (TombKit) and the builder (TombBuild)
## share it.

## [{"id", "kind" ("room" / "stretch"), "piece", "a0", "a1" (the stretch's
## span along its piece; a room 0..len), "holders" (a room's torches,
## indices into lay.holders), "ends" (a stretch's: [{"type": "sconce",
## "holder"} / {"type": "door", "node"} / {"type": "open"}]), "hearth",
## "lit", "center" (Vector3, on its floor), "doors" (how many doors it
## has: a room with one is a dead end), "links" ([{"to", "via" (Vector3),
## "cost", "door" (door id, -1 at a sconce)}])}]
var nodes: Array = []
var lay: Dictionary = {}
## piece id -> [node ids], a corridor's stretches in order along it.
var by_piece: Dictionary = {}
## The holders' lit flags the graph was last worked out from.
var holders_lit: Array = []


static func build(p_lay: Dictionary) -> BossGround:
	var g := BossGround.new()
	g.lay = p_lay
	g._make()
	var cold: Array = []
	cold.resize((p_lay.get("holders", []) as Array).size())
	cold.fill(false)
	g.update(cold)
	return g


func _node(kind: String, pc: Dictionary, a0: float, a1: float) -> Dictionary:
	var n := {"id": nodes.size(), "kind": kind, "piece": int(pc.id), "a0": a0, "a1": a1, "holders": [], "ends": [],
		"hearth": str(pc.get("room_kind", "")) == "hearth", "lit": false, "doors": 0, "links": []}
	n["center"] = point(pc, (a0 + a1) * 0.5, 0.0)
	nodes.append(n)
	if not by_piece.has(int(pc.id)):
		by_piece[int(pc.id)] = []
	(by_piece[int(pc.id)] as Array).append(n.id)
	return n


## A point in piece `pc`, `along` it and `across` its middle line, on its
## floor.
static func point(pc: Dictionary, along: float, across: float) -> Vector3:
	var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + Delves.perp(pc.dir) * across
	return Vector3(q.x, Delves.floor_of(pc, along), q.y)


func _make() -> void:
	var holders: Array = lay.get("holders", [])
	# Every piece's nodes: a room whole, a corridor or stair cut at its
	# sconces.
	for pc in lay.pieces:
		if str(pc.kind) == "room":
			var n := _node("room", pc, 0.0, float(pc.len))
			for i in holders.size():
				if int(holders[i].piece) == int(pc.id):
					(n.holders as Array).append(i)
			continue
		var cuts: Array = []
		for i in holders.size():
			var h: Dictionary = holders[i]
			if int(h.piece) == int(pc.id) and str(h.kind) == "sconce":
				var a := Delves.along_across(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z)).x
				cuts.append([clampf(a, 0.05, float(pc.len) - 0.05), i])
		cuts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
		var a0 := 0.0
		var prev := -1
		for c in cuts:
			var n := _node("stretch", pc, a0, float(c[0]))
			if prev >= 0:
				(n.ends as Array).append({"type": "sconce", "holder": prev})
			(n.ends as Array).append({"type": "sconce", "holder": int(c[1])})
			a0 = float(c[0])
			prev = int(c[1])
		var last := _node("stretch", pc, a0, float(pc.len))
		if prev >= 0:
			(last.ends as Array).append({"type": "sconce", "holder": prev})
	# The sconces join a corridor's stretches, on its middle line.
	for pid in by_piece:
		var ids: Array = by_piece[pid]
		var pc: Dictionary = lay.pieces[int(pid)]
		for k in range(ids.size() - 1):
			var a: Dictionary = nodes[ids[k]]
			var b: Dictionary = nodes[ids[k + 1]]
			_link(a, b, point(pc, float(a.a1), 0.0), -1)
	# The doors join pieces.
	for d in lay.doors:
		var na := _node_by_door(int(d.a), d)
		var nb := _node_by_door(int(d.b), d)
		if na < 0 or nb < 0:
			continue
		var via := Vector3((d.p as Vector2).x, float(d.y), (d.p as Vector2).y)
		_link(nodes[na], nodes[nb], via, int(d.id))
		nodes[na].doors = int(nodes[na].doors) + 1
		nodes[nb].doors = int(nodes[nb].doors) + 1
		for pair in [[na, nb], [nb, na]]:
			var n: Dictionary = nodes[pair[0]]
			if str(n.kind) == "stretch":
				(n.ends as Array).append({"type": "door", "node": int(pair[1])})
	# A stretch's end with no door and no sconce: open (a dead end, or the
	# way out).
	for n in nodes:
		if str(n.kind) == "stretch" and (n.ends as Array).size() < 2:
			(n.ends as Array).append({"type": "open"})


## The node of piece `pid` that door `d` opens from.
func _node_by_door(pid: int, d: Dictionary) -> int:
	var ids: Array = by_piece.get(pid, [])
	if ids.is_empty():
		return -1
	if ids.size() == 1:
		return int(ids[0])
	var pc: Dictionary = lay.pieces[pid]
	var a := clampf(Delves.along_across(pc, d.p).x, 0.0, float(pc.len))
	for id in ids:
		if a <= float(nodes[id].a1) + 0.001:
			return int(id)
	return int(ids[-1])


func _link(a: Dictionary, b: Dictionary, via: Vector3, door: int) -> void:
	var cost := (a.center as Vector3).distance_to(via) + via.distance_to(b.center)
	(a.links as Array).append({"to": int(b.id), "via": via, "cost": cost, "door": door})
	(b.links as Array).append({"to": int(a.id), "via": via, "cost": cost, "door": door})


## Work the light out again from the holders' lit flags (`lit`, in
## lay.holders' order). Returns whether anything changed.
func update(lit: Array) -> bool:
	holders_lit = lit.duplicate()
	var before: Array = []
	for n in nodes:
		before.append(bool(n.lit))
	# The rooms with torches of their own, and the hearth room, first.
	var depends: Array = []
	for n in nodes:
		if bool(n.hearth):
			n.lit = true
		elif str(n.kind) == "room" and not (n.holders as Array).is_empty():
			var all := true
			for i in n.holders:
				if i >= lit.size() or not bool(lit[i]):
					all = false
			n.lit = all
		else:
			# Lit unless something dark touches it (the greatest fixpoint:
			# dark spreads in from the cold holders and the dark rooms).
			n.lit = true
			depends.append(n)
	var changed := true
	while changed:
		changed = false
		for n in depends:
			if not bool(n.lit):
				continue
			if not _ends_lit(n, lit):
				n.lit = false
				changed = true
	for i in nodes.size():
		if bool(nodes[i].lit) != bool(before[i]):
			return true
	return false


func _ends_lit(n: Dictionary, lit: Array) -> bool:
	if str(n.kind) == "room":
		# A room with no torch of its own: lit when everything through its
		# doors is.
		for l in n.links:
			if not bool(nodes[l.to].lit):
				return false
		return true
	for e in n.ends:
		match str(e.type):
			"sconce":
				var i := int(e.holder)
				if i >= lit.size() or not bool(lit[i]):
					return false
			"door":
				if not bool(nodes[int(e.node)].lit):
					return false
	return true


## How many nodes are its ground (dark) now.
func ground_count() -> int:
	var k := 0
	for n in nodes:
		if not bool(n.lit):
			k += 1
	return k


func is_ground(id: int) -> bool:
	return id >= 0 and id < nodes.size() and not bool(nodes[id].lit)


## The node `pos` (scene) stands in: the piece it is inside, else the
## nearest (a doorway is in neither), and in a corridor the stretch.
func node_at(pos: Vector3) -> int:
	var pid := TombKit.piece_at(lay, pos)
	if pid < 0:
		var best := INF
		for pc in lay.pieces:
			var r := Delves.rect_of(pc)
			var q := Vector2(pos.x, pos.z)
			var dx := maxf(maxf(r.position.x - q.x, q.x - r.end.x), 0.0)
			var dz := maxf(maxf(r.position.y - q.y, q.y - r.end.y), 0.0)
			var aa := Delves.along_across(pc, q)
			var dy := absf(pos.y - Delves.floor_of(pc, clampf(aa.x, 0.0, float(pc.len))))
			var dd := Vector2(dx, dz).length() + maxf(dy - 1.0, 0.0)
			if dd < best:
				best = dd
				pid = int(pc.id)
	if pid < 0:
		return -1
	var ids: Array = by_piece.get(pid, [])
	if ids.size() <= 1:
		return int(ids[0]) if not ids.is_empty() else -1
	var a := Delves.along_across(lay.pieces[pid], Vector2(pos.x, pos.z)).x
	for id in ids:
		if a <= float(nodes[id].a1):
			return int(id)
	return int(ids[-1])


## The cheapest way from node `from` to `to` ([node ids], from first), or
## [] if there is none, never through the hearth room. ground_only:
## through dark nodes only (`from` itself may be lit: the way out of a room
## just relit).
func path(from: int, to: int, ground_only := true) -> Array:
	var r := _dijkstra(from, ground_only, 0.0)
	if not (r.dist as Dictionary).has(to):
		return []
	return _walk_back(r.prev, from, to)


## Every node reachable from `from` through dark nodes, and how far:
## {node id: cost}.
func reach(from: int) -> Dictionary:
	return _dijkstra(from, true, 0.0).dist


## The nearest dark node to `from` by a way that crosses as little light
## as it can (the way out of a room just relit, rule.leaves_lit_room), never
## through the hearth room: [the path], or [] when there is none.
func nearest_dark(from: int) -> Array:
	var r := _dijkstra(from, false, 1000.0)
	var best := -1
	var best_d := INF
	for id in r.dist:
		if int(id) == from or bool(nodes[id].lit):
			continue
		if float(r.dist[id]) < best_d:
			best_d = float(r.dist[id])
			best = int(id)
	if best < 0:
		return []
	return _walk_back(r.prev, from, best)


## How many of the nodes on `p` are lit.
func lit_on(p: Array) -> int:
	var k := 0
	for id in p:
		if bool(nodes[id].lit):
			k += 1
	return k


## Dijkstra from `from`: {"dist", "prev"}. ground_only: lit nodes are not
## entered; else each lit node entered costs `lit_cost` more. The hearth
## room is never entered (the boss's way never goes through it, §EY.2).
func _dijkstra(from: int, ground_only: bool, lit_cost: float) -> Dictionary:
	var dist := {from: 0.0}
	var prev := {}
	var done := {}
	while true:
		var u := -1
		var ud := INF
		for id in dist:
			if not done.has(id) and float(dist[id]) < ud:
				ud = float(dist[id])
				u = int(id)
		if u < 0:
			break
		done[u] = true
		for l in nodes[u].links:
			var v := int(l.to)
			var lit_v := bool(nodes[v].lit)
			if (ground_only and lit_v) or bool(nodes[v].hearth):
				continue
			var nd := ud + float(l.cost) + (lit_cost if lit_v else 0.0)
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = u
	return {"dist": dist, "prev": prev}


func _walk_back(prev: Dictionary, from: int, to: int) -> Array:
	var out: Array = [to]
	var at := to
	while at != from:
		if not prev.has(at):
			return []
		at = int(prev[at])
		out.push_front(at)
	return out


## The link between nodes `a` and `b` ({} if they don't touch).
func link(a: int, b: int) -> Dictionary:
	for l in nodes[a].links:
		if int(l.to) == b:
			return l
	return {}


## Is node `id` a dead end (a room with one door)?
func dead_end(id: int) -> bool:
	var n: Dictionary = nodes[id]
	return str(n.kind) == "room" and int(n.doors) == 1 and not bool(n.hearth)


## The pieces of the main way through the tomb (the spine, design §EX.2:
## from the hearth room through the heart to the way out): lay.spine when
## the generator lays one, else the way from the hearth room to the heart
## and on to the exit if there is one. [piece ids].
static func main_path(p_lay: Dictionary) -> Array:
	# The spine as the generator lays it (piece ids, or {"id"}s, or pieces
	# marked spine / on_spine).
	var marked: Array = []
	var sp: Variant = p_lay.get("spine", null)
	if sp is Array:
		for v in sp:
			if v is int or v is float:
				marked.append(int(v))
			elif v is Dictionary and (v as Dictionary).has("id"):
				marked.append(int(v.id))
	for pc in p_lay.get("pieces", []):
		if (bool(pc.get("spine", false)) or bool(pc.get("on_spine", false))) and not int(pc.id) in marked:
			marked.append(int(pc.id))
	if not marked.is_empty():
		return marked
	var goal := int(p_lay.get("heart", -1))
	var ex: Variant = p_lay.get("exit", null)
	if ex is Dictionary and (ex as Dictionary).has("piece"):
		goal = int((ex as Dictionary).piece)
	if goal < 0:
		return [0]
	var prev := {0: -1}
	var queue: Array = [0]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if id == goal:
			break
		for di in p_lay.pieces[id].doors:
			var d: Dictionary = p_lay.doors[di]
			for o in [int(d.a), int(d.b)]:
				if not prev.has(o):
					prev[o] = id
					queue.append(o)
	var out: Array = []
	var at := goal
	while at >= 0 and prev.has(at):
		out.push_front(at)
		at = int(prev[at])
	return out


## The lair (design §EY.1: "a hole in a cave somewhere in the dungeon";
## bosses.json lair: kind hole, off_main_path): a side room off the main
## way (main_path), a dead end if there is one, and in it a spot of floor
## clear of its doors, its fires, its airways and the way between its
## doors, where the floor has broken through into the dark below.
## {"piece", "pos" (Vector3, the hole's middle on the floor), "r" (its
## radius, bosses.json lair.hole_r_m)}, or {} if no side room has room for
## it. Its own RNG, so the rest of the layout's dice are untouched.
static func place_lair(p_lay: Dictionary, r_m := -1.0) -> Dictionary:
	if r_m < 0.0:
		r_m = float((Tuning.table("bosses").get("lair", {}) as Dictionary).get("hole_r_m", 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(p_lay.seed), "lair"])
	var main := main_path(p_lay)
	var best := {}
	var best_score := -INF
	for pc in p_lay.pieces:
		if str(pc.kind) != "room" or str(pc.get("room_kind", "")) in ["hearth", "heart"] or int(pc.id) in main:
			continue
		var spot := _lair_spot(p_lay, pc, r_m)
		if spot.is_empty():
			continue
		# A dead end, deep, not a fallen room; the dice break ties.
		var score := float(spot.clear) + (3.0 if (pc.doors as Array).size() == 1 else 0.0) + float(pc.get("depth", 0)) * 0.5
		if str(pc.get("room_kind", "")) == "collapsed":
			score -= 2.0
		score += rng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = {"piece": int(pc.id), "pos": spot.pos, "r": r_m}
	return best


## The clearest spot for a hole `r` across in room `pc`: {"pos", "clear"
## (m to the nearest thing it must keep off)} or {}.
static func _lair_spot(p_lay: Dictionary, pc: Dictionary, r: float) -> Dictionary:
	var length := float(pc.len)
	var half := float(pc.half)
	var keep: Array = []
	for di in pc.doors:
		var d: Dictionary = p_lay.doors[di]
		keep.append([d.p as Vector2, 2.0])
	for h in p_lay.get("holders", []):
		if int(h.piece) == int(pc.id):
			keep.append([Vector2((h.pos as Vector3).x, (h.pos as Vector3).z), 1.3])
	for a in p_lay.get("airways", []):
		if int(a.piece) == int(pc.id):
			keep.append([Vector2((a.pos as Vector3).x, (a.pos as Vector3).z), 1.2])
	var lines: Array = []
	for i in (pc.doors as Array).size():
		for j in range(i + 1, (pc.doors as Array).size()):
			lines.append([p_lay.doors[pc.doors[i]].p, p_lay.doors[pc.doors[j]].p])
	var best := {}
	var best_c := -INF
	var m := r + 0.75
	for ka in 7:
		for kc in 5:
			var along := lerpf(m, length - m, ka / 6.0)
			var across := lerpf(-(half - m), half - m, kc / 4.0)
			if length - 2.0 * m < 0.0 or half - m < 0.0:
				continue
			var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + Delves.perp(pc.dir) * across
			var clear := INF
			var ok := true
			for k in keep:
				var dd := q.distance_to(k[0]) - r - float(k[1])
				clear = minf(clear, dd + float(k[1]))
				if dd < 0.0:
					ok = false
			for ln in lines:
				var dl := q.distance_to(Geometry2D.get_closest_point_to_segment(q, ln[0], ln[1])) - r
				if dl < 1.2:
					ok = false
				clear = minf(clear, dl)
			if not ok:
				continue
			# Toward the walls (a den is in a corner, not the room's middle).
			var c := clear + absf(across) * 0.2 + along / maxf(length, 1.0) * 0.3
			if c > best_c:
				best_c = c
				best = {"pos": Vector3(q.x, float(pc.y0), q.y), "clear": clear}
	return best

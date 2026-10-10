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
##
## Its own tunnels (Mike's note of 7 Oct: "depending on the ruins boss type
## as well, they may have their own tunnels- this can be the case for the
## snake"; bosses.json bosses.<key>.tunnels; place_tunnels): a few holes at
## the foot of the walls, one in its lair room, the rest in the side ways'
## rooms and corridors (none in the hearth room, none on the spine or the
## way out), joined under the floors by tunnels only it fits through. Built
## with_tunnels (the boss's graph; the skeletons' has none), each tunnel is
## a link between the nodes its holes open into, as long as the tunnel, so
## a way may go under the light. Every way here goes round the hearth room
## unless a caller allows it at hearth_cost (a creature cut off from every
## dark it could reach otherwise crosses it, Mike's note: nothing goes
## through the stone).

## In a crypt the lair is where a coffin stood (_coffin_spot): its rim this
## far (m) off the wall the coffin stood against.
const COFFIN_WALL_M := 0.75
## ...and its rim this far along the row from an open grave's middle (the
## grave itself, its lid shoved off onto the floor beside it, out to about
## 1.5 m, and room to spare).
const OPEN_GRAVE_M := 2.1

## [{"id", "kind" ("room" / "stretch"), "piece", "a0", "a1" (the stretch's
## span along its piece; a room 0..len), "holders" (a room's torches,
## indices into lay.holders), "ends" (a stretch's: [{"type": "sconce",
## "holder"} / {"type": "door", "node"} / {"type": "open"}]), "hearth",
## "lit", "center" (Vector3, on its floor), "doors" (how many doors it
## has: a room with one is a dead end), "links" ([{"to", "via" (Vector3),
## "cost", "door" (door id, -1 at a sconce or a tunnel)[, "tunnel"
## (lay.tunnels.links index), "from_hole", "to_hole" (lay.tunnels.holes
## indices, this end first)]}])}]
var nodes: Array = []
var lay: Dictionary = {}
## piece id -> [node ids], a corridor's stretches in order along it.
var by_piece: Dictionary = {}
## The holders' lit flags the graph was last worked out from.
var holders_lit: Array = []
## Built with the boss's own tunnels as links.
var with_tunnels := false
## Doors a gate shuts (design §FM.6: the fork's seals, Fork; door id ->
## true): no way through them while they stand (_dijkstra), whatever the
## light.
var shut := {}


static func build(p_lay: Dictionary, p_with_tunnels := false) -> BossGround:
	var g := BossGround.new()
	g.lay = p_lay
	g.with_tunnels = p_with_tunnels
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
	# sconces. The boss's graph (with_tunnels) holds only its own floor
	# (TombFloors.BOSS_FLOOR, design §FM.6: it stays on floor one as built),
	# so its ground is floor one's dark and the last light there sends it
	# home; the skeletons' holds every floor.
	for pc in lay.pieces:
		if with_tunnels and int(pc.get("floor", 0)) != TombFloors.BOSS_FLOOR:
			continue
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
	# The boss's own tunnels (place_tunnels): each a link between the nodes
	# its two holes open into, costing its length and the walk to each hole.
	if with_tunnels:
		var tun: Dictionary = lay.get("tunnels", {})
		var holes: Array = tun.get("holes", [])
		var tl: Array = tun.get("links", [])
		for ti in tl.size():
			var t: Dictionary = tl[ti]
			var ha: Dictionary = holes[int(t.a)]
			var hb: Dictionary = holes[int(t.b)]
			var na := node_at(ha.out)
			var nb := node_at(hb.out)
			if na < 0 or nb < 0 or na == nb:
				continue
			var a: Dictionary = nodes[na]
			var b: Dictionary = nodes[nb]
			var cost := (a.center as Vector3).distance_to(ha.out) + float(t.len) + (hb.out as Vector3).distance_to(b.center)
			(a.links as Array).append({"to": nb, "via": ha.out, "cost": cost, "door": -1, "tunnel": ti, "from_hole": int(t.a), "to_hole": int(t.b)})
			(b.links as Array).append({"to": na, "via": hb.out, "cost": cost, "door": -1, "tunnel": ti, "from_hole": int(t.b), "to_hole": int(t.a)})


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
## [] if there is none, never through the hearth room unless `hearth_cost`
## is given (0 or more: entering it costs that much more). ground_only:
## through dark nodes only (`from` itself may be lit: the way out of a room
## just relit); else each lit node entered costs `lit_cost` more.
func path(from: int, to: int, ground_only := true, lit_cost := 0.0, hearth_cost := -1.0) -> Array:
	var r := _dijkstra(from, ground_only, lit_cost, hearth_cost)
	if not (r.dist as Dictionary).has(to):
		return []
	return _walk_back(r.prev, from, to)


## Every node reachable from `from` through dark nodes, and how far:
## {node id: cost}.
func reach(from: int) -> Dictionary:
	return _dijkstra(from, true, 0.0).dist


## How dear a lit node is to a way that would rather keep to the dark
## (nearest_dark), and the hearth room to one that has no other way.
const LIT_COST := 1000.0
const HEARTH_COST := 20000.0


## The nearest dark node to `from` by a way that crosses as little light
## as it can (the way out of a room just relit, rule.leaves_lit_room; the
## boss's tunnels under it, where it has them), never through the hearth
## room unless `hearth_cost` (0 or more) lets it, as a last resort: [the
## path], or [] when there is none.
func nearest_dark(from: int, hearth_cost := -1.0) -> Array:
	var r := _dijkstra(from, false, LIT_COST, hearth_cost)
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


## Does the way through nodes `p` cross the hearth room?
func crosses_hearth(p: Array) -> bool:
	for id in p:
		if bool(nodes[int(id)].hearth):
			return true
	return false


## The cheapest link from node `a` to node `b` ({} if they don't touch):
## the one a way between them takes (a door, a sconce, or a tunnel).
func best_link(a: int, b: int) -> Dictionary:
	var best := {}
	for l in nodes[a].links:
		if int(l.to) == b and (best.is_empty() or float(l.cost) < float(best.cost)):
			best = l
	return best


## How many of the nodes on `p` are lit.
func lit_on(p: Array) -> int:
	var k := 0
	for id in p:
		if bool(nodes[id].lit):
			k += 1
	return k


## Dijkstra from `from`: {"dist", "prev"}. ground_only: lit nodes are not
## entered; else each lit node entered costs `lit_cost` more. The hearth
## room is never entered (the boss's way never goes through it, §EY.2)
## unless `hearth_cost` is 0 or more: then it costs that much more (a
## creature cut off from every other way to the dark, Mike's 7 Oct note).
func _dijkstra(from: int, ground_only: bool, lit_cost: float, hearth_cost := -1.0) -> Dictionary:
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
			if not shut.is_empty() and shut.has(int(l.get("door", -1))):
				continue
			var lit_v := bool(nodes[v].lit)
			if ground_only and lit_v:
				continue
			var extra := 0.0
			if bool(nodes[v].hearth):
				if hearth_cost < 0.0:
					continue
				extra = hearth_cost
			var nd := ud + float(l.cost) + (lit_cost if lit_v else 0.0) + extra
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
## clear of its doors, its fires, its airways, the way between its doors
## what stands on its floor and the pillars it will stand on (§EX.3),
## where the floor has broken through into the dark below; in a crypt,
## where one of its coffins stood (_lair_spot).
## {"piece", "pos" (Vector3, the hole's middle on the floor), "r" (its
## radius, bosses.json lair.hole_r_m)[, "coffin" (the crypt's coffin spot
## it took, TombKit.coffin_spots' "i")]}, or {} if no side room has room
## for it. Its own RNG, so the rest of the layout's dice are untouched.
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
		# Never in a big room (design §FM.6's room pool: hand-built, what
		# stands in it its archetype's).
		if pc.has("big_room"):
			continue
		# On the boss's own floor (TombFloors.BOSS_FLOOR: floor one, §FM.10
		# call 4 not answered).
		if int(pc.get("floor", 0)) != TombFloors.BOSS_FLOOR:
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
			if spot.has("coffin"):
				best["coffin"] = int(spot.coffin)
	return best


## How far a hole's edge keeps from a pillar's middle (m): the broken
## flags round its rim, the pillar's base, and a passage between them.
const PILLAR_KEEP_M := 1.35


## The clearest spot for a hole `r` across in room `pc`: {"pos", "clear"
## (m to the nearest thing it must keep off)[, "coffin" (the coffin spot it
## took)]} or {}. In a crypt it is where one of its coffins stood
## (_coffin_spot); elsewhere the clearest floor toward a wall, off the
## room's doors, fires, airways, the line between its doors and its
## dressing (_dressing).
static func _lair_spot(p_lay: Dictionary, pc: Dictionary, r: float) -> Dictionary:
	var length := float(pc.len)
	var half := float(pc.half)
	# [point, metres the rim keeps off it, and where a coffin stood]: a
	# door as far either way; a fire or an airway half as far there (the
	# coffin stood that near them).
	var keep: Array = []
	for di in pc.doors:
		var d: Dictionary = p_lay.doors[di]
		keep.append([d.p as Vector2, 2.0, 2.0])
	for h in p_lay.get("holders", []):
		if int(h.piece) == int(pc.id):
			keep.append([Vector2((h.pos as Vector3).x, (h.pos as Vector3).z), 1.3, 0.65])
	for a in p_lay.get("airways", []):
		if int(a.piece) == int(pc.id):
			keep.append([Vector2((a.pos as Vector3).x, (a.pos as Vector3).z), 1.2, 0.6])
	# Off the pillars the room will stand on (design §EX.3; TombBuild
	# .pillars_for): its broken edge never under one, and room to pass
	# between them, where a coffin stood too.
	for q: Vector2 in TombBuild.pillars_for(p_lay, pc):
		keep.append([q, PILLAR_KEEP_M, PILLAR_KEEP_M])
	var lines: Array = []
	for i in (pc.doors as Array).size():
		for j in range(i + 1, (pc.doors as Array).size()):
			lines.append([p_lay.doors[pc.doors[i]].p, p_lay.doors[pc.doors[j]].p])
	if str(pc.get("room_kind", "")) == "crypt":
		var coffins := TombKit.coffin_spots(p_lay, pc)
		if not coffins.is_empty():
			return _coffin_spot(p_lay, pc, coffins, keep, lines, r)
	keep.append_array(_dressing(p_lay, pc))
	var best := {}
	var best_c := -INF
	var m := r + 0.75
	# A catacomb's long walls are niches and shelves, standing up to 0.64 m
	# out of them: further off those.
	var ms := m + (0.6 if str(pc.get("room_kind", "")) == "catacomb" else 0.0)
	for ka in 7:
		for kc in 5:
			var along := lerpf(m, length - m, ka / 6.0)
			var across := lerpf(-(half - ms), half - ms, kc / 4.0)
			if length - 2.0 * m < 0.0 or half - ms < 0.0:
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


## A crypt's floor is rows of coffins down both long walls, with no floor
## between them wide enough for the hole: so the hole is where one of them
## stood, fallen through with the floor (TombBuild leaves that coffin out,
## and no skeleton rests in it: TombKit.lair_took). Its middle a little in
## from the coffin's, so its rim keeps COFFIN_WALL_M off the wall; the
## coffin whose place is clearest of the doors, the line between them, the
## fires and the airways (keep's third margin), toward the room's far end.
## Never a grave a resident sleeps in (TombKit lays them first), nor beside
## one: TombBuild shoves an open grave's lid off onto the floor along its
## row, toward the room's middle or away from a sconce, so either
## neighbour may have it (OPEN_GRAVE_M).
static func _coffin_spot(p_lay: Dictionary, pc: Dictionary, coffins: Array, keep: Array, lines: Array, r: float) -> Dictionary:
	var length := float(pc.len)
	var half := float(pc.half)
	var open: Array = []
	for rp in p_lay.get("residents", []):
		if int(rp.piece) != int(pc.id) or str(rp.rests_in) != "grave" or int(rp.spot) < 0 or int(rp.spot) >= coffins.size():
			continue
		open.append(coffins[int(rp.spot)])
	var best := {}
	var best_c := -INF
	for s in coffins:
		var by_open := false
		for g in open:
			if float(g.sd) == float(s.sd) and absf(float(s.along) - float(g.along)) < r + OPEN_GRAVE_M:
				by_open = true
		if by_open:
			continue
		var along := float(s.along)
		var across := float(s.sd) * (half - r - COFFIN_WALL_M)
		var q: Vector2 = (pc.c as Vector2) + (pc.dir as Vector2) * along + Delves.perp(pc.dir) * across
		var clear := INF
		var ok := true
		for k in keep:
			var dd := q.distance_to(k[0]) - r
			clear = minf(clear, dd)
			if dd < float(k[2]):
				ok = false
		for ln in lines:
			var dl := q.distance_to(Geometry2D.get_closest_point_to_segment(q, ln[0], ln[1])) - r
			clear = minf(clear, dl)
			if dl < 1.2:
				ok = false
		if not ok:
			continue
		var c := clear + along / maxf(length, 1.0) * 0.3
		if c > best_c:
			best_c = c
			best = {"pos": Vector3(q.x, float(pc.y0), q.y), "clear": clear, "coffin": int(s.i)}
	return best


## What a room's dressing may stand on its floor, as TombBuild lays it, as
## [point, metres the hole's rim keeps off it]: an ossuary's piles of bones
## in its corners; a fallen room's slab and rubble where TombBuild lays
## them (clear of its doors' ways, its pillars and its sconces' bays). (A
## catacomb's niches line its long walls: _lair_spot keeps further off
## those.)
static func _dressing(_p_lay: Dictionary, pc: Dictionary) -> Array:
	var out: Array = []
	var length := float(pc.len)
	var half := float(pc.half)
	match str(pc.get("room_kind", "")):
		"ossuary":
			for k in 4:
				var ca := 0.9 if k < 2 else length - 0.9
				var cs := (half - 0.9) * (1.0 if k % 2 == 0 else -1.0)
				var q := point(pc, ca, cs)
				out.append([Vector2(q.x, q.z), 0.8])
		"collapsed":
			# Where TombBuild lays its fallen slab and rubble (TombBuild
			# .collapse_for), as far as they reach.
			var col := TombBuild.collapse_for(_p_lay, pc)
			var q := point(pc, (col[0] as Vector2).x, (col[0] as Vector2).y)
			out.append([Vector2(q.x, q.z), maxf(float(col[1]), float(col[2]) * 0.5) + 0.5])
	return out


# --- Its own tunnels (Mike's note of 7 Oct) ----------------------------------------

## The boss the tomb stands in for (bosses.json bosses, the one marked
## first)'s tunnels block: {} for a boss with none.
static func tunnels_def() -> Dictionary:
	var bs: Dictionary = Tuning.table("bosses").get("bosses", {})
	for k in bs:
		if bool((bs[k] as Dictionary).get("first", false)):
			var t: Variant = (bs[k] as Dictionary).get("tunnels", {})
			return t if t is Dictionary else {}
	return {}


## The boss's own tunnels (bosses.json bosses.<key>.tunnels; Mike's note of
## 7 Oct: "they may have their own tunnels- this can be the case for the
## snake"): {"holes": [hole...], "links": [{"a", "b" (hole indices), "pts"
## (PackedVector3Array: a's floor before it, a's mouth, in to its back,
## down under every floor on the way, across, up behind b and out of b's
## mouth to its floor), "len" (m along them)}]}, or {} for a boss with none.
## A hole is {"piece", "side", "off" (along that wall from its middle,
## TombKit.face_point), "pos" (Vector3: its foot's middle on the wall's
## face, on the floor), "n" (Vector3: out of the wall into the piece), "u"
## (Vector3: along the wall), "out" (the floor before it, out_m out), "w",
## "h", "depth", "lair" (the one in its lair room)}. holes [least, most] of
## them (its own dice): the first in the lair room, then one in each other
## side way, then any side room or corridor, apart_m apart; each at the
## foot of a wall clear of its doors and their frames, its corners, its
## torches, its airways, a catacomb's niches and a crypt's coffins (never
## on their long walls), an ossuary's bone piles, a fallen room's slab, the
## pillars and the lair's hole (_hole_spot); none in the hearth room, on
## the spine or the way out (main_path), nor on a stair. The holes are
## joined in a tree, each to its nearest, and each to the lair room's.
static func place_tunnels(p_lay: Dictionary) -> Dictionary:
	var td := tunnels_def()
	if td.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(p_lay.seed), "tunnels"])
	var span: Array = td.get("holes", [3, 5])
	var want := rng.randi_range(int(span[0]), int(span[1]))
	var apart := float(td.get("apart_m", 6.0))
	var main := main_path(p_lay)
	var lair: Dictionary = p_lay.get("lair", {})
	var spots := {}
	for pc in p_lay.pieces:
		if not str(pc.kind) in ["room", "corridor"] or int(pc.get("floor", 0)) != TombFloors.BOSS_FLOOR:
			continue
		if str(pc.get("room_kind", "")) in ["hearth", "heart"] or int(pc.id) in main or bool(pc.get("spine", false)):
			continue
		# Not in a big room's walls (design §FM.6's room pool, hand-built).
		if pc.has("big_room"):
			continue
		var s := _hole_spot(p_lay, pc, td, lair)
		if not s.is_empty():
			spots[int(pc.id)] = s
	var holes: Array = []
	# The lair room's first.
	if not lair.is_empty() and spots.has(int(lair.piece)):
		var s0: Dictionary = spots[int(lair.piece)]
		s0["lair"] = true
		holes.append(s0)
	# One in each side way that has none yet: its best piece.
	var branches: Array = p_lay.get("branches", [])
	for bi in range(1, branches.size()):
		var br: Array = branches[bi]
		var has := false
		for h in holes:
			if int(h.piece) in br:
				has = true
		if has:
			continue
		var best := {}
		var best_s := -INF
		for pid in br:
			if not spots.has(int(pid)):
				continue
			var s: Dictionary = spots[int(pid)]
			var sc := _hole_score(p_lay, s)
			if sc > best_s and _apart(holes, s, apart):
				best_s = sc
				best = s
		if not best.is_empty():
			holes.append(best)
	# Then any other side piece, the best first (its own dice break ties).
	var rest: Array = []
	for pid in spots:
		var s: Dictionary = spots[pid]
		var used := false
		for h in holes:
			if int(h.piece) == int(pid):
				used = true
		if not used:
			rest.append([_hole_score(p_lay, s) + rng.randf() * 2.0, s])
	rest.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for e in rest:
		if holes.size() >= want:
			break
		if _apart(holes, e[1], apart):
			holes.append(e[1])
	for h in holes:
		if not h.has("lair"):
			h["lair"] = false
	# The tunnels: a tree joining each hole to its nearest (Prim), and each to
	# the lair room's.
	var pairs := {}
	if holes.size() >= 2:
		var inside: Array = [0]
		while inside.size() < holes.size():
			var bi2 := -1
			var bj := -1
			var bd := INF
			for i in inside:
				for j in holes.size():
					if j in inside:
						continue
					var d := _flat_d(holes[i].pos, holes[j].pos)
					if d < bd:
						bd = d
						bi2 = i
						bj = j
			inside.append(bj)
			pairs[Vector2i(mini(bi2, bj), maxi(bi2, bj))] = true
		if bool(holes[0].lair):
			for j in range(1, holes.size()):
				pairs[Vector2i(0, j)] = true
	var links: Array = []
	for pr: Vector2i in pairs:
		var pts := tunnel_pts(p_lay, holes[pr.x], holes[pr.y], td)
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k - 1].distance_to(pts[k])
		links.append({"a": pr.x, "b": pr.y, "pts": pts, "len": length})
	return {"holes": holes, "links": links}


static func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _apart(holes: Array, s: Dictionary, apart: float) -> bool:
	for h in holes:
		if _flat_d(h.pos, s.pos) < apart:
			return false
	return true


## How good a hole spot is: off by itself, in a room (a dead end best),
## deep.
static func _hole_score(p_lay: Dictionary, s: Dictionary) -> float:
	var pc: Dictionary = p_lay.pieces[int(s.piece)]
	var sc := minf(float(s.clear), 2.0) + float(pc.get("depth", 0)) * 0.3
	if str(pc.kind) == "room":
		sc += 1.0
		if (pc.doors as Array).size() == 1:
			sc += 2.0
	return sc


## The tunnel from hole `ha` to hole `hb` (place_tunnels' "pts"): a's floor
## before it, its mouth, in to its back, straight down under every floor
## the way crosses (under_m beneath the lowest), across, up behind b, its
## mouth, its floor. Always longer than the straight line between them.
static func tunnel_pts(p_lay: Dictionary, ha: Dictionary, hb: Dictionary, td: Dictionary) -> PackedVector3Array:
	var depth_in := maxf(float(td.get("depth_m", 0.45)) - 0.05, 0.1)
	var under := float(td.get("under_m", 1.2))
	var back_a: Vector3 = (ha.pos as Vector3) - (ha.n as Vector3) * depth_in
	var back_b: Vector3 = (hb.pos as Vector3) - (hb.n as Vector3) * depth_in
	var y := minf((ha.pos as Vector3).y, (hb.pos as Vector3).y)
	var a2 := Vector2(back_a.x, back_a.z)
	var b2 := Vector2(back_b.x, back_b.z)
	var steps := maxi(int(ceil(a2.distance_to(b2) / 0.5)), 1)
	for k in steps + 1:
		var q := a2.lerp(b2, float(k) / steps)
		for pc in p_lay.pieces:
			if int(pc.get("floor", 0)) == TombFloors.BOSS_FLOOR and Delves.rect_of(pc, Delves.WALL + 0.3).has_point(q):
				# (Under a sunken court's court too: RoomPool.lowest.)
				y = minf(y, RoomPool.lowest(pc))
	y -= under
	return PackedVector3Array([ha.out, ha.pos, back_a, Vector3(back_a.x, y, back_a.z), Vector3(back_b.x, y, back_b.z), back_b, hb.pos, hb.out])


## Which of a tunnel's points are inside the rock (tunnel_pts: its back,
## the two drops and the run between): the snake there is hidden.
const TUNNEL_HIDDEN := [false, false, true, true, true, true, false, false]


## The best spot for one of the boss's holes in piece `pc` (place_tunnels'
## hole), or {}: on any of a room's walls (a crypt's or catacomb's end
## walls only: coffins and niches line its long walls), on a corridor's
## side walls, a quarter metre at a time, the one clearest of everything.
static func _hole_spot(p_lay: Dictionary, pc: Dictionary, td: Dictionary, lair: Dictionary) -> Dictionary:
	var w := float(td.get("w_m", 0.6))
	var corner := float(td.get("corner_clear_m", 0.9))
	var room := str(pc.kind) == "room"
	var kind := str(pc.get("room_kind", ""))
	var sides: Array = ["left", "right"]
	if room:
		sides = ["start", "end"] if kind in ["crypt", "catacomb"] else ["start", "end", "left", "right"]
	if kind == "ossuary":
		# Its bone piles stand 0.9 m in from each corner.
		corner += 1.0
	var best := {}
	var best_c := -INF
	# What stands on the room's floor, worked out once (_hole_clear).
	var floor_things := {"pillars": TombBuild.pillars_for(p_lay, pc), "coffins": TombKit.coffin_spots(p_lay, pc) if kind == "crypt" else [],
		"collapse": TombBuild.collapse_for(p_lay, pc) if kind == "collapsed" else []}
	for side in sides:
		var length := TombKit.wall_len(pc, side)
		var lo := -length * 0.5 + (corner if room else 1.0) + w * 0.5
		var hi := length * 0.5 - (corner if room else 1.0) - w * 0.5
		var off := lo
		while off <= hi + 1e-4:
			var clear := _hole_clear(p_lay, pc, side, off, w, td, lair, floor_things)
			if clear >= 0.0:
				# The clearest spot: the middle of the widest free stretch.
				var c := clear
				if c > best_c:
					best_c = c
					var fp := TombKit.face_point(pc, side, off)
					var n2: Vector2 = fp[1]
					var at: Vector2 = fp[0]
					var aa := Delves.along_across(pc, at)
					var fy := Delves.floor_of(pc, clampf(aa.x, 0.0, float(pc.len)))
					var n := Vector3(n2.x, 0.0, n2.y)
					var pos := Vector3(at.x, fy, at.y)
					var out := pos + n * float(td.get("out_m", 0.7))
					best = {"piece": int(pc.id), "side": side, "off": off, "pos": pos, "n": n, "u": Vector3.UP.cross(n).normalized(),
						"out": out, "w": w, "h": float(td.get("h_m", 0.45)), "depth": float(td.get("depth_m", 0.45)), "clear": clear}
			off += 0.25
	return best


## How clear a hole `w` wide `off` along wall `side` of `pc` is (m to the
## nearest thing it keeps off, past its margin), or -1 where it may not go.
## `things`: what stands on the floor ({"pillars", "coffins", "collapse"},
## _hole_spot's).
static func _hole_clear(p_lay: Dictionary, pc: Dictionary, side: String, off: float, w: float, td: Dictionary, lair: Dictionary, things: Dictionary) -> float:
	var clear := 3.0
	var jamb := RuinStyle.num("doors.jamb_w_m", 0.32, str(p_lay.get("theme", "")))
	var dc := float(td.get("door_clear_m", 0.8))
	for di in pc.doors:
		var d: Dictionary = p_lay.doors[di]
		var ds := TombKit.door_side(pc, d)
		if str(ds[0]) != side:
			continue
		var gap := absf(off - float(ds[1])) - (float(d.half) + jamb + dc + w * 0.5)
		if gap < 0.0:
			return -1.0
		clear = minf(clear, gap)
	# The wall's torches (their niches and flue slots) and airways.
	for h in p_lay.get("holders", []):
		if int(h.piece) != int(pc.id):
			continue
		var hs := _wall_of(pc, Vector2((h.pos as Vector3).x, (h.pos as Vector3).z))
		if str(hs[0]) != side:
			continue
		var gap := absf(off - float(hs[1])) - (0.2 + 0.6 + w * 0.5)
		if gap < 0.0:
			return -1.0
		clear = minf(clear, gap)
	for a in p_lay.get("airways", []):
		if int(a.piece) != int(pc.id):
			continue
		var as2 := _wall_of(pc, Vector2((a.pos as Vector3).x, (a.pos as Vector3).z))
		if str(as2[0]) != side:
			continue
		var gap := absf(off - float(as2[1])) - (float(TombKit.AIRWAY_HALF[0 if bool(a.strong) else 1]) + 0.3 + w * 0.5)
		if gap < 0.0:
			return -1.0
		clear = minf(clear, gap)
	# The floor before it: off the pillars, the lair's hole, a crypt's
	# coffins, a fallen room's slab.
	var fp := TombKit.face_point(pc, side, off)
	var out2: Vector2 = (fp[0] as Vector2) + (fp[1] as Vector2) * float(td.get("out_m", 0.7))
	for q: Vector2 in things.get("pillars", []):
		var gap := out2.distance_to(q) - 1.2
		if gap < 0.0:
			return -1.0
		clear = minf(clear, gap)
	if not lair.is_empty() and int(lair.piece) == int(pc.id):
		var lc := Vector2((lair.pos as Vector3).x, (lair.pos as Vector3).z)
		var gap := minf(out2.distance_to(lc), (fp[0] as Vector2).distance_to(lc)) - (float(lair.r) + 1.0)
		if gap < 0.0:
			return -1.0
		clear = minf(clear, gap)
	match str(pc.get("room_kind", "")):
		"crypt":
			var oa := Delves.along_across(pc, out2)
			for s in things.get("coffins", []):
				var sd := float(s.sd)
				var r := Rect2(float(s.along) - TombKit.COFFIN_SIZE.x * 0.5, minf(sd * float(pc.half), sd * (float(pc.half) - TombKit.COFFIN_IN * 2.0 + 0.15)), TombKit.COFFIN_SIZE.x, TombKit.COFFIN_IN * 2.0 - 0.15)
				var gap := (oa - oa.clamp(r.position, r.end)).length() - 0.7
				if gap < 0.0:
					return -1.0
				clear = minf(clear, gap)
		"collapsed":
			var col: Array = things.get("collapse", [])
			if col.size() >= 3:
				var q := point(pc, (col[0] as Vector2).x, (col[0] as Vector2).y)
				var gap := out2.distance_to(Vector2(q.x, q.z)) - (maxf(float(col[1]), float(col[2]) * 0.5) + 1.2)
				if gap < 0.0:
					return -1.0
				clear = minf(clear, gap)
	return clear


## Which wall of piece `pc` the point `p` (x/z, on a wall's face) is on, and
## how far along it from its middle (TombKit.face_point's offset): [side,
## off], or ["", 0] if it is on none.
static func _wall_of(pc: Dictionary, p: Vector2) -> Array:
	var aa := Delves.along_across(pc, p)
	var half := float(pc.half)
	var length := float(pc.len)
	if absf(aa.y) >= half - 0.08:
		return ["left" if aa.y > 0.0 else "right", aa.x - length * 0.5]
	if aa.x <= 0.08:
		return ["start", aa.y]
	if aa.x >= length - 0.08:
		return ["end", aa.y]
	return ["", 0.0]

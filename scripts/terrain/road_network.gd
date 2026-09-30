class_name RoadNetwork
## Roads (design 30 Sept §BC, data/roads.json): a trail network laid
## before plants, built by whoever left the ruins and maintained by
## nobody. Nodes are the ruins, the mythic folk's camps, the hot springs
## and standing stones; links join each node to its nearest neighbours
## (a relative-neighbourhood graph within link_max_km, none closer than
## min_spacing_km); each link is routed over a lattice of the terrain
## (A*, 200 m steps) that costs grade above max_grade (the road
## switchbacks), water crossings (a ford or a bridge), lakes and the
## sea (never), and rewards a river bank and level ground, so roads
## follow rivers and contours. Rivers are the other road type.
##
## Decay (per link, by its own hash): a bridge out (both abutments stand),
## a trail that ends at a collapse, waymarks every waymark_every_m (a
## share fallen), and an off-road find set out of sight of the trail.
## Forks: where two links leave a node along the same ground, the second
## starts where they part, so the fork is where you see them part.
##
## Built by region (REGION_M cells) on demand, from any thread
## (TerrainChunk's colours and VegetationPlacer ask while chunks are
## computed): a region gathers its nodes with a margin, keeps the links
## whose first node is its own, and routes them once. Queries: the links
## near a place, the nearest road, the tread at a point.

## Regions and their margin, cut down on a small planet (the dev stamp,
## 40 km around) where a 16 km cube would be a quarter of the sphere.
static var REGION_M := minf(16000.0, PlanetConst.CIRCUMFERENCE_M / 8.0)
static var MARGIN_M := minf(9000.0, PlanetConst.CIRCUMFERENCE_M / 12.0)
## The routing lattice's step: fine enough that a 1/10-height planet's
## ravines show between samples (the grade limit is judged on it).
const STEP_M := 120.0
const HASH_M := 2000.0

static var instance: RoadNetwork = null
static var D := Tuning.table("roads")
## ROAD_DEBUG=1: a line per region built (nodes, links, seconds).
static var DEBUG := OS.get_environment("ROAD_DEBUG") == "1"

var map: PlanetData
var rivers: RiverNetwork
var _regions := {}
var _mutex := Mutex.new()
## Links: {"id", "a": node, "b": node, "pts": PackedVector3Array (dirs),
## "len_m", "width_m", "collapsed": bool, "crossings": [[pt, kind, out]],
## "waymarks": [[pt, kind, fallen]], "landmark": {} or {"dir", "kind"},
## "bends": PackedVector3Array}
var links: Array = []
var nodes: Array = [] # {"dir", "kind", "key"}
var _node_keys := {}
var _hash := {} # Vector3i -> PackedInt32Array of link ids


func _init(p_map: PlanetData, p_rivers: RiverNetwork) -> void:
	map = p_map
	rivers = p_rivers
	instance = self


# --- Regions ---------------------------------------------------------------------

static func _region_of(d: Vector3) -> Vector3i:
	var p := d * PlanetConst.RADIUS_M / REGION_M
	return Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))


## Make sure every region within `radius` m of `d` is built.
func ensure(d: Vector3, radius: float) -> void:
	var want := {}
	var r := int(ceil((radius + 1.0) / REGION_M))
	var c := _region_of(d)
	var p := d * PlanetConst.RADIUS_M
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var k := c + Vector3i(x, y, z)
				var lo := Vector3(k) * REGION_M
				# The cube's distance to the point, and to the shell.
				var q := Vector3(clampf(p.x, lo.x, lo.x + REGION_M), clampf(p.y, lo.y, lo.y + REGION_M), clampf(p.z, lo.z, lo.z + REGION_M))
				if q.distance_to(p) > radius:
					continue
				var centre := lo + Vector3.ONE * REGION_M * 0.5
				if centre.length() > PlanetConst.RADIUS_M + REGION_M or centre.length() < PlanetConst.RADIUS_M - REGION_M:
					continue
				want[k] = true
	for k in want:
		_mutex.lock()
		var done := _regions.has(k)
		if not done:
			_regions[k] = false
		_mutex.unlock()
		if not done:
			_build_region(k)


func _build_region(k: Vector3i) -> void:
	var t0 := Time.get_ticks_msec()
	var centre := (Vector3(k) * REGION_M + Vector3.ONE * REGION_M * 0.5).normalized()
	var reach := REGION_M * 0.87 + MARGIN_M
	var own: Array = []
	var all: Array = []
	var found := _find_nodes(centre, reach)
	if DEBUG:
		print("[roads] region %s: %d nodes found in %.1f s" % [k, found.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for n in found:
		var nk = n.key
		_mutex.lock()
		if not _node_keys.has(nk):
			_node_keys[nk] = nodes.size()
			nodes.append(n)
		var ni: int = _node_keys[nk]
		_mutex.unlock()
		all.append(ni)
		if _region_of(n.dir) == k:
			own.append(ni)
	if own.is_empty():
		return
	# Links: each node's nearest neighbours, relative-neighbourhood pruned.
	var max_m := float((D.get("network", {}) as Dictionary).get("link_max_km", 15.0)) * 1000.0
	var pairs := {}
	for i in own:
		var di: Vector3 = nodes[i].dir
		var cand: Array = []
		for j in all:
			if j == i:
				continue
			var dm := CubeSphere.surface_distance_m(di, nodes[j].dir)
			if dm <= max_m:
				cand.append([dm, j])
		cand.sort_custom(func(x, y): return x[0] < y[0])
		var kept := 0
		for c in cand:
			if kept >= 3:
				break
			var j: int = c[1]
			var dm: float = c[0]
			var redundant := false
			for o in all:
				if o == i or o == j:
					continue
				if CubeSphere.surface_distance_m(di, nodes[o].dir) < dm and CubeSphere.surface_distance_m(nodes[j].dir, nodes[o].dir) < dm:
					redundant = true
					break
			if redundant:
				continue
			var key := Vector2i(mini(i, j), maxi(i, j))
			if not pairs.has(key):
				pairs[key] = true
				kept += 1
	var new_links: Array = []
	for key in pairs:
		var t1 := Time.get_ticks_msec()
		var link := _route(key.x, key.y, centre, reach)
		if not link.is_empty():
			new_links.append(link)
		if DEBUG:
			print("[roads]   link %d-%d: %s, %.1f s" % [key.x, key.y, "%.0f m" % link.len_m if not link.is_empty() else "no way", (Time.get_ticks_msec() - t1) / 1000.0])
	_mutex.lock()
	for link in new_links:
		link.id = links.size()
		links.append(link)
		_index(link)
	_mutex.unlock()
	_legible_forks(new_links)
	if DEBUG:
		print("[roads] region %s: %d own nodes, %d pairs, %d links, %.1f s" % [k, own.size(), pairs.size(), new_links.size(), (Time.get_ticks_msec() - t0) / 1000.0])


## The nodes within `reach` m of `centre`: ruins, the mythic camps, hot
## springs (the biome), standing stones (their own hash).
func _find_nodes(centre: Vector3, reach: float) -> Array:
	var out: Array = []
	var min_m := float((D.get("network", {}) as Dictionary).get("min_spacing_km", 3.0)) * 1000.0
	var kinds: Array = (D.get("network", {}) as Dictionary).get("nodes", ["ruin", "camp", "hot_spring", "standing_stone"])
	if kinds.has("ruin"):
		for c in CreatureSpawner._cells_around(centre, reach, Ruins.CELL_M):
			var site := Ruins.find(map, c)
			if not site.is_empty():
				out.append({"dir": site.dir, "kind": "ruin", "key": "ruin:%s" % str(c)})
	if kinds.has("camp"):
		for c in CreatureSpawner._cells_around(centre, reach, Territories.CELL_M):
			var t := Territories.find(map, c)
			if not t.is_empty():
				out.append({"dir": t.dir, "kind": "camp", "key": "camp:%s" % str(c)})
	if kinds.has("hot_spring") and not map.biome.is_empty():
		for c in CreatureSpawner._cells_around(centre, reach, map.cell_m()):
			var p := CreatureSpawner._cell_point(c, map.res, 31)
			var cell := map.cell_at(p)
			if map.biome[cell] == BiomeTemplates.HOT_SPRING and map.water[cell] == PlanetData.Water.NONE:
				out.append({"dir": map.dir[cell], "kind": "hot_spring", "key": "hot:%d" % cell})
	if kinds.has("standing_stone"):
		for c in CreatureSpawner._cells_around(centre, reach, 9000.0):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([c, "standing_stone"])
			if rng.randf() < 0.35:
				var p := CreatureSpawner._cell_point(c, CreatureSpawner._cells_per_face(9000.0), 313)
				if map.water[map.cell_at(p)] == PlanetData.Water.NONE and map.terrain.elevation(p, false) > 2.0:
					out.append({"dir": p, "kind": "standing_stone", "key": "stone:%s" % str(c)})
	# Spacing: ruins first, then the rest; anything within min_spacing of
	# a kept node is dropped.
	out.sort_custom(func(x, y): return (x.kind == "ruin") and not (y.kind == "ruin"))
	var kept: Array = []
	for n in out:
		var near := false
		for m in kept:
			if CubeSphere.surface_distance_m(n.dir, m.dir) < min_m:
				near = true
				break
		if not near:
			kept.append(n)
	return kept


# --- Routing ----------------------------------------------------------------------

class _Lattice:
	var centre: Vector3
	var east: Vector3
	var north: Vector3
	var n: int
	var half: int
	## Sampled as A* reaches them (index -> [elev, water kind, river
	## width, bank]); water: 0 land, 1 lake or sea, 2 river.
	var cells := {}
	var map: PlanetData
	var rivers: RiverNetwork

	func dir_of(i: int, j: int) -> Vector3:
		return (centre + (east * (i - half) + north * (j - half)) * RoadNetwork.STEP_M / PlanetConst.RADIUS_M).normalized()

	## The lattice cell under `d`: the gnomonic inverse of dir_of (exact
	## on a small planet too).
	func index_of(d: Vector3) -> Vector2i:
		var k := d.dot(centre)
		if k <= 0.05:
			return Vector2i(-1, -1)
		var rel := (d / k - centre) * PlanetConst.RADIUS_M
		return Vector2i(roundi(rel.dot(east) / RoadNetwork.STEP_M) + half, roundi(rel.dot(north) / RoadNetwork.STEP_M) + half)

	func cell(idx: int) -> Array:
		if cells.has(idx):
			return cells[idx]
		var d := dir_of(idx % n, idx / n)
		var e := map.terrain.elevation(d, false)
		var c := map.cell_at(d)
		var w := map.water[c]
		var kind := 0
		if w == PlanetData.Water.OCEAN or e < PlanetConst.SEA_LEVEL_M + 0.5:
			kind = 1
		elif w == PlanetData.Water.LAKE and e < map.water_level[c] + 0.5:
			kind = 1
		var rw := 0.0
		var bank := 0
		if rivers != null:
			var best := INF
			for s in rivers.segments_near(map, c):
				var dt := rivers.closest_dt(s, d)
				if dt.x < best:
					best = dt.x
					rw = rivers.width[s]
			if best < rw * 0.5 + 2.0:
				kind = 2
			elif best < rw * 0.5 + 80.0:
				bank = 1
		var out := [e, kind, rw, bank]
		cells[idx] = out
		return out


var _lattices := {}


func _lattice(centre: Vector3, reach: float) -> _Lattice:
	var key := _region_of(centre)
	_mutex.lock()
	if _lattices.has(key):
		var l: _Lattice = _lattices[key]
		_mutex.unlock()
		return l
	_mutex.unlock()
	var lat := _Lattice.new()
	lat.centre = centre
	lat.east = CubeSphere.east(centre)
	lat.north = CubeSphere.north(centre)
	lat.half = int(ceil(reach / STEP_M))
	lat.n = lat.half * 2 + 1
	lat.map = map
	lat.rivers = rivers
	_mutex.lock()
	_lattices[key] = lat
	_mutex.unlock()
	return lat


## A* over the lattice between two nodes; the link dict, or {} when no
## way (an island, the sea between).
func _route(ia: int, ib: int, centre: Vector3, reach: float) -> Dictionary:
	var lat := _lattice(centre, reach)
	var start := lat.index_of(nodes[ia].dir)
	var goal := lat.index_of(nodes[ib].dir)
	var n := lat.n
	if start.x < 0 or start.y < 0 or start.x >= n or start.y >= n or goal.x < 0 or goal.y < 0 or goal.x >= n or goal.y >= n:
		return {}
	var net: Dictionary = D.get("network", {})
	var max_grade := float(net.get("max_grade", 0.18))
	var follow_rivers := bool(net.get("follow_rivers", true))
	var s_idx := start.y * n + start.x
	var g_idx := goal.y * n + goal.x
	var came := {}
	var g := {s_idx: 0.0}
	var heap: Array = [[0.0, s_idx]]
	var closed := {}
	var steps := 0
	var found := false
	var cur_cell := lat.cell(s_idx)
	while not heap.is_empty() and steps < 60000:
		steps += 1
		var cur: Array = _heap_pop(heap)
		var ci: int = cur[1]
		if closed.has(ci):
			continue
		closed[ci] = true
		if ci == g_idx:
			found = true
			break
		cur_cell = lat.cell(ci)
		var cx := ci % n
		var cy := ci / n
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if nx < 0 or ny < 0 or nx >= n or ny >= n:
					continue
				var ni := ny * n + nx
				if closed.has(ni):
					continue
				var nc := lat.cell(ni)
				var wk: int = nc[1]
				if wk == 1:
					continue
				var dist := STEP_M * (1.4142 if dx != 0 and dy != 0 else 1.0)
				var grade := absf(float(nc[0]) - float(cur_cell[0])) / dist
				# A cliff is no road at all; above max_grade the road
				# switchbacks (the cost climbs steeply with the excess).
				if grade > 0.5:
					continue
				var cost := dist
				if grade > max_grade:
					cost *= 1.0 + 8.0 * (grade - max_grade) / max_grade
				if wk == 2:
					cost *= 3.0 + float(nc[2]) / 6.0
				elif follow_rivers and int(nc[3]) == 1:
					cost *= 0.8
				var ng: float = g[ci] + cost
				if not g.has(ni) or ng < g[ni]:
					g[ni] = ng
					came[ni] = ci
					var h := Vector2(nx - goal.x, ny - goal.y).length() * STEP_M
					_heap_push(heap, [ng + h, ni])
	if not found:
		return {}
	var cells: Array = []
	var at := g_idx
	while at != s_idx:
		cells.append(at)
		at = came[at]
	cells.append(s_idx)
	cells.reverse()
	var pts := PackedVector3Array()
	for c in cells:
		pts.append(lat.dir_of(c % n, c / n))
	# The ends on the nodes themselves, then smoothed (Chaikin twice).
	pts[0] = nodes[ia].dir
	pts[pts.size() - 1] = nodes[ib].dir
	for pass_i in 2:
		pts = _chaikin(pts)
	var link := {"a": ia, "b": ib, "pts": pts, "id": -1}
	_decay(link, lat)
	return link


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var t = heap[parent]
		heap[parent] = heap[i]
		heap[i] = t
		i = parent


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and heap[l][0] < heap[m][0]:
			m = l
		if r < n and heap[r][0] < heap[m][0]:
			m = r
		if m == i:
			break
		var t = heap[m]
		heap[m] = heap[i]
		heap[i] = t
		i = m
	return top


static func _chaikin(pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector3Array()
	out.append(pts[0])
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		out.append((p * 0.75 + q * 0.25).normalized())
		out.append((p * 0.25 + q * 0.75).normalized())
	out.append(pts[pts.size() - 1])
	return out


## Length (m) along the polyline, and the point at `m` metres along it.
static func length_m(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += CubeSphere.surface_distance_m(pts[i], pts[i + 1])
	return total


static func point_at(pts: PackedVector3Array, m: float) -> Vector3:
	var left := m
	for i in pts.size() - 1:
		var seg := CubeSphere.surface_distance_m(pts[i], pts[i + 1])
		if left <= seg or i == pts.size() - 2:
			return pts[i].slerp(pts[i + 1], clampf(left / maxf(seg, 0.01), 0.0, 1.0))
		left -= seg
	return pts[pts.size() - 1]


## What the years did to the link (roads.json decay, landmarks): bridges
## and fords at the crossings, a collapsed end, waymarks, an off-road find.
func _decay(link: Dictionary, lat: _Lattice) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([nodes[link.a].key, nodes[link.b].key, "road"])
	var trail: Dictionary = D.get("trail", {})
	var decay: Dictionary = D.get("decay", {})
	var wb = trail.get("width_m", [1.2, 2.6])
	link.width_m = rng.randf_range(float(wb[0]), float(wb[1]))
	var pts: PackedVector3Array = link.pts
	var total := length_m(pts)
	link.len_m = total
	# A trail that ends at a collapse: cut short, rubble at the end.
	link.collapsed = rng.randf() < float(decay.get("collapse_end_share", 0.15))
	if link.collapsed:
		var keep := rng.randf_range(0.6, 0.85)
		var cut := PackedVector3Array()
		var acc := 0.0
		for i in pts.size() - 1:
			cut.append(pts[i])
			acc += CubeSphere.surface_distance_m(pts[i], pts[i + 1])
			if acc >= total * keep:
				break
		cut.append(point_at(pts, total * keep))
		link.pts = cut
		pts = cut
		total = length_m(pts)
		link.len_m = total
	# Crossings: where the road runs into a river: a ford on a narrow
	# stream, a bridge on a wide one (out with bridge_out_share, both
	# abutments always standing).
	var crossings: Array = []
	var in_water := false
	for i in pts.size():
		var idx := lat.index_of(pts[i])
		var wet := false
		var rw := 0.0
		if idx.x >= 0 and idx.y >= 0 and idx.x < lat.n and idx.y < lat.n:
			var lc := lat.cell(idx.y * lat.n + idx.x)
			wet = int(lc[1]) == 2
			rw = float(lc[2])
		if wet and not in_water:
			var kind := "bridge" if rw >= 9.0 else "ford"
			var out := kind == "bridge" and rng.randf() < float(decay.get("bridge_out_share", 0.5))
			crossings.append([pts[i], kind, out, rw])
		in_water = wet
	link.crossings = crossings
	# Waymarks along it, a share fallen.
	var marks: Array = []
	var every = decay.get("waymark_every_m", [150, 400])
	var kinds: Array = decay.get("waymarks", ["cairn", "standing_stone", "post"])
	var m := rng.randf_range(float(every[0]), float(every[1])) * 0.5
	while m < total - 20.0:
		marks.append([point_at(pts, m), str(kinds[rng.randi() % kinds.size()]), rng.randf() < float(decay.get("waymark_fallen_share", 0.4))])
		m += rng.randf_range(float(every[0]), float(every[1]))
	link.waymarks = marks
	# Bends: where the road turns more than 25 degrees (a tree stands at
	# each, VegetationPlacer).
	var bends := PackedVector3Array()
	for i in range(1, pts.size() - 1):
		var a := (pts[i] - pts[i - 1]).normalized()
		var b := (pts[i + 1] - pts[i]).normalized()
		if a.dot(b) < cos(deg_to_rad(25.0)):
			bends.append(pts[i])
	link.bends = bends
	# The off-road find: 40-120 m off the trail, out of sight of it.
	link.landmark = {}
	var lm: Dictionary = D.get("landmarks", {})
	if rng.randf() < 0.5 and total > 300.0:
		var kinds_lm: Array = lm.get("kinds", ["standing_stone", "old_tree", "spring"])
		var kind := str(kinds_lm[rng.randi() % kinds_lm.size()])
		if kind == "ruin" or kind == "hot_spring":
			kind = "standing_stone"
		var off_b = lm.get("off_road_m", [40, 120])
		var best := Vector3.ZERO
		var best_hidden := false
		for attempt in 5:
			var at := point_at(pts, total * rng.randf_range(0.25, 0.75))
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var fwd := (point_at(pts, minf(total, total * 0.5 + 30.0)) - point_at(pts, total * 0.5)).normalized()
			var right := fwd.cross(at).normalized()
			var off := rng.randf_range(float(off_b[0]), float(off_b[1]))
			var p := (at + right * side * off / PlanetConst.RADIUS_M).normalized()
			if map.water[map.cell_at(p)] != PlanetData.Water.NONE:
				continue
			var hidden := not bool(lm.get("out_of_sight", true)) or _hidden_from(at, p)
			if best == Vector3.ZERO or (hidden and not best_hidden):
				best = p
				best_hidden = hidden
			if hidden:
				break
		if best != Vector3.ZERO:
			link.landmark = {"dir": best, "kind": kind, "hidden": best_hidden}


## Is `p` out of sight of the trail at `at` (an eye at 1.6 m): the ground
## between rises over the line, or it is 60 m or more into a forest.
func _hidden_from(at: Vector3, p: Vector3) -> bool:
	var e0 := map.terrain.elevation(at, false) + 1.6
	var e1 := map.terrain.elevation(p, false) + 1.0
	for k in range(1, 6):
		var t := k / 6.0
		var q := at.slerp(p, t)
		if map.terrain.elevation(q, false) > lerpf(e0, e1, t) + 0.3:
			return true
	var biome: int = map.biome[map.cell_at(p)]
	return VegetationPlacer.FORESTS.has(biome) and CubeSphere.surface_distance_m(at, p) >= 60.0


## Forks legible before you commit (§BC): two links leaving one node
## along the same ground start apart only where they part; the second
## begins there, so the fork is where you see the roads separate.
func _legible_forks(new_links: Array) -> void:
	var legible := float((D.get("forks", {}) as Dictionary).get("legible_before_commit_m", 60.0))
	for i in new_links.size():
		for j in range(i + 1, new_links.size()):
			var l1: Dictionary = new_links[i]
			var l2: Dictionary = new_links[j]
			var shared := -1
			var pts1: PackedVector3Array = l1.pts
			var pts2: PackedVector3Array = l2.pts
			if l1.a == l2.a:
				shared = l1.a
			elif l1.a == l2.b:
				shared = l1.a
				pts2 = pts2.duplicate()
				pts2.reverse()
			elif l1.b == l2.a:
				shared = l1.b
				pts1 = pts1.duplicate()
				pts1.reverse()
			elif l1.b == l2.b:
				shared = l1.b
				pts1 = pts1.duplicate()
				pts1.reverse()
				pts2 = pts2.duplicate()
				pts2.reverse()
			if shared < 0:
				continue
			# Walk out from the node while the two stay within a road's
			# width of each other; the second link restarts where they part.
			var part := 0
			for k in range(1, mini(pts1.size(), pts2.size())):
				if CubeSphere.surface_distance_m(pts1[k], pts2[k]) > 12.0:
					break
				part = k
			if part >= 2 and CubeSphere.surface_distance_m(pts2[0], pts2[part]) > legible * 0.5:
				var cut := pts2.slice(part)
				if l2.a == shared:
					l2.pts = cut
				else:
					cut.reverse()
					l2.pts = cut
				l2.len_m = length_m(l2.pts)
				l2.forked = true


func _index(link: Dictionary) -> void:
	for p in link.pts:
		var k := _hash_key(p)
		if not _hash.has(k):
			_hash[k] = PackedInt32Array()
		var arr: PackedInt32Array = _hash[k]
		if arr.is_empty() or arr[arr.size() - 1] != int(link.id):
			arr.append(int(link.id))
			_hash[k] = arr


static func _hash_key(d: Vector3) -> Vector3i:
	var p := d * PlanetConst.RADIUS_M / HASH_M
	return Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))


# --- Queries -------------------------------------------------------------------------

## The links with any point within about `radius` m of `d` (built first
## if the region isn't yet).
func links_near(d: Vector3, radius: float) -> Array:
	ensure(d, radius)
	var out: Array = []
	var seen := {}
	var r := int(ceil(radius / HASH_M)) + 1
	var c := _hash_key(d)
	_mutex.lock()
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var k := c + Vector3i(x, y, z)
				if not _hash.has(k):
					continue
				for id in _hash[k]:
					if not seen.has(id):
						seen[id] = true
						out.append(links[id])
	_mutex.unlock()
	return out


## The nearest road to `d` among `near` (links_near): {"dist_m", "link",
## "seg": index of the polyline segment, "t", "pt"} or {} past `radius`.
static func nearest_in(near: Array, d: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_m := radius
	for link in near:
		var pts: PackedVector3Array = link.pts
		for i in pts.size() - 1:
			var pa := pts[i]
			var ab := pts[i + 1] - pa
			var t := clampf((d - pa).dot(ab) / maxf(ab.length_squared(), 1e-14), 0.0, 1.0)
			var p := (pa + ab * t).normalized()
			var dm := CubeSphere.surface_distance_m(p, d)
			if dm < best_m:
				best_m = dm
				best = {"dist_m": dm, "link": link, "seg": i, "t": t, "pt": p}
	return best


## The polyline segments of `near` (links_near) within `radius` m of
## `centre`: [pa, pb, link], for the per-vertex and per-site tests.
static func segments_in(near: Array, centre: Vector3, radius: float) -> Array:
	var out: Array = []
	var limit := cos(minf(radius / PlanetConst.RADIUS_M, PI))
	for link in near:
		var pts: PackedVector3Array = link.pts
		for i in pts.size() - 1:
			var mid := (pts[i] + pts[i + 1]).normalized()
			if mid.dot(centre) >= limit:
				out.append([pts[i], pts[i + 1], link])
	return out


## The nearest of `segs` to `d`: {"dist_m", "link", "pt", "along"} or
## {} past `radius`.
static func nearest_seg(segs: Array, d: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_m := radius
	for s in segs:
		var pa: Vector3 = s[0]
		var ab: Vector3 = (s[1] as Vector3) - pa
		var t := clampf((d - pa).dot(ab) / maxf(ab.length_squared(), 1e-14), 0.0, 1.0)
		var p := (pa + ab * t).normalized()
		var dm := CubeSphere.surface_distance_m(p, d)
		if dm < best_m:
			best_m = dm
			best = {"dist_m": dm, "link": s[2], "pt": p, "along": ab.normalized()}
	return best


## The tread at `d` (0 bare ground to 1 full path colour) from the
## segments near: the road's width, worn by trail.wear and taken back by
## trail.overgrown, feathered over the terrain's vertex spacing.
static func tread_at(segs: Array, d: Vector3) -> float:
	if segs.is_empty():
		return 0.0
	var r := nearest_seg(segs, d, 8.0)
	if r.is_empty():
		return 0.0
	var trail: Dictionary = D.get("trail", {})
	var w := float((r.link as Dictionary).get("width_m", 2.0))
	var k := 1.0 - smoothstep(w * 0.5, w * 0.5 + 4.0, float(r.dist_m))
	return k * float(trail.get("wear", 0.6)) * (1.0 - 0.6 * float(trail.get("overgrown", 0.55)))


# --- Rooms (design 30 Sept §BB, data/rooms.json) ------------------------------------

static var ROOMS := Tuning.table("rooms")
var _rooms_cache := {}

## The rooms hanging off the roads near `d`: [{"dir", "r", "open":
## PackedVector3Array of open headings (unit tangents: a reveal side, no
## wall there), "kind"}]. Rooms sit at the nodes, at fords and bridges,
## and at every other bend, sized from room.size_m.
func rooms_near(d: Vector3, radius: float) -> Array:
	var out: Array = []
	var room: Dictionary = ROOMS.get("room", {})
	var sb = room.get("size_m", [30, 120])
	var at: Array = room.get("at", ["ford", "ruin", "road_bend"])
	for link in links_near(d, radius + float(sb[1])):
		var key: int = link.id
		_mutex.lock()
		var have := _rooms_cache.has(key)
		_mutex.unlock()
		if not have:
			var rooms: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([nodes[link.a].key, nodes[link.b].key, "rooms"])
			var pts: PackedVector3Array = link.pts
			for end in [link.a, link.b]:
				var n: Dictionary = nodes[end]
				if at.has(str(n.kind)) or (n.kind == "camp" and at.has("ruin")) or at.has("clearing"):
					rooms.append(_room(n.dir, rng.randf_range(float(sb[0]), float(sb[1])) * 0.5, str(n.kind)))
			for c in link.get("crossings", []):
				if at.has("ford"):
					rooms.append(_room(c[0], rng.randf_range(float(sb[0]), float(sb[0]) * 1.6) * 0.5, "ford"))
			if at.has("road_bend"):
				var bends: PackedVector3Array = link.get("bends", PackedVector3Array())
				for i in bends.size():
					if rng.randf() < 0.4:
						rooms.append(_room(bends[i], rng.randf_range(float(sb[0]), float(sb[1]) * 0.7) * 0.5, "road_bend"))
			_mutex.lock()
			_rooms_cache[key] = rooms
			_mutex.unlock()
		_mutex.lock()
		var rooms_of: Array = _rooms_cache[key]
		_mutex.unlock()
		for r in rooms_of:
			if CubeSphere.surface_distance_m(r.dir, d) < radius + float(r.r):
				out.append(r)
	return out


## A room at `dir` of radius `r`: its open headings are where the ground
## drops away or water lies just past its edge (the reveal after the
## corridor: no wall on that side).
func _room(dir: Vector3, r: float, kind: String) -> Dictionary:
	var open := PackedVector3Array()
	var e0 := map.terrain.elevation(dir, false)
	for k in 8:
		var a := k * TAU / 8.0
		var p := CreatureSpawner._offset(dir, a, r + 40.0)
		var e := map.terrain.elevation(p, false)
		var cell := map.cell_at(p)
		if e < e0 - 12.0 or map.water[cell] != PlanetData.Water.NONE or e < PlanetConst.SEA_LEVEL_M + 0.5:
			open.append((p - dir).normalized())
	return {"dir": dir, "r": r, "open": open, "kind": kind}


## The understory's density scale at `d` (rooms.json walls): a room's
## floor is thinned, its edge band thickened (but not toward an open
## side), a corridor's sides thickened just past the cleared strip.
static func wall_scale(rooms: Array, road_gap: float, road_clear: float, d: Vector3) -> float:
	var walls: Dictionary = ROOMS.get("walls", {})
	var band := float(walls.get("edge_band_m", 6.0))
	var scale := 1.0
	var on_floor := false
	for room in rooms:
		var dm := CubeSphere.surface_distance_m(room.dir, d)
		var rr := float(room.r)
		if dm < rr - band:
			scale *= float(walls.get("floor_density_scale", 0.3))
			on_floor = true
		elif dm < rr + band * 0.5:
			var toward := (d - (room.dir as Vector3)).normalized()
			var open_side := false
			for o in room.open:
				if toward.dot(o) > cos(deg_to_rad(50.0)):
					open_side = true
					break
			if not open_side:
				scale *= float(walls.get("edge_density_scale", 2.5))
	if not on_floor and road_gap < INF and road_gap > road_clear and road_gap < road_clear + band:
		scale *= float(walls.get("corridor_side_scale", 2.0))
	return scale

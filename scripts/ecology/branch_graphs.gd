class_name BranchGraphs
## The branch graphs of the trees in NEAR range (spec Phase 1 (i)), for
## climbing and monkeys. The tree code (the owner) adds a tree's graph when
## the tree comes into NEAR range and removes it when the tree leaves or
## its chunk goes; everything else only reads. See BranchGraph.

static var _graphs := {} # key -> BranchGraph


static func add(g: BranchGraph) -> void:
	_graphs[g.key] = g


static func remove(key: int) -> void:
	_graphs.erase(key)


static func clear() -> void:
	_graphs.clear()


static func count() -> int:
	return _graphs.size()


## The graph of the tree with this key, or null.
static func find(key: int) -> BranchGraph:
	return _graphs.get(key)


static func all() -> Array:
	return _graphs.values()


## Graphs that may have a handhold within `radius_m` of `scene_pos`.
static func near(scene_pos: Vector3, radius_m: float) -> Array[BranchGraph]:
	var out: Array[BranchGraph] = []
	for g in _graphs.values():
		var bg := g as BranchGraph
		if not bg.valid():
			continue
		var b := bg.bounds()
		if (b[0] as Vector3).distance_to(scene_pos) <= radius_m + float(b[1]):
			out.append(bg)
	return out


## Every handhold within `radius_m` of `scene_pos`, on wood at least
## `min_radius` thick, nearest first, as [graph, index, distance] entries.
static func handholds_within(scene_pos: Vector3, radius_m: float, min_radius := 0.0) -> Array:
	var out := []
	for g in near(scene_pos, radius_m):
		for i in g.size():
			if g.radius[i] < min_radius:
				continue
			var d := g.pos(i).distance_to(scene_pos)
			if d <= radius_m:
				out.append([g, i, d])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	return out


## The nearest handhold within `max_m` of `scene_pos`, on wood at least
## `min_radius` thick, as [graph, index, distance], or [] if there is none.
static func nearest(scene_pos: Vector3, max_m: float, min_radius := 0.0) -> Array:
	var best := []
	for g in near(scene_pos, max_m):
		var i := g.nearest(scene_pos, min_radius)
		if i < 0:
			continue
		var d := g.pos(i).distance_to(scene_pos)
		if d <= max_m and (best.is_empty() or d < float(best[2])):
			best = [g, i, d]
	return best

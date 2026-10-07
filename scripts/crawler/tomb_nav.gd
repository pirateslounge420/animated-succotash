class_name TombNav
extends RefCounted
## The tomb's floor as a grid for what walks it (design §FE: a skeleton
## climbs out and comes after you, then walks back to its rest;
## Residents). CELL m squares over the tomb's x/z (its pieces never overlap
## there, TombKit, so one grid holds every level), each with its floor's
## height. A square is open where a body `radius` m round fits: on the
## floor of a piece's lane or in a door's gap through a wall, clear of
## anything standing on the floor (coffins, holders, rubble, the lowest
## shelves, the pillars: found by casting down onto it once, when the tomb
## is built).
## Paths by A* (AStarGrid2D), pulled straight wherever the straight line
## stays on open squares.
##
## The light (Mike's note of 7 Oct; LightField, attached once the tomb's
## fires are in): every square then carries the firelight on it, and the
## grid is walked two ways (path's `mode`):
##   DIM  the dimmest way: each square costs 1 + light_field.dim_weight
##        times its light over the chase's cap (at most dim_max times), so
##        a way across lit ground keeps to the edges of the light and the
##        dark corners; a line is pulled straight only where it is no
##        brighter than the way it replaces;
##   CAP  the chase's grid (residents.json rules.chase_light_cap): the same
##        weights, and no square brighter than the cap at all, so a way to
##        you in the light ends at the edge of it nearest you.
## Without a light field (the checks' own walks) every square costs the
## same.

const CELL := 0.25
## The ways to walk the grid (path's mode): the dimmest way, and the
## chase's (never past the light's cap).
const DIM := 0
const CAP := 1
## How far over the floor a cast may stop and still count as the floor
## (m): what your capsule rides over (its round foot climbs about this
## much under the 45° it can walk); a stair's collision is its ramp. The
## hearth's ring of stones (0.15-0.18 m) stands in the way.
const STEP_M := 0.09
## Casts start this high over the floor (over the bone shelves).
const PROBE_M := 1.75

var radius := 0.3
var lay: Dictionary
## The grid's corner (x/z) and its size in squares.
var origin := Vector2.ZERO
var size := Vector2i.ZERO
var astar := AStarGrid2D.new()
## Per square: the floor's height (NAN off it), the piece it lies in (-1
## a door's gap, -2 none), open (1) or not.
var floor_y := PackedFloat32Array()
var piece_of := PackedInt32Array()
var open := PackedByteArray()
## Squares open (tools).
var open_count := 0
## Open squares closed because no door reaches them (_close_islands; tools).
var closed_islands := 0
## The light on the floor (LightField; null until attached), and the
## chase's grid: open squares no brighter than its cap.
var light: LightField
var astar_cap: AStarGrid2D


## The grid for `p_lay`, cast against `space` (the tomb's stone), for a
## body `p_radius` m round; `exclude` the casts pass through (the player).
static func build(p_lay: Dictionary, space: PhysicsDirectSpaceState3D, p_radius: float, exclude: Array[RID] = []) -> TombNav:
	var nav := TombNav.new()
	nav.lay = p_lay
	nav.radius = p_radius
	nav._build(space, exclude)
	return nav


func _index(c: Vector2i) -> int:
	return c.y * size.x + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))


## A square's middle on its floor.
func point_of(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (c.x + 0.5) * CELL, floor_y[_index(c)], origin.y + (c.y + 0.5) * CELL)


func is_open(c: Vector2i) -> bool:
	return inside(c) and open[_index(c)] == 1


## The floor's height under `p` (its piece's slope, so a stair is smooth),
## or NAN off the floor.
func floor_at(p: Vector3) -> float:
	var c := cell_of(p)
	if not inside(c):
		return NAN
	var i := _index(c)
	var pid := piece_of[i]
	if pid >= 0:
		var pc: Dictionary = lay.pieces[pid]
		return Delves.floor_of(pc, Delves.along_across(pc, Vector2(p.x, p.z)).x)
	return floor_y[i]


func _build(space: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> void:
	var bounds := Rect2()
	var first := true
	for pc in lay.pieces:
		var r := Delves.rect_of(pc, Delves.WALL + 0.5)
		bounds = r if first else bounds.merge(r)
		first = false
	origin = bounds.position
	size = Vector2i(ceili(bounds.size.x / CELL) + 1, ceili(bounds.size.y / CELL) + 1)
	var n := size.x * size.y
	floor_y.resize(n)
	floor_y.fill(NAN)
	piece_of.resize(n)
	piece_of.fill(-2)
	open.resize(n)
	open.fill(0)
	# The floor: every piece's lane, then every door's gap.
	for pc in lay.pieces:
		_fill(Delves.rect_of(pc, 0.0), func(p: Vector2) -> Array:
			var aa := Delves.along_across(pc, p)
			if aa.x < 0.0 or aa.x > float(pc.len) or absf(aa.y) > float(pc.half):
				return []
			return [Delves.floor_of(pc, aa.x), int(pc.id)])
	for d in lay.doors:
		var p0: Vector2 = d.p
		var nv: Vector2 = d.n
		var across := Vector2(absf(nv.y), absf(nv.x))
		var ext := Vector2(absf(nv.x), absf(nv.y)) * (Delves.WALL * 0.5 + 0.1) + across * float(d.half)
		var y := float(d.y)
		_fill(Rect2(p0 - ext, ext * 2.0), func(_p: Vector2) -> Array: return [y, -1])
	# What stands on it: cast down onto every square of floor.
	var blocked := PackedByteArray()
	blocked.resize(n)
	blocked.fill(1)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = exclude
	# A cast that starts inside something standing there (a pillar, §EX.3,
	# taller than PROBE_M) finds it where it starts.
	q.hit_from_inside = true
	for cy in size.y:
		for cx in size.x:
			var i := cy * size.x + cx
			var fy := floor_y[i]
			if is_nan(fy):
				continue
			var x := origin.x + (cx + 0.5) * CELL
			var z := origin.y + (cy + 0.5) * CELL
			q.from = Vector3(x, fy + PROBE_M, z)
			q.to = Vector3(x, fy - 0.4, z)
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and (hit.position as Vector3).y <= fy + STEP_M:
				blocked[i] = 0
	# Open where every square within radius (and half a square more, for
	# where between squares the edge may lie) is clear floor.
	var reach := radius + CELL * 0.5
	var rc := ceili(reach / CELL)
	var disc: Array[Vector2i] = []
	for oy in range(-rc, rc + 1):
		for ox in range(-rc, rc + 1):
			if Vector2(ox, oy).length() * CELL <= reach:
				disc.append(Vector2i(ox, oy))
	for cy in size.y:
		for cx in size.x:
			var i := cy * size.x + cx
			if blocked[i] == 1:
				continue
			var ok := true
			for o in disc:
				var x2 := cx + o.x
				var y2 := cy + o.y
				if x2 < 0 or y2 < 0 or x2 >= size.x or y2 >= size.y or blocked[y2 * size.x + x2] == 1:
					ok = false
					break
			if ok:
				open[i] = 1
				open_count += 1
	_close_islands()
	_grid(astar)


## Set `g` up over the grid: its open squares walkable, the rest solid.
func _grid(g: AStarGrid2D) -> void:
	g.region = Rect2i(Vector2i.ZERO, size)
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	g.fill_solid_region(g.region, true)
	for cy in size.y:
		for cx in size.x:
			if open[cy * size.x + cx] == 1:
				g.set_point_solid(Vector2i(cx, cy), false)


# --- The light (LightField) ----------------------------------------------------

## The light on the floor from now on (LightField.build): the chase's grid
## made, every square's weight its light's.
func attach_light(lf: LightField) -> void:
	light = lf
	astar_cap = AStarGrid2D.new()
	_grid(astar_cap)


## Squares `cells` (indices) have new light (LightField.refresh): their
## weights in both grids, and in the chase's grid whether they are past the
## cap.
func light_changed(cells: Array, lf: LightField) -> void:
	var w := LightField.num("dim_weight", 2.0)
	var most := LightField.num("dim_max", 30.0)
	var cap := maxf(lf.cap, 1e-4)
	for i in cells:
		var idx := int(i)
		if open[idx] != 1:
			continue
		var c := Vector2i(idx % size.x, idx / size.x)
		var lv := lf.level[idx]
		var ws := 1.0 + w * minf(lv / cap, most)
		astar.set_point_weight_scale(c, ws)
		if astar_cap != null:
			astar_cap.set_point_weight_scale(c, ws)
			astar_cap.set_point_solid(c, lv > lf.cap)


## The light on square `c` (0 without a light field).
func light_of(c: Vector2i) -> float:
	if light == null or not inside(c):
		return 0.0
	return light.level[_index(c)]


## Close every open square no door's gap reaches over open squares: a patch
## of floor walled in by what stands there (coffins and a pillar, §EX.3),
## which nothing could walk into or out of, so nothing comes up or hangs
## back there (Residents.pocket_spot). Squares joined only corner to corner
## don't join (A* goes diagonally only past two open sides).
func _close_islands() -> void:
	var seen := PackedByteArray()
	seen.resize(open.size())
	var stack: Array[int] = []
	for i in open.size():
		if open[i] == 1 and piece_of[i] == -1:
			seen[i] = 1
			stack.append(i)
	if stack.is_empty():
		# No door's gap open at this size (a test floor): nothing to tell by.
		return
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var cx := i % size.x
		var cy := i / size.x
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x2 := cx + o.x
			var y2 := cy + o.y
			if x2 < 0 or y2 < 0 or x2 >= size.x or y2 >= size.y:
				continue
			var j := y2 * size.x + x2
			if open[j] == 1 and seen[j] == 0:
				seen[j] = 1
				stack.append(j)
	for i in open.size():
		if open[i] == 1 and seen[i] == 0:
			open[i] = 0
			open_count -= 1
			closed_islands += 1


## Every square whose middle is in `r` (x/z) takes `what(middle)`: [floor
## height, piece] or [] to leave it.
func _fill(r: Rect2, what: Callable) -> void:
	var c0 := Vector2i(floori((r.position.x - origin.x) / CELL), floori((r.position.y - origin.y) / CELL))
	var c1 := Vector2i(floori((r.end.x - origin.x) / CELL), floori((r.end.y - origin.y) / CELL))
	for cy in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
			var mid := Vector2(origin.x + (cx + 0.5) * CELL, origin.y + (cy + 0.5) * CELL)
			if not r.has_point(mid):
				continue
			var got: Array = what.call(mid)
			if got.is_empty():
				continue
			var i := cy * size.x + cx
			floor_y[i] = float(got[0])
			piece_of[i] = int(got[1])


## The open square nearest `c` within `within` squares, or (-1, -1).
func nearest_open(c: Vector2i, within := 8) -> Vector2i:
	if is_open(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(1, within + 1):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var q := c + Vector2i(ox, oy)
				if is_open(q):
					var d := Vector2(ox, oy).length()
					if d < best_d:
						best_d = d
						best = q
		if best.x >= 0:
			return best
	return best


## Do the squares on the straight line from `a` to `b` all stay open
## (and, going diagonally, the squares beside each step), none of them
## brighter than `most` (the light field's level)?
func line_open(a: Vector2i, b: Vector2i, most := INF) -> bool:
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y))
	if steps == 0:
		return is_open(a)
	var prev := a
	for s in steps + 1:
		var t := float(s) / steps
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if not is_open(c) or (most < INF and light_of(c) > most):
			return false
		if c.x != prev.x and c.y != prev.y:
			for side: Vector2i in [Vector2i(c.x, prev.y), Vector2i(prev.x, c.y)]:
				if not is_open(side) or (most < INF and light_of(side) > most):
					return false
		prev = c
	return true


## A walkable way from `from` to `to` (scene): points on the floor, the
## first where `from`'s nearest open square is, the last `to`'s (or, if
## `to` can't be reached, the nearest square to it that can: `partial`);
## pulled straight where the line stays open (and, with a light field, no
## brighter than the way it replaces). Empty when there is no way. `mode`:
## DIM, the dimmest way (with a light field; else every square alike), or
## CAP, the chase's, never onto a square brighter than the light's cap: a
## way to `to` past the cap ends at the edge of the light nearest it (the
## search may start from a square past the cap, the creature's own, so it
## can step out of it).
func path(from: Vector3, to: Vector3, partial := true, mode := DIM) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_open(cell_of(from))
	var b := nearest_open(cell_of(to))
	if a.x < 0 or b.x < 0:
		return out
	var capped := mode == CAP and light != null and astar_cap != null
	var g := astar_cap if capped else astar
	# AStarGrid2D finds no way to a solid square, not even part of one: the
	# two ends are opened for the search, and a way that ends past the cap
	# is cut back to the edge.
	var opened: Array[Vector2i] = []
	if capped:
		for c: Vector2i in [a, b]:
			if g.is_point_solid(c):
				g.set_point_solid(c, false)
				opened.append(c)
	var ids := g.get_id_path(a, b, partial)
	for c in opened:
		g.set_point_solid(c, true)
	if capped:
		while ids.size() > 1 and light_of(ids[-1]) > light.cap:
			ids.remove_at(ids.size() - 1)
	if ids.is_empty():
		return out
	var lit := light != null
	var i := 0
	out.append(point_of(ids[0]))
	while i < ids.size() - 1:
		var j := mini(i + 48, ids.size() - 1)
		# The brightest square on the way from i to each j: a straight line
		# may be no brighter (the dimmest way stays dim); on the chase's grid
		# never past the cap.
		var most := INF
		if lit:
			var run := PackedFloat32Array()
			run.resize(j - i + 1)
			var m := 0.0
			for k in range(i, j + 1):
				m = maxf(m, light_of(ids[k]))
				run[k - i] = m
			while j > i + 1:
				most = run[j - i] + 1e-4
				if capped:
					most = minf(most, light.cap)
				if line_open(ids[i], ids[j], most):
					break
				j -= 1
		else:
			while j > i + 1 and not line_open(ids[i], ids[j]):
				j -= 1
		out.append(point_of(ids[j]))
		i = j
	return out


## Whether `path` reached `to` (its last point within `near` m of it, flat)
## or stopped short of it (no way, or the light's edge: CAP).
static func reaches(pts: PackedVector3Array, to: Vector3, near := 0.6) -> bool:
	if pts.is_empty():
		return false
	var e := pts[pts.size() - 1]
	return Vector2(e.x - to.x, e.z - to.z).length() <= near


## The length of `pts` along the floor (m).
static func length_of(pts: PackedVector3Array) -> float:
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k - 1].distance_to(pts[k])
	return total

class_name WallLife
extends Node3D
## Wall life (design 6 Oct §FG; crawler.json ambience.wall_life): Mike's
## beetles, and the odd scarab, crawling the tomb's walls. The world
## answers your light; you never use any of it, and it marks nothing.
##
##   where    on the tomb's dressed wall faces (TombBuild wall_faces), count
##            of them a tomb, more where it's damp and dark: a face is
##            picked by its length, its dampness (GlowMoss.dampness: the
##            wet field the moss grows by, and the airways' damp air) and
##            how far it lies from every fire (the hearth, the holders that
##            may be relit); never in the hearth room, never on the stairs.
##   crawl    a wander over the stone (crawl_mps, turning as it goes),
##            resting now and then (crawl_s, rest_s), height_m up the wall;
##            its legs step (two poses) while it moves.
##   scatter  when a flame's light falls on one within scatter_from_light_m
##            (CrawlerFires.lit_on: the torch in hand, a planted torch, a lit
##            fire or sconce, no stone between), it scuttles to the nearest
##            joint of the stone it is on (the face's own stones,
##            FittedStone's cells: the cracks are real), at flee_mps or
##            faster, so that with sink_s to squeeze into the joint it is
##            gone from view within gone_within_s.
##   returns  hidden, it waits hide_s, then comes out of its crack again
##            (emerge_s) once no flame's light is on that spot: later, in
##            the dark.
##
## Tiny meshes, not sprites (the prompt's choice): at two to six pixels
## across a sprite and a mesh look alike, and a mesh lies on the wall at
## any heading. Matte and dark, lit like the world (CreatureBodies.mat).

static var W: Dictionary = ((Tuning.table("crawler").get("ambience", {}) as Dictionary).get("wall_life", {}) as Dictionary)
static var _meshes := {}

## The bugs: [{"kind", "face" (index into walls), "at" (Vector2 on the face:
## along from its start, up from its y0), "heading" (radians in the
## wall's plane, 0 along the face, PI/2 straight up), "speed" (crawling),
## "size" (m long), "state" ("crawl", "rest", "flee", "sink", "hidden",
## "emerge"), "t" (s left in the state), "crack" (Vector2: the joint it
## runs to), "flee_mps", "node"}].
var bugs: Array = []
var walls: Array = []
var fires: CrawlerFires
var _rng := RandomNumberGenerator.new()
var _t := 0.0
## How far back the joints are, and the band of bevel round each stone's
## face (masonry.json relief).
var _joint := 0.06
var _band := 0.035
## Per wall face with bugs on it: {"grid" (Vector2i square of GRID_M -> the
## stones over it), "inr" (each stone's inradius), "span" (Vector2: the
## stretch along it that is seen, in front of its own piece; a room's side
## wall runs on past its ends into the corners)}.
var _stones := {}
var _lay: Dictionary = {}
const GRID_M := 0.3


static func _r(v, rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	if v is Array and (v as Array).size() == 2:
		return rng.randf_range(float(v[0]), float(v[1]))
	return rng.randf_range(lo, hi)


## A kind's [min, max] from a by-kind table (wall_life size_m, crawl_mps).
static func _of(table: String, kind: String, dflt: Array) -> Array:
	var t: Variant = W.get(table, {})
	if t is Dictionary and (t as Dictionary).get(kind) is Array:
		return (t as Dictionary)[kind]
	return dflt


func build(lay: Dictionary, p_walls: Array, p_fires: CrawlerFires) -> void:
	walls = p_walls
	fires = p_fires
	_lay = lay
	_rng.seed = hash([int(lay.seed), "wall_life"])
	var rl := FittedStone.relief()
	_joint = float(rl.get("joint_depth_m", 0.06))
	_band = float(rl.get("joint_m", 0.012)) * 0.5 + float(rl.get("bevel_m", 0.05))
	# The faces by length, damp and dark.
	var fire_at := GlowMoss.fire_spots(lay)
	var weights: Array = []
	var total := 0.0
	for f in walls:
		var w := face_weight(lay, f, fire_at) if not (f.get("cells", []) as Array).is_empty() else 0.0
		weights.append(w)
		total += w
	var used := {}
	if total > 0.0:
		var n := roundi(_r(W.get("count", [10, 16]), _rng, 10.0, 16.0))
		for k in n:
			var pick := _rng.randf() * total
			var fi := 0
			while fi < weights.size() - 1 and pick > float(weights[fi]):
				pick -= float(weights[fi])
				fi += 1
			if float(weights[fi]) <= 0.0:
				continue
			if not used.has(fi):
				used[fi] = true
				_index_stones(fi)
			bugs.append(_spawn(fi))
	# Only the faces with something living on them keep their stones.
	for i in walls.size():
		if not used.has(i):
			(walls[i] as Dictionary).erase("cells")
			(walls[i] as Dictionary).erase("heights")


## Face `fi`'s stones by GRID_M squares (each stone under every square its
## bounds touch), and each one's inradius: which stone a bug is on.
func _index_stones(fi: int) -> void:
	var f: Dictionary = walls[fi]
	var grid := {}
	var inr := PackedFloat32Array()
	var cells: Array = f.get("cells", [])
	inr.resize(cells.size())
	for ci in cells.size():
		var poly: PackedVector2Array = cells[ci][1]
		var lo := poly[0]
		var hi := poly[0]
		for q in poly:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		for gx in range(floori(lo.x / GRID_M), floori(hi.x / GRID_M) + 1):
			for gy in range(floori(lo.y / GRID_M), floori(hi.y / GRID_M) + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(ci)
		inr[ci] = FittedStone._inradius(poly, FittedStone._centroid(poly))
	# The stretch that's seen: in front of the face's own piece.
	var pid := TombKit.piece_at(_lay, f.probe)
	var lo_a := INF
	var hi_a := -INF
	var a := 0.05
	while a <= float(f.length) - 0.05:
		var p: Vector3 = (f.o as Vector3) + (f.u as Vector3) * a + Vector3.UP * (float(f.floor_y) + 0.5) + (f.n as Vector3) * 0.3
		if TombKit.piece_at(_lay, p) == pid:
			lo_a = minf(lo_a, a)
			hi_a = maxf(hi_a, a)
		a += 0.05
	var span := Vector2(lo_a + 0.1, hi_a - 0.1) if hi_a - lo_a > 0.4 else Vector2(0.12, float(f.length) - 0.12)
	_stones[fi] = {"grid": grid, "inr": inr, "span": span}


## The stone (its index in its face's cells) bug `b` is on. Right on a
## joint's line (where it runs to, and comes out) it is on none, so the one
## it was last on: it sinks into the joint from that stone's rim and comes
## up onto it again.
func _stone_under(b: Dictionary) -> int:
	var fi := int(b.face)
	var cells: Array = (walls[fi] as Dictionary).get("cells", [])
	var at: Vector2 = b.at
	var last := int(b.get("stone", -1))
	if last >= 0 and last < cells.size() and Geometry2D.is_point_in_polygon(at, cells[last][1]):
		return last
	var idx: Dictionary = _stones.get(fi, {})
	for ci in (idx.get("grid", {}) as Dictionary).get(Vector2i(floori(at.x / GRID_M), floori(at.y / GRID_M)), []):
		if Geometry2D.is_point_in_polygon(at, cells[ci][1]):
			b["stone"] = ci
			return ci
	return last


## How far off the wall's face the stone under `b` stands where it is:
## its rim near its edges (the bevel band) and on its joint's line, rising
## over its pillowed middle; down at the joints' back over a sliver left as
## joint.
func _surface_at(b: Dictionary) -> float:
	var ci := _stone_under(b)
	var f: Dictionary = walls[int(b.face)]
	var hs: PackedVector2Array = f.get("heights", PackedVector2Array())
	if ci < 0 or ci >= hs.size():
		return -_joint
	var h := hs[ci]
	var poly: PackedVector2Array = (f.cells as Array)[ci][1]
	var at: Vector2 = b.at
	var edge := INF
	for i in poly.size():
		edge = minf(edge, Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()]).distance_to(at))
	var r := float((_stones[int(b.face)].inr as PackedFloat32Array)[ci])
	var k := clampf((edge - _band) / maxf(r - _band, 0.01), 0.0, 1.0)
	return h.x + (h.y - h.x) * (1.0 - (1.0 - k) * (1.0 - k))


## A wall face's share of the bugs: its length, more where it's damp
## (GlowMoss.dampness at its middle) and the farther it is from every fire
## (`fire_at`: GlowMoss.fire_spots), the darkest; 0 in the hearth room, on
## the stairs, or a scrap under 0.8 m.
static func face_weight(lay: Dictionary, f: Dictionary, fire_at: Array) -> float:
	var pid := TombKit.piece_at(lay, f.probe)
	if pid < 0 or float(f.length) < 0.8:
		return 0.0
	var pc: Dictionary = lay.pieces[pid]
	if str(pc.kind) == "stair" or str(pc.get("room_kind", "")) == "hearth":
		return 0.0
	var mid: Vector3 = (f.o as Vector3) + (f.u as Vector3) * float(f.length) * 0.5 + Vector3.UP * (float(f.floor_y) + 0.8)
	var near := INF
	for fp in fire_at:
		near = minf(near, (fp as Vector3).distance_to(mid))
	var damp := smoothstep(0.45, 0.75, GlowMoss.dampness(lay, mid))
	return float(f.length) * lerpf(0.3, 1.0, damp) * clampf((near - 2.0) / 6.0, 0.2, 1.0)


func _spawn(fi: int) -> Dictionary:
	var f: Dictionary = walls[fi]
	var kind := "scarab" if _rng.randf() < float(W.get("scarab_share", 0.2)) else "beetle"
	var hm: Array = W.get("height_m", [0.05, 2.0])
	var lift := float(f.floor_y) - float(f.y0)
	var top := float(f.y1) - float(f.y0) - 0.1
	var span: Vector2 = (_stones[fi] as Dictionary).span
	var at := Vector2(_rng.randf_range(span.x, maxf(span.y, span.x + 0.01)), clampf(lift + _rng.randf_range(float(hm[0]), float(hm[1])), lift + 0.03, top))
	var b := {"kind": kind, "face": fi, "at": at, "heading": _rng.randf() * TAU,
		"speed": _r(_of("crawl_mps", kind, [0.04, 0.09] if kind == "beetle" else [0.02, 0.045]), _rng, 0.03, 0.08),
		"size": _r(_of("size_m", kind, [0.024, 0.036] if kind == "beetle" else [0.04, 0.055]), _rng, 0.025, 0.04),
		"state": "crawl", "t": _r(W.get("crawl_s", [2.0, 7.0]), _rng, 2.0, 7.0), "crack": at, "flee_mps": float(W.get("flee_mps", 0.8))}
	var node := Node3D.new()
	node.name = kind.capitalize()
	add_child(node)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = bug_mesh(kind, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	b["node"] = node
	# A share start in their cracks and come out over the first while.
	if _rng.randf() < 0.3:
		b.state = "hidden"
		b.t = _rng.randf_range(0.5, 1.0) * _r(W.get("hide_s", [8.0, 22.0]), _rng, 8.0, 22.0)
		node.visible = false
	_place(b)
	return b


## Where a bug is in the scene: on its face's stones, or down in a joint.
func world_pos(b: Dictionary) -> Vector3:
	var f: Dictionary = walls[int(b.face)]
	var at: Vector2 = b.at
	return (f.o as Vector3) + (f.u as Vector3) * at.x + Vector3.UP * (float(f.y0) + at.y) + (f.n as Vector3) * _lift(b)


## How far off the wall's face it sits: on the stone under it, or sinking
## into a joint (sink), or coming out of one (emerge).
func _lift(b: Dictionary) -> float:
	var down := -_joint - 0.02
	if str(b.state) == "hidden":
		return down
	var on := _surface_at(b) + 0.002
	match str(b.state):
		"sink":
			return lerpf(down, on, clampf(float(b.t) / maxf(float(W.get("sink_s", 0.15)), 0.01), 0.0, 1.0))
		"emerge":
			return lerpf(on, down, clampf(float(b.t) / maxf(float(W.get("emerge_s", 0.4)), 0.01), 0.0, 1.0))
	return on


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_t += delta
	for b in bugs:
		_step_bug(b, delta)


## Is a flame's light on a bug (or, hidden, on its crack)?
func _lit(b: Dictionary) -> bool:
	if fires == null:
		return false
	var f: Dictionary = walls[int(b.face)]
	var f_o: Vector3 = f.o
	var f_u: Vector3 = f.u
	var at: Vector2 = b.at
	var on_face := f_o + f_u * at.x + Vector3.UP * (float(f.y0) + at.y)
	return fires.lit_on(on_face, f.n, float(W.get("scatter_from_light_m", 3.0)))


func _step_bug(b: Dictionary, delta: float) -> void:
	var f: Dictionary = walls[int(b.face)]
	var span: Vector2 = (_stones[int(b.face)] as Dictionary).span
	var lo := float(f.floor_y) - float(f.y0) + 0.03
	var hi := float(f.y1) - float(f.y0) - 0.1
	match str(b.state):
		"crawl", "rest":
			if _lit(b):
				_flee(b)
			else:
				b.t = float(b.t) - delta
				if str(b.state) == "rest":
					if float(b.t) <= 0.0:
						b.state = "crawl"
						b.t = _r(W.get("crawl_s", [2.0, 7.0]), _rng, 2.0, 7.0)
				else:
					b.heading = float(b.heading) + _rng.randf_range(-1.0, 1.0) * 3.0 * delta
					var at: Vector2 = b.at + Vector2(cos(float(b.heading)), sin(float(b.heading))) * float(b.speed) * delta
					# Turned back at the seen face's edges (a door's jamb, a
					# corner, the floor, the ceiling).
					if at.x < span.x or at.x > span.y:
						b.heading = PI - float(b.heading)
						at.x = clampf(at.x, span.x, span.y)
					if at.y < lo or at.y > hi:
						b.heading = -float(b.heading)
						at.y = clampf(at.y, lo, hi)
					b.at = at
					if float(b.t) <= 0.0:
						b.state = "rest"
						b.t = _r(W.get("rest_s", [1.0, 5.0]), _rng, 1.0, 5.0)
		"flee":
			var to: Vector2 = (b.crack as Vector2) - (b.at as Vector2)
			var go := float(b.flee_mps) * delta
			if to.length() <= go:
				b.at = b.crack
				b.state = "sink"
				b.t = float(W.get("sink_s", 0.15))
			else:
				b.at = (b.at as Vector2) + to.normalized() * go
				b.heading = atan2(to.y, to.x)
		"sink":
			b.t = float(b.t) - delta
			if float(b.t) <= 0.0:
				b.state = "hidden"
				b.t = _r(W.get("hide_s", [8.0, 22.0]), _rng, 8.0, 22.0)
				(b.node as Node3D).visible = false
		"hidden":
			b.t = float(b.t) - delta
			if float(b.t) <= 0.0:
				if _lit(b):
					b.t = _r(W.get("hide_s", [8.0, 22.0]), _rng, 8.0, 22.0) * 0.5
				else:
					b.state = "emerge"
					b.t = float(W.get("emerge_s", 0.4))
					b.heading = _rng.randf() * TAU
					(b.node as Node3D).visible = true
		"emerge":
			if _lit(b):
				# Back in at once.
				b.state = "sink"
				b.t = float(W.get("sink_s", 0.15)) * 0.5
			else:
				b.t = float(b.t) - delta
				if float(b.t) <= 0.0:
					b.state = "crawl"
					b.t = _r(W.get("crawl_s", [2.0, 7.0]), _rng, 2.0, 7.0)
	_place(b)


## Light on it: off to the nearest joint of the stone it's on, fast enough
## to be gone within gone_within_s.
func _flee(b: Dictionary) -> void:
	var f: Dictionary = walls[int(b.face)]
	var crack := nearest_joint(f.get("cells", []), b.at)
	b.crack = crack
	var run := maxf(float(W.get("gone_within_s", 0.85)) - float(W.get("sink_s", 0.15)) - 0.05, 0.05)
	b.flee_mps = maxf(float(W.get("flee_mps", 0.8)), crack.distance_to(b.at) / run)
	b.state = "flee"


## The nearest joint to `at` among a face's stones (`cells`: FittedStone
## cells, [site, polygon]): the nearest point on the edge of the stone
## `at` is on (or of any, if it's on none).
static func nearest_joint(cells: Array, at: Vector2) -> Vector2:
	var best := at
	var best_d := INF
	for pass_i in 2:
		for cell in cells:
			var poly: PackedVector2Array = cell[1]
			if pass_i == 0 and not Geometry2D.is_point_in_polygon(at, poly):
				continue
			for i in poly.size():
				var q := Geometry2D.get_closest_point_to_segment(at, poly[i], poly[(i + 1) % poly.size()])
				if q.distance_to(at) < best_d:
					best_d = q.distance_to(at)
					best = q
			if pass_i == 0:
				return best
	return best


## The bug's node where it is: lying on the wall, head along its heading,
## its legs stepping while it moves.
func _place(b: Dictionary) -> void:
	var node: Node3D = b.node
	if not node.visible and str(b.state) == "hidden":
		return
	var f: Dictionary = walls[int(b.face)]
	var u: Vector3 = f.u
	var n: Vector3 = f.n
	var fwd := (u * cos(float(b.heading)) + Vector3.UP * sin(float(b.heading))).normalized()
	var s := float(b.size)
	match str(b.state):
		"sink":
			s *= lerpf(0.55, 1.0, clampf(float(b.t) / maxf(float(W.get("sink_s", 0.15)), 0.01), 0.0, 1.0))
		"emerge":
			s *= lerpf(1.0, 0.55, clampf(float(b.t) / maxf(float(W.get("emerge_s", 0.4)), 0.01), 0.0, 1.0))
	node.global_transform = Transform3D(Basis(fwd.cross(n), n, -fwd).scaled(Vector3.ONE * s), world_pos(b))
	var moving := str(b.state) in ["crawl", "flee", "emerge"]
	var hz := 14.0 if str(b.state) == "flee" else 7.0
	var pose := int(_t * hz) % 2 if moving else 0
	var mi := node.get_child(0) as MeshInstance3D
	var m := bug_mesh(str(b.kind), pose)
	if mi.mesh != m:
		mi.mesh = m


## How many are out (seen) now.
func out_count() -> int:
	var n := 0
	for b in bugs:
		if (b.node as Node3D).visible:
			n += 1
	return n


# --- The bodies ---------------------------------------------------------------------

## A bug's body, one unit long, head toward -z, lying on the xz plane (up
## +y, off the wall): its shell (a beetle's long domed wing-cases and
## shield and small head; a scarab's rounder, broader dome and flat
## shovel of a head) in one colour and its six legs and feelers in a
## darker one (wall_life colors), the legs in one of two steps (`pose`).
static func bug_mesh(kind: String, pose: int) -> ArrayMesh:
	var key := "%s_%d" % [kind, pose]
	if _meshes.has(key):
		return _meshes[key]
	var cols: Array = ((W.get("colors", {}) as Dictionary).get(kind, ["#1c140f", "#0f0b08"] if kind == "beetle" else ["#1b2c25", "#0d1512"]))
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "scarab":
		_dome(st, Vector3(0.0, 0.0, 0.1), 0.36, 0.34, 0.3)
		_dome(st, Vector3(0.0, 0.0, -0.3), 0.3, 0.13, 0.2)
		_dome(st, Vector3(0.0, 0.0, -0.47), 0.2, 0.08, 0.07)
	else:
		_dome(st, Vector3(0.0, 0.0, 0.13), 0.26, 0.36, 0.24)
		_dome(st, Vector3(0.0, 0.0, -0.32), 0.2, 0.12, 0.16)
		_dome(st, Vector3(0.0, 0.0, -0.48), 0.12, 0.07, 0.1)
	mesh = st.commit()
	mesh.surface_set_material(0, CreatureBodies.mat(Color(str(cols[0]))))
	var lg := SurfaceTool.new()
	lg.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wide := 1.25 if kind == "scarab" else 1.0
	for i in 3:
		var z: float = [-0.3, -0.05, 0.2][i]
		for sd: float in [-1.0, 1.0]:
			# A tripod steps together: front and back on one side with the
			# middle on the other.
			var set_a := (i == 1) == (sd > 0.0)
			var dz := 0.08 * (1.0 if set_a == (pose == 0) else -1.0)
			var root := Vector3(sd * 0.17 * wide, 0.07, z)
			var knee := Vector3(sd * 0.36 * wide, 0.1, z + dz * 0.5 - 0.04)
			var foot := Vector3(sd * 0.47 * wide, 0.0, z + dz + (0.08 if i == 2 else -0.04))
			_strip(lg, root, knee, 0.06)
			_strip(lg, knee, foot, 0.05)
	# The feelers.
	for sd: float in [-1.0, 1.0]:
		_strip(lg, Vector3(sd * 0.05, 0.08, -0.53), Vector3(sd * 0.2, 0.06, -0.72), 0.035)
	lg.commit(mesh)
	mesh.surface_set_material(1, CreatureBodies.mat(Color(str(cols[1]))))
	_meshes[key] = mesh
	return mesh


## A half-ellipsoid dome on the xz plane at `c`: `hw` half wide (x), `hl`
## half long (z), `h` high; smooth normals; front faces outward (Godot's
## clockwise).
static func _dome(st: SurfaceTool, c: Vector3, hw: float, hl: float, h: float, segs := 8, rings := 3) -> void:
	var rows: Array = []
	for r in rings + 1:
		var phi := PI * 0.5 * r / rings
		var row: Array = []
		for s in segs:
			var th := TAU * s / segs
			row.append(c + Vector3(sin(th) * hw * cos(phi), h * sin(phi), cos(th) * hl * cos(phi)))
		rows.append(row)
	var nrm := func(p: Vector3) -> Vector3:
		var d := p - c
		return Vector3(d.x / (hw * hw), d.y / (h * h), d.z / (hl * hl)).normalized()
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = rows[r][s]
			var b: Vector3 = rows[r][s2]
			var top: Vector3 = rows[r + 1][s2]
			_tri(st, a, b, top, nrm.call(a), nrm.call(b), nrm.call(top), (a + b + top) / 3.0 - c)
			if r < rings - 1:
				var d2: Vector3 = rows[r + 1][s]
				_tri(st, a, top, d2, nrm.call(a), nrm.call(top), nrm.call(d2), (a + top + d2) / 3.0 - c)


## A thin flat strip from `a` to `b`, `w` wide, facing up (a leg, a
## feeler).
static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var along := b - a
	var side := along.cross(Vector3.UP).normalized() * w * 0.5
	if side.length() < 1e-5:
		side = Vector3(w * 0.5, 0.0, 0.0)
	var up := Vector3.UP
	_tri(st, a - side, a + side, b + side, up, up, up, up)
	_tri(st, a - side, b + side, b - side, up, up, up, up)


## One triangle, wound so its front faces `out` (Godot's front faces are
## clockwise seen from outside).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)

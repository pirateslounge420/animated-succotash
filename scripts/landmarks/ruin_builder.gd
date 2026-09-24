class_name RuinBuilder
## Builds a ruin (Ruins.find() site) as one low-poly mesh plus collision.
##
## Everything is stacked stone blocks, so collapse comes for free: each
## column of a wall or tower stops at its own jagged height, breaches drop
## whole stretches to stumps, window and door gaps are missing blocks, and
## fallen blocks lie in rubble at the foot. Moss creeps over every upward
## face and the lowest courses, ivy hangs in strands from broken tops, and
## vertex alpha marks moss for the night glow (shaders/ruin.gdshader).
##
## Silhouettes carry: castles ring a hilltop with a tall keep, towers stand
## 14-22 m, aqueducts stride level across the ground on tall piers. Ruins
## are built up to ~2.6 km out, beyond the terrain chunks, so their bases
## run down into a buried mound or deep footings and never float over the
## coarser far terrain.

const COURSE_M := 0.85
const STONES := [Color(0.62, 0.58, 0.5), Color(0.55, 0.53, 0.5), Color(0.66, 0.62, 0.52), Color(0.5, 0.48, 0.45), Color(0.6, 0.57, 0.56)]
const MOSS := Color(0.2, 0.44, 0.14)
const IVY := Color(0.1, 0.32, 0.12)
const IVY_LIGHT := Color(0.2, 0.46, 0.16)
const EARTH := Color(0.36, 0.3, 0.22)
const GRASS := Color(0.3, 0.52, 0.2)

static var _material: ShaderMaterial

var map: PlanetData
var site: Dictionary
var rng := RandomNumberGenerator.new()
var up: Vector3
var ex: Vector3 # local +x
var ez: Vector3 # local +z (right-handed with ex, up)
var base_e := 0.0

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/ruin.gdshader")
		Look.register(_material)
	return _material


## Build a ruin's geometry. Pure and thread-safe (reads the planet data
## only), so Landmarks runs it on a worker thread; make_node() turns the
## result into nodes on the main thread.
static func compute(p_map: PlanetData, p_site: Dictionary) -> Dictionary:
	var b := RuinBuilder.new()
	b.map = p_map
	b.site = p_site
	b.rng.seed = p_site.seed
	b.up = p_site.dir
	var a: float = p_site.heading + PI * 0.5
	b.ex = CubeSphere.north(b.up) * cos(a) + CubeSphere.east(b.up) * sin(a)
	b.ez = b.ex.cross(b.up).normalized()
	b.base_e = p_map.terrain.elevation(b.up, true)
	match p_site.kind:
		Ruins.Kind.CASTLE:
			b._castle()
		Ruins.Kind.TOWER:
			b._lone_tower()
		Ruins.Kind.AQUEDUCT:
			b._aqueduct()
	return {"site": p_site, "v": b._v, "n": b._n, "c": b._c, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e}


## Main thread: mesh and collision (see placement()).
static func make_node(data: Dictionary, world: Node) -> Node3D:
	var site: Dictionary = data.site
	var root := Node3D.new()
	root.name = Ruins.KIND_NAMES[site.kind].replace(" ", "")
	root.set_meta("site", site)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.v
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material()
	root.add_child(mi)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.v)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)
	return root


## Where the node goes, in scene space (set it after adding the node to
## the tree: its parent may have been shifted by the floating origin).
static func placement(data: Dictionary, world: Node) -> Transform3D:
	return Transform3D(Basis(data.ex, data.up, data.ez), world.to_scene(data.up, PlanetConst.RADIUS_M + data.base_e))


## Ground height at local (x, z), relative to the ruin's origin.
func ground(x: float, z: float) -> float:
	var d := (up + (ex * x + ez * z) / PlanetConst.RADIUS_M).normalized()
	return map.terrain.elevation(d, true) - base_e


# --- Primitives ----------------------------------------------------------------

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	_v.append_array([a, b, c])
	_n.append_array([nrm, nrm, nrm])
	_c.append_array([col, col, col])


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)


## A quad whose normal points away from `inside` (winding fixed to match).
func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot((a + c) * 0.5 - inside) < 0.0:
		_quad(a, d, c, b, col)
	else:
		_quad(a, b, c, d, col)


## A box. `moss` (0-1) greens the top face fully and the sides partly;
## the same value goes to vertex alpha for the glow.
func box(xf: Transform3D, size: Vector3, col: Color, moss: float) -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	var top := col.lerp(MOSS, moss)
	top.a = moss
	var side := col.lerp(MOSS, moss * 0.3)
	side.a = moss * 0.4
	var bottom := col.darkened(0.3)
	bottom.a = 0.0
	var o := xf.origin
	_face(p[2], p[3], p[7], p[6], top, o) # +y
	_face(p[0], p[4], p[5], p[1], bottom, o) # -y
	_face(p[1], p[5], p[7], p[3], side, o) # +x
	_face(p[0], p[2], p[6], p[4], side, o) # -x
	_face(p[4], p[6], p[7], p[5], side, o) # +z
	_face(p[0], p[1], p[3], p[2], side, o) # -z


## A block at a position, its length (size.x) running along `dir`
## (horizontal), with a little crumble.
func block(center: Vector3, dir: Vector3, size: Vector3, moss: float, wobble := 0.04) -> void:
	var x := dir.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var basis := Basis(x, Vector3.UP, z)
	basis = basis.rotated(Vector3.UP, rng.randf_range(-wobble, wobble)).rotated(x, rng.randf_range(-wobble, wobble) * 0.5)
	var col: Color = STONES[rng.randi() % STONES.size()]
	col = col.lightened(rng.randf_range(-0.06, 0.06))
	box(Transform3D(basis, center), size, col, moss)


## An ivy strand hanging from `top` down a face with outward normal `out`.
func ivy(top: Vector3, out: Vector3, length: float) -> void:
	var side := Vector3.UP.cross(out).normalized() * rng.randf_range(0.25, 0.45)
	var o := out.normalized() * 0.08
	var steps := maxi(1, int(length / 0.8))
	var prev_l := top + o - side
	var prev_r := top + o + side
	for i in steps:
		var y := -length * float(i + 1) / steps
		var sway := side * rng.randf_range(-0.4, 0.4)
		var taper := 1.0 - 0.6 * float(i + 1) / steps
		var l := top + o + Vector3(0, y, 0) - side * taper + sway
		var r := top + o + Vector3(0, y, 0) + side * taper + sway
		var col := IVY.lerp(IVY_LIGHT, rng.randf())
		col.a = 1.0
		_quad(prev_l, prev_r, r, l, col)
		# A leaf sticking out.
		if rng.randf() < 0.6:
			var c := (prev_l + r) * 0.5 + o
			var s := rng.randf_range(0.18, 0.3)
			_tri(c, c + out.normalized() * s + Vector3(0, s, 0), c + side.normalized() * s, col.lightened(0.1))
		prev_l = l
		prev_r = r


## Fallen blocks strewn around a point.
func rubble(center: Vector3, spread: float, count: int) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		var x := center.x + cos(a) * r
		var z := center.z + sin(a) * r
		var size := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var col: Color = STONES[rng.randi() % STONES.size()]
		box(Transform3D(basis, Vector3(x, ground(x, z) + size.y * 0.3, z)), size, col, rng.randf_range(0.3, 0.9))


# --- Walls and towers ------------------------------------------------------------

## A straight wall of stacked blocks from a to b (local xz), `height` tall.
## Breaches: [[t0, t1], ...] stretches (0-1 along the wall) collapsed to
## stumps. Returns the number of fallen courses (for rubble).
func wall(a: Vector2, b: Vector2, height: float, thick: float, breaches: Array, ivy_chance := 0.3) -> int:
	var along := b - a
	var length := along.length()
	var dir3 := Vector3(along.x, 0, along.y) / length
	var out := Vector3(dir3.z, 0, -dir3.x)
	var cols := maxi(1, int(ceil(length / 1.5)))
	var bw := length / cols
	var fallen := 0
	for i in cols:
		var t := (i + 0.5) / cols
		var p := a + along * t
		var g := ground(p.x, p.y)
		var h := height - rng.randf_range(0.0, 2.2) * COURSE_M
		for br in breaches:
			if t > br[0] and t < br[1]:
				# V-shaped gap: full height at its edges, stumps in the middle.
				var depth := minf(t - br[0], br[1] - t) / maxf(br[1] - br[0], 0.01) * 2.0
				h = minf(h, lerpf(height, rng.randf_range(0.0, 1.2), smoothstep(0.0, 0.6, depth)))
		h = maxf(h, 0.0)
		fallen += int((height - h) / COURSE_M)
		# Footing down into the ground, then courses.
		block(Vector3(p.x, g - 1.2, p.y), dir3, Vector3(bw, 1.6, thick * 1.1), 0.0, 0.0)
		var y := g - 0.4
		var k := 0
		while y + COURSE_M * 0.5 < g + h:
			if y > g + 1.0 and rng.randf() < 0.04:
				y += COURSE_M
				k += 1
				continue
			var moss := 0.15 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
			block(Vector3(p.x, y + COURSE_M * 0.5, p.y), dir3, Vector3(bw * 0.97, COURSE_M * 0.96, thick), moss)
			y += COURSE_M
			k += 1
		if h > 1.0 and rng.randf() < ivy_chance:
			var top := Vector3(p.x, g + h, p.y)
			ivy(top + out * thick * 0.5, out, rng.randf_range(1.2, minf(5.0, h)))
			if rng.randf() < 0.5:
				ivy(top - out * thick * 0.5, -out, rng.randf_range(1.0, minf(4.0, h)))
	return fallen


## A round tower of block rings, `height` tall, with one side slumped.
func round_tower(center: Vector2, radius: float, height: float, door_angle: float) -> void:
	var segs := maxi(8, int(TAU * radius / 1.4))
	var slump_a := rng.randf() * TAU
	var slump := rng.randf_range(0.2, 0.5)
	var fallen := 0
	for i in segs:
		var a := TAU * i / segs
		var p := center + Vector2(cos(a), sin(a)) * radius
		var tangent := Vector3(-sin(a), 0, cos(a))
		var out := Vector3(cos(a), 0, sin(a))
		var g := ground(p.x, p.y)
		var closeness := (cos(a - slump_a) + 1.0) * 0.5
		var h := height * (1.0 - slump * smoothstep(0.4, 1.0, closeness)) - rng.randf_range(0.0, 2.5)
		fallen += int((height - h) / COURSE_M)
		var bw := TAU * radius / segs
		block(Vector3(p.x, g - 1.2, p.y), tangent, Vector3(bw * 1.05, 1.6, 1.5), 0.0, 0.0)
		var y := g - 0.4
		var door := absf(angle_difference(a, door_angle)) < 0.35
		var window_row := rng.randi_range(6, 10)
		while y + COURSE_M * 0.5 < g + h:
			var course := int((y - g) / COURSE_M)
			var gap := (door and y < g + 2.4) or (course % window_row == 0 and course > 3 and rng.randf() < 0.35)
			if not gap:
				var moss := 0.12 + 0.5 * exp(-(y - g) / 1.5) + rng.randf_range(0.0, 0.2)
				block(Vector3(p.x, y + COURSE_M * 0.5, p.y), tangent, Vector3(bw * 1.02, COURSE_M * 0.96, 1.3), moss)
			y += COURSE_M
		if h > 2.0 and rng.randf() < 0.35:
			ivy(Vector3(p.x, g + h, p.y) + out * 0.65, out, rng.randf_range(2.0, minf(7.0, h)))
	rubble(Vector3(center.x + cos(slump_a) * (radius + 2.0), 0, center.y + sin(slump_a) * (radius + 2.0)), 3.5, mini(fallen / 6, 16))


## A buried earth mound (motte) under a structure: keeps it from floating
## over the coarse far terrain and gives castles their raised hilltop.
func mound(radius_top: float, radius_bottom: float, depth: float, rise: float) -> void:
	var sides := 12
	var top_pts: Array = []
	var bot_pts: Array = []
	for i in sides:
		var a := TAU * i / sides + rng.randf_range(-0.08, 0.08)
		var rt := radius_top * rng.randf_range(0.92, 1.05)
		top_pts.append(Vector3(cos(a) * rt, rise + rng.randf_range(-0.3, 0.2), sin(a) * rt))
		bot_pts.append(Vector3(cos(a) * radius_bottom, -depth, sin(a) * radius_bottom))
	# Match the local ground so the motte reads as part of the hill.
	var grass := TerrainChunk._biome_blend(map, up).lerp(GRASS, 0.15)
	grass.a = 0.3
	var earth := grass.darkened(0.3).lerp(EARTH, 0.4)
	earth.a = 0.1
	var c := Vector3(0, rise, 0)
	var inside := Vector3(0, -depth * 0.5, 0)
	for i in sides:
		var j := (i + 1) % sides
		_face(c, top_pts[j], top_pts[i], top_pts[i], grass, inside)
		_face(top_pts[i], top_pts[j], bot_pts[j], bot_pts[i], earth.lerp(grass, 0.25), inside)


# --- Structures -------------------------------------------------------------------

func _castle() -> void:
	mound(24.0, 36.0, 32.0, 0.35)
	# Curtain wall: an octagon with two breaches and a gate gap.
	var r := 17.0
	var pts: Array = []
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	var breach_sides := [rng.randi() % 8, rng.randi() % 8]
	var gate := rng.randi() % 8
	var fallen := 0
	for i in 8:
		var breaches: Array = []
		if i in breach_sides:
			var s := rng.randf_range(0.15, 0.55)
			breaches.append([s, s + rng.randf_range(0.25, 0.4)])
		if i == gate:
			breaches.append([0.4, 0.6])
		fallen += wall(pts[i], pts[(i + 1) % 8], rng.randf_range(6.0, 7.5), 1.6, breaches)
		if i in breach_sides:
			var mid: Vector2 = (pts[i] + pts[(i + 1) % 8]) * 0.5
			rubble(Vector3(mid.x * 1.12, 0, mid.y * 1.12), 4.0, 12)
	# Corner towers on alternate corners.
	for i in range(0, 8, 2):
		round_tower(pts[i], 2.8, rng.randf_range(8.5, 11.5), rng.randf() * TAU)
	# The keep: a tall square tower, one corner fallen in.
	var k := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
	var hs := 4.5
	var keep_h := rng.randf_range(15.0, 19.0)
	var corners := [k + Vector2(-hs, -hs), k + Vector2(hs, -hs), k + Vector2(hs, hs), k + Vector2(-hs, hs)]
	var broken := rng.randi() % 4
	for i in 4:
		var br: Array = []
		if i == broken:
			br = [[0.55, 1.05]]
		elif i == (broken + 3) % 4:
			br = [[-0.05, 0.35]]
		wall(corners[i], corners[(i + 1) % 4], keep_h, 1.3, br, 0.45)
	var fall_corner: Vector2 = corners[(broken + 1) % 4]
	rubble(Vector3(fall_corner.x * 1.3, 0, fall_corner.y * 1.3), 5.0, 22)
	rubble(Vector3.ZERO, 14.0, mini(fallen / 4, 30))


func _lone_tower() -> void:
	mound(6.0, 10.0, 14.0, 0.0)
	round_tower(Vector2.ZERO, rng.randf_range(3.2, 4.2), rng.randf_range(14.0, 22.0), rng.randf() * TAU)
	# A stump of an old wall running off from it.
	var a := rng.randf() * TAU
	var end := Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 16.0)
	wall(Vector2(cos(a), sin(a)) * 3.8, end, rng.randf_range(2.0, 4.0), 1.2, [[0.5, 1.1]], 0.4)


## Arches striding level across the ground on piers; some spans fallen.
func _aqueduct() -> void:
	var length: float = site.length_m
	var spacing := 7.5
	var piers := int(length / spacing) + 1
	var x0 := -spacing * (piers - 1) * 0.5
	var top := -INF
	for i in piers:
		top = maxf(top, ground(x0 + i * spacing, 0.0))
	top += rng.randf_range(9.0, 12.0)
	var spring := top - 3.6
	var fallen_span := []
	for i in piers - 1:
		fallen_span.append(rng.randf() < 0.22 or i == 0 and rng.randf() < 0.5 or i == piers - 2 and rng.randf() < 0.5)
	var along := Vector3(1, 0, 0)
	for i in piers:
		var x := x0 + i * spacing
		var g := ground(x, 0.0)
		# Deep footing (hidden underground next to the chunks; keeps the
		# silhouette grounded against the coarser far terrain).
		box(Transform3D(Basis.IDENTITY, Vector3(x, g - 18.0, 0)), Vector3(2.0, 34.0, 2.4), STONES[1], 0.0)
		var both_fallen: bool = (i == 0 or fallen_span[i - 1]) and (i == piers - 1 or fallen_span[mini(i, piers - 2)])
		var h := spring - g + 0.4
		if both_fallen:
			h *= rng.randf_range(0.2, 0.7)
		var y := g - 0.4
		while y < g + h:
			var moss := 0.1 + 0.5 * exp(-(y - g) / 2.0) + rng.randf_range(0.0, 0.25)
			block(Vector3(x, y + COURSE_M * 0.5, 0), along, Vector3(1.8, COURSE_M * 0.96, 2.2), moss, 0.03)
			y += COURSE_M
		if both_fallen:
			rubble(Vector3(x + rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), 3.0, 8)
	# Arches, spandrels and the channel on top.
	for i in piers - 1:
		var xa := x0 + i * spacing + 0.9
		var xb := x0 + (i + 1) * spacing - 0.9
		if fallen_span[i]:
			# Broken arch stubs on both sides.
			for s in [0, 1]:
				var xs: float = xa if s == 0 else xb
				var dirx := 1.0 if s == 0 else -1.0
				for k in rng.randi_range(1, 2):
					var ang := PI * 0.5 * (k + 0.5) / 4.0
					var rr := (xb - xa) * 0.5
					var cx := xs + dirx * (rr - cos(ang) * rr)
					block(Vector3(cx, spring + sin(ang) * rr, 0), along, Vector3(0.9, 0.7, 2.1), 0.5)
			continue
		var cx := (xa + xb) * 0.5
		var rr := (xb - xa) * 0.5
		var stones := 9
		for k in stones:
			var ang := PI * (k + 0.5) / stones
			var p := Vector3(cx - cos(ang) * rr, spring + sin(ang) * rr, 0)
			var tangent := Vector3(sin(ang), cos(ang), 0)
			var basis := Basis(tangent, tangent.cross(Vector3(0, 0, 1)).normalized() * -1.0, Vector3(0, 0, 1)).orthonormalized()
			var col: Color = STONES[rng.randi() % STONES.size()]
			box(Transform3D(basis, p), Vector3(rr * PI / stones * 1.05, 0.7, 2.1), col, 0.35)
		# Spandrel courses from the arch crown up to the deck.
		var y := spring + rr * 0.55
		while y < top - 0.5:
			for part in [xa + (xb - xa) * 0.18, xb - (xb - xa) * 0.18, cx]:
				if part == cx and y < spring + rr + 0.2:
					continue
				block(Vector3(part, y + COURSE_M * 0.5, 0), along, Vector3((xb - xa) * 0.36, COURSE_M * 0.96, 2.2), 0.3)
			y += COURSE_M
		# Channel: floor and two low side walls, mossy and ivy-draped.
		block(Vector3(cx, top, 0), along, Vector3(spacing, 0.5, 2.4), 0.8, 0.02)
		for sz in [-1.0, 1.0]:
			if rng.randf() < 0.85:
				block(Vector3(cx, top + 0.55, sz * 1.0), along, Vector3(spacing * rng.randf_range(0.6, 1.0), 0.6, 0.4), 0.9, 0.05)
			if rng.randf() < 0.55:
				ivy(Vector3(cx + rng.randf_range(-2.5, 2.5), top + 0.2, sz * 1.25), Vector3(0, 0, sz), rng.randf_range(2.0, 6.0))

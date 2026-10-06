class_name BeastHeads
## Beast heads under the hood (design 5 Oct §EO.1; data/zodiac_heads.json).
## The shared cloaked rig (PlayerBody, CloakedFigure) is unchanged; only
## the head changes. Each people's folk are one of the twelve Eastern
## zodiac animals (zodiac_heads.json peoples), the dragon the rare tribe
## (rare.dragon: a share of camps, rolled from the camp's seed). The head
## sits inside the hood's hollow, its snout, beak or horns just out past
## the brim, and is drawn by shaders/beast_head.gdshader: only up close
## (look.near_m to look.gone_m) does it show; further off it fades into
## the hood's flat dark hollow, so the figure reads as a person. The
## player's hood stays empty (§EO.2: PlayerBody.set_beast refuses it).
##
## Where a head comes from: a node above the body carries meta "beast"
## (an animal id). Camps and the opening camp set it on their root; the
## travellers and the wandering fire on theirs. A body (not the player's)
## looks for it when it enters the tree, so every folk a camp adds later
## (walkers, carriers, the hunter, the gift-giver) wears it too.
##
## Shapes: a few rounded parts per animal (ellipsoids and tapered cones,
## low-poly, vertex colours: fur, muzzle, accent from look.colours), in
## the Head pivot's space (the neck at 0, -Z forward). The hood's hollow
## is about 0.1 m round its middle at y 0.117 and its brim at z -0.13.

static var Z: Dictionary = {}
static var _meshes := {}
static var _mat: ShaderMaterial

const HEAD_C := Vector3(0, 0.112, -0.005)


static func data() -> Dictionary:
	if Z.is_empty():
		Z = Tuning.table("zodiac_heads")
	return Z


## The twelve animals (heads.*).
static func animals() -> Array:
	return ((data().get("heads", {}) as Dictionary).keys())


## The animal a people's folk are ("" none: the empty hood).
static func of_people(people_id: String) -> String:
	return str((data().get("peoples", {}) as Dictionary).get(people_id, ""))


## The animal of a camp of `people_id` with seed `seed_value` and folk
## kind `kind`: the people's, or the dragon for the rare tribe; "" for a
## kind that keeps the empty hood (look.no_head_kinds).
static func for_camp(people_id: String, seed_value: int, kind := "human", rare_ok := true) -> String:
	var look: Dictionary = data().get("look", {})
	if (look.get("no_head_kinds", []) as Array).has(kind):
		return ""
	var a := of_people(people_id)
	if a == "":
		return ""
	if rare_ok:
		var ch := float(((data().get("rare", {}) as Dictionary).get("dragon", {}) as Dictionary).get("chance_per_camp", 0.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "dragon"])
		if rng.randf() < ch:
			return "dragon"
	return a


## The animal for a body: the first ancestor's meta "beast" ("" none).
static func beast_above(n: Node) -> String:
	var p := n.get_parent()
	while p != null:
		if p.has_meta("beast"):
			return str(p.get_meta("beast"))
		p = p.get_parent()
	return ""


## The head's material (shared): the fade distances and hood shade from
## look.
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/beast_head.gdshader")
		Look.register(_mat)
		var look: Dictionary = data().get("look", {})
		_mat.set_shader_parameter("near_m", float(look.get("near_m", 4.0)))
		_mat.set_shader_parameter("gone_m", float(look.get("gone_m", 8.0)))
		_mat.set_shader_parameter("hood_shade", float(look.get("hood_shade", 0.6)))
	return _mat


## The head mesh for `animal` (built once), or null for an unknown one.
static func mesh(animal: String) -> ArrayMesh:
	if _meshes.has(animal):
		return _meshes[animal]
	if not (data().get("heads", {}) as Dictionary).has(animal):
		return null
	var cols: Array = ((data().get("look", {}) as Dictionary).get("colours", {}) as Dictionary).get(animal, ["#7A6A5A", "#9A8A7A", "#3A2A22"])
	var fur := Color(str(cols[0]))
	var muz := Color(str(cols[1 % cols.size()]))
	var acc := Color(str(cols[2 % cols.size()]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := _shape(st, animal, fur, muz, acc)
	var m := st.commit()
	m.set_meta("tris", tris)
	_meshes[animal] = m
	return m


## The parts of each head. Returns its triangle count.
static func _shape(st: SurfaceTool, a: String, fur: Color, muz: Color, acc: Color) -> int:
	var n := 0
	var eye := Color(0.86, 0.7, 0.3)
	var dark := Color(0.08, 0.07, 0.07)
	var c := HEAD_C
	# The skull, filling the hood's hollow.
	match a:
		"snake":
			n += _ball(st, c + Vector3(0, -0.005, -0.03), Vector3(0.062, 0.05, 0.09), fur)
		"monkey":
			n += _ball(st, c, Vector3(0.075, 0.082, 0.075), fur)
		_:
			n += _ball(st, c, Vector3(0.072, 0.078, 0.078), fur)
	var eye_y := c.y + 0.022
	var eye_z := -0.072
	var eye_x := 0.032
	match a:
		"rat":
			n += _cone(st, c + Vector3(0, -0.012, -0.05), c + Vector3(0, -0.022, -0.165), 0.036, 0.012, fur)
			n += _ball(st, c + Vector3(0, -0.022, -0.168), Vector3(0.013, 0.012, 0.012), acc)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.058, 0.05, -0.045), Vector3(0.026, 0.026, 0.008), acc.lerp(fur, 0.5))
		"ox":
			n += _ball(st, c + Vector3(0, -0.035, -0.095), Vector3(0.058, 0.045, 0.055), muz)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.02, -0.04, -0.148), Vector3(0.01, 0.01, 0.006), dark)
				n += _cone(st, c + Vector3(s * 0.055, 0.045, -0.06), c + Vector3(s * 0.1, 0.06, -0.125), 0.016, 0.004, acc)
			eye_x = 0.042
		"tiger":
			n += _ball(st, c + Vector3(0, -0.03, -0.085), Vector3(0.045, 0.034, 0.04), muz)
			n += _ball(st, c + Vector3(0, -0.018, -0.124), Vector3(0.012, 0.009, 0.006), acc)
			for i in 3:
				n += _ball(st, c + Vector3((i - 1) * 0.022, 0.06, -0.06), Vector3(0.006, 0.02, 0.006), acc)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.055, 0.0, -0.065), Vector3(0.022, 0.006, 0.006), acc)
		"rabbit":
			n += _ball(st, c + Vector3(0, -0.032, -0.075), Vector3(0.04, 0.034, 0.038), muz)
			n += _ball(st, c + Vector3(0, -0.02, -0.112), Vector3(0.01, 0.008, 0.006), acc)
			# The ears laid back under the hood, their roots showing.
			for s in [-1.0, 1.0]:
				n += _cone(st, c + Vector3(s * 0.028, 0.06, -0.04), c + Vector3(s * 0.04, 0.085, 0.09), 0.02, 0.012, fur)
			eye_x = 0.04
		"dragon":
			n += _cone(st, c + Vector3(0, -0.012, -0.05), c + Vector3(0, -0.026, -0.18), 0.045, 0.026, muz)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.016, -0.014, -0.175), Vector3(0.007, 0.006, 0.006), dark)
				n += _cone(st, c + Vector3(s * 0.04, 0.05, -0.045), c + Vector3(s * 0.07, 0.085, -0.11), 0.012, 0.003, acc)
				n += _cone(st, c + Vector3(s * 0.035, -0.04, -0.12), c + Vector3(s * 0.05, -0.085, -0.15), 0.006, 0.002, acc)
			n += _ball(st, c + Vector3(0, 0.035, -0.07), Vector3(0.05, 0.012, 0.03), fur.darkened(0.2))
		"snake":
			n += _ball(st, c + Vector3(0, -0.02, -0.105), Vector3(0.045, 0.026, 0.045), muz)
			eye_x = 0.05
			eye_z = -0.085
			eye_y = c.y + 0.012
		"horse":
			n += _cone(st, c + Vector3(0, -0.005, -0.04), c + Vector3(0, -0.045, -0.155), 0.048, 0.036, fur)
			n += _ball(st, c + Vector3(0, -0.05, -0.155), Vector3(0.038, 0.03, 0.022), muz)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.015, -0.045, -0.175), Vector3(0.007, 0.007, 0.004), acc)
			n += _cone(st, c + Vector3(0, 0.07, -0.02), c + Vector3(0, 0.03, -0.1), 0.02, 0.006, acc)
		"goat":
			n += _cone(st, c + Vector3(0, -0.01, -0.05), c + Vector3(0, -0.035, -0.15), 0.04, 0.024, muz)
			n += _cone(st, c + Vector3(0, -0.06, -0.1), c + Vector3(0, -0.12, -0.11), 0.016, 0.003, muz)
			for s in [-1.0, 1.0]:
				n += _cone(st, c + Vector3(s * 0.035, 0.06, -0.05), c + Vector3(s * 0.06, 0.09, 0.0), 0.014, 0.004, acc)
		"monkey":
			n += _ball(st, c + Vector3(0, -0.01, -0.07), Vector3(0.052, 0.058, 0.026), muz)
			n += _ball(st, c + Vector3(0, -0.04, -0.09), Vector3(0.03, 0.02, 0.016), muz.darkened(0.1))
			eye_z = -0.09
			eye_x = 0.022
			eye_y = c.y + 0.012
		"rooster":
			n += _cone(st, c + Vector3(0, -0.005, -0.065), c + Vector3(0, -0.02, -0.135), 0.018, 0.0, muz)
			for i in 3:
				n += _ball(st, c + Vector3(0, 0.075 - i * 0.006, -0.03 - i * 0.025), Vector3(0.007, 0.02, 0.012), acc)
			n += _ball(st, c + Vector3(0, -0.045, -0.085), Vector3(0.009, 0.02, 0.01), acc)
		"dog":
			n += _cone(st, c + Vector3(0, -0.015, -0.05), c + Vector3(0, -0.025, -0.15), 0.038, 0.022, muz)
			n += _ball(st, c + Vector3(0, -0.018, -0.152), Vector3(0.014, 0.011, 0.01), acc)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.066, 0.005, -0.03), Vector3(0.012, 0.042, 0.026), fur.darkened(0.2))
		"pig":
			n += _cone(st, c + Vector3(0, -0.025, -0.06), c + Vector3(0, -0.025, -0.14), 0.034, 0.03, muz)
			n += _ball(st, c + Vector3(0, -0.025, -0.142), Vector3(0.032, 0.026, 0.006), acc)
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.012, -0.025, -0.148), Vector3(0.006, 0.008, 0.004), dark)
				n += _cone(st, c + Vector3(s * 0.05, 0.05, -0.04), c + Vector3(s * 0.07, 0.04, -0.1), 0.018, 0.004, fur)
	for s in [-1.0, 1.0]:
		n += _ball(st, Vector3(s * eye_x, eye_y, eye_z), Vector3(0.011, 0.011, 0.008), eye)
		n += _ball(st, Vector3(s * eye_x, eye_y, eye_z - 0.007), Vector3(0.005, 0.007, 0.003), dark)
	return n


static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


## A low-poly ellipsoid at `c`, radii `r`.
static func _ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> int:
	var seg := 10
	var rings := 6
	var lc := _lin(col)
	var pts: Array = []
	for j in rings + 1:
		var phi := PI * j / rings
		var row: Array = []
		for i in seg + 1:
			var th := TAU * i / seg
			row.append(c + Vector3(sin(phi) * cos(th) * r.x, cos(phi) * r.y, sin(phi) * sin(th) * r.z))
		pts.append(row)
	var n := 0
	for j in rings:
		for i in seg:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var d: Vector3 = pts[j + 1][i]
			var e: Vector3 = pts[j + 1][i + 1]
			n += _quad(st, a, b, e, d, lc, func(p: Vector3) -> Vector3: return ((p - c) / (r * r)).normalized())
	return n


## A tapered cone from `a` (radius ra) to `b` (radius rb), capped.
static func _cone(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color) -> int:
	var seg := 8
	var lc := _lin(col)
	var ax := (b - a).normalized()
	var x := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := ax.cross(x).normalized()
	var n := 0
	for i in seg:
		var t0 := TAU * i / seg
		var t1 := TAU * (i + 1) / seg
		var o0 := x * cos(t0) + y * sin(t0)
		var o1 := x * cos(t1) + y * sin(t1)
		var side := func(p: Vector3) -> Vector3:
			var q := p - a
			var radial := (q - ax * q.dot(ax)).normalized()
			return (radial + ax * (ra - rb) / maxf((b - a).length(), 0.001)).normalized()
		n += _quad(st, a + o0 * ra, a + o1 * ra, b + o1 * rb, b + o0 * rb, lc, side)
		_tri(st, a, a + o1 * ra, a + o0 * ra, lc, func(_p: Vector3) -> Vector3: return -ax)
		n += 1
		if rb > 0.0:
			_tri(st, b, b + o0 * rb, b + o1 * rb, lc, func(_p: Vector3) -> Vector3: return ax)
			n += 1
	return n


## (Both faces are drawn: the head shader culls nothing, so winding never
## hides a part; `nrm` gives each vertex its outward normal.)
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, nrm: Callable) -> int:
	_tri(st, a, b, c, col, nrm)
	_tri(st, a, c, d, col, nrm)
	return 2


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, nrm: Callable) -> void:
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(nrm.call(p))
		st.add_vertex(p)

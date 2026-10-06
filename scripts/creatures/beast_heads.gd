class_name BeastHeads
## Beast heads (design 5 Oct §EO.1, 6 Oct §EQ; data/zodiac_heads.json,
## data/beast_head_fit.json). The shared cloaked rig (PlayerBody,
## CloakedFigure) is unchanged; only the head changes. Each people's folk
## are one of the twelve Eastern zodiac animals (zodiac_heads.json
## peoples), the dragon the rare tribe (rare.dragon: a share of camps,
## rolled from the camp's seed).
##
## §EQ: the head is life-sized for its animal (fit(): beast_head_fit.json
## scale, forward_m, drop_m, muzzle_out over its defaults), pushed forward
## so the muzzle, beak or snout juts past the hood's brim, and the hood
## becomes a cowl behind it (PlayerBody.set_beast: the lined hood with no
## dark hollow, stretched round the skull, its brim slid back behind every
## through_hood part, tilted back off the crown). The silhouette shows at
## every distance; shaders/beast_head.gdshader fades only the face's
## painted detail to plain fur past look.near_m..gone_m. The player's hood
## stays empty and whole (§EO.2: PlayerBody.set_beast refuses it).
##
## Where a head comes from: a node above the body carries meta "beast"
## (an animal id). Camps and the opening camp set it on their root; the
## travellers on theirs. A body (not the player's) looks for it when it
## enters the tree, so every folk a camp adds later (walkers, carriers,
## the hunter, the gift-giver) wears it too.
##
## Shapes: a few rounded parts per animal (ellipsoids and tapered cones,
## low-poly, vertex colours: fur, muzzle, accent from look.colours), each
## tagged (skull, muzzle, face, ears, horns, ...: _shape), in the Head
## pivot's space (the neck at 0, -Z forward), sized to today's hollow
## (about 0.1 m round its middle at y 0.117, the brim at z -0.13) and
## then fitted.

static var Z: Dictionary = {}
static var _meshes := {}

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


static var _mats := {}


## `animal`'s head material (one per animal): the face's painted detail
## fades to its plain fur between look.near_m and look.gone_m (§EQ.2: the
## silhouette itself shows at every distance).
static func material(animal := "") -> ShaderMaterial:
	if _mats.has(animal):
		return _mats[animal]
	var mt := ShaderMaterial.new()
	mt.shader = preload("res://shaders/beast_head.gdshader")
	Look.register(mt)
	var look: Dictionary = data().get("look", {})
	mt.set_shader_parameter("near_m", float(look.get("near_m", 4.0)))
	mt.set_shader_parameter("gone_m", float(look.get("gone_m", 8.0)))
	var m := mesh(animal) if animal != "" else null
	var fur: Color = m.get_meta("fur") if m != null else Color(0.45, 0.4, 0.35)
	mt.set_shader_parameter("fur_color", fur.srgb_to_linear())
	_mats[animal] = mt
	return mt


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
	_bounds = {}
	var tris := _shape(st, animal, fur, muz, acc)
	var m: ArrayMesh
	if Prelit.on():
		# Pre-lit (design §ES.2): the head's own occlusion (inside the ears,
		# under the jaw, round the eyes) baked into its colours, toward navy.
		m = ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Prelit.bake(st.commit_to_arrays(), 18, 4))
	else:
		m = st.commit()
	m.set_meta("tris", tris)
	m.set_meta("parts", _bounds.duplicate())
	m.set_meta("fur", fur)
	_meshes[animal] = m
	return m


# --- The fit (design 6 Oct §EQ; data/beast_head_fit.json) --------------------------

static var _fits := {}

## The hood's brim in Head space (PlayerBody.HOOD_RINGS' lip; its top
## overhangs about 3 cm further forward).
const BRIM_Z := -0.13
const BRIM_OVERHANG := 0.035
## The hood's hollow: half its width round the middle (for the cowl's
## stretch round a bigger skull).
const HOLLOW_HALF_W := 0.096
## The cowl stretches round a bigger skull at most this much, and tilts
## back off the crown by this much (radians, round the neck).
const COWL_K_MAX := 1.25
const COWL_TILT := 0.45


## The fit numbers for `animal`: beast_head_fit.json heads.<animal> over
## its defaults.
static func fit_numbers(animal: String) -> Dictionary:
	var F: Dictionary = Tuning.table("beast_head_fit")
	var out: Dictionary = (F.get("defaults", {}) as Dictionary).duplicate()
	out.merge((F.get("heads", {}) as Dictionary).get(animal, {}), true)
	return out


## How `animal`'s head and the cowl sit (Head-pivot space; built once):
##   head: the Beast node's transform: scaled by `scale` round the skull's
##     middle, forward by forward_m (more if muzzle_out of the head's
##     length is not yet past the brim) and down by drop_m;
##   cowl: the hood's transform on a beast folk: stretched round the
##     bigger skull, its brim slid back by cowl_back_m and further if need
##     be, so every through_hood part stands in front of it;
##   aabb: the head's bounds as it sits; length: its length (z);
##   out: how far past the brim its muzzle reaches.
static func fit(animal: String) -> Dictionary:
	if _fits.has(animal):
		return _fits[animal]
	var m := mesh(animal)
	if m == null:
		return {}
	var f := fit_numbers(animal)
	var sc := float(f.get("scale", 1.4))
	var a := m.get_aabb()
	var length := a.size.z * sc
	var c := HEAD_C
	# Forward: at least forward_m; enough that muzzle_out of the length is
	# past the brim.
	var zmin_scaled := c.z + (a.position.z - c.z) * sc
	var need := zmin_scaled - BRIM_Z + float(f.get("muzzle_out", 0.5)) * length
	var fwd := maxf(float(f.get("forward_m", 0.05)), need)
	var drop := float(f.get("drop_m", 0.0))
	var head_xf := Transform3D(Basis.IDENTITY, c + Vector3(0, -drop, -fwd)) * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -c)
	var aabb: AABB = head_xf * a
	# The cowl, like a hood pushed back (§EQ: the goat of reference frame
	# 3): wide enough for the skull (at most COWL_K_MAX), its brim behind
	# the skull's middle by at least a third of its depth, behind every
	# through_hood part, and back by cowl_back_m from the hood's own, then
	# tilted back off the crown (COWL_TILT) to drape on the shoulders.
	var parts: Dictionary = m.get_meta("parts", {})
	var skull: AABB = head_xf * (parts.get("skull", a) as AABB)
	var k := clampf((skull.size.x * 0.5 * 1.05) / HOLLOW_HALF_W, 1.0, COWL_K_MAX)
	var brim := maxf(BRIM_Z + float(f.get("cowl_back_m", 0.05)), skull.get_center().z + skull.size.z * 0.5 * 0.33)
	var through: Array = f.get("through_hood", [])
	for t in through:
		if parts.has(t):
			var pb: AABB = head_xf * (parts[t] as AABB)
			brim = maxf(brim, pb.end.z + BRIM_OVERHANG * k + 0.01)
	# Never further back than the skull's own back.
	brim = minf(brim, skull.end.z - 0.02)
	var pivot := Vector3(0, 0.0, BRIM_Z)
	var cowl_xf := Transform3D(Basis(Vector3.RIGHT, COWL_TILT), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, -0.01, brim - BRIM_Z)) * Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis.IDENTITY.scaled(Vector3(k, minf(k, 1.12), k)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	var out := {"head": head_xf, "cowl": cowl_xf, "aabb": aabb, "length": length, "out": BRIM_Z - aabb.position.z,
		"brim": brim, "scale": sc, "forward": fwd, "cowl_k": k, "through": through}
	_fits[animal] = out
	return out


## The part being built (_shape): each primitive's bounds go under it, so
## the fit can keep through_hood parts in front of the cowl's brim.
static var _tag := "skull"
static var _bounds := {}


static func _part(tag: String) -> void:
	_tag = tag


static func _grow(lo: Vector3, hi: Vector3) -> void:
	var box := AABB(lo, hi - lo)
	_bounds[_tag] = (_bounds[_tag] as AABB).merge(box) if _bounds.has(_tag) else box


## The parts of each head, tagged (skull, muzzle, face; and the
## through_hood vocabulary of beast_head_fit.json: ears, horns, whiskers,
## ruff, frills, forelock, beard, comb, wattles, tusks). Ears and horns
## stand in their real pose (§EQ.1: never folded under the hood).
## Returns its triangle count.
static func _shape(st: SurfaceTool, a: String, fur: Color, muz: Color, acc: Color) -> int:
	var n := 0
	var eye := Color(0.86, 0.7, 0.3)
	var dark := Color(0.08, 0.07, 0.07)
	var ivory := Color(0.9, 0.86, 0.74)
	var c := HEAD_C
	_part("skull")
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
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.012, -0.05), c + Vector3(0, -0.022, -0.165), 0.036, 0.012, fur)
			_part("face")
			n += _ball(st, c + Vector3(0, -0.022, -0.168), Vector3(0.013, 0.012, 0.012), acc)
			for s in [-1.0, 1.0]:
				_part("ears")
				n += _ball(st, c + Vector3(s * 0.048, 0.072, -0.012), Vector3(0.03, 0.03, 0.008), acc.lerp(fur, 0.5))
				_part("whiskers")
				n += _cone(st, c + Vector3(s * 0.018, -0.02, -0.14), c + Vector3(s * 0.085, -0.012, -0.15), 0.003, 0.0, dark)
		"ox":
			_part("muzzle")
			n += _ball(st, c + Vector3(0, -0.035, -0.095), Vector3(0.058, 0.045, 0.055), muz)
			for s in [-1.0, 1.0]:
				_part("face")
				n += _ball(st, c + Vector3(s * 0.02, -0.04, -0.148), Vector3(0.01, 0.01, 0.006), dark)
				_part("horns")
				n += _cone(st, c + Vector3(s * 0.058, 0.05, -0.035), c + Vector3(s * 0.135, 0.09, -0.07), 0.018, 0.004, acc)
				_part("ears")
				n += _ball(st, c + Vector3(s * 0.085, 0.015, -0.025), Vector3(0.032, 0.012, 0.017), fur.darkened(0.1))
			eye_x = 0.042
		"tiger":
			_part("muzzle")
			n += _ball(st, c + Vector3(0, -0.03, -0.085), Vector3(0.045, 0.034, 0.04), muz)
			_part("face")
			n += _ball(st, c + Vector3(0, -0.018, -0.124), Vector3(0.012, 0.009, 0.006), acc)
			for i in 3:
				n += _ball(st, c + Vector3((i - 1) * 0.022, 0.06, -0.06), Vector3(0.006, 0.02, 0.006), acc)
			for s in [-1.0, 1.0]:
				_part("face")
				n += _ball(st, c + Vector3(s * 0.055, 0.0, -0.065), Vector3(0.022, 0.006, 0.006), acc)
				_part("ears")
				n += _ball(st, c + Vector3(s * 0.05, 0.072, -0.02), Vector3(0.024, 0.024, 0.008), fur)
				_part("ruff")
				n += _ball(st, c + Vector3(s * 0.065, -0.03, -0.035), Vector3(0.035, 0.03, 0.028), muz)
		"rabbit":
			_part("muzzle")
			n += _ball(st, c + Vector3(0, -0.032, -0.075), Vector3(0.04, 0.034, 0.038), muz)
			_part("face")
			n += _ball(st, c + Vector3(0, -0.02, -0.112), Vector3(0.01, 0.008, 0.006), acc)
			# The ears stand up (§EQ: never laid back under the hood).
			_part("ears")
			for s in [-1.0, 1.0]:
				n += _cone(st, c + Vector3(s * 0.026, 0.06, -0.025), c + Vector3(s * 0.045, 0.205, -0.005), 0.021, 0.013, fur)
			eye_x = 0.04
		"dragon":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.012, -0.05), c + Vector3(0, -0.026, -0.18), 0.045, 0.026, muz)
			for s in [-1.0, 1.0]:
				_part("face")
				n += _ball(st, c + Vector3(s * 0.016, -0.014, -0.175), Vector3(0.007, 0.006, 0.006), dark)
				_part("horns")
				n += _cone(st, c + Vector3(s * 0.04, 0.05, -0.04), c + Vector3(s * 0.07, 0.12, -0.015), 0.013, 0.003, acc)
				_part("whiskers")
				n += _cone(st, c + Vector3(s * 0.035, -0.04, -0.12), c + Vector3(s * 0.055, -0.09, -0.15), 0.006, 0.002, acc)
				_part("frills")
				n += _ball(st, c + Vector3(s * 0.075, 0.0, -0.025), Vector3(0.008, 0.045, 0.03), acc.darkened(0.15))
			_part("skull")
			n += _ball(st, c + Vector3(0, 0.035, -0.07), Vector3(0.05, 0.012, 0.03), fur.darkened(0.2))
		"snake":
			_part("muzzle")
			n += _ball(st, c + Vector3(0, -0.02, -0.105), Vector3(0.045, 0.026, 0.045), muz)
			eye_x = 0.05
			eye_z = -0.085
			eye_y = c.y + 0.012
		"horse":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.005, -0.04), c + Vector3(0, -0.045, -0.155), 0.048, 0.036, fur)
			n += _ball(st, c + Vector3(0, -0.05, -0.155), Vector3(0.038, 0.03, 0.022), muz)
			_part("face")
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.015, -0.045, -0.175), Vector3(0.007, 0.007, 0.004), acc)
			_part("ears")
			for s in [-1.0, 1.0]:
				n += _cone(st, c + Vector3(s * 0.032, 0.07, -0.025), c + Vector3(s * 0.04, 0.13, -0.03), 0.015, 0.003, fur)
			_part("forelock")
			n += _cone(st, c + Vector3(0, 0.075, -0.03), c + Vector3(0, 0.035, -0.1), 0.02, 0.006, acc)
		"goat":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.01, -0.05), c + Vector3(0, -0.035, -0.15), 0.04, 0.024, muz)
			_part("beard")
			n += _cone(st, c + Vector3(0, -0.06, -0.1), c + Vector3(0, -0.12, -0.11), 0.016, 0.003, muz)
			for s in [-1.0, 1.0]:
				_part("horns")
				n += _cone(st, c + Vector3(s * 0.032, 0.06, -0.045), c + Vector3(s * 0.058, 0.125, -0.02), 0.014, 0.004, acc)
				_part("ears")
				n += _ball(st, c + Vector3(s * 0.08, 0.025, -0.035), Vector3(0.036, 0.01, 0.015), muz)
		"monkey":
			_part("face")
			n += _ball(st, c + Vector3(0, -0.01, -0.07), Vector3(0.052, 0.058, 0.026), muz)
			_part("muzzle")
			n += _ball(st, c + Vector3(0, -0.04, -0.09), Vector3(0.03, 0.02, 0.016), muz.darkened(0.1))
			_part("ears")
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.082, 0.0, -0.02), Vector3(0.012, 0.026, 0.022), muz.darkened(0.15))
			eye_z = -0.09
			eye_x = 0.022
			eye_y = c.y + 0.012
		"rooster":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.005, -0.065), c + Vector3(0, -0.02, -0.135), 0.018, 0.0, muz)
			_part("comb")
			for i in 3:
				n += _ball(st, c + Vector3(0, 0.075 - i * 0.006, -0.03 - i * 0.025), Vector3(0.007, 0.02, 0.012), acc)
			_part("wattles")
			n += _ball(st, c + Vector3(0, -0.045, -0.085), Vector3(0.009, 0.02, 0.01), acc)
		"dog":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.015, -0.05), c + Vector3(0, -0.025, -0.15), 0.038, 0.022, muz)
			_part("face")
			n += _ball(st, c + Vector3(0, -0.018, -0.152), Vector3(0.014, 0.011, 0.01), acc)
			_part("ears")
			for s in [-1.0, 1.0]:
				n += _ball(st, c + Vector3(s * 0.066, 0.005, -0.03), Vector3(0.012, 0.042, 0.026), fur.darkened(0.2))
		"pig":
			_part("muzzle")
			n += _cone(st, c + Vector3(0, -0.025, -0.06), c + Vector3(0, -0.025, -0.14), 0.034, 0.03, muz)
			_part("face")
			n += _ball(st, c + Vector3(0, -0.025, -0.142), Vector3(0.032, 0.026, 0.006), acc)
			for s in [-1.0, 1.0]:
				_part("face")
				n += _ball(st, c + Vector3(s * 0.012, -0.025, -0.148), Vector3(0.006, 0.008, 0.004), dark)
				_part("ears")
				n += _cone(st, c + Vector3(s * 0.05, 0.05, -0.04), c + Vector3(s * 0.075, 0.07, -0.095), 0.018, 0.004, fur)
				_part("tusks")
				n += _cone(st, c + Vector3(s * 0.026, -0.045, -0.12), c + Vector3(s * 0.034, -0.015, -0.128), 0.006, 0.0, ivory)
	_part("face")
	for s in [-1.0, 1.0]:
		n += _ball(st, Vector3(s * eye_x, eye_y, eye_z), Vector3(0.011, 0.011, 0.008), eye)
		n += _ball(st, Vector3(s * eye_x, eye_y, eye_z - 0.007), Vector3(0.005, 0.007, 0.003), dark)
	return n


static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


## A low-poly ellipsoid at `c`, radii `r`.
static func _ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> int:
	# (10 x 6 until design 6 Oct §ES.2: the head is a few pixels across at
	# 270 lines; 8 x 5 keeps it round.)
	var seg := 8
	var rings := 5
	var lc := _lin(col)
	_grow(c - r, c + r)
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
	var seg := 6 # (8 before §ES.2)
	var lc := _lin(col)
	var rr := Vector3.ONE * maxf(ra, rb)
	_grow((a.min(b)) - rr, (a.max(b)) + rr)
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

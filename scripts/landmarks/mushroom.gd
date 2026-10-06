class_name Mushroom
## The mushroom (design 5 Oct §EO.4: "the engine has no mushroom shape
## yet; a ring needs one"). A few flat-shaded parts in Workshop.Build,
## the ruin material at 16 texels a metre (so a cap is a couple of big
## texels across), matte, no shine (LOOK R1–R10): a short stem, a domed
## cap in two tiers, and a dark gill ring under it. A clean silhouette:
## no frills, no spots. Cheap: about 60 triangles a mushroom, a whole
## ring one mesh.

## Add one mushroom to `b` standing at `at` (b's frame, `up` its up),
## `h` tall, cap `cap`, stem `stem`, gills `gill` (sRGB), leaning a
## little by `rng`.
static func add(b: Workshop.Build, at: Vector3, up: Vector3, h: float, cap: Color, stem: Color, gill: Color, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var u := (up + lean).normalized()
	var stem_h := h * 0.62
	var stem_r := h * 0.11
	var cap_r := h * rng.randf_range(0.36, 0.46)
	var top := at + u * stem_h
	# The stem, a little thicker at the foot.
	b.beam(at - u * 0.01, top, _across(u), stem_r * 2.0, stem_r * 2.0, stem, Workshop.HIDE)
	# The cap: a wide low frustum, then a dome on it.
	_frustum(b, top - u * h * 0.04, u, cap_r, cap_r * 0.72, h * 0.16, 7, cap, Workshop.HIDE)
	_frustum(b, top + u * h * 0.12, u, cap_r * 0.72, 0.0, h * 0.2, 7, cap.lightened(0.06), Workshop.HIDE)
	# The gills under the brim.
	_frustum(b, top - u * h * 0.045, u, cap_r * 0.98, stem_r * 1.1, 0.0, 7, gill, Workshop.HIDE)


static func _across(u: Vector3) -> Vector3:
	return u.cross(Vector3.FORWARD if absf(u.z) < 0.9 else Vector3.RIGHT).normalized()


## A frustum round `u` from `base` (radius r0) up `h` (radius r1), both
## windings, `sides` sides.
static func _frustum(b: Workshop.Build, base: Vector3, u: Vector3, r0: float, r1: float, h: float, sides: int, col: Color, kind: int) -> void:
	var x := _across(u)
	var z := x.cross(u).normalized()
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var o0 := x * cos(a0) + z * sin(a0)
		var o1 := x * cos(a1) + z * sin(a1)
		var p0 := base + o0 * r0
		var p1 := base + o1 * r0
		var q0 := base + u * h + o0 * r1
		var q1 := base + u * h + o1 * r1
		var mid := (o0 + o1).normalized()
		var nrm := (mid * maxf(h, 0.001) + u * (r0 - r1)).normalized() if h > 0.0 else -u
		b.tri(p0, q0, p1, nrm, col, kind)
		b.tri(p0, p1, q0, -nrm, col, kind)
		if r1 > 0.0:
			b.tri(p1, q0, q1, nrm, col, kind)
			b.tri(p1, q1, q0, -nrm, col, kind)

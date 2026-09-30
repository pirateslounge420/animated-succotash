class_name AroidMeshes
## The unit meshes of an Amorphophallus' passing parts (AroidGarden): each 1
## tall along +Y from its base, 1 in radius (the instance scales them), low
## poly with smooth normals (the GameCube look), UV.x 1 on a spathe's inner
## surface (shaders/aroid_part.gdshader). Built once, shared.

const SIDES := 10
static var _cache := {}


static func get_mesh(kind: String) -> Mesh:
	if not _cache.has(kind):
		match kind:
			"spike":
				_cache[kind] = _lathe([[0.0, 1.0], [0.25, 0.9], [0.6, 0.6], [0.85, 0.3], [1.0, 0.0]], false)
			"bud":
				_cache[kind] = _lathe([[0.0, 0.35], [0.12, 0.8], [0.35, 1.0], [0.62, 0.95], [0.85, 0.65], [1.0, 0.0]], false)
			"peduncle":
				_cache[kind] = _lathe([[0.0, 1.0], [1.0, 0.9]], true)
			"spathe":
				_cache[kind] = _spathe()
			"appendix":
				# The spadix's appendix: a thick pointed column, fattest a
				# little up from its foot (the titan arum's 3 m spike).
				_cache[kind] = _lathe([[0.0, 0.85], [0.12, 1.0], [0.45, 0.88], [0.75, 0.6], [0.93, 0.28], [1.0, 0.0]], false)
			"pollen":
				_cache[kind] = _lathe([[0.0, 1.0], [1.0, 1.0]], true)
			"berries":
				_cache[kind] = _berries()
			_:
				_cache[kind] = _lathe([[0.0, 1.0], [1.0, 0.0]], false)
	return _cache[kind]


## A surface of revolution: `profile` [[y, radius]...] bottom to top.
## `open`: no caps.
static func _lathe(profile: Array, open: bool, inner := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_lathe(st, profile, inner, false)
	if not open and float(profile[0][1]) > 0.0:
		# A cap at the bottom.
		var y0 := float(profile[0][0])
		var r0 := float(profile[0][1])
		for s in SIDES:
			var a0 := TAU * s / SIDES
			var a1 := TAU * (s + 1) / SIDES
			st.set_normal(Vector3.DOWN)
			st.set_uv(Vector2(inner, 0))
			st.add_vertex(Vector3(0, y0, 0))
			st.add_vertex(Vector3(cos(a1) * r0, y0, sin(a1) * r0))
			st.add_vertex(Vector3(cos(a0) * r0, y0, sin(a0) * r0))
	return st.commit()


static func _add_lathe(st: SurfaceTool, profile: Array, uvx: float, inward: bool) -> void:
	for i in profile.size() - 1:
		var y0 := float(profile[i][0])
		var r0 := float(profile[i][1])
		var y1 := float(profile[i + 1][0])
		var r1 := float(profile[i + 1][1])
		var slope := Vector2(r0 - r1, y1 - y0).normalized()
		for s in SIDES:
			var a0 := TAU * s / SIDES
			var a1 := TAU * (s + 1) / SIDES
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 * slope.y + Vector3.UP * slope.x).normalized()
			var n1 := (d1 * slope.y + Vector3.UP * slope.x).normalized()
			if inward:
				n0 = -n0
				n1 = -n1
			var p00 := d0 * r0 + Vector3.UP * y0
			var p01 := d1 * r0 + Vector3.UP * y0
			var p10 := d0 * r1 + Vector3.UP * y1
			var p11 := d1 * r1 + Vector3.UP * y1
			var tri := [[p00, n0], [p10, n0], [p11, n1], [p00, n0], [p11, n1], [p01, n1]]
			if inward:
				tri = [[p00, n0], [p11, n1], [p10, n0], [p00, n0], [p01, n1], [p11, n1]]
			for v in tri:
				st.set_normal(v[1])
				st.set_uv(Vector2(uvx, (v[0] as Vector3).y))
				st.add_vertex(v[0])


## The spathe: a funnel flaring to its limb, open on one side at the top
## (a gentle slant), with an inner surface a little inside (UV.x 1: the
## inside colour).
static func _spathe() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A pleated bell (the titan arum: from reference photos, a narrow
	# green neck, a wide fluted flare and a frilled rim rolled back past
	# the vertical), the inside the second colour.
	var outer := [[0.0, 0.28], [0.12, 0.34], [0.35, 0.5], [0.6, 0.76], [0.8, 1.02], [0.92, 1.24], [1.0, 1.42], [1.03, 1.5], [1.0, 1.55]]
	var inner := [[0.02, 0.24], [0.12, 0.3], [0.35, 0.45], [0.6, 0.7], [0.8, 0.95], [0.92, 1.17], [1.0, 1.36], [1.03, 1.44], [1.005, 1.49]]
	# The spathe is a rolled sheet, not a bowl (reference photo): it wraps
	# round a little more than once, the outer edge a flap lying over the
	# inner one down the side, closed at the neck and rolling open toward
	# the rim, where it unfurls into the frill. The rim itself wavers.
	_add_pleated(st, outer, 0.0, false, 64, 16, 0.1, 0.75, 0.7, 0.3)
	_add_pleated(st, inner, 1.0, true, 64, 16, 0.1, 0.75, 0.7, 0.3)
	var mesh := st.commit()
	return mesh


## A lathe with `pleats` ridges round it: the radius swells by `depth`
## (a share) on the ridges, more toward the top (the frilled rim).
## `seam_at` (radians round): the sheet starts there and wraps `overlap`
## radians past a full turn; the flap past the turn lies over the start,
## `open_from` (height) up rolling outward, wide open at the rim. The rim
## wavers (a torn, wavy edge).
static func _add_pleated(st: SurfaceTool, profile: Array, uvx: float, inward: bool, sides_n: int, pleats: int, depth: float, seam_at := 0.0, overlap := 0.0, open_from := 1.0) -> void:
	var ymax := 0.0
	for pr in profile:
		ymax = maxf(ymax, float(pr[0]))
	var extra := int(ceil(overlap / TAU * sides_n))
	var pt := func(i: int, s: int) -> Vector3:
		var y := float(profile[i][0])
		var r := float(profile[i][1])
		var a := seam_at + TAU * s / sides_n
		var k := depth * (0.3 + 0.7 * y / maxf(ymax, 1e-3))
		var rr := r * (1.0 + k * cos(a * pleats))
		var open := clampf((y - open_from) / maxf(ymax - open_from, 1e-3), 0.0, 1.0)
		if s > sides_n:
			# The flap: over the start of the sheet, rolling out as it opens.
			var f := float(s - sides_n) / maxf(extra, 1)
			rr *= 1.05 + (0.12 + 0.55 * f) * open * open
		elif s < extra:
			# The inner edge tucks in under the flap.
			var f := 1.0 - float(s) / maxf(extra, 1)
			rr *= 1.0 - 0.06 * f * (1.0 - 0.5 * open)
		# A wavy rim.
		if y > ymax * 0.9:
			var w := sin(a * 7.0 + 1.3) * 0.5 + sin(a * 11.0) * 0.5
			rr *= 1.0 + 0.05 * w * (y - ymax * 0.9) / (ymax * 0.1)
		return Vector3(cos(a) * rr, y, sin(a) * rr)
	for i in profile.size() - 1:
		for s in sides_n + extra:
			var p00: Vector3 = pt.call(i, s)
			var p01: Vector3 = pt.call(i, s + 1)
			var p10: Vector3 = pt.call(i + 1, s)
			var p11: Vector3 = pt.call(i + 1, s + 1)
			var nrm := (p10 - p00).cross(p01 - p00).normalized()
			if nrm.length() < 0.5:
				nrm = Vector3.UP
			if inward:
				nrm = -nrm
			var tri := [p00, p10, p11, p00, p11, p01] if not inward else [p00, p11, p10, p00, p01, p11]
			for v in tri:
				st.set_normal(nrm)
				st.set_uv(Vector2(uvx, v.y))
				st.add_vertex(v)


## An infructescence: rows of berries round a column (octahedra, each
## shaded round in the shader).
static func _berries() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 7
	var per := 7
	var r := 0.3
	for row in rows:
		var y := (float(row) + 0.5) / rows
		for k in per:
			var a := TAU * (float(k) + (0.5 if row % 2 == 1 else 0.0)) / per
			var c := Vector3(cos(a) * 0.75, y, sin(a) * 0.75)
			var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
			var faces := [[0, 2, 4], [0, 5, 2], [0, 4, 3], [0, 3, 5], [1, 4, 2], [1, 2, 5], [1, 3, 4], [1, 5, 3]]
			for f in faces:
				for idx in f:
					var dv: Vector3 = dirs[idx]
					st.set_normal(dv)
					st.set_uv(Vector2(0, y))
					st.add_vertex(c + Vector3(dv.x * r, dv.y * r / rows * 2.2, dv.z * r))
	return st.commit()

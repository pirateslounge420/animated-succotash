class_name NestBuilder
extends RuinBuilder
## The nests' set pieces (design 1 Oct §CK roof_rule: the ground is a
## heightfield and cannot overhang, so anything with a roof is a mesh on
## the terrain). Built with RuinBuilder's rock, collision and far LOD, into
## the same node (RuinBuilder.make_node), by Landmarks:
##   cave_mouth   a rock roof 3-6.5 m up overhanging the cliff foot, side
##                walls closing a first chamber, a dark low passage at the
##                back (the cave behind is Phase 3), wet stones along the
##                drip line;
##   grotto       RuinBuilder's barrow passage in raw rock: a rock mound
##                out from the cliff, a low arched mouth, a dry floor just
##                inside, the passage narrowing back to a chamber with its
##                drip pool and a faint glow;
##   escarpment   an overhang slab and two boulders at the foot; on open
##                grass the buffalo jump: cairn lanes on the plateau
##                narrowing to the lip;
##   cenote       the undercut lip round the shaft (rock slabs leaning in
##                over the drop) and fallen blocks down the slope;
##   slot_canyon  drift logs jammed across the slot near the top;
##   columnar_basalt (design 3 Oct §DX) hexagonal columns of basalt
##                (_hex_field): the causeway's stepped floor of tops going
##                down into the sea with water in its cups, a cliff of tall
##                columns at its landward edge; the organ pipes' cliff on a
##                river bank with a fall over it into a pool; the sea cave's
##                headland of columns, the cave through it with a roof of
##                column undersides and a ledge of broken stumps, the boom
##                of the swell at its back (Landmarks plays it);
## and a spring's pool (escarpment foot, a ravine's widening, a cave mouth
## on an escarpment face) and a blue hole's dark water (pools, make_node).
## Local frame: origin at the nest's feature, -z out of the rock (or along
## a cenote's slope), +z into it.

var nest: Dictionary
## Water discs [local center, radius, dark] added by make_nest().
var _pools: Array = []
## Columnar basalt (§DX): a fall's roar [local, size], the sea cave's boom
## and its den (local, INF none), the cups holding water, the columns.
var _roar: Array = []
var _boom := Vector3.INF
var _den := Vector3.INF
var _cups := 0
var _columns := 0
var _no_cups := false
## Column sides below this (local y) are not drawn: deep under the sea.
var _clip_y := -INF


static func compute_nest(p_map: PlanetData, p_nest: Dictionary) -> Dictionary:
	var b := NestBuilder.new()
	b.map = p_map
	b.nest = p_nest
	b.site = p_nest
	b.rng.seed = int(p_nest.seed)
	b.up = p_nest.dir
	var heading := float(p_nest.get("facing", 0.0)) + PI
	match str(p_nest.kind):
		"cenote":
			heading = float(p_nest.get("ramp", 0.0))
		"slot_canyon", "ravine", "waterfall", "bioluminescent_bay":
			heading = float(p_nest.get("facing", 0.0))
		"columnar_basalt":
			# -z into the land (the rock), +z out to the water.
			heading = float(p_nest.get("toward", 0.0))
	b.site = p_nest.duplicate()
	b.site.heading = heading
	var a: float = heading + PI * 0.5
	b.ex = CubeSphere.north(b.up) * cos(a) + CubeSphere.east(b.up) * sin(a)
	b.ez = b.ex.cross(b.up).normalized()
	b.base_e = p_map.terrain.elevation(b.up, true)
	b.wet = smoothstep(0.2, 0.8, p_map.sample(p_map.moisture, b.up))
	var rock: int = p_map.rock[p_map.cell_at(b.up)]
	b.palette = RuinBuilder.SANDSTONE if rock == PlanetData.Rock.SANDSTONE else (RuinBuilder.LIMESTONE if rock == PlanetData.Rock.LIMESTONE_KARST else RuinBuilder.STONES)
	match str(p_nest.kind):
		"cave_mouth":
			b._cave_mouth()
		"grotto":
			b._grotto()
		"escarpment":
			if str(p_nest.variant) == "buffalo_jump":
				b._buffalo_jump()
			else:
				b._overhang_slab()
		"cenote":
			if str(p_nest.variant) == "":
				b._cenote_lip()
			elif str(p_nest.variant) == "blue_hole":
				b._pools.append([Vector3(0.0, -b.base_e + PlanetConst.SEA_LEVEL_M + 0.03, 0.0), float(p_nest.radius_m), true])
		"slot_canyon":
			b._drift_logs()
		"columnar_basalt":
			match str(p_nest.variant):
				"organ_pipes":
					b._organ_pipes()
				"columned_sea_cave":
					b._sea_cave()
				_:
					b._causeway()
	if p_nest.has("spring"):
		b._spring(p_nest.spring)
	return {"site": b.site, "v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch,
		"lv": b._lv, "ln": b._ln, "lc": b._lc, "lm": b._lm, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e,
		"shelters": b._shelters, "camp_spot": Vector3.ZERO, "lights": b._lights, "vine_anchors": b._vine_anchors,
		"boulder_anchors": b._boulder_anchors, "pools": b._pools, "nest": p_nest,
		"water": {"v": b._wv, "uv": b._wuv, "uv2": b._wuv2}, "falls": {"v": b._fv, "n": b._fn, "uv": b._fuv, "uv2": b._fuv2},
		"roar": b._roar, "boom": b._boom, "den": b._den, "cups": b._cups, "columns": b._columns}


## Main thread: the node (RuinBuilder.make_node) with its pools.
static func make_nest(data: Dictionary, world: Node) -> Node3D:
	var root := RuinBuilder.make_node(data, world)
	var nest: Dictionary = data.nest
	root.name = Nests.name_of(nest).replace(" ", "").replace("/", "")
	root.set_meta("nest", nest)
	for p in data.get("pools", []):
		root.add_child(_pool_disc(p[0], p[1], p[2]))
	# The organ pipes' fall roars at its pool, as a river's falls do
	# (TerrainChunk, audio.json "waterfall").
	var roar: Array = data.get("roar", [])
	if not roar.is_empty():
		var rp := Audio3D.make("waterfall", root, "Roar")
		rp.stream = SoundSynth.stream("waterfall_loop", posmod(int(nest.seed), SoundSynth.VARIANTS))
		rp.position = roar[0]
		rp.volume_db = linear_to_db(float(roar[1]))
		rp.autoplay = true
	# The sea cave's boom and its den: Landmarks plays the one and lays the
	# other's sleeper by day (§BG, §CH).
	if (data.get("boom", Vector3.INF) as Vector3) != Vector3.INF:
		root.set_meta("boom", data.boom)
	if (data.get("den", Vector3.INF) as Vector3) != Vector3.INF:
		root.set_meta("den", data.den)
	return root


## A round pool of standing water (fresh water's material), or a blue
## hole's dark water over the reef (`dark`).
static func _pool_disc(c: Vector3, r: float, dark: bool) -> MeshInstance3D:
	var n := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		for v in [Vector3.ZERO, Vector3(cos(a1), 0.0, sin(a1)) * r, Vector3(cos(a0), 0.0, sin(a0)) * r]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(c.x + v.x, c.z + v.z))
			st.set_uv2(Vector2.ZERO)
			st.set_color(Color(0.03, 0.08, 0.32, 0.75 if v == Vector3.ZERO else 0.0))
			st.add_vertex(c + v)
	var mi := MeshInstance3D.new()
	mi.name = "BlueHole" if dark else "Pool"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if dark:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
	else:
		mi.material_override = TerrainChunk.water_materials()[1]
	return mi


## Local (x, y on the ground, z) of a surface direction.
func _local(d: Vector3) -> Vector3:
	var off := (d - up * d.dot(up)) * PlanetConst.RADIUS_M
	var x := off.dot(ex)
	var z := off.dot(ez)
	return Vector3(x, ground(x, z), z)


## A rock mass (a boulder in the site's stone), its foot shaded.
func _rock(center: Vector3, radii: Vector3, basis: Basis, darker := 0.0, moss := 0.3) -> void:
	var col: Color = (palette[rng.randi() % palette.size()] as Color).darkened(darker + rng.randf_range(0.0, 0.08))
	var was := foot_y
	foot_y = ground(center.x, center.z)
	boulder(center, radii, basis, col, _growth(moss))
	foot_y = was


## A cave mouth: the roof overhanging the foot, side walls closing the
## first chamber, the dark passage at the back, the drip line.
func _cave_mouth() -> void:
	var w: float = nest.get("width_m", 12.0)
	var over: float = nest.get("overhang_m", 7.0)
	var roof: float = nest.get("roof_m", 4.5)
	var g0 := ground(0.0, -over * 0.5)
	# The roof: two or three great slabs, their underside smoke-black near
	# the lip, set back into the face.
	var n := 2 if w < 16.0 else 3
	for i in n:
		var x := -w * 0.5 + w * (i + 0.5) / n + rng.randf_range(-0.6, 0.6)
		var depth := over + 2.5 + rng.randf_range(-0.8, 0.8)
		var c := Vector3(x, g0 + roof + 1.1 + rng.randf_range(-0.3, 0.3), 1.5 - depth * 0.5)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.12, -0.02), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.06, 0.06)))
		_rock(c, Vector3(w / n * 0.62, 1.2, depth * 0.5), basis, 0.12, 0.5)
	# The side walls of the first chamber.
	for sx: float in [-1.0, 1.0]:
		var x2 := sx * (w * 0.5 + 0.6)
		for k in 2:
			var z := -over * (0.25 + 0.4 * k)
			var gy := ground(x2, z)
			var hh := (roof + 1.0) * 0.5
			_rock(Vector3(x2, gy + hh - 0.4, z), Vector3(1.6 + rng.randf() * 0.6, hh + 0.3, over * 0.28 + 0.6), Basis.from_euler(Vector3(0.0, rng.randf_range(-0.3, 0.3), 0.0)), 0.05)
	# The low dark passage at the back (Phase 3 digs the cave behind it).
	var was := shade
	shade = 0.85
	solid = false
	box(Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-w * 0.2, w * 0.2), ground(0.0, -0.4) + 0.75, -0.35)), Vector3(2.2, 1.5, 0.25), Color(0.05, 0.05, 0.06), 0.0, 0.3, 0.1)
	solid = true
	shade = was
	# The drip line: wet stones where the rain falls off the lip.
	for k in 7:
		var x3 := -w * 0.45 + w * 0.9 * k / 6.0 + rng.randf_range(-0.5, 0.5)
		var z3 := -over + rng.randf_range(-0.4, 0.4)
		var s := Vector3(rng.randf_range(0.3, 0.6), rng.randf_range(0.2, 0.35), rng.randf_range(0.3, 0.5))
		_rock(Vector3(x3, ground(x3, z3) + s.y * 0.3, z3), s, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), 0.2, 0.8)
	_shelters.append([Vector3(0.0, g0, -over * 0.5), minf(w * 0.5, over * 0.55), roof])
	# The soot the hearth's smoke has left over the mouth (§CV.2), whether
	# the fire is lit or not.
	_soot(0.0, g0 + roof - 0.1, 1.5 - (over + 2.5) - 0.05, w * 0.55)


## Soot above a nest's mouth (design 3 Oct §CV.2, smoke.json outlets.soot):
## a navy-black streak streak_m tall on the rock face at `z_face`, from
## `y0` up, `width` wide, its middle at `x`. It stays when the fire is out.
func _soot(x: float, y0: float, z_face: float, width: float) -> void:
	var sd: Dictionary = (Smoke.D.get("outlets", {}) as Dictionary).get("soot", {})
	var hs := float(sd.get("streak_m", 1.2))
	var was_shade := shade
	var was_solid := solid
	shade = 0.0
	solid = false
	box(Transform3D(Basis.IDENTITY, Vector3(x, y0 + hs * 0.5, z_face)), Vector3(width, hs, 0.08), Color(str(sd.get("colour", "#0A0C20"))), 0.0, 0.02, 0.0)
	box(Transform3D(Basis.IDENTITY, Vector3(x, y0 + hs * 1.2, z_face - 0.01)), Vector3(width * 0.55, hs * 0.5, 0.08), Color(str(sd.get("colour", "#0A0C20"))).lightened(0.08), 0.0, 0.02, 0.0)
	shade = was_shade
	solid = was_solid


## An overhang at the escarpment foot: a great slab out from the face and
## a boulder either side (the old cliff shelter, Camps._overhang; its fire
## now a pace or two in from the drip line, Nests).
func _overhang_slab() -> void:
	var w: float = nest.get("width_m", 12.0)
	var over: float = nest.get("overhang_m", 6.0)
	var roof: float = nest.get("roof_m", 4.0)
	var g0 := ground(0.0, -over * 0.5)
	_rock(Vector3(0.0, g0 + roof + 1.0, 1.2 - (over + 1.2) * 0.5), Vector3(w * 0.5, 1.0, (over + 1.2) * 0.5), Basis.from_euler(Vector3(-0.08, 0.0, rng.randf_range(-0.05, 0.05))), 0.1, 0.5)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w * 0.5 + 0.4)
		var s := Vector3(rng.randf_range(1.2, 1.8), rng.randf_range(1.0, 1.5), rng.randf_range(1.0, 1.4))
		_rock(Vector3(x, ground(x, -over * 0.4) + s.y * 0.6, -over * 0.4), s, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)))
	_shelters.append([Vector3(0.0, g0, -over * 0.5), minf(w * 0.5, over * 0.5), roof])


## The buffalo jump: two lanes of small cairns on the plateau behind the
## lip, narrowing toward it (the drive lanes; the bone bed below is the
## remains, steppe folk's bone_bed).
func _buffalo_jump() -> void:
	for sx: float in [-1.0, 1.0]:
		for k in 7:
			var t := float(k) / 6.0
			var x := sx * lerpf(5.0, 34.0, t) + rng.randf_range(-1.0, 1.0)
			var z := lerpf(6.0, 80.0, t) + rng.randf_range(-2.0, 2.0)
			var g := ground(x, z)
			var h := 0.0
			for j in rng.randi_range(2, 3):
				var s := Vector3(0.45, 0.3, 0.4) * (1.0 - 0.2 * j)
				_rock(Vector3(x, g + h + s.y * 0.7, z), s, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), 0.0, 0.2)
				h += s.y * 1.3


## The grotto: a rock mound out from the cliff over a passage — the
## barrow's passage and chamber (RuinBuilder._barrow_passage) in raw rock.
## The mouth is at -z (passage_m from the cliff), the chamber and its pool
## at the back against the cliff.
func _grotto() -> void:
	var depth: float = nest.get("passage_m", 14.0)
	var mouth_w: float = nest.get("width_m", 4.5)
	var h := 6.5
	var w := mouth_w * 0.5 + 4.0
	var z_front := -depth
	var ph := rng.randf() * TAU
	var hf := func(x: float, z: float) -> float:
		var prof := pow(maxf(0.0, 1.0 - (x / w) * (x / w)), 0.55)
		# Lower at the front, where rock masses close it but for the mouth.
		var along := lerpf(0.62, 1.0, smoothstep(z_front, z_front + 5.0, z))
		return ground(x, z) - 1.0 + (h + 0.6 * sin(x * 1.1 + ph) * sin(z * 0.7 + ph)) * prof * along
	# The mound: bare rock, mossed on top where it's wet.
	var nx := 12
	var nz := 14
	var pts: Array[Vector3] = []
	for j in nz + 1:
		var z := z_front + (0.0 - z_front + 1.5) * j / nz
		for i in nx + 1:
			var x := -w + 2.0 * w * i / nx
			pts.append(Vector3(x, hf.call(x, z), z))
	var start := _v.size()
	mat = RuinBuilder.STONE_M
	for j in nz:
		for i in nx:
			var a := pts[j * (nx + 1) + i]
			var b := pts[j * (nx + 1) + i + 1]
			var c := pts[(j + 1) * (nx + 1) + i + 1]
			var d := pts[(j + 1) * (nx + 1) + i]
			var mid := (a + b + c + d) * 0.25
			var col: Color = (palette[(i + j) % palette.size()] as Color).darkened(0.05)
			col = col.lerp(MOSS, _growth(0.6) * smoothstep(0.4, 0.9, (b - a).cross(d - a).normalized().y))
			_face(a, b, c, d, col, mid - Vector3(0.0, 3.0, 0.0))
	_smooth_from(start)
	_collide_since(start)
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	# The front face round the mouth: rock masses either side, a lintel of
	# rock over it (the low arch).
	var mh := 2.8
	for sx: float in [-1.0, 1.0]:
		var x := sx * (mouth_w * 0.5 + 1.4)
		_rock(Vector3(x, ground(x, z_front) + mh * 0.5, z_front + 0.6), Vector3(1.6, mh * 0.75, 1.4), Basis.from_euler(Vector3(0.0, rng.randf_range(-0.2, 0.2), 0.0)), 0.05, 0.6)
	_rock(Vector3(0.0, ground(0.0, z_front) + mh + 0.6, z_front + 0.8), Vector3(mouth_w * 0.5 + 1.8, 0.9, 1.5), Basis.from_euler(Vector3(0.05, 0.0, rng.randf_range(-0.06, 0.06))), 0.08, 0.7)
	_soot(0.0, ground(0.0, z_front) + mh - 0.2, z_front - 0.75, mouth_w * 0.8)
	for sx: float in [-1.0, 1.0]:
		var xo := sx * (w - 1.0)
		_rock(Vector3(xo, ground(xo, z_front) + 0.4, z_front + 0.8), Vector3(1.3, 1.1, 1.3), Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), 0.05, 0.6)
	# Inside: the dry floor just in from the mouth (the fire's), then the
	# passage narrowing back to the chamber. Walls of raw rock under a roof
	# of rock slabs, the light failing toward the back.
	shade = 0.35
	var z_room := z_front + 5.0
	var z_pass := -4.5
	for sx: float in [-1.0, 1.0]:
		# The front room's walls.
		var z := z_front + 1.4
		while z < z_room:
			var x := sx * (mouth_w * 0.5 + 0.9)
			_rock(Vector3(x, ground(x, z) + 1.3, z + 0.7), Vector3(0.9, 1.6, 0.95), Basis.IDENTITY, 0.0, 0.2)
			z += 1.4
		# The passage's.
		z = z_room
		while z < z_pass:
			var x := sx * 1.9
			_rock(Vector3(x, ground(x, z) + 1.2, z + 0.7), Vector3(0.8, 1.5, 0.95), Basis.IDENTITY, 0.0, 0.1)
			z += 1.4
		# The chamber's.
		z = z_pass
		while z < 1.0:
			var x := sx * 3.4
			_rock(Vector3(x, ground(x, z) + 1.3, z + 0.7), Vector3(0.9, 1.6, 0.95), Basis.IDENTITY, 0.05, 0.1)
			z += 1.4
	# The roofs: slabs on the walls' tops.
	var zr := z_front + 1.2
	while zr < 0.8:
		var half := mouth_w * 0.5 + 1.6 if zr < z_room else (2.6 if zr < z_pass else 4.2)
		var g := ground(0.0, zr)
		_rock(Vector3(0.0, g + 3.0, zr + 0.8), Vector3(half, 0.55, 1.0), Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))), 0.15, 0.0)
		zr += 1.5
	shade = 0.0
	# The chamber's drip pool against the cliff, and a faint glow (the back
	# pool can be a glow pond, landforms.json links.magic).
	var gp := ground(0.0, -1.8)
	_pools.append([Vector3(0.0, gp + 0.12, -1.8), 1.5, false])
	_glow(Vector3(0.0, gp + 1.4, -2.0), Color(0.45, 0.85, 0.8), 5.0, 0.14)
	var zs := z_front + 1.0
	while zs < 0.5:
		_shelters.append([Vector3(0.0, ground(0.0, zs), zs), 1.4, 2.6])
		zs += 1.6


## The cenote's undercut lip: rock slabs round the rim leaning in over the
## shaft (none over the fallen-block slope), and the blocks down it.
func _cenote_lip() -> void:
	var r: float = nest.radius_m
	var segs := maxi(8, int(TAU * r / 4.5))
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		# The slope runs down along local -z (the site's heading).
		var off := absf(wrapf(a - PI * 1.5, -PI, PI))
		if off < 0.65:
			continue
		var dir := Vector3(cos(a), 0.0, sin(a))
		var p := dir * (r - 0.4)
		var g := ground(p.x * 1.15, p.z * 1.15)
		var tangent := Vector3(-dir.z, 0.0, dir.x)
		var basis := Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)).rotated(tangent, -0.18)
		_rock(Vector3(p.x, g - 0.5, p.z), Vector3(TAU * r / segs * 0.6, 0.7, 1.4), basis, 0.05, 0.6)
	# The fallen blocks on the slope down (-z).
	for k in 6:
		var t := float(k) / 5.0
		var z := -lerpf(r * 0.5, r + float(nest.get("ramp_out_m", 6.0)) * 0.6, t)
		var x := rng.randf_range(-3.0, 3.0)
		var s := Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.35, 0.6), rng.randf_range(0.5, 0.9))
		_rock(Vector3(x, ground(x, z) + s.y * 0.35, z), s, Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0.0)), 0.05, 0.5)


## Drift logs jammed between a slot canyon's walls near the top: how high
## the floods rise.
func _drift_logs() -> void:
	var depth: float = nest.get("depth_m", 10.0)
	mat = RuinBuilder.WOOD_M
	solid = false
	for k in 2:
		var z := rng.randf_range(-12.0, 12.0)
		var y := ground(0.0, z) + depth * rng.randf_range(0.55, 0.75)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.12, 0.12)))
		box(Transform3D(basis, Vector3(0.0, y, z)), Vector3(7.0, 0.35, 0.35), RuinBuilder.OLD_WOOD, 0.0, 0.12, 0.05)
	solid = true
	mat = RuinBuilder.STONE_M


## A spring: a small pool where the water comes out, a wet stain of mossed
## stones round it.
func _spring(d: Vector3) -> void:
	var c := _local(d)
	_pools.append([c + Vector3(0.0, 0.1, 0.0), 1.6, false])
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var p := c + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(1.7, 2.3)
		var s := Vector3(rng.randf_range(0.3, 0.55), rng.randf_range(0.2, 0.3), rng.randf_range(0.3, 0.5))
		_rock(Vector3(p.x, ground(p.x, p.z) + s.y * 0.3, p.z), s, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), 0.15, 0.9)


# --- Columnar basalt (design 3 Oct §DX) ---------------------------------------------

## Dark grey-black basalt: the wet tops darker and bluer than the faces (the
## shade rule is navy, never grey); the stone's own tile at 16 texels a
## metre on both (ruin.gdshader); green weed in the cups that hold water.
const BASALT_TOP := Color(0.19, 0.205, 0.27, 0.0)
const BASALT_SIDE := Color(0.155, 0.16, 0.2, 0.0)
const BASALT_WET := Color(0.12, 0.14, 0.22, 0.0)
const WEED := Color(0.13, 0.27, 0.15, 0.55)
## The columns' circumradius: the causeway's 30-50 cm across (0.42 m), the
## cliffs' a little coarser; the far stand-in's.
const CAUSEWAY_R := 0.24
const CLIFF_R := 0.34
const COLUMN_LOD_R := 1.1
## Flat-topped hexagons: the axial neighbour across edge k (between corners
## k and k+1, at 60k degrees round the centre).
const HEX_NB := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]


## 0-1 from a column's hash, `k`th draw.
static func _hf(h: int, k: int) -> float:
	return float((h >> (k * 7 % 28)) & 1023) / 1023.0


## A field of hexagonal columns (circumradius `r`) over local x in
## [-half_x, half_x], z in [z0, z1]. `spans` (Callable(x, z, hash) ->
## Array) gives a column's solid lengths, [[bottom, top, under, top colour,
## side colour, cup], ...] (empty: no column; `under`: draw the underside of
## a hanging span; `cup`: water stands in its top). A face is drawn only
## where it shows: each span's top, a hanging span's underside, and a side
## only where the neighbour's spans don't cover it.
func _hex_field(r: float, half_x: float, z0: float, z1: float, spans: Callable) -> void:
	var dz := sqrt(3.0) * r
	var q0 := int(floor(-half_x / (1.5 * r))) - 1
	var q1 := int(ceil(half_x / (1.5 * r))) + 1
	var cols := {}
	for q in range(q0, q1 + 1):
		var x := 1.5 * r * q
		if absf(x) > half_x:
			continue
		for s in range(int(floor(z0 / dz - q * 0.5)) - 1, int(ceil(z1 / dz - q * 0.5)) + 2):
			var z := dz * (s + q * 0.5)
			if z < z0 or z > z1:
				continue
			var sp: Array = spans.call(x, z, hash(Vector3i(q, s, int(nest.seed) % 1000003)))
			if not sp.is_empty():
				cols[Vector2i(q, s)] = sp
	var cn: Array[Vector3] = []
	for k in 7:
		var a := deg_to_rad(60.0 * k)
		cn.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for key: Vector2i in cols:
		var c := Vector3(1.5 * r * key.x, 0.0, dz * (key.y + key.x * 0.5))
		if not _no_cups:
			_columns += 1
		for span in cols[key]:
			var bot := float(span[0])
			var top := float(span[1])
			var tc: Color = span[3]
			var sc: Color = span[4]
			var cup := bool(span[5]) and not _no_cups
			if cup:
				tc = tc.lerp(WEED, 0.55)
				tc.a = WEED.a
			for k in [1, 2, 3, 4]:
				_tri_dir(c + cn[0] + Vector3(0, top, 0), c + cn[k] + Vector3(0, top, 0), c + cn[k + 1] + Vector3(0, top, 0), tc, Vector3.UP)
			if bool(span[2]):
				for k in [1, 2, 3, 4]:
					_tri_dir(c + cn[0] + Vector3(0, bot, 0), c + cn[k] + Vector3(0, bot, 0), c + cn[k + 1] + Vector3(0, bot, 0), sc.darkened(0.15), Vector3.DOWN)
			for k in 6:
				var cover: Array = cols.get(key + HEX_NB[k], [])
				for iv in _uncovered(bot, top, cover):
					var y0 := maxf(float(iv[0]), _clip_y)
					var y1 := float(iv[1])
					if y1 - y0 < 0.02:
						continue
					var a0 := c + cn[k]
					var a1 := c + cn[k + 1]
					var col := sc.darkened(clampf((top - y1) * 0.04, 0.0, 0.12))
					_face(a0 + Vector3(0, y0, 0), a1 + Vector3(0, y0, 0), a1 + Vector3(0, y1, 0), a0 + Vector3(0, y1, 0), col, c + Vector3(0, (y0 + y1) * 0.5, 0))
			if cup:
				# Water in the cup: a hexagon a little in from the rim.
				_cups += 1
				var w := top + 0.015
				for k in 6:
					for p: Vector3 in [c, c + cn[k] * 0.72, c + cn[k + 1] * 0.72]:
						_wv.append(Vector3(p.x, w, p.z))
						_wuv.append(Vector2(p.x, p.z))
						_wuv2.append(Vector2.ZERO)


## A triangle facing `want` (its winding fixed to match).
func _tri_dir(a: Vector3, b: Vector3, c: Vector3, col: Color, want: Vector3) -> void:
	if (b - a).cross(c - a).dot(want) < 0.0:
		_tri(a, c, b, col)
	else:
		_tri(a, b, c, col)


## The parts of [a, b] no interval of `cover` ([[bottom, top, ...], ...])
## covers.
static func _uncovered(a: float, b: float, cover: Array) -> Array:
	var out := [[a, b]]
	for cv in cover:
		var lo := float(cv[0])
		var hi := float(cv[1])
		var nxt := []
		for seg in out:
			if hi <= seg[0] or lo >= seg[1]:
				nxt.append(seg)
				continue
			if lo > seg[0]:
				nxt.append([seg[0], lo])
			if hi < seg[1]:
				nxt.append([hi, seg[1]])
		out = nxt
	return out


## The field again as the far stand-in (coarse columns, no water), moved
## into the far LOD.
func _hex_lod(half_x: float, z0: float, z1: float, spans: Callable) -> void:
	var start := _v.size()
	var was_cols := _columns
	_no_cups = true
	_hex_field(COLUMN_LOD_R, half_x, z0, z1, spans)
	_no_cups = false
	_columns = was_cols
	_lv.append_array(_v.slice(start))
	_ln.append_array(_n.slice(start))
	_lc.append_array(_c.slice(start))
	_lm.append_array(_m.slice(start))
	_v.resize(start)
	_n.resize(start)
	_c.resize(start)
	_m.resize(start)


## Collision for walking on columns: a smooth surface `step` m apart at
## `h`(x, z) (NAN: the ground's), so the stepped tops walk as a slope and
## the cliffs stand as walls; solid from above. Only quads with a corner
## off the ground are added (the terrain has its own).
func _walk_grid(x0: float, x1: float, z0: float, z1: float, step: float, h: Callable) -> void:
	var nx := int(ceil((x1 - x0) / step))
	var nz := int(ceil((z1 - z0) / step))
	var ys := PackedFloat32Array()
	var lifted := PackedByteArray()
	ys.resize((nx + 1) * (nz + 1))
	lifted.resize((nx + 1) * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			var v: float = h.call(x, z)
			var g := ground(x, z)
			lifted[j * (nx + 1) + i] = 0 if is_nan(v) or v <= g + 0.05 else 1
			ys[j * (nx + 1) + i] = g if is_nan(v) else maxf(v, g)
	for j in nz:
		for i in nx:
			var ia := j * (nx + 1) + i
			var ib := ia + 1
			var ic := ia + nx + 2
			var id := ia + nx + 1
			if lifted[ia] + lifted[ib] + lifted[ic] + lifted[id] == 0:
				continue
			var x := x0 + i * step
			var z := z0 + j * step
			var a := Vector3(x, ys[ia], z)
			var b := Vector3(x + step, ys[ib], z)
			var c := Vector3(x + step, ys[ic], z + step)
			var d := Vector3(x, ys[id], z + step)
			var below := (a + b + c + d) * 0.25 - Vector3(0, 1.0, 0)
			_ctri(a, b, c, below)
			_ctri(a, c, d, below)


## The causeway (§DX.1): a field of close-packed columns whose tops step
## down from a cliff of tall columns at the landward edge (cliff_m) to
## below the sea, a stair of flat stones going down into the water; rain
## and tide pools in the cups with green weed, more of them near the
## water; the hearth's floor a flush circle of tops on the highest dry step,
## the seats round it the fire circle's own column tops (FireCircle).
func _causeway() -> void:
	var land_m := float(nest.get("land_m", 20.0))
	var sea_m := float(nest.get("sea_m", 16.0))
	var width := float(nest.get("width_m", 24.0))
	var cliff := float(nest.get("cliff_m", 8.0))
	var sea_y := PlanetConst.SEA_LEVEL_M - base_e
	var hl := _local(nest.hearth)
	var ph := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var outline := func(x: float, z: float) -> float:
		# How far inside the field's ragged edge (m; negative outside).
		var hw := width * 0.5 * (0.82 + 0.18 * sin(z * 0.31 + ph)) * lerpf(1.0, 0.55, clampf(z / sea_m, 0.0, 1.0))
		return minf(hw - absf(x), z + land_m)
	# The smooth surface the tops step about (and the walk's).
	var surf := func(x: float, z: float, g: float) -> float:
		var edge: float = outline.call(x, z)
		if edge < 0.0:
			return NAN
		if z < -land_m + 2.6:
			return g + cliff * 0.78
		if Vector2(x - hl.x, z - hl.z).length() < 3.0:
			return g + 0.03
		var lift := 0.15 + 0.3 * (0.5 + 0.5 * sin(x * 0.45 + ph) * sin(z * 0.38 + ph2))
		return g + lift * smoothstep(0.0, 1.5, edge)
	var spans := func(x: float, z: float, h: int) -> Array:
		var g := ground(x, z)
		var s: float = surf.call(x, z, g)
		if is_nan(s):
			return []
		var top := s
		var tc := BASALT_TOP.darkened(_hf(h, 1) * 0.12)
		var sc := BASALT_SIDE.darkened(_hf(h, 2) * 0.1)
		var cup := false
		if z < -land_m + 2.6:
			# The cliff: tall columns, broken at their own heights.
			top = g + cliff * (0.55 + 0.45 * _hf(h, 0))
		elif Vector2(x - hl.x, z - hl.z).length() >= 3.0:
			top = snappedf(s, 0.16) + [0.0, 0.08, 0.16, -0.08][h & 3]
			top = maxf(top, g + 0.04)
			if top < sea_y - 1.2:
				# Gone under the sea.
				return []
			if top < sea_y + 0.8:
				tc = tc.lerp(BASALT_WET, 0.6)
			if top < sea_y:
				tc = tc.lerp(WEED, 0.5)
				tc.a = 0.4
			elif _hf(h, 3) < (0.2 if top < sea_y + 1.2 else 0.08) and outline.call(x, z) > 0.6:
				cup = true
		return [[g - 0.5, top, false, tc, sc, cup]]
	_clip_y = sea_y - 1.4
	_hex_field(CAUSEWAY_R, width * 0.5 + 0.5, -land_m - 0.3, sea_m, spans)
	_hex_lod(width * 0.5 + 0.5, -land_m - 0.3, sea_m, spans)
	_clip_y = -INF
	_walk_grid(-width * 0.5 - 1.0, width * 0.5 + 1.0, -land_m - 1.0, sea_m, 0.7, func(x: float, z: float) -> float:
		return surf.call(x, z, ground(x, z)))


## The organ pipes (§DX.2): a cliff of columns cliff_m tall on the river's
## bank, its face face_m back from the water's edge, the flow behind it
## stepping down; a stream comes out between the columns and pours over the
## middle of the lip (the waterfall's own sheet) into a pool at the foot,
## running on to the river; the hearth along the foot out of the spray.
func _organ_pipes() -> void:
	var face_m := float(nest.get("face_m", 9.0))
	var width := float(nest.get("width_m", 28.0))
	var cliff := float(nest.get("cliff_m", 16.0))
	var deep := 14.0
	var ph := rng.randf() * TAU
	var g_lip := ground(0.0, -face_m - 0.5)
	var notch_y := g_lip + cliff - 1.0
	var surf := func(x: float, z: float, g: float) -> float:
		if z > -face_m:
			return NAN
		var hw := width * 0.5 * (0.85 + 0.15 * sin(z * 0.27 + ph))
		var edge := hw - absf(x)
		if edge < 0.0 or z < -face_m - deep:
			return NAN
		var t := (-face_m - z) / deep
		if absf(x) < 1.4 and t < 0.45:
			return notch_y
		var hgt := cliff * (1.0 - 0.85 * smoothstep(0.25, 1.0, t))
		return g + hgt * (0.4 + 0.6 * smoothstep(0.0, 4.0, edge))
	var spans := func(x: float, z: float, h: int) -> Array:
		var g := ground(x, z)
		var s: float = surf.call(x, z, g)
		if is_nan(s):
			return []
		var top := s
		var t := (-face_m - z) / deep
		if not (absf(x) < 1.4 and t < 0.45):
			top += (_hf(h, 0) - 0.5) * (2.4 if t < 0.1 else 0.6)
		var tc := BASALT_TOP.darkened(_hf(h, 1) * 0.12)
		var sc := BASALT_SIDE.darkened(_hf(h, 2) * 0.1)
		if absf(x) < 3.0:
			# Wet by the fall.
			sc = sc.lerp(BASALT_WET, 0.6)
			tc = tc.lerp(BASALT_WET, 0.5)
		return [[g - 0.5, maxf(top, g + 0.1), false, tc, sc, false]]
	_hex_field(CLIFF_R, width * 0.5 + 0.5, -face_m - deep - 0.3, -face_m, spans)
	_hex_lod(width * 0.5 + 0.5, -face_m - deep - 0.3, -face_m, spans)
	_walk_grid(-width * 0.5 - 1.0, width * 0.5 + 1.0, -face_m - deep - 1.0, -face_m + 0.7, 0.7, func(x: float, z: float) -> float:
		return surf.call(x, z, ground(x, z)))
	# The stream on the notch, over the lip into the pool at the foot.
	var pz := -face_m + 2.5
	var gp := ground(0.0, pz)
	_water_strip(Vector3(0.0, notch_y + 0.05, -face_m - deep * 0.45), Vector3(0.0, notch_y + 0.05, -face_m + 0.05), 0.95, 0.0)
	_water_fall(Vector3(-0.95, notch_y + 0.05, -face_m + 0.05), Vector3(0.95, notch_y + 0.05, -face_m + 0.05), gp + 0.1)
	_pools.append([Vector3(0.0, gp + 0.1, pz), 2.4, false])
	# Its outflow to the river, over the ground.
	var prev := Vector3(0.0, gp + 0.08, pz + 2.2)
	for k in 4:
		var z := lerpf(pz + 2.2, 1.0, float(k + 1) / 4.0)
		var nxt := Vector3(0.0, ground(0.0, z) + 0.06, z)
		_water_strip(prev, nxt, 0.6, float(k) * 2.0)
		prev = nxt
	# Spray-wet stones round the pool.
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var p := Vector3(cos(a) * 2.8, 0.0, pz + sin(a) * 2.8)
		var sz := Vector3(rng.randf_range(0.3, 0.6), rng.randf_range(0.2, 0.35), rng.randf_range(0.3, 0.5))
		_rock(Vector3(p.x, ground(p.x, p.z) + sz.y * 0.3, p.z), sz, Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)), 0.25, 0.9)
	_roar = [Vector3(0.0, gp + 1.0, pz), clampf(cliff / 20.0 + 0.3, 0.4, 1.4)]


## The columned sea cave (§DX.3): a headland of columns standing out from
## the shore over the water (reach_m), its top the clifftop top_m over the
## sea, reached from the land by a stair of column tops; the cave runs
## through it from the seaward face to its back just off the shore, the sea
## running in, the roof the columns' undersides; a ledge of broken stumps
## along one wall above the water to the back, and on round the outside of
## the headland to the shore (the way in is already there). Darker toward
## the back: the mouth is the only light (§BD). The boom of the swell at the
## back (§BG) and the den on the ledge (§CH).
func _sea_cave() -> void:
	var reach := float(nest.get("reach_m", 30.0))
	var width := float(nest.get("width_m", 24.0))
	var top_m := float(nest.get("top_m", 9.0))
	var back := float(nest.get("back_m", 2.5))
	var stair := float(nest.get("stair_m", 18.0))
	var sea_y := PlanetConst.SEA_LEVEL_M - base_e
	var ph := rng.randf() * TAU
	var hw_r := width * 0.5
	var cave_w := func(z: float) -> float:
		return lerpf(2.2, 3.4, clampf((z - back) / (reach - back), 0.0, 1.0))
	var roof := func(z: float) -> float:
		return sea_y + lerpf(4.0, 6.5, clampf((z - back) / (reach - back), 0.0, 1.0))
	var in_mass := func(x: float, z: float) -> bool:
		if z > reach or z < -3.0 - stair:
			return false
		# The +x side straight (the outer ledge runs along it), the -x ragged.
		var hw_l := hw_r * (0.85 + 0.15 * sin(z * 0.2 + ph))
		var round_off := sqrt(clampf((reach - z) / 5.0, 0.0, 1.0))
		return x <= hw_r * maxf(round_off, 0.75) and x >= -hw_l * round_off
	var in_cave := func(x: float, z: float) -> bool:
		return z >= back and z <= reach + 0.5 and absf(x) < cave_w.call(z)
	var ledge := func(x: float, z: float) -> bool:
		# Inside along the +x wall; round the mouth; along the outside.
		if in_cave.call(x, z):
			return x > float(cave_w.call(z)) - 1.6
		if z > reach and z < reach + 1.7 and x > float(cave_w.call(reach)) - 1.6 and x < hw_r + 1.7:
			return true
		return x > hw_r and x < hw_r + 1.7 and z > -4.0 and z < reach + 1.7
	var top_at := func(x: float, z: float, g: float) -> float:
		if z >= -3.0:
			return sea_y + top_m + 0.4 * sin(x * 0.3 + ph) * sin(z * 0.23)
		var t := (-3.0 - z) / stair
		return maxf(lerpf(sea_y + top_m, g + 0.2, t), g + 0.1)
	var stump := func(z: float, g: float) -> float:
		return maxf(sea_y + 0.9, g + 0.15)
	var spans := func(x: float, z: float, h: int) -> Array:
		var g := ground(x, z)
		var out := []
		var dark := clampf(1.0 - (z - back) / (reach - back), 0.0, 1.0) * 0.75
		var near_cave := z >= back - 1.0 and z <= reach and absf(x) < float(cave_w.call(z)) + 1.4
		var tc := BASALT_TOP.darkened(_hf(h, 1) * 0.12)
		var sc := BASALT_SIDE.darkened(_hf(h, 2) * 0.1)
		if near_cave:
			sc = sc.darkened(dark)
		if ledge.call(x, z):
			var st: float = stump.call(z, g) + (_hf(h, 3) - 0.5) * 0.35
			if _hf(h, 4) < 0.08:
				st = maxf(sea_y + 0.35, g + 0.1)
			out.append([g - 0.5, st, false, tc.lerp(BASALT_WET, 0.5).darkened(dark if near_cave else 0.0), sc, false])
		if in_mass.call(x, z):
			var top: float = top_at.call(x, z, g)
			if z < -3.0:
				top = snappedf(top, 0.22)
			else:
				top += (_hf(h, 0) - 0.5) * 0.24
			if in_cave.call(x, z):
				var rf: float = roof.call(z) + _hf(h, 5) * 0.7
				out.append([rf, top, true, tc, BASALT_SIDE.darkened(dark + 0.1), false])
			elif not ledge.call(x, z):
				out.append([g - 0.5, top, false, tc, sc, false])
		return out
	_clip_y = sea_y - 1.4
	_hex_field(CLIFF_R, hw_r + 2.0, -3.0 - stair - 0.3, reach + 1.8, spans)
	_hex_lod(hw_r + 2.0, -3.0 - stair - 0.3, reach + 1.8, spans)
	_clip_y = -INF
	# Walking: the ledges, the clifftop and its stair, the walls; and the
	# clifftop again over the cave (its roof's top).
	var low := func(x: float, z: float) -> float:
		var g := ground(x, z)
		if ledge.call(x, z):
			return stump.call(z, g)
		if in_cave.call(x, z):
			return NAN
		if in_mass.call(x, z):
			return top_at.call(x, z, g)
		return NAN
	_walk_grid(-hw_r - 2.0, hw_r + 2.0, -3.0 - stair - 0.5, reach + 2.0, 0.6, low)
	var upper := func(x: float, z: float) -> float:
		if in_mass.call(x, z) and in_cave.call(x, z):
			return top_at.call(x, z, ground(x, z))
		return NAN
	_walk_grid(-4.0, 4.0, back, reach, 0.6, upper)
	# In the cave, out of the rain on the ledge; the boom at the back where
	# the swell runs in; the den at the ledge's end.
	var zs := back + 1.0
	while zs < reach - 1.0:
		var cw: float = cave_w.call(zs)
		_shelters.append([Vector3(cw - 0.8, sea_y + 0.9, zs), 1.2, float(roof.call(zs)) - sea_y - 0.9])
		zs += 2.0
	_boom = Vector3(0.0, sea_y + 1.0, back + 3.0)
	_den = Vector3(float(cave_w.call(back)) - 0.8, sea_y + 1.0, back + 1.2)

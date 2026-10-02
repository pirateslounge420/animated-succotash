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
## and a spring's pool (escarpment foot, a ravine's widening, a cave mouth
## on an escarpment face) and a blue hole's dark water (pools, make_node).
## Local frame: origin at the nest's feature, -z out of the rock (or along
## a cenote's slope), +z into it.

var nest: Dictionary
## Water discs [local center, radius, dark] added by make_nest().
var _pools: Array = []


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
	if p_nest.has("spring"):
		b._spring(p_nest.spring)
	return {"site": b.site, "v": b._v, "n": b._n, "c": b._c, "m": b._m, "cv": b._cv, "ch": b._ch,
		"lv": b._lv, "ln": b._ln, "lc": b._lc, "lm": b._lm, "up": b.up, "ex": b.ex, "ez": b.ez, "base_e": b.base_e,
		"shelters": b._shelters, "camp_spot": Vector3.ZERO, "lights": b._lights, "vine_anchors": b._vine_anchors,
		"boulder_anchors": b._boulder_anchors, "pools": b._pools, "nest": p_nest}


## Main thread: the node (RuinBuilder.make_node) with its pools.
static func make_nest(data: Dictionary, world: Node) -> Node3D:
	var root := RuinBuilder.make_node(data, world)
	var nest: Dictionary = data.nest
	root.name = Nests.name_of(nest).replace(" ", "").replace("/", "")
	root.set_meta("nest", nest)
	for p in data.get("pools", []):
		root.add_child(_pool_disc(p[0], p[1], p[2]))
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
		if off < 0.5:
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
		var x := rng.randf_range(-1.6, 1.6)
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

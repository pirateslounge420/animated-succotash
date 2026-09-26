class_name CreatureBodies
## Placeholder low-poly bodies for creatures, built from a handful of
## rounded, smooth-shaded primitives with flat colors (the GameCube look):
## spheres and capsules of 12 sides by 6 rings for bodies and heads, 8 x 4
## for eyes and other small bits, limbs as capsules that taper toward the
## foot. Meshes are shared between all creatures. Every body faces
## -Z with +Y up. Ambient animals are scaled so `size_m` is roughly their
## length; mythical figures so `size_m` is their height.
##
## build() returns {"root": Node3D, "legs": [pivots], "wings": [pivots],
## "tail": pivot or null, "light": OmniLight3D or null}; Creature swings the
## pivots while it moves.

static var _mats := {}
static var _meshes := {}


static func build(sp: CreatureSpecies) -> Dictionary:
	# An imported model (ModelLibrary: assets/models/<name>.glb) first.
	var model := ModelLibrary.load_model(ModelLibrary.name_for(sp.name), true)
	if model:
		model.scale = Vector3.ONE * sp.size_m
		var animator: ModelAnimator = model.get_node_or_null("Animator")
		return {"root": model, "legs": [], "wings": [], "tail": null, "light": null, "animator": animator}
	# Then a sculpted body (SculptedBodies) when this kind has one and it's
	# built.
	var sculpted := SculptedBodies.build(sp)
	if not sculpted.is_empty():
		if sp.body != "swarm":
			(sculpted.root as Node3D).scale = Vector3.ONE * sp.size_m
		return sculpted
	var b := {"root": Node3D.new(), "legs": [], "wings": [], "tail": null, "light": null}
	var kind := sp.shape if sp.role == "mythical" else sp.body
	match kind:
		"wolf":
			_quadruped(b, sp, 0.36, 0.55)
		"quadruped":
			_quadruped(b, sp, 0.32, 0.55)
		"rodent":
			_quadruped(b, sp, 0.14, 0.8)
		"deer":
			_quadruped(b, sp, 0.55, 0.35)
			_antlers(b, sp)
		"tortoise":
			_tortoise(b, sp)
		"bird":
			_bird(b, sp, 0.08, 0.0)
		"wader":
			_bird(b, sp, 0.5, 0.35)
		"duck":
			_bird(b, sp, 0.0, 0.08)
		"frog":
			_frog(b, sp)
		"beetle":
			_beetle(b, sp)
		"swarm":
			_swarm(b, sp)
		"stalker":
			_stalker(b, sp)
		"wisp":
			_wisp(b, sp)
		"troll":
			_troll(b, sp)
		"witch":
			_witch(b, sp)
		"goblin":
			_goblin(b, sp)
		"tribal":
			_tribal(b, sp)
		"unicorn":
			_unicorn(b, sp)
		"werewolf":
			_werewolf(b, sp)
		"skeleton":
			_skeleton(b, sp)
		"robed":
			_robed(b, sp)
		_:
			_quadruped(b, sp, 0.3, 0.5)
	if kind != "swarm":
		(b.root as Node3D).scale = Vector3.ONE * sp.size_m
	return b


# --- Materials and primitive parts -------------------------------------------

static func mat(c: Color, glow := 0.0) -> Material:
	var key := "%s_%.2f" % [c.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if glow > 0.0:
		# Glowing parts (eyes, lanterns, wisps): unshaded emissive.
		var sm := StandardMaterial3D.new()
		sm.albedo_color = c
		sm.emission_enabled = true
		sm.emission = c
		sm.emission_energy_multiplier = glow
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = sm
	else:
		# Lit like the world: colored shadows, rim light, moonlit edge.
		var sh := ShaderMaterial.new()
		sh.shader = preload("res://shaders/creature.gdshader")
		sh.set_shader_parameter("albedo", c)
		Look.register(sh)
		m = sh
	_mats[key] = m
	return m


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(c, glow)
	parent.add_child(mi)
	return mi


## Shared unit sphere (radius 0.5). Level 2: 28 sides x 14 rings (bodies,
## heads); 1: 16 x 8 (snouts, tails); 0: 8 x 5 (eyes, noses). Round,
## smooth silhouettes like GameCube-era models, not faceted shapes.
static func _sphere(level: int) -> SphereMesh:
	var key := "sphere_%d" % level
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = [8, 16, 28][level]
		m.rings = [5, 8, 14][level]
		_meshes[key] = m
	return _meshes[key]


## Detail level for a part of this size (in body lengths).
static func _level(size: float) -> int:
	return 2 if size >= 0.15 else (1 if size >= 0.07 else 0)


## Shared capsule of diameter 1 along Y, `length` long overall (>= 1):
## 28 sides and 5 rings round each cap for body parts, fewer for small
## ones.
static func _capsule(length: float, level: int) -> ArrayMesh:
	var q := snappedf(maxf(length, 1.0), 0.25)
	var key := "capsule_%.2f_%d" % [q, level]
	if not _meshes.has(key):
		var half := q * 0.5 - 0.5
		var prof: Array = []
		var cap_rings: int = [1, 3, 5][level]
		for k in range(1, cap_rings + 1):
			var a := PI * 0.5 * k / (cap_rings + 1)
			prof.append([0.5 * sin(a), half + 0.5 * cos(a)])
		prof.append([0.5, half])
		prof.append([0.5, -half])
		for k in range(cap_rings, 0, -1):
			var a := PI * 0.5 * k / (cap_rings + 1)
			prof.append([0.5 * sin(a), -half - 0.5 * cos(a)])
		_meshes[key] = _revolve(prof, half + 0.5, -half - 0.5, [10, 16, 28][level])
	return _meshes[key]


## A smooth closed surface of revolution around Y: `prof` is [radius, y]
## rings from top to bottom, between poles at y = top and y = bottom.
static func _revolve(prof: Array, top: float, bottom: float, radial: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3(0, top, 0))
	for ring in prof:
		for k in radial:
			var a := TAU * k / radial
			verts.append(Vector3(cos(a) * ring[0], ring[1], sin(a) * ring[0]))
	verts.append(Vector3(0, bottom, 0))
	var last := verts.size() - 1
	for k in radial:
		var k1 := (k + 1) % radial
		idx.append_array([0, 1 + k, 1 + k1])
		for r in prof.size() - 1:
			var a0 := 1 + r * radial
			var a1 := a0 + radial
			idx.append_array([a0 + k, a1 + k1, a0 + k1, a0 + k, a1 + k, a1 + k1])
		var lb := 1 + (prof.size() - 1) * radial
		idx.append_array([lb + k, last, lb + k1])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var fn := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
		for q in 3:
			normals[idx[t + q]] += fn
	var mid := Vector3(0, (top + bottom) * 0.5, 0)
	var out_sum := 0.0
	for i in normals.size():
		normals[i] = normals[i].normalized()
		out_sum += normals[i].dot(verts[i] - mid)
	# Normals point out. Godot draws a triangle whose (v1 - v0) x (v2 - v0)
	# points away from the camera, so the faces must be wound the other way
	# from the normals (else the near side is culled and the far side's
	# inside shows).
	if out_sum < 0.0:
		for i in normals.size():
			normals[i] = -normals[i]
	else:
		for t in range(0, idx.size(), 3):
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A rounded block filling `size`: a capsule along its long axis when it's
## elongated, else an ellipsoid. Returns a pivot at `pos` (rotate that).
static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, glow := 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var axis := 0
	if size.y >= size.x and size.y >= size.z:
		axis = 1
	elif size.z >= size.x and size.z >= size.y:
		axis = 2
	var long := size[axis]
	var a := size[(axis + 1) % 3]
	var b := size[(axis + 2) % 3]
	var thick := maxf(a, b)
	var mi: MeshInstance3D
	if long > thick * 1.4:
		mi = _mi(pivot, _capsule(long / thick, _level(thick)), Vector3.ZERO, c, glow)
		# Capsule space: long axis Y, cross-section X and Z; turned so Y
		# runs along the block's long axis.
		var basis := Basis.from_scale(Vector3(size.x, thick, size.z))
		if axis == 0:
			basis = Basis(Vector3(0, 0, 1), -PI * 0.5) * Basis.from_scale(Vector3(size.y, thick, size.z))
		elif axis == 2:
			basis = Basis(Vector3(1, 0, 0), PI * 0.5) * Basis.from_scale(Vector3(size.x, thick, size.y))
		mi.basis = basis
	else:
		var big := maxf(size.x, maxf(size.y, size.z))
		var level := _level(big)
		if minf(size.x, minf(size.y, size.z)) < big * 0.25:
			level = mini(level, 1) # flat (wings, brims): the outline is what shows
		mi = _mi(pivot, _sphere(level), Vector3.ZERO, c, glow)
		mi.scale = size
	return pivot


static func ball(parent: Node3D, radii: Vector3, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := _mi(parent, _sphere(_level(2.0 * maxf(radii.x, maxf(radii.y, radii.z)))), pos, c, glow)
	mi.scale = radii * 2.0
	return mi


static func cone(parent: Node3D, r_bottom: float, r_top: float, h: float, pos: Vector3, c: Color, glow := 0.0, sides := 0) -> MeshInstance3D:
	if sides == 0:
		sides = 24 if maxf(r_bottom, r_top) >= 0.08 else 12
	var key := "cone_%.3f_%.3f_%.3f_%d" % [r_bottom, r_top, h, sides]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = r_bottom
		m.top_radius = r_top
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		m.cap_top = r_top > 0.0
		_meshes[key] = m
	return _mi(parent, _meshes[key], pos, c, glow)


## Ears and the like: a flattened cone, point up. Returns a pivot.
static func wedge(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var mi := cone(pivot, 0.5, 0.0, 1.0, Vector3.ZERO, c, 0.0, 12)
	mi.scale = size
	return pivot


## A capsule tapering from radius r0 at the top (y = 0) to r1 at the
## bottom (y = -length), smooth shaded, 12 sides with rounded ends and a
## slight swell above the middle: legs and arms.
static func _limb_mesh(length: float, r0: float, r1: float) -> ArrayMesh:
	var key := "limb_%.3f_%.3f_%.3f" % [length, r0, r1]
	if not _meshes.has(key):
		var prof := [[r0 * 0.5, r0 * 0.86], [r0 * 0.87, r0 * 0.5], [r0, 0.0], [lerpf(r0, r1, 0.3) * 1.04, -length * 0.3],
			[lerpf(r0, r1, 0.65), -length * 0.65], [r1, -length], [r1 * 0.87, -length - r1 * 0.5], [r1 * 0.5, -length - r1 * 0.86]]
		_meshes[key] = _revolve(prof, r0, -length - r1, 12)
	return _meshes[key]


## A limb hanging from a pivot, so rotating the pivot swings it; thick at
## the hip, tapering to the foot.
static func limb(b: Dictionary, parent: Node3D, hip: Vector3, length: float, thick: float, c: Color, key := "legs") -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	parent.add_child(pivot)
	_mi(pivot, _limb_mesh(snappedf(length, 0.01), snappedf(thick * 0.5, 0.005), snappedf(thick * 0.28, 0.005)), Vector3.ZERO, c)
	b[key].append(pivot)
	return pivot


static func eyes(parent: Node3D, pos: Vector3, spread: float, r: float, c := Color(0.05, 0.05, 0.05), glow := 0.0) -> void:
	ball(parent, Vector3.ONE * r, pos + Vector3(spread, 0, 0), c, glow)
	ball(parent, Vector3.ONE * r, pos - Vector3(spread, 0, 0), c, glow)


# --- Animals -------------------------------------------------------------------

## Four legs, a body, head, ears and tail. `leg` is leg length and `tail`
## tail length, both in body lengths.
static func _quadruped(b: Dictionary, sp: CreatureSpecies, leg: float, tail: float, leg_thick := 0.07) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var body_h := 0.26
	var y := leg + body_h * 0.5
	box(r, Vector3(0.26, body_h, 0.62), Vector3(0, y, 0), c)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, y + 0.14, -0.36)
	r.add_child(head)
	box(head, Vector3(0.18, 0.17, 0.2), Vector3.ZERO, c)
	box(head, Vector3(0.1, 0.09, 0.14), Vector3(0, -0.03, -0.14), c.lightened(0.15))
	box(head, Vector3(0.05, 0.04, 0.03), Vector3(0, -0.01, -0.22), Color(0.08, 0.07, 0.07))
	wedge(head, Vector3(0.06, 0.1, 0.03), Vector3(0.06, 0.12, 0.02), c.darkened(0.2))
	wedge(head, Vector3(0.06, 0.1, 0.03), Vector3(-0.06, 0.12, 0.02), c.darkened(0.2))
	eyes(head, Vector3(0, 0.03, -0.1), 0.06, 0.018)
	for x in [-0.09, 0.09]:
		for z in [-0.24, 0.24]:
			limb(b, r, Vector3(x, leg + 0.02, z), leg + 0.02, leg_thick, c.darkened(0.15))
	var t := Node3D.new()
	t.position = Vector3(0, y + 0.06, 0.31)
	r.add_child(t)
	box(t, Vector3(0.08, 0.08, tail * 0.5), Vector3(0, 0.02, tail * 0.25), c.lightened(0.1))
	t.rotation.x = 0.5
	b.tail = t


static func _antlers(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var y := 0.55 + 0.13 + 0.22
	for s in [-1.0, 1.0]:
		var a := cone(r, 0.014, 0.006, 0.28, Vector3(0.07 * s, y + 0.14, -0.36), Color(0.75, 0.68, 0.55), 0.0, 5)
		a.rotation.z = -0.4 * s
		var tine := cone(r, 0.011, 0.0, 0.14, Vector3(0.12 * s, y + 0.2, -0.42), Color(0.75, 0.68, 0.55), 0.0, 5)
		tine.rotation.x = 0.5


static func _tortoise(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	ball(r, Vector3(0.4, 0.22, 0.48), Vector3(0, 0.14, 0), sp.color)
	box(r, Vector3(0.7, 0.05, 0.8), Vector3(0, 0.09, 0), sp.color.darkened(0.25))
	ball(r, Vector3(0.09, 0.08, 0.12), Vector3(0, 0.12, -0.5), sp.accent.lightened(0.3))
	for x in [-0.25, 0.25]:
		for z in [-0.28, 0.28]:
			limb(b, r, Vector3(x, 0.1, z), 0.1, 0.1, sp.accent.lightened(0.3))


## Birds. `leg` = leg length, `neck` = extra neck length (waders).
static func _bird(b: Dictionary, sp: CreatureSpecies, leg: float, neck: float) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var y := leg + 0.14
	ball(r, Vector3(0.14, 0.14, 0.3), Vector3(0, y, 0), c)
	var head_pos := Vector3(0, y + 0.14 + neck, -0.2)
	if neck > 0.0:
		var n := cone(r, 0.035, 0.03, neck + 0.12, Vector3(0, y + 0.08 + neck * 0.5, -0.16), c)
		n.rotation.x = -0.25
	ball(r, Vector3.ONE * 0.085, head_pos, c if sp.body != "duck" else sp.accent)
	var beak_len := 0.16 if sp.body == "wader" else (0.2 if sp.name == "Toucan" else 0.09)
	var beak := box(r, Vector3(0.04, 0.035, beak_len), head_pos + Vector3(0, -0.01, -0.07 - beak_len * 0.5),
		sp.accent if sp.body != "duck" else Color(0.95, 0.7, 0.2))
	beak.rotation.x = 0.12 if sp.body == "wader" else 0.0
	eyes(r, head_pos + Vector3(0, 0.02, -0.04), 0.07, 0.015)
	box(r, Vector3(0.12, 0.03, 0.14), Vector3(0, y + 0.02, 0.32), c.darkened(0.2))
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.12 * s, y + 0.06, -0.02)
		r.add_child(w)
		box(w, Vector3(0.28, 0.025, 0.22), Vector3(0.13 * s, 0, 0.04), c.darkened(0.12))
		w.rotation.z = -1.2 * s
		b.wings.append(w)
	if leg > 0.0:
		var leg_color := sp.accent if sp.body == "wader" else Color(0.35, 0.3, 0.25)
		for x in [-0.04, 0.04]:
			limb(b, r, Vector3(x, leg + 0.02, 0.02), leg + 0.02, 0.022, leg_color)


static func _frog(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	ball(r, Vector3(0.3, 0.2, 0.4), Vector3(0, 0.2, 0), sp.color)
	eyes(r, Vector3(0, 0.36, -0.22), 0.14, 0.08, Color(0.9, 0.2, 0.1))
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.28 * s, 0.14, 0.2), 0.14, 0.1, sp.color.darkened(0.15))
		limb(b, r, Vector3(0.22 * s, 0.14, -0.2), 0.14, 0.08, sp.color.darkened(0.15))


static func _beetle(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	ball(r, Vector3(0.35, 0.22, 0.5), Vector3(0, 0.25, 0.05), sp.accent)
	ball(r, Vector3(0.22, 0.18, 0.2), Vector3(0, 0.22, -0.45), sp.color)
	for s in [-1.0, 1.0]:
		for z in [-0.25, 0.05, 0.35]:
			var l := limb(b, r, Vector3(0.3 * s, 0.2, z), 0.22, 0.06, sp.color)
			l.rotation.z = 0.7 * s


## Fireflies: a slow cloud of glowing specks. Not scaled with size_m;
## size_m is the cloud's width.
static func _swarm(b: Dictionary, sp: CreatureSpecies) -> void:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(sp.size_m, sp.size_m * 0.35, sp.size_m)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.local_coords = true
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = sp.color
	m.emission_enabled = true
	m.emission = sp.color
	m.emission_energy_multiplier = 6.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	# Blink: fade in and out over each speck's life.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.position = Vector3(0, 1.0, 0)
	b.root.add_child(p)


# --- Mythical figures (size_m = height) ---------------------------------------

## Desert skinwalker: tall, thin, hunched, too-long arms, pale skull face
## and glowing eyes.
static func _stalker(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var torso := box(r, Vector3(0.16, 0.34, 0.1), Vector3(0, 0.66, -0.03), c)
	torso.rotation.x = -0.3
	var head := Node3D.new()
	head.position = Vector3(0, 0.86, -0.1)
	r.add_child(head)
	box(head, Vector3(0.09, 0.1, 0.12), Vector3.ZERO, Color(0.78, 0.74, 0.66))
	box(head, Vector3(0.05, 0.05, 0.08), Vector3(0, -0.03, -0.08), Color(0.7, 0.66, 0.58))
	eyes(head, Vector3(0, 0.02, -0.06), 0.025, 0.014, sp.accent, 4.0)
	for s in [-1.0, 1.0]:
		var ear := wedge(head, Vector3(0.03, 0.12, 0.02), Vector3(0.04 * s, 0.09, 0.02), c)
		ear.rotation.z = -0.35 * s
		limb(b, r, Vector3(0.05 * s, 0.5, 0.0), 0.5, 0.045, c)
		var arm := limb(b, r, Vector3(0.1 * s, 0.8, -0.06), 0.62, 0.035, c, "wings")
		arm.rotation.z = 0.08 * s


static func _wisp(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	ball(r, Vector3.ONE * 0.3, Vector3(0, 1.0, 0), sp.color, 5.0)
	ball(r, Vector3.ONE * 0.5, Vector3(0, 1.0, 0), sp.color.darkened(0.3), 1.2).transparency = 0.6
	var light := OmniLight3D.new()
	light.light_color = sp.color
	light.light_energy = 0.9
	light.omni_range = 9.0
	light.position = Vector3(0, 1.0, 0)
	light.shadow_enabled = false
	r.add_child(light)
	b.light = light


## Trolls (and the yeti): huge hunched body, small head, long arms.
static func _troll(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	ball(r, Vector3(0.24, 0.26, 0.2), Vector3(0, 0.55, 0), c)
	ball(r, Vector3(0.2, 0.18, 0.18), Vector3(0, 0.34, 0.02), c.darkened(0.1))
	var head := Node3D.new()
	head.position = Vector3(0, 0.74, -0.14)
	r.add_child(head)
	ball(head, Vector3(0.1, 0.09, 0.1), Vector3.ZERO, c.lightened(0.05))
	box(head, Vector3(0.05, 0.08, 0.06), Vector3(0, -0.02, -0.1), c.lightened(0.1))
	eyes(head, Vector3(0, 0.02, -0.08), 0.04, 0.014, Color(0.95, 0.85, 0.5), 1.5)
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.1 * s, 0.26, 0.0), 0.26, 0.1, c.darkened(0.15))
		limb(b, r, Vector3(0.25 * s, 0.66, -0.04), 0.55, 0.075, c, "wings")
	if sp.name != "Mountain yeti":
		# Moss and a few stones grown into the back.
		ball(r, Vector3(0.16, 0.08, 0.14), Vector3(0, 0.76, 0.08), Color(0.3, 0.45, 0.22))
		box(r, Vector3(0.06, 0.05, 0.06), Vector3(0.08, 0.72, 0.16), Color(0.5, 0.5, 0.48))


## Marsh witch: robe cone, pale face, pointed hat, lantern.
static func _witch(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	cone(r, 0.2, 0.08, 0.6, Vector3(0, 0.3, 0), c)
	ball(r, Vector3(0.09, 0.1, 0.09), Vector3(0, 0.68, -0.01), Color(0.78, 0.8, 0.7))
	eyes(r, Vector3(0, 0.7, -0.08), 0.03, 0.012)
	box(r, Vector3(0.025, 0.06, 0.04), Vector3(0, 0.66, -0.1), Color(0.7, 0.72, 0.6))
	box(r, Vector3(0.36, 0.015, 0.36), Vector3(0, 0.76, 0), c.darkened(0.2))
	var hat := cone(r, 0.1, 0.0, 0.34, Vector3(0, 0.93, 0.02), c.darkened(0.2))
	hat.rotation.x = 0.25
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.15 * s, 0.58, 0), 0.3, 0.05, c, "wings")
	_lantern(b, r, Vector3(0.2, 0.3, -0.08), sp.accent)


## Goblin: small, big head, huge ears, a lantern.
static func _goblin(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	box(r, Vector3(0.28, 0.3, 0.2), Vector3(0, 0.45, 0), Color(0.45, 0.32, 0.22))
	var head := Node3D.new()
	head.position = Vector3(0, 0.76, -0.02)
	r.add_child(head)
	ball(head, Vector3(0.16, 0.15, 0.15), Vector3.ZERO, c)
	box(head, Vector3(0.05, 0.05, 0.12), Vector3(0, -0.02, -0.16), c.darkened(0.1))
	eyes(head, Vector3(0, 0.03, -0.12), 0.06, 0.03, Color(1.0, 0.85, 0.3), 1.5)
	for s in [-1.0, 1.0]:
		var ear := wedge(head, Vector3(0.05, 0.22, 0.03), Vector3(0.2 * s, 0.03, 0), c)
		ear.rotation.z = -1.2 * s
		limb(b, r, Vector3(0.08 * s, 0.3, 0), 0.3, 0.08, c.darkened(0.2))
		limb(b, r, Vector3(0.18 * s, 0.56, 0), 0.26, 0.06, c, "wings")
	_lantern(b, r, Vector3(0.22, 0.32, -0.06), sp.accent)


## Tribal person (camp folk; size_m = height), until SculptedBodies'
## smooth one is built: hide tunic and leggings, ochre face paint, hair,
## an elder's cloak, and their gear (tribal_gear()). Colors: `color`
## skin, `accent` hide.
static func _tribal(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var skin := sp.color
	var hide := sp.accent
	var ochre := Color(0.72, 0.3, 0.16)
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.055 * s, 0.5, 0.0), 0.48, 0.08, hide.darkened(0.25))
	box(r, Vector3(0.2, 0.3, 0.13), Vector3(0, 0.68, 0), hide)
	cone(r, 0.14, 0.11, 0.14, Vector3(0, 0.5, 0), hide.darkened(0.1)) # skirt of the tunic
	box(r, Vector3(0.21, 0.035, 0.14), Vector3(0, 0.55, 0), ochre.darkened(0.3)) # belt
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.9, 0)
	r.add_child(head)
	ball(head, Vector3(0.062, 0.075, 0.068), Vector3.ZERO, skin)
	ball(head, Vector3(0.07, 0.06, 0.07), Vector3(0, 0.03, 0.012), Color(0.12, 0.09, 0.07)) # hair
	box(head, Vector3(0.09, 0.006, 0.006), Vector3(0, -0.008, -0.062), ochre) # paint stripe under the eyes
	eyes(head, Vector3(0, 0.012, -0.058), 0.022, 0.008)
	box(r, Vector3(0.05, 0.05, 0.05), Vector3(0, 0.82, 0), skin) # neck
	for s in [-1.0, 1.0]:
		var arm := limb(b, r, Vector3(0.13 * s, 0.8, 0.0), 0.36, 0.055, skin, "wings")
		arm.rotation.z = 0.1 * s
	if sp.shape.trim_suffix("_seated") == "elder":
		cone(r, 0.17, 0.12, 0.42, Vector3(0, 0.62, 0.02), hide.lightened(0.15)) # cloak
	tribal_gear(b, sp)


## A tribal person's gear by `sp.shape`: "elder" a feathered staff,
## "hunter" a spear and a quiver, "archer" a bow and a quiver;
## "<shape>_seated" leaves the weapon out (camp folk lay theirs by the
## fire). The sculpted body (SculptedBodies) wears the same.
static func tribal_gear(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var hide := sp.accent
	var seated := sp.shape.ends_with("_seated")
	match sp.shape.trim_suffix("_seated"):
		"elder":
			if not seated:
				var staff := cone(r, 0.012, 0.01, 1.05, Vector3(0.2, 0.52, -0.04), Color(0.4, 0.28, 0.16), 0.0, 8)
				staff.rotation.z = 0.05
				var feather := box(r, Vector3(0.015, 0.1, 0.03), Vector3(0.21, 1.07, -0.04), Color(0.9, 0.86, 0.75))
				feather.rotation.z = -0.4
		"archer":
			var quiver := box(r, Vector3(0.06, 0.28, 0.06), Vector3(-0.06, 0.72, 0.09), hide.darkened(0.2))
			quiver.rotation.z = -0.35
			for k in 3:
				cone(r, 0.004, 0.004, 0.08, Vector3(-0.1 + k * 0.012, 0.9, 0.1), Color(0.88, 0.86, 0.8), 0.0, 3) # fletchings
			if not seated:
				# Bow held upright in the left hand.
				var bow := BowMesh.build(1.25 / maxf(sp.size_m, 0.1))
				r.add_child(bow)
				bow.position = Vector3(-0.2, 0.5, -0.06)
				bow.rotation = Vector3(0.0, PI * 0.5, 0.08)
		_:
			var quiver := box(r, Vector3(0.06, 0.28, 0.06), Vector3(0.06, 0.72, 0.09), hide.darkened(0.2))
			quiver.rotation.z = 0.35
			if not seated:
				var spear := cone(r, 0.01, 0.009, 1.15, Vector3(-0.19, 0.58, -0.02), Color(0.42, 0.3, 0.18), 0.0, 8)
				spear.rotation.z = -0.06
				cone(r, 0.02, 0.0, 0.1, Vector3(-0.22, 1.2, -0.02), Color(0.35, 0.36, 0.4), 0.0, 6) # stone head


## Unicorn (size_m = height at the head): a slender white horse, a raised
## neck and a flowing mane, and a spiral horn that glows (`accent`).
static func _unicorn(b: Dictionary, sp: CreatureSpecies) -> void:
	_quadruped(b, sp, 0.58, 0.5, 0.1)
	var r: Node3D = b.root
	var c := sp.color
	var head: Node3D = r.get_node("Head")
	# Lift the head on a neck.
	head.position += Vector3(0, 0.2, -0.06)
	var neck := box(r, Vector3(0.12, 0.3, 0.13), Vector3(0, head.position.y - 0.15, -0.34), c)
	neck.rotation.x = 0.55
	# Mane down the neck and a forelock, silver-lilac.
	var mane := c.lerp(sp.accent, 0.35)
	for k in 5:
		var t := k / 4.0
		var m := box(r, Vector3(0.05, 0.12, 0.06), Vector3(0, head.position.y + 0.02 - t * 0.28, -0.31 + t * 0.1), mane)
		m.rotation.x = 0.5
	box(head, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.1, -0.04), mane)
	# The horn: a glowing spiral (a stack of tapering rings).
	var horn := Node3D.new()
	horn.position = Vector3(0, 0.1, -0.08)
	horn.rotation.x = -0.55
	head.add_child(horn)
	cone(horn, 0.022, 0.0, 0.22, Vector3(0, 0.11, 0), sp.accent, 3.0)
	for k in 3:
		var ring := cone(horn, 0.024 - k * 0.006, 0.02 - k * 0.006, 0.015, Vector3(0, 0.04 + k * 0.05, 0), sp.accent.lightened(0.3), 4.0)
		ring.rotation.y = k * 0.6
	# A tuft at each hoof.
	for leg in b.legs:
		ball(leg as Node3D, Vector3(0.035, 0.03, 0.035), Vector3(0, -0.6, 0), mane)


## Werewolf (size_m = height, hunched): a dark-furred wolf's head with
## glowing eyes, a heavy chest over a lean waist, long clawed arms and
## digitigrade legs, ragged fur at the shoulders.
static func _werewolf(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var fur := c.lightened(0.12)
	for s in [-1.0, 1.0]:
		var leg := limb(b, r, Vector3(0.08 * s, 0.46, 0.04), 0.46, 0.1, c)
		leg.rotation.x = -0.15
	var chest := box(r, Vector3(0.34, 0.3, 0.22), Vector3(0, 0.7, -0.06), c)
	chest.rotation.x = -0.45
	box(r, Vector3(0.22, 0.22, 0.16), Vector3(0, 0.5, 0.0), c.darkened(0.1)) # waist
	for s in [-1.0, 1.0]:
		var tuft := wedge(r, Vector3(0.08, 0.14, 0.05), Vector3(0.14 * s, 0.86, -0.04), fur)
		tuft.rotation.z = -0.6 * s
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.86, -0.2)
	r.add_child(head)
	ball(head, Vector3(0.1, 0.09, 0.1), Vector3.ZERO, c)
	box(head, Vector3(0.08, 0.07, 0.16), Vector3(0, -0.03, -0.12), c.lightened(0.05)) # muzzle
	box(head, Vector3(0.04, 0.03, 0.03), Vector3(0, -0.01, -0.21), Color(0.05, 0.05, 0.06)) # nose
	eyes(head, Vector3(0, 0.025, -0.08), 0.045, 0.016, sp.accent, 5.0)
	for s in [-1.0, 1.0]:
		var ear := wedge(head, Vector3(0.05, 0.12, 0.03), Vector3(0.06 * s, 0.1, 0.02), c)
		ear.rotation.z = -0.25 * s
		var arm := limb(b, r, Vector3(0.19 * s, 0.8, -0.1), 0.6, 0.08, c, "wings")
		arm.rotation = Vector3(-0.25, 0.0, 0.12 * s)
		for k in 3:
			var claw := cone(arm, 0.012, 0.0, 0.07, Vector3((k - 1) * 0.02, -0.64, -0.02), Color(0.85, 0.82, 0.75))
			claw.rotation.x = PI


## Skeleton (the restless dead at ruin fires; size_m = height): skull with
## dark sockets, a spine and ribs, bare bone limbs. `color` is the bone.
static func _skeleton(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var bone := sp.color
	var dark := Color(0.08, 0.07, 0.06)
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.05 * s, 0.5, 0.0), 0.48, 0.035, bone)
	box(r, Vector3(0.16, 0.06, 0.08), Vector3(0, 0.52, 0), bone) # pelvis
	for k in 5:
		ball(r, Vector3.ONE * 0.018, Vector3(0, 0.56 + k * 0.05, 0.02), bone) # spine
	for k in 4:
		var y := 0.66 + k * 0.045
		var w := 0.09 - absf(k - 1.5) * 0.008
		box(r, Vector3(w * 2.0, 0.018, 0.1), Vector3(0, y, -0.005), bone) # ribs
	box(r, Vector3(0.24, 0.03, 0.05), Vector3(0, 0.84, 0), bone) # collarbones
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.92, 0)
	r.add_child(head)
	ball(head, Vector3(0.06, 0.068, 0.068), Vector3.ZERO, bone)
	box(head, Vector3(0.07, 0.03, 0.05), Vector3(0, -0.05, -0.025), bone) # jaw
	eyes(head, Vector3(0, 0.005, -0.058), 0.024, 0.016, dark)
	ball(head, Vector3(0.008, 0.012, 0.006), Vector3(0, -0.02, -0.064), dark) # nose hole
	for s in [-1.0, 1.0]:
		var arm := limb(b, r, Vector3(0.12 * s, 0.82, 0.0), 0.36, 0.03, bone, "wings")
		arm.rotation.z = 0.1 * s


## Robed, hooded figure (keeps company with the dead): a long robe, a deep
## hood with a pale skull face in its shadow, bony hands. `color` is the
## robe, `accent` the face and hands.
static func _robed(b: Dictionary, sp: CreatureSpecies) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var bone := sp.accent
	for s in [-1.0, 1.0]:
		limb(b, r, Vector3(0.055 * s, 0.5, 0.0), 0.48, 0.08, c.darkened(0.3))
	cone(r, 0.2, 0.12, 0.55, Vector3(0, 0.3, 0), c) # skirt of the robe
	box(r, Vector3(0.24, 0.34, 0.16), Vector3(0, 0.7, 0), c)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.92, 0)
	r.add_child(head)
	ball(head, Vector3(0.085, 0.1, 0.095), Vector3(0, 0.01, 0.01), c.darkened(0.1)) # hood
	cone(head, 0.06, 0.0, 0.1, Vector3(0, 0.1, 0.03), c.darkened(0.1)) # hood point
	ball(head, Vector3(0.05, 0.058, 0.04), Vector3(0, -0.005, -0.05), bone) # face
	eyes(head, Vector3(0, 0.005, -0.085), 0.02, 0.013, Color(0.05, 0.05, 0.05))
	for s in [-1.0, 1.0]:
		var arm := limb(b, r, Vector3(0.14 * s, 0.8, 0.0), 0.36, 0.07, c, "wings")
		arm.rotation.z = 0.1 * s
		ball(arm, Vector3.ONE * 0.025, Vector3(0, -0.38, 0), bone) # hand


static func _lantern(b: Dictionary, parent: Node3D, pos: Vector3, c: Color) -> void:
	box(parent, Vector3(0.07, 0.09, 0.07), pos, c, 6.0)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = pos
	parent.add_child(light)
	b.light = light

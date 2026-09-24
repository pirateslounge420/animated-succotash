class_name CreatureBodies
## Placeholder low-poly bodies for creatures, built from a handful of
## primitive meshes with flat colors (the GameCube look). Every body faces
## -Z with +Y up. Ambient animals are scaled so `size_m` is roughly their
## length; mythical figures so `size_m` is their height.
##
## build() returns {"root": Node3D, "legs": [pivots], "wings": [pivots],
## "tail": pivot or null, "light": OmniLight3D or null}; Creature swings the
## pivots while it moves.

static var _mats := {}


static func build(sp: CreatureSpecies) -> Dictionary:
	var b := {"root": Node3D.new(), "legs": [], "wings": [], "tail": null, "light": null}
	var kind := sp.shape if sp.role == "mythical" else sp.body
	match kind:
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
		_:
			_quadruped(b, sp, 0.3, 0.5)
	if kind != "swarm":
		(b.root as Node3D).scale = Vector3.ONE * sp.size_m
	return b


# --- Materials and primitive parts -------------------------------------------

static func mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f" % [c.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# Flat period lighting: Lambert diffuse, no PBR specular.
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat(c, glow)
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(parent, m, pos, c, glow)


static func ball(parent: Node3D, radii: Vector3, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 7
	m.rings = 4
	var mi := _mi(parent, m, pos, c, glow)
	mi.scale = radii * 2.0
	return mi


static func cone(parent: Node3D, r_bottom: float, r_top: float, h: float, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return _mi(parent, m, pos, c, glow)


static func wedge(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _mi(parent, m, pos, c)


## A limb hanging from a pivot, so rotating the pivot swings it.
static func limb(b: Dictionary, parent: Node3D, hip: Vector3, length: float, thick: float, c: Color, key := "legs") -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	parent.add_child(pivot)
	box(pivot, Vector3(thick, length, thick), Vector3(0, -length * 0.5, 0), c)
	b[key].append(pivot)
	return pivot


static func eyes(parent: Node3D, pos: Vector3, spread: float, r: float, c := Color(0.05, 0.05, 0.05), glow := 0.0) -> void:
	ball(parent, Vector3.ONE * r, pos + Vector3(spread, 0, 0), c, glow)
	ball(parent, Vector3.ONE * r, pos - Vector3(spread, 0, 0), c, glow)


# --- Animals -------------------------------------------------------------------

## Four legs, a body, head, ears and tail. `leg` is leg length and `tail`
## tail length, both in body lengths.
static func _quadruped(b: Dictionary, sp: CreatureSpecies, leg: float, tail: float) -> void:
	var r: Node3D = b.root
	var c := sp.color
	var body_h := 0.26
	var y := leg + body_h * 0.5
	box(r, Vector3(0.26, body_h, 0.62), Vector3(0, y, 0), c)
	var head := Node3D.new()
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
			limb(b, r, Vector3(x, leg + 0.02, z), leg + 0.02, 0.07, c.darkened(0.15))
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
		var a := box(r, Vector3(0.025, 0.28, 0.025), Vector3(0.07 * s, y + 0.14, -0.36), Color(0.75, 0.68, 0.55))
		a.rotation.z = -0.4 * s
		var tine := box(r, Vector3(0.02, 0.14, 0.02), Vector3(0.12 * s, y + 0.2, -0.42), Color(0.75, 0.68, 0.55))
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
	m.emission_energy_multiplier = 4.0
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


static func _lantern(b: Dictionary, parent: Node3D, pos: Vector3, c: Color) -> void:
	box(parent, Vector3(0.07, 0.09, 0.07), pos, c, 3.0)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = pos
	parent.add_child(light)
	b.light = light

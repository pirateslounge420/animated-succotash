class_name Campfire
## A campfire: a stone ring, crossed logs on a bed of glowing coals,
## flames, a warm light, firelight pooled on the ground and a log to sit
## on (DESIGN.md: the warm "pop" against the blue night). Used by the camps
## (Camps), the mythical creatures' fires and the opening encampment.
## The stones and logs collide (PropCollision): low capsules you bump into
## at the ring's edge, and the seat log.
##
## The flames are tongues of shaders/flame.gdshader: cards that turn to
## the camera, drawn additively, so they read as fire from any side and
## build a hot core. Each tongue has its own phase; all campfires share the
## tongue materials.

## R1a fire (docs/WORLD_SYSTEMS_SPEC.md): coals #FF4A00 (the flames' core
## #FFB020 is in the flame shader) and the light #FFA050, strong enough to
## paint the folk and props round the fire warm orange against the blue
## night without turning skin red. The pool on the ground stays the deeper
## #FF7A2A (shaders/fire_glow.gdshader).
const COALS := Color("#ff4a00")
const LIGHT := Color("#ffa050")
const LIGHT_ENERGY := 7.0
## By day the sun drowns the fire: its light falls to this share of
## LIGHT_ENERGY in full daylight.
const DAY_SHARE := 0.45
## Radius (m) of the firelight pooled on the ground (shaders/fire_glow).
const GLOW_M := 5.5
const RING_STONE := Color(0.4, 0.45, 0.52) # R1a blue-grey stone

## [width, height, x, z, phase] of each tongue: a tall one in the middle,
## smaller ones around it.
const TONGUES := [[0.62, 1.0, 0.0, 0.0, 0.0], [0.42, 0.66, 0.13, 0.06, 1.7],
	[0.4, 0.6, -0.11, 0.08, 3.1], [0.36, 0.52, 0.02, -0.13, 4.6]]

## 0 by day, 1 at night (Main sets it each frame from the sky).
static var night := 1.0
static var _flame_mats: Array[ShaderMaterial] = []
static var _card: QuadMesh
static var _glow_mesh: PlaneMesh
static var _glow_mat: ShaderMaterial
static var _warm_mat: ShaderMaterial


## Build one on the ground at surface direction `d`, under `parent`
## (which must be in the scene tree).
static func build(parent: Node3D, world: Node, chunks: ChunkManager, d: Vector3, seat := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	parent.add_child(root)
	root.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	root.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	var body := PropCollision.body(root)
	for i in 8:
		var a := i * TAU / 8.0
		var stone := CreatureBodies.box(root, Vector3(0.28, 0.18, 0.22), Vector3(cos(a) * 0.62, 0.09, sin(a) * 0.62), RING_STONE)
		stone.rotation.y = a
		# Along the stone's length (its x).
		PropCollision.capsule(body, Transform3D(stone.basis * Basis(Vector3(0, 0, 1), -PI * 0.5), stone.position), 0.09, 0.28)
	for i in 3:
		var l := CreatureBodies.cone(root, 0.06, 0.06, 0.9, Vector3(0, 0.12, 0), Color(0.3, 0.2, 0.12))
		l.rotation = Vector3(PI * 0.5, i * TAU / 3.0, 0)
		PropCollision.capsule(body, l.transform, 0.06, 0.9)
	CreatureBodies.ball(root, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.08, 0), COALS, 1.0) # coals
	var flames := Node3D.new()
	flames.name = "Flames"
	flames.position = Vector3(0, 0.1, 0)
	root.add_child(flames)
	for i in TONGUES.size():
		var tg: Array = TONGUES[i]
		var card := MeshInstance3D.new()
		card.mesh = _card_mesh()
		card.material_override = _flame_material(i)
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = Vector3(tg[2], 0.0, tg[3])
		card.scale = Vector3(tg[0], tg[1], 1.0)
		flames.add_child(card)
	for part in _ground_glow():
		root.add_child(part)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = LIGHT
	light.light_energy = LIGHT_ENERGY
	light.omni_range = 14.0
	light.omni_attenuation = 1.1
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	if seat:
		var log_seat := CreatureBodies.cone(root, 0.18, 0.18, 1.5, Vector3(0, 0.18, 2.0), Color(0.36, 0.25, 0.16))
		log_seat.rotation.z = PI * 0.5
		PropCollision.capsule(body, log_seat.transform, 0.18, 1.5)
	return root


## Firelight pooled on the ground round the fire, after dark only: a disc
## that filters the ground warm (shaders/fire_glow_warm.gdshader), then
## the same disc adding the orange light (shaders/fire_glow.gdshader),
## drawn in that order. One mesh and two materials serve every fire.
static func _ground_glow() -> Array[MeshInstance3D]:
	if _glow_mesh == null:
		_glow_mesh = PlaneMesh.new()
		_glow_mesh.size = Vector2(2.0, 2.0)
		_warm_mat = ShaderMaterial.new()
		_warm_mat.shader = preload("res://shaders/fire_glow_warm.gdshader")
		_warm_mat.render_priority = 0
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = preload("res://shaders/fire_glow.gdshader")
		_glow_mat.render_priority = 1
	var out: Array[MeshInstance3D] = []
	for m: ShaderMaterial in [_warm_mat, _glow_mat]:
		var mi := MeshInstance3D.new()
		mi.name = "GroundWarm" if m == _warm_mat else "GroundGlow"
		mi.mesh = _glow_mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.04, 0.0)
		mi.scale = Vector3(GLOW_M, 1.0, GLOW_M)
		out.append(mi)
	return out


## A unit card standing on its bottom edge.
static func _card_mesh() -> QuadMesh:
	if _card == null:
		_card = QuadMesh.new()
		_card.center_offset = Vector3(0, 0.5, 0)
	return _card


static func _flame_material(i: int) -> ShaderMaterial:
	while _flame_mats.size() < TONGUES.size():
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/flame.gdshader")
		m.set_shader_parameter("look_grain_soft", Look.grain())
		m.set_shader_parameter("phase", TONGUES[_flame_mats.size()][4])
		_flame_mats.append(m)
	return _flame_mats[i]


## Flicker the flames and light (call every frame with a running time).
static func flicker(camp: Node3D, time: float) -> void:
	var f := time * 9.0
	var k := 0.85 + 0.1 * sin(f) + 0.07 * sin(f * 2.3 + 1.0) + 0.05 * sin(f * 5.1)
	(camp.get_node("Flames") as Node3D).scale = Vector3(1.0, k, 1.0)
	(camp.get_node("Light") as OmniLight3D).light_energy = LIGHT_ENERGY * lerpf(DAY_SHARE, 1.0, night) * k

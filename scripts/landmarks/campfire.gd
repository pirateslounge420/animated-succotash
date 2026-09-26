class_name Campfire
## A campfire: a stone ring, crossed logs on a bed of glowing coals,
## flames, a warm light and a log to sit on (DESIGN.md: the warm "pop"
## against the blue night). Used by the camps (Camps) and the opening
## encampment.
##
## The flames are tongues of shaders/flame.gdshader: cards that turn to
## the camera, drawn additively, so they read as fire from any side and
## bloom. Each tongue has its own phase; all campfires share the three
## materials.

## [width, height, x, z, phase] of each tongue: a tall one in the middle,
## smaller ones around it.
const TONGUES := [[0.62, 1.0, 0.0, 0.0, 0.0], [0.42, 0.66, 0.13, 0.06, 1.7],
	[0.4, 0.6, -0.11, 0.08, 3.1], [0.36, 0.52, 0.02, -0.13, 4.6]]

static var _flame_mats: Array[ShaderMaterial] = []
static var _card: QuadMesh


## Build one on the ground at surface direction `d`, under `parent`
## (which must be in the scene tree). `warm` tints the light.
static func build(parent: Node3D, world: Node, chunks: ChunkManager, d: Vector3, warm: Color, seat := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	parent.add_child(root)
	root.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	root.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	for i in 8:
		var a := i * TAU / 8.0
		CreatureBodies.box(root, Vector3(0.28, 0.18, 0.22), Vector3(cos(a) * 0.62, 0.09, sin(a) * 0.62), Color(0.4, 0.4, 0.42)).rotation.y = a
	for i in 3:
		var l := CreatureBodies.cone(root, 0.06, 0.06, 0.9, Vector3(0, 0.12, 0), Color(0.3, 0.2, 0.12))
		l.rotation = Vector3(PI * 0.5, i * TAU / 3.0, 0)
	CreatureBodies.ball(root, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.08, 0), Color(1.0, 0.32, 0.08), 2.5) # coals
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
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = warm.lerp(Color(1.0, 0.55, 0.2), 0.5)
	light.light_energy = 3.2
	light.omni_range = 16.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	if seat:
		var log_seat := CreatureBodies.cone(root, 0.18, 0.18, 1.5, Vector3(0, 0.18, 2.0), Color(0.36, 0.25, 0.16))
		log_seat.rotation.z = PI * 0.5
	return root


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
	(camp.get_node("Light") as OmniLight3D).light_energy = 3.2 * k

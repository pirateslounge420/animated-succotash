class_name Campfire
## A campfire: a stone ring, crossed logs, flames, a warm light and a log
## to sit on (DESIGN.md: the warm "pop" against the blue night). Used by
## mythical folk camps (CreatureSpawner) and the opening encampment.


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
	var flames := Node3D.new()
	flames.name = "Flames"
	flames.position = Vector3(0, 0.15, 0)
	root.add_child(flames)
	CreatureBodies.cone(flames, 0.28, 0.0, 0.7, Vector3(0, 0.35, 0), Color(1.0, 0.45, 0.12), 6.0)
	CreatureBodies.cone(flames, 0.16, 0.0, 0.5, Vector3(0.06, 0.28, 0.04), Color(1.0, 0.85, 0.35), 8.0)
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


## Flicker the flames and light (call every frame with a running time).
static func flicker(camp: Node3D, time: float) -> void:
	var f := time * 9.0
	var k := 0.85 + 0.1 * sin(f) + 0.07 * sin(f * 2.3 + 1.0) + 0.05 * sin(f * 5.1)
	(camp.get_node("Flames") as Node3D).scale = Vector3(1.0, k, 1.0)
	(camp.get_node("Light") as OmniLight3D).light_energy = 3.2 * k

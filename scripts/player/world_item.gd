class_name WorldItem
extends Node3D
## A thing lying on the ground: something you set down (the inventory
## screen's G), a small bundle in the item's colors, or one of the folk's
## gifts by the fire where you wake (`gift`: the bow and the spear, drawn
## as themselves), until you take it (interact, right
## click, within PICK_M: main's interact). No physics; it sits on the
## ground below where it was dropped. Rides the floating origin with the
## world root it's parented to.

const PICK_M := 2.0

static var lying: Array[WorldItem] = []

var item: Dictionary
## Left for you by the folk who found you (main._lay_gifts()): "take the
## bow", not "take the bow back".
var gift := false


## Lay `it` on the ground at planet direction `up` (ground `ground` m
## above the datum: ChunkManager.ground_height()).
static func drop(it: Dictionary, world, up: Vector3, ground: float) -> WorldItem:
	var w := WorldItem.new()
	w.item = it
	world.world_root.add_child(w)
	w.global_position = world.to_scene(up, PlanetConst.RADIUS_M + ground + 0.06)
	w.look_at(w.global_position + CubeSphere.north(up), up)
	w.rotate(up, randf() * TAU)
	return w


static func in_reach(pos: Vector3, radius: float) -> WorldItem:
	var best: WorldItem = null
	var best_d := radius
	for w in lying:
		if not is_instance_valid(w):
			continue
		var d := w.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = w
	return best


func _ready() -> void:
	lying.append(self)
	# A tool lies there as itself, flat on the ground.
	var tool := _tool_mesh(str(item.get("kind", "")))
	if tool != null:
		add_child(tool)
		Bow._no_shadow(tool)
		return
	var cols := Inventory.colors(item)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.34
	mesh.radial_segments = 8
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cols[0]
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.rotation = Vector3(0, 0, PI * 0.5)
	add_child(mi)
	# A band of its second color, so a sample reads as tied up.
	var band := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.075
	tm.bottom_radius = 0.075
	tm.height = 0.04
	tm.radial_segments = 8
	band.mesh = tm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = cols[1]
	band.material_override = bm
	band.rotation = Vector3(0, 0, PI * 0.5)
	add_child(band)


## The bow or the spear, laid flat (null for anything
## else).
static func _tool_mesh(kind: String) -> Node3D:
	var n: Node3D = null
	match kind:
		"bow":
			n = BowMesh.build(1.3)
			n.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			n.position = Vector3(0, 0.02, 0)
		"spear":
			n = Spear.mesh()
			n.position = Vector3(0, 0.02, Spear.LENGTH * 0.5)
	return n


func _exit_tree() -> void:
	lying.erase(self)


## Taken back: returns the item and goes.
func pick_up() -> Dictionary:
	lying.erase(self)
	queue_free()
	return item

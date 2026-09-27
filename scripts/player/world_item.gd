class_name WorldItem
extends Node3D
## A carried thing set down on the ground (the inventory screen's G): a
## small bundle in the item's colors lying where you put it, until you take
## it back (E within PICK_M: main's interact). No physics; it sits on the
## ground below where it was dropped. Rides the floating origin with the
## world root it's parented to.

const PICK_M := 1.8

static var lying: Array[WorldItem] = []

var item: Dictionary


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


func _exit_tree() -> void:
	lying.erase(self)


## Taken back: returns the item and goes.
func pick_up() -> Dictionary:
	lying.erase(self)
	queue_free()
	return item

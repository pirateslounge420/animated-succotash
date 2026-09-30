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
	if tool == null and str(item.get("kind", "")) == "fuel":
		tool = _fuel_mesh(str(item.get("fuel", "branch")))
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


## A piece of fuel lying as itself (FuelField): a log, a branch, a bunch
## of brush or reeds, a dung pat, a peat block, a frond, a rib, a culm.
static func _fuel_mesh(kind: String) -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.36, 0.26, 0.16)
	var pale := Color(0.62, 0.56, 0.46)
	match kind:
		"hardwood_log", "softwood_log":
			var c := CreatureBodies.cone(n, 0.1, 0.09, 0.8, Vector3(0, 0.1, 0), wood if kind == "hardwood_log" else Color(0.5, 0.36, 0.2))
			c.rotation = Vector3(PI * 0.5, 0, 0)
		"branch":
			var c := CreatureBodies.cone(n, 0.035, 0.02, 0.9, Vector3(0, 0.035, 0), wood, 0.0, 6)
			c.rotation = Vector3(PI * 0.5, 0.3, 0)
		"brush", "reeds", "grass_bundle", "palm_frond":
			var col := Color(0.42, 0.34, 0.2) if kind == "brush" else (Color(0.62, 0.55, 0.3) if kind != "palm_frond" else Color(0.45, 0.42, 0.2))
			for i in 4:
				var c := CreatureBodies.cone(n, 0.014, 0.008, 0.7 if kind != "palm_frond" else 1.1, Vector3(0.03 * (i - 1.5), 0.02 + 0.01 * i, 0), col, 0.0, 5)
				c.rotation = Vector3(PI * 0.5, 0.12 * (i - 1.5), 0)
		"dung":
			CreatureBodies.ball(n, Vector3(0.16, 0.05, 0.14), Vector3(0, 0.05, 0), Color(0.3, 0.24, 0.14))
		"peat":
			CreatureBodies.box(n, Vector3(0.3, 0.12, 0.16), Vector3(0, 0.06, 0), Color(0.2, 0.15, 0.1))
		"driftwood":
			var c := CreatureBodies.cone(n, 0.06, 0.03, 0.9, Vector3(0, 0.06, 0), pale, 0.0, 7)
			c.rotation = Vector3(PI * 0.5, 0.5, 0)
		"bamboo":
			var c := CreatureBodies.cone(n, 0.04, 0.04, 1.2, Vector3(0, 0.04, 0), Color(0.6, 0.6, 0.3), 0.0, 8)
			c.rotation = Vector3(PI * 0.5, 0, 0)
		"cactus_rib":
			var c := CreatureBodies.cone(n, 0.03, 0.02, 0.8, Vector3(0, 0.03, 0), Color(0.68, 0.64, 0.5), 0.0, 6)
			c.rotation = Vector3(PI * 0.5, 0, 0)
		_:
			var c := CreatureBodies.cone(n, 0.04, 0.03, 0.7, Vector3(0, 0.04, 0), wood, 0.0, 6)
			c.rotation = Vector3(PI * 0.5, 0, 0)
	return n


func _exit_tree() -> void:
	lying.erase(self)


## Taken back: returns the item and goes.
func pick_up() -> Dictionary:
	lying.erase(self)
	queue_free()
	return item

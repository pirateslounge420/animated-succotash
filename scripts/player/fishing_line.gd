class_name FishingLine
extends Node3D
## Line and hook (design 30 Sept §BP, technique fishing_line): the patient
## way to fish, beside the spear's lunge and throw. Made from a branch
## and a twist of grass or reed (main: right click water with both in
## the pack and the technique known): a pole (item kind pole, Q brings
## it to hand). With it in hand, left click toward water within cast_m:
## the float lands on the water and rides there; a bite comes after
## bite_s (the float dips); click within hook_window_s to land the fish
## (item kind fish, food for you or a camp's store), else the bite is
## missed and the wait starts again. Left click with the line out brings
## it in. Swapping away, climbing or swimming brings it in.

static var P: Dictionary = Techniques.params("fishing_line")

var player: PlanetPlayer
var out := false
var bite := false
var _float: MeshInstance3D
var _view: Node3D
var _line: MeshInstance3D
var _im := ImmediateMesh.new()
var _float_pos := Vector3.ZERO
var _float_up := Vector3.UP
var _wait := 0.0
var _bite_t := 0.0
var _t := 0.0
var _hold := false
var _rng := RandomNumberGenerator.new()


func setup(p: PlanetPlayer) -> void:
	player = p
	_rng.randomize()
	# First person: the pole out of the right hand, tip up and out.
	_view = Node3D.new()
	_view.name = "PoleView"
	var cane := CreatureBodies.cone(_view, 0.014, 0.006, 2.2, Vector3.ZERO, Color("#b99c5c"), 0.0, 6)
	cane.position = Vector3(0, 1.1, 0)
	_view.position = Vector3(0.38, -0.42, -0.5)
	_view.rotation = Vector3(-0.9, 0.25, 0.3)
	_view.visible = false
	var cam := player.camera()
	if cam:
		cam.add_child(_view)
	else:
		add_child(_view)
	_float = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	_float.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#c8281e")
	_float.material_override = m
	_float.visible = false
	add_child(_float)
	_line = MeshInstance3D.new()
	_line.mesh = _im
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.9, 0.9, 0.85)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = lm
	_line.visible = false
	add_child(_line)


func in_hand() -> bool:
	return player.weapon == "pole" and player.inventory.has_kind("pole")


## Where a cast would land: the look ray's water within cast_m, or ZERO.
func cast_point() -> Vector3:
	var cam := player.camera()
	if cam == null:
		return Vector3.ZERO
	var from := cam.global_position
	var dirv := -cam.global_basis.z
	var reach := float(P.get("cast_m", 12.0))
	# March the ray and find the water surface along it.
	var steps := 24
	for i in range(1, steps + 1):
		var p := from + dirv * reach * i / steps
		var d: Vector3 = player.world.dir_of(p)
		var r: float = player.world.radius_of(p)
		var water: float = player.chunks.water_level_at(d)
		var ground: float = player.chunks.ground_height(d)
		if water > ground + 0.3 and r <= PlanetConst.RADIUS_M + water:
			return player.world.to_scene(d, PlanetConst.RADIUS_M + water)
		if r <= PlanetConst.RADIUS_M + ground:
			return Vector3.ZERO
	return Vector3.ZERO


func cast() -> bool:
	var at := cast_point()
	if at == Vector3.ZERO:
		return false
	out = true
	bite = false
	_float_pos = at
	_float_up = player.world.dir_of(at)
	var b = P.get("bite_s", [8.0, 30.0])
	_wait = _rng.randf_range(float(b[0]), float(b[1]))
	_float.visible = true
	_line.visible = true
	player.make_noise(0.2)
	return true


func reel_in() -> void:
	out = false
	bite = false
	_float.visible = false
	_line.visible = false


func update_line(delta: float) -> void:
	_t += delta
	var held := in_hand() and player.first_person and not player.climbing
	_view.visible = held
	if not held or player.swimming or player.climbing or player.dead:
		if out:
			reel_in()
		_hold = Input.is_action_pressed("shoot")
		return
	var press := Input.is_action_just_pressed("shoot") and not player.ui_open
	if press:
		if not out:
			cast()
		elif bite:
			# Hooked: a fish.
			var fish := Inventory.make("fish", {"title": "Fish"})
			if player.inventory.add(fish):
				GameLog.add("Landed a fish on the line.", "fishing")
			reel_in()
		else:
			reel_in()
	if not out:
		return
	# The float rides the water; the bite comes, the window closes.
	var bob := 0.03 * sin(_t * 2.1)
	if bite:
		_bite_t -= delta
		bob = -0.12 + 0.04 * sin(_t * 9.0)
		if _bite_t <= 0.0:
			bite = false
			var b = P.get("bite_s", [8.0, 30.0])
			_wait = _rng.randf_range(float(b[0]), float(b[1]))
	else:
		_wait -= delta
		if _wait <= 0.0:
			bite = true
			_bite_t = float(P.get("hook_window_s", 2.0))
			player.make_noise(0.05)
	_float.global_position = _float_pos + _float_up * bob
	# The line from the pole's tip to the float.
	var tip: Vector3 = _view.global_position + _view.global_basis.y * 2.2 if _view.is_inside_tree() else player.global_position + player.up * 1.5
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var last := tip
	for i in range(1, 9):
		var k := i / 8.0
		var p := tip.lerp(_float.global_position, k) - _float_up * 0.35 * sin(k * PI)
		_im.surface_add_vertex(last)
		_im.surface_add_vertex(p)
		last = p
	_im.surface_end()

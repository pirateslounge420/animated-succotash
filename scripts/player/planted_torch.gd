class_name PlantedTorch
extends Node3D
## A torch stood in the ground (design 30 Sept §AW: right click the ground
## with a lit torch), or dropped lying, burning on where it is: a stick,
## a glowing ember (Torch.ember_node) and a point light, burning down by the same rules as the one in
## hand (Torch.burn_step); a light source for the dark (§BA) and an ember
## another torch can be lit at. Right click within pickup_reach_m takes it
## back (take()). Under World.world_root, so it rides the floating origin.
## In Torchfire 1 its head is the pitch torch's (design 6 Oct §EZ.2,
## PitchTorch): the wrap, and lit, its coal and a true-size flame that
## leans toward an airway's draft; the tombs have no world_root, so it
## stands under the scene it is given.

static var all: Array[PlantedTorch] = []

var item: Dictionary
var lying := false
var up := Vector3.UP
## The pitch torch (Torchfire 1, §EZ.2): its head is PitchTorch's.
var pitch := false
var lean := PitchTorch.Lean.new()
## The head: the burnt end (open world) or the pitch head.
var _flame: Node3D
var _light: OmniLight3D
var _t := randf() * 10.0


## Stand `it` at `scene_pos` under World.world_root, or under `parent` when
## given (the tombs have no world_root, design 6 Oct §ET).
static func plant(it: Dictionary, world, scene_pos: Vector3, planet_up: Vector3, lie := false, parent: Node = null) -> PlantedTorch:
	var p := PlantedTorch.new()
	p.item = it
	p.lying = lie
	p.up = planet_up
	(parent if parent != null else world.world_root).add_child(p)
	p.global_position = scene_pos
	p.global_basis = Basis.looking_at(CubeSphere.north(planet_up), planet_up)
	if lie:
		p.rotate_object_local(Vector3.RIGHT, PI * 0.5 - 0.08)
	all.append(p)
	return p


func _ready() -> void:
	var h := float(Tuning.section("torch", "planted").get("stand_height_m", 0.9))
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.028
	cm.height = h
	cm.radial_segments = 6
	stick.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.36, 0.25, 0.14)
	sm.roughness = 1.0
	# No shine (the R-rules: no specular).
	sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	stick.material_override = sm
	stick.position = Vector3(0, h * 0.5 - (0.15 if not lying else 0.0), 0)
	stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stick)
	pitch = GameMode.crawler_running
	if pitch:
		# The pitch head (§EZ.2) round the stick's last length_m, its flame
		# at the torch's true size (look.json fire.flame.torch.scale).
		_flame = PitchTorch.head_node(cm.top_radius, int(_t * 1000.0), true)
		_flame.position = Vector3(0, stick.position.y + h * 0.5 - PitchTorch.length_m() * 0.9, 0)
	else:
		# The head: the stick's burnt end, smouldering (Mike, 3 Oct).
		_flame = Torch.ember_node(cm.top_radius, 0.09, 0.32)
		_flame.position = Vector3(0, stick.position.y + h * 0.5 - 0.09 * 0.4, 0)
	add_child(_flame)
	_light = Torch.light_node()
	_light.position = Vector3(0, h + 0.05, 0)
	add_child(_light)
	_apply()


func lit() -> bool:
	return bool(item.get("lit", false))


func _apply() -> void:
	if pitch:
		# The wrap shows lit or not; burnt out, a bare stick, as built.
		_flame.visible = not bool(item.get("burnt", false))
		PitchTorch.set_lit(_flame, lit())
	else:
		_flame.visible = lit()
	_light.visible = lit()


func _process(delta: float) -> void:
	if not lit():
		return
	_t += delta
	var what := Torch.burn_step(item, delta, Torch.weather, false)
	if what == "out":
		GameLog.add("A planted torch has burnt out.", "torch")
		_apply()
		return
	_light.light_energy = Torch.energy_now(item, _t, 1.0)
	_light.light_color = Torch.gutter_color(1.0 if Torch.guttering(item) else 0.0)
	if pitch:
		# Still in the ground, only an airway's draft leans its flame
		# (§EV.3; flat out in a strong mouth's gust, §EZ.5); the light
		# flickers with the flame and breathes with the coal (§EZ.2).
		var draft := Vector3.ZERO
		var whip := false
		if PitchTorch.toward_draft() and TorchSnuff.drafts != null and is_instance_valid(TorchSnuff.drafts):
			var d: Dictionary = TorchSnuff.drafts.call("draft_at", _flame.global_position)
			draft = d.get("lean", Vector3.ZERO)
			whip = bool(d.get("gust", false))
		lean.step(draft, up, delta, whip)
		_light.light_energy *= PitchTorch.flicker(_t, float(get_instance_id() % 1000), lean.air_share)
		PitchTorch.set_glow(_flame, Torch.ember_glow(item, _t, 1.0), item)
		PitchTorch.set_low(_flame, PitchTorch.GUTTER_LOW if Torch.guttering(item) else 0.0)
		PitchTorch.pose(_flame, lean, up)
		PitchTorch.smoke(_flame, up)
	else:
		Torch.set_glow(_flame, Torch.ember_glow(item, _t, 1.0), item)
		Torch.smoke_ember(_flame, up)


## The nearest planted torch within `radius` of `pos`, or null.
static func in_reach(pos: Vector3, radius: float) -> PlantedTorch:
	var best: PlantedTorch = null
	var best_d := radius
	for p in all:
		if not is_instance_valid(p):
			continue
		var d := p.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


## A planted torch gone out (not burnt to a stick) within `radius` of
## `pos`: the swing of a lit torch lights it again (§CN).
static func unlit_near(pos: Vector3, radius: float) -> PlantedTorch:
	for p in all:
		if is_instance_valid(p) and not p.lit() and not bool(p.item.get("burnt", false)) and p.global_position.distance_to(pos) < radius:
			return p
	return null


func relight() -> void:
	item["lit"] = true
	if not item.has("burn_left_min"):
		item["burn_left_min"] = Torch.full_burn_min()
	_apply()


## A lit planted torch within `radius` of `pos`?
static func lit_near(pos: Vector3, radius: float) -> bool:
	for p in all:
		if is_instance_valid(p) and p.lit() and p.global_position.distance_to(pos) < radius:
			return true
	return false


## Torchlight at `pos` from the planted ones (0-1, the brightest).
static func light_at(pos: Vector3) -> float:
	var best := 0.0
	var range_m := float(Tuning.section("torch", "light").get("range_m", 14.0))
	for p in all:
		if is_instance_valid(p) and p.lit():
			best = maxf(best, clampf(1.0 - p.global_position.distance_to(pos) / range_m, 0.0, 1.0) * Torch.share_now(p.item))
	return best


## Taken back: gone from the ground, the torch as it is.
func take() -> Dictionary:
	all.erase(self)
	queue_free()
	return item


func _exit_tree() -> void:
	all.erase(self)

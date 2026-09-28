class_name PlayerCorpse
extends Node3D
## Where you died (design reconciliation, "Death and respawn"): your body
## stays where it fell, slumped on its face with the cloak over it, holding
## everything you carried and wore. You wake at a fire with nothing; E by
## the body takes it all back, and the body is gone. No map pin, no
## marker: you find it by going back the way you came.
##
## The world acts on it: after a while scavengers gather, birds circling
## high over it (visible from a way off, which helps you look), their calls
## now and then. Numbers: data/combat.json "death".
##
## Rides the floating origin with the world root it's parented to; lasts
## until recovered (Phase 12 persistence decides how long past a session).

static var lying: Array[PlayerCorpse] = []

## The inventory it holds: carried things and worn gear, as Inventory
## holds them.
var carried: Array = []
var worn := {}

var _time := 0.0
var _birds: Array[Node3D] = []
var _voice: AudioStreamPlayer3D
var _call_t := 0.0
var _up := Vector3.UP


## The body at `pos` (scene), taking everything in `inv` (which is left
## empty).
static func drop(world, pos: Vector3, facing: Basis, inv: Inventory) -> PlayerCorpse:
	var c := PlayerCorpse.new()
	c.carried = inv.carried.duplicate()
	c.worn = inv.worn.duplicate(true)
	world.world_root.add_child(c)
	c.global_position = pos
	c.global_basis = facing
	c._up = world.dir_of(pos)
	for i in inv.carried.size():
		inv.carried[i] = null
	for slot in inv.worn:
		(inv.worn[slot] as Array).fill(null)
	return c


static func in_reach(pos: Vector3, radius: float) -> PlayerCorpse:
	for c in lying:
		if is_instance_valid(c) and c.global_position.distance_to(pos) < radius:
			return c
	return null


func _ready() -> void:
	lying.append(self)
	var body := PlayerBody.new()
	body.scale = Vector3.ONE * PlanetPlayer.BODY_K
	add_child(body)
	# Slumped on its face, as you fell.
	body.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	body.position = Vector3(0, 0.2, 0)
	_voice = Audio3D.make("wildlife_call", self, "Scavengers")
	_voice.position = Vector3(0, 18, 0)


func _exit_tree() -> void:
	lying.erase(self)


func _process(delta: float) -> void:
	_time += delta
	var d := Tuning.section("combat", "death")
	if _time < float(d.get("scavenger_delay_s", 45.0)):
		return
	if _birds.is_empty():
		for i in int(d.get("scavenger_count", 3)):
			_birds.append(_bird())
	var r := float(d.get("circle_radius_m", 8.0))
	var h := float(d.get("circle_height_m", 18.0))
	var up := global_basis.y
	var side := global_basis.x
	var fwd := global_basis.z
	for i in _birds.size():
		var a := _time * 0.35 + TAU * i / _birds.size()
		var rr := r * (0.8 + 0.25 * i)
		var p := (side * cos(a) + fwd * sin(a)) * rr + up * (h + 2.0 * sin(_time * 0.3 + i))
		var b := _birds[i]
		b.position = global_basis.inverse() * p
		var tangent := (-side * sin(a) + fwd * cos(a))
		b.basis = Basis.looking_at(global_basis.inverse() * tangent, Vector3.UP).rotated(Vector3.FORWARD, 0.35)
		var flap := sin(_time * 7.0 + i * 1.7)
		(b.get_child(0) as Node3D).rotation.z = 0.25 + 0.5 * flap
		(b.get_child(1) as Node3D).rotation.z = -0.25 - 0.5 * flap
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = randf_range(6.0, 14.0)
		_voice.stream = SoundSynth.stream("call", randi())
		_voice.pitch_scale = randf_range(0.55, 0.7)
		_voice.play()


## A dark bird: a body and two wings that flap.
func _bird() -> Node3D:
	var b := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.14)
	mat.roughness = 1.0
	for s in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.7, 0.03, 0.28)
		wing.mesh = m
		wing.material_override = mat
		var pivot := Node3D.new()
		pivot.add_child(wing)
		wing.position = Vector3(0.35 * s, 0, 0)
		b.add_child(pivot)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.09
	bm.height = 0.5
	body.mesh = bm
	body.rotation = Vector3(PI * 0.5, 0, 0)
	body.material_override = mat
	b.add_child(body)
	add_child(b)
	return b


## Take your things back into `inv`: worn gear into its slots, carried
## things into free carry slots. What doesn't fit stays; once it's all
## taken, the body is gone. True if anything was taken.
func recover(inv: Inventory) -> bool:
	var took := false
	for slot in worn:
		var a: Array = worn[slot]
		for i in a.size():
			if a[i] != null and inv.wear(a[i]):
				a[i] = null
				took = true
	for i in carried.size():
		if carried[i] != null and inv.add(carried[i]):
			carried[i] = null
			took = true
	var left := carried.any(func(x) -> bool: return x != null)
	for slot in worn:
		if (worn[slot] as Array).any(func(x) -> bool: return x != null):
			left = true
	if not left:
		lying.erase(self)
		queue_free()
	return took

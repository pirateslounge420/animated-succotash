class_name PlayerFires
extends Node
## What the player lays with fire carried (design 30 Sept §BP): a fire
## laid from the ember carrier (a small hearth, FireStore untended, two
## units to start, feed it like any fire), and a fat lamp set down (a
## dim light for hours that never blows out). Kept per world (WorldSave
## "fires", "lamps") and built round the player as they come into reach.

const BUILD_M := 400.0

var world: Node
var chunks: ChunkManager
var player: Node3D
var _root: Node3D
var _built := {}
var _timer := 0.0


func setup(p_world: Node, p_chunks: ChunkManager, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	player = p_player
	_root = Node3D.new()
	_root.name = "PlayerFires"
	world.world_root.add_child(_root)
	for k in ["fires", "lamps"]:
		if not WorldSave.data.get(k, null) is Array:
			WorldSave.data[k] = []


## Lay a fire at `d` from a live ember: a hearth with fire_units of the
## people's kind on it, burning untended (full rate).
func lay_fire(d: Vector3, units: int) -> Node3D:
	var rec := {"dir": [d.x, d.y, d.z], "day": world.days}
	(WorldSave.data["fires"] as Array).append(rec)
	WorldSave.mark_dirty()
	var key := FireStore.key_of(d)
	var fuel: Array = []
	for i in units:
		fuel.append(["branch", FireStore.burn_min("branch")])
	FireStore.stores[key] = {"units": fuel, "embers_min": 0.0, "state": "flames", "tended": false}
	return _build_fire(rec)


func place_lamp(d: Vector3, hours: float) -> Node3D:
	var rec := {"dir": [d.x, d.y, d.z], "lit": world.days, "until": world.days + hours / 24.0}
	(WorldSave.data["lamps"] as Array).append(rec)
	WorldSave.mark_dirty()
	return _build_lamp(rec)


func _key(rec: Dictionary, kind: String) -> String:
	return "%s:%s" % [kind, str(rec.dir)]


func _build_fire(rec: Dictionary) -> Node3D:
	var a: Array = rec.dir
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	var n := Campfire.build(_root, world, chunks, d, false)
	n.set_meta("player_fire", true)
	_built[_key(rec, "fire")] = n
	return n


func _build_lamp(rec: Dictionary) -> Node3D:
	var a: Array = rec.dir
	var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	var n := Node3D.new()
	n.name = "FatLamp"
	_root.add_child(n)
	n.global_position = world.to_scene(d, PlanetConst.RADIUS_M + chunks.ground_height(d))
	n.global_basis = Basis.looking_at(CubeSphere.north(d), d)
	CreatureBodies.ball(n, Vector3(0.14, 0.06, 0.14), Vector3(0, 0.05, 0), Color(0.45, 0.45, 0.47))
	var p: Dictionary = Techniques.params("fat_lamp")
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.35)
	l.light_energy = float(p.get("energy", 0.8))
	l.omni_range = float(p.get("range_m", 6.0))
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = Vector3(0, 0.12, 0)
	n.add_child(l)
	var flame := Torch.flame_node(0.12)
	# Its base in the dish's fat (the dish is 0.06 tall at y 0.05; §CA).
	flame.position = Vector3(0, 0.07, 0)
	n.add_child(flame)
	n.set_meta("rec", rec)
	_built[_key(rec, "lamp")] = n
	return n


func _process(delta: float) -> void:
	if world == null:
		return
	# Flicker the lamps and the player's fires every frame (Campfire.flicker).
	var t := Time.get_ticks_msec() / 1000.0
	for k in _built:
		var fn: Node3D = _built[k]
		if is_instance_valid(fn) and fn.has_node("Flames"):
			Campfire.flicker(fn, t)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var pd: Vector3 = world.dir_of(player.global_position)
	for rec in WorldSave.data.get("fires", []):
		var a: Array = rec.dir
		var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		var near := CubeSphere.surface_distance_m(d, pd) < BUILD_M
		var k := _key(rec, "fire")
		if near and not _built.has(k):
			_build_fire(rec)
		elif not near and _built.has(k):
			NodeRelease.free_later(_built[k])
			_built.erase(k)
	var lamps: Array = WorldSave.data.get("lamps", [])
	for rec in lamps.duplicate():
		var a: Array = rec.dir
		var d := Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
		var k := _key(rec, "lamp")
		if world.days >= float(rec.get("until", 0.0)):
			# Burnt out: gone, the bowl with it.
			if _built.has(k):
				NodeRelease.free_later(_built[k])
				_built.erase(k)
			lamps.erase(rec)
			WorldSave.mark_dirty()
			continue
		var near := CubeSphere.surface_distance_m(d, pd) < BUILD_M
		if near and not _built.has(k):
			_build_lamp(rec)
		elif not near and _built.has(k):
			NodeRelease.free_later(_built[k])
			_built.erase(k)

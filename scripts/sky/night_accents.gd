class_name NightAccents
extends Node3D
## Two emissive ambient props, only at night, only where they belong
## (design §BU step 6, data/night_accents.json): glowing moss hanging from
## the willows of the swamps and bogs, and a drifting swarm of blue
## butterflies at the ruins of the temperate forests. Both cold light; the
## fire stays the only warm light. Built round the player once the sky's
## daylight falls under shows_below_daylight, freed by day or when far.

var world: Node
var chunks: ChunkManager
var landmarks: Landmarks
var sky: SkySystem
var player: Node3D
static var D: Dictionary = {}
var _moss := {} # graph key -> Node3D
var _swarms := {} # ruin cell -> Node3D
var _timer := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


static func data() -> Dictionary:
	if D.is_empty():
		var f := FileAccess.open("res://data/night_accents.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			D = parsed if parsed is Dictionary else {}
	return D


func setup(p_world: Node, p_chunks: ChunkManager, p_landmarks: Landmarks, p_sky: SkySystem, p_player: Node3D) -> void:
	world = p_world
	chunks = p_chunks
	landmarks = p_landmarks
	sky = p_sky
	player = p_player
	_rng.seed = 7


func _process(delta: float) -> void:
	_time += delta
	_timer -= delta
	var dark := sky != null and sky.daylight < float(data().get("shows_below_daylight", 0.35))
	if _timer <= 0.0:
		_timer = 0.5
		_refresh(dark)
	# Flicker and flight.
	var mossd: Dictionary = data().get("glow_moss", {})
	var fl := float(mossd.get("flicker", 0.2))
	for k in _moss:
		var n: Node3D = _moss[k]
		for s in n.get_children():
			if s is MeshInstance3D:
				var ph: float = s.get_meta("phase", 0.0)
				(s as MeshInstance3D).transparency = clampf(fl * (0.5 + 0.5 * sin(_time * 0.7 + ph)), 0.0, 0.6)
	for k in _swarms:
		_fly(_swarms[k], delta)


func _refresh(dark: bool) -> void:
	if not dark or player == null:
		for k in _moss.keys():
			NodeRelease.free_later(_moss[k])
		_moss.clear()
		for k in _swarms.keys():
			NodeRelease.free_later(_swarms[k])
		_swarms.clear()
		return
	var pp := player.global_position
	# Moss on the willows of the swamps.
	var mossd: Dictionary = data().get("glow_moss", {})
	var range_m := float(mossd.get("range_m", 60.0))
	var genera: Array = mossd.get("genera", ["Salix"])
	var biomes: Array = mossd.get("biomes", ["SWAMP", "BOG"])
	var keep := {}
	for key in chunks.chunks:
		var chunk: TerrainChunk = chunks.chunks[key]
		if chunk.trees.is_empty() or chunk.global_position.distance_to(pp) > range_m + 400.0:
			continue
		for i in chunk.trees.size():
			var base := chunk.tree_base(i)
			if base.distance_to(pp) > range_m:
				continue
			var sp := chunk.tree_species(i)
			if not genera.has(sp.genus):
				continue
			var gk := chunk.graph_key(i)
			keep[gk] = true
			if _moss.has(gk):
				continue
			var d: Vector3 = world.dir_of(base)
			if not biomes.has(FireStore.biome_key(world, d)):
				continue
			_moss[gk] = _hang_moss(chunk, i, mossd)
	for k in _moss.keys():
		if not keep.has(k):
			NodeRelease.free_later(_moss[k])
			_moss.erase(k)
	# Butterflies at the ruins of the temperate forests.
	var bd: Dictionary = data().get("blue_butterflies", {})
	var brange := float(bd.get("range_m", 90.0))
	var bbiomes: Array = bd.get("biomes", [])
	var keep_r := {}
	var ruins := landmarks.built_ruins()
	for c in ruins:
		var rn: Node3D = ruins[c]
		if rn.global_position.distance_to(pp) > brange:
			continue
		keep_r[c] = true
		if _swarms.has(c):
			continue
		var site: Dictionary = rn.get_meta("site", {})
		if site.is_empty() or not bbiomes.has(FireStore.biome_key(world, site.dir)):
			continue
		_swarms[c] = _swarm(rn, bd)
	for c in _swarms.keys():
		if not keep_r.has(c):
			NodeRelease.free_later(_swarms[c])
			_swarms.erase(c)


## Strands of glowing moss hung under the crown's base, round the trunk.
func _hang_moss(chunk: TerrainChunk, i: int, mossd: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "GlowMoss"
	add_child(n)
	var base := chunk.tree_base(i)
	var up := chunk.tree_up(i)
	var h := float(chunk.trees[i][1])
	n.global_transform = Transform3D(Basis.looking_at(CubeSphere.north(world.dir_of(base)), world.dir_of(base)), base)
	var col := Color(str(mossd.get("color", "#5CF0C8")))
	var sr = mossd.get("strands", [6, 12])
	var lr = mossd.get("length_m", [0.6, 2.4])
	var energy := float(mossd.get("energy", 1.4))
	var count := _rng.randi_range(int(sr[0]), int(sr[1]))
	for k in count:
		var a := TAU * k / count + _rng.randf_range(-0.3, 0.3)
		var r := h * _rng.randf_range(0.08, 0.22)
		var y := h * _rng.randf_range(0.45, 0.7)
		var len := _rng.randf_range(float(lr[0]), float(lr[1]))
		var local := n.to_local(base + up * y) + Vector3(cos(a), 0, sin(a)) * r
		var s := CreatureBodies.cone(n, 0.035, 0.012, len, local - Vector3(0, len * 0.5, 0), col, energy, 5)
		s.set_meta("phase", _rng.randf() * TAU)
	return n


## A swarm of small glowing quads drifting round the ruin, flapping.
func _swarm(ruin: Node3D, bd: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "BlueButterflies"
	add_child(n)
	n.global_transform = ruin.global_transform
	var col := Color(str(bd.get("color", "#3C64FF")))
	var quad := QuadMesh.new()
	var size := float(bd.get("size_m", 0.14))
	quad.size = Vector2(size, size * 0.8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = float(bd.get("energy", 1.8))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = int(bd.get("count", 24))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	n.add_child(mmi)
	var seeds: Array = []
	for k in mm.instance_count:
		seeds.append([_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf_range(0.6, 1.0), _rng.randf() * TAU])
	n.set_meta("seeds", seeds)
	n.set_meta("mm", mm)
	n.set_meta("radius", float(bd.get("radius_m", 9.0)))
	var hr = bd.get("height_m", [0.8, 4.0])
	n.set_meta("h0", float(hr[0]))
	n.set_meta("h1", float(hr[1]))
	n.set_meta("speed", float(bd.get("speed_mps", 0.6)))
	return n


func _fly(n: Node3D, _delta: float) -> void:
	var mm: MultiMesh = n.get_meta("mm")
	var seeds: Array = n.get_meta("seeds")
	var r: float = n.get_meta("radius")
	var h0: float = n.get_meta("h0")
	var h1: float = n.get_meta("h1")
	var sp: float = n.get_meta("speed")
	for k in mm.instance_count:
		var s: Array = seeds[k]
		var t := _time * sp * 0.25 * float(s[2])
		var a: float = s[0] + t
		var rad: float = r * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.7 + float(s[1]))))
		var y: float = lerpf(h0, h1, 0.5 + 0.5 * sin(t * 1.3 + float(s[3])))
		var pos := Vector3(cos(a) * rad, y, sin(a) * rad)
		var flap := 0.35 + 0.65 * absf(sin(_time * 9.0 + float(s[3]) * 3.0))
		var basis := Basis(Vector3.UP, a + PI * 0.5).scaled(Vector3(flap, 1.0, 1.0))
		mm.set_instance_transform(k, Transform3D(basis, pos))

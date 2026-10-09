class_name RelightGate
extends Node3D
## A relight gate (design §ET.4: "a passage that opens once it is relit";
## crawler.json gates.kinds relight_to_open; §EX.5 narrows gates to side
## ways and shortcuts, never the only way out): the first one built, the
## fork's (Fork, design §FM.6). A plain stone seal standing in a doorway:
## one slab of the ruin's one stone (§EX.1, RuinStyle), set back in the
## door's frame with its edges hidden in the jambs and the lintel, nothing
## carved on it, no light, no glow (§FG: nothing points to it). It shuts the
## doorway to bodies and to rays (its collision on the world's layer) and,
## through the Fork, to whatever walks the floor grid (TombNav.close_door)
## or the graph of the light (BossGround.shut).
##
## Opened (open), it sinks straight down into the floor of its doorway
## over descent.json fork.seal.open_s, slow to start as a heavy stone is,
## with a grinding of stone heard a long way down the passages (audio.json
## stone_seal) and a thud as it settles; its collision goes down with it,
## and once it is under the floor it is gone (`gone` fires). Opened from a
## save (quiet) it is simply gone, without a sound.

## Its whole way down done: under the floor, no collision left.
signal gone(gate: RelightGate)

static var SEAL: Dictionary = (Tuning.table("descent").get("fork", {}) as Dictionary).get("seal", {})
static var _grind := {}

## The doorway it stands in (lay.doors).
var door: Dictionary = {}
var opened := false
## The physics frame it began to open on (-1 while shut): the fork opens
## its seals together, on one tick.
var opened_frame := -1
## How far down it has gone: 0 standing, 1 under the floor.
var sunk := 0.0
var is_gone := false
var body: StaticBody3D
var slab: MeshInstance3D
var voice: AudioStreamPlayer3D
## Times its grinding has started (the checks: an opening you hear).
var sounded := 0
## The slab's size (m): across the doorway, up, through the wall.
var size := Vector3.ONE
var _open_s := 3.0


## The seal in door `door_id` of `lay` (TombKit's doors: a centred
## trapezoid opening `half` either side of its middle at its foot, `h`
## high from its floor `y`).
func build(lay: Dictionary, door_id: int) -> void:
	door = lay.doors[door_id]
	name = "Seal%d" % door_id
	_open_s = maxf(float(SEAL.get("open_s", 3.0)), 0.1)
	var p: Vector2 = door.p
	var nv: Vector2 = door.n
	var y := float(door.y)
	var h := float(door.h)
	# Along the wall, up, through it (TombBuild._doorway's frame).
	var t := Vector3(-nv.y, 0.0, nv.x)
	var bs := Basis(t, Vector3.UP, t.cross(Vector3.UP))
	# Into the jambs either side and up under the lintel, so no edge of it
	# shows; its foot just under the threshold's top.
	size = Vector3(2.0 * float(door.half) + 0.16, h + 0.12, clampf(float(SEAL.get("thick_m", 0.36)), 0.1, Delves.WALL - 0.08))
	transform = Transform3D(bs, Vector3(p.x, y - 0.02, p.y))
	slab = MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = _slab_mesh(lay, door_id)
	slab.material_override = RuinBuilder.material_lit()
	add_child(slab)
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = PropCollision.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(cs)
	add_child(body)
	voice = Audio3D.make("stone_seal", self, "Grind")
	voice.stream = grind_stream(_open_s)
	voice.position = Vector3(0.0, size.y * 0.5, 0.0)
	set_process(false)


## The slab: one block of the ruin's stone (the tomb's builder's own box,
## its own dice), standing on its foot at the node's origin.
func _slab_mesh(lay: Dictionary, door_id: int) -> ArrayMesh:
	var b := TombBuild.new()
	b._lay = lay
	b.rng.seed = hash([int(lay.get("seed", 0)), "seal", door_id])
	b.up = Vector3.UP
	b.ex = Vector3.RIGHT
	b.ez = Vector3.BACK
	var th := str(lay.get("theme", "tomb"))
	FittedStone.theme = th
	RuinStyle.theme = th
	b.palette = [TombBuild.POISON, TombBuild.POISON, TombBuild.POISON, TombBuild.POISON, TombBuild.POISON] if TombBuild.poison else RuinStyle.tones(th)
	b.shade = 0.0
	b._stone_mode()
	b.solid = false
	b.box(Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0)), size, RuinStyle.stone(b.rng), 0.0, 0.04, 0.02)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b._v
	arrays[Mesh.ARRAY_NORMAL] = b._n
	arrays[Mesh.ARRAY_COLOR] = b._c
	arrays[Mesh.ARRAY_TEX_UV] = b._m
	RuinBuilder._flip_winding(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The rids it blocks with (its collision): the floor grid casts through
## them (Residents.see_through), the gate shutting its squares itself.
func rids() -> Array[RID]:
	var out: Array[RID] = []
	if body != null:
		out.append(body.get_rid())
	return out


## Open: it starts down at once, grinding (`quiet`: gone at once, without a
## sound, as when a save says it was opened before).
func open(quiet := false) -> void:
	if opened:
		return
	opened = true
	opened_frame = Engine.get_physics_frames()
	if quiet:
		_set_sunk(1.0)
		return
	if voice != null and voice.is_inside_tree():
		Audio3D.play(voice)
		sounded += 1
	set_process(true)


func _process(delta: float) -> void:
	if not opened or is_gone:
		set_process(false)
		return
	_set_sunk(sunk + delta / _open_s)


## Down `k` of its way (0-1): eased, slow to start and slow to settle.
func _set_sunk(k: float) -> void:
	sunk = clampf(k, 0.0, 1.0)
	var down := sunk * sunk * (3.0 - 2.0 * sunk) * (size.y + 0.1)
	slab.position.y = -down
	body.position.y = -down
	if sunk >= 1.0 and not is_gone:
		is_gone = true
		slab.visible = false
		body.collision_layer = 0
		for c in body.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
		set_process(false)
		gone.emit(self)


## The seal's sound (audio.json stone_seal): a heavy slab dragging down in
## its groove for `seconds`, a low rumble with a slow judder and grit
## breaking off the edges, rising as it gets going and easing as it slows,
## then the dull thud of it seating below the floor. Cached by length.
static func grind_stream(seconds: float) -> AudioStreamWAV:
	var key := snappedf(seconds, 0.01)
	if _grind.has(key):
		return _grind[key]
	var rate := SoundSynth.RATE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["stone_seal", key])
	var tail := 0.9
	var s := PackedFloat32Array()
	s.resize(int((seconds + tail) * rate))
	var lp := 0.0
	var lp2 := 0.0
	var ph := 0.0
	for i in s.size():
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(seconds - 0.5, seconds, t))
		if env > 0.0:
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.05)
			lp2 = lerpf(lp2, lp, 0.18)
			var judder := 0.6 + 0.4 * absf(sin(t * TAU * 5.3) * sin(t * TAU * 1.7 + 0.6))
			ph += TAU * (42.0 + 6.0 * sin(t * 3.1)) / rate
			var grit := rng.randf_range(-1.0, 1.0) * 0.6 if rng.randf() < 0.004 * judder else 0.0
			s[i] = (lp2 * 3.4 * judder + sin(ph) * 0.35 + grit) * env
		var td := t - seconds
		if td >= 0.0:
			# The thud: a low knock and a puff of grit as it seats.
			s[i] += sin(TAU * 48.0 * td) * exp(-td * 7.0) * 1.1 + rng.randf_range(-1.0, 1.0) * exp(-td * 35.0) * 0.4
	var wav := SoundSynth._to_wav(s)
	_grind[key] = wav
	return wav

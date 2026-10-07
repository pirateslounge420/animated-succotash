class_name Airways
extends Node3D
## The builders' airways (design 6 Oct §ET.6, §ET.7, amended by §EZ.5;
## crawler.json airways, torch.json snuff.draft): dark slots in the walls
## through which the rock breathes. They move the torch's flame and never
## put it out (§EZ.5: only deep water does). TorchSnuff asks draft_at()
## each frame:
##
##   ordinary  a slot high in a corridor wall, a faint stone wind in it:
##             within reach_m the flame leans toward it (the air going out
##             to the open, a way to find your way out) at up to lean_mps,
##             and its light flickers a little harder (flicker; §EV.3).
##   strong    a marked mouth low in a room's wall (a carved surround, two
##             notches cut in its lintel): every every_s it blows for
##             gust_s. warn_s before, it is heard (the moan rising) and
##             seen (dust streaming out of the mouth). When it blows, a
##             torch flame in its line (line_m out from the mouth,
##             line_half_m either side, about the mouth's height) and not
##             behind cover (stone between it and the mouth) is whipped
##             hard away from the mouth (its smoke streams flat, its light
##             flickers hard), and it holds.

static var A: Dictionary = Tuning.table("crawler").get("airways", {})
static var SN: Dictionary = (Tuning.table("torch").get("snuff", {}) as Dictionary).get("draft", {})

## [{"strong", "pos", "normal", "t" (s to the next gust), "phase" ("idle",
## "warn", "gust"), "dust", "voice"}]
var mouths: Array = []
## What never counts as cover (the player's own body).
var exclude: Array[RID] = []
var _rng := RandomNumberGenerator.new()
static var _void_mat: StandardMaterial3D


func build(lay: Dictionary) -> void:
	_rng.seed = hash([int(lay.seed), "airways"])
	for a in lay.airways:
		var m := {"strong": bool(a.strong), "pos": a.pos, "normal": a.normal, "phase": "idle"}
		m["t"] = _next_gap() * _rng.randf_range(0.4, 1.0)
		_slot(m)
		mouths.append(m)


func _next_gap() -> float:
	var e: Array = A.get("every_s", [14.0, 22.0])
	return _rng.randf_range(float(e[0]), float(e[1]))


## The slot's dark, the stone wind in it, and a strong mouth's dust.
func _slot(m: Dictionary) -> void:
	var nrm: Vector3 = m.normal
	var right := Vector3.UP.cross(nrm).normalized()
	var root := Node3D.new()
	root.name = "Airway"
	add_child(root)
	root.global_transform = Transform3D(Basis(right, Vector3.UP, nrm), (m.pos as Vector3) + nrm * 0.03)
	if _void_mat == null:
		_void_mat = StandardMaterial3D.new()
		_void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_void_mat.albedo_color = Color(0.01, 0.012, 0.03)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.6) if bool(m.strong) else Vector2(0.5, 0.25)
	q.mesh = qm
	q.material_override = _void_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	var v := Audio3D.make("fire", root, "Wind")
	v.stream = SoundSynth.stream("stone_wind_loop", posmod(hash(m.pos), SoundSynth.VARIANTS))
	v.volume_db = -26.0 if not bool(m.strong) else -22.0
	v.max_distance = 18.0
	m["voice"] = v
	if bool(m.strong):
		var dust := CPUParticles3D.new()
		dust.name = "Dust"
		dust.emitting = false
		dust.amount = 40
		dust.lifetime = 1.3
		dust.direction = Vector3(0, 0, 1)
		dust.spread = 14.0
		dust.gravity = Vector3(0, -0.6, 0)
		dust.initial_velocity_min = 3.5
		dust.initial_velocity_max = 6.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(0.35, 0.2, 0.05)
		dust.scale_amount_min = 0.02
		dust.scale_amount_max = 0.05
		var dq := QuadMesh.new()
		dq.size = Vector2.ONE
		var dm := StandardMaterial3D.new()
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		dm.albedo_color = Color(0.58, 0.6, 0.66)
		dq.material = dm
		dust.mesh = dq
		root.add_child(dust)
		m["dust"] = dust


func _process(delta: float) -> void:
	var warn := float(SN.get("warn_s", 1.5))
	var gust := float(A.get("gust_s", 2.2))
	for m in mouths:
		if not bool(m.strong):
			continue
		m.t = float(m.t) - delta
		var phase := "idle"
		if float(m.t) <= 0.0:
			phase = "gust"
			if float(m.t) <= -gust:
				m.t = _next_gap()
				phase = "idle"
		elif float(m.t) <= warn:
			phase = "warn"
		m.phase = phase
		# The moan rises through the warning and roars in the gust.
		var v: AudioStreamPlayer3D = m.voice
		var want_db := -22.0
		if phase == "warn":
			want_db = lerpf(-14.0, -2.0, 1.0 - float(m.t) / maxf(warn, 0.01))
		elif phase == "gust":
			want_db = 0.0
		v.volume_db = lerpf(v.volume_db, want_db, minf(delta * 6.0, 1.0))
		v.pitch_scale = 1.0 + (0.25 if phase != "idle" else 0.0)
		(m.dust as CPUParticles3D).emitting = phase != "idle"
	for m in mouths:
		var v2: AudioStreamPlayer3D = m.voice
		if not v2.playing and v2.is_inside_tree():
			v2.play()


## What the airways do to a flame at `pos` (scene): {"lean" (m/s, the
## push on it), "flicker" (0-1, how much harder its light flickers),
## "gust" (a strong gust has it: whipped hard, never out, §EZ.5)}.
func draft_at(pos: Vector3) -> Dictionary:
	var lean := Vector3.ZERO
	var flicker := 0.0
	var gust := false
	var reach := float(A.get("reach_m", 5.0))
	var most := float(A.get("flicker", 0.25))
	for m in mouths:
		var mp: Vector3 = m.pos
		var nrm: Vector3 = m.normal
		var rel := pos - mp
		var ahead := rel.dot(nrm)
		if not bool(m.strong):
			var d := rel.length()
			if d < reach and ahead > -0.2:
				var k := 1.0 - d / reach
				# Toward the slot: the air going out to the open (§ET.6).
				lean += -rel.normalized() * float(A.get("lean_mps", 1.4)) * k
				flicker = maxf(flicker, most * k)
			continue
		if str(m.phase) == "idle":
			continue
		var line_m := float(A.get("line_m", 7.0))
		var side := (rel - nrm * ahead)
		var in_line := ahead > 0.0 and ahead < line_m and Vector2(side.x, side.z).length() < float(A.get("line_half_m", 0.9)) and absf(rel.y) < 1.6
		if not in_line or _covered(mp + nrm * 0.35, pos):
			continue
		var k2 := 1.0 - ahead / line_m * 0.5
		if str(m.phase) == "warn":
			# The air starts to move with the moan and the dust.
			lean += nrm * 1.5 * k2
		else:
			# The gust whips it hard away from the mouth; it holds.
			lean += nrm * 6.0 * k2
			flicker = most
			gust = true
	return {"lean": lean, "flicker": flicker, "gust": gust}


## Is there stone between the mouth and the flame (cover, §ET.7 shelter)?
func _covered(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = PropCollision.WORLD_LAYER
	q.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and (hit.position as Vector3).distance_to(to) > 0.15

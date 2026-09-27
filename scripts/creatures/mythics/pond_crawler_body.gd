class_name PondCrawlerBody
## The Pond Crawler's body (PondCrawler): a rounded, hooded lump with two
## long arms ending in splayed four-fingered hands, and one large slit eye
## that glows (#2A6AFF, the species' `accent`) with a real point light.
## The eye is drawn by the body's shader (shaders/pond_crawler.gdshader)
## across the face under the hood's brim; its light is make_light().
##
## Sculpted like SculptedBodies' creatures (signed-distance shapes blended
## smooth, surface nets, baked creases, skinned to bones), in two passes
## so the thin fingers get a finer grid than the lump: the body and arms
## at BODY_CELL, the hands at HAND_CELL (the hand mesh's wrist cuff hides
## the join). A coarser pair past FAR_M, its arms and fingers a little
## thicker so the coarse grid doesn't break them apart. Built once on a
## worker thread (start()/wait()) and shared by every crawler.
##
## Colors are tints, so the data's `color` drives them without a rebuild:
## almost every vertex carries the body color's weight (with its shade:
## darker hood and face, paler belly, knuckles and fingertips, occlusion
## baked in) in UV2.x; the claws and the eye socket carry fixed colors in
## COLOR. CUSTOM0/CUSTOM1 hold each vertex's rest position and normal, so
## shaders/pond_crawler.gdshader's crunchy texture (and the eye) ride on
## the skin instead of swimming as the arms bend.
##
## Space: meters at REF_HEIGHT tall (the crawl stance), facing -Z, +Y up,
## origin at the body's center (the Root bone), the floor at y = FLOOR_Y
## under the planted hands. Bones: Root; per side (left, right) Shoulder,
## Elbow, Wrist and four finger bones (thumb, index, middle, ring).

const REF_HEIGHT := 1.4
const FLOOR_Y := -0.45
const BODY_CELL := 0.078
const HAND_CELL := 0.034
const FAR_SCALE := 2.0
## Far LOD: arms and fingers this much thicker.
const FAR_THICK := 1.45
const FAR_M := 45.0

## Rest joints of the left arm (x mirrored for the right).
const SHOULDER := Vector3(-0.46, 0.2, -0.26)
const ELBOW := Vector3(-0.98, 0.9, -0.62)
const WRIST := Vector3(-0.86, -0.36, -1.26)
## Palm center (on the floor, flat) and the fingers' mean direction.
const PALM := Vector3(-0.89, -0.41, -1.38)
const HAND_FWD := Vector3(-0.35, 0.0, -1.0)
## Fingers: [outward angle from HAND_FWD (radians; the thumb inward),
## length].
const FINGERS := [[-0.95, 0.2], [-0.3, 0.33], [0.1, 0.36], [0.5, 0.3]]
## The eye: slit center and half-size wide open (x wide, y tall), on the
## recessed face just under the hood's brim (high in the opening, so it
## reads as an eye, not a mouth); its light just outside the hood.
const EYE := Vector3(0.0, 0.35, -0.48)
const EYE_SIZE := Vector2(0.18, 0.055)
const EYE_LIGHT := Vector3(0.0, 0.35, -1.0)

static var _data := {} # built: {"near", "far", "bones", "tris", "far_tris", "ms"}
static var _task := -1
static var _mutex := Mutex.new()
static var _meshes: Array = [] # [ArrayMesh near, ArrayMesh far, Skin]
static var _materials := {} # body color + pale color -> ShaderMaterial


## Start building the meshes on a worker thread (once).
static func start() -> void:
	_mutex.lock()
	if _task < 0 and _data.is_empty():
		_task = WorkerThreadPool.add_task(func() -> void:
			var d := compute()
			_mutex.lock()
			_data = d
			_mutex.unlock())
	_mutex.unlock()


## Wait for the build (starting it if need be).
static func wait() -> void:
	start()
	_mutex.lock()
	var id := _task
	_task = -2
	_mutex.unlock()
	if id >= 0:
		WorkerThreadPool.wait_for_task_completion(id)


static func stats() -> Dictionary:
	wait()
	return {"tris": _data.tris, "far_tris": _data.far_tris, "ms": _data.ms, "bones": _data.bones.size()}


## A body for species `sp`: {"root" (scaled to sp.size_m), "skeleton",
## "bones" (name -> index), "attach" (bone name -> BoneAttachment3D, for
## hitboxes and arrows), "meshes" (near and far: set_eye() on them),
## "scale" (size_m / REF_HEIGHT)}. The eye's light is left to the caller
## (it must not be scaled): make_light().
static func build(sp: CreatureSpecies) -> Dictionary:
	wait()
	if _meshes.is_empty():
		_make_meshes()
	var k := sp.size_m / REF_HEIGHT
	var root := Node3D.new()
	root.name = "Body"
	root.scale = Vector3.ONE * k
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	var index := {}
	var bones: Array = _data.bones
	for i in bones.size():
		var bone: Dictionary = bones[i]
		skel.add_bone(bone.name)
		if bone.parent >= 0:
			skel.set_bone_parent(i, bone.parent)
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, bone.local))
		skel.reset_bone_pose(i)
		index[bone.name] = i
	var mat := material(sp)
	var meshes: Array[MeshInstance3D] = []
	for f in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Near" if f == 0 else "Far"
		mi.mesh = _meshes[f]
		mi.skin = _meshes[2]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if f == 0:
			mi.visibility_range_end = FAR_M
		else:
			mi.visibility_range_begin = FAR_M
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		meshes.append(mi)
	var attach := {}
	for bname in ["ShoulderL", "ElbowL", "WristL", "ShoulderR", "ElbowR", "WristR"]:
		var ba := BoneAttachment3D.new()
		ba.name = bname + "Attach"
		skel.add_child(ba)
		ba.bone_name = bname
		attach[bname] = ba
	for mi in meshes:
		set_eye(mi, 0.5, 1.0)
	return {"root": root, "skeleton": skel, "bones": index, "attach": attach, "meshes": meshes, "scale": k}


## Open the eye `open` (0 shut .. 1 wide) and light it `glow` (0-1).
static func set_eye(mi: MeshInstance3D, open: float, glow: float) -> void:
	mi.set_instance_shader_parameter("eye_open", open)
	mi.set_instance_shader_parameter("eye_glow", glow)


## The eye's light: a small blue point light (the species' `accent`),
## unscaled; the caller places it at EYE_LIGHT * scale, just outside the
## hood.
static func make_light(sp: CreatureSpecies, range_m: float, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "EyeLight"
	light.light_color = sp.accent
	light.light_energy = energy
	light.omni_range = range_m
	# Falls off quickly: a pool on the water and its hands, not a lamp
	# washing its own body.
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	light.light_specular = 0.0
	return light


## The body material for this species' colors: `color` is the body,
## a paler blend of it toward `accent` the bony parts.
static func material(sp: CreatureSpecies) -> ShaderMaterial:
	var body := sp.color
	var key := body.to_html(false) + sp.accent.to_html(false)
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/pond_crawler.gdshader")
		Look.register(m)
		var bl := body.srgb_to_linear()
		var pale := body.lerp(sp.accent, 0.18).lightened(0.12).srgb_to_linear()
		m.set_shader_parameter("body_color", Vector3(bl.r, bl.g, bl.b))
		m.set_shader_parameter("pale_color", Vector3(pale.r, pale.g, pale.b))
		m.set_shader_parameter("eye_color", sp.accent)
		m.set_shader_parameter("eye_center", EYE)
		m.set_shader_parameter("eye_size", EYE_SIZE)
		_materials[key] = m
	return _materials[key]


## Rest joint positions for side `sd` (-1 left, +1 right).
static func mirror(v: Vector3, sd: float) -> Vector3:
	return Vector3(v.x * -sd, v.y, v.z)


static func side_name(sd: float) -> String:
	return "L" if sd < 0.0 else "R"


## The fingers' mean direction for side `sd` (unit, flat).
static func hand_fwd(sd: float) -> Vector3:
	return mirror(HAND_FWD, sd).normalized()


## Direction of finger `j` on side `sd` (flat, unit).
static func finger_dir(sd: float, j: int) -> Vector3:
	var f: Array = FINGERS[j]
	# Outward is +angle about Y for the left hand (toward -X), - for the
	# right.
	return hand_fwd(sd).rotated(Vector3.UP, -sd * float(f[0]))


static func knuckle(sd: float, j: int) -> Vector3:
	return mirror(PALM, sd) + finger_dir(sd, j) * 0.1 + Vector3(0, 0.012, 0)


# --- Building (thread-safe: no scene or resource objects) -------------------------

static func compute() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var body := _spec(false, 1.0)
	var hands := _spec(true, 1.0)
	var near := _merge([SculptedBodies._mesh_arrays(body, BODY_CELL), SculptedBodies._mesh_arrays(hands, HAND_CELL)])
	var far := _merge([SculptedBodies._mesh_arrays(_spec(false, FAR_THICK), BODY_CELL * FAR_SCALE),
		SculptedBodies._mesh_arrays(_spec(true, FAR_THICK), HAND_CELL * FAR_SCALE)])
	var bones: Array = []
	for i in body.bones.size():
		var bn: Array = body.bones[i]
		var parent: int = bn[1]
		var world: Vector3 = bn[2]
		var local := world - (body.bones[parent][2] as Vector3 if parent >= 0 else Vector3.ZERO)
		bones.append({"name": bn[0], "parent": parent, "world": world, "local": local})
	return {"near": near.arrays, "far": far.arrays, "bones": bones, "tris": near.tris, "far_tris": far.tris,
		"ms": Time.get_ticks_msec() - t0}


## One of the two shape sets: the body and arms, or (`hands`) the hands,
## limbs `thick` times as thick. Both declare the same bones in the same
## order.
static func _spec(hands: bool, thick: float) -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	var W := Color.WHITE
	# Claws: pale moonlit bone-blue.
	var claw := Color(0.5, 0.56, 0.78)
	var root := s.bone("Root", -1, Vector3.ZERO)
	var arm_bones := {}
	for sd: float in [-1.0, 1.0]:
		var n := side_name(sd)
		var sh := s.bone("Shoulder" + n, root, mirror(SHOULDER, sd))
		var el := s.bone("Elbow" + n, sh, mirror(ELBOW, sd))
		var wr := s.bone("Wrist" + n, el, mirror(WRIST, sd))
		var fingers: Array[int] = []
		for j in FINGERS.size():
			fingers.append(s.bone("Finger%s%d" % [n, j], wr, knuckle(sd, j)))
		arm_bones[sd] = [sh, el, wr, fingers]
	if not hands:
		# The lump: a low, wide sack sitting in the water, a mantle rising
		# behind, and the hood: a heavy dome over the front with a brim
		# that overhangs the face and cowl flaps down either side. The face
		# sits well back inside them, dark (its shade, and the occlusion
		# the recess bakes), with the eye across it.
		s.skin(s.ell(Vector3(0, -0.02, 0.1), Vector3(0.56, 0.44, 0.62), root, W, 0.12, Basis.IDENTITY, 0), 1.0)
		s.skin(s.ell(Vector3(0, -0.2, 0.0), Vector3(0.5, 0.24, 0.5), root, W, 0.1, Basis.IDENTITY, 0), 1.08)
		s.skin(s.ell(Vector3(0, 0.26, 0.28), Vector3(0.44, 0.34, 0.44), root, W, 0.12, Basis.IDENTITY, 0), 0.92)
		s.skin(s.ell(Vector3(0, 0.5, -0.06), Vector3(0.46, 0.4, 0.48), root, W, 0.12, Basis.IDENTITY, 1), 0.84)
		s.skin(s.ell(Vector3(0, 0.56, -0.5), Vector3(0.4, 0.11, 0.24), root, W, 0.06, Basis(Vector3.RIGHT, -0.35), 1), 0.8)
		s.skin(s.cap(Vector3(0, 0.62, 0.05), Vector3(0, 0.36, 0.52), 0.24, 0.16, root, W, 0.1, 1), 0.86)
		s.skin(s.ell(Vector3(0, 0.27, -0.28), Vector3(0.26, 0.2, 0.22), root, W, 0.05, Basis.IDENTITY, 0), 0.55)
		for sd: float in [-1.0, 1.0]:
			s.skin(s.ell(Vector3(0.34 * sd, 0.28, -0.46), Vector3(0.12, 0.3, 0.22), root, W, 0.05, Basis(Vector3.BACK, 0.2 * sd), 1), 0.8)
		# Shoulders, then the long arms: upper arm up and out to a high
		# elbow, the forearm long and thin down to the wrist.
		for sd: float in [-1.0, 1.0]:
			var ab: Array = arm_bones[sd]
			var s0 := mirror(SHOULDER, sd)
			var e0 := mirror(ELBOW, sd)
			var w0 := mirror(WRIST, sd)
			s.skin(s.ell(Vector3(0.44 * sd, 0.2, -0.24), Vector3(0.18, 0.2, 0.18), ab[0], W, 0.12, Basis.IDENTITY, 0), 0.95)
			s.skin(s.cap(s0, e0, 0.1 * thick, 0.074 * thick, ab[0], W, 0.05, 0), 1.0)
			s.skin(s.ell(s0.lerp(e0, 0.4), Vector3.ONE * 0.1 * thick, ab[0], W, 0.05, Basis.IDENTITY, 0), 0.98)
			s.skin(s.ell(e0, Vector3.ONE * 0.082 * thick, ab[1], W, 0.03, Basis.IDENTITY, 0), 1.12)
			s.skin(s.cap(e0, w0, 0.074 * thick, 0.05 * thick, ab[1], W, 0.04, 0), 1.05)
			s.skin(s.ell(e0.lerp(w0, 0.22), Vector3.ONE * 0.082 * thick, ab[1], W, 0.06, Basis.IDENTITY, 0), 1.02)
		# Paler underside.
		s.skin(s.paint(Vector3(0, -0.36, 0.0), Vector3(0.5, 0.2, 0.55), W, 0.08), 1.22)
	else:
		for sd: float in [-1.0, 1.0]:
			var ab: Array = arm_bones[sd]
			var e0 := mirror(ELBOW, sd)
			var w0 := mirror(WRIST, sd)
			var up := Vector3.UP
			var fwd := hand_fwd(sd)
			var palm_b := Basis(up.cross(-fwd).normalized(), up, -fwd)
			# A cuff over the forearm's end (hides the join), the wrist,
			# the palm lying flat.
			s.skin(s.cap(e0.lerp(w0, 0.88), w0, 0.054 * thick, 0.056 * thick, ab[1], W, 0.03, 0), 1.06)
			s.skin(s.ell(w0, Vector3.ONE * 0.066 * thick, ab[2], W, 0.03, Basis.IDENTITY, 0), 1.14)
			s.skin(s.cap(w0, mirror(PALM, sd) - fwd * 0.04, 0.058 * thick, 0.05 * thick, ab[2], W, 0.04, 0), 1.12)
			s.skin(s.ell(mirror(PALM, sd), Vector3(0.11, 0.036 * thick, 0.12), ab[2], W, 0.04, palm_b, 0), 1.18)
			# Four long splayed fingers, arched at the middle joint, their
			# tips on the floor, and a pale claw on each.
			var fingers: Array = ab[3]
			for j in FINGERS.size():
				var f: Array = FINGERS[j]
				var length: float = f[1]
				var dir := finger_dir(sd, j)
				var kn := knuckle(sd, j)
				var mid := kn + dir * length * 0.5 + up * 0.03
				var tip := kn + dir * length + Vector3(0, FLOOR_Y + 0.02 - kn.y, 0)
				var r0 := (0.033 if j > 0 else 0.036) * thick
				s.skin(s.ell(kn, Vector3.ONE * r0 * 1.12, fingers[j], W, 0.02, Basis.IDENTITY, 0), 1.25)
				s.skin(s.cap(kn, mid, r0, r0 * 0.86, fingers[j], W, 0.02, 0), 1.2)
				s.skin(s.cap(mid, tip, r0 * 0.86, r0 * 0.6, fingers[j], W, 0.015, 0), 1.3)
				s.cap(tip, tip + dir * 0.05 + Vector3(0, -0.012, 0), r0 * 0.55, 0.006, fingers[j], claw, 0.01, 2)
	# Fixed colors are authored in sRGB (the shader takes them linear).
	for pr in s.prims + s.paints:
		if pr.channel == 0:
			pr.color = pr.color.srgb_to_linear()
	return s


## Two meshed parts as one surface's arrays, plus each vertex's rest
## position and normal (CUSTOM0, CUSTOM1).
static func _merge(parts: Array) -> Dictionary:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	var tris := 0
	for part: Dictionary in parts:
		var a: Array = part.arrays
		var base := verts.size()
		verts.append_array(a[Mesh.ARRAY_VERTEX])
		normals.append_array(a[Mesh.ARRAY_NORMAL])
		colors.append_array(a[Mesh.ARRAY_COLOR])
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		uv2s.append_array(a[Mesh.ARRAY_TEX_UV2])
		bones.append_array(a[Mesh.ARRAY_BONES])
		weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i in pi:
			idx.append(i + base)
		tris += part.tris
	var rest := PackedFloat32Array()
	var rest_n := PackedFloat32Array()
	rest.resize(verts.size() * 4)
	rest_n.resize(verts.size() * 4)
	for i in verts.size():
		var v := verts[i]
		var n := normals[i]
		rest[i * 4] = v.x
		rest[i * 4 + 1] = v.y
		rest[i * 4 + 2] = v.z
		rest[i * 4 + 3] = 0.0
		rest_n[i * 4] = n.x
		rest_n[i * 4 + 1] = n.y
		rest_n[i * 4 + 2] = n.z
		rest_n[i * 4 + 3] = 0.0
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_TEX_UV2] = uv2s
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_CUSTOM0] = rest
	out[Mesh.ARRAY_CUSTOM1] = rest_n
	out[Mesh.ARRAY_INDEX] = idx
	return {"arrays": out, "tris": tris}


static func _make_meshes() -> void:
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for which in ["near", "far"]:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _data[which], [], {}, flags)
		_meshes.append(mesh)
	var skin := Skin.new()
	var bones: Array = _data.bones
	for i in bones.size():
		skin.add_bind(i, Transform3D(Basis.IDENTITY, bones[i].world).affine_inverse())
	_meshes.append(skin)

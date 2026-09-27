class_name GibbonBody
## The gibbon's body (spec Phase 1 (iii)): one smooth skinned mesh from
## SculptedBodies' signed-distance pipeline (its Spec shapes and its
## surface-nets mesher), in meters, facing -Z, the center of mass at the
## origin. A small torso, very long arms (1.57 m fingertip to fingertip
## against 0.78 m crown to heel), short legs with long grasping feet, no
## tail, a round head with a pale ring round a dark face, pale hands and
## feet. Hand and finger bones let the hooked fingers close round wood.
##
## Built in the rest pose it hangs from: arms raised in a Y, 40 degrees
## out from straight up, so the shoulders deform least in the poses it
## spends its life in (one arm overhead, the other reaching or trailing).
##
## Differences from SculptedBodies' animals:
##   - The coat and the pale parts are tint channels (the weight of each
##     at every vertex, occlusion included, in UV2) with the colors in the
##     material, so dark and buff coats share one mesh.
##   - The face (the pale ring round the bare dark face) is drawn by the
##     shader per pixel in rest-pose space, so the mesh can stay coarse.
##   - Every vertex also carries its rest position and normal (CUSTOM0,
##     CUSTOM1): the shader textures the fur in rest-pose space, so the
##     fur doesn't slide over the arms as the skeleton swings them.
##   - The Gibbon rig poses the bones directly (IK), no pivot nodes.
## Meshes are built once on a worker thread (prewarm()) and shared.

## Mesher cell sizes (m) for the near and far meshes. The face ring is
## drawn by the shader in rest-pose space, so it stays crisp at this
## resolution.
const CELL_NEAR := 0.02
const CELL_FAR := 0.032
## Past this the coarse mesh is drawn (m).
const FAR_M := 28.0

## Bones: [name, parent].
const BONES := [
	["Root", -1], ["Chest", 0], ["Head", 1],
	["UpperArmL", 1], ["ForearmL", 3], ["HandL", 4], ["FingersL", 5],
	["UpperArmR", 1], ["ForearmR", 7], ["HandR", 8], ["FingersR", 9],
	["ThighL", 0], ["ShinL", 11], ["FootL", 12],
	["ThighR", 0], ["ShinR", 14], ["FootR", 15],
]
const ROOT := 0
const CHEST := 1
const HEAD := 2
## Per side (0 left, 1 right): upper arm, forearm, hand, fingers, thigh,
## shin, foot.
const UPPER := [3, 7]
const FORE := [4, 8]
const HAND := [5, 9]
const FINGERS := [6, 10]
const THIGH := [11, 14]
const SHIN := [12, 15]
const FOOT := [13, 16]

## Arm segments (m) and the rest direction of the right arm (raised 40
## degrees out from straight up; the left mirrors it).
const UPPER_M := 0.25
const FORE_M := 0.27
const PALM_M := 0.085
const FINGER_M := 0.07
## Where the wood sits in the hooked hand: this far from the wrist along
## the hand (m).
const GRIP_M := 0.1
const ARM_DIR_R := Vector3(0.6428, 0.766, 0.0)
const SHOULDER_R := Vector3(0.11, 0.155, 0.005)
const HIP_R := Vector3(0.052, -0.14, 0.012)
const KNEE_R := Vector3(0.058, -0.275, -0.004)
const ANKLE_R := Vector3(0.06, -0.395, 0.006)
const CHEST_AT := Vector3(0.0, 0.07, 0.0)
const HEAD_AT := Vector3(0.0, 0.215, -0.005)
## The palm faces forward in the rest pose.
const PALM_N := Vector3(0.0, 0.0, -1.0)

## Default colors (sRGB): a brown lar gibbon (the species runs from
## black through brown to buff; a warm mid brown shows the fur's grain
## and keeps R1a's "nothing black"), with the white face ring, hands and
## feet; the bare face (dark, lighter than the eyes so they read) and
## the eyes.
const COAT := Color("#7d5534")
const PALE := Color("#eee3cc")
const FACE := Color("#62504a")
const EYE := Color("#26170f")

static var _data := {}
static var _task := -1
static var _mutex := Mutex.new()
static var _meshes: Array = [] # [near ArrayMesh, far ArrayMesh, Skin]
static var _materials := {} # coat + pale html -> ShaderMaterial


## A joint's rest position; `side` 0 left, 1 right (mirrored in x).
static func mirror(v: Vector3, side: int) -> Vector3:
	return Vector3(v.x if side == 1 else -v.x, v.y, v.z)


static func arm_dir(side: int) -> Vector3:
	return mirror(ARM_DIR_R, side)


static func shoulder(side: int) -> Vector3:
	return mirror(SHOULDER_R, side)


static func elbow(side: int) -> Vector3:
	return shoulder(side) + arm_dir(side) * UPPER_M


static func wrist(side: int) -> Vector3:
	return elbow(side) + arm_dir(side) * FORE_M


static func knuckle(side: int) -> Vector3:
	return wrist(side) + arm_dir(side) * PALM_M


static func hip(side: int) -> Vector3:
	return mirror(HIP_R, side)


static func knee(side: int) -> Vector3:
	return mirror(KNEE_R, side)


static func ankle(side: int) -> Vector3:
	return mirror(ANKLE_R, side)


## Rest position of every bone's joint, in BONES order.
static func joints() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(BONES.size())
	out[ROOT] = Vector3.ZERO
	out[CHEST] = CHEST_AT
	out[HEAD] = HEAD_AT
	for s in 2:
		out[UPPER[s]] = shoulder(s)
		out[FORE[s]] = elbow(s)
		out[HAND[s]] = wrist(s)
		out[FINGERS[s]] = knuckle(s)
		out[THIGH[s]] = hip(s)
		out[SHIN[s]] = knee(s)
		out[FOOT[s]] = ankle(s)
	return out


## The shapes. Coat is tint channel 1, the pale parts channel 2.
static func spec() -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = CELL_NEAR
	var W := Color.WHITE
	var j := joints()
	for b in BONES.size():
		s.bone(BONES[b][0], BONES[b][1], j[b], "")
	# Torso: a narrow pelvis and waist under a deep chest and a shoulder
	# yoke (small torso, big shoulders for the arms).
	s.skin(s.ell(Vector3(0, -0.13, 0.012), Vector3(0.066, 0.062, 0.056), ROOT, W, 0.04))
	s.skin(s.cap(Vector3(0, -0.1, 0.008), Vector3(0, 0.05, 0.0), 0.064, 0.074, ROOT, W, 0.05))
	s.skin(s.ell(Vector3(0, 0.1, 0.0), Vector3(0.088, 0.094, 0.068), CHEST, W, 0.05))
	s.skin(s.ell(Vector3(0, 0.162, 0.01), Vector3(0.122, 0.042, 0.054), CHEST, W, 0.04))
	# Neck and a round head: skull, a short muzzle, a brow, cheek fur.
	# The pale ring and the bare face are drawn by the shader.
	s.skin(s.cap(Vector3(0, 0.18, 0.006), Vector3(0, 0.238, -0.006), 0.038, 0.034, HEAD, W, 0.03))
	s.skin(s.ell(Vector3(0, 0.29, -0.004), Vector3(0.062, 0.064, 0.061), HEAD, W, 0.03))
	s.skin(s.ell(Vector3(0, 0.266, -0.05), Vector3(0.034, 0.029, 0.028), HEAD, W, 0.026))
	s.skin(s.ell(Vector3(0, 0.302, -0.05), Vector3(0.046, 0.016, 0.018), HEAD, W, 0.02))
	for sd: float in [-1.0, 1.0]:
		s.skin(s.ell(Vector3(0.044 * sd, 0.27, -0.03), Vector3(0.026, 0.03, 0.024), HEAD, W, 0.022))
	# Arms: shoulder cap, upper arm, elbow, a long slim forearm, a long
	# narrow palm and the fingers as one hook (the hand bones curl it).
	for side in 2:
		var a := arm_dir(side)
		var sh := shoulder(side)
		var el := elbow(side)
		var wr := wrist(side)
		var kn := knuckle(side)
		var tip := kn + a * FINGER_M
		var width := Vector3(a.y, -a.x, 0.0) if side == 1 else Vector3(a.y, -a.x, 0.0) * -1.0
		s.skin(s.cap(sh - a * 0.012, sh + a * 0.07, 0.048, 0.037, UPPER[side], W, 0.035))
		s.skin(s.cap(sh, el, 0.037, 0.028, UPPER[side], W, 0.02))
		s.skin(s.ell(el, Vector3.ONE * 0.028, FORE[side], W, 0.012))
		s.skin(s.cap(el + a * 0.01, el + a * 0.1, 0.029, 0.026, FORE[side], W, 0.015))
		s.skin(s.cap(el + a * 0.05, wr, 0.026, 0.022, FORE[side], W, 0.014))
		var palm_b := Basis(width.normalized(), a, Vector3(0, 0, 1))
		s.hide(s.ell(wr + a * 0.045, Vector3(0.028, 0.052, 0.02), HAND[side], W, 0.014, palm_b))
		s.hide(s.cap(kn - a * 0.012, tip, 0.021, 0.018, FINGERS[side], W, 0.01))
		# Pale hands (with a little of the wrist).
		s.hide(s.paint(wr + a * 0.075, Vector3.ONE * 0.09, W, 0.02))
	# Legs: short thighs and shins, long grasping feet (pale).
	for side in 2:
		var sx := 1.0 if side == 1 else -1.0
		var hp := hip(side)
		var kn := knee(side)
		var an := ankle(side)
		s.skin(s.cap(hp, kn, 0.043, 0.031, THIGH[side], W, 0.03))
		s.skin(s.ell(kn, Vector3.ONE * 0.028, SHIN[side], W, 0.012))
		s.skin(s.cap(kn, an, 0.029, 0.023, SHIN[side], W, 0.015))
		var foot_c := an + Vector3(0.002 * sx, -0.02, -0.036)
		s.hide(s.ell(foot_c, Vector3(0.027, 0.02, 0.06), FOOT[side], W, 0.015))
		s.hide(s.cap(an + Vector3(-0.012 * sx, -0.018, -0.03), an + Vector3(-0.032 * sx, -0.022, -0.068), 0.016, 0.014, FOOT[side], W, 0.008))
		s.hide(s.paint(foot_c + Vector3(0, 0.01, 0), Vector3(0.06, 0.05, 0.085), W, 0.015))
	# A darker crown.
	s.skin(s.paint(Vector3(0, 0.34, 0.01), Vector3(0.06, 0.035, 0.06), W, 0.03), 0.8)
	for pr in s.prims + s.paints:
		if pr.channel == 0:
			pr.color = pr.color.srgb_to_linear()
	return s


## Build the mesh data (thread-safe: no scene or resource objects):
## {"near", "far" (mesh arrays), "near_tris", "far_tris", "ms"}.
static func compute() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var s := spec()
	var near: Dictionary = SculptedBodies._mesh_arrays(s, CELL_NEAR)
	var far: Dictionary = SculptedBodies._mesh_arrays(s, CELL_FAR)
	_add_rest(near.arrays)
	_add_rest(far.arrays)
	return {"near": near.arrays, "far": far.arrays, "near_tris": near.tris, "far_tris": far.tris,
		"ms": Time.get_ticks_msec() - t0}


## Rest position and normal of every vertex, for the shader's texture
## space (CUSTOM0, CUSTOM1; skinning moves VERTEX and NORMAL, not these).
static func _add_rest(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rp := PackedFloat32Array()
	var rn := PackedFloat32Array()
	rp.resize(verts.size() * 3)
	rn.resize(verts.size() * 3)
	for i in verts.size():
		rp[i * 3] = verts[i].x
		rp[i * 3 + 1] = verts[i].y
		rp[i * 3 + 2] = verts[i].z
		rn[i * 3] = normals[i].x
		rn[i * 3 + 1] = normals[i].y
		rn[i * 3 + 2] = normals[i].z
	arrays[Mesh.ARRAY_CUSTOM0] = rp
	arrays[Mesh.ARRAY_CUSTOM1] = rn


## Start building in the background (once).
static func prewarm() -> void:
	_mutex.lock()
	if _task < 0 and _data.is_empty():
		_task = WorkerThreadPool.add_task(func() -> void:
			var d := compute()
			_mutex.lock()
			_data = d
			_mutex.unlock())
	_mutex.unlock()


## Is the mesh built (starting the build if it isn't)?
static func ready() -> bool:
	prewarm()
	_mutex.lock()
	var ok := not _data.is_empty()
	_mutex.unlock()
	if ok and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2
	return ok


## Wait for the mesh (building it now if need be).
static func wait_ready() -> void:
	prewarm()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -2


## Triangle counts [near, far] (0 until built).
static func triangles() -> Vector2i:
	if _data.is_empty():
		return Vector2i.ZERO
	return Vector2i(_data.near_tris, _data.far_tris)


static func _make_meshes() -> void:
	var flags := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	_meshes = []
	for which in ["near", "far"]:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _data[which], [], {}, flags)
		_meshes.append(mesh)
	var skin := Skin.new()
	var j := joints()
	for b in BONES.size():
		skin.add_bind(b, Transform3D(Basis.IDENTITY, j[b]).affine_inverse())
	_meshes.append(skin)


## A body for the Gibbon rig, or {} if the mesh isn't built yet:
## {"root" (Node3D), "skeleton" (Skeleton3D), "near", "far"
## (MeshInstance3D), "material"}. Bones rest unrotated at joints(); the
## rig sets their rotations.
static func build(coat := COAT, pale := PALE) -> Dictionary:
	if not ready():
		return {}
	if _meshes.is_empty():
		_make_meshes()
	var root := Node3D.new()
	root.name = "Body"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	var j := joints()
	for b in BONES.size():
		skel.add_bone(BONES[b][0])
		var parent: int = BONES[b][1]
		if parent >= 0:
			skel.set_bone_parent(b, parent)
		skel.set_bone_rest(b, Transform3D(Basis.IDENTITY, j[b] - (j[parent] if parent >= 0 else Vector3.ZERO)))
		skel.reset_bone_pose(b)
	var mat := material(coat, pale)
	var out := {"root": root, "skeleton": skel, "material": mat}
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
		out["near" if f == 0 else "far"] = mi
	# Eyes: dark brown beads under the brow, riding the head bone. Not a
	# glow: they're lit like the rest of the body.
	var head := BoneAttachment3D.new()
	head.name = "HeadAttach"
	head.bone_name = "Head"
	skel.add_child(head)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.0105
	eye_mesh.height = 0.021
	eye_mesh.radial_segments = 10
	eye_mesh.rings = 5
	var eye_mat := eye_material()
	for sd: float in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.name = "Eye"
		e.mesh = eye_mesh
		e.material_override = eye_mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Half out of the face (whose surface is at z -0.0725 here).
		e.position = Vector3(0.019 * sd, 0.287, -0.069) - HEAD_AT
		e.visibility_range_end = FAR_M
		head.add_child(e)
	return out


## The body material for a coat and pale color (sRGB), shared by every
## gibbon of those colors.
static func material(coat: Color, pale: Color) -> ShaderMaterial:
	var key := coat.to_html(false) + pale.to_html(false)
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/gibbon.gdshader")
		Look.register(m)
		m.set_shader_parameter("look_tex_fur", Look.texture("fur"))
		var cl := coat.srgb_to_linear()
		var pl := pale.srgb_to_linear()
		var fl := FACE.srgb_to_linear()
		m.set_shader_parameter("coat_color", Vector3(cl.r, cl.g, cl.b))
		m.set_shader_parameter("pale_color", Vector3(pl.r, pl.g, pl.b))
		m.set_shader_parameter("face_color", Vector3(fl.r, fl.g, fl.b))
		_materials[key] = m
	return _materials[key]


static func eye_material() -> ShaderMaterial:
	if not _materials.has("eye"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/gibbon.gdshader")
		Look.register(m)
		m.set_shader_parameter("look_tex_fur", Look.texture("fur"))
		var el := EYE.srgb_to_linear()
		m.set_shader_parameter("rigid", true)
		m.set_shader_parameter("flat_color", Vector3(el.r, el.g, el.b))
		_materials["eye"] = m
	return _materials["eye"]

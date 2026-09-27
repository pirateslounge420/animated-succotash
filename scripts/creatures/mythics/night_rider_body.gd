class_name NightRiderBody
## The Night Rider's body (data/creatures/creatures.json "Night rider"): a
## heavy dark horse and its hooded, cloaked rider as ONE smooth skinned
## mesh, built with SculptedBodies' pieces (signed-distance shapes blended
## with a smooth minimum, surface nets, normals from the field, baked
## crease shading, per-vertex skinning) but with its own shapes, cache and
## rig, so the shared sculpt code needs no changes.
##
## The horse: a deep chest and barrel, a thick arched neck with a long
## mane falling to one side, a heavy head carried steep, a full tail, and
## thick legs whose hair flares over broad hooves. The rider sits at the
## withers: a deep hood with a pointed peak and a dark void for a face,
## broad cloaked shoulders, sleeved arms to gloved hands at the reins, the
## cloak draped over the horse's back and down its flanks, the hem torn
## into points. Colors are the species' "palette" (deep ultramarine and
## indigo): each at or above the R1a night sky's darkest, #0A14A0 (R1a:
## nothing pure black), and the shader keeps creases and dark strokes
## from going below it either. At night they're "lit only by blue sheen"
## (the species' "look": the world's light reaches them only
## `night_shade` as much, and a streaky cold blue sheen carries their
## shapes; shaders/night_rider.gdshader). Eyes are separate glowing points
## (shaders/eye_glow.gdshader, the species' `accent`, #FF2A2A): the only
## light on them.
##
## Authored in meters for a REF_HEIGHT-tall figure (feet at y 0, facing
## -Z) and stored in units of that height, like the other mythical bodies
## (so the sculpt pipeline's blend and skinning widths fit); the creature
## scales the root by its size_m. Bones form a real hierarchy: each leg is
## two bones (upper: shoulder or hip to knee or hock; lower: to the hoof),
## the head hangs off the neck, the rider's head and arms off the rider,
## and build() mirrors it with nested pivot nodes, so a pivot's rotation is
## its bone's local pose (SculptRig copies them on) and hitboxes riding
## the pivots follow the mesh exactly. NightRider bends the legs with
## two-bone IK (leg_chain()).
##
## Each vertex also carries its rest position and normal (CUSTOM0,
## CUSTOM1), so the shader's texture is bound to the rest pose and rides
## on the skin instead of sliding over the legs as they walk.
##
## Meshes build once on a worker thread (prewarm(), ready()) and are shared.

const REF_HEIGHT := 2.7
## Surface-net cell (m) for the near mesh; the far mesh's is FAR_FACTOR
## times that.
const CELL_M := 0.056
const FAR_FACTOR := 2.0
## Near mesh to this distance (m), then the coarse one.
const FAR_M := 55.0
## Eye glow points: [pivot bone, position (m), radius (m)].
const EYES := [["Head", Vector3(0.12, 1.93, -1.14), 0.022], ["Head", Vector3(-0.12, 1.93, -1.14), 0.022],
	["RiderHead", Vector3(0.048, 2.38, -0.29), 0.017], ["RiderHead", Vector3(-0.048, 2.38, -0.29), 0.017]]
## The legs, in footfall order of the four-beat walk (left hind, left
## fore, right hind, right fore): [upper bone, lower bone].
const LEGS := [["HindL", "HindLLow"], ["ForeL", "ForeLLow"], ["HindR", "HindRLow"], ["ForeR", "ForeRLow"]]
## Hoof contact points (m, the bottom of each hoof), in LEGS order.
const HOOVES := [Vector3(-0.19, 0.0, 0.635), Vector3(-0.19, 0.0, -0.55), Vector3(0.19, 0.0, 0.635), Vector3(0.19, 0.0, -0.55)]

const DEFAULT_PALETTE := {"coat": "#1a2cc4", "mane": "#2634cc", "hoof": "#141ca8", "cloak": "#1c18b0", "hood": "#0c16a6", "glove": "#1618ac"}
## The night look (the species' "look" entry overrides these).
const DEFAULT_LOOK := {"night_shade": 0.25, "sheen": "#2e66ff", "sheen_amount": 1.2}
## Surface kinds (UV.x; shaders/night_rider.gdshader): 0 leather and
## gloves, 1 hair, 2 hoof, 3 cloth, and VOID: the rider's face and the
## horse's eye sockets and nostrils, dark and untextured, catching no sheen.
const VOID := 4
## The mesh formats of CUSTOM0 and CUSTOM1 (rest position and normal).
const REST_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
	| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static var _cache := {} # palette key -> {"arrays", "far_arrays", "bones", "tris", "far_tris", "ms"}
static var _pending := {} # key -> worker task id
static var _meshes := {} # key -> [ArrayMesh near, ArrayMesh far, Skin]
static var _mutex := Mutex.new()
static var _material: ShaderMaterial
static var _eye_mats := {}
static var _eye_quad: QuadMesh


static func palette_of(sp: CreatureSpecies) -> Dictionary:
	var pal := DEFAULT_PALETTE.duplicate()
	pal.merge(sp.data.get("palette", {}), true)
	return pal


static func _key(pal: Dictionary) -> String:
	var keys := pal.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s=%s" % [k, pal[k]])
	return ",".join(parts)


## Start building this species' mesh in the background (no-op if built or
## building).
static func prewarm(sp: CreatureSpecies) -> void:
	var pal := palette_of(sp)
	var key := _key(pal)
	_mutex.lock()
	if not _cache.has(key) and not _pending.has(key):
		_pending[key] = WorkerThreadPool.add_task(func() -> void:
			var data := compute(pal)
			_mutex.lock()
			_cache[key] = data
			_mutex.unlock())
	_mutex.unlock()


## Is the mesh built (starting the build if it isn't)?
static func ready(sp: CreatureSpecies) -> bool:
	var key := _key(palette_of(sp))
	_mutex.lock()
	var ok := _cache.has(key)
	var id: int = _pending.get(key, -1)
	_mutex.unlock()
	if ok:
		if id >= 0 and WorkerThreadPool.is_task_completed(id):
			_mutex.lock()
			_pending.erase(key)
			_mutex.unlock()
			WorkerThreadPool.wait_for_task_completion(id)
		return true
	if id < 0:
		prewarm(sp)
	return false


## Wait for the mesh (building it now if need be).
static func wait_ready(sp: CreatureSpecies) -> void:
	if ready(sp):
		return
	var key := _key(palette_of(sp))
	_mutex.lock()
	var id: int = _pending.get(key, -1)
	_pending.erase(key)
	_mutex.unlock()
	if id >= 0:
		WorkerThreadPool.wait_for_task_completion(id)


## Wait for any build still running (at shutdown).
static func finish() -> void:
	_mutex.lock()
	var ids: Array = _pending.values()
	_pending.clear()
	_mutex.unlock()
	for id in ids:
		WorkerThreadPool.wait_for_task_completion(id)


## Triangles in the near and far meshes (0 until built).
static func triangles(sp: CreatureSpecies) -> Vector2i:
	var key := _key(palette_of(sp))
	_mutex.lock()
	var data: Dictionary = _cache.get(key, {})
	_mutex.unlock()
	return Vector2i(int(data.get("tris", 0)), int(data.get("far_tris", 0)))


## The body, or {} while the mesh isn't built. Returns {"root": Node3D
## (unscaled; scale it by size_m), "skeleton", "rig": SculptRig, "pivots":
## {bone name: Node3D}, "bones": {bone name: {"world", "parent"}} (units),
## "eyes": [MeshInstance3D]}.
static func build(sp: CreatureSpecies) -> Dictionary:
	if not ready(sp):
		return {}
	var key := _key(palette_of(sp))
	_mutex.lock()
	var data: Dictionary = _cache[key]
	_mutex.unlock()
	if not _meshes.has(key):
		var out: Array = []
		for which in ["arrays", "far_arrays"]:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data[which], [], {}, REST_FORMAT)
			out.append(mesh)
		var skin := Skin.new()
		var bl: Array = data.bones
		for i in bl.size():
			skin.add_bind(i, Transform3D(Basis.IDENTITY, bl[i].world).affine_inverse())
		out.append(skin)
		_meshes[key] = out
	var res: Array = _meshes[key]
	var root := Node3D.new()
	root.name = "NightRiderBody"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	var bones: Array = data.bones
	for i in bones.size():
		var bone: Dictionary = bones[i]
		skel.add_bone(bone.name)
		if bone.parent >= 0:
			skel.set_bone_parent(i, bone.parent)
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, bone.local))
		skel.reset_bone_pose(i)
	for f in 2:
		var mi := MeshInstance3D.new()
		mi.name = "Near" if f == 0 else "Far"
		mi.mesh = res[f]
		mi.skin = res[2]
		mi.material_override = material(sp)
		if f == 0:
			mi.visibility_range_end = FAR_M
		else:
			mi.visibility_range_begin = FAR_M
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
	# Pivots at the joints, nested like the bones: a pivot's rotation is
	# its bone's local pose. The rig copies them on after the creature has
	# posed them (a high process priority: after the creature's tick).
	var rig := SculptRig.new()
	rig.name = "Rig"
	rig.skeleton = skel
	rig.process_priority = 100
	root.add_child(rig)
	var pivots := {}
	var info := {}
	for i in bones.size():
		var bone: Dictionary = bones[i]
		var pivot := Node3D.new()
		pivot.name = bone.name
		var parent_node: Node3D = root if bone.parent < 0 else pivots[bones[bone.parent].name]
		pivot.position = bone.world if bone.parent < 0 else bone.local
		parent_node.add_child(pivot)
		pivots[bone.name] = pivot
		info[bone.name] = {"world": bone.world, "parent": bones[bone.parent].name if bone.parent >= 0 else ""}
		rig.pivots.append(pivot)
		rig.bones.append(i)
	var eyes: Array = []
	for e in EYES:
		var pv: Node3D = pivots[e[0]]
		var at: Vector3 = (e[1] as Vector3) / REF_HEIGHT - (info[e[0]].world as Vector3)
		eyes.append(eye(pv, at, e[2], sp.accent, sp.size_m))
	return {"root": root, "skeleton": skel, "rig": rig, "pivots": pivots, "bones": info, "eyes": eyes}


## The rider's material (shaders/night_rider.gdshader): the world's fur
## strokes and grain, coarse enough to read as texture at walking
## distance, vertex-lit like everything else, its colors never darker than
## the R1a night sky's darkest (SkySystem.NIGHT_ZENITH, #0A14A0); at night
## shaded and sheened as `sp`'s "look" says (one species wears it).
static func material(sp: CreatureSpecies = null) -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/night_rider.gdshader")
		Look.register(_material)
		_material.set_shader_parameter("look_tex_fur", Look.texture("fur"))
		_material.set_shader_parameter("floor_color", SkySystem.NIGHT_ZENITH)
	if sp:
		var look := DEFAULT_LOOK.duplicate()
		look.merge(sp.data.get("look", {}), true)
		_material.set_shader_parameter("night_shade", clampf(float(look.night_shade), 0.0, 1.0))
		_material.set_shader_parameter("sheen_color", Color.from_string(str(look.sheen), Color("#2e66ff")))
		_material.set_shader_parameter("sheen_amount", maxf(float(look.sheen_amount), 0.0))
	return _material


## A glowing eye point (shaders/eye_glow.gdshader) at `pos` (units) under
## `parent`: `radius_m` across, never less than a couple of pixels, in
## `color`. `full_scale` is the body's scale when fully there (the glow
## fades with the body).
static func eye(parent: Node3D, pos: Vector3, radius_m: float, color: Color, full_scale: float) -> MeshInstance3D:
	if _eye_quad == null:
		_eye_quad = QuadMesh.new()
		_eye_quad.size = Vector2(2.0, 2.0)
	var key := "%s_%.3f_%.2f" % [color.to_html(false), radius_m, full_scale]
	if not _eye_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/eye_glow.gdshader")
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("radius_m", radius_m)
		m.set_shader_parameter("full_scale", full_scale)
		_eye_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.name = "Eye"
	mi.mesh = _eye_quad
	mi.material_override = _eye_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader sizes the quad itself (it never shrinks below a few
	# pixels), so its box must allow for that.
	mi.custom_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	mi.visibility_range_end = 400.0
	mi.position = pos
	parent.add_child(mi)
	return mi


## A leg's rest geometry for IK, in body units: {"hip", "joint", "foot"}
## (the upper bone's pivot, the lower bone's pivot, the hoof's contact
## point), from build()'s "bones".
static func leg_chain(bones: Dictionary, leg: int) -> Dictionary:
	var names: Array = LEGS[leg]
	return {"hip": bones[names[0]].world, "joint": bones[names[1]].world, "foot": (HOOVES[leg] as Vector3) / REF_HEIGHT}


# --- Shapes (meters; stored in units of REF_HEIGHT) -----------------------------

## Build the mesh data (thread-safe: no scene or resource objects). The
## far mesh's shapes are thickened where they're thinner than its cells
## can hold, so the legs don't break up in the distance.
static func compute(pal: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var s := _spec(pal)
	var near := SculptedBodies._mesh_arrays(s, s.cell)
	var far_cell := s.cell * FAR_FACTOR
	var far := SculptedBodies._mesh_arrays(_spec(pal, 0.62 * far_cell * H), far_cell)
	_add_rest(near.arrays)
	_add_rest(far.arrays)
	var bones: Array = []
	for i in s.bones.size():
		var bn: Array = s.bones[i]
		var parent: int = bn[1]
		var world: Vector3 = bn[2]
		var local := world - (s.bones[parent][2] as Vector3 if parent >= 0 else Vector3.ZERO)
		bones.append({"name": bn[0], "parent": parent, "world": world, "local": local, "role": bn[3]})
	return {"arrays": near.arrays, "far_arrays": far.arrays, "bones": bones,
		"tris": near.tris, "far_tris": far.tris, "ms": Time.get_ticks_msec() - t0}


## Each vertex's rest position and normal as CUSTOM0 and CUSTOM1 (RGBA
## floats, REST_FORMAT): the skinned VERTEX and NORMAL move with the pose,
## these don't, so texture looked up by them stays put on the skin.
static func _add_rest(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
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
		rest_n[i * 4] = n.x
		rest_n[i * 4 + 1] = n.y
		rest_n[i * 4 + 2] = n.z
	arrays[Mesh.ARRAY_CUSTOM0] = rest
	arrays[Mesh.ARRAY_CUSTOM1] = rest_n


const H := REF_HEIGHT


static func _bone(s: SculptedBodies.Spec, bname: String, parent: int, at: Vector3) -> int:
	return s.bone(bname, parent, at / H, bname)


static func _cap(s: SculptedBodies.Spec, a: Vector3, b: Vector3, ra: float, rb: float, bone: int, col: Color, k := 0.06, mat := 1) -> SculptedBodies.Prim:
	var mr: float = s.get_meta("min_r", 0.0)
	return s.cap(a / H, b / H, maxf(ra, mr) / H, maxf(rb, mr) / H, bone, col, k / H, mat)


static func _ell(s: SculptedBodies.Spec, c: Vector3, r: Vector3, bone: int, col: Color, k := 0.06, basis := Basis.IDENTITY, mat := 1) -> SculptedBodies.Prim:
	var mr: float = s.get_meta("min_r", 0.0)
	return s.ell(c / H, r.max(Vector3.ONE * mr) / H, bone, col, k / H, basis, mat)


static func _paint(s: SculptedBodies.Spec, c: Vector3, r: Vector3, col: Color, soft := 0.03, basis := Basis.IDENTITY, mat := -1) -> SculptedBodies.Prim:
	return s.paint(c / H, r / H, col, soft / H, basis, mat)


## The shapes, in meters. `min_r` (m) thickens anything thinner (the far
## mesh).
static func _spec(pal: Dictionary, min_r := 0.0) -> SculptedBodies.Spec:
	var s := SculptedBodies.Spec.new()
	s.cell = CELL_M / H
	s.set_meta("min_r", min_r)
	var coat := Color.from_string(str(pal.coat), Color(0.1, 0.13, 0.38))
	var mane := Color.from_string(str(pal.mane), coat.lightened(0.1))
	var hoof := Color.from_string(str(pal.hoof), coat)
	var cloak := Color.from_string(str(pal.cloak), coat)
	var hood := Color.from_string(str(pal.hood), cloak.darkened(0.6))
	var glove := Color.from_string(str(pal.glove), cloak)
	# The belly shades toward the hood's color, never below it.
	var belly := coat.lerp(hood, 0.45)

	# --- The horse -------------------------------------------------------------
	var root := _bone(s, "Root", -1, Vector3(0, 1.22, 0))
	_ell(s, Vector3(0, 1.2, 0.0), Vector3(0.34, 0.4, 0.8), root, coat, 0.14) # barrel
	_ell(s, Vector3(0, 1.2, -0.58), Vector3(0.32, 0.4, 0.33), root, coat, 0.12) # chest
	_ell(s, Vector3(0, 1.47, -0.4), Vector3(0.2, 0.15, 0.3), root, coat, 0.12) # withers
	_ell(s, Vector3(0, 1.3, 0.58), Vector3(0.33, 0.34, 0.35), root, coat, 0.12) # croup
	_ell(s, Vector3(0, 1.48, 0.48), Vector3(0.26, 0.13, 0.3), root, coat, 0.1) # top of the croup
	_ell(s, Vector3(0, 1.0, 0.0), Vector3(0.3, 0.22, 0.5), root, coat, 0.12) # belly
	_paint(s, Vector3(0, 0.84, 0.0), Vector3(0.26, 0.14, 0.62), belly, 0.08)

	# Neck and head: a thick arched neck, a heavy head carried steep, the
	# mane falling to the right.
	var neck := _bone(s, "Neck", root, Vector3(0, 1.45, -0.62))
	_cap(s, Vector3(0, 1.33, -0.64), Vector3(0, 1.9, -0.98), 0.28, 0.16, neck, coat, 0.12)
	_cap(s, Vector3(0, 1.6, -0.58), Vector3(0, 2.03, -0.92), 0.15, 0.11, neck, coat, 0.1) # crest
	var head := _bone(s, "Head", neck, Vector3(0, 1.98, -1.0))
	_ell(s, Vector3(0, 1.93, -1.08), Vector3(0.13, 0.15, 0.16), head, coat, 0.06) # skull
	_ell(s, Vector3(0, 1.8, -1.05), Vector3(0.12, 0.12, 0.13), head, coat, 0.06) # jowl
	_cap(s, Vector3(0, 1.9, -1.14), Vector3(0, 1.6, -1.34), 0.115, 0.095, head, coat, 0.06) # face
	_ell(s, Vector3(0, 1.55, -1.36), Vector3(0.1, 0.095, 0.105), head, coat, 0.04) # muzzle
	for sd: float in [-1.0, 1.0]:
		_cap(s, Vector3(0.065 * sd, 2.06, -1.0), Vector3(0.085 * sd, 2.2, -0.97), 0.04, 0.01, head, coat, 0.02) # ear
		_paint(s, Vector3(0.045 * sd, 1.52, -1.45), Vector3(0.025, 0.025, 0.02), hood, 0.012, Basis.IDENTITY, VOID) # nostril
		_paint(s, Vector3(0.12 * sd, 1.93, -1.14), Vector3(0.035, 0.03, 0.035), hood, 0.014, Basis.IDENTITY, VOID) # eye socket
	for k in 6:
		var t := k / 5.0
		var crest := Vector3(0, 2.05, -0.95).lerp(Vector3(0, 1.64, -0.5), t)
		var lock := Basis(Vector3.BACK, 0.3) * Basis(Vector3.RIGHT, 0.5)
		_ell(s, crest + Vector3(0.08, -0.1 - 0.02 * t, 0.0), Vector3(0.05, 0.18 - 0.03 * t, 0.09), neck, mane, 0.05, lock)
	_cap(s, Vector3(0, 2.08, -0.95), Vector3(0, 1.68, -0.5), 0.065, 0.055, neck, mane, 0.04) # mane along the crest
	_ell(s, Vector3(0, 2.02, -1.1), Vector3(0.06, 0.09, 0.04), head, mane, 0.03) # forelock

	# Tail: a heavy fall of hair.
	var tail := _bone(s, "Tail", root, Vector3(0, 1.48, 0.9))
	_cap(s, Vector3(0, 1.5, 0.88), Vector3(0, 1.33, 1.02), 0.075, 0.085, tail, mane, 0.06)
	_cap(s, Vector3(0, 1.33, 1.02), Vector3(0, 0.78, 1.1), 0.1, 0.14, tail, mane, 0.06)
	_ell(s, Vector3(0, 0.7, 1.1), Vector3(0.13, 0.12, 0.1), tail, mane, 0.05)

	# Legs, in LEGS order: thick, the hair flaring over broad hooves. Fore:
	# shoulder to knee, knee to hoof. Hind: hip to hock (haunch and
	# gaskin), hock to hoof.
	for leg in LEGS.size():
		var names: Array = LEGS[leg]
		var fore: bool = (names[0] as String).begins_with("Fore")
		var x := 0.19 * (-1.0 if (names[0] as String).ends_with("L") else 1.0)
		var foot: Vector3 = HOOVES[leg]
		if fore:
			var up := _bone(s, names[0], root, Vector3(x, 1.3, -0.52))
			_ell(s, Vector3(x * 0.9, 1.22, -0.55), Vector3(0.15, 0.31, 0.21), up, coat, 0.08) # shoulder
			_cap(s, Vector3(x, 1.1, -0.52), Vector3(x, 0.56, -0.545), 0.125, 0.08, up, coat, 0.06) # forearm
			var low := _bone(s, names[1], up, Vector3(x, 0.52, -0.55))
			_ell(s, Vector3(x, 0.52, -0.55), Vector3(0.082, 0.09, 0.085), low, coat, 0.02) # knee
			_cap(s, Vector3(x, 0.5, -0.55), Vector3(x, 0.28, -0.54), 0.07, 0.064, low, coat, 0.02) # cannon
			_cap(s, Vector3(x, 0.3, -0.54), Vector3(x, 0.1, foot.z + 0.02), 0.066, 0.098, low, mane, 0.03) # feathering
			_ell(s, Vector3(x, 0.062, foot.z), Vector3(0.085, 0.062, 0.095), low, hoof, 0.02, Basis.IDENTITY, 2) # hoof
		else:
			var up := _bone(s, names[0], root, Vector3(x, 1.3, 0.55))
			_ell(s, Vector3(x * 0.95, 1.2, 0.6), Vector3(0.17, 0.31, 0.31), up, coat, 0.08) # haunch
			_cap(s, Vector3(x, 1.02, 0.62), Vector3(x, 0.58, 0.73), 0.14, 0.085, up, coat, 0.06) # gaskin
			var low := _bone(s, names[1], up, Vector3(x, 0.55, 0.72))
			_ell(s, Vector3(x, 0.55, 0.735), Vector3(0.082, 0.1, 0.095), low, coat, 0.02) # hock
			_cap(s, Vector3(x, 0.52, 0.72), Vector3(x, 0.28, 0.68), 0.07, 0.064, low, coat, 0.02) # cannon
			_cap(s, Vector3(x, 0.3, 0.68), Vector3(x, 0.1, foot.z + 0.01), 0.066, 0.098, low, mane, 0.03) # feathering
			_ell(s, Vector3(x, 0.062, foot.z), Vector3(0.085, 0.062, 0.095), low, hoof, 0.02, Basis.IDENTITY, 2) # hoof

	# --- The rider -------------------------------------------------------------
	var rider := _bone(s, "Rider", root, Vector3(0, 1.62, -0.1))
	_ell(s, Vector3(0, 1.72, -0.1), Vector3(0.19, 0.14, 0.18), rider, cloak, 0.06, Basis.IDENTITY, 3) # seat
	for sd: float in [-1.0, 1.0]:
		_cap(s, Vector3(0.13 * sd, 1.72, -0.12), Vector3(0.32 * sd, 1.5, -0.32), 0.095, 0.08, rider, cloak, 0.04, 3) # thigh
		_cap(s, Vector3(0.32 * sd, 1.5, -0.32), Vector3(0.33 * sd, 1.2, -0.24), 0.072, 0.062, rider, glove, 0.03, 0) # shin
		_ell(s, Vector3(0.33 * sd, 1.15, -0.28), Vector3(0.062, 0.057, 0.115), rider, glove, 0.03, Basis.IDENTITY, 0) # boot
	_cap(s, Vector3(0, 1.76, -0.1), Vector3(0, 2.13, -0.14), 0.2, 0.23, rider, cloak, 0.08, 3) # torso
	_ell(s, Vector3(0, 2.14, -0.13), Vector3(0.3, 0.12, 0.17), rider, cloak, 0.08, Basis.IDENTITY, 3) # shoulders
	_ell(s, Vector3(0, 1.88, 0.08), Vector3(0.3, 0.34, 0.15), rider, cloak, 0.08, Basis.IDENTITY, 3) # cloak down the back
	_ell(s, Vector3(0, 1.63, 0.26), Vector3(0.33, 0.12, 0.36), rider, cloak, 0.06, Basis.IDENTITY, 3) # cloak over the horse's back
	for sd: float in [-1.0, 1.0]:
		# The cloak hangs down each flank, its hem torn into points.
		_ell(s, Vector3(0.33 * sd, 1.36, 0.24), Vector3(0.055, 0.26, 0.33), rider, cloak, 0.04, Basis(Vector3.BACK, 0.1 * sd), 3)
		for k in 4:
			var z := -0.02 + k * 0.16
			_cap(s, Vector3(0.35 * sd, 1.14, z), Vector3(0.37 * sd, 1.0 + 0.04 * (k % 2), z + 0.03), 0.04, 0.018, rider, cloak, 0.03, 3)
	# Arms, sleeved to the gloves at the reins.
	for sd: float in [-1.0, 1.0]:
		var arm := _bone(s, "ArmL" if sd < 0.0 else "ArmR", rider, Vector3(0.25 * sd, 2.1, -0.13))
		_cap(s, Vector3(0.25 * sd, 2.1, -0.13), Vector3(0.3 * sd, 1.88, -0.27), 0.09, 0.08, arm, cloak, 0.04, 3)
		_cap(s, Vector3(0.3 * sd, 1.88, -0.27), Vector3(0.16 * sd, 1.8, -0.45), 0.08, 0.095, arm, cloak, 0.03, 3) # sleeve
		_ell(s, Vector3(0.14 * sd, 1.785, -0.5), Vector3(0.052, 0.058, 0.068), arm, glove, 0.02, Basis.IDENTITY, 0) # glove
	# The hood: deep, a pointed peak drooping back, a dark void for a face.
	var rhead := _bone(s, "RiderHead", rider, Vector3(0, 2.2, -0.14))
	_cap(s, Vector3(0, 2.15, -0.13), Vector3(0, 2.3, -0.15), 0.095, 0.09, rhead, cloak, 0.04, 3) # neck
	_ell(s, Vector3(0, 2.21, -0.1), Vector3(0.26, 0.1, 0.21), rhead, cloak, 0.06, Basis.IDENTITY, 3) # collar
	_ell(s, Vector3(0, 2.39, -0.12), Vector3(0.17, 0.19, 0.19), rhead, cloak, 0.06, Basis.IDENTITY, 3) # hood
	_ell(s, Vector3(0, 2.49, -0.21), Vector3(0.15, 0.07, 0.1), rhead, cloak, 0.04, Basis.IDENTITY, 3) # hood brow
	_cap(s, Vector3(0, 2.5, -0.03), Vector3(0, 2.66, 0.14), 0.12, 0.015, rhead, cloak, 0.04, 3) # peak
	_paint(s, Vector3(0, 2.37, -0.32), Vector3(0.12, 0.14, 0.1), hood, 0.03, Basis.IDENTITY, VOID) # the face: a void

	# Colors are authored in sRGB (like the other sculpted bodies); the
	# shader takes them linear.
	for pr in s.prims + s.paints:
		pr.color = pr.color.srgb_to_linear()
	return s

class_name SculptedBodies
## Sculpted creature bodies: one continuous, smooth, skinned mesh per body
## instead of CreatureBodies' glued-together capsules and spheres (the
## GameCube "hero model" look: shoulders flow into limbs, the neck into
## the head, no seams).
##
## A body is described as signed-distance shapes (tapered capsules and
## ellipsoids), each tied to a bone, blended with a smooth minimum so they
## melt into each other. Surface nets turn the field into a mesh; normals
## come from the field's gradient; creases get darker (ambient occlusion
## baked into the vertex color); colors blend across the joins, with
## "paint" shapes for muzzles, bellies, socks and loincloths; each vertex
## is skinned to the bones of the shapes nearest it, so limbs bend at
## their joints. Eyes, antlers and lanterns stay separate small parts.
##
## Meshes are built once per body kind on a worker thread (prewarm(),
## from CreatureSpawner) and shared; build() returns CreatureBodies'
## dictionary shape ({"root", "legs", "wings", "tail", "light"}) with
## plain pivot nodes at the joints, and a SculptRig copies the pivots'
## rotations onto the skeleton every frame, so Creature's leg, arm and
## tail swings drive the bones unchanged. Until a kind's mesh is ready
## (or with `enabled` off) CreatureBodies builds the old body.
##
## Kinds: "wolf", "deer", "goblin", and people: "tribal" (the camps'
## hunters and archers) and "elder" (a fur mantle, grey hair, a beard).
## A near mesh and a coarser far one (past FAR_M).
##
## Camp folk come in every shade of skin (and people of hide), so their
## meshes carry those two as tint channels instead of colors (the weight
## of each at every vertex, occlusion included, in UV2): one mesh per
## kind, and each one's own colors in a material (_tinted()). Other kinds
## are built once per coat color. Colors are sRGB like CreatureBodies'.

const KINDS := ["wolf", "deer", "goblin", "tribal", "elder"]
const TINTED := ["tribal", "elder", "goblin"]
const FAR_M := 45.0

## Off: every body the old way (for comparisons).
static var enabled := true

static var _cache := {} # key (key_for()) -> {"arrays", "far_arrays", "bones", "tris", "ms"} once built
static var _meshes := {} # key -> [ArrayMesh near, ArrayMesh far, Skin]
static var _pending := {} # key -> task id
static var _mutex := Mutex.new()
static var _material: ShaderMaterial
static var _tints := {} # skin + hide colors -> ShaderMaterial


## The sculpted kind for a species, or "".
static func kind_for(sp: CreatureSpecies) -> String:
	var k := sp.shape if sp.role == "mythical" else sp.body
	if k == "tribal" and sp.shape.begins_with("elder"):
		k = "elder"
	return k if k in KINDS else ""


## Cache key: the kind and the species' coat color (just the kind for
## camp folk: their colors are tints).
static func key_for(sp: CreatureSpecies) -> String:
	var kind := kind_for(sp)
	return kind if kind in TINTED else kind + ":" + sp.color.to_html(false)


## Start building every sculpted species' body in the background.
static func prewarm(species: Array[CreatureSpecies]) -> void:
	for sp in species:
		if kind_for(sp) != "":
			_start(key_for(sp), kind_for(sp), sp.color)


## Start building the camp folk's bodies (call early: the opening camp
## needs them in its first frame).
static func prewarm_folk() -> void:
	for kind in TINTED:
		_start(kind, kind, Color.WHITE)


static func _start(key: String, kind: String, base: Color) -> void:
	_mutex.lock()
	var busy := _cache.has(key) or _pending.has(key)
	if not busy:
		_pending[key] = WorkerThreadPool.add_task(func() -> void:
			var data := compute(kind, base)
			_mutex.lock()
			_cache[key] = data
			_mutex.unlock())
	_mutex.unlock()


## Collect finished builds (a worker task must be waited on once it's
## done, or it's left dangling at exit). CreatureSpawner calls this now
## and then.
static func collect() -> void:
	_mutex.lock()
	var done: Array = []
	for key in _pending:
		if WorkerThreadPool.is_task_completed(_pending[key]):
			done.append(key)
	var ids: Array = []
	for key in done:
		ids.append(_pending[key])
		_pending.erase(key)
	_mutex.unlock()
	for id in ids:
		WorkerThreadPool.wait_for_task_completion(id)


## Wait for every build still running (at shutdown).
static func finish() -> void:
	_mutex.lock()
	var ids: Array = _pending.values()
	_pending.clear()
	_mutex.unlock()
	for id in ids:
		WorkerThreadPool.wait_for_task_completion(id)


## Is this species' mesh ready (building it if it isn't)?
static func ready(sp: CreatureSpecies) -> bool:
	collect()
	var key := key_for(sp)
	_mutex.lock()
	var ok := _cache.has(key)
	_mutex.unlock()
	if not ok:
		_start(key, kind_for(sp), sp.color)
	return ok


## Wait until this species' mesh is built (building it now if need be),
## for bodies that must look right from their first frame.
static func wait_ready(sp: CreatureSpecies) -> void:
	if not enabled or kind_for(sp) == "" or ready(sp):
		return
	var key := key_for(sp)
	_mutex.lock()
	var id: int = _pending.get(key, -1)
	_pending.erase(key)
	_mutex.unlock()
	if id >= 0:
		WorkerThreadPool.wait_for_task_completion(id)


## The body for `sp`, or {} if it has no sculpted kind or isn't ready yet.
static func build(sp: CreatureSpecies) -> Dictionary:
	if not enabled:
		return {}
	var kind := kind_for(sp)
	if kind == "" or not ready(sp):
		return {}
	var key := key_for(sp)
	if not _meshes.has(key):
		_make_meshes(key)
	var data: Dictionary = _cache[key]
	var res: Array = _meshes[key]
	var b := {"root": Node3D.new(), "legs": [], "wings": [], "tail": null, "light": null}
	var root: Node3D = b.root
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
		mi.material_override = _tinted(sp) if kind in TINTED else material()
		if f == 0:
			mi.visibility_range_end = FAR_M
		else:
			mi.visibility_range_begin = FAR_M
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
	# Pivots at the joints: Creature swings these; the rig copies them on.
	var rig := SculptRig.new()
	rig.skeleton = skel
	root.add_child(rig)
	for i in bones.size():
		var bone: Dictionary = bones[i]
		var role: String = bone.role
		if role == "":
			continue
		var pivot := Node3D.new()
		pivot.name = bone.name
		pivot.position = bone.world
		root.add_child(pivot)
		rig.pivots.append(pivot)
		rig.bones.append(i)
		match role:
			"leg":
				b.legs.append(pivot)
			"arm":
				b.wings.append(pivot)
			"tail":
				b.tail = pivot
	_attach_extras(b, kind, sp)
	return b


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/creature_sculpt.gdshader")
		Look.register(_material)
		_material.set_shader_parameter("look_tex_fur", Look.texture("fur"))
	return _material


## A camp folk's material: the shared one with their skin and hide colors
## (shared in turn by everyone within a shade of them), taken linear.
static func _tinted(sp: CreatureSpecies) -> ShaderMaterial:
	var skin := _snap(sp.color)
	var hide := _snap(sp.accent)
	var key := skin.to_html(false) + hide.to_html(false)
	if not _tints.has(key):
		var m := material().duplicate() as ShaderMaterial
		var sl := skin.srgb_to_linear()
		var hl := hide.srgb_to_linear()
		m.set_shader_parameter("skin_color", Vector3(sl.r, sl.g, sl.b))
		m.set_shader_parameter("hide_color", Vector3(hl.r, hl.g, hl.b))
		_tints[key] = m
	return _tints[key]


static func _snap(c: Color) -> Color:
	return Color(snappedf(c.r, 1.0 / 64.0), snappedf(c.g, 1.0 / 64.0), snappedf(c.b, 1.0 / 64.0))


static func _make_meshes(key: String) -> void:
	var data: Dictionary = _cache[key]
	var out: Array = []
	for which in ["arrays", "far_arrays"]:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data[which])
		out.append(mesh)
	var skin := Skin.new()
	var bones: Array = data.bones
	for i in bones.size():
		skin.add_bind(i, Transform3D(Basis.IDENTITY, bones[i].world).affine_inverse())
	out.append(skin)
	_meshes[key] = out


## Eyes, antlers, the goblin's lantern, people's gear: small separate
## parts on the head pivot (or the root).
static func _attach_extras(b: Dictionary, kind: String, sp: CreatureSpecies) -> void:
	var root: Node3D = b.root
	var head: Node3D = root.get_node_or_null("Head")
	var hp := head.position if head else Vector3.ZERO
	match kind:
		"wolf":
			CreatureBodies.eyes(head, Vector3(0, 0.705, -0.5) - hp, 0.04, 0.014, Color(0.9, 0.75, 0.3), 0.6)
			CreatureBodies.ball(head, Vector3(0.018, 0.014, 0.012), Vector3(0, 0.66, -0.595) - hp, Color(0.05, 0.05, 0.05))
		"deer":
			CreatureBodies.eyes(head, Vector3(0, 0.975, -0.47) - hp, 0.042, 0.013, Color(0.06, 0.05, 0.05))
			if sp.name == "Deer":
				var bone := Color(0.75, 0.68, 0.55)
				for s: float in [-1.0, 1.0]:
					# Beam from the brow up and out, a brow tine forward, a
					# second tine near the top.
					var beam := CreatureBodies.cone(head, 0.016, 0.007, 0.32, Vector3(0.09 * s, 1.14, -0.4) - hp, bone, 0.0, 5)
					beam.rotation = Vector3(0.25, 0.0, -0.5 * s)
					var brow := CreatureBodies.cone(head, 0.011, 0.0, 0.12, Vector3(0.06 * s, 1.06, -0.47) - hp, bone, 0.0, 5)
					brow.rotation = Vector3(-0.9, 0.0, -0.2 * s)
					var tine := CreatureBodies.cone(head, 0.01, 0.0, 0.12, Vector3(0.14 * s, 1.21, -0.43) - hp, bone, 0.0, 5)
					tine.rotation = Vector3(-0.5, 0.0, -0.1 * s)
		"goblin":
			CreatureBodies.eyes(head, Vector3(0, 0.79, -0.125) - hp, 0.05, 0.022, Color(1.0, 0.85, 0.3), 1.5)
			var arm: Node3D = b.wings[1] if b.wings.size() > 1 else root
			CreatureBodies._lantern(b, arm, Vector3(0.18, 0.24, -0.06) - arm.position, sp.accent)
		"tribal", "elder":
			CreatureBodies.eyes(head, Vector3(0, 0.903, -0.054) - hp, 0.021, 0.0085, Color(0.07, 0.05, 0.04))
			CreatureBodies.tribal_gear(b, sp)


# --- The shapes ----------------------------------------------------------------

class Prim:
	## 0 tapered capsule (a..b, radii ra..rb), 1 ellipsoid.
	var type := 0
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var ra := 0.1
	var rb := 0.1
	var center := Vector3.ZERO
	var radii := Vector3.ONE
	var inv := Basis.IDENTITY
	var k := 0.05 # blend radius into what's already there
	var bone := 0
	var color := Color.WHITE
	var mat := 1 # 0 skin, 1 fur, 2 horn/hoof
	var paint := false # color only, no geometry
	## Tint channel: 0 its own color, 1 skin, 2 hide (the person's colors
	## times `shade`).
	var channel := 0
	var shade := 1.0
	var soft := 0.02 # paint edge
	var bound_c := Vector3.ZERO
	var bound_r := 1.0
	# Tapered capsule constants.
	var ba := Vector3.ZERO
	var l2 := 1.0
	var rr := 0.0
	var a2 := 1.0
	var il2 := 1.0

	func setup() -> void:
		if type == 0:
			ba = b - a
			l2 = maxf(ba.length_squared(), 1e-8)
			rr = ra - rb
			a2 = l2 - rr * rr
			il2 = 1.0 / l2
			bound_c = (a + b) * 0.5
			bound_r = ba.length() * 0.5 + maxf(ra, rb)
		else:
			bound_c = center
			bound_r = maxf(radii.x, maxf(radii.y, radii.z))

	func dist(p: Vector3) -> float:
		if type == 1:
			var q := inv * (p - center)
			var k0 := (q / radii).length()
			var k1 := (q / (radii * radii)).length()
			return k0 * (k0 - 1.0) / maxf(k1, 1e-8)
		# Tapered capsule (round cone), Inigo Quilez's exact form.
		var pa := p - a
		var y := pa.dot(ba)
		var z := y - l2
		var xv := pa * l2 - ba * y
		var x2 := xv.length_squared()
		var y2 := y * y * l2
		var z2 := z * z * l2
		var kk := signf(rr) * rr * rr * x2
		if signf(z) * a2 * z2 > kk:
			return sqrt(x2 + z2) * il2 - rb
		if signf(y) * a2 * y2 < kk:
			return sqrt(x2 + y2) * il2 - ra
		return (sqrt(x2 * a2 * il2) + y * rr) * il2 - ra


class Spec:
	var prims: Array[Prim] = []
	var paints: Array[Prim] = []
	## [name, parent index, world joint position, role ("leg", "arm",
	## "tail", "head" or "" for the root)]
	var bones: Array = []
	var cell := 0.025

	func bone(bname: String, parent: int, at: Vector3, role := "") -> int:
		bones.append([bname, parent, at, role])
		return bones.size() - 1

	func cap(a: Vector3, b: Vector3, ra: float, rb: float, bone_i: int, col: Color, k := 0.03, mat := 1) -> Prim:
		var p := Prim.new()
		p.type = 0
		p.a = a
		p.b = b
		p.ra = ra
		p.rb = rb
		p.k = k
		p.bone = bone_i
		p.color = col
		p.mat = mat
		p.setup()
		prims.append(p)
		return p

	func ell(c: Vector3, r: Vector3, bone_i: int, col: Color, k := 0.03, basis := Basis.IDENTITY, mat := 1) -> Prim:
		var p := Prim.new()
		p.type = 1
		p.center = c
		p.radii = r
		p.inv = basis.inverse()
		p.k = k
		p.bone = bone_i
		p.color = col
		p.mat = mat
		p.setup()
		prims.append(p)
		return p

	## A color-only ellipsoid: tints what's inside it (soft edge).
	func paint(c: Vector3, r: Vector3, col: Color, soft := 0.02, basis := Basis.IDENTITY, mat := -1) -> Prim:
		var p := Prim.new()
		p.type = 1
		p.center = c
		p.radii = r
		p.inv = basis.inverse()
		p.color = col
		p.paint = true
		p.soft = soft
		p.mat = mat
		p.setup()
		paints.append(p)
		return p

	## A person's shape (or paint) in their own skin or hide color, times
	## `shade`, instead of its own.
	func skin(p: Prim, shade := 1.0) -> Prim:
		p.channel = 1
		p.shade = shade
		return p

	func hide(p: Prim, shade := 1.0) -> Prim:
		p.channel = 2
		p.shade = shade
		return p

	func mirror(v: Vector3, s: float) -> Vector3:
		return Vector3(v.x * s, v.y, v.z)


static func _spec(kind: String, base: Color) -> Spec:
	var s := Spec.new()
	match kind:
		"wolf":
			_wolf(s, base)
		"deer":
			_deer(s, base)
		"goblin":
			_goblin(s)
		"tribal":
			_person(s, false)
		"elder":
			_person(s, true)
	# Colors are authored in sRGB, like CreatureBodies' (the shader takes
	# them linear).
	for pr in s.prims + s.paints:
		if pr.channel == 0:
			pr.color = pr.color.srgb_to_linear()
	return s


## Wolf (unit = body length, feet at y 0, facing -Z): deep chest, tucked
## waist, a wedge head with a long muzzle and tall ears, a bushy tail,
## lean legs with paws. Pale belly, muzzle and socks; dark nose.
static func _wolf(s: Spec, base: Color) -> void:
	s.cell = 0.034
	var fur := base
	var pale := base.lightened(0.35)
	var root := s.bone("Root", -1, Vector3(0, 0.5, 0))
	var head := s.bone("Head", root, Vector3(0, 0.6, -0.3), "head")
	var chest := s.ell(Vector3(0, 0.5, -0.13), Vector3(0.12, 0.15, 0.19), root, fur, 0.05)
	s.cap(Vector3(0, 0.5, -0.12), Vector3(0, 0.49, 0.2), 0.12, 0.09, root, fur, 0.06)
	s.ell(Vector3(0, 0.5, 0.2), Vector3(0.1, 0.11, 0.12), root, fur, 0.05) # haunches
	s.cap(Vector3(0, 0.55, -0.24), Vector3(0, 0.65, -0.37), 0.09, 0.065, head, fur, 0.06) # neck, ruff
	s.ell(Vector3(0, 0.69, -0.42), Vector3(0.075, 0.075, 0.09), head, fur, 0.04)
	s.cap(Vector3(0, 0.68, -0.47), Vector3(0, 0.65, -0.59), 0.045, 0.025, head, fur, 0.03)
	for sd: float in [-1.0, 1.0]:
		s.cap(Vector3(0.045 * sd, 0.73, -0.4), Vector3(0.06 * sd, 0.82, -0.385), 0.028, 0.004, head, fur.darkened(0.1), 0.02)
	# Legs, in CreatureBodies' order: left front, left hind, right front,
	# right hind (the gait alternates by index).
	for sd: float in [-1.0, 1.0]:
		for front: bool in [true, false]:
			var x := 0.075 * sd
			var zj := -0.2 if front else 0.2
			var leg := s.bone(("Front" if front else "Hind") + ("L" if sd < 0.0 else "R"), root, Vector3(x, 0.5, zj), "leg")
			if front:
				s.cap(Vector3(x, 0.5, zj), Vector3(x, 0.28, zj - 0.01), 0.05, 0.034, leg, fur, 0.04)
				s.cap(Vector3(x, 0.28, zj - 0.01), Vector3(x, 0.05, zj - 0.005), 0.034, 0.028, leg, fur, 0.015)
			else:
				s.ell(Vector3(x * 0.85, 0.42, zj + 0.01), Vector3(0.055, 0.1, 0.075), leg, fur, 0.04)
				s.cap(Vector3(x, 0.42, zj + 0.02), Vector3(x, 0.2, zj + 0.07), 0.05, 0.03, leg, fur, 0.03)
				s.cap(Vector3(x, 0.2, zj + 0.07), Vector3(x, 0.05, zj + 0.04), 0.03, 0.027, leg, fur, 0.015)
			s.ell(Vector3(x, 0.028, zj - 0.025), Vector3(0.036, 0.026, 0.048), leg, fur, 0.02)
			s.paint(Vector3(x, 0.05, zj - 0.01), Vector3(0.06, 0.1, 0.07), pale, 0.03) # socks
	var tail := s.bone("Tail", root, Vector3(0, 0.53, 0.3), "tail")
	s.cap(Vector3(0, 0.53, 0.29), Vector3(0, 0.4, 0.52), 0.045, 0.035, tail, fur, 0.04)
	s.paint(Vector3(0, 0.38, 0.54), Vector3(0.05, 0.06, 0.06), pale, 0.02) # tail tip
	s.paint(Vector3(0, 0.39, -0.05), Vector3(0.11, 0.08, 0.26), pale, 0.05) # belly
	s.paint(Vector3(0, 0.63, -0.55), Vector3(0.05, 0.035, 0.08), pale, 0.02) # muzzle underside
	s.paint(Vector3(0, 0.55, -0.3), Vector3(0.07, 0.06, 0.07), pale, 0.03) # throat
	s.paint(Vector3(0, 0.66, -0.6), Vector3(0.022, 0.018, 0.015), Color(0.08, 0.07, 0.07), 0.006, Basis.IDENTITY, 2) # nose
	s.paint(Vector3(0, 0.75, -0.36), Vector3(0.1, 0.07, 0.12), fur.darkened(0.25), 0.05) # darker crown and ear backs
	s.paint(Vector3(0, 0.62, 0.05), Vector3(0.09, 0.05, 0.3), fur.darkened(0.2), 0.05) # saddle


## Deer (unit = body length): a barrel body on long slim legs with
## hooves, a raised neck, a fine head with big ears. Warm brown, white
## belly, rump and tail underside, dark muzzle and hooves.
static func _deer(s: Spec, base: Color) -> void:
	s.cell = 0.03
	var coat := base
	var white := Color(0.92, 0.88, 0.8)
	var dark := Color(0.14, 0.11, 0.09)
	var root := s.bone("Root", -1, Vector3(0, 0.72, 0))
	var head := s.bone("Head", root, Vector3(0, 0.82, -0.3), "head")
	s.ell(Vector3(0, 0.72, -0.1), Vector3(0.12, 0.14, 0.2), root, coat, 0.05)
	s.cap(Vector3(0, 0.72, -0.08), Vector3(0, 0.73, 0.22), 0.12, 0.11, root, coat, 0.06)
	s.ell(Vector3(0, 0.74, 0.24), Vector3(0.1, 0.12, 0.11), root, coat, 0.05)
	s.cap(Vector3(0, 0.78, -0.24), Vector3(0, 0.95, -0.38), 0.07, 0.05, head, coat, 0.05)
	s.ell(Vector3(0, 0.98, -0.43), Vector3(0.055, 0.06, 0.075), head, coat, 0.04)
	s.cap(Vector3(0, 0.97, -0.46), Vector3(0, 0.935, -0.56), 0.04, 0.022, head, coat, 0.025)
	for sd: float in [-1.0, 1.0]:
		var ear_b := Basis(Vector3.BACK, -0.9 * sd) * Basis(Vector3.RIGHT, -0.3)
		s.ell(Vector3(0.075 * sd, 1.03, -0.4), Vector3(0.022, 0.055, 0.012), head, coat, 0.012, ear_b)
	for sd: float in [-1.0, 1.0]:
		for front: bool in [true, false]:
			var x := 0.07 * sd
			var zj := -0.19 if front else 0.21
			var leg := s.bone(("Front" if front else "Hind") + ("L" if sd < 0.0 else "R"), root, Vector3(x, 0.7, zj), "leg")
			if front:
				s.cap(Vector3(x, 0.7, zj), Vector3(x, 0.4, zj - 0.01), 0.05, 0.03, leg, coat, 0.04)
				s.cap(Vector3(x, 0.4, zj - 0.01), Vector3(x, 0.05, zj), 0.032, 0.026, leg, coat, 0.012)
			else:
				s.ell(Vector3(x * 0.8, 0.63, zj + 0.02), Vector3(0.055, 0.13, 0.08), leg, coat, 0.04)
				s.cap(Vector3(x, 0.6, zj + 0.03), Vector3(x, 0.33, zj + 0.09), 0.048, 0.026, leg, coat, 0.03)
				s.cap(Vector3(x, 0.33, zj + 0.09), Vector3(x, 0.05, zj + 0.05), 0.03, 0.026, leg, coat, 0.012)
			s.cap(Vector3(x, 0.05, zj - 0.005), Vector3(x, 0.014, zj - 0.02), 0.028, 0.024, leg, dark, 0.008, 2) # hoof
			s.paint(Vector3(x, 0.03, zj - 0.01), Vector3(0.04, 0.035, 0.045), dark, 0.01, Basis.IDENTITY, 2)
	var tail := s.bone("Tail", root, Vector3(0, 0.8, 0.33), "tail")
	s.cap(Vector3(0, 0.8, 0.32), Vector3(0, 0.72, 0.39), 0.035, 0.022, tail, coat, 0.03)
	s.paint(Vector3(0, 0.74, 0.38), Vector3(0.05, 0.06, 0.05), white, 0.015) # tail underside
	s.paint(Vector3(0, 0.72, 0.33), Vector3(0.08, 0.09, 0.05), white, 0.03) # rump patch
	s.paint(Vector3(0, 0.6, 0.0), Vector3(0.1, 0.06, 0.26), white, 0.05) # belly
	s.paint(Vector3(0, 0.84, -0.3), Vector3(0.05, 0.06, 0.05), white, 0.03) # throat patch
	s.paint(Vector3(0, 0.935, -0.565), Vector3(0.028, 0.022, 0.02), dark, 0.008, Basis.IDENTITY, 2) # nose
	s.paint(Vector3(0, 0.955, -0.52), Vector3(0.045, 0.03, 0.03), white.darkened(0.1), 0.012) # muzzle band


## Goblin (unit = height ~1, standing): a pot belly on skinny legs with
## big feet, long arms to knobbly hands, a big head with a heavy brow,
## cheekbones, a long hooked nose and a wide jaw, huge pointed ears. The
## skin (a tint: camp goblins come in many greens), darker over the scalp
## and back; a leather loincloth and belt.
static func _goblin(s: Spec) -> void:
	s.cell = 0.019
	var W := Color.WHITE
	var leather := Color(0.36, 0.25, 0.15)
	var root := s.bone("Root", -1, Vector3(0, 0.34, 0))
	var head := s.bone("Head", root, Vector3(0, 0.62, -0.01), "head")
	s.skin(s.ell(Vector3(0, 0.34, 0.0), Vector3(0.1, 0.075, 0.08), root, W, 0.04, Basis.IDENTITY, 0)) # pelvis
	s.skin(s.ell(Vector3(0, 0.43, -0.03), Vector3(0.11, 0.1, 0.1), root, W, 0.05, Basis.IDENTITY, 0)) # belly
	s.skin(s.cap(Vector3(0, 0.42, 0.01), Vector3(0, 0.55, 0.0), 0.095, 0.11, root, W, 0.05, 0)) # chest
	s.skin(s.ell(Vector3(0, 0.54, 0.0), Vector3(0.14, 0.05, 0.07), root, W, 0.04, Basis.IDENTITY, 0)) # shoulders
	s.skin(s.cap(Vector3(0, 0.56, 0.0), Vector3(0, 0.66, -0.01), 0.045, 0.05, head, W, 0.03, 0)) # neck
	s.skin(s.ell(Vector3(0, 0.77, -0.02), Vector3(0.12, 0.115, 0.115), head, W, 0.04, Basis.IDENTITY, 0)) # skull
	s.skin(s.ell(Vector3(0, 0.8, -0.1), Vector3(0.095, 0.025, 0.035), head, W, 0.03, Basis.IDENTITY, 0)) # brow
	s.skin(s.ell(Vector3(0, 0.69, -0.06), Vector3(0.09, 0.05, 0.08), head, W, 0.035, Basis.IDENTITY, 0)) # jaw
	for sd: float in [-1.0, 1.0]:
		s.skin(s.ell(Vector3(0.06 * sd, 0.74, -0.1), Vector3(0.03, 0.025, 0.025), head, W, 0.025, Basis.IDENTITY, 0)) # cheekbone
		var ear_b := Basis(Vector3.BACK, 0.25 * sd) * Basis(Vector3.UP, -0.25 * sd)
		s.skin(s.ell(Vector3(0.18 * sd, 0.8, 0.0), Vector3(0.1, 0.04, 0.026), head, W, 0.025, ear_b, 0)) # ear
		s.paint(Vector3(0.19 * sd, 0.8, -0.02), Vector3(0.07, 0.022, 0.02), Color(0.62, 0.42, 0.3), 0.01, ear_b) # inner ear
	s.skin(s.cap(Vector3(0, 0.77, -0.12), Vector3(0, 0.71, -0.2), 0.028, 0.012, head, W, 0.02, 0)) # hooked nose
	# Legs (left, right), then arms (left, right).
	for sd: float in [-1.0, 1.0]:
		var x := 0.06 * sd
		var leg := s.bone("Leg" + ("L" if sd < 0.0 else "R"), root, Vector3(x, 0.32, 0.0), "leg")
		s.skin(s.cap(Vector3(x, 0.32, 0.0), Vector3(x * 1.15, 0.18, -0.02), 0.045, 0.032, leg, W, 0.03, 0))
		s.skin(s.ell(Vector3(x * 1.15, 0.18, -0.025), Vector3(0.034, 0.03, 0.032), leg, W, 0.015, Basis.IDENTITY, 0)) # knee
		s.skin(s.cap(Vector3(x * 1.15, 0.18, -0.02), Vector3(x * 1.2, 0.05, 0.0), 0.03, 0.024, leg, W, 0.015, 0))
		s.skin(s.ell(Vector3(x * 1.2, 0.028, -0.045), Vector3(0.042, 0.026, 0.075), leg, W, 0.02, Basis.IDENTITY, 0)) # foot
	for sd: float in [-1.0, 1.0]:
		var x := 0.13 * sd
		var arm := s.bone("Arm" + ("L" if sd < 0.0 else "R"), root, Vector3(x, 0.54, 0.0), "arm")
		s.skin(s.cap(Vector3(x, 0.54, 0.0), Vector3(x * 1.3, 0.41, -0.02), 0.04, 0.03, arm, W, 0.03, 0))
		s.skin(s.ell(Vector3(x * 1.3, 0.41, -0.02), Vector3(0.028, 0.028, 0.028), arm, W, 0.012, Basis.IDENTITY, 0)) # elbow
		s.skin(s.cap(Vector3(x * 1.3, 0.41, -0.02), Vector3(x * 1.38, 0.29, -0.04), 0.027, 0.024, arm, W, 0.012, 0))
		s.skin(s.ell(Vector3(x * 1.4, 0.255, -0.05), Vector3(0.032, 0.04, 0.026), arm, W, 0.015, Basis.IDENTITY, 0)) # hand
		for f in 3:
			s.skin(s.cap(Vector3(x * 1.4 + (f - 1) * 0.014, 0.23, -0.05), Vector3(x * 1.4 + (f - 1) * 0.018, 0.19, -0.06), 0.009, 0.006, arm, W, 0.006, 0)) # fingers
	s.paint(Vector3(0, 0.3, 0.0), Vector3(0.13, 0.07, 0.11), leather, 0.01, Basis.IDENTITY, 2) # loincloth
	s.paint(Vector3(0, 0.38, 0.0), Vector3(0.13, 0.018, 0.12), leather.darkened(0.3), 0.004, Basis.IDENTITY, 2) # belt
	s.skin(s.paint(Vector3(0, 0.83, 0.03), Vector3(0.11, 0.06, 0.1), W, 0.04), 0.8) # darker scalp
	s.skin(s.paint(Vector3(0, 0.45, 0.07), Vector3(0.1, 0.12, 0.05), W, 0.04), 0.85) # darker back


## A person (unit = height, standing, facing -Z): the camps' folk and the
## opening camp's two. Lean and long-limbed: a hide tunic to mid-thigh
## with a belt and a dark hem, bare arms with leather bracers, leggings
## and wrapped feet, dark hair tied back, a stripe of ochre under the
## eyes. An `elder` wears a fur mantle and a drape down
## the back, and has grey hair and a beard. Skin and hide are the
## person's own colors (tint channels); hair, paint and trim are fixed.
## Joints where CreatureBodies' tribal body has them, so its gear fits.
static func _person(s: Spec, elder: bool) -> void:
	s.cell = 0.0135
	var W := Color.WHITE
	var hair := Color(0.6, 0.58, 0.54) if elder else Color(0.12, 0.09, 0.07)
	var ochre := Color(0.72, 0.3, 0.16)
	var root := s.bone("Root", -1, Vector3(0, 0.52, 0))
	var head := s.bone("Head", root, Vector3(0, 0.8, 0), "head")
	# Legs first (left, right), so the tunic's hem blends onto them only
	# a little: leggings, knees, calves, wrapped feet.
	for sd: float in [-1.0, 1.0]:
		var x := 0.064 * sd
		var leg := s.bone("Leg" + ("L" if sd < 0.0 else "R"), root, Vector3(x, 0.5, 0.0), "leg")
		s.hide(s.cap(Vector3(x, 0.49, 0.0), Vector3(x, 0.28, -0.004), 0.05, 0.037, leg, W, 0.02, 3), 0.72) # thigh
		s.hide(s.ell(Vector3(x, 0.276, -0.01), Vector3(0.035, 0.033, 0.035), leg, W, 0.014, Basis.IDENTITY, 3), 0.72) # knee
		s.hide(s.ell(Vector3(x, 0.2, 0.01), Vector3(0.035, 0.068, 0.037), leg, W, 0.02, Basis.IDENTITY, 3), 0.72) # calf
		s.hide(s.cap(Vector3(x, 0.27, -0.004), Vector3(x * 1.02, 0.05, 0.004), 0.034, 0.025, leg, W, 0.014, 3), 0.72) # shin
		s.hide(s.ell(Vector3(x * 1.03, 0.024, -0.026), Vector3(0.033, 0.025, 0.068), leg, W, 0.02, Basis.IDENTITY, 3), 0.5) # foot
		s.hide(s.paint(Vector3(x, 0.08, 0.0), Vector3(0.045, 0.035, 0.045), W, 0.008), 0.5) # ankle wraps
	# The tunic: hips and skirt, waist, chest, shoulders.
	s.hide(s.ell(Vector3(0, 0.465, 0.004), Vector3(0.118, 0.065, 0.094), root, W, 0.015, Basis.IDENTITY, 3)) # skirt
	s.hide(s.ell(Vector3(0, 0.53, 0.0), Vector3(0.104, 0.08, 0.08), root, W, 0.04, Basis.IDENTITY, 3)) # hips
	s.hide(s.cap(Vector3(0, 0.54, 0.0), Vector3(0, 0.65, -0.004), 0.088, 0.098, root, W, 0.05, 3)) # waist
	s.hide(s.ell(Vector3(0, 0.69, -0.01), Vector3(0.108, 0.088, 0.07), root, W, 0.05, Basis.IDENTITY, 3)) # chest
	s.hide(s.ell(Vector3(0, 0.765, 0.004), Vector3(0.14, 0.04, 0.06), root, W, 0.04, Basis.IDENTITY, 3)) # shoulders
	if elder:
		s.hide(s.ell(Vector3(0, 0.75, 0.012), Vector3(0.165, 0.08, 0.1), root, W, 0.03, Basis.IDENTITY, 1), 1.25) # fur mantle
		s.hide(s.ell(Vector3(0, 0.56, 0.062), Vector3(0.12, 0.22, 0.032), root, W, 0.025, Basis.IDENTITY, 1), 1.2) # drape down the back
	# Neck and head: skull, face and jaw, chin, brow, cheekbones, nose,
	# ears; the hair over the crown and back, a tail tied at the nape.
	s.skin(s.cap(Vector3(0, 0.77, 0.004), Vector3(0, 0.86, -0.004), 0.036, 0.031, head, W, 0.03, 0))
	s.skin(s.ell(Vector3(0, 0.915, 0.006), Vector3(0.057, 0.066, 0.064), head, W, 0.03, Basis.IDENTITY, 0))
	s.skin(s.ell(Vector3(0, 0.878, -0.02), Vector3(0.044, 0.04, 0.044), head, W, 0.03, Basis.IDENTITY, 0))
	s.skin(s.ell(Vector3(0, 0.852, -0.042), Vector3(0.02, 0.016, 0.016), head, W, 0.02, Basis.IDENTITY, 0))
	s.skin(s.ell(Vector3(0, 0.921, -0.047), Vector3(0.046, 0.013, 0.017), head, W, 0.02, Basis.IDENTITY, 0))
	for sd: float in [-1.0, 1.0]:
		s.skin(s.ell(Vector3(0.03 * sd, 0.896, -0.042), Vector3(0.018, 0.014, 0.014), head, W, 0.02, Basis.IDENTITY, 0))
		s.skin(s.ell(Vector3(0.058 * sd, 0.9, 0.006), Vector3(0.009, 0.019, 0.013), head, W, 0.008, Basis.IDENTITY, 0))
	s.skin(s.cap(Vector3(0, 0.912, -0.06), Vector3(0, 0.889, -0.069), 0.009, 0.012, head, W, 0.012, 0), 0.97)
	s.ell(Vector3(0, 0.93, 0.016), Vector3(0.063, 0.058, 0.066), head, hair, 0.012, Basis.IDENTITY, 1)
	s.cap(Vector3(0, 0.93, 0.07), Vector3(0, 0.78, 0.095), 0.02, 0.011, head, hair, 0.012, 1)
	if elder:
		s.ell(Vector3(0, 0.858, -0.04), Vector3(0.036, 0.042, 0.024), head, hair, 0.015, Basis.IDENTITY, 1) # beard
		s.ell(Vector3(0, 0.88, -0.058), Vector3(0.027, 0.008, 0.01), head, hair, 0.008, Basis.IDENTITY, 1) # moustache
	# Arms (left, right), hanging a little out from the sides: shoulder,
	# upper arm, elbow, forearm, hand and thumb.
	for sd: float in [-1.0, 1.0]:
		var arm := s.bone("Arm" + ("L" if sd < 0.0 else "R"), root, Vector3(0.14 * sd, 0.775, 0.0), "arm")
		s.skin(s.ell(Vector3(0.145 * sd, 0.752, 0.0), Vector3(0.04, 0.048, 0.042), arm, W, 0.025, Basis.IDENTITY, 0))
		s.skin(s.cap(Vector3(0.145 * sd, 0.755, 0.0), Vector3(0.163 * sd, 0.6, 0.012), 0.034, 0.027, arm, W, 0.02, 0))
		s.skin(s.ell(Vector3(0.164 * sd, 0.598, 0.014), Vector3(0.026, 0.026, 0.026), arm, W, 0.012, Basis.IDENTITY, 0))
		s.skin(s.ell(Vector3(0.166 * sd, 0.56, 0.008), Vector3(0.029, 0.045, 0.029), arm, W, 0.015, Basis.IDENTITY, 0))
		s.skin(s.cap(Vector3(0.164 * sd, 0.598, 0.014), Vector3(0.17 * sd, 0.452, -0.002), 0.027, 0.02, arm, W, 0.012, 0))
		s.skin(s.ell(Vector3(0.173 * sd, 0.416, -0.006), Vector3(0.017, 0.036, 0.027), arm, W, 0.012, Basis.IDENTITY, 0))
		s.skin(s.cap(Vector3(0.166 * sd, 0.44, -0.028), Vector3(0.163 * sd, 0.405, -0.035), 0.008, 0.007, arm, W, 0.006, 0))
		s.hide(s.paint(Vector3(0.169 * sd, 0.49, 0.003), Vector3(0.032, 0.036, 0.032), W, 0.004, Basis.IDENTITY, 2), 0.55) # bracer
	# Belt, hem, face paint across the cheekbones.
	s.paint(Vector3(0, 0.575, -0.002), Vector3(0.13, 0.016, 0.105), ochre.darkened(0.3), 0.004, Basis.IDENTITY, 2)
	s.hide(s.paint(Vector3(0, 0.405, 0.004), Vector3(0.15, 0.03, 0.12), W, 0.01), 0.7)
	s.paint(Vector3(0, 0.884, -0.05), Vector3(0.052, 0.008, 0.03), ochre, 0.003)


# --- Meshing ---------------------------------------------------------------------

## Build a kind's mesh data in coat color `base` (thread-safe: no scene
## or resource objects).
static func compute(kind: String, base: Color) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var s := _spec(kind, base)
	var near := _mesh_arrays(s, s.cell)
	var far := _mesh_arrays(s, s.cell * 2.2)
	var bones: Array = []
	for i in s.bones.size():
		var bn: Array = s.bones[i]
		var parent: int = bn[1]
		var world: Vector3 = bn[2]
		var local := world - (s.bones[parent][2] as Vector3 if parent >= 0 else Vector3.ZERO)
		bones.append({"name": bn[0], "parent": parent, "world": world, "local": local, "role": bn[3]})
	return {"arrays": near.arrays, "far_arrays": far.arrays, "bones": bones,
		"tris": near.tris, "far_tris": far.tris, "ms": Time.get_ticks_msec() - t0}


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _sdf(s: Spec, p: Vector3) -> float:
	var d := 1e9
	for pr in s.prims:
		if p.distance_to(pr.bound_c) - pr.bound_r > d + pr.k:
			continue
		d = _smin(d, pr.dist(p), pr.k)
	return d


static func _mesh_arrays(s: Spec, cell: float) -> Dictionary:
	# Bounds of all the shapes, with a margin.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for pr in s.prims:
		lo = lo.min(pr.bound_c - Vector3.ONE * (pr.bound_r + pr.k))
		hi = hi.max(pr.bound_c + Vector3.ONE * (pr.bound_r + pr.k))
	lo -= Vector3.ONE * cell * 2.0
	hi += Vector3.ONE * cell * 2.0
	var n := Vector3i(((hi - lo) / cell).ceil()) + Vector3i.ONE
	var nx := n.x
	var ny := n.y
	var nz := n.z
	# Field samples.
	var f := PackedFloat32Array()
	f.resize(nx * ny * nz)
	for k in nz:
		for j in ny:
			for i in nx:
				f[(k * ny + j) * nx + i] = _sdf(s, lo + Vector3(i, j, k) * cell)
	# One vertex per cell the surface passes through: the mean of its edge
	# crossings.
	var cell_vert := PackedInt32Array()
	cell_vert.resize((nx - 1) * (ny - 1) * (nz - 1))
	cell_vert.fill(-1)
	var verts := PackedVector3Array()
	var corners: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var vals := PackedFloat32Array()
	vals.resize(8)
	for k in nz - 1:
		for j in ny - 1:
			for i in nx - 1:
				var inside := 0
				for c in 8:
					var cv: Vector3i = corners[c]
					vals[c] = f[((k + cv.z) * ny + j + cv.y) * nx + i + cv.x]
					if vals[c] < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var sum := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var va := vals[e[0]]
					var vb := vals[e[1]]
					if (va < 0.0) == (vb < 0.0):
						continue
					var t := va / (va - vb)
					var pa := Vector3(corners[e[0]])
					var pb := Vector3(corners[e[1]])
					sum += pa.lerp(pb, t)
					cnt += 1
				cell_vert[(k * (ny - 1) + j) * (nx - 1) + i] = verts.size()
				verts.append(lo + (Vector3(i, j, k) + sum / cnt) * cell)
	# Quads across every grid edge the surface crosses, joining the four
	# cells around it.
	var idx := PackedInt32Array()
	var cid := func(i: int, j: int, k: int) -> int:
		if i < 0 or j < 0 or k < 0 or i >= nx - 1 or j >= ny - 1 or k >= nz - 1:
			return -1
		return cell_vert[(k * (ny - 1) + j) * (nx - 1) + i]
	for k in nz:
		for j in ny:
			for i in nx:
				var v0 := f[(k * ny + j) * nx + i]
				for axis in 3:
					var di := 1 if axis == 0 else 0
					var dj := 1 if axis == 1 else 0
					var dk := 1 if axis == 2 else 0
					if i + di >= nx or j + dj >= ny or k + dk >= nz:
						continue
					var v1 := f[((k + dk) * ny + j + dj) * nx + i + di]
					if (v0 < 0.0) == (v1 < 0.0):
						continue
					var q: Array[int] = []
					match axis:
						0:
							q = [cid.call(i, j - 1, k - 1), cid.call(i, j, k - 1), cid.call(i, j, k), cid.call(i, j - 1, k)]
						1:
							q = [cid.call(i - 1, j, k - 1), cid.call(i - 1, j, k), cid.call(i, j, k), cid.call(i, j, k - 1)]
						2:
							q = [cid.call(i - 1, j - 1, k), cid.call(i, j - 1, k), cid.call(i, j, k), cid.call(i - 1, j, k)]
					if q.has(-1):
						continue
					idx.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	# Normals from the field's gradient; wind each triangle so Godot draws
	# it from outside ((v1 - v0) x (v2 - v0) must point inward).
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var e := cell * 0.5
	for vi in verts.size():
		var p := verts[vi]
		var g := Vector3(_sdf(s, p + Vector3(e, 0, 0)) - _sdf(s, p - Vector3(e, 0, 0)),
			_sdf(s, p + Vector3(0, e, 0)) - _sdf(s, p - Vector3(0, e, 0)),
			_sdf(s, p + Vector3(0, 0, e)) - _sdf(s, p - Vector3(0, 0, e)))
		normals[vi] = g.normalized() if g.length_squared() > 1e-12 else Vector3.UP
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var cr := (verts[idx[t + 1]] - a).cross(verts[idx[t + 2]] - a)
		var nsum := normals[idx[t]] + normals[idx[t + 1]] + normals[idx[t + 2]]
		if cr.dot(nsum) > 0.0:
			var tmp := idx[t + 1]
			idx[t + 1] = idx[t + 2]
			idx[t + 2] = tmp
	# Colors (blended across joins, then paint; a person's skin and hide
	# as weights in UV2), baked occlusion, material, bone weights.
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var tints := PackedVector2Array()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	colors.resize(verts.size())
	uvs.resize(verts.size())
	tints.resize(verts.size())
	bone_ids.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for vi in verts.size():
		var p := verts[vi]
		var dmin := INF
		var ds := PackedFloat32Array()
		ds.resize(s.prims.size())
		for pi in s.prims.size():
			var d := s.prims[pi].dist(p)
			ds[pi] = d
			dmin = minf(dmin, d)
		var col := Color(0, 0, 0)
		var tint := Vector2.ZERO
		var wsum := 0.0
		var mat := 1
		var best := INF
		var bw := {}
		for pi in s.prims.size():
			var pr := s.prims[pi]
			var d := ds[pi]
			var w := maxf(0.0, 1.0 - (d - dmin) / maxf(pr.k, 0.01))
			w *= w
			if w > 0.0:
				if pr.channel == 0:
					col += pr.color * w
				else:
					tint[pr.channel - 1] += pr.shade * w
				wsum += w
			if d < best:
				best = d
				mat = pr.mat
			# Skinning: bones of the shapes near the surface here.
			var sw := exp(-(d - dmin) / 0.02)
			if sw > 0.01:
				bw[pr.bone] = bw.get(pr.bone, 0.0) + sw
		col = col / maxf(wsum, 1e-6)
		tint /= maxf(wsum, 1e-6)
		for pp in s.paints:
			var d := pp.dist(p)
			var amt := 1.0 - smoothstep(-pp.soft, pp.soft, d)
			if amt > 0.0:
				col = col.lerp(pp.color if pp.channel == 0 else Color(0, 0, 0), amt)
				tint *= 1.0 - amt
				if pp.channel > 0:
					tint[pp.channel - 1] += pp.shade * amt
				if pp.mat >= 0 and amt > 0.5:
					mat = pp.mat
		# Occlusion: how much the field closes in along the normal.
		var nrm := normals[vi]
		var occ := 0.0
		for step in 4:
			var h := cell * (1.0 + step * 1.5)
			occ += (h - _sdf(s, p + nrm * h)) / h / pow(2.0, step)
		var ao := clampf(1.0 - occ * 0.9, 0.45, 1.0)
		colors[vi] = Color(col.r * ao, col.g * ao, col.b * ao, 1.0)
		tints[vi] = tint * ao
		uvs[vi] = Vector2(mat, 0.0)
		var ranked: Array = []
		for bi in bw:
			ranked.append([bw[bi], bi])
		ranked.sort_custom(func(x, y): return x[0] > y[0])
		var total := 0.0
		for r in mini(4, ranked.size()):
			total += float(ranked[r][0])
		for r in 4:
			if r < ranked.size():
				bone_ids[vi * 4 + r] = int(ranked[r][1])
				weights[vi * 4 + r] = float(ranked[r][0]) / total
			else:
				bone_ids[vi * 4 + r] = 0
				weights[vi * 4 + r] = 0.0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = tints
	arrays[Mesh.ARRAY_BONES] = bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	return {"arrays": arrays, "tris": idx.size() / 3}

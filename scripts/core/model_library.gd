class_name ModelLibrary
## Hand-made or generated character models (e.g. from Summer Engine's
## image-to-3D) dropped into assets/models/, used in place of the
## procedural bodies:
##   player.glb           the player (PlanetPlayer; else the elf,
##                        PlayerBody)
##   <species>.glb        a creature or NPC, by name in snake case:
##                        goblin.glb, deer.glb, arctic_wolf.glb,
##                        elder.glb, hunter.glb, skeleton.glb,
##                        hooded_one.glb ... (CreatureBodies.build;
##                        else the sculpted or primitive body)
## .glb or .gltf. If the engine has imported the file it's used as a
## scene; if not, it's read at runtime (GLTFDocument).
##
## An optional sidecar <name>.json next to it tunes it (all optional):
##   {"height_m": 1.75,        player: height to scale to (creatures use
##                             their species size_m instead)
##    "measure": "height",     what size means: "height", or "length"
##                             (nose to tail, for animals)
##    "yaw_deg": 180,          turn to face -Z (glTF models face +Z, so
##                             180 by default)
##    "lighting": "world",     "world": our lighting on its textures;
##                             "own": keep its materials untouched
##    "animations": {"idle": "Idle", "walk": "Walk", "sprint": "Run",
##                   "crouch": "Crouch", "crouch_walk": "CrouchWalk",
##                   "air": "Jump", "swim": "Swim", "climb": "Climb",
##                   "sit": "Sit"}}
## Clip names not given are matched by name (case-insensitive: a clip
## called "walk" or "Walking" serves "walk"); a missing state falls back
## to idle, then to the first clip.
##
## load_model() returns a Node3D, normalized: feet at y = 0, centered,
## facing -Z, 1 unit tall (or long) for creatures (CreatureBodies scales
## by size_m) or height_m for the player, with a ModelAnimator child
## named "Animator" when the model has animations.

const DIR := "res://assets/models/"

static var _cache := {} # name -> PackedScene or null (none)


## The model called `name` (no extension), or null if there's none.
## `unit`: normalize to 1 tall/long (creatures), else to height_m.
static func load_model(name: String, unit := false) -> Node3D:
	var scene := _scene(name)
	if scene == null:
		return null
	var model: Node3D = scene.instantiate()
	var opts := _sidecar(name)
	return _prepare(model, opts, unit)


## Does a model called `name` exist?
static func has_model(name: String) -> bool:
	return _scene(name) != null


## The file name for a species or NPC name: "Arctic wolf" -> "arctic_wolf".
static func name_for(label: String) -> String:
	return label.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


static func _scene(name: String) -> PackedScene:
	if _cache.has(name):
		return _cache[name]
	var scene: PackedScene = null
	for ext: String in [".glb", ".gltf"]:
		var path := DIR + name + ext
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
		elif FileAccess.file_exists(path):
			scene = _read_raw(path)
		if scene:
			break
	_cache[name] = scene
	return scene


## A .glb/.gltf the engine hasn't imported: read it at runtime.
static func _read_raw(path: String) -> PackedScene:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		push_warning("ModelLibrary: can't read %s" % path)
		return null
	var root := doc.generate_scene(state)
	if root == null:
		return null
	_own(root, root)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


## Every node's owner set to `root`, so it's packed with it.
static func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)


static func _sidecar(name: String) -> Dictionary:
	var path := DIR + name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Scale, place and turn the model; relight it; attach its animator.
static func _prepare(model: Node3D, opts: Dictionary, unit: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Model"
	var inner := Node3D.new()
	inner.name = "Pose"
	holder.add_child(inner)
	inner.add_child(model)
	inner.rotation.y = deg_to_rad(float(opts.get("yaw_deg", 180.0)))
	# Bounds in the model's own space (rest pose).
	var box := _bounds(model, Transform3D.IDENTITY)
	if box.size.length() > 0.0:
		var measure: String = opts.get("measure", "height")
		var size := box.size.z if measure == "length" else box.size.y
		var target := 1.0 if unit else float(opts.get("height_m", 1.75))
		var k := target / maxf(size, 1e-4)
		model.scale *= k
		var c := box.get_center() * k
		model.position -= Vector3(c.x, box.position.y * k, c.z)
	if opts.get("lighting", "world") == "world":
		_relight(model)
	var anim := _find_player(model)
	if anim:
		var animator := ModelAnimator.new()
		animator.name = "Animator"
		animator.player = anim
		animator.clips = opts.get("animations", {})
		holder.add_child(animator)
	return holder


static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b := here * (n as MeshInstance3D).mesh.get_aabb()
		box = b
		first = false
	for c in n.get_children():
		var cb := _bounds(c, here)
		if cb.size.length() > 0.0:
			box = cb if first else box.merge(cb)
			first = false
	return box


## Our lighting on the model's own textures and colors.
static func _relight(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var src := mi.get_active_material(s)
				mi.set_surface_override_material(s, _world_material(src))
	for c in n.get_children():
		_relight(c)


static func _world_material(src: Material) -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/model.gdshader")
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		m.set_shader_parameter("albedo_color", b.albedo_color)
		if b.albedo_texture:
			m.set_shader_parameter("albedo_texture", b.albedo_texture)
			m.set_shader_parameter("use_texture", true)
		m.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.set_shader_parameter("alpha_scissor", maxf(b.alpha_scissor_threshold, 0.3))
		if b.emission_enabled:
			m.set_shader_parameter("emission_color", b.emission)
			m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	elif src != null:
		# A material we can't read (a custom shader): leave it as it is.
		return src
	Look.register(m)
	return m


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null

extends SceneTree
## A picture of one Amorphophallus model on its own, no planet (seconds,
## not the minutes of tools/aroid_view.gd's world walk): the species'
## leaf (the umbrella stand-in, PlantMeshes) beside its inflorescence in
## full bloom (AroidMeshes + shaders/aroid_part.gdshader, the parts sized
## and coloured the way AroidGarden emits them), a plain green ground, one
## sun. Also a close shot of the inflorescence.
##
##   SPECIES="Amorphophallus titanum" OUT_DIR=/tmp/shots xvfb-run -a \
##     ~/bin/godot --path . --rendering-method forward_plus --resolution 960x540 \
##     -s tools/aroid_model_view.gd
## Writes model_<species>.png and model_<species>_bloom.png.

var out_dir := "/tmp/shots"


func _initialize() -> void:
	if OS.get_environment("OUT_DIR") != "":
		out_dir = OS.get_environment("OUT_DIR")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _col(hex, fallback: Color) -> Color:
	var c := Color.from_string(str(hex), fallback) if hex != null else fallback
	return c.srgb_to_linear()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var name := OS.get_environment("SPECIES") if OS.get_environment("SPECIES") != "" else "Amorphophallus titanum"
	var sp := SpeciesDB.find(name)
	if sp == null:
		print("[model] no species " + name)
		quit(1)
		return
	var h: float = lerpf(float(sp.height_m.x), float(sp.height_m.y), 0.7) if sp.height_m is Vector2 else 3.0
	print("[model] %s, %.1f m" % [sp.name, h])
	# Sane shared look values (no sky system here).
	Look.apply({"look_fog_density": 0.0, "look_night": 0.0, "look_glow": 0.0, "look_mist": 0.0,
		"look_planet_center": Vector3(0, -1.0e6, 0), "look_planet_radius": 1.0e6, "look_up": Vector3.UP,
		"look_canopy_dark": 0.0, "look_height_density": 0.0})
	RenderingServer.global_shader_parameter_set("plant_wind", Vector3.ZERO)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.78, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.8, 0.75)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.32, 0.14)
	ground.material_override = gm
	root.add_child(ground)
	# The leaf: the species' own plant mesh, one instance, to the left.
	var leaf := MeshInstance3D.new()
	leaf.mesh = PlantMeshes.mesh_for(sp, PlantMeshes.LOD_HERO)
	leaf.material_override = PlantMeshes.material_for(sp)
	leaf.position = Vector3(-h * 0.7, 0, 0)
	leaf.scale = Vector3.ONE * h
	root.add_child(leaf)
	# The inflorescence, in bloom, to the right: the parts as AroidGarden
	# emits them (peduncle, spathe fully open, appendix, pollen).
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/aroid_part.gdshader")
	var bud: Dictionary = sp.cycle.get("bud", {})
	var pet: Dictionary = sp.aroid.get("petiole", {})
	var spa: Dictionary = sp.aroid.get("spathe", {})
	var ped_c := _col(pet.get("base"), Color(0.35, 0.45, 0.3))
	var ped_c2 := _col(pet.get("spots"), ped_c.lightened(0.4))
	var ped_m := float(AroidGarden.PATTERN_MODE.get(str(pet.get("pattern", "mottled")), 1.0))
	var so := _col(spa.get("outside"), Color(0.45, 0.2, 0.25))
	var si := _col(spa.get("inside"), Color(0.3, 0.05, 0.1))
	var app_c := _col(sp.flower.get("spadix") if sp.flower != null else null, Color(0.88, 0.84, 0.55))
	var ped_cm = bud.get("peduncle_cm", [10, 30])
	var ped := minf((float(ped_cm[0]) + float(ped_cm[1])) * 0.005, h)
	var dims := AroidGarden.bloom_dims(h)
	var s_len: float = dims.x
	var a_len: float = dims.y
	var a_r: float = dims.z
	var o := Vector3(h * 0.5, 0, 0)
	var top := o + Vector3.UP * ped
	var parts := {
		"peduncle": [Vector3(s_len * 0.07, 0, 0), Vector3(0, ped, 0), Vector3(0, 0, s_len * 0.07), o, ped_c, ped_c2, ped_m],
		"spathe": [Vector3(s_len * 0.42, 0, 0), Vector3(0, s_len, 0), Vector3(0, 0, s_len * 0.42), top, so, si, 10.0],
		"appendix": [Vector3(a_r, 0, 0), Vector3(0, a_len, 0), Vector3(0, 0, a_r), top + Vector3.UP * s_len * 0.05, app_c, app_c, 0.0],
		"pollen": [Vector3(s_len * 0.15, 0, 0), Vector3(0, s_len * 0.05, 0), Vector3(0, 0, s_len * 0.15), top + Vector3.UP * s_len * 0.14, Color(0.95, 0.8, 0.25).srgb_to_linear(), Color.BLACK, 12.0],
	}
	for p in parts:
		var a: Array = parts[p]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = AroidMeshes.get_mesh(p)
		mm.instance_count = 1
		var x: Vector3 = a[0]
		var y: Vector3 = a[1]
		var z: Vector3 = a[2]
		var org: Vector3 = a[3]
		var c: Color = a[4]
		var c2: Color = a[5]
		mm.buffer = PackedFloat32Array([x.x, y.x, z.x, org.x, x.y, y.y, z.y, org.y, x.z, y.z, z.z, org.z,
			c.r, c.g, c.b, 1.0, c2.r, c2.g, c2.b, float(a[6])])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		root.add_child(mi)
	var total_h: float = ped + s_len * 0.05 + a_len
	print("[model] bloom: peduncle %.2f m, spathe %.2f m, appendix %.2f m: %.1f m tall" % [ped, s_len, a_len, total_h])
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.05
	root.add_child(cam)
	cam.current = true
	# Both, from a little above eye height, back far enough for the taller.
	var tall := maxf(h, total_h)
	var mid := Vector3(0, tall * 0.45, 0)
	var eye := mid + Vector3(0.35, 0.12, 1.0).normalized() * tall * 2.3
	cam.global_transform = Transform3D(Basis.looking_at((mid - eye).normalized(), Vector3.UP), eye)
	await _frames(6)
	var tag := sp.name.replace(" ", "_").to_lower()
	get_root().get_texture().get_image().save_png("%s/model_%s.png" % [out_dir, tag])
	# The inflorescence, close.
	# From a little below the rim, as the photos are: the frilled limb,
	# the maroon inside and the spike over it.
	var bm := top + Vector3.UP * (s_len * 0.5 + a_len * 0.3)
	var be := top + Vector3.UP * s_len * 0.3 + Vector3(0.35, 0.0, 1.0).normalized() * (a_len + s_len) * 1.15
	cam.global_transform = Transform3D(Basis.looking_at((bm - be).normalized(), Vector3.UP), be)
	await _frames(6)
	get_root().get_texture().get_image().save_png("%s/model_%s_bloom.png" % [out_dir, tag])
	print("[model] wrote %s/model_%s.png and _bloom.png" % [out_dir, tag])
	quit()

extends SceneTree
## The glossy look's check (design §GB, queue 111; GlossyLook, look.json
## glossy). Rendered, once per preset:
##   LOOK=pixel  xvfb-run -a -s "-screen 0 1280x720x24" ~/bin/godot --path . \
##     --rendering-method forward_plus --resolution 1280x720 -s tools/glossy_check.gd
##   LOOK=glossy (the same)
## Run pixel first: glossy compares its saturation with pixel's (kept in
## user://glossy_check/pixel.json). Frames go to OUT (default
## user://glossy_check/<preset>/): 01 the hearth room from where you wake,
## 02 a corridor with its sconce relit, 03 a cold corridor by your torch,
## 04 the same with the torch smothered.
## Asserts: the crawler boots under the preset; glossy draws the 3D at the
## window's size (the root's texture is the window's, no canvas downscale)
## and runs no dither, grain or posterising, the stone is the GLOSSY
## shader (linear, specular), the environment ACES with bloom, adjusted
## and fogged indigo; pixel keeps its 854x480 frame and its dither. Frame
## numbers (glossy): the darkest 5 % near #07071a (within 0.06 a channel,
## blue the strongest), the mean hue of the coloured pixels in the blue
## band (200-250 degrees), the mean saturation over pixel's, and in the
## cold corridor warm pixels only with the torch lit (smothered: under
## 0.2 %). The frame time over 120 frames standing in the hearth room is
## printed (lavapipe here, a CPU renderer: it is reported, not judged).
## QUICK=1 renders the hearth room alone.

var fails := 0
var out_dir := ""
var preset := ""


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("  frame %s (%dx%d)" % [name, img.get_width(), img.get_height()])
	return img


## The frame's numbers: the darkest 5 %'s mean colour, the mean hue (a
## circular mean, weighted by saturation) of pixels with some colour, the
## mean saturation, the warm share (red well over blue).
func _stats(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(w / 320, 1)
	var lum: Array = []
	var hx := 0.0
	var hy := 0.0
	var sat := 0.0
	var warm := 0
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c := img.get_pixel(x, y)
			lum.append([c.r * 0.3 + c.g * 0.59 + c.b * 0.11, c])
			sat += c.s
			if c.s > 0.15 and c.v > 0.03:
				hx += cos(c.h * TAU) * c.s
				hy += sin(c.h * TAU) * c.s
			if c.r > c.b * 1.6 and c.r > 0.25:
				warm += 1
	lum.sort_custom(func(a, b): return a[0] < b[0])
	var n := maxi(lum.size() / 20, 1)
	var dark := Color(0, 0, 0)
	for i in n:
		dark += lum[i][1]
	dark = dark / float(n)
	var hue := fposmod(rad_to_deg(atan2(hy, hx)), 360.0)
	return {"dark": dark, "hue": hue, "sat": sat / lum.size(), "warm": float(warm) / lum.size()}


func _say(name: String, s: Dictionary) -> void:
	print("  %s: darkest 5%% #%s, mean hue %.0f deg, mean saturation %.3f, warm %.2f%%" % [name, (s.dark as Color).to_html(false), s.hue, s.sat, float(s.warm) * 100.0])


func _run() -> void:
	WorldSave.read_only = true
	Boss.pool_off = true
	Residents.stay_asleep = true
	Torch.burn_down = false
	Controls.path = "user://controls_glossy.cfg"
	if OS.get_environment("SEED") == "":
		OS.set_environment("SEED", "7")
	preset = "glossy" if GlossyLook.wanted() else "pixel"
	var base := ProjectSettings.globalize_path("user://glossy_check")
	out_dir = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else base.path_join(preset)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: CrawlerMain = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	while not main.baked:
		await process_frame
	var boss: Variant = main.get("boss")
	if boss is Boss:
		(boss as Boss).auto = false
	await _frames(30)
	ok(GlossyLook.active == (preset == "glossy"), "the crawler boots under preset %s" % preset)
	var win := get_root()
	var tex_size := win.get_texture().get_size()
	var pm := main.post._rect.material as ShaderMaterial
	if preset == "glossy":
		ok(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and Vector2i(tex_size) == win.size, "the 3D is drawn at the window's own size (%dx%d), not a fixed frame" % [tex_size.x, tex_size.y])
		ok(float(pm.get_shader_parameter("dither")) == 0.0 and float(pm.get_shader_parameter("grain")) == 0.0 and float(pm.get_shader_parameter("levels")) >= 255.0, "no dither, grain or posterising in the post grade")
		var st := RuinBuilder.material_lit()
		var code := st.shader.code
		ok(st == GlossyLook.stone_material() and code.contains("#define GLOSSY") and code.contains("filter_linear_mipmap_anisotropic") and not code.contains("specular_disabled"), "the stone is the glossy shader: linear, mipmapped, anisotropic, specular on")
		var env: Environment = main.environment
		ok(env.tonemap_mode == Environment.TONE_MAPPER_ACES and env.glow_enabled and env.adjustment_enabled and env.fog_enabled, "the environment: ACES, bloom, contrast %.2f saturation %.2f, fog %.3f/m #%s" % [env.adjustment_contrast, env.adjustment_saturation, env.fog_density, env.fog_light_color.to_html(false)])
	else:
		ok(win.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and tex_size.y == Display.lines(), "pixel keeps its fixed frame (%dx%d)" % [tex_size.x, tex_size.y])
		ok(float(pm.get_shader_parameter("dither")) > 0.0, "pixel keeps its dither")
	var p := main.player
	# 01 the hearth room, from where you wake.
	var hearth := _stats(await _shot("01_hearth_room"))
	_say("hearth room", hearth)
	# QUICK=1: just the hearth room (tuning by eye).
	if OS.get_environment("QUICK") != "":
		_finish()
		return
	# The frame time standing there.
	var t0 := Time.get_ticks_usec()
	await _frames(120)
	var ms := float(Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	print("  frame time in the hearth room: %.1f ms (%s, %dx%d; lavapipe is a CPU renderer)" % [ms, preset, tex_size.x, tex_size.y])
	# 02 a corridor with its sconce relit; 03 another, cold, by torchlight;
	# 04 the same, the torch smothered.
	var lit_s: Node3D = null
	var cold_s: Node3D = null
	for h in main.fires.holders:
		if str(h.get_meta("fire_holder")) != "sconce" or str((main.lay.pieces[int(h.get_meta("piece"))] as Dictionary).kind) != "corridor" or FireStore.is_lit(h):
			continue
		if lit_s == null:
			lit_s = h
		elif cold_s == null and h.global_position.distance_to(lit_s.global_position) > 14.0:
			cold_s = h
	ok(lit_s != null and cold_s != null, "two corridors with sconces to look down")
	if lit_s == null or cold_s == null:
		_finish()
		return
	FireStore.relight(lit_s)
	var stand := _stand(lit_s)
	p.spawn_flat(stand[0], stand[1], -0.05)
	await _frames(20)
	var lit := _stats(await _shot("02_lit_corridor"))
	_say("lit corridor", lit)
	if not p.inventory.has_kind("torch"):
		p.inventory.add(Inventory.make("torch"))
	p.weapon = "torch"
	p.torch.light()
	stand = _stand(cold_s)
	p.spawn_flat(stand[0], stand[1], -0.05)
	await _frames(20)
	var torch := _stats(await _shot("03_cold_corridor_torch"))
	_say("cold corridor by torch", torch)
	p.torch.douse()
	await _frames(40)
	var cold := _stats(await _shot("04_cold_corridor_smothered"))
	_say("cold corridor smothered", cold)
	var mine := {"hearth_sat": hearth.sat, "lit_sat": lit.sat, "torch_sat": torch.sat}
	var f := FileAccess.open(base.path_join(preset + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(mine))
	f.close()
	if preset == "glossy":
		var target := Color("#07071a")
		for pair in [["hearth room", hearth], ["lit corridor", lit]]:
			var d: Color = pair[1].dark
			ok(absf(d.r - target.r) < 0.06 and absf(d.g - target.g) < 0.06 and absf(d.b - target.b) < 0.06 and d.b >= d.r and d.b >= d.g, "%s: the darkest 5%% near #07071a (#%s)" % [pair[0], d.to_html(false)])
		for pair in [["hearth room", hearth], ["lit corridor", lit], ["cold corridor smothered", cold]]:
			ok(float(pair[1].hue) >= 200.0 and float(pair[1].hue) <= 250.0, "%s: the mean hue in the blue band (%.0f deg)" % [pair[0], pair[1].hue])
		ok(float(torch.warm) > 0.0 and float(cold.warm) < 0.002, "the cold corridor: warm only with the torch lit (lit %.2f%%, smothered %.2f%%)" % [float(torch.warm) * 100.0, float(cold.warm) * 100.0])
		var pf := base.path_join("pixel.json")
		if FileAccess.file_exists(pf):
			var px: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pf))
			for k in ["hearth_sat", "lit_sat", "torch_sat"]:
				ok(float(mine[k]) > float(px[k]), "%s: saturation over pixel's (%.3f > %.3f)" % [k, mine[k], px[k]])
		else:
			print("  (no pixel.json yet: run LOOK=pixel first to compare saturation)")
	_finish()


## Where to stand for a sconce: 3.5 m along its corridor, looking along.
func _stand(s: Node3D) -> Array:
	var nrm := s.global_basis.z
	var along := nrm.cross(Vector3.UP).normalized()
	var at := s.global_position - Vector3(0.0, float(CrawlerFires.HOLD.get("sconce_h_m", 1.7)), 0.0) + nrm * 0.7 - along * 3.5
	return [at, atan2(-along.x, -along.z)]


func _finish() -> void:
	if FileAccess.file_exists(Controls.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Controls.path))
	print("[glossy_check] %s" % out_dir)
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)

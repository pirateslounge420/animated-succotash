extends SceneTree
## The volume sliders (AudioMix; settings panel, Audio): the Footsteps and
## Climbing buses and their defaults (half, from play), the footsteps on
## theirs, clicks on the panel's sliders (on the bar, left and right of it,
## down to mute) and the master volume. Leaves the settings as it found
## them (the defaults). OUT=<png> also saves the panel.
##
##   godot --headless --path . --script tools/audio_mix_check.gd
##   (a picture needs a renderer: xvfb-run ... --rendering-driver opengl3)

var fails := 0

func ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	HudText.install()
	for k in AudioMix.DEFAULTS:
		Settings.erase(k)
	AudioMix.apply()
	var fb := AudioServer.get_bus_index("Footsteps")
	var cb := AudioServer.get_bus_index("Climbing")
	ok(fb > 0 and cb > 0, "the Footsteps and Climbing buses exist (%d, %d)" % [fb, cb])
	ok(absf(AudioServer.get_bus_volume_db(fb) - linear_to_db(0.5)) < 0.01, "footsteps start at half (%.1f dB)" % AudioServer.get_bus_volume_db(fb))
	ok(absf(AudioServer.get_bus_volume_db(cb) - linear_to_db(0.5)) < 0.01, "climbing starts at half")
	ok(AudioServer.get_bus_send(fb) == "Master", "they send to Master")
	var steps := Footsteps.new()
	ok(steps.bus == "Footsteps", "the footsteps play on it")
	steps.free()
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.2, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(bg)
	var panel := SettingsPanel.new()
	get_root().add_child(panel)
	panel.open()
	for i in 3:
		await process_frame
	var row_f: Rect2
	var row_m: Rect2
	for r in panel._rows:
		if r[1][0] == "audio.footsteps":
			row_f = r[0]
		if r[1][0] == "audio.master":
			row_m = r[0]
	ok(row_f.has_area(), "the panel has a Footsteps slider row (%s)" % row_f)
	# A click at 80 % along the bar.
	var y := row_f.get_center().y
	panel.click(Vector2(row_f.position.x + SettingsPanel.BAR_X + SettingsPanel.BAR_W * 0.8, y))
	ok(AudioMix.percent("audio.footsteps") == 80, "a click on the bar sets it (80 %%: %d)" % AudioMix.percent("audio.footsteps"))
	ok(absf(AudioServer.get_bus_volume_db(fb) - linear_to_db(0.8)) < 0.01, "and the bus follows")
	# Left of the bar: 10 % less.
	panel.click(Vector2(row_f.position.x + 20, y))
	ok(AudioMix.percent("audio.footsteps") == 70, "left of the bar: 10 %% less (%d)" % AudioMix.percent("audio.footsteps"))
	# Right of it: 10 % more.
	panel.click(Vector2(row_f.position.x + SettingsPanel.BAR_X + SettingsPanel.BAR_W + 20, y))
	ok(AudioMix.percent("audio.footsteps") == 80, "right of it: 10 %% more (%d)" % AudioMix.percent("audio.footsteps"))
	# To zero: muted.
	panel.click(Vector2(row_f.position.x + SettingsPanel.BAR_X, y))
	ok(AudioMix.percent("audio.footsteps") == 0 and AudioServer.is_bus_mute(fb), "all the way down mutes it")
	# Master.
	panel.click(Vector2(row_m.position.x + SettingsPanel.BAR_X + SettingsPanel.BAR_W * 0.5, row_m.get_center().y))
	ok(AudioMix.percent("audio.master") == 50 and absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01, "the master volume slider sets Master")
	# Back to the defaults for the picture.
	for k in AudioMix.DEFAULTS:
		Settings.erase(k)
	AudioMix.apply()
	panel.queue_redraw()
	for i in 3:
		await process_frame
	if OS.get_environment("OUT") != "":
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT"))
	for k in AudioMix.DEFAULTS:
		Settings.erase(k)
	print("RESULT fails: %d" % fails)
	quit()

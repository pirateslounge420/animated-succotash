extends SceneTree
## Run: STAMP=1 godot --headless --path . --fixed-fps 60 --script tools/hud_pin_check.gd
## The HUD's parts and pins (Hud; data/hud.json "_help" parts, pins,
## modes): a new game pins exactly the speedometer and the clock; in normal
## play an unpinned part (wind) is hidden; H (toggle()) shows every part;
## set_pinned() saves at once (Settings) and shows the part in normal
## play. Pinning, the way main starts it when Esc frees the mouse: every
## part shows, a click on a part (biome, then the clock) pins or unpins it
## and stops there as GUI input (it never reaches _unhandled_input, where
## the player takes the mouse back), a click anywhere else goes on and ends
## pinning; not while the inventory is open. The pin settings are backed
## up first and put back after.
var main
var world
var hud: Hud
var probe: Probe
var fails := 0
## Pin key -> its saved value before the check (null: not saved).
var backup := {}


## Mouse presses that reach _unhandled_input (where PlanetPlayer takes the
## mouse back on any click while it's free).
class Probe extends Node:
	var clicks := 0

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			clicks += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func act(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	main._unhandled_input(e)


## A left click (press and release) at a point on the screen (the internal
## frame's px), through the viewport like a real one: _input, the GUI,
## then _unhandled_input.
func click(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		get_root().push_input(e, true)


func shown_parts() -> Array:
	return Array(Hud.PARTS).filter(func(id): return hud.is_shown(id))


func _initialize() -> void:
	# Back up every pin, then clear them: a new game's defaults.
	for id in Hud.PARTS:
		var key := Hud.pin_key(id)
		backup[key] = Settings.get_value(key) if Settings.has(key) else null
		Settings.erase(key)
	world = get_root().get_node("World")
	world.spawn_choice = 0
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	while not main._playing:
		await process_frame
	hud = main.hud
	probe = Probe.new()
	get_root().add_child(probe)
	await frames(30)

	# Defaults: the two dials pinned, nothing else (the ambient profile
	# pins hud.json pins_ambient: the clock alone, design 30 Sept §AU).
	var dials: Array = ["speedometer", "clock"]
	if Tuning.profile() == "ambient":
		dials = Array(Tuning.table("hud").get("pins_ambient", ["clock"]))
	var pinned := Array(Hud.PARTS).filter(func(id): return Hud.is_pinned(id))
	print("pinned by default: %s" % [pinned])
	ok(pinned == dials, "a new game pins exactly the profile's dials %s" % [dials])
	ok(Hud.pin_key("wind") == "hud.pin.wind" and Hud.pin_key("clock") == "hud.clock", "pin keys: hud.pin.<part>, the dials' own hud.speedometer / hud.clock")

	# Normal play: the pinned parts only.
	ok(not hud.full and not hud.pinning, "normal play (not the full HUD, not pinning)")
	ok(not hud.is_shown("wind"), "normal play: wind (not pinned) is hidden")
	ok(shown_parts() == dials, "normal play shows just the pinned dials: %s" % [shown_parts()])
	ok(hud.readouts.top_right_below == 0.0 and hud.readouts.clock_rect().position.y < 20.0, "the right column is empty, so the clock sits in the corner (y %.0f)" % hud.readouts.clock_rect().position.y)

	# H: the full HUD.
	act("toggle_hud")
	ok(hud.full, "H (toggle()) turns the full HUD on")
	ok(shown_parts() == Array(Hud.PARTS), "the full HUD shows every part: %s" % [shown_parts()])
	await frames(2)
	var texts := []
	for id in ["time", "season", "biome", "wind", "position"]:
		texts.append((hud._parts[id] as Label).text)
	print("   lines: %s" % [texts])
	ok(str(texts[2]).ends_with(" soil") and str(texts[3]).begins_with("Wind ") and str(texts[1]).contains("of the season"), "each part's line is filled in")
	ok(hud.readouts.clock_rect().position.y >= hud.part_rect("position").end.y, "the clock sits below the right column (clock y %.0f, column bottom %.0f)" % [hud.readouts.clock_rect().position.y, hud.part_rect("position").end.y])
	var left_gap: float = hud.part_rect("moon").position.y - hud.part_rect("time").end.y
	ok(left_gap >= 0.0 and left_gap <= 4.0, "one line per part, stacked with the old line spacing (%.0f px)" % left_gap)
	act("toggle_hud")
	ok(not hud.full and not hud.is_shown("wind"), "H again: the pinned parts only")

	# A pin: saved at once, shown in normal play.
	hud.set_pinned("wind", true)
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	ok(Hud.is_pinned("wind") and bool(cfg.get_value("hud", "pin.wind", false)), "set_pinned(\"wind\", true) is saved (user://settings.cfg hud/pin.wind)")
	ok(hud.is_shown("wind") and not hud.is_shown("biome"), "normal play now shows wind (and still not biome)")
	await frames(2)
	var wind_r := hud.part_rect("wind")
	ok(wind_r.position.y < 20.0 and wind_r.end.x > 800.0, "wind moves up to the top of the right column, no gap above it (%s)" % wind_r)
	ok(hud.readouts.clock_rect().position.y >= wind_r.end.y, "the clock sits just below it")

	# Pinning: Esc frees the mouse (main starts pinning: Hud.set_pinning()).
	act("release_mouse")
	await frames(3)
	ok(hud.pinning, "Esc (the mouse free, nothing open): the HUD is pinning")
	ok(shown_parts() == Array(Hud.PARTS), "pinning shows every part")
	ok(hud._caption.visible and hud._caption.text.begins_with("Click a readout to pin it"), "the caption shows")
	var dim := float(Hud.PINS.dim_alpha)
	var biome_l: Label = hud._parts["biome"]
	ok(is_equal_approx(biome_l.self_modulate.a, dim) and not (hud._marks["biome"] as Label).visible, "an unpinned part (biome) is dimmed to %.2f, no pin mark" % dim)
	ok((hud._parts["wind"] as Label).self_modulate.a == 1.0 and (hud._marks["wind"] as Label).visible and (hud._parts["wind"] as Label).text.begins_with(Hud.PIN_PAD), "a pinned part (wind) is full with its pin mark before it")
	ok(hud.readouts.mark["clock"] == 1.0 and is_equal_approx(hud.readouts.share["clock"], 1.0), "the pinned clock has its pin mark")

	# A click on the biome part: pins it, and the mouse stays free.
	var r := hud.part_rect("biome")
	ok(r.has_area(), "the biome part has a rect to click: %s" % r)
	var clicks0 := probe.clicks
	click(r.get_center())
	ok(Hud.is_pinned("biome"), "a click on the biome part pins it")
	ok(probe.clicks == clicks0, "the click stopped at the HUD: it never reached _unhandled_input (so the player doesn't take the mouse back)")
	await frames(3)
	ok(hud.pinning, "still pinning after it")
	ok(biome_l.self_modulate.a == 1.0 and (hud._marks["biome"] as Label).visible, "biome shows pinned now (full, with its mark)")
	cfg.load(Settings.PATH)
	ok(bool(cfg.get_value("hud", "pin.biome", false)), "biome's pin is saved at once")
	click(hud.part_rect("biome").get_center())
	await frames(1)
	ok(not Hud.is_pinned("biome") and probe.clicks == clicks0, "a second click unpins it")

	# The dials: the clock's rect (Readouts.clock_rect()).
	var cr := hud.part_rect("clock")
	ok(cr.has_area() and cr == hud.readouts.clock_rect(), "the clock has a click rect (Readouts.clock_rect(): %s)" % cr)
	click(cr.get_center())
	ok(not Hud.is_pinned("clock") and not Settings.get_bool("hud.clock", true), "a click on the clock unpins it (the settings panel's hud.clock)")
	await frames(2)
	ok(hud.readouts.mark["clock"] == 0.0 and is_equal_approx(hud.readouts.share["clock"], dim), "the unpinned clock is dimmed, no mark")
	click(hud.part_rect("clock").get_center())
	ok(Hud.is_pinned("clock") and probe.clicks == clicks0, "a click again pins it back")
	var sr := hud.part_rect("speedometer")
	ok(sr.has_area() and sr == hud.readouts.speedometer_rect() and sr.end.y > 400.0, "the speedometer has a click rect too, bottom right (%s)" % sr)
	ok(hud.part_at(Vector2(427, 240)) == "", "nothing to pin in the middle of the screen")

	# A click anywhere else: on to _unhandled_input (the player takes the
	# mouse back) and pinning ends.
	click(Vector2(427, 240))
	ok(probe.clicks == clicks0 + 1, "a click elsewhere goes on to _unhandled_input")
	await frames(3)
	ok(not hud.pinning and not hud._caption.visible, "and pinning ends")
	ok(shown_parts() == ["wind"] + dials, "normal play again: the pinned parts (%s)" % [shown_parts()])
	click(wind_r.get_center())
	ok(Hud.is_pinned("wind") and probe.clicks == clicks0 + 2, "out of pinning a click on a part doesn't touch its pin (it goes to the player)")

	# Not while a screen is open: Esc, then the inventory.
	act("release_mouse")
	await frames(2)
	ok(hud.pinning, "Esc again: pinning")
	act("inventory")
	await frames(2)
	ok(main.inventory_screen.visible and not hud.pinning, "the inventory opens: no pinning")
	act("inventory")
	await frames(2)
	ok(not main.inventory_screen.visible and not hud.pinning, "it closes (the mouse taken back): still none")

	# Put the settings back.
	for key in backup:
		if backup[key] == null:
			Settings.erase(key)
		else:
			Settings.set_value(key, backup[key])
	var back := true
	for key in backup:
		back = back and (Settings.get_value(key) == backup[key] if Settings.has(key) else backup[key] == null)
	ok(back, "the pin settings are back as they were")
	print("RESULT fails: %d" % fails)
	quit()

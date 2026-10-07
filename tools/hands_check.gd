extends SceneTree
## Two hands and the Controls page (design 6 Oct §FB, prompt 55), headless:
##   SEED=7 godot --headless --path . --fixed-fps 60 --script tools/hands_check.gd
## Plays the crawler with the input events a keyboard and a mouse send
## (Input.parse_input_event; clicks pushed at the panel's own coordinates)
## and asserts:
##  1. the right hand (hands.json right.holds): you wake with bare hands,
##     and with no torch the wheel leaves them so; with only the torch the
##     wheel goes torch → bare hands → torch, down and up; scrolling a lit
##     torch away puts it out (as built);
##  2. Q (weapon_swap) changes nothing in the crawler (q_swaps); the open
##     world keeps Q for its tool swap;
##  3. the left hand: a fire pot (FirePots, prompt 60) goes on the strip,
##     not in a carry slot; a tap of Tab does nothing and shows nothing;
##     Tab held shows the strip (the pot, an empty hand) inside the 480-line
##     frame, the one in hand marked; Tab+wheel goes item → empty → item and
##     the right hand stays; the pot shows in view while held (FirePots');
##  4. wheel_drives left: the plain wheel drives the left hand and
##     Tab+wheel the right, and Tab shows the right hand's choices;
##  5. the wheel's step: a notch is a step; a trackpad's small steps add
##     up to one step a stroke;
##  5b. the fire pots on the strip: F9 (dev) fills it with pots of both
##     oils, none in the carry slots; Tab+wheel steps once a notch through
##     all of them and back to empty (one hand answers, not two); while a
##     pot is being lit the left hand doesn't change;
##  6. the Controls page: every action on it once, named; the defaults
##     clash nowhere; click one and press a key: bound and saved, the key
##     caught before the game hears it; Esc cancels and leaves the panel
##     open; a clash in one game is marked, one across the two games not;
##     the wheel's switch; a key bound to the wheel's action steps a hand;
##  7. a restart (the crawler made anew, the file read again): the saved
##     bindings in force over DEFAULTS, the rest at their defaults, the
##     wheel's hand kept;
##  8. reset (asked once): every action's keys and buttons are DEFAULTS'
##     again, the wheel on the right, the file gone.
## The player's file is user://controls_check.cfg here, never the game's.

var fails := 0
var main: CrawlerMain
var p: CrawlerPlayer
var h: Hands


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	WorldSave.read_only = true
	Bow.need_capture = false
	Controls.path = "user://controls_check.cfg"
	_wipe()
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED").is_valid_int() else 7
	OS.set_environment("SEED", str(seed_v))
	await _boot()
	await _right()
	await _q()
	await _left()
	await _wheel_drives()
	await _wheel_step()
	await _pots()
	await _page()
	await _restart()
	await _reset()
	_wipe()
	print("RESULT fails: %d" % fails)
	quit(1 if fails > 0 else 0)


## A fresh crawler (as a new start: CrawlerMain runs Controls.ensure()).
func _boot() -> void:
	main = load("res://scenes/crawler.tscn").instantiate()
	get_root().add_child(main)
	for i in 10:
		await physics_frame
	while not main.baked:
		await process_frame
	p = main.player
	h = p.hands


func _wipe() -> void:
	if FileAccess.file_exists(Controls.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Controls.path))
	Controls.reload()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)


## One turn of the wheel (`factor` a notch's share: 1 a mouse's notch, less
## a trackpad's small step).
func _notch(down := true, factor := 1.0) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		e.factor = factor
		e.pressed = pressed
		Input.parse_input_event(e)
	await _frames(1)


## A left click at `at` in the frame's own pixels.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		get_root().push_input(e, true)
	await _frames(2)


func _place_facing(pl: CrawlerPlayer, at: Vector3, target: Vector3) -> void:
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	pl.spawn_flat(at, atan2(-flat.x, -flat.z))


func _left_name() -> String:
	return str(h.left_item().get("kind", "empty"))


## An action's keys and buttons by name.
func _keys(action: String) -> Array:
	var out: Array = []
	for ev in Controls.inputs(action):
		out.append(Controls.input_name(ev))
	return out


func _light_at_hearth() -> void:
	var hp := main.fires.hearth.global_position
	_place_facing(p, hp + Vector3(0.0, 0.0, 1.0), hp)
	if not p.torch.lit():
		p.torch.pass_flame()


func _right() -> void:
	ok(p.weapon == "hands" and h.right_choices() == ["hands"], "you wake with bare hands and nothing else to hold")
	await _notch(true)
	ok(p.weapon == "hands", "with no torch, the wheel leaves bare hands")
	var b := main.fires.bundle.global_position
	_place_facing(p, b + Vector3(1.0, 0.0, 0.0), b)
	ok(main.take_torch() and p.weapon == "torch" and h.right_choices() == ["torch", "hands"], "a torch from the bundle, in hand: the right hand's choices are the torch and bare hands (%s)" % str(h.right_choices()))
	var seq := [p.weapon]
	for i in 2:
		await _notch(true)
		seq.append(p.weapon)
	ok(seq == ["torch", "hands", "torch"], "with only the torch, the wheel goes %s" % " → ".join(seq))
	seq = [p.weapon]
	for i in 2:
		await _notch(false)
		seq.append(p.weapon)
	ok(seq == ["torch", "hands", "torch"], "and the same scrolling the other way: %s" % " → ".join(seq))
	_light_at_hearth()
	var was_lit := p.torch.lit()
	await _notch(true)
	ok(was_lit and p.weapon == "hands" and not bool(p.torch.item().get("lit", true)), "scrolling a lit torch away puts it out (Torch.stow, as built)")
	await _notch(true)
	ok(p.weapon == "torch" and p.torch.in_hand() and not p.torch.lit(), "scrolled back, the torch is in hand again, out")


func _q() -> void:
	_light_at_hearth()
	var lit := p.torch.lit()
	await _tap(KEY_Q)
	ok(lit and p.weapon == "torch" and p.torch.lit(), "Q changes nothing in the crawler: the lit torch stays in hand, lit (hands.json q_swaps %s)" % str(Hands.q_swaps()))
	await _notch(true)
	await _tap(KEY_Q)
	ok(p.weapon == "hands", "nor with bare hands: Q leaves them empty")
	await _notch(true)
	var q := Controls.key_event(KEY_Q)
	ok(InputMap.event_is_action(q, "weapon_swap") and Controls.DEFAULTS.weapon_swap == [KEY_Q], "the open world keeps Q for its tool swap (weapon_swap)")


func _left() -> void:
	var fp := main.fire_pots
	var strip: Array = p.inventory.strip
	ok(strip.size() == 3 and strip.count(null) == 3, "the pack's left-hand strip: %d places, empty (hands.json left.strip_slots)" % strip.size())
	var carried := p.inventory.count()
	ok(fp.give("tar") and strip[0] is Dictionary and str(strip[0].get("kind", "")) == "fire_pot" and p.inventory.count() == carried and not p.inventory.has_kind("fire_pot"), "a fire pot goes on the strip, not in a carry slot")
	await _frames(2)
	ok(h.left == -1 and fp.in_left().is_empty() and not fp._view.visible, "the left hand starts empty")
	# A tap of Tab.
	var before := [p.weapon, h.left]
	var shown := false
	_key(KEY_TAB, true)
	for i in 3:
		await _frames(1)
		shown = shown or h.strip_showing() or main.hand_strip.visible
	_key(KEY_TAB, false)
	await _frames(2)
	shown = shown or main.hand_strip.visible
	ok(not shown and [p.weapon, h.left] == before, "a tap of Tab does nothing in the crawler and shows nothing")
	# Tab held.
	_key(KEY_TAB, true)
	await _frames(15)
	ok(h.strip_showing() and main.hand_strip.visible, "Tab held shows the strip (once held %.2f s: tab_hold.show_after_s)" % float(Hands._tab().get("show_after_s", 0.15)))
	var lay: Dictionary = main.hand_strip.layout()
	var cells: Array = lay.cells
	ok(str(lay.hand) == "left" and cells.size() == 2 and str((cells[0][1] as Dictionary).get("kind", "")) == "fire_pot" and (cells[1][1] as Dictionary).is_empty() and bool(cells[1][2]) and not bool(cells[0][2]), "the strip: the pot and an empty hand, the empty one marked")
	var frame := Rect2(Vector2.ZERO, main.hand_strip.size)
	ok(Vector2i(main.hand_strip.size) == Display.internal_size() and frame.encloses(lay.panel) and (lay.panel as Rect2).position.x < frame.size.x * 0.5, "inside the 480-line frame, low on the left (%s in %s)" % [str(lay.panel), str(main.hand_strip.size)])
	var w0 := p.weapon
	var seq := [_left_name()]
	var marked := true
	var in_view := true
	for i in 3:
		await _notch(true)
		await _frames(1)
		seq.append(_left_name())
		var cl: Array = main.hand_strip.layout().cells
		marked = marked and bool(cl[0][2]) == (_left_name() == "fire_pot")
		var fl := main.fire_pots.in_left()
		var same := fl.is_empty() == h.left_item().is_empty() and (fl.is_empty() or is_same(fl, h.left_item()))
		in_view = in_view and main.fire_pots._view.visible == (_left_name() == "fire_pot") and same
	ok(seq == ["empty", "fire_pot", "empty", "fire_pot"], "Tab+wheel goes %s" % " → ".join(seq))
	ok(p.weapon == w0, "and the right hand stays as it was (%s)" % p.weapon)
	ok(marked, "the strip marks the one in hand as it steps")
	ok(in_view, "the pot shows low left in view while it's in hand (FirePots' view, the same pot), and not when the hand is empty")
	_key(KEY_TAB, false)
	await _frames(2)
	ok(not main.hand_strip.visible and _left_name() == "fire_pot", "Tab let go: the strip goes, the pot stays in hand")


func _wheel_drives() -> void:
	Controls.set_wheel_drives("left")
	ok(Hands.wheel_hand() == "left" and Hands.tab_hand() == "right", "wheel_drives left (the Controls page's switch, saved)")
	var w0 := p.weapon
	var seq := [_left_name()]
	for i in 2:
		await _notch(true)
		seq.append(_left_name())
	ok(p.weapon == w0 and seq == ["fire_pot", "empty", "fire_pot"], "the plain wheel steps the left hand (%s), the right stays (%s)" % [" → ".join(seq), p.weapon])
	_key(KEY_TAB, true)
	await _frames(2)
	var rs := [p.weapon]
	for i in 2:
		await _notch(true)
		rs.append(p.weapon)
	ok(_left_name() == "fire_pot" and rs == ["torch", "hands", "torch"], "and Tab+wheel the right (%s), the left stays" % " → ".join(rs))
	await _frames(2)
	var lay: Dictionary = main.hand_strip.layout()
	var cells: Array = lay.cells
	var panel: Rect2 = lay.panel
	ok(main.hand_strip.visible and str(lay.hand) == "right" and cells.size() == 2 and str((cells[0][1] as Dictionary).get("kind", "")) == "torch" and (cells[1][1] as Dictionary).is_empty() and panel.position.x > main.hand_strip.size.x * 0.5 and panel.end.x <= main.hand_strip.size.x, "Tab held shows the right hand's choices (the torch, bare hands), low on the right")
	_key(KEY_TAB, false)
	await _frames(2)
	Controls.set_wheel_drives("right")
	ok(Hands.wheel_hand() == "right", "back to the right")


func _wheel_step() -> void:
	await _frames(30)
	var n0 := h.steps
	for i in 3:
		await _notch(true, 0.3)
	ok(h.steps == n0, "a trackpad's small steps (0.3 of a notch each) don't step below one notch")
	await _notch(true, 0.3)
	ok(h.steps == n0 + 1, "they step once they add up to one")
	for i in 12:
		await _notch(true, 0.3)
	ok(h.steps == n0 + 1, "the rest of that stroke steps no more (12 more small steps)")
	await _frames(30)
	for i in 4:
		await _notch(true, 0.3)
	ok(h.steps == n0 + 2, "a new stroke after a rest steps again")
	var n1 := h.steps
	for i in 3:
		await _notch(true)
	ok(h.steps == n1 + 3, "a mouse's notches: one step each, quick ones too")
	if p.weapon != "torch":
		await _notch(true)


## The row of `action` on the open Controls page.
func _row_of(sp: SettingsPanel, action: String) -> Rect2:
	for row in sp.controls.rows_in(sp.panel_rect()):
		if str(row[1][0]) == "bind" and str(row[1][1]) == action:
			return row[0]
	return Rect2()


func _row_kind(sp: SettingsPanel, kind: String) -> Rect2:
	for row in sp.controls.rows_in(sp.panel_rect()):
		if str(row[1][0]) == kind:
			return row[0]
	return Rect2()


func _open_controls() -> SettingsPanel:
	var sp := main.settings_panel
	if not sp.visible:
		main._toggle_settings(true)
		await _frames(2)
	if sp.page != "controls":
		await _click((sp.tab_rects(sp.panel_rect())[1][0] as Rect2).get_center())
	return sp


func _page() -> void:
	var on_page := ControlsPage.actions()
	var off: Array = []
	for a in Controls.DEFAULTS:
		if on_page.count(a) != 1 or not Controls.NAMES.has(a):
			off.append(a)
	ok(off.is_empty() and on_page.size() == Controls.DEFAULTS.size(), "every Controls action is on the Controls page once, named (%d)%s" % [on_page.size(), "" if off.is_empty() else ": not " + str(off)])
	var clash: Array = []
	for a in Controls.DEFAULTS:
		if not Controls.clashes(a).is_empty():
			clash.append(a)
	ok(clash.is_empty(), "the defaults clash nowhere (Tab: the crawler's other hand and the open world's inventory, one game each)%s" % ("" if clash.is_empty() else ": " + str(clash)))
	var sp: SettingsPanel = await _open_controls()
	ok(sp.visible and sp.page == "controls", "the Controls tab opens the Controls page")
	var pr := sp.panel_rect()
	var frame := Rect2(Vector2.ZERO, sp.size)
	ok(frame.encloses(pr) and pr.size.x <= 640.0, "the page fits the 480-line frame, and a 4:3 one (%s in %s)" % [str(pr), str(sp.size)])
	# Rebind Jump to J.
	await _click(_row_of(sp, "jump").get_center())
	ok(sp.controls.waiting == "jump", "a click on Jump waits for its new input")
	await _tap(KEY_J)
	var pad_a := false
	for ev in InputMap.action_get_events("jump"):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			pad_a = true
	ok(sp.controls.waiting == "" and _keys("jump") == ["J"] and pad_a, "J pressed: Jump is J now, Space no longer (%s), its pad button kept" % str(_keys("jump")))
	var cf := ConfigFile.new()
	cf.load(Controls.path)
	ok(cf.get_value("bindings", "jump", []) == ["key:J"], "saved in the player's file (%s: %s)" % [Controls.path, str(cf.get_value("bindings", "jump", []))])
	# Esc lets a waiting action go, and doesn't shut the panel.
	await _click(_row_of(sp, "settings").get_center())
	await _tap(KEY_ESCAPE)
	ok(sp.visible and sp.controls.waiting == "" and _keys("settings") == ["O", "F10"], "Esc cancels: Settings keeps O, F10, the panel stays open")
	# The page hears the key before the game: O (Settings) bound to Free
	# the mouse leaves the panel open, and the two then clash.
	await _click(_row_of(sp, "release_mouse").get_center())
	await _tap(KEY_O)
	ok(sp.visible and _keys("release_mouse") == ["O"], "O pressed for Free the mouse is caught by the page (the panel stays open)")
	ok("settings" in Controls.clashes("release_mouse") and "release_mouse" in Controls.clashes("settings"), "a clash in one game is marked: Free the mouse and Settings both on O")
	await _click(_row_of(sp, "release_mouse").get_center())
	await _tap(KEY_ESCAPE)
	ok(_keys("release_mouse") == ["O"] and sp.visible, "(Esc, now free of Free the mouse, still only cancels)")
	# Across the two games no clash: Q as the other hand.
	await _click(_row_of(sp, "other_hand").get_center())
	await _tap(KEY_Q)
	ok(_keys("other_hand") == ["Q"] and Controls.clashes("other_hand").is_empty() and Controls.clashes("weapon_swap").is_empty(), "Q as the other hand: no clash, the open world's Q is the open world's")
	# A key for the wheel's action.
	await _click(_row_of(sp, "hand_next").get_center())
	await _tap(KEY_E)
	ok(_keys("hand_next") == ["E"], "E bound to Next in hand (the wheel down no longer)")
	# The wheel's switch.
	await _click(_row_kind(sp, "wheel").get_center())
	var one := Controls.wheel_drives()
	await _click(_row_kind(sp, "wheel").get_center())
	ok(one == "left" and Controls.wheel_drives() == "right", "the page's wheel line switches the wheel's hand (right → %s → %s)" % [one, Controls.wheel_drives()])
	# In play: E steps the right hand, Q held turns it to the left.
	main._toggle_settings(false)
	await _frames(2)
	var n0 := h.steps
	var w0 := p.weapon
	await _tap(KEY_E)
	ok(h.steps == n0 + 1 and p.weapon != w0, "in play, E steps the right hand (%s → %s)" % [w0, p.weapon])
	var l0 := h.left
	_key(KEY_Q, true)
	await _frames(2)
	await _tap(KEY_E)
	_key(KEY_Q, false)
	await _frames(2)
	ok(h.left != l0, "and with Q held, the left (strip place %d → %d)" % [l0, h.left])
	await _notch(true)
	ok(h.steps == n0 + 2, "the wheel down no longer steps (bound to E instead)")


## The fire pots on the strip (FirePots, prompt 60, through Hands).
func _pots() -> void:
	var fp := main.fire_pots
	await _tap(KEY_F9)
	var pots := fp.pots_carried()
	var oils := {}
	for it in pots:
		oils[str(it.get("oil", ""))] = true
	ok(pots.size() == FirePots.carry_max() and not p.inventory.has_kind("fire_pot") and oils.has("tar") and oils.has("light_oil"), "F9 (dev) fills the strip with %d fire pots of both oils, none in the carry slots" % pots.size())
	h.hold_left({})
	_key(KEY_TAB, true)
	await _frames(2)
	var n0 := h.steps
	var seen: Array = [h.left]
	for i in pots.size() + 1:
		await _notch(true)
		seen.append(h.left)
	ok(seen == [-1, 0, 1, 2, -1] and h.steps == n0 + pots.size() + 1, "Tab+wheel steps once a notch through all %d pots and back to empty (%s)" % [pots.size(), str(seen)])
	var cl: Array = main.hand_strip.layout().cells
	ok(cl.size() == pots.size() + 1 and str((cl[1][1] as Dictionary).get("oil", "")) == str(pots[1].get("oil", "")), "the strip shows each pot as itself (%d cells, its oil drawn on its plug)" % cl.size())
	_key(KEY_TAB, false)
	await _frames(2)
	# Lighting a pot: the left hand holds still.
	_light_at_hearth()
	h.hold_left(pots[0])
	await _frames(2)
	Input.action_press("shoot")
	await _frames(10)
	var lighting := fp.state == "lighting"
	_key(KEY_TAB, true)
	await _frames(2)
	await _notch(true)
	var held := h.left
	_key(KEY_TAB, false)
	Input.action_release("shoot")
	await _frames(3)
	ok(lighting and held == 0 and fp.state == "idle" and not bool(pots[0].get("lit", false)), "while a pot is being lit, Tab+wheel leaves the left hand as it is (let go before the wick caught: nothing lit)")
	h.hold_left({})
	if p.weapon != "torch":
		await _notch(true)


func _restart() -> void:
	Controls.set_wheel_drives("left")
	main.queue_free()
	await _frames(3)
	# A new start: the actions made anew from DEFAULTS, the file read again.
	for a in Controls.DEFAULTS:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
	Controls.reload()
	await _boot()
	ok(_keys("jump") == ["J"] and _keys("other_hand") == ["Q"] and _keys("hand_next") == ["E"] and _keys("release_mouse") == ["O"], "a restart: the saved bindings in force over DEFAULTS (Jump J, Other hand Q, Next in hand E, Free the mouse O)")
	ok(_keys("move_forward") == ["W", "Up"] and _keys("hand_prev") == ["Wheel up"] and _keys("shoot") == ["Left click"], "the actions never changed keep their defaults")
	ok(Controls.wheel_drives() == "left", "the wheel's hand kept (left)")
	await _tap(KEY_F9)
	var l0 := _left_name()
	await _tap(KEY_E)
	ok(_left_name() != l0, "and in force in play: E (the wheel's hand, now the left) steps the left hand (%s → %s)" % [l0, _left_name()])


func _reset() -> void:
	var sp: SettingsPanel = await _open_controls()
	await _click(_row_kind(sp, "reset").get_center())
	ok(sp.controls.armed and _keys("jump") == ["J"], "reset asks once: one click arms it, nothing changed yet")
	await _click(_row_kind(sp, "reset").get_center())
	var off: Array = []
	for a in Controls.DEFAULTS:
		var want: Array = []
		for k in Controls.DEFAULTS[a]:
			want.append(Controls.input_text(Controls.key_event(k)))
		if Controls.MOUSE_BUTTONS.has(a):
			want.append(Controls.input_text(Controls.mouse_event(Controls.MOUSE_BUTTONS[a])))
		var got: Array = []
		for ev in Controls.inputs(a):
			got.append(Controls.input_text(ev))
		want.sort()
		got.sort()
		if want != got:
			off.append("%s %s" % [a, str(got)])
	ok(off.is_empty(), "the second click resets: every action's keys and buttons are DEFAULTS' again%s" % ("" if off.is_empty() else ": " + str(off)))
	ok(Controls.wheel_drives() == "right" and not FileAccess.file_exists(Controls.path), "the wheel back on the right, the player's file gone")
	main._toggle_settings(false)
	await _frames(2)
	var n0 := h.steps
	await _notch(true)
	ok(h.steps == n0 + 1, "the wheel steps a hand again")

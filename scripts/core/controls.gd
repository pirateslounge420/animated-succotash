class_name Controls
## Default input actions, registered at startup. Any action already defined
## in Project Settings > Input Map is left alone, so rebinding there wins
## over DEFAULTS; a binding the player chose on Settings' Controls page
## (design 6 Oct §FB, ControlsPage) is saved per player in
## user://controls.cfg and wins over both (ensure()). Keys are bound by
## where they sit on the keyboard (physical keys), so WASD stays WASD on
## any layout; the page shows each key by this keyboard's label.

const DEFAULTS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	# Jump; in the air by a wall, cliff, trunk or ruin, the wall jump; just
	# as you land, the bounce (Mike, 29 Sept 2026: the tech moved here
	# from the right mouse button).
	"jump": [KEY_SPACE],
	# Crouch; in the air, fast-fall; just as you land from a height, the
	# ninja roll.
	"crouch": [KEY_SHIFT],
	# Sprint is a double-tap of move_forward, held (PlanetPlayer); this
	# action is the gamepad's way in (click the left stick and hold).
	"sprint": [],
	# The right mouse button (MOUSE_BUTTONS; Mike, 29 Sept 2026: instead
	# of E): take things, climb the tree in front of you, and hold to cling
	# to a wall or trunk or to catch and swing on a branch or vine.
	"interact": [],
	# The inventory screen (what you carry and wear); G sets the chosen
	# carried thing down while it's open. Tab by the designer's call
	# (2026-09-28); I stays as a second key. The open world's: the crawler
	# has no inventory screen, and there Tab is other_hand's (§FB).
	"inventory": [KEY_TAB, KEY_I],
	# The log (design 30 Sept §AZ, LogPanel).
	"log": [KEY_ENTER, KEY_KP_ENTER],
	"inventory_drop": [KEY_G],
	"toggle_map": [KEY_M],
	"toggle_hud": [KEY_H],
	# Debug overlay (spec A4): clock, phase, sun and moon.
	"toggle_debug": [KEY_F3],
	"settings": [KEY_O, KEY_F10],
	"release_mouse": [KEY_ESCAPE],
	# First / third person.
	"toggle_view": [KEY_V, KEY_F5],
	# Hold to draw the bow, release to shoot (the left mouse button; see
	# MOUSE_BUTTONS). With the spear in hand: tap to thrust, hold and
	# release to throw. In the crawler, swing what's in the right hand
	# (§CN, §FB).
	"shoot": [],
	# The next tool to hand: the bow, the spear, bare hands (whichever you
	# have). The open world's; in the crawler Q does nothing (hands.json
	# q_swaps: the wheel took its place, §FB).
	"weapon_swap": [KEY_Q],
	# Smother your own torch and keep holding it (design 6 Oct §FC.3,
	# hands.json douse_key; the crawler, Torch.douse).
	"douse": [KEY_F],
	# The two hands (design 6 Oct §FB, data/hands.json; the crawler, Hands):
	# the mouse wheel (MOUSE_BUTTONS) cycles what's in the hand it drives,
	# the right by default (wheel_drives()); hold other_hand (Tab) and the
	# wheel drives the other hand.
	"hand_next": [],
	"hand_prev": [],
	"other_hand": [KEY_TAB],
	# Read a tome you carry (design 3 Oct §DL, TomePanel); R or Esc closes.
	"read_tome": [KEY_R],
	# Dev mode only (data/dev.json): F4 shows collision shapes, F6 the
	# trees' branch graphs, F7 spawns the next Phase 1 rig beside you (Night
	# Riders, Pond Crawler, monkey), F8 makes the nearest wolf pack howl.
	"toggle_collision_view": [KEY_F4],
	"toggle_branch_view": [KEY_F6],
	"dev_spawn": [KEY_F7],
	"dev_howl": [KEY_F8],
	# Dev: one of each carried kind into the pack (to look at the screen);
	# in the crawler, a stand-in for the left hand (§FB, Hands).
	"dev_items": [KEY_F9],
	# Dev: a new world (asked once; design 1 Oct §CB).
	"dev_new_world": [KEY_F12],
	# Dev: the frame-time readout (design §W, PerfReadout).
	"dev_perf": [KEY_F2],
	# F11 cycles the pixel-size presets live (design §BU).
	"dev_pixel": [KEY_F11],
}

## Mouse buttons per action (the wheel's two ways are buttons too).
const MOUSE_BUTTONS := {
	"shoot": MOUSE_BUTTON_LEFT,
	"interact": MOUSE_BUTTON_RIGHT,
	"hand_next": MOUSE_BUTTON_WHEEL_DOWN,
	"hand_prev": MOUSE_BUTTON_WHEEL_UP,
}

## Gamepad: left stick moves, A jumps (and wall-jumps), X interacts (and
## holds on: climb, cling, swing), B crouches (and rolls), Y swaps tools
## (in the crawler, the next thing in hand; hold the left shoulder for the
## left hand, §FB), the left stick held in sprints, the right trigger
## draws and shoots the bow, the right stick clicked switches first/third
## person, Back opens the map, the d-pad's down smothers the torch (the
## crawler).
const PAD_BUTTONS := {
	"weapon_swap": JOY_BUTTON_Y,
	"douse": JOY_BUTTON_DPAD_DOWN,
	"hand_next": JOY_BUTTON_Y,
	"other_hand": JOY_BUTTON_LEFT_SHOULDER,
	"toggle_view": JOY_BUTTON_RIGHT_STICK,
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_X,
	"crouch": JOY_BUTTON_B,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"toggle_map": JOY_BUTTON_BACK,
	"inventory": JOY_BUTTON_START,
}
const PAD_AXES := {
	"shoot": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}

## Each action's name on the Controls page (ControlsPage).
const NAMES := {
	"move_forward": "Forward",
	"move_back": "Back",
	"move_left": "Left",
	"move_right": "Right",
	"jump": "Jump",
	"crouch": "Sneak / crouch",
	"sprint": "Sprint (held)",
	"shoot": "Swing (right hand)",
	"interact": "Interact",
	"hand_next": "Next in hand",
	"hand_prev": "Previous in hand",
	"other_hand": "Other hand (hold)",
	"douse": "Douse the torch",
	"log": "Log",
	"settings": "Settings",
	"release_mouse": "Free the mouse",
	"inventory": "Inventory",
	"inventory_drop": "Set down",
	"toggle_map": "Map",
	"toggle_view": "1st / 3rd person",
	"weapon_swap": "Next tool",
	"read_tome": "Read a tome",
	"toggle_hud": "HUD on / off",
	"toggle_debug": "Debug overlay",
	"dev_perf": "Frame time",
	"dev_pixel": "Pixel size",
	"dev_items": "Dev items",
	"toggle_collision_view": "Collision view",
	"toggle_branch_view": "Branch view",
	"dev_spawn": "Spawn a rig",
	"dev_howl": "Wolves howl",
	"dev_new_world": "New world (dev)",
}

## The actions only one game reads (the rest both read): one input on two
## actions is a clash only where one game reads both (clashes()), so Tab
## can be the crawler's other hand and the open world's inventory at once.
const CRAWLER_ONLY := ["hand_next", "hand_prev", "other_hand", "douse"]
const OPEN_WORLD_ONLY := ["inventory", "inventory_drop", "toggle_map", "toggle_hud", "toggle_debug", "toggle_view", "weapon_swap", "read_tome", "toggle_collision_view", "toggle_branch_view", "dev_spawn", "dev_howl", "dev_new_world"]

## The mouse buttons in the file, and on screen.
const MOUSE_TEXT := {
	MOUSE_BUTTON_LEFT: "left",
	MOUSE_BUTTON_RIGHT: "right",
	MOUSE_BUTTON_MIDDLE: "middle",
	MOUSE_BUTTON_WHEEL_UP: "wheel_up",
	MOUSE_BUTTON_WHEEL_DOWN: "wheel_down",
	MOUSE_BUTTON_WHEEL_LEFT: "wheel_left",
	MOUSE_BUTTON_WHEEL_RIGHT: "wheel_right",
	MOUSE_BUTTON_XBUTTON1: "x1",
	MOUSE_BUTTON_XBUTTON2: "x2",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Left click",
	MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
	MOUSE_BUTTON_WHEEL_LEFT: "Wheel left",
	MOUSE_BUTTON_WHEEL_RIGHT: "Wheel right",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}

## The player's own choices (design §FB: saved per player): [bindings]
## action = ["key:W", "mouse:wheel_down", ...] for each action changed on
## the Controls page (the rest keep their defaults, so a new default
## reaches them), and [hands] wheel_drives. The checks point it elsewhere.
static var path := "user://controls.cfg"
static var _cfg: ConfigFile
## Each physical key's label on this keyboard (input_name()).
static var _labels := {}


static func ensure() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for ev in _default_events(action):
			InputMap.action_add_event(action, ev)
	# The player's saved bindings win (the Controls page, §FB).
	var f := _file()
	if f.has_section("bindings"):
		for action in f.get_section_keys("bindings"):
			if InputMap.has_action(action):
				var evs: Array = []
				var saved = f.get_value("bindings", action, [])
				for s in (saved if saved is Array else []):
					var ev := parse_input(str(s))
					if ev != null:
						evs.append(ev)
				_set_inputs(action, evs)


## Every event an action starts with: its keys, mouse button, pad button
## and pad axis.
static func _default_events(action: String) -> Array:
	var out: Array = []
	for key in DEFAULTS.get(action, []):
		out.append(key_event(key))
	if MOUSE_BUTTONS.has(action):
		out.append(mouse_event(MOUSE_BUTTONS[action]))
	if PAD_BUTTONS.has(action):
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		out.append(jb)
	if PAD_AXES.has(action):
		var ja := InputEventJoypadMotion.new()
		ja.axis = PAD_AXES[action][0]
		ja.axis_value = PAD_AXES[action][1]
		out.append(ja)
	return out


static func key_event(physical: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	return ev


static func mouse_event(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


## The kinds of input the Controls page shows and rebinds: keys and mouse
## buttons (the wheel among them). A pad's stay as they are.
static func is_input(ev) -> bool:
	return ev is InputEventKey or ev is InputEventMouseButton


static func is_wheel(ev: InputEvent) -> bool:
	return ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]


## An action's keys and mouse buttons now.
static func inputs(action: String) -> Array:
	var out: Array = []
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if is_input(ev):
				out.append(ev)
	return out


## The keys and buttons an action starts with: the Project Settings' if it
## has the action there, else DEFAULTS' and MOUSE_BUTTONS'.
static func default_inputs(action: String) -> Array:
	var out: Array = []
	var ps := "input/" + action
	if ProjectSettings.has_setting(ps):
		var d = ProjectSettings.get_setting(ps)
		for ev in (d.get("events", []) if d is Dictionary else []):
			if is_input(ev):
				out.append(ev)
		return out
	for ev in _default_events(action):
		if is_input(ev):
			out.append(ev)
	return out


## Put `evs` in place of the action's keys and buttons (its pad's stay).
static func _set_inputs(action: String, evs: Array) -> void:
	for ev in InputMap.action_get_events(action):
		if is_input(ev):
			InputMap.action_erase_event(action, ev)
	for ev in evs:
		if ev is InputEvent:
			InputMap.action_add_event(action, ev)


## Bind `action` to the one input `ev` pressed (a key, a mouse button, a
## turn of the wheel) in place of its keys and buttons, and save it for
## this player (the Controls page, §FB). Modifiers held are dropped:
## Shift+W binds W.
static func bind(action: String, ev: InputEvent) -> bool:
	var clean := clean_input(ev)
	if clean == null or not InputMap.has_action(action):
		return false
	_set_inputs(action, [clean])
	_file().set_value("bindings", action, [input_text(clean)])
	_save()
	return true


## A key or a button as a binding: the physical key alone, or the button.
static func clean_input(ev: InputEvent) -> InputEvent:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return key_event(code) if code != KEY_NONE else null
	if ev is InputEventMouseButton:
		var b := (ev as InputEventMouseButton).button_index
		return mouse_event(b) if b != MOUSE_BUTTON_NONE else null
	return null


## Back to the defaults (the Controls page's reset): every action's keys
## and buttons as it starts (default_inputs()), the wheel on hands.json's
## hand, and the player's file gone.
static func reset() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			_set_inputs(action, default_inputs(action))
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Read the player's file afresh on the next use (a new start; the checks).
static func reload() -> void:
	_cfg = null


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path) # missing on a first run: every default
	return _cfg


static func _save() -> void:
	var err := _file().save(path)
	if err != OK:
		push_warning("Controls: could not save %s (error %d)" % [path, err])


## Which hand the plain wheel drives, "right" or "left": hands.json
## wheel_drives, or the player's choice on the Controls page (§FB).
static func wheel_drives() -> String:
	var H := Tuning.table("hands")
	var fallback := str(H.get("wheel_drives", "right"))
	var opts: Array = H.get("wheel_drives_options", ["right", "left"])
	var v := str(_file().get_value("hands", "wheel_drives", fallback))
	return v if v in opts else fallback


static func set_wheel_drives(hand: String) -> void:
	_file().set_value("hands", "wheel_drives", hand)
	_save()


## An input as the file keeps it: "key:W", "key:Shift", "mouse:wheel_down".
static func input_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return "key:" + OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		var b := (ev as InputEventMouseButton).button_index
		return "mouse:" + str(MOUSE_TEXT.get(b, str(b)))
	return ""


static func parse_input(s: String) -> InputEvent:
	var p := s.split(":", true, 1)
	if p.size() < 2:
		return null
	match p[0]:
		"key":
			var code := OS.find_keycode_from_string(p[1])
			return key_event(code) if code != KEY_NONE else null
		"mouse":
			for b in MOUSE_TEXT:
				if MOUSE_TEXT[b] == p[1]:
					return mouse_event(b)
			return mouse_event(int(p[1]) as MouseButton) if p[1].is_valid_int() else null
	return null


## An input's name on screen: "W", "Space", "Esc", "Left click", "Wheel
## down". A key shows this keyboard's label for where it sits (a physical
## binding: W's place is Z on a French keyboard).
static func input_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if k.physical_keycode != KEY_NONE:
			code = _label_of(k.physical_keycode)
		var s := OS.get_keycode_string(code)
		return "Esc" if s == "Escape" else s.replace("Kp ", "Num ")
	if ev is InputEventMouseButton:
		var b := (ev as InputEventMouseButton).button_index
		return str(MOUSE_NAMES.get(b, "Mouse %d" % b))
	return "?"


## The key at physical place `physical` on this keyboard's layout (asked
## once a key; a display server without layouts keeps the place's own).
static func _label_of(physical: Key) -> Key:
	if not _labels.has(physical):
		var shown := physical
		if DisplayServer.get_name() != "headless":
			var k := DisplayServer.keyboard_get_keycode_from_physical(physical)
			if k != KEY_NONE:
				shown = k
		_labels[physical] = shown
	return _labels[physical]


## An action's keys and buttons for the page: "W, Up"; "—" with none.
static func label(action: String) -> String:
	var names: Array = []
	for ev in inputs(action):
		names.append(input_name(ev))
	return ", ".join(names) if not names.is_empty() else "—"


## The action's first key or button by name, or `fallback` with none.
static func first_name(action: String, fallback: String) -> String:
	var evs := inputs(action)
	return input_name(evs[0]) if not evs.is_empty() else fallback


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		return (ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode) == (kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Does one game read both actions (CRAWLER_ONLY, OPEN_WORLD_ONLY)?
static func one_game(a: String, b: String) -> bool:
	return not ((a in CRAWLER_ONLY and b in OPEN_WORLD_ONLY) or (a in OPEN_WORLD_ONLY and b in CRAWLER_ONLY))


## The other actions on one of `action`'s keys or buttons that a game
## reads together with it: pressing it would do both (the Controls page
## marks them).
static func clashes(action: String) -> Array:
	var out: Array = []
	var mine := inputs(action)
	for other in DEFAULTS:
		if other == action or not one_game(action, other):
			continue
		var hit := false
		for a in mine:
			for b in inputs(other):
				if same_input(a, b):
					hit = true
		if hit:
			out.append(other)
	return out


## The interact button's name for prompts ("Right click: take the arrow
## back"), as bound (the Controls page).
static func interact_word() -> String:
	return first_name("interact", "Right click")


## The shoot button's name for prompts ("Left click: swing the torch ...";
## §CN), as bound.
static func shoot_word() -> String:
	return first_name("shoot", "Left click")

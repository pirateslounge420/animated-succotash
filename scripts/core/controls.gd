class_name Controls
## Default input actions, registered at startup. Any action already defined
## in Project Settings > Input Map is left alone, so rebinding there wins.

const DEFAULTS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_SHIFT],
	# Sprint is a double-tap of move_forward, held (PlanetPlayer); this
	# action is the gamepad's way in (click the left stick and hold).
	"sprint": [],
	"interact": [KEY_E],
	# The inventory screen (what you carry and wear); G sets the chosen
	# carried thing down while it's open. Tab by the designer's call
	# (2026-09-28); I stays as a second key.
	"inventory": [KEY_TAB, KEY_I],
	"inventory_drop": [KEY_G],
	"toggle_map": [KEY_M],
	"toggle_hud": [KEY_H],
	# Debug overlay (spec A4): clock, phase, sun and moon.
	"toggle_debug": [KEY_F3],
	"release_mouse": [KEY_ESCAPE],
	# First / third person.
	"toggle_view": [KEY_V, KEY_F5],
	# Hold to draw the bow, release to shoot (the left mouse button; see
	# MOUSE_BUTTONS). With the spear in hand: tap to thrust, hold and
	# release to throw.
	"shoot": [],
	# Wall jump: in the air, by a wall, cliff, trunk or ruin (the right
	# mouse button; see MOUSE_BUTTONS).
	"wall_jump": [],
	# Swap between the bow, the spear and the fishing pole.
	"weapon_swap": [KEY_Q],
	# The fishing pole (design §N): the line is reeled in with the mouse
	# wheel (scroll down toward you) and let out with scroll up; see
	# MOUSE_BUTTONS. Godot reports the wheel as button presses.
	"reel_in": [],
	"reel_out": [],
	# Dev mode only (data/dev.json): F4 shows collision shapes, F6 the
	# trees' branch graphs, F7 spawns the next Phase 1 rig beside you (Night
	# Riders, Pond Crawler, monkey), F8 makes the nearest wolf pack howl.
	"toggle_collision_view": [KEY_F4],
	"toggle_branch_view": [KEY_F6],
	"dev_spawn": [KEY_F7],
	"dev_howl": [KEY_F8],
	# Dev: one of each carried kind into the pack (to look at the screen).
	"dev_items": [KEY_F9],
}

## Mouse buttons per action.
const MOUSE_BUTTONS := {
	"shoot": MOUSE_BUTTON_LEFT,
	"wall_jump": MOUSE_BUTTON_RIGHT,
	"reel_in": MOUSE_BUTTON_WHEEL_DOWN,
	"reel_out": MOUSE_BUTTON_WHEEL_UP,
}

## Gamepad: left stick moves, A jumps, X interacts, B crouches, Y swaps
## bow and spear, the left stick held in sprints, the right trigger draws
## and shoots the bow, the right stick clicked switches first/third person,
## Back opens the map, the right shoulder wall-jumps.
const PAD_BUTTONS := {
	"weapon_swap": JOY_BUTTON_Y,
	"toggle_view": JOY_BUTTON_RIGHT_STICK,
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_X,
	"crouch": JOY_BUTTON_B,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"toggle_map": JOY_BUTTON_BACK,
	"wall_jump": JOY_BUTTON_RIGHT_SHOULDER,
	"inventory": JOY_BUTTON_START,
}
const PAD_AXES := {
	"shoot": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}


static func ensure() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in DEFAULTS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if MOUSE_BUTTONS.has(action):
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTONS[action]
			InputMap.action_add_event(action, mb)
		if PAD_BUTTONS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var ja := InputEventJoypadMotion.new()
			ja.axis = PAD_AXES[action][0]
			ja.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, ja)

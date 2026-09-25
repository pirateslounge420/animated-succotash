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
	"toggle_map": [KEY_M],
	"toggle_hud": [KEY_H],
	"release_mouse": [KEY_ESCAPE],
}

## Gamepad: left stick moves, A jumps, X interacts, B crouches, the left
## stick held in sprints, Back opens the map.
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"interact": JOY_BUTTON_X,
	"crouch": JOY_BUTTON_B,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"toggle_map": JOY_BUTTON_BACK,
}
const PAD_AXES := {
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
		if PAD_BUTTONS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var ja := InputEventJoypadMotion.new()
			ja.axis = PAD_AXES[action][0]
			ja.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, ja)

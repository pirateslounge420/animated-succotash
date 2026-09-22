extends Camera3D
## Free-fly debug camera for inspecting generated worlds -- not a
## gameplay camera. Hold the right mouse button to look around; WASD to
## move horizontally relative to the view, Space/Shift for up/down, Ctrl
## to move faster.

@export var move_speed: float = 40.0
@export var boost_multiplier: float = 4.0
@export var look_sensitivity: float = 0.15

var _looking := false
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	_yaw = rotation_degrees.y
	_pitch = rotation_degrees.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -89.0, 89.0)
		rotation_degrees = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		input_dir -= Vector3.UP

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var speed := move_speed
		if Input.is_key_pressed(KEY_CTRL):
			speed *= boost_multiplier
		global_position += input_dir * speed * delta

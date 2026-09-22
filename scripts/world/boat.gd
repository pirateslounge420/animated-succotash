extends CharacterBody3D
## Simple, Minecraft-esque boat physics (DESIGN.md section 3.2).
##
## Not a buoyancy/fluid simulation: the hull is height-locked to the
## river's water surface every physics tick, horizontal motion comes from
## paddle input plus the river's current vector, and bank collision comes
## for free from move_and_slide() against the terrain's collision mesh.

@export var max_paddle_speed: float = 6.0
@export var turn_speed: float = 2.0
@export var response: float = 3.0
@export var current_strength: float = 1.5
@export var hull_offset: float = 0.15


func _physics_process(delta: float) -> void:
	var paddle_input := 0.0
	if Input.is_action_pressed("boat_forward"):
		paddle_input += 1.0
	if Input.is_action_pressed("boat_back"):
		paddle_input -= 1.0

	var turn_input := 0.0
	if Input.is_action_pressed("boat_turn_right"):
		turn_input += 1.0
	if Input.is_action_pressed("boat_turn_left"):
		turn_input -= 1.0

	rotation.y -= turn_input * turn_speed * delta

	var forward := -global_transform.basis.z
	var current := WorldGenConfig.current_direction_at(global_position.x, global_position.z) * current_strength
	var target_velocity := forward * paddle_input * max_paddle_speed + current

	velocity.x = lerpf(velocity.x, target_velocity.x, clampf(response * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_velocity.z, clampf(response * delta, 0.0, 1.0))
	velocity.y = 0.0

	move_and_slide()

	global_position.y = WorldGenConfig.WATER_LEVEL + hull_offset

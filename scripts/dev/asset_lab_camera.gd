class_name ActionDashAssetLabCamera
extends Camera3D

@export var movement_speed: float = 18.0
@export var fast_multiplier: float = 2.5
@export var mouse_sensitivity: float = 0.003

var _looking: bool = false

func _ready() -> void:
	current = true

func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var local_motion := Vector3(input.x, 0.0, input.y)
	if Input.is_key_pressed(KEY_E):
		local_motion.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		local_motion.y -= 1.0
	if local_motion.length_squared() > 1.0:
		local_motion = local_motion.normalized()
	var speed := movement_speed * (fast_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var horizontal_forward := -global_basis.z
	horizontal_forward.y = 0.0
	horizontal_forward = horizontal_forward.normalized()
	var horizontal_right := global_basis.x
	horizontal_right.y = 0.0
	horizontal_right = horizontal_right.normalized()
	global_position += (horizontal_right * local_motion.x + horizontal_forward * -local_motion.z + Vector3.UP * local_motion.y) * speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_looking = button.pressed
	elif event is InputEventMouseMotion and _looking:
		var motion := event as InputEventMouseMotion
		rotation.y -= motion.relative.x * mouse_sensitivity
		rotation.x = clampf(rotation.x - motion.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))

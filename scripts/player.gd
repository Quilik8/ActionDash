class_name ActionDashPlayer
extends CharacterBody3D

@export_category("Movement")
@export var base_speed: float = 11.0
@export var max_speed: float = 20.0
@export var acceleration: float = 34.0
@export var deceleration: float = 7.0
@export_range(0.0, 1.0, 0.05) var momentum_preservation: float = 0.84
@export var gravity: float = 24.0
@export var jump_force: float = 10.5
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4
@export var air_acceleration: float = 11.0
@export var air_deceleration: float = 1.8

@export_category("Shooting")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 20.0
@export var projectile_damage: float = 1.0
@export var fire_interval: float = 0.22
@export var projectile_spawn_height: float = 0.9
@export var aim_height: float = 0.65

var _fire_timer: float = 0.0
var _camera: Camera3D

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_move_with_inertia(delta)
	_handle_jump()
	move_and_slide()

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if Input.is_action_just_pressed("shoot") and _fire_timer <= 0.0:
		if _fire_projectile():
			_fire_timer = fire_interval

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

func _move_with_inertia(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var desired_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if desired_direction.length_squared() > 1.0:
		desired_direction = desired_direction.normalized()

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	if desired_direction.length_squared() > 0.0:
		# Launch quickly to base_speed, then keep accelerating toward max_speed.
		var target_speed: float = base_speed if current_speed < base_speed else max_speed
		var desired_velocity: Vector3 = desired_direction * target_speed
		var response: float = acceleration if is_on_floor() else air_acceleration * air_control

		# Turning against existing momentum is possible, but deliberately takes time.
		if current_speed > 0.01:
			var alignment: float = horizontal_velocity.normalized().dot(desired_direction)
			var turn_resistance: float = 1.0 - (1.0 - alignment) * 0.3 * momentum_preservation
			response *= clampf(turn_resistance, 0.35, 1.0)
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, response * delta)
	else:
		# Releasing movement coasts instead of snapping to a stop.
		var coast_factor: float = lerpf(1.0, 0.22, momentum_preservation)
		var response: float = deceleration * coast_factor if is_on_floor() else air_deceleration * coast_factor
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, response * delta)

	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

func _fire_projectile() -> bool:
	if projectile_scene == null:
		return false
	var aim_position: Vector3 = _get_mouse_world_position()
	if not aim_position.is_finite():
		return false
	var direction: Vector3 = aim_position - global_position - Vector3.UP * projectile_spawn_height
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()

	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * projectile_spawn_height
	projectile.setup(direction, projectile_speed, projectile_damage)
	return true

func _get_mouse_world_position() -> Vector3:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return Vector3.INF

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.001:
		return Vector3.INF

	var distance := (global_position.y + aim_height - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return Vector3.INF
	return ray_origin + ray_direction * distance

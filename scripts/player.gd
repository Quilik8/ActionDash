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

@export_category("Recovery")
@export var fall_limit_y: float = -12.0
@export var respawn_position: Vector3 = Vector3.ZERO

@export_category("Pistol")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 45.0
@export var projectile_damage: float = 1.0
@export var magazine_size: int = 20
@export var reload_time: float = 2.0
@export var fire_cooldown: float = 0.22
@export var projectile_spawn_height: float = 0.9
@export var aim_height: float = 0.65
@export var aim_distance: float = 60.0
@export var vertical_aim_strength: float = 8.0

var _fire_timer: float = 0.0
var _reload_timer: float = 0.0
var current_ammo: int
var _camera: Camera3D

func _ready() -> void:
	add_to_group("player")
	current_ammo = magazine_size

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_move_with_inertia(delta)
	_handle_jump()
	move_and_slide()
	_check_fall_recovery()

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_update_reload(delta)
	if Input.is_action_just_pressed("shoot") and _fire_timer <= 0.0 and not is_reloading():
		if _fire_projectile():
			_fire_timer = fire_cooldown

func _check_fall_recovery() -> void:
	if global_position.y < fall_limit_y:
		global_position = respawn_position
		velocity = Vector3.ZERO

func _update_reload(delta: float) -> void:
	if _reload_timer <= 0.0:
		return
	_reload_timer = maxf(_reload_timer - delta, 0.0)
	if _reload_timer <= 0.0:
		current_ammo = magazine_size

func _start_reload() -> void:
	if _reload_timer > 0.0:
		return
	_reload_timer = reload_time

func is_reloading() -> bool:
	return _reload_timer > 0.0

func get_current_ammo() -> int:
	return current_ammo

func get_magazine_size() -> int:
	return magazine_size

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
	if projectile_scene == null or current_ammo <= 0 or is_reloading():
		return false
	var aim_position: Vector3 = _get_mouse_world_position()
	if not aim_position.is_finite():
		return false
	var direction: Vector3 = aim_position - global_position - Vector3.UP * projectile_spawn_height
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()

	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * projectile_spawn_height
	projectile.setup(direction, projectile_speed, projectile_damage)
	current_ammo -= 1
	if current_ammo <= 0:
		_start_reload()
	return true

func _get_mouse_world_position() -> Vector3:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return Vector3.INF

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	var target_position: Vector3 = Vector3.INF
	if absf(ray_direction.y) >= 0.001:
		var distance := (global_position.y + aim_height - ray_origin.y) / ray_direction.y
		if distance > 0.0:
			target_position = ray_origin + ray_direction * distance

	if not target_position.is_finite():
		target_position = ray_origin + ray_direction * aim_distance

	# Keep horizontal mouse aiming comfortable while allowing cursor height to aim up/down.
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center_y: float = viewport_size.y * 0.5
	var vertical_aim: float = 0.0
	if screen_center_y > 0.0:
		vertical_aim = clampf((screen_center_y - mouse_position.y) / screen_center_y, -1.0, 1.0)
	target_position.y = global_position.y + projectile_spawn_height + vertical_aim * vertical_aim_strength
	return target_position

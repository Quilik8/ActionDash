class_name ActionDashPlayer
extends CharacterBody3D

signal energy_attack_fired(origin: Vector3, direction: Vector3)
signal proximity_attack(position: Vector3, targets_hit: int, damage_multiplier: float)
signal kinetic_wave(position: Vector3, targets_hit: int)
signal kinetic_state_changed(active: bool)
signal landing_attack(position: Vector3, targets_hit: int, damage_multiplier: float)

@export_category("Movement")
@export var base_speed: float = 11.0
@export var max_speed: float = 36.0
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

@export_category("Energy attack")
@export var energy_projectile_scene: PackedScene
@export var energy_damage: float = 4.0
@export var energy_speed: float = 52.0
@export var energy_size: float = 0.48
@export var energy_reload_duration: float = 4.0
@export var energy_lifetime: float = 1.8
@export var aim_height: float = 0.65
@export var aim_distance: float = 60.0

@export_category("Aim debug")
@export var show_aim_marker: bool = true
@export_flags_3d_physics var aim_collision_mask: int = 3

var _energy_reload_remaining: float = 0.0
var _camera: Camera3D
var _kinetic_max_active: bool = false
var _air_time: float = 0.0
var _landing_horizontal_speed: float = 0.0
var _landing_fall_speed: float = 0.0

@onready var _attack_origin: Marker3D = $AttackOrigin
@onready var _aim_marker: MeshInstance3D = $Debug/AimMarker
@onready var _proximity_damage: ActionDashProximityDamage = $Gameplay/ProximityDamage

func _ready() -> void:
	add_to_group("player")
	_aim_marker.visible = show_aim_marker
	_proximity_damage.proximity_hit.connect(_on_proximity_hit)
	_proximity_damage.kinetic_wave_triggered.connect(_on_kinetic_wave)
	_proximity_damage.landing_impact.connect(_on_landing_impact)

func _process(_delta: float) -> void:
	if not show_aim_marker:
		_aim_marker.visible = false
		return
	var aim_position := _get_mouse_world_position()
	_aim_marker.visible = aim_position.is_finite()
	if _aim_marker.visible:
		_aim_marker.global_position = aim_position

func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	_track_airborne_state(delta, was_on_floor)
	_apply_gravity(delta)
	_move_with_inertia(delta)
	_handle_jump()
	move_and_slide()
	_handle_landing(was_on_floor)
	_update_kinetic_state()
	_check_fall_recovery()

	_energy_reload_remaining = maxf(_energy_reload_remaining - delta, 0.0)
	if Input.is_action_just_pressed("shoot") and is_energy_ready():
		_fire_energy_projectile()

func _check_fall_recovery() -> void:
	if global_position.y < fall_limit_y:
		global_position = respawn_position
		velocity = Vector3.ZERO
		_reset_airborne_state()

func is_energy_ready() -> bool:
	return _energy_reload_remaining <= 0.0

func get_energy_reload_remaining() -> float:
	return _energy_reload_remaining

func get_horizontal_speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func get_max_speed() -> float:
	return max_speed

func get_kinetic_damage_multiplier() -> float:
	return _proximity_damage.get_damage_multiplier(get_horizontal_speed(), max_speed)

func is_kinetic_max_active() -> bool:
	return _kinetic_max_active

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
		var target_speed: float = base_speed if current_speed < base_speed else max_speed
		var desired_velocity: Vector3 = desired_direction * target_speed
		var response: float = acceleration if is_on_floor() else air_acceleration * air_control
		if current_speed > 0.01:
			var alignment: float = horizontal_velocity.normalized().dot(desired_direction)
			var turn_resistance: float = 1.0 - (1.0 - alignment) * 0.3 * momentum_preservation
			response *= clampf(turn_resistance, 0.35, 1.0)
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, response * delta)
	else:
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

func _track_airborne_state(delta: float, was_on_floor: bool) -> void:
	if was_on_floor:
		return
	_air_time += delta
	_landing_horizontal_speed = maxf(_landing_horizontal_speed, get_horizontal_speed())
	_landing_fall_speed = maxf(_landing_fall_speed, -velocity.y)

func _handle_landing(was_on_floor: bool) -> void:
	if not was_on_floor and is_on_floor():
		_proximity_damage.try_landing_attack(
			global_position,
			_landing_horizontal_speed,
			_landing_fall_speed,
			_air_time,
			max_speed
		)
		_reset_airborne_state()
	elif is_on_floor():
		_reset_airborne_state()

func _reset_airborne_state() -> void:
	_air_time = 0.0
	_landing_horizontal_speed = 0.0
	_landing_fall_speed = 0.0

func _update_kinetic_state() -> void:
	var active := _proximity_damage.is_kinetic_max(get_horizontal_speed(), max_speed)
	if active == _kinetic_max_active:
		return
	_kinetic_max_active = active
	kinetic_state_changed.emit(active)

func _fire_energy_projectile() -> bool:
	if energy_projectile_scene == null or not is_energy_ready():
		return false
	var aim_position := _get_mouse_world_position()
	if not aim_position.is_finite():
		return false
	return _spawn_energy_projectile_toward(aim_position)

func _spawn_energy_projectile_toward(aim_position: Vector3) -> bool:
	if energy_projectile_scene == null or not is_energy_ready():
		return false
	var origin := _attack_origin.global_position
	var direction := aim_position - origin
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()

	var projectile := energy_projectile_scene.instantiate() as ActionDashProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(direction, energy_speed, energy_damage, energy_size, energy_lifetime)
	_energy_reload_remaining = energy_reload_duration
	energy_attack_fired.emit(origin, direction)
	return true

func _on_proximity_hit(position: Vector3, targets_hit: int, multiplier: float) -> void:
	proximity_attack.emit(position, targets_hit, multiplier)

func _on_kinetic_wave(position: Vector3, targets_hit: int) -> void:
	kinetic_wave.emit(position, targets_hit)

func _on_landing_impact(position: Vector3, targets_hit: int, multiplier: float) -> void:
	landing_attack.emit(position, targets_hit, multiplier)

func _get_mouse_world_position() -> Vector3:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return Vector3.INF

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * aim_distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, aim_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"] as Vector3

	var target_position := Vector3.INF
	if absf(ray_direction.y) >= 0.001:
		var distance := (global_position.y + aim_height - ray_origin.y) / ray_direction.y
		if distance > 0.0:
			target_position = ray_origin + ray_direction * distance
	if not target_position.is_finite():
		target_position = ray_end
	return target_position

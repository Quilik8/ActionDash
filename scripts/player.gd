class_name ActionDashPlayer
extends CharacterBody3D

signal energy_attack_fired(origin: Vector3, direction: Vector3)
signal melee_attack(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float, knockback_force: float)
signal landed(position: Vector3, air_time: float, fall_speed: float)

@export_category("Movement")
@export var initial_speed: float = 18.0
@export var max_speed: float = 36.0
@export var acceleration: float = 34.0
@export var turning_response: float = 12.0
@export var gravity: float = 24.0
@export var jump_force: float = 10.5
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.4
@export var air_acceleration: float = 11.0

@export_category("Recovery")
@export var fall_limit_y: float = -12.0
@export var respawn_position: Vector3 = Vector3.ZERO

@export_category("Ranged attack")
@export var ranged_power_path: NodePath = NodePath("Gameplay/RangedPower")
@export var aim_height: float = 0.65
@export var aim_distance: float = 60.0
@export var minimum_aim_distance: float = 6.0

@export_category("Aim debug")
@export var show_aim_marker: bool = true
@export_flags_3d_physics var aim_collision_mask: int = 3

var _camera: Camera3D
var _air_time: float = 0.0
var _landing_fall_speed: float = 0.0
var _base_run_stats: Dictionary = {}
var _last_move_direction: Vector3 = Vector3.FORWARD

@onready var _attack_origin: Marker3D = $AttackOrigin
@onready var _aim_marker: MeshInstance3D = $Debug/AimMarker
@onready var _proximity_damage: ActionDashProximityDamage = $Gameplay/ProximityDamage
@onready var _ranged_power: ActionDashRangedPower = get_node(ranged_power_path) as ActionDashRangedPower

func _ready() -> void:
	add_to_group("player")
	_aim_marker.visible = show_aim_marker
	_proximity_damage.melee_hit.connect(_on_melee_hit)
	_capture_base_run_stats()

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
	_check_fall_recovery()

	if Input.is_action_just_pressed("melee_attack"):
		_proximity_damage.try_melee_attack(self, get_melee_attack_direction())
	if Input.is_action_just_pressed("ranged_attack"):
		_fire_energy_projectile()

func _check_fall_recovery() -> void:
	if global_position.y < fall_limit_y:
		global_position = respawn_position
		velocity = Vector3.ZERO
		_reset_airborne_state()
		reset_physics_interpolation()

func is_energy_ready() -> bool:
	return is_instance_valid(_ranged_power) and _ranged_power.is_ready()

func get_energy_reload_remaining() -> float:
	return _ranged_power.get_cooldown_remaining() if is_instance_valid(_ranged_power) else 0.0

func get_horizontal_speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func get_initial_speed() -> float:
	return initial_speed

func get_speed_progress() -> float:
	var speed_range := maxf(max_speed - initial_speed, 0.001)
	return clampf((get_horizontal_speed() - initial_speed) / speed_range, 0.0, 1.0)

func get_melee_radius_multiplier() -> float:
	return _proximity_damage.get_radius_multiplier(get_horizontal_speed(), max_speed)

func get_effective_melee_radius() -> float:
	return _proximity_damage.get_effective_radius(get_horizontal_speed(), max_speed)

func get_visual_melee_radius() -> float:
	return _proximity_damage.get_visual_radius(get_horizontal_speed(), max_speed)

func get_melee_damage_multiplier() -> float:
	return _proximity_damage.get_damage_multiplier(get_horizontal_speed(), max_speed)

func get_current_melee_knockback_force() -> float:
	return _proximity_damage.get_knockback_force(get_horizontal_speed(), initial_speed, max_speed)

func get_melee_attack_direction() -> Vector3:
	if get_horizontal_speed() > 0.5:
		return Vector3(velocity.x, 0.0, velocity.z).normalized()
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_camera):
		var camera_forward := -_camera.global_basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.01:
			return camera_forward.normalized()
	return _last_move_direction

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

func _move_with_inertia(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var desired_direction := _get_camera_relative_direction(input_vector)
	if desired_direction.length_squared() > 1.0:
		desired_direction = desired_direction.normalized()
	if desired_direction.length_squared() > 0.01:
		_last_move_direction = desired_direction

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	if desired_direction.length_squared() > 0.0:
		if current_speed < initial_speed:
			horizontal_velocity = desired_direction * initial_speed
			current_speed = initial_speed
		var turn_blend := 1.0 - exp(-turning_response * delta)
		var redirected_velocity := desired_direction * current_speed
		horizontal_velocity = horizontal_velocity.lerp(redirected_velocity, turn_blend)
		var desired_velocity := desired_direction * max_speed
		var response := acceleration if is_on_floor() else air_acceleration * air_control
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, response * delta)
	else:
		horizontal_velocity = Vector3.ZERO

	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _get_camera_relative_direction(input_vector: Vector2) -> Vector3:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y)
	var camera_forward := -_camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := _camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	return camera_right * input_vector.x + camera_forward * -input_vector.y

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

func _track_airborne_state(delta: float, was_on_floor: bool) -> void:
	if was_on_floor:
		return
	_air_time += delta
	_landing_fall_speed = maxf(_landing_fall_speed, -velocity.y)

func _handle_landing(was_on_floor: bool) -> void:
	if not was_on_floor and is_on_floor():
		landed.emit(global_position, _air_time, _landing_fall_speed)
		_reset_airborne_state()
	elif is_on_floor():
		_reset_airborne_state()

func _reset_airborne_state() -> void:
	_air_time = 0.0
	_landing_fall_speed = 0.0

func _fire_energy_projectile() -> bool:
	if not is_energy_ready():
		return false
	var aim_position := _get_mouse_world_position()
	if not aim_position.is_finite():
		return false
	return _spawn_energy_projectile_toward(aim_position)

func _spawn_energy_projectile_toward(aim_position: Vector3) -> bool:
	if not is_energy_ready():
		return false
	var origin := _attack_origin.global_position
	var world := get_tree().current_scene
	if world == null:
		world = get_parent()
	return _ranged_power.activate(world, origin, aim_position)

func set_ranged_power(power: ActionDashRangedPower) -> void:
	if power == null:
		return
	if is_instance_valid(_ranged_power):
		if _ranged_power.activated.is_connected(_on_ranged_power_activated):
			_ranged_power.activated.disconnect(_on_ranged_power_activated)
		_ranged_power.queue_free()
	$Gameplay.add_child(power)
	_ranged_power = power
	_ranged_power.activated.connect(_on_ranged_power_activated)

func apply_ranged_power_modifiers(modifiers: Dictionary) -> void:
	if is_instance_valid(_ranged_power):
		_ranged_power.apply_runtime_modifiers(modifiers)

func apply_run_stat_modifier(stat_id: StringName, operation: String, value: float) -> void:
	match stat_id:
		&"max_speed":
			max_speed = _modified_value(max_speed, operation, value)
		&"acceleration":
			acceleration = _modified_value(acceleration, operation, value)
		&"jump_force":
			jump_force = _modified_value(jump_force, operation, value)
		&"melee_damage":
			_proximity_damage.base_damage = _modified_value(_proximity_damage.base_damage, operation, value)
		&"melee_radius":
			_proximity_damage.damage_radius = _modified_value(_proximity_damage.damage_radius, operation, value)
		&"melee_knockback":
			_proximity_damage.maximum_speed_knockback_bonus = _modified_value(_proximity_damage.maximum_speed_knockback_bonus, operation, value)
		&"ranged_damage":
			_ranged_power.damage = _modified_value(_ranged_power.damage, operation, value)
		&"ranged_cooldown":
			_ranged_power.cooldown = maxf(_modified_value(_ranged_power.cooldown, operation, value), 0.2)
		&"ranged_speed":
			if _ranged_power is ActionDashEnergySpherePower:
				var energy_power := _ranged_power as ActionDashEnergySpherePower
				energy_power.projectile_speed = _modified_value(energy_power.projectile_speed, operation, value)
		&"ranged_size":
			if _ranged_power is ActionDashEnergySpherePower:
				var energy_power := _ranged_power as ActionDashEnergySpherePower
				energy_power.projectile_size = maxf(_modified_value(energy_power.projectile_size, operation, value), 0.05)

func get_run_stat(stat_id: StringName) -> float:
	match stat_id:
		&"max_speed": return max_speed
		&"acceleration": return acceleration
		&"jump_force": return jump_force
		&"melee_damage": return _proximity_damage.base_damage
		&"melee_radius": return _proximity_damage.damage_radius
		&"melee_knockback": return _proximity_damage.maximum_speed_knockback_bonus
		&"ranged_damage": return _ranged_power.damage
		&"ranged_cooldown": return _ranged_power.cooldown
		&"ranged_speed": return (_ranged_power as ActionDashEnergySpherePower).projectile_speed if _ranged_power is ActionDashEnergySpherePower else 0.0
		&"ranged_size": return (_ranged_power as ActionDashEnergySpherePower).projectile_size if _ranged_power is ActionDashEnergySpherePower else 0.0
	return 0.0

func restore_base_run_stats() -> void:
	for stat_id in _base_run_stats:
		_set_run_stat(stat_id, _base_run_stats[stat_id])

func _capture_base_run_stats() -> void:
	for stat_id in [&"max_speed", &"acceleration", &"jump_force", &"melee_damage", &"melee_radius", &"melee_knockback", &"ranged_damage", &"ranged_cooldown", &"ranged_speed", &"ranged_size"]:
		_base_run_stats[stat_id] = get_run_stat(stat_id)

func _set_run_stat(stat_id: StringName, value: float) -> void:
	var current := get_run_stat(stat_id)
	apply_run_stat_modifier(stat_id, "Add", value - current)

func _modified_value(current: float, operation: String, value: float) -> float:
	return current * value if operation == "Multiply" else current + value

func _on_ranged_power_activated(origin: Vector3, direction: Vector3) -> void:
	energy_attack_fired.emit(origin, direction)

func _on_melee_hit(world_position: Vector3, targets_hit: int, multiplier: float, effective_radius: float, knockback_force: float) -> void:
	melee_attack.emit(world_position, targets_hit, multiplier, effective_radius, knockback_force)

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
	var target_position := Vector3.INF
	if not hit.is_empty():
		target_position = hit["position"] as Vector3

	if not target_position.is_finite() and absf(ray_direction.y) >= 0.001:
		var distance := (global_position.y + aim_height - ray_origin.y) / ray_direction.y
		if distance > 0.0:
			target_position = ray_origin + ray_direction * distance
	if not target_position.is_finite():
		target_position = ray_end

	# Very close camera hits create severe third-person parallax and can send the
	# sphere sideways or behind the character. Keep the same screen ray, but use
	# a point safely beyond the launch origin in those cases.
	var launch_origin := _attack_origin.global_position if is_instance_valid(_attack_origin) else global_position + Vector3.UP * aim_height
	if launch_origin.distance_to(target_position) < minimum_aim_distance:
		var launch_depth := maxf((launch_origin - ray_origin).dot(ray_direction), 0.0)
		target_position = ray_origin + ray_direction * (launch_depth + minimum_aim_distance)
	return target_position

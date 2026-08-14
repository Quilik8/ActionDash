class_name ActionDashProximityDamage
extends Node

signal proximity_hit(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float)
signal kinetic_wave_triggered(position: Vector3, targets_hit: int)
signal landing_impact(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float)

@export_category("Kinetic proximity damage")
@export var damage_radius: float = 6.3
@export var maximum_radius_multiplier: float = 1.5
@export_range(0.25, 3.0, 0.05) var radius_scaling_exponent: float = 1.15
@export_range(1.0, 1.5, 0.01) var contact_radius_multiplier: float = 1.1
@export var base_damage: float = 1.0
@export var scaling_start_speed: float = 8.0
@export var maximum_damage_multiplier: float = 3.0
@export_range(0.25, 3.0, 0.05) var scaling_exponent: float = 1.35
@export var damage_interval: float = 0.35

@export_category("Maximum kinetic state")
@export_range(0.5, 1.0, 0.01) var kinetic_max_threshold: float = 0.9
@export var kinetic_max_impact_multiplier: float = 2.0
@export var kinetic_wave_radius: float = 5.0
@export var kinetic_wave_damage: float = 1.5
@export var kinetic_wave_cooldown: float = 1.25

@export_category("Landing attack")
@export var landing_melee_multiplier: float = 1.5
@export var landing_damage: float = 1.4
@export var landing_minimum_air_time: float = 0.25
@export var landing_minimum_fall_speed: float = 2.0
@export var landing_cooldown: float = 0.6
@export_range(1.0, 2.0, 0.05) var landing_speed_bonus_limit: float = 1.3

var _damage_timer: float = 0.0
var _wave_timer: float = 0.0
var _landing_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_damage_timer = maxf(_damage_timer - delta, 0.0)
	_wave_timer = maxf(_wave_timer - delta, 0.0)
	_landing_timer = maxf(_landing_timer - delta, 0.0)
	if _damage_timer > 0.0:
		return
	_damage_timer = damage_interval

	var player := get_parent().get_parent() as ActionDashPlayer
	if player == null:
		return
	var speed := player.get_horizontal_speed()
	var configured_max_speed := player.max_speed
	var multiplier := get_damage_multiplier(speed, configured_max_speed)
	var maximum_state := is_kinetic_max(speed, configured_max_speed)
	var direct_multiplier := multiplier * (kinetic_max_impact_multiplier if maximum_state else 1.0)
	var effective_radius := get_effective_radius(speed, configured_max_speed)
	var targets := _get_melee_targets(player.global_position, effective_radius, not player.is_on_floor())
	if targets.is_empty():
		return
	for enemy in targets:
		enemy.apply_damage(base_damage * direct_multiplier, &"melee")
	proximity_hit.emit(player.global_position, targets.size(), direct_multiplier, effective_radius)

	if maximum_state and _wave_timer <= 0.0:
		_wave_timer = kinetic_wave_cooldown
		var wave_targets := _get_melee_targets(player.global_position, kinetic_wave_radius, not player.is_on_floor())
		for enemy in wave_targets:
			enemy.apply_damage(kinetic_wave_damage, &"wave")
		kinetic_wave_triggered.emit(player.global_position, wave_targets.size())

func get_speed_progress(horizontal_speed: float, configured_max_speed: float) -> float:
	var scaling_range := maxf(configured_max_speed - scaling_start_speed, 0.001)
	return clampf((horizontal_speed - scaling_start_speed) / scaling_range, 0.0, 1.0)

func get_damage_multiplier(horizontal_speed: float, configured_max_speed: float) -> float:
	var curved_progress := pow(get_speed_progress(horizontal_speed, configured_max_speed), scaling_exponent)
	return lerpf(1.0, maximum_damage_multiplier, curved_progress)

func get_radius_multiplier(horizontal_speed: float, configured_max_speed: float) -> float:
	var curved_progress := pow(get_speed_progress(horizontal_speed, configured_max_speed), radius_scaling_exponent)
	return lerpf(1.0, maximum_radius_multiplier, curved_progress)

func get_effective_radius(horizontal_speed: float, configured_max_speed: float) -> float:
	return get_visual_radius(horizontal_speed, configured_max_speed) * contact_radius_multiplier

func get_visual_radius(horizontal_speed: float, configured_max_speed: float) -> float:
	return damage_radius * get_radius_multiplier(horizontal_speed, configured_max_speed)

func get_landing_radius(horizontal_speed: float, configured_max_speed: float) -> float:
	var effective_melee_radius := get_effective_radius(horizontal_speed, configured_max_speed)
	return effective_melee_radius * landing_melee_multiplier

func is_kinetic_max(horizontal_speed: float, configured_max_speed: float) -> bool:
	return horizontal_speed >= configured_max_speed * kinetic_max_threshold

func try_landing_attack(
	world_position: Vector3,
	horizontal_speed: float,
	fall_speed: float,
	air_time: float,
	configured_max_speed: float
) -> bool:
	if _landing_timer > 0.0:
		return false
	if air_time < landing_minimum_air_time or fall_speed < landing_minimum_fall_speed:
		return false
	var effective_radius := get_landing_radius(horizontal_speed, configured_max_speed)
	var targets := _get_melee_targets(world_position, effective_radius, false)
	if targets.is_empty():
		return false

	var speed_ratio := clampf(horizontal_speed / maxf(configured_max_speed, 0.001), 0.0, 1.0)
	var multiplier := lerpf(1.0, landing_speed_bonus_limit, speed_ratio)
	for enemy in targets:
		enemy.apply_damage(landing_damage * multiplier, &"landing")
	_landing_timer = landing_cooldown
	landing_impact.emit(world_position, targets.size(), multiplier, effective_radius)
	return true

func _get_melee_targets(world_position: Vector3, radius: float, allow_flying: bool) -> Array[Node]:
	var result: Array[Node] = []
	var radius_squared := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var is_flying := enemy.is_in_group("flying_enemies")
		if is_flying and not allow_flying:
			continue
		var offset: Vector3 = enemy.get_projectile_hit_position() - world_position
		if is_flying:
			if offset.y > 0.0 and Vector2(offset.x, offset.z).length_squared() <= radius_squared:
				result.append(enemy)
		elif offset.length_squared() <= radius_squared:
			result.append(enemy)
	return result

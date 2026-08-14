class_name ActionDashProximityDamage
extends Node

signal melee_hit(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float, knockback_force: float)
signal landing_impact(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float)

@export_category("Manual melee")
@export var damage_radius: float = 5.2
@export var base_damage: float = 1.0
@export var melee_cooldown: float = 0.28
@export_range(-1.0, 1.0, 0.05) var front_dot_threshold: float = -0.15
@export var close_assist_radius: float = 2.2
@export var maximum_vertical_reach: float = 4.5
@export_range(1, 8, 1) var maximum_targets: int = 1

@export_category("Melee damage scaling")
@export var scaling_start_speed: float = 18.0
@export var maximum_damage_multiplier: float = 2.0
@export_range(0.25, 3.0, 0.05) var scaling_exponent: float = 1.25

@export_category("Melee knockback")
@export var base_knockback_force: float = 8.0
@export var maximum_speed_knockback_bonus: float = 20.0
@export_range(0.25, 3.0, 0.05) var knockback_speed_exponent: float = 1.2
@export var knockback_duration: float = 0.52
@export var knockback_vertical_boost: float = 3.2

@export_category("Landing attack")
@export var landing_radius: float = 5.0
@export var landing_damage: float = 1.4
@export var landing_knockback_force: float = 9.0
@export var landing_knockback_duration: float = 0.42
@export var landing_vertical_boost: float = 2.2
@export var landing_minimum_air_time: float = 0.25
@export var landing_minimum_fall_speed: float = 2.0
@export var landing_cooldown: float = 0.6

var _melee_timer: float = 0.0
var _landing_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	_landing_timer = maxf(_landing_timer - delta, 0.0)

func try_melee_attack(player: ActionDashPlayer, attack_direction: Vector3) -> bool:
	if player == null or _melee_timer > 0.0:
		return false
	var flat_direction := Vector3(attack_direction.x, 0.0, attack_direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	var targets := _select_melee_targets(player.global_position, flat_direction)
	if targets.is_empty():
		return false
	var speed := player.get_horizontal_speed()
	var damage_multiplier := get_damage_multiplier(speed, player.max_speed)
	var knockback_force := get_knockback_force(speed, player.normal_speed, player.max_speed)
	for enemy in targets:
		var enemy_position: Vector3 = enemy.get_projectile_hit_position()
		var radial := enemy_position - player.global_position
		radial.y = 0.0
		var knockback_direction := (flat_direction * 0.68 + radial.normalized() * 0.32).normalized()
		enemy.apply_damage(base_damage * damage_multiplier, &"melee")
		_apply_knockback(enemy, knockback_direction, knockback_force, knockback_duration, knockback_vertical_boost)
	_melee_timer = melee_cooldown
	melee_hit.emit(player.global_position, targets.size(), damage_multiplier, damage_radius, knockback_force)
	return true

func get_speed_progress(horizontal_speed: float, configured_max_speed: float) -> float:
	var scaling_range := maxf(configured_max_speed - scaling_start_speed, 0.001)
	return clampf((horizontal_speed - scaling_start_speed) / scaling_range, 0.0, 1.0)

func get_damage_multiplier(horizontal_speed: float, configured_max_speed: float) -> float:
	var curved_progress := pow(get_speed_progress(horizontal_speed, configured_max_speed), scaling_exponent)
	return lerpf(1.0, maximum_damage_multiplier, curved_progress)

func get_knockback_force(horizontal_speed: float, normal_speed: float, configured_max_speed: float) -> float:
	var speed_range := maxf(configured_max_speed - normal_speed, 0.001)
	var progress := clampf((horizontal_speed - normal_speed) / speed_range, 0.0, 1.0)
	return base_knockback_force + pow(progress, knockback_speed_exponent) * maximum_speed_knockback_bonus

func get_effective_radius(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return damage_radius

func get_visual_radius(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return damage_radius

func get_radius_multiplier(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return 1.0

func get_landing_radius(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return landing_radius

func is_kinetic_max(horizontal_speed: float, configured_max_speed: float) -> bool:
	return horizontal_speed >= configured_max_speed * 0.9

func try_landing_attack(
	world_position: Vector3,
	_horizontal_speed: float,
	fall_speed: float,
	air_time: float,
	_configured_max_speed: float
) -> bool:
	if _landing_timer > 0.0:
		return false
	if air_time < landing_minimum_air_time or fall_speed < landing_minimum_fall_speed:
		return false
	var targets := _get_landing_targets(world_position)
	if targets.is_empty():
		return false
	for enemy in targets:
		var direction: Vector3 = enemy.get_projectile_hit_position() - world_position
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			direction = Vector3.FORWARD
		enemy.apply_damage(landing_damage, &"landing")
		_apply_knockback(enemy, direction.normalized(), landing_knockback_force, landing_knockback_duration, landing_vertical_boost)
	_landing_timer = landing_cooldown
	landing_impact.emit(world_position, targets.size(), 1.0, landing_radius)
	return true

func _select_melee_targets(world_position: Vector3, attack_direction: Vector3) -> Array[Node]:
	var scored_targets: Array[Dictionary] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("apply_damage"):
			continue
		var offset: Vector3 = enemy.get_projectile_hit_position() - world_position
		var vertical_distance := absf(offset.y)
		offset.y = 0.0
		var distance := offset.length()
		if distance > damage_radius or vertical_distance > maximum_vertical_reach:
			continue
		var direction_to_enemy := offset.normalized() if distance > 0.01 else attack_direction
		var alignment := attack_direction.dot(direction_to_enemy)
		if alignment < front_dot_threshold and distance > close_assist_radius:
			continue
		scored_targets.append({"enemy": enemy, "score": distance - alignment * 2.0})
	scored_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	var result: Array[Node] = []
	for index in mini(maximum_targets, scored_targets.size()):
		result.append(scored_targets[index]["enemy"] as Node)
	return result

func _get_landing_targets(world_position: Vector3) -> Array[Node]:
	var result: Array[Node] = []
	var radius_squared := landing_radius * landing_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_in_group("flying_enemies") or not enemy.has_method("apply_damage"):
			continue
		var offset: Vector3 = enemy.get_projectile_hit_position() - world_position
		if offset.length_squared() <= radius_squared:
			result.append(enemy)
	return result

func _apply_knockback(enemy: Node, direction: Vector3, force: float, duration: float, vertical_boost: float) -> void:
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction, force, duration, vertical_boost)

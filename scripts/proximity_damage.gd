class_name ActionDashProximityDamage
extends Node

signal melee_hit(position: Vector3, targets_hit: int, damage_multiplier: float, effective_radius: float, knockback_force: float)

@export_category("Manual melee")
@export var damage_radius: float = 5.2
@export var base_damage: float = 1.0
@export var melee_cooldown: float = 0.28
@export_range(-1.0, 1.0, 0.05) var front_dot_threshold: float = -0.15
@export var close_assist_radius: float = 2.2
@export var ground_vertical_reach: float = 2.0
@export var aerial_horizontal_reach: float = 7.2
@export var aerial_vertical_reach: float = 6.5
@export_range(-1.0, 1.0, 0.05) var aerial_front_dot_threshold: float = -0.45
@export var aerial_close_assist_radius: float = 3.0
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

@export_category("Melee lethal knockback")
@export var lethal_knockback_force: float = 30.0
@export var lethal_speed_knockback_bonus: float = 45.0
@export_range(0.25, 3.0, 0.05) var lethal_knockback_speed_exponent: float = 1.1
@export var lethal_knockback_duration: float = 0.75
@export var lethal_knockback_vertical_boost: float = 6.0

var _melee_timer: float = 0.0

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	if _melee_timer <= 0.0:
		set_physics_process(false)

func try_melee_attack(player: ActionDashPlayer, attack_direction: Vector3) -> bool:
	if player == null or _melee_timer > 0.0:
		return false
	var flat_direction := Vector3(attack_direction.x, 0.0, attack_direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	var airborne := not player.is_on_floor()
	var targets := _select_melee_targets(player.global_position, flat_direction, airborne)
	var speed := player.get_horizontal_speed()
	var damage_multiplier := get_damage_multiplier(speed, player.max_speed)
	var knockback_force := get_knockback_force(speed, player.initial_speed, player.max_speed)
	for enemy in targets:
		var enemy_position: Vector3 = enemy.get_projectile_hit_position()
		var radial := enemy_position - player.global_position
		radial.y = 0.0
		var knockback_direction := (flat_direction * 0.68 + radial.normalized() * 0.32).normalized()
		enemy.apply_damage(base_damage * damage_multiplier, &"melee")
		if _is_defeated(enemy):
			_apply_knockback(
				enemy,
				knockback_direction,
				get_lethal_knockback_force(speed, player.initial_speed, player.max_speed),
				lethal_knockback_duration,
				lethal_knockback_vertical_boost,
				true
			)
		else:
			_apply_knockback(enemy, knockback_direction, knockback_force, knockback_duration, knockback_vertical_boost)
	_melee_timer = melee_cooldown
	set_physics_process(_melee_timer > 0.0)
	melee_hit.emit(player.global_position, targets.size(), damage_multiplier, damage_radius, knockback_force)
	return true

func get_speed_progress(horizontal_speed: float, configured_max_speed: float) -> float:
	var scaling_range := maxf(configured_max_speed - scaling_start_speed, 0.001)
	return clampf((horizontal_speed - scaling_start_speed) / scaling_range, 0.0, 1.0)

func get_damage_multiplier(horizontal_speed: float, configured_max_speed: float) -> float:
	var curved_progress := pow(get_speed_progress(horizontal_speed, configured_max_speed), scaling_exponent)
	return lerpf(1.0, maximum_damage_multiplier, curved_progress)

func get_knockback_force(horizontal_speed: float, initial_speed: float, configured_max_speed: float) -> float:
	var speed_range := maxf(configured_max_speed - initial_speed, 0.001)
	var progress := clampf((horizontal_speed - initial_speed) / speed_range, 0.0, 1.0)
	return base_knockback_force + pow(progress, knockback_speed_exponent) * maximum_speed_knockback_bonus

func get_lethal_knockback_force(horizontal_speed: float, initial_speed: float, configured_max_speed: float) -> float:
	var speed_range := maxf(configured_max_speed - initial_speed, 0.001)
	var progress := clampf((horizontal_speed - initial_speed) / speed_range, 0.0, 1.0)
	return lethal_knockback_force + pow(progress, lethal_knockback_speed_exponent) * lethal_speed_knockback_bonus

func get_effective_radius(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return damage_radius

func get_visual_radius(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return damage_radius

func get_radius_multiplier(_horizontal_speed: float, _configured_max_speed: float) -> float:
	return 1.0

func _select_melee_targets(world_position: Vector3, attack_direction: Vector3, airborne: bool) -> Array[Node]:
	var scored_targets: Array[Dictionary] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("apply_damage"):
			continue
		var offset: Vector3 = enemy.get_projectile_hit_position() - world_position
		var vertical_distance := absf(offset.y)
		offset.y = 0.0
		var distance := offset.length()
		var horizontal_limit := aerial_horizontal_reach if airborne else damage_radius
		var vertical_limit := aerial_vertical_reach if airborne else ground_vertical_reach
		if distance > horizontal_limit or vertical_distance > vertical_limit:
			continue
		var direction_to_enemy := offset.normalized() if distance > 0.01 else attack_direction
		var alignment := attack_direction.dot(direction_to_enemy)
		var alignment_limit := aerial_front_dot_threshold if airborne else front_dot_threshold
		var assist_distance := aerial_close_assist_radius if airborne else close_assist_radius
		if alignment < alignment_limit and distance > assist_distance:
			continue
		var score := distance + vertical_distance * 0.6 - alignment * 2.4
		# Airborne attacks give flying targets the same fair volume, while the
		# score still prefers the closest target in front of the player.
		scored_targets.append({"enemy": enemy, "score": score})
	scored_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	var result: Array[Node] = []
	for index in mini(maximum_targets, scored_targets.size()):
		result.append(scored_targets[index]["enemy"] as Node)
	return result

func _apply_knockback(enemy: Node, direction: Vector3, force: float, duration: float, vertical_boost: float, lethal: bool = false) -> void:
	if lethal and enemy.has_method("apply_lethal_knockback"):
		enemy.apply_lethal_knockback(direction, force, duration, vertical_boost)
	elif enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction, force, duration, vertical_boost)

func _is_defeated(enemy: Node) -> bool:
	if enemy.has_method("is_defeated"):
		return enemy.is_defeated()
	var health = enemy.get("current_health")
	return health != null and float(health) <= 0.0

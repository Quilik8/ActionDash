class_name ActionDashProjectile
extends Node3D

signal enemy_hit(position: Vector3, damage: float)

var _direction := Vector3.FORWARD
var _speed: float = 52.0
var _damage: float = 4.0
var _hit_radius: float = 0.55
var _remaining_lifetime: float = 1.8
var _hit_enemy_ids: Dictionary = {}
var _current_target: Node
var _chain_targets_hit: int = 0
var _maximum_chain_targets: int = 3
var _chain_search_radius: float = 12.0
var _homing_turn_rate: float = 9.0
var _debug_chain_targeting: bool = false

@export_category("Projectile hit reaction")
@export var nonlethal_knockback_force: float = 3.5
@export var nonlethal_knockback_duration: float = 0.24
@export var nonlethal_knockback_vertical_boost: float = 0.5
@export var lethal_knockback_force: float = 24.0
@export var lethal_knockback_duration: float = 0.72
@export var lethal_knockback_vertical_boost: float = 4.0

@onready var _presentation: ActionDashEnergyProjectileVisual = $Presentation

func setup(direction: Vector3, speed: float, damage: float, visual_radius: float, contact_margin: float, lifetime: float) -> void:
	setup_guided(direction, speed, damage, visual_radius, contact_margin, lifetime, null, 1, 0.0, 0.0, false)

func setup_guided(
	direction: Vector3,
	speed: float,
	damage: float,
	visual_radius: float,
	contact_margin: float,
	lifetime: float,
	initial_target: Node,
	maximum_chain_targets: int,
	chain_search_radius: float,
	homing_turn_rate: float,
	debug_chain_targeting: bool
) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_hit_radius = maxf(visual_radius + contact_margin, 0.05)
	_remaining_lifetime = lifetime
	_current_target = initial_target
	_maximum_chain_targets = clampi(maximum_chain_targets, 1, 3)
	_chain_search_radius = maxf(chain_search_radius, 0.0)
	_homing_turn_rate = maxf(homing_turn_rate, 0.0)
	_debug_chain_targeting = debug_chain_targeting
	look_at(global_position + _direction, Vector3.UP)
	if is_node_ready():
		_presentation.configure_size(visual_radius)

func _ready() -> void:
	_presentation.play_launch()

func _process(delta: float) -> void:
	var previous_position := global_position
	_update_guidance(delta)
	var next_position := previous_position + _direction * _speed * delta
	global_position = next_position
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()
		return

	_try_hit_current_target(previous_position, next_position)

func _update_guidance(delta: float) -> void:
	if not is_instance_valid(_current_target) or (_current_target.has_method("is_defeated") and _current_target.is_defeated()):
		_current_target = null
		return
	var target_position: Vector3 = _current_target.get_projectile_hit_position()
	var target_direction := global_position.direction_to(target_position)
	if target_direction.length_squared() < 0.0001:
		return
	var blend := 1.0 - exp(-_homing_turn_rate * delta)
	_direction = _direction.lerp(target_direction, blend).normalized()
	look_at(global_position + _direction, Vector3.UP)

func _try_hit_current_target(previous_position: Vector3, next_position: Vector3) -> void:
	if not is_instance_valid(_current_target):
		_remaining_lifetime = minf(_remaining_lifetime, 0.08)
		return
	var enemy := _current_target
	var enemy_id := enemy.get_instance_id()
	if _hit_enemy_ids.has(enemy_id):
		_select_next_target(enemy.get_projectile_hit_position())
		return
	var hit_zone: StringName = &"none"
	if enemy.has_method("get_projectile_hit_zone"):
		hit_zone = enemy.get_projectile_hit_zone(previous_position, next_position, _hit_radius)
	else:
		var enemy_center: Vector3 = enemy.get_projectile_hit_position()
		var closest := Geometry3D.get_closest_point_to_segment(enemy_center, previous_position, next_position)
		var combined_radius: float = _hit_radius + enemy.get_projectile_hit_radius()
		if closest.distance_squared_to(enemy_center) <= combined_radius * combined_radius:
			hit_zone = &"body"
	if hit_zone != &"weak_point" and hit_zone != &"body":
		return
	_hit_enemy_ids[enemy_id] = true
	var impact_position: Vector3 = enemy.get_projectile_hit_position()
	if hit_zone == &"weak_point" and enemy.has_method("hit_weak_point"):
		enemy.hit_weak_point(_damage)
	else:
		enemy.apply_damage(_damage, &"ranged")
	_apply_hit_reaction(enemy)
	enemy_hit.emit(impact_position, _damage)
	_chain_targets_hit += 1
	if _debug_chain_targeting:
		print("[EnergySphere] T" + str(_chain_targets_hit) + " hit " + enemy.name)
	if _chain_targets_hit >= _maximum_chain_targets:
		queue_free()
		return
	_select_next_target(impact_position)

func _select_next_target(previous_position: Vector3) -> void:
	var next_target: Node
	var best_distance := _chain_search_radius
	var radius_squared := _chain_search_radius * _chain_search_radius
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or candidate == _current_target:
			continue
		var candidate_id := candidate.get_instance_id()
		if _hit_enemy_ids.has(candidate_id) or not candidate.has_method("get_projectile_hit_position"):
			continue
		if candidate.has_method("is_defeated") and candidate.is_defeated():
			continue
		var candidate_position: Vector3 = candidate.get_projectile_hit_position()
		var distance := previous_position.distance_to(candidate_position)
		if distance * distance > radius_squared or distance >= best_distance:
			continue
		best_distance = distance
		next_target = candidate
	_current_target = next_target
	if is_instance_valid(_current_target):
		var redirect_direction := global_position.direction_to(_current_target.get_projectile_hit_position())
		if redirect_direction.length_squared() > 0.0001:
			_direction = _direction.lerp(redirect_direction, 0.65).normalized()
			look_at(global_position + _direction, Vector3.UP)
		_presentation.play_target_switch()
		if _debug_chain_targeting:
			print("[EnergySphere] next target " + _current_target.name + " radius=" + str(_chain_search_radius))
	else:
		_remaining_lifetime = minf(_remaining_lifetime, 0.08)

func _apply_hit_reaction(enemy: Node) -> void:
	if enemy.has_method("is_defeated") and enemy.is_defeated() and enemy.has_method("apply_lethal_knockback"):
		enemy.apply_lethal_knockback(_direction, lethal_knockback_force, lethal_knockback_duration, lethal_knockback_vertical_boost)
	elif enemy.has_method("apply_knockback"):
		enemy.apply_knockback(_direction, nonlethal_knockback_force, nonlethal_knockback_duration, nonlethal_knockback_vertical_boost)

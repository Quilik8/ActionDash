class_name ActionDashProjectile
extends Node3D

signal enemy_hit(position: Vector3, damage: float)

var _direction := Vector3.FORWARD
var _speed: float = 52.0
var _damage: float = 4.0
var _hit_radius: float = 0.55
var _remaining_lifetime: float = 1.8
var _hit_enemy_ids: Dictionary = {}

@export_category("Projectile hit reaction")
@export var nonlethal_knockback_force: float = 3.5
@export var nonlethal_knockback_duration: float = 0.24
@export var nonlethal_knockback_vertical_boost: float = 0.5
@export var lethal_knockback_force: float = 10.0
@export var lethal_knockback_duration: float = 0.58
@export var lethal_knockback_vertical_boost: float = 3.0

@onready var _presentation: ActionDashEnergyProjectileVisual = $Presentation

func setup(direction: Vector3, speed: float, damage: float, visual_radius: float, contact_margin: float, lifetime: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_hit_radius = maxf(visual_radius + contact_margin, 0.05)
	_remaining_lifetime = lifetime
	look_at(global_position + _direction, Vector3.UP)
	if is_node_ready():
		_presentation.configure_size(visual_radius)

func _ready() -> void:
	_presentation.play_launch()

func _process(delta: float) -> void:
	var previous_position := global_position
	var next_position := previous_position + _direction * _speed * delta
	global_position = next_position
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_id := enemy.get_instance_id()
		if _hit_enemy_ids.has(enemy_id):
			continue
		if enemy.has_method("get_projectile_hit_zone"):
			var hit_zone: StringName = enemy.get_projectile_hit_zone(previous_position, next_position, _hit_radius)
			if hit_zone == &"weak_point":
				_hit_enemy_ids[enemy_id] = true
				enemy.hit_weak_point(_damage)
				_apply_hit_reaction(enemy)
				enemy_hit.emit(enemy.get_projectile_hit_position(), _damage)
				continue
			if hit_zone == &"body":
				_hit_enemy_ids[enemy_id] = true
				enemy.apply_damage(_damage, &"ranged")
				_apply_hit_reaction(enemy)
				enemy_hit.emit(enemy.get_projectile_hit_position(), _damage)
			continue
		var enemy_center: Vector3 = enemy.get_projectile_hit_position()
		var closest := Geometry3D.get_closest_point_to_segment(enemy_center, previous_position, next_position)
		var combined_radius: float = _hit_radius + enemy.get_projectile_hit_radius()
		if closest.distance_squared_to(enemy_center) <= combined_radius * combined_radius:
			_hit_enemy_ids[enemy_id] = true
			enemy.apply_damage(_damage, &"ranged")
			_apply_hit_reaction(enemy)
			enemy_hit.emit(closest, _damage)

func _apply_hit_reaction(enemy: Node) -> void:
	if enemy.has_method("is_defeated") and enemy.is_defeated() and enemy.has_method("apply_lethal_knockback"):
		enemy.apply_lethal_knockback(_direction, lethal_knockback_force, lethal_knockback_duration, lethal_knockback_vertical_boost)
	elif enemy.has_method("apply_knockback"):
		enemy.apply_knockback(_direction, nonlethal_knockback_force, nonlethal_knockback_duration, nonlethal_knockback_vertical_boost)

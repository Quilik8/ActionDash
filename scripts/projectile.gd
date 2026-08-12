class_name ActionDashProjectile
extends Node3D

@export var hit_radius: float = 0.55
@export var lifetime: float = 1.6

var _direction := Vector3.FORWARD
var _speed: float = 20.0
var _damage: float = 1.0
var _remaining_lifetime: float

func _ready() -> void:
	_remaining_lifetime = lifetime

func setup(direction: Vector3, speed: float, damage: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_remaining_lifetime = lifetime

func _process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()
		return

	var hit_distance_squared := hit_radius * hit_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_center: Vector3 = enemy.global_position + Vector3.UP * 0.8
		if global_position.distance_squared_to(enemy_center) <= hit_distance_squared:
			enemy.apply_damage(_damage)
			queue_free()
			return

class_name ActionDashEnemy
extends Node3D

@export_category("Enemy")
@export var max_health: float = 3.0
@export var move_speed: float = 1.8

var current_health: float
var _target: Node3D

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("ground_enemies")

func initialize(target: Node3D) -> void:
	_target = target

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
		if _target == null:
			return

	var offset := _target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.04:
		global_position += offset.normalized() * move_speed * delta

func apply_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		queue_free()

func get_projectile_hit_position() -> Vector3:
	return global_position + Vector3.UP * 0.85

func get_projectile_hit_radius() -> float:
	return 0.75

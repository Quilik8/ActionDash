class_name ActionDashProximityDamage
extends Node

@export_category("Proximity damage")
@export var damage_radius: float = 2.1
@export var damage_amount: float = 1.0
@export var damage_interval: float = 0.35

var _timer: float = 0.0

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = damage_interval

	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	var radius_squared := damage_radius * damage_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and owner_node.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			enemy.apply_damage(damage_amount)

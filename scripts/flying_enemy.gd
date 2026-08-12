class_name ActionDashFlyingEnemy
extends Node3D

@export_category("Flying enemy")
@export var max_health: float = 3.0
@export var move_speed: float = 2.2
@export var hover_height: float = 7.0

var current_health: float
var _target: Node3D

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("flying_enemies")

func initialize(target: Node3D) -> void:
	_target = target

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
		if _target == null:
			return

	var desired_position := _target.global_position + Vector3.UP * hover_height
	global_position = global_position.move_toward(desired_position, move_speed * delta)

func apply_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		queue_free()

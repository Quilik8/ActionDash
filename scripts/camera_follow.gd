class_name ActionDashCameraFollow
extends Node3D

@export var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 8.0, 10.0)
@export var follow_smoothing: float = 7.0
@export var look_height: float = 0.7

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		global_position = _target.global_position + follow_offset

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Node3D
		if _target == null:
			return

	var desired_position := _target.global_position + follow_offset
	var blend := 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(desired_position, blend)
	look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)

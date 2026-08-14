class_name ActionDashEnvironmentDeterioration
extends Node

signal state_changed(state: StringName)

@export var world_environment_path: NodePath
@export var directional_light_path: NodePath
@export_range(0.0, 1.0, 0.01) var danger_threshold: float = 0.5
@export_range(0.0, 1.0, 0.01) var critical_threshold: float = 0.2

var _state: StringName = &"stable"
var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D

func _ready() -> void:
	_world_environment = get_node(world_environment_path) as WorldEnvironment
	_directional_light = get_node(directional_light_path) as DirectionalLight3D
	reset()

func update_time_ratio(ratio: float) -> void:
	var next_state: StringName = &"stable"
	if ratio <= critical_threshold:
		next_state = &"critical"
	elif ratio <= danger_threshold:
		next_state = &"danger"
	if next_state != _state:
		_state = next_state
		_apply_state()
		state_changed.emit(_state)

func reset() -> void:
	_state = &"stable"
	_apply_state()

func get_state() -> StringName:
	return _state

func _apply_state() -> void:
	if not is_instance_valid(_world_environment) or not is_instance_valid(_directional_light):
		return
	match _state:
		&"danger":
			_world_environment.environment.background_color = Color(0.18, 0.09, 0.08)
			_directional_light.light_color = Color(1.0, 0.72, 0.55)
			_directional_light.light_energy = 1.0
		&"critical":
			_world_environment.environment.background_color = Color(0.18, 0.035, 0.045)
			_directional_light.light_color = Color(1.0, 0.38, 0.28)
			_directional_light.light_energy = 0.82
		_:
			_world_environment.environment.background_color = Color(0.12, 0.17, 0.26)
			_directional_light.light_color = Color(1.0, 0.92, 0.8)
			_directional_light.light_energy = 1.1

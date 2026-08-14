class_name ActionDashCameraFollow
extends Node3D

@export var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 9.0, 12.0)
@export var follow_smoothing: float = 10.0
@export var look_smoothing: float = 14.0
@export var look_height: float = 0.7
@export_category("Camera collision")
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_margin: float = 0.65
@export_category("Speed framing")
@export var high_speed_distance_multiplier: float = 1.35
@export var normal_fov: float = 70.0
@export var high_speed_fov: float = 82.0
@export var framing_smoothing: float = 5.0
@export_category("Manual orbit")
@export var orbit_sensitivity: float = 0.004
@export_range(-80.0, 0.0, 1.0) var minimum_pitch_degrees: float = -20.0
@export_range(0.0, 89.0, 1.0) var maximum_pitch_degrees: float = 65.0

@onready var _camera: Camera3D = $Camera3D

var _target: ActionDashPlayer
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _current_distance_multiplier: float = 1.0
var _orbiting: bool = false
var _smoothed_look_position: Vector3

func _ready() -> void:
	process_priority = 1
	_target = get_node_or_null(target_path) as ActionDashPlayer
	var base_distance := follow_offset.length()
	if base_distance > 0.001:
		_orbit_yaw = atan2(follow_offset.x, follow_offset.z)
		_orbit_pitch = asin(clampf(follow_offset.y / base_distance, -1.0, 1.0))
	_camera.fov = normal_fov
	if _target != null:
		global_position = _target.global_position + follow_offset
		_smoothed_look_position = _target.global_position + Vector3.UP * look_height

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = mouse_button.pressed
	elif event is InputEventMouseMotion and _orbiting:
		var mouse_motion := event as InputEventMouseMotion
		_orbit_yaw -= mouse_motion.relative.x * orbit_sensitivity
		_orbit_pitch = clampf(
			_orbit_pitch + mouse_motion.relative.y * orbit_sensitivity,
			deg_to_rad(minimum_pitch_degrees),
			deg_to_rad(maximum_pitch_degrees)
		)

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as ActionDashPlayer
		if _target == null:
			return

	var speed_range := maxf(_target.get_extraordinary_max_speed() - _target.get_normal_speed(), 0.001)
	var speed_ratio := clampf((_target.get_horizontal_speed() - _target.get_normal_speed()) / speed_range, 0.0, 1.0)
	var desired_distance_multiplier := lerpf(1.0, high_speed_distance_multiplier, speed_ratio)
	var framing_blend := 1.0 - exp(-framing_smoothing * delta)
	_current_distance_multiplier = lerpf(_current_distance_multiplier, desired_distance_multiplier, framing_blend)
	_camera.fov = lerpf(_camera.fov, lerpf(normal_fov, high_speed_fov, speed_ratio), framing_blend)

	var base_distance := follow_offset.length()
	var orbit_direction := Vector3(
		sin(_orbit_yaw) * cos(_orbit_pitch),
		sin(_orbit_pitch),
		cos(_orbit_yaw) * cos(_orbit_pitch)
	)
	var desired_position := _target.global_position + orbit_direction * base_distance * _current_distance_multiplier
	desired_position = _get_collision_safe_position(_target.global_position + Vector3.UP * look_height, desired_position)
	var blend := 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(desired_position, blend)
	var desired_look_position := _target.global_position + Vector3.UP * look_height
	var look_blend := 1.0 - exp(-look_smoothing * delta)
	_smoothed_look_position = _smoothed_look_position.lerp(desired_look_position, look_blend)
	look_at(_smoothed_look_position, Vector3.UP)

func _get_collision_safe_position(look_origin: Vector3, desired_position: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(look_origin, desired_position, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_position
	return (hit["position"] as Vector3) + (hit["normal"] as Vector3) * collision_margin

func snap_to_target() -> void:
	if not is_instance_valid(_target):
		return
	var base_distance := follow_offset.length()
	var orbit_direction := Vector3(
		sin(_orbit_yaw) * cos(_orbit_pitch),
		sin(_orbit_pitch),
		cos(_orbit_yaw) * cos(_orbit_pitch)
	)
	global_position = _target.global_position + orbit_direction * base_distance * _current_distance_multiplier
	_smoothed_look_position = _target.global_position + Vector3.UP * look_height
	look_at(_smoothed_look_position, Vector3.UP)

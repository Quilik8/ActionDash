class_name ActionDashFlyingEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Flying enemy")
@export var max_health: float = 1.0

@export_category("Protected objective assault")
@export var drift_speed: float = 3.0
@export var territory_radius: float = 5.5
@export var hover_amplitude: float = 0.65
@export var hover_frequency: float = 1.15
@export var objective_damage: float = 3.0
@export var objective_attack_interval: float = 1.5
@export var route_lane_spacing: float = 9.0

@export_category("Performance LOD")
@export var detailed_visual_distance: float = 40.0
@export var simplified_visual_distance: float = 115.0
@export var lod_check_interval: float = 0.2
@export var distant_logic_interval: float = 0.1

const BAT_SCENE := preload("res://assets/enemies/quaternius_lowpoly_monsters/Bat.fbx")
const DEATH_TEXTURE := preload("res://assets/vfx/brackeys/particles/smoke_04_a.png")

var current_health: float
var _home_position: Vector3
var _drift_target: Vector3
var _hover_time: float = 0.0
var _defeated: bool = false
var _random := RandomNumberGenerator.new()
var _model: Node3D
var _animation_player: AnimationPlayer
var _death_timer: float = 0.0
var _hit_timer: float = 0.0
var _current_animation: StringName
var _death_vfx: Sprite3D
var _camera: Camera3D
var _lod_timer: float = 0.0
var _logic_accumulator: float = 0.0
var _detailed_lod_active: bool = true
var _simplified_lod_active: bool = false
var _assault_target: ActionDashProtectedCore
var _route_stage: int = 0
var _objective_attack_timer: float = 0.0
var _knockback_velocity: Vector3
var _knockback_remaining: float = 0.0
var _knockback_drag: float = 0.0

@onready var _visual_root: Node3D = $VisualRoot
@onready var _primitive_body: MeshInstance3D = $VisualRoot/Body

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	_primitive_body.visible = false
	_create_death_vfx()
	deactivate()

func activate(home_position: Vector3) -> void:
	_home_position = home_position
	_drift_target = home_position
	global_position = home_position
	current_health = max_health
	_defeated = false
	_death_timer = 0.0
	_hit_timer = 0.0
	_knockback_velocity = Vector3.ZERO
	_knockback_remaining = 0.0
	_objective_attack_timer = _random.randf_range(0.0, objective_attack_interval)
	_visual_root.scale = Vector3.ONE
	_visual_root.rotation.z = 0.0
	_death_vfx.visible = false
	visible = true
	add_to_group("enemies")
	add_to_group("flying_enemies")
	set_process(true)
	_lod_timer = _random.randf_range(0.0, lod_check_interval)
	_logic_accumulator = 0.0
	_update_performance_lod()
	_hover_time = _random.randf_range(0.0, TAU)
	_choose_protected_objective()
	_play_animation("Flying", 0.0, 1.0)

func initialize(home_position: Vector3) -> void:
	activate(home_position)

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("enemies")
	remove_from_group("flying_enemies")
	if is_instance_valid(_death_vfx):
		_death_vfx.visible = false

func _process(delta: float) -> void:
	var being_knocked_back := _update_knockback(delta)
	if _defeated:
		_death_timer = maxf(_death_timer - delta, 0.0)
		_visual_root.rotation.z += delta * 5.0
		_visual_root.scale = _visual_root.scale.lerp(Vector3.ONE * 0.4, 1.0 - exp(-7.0 * delta))
		if _death_timer <= 0.0:
			died.emit()
			set_process(false)
		return
	if being_knocked_back:
		return
	_hover_time += delta * hover_frequency
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = lod_check_interval
		_update_performance_lod()
	_logic_accumulator += delta
	if not _detailed_lod_active and _logic_accumulator < distant_logic_interval:
		return
	var logic_delta := _logic_accumulator
	_logic_accumulator = 0.0
	if _hit_timer <= 0.0:
		_play_animation("Flying", 0.12, 1.0)
	_objective_attack_timer = maxf(_objective_attack_timer - logic_delta, 0.0)
	var desired := _drift_target
	desired.y = _home_position.y + sin(_hover_time) * hover_amplitude
	global_position = global_position.move_toward(desired, drift_speed * logic_delta)
	var offset := desired - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.02:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-6.0 * logic_delta))
	if _route_stage < 2 and global_position.distance_squared_to(desired) < 0.2:
		_advance_objective_route()
	if _route_stage >= 2:
		_try_damage_objective()

func get_home_position() -> Vector3:
	return _home_position

func is_using_simplified_lod() -> bool:
	return visible and _simplified_lod_active

func is_assaulting_building() -> bool:
	return is_attacking_objective()

func is_attacking_objective() -> bool:
	return visible and _route_stage >= 2 and is_instance_valid(_assault_target)

func get_simplified_lod_transform() -> Transform3D:
	return transform * _primitive_body.transform

func apply_damage(amount: float, _damage_type: StringName = &"generic") -> void:
	if _defeated:
		return
	current_health -= amount
	damaged.emit(amount, maxf(current_health, 0.0))
	if current_health <= 0.0:
		_defeated = true
		_death_timer = 0.48
		_death_vfx.visible = true
		_play_animation("Death", 0.03, 2.0)
	else:
		_hit_timer = 0.16
		_play_animation("Hit", 0.02, 1.5)

func apply_knockback(direction: Vector3, force: float, duration: float, vertical_boost: float = 0.0) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	_knockback_velocity = flat_direction * maxf(force, 0.0) + Vector3.UP * maxf(vertical_boost, 0.0)
	_knockback_remaining = maxf(duration, 0.05)
	_knockback_drag = maxf(force / _knockback_remaining, 0.0)

func get_projectile_hit_position() -> Vector3:
	return global_position

func get_projectile_hit_radius() -> float:
	return 0.95

func _choose_protected_objective() -> void:
	var objectives := get_tree().get_nodes_in_group("protected_objective")
	if objectives.is_empty():
		var fallback_angle := _random.randf_range(0.0, TAU)
		var fallback_distance := sqrt(_random.randf()) * territory_radius
		_drift_target = _home_position + Vector3(cos(fallback_angle), 0.0, sin(fallback_angle)) * fallback_distance
		return
	_assault_target = objectives[0] as ActionDashProtectedCore
	var toward_core := _assault_target.global_position - _home_position
	toward_core.y = 0.0
	var perpendicular := Vector3(-toward_core.z, 0.0, toward_core.x).normalized()
	var group_index := int(get_meta("spawn_group", 0))
	var lane_offset := float((group_index % 3) - 1) * route_lane_spacing
	_drift_target = _home_position.lerp(_assault_target.global_position, 0.5) + perpendicular * lane_offset
	_drift_target.y = _home_position.y
	_route_stage = 0

func _advance_objective_route() -> void:
	if not is_instance_valid(_assault_target):
		_choose_protected_objective()
		return
	if _route_stage == 0:
		var outward := global_position - _assault_target.global_position
		outward.y = 0.0
		if outward.length_squared() < 0.01:
			outward = Vector3.FORWARD
		_drift_target = _assault_target.global_position + outward.normalized() * (_assault_target.get_approach_radius() + 3.0)
		_drift_target.y = _home_position.y
		_route_stage = 1
		return
	_route_stage = 2
	_drift_target = global_position
	_try_damage_objective()

func _try_damage_objective() -> void:
	if _route_stage < 2 or _objective_attack_timer > 0.0 or not is_instance_valid(_assault_target):
		return
	var flat_offset := _assault_target.global_position - global_position
	flat_offset.y = 0.0
	if flat_offset.length() > _assault_target.get_approach_radius() + 4.0:
		_route_stage = 1
		_drift_target = _assault_target.global_position + flat_offset.normalized() * (_assault_target.get_approach_radius() + 3.0)
		_drift_target.y = _home_position.y
		return
	_objective_attack_timer = objective_attack_interval * _random.randf_range(0.9, 1.1)
	_assault_target.apply_enemy_damage(objective_damage)

func _update_knockback(delta: float) -> bool:
	if _knockback_remaining <= 0.0:
		return false
	_knockback_remaining = maxf(_knockback_remaining - delta, 0.0)
	global_position += _knockback_velocity * delta
	var flat_velocity := Vector3(_knockback_velocity.x, 0.0, _knockback_velocity.z)
	flat_velocity = flat_velocity.move_toward(Vector3.ZERO, _knockback_drag * delta)
	_knockback_velocity.x = flat_velocity.x
	_knockback_velocity.z = flat_velocity.z
	_knockback_velocity.y = move_toward(_knockback_velocity.y, 0.0, 8.0 * delta)
	return true

func _update_performance_lod() -> void:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var distance_squared := _camera.global_position.distance_squared_to(global_position)
	var in_view := _camera.is_position_in_frustum(global_position)
	_detailed_lod_active = in_view and distance_squared <= detailed_visual_distance * detailed_visual_distance
	_simplified_lod_active = in_view and distance_squared <= simplified_visual_distance * simplified_visual_distance and not _detailed_lod_active
	if _detailed_lod_active and not is_instance_valid(_model):
		_install_model()
	if is_instance_valid(_model):
		_model.visible = _detailed_lod_active
		_model.process_mode = Node.PROCESS_MODE_INHERIT if _detailed_lod_active else Node.PROCESS_MODE_DISABLED
	_primitive_body.visible = false

func _install_model() -> void:
	_model = BAT_SCENE.instantiate() as Node3D
	_model.name = "AnimatedBat"
	_model.scale = Vector3.ONE * 0.42
	_model.rotation_degrees.y = 180.0
	_visual_root.add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null

func _play_animation(keyword: String, blend: float, speed: float) -> void:
	if _animation_player == null:
		return
	for animation in _animation_player.get_animation_list():
		if keyword.to_lower() in String(animation).to_lower():
			if _current_animation == animation and _animation_player.is_playing():
				return
			_current_animation = animation
			_animation_player.play(animation, blend, speed)
			return

func _create_death_vfx() -> void:
	_death_vfx = Sprite3D.new()
	_death_vfx.name = "DeathSmoke"
	_death_vfx.texture = DEATH_TEXTURE
	_death_vfx.pixel_size = 0.012
	_death_vfx.modulate = Color(0.38, 0.65, 0.9, 0.85)
	_death_vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_root.add_child(_death_vfx)

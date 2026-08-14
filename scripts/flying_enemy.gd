class_name ActionDashFlyingEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Flying enemy")
@export var max_health: float = 1.0

@export_category("Territorial flight")
@export var drift_speed: float = 3.0
@export var territory_radius: float = 5.5
@export var hover_amplitude: float = 0.65
@export var hover_frequency: float = 1.15
@export var decision_interval_min: float = 2.0
@export var decision_interval_max: float = 4.0

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
var _decision_timer: float = 0.0
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
var _assault_target: Node3D

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
	_choose_building_target()
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
	if _defeated:
		_death_timer = maxf(_death_timer - delta, 0.0)
		_visual_root.rotation.z += delta * 5.0
		_visual_root.scale = _visual_root.scale.lerp(Vector3.ONE * 0.4, 1.0 - exp(-7.0 * delta))
		if _death_timer <= 0.0:
			died.emit()
			set_process(false)
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
	_decision_timer -= logic_delta
	var desired := _drift_target
	desired.y = _home_position.y + sin(_hover_time) * hover_amplitude
	global_position = global_position.move_toward(desired, drift_speed * logic_delta)
	var offset := desired - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.02:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-6.0 * logic_delta))
	if global_position.distance_squared_to(desired) < 0.2 or _decision_timer <= 0.0:
		_choose_building_target()

func get_home_position() -> Vector3:
	return _home_position

func is_using_simplified_lod() -> bool:
	return visible and _simplified_lod_active

func is_assaulting_building() -> bool:
	return visible and is_instance_valid(_assault_target)

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

func get_projectile_hit_position() -> Vector3:
	return global_position

func get_projectile_hit_radius() -> float:
	return 0.95

func _choose_building_target() -> void:
	var buildings := get_tree().get_nodes_in_group("city_building_colliders")
	if buildings.is_empty():
		var fallback_angle := _random.randf_range(0.0, TAU)
		var fallback_distance := sqrt(_random.randf()) * territory_radius
		_drift_target = _home_position + Vector3(cos(fallback_angle), 0.0, sin(fallback_angle)) * fallback_distance
		_schedule_next_decision()
		return
	var closest: Node3D
	var closest_distance_squared := INF
	for node in buildings:
		var building := node as Node3D
		var distance_squared := global_position.distance_squared_to(building.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = building
	_assault_target = closest
	var collision_size: Vector3 = _assault_target.get_meta("collision_size", Vector3(8.0, 8.0, 8.0))
	var angle := _random.randf_range(0.0, TAU)
	var orbit_radius := maxf(collision_size.x, collision_size.z) * 0.55 + _random.randf_range(2.0, 5.0)
	_drift_target = _assault_target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * orbit_radius
	_drift_target.y = _assault_target.global_position.y + clampf(collision_size.y * 0.65, 5.0, 11.0)
	_schedule_next_decision()

func _schedule_next_decision() -> void:
	_decision_timer = _random.randf_range(decision_interval_min, decision_interval_max)

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

class_name ActionDashEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Enemy")
@export var max_health: float = 1.0

@export_category("Territorial idle")
@export var wander_speed: float = 0.75
@export var territory_radius: float = 4.0
@export var decision_interval_min: float = 1.5
@export var decision_interval_max: float = 3.5
@export var arrival_distance: float = 0.25

@export_category("Performance LOD")
@export var detailed_visual_distance: float = 34.0
@export var simplified_visual_distance: float = 105.0
@export var lod_check_interval: float = 0.2
@export var distant_logic_interval: float = 0.1

const VISUALS := {
	&"skeleton": [preload("res://assets/enemies/quaternius_lowpoly_monsters/Skeleton.fbx"), 0.36, "Idle", "Running", "Death", 1.0, 0.6],
	&"slime": [preload("res://assets/enemies/quaternius_lowpoly_monsters/Slime.fbx"), 0.75, "Idle", "Walk", "Death", 1.5, 0.02],
	&"spider": [preload("res://assets/enemies/quaternius_easy_animated/Spider.fbx"), 0.65, "Idle", "Walk", "Death", 4.0, 0.0],
}
const DEATH_TEXTURE := preload("res://assets/vfx/brackeys/particles/smoke_04_a.png")

var current_health: float
var _home_position: Vector3
var _wander_target: Vector3
var _decision_timer: float = 0.0
var _defeated: bool = false
var _random := RandomNumberGenerator.new()
var _visual_variant: StringName = &"skeleton"
var _model: Node3D
var _animation_player: AnimationPlayer
var _current_animation: StringName
var _death_timer: float = 0.0
var _hit_timer: float = 0.0
var _death_vfx: Sprite3D
var _camera: Camera3D
var _lod_timer: float = 0.0
var _logic_accumulator: float = 0.0
var _detailed_lod_active: bool = true
var _simplified_lod_active: bool = false

@onready var _visual_root: Node3D = $VisualRoot
@onready var _primitive_body: MeshInstance3D = $VisualRoot/Body

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	_primitive_body.visible = false
	_create_death_vfx()
	_install_visual()
	deactivate()

func configure_visual(variant: StringName) -> void:
	if not VISUALS.has(variant):
		variant = &"skeleton"
	if _visual_variant == variant and is_instance_valid(_model):
		return
	_visual_variant = variant
	if is_node_ready():
		_install_visual()

func get_visual_variant() -> StringName:
	return _visual_variant

func activate(home_position: Vector3) -> void:
	_home_position = home_position
	_wander_target = home_position
	global_position = home_position
	current_health = max_health
	_defeated = false
	_death_timer = 0.0
	_hit_timer = 0.0
	_visual_root.scale = Vector3.ONE
	_death_vfx.visible = false
	visible = true
	add_to_group("enemies")
	add_to_group("ground_enemies")
	set_process(true)
	_lod_timer = _random.randf_range(0.0, lod_check_interval)
	_logic_accumulator = 0.0
	_update_performance_lod()
	_schedule_next_decision()
	_play_named_animation(String(VISUALS[_visual_variant][2]), 0.0, 1.0)

func initialize(home_position: Vector3) -> void:
	activate(home_position)

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("enemies")
	remove_from_group("ground_enemies")
	if is_instance_valid(_death_vfx):
		_death_vfx.visible = false

func _process(delta: float) -> void:
	if _defeated:
		_death_timer = maxf(_death_timer - delta, 0.0)
		_visual_root.scale = _visual_root.scale.lerp(Vector3.ONE * 0.55, 1.0 - exp(-7.0 * delta))
		if _death_timer <= 0.0:
			died.emit()
			set_process(false)
		return
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_visual_root.scale = _visual_root.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = lod_check_interval
		_update_performance_lod()
	_logic_accumulator += delta
	if not _detailed_lod_active and _logic_accumulator < distant_logic_interval:
		return
	var logic_delta := _logic_accumulator
	_logic_accumulator = 0.0
	_decision_timer -= logic_delta
	var offset := _wander_target - global_position
	offset.y = 0.0
	if offset.length() > arrival_distance:
		global_position += offset.normalized() * minf(wander_speed * logic_delta, offset.length())
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-7.0 * logic_delta))
		_play_named_animation(String(VISUALS[_visual_variant][3]), 0.18, 1.0)
	elif _decision_timer <= 0.0:
		_choose_wander_target()
	else:
		_play_named_animation(String(VISUALS[_visual_variant][2]), 0.22, 1.0)

func get_home_position() -> Vector3:
	return _home_position

func is_using_simplified_lod() -> bool:
	return visible and _simplified_lod_active

func get_simplified_lod_transform() -> Transform3D:
	return transform * _primitive_body.transform

func apply_damage(amount: float, _damage_type: StringName = &"generic") -> void:
	if _defeated:
		return
	current_health -= amount
	damaged.emit(amount, maxf(current_health, 0.0))
	if current_health <= 0.0:
		_defeated = true
		_death_timer = 0.52
		_death_vfx.visible = true
		_death_vfx.scale = Vector3.ONE * (1.7 if _visual_variant == &"spider" else 1.0)
		_play_named_animation(String(VISUALS[_visual_variant][4]), 0.03, 2.0)
	else:
		_hit_timer = 0.1
		_visual_root.scale = Vector3.ONE * 1.12

func get_projectile_hit_position() -> Vector3:
	var height := 1.15 if _visual_variant == &"spider" else (0.65 if _visual_variant == &"slime" else 0.95)
	return global_position + Vector3.UP * height

func get_projectile_hit_radius() -> float:
	return 1.35 if _visual_variant == &"spider" else (0.75 if _visual_variant == &"slime" else 0.82)

func _choose_wander_target() -> void:
	var angle := _random.randf_range(0.0, TAU)
	var distance := sqrt(_random.randf()) * territory_radius
	_wander_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	_schedule_next_decision()

func _schedule_next_decision() -> void:
	_decision_timer = _random.randf_range(decision_interval_min, decision_interval_max)

func _update_performance_lod() -> void:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null or not is_instance_valid(_model):
		return
	var distance_squared := _camera.global_position.distance_squared_to(global_position)
	var in_view := _camera.is_position_in_frustum(global_position + Vector3.UP)
	_detailed_lod_active = in_view and distance_squared <= detailed_visual_distance * detailed_visual_distance
	_simplified_lod_active = in_view and distance_squared <= simplified_visual_distance * simplified_visual_distance and not _detailed_lod_active
	_model.visible = _detailed_lod_active
	_model.process_mode = Node.PROCESS_MODE_INHERIT if _detailed_lod_active else Node.PROCESS_MODE_DISABLED
	_primitive_body.visible = false

func _install_visual() -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	var definition: Array = VISUALS[_visual_variant]
	_model = (definition[0] as PackedScene).instantiate() as Node3D
	_model.name = "AnimatedModel"
	_model.scale = Vector3.ONE * float(definition[1])
	_model.position.y = float(definition[6])
	_model.rotation_degrees.y = 180.0
	_visual_root.add_child(_model)
	max_health = float(definition[5])
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	_current_animation = &""
	_update_primitive_lod_shape()

func _update_primitive_lod_shape() -> void:
	match _visual_variant:
		&"slime":
			_primitive_body.scale = Vector3(1.15, 0.65, 1.15)
		&"spider":
			_primitive_body.scale = Vector3(1.65, 0.45, 1.65)
		_:
			_primitive_body.scale = Vector3(0.85, 1.0, 0.85)

func _play_named_animation(keyword: String, blend: float, speed: float) -> void:
	if _animation_player == null:
		return
	var animation := _find_animation(keyword)
	if animation == &"" or (_current_animation == animation and _animation_player.is_playing()):
		return
	_current_animation = animation
	_animation_player.play(animation, blend, speed)

func _find_animation(keyword: String) -> StringName:
	for animation in _animation_player.get_animation_list():
		if keyword.to_lower() in String(animation).to_lower():
			return animation
	return &""

func _create_death_vfx() -> void:
	_death_vfx = Sprite3D.new()
	_death_vfx.name = "DeathSmoke"
	_death_vfx.texture = DEATH_TEXTURE
	_death_vfx.pixel_size = 0.01
	_death_vfx.modulate = Color(0.65, 0.38, 0.8, 0.85)
	_death_vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_death_vfx.position.y = 0.9
	_visual_root.add_child(_death_vfx)

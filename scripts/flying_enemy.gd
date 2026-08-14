class_name ActionDashFlyingEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Flying enemy")
@export var max_health: float = 1.0

@export_category("Territorial flight")
@export var drift_speed: float = 1.1
@export var territory_radius: float = 5.5
@export var hover_amplitude: float = 0.65
@export var hover_frequency: float = 1.15
@export var decision_interval_min: float = 2.0
@export var decision_interval_max: float = 4.0

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

@onready var _visual_root: Node3D = $VisualRoot
@onready var _primitive_body: MeshInstance3D = $VisualRoot/Body

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	_primitive_body.visible = false
	_model = BAT_SCENE.instantiate() as Node3D
	_model.name = "AnimatedBat"
	_model.scale = Vector3.ONE * 52.0
	_model.rotation_degrees.y = 180.0
	_visual_root.add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
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
	_hover_time = _random.randf_range(0.0, TAU)
	_schedule_next_decision()
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
	if _hit_timer <= 0.0:
		_play_animation("Flying", 0.12, 1.0)
	_decision_timer -= delta
	var desired := _drift_target
	desired.y = _home_position.y + sin(_hover_time) * hover_amplitude
	global_position = global_position.move_toward(desired, drift_speed * delta)
	var offset := desired - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.02:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-6.0 * delta))
	if global_position.distance_squared_to(desired) < 0.2 or _decision_timer <= 0.0:
		_choose_drift_target()

func get_home_position() -> Vector3:
	return _home_position

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

func _choose_drift_target() -> void:
	var angle := _random.randf_range(0.0, TAU)
	var distance := sqrt(_random.randf()) * territory_radius
	_drift_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	_schedule_next_decision()

func _schedule_next_decision() -> void:
	_decision_timer = _random.randf_range(decision_interval_min, decision_interval_max)

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

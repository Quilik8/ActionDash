class_name ActionDashFlyingEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Flying enemy")
@export var max_health: float = 3.0

@export_category("Territorial flight")
@export var drift_speed: float = 1.1
@export var territory_radius: float = 5.5
@export var hover_amplitude: float = 0.65
@export var hover_frequency: float = 1.15
@export var decision_interval_min: float = 2.0
@export var decision_interval_max: float = 4.0

var current_health: float
var _home_position: Vector3
var _drift_target: Vector3
var _decision_timer: float = 0.0
var _hover_time: float = 0.0
var _defeated: bool = false
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	deactivate()

func activate(home_position: Vector3) -> void:
	_home_position = home_position
	_drift_target = home_position
	global_position = home_position
	current_health = max_health
	_defeated = false
	visible = true
	add_to_group("enemies")
	add_to_group("flying_enemies")
	set_process(true)
	_hover_time = _random.randf_range(0.0, TAU)
	_schedule_next_decision()

func initialize(home_position: Vector3) -> void:
	activate(home_position)

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("enemies")
	remove_from_group("flying_enemies")

func _process(delta: float) -> void:
	_hover_time += delta * hover_frequency
	_decision_timer -= delta
	var desired := _drift_target
	desired.y = _home_position.y + sin(_hover_time) * hover_amplitude
	global_position = global_position.move_toward(desired, drift_speed * delta)
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
		died.emit()

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

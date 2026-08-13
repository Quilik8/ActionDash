class_name ActionDashEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Enemy")
@export var max_health: float = 3.0

@export_category("Territorial idle")
@export var wander_speed: float = 0.75
@export var territory_radius: float = 4.0
@export var decision_interval_min: float = 1.5
@export var decision_interval_max: float = 3.5
@export var arrival_distance: float = 0.25

var current_health: float
var _home_position: Vector3
var _wander_target: Vector3
var _decision_timer: float = 0.0
var _defeated: bool = false
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	deactivate()

func activate(home_position: Vector3) -> void:
	_home_position = home_position
	_wander_target = home_position
	global_position = home_position
	current_health = max_health
	_defeated = false
	visible = true
	add_to_group("enemies")
	add_to_group("ground_enemies")
	set_process(true)
	_schedule_next_decision()

func initialize(home_position: Vector3) -> void:
	activate(home_position)

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("enemies")
	remove_from_group("ground_enemies")

func _process(delta: float) -> void:
	_decision_timer -= delta
	var offset := _wander_target - global_position
	offset.y = 0.0
	if offset.length() > arrival_distance:
		global_position += offset.normalized() * minf(wander_speed * delta, offset.length())
	elif _decision_timer <= 0.0:
		_choose_wander_target()

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
	return global_position + Vector3.UP * 0.85

func get_projectile_hit_radius() -> float:
	return 0.75

func _choose_wander_target() -> void:
	var angle := _random.randf_range(0.0, TAU)
	var distance := sqrt(_random.randf()) * territory_radius
	_wander_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	_schedule_next_decision()

func _schedule_next_decision() -> void:
	_decision_timer = _random.randf_range(decision_interval_min, decision_interval_max)

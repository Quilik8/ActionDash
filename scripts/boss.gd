class_name ActionDashBoss
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died
signal weak_point_hit
signal vulnerability_changed(active: bool)

@export_category("Boss")
@export var max_health: float = 60.0
@export var resistant_damage_multiplier: float = 0.35
@export var vulnerable_melee_multiplier: float = 3.0
@export var vulnerability_duration: float = 6.0
@export var weak_point_radius: float = 0.72
@export var body_hit_radius: float = 2.1

var current_health: float
var _vulnerability_remaining: float = 0.0
var _defeated: bool = false

@onready var _weak_point: Marker3D = $Detection/WeakPointCenter
@onready var _vulnerability_aura: MeshInstance3D = $VisualRoot/VulnerabilityAura

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	add_to_group("bosses")
	_vulnerability_aura.visible = false

func initialize(home_position: Vector3) -> void:
	global_position = home_position

func _process(delta: float) -> void:
	if _vulnerability_remaining <= 0.0:
		return
	_vulnerability_remaining = maxf(_vulnerability_remaining - delta, 0.0)
	if _vulnerability_remaining <= 0.0:
		_vulnerability_aura.visible = false
		vulnerability_changed.emit(false)

func is_vulnerable() -> bool:
	return _vulnerability_remaining > 0.0

func get_vulnerability_remaining() -> float:
	return _vulnerability_remaining

func hit_weak_point(projectile_damage: float) -> void:
	if _defeated:
		return
	apply_damage(projectile_damage, &"ranged")
	_vulnerability_remaining = vulnerability_duration
	_vulnerability_aura.visible = true
	weak_point_hit.emit()
	vulnerability_changed.emit(true)

func apply_damage(amount: float, damage_type: StringName = &"generic") -> void:
	if _defeated:
		return
	var multiplier := resistant_damage_multiplier
	if damage_type == &"melee" and is_vulnerable():
		multiplier = vulnerable_melee_multiplier
	var applied_damage := amount * multiplier
	current_health -= applied_damage
	damaged.emit(applied_damage, maxf(current_health, 0.0))
	if current_health <= 0.0:
		_defeated = true
		remove_from_group("enemies")
		remove_from_group("bosses")
		visible = false
		set_process(false)
		died.emit()

func get_projectile_hit_position() -> Vector3:
	return global_position + Vector3.UP * 2.0

func get_projectile_hit_radius() -> float:
	return body_hit_radius

func get_projectile_hit_zone(segment_start: Vector3, segment_end: Vector3, projectile_radius: float) -> StringName:
	var weak_closest := Geometry3D.get_closest_point_to_segment(_weak_point.global_position, segment_start, segment_end)
	if weak_closest.distance_squared_to(_weak_point.global_position) <= pow(weak_point_radius + projectile_radius, 2.0):
		return &"weak_point"
	var body_center := get_projectile_hit_position()
	var body_closest := Geometry3D.get_closest_point_to_segment(body_center, segment_start, segment_end)
	if body_closest.distance_squared_to(body_center) <= pow(body_hit_radius + projectile_radius, 2.0):
		return &"body"
	return &"none"

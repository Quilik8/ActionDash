class_name ActionDashProtectedCore
extends StaticBody3D

signal integrity_changed(current: float, maximum: float)
signal depleted

@export var maximum_integrity: float = 1000.0
@export var approach_radius: float = 7.0

var _integrity: float
var _flash_timer: float = 0.0

@onready var _energy_mesh: MeshInstance3D = $Energy

func _ready() -> void:
	add_to_group("protected_objective")
	reset_integrity()

func _process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
	if _flash_timer > 0.0:
		pulse += 0.16
	_energy_mesh.scale = Vector3.ONE * pulse

func reset_integrity() -> void:
	_integrity = maximum_integrity
	_flash_timer = 0.0
	integrity_changed.emit(_integrity, maximum_integrity)

func apply_enemy_damage(amount: float) -> void:
	if amount <= 0.0 or _integrity <= 0.0:
		return
	_integrity = maxf(_integrity - amount, 0.0)
	_flash_timer = 0.12
	integrity_changed.emit(_integrity, maximum_integrity)
	if _integrity <= 0.0:
		depleted.emit()

func get_integrity() -> float:
	return _integrity

func get_maximum_integrity() -> float:
	return maximum_integrity

func get_integrity_ratio() -> float:
	return _integrity / maxf(maximum_integrity, 0.001)

func get_approach_radius() -> float:
	return approach_radius

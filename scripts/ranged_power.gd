class_name ActionDashRangedPower
extends Node

@warning_ignore("unused_signal")
signal activated(origin: Vector3, direction: Vector3)

@export_category("Ranged power")
@export var projectile_scene: PackedScene
@export var cooldown: float = 3.5
@export var damage: float = 4.0
@export var projectile_count: int = 1
@export var impact_behavior: StringName = &"standard"

var _cooldown_remaining: float = 0.0

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining <= 0.0:
		set_physics_process(false)

func is_ready() -> bool:
	return _cooldown_remaining <= 0.0

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func activate(_world: Node, _origin: Vector3, _target: Vector3) -> bool:
	return false

func apply_runtime_modifiers(modifiers: Dictionary) -> void:
	if modifiers.has("cooldown"):
		cooldown = maxf(float(modifiers["cooldown"]), 0.0)
	if modifiers.has("damage"):
		damage = maxf(float(modifiers["damage"]), 0.0)
	if modifiers.has("projectile_count"):
		projectile_count = maxi(int(modifiers["projectile_count"]), 1)
	if modifiers.has("impact_behavior"):
		impact_behavior = StringName(modifiers["impact_behavior"])

func _begin_cooldown() -> void:
	_cooldown_remaining = cooldown
	set_physics_process(_cooldown_remaining > 0.0)

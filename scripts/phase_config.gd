class_name ActionDashPhaseConfig
extends Resource

@export_category("Identity")
@export var phase_number: int = 1
@export var display_name: String = "FASE 1"
@export var variant_id: StringName = &"standard"

@export_category("Objective")
@export var total_enemies: int = 38
@export var maximum_active_enemies: int = 14
@export var time_limit_seconds: float = 105.0
@export var contains_boss: bool = false
@export var boss_scene: PackedScene

@export_category("Spawn groups")
@export var group_count: int = 4
@export var minimum_enemies_per_group: int = 3
@export var maximum_enemies_per_group: int = 5
@export var group_spread_radius: float = 7.0
@export var minimum_group_center_distance: float = 38.0
@export var flying_enemy_ratio: float = 0.15
@export var spawn_interval: float = 0.45

@export_category("Future variants")
@export var enemy_set_id: StringName = &"basic_invasion"
@export var environment_variant_id: StringName = &"macrozone_01"

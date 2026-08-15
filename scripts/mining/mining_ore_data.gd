class_name ActionDashMiningOreData
extends Resource

@export var id: StringName
@export var display_name: String
@export var value: int = 1
@export var weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var rarity: float = 0.5
@export var color: Color = Color.WHITE

@export_category("Vein distribution")
@export var layer_1_vein_count: int = 0
@export var layer_2_vein_count: int = 0
@export var vein_min_size: int = 2
@export var vein_max_size: int = 4
@export var preferred_layer: int = 1

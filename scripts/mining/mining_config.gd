class_name ActionDashMiningConfig
extends Resource

@export_category("Grid")
@export var default_seed: int = 814271
@export var grid_width: int = 40
@export var layer_1_rows: int = 18
@export var layer_2_rows: int = 18
@export var cell_size: float = 24.0

@export_category("Mech")
@export var drill_power: float = 12.0
@export var capacity: float = 60.0
@export var base_speed: float = 150.0
@export_range(0.0, 0.8, 0.01) var maximum_load_speed_penalty: float = 0.32
@export_range(0.1, 0.9, 0.01) var light_max_ratio: float = 0.45

@export_category("Layer 1 composition")
@export var layer_1_soil_weight: float = 0.68
@export var layer_1_compact_weight: float = 0.22
@export var layer_1_rock_weight: float = 0.10
@export var layer_1_compact_pockets: int = 3

@export_category("Layer 2 composition")
@export var layer_2_soil_weight: float = 0.30
@export var layer_2_compact_weight: float = 0.42
@export var layer_2_rock_weight: float = 0.28
@export var layer_2_compact_pockets: int = 5
@export var layer_2_soft_pockets: int = 2
@export var layer_2_rock_bands: int = 3

@export_category("Veins")

@export_category("Data")
@export var blocks: Array[ActionDashMiningBlockData] = []
@export var ores: Array[ActionDashMiningOreData] = []

func get_block_index(id: StringName) -> int:
	for index in blocks.size():
		if blocks[index].id == id:
			return index
	return -1

func get_ore_index(id: StringName) -> int:
	for index in ores.size():
		if ores[index].id == id:
			return index
	return -1

func get_ore(id: StringName) -> ActionDashMiningOreData:
	var index := get_ore_index(id)
	return ores[index] if index >= 0 else null

func get_total_rows() -> int:
	return layer_1_rows + layer_2_rows

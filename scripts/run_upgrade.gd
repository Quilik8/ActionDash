class_name ActionDashRunUpgrade
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export_enum("Card", "Movement", "Melee", "Ranged") var category: String = "Card"
@export var stat_id: StringName
@export_enum("Add", "Multiply") var operation: String = "Add"
@export var value: float

func apply_to(player: ActionDashPlayer) -> void:
	player.apply_run_stat_modifier(stat_id, operation, value)

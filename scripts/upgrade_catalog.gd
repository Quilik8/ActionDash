class_name ActionDashUpgradeCatalog
extends Resource

@export var cards: Array[ActionDashRunUpgrade] = []
@export var movement_tree: Array[ActionDashRunUpgrade] = []
@export var melee_tree: Array[ActionDashRunUpgrade] = []
@export var ranged_tree: Array[ActionDashRunUpgrade] = []

func get_tree_upgrades() -> Array[ActionDashRunUpgrade]:
	var result: Array[ActionDashRunUpgrade] = []
	result.append_array(movement_tree)
	result.append_array(melee_tree)
	result.append_array(ranged_tree)
	return result

func find_upgrade(upgrade_id: StringName) -> ActionDashRunUpgrade:
	for upgrade in cards:
		if upgrade.id == upgrade_id:
			return upgrade
	for upgrade in get_tree_upgrades():
		if upgrade.id == upgrade_id:
			return upgrade
	return null

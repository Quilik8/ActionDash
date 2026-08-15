class_name ActionDashSurfaceMiningEntry
extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mining_toggle"):
		get_viewport().set_input_as_handled()
		(get_node("/root/RunSession") as ActionDashRunState).call_deferred("enter_mining")

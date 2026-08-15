class_name ActionDashLooseOre
extends Node2D

var ore_id: StringName
var ore_data: ActionDashMiningOreData
var pickup_available_msec: int = 0

func setup(data: ActionDashMiningOreData, delay_seconds: float = 0.0) -> void:
	ore_data = data
	ore_id = data.id
	pickup_available_msec = Time.get_ticks_msec() + roundi(delay_seconds * 1000.0)
	add_to_group("mining_loose_ores")
	queue_redraw()

func can_be_picked_up() -> bool:
	return Time.get_ticks_msec() >= pickup_available_msec

func _draw() -> void:
	if ore_data == null:
		return
	draw_circle(Vector2.ZERO, 7.0, Color(0.04, 0.05, 0.07, 0.9))
	draw_circle(Vector2.ZERO, 5.0, ore_data.color)
	draw_line(Vector2(-3, -1), Vector2(2, -4), Color.WHITE, 1.5)

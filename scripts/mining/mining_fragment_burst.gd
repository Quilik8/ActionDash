class_name ActionDashMiningFragmentBurst
extends Node2D

const FRAGMENT_DIRECTIONS: Array[Vector2] = [Vector2(-1, -0.6), Vector2(1, -0.8), Vector2(-0.7, 0.4), Vector2(0.8, 0.5)]

var _color: Color
var _life: float = 0.28

func setup(color: Color) -> void:
	_color = color
	queue_redraw()

func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	var progress := 1.0 - _life / 0.28
	var alpha := clampf(_life / 0.28, 0.0, 1.0)
	for direction in FRAGMENT_DIRECTIONS:
		var fragment_position: Vector2 = direction * progress * 18.0
		draw_rect(Rect2(fragment_position - Vector2.ONE * 2.0, Vector2.ONE * 4.0), Color(_color, alpha))

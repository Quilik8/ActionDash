class_name ActionDashDebugOverlay
extends Label

@export var player_path: NodePath
@export var update_interval: float = 0.2

var _player: Node3D
var _timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_update_text()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = update_interval
		_update_text()

func _update_text() -> void:
	var current_speed := 0.0
	if is_instance_valid(_player):
		current_speed = Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	text = "ActionDash MVP\nWASF: W avanzar | A izquierda | S retroceder | F derecha\nSpace: saltar | Clic izquierdo: disparar\nFPS: %d   Velocidad: %.1f   Enemigos: %d" % [Engine.get_frames_per_second(), current_speed, get_tree().get_nodes_in_group("enemies").size()]

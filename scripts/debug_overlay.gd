class_name ActionDashDebugOverlay
extends Label

@export var player_path: NodePath
@export var update_interval: float = 0.2

var _player: ActionDashPlayer
var _timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as ActionDashPlayer
	_update_text()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = update_interval
		_update_text()

func _update_text() -> void:
	var current_speed := 0.0
	var weapon_text := ""
	if is_instance_valid(_player):
		current_speed = Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
		weapon_text = "   Pistola: %d / %d" % [_player.get_current_ammo(), _player.get_magazine_size()]
		if _player.is_reloading():
			weapon_text += "   RELOADING"
	var maximum_speed := _player.get_max_speed() if is_instance_valid(_player) else 0.0
	text = "ActionDash MVP\nWASF: W avanzar | A izquierda | S retroceder | F derecha\nSpace: saltar | Clic izquierdo: disparar\nFPS: %d   Velocidad: %.1f / %.1f   Enemigos: %d%s" % [Engine.get_frames_per_second(), current_speed, maximum_speed, get_tree().get_nodes_in_group("enemies").size(), weapon_text]

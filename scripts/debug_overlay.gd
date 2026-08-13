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
	var maximum_speed := 0.0
	var kinetic_active := false
	var kinetic_multiplier := 1.0
	var energy_status := "READY"
	if is_instance_valid(_player):
		current_speed = _player.get_horizontal_speed()
		maximum_speed = _player.get_max_speed()
		kinetic_active = _player.is_kinetic_max_active()
		kinetic_multiplier = _player.get_kinetic_damage_multiplier()
		if not _player.is_energy_ready():
			energy_status = "RELOADING %.1fs" % _player.get_energy_reload_remaining()
	text = "ActionDash MVP\nWASF: movimiento | Space: salto | Clic: esfera de energía\nFPS: %d   Velocidad: %.1f / %.1f   Enemigos: %d\nCinético máximo: %s   Multiplicador: x%.2f   Energía: %s" % [
		Engine.get_frames_per_second(),
		current_speed,
		maximum_speed,
		get_tree().get_nodes_in_group("enemies").size(),
		"ACTIVO" if kinetic_active else "INACTIVO",
		kinetic_multiplier,
		energy_status
	]

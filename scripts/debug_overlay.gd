class_name ActionDashDebugOverlay
extends Label

@export var player_path: NodePath
@export var phase_controller_path: NodePath
@export var update_interval: float = 0.2

var _player: ActionDashPlayer
var _phase_controller: ActionDashPhaseController
var _timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as ActionDashPlayer
	_phase_controller = get_node_or_null(phase_controller_path) as ActionDashPhaseController
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
	var active_enemies := get_tree().get_node_count_in_group("enemies")
	var remaining_enemies := _phase_controller.get_enemies_remaining() if is_instance_valid(_phase_controller) else active_enemies
	var frame_ms := 1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0)
	text = "ActionDash MVP\nWASF: movimiento | Space: salto | Clic: esfera de energía\nFPS: %d (%.2f ms)   Velocidad: %.1f / %.1f\nEnemigos activos: %d   Restantes: %d\nCinético máximo: %s   Multiplicador: x%.2f   Energía: %s" % [
		Engine.get_frames_per_second(),
		frame_ms,
		current_speed,
		maximum_speed,
		active_enemies,
		remaining_enemies,
		"ACTIVO" if kinetic_active else "INACTIVO",
		kinetic_multiplier,
		energy_status
	]

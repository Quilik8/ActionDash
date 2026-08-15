class_name ActionDashDebugOverlay
extends Label

@export var player_path: NodePath
@export var phase_controller_path: NodePath
@export var protected_core_path: NodePath
@export var update_interval: float = 0.2

var _player: ActionDashPlayer
var _phase_controller: ActionDashPhaseController
var _protected_core: ActionDashProtectedCore
var _timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as ActionDashPlayer
	_phase_controller = get_node_or_null(phase_controller_path) as ActionDashPhaseController
	_protected_core = get_node_or_null(protected_core_path) as ActionDashProtectedCore
	_update_text()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = update_interval
		_update_text()

func _update_text() -> void:
	var current_speed := 0.0
	var initial_speed := 18.0
	var maximum_speed := 36.0
	var acceleration := 34.0
	var melee_radius := 0.0
	var melee_knockback := 0.0
	if is_instance_valid(_player):
		current_speed = _player.get_horizontal_speed()
		initial_speed = _player.initial_speed
		maximum_speed = _player.max_speed
		acceleration = _player.acceleration
		melee_radius = _player.get_effective_melee_radius()
		melee_knockback = _player.get_current_melee_knockback_force()
	var active_enemies := get_tree().get_node_count_in_group("enemies")
	var remaining_enemies := _phase_controller.get_enemies_remaining() if is_instance_valid(_phase_controller) else active_enemies
	var core_integrity := _protected_core.get_integrity() if is_instance_valid(_protected_core) else 0.0
	var core_maximum := _protected_core.get_maximum_integrity() if is_instance_valid(_protected_core) else 0.0
	var frame_ms := 1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0)
	text = "ActionDash 3D Defense\nWASF: movimiento | MMB: orbitar | Space: salto | LMB: melee | RMB: ranged | M: Mining MVP\nFPS: %d (%.2f ms)\nVelocidad: %.1f / %.1f   Inicial: %.1f   Aceleración: %.1f\nKnockback melee: %.1f   Radio melee: %.1f\nNúcleo: %d / %d   Enemigos activos: %d   Restantes: %d" % [
		Engine.get_frames_per_second(),
		frame_ms,
		current_speed,
		maximum_speed,
		initial_speed,
		acceleration,
		melee_knockback,
		melee_radius,
		ceili(core_integrity),
		ceili(core_maximum),
		active_enemies,
		remaining_enemies
	]

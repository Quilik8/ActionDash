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
	var normal_speed := 18.0
	var super_max_speed := 36.0
	var movement_mode := "NORMAL"
	var kinetic_active := false
	var melee_radius := 0.0
	var landing_radius := 0.0
	var melee_knockback := 0.0
	if is_instance_valid(_player):
		current_speed = _player.get_horizontal_speed()
		normal_speed = _player.get_normal_speed()
		super_max_speed = _player.get_extraordinary_max_speed()
		movement_mode = _player.get_movement_mode_name()
		kinetic_active = _player.is_kinetic_max_active()
		melee_radius = _player.get_effective_melee_radius()
		landing_radius = _player.get_estimated_landing_radius()
		melee_knockback = _player.get_current_melee_knockback_force()
	var active_enemies := get_tree().get_node_count_in_group("enemies")
	var remaining_enemies := _phase_controller.get_enemies_remaining() if is_instance_valid(_phase_controller) else active_enemies
	var core_integrity := _protected_core.get_integrity() if is_instance_valid(_protected_core) else 0.0
	var core_maximum := _protected_core.get_maximum_integrity() if is_instance_valid(_protected_core) else 0.0
	var frame_ms := 1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0)
	var speed_detail := "Velocidad: %.1f   Normal fija: %.1f" % [current_speed, normal_speed]
	if movement_mode == "SUPER":
		speed_detail = "Velocidad: %.1f   Máxima SUPER: %.1f" % [current_speed, super_max_speed]
	text = "ActionDash 3D Defense\nWASF: movimiento | Q: SUPER ON/OFF | MMB: orbitar | Space: salto | Clic: melee\nFPS: %d (%.2f ms)   Modo: %s   SUPER: %s\n%s\nKnockback melee: %.1f   Radio melee: %.1f   Landing: %.1f\nNúcleo: %d / %d   Enemigos activos: %d   Restantes: %d\nCinético máximo: %s" % [
		Engine.get_frames_per_second(),
		frame_ms,
		movement_mode,
		"ON" if movement_mode == "SUPER" else "OFF",
		speed_detail,
		melee_knockback,
		melee_radius,
		landing_radius,
		ceili(core_integrity),
		ceili(core_maximum),
		active_enemies,
		remaining_enemies,
		"ACTIVO" if kinetic_active else "INACTIVO"
	]

class_name ActionDashSurfaceMiningEntry
extends Node

@export var player_path: NodePath = NodePath("../Player")
@export var protected_core_path: NodePath = NodePath("../ProtectedCore")
@export var run_ui_path: NodePath = NodePath("../RunUI")
@export var interaction_radius_bonus: float = 9.0

var _run_session: ActionDashRunState
var _player: ActionDashPlayer
var _protected_core: ActionDashProtectedCore
var _run_ui: ActionDashRunUI
var _confirmation_open: bool = false
var _inside_interaction_zone: bool = false
var _last_phase_state: int = -1

func _ready() -> void:
	_run_session = get_node("/root/RunSession") as ActionDashRunState
	_player = get_node(player_path) as ActionDashPlayer
	_protected_core = get_node(protected_core_path) as ActionDashProtectedCore
	_run_ui = get_node(run_ui_path) as ActionDashRunUI
	_run_ui.interaction_confirmed.connect(_confirm_enter_mining)
	_run_ui.interaction_cancelled.connect(_cancel_enter_mining)

func _process(_delta: float) -> void:
	var phase_state := _run_session.get_phase_state()
	if phase_state != _last_phase_state:
		_last_phase_state = phase_state
		_inside_interaction_zone = false
	if phase_state != ActionDashRunState.PhaseState.PREPARATION or _confirmation_open:
		if not _confirmation_open:
			_run_ui.hide_prompt()
		return
	var distance := _player.global_position.distance_to(_protected_core.global_position)
	var allowed_distance := _protected_core.get_approach_radius() + interaction_radius_bonus
	var inside := distance <= allowed_distance
	if inside == _inside_interaction_zone:
		return
	_inside_interaction_zone = inside
	if inside:
		_run_ui.show_prompt("BAJAR A LA MINA [E]")
	else:
		_run_ui.hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or _confirmation_open:
		return
	if _run_session.get_phase_state() != ActionDashRunState.PhaseState.PREPARATION or not _inside_interaction_zone:
		return
	get_viewport().set_input_as_handled()
	_confirmation_open = true
	_run_ui.show_interaction("¿BAJAR A LA MINA?", "BAJAR", "CANCELAR")

func _confirm_enter_mining() -> void:
	_confirmation_open = false
	if not _inside_interaction_zone:
		return
	_run_session.enter_mining()

func _cancel_enter_mining() -> void:
	_confirmation_open = false

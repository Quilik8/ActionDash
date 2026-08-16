class_name ActionDashPhaseController
extends Node

signal phase_started(phase_number: int)
signal phase_completed(phase_number: int)
signal run_defeated
signal macrozone_completed(macrozone_number: int)

enum RunState { PREPARATION, DEFENSE, REWARD, DEFEAT }

@export_category("Run data")
@export var phases: Array[ActionDashPhaseConfig] = []
@export var upgrade_catalog: ActionDashUpgradeCatalog
@export var skill_points_per_phase: int = 1
@export var phase_complete_message_duration: float = 0.65

@export_category("Scene references")
@export var player_path: NodePath
@export var spawner_path: NodePath
@export var run_ui_path: NodePath
@export var deterioration_path: NodePath
@export var protected_core_path: NodePath

var _state: RunState = RunState.PREPARATION
var _phase_index: int = 0
var _enemies_remaining: int = 0
var _time_remaining: float = 0.0
var _run_skill_points: int = 0
var _purchased_skills: Dictionary = {}
var _chosen_cards: Array[StringName] = []
var _current_card_choices: Array[ActionDashRunUpgrade] = []
var _run_session: ActionDashRunState

@onready var _player: ActionDashPlayer = get_node(player_path) as ActionDashPlayer
@onready var _spawner: ActionDashEnemySpawner = get_node(spawner_path) as ActionDashEnemySpawner
@onready var _run_ui: ActionDashRunUI = get_node(run_ui_path) as ActionDashRunUI
@onready var _deterioration: ActionDashEnvironmentDeterioration = get_node(deterioration_path) as ActionDashEnvironmentDeterioration
@onready var _protected_core: ActionDashProtectedCore = get_node(protected_core_path) as ActionDashProtectedCore

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_session = get_node("/root/RunSession") as ActionDashRunState
	_spawner.enemy_defeated.connect(_on_enemy_defeated)
	_protected_core.integrity_changed.connect(_on_core_integrity_changed)
	_protected_core.depleted.connect(_on_core_depleted)
	_run_ui.card_selected.connect(select_card)
	_run_ui.skill_selected.connect(purchase_skill)
	_run_ui.continue_requested.connect(continue_run)
	_run_ui.restart_requested.connect(restart_run)
	call_deferred("start_new_run")

func _process(delta: float) -> void:
	if _state != RunState.DEFENSE:
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_hud()
	var config := get_current_phase_config()
	_deterioration.update_time_ratio(_time_remaining / maxf(config.time_limit_seconds, 0.001))

func start_new_run() -> void:
	get_tree().paused = false
	_run_session.start_new_run()
	_phase_index = 0
	_run_skill_points = 0
	_purchased_skills.clear()
	_chosen_cards.clear()
	_player.restore_base_run_stats()
	_protected_core.reset_integrity()
	_spawner.clear_phase()
	_set_state(RunState.PREPARATION)
	_update_preparation_hud()

func select_card(upgrade_id: StringName) -> bool:
	if _state != RunState.REWARD:
		return false
	var selected: ActionDashRunUpgrade
	for upgrade in _current_card_choices:
		if upgrade.id == upgrade_id:
			selected = upgrade
			break
	if selected == null:
		return false
	selected.apply_to(_player)
	_chosen_cards.append(selected.id)
	_run_session.set_selected_card(selected.id)
	_phase_index = mini(_phase_index + 1, maxi(phases.size() - 1, 0))
	get_tree().paused = false
	_set_state(RunState.PREPARATION)
	_update_preparation_hud()
	_run_ui.hide_overlay()
	return true

func purchase_skill(upgrade_id: StringName) -> bool:
	if _run_skill_points <= 0 or _purchased_skills.has(upgrade_id):
		return false
	var upgrade := upgrade_catalog.find_upgrade(upgrade_id)
	if upgrade == null or upgrade.category == "Card":
		return false
	upgrade.apply_to(_player)
	_purchased_skills[upgrade_id] = true
	_run_skill_points -= 1
	_run_ui.show_skill_tree(upgrade_catalog, _run_skill_points, _purchased_skills)
	return true

func continue_run() -> bool:
	if _state != RunState.REWARD:
		return false
	return select_card(_current_card_choices[0].id) if not _current_card_choices.is_empty() else false

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func get_current_phase_config() -> ActionDashPhaseConfig:
	return phases[_phase_index]

func get_state() -> RunState:
	return _state

func begin_defense() -> bool:
	if _state != RunState.PREPARATION or _run_session.get_phase_state() != ActionDashRunState.PhaseState.DEFENSE:
		return false
	get_tree().paused = false
	_set_state(RunState.DEFENSE)
	call_deferred("_start_current_wave")
	return true

func get_enemies_remaining() -> int:
	return _enemies_remaining

func get_time_remaining() -> float:
	return _time_remaining

func get_core_integrity() -> float:
	return _protected_core.get_integrity() if is_instance_valid(_protected_core) else 0.0

func get_core_maximum_integrity() -> float:
	return _protected_core.get_maximum_integrity() if is_instance_valid(_protected_core) else 0.0

func get_run_skill_points() -> int:
	return _run_skill_points

func get_chosen_cards() -> Array[StringName]:
	return _chosen_cards.duplicate()

func get_current_card_choices() -> Array[StringName]:
	var result: Array[StringName] = []
	for card in _current_card_choices:
		result.append(card.id)
	return result

func get_purchased_skill_count() -> int:
	return _purchased_skills.size()

func _start_current_wave() -> void:
	if phases.is_empty() or _phase_index >= phases.size():
		return
	if _state != RunState.DEFENSE:
		return
	var config := get_current_phase_config()
	_run_session.set_wave_number(config.phase_number)
	_enemies_remaining = config.total_enemies
	_time_remaining = config.time_limit_seconds
	_deterioration.reset()
	_run_ui.hide_overlay()
	_spawner.start_phase(config)
	_update_defense_hud()
	phase_started.emit(config.phase_number)

func _on_enemy_defeated(_was_boss: bool) -> void:
	if _state != RunState.DEFENSE:
		return
	_enemies_remaining = maxi(_enemies_remaining - 1, 0)
	_update_hud()
	if _enemies_remaining <= 0:
		_complete_phase()

func _complete_phase() -> void:
	_set_state(RunState.REWARD)
	_spawner.clear_phase()
	_run_skill_points += skill_points_per_phase
	get_tree().paused = true
	var phase_number := get_current_phase_config().phase_number
	_run_ui.show_phase_complete(get_current_phase_config().display_name)
	phase_completed.emit(phase_number)
	await get_tree().create_timer(phase_complete_message_duration, true, false, true).timeout
	if _state == RunState.REWARD:
		_open_cards()

func _open_cards() -> void:
	if _state != RunState.REWARD:
		return
	_current_card_choices.clear()
	var start_index := (_phase_index * 2) % upgrade_catalog.cards.size()
	for offset in 3:
		_current_card_choices.append(upgrade_catalog.cards[(start_index + offset) % upgrade_catalog.cards.size()])
	_run_ui.show_cards(_current_card_choices)

func _defeat_run() -> void:
	if _state == RunState.DEFEAT:
		return
	_set_state(RunState.DEFEAT)
	_spawner.clear_phase()
	get_tree().paused = true
	_run_ui.show_defeat()
	run_defeated.emit()

func _update_hud() -> void:
	if phases.is_empty():
		return
	_update_defense_hud()

func _update_defense_hud() -> void:
	_run_ui.set_hud(
		"OLEADA %d" % get_current_phase_config().phase_number,
		_enemies_remaining,
		_time_remaining,
		get_core_integrity(),
		get_core_maximum_integrity()
	)

func _on_core_integrity_changed(_current: float, _maximum: float) -> void:
	_run_session.set_dome_integrity(_current, _maximum)
	_update_hud()

func _on_core_depleted() -> void:
	_defeat_run()

func _set_state(next_state: RunState) -> void:
	_state = next_state
	match next_state:
		RunState.PREPARATION:
			_run_session.set_phase_state(ActionDashRunState.PhaseState.PREPARATION)
		RunState.DEFENSE:
			_run_session.set_phase_state(ActionDashRunState.PhaseState.DEFENSE)
		RunState.REWARD:
			_run_session.set_phase_state(ActionDashRunState.PhaseState.REWARD)
		RunState.DEFEAT:
			_run_session.set_phase_state(ActionDashRunState.PhaseState.DEFEAT)

func _update_preparation_hud() -> void:
	_run_ui.set_hud("PREPARACIÓN", 0, 0.0, get_core_integrity(), get_core_maximum_integrity())

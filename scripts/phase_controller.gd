class_name ActionDashPhaseController
extends Node

signal phase_started(phase_number: int)
signal phase_completed(phase_number: int)
signal run_defeated
signal macrozone_completed(macrozone_number: int)

enum RunState { COMBAT, PHASE_COMPLETE, CARDS, SKILL_TREE, DEFEAT, MACROZONE_COMPLETE }

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

var _state: RunState = RunState.COMBAT
var _phase_index: int = 0
var _enemies_remaining: int = 0
var _time_remaining: float = 0.0
var _run_skill_points: int = 0
var _purchased_skills: Dictionary = {}
var _chosen_cards: Array[StringName] = []
var _current_card_choices: Array[ActionDashRunUpgrade] = []

@onready var _player: ActionDashPlayer = get_node(player_path) as ActionDashPlayer
@onready var _spawner: ActionDashEnemySpawner = get_node(spawner_path) as ActionDashEnemySpawner
@onready var _run_ui: ActionDashRunUI = get_node(run_ui_path) as ActionDashRunUI
@onready var _deterioration: ActionDashEnvironmentDeterioration = get_node(deterioration_path) as ActionDashEnvironmentDeterioration

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawner.enemy_defeated.connect(_on_enemy_defeated)
	_run_ui.card_selected.connect(select_card)
	_run_ui.skill_selected.connect(purchase_skill)
	_run_ui.continue_requested.connect(continue_run)
	_run_ui.restart_requested.connect(restart_run)
	call_deferred("start_new_run")

func _process(delta: float) -> void:
	if _state != RunState.COMBAT:
		return
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	_update_hud()
	var config := get_current_phase_config()
	_deterioration.update_time_ratio(_time_remaining / maxf(config.time_limit_seconds, 0.001))
	if _time_remaining <= 0.0 and _enemies_remaining > 0:
		_defeat_run()

func start_new_run() -> void:
	get_tree().paused = false
	_phase_index = 0
	_run_skill_points = 0
	_purchased_skills.clear()
	_chosen_cards.clear()
	_player.restore_base_run_stats()
	_start_current_phase()

func select_card(upgrade_id: StringName) -> bool:
	if _state != RunState.CARDS:
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
	_state = RunState.SKILL_TREE
	_run_ui.show_skill_tree(upgrade_catalog, _run_skill_points, _purchased_skills)
	return true

func purchase_skill(upgrade_id: StringName) -> bool:
	if _state != RunState.SKILL_TREE or _run_skill_points <= 0 or _purchased_skills.has(upgrade_id):
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
	if _state != RunState.SKILL_TREE:
		return false
	var completed_phase := get_current_phase_config()
	if completed_phase.phase_number % 3 == 0:
		_state = RunState.MACROZONE_COMPLETE
		_run_ui.show_macrozone_complete()
		macrozone_completed.emit(floori(float(completed_phase.phase_number) / 3.0))
		return true
	_phase_index += 1
	get_tree().paused = false
	_start_current_phase()
	return true

func restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func get_current_phase_config() -> ActionDashPhaseConfig:
	return phases[_phase_index]

func get_state() -> RunState:
	return _state

func get_enemies_remaining() -> int:
	return _enemies_remaining

func get_time_remaining() -> float:
	return _time_remaining

func get_run_skill_points() -> int:
	return _run_skill_points

func get_chosen_cards() -> Array[StringName]:
	return _chosen_cards.duplicate()

func get_purchased_skill_count() -> int:
	return _purchased_skills.size()

func _start_current_phase() -> void:
	if phases.is_empty() or _phase_index >= phases.size():
		return
	_state = RunState.COMBAT
	var config := get_current_phase_config()
	_enemies_remaining = config.total_enemies
	_time_remaining = config.time_limit_seconds
	_deterioration.reset()
	_run_ui.hide_overlay()
	_spawner.start_phase(config)
	_update_hud()
	phase_started.emit(config.phase_number)

func _on_enemy_defeated(_was_boss: bool) -> void:
	if _state != RunState.COMBAT:
		return
	_enemies_remaining = maxi(_enemies_remaining - 1, 0)
	_update_hud()
	if _enemies_remaining <= 0:
		_complete_phase()

func _complete_phase() -> void:
	_state = RunState.PHASE_COMPLETE
	_spawner.stop_phase()
	_run_skill_points += skill_points_per_phase
	get_tree().paused = true
	var phase_number := get_current_phase_config().phase_number
	_run_ui.show_phase_complete(get_current_phase_config().display_name)
	phase_completed.emit(phase_number)
	await get_tree().create_timer(phase_complete_message_duration, true, false, true).timeout
	if _state == RunState.PHASE_COMPLETE:
		_open_cards()

func _open_cards() -> void:
	_state = RunState.CARDS
	_current_card_choices.clear()
	var start_index := (_phase_index * 2) % upgrade_catalog.cards.size()
	for offset in 3:
		_current_card_choices.append(upgrade_catalog.cards[(start_index + offset) % upgrade_catalog.cards.size()])
	_run_ui.show_cards(_current_card_choices)

func _defeat_run() -> void:
	_state = RunState.DEFEAT
	_spawner.stop_phase()
	get_tree().paused = true
	_run_ui.show_defeat()
	run_defeated.emit()

func _update_hud() -> void:
	if phases.is_empty():
		return
	_run_ui.set_hud(get_current_phase_config().display_name, _enemies_remaining, _time_remaining)

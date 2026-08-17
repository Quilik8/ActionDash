class_name ActionDashRunState
extends Node

signal resources_changed(extracted_value: int, resources: Dictionary)
signal phase_state_changed(previous_state: PhaseState, current_state: PhaseState)
signal wave_changed(wave_number: int)
signal selected_card_changed(card_id: StringName)
signal preparation_started(duration_seconds: float)
signal preparation_time_changed(remaining_seconds: float)
signal preparation_expired

enum PhaseState {
	PREPARATION,
	MINING,
	DEFENSE,
	REWARD,
	DEFEAT,
}

const MINING_SCENE := preload("res://scenes/mining/mining_mvp.tscn")
const SURFACE_SCENE := preload("res://scenes/gameplay/playground.tscn")
const PREPARATION_DURATION_SECONDS: float = 150.0

var extracted_value: int = 0
var run_resources: Dictionary = {}
var mining_seed: int = 814271
var phase_state: PhaseState = PhaseState.PREPARATION
var wave_number: int = 1
var selected_card_id: StringName = &""
var dome_integrity: float = 4000.0
var dome_maximum_integrity: float = 4000.0
var preparation_time_remaining: float = PREPARATION_DURATION_SECONDS
var transition_in_progress: bool = false

var _surface_scene: Node
var _mining_scene: Node
var _surface_was_paused: bool = false
var _preparation_timer_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _preparation_timer_active:
		return
	if phase_state != PhaseState.PREPARATION and phase_state != PhaseState.MINING:
		return
	preparation_time_remaining = maxf(preparation_time_remaining - delta, 0.0)
	preparation_time_changed.emit(preparation_time_remaining)
	if preparation_time_remaining > 0.0:
		return
	_preparation_timer_active = false
	preparation_expired.emit()
	_activate_defense_from_grace()

func deposit_items(items: Array[StringName], ore_values: Dictionary) -> int:
	var deposited_value := 0
	for ore_id in items:
		run_resources[ore_id] = int(run_resources.get(ore_id, 0)) + 1
		deposited_value += int(ore_values.get(ore_id, 0))
	extracted_value += deposited_value
	resources_changed.emit(extracted_value, run_resources.duplicate())
	return deposited_value

func start_new_run() -> void:
	reset_mining_run()
	wave_number = 1
	selected_card_id = &""
	dome_integrity = 4000.0
	dome_maximum_integrity = 4000.0
	transition_in_progress = false
	start_preparation_cycle()
	resources_changed.emit(extracted_value, run_resources.duplicate())

func start_preparation_cycle() -> void:
	set_phase_state(PhaseState.PREPARATION)
	preparation_time_remaining = PREPARATION_DURATION_SECONDS
	_preparation_timer_active = true
	preparation_started.emit(PREPARATION_DURATION_SECONDS)
	preparation_time_changed.emit(preparation_time_remaining)

func set_phase_state(next_state: PhaseState) -> bool:
	if phase_state == next_state:
		return false
	var previous := phase_state
	phase_state = next_state
	phase_state_changed.emit(previous, phase_state)
	return true

func get_phase_state() -> PhaseState:
	return phase_state

func set_wave_number(next_wave: int) -> void:
	wave_number = maxi(next_wave, 1)
	wave_changed.emit(wave_number)

func set_selected_card(card_id: StringName) -> void:
	selected_card_id = card_id
	selected_card_changed.emit(card_id)

func set_dome_integrity(current: float, maximum: float) -> void:
	dome_integrity = current
	dome_maximum_integrity = maximum

func get_preparation_time_remaining() -> float:
	return preparation_time_remaining

func is_preparation_timer_active() -> bool:
	return _preparation_timer_active

func enter_mining() -> bool:
	var tree := get_tree()
	if transition_in_progress or phase_state != PhaseState.PREPARATION:
		return false
	if tree.current_scene == null or tree.current_scene == _mining_scene:
		return false
	_surface_scene = tree.current_scene
	_surface_was_paused = tree.paused
	transition_in_progress = true
	tree.paused = false
	tree.root.remove_child(_surface_scene)
	if not is_instance_valid(_mining_scene):
		_mining_scene = MINING_SCENE.instantiate()
	tree.root.add_child(_mining_scene)
	tree.current_scene = _mining_scene
	if _mining_scene.has_method("prepare_for_entry"):
		_mining_scene.call("prepare_for_entry")
	set_phase_state(PhaseState.MINING)
	transition_in_progress = false
	return true

func exit_mining() -> bool:
	return exit_mining_to_preparation()

func exit_mining_to_preparation() -> bool:
	var tree := get_tree()
	if transition_in_progress or phase_state != PhaseState.MINING:
		return false
	if not is_instance_valid(_surface_scene) or tree.current_scene != _mining_scene:
		return false
	transition_in_progress = true
	tree.root.remove_child(_mining_scene)
	tree.root.add_child(_surface_scene)
	tree.current_scene = _surface_scene
	tree.paused = _surface_was_paused
	set_phase_state(PhaseState.PREPARATION)
	transition_in_progress = false
	return true

func exit_mining_to_defense() -> bool:
	if phase_state != PhaseState.MINING or not is_preparation_timer_active():
		return false
	preparation_time_remaining = 0.0
	_preparation_timer_active = false
	_activate_defense_from_grace()
	return phase_state == PhaseState.DEFENSE

func _activate_defense_from_grace() -> void:
	if transition_in_progress or phase_state == PhaseState.DEFENSE or phase_state == PhaseState.REWARD:
		return
	var tree := get_tree()
	transition_in_progress = true
	tree.paused = false
	if tree.current_scene == _mining_scene:
		if is_instance_valid(_mining_scene) and _mining_scene.is_inside_tree():
			tree.root.remove_child(_mining_scene)
		if not is_instance_valid(_surface_scene):
			_surface_scene = SURFACE_SCENE.instantiate()
		tree.root.add_child(_surface_scene)
		tree.current_scene = _surface_scene
	set_phase_state(PhaseState.DEFENSE)
	transition_in_progress = false
	call_deferred("_begin_defense_after_transition")

func _begin_defense_after_transition() -> void:
	await get_tree().process_frame
	if phase_state != PhaseState.DEFENSE or not is_instance_valid(_surface_scene):
		return
	var phase_controller := _surface_scene.get_node_or_null("PhaseController")
	if phase_controller != null:
		phase_controller.call_deferred("begin_defense")

func reset_mining_run() -> void:
	reset_resources()
	if is_instance_valid(_mining_scene):
		if _mining_scene.is_inside_tree():
			_mining_scene.queue_free()
		else:
			_mining_scene.free()
	_mining_scene = null
	_surface_scene = null

func reset_resources() -> void:
	extracted_value = 0
	run_resources.clear()
	resources_changed.emit(extracted_value, run_resources.duplicate())

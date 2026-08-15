class_name ActionDashRunState
extends Node

signal resources_changed(extracted_value: int, resources: Dictionary)

const MINING_SCENE := preload("res://scenes/mining/mining_mvp.tscn")

var extracted_value: int = 0
var run_resources: Dictionary = {}
var mining_seed: int = 814271

var _surface_scene: Node
var _mining_scene: Node
var _surface_was_paused: bool = false

func deposit_items(items: Array[StringName], ore_values: Dictionary) -> int:
	var deposited_value := 0
	for ore_id in items:
		run_resources[ore_id] = int(run_resources.get(ore_id, 0)) + 1
		deposited_value += int(ore_values.get(ore_id, 0))
	extracted_value += deposited_value
	resources_changed.emit(extracted_value, run_resources.duplicate())
	return deposited_value

func enter_mining() -> bool:
	var tree := get_tree()
	if tree.current_scene == null or tree.current_scene == _mining_scene:
		return false
	_surface_scene = tree.current_scene
	_surface_was_paused = tree.paused
	tree.paused = false
	tree.root.remove_child(_surface_scene)
	if not is_instance_valid(_mining_scene):
		_mining_scene = MINING_SCENE.instantiate()
	tree.root.add_child(_mining_scene)
	tree.current_scene = _mining_scene
	return true

func exit_mining() -> bool:
	var tree := get_tree()
	if not is_instance_valid(_surface_scene) or tree.current_scene != _mining_scene:
		return false
	tree.root.remove_child(_mining_scene)
	tree.root.add_child(_surface_scene)
	tree.current_scene = _surface_scene
	tree.paused = _surface_was_paused
	return true

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

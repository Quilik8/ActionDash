class_name ActionDashMiningMVP
extends Node2D

@export var config: ActionDashMiningConfig

@onready var terrain: ActionDashMiningTerrain = $Terrain
@onready var mech: ActionDashMiningMech = $Mech
@onready var _depth_label: Label = $UI/HUD/Depth
@onready var _capacity_label: Label = $UI/HUD/Capacity
@onready var _state_label: Label = $UI/HUD/State
@onready var _cargo_value_label: Label = $UI/HUD/CargoValue
@onready var _run_value_label: Label = $UI/HUD/RunValue
@onready var _seed_label: Label = $UI/HUD/Seed
@onready var _notice_label: Label = $UI/HUD/Notice
@onready var _drill_progress: ProgressBar = $UI/HUD/DrillProgress

var _notice_time: float = 0.0
var _run_session: ActionDashRunState
var _loose_ores: Array[ActionDashLooseOre] = []
var _last_depth_cell := Vector2i(-9999, -9999)

func _ready() -> void:
	_run_session = get_node("/root/RunSession") as ActionDashRunState
	if not terrain.is_generated():
		terrain.generate(_run_session.mining_seed if _run_session.mining_seed != 0 else config.default_seed)
	terrain.block_broken.connect(_on_block_broken)
	mech.ore_ejected.connect(_on_ore_ejected)
	mech.cargo_changed.connect(_update_ui)
	mech.drilling_changed.connect(_on_drilling_changed)
	_run_session.resources_changed.connect(_on_run_resources_changed)
	set_physics_process(false)
	_update_ui()
	_show_notice("M: depositar/salir en la zona superior | E: expulsar último ore", 4.0)

func _physics_process(_delta: float) -> void:
	for index in range(_loose_ores.size() - 1, -1, -1):
		var loose := _loose_ores[index]
		if not is_instance_valid(loose):
			_loose_ores.remove_at(index)
			continue
		if not loose.can_be_picked_up():
			continue
		if mech.global_position.distance_to(loose.global_position) <= 20.0 and mech.try_absorb_ore(loose.ore_id):
			_show_notice("ABSORBIDO: %s" % loose.ore_data.display_name, 1.2)
			loose.queue_free()
			_loose_ores.remove_at(index)
	if _loose_ores.is_empty():
		set_physics_process(false)
	_update_depth()

func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time = maxf(_notice_time - delta, 0.0)
		if _notice_time <= 0.0:
			_notice_label.text = ""
			set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mining_toggle"):
		get_viewport().set_input_as_handled()
		if terrain.is_at_exit(mech.global_position):
			deposit_at_surface(true)
		else:
			_show_notice("REGRESA A LA ZONA SUPERIOR PARA DEPOSITAR Y SALIR", 2.0)

func deposit_at_surface(return_to_surface: bool = true) -> bool:
	if not terrain.is_at_exit(mech.global_position):
		return false
	var items := mech.get_cargo_stack()
	var values: Dictionary = {}
	for ore in config.ores:
		values[ore.id] = ore.value
	var deposited := _run_session.deposit_items(items, values)
	mech.clear_cargo()
	_show_notice("DEPÓSITO: +%d" % deposited, 1.0)
	if return_to_surface:
		_run_session.call_deferred("exit_mining")
	return true

func spawn_loose_ore(ore_id: StringName, world_position: Vector2, pickup_delay: float = 0.0) -> ActionDashLooseOre:
	var ore := config.get_ore(ore_id)
	if ore == null:
		return null
	var loose := ActionDashLooseOre.new()
	$LooseOres.add_child(loose)
	loose.global_position = terrain.find_nearest_open_position(world_position)
	loose.setup(ore, pickup_delay)
	_loose_ores.append(loose)
	set_physics_process(true)
	return loose

func _on_block_broken(_cell: Vector2i, _block_id: StringName, ore_id: StringName, world_position: Vector2, color: Color) -> void:
	var fragments := ActionDashMiningFragmentBurst.new()
	$Feedback.add_child(fragments)
	fragments.global_position = world_position
	fragments.setup(color)
	if not ore_id.is_empty():
		spawn_loose_ore(ore_id, world_position)

func _on_ore_ejected(ore_id: StringName, world_position: Vector2) -> void:
	var loose := spawn_loose_ore(ore_id, world_position, 0.65)
	if loose != null:
		_show_notice("EXPULSADO: %s" % loose.ore_data.display_name, 1.2)

func _on_drilling_changed(active: bool, progress: float) -> void:
	_drill_progress.visible = active
	_drill_progress.value = progress * 100.0

func _on_run_resources_changed(_value: int, _resources: Dictionary) -> void:
	_update_ui()

func _update_depth() -> void:
	var depth_cell := terrain.world_to_cell(mech.global_position)
	if depth_cell == _last_depth_cell:
		return
	_last_depth_cell = depth_cell
	_depth_label.text = "DEPTH: %d   LAYER: %d" % [terrain.get_depth_row(mech.global_position), terrain.get_layer_at(mech.global_position)]

func _update_ui() -> void:
	if not is_node_ready():
		return
	_capacity_label.text = "LOAD: %.0f / %.0f" % [mech.get_current_load(), config.capacity]
	_state_label.text = "STATE: %s   SPEED: %.0f" % [mech.get_load_state(), mech.get_current_speed()]
	_cargo_value_label.text = "CARGO VALUE: %d" % mech.get_cargo_value()
	_run_value_label.text = "RUN EXTRACTED VALUE: %d" % _run_session.extracted_value
	_seed_label.text = "SEED: %d" % terrain.generation_seed

func _show_notice(message: String, duration: float) -> void:
	_notice_label.text = message
	_notice_time = duration
	set_process(true)

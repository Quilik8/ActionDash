class_name ActionDashMiningMVP
extends Node2D

signal upgrades_requested

const BASE_ZONE_RADIUS: float = 30.0

@export var config: ActionDashMiningConfig

@onready var terrain: ActionDashMiningTerrain = $Terrain
@onready var mech: ActionDashMiningMech = $Mech
@onready var _depth_label: Label = $UI/HUD/Depth
@onready var _phase_state_label: Label = $UI/HUD/PhaseState
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
var _last_layer: int = 0
var _base_prompt_label: Label
var _interaction_panel: PanelContainer
var _interaction_label: Label
var _interaction_confirm: Button
var _interaction_cancel: Button
var _upgrades_panel: PanelContainer
var _upgrades_label: Label
var _modal_open: bool = false

func _ready() -> void:
	_run_session = get_node("/root/RunSession") as ActionDashRunState
	_create_base_ui()
	if not terrain.is_generated():
		terrain.generate(_run_session.mining_seed if _run_session.mining_seed != 0 else config.default_seed)
	if not terrain.block_broken.is_connected(_on_block_broken):
		terrain.block_broken.connect(_on_block_broken)
	if not terrain.ore_discovered.is_connected(_on_ore_discovered):
		terrain.ore_discovered.connect(_on_ore_discovered)
	mech.ore_ejected.connect(_on_ore_ejected)
	mech.cargo_changed.connect(_update_ui)
	mech.drilling_changed.connect(_on_drilling_changed)
	mech.cell_changed.connect(_on_mech_cell_changed)
	_run_session.resources_changed.connect(_on_run_resources_changed)
	set_physics_process(false)
	_update_ui()
	_update_depth()
	_update_base_prompt()
	_show_notice("Q: expulsar último ore | E: interactuar en la base", 4.0)

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
	if event.is_action_pressed("open_upgrades"):
		get_viewport().set_input_as_handled()
		if not _modal_open and _get_base_zone() == &"upgrades":
			_show_upgrades()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not _modal_open and _get_base_zone() == &"defender":
			_show_defender_confirmation()
		return
	if event.is_action_pressed("mining_toggle"):
		get_viewport().set_input_as_handled()
		_show_notice("USA DEFENDER CÚPULA [E] PARA REGRESAR", 2.0)

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

func _on_ore_discovered(ore_id: StringName, _world_position: Vector2, _color: Color) -> void:
	var ore := config.get_ore(ore_id)
	if ore != null:
		_show_notice("DESCUBIERTO: %s" % ore.display_name, 1.4)

func _on_ore_ejected(ore_id: StringName, world_position: Vector2) -> void:
	var loose := spawn_loose_ore(ore_id, world_position, 0.65)
	if loose != null:
		_show_notice("EXPULSADO: %s" % loose.ore_data.display_name, 1.2)

func _on_drilling_changed(active: bool, progress: float) -> void:
	_drill_progress.visible = active
	_drill_progress.value = progress * 100.0

func _on_run_resources_changed(_value: int, _resources: Dictionary) -> void:
	_update_ui()

func _on_mech_cell_changed(_cell: Vector2i) -> void:
	_update_depth()
	_update_base_prompt()

func _update_depth() -> void:
	var depth_cell := terrain.world_to_cell(mech.global_position)
	var layer := terrain.get_layer_at(mech.global_position)
	if depth_cell == _last_depth_cell and layer == _last_layer:
		return
	_last_depth_cell = depth_cell
	if _last_layer > 0 and layer != _last_layer:
		_show_notice("LAYER %d" % layer, 1.0)
	_last_layer = layer
	_depth_label.text = "DEPTH: %d   LAYER: %d" % [terrain.get_depth_row(mech.global_position), layer]

func _update_ui() -> void:
	if not is_node_ready():
		return
	_phase_state_label.text = "MINERÍA"
	_capacity_label.text = "LOAD: %.0f / %.0f" % [mech.get_current_load(), config.capacity]
	_state_label.text = "STATE: %s   SPEED: %.0f" % [mech.get_load_state(), mech.get_current_speed()]
	_cargo_value_label.text = "CARGO VALUE: %d" % mech.get_cargo_value()
	_run_value_label.text = "RUN EXTRACTED VALUE: %d" % _run_session.extracted_value
	_seed_label.text = "SEED: %d" % terrain.generation_seed
	if _upgrades_panel != null and _upgrades_panel.visible:
		_update_upgrades_text()

func _show_notice(message: String, duration: float) -> void:
	_notice_label.text = message
	_notice_time = duration
	set_process(true)

func _create_base_ui() -> void:
	_base_prompt_label = Label.new()
	_base_prompt_label.position = Vector2(430, 14)
	_base_prompt_label.size = Vector2(500, 54)
	_base_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_base_prompt_label.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0, 1.0))
	_base_prompt_label.add_theme_font_size_override("font_size", 18)
	$UI.add_child(_base_prompt_label)

	_interaction_panel = PanelContainer.new()
	_interaction_panel.position = Vector2(300, 170)
	_interaction_panel.size = Vector2(360, 112)
	_interaction_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.add_child(_interaction_panel)
	var interaction_layout := VBoxContainer.new()
	_interaction_panel.add_child(interaction_layout)
	_interaction_label = Label.new()
	_interaction_label.custom_minimum_size = Vector2(0, 48)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_layout.add_child(_interaction_label)
	var interaction_actions := HBoxContainer.new()
	interaction_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	interaction_layout.add_child(interaction_actions)
	_interaction_confirm = Button.new()
	_interaction_confirm.custom_minimum_size = Vector2(120, 32)
	_interaction_confirm.text = "DEFENDER"
	_interaction_confirm.pressed.connect(_confirm_defender)
	interaction_actions.add_child(_interaction_confirm)
	_interaction_cancel = Button.new()
	_interaction_cancel.custom_minimum_size = Vector2(120, 32)
	_interaction_cancel.text = "SEGUIR MINANDO"
	_interaction_cancel.pressed.connect(_close_mining_modal)
	interaction_actions.add_child(_interaction_cancel)

	_upgrades_panel = PanelContainer.new()
	_upgrades_panel.position = Vector2(300, 150)
	_upgrades_panel.size = Vector2(360, 150)
	_upgrades_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.add_child(_upgrades_panel)
	var upgrades_layout := VBoxContainer.new()
	_upgrades_panel.add_child(upgrades_layout)
	var upgrades_title := Label.new()
	upgrades_title.text = "MEJORAS"
	upgrades_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrades_title.add_theme_font_size_override("font_size", 22)
	upgrades_layout.add_child(upgrades_title)
	_upgrades_label = Label.new()
	_upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrades_layout.add_child(_upgrades_label)
	var close_upgrades := Button.new()
	close_upgrades.text = "CERRAR"
	close_upgrades.pressed.connect(_close_mining_modal)
	upgrades_layout.add_child(close_upgrades)
	_interaction_panel.visible = false
	_upgrades_panel.visible = false

func _get_base_zone() -> StringName:
	if not terrain.is_at_exit(mech.global_position):
		return &""
	var entry := terrain.get_entry_position()
	var offset := mech.global_position - entry
	if offset.distance_to(Vector2(-38.0, 0.0)) <= BASE_ZONE_RADIUS:
		return &"upgrades"
	if offset.distance_to(Vector2(38.0, 0.0)) <= BASE_ZONE_RADIUS:
		return &"defender"
	return &"center"

func _update_base_prompt() -> void:
	if _base_prompt_label == null or _modal_open:
		return
	match _get_base_zone():
		&"upgrades":
			_base_prompt_label.text = "BASE MINERA\nMEJORAS [U]"
		&"defender":
			_base_prompt_label.text = "BASE MINERA\nDEFENDER CÚPULA [E]"
		&"center":
			_base_prompt_label.text = "BASE MINERA\nve a MEJORAS o DEFENDER"
		_:
			_base_prompt_label.text = ""

func _show_defender_confirmation() -> void:
	_modal_open = true
	mech.set_physics_process(false)
	_interaction_label.text = "¿DEFENDER CÚPULA?\nCARGO: %d" % mech.get_cargo_value()
	_interaction_confirm.text = "DEFENDER"
	_interaction_cancel.text = "SEGUIR MINANDO"
	_interaction_panel.visible = true

func _confirm_defender() -> void:
	if not _modal_open or _get_base_zone() != &"defender":
		_close_mining_modal()
		return
	if not deposit_at_surface(false):
		_close_mining_modal()
		return
	_modal_open = false
	_interaction_panel.visible = false
	_run_session.exit_mining_to_defense()

func _show_upgrades() -> void:
	_modal_open = true
	mech.set_physics_process(false)
	_update_upgrades_text()
	_upgrades_panel.visible = true
	upgrades_requested.emit()

func _update_upgrades_text() -> void:
	if _upgrades_label == null:
		return
	var resource_lines: Array[String] = []
	for ore_id in _run_session.run_resources:
		resource_lines.append("%s: %d" % [String(ore_id).to_upper(), int(_run_session.run_resources[ore_id])])
	var summary := "\n".join(resource_lines) if not resource_lines.is_empty() else "SIN RECURSOS DEPOSITADOS"
	_upgrades_label.text = "%s\nVALOR EXTRAÍDO: %d\nTIENDA: POSPUESTA" % [summary, _run_session.extracted_value]

func _close_mining_modal() -> void:
	_modal_open = false
	_interaction_panel.visible = false
	_upgrades_panel.visible = false
	mech.set_physics_process(true)
	_update_base_prompt()

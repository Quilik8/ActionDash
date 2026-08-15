class_name ActionDashMiningMech
extends Node2D

signal cargo_changed
signal ore_ejected(ore_id: StringName, world_position: Vector2)
signal drilling_changed(active: bool, progress: float)

@export var config: ActionDashMiningConfig
@export var terrain_path: NodePath
@export var head_radius: float = 9.0
@export var segment_count: int = 5
@export var segment_spacing: float = 17.0

var _terrain: ActionDashMiningTerrain
var _cargo_stack: Array[StringName] = []
var _current_load: float = 0.0
var _last_direction: Vector2 = Vector2.DOWN
var _history: Array[Vector2] = []
var _drilling: bool = false
var _drill_cell := Vector2i(-1, -1)
var _drill_visual_time: float = 0.0

func _ready() -> void:
	_terrain = get_node(terrain_path) as ActionDashMiningTerrain
	position = _terrain.get_entry_position()
	for _index in 90:
		_history.append(global_position)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := input.normalized() if input.length_squared() > 0.01 else Vector2.ZERO
	var was_drilling := _drilling
	_drilling = false
	if direction != Vector2.ZERO:
		_last_direction = direction
		var travel := direction * get_current_speed() * delta
		var probe := global_position + direction * (head_radius + maxf(travel.length(), 2.0))
		var target_cell := _terrain.world_to_cell(probe)
		if _terrain.is_solid_cell(target_cell):
			_drilling = true
			_drill_cell = target_cell
			_drill_visual_time += delta * 34.0
			_terrain.drill_cell(target_cell, config.drill_power * delta)
		else:
			global_position += travel
			global_position.y = maxf(global_position.y, -config.cell_size)
			_record_history()
	if _drilling:
		drilling_changed.emit(true, 1.0 - _terrain.get_cell_health_ratio(_drill_cell))
	elif was_drilling:
		drilling_changed.emit(false, 0.0)
	if Input.is_action_just_pressed("mining_eject"):
		eject_last_ore()
	if _drilling or was_drilling:
		queue_redraw()

func try_absorb_ore(ore_id: StringName) -> bool:
	var ore := config.get_ore(ore_id)
	if ore == null or _current_load + ore.weight > config.capacity + 0.001:
		return false
	_cargo_stack.append(ore_id)
	_current_load += ore.weight
	cargo_changed.emit()
	return true

func eject_last_ore() -> StringName:
	if _cargo_stack.is_empty():
		return &""
	var ore_id: StringName = _cargo_stack.pop_back()
	var ore := config.get_ore(ore_id)
	_current_load = maxf(_current_load - ore.weight, 0.0)
	var preferred := global_position - _last_direction * (head_radius + config.cell_size * 0.75)
	var eject_position := _terrain.find_nearest_open_position(preferred)
	ore_ejected.emit(ore_id, eject_position)
	cargo_changed.emit()
	return ore_id

func clear_cargo() -> void:
	_cargo_stack.clear()
	_current_load = 0.0
	cargo_changed.emit()

func get_cargo_stack() -> Array[StringName]:
	return _cargo_stack.duplicate()

func get_current_load() -> float:
	return _current_load

func get_load_ratio() -> float:
	return clampf(_current_load / maxf(config.capacity, 0.001), 0.0, 1.0)

func get_load_state() -> StringName:
	var ratio := get_load_ratio()
	if _current_load <= 0.001:
		return &"EMPTY"
	if ratio >= 0.999:
		return &"FULL"
	if ratio <= config.light_max_ratio:
		return &"LIGHT"
	return &"HEAVY"

func get_current_speed() -> float:
	return config.base_speed * (1.0 - config.maximum_load_speed_penalty * get_load_ratio())

func get_cargo_value() -> int:
	var result := 0
	for ore_id in _cargo_stack:
		var ore := config.get_ore(ore_id)
		result += ore.value if ore != null else 0
	return result

func get_last_direction() -> Vector2:
	return _last_direction

func _record_history() -> void:
	if _history.is_empty() or _history[0].distance_to(global_position) >= 3.0:
		_history.push_front(global_position)
		if _history.size() > 120:
			_history.resize(120)

func _get_segment_position(index: int) -> Vector2:
	var desired_distance := float(index + 1) * segment_spacing
	var accumulated := 0.0
	var previous := global_position
	for point in _history:
		accumulated += previous.distance_to(point)
		if accumulated >= desired_distance:
			return to_local(point)
		previous = point
	return to_local(_history[-1]) if not _history.is_empty() else Vector2.ZERO

func _draw() -> void:
	for index in range(segment_count - 1, -1, -1):
		var segment_position := _get_segment_position(index)
		var radius := lerpf(6.0, 8.0, 1.0 - float(index) / maxf(float(segment_count), 1.0))
		draw_circle(segment_position, radius, Color(0.16, 0.34, 0.42))
		draw_circle(segment_position, radius - 2.0, Color(0.22, 0.62, 0.68))
	var shake := Vector2(sin(_drill_visual_time), cos(_drill_visual_time * 1.37)) * (1.8 if _drilling else 0.0)
	draw_circle(shake, head_radius + 3.0, Color(0.06, 0.12, 0.16))
	draw_circle(shake, head_radius, Color(0.25, 0.82, 0.88))
	var drill_tip := shake + _last_direction * 14.0
	var perpendicular := _last_direction.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([drill_tip + _last_direction * 7.0, drill_tip + perpendicular, drill_tip - perpendicular]), Color(1.0, 0.58, 0.12))

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
var _segment_positions_global: Array[Vector2] = []
var _segment_visuals: Array[Polygon2D] = []
var _head_shadow: Polygon2D
var _head_visual: Polygon2D
var _drill_visual: Polygon2D
var _drilling: bool = false
var _drill_cell := Vector2i(-1, -1)
var _drill_visual_time: float = 0.0

func _ready() -> void:
	_terrain = get_node(terrain_path) as ActionDashMiningTerrain
	position = _terrain.get_entry_position()
	for _index in 90:
		_history.append(global_position)
	_update_segment_cache()
	_create_visuals()
	_update_visual_positions()

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
	_update_visual_positions()

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
		_update_segment_cache()

func _update_segment_cache() -> void:
	_segment_positions_global.clear()
	for index in segment_count:
		_segment_positions_global.append(_calculate_segment_position(index))

func _calculate_segment_position(index: int) -> Vector2:
	var desired_distance := float(index + 1) * segment_spacing
	var accumulated := 0.0
	var previous := global_position
	for point in _history:
		accumulated += previous.distance_to(point)
		if accumulated >= desired_distance:
			return point
		previous = point
	return _history[-1] if not _history.is_empty() else global_position

func _create_visuals() -> void:
	for index in segment_count:
		var radius := lerpf(6.0, 8.0, 1.0 - float(index) / maxf(float(segment_count), 1.0))
		var segment := Polygon2D.new()
		segment.name = "Segment%d" % index
		segment.polygon = _circle_polygon(radius)
		segment.color = Color(0.22, 0.62, 0.68)
		add_child(segment)
		_segment_visuals.append(segment)
	_head_shadow = Polygon2D.new()
	_head_shadow.name = "HeadShadow"
	_head_shadow.polygon = _circle_polygon(head_radius + 3.0)
	_head_shadow.color = Color(0.06, 0.12, 0.16)
	add_child(_head_shadow)
	_head_visual = Polygon2D.new()
	_head_visual.name = "Head"
	_head_visual.polygon = _circle_polygon(head_radius)
	_head_visual.color = Color(0.25, 0.82, 0.88)
	add_child(_head_visual)
	_drill_visual = Polygon2D.new()
	_drill_visual.name = "Drill"
	_drill_visual.polygon = PackedVector2Array([Vector2(21.0, 0.0), Vector2(14.0, 5.0), Vector2(14.0, -5.0)])
	_drill_visual.color = Color(1.0, 0.58, 0.12)
	add_child(_drill_visual)

func _update_visual_positions() -> void:
	for index in _segment_visuals.size():
		if index < _segment_positions_global.size():
			_segment_visuals[index].position = to_local(_segment_positions_global[index])
	var shake := Vector2(sin(_drill_visual_time), cos(_drill_visual_time * 1.37)) * (1.8 if _drilling else 0.0)
	_head_shadow.position = shake
	_head_visual.position = shake
	_drill_visual.position = shake
	_drill_visual.rotation = _last_direction.angle()

func _circle_polygon(radius: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in 12:
		var angle := TAU * float(index) / 12.0
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon

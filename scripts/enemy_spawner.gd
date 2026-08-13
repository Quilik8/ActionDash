class_name ActionDashEnemySpawner
extends Node3D

@export_category("Scenes")
@export var enemy_scene: PackedScene
@export var flying_enemy_scene: PackedScene

@export_category("Population")
@export var total_enemy_count: int = 42
@export var flying_enemy_count: int = 6
@export var respawn_interval: float = 2.0

@export_category("Groups")
@export var group_count: int = 6
@export var minimum_enemies_per_group: int = 5
@export var maximum_enemies_per_group: int = 8
@export var group_spread_radius: float = 7.0
@export var minimum_group_center_distance: float = 38.0
@export var spawn_area_half_extents: Vector2 = Vector2(125.0, 95.0)
@export var center_safe_radius: float = 20.0
@export var deterministic_seed: int = 1337

@export_category("Flying enemies")
@export var flying_spawn_height: float = 7.0
@export var flying_group_spread: float = 9.0

var _spawn_timer: float = 0.0
var _random := RandomNumberGenerator.new()
var _group_centers: Array[Vector3] = []

func _ready() -> void:
	_random.seed = deterministic_seed
	_create_group_centers()
	_spawn_initial_population()

func _process(delta: float) -> void:
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _spawn_timer > 0.0:
		return
	_spawn_timer = respawn_interval
	_replenish_population()

func get_group_centers() -> Array[Vector3]:
	return _group_centers.duplicate()

func _create_group_centers() -> void:
	_group_centers.clear()
	var desired_count := maxi(group_count, 1)
	for group_index in desired_count:
		var candidate := Vector3.ZERO
		var accepted := false
		for _attempt in 120:
			candidate = Vector3(
				_random.randf_range(-spawn_area_half_extents.x, spawn_area_half_extents.x),
				0.0,
				_random.randf_range(-spawn_area_half_extents.y, spawn_area_half_extents.y)
			)
			if Vector2(candidate.x, candidate.z).length() < center_safe_radius:
				continue
			if _is_far_enough_from_centers(candidate):
				accepted = true
				break
		if not accepted:
			var angle := TAU * float(group_index) / float(desired_count)
			var fallback_radius := minf(spawn_area_half_extents.x, spawn_area_half_extents.y) * 0.72
			candidate = Vector3(cos(angle), 0.0, sin(angle)) * fallback_radius
		_group_centers.append(candidate)

func _is_far_enough_from_centers(candidate: Vector3) -> bool:
	for center in _group_centers:
		if candidate.distance_to(center) < minimum_group_center_distance:
			return false
	return true

func _spawn_initial_population() -> void:
	var ground_total := maxi(total_enemy_count - flying_enemy_count, 0)
	var group_sizes := _calculate_group_sizes(ground_total)
	for group_index in group_sizes.size():
		for _enemy_index in group_sizes[group_index]:
			_spawn_ground_enemy(group_index)
	for flying_index in mini(flying_enemy_count, total_enemy_count):
		_spawn_flying_enemy(flying_index % _group_centers.size())

func _calculate_group_sizes(ground_total: int) -> Array[int]:
	var sizes: Array[int] = []
	var count := _group_centers.size()
	if count == 0:
		return sizes
	var remaining := ground_total
	for group_index in count:
		var groups_left := count - group_index
		var minimum_here := mini(minimum_enemies_per_group, remaining)
		var maximum_here := mini(maximum_enemies_per_group, remaining)
		var ideal := ceili(float(remaining) / float(groups_left))
		var group_size := clampi(ideal, minimum_here, maximum_here)
		sizes.append(group_size)
		remaining -= group_size
	# Inspector totals remain authoritative even if they exceed configured group-size guidance.
	var cursor := 0
	while remaining > 0:
		sizes[cursor % count] += 1
		remaining -= 1
		cursor += 1
	return sizes

func _replenish_population() -> void:
	var desired_flying := mini(flying_enemy_count, total_enemy_count)
	var desired_ground := maxi(total_enemy_count - desired_flying, 0)
	var current_ground := get_tree().get_nodes_in_group("ground_enemies").size()
	var current_flying := get_tree().get_nodes_in_group("flying_enemies").size()
	if current_ground < desired_ground:
		_spawn_ground_enemy(_least_populated_group("ground_enemies"))
	elif current_flying < desired_flying:
		_spawn_flying_enemy(_least_populated_group("flying_enemies"))

func _least_populated_group(group_name: StringName) -> int:
	var counts: Array[int] = []
	counts.resize(_group_centers.size())
	counts.fill(0)
	for enemy in get_tree().get_nodes_in_group(group_name):
		var index := int(enemy.get_meta("spawn_group", 0))
		if index >= 0 and index < counts.size():
			counts[index] += 1
	var best_index := 0
	for index in counts.size():
		if counts[index] < counts[best_index]:
			best_index = index
	return best_index

func _spawn_ground_enemy(group_index: int) -> void:
	if enemy_scene == null or _group_centers.is_empty():
		return
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	var home := _random_point_around(_group_centers[group_index], group_spread_radius)
	enemy.global_position = home
	enemy.set_meta("spawn_group", group_index)
	enemy.initialize(home)

func _spawn_flying_enemy(group_index: int) -> void:
	if flying_enemy_scene == null or _group_centers.is_empty():
		return
	var enemy := flying_enemy_scene.instantiate()
	add_child(enemy)
	var home := _random_point_around(_group_centers[group_index], flying_group_spread)
	home.y = flying_spawn_height
	enemy.global_position = home
	enemy.set_meta("spawn_group", group_index)
	enemy.initialize(home)

func _random_point_around(center: Vector3, radius: float) -> Vector3:
	var angle := _random.randf_range(0.0, TAU)
	var distance := sqrt(_random.randf()) * radius
	return center + Vector3(cos(angle), 0.0, sin(angle)) * distance

class_name ActionDashEnemySpawner
extends Node3D

signal enemy_defeated(was_boss: bool)

@export_category("Scenes")
@export var enemy_scene: PackedScene
@export var flying_enemy_scene: PackedScene

@export_category("Spawn area")
@export var spawn_area_half_extents: Vector2 = Vector2(125.0, 95.0)
@export var center_safe_radius: float = 20.0
@export var flying_spawn_height: float = 7.0
@export var deterministic_seed: int = 1337

var _phase_config: ActionDashPhaseConfig
var _spawn_timer: float = 0.0
var _pending_ground: int = 0
var _pending_flying: int = 0
var _boss_pending: bool = false
var _maximum_active: int = 0
var _spawn_group_cursor: int = 0
var _ground_visual_cursor: int = 0
var _random := RandomNumberGenerator.new()
var _group_centers: Array[Vector3] = []
var _active_ground: Array[ActionDashEnemy] = []
var _active_flying: Array[ActionDashFlyingEnemy] = []
var _ground_pool: Array[ActionDashEnemy] = []
var _flying_pool: Array[ActionDashFlyingEnemy] = []
var _active_boss: ActionDashBoss
var _lod_batch_timer: float = 0.0
var _ground_lod_batch: MultiMeshInstance3D
var _flying_lod_batch: MultiMeshInstance3D

func _ready() -> void:
	_random.seed = deterministic_seed
	_create_lod_batches()
	set_process(false)

func _process(delta: float) -> void:
	_lod_batch_timer = maxf(_lod_batch_timer - delta, 0.0)
	if _lod_batch_timer <= 0.0:
		_lod_batch_timer = 0.1
		_update_lod_batches()
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _spawn_timer <= 0.0 and get_active_count() < _maximum_active and get_pending_count() > 0:
		_spawn_one_pending()
		_spawn_timer = _phase_config.spawn_interval

func start_phase(config: ActionDashPhaseConfig) -> void:
	clear_phase()
	_phase_config = config
	_maximum_active = config.maximum_active_enemies
	_random.seed = deterministic_seed + config.phase_number * 101
	_ground_visual_cursor = 0
	_create_group_centers(config.group_count, config.minimum_group_center_distance)
	var normal_total := config.total_enemies - (1 if config.contains_boss else 0)
	_pending_flying = clampi(roundi(normal_total * config.flying_enemy_ratio), 0, normal_total)
	_pending_ground = normal_total - _pending_flying
	_boss_pending = config.contains_boss
	_spawn_timer = 0.0
	set_process(true)
	while get_active_count() < _maximum_active and get_pending_count() > 0:
		_spawn_one_pending()
	_update_lod_batches()

func stop_phase() -> void:
	set_process(false)

func clear_phase() -> void:
	set_process(false)
	for enemy in _active_ground.duplicate():
		_recycle_ground(enemy)
	for enemy in _active_flying.duplicate():
		_recycle_flying(enemy)
	if is_instance_valid(_active_boss):
		_active_boss.queue_free()
	_active_boss = null
	_pending_ground = 0
	_pending_flying = 0
	_boss_pending = false
	_group_centers.clear()
	_update_lod_batches()

func get_active_count() -> int:
	return _active_ground.size() + _active_flying.size() + (1 if is_instance_valid(_active_boss) and _active_boss.visible else 0)

func get_pending_count() -> int:
	return _pending_ground + _pending_flying + (1 if _boss_pending else 0)

func get_pool_size() -> int:
	return _ground_pool.size() + _flying_pool.size()

func get_group_centers() -> Array[Vector3]:
	return _group_centers.duplicate()

func get_active_boss() -> ActionDashBoss:
	return _active_boss

func _spawn_one_pending() -> void:
	if _boss_pending:
		_spawn_boss()
		return
	# Alternate types when possible so flying targets remain represented throughout a phase.
	if _pending_flying > 0 and (_pending_ground <= 0 or (_spawn_group_cursor % 4 == 0)):
		_spawn_flying_enemy()
	elif _pending_ground > 0:
		_spawn_ground_enemy()
	elif _pending_flying > 0:
		_spawn_flying_enemy()

func _spawn_ground_enemy() -> void:
	if enemy_scene == null or _group_centers.is_empty():
		return
	var enemy: ActionDashEnemy
	if _ground_pool.is_empty():
		enemy = enemy_scene.instantiate() as ActionDashEnemy
		add_child(enemy)
		enemy.died.connect(_on_ground_enemy_died.bind(enemy))
	else:
		enemy = _ground_pool.pop_back()
	var group_index := _next_group_index()
	var visual_variant: StringName = &"skeleton"
	if _ground_visual_cursor % 10 == 7:
		visual_variant = &"spider"
	elif _ground_visual_cursor % 3 == 2:
		visual_variant = &"slime"
	_ground_visual_cursor += 1
	enemy.configure_visual(visual_variant)
	var home := _random_point_around(_group_centers[group_index], _phase_config.group_spread_radius)
	enemy.set_meta("spawn_group", group_index)
	enemy.activate(home)
	_active_ground.append(enemy)
	_pending_ground -= 1

func _spawn_flying_enemy() -> void:
	if flying_enemy_scene == null or _group_centers.is_empty():
		return
	var enemy: ActionDashFlyingEnemy
	if _flying_pool.is_empty():
		enemy = flying_enemy_scene.instantiate() as ActionDashFlyingEnemy
		add_child(enemy)
		enemy.died.connect(_on_flying_enemy_died.bind(enemy))
	else:
		enemy = _flying_pool.pop_back()
	var group_index := _next_group_index()
	var home := _random_point_around(_group_centers[group_index], _phase_config.group_spread_radius + 2.0)
	home.y = flying_spawn_height
	enemy.set_meta("spawn_group", group_index)
	enemy.activate(home)
	_active_flying.append(enemy)
	_pending_flying -= 1

func _spawn_boss() -> void:
	if _phase_config.boss_scene == null:
		_boss_pending = false
		return
	_active_boss = _phase_config.boss_scene.instantiate() as ActionDashBoss
	add_child(_active_boss)
	var home := _group_centers[0] if not _group_centers.is_empty() else Vector3(0, 0, -55)
	_active_boss.initialize(home)
	_active_boss.died.connect(_on_boss_died.bind(_active_boss))
	_boss_pending = false

func _on_ground_enemy_died(enemy: ActionDashEnemy) -> void:
	if not _active_ground.has(enemy):
		return
	_recycle_ground(enemy)
	enemy_defeated.emit(false)

func _on_flying_enemy_died(enemy: ActionDashFlyingEnemy) -> void:
	if not _active_flying.has(enemy):
		return
	_recycle_flying(enemy)
	enemy_defeated.emit(false)

func _on_boss_died(boss: ActionDashBoss) -> void:
	if boss != _active_boss:
		return
	_active_boss = null
	boss.queue_free()
	enemy_defeated.emit(true)

func _recycle_ground(enemy: ActionDashEnemy) -> void:
	_active_ground.erase(enemy)
	enemy.deactivate()
	if not _ground_pool.has(enemy):
		_ground_pool.append(enemy)

func _recycle_flying(enemy: ActionDashFlyingEnemy) -> void:
	_active_flying.erase(enemy)
	enemy.deactivate()
	if not _flying_pool.has(enemy):
		_flying_pool.append(enemy)

func _next_group_index() -> int:
	var index := _spawn_group_cursor % _group_centers.size()
	_spawn_group_cursor += 1
	return index

func _create_group_centers(group_count: int, minimum_distance: float) -> void:
	_group_centers.clear()
	_spawn_group_cursor = 0
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
			if _is_far_enough(candidate, minimum_distance):
				accepted = true
				break
		if not accepted:
			var angle := TAU * float(group_index) / float(desired_count)
			candidate = Vector3(cos(angle), 0.0, sin(angle)) * minf(spawn_area_half_extents.x, spawn_area_half_extents.y) * 0.72
		_group_centers.append(candidate)

func _is_far_enough(candidate: Vector3, minimum_distance: float) -> bool:
	for center in _group_centers:
		if candidate.distance_to(center) < minimum_distance:
			return false
	return true

func _random_point_around(center: Vector3, radius: float) -> Vector3:
	var angle := _random.randf_range(0.0, TAU)
	var distance := sqrt(_random.randf()) * radius
	return center + Vector3(cos(angle), 0.0, sin(angle)) * distance

func _create_lod_batches() -> void:
	_ground_lod_batch = MultiMeshInstance3D.new()
	_ground_lod_batch.name = "GroundEnemyLODBatch"
	_ground_lod_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_lod_batch.multimesh = MultiMesh.new()
	_ground_lod_batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var ground_mesh := CapsuleMesh.new()
	ground_mesh.radius = 0.5
	ground_mesh.height = 1.7
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.85, 0.22, 0.2)
	ground_material.roughness = 0.8
	ground_mesh.material = ground_material
	_ground_lod_batch.multimesh.mesh = ground_mesh
	add_child(_ground_lod_batch)

	_flying_lod_batch = MultiMeshInstance3D.new()
	_flying_lod_batch.name = "FlyingEnemyLODBatch"
	_flying_lod_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flying_lod_batch.multimesh = MultiMesh.new()
	_flying_lod_batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var flying_mesh := SphereMesh.new()
	flying_mesh.radius = 0.75
	flying_mesh.height = 1.5
	var flying_material := StandardMaterial3D.new()
	flying_material.albedo_color = Color(0.28, 0.78, 0.92)
	flying_material.emission_enabled = true
	flying_material.emission = Color(0.04, 0.18, 0.24)
	flying_mesh.material = flying_material
	_flying_lod_batch.multimesh.mesh = flying_mesh
	add_child(_flying_lod_batch)

func _update_lod_batches() -> void:
	if not is_instance_valid(_ground_lod_batch) or not is_instance_valid(_flying_lod_batch):
		return
	var ground_transforms: Array[Transform3D] = []
	for enemy in _active_ground:
		if is_instance_valid(enemy) and enemy.is_using_simplified_lod():
			ground_transforms.append(enemy.get_simplified_lod_transform())
	_set_batch_transforms(_ground_lod_batch.multimesh, ground_transforms)
	var flying_transforms: Array[Transform3D] = []
	for enemy in _active_flying:
		if is_instance_valid(enemy) and enemy.is_using_simplified_lod():
			flying_transforms.append(enemy.get_simplified_lod_transform())
	_set_batch_transforms(_flying_lod_batch.multimesh, flying_transforms)

func _set_batch_transforms(multimesh: MultiMesh, transforms: Array[Transform3D]) -> void:
	if multimesh.instance_count < transforms.size():
		multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])

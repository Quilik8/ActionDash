class_name ActionDashEnemySpawner
extends Node3D

@export_category("Spawner")
@export var enemy_scene: PackedScene
@export var flying_enemy_scene: PackedScene
@export var player_path: NodePath
@export var initial_spawn_count: int = 4
@export var maximum_enemies: int = 6
@export var initial_flying_count: int = 2
@export var maximum_flying_enemies: int = 2
@export var spawn_interval: float = 1.5
@export var minimum_distance: float = 7.0
@export var maximum_distance: float = 12.0
@export var flying_spawn_height: float = 7.0
@export var flying_minimum_distance: float = 12.0
@export var flying_maximum_distance: float = 22.0

var _player: Node3D
var _spawn_timer: float = 0.0
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	_player = get_node_or_null(player_path) as Node3D
	for index in range(mini(initial_spawn_count, maximum_enemies)):
		_spawn_enemy()
	for index in range(mini(initial_flying_count, maximum_flying_enemies)):
		_spawn_flying_enemy()

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if get_tree().get_nodes_in_group("ground_enemies").size() < maximum_enemies:
		_spawn_enemy()
	elif get_tree().get_nodes_in_group("flying_enemies").size() < maximum_flying_enemies:
		_spawn_flying_enemy()

func _spawn_enemy() -> void:
	if enemy_scene == null or not is_instance_valid(_player):
		return
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	var angle := _random.randf_range(0.0, TAU)
	var distance := _random.randf_range(minimum_distance, maximum_distance)
	enemy.global_position = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	enemy.initialize(_player)

func _spawn_flying_enemy() -> void:
	if flying_enemy_scene == null or not is_instance_valid(_player):
		return
	var enemy := flying_enemy_scene.instantiate()
	add_child(enemy)
	var angle := _random.randf_range(0.0, TAU)
	var distance := _random.randf_range(flying_minimum_distance, flying_maximum_distance)
	enemy.global_position = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	enemy.global_position.y = _player.global_position.y + flying_spawn_height
	enemy.initialize(_player)

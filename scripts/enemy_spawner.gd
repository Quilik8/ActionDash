class_name ActionDashEnemySpawner
extends Node3D

@export_category("Spawner")
@export var enemy_scene: PackedScene
@export var player_path: NodePath
@export var initial_spawn_count: int = 4
@export var maximum_enemies: int = 6
@export var spawn_interval: float = 1.5
@export var minimum_distance: float = 7.0
@export var maximum_distance: float = 12.0

var _player: Node3D
var _spawn_timer: float = 0.0
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	_player = get_node_or_null(player_path) as Node3D
	for index in range(mini(initial_spawn_count, maximum_enemies)):
		_spawn_enemy()

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if get_tree().get_nodes_in_group("enemies").size() < maximum_enemies:
		_spawn_enemy()

func _spawn_enemy() -> void:
	if enemy_scene == null or not is_instance_valid(_player):
		return
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	var angle := _random.randf_range(0.0, TAU)
	var distance := _random.randf_range(minimum_distance, maximum_distance)
	enemy.global_position = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	enemy.initialize(_player)

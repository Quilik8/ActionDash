extends SceneTree

class DummyEnemy:
	extends Node3D
	var health: float = 1.0
	var knockback_force: float = 0.0
	var knockback_direction: Vector3 = Vector3.ZERO

	func _ready() -> void:
		add_to_group("enemies")

	func get_projectile_hit_position() -> Vector3:
		return global_position

	func get_projectile_hit_radius() -> float:
		return 0.5

	func is_defeated() -> bool:
		return health <= 0.0

	func apply_damage(amount: float, _damage_type: StringName = &"generic") -> void:
		health -= amount
		if health <= 0.0:
			remove_from_group("enemies")

	func apply_knockback(direction: Vector3, force: float, _duration: float, _vertical_boost: float = 0.0) -> void:
		knockback_direction = direction
		knockback_force = force

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var playground: Node = (load("res://scenes/gameplay/playground.tscn") as PackedScene).instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	var player := playground.get_node("Player") as ActionDashPlayer
	var spawner := playground.get_node("EnemySpawner") as ActionDashEnemySpawner
	var core := playground.get_node("ProtectedCore") as ActionDashProtectedCore
	var controller := playground.get_node("PhaseController") as ActionDashPhaseController
	spawner.clear_phase()

	Input.action_press("move_forward")
	await physics_frame
	_expect(is_equal_approx(player.get_horizontal_speed(), 18.0), "NORMAL no mantiene velocidad fija 18")
	Input.action_release("move_forward")
	await physics_frame
	_expect(player.get_horizontal_speed() < 0.05, "NORMAL no se detiene al soltar input")

	Input.action_press("super_movement")
	await physics_frame
	Input.action_release("super_movement")
	await physics_frame
	_expect(player.is_super_movement_active(), "Q no activa SUPER")
	Input.action_press("move_backward")
	await physics_frame
	_expect(player.get_horizontal_speed() >= 18.0 and player.get_horizontal_speed() < 19.0, "SUPER no comienza en velocidad mínima 18")
	for _frame in 23:
		await physics_frame
	var accelerated_speed := player.get_horizontal_speed()
	_expect(accelerated_speed > 18.0 and accelerated_speed <= player.max_speed + 0.1, "SUPER no acelera sobre NORMAL")
	Input.action_release("move_backward")
	await physics_frame
	_expect(player.get_horizontal_speed() < 0.05, "SUPER no se detiene inmediatamente sin input")
	_expect(player.is_super_movement_active(), "SUPER se apaga al detenerse")
	Input.action_press("move_right")
	await physics_frame
	_expect(player.get_horizontal_speed() >= player.super_initial_speed - 0.1, "SUPER no reinicia al pulsar otra dirección")
	Input.action_release("move_right")
	await physics_frame
	Input.action_press("super_movement")
	await physics_frame
	Input.action_release("super_movement")
	await physics_frame
	_expect(not player.is_super_movement_active(), "Q no desactiva SUPER")

	var combat := player.get_node("Gameplay/ProximityDamage") as ActionDashProximityDamage
	var normal_knockback := combat.get_knockback_force(player.normal_speed, player.normal_speed, player.max_speed)
	var maximum_knockback := combat.get_knockback_force(player.max_speed, player.normal_speed, player.max_speed)
	_expect(maximum_knockback > normal_knockback * 3.0, "La velocidad alta no aumenta claramente el knockback")
	var melee_enemy := DummyEnemy.new()
	playground.add_child(melee_enemy)
	melee_enemy.global_position = player.global_position + player.get_melee_attack_direction() * 3.0
	for _frame in 3:
		await physics_frame
	_expect(is_equal_approx(melee_enemy.health, 1.0), "La proximidad sola todavía causa daño")
	Input.action_press("melee_attack")
	await physics_frame
	Input.action_release("melee_attack")
	await physics_frame
	_expect(melee_enemy.health <= 0.0, "Clic no ejecuta melee sobre un objetivo válido")
	_expect(melee_enemy.knockback_force >= combat.base_knockback_force, "Melee no aplica knockback")

	for _frame in 40:
		await physics_frame
	var landing_enemy := DummyEnemy.new()
	playground.add_child(landing_enemy)
	landing_enemy.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	var landed := combat.try_landing_attack(player.global_position, player.max_speed, 8.0, 0.5, player.max_speed)
	_expect(landed and landing_enemy.health < 1.0, "Landing Attack no daña automáticamente en aterrizaje válido")
	_expect(is_equal_approx(combat.get_landing_radius(player.max_speed, player.max_speed), combat.landing_radius), "Landing radius cambia con velocidad máxima")
	_expect(landing_enemy.knockback_force >= combat.landing_knockback_force, "Landing Attack no aplica knockback radial")

	var saved_player_position := player.global_position
	player.global_position = saved_player_position + Vector3.UP * 2.0
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	var flying_enemy := (spawner.flying_enemy_scene.instantiate() as ActionDashFlyingEnemy)
	playground.add_child(flying_enemy)
	flying_enemy.activate(player.global_position + Vector3(2.8, 4.8, -3.0))
	var aerial_health_before := flying_enemy.current_health
	var aerial_hit := combat.try_melee_attack(player, Vector3(0.0, 0.0, -1.0))
	_expect(not player.is_on_floor(), "La prueba aerea no dejo al Player fuera del suelo")
	_expect(aerial_hit and flying_enemy.current_health < aerial_health_before, "Melee aereo no alcanzo al Bat dentro del volumen asistido")
	_expect(flying_enemy.is_defeated(), "Melee aereo no pudo derrotar al Bat")
	var aerial_start := flying_enemy.global_position
	await physics_frame
	_expect(flying_enemy.global_position.distance_to(aerial_start) > 0.01, "La muerte aerea no inicio trayectoria de knockback")
	flying_enemy.deactivate()
	player.global_position = saved_player_position
	player.velocity = Vector3.ZERO
	player.move_and_slide()

	var ranged_one := DummyEnemy.new()
	var ranged_two := DummyEnemy.new()
	playground.add_child(ranged_one)
	playground.add_child(ranged_two)
	ranged_one.global_position = player.global_position + Vector3(0.0, 0.95, -7.0)
	ranged_two.global_position = player.global_position + Vector3(0.0, 0.95, -13.0)
	var ranged_power := player.get_node("Gameplay/RangedPower") as ActionDashRangedPower
	ranged_power._cooldown_remaining = 0.0
	var ranged_activated := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -25.0))
	for _frame in 60:
		await process_frame
	_expect(ranged_activated, "RMB/ranged no pudo activar la esfera")
	_expect(ranged_one.health <= 0.0 and ranged_two.health <= 0.0, "El proyectil ranged no atraveso dos enemigos tocados")

	var pool_config := (load("res://resources/phases/phase_1.tres") as ActionDashPhaseConfig).duplicate(true) as ActionDashPhaseConfig
	pool_config.total_enemies = 1
	pool_config.maximum_active_enemies = 1
	pool_config.flying_enemy_ratio = 0.0
	pool_config.contains_boss = false
	pool_config.spawn_interval = 0.0
	spawner.start_phase(pool_config)
	await physics_frame
	var pooled_enemy := spawner._active_ground[0] as ActionDashEnemy
	pooled_enemy.apply_damage(100.0, &"melee")
	for _frame in 60:
		await physics_frame
	_expect(spawner.get_active_count() == 0, "Enemigo derrotado no salio del active pool tras su reaccion")
	_expect(spawner.get_pool_size() > 0, "Enemigo derrotado no regreso al pool")
	spawner.start_phase(pool_config)
	await physics_frame
	_expect(spawner.get_active_count() == 1, "El pool no reutilizo la instancia derrotada")

	var route_enemy := spawner.enemy_scene.instantiate() as ActionDashEnemy
	playground.add_child(route_enemy)
	route_enemy.set_meta("spawn_group", 1)
	var route_start := core.global_position + Vector3(12.0, 0.0, 0.0)
	route_enemy.activate(route_start)
	var integrity_before_route := core.get_integrity()
	for _frame in 300:
		await physics_frame
	_expect(route_enemy.global_position.distance_to(core.global_position) < route_start.distance_to(core.global_position), "Enemigo no avanza hacia el núcleo")
	_expect(core.get_integrity() < integrity_before_route, "Enemigo que llega al núcleo no le causa daño")
	route_enemy.deactivate()

	core.apply_enemy_damage(core.get_maximum_integrity())
	await process_frame
	_expect(controller.get_state() == ActionDashPhaseController.RunState.DEFEAT, "Integridad 0 no genera derrota")

	if _failures.is_empty():
		print("REWORK_VALIDATION_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

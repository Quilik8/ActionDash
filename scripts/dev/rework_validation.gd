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
	Engine.max_fps = 144
	var playground: Node = (load("res://scenes/gameplay/playground.tscn") as PackedScene).instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	var player := playground.get_node("Player") as ActionDashPlayer
	var spawner := playground.get_node("EnemySpawner") as ActionDashEnemySpawner
	var core := playground.get_node("ProtectedCore") as ActionDashProtectedCore
	var controller := playground.get_node("PhaseController") as ActionDashPhaseController
	spawner.clear_phase()

	_expect(not InputMap.has_action("super_movement"), "Q sigue registrado como accion de movimiento")
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "La interpolacion fisica global no esta activa")
	_expect(player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "Player no fuerza interpolacion fisica")
	_expect(playground.get_node("CameraRig").physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "CameraRig controlado en process hereda interpolacion")

	var movement_start := player.global_position
	Input.action_press("move_backward")
	await physics_frame
	_expect(player.get_horizontal_speed() >= player.initial_speed and player.get_horizontal_speed() < player.initial_speed + 1.0, "El movimiento base no comienza en la velocidad inicial")
	for _frame in 40:
		await physics_frame
	_expect(is_equal_approx(player.get_horizontal_speed(), player.max_speed), "El movimiento base no acelera hasta la velocidad maxima")
	var stable_positions: Array[Vector3] = []
	for _frame in 30:
		await physics_frame
		stable_positions.append(player.global_position)
	_expect(_axis_span(stable_positions, 1) < 0.001, "El cuerpo oscila verticalmente a velocidad maxima")
	_expect(_axis_span(stable_positions, 0) < 0.001, "El cuerpo deriva lateralmente a velocidad maxima")
	var interpolated_positions: Array[Vector3] = []
	for _frame in 90:
		await process_frame
		interpolated_positions.append(player.get_global_transform_interpolated().origin)
	_expect(_maximum_step(interpolated_positions) < 0.4, "La ruta visual interpolada conserva saltos de 0.6 m")
	Input.action_release("move_backward")
	await physics_frame
	await physics_frame
	_expect(player.get_horizontal_speed() < 0.05, "El movimiento base no se detiene inmediatamente al soltar input")
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	_expect(player.get_horizontal_speed() >= player.initial_speed and player.get_horizontal_speed() < player.initial_speed + 2.0, "El movimiento no reinicia desde la velocidad inicial")
	for _frame in 12:
		await physics_frame
	var camera_right := playground.get_viewport().get_camera_3d().global_basis.x
	camera_right.y = 0.0
	_expect(player.get_melee_attack_direction().dot(camera_right.normalized()) > 0.8, "El cambio de direccion no responde con rapidez")
	Input.action_release("move_right")
	await physics_frame
	var base_max_speed := player.max_speed
	var base_acceleration := player.acceleration
	player.apply_run_stat_modifier(&"max_speed", "Add", 3.0)
	player.apply_run_stat_modifier(&"acceleration", "Add", 4.0)
	_expect(is_equal_approx(player.max_speed, base_max_speed + 3.0), "El upgrade de velocidad maxima no modifica el movimiento base")
	_expect(is_equal_approx(player.acceleration, base_acceleration + 4.0), "El upgrade de aceleracion no modifica el movimiento base")
	player.restore_base_run_stats()
	_expect(is_equal_approx(player.max_speed, base_max_speed) and is_equal_approx(player.acceleration, base_acceleration), "Los stats base no se restauran")
	player.global_position = movement_start
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await physics_frame

	var combat := player.get_node("Gameplay/ProximityDamage") as ActionDashProximityDamage
	var initial_knockback := combat.get_knockback_force(player.initial_speed, player.initial_speed, player.max_speed)
	var maximum_knockback := combat.get_knockback_force(player.max_speed, player.initial_speed, player.max_speed)
	_expect(maximum_knockback > initial_knockback * 3.0, "La velocidad real alta no aumenta claramente el knockback")
	_expect(is_equal_approx(combat.get_lethal_knockback_force(player.initial_speed, player.initial_speed, player.max_speed), 30.0), "El knockback letal base no empieza en 30")
	_expect(is_equal_approx(combat.get_lethal_knockback_force(player.max_speed, player.initial_speed, player.max_speed), 75.0), "El knockback letal maximo no llega a 75")
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
	var visuals := player.get_node("VisualRoot") as ActionDashPlayerVisuals
	var empty_attack_position := player.global_position
	var empty_attack := combat.try_melee_attack(player, player.get_melee_attack_direction())
	await physics_frame
	_expect(empty_attack, "Melee sin objetivo no consume el ataque")
	_expect(visuals._action_timer > 0.0, "Melee sin objetivo no dispara la animacion visual")
	_expect(player.global_position.distance_to(empty_attack_position) < 0.01, "Melee sin objetivo mueve al Player")
	for _frame in 20:
		await physics_frame
	var landing_enemy := DummyEnemy.new()
	playground.add_child(landing_enemy)
	landing_enemy.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)
	_expect(not combat.has_method("try_landing_attack"), "El metodo ofensivo de Landing sigue presente")
	player.global_position += Vector3.UP * 3.0
	player.velocity = Vector3(0.0, -2.0, 0.0)
	player.reset_physics_interpolation()
	for _frame in 60:
		await physics_frame
		if player.is_on_floor():
			break
	_expect(player.is_on_floor(), "La prueba de aterrizaje no llego al suelo")
	_expect(is_equal_approx(landing_enemy.health, 1.0) and is_equal_approx(landing_enemy.knockback_force, 0.0), "El aterrizaje normal todavia daña o empuja enemigos")
	_expect((player.get_node("VisualRoot/VFX/LandingDustParticles") as GPUParticles3D).emitting, "El aterrizaje normal no emite polvo ligero")
	landing_enemy.remove_from_group("enemies")

	var saved_player_position := player.global_position
	player.global_position = saved_player_position + Vector3.UP * 2.0
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	var flying_enemy := (spawner.flying_enemy_scene.instantiate() as ActionDashFlyingEnemy)
	playground.add_child(flying_enemy)
	flying_enemy.activate(player.global_position + Vector3(1.8, 4.8, -1.8))
	var aerial_health_before := flying_enemy.current_health
	var aerial_hit := combat.try_melee_attack(player, Vector3(0.0, 0.0, -1.0))
	_expect(not player.is_on_floor(), "La prueba aerea no dejo al Player fuera del suelo")
	_expect(aerial_hit and flying_enemy.current_health < aerial_health_before, "Melee aereo no alcanzo al Bat dentro del volumen asistido")
	_expect(flying_enemy.is_defeated(), "Melee aereo no pudo derrotar al Bat")
	var aerial_start := flying_enemy.global_position
	_expect(flying_enemy.get_node("VisualRoot").scale.distance_to(Vector3.ONE) < 0.01, "La muerte aerea reduce la escala antes del vuelo")
	await physics_frame
	_expect(flying_enemy.global_position.distance_to(aerial_start) > 0.01, "La muerte aerea no inicio trayectoria de knockback")
	flying_enemy.deactivate()
	player.global_position = saved_player_position
	player.velocity = Vector3.ZERO
	player.move_and_slide()

	var ranged_power := player.get_node("Gameplay/RangedPower") as ActionDashRangedPower
	var ranged_three: Array[DummyEnemy] = []
	for depth in [7.0, 13.0, 19.0]:
		var target := DummyEnemy.new()
		playground.add_child(target)
		target.global_position = player.global_position + Vector3(0.0, 0.95, -depth)
		ranged_three.append(target)
	ranged_power._cooldown_remaining = 0.0
	var ranged_activated := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -30.0))
	for _frame in 80:
		await process_frame
	_expect(ranged_activated, "RMB/ranged no pudo activar la esfera")
	_expect(ranged_three[0].health <= 0.0 and ranged_three[1].health <= 0.0 and ranged_three[2].health <= 0.0, "La cadena ranged no completo tres objetivos unicos")

	var ground_chain_a := DummyEnemy.new()
	var ground_chain_b := DummyEnemy.new()
	var bat_chain := spawner.flying_enemy_scene.instantiate() as ActionDashFlyingEnemy
	playground.add_child(ground_chain_a)
	playground.add_child(ground_chain_b)
	playground.add_child(bat_chain)
	ground_chain_a.global_position = player.global_position + Vector3(0.0, 0.95, -7.0)
	ground_chain_b.global_position = player.global_position + Vector3(0.0, 0.95, -19.0)
	bat_chain.activate(player.global_position + Vector3(0.0, 4.8, -13.0))
	ranged_power._cooldown_remaining = 0.0
	(ranged_power as ActionDashEnergySpherePower).debug_chain_targeting = true
	var mixed_ranged := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -30.0))
	for _frame in 90:
		await process_frame
	_expect(mixed_ranged and ground_chain_a.health <= 0.0 and bat_chain.is_defeated() and ground_chain_b.health <= 0.0, "La cadena ranged no mezclo suelo, Bat y suelo")
	(ranged_power as ActionDashEnergySpherePower).debug_chain_targeting = false
	bat_chain.deactivate()

	var one_target := DummyEnemy.new()
	playground.add_child(one_target)
	one_target.global_position = player.global_position + Vector3(0.0, 0.95, -8.0)
	ranged_power._cooldown_remaining = 0.0
	var one_shot := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -20.0))
	for _frame in 60:
		await process_frame
	_expect(one_shot and one_target.health <= 0.0, "El ranged de un objetivo no impacto")

	var two_targets: Array[DummyEnemy] = []
	for depth in [8.0, 15.0]:
		var target := DummyEnemy.new()
		playground.add_child(target)
		target.global_position = player.global_position + Vector3(0.0, 0.95, -depth)
		two_targets.append(target)
	ranged_power._cooldown_remaining = 0.0
	var two_shot := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -22.0))
	for _frame in 70:
		await process_frame
	_expect(two_shot and two_targets[0].health <= 0.0 and two_targets[1].health <= 0.0, "El ranged de dos objetivos no completo la cadena")

	var capped_targets: Array[DummyEnemy] = []
	for depth in [8.0, 14.0, 20.0, 26.0]:
		var target := DummyEnemy.new()
		playground.add_child(target)
		target.global_position = player.global_position + Vector3(0.0, 0.95, -depth)
		capped_targets.append(target)
	ranged_power._cooldown_remaining = 0.0
	var capped_shot := player._spawn_energy_projectile_toward(player.global_position + Vector3(0.0, 0.0, -36.0))
	for _frame in 90:
		await process_frame
	_expect(capped_shot and capped_targets[0].health <= 0.0 and capped_targets[1].health <= 0.0 and capped_targets[2].health <= 0.0 and capped_targets[3].health > 0.0, "Ranged no respeta el maximo de tres objetivos")

	# The boss weak point is acquired through the cursor ray before ordinary bodies.
	var boss_config := load("res://resources/phases/phase_1.tres") as ActionDashPhaseConfig
	if boss_config != null and boss_config.boss_scene != null:
		var weak_boss := boss_config.boss_scene.instantiate() as ActionDashBoss
		playground.add_child(weak_boss)
		await process_frame
		weak_boss.initialize(player.global_position + Vector3(0.0, 0.0, -16.0))
		await process_frame
		ranged_power._cooldown_remaining = 0.0
		var weak_point_shot := player._spawn_energy_projectile_toward(weak_boss.get_projectile_weak_point_position())
		for _frame in 55:
			await process_frame
		_expect(weak_point_shot and weak_boss.is_vulnerable(), "El ranged no prioriza el weak point del boss apuntado")
		weak_boss.queue_free()

	var camera := playground.get_viewport().get_camera_3d()
	var lod_enemy := spawner.enemy_scene.instantiate() as ActionDashEnemy
	playground.add_child(lod_enemy)
	await process_frame
	var camera_forward := -camera.global_basis.z
	lod_enemy.global_position = camera.global_position + camera_forward * 10.0
	lod_enemy._lod_level = 0
	lod_enemy._update_performance_lod()
	_expect(lod_enemy.get_lod_level() == 0 and lod_enemy._model.visible, "LOD0 cercano no conserva el modelo completo")
	lod_enemy.global_position = camera.global_position + camera_forward * 50.0
	lod_enemy._update_performance_lod()
	_expect(lod_enemy.get_lod_level() == 1 and lod_enemy._primitive_body.visible, "LOD1 medio no activa el proxy reconocible")
	lod_enemy.global_position = camera.global_position + camera_forward * 90.0
	lod_enemy._update_performance_lod()
	_expect(lod_enemy.get_lod_level() == 2 and lod_enemy._primitive_body.mesh is ArrayMesh, "LOD2 lejano no activa la silueta barata")
	var lod_flying := spawner.flying_enemy_scene.instantiate() as ActionDashFlyingEnemy
	playground.add_child(lod_flying)
	lod_flying.activate(camera.global_position + camera_forward * 90.0)
	lod_flying._update_performance_lod()
	_expect(lod_flying.get_lod_level() == 2, "LOD2 no cubre al Bat")
	lod_enemy.deactivate()
	lod_enemy.queue_free()
	lod_flying.deactivate()
	lod_flying.queue_free()

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
		print("CONSOLIDATION_VALIDATION_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _axis_span(values: Array[Vector3], axis: int) -> float:
	var minimum := INF
	var maximum := -INF
	for value in values:
		minimum = minf(minimum, value[axis])
		maximum = maxf(maximum, value[axis])
	return maximum - minimum

func _maximum_step(values: Array[Vector3]) -> float:
	var result := 0.0
	for index in range(1, values.size()):
		result = maxf(result, values[index].distance_to(values[index - 1]))
	return result

extends Node3D

const PLAYGROUND_SCENE := preload("res://scenes/gameplay/playground.tscn")
const PHASE_TEMPLATE := preload("res://resources/phases/phase_2.tres")

@export var baseline_active_enemies: int = 22
@export var stress_active_enemies: int = 100
@export var warmup_seconds: float = 2.0
@export var measurement_seconds: float = 6.0

var _playground: Node3D
var _player: ActionDashPlayer
var _visuals: ActionDashPlayerVisuals
var _spawner: ActionDashEnemySpawner
var _controller: ActionDashPhaseController
var _effect_refresh_timer: float = 0.0
var _sphere_timer: float = 0.0
var _effects_active: bool = false

func _ready() -> void:
	process_priority = 100
	_playground = PLAYGROUND_SCENE.instantiate() as Node3D
	add_child(_playground)
	call_deferred("_run_test")

func _process(delta: float) -> void:
	if not _effects_active or not is_instance_valid(_player):
		return
	_player._super_movement_active = true
	_player._kinetic_max_active = true
	if Vector2(_player.global_position.x, _player.global_position.z).length() > 70.0:
		_player.global_position = Vector3.ZERO
		_player.velocity = Vector3(0.0, 0.0, -_player.max_speed)
	_controller._time_remaining = 29.0
	_effect_refresh_timer = maxf(_effect_refresh_timer - delta, 0.0)
	_sphere_timer = maxf(_sphere_timer - delta, 0.0)
	if _effect_refresh_timer <= 0.0:
		_effect_refresh_timer = 0.1
		var melee_radius := _player.get_visual_melee_radius()
		_visuals._on_proximity_attack(_player.global_position, 4, 3.0, melee_radius)
		_visuals._on_kinetic_wave(_player.global_position, 8)
		_visuals._on_landing_attack(_player.global_position, 6, 1.3, _player.get_estimated_landing_radius())
		_visuals._on_energy_attack_fired((_player.get_node("AttackOrigin") as Marker3D).global_position, -_player.global_basis.z)
		_visuals._on_kinetic_state_changed(true)
	if _sphere_timer <= 0.0:
		_sphere_timer = 0.9
		var power := _player.get_node("Gameplay/RangedPower") as ActionDashRangedPower
		power._cooldown_remaining = 0.0
		_player._spawn_energy_projectile_toward(_player.global_position + Vector3(0.0, 12.0, -55.0))
	var vfx := _player.get_node("VisualRoot/VFX")
	(vfx.get_node("KineticAura") as MeshInstance3D).visible = true
	(vfx.get_node("SuperSpeedParticles") as GPUParticles3D).emitting = true
	_force_enemy_arrow()

func _force_enemy_arrow() -> void:
	var arrow := _player.get_node("VisualRoot/VFX/EnemyDirectionArrow") as Node3D
	var nearest_enemy: Node3D
	var nearest_distance_squared := INF
	for group_name in [&"ground_enemies", &"flying_enemies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var enemy := node as Node3D
			if not is_instance_valid(enemy):
				continue
			var distance_squared := _player.global_position.distance_squared_to(enemy.global_position)
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest_enemy = enemy
	if not is_instance_valid(nearest_enemy):
		arrow.visible = false
		return
	var direction := nearest_enemy.global_position - _player.global_position
	arrow.rotation.y = atan2(-direction.x, -direction.z)
	arrow.visible = true

func _run_test() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	_player = _playground.get_node("Player") as ActionDashPlayer
	_visuals = _player.get_node("VisualRoot") as ActionDashPlayerVisuals
	_spawner = _playground.get_node("EnemySpawner") as ActionDashEnemySpawner
	_controller = _playground.get_node("PhaseController") as ActionDashPhaseController
	(_player.get_node("Gameplay/ProximityDamage") as ActionDashProximityDamage).set_physics_process(false)
	_player._super_movement_active = true
	_player._kinetic_max_active = true
	_player.velocity = Vector3(0.0, 0.0, -_player.max_speed)
	_player.kinetic_state_changed.emit(true)
	Input.action_press("move_forward")
	_effects_active = true

	var baseline := await _measure_population("baseline", baseline_active_enemies)
	var maximum := await _measure_population("maximum", maxi(stress_active_enemies, baseline_active_enemies))

	Input.action_release("move_forward")
	_effects_active = false
	var result := {
		"baseline": baseline,
		"maximum": maximum,
		"fps_retention": float(maximum["average_fps"]) / maxf(float(baseline["average_fps"]), 0.001),
	}
	print("STRESS_TEST_RESULT ", JSON.stringify(result))
	get_tree().quit()

func _measure_population(label: String, active_count: int) -> Dictionary:
	var config := PHASE_TEMPLATE.duplicate(true) as ActionDashPhaseConfig
	config.display_name = "STRESS %s" % label.to_upper()
	config.total_enemies = active_count
	config.maximum_active_enemies = active_count
	config.time_limit_seconds = 999.0
	config.spawn_interval = 0.0
	_spawner.start_phase(config)
	_controller._enemies_remaining = active_count
	_controller._time_remaining = 29.0
	await get_tree().create_timer(warmup_seconds).timeout

	var actual_count := _spawner.get_active_count()
	var start_usec := Time.get_ticks_usec()
	var start_frames := Engine.get_process_frames()
	var previous_usec := start_usec
	var previous_frames := start_frames
	var minimum_fps := INF
	var samples: Array[float] = []
	while float(Time.get_ticks_usec() - start_usec) / 1000000.0 < measurement_seconds:
		await get_tree().create_timer(0.5).timeout
		var now_usec := Time.get_ticks_usec()
		var now_frames := Engine.get_process_frames()
		var interval_seconds := maxf(float(now_usec - previous_usec) / 1000000.0, 0.001)
		var interval_fps := float(now_frames - previous_frames) / interval_seconds
		samples.append(interval_fps)
		minimum_fps = minf(minimum_fps, interval_fps)
		previous_usec = now_usec
		previous_frames = now_frames
	var elapsed_seconds := maxf(float(Time.get_ticks_usec() - start_usec) / 1000000.0, 0.001)
	var average_fps := float(Engine.get_process_frames() - start_frames) / elapsed_seconds
	var variants := {&"skeleton": 0, &"slime": 0, &"spider": 0, &"bat": 0}
	for node in get_tree().get_nodes_in_group("ground_enemies"):
		var enemy := node as ActionDashEnemy
		variants[enemy.get_visual_variant()] = int(variants[enemy.get_visual_variant()]) + 1
	variants[&"bat"] = get_tree().get_node_count_in_group("flying_enemies")
	var measurement := {
		"requested_active": active_count,
		"actual_active": actual_count,
		"average_fps": snappedf(average_fps, 0.1),
		"minimum_half_second_fps": snappedf(minimum_fps, 0.1),
		"average_frame_ms": snappedf(1000.0 / maxf(average_fps, 0.001), 0.01),
		"variants": variants,
		"player_effects": _get_player_effect_state(),
		"samples": samples,
	}
	print("STRESS_STAGE ", JSON.stringify({label: measurement}))
	return measurement

func _get_player_effect_state() -> Dictionary:
	var vfx := _player.get_node("VisualRoot/VFX")
	var projectile_count := 0
	for node in find_children("*", "Node3D", true, false):
		if node is ActionDashProjectile:
			projectile_count += 1
	return {
		"kinetic_aura": (vfx.get_node("KineticAura") as MeshInstance3D).visible,
		"speed_particles": (vfx.get_node("SuperSpeedParticles") as GPUParticles3D).emitting,
		"melee_flash": (vfx.get_node("ProximityFlash") as MeshInstance3D).visible,
		"kinetic_wave": (vfx.get_node("KineticWave") as MeshInstance3D).visible,
		"landing": (vfx.get_node("LandingImpact") as MeshInstance3D).visible,
		"muzzle": (vfx.get_node("MuzzleFlash") as MeshInstance3D).visible,
		"enemy_arrow": (vfx.get_node("EnemyDirectionArrow") as Node3D).visible,
		"energy_spheres": projectile_count,
	}

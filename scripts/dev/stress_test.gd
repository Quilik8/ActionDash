extends Node3D

const PLAYGROUND_SCENE := preload("res://scenes/gameplay/playground.tscn")
const PHASE_TEMPLATE := preload("res://resources/phases/phase_2.tres")

@export var baseline_active_enemies: int = 22
@export var stress_active_enemies: int = 200
@export var warmup_seconds: float = 4.0
@export var baseline_measurement_seconds: float = 8.0
@export var stress_measurement_seconds: float = 30.0
@export var orbit_speed_degrees: float = 45.0
@export var target_fps: float = 30.0

var _playground: Node3D
var _player: ActionDashPlayer
var _visuals: ActionDashPlayerVisuals
var _spawner: ActionDashEnemySpawner
var _controller: ActionDashPhaseController
var _camera_rig: ActionDashCameraFollow
var _sphere_timer: float = 0.0
var _arrow_force_timer: float = 0.0
var _effects_active: bool = false
var _travel_distance: float = 0.0
var _orbit_degrees: float = 0.0
var _previous_player_position: Vector3
var _reset_count: int = 0

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
	var movement_delta := _player.global_position - _previous_player_position
	movement_delta.y = 0.0
	if movement_delta.length() < 10.0:
		_travel_distance += movement_delta.length()
	_previous_player_position = _player.global_position
	_camera_rig._orbit_yaw += deg_to_rad(orbit_speed_degrees) * delta
	_orbit_degrees += absf(orbit_speed_degrees * delta)
	if Vector2(_player.global_position.x, _player.global_position.z).length() > 110.0:
		_player.global_position = Vector3.ZERO
		_player.velocity = Vector3(0.0, 0.0, -_player.max_speed)
		_previous_player_position = _player.global_position
		_camera_rig.snap_to_target()
		_reset_count += 1
	_controller._time_remaining = 29.0
	_sphere_timer = maxf(_sphere_timer - delta, 0.0)
	_arrow_force_timer = maxf(_arrow_force_timer - delta, 0.0)
	if _sphere_timer <= 0.0:
		_sphere_timer = 0.9
		var power := _player.get_node("Gameplay/RangedPower") as ActionDashRangedPower
		power._cooldown_remaining = 0.0
		_player._spawn_energy_projectile_toward(_player.global_position + Vector3(0.0, 12.0, -55.0))
	_force_stable_player_effects()
	if _arrow_force_timer <= 0.0:
		_arrow_force_timer = 0.1
		_force_enemy_arrow()

func _force_stable_player_effects() -> void:
	var vfx := _player.get_node("VisualRoot/VFX")
	var stable_scales := {
		"ProximityFlash": Vector3.ONE * 1.45,
	}
	for node_name in stable_scales:
		var effect := vfx.get_node(NodePath(node_name)) as MeshInstance3D
		effect.visible = true
		effect.scale = stable_scales[node_name]
	(vfx.get_node("SuperSpeedParticles") as GPUParticles3D).emitting = true
	var slash := vfx.get_node_or_null("MeleeSlash") as Sprite3D
	if slash != null:
		slash.visible = true
		slash.scale = Vector3.ONE * 1.8

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
	_camera_rig = _playground.get_node("CameraRig") as ActionDashCameraFollow
	(_player.get_node("Gameplay/ProximityDamage") as ActionDashProximityDamage).set_physics_process(false)
	(_player.get_node("Gameplay/RangedPower") as ActionDashRangedPower).damage = 0.0
	_player._super_movement_active = true
	_player._kinetic_max_active = true
	_player.velocity = Vector3(0.0, 0.0, -_player.max_speed)
	_player.kinetic_state_changed.emit(true)
	Input.action_press("move_forward")
	_previous_player_position = _player.global_position
	_effects_active = true

	var baseline := await _measure_population("baseline", baseline_active_enemies, baseline_measurement_seconds)
	var maximum := await _measure_population("maximum", maxi(stress_active_enemies, baseline_active_enemies), stress_measurement_seconds)

	Input.action_release("move_forward")
	_effects_active = false
	var result := {
		"baseline": baseline,
		"maximum": maximum,
		"fps_retention": float(maximum["average_fps"]) / maxf(float(baseline["average_fps"]), 0.001),
	}
	print("STRESS_TEST_RESULT ", JSON.stringify(result))
	get_tree().quit()

func _measure_population(label: String, active_count: int, duration_seconds: float) -> Dictionary:
	var config := PHASE_TEMPLATE.duplicate(true) as ActionDashPhaseConfig
	config.display_name = "STRESS %s" % label.to_upper()
	config.total_enemies = active_count
	config.maximum_active_enemies = active_count
	config.time_limit_seconds = 999.0
	config.spawn_interval = 0.0
	var spawn_start_usec := Time.get_ticks_usec()
	_spawner.start_phase(config)
	var spawn_setup_ms := float(Time.get_ticks_usec() - spawn_start_usec) / 1000.0
	_controller._enemies_remaining = active_count
	_controller._time_remaining = 29.0
	await get_tree().create_timer(warmup_seconds).timeout

	var actual_count := _spawner.get_active_count()
	var starting_enemy_positions := _capture_enemy_positions()
	var starting_distance := _travel_distance
	var starting_orbit := _orbit_degrees
	var starting_reset_count := _reset_count
	var start_usec := Time.get_ticks_usec()
	var start_frames := Engine.get_process_frames()
	var previous_usec := start_usec
	var previous_frames := start_frames
	var minimum_fps := INF
	var samples_below_target := 0
	var samples: Array[float] = []
	while float(Time.get_ticks_usec() - start_usec) / 1000000.0 < duration_seconds:
		await get_tree().create_timer(0.5).timeout
		var now_usec := Time.get_ticks_usec()
		var now_frames := Engine.get_process_frames()
		var interval_seconds := maxf(float(now_usec - previous_usec) / 1000000.0, 0.001)
		var interval_fps := float(now_frames - previous_frames) / interval_seconds
		samples.append(interval_fps)
		minimum_fps = minf(minimum_fps, interval_fps)
		if interval_fps < target_fps:
			samples_below_target += 1
		previous_usec = now_usec
		previous_frames = now_frames
	var elapsed_seconds := maxf(float(Time.get_ticks_usec() - start_usec) / 1000000.0, 0.001)
	var average_fps := float(Engine.get_process_frames() - start_frames) / elapsed_seconds
	var variants := {&"skeleton": 0, &"slime": 0, &"spider": 0, &"bat": 0}
	var attacking_buildings := 0
	for node in get_tree().get_nodes_in_group("ground_enemies"):
		var enemy := node as ActionDashEnemy
		variants[enemy.get_visual_variant()] = int(variants[enemy.get_visual_variant()]) + 1
		if enemy.is_attacking_building():
			attacking_buildings += 1
	variants[&"bat"] = get_tree().get_node_count_in_group("flying_enemies")
	for node in get_tree().get_nodes_in_group("flying_enemies"):
		if (node as ActionDashFlyingEnemy).is_assaulting_building():
			attacking_buildings += 1
	var enemy_motion := _measure_enemy_motion(starting_enemy_positions)
	var measurement := {
		"requested_active": active_count,
		"actual_active": actual_count,
		"average_fps": snappedf(average_fps, 0.1),
		"minimum_half_second_fps": snappedf(minimum_fps, 0.1),
		"average_frame_ms": snappedf(1000.0 / maxf(average_fps, 0.001), 0.01),
		"spawn_setup_ms": snappedf(spawn_setup_ms, 0.1),
		"ending_active": _spawner.get_active_count(),
		"enemies_moved": enemy_motion["moved"],
		"average_enemy_travel": enemy_motion["average_travel"],
		"attacking_buildings": attacking_buildings,
		"duration_seconds": snappedf(elapsed_seconds, 0.1),
		"travel_distance": snappedf(_travel_distance - starting_distance, 0.1),
		"orbit_degrees": snappedf(_orbit_degrees - starting_orbit, 0.1),
		"route_resets": _reset_count - starting_reset_count,
		"samples_below_target": samples_below_target,
		"percent_samples_at_or_above_target": snappedf(100.0 * float(samples.size() - samples_below_target) / maxf(float(samples.size()), 1.0), 0.1),
		"variants": variants,
		"player_effects": _get_player_effect_state(),
		"samples": samples,
	}
	print("STRESS_STAGE ", JSON.stringify({label: measurement}))
	return measurement

func _capture_enemy_positions() -> Dictionary:
	var positions := {}
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D:
			positions[node.get_instance_id()] = (node as Node3D).global_position
	return positions

func _measure_enemy_motion(starting_positions: Dictionary) -> Dictionary:
	var moved := 0
	var total_travel := 0.0
	var measured := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D or not starting_positions.has(node.get_instance_id()):
			continue
		var travel := (node as Node3D).global_position.distance_to(starting_positions[node.get_instance_id()])
		total_travel += travel
		measured += 1
		if travel >= 0.5:
			moved += 1
	return {
		"moved": moved,
		"average_travel": snappedf(total_travel / maxf(float(measured), 1.0), 0.1),
	}

func _get_player_effect_state() -> Dictionary:
	var vfx := _player.get_node("VisualRoot/VFX")
	var projectile_count := 0
	for node in find_children("*", "Node3D", true, false):
		if node is ActionDashProjectile:
			projectile_count += 1
	return {
		"speed_particles": (vfx.get_node("SuperSpeedParticles") as GPUParticles3D).emitting,
		"melee_flash": (vfx.get_node("ProximityFlash") as MeshInstance3D).visible,
		"landing_debris": (vfx.get_node("LandingDebrisParticles") as GPUParticles3D).emitting,
		"enemy_arrow": (vfx.get_node("EnemyDirectionArrow") as Node3D).visible,
		"energy_spheres": projectile_count,
	}

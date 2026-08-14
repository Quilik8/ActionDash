class_name ActionDashPlayerVisuals
extends Node3D

@export var enable_temporary_vfx: bool = true

const HUMANOID_SCENE := preload("res://assets/animations/quaternius_ual1/UAL1_Standard.glb")
const SLASH_TEXTURE := preload("res://assets/vfx/brackeys/particles/slash_02_a.png")
const TRACE_TEXTURE := preload("res://assets/vfx/brackeys/particles/trace_03_a.png")
const SPARK_TEXTURE := preload("res://assets/vfx/brackeys/particles/spark_03_a.png")

var _proximity_timer: float = 0.0
var _action_timer: float = 0.0
var _landing_animation_timer: float = 0.0
var _was_on_floor: bool = true
var _current_animation: StringName
var _humanoid: Node3D
var _animation_player: AnimationPlayer
var _slash_sprite: Sprite3D
var _speed_particles: GPUParticles3D
var _landing_debris: GPUParticles3D
var _enemy_arrow: Node3D
var _arrow_update_timer: float = 0.0
var _arrow_bob_time: float = 0.0

@onready var _body: MeshInstance3D = $Model/Body
@onready var _proximity_flash: MeshInstance3D = $VFX/ProximityFlash

func _ready() -> void:
	var player := get_parent() as ActionDashPlayer
	player.melee_attack.connect(_on_melee_attack)
	player.landing_attack.connect(_on_landing_attack)
	_install_humanoid()
	_create_asset_vfx()
	_hide_transient_vfx()
	_play_animation(&"Idle")

func _process(delta: float) -> void:
	var player := get_parent() as ActionDashPlayer
	_action_timer = maxf(_action_timer - delta, 0.0)
	_landing_animation_timer = maxf(_landing_animation_timer - delta, 0.0)
	_update_character_animation(player, delta)
	_update_super_feedback(player)
	_update_enemy_arrow(player, delta)
	_update_effect(_proximity_flash, "_proximity_timer", delta, 8.0)

func _on_melee_attack(_position: Vector3, _targets_hit: int, _damage_multiplier: float, effective_radius: float, _knockback_force: float) -> void:
	if not enable_temporary_vfx:
		return
	_proximity_timer = 0.16
	_show_effect(_proximity_flash, clampf(effective_radius * 0.2, 0.9, 2.0))
	_slash_sprite.visible = true
	_slash_sprite.scale = Vector3.ONE * clampf(effective_radius * 0.25, 1.3, 2.8)
	_play_action(&"Punch_Cross", 0.34)

func _on_landing_attack(_position: Vector3, _targets_hit: int, _damage_multiplier: float, effective_radius: float) -> void:
	if not enable_temporary_vfx:
		return
	_landing_debris.amount_ratio = clampf(effective_radius / 5.0, 0.7, 1.0)
	_landing_debris.restart()
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.get_parent() is ActionDashCameraFollow:
		(camera.get_parent() as ActionDashCameraFollow).add_shake(0.12, 0.12)
	_play_action(&"Jump_Land", 0.4)

func _install_humanoid() -> void:
	_body.visible = false
	_humanoid = HUMANOID_SCENE.instantiate() as Node3D
	_humanoid.name = "UALHumanoid"
	_humanoid.scale = Vector3.ONE * 1.5
	$Model.add_child(_humanoid)
	var players := _humanoid.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation_player = players[0] as AnimationPlayer

func _create_asset_vfx() -> void:
	_slash_sprite = _make_billboard("MeleeSlash", SLASH_TEXTURE, Color(0.35, 0.9, 1.0, 0.9), 0.012)
	_slash_sprite.position = Vector3(0.0, 1.0, -0.45)
	$VFX.add_child(_slash_sprite)

	_speed_particles = GPUParticles3D.new()
	_speed_particles.name = "SuperSpeedParticles"
	_speed_particles.amount = 18
	_speed_particles.lifetime = 0.42
	_speed_particles.randomness = 0.25
	_speed_particles.visibility_aabb = AABB(Vector3(-4, -3, -8), Vector3(8, 6, 16))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 1.8)
	quad.orientation = PlaneMesh.FACE_Z
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.18, 0.75, 1.0, 0.75)
	material.albedo_texture = TRACE_TEXTURE
	quad.material = material
	_speed_particles.draw_pass_1 = quad
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 0, 1)
	process_material.spread = 18.0
	process_material.initial_velocity_min = 5.0
	process_material.initial_velocity_max = 9.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.35
	process_material.scale_max = 0.8
	_speed_particles.process_material = process_material
	$VFX.add_child(_speed_particles)

	_landing_debris = GPUParticles3D.new()
	_landing_debris.name = "LandingDebrisParticles"
	_landing_debris.amount = 14
	_landing_debris.lifetime = 0.36
	_landing_debris.one_shot = true
	_landing_debris.explosiveness = 0.92
	_landing_debris.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 6, 10))
	var debris_quad := QuadMesh.new()
	debris_quad.size = Vector2(0.18, 0.18)
	debris_quad.orientation = PlaneMesh.FACE_Z
	var debris_material := StandardMaterial3D.new()
	debris_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debris_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	debris_material.albedo_color = Color(1.0, 0.62, 0.18, 0.82)
	debris_material.albedo_texture = SPARK_TEXTURE
	debris_quad.material = debris_material
	_landing_debris.draw_pass_1 = debris_quad
	var debris_process := ParticleProcessMaterial.new()
	debris_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	debris_process.emission_sphere_radius = 0.28
	debris_process.direction = Vector3.UP
	debris_process.spread = 55.0
	debris_process.initial_velocity_min = 2.5
	debris_process.initial_velocity_max = 5.5
	debris_process.gravity = Vector3(0.0, -11.0, 0.0)
	debris_process.scale_min = 0.45
	debris_process.scale_max = 0.9
	_landing_debris.process_material = debris_process
	_landing_debris.position.y = 0.18
	$VFX.add_child(_landing_debris)
	_create_enemy_arrow()

func _create_enemy_arrow() -> void:
	_enemy_arrow = Node3D.new()
	_enemy_arrow.name = "EnemyDirectionArrow"
	_enemy_arrow.position.y = 3.05
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ArrowMesh"
	var arrow_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, 0.0, -1.15), Vector3(-0.62, 0.0, -0.25), Vector3(-0.2, 0.0, -0.25),
		Vector3(0.0, 0.0, -1.15), Vector3(-0.2, 0.0, -0.25), Vector3(0.2, 0.0, -0.25),
		Vector3(0.0, 0.0, -1.15), Vector3(0.2, 0.0, -0.25), Vector3(0.62, 0.0, -0.25),
		Vector3(-0.2, 0.0, -0.25), Vector3(-0.2, 0.0, 0.75), Vector3(0.2, 0.0, 0.75),
		Vector3(-0.2, 0.0, -0.25), Vector3(0.2, 0.0, 0.75), Vector3(0.2, 0.0, -0.25),
	])
	arrow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 0.28, 0.08)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.08, 0.01)
	arrow_mesh.surface_set_material(0, material)
	mesh_instance.mesh = arrow_mesh
	_enemy_arrow.add_child(mesh_instance)
	$VFX.add_child(_enemy_arrow)
	_enemy_arrow.visible = false

func _update_enemy_arrow(player: ActionDashPlayer, delta: float) -> void:
	if player == null or not is_instance_valid(_enemy_arrow):
		return
	_arrow_bob_time += delta
	_enemy_arrow.position.y = 3.05 + sin(_arrow_bob_time * 4.0) * 0.12
	_arrow_update_timer = maxf(_arrow_update_timer - delta, 0.0)
	if _arrow_update_timer > 0.0:
		return
	_arrow_update_timer = 0.1
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = player.get_parent()
	var phase_controller := scene_root.get_node_or_null("PhaseController") as ActionDashPhaseController
	if phase_controller == null or phase_controller.get_state() != ActionDashPhaseController.RunState.COMBAT or phase_controller.get_time_remaining() > 30.0:
		_enemy_arrow.visible = false
		return
	var nearest_enemy: Node3D
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not node is Node3D or not (node as Node3D).visible:
			continue
		var candidate := node as Node3D
		var distance := player.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = candidate
	if nearest_enemy == null:
		_enemy_arrow.visible = false
		return
	var direction := nearest_enemy.global_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		_enemy_arrow.visible = false
		return
	_enemy_arrow.rotation.y = atan2(-direction.x, -direction.z)
	_enemy_arrow.visible = true

func _make_billboard(node_name: String, texture: Texture2D, color: Color, pixel_size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.modulate = color
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	return sprite

func _update_character_animation(player: ActionDashPlayer, delta: float) -> void:
	if player == null or _animation_player == null:
		return
	var on_floor := player.is_on_floor()
	if not _was_on_floor and on_floor:
		_landing_animation_timer = 0.24
		_play_animation(&"Jump_Land", 0.05, 1.25)
	_was_on_floor = on_floor
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal.length_squared() > 0.2:
		var desired_yaw := atan2(-horizontal.x, -horizontal.z) + PI
		$Model.rotation.y = lerp_angle($Model.rotation.y, desired_yaw, 1.0 - exp(-12.0 * delta))
	if _action_timer > 0.0:
		return
	if not on_floor:
		_play_animation(&"Jump_Start" if player.velocity.y > 1.5 else &"Jump", 0.12)
	elif _landing_animation_timer > 0.0:
		_play_animation(&"Jump_Land", 0.08, 1.25)
	elif horizontal.length() < 0.25:
		_play_animation(&"Idle", 0.16)
	elif player.is_super_movement_active():
		_play_animation(&"Sprint", 0.12, clampf(horizontal.length() / player.normal_speed, 1.0, 1.75))
	else:
		_play_animation(&"Jog_Fwd", 0.12, clampf(horizontal.length() / player.normal_speed, 0.8, 1.25))

func _update_super_feedback(player: ActionDashPlayer) -> void:
	if player == null:
		return
	var speed_ratio := clampf(player.get_horizontal_speed() / maxf(player.max_speed, 0.01), 0.0, 1.0)
	var super_visible := enable_temporary_vfx and player.is_super_movement_active()
	_speed_particles.emitting = super_visible and speed_ratio > 0.35
	_speed_particles.amount_ratio = clampf((speed_ratio - 0.25) / 0.75, 0.1, 1.0)

func _play_action(animation: StringName, duration: float) -> void:
	if _action_timer > duration * 0.45:
		return
	_action_timer = duration
	_play_animation(animation, 0.04, 1.45)

func _play_animation(animation: StringName, blend: float = 0.12, speed: float = 1.0) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation):
		return
	if _current_animation == animation and _animation_player.is_playing():
		_animation_player.speed_scale = speed
		return
	_current_animation = animation
	_animation_player.play(animation, blend, speed)

func _show_effect(effect: MeshInstance3D, initial_scale: float) -> void:
	effect.visible = true
	effect.scale = Vector3.ONE * initial_scale

func _update_effect(effect: MeshInstance3D, timer_name: StringName, delta: float, growth: float) -> void:
	var remaining: float = get(timer_name)
	if remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	set(timer_name, remaining)
	effect.scale += Vector3.ONE * delta * growth
	if remaining <= 0.0:
		effect.visible = false
		if is_instance_valid(_slash_sprite):
			_slash_sprite.visible = false

func _hide_transient_vfx() -> void:
	_proximity_flash.visible = false
	if is_instance_valid(_slash_sprite):
		_slash_sprite.visible = false

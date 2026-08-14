class_name ActionDashEnemy
extends Node3D

signal damaged(amount: float, remaining_health: float)
signal died

@export_category("Enemy")
@export var max_health: float = 1.0

@export_category("Protected objective assault")
@export var wander_speed: float = 2.6
@export var territory_radius: float = 4.0
@export var arrival_distance: float = 0.25
@export var objective_damage: float = 5.0
@export var objective_attack_interval: float = 1.2
@export var route_lane_spacing: float = 7.0

@export_category("Performance LOD")
@export var detailed_visual_distance: float = 34.0
@export var medium_visual_distance: float = 68.0
@export var far_visual_distance: float = 105.0
@export var lod_hysteresis: float = 3.0
@export var lod_check_interval: float = 0.2
@export var distant_logic_interval: float = 0.1

const VISUALS := {
	&"skeleton": [preload("res://assets/enemies/quaternius_lowpoly_monsters/Skeleton.fbx"), 0.36, "Idle", "Running", "Death", 1.0, 0.6],
	&"slime": [preload("res://assets/enemies/quaternius_lowpoly_monsters/Slime.fbx"), 0.75, "Idle", "Walk", "Death", 1.5, 0.02],
	&"spider": [preload("res://assets/enemies/quaternius_easy_animated/Spider.fbx"), 0.65, "Idle", "Walk", "Death", 4.0, 0.0],
}
const DEATH_TEXTURE := preload("res://assets/vfx/brackeys/particles/smoke_04_a.png")
const HIT_TEXTURE := preload("res://assets/vfx/brackeys/particles/spark_03_a.png")

var current_health: float
var _home_position: Vector3
var _wander_target: Vector3
var _defeated: bool = false
var _random := RandomNumberGenerator.new()
var _visual_variant: StringName = &"skeleton"
var _model: Node3D
var _animation_player: AnimationPlayer
var _current_animation: StringName
var _death_timer: float = 0.0
var _hit_timer: float = 0.0
var _death_vfx: Sprite3D
var _hit_vfx: Sprite3D
var _camera: Camera3D
var _lod_timer: float = 0.0
var _logic_accumulator: float = 0.0
var _detailed_lod_active: bool = true
var _lod_level: int = 0
var _assault_target: ActionDashProtectedCore
var _attacking_building: bool = false
var _route_stage: int = 0
var _objective_attack_timer: float = 0.0
var _knockback_velocity: Vector3
var _knockback_remaining: float = 0.0
var _knockback_drag: float = 0.0
var _ground_height: float = 0.0

@onready var _visual_root: Node3D = $VisualRoot
@onready var _primitive_body: MeshInstance3D = $VisualRoot/Body

func _ready() -> void:
	_random.seed = hash(str(get_instance_id()))
	_primitive_body.visible = false
	_update_primitive_lod_shape()
	_create_death_vfx()
	_create_hit_vfx()
	deactivate()

func configure_visual(variant: StringName) -> void:
	if not VISUALS.has(variant):
		variant = &"skeleton"
	if _visual_variant == variant and is_instance_valid(_model):
		return
	_visual_variant = variant
	if not is_node_ready():
		return
	_update_primitive_lod_shape()
	if not is_instance_valid(_model):
		return
	if _detailed_lod_active:
		_install_visual()
	else:
		_model.queue_free()
		_model = null
		_animation_player = null

func get_visual_variant() -> StringName:
	return _visual_variant

func activate(home_position: Vector3) -> void:
	_home_position = home_position
	_wander_target = home_position
	global_position = home_position
	_ground_height = home_position.y
	current_health = max_health
	_defeated = false
	_death_timer = 0.0
	_hit_timer = 0.0
	_attacking_building = false
	_knockback_velocity = Vector3.ZERO
	_knockback_remaining = 0.0
	_objective_attack_timer = _random.randf_range(0.0, objective_attack_interval)
	_visual_root.scale = Vector3.ONE
	_visual_root.rotation = Vector3.ZERO
	_current_animation = &""
	_death_vfx.visible = false
	_hit_vfx.visible = false
	visible = true
	add_to_group("enemies")
	add_to_group("ground_enemies")
	set_process(true)
	_lod_timer = _random.randf_range(0.0, lod_check_interval)
	_logic_accumulator = 0.0
	_update_performance_lod()
	_choose_protected_objective()
	if _detailed_lod_active:
		_play_named_animation(String(VISUALS[_visual_variant][2]), 0.0, 1.0)

func initialize(home_position: Vector3) -> void:
	activate(home_position)

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("enemies")
	remove_from_group("ground_enemies")
	if is_instance_valid(_death_vfx):
		_death_vfx.visible = false
	if is_instance_valid(_hit_vfx):
		_hit_vfx.visible = false

func _process(delta: float) -> void:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	if _hit_timer <= 0.0 and is_instance_valid(_hit_vfx):
		_hit_vfx.visible = false
	var being_knocked_back := _update_knockback(delta)
	if _defeated:
		_death_timer = maxf(_death_timer - delta, 0.0)
		_visual_root.rotation.z += delta * 7.0
		if _death_timer <= 0.0:
			died.emit()
			set_process(false)
		return
	if being_knocked_back:
		return
	_visual_root.scale = _visual_root.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = lod_check_interval
		_update_performance_lod()
	_logic_accumulator += delta
	if not _detailed_lod_active and _logic_accumulator < distant_logic_interval:
		return
	var logic_delta := _logic_accumulator
	_logic_accumulator = 0.0
	_objective_attack_timer = maxf(_objective_attack_timer - logic_delta, 0.0)
	var offset := _wander_target - global_position
	offset.y = 0.0
	if offset.length() > arrival_distance:
		_attacking_building = false
		global_position += offset.normalized() * minf(wander_speed * logic_delta, offset.length())
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-7.0 * logic_delta))
		if _detailed_lod_active:
			_play_named_animation(String(VISUALS[_visual_variant][3]), 0.18, 1.0)
	elif _route_stage < 2:
		_advance_objective_route()
	else:
		_attacking_building = true
		_face_assault_target(logic_delta)
		if _detailed_lod_active:
			_play_building_attack()
		_try_damage_objective()

func get_home_position() -> Vector3:
	return _home_position

func is_using_simplified_lod() -> bool:
	return visible and _lod_level == 2

func get_lod_level() -> int:
	return _lod_level

func is_attacking_building() -> bool:
	return is_attacking_objective()

func is_attacking_objective() -> bool:
	return visible and _attacking_building and is_instance_valid(_assault_target)

func get_simplified_lod_transform() -> Transform3D:
	return transform * _primitive_body.transform

func apply_damage(amount: float, _damage_type: StringName = &"generic") -> void:
	if _defeated:
		return
	current_health -= amount
	damaged.emit(amount, maxf(current_health, 0.0))
	if current_health <= 0.0:
		_defeated = true
		remove_from_group("enemies")
		remove_from_group("ground_enemies")
		_death_timer = 0.58
		_visual_root.scale = Vector3.ONE
		_death_vfx.visible = _lod_level == 0
		_death_vfx.scale = Vector3.ONE * (1.7 if _visual_variant == &"spider" else 1.0)
		_play_named_animation(String(VISUALS[_visual_variant][4]), 0.03, 2.0)
	else:
		_hit_timer = 0.14
		_hit_vfx.visible = _lod_level == 0
		_hit_vfx.scale = Vector3.ONE * 0.75
		_visual_root.scale = Vector3.ONE * 1.12

func apply_knockback(direction: Vector3, force: float, duration: float, vertical_boost: float = 0.0) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction.length_squared() < 0.01:
		flat_direction = Vector3.FORWARD
	_knockback_velocity = flat_direction * maxf(force, 0.0) + Vector3.UP * maxf(vertical_boost, 0.0)
	_knockback_remaining = maxf(duration, 0.05)
	_knockback_drag = maxf(force / _knockback_remaining, 0.0)
	_attacking_building = false

func apply_lethal_knockback(direction: Vector3, force: float, duration: float, vertical_boost: float = 0.0) -> void:
	apply_knockback(direction, force, duration, vertical_boost)
	_death_timer = maxf(_death_timer, duration + 0.12)

func is_defeated() -> bool:
	return _defeated

func get_projectile_hit_position() -> Vector3:
	var height := 1.15 if _visual_variant == &"spider" else (0.65 if _visual_variant == &"slime" else 0.95)
	return global_position + Vector3.UP * height

func get_projectile_hit_radius() -> float:
	return 1.35 if _visual_variant == &"spider" else (0.75 if _visual_variant == &"slime" else 0.82)

func _choose_protected_objective() -> void:
	var objectives := get_tree().get_nodes_in_group("protected_objective")
	if objectives.is_empty():
		var angle := _random.randf_range(0.0, TAU)
		var distance := sqrt(_random.randf()) * territory_radius
		_wander_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		return
	_assault_target = objectives[0] as ActionDashProtectedCore
	var toward_core := _assault_target.global_position - _home_position
	toward_core.y = 0.0
	var perpendicular := Vector3(-toward_core.z, 0.0, toward_core.x).normalized()
	var group_index := int(get_meta("spawn_group", 0))
	var lane_offset := float((group_index % 3) - 1) * route_lane_spacing
	_wander_target = _home_position.lerp(_assault_target.global_position, 0.48) + perpendicular * lane_offset
	_wander_target.y = _ground_height
	_route_stage = 0
	_attacking_building = false

func _advance_objective_route() -> void:
	if not is_instance_valid(_assault_target):
		_choose_protected_objective()
		return
	if _route_stage == 0:
		var outward := global_position - _assault_target.global_position
		outward.y = 0.0
		if outward.length_squared() < 0.01:
			outward = Vector3.FORWARD
		_wander_target = _assault_target.global_position + outward.normalized() * (_assault_target.get_approach_radius() + 1.0)
		_wander_target.y = _ground_height
		_route_stage = 1
	else:
		_route_stage = 2

func _try_damage_objective() -> void:
	if _objective_attack_timer > 0.0 or not is_instance_valid(_assault_target):
		return
	_objective_attack_timer = objective_attack_interval * _random.randf_range(0.9, 1.1)
	_assault_target.apply_enemy_damage(objective_damage)

func _face_assault_target(delta: float) -> void:
	if not is_instance_valid(_assault_target):
		return
	var direction := _assault_target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-9.0 * delta))

func _play_building_attack() -> void:
	if _find_animation("Attack") != &"":
		_play_named_animation("Attack", 0.12, 1.15)
	else:
		_play_named_animation(String(VISUALS[_visual_variant][2]), 0.18, 1.0)

func _update_knockback(delta: float) -> bool:
	if _knockback_remaining <= 0.0:
		return false
	_knockback_remaining = maxf(_knockback_remaining - delta, 0.0)
	global_position += _knockback_velocity * delta
	_knockback_velocity.y -= 13.0 * delta
	var flat_velocity := Vector3(_knockback_velocity.x, 0.0, _knockback_velocity.z)
	flat_velocity = flat_velocity.move_toward(Vector3.ZERO, _knockback_drag * delta)
	_knockback_velocity.x = flat_velocity.x
	_knockback_velocity.z = flat_velocity.z
	if global_position.y < _ground_height:
		global_position = Vector3(global_position.x, _ground_height, global_position.z)
		_knockback_velocity.y = 0.0
	return true

func _update_performance_lod() -> void:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var distance := _camera.global_position.distance_to(global_position)
	var in_view := _camera.is_position_in_frustum(global_position + Vector3.UP)
	if not in_view:
		_lod_level = 3
	else:
		_lod_level = _select_lod_level(distance)
	_detailed_lod_active = _lod_level == 0
	if _detailed_lod_active and not is_instance_valid(_model):
		_install_visual()
	if is_instance_valid(_model):
		_model.visible = _detailed_lod_active
		_model.process_mode = Node.PROCESS_MODE_INHERIT if _detailed_lod_active else Node.PROCESS_MODE_DISABLED
		if not _detailed_lod_active and _lod_level >= 2:
			_model.queue_free()
			_model = null
			_animation_player = null
	_primitive_body.visible = _lod_level == 1

func _select_lod_level(distance: float) -> int:
	var detail_in := maxf(detailed_visual_distance - lod_hysteresis, 0.0)
	var detail_out := detailed_visual_distance + lod_hysteresis
	var medium_in := maxf(medium_visual_distance - lod_hysteresis, detail_out)
	var medium_out := medium_visual_distance + lod_hysteresis
	var far_out := far_visual_distance + lod_hysteresis
	if distance > far_out:
		return 3
	if _lod_level == 0:
		return 0 if distance <= detail_out else 1
	if _lod_level == 1:
		if distance < detail_in:
			return 0
		return 1 if distance <= medium_out else 2
	if _lod_level == 2:
		if distance < detail_in:
			return 0
		return 1 if distance < medium_in else 2
	return 0 if distance <= detail_in else (1 if distance <= medium_out else 2)

func _install_visual() -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	var definition: Array = VISUALS[_visual_variant]
	_model = (definition[0] as PackedScene).instantiate() as Node3D
	_model.name = "AnimatedModel"
	_model.scale = Vector3.ONE * float(definition[1])
	_model.position.y = float(definition[6])
	_model.rotation_degrees.y = 180.0
	_visual_root.add_child(_model)
	max_health = float(definition[5])
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	_current_animation = &""
	_update_primitive_lod_shape()

func _update_primitive_lod_shape() -> void:
	_primitive_body.mesh = ActionDashEnemy.create_lod_mesh(_visual_variant)
	match _visual_variant:
		&"slime":
			_primitive_body.position = Vector3(0.0, 0.52, 0.0)
			_primitive_body.scale = Vector3.ONE
		&"spider":
			_primitive_body.position = Vector3(0.0, 0.62, 0.0)
			_primitive_body.scale = Vector3.ONE
		_:
			_primitive_body.position = Vector3(0.0, 0.82, 0.0)
			_primitive_body.scale = Vector3.ONE

static func create_lod_mesh(variant: StringName) -> Mesh:
	if variant == &"slime":
		var slime := SphereMesh.new()
		slime.radius = 0.8
		slime.height = 1.0
		slime.radial_segments = 8
		slime.rings = 4
		slime.material = _create_lod_material(Color(0.25, 0.82, 0.42), Color(0.02, 0.12, 0.04))
		return slime
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	match variant:
		&"spider":
			_append_lod_box(vertices, indices, Vector3(0.0, 0.0, 0.0), Vector3(1.35, 0.52, 0.9))
			_append_lod_box(vertices, indices, Vector3(0.0, 0.02, -0.58), Vector3(0.62, 0.42, 0.52))
			for side in [-1.0, 1.0]:
				_append_lod_box(vertices, indices, Vector3(side * 0.78, -0.05, -0.32), Vector3(0.72, 0.12, 0.16))
				_append_lod_box(vertices, indices, Vector3(side * 0.82, -0.05, 0.32), Vector3(0.78, 0.12, 0.16))
				_append_lod_box(vertices, indices, Vector3(side * 0.42, -0.05, 0.7), Vector3(0.16, 0.12, 0.72))
			return _build_lod_mesh(vertices, indices, Color(0.48, 0.24, 0.68), Color(0.08, 0.02, 0.12))
		&"bat":
			_append_lod_box(vertices, indices, Vector3(0.0, 0.0, 0.0), Vector3(0.48, 0.72, 0.72))
			_append_lod_box(vertices, indices, Vector3(-0.62, 0.08, 0.0), Vector3(0.9, 0.1, 0.75))
			_append_lod_box(vertices, indices, Vector3(0.62, 0.08, 0.0), Vector3(0.9, 0.1, 0.75))
			return _build_lod_mesh(vertices, indices, Color(0.22, 0.58, 0.86), Color(0.02, 0.08, 0.16))
		_:
			_append_lod_box(vertices, indices, Vector3(0.0, 0.0, 0.0), Vector3(0.62, 1.02, 0.42))
			_append_lod_box(vertices, indices, Vector3(0.0, 0.72, 0.0), Vector3(0.5, 0.44, 0.5))
			_append_lod_box(vertices, indices, Vector3(-0.52, 0.05, 0.0), Vector3(0.16, 0.76, 0.16))
			_append_lod_box(vertices, indices, Vector3(0.52, 0.05, 0.0), Vector3(0.16, 0.76, 0.16))
			return _build_lod_mesh(vertices, indices, Color(0.62, 0.68, 0.72), Color(0.08, 0.1, 0.12))

static func _create_lod_material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission
	return material

static func _build_lod_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, color: Color, emission: Color) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _create_lod_material(color, emission))
	return mesh

static func _append_lod_box(vertices: PackedVector3Array, indices: PackedInt32Array, center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([
		center + Vector3(-half.x, -half.y, -half.z), center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z), center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z), center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z), center + Vector3(-half.x, half.y, half.z)
	]))
	indices.append_array(PackedInt32Array([
		base + 0, base + 1, base + 2, base + 0, base + 2, base + 3,
		base + 4, base + 6, base + 5, base + 4, base + 7, base + 6,
		base + 0, base + 4, base + 5, base + 0, base + 5, base + 1,
		base + 3, base + 2, base + 6, base + 3, base + 6, base + 7,
		base + 0, base + 3, base + 7, base + 0, base + 7, base + 4,
		base + 1, base + 5, base + 6, base + 1, base + 6, base + 2
	]))

func _play_named_animation(keyword: String, blend: float, speed: float) -> void:
	if _animation_player == null:
		return
	var animation := _find_animation(keyword)
	if animation == &"" or (_current_animation == animation and _animation_player.is_playing()):
		return
	_current_animation = animation
	_animation_player.play(animation, blend, speed)

func _find_animation(keyword: String) -> StringName:
	if _animation_player == null:
		return &""
	for animation in _animation_player.get_animation_list():
		if keyword.to_lower() in String(animation).to_lower():
			return animation
	return &""

func _create_death_vfx() -> void:
	_death_vfx = Sprite3D.new()
	_death_vfx.name = "DeathSmoke"
	_death_vfx.texture = DEATH_TEXTURE
	_death_vfx.pixel_size = 0.01
	_death_vfx.modulate = Color(0.65, 0.38, 0.8, 0.85)
	_death_vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_death_vfx.position.y = 0.9
	_visual_root.add_child(_death_vfx)

func _create_hit_vfx() -> void:
	_hit_vfx = Sprite3D.new()
	_hit_vfx.name = "HitSpark"
	_hit_vfx.texture = HIT_TEXTURE
	_hit_vfx.pixel_size = 0.009
	_hit_vfx.modulate = Color(1.0, 0.82, 0.3, 0.9)
	_hit_vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hit_vfx.position.y = 0.9
	_hit_vfx.visible = false
	_visual_root.add_child(_hit_vfx)

class_name ActionDashEnergySpherePower
extends ActionDashRangedPower

@export_category("Energy sphere")
@export var projectile_speed: float = 52.0
@export var projectile_size: float = 1.1
@export var projectile_contact_margin: float = 0.14
@export var projectile_lifetime: float = 1.8
@export var initial_target_cone_radius: float = 6.0
@export var chain_search_radius: float = 12.0
@export_range(1, 3, 1) var maximum_chain_targets: int = 3
@export var homing_turn_rate: float = 9.0
@export var debug_chain_targeting: bool = false

func activate(world: Node, origin: Vector3, target: Vector3) -> bool:
	if projectile_scene == null or not is_ready():
		return false
	var direction := target - origin
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()
	var initial_target := _find_initial_target(world, origin, target)
	if initial_target == null:
		if debug_chain_targeting:
			print("[EnergySphere] no initial target in aim cone")
		return false

	# One projectile today; projectile_count is already externally adjustable for future powers/upgrades.
	for _index in projectile_count:
		var projectile := projectile_scene.instantiate()
		world.add_child(projectile)
		projectile.global_position = origin
		projectile.setup_guided(
			direction,
			projectile_speed,
			damage,
			projectile_size,
			projectile_contact_margin,
			projectile_lifetime,
			initial_target,
			maximum_chain_targets,
			chain_search_radius,
			homing_turn_rate,
			debug_chain_targeting
		)
	_begin_cooldown()
	activated.emit(origin, direction)
	return true

func _find_initial_target(world: Node, origin: Vector3, aim_point: Vector3) -> Node:
	var aim_direction := (aim_point - origin).normalized()
	var ray_length := maxf(origin.distance_to(aim_point), projectile_speed * 1.15)
	var ray_end := origin + aim_direction * ray_length
	var best_target: Node
	var best_score := INF
	for candidate in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate.has_method("get_projectile_hit_position"):
			continue
		if candidate.has_method("is_defeated") and candidate.is_defeated():
			continue
		var candidate_position: Vector3 = candidate.get_projectile_hit_position()
		var along := (candidate_position - origin).dot(aim_direction)
		if along <= 0.0 or along > ray_length:
			continue
		var weak_point_hit := false
		var body_hit := false
		if candidate.has_method("get_projectile_hit_zone"):
			var zone: StringName = candidate.get_projectile_hit_zone(origin, ray_end, projectile_size + projectile_contact_margin)
			weak_point_hit = zone == &"weak_point"
			body_hit = zone == &"body"
		var closest := Geometry3D.get_closest_point_to_segment(candidate_position, origin, ray_end)
		var lateral_distance := closest.distance_to(candidate_position)
		var candidate_radius := float(candidate.get_projectile_hit_radius()) if candidate.has_method("get_projectile_hit_radius") else 0.8
		var cone_limit := initial_target_cone_radius + candidate_radius
		if not weak_point_hit and not body_hit and lateral_distance > cone_limit:
			continue
		var score := lateral_distance * 3.0 + along * 0.02
		# A weak point deliberately on the cursor ray wins over the boss body or a nearby mob.
		if weak_point_hit:
			score -= 10000.0
		elif body_hit:
			score -= 100.0
		if score < best_score:
			best_score = score
			best_target = candidate
	return best_target

func apply_runtime_modifiers(modifiers: Dictionary) -> void:
	super.apply_runtime_modifiers(modifiers)
	if modifiers.has("speed"):
		projectile_speed = maxf(float(modifiers["speed"]), 0.0)
	if modifiers.has("size"):
		projectile_size = maxf(float(modifiers["size"]), 0.05)
	if modifiers.has("lifetime"):
		projectile_lifetime = maxf(float(modifiers["lifetime"]), 0.05)

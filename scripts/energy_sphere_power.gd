class_name ActionDashEnergySpherePower
extends ActionDashRangedPower

@export_category("Energy sphere")
@export var projectile_speed: float = 52.0
@export var projectile_size: float = 1.6
@export var projectile_contact_margin: float = 0.2
@export var projectile_lifetime: float = 1.8

func activate(world: Node, origin: Vector3, target: Vector3) -> bool:
	if projectile_scene == null or not is_ready():
		return false
	var direction := target - origin
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()

	# One projectile today; projectile_count is already externally adjustable for future powers/upgrades.
	for _index in projectile_count:
		var projectile := projectile_scene.instantiate()
		world.add_child(projectile)
		projectile.global_position = origin
		projectile.setup(direction, projectile_speed, damage, projectile_size, projectile_contact_margin, projectile_lifetime)
	_begin_cooldown()
	activated.emit(origin, direction)
	return true

func apply_runtime_modifiers(modifiers: Dictionary) -> void:
	super.apply_runtime_modifiers(modifiers)
	if modifiers.has("speed"):
		projectile_speed = maxf(float(modifiers["speed"]), 0.0)
	if modifiers.has("size"):
		projectile_size = maxf(float(modifiers["size"]), 0.05)
	if modifiers.has("lifetime"):
		projectile_lifetime = maxf(float(modifiers["lifetime"]), 0.05)

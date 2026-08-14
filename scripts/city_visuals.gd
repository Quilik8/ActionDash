class_name ActionDashCityVisuals
extends Node3D

const CITY_ROOT := "res://assets/environment/city/kenney_city_kit_commercial/"
const CITY_COLORMAP := preload("res://assets/environment/city/kenney_city_kit_commercial/Textures/colormap.png")
const BUILDINGS := [
	"building-a.glb", "building-b.glb", "building-c.glb", "building-d.glb",
	"building-e.glb", "building-f.glb", "building-g.glb", "building-h.glb",
	"building-i.glb", "building-j.glb", "building-k.glb", "building-l.glb",
	"building-m.glb", "building-n.glb", "building-skyscraper-a.glb",
	"building-skyscraper-b.glb", "building-skyscraper-c.glb",
	"building-skyscraper-d.glb", "building-skyscraper-e.glb",
]
const HORIZON_BUILDINGS := [
	"low-detail-building-a.glb", "low-detail-building-b.glb", "low-detail-building-c.glb",
	"low-detail-building-d.glb", "low-detail-building-e.glb", "low-detail-building-f.glb",
	"low-detail-building-g.glb", "low-detail-building-h.glb", "low-detail-building-i.glb",
	"low-detail-building-j.glb", "low-detail-building-k.glb", "low-detail-building-l.glb",
	"low-detail-building-m.glb", "low-detail-building-n.glb",
	"low-detail-building-wide-a.glb", "low-detail-building-wide-b.glb",
]
const BUILDING_PALETTE := [
	Color(0.95, 0.5, 0.38),
	Color(0.35, 0.65, 0.92),
	Color(0.98, 0.75, 0.3),
	Color(0.38, 0.76, 0.58),
	Color(0.68, 0.5, 0.88),
	Color(0.9, 0.58, 0.74),
]

var _asphalt_material: StandardMaterial3D
var _plaza_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_create_street_surface()
	_create_playable_blocks()
	_create_horizon()

func get_building_count() -> int:
	return get_tree().get_nodes_in_group("city_buildings").size()

func get_collidable_building_count() -> int:
	return get_tree().get_nodes_in_group("city_building_colliders").size()

func _create_materials() -> void:
	_asphalt_material = StandardMaterial3D.new()
	_asphalt_material.albedo_color = Color(0.055, 0.065, 0.085)
	_asphalt_material.roughness = 0.96
	_plaza_material = StandardMaterial3D.new()
	_plaza_material.albedo_color = Color(0.28, 0.3, 0.33)
	_plaza_material.roughness = 0.9

func _create_street_surface() -> void:
	_add_surface("CentralAvenueNS", Vector3(0, 0.115, 0), Vector3(34, 0.03, 410), _asphalt_material)
	_add_surface("CentralAvenueEW", Vector3(0, 0.117, 0), Vector3(218, 0.032, 32), _asphalt_material)
	_add_surface("WestAvenueNS", Vector3(-58, 0.116, 0), Vector3(22, 0.031, 390), _asphalt_material)
	_add_surface("EastAvenueNS", Vector3(58, 0.116, 0), Vector3(22, 0.031, 390), _asphalt_material)
	_add_surface("NorthAvenueEW", Vector3(0, 0.118, -112), Vector3(205, 0.034, 22), _asphalt_material)
	_add_surface("SouthAvenueEW", Vector3(0, 0.118, 112), Vector3(205, 0.034, 22), _asphalt_material)
	_add_surface("CentralPlaza", Vector3(0, 0.12, 0), Vector3(48, 0.04, 48), _plaza_material)
	_add_surface("NorthStagingArea", Vector3(0, 0.12, -160), Vector3(48, 0.04, 42), _plaza_material)
	_add_surface("SouthStagingArea", Vector3(0, 0.12, 160), Vector3(48, 0.04, 42), _plaza_material)

func _create_playable_blocks() -> void:
	var placements: Array[Vector3] = []
	for z in [-174.0, -138.0, -96.0, -54.0, 54.0, 96.0, 138.0, 174.0]:
		placements.append(Vector3(-92.0, 0.1, z))
		placements.append(Vector3(92.0, 0.1, z))
	for x in [-76.0, -42.0, 42.0, 76.0]:
		placements.append(Vector3(x, 0.1, -194.0))
		placements.append(Vector3(x, 0.1, 194.0))
	placements.append_array([
		Vector3(-72, 0.1, -78), Vector3(-72, 0.1, 78),
		Vector3(72, 0.1, -78), Vector3(72, 0.1, 78),
	])
	for index in placements.size():
		var scale_value := 10.0 + float(index % 4) * 1.15
		var yaw := float((index * 90) % 360)
		_add_building(BUILDINGS[index % BUILDINGS.size()], placements[index], scale_value, yaw, true, index)

func _create_horizon() -> void:
	var placements: Array[Vector3] = []
	for z in [-205.0, -155.0, -105.0, -55.0, 5.0, 55.0, 105.0, 155.0, 205.0]:
		placements.append(Vector3(-126.0, 0.0, z))
		placements.append(Vector3(126.0, 0.0, z))
	for x in [-95.0, -55.0, -15.0, 25.0, 65.0, 95.0]:
		placements.append(Vector3(x, 0.0, -236.0))
		placements.append(Vector3(x, 0.0, 236.0))
	for index in placements.size():
		var scale_value := 11.0 + float(index % 5) * 1.5
		_add_building(HORIZON_BUILDINGS[index % HORIZON_BUILDINGS.size()], placements[index], scale_value, float((index * 90) % 360), false, index + 2)

func _add_building(file_name: String, world_position: Vector3, scale_value: float, yaw: float, collidable: bool, palette_index: int) -> void:
	var packed := load(CITY_ROOT + file_name) as PackedScene
	if packed == null:
		push_warning("City: no se pudo cargar " + file_name)
		return
	var holder: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	holder.name = file_name.get_basename().to_pascal_case()
	holder.position = world_position
	holder.rotation_degrees.y = yaw
	holder.add_to_group("city_buildings")
	if collidable:
		holder.add_to_group("city_building_colliders")
		(holder as StaticBody3D).collision_layer = 1
		(holder as StaticBody3D).collision_mask = 1
	add_child(holder)
	var model := packed.instantiate() as Node3D
	model.scale = Vector3.ONE * scale_value
	holder.add_child(model)
	_apply_building_color(model, palette_index, not collidable)
	if collidable:
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var visual_bounds := _get_bounds_relative_to(model, holder)
		box.size = Vector3(
			maxf(visual_bounds.size.x * 1.12, 2.0),
			maxf(visual_bounds.size.y + 0.5, 3.0),
			maxf(visual_bounds.size.z * 1.12, 2.0)
		)
		shape_node.shape = box
		shape_node.position = visual_bounds.get_center()
		holder.add_child(shape_node)
		holder.set_meta("visual_bounds_size", visual_bounds.size)
		holder.set_meta("collision_size", box.size)

func _get_bounds_relative_to(model: Node3D, relative_to: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var relative_inverse := relative_to.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_transform := relative_inverse * mesh_instance.global_transform
		var local_bounds: AABB = local_transform * mesh_instance.get_aabb()
		result = local_bounds if first else result.merge(local_bounds)
		first = false
	return result

func _apply_building_color(model: Node3D, palette_index: int, horizon: bool) -> void:
	var tint: Color = BUILDING_PALETTE[palette_index % BUILDING_PALETTE.size()]
	if horizon:
		tint = tint.lerp(Color(0.34, 0.39, 0.5), 0.38)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		var colored := source.duplicate() as StandardMaterial3D if source != null else StandardMaterial3D.new()
		colored.albedo_color = colored.albedo_color * tint
		colored.albedo_texture = CITY_COLORMAP
		colored.roughness = maxf(colored.roughness, 0.72)
		mesh_instance.material_override = colored

func _add_surface(node_name: String, surface_position: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = surface_position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

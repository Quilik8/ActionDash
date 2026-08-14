class_name ActionDashCityVisuals
extends Node3D

const CITY_ROOT := "res://assets/environment/city/kenney_city_kit_commercial/"
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
	_add_surface("CentralAvenueNS", Vector3(0, 0.115, 0), Vector3(34, 0.03, 238), _asphalt_material)
	_add_surface("CentralAvenueEW", Vector3(0, 0.117, 0), Vector3(298, 0.032, 32), _asphalt_material)
	_add_surface("WestAvenueNS", Vector3(-72, 0.116, 0), Vector3(24, 0.031, 220), _asphalt_material)
	_add_surface("EastAvenueNS", Vector3(72, 0.116, 0), Vector3(24, 0.031, 220), _asphalt_material)
	_add_surface("NorthAvenueEW", Vector3(0, 0.118, -62), Vector3(280, 0.034, 22), _asphalt_material)
	_add_surface("SouthAvenueEW", Vector3(0, 0.118, 62), Vector3(280, 0.034, 22), _asphalt_material)
	_add_surface("CentralPlaza", Vector3(0, 0.12, 0), Vector3(48, 0.04, 48), _plaza_material)
	_add_surface("WestPlaza", Vector3(-72, 0.12, 62), Vector3(34, 0.04, 34), _plaza_material)
	_add_surface("EastPlaza", Vector3(72, 0.12, -62), Vector3(34, 0.04, 34), _plaza_material)

func _create_playable_blocks() -> void:
	var placements: Array[Vector3] = []
	for z in [-88.0, -52.0, -18.0, 22.0, 56.0, 90.0]:
		placements.append(Vector3(-132.0, 0.1, z))
		placements.append(Vector3(132.0, 0.1, z))
	for x in [-108.0, -76.0, -42.0, 42.0, 76.0, 108.0]:
		placements.append(Vector3(x, 0.1, -108.0))
		placements.append(Vector3(x, 0.1, 108.0))
	placements.append_array([
		Vector3(-102, 0.1, -74), Vector3(-102, 0.1, 74),
		Vector3(102, 0.1, -74), Vector3(102, 0.1, 74),
		Vector3(-44, 0.1, -82), Vector3(44, 0.1, 82),
	])
	for index in placements.size():
		var scale_value := 10.0 + float(index % 4) * 1.15
		var yaw := float((index * 90) % 360)
		_add_building(BUILDINGS[index % BUILDINGS.size()], placements[index], scale_value, yaw, true)

func _create_horizon() -> void:
	var placements: Array[Vector3] = []
	for z in [-118.0, -78.0, -38.0, 2.0, 42.0, 82.0, 122.0]:
		placements.append(Vector3(-166.0, 0.0, z))
		placements.append(Vector3(166.0, 0.0, z))
	for x in [-130.0, -90.0, -50.0, -10.0, 30.0, 70.0, 110.0]:
		placements.append(Vector3(x, 0.0, -142.0))
		placements.append(Vector3(x, 0.0, 142.0))
	for index in placements.size():
		var scale_value := 11.0 + float(index % 5) * 1.5
		_add_building(HORIZON_BUILDINGS[index % HORIZON_BUILDINGS.size()], placements[index], scale_value, float((index * 90) % 360), false)

func _add_building(file_name: String, world_position: Vector3, scale_value: float, yaw: float, collidable: bool) -> void:
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
	if collidable:
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var width := 11.0 + float(holder.get_index() % 3) * 2.0
		var depth := 11.0 + float((holder.get_index() + 1) % 3) * 2.0
		var height := 14.0 + float(holder.get_index() % 5) * 3.0
		box.size = Vector3(width, height, depth)
		shape_node.shape = box
		shape_node.position.y = height * 0.5
		holder.add_child(shape_node)

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

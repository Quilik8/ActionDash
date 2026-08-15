class_name ActionDashMiningTerrain
extends Node2D

signal block_broken(cell: Vector2i, block_id: StringName, ore_id: StringName, world_position: Vector2, color: Color)

const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export var config: ActionDashMiningConfig

var generation_seed: int
var _blocks := PackedInt32Array()
var _ores := PackedInt32Array()
var _health := PackedFloat32Array()
var _generated: bool = false
var _terrain_image: Image
var _terrain_texture: ImageTexture
var _terrain_sprite: Sprite2D

func generate(seed_value: int) -> void:
	generation_seed = seed_value
	var count := config.grid_width * config.get_total_rows()
	_blocks.resize(count)
	_ores.resize(count)
	_health.resize(count)
	_ores.fill(-1)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for y in config.get_total_rows():
		for x in config.grid_width:
			var block_index := _pick_layer_block(random, 1 if y < config.layer_1_rows else 2)
			_set_cell(Vector2i(x, y), block_index, -1)
	_generate_veins(random, 0, config.layer_1_rows, config.layer_1_veins, config.layer_1_ore_weights, 1)
	_generate_veins(random, config.layer_1_rows, config.get_total_rows(), config.layer_2_veins, config.layer_2_ore_weights, 2)
	_carve_entry()
	_generated = true
	_rebuild_texture()
	queue_redraw()

func is_generated() -> bool:
	return _generated

func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(floori(local.x / config.cell_size + config.grid_width * 0.5), floori(local.y / config.cell_size))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2((float(cell.x) - config.grid_width * 0.5 + 0.5) * config.cell_size, (float(cell.y) + 0.5) * config.cell_size))

func is_solid_cell(cell: Vector2i) -> bool:
	var index := _index(cell)
	if index < 0:
		return cell.x < 0 or cell.x >= config.grid_width or cell.y >= config.get_total_rows()
	return index >= 0 and _blocks[index] >= 0

func is_solid_at(world_position: Vector2) -> bool:
	return is_solid_cell(world_to_cell(world_position))

func drill_cell(cell: Vector2i, damage: float) -> bool:
	var index := _index(cell)
	if index < 0 or _blocks[index] < 0:
		return false
	_health[index] = maxf(_health[index] - maxf(damage, 0.0), 0.0)
	if _health[index] > 0.0:
		return false
	var block_index := _blocks[index]
	var ore_index := _ores[index]
	var block := config.blocks[block_index]
	var ore_id: StringName = config.ores[ore_index].id if ore_index >= 0 else &""
	_blocks[index] = -1
	_ores[index] = -1
	_health[index] = 0.0
	block_broken.emit(cell, block.id, ore_id, cell_to_world(cell), block.color)
	_update_texture_cell(cell)
	queue_redraw()
	return true

func get_cell_hardness(cell: Vector2i) -> float:
	var index := _index(cell)
	return config.blocks[_blocks[index]].hardness if index >= 0 and _blocks[index] >= 0 else 0.0

func get_cell_health_ratio(cell: Vector2i) -> float:
	var index := _index(cell)
	if index < 0 or _blocks[index] < 0:
		return 0.0
	return _health[index] / maxf(config.blocks[_blocks[index]].hardness, 0.001)

func get_entry_position() -> Vector2:
	return cell_to_world(Vector2i(floori(float(config.grid_width) / 2.0), 1))

func is_at_exit(world_position: Vector2) -> bool:
	var cell := world_to_cell(world_position)
	return cell.y <= 2 and absi(cell.x - floori(float(config.grid_width) / 2.0)) <= 2

func get_layer_at(world_position: Vector2) -> int:
	return 1 if world_to_cell(world_position).y < config.layer_1_rows else 2

func get_depth_row(world_position: Vector2) -> int:
	return maxi(world_to_cell(world_position).y, 0)

func find_nearest_open_position(preferred_world: Vector2) -> Vector2:
	var origin := world_to_cell(preferred_world)
	if not is_solid_cell(origin):
		return cell_to_world(origin)
	for radius in range(1, 5):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := origin + Vector2i(x, y)
				if _index(candidate) >= 0 and not is_solid_cell(candidate):
					return cell_to_world(candidate)
	return get_entry_position()

func get_generation_stats() -> Dictionary:
	var layer_stats := {
		1: {&"soil": 0, &"compact_soil": 0, &"rock": 0, &"ore_block": 0},
		2: {&"soil": 0, &"compact_soil": 0, &"rock": 0, &"ore_block": 0},
	}
	var ore_counts: Dictionary = {}
	var layer_ores := {1: {}, 2: {}}
	for y in config.get_total_rows():
		var layer := 1 if y < config.layer_1_rows else 2
		for x in config.grid_width:
			var index := _index(Vector2i(x, y))
			if _blocks[index] >= 0:
				var block_id := config.blocks[_blocks[index]].id
				layer_stats[layer][block_id] = int(layer_stats[layer].get(block_id, 0)) + 1
			if _ores[index] >= 0:
				var ore_id := config.ores[_ores[index]].id
				ore_counts[ore_id] = int(ore_counts.get(ore_id, 0)) + 1
				layer_ores[layer][ore_id] = int(layer_ores[layer].get(ore_id, 0)) + 1
	return {"layers": layer_stats, "ores": ore_counts, "layer_ores": layer_ores, "seed": generation_seed}

func get_generation_signature() -> int:
	return hash([_blocks, _ores])

func find_first_cell(block_id: StringName, layer: int = 0) -> Vector2i:
	var start_row := 0 if layer <= 1 else config.layer_1_rows
	var end_row := config.get_total_rows() if layer == 0 or layer == 2 else config.layer_1_rows
	for y in range(start_row, end_row):
		for x in config.grid_width:
			var cell := Vector2i(x, y)
			var index := _index(cell)
			if _blocks[index] >= 0 and config.blocks[_blocks[index]].id == block_id:
				return cell
	return Vector2i(-1, -1)

func get_ore_cluster_sizes() -> Array[int]:
	var result: Array[int] = []
	var visited: Dictionary = {}
	for y in config.get_total_rows():
		for x in config.grid_width:
			var cell := Vector2i(x, y)
			var index := _index(cell)
			if _ores[index] < 0 or visited.has(cell):
				continue
			var ore_index := _ores[index]
			var pending: Array[Vector2i] = [cell]
			var size := 0
			visited[cell] = true
			while not pending.is_empty():
				var current: Vector2i = pending.pop_back()
				size += 1
				for direction in CARDINAL_DIRECTIONS:
					var neighbor: Vector2i = current + direction
					var neighbor_index := _index(neighbor)
					if neighbor_index >= 0 and not visited.has(neighbor) and _ores[neighbor_index] == ore_index:
						visited[neighbor] = true
						pending.append(neighbor)
			result.append(size)
	return result

func _pick_layer_block(random: RandomNumberGenerator, layer: int) -> int:
	var soil := config.layer_1_soil_weight if layer == 1 else config.layer_2_soil_weight
	var compact := config.layer_1_compact_weight if layer == 1 else config.layer_2_compact_weight
	var roll := random.randf()
	if roll < soil:
		return config.get_block_index(&"soil")
	if roll < soil + compact:
		return config.get_block_index(&"compact_soil")
	return config.get_block_index(&"rock")

func _carve_entry() -> void:
	var center := floori(float(config.grid_width) / 2.0)
	for y in mini(4, config.get_total_rows()):
		for x in range(center - 2, center + 3):
			_set_cell(Vector2i(x, y), -1, -1)

func _generate_veins(random: RandomNumberGenerator, start_row: int, end_row: int, vein_count: int, ore_weights: Array[float], layer: int) -> void:
	var ore_block_index := config.get_block_index(&"ore_block")
	for vein_index in vein_count:
		var guaranteed_count := 2 if layer == 1 else 3
		var ore_index := vein_index if vein_index < guaranteed_count else _pick_weighted_index(random, ore_weights)
		var current := Vector2i(random.randi_range(2, config.grid_width - 3), random.randi_range(start_row, end_row - 1))
		var target_size := random.randi_range(config.minimum_vein_size, config.maximum_vein_size)
		var placed: Dictionary = {}
		for _cell in target_size:
			current.x = clampi(current.x, 1, config.grid_width - 2)
			current.y = clampi(current.y, start_row, end_row - 1)
			_set_cell(current, ore_block_index, ore_index)
			placed[current] = true
			var moved := false
			var first_direction := random.randi_range(0, CARDINAL_DIRECTIONS.size() - 1)
			for offset in CARDINAL_DIRECTIONS.size():
				var direction := CARDINAL_DIRECTIONS[(first_direction + offset) % CARDINAL_DIRECTIONS.size()]
				var next: Vector2i = current + direction
				if next.y >= start_row and next.y < end_row and next.x > 0 and next.x < config.grid_width - 1 and not placed.has(next):
					current = next
					moved = true
					break
			if not moved:
				break

func _pick_weighted_index(random: RandomNumberGenerator, weights: Array[float]) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := random.randf() * maxf(total, 0.001)
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return maxi(weights.size() - 1, 0)

func _set_cell(cell: Vector2i, block_index: int, ore_index: int) -> void:
	var index := _index(cell)
	if index < 0:
		return
	_blocks[index] = block_index
	_ores[index] = ore_index
	_health[index] = config.blocks[block_index].hardness if block_index >= 0 else 0.0

func _index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= config.grid_width or cell.y < 0 or cell.y >= config.get_total_rows():
		return -1
	return cell.y * config.grid_width + cell.x

func _draw() -> void:
	if not _generated:
		return
	var width_pixels := config.grid_width * config.cell_size
	var divider_y := config.layer_1_rows * config.cell_size
	draw_line(Vector2(-width_pixels * 0.5, divider_y), Vector2(width_pixels * 0.5, divider_y), Color(0.8, 0.35, 0.15, 0.6), 2.0)
	var exit_center := cell_to_world(Vector2i(floori(float(config.grid_width) / 2.0), 0))
	draw_rect(Rect2(to_local(exit_center) - Vector2(55, 20), Vector2(110, 40)), Color(0.15, 0.8, 1.0, 0.18), false, 3.0)

func _rebuild_texture() -> void:
	var cell_pixels := maxi(roundi(config.cell_size), 1)
	var width_pixels := config.grid_width * cell_pixels
	var height_pixels := config.get_total_rows() * cell_pixels + cell_pixels * 2
	_terrain_image = Image.create(width_pixels, height_pixels, false, Image.FORMAT_RGBA8)
	_terrain_image.fill(Color(0.055, 0.045, 0.055, 1.0))
	for y in config.get_total_rows():
		for x in config.grid_width:
			_update_image_cell(Vector2i(x, y), cell_pixels)
	_terrain_texture = ImageTexture.create_from_image(_terrain_image)
	if not is_instance_valid(_terrain_sprite):
		_terrain_sprite = Sprite2D.new()
		_terrain_sprite.name = "TerrainTexture"
		_terrain_sprite.z_index = -1
		_terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_terrain_sprite)
	_terrain_sprite.texture = _terrain_texture
	_terrain_sprite.position = Vector2(0.0, float(config.get_total_rows() * cell_pixels) * 0.5 - float(cell_pixels))

func _update_texture_cell(cell: Vector2i) -> void:
	if _terrain_image == null or _terrain_texture == null:
		return
	_update_image_cell(cell, maxi(roundi(config.cell_size), 1))
	_terrain_texture.update(_terrain_image)

func _update_image_cell(cell: Vector2i, cell_pixels: int) -> void:
	var image_position := Vector2i(cell.x * cell_pixels + 1, (cell.y + 2) * cell_pixels + 1)
	var inner_size := maxi(cell_pixels - 2, 1)
	var index := _index(cell)
	var cell_color := Color(0.055, 0.045, 0.055, 1.0)
	if index >= 0 and _blocks[index] >= 0:
		cell_color = config.blocks[_blocks[index]].color
	_terrain_image.fill_rect(Rect2i(image_position, Vector2i(inner_size, inner_size)), cell_color)
	if index >= 0 and _ores[index] >= 0:
		var ore_size := maxi(floori(float(cell_pixels) / 2.0), 2)
		var ore_position := Vector2i(cell.x * cell_pixels + floori(float(cell_pixels - ore_size) / 2.0), (cell.y + 2) * cell_pixels + floori(float(cell_pixels - ore_size) / 2.0))
		_terrain_image.fill_rect(Rect2i(ore_position, Vector2i(ore_size, ore_size)), config.ores[_ores[index]].color)

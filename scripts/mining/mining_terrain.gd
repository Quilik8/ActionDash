class_name ActionDashMiningTerrain
extends Node2D

signal block_broken(cell: Vector2i, block_id: StringName, ore_id: StringName, world_position: Vector2, color: Color)
signal ore_discovered(ore_id: StringName, world_position: Vector2, color: Color)

const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const TERRAIN_RENDER_SCALE: float = 0.5
const TERRAIN_CHUNK_WIDTH: int = 8
const TERRAIN_CHUNK_HEIGHT: int = 9
const HIDDEN_COLOR := Color(0.012, 0.016, 0.022, 1.0)
const EXCAVATED_COLOR := Color(0.075, 0.065, 0.08, 1.0)

enum VisibilityState {
	HIDDEN,
	EXPOSED,
	EXCAVATED,
}

@export var config: ActionDashMiningConfig

var generation_seed: int
var _blocks := PackedInt32Array()
var _ores := PackedInt32Array()
var _health := PackedFloat32Array()
var _visibility := PackedInt32Array()
var _generated: bool = false
var _chunk_images: Array[Image] = []
var _chunk_textures: Array[ImageTexture] = []
var _chunk_sprites: Array[Sprite2D] = []
var _chunk_cell_pixels: int = 1
var _dirty_chunks: Dictionary = {}

func generate(seed_value: int) -> void:
	generation_seed = seed_value
	var count := config.grid_width * config.get_total_rows()
	_blocks.resize(count)
	_ores.resize(count)
	_health.resize(count)
	_visibility.resize(count)
	_ores.fill(-1)
	_visibility.fill(VisibilityState.HIDDEN)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for y in config.get_total_rows():
		for x in config.grid_width:
			var block_index := _pick_layer_block(random, 1 if y < config.layer_1_rows else 2)
			_set_cell(Vector2i(x, y), block_index, -1)
	_generate_terrain_structures(random)
	_generate_veins(random, 0, config.layer_1_rows, 1)
	_generate_veins(random, config.layer_1_rows, config.get_total_rows(), 2)
	_carve_entry()
	_initialize_visibility()
	_generated = true
	_rebuild_chunks()
	queue_redraw()

func is_generated() -> bool:
	return _generated

func get_chunk_count() -> int:
	return _chunk_sprites.size()

func get_visibility(cell: Vector2i) -> int:
	var index := _index(cell)
	return _visibility[index] if index >= 0 else VisibilityState.HIDDEN

func is_cell_hidden(cell: Vector2i) -> bool:
	return get_visibility(cell) == VisibilityState.HIDDEN

func is_cell_exposed(cell: Vector2i) -> bool:
	return get_visibility(cell) == VisibilityState.EXPOSED

func is_cell_excavated(cell: Vector2i) -> bool:
	return get_visibility(cell) == VisibilityState.EXCAVATED

func get_visible_ore_id(cell: Vector2i) -> StringName:
	var index := _index(cell)
	if index < 0 or _visibility[index] != VisibilityState.EXPOSED or _ores[index] < 0:
		return &""
	return config.ores[_ores[index]].id

func get_ore_id_at(cell: Vector2i) -> StringName:
	var index := _index(cell)
	if index < 0 or _ores[index] < 0:
		return &""
	return config.ores[_ores[index]].id

func get_discovered_ore_count() -> int:
	var count := 0
	for index in _visibility.size():
		if _visibility[index] == VisibilityState.EXPOSED and _ores[index] >= 0:
			count += 1
	return count

func find_first_hidden_ore_cell() -> Vector2i:
	for y in range(1, config.get_total_rows() - 1):
		for x in range(1, config.grid_width - 1):
			var cell := Vector2i(x, y)
			var index := _index(cell)
			if index >= 0 and _ores[index] >= 0 and _visibility[index] == VisibilityState.HIDDEN:
				return cell
	return Vector2i(-1, -1)

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
	_update_visibility_after_excavation(cell, true)
	block_broken.emit(cell, block.id, ore_id, cell_to_world(cell), block.color)
	_flush_dirty_chunks()
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

func _generate_terrain_structures(random: RandomNumberGenerator) -> void:
	var compact_index := config.get_block_index(&"compact_soil")
	var soil_index := config.get_block_index(&"soil")
	var rock_index := config.get_block_index(&"rock")
	_generate_pockets(random, 0, config.layer_1_rows, config.layer_1_compact_pockets, compact_index, 1, 2)
	_generate_pockets(random, config.layer_1_rows, config.get_total_rows(), config.layer_2_compact_pockets, compact_index, 1, 3)
	_generate_pockets(random, config.layer_1_rows, config.get_total_rows(), config.layer_2_soft_pockets, soil_index, 1, 2)
	_generate_rock_bands(random, config.layer_1_rows, config.get_total_rows(), config.layer_2_rock_bands, rock_index)

func _generate_pockets(random: RandomNumberGenerator, start_row: int, end_row: int, pocket_count: int, block_index: int, min_radius: int, max_radius: int) -> void:
	if block_index < 0:
		return
	for _pocket in pocket_count:
		var center := Vector2i(random.randi_range(2, config.grid_width - 3), random.randi_range(start_row, end_row - 1))
		var radius := random.randi_range(min_radius, max_radius)
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var offset := Vector2(x - center.x, y - center.y)
				if offset.length_squared() <= float(radius * radius) and y >= start_row and y < end_row and x > 0 and x < config.grid_width - 1:
					_set_cell(Vector2i(x, y), block_index, -1)

func _generate_rock_bands(random: RandomNumberGenerator, start_row: int, end_row: int, band_count: int, block_index: int) -> void:
	if block_index < 0:
		return
	for _band in band_count:
		var y := random.randi_range(start_row + 1, end_row - 2)
		var start_x := random.randi_range(2, config.grid_width - 10)
		var length := random.randi_range(5, 10)
		for x in range(start_x, mini(start_x + length, config.grid_width - 1)):
			_set_cell(Vector2i(x, y), block_index, -1)
			if random.randf() > 0.55 and y + 1 < end_row:
				_set_cell(Vector2i(x, y + 1), block_index, -1)

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

func _initialize_visibility() -> void:
	var center := floori(float(config.grid_width) / 2.0)
	for y in mini(4, config.get_total_rows()):
		for x in range(center - 2, center + 3):
			_update_visibility_after_excavation(Vector2i(x, y), false)

func _update_visibility_after_excavation(cell: Vector2i, emit_discovery: bool) -> void:
	_set_visibility(cell, VisibilityState.EXCAVATED, emit_discovery)
	for direction in CARDINAL_DIRECTIONS:
		var neighbor := cell + direction
		var neighbor_index := _index(neighbor)
		if neighbor_index < 0:
			continue
		if _blocks[neighbor_index] >= 0:
			_set_visibility(neighbor, VisibilityState.EXPOSED, emit_discovery)
		else:
			_set_visibility(neighbor, VisibilityState.EXCAVATED, emit_discovery)

func _set_visibility(cell: Vector2i, state: int, emit_discovery: bool) -> void:
	var index := _index(cell)
	if index < 0 or _visibility[index] == state:
		return
	var was_hidden := _visibility[index] == VisibilityState.HIDDEN
	_visibility[index] = state
	_mark_chunk_dirty(cell)
	if state == VisibilityState.EXPOSED and was_hidden and emit_discovery and _ores[index] >= 0:
		var ore := config.ores[_ores[index]]
		ore_discovered.emit(ore.id, cell_to_world(cell), ore.color)

func _generate_veins(random: RandomNumberGenerator, start_row: int, end_row: int, layer: int) -> void:
	var ore_block_index := config.get_block_index(&"ore_block")
	for ore_index in config.ores.size():
		var ore := config.ores[ore_index]
		var vein_count := ore.layer_1_vein_count if layer == 1 else ore.layer_2_vein_count
		for _vein in vein_count:
			var placement_end := end_row if ore.preferred_layer == layer else mini(end_row, start_row + maxi(floori(float(end_row - start_row) / 2.0), 1))
			var current := Vector2i(random.randi_range(2, config.grid_width - 3), random.randi_range(start_row, placement_end - 1))
			var target_size := random.randi_range(ore.vein_min_size, ore.vein_max_size)
			var placed: Dictionary = {}
			for _cell in target_size:
				current.x = clampi(current.x, 1, config.grid_width - 2)
				current.y = clampi(current.y, start_row, end_row - 1)
				var current_index := _index(current)
				if current_index >= 0 and _ores[current_index] < 0:
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

func _rebuild_chunks() -> void:
	_clear_chunks()
	_dirty_chunks.clear()
	_chunk_cell_pixels = maxi(roundi(config.cell_size * TERRAIN_RENDER_SCALE), 1)
	var chunk_columns := ceili(float(config.grid_width) / float(TERRAIN_CHUNK_WIDTH))
	var chunk_rows := ceili(float(config.get_total_rows()) / float(TERRAIN_CHUNK_HEIGHT))
	for chunk_y in chunk_rows:
		for chunk_x in chunk_columns:
			var start_x := chunk_x * TERRAIN_CHUNK_WIDTH
			var start_y := chunk_y * TERRAIN_CHUNK_HEIGHT
			var chunk_width := mini(TERRAIN_CHUNK_WIDTH, config.grid_width - start_x)
			var chunk_height := mini(TERRAIN_CHUNK_HEIGHT, config.get_total_rows() - start_y)
			var image := Image.create(chunk_width * _chunk_cell_pixels, chunk_height * _chunk_cell_pixels, false, Image.FORMAT_RGB8)
			image.fill(HIDDEN_COLOR)
			for local_y in chunk_height:
				for local_x in chunk_width:
					_paint_cell(image, Vector2i(start_x + local_x, start_y + local_y))
			var texture := ImageTexture.create_from_image(image)
			var sprite := Sprite2D.new()
			sprite.name = "TerrainChunk_%d_%d" % [chunk_x, chunk_y]
			sprite.z_index = -1
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture = texture
			sprite.scale = Vector2.ONE / TERRAIN_RENDER_SCALE
			sprite.position = Vector2(
				(float(start_x) + float(chunk_width) * 0.5 - float(config.grid_width) * 0.5) * config.cell_size,
				(float(start_y) + float(chunk_height) * 0.5) * config.cell_size
			)
			add_child(sprite)
			_chunk_images.append(image)
			_chunk_textures.append(texture)
			_chunk_sprites.append(sprite)

func _clear_chunks() -> void:
	for sprite in _chunk_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_chunk_images.clear()
	_chunk_textures.clear()
	_chunk_sprites.clear()

func _mark_chunk_dirty(cell: Vector2i) -> void:
	if _chunk_textures.is_empty():
		return
	_dirty_chunks[_get_chunk_index(cell)] = true

func _flush_dirty_chunks() -> void:
	if _dirty_chunks.is_empty():
		return
	for chunk_key in _dirty_chunks:
		var chunk_index := int(chunk_key)
		var chunk_x := chunk_index % _get_chunk_columns()
		var chunk_y := floori(float(chunk_index) / float(_get_chunk_columns()))
		var start_x := chunk_x * TERRAIN_CHUNK_WIDTH
		var start_y := chunk_y * TERRAIN_CHUNK_HEIGHT
		var chunk_width := mini(TERRAIN_CHUNK_WIDTH, config.grid_width - start_x)
		var chunk_height := mini(TERRAIN_CHUNK_HEIGHT, config.get_total_rows() - start_y)
		var image := _chunk_images[chunk_index]
		for local_y in chunk_height:
			for local_x in chunk_width:
				_paint_cell(image, Vector2i(start_x + local_x, start_y + local_y))
		_chunk_textures[chunk_index].update(image)
	_dirty_chunks.clear()

func _get_chunk_columns() -> int:
	return ceili(float(config.grid_width) / float(TERRAIN_CHUNK_WIDTH))

func _get_chunk_index(cell: Vector2i) -> int:
	return floori(float(cell.y) / float(TERRAIN_CHUNK_HEIGHT)) * _get_chunk_columns() + floori(float(cell.x) / float(TERRAIN_CHUNK_WIDTH))

func _paint_cell(image: Image, cell: Vector2i) -> void:
	var local_cell := Vector2i(posmod(cell.x, TERRAIN_CHUNK_WIDTH), posmod(cell.y, TERRAIN_CHUNK_HEIGHT))
	var image_position := local_cell * _chunk_cell_pixels
	var cell_rect := Rect2i(image_position, Vector2i(_chunk_cell_pixels, _chunk_cell_pixels))
	var index := _index(cell)
	var state := get_visibility(cell)
	var cell_color := EXCAVATED_COLOR
	if state == VisibilityState.HIDDEN:
		cell_color = HIDDEN_COLOR
	elif state == VisibilityState.EXPOSED and index >= 0 and _blocks[index] >= 0:
		cell_color = _get_display_block_color(cell, config.blocks[_blocks[index]].color)
	image.fill_rect(cell_rect, cell_color)
	if state == VisibilityState.EXPOSED and index >= 0 and _ores[index] >= 0:
		var ore_size := maxi(floori(float(_chunk_cell_pixels) / 2.0), 2)
		var ore_position := image_position + Vector2i(floori(float(_chunk_cell_pixels - ore_size) / 2.0), floori(float(_chunk_cell_pixels - ore_size) / 2.0))
		image.fill_rect(Rect2i(ore_position, Vector2i(ore_size, ore_size)), config.ores[_ores[index]].color)

func _get_display_block_color(cell: Vector2i, base_color: Color) -> Color:
	var layer_tint := Color(0.95, 0.9, 0.82, 1.0) if cell.y < config.layer_1_rows else Color(0.82, 0.9, 1.0, 1.0)
	return Color(base_color.r * layer_tint.r, base_color.g * layer_tint.g, base_color.b * layer_tint.b, 1.0)

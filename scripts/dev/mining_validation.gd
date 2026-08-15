extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_session := root.get_node("/root/RunSession") as ActionDashRunState
	_expect(run_session != null, "RunSession autoload no esta disponible")
	var config := load("res://resources/mining/mining_mvp_config.tres") as ActionDashMiningConfig
	_expect(config != null, "No carga MiningConfig")
	_expect(InputMap.has_action("mining_eject") and InputMap.has_action("mining_toggle"), "Faltan inputs de mineria")

	var mine := (load("res://scenes/mining/mining_mvp.tscn") as PackedScene).instantiate() as ActionDashMiningMVP
	root.add_child(mine)
	await process_frame
	await physics_frame
	var terrain := mine.terrain
	var mech := mine.mech
	var stats := terrain.get_generation_stats()
	var layer_1: Dictionary = stats["layers"][1]
	var layer_2: Dictionary = stats["layers"][2]
	var layer_1_hard := int(layer_1[&"compact_soil"]) + int(layer_1[&"rock"])
	var layer_2_hard := int(layer_2[&"compact_soil"]) + int(layer_2[&"rock"])
	_expect(layer_2_hard > layer_1_hard, "Layer 2 no aumenta compact soil/rock por composicion")
	_expect(int(stats["layer_ores"][1].get(&"voltrita", 0)) > 0 and int(stats["layer_ores"][1].get(&"keronita", 0)) > 0, "Layer 1 no garantiza recursos")
	_expect(int(stats["layer_ores"][2].get(&"nexalita", 0)) > 0, "Layer 2 no garantiza Nexalita")
	var clusters := terrain.get_ore_cluster_sizes()
	_expect(not clusters.is_empty() and clusters.max() >= 2, "Los ores no forman vetas reconocibles")
	var repeat_terrain := ActionDashMiningTerrain.new()
	repeat_terrain.config = config
	repeat_terrain.generate(config.default_seed)
	_expect(repeat_terrain.get_generation_signature() == terrain.get_generation_signature(), "La misma seed no repite la generacion")
	repeat_terrain.free()

	var expected_hardness := {&"soil": 6.0, &"compact_soil": 12.0, &"rock": 24.0, &"ore_block": 16.0}
	for block_id in expected_hardness:
		var cell := terrain.find_first_cell(block_id)
		var hardness: float = expected_hardness[block_id]
		_expect(cell.x >= 0 and is_equal_approx(terrain.get_cell_hardness(cell), hardness), "Dureza incorrecta para %s" % block_id)
		_expect(not terrain.drill_cell(cell, hardness - 0.1), "%s se rompe antes de consumir su dureza" % block_id)
		_expect(terrain.drill_cell(cell, 0.11), "%s no se rompe al completar su dureza" % block_id)
	_expect(expected_hardness[&"soil"] < expected_hardness[&"compact_soil"] and expected_hardness[&"compact_soil"] < expected_hardness[&"rock"], "Las resistencias no diferencian soil/compact/rock")

	var first_drill_cell := Vector2i(floori(float(config.grid_width) / 2.0), 4)
	var movement_start := mech.global_position
	Input.action_press("move_backward")
	for _frame in 210:
		await physics_frame
	Input.action_release("move_backward")
	await physics_frame
	_expect(not terrain.is_solid_cell(first_drill_cell), "Mantener direccion no perfora el primer bloque")
	_expect(mech.global_position.y > movement_start.y + config.cell_size * 2.0, "El meca no avanza por el tunel perforado")

	mech.clear_cargo()
	_expect(mech.try_absorb_ore(&"voltrita") and mech.try_absorb_ore(&"keronita") and mech.try_absorb_ore(&"nexalita"), "No absorbe la secuencia LIFO")
	var ejected: Array[StringName] = [mech.eject_last_ore(), mech.eject_last_ore(), mech.eject_last_ore()]
	_expect(ejected == [&"nexalita", &"keronita", &"voltrita"], "Eject no respeta Nexalita/Keronita/Voltrita")
	_expect(is_equal_approx(mech.get_current_load(), 0.0), "Eject LIFO no libera el peso")
	var loose_after_eject := get_nodes_in_group("mining_loose_ores")
	_expect(loose_after_eject.size() >= 3, "Los ores expulsados no quedan fisicamente en el tunel")
	if not loose_after_eject.is_empty():
		var recoverable := loose_after_eject[0] as ActionDashLooseOre
		var recoverable_id := recoverable.ore_id
		recoverable.pickup_available_msec = 0
		recoverable.global_position = mech.global_position
		await physics_frame
		await physics_frame
		_expect(not mech.get_cargo_stack().is_empty() and mech.get_cargo_stack()[-1] == recoverable_id, "El ore expulsado no puede reabsorberse al final de la pila")
	mech.clear_cargo()
	for node in get_nodes_in_group("mining_loose_ores"):
		node.queue_free()
	await process_frame

	var empty_speed := mech.get_current_speed()
	_expect(mech.get_load_state() == &"EMPTY", "Estado EMPTY incorrecto")
	for _item in 20:
		mech.try_absorb_ore(&"voltrita")
	var light_speed := mech.get_current_speed()
	_expect(mech.get_load_state() == &"LIGHT", "Estado LIGHT incorrecto")
	for _item in 20:
		mech.try_absorb_ore(&"voltrita")
	var heavy_speed := mech.get_current_speed()
	_expect(mech.get_load_state() == &"HEAVY", "Estado HEAVY incorrecto")
	for _item in 20:
		mech.try_absorb_ore(&"voltrita")
	var full_speed := mech.get_current_speed()
	_expect(mech.get_load_state() == &"FULL" and is_equal_approx(mech.get_current_load(), config.capacity), "Estado FULL/capacidad incorrecto")
	_expect(empty_speed > light_speed and light_speed > heavy_speed and heavy_speed > full_speed, "La carga no reduce velocidad progresivamente")
	_expect(full_speed >= config.base_speed * 0.65, "FULL vuelve insoportable el regreso")
	var blocked_ore := mine.spawn_loose_ore(&"keronita", mech.global_position)
	await physics_frame
	await physics_frame
	_expect(is_instance_valid(blocked_ore) and blocked_ore.is_inside_tree(), "El ore desaparece cuando no hay capacidad")

	mech.clear_cargo()
	mech.try_absorb_ore(&"voltrita")
	mech.try_absorb_ore(&"keronita")
	mech.try_absorb_ore(&"nexalita")
	mech.global_position = terrain.get_entry_position()
	run_session.reset_resources()
	_expect(mine.deposit_at_surface(false), "No deposita en la salida superior")
	_expect(mech.get_cargo_stack().is_empty() and is_equal_approx(mech.get_current_load(), 0.0), "Depositar no vacia el cargo")
	_expect(run_session.extracted_value == 102, "Valor depositado incorrecto")
	_expect(int(run_session.run_resources.get(&"voltrita", 0)) == 1 and int(run_session.run_resources.get(&"keronita", 0)) == 1 and int(run_session.run_resources.get(&"nexalita", 0)) == 1, "Cantidades depositadas incorrectas o duplicadas")
	var deposited_count := 0
	for amount in run_session.run_resources.values():
		deposited_count += int(amount)
	_expect(deposited_count == 3, "Ores sueltos cuentan como extraidos")

	current_scene = null
	mine.queue_free()
	await process_frame
	run_session.reset_mining_run()
	var surface := (load("res://scenes/gameplay/playground.tscn") as PackedScene).instantiate()
	root.add_child(surface)
	current_scene = surface
	await process_frame
	await physics_frame
	var controller := surface.get_node("PhaseController") as ActionDashPhaseController
	var phase_state := controller.get_state()
	var phase_time := controller.get_time_remaining()
	_expect(run_session.enter_mining(), "No entra de 3D a Mining MVP")
	await process_frame
	var transition_mine := current_scene as ActionDashMiningMVP
	_expect(transition_mine != null and not surface.is_inside_tree(), "La escena 3D sigue activa/renderizando durante mineria")
	var mining_instance_id := transition_mine.get_instance_id()
	transition_mine.mech.try_absorb_ore(&"voltrita")
	transition_mine.mech.global_position = transition_mine.terrain.get_entry_position()
	_expect(transition_mine.deposit_at_surface(true), "Deposito de transicion falla")
	await process_frame
	await process_frame
	_expect(current_scene == surface and surface.is_inside_tree(), "No regresa a la misma escena 3D")
	_expect(controller.get_state() == phase_state and absf(controller.get_time_remaining() - phase_time) < 0.25, "La run 3D pierde estado durante la mineria")
	_expect(run_session.extracted_value == 8, "El valor no persiste al volver a 3D")
	_expect(run_session.enter_mining(), "No permite una segunda entrada a mineria")
	await process_frame
	_expect(current_scene.get_instance_id() == mining_instance_id, "La segunda entrada regenera mina y duplica estado")
	_expect((current_scene as ActionDashMiningMVP).mech.get_cargo_stack().is_empty(), "Cargo depositado reaparece en segunda entrada")
	_expect(run_session.exit_mining(), "La segunda salida a 3D falla")
	await process_frame
	_expect(current_scene == surface and get_nodes_in_group("mining_loose_ores").is_empty(), "Quedan escenas/ores activos tras salir")
	current_scene = null
	run_session.reset_mining_run()
	surface.queue_free()
	await process_frame

	if _failures.is_empty():
		print("MINING_MVP_VALIDATION_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

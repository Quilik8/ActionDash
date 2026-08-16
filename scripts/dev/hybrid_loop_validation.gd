extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_session := root.get_node("/root/RunSession") as ActionDashRunState
	var surface := (load("res://scenes/gameplay/playground.tscn") as PackedScene).instantiate()
	root.add_child(surface)
	current_scene = surface
	await process_frame
	await physics_frame
	var controller := surface.get_node("PhaseController") as ActionDashPhaseController
	var spawner := surface.get_node("EnemySpawner") as ActionDashEnemySpawner
	var surface_entry := surface.get_node("MiningMVPEntry") as ActionDashSurfaceMiningEntry
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.PREPARATION, "La run no inicia en PREPARATION")
	_expect(controller.get_state() == ActionDashPhaseController.RunState.PREPARATION, "El controlador no inicia en zona segura")
	_expect(spawner.get_active_count() == 0, "Hay enemigos activos durante PREPARATION")

	var enter_event := InputEventAction.new()
	enter_event.action = &"interact"
	enter_event.pressed = true
	surface_entry._unhandled_input(enter_event)
	_expect(surface.get_node("RunUI/Overlay/InteractionPanel").visible, "No muestra confirmacion para entrar a Mining")
	surface_entry._confirm_enter_mining()
	await process_frame
	var mine := current_scene as ActionDashMiningMVP
	var first_mine_id := mine.get_instance_id()
	var entry := mine.terrain.get_entry_position()
	var drilled_cell := Vector2i(floori(float(mine.config.grid_width) / 2.0), 4)
	mine.terrain.drill_cell(drilled_cell, 1000.0)
	var first_signature := mine.terrain.get_generation_signature()
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.MINING, "El estado central no cambia a MINING")
	_expect(not surface.is_inside_tree(), "La superficie sigue activa durante Mining")
	_expect(mine.terrain.is_cell_excavated(drilled_cell), "La celda excavada no queda persistente")
	mine.mech.try_absorb_ore(&"voltrita")
	mine.mech.global_position = entry + Vector2(38.0, 0.0)
	var defend_event := InputEventAction.new()
	defend_event.action = &"interact"
	defend_event.pressed = true
	mine._unhandled_input(defend_event)
	_expect(mine._interaction_panel.visible, "No muestra confirmacion para defender")
	mine._confirm_defender()
	var value_after_first_deposit := run_session.extracted_value
	_expect(value_after_first_deposit == 8, "El primer deposito no llega a RunSession")
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.DEFENSE, "No vuelve a 3D para defender")
	await process_frame
	await physics_frame
	_expect(current_scene == surface and surface.is_inside_tree(), "La superficie no vuelve tras Mining")
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.DEFENSE, "No entra en DEFENSE")
	_expect(spawner.get_active_count() > 0, "La oleada no arranca despues de cargar la superficie")

	await _finish_wave(controller)
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.REWARD, "La oleada no abre REWARD")
	_expect(paused, "REWARD no pausa el gameplay")
	var first_choices := controller.get_current_card_choices()
	_expect(first_choices.size() == 3, "REWARD no ofrece tres cartas")
	if first_choices.size() == 3:
		_expect(controller.select_card(first_choices[0]), "No se puede elegir la primera carta")
	await process_frame
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.PREPARATION, "La carta no devuelve a PREPARATION")
	_expect(not paused, "La pausa permanece despues de elegir carta")
	_expect(run_session.selected_card_id == first_choices[0], "La carta elegida no persiste en RunSession")

	_expect(run_session.enter_mining(), "No permite el segundo ciclo de Mining")
	await process_frame
	var second_mine := current_scene as ActionDashMiningMVP
	_expect(second_mine.get_instance_id() == first_mine_id, "El segundo ciclo crea una mina nueva")
	_expect(second_mine.terrain.get_generation_signature() == first_signature, "La mina se regenera entre oleadas")
	_expect(second_mine.terrain.is_cell_excavated(drilled_cell), "El tunel excavado desaparece entre ciclos")
	_expect(run_session.extracted_value == value_after_first_deposit, "Los recursos se duplican al reentrar")
	second_mine.mech.global_position = second_mine.terrain.get_entry_position() + Vector2(-38.0, 0.0)
	var upgrades_event := InputEventAction.new()
	upgrades_event.action = &"open_upgrades"
	upgrades_event.pressed = true
	second_mine._unhandled_input(upgrades_event)
	_expect(second_mine._upgrades_panel.visible, "MEJORAS se abre fuera de su zona o no abre en la base")
	second_mine._close_mining_modal()
	second_mine.mech.global_position = second_mine.terrain.get_entry_position() + Vector2(38.0, 0.0)
	second_mine._unhandled_input(defend_event)
	second_mine._confirm_defender()
	await process_frame
	await physics_frame
	_expect(spawner.get_active_count() > 0, "La segunda oleada no arranca")
	await _finish_wave(controller)
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.REWARD, "El segundo final no abre REWARD")
	var second_choices := controller.get_current_card_choices()
	_expect(second_choices.size() == 3, "El segundo REWARD no ofrece tres cartas")
	if second_choices.size() == 3:
		controller.select_card(second_choices[0])
	await process_frame
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.PREPARATION, "El segundo ciclo no vuelve a PREPARATION")
	_expect(spawner.get_active_count() == 0, "Quedan enemigos tras cerrar el segundo ciclo")

	current_scene = null
	run_session.reset_mining_run()
	surface.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HYBRID_LOOP_MVP_VALIDATION_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _finish_wave(controller: ActionDashPhaseController) -> void:
	var total := controller.get_current_phase_config().total_enemies
	for _index in total:
		controller.call("_on_enemy_defeated", false)
	await process_frame
	await create_timer(1.0, true, false, true).timeout

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

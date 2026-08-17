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
	_expect(absf(run_session.get_preparation_time_remaining() - 150.0) < 0.2, "La gracia inicial no empieza en 2:30")
	var grace_before_mining := run_session.get_preparation_time_remaining()
	await process_frame
	await physics_frame
	_expect(run_session.get_preparation_time_remaining() < grace_before_mining, "El temporizador de gracia no avanza en 3D")

	var enter_event := InputEventAction.new()
	enter_event.action = &"interact"
	enter_event.pressed = true
	surface_entry._unhandled_input(enter_event)
	_expect(surface.get_node("RunUI/Overlay/InteractionPanel").visible, "No muestra confirmacion para entrar a Mining")
	surface_entry._confirm_enter_mining()
	var mine := current_scene as ActionDashMiningMVP
	var first_mine_id := mine.get_instance_id()
	# The confirmation input must not reopen Mining's base modal during the scene swap.
	mine._unhandled_input(enter_event)
	_expect(not mine._interaction_panel.visible, "La entrada 3D->2D arrastra el cuadro de interaccion")
	_expect(mine.mech.is_physics_processing(), "El meca no queda habilitado al entrar a Mining")
	await process_frame
	var entry := mine.terrain.get_entry_position()
	var drilled_cell := Vector2i(floori(float(mine.config.grid_width) / 2.0), 4)
	mine.terrain.drill_cell(drilled_cell, 1000.0)
	var first_signature := mine.terrain.get_generation_signature()
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.MINING, "El estado central no cambia a MINING")
	_expect(not surface.is_inside_tree(), "La superficie sigue activa durante Mining")
	_expect(mine.terrain.is_cell_excavated(drilled_cell), "La celda excavada no queda persistente")
	mine.mech.try_absorb_ore(&"voltrita")
	var grace_inside_mining := run_session.get_preparation_time_remaining()
	await process_frame
	await physics_frame
	_expect(run_session.get_preparation_time_remaining() < grace_inside_mining, "El temporizador no sigue avanzando dentro de Mining")
	# La cabeza tiene un radio propio; una posicion fuera de ese radio no puede absorber.
	_expect(not mine.mech.is_head_near(mine.mech.global_position + Vector2(14.0, 0.0)), "El radio de absorcion de la cabeza es demasiado amplio")
	# Se fuerza el vencimiento para validar la transicion sin esperar 2:30 reales.
	run_session.preparation_time_remaining = 0.05
	await _wait_for_defense(run_session)
	var value_after_first_deposit := run_session.extracted_value
	_expect(value_after_first_deposit == 0, "La salida automatica deposito carga sin confirmacion")
	_expect(mine.mech.get_cargo_stack().size() == 1, "La salida automatica perdio la carga de Mining")
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
	_expect(absf(run_session.get_preparation_time_remaining() - 150.0) < 0.2, "La segunda gracia no reinicia en 2:30")
	_expect(spawner.get_active_count() == 0, "Hay enemigos durante la segunda gracia")

	_expect(run_session.enter_mining(), "No permite el segundo ciclo de Mining")
	await process_frame
	var second_mine := current_scene as ActionDashMiningMVP
	_expect(second_mine.get_instance_id() == first_mine_id, "El segundo ciclo crea una mina nueva")
	_expect(second_mine.terrain.get_generation_signature() == first_signature, "La mina se regenera entre oleadas")
	_expect(second_mine.terrain.is_cell_excavated(drilled_cell), "El tunel excavado desaparece entre ciclos")
	_expect(run_session.extracted_value == value_after_first_deposit, "Los recursos se duplican al reentrar")
	_expect(second_mine.mech.get_cargo_stack().size() == 1, "La carga no persiste al reentrar en Mining")
	# Regression: entering again must re-enable the mech even if a previous modal stopped it.
	second_mine.mech.set_physics_process(false)
	_expect(run_session.exit_mining_to_preparation(), "No puede salir temporalmente para probar la reentrada")
	await process_frame
	_expect(run_session.enter_mining(), "No puede volver a entrar tras una salida temporal")
	await process_frame
	second_mine = current_scene as ActionDashMiningMVP
	_expect(second_mine.mech.is_physics_processing(), "La reentrada conserva el meca bloqueado")
	second_mine.mech.global_position = second_mine.terrain.get_entry_position() + Vector2(-38.0, 0.0)
	var upgrades_event := InputEventAction.new()
	upgrades_event.action = &"open_upgrades"
	upgrades_event.pressed = true
	second_mine._unhandled_input(upgrades_event)
	_expect(second_mine._upgrades_panel.visible, "MEJORAS se abre fuera de su zona o no abre en la base")
	second_mine._close_mining_modal()
	second_mine.mech.global_position = second_mine.terrain.get_entry_position()
	var defend_event := InputEventAction.new()
	defend_event.action = &"interact"
	defend_event.pressed = true
	second_mine._unhandled_input(defend_event)
	second_mine._confirm_defender()
	await process_frame
	await physics_frame
	_expect(run_session.get_phase_state() == ActionDashRunState.PhaseState.PREPARATION, "El regreso manual inicia la oleada antes de tiempo")
	_expect(run_session.extracted_value == 8, "El segundo deposito no llega a RunSession")
	_expect(spawner.get_active_count() == 0, "Hay enemigos durante la gracia despues del regreso")
	run_session.preparation_time_remaining = 0.05
	await _wait_for_defense(run_session)
	_expect(spawner.get_active_count() > 0, "La segunda oleada no arranca al terminar la gracia")
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

func _wait_for_defense(run_session: ActionDashRunState) -> void:
	for _index in 12:
		await process_frame
		await physics_frame
		var active_spawner := current_scene.get_node_or_null("EnemySpawner") as ActionDashEnemySpawner if current_scene != null else null
		if run_session.get_phase_state() == ActionDashRunState.PhaseState.DEFENSE and active_spawner != null and active_spawner.get_active_count() > 0:
			return

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

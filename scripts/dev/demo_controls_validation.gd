extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	if not OS.has_feature("actiondash_demo"):
		print("DEMO_CONTROLS_VALIDATION_SKIPPED")
		quit(0)
		return
	var run_session := root.get_node("/root/RunSession") as ActionDashRunState
	var right_key := _get_physical_key(&"move_right")
	var upgrade_key := _get_physical_key(&"open_upgrades")
	if run_session.demo_controls_enabled and right_key == KEY_D and upgrade_key == KEY_U:
		print("DEMO_CONTROLS_VALIDATION_OK")
		quit(0)
		return
	push_error("La demo no aplico WASD/U: right=%d upgrades=%d" % [right_key, upgrade_key])
	quit(1)

func _get_physical_key(action: StringName) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return -1

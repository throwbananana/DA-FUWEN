extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	await process_frame
	scene._on_start_day_pressed()
	scene.pending_roll = {
		"base_roll": 2,
		"value": 2,
		"adjustment": 0,
		"rerolled": false,
	}
	scene._apply_current_roll_routes()
	if scene._get_selectable_nodes().is_empty():
		push_error("Smoke test failed: no selectable habitats after starting a day.")
		quit(1)
		return

	if not await _drive_roll_to_stop(scene):
		push_error("Smoke test failed: visit decision panel did not open.")
		quit(1)
		return

	if not scene.decision_panel.visible:
		push_error("Smoke test failed: visit decision panel did not open.")
		quit(1)
		return

	scene._on_base_pressed()
	await process_frame
	if not scene.base_panel.visible:
		push_error("Smoke test failed: base overview did not open.")
		quit(1)
		return

	scene.base_panel.close_panel()
	scene.decision_panel.close_panel()
	await create_timer(0.1).timeout
	quit()

func _drive_roll_to_stop(scene: Node) -> bool:
	for _step in range(8):
		if scene.decision_panel.visible or scene.base_panel.visible:
			return true
		if scene.branch_choice_pending:
			var options: Array[int] = scene._get_selectable_nodes()
			if options.is_empty():
				return false
			scene._on_board_node_chosen(int(options[0]))
		elif scene.awaiting_destination:
			scene._start_roll_travel()
		await process_frame
	return scene.decision_panel.visible or scene.base_panel.visible

extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	await process_frame
	scene._on_start_day_pressed()
	if scene._get_selectable_nodes().is_empty():
		push_error("Smoke test failed: no selectable habitats after starting a day.")
		quit(1)
		return

	var first_target := int(scene._get_selectable_nodes()[0])
	scene._on_board_node_chosen(first_target)
	await process_frame
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

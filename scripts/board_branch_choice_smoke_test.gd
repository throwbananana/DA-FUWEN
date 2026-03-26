extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	await process_frame
	scene.pending_roll = {
		"base_roll": 2,
		"value": 2,
		"adjustment": 0,
		"rerolled": false,
	}
	scene._apply_current_roll_routes()

	if not scene.awaiting_destination:
		_fail("Branch choice smoke test failed: a seeded roll should prepare reachable destinations.")
		return

	scene._start_roll_travel()
	await process_frame

	if not scene.branch_choice_pending:
		_fail("Branch choice smoke test failed: travel should pause for a branch choice at the opening fork.")
		return
	if scene.current_node_id != 1:
		_fail("Branch choice smoke test failed: the seeded opening route should advance to node 1 before the first branch choice.")
		return

	var options: Array[int] = scene._get_selectable_nodes()
	if options.size() < 2:
		_fail("Branch choice smoke test failed: the opening fork should expose multiple branch options.")
		return

	var chosen_step := int(options[0])
	var chosen_node: Dictionary = scene.board_lookup.get(chosen_step, {})
	scene._on_board_node_chosen(chosen_step)
	await process_frame

	if scene.branch_choice_pending:
		_fail("Branch choice smoke test failed: choosing a single-exit branch should resume travel immediately.")
		return
	if scene.current_node_id != chosen_step:
		_fail("Branch choice smoke test failed: choosing a branch should end the 2-step route at the chosen node.")
		return
	if not scene.decision_panel.visible:
		_fail("Branch choice smoke test failed: completing the branched route should open the arrival panel.")
		return
	if scene.current_visit_habitat_id != String(chosen_node.get("habitat_id", "")):
		_fail("Branch choice smoke test failed: the arrival habitat should match the chosen branch node.")
		return
	if not scene.pending_roll.is_empty():
		_fail("Branch choice smoke test failed: roll state should clear after arrival resolves.")
		return
	if scene.awaiting_destination:
		_fail("Branch choice smoke test failed: destination selection should be cleared after arrival.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

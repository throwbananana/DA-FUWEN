extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")

	if game_state.season_length != 25:
		_fail("Run upgrade smoke test failed: season length should be upgraded to 25 turns.")
		return
	if data_repository.get_board_region_for_season("spring").is_empty():
		_fail("Run upgrade smoke test failed: spring board region data was not loaded.")
		return
	if game_state.weekly_objective.is_empty():
		_fail("Run upgrade smoke test failed: a weekly objective should be assigned on scene start.")
		return
	if game_state.run_modifiers.is_empty():
		_fail("Run upgrade smoke test failed: a run modifier should be assigned on scene start.")
		return

	scene._on_start_day_pressed()
	await process_frame
	if scene.pending_roll.is_empty():
		_fail("Run upgrade smoke test failed: rolling should create a pending roll state.")
		return
	if scene._get_selectable_nodes().is_empty():
		scene.pending_roll = {
			"base_roll": 1,
			"value": 1,
			"adjustment": 0,
			"rerolled": false,
		}
		scene._apply_current_roll_routes()
		if scene._get_selectable_nodes().is_empty():
			_fail("Run upgrade smoke test failed: a 1-step roll from the opening camp should expose at least one reachable node.")
			return

	scene._on_reroll_pressed()
	if game_state.weekly_reroll_count != 1:
		_fail("Run upgrade smoke test failed: reroll should consume the weekly reroll counter.")
		return

	var objective: Dictionary = game_state.weekly_objective.duplicate(true)
	for requirement in objective.get("requirements", []):
		game_state.weekly_progress[String(requirement.get("metric", ""))] = int(requirement.get("target", 0))
	var season_points_before: int = int(game_state.season_points)
	scene._resolve_weekly_settlement()
	if not game_state.weekly_objective.is_empty():
		_fail("Run upgrade smoke test failed: weekly settlement should clear the current objective.")
		return
	if game_state.season_points <= season_points_before:
		_fail("Run upgrade smoke test failed: weekly settlement should grant progression rewards.")
		return

	scene._assign_weekly_objective()
	if game_state.weekly_objective.is_empty():
		_fail("Run upgrade smoke test failed: a new weekly objective should be assignable after settlement.")
		return

	var boss_rule: Dictionary = data_repository.get_season_boss_rule(game_state.season_id)
	var exploration_before: int = int(game_state.exploration_points)
	scene.current_node_id = int(boss_rule.get("node_id", -1))
	scene._resolve_season_boss_reward()
	if game_state.exploration_points <= exploration_before:
		_fail("Run upgrade smoke test failed: season boss nodes should grant exploration point rewards.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

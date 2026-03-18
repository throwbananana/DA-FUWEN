extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	await process_frame
	var game_state: Node = root.get_node("GameState")
	var initial_ai: Array = game_state.get_ai_players()
	if initial_ai.size() < 3:
		_fail("AI turn smoke test failed: a new run should seed at least 3 rival expeditions.")
		return
	var starting_positions: Array[int] = []
	for rival in initial_ai:
		starting_positions.append(int(Dictionary(rival).get("current_node_id", -1)))
	var log_count_before: int = game_state.journal_entries.size()
	await scene._run_ai_turns()
	await process_frame
	var updated_ai: Array = game_state.get_ai_players()
	var moved_count := 0
	for index in range(min(initial_ai.size(), updated_ai.size())):
		var rival: Dictionary = updated_ai[index]
		if int(rival.get("current_node_id", -1)) != starting_positions[index]:
			moved_count += 1
		if String(rival.get("latest_action", "")).is_empty():
			_fail("AI turn smoke test failed: rivals should record a latest_action after their turn resolves.")
			return
	if moved_count <= 0:
		_fail("AI turn smoke test failed: at least one rival should advance on its observed turn.")
		return
	var saw_ai_log := false
	for entry in game_state.journal_entries:
		if String(entry).begins_with("对手回合："):
			saw_ai_log = true
			break
	if not saw_ai_log or game_state.journal_entries.size() <= log_count_before:
		_fail("AI turn smoke test failed: observed rival turns should be pushed into the journal feed.")
		return
	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

extends SceneTree

var _finished := false

func _initialize() -> void:
	create_timer(5.0).timeout.connect(_on_watchdog_timeout)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var game_state := root.get_node("GameState")
	game_state.exploration_points_total = 0
	game_state.exploration_points = 4
	game_state.week_index = 3
	game_state.completed_seasons = 2
	game_state.badge_count = 1
	game_state.discovered_species.clear()
	game_state.discovered_species.append_array(["steam_otter_1", "moss_deer_1"])
	game_state.meta_unlocks = {
		"tracks": [],
		"dice_modules": [],
	}

	scene.season_finished = true
	scene.turn_flow_controller.mark_run_summary()
	scene.action_hint_label.text = "[b]这一年的收获[/b]\n本局探索点 14 ｜ 累计探索点 14"
	scene._update_ui()

	if scene.turn_flow_controller.get_phase_name() != "RUN_SUMMARY":
		_fail("Run summary smoke test failed: season summary UI should preserve RUN_SUMMARY phase.")
		return
	if not String(scene.action_hint_label.text).contains("累计探索点"):
		_fail("Run summary smoke test failed: action hint should keep the settlement summary text.")
		return
	var run_summary: Dictionary = scene.meta_progression_service.build_run_summary()
	var reward_result: Dictionary = scene.meta_progression_service.commit_run_rewards(run_summary, false)
	if game_state.exploration_points_total <= 0 or int(reward_result.get("total_after", 0)) <= 0:
		_fail("Run summary smoke test failed: run summary should still be able to commit meta progression points.")
		return

	_finished = true
	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_fail("Run summary smoke test failed: timed out before completing checks.")

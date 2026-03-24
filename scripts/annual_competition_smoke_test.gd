extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()

	var annual_competition_service = load("res://scripts/services/annual_competition_service.gd").new()
	var initial_status: Dictionary = annual_competition_service.build_status_snapshot()
	if String(initial_status.get("state", "")) != "upcoming":
		_fail("Annual competition smoke test failed: fresh run should mark the event as upcoming.")
		return

	var reserve_uid: String = game_state.add_companion("reed_frog_1", "后备雀")
	if not game_state.get_reserve_uids().has(reserve_uid):
		_fail("Annual competition smoke test failed: extra companion should enter the reserve roster.")
		return

	game_state.season_id = "winter"
	var reminder: Dictionary = annual_competition_service.maybe_issue_month_reminder()
	if not bool(reminder.get("ok", false)):
		_fail("Annual competition smoke test failed: winter reminder should trigger exactly once before the event.")
		return
	if not game_state.has_annual_competition_reminder(1):
		_fail("Annual competition smoke test failed: reminder year should persist in runtime state.")
		return
	var reminder_status: Dictionary = annual_competition_service.build_status_snapshot()
	if String(reminder_status.get("state", "")) != "reminder":
		_fail("Annual competition smoke test failed: status should switch to reminder in the final month window.")
		return
	if Array(reminder.get("body_lines", [])).size() < 3:
		_fail("Annual competition smoke test failed: reminder should expose a readable event preview.")
		return
	if not annual_competition_service.maybe_issue_month_reminder().is_empty():
		_fail("Annual competition smoke test failed: reminder should not repeat within the same year.")
		return

	var reward_watch_items := _collect_reward_item_ids(annual_competition_service.get_event())
	var item_counts_before := {}
	for item_id in reward_watch_items:
		item_counts_before[item_id] = game_state.get_item_count(item_id)
	var wallet_before := int(game_state.get_treasury_snapshot().get("wallet_gold", 0))

	var result: Dictionary = annual_competition_service.resolve_current_year()
	if not bool(result.get("ok", false)):
		_fail("Annual competition smoke test failed: year-end resolution should succeed.")
		return
	if Array(result.get("standings", [])).size() != game_state.get_ai_players().size() + 1:
		_fail("Annual competition smoke test failed: all AI rivals and the player should enter the standings.")
		return
	if int(result.get("player_placement", 0)) <= 0:
		_fail("Annual competition smoke test failed: player placement should be recorded.")
		return
	var expected_player_units: int = game_state.get_party_uids().size() + game_state.get_reserve_uids().size()
	if int(result.get("player_unit_count", 0)) != expected_player_units:
		_fail("Annual competition smoke test failed: automatic entry should include both battle and reserve pets.")
		return
	if game_state.get_annual_competition_history().size() != 1 or not game_state.has_annual_competition_result(1):
		_fail("Annual competition smoke test failed: competition result should persist in yearly history.")
		return

	var player_reward: Dictionary = Dictionary(result.get("player_reward", {})).duplicate(true)
	var reward_gold := int(player_reward.get("gold", 0))
	if int(game_state.get_treasury_snapshot().get("wallet_gold", 0)) != wallet_before + reward_gold:
		_fail("Annual competition smoke test failed: wallet gold should match the resolved placement reward.")
		return
	for item_id in Dictionary(player_reward.get("items", {})).keys():
		var expected_count := int(item_counts_before.get(String(item_id), 0)) + int(Dictionary(player_reward.get("items", {})).get(item_id, 0))
		if game_state.get_item_count(String(item_id)) != expected_count:
			_fail("Annual competition smoke test failed: inventory reward application does not match the resolved reward table.")
			return

	var ai_result_recorded := false
	for rival_value in game_state.get_ai_players():
		var rival: Dictionary = Dictionary(rival_value).duplicate(true)
		if String(rival.get("latest_action_short", "")).contains("年赛第"):
			ai_result_recorded = true
			break
	if not ai_result_recorded:
		_fail("Annual competition smoke test failed: AI participants should record their annual competition placement.")
		return

	var repeated_result: Dictionary = annual_competition_service.resolve_current_year()
	if String(repeated_result.get("reason", "")) != "already_resolved":
		_fail("Annual competition smoke test failed: same year should not resolve twice.")
		return
	if int(game_state.get_treasury_snapshot().get("wallet_gold", 0)) != wallet_before + reward_gold:
		_fail("Annual competition smoke test failed: repeated resolve should not duplicate gold rewards.")
		return
	for item_id in Dictionary(player_reward.get("items", {})).keys():
		var expected_count := int(item_counts_before.get(String(item_id), 0)) + int(Dictionary(player_reward.get("items", {})).get(item_id, 0))
		if game_state.get_item_count(String(item_id)) != expected_count:
			_fail("Annual competition smoke test failed: repeated resolve should not duplicate item rewards.")
			return

	await create_timer(0.05).timeout
	quit()

func _collect_reward_item_ids(event: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for reward_value in Dictionary(event.get("placement_rewards", {})).values():
		for item_id in Dictionary(Dictionary(reward_value).get("items", {})).keys():
			var item_text := String(item_id)
			if item_text.is_empty() or result.has(item_text):
				continue
			result.append(item_text)
	result.sort()
	return result

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

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

	if data_repository.get_season_rule("summer").is_empty():
		_fail("Upgrade smoke test failed: season rules were not loaded.")
		return
	if data_repository.get_dojo("summer_storm_trial").is_empty():
		_fail("Upgrade smoke test failed: dojo definitions were not loaded.")
		return
	if game_state.is_habitat_unlocked("thunder_meadow"):
		_fail("Upgrade smoke test failed: thunder_meadow should not unlock during spring.")
		return

	game_state.set_building_level("mist_moss_cave", "warm_nest", 2)
	game_state.note_build("warm_nest", 2)
	if not game_state.advance_to_next_season():
		_fail("Upgrade smoke test failed: could not advance to summer.")
		return
	if game_state.season_id != "summer":
		_fail("Upgrade smoke test failed: season did not advance to summer.")
		return
	if not game_state.is_habitat_unlocked("thunder_meadow"):
		_fail("Upgrade smoke test failed: thunder_meadow did not unlock in summer.")
		return

	game_state.grant_items({"spark_reed": 1})
	var dojo_service = load("res://scripts/services/dojo_service.gd").new()
	var summer_result: Dictionary = dojo_service.attempt_dojo("summer_storm_trial", "tier_1")
	if not bool(summer_result.get("ok", false)) or not bool(summer_result.get("success", false)):
		_fail("Upgrade smoke test failed: summer dojo tier 1 did not clear.")
		return
	if not game_state.has_cleared_dojo("summer_storm_trial", "tier_1"):
		_fail("Upgrade smoke test failed: dojo clear flag was not stored.")
		return
	if game_state.badge_count < 1:
		_fail("Upgrade smoke test failed: dojo rewards did not grant a badge.")
		return
	if not game_state.is_habitat_unlocked("echo_broken_bridge"):
		_fail("Upgrade smoke test failed: echo_broken_bridge was not unlocked by the summer dojo reward.")
		return

	if not game_state.advance_to_next_season():
		_fail("Upgrade smoke test failed: could not advance to autumn.")
		return
	if not game_state.is_habitat_unlocked("autumn_leaf_dojo"):
		_fail("Upgrade smoke test failed: autumn_leaf_dojo did not unlock in autumn.")
		return

	game_state.add_trust("moss_keeper", 6)
	if not game_state.advance_to_next_season():
		_fail("Upgrade smoke test failed: could not advance to winter.")
		return
	if not game_state.is_habitat_unlocked("frost_mirror_lake"):
		_fail("Upgrade smoke test failed: frost_mirror_lake did not unlock in winter.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

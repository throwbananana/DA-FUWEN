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
		_fail("Upgrade smoke test failed: thunder_meadow should still require progression, not season.")
		return

	game_state.set_building_level("mist_moss_cave", "warm_nest", 2)
	game_state.note_build("warm_nest", 2)
	if not game_state.is_habitat_unlocked("thunder_meadow"):
		_fail("Upgrade smoke test failed: thunder_meadow did not unlock after reaching the rank gate.")
		return
	if not game_state.is_habitat_unlocked("autumn_leaf_dojo"):
		_fail("Upgrade smoke test failed: autumn_leaf_dojo did not unlock after the building gate.")
		return

	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var assign_result: Dictionary = habitat_service.assign_resident("mist_moss_cave", "pet_001")
	if not bool(assign_result.get("ok", false)):
		_fail("Upgrade smoke test failed: could not assign a resident before dojo validation.")
		return

	game_state.grant_items({"spark_reed": 2})
	var dojo_service = load("res://scripts/services/dojo_service.gd").new()

	var summer_t1: Dictionary = dojo_service.attempt_dojo("summer_storm_trial", "tier_1")
	if not bool(summer_t1.get("ok", false)) or not bool(summer_t1.get("success", false)):
		_fail("Upgrade smoke test failed: summer dojo tier 1 did not clear.")
		return
	if game_state.is_habitat_unlocked("echo_broken_bridge"):
		_fail("Upgrade smoke test failed: echo_broken_bridge should unlock on summer dojo tier 2, not tier 1.")
		return

	var summer_t2: Dictionary = dojo_service.attempt_dojo("summer_storm_trial", "tier_2")
	if not bool(summer_t2.get("ok", false)) or not bool(summer_t2.get("success", false)):
		_fail("Upgrade smoke test failed: summer dojo tier 2 did not clear.")
		return
	if not game_state.is_habitat_unlocked("echo_broken_bridge"):
		_fail("Upgrade smoke test failed: echo_broken_bridge was not unlocked by the summer dojo tier 2 reward.")
		return

	game_state.add_trust("moss_keeper", 6)
	if not game_state.is_habitat_unlocked("frost_mirror_lake"):
		_fail("Upgrade smoke test failed: frost_mirror_lake did not unlock after the trust gate.")
		return

	game_state.grant_items({"amber_resin": 2, "tea_leaf": 2})
	var autumn_t1: Dictionary = dojo_service.attempt_dojo("autumn_leaf_dojo", "tier_1")
	if not bool(autumn_t1.get("ok", false)) or not bool(autumn_t1.get("success", false)):
		_fail("Upgrade smoke test failed: autumn dojo tier 1 did not clear.")
		return
	var autumn_t2: Dictionary = dojo_service.attempt_dojo("autumn_leaf_dojo", "tier_2")
	if not bool(autumn_t2.get("ok", false)) or not bool(autumn_t2.get("success", false)):
		_fail("Upgrade smoke test failed: autumn dojo tier 2 did not clear.")
		return
	if not game_state.is_habitat_unlocked("radiant_observatory"):
		_fail("Upgrade smoke test failed: radiant_observatory was not unlocked by the autumn dojo reward.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

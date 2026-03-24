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

	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var dojo_service = load("res://scripts/services/dojo_service.gd").new()
	var assign_result: Dictionary = habitat_service.assign_resident("mist_moss_cave", "pet_001")
	if not bool(assign_result.get("ok", false)):
		_fail("Building tier smoke test failed: could not assign a resident for construction preview.")
		return

	game_state.grant_items({"soft_moss": 12, "fiber": 2, "warm_stone": 2})
	var warm_nest_preview: Dictionary = habitat_service.can_build("mist_moss_cave", "warm_nest")
	if not bool(warm_nest_preview.get("ok", false)):
		_fail("Building tier smoke test failed: warm_nest level 1 preview should be buildable.")
		return
	if int(warm_nest_preview.get("current_level", -1)) != 0 or int(warm_nest_preview.get("max_level", 0)) != 3:
		_fail("Building tier smoke test failed: construction preview did not expose current/max levels.")
		return
	if Array(warm_nest_preview.get("effects", [])).is_empty():
		_fail("Building tier smoke test failed: construction preview should expose next-level effects.")
		return

	var level1_result: Dictionary = habitat_service.build_on_site("mist_moss_cave", "warm_nest")
	if not bool(level1_result.get("ok", false)):
		_fail("Building tier smoke test failed: warm_nest level 1 build failed.")
		return

	var level2_preview: Dictionary = habitat_service.can_build("mist_moss_cave", "warm_nest")
	if not bool(level2_preview.get("ok", false)):
		_fail("Building tier smoke test failed: warm_nest level 2 preview should still be buildable.")
		return
	if int(level2_preview.get("progression_rank_after", 0)) <= int(level2_preview.get("progression_rank_before", 0)):
		_fail("Building tier smoke test failed: construction preview should show progression-rank gain on the second upgrade.")
		return

	var level2_result: Dictionary = habitat_service.build_on_site("mist_moss_cave", "warm_nest")
	if not bool(level2_result.get("ok", false)):
		_fail("Building tier smoke test failed: warm_nest level 2 build failed.")
		return
	if int(level2_result.get("progression_rank_after", 0)) != 2 or int(level2_result.get("capacity_after", 0)) != 5:
		_fail("Building tier smoke test failed: building upgrade did not raise progression rank/capacity as expected.")
		return

	if not game_state.is_habitat_unlocked("thunder_meadow"):
		_fail("Building tier smoke test failed: thunder_meadow should unlock after early building progress.")
		return

	game_state.grant_items({"spark_reed": 1})
	var dojo_menu: Dictionary = dojo_service.get_dojo_menu("thunder_meadow")
	if String(dojo_menu.get("backpack_summary", "")).is_empty():
		_fail("Building tier smoke test failed: dojo menu should expose backpack summary.")
		return
	var choices: Array = dojo_menu.get("choices", [])
	if choices.size() < 2:
		_fail("Building tier smoke test failed: dojo menu should expose tier choices.")
		return
	if bool(choices[0].get("disabled", true)):
		_fail("Building tier smoke test failed: summer tier 1 should be selectable when ticket and battle slots are ready.")
		return
	if not bool(choices[1].get("disabled", false)):
		_fail("Building tier smoke test failed: summer tier 2 should stay locked until tier 1 is cleared.")
		return
	if not String(choices[0].get("summary", "")).contains("准备"):
		_fail("Building tier smoke test failed: dojo tier summary should expose readiness scoring.")
		return
	if not String(choices[0].get("tooltip", "")).contains("首通奖励"):
		_fail("Building tier smoke test failed: dojo tier tooltip should preview first-clear rewards.")
		return

	var tier1_result: Dictionary = dojo_service.attempt_dojo("summer_storm_trial", "tier_1")
	if not bool(tier1_result.get("ok", false)) or not bool(tier1_result.get("success", false)):
		_fail("Building tier smoke test failed: summer dojo tier 1 should clear in the smoke setup.")
		return

	game_state.grant_items({"spark_reed": 1})
	var dojo_menu_after_clear: Dictionary = dojo_service.get_dojo_menu("thunder_meadow")
	var refreshed_choices: Array = dojo_menu_after_clear.get("choices", [])
	if bool(refreshed_choices[1].get("disabled", true)):
		_fail("Building tier smoke test failed: summer tier 2 should unlock in the menu after tier 1 clear.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

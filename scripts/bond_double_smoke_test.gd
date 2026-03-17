extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()
	if data_repository.species.size() < 120:
		_fail("Bond smoke test failed: MDA species pack was not merged into DataRepository.")
		return

	if game_state.backpack_capacity != 4:
		_fail("Bond smoke test failed: initial backpack capacity should start at 4 from the MDA population curve.")
		return
	game_state.set_building_level("sky_post", "boarding_pen", 2)
	if game_state.backpack_capacity != 5:
		_fail("Bond smoke test failed: progression rank should raise backpack capacity to 5 after early building progress.")
		return

	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var assign_result: Dictionary = habitat_service.assign_resident("mist_moss_cave", "pet_002")
	if not bool(assign_result.get("ok", false)):
		_fail("Bond smoke test failed: could not assign seeded cave companion to warm_nest habitat.")
		return
	game_state.set_building_level("mist_moss_cave", "warm_nest", 2)

	game_state.add_companion("steam_otter_1")
	game_state.add_companion("steam_otter_1")
	var merge_result: Dictionary = game_state.merge_species_duplicates("steam_otter_1")
	if not bool(merge_result.get("ok", false)):
		_fail("Bond smoke test failed: duplicate steam_otter_1 did not merge into higher star.")
		return
	if game_state.count_species_pets("steam_otter_1", 2) != 1:
		_fail("Bond smoke test failed: merged steam_otter_1 should leave exactly one 2-star copy.")
		return

	game_state.add_companion("steam_otter_1")
	game_state.add_companion("reed_frog_1")
	var synergy_service = load("res://scripts/services/synergy_service.gd").new()
	var synergy_report: Dictionary = synergy_service.build_synergy_report()
	var tide_bucket: Dictionary = synergy_report.get("buckets", {}).get("elements", {}).get("water", {})
	if int(tide_bucket.get("count", 0)) != 2:
		_fail("Bond smoke test failed: duplicate steam_otter_1 should not count twice toward water synergy.")
		return
	var facility_bonus: Dictionary = synergy_service.build_facility_bonus()
	if facility_bonus.get("lines", []).is_empty():
		_fail("Bond smoke test failed: matched building should provide a visible prebattle bonus.")
		return
	if int(facility_bonus.get("bonus", {}).get("ally_hp_bonus", 0)) < 2:
		_fail("Bond smoke test failed: warm_nest should grant ally HP bonus when matched.")
		return

	if not game_state.advance_to_next_season():
		_fail("Bond smoke test failed: could not advance to summer for dojo validation.")
		return
	game_state.grant_items({"spark_reed": 1})
	var dojo_service = load("res://scripts/services/dojo_service.gd").new()
	var battle_prep: Dictionary = dojo_service.prepare_dojo_battle("summer_storm_trial", "tier_1")
	if not bool(battle_prep.get("ok", false)):
		_fail("Bond smoke test failed: dojo battle preparation failed.")
		return
	var battle_config: Dictionary = battle_prep.get("battle_config", {})
	if battle_config.get("allies", []).size() != 2 or battle_config.get("enemies", []).size() != 2:
		_fail("Bond smoke test failed: dojo battle should prepare a 2v2 lineup.")
		return
	if int(battle_config.get("ally_hp_bonus", 0)) < 2:
		_fail("Bond smoke test failed: prepared dojo battle did not inherit synergy/building HP bonus.")
		return

	scene._on_base_pressed()
	await process_frame
	scene.base_panel._on_manage_pressed()
	await process_frame
	if not scene.decision_panel.visible or String(scene.pending_context.get("kind", "")) != "team_manage":
		_fail("Bond smoke test failed: base panel did not open the team management menu.")
		return
	scene._on_decision_choice_selected("battle_0")
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "team_battle_slot":
		_fail("Bond smoke test failed: battle slot picker did not open from team management.")
		return
	var target_uid := String(game_state.get_companions()[-1].get("uid", ""))
	scene._on_decision_choice_selected(target_uid)
	await process_frame
	if String(game_state.get_battle_party_uids()[0]) != target_uid:
		_fail("Bond smoke test failed: team management did not update battle slot 1.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

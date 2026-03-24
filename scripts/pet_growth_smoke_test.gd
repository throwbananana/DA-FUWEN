extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()

	var starter_skill_ids: Array[String] = game_state.get_pet_skill_ids("pet_001")
	if starter_skill_ids.size() != 2:
		_fail("Pet growth smoke test failed: seeded starter should begin with exactly 2 known skills.")
		return
	if not starter_skill_ids.has("water_basic") or not starter_skill_ids.has("striker_tactic"):
		_fail("Pet growth smoke test failed: seeded starter should inherit the first two species skills.")
		return

	game_state.set_building_level("sky_post", "boarding_pen", 2)
	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var otter_assign: Dictionary = habitat_service.assign_resident("crystal_creek", "pet_001")
	if not bool(otter_assign.get("ok", false)):
		_fail("Pet growth smoke test failed: seeded otter could not be assigned for evolution setup.")
		return
	game_state.set_building_level("crystal_creek", "shallow_pool", 1)
	scene._resolve_visit_yield("crystal_creek")
	var frog_uid: String = game_state.add_companion("reed_frog_1")
	game_state.set_battle_slot(1, frog_uid)

	game_state.add_companion("steam_otter_1")
	game_state.add_companion("steam_otter_1")
	var stage_two_merge: Dictionary = game_state.merge_species_duplicates("steam_otter_1")
	if not bool(stage_two_merge.get("ok", false)):
		_fail("Pet growth smoke test failed: stage 1 otter merge should succeed.")
		return
	var stage_two_upgrades: Array = stage_two_merge.get("upgrades", [])
	if stage_two_upgrades.is_empty():
		_fail("Pet growth smoke test failed: stage 1 otter merge should report at least one upgrade.")
		return
	var stage_two_result: Dictionary = stage_two_upgrades[0]
	var stage_two_uid := String(stage_two_result.get("pet_uid", ""))
	var stage_two_skill_ids: Array[String] = game_state.get_pet_skill_ids(stage_two_uid)
	if String(game_state.get_pet(stage_two_uid).get("species_id", "")) != "steam_otter_2":
		_fail("Pet growth smoke test failed: stage 2 otter should reach the second species form under evolution setup.")
		return
	if stage_two_skill_ids.size() != 3:
		_fail("Pet growth smoke test failed: stage 2 otter should expand to 3 known skills.")
		return
	if not stage_two_skill_ids.has("steam_otter_sig_2"):
		_fail("Pet growth smoke test failed: stage 2 otter should learn its third species skill.")
		return
	if game_state.pet_has_pending_skill(stage_two_uid):
		_fail("Pet growth smoke test failed: stage 2 otter should not queue a pending skill when capacity remains.")
		return

	var extra_uid_a: String = game_state.add_companion("steam_otter_2")
	var extra_uid_b: String = game_state.add_companion("steam_otter_2")
	var extra_pet_a: Dictionary = game_state.get_pet(extra_uid_a).duplicate(true)
	extra_pet_a["star_level"] = 2
	game_state.pet_states[extra_uid_a] = extra_pet_a
	var extra_pet_b: Dictionary = game_state.get_pet(extra_uid_b).duplicate(true)
	extra_pet_b["star_level"] = 2
	game_state.pet_states[extra_uid_b] = extra_pet_b

	var stage_three_merge: Dictionary = game_state.merge_species_duplicates("steam_otter_2")
	if not bool(stage_three_merge.get("ok", false)):
		_fail("Pet growth smoke test failed: stage 2 otter merge should succeed.")
		return
	var final_skill_ids: Array[String] = game_state.get_pet_skill_ids(stage_two_uid)
	if String(game_state.get_pet(stage_two_uid).get("species_id", "")) != "steam_otter_3":
		_fail("Pet growth smoke test failed: stage 3 otter should reach the third species form.")
		return
	if final_skill_ids.size() != 4:
		_fail("Pet growth smoke test failed: stage 3 otter should cap out at 4 known skills.")
		return
	if not final_skill_ids.has("water_burst"):
		_fail("Pet growth smoke test failed: stage 3 otter should learn its fourth species skill.")
		return
	if game_state.pet_has_pending_skill(stage_two_uid):
		_fail("Pet growth smoke test failed: stage 3 otter should not queue a pending skill at max species kit.")
		return
	if data_repository.get_pet_skill_capacity("steam_otter_3") != 4:
		_fail("Pet growth smoke test failed: repository should report 4 total skill slots.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

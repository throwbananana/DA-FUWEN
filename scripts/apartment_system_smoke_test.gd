extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var data_repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	var building_interaction_service = load("res://scripts/services/building_interaction_service.gd").new()
	data_repository.load_all()
	game_state.reset_for_new_season()

	var apartment_building: Dictionary = data_repository.get_building("settlement_apartment")
	if apartment_building.is_empty():
		_fail("Apartment smoke test failed: settlement_apartment blueprint is missing.")
		return
	if not data_repository.building_matches_habitat(apartment_building, "sky_post"):
		_fail("Apartment smoke test failed: settlement_apartment should be buildable in sky_post.")
		return
	if not data_repository.building_matches_habitat(apartment_building, "copper_hammer_bazaar"):
		_fail("Apartment smoke test failed: settlement_apartment should be buildable in copper_hammer_bazaar.")
		return
	if data_repository.building_matches_habitat(apartment_building, "mist_moss_cave"):
		_fail("Apartment smoke test failed: settlement_apartment should not be buildable in a habitat node.")
		return

	game_state.set_building_level("sky_post", "settlement_apartment", 3)
	game_state.ensure_building_runtime_state("sky_post", "settlement_apartment")
	game_state.set_building_level("sky_post", "tea_shed", 1)
	game_state.ensure_building_runtime_state("sky_post", "tea_shed")
	game_state.set_building_level("copper_hammer_bazaar", "settlement_apartment", 2)
	game_state.ensure_building_runtime_state("copper_hammer_bazaar", "settlement_apartment")

	game_state.record_npc_intro_duel("innkeeper_yun", true, 2)
	game_state.add_trust("innkeeper_yun", 3)
	game_state.record_npc_intro_duel("boarder_liu", true, 2)
	game_state.add_trust("boarder_liu", 2)
	game_state.record_npc_intro_duel("traveling_peddler", true, 2)
	game_state.add_trust("traveling_peddler", 2)
	game_state.record_npc_intro_duel("parts_vendor", true, 0)

	var starting_wallet := int(game_state.wallet_gold)
	var saw_move_in := false
	var saw_rent := false
	var saw_nuisance := false
	for _day in range(10):
		var report: Dictionary = game_state.advance_day()
		for raw_line in Array(report.get("lines", [])).duplicate(true):
			var line := String(raw_line)
			if line.contains("新住客"):
				saw_move_in = true
			if line.contains("结租"):
				saw_rent = true
			if line.contains("折腾坏了") or line.contains("顺走了备料") or line.contains("掏走了"):
				saw_nuisance = true

	var apartment_status: Dictionary = game_state.get_apartment_status("sky_post")
	if int(apartment_status.get("tenant_count", 0)) < 2:
		_fail("Apartment smoke test failed: apartment should attract multiple tenants after several day ticks.")
		return
	if int(game_state.wallet_gold) <= starting_wallet:
		_fail("Apartment smoke test failed: apartment rent should increase wallet gold.")
		return
	if not saw_move_in:
		_fail("Apartment smoke test failed: move-in journal line was not emitted.")
		return
	if not saw_rent:
		_fail("Apartment smoke test failed: rent journal line was not emitted.")
		return
	if not saw_nuisance:
		_fail("Apartment smoke test failed: nuisance journal line was not emitted.")
		return

	game_state._apply_building_damage("sky_post", "settlement_apartment", 2, "测试修缮需求。", "repair_prank", {"wood": 1, "cloth": 1})
	var repair_cost: Dictionary = game_state.get_building_repair_cost("sky_post", "settlement_apartment")
	if repair_cost.is_empty():
		_fail("Apartment smoke test failed: damaged apartment should expose a repair cost.")
		return
	game_state.grant_items(repair_cost)
	var menu: Array = building_interaction_service.get_interaction_menu("sky_post")
	var found_repair_action := false
	for entry in menu:
		if String(entry.get("building_id", "")) != "settlement_apartment":
			continue
		for action in Array(entry.get("actions", [])).duplicate(true):
			if String(Dictionary(action).get("id", "")) == "repair_damage":
				found_repair_action = true
	if not found_repair_action:
		_fail("Apartment smoke test failed: damaged building should offer a repair action.")
		return
	var repair_result: Dictionary = building_interaction_service.execute_action("sky_post", "settlement_apartment", "repair_damage")
	if not bool(repair_result.get("ok", false)):
		_fail("Apartment smoke test failed: repair action should succeed when materials are available.")
		return
	if game_state.is_building_damaged("sky_post", "settlement_apartment"):
		_fail("Apartment smoke test failed: repair action should clear building damage.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

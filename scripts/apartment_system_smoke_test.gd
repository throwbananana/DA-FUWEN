extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var data_repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
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

	game_state.set_building_level("sky_post", "settlement_apartment", 2)
	game_state.ensure_building_runtime_state("sky_post", "settlement_apartment")
	game_state.set_building_level("sky_post", "tea_shed", 1)
	game_state.ensure_building_runtime_state("sky_post", "tea_shed")

	game_state.record_npc_intro_duel("innkeeper_yun", true, 2)
	game_state.add_trust("innkeeper_yun", 3)
	game_state.record_npc_intro_duel("boarder_liu", true, 2)
	game_state.add_trust("boarder_liu", 2)
	game_state.record_npc_intro_duel("traveling_peddler", false, 0)

	var starting_wallet := int(game_state.wallet_gold)
	var saw_move_in := false
	var saw_rent := false
	var saw_damage := false
	for _day in range(6):
		var report: Dictionary = game_state.advance_day()
		for raw_line in Array(report.get("lines", [])).duplicate(true):
			var line := String(raw_line)
			if line.contains("新住客"):
				saw_move_in = true
			if line.contains("结租"):
				saw_rent = true
			if line.contains("折腾坏了"):
				saw_damage = true

	var apartment_status: Dictionary = game_state.get_apartment_status("sky_post")
	if int(apartment_status.get("tenant_count", 0)) < 1:
		_fail("Apartment smoke test failed: apartment should attract at least one tenant after several day ticks.")
		return
	if int(game_state.wallet_gold) <= starting_wallet:
		_fail("Apartment smoke test failed: apartment rent should increase wallet gold.")
		return
	var tea_shed_damage := int(game_state.get_building_runtime_state("sky_post", "tea_shed").get("damage_days", 0))
	var apartment_damage := int(game_state.get_building_runtime_state("sky_post", "settlement_apartment").get("damage_days", 0))
	if tea_shed_damage <= 0 and apartment_damage <= 0:
		_fail("Apartment smoke test failed: a low-trust nuisance NPC should damage a sky_post building.")
		return
	if not saw_move_in:
		_fail("Apartment smoke test failed: move-in journal line was not emitted.")
		return
	if not saw_rent:
		_fail("Apartment smoke test failed: rent journal line was not emitted.")
		return
	if not saw_damage:
		_fail("Apartment smoke test failed: damage journal line was not emitted.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

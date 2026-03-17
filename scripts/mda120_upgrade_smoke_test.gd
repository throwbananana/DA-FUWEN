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

	if game_state.get_progression_rank() != 1:
		_fail("MDA120 smoke test failed: initial progression rank should start at 1.")
		return
	if game_state.backpack_capacity != 4:
		_fail("MDA120 smoke test failed: initial backpack capacity should follow rank 1 curve and equal 4.")
		return
	if data_repository.get_population_curve_entry(9).is_empty():
		_fail("MDA120 smoke test failed: population curve lookup should support fallback for late ranks.")
		return

	var encounter_service = load("res://scripts/services/encounter_service.gd").new()
	var weighted_entries: Array = encounter_service.build_weighted_entries("sky_post")
	var common_weight := 0
	var uncommon_weight := 0
	for entry in weighted_entries:
		var species_id := String(entry.get("species_id", ""))
		match String(data_repository.get_species(species_id).get("rarity", "")):
			"common":
				if common_weight == 0:
					common_weight = int(entry.get("effective_weight", 0))
			"uncommon":
				if uncommon_weight == 0:
					uncommon_weight = int(entry.get("effective_weight", 0))
	if common_weight <= uncommon_weight:
		_fail("MDA120 smoke test failed: shop odds weighting should favor common entries over uncommon ones at rank 1.")
		return
	for _index in range(24):
		var encounter: Dictionary = encounter_service.roll_encounter("mist_moss_cave")
		if not bool(encounter.get("ok", false)):
			_fail("MDA120 smoke test failed: mist_moss_cave should produce a valid low-rank encounter.")
			return
		var species_id := String(encounter.get("species_id", ""))
		var unlock_rank := int(data_repository.get_species(species_id).get("unlock_rank", 1))
		if unlock_rank > game_state.get_progression_rank():
			_fail("MDA120 smoke test failed: low-rank encounter pool leaked species above current progression rank.")
			return

	game_state.set_building_level("sky_post", "boarding_pen", 2)
	if game_state.get_progression_rank() != 2 or game_state.backpack_capacity != 5:
		_fail("MDA120 smoke test failed: early building progress should raise rank to 2 and capacity to 5.")
		return

	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var otter_assign: Dictionary = habitat_service.assign_resident("crystal_creek", "pet_001")
	if not bool(otter_assign.get("ok", false)):
		_fail("MDA120 smoke test failed: seeded otter could not be assigned to crystal_creek.")
		return
	game_state.set_building_level("crystal_creek", "shallow_pool", 1)
	var stone_before := int(game_state.inventory.get("stone_chip", 0))
	scene._resolve_visit_yield("crystal_creek")
	if int(game_state.inventory.get("stone_chip", 0)) != stone_before + 2:
		_fail("MDA120 smoke test failed: matched economy resonance should duplicate crystal_creek visit material output.")
		return
	if int(game_state.get_pet("pet_001").get("bond_level", 1)) != 2:
		_fail("MDA120 smoke test failed: matched growth resonance should raise resident bond_level during visit settlement.")
		return

	var frog_uid: String = game_state.add_companion("reed_frog_1")
	game_state.set_battle_slot(1, frog_uid)
	game_state.add_companion("steam_otter_1")
	game_state.add_companion("steam_otter_1")
	var stage_two_result: Dictionary = game_state.merge_species_duplicates("steam_otter_1")
	if not bool(stage_two_result.get("ok", false)):
		_fail("MDA120 smoke test failed: steam_otter_1 duplicates did not merge.")
		return
	if String(stage_two_result.get("upgrades", [])[0].get("new_species_id", "")) != "steam_otter_2":
		_fail("MDA120 smoke test failed: stage 1 otter should evolve into steam_otter_2 after site/building/synergy checks.")
		return

	var evo_pet: Dictionary = game_state.get_pet("pet_001")
	if String(evo_pet.get("species_id", "")) != "steam_otter_2":
		_fail("MDA120 smoke test failed: evolved otter state was not written back to pet_001.")
		return

	var extra_uid_a: String = game_state.add_companion("steam_otter_2")
	var extra_uid_b: String = game_state.add_companion("steam_otter_2")
	var extra_pet_a: Dictionary = game_state.get_pet(extra_uid_a).duplicate(true)
	extra_pet_a["star_level"] = 2
	game_state.pet_states[extra_uid_a] = extra_pet_a
	var extra_pet_b: Dictionary = game_state.get_pet(extra_uid_b).duplicate(true)
	extra_pet_b["star_level"] = 2
	game_state.pet_states[extra_uid_b] = extra_pet_b

	var stage_three_result: Dictionary = game_state.merge_species_duplicates("steam_otter_2")
	if not bool(stage_three_result.get("ok", false)):
		_fail("MDA120 smoke test failed: steam_otter_2 duplicates did not merge into late evolution.")
		return
	if String(stage_three_result.get("upgrades", [])[0].get("new_species_id", "")) != "steam_otter_3":
		_fail("MDA120 smoke test failed: stage 2 otter should evolve into steam_otter_3 using evolution_chains role clause.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

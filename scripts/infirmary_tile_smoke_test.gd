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

	var board_progression_service = load("res://scripts/services/board_progression_service.gd").new()
	for season_id in ["spring", "summer", "autumn", "winter"]:
		game_state.reset_for_new_season()
		game_state.season_id = String(season_id)
		board_progression_service.set_region_for_season(String(season_id))
		var region: Dictionary = board_progression_service.get_region()
		var expected_settlements := _collect_expected_settlement_ids(Array(region.get("nodes", [])))
		if expected_settlements.is_empty():
			_fail("Infirmary smoke test failed: %s should still expose settlement-linked nodes for matching infirmary checks." % season_id)
			return
		for settlement_id in expected_settlements:
			if _find_linked_infirmary(Array(region.get("nodes", [])), settlement_id).is_empty():
				_fail("Infirmary smoke test failed: %s is missing the infirmary tile paired to %s." % [season_id, settlement_id])
				return

	game_state.reset_for_new_season()
	game_state.season_id = "spring"
	game_state.set_board_loop_progress({
		"unlocked_ring_count": 6,
		"generated_ring_count": 7,
		"pending_dojo_ring": -1,
	}, "spring")
	board_progression_service.set_region_for_season("spring")
	var special_region: Dictionary = board_progression_service.get_region()
	for loop_id in ["sky_island", "swamp", "ocean"]:
		if _find_special_infirmary(Array(special_region.get("nodes", [])), loop_id).is_empty():
			_fail("Infirmary smoke test failed: special loop %s should have at least one dedicated infirmary tile." % loop_id)
			return

	game_state.reset_for_new_season()
	game_state.season_id = "spring"
	scene._refresh_board_region(true)

	var infirmary_node := _find_any_infirmary(scene.world_nodes)
	if infirmary_node.is_empty():
		_fail("Infirmary smoke test failed: refreshed board should contain an infirmary node.")
		return

	game_state.hunger = 34
	var wallet_before: int = game_state.wallet_gold
	scene._show_infirmary_stop(infirmary_node)
	await process_frame
	if not scene.decision_panel.visible or String(scene.pending_context.get("kind", "")) != "infirmary_menu":
		_fail("Infirmary smoke test failed: landing on infirmary should open the infirmary menu.")
		return
	scene._on_decision_choice_selected("rest")
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "infirmary_result":
		_fail("Infirmary smoke test failed: choosing free rest should open the infirmary result panel.")
		return
	if game_state.wallet_gold != wallet_before:
		_fail("Infirmary smoke test failed: voluntary infirmary rest should not deduct wallet gold.")
		return
	if game_state.hunger != game_state.max_hunger:
		_fail("Infirmary smoke test failed: voluntary infirmary rest should fully restore hunger.")
		return

	var defeated_node: Dictionary = _find_defeat_source(scene.world_nodes)
	if defeated_node.is_empty():
		_fail("Infirmary smoke test failed: could not find a non-infirmary source node for forced recovery.")
		return
	var source_node_id := int(defeated_node.get("id", -1))
	scene.current_node_id = source_node_id
	game_state.move_to_board_node(source_node_id)
	game_state.hunger = 9
	game_state.wallet_gold = 20
	var expected_destination: Dictionary = scene.board_progression_service.find_best_infirmary_node(source_node_id)
	if expected_destination.is_empty():
		_fail("Infirmary smoke test failed: forced recovery should have a target infirmary node.")
		return
	var expected_cost: int = scene.infirmary_service.auto_recovery_cost(defeated_node)
	var forced_result: Dictionary = scene._apply_forced_infirmary_transfer(defeated_node)
	if scene.current_node_id != int(expected_destination.get("id", -1)):
		_fail("Infirmary smoke test failed: forced recovery should move the player to the matched infirmary tile.")
		return
	if int(forced_result.get("paid_gold", -1)) != expected_cost:
		_fail("Infirmary smoke test failed: forced recovery should deduct the expected amount of gold.")
		return
	if game_state.wallet_gold != 20 - expected_cost:
		_fail("Infirmary smoke test failed: forced recovery wallet deduction does not match the reported fee.")
		return
	if game_state.hunger != game_state.max_hunger:
		_fail("Infirmary smoke test failed: forced recovery should restore hunger to full.")
		return

	await create_timer(0.05).timeout
	quit()

func _collect_expected_settlement_ids(nodes: Array) -> Array[String]:
	var data_repository := root.get_node("DataRepository")
	var ids: Array[String] = []
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if String(data_repository.get_habitat(habitat_id).get("type", "")) != "settlement":
			continue
		if not ids.has(habitat_id):
			ids.append(habitat_id)
	return ids

func _find_linked_infirmary(nodes: Array, settlement_id: String) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("type", "")) != "infirmary":
			continue
		if String(node.get("linked_habitat_id", "")) == settlement_id:
			return node
	return {}

func _find_special_infirmary(nodes: Array, loop_id: String) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("type", "")) != "infirmary":
			continue
		if String(node.get("special_loop_id", "")) == loop_id:
			return node
	return {}

func _find_any_infirmary(nodes: Array) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("type", "")) == "infirmary":
			return node
	return {}

func _find_defeat_source(nodes: Array) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		var type_id := String(node.get("type", ""))
		if type_id in ["infirmary", "camp", "bulletin", "minigame"]:
			continue
		return node
	return {}

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

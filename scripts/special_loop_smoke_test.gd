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
	var dojo_service = load("res://scripts/services/dojo_service.gd").new()

	var summer_menu: Dictionary = dojo_service.get_dojo_menu("thunder_meadow")
	if Array(summer_menu.get("choices", [])).is_empty():
		_fail("Special loop smoke test failed: summer dojo menu should exist.")
		return
	if not String(Dictionary(Array(summer_menu.get("choices", []))[0]).get("tooltip", "")).contains("通行技 腾空翼"):
		_fail("Special loop smoke test failed: summer dojo tooltip should preview the sky traversal skill.")
		return

	game_state.reset_for_new_season()
	game_state.season_id = "spring"
	game_state.set_board_loop_progress({
		"unlocked_ring_count": 2,
		"generated_ring_count": 3,
		"pending_dojo_ring": -1,
	}, "spring")
	board_progression_service.set_region_for_season("spring")
	var spring_region: Dictionary = board_progression_service.get_region()
	if _collect_special_nodes(Array(spring_region.get("nodes", [])), "sky_island").is_empty():
		_fail("Special loop smoke test failed: sky island loop nodes should be generated on ring 3.")
		return
	var sky_gate := _find_gate_for_target_ring(Array(spring_region.get("nodes", [])), 2)
	if sky_gate.is_empty():
		_fail("Special loop smoke test failed: sky island gate missing.")
		return
	var blocked_sky: Dictionary = board_progression_service.try_resolve_unlock_gate(int(sky_gate.get("id", -1)))
	if bool(blocked_sky.get("ok", false)):
		_fail("Special loop smoke test failed: sky island should stay blocked before learning its traversal skill.")
		return
	if not String(blocked_sky.get("message", "")).contains("腾空翼"):
		_fail("Special loop smoke test failed: sky island block reason should mention 腾空翼.")
		return
	var learned_sky: Array[String] = game_state.mark_dojo_clear("summer_storm_trial", "tier_1", true)
	if not learned_sky.has("sky_glide") or not game_state.has_traversal_skill("sky_glide"):
		_fail("Special loop smoke test failed: clearing summer tier 1 should teach 腾空翼.")
		return
	var unlocked_sky: Dictionary = board_progression_service.try_resolve_unlock_gate(int(sky_gate.get("id", -1)))
	if not bool(unlocked_sky.get("ok", false)) or int(unlocked_sky.get("target_ring", -1)) != 2:
		_fail("Special loop smoke test failed: sky island gate should unlock after learning 腾空翼 and clearing the dojo.")
		return
	var sky_wild_node := _find_special_wild_node(Array(spring_region.get("nodes", [])), "sky_island")
	if sky_wild_node.is_empty():
		_fail("Special loop smoke test failed: sky island should contain a dedicated wild-battle node.")
		return
	if not _validate_special_battle_pool(scene, sky_wild_node, "sky_island"):
		return

	game_state.reset_for_new_season()
	game_state.season_id = "spring"
	game_state.set_board_loop_progress({
		"unlocked_ring_count": 4,
		"generated_ring_count": 5,
		"pending_dojo_ring": -1,
	}, "spring")
	board_progression_service.set_region_for_season("spring")
	var swamp_region: Dictionary = board_progression_service.get_region()
	if _collect_special_nodes(Array(swamp_region.get("nodes", [])), "swamp").is_empty():
		_fail("Special loop smoke test failed: swamp loop nodes should be generated on ring 5.")
		return
	var swamp_gate := _find_gate_for_target_ring(Array(swamp_region.get("nodes", [])), 4)
	if swamp_gate.is_empty():
		_fail("Special loop smoke test failed: swamp gate missing.")
		return
	var blocked_swamp: Dictionary = board_progression_service.try_resolve_unlock_gate(int(swamp_gate.get("id", -1)))
	if bool(blocked_swamp.get("ok", false)):
		_fail("Special loop smoke test failed: swamp loop should stay blocked before learning 涉泽步.")
		return
	if not String(blocked_swamp.get("message", "")).contains("涉泽步"):
		_fail("Special loop smoke test failed: swamp block reason should mention 涉泽步.")
		return
	var learned_swamp: Array[String] = game_state.mark_dojo_clear("autumn_leaf_dojo", "tier_1", true)
	if not learned_swamp.has("bog_stride") or not game_state.has_traversal_skill("bog_stride"):
		_fail("Special loop smoke test failed: clearing autumn tier 1 should teach 涉泽步.")
		return
	var unlocked_swamp: Dictionary = board_progression_service.try_resolve_unlock_gate(int(swamp_gate.get("id", -1)))
	if not bool(unlocked_swamp.get("ok", false)) or int(unlocked_swamp.get("target_ring", -1)) != 4:
		_fail("Special loop smoke test failed: swamp gate should unlock after learning 涉泽步.")
		return
	var swamp_wild_node := _find_special_wild_node(Array(swamp_region.get("nodes", [])), "swamp")
	if swamp_wild_node.is_empty():
		_fail("Special loop smoke test failed: swamp loop should contain a dedicated wild-battle node.")
		return
	if not _validate_special_battle_pool(scene, swamp_wild_node, "swamp"):
		return

	game_state.reset_for_new_season()
	game_state.season_id = "spring"
	game_state.set_board_loop_progress({
		"unlocked_ring_count": 6,
		"generated_ring_count": 7,
		"pending_dojo_ring": -1,
	}, "spring")
	board_progression_service.set_region_for_season("spring")
	var ocean_region: Dictionary = board_progression_service.get_region()
	if _collect_special_nodes(Array(ocean_region.get("nodes", [])), "ocean").is_empty():
		_fail("Special loop smoke test failed: ocean loop nodes should be generated on ring 7.")
		return
	var ocean_gate := _find_gate_for_target_ring(Array(ocean_region.get("nodes", [])), 6)
	if ocean_gate.is_empty():
		_fail("Special loop smoke test failed: ocean gate missing.")
		return
	var learned_ocean: Array[String] = game_state.mark_dojo_clear("autumn_leaf_dojo", "tier_2", true)
	if not learned_ocean.has("tide_surf") or not game_state.has_traversal_skill("tide_surf"):
		_fail("Special loop smoke test failed: clearing autumn tier 2 should teach 踏潮鳍.")
		return
	game_state.time_of_day = "day"
	var blocked_ocean: Dictionary = board_progression_service.try_resolve_unlock_gate(int(ocean_gate.get("id", -1)))
	if bool(blocked_ocean.get("ok", false)):
		_fail("Special loop smoke test failed: ocean loop should stay blocked outside its tide window.")
		return
	if not String(blocked_ocean.get("message", "")).contains("傍晚"):
		_fail("Special loop smoke test failed: ocean block reason should mention the evening tide window.")
		return
	game_state.time_of_day = "evening"
	var unlocked_ocean: Dictionary = board_progression_service.try_resolve_unlock_gate(int(ocean_gate.get("id", -1)))
	if not bool(unlocked_ocean.get("ok", false)) or int(unlocked_ocean.get("target_ring", -1)) != 6:
		_fail("Special loop smoke test failed: ocean gate should unlock during the tide window after learning 踏潮鳍.")
		return
	var ocean_wild_node := _find_special_wild_node(Array(ocean_region.get("nodes", [])), "ocean")
	if ocean_wild_node.is_empty():
		_fail("Special loop smoke test failed: ocean loop should contain a dedicated wild-battle node.")
		return
	if not _validate_special_battle_pool(scene, ocean_wild_node, "ocean"):
		return

	await create_timer(0.05).timeout
	quit()

func _collect_special_nodes(nodes: Array, special_loop_id: String) -> Array:
	var result: Array = []
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("special_loop_id", "")) != special_loop_id:
			continue
		result.append(node)
	return result

func _find_gate_for_target_ring(nodes: Array, target_ring: int) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if not bool(node.get("unlock_gate", false)):
			continue
		if int(node.get("unlock_target_ring", -1)) != target_ring:
			continue
		return node
	return {}

func _find_special_wild_node(nodes: Array, special_loop_id: String) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("special_loop_id", "")) != special_loop_id:
			continue
		if String(node.get("environment_kind", "")) != "wild_battle":
			continue
		return node
	return {}

func _validate_special_battle_pool(scene: Node, node: Dictionary, expected_loop_id: String) -> bool:
	var battle_config: Dictionary = scene._build_environment_battle_config(node)
	if battle_config.is_empty():
		_fail("Special loop smoke test failed: %s wild node should build an encounter battle." % expected_loop_id)
		return false
	if String(battle_config.get("encounter_origin", "")) != "special_loop":
		_fail("Special loop smoke test failed: %s battle should be marked as using the special loop encounter pool." % expected_loop_id)
		return false
	if String(battle_config.get("special_loop_id", "")) != expected_loop_id:
		_fail("Special loop smoke test failed: %s battle should preserve its loop id in the battle config." % expected_loop_id)
		return false
	var allowed_species := {}
	for raw_entry in Array(node.get("special_encounter_pool", [])):
		var entry := Dictionary(raw_entry).duplicate(true)
		var species_id := String(entry.get("species_id", ""))
		if species_id.is_empty():
			continue
		allowed_species[species_id] = true
	if allowed_species.is_empty():
		_fail("Special loop smoke test failed: %s node should expose a non-empty special encounter pool." % expected_loop_id)
		return false
	for enemy in battle_config.get("enemies", []):
		if not allowed_species.has(String(enemy.species_id)):
			_fail("Special loop smoke test failed: %s battle spawned a species outside its special encounter pool." % expected_loop_id)
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

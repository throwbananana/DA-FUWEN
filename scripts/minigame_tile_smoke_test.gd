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

	var board_progression_service = load("res://scripts/services/board_progression_service.gd").new()
	for season_id in ["spring", "summer", "autumn", "winter"]:
		game_state.season_id = String(season_id)
		board_progression_service.set_region_for_season(String(season_id))
		var region: Dictionary = board_progression_service.get_region()
		var minigame_nodes := _collect_nodes(Array(region.get("nodes", [])), "minigame")
		if minigame_nodes.size() < 2:
			_fail("Minigame smoke test failed: %s should generate at least two early minigame nodes." % season_id)
			return
		for raw_node in minigame_nodes.slice(0, 2):
			var node: Dictionary = Dictionary(raw_node).duplicate(true)
			if not _revealed_nodes_have(Array(region.get("revealed_nodes", [])), int(node.get("id", -1))):
				_fail("Minigame smoke test failed: %s minigame nodes should start revealed." % season_id)
				return

	game_state.reset_for_new_season()
	var minigame_service = load("res://scripts/services/minigame_service.gd").new()
	board_progression_service.set_region_for_season("spring")
	var spring_region: Dictionary = board_progression_service.get_region()
	var spring_node: Dictionary = Dictionary(_collect_nodes(Array(spring_region.get("nodes", [])), "minigame")[0]).duplicate(true)
	var menu: Dictionary = minigame_service.build_board_minigame(spring_node)
	if Array(menu.get("choices", [])).size() < 3:
		_fail("Minigame smoke test failed: minigame menu should expose multiple choices.")
		return

	var first_choice: Dictionary = Dictionary(Array(menu.get("choices", []))[0]).duplicate(true)
	var result: Dictionary = minigame_service.resolve_board_minigame(spring_node, String(first_choice.get("id", "")))
	if not bool(result.get("ok", false)):
		_fail("Minigame smoke test failed: minigame resolution did not return success.")
		return
	var pending_bonus: Dictionary = game_state.peek_pending_minigame_bonus()
	if _sum_bonus(pending_bonus) <= 0:
		_fail("Minigame smoke test failed: resolving a minigame should grant a pending battle bonus.")
		return

	var npc_service = load("res://scripts/services/npc_service.gd").new()
	var duel: Dictionary = npc_service.prepare_intro_duel("moss_keeper", "mist_moss_cave")
	if not bool(duel.get("ok", false)):
		_fail("Minigame smoke test failed: intro duel battle prep should succeed for pending-bonus validation.")
		return
	var battle_config: Dictionary = duel.get("battle_config", {})
	if int(battle_config.get("ally_attack_bonus", 0)) < int(pending_bonus.get("ally_attack_bonus", 0)):
		_fail("Minigame smoke test failed: intro duel should inherit pending attack bonus.")
		return
	if int(battle_config.get("ally_speed_bonus", 0)) < int(pending_bonus.get("ally_speed_bonus", 0)):
		_fail("Minigame smoke test failed: intro duel should inherit pending speed bonus.")
		return
	if int(battle_config.get("ally_hp_bonus", 0)) < int(pending_bonus.get("ally_hp_bonus", 0)):
		_fail("Minigame smoke test failed: intro duel should inherit pending HP bonus.")
		return
	if not bool(battle_config.get("consume_minigame_bonus", false)):
		_fail("Minigame smoke test failed: battle config should consume pending minigame bonuses on start.")
		return

	scene.battle_panel.start_battle(battle_config)
	await process_frame
	if not game_state.peek_pending_minigame_bonus().is_empty():
		_fail("Minigame smoke test failed: pending minigame bonus should be consumed when battle starts.")
		return

	await create_timer(0.05).timeout
	quit()

func _collect_nodes(nodes: Array, type_id: String) -> Array:
	var result: Array = []
	for raw_node in nodes:
		var node: Dictionary = Dictionary(raw_node).duplicate(true)
		if String(node.get("type", "")) == type_id:
			result.append(node)
	return result

func _revealed_nodes_have(values: Array, expected_node_id: int) -> bool:
	for raw_value in values:
		if int(raw_value) == expected_node_id:
			return true
	return false

func _sum_bonus(bonus: Dictionary) -> int:
	var total := 0
	for stat_key in ["ally_attack_bonus", "ally_speed_bonus", "ally_hp_bonus"]:
		total += int(bonus.get(stat_key, 0))
	return total

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

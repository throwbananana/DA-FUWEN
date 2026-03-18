extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")

	var spring_threats: Array = data_repository.get_board_threats_for_season("spring")
	if spring_threats.is_empty():
		_fail("Board threat smoke test failed: spring board threats should be loaded.")
		return
	if game_state.get_active_board_threats().size() != spring_threats.size():
		_fail("Board threat smoke test failed: season threat state should be initialized on scene start.")
		return

	game_state.season_turn = int(spring_threats[0].get("spawn_turn", 1))
	scene.current_node_id = 0
	scene._resolve_board_threat_turn()
	game_state.season_turn += 1
	scene._resolve_board_threat_turn()

	var active_threats: Array = game_state.get_active_board_threats()
	if active_threats.is_empty() or not bool(active_threats[0].get("active", false)):
		_fail("Board threat smoke test failed: threat should become active after its spawn turn.")
		return

	var occupied_node := int(active_threats[0].get("current_node_id", -1))
	if occupied_node < 0:
		_fail("Board threat smoke test failed: active threat should occupy a valid node.")
		return
	if game_state.get_node_danger(occupied_node) <= 0:
		_fail("Board threat smoke test failed: occupied nodes should gain danger.")
		return
	if not scene._blocked_node_ids().has(occupied_node):
		_fail("Board threat smoke test failed: occupied nodes should be treated as blocked.")
		return

	var markers: Dictionary = scene._build_board_markers()
	if not String(markers.get(occupied_node, "")).contains("敌群"):
		_fail("Board threat smoke test failed: occupied nodes should expose a threat marker.")
		return

	scene.current_node_id = 8
	scene.pending_roll = {"value": 1}
	scene._apply_current_roll_routes()
	if scene._get_selectable_nodes().has(occupied_node):
		_fail("Board threat smoke test failed: blocked reachable nodes should not remain selectable.")
		return
	if not scene._get_blocked_reachable_nodes().has(occupied_node):
		_fail("Board threat smoke test failed: blocked reachable nodes should be reported in the map hint state.")
		return

	var day_one_sky_post: Dictionary = scene.habitat_service.get_visit_summary("sky_post")
	if Array(day_one_sky_post.get("npcs", [])).size() < 2:
		_fail("Board threat smoke test failed: sky_post should still expose its resident NPCs.")
		return
	if Array(day_one_sky_post.get("npc_presence", {}).get("window_lines", [])).is_empty():
		_fail("Board threat smoke test failed: arrival summary should mention traveler windows.")
		return

	game_state.set_active_board_threats([])
	game_state.global_turn = 3
	game_state.week_index = 1
	game_state.weekly_turn = 3
	scene._sync_npc_routes_for_day()
	var visible_npcs: Array = scene.npc_service.get_visible_npcs("sky_post")
	var has_traveling_peddler := false
	for npc in visible_npcs:
		if str(npc.get("id", "")) == "traveling_peddler":
			has_traveling_peddler = true
			break
	if not has_traveling_peddler:
		_fail("Board threat smoke test failed: traveling_peddler should appear at sky_post on turn 3.")
		return
	var available_quests: Array = scene.npc_service.get_available_quests("sky_post")
	var has_peddler_quest := false
	for quest in available_quests:
		if str(quest.get("id", "")) == "message_board_refresh":
			has_peddler_quest = true
			break
	if not has_peddler_quest:
		_fail("Board threat smoke test failed: traveler quest should require its giver to be present.")
		return
	var npc_markers: Dictionary = scene.npc_route_service.build_node_markers()
	if not str(npc_markers.get(3, [])).contains("流动商 青禾"):
		_fail("Board threat smoke test failed: traveler nodes should expose map markers.")
		return
	game_state.global_turn = 4
	game_state.weekly_turn = 4
	scene._sync_npc_routes_for_day()
	if str(game_state.get_npc_positions().get("traveling_peddler", "")) != "ancient_platform":
		_fail("Board threat smoke test failed: travelers should move to the next route stop on the following day.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

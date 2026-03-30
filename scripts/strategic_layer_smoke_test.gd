extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var game_state := root.get_node("GameState")

	scene.current_node_id = 5
	scene.current_visit_habitat_id = "ancient_platform"
	scene.visit_flow.start_visit("ancient_platform", scene.board_lookup.get(5, {}))
	await process_frame
	if scene.decision_panel.current_choices.is_empty():
		_fail("Strategic layer smoke test failed: arrival menu should still expose a primary node action.")
		return
	if scene.decision_panel.current_choices.size() != 1:
		_fail("Strategic layer smoke test failed: arrival menu should expose exactly one node action.")
		return
	if String(scene.decision_panel.current_choices[0].get("id", "")) != "build_menu":
		_fail("Strategic layer smoke test failed: ancient_platform should prioritize build_menu as its primary content.")
		return
	scene._show_build_result({"ok": false, "reason": "max_level"})
	if String(scene.pending_context.get("on_close", "")) != "finish_visit":
		_fail("Strategic layer smoke test failed: finishing a node action should end the visit instead of reopening the node menu.")
		return
	scene.visit_flow.open_resident_picker()
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "resident_select":
		_fail("Strategic layer smoke test failed: resident picker should be routed through visit flow state changes.")
		return
	if scene.decision_panel.current_choices.is_empty():
		_fail("Strategic layer smoke test failed: resident picker should expose assignable caretaker choices.")
		return
	scene.current_visit_habitat_id = "mist_moss_cave"
	scene.visit_flow.choose_npc_action("duel:moss_keeper")
	await process_frame
	var duel_routed := String(scene.pending_context.get("kind", "")) == "npc_duel_result" or String(scene.pending_battle_source) == "npc_intro_duel"
	if not duel_routed:
		_fail("Strategic layer smoke test failed: NPC duel selection should be routed through visit flow state changes.")
		return
	scene.visit_flow.choose_npc_action("quest:build_warm_nest")
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "quest_result":
		_fail("Strategic layer smoke test failed: quest acceptance should be routed through visit flow state changes.")
		return

	scene.current_node_id = 1
	scene.current_visit_habitat_id = "mist_moss_cave"
	scene.current_encounter = {
		"species_id": "moss_puff",
		"species": {"name": "苔团"},
		"source": "ambush",
	}
	scene.last_encounter_action_id = "observe"
	scene._handle_encounter_result_effects({"outcome": "alert_rise", "combat_risk": 1})
	if game_state.get_node_danger(1) <= 0:
		_fail("Strategic layer smoke test failed: alert_rise should increase node danger.")
		return
	if not game_state.has_node_ambush(1):
		_fail("Strategic layer smoke test failed: alert_rise should queue a follow-up ambush on the same node.")
		return

	scene._on_board_travel_finished(0)
	await process_frame
	if not scene.base_panel.visible:
		_fail("Strategic layer smoke test failed: camp nodes should auto-open the camp panel on arrival.")
		return
	if scene.base_button.visible:
		_fail("Strategic layer smoke test failed: the camp panel should no longer be exposed as a permanent side button.")
		return
	scene.camp_flow.open_team_manage_menu()
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "team_manage":
		_fail("Strategic layer smoke test failed: camp team management should be routed through camp flow state changes.")
		return
	scene.camp_flow.choose_team_manage_action("battle_0")
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "team_battle_slot":
		_fail("Strategic layer smoke test failed: battle slot picker should be routed through camp flow state changes.")
		return
	scene.camp_flow.open_team_manage_menu()
	await process_frame
	scene.camp_flow.choose_team_manage_action("resident_sites")
	await process_frame
	if String(scene.pending_context.get("kind", "")) != "camp_resident_site":
		_fail("Strategic layer smoke test failed: camp resident site picker should be routed through camp flow state changes.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

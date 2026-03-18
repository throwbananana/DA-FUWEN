extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var game_state := root.get_node("GameState")

	scene.current_node_id = 4
	scene.current_visit_habitat_id = "ancient_platform"
	var arrival_payload: Dictionary = scene.habitat_service.get_visit_summary("ancient_platform")
	scene._show_arrival_menu(arrival_payload)
	await process_frame
	if scene.decision_panel.current_choices.is_empty():
		_fail("Strategic layer smoke test failed: arrival menu should still expose a primary node action.")
		return
	if scene.decision_panel.current_choices.size() > 2:
		_fail("Strategic layer smoke test failed: arrival menu should no longer expose all content at one point.")
		return
	if String(scene.decision_panel.current_choices[0].get("id", "")) != "build_menu":
		_fail("Strategic layer smoke test failed: ancient_platform should prioritize build_menu as its primary content.")
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

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

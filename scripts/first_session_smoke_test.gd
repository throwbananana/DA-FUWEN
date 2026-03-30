extends SceneTree

const ALLOWED_GUIDED_METRICS := {
	"visit_count": true,
	"build_count": true,
	"encounter_count": true,
}

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var game_state := root.get_node("GameState")

	if not game_state.is_guided_intro_active():
		_fail("First session smoke test failed: a fresh run should start in guided intro mode.")
		return
	game_state.week_index = 4
	game_state.global_turn = 17
	if not game_state.is_guided_intro_active():
		_fail("First session smoke test failed: guided intro should stay active for the full first season.")
		return
	game_state.week_index = 1
	game_state.global_turn = 1
	if game_state.weekly_objective.is_empty():
		_fail("First session smoke test failed: a fresh run should assign a weekly objective.")
		return
	for requirement in game_state.weekly_objective.get("requirements", []):
		var metric := String(requirement.get("metric", ""))
		if not ALLOWED_GUIDED_METRICS.has(metric):
			_fail("First session smoke test failed: guided intro should only assign basic weekly objective metrics.")
			return

	scene.board_lookup[9999] = {
		"id": 9999,
		"primary_content": "fishing_menu",
	}
	scene.current_node_id = 9999
	scene.current_visit_habitat_id = "ancient_platform"
	scene.visit_flow.start_visit("ancient_platform", scene.board_lookup.get(9999, {}))
	await process_frame
	if scene.decision_panel.current_choices.is_empty():
		_fail("First session smoke test failed: arrival menu should still expose a guided primary action.")
		return
	var guided_action_id := String(scene.decision_panel.current_choices[0].get("id", ""))
	if not ["build_menu", "npc_menu", "observe"].has(guided_action_id):
		_fail("First session smoke test failed: guided intro should hide advanced arrival actions.")
		return

	var encounter: Dictionary = scene.encounter_service.roll_encounter("mist_moss_cave")
	if not bool(encounter.get("ok", false)):
		_fail("First session smoke test failed: expected a valid encounter preview payload.")
		return
	scene._show_encounter_preview(encounter)
	await process_frame
	if scene.decision_panel.body_label.text.find("这次为什么会遇见") == -1:
		_fail("First session smoke test failed: encounter preview should explain why the encounter appeared.")
		return
	if scene.decision_panel.current_choices.is_empty():
		_fail("First session smoke test failed: encounter preview should expose guided choices.")
		return
	if String(scene.decision_panel.current_choices[0].get("summary", "")).is_empty():
		_fail("First session smoke test failed: encounter choices should include explanatory summaries.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

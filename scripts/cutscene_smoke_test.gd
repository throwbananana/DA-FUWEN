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
	var story_service = scene.story_service
	var cutscene_service = scene.cutscene_service
	var preview: Dictionary = story_service.preview_story_dialogue("lost_apprentice", "mist_moss_cave")
	if preview.is_empty():
		_fail("Cutscene smoke test failed: story preview did not return a beat for lost_apprentice at mist_moss_cave.")
		return
	if game_state.has_story_beat_seen(String(preview.get("arc_id", "")), String(preview.get("id", ""))):
		_fail("Cutscene smoke test failed: preview should not mark story beat as seen before commit.")
		return
	story_service.commit_story_beat(preview)
	if not game_state.has_story_beat_seen(String(preview.get("arc_id", "")), String(preview.get("id", ""))):
		_fail("Cutscene smoke test failed: committed story beat was not persisted.")
		return
	var dialogue: Dictionary = data_repository.get_dialogue(String(preview.get("dialogue_id", "")))
	if dialogue.is_empty():
		_fail("Cutscene smoke test failed: previewed dialogue row is missing.")
		return
	var runtime: Dictionary = cutscene_service.build_dialogue_runtime(dialogue, String(dialogue.get("npc", "")))
	var first_step: Dictionary = cutscene_service.build_dialogue_step(runtime, "start")
	if first_step.is_empty():
		_fail("Cutscene smoke test failed: dialogue runtime could not build the first step.")
		return
	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

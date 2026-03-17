extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var data_repository := root.get_node("DataRepository")
	data_repository.load_all()

	if data_repository.quests.size() < 20:
		_fail("JSON expansion smoke test failed: expanded quest table was not loaded.")
		return
	if data_repository.get_quest("repair_bench_opening").is_empty():
		_fail("JSON expansion smoke test failed: expanded quest entry repair_bench_opening is missing.")
		return
	if data_repository.get_event("evt_moss_night_watch").is_empty():
		_fail("JSON expansion smoke test failed: events table was not loaded.")
		return
	if data_repository.get_dialogue("dlg_moss_keeper_night_watch").is_empty():
		_fail("JSON expansion smoke test failed: dialogues table was not loaded.")
		return
	if data_repository.get_codex_entry("codex_moss_puff").is_empty():
		_fail("JSON expansion smoke test failed: codex table was not loaded.")
		return
	if data_repository.get_encyclopedia_entry("ency_mist_moss_cave").is_empty():
		_fail("JSON expansion smoke test failed: encyclopedia table was not loaded.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

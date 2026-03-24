extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()

	var care_progress_before := int(game_state.get_care_progress())
	var habitat_service = load("res://scripts/services/habitat_service.gd").new()
	var assign_result: Dictionary = habitat_service.assign_resident("mist_moss_cave", "pet_002")
	if not bool(assign_result.get("ok", false)):
		_fail("Nursery smoke test failed: could not assign a cave resident to mist_moss_cave.")
		return

	game_state.set_building_level("mist_moss_cave", "warm_nest", 3)
	game_state.set_building_level("mist_moss_cave", "nursery_corner", 2)
	var local_species_id := String(Array(data_repository.get_habitat("mist_moss_cave").get("wild_pool", []))[0])
	game_state.note_encounter(local_species_id)
	if not game_state.get_nursery_candidate_species("mist_moss_cave").has(local_species_id):
		_fail("Nursery smoke test failed: recorded local species did not become a nursery candidate.")
		return

	var start_result: Dictionary = game_state.start_nursery_project("mist_moss_cave", local_species_id)
	if not bool(start_result.get("ok", false)):
		_fail("Nursery smoke test failed: could not start incubation for local nursery candidate.")
		return
	var project: Dictionary = game_state.get_nursery_project("mist_moss_cave")
	if project.is_empty():
		_fail("Nursery smoke test failed: active nursery project was not written to habitat state.")
		return

	var first_need := String(project.get("current_need_action", ""))
	var care_result: Dictionary = game_state.care_nursery_project("mist_moss_cave", first_need)
	if not bool(care_result.get("ok", false)):
		_fail("Nursery smoke test failed: first nursery care action was rejected.")
		return
	if int(game_state.get_nursery_project("mist_moss_cave").get("progress", 0)) < 2:
		_fail("Nursery smoke test failed: nursery care action did not increase progress.")
		return
	var repeat_result: Dictionary = game_state.care_nursery_project("mist_moss_cave", first_need)
	if bool(repeat_result.get("ok", false)):
		_fail("Nursery smoke test failed: nursery care should be limited to once per turn.")
		return

	var day_report: Dictionary = game_state.advance_day()
	var ready_project: Dictionary = game_state.get_nursery_project("mist_moss_cave")
	if not bool(ready_project.get("ready_to_hatch", false)):
		_fail("Nursery smoke test failed: passive nursery progress did not ready the project for hatching.")
		return
	if Array(day_report.get("lines", [])).is_empty():
		_fail("Nursery smoke test failed: ready-to-hatch nursery turn did not emit any daily report lines.")
		return

	var companion_count_before: int = game_state.get_companions().size()
	var hatch_result: Dictionary = game_state.hatch_nursery_project("mist_moss_cave")
	if not bool(hatch_result.get("ok", false)):
		_fail("Nursery smoke test failed: ready nursery project could not hatch.")
		return
	if game_state.get_companions().size() != companion_count_before + 1:
		_fail("Nursery smoke test failed: hatching did not add a new companion.")
		return
	var hatched_pet: Dictionary = game_state.get_pet(String(hatch_result.get("pet_uid", "")))
	if String(hatched_pet.get("species_id", "")) != local_species_id:
		_fail("Nursery smoke test failed: hatched companion species_id mismatch.")
		return
	if not game_state.get_nursery_project("mist_moss_cave").is_empty():
		_fail("Nursery smoke test failed: nursery project was not cleared after hatching.")
		return
	if int(game_state.get_care_progress()) <= care_progress_before:
		_fail("Nursery smoke test failed: care progress did not reflect nursery system participation.")
		return

	scene._on_base_pressed()
	await process_frame
	if scene.base_panel.summary_label.text.find("孵育") == -1:
		_fail("Nursery smoke test failed: base overview did not surface nursery status.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

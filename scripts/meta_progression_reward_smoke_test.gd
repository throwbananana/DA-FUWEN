extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var game_state := root.get_node("GameState")
	var meta_service = load("res://scripts/services/meta_progression_service.gd").new()

	game_state.exploration_points_total = 3
	game_state.exploration_points = 2
	game_state.meta_unlocks = {
		"tracks": [],
		"dice_modules": [],
	}

	var summary := {
		"weeks_completed": 1,
		"seasons_completed": 1,
		"badges": 0,
		"discovered_species": 0,
		"exploration_points": 2,
	}

	var preview: Dictionary = meta_service.preview_run_rewards(summary)
	if int(preview.get("points", 0)) != 6:
		_fail("Meta progression smoke test failed: full point summary should still report 6 total run points.")
		return
	if int(preview.get("bonus_points", 0)) != 4:
		_fail("Meta progression smoke test failed: only non-exploration bonus points should be pending at settlement.")
		return
	if int(preview.get("total_after", 0)) != 7:
		_fail("Meta progression smoke test failed: projected total should add only pending bonus points.")
		return
	if Array(preview.get("new_tracks", [])).is_empty():
		_fail("Meta progression smoke test failed: projected total should unlock the first meta track.")
		return

	var result: Dictionary = meta_service.commit_run_rewards(summary, false)
	if game_state.exploration_points_total != 7:
		_fail("Meta progression smoke test failed: commit should add pending bonus points without double-counting exploration points.")
		return
	if not game_state.has_meta_track("meta_steady_core"):
		_fail("Meta progression smoke test failed: first meta track should be registered during commit.")
		return
	if not Array(game_state.meta_unlocks.get("dice_modules", [])).has("steady_core"):
		_fail("Meta progression smoke test failed: dice module unlock should be propagated from the track payload.")
		return
	if bool(result.get("saved", true)):
		_fail("Meta progression smoke test failed: explicit auto_save=false should be preserved in the result payload.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

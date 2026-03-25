extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()
	var monster_instance_script = load("res://scripts/monster_instance.gd")
	var game_data_script = load("res://scripts/game_data.gd")

	var template: Dictionary = game_data_script.get_monster_template("moss_puff")
	if int(template.get("stamina", 0)) <= 0 or int(template.get("defense", 0)) <= 0:
		_fail("Codex/stats smoke test failed: moss_puff template should expose stamina and defense.")
		return
	var resistance_map := Dictionary(template.get("element_resistances", {})).duplicate(true)
	if float(resistance_map.get("grove", 1.0)) >= 1.0:
		_fail("Codex/stats smoke test failed: grove species should gain at least one non-neutral elemental resistance.")
		return

	var unit = monster_instance_script.new("moss_puff", 2, 1)
	if unit.stamina <= 0 or unit.defense <= 0:
		_fail("Codex/stats smoke test failed: monster instance should inherit stamina/defense.")
		return
	if unit.get_resistance_multiplier("grove") >= 1.0:
		_fail("Codex/stats smoke test failed: monster instance should expose non-neutral elemental resistance values.")
		return

	var entry: Dictionary = Dictionary(data_repository.get_codex_entry("codex_moss_puff")).duplicate(true)
	if entry.is_empty():
		_fail("Codex/stats smoke test failed: codex_moss_puff entry missing.")
		return
	if game_state.is_codex_entry_unlocked(entry):
		_fail("Codex/stats smoke test failed: codex_moss_puff should start locked on a fresh run.")
		return
	if game_state.reveal_codex_for_species("moss_puff").size() != 1:
		_fail("Codex/stats smoke test failed: battle-style reveal should identify the moss_puff codex entry.")
		return
	if not game_state.is_codex_entry_id_unlocked("codex_moss_puff"):
		_fail("Codex/stats smoke test failed: codex reveal should persist in runtime state.")
		return
	if game_state.is_codex_entry_id_fully_unlocked("codex_moss_puff"):
		_fail("Codex/stats smoke test failed: battle-style reveal should not fully unlock the codex page.")
		return
	var guide_unlocks: Array = game_state.unlock_next_locked_codex_entries(1)
	if guide_unlocks.is_empty():
		_fail("Codex/stats smoke test failed: guidebook unlock should fully unlock at least one codex page when available.")
		return
	if not game_state.is_codex_entry_id_fully_unlocked("codex_moss_puff"):
		_fail("Codex/stats smoke test failed: guidebook unlock should prioritize completing the revealed moss_puff page.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

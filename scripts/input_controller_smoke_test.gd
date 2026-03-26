extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	await process_frame
	if not InputMap.has_action("game_roll") or not InputMap.has_action("game_menu"):
		_fail("Input controller smoke test failed: managed gameplay actions were not registered.")
		return
	if InputMap.action_get_events("ui_accept").is_empty():
		_fail("Input controller smoke test failed: ui_accept should have default bindings.")
		return
	scene._show_main_menu()
	await process_frame
	scene._open_input_settings_panel()
	await process_frame
	if scene.input_settings_panel == null or not scene.input_settings_panel.visible:
		_fail("Input controller smoke test failed: the input settings panel did not open.")
		return
	scene.input_settings_panel.close_panel()
	await process_frame
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

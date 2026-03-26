extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var service = scene.board_progression_service
	if service.get_nodes().size() < 25:
		_fail("Exact roll smoke test failed: season board should expand into a multi-ring route map with at least 25 nodes.")
		return

	var one_step_paths: Dictionary = service.get_reachable_paths(0, 1)
	if one_step_paths.size() != 1 or not one_step_paths.has(1):
		_fail("Exact roll smoke test failed: a one-step roll from the opening camp should only land on node 1.")
		return

	var three_step_paths: Dictionary = service.get_reachable_paths(0, 3)
	if three_step_paths.is_empty() or not three_step_paths.has(3):
		_fail("Exact roll smoke test failed: exact roll movement should expose at least one node that matches the dice distance.")
		return
	if three_step_paths.has(1) or three_step_paths.has(2):
		_fail("Exact roll smoke test failed: shorter destinations must not remain selectable after a larger roll.")
		return
	for path in three_step_paths.values():
		var resolved_path: Array = Array(path)
		if resolved_path.size() != 4:
			_fail("Exact roll smoke test failed: every exact-roll destination should consume the full dice distance.")
			return
	var event_count := 0
	var environment_count := 0
	for node in service.get_nodes():
		match String(node.get("type", "")):
			"event":
				event_count += 1
			"environment":
				environment_count += 1
	if event_count <= 0:
		_fail("Exact roll smoke test failed: long-line map should inject dedicated event tiles.")
		return
	if environment_count <= 0:
		_fail("Exact roll smoke test failed: long-line map should inject environment travel tiles between functional stops.")
		return

	await create_timer(0.05).timeout
	quit()

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

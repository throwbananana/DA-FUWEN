extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var service = scene.board_progression_service
	if service.get_nodes().size() < 60:
		_fail("Exact roll smoke test failed: season board should expand into a long-line map with at least 60 nodes.")
		return

	var one_step_paths: Dictionary = service.get_reachable_paths(0, 1)
	if one_step_paths.size() != 1 or not one_step_paths.has(1):
		_fail("Exact roll smoke test failed: a one-step roll from the opening camp should only land on node 1.")
		return

	var three_step_paths: Dictionary = service.get_reachable_paths(0, 3)
	if three_step_paths.size() != 1 or not three_step_paths.has(3):
		_fail("Exact roll smoke test failed: exact roll movement should only expose the node that matches the dice distance.")
		return
	if three_step_paths.has(1) or three_step_paths.has(2):
		_fail("Exact roll smoke test failed: shorter destinations must not remain selectable after a larger roll.")
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

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
	game_state.reset_for_new_season()
	var service = scene.synergy_service
	var report: Dictionary = service.build_synergy_report()
	var runtime_bonus: Dictionary = service.build_runtime_bonus(report)
	print("traits=", service.format_trait_effect_lines(report, 8))
	print("runtime=", runtime_bonus)
	await create_timer(0.05).timeout
	quit()

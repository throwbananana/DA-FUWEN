extends SceneTree
var _finished := false

func _initialize() -> void:
	create_timer(5.0).timeout.connect(_on_watchdog_timeout)
	var data_repository = root.get_node("DataRepository")
	data_repository.load_all()
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var game_state = root.get_node("GameState")
	var previous_unlocks: Dictionary = Dictionary(game_state.meta_unlocks).duplicate(true)
	var previous_points_total := int(game_state.exploration_points_total)
	var previous_adjust := int(game_state.season_adjust_points)
	var previous_reroll_limit := int(game_state.weekly_reroll_limit)
	var previous_anchor := int(game_state.anchor_points)
	var previous_global_turn := int(game_state.global_turn)

	game_state.meta_unlocks = {
		"tracks": ["meta_path_alpha"],
		"dice_modules": ["steady_core", "trim_edge", "anchor_thread"],
	}
	game_state.exploration_points_total = 24
	game_state.season_adjust_points = 2
	game_state.weekly_reroll_limit = 2
	game_state.anchor_points = 1
	game_state.global_turn = 6

	var menu_meta_summary := String(scene._build_main_menu_meta_summary())
	if not menu_meta_summary.contains("稳态芯片"):
		_fail("meta summary should mention steady_core.")
		return
	if not menu_meta_summary.contains("当前赛季基线"):
		_fail("meta summary should include current resource baseline.")
		return

	scene.pending_roll = {"base_roll": 3, "value": 3, "adjustment": 0, "rerolled": false}
	scene.awaiting_destination = true
	scene.reachable_paths = {1: [0, 1], 2: [0, 2]}
	var roll_state: Dictionary = scene._build_dice_roll_panel_state()
	var body := String(roll_state.get("body", ""))
	if not body.contains("元成长加成"):
		_fail("dice panel body should include meta bonus section.")
		return

	game_state.meta_unlocks = previous_unlocks
	game_state.exploration_points_total = previous_points_total
	game_state.season_adjust_points = previous_adjust
	game_state.weekly_reroll_limit = previous_reroll_limit
	game_state.anchor_points = previous_anchor
	game_state.global_turn = previous_global_turn
	_finished = true
	await create_timer(0.02).timeout
	quit(0)

func _fail(message: String) -> void:
	push_error("main_meta_bonus_ui_smoke_test failed: %s" % message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_fail("timed out before completing checks.")

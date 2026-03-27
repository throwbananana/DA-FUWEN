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
	var previous_threats: Array = Array(game_state.get_active_board_threats()).duplicate(true)
	game_state.set_active_board_threats([
		{
			"id": "forecast_pack",
			"name": "前哨敌群",
			"spawn_turn": int(game_state.season_turn) + 1,
			"route": [1, 4],
			"route_index": -1,
			"active": false,
			"current_node_id": -1,
			"danger_gain": 1,
			"spillover_danger": 1,
			"block_node": true,
			"loop_route": true,
			"player_ambush": 1,
		}
	])

	var forecast_lines: Array[String] = scene._build_threat_forecast_preview_lines(2, 4)
	if forecast_lines.is_empty() or not forecast_lines[0].contains("T+1"):
		_fail("forecast preview should describe the next threatened beat.")
		return

	scene.pending_roll = {"base_roll": 2, "value": 2, "adjustment": 0, "rerolled": false}
	scene.awaiting_destination = true
	scene.reachable_paths = {
		1: [0, 1],
		2: [0, 2],
		3: [0, 3],
	}
	var panel_state: Dictionary = scene._build_dice_roll_panel_state()
	if not String(panel_state.get("body", "")).contains("前方威胁"):
		_fail("dice preview should include threat forecast text.")
		return

	scene._update_map_hint()
	if not String(scene.map_hint_label.text).contains("威胁预告"):
		_fail("map hint should show the threat forecast section while previewing routes.")
		return

	game_state.set_active_board_threats(previous_threats)
	_finished = true
	await create_timer(0.02).timeout
	quit(0)

func _fail(message: String) -> void:
	push_error("threat_forecast_ui_smoke_test failed: %s" % message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_fail("timed out before completing checks.")

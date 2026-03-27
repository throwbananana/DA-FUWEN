extends SceneTree

const ROUTE_RISK_SERVICE := preload("res://scripts/services/route_risk_service.gd")
var _finished := false

func _initialize() -> void:
	create_timer(5.0).timeout.connect(_on_watchdog_timeout)
	_run_checks.call_deferred()

func _run_checks() -> void:
	var game_state = root.get_node("GameState")
	var previous_threats: Array = Array(game_state.get_active_board_threats()).duplicate(true)
	var previous_danger: Dictionary = Dictionary(game_state.node_danger).duplicate(true)
	game_state.set_active_board_threats([
		{
			"id": "pack_alpha",
			"name": "灰脊狼群",
			"route": [1, 2],
			"route_index": 0,
			"active": true,
			"current_node_id": 1,
			"danger_gain": 1,
			"spillover_danger": 1,
			"block_node": true,
			"loop_route": true,
			"player_ambush": 1,
		}
	])
	game_state.node_danger = {
		1: 1,
		2: 0,
		3: 0,
	}

	var service = ROUTE_RISK_SERVICE.new()
	var node_lookup := {
		0: {"id": 0, "name": "营地", "edges": [1, 2, 3]},
		1: {"id": 1, "name": "雾苔窟", "edges": [0, 2]},
		2: {"id": 2, "name": "晶溪滩", "edges": [0, 1, 3]},
		3: {"id": 3, "name": "云升驿", "edges": [0, 2]},
	}
	var reachable_paths := {
		1: [0, 1],
		2: [0, 2],
		3: [0, 3],
	}
	var reports: Array = service.build_candidate_reports(0, [1, 2, 3], reachable_paths, node_lookup, 2)
	if reports.size() != 3:
		_fail("should build reports for all candidate nodes.")
		return
	var safest: Dictionary = Dictionary(reports[0]).duplicate(true)
	var riskiest: Dictionary = Dictionary(reports[reports.size() - 1]).duplicate(true)
	if String(safest.get("name", "")) != "云升驿":
		_fail("云升驿 should be the safest candidate in this setup.")
		return
	if String(riskiest.get("risk_band", "")) != "blocked":
		_fail("the currently occupied node should be flagged as blocked.")
		return
	var future_hot := {}
	for raw_report in reports:
		var report: Dictionary = Dictionary(raw_report).duplicate(true)
		if String(report.get("name", "")) == "晶溪滩":
			future_hot = report
			break
	if future_hot.is_empty():
		_fail("expected to find report for 晶溪滩.")
		return
	if int(future_hot.get("blocked_turn", -1)) != 1:
		_fail("晶溪滩 should be forecast as blocked on the next turn.")
		return
	var lines: Array[String] = service.format_compact_lines(reports, 3)
	if lines.is_empty() or lines[0].find("较稳") < 0:
		_fail("compact lines should expose the risk label for the safest route.")
		return

	game_state.set_active_board_threats(previous_threats)
	game_state.node_danger = previous_danger
	_finished = true
	await create_timer(0.02).timeout
	quit(0)

func _fail(message: String) -> void:
	push_error("route_risk_advisor_smoke_test failed: %s" % message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_fail("timed out before completing checks.")

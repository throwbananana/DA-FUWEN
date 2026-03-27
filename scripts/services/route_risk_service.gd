class_name RouteRiskService
extends RefCounted

const RISK_SAFE := "safe"
const RISK_WATCH := "watch"
const RISK_HOT := "hot"
const RISK_BLOCKED := "blocked"

func build_candidate_reports(
	current_node_id: int,
	candidate_node_ids: Array[int],
	reachable_paths: Dictionary,
	node_lookup: Dictionary,
	forecast_turns: int = 2
) -> Array:
	var reports: Array = []
	var game_state := _game_state()
	if game_state == null:
		return reports
	if candidate_node_ids.is_empty():
		return reports
	var states := Array(game_state.get_active_board_threats()).duplicate(true)
	var blocked_now := _blocked_node_ids(states)
	var snapshots := _build_forecast_snapshots(states, node_lookup, forecast_turns)
	for candidate_node_id in candidate_node_ids:
		var node_id := int(candidate_node_id)
		var node: Dictionary = Dictionary(node_lookup.get(node_id, {})).duplicate(true)
		var path: Array = Array(reachable_paths.get(node_id, [])).duplicate(true)
		if path.is_empty():
			path = [current_node_id, node_id]
		var report := {
			"node_id": node_id,
			"name": String(node.get("name", "未知节点")),
			"path": _int_array(path),
			"blocked_now": blocked_now.has(node_id),
			"blocked_turn": -1,
			"pressure_now": int(game_state.get_node_danger(node_id)),
			"future_pressure": 0,
			"path_pressure": 0,
			"risk_score": 0,
			"risk_band": RISK_SAFE,
			"summary": "",
		}
		var risk_score := 0
		if bool(report.get("blocked_now", false)):
			risk_score += 100
		for raw_snapshot in snapshots:
			var snapshot: Dictionary = Dictionary(raw_snapshot).duplicate(true)
			var turn := int(snapshot.get("turn", 0))
			var blocked_nodes: Array = Array(snapshot.get("blocked_nodes", [])).duplicate(true)
			var pressure_by_node: Dictionary = Dictionary(snapshot.get("pressure_by_node", {})).duplicate(true)
			if int(report.get("blocked_turn", -1)) < 0 and blocked_nodes.has(node_id):
				report["blocked_turn"] = turn
			var future_pressure := int(pressure_by_node.get(node_id, 0))
			report["future_pressure"] = maxi(int(report.get("future_pressure", 0)), future_pressure)
			risk_score += future_pressure * (4 if turn == 1 else 2)
			for raw_path_node in Array(report.get("path", [])).duplicate(true):
				var path_node_id := int(raw_path_node)
				if path_node_id == current_node_id or path_node_id == node_id:
					continue
				report["path_pressure"] = int(report.get("path_pressure", 0)) + int(pressure_by_node.get(path_node_id, 0))
				if blocked_nodes.has(path_node_id):
					risk_score += 8 if turn == 1 else 4
		if int(report.get("blocked_turn", -1)) == 1:
			risk_score += 40
		elif int(report.get("blocked_turn", -1)) == 2:
			risk_score += 18
		risk_score += int(report.get("pressure_now", 0)) * 5
		risk_score += int(report.get("path_pressure", 0)) * 2
		report["risk_score"] = risk_score
		report["risk_band"] = _risk_band_for_report(report)
		report["summary"] = _build_summary(report)
		reports.append(report)
	reports.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("risk_score", 0))
		var score_b := int(b.get("risk_score", 0))
		if score_a != score_b:
			return score_a < score_b
		var future_a := int(a.get("future_pressure", 0))
		var future_b := int(b.get("future_pressure", 0))
		if future_a != future_b:
			return future_a < future_b
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	return reports

func format_compact_lines(reports: Array, max_lines: int = 3) -> Array[String]:
	var lines: Array[String] = []
	for raw_report in reports.slice(0, max_lines):
		var report: Dictionary = Dictionary(raw_report).duplicate(true)
		lines.append("• %s" % String(report.get("summary", "")))
	return lines

func _build_forecast_snapshots(states: Array, node_lookup: Dictionary, forecast_turns: int) -> Array:
	var snapshots: Array = []
	var simulated_states: Array = []
	for raw_state in states:
		simulated_states.append(Dictionary(raw_state).duplicate(true))
	var current_turn := 0
	var game_state := _game_state()
	if game_state != null:
		current_turn = int(game_state.season_turn)
	for turn in range(1, maxi(0, forecast_turns) + 1):
		var target_turn := current_turn + turn
		var blocked_nodes: Array[int] = []
		var pressure_by_node := {}
		for index in range(simulated_states.size()):
			var state: Dictionary = Dictionary(simulated_states[index]).duplicate(true)
			var route: Array = Array(state.get("route", [])).duplicate(true)
			if route.is_empty():
				simulated_states[index] = state
				continue
			var spawn_turn := int(state.get("spawn_turn", 1))
			if target_turn < spawn_turn:
				simulated_states[index] = state
				continue
			if not bool(state.get("active", false)):
				state["active"] = true
			state["route_index"] = _next_route_index(state, route.size())
			var current_node := int(route[int(state.get("route_index", 0))])
			state["current_node_id"] = current_node
			if bool(state.get("block_node", false)) and not blocked_nodes.has(current_node):
				blocked_nodes.append(current_node)
			_add_pressure(pressure_by_node, current_node, maxi(1, int(state.get("danger_gain", 1))))
			var spillover := int(state.get("spillover_danger", 0))
			if spillover > 0:
				for neighbor_id in _neighbors(current_node, node_lookup):
					_add_pressure(pressure_by_node, neighbor_id, spillover)
			simulated_states[index] = state
		snapshots.append({
			"turn": turn,
			"blocked_nodes": blocked_nodes,
			"pressure_by_node": pressure_by_node,
		})
	return snapshots

func _blocked_node_ids(states: Array) -> Array[int]:
	var blocked: Array[int] = []
	for raw_state in states:
		var state: Dictionary = Dictionary(raw_state).duplicate(true)
		if not bool(state.get("active", false)) or not bool(state.get("block_node", false)):
			continue
		var node_id := int(state.get("current_node_id", -1))
		if node_id < 0 or blocked.has(node_id):
			continue
		blocked.append(node_id)
	return blocked

func _next_route_index(state: Dictionary, route_size: int) -> int:
	if route_size <= 0:
		return -1
	var current_index := int(state.get("route_index", -1))
	if current_index < 0:
		return 0
	if bool(state.get("loop_route", true)):
		return (current_index + 1) % route_size
	return mini(route_size - 1, current_index + 1)

func _neighbors(node_id: int, node_lookup: Dictionary) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = Dictionary(node_lookup.get(node_id, {})).duplicate(true)
	for raw_neighbor_id in Array(node.get("edges", [])).duplicate(true):
		var next_id := int(raw_neighbor_id)
		if not neighbors.has(next_id):
			neighbors.append(next_id)
	return neighbors

func _add_pressure(pressure_by_node: Dictionary, node_id: int, amount: int) -> void:
	pressure_by_node[node_id] = int(pressure_by_node.get(node_id, 0)) + amount

func _risk_band_for_report(report: Dictionary) -> String:
	if bool(report.get("blocked_now", false)):
		return RISK_BLOCKED
	if int(report.get("blocked_turn", -1)) == 1:
		return RISK_HOT
	var score := int(report.get("risk_score", 0))
	if score >= 22:
		return RISK_HOT
	if score >= 8:
		return RISK_WATCH
	return RISK_SAFE

func _build_summary(report: Dictionary) -> String:
	var band := String(report.get("risk_band", RISK_SAFE))
	var name := String(report.get("name", "未知节点"))
	var label := _risk_label(band)
	var notes: Array[String] = []
	if bool(report.get("blocked_now", false)):
		notes.append("当前已封锁")
	elif int(report.get("blocked_turn", -1)) > 0:
		notes.append("T+%d 可能被封" % int(report.get("blocked_turn", -1)))
	var future_pressure := int(report.get("future_pressure", 0))
	if future_pressure > 0:
		notes.append("后续危险 %+d" % future_pressure)
	var path_pressure := int(report.get("path_pressure", 0))
	if path_pressure > 0:
		notes.append("沿途压力 %+d" % path_pressure)
	var pressure_now := int(report.get("pressure_now", 0))
	if pressure_now > 0:
		notes.append("当前危险 %d" % pressure_now)
	if notes.is_empty():
		notes.append("短线较稳")
	return "%s：%s｜%s" % [name, label, " / ".join(notes)]

func _risk_label(band: String) -> String:
	match band:
		RISK_BLOCKED:
			return "封锁"
		RISK_HOT:
			return "高压"
		RISK_WATCH:
			return "可赌"
		_:
			return "较稳"

func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result

func _game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")

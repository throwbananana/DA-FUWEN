class_name ThreatService
extends RefCounted

func setup_for_season(season_id: String) -> void:
	var states: Array = []
	for threat in DataRepository.get_board_threats_for_season(season_id):
		var route: Array[int] = []
		for node_id in threat.get("route", []):
			route.append(int(node_id))
		states.append({
			"id": String(threat.get("id", "")),
			"name": String(threat.get("name", "敌对群")),
			"spawn_turn": int(threat.get("spawn_turn", 1)),
			"route": route,
			"route_index": -1,
			"active": false,
			"current_node_id": -1,
			"danger_gain": int(threat.get("danger_gain", 1)),
			"spillover_danger": int(threat.get("spillover_danger", 0)),
			"block_node": bool(threat.get("block_node", true)),
			"loop_route": bool(threat.get("loop_route", true)),
			"player_ambush": int(threat.get("player_ambush", 1)),
		})
	GameState.set_active_board_threats(states)

func advance_turn(season_turn: int, node_lookup: Dictionary, player_node_id: int) -> Dictionary:
	var states := GameState.get_active_board_threats()
	var lines: Array[String] = []
	for index in range(states.size()):
		var state: Dictionary = states[index].duplicate(true)
		var route: Array = state.get("route", [])
		if route.is_empty():
			states[index] = state
			continue
		var spawn_turn := int(state.get("spawn_turn", 1))
		if season_turn < spawn_turn:
			states[index] = state
			continue
		var was_active := bool(state.get("active", false))
		var previous_node_id := int(state.get("current_node_id", -1))
		state["active"] = true
		state["route_index"] = _next_route_index(state, route.size())
		var current_node_id := int(route[int(state.get("route_index", 0))])
		state["current_node_id"] = current_node_id
		_apply_pressure(current_node_id, state, node_lookup)
		var line := _movement_line(state, node_lookup, was_active, previous_node_id, current_node_id)
		if not line.is_empty():
			lines.append(line)
		if current_node_id == player_node_id:
			var ambush_count := maxi(1, int(state.get("player_ambush", 1)))
			GameState.queue_node_ambush(current_node_id, ambush_count)
			lines.append("%s 已逼近你所在的 %s，下次进点前会先遭遇袭扰。" % [
				String(state.get("name", "敌对群")),
				_node_name(current_node_id, node_lookup),
			])
		states[index] = state
	GameState.set_active_board_threats(states)
	return {
		"lines": lines,
		"blocked_nodes": get_blocked_node_ids(),
	}

func get_blocked_node_ids() -> Array[int]:
	var blocked: Array[int] = []
	for state in GameState.get_active_board_threats():
		if not bool(state.get("active", false)) or not bool(state.get("block_node", false)):
			continue
		var node_id := int(state.get("current_node_id", -1))
		if node_id < 0 or blocked.has(node_id):
			continue
		blocked.append(node_id)
	return blocked

func build_node_markers() -> Dictionary:
	var markers := {}
	for state in GameState.get_active_board_threats():
		if not bool(state.get("active", false)):
			continue
		var node_id := int(state.get("current_node_id", -1))
		if node_id < 0:
			continue
		if not markers.has(node_id):
			markers[node_id] = []
		markers[node_id].append(String(state.get("name", "敌对群")))
	return markers

func build_status_lines(node_lookup: Dictionary, max_lines: int = 3, include_forecast: bool = true) -> Array[String]:
	var lines: Array[String] = []
	for state in GameState.get_active_board_threats():
		if not bool(state.get("active", false)):
			continue
		var node_id := int(state.get("current_node_id", -1))
		lines.append("%s：占据 %s" % [
			String(state.get("name", "敌对群")),
			_node_name(node_id, node_lookup),
		])
		if lines.size() >= max_lines:
			break
	if lines.is_empty():
		lines.append("暂未发现游走敌群。")
	if include_forecast and lines.size() < max_lines:
		lines.append_array(build_forecast(node_lookup, 2, max_lines - lines.size()))
	return lines

func build_forecast(node_lookup: Dictionary, turns_ahead: int = 2, max_lines: int = 3) -> Array[String]:
	var lines: Array[String] = []
	if turns_ahead <= 0 or max_lines <= 0:
		return lines
	for state in GameState.get_active_board_threats():
		var entry := _build_forecast_entry(Dictionary(state).duplicate(true), node_lookup, turns_ahead)
		if entry.is_empty():
			continue
		lines.append(entry)
		if lines.size() >= max_lines:
			break
	return lines

func get_projected_blocked_node_ids(turns_ahead: int = 1) -> Array[int]:
	var blocked: Array[int] = []
	if turns_ahead <= 0:
		return blocked
	for state in GameState.get_active_board_threats():
		if not bool(Dictionary(state).get("block_node", false)):
			continue
		var node_id := _project_state_node_id(Dictionary(state).duplicate(true), turns_ahead)
		if node_id < 0 or blocked.has(node_id):
			continue
		blocked.append(node_id)
	return blocked

func get_high_risk_node_ids(turns_ahead: int = 2) -> Array[int]:
	var risk_nodes: Array[int] = []
	if turns_ahead <= 0:
		return risk_nodes
	for state in GameState.get_active_board_threats():
		for step in range(1, turns_ahead + 1):
			var node_id := _project_state_node_id(Dictionary(state).duplicate(true), step)
			if node_id < 0 or risk_nodes.has(node_id):
				continue
			risk_nodes.append(node_id)
	return risk_nodes

func build_forecast_snapshot(season_turn: int, node_lookup: Dictionary, steps: int = 2) -> Dictionary:
	var future_states: Array = Array(GameState.get_active_board_threats()).duplicate(true)
	var reports: Array[Dictionary] = []
	var safe_steps := maxi(1, steps)
	for offset in range(1, safe_steps + 1):
		var target_turn := season_turn + offset
		var blocked_nodes: Array[int] = []
		var pressured_nodes: Array[int] = []
		var lines: Array[String] = []
		for index in range(future_states.size()):
			var state: Dictionary = Dictionary(future_states[index]).duplicate(true)
			var route: Array = Array(state.get("route", [])).duplicate(true)
			if route.is_empty():
				future_states[index] = state
				continue
			var spawn_turn := int(state.get("spawn_turn", 1))
			if target_turn < spawn_turn:
				future_states[index] = state
				continue
			var was_active := bool(state.get("active", false))
			var previous_node_id := int(state.get("current_node_id", -1))
			state["active"] = true
			state["route_index"] = _next_route_index(state, route.size())
			var current_node_id := int(route[int(state.get("route_index", 0))])
			state["current_node_id"] = current_node_id
			if bool(state.get("block_node", false)):
				_append_unique_node_id(blocked_nodes, current_node_id)
			_append_unique_node_id(pressured_nodes, current_node_id)
			var spillover := int(state.get("spillover_danger", 0))
			if spillover > 0:
				for neighbor_id in _neighbors(current_node_id, node_lookup):
					_append_unique_node_id(pressured_nodes, neighbor_id)
			var line := _movement_line(state, node_lookup, was_active, previous_node_id, current_node_id)
			if not line.is_empty():
				lines.append(line)
			future_states[index] = state
		reports.append({
			"offset": offset,
			"season_turn": target_turn,
			"blocked_nodes": blocked_nodes,
			"pressured_nodes": pressured_nodes,
			"lines": lines,
		})
	return {"steps": reports}

func build_forecast_lines(season_turn: int, node_lookup: Dictionary, max_lines: int = 3, steps: int = 2) -> Array[String]:
	var snapshot := build_forecast_snapshot(season_turn, node_lookup, steps)
	var lines: Array[String] = []
	for raw_step in Array(snapshot.get("steps", [])).duplicate(true):
		var step: Dictionary = Dictionary(raw_step).duplicate(true)
		var offset := int(step.get("offset", 1))
		var blocked_names := _node_names(Array(step.get("blocked_nodes", [])).duplicate(true), node_lookup)
		if not blocked_names.is_empty():
			lines.append("T+%d 封锁：%s" % [offset, " / ".join(blocked_names.slice(0, 2))])
			if lines.size() >= max_lines:
				break
		var pressured_names := _node_names(Array(step.get("pressured_nodes", [])).duplicate(true), node_lookup)
		if pressured_names.size() > blocked_names.size():
			lines.append("T+%d 高压：%s" % [offset, " / ".join(pressured_names.slice(0, 3))])
			if lines.size() >= max_lines:
				break
		if blocked_names.is_empty() and pressured_names.is_empty():
			continue
	if lines.is_empty():
		lines.append("未来两拍暂未看到新的路线封锁。")
	return lines

func _build_forecast_entry(state: Dictionary, node_lookup: Dictionary, turns_ahead: int) -> String:
	var node_id := _project_state_node_id(state, turns_ahead)
	if node_id < 0:
		return ""
	return "%s：预计 %d 回合后压到 %s" % [
		String(state.get("name", "敌对群")),
		turns_ahead,
		_node_name(node_id, node_lookup),
	]

func _project_state_node_id(state: Dictionary, turns_ahead: int) -> int:
	var route: Array = state.get("route", [])
	if route.is_empty() or turns_ahead <= 0:
		return -1
	var route_index := int(state.get("route_index", -1))
	for _step in range(turns_ahead):
		route_index = _advance_index(route_index, route.size(), bool(state.get("loop_route", true)))
	if route_index < 0 or route_index >= route.size():
		return -1
	return int(route[route_index])

func _next_route_index(state: Dictionary, route_size: int) -> int:
	return _advance_index(int(state.get("route_index", -1)), route_size, bool(state.get("loop_route", true)))

func _advance_index(current_index: int, route_size: int, loop_route: bool) -> int:
	if route_size <= 0:
		return -1
	if current_index < 0:
		return 0
	if loop_route:
		return (current_index + 1) % route_size
	return mini(route_size - 1, current_index + 1)

func _apply_pressure(node_id: int, state: Dictionary, node_lookup: Dictionary) -> void:
	var danger_gain := maxi(1, int(state.get("danger_gain", 1)))
	GameState.add_node_danger(node_id, danger_gain)
	var spillover := int(state.get("spillover_danger", 0))
	if spillover <= 0:
		return
	for neighbor_id in _neighbors(node_id, node_lookup):
		GameState.add_node_danger(neighbor_id, spillover)

func _movement_line(state: Dictionary, node_lookup: Dictionary, was_active: bool, previous_node_id: int, current_node_id: int) -> String:
	var name := String(state.get("name", "敌对群"))
	if not was_active:
		return "%s 已进入 %s，并开始封锁这个落点。" % [name, _node_name(current_node_id, node_lookup)]
	if previous_node_id != current_node_id:
		return "%s 转向 %s，路线压力重新分布。" % [name, _node_name(current_node_id, node_lookup)]
	return "%s 继续盘踞在 %s。" % [name, _node_name(current_node_id, node_lookup)]

func _neighbors(node_id: int, node_lookup: Dictionary) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = node_lookup.get(node_id, {})
	for neighbor_id in node.get("edges", []):
		var next_id := int(neighbor_id)
		if not neighbors.has(next_id):
			neighbors.append(next_id)
	return neighbors

func _append_unique_node_id(target: Array[int], node_id: int) -> void:
	if node_id < 0 or target.has(node_id):
		return
	target.append(node_id)

func _node_names(node_ids: Array, node_lookup: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_node_id in node_ids:
		var node_id := int(raw_node_id)
		var node_name := _node_name(node_id, node_lookup)
		if names.has(node_name):
			continue
		names.append(node_name)
	return names

func _node_name(node_id: int, node_lookup: Dictionary) -> String:
	return String(node_lookup.get(node_id, {}).get("name", "未知节点"))

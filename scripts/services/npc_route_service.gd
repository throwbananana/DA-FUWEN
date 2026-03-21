class_name NpcRouteService
extends RefCounted

func sync_daily_positions() -> Dictionary:
	var previous_positions: Dictionary = GameState.get_npc_positions()
	var current_positions := {}
	var lines: Array[String] = []
	for route in DataRepository.get_npc_routes_for_season(GameState.season_id):
		var npc_id := String(route.get("npc_id", ""))
		if npc_id.is_empty():
			continue
		var habitat_id := _current_habitat_for_route(route, GameState.global_turn, GameState.week_index, GameState.weekly_turn)
		var npc_name := String(DataRepository.get_npc(npc_id).get("name", npc_id))
		var previous_habitat_id := String(previous_positions.get(npc_id, ""))
		if habitat_id.is_empty():
			if not previous_habitat_id.is_empty():
				lines.append("%s 今天离开了公开路线。" % npc_name)
			continue
		if _blocked_habitat_ids().has(habitat_id):
			if not previous_habitat_id.is_empty():
				lines.append("%s 受敌群封锁影响，今天没有按时出现。" % npc_name)
			continue
		current_positions[npc_id] = habitat_id
		if previous_habitat_id != habitat_id:
			lines.append("%s 今天会在 %s 出现。" % [npc_name, _habitat_name(habitat_id)])
	GameState.set_npc_positions(current_positions)
	return {"lines": lines}

func get_visible_npcs(habitat_id: String) -> Array:
	var visible: Array = []
	var positions: Dictionary = GameState.get_npc_positions()
	for npc in DataRepository.npcs.values():
		var npc_id := String(npc.get("id", ""))
		if npc_id.is_empty():
			continue
		var role := String(npc.get("role", "resident"))
		if role == "traveler":
			if String(positions.get(npc_id, "")) != habitat_id:
				continue
		elif String(npc.get("home", "")) != habitat_id:
			continue
		visible.append(npc)
	visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_traveler := String(a.get("role", "")) == "traveler"
		var b_traveler := String(b.get("role", "")) == "traveler"
		if a_traveler != b_traveler:
			return not a_traveler
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	return visible

func get_presence_report(habitat_id: String) -> Dictionary:
	var visible_npcs := get_visible_npcs(habitat_id)
	var visible_names: Array[String] = []
	for npc in visible_npcs:
		visible_names.append(String(npc.get("name", "")))
	var window_lines: Array[String] = []
	for route in DataRepository.get_npc_routes_for_season(GameState.season_id):
		if not Array(route.get("cycle", [])).has(habitat_id):
			continue
		var npc_id := String(route.get("npc_id", ""))
		var npc_name := String(DataRepository.get_npc(npc_id).get("name", npc_id))
		var current_habitat_id := String(GameState.get_npc_positions().get(npc_id, ""))
		if current_habitat_id == habitat_id:
			window_lines.append("%s 正在这里停留。" % npc_name)
			continue
		var forecast := _forecast_next_stop(route, habitat_id)
		if not forecast.is_empty():
			window_lines.append("%s 下次会在第 %d 周第 %d 天路过。" % [
				npc_name,
				int(forecast.get("week_index", 0)),
				int(forecast.get("weekly_turn", 0)),
			])
	return {
		"visible_npcs": visible_npcs,
		"visible_names": visible_names,
		"window_lines": window_lines,
	}

func build_node_markers() -> Dictionary:
	var markers := {}
	for npc_id in GameState.get_npc_positions().keys():
		var habitat_id := String(GameState.get_npc_positions().get(npc_id, ""))
		var node_id := _node_id_for_habitat(habitat_id)
		if node_id < 0:
			continue
		if not markers.has(node_id):
			markers[node_id] = []
		markers[node_id].append(String(DataRepository.get_npc(npc_id).get("name", npc_id)))
	return markers

func build_status_lines(max_lines: int = 3) -> Array[String]:
	var lines: Array[String] = []
	for npc_id in GameState.get_npc_positions().keys():
		lines.append("%s：%s" % [
			String(DataRepository.get_npc(String(npc_id)).get("name", String(npc_id))),
			_habitat_name(String(GameState.get_npc_positions()[npc_id])),
		])
		if lines.size() >= max_lines:
			break
	if lines.is_empty():
		lines.append("今天没有流动访客。")
	return lines

func _forecast_next_stop(route: Dictionary, habitat_id: String, lookahead_turns: int = 10) -> Dictionary:
	for offset in range(1, lookahead_turns + 1):
		var next_global_turn: int = GameState.global_turn + offset
		var next_weekly_turn: int = ((GameState.weekly_turn - 1 + offset) % 5) + 1
		var next_week_index: int = GameState.week_index + int((GameState.weekly_turn - 1 + offset) / 5)
		var next_habitat_id := _current_habitat_for_route(route, next_global_turn, next_week_index, next_weekly_turn)
		if next_habitat_id == habitat_id:
			return {
				"week_index": next_week_index,
				"weekly_turn": next_weekly_turn,
			}
	return {}

func _current_habitat_for_route(route: Dictionary, global_turn: int, _week_index: int, weekly_turn: int) -> String:
	if not _is_turn_active(route, weekly_turn):
		return ""
	var cycle: Array = route.get("cycle", [])
	if cycle.is_empty():
		return ""
	var offset := int(route.get("offset", 0))
	var route_index := posmod(global_turn - 1 + offset, cycle.size())
	return String(cycle[route_index])

func _is_turn_active(route: Dictionary, weekly_turn: int) -> bool:
	var active_turns: Array = route.get("active_turns", [])
	if active_turns.is_empty():
		return true
	for raw_turn in active_turns:
		if int(raw_turn) == weekly_turn:
			return true
	return false

func _blocked_habitat_ids() -> Array[String]:
	var blocked: Array[String] = []
	for threat in GameState.get_active_board_threats():
		if not bool(threat.get("active", false)):
			continue
		var node_id := int(threat.get("current_node_id", -1))
		if node_id < 0:
			continue
		var habitat_id := String(_region_node_lookup().get(node_id, {}).get("habitat_id", ""))
		if habitat_id.is_empty() or blocked.has(habitat_id):
			continue
		blocked.append(habitat_id)
	return blocked

func _node_id_for_habitat(habitat_id: String) -> int:
	var fallback_node_id := -1
	for node in _region_node_lookup().values():
		if String(node.get("habitat_id", "")) == habitat_id:
			var node_id := int(node.get("id", -1))
			if String(node.get("primary_content", "")) == "npc_menu":
				return node_id
			if fallback_node_id < 0:
				fallback_node_id = node_id
	return fallback_node_id

func _region_node_lookup() -> Dictionary:
	var lookup := {}
	var region := DataRepository.get_board_region(GameState.board_region_id)
	for node in region.get("nodes", []):
		lookup[int(node.get("id", -1))] = node
	return lookup

func _habitat_name(habitat_id: String) -> String:
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

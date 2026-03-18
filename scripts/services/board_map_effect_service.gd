class_name BoardMapEffectService
extends RefCounted

func apply_on_arrival(node: Dictionary, node_id: int, region_id: String, boss_node_id: int, node_lookup: Dictionary) -> Dictionary:
	if not _supports_map_effect(node):
		return {}
	var effect_id := String(node.get("map_effect_id", ""))
	if effect_id.is_empty():
		return {}
	var effect_row := DataRepository.get_board_map_effect(effect_id)
	if effect_row.is_empty():
		return {}
	if String(effect_row.get("trigger", "arrival")) != "arrival":
		return {}
	var effect_key := _effect_key(region_id, node_id, effect_id)
	if bool(effect_row.get("once_per_node", true)) and GameState.has_map_effect_trigger(effect_key):
		return {}

	var lines: Array[String] = []
	for raw_effect in effect_row.get("effects", []):
		var effect: Dictionary = Dictionary(raw_effect)
		for line in _apply_effect(effect, node_id, boss_node_id, node_lookup):
			if not String(line).is_empty():
				lines.append(String(line))

	if bool(effect_row.get("once_per_node", true)):
		GameState.mark_map_effect_trigger(effect_key)

	return {
		"id": effect_id,
		"title": String(effect_row.get("title", "地图效果")),
		"description": String(effect_row.get("description", "")),
		"lines": lines,
	}

func preview_title(node: Dictionary) -> String:
	if not _supports_map_effect(node):
		return ""
	var effect_id := String(node.get("map_effect_id", ""))
	if effect_id.is_empty():
		return ""
	return String(DataRepository.get_board_map_effect(effect_id).get("title", ""))

func has_pending_effect(node: Dictionary, node_id: int, region_id: String) -> bool:
	if not _supports_map_effect(node):
		return false
	var effect_id := String(node.get("map_effect_id", ""))
	if effect_id.is_empty():
		return false
	var effect_row := DataRepository.get_board_map_effect(effect_id)
	if effect_row.is_empty():
		return false
	if not bool(effect_row.get("once_per_node", true)):
		return true
	return not GameState.has_map_effect_trigger(_effect_key(region_id, node_id, effect_id))

func _apply_effect(effect: Dictionary, node_id: int, boss_node_id: int, node_lookup: Dictionary) -> Array[String]:
	match String(effect.get("type", "")):
		"reveal_ahead":
			return _apply_reveal_ahead(effect, node_id, boss_node_id, node_lookup)
		"grant_resource":
			return _apply_grant_resource(effect)
		"reduce_danger":
			return _apply_reduce_danger(effect, node_id, node_lookup)
		"clear_ambush":
			return _apply_clear_ambush(effect, node_id)
		"retreat_threats":
			return _apply_retreat_threats(effect, node_lookup)
		_:
			return []

func _apply_reveal_ahead(effect: Dictionary, node_id: int, boss_node_id: int, node_lookup: Dictionary) -> Array[String]:
	var amount := maxi(1, int(effect.get("amount", 1)))
	var revealed_ids: Array[int] = []
	for reveal_id in range(node_id + 1, mini(boss_node_id, node_id + amount) + 1):
		if GameState.revealed_board_nodes.has(reveal_id):
			continue
		revealed_ids.append(reveal_id)
	GameState.reveal_board_nodes(revealed_ids)
	if revealed_ids.is_empty():
		return ["前方没有新的路况被揭开。"]
	return ["额外显露前方 %d 格：%s" % [revealed_ids.size(), " / ".join(_node_names(revealed_ids, node_lookup, 3))]]

func _apply_grant_resource(effect: Dictionary) -> Array[String]:
	var resource := String(effect.get("resource", ""))
	var amount := maxi(1, int(effect.get("amount", 1)))
	match resource:
		"season_adjust_points":
			GameState.season_adjust_points += amount
			return ["修正点 +%d" % amount]
		"anchor_points":
			GameState.anchor_points += amount
			return ["锚定点 +%d" % amount]
		"weekly_reroll_limit":
			GameState.weekly_reroll_limit += amount
			return ["本周重掷上限 +%d" % amount]
		_:
			return []

func _apply_reduce_danger(effect: Dictionary, node_id: int, node_lookup: Dictionary) -> Array[String]:
	var scope := String(effect.get("scope", "current"))
	var amount := maxi(1, int(effect.get("amount", 1)))
	var targets: Array[int] = [node_id]
	if scope == "current_and_neighbors":
		for raw_neighbor in Dictionary(node_lookup.get(node_id, {})).get("edges", []):
			var neighbor_id := int(raw_neighbor)
			if not targets.has(neighbor_id):
				targets.append(neighbor_id)
	var changed_names: Array[String] = []
	for target_id in targets:
		var before := GameState.get_node_danger(target_id)
		if before <= 0:
			continue
		GameState.reduce_node_danger(target_id, amount)
		if GameState.get_node_danger(target_id) < before:
			changed_names.append(_node_name(target_id, node_lookup))
	if changed_names.is_empty():
		return ["周边危险暂时没有进一步下降。"]
	return ["危险回落：%s" % " / ".join(changed_names.slice(0, 3))]

func _apply_clear_ambush(_effect: Dictionary, node_id: int) -> Array[String]:
	if not GameState.has_node_ambush(node_id):
		return ["这里暂时没有额外袭扰需要排除。"]
	GameState.clear_node_ambush(node_id)
	return ["已清除这个落点的袭扰预警。"]

func _apply_retreat_threats(effect: Dictionary, node_lookup: Dictionary) -> Array[String]:
	var amount := maxi(1, int(effect.get("amount", 1)))
	var states := GameState.get_active_board_threats()
	var moved_lines: Array[String] = []
	for index in range(states.size()):
		var state: Dictionary = Dictionary(states[index]).duplicate(true)
		if not bool(state.get("active", false)):
			states[index] = state
			continue
		var route: Array = state.get("route", [])
		if route.is_empty():
			states[index] = state
			continue
		var route_index := int(state.get("route_index", -1))
		if route_index < 0:
			states[index] = state
			continue
		var next_index := route_index - amount
		if next_index < 0:
			state["active"] = false
			state["route_index"] = -1
			state["current_node_id"] = -1
			moved_lines.append("%s 暂时退离前线" % String(state.get("name", "敌对群")))
		else:
			state["route_index"] = next_index
			state["current_node_id"] = int(route[next_index])
			moved_lines.append("%s 后撤到 %s" % [
				String(state.get("name", "敌对群")),
				_node_name(int(route[next_index]), node_lookup),
			])
		states[index] = state
	GameState.set_active_board_threats(states)
	if moved_lines.is_empty():
		return ["这附近暂时没有已进场的敌群需要逼退。"]
	return ["敌群后撤：%s" % " / ".join(moved_lines.slice(0, 2))]

func _effect_key(region_id: String, node_id: int, effect_id: String) -> String:
	return "%s:%d:%s" % [region_id, node_id, effect_id]

func _supports_map_effect(node: Dictionary) -> bool:
	return String(node.get("type", "")) in ["habitat", "settlement", "dojo", "anomaly"]

func _node_names(node_ids: Array[int], node_lookup: Dictionary, max_items: int) -> Array[String]:
	var names: Array[String] = []
	for node_id in node_ids.slice(0, max_items):
		names.append(_node_name(int(node_id), node_lookup))
	if node_ids.size() > max_items:
		names.append("等 %d 格" % node_ids.size())
	return names

func _node_name(node_id: int, node_lookup: Dictionary) -> String:
	return String(Dictionary(node_lookup.get(node_id, {})).get("name", "%d 号节点" % node_id))

class_name TurnRoutePlanningService
extends RefCounted

static func filter_blocked_selectable_nodes(candidate_nodes: Array, blocked_node_ids: Array) -> Array[int]:
	var blocked := _node_set(blocked_node_ids)
	var filtered: Array[int] = []
	for raw_node_id in candidate_nodes:
		var node_id := int(raw_node_id)
		if blocked.has(node_id):
			continue
		filtered.append(node_id)
	return filtered

static func reachable_selectable_nodes(reachable_paths: Dictionary, board_lookup: Dictionary, board_progression_service) -> Array[int]:
	var selectable: Array[int] = []
	for raw_node_id in reachable_paths.keys():
		var node_id := int(raw_node_id)
		if not board_lookup.has(node_id):
			continue
		if board_progression_service.is_node_locked(node_id):
			continue
		selectable.append(node_id)
	return selectable

static func blocked_reachable_nodes(reachable_paths: Dictionary, board_lookup: Dictionary, board_progression_service, blocked_node_ids: Array) -> Array[int]:
	return _intersect_nodes(reachable_selectable_nodes(reachable_paths, board_lookup, board_progression_service), blocked_node_ids)

static func build_roll_route_preview(current_node_id: int, roll_value: int, board_progression_service, board_lookup: Dictionary, blocked_node_ids: Array, revealed_node_ids: Array, can_anchor_override: bool, can_visit_habitat: Callable) -> Dictionary:
	var reachable_paths: Dictionary = board_progression_service.get_reachable_paths(current_node_id, roll_value)
	var blocked_before_anchor := blocked_reachable_nodes(reachable_paths, board_lookup, board_progression_service, blocked_node_ids)
	var selectable_nodes := filter_blocked_selectable_nodes(reachable_selectable_nodes(reachable_paths, board_lookup, board_progression_service), blocked_node_ids)
	var anchor_target := -1
	var anchor_override_active := false
	if selectable_nodes.is_empty() and can_anchor_override:
		anchor_target = pick_anchor_override_target(current_node_id, revealed_node_ids, blocked_node_ids, board_lookup, board_progression_service, can_visit_habitat)
		if anchor_target >= 0:
			anchor_override_active = true
			reachable_paths.clear()
			reachable_paths[anchor_target] = board_progression_service.get_shortest_path(current_node_id, anchor_target)
			selectable_nodes = filter_blocked_selectable_nodes(reachable_selectable_nodes(reachable_paths, board_lookup, board_progression_service), blocked_node_ids)
	return {
		"reachable_paths": reachable_paths.duplicate(true),
		"blocked_reachable_nodes": blocked_before_anchor,
		"selectable_nodes": selectable_nodes,
		"anchor_target": anchor_target,
		"anchor_override_active": anchor_override_active,
	}

static func pick_anchor_override_target(current_node_id: int, revealed_node_ids: Array, blocked_node_ids: Array, board_lookup: Dictionary, board_progression_service, can_visit_habitat: Callable) -> int:
	var blocked := _node_set(blocked_node_ids)
	var candidates: Array = []
	for raw_node_id in revealed_node_ids:
		var node_id := int(raw_node_id)
		if node_id == current_node_id or blocked.has(node_id) or board_progression_service.is_node_locked(node_id):
			continue
		var node: Dictionary = Dictionary(board_lookup.get(node_id, {})).duplicate(true)
		if node.is_empty():
			continue
		if String(node.get("type", "")) == "camp":
			var camp_path: Array = board_progression_service.get_shortest_path(current_node_id, node_id)
			if camp_path.size() >= 2:
				candidates.append({
					"node_id": node_id,
					"path": camp_path,
				})
			continue
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty() or not bool(can_visit_habitat.call(habitat_id)):
			continue
		var path: Array = board_progression_service.get_shortest_path(current_node_id, node_id)
		if path.size() < 2:
			continue
		candidates.append({
			"node_id": node_id,
			"path": path,
		})
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_path: Array = a.get("path", [])
		var b_path: Array = b.get("path", [])
		if a_path.size() != b_path.size():
			return a_path.size() < b_path.size()
		return int(a.get("node_id", -1)) < int(b.get("node_id", -1))
	)
	return int(candidates[0].get("node_id", -1))

static func build_travel_seed(current_node_id: int, pending_roll: Dictionary, reachable_paths: Dictionary, anchor_override_active: bool) -> Dictionary:
	var forced_path: Array[int] = []
	var forced_index := -1
	var steps_remaining := int(pending_roll.get("value", 0))
	if anchor_override_active and reachable_paths.size() == 1:
		var only_target := int(reachable_paths.keys()[0])
		for raw_node_id in Array(reachable_paths.get(only_target, [])).duplicate(true):
			forced_path.append(int(raw_node_id))
		forced_index = 0
		steps_remaining = maxi(0, forced_path.size() - 1)
	return {
		"route_history": [current_node_id],
		"steps_remaining": steps_remaining,
		"forced_path": forced_path,
		"forced_index": forced_index,
	}

static func _node_set(node_ids: Array) -> Dictionary:
	var result := {}
	for raw_node_id in node_ids:
		result[int(raw_node_id)] = true
	return result

static func _intersect_nodes(candidate_nodes: Array, blocked_node_ids: Array) -> Array[int]:
	var blocked := _node_set(blocked_node_ids)
	var result: Array[int] = []
	for raw_node_id in candidate_nodes:
		var node_id := int(raw_node_id)
		if blocked.has(node_id):
			result.append(node_id)
	return result

class_name BoardProgressionService
extends RefCounted

var current_region: Dictionary = {}
var node_lookup: Dictionary = {}

func set_region_for_season(season_id: String) -> void:
	current_region = DataRepository.get_board_region_for_season(season_id)
	_rebuild_lookup()

func get_region() -> Dictionary:
	return current_region.duplicate(true)

func get_region_name() -> String:
	return String(current_region.get("name", "未命名区域"))

func get_region_id() -> String:
	return String(current_region.get("id", ""))

func get_start_node_id() -> int:
	return int(current_region.get("start_node_id", 0))

func get_boss_node_id() -> int:
	return int(current_region.get("boss_node_id", -1))

func get_nodes() -> Array:
	var nodes: Array = []
	for node in current_region.get("nodes", []):
		nodes.append(_normalize_node(node))
	return nodes

func get_node(node_id: int) -> Dictionary:
	return node_lookup.get(node_id, {})

func get_reachable_paths(from_node_id: int, steps: int) -> Dictionary:
	var result := {}
	if from_node_id == -1:
		return result
	if steps <= 0:
		result[from_node_id] = [from_node_id]
		return result

	var frontier: Array = [{
		"node_id": from_node_id,
		"path": [from_node_id],
		"spent": 0,
	}]

	while not frontier.is_empty():
		var state: Dictionary = frontier.pop_front()
		var current_id := int(state.get("node_id", -1))
		var current_path: Array = state.get("path", []).duplicate()
		var spent := int(state.get("spent", 0))

		for neighbor_id in _neighbors(current_id):
			if current_path.has(neighbor_id):
				continue

			var move_cost := _step_cost(neighbor_id)
			var next_spent := spent + move_cost
			if next_spent > steps:
				continue

			var next_path := current_path.duplicate()
			next_path.append(neighbor_id)

			if next_spent == steps:
				if not result.has(neighbor_id):
					result[neighbor_id] = next_path
				continue

			frontier.append({
				"node_id": neighbor_id,
				"path": next_path,
				"spent": next_spent,
			})

	return result

func expand_reveal_from(node_id: int) -> Array[int]:
	var revealed: Array[int] = []
	if node_id == -1:
		return revealed
	revealed.append(node_id)
	for neighbor_id in _neighbors(node_id):
		if not revealed.has(neighbor_id):
			revealed.append(neighbor_id)
	return revealed

func _rebuild_lookup() -> void:
	node_lookup.clear()
	for node in get_nodes():
		node_lookup[int(node.get("id", -1))] = node

func _normalize_node(node: Dictionary) -> Dictionary:
	var normalized: Dictionary = node.duplicate(true)
	var raw_position = normalized.get("position", [0, 0])
	if raw_position is Array and raw_position.size() >= 2:
		normalized["position"] = Vector2(float(raw_position[0]), float(raw_position[1]))
	elif raw_position is Dictionary:
		normalized["position"] = Vector2(
			float(raw_position.get("x", 0.0)),
			float(raw_position.get("y", 0.0))
		)
	return normalized

func _neighbors(node_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = node_lookup.get(node_id, {})
	for raw_neighbor in node.get("edges", []):
		neighbors.append(int(raw_neighbor))
	return neighbors

func _step_cost(node_id: int) -> int:
	var node: Dictionary = node_lookup.get(node_id, {})
	return maxi(1, int(node.get("travel_cost", 1)))

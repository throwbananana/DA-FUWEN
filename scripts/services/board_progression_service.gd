class_name BoardProgressionService
extends RefCounted

const LEGACY_BUFFER_NODE_PRESETS := {
	"spring": {
		14: {
			"id": 14,
			"name": "林脊观测点",
			"type": "habitat",
			"description": "上路冲塔前新增的一段缓冲观察点，让后段路线不再一口气冲到终点前。",
			"position": Vector2(1180, 90),
			"edges": [9, 11],
			"travel_cost": 1,
			"habitat_id": "greenbark_grove",
			"primary_content": "observe",
			"focus": "缓冲 / 观察",
			"reward_hint": "先在这里确认局势，再决定要不要继续压向尖塔",
		},
		15: {
			"id": 15,
			"name": "潮湾回流坡",
			"type": "habitat",
			"description": "下路末段新增的回流坡，把返程线拆成两段，节奏更从容。",
			"position": Vector2(1180, 510),
			"edges": [10, 13],
			"travel_cost": 1,
			"habitat_id": "saltglass_coast",
			"primary_content": "observe",
			"focus": "回流 / 调整",
			"reward_hint": "在这里先修正下路节奏，再决定要不要顶到异常终点",
		},
	},
	"summer": {
		14: {
			"id": 14,
			"name": "雷痕高台",
			"type": "habitat",
			"description": "夏季上路新增的高台节点，把冲压路线拆成更清晰的两段。",
			"position": Vector2(1180, 90),
			"edges": [9, 11],
			"travel_cost": 1,
			"habitat_id": "saltglass_coast",
			"primary_content": "observe",
			"focus": "高台 / 侦察",
			"reward_hint": "先从高台看清雷暴节奏，再决定是否压向尖塔",
		},
		15: {
			"id": 15,
			"name": "盐镜回流坡",
			"type": "habitat",
			"description": "夏季下路新增的回流坡，把后段返程拆开，避免连续大岔路。",
			"position": Vector2(1180, 510),
			"edges": [10, 13],
			"travel_cost": 1,
			"habitat_id": "saltglass_coast",
			"primary_content": "build_menu",
			"focus": "回流 / 建设",
			"reward_hint": "这里决定你能不能把下路资源稳稳带到终点前",
		},
	},
	"autumn": {
		14: {
			"id": 14,
			"name": "锻火望台",
			"type": "habitat",
			"description": "秋季上路新增的望台，把冲演武场前的节奏拆得更舒展。",
			"position": Vector2(1180, 90),
			"edges": [9, 11],
			"travel_cost": 1,
			"habitat_id": "radiant_observatory",
			"primary_content": "observe",
			"focus": "望台 / 侦察",
			"reward_hint": "先在这里看清后段压力，再决定要不要直压演武场",
		},
		15: {
			"id": 15,
			"name": "净池回流坡",
			"type": "habitat",
			"description": "秋季下路新增的回流坡，让返程线多一段整理空间。",
			"position": Vector2(1180, 510),
			"edges": [10, 13],
			"travel_cost": 1,
			"habitat_id": "reed_mire",
			"primary_content": "build_menu",
			"focus": "回流 / 净化",
			"reward_hint": "在这里把下路局势整理好，再决定是否顶向终点",
		},
	},
	"winter": {
		14: {
			"id": 14,
			"name": "霜镜折光台",
			"type": "habitat",
			"description": "冬季上路新增的折光台，把终段推进拆成更清晰的两拍。",
			"position": Vector2(1180, 90),
			"edges": [9, 11],
			"travel_cost": 1,
			"habitat_id": "frost_mirror_lake",
			"primary_content": "observe",
			"focus": "折光 / 侦察",
			"reward_hint": "先看清雪线节奏，再决定是否继续压向遗迹",
		},
		15: {
			"id": 15,
			"name": "雪湾回流坡",
			"type": "habitat",
			"description": "冬季下路新增的回流坡，让返程线不会一口气切到终点前。",
			"position": Vector2(1180, 510),
			"edges": [10, 13],
			"travel_cost": 1,
			"habitat_id": "saltglass_coast",
			"primary_content": "build_menu",
			"focus": "回流 / 建设",
			"reward_hint": "在这里把下路局势压稳，再决定要不要顶向遗迹",
		},
	},
}

const REGION_NODE_COUNT := 60
const ROUTE_COLUMNS := 12
const VISUAL_COLUMN_STEP := 2
const GRID_ORIGIN := Vector2(70, 110)
const GRID_SPACING := Vector2(120, 150)
const CHECKPOINT_INTERVAL := 15
const REVEAL_BACKTRACK := 2
const REVEAL_LOOKAHEAD := 8
const CHECKPOINT_NAMES := {
	"spring": ["营地", "春芽补给营", "林脊整备营", "尖塔前哨"],
	"summer": ["营地", "雷暴补给营", "高热整备营", "尖塔前哨"],
	"autumn": ["营地", "赤叶补给营", "锻火整备营", "演武前哨"],
	"winter": ["营地", "雪线补给营", "镜潮整备营", "遗迹前哨"],
}
const SEGMENT_NAMES := ["前段", "中段", "深行", "终盘"]
const ENVIRONMENT_VARIANTS := {
	"spring": [
		{"name": "苔径浅湾", "kind": "forage", "focus": "采集 / 缓行", "description": "薄雾和苔径把主路拉成了一段能停下来喘口气的林间浅湾。", "reward_hint": "更容易顺手带回一点苔类和纤维。"},
		{"name": "雾缝林线", "kind": "scout", "focus": "侦察 / 探路", "description": "林线被湿雾切开，适合先看清后段路况再决定今天怎么压线。", "reward_hint": "能额外看清前方几格的地形变化。"},
		{"name": "湿苔兽道", "kind": "wild_battle", "focus": "遭遇 / 野战", "description": "这里有明显的兽道和折枝，路过时很容易惊动附近游荡的个体。", "reward_hint": "可能直接爆发一次短促的野外遭遇战。"},
	],
	"summer": [
		{"name": "潮热浅滩", "kind": "forage", "focus": "采集 / 热流", "description": "潮湿热浪把主干道边缘泡成了浅滩，适合快速搜一圈补给。", "reward_hint": "更容易捞到潮湿地带的基础素材。"},
		{"name": "雷痕高坡", "kind": "scout", "focus": "侦察 / 观势", "description": "高坡上满是旧雷痕，站上去能先看清风暴和路口的分布。", "reward_hint": "能提前显露一段后续路线。"},
		{"name": "灼风兽径", "kind": "wild_battle", "focus": "遭遇 / 突袭", "description": "热流里夹着躁动脚印，队伍一旦经过就很容易引来正面冲撞。", "reward_hint": "可能触发一次高压但回报更高的野外遭遇。"},
	],
	"autumn": [
		{"name": "落叶空坪", "kind": "forage", "focus": "采集 / 收拢", "description": "落叶把地面铺得很厚，是一段适合收拢补给、重新整顿脚步的空坪。", "reward_hint": "更容易捡到树脂和可加工材料。"},
		{"name": "风纹坡口", "kind": "scout", "focus": "侦察 / 预判", "description": "风纹在坡口交汇，能提前看清前方哪里有压强更高的遭遇点。", "reward_hint": "会额外揭开后续一段地图信息。"},
		{"name": "赤痕猎道", "kind": "wild_battle", "focus": "遭遇 / 试锋", "description": "这里留着新鲜的爪痕和冲撞印，基本意味着今天会有正面交锋。", "reward_hint": "可能直接进入一次野外对抗。"},
	],
	"winter": [
		{"name": "霜线雪凹", "kind": "forage", "focus": "采集 / 整备", "description": "雪线在这里压成了缓坡和雪凹，是长线推进里少数能停下来整理物资的地方。", "reward_hint": "更容易带回冰湖与遗迹边缘的基础素材。"},
		{"name": "镜雪断脊", "kind": "scout", "focus": "侦察 / 望远", "description": "折光的雪脊能把远处路线照得很清楚，适合先判断今天值不值得继续深压。", "reward_hint": "会额外显露前方几格路线。"},
		{"name": "寒痕伏道", "kind": "wild_battle", "focus": "遭遇 / 伏击", "description": "雪地里全是新鲜拖痕，队伍经过时很容易把潜伏个体逼出来。", "reward_hint": "可能触发一次偏伏击型的野外遭遇。"},
	],
}

var current_region: Dictionary = {}
var node_lookup: Dictionary = {}
var _seed_regions_by_season: Dictionary = {}

func set_region_for_season(season_id: String) -> void:
	var seed_region := _seed_region_for_season(season_id)
	current_region = _build_long_region(seed_region)
	_register_runtime_region(current_region)
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

			var next_spent := spent + 1
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

func get_shortest_path(from_node_id: int, to_node_id: int) -> Array[int]:
	if from_node_id == -1 or to_node_id == -1:
		return []
	if from_node_id == to_node_id:
		return [from_node_id]

	var frontier: Array[int] = [from_node_id]
	var parents := {from_node_id: -1}

	while not frontier.is_empty():
		var current_id := int(frontier.pop_front())
		for neighbor_id in _neighbors(current_id):
			if parents.has(neighbor_id):
				continue
			parents[neighbor_id] = current_id
			if neighbor_id == to_node_id:
				var path: Array[int] = [to_node_id]
				var walker := current_id
				while walker != -1:
					path.push_front(walker)
					walker = int(parents.get(walker, -1))
				return path
			frontier.append(neighbor_id)
	return []

func expand_reveal_from(node_id: int) -> Array[int]:
	var revealed: Array[int] = []
	if node_id == -1:
		return revealed
	var last_node_id := int(current_region.get("boss_node_id", REGION_NODE_COUNT - 1))
	for reveal_id in range(maxi(0, node_id - REVEAL_BACKTRACK), mini(last_node_id, node_id + REVEAL_LOOKAHEAD) + 1):
		revealed.append(reveal_id)
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

func _seed_region_for_season(season_id: String) -> Dictionary:
	if _seed_regions_by_season.has(season_id):
		return Dictionary(_seed_regions_by_season[season_id]).duplicate(true)
	var raw_region := DataRepository.get_board_region_for_season(season_id)
	var seed_region := _expand_seed_layout(raw_region)
	_seed_regions_by_season[season_id] = seed_region.duplicate(true)
	return seed_region

func _build_long_region(seed_region: Dictionary) -> Dictionary:
	if seed_region.is_empty():
		return {}
	var generated: Dictionary = seed_region.duplicate(true)
	var season_id := String(seed_region.get("season_id", ""))
	var boss_node_id := REGION_NODE_COUNT - 1
	var template_pool := _build_template_pool(seed_region, int(seed_region.get("boss_node_id", -1)))
	var boss_template := _build_boss_template(seed_region)
	var generated_nodes: Array = []
	var template_cursor := 0

	for node_id in range(REGION_NODE_COUNT):
		if node_id == boss_node_id:
			generated_nodes.append(_build_boss_node(season_id, boss_template, node_id))
			continue
		if _is_checkpoint(node_id):
			generated_nodes.append(_build_checkpoint_node(season_id, node_id))
			continue
		var template: Dictionary = {}
		if not template_pool.is_empty():
			template = Dictionary(template_pool[template_cursor % template_pool.size()]).duplicate(true)
		generated_nodes.append(_build_path_node(season_id, template, node_id, template_cursor))
		template_cursor += 1

	for node_id in range(generated_nodes.size()):
		var node: Dictionary = generated_nodes[node_id]
		var edges: Array[int] = []
		if node_id < boss_node_id:
			edges.append(node_id + 1)
		node["edges"] = edges
		generated_nodes[node_id] = node

	generated["name"] = "%s · 60格远征线" % String(seed_region.get("name", "长线区域"))
	generated["start_node_id"] = 0
	generated["boss_node_id"] = boss_node_id
	generated["revealed_nodes"] = _initial_revealed_nodes()
	generated["nodes"] = generated_nodes
	return generated

func _register_runtime_region(region: Dictionary) -> void:
	if region.is_empty():
		return
	var region_id := String(region.get("id", ""))
	var season_id := String(region.get("season_id", ""))
	if not region_id.is_empty():
		DataRepository.board_regions[region_id] = region.duplicate(true)
	if not season_id.is_empty():
		DataRepository.board_regions_by_season[season_id] = region.duplicate(true)
		var boss_rule: Dictionary = DataRepository.season_boss_rules_by_season.get(season_id, {}).duplicate(true)
		if not boss_rule.is_empty():
			boss_rule["node_id"] = int(region.get("boss_node_id", -1))
			DataRepository.season_boss_rules_by_season[season_id] = boss_rule

func _expand_seed_layout(region: Dictionary) -> Dictionary:
	if region.is_empty():
		return {}
	var expanded: Dictionary = region.duplicate(true)
	var season_id := String(expanded.get("season_id", ""))
	if not LEGACY_BUFFER_NODE_PRESETS.has(season_id):
		return expanded
	var existing_nodes: Array = expanded.get("nodes", [])
	var node_map := {}
	for raw_node in existing_nodes:
		var node: Dictionary = _normalize_node(raw_node)
		node_map[int(node.get("id", -1))] = node
	if node_map.has(14) or node_map.has(15):
		return expanded
	if node_map.has(0):
		node_map[0]["edges"] = [1, 2]
	if node_map.has(9):
		node_map[9]["edges"] = [8, 14]
	if node_map.has(10):
		node_map[10]["edges"] = [7, 15]
	if node_map.has(11):
		node_map[11]["edges"] = [14, 12]
		node_map[11]["position"] = Vector2(1320, 180)
	if node_map.has(12):
		node_map[12]["edges"] = [11, 13]
		node_map[12]["position"] = Vector2(1480, 300)
	if node_map.has(13):
		node_map[13]["edges"] = [15, 12]
		node_map[13]["position"] = Vector2(1320, 420)
	var preset: Dictionary = LEGACY_BUFFER_NODE_PRESETS[season_id]
	node_map[14] = Dictionary(preset.get(14, {})).duplicate(true)
	node_map[15] = Dictionary(preset.get(15, {})).duplicate(true)
	var ordered_nodes: Array = []
	for node_id in node_map.keys():
		ordered_nodes.append(int(node_id))
	ordered_nodes.sort()
	var final_nodes: Array = []
	for node_id in ordered_nodes:
		final_nodes.append(node_map.get(node_id, {}).duplicate(true))
	expanded["nodes"] = final_nodes
	return expanded

func _build_template_pool(seed_region: Dictionary, boss_seed_id: int) -> Array:
	var ordered_ids: Array[int] = []
	var seed_lookup := {}
	for raw_node in seed_region.get("nodes", []):
		var node: Dictionary = _normalize_node(raw_node)
		var node_id := int(node.get("id", -1))
		if node_id < 0:
			continue
		seed_lookup[node_id] = node
		ordered_ids.append(node_id)
	ordered_ids.sort()

	var templates: Array = []
	for node_id in ordered_ids:
		if node_id == 0 or node_id == boss_seed_id:
			continue
		var template: Dictionary = seed_lookup.get(node_id, {}).duplicate(true)
		if String(template.get("type", "")) == "camp":
			continue
		if String(template.get("habitat_id", "")).is_empty():
			continue
		templates.append(template)
	return templates

func _build_boss_template(seed_region: Dictionary) -> Dictionary:
	var boss_seed_id := int(seed_region.get("boss_node_id", -1))
	for raw_node in seed_region.get("nodes", []):
		var node: Dictionary = _normalize_node(raw_node)
		if int(node.get("id", -1)) == boss_seed_id:
			return node
	return {}

func _build_checkpoint_node(season_id: String, node_id: int) -> Dictionary:
	var checkpoint_index := int(node_id / CHECKPOINT_INTERVAL)
	var names: Array = CHECKPOINT_NAMES.get(season_id, CHECKPOINT_NAMES.get("spring", []))
	var label := "营地" if checkpoint_index <= 0 else String(names[min(checkpoint_index, names.size() - 1)])
	var description := "长线远征中的补给节点。路过这里会自动进入营地整备，用来重新收口队伍、驻守和留信节奏。"
	if node_id == 0:
		description = "长线远征的起点。这里是本赛季第一格，也承担整备、编成和路线规划。"
	return {
		"id": node_id,
		"name": label,
		"type": "camp",
		"description": description,
		"position": _position_for_node(node_id),
		"edges": [],
		"travel_cost": 0,
		"habitat_id": "",
		"focus": "补给 / 整备",
		"reward_hint": "路过这里会自动进入营地整备，不再需要靠侧边常驻按钮。",
	}

func _build_environment_node(season_id: String, template: Dictionary, node_id: int, template_cursor: int) -> Dictionary:
	var variants: Array = ENVIRONMENT_VARIANTS.get(season_id, ENVIRONMENT_VARIANTS.get("spring", []))
	var variant: Dictionary = {}
	if not variants.is_empty():
		variant = Dictionary(variants[(node_id + template_cursor) % variants.size()]).duplicate(true)
	var source_habitat_id := String(template.get("habitat_id", ""))
	var environment_name := String(variant.get("name", "沿途环境"))
	return {
		"id": node_id,
		"name": "%s · %02d" % [environment_name, node_id],
		"type": "environment",
		"description": "%s\n它不再是纯空地，而是长线推进里会发生沿途内容的环境段。" % String(variant.get("description", "这是一段会产生沿途内容的环境地貌。")),
		"position": _position_for_node(node_id),
		"edges": [],
		"travel_cost": 1,
		"habitat_id": "",
		"source_habitat_id": source_habitat_id,
		"environment_kind": String(variant.get("kind", "forage")),
		"focus": String(variant.get("focus", "行进 / 缓冲")),
		"reward_hint": String(variant.get("reward_hint", "这段环境会提供一次沿途内容，而不只是空走一格。")),
	}

func _build_path_node(season_id: String, template: Dictionary, node_id: int, template_cursor: int) -> Dictionary:
	var node: Dictionary = template.duplicate(true)
	node["id"] = node_id
	node["position"] = _position_for_node(node_id)
	var reward_hint := String(node.get("reward_hint", ""))
	if _should_be_event_node(node_id, template):
		node["type"] = "event"
		node["primary_content"] = "board_event"
		node["focus"] = "插曲 / 机遇"
		node["name"] = "%s · 事件格 %02d" % [_template_display_name(template), node_id]
		reward_hint = "落到这里会自动触发一段沿途插曲。"
	elif _should_be_empty_node(node_id):
		return _build_environment_node(season_id, template, node_id, template_cursor)
	else:
		node["name"] = "%s · %02d格" % [_template_display_name(template), node_id]
		if reward_hint.is_empty():
			reward_hint = "精确走满骰面后才会落到这一格。"
		else:
			reward_hint = "%s ｜ 这是长线推进中的第 %d 格。" % [reward_hint, node_id]
	node["reward_hint"] = reward_hint
	var description := String(node.get("description", "沿主干继续推进。"))
	node["description"] = "%s\n当前位于%s，用来把原本过短的赛季棋盘拉成长线推进。" % [
		description,
		_segment_name(node_id, template_cursor),
	]
	return node

func _build_boss_node(season_id: String, template: Dictionary, node_id: int) -> Dictionary:
	var node: Dictionary = template.duplicate(true)
	var boss_rule := DataRepository.get_season_boss_rule(season_id)
	if node.is_empty():
		node = {
			"type": "anomaly",
			"habitat_id": String(boss_rule.get("habitat_id", "")),
			"primary_content": "observe",
		}
	node["id"] = node_id
	node["position"] = _position_for_node(node_id)
	node["name"] = String(boss_rule.get("name", node.get("name", "赛季高潮")))
	node["description"] = String(boss_rule.get("description", node.get("description", "这是赛季长线地图的最终落点。")))
	node["reward_hint"] = "走到这里会直接触发赛季高潮奖励结算。"
	node["focus"] = "赛季高潮 / 验收"
	node["primary_content"] = "observe"
	if not String(boss_rule.get("habitat_id", "")).is_empty():
		node["habitat_id"] = String(boss_rule.get("habitat_id", ""))
	return node

func _template_display_name(template: Dictionary) -> String:
	var habitat_id := String(template.get("habitat_id", ""))
	if habitat_id.is_empty():
		return String(template.get("name", "未知节点"))
	return String(DataRepository.get_habitat(habitat_id).get("name", template.get("name", habitat_id)))

func _position_for_node(node_id: int) -> Vector2:
	var row := int(node_id / ROUTE_COLUMNS)
	var route_column := node_id % ROUTE_COLUMNS
	var column := route_column * VISUAL_COLUMN_STEP
	if row % 2 == 1:
		column = (ROUTE_COLUMNS - 1 - route_column) * VISUAL_COLUMN_STEP + 1
	var lane_offset := 32.0 if route_column % 2 == 1 else 0.0
	return GRID_ORIGIN + Vector2(float(column) * GRID_SPACING.x, float(row) * GRID_SPACING.y + lane_offset)

func _segment_name(node_id: int, template_cursor: int) -> String:
	var checkpoint_index := int(node_id / CHECKPOINT_INTERVAL)
	var segment_label := String(SEGMENT_NAMES[min(checkpoint_index, SEGMENT_NAMES.size() - 1)])
	return "%s第 %d 段" % [segment_label, template_cursor + 1]

func _initial_revealed_nodes() -> Array[int]:
	var revealed: Array[int] = []
	for node_id in range(mini(REGION_NODE_COUNT, 7)):
		revealed.append(node_id)
	return revealed

func _should_be_event_node(node_id: int, template: Dictionary) -> bool:
	if node_id <= 0 or _is_checkpoint(node_id) or node_id >= REGION_NODE_COUNT - 1:
		return false
	if node_id % 6 != 4:
		return false
	if String(template.get("type", "")) == "dojo":
		return false
	return not String(template.get("habitat_id", "")).is_empty()

func _should_be_empty_node(node_id: int) -> bool:
	if node_id <= 0 or _is_checkpoint(node_id) or node_id >= REGION_NODE_COUNT - 1:
		return false
	return node_id % 3 == 2

func _is_checkpoint(node_id: int) -> bool:
	if node_id == 0:
		return true
	return node_id % CHECKPOINT_INTERVAL == 0 and node_id < REGION_NODE_COUNT - 1

func _neighbors(node_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = node_lookup.get(node_id, {})
	for raw_neighbor in node.get("edges", []):
		neighbors.append(int(raw_neighbor))
	return neighbors

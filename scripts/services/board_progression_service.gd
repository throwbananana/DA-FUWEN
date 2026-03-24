class_name BoardProgressionService
extends RefCounted

const REGION_NAME_SUFFIX := "环阵扩张盘"
const MAX_GENERATED_RINGS := 8
const PREVIEW_RING_AHEAD := 1
const START_UNLOCKED_RING_COUNT := 1
const START_GENERATED_RING_COUNT := 2
const STARTER_RING_COUNT := 12
const RING_NODE_GROWTH := 4
const RING_GATE_COUNT := 4
const START_RADIUS := 210.0
const RING_RADIUS_STEP := 150.0
const ELLIPSE_Y_RATIO := 0.72
const BOARD_CENTER := Vector2(980.0, 520.0)
const REVEAL_GRAPH_RADIUS := 2
const SCOUT_LOOKAHEAD := 4
const SCOUT_REVEAL_RADIUS := 1
const GATE_REQUIREMENT_PATTERN := ["boss", "dojo"]

const CHECKPOINT_NAMES := {
	"spring": ["营地", "苔岔补给站", "雾林前哨"],
	"summer": ["营地", "雷潮补给站", "热浪前哨"],
	"autumn": ["营地", "赤叶补给站", "锻风前哨"],
	"winter": ["营地", "雪线补给站", "寒镜前哨"],
}

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
		{"name": "霜线雪凹", "kind": "forage", "focus": "采集 / 整备", "description": "雪线在这里压成了缓坡和雪凹，是环阵推进里少数能停下来整理物资的地方。", "reward_hint": "更容易带回冰湖与遗迹边缘的基础素材。"},
		{"name": "镜雪断脊", "kind": "scout", "focus": "侦察 / 望远", "description": "折光的雪脊能把远处路线照得很清楚，适合先判断今天值不值得继续深压。", "reward_hint": "会额外显露前方几格路线。"},
		{"name": "寒痕伏道", "kind": "wild_battle", "focus": "遭遇 / 伏击", "description": "雪地里全是新鲜拖痕，队伍经过时很容易把潜伏个体逼出来。", "reward_hint": "可能触发一次偏伏击型的野外遭遇。"},
	],
}

const BULLETIN_VARIANTS := {
	"spring": {
		"name": "边境公告板",
		"description": "巡路人会把本周野群出没和摊位折扣钉在这里，适合起手先看一眼。",
		"focus": "传闻 / 折扣",
		"reward_hint": "先看哪边会刷野群、哪边有折扣，再决定春季第一圈从哪边起手。",
	},
	"summer": {
		"name": "雷汐公告板",
		"description": "赶路人会把雷季野群动向和摊位折扣贴在这里，方便出发前先校准路线。",
		"focus": "动向 / 折扣",
		"reward_hint": "先看哪边有雷季野群和特价维修货，再决定练雷场还是补给线。",
	},
	"autumn": {
		"name": "锻路公告板",
		"description": "这块木板上会更新试炼补给和野群消息，方便你先排好这一圈的先后手。",
		"focus": "排期 / 折扣",
		"reward_hint": "先看哪边更容易遇见野群、哪档试炼补给在降价，再决定这圈先 build 还是先试炼。",
	},
	"winter": {
		"name": "霜线公告板",
		"description": "终局路上的巡线员会把本周野群动向和特价补给钉在这里，免得白白走冤枉路。",
		"focus": "线索 / 折扣",
		"reward_hint": "先看哪边野群更活跃、哪档终局补给在降价，再决定这一圈先稳态还是冲终局。",
	},
}

const MINIGAME_RING_OFFSETS := [4, 5]
const MINIGAME_VARIANTS := {
	"spring": [
		{
			"id": "moss_dash",
			"name": "苔径追跑垫",
			"description": "有人在软苔地上摆了几枚折返点，正好适合带伙伴活动一下脚步。",
			"focus": "小游戏 / 速度",
			"reward_hint": "做完会给下一场战斗留下一点速度热身。",
		},
		{
			"id": "warmup_nap",
			"name": "暖石打盹垫",
			"description": "暖石边围了一圈松苔垫，路过的人会顺手带伙伴做一轮短暂热身。",
			"focus": "小游戏 / 体力",
			"reward_hint": "做完会给下一场战斗留下一点体力热身。",
		},
	],
	"summer": [
		{
			"id": "thunder_steps",
			"name": "雷线折返场",
			"description": "雷痕步点被画成了短跑格，适合刚出营时先把节奏踩热。",
			"focus": "小游戏 / 速度",
			"reward_hint": "做完会给下一场战斗留下一点速度热身。",
		},
		{
			"id": "gear_pull",
			"name": "拉杆牵引架",
			"description": "旧牵引杆被改成了练力小游戏，正好给伙伴热一热发力感。",
			"focus": "小游戏 / 攻击",
			"reward_hint": "做完会给下一场战斗留下一点攻击热身。",
		},
	],
	"autumn": [
		{
			"id": "ring_toss",
			"name": "赤叶抛环台",
			"description": "干燥木环被垒成一摞，路过时总会有人顺手来一轮扑接练习。",
			"focus": "小游戏 / 攻击",
			"reward_hint": "做完会给下一场战斗留下一点攻击热身。",
		},
		{
			"id": "leaf_huddle",
			"name": "落叶埋身堆",
			"description": "叶堆被整理成一圈软垫，特别适合在试炼前让伙伴放松一下身体。",
			"focus": "小游戏 / 体力",
			"reward_hint": "做完会给下一场战斗留下一点体力热身。",
		},
	],
	"winter": [
		{
			"id": "ice_steps",
			"name": "霜点踏步灯",
			"description": "暖灯在雪地上点成了几段踏步线，正好给伙伴踩踩节奏。",
			"focus": "小游戏 / 速度",
			"reward_hint": "做完会给下一场战斗留下一点速度热身。",
		},
		{
			"id": "snow_roll",
			"name": "暖棚雪垫堆",
			"description": "软雪被堆成了翻身垫，路过的人总会带伙伴滚两圈再继续赶路。",
			"focus": "小游戏 / 体力",
			"reward_hint": "做完会给下一场战斗留下一点体力热身。",
		},
	],
}

const INFIRMARY_VARIANTS := {
	"spring": {
		"description": "巡路医和照料员把这里布置成了能随时接队伍休整的轻疗点。",
		"focus": "疗养 / 休整",
	},
	"summer": {
		"description": "高压季里总得留一处能先降温、包扎和重新整顿呼吸的疗养点。",
		"focus": "疗养 / 缓压",
	},
	"autumn": {
		"description": "演武路线上专门留了这一处疗养棚，方便把伤势和节奏都先稳下来。",
		"focus": "疗养 / 调整",
	},
	"winter": {
		"description": "寒线队伍会把这里当成暖棚疗养站，先把身体和装备一起回温。",
		"focus": "疗养 / 回温",
	},
}

const SPECIAL_LOOP_INFIRMARY_VARIANTS := {
	"sky_island": {
		"name": "空岛风栈疗养台",
		"description": "风栈上系着缓冲绳和热饮囊，是高空环带里专门留给失手队伍的安稳落脚点。",
	},
	"swamp": {
		"name": "沼泽浮栈疗养棚",
		"description": "浮栈边钉满了防陷木桩和药草包，正好能把陷泥后的队伍先托稳。",
	},
	"ocean": {
		"name": "海潮泊位疗养舱",
		"description": "涨潮线旁常备干燥布和热盐水，专门接应从外海路上退下来的队伍。",
	},
}

const TIME_NAMES := {
	"day": "白昼",
	"evening": "傍晚",
	"night": "夜晚",
}

const SPECIAL_RING_DEFS := {
	2: {
		"id": "sky_island",
		"name": "空岛环带",
		"gate_name": "空岛升流门",
		"gate_description": "更外侧已经抬升成一圈浮岛，只有掌握腾空翼并踩准白昼上升气流，才能把通路接起来。",
		"unlock_summary": "白昼升流已经把空岛环带接起来了。",
		"skill_id": "sky_glide",
		"dojo_id": "summer_storm_trial",
		"tier": "tier_1",
		"time_windows": ["day"],
		"source_habitat_id": "sky_post",
		"encounter_pool": [
			{"species_id": "iron_pigeon_2", "weight": 34, "mood": "diligent"},
			{"species_id": "storm_yak_2", "weight": 28, "mood": "steady"},
			{"species_id": "shale_ram_2", "weight": 22, "mood": "bold"},
			{"species_id": "spark_mouse_2", "weight": 16, "mood": "curious"},
		],
		"variants": [
			{
				"name": "云绳补给栈",
				"kind": "forage",
				"focus": "空岛 / 补给",
				"description": "几段云绳和浮木被绑成半空补给点，适合在高空路线里顺手收一轮材料。",
				"reward_hint": "更容易在高空补给点带回轻量素材。",
			},
			{
				"name": "断风观测脊",
				"kind": "scout",
				"focus": "空岛 / 侦察",
				"description": "断风脊会把外层路况压得很清楚，正适合在切进更高处前先看一眼。",
				"reward_hint": "会额外揭开前方一小段路线。",
			},
			{
				"name": "悬桥惊翼道",
				"kind": "wild_battle",
				"focus": "空岛 / 遭遇",
				"description": "悬桥边缘总有盘旋个体试探领空，路过时很容易直接起冲突。",
				"reward_hint": "可能触发一次高空野外遭遇。",
			},
		],
	},
	4: {
		"id": "swamp",
		"name": "沼泽环带",
		"gate_name": "沼泽浮栈门",
		"gate_description": "更外侧是一整圈软泥和浮栈，得先学会涉泽步并完成赤叶演武场的一阶验证，才不会在入口就陷进去。",
		"unlock_summary": "涉泽步已经稳住了沼泽环带的浮栈。",
		"skill_id": "bog_stride",
		"dojo_id": "autumn_leaf_dojo",
		"tier": "tier_1",
		"time_windows": [],
		"source_habitat_id": "reed_mire",
		"encounter_pool": [
			{"species_id": "echo_snail_2", "weight": 30, "mood": "slow"},
			{"species_id": "marsh_slime_2", "weight": 28, "mood": "hungry"},
			{"species_id": "steam_otter_2", "weight": 24, "mood": "playful"},
			{"species_id": "crystal_shrimp_2", "weight": 18, "mood": "alert"},
		],
		"variants": [
			{
				"name": "苇泥采集塘",
				"kind": "forage",
				"focus": "沼泽 / 采集",
				"description": "浮苇和软泥把这段外环压成了采集塘，适合停一下摸清还能带走什么。",
				"reward_hint": "更容易带回湿地素材与纤维。",
			},
			{
				"name": "沉木探路口",
				"kind": "scout",
				"focus": "沼泽 / 探路",
				"description": "沉木被踩出几条窄道，正适合先看哪边的泥面还能继续压。",
				"reward_hint": "会多显露几格沼泽里的安全路。",
			},
			{
				"name": "黑泽伏行带",
				"kind": "wild_battle",
				"focus": "沼泽 / 遭遇",
				"description": "这里的泥面总会突然炸开，说明附近潜着不想被惊动的个体。",
				"reward_hint": "可能直接引出一次伏击型遭遇。",
			},
		],
	},
	6: {
		"id": "ocean",
		"name": "海洋环带",
		"gate_name": "海潮外闸",
		"gate_description": "更外层会在傍晚到夜晚涨潮成整圈海路，必须先学会踏潮鳍，并完成更高一阶的演武验证，潮门才会接通。",
		"unlock_summary": "涨潮已经把海洋环带推到了脚下。",
		"skill_id": "tide_surf",
		"dojo_id": "autumn_leaf_dojo",
		"tier": "tier_2",
		"time_windows": ["evening", "night"],
		"source_habitat_id": "saltglass_coast",
		"encounter_pool": [
			{"species_id": "cloud_crane_2", "weight": 30, "mood": "calm"},
			{"species_id": "crystal_shrimp_2", "weight": 26, "mood": "alert"},
			{"species_id": "ice_seal_2", "weight": 22, "mood": "placid"},
			{"species_id": "volt_carp_2", "weight": 22, "mood": "rash"},
		],
		"variants": [
			{
				"name": "潮脊拾贝线",
				"kind": "forage",
				"focus": "海洋 / 采集",
				"description": "涨潮把外海碎贝和轻浮补给推成一条细线，正好能顺手捞一轮。",
				"reward_hint": "更容易带回海边素材和玻璃碎料。",
			},
			{
				"name": "外潮观测桩",
				"kind": "scout",
				"focus": "海洋 / 观势",
				"description": "潮位标桩会把后段浪线暴露得很清楚，适合先判断这圈要不要继续深压。",
				"reward_hint": "会额外显露一段潮路信息。",
			},
			{
				"name": "夜潮冲击槽",
				"kind": "wild_battle",
				"focus": "海洋 / 遭遇",
				"description": "夜潮一上来，这段外海就会有游弋个体贴着浪头冲线。",
				"reward_hint": "可能爆发一次海路遭遇战。",
			},
		],
	},
}

var current_region: Dictionary = {}
var node_lookup: Dictionary = {}
var _seed_regions_by_season: Dictionary = {}
var _ring_node_ids: Array = []
var _ring_gate_nodes: Dictionary = {}
var _current_progress: Dictionary = {}
var _current_season_id := ""
var _placed_settlement_infirmaries: Dictionary = {}
var _placed_special_loop_infirmaries: Dictionary = {}

func set_region_for_season(season_id: String) -> void:
	_current_season_id = season_id
	var seed_region := _seed_region_for_season(season_id)
	_current_progress = _ensure_loop_progress(season_id)
	current_region = _build_generated_region(seed_region, _current_progress)
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
	return Dictionary(node_lookup.get(node_id, {})).duplicate(true)

func find_best_infirmary_node(from_node_id: int) -> Dictionary:
	var candidates: Array = []
	for raw_node in current_region.get("nodes", []):
		var node := _normalize_node(raw_node)
		if String(node.get("type", "")) != "infirmary":
			continue
		var node_id := int(node.get("id", -1))
		if node_id < 0 or is_node_locked(node_id):
			continue
		candidates.append(node)
	if candidates.is_empty():
		return {}
	if from_node_id == -1:
		return Dictionary(candidates[0]).duplicate(true)

	var from_node := get_node(from_node_id)
	var preferred_habitat_id := String(from_node.get("habitat_id", ""))
	var preferred_loop_id := String(from_node.get("special_loop_id", ""))
	var best_score := INF
	var best_node: Dictionary = Dictionary(candidates[0]).duplicate(true)
	for raw_candidate in candidates:
		var candidate: Dictionary = Dictionary(raw_candidate).duplicate(true)
		var candidate_id := int(candidate.get("id", -1))
		var score := 0.0
		if not preferred_loop_id.is_empty():
			if String(candidate.get("special_loop_id", "")) == preferred_loop_id:
				score -= 600.0
			elif not String(candidate.get("special_loop_id", "")).is_empty():
				score += 120.0
		if not preferred_habitat_id.is_empty() and String(candidate.get("linked_habitat_id", "")) == preferred_habitat_id:
			score -= 260.0
		var path := get_shortest_path(from_node_id, candidate_id)
		var distance := 9999
		if not path.is_empty():
			distance = maxi(path.size() - 1, 0)
		score += float(distance)
		if score < best_score:
			best_score = score
			best_node = candidate
	return best_node

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
			if is_node_locked(neighbor_id):
				continue
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
	if is_node_locked(to_node_id):
		return []
	var frontier: Array[int] = [from_node_id]
	var parents := {from_node_id: -1}
	while not frontier.is_empty():
		var current_id := int(frontier.pop_front())
		for neighbor_id in _neighbors(current_id):
			if is_node_locked(neighbor_id):
				continue
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

func get_next_route_options(current_node_id: int, steps_remaining: int, visited_nodes: Array) -> Array[int]:
	var options: Array[int] = []
	if current_node_id == -1 or steps_remaining <= 0:
		return options

	var visited := {}
	for raw_node_id in visited_nodes:
		visited[int(raw_node_id)] = true
	if not visited.has(current_node_id):
		visited[current_node_id] = true

	for neighbor_id in _neighbors(current_node_id):
		if is_node_locked(neighbor_id):
			continue
		if visited.has(neighbor_id):
			continue

		visited[neighbor_id] = true
		if _can_finish_route_from(neighbor_id, steps_remaining - 1, visited):
			options.append(neighbor_id)
		visited.erase(neighbor_id)

	options.sort()
	return options

func _can_finish_route_from(node_id: int, steps_remaining: int, visited: Dictionary) -> bool:
	if steps_remaining <= 0:
		return true

	for neighbor_id in _neighbors(node_id):
		if is_node_locked(neighbor_id):
			continue
		if visited.has(neighbor_id):
			continue

		visited[neighbor_id] = true
		if _can_finish_route_from(neighbor_id, steps_remaining - 1, visited):
			visited.erase(neighbor_id)
			return true
		visited.erase(neighbor_id)

	return false

func expand_reveal_from(node_id: int, radius: int = REVEAL_GRAPH_RADIUS) -> Array[int]:
	if node_id == -1:
		return []
	return _collect_graph_nodes(node_id, maxi(0, radius), true)

func build_scout_reveal(from_node_id: int, max_steps: int = SCOUT_LOOKAHEAD, local_radius: int = SCOUT_REVEAL_RADIUS) -> Array[int]:
	if from_node_id == -1:
		return []
	var revealed := {}
	for node_id in _collect_forward_nodes(from_node_id, maxi(0, max_steps)):
		revealed[node_id] = true
		for nearby_id in _collect_graph_nodes(node_id, maxi(0, local_radius), true):
			revealed[nearby_id] = true
	return _sorted_node_keys(revealed)

func is_node_locked(node_id: int) -> bool:
	return bool(node_lookup.get(node_id, {}).get("ring_locked", false))

func get_node_lock_reason(node_id: int) -> String:
	return String(node_lookup.get(node_id, {}).get("lock_reason", ""))

func is_unlock_gate_node(node_id: int) -> bool:
	return bool(node_lookup.get(node_id, {}).get("unlock_gate", false))

func try_resolve_unlock_gate(node_id: int) -> Dictionary:
	var node: Dictionary = node_lookup.get(node_id, {})
	if not bool(node.get("unlock_gate", false)):
		return {}
	var requirement: Dictionary = node.get("unlock_requirement", {}).duplicate(true)
	var target_ring := int(node.get("unlock_target_ring", -1))
	if target_ring < 0:
		return {}
	var kind := String(requirement.get("kind", "boss"))
	if kind == "boss":
		return _unlock_next_ring(target_ring, "击败了 %s。" % String(node.get("name", "路口领主")))
	var evaluation := _evaluate_gate_requirement(requirement)
	if bool(evaluation.get("ok", false)):
		return _unlock_next_ring(target_ring, String(evaluation.get("summary", "外环条件已经满足。")))
	if String(evaluation.get("awaiting", "")) == "dojo":
		var progress := _ensure_loop_progress(_current_season_id)
		progress["pending_dojo_ring"] = target_ring
		GameState.set_board_loop_progress(progress, _current_season_id)
		_current_progress = progress.duplicate(true)
	return {
		"ok": false,
		"awaiting": String(evaluation.get("awaiting", "")),
		"message": String(evaluation.get("message", requirement.get("blocked_text", "还需要先满足外环条件。"))),
		"revealed_nodes": [],
	}

func try_unlock_outer_ring_from_dojo(dojo_id: String, tier: String) -> Dictionary:
	var progress := _ensure_loop_progress(_current_season_id)
	var target_ring := int(progress.get("pending_dojo_ring", -1))
	if target_ring < 0:
		return {}
	var requirement := _unlock_requirement_for_ring(target_ring - 1, _current_season_id)
	var kind := String(requirement.get("kind", ""))
	if kind != "dojo" and kind != "special":
		return {}
	if String(requirement.get("tier", "tier_1")) != tier:
		return {}
	var expected_dojo_id := String(requirement.get("dojo_id", ""))
	if not expected_dojo_id.is_empty() and expected_dojo_id != dojo_id:
		return {}
	var evaluation := _evaluate_gate_requirement(requirement)
	if not bool(evaluation.get("ok", false)):
		return {
			"ok": false,
			"awaiting": String(evaluation.get("awaiting", "")),
			"message": String(evaluation.get("message", requirement.get("blocked_text", "还需要先满足外环条件。"))),
		}
	return _unlock_next_ring(target_ring, String(evaluation.get("summary", "外环条件已经满足。")))

func get_active_gate_text(node_id: int) -> String:
	var node: Dictionary = node_lookup.get(node_id, {})
	if not bool(node.get("unlock_gate", false)):
		return ""
	var requirement: Dictionary = node.get("unlock_requirement", {}).duplicate(true)
	if String(requirement.get("kind", "boss")) == "boss":
		return "击败此路口领主后，会打开下一圈外环。"
	return String(requirement.get("blocked_text", "需要满足当前外环条件后，下一圈才会解锁。"))

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
		normalized["position"] = Vector2(float(raw_position.get("x", 0.0)), float(raw_position.get("y", 0.0)))
	return normalized

func _seed_region_for_season(season_id: String) -> Dictionary:
	if _seed_regions_by_season.has(season_id):
		return Dictionary(_seed_regions_by_season[season_id]).duplicate(true)
	var raw_region := DataRepository.get_board_region_for_season(season_id)
	_seed_regions_by_season[season_id] = raw_region.duplicate(true)
	return Dictionary(raw_region).duplicate(true)

func _ensure_loop_progress(season_id: String) -> Dictionary:
	var progress: Dictionary = GameState.get_board_loop_progress(season_id)
	if progress.is_empty():
		progress = {
			"unlocked_ring_count": START_UNLOCKED_RING_COUNT,
			"generated_ring_count": START_GENERATED_RING_COUNT,
			"pending_dojo_ring": -1,
		}
	progress["unlocked_ring_count"] = clampi(int(progress.get("unlocked_ring_count", START_UNLOCKED_RING_COUNT)), 1, MAX_GENERATED_RINGS)
	var minimum_generated := mini(MAX_GENERATED_RINGS, int(progress.get("unlocked_ring_count", START_UNLOCKED_RING_COUNT)) + PREVIEW_RING_AHEAD)
	progress["generated_ring_count"] = clampi(int(progress.get("generated_ring_count", START_GENERATED_RING_COUNT)), minimum_generated, MAX_GENERATED_RINGS)
	progress["pending_dojo_ring"] = int(progress.get("pending_dojo_ring", -1))
	GameState.set_board_loop_progress(progress, season_id)
	return progress

func _unlock_next_ring(target_ring: int, summary: String) -> Dictionary:
	var progress := _ensure_loop_progress(_current_season_id)
	var unlocked_ring_count := int(progress.get("unlocked_ring_count", START_UNLOCKED_RING_COUNT))
	if target_ring >= MAX_GENERATED_RINGS or target_ring < unlocked_ring_count:
		return {}
	progress["unlocked_ring_count"] = target_ring + 1
	progress["generated_ring_count"] = mini(MAX_GENERATED_RINGS, int(progress.get("unlocked_ring_count", 1)) + PREVIEW_RING_AHEAD)
	progress["pending_dojo_ring"] = -1
	GameState.set_board_loop_progress(progress, _current_season_id)
	_current_progress = progress.duplicate(true)
	var seed_region := _seed_region_for_season(_current_season_id)
	current_region = _build_generated_region(seed_region, progress)
	_register_runtime_region(current_region)
	_rebuild_lookup()
	var revealed_nodes := _unlock_reveal_nodes(target_ring)
	return {
		"ok": true,
		"message": "%s 新的外环已经展开。" % summary,
		"revealed_nodes": revealed_nodes,
		"target_ring": target_ring,
	}

func _build_generated_region(seed_region: Dictionary, progress: Dictionary) -> Dictionary:
	var generated: Dictionary = seed_region.duplicate(true)
	var season_id := String(seed_region.get("season_id", _current_season_id))
	var template_pool := _build_template_pool(seed_region, int(seed_region.get("boss_node_id", -1)))
	var boss_template := _build_boss_template(seed_region)
	_placed_settlement_infirmaries.clear()
	_placed_special_loop_infirmaries.clear()
	_ring_node_ids.clear()
	_ring_gate_nodes.clear()
	var nodes: Array = []
	var next_id := 0
	var ring_count := int(progress.get("generated_ring_count", START_GENERATED_RING_COUNT))
	var unlocked_ring_count := int(progress.get("unlocked_ring_count", START_UNLOCKED_RING_COUNT))
	var template_cursor := 0
	var center_node := _build_center_camp_node(season_id, next_id)
	nodes.append(center_node)
	next_id += 1
	for ring_index in range(ring_count):
		var count := STARTER_RING_COUNT + ring_index * RING_NODE_GROWTH
		var ring_ids: Array[int] = []
		for _offset in range(count):
			ring_ids.append(next_id)
			next_id += 1
		_ring_node_ids.append(ring_ids)
	var active_boss_gate_id := -1
	for ring_index in range(ring_count):
		var ring_ids: Array = _ring_node_ids[ring_index]
		var locked := ring_index >= unlocked_ring_count
		var lock_reason := _ring_lock_reason(ring_index, season_id)
		var gate_offset := _gate_offset_for_ring(ring_ids.size())
		var entrance_offset := 0
		for offset in range(ring_ids.size()):
			var node_id: int = int(ring_ids[offset])
			var node: Dictionary
			if offset == entrance_offset and ring_index == 0:
				node = _build_entry_node(season_id, node_id)
			elif ring_index < MAX_GENERATED_RINGS - 1 and offset == gate_offset:
				var gate_requirement := _unlock_requirement_for_ring(ring_index, season_id)
				node = _build_gate_node(season_id, boss_template, node_id, ring_index, gate_requirement)
				_ring_gate_nodes[ring_index] = node_id
				if ring_index == unlocked_ring_count - 1 and String(gate_requirement.get("kind", "boss")) == "boss":
					active_boss_gate_id = node_id
			else:
				var template: Dictionary = {}
				if not template_pool.is_empty():
					template = Dictionary(template_pool[template_cursor % template_pool.size()]).duplicate(true)
				template_cursor += 1
				node = _build_ring_content_node(season_id, template, node_id, ring_index, offset)
			node["ring_index"] = ring_index
			node["position"] = _ring_position(ring_index, offset, ring_ids.size())
			node["ring_locked"] = locked
			node["lock_reason"] = lock_reason if locked else ""
			node["edges"] = []
			nodes.append(node)
	_connect_layout(nodes, ring_count)
	generated["id"] = "%s_loop" % season_id
	generated["name"] = "%s · %s" % [String(seed_region.get("name", "未命名区域")), REGION_NAME_SUFFIX]
	generated["start_node_id"] = 0
	generated["boss_node_id"] = active_boss_gate_id
	generated["revealed_nodes"] = _initial_revealed_nodes(nodes, unlocked_ring_count)
	generated["nodes"] = nodes
	generated["loop_progress"] = progress.duplicate(true)
	return generated

func _build_center_camp_node(season_id: String, node_id: int) -> Dictionary:
	var names: Array = CHECKPOINT_NAMES.get(season_id, CHECKPOINT_NAMES.get("spring", []))
	return {
		"id": node_id,
		"name": String(names[0]) if not names.is_empty() else "营地",
		"type": "camp",
		"description": "环阵自动生成的中心营地。所有外环都从这里向外展开。",
		"travel_cost": 0,
		"focus": "整备 / 起点",
		"reward_hint": "在这里重整队伍，再决定切向哪一圈。",
	}

func _build_entry_node(season_id: String, node_id: int) -> Dictionary:
	return {
		"id": node_id,
		"name": "%s前环入口" % String(CHECKPOINT_NAMES.get(season_id, CHECKPOINT_NAMES.get("spring", ["营地"]))[0]),
		"type": "camp",
		"description": "这是第一圈与中心营地衔接的入口，适合重新判断今天是继续压外圈还是回内圈整备。",
		"travel_cost": 0,
		"focus": "入口 / 调整",
		"reward_hint": "这里能稳定承接中心营地与第一圈的路线。",
	}

func _build_gate_node(season_id: String, boss_template: Dictionary, node_id: int, ring_index: int, requirement: Dictionary) -> Dictionary:
	var kind := String(requirement.get("kind", "boss"))
	if kind == "boss":
		var node: Dictionary = boss_template.duplicate(true)
		node["id"] = node_id
		node["name"] = String(requirement.get("label", "路口领主"))
		node["type"] = "anomaly"
		node["description"] = "这里是第 %d 圈的路口封门点。只要压过这里，下一圈外环就会展开。" % (ring_index + 1)
		node["travel_cost"] = 1
		node["focus"] = "路口 Boss / 开环"
		node["reward_hint"] = "击破后会立即生成并显露更外侧的一圈。"
		node["unlock_gate"] = true
		node["unlock_requirement"] = requirement.duplicate(true)
		node["unlock_target_ring"] = ring_index + 1
		return node
	var special_loop_name := String(requirement.get("ring_name", ""))
	var focus_label := "道馆验证 / 开环"
	if kind == "special" and not special_loop_name.is_empty():
		focus_label = "%s / 开环" % special_loop_name
	return {
		"id": node_id,
		"name": String(requirement.get("gate_name", requirement.get("label", "道馆门"))),
		"type": "event",
		"description": String(requirement.get("gate_description", "这里通向更外侧的环路，但需要先通过当前层要求的道馆验证。")),
		"travel_cost": 1,
		"focus": focus_label,
		"reward_hint": String(requirement.get("blocked_text", "需要先通过当前道馆。")),
		"special_loop_id": String(requirement.get("ring_id", "")),
		"special_loop_name": special_loop_name,
		"unlock_gate": true,
		"unlock_requirement": requirement.duplicate(true),
		"unlock_target_ring": ring_index + 1,
	}

func _build_ring_content_node(season_id: String, template: Dictionary, node_id: int, ring_index: int, offset: int) -> Dictionary:
	if ring_index == 0 and offset == 1:
		return _build_bulletin_node(season_id, node_id, ring_index)
	if ring_index == 0:
		var minigame_variant_index := MINIGAME_RING_OFFSETS.find(offset)
		if minigame_variant_index != -1:
			return _build_minigame_node(season_id, node_id, ring_index, minigame_variant_index)
	var special_ring := _special_ring_for_index(ring_index)
	if not special_ring.is_empty():
		if not _placed_special_loop_infirmaries.has(String(special_ring.get("id", ""))) and offset == 1:
			return _build_special_infirmary_node(node_id, ring_index, special_ring)
		return _build_special_ring_node(node_id, ring_index, offset, special_ring)
	if _should_place_settlement_infirmary(template):
		return _build_settlement_infirmary_node(season_id, template, node_id, ring_index)
	if (offset + ring_index) % 5 == 2:
		return _build_environment_node(season_id, template, node_id, ring_index)
	if (offset + ring_index) % 7 == 4 and not template.is_empty() and String(template.get("type", "")) != "dojo":
		return _build_event_node(template, node_id, ring_index)
	return _build_path_node(template, node_id, ring_index)

func _build_bulletin_node(season_id: String, node_id: int, ring_index: int) -> Dictionary:
	var variant: Dictionary = Dictionary(BULLETIN_VARIANTS.get(season_id, BULLETIN_VARIANTS.get("spring", {}))).duplicate(true)
	return {
		"id": node_id,
		"name": String(variant.get("name", "公告板")),
		"type": "bulletin",
		"description": "%s\n它是第 %d 圈最适合先停一下看消息的路线节点。" % [
			String(variant.get("description", "路牌上贴着最近整理过的野群动向和集市折扣。")),
			ring_index + 1,
		],
		"travel_cost": 1,
		"habitat_id": "",
		"focus": String(variant.get("focus", "传闻 / 折扣")),
		"reward_hint": String(variant.get("reward_hint", "先看看本周哪些地方会出野群、哪些货在降价，再决定路线。")),
	}

func _build_minigame_node(season_id: String, node_id: int, ring_index: int, variant_index: int) -> Dictionary:
	var season_variants: Array = Array(MINIGAME_VARIANTS.get(season_id, MINIGAME_VARIANTS.get("spring", []))).duplicate(true)
	var variant: Dictionary = {}
	if variant_index >= 0 and variant_index < season_variants.size():
		variant = Dictionary(season_variants[variant_index]).duplicate(true)
	elif not season_variants.is_empty():
		variant = Dictionary(season_variants[0]).duplicate(true)
	return {
		"id": node_id,
		"name": String(variant.get("name", "小游戏地块")),
		"type": "minigame",
		"description": "%s\n它是第 %d 圈开局就能用来热身的小游戏节点。" % [
			String(variant.get("description", "这里正好能带伙伴做个短促小游戏，给下一场战斗留一点状态。")),
			ring_index + 1,
		],
		"travel_cost": 1,
		"habitat_id": "",
		"focus": String(variant.get("focus", "小游戏 / 热身")),
		"reward_hint": String(variant.get("reward_hint", "做完会给下一场战斗留下一点小幅属性热身。")),
		"minigame_id": String(variant.get("id", "")),
	}

func _should_place_settlement_infirmary(template: Dictionary) -> bool:
	var habitat_id := String(template.get("habitat_id", ""))
	if habitat_id.is_empty() or _placed_settlement_infirmaries.has(habitat_id):
		return false
	return String(DataRepository.get_habitat(habitat_id).get("type", "")) == "settlement"

func _build_settlement_infirmary_node(season_id: String, template: Dictionary, node_id: int, ring_index: int) -> Dictionary:
	var habitat_id := String(template.get("habitat_id", ""))
	_placed_settlement_infirmaries[habitat_id] = true
	var habitat := DataRepository.get_habitat(habitat_id)
	var linked_name := String(habitat.get("name", _template_display_name(template)))
	var variant: Dictionary = Dictionary(INFIRMARY_VARIANTS.get(season_id, INFIRMARY_VARIANTS.get("spring", {}))).duplicate(true)
	return {
		"id": node_id,
		"name": "%s疗养所" % linked_name,
		"type": "infirmary",
		"description": "%s\n这是第 %d 圈里专门给 %s 配套的疗养点，失手队伍会先被送到这里收口。" % [
			String(variant.get("description", "这里有人专门照看从外环退下来的队伍。")),
			ring_index + 1,
			linked_name,
		],
		"travel_cost": 1,
		"habitat_id": "",
		"focus": String(variant.get("focus", "疗养 / 休整")),
		"reward_hint": "主动疗养免费；战败后被送来会扣一笔疗养费。",
		"linked_habitat_id": habitat_id,
		"linked_habitat_name": linked_name,
	}

func _build_special_infirmary_node(node_id: int, ring_index: int, special_ring: Dictionary) -> Dictionary:
	var loop_id := String(special_ring.get("id", ""))
	_placed_special_loop_infirmaries[loop_id] = true
	var ring_name := String(special_ring.get("name", "特殊环带"))
	var variant: Dictionary = Dictionary(SPECIAL_LOOP_INFIRMARY_VARIANTS.get(loop_id, {})).duplicate(true)
	return {
		"id": node_id,
		"name": String(variant.get("name", "%s疗养站" % ring_name)),
		"type": "infirmary",
		"description": "%s\n这是第 %d 圈%s至少配套的一处疗养点，整圈失手后的队伍都会先往这里回收。" % [
			String(variant.get("description", "这里专门接应从特殊外环退下来的队伍。")),
			ring_index + 1,
			ring_name,
		],
		"travel_cost": 1,
		"habitat_id": "",
		"focus": "疗养 / %s" % ring_name,
		"reward_hint": "主动疗养免费；在这圈战败后自动送医会扣一笔疗养费。",
		"special_loop_id": loop_id,
		"special_loop_name": ring_name,
	}

func _build_special_ring_node(node_id: int, ring_index: int, offset: int, special_ring: Dictionary) -> Dictionary:
	var variants: Array = Array(special_ring.get("variants", [])).duplicate(true)
	var variant: Dictionary = {}
	if not variants.is_empty():
		variant = Dictionary(variants[(offset + ring_index) % variants.size()]).duplicate(true)
	var ring_name := String(special_ring.get("name", "特殊环带"))
	var encounter_pool: Array = Array(special_ring.get("encounter_pool", [])).duplicate(true)
	var encounter_hint := _special_encounter_hint(encounter_pool)
	var reward_hint := String(variant.get("reward_hint", "这圈会提供一整段特殊地貌收益。"))
	if String(variant.get("kind", "")) == "wild_battle" and not encounter_hint.is_empty():
		reward_hint += " 常见个体：%s。" % encounter_hint
	return {
		"id": node_id,
		"name": "%s · %02d" % [String(variant.get("name", ring_name)), node_id],
		"type": "environment",
		"description": "%s\n这里已经切入第 %d 圈的%s，整圈地块都会按这套特殊地形运转。" % [
			String(variant.get("description", "这段外环已经被特殊地形整体接管。")),
			ring_index + 1,
			ring_name,
		],
		"travel_cost": 1,
		"habitat_id": "",
		"environment_kind": String(variant.get("kind", "forage")),
		"focus": String(variant.get("focus", ring_name)),
		"reward_hint": reward_hint,
		"source_habitat_id": String(special_ring.get("source_habitat_id", "")),
		"special_loop_id": String(special_ring.get("id", "")),
		"special_loop_name": ring_name,
		"special_encounter_pool": encounter_pool,
		"special_encounter_hint": encounter_hint,
	}

func _build_environment_node(season_id: String, template: Dictionary, node_id: int, ring_index: int) -> Dictionary:
	var variants: Array = ENVIRONMENT_VARIANTS.get(season_id, ENVIRONMENT_VARIANTS.get("spring", []))
	var variant: Dictionary = {}
	if not variants.is_empty():
		variant = Dictionary(variants[(node_id + ring_index) % variants.size()]).duplicate(true)
	return {
		"id": node_id,
		"name": "%s · %02d" % [String(variant.get("name", "沿途环境")), node_id],
		"type": "environment",
		"description": "%s\n它属于自动扩张的第 %d 圈环境段。" % [String(variant.get("description", "这是一段会产生沿途内容的环境地貌。")), ring_index + 1],
		"travel_cost": 1,
		"habitat_id": "",
		"environment_kind": String(variant.get("kind", "forage")),
		"focus": String(variant.get("focus", "行进 / 缓冲")),
		"reward_hint": String(variant.get("reward_hint", "这段环境会提供一次沿途内容，而不只是空走一格。")),
		"source_habitat_id": String(template.get("habitat_id", "")),
	}

func _build_event_node(template: Dictionary, node_id: int, ring_index: int) -> Dictionary:
	var node: Dictionary = template.duplicate(true)
	node["id"] = node_id
	node["type"] = "event"
	node["primary_content"] = "board_event"
	node["name"] = "%s · 插曲格 %02d" % [_template_display_name(template), node_id]
	node["description"] = "%s\n当前位于第 %d 圈的插曲位，会在环阵上制造节奏变化。" % [String(template.get("description", "沿主干继续推进。")), ring_index + 1]
	node["focus"] = "插曲 / 机遇"
	node["reward_hint"] = "落到这里会自动触发一段沿途插曲。"
	return node

func _build_path_node(template: Dictionary, node_id: int, ring_index: int) -> Dictionary:
	var node: Dictionary = template.duplicate(true)
	if node.is_empty():
		node = {
			"type": "habitat",
			"name": "外环节点",
			"description": "自动生成的环阵节点。",
			"travel_cost": 1,
			"habitat_id": "",
		}
	node["id"] = node_id
	node["name"] = "%s · %02d格" % [_template_display_name(template), node_id]
	node["description"] = "%s\n当前位于自动生成的第 %d 圈，可以继续沿环前压，或在路口切向更外层。" % [String(node.get("description", "沿主干继续推进。")), ring_index + 1]
	node["focus"] = String(node.get("focus", "推进 / 观察"))
	node["reward_hint"] = "精确走满骰面后才会落到这一格。"
	return node

func _connect_layout(nodes: Array, ring_count: int) -> void:
	var node_map := {}
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		node_map[int(node.get("id", -1))] = index
	for ring_index in range(ring_count):
		var ring_ids: Array = _ring_node_ids[ring_index]
		for offset in range(ring_ids.size()):
			var current_id: int = int(ring_ids[offset])
			var next_id: int = int(ring_ids[(offset + 1) % ring_ids.size()])
			var prev_id: int = int(ring_ids[(offset - 1 + ring_ids.size()) % ring_ids.size()])
			_append_edge_to_nodes(nodes, node_map, current_id, next_id)
			_append_edge_to_nodes(nodes, node_map, current_id, prev_id)
		if ring_index == 0 and not ring_ids.is_empty():
			_append_edge_to_nodes(nodes, node_map, 0, ring_ids[0])
			_append_edge_to_nodes(nodes, node_map, ring_ids[0], 0)
	for ring_index in range(ring_count - 1):
		var inner_ids: Array = _ring_node_ids[ring_index]
		var outer_ids: Array = _ring_node_ids[ring_index + 1]
		for slot in range(RING_GATE_COUNT):
			var ratio := float(slot) / float(RING_GATE_COUNT)
			var inner_index := int(round(ratio * float(inner_ids.size() - 1)))
			var outer_index := int(round(ratio * float(outer_ids.size() - 1)))
			var inner_id: int = int(inner_ids[clampi(inner_index, 0, inner_ids.size() - 1)])
			var outer_id: int = int(outer_ids[clampi(outer_index, 0, outer_ids.size() - 1)])
			_append_edge_to_nodes(nodes, node_map, inner_id, outer_id)
			_append_edge_to_nodes(nodes, node_map, outer_id, inner_id)

func _append_edge_to_nodes(nodes: Array, node_map: Dictionary, from_node_id: int, to_node_id: int) -> void:
	if not node_map.has(from_node_id):
		return
	var index := int(node_map[from_node_id])
	var node: Dictionary = nodes[index]
	var edges: Array[int] = []
	for existing_id in node.get("edges", []):
		edges.append(int(existing_id))
	if not edges.has(to_node_id):
		edges.append(to_node_id)
	node["edges"] = edges
	nodes[index] = node

func _ring_position(ring_index: int, offset: int, count: int) -> Vector2:
	var radius_x := START_RADIUS + float(ring_index) * RING_RADIUS_STEP
	var radius_y := radius_x * ELLIPSE_Y_RATIO
	var angle := -PI * 0.5 + TAU * (float(offset) / maxf(float(count), 1.0))
	return BOARD_CENTER + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)

func _gate_offset_for_ring(count: int) -> int:
	return maxi(1, int(floor(float(count) * 0.25)))

func _unlock_requirement_for_ring(ring_index: int, season_id: String) -> Dictionary:
	var special_requirement := _special_requirement_for_target_ring(ring_index + 1)
	if not special_requirement.is_empty():
		return special_requirement
	var kind: String = String(GATE_REQUIREMENT_PATTERN[ring_index % GATE_REQUIREMENT_PATTERN.size()])
	if kind == "boss":
		return {
			"kind": "boss",
			"label": _boss_gate_name(season_id, ring_index),
		}
	var dojo_ids: Array = GameState.get_current_dojo_rotation()
	if dojo_ids.is_empty():
		return {
			"kind": "boss",
			"label": _boss_gate_name(season_id, ring_index),
		}
	var dojo_id := String(dojo_ids[ring_index % dojo_ids.size()])
	var dojo_name := dojo_id
	if not dojo_id.is_empty():
		dojo_name = String(DataRepository.get_dojo(dojo_id).get("name", dojo_id))
	return {
		"kind": "dojo",
		"dojo_id": dojo_id,
		"tier": "tier_1",
		"label": "%s一阶试炼" % dojo_name if not dojo_name.is_empty() else "当前道馆一阶试炼",
		"blocked_text": "需要先通过 %s，下一圈外环才会解锁。" % ("%s的一阶试炼" % dojo_name if not dojo_name.is_empty() else "当前道馆的一阶试炼"),
		"summary": "通过了 %s。" % String(dojo_name if not dojo_name.is_empty() else "当前道馆"),
	}

func _ring_lock_reason(ring_index: int, season_id: String) -> String:
	if ring_index <= 0:
		return ""
	var requirement := _unlock_requirement_for_ring(ring_index - 1, season_id)
	if String(requirement.get("kind", "boss")) == "boss":
		return "需先击败上一圈的路口领主。"
	return String(requirement.get("blocked_text", "需先满足当前外环条件。"))

func _boss_gate_name(season_id: String, ring_index: int) -> String:
	match season_id:
		"summer":
			return "雷痕路口领主 %d" % (ring_index + 1)
		"autumn":
			return "赤纹路口领主 %d" % (ring_index + 1)
		"winter":
			return "霜镜路口领主 %d" % (ring_index + 1)
		_:
			return "雾苔路口领主 %d" % (ring_index + 1)

func _is_dojo_requirement_satisfied(requirement: Dictionary) -> bool:
	var expected_dojo_id := String(requirement.get("dojo_id", ""))
	var tier := String(requirement.get("tier", "tier_1"))
	if not expected_dojo_id.is_empty():
		return GameState.has_cleared_dojo(expected_dojo_id, tier)
	for dojo_id in GameState.get_current_dojo_rotation():
		if GameState.has_cleared_dojo(String(dojo_id), tier):
			return true
	return false

func _special_ring_for_index(ring_index: int) -> Dictionary:
	return Dictionary(SPECIAL_RING_DEFS.get(ring_index, {})).duplicate(true)

func _special_requirement_for_target_ring(target_ring: int) -> Dictionary:
	var special_ring := _special_ring_for_index(target_ring)
	if special_ring.is_empty():
		return {}
	var dojo_id := String(special_ring.get("dojo_id", ""))
	var tier := String(special_ring.get("tier", "tier_1"))
	var dojo_name := String(DataRepository.get_dojo(dojo_id).get("name", dojo_id))
	var skill_id := String(special_ring.get("skill_id", ""))
	var skill_name := GameState.get_traversal_skill_name(skill_id)
	var blocked_text := _build_special_ring_blocked_text(
		String(special_ring.get("name", "特殊环带")),
		skill_name,
		dojo_name,
		tier,
		Array(special_ring.get("time_windows", [])).duplicate()
	)
	return {
		"kind": "special",
		"ring_id": String(special_ring.get("id", "")),
		"ring_name": String(special_ring.get("name", "特殊环带")),
		"gate_name": String(special_ring.get("gate_name", "特殊外环门")),
		"gate_description": String(special_ring.get("gate_description", "这里通向更外层的特殊地块环带。")),
		"skill_id": skill_id,
		"skill_name": skill_name,
		"dojo_id": dojo_id,
		"dojo_name": dojo_name,
		"tier": tier,
		"time_windows": Array(special_ring.get("time_windows", [])).duplicate(),
		"label": String(special_ring.get("gate_name", special_ring.get("name", "特殊外环"))),
		"blocked_text": blocked_text,
		"summary": String(special_ring.get("unlock_summary", "特殊外环已经接通。")),
	}

func _evaluate_gate_requirement(requirement: Dictionary) -> Dictionary:
	var kind := String(requirement.get("kind", "boss"))
	if kind == "dojo":
		if _is_dojo_requirement_satisfied(requirement):
			return {
				"ok": true,
				"summary": String(requirement.get("summary", "通过了 %s。" % String(requirement.get("label", "当前道馆")))),
			}
		return {
			"ok": false,
			"awaiting": "dojo",
			"message": String(requirement.get("blocked_text", "还需要先通过当前外环对应的道馆。")),
		}
	if kind != "special":
		return {"ok": true, "summary": "外环条件已经满足。"}
	var reasons: Array[String] = []
	var awaiting := ""
	var skill_id := String(requirement.get("skill_id", ""))
	var skill_name := String(requirement.get("skill_name", GameState.get_traversal_skill_name(skill_id)))
	if not skill_id.is_empty() and not GameState.has_traversal_skill(skill_id):
		reasons.append("先学会 %s" % skill_name)
		awaiting = "skill"
	var dojo_required := not _is_dojo_requirement_satisfied(requirement)
	if dojo_required:
		var dojo_name := String(requirement.get("dojo_name", requirement.get("dojo_id", "当前道馆")))
		reasons.append("通过 %s 的 %s" % [dojo_name, _tier_name(String(requirement.get("tier", "tier_1")))])
		awaiting = "dojo"
	var time_windows: Array = Array(requirement.get("time_windows", [])).duplicate()
	if not time_windows.is_empty() and not time_windows.has(GameState.time_of_day):
		reasons.append("等到 %s 再来" % _format_time_window_list(time_windows))
		if awaiting.is_empty():
			awaiting = "time"
	if reasons.is_empty():
		return {
			"ok": true,
			"summary": String(requirement.get("summary", "特殊外环已经接通。")),
		}
	return {
		"ok": false,
		"awaiting": awaiting,
		"message": "想切进 %s，还需要 %s。" % [
			String(requirement.get("ring_name", "更外侧环带")),
			"、".join(reasons),
		],
	}

func _build_special_ring_blocked_text(ring_name: String, skill_name: String, dojo_name: String, tier: String, time_windows: Array) -> String:
	var parts: Array[String] = []
	if not skill_name.is_empty():
		parts.append("学会 %s" % skill_name)
	if not dojo_name.is_empty():
		parts.append("通过 %s 的 %s" % [dojo_name, _tier_name(tier)])
	if not time_windows.is_empty():
		parts.append("在 %s 切入" % _format_time_window_list(time_windows))
	if parts.is_empty():
		return "%s 暂时还没接通。" % ring_name
	return "想进入 %s，需要先%s。" % [ring_name, "、".join(parts)]

func _format_time_window_list(time_windows: Array) -> String:
	var parts: Array[String] = []
	for raw_time in time_windows:
		var time_id := String(raw_time)
		if time_id.is_empty():
			continue
		var label := String(TIME_NAMES.get(time_id, time_id))
		if not parts.has(label):
			parts.append(label)
	return " / ".join(parts)

func _tier_name(tier: String) -> String:
	match tier:
		"tier_1":
			return "试炼一阶"
		"tier_2":
			return "试炼二阶"
		"tier_3":
			return "试炼三阶"
		_:
			return tier

func _special_encounter_hint(encounter_pool: Array) -> String:
	var names: Array[String] = []
	for entry in encounter_pool:
		var species_id := String(Dictionary(entry).get("species_id", ""))
		if species_id.is_empty():
			continue
		var species_name := String(DataRepository.get_species(species_id).get("name", species_id))
		if names.has(species_name):
			continue
		names.append(species_name)
		if names.size() >= 4:
			break
	return " / ".join(names)

func _initial_revealed_nodes(nodes: Array, unlocked_ring_count: int) -> Array[int]:
	var adjacency := _build_undirected_adjacency(nodes)
	var revealed := _collect_graph_nodes_with_adjacency(0, 2, adjacency)
	if unlocked_ring_count > 0:
		revealed.append_array(_unlock_reveal_nodes(0))
	for raw_node in nodes:
		var node: Dictionary = _normalize_node(raw_node)
		if int(node.get("ring_index", -1)) != 0:
			continue
		if String(node.get("type", "")) != "minigame":
			continue
		revealed.append(int(node.get("id", -1)))
	return _dedupe_sorted_ints(revealed)

func _unlock_reveal_nodes(ring_index: int) -> Array[int]:
	var revealed: Array[int] = []
	if ring_index < 0 or ring_index >= _ring_node_ids.size():
		return revealed
	for node_id in _ring_node_ids[ring_index]:
		revealed.append(int(node_id))
		if revealed.size() >= 8:
			break
		for neighbor_id in _neighbors(int(node_id)):
			revealed.append(int(neighbor_id))
	return _dedupe_sorted_ints(revealed)

func _collect_forward_nodes(from_node_id: int, max_depth: int) -> Array[int]:
	var revealed := {from_node_id: true}
	var frontier: Array = [{"node_id": from_node_id, "depth": 0}]
	while not frontier.is_empty():
		var state: Dictionary = frontier.pop_front()
		var node_id := int(state.get("node_id", -1))
		var depth := int(state.get("depth", 0))
		if depth >= max_depth:
			continue
		for neighbor_id in _neighbors(node_id):
			if is_node_locked(neighbor_id):
				continue
			if revealed.has(neighbor_id):
				continue
			revealed[neighbor_id] = true
			frontier.append({"node_id": neighbor_id, "depth": depth + 1})
	return _sorted_node_keys(revealed)

func _collect_graph_nodes(from_node_id: int, radius: int, include_reverse: bool) -> Array[int]:
	var adjacency := _build_runtime_adjacency(include_reverse)
	return _collect_graph_nodes_with_adjacency(from_node_id, radius, adjacency)

func _collect_graph_nodes_with_adjacency(from_node_id: int, radius: int, adjacency: Dictionary) -> Array[int]:
	if from_node_id == -1:
		return []
	var visited := {from_node_id: 0}
	var frontier: Array = [{"node_id": from_node_id, "depth": 0}]
	while not frontier.is_empty():
		var state: Dictionary = frontier.pop_front()
		var node_id := int(state.get("node_id", -1))
		var depth := int(state.get("depth", 0))
		if depth >= radius:
			continue
		for neighbor_id in adjacency.get(node_id, []):
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = depth + 1
			frontier.append({"node_id": neighbor_id, "depth": depth + 1})
	return _sorted_node_keys(visited)

func _build_runtime_adjacency(include_reverse: bool) -> Dictionary:
	return _build_adjacency_from_nodes(get_nodes(), include_reverse)

func _build_undirected_adjacency(nodes: Array) -> Dictionary:
	return _build_adjacency_from_nodes(nodes, true)

func _build_adjacency_from_nodes(nodes: Array, include_reverse: bool) -> Dictionary:
	var adjacency := {}
	for raw_node in nodes:
		var node: Dictionary = _normalize_node(raw_node)
		var node_id := int(node.get("id", -1))
		if node_id < 0:
			continue
		if not adjacency.has(node_id):
			adjacency[node_id] = []
		for raw_neighbor in node.get("edges", []):
			var neighbor_id := int(raw_neighbor)
			_add_unique_neighbor(adjacency, node_id, neighbor_id)
			if include_reverse:
				_add_unique_neighbor(adjacency, neighbor_id, node_id)
	return adjacency

func _add_unique_neighbor(adjacency: Dictionary, from_node_id: int, to_node_id: int) -> void:
	var neighbors: Array[int] = []
	for raw_neighbor in adjacency.get(from_node_id, []):
		neighbors.append(int(raw_neighbor))
	if neighbors.has(to_node_id):
		adjacency[from_node_id] = neighbors
		return
	neighbors.append(to_node_id)
	adjacency[from_node_id] = neighbors

func _sorted_node_keys(value: Dictionary) -> Array[int]:
	var keys: Array[int] = []
	for raw_key in value.keys():
		keys.append(int(raw_key))
	keys.sort()
	return keys

func _dedupe_sorted_ints(values: Array) -> Array[int]:
	var seen := {}
	for value in values:
		seen[int(value)] = true
	return _sorted_node_keys(seen)

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
		templates.append(template)
	return templates

func _build_boss_template(seed_region: Dictionary) -> Dictionary:
	var boss_seed_id := int(seed_region.get("boss_node_id", -1))
	for raw_node in seed_region.get("nodes", []):
		var node: Dictionary = _normalize_node(raw_node)
		if int(node.get("id", -1)) == boss_seed_id:
			return node
	return {}

func _template_display_name(template: Dictionary) -> String:
	var habitat_id := String(template.get("habitat_id", ""))
	if habitat_id.is_empty():
		return String(template.get("name", "未知节点"))
	return String(DataRepository.get_habitat(habitat_id).get("name", template.get("name", habitat_id)))

func _register_runtime_region(region: Dictionary) -> void:
	if region.is_empty():
		return
	var region_id := String(region.get("id", ""))
	var season_id := String(region.get("season_id", _current_season_id))
	if not region_id.is_empty():
		DataRepository.board_regions[region_id] = region.duplicate(true)
	if not season_id.is_empty():
		DataRepository.board_regions_by_season[season_id] = region.duplicate(true)
		var boss_rule: Dictionary = DataRepository.season_boss_rules_by_season.get(season_id, {}).duplicate(true)
		if not boss_rule.is_empty():
			boss_rule["node_id"] = int(region.get("boss_node_id", -1))
			DataRepository.season_boss_rules_by_season[season_id] = boss_rule

func _neighbors(node_id: int) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = node_lookup.get(node_id, {})
	for raw_neighbor in node.get("edges", []):
		neighbors.append(int(raw_neighbor))
	return neighbors

class_name GameData
extends RefCounted

const GAME_TITLE := "雾野领主"
const MAX_ROUNDS := 8
const TARGET_PRESTIGE := 10
const BOSS_UNLOCK_ROUND := 5
const FRONTLINE_SLOTS := 2

const RESOURCE_ORDER := ["food", "ore", "knowledge"]
const RESOURCE_NAMES := {
	"food": "食粮",
	"ore": "矿石",
	"knowledge": "灵知",
}

const ROLE_ORDER := ["frontline", "farm", "forge", "lab", "rest"]
const ROLE_NAMES := {
	"frontline": "前线",
	"farm": "苗圃",
	"forge": "熔炉",
	"lab": "研究所",
	"rest": "休整",
}

const TYPE_NAMES := {
	"blaze": "焰",
	"grove": "林",
	"tide": "潮",
	"spark": "霆",
	"stone": "岩",
	"mist": "雾",
}

const TYPE_COLORS := {
	"blaze": Color("d97706"),
	"grove": Color("16a34a"),
	"tide": Color("0ea5e9"),
	"spark": Color("ca8a04"),
	"stone": Color("78716c"),
	"mist": Color("7c3aed"),
}

const TYPE_ADVANTAGE := {
	"blaze": "grove",
	"grove": "tide",
	"tide": "blaze",
	"spark": "mist",
	"mist": "stone",
	"stone": "spark",
}

const BUILDINGS := {
	"farm": {
		"name": "苗圃",
		"description": "提供稳定的食粮与回复物资。",
		"resource": "food",
		"costs": {
			2: {"food": 2, "ore": 1, "knowledge": 0},
			3: {"food": 4, "ore": 2, "knowledge": 1},
		},
	},
	"forge": {
		"name": "熔炉",
		"description": "提炼矿石，为升级和战术支援提供材料。",
		"resource": "ore",
		"costs": {
			2: {"food": 1, "ore": 2, "knowledge": 0},
			3: {"food": 2, "ore": 4, "knowledge": 1},
		},
	},
	"lab": {
		"name": "研究所",
		"description": "转化灵知，解锁永久科技。",
		"resource": "knowledge",
		"costs": {
			2: {"food": 1, "ore": 1, "knowledge": 2},
			3: {"food": 2, "ore": 2, "knowledge": 4},
		},
	},
}

const TECH_TIERS := {
	1: {
		"threshold": 5,
		"choices": [
			{
				"id": "survey_maps",
				"name": "测绘图卷",
				"description": "每回合第一次步数修正免费。",
			},
			{
				"id": "battle_drills",
				"name": "战斗教令",
				"description": "前线单位每场战斗首回合攻击 +2。",
			},
			{
				"id": "auto_haulers",
				"name": "搬运滑轨",
				"description": "苗圃与熔炉回合结算各额外 +1 产出。",
			},
		],
	},
	2: {
		"threshold": 10,
		"choices": [
			{
				"id": "field_hospital",
				"name": "野战医帐",
				"description": "回合结束时前线怪物额外回复 4 点生命。",
			},
			{
				"id": "pressure_core",
				"name": "压制核心",
				"description": "击败 AI 或 Boss 时额外获得 1 点威望。",
			},
			{
				"id": "farsight_lens",
				"name": "远见晶镜",
				"description": "掷骰后自动看到所有可达终点效果。",
			},
		],
	},
}

const SKILLS := {
	"ember_claw": {
		"name": "炽爪",
		"type": "blaze",
		"power": 8,
		"cooldown": 0,
		"target": "enemy",
		"text": "稳定的单体火焰斩击。",
	},
	"scorch_dive": {
		"name": "灼袭",
		"type": "blaze",
		"power": 12,
		"cooldown": 2,
		"target": "enemy",
		"text": "高爆发单体技能。",
	},
	"vine_whip": {
		"name": "缠藤",
		"type": "grove",
		"power": 7,
		"cooldown": 0,
		"target": "enemy",
		"effect": "slow",
		"effect_turns": 2,
		"text": "造成伤害并降低目标速度。",
	},
	"harvest_hymn": {
		"name": "丰收曲",
		"type": "grove",
		"power": 0,
		"cooldown": 2,
		"target": "ally",
		"effect": "heal",
		"effect_value": 7,
		"text": "回复友军生命。",
	},
	"tide_burst": {
		"name": "潮涌",
		"type": "tide",
		"power": 9,
		"cooldown": 1,
		"target": "enemy",
		"text": "中等伤害的水流冲击。",
	},
	"tidal_guard": {
		"name": "潮壳",
		"type": "tide",
		"power": 0,
		"cooldown": 2,
		"target": "self",
		"effect": "guard",
		"effect_value": 0.5,
		"text": "本回合后续受到的伤害减少。",
	},
	"static_jolt": {
		"name": "静电击",
		"type": "spark",
		"power": 8,
		"cooldown": 0,
		"target": "enemy",
		"effect": "vulnerable",
		"effect_turns": 2,
		"text": "使目标更容易受击。",
	},
	"rush_echo": {
		"name": "疾返",
		"type": "spark",
		"power": 7,
		"cooldown": 1,
		"target": "enemy",
		"effect": "haste",
		"effect_target": "self",
		"effect_turns": 1,
		"text": "打击同时提升自身节奏。",
	},
	"stone_ram": {
		"name": "裂岩角",
		"type": "stone",
		"power": 11,
		"cooldown": 1,
		"target": "enemy",
		"text": "高威力正面冲击。",
	},
	"bulwark": {
		"name": "岩壁",
		"type": "stone",
		"power": 0,
		"cooldown": 2,
		"target": "self",
		"effect": "guard",
		"effect_value": 0.45,
		"text": "为自己建立护盾姿态。",
	},
	"mist_dart": {
		"name": "雾羽",
		"type": "mist",
		"power": 7,
		"cooldown": 0,
		"target": "enemy",
		"text": "轻快的远程打击。",
	},
	"hush_wing": {
		"name": "寂翼",
		"type": "mist",
		"power": 6,
		"cooldown": 1,
		"target": "enemy",
		"effect": "weaken",
		"effect_value": 2,
		"effect_turns": 2,
		"text": "降低目标攻击。",
	},
	"boss_shard": {
		"name": "裂辉束",
		"type": "mist",
		"power": 12,
		"cooldown": 0,
		"target": "enemy",
		"text": "尖塔守卫发射不稳定的裂辉。",
	},
	"boss_pulse": {
		"name": "塔心脉冲",
		"type": "spark",
		"power": 0,
		"cooldown": 2,
		"target": "enemy_all",
		"effect": "damage_all",
		"effect_value": 6,
		"text": "对全体敌人造成脉冲伤害。",
	},
}

const MONSTERS := {
	"ember_lynx": {
		"name": "焰猞",
		"type": "blaze",
		"max_hp": 30,
		"attack": 9,
		"speed": 8,
		"skills": ["ember_claw", "scorch_dive"],
		"roles": {"frontline": 2, "farm": 1, "forge": 0, "lab": 0, "rest": 1},
		"bio": "擅长前线切入和短促爆发的赤焰猎手。",
	},
	"mossback": {
		"name": "苔岳",
		"type": "grove",
		"max_hp": 35,
		"attack": 7,
		"speed": 5,
		"skills": ["vine_whip", "harvest_hymn"],
		"roles": {"frontline": 1, "farm": 3, "forge": 0, "lab": 1, "rest": 1},
		"bio": "厚重稳健，能把战斗收益变成持续经营。",
	},
	"tide_mite": {
		"name": "潮甲",
		"type": "tide",
		"max_hp": 31,
		"attack": 8,
		"speed": 6,
		"skills": ["tide_burst", "tidal_guard"],
		"roles": {"frontline": 2, "farm": 0, "forge": 2, "lab": 0, "rest": 1},
		"bio": "攻守均衡，擅长矿线和持久战。",
	},
	"spark_hare": {
		"name": "霆兔",
		"type": "spark",
		"max_hp": 26,
		"attack": 8,
		"speed": 10,
		"skills": ["static_jolt", "rush_echo"],
		"roles": {"frontline": 2, "farm": 0, "forge": 1, "lab": 3, "rest": 1},
		"bio": "高机动的研究型打手，适合开局建立节奏。",
	},
	"stonehorn": {
		"name": "岩角",
		"type": "stone",
		"max_hp": 38,
		"attack": 10,
		"speed": 4,
		"skills": ["stone_ram", "bulwark"],
		"roles": {"frontline": 3, "farm": 0, "forge": 3, "lab": 0, "rest": 1},
		"bio": "慢但扎实，适合作为阵线核心。",
	},
	"mist_owl": {
		"name": "雾隼",
		"type": "mist",
		"max_hp": 28,
		"attack": 7,
		"speed": 9,
		"skills": ["mist_dart", "hush_wing"],
		"roles": {"frontline": 2, "farm": 0, "forge": 0, "lab": 2, "rest": 2},
		"bio": "善于扰乱敌方节奏，也适合侦察与研究。",
	},
	"spire_guardian": {
		"name": "裂辉守卫",
		"type": "mist",
		"max_hp": 42,
		"attack": 11,
		"speed": 7,
		"skills": ["boss_shard", "boss_pulse"],
		"roles": {"frontline": 0, "farm": 0, "forge": 0, "lab": 0, "rest": 0},
		"bio": "守护裂辉尖塔的远古机关。",
	},
}

const START_PLAYER_SPECIES := ["ember_lynx", "mossback", "spark_hare"]

const AI_PERSONALITIES := {
	"aggressive": {
		"name": "赤旌掠主",
		"description": "偏爱战斗、据点和 Boss 的正面冲突。",
		"weights": {
			"battle": 5,
			"resource": 2,
			"event": 1,
			"market": 1,
			"research": 1,
			"control": 4,
			"boss": 8,
			"camp": 0,
		},
		"lineup": ["stonehorn", "ember_lynx"],
	},
	"industrial": {
		"name": "铜炉执政",
		"description": "偏好资源、研究和稳定发育。",
		"weights": {
			"battle": 2,
			"resource": 5,
			"event": 2,
			"market": 2,
			"research": 5,
			"control": 4,
			"boss": 5,
			"camp": 1,
		},
		"lineup": ["mossback", "tide_mite"],
	},
	"opportunist": {
		"name": "灰雾投机者",
		"description": "围绕研究点与残局收割行动。",
		"weights": {
			"battle": 3,
			"resource": 2,
			"event": 4,
			"market": 3,
			"research": 5,
			"control": 5,
			"boss": 6,
			"camp": 1,
		},
		"lineup": ["mist_owl", "spark_hare"],
	},
}

const BOARD_NODES := [
	{
		"id": 0,
		"name": "启程营地",
		"type": "camp",
		"description": "营地会在回合结算时为前线恢复士气。",
		"position": Vector2(72, 310),
		"edges": [1],
	},
	{
		"id": 1,
		"name": "日穗田",
		"type": "resource",
		"description": "稳定的食粮地块。",
		"reward": {"food": 2},
		"position": Vector2(196, 192),
		"edges": [2],
	},
	{
		"id": 2,
		"name": "雾苔窟",
		"type": "battle",
		"description": "低威胁野外巢穴，适合抓捕。",
		"position": Vector2(338, 116),
		"edges": [3],
	},
	{
		"id": 3,
		"name": "裂隙岔路",
		"type": "event",
		"description": "会触发一次局势选择。",
		"position": Vector2(476, 194),
		"edges": [4, 5],
	},
	{
		"id": 4,
		"name": "铜锤集",
		"type": "market",
		"description": "可用资源换取治疗或即时收益。",
		"position": Vector2(620, 112),
		"edges": [6],
	},
	{
		"id": 5,
		"name": "晶溪滩",
		"type": "resource",
		"description": "高价值矿脉，但路线更长。",
		"reward": {"ore": 2},
		"position": Vector2(622, 298),
		"edges": [7],
	},
	{
		"id": 6,
		"name": "獠牙巢穴",
		"type": "battle",
		"description": "更危险的野外点位，能刷新高阶怪物。",
		"position": Vector2(780, 128),
		"edges": [8],
	},
	{
		"id": 7,
		"name": "云升驿",
		"type": "event",
		"description": "提供支援、捷径和小幅风险。",
		"position": Vector2(782, 336),
		"edges": [8],
	},
	{
		"id": 8,
		"name": "古械平台",
		"type": "control",
		"description": "关键运输节点，占领后每回合提供矿石和威望。",
		"control_reward": {"ore": 1, "prestige": 1},
		"position": Vector2(928, 228),
		"edges": [9, 10],
	},
	{
		"id": 9,
		"name": "观星废都",
		"type": "research",
		"description": "核心研究点，优先争夺。",
		"reward": {"knowledge": 2},
		"control_reward": {"knowledge": 1, "prestige": 1},
		"position": Vector2(1082, 126),
		"edges": [11],
	},
	{
		"id": 10,
		"name": "风纹神龛",
		"type": "resource",
		"description": "获得食粮与灵知的小型混合点。",
		"reward": {"food": 1, "knowledge": 1},
		"position": Vector2(1080, 340),
		"edges": [11],
	},
	{
		"id": 11,
		"name": "冠冕关塞",
		"type": "control",
		"description": "Boss 之前的争夺关口，占领可压制对手。",
		"control_reward": {"food": 1, "knowledge": 1, "prestige": 1},
		"position": Vector2(1242, 232),
		"edges": [12, 13],
	},
	{
		"id": 12,
		"name": "裂辉尖塔",
		"type": "boss",
		"description": "第 5 回合后开放，击破可改变胜负。",
		"position": Vector2(1398, 234),
		"edges": [13],
	},
	{
		"id": 13,
		"name": "归航门",
		"type": "camp",
		"description": "回到起点，准备下一轮路线。",
		"position": Vector2(1530, 308),
		"edges": [0],
	},
]

const EVENT_CARDS := [
	{
		"id": "supply_cache",
		"title": "旧侦察站",
		"text": "半塌的侦察站里还留着能用的补给。",
		"choices": [
			{"id": "salvage", "label": "拆解补给", "summary": "矿石 +2，食粮 +1", "effects": {"ore": 2, "food": 1}},
			{"id": "survey", "label": "绘制路线", "summary": "威望 +1，下回合专注 +1", "effects": {"prestige": 1, "next_turn_focus": 1}},
		],
	},
	{
		"id": "field_menders",
		"title": "漂泊修补匠",
		"text": "一支流动工队愿意提供临时援助。",
		"choices": [
			{"id": "patch", "label": "修补装备", "summary": "前线回复 8 点生命", "effects": {"heal_frontline": 8}},
			{"id": "hire", "label": "雇佣搬运", "summary": "本回合熔炉额外 +2 产出", "effects": {"forge_bonus_this_round": 2}},
		],
	},
	{
		"id": "weather_spire",
		"title": "气流异常",
		"text": "裂风穿过雾谷，路线和节奏都可能被打乱。",
		"choices": [
			{"id": "stabilize", "label": "稳住阵线", "summary": "食粮 +1，前线回复 4", "effects": {"food": 1, "heal_frontline": 4}},
			{"id": "ride_wind", "label": "借风推进", "summary": "立即获得 1 点专注", "effects": {"focus_now": 1}},
		],
	},
	{
		"id": "silent_market",
		"title": "黑市耳语",
		"text": "无名商贩愿意快速交换稀缺资源。",
		"choices": [
			{"id": "buy_notes", "label": "换情报", "summary": "矿石 -1，灵知 +2", "effects": {"ore": -1, "knowledge": 2}},
			{"id": "buy_rations", "label": "换军粮", "summary": "灵知 -1，食粮 +2", "effects": {"knowledge": -1, "food": 2}},
		],
	},
]

const WILD_POOLS := {
	2: ["mossback", "mist_owl", "spark_hare"],
	6: ["stonehorn", "tide_mite", "mist_owl"],
}

static func get_board_node(node_id: int) -> Dictionary:
	for node in BOARD_NODES:
		if int(node.get("id", -1)) == node_id:
			return node
	return {}

static func get_board_lookup() -> Dictionary:
	var lookup := {}
	for node in BOARD_NODES:
		lookup[int(node.get("id", -1))] = node
	return lookup

static func get_building_name(building_id: String) -> String:
	return BUILDINGS.get(building_id, {}).get("name", building_id)

static func get_role_name(role_id: String) -> String:
	return ROLE_NAMES.get(role_id, role_id)

static func get_resource_name(resource_id: String) -> String:
	return RESOURCE_NAMES.get(resource_id, resource_id)

static func get_type_name(type_id: String) -> String:
	return TYPE_NAMES.get(type_id, type_id)

static func get_next_building_cost(building_id: String, level: int) -> Dictionary:
	return BUILDINGS.get(building_id, {}).get("costs", {}).get(level + 1, {})

static func type_multiplier(attacker_type: String, defender_type: String) -> float:
	if TYPE_ADVANTAGE.get(attacker_type, "") == defender_type:
		return 1.3
	if TYPE_ADVANTAGE.get(defender_type, "") == attacker_type:
		return 0.8
	return 1.0

static func get_ai_weight(personality_id: String, node_type: String) -> int:
	return AI_PERSONALITIES.get(personality_id, {}).get("weights", {}).get(node_type, 0)

static func format_resource_delta(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for key in RESOURCE_ORDER:
		if delta.get(key, 0) != 0:
			var value := int(delta[key])
			var prefix := "+" if value > 0 else ""
			parts.append("%s%s%s" % [prefix, str(value), RESOURCE_NAMES[key]])
	if delta.get("prestige", 0) != 0:
		var prestige := int(delta["prestige"])
		var prestige_prefix := "+" if prestige > 0 else ""
		parts.append("%s%s威望" % [prestige_prefix, str(prestige)])
	return "，".join(parts)

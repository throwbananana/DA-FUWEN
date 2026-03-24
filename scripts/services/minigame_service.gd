class_name MinigameService
extends RefCounted

const BONUS_LABELS := {
	"ally_attack_bonus": "攻击",
	"ally_speed_bonus": "速度",
	"ally_hp_bonus": "体力",
}

const MINIGAMES := {
	"moss_dash": {
		"name": "苔径追跑",
		"prompt": "幼体会沿着软苔圈来回折返，你得看准节奏带它一起切线。",
		"focus_text": "偏速度热身",
		"success_text": "你提前踩准了折返点，整队节奏一下就顺了起来。",
		"fallback_text": "这轮没完全踩上拍子，但也算让大家活动开了。",
		"base_bonus": {"ally_speed_bonus": 1},
		"success_bonus": {"ally_speed_bonus": 2},
		"choices": [
			{"id": "cut_in", "label": "提前切线", "summary": "抢前一步去接它的折返。"},
			{"id": "steady", "label": "稳住步幅", "summary": "先跟住它的节奏，再慢慢提速。"},
			{"id": "turn_back", "label": "回身补位", "summary": "等它转回来时再重新并线。"},
		],
	},
	"ring_toss": {
		"name": "抛环接力",
		"prompt": "你把轻木环抛出去，让伙伴轮流扑接，看谁能把落点咬得更准。",
		"focus_text": "偏攻击热身",
		"success_text": "这一轮的抛接特别利落，出手和扑击都更稳了。",
		"fallback_text": "木环落点有些飘，不过扑接感觉还是被带热了。",
		"base_bonus": {"ally_attack_bonus": 1},
		"success_bonus": {"ally_attack_bonus": 2},
		"choices": [
			{"id": "low_arc", "label": "压低弧线", "summary": "让扑接更看反应和爆发。"},
			{"id": "flat_throw", "label": "平直甩出", "summary": "赌一手又快又准的短线出手。"},
			{"id": "high_jump", "label": "抬高落点", "summary": "逼它们提前起跳去咬环。"},
		],
	},
	"warmup_nap": {
		"name": "暖垫打盹",
		"prompt": "热石垫刚好晒暖，大家挤在一起翻个身，顺手把呼吸和状态调匀。",
		"focus_text": "偏体力热身",
		"success_text": "这轮休整把呼吸彻底顺开了，站上场会更稳一些。",
		"fallback_text": "虽然还没完全放松到位，但身体总算暖开了。",
		"base_bonus": {"ally_hp_bonus": 4},
		"success_bonus": {"ally_hp_bonus": 6},
		"choices": [
			{"id": "huddle", "label": "抱团取暖", "summary": "让大家先贴在一起慢慢回温。"},
			{"id": "sun_flip", "label": "翻身晒暖", "summary": "借热石把身体两侧都晒开。"},
			{"id": "moss_press", "label": "轻踩松苔", "summary": "先踩松脚下再整个趴下去。"},
		],
	},
	"thunder_steps": {
		"name": "雷线折返",
		"prompt": "地上画着几段雷痕跑格，你得带着伙伴踩准折返和停顿。",
		"focus_text": "偏速度热身",
		"success_text": "这轮折返踩得很准，大家的起步都轻了一截。",
		"fallback_text": "脚步有点乱，但至少把身体热开了。",
		"base_bonus": {"ally_speed_bonus": 1},
		"success_bonus": {"ally_speed_bonus": 2},
		"choices": [
			{"id": "snap_step", "label": "快进快收", "summary": "用最短的步数压完一整段雷线。"},
			{"id": "count_beat", "label": "按拍折返", "summary": "严格照着停顿和起步的节奏走。"},
			{"id": "long_stride", "label": "拉大步幅", "summary": "靠大步直接跨掉中间那格。"},
		],
	},
	"gear_pull": {
		"name": "拉杆牵引",
		"prompt": "旧工棚前挂了几段练力绳，大家轮着扑上去把拉杆拽回原位。",
		"focus_text": "偏攻击热身",
		"success_text": "发力点抓得很准，扑击和拉拽的手感都起来了。",
		"fallback_text": "节奏差了一点，但身体已经开始进状态了。",
		"base_bonus": {"ally_attack_bonus": 1},
		"success_bonus": {"ally_attack_bonus": 2},
		"choices": [
			{"id": "front_burst", "label": "正面爆拽", "summary": "直接从正面抢第一下爆发。"},
			{"id": "hip_turn", "label": "拧腰带动", "summary": "用转身把后劲一起带出来。"},
			{"id": "short_tug", "label": "短拽连发", "summary": "靠小幅连续发力拉满整段阻力。"},
		],
	},
	"leaf_huddle": {
		"name": "落叶埋身",
		"prompt": "你把干燥叶堆拢成一圈，让伙伴轮流钻进去再自己拱出来。",
		"focus_text": "偏体力热身",
		"success_text": "叶堆松紧正合适，钻进钻出的那几下把状态垫得很稳。",
		"fallback_text": "叶堆有点散，但至少把身子和呼吸都暖起来了。",
		"base_bonus": {"ally_hp_bonus": 4},
		"success_bonus": {"ally_hp_bonus": 6},
		"choices": [
			{"id": "pack_center", "label": "压实中心", "summary": "先把中间压暖，再让它们往里钻。"},
			{"id": "leave_gap", "label": "留出气口", "summary": "让它们能更顺地拱进去再拱出来。"},
			{"id": "roll_layer", "label": "分层翻叶", "summary": "把表层和底层叶子先翻松再堆。"},
		],
	},
	"ice_steps": {
		"name": "霜点踏步",
		"prompt": "地上点着一圈暖灯，你得带着伙伴踩着亮起顺序穿过去。",
		"focus_text": "偏速度热身",
		"success_text": "这轮踏步几乎没乱，起步和换位都快了不少。",
		"fallback_text": "灯点没完全踩顺，但脚步总算被提起来了。",
		"base_bonus": {"ally_speed_bonus": 1},
		"success_bonus": {"ally_speed_bonus": 2},
		"choices": [
			{"id": "inside_line", "label": "抢内圈", "summary": "尽量缩短换步路线。"},
			{"id": "follow_flash", "label": "跟灯走", "summary": "死盯亮灯节奏再起步。"},
			{"id": "delay_half", "label": "慢半拍进", "summary": "等光稳下来再压上去。"},
		],
	},
	"snow_roll": {
		"name": "雪垫翻身",
		"prompt": "暖棚边堆起了软雪垫，大家翻进去又翻出来，顺手把关节和呼吸活动开。",
		"focus_text": "偏体力热身",
		"success_text": "翻身节奏踩准了，整队的耐性和站场感都更稳了。",
		"fallback_text": "动作稍微卡壳，不过状态还是被垫起来一点。",
		"base_bonus": {"ally_hp_bonus": 4},
		"success_bonus": {"ally_hp_bonus": 6},
		"choices": [
			{"id": "shoulder_roll", "label": "先压肩侧", "summary": "从侧面压过去让身体先放松。"},
			{"id": "back_sink", "label": "后背先落", "summary": "让重心先沉进雪垫里。"},
			{"id": "kick_flip", "label": "蹬腿翻回", "summary": "靠下肢把整次翻身带完。"},
		],
	},
}

func build_board_minigame(node: Dictionary) -> Dictionary:
	var game: Dictionary = _get_game(node)
	var choices: Array = []
	for raw_choice in Array(game.get("choices", [])):
		var choice: Dictionary = Dictionary(raw_choice).duplicate(true)
		choices.append({
			"id": String(choice.get("id", "")),
			"label": String(choice.get("label", "试一把")),
			"summary": String(choice.get("summary", "")),
		})
	var body_lines: Array[String] = [
		String(node.get("description", "路边正好有个能让伙伴活动开的小游戏摊位。")),
		"",
		"[b]玩法[/b] %s" % String(game.get("prompt", "带着伙伴做个短促的热身小游戏。")),
		"[b]收益[/b] %s" % String(game.get("focus_text", "会给下一场战斗一点小加成。")),
		"猜中节奏会拿到更好的热身效果；就算失手，也能留下小幅增益。",
	]
	return {
		"ok": true,
		"title": String(node.get("name", game.get("name", "小游戏地块"))),
		"body": "\n".join(body_lines),
		"choices": choices,
	}

func resolve_board_minigame(node: Dictionary, choice_id: String) -> Dictionary:
	var game: Dictionary = _get_game(node)
	var choices: Array = Array(game.get("choices", [])).duplicate(true)
	var correct_index: int = _correct_choice_index(node, choices.size())
	var selected_index: int = _choice_index(choices, choice_id)
	var success := selected_index == correct_index
	var reward_bonus: Dictionary = Dictionary(game.get("success_bonus", {})).duplicate(true) if success else Dictionary(game.get("base_bonus", {})).duplicate(true)
	var note := "%s：%s" % [
		String(node.get("name", game.get("name", "小游戏地块"))),
		_format_bonus(Dictionary(reward_bonus).duplicate(true)),
	]
	var pending_result: Dictionary = GameState.add_pending_minigame_bonus(reward_bonus, note)
	return {
		"ok": true,
		"title": String(node.get("name", game.get("name", "小游戏地块"))),
		"success": success,
		"text": String(game.get("success_text", "")) if success else String(game.get("fallback_text", "")),
		"reward_bonus": reward_bonus,
		"reward_text": _format_bonus(Dictionary(reward_bonus).duplicate(true)),
		"combined_bonus": Dictionary(pending_result.get("bonus", {})).duplicate(true),
		"combined_text": _format_bonus(Dictionary(pending_result.get("bonus", {})).duplicate(true)),
	}

func merge_with_pending_battle_bonus(base_bonus: Dictionary) -> Dictionary:
	var merged: Dictionary = Dictionary(base_bonus).duplicate(true)
	var pending: Dictionary = GameState.peek_pending_minigame_bonus()
	for stat_key in pending.keys():
		var current_value := int(merged.get(stat_key, 0))
		merged[stat_key] = current_value + int(pending.get(stat_key, 0))
	return merged

func pending_bonus_summary() -> String:
	var pending: Dictionary = GameState.peek_pending_minigame_bonus()
	var text := _format_bonus(pending)
	if text.is_empty():
		return ""
	return "小游戏热身：%s" % text

func has_pending_bonus() -> bool:
	return not _format_bonus(GameState.peek_pending_minigame_bonus()).is_empty()

func _get_game(node: Dictionary) -> Dictionary:
	var game_id := String(node.get("minigame_id", ""))
	return Dictionary(MINIGAMES.get(game_id, MINIGAMES.get("moss_dash", {}))).duplicate(true)

func _correct_choice_index(node: Dictionary, count: int) -> int:
	if count <= 0:
		return 0
	var seed_text := "%s|%s|%d|%d" % [
		String(node.get("minigame_id", "")),
		GameState.season_id,
		GameState.week_index,
		int(node.get("id", -1)),
	]
	return int(posmod(hash(seed_text), count))

func _choice_index(choices: Array, choice_id: String) -> int:
	for index in range(choices.size()):
		var choice: Dictionary = Dictionary(choices[index]).duplicate(true)
		if String(choice.get("id", "")) == choice_id:
			return index
	return -1

func _format_bonus(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_key in ["ally_attack_bonus", "ally_speed_bonus", "ally_hp_bonus"]:
		var value := int(bonus.get(stat_key, 0))
		if value <= 0:
			continue
		parts.append("%s +%d" % [String(BONUS_LABELS.get(stat_key, stat_key)), value])
	return " / ".join(parts)

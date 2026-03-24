class_name InfirmaryService
extends RefCounted

const AUTO_RECOVERY_BASE_COST := 4
const AUTO_RECOVERY_RING_STEP := 2
const SPECIAL_LOOP_SURCHARGE := 2
const DOJO_SURCHARGE := 2

func build_stop_menu(node: Dictionary) -> Dictionary:
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "疗养所")),
		String(node.get("description", "这里有人照看队伍，能让宠物和行装一起稳下来。")),
	]
	var scope_text := _service_scope_text(node)
	if not scope_text.is_empty():
		body_lines.append(scope_text)
	body_lines.append("")
	body_lines.append("主动疗养会让队伍痊愈并恢复行进状态，这次不收费。")
	body_lines.append("当前资金 %d 金 ｜ 当前饥饿 %d / %d" % [GameState.wallet_gold, GameState.hunger, GameState.max_hunger])
	return {
		"title": String(node.get("name", "疗养所")),
		"body": "\n".join(body_lines),
		"choices": [{
			"id": "rest",
			"label": "免费疗养",
			"summary": "主动进来休整，不扣金币，直接把队伍状态拉满。",
		}],
	}

func resolve_voluntary_rest(node: Dictionary) -> Dictionary:
	var hunger_before := GameState.hunger
	var hunger_after := GameState.restore_hunger(GameState.max_hunger)
	var body_lines: Array[String] = [
		"[b]%s[/b] 给队伍做了一轮安置、换药和热食休整。" % String(node.get("name", "疗养所")),
		"这是主动疗养，本次不收金币。",
	]
	if hunger_after > hunger_before:
		body_lines.append("饥饿恢复到 %d / %d。" % [hunger_after, GameState.max_hunger])
	else:
		body_lines.append("今天状态本来就稳，只做了例行检查。")
	body_lines.append("当前资金 %d 金。" % GameState.wallet_gold)
	var scope_text := _service_scope_text(node)
	if not scope_text.is_empty():
		body_lines.append(scope_text)
	return {
		"title": "疗养完成",
		"body": "\n".join(body_lines),
		"paid_gold": 0,
		"hunger_after": hunger_after,
		"wallet_gold": GameState.wallet_gold,
	}

func resolve_forced_recovery(infirmary_node: Dictionary, defeated_node: Dictionary) -> Dictionary:
	var expected_fee := auto_recovery_cost(defeated_node)
	var available_gold := GameState.wallet_gold
	var paid_gold := mini(expected_fee, available_gold)
	GameState.spend_wallet_gold(paid_gold)
	var hunger_after := GameState.restore_hunger(GameState.max_hunger)
	var body_lines: Array[String] = [
		"[b]自动送医[/b] 战斗失利后，队伍被送往 %s 暂作休整。" % String(infirmary_node.get("name", "疗养所")),
	]
	if paid_gold >= expected_fee:
		body_lines.append("疗养费 -%d 金，当前资金 %d 金。" % [paid_gold, GameState.wallet_gold])
	elif paid_gold > 0:
		body_lines.append("应收疗养费 %d 金，但手头只剩 %d 金，已全部扣除。" % [expected_fee, paid_gold])
	else:
		body_lines.append("应收疗养费 %d 金，但这次手头已经没钱可扣了。" % expected_fee)
	body_lines.append("包扎和热食让队伍恢复到可继续推进的状态，饥饿回到 %d / %d。" % [hunger_after, GameState.max_hunger])
	var scope_text := _service_scope_text(infirmary_node)
	if not scope_text.is_empty():
		body_lines.append(scope_text)
	return {
		"title": "疗养所",
		"body": "\n".join(body_lines),
		"paid_gold": paid_gold,
		"expected_gold": expected_fee,
		"hunger_after": hunger_after,
		"wallet_gold": GameState.wallet_gold,
	}

func auto_recovery_cost(defeated_node: Dictionary) -> int:
	var ring_index := maxi(0, int(defeated_node.get("ring_index", 0)))
	var cost := AUTO_RECOVERY_BASE_COST + ring_index * AUTO_RECOVERY_RING_STEP
	if not String(defeated_node.get("special_loop_id", "")).is_empty():
		cost += SPECIAL_LOOP_SURCHARGE
	if String(defeated_node.get("type", "")) == "dojo":
		cost += DOJO_SURCHARGE
	return maxi(cost, 1)

func _service_scope_text(node: Dictionary) -> String:
	var linked_habitat_name := String(node.get("linked_habitat_name", ""))
	if not linked_habitat_name.is_empty():
		return "配套地点：%s。" % linked_habitat_name
	var special_loop_name := String(node.get("special_loop_name", ""))
	if not special_loop_name.is_empty():
		return "负责环带：%s。" % special_loop_name
	return ""

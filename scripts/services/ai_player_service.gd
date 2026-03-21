class_name AIPlayerService
extends RefCounted

const GameData = preload("res://scripts/game_data.gd")

const MAX_ROLL := 6
const REROLL_THRESHOLD := 2.25

func simulate_turns(node_lookup: Dictionary, commit_results: bool = true) -> Dictionary:
	var players: Array = GameState.get_ai_players()
	var reports: Array = []
	for index in range(players.size()):
		var rival := Dictionary(players[index]).duplicate(true)
		var report := _simulate_single_turn(rival, node_lookup)
		report["index"] = index
		players[index] = report.get("player", rival)
		reports.append(report)
	if commit_results:
		GameState.set_ai_players(players)
	return {
		"players": players,
		"reports": reports,
	}

func build_node_markers() -> Dictionary:
	var markers := {}
	for rival in GameState.get_ai_players():
		var state := Dictionary(rival)
		var node_id := int(state.get("current_node_id", -1))
		if node_id < 0:
			continue
		if not markers.has(node_id):
			markers[node_id] = []
		markers[node_id].append(String(state.get("display_name", "对手")))
	return markers

func build_summary_entries(node_lookup: Dictionary) -> Array:
	var players: Array = GameState.get_ai_players()
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _player_score(a) > _player_score(b)
	)
	var entries: Array = []
	for rival in players:
		var state := Dictionary(rival)
		var node_id := int(state.get("current_node_id", -1))
		entries.append({
			"name": String(state.get("display_name", "对手")),
			"node_name": String(node_lookup.get(node_id, {}).get("name", "营地")),
			"prestige": int(state.get("prestige", 0)),
			"gold": int(state.get("gold", 0)),
			"intel": int(state.get("intel", 0)),
			"control": int(state.get("control", 0)),
			"latest_action_short": String(state.get("latest_action_short", "待命")),
			"intent": String(state.get("intent", "继续观察")),
			"lineup_text": _format_lineup_text(state),
		})
	return entries

func build_status_lines(node_lookup: Dictionary, max_lines: int = 3) -> Array[String]:
	var lines: Array[String] = []
	for entry in build_summary_entries(node_lookup):
		lines.append("%s：%s ｜ 威望 %d ｜ 金 %d ｜ %s" % [
			String(entry.get("name", "对手")),
			String(entry.get("node_name", "营地")),
			int(entry.get("prestige", 0)),
			int(entry.get("gold", 0)),
			String(entry.get("latest_action_short", "待命")),
		])
		if lines.size() >= max_lines:
			break
	if lines.is_empty():
		lines.append("其他远征队暂时没有公开动向。")
	return lines

func _simulate_single_turn(rival: Dictionary, node_lookup: Dictionary) -> Dictionary:
	var current_node_id := int(rival.get("current_node_id", 0))
	var ideal_plan := _build_turn_plan(rival, node_lookup)
	var move_report := _resolve_move(rival, current_node_id, node_lookup, ideal_plan)
	var updated_rival: Dictionary = Dictionary(move_report.get("player", rival)).duplicate(true)
	var node_id := int(updated_rival.get("current_node_id", current_node_id))
	var landed_node := Dictionary(node_lookup.get(node_id, {})).duplicate(true)
	var pre_landing_state := updated_rival.duplicate(true)
	var action_report := _resolve_landing(updated_rival, landed_node)
	updated_rival = Dictionary(action_report.get("player", updated_rival)).duplicate(true)
	var move_text := String(move_report.get("text", ""))
	var action_text := String(action_report.get("text", ""))
	var landing_debug := {
		"text": action_text,
		"short": String(action_report.get("short", "继续推进")),
		"node_id": node_id,
		"node_name": String(landed_node.get("name", "")),
		"node_type": _legacy_type_for_node(landed_node, node_lookup) if not landed_node.is_empty() else "none",
		"gold_delta": int(updated_rival.get("gold", 0)) - int(pre_landing_state.get("gold", 0)),
		"intel_delta": int(updated_rival.get("intel", 0)) - int(pre_landing_state.get("intel", 0)),
		"control_delta": int(updated_rival.get("control", 0)) - int(pre_landing_state.get("control", 0)),
		"prestige_delta": int(updated_rival.get("prestige", 0)) - int(pre_landing_state.get("prestige", 0)),
		"rerolls_delta": int(updated_rival.get("tactical_rerolls", 0)) - int(pre_landing_state.get("tactical_rerolls", 0)),
		"gold_after": int(updated_rival.get("gold", 0)),
		"intel_after": int(updated_rival.get("intel", 0)),
		"control_after": int(updated_rival.get("control", 0)),
		"prestige_after": int(updated_rival.get("prestige", 0)),
		"rerolls_after": int(updated_rival.get("tactical_rerolls", 0)),
	}
	updated_rival["turns_taken"] = int(updated_rival.get("turns_taken", 0)) + 1
	var next_plan := _build_turn_plan(updated_rival, node_lookup)
	updated_rival["intent"] = _plan_text(next_plan)
	var full_line := move_text
	if not action_text.is_empty():
		full_line += " " + action_text
	updated_rival["latest_action"] = full_line.strip_edges()
	updated_rival["latest_action_short"] = String(action_report.get("short", "继续推进"))
	return {
		"player": updated_rival,
		"line": updated_rival["latest_action"],
		"short": updated_rival["latest_action_short"],
		"intent": updated_rival["intent"],
		"move": Dictionary(move_report.get("debug", {})).duplicate(true),
		"landing": landing_debug,
		"next_plan": Dictionary(next_plan).duplicate(true),
	}

func _resolve_move(rival: Dictionary, current_node_id: int, node_lookup: Dictionary, ideal_plan: Dictionary) -> Dictionary:
	var working := rival.duplicate(true)
	var roll := _deterministic_roll(working, "roll")
	var first_roll := roll
	var choice := _pick_destination(working, current_node_id, roll, node_lookup)
	var first_candidates: Array = Array(choice.get("candidates", [])).duplicate(true)
	var reroll_used := false
	var reroll_value := 0
	var reroll_candidates: Array = []
	var best_plan_score := float(ideal_plan.get("score", -999.0))
	var current_score := float(choice.get("score", -999.0))
	if int(working.get("tactical_rerolls", 0)) > 0 and best_plan_score - current_score >= REROLL_THRESHOLD:
		reroll_value = _deterministic_roll(working, "reroll")
		if reroll_value == roll:
			reroll_value = 1 + int(posmod(reroll_value + int(working.get("turns_taken", 0)) + 1, MAX_ROLL))
		var reroll_choice := _pick_destination(working, current_node_id, reroll_value, node_lookup)
		reroll_candidates = Array(reroll_choice.get("candidates", [])).duplicate(true)
		if float(reroll_choice.get("score", -999.0)) > current_score:
			reroll_used = true
			roll = reroll_value
			choice = reroll_choice
			working["tactical_rerolls"] = maxi(0, int(working.get("tactical_rerolls", 0)) - 1)
			current_score = float(choice.get("score", -999.0))
	working["last_roll"] = roll
	var text := ""
	if choice.is_empty():
		working["latest_action_short"] = "原地整备"
		working["latest_action"] = "%s 掷出 %d，但前方没有精确落点，只能继续整备。" % [
			String(working.get("display_name", "对手")),
			roll,
		]
		text = working["latest_action"]
		var current_node: Dictionary = Dictionary(node_lookup.get(current_node_id, {})).duplicate(true)
		return {
			"player": working,
			"text": text,
			"debug": {
				"first_roll": first_roll,
				"final_roll": roll,
				"reroll_used": reroll_used,
				"reroll_value": reroll_value,
				"destination_node_id": current_node_id,
				"destination_name": String(current_node.get("name", "当前位置")),
				"path": [],
				"path_names": [],
				"candidates": [],
				"first_candidates": first_candidates,
				"reroll_candidates": reroll_candidates,
				"score": current_score,
				"ideal_plan_text": String(ideal_plan.get("text", "")),
				"ideal_plan_score": best_plan_score,
				"rerolls_after": int(working.get("tactical_rerolls", 0)),
				"stayed_put": true,
			},
		}
	var destination_node_id := int(choice.get("node_id", current_node_id))
	var destination_node: Dictionary = choice.get("node", {})
	working["current_node_id"] = destination_node_id
	working["season_distance"] = maxi(int(working.get("season_distance", 0)), destination_node_id)
	var reroll_text := "，不满意首掷 %d，改掷 %d" % [first_roll, roll] if reroll_used else ""
	text = "%s 掷出 %d%s，推进到 %s。" % [
		String(working.get("display_name", "对手")),
		roll,
		reroll_text,
		String(destination_node.get("name", "未知节点")),
	]
	return {
		"player": working,
		"text": text,
		"destination_node_id": destination_node_id,
		"node": destination_node,
		"debug": {
			"first_roll": first_roll,
			"final_roll": roll,
			"reroll_used": reroll_used,
			"reroll_value": reroll_value,
			"destination_node_id": destination_node_id,
			"destination_name": String(destination_node.get("name", "")),
			"path": Array(choice.get("path", [])).duplicate(),
			"path_names": _path_node_names(Array(choice.get("path", [])).duplicate(), node_lookup),
			"candidates": Array(choice.get("candidates", [])).duplicate(true),
			"first_candidates": first_candidates,
			"reroll_candidates": reroll_candidates,
			"score": current_score,
			"ideal_plan_text": String(ideal_plan.get("text", "")),
			"ideal_plan_score": best_plan_score,
			"rerolls_after": int(working.get("tactical_rerolls", 0)),
			"stayed_put": false,
		},
	}

func _resolve_landing(rival: Dictionary, node: Dictionary) -> Dictionary:
	var working := rival.duplicate(true)
	if node.is_empty():
		working["gold"] = int(working.get("gold", 0)) + 1
		return {
			"player": working,
			"short": "原地整备",
			"text": "没有吃到有效落点，只能先整理补给并多攒 1 金。",
		}
	var node_name := String(node.get("name", "未知节点"))
	var legacy_type := _legacy_type_for_node(node)
	match legacy_type:
		"camp":
			var rest_gold := 1 + (1 if String(working.get("personality_id", "")) == "industrial" else 0)
			working["gold"] = int(working.get("gold", 0)) + rest_gold
			working["tactical_rerolls"] = mini(2, int(working.get("tactical_rerolls", 0)) + 1)
			return {
				"player": working,
				"short": "营地整备",
				"text": "在 %s 休整队伍，顺手补进 %d 金，并把战术重掷回充到 %d。" % [
					node_name,
					rest_gold,
					int(working.get("tactical_rerolls", 0)),
				],
			}
		"resource":
			var resource_gold := 2 + (1 if GameData.get_ai_weight(String(working.get("personality_id", "")), "resource") >= 5 else 0)
			working["gold"] = int(working.get("gold", 0)) + resource_gold
			if String(node.get("type", "")) == "habitat":
				working["control"] = int(working.get("control", 0)) + 1
			return {
				"player": working,
				"short": "收拢资源",
				"text": "在 %s 稳住补给线，带回 %d 金。" % [node_name, resource_gold],
			}
		"market":
			var trade_gold := 2 + (1 if int(working.get("gold", 0)) < 10 else 0)
			working["gold"] = int(working.get("gold", 0)) + trade_gold
			working["control"] = int(working.get("control", 0)) + 1
			return {
				"player": working,
				"short": "整顿补给",
				"text": "借 %s 的补给窗口净赚 %d 金，并顺手补了一层控制。" % [node_name, trade_gold],
			}
		"research":
			var intel_gain := 2 + (1 if GameData.get_ai_weight(String(working.get("personality_id", "")), "research") >= 5 else 0)
			working["intel"] = int(working.get("intel", 0)) + intel_gain
			return {
				"player": working,
				"short": "侦察研判",
				"text": "在 %s 抢到 %d 点情报，对后段路线的判断更准了。" % [node_name, intel_gain],
			}
		"control":
			var control_gain := 2 + (1 if String(node.get("type", "")) == "habitat" else 0)
			working["control"] = int(working.get("control", 0)) + control_gain
			working["prestige"] = int(working.get("prestige", 0)) + 1
			return {
				"player": working,
				"short": "夺控据点",
				"text": "在 %s 压住据点，控制 +%d，威望 +1。" % [node_name, control_gain],
			}
		"event":
			return _resolve_event_node(working, node_name)
		"battle":
			return _resolve_battle_node(working, node, false)
		"boss":
			return _resolve_battle_node(working, node, true)
		_:
			working["gold"] = int(working.get("gold", 0)) + 1
			return {
				"player": working,
				"short": "保持推进",
				"text": "在 %s 没有久留，顺手整合了 1 金补给。" % node_name,
			}

func _resolve_event_node(rival: Dictionary, node_name: String) -> Dictionary:
	var working := rival.duplicate(true)
	var personality_id := String(working.get("personality_id", ""))
	var economy_bias := GameData.get_ai_weight(personality_id, "resource") + GameData.get_ai_weight(personality_id, "market")
	var research_bias := GameData.get_ai_weight(personality_id, "research") + int(working.get("intel", 0))
	var conflict_bias := GameData.get_ai_weight(personality_id, "battle") + int(working.get("prestige", 0))
	if research_bias >= economy_bias and research_bias >= conflict_bias:
		working["intel"] = int(working.get("intel", 0)) + 2
		working["prestige"] = int(working.get("prestige", 0)) + 1
		return {
			"player": working,
			"short": "截获情报",
			"text": "在 %s 截到一手情报窗口，情报 +2，威望 +1。" % node_name,
		}
	if economy_bias >= conflict_bias:
		working["gold"] = int(working.get("gold", 0)) + 3
		working["control"] = int(working.get("control", 0)) + 1
		return {
			"player": working,
			"short": "套到机会",
			"text": "在 %s 把偶发机会兑现成了 3 金和 1 层控制。" % node_name,
		}
	working["prestige"] = int(working.get("prestige", 0)) + 2
	working["battle_wins"] = int(working.get("battle_wins", 0)) + 1
	return {
		"player": working,
		"short": "借势压人",
		"text": "在 %s 借势制造了压迫感，威望 +2。" % node_name,
	}

func _resolve_battle_node(rival: Dictionary, node: Dictionary, is_boss: bool) -> Dictionary:
	var working := rival.duplicate(true)
	var node_name := String(node.get("name", "未知节点"))
	var node_id := int(node.get("id", -1))
	var personality_id := String(working.get("personality_id", ""))
	var battle_weight := GameData.get_ai_weight(personality_id, "battle")
	var support_power := int(working.get("prestige", 0)) / 2 + int(working.get("control", 0)) / 2 + int(working.get("intel", 0)) / 3
	var roll := _deterministic_roll(working, "battle_%d" % node_id, 1, 6)
	var difficulty: int = 5 + int(GameState.get_node_danger(node_id))
	if String(node.get("type", "")) == "dojo":
		difficulty += 1
	if String(node.get("type", "")) == "anomaly":
		difficulty += 2
	if is_boss:
		difficulty += 3
	var total_power := battle_weight + support_power + roll
	if total_power >= difficulty + 2:
		var prestige_gain := 3 if is_boss else 2
		var gold_gain := 3 if is_boss else 1
		working["prestige"] = int(working.get("prestige", 0)) + prestige_gain
		working["gold"] = int(working.get("gold", 0)) + gold_gain
		working["battle_wins"] = int(working.get("battle_wins", 0)) + 1
		return {
			"player": working,
			"short": "赢下交锋" if not is_boss else "吃下赛季高潮",
			"text": "在 %s 的交锋里站住了，威望 +%d，金 +%d。" % [node_name, prestige_gain, gold_gain],
		}
	if total_power >= difficulty:
		working["prestige"] = int(working.get("prestige", 0)) + 1
		return {
			"player": working,
			"short": "试探换势",
			"text": "在 %s 试探了一轮，虽然没完全打穿，但还是换到了 1 点威望。" % node_name,
		}
	working["gold"] = maxi(0, int(working.get("gold", 0)) - 1)
	return {
		"player": working,
		"short": "试探后撤",
		"text": "在 %s 没能打穿正面压力，只能后撤并损失 1 金补给。" % node_name,
	}

func _build_turn_plan(rival: Dictionary, node_lookup: Dictionary) -> Dictionary:
	var current_node_id := int(rival.get("current_node_id", 0))
	var best_plan := {}
	for roll in range(1, MAX_ROLL + 1):
		var choice := _pick_destination(rival, current_node_id, roll, node_lookup)
		if choice.is_empty():
			continue
		if best_plan.is_empty() or float(choice.get("score", -999.0)) > float(best_plan.get("score", -999.0)):
			best_plan = choice
	if best_plan.is_empty():
		return {"text": "继续原地整备", "score": -999.0}
	var node := Dictionary(best_plan.get("node", {}))
	best_plan["text"] = "盯住 %s，准备%s" % [
		String(node.get("name", "前方节点")),
		_focus_text_for_node(node),
	]
	return best_plan

func _plan_text(plan: Dictionary) -> String:
	return String(plan.get("text", "继续观察局势"))

func _pick_destination(rival: Dictionary, current_node_id: int, roll: int, node_lookup: Dictionary) -> Dictionary:
	var paths := _reachable_paths(current_node_id, roll, node_lookup)
	var best_choice := {}
	var candidates: Array = []
	for raw_node_id in paths.keys():
		var node_id := int(raw_node_id)
		var node := Dictionary(node_lookup.get(node_id, {})).duplicate(true)
		if node.is_empty():
			continue
		var path: Array = Array(paths[raw_node_id]).duplicate()
		var legacy_type := _legacy_type_for_node(node, node_lookup)
		var score := _score_destination(rival, node, node_lookup)
		var candidate := {
			"node_id": node_id,
			"name": String(node.get("name", "未知节点")),
			"legacy_type": legacy_type,
			"danger": int(GameState.get_node_danger(node_id)),
			"path": path,
			"path_names": _path_node_names(path, node_lookup),
			"score": score,
		}
		candidates.append(candidate)
		if best_choice.is_empty() or score > float(best_choice.get("score", -999.0)) or (is_equal_approx(score, float(best_choice.get("score", -999.0))) and node_id > int(best_choice.get("node_id", -1))):
			best_choice = {
				"node_id": node_id,
				"path": path,
				"path_names": Array(candidate.get("path_names", [])).duplicate(),
				"node": node,
				"score": score,
				"legacy_type": legacy_type,
				"danger": int(candidate.get("danger", 0)),
			}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.get("score", -999.0))
		var b_score := float(b.get("score", -999.0))
		if not is_equal_approx(a_score, b_score):
			return a_score > b_score
		return int(a.get("node_id", -1)) > int(b.get("node_id", -1))
	)
	if not best_choice.is_empty():
		best_choice["candidates"] = candidates.duplicate(true)
	return best_choice

func _reachable_paths(from_node_id: int, steps: int, node_lookup: Dictionary) -> Dictionary:
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
		for neighbor_id in _neighbors(current_id, node_lookup):
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

func _path_node_names(path: Array, node_lookup: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_node_id in path:
		var node_id := int(raw_node_id)
		names.append(String(node_lookup.get(node_id, {}).get("name", "节点 %d" % node_id)))
	return names

func _score_destination(rival: Dictionary, node: Dictionary, node_lookup: Dictionary) -> float:
	var personality_id := String(rival.get("personality_id", ""))
	var legacy_type := _legacy_type_for_node(node, node_lookup)
	var node_id := int(node.get("id", -1))
	var score := float(GameData.get_ai_weight(personality_id, legacy_type))
	var danger := float(GameState.get_node_danger(node_id))
	var gold := float(rival.get("gold", 0))
	var prestige := float(rival.get("prestige", 0))
	var intel := float(rival.get("intel", 0))
	var control := float(rival.get("control", 0))
	match legacy_type:
		"resource":
			score += 1.6 if gold < 14.0 else 0.6
		"market":
			score += 1.2 if gold < 10.0 else 0.4
		"research":
			score += 1.5 if intel <= control + 1.0 else 0.5
		"control":
			score += 1.7 if control <= prestige + 1.0 else 0.6
		"battle":
			score += 0.5 * danger if GameData.get_ai_weight(personality_id, "battle") >= 4 else -0.35 * danger
		"boss":
			score += 2.5 + prestige * 0.15
		"camp":
			score += 2.0 if int(rival.get("tactical_rerolls", 0)) <= 0 else 0.3
		"event":
			score += 1.0 + intel * 0.08
	var boss_distance := maxi(0, _boss_node_id(node_lookup) - node_id)
	score += float(MAX_ROLL - mini(MAX_ROLL, boss_distance)) * 0.08
	return score

func _legacy_type_for_node(node: Dictionary, node_lookup: Dictionary = {}) -> String:
	var type_id := String(node.get("type", ""))
	match type_id:
		"camp":
			return "camp"
		"event":
			return "event"
		"settlement":
			return "market"
		"dojo":
			return "battle"
		"anomaly":
			if not node_lookup.is_empty() and int(node.get("id", -1)) == _boss_node_id(node_lookup):
				return "boss"
			if String(node.get("focus", "")).contains("赛季高潮") or String(node.get("reward_hint", "")).contains("赛季高潮"):
				return "boss"
			return "battle"
		"environment":
			var environment_kind := String(node.get("environment_kind", "forage"))
			match environment_kind:
				"forage":
					return "resource"
				"scout":
					return "research"
				"wild_battle":
					return "battle"
				_:
					return "event"
		"habitat":
			var primary_content := String(node.get("primary_content", "observe"))
			match primary_content:
				"build_menu", "resident_menu":
					return "control"
				"npc_menu", "mail_menu":
					return "market"
				"observe", "quest_menu":
					return "research"
				_:
					return "resource"
		_:
			return "resource"

func _focus_text_for_node(node: Dictionary) -> String:
	match _legacy_type_for_node(node):
		"camp":
			return "回营补给"
		"resource":
			return "补足资源"
		"market":
			return "盘活补给"
		"research":
			return "抢情报"
		"control":
			return "压据点"
		"battle":
			return "试探交锋"
		"boss":
			return "冲赛季高潮"
		"event":
			return "截机会"
		_:
			return "继续推进"

func _format_lineup_text(rival: Dictionary) -> String:
	var parts: Array[String] = []
	for species_id in rival.get("lineup", []):
		var species := DataRepository.get_species(String(species_id))
		parts.append(String(species.get("name", species_id)))
	if parts.is_empty():
		return "未记录阵容"
	return " / ".join(parts)

func _player_score(rival: Dictionary) -> float:
	return float(
		int(rival.get("prestige", 0)) * 4
		+ int(rival.get("control", 0)) * 3
		+ int(rival.get("intel", 0)) * 2
		+ int(rival.get("season_distance", 0))
		+ int(rival.get("gold", 0))
	)

func _boss_node_id(node_lookup: Dictionary) -> int:
	var max_node_id := 0
	for raw_node_id in node_lookup.keys():
		max_node_id = maxi(max_node_id, int(raw_node_id))
	return max_node_id

func _neighbors(node_id: int, node_lookup: Dictionary) -> Array[int]:
	var neighbors: Array[int] = []
	var node: Dictionary = node_lookup.get(node_id, {})
	for raw_neighbor in node.get("edges", []):
		var next_id := int(raw_neighbor)
		if not neighbors.has(next_id):
			neighbors.append(next_id)
	return neighbors

func _deterministic_roll(rival: Dictionary, salt: String, min_value: int = 1, max_value: int = MAX_ROLL) -> int:
	var rng := RandomNumberGenerator.new()
	var seed_text := "%s|%s|%d|%d|%d" % [
		String(rival.get("id", "")),
		salt,
		GameState.global_turn,
		GameState.week_index,
		int(rival.get("turns_taken", 0)),
	]
	rng.seed = seed_text.hash()
	return rng.randi_range(min_value, max_value)

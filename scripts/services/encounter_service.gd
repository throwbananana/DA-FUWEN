class_name EncounterService
extends RefCounted

## 负责把“战斗/捕捉”改成“观察/安抚/结缘”的前置流程。

func roll_encounter(habitat_id: String, source: String = "observe") -> Dictionary:
	var valid_entries := build_weighted_entries(habitat_id, source)
	return _roll_from_entries(valid_entries, source)

func roll_custom_entries(entries: Array, source: String = "observe") -> Dictionary:
	var valid_entries := build_weighted_entries_from_rows(entries, source)
	return _roll_from_entries(valid_entries, source)

func _roll_from_entries(valid_entries: Array, source: String) -> Dictionary:
	if valid_entries.is_empty():
		return {"ok": false, "reason": "no_encounter", "source": source}
	var chosen := _weighted_pick(valid_entries)
	var species_id := String(chosen.get("species_id", ""))
	var mood_id := String(chosen.get("mood", "curious"))
	return {
		"ok": true,
		"species_id": species_id,
		"species": DataRepository.get_species(species_id),
		"mood_id": mood_id,
		"bond_window": _estimate_bond_window(mood_id),
		"source": source,
		"selection_reasons": _build_selection_reasons(chosen, source),
	}

func build_weighted_entries(habitat_id: String, source: String = "observe") -> Array:
	var habitat_encounters: Dictionary = DataRepository.encounters.get(habitat_id, {})
	var groups: Array = habitat_encounters.get("weight_groups", [])
	var base_entries: Array = []
	for group in groups:
		if _matches_condition(group.get("when", {})):
			base_entries.append_array(group.get("entries", []))
	return build_weighted_entries_from_rows(base_entries, source)

func build_weighted_entries_from_rows(entries: Array, source: String = "observe") -> Array:
	var valid_entries: Array = []
	valid_entries.append_array(_filter_entries_by_progression(entries))
	valid_entries = _apply_shop_odds(valid_entries)
	return _apply_source_biases(valid_entries, source)

func _filter_entries_by_progression(entries: Array) -> Array:
	var filtered: Array = []
	var progression_rank: int = GameState.get_progression_rank()
	for entry in entries:
		var species_id := String(entry.get("species_id", ""))
		var species := DataRepository.get_species(species_id)
		if species.is_empty():
			continue
		if int(species.get("unlock_rank", 1)) > progression_rank:
			continue
		filtered.append(entry)
	if filtered.is_empty():
		return entries.duplicate(true)
	return filtered

func _apply_shop_odds(entries: Array) -> Array:
	var adjusted: Array = []
	var odds: Dictionary = DataRepository.get_shop_odds_entry(GameState.get_progression_rank())
	for entry in entries:
		var species_id := String(entry.get("species_id", ""))
		var species := DataRepository.get_species(species_id)
		if species.is_empty():
			continue
		var rarity := String(species.get("rarity", "common"))
		var rarity_factor := float(odds.get(rarity, 1.0))
		var effective_weight := int(round(float(entry.get("weight", 0)) * rarity_factor * 100.0))
		if effective_weight <= 0:
			continue
		var adjusted_entry: Dictionary = entry.duplicate(true)
		adjusted_entry["effective_weight"] = effective_weight
		adjusted_entry["weight_breakdown"] = {
			"base_weight": int(entry.get("weight", 0)),
			"rarity": rarity,
			"rarity_factor": rarity_factor,
			"after_rarity_weight": effective_weight,
			"source_factor": 1.0,
			"final_weight": effective_weight,
		}
		adjusted.append(adjusted_entry)
	if adjusted.is_empty():
		for entry in entries:
			var fallback_entry: Dictionary = entry.duplicate(true)
			var fallback_weight := int(entry.get("weight", 0))
			fallback_entry["effective_weight"] = fallback_weight
			fallback_entry["weight_breakdown"] = {
				"base_weight": fallback_weight,
				"rarity": "",
				"rarity_factor": 1.0,
				"after_rarity_weight": fallback_weight,
				"source_factor": 1.0,
				"final_weight": fallback_weight,
			}
			adjusted.append(fallback_entry)
	return adjusted

func _apply_source_biases(entries: Array, source: String) -> Array:
	if source.is_empty() or source == "observe":
		return entries
	var adjusted: Array = []
	for entry in entries:
		var adjusted_entry: Dictionary = entry.duplicate(true)
		var species_id := String(adjusted_entry.get("species_id", ""))
		var species := DataRepository.get_species(species_id)
		if species.is_empty():
			adjusted.append(adjusted_entry)
			continue
		var factor := _source_bias_factor(species, source)
		var base_weight := int(adjusted_entry.get("effective_weight", adjusted_entry.get("weight", 0)))
		var final_weight := maxi(1, int(round(float(base_weight) * factor)))
		var breakdown: Dictionary = Dictionary(adjusted_entry.get("weight_breakdown", {})).duplicate(true)
		breakdown["source"] = source
		breakdown["source_factor"] = factor
		breakdown["final_weight"] = final_weight
		adjusted_entry["weight_breakdown"] = breakdown
		adjusted_entry["source_bias_reason"] = _source_bias_reason(species, source, factor)
		adjusted_entry["effective_weight"] = final_weight
		adjusted.append(adjusted_entry)
	return adjusted

func get_available_actions(encounter: Dictionary) -> Array:
	var mood_id := String(encounter.get("mood_id", "curious"))
	match mood_id:
		"fearful":
			return ["calm", "feed", "retreat", "shelter"]
		"hungry":
			return ["feed", "observe", "guide"]
		"lively", "playful":
			return ["guide", "observe", "feed"]
		"kind", "gentle", "placid", "calm":
			return ["observe", "calm", "feed"]
		"steady", "patient", "slow":
			return ["observe", "calm", "shelter"]
		"protective", "stubborn":
			return ["calm", "retreat", "observe"]
		"sly", "smooth":
			return ["observe", "guide", "retreat"]
		"alert", "guarded", "wild":
			return ["observe", "retreat", "calm"]
		"fragile", "cold":
			return ["hum", "calm", "shelter"]
		_:
			return ["observe", "feed", "calm", "guide"]

func describe_action(encounter: Dictionary, action_id: String) -> String:
	var evaluation := _evaluate_action(encounter, action_id)
	if evaluation.is_empty():
		return "先按当前气氛做一次温和尝试。"
	if String(evaluation.get("outcome", "")) == "safe_leave":
		return "先拉开距离，稳稳结束这次相遇。"
	var parts: Array[String] = []
	if bool(evaluation.get("mood_match", false)):
		parts.append("这一步比较顺着它现在的情绪。")
	else:
		parts.append("这一步偏试探，成不成更看窗口。")
	match int(evaluation.get("window_adjustment", 0)):
		1:
			parts.append("它现在愿意多停一会。")
		-1:
			parts.append("它现在很警惕，别太冒进。")
		_:
			parts.append("窗口普通，先求稳。")
	match String(evaluation.get("outcome", "")):
		"bond_success":
			parts.append("顺的话能直接建立联系。")
		"bond_progress":
			parts.append("更常见的是先把关系往前推一步。")
		"alert_rise":
			parts.append("踩偏了就会让它更警惕。")
	return " ".join(parts)

func resolve_action(encounter: Dictionary, action_id: String) -> Dictionary:
	var evaluation := _evaluate_action(encounter, action_id)
	if evaluation.is_empty():
		return {"ok": false, "reason": "encounter_missing"}
	var result := {
		"ok": true,
		"outcome": String(evaluation.get("outcome", "safe_leave")),
		"bond_delta": int(evaluation.get("bond_delta", 0)),
		"reason_lines": _build_result_reason_lines(evaluation),
	}
	if evaluation.has("combat_risk"):
		result["combat_risk"] = int(evaluation.get("combat_risk", 0))
	return result

func _evaluate_action(encounter: Dictionary, action_id: String) -> Dictionary:
	var mood_id := String(encounter.get("mood_id", "curious"))
	var bond_window := String(encounter.get("bond_window", "medium"))
	var base_score := 0
	var mood_match := false
	match action_id:
		"feed":
			mood_match = mood_id in ["hungry", "fearful", "curious", "gentle", "placid", "steady"]
			base_score += 2 if mood_match else 0
		"calm":
			mood_match = mood_id in ["fearful", "alert", "wild", "guarded", "protective", "stubborn", "patient", "calm"]
			base_score += 2 if mood_match else 1
		"observe":
			mood_match = mood_id in ["kind", "steady", "patient", "slow", "sly"]
			base_score += 2 if mood_match else 1
		"hum":
			mood_match = mood_id in ["fragile", "cold"]
			base_score += 2 if mood_match else 0
		"shelter":
			mood_match = mood_id in ["fearful", "cold", "steady", "patient"]
			base_score += 2 if mood_match else 0
		"guide":
			mood_match = mood_id in ["curious", "hungry", "lively", "playful", "smooth"]
			base_score += 2 if mood_match else 0
		"retreat":
			return {
				"outcome": "safe_leave",
				"bond_delta": 0,
				"action_id": action_id,
				"mood_id": mood_id,
				"bond_window": bond_window,
				"mood_match": true,
				"base_score": 0,
				"window_adjustment": 0,
			}
		_:
			return {}
	var window_adjustment := 0
	if bond_window == "high":
		window_adjustment = 1
	elif bond_window == "low":
		window_adjustment = -1
	var score := base_score + window_adjustment
	var result := {
		"outcome": "alert_rise",
		"bond_delta": 0,
		"action_id": action_id,
		"mood_id": mood_id,
		"bond_window": bond_window,
		"mood_match": mood_match,
		"base_score": base_score,
		"window_adjustment": window_adjustment,
		"score": score,
	}
	if score >= 3:
		result["outcome"] = "bond_success"
		result["bond_delta"] = 2
	elif score == 2:
		result["outcome"] = "bond_progress"
		result["bond_delta"] = 1
	else:
		result["combat_risk"] = 1
	return result

func _build_result_reason_lines(evaluation: Dictionary) -> Array[String]:
	var outcome := String(evaluation.get("outcome", ""))
	if outcome == "safe_leave":
		return ["你主动收了一步，没有继续刺激它。"]
	var lines: Array[String] = []
	if bool(evaluation.get("mood_match", false)):
		lines.append("这一步顺着它现在的情绪。")
	else:
		lines.append("这一步没有完全踩中它现在的情绪。")
	match int(evaluation.get("window_adjustment", 0)):
		1:
			lines.append("这会儿它愿意多停一会，所以结果更顺。")
		-1:
			lines.append("它这会儿很警惕，所以容错更低。")
		_:
			lines.append("这次结缘窗口普通，成败主要看动作是否合拍。")
	match outcome:
		"bond_success":
			lines.append("你把节奏踩准了，它愿意继续靠近。")
		"bond_progress":
			lines.append("虽然还没完全放下戒备，但关系已经往前推进了一步。")
		"alert_rise":
			lines.append("它还是更紧张了一些，这里也会因此变得更危险。")
	return lines

func _build_selection_reasons(entry: Dictionary, source: String) -> Array[String]:
	var lines: Array[String] = []
	var breakdown: Dictionary = Dictionary(entry.get("weight_breakdown", {})).duplicate(true)
	var base_weight := int(breakdown.get("base_weight", entry.get("weight", 0)))
	var rarity := String(breakdown.get("rarity", ""))
	var rarity_factor := float(breakdown.get("rarity_factor", 1.0))
	var source_factor := float(breakdown.get("source_factor", 1.0))
	var final_weight := int(breakdown.get("final_weight", entry.get("effective_weight", base_weight)))
	lines.append("基础生态权重 %d，当前实际权重 %d。" % [base_weight, final_weight])
	if not rarity.is_empty() and absf(rarity_factor - 1.0) > 0.01:
		lines.append("按你当前推进阶段，%s个体会吃到 %.2f 倍稀有度修正。" % [_rarity_label(rarity), rarity_factor])
	if source.is_empty() or source == "observe":
		lines.append("这次按地点本身的观察池来抽取。")
	elif absf(source_factor - 1.0) > 0.01:
		lines.append(_source_bias_reason(Dictionary(entry.get("species", {})), source, source_factor))
	return lines

func _source_bias_reason(species: Dictionary, source: String, factor: float) -> String:
	if absf(factor - 1.0) <= 0.01:
		return "这次来源没有明显偏压。"
	var species_name := String(species.get("name", "这类个体"))
	return "%s 与“%s”这条线索更贴，所以额外吃到 %.2f 倍来源修正。" % [species_name, _source_label(source), factor]

func _source_label(source: String) -> String:
	match source:
		"observe":
			return "基础观察"
		"ambush":
			return "潜伏袭扰"
		"nursery_watch":
			return "孵育观察"
		"nursery_rare_watch":
			return "稀有孵育观察"
		"waterside_lure":
			return "水边诱引"
		"waterside_rare":
			return "稀有水边诱引"
		"route_tip":
			return "路线线索"
		"anomaly_watch":
			return "异常观测"
		"anomaly_rare_watch":
			return "稀有异常观测"
		"echo_watch":
			return "回响观察"
		"echo_rare_watch":
			return "稀有回响观察"
		_:
			return source

func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "常见"
		"uncommon":
			return "少见"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return rarity

func _matches_condition(condition: Dictionary) -> bool:
	for key in condition.keys():
		var expected = condition[key]
		match String(key):
			"season":
				if GameState.season_id != String(expected):
					return false
			"weather":
				if GameState.weather_id != String(expected):
					return false
			"time":
				if GameState.time_of_day != String(expected):
					return false
			"anomaly":
				# 这里可接你的异常强度系统
				if String(expected) != "high":
					return false
	return true

func _estimate_bond_window(mood_id: String) -> String:
	match mood_id:
		"curious", "hungry":
			return "high"
		"fearful", "fragile", "cold":
			return "medium"
		"alert", "guarded", "wild":
			return "low"
		_:
			return "medium"

func _source_bias_factor(species: Dictionary, source: String) -> float:
	var resident_tags: Array = species.get("resident_tags", [])
	var habitat_preferences: Array = species.get("habitat_preferences", [])
	var trait_tags: Array = species.get("trait_tags", [])
	var rarity := String(species.get("rarity", "common"))
	var temperament := String(species.get("temperament", ""))
	var factor := 1.0
	match source:
		"nursery_watch":
			if _array_contains_any(resident_tags, ["nursery", "moss", "calm"]):
				factor *= 1.8
			if temperament in ["gentle", "curious", "fearful"]:
				factor *= 1.2
		"nursery_rare_watch":
			if _array_contains_any(resident_tags, ["nursery", "moss", "calm"]):
				factor *= 1.6
			if rarity in ["rare", "epic"]:
				factor *= 1.6
		"waterside_lure":
			if _array_contains_any(resident_tags, ["water", "cleaner"]) or habitat_preferences.has("waterside"):
				factor *= 1.9
		"waterside_rare":
			if _array_contains_any(resident_tags, ["water", "cleaner"]) or habitat_preferences.has("waterside"):
				factor *= 1.6
			if rarity in ["uncommon", "rare", "epic"]:
				factor *= 1.35
		"route_tip":
			if _array_contains_any(trait_tags, ["pathfinder"]) or _array_contains_any(resident_tags, ["messenger", "speed"]):
				factor *= 1.8
		"anomaly_watch":
			if _array_contains_any(habitat_preferences, ["anomaly", "ruin", "night"]) or _array_contains_any(resident_tags, ["light", "echo", "machine"]):
				factor *= 1.8
		"anomaly_rare_watch":
			if _array_contains_any(habitat_preferences, ["anomaly", "ruin", "night"]) or _array_contains_any(resident_tags, ["light", "echo", "machine"]):
				factor *= 1.5
			if rarity in ["rare", "epic"]:
				factor *= 1.5
		"echo_watch":
			if _array_contains_any(resident_tags, ["echo", "light", "calm"]):
				factor *= 1.9
		"echo_rare_watch":
			if _array_contains_any(resident_tags, ["echo", "light", "calm"]):
				factor *= 1.5
			if rarity in ["rare", "epic"]:
				factor *= 1.6
	return factor

func _array_contains_any(values: Array, expected: Array) -> bool:
	for item in values:
		if expected.has(item):
			return true
	return false

func _weighted_pick(entries: Array) -> Dictionary:
	var total := 0
	for entry in entries:
		total += int(entry.get("effective_weight", entry.get("weight", 0)))
	if total <= 0:
		return entries[0] if not entries.is_empty() else {}
	var roll := randi() % total
	var cursor := 0
	for entry in entries:
		cursor += int(entry.get("effective_weight", entry.get("weight", 0)))
		if roll < cursor:
			return entry
	return entries[-1]

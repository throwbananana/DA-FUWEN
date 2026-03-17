class_name EncounterService
extends RefCounted

## 负责把“战斗/捕捉”改成“观察/安抚/结缘”的前置流程。

func roll_encounter(habitat_id: String) -> Dictionary:
	var valid_entries := build_weighted_entries(habitat_id)
	if valid_entries.is_empty():
		return {"ok": false, "reason": "no_encounter"}

	var chosen := _weighted_pick(valid_entries)
	var species_id := String(chosen.get("species_id", ""))
	var mood_id := String(chosen.get("mood", "curious"))

	return {
		"ok": true,
		"species_id": species_id,
		"species": DataRepository.get_species(species_id),
		"mood_id": mood_id,
		"bond_window": _estimate_bond_window(mood_id)
	}

func build_weighted_entries(habitat_id: String) -> Array:
	var habitat_encounters: Dictionary = DataRepository.encounters.get(habitat_id, {})
	var groups: Array = habitat_encounters.get("weight_groups", [])
	var valid_entries: Array = []
	for group in groups:
		if _matches_condition(group.get("when", {})):
			valid_entries.append_array(_filter_entries_by_progression(group.get("entries", [])))
	return _apply_shop_odds(valid_entries)

func _filter_entries_by_progression(entries: Array) -> Array:
	var filtered: Array = []
	var progression_rank := GameState.get_progression_rank()
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
		adjusted.append(adjusted_entry)
	if adjusted.is_empty():
		for entry in entries:
			var fallback_entry: Dictionary = entry.duplicate(true)
			fallback_entry["effective_weight"] = int(entry.get("weight", 0))
			adjusted.append(fallback_entry)
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

func resolve_action(encounter: Dictionary, action_id: String) -> Dictionary:
	var mood_id := String(encounter.get("mood_id", "curious"))
	var bond_window := String(encounter.get("bond_window", "medium"))

	var score := 0
	match action_id:
		"feed":
			score += 2 if mood_id in ["hungry", "fearful", "curious", "gentle", "placid", "steady"] else 0
		"calm":
			score += 2 if mood_id in ["fearful", "alert", "wild", "guarded", "protective", "stubborn", "patient", "calm"] else 1
		"observe":
			score += 2 if mood_id in ["kind", "steady", "patient", "slow", "sly"] else 1
		"hum":
			score += 2 if mood_id in ["fragile", "cold"] else 0
		"shelter":
			score += 2 if mood_id in ["fearful", "cold", "steady", "patient"] else 0
		"guide":
			score += 2 if mood_id in ["curious", "hungry", "lively", "playful", "smooth"] else 0
		"retreat":
			return {"ok": true, "outcome": "safe_leave", "bond_delta": 0}

	if bond_window == "high":
		score += 1
	elif bond_window == "low":
		score -= 1

	if score >= 3:
		return {"ok": true, "outcome": "bond_success", "bond_delta": 2}
	elif score == 2:
		return {"ok": true, "outcome": "bond_progress", "bond_delta": 1}
	else:
		return {"ok": true, "outcome": "alert_rise", "bond_delta": 0, "combat_risk": 1}

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

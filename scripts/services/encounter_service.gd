class_name EncounterService
extends RefCounted

## 负责把“战斗/捕捉”改成“观察/安抚/结缘”的前置流程。

func roll_encounter(habitat_id: String) -> Dictionary:
	var habitat_encounters: Dictionary = DataRepository.encounters.get(habitat_id, {})
	var groups: Array = habitat_encounters.get("weight_groups", [])
	var valid_entries: Array = []

	for group in groups:
		if _matches_condition(group.get("when", {})):
			valid_entries.append_array(group.get("entries", []))

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

func get_available_actions(encounter: Dictionary) -> Array:
	var mood_id := String(encounter.get("mood_id", "curious"))
	match mood_id:
		"fearful":
			return ["calm", "feed", "retreat", "shelter"]
		"hungry":
			return ["feed", "observe", "guide"]
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
			score += 2 if mood_id in ["hungry", "fearful", "curious"] else 0
		"calm":
			score += 2 if mood_id in ["fearful", "alert", "wild", "guarded"] else 1
		"observe":
			score += 1
		"hum":
			score += 2 if mood_id in ["fragile", "cold"] else 0
		"shelter":
			score += 2 if mood_id in ["fearful", "cold"] else 0
		"guide":
			score += 2 if mood_id in ["curious", "hungry"] else 0
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
		total += int(entry.get("weight", 0))
	if total <= 0:
		return entries[0] if not entries.is_empty() else {}

	var roll := randi() % total
	var cursor := 0
	for entry in entries:
		cursor += int(entry.get("weight", 0))
		if roll < cursor:
			return entry
	return entries[-1]

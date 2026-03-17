class_name HabitatService
extends RefCounted

## 处理据点驻守、建造、据点成长。
## 这里假设存在 DataRepository / GameState 两个 AutoLoad。

func assign_resident(habitat_id: String, pet_uid: String, as_assistant: bool = false) -> Dictionary:
	var habitat = DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return {"ok": false, "reason": "habitat_missing"}

	var state: Dictionary = GameState.habitats.get(habitat_id, {})
	if state.is_empty():
		return {"ok": false, "reason": "habitat_state_missing"}

	if not GameState.pet_states.has(pet_uid):
		return {"ok": false, "reason": "pet_missing"}

	var previous_home := String(GameState.get_pet(pet_uid).get("residence_habitat_id", ""))
	if not previous_home.is_empty() and GameState.habitats.has(previous_home):
		var previous_state: Dictionary = GameState.habitats[previous_home]
		if String(previous_state.get("resident_uid", "")) == pet_uid:
			previous_state["resident_uid"] = ""
		if String(previous_state.get("assistant_uid", "")) == pet_uid:
			previous_state["assistant_uid"] = ""
		GameState.habitats[previous_home] = previous_state

	if as_assistant:
		state["assistant_uid"] = pet_uid
	else:
		var displaced_uid := String(state.get("resident_uid", ""))
		if not displaced_uid.is_empty() and displaced_uid != pet_uid:
			GameState.clear_pet_residence(displaced_uid)
		state["resident_uid"] = pet_uid
	GameState.habitats[habitat_id] = state
	GameState.set_pet_residence(pet_uid, habitat_id)

	return {
		"ok": true,
		"habitat_id": habitat_id,
		"pet_uid": pet_uid,
		"preference_match": _resident_matches_preferences(habitat_id, pet_uid),
	}

func can_build(habitat_id: String, building_id: String) -> Dictionary:
	var building = DataRepository.get_building(building_id)
	if building.is_empty():
		return {"ok": false, "reason": "building_missing"}

	if String(building.get("site", "")) != habitat_id:
		return {"ok": false, "reason": "site_mismatch"}

	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	var resident_uid := String(habitat_state.get("resident_uid", ""))
	if resident_uid.is_empty() and DataRepository.get_habitat(habitat_id).get("type", "") == "habitat":
		return {"ok": false, "reason": "resident_required"}

	var current_level := GameState.get_building_level(habitat_id, building_id)
	var levels: Array = _building_levels(building)
	if current_level >= levels.size():
		return {"ok": false, "reason": "max_level"}

	var next_level: Dictionary = levels[current_level]
	var cost: Dictionary = _normalize_cost(next_level.get("cost", {}))
	if not GameState.can_pay(cost):
		return {"ok": false, "reason": "insufficient_items", "cost": cost}

	return {"ok": true, "next_level": current_level + 1, "cost": cost, "effects": next_level.get("effects", [])}

func build_on_site(habitat_id: String, building_id: String) -> Dictionary:
	var check := can_build(habitat_id, building_id)
	if not bool(check.get("ok", false)):
		return check

	if not GameState.pay_cost(check.get("cost", {})):
		return {"ok": false, "reason": "payment_failed"}

	var new_level := int(check.get("next_level", 1))
	GameState.set_building_level(habitat_id, building_id, new_level)
	GameState.note_build(building_id, new_level)
	_refresh_habitat_rank(habitat_id)

	return {
		"ok": true,
		"habitat_id": habitat_id,
		"building_id": building_id,
		"level": new_level,
		"effects": check.get("effects", [])
	}

func _refresh_habitat_rank(habitat_id: String) -> void:
	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	var building_levels: Dictionary = habitat_state.get("building_levels", {})
	var total := 0
	for level in building_levels.values():
		total += int(level)
	habitat_state["rank"] = total
	GameState.habitats[habitat_id] = habitat_state

func get_visit_summary(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	var state: Dictionary = GameState.habitats.get(habitat_id, {})
	var resident_uid := String(state.get("resident_uid", ""))
	return {
		"habitat": habitat,
		"state": state,
		"buildings": DataRepository.get_buildings_for_habitat(habitat_id),
		"npcs": DataRepository.get_habitat_npcs(habitat_id),
		"resident": GameState.get_pet(resident_uid) if not resident_uid.is_empty() else {},
		"access": get_access_report(habitat_id),
		"dojo": DataRepository.get_dojo(String(habitat.get("dojo_id", ""))),
	}

func get_access_report(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	var status := GameState.get_habitat_unlock_status(habitat_id)
	return {
		"habitat_id": habitat_id,
		"open": bool(status.get("open", false)),
		"unlock_text": String(status.get("unlock_text", "")),
		"reasons": status.get("reasons", []).duplicate(),
		"recommended_rank": int(habitat.get("recommended_rank", 0)),
		"flow_band": String(habitat.get("flow_band", "")),
		"seasonal_events": habitat.get("seasonal_events", []).duplicate(),
	}

func _resident_matches_preferences(habitat_id: String, pet_uid: String) -> bool:
	var habitat := DataRepository.get_habitat(habitat_id)
	var pet := GameState.get_pet(pet_uid)
	var preferences: Array = habitat.get("resident_preferences", [])
	var resident_tags: Array = pet.get("resident_tags", [])
	for tag in resident_tags:
		if preferences.has(tag):
			return true
	return preferences.is_empty()

func _building_levels(building: Dictionary) -> Array:
	if building.has("levels"):
		return building.get("levels", [])
	var effects: Array[String] = []
	var resonance_effects: Dictionary = building.get("resonance_effects", {})
	effects.append_array(resonance_effects.get("pre_battle", []))
	effects.append_array(resonance_effects.get("growth", []))
	effects.append_array(resonance_effects.get("economy", []))
	if effects.is_empty():
		effects.append("建筑共鸣已激活")
	return [{
		"level": 1,
		"cost": building.get("construction_cost", {}),
		"effects": effects,
	}]

func _normalize_cost(cost: Dictionary) -> Dictionary:
	var normalized := {}
	var alias_map := {
		"stone": "stone_chip",
		"ore": "parts",
	}
	for item_id in cost.keys():
		var target_id := String(alias_map.get(String(item_id), String(item_id)))
		normalized[target_id] = int(normalized.get(target_id, 0)) + int(cost[item_id])
	return normalized

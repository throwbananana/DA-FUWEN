class_name HabitatService
extends RefCounted

## 处理据点驻守、建造、据点成长。
## 这里假设存在 DataRepository / GameState 两个 AutoLoad。

const NpcRouteServiceScript = preload("res://scripts/services/npc_route_service.gd")
const BuildingInteractionServiceScript = preload("res://scripts/services/building_interaction_service.gd")

var npc_route_service = NpcRouteServiceScript.new()
var building_interaction_service = BuildingInteractionServiceScript.new()

const PLAYER_ACTOR_ID := "player_main"
const PLAYER_ACTOR_TYPE := "player"
const PET_ACTOR_TYPE := "pet"

func assign_resident(habitat_id: String, actor_id: String, as_assistant: bool = false) -> Dictionary:
	var habitat = DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return {"ok": false, "reason": "habitat_missing"}

	var state: Dictionary = GameState.habitats.get(habitat_id, {})
	if state.is_empty():
		return {"ok": false, "reason": "habitat_state_missing"}

	var actor := _resolve_guard_actor(actor_id)
	if actor.is_empty():
		return {"ok": false, "reason": "pet_missing"}

	var actor_type := String(actor.get("type", PET_ACTOR_TYPE))
	var normalized_actor_id := String(actor.get("id", actor_id))

	if as_assistant and actor_type != PET_ACTOR_TYPE:
		return {"ok": false, "reason": "assistant_pet_only"}

	_clear_previous_residence_for_actor(actor_type, normalized_actor_id)

	if as_assistant:
		state["assistant_uid"] = normalized_actor_id
	else:
		var displaced_actor_type := String(state.get("resident_actor_type", ""))
		var displaced_actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		if displaced_actor_type.is_empty() and not displaced_actor_id.is_empty():
			displaced_actor_type = PET_ACTOR_TYPE
		if not displaced_actor_id.is_empty() and displaced_actor_id != normalized_actor_id:
			if displaced_actor_type == PET_ACTOR_TYPE:
				GameState.clear_pet_residence(displaced_actor_id)
		_set_resident_actor_state(state, actor_type, normalized_actor_id)

	GameState.habitats[habitat_id] = state
	if actor_type == PET_ACTOR_TYPE:
		GameState.set_pet_residence(normalized_actor_id, habitat_id)

	return {
		"ok": true,
		"habitat_id": habitat_id,
		"actor_id": normalized_actor_id,
		"actor_type": actor_type,
		"pet_uid": normalized_actor_id if actor_type == PET_ACTOR_TYPE else "",
		"preference_match": _resident_matches_preferences(habitat_id, normalized_actor_id),
	}

func _resolve_guard_actor(actor_id: String) -> Dictionary:
	if GameState.is_player_actor_id(actor_id):
		return {
			"type": PLAYER_ACTOR_TYPE,
			"id": PLAYER_ACTOR_ID,
			"profile": GameState.get_player_profile(),
		}
	if GameState.pet_states.has(actor_id):
		return {
			"type": PET_ACTOR_TYPE,
			"id": actor_id,
			"profile": GameState.get_pet(actor_id),
		}
	return {}

func _clear_previous_residence_for_actor(actor_type: String, actor_id: String) -> void:
	if actor_id.is_empty():
		return
	if actor_type == PET_ACTOR_TYPE:
		var previous_home := String(GameState.get_pet(actor_id).get("residence_habitat_id", ""))
		if not previous_home.is_empty() and GameState.habitats.has(previous_home):
			var previous_state: Dictionary = GameState.habitats[previous_home]
			if String(previous_state.get("resident_uid", "")) == actor_id:
				previous_state["resident_uid"] = ""
			if String(previous_state.get("resident_actor_id", "")) == actor_id:
				previous_state["resident_actor_id"] = ""
				previous_state["resident_actor_type"] = ""
			if String(previous_state.get("assistant_uid", "")) == actor_id:
				previous_state["assistant_uid"] = ""
			GameState.habitats[previous_home] = previous_state
		return

	for previous_home in GameState.habitats.keys():
		var previous_state: Dictionary = GameState.habitats[previous_home]
		if String(previous_state.get("resident_actor_type", "")) != actor_type:
			continue
		if String(previous_state.get("resident_actor_id", "")) != actor_id:
			continue
		previous_state["resident_uid"] = ""
		previous_state["resident_actor_id"] = ""
		previous_state["resident_actor_type"] = ""
		GameState.habitats[previous_home] = previous_state

func _set_resident_actor_state(state: Dictionary, actor_type: String, actor_id: String) -> void:
	state["resident_actor_type"] = actor_type
	state["resident_actor_id"] = actor_id
	state["resident_uid"] = actor_id if actor_type == PET_ACTOR_TYPE else ""


func can_build(habitat_id: String, building_id: String) -> Dictionary:
	var building = DataRepository.get_building(building_id)
	if building.is_empty():
		return {"ok": false, "reason": "building_missing"}

	if not DataRepository.building_matches_habitat(building, habitat_id):
		return {"ok": false, "reason": "site_mismatch"}

	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	var current_level: int = GameState.get_building_level(habitat_id, building_id)
	var levels: Array = _building_levels(building)
	var preview := _build_construction_preview(habitat_state, current_level, levels)
	var response := {
		"ok": false,
		"habitat_id": habitat_id,
		"building_id": building_id,
		"building_name": String(building.get("name", building_id)),
		"current_level": current_level,
		"max_level": levels.size(),
		"current_effects": preview.get("current_effects", []),
		"habitat_rank_before": preview.get("habitat_rank_before", 0),
		"habitat_rank_after": preview.get("habitat_rank_after", preview.get("habitat_rank_before", 0)),
		"progression_rank_before": preview.get("progression_rank_before", GameState.get_progression_rank()),
		"progression_rank_after": preview.get("progression_rank_after", GameState.get_progression_rank()),
		"capacity_before": preview.get("capacity_before", GameState.pet_capacity),
		"capacity_after": preview.get("capacity_after", GameState.pet_capacity),
		"progression_summary_after": preview.get("progression_summary_after", ""),
	}
	if not _has_guard_actor(habitat_state) and DataRepository.get_habitat(habitat_id).get("type", "") == "habitat":
		response["reason"] = "resident_required"
		return response

	if current_level >= levels.size():
		response["reason"] = "max_level"
		return response

	var next_level: Dictionary = levels[current_level]
	var cost: Dictionary = _normalize_cost(next_level.get("cost", {}))
	response["next_level"] = current_level + 1
	response["cost"] = cost
	response["effects"] = _level_effects(next_level)
	response["interactions"] = next_level.get("interactions", []).duplicate(true)
	if not GameState.can_pay(cost):
		response["reason"] = "insufficient_items"
		response["missing_cost"] = _missing_cost(cost)
		return response

	response["ok"] = true
	return response

func build_on_site(habitat_id: String, building_id: String) -> Dictionary:
	var check := can_build(habitat_id, building_id)
	if not bool(check.get("ok", false)):
		return check

	var habitat_rank_before := int(check.get("habitat_rank_before", 0))
	var progression_rank_before := int(check.get("progression_rank_before", GameState.get_progression_rank()))
	var capacity_before := int(check.get("capacity_before", GameState.pet_capacity))
	if not GameState.pay_cost(check.get("cost", {})):
		return {"ok": false, "reason": "payment_failed"}

	var new_level := int(check.get("next_level", 1))
	GameState.set_building_level(habitat_id, building_id, new_level)
	GameState.ensure_building_runtime_state(habitat_id, building_id)
	GameState.note_build(building_id, new_level)
	_refresh_habitat_rank(habitat_id)

	return {
		"ok": true,
		"habitat_id": habitat_id,
		"building_id": building_id,
		"level": new_level,
		"habitat_rank_before": habitat_rank_before,
		"habitat_rank_after": int(GameState.habitats.get(habitat_id, {}).get("rank", habitat_rank_before)),
		"progression_rank_before": progression_rank_before,
		"progression_rank_after": GameState.get_progression_rank(),
		"capacity_before": capacity_before,
		"capacity_after": GameState.pet_capacity,
		"progression_summary_after": GameState.get_progression_summary(),
		"effects": check.get("effects", []),
		"interactions": check.get("interactions", []).duplicate(true),
	}

func _refresh_habitat_rank(habitat_id: String) -> void:
	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	var building_levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
	var total := 0
	for level in building_levels.values():
		total += int(level)
	habitat_state["rank"] = total
	GameState.habitats[habitat_id] = habitat_state

func get_visit_summary(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	var state: Dictionary = GameState.habitats.get(habitat_id, {})
	var resident_profile := _resident_profile_for_state(state)
	var resident_uid := String(resident_profile.get("uid", ""))
	var npc_presence := npc_route_service.get_presence_report(habitat_id)
	return {
		"habitat": habitat,
		"state": state,
		"buildings": DataRepository.get_buildings_for_habitat(habitat_id),
		"building_actions": building_interaction_service.get_interaction_menu(habitat_id),
		"building_runtime_states": state.get("building_runtime_states", {}).duplicate(true),
		"npcs": npc_presence.get("visible_npcs", []),
		"npc_presence": npc_presence,
		"resident": resident_profile,
		"resident_uid": resident_uid,
		"access": get_access_report(habitat_id),
		"dojo": DataRepository.get_dojo(String(habitat.get("dojo_id", ""))),
	}

func get_access_report(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	var status: Dictionary = GameState.get_habitat_unlock_status(habitat_id)
	return {
		"habitat_id": habitat_id,
		"open": bool(status.get("open", false)),
		"unlock_text": String(status.get("unlock_text", "")),
		"reasons": status.get("reasons", []).duplicate(),
		"recommended_rank": int(habitat.get("recommended_rank", 0)),
		"flow_band": String(habitat.get("flow_band", "")),
		"seasonal_events": habitat.get("seasonal_events", []).duplicate(),
	}

func _resident_matches_preferences(habitat_id: String, actor_id: String) -> bool:
	return _guard_actor_matches_preferences(habitat_id, actor_id)

func _guard_actor_matches_preferences(habitat_id: String, actor_id: String) -> bool:
	var habitat := DataRepository.get_habitat(habitat_id)
	var profile := GameState.get_player_profile() if GameState.is_player_actor_id(actor_id) else GameState.get_pet(actor_id)
	var preferences: Array = habitat.get("resident_preferences", [])
	var resident_tags: Array = profile.get("resident_tags", [])
	for tag in resident_tags:
		if preferences.has(tag):
			return true
	return preferences.is_empty()

func _resident_profile_for_state(state: Dictionary) -> Dictionary:
	var actor_type := String(state.get("resident_actor_type", ""))
	var actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
	if actor_type.is_empty() and not actor_id.is_empty():
		actor_type = PET_ACTOR_TYPE
	if actor_id.is_empty():
		return {}
	if actor_type == PLAYER_ACTOR_TYPE:
		return GameState.get_player_profile()
	return GameState.get_pet(actor_id)

func _has_guard_actor(state: Dictionary) -> bool:
	var actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
	return not actor_id.is_empty()

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

func _level_effects(level_data: Dictionary) -> Array:
	var passive_effects: Array = level_data.get("passive_effects", [])
	if passive_effects.is_empty():
		passive_effects = level_data.get("effects", [])
	return passive_effects.duplicate(true)

func _build_construction_preview(habitat_state: Dictionary, current_level: int, levels: Array) -> Dictionary:
	var habitat_rank_before := int(habitat_state.get("rank", 0))
	var current_total_rank := GameState.get_habitat_rank_total()
	var progression_rank_before := GameState.get_progression_rank()
	var capacity_before := GameState.pet_capacity
	var habitat_rank_after := habitat_rank_before
	var progression_rank_after := progression_rank_before
	var capacity_after := capacity_before
	var progression_summary_after := GameState.get_progression_summary()
	if current_level < levels.size():
		habitat_rank_after += 1
		var total_rank_after := current_total_rank + 1
		progression_rank_after = maxi(1, 1 + GameState.badge_count + int(total_rank_after / 2))
		var curve_entry := DataRepository.get_population_curve_entry(progression_rank_after)
		capacity_after = int(curve_entry.get("pet_capacity", curve_entry.get("backpack_capacity", capacity_before)))
		progression_summary_after = _progression_summary_for_rank(progression_rank_after)
	return {
		"current_effects": _level_effects(levels[current_level - 1]) if current_level > 0 and current_level - 1 < levels.size() else [],
		"habitat_rank_before": habitat_rank_before,
		"habitat_rank_after": habitat_rank_after,
		"progression_rank_before": progression_rank_before,
		"progression_rank_after": progression_rank_after,
		"capacity_before": capacity_before,
		"capacity_after": capacity_after,
		"progression_summary_after": progression_summary_after,
	}

func _progression_summary_for_rank(rank: int) -> String:
	var entry := DataRepository.get_population_curve_entry(rank)
	if entry.is_empty():
		return ""
	var parts: Array[String] = []
	var new_system := String(entry.get("new_system", ""))
	var flow_goal := String(entry.get("flow_goal", ""))
	if not new_system.is_empty():
		parts.append(new_system)
	if not flow_goal.is_empty():
		parts.append(flow_goal)
	return " ｜ ".join(parts)

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

func _missing_cost(cost: Dictionary) -> Dictionary:
	var missing := {}
	for item_id in cost.keys():
		var required := int(cost[item_id])
		var current := GameState.get_item_count(String(item_id))
		if current < required:
			missing[item_id] = required - current
	return missing

class_name BuildingInteractionService
extends RefCounted

func get_interaction_menu(habitat_id: String) -> Array:
	var result: Array = []
	for building in DataRepository.get_buildings_for_habitat(habitat_id):
		var building_id := String(building.get("id", ""))
		if building_id.is_empty():
			continue
		var level: int = GameState.get_building_level(habitat_id, building_id)
		if level <= 0:
			continue
		var runtime_state: Dictionary = GameState.ensure_building_runtime_state(habitat_id, building_id)
		var actions: Array = []
		var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
		for action in _get_unlocked_actions(building, level):
			var action_id := String(action.get("id", ""))
			if action_id.is_empty():
				continue
			var cooldown_remaining := _get_cooldown_remaining(runtime_state, action_id)
			var disabled_reason := ""
			if damage_days > 0:
				disabled_reason = "damaged"
			elif cooldown_remaining > 0:
				disabled_reason = "cooldown"
			actions.append({
				"id": action_id,
				"label": String(action.get("label", action_id)),
				"description": String(action.get("description", "")),
				"cost": Dictionary(action.get("cost", {})).duplicate(true),
				"cooldown_remaining": cooldown_remaining,
				"damage_days": damage_days,
				"disabled": cooldown_remaining > 0 or damage_days > 0,
				"disabled_reason": disabled_reason,
			})
		if actions.is_empty():
			continue
		result.append({
			"building_id": building_id,
			"building_name": String(building.get("name", building_id)),
			"level": level,
			"category": String(building.get("category", "utility")),
			"actions": actions,
			"runtime_state": runtime_state.duplicate(true),
		})
	return result

func execute_action(habitat_id: String, building_id: String, action_id: String) -> Dictionary:
	var building: Dictionary = DataRepository.get_building(building_id)
	if building.is_empty():
		return {"ok": false, "reason": "building_missing", "building_id": building_id}
	if not DataRepository.building_matches_habitat(building, habitat_id):
		return {"ok": false, "reason": "site_mismatch", "building_id": building_id, "habitat_id": habitat_id}
	var level: int = GameState.get_building_level(habitat_id, building_id)
	if level <= 0:
		return {"ok": false, "reason": "building_not_built", "building_id": building_id, "habitat_id": habitat_id}
	var action := _find_action(building, level, action_id)
	if action.is_empty():
		return {"ok": false, "reason": "action_missing", "building_id": building_id, "action_id": action_id}
	var runtime_state: Dictionary = GameState.ensure_building_runtime_state(habitat_id, building_id)
	var cooldown_remaining := _get_cooldown_remaining(runtime_state, action_id)
	if cooldown_remaining > 0:
		return {
			"ok": false,
			"reason": "cooldown",
			"building_id": building_id,
			"action_id": action_id,
			"cooldown_remaining": cooldown_remaining,
		}
	var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
	if damage_days > 0:
		return {
			"ok": false,
			"reason": "building_damaged",
			"building_id": building_id,
			"action_id": action_id,
			"damage_days": damage_days,
		}
	var cost: Dictionary = Dictionary(action.get("cost", {})).duplicate(true)
	if not cost.is_empty() and not GameState.can_pay(cost):
		return {
			"ok": false,
			"reason": "insufficient_items",
			"building_id": building_id,
			"action_id": action_id,
			"cost": cost,
		}
	if not cost.is_empty() and not GameState.pay_cost(cost):
		return {"ok": false, "reason": "payment_failed", "building_id": building_id, "action_id": action_id}

	var result_payload: Dictionary = _apply_action_result(habitat_id, building, runtime_state, action)
	var cooldown_turns := maxi(0, int(action.get("cooldown_turns", 0)))
	if cooldown_turns > 0:
		var cooldowns: Dictionary = Dictionary(runtime_state.get("cooldowns", {})).duplicate(true)
		cooldowns[action_id] = cooldown_turns
		runtime_state["cooldowns"] = cooldowns
	runtime_state["last_used_turn"] = int(GameState.global_turn)
	runtime_state["last_action_id"] = action_id
	GameState.set_building_runtime_state(habitat_id, building_id, runtime_state)

	result_payload["ok"] = true
	result_payload["habitat_id"] = habitat_id
	result_payload["building_id"] = building_id
	result_payload["building_name"] = String(building.get("name", building_id))
	result_payload["action_id"] = action_id
	result_payload["action_label"] = String(action.get("label", action_id))
	result_payload["cost"] = cost
	result_payload["cooldown_turns"] = cooldown_turns
	result_payload["runtime_state"] = runtime_state.duplicate(true)
	return result_payload

func _find_action(building: Dictionary, level: int, action_id: String) -> Dictionary:
	for action in _get_unlocked_actions(building, level):
		if String(action.get("id", "")) == action_id:
			return Dictionary(action).duplicate(true)
	return {}

func _get_unlocked_actions(building: Dictionary, level: int) -> Array:
	var levels: Array = building.get("levels", [])
	var unlocked: Dictionary = {}
	for index in range(mini(level, levels.size())):
		var level_data: Dictionary = levels[index]
		for action in level_data.get("interactions", []):
			var action_id := String(action.get("id", ""))
			if action_id.is_empty():
				continue
			unlocked[action_id] = Dictionary(action).duplicate(true)
	var result: Array = []
	for action_id in unlocked.keys():
		result.append(unlocked[action_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return result

func _get_cooldown_remaining(runtime_state: Dictionary, action_id: String) -> int:
	var cooldowns: Dictionary = runtime_state.get("cooldowns", {})
	return maxi(0, int(cooldowns.get(action_id, 0)))

func _apply_action_result(habitat_id: String, building: Dictionary, runtime_state: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = Dictionary(action.get("result", {})).duplicate(true)
	var applied := {
		"granted_items": {},
		"bond_target_uid": "",
		"bond_delta": 0,
		"restored_hunger": 0,
		"next_observation_source": "",
		"marked_effects": [],
		"stored_output": {},
		"journal": String(result.get("journal", "")),
	}
	var reward_items: Dictionary = Dictionary(result.get("grant_items", {})).duplicate(true)
	if not reward_items.is_empty():
		GameState.grant_items(reward_items)
		applied["granted_items"] = reward_items
	var restore_hunger := maxi(0, int(result.get("restore_hunger", 0)))
	if restore_hunger > 0:
		GameState.restore_hunger(restore_hunger)
		applied["restored_hunger"] = restore_hunger
	var bond_delta := int(result.get("bond_delta", 0))
	var building_name := String(building.get("name", building.get("id", "建筑")))
	if bond_delta != 0:
		var bond_target := _resolve_bond_target_actor(habitat_id, String(result.get("bond_target", "resident")))
		var bond_target_uid := String(bond_target.get("id", ""))
		var bond_target_type := String(bond_target.get("type", ""))
		if not bond_target_uid.is_empty():
			if bond_target_type == "pet":
				GameState.add_pet_bond(bond_target_uid, bond_delta)
			elif bond_target_type == "player":
				GameState.add_journal_entry("你在 %s 的看守中又摸熟了一点这处据点。" % building_name)
			applied["bond_target_uid"] = bond_target_uid
			applied["bond_delta"] = bond_delta
	var next_observation_source := String(result.get("set_next_observation_source", ""))
	if not next_observation_source.is_empty():
		var visit_flags: Dictionary = Dictionary(runtime_state.get("visit_flags", {})).duplicate(true)
		visit_flags["next_observation_source"] = next_observation_source
		runtime_state["visit_flags"] = visit_flags
		applied["next_observation_source"] = next_observation_source
	var marked_effects: Array = Array(result.get("mark_map_effects", [])).duplicate(true)
	for effect_id in marked_effects:
		GameState.mark_map_effect_trigger(String(effect_id))
	applied["marked_effects"] = marked_effects
	var stored_output: Dictionary = Dictionary(result.get("store_output", {})).duplicate(true)
	if not stored_output.is_empty():
		var runtime_output: Dictionary = Dictionary(runtime_state.get("stored_output", {})).duplicate(true)
		for key in stored_output.keys():
			runtime_output[String(key)] = int(runtime_output.get(String(key), 0)) + int(stored_output[key])
		runtime_state["stored_output"] = runtime_output
		applied["stored_output"] = runtime_output.duplicate(true)
	if not applied["journal"].is_empty():
		GameState.add_journal_entry(String(applied["journal"]))
	return applied

func _resolve_bond_target_actor(habitat_id: String, target: String) -> Dictionary:
	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	match target:
		"assistant":
			return {
				"type": "pet",
				"id": String(habitat_state.get("assistant_uid", "")),
			}
		"service_pet":
			var assistant_uid := String(habitat_state.get("assistant_uid", ""))
			if not assistant_uid.is_empty():
				return {"type": "pet", "id": assistant_uid}
			return {
				"type": String(habitat_state.get("resident_actor_type", "pet")),
				"id": String(habitat_state.get("resident_actor_id", habitat_state.get("resident_uid", ""))),
			}
		_:
			return {
				"type": String(habitat_state.get("resident_actor_type", "pet")),
				"id": String(habitat_state.get("resident_actor_id", habitat_state.get("resident_uid", ""))),
			}

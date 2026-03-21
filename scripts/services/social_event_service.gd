class_name SocialEventService
extends RefCounted

const NpcRouteService = preload("res://scripts/services/npc_route_service.gd")
const EncounterService = preload("res://scripts/services/encounter_service.gd")

var rng := RandomNumberGenerator.new()
var npc_route_service := NpcRouteService.new()
var encounter_service := EncounterService.new()

func _init() -> void:
	rng.randomize()

func claim_talk_event(npc_id: String, habitat_id: String) -> Dictionary:
	var actor_context := _build_actor_context(habitat_id)
	var candidates: Array = []
	for raw_event in DataRepository.get_social_events_for_habitat(habitat_id):
		var social_event: Dictionary = Dictionary(raw_event).duplicate(true)
		var bindings := _find_binding(social_event, actor_context, npc_id)
		if bindings.is_empty():
			continue
		if not _event_is_available(social_event, habitat_id, bindings):
			continue
		var candidate := social_event.duplicate(true)
		candidate["_bindings"] = bindings
		candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = _pick_weighted_event(candidates, habitat_id)
	return _materialize_event(chosen, Dictionary(chosen.get("_bindings", {})).duplicate(true))

func claim_board_event(habitat_id: String) -> Dictionary:
	var actor_context := _build_actor_context(habitat_id)
	var candidates: Array = []
	for raw_event in DataRepository.get_social_events_for_habitat(habitat_id):
		var social_event: Dictionary = Dictionary(raw_event).duplicate(true)
		var bindings := _find_binding(social_event, actor_context)
		if bindings.is_empty():
			continue
		if not _event_is_available(social_event, habitat_id, bindings):
			continue
		var candidate := social_event.duplicate(true)
		candidate["_bindings"] = bindings
		candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = _pick_weighted_event(candidates, habitat_id)
	return _materialize_event(chosen, Dictionary(chosen.get("_bindings", {})).duplicate(true))

func _build_actor_context(habitat_id: String) -> Dictionary:
	var visible_npcs: Array = npc_route_service.get_visible_npcs(habitat_id)
	var npc_ids: Array[String] = []
	for npc in visible_npcs:
		var npc_id := String(npc.get("id", ""))
		if npc_id.is_empty() or npc_ids.has(npc_id):
			continue
		npc_ids.append(npc_id)
	var species_ids: Array[String] = []
	for raw_species_id in DataRepository.get_habitat(habitat_id).get("wild_pool", []):
		var species_id := String(raw_species_id)
		if species_id.is_empty() or species_ids.has(species_id):
			continue
		species_ids.append(species_id)
	for entry in encounter_service.build_weighted_entries(habitat_id, "observe"):
		var species_id := String(entry.get("species_id", ""))
		if species_id.is_empty() or species_ids.has(species_id):
			continue
		species_ids.append(species_id)
	return {
		"npc_ids": npc_ids,
		"species_ids": species_ids,
	}

func _find_binding(event_row: Dictionary, actor_context: Dictionary, preferred_npc_id: String = "") -> Dictionary:
	var actor_slots: Array = Array(event_row.get("actor_slots", [])).duplicate(true)
	if actor_slots.is_empty():
		return {}
	var results: Array = []
	_bind_slots(actor_slots, 0, actor_context, preferred_npc_id, {}, {}, results)
	if results.is_empty():
		return {}
	return Dictionary(results[rng.randi_range(0, results.size() - 1)]).duplicate(true)

func _bind_slots(actor_slots: Array, index: int, actor_context: Dictionary, preferred_npc_id: String, bindings: Dictionary, used: Dictionary, results: Array) -> void:
	if index >= actor_slots.size():
		if not preferred_npc_id.is_empty() and not _bindings_have_actor(bindings, preferred_npc_id):
			return
		results.append(bindings.duplicate(true))
		return
	var slot: Dictionary = Dictionary(actor_slots[index])
	var slot_name := String(slot.get("slot", ""))
	if slot_name.is_empty():
		return
	for actor_id in _candidates_for_slot(slot, actor_context, preferred_npc_id):
		if bool(used.get(actor_id, false)):
			continue
		var next_bindings := bindings.duplicate(true)
		next_bindings[slot_name] = actor_id
		var next_used := used.duplicate(true)
		next_used[actor_id] = true
		_bind_slots(actor_slots, index + 1, actor_context, preferred_npc_id, next_bindings, next_used, results)

func _bindings_have_actor(bindings: Dictionary, actor_id: String) -> bool:
	for value in bindings.values():
		if String(value) == actor_id:
			return true
	return false

func _candidates_for_slot(slot: Dictionary, actor_context: Dictionary, preferred_npc_id: String) -> Array[String]:
	var candidates: Array[String] = []
	var slot_type := String(slot.get("type", ""))
	var source: Array = []
	match slot_type:
		"npc":
			source = Array(actor_context.get("npc_ids", [])).duplicate(true)
		"species":
			source = Array(actor_context.get("species_ids", [])).duplicate(true)
		_:
			return candidates
	for raw_actor_id in source:
		var actor_id := String(raw_actor_id)
		if actor_id.is_empty():
			continue
		if not _slot_accepts_actor(slot, actor_id):
			continue
		candidates.append(actor_id)
	if slot_type == "npc" and not preferred_npc_id.is_empty() and candidates.has(preferred_npc_id):
		candidates.erase(preferred_npc_id)
		candidates.push_front(preferred_npc_id)
	return candidates

func _slot_accepts_actor(slot: Dictionary, actor_id: String) -> bool:
	var slot_type := String(slot.get("type", ""))
	match slot_type:
		"npc":
			var npc := DataRepository.get_npc(actor_id)
			if npc.is_empty():
				return false
			var npc_ids: Array = Array(slot.get("npc_ids", [])).duplicate(true)
			if not npc_ids.is_empty() and not npc_ids.has(actor_id):
				return false
			var tags_any: Array = Array(slot.get("npc_tags_any", [])).duplicate(true)
			if not tags_any.is_empty() and not _array_contains_any(Array(npc.get("tags", [])).duplicate(true), tags_any):
				return false
			var roles: Array = Array(slot.get("role_in", [])).duplicate(true)
			if not roles.is_empty() and not roles.has(String(npc.get("role", "resident"))):
				return false
			return true
		"species":
			var species := DataRepository.get_species(actor_id)
			if species.is_empty():
				return false
			var species_ids: Array = Array(slot.get("species_ids", [])).duplicate(true)
			if not species_ids.is_empty() and not species_ids.has(actor_id):
				return false
			var resident_tags_any: Array = Array(slot.get("resident_tags_any", [])).duplicate(true)
			if not resident_tags_any.is_empty() and not _array_contains_any(Array(species.get("resident_tags", [])).duplicate(true), resident_tags_any):
				return false
			var habitat_preferences_any: Array = Array(slot.get("habitat_preferences_any", [])).duplicate(true)
			if not habitat_preferences_any.is_empty() and not _array_contains_any(Array(species.get("habitat_preferences", [])).duplicate(true), habitat_preferences_any):
				return false
			var trait_tags_any: Array = Array(slot.get("trait_tags_any", [])).duplicate(true)
			if not trait_tags_any.is_empty() and not _array_contains_any(Array(species.get("trait_tags", [])).duplicate(true), trait_tags_any):
				return false
			var temperament_in: Array = Array(slot.get("temperament_in", [])).duplicate(true)
			if not temperament_in.is_empty() and not temperament_in.has(String(species.get("temperament", ""))):
				return false
			return true
		_:
			return false

func _event_is_available(event_row: Dictionary, habitat_id: String, bindings: Dictionary) -> bool:
	var event_id := String(event_row.get("id", ""))
	if event_id.is_empty() or String(event_row.get("habitat_id", habitat_id)) != habitat_id:
		return false
	var repeatable := bool(event_row.get("repeatable", false))
	if GameState.has_completed_event(event_id) and not repeatable:
		return false
	var cooldown_days := int(event_row.get("cooldown_days", 0))
	if cooldown_days > 0 and GameState.global_turn - GameState.get_event_last_turn(event_id) < cooldown_days:
		return false
	var conditions: Dictionary = Dictionary(event_row.get("conditions", {})).duplicate(true)
	if not _conditions_match(conditions, habitat_id, bindings):
		return false
	var chance := float(conditions.get("chance", 1.0))
	if chance < 1.0 and rng.randf() > chance:
		return false
	return true

func _conditions_match(conditions: Dictionary, habitat_id: String, bindings: Dictionary) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("after_event") and not _all_events_completed(conditions.get("after_event")):
		return false
	if conditions.has("after_quest") and not _all_quests_completed(conditions.get("after_quest")):
		return false
	if conditions.has("story_flag") and not GameState.has_story_flag(String(conditions.get("story_flag", ""))):
		return false
	if conditions.has("story_flags"):
		for raw_flag in conditions.get("story_flags", []):
			if not GameState.has_story_flag(String(raw_flag)):
				return false
	if conditions.has("week_index") and GameState.week_index != int(conditions.get("week_index", 0)):
		return false
	if conditions.has("week_index_min") and GameState.week_index < int(conditions.get("week_index_min", 0)):
		return false
	if conditions.has("week_index_max") and GameState.week_index > int(conditions.get("week_index_max", 9999)):
		return false
	if conditions.has("global_turn_min") and GameState.global_turn < int(conditions.get("global_turn_min", 0)):
		return false
	if conditions.has("global_turn_max") and GameState.global_turn > int(conditions.get("global_turn_max", 999999)):
		return false
	if conditions.has("season") and String(conditions.get("season", "")) != GameState.season_id:
		return false
	if conditions.has("season_in") and not Array(conditions.get("season_in", [])).has(GameState.season_id):
		return false
	if conditions.has("weather") and String(conditions.get("weather", "")) != GameState.weather_id:
		return false
	if conditions.has("weather_in") and not Array(conditions.get("weather_in", [])).has(GameState.weather_id):
		return false
	if conditions.has("time") and String(conditions.get("time", "")) != GameState.time_of_day:
		return false
	if conditions.has("time_in") and not Array(conditions.get("time_in", [])).has(GameState.time_of_day):
		return false
	if conditions.has("required_building"):
		var requirement: Dictionary = Dictionary(conditions.get("required_building", {})).duplicate(true)
		var building_id := String(requirement.get("id", ""))
		var min_level := int(requirement.get("min_level", 1))
		if building_id.is_empty() or GameState.get_building_level(habitat_id, building_id) < min_level:
			return false
	for requirement in _normalize_requirements(conditions.get("min_player_trust", [])):
		var slot_name := String(requirement.get("slot", ""))
		var npc_id := String(bindings.get(slot_name, ""))
		if npc_id.is_empty() or int(GameState.npc_trust.get(npc_id, 0)) < int(requirement.get("value", 0)):
			return false
	if not _pair_requirements_match(conditions.get("pair_relation_min", []), bindings, true):
		return false
	if not _pair_requirements_match(conditions.get("pair_relation_max", []), bindings, false):
		return false
	return true

func _pair_requirements_match(raw_requirements, bindings: Dictionary, is_minimum: bool) -> bool:
	for requirement in _normalize_requirements(raw_requirements):
		var pair: Array = Array(requirement.get("pair", [])).duplicate(true)
		if pair.size() < 2:
			return false
		var actor_a := _resolve_actor_reference(String(pair[0]), bindings)
		var actor_b := _resolve_actor_reference(String(pair[1]), bindings)
		if actor_a.is_empty() or actor_b.is_empty():
			return false
		for stat_key in ["affinity", "familiarity", "fear", "rivalry"]:
			if not requirement.has(stat_key):
				continue
			var current_value: int = GameState.get_social_relation_value(actor_a, actor_b, stat_key)
			var expected_value := int(requirement.get(stat_key, 0))
			if is_minimum and current_value < expected_value:
				return false
			if not is_minimum and current_value > expected_value:
				return false
	return true

func _normalize_requirements(raw_value) -> Array:
	if raw_value is Array:
		return Array(raw_value).duplicate(true)
	if raw_value is Dictionary:
		return [Dictionary(raw_value).duplicate(true)]
	return []

func _materialize_event(event_row: Dictionary, bindings: Dictionary) -> Dictionary:
	var stage_lines: Array = []
	for raw_stage in event_row.get("stages", []):
		var stage: Dictionary = Dictionary(raw_stage).duplicate(true)
		var slot_name := String(stage.get("slot", ""))
		if not slot_name.is_empty() and not bindings.has(slot_name):
			continue
		var text := _format_text(String(stage.get("text", "")), bindings)
		if text.is_empty():
			continue
		stage_lines.append(text)
		if stage_lines.size() >= 3:
			break
	if stage_lines.is_empty() and not String(event_row.get("summary", "")).is_empty():
		stage_lines.append(_format_text(String(event_row.get("summary", "")), bindings))
	var outcome_row := _pick_outcome(Array(event_row.get("outcomes", [])).duplicate(true))
	var effects: Dictionary = Dictionary(outcome_row.get("effects", {})).duplicate(true)
	var journal_entries: Array = []
	var journal_entry := _format_text(String(effects.get("journal_entry", "")), bindings)
	if not journal_entry.is_empty():
		journal_entries.append(journal_entry)
	var unlocked_dialogues: Array = []
	var unlock_dialogue = effects.get("unlock_dialogue", "")
	if unlock_dialogue is Array:
		for dialogue_id in unlock_dialogue:
			var value := String(dialogue_id)
			if value.is_empty():
				continue
			unlocked_dialogues.append(value)
	elif not String(unlock_dialogue).is_empty():
		unlocked_dialogues.append(String(unlock_dialogue))
	var relation_deltas := _resolve_relation_deltas(Array(effects.get("relation_delta", [])).duplicate(true), bindings)
	var story_flags: Array = []
	for raw_flag in Array(effects.get("set_story_flags", [])).duplicate(true):
		var flag_id := String(raw_flag)
		if flag_id.is_empty():
			continue
		story_flags.append(flag_id)
	var completed_events: Array = [String(event_row.get("id", ""))]
	for raw_id in Array(effects.get("complete_events", [])).duplicate(true):
		var event_id := String(raw_id)
		if event_id.is_empty() or completed_events.has(event_id):
			continue
		completed_events.append(event_id)
	return {
		"id": String(event_row.get("id", "")),
		"title": _format_text(String(event_row.get("title", "")), bindings),
		"category": String(event_row.get("category", "social")),
		"habitat_id": String(event_row.get("habitat_id", "")),
		"summary": _format_text(String(event_row.get("summary", "")), bindings),
		"stage_lines": stage_lines,
		"outcome": _format_text(String(outcome_row.get("outcome", "")), bindings),
		"trust_rewards": _resolve_trust_rewards(Dictionary(effects.get("trust", {})).duplicate(true), bindings),
		"items": Dictionary(effects.get("items", {})).duplicate(true),
		"journal_entries": journal_entries,
		"completed_events": completed_events,
		"unlocked_dialogues": unlocked_dialogues,
		"story_flags": story_flags,
		"relation_deltas": relation_deltas,
		"tags": Array(event_row.get("tags", [])).duplicate(true),
		"participants": bindings.duplicate(true),
	}

func _pick_outcome(outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {}
	var total := 0
	var buckets: Array = []
	for raw_outcome in outcomes:
		var outcome: Dictionary = Dictionary(raw_outcome).duplicate(true)
		var weight := maxi(1, int(outcome.get("weight", 1)))
		total += weight
		buckets.append({"threshold": total, "row": outcome})
	var roll := rng.randi_range(1, maxi(1, total))
	for bucket in buckets:
		if roll <= int(bucket.get("threshold", 0)):
			return Dictionary(bucket.get("row", {})).duplicate(true)
	return Dictionary(outcomes[0]).duplicate(true)

func _resolve_trust_rewards(raw_rewards: Dictionary, bindings: Dictionary) -> Dictionary:
	var result := {}
	for raw_key in raw_rewards.keys():
		var resolved_key := _resolve_actor_reference(String(raw_key), bindings)
		if resolved_key.begins_with("npc:"):
			resolved_key = resolved_key.trim_prefix("npc:")
		if resolved_key.is_empty() or resolved_key.contains(":"):
			continue
		result[resolved_key] = int(raw_rewards[raw_key])
	return result

func _resolve_relation_deltas(raw_deltas: Array, bindings: Dictionary) -> Array:
	var result: Array = []
	for raw_delta in raw_deltas:
		var delta: Dictionary = Dictionary(raw_delta).duplicate(true)
		var pair: Array = Array(delta.get("pair", [])).duplicate(true)
		if pair.size() < 2:
			continue
		var actor_a := _resolve_actor_reference(String(pair[0]), bindings)
		var actor_b := _resolve_actor_reference(String(pair[1]), bindings)
		if actor_a.is_empty() or actor_b.is_empty():
			continue
		var resolved := {
			"actor_a": actor_a,
			"actor_b": actor_b,
		}
		for stat_key in ["affinity", "familiarity", "fear", "rivalry"]:
			if delta.has(stat_key):
				resolved[stat_key] = int(delta.get(stat_key, 0))
		result.append(resolved)
	return result

func _resolve_actor_reference(raw_reference: String, bindings: Dictionary) -> String:
	var reference := raw_reference.strip_edges()
	if reference.is_empty():
		return ""
	if reference.begins_with("{") and reference.ends_with("}"):
		reference = reference.substr(1, reference.length() - 2)
	if bindings.has(reference):
		var bound_id := String(bindings.get(reference, ""))
		return _actor_runtime_id(bound_id)
	return _actor_runtime_id(reference)

func _actor_runtime_id(actor_id: String) -> String:
	if actor_id.is_empty():
		return ""
	if actor_id.contains(":"):
		return actor_id
	if not DataRepository.get_npc(actor_id).is_empty():
		return "npc:%s" % actor_id
	if not DataRepository.get_species(actor_id).is_empty():
		return "species:%s" % actor_id
	return actor_id

func _format_text(template: String, bindings: Dictionary) -> String:
	var text := template
	for slot_name in bindings.keys():
		text = text.replace("{%s}" % String(slot_name), _actor_label(String(bindings[slot_name])))
	return text

func _actor_label(actor_id: String) -> String:
	var normalized := actor_id
	if normalized.begins_with("npc:"):
		normalized = normalized.trim_prefix("npc:")
	if normalized.begins_with("species:"):
		normalized = normalized.trim_prefix("species:")
	var npc := DataRepository.get_npc(normalized)
	if not npc.is_empty():
		return String(npc.get("name", normalized))
	var species := DataRepository.get_species(normalized)
	if not species.is_empty():
		return String(species.get("name", normalized))
	return normalized

func _event_weight(event_row: Dictionary, habitat_id: String) -> int:
	var weight := maxi(1, int(event_row.get("weight", 1)))
	var event_id := String(event_row.get("id", ""))
	if GameState.get_event_last_turn(event_id) < 0:
		weight += 3
	var recent_ids: Array = GameState.get_recent_ambient_event_ids(6, habitat_id)
	if recent_ids.has(event_id):
		weight = maxi(1, int(ceil(float(weight) * 0.25)))
	for raw_tag in Array(event_row.get("tags", [])).duplicate(true):
		if GameState.get_recent_ambient_event_tags(6, habitat_id).has(String(raw_tag)):
			weight = maxi(1, weight - 1)
	if bool(event_row.get("repeatable", false)):
		weight += 1
	return maxi(1, weight)

func _pick_weighted_event(rows: Array, habitat_id: String) -> Dictionary:
	var total := 0
	var buckets: Array = []
	for row in rows:
		var score := _event_weight(row, habitat_id)
		total += score
		buckets.append({"threshold": total, "row": row})
	var roll := rng.randi_range(1, maxi(1, total))
	for bucket in buckets:
		if roll <= int(bucket.get("threshold", 0)):
			return Dictionary(bucket.get("row", {})).duplicate(true)
	return Dictionary(rows[0]).duplicate(true)

func _all_events_completed(raw_value) -> bool:
	if raw_value is Array:
		for raw_id in raw_value:
			if not GameState.has_completed_event(String(raw_id)):
				return false
		return true
	return GameState.has_completed_event(String(raw_value))

func _all_quests_completed(raw_value) -> bool:
	if raw_value is Array:
		for raw_id in raw_value:
			if not GameState.completed_quests.has(String(raw_id)):
				return false
		return true
	return GameState.completed_quests.has(String(raw_value))

func _array_contains_any(values: Array, expected: Array) -> bool:
	for item in values:
		if expected.has(item):
			return true
	return false

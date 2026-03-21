class_name StoryService
extends RefCounted

func claim_story_dialogue(npc_id: String, habitat_id: String) -> Dictionary:
	for raw_arc in DataRepository.get_story_arcs():
		var arc: Dictionary = Dictionary(raw_arc).duplicate(true)
		var arc_id := String(arc.get("id", ""))
		if arc_id.is_empty():
			continue
		if GameState.has_completed_story_arc(arc_id):
			continue
		if not GameState.is_story_arc_active(arc_id):
			var start_conditions: Dictionary = Dictionary(arc.get("start_conditions", {}))
			if not _conditions_match(start_conditions, npc_id, habitat_id):
				continue
			GameState.activate_story_arc(arc_id)
		for raw_beat in arc.get("beats", []):
			var beat: Dictionary = Dictionary(raw_beat).duplicate(true)
			var beat_id := String(beat.get("id", ""))
			if beat_id.is_empty():
				continue
			if GameState.has_story_beat_seen(arc_id, beat_id):
				continue
			if not _conditions_match(beat, npc_id, habitat_id):
				continue
			var dialogue_id := String(beat.get("dialogue_id", ""))
			if dialogue_id.is_empty() or DataRepository.get_dialogue(dialogue_id).is_empty():
				continue
			GameState.mark_story_beat_seen(arc_id, beat_id)
			var unlock_dialogue = beat.get("unlock_dialogue", "")
			if unlock_dialogue is Array:
				for raw_dialogue_id in unlock_dialogue:
					GameState.unlock_dialogue(String(raw_dialogue_id))
			elif not String(unlock_dialogue).is_empty():
				GameState.unlock_dialogue(String(unlock_dialogue))
			for raw_flag in beat.get("set_story_flags", []):
				var flag_id := String(raw_flag)
				if flag_id.is_empty():
					continue
				GameState.set_story_flag(flag_id)
			if bool(beat.get("complete_arc", false)):
				GameState.complete_story_arc(arc_id)
			beat["arc_id"] = arc_id
			return beat
	return {}

func _conditions_match(conditions: Dictionary, npc_id: String, habitat_id: String) -> bool:
	if conditions.is_empty():
		return true
	if conditions.has("habitat_id") and String(conditions.get("habitat_id", "")) != habitat_id:
		return false
	if conditions.has("npc_id") and String(conditions.get("npc_id", "")) != npc_id:
		return false
	if conditions.has("after_event") and not _all_events_completed(conditions.get("after_event")):
		return false
	if conditions.has("requires_events") and not _all_events_completed(conditions.get("requires_events")):
		return false
	if conditions.has("after_quest") and not _all_quests_completed(conditions.get("after_quest")):
		return false
	if conditions.has("requires_quests") and not _all_quests_completed(conditions.get("requires_quests")):
		return false
	if conditions.has("story_flag") and not GameState.has_story_flag(String(conditions.get("story_flag", ""))):
		return false
	if conditions.has("story_flags"):
		for raw_flag in conditions.get("story_flags", []):
			if not GameState.has_story_flag(String(raw_flag)):
				return false
	if conditions.has("season") and String(conditions.get("season", "")) != GameState.season_id:
		return false
	if conditions.has("season_in") and not Array(conditions.get("season_in", [])).has(GameState.season_id):
		return false
	if conditions.has("time") and String(conditions.get("time", "")) != GameState.time_of_day:
		return false
	if conditions.has("time_in") and not Array(conditions.get("time_in", [])).has(GameState.time_of_day):
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
	if conditions.has("pair_relation_min") and not _pair_requirements_match(conditions.get("pair_relation_min"), true):
		return false
	if conditions.has("pair_relation_max") and not _pair_requirements_match(conditions.get("pair_relation_max"), false):
		return false
	if conditions.has("required_building"):
		var requirement: Dictionary = Dictionary(conditions.get("required_building", {}))
		var building_id := String(requirement.get("id", ""))
		var min_level := int(requirement.get("min_level", 1))
		if building_id.is_empty() or GameState.get_building_level(habitat_id, building_id) < min_level:
			return false
	return true

func _pair_requirements_match(raw_requirements, is_minimum: bool) -> bool:
	var requirements: Array = []
	if raw_requirements is Array:
		requirements = Array(raw_requirements).duplicate(true)
	elif raw_requirements is Dictionary:
		requirements = [Dictionary(raw_requirements).duplicate(true)]
	for raw_requirement in requirements:
		var requirement: Dictionary = Dictionary(raw_requirement).duplicate(true)
		var pair: Array = Array(requirement.get("pair", [])).duplicate(true)
		if pair.size() < 2:
			return false
		var actor_a := String(pair[0])
		var actor_b := String(pair[1])
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

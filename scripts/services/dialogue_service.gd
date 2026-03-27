class_name DialogueService
extends RefCounted

const StoryService = preload("res://scripts/services/story_service.gd")
const SocialEventService = preload("res://scripts/services/social_event_service.gd")

var rng := RandomNumberGenerator.new()
var story_service := StoryService.new()
var social_event_service := SocialEventService.new()

func _init() -> void:
	rng.randomize()

func build_talk_package(npc_id: String, habitat_id: String, context: Dictionary = {}) -> Dictionary:
	var npc := DataRepository.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var forced_dialogue_id := String(context.get("forced_dialogue_id", ""))
	var story_beat: Dictionary = {}
	if forced_dialogue_id.is_empty():
		story_beat = story_service.preview_story_dialogue(npc_id, habitat_id)
		forced_dialogue_id = String(story_beat.get("dialogue_id", ""))
	var event_result := _pick_social_or_ambient_event(npc_id, habitat_id)
	var dialogue := {}
	if not forced_dialogue_id.is_empty():
		dialogue = DataRepository.get_dialogue(forced_dialogue_id)
	if dialogue.is_empty():
		dialogue = _pick_dialogue(npc_id, habitat_id)
	var transcript_lines: Array = []
	if dialogue.is_empty():
		transcript_lines = _build_fallback_lines(npc, habitat_id)
	else:
		transcript_lines = _build_transcript(dialogue)
	return {
		"npc_id": npc_id,
		"dialogue_id": String(dialogue.get("id", "")),
		"topic": String(dialogue.get("topic", "daily")),
		"dialogue": Dictionary(dialogue).duplicate(true),
		"story_beat": Dictionary(story_beat).duplicate(true),
		"transcript_lines": transcript_lines,
		"tags": _build_tags(dialogue, event_result, npc),
		"event": event_result,
		"trust_rewards": Dictionary(event_result.get("trust_rewards", {})).duplicate(true),
		"items": Dictionary(event_result.get("items", {})).duplicate(true),
		"journal_entries": Array(event_result.get("journal_entries", [])).duplicate(true),
		"completed_events": Array(event_result.get("completed_events", [])).duplicate(true),
		"unlocked_dialogues": Array(event_result.get("unlocked_dialogues", [])).duplicate(true),
		"codex_unlocks": Array(event_result.get("codex_unlocks", [])).duplicate(true),
		"encyclopedia_unlocks": Array(event_result.get("encyclopedia_unlocks", [])).duplicate(true),
		"story_flags": Array(event_result.get("story_flags", [])).duplicate(true),
		"relation_deltas": Array(event_result.get("relation_deltas", [])).duplicate(true),
	}

func build_board_event_package(habitat_id: String) -> Dictionary:
	var social_event := social_event_service.claim_board_event(habitat_id)
	if not social_event.is_empty():
		return social_event
	var candidates: Array = []
	for event_row in DataRepository.get_events_for_habitat(habitat_id):
		if String(event_row.get("mode", "")) != "ambient_talk":
			continue
		var participants: Array = event_row.get("participants", [])
		if participants.is_empty():
			continue
		var candidate: Dictionary = Dictionary(event_row).duplicate(true)
		var available_participants: Array[String] = []
		for raw_npc_id in participants:
			var npc_id := String(raw_npc_id)
			if npc_id.is_empty():
				continue
			if _event_is_available(event_row, npc_id, habitat_id):
				available_participants.append(npc_id)
		if available_participants.is_empty():
			continue
		candidate["board_npc_id"] = available_participants[rng.randi_range(0, available_participants.size() - 1)]
		candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = _pick_weighted_event(candidates, habitat_id)
	var npc_id := String(chosen.get("board_npc_id", ""))
	if npc_id.is_empty():
		return {}
	var result := _materialize_event(chosen, npc_id)
	result["npc_id"] = npc_id
	return result

func _pick_social_or_ambient_event(npc_id: String, habitat_id: String) -> Dictionary:
	var social_event := social_event_service.claim_talk_event(npc_id, habitat_id)
	if not social_event.is_empty():
		return social_event
	return _pick_ambient_event(npc_id, habitat_id)

func _pick_dialogue(npc_id: String, habitat_id: String) -> Dictionary:
	var candidates: Array = []
	for dialogue in DataRepository.get_dialogues_for_npc(npc_id):
		if String(dialogue.get("habitat_id", habitat_id)) != habitat_id:
			continue
		if not _dialogue_is_available(dialogue, npc_id, habitat_id):
			continue
		candidates.append(dialogue)
	if candidates.is_empty():
		return {}
	return _pick_weighted_dialogue(candidates, npc_id)

func _pick_ambient_event(npc_id: String, habitat_id: String) -> Dictionary:
	var candidates: Array = []
	for event_row in DataRepository.get_events_for_habitat(habitat_id):
		if String(event_row.get("mode", "")) != "ambient_talk":
			continue
		if not Array(event_row.get("participants", [])).has(npc_id):
			continue
		if not _event_is_available(event_row, npc_id, habitat_id):
			continue
		candidates.append(event_row)
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = _pick_weighted_event(candidates, habitat_id)
	return _materialize_event(chosen, npc_id)

func _dialogue_is_available(dialogue: Dictionary, npc_id: String, habitat_id: String) -> bool:
	var dialogue_id := String(dialogue.get("id", ""))
	if dialogue_id.is_empty():
		return false
	if String(dialogue.get("habitat_id", habitat_id)) != habitat_id:
		return false
	if bool(dialogue.get("requires_unlock", false)) and not GameState.is_dialogue_unlocked(dialogue_id):
		return false
	if bool(dialogue.get("once", false)) and GameState.get_dialogue_seen_count(dialogue_id) > 0:
		return false
	var cooldown_days := int(dialogue.get("cooldown_days", 0))
	if cooldown_days > 0 and GameState.global_turn - GameState.get_dialogue_last_seen(dialogue_id) < cooldown_days:
		return false
	var conditions: Dictionary = dialogue.get("conditions", {})
	return _conditions_match(conditions, npc_id, habitat_id)

func _event_is_available(event_row: Dictionary, npc_id: String, habitat_id: String) -> bool:
	var event_id := String(event_row.get("id", ""))
	if event_id.is_empty() or String(event_row.get("habitat_id", habitat_id)) != habitat_id:
		return false
	var repeatable := bool(event_row.get("repeatable", false))
	if GameState.has_completed_event(event_id) and not repeatable:
		return false
	var cooldown_days := int(event_row.get("cooldown_days", 0))
	if cooldown_days > 0 and GameState.global_turn - GameState.get_event_last_turn(event_id) < cooldown_days:
		return false
	var trigger: Dictionary = event_row.get("trigger", {})
	if not _conditions_match(trigger, npc_id, habitat_id):
		return false
	var chance := float(trigger.get("chance", 1.0))
	if chance < 1.0 and rng.randf() > chance:
		return false
	return true

func _conditions_match(conditions: Dictionary, npc_id: String, habitat_id: String) -> bool:
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
	if conditions.has("active_story_arc") and not GameState.is_story_arc_active(String(conditions.get("active_story_arc", ""))):
		return false
	if conditions.has("completed_story_arc") and not GameState.has_completed_story_arc(String(conditions.get("completed_story_arc", ""))):
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
	if conditions.has("min_trust") and int(GameState.npc_trust.get(npc_id, 0)) < int(conditions.get("min_trust", 0)):
		return false
	if conditions.has("max_trust") and int(GameState.npc_trust.get(npc_id, 0)) > int(conditions.get("max_trust", 0)):
		return false
	if conditions.has("pair_relation_min") and not _pair_requirements_match(conditions.get("pair_relation_min"), true):
		return false
	if conditions.has("pair_relation_max") and not _pair_requirements_match(conditions.get("pair_relation_max"), false):
		return false
	if conditions.has("required_building"):
		var requirement: Dictionary = conditions.get("required_building", {})
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

func _dialogue_weight(dialogue: Dictionary, npc_id: String) -> int:
	var weight := maxi(1, int(dialogue.get("weight", 1)))
	var dialogue_id := String(dialogue.get("id", ""))
	if GameState.get_dialogue_seen_count(dialogue_id) == 0:
		weight += 3
	if GameState.get_last_dialogue_for_npc(npc_id) == dialogue_id:
		weight = maxi(1, int(weight / 4))
	var topic := String(dialogue.get("topic", "daily"))
	weight = maxi(1, weight - mini(GameState.get_npc_topic_seen_count(npc_id, topic), weight - 1))
	return weight

func _pick_weighted_dialogue(rows: Array, npc_id: String) -> Dictionary:
	var total := 0
	var buckets: Array = []
	for row in rows:
		var score := _dialogue_weight(row, npc_id)
		total += score
		buckets.append({"threshold": total, "row": row})
	var roll := rng.randi_range(1, maxi(1, total))
	for bucket in buckets:
		if roll <= int(bucket.get("threshold", 0)):
			return Dictionary(bucket.get("row", {})).duplicate(true)
	return Dictionary(rows[0]).duplicate(true)

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

func _event_weight(row: Dictionary, habitat_id: String) -> int:
	var weight := maxi(1, int(row.get("weight", 1)))
	var event_id := String(row.get("id", ""))
	if GameState.get_event_last_turn(event_id) < 0:
		weight += 3
	var recent_ids: Array = GameState.get_recent_ambient_event_ids(6, habitat_id)
	if recent_ids.has(event_id):
		weight = maxi(1, int(ceil(float(weight) * 0.2)))
	weight = maxi(1, weight - _recent_event_tag_penalty(row, habitat_id))
	if _event_matches_current_deck(row):
		weight += 2
	if bool(row.get("repeatable", false)):
		weight += 1
	return maxi(1, weight)

func _recent_event_tag_penalty(row: Dictionary, habitat_id: String) -> int:
	var penalty := 0
	var recent_tags: Array = GameState.get_recent_ambient_event_tags(6, habitat_id)
	for raw_tag in row.get("tags", []):
		if recent_tags.has(String(raw_tag)):
			penalty += 1
	return penalty

func _event_matches_current_deck(row: Dictionary) -> bool:
	var deck: Dictionary = DataRepository.get_node_deck_for_season(GameState.season_id)
	var flavors: Array = Array(deck.get("encounter_flavors", [])).duplicate(true)
	if flavors.is_empty():
		return false
	var summary_text := "%s %s" % [String(row.get("title", "")), String(row.get("summary", ""))]
	for flavor in flavors:
		var token := String(flavor)
		if token.is_empty():
			continue
		if summary_text.findn(token) >= 0:
			return true
		for raw_tag in row.get("tags", []):
			if String(raw_tag) == token:
				return true
	return false

func _materialize_event(event_row: Dictionary, npc_id: String) -> Dictionary:
	var stage_lines: Array = []
	for stage in event_row.get("stages", []):
		var stage_npc := String(stage.get("npc", ""))
		if not stage_npc.is_empty() and stage_npc != npc_id:
			continue
		var text := String(stage.get("text", ""))
		if text.is_empty():
			continue
		stage_lines.append(text)
		if stage_lines.size() >= 2:
			break
	if stage_lines.is_empty() and not String(event_row.get("summary", "")).is_empty():
		stage_lines.append(String(event_row.get("summary", "")))
	var choice := {}
	var choices: Array = event_row.get("choices", [])
	if not choices.is_empty():
		choice = choices[rng.randi_range(0, choices.size() - 1)]
	var effects: Dictionary = choice.get("effects", {})
	var journal_entries: Array = []
	var journal_entry := String(effects.get("journal_entry", ""))
	if not journal_entry.is_empty():
		journal_entries.append(journal_entry)
	var unlocked_dialogues: Array = _coerce_string_list(effects.get("unlock_dialogue", []))
	var codex_unlocks: Array = _coerce_string_list(effects.get("unlock_codex", []))
	var encyclopedia_unlocks: Array = _coerce_string_list(effects.get("unlock_encyclopedia", []))
	return {
		"id": String(event_row.get("id", "")),
		"title": String(event_row.get("title", "")),
		"habitat_id": String(event_row.get("habitat_id", "")),
		"summary": String(event_row.get("summary", "")),
		"stage_lines": stage_lines,
		"outcome": String(choice.get("outcome", "")),
		"trust_rewards": Dictionary(effects.get("trust", {})).duplicate(true),
		"items": Dictionary(effects.get("items", {})).duplicate(true),
		"journal_entries": journal_entries,
		"completed_events": [String(event_row.get("id", ""))],
		"unlocked_dialogues": unlocked_dialogues,
		"codex_unlocks": codex_unlocks,
		"encyclopedia_unlocks": encyclopedia_unlocks,
		"story_flags": Array(effects.get("set_story_flags", [])).duplicate(true),
		"relation_deltas": Array(effects.get("relation_delta", [])).duplicate(true),
		"tags": Array(event_row.get("tags", [])).duplicate(true),
	}

func _coerce_string_list(raw_value) -> Array:
	var values: Array = []
	if raw_value is Array:
		values = Array(raw_value).duplicate(true)
	elif not String(raw_value).is_empty():
		values = [String(raw_value)]
	var result: Array = []
	for raw_item in values:
		var value := String(raw_item)
		if value.is_empty() or result.has(value):
			continue
		result.append(value)
	return result

func _build_transcript(dialogue: Dictionary) -> Array:
	var lines: Array = []
	var nodes_by_id := {}
	for node in dialogue.get("nodes", []):
		nodes_by_id[String(node.get("id", ""))] = node
	var current_id := "start"
	var guard := 0
	while guard < 8 and nodes_by_id.has(current_id):
		guard += 1
		var node: Dictionary = nodes_by_id[current_id]
		var speaker := _speaker_name(String(node.get("speaker", "")))
		var text := String(node.get("text", ""))
		if not text.is_empty():
			lines.append("%s：%s" % [speaker, text])
		var choices: Array = node.get("choices", [])
		if choices.is_empty():
			break
		var choice: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
		lines.append("你：%s" % String(choice.get("text", "…")))
		current_id = String(choice.get("next", ""))
		if current_id.is_empty():
			break
	return lines

func _build_fallback_lines(npc: Dictionary, habitat_id: String) -> Array:
	var name := String(npc.get("name", "某人"))
	var tags: Array = npc.get("tags", [])
	var habitat_name := String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))
	if tags.has("care"):
		return [
			"%s先看了看你手上有没有沾到会惊到幼体的冷气和水。" % name,
			"%s：今天先别急，照料很多时候是把动作放轻。" % name,
		]
	if tags.has("trade"):
		return [
			"%s把随身的小包重新系紧，像是在确认每样东西都待在该待的位置。" % name,
			"%s：路上最值钱的不是货，是知道什么该在 %s 留下。" % [name, habitat_name],
		]
	return [
		"%s抬头看了你一眼，像是在确认你今天是来赶路，还是来认真待一会儿。" % name,
		"%s：这里每天都不太一样，先看看今天肯跟我们说什么吧。" % name,
	]

func _build_tags(dialogue: Dictionary, event_result: Dictionary, npc: Dictionary) -> Array:
	var tags: Array = []
	for raw_tag in dialogue.get("tags", []):
		var tag := String(raw_tag)
		if tag.is_empty() or tags.has(tag):
			continue
		tags.append(tag)
	for raw_tag in event_result.get("tags", []):
		var tag := String(raw_tag)
		if tag.is_empty() or tags.has(tag):
			continue
		tags.append(tag)
	if tags.is_empty():
		for raw_tag in npc.get("tags", []):
			var tag := String(raw_tag)
			if tag.is_empty() or tags.has(tag):
				continue
			tags.append(tag)
			if tags.size() >= 3:
				break
	return tags

func _speaker_name(speaker_id: String) -> String:
	if speaker_id.is_empty() or speaker_id == "player":
		return "你"
	var npc := DataRepository.get_npc(speaker_id)
	if not npc.is_empty():
		return String(npc.get("name", speaker_id))
	return speaker_id

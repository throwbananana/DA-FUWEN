class_name CutsceneService
extends RefCounted

func build_talk_cutscene(npc_id: String, npc: Dictionary, talk_package: Dictionary) -> Dictionary:
	var steps: Array = []
	var event_result: Dictionary = Dictionary(talk_package.get("event", {})).duplicate(true)
	if not event_result.is_empty():
		var event_title := String(event_result.get("title", "临时插曲"))
		var stage_lines: Array = Array(event_result.get("stage_lines", [])).duplicate(true)
		for line in stage_lines:
			var text := String(line)
			if text.is_empty():
				continue
			steps.append({
				"title": event_title,
				"speaker": String(npc.get("name", "旁白")),
				"body": text,
				"continue_text": "继续",
			})
		var outcome := String(event_result.get("outcome", ""))
		if not outcome.is_empty():
			steps.append({
				"title": event_title,
				"speaker": "结果",
				"body": outcome,
				"continue_text": "继续",
			})
	var dialogue: Dictionary = Dictionary(talk_package.get("dialogue", {})).duplicate(true)
	if dialogue.is_empty():
		var transcript_lines: Array = Array(talk_package.get("transcript_lines", [])).duplicate(true)
		if not transcript_lines.is_empty():
			steps.append({
				"title": String(npc.get("name", "交谈")),
				"speaker": String(npc.get("name", "某人")),
				"body": "\n".join(PackedStringArray(_stringify_lines(transcript_lines))),
				"continue_text": "继续",
			})
		return {"steps": steps, "dialogue_runtime": {}}
	return {
		"steps": steps,
		"dialogue_runtime": build_dialogue_runtime(dialogue, npc_id),
	}

func build_dialogue_runtime(dialogue: Dictionary, fallback_npc_id: String = "") -> Dictionary:
	var nodes_by_id := {}
	for raw_node in dialogue.get("nodes", []):
		var node: Dictionary = Dictionary(raw_node).duplicate(true)
		var node_id := String(node.get("id", ""))
		if node_id.is_empty():
			continue
		nodes_by_id[node_id] = node
	return {
		"title": String(dialogue.get("title", "")),
		"dialogue_id": String(dialogue.get("id", "")),
		"npc_id": String(dialogue.get("npc", fallback_npc_id)),
		"start_node_id": "start",
		"nodes_by_id": nodes_by_id,
	}

func build_dialogue_step(runtime: Dictionary, node_id: String) -> Dictionary:
	var nodes_by_id: Dictionary = Dictionary(runtime.get("nodes_by_id", {})).duplicate(true)
	if not nodes_by_id.has(node_id):
		return {}
	var node: Dictionary = Dictionary(nodes_by_id.get(node_id, {})).duplicate(true)
	var step_choices: Array = []
	var choices: Array = Array(node.get("choices", [])).duplicate(true)
	for index in range(choices.size()):
		var choice: Dictionary = Dictionary(choices[index]).duplicate(true)
		var choice_id := String(choice.get("id", ""))
		if choice_id.is_empty():
			choice_id = "%s_choice_%d" % [node_id, index]
		step_choices.append({
			"id": choice_id,
			"label": String(choice.get("text", "继续")),
			"summary": String(choice.get("summary", "")),
			"next": String(choice.get("next", "")),
		})
	return {
		"title": _dialogue_title(runtime),
		"speaker": _speaker_name(String(node.get("speaker", runtime.get("npc_id", "")))),
		"body": String(node.get("text", "")),
		"choices": step_choices,
		"continue_text": "收束这一段" if bool(node.get("end", false)) else "继续",
		"end": bool(node.get("end", false)),
		"next": String(node.get("next", "")),
	}

func resolve_dialogue_next(runtime: Dictionary, node_id: String, choice_id: String) -> String:
	var nodes_by_id: Dictionary = Dictionary(runtime.get("nodes_by_id", {})).duplicate(true)
	if not nodes_by_id.has(node_id):
		return ""
	var node: Dictionary = Dictionary(nodes_by_id.get(node_id, {})).duplicate(true)
	var choices: Array = Array(node.get("choices", [])).duplicate(true)
	if choices.is_empty():
		return String(node.get("next", ""))
	if choice_id.is_empty():
		var first_choice: Dictionary = Dictionary(choices[0]).duplicate(true)
		return String(first_choice.get("next", ""))
	for index in range(choices.size()):
		var choice: Dictionary = Dictionary(choices[index]).duplicate(true)
		var resolved_choice_id := String(choice.get("id", ""))
		if resolved_choice_id.is_empty():
			resolved_choice_id = "%s_choice_%d" % [node_id, index]
		if resolved_choice_id == choice_id:
			return String(choice.get("next", ""))
	return ""

func _dialogue_title(runtime: Dictionary) -> String:
	var title := String(runtime.get("title", ""))
	if not title.is_empty():
		return title
	var npc_name := _speaker_name(String(runtime.get("npc_id", "")))
	return "%s 的谈话" % npc_name if not npc_name.is_empty() else "交谈"

func _speaker_name(speaker_id: String) -> String:
	if speaker_id.is_empty():
		return "旁白"
	match speaker_id:
		"player", "you", "self":
			return "你"
	var npc := DataRepository.get_npc(speaker_id)
	if not npc.is_empty():
		return String(npc.get("name", speaker_id))
	return speaker_id.replace("_", " ")

func _stringify_lines(lines: Array) -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		var text := String(line)
		if text.is_empty():
			continue
		result.append(text)
	return result

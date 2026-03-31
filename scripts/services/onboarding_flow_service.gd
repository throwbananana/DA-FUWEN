class_name OnboardingFlowService
extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const GameConstants = preload("res://scripts/game_constants.gd")

func tutorial_entry(tutorial_id: String) -> Dictionary:
	return Dictionary(GameConstants.TUTORIAL_ENTRIES.get(tutorial_id, {})).duplicate(true)

func build_starter_choices() -> Array:
	var choices: Array = []
	for raw_species_id in GameConstants.STARTER_SPECIES_IDS:
		var species_id := String(raw_species_id)
		if species_id.is_empty():
			continue
		var species := DataRepository.get_species(species_id)
		if species.is_empty():
			continue
		var profile := GameData.get_species_synergy_profile(species_id)
		choices.append({
			"id": species_id,
			"label": String(species.get("name", species_id)),
			"summary": "%s ｜ %s ｜ 会直接放进 1 号出战位" % [
				_format_type_tags(Array(profile.get("elements", []))),
				_format_role_tags(Array(profile.get("job_tags", []))),
			],
		})
	return choices

func pick_random_starter_species(rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	for raw_species_id in GameConstants.STARTER_SPECIES_IDS:
		var species_id := String(raw_species_id)
		if species_id.is_empty() or DataRepository.get_species(species_id).is_empty():
			continue
		candidates.append(species_id)
	if candidates.is_empty():
		return ""
	return String(candidates[rng.randi_range(0, candidates.size() - 1)])

func build_starter_result_body(species_id: String, random_choice := false) -> String:
	var species := DataRepository.get_species(species_id)
	if species.is_empty():
		return ""
	var profile := GameData.get_species_synergy_profile(species_id)
	var mode_text := "随机分配" if random_choice else "已选择"
	var body_lines: Array[String] = [
		"[b]%s[/b] %s" % [mode_text, String(species.get("name", species_id))],
		"属性：%s ｜ 职能：%s" % [
			_format_type_tags(Array(profile.get("elements", []))),
			_format_role_tags(Array(profile.get("job_tags", []))),
		],
		"它已经进入 1 号出战位，前期路线和第一场战斗会围绕它展开。",
	]
	return "\n".join(body_lines)

func build_tutorial_review_lines(has_completed_tutorial: Callable) -> Array[String]:
	var tutorial_lines: Array[String] = []
	var completed_count := 0
	for raw_tutorial_id in GameConstants.TUTORIAL_ORDER:
		var tutorial_id := String(raw_tutorial_id)
		if bool(has_completed_tutorial.call(tutorial_id)):
			completed_count += 1
	tutorial_lines.append("[b]已读教程[/b] %d / %d" % [completed_count, GameConstants.TUTORIAL_ORDER.size()])
	for raw_tutorial_id in GameConstants.TUTORIAL_ORDER:
		var tutorial_id := String(raw_tutorial_id)
		var entry := tutorial_entry(tutorial_id)
		var status := "已读" if bool(has_completed_tutorial.call(tutorial_id)) else "未读"
		tutorial_lines.append("[b]%s[/b] %s" % [status, String(entry.get("title", tutorial_id))])
		tutorial_lines.append(String(entry.get("body", "")))
		tutorial_lines.append("")
	tutorial_lines.append("如果刚开新局，起始伙伴选择会在进入远征时自动触发。")
	return tutorial_lines

func _format_type_tags(type_ids: Array) -> String:
	var parts: Array[String] = []
	for type_id in type_ids:
		parts.append(GameData.get_type_name(String(type_id)))
	return " / ".join(parts)

func _format_role_tags(role_ids: Array) -> String:
	var parts: Array[String] = []
	for role_id in role_ids:
		parts.append(String(GameData.JOB_NAMES.get(String(role_id), String(role_id))))
	return " / ".join(parts)

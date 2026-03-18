class_name WeeklyCycleService
extends RefCounted

func pick_objective(season_id: String, week_index: int) -> Dictionary:
	var pool: Array = DataRepository.get_weekly_objectives_for_season(season_id)
	if pool.is_empty():
		return {}
	var safe_index := maxi(0, week_index - 1) % pool.size()
	return Dictionary(pool[safe_index]).duplicate(true)

func is_complete(objective: Dictionary, progress: Dictionary) -> bool:
	if objective.is_empty():
		return false
	for requirement in objective.get("requirements", []):
		var metric := String(requirement.get("metric", ""))
		var target := int(requirement.get("target", 0))
		if int(progress.get(metric, 0)) < target:
			return false
	return true

func build_progress_lines(objective: Dictionary, progress: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for requirement in objective.get("requirements", []):
		var metric := String(requirement.get("metric", ""))
		var target := int(requirement.get("target", 0))
		var label := String(requirement.get("label", metric))
		lines.append("%s %d/%d" % [label, int(progress.get(metric, 0)), target])
	return lines

func build_summary(objective: Dictionary, progress: Dictionary) -> String:
	if objective.is_empty():
		return "本周暂无目标"
	var lines: Array[String] = []
	lines.append(String(objective.get("title", "本周目标")))
	for line in build_progress_lines(objective, progress):
		lines.append(line)
	return " ｜ ".join(lines)

func get_reward_bundle_id(objective: Dictionary) -> String:
	return String(objective.get("reward_bundle_id", ""))

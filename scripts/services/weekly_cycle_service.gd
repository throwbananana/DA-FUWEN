class_name WeeklyCycleService
extends RefCounted

const GUIDED_INTRO_METRICS := {
	"visit_count": true,
	"build_count": true,
	"encounter_count": true,
}

func pick_objective(season_id: String, week_index: int) -> Dictionary:
	var pool: Array = DataRepository.get_weekly_objectives_for_season(season_id)
	if GameState.is_guided_intro_active():
		var guided_pool := _filter_guided_intro_objectives(pool)
		if not guided_pool.is_empty():
			pool = guided_pool
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

func _filter_guided_intro_objectives(pool: Array) -> Array:
	var filtered: Array = []
	for raw_objective in pool:
		var objective: Dictionary = Dictionary(raw_objective).duplicate(true)
		var requirements: Array = objective.get("requirements", [])
		if requirements.size() != 1:
			continue
		var metric := String(requirements[0].get("metric", ""))
		if GUIDED_INTRO_METRICS.has(metric):
			filtered.append(objective)
	return filtered

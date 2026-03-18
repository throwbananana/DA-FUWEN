class_name RunModifierService
extends RefCounted

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func choose_run_modifiers(count: int = 1) -> Array:
	var pool: Array = DataRepository.get_run_modifiers()
	var result: Array = []
	var available: Array = pool.duplicate(true)
	for _index in range(count):
		if available.is_empty():
			break
		var choice_index := _roll_weighted_index(available)
		result.append(Dictionary(available[choice_index]).duplicate(true))
		available.remove_at(choice_index)
	return result

func apply_starting_bonus(modifiers: Array) -> Dictionary:
	var systems := {}
	for modifier in modifiers:
		var effects: Dictionary = modifier.get("effects", {})
		if effects.has("season_adjust_bonus"):
			systems["season_adjust_points"] = int(systems.get("season_adjust_points", 0)) + int(effects.get("season_adjust_bonus", 0))
	return systems

func apply_weekly_bonus(modifiers: Array) -> Dictionary:
	var systems := {}
	for modifier in modifiers:
		var effects: Dictionary = modifier.get("effects", {})
		if effects.has("weekly_bonus_season_points"):
			systems["season_points"] = int(systems.get("season_points", 0)) + int(effects.get("weekly_bonus_season_points", 0))
	return systems

func apply_visit_reward_modifiers(reward: Dictionary, modifiers: Array) -> Dictionary:
	var result: Dictionary = reward.duplicate(true)
	for modifier in modifiers:
		var effects: Dictionary = modifier.get("effects", {})
		var item_id := String(effects.get("visit_bonus_item", ""))
		if item_id.is_empty():
			continue
		result[item_id] = int(result.get(item_id, 0)) + int(effects.get("visit_bonus_amount", 0))
	return result

func format_lines(modifiers: Array) -> Array[String]:
	var lines: Array[String] = []
	for modifier in modifiers:
		lines.append("%s：%s" % [String(modifier.get("name", "词缀")), String(modifier.get("description", ""))])
	return lines

func _roll_weighted_index(pool: Array) -> int:
	var total_weight := 0
	for modifier in pool:
		total_weight += maxi(1, int(modifier.get("weight", 1)))
	var pick := rng.randi_range(1, maxi(1, total_weight))
	var cursor := 0
	for index in range(pool.size()):
		cursor += maxi(1, int(pool[index].get("weight", 1)))
		if pick <= cursor:
			return index
	return 0

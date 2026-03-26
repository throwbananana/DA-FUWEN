class_name NurseryService
extends RefCounted

func supports_nursery(habitat_id: String) -> bool:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return false
	return Array(habitat.get("buildings", [])).has("nursery_corner")

func build_arrival_lines(habitat_id: String) -> Array[String]:
	if not supports_nursery(habitat_id):
		return []
	var access := GameState.get_nursery_access_report(habitat_id)
	var project := GameState.get_nursery_project(habitat_id)
	var lines: Array[String] = []
	if project.is_empty():
		var candidate_count := GameState.get_nursery_candidate_species(habitat_id).size()
		if bool(access.get("ok", false)):
			lines.append("[b]孵育位[/b] 空置（已记录本地样本 %d 种）" % candidate_count)
		else:
			lines.append("[b]孵育位[/b] %s" % _access_reason_text(access))
		return lines
	lines.append("[b]孵育位[/b] %s" % _project_progress_text(project))
	lines.append("[b]今日偏好[/b] %s" % _action_name(String(project.get("current_need_action", "observe"))))
	return lines

func build_habitat_status_text(habitat_id: String) -> String:
	if not supports_nursery(habitat_id):
		return ""
	var access := GameState.get_nursery_access_report(habitat_id)
	var project := GameState.get_nursery_project(habitat_id)
	if project.is_empty():
		return "孵育位空置" if bool(access.get("ok", false)) else _access_reason_text(access)
	return _project_progress_text(project)

func build_overview_lines() -> Array[String]:
	var lines: Array[String] = []
	for habitat_id in DataRepository.habitats.keys():
		if not supports_nursery(habitat_id):
			continue
		var access := GameState.get_nursery_access_report(habitat_id)
		var project := GameState.get_nursery_project(habitat_id)
		if project.is_empty() and not bool(access.get("ok", false)):
			continue
		var status_text := build_habitat_status_text(habitat_id)
		if status_text.is_empty():
			continue
		lines.append("%s：%s" % [String(DataRepository.get_habitat(habitat_id).get("name", habitat_id)), status_text])
	return lines

func get_menu(habitat_id: String) -> Dictionary:
	var access := GameState.get_nursery_access_report(habitat_id)
	var project := GameState.get_nursery_project(habitat_id)
	var lines: Array[String] = []
	var choices: Array = []
	lines.append("[b]设施[/b] 幼护角 Lv.%d ｜ 暖窝 Lv.%d" % [
		int(access.get("primary_level", GameState.get_building_level(habitat_id, "nursery_corner"))),
		int(access.get("support_level", GameState.get_building_level(habitat_id, "warm_nest"))),
	])
	var resident := GameState.get_habitat_resident_actor(habitat_id)
	lines.append("[b]看守[/b] %s" % (GameState.get_actor_display_name(String(resident.get("uid", ""))) if not resident.is_empty() else "暂无"))
	lines.append("[b]季节加护[/b] %s" % ("春芽季提供额外孵化推进" if GameState.season_id == "spring" else "当前按常规推进"))
	if not bool(access.get("ok", false)):
		lines.append("[b]当前状态[/b] %s" % _access_reason_text(access))
		return {
			"ok": false,
			"title": "照料孵育",
			"body": "\n".join(lines),
			"choices": choices,
		}
	if project.is_empty():
		var candidates := GameState.get_nursery_candidate_species(habitat_id)
		lines.append("[b]当前状态[/b] 还没有在孵的幼体。")
		lines.append("[b]已记录本地样本[/b] %d 种" % candidates.size())
		if candidates.is_empty():
			lines.append("先在这里遇见、观察或结缘过目标个体，才能把它写进孵育记录。")
		else:
			lines.append("已经能从本地记录里挑一个样本，开始慢慢照看。")
		choices.append({
			"id": "start_incubation",
			"label": "开始孵化",
			"summary": "从已记录的本地个体里挑一个，建立孵育项目。",
			"disabled": candidates.is_empty(),
		})
		return {
			"ok": true,
			"title": "照料孵育",
			"body": "\n".join(lines),
			"choices": choices,
		}
	lines.append("[b]当前孵化[/b] %s" % String(DataRepository.get_species(String(project.get("species_id", ""))).get("name", project.get("species_id", ""))))
	lines.append("[b]进度[/b] %s" % _project_progress_text(project))
	lines.append("[b]今日偏好[/b] %s" % _action_name(String(project.get("current_need_action", "observe"))))
	lines.append("[b]照料质量[/b] %d" % int(project.get("care_points", 0)))
	if bool(project.get("ready_to_hatch", false)):
		lines.append("壳已经有回应了，现在就可以迎接破壳。")
		choices.append({
			"id": "hatch_incubation",
			"label": "迎接破壳",
			"summary": "把已经准备好的幼体接回身边，好好照看。",
		})
	else:
		var cared_today := int(project.get("last_care_turn", -1)) == GameState.global_turn
		lines.append("[b]今日照料[/b] %s" % ("已经做过一轮" if cared_today else "还可以再照看一次"))
		choices.append({
			"id": "care_incubation",
			"label": "继续养育",
			"summary": "按它现在最需要的方式再推进一轮。",
			"disabled": cared_today,
		})
	return {
		"ok": true,
		"title": "照料孵育",
		"body": "\n".join(lines),
		"choices": choices,
	}

func get_candidate_picker(habitat_id: String) -> Dictionary:
	var candidates := GameState.get_nursery_candidate_species(habitat_id)
	var choices: Array = []
	for species_id in candidates:
		var species := DataRepository.get_species(String(species_id))
		var actions := _action_labels(species.get("care_actions", []))
		choices.append({
			"id": String(species_id),
			"label": String(species.get("name", species_id)),
			"summary": "%s ｜ 偏好 %s ｜ %s" % [
				_rarity_name(String(species.get("rarity", "common"))),
				" / ".join(actions.slice(0, 2)),
				_relationship_note(String(species_id)),
			],
		})
	return {
		"title": "选择孵育样本",
		"body": "从这片地方已经记下的个体里挑一个，作为接下来要重点照看的目标。",
		"choices": choices,
	}

func get_care_picker(habitat_id: String) -> Dictionary:
	var project := GameState.get_nursery_project(habitat_id)
	var choices: Array = []
	for raw_action in _coerce_action_ids(project.get("preferred_actions", [])):
		var action_id := String(raw_action)
		choices.append({
			"id": action_id,
			"label": _action_name(action_id),
			"summary": "当前%s%s" % [
				"最需要" if String(project.get("current_need_action", "")) == action_id else "也能接受",
				"这一步" if String(project.get("current_need_action", "")) == action_id else "，但推进会慢一点",
			],
		})
	return {
		"title": "今天怎么照看",
		"body": "根据壳内回应，今天它更想要的是：%s。" % _action_name(String(project.get("current_need_action", "observe"))),
		"choices": choices,
	}

func format_project_result(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return _access_reason_text(result)
	var project: Dictionary = result.get("project", {})
	var species_id := String(result.get("species_id", project.get("species_id", "")))
	var species_name := String(DataRepository.get_species(species_id).get("name", species_id))
	if result.has("pet_uid"):
		return "%s 已经顺利破壳，并加入了照料名册。\n起始信赖 %d。" % [species_name, int(result.get("starting_bond", 1))]
	if result.has("action_id"):
		var lines: Array[String] = [
			"%s 接受了这轮照料。" % species_name,
			"进度 +%d ｜ 当前 %s" % [int(result.get("progress_delta", 0)), _project_progress_text(project)],
		]
		if bool(result.get("ready_to_hatch", false)):
			lines.append("已经能听见壳内回应，下一步就可以迎接破壳。")
		else:
			lines.append("新的偏好变成了：%s。" % _action_name(String(project.get("current_need_action", "observe"))))
		return "\n".join(lines)
	return "%s 已经安顿进孵育位了。\n离破壳还差：%s。" % [species_name, _project_progress_text(project)]

func _relationship_note(species_id: String) -> String:
	var bonded: Dictionary = GameState.quest_memory.get("bonded_species", {})
	if bool(Dictionary(bonded).get(species_id, false)):
		return "已经结缘"
	var observed: Dictionary = GameState.quest_memory.get("observed_species", {})
	if bool(Dictionary(observed).get(species_id, false)):
		return "已经观察过"
	return "已经遇见过"

func _project_progress_text(project: Dictionary) -> String:
	var species_id := String(project.get("species_id", ""))
	var species_name := String(DataRepository.get_species(species_id).get("name", species_id))
	var suffix := " ｜ 可破壳" if bool(project.get("ready_to_hatch", false)) else ""
	return "%s %d / %d%s" % [
		species_name,
		int(project.get("progress", 0)),
		int(project.get("required_progress", 1)),
		suffix,
	]

func _access_reason_text(access: Dictionary) -> String:
	match String(access.get("reason", "")):
		"nursery_locked":
			return "幼护角还没收拾出来，或暖窝还没稳到能单独开孵育位。"
		"resident_required":
			return "这里得先安排一位看守，幼体才会安心。"
		"incubation_active":
			return "这里已经有一个在孵的项目了。"
		"species_not_recorded":
			return "先在这里记录过这个物种，再来建立孵育项目。"
		"species_missing":
			return "这条样本记录今天没法继续用了。"
		"nursery_missing":
			return "这里眼下还没有能展开孵育的设施。"
		"no_incubation":
			return "这里现在还没有正在孵育的项目。"
		"care_already_done":
			return "这一回合已经照看过一次了，先让它安稳待一会儿。"
		"invalid_care_action":
			return "这一步不太对路，换个更合适的照料方式。"
		"incubation_not_ready":
			return "现在还没到破壳的时候，再照看几轮。"
		"incubation_ready":
			return "它已经准备破壳了，不用再重复照料。"
		_:
			return "这一步现在还做不了。"

func _action_name(action_id: String) -> String:
	match action_id:
		"feed":
			return "投喂"
		"calm":
			return "安抚"
		"observe":
			return "观察"
		"guide":
			return "引导"
		"hum":
			return "轻声哼唱"
		"shelter":
			return "提供遮蔽"
		"brush":
			return "梳理茸毛"
		"soak":
			return "浅水浸润"
		"pat":
			return "轻拍安定"
		"play":
			return "陪它活动"
		"track":
			return "顺着痕迹观察"
		_:
			return action_id

func _rarity_name(rarity: String) -> String:
	match rarity:
		"uncommon":
			return "少见"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return "常见"

func _coerce_action_ids(value: Variant) -> Array[String]:
	var actions: Array[String] = []
	for raw_action in Array(value):
		var action_id := String(raw_action)
		if action_id.is_empty():
			continue
		actions.append(action_id)
	return actions

func _action_labels(value: Variant) -> Array[String]:
	var labels: Array[String] = []
	for action_id in _coerce_action_ids(value):
		labels.append(_action_name(action_id))
	return labels

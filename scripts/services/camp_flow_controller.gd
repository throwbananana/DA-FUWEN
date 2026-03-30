class_name CampFlowController
extends Node

const HabitatServiceScript = preload("res://scripts/services/habitat_service.gd")

signal state_changed(step_id: String, payload: Dictionary)

var habitat_service = HabitatServiceScript.new()

func open_team_manage_menu() -> void:
	state_changed.emit("team_manage", {
		"title": "营地整备",
		"body": "营地只在路过时弹出；队伍、看守和留信都改到这里统一处理。",
		"choices": [
			{"id": "battle_0", "label": "出战位 1", "summary": "当前：%s" % _battle_slot_name_at(0)},
			{"id": "battle_1", "label": "出战位 2", "summary": "当前：%s" % _battle_slot_name_at(1)},
			{"id": "backpack", "label": "调整宠物栏", "summary": "当前：%d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity]},
			{"id": "resident_sites", "label": "安排看守", "summary": "在营地统一调整各据点的主看守。"},
			{"id": "mail_menu", "label": "处理留信", "summary": "当前待处理：%d 处" % _pending_mail_targets().size(), "disabled": _pending_mail_targets().is_empty()},
		],
	})

func choose_team_manage_action(choice_id: String) -> void:
	match choice_id:
		"battle_0":
			open_team_battle_slot_picker(0)
		"battle_1":
			open_team_battle_slot_picker(1)
		"backpack":
			open_team_reserve_picker()
		"resident_sites":
			open_camp_resident_site_picker()
		"mail_menu":
			open_camp_mail_menu()

func open_team_battle_slot_picker(slot_index: int) -> void:
	var choices := []
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		choices.append({
			"id": pet_uid,
			"label": "%s ★%d" % [String(companion.get("display_name", "未命名伙伴")), int(companion.get("star_level", 1))],
			"summary": "%s ｜ 当前：%s" % [String(companion.get("species_id", "")), _companion_slot_label(pet_uid)],
		})
	state_changed.emit("team_battle_slot", {
		"title": "选择出战位 %d" % (slot_index + 1),
		"body": "挑一只本场直接上阵的伙伴。",
		"slot_index": slot_index,
		"choices": choices,
	})

func assign_team_battle_slot(slot_index: int, pet_uid: String) -> void:
	GameState.set_party_slot(slot_index, pet_uid)
	state_changed.emit("team_result", {
		"title": "队伍已更新",
		"body": "%s 已被放到出战位 %d。" % [GameState.get_pet_display_name(pet_uid), slot_index + 1],
	})

func open_team_reserve_picker() -> void:
	var choices := []
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		var in_reserve := GameState.get_reserve_uids().has(pet_uid)
		choices.append({
			"id": pet_uid,
			"label": "%s ★%d" % [String(companion.get("display_name", "未命名伙伴")), int(companion.get("star_level", 1))],
			"summary": "%s ｜ 人口 %d ｜ %s" % [String(companion.get("species_id", "")), GameState.get_pet_population_cost(pet_uid), "当前已在休息位" if in_reserve else "当前未在休息位"],
			"disabled": GameState.get_party_uids().has(pet_uid),
		})
	state_changed.emit("team_reserve_slot", {
		"title": "调整宠物栏",
		"body": "留在后头的伙伴这回合不上场，但也会给羁绊；每只占的照看份额不一样。元素、生态和职能按独特物种计数，特性羁绊按实际单位计数。",
		"choices": choices,
	})

func toggle_team_reserve_slot(pet_uid: String) -> void:
	GameState.toggle_reserve_slot(pet_uid)
	state_changed.emit("team_result", {
		"title": "宠物栏已更新",
		"body": "已切换 %s 的待命状态。" % GameState.get_pet_display_name(pet_uid),
	})

func open_camp_resident_site_picker() -> void:
	var choices := []
	for habitat_id in GameState.habitats.keys():
		var habitat := DataRepository.get_habitat(String(habitat_id))
		if habitat.is_empty() or String(habitat.get("type", "")) != "habitat":
			continue
		if not GameState.is_habitat_unlocked(String(habitat_id)):
			continue
		var state: Dictionary = GameState.habitats.get(String(habitat_id), {})
		var resident_actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		choices.append({
			"id": String(habitat_id),
			"label": String(habitat.get("name", habitat_id)),
			"summary": "当前看守：%s ｜ 据点等级 %d" % [
				GameState.get_actor_display_name(resident_actor_id) if not resident_actor_id.is_empty() else "暂无",
				int(state.get("rank", 0)),
			],
		})
	state_changed.emit("camp_resident_site", {
		"title": "选择看守地点",
		"body": "先挑一个要在营地里统一调整的据点。",
		"choices": choices,
	})

func open_camp_resident_picker(habitat_id: String) -> void:
	var choices := [{
		"id": GameState.PLAYER_ACTOR_ID,
		"label": "玩家",
		"summary": "由玩家本人临时看守这里；更适合先顶上空缺。",
	}]
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		var home_id := String(companion.get("residence_habitat_id", ""))
		choices.append({
			"id": pet_uid,
			"label": String(companion.get("display_name", "未命名伙伴")),
			"summary": "当前安居：%s ｜ 偏好：%s" % [
				_habitat_name(home_id) if not home_id.is_empty() else "暂未安居",
				", ".join(companion.get("resident_tags", [])),
			],
		})
	state_changed.emit("camp_resident_select", {
		"title": "安排看守",
		"body": "为 %s 挑一个更合适的看守者。" % _habitat_name(habitat_id),
		"habitat_id": habitat_id,
		"choices": choices,
	})

func assign_resident_to_habitat(habitat_id: String, pet_uid: String) -> void:
	var result := habitat_service.assign_resident(habitat_id, pet_uid)
	result["pet_uid"] = pet_uid
	result["habitat_id"] = habitat_id
	state_changed.emit("camp_resident_result", result)

func open_camp_mail_menu() -> void:
	var targets := _pending_mail_targets()
	if targets.is_empty():
		state_changed.emit("camp_mail_menu", {
			"title": "处理留信",
			"body": "目前没有需要寄出的跨点消息。",
			"choices": [],
			"empty": true,
		})
		return
	var choices := []
	for destination in targets:
		choices.append({
			"id": destination,
			"label": _habitat_name(destination),
			"summary": "把今天要转交的留信送往这里。",
		})
	state_changed.emit("camp_mail_menu", {
		"title": "处理留信",
		"body": "在营地统一处理今天的跨点消息。",
		"choices": choices,
		"empty": false,
	})

func send_camp_mail(destination: String) -> void:
	GameState.note_mail(destination)
	state_changed.emit("camp_mail_result", {
		"ok": true,
		"destination": destination,
		"body": "今天处理了一封送往 %s 的消息。" % _habitat_name(destination),
		"log_line": "你在营地寄出了送往 %s 的留信。" % _habitat_name(destination),
	})

func _pending_mail_targets() -> Array[String]:
	var targets: Array[String] = []
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		for step in quest.get("steps", []):
			if String(step.get("type", "")) != "mail":
				continue
			var destination := String(step.get("destination", ""))
			if destination.is_empty() or bool(GameState.quest_memory["mailed_destinations"].get(destination, false)):
				continue
			if not targets.has(destination):
				targets.append(destination)
	return targets

func _habitat_name(habitat_id: String) -> String:
	if habitat_id.is_empty():
		return "营地"
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return habitat_id
	return String(habitat.get("name", habitat_id))

func _battle_slot_name_at(slot_index: int) -> String:
	var slot_uid := String(GameState.get_battle_party_uids()[slot_index] if slot_index < GameState.get_battle_party_uids().size() else "")
	if slot_uid.is_empty():
		return "未配置"
	return GameState.get_pet_display_name(slot_uid)

func _companion_slot_label(pet_uid: String) -> String:
	if GameState.get_party_uids().has(pet_uid):
		return "上阵"
	if GameState.get_reserve_uids().has(pet_uid):
		return "休息中"
	for habitat_state in GameState.habitats.values():
		if String(habitat_state.get("resident_uid", "")) == pet_uid or String(habitat_state.get("assistant_uid", "")) == pet_uid:
			return "看守"
	return "休息中"

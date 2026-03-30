class_name VisitFlowController
extends Node

## 管理一次“出门 -> 落点偶遇 -> 互动 -> 结算”的流程。
## 你可以把它挂到 visit 场景或主场景里。

const HabitatServiceScript = preload("res://scripts/services/habitat_service.gd")
const BuildingInteractionServiceScript = preload("res://scripts/services/building_interaction_service.gd")
const NpcServiceScript = preload("res://scripts/services/npc_service.gd")
const EncounterServiceScript = preload("res://scripts/services/encounter_service.gd")
const DojoServiceScript = preload("res://scripts/services/dojo_service.gd")
const ShopServiceScript = preload("res://scripts/services/shop_service.gd")
const FishingServiceScript = preload("res://scripts/services/fishing_service.gd")
const NurseryServiceScript = preload("res://scripts/services/nursery_service.gd")

signal visit_started(habitat_id: String)
signal state_changed(step_id: String, payload: Dictionary)
signal visit_finished(report: Dictionary)

var habitat_service = HabitatServiceScript.new()
var building_interaction_service = BuildingInteractionServiceScript.new()
var npc_service = NpcServiceScript.new()
var encounter_service = EncounterServiceScript.new()
var dojo_service = DojoServiceScript.new()
var shop_service = ShopServiceScript.new()
var fishing_service = FishingServiceScript.new()
var nursery_service = NurseryServiceScript.new()

var current_habitat_id := ""
var current_step := "idle"
var current_encounter := {}
var current_board_node := {}
var pending_npc_duel_id := ""
var pending_dojo_id := ""
var pending_dojo_tier := ""

func reset() -> void:
	current_habitat_id = ""
	current_step = "idle"
	current_encounter.clear()
	current_board_node.clear()
	pending_npc_duel_id = ""
	pending_dojo_id = ""
	pending_dojo_tier = ""

func start_visit(habitat_id: String, board_node: Dictionary = {}) -> void:
	current_habitat_id = habitat_id
	current_encounter.clear()
	current_board_node = board_node.duplicate(true)
	current_step = "arrival"
	var payload: Dictionary = _build_arrival_payload(habitat_id)
	visit_started.emit(habitat_id)
	state_changed.emit("arrival", payload)

func open_build_menu() -> void:
	current_step = "build_select"
	state_changed.emit("build_select", {
		"habitat_id": current_habitat_id,
		"buildings": DataRepository.get_buildings_for_habitat(current_habitat_id)
	})

func build_selected(building_id: String) -> void:
	var result: Dictionary = habitat_service.build_on_site(current_habitat_id, building_id)
	current_step = "build_result"
	state_changed.emit("build_result", result)

func open_building_action_menu() -> void:
	current_step = "building_action_select"
	state_changed.emit("building_action_select", {
		"habitat_id": current_habitat_id,
		"actions": building_interaction_service.get_interaction_menu(current_habitat_id)
	})

func use_building_action(building_id: String, action_id: String) -> void:
	var result: Dictionary = building_interaction_service.execute_action(current_habitat_id, building_id, action_id)
	current_step = "building_action_result"
	state_changed.emit("building_action_result", result)

func open_shop_menu() -> void:
	current_step = "shop_menu"
	state_changed.emit("shop_menu", shop_service.get_shop_menu(current_habitat_id))

func buy_shop_offer(offer_id: String) -> void:
	current_step = "shop_result"
	state_changed.emit("shop_result", shop_service.buy_offer(current_habitat_id, offer_id))

func use_shop_npc_service(service_id: String) -> void:
	current_step = "shop_npc_result"
	state_changed.emit("shop_npc_result", shop_service.use_npc_service(current_habitat_id, service_id))

func open_npc_menu() -> void:
	current_step = "npc_menu"
	state_changed.emit("npc_menu", {
		"habitat_id": current_habitat_id,
		"title": "你在这里遇到的人",
		"body": "第一次见面先过过招，熟了之后再慢慢聊。",
		"choices": _build_npc_menu_choices(),
	})

func choose_npc_action(choice_id: String) -> void:
	if choice_id.begins_with("duel:"):
		_prepare_npc_intro_duel(choice_id.trim_prefix("duel:"))
		return
	if choice_id.begins_with("talk:"):
		_prepare_npc_talk(choice_id.trim_prefix("talk:"))
		return
	if choice_id.begins_with("quest:"):
		_prepare_quest_acceptance(choice_id.trim_prefix("quest:"))
		return

func resolve_npc_intro_duel(battle_result: Dictionary) -> void:
	if pending_npc_duel_id.is_empty():
		return
	current_step = "npc_duel_result"
	state_changed.emit("npc_duel_result", npc_service.resolve_intro_duel(pending_npc_duel_id, battle_result))
	pending_npc_duel_id = ""

func open_resident_picker() -> void:
	current_step = "resident_select"
	var choices := [{
		"id": GameState.PLAYER_ACTOR_ID,
		"label": "玩家",
		"summary": "由玩家本人临时看守这里；适合先补上空缺。",
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
	state_changed.emit("resident_select", {
		"title": "安排看守",
		"body": "挑一个更适合看着这里的人或伙伴。",
		"choices": choices,
	})

func assign_resident(pet_uid: String) -> void:
	current_step = "resident_result"
	var result := habitat_service.assign_resident(current_habitat_id, pet_uid)
	result["pet_uid"] = pet_uid
	result["habitat_id"] = current_habitat_id
	state_changed.emit("resident_result", result)

func open_mail_menu() -> void:
	current_step = "mail_menu"
	var targets := _pending_mail_targets()
	if targets.is_empty():
		state_changed.emit("mail_menu", {
			"title": "寄送留信",
			"body": "目前没有需要寄送的跨点消息。",
			"choices": [],
		})
		return
	var choices := []
	for destination in targets:
		choices.append({
			"id": destination,
			"label": _habitat_name(destination),
			"summary": "把今天的信件和托付送过去。",
		})
	state_changed.emit("mail_menu", {
		"title": "寄送留信",
		"body": "挑一个今天要处理的目标地点。",
		"choices": choices,
	})

func send_mail(destination: String) -> void:
	current_step = "mail_result"
	GameState.note_mail(destination)
	state_changed.emit("mail_result", {
		"ok": true,
		"destination": destination,
		"body": "今天处理了一封送往 %s 的消息。" % _habitat_name(destination),
		"log_line": "寄出了送往 %s 的留信。" % _habitat_name(destination),
	})

func open_dojo_menu() -> void:
	current_step = "dojo_menu"
	state_changed.emit("dojo_menu", dojo_service.get_dojo_menu(current_habitat_id))

func choose_dojo_tier(tier: String) -> void:
	var dojo := dojo_service.get_dojo_for_habitat(current_habitat_id)
	var result := dojo_service.prepare_dojo_battle(String(dojo.get("id", "")), tier)
	if not bool(result.get("ok", false)):
		current_step = "dojo_result"
		state_changed.emit("dojo_result", result)
		return
	pending_dojo_id = String(dojo.get("id", ""))
	pending_dojo_tier = tier
	current_step = "dojo_battle"
	state_changed.emit("dojo_battle", result)

func resolve_dojo_battle(battle_result: Dictionary) -> void:
	if pending_dojo_id.is_empty() or pending_dojo_tier.is_empty():
		return
	current_step = "dojo_result"
	state_changed.emit("dojo_result", dojo_service.resolve_dojo_battle(pending_dojo_id, pending_dojo_tier, battle_result))
	pending_dojo_id = ""
	pending_dojo_tier = ""

func start_observation() -> void:
	var source: String = GameState.consume_next_observation_source(current_habitat_id)
	current_encounter = encounter_service.roll_encounter(current_habitat_id, source)
	current_step = "encounter_preview"
	state_changed.emit("encounter_preview", current_encounter)

func start_observation_for_habitat(habitat_id: String, source: String = "observe") -> void:
	current_habitat_id = habitat_id
	var actual_source := source
	if actual_source == "observe":
		actual_source = GameState.consume_next_observation_source(current_habitat_id)
	current_encounter = encounter_service.roll_encounter(current_habitat_id, actual_source)
	current_step = "encounter_preview"
	state_changed.emit("encounter_preview", current_encounter)

func choose_encounter_action(action_id: String) -> void:
	if current_encounter.is_empty():
		return
	var result: Dictionary = encounter_service.resolve_action(current_encounter, action_id)
	current_step = "encounter_result"
	state_changed.emit("encounter_result", result)

func open_fishing_menu() -> void:
	current_step = "fishing_menu"
	state_changed.emit("fishing_menu", fishing_service.build_fishing_menu(current_habitat_id))

func choose_fishing_action(choice_id: String) -> void:
	current_step = "fishing_result"
	state_changed.emit("fishing_result", fishing_service.resolve_fishing_choice(current_habitat_id, choice_id))

func open_nursery_menu() -> void:
	current_step = "nursery_menu"
	state_changed.emit("nursery_menu", nursery_service.get_menu(current_habitat_id))

func open_nursery_species_picker() -> void:
	current_step = "nursery_species_select"
	state_changed.emit("nursery_species_select", nursery_service.get_candidate_picker(current_habitat_id))

func open_nursery_care_picker() -> void:
	current_step = "nursery_care_select"
	state_changed.emit("nursery_care_select", nursery_service.get_care_picker(current_habitat_id))

func hatch_nursery_project() -> void:
	current_step = "nursery_result"
	state_changed.emit("nursery_result", GameState.hatch_nursery_project(current_habitat_id))

func start_nursery_project(species_id: String) -> void:
	current_step = "nursery_result"
	state_changed.emit("nursery_result", GameState.start_nursery_project(current_habitat_id, species_id))

func care_nursery_project(action_id: String) -> void:
	current_step = "nursery_result"
	state_changed.emit("nursery_result", GameState.care_nursery_project(current_habitat_id, action_id))

func finish_visit() -> void:
	if not current_habitat_id.is_empty():
		GameState.note_visit(current_habitat_id)
	var report := {
		"habitat_id": current_habitat_id,
		"step": current_step,
		"timestamp": Time.get_unix_time_from_system()
	}
	GameState.record_visit(report)
	reset()
	visit_finished.emit(report)

func start_stop_encounter(habitat_id: String) -> void:
	start_visit(habitat_id)

func finish_stop_encounter() -> void:
	finish_visit()

func _build_arrival_payload(habitat_id: String) -> Dictionary:
	var payload: Dictionary = habitat_service.get_visit_summary(habitat_id)
	var habitat: Dictionary = payload.get("habitat", {})
	var buildings: Array = payload.get("buildings", [])
	var npcs: Array = payload.get("npcs", [])
	var primary_action := _primary_content_action(current_board_node, habitat, buildings, npcs)
	var guided_intro := GameState.is_guided_intro_active()
	payload["guided_intro"] = guided_intro
	payload["primary_action"] = primary_action
	payload["primary_action_label"] = _primary_content_label(primary_action)
	payload["primary_action_summary"] = _primary_content_summary(primary_action)
	payload["choices"] = _build_arrival_choices(habitat, primary_action, guided_intro)
	return payload

func _build_arrival_choices(habitat: Dictionary, primary_action: String, guided_intro: bool) -> Array:
	var choices := []
	if not primary_action.is_empty():
		choices.append({
			"id": primary_action,
			"label": _primary_content_label(primary_action),
			"summary": "%s\n这就是你到这儿后最值得先顾上的那件事。" % _primary_content_summary(primary_action),
		})
	elif not guided_intro and nursery_service.supports_nursery(current_habitat_id):
		choices.append({
			"id": "nursery_menu",
			"label": "照料孵育",
			"summary": "查看这里的孵育位，安排孵化或继续照看幼体。",
		})
	elif not guided_intro and String(habitat.get("type", "")) == "habitat":
		choices.append({
			"id": "assign_resident",
			"label": "安排看守",
			"summary": "把这里交给更合适的人或伙伴看着。",
		})
	return choices

func _primary_content_action(node: Dictionary, habitat: Dictionary, buildings: Array, npcs: Array) -> String:
	var requested := String(node.get("primary_content", ""))
	var fallback_actions := ["fishing_menu", "dojo_menu", "build_menu", "npc_menu", "observe", "mail_menu"]
	if GameState.is_guided_intro_active():
		fallback_actions = ["build_menu", "observe", "npc_menu"]
	if not requested.is_empty() and _is_primary_action_available(requested, habitat, buildings, npcs):
		return requested
	for fallback_action in fallback_actions:
		if fallback_action == requested:
			continue
		if _is_primary_action_available(fallback_action, habitat, buildings, npcs):
			return fallback_action
	return ""

func _is_primary_action_available(action_id: String, habitat: Dictionary, buildings: Array, npcs: Array) -> bool:
	if GameState.is_guided_intro_active() and not ["build_menu", "npc_menu", "observe"].has(action_id):
		return false
	match action_id:
		"build_menu":
			return not buildings.is_empty()
		"shop_menu":
			return not DataRepository.get_shop(String(habitat.get("id", ""))).is_empty()
		"npc_menu":
			return not npcs.is_empty()
		"observe":
			return not Array(habitat.get("wild_pool", [])).is_empty()
		"fishing_menu":
			return fishing_service.has_fishing_spot(String(habitat.get("id", "")))
		"dojo_menu":
			return not String(habitat.get("dojo_id", "")).is_empty()
		"mail_menu":
			return String(habitat.get("type", "")) == "settlement"
		_:
			return false

func _primary_content_label(action_id: String) -> String:
	match action_id:
		"build_menu":
			return "推进建设"
		"shop_menu":
			return "补给采购"
		"npc_menu":
			return "和人聊聊"
		"observe":
			return "观察环境"
		"fishing_menu":
			return "去钓鱼"
		"dojo_menu":
			return "进行试炼"
		"mail_menu":
			return "处理留信"
		_:
			return "先做这件事"

func _primary_content_summary(action_id: String) -> String:
	match action_id:
		"build_menu":
			return "这里最值得先做的是推进建设，能直接改善后续收益和驻守效果。"
		"shop_menu":
			return "这里更适合先补给、买材料，顺手把本周短缺补齐。"
		"npc_menu":
			return "这里先和人聊聊更划算，通常能推进关系、委托或后续事件。"
		"observe":
			return "先观察环境，能更稳地拿到记录、线索或后续互动机会。"
		"fishing_menu":
			return "这里可以直接钓鱼，常用于补资源、做记录或推进相关事件。"
		"dojo_menu":
			return "这里适合检验当前队伍配置，也可能推进阶段目标。"
		"mail_menu":
			return "这里适合先处理跨点消息，顺手推进委托和地点近况。"
		_:
			return "先做当前收益最高的一步。"

func _build_npc_menu_choices() -> Array:
	var choices := []
	for npc in npc_service.get_visible_npcs(current_habitat_id):
		var npc_id := String(npc.get("id", ""))
		var intro_pending := npc_service.needs_intro_duel(npc_id)
		var duel_status := npc_service.get_intro_duel_status(npc_id)
		choices.append({
			"id": "duel:%s" % npc_id if intro_pending else "talk:%s" % npc_id,
			"label": "%s（先决斗）" % String(npc.get("name", "未命名 NPC")) if intro_pending else String(npc.get("name", "未命名 NPC")),
			"summary": "第一次见面先切磋一场；赢了更容易聊开，输了也还能慢慢熟起来。" if intro_pending else "今天可以好好聊聊。当前信赖 %d ｜ %s" % [npc_service.get_npc_trust(npc_id), "首战赢过" if bool(duel_status.get("won", false)) else "还在慢慢熟"],
		})
	for quest in npc_service.get_available_quests(current_habitat_id):
		var quest_id := String(quest.get("id", ""))
		if GameState.active_quests.has(quest_id) or GameState.completed_quests.has(quest_id):
			continue
		var giver_id := String(quest.get("giver", ""))
		var giver := DataRepository.get_npc(giver_id)
		var duel_locked := npc_service.needs_intro_duel(giver_id)
		var quest_description := String(quest.get("description", ""))
		var quest_summary := "得先和 %s 过过招，聊熟之后才能接这份委托。" % String(giver.get("name", "委托人")) if duel_locked else "先记在这季安排里，之后回来时会顺手看看进展。"
		if not duel_locked and not quest_description.is_empty():
			quest_summary = quest_description
		choices.append({
			"id": "quest:%s" % quest_id,
			"label": "接委托：%s" % String(quest.get("title", "")),
			"summary": quest_summary,
			"disabled": duel_locked,
		})
	return choices

func _prepare_npc_intro_duel(npc_id: String) -> void:
	var result := npc_service.prepare_intro_duel(npc_id, current_habitat_id)
	if not bool(result.get("ok", false)):
		current_step = "npc_duel_result"
		state_changed.emit("npc_duel_result", {
			"ok": false,
			"reason": String(result.get("reason", "unknown")),
		})
		return
	pending_npc_duel_id = npc_id
	current_step = "npc_duel_battle"
	state_changed.emit("npc_duel_battle", result)

func _prepare_npc_talk(npc_id: String) -> void:
	if npc_service.needs_intro_duel(npc_id):
		current_step = "talk_result"
		state_changed.emit("talk_result", {
			"ok": false,
			"title": "现在还聊不开",
			"body": "第一次见面要先切磋一下，熟了之后再慢慢聊。",
		})
		return
	current_step = "npc_talk_request"
	state_changed.emit("npc_talk_request", {"npc_id": npc_id})

func _prepare_quest_acceptance(quest_id: String) -> void:
	var quest := DataRepository.get_quest(quest_id)
	if quest.is_empty():
		return
	var giver_id := String(quest.get("giver", ""))
	if npc_service.needs_intro_duel(giver_id):
		var giver := DataRepository.get_npc(giver_id)
		current_step = "quest_result"
		state_changed.emit("quest_result", {
			"ok": false,
			"title": "现在还接不了委托",
			"body": "第一次见面要先和 %s 切磋一下，熟了之后才能接这份委托。" % String(giver.get("name", "委托人")),
		})
		return
	var cost := _accept_cost_for_quest(quest)
	if not cost.is_empty() and not GameState.can_pay(cost):
		current_step = "quest_result"
		state_changed.emit("quest_result", {
			"ok": false,
			"title": "暂时接不下",
			"body": "还缺少交付物资：%s" % _format_item_cost(cost),
		})
		return
	if not cost.is_empty():
		GameState.pay_cost(cost)
		for item_id in cost.keys():
			GameState.note_delivery(String(item_id), int(cost[item_id]))
	GameState.accept_quest(quest_id)
	var quest_lines: Array[String] = ["已记下这件事：%s" % String(quest.get("title", ""))]
	var quest_description := String(quest.get("description", ""))
	if not quest_description.is_empty():
		quest_lines.append("")
		quest_lines.append(quest_description)
	current_step = "quest_result"
	state_changed.emit("quest_result", {
		"ok": true,
		"accepted": true,
		"title": "委托记录",
		"body": "\n".join(quest_lines),
		"log_line": "接下委托：%s。" % String(quest.get("title", "")),
	})

func _accept_cost_for_quest(quest: Dictionary) -> Dictionary:
	var cost := {}
	for step in quest.get("steps", []):
		if String(step.get("type", "")) != "deliver":
			continue
		cost[String(step.get("item", ""))] = int(step.get("count", 0))
	return cost

func _format_item_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in cost.keys():
		parts.append("%s ×%d" % [_item_name(String(item_id)), int(cost[item_id])])
	return " / ".join(parts)

func _item_name(item_id: String) -> String:
	return String(DataRepository.get_item(item_id).get("name", item_id))

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

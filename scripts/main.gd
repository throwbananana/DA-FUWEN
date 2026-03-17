extends Control

const BoardView = preload("res://scripts/board_view.gd")
const DecisionPanel = preload("res://scripts/decision_panel.gd")
const BasePanel = preload("res://scripts/base_panel.gd")
const VisitFlowController = preload("res://scripts/services/visit_flow_controller.gd")
const HabitatService = preload("res://scripts/services/habitat_service.gd")
const NpcService = preload("res://scripts/services/npc_service.gd")
const EncounterService = preload("res://scripts/services/encounter_service.gd")

const GAME_TITLE := "雾野养成原型"

const WEATHER_ORDER := ["clear", "fog", "rain", "storm"]
const WEATHER_NAMES := {
	"clear": "晴日",
	"fog": "薄雾",
	"rain": "细雨",
	"storm": "风暴",
}

const TIME_ORDER := ["day", "evening", "night"]
const TIME_NAMES := {
	"day": "白昼",
	"evening": "黄昏",
	"night": "夜晚",
}

const NODE_TEMPLATES := [
	{"id": 0, "name": "营地", "type": "camp", "description": "整理材料、查看笔记，然后决定今天去看望谁。", "position": Vector2(80, 280), "edges": [1, 2, 3], "travel_cost": 0, "habitat_id": ""},
	{"id": 1, "name": "雾苔窟", "type": "habitat", "description": "湿冷又安静的巢居据点，适合慢慢照料。", "position": Vector2(280, 130), "edges": [4], "travel_cost": 1, "habitat_id": "mist_moss_cave"},
	{"id": 2, "name": "晶溪滩", "type": "habitat", "description": "浅水和暖石交错的水边驻点。", "position": Vector2(470, 320), "edges": [5], "travel_cost": 1, "habitat_id": "crystal_creek"},
	{"id": 3, "name": "云升驿", "type": "settlement", "description": "来往消息最灵通的聚落节点。", "position": Vector2(530, 90), "edges": [4, 5], "travel_cost": 1, "habitat_id": "sky_post"},
	{"id": 4, "name": "古械平台", "type": "habitat", "description": "需要慢慢修复的遗迹据点。", "position": Vector2(830, 140), "edges": [6], "travel_cost": 2, "habitat_id": "ancient_platform"},
	{"id": 5, "name": "铜锤集", "type": "settlement", "description": "手作和交换最热闹的工坊聚落。", "position": Vector2(840, 330), "edges": [6], "travel_cost": 1, "habitat_id": "copper_hammer_bazaar"},
	{"id": 6, "name": "裂辉尖塔", "type": "anomaly", "description": "季末才建议踏入的异常区域。", "position": Vector2(1150, 220), "edges": [], "travel_cost": 3, "habitat_id": "radiant_spire"},
]

@onready var title_label: Label = %TitleLabel
@onready var round_label: Label = %RoundLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var player_summary_label: RichTextLabel = %PlayerSummaryLabel
@onready var ai_summary_label: RichTextLabel = %AISummaryLabel
@onready var control_summary_label: RichTextLabel = %ControlSummaryLabel
@onready var dice_label: Label = %DiceLabel
@onready var action_hint_label: RichTextLabel = %ActionHintLabel
@onready var map_hint_label: RichTextLabel = %MapHintLabel
@onready var roster_label: RichTextLabel = %RosterLabel
@onready var event_log_label: RichTextLabel = %EventLogLabel
@onready var roll_button: Button = %RollButton
@onready var plus_button: Button = %PlusButton
@onready var minus_button: Button = %MinusButton
@onready var reroll_button: Button = %RerollButton
@onready var support_button: Button = %SupportButton
@onready var base_button: Button = %BaseButton
@onready var new_game_button: Button = %NewGameButton
@onready var board_view: BoardView = %BoardView
@onready var legacy_battle_panel: Control = %BattlePanel
@onready var decision_panel: DecisionPanel = %DecisionPanel
@onready var base_panel: BasePanel = %BasePanel

var rng := RandomNumberGenerator.new()
var world_nodes: Array = []
var board_lookup := {}

var visit_flow: VisitFlowController
var habitat_service := HabitatService.new()
var npc_service := NpcService.new()
var encounter_service := EncounterService.new()

var season_finished := false
var awaiting_destination := false
var current_node_id := 0
var current_visit_habitat_id := ""
var current_encounter := {}
var last_encounter_action_id := ""
var pending_context := {}

func _ready() -> void:
	rng.randomize()
	title_label.text = GAME_TITLE
	_connect_signals()
	_apply_basic_styles()
	install_visit_flow()
	start_new_game()

func install_visit_flow() -> void:
	visit_flow = VisitFlowController.new()
	add_child(visit_flow)
	visit_flow.state_changed.connect(_on_visit_state_changed)
	visit_flow.visit_finished.connect(_on_visit_finished)

func _connect_signals() -> void:
	roll_button.pressed.connect(_on_start_day_pressed)
	support_button.pressed.connect(_on_support_pressed)
	base_button.pressed.connect(_on_base_pressed)
	new_game_button.pressed.connect(start_new_game)
	board_view.node_chosen.connect(_on_board_node_chosen)
	decision_panel.choice_selected.connect(_on_decision_choice_selected)
	decision_panel.closed.connect(_on_decision_closed)
	base_panel.closed.connect(_on_base_closed)

func _apply_basic_styles() -> void:
	legacy_battle_panel.hide()
	plus_button.hide()
	minus_button.hide()
	reroll_button.hide()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101826")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("334155")
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for panel in [decision_panel, base_panel]:
		panel.add_theme_stylebox_override("panel", panel_style)

func start_new_game() -> void:
	DataRepository.load_all()
	GameState.reset_for_new_season()
	world_nodes = _build_world_nodes()
	board_lookup = _build_board_lookup()
	board_view.setup(world_nodes)
	season_finished = false
	awaiting_destination = false
	current_node_id = 0
	current_visit_habitat_id = ""
	current_encounter.clear()
	last_encounter_action_id = ""
	pending_context.clear()
	decision_panel.hide()
	base_panel.hide()
	_push_log("新的季节开始。目标不再是抢赢谁，而是把伙伴和地点安顿好。")
	_push_log("先从雾苔窟、晶溪滩和云升驿开始回访。")
	_begin_next_day()

func _build_world_nodes() -> Array:
	var nodes: Array = []
	for template in NODE_TEMPLATES:
		var node: Dictionary = template.duplicate(true)
		var habitat_id := String(node.get("habitat_id", ""))
		if not habitat_id.is_empty():
			var habitat := DataRepository.get_habitat(habitat_id)
			if not habitat.is_empty():
				node["name"] = habitat.get("name", node["name"])
				node["description"] = _description_for_habitat(habitat)
				node["travel_cost"] = int(habitat.get("travel_cost", node.get("travel_cost", 1)))
		nodes.append(node)
	return nodes

func _build_board_lookup() -> Dictionary:
	var lookup := {}
	for node in world_nodes:
		lookup[int(node.get("id", -1))] = node
	return lookup

func _description_for_habitat(habitat: Dictionary) -> String:
	var mood_tags: Array = habitat.get("mood_tags", [])
	var actions: Array = habitat.get("visit_actions", [])
	return "%s\n可做的事：%s" % ["、".join(mood_tags), " / ".join(actions)]

func _begin_next_day() -> void:
	if GameState.day_index > GameState.season_length:
		_finish_season()
		return
	awaiting_destination = false
	current_node_id = 0
	current_visit_habitat_id = ""
	current_encounter.clear()
	last_encounter_action_id = ""
	var next_weather: String = String(WEATHER_ORDER[rng.randi_range(0, WEATHER_ORDER.size() - 1)])
	var next_time: String = String(TIME_ORDER[rng.randi_range(0, TIME_ORDER.size() - 1)])
	if GameState.day_index == 1:
		next_weather = "clear"
		next_time = "day"
	GameState.set_daily_conditions(next_weather, next_time)
	_push_log("[第 %d 日] 天气：%s，时段：%s。" % [GameState.day_index, _weather_name(GameState.weather_id), _time_name(GameState.time_of_day)])
	_update_ui()

func _on_start_day_pressed() -> void:
	if season_finished or _is_modal_open():
		return
	if awaiting_destination:
		return
	awaiting_destination = true
	_update_ui()

func _on_support_pressed() -> void:
	var lines: Array[String] = []
	if GameState.active_quests.is_empty():
		lines.append("今天没有挂在手边的生活委托。")
	else:
		lines.append("[b]当前委托[/b]")
		for quest_id in GameState.active_quests:
			lines.append("- %s" % _quest_title(quest_id))
	if not GameState.completed_quests.is_empty():
		lines.append("")
		lines.append("[b]已完成[/b] %d 件" % GameState.completed_quests.size())
	pending_context = {"kind": "quest_journal", "on_close": "none"}
	decision_panel.open_panel("委托记录", "\n".join(lines), [], "关闭")

func _on_base_pressed() -> void:
	base_panel.open_panel({
		"season": {
			"day_index": GameState.day_index,
			"season_length": GameState.season_length,
			"weather_name": _weather_name(GameState.weather_id),
			"time_name": _time_name(GameState.time_of_day),
			"care_progress": GameState.get_care_progress(),
		},
		"inventory": GameState.inventory,
		"companions": _build_companion_summaries(),
		"habitats": _build_habitat_summaries(),
		"active_quests": _quest_titles(GameState.active_quests),
		"completed_quests": GameState.completed_quests.duplicate(),
	})

func _on_board_node_chosen(node_id: int) -> void:
	if season_finished or _is_modal_open():
		return
	if not awaiting_destination or not _get_selectable_nodes().has(node_id):
		return
	awaiting_destination = false
	current_node_id = node_id
	var node: Dictionary = board_lookup[node_id]
	current_visit_habitat_id = String(node.get("habitat_id", ""))
	_push_log("今天前往 %s。" % String(node.get("name", "未知地点")))
	GameState.note_visit(current_visit_habitat_id)
	_check_active_quests()
	visit_flow.start_visit(current_visit_habitat_id)
	_update_ui()

func _on_visit_state_changed(step_id: String, payload: Dictionary) -> void:
	match step_id:
		"arrival":
			_show_arrival_menu(payload)
		"build_select":
			_show_build_menu(payload)
		"build_result":
			_show_build_result(payload)
		"npc_menu":
			_show_npc_menu(payload)
		"encounter_preview":
			_show_encounter_preview(payload)
		"encounter_result":
			_show_encounter_result(payload)

func _show_arrival_menu(payload: Dictionary) -> void:
	var habitat: Dictionary = payload.get("habitat", {})
	var state: Dictionary = payload.get("state", {})
	var resident: Dictionary = payload.get("resident", {})
	var npcs: Array = payload.get("npcs", [])
	var buildings: Array = payload.get("buildings", [])
	var lines: Array[String] = []
	lines.append("[b]地点气氛[/b] %s" % "、".join(habitat.get("mood_tags", [])))
	lines.append("[b]今日适合[/b] %s" % _seasonal_hook_text(habitat))
	lines.append("[b]当前驻守[/b] %s" % String(resident.get("display_name", "暂无")))
	lines.append("[b]据点等级[/b] %d" % int(state.get("rank", 0)))
	lines.append("[b]常见人物[/b] %s" % (" / ".join(_npc_names(npcs)) if not npcs.is_empty() else "今天没有遇见谁"))
	lines.append("[b]建设进度[/b] %s" % _format_building_levels(current_visit_habitat_id, buildings))

	var choices := []
	if String(habitat.get("type", "")) == "habitat":
		choices.append({"id": "assign_resident", "label": "安排驻守", "summary": "把一只伙伴安顿在这里。"})
	if not buildings.is_empty():
		choices.append({"id": "build_menu", "label": "推进建设", "summary": "必须到点后才能动工。"})
	if not npcs.is_empty():
		choices.append({"id": "npc_menu", "label": "与人交谈", "summary": "看看谁有新的反馈和委托。"})
	if not habitat.get("wild_pool", []).is_empty():
		choices.append({"id": "observe", "label": "观察野外", "summary": "先看情绪，再决定如何靠近。"})
	if String(habitat.get("type", "")) == "settlement":
		choices.append({"id": "mail_menu", "label": "寄送留信", "summary": "处理跨点消息和驿站类委托。"})
	pending_context = {"kind": "visit_arrival", "on_close": "finish_visit"}
	decision_panel.open_panel(String(habitat.get("name", "地点")), "\n".join(lines), choices, "结束拜访")

func _show_build_menu(payload: Dictionary) -> void:
	var choices := []
	for building in payload.get("buildings", []):
		var building_id := String(building.get("id", ""))
		var current_level := GameState.get_building_level(current_visit_habitat_id, building_id)
		var check := habitat_service.can_build(current_visit_habitat_id, building_id)
		var summary := "当前 Lv.%d" % current_level
		var disabled := false
		if bool(check.get("ok", false)):
			summary += " ｜ 下一步：%s" % _format_item_cost(check.get("cost", {}))
		else:
			disabled = true
			summary += " ｜ %s" % _build_fail_reason(String(check.get("reason", "unknown")))
		choices.append({
			"id": building_id,
			"label": String(building.get("name", "未命名建筑")),
			"summary": summary,
			"disabled": disabled,
		})
	pending_context = {"kind": "build_select", "on_close": "arrival"}
	decision_panel.open_panel("推进建设", "只有抵达地点后才允许施工。", choices, "返回地点")

func _show_build_result(payload: Dictionary) -> void:
	if bool(payload.get("ok", false)):
		var building_name := String(DataRepository.get_building(String(payload.get("building_id", ""))).get("name", "建设"))
		_push_log("%s 的 %s 升到了 Lv.%d。" % [_habitat_name(current_visit_habitat_id), building_name, int(payload.get("level", 0))])
		_check_active_quests()
		pending_context = {"kind": "build_result", "on_close": "arrival"}
		decision_panel.open_panel("建设完成", "[b]%s[/b] 升到 Lv.%d\n%s" % [building_name, int(payload.get("level", 0)), "\n".join(payload.get("effects", []))], [], "返回地点")
		return
	pending_context = {"kind": "build_result", "on_close": "arrival"}
	decision_panel.open_panel("建设受阻", _build_fail_reason(String(payload.get("reason", "unknown"))), [], "返回地点")

func _show_npc_menu(payload: Dictionary) -> void:
	var choices := []
	for npc in payload.get("npcs", []):
		var npc_id := String(npc.get("id", ""))
		choices.append({
			"id": "talk:%s" % npc_id,
			"label": String(npc.get("name", "未命名 NPC")),
			"summary": "交谈并推进关系。当前信赖 %d" % npc_service.get_npc_trust(npc_id),
		})
	for quest in payload.get("quests", []):
		var quest_id := String(quest.get("id", ""))
		if GameState.active_quests.has(quest_id) or GameState.completed_quests.has(quest_id):
			continue
		choices.append({
			"id": "quest:%s" % quest_id,
			"label": "接委托：%s" % String(quest.get("title", "")),
			"summary": "记录到本季计划里，后续回访时自动检查进度。",
		})
	pending_context = {"kind": "npc_menu", "on_close": "arrival"}
	decision_panel.open_panel("与地点上的人交谈", "先听听他们最近关心什么。", choices, "返回地点")

func _show_encounter_preview(payload: Dictionary) -> void:
	current_encounter = payload.duplicate(true)
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "encounter_preview", "on_close": "arrival"}
		decision_panel.open_panel("今天的野外", "今天没有遇到特别愿意停留的个体。", [], "返回地点")
		return
	var species: Dictionary = payload.get("species", {})
	var species_id := String(payload.get("species_id", ""))
	GameState.note_encounter(species_id)
	var body_lines: Array[String] = []
	body_lines.append("[b]%s[/b]" % String(species.get("name", "未知个体")))
	body_lines.append("[b]当前情绪[/b] %s" % String(payload.get("mood_id", "curious")))
	body_lines.append("[b]结缘窗口[/b] %s" % String(payload.get("bond_window", "medium")))
	body_lines.append("[b]偏好动作[/b] %s" % " / ".join(species.get("care_actions", [])))
	var choices := []
	for action_id in encounter_service.get_available_actions(payload):
		choices.append({"id": action_id, "label": _action_name(action_id), "summary": "按当前情绪做一次温和尝试。"})
	pending_context = {"kind": "encounter_preview", "on_close": "arrival"}
	decision_panel.open_panel("野外相遇", "\n".join(body_lines), choices, "返回地点")

func _show_encounter_result(payload: Dictionary) -> void:
	var outcome_text := _handle_encounter_result_effects(payload)
	pending_context = {"kind": "encounter_result", "on_close": "arrival"}
	decision_panel.open_panel("相遇结果", outcome_text, [], "返回地点")

func _on_decision_choice_selected(choice_id: String) -> void:
	if pending_context.is_empty():
		return
	var context := pending_context.duplicate(true)
	pending_context.clear()
	match String(context.get("kind", "")):
		"visit_arrival":
			match choice_id:
				"assign_resident":
					_open_resident_picker()
				"build_menu":
					visit_flow.open_build_menu()
				"npc_menu":
					visit_flow.open_npc_menu()
				"observe":
					visit_flow.start_observation()
				"mail_menu":
					_show_mail_menu()
		"resident_select":
			_assign_resident(choice_id)
		"build_select":
			visit_flow.build_selected(choice_id)
		"npc_menu":
			if choice_id.begins_with("talk:"):
				_handle_talk_to_npc(choice_id.trim_prefix("talk:"))
			elif choice_id.begins_with("quest:"):
				_try_accept_quest(choice_id.trim_prefix("quest:"))
		"encounter_preview":
			last_encounter_action_id = choice_id
			visit_flow.choose_encounter_action(choice_id)
		"mail_menu":
			_handle_mail_selection(choice_id)

func _on_decision_closed() -> void:
	if pending_context.is_empty():
		return
	var context := pending_context.duplicate(true)
	pending_context.clear()
	match String(context.get("on_close", "none")):
		"finish_visit":
			_finish_current_visit()
		"arrival":
			if not current_visit_habitat_id.is_empty():
				visit_flow.start_visit(current_visit_habitat_id)
		_:
			pass

func _on_visit_finished(_report: Dictionary) -> void:
	_resolve_visit_yield(current_visit_habitat_id)
	current_visit_habitat_id = ""
	if season_finished:
		return
	GameState.advance_day()
	_begin_next_day()

func _on_base_closed() -> void:
	_update_ui()

func _open_resident_picker() -> void:
	var choices := []
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
	pending_context = {"kind": "resident_select", "on_close": "arrival"}
	decision_panel.open_panel("安排驻守", "挑一只更适合住在这里的伙伴。", choices, "返回地点")

func _show_mail_menu() -> void:
	var targets := _pending_mail_targets()
	if targets.is_empty():
		pending_context = {"kind": "mail_menu", "on_close": "arrival"}
		decision_panel.open_panel("寄送留信", "目前没有需要寄送的跨点消息。", [], "返回地点")
		return
	var choices := []
	for destination in targets:
		choices.append({
			"id": destination,
			"label": _habitat_name(destination),
			"summary": "把今天的信件和托付送过去。",
		})
	pending_context = {"kind": "mail_menu", "on_close": "arrival"}
	decision_panel.open_panel("寄送留信", "挑一个今天要处理的目标地点。", choices, "返回地点")

func _assign_resident(pet_uid: String) -> void:
	var result := habitat_service.assign_resident(current_visit_habitat_id, pet_uid)
	var body := ""
	if bool(result.get("ok", false)):
		var pet_name := GameState.get_pet_display_name(pet_uid)
		var fit_text := "它对这里很有亲近感。" if bool(result.get("preference_match", false)) else "它还需要时间适应这里。"
		body = "%s 被安顿在 %s。\n%s" % [pet_name, _habitat_name(current_visit_habitat_id), fit_text]
		_push_log(body.replace("\n", " "))
		_check_active_quests()
	else:
		body = _build_fail_reason(String(result.get("reason", "unknown")))
	pending_context = {"kind": "resident_result", "on_close": "arrival"}
	decision_panel.open_panel("驻守安排", body, [], "返回地点")

func _handle_talk_to_npc(npc_id: String) -> void:
	GameState.note_talk(npc_id)
	if _can_mark_return(npc_id):
		GameState.note_return(npc_id)
	var npc := DataRepository.get_npc(npc_id)
	var trust_result := npc_service.complete_trust_reward(npc_id, 1)
	var unlocked_lines: Array[String] = []
	for entry in trust_result.get("unlocked", []):
		unlocked_lines.append("- 信赖 %d：%s" % [int(entry.get("threshold", 0)), String(entry.get("reward", ""))])
	var body_lines: Array[String] = []
	body_lines.append("[b]%s[/b] 对你的照料计划更信任了一点。" % String(npc.get("name", "某人")))
	body_lines.append("当前信赖：%d" % int(trust_result.get("trust", 0)))
	if not unlocked_lines.is_empty():
		body_lines.append("")
		body_lines.append("[b]对话带来的新反馈[/b]")
		body_lines.append("\n".join(unlocked_lines))
	_push_log("和 %s 聊了聊，关系更近了一点。" % String(npc.get("name", "某人")))
	_check_active_quests()
	pending_context = {"kind": "talk_result", "on_close": "arrival"}
	decision_panel.open_panel("交谈结果", "\n".join(body_lines), [], "返回地点")

func _try_accept_quest(quest_id: String) -> void:
	var quest := DataRepository.get_quest(quest_id)
	if quest.is_empty():
		return
	var cost := _accept_cost_for_quest(quest)
	if not cost.is_empty() and not GameState.can_pay(cost):
		pending_context = {"kind": "quest_result", "on_close": "arrival"}
		decision_panel.open_panel("暂时接不下", "还缺少交付物资：%s" % _format_item_cost(cost), [], "返回地点")
		return
	if not cost.is_empty():
		GameState.pay_cost(cost)
		for item_id in cost.keys():
			GameState.note_delivery(String(item_id), int(cost[item_id]))
	GameState.accept_quest(quest_id)
	_push_log("接下委托：%s。" % String(quest.get("title", "")))
	_check_active_quests()
	pending_context = {"kind": "quest_result", "on_close": "arrival"}
	decision_panel.open_panel("委托记录", "已记下这件事：%s" % String(quest.get("title", "")), [], "返回地点")

func _accept_cost_for_quest(quest: Dictionary) -> Dictionary:
	var cost := {}
	for step in quest.get("steps", []):
		if String(step.get("type", "")) != "deliver":
			continue
		cost[String(step.get("item", ""))] = int(step.get("count", 0))
	return cost

func _handle_mail_selection(destination: String) -> void:
	GameState.note_mail(destination)
	_push_log("寄出了送往 %s 的留信。" % _habitat_name(destination))
	_check_active_quests()
	pending_context = {"kind": "mail_result", "on_close": "arrival"}
	decision_panel.open_panel("寄送完成", "今天处理了一封送往 %s 的消息。" % _habitat_name(destination), [], "返回地点")

func _handle_encounter_result_effects(payload: Dictionary) -> String:
	var outcome := String(payload.get("outcome", "unknown"))
	var species_id := String(current_encounter.get("species_id", ""))
	var species_name := String(current_encounter.get("species", {}).get("name", species_id))
	if last_encounter_action_id == "observe":
		GameState.note_observe(species_id)
		if current_visit_habitat_id == "mist_moss_cave" and not bool(GameState.quest_memory["observed_markers"].get("note_cache", false)) and rng.randf() <= 0.55:
			GameState.note_observe_marker("note_cache")
			_push_log("你在苔缝里找到了小禾落下的笔记。")
	if last_encounter_action_id == "calm" and outcome != "alert_rise":
		GameState.note_calm(species_id)
	if outcome == "bond_success":
		GameState.note_bond(species_id)
		var joined := _add_companion_if_new(species_id)
		_push_log("%s 愿意靠近，并把这里当成了新的联系点。" % species_name)
		_check_active_quests()
		if joined:
			return "[b]%s[/b]\n%s 愿意靠近，并加入了你的照料名册。" % [_encounter_outcome_text(outcome), species_name]
	elif outcome == "bond_progress":
		_push_log("%s 对你的存在不再那么戒备了。" % species_name)
	elif outcome == "safe_leave":
		_push_log("你选择先后退一步，让这次相遇停在安全距离。")
	elif outcome == "alert_rise":
		_push_log("%s 还是更警惕了一些，你决定改天再来。" % species_name)
	_check_active_quests()
	return "[b]%s[/b]\n%s" % [_encounter_outcome_text(outcome), species_name]

func _add_companion_if_new(species_id: String) -> bool:
	for pet in GameState.pet_states.values():
		if String(pet.get("species_id", "")) == species_id:
			return false
	GameState.add_companion(species_id)
	return true

func _can_mark_return(npc_id: String) -> bool:
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		for step in quest.get("steps", []):
			if String(step.get("type", "")) == "return" and String(step.get("npc", "")) == npc_id:
				return true
	return false

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

func _finish_current_visit() -> void:
	if current_visit_habitat_id.is_empty():
		return
	visit_flow.finish_visit()

func _resolve_visit_yield(habitat_id: String) -> void:
	var reward := {}
	match habitat_id:
		"mist_moss_cave":
			reward = {"soft_moss": 1 + GameState.get_building_level(habitat_id, "moss_bed")}
		"crystal_creek":
			reward = {"stone_chip": 1 + GameState.get_building_level(habitat_id, "sun_drying_rack")}
		"sky_post":
			reward = {"tea_leaf": 1}
		"ancient_platform":
			reward = {"parts": 1 + GameState.get_building_level(habitat_id, "repair_bench")}
		"copper_hammer_bazaar":
			reward = {"fiber": 1, "parts": 1}
		"radiant_spire":
			reward = {"stability_shard": 1}
	if reward.is_empty():
		return
	GameState.grant_items(reward)
	_push_log("回营时顺手带回：%s。" % _format_item_cost(reward))

func _finish_season() -> void:
	season_finished = true
	awaiting_destination = false
	action_hint_label.text = "[b]季末回顾[/b]\n照料进度 %d ｜ 已安居据点 %d ｜ 图鉴 %d ｜ 完成委托 %d" % [
		GameState.get_care_progress(),
		GameState.get_settled_habitat_count(),
		GameState.discovered_species.size(),
		GameState.completed_quests.size(),
	]
	_update_ui()

func _build_companion_summaries() -> Array:
	var result: Array = []
	for companion in GameState.get_companions():
		var species := DataRepository.get_species(String(companion.get("species_id", "")))
		var home_id := String(companion.get("residence_habitat_id", ""))
		var entry: Dictionary = companion.duplicate(true)
		entry["species_name"] = String(species.get("name", companion.get("species_id", "")))
		entry["residence_name"] = _habitat_name(home_id) if not home_id.is_empty() else "暂未安居"
		result.append(entry)
	return result

func _build_habitat_summaries() -> Array:
	var result: Array = []
	for habitat_id in DataRepository.habitats.keys():
		var habitat := DataRepository.get_habitat(habitat_id)
		if habitat.is_empty():
			continue
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_name := "暂无"
		var resident_uid := String(state.get("resident_uid", ""))
		if not resident_uid.is_empty():
			resident_name = GameState.get_pet_display_name(resident_uid)
		result.append({
			"name": String(habitat.get("name", habitat_id)),
			"type_name": _type_name(String(habitat.get("type", ""))),
			"resident_name": resident_name,
			"building_text": _format_building_levels(habitat_id, DataRepository.get_buildings_for_habitat(habitat_id)),
			"quest_text": _quest_text_for_habitat(habitat_id),
		})
	return result

func _update_ui() -> void:
	_update_header()
	_update_action_ui()
	_update_summaries()
	_update_roster()
	_update_log()
	_update_map_hint()
	board_view.refresh_view(current_node_id, _get_selectable_nodes(), _build_board_markers(), _get_locked_nodes())

func _update_header() -> void:
	round_label.text = "第 %d / %d 日" % [GameState.day_index, GameState.season_length]
	objective_label.text = "本季照料进度 %d ｜ 已安居 %d ｜ 图鉴 %d ｜ 委托 %d" % [
		GameState.get_care_progress(),
		GameState.get_settled_habitat_count(),
		GameState.discovered_species.size(),
		GameState.completed_quests.size(),
	]

func _update_action_ui() -> void:
	dice_label.text = "今日天气：%s ｜ 时段：%s" % [_weather_name(GameState.weather_id), _time_name(GameState.time_of_day)]
	roll_button.text = "开始今天"
	support_button.text = "查看委托"
	base_button.text = "驻点总览"
	new_game_button.text = "重开本季"
	roll_button.disabled = season_finished or _is_modal_open() or awaiting_destination
	support_button.disabled = _is_modal_open() and not decision_panel.visible
	base_button.disabled = _is_modal_open() and not base_panel.visible
	if season_finished:
		return
	if awaiting_destination:
		action_hint_label.text = "[b]今天想去哪里看看？[/b]\n点亮的地点都可以出发，重点关注还没安居的据点。"
	else:
		action_hint_label.text = "[b]从营地开始一天。[/b]\n核心闭环：准备 -> 选地点 -> 到点照料/建设/交谈 -> 回营记录。"

func _update_summaries() -> void:
	player_summary_label.text = "[b]营地记录[/b]\n照料进度：%d\n库存：%s\n活跃委托：%d" % [GameState.get_care_progress(), _format_inventory_highlights(), GameState.active_quests.size()]
	ai_summary_label.text = "[b]今日计划[/b]\n天气：%s\n时段：%s\n推荐：%s" % [_weather_name(GameState.weather_id), _time_name(GameState.time_of_day), _today_focus_text()]
	control_summary_label.text = "[b]地点状态[/b]\n%s" % "\n".join(_location_status_lines())

func _update_roster() -> void:
	var lines: Array[String] = ["[b]伙伴与安居[/b]"]
	for companion in GameState.get_companions():
		var home_id := String(companion.get("residence_habitat_id", ""))
		lines.append("%s  [%s]  驻守：%s" % [
			String(companion.get("display_name", "未命名伙伴")),
			String(companion.get("species_id", "")),
			_habitat_name(home_id) if not home_id.is_empty() else "暂未安居",
		])
	roster_label.text = "\n".join(lines)

func _update_log() -> void:
	event_log_label.text = "\n".join(GameState.journal_entries)
	event_log_label.scroll_to_line(event_log_label.get_line_count())

func _update_map_hint() -> void:
	if awaiting_destination:
		var lines: Array[String] = ["[b]可前往地点[/b]"]
		for node_id in _get_selectable_nodes():
			var node: Dictionary = board_lookup[node_id]
			lines.append("%s [%s]" % [node["name"], _type_name(String(node.get("type", "")))])
		map_hint_label.text = "\n".join(lines)
		return
	map_hint_label.text = "[b]今日提醒[/b]\n%s" % _today_focus_text()

func _build_board_markers() -> Dictionary:
	var markers := {}
	for node in world_nodes:
		var node_id := int(node.get("id", -1))
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			markers[node_id] = "准备区"
			continue
		if not GameState.is_habitat_unlocked(habitat_id):
			markers[node_id] = "尚未开放"
			continue
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_uid := String(state.get("resident_uid", ""))
		var resident_text := ""
		if not resident_uid.is_empty():
			resident_text = "住着 %s" % GameState.get_pet_display_name(resident_uid)
		var quest_text := _quest_text_for_habitat(habitat_id)
		var parts: Array[String] = []
		if not resident_text.is_empty():
			parts.append(resident_text)
		if not quest_text.is_empty():
			parts.append(quest_text)
		if parts.is_empty():
			parts.append("可回访")
		markers[node_id] = " · ".join(parts)
	return markers

func _get_selectable_nodes() -> Array[int]:
	var selectable: Array[int] = []
	if not awaiting_destination:
		return selectable
	for node in world_nodes:
		var node_id := int(node.get("id", -1))
		if node_id == 0:
			continue
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if GameState.is_habitat_unlocked(habitat_id):
			selectable.append(node_id)
	return selectable

func _get_locked_nodes() -> Array[int]:
	var locked: Array[int] = []
	for node in world_nodes:
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if not GameState.is_habitat_unlocked(habitat_id):
			locked.append(int(node.get("id", -1)))
	return locked

func _today_focus_text() -> String:
	if not GameState.active_quests.is_empty():
		return "优先推进：%s" % _quest_title(GameState.active_quests[0])
	if GameState.get_settled_habitat_count() < 2:
		return "先替据点安排驻守，让它们真正成为家。"
	if GameState.get_habitat_rank_total() < 3:
		return "该去古械平台补第一层建设了，先让据点真正运转起来。"
	if not GameState.is_habitat_unlocked("radiant_spire"):
		return "继续累积地点等级和 NPC 信赖，为异常区做准备。"
	return "季末可以考虑去裂辉尖塔做一次救助。"

func _location_status_lines() -> Array[String]:
	var lines: Array[String] = []
	for habitat_id in ["mist_moss_cave", "crystal_creek", "sky_post", "ancient_platform", "copper_hammer_bazaar"]:
		var habitat := DataRepository.get_habitat(habitat_id)
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_uid := String(state.get("resident_uid", ""))
		var resident_name := "暂无"
		if not resident_uid.is_empty():
			resident_name = GameState.get_pet_display_name(resident_uid)
		lines.append("%s：%s" % [String(habitat.get("name", habitat_id)), resident_name])
	return lines

func _quest_text_for_habitat(habitat_id: String) -> String:
	var count := 0
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		if String(quest.get("target_habitat", "")) == habitat_id:
			count += 1
	if count == 0:
		return ""
	return "委托 %d" % count

func _quest_title(quest_id: String) -> String:
	return String(DataRepository.get_quest(quest_id).get("title", quest_id))

func _quest_titles(quest_ids: Array) -> Array[String]:
	var titles: Array[String] = []
	for quest_id in quest_ids:
		titles.append(_quest_title(String(quest_id)))
	return titles

func _seasonal_hook_text(habitat: Dictionary) -> String:
	var hooks: Dictionary = habitat.get("seasonal_hooks", {})
	var candidates: Array[String] = []
	if hooks.has(GameState.season_id):
		candidates.append_array(hooks[GameState.season_id])
	if hooks.has(GameState.weather_id):
		candidates.append_array(hooks[GameState.weather_id])
	if hooks.has(GameState.time_of_day):
		candidates.append_array(hooks[GameState.time_of_day])
	return " / ".join(candidates) if not candidates.is_empty() else "今天适合慢一点地观察和照料。"

func _format_building_levels(habitat_id: String, buildings: Array) -> String:
	if buildings.is_empty():
		return "这个地点当前没有建设项目"
	var parts: Array[String] = []
	for building in buildings:
		var building_id := String(building.get("id", ""))
		parts.append("%s Lv.%d" % [String(building.get("name", building_id)), GameState.get_building_level(habitat_id, building_id)])
	return " / ".join(parts)

func _format_item_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var keys: Array[String] = []
	for item_id in cost.keys():
		keys.append(String(item_id))
	keys.sort()
	var parts: Array[String] = []
	for item_id in keys:
		parts.append("%s x%d" % [_item_name(item_id), int(cost[item_id])])
	return " / ".join(parts)

func _npc_names(npcs: Array) -> Array[String]:
	var names: Array[String] = []
	for npc in npcs:
		names.append(String(npc.get("name", "")))
	return names

func _action_name(action_id: String) -> String:
	match action_id:
		"feed": return "投喂"
		"calm": return "安抚"
		"observe": return "观察"
		"guide": return "引导"
		"retreat": return "后退"
		"hum": return "轻声哼唱"
		"shelter": return "提供遮蔽"
		_: return action_id

func _encounter_outcome_text(outcome: String) -> String:
	match outcome:
		"bond_success": return "愿意靠近"
		"bond_progress": return "情绪平复"
		"safe_leave": return "平静结束"
		"alert_rise": return "仍然戒备"
		_: return outcome

func _build_fail_reason(reason: String) -> String:
	match reason:
		"resident_required": return "这里还没有主驻守伙伴，得先让谁住下来。"
		"insufficient_items": return "材料还不够，先再回访几次或做做委托。"
		"max_level": return "这项建设已经走到当前上限。"
		"site_mismatch": return "这项建设不属于当前地点。"
		"building_missing": return "蓝图暂时没有准备好。"
		"pet_missing": return "这只伙伴现在不在照料名册里。"
		_: return "这一步今天还做不了。"

func _format_inventory_highlights() -> String:
	var highlights := ["soft_moss", "stone_chip", "parts", "wood", "tea_leaf", "glow_dust"]
	var parts: Array[String] = []
	for item_id in highlights:
		if int(GameState.inventory.get(item_id, 0)) <= 0:
			continue
		parts.append("%s x%d" % [_item_name(item_id), int(GameState.inventory[item_id])])
	return " / ".join(parts)

func _item_name(item_id: String) -> String:
	return String(DataRepository.items.get(item_id, {}).get("name", item_id))

func _weather_name(weather_id: String) -> String:
	return String(WEATHER_NAMES.get(weather_id, weather_id))

func _time_name(time_id: String) -> String:
	return String(TIME_NAMES.get(time_id, time_id))

func _type_name(type_id: String) -> String:
	match type_id:
		"camp": return "营地"
		"habitat": return "栖居据点"
		"settlement": return "聚落节点"
		"anomaly": return "异常区域"
		_: return type_id

func _habitat_name(habitat_id: String) -> String:
	if habitat_id.is_empty():
		return "营地"
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

func _push_log(text: String) -> void:
	GameState.add_journal_entry(text)

func _check_active_quests() -> void:
	for quest_id in GameState.active_quests.duplicate():
		var quest := DataRepository.get_quest(quest_id)
		if quest.is_empty() or not _quest_is_complete(quest):
			continue
		var result := npc_service.finish_quest(quest_id)
		if not bool(result.get("ok", false)):
			continue
		var reward_items: Dictionary = result.get("items", {})
		var reward_text := _format_item_cost(reward_items)
		var line := "委托完成：%s。" % String(quest.get("title", quest_id))
		if not reward_text.is_empty():
			line += " 收到 %s。" % reward_text
		_push_log(line)
		if not String(result.get("journal_entry", "")).is_empty():
			_push_log("记录新增：%s。" % String(result.get("journal_entry", "")))

func _quest_is_complete(quest: Dictionary) -> bool:
	for step in quest.get("steps", []):
		if not _step_is_complete(step):
			return false
	return true

func _step_is_complete(step: Dictionary) -> bool:
	match String(step.get("type", "")):
		"deliver":
			return int(GameState.quest_memory["delivered_items"].get(String(step.get("item", "")), 0)) >= int(step.get("count", 0))
		"visit":
			var habitat_id := String(step.get("habitat_id", ""))
			if habitat_id.is_empty():
				return false
			if step.has("time"):
				return bool(GameState.quest_memory["visited_moments"].get("%s@%s" % [habitat_id, String(step.get("time", ""))], false))
			return int(GameState.quest_memory["visited_habitats"].get(habitat_id, 0)) > 0
		"build":
			return int(GameState.quest_memory["built_levels"].get(String(step.get("building_id", "")), 0)) >= int(step.get("level", 0))
		"encounter":
			return bool(GameState.quest_memory["encounter_species"].get(String(step.get("species_id", "")), false))
		"observe":
			if step.has("species_id"):
				return bool(GameState.quest_memory["observed_species"].get(String(step.get("species_id", "")), false))
			if step.has("marker"):
				return bool(GameState.quest_memory["observed_markers"].get(String(step.get("marker", "")), false))
			return false
		"bond":
			return bool(GameState.quest_memory["bonded_species"].get(String(step.get("species_id", "")), false))
		"talk":
			return bool(GameState.quest_memory["talked_npcs"].get(String(step.get("npc", "")), false))
		"mail":
			return bool(GameState.quest_memory["mailed_destinations"].get(String(step.get("destination", "")), false))
		"return":
			return bool(GameState.quest_memory["returned_npcs"].get(String(step.get("npc", "")), false))
		"calm":
			return bool(GameState.quest_memory["calmed_species"].get(String(step.get("species_id", "")), false))
		_:
			return false

func _is_modal_open() -> bool:
	return decision_panel.visible or base_panel.visible

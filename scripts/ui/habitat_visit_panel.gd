class_name HabitatVisitPanel
extends PanelContainer

## 一个极简 UI 骨架：用“分步展示”替代把所有信息塞满一屏。
## 配合 VisitFlowController 使用。

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var subtitle_label: RichTextLabel = $Margin/VBox/SubtitleLabel
@onready var actions_box: VBoxContainer = $Margin/VBox/ActionsBox

var controller: VisitFlowController

func bind_controller(target: VisitFlowController) -> void:
	controller = target
	controller.state_changed.connect(_on_state_changed)

func _on_state_changed(step_id: String, payload: Dictionary) -> void:
	for child in actions_box.get_children():
		child.queue_free()

	match step_id:
		"arrival":
			_render_arrival(payload)
		"build_select":
			_render_build_select(payload)
		"build_result":
			_render_build_result(payload)
		"npc_menu":
			_render_npc_menu(payload)
		"encounter_preview":
			_render_encounter_preview(payload)
		"encounter_result":
			_render_encounter_result(payload)

func _render_arrival(payload: Dictionary) -> void:
	var habitat: Dictionary = payload.get("habitat", {})
	var state: Dictionary = payload.get("state", {})
	title_label.text = String(habitat.get("name", "未知地点"))
	subtitle_label.text = "[b]到点可做的事[/b]\n建设、照料、交谈、观察。\n\n[b]当前据点等级[/b] %d" % int(state.get("rank", 0))

	_add_action("查看建造", controller.open_build_menu)
	_add_action("与 NPC 交谈", controller.open_npc_menu)
	_add_action("观察野外", controller.start_observation)
	_add_action("结束本次偶遇", controller.finish_visit)

func _render_build_select(payload: Dictionary) -> void:
	title_label.text = "选择要推进的建设"
	subtitle_label.text = "只有抵达地点后才允许升级；这能把“远程经营”改成“到点生活”。"

	for building in payload.get("buildings", []):
		var button := Button.new()
		button.text = String(building.get("name", "未命名建筑"))
		button.pressed.connect(controller.build_selected.bind(String(building.get("id", ""))))
		actions_box.add_child(button)

	_add_action("返回", controller.start_visit.bind(controller.current_habitat_id))

func _render_build_result(payload: Dictionary) -> void:
	title_label.text = "建设结果"
	if bool(payload.get("ok", false)):
		subtitle_label.text = "[b]建设成功[/b]\n%s 升到 Lv.%d\n%s" % [
			String(payload.get("building_id", "")),
			int(payload.get("level", 0)),
			"\n".join(payload.get("effects", []))
		]
	else:
		subtitle_label.text = "[b]建设失败[/b]\n原因：%s" % String(payload.get("reason", "unknown"))
	_add_action("返回到点界面", controller.start_visit.bind(controller.current_habitat_id))

func _render_npc_menu(payload: Dictionary) -> void:
	title_label.text = "与地点上的人交谈"
	var lines: Array[String] = []
	for npc in payload.get("npcs", []):
		lines.append("- %s" % String(npc.get("name", "")))
	subtitle_label.text = "\n".join(lines)
	_add_action("返回", controller.start_visit.bind(controller.current_habitat_id))

func _render_encounter_preview(payload: Dictionary) -> void:
	title_label.text = "野外相遇"
	if not bool(payload.get("ok", false)):
		subtitle_label.text = "今天没有遇到特别的个体。"
		_add_action("返回", controller.start_visit.bind(controller.current_habitat_id))
		return

	var species: Dictionary = payload.get("species", {})
	subtitle_label.text = "[b]%s[/b]\n当前情绪：%s\n结缘窗口：%s" % [
		String(species.get("name", "未知个体")),
		String(payload.get("mood_id", "curious")),
		String(payload.get("bond_window", "medium"))
	]

	for action_id in EncounterService.new().get_available_actions(payload):
		_add_action(_action_name(action_id), controller.choose_encounter_action.bind(action_id))

func _render_encounter_result(payload: Dictionary) -> void:
	title_label.text = "相遇结果"
	subtitle_label.text = "[b]结果[/b] %s" % String(payload.get("outcome", "unknown"))
	_add_action("返回", controller.start_visit.bind(controller.current_habitat_id))

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

func _add_action(label: String, callable: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callable)
	actions_box.add_child(button)

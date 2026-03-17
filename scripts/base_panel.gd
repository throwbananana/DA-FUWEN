class_name BasePanel
extends PanelContainer

signal closed

@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderRow/HeaderLabel
@onready var summary_label: RichTextLabel = $MarginContainer/VBoxContainer/SummaryLabel
@onready var monster_title: Label = $MarginContainer/VBoxContainer/MonsterTitle
@onready var monster_list: VBoxContainer = $MarginContainer/VBoxContainer/MonsterScroll/MonsterList
@onready var building_title: Label = $MarginContainer/VBoxContainer/BuildingTitle
@onready var building_list: VBoxContainer = $MarginContainer/VBoxContainer/BuildingScroll/BuildingList
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)

func open_panel(panel_state: Dictionary) -> void:
	show()
	header_label.text = "驻点总览"
	monster_title.text = "同行伙伴"
	building_title.text = "地点与委托"
	_render_summary(panel_state)
	_render_companions(panel_state)
	_render_habitats(panel_state)

func close_panel() -> void:
	hide()
	closed.emit()

func _render_summary(panel_state: Dictionary) -> void:
	var season: Dictionary = panel_state.get("season", {})
	var inventory: Dictionary = panel_state.get("inventory", {})
	var active_quests: Array = panel_state.get("active_quests", [])
	var completed_quests: Array = panel_state.get("completed_quests", [])
	var lines: Array[String] = []
	lines.append("[b]本季进度[/b] 第 %d / %d 日" % [
		int(season.get("day_index", 1)),
		int(season.get("season_length", 1)),
	])
	lines.append("[b]天气[/b] %s ｜ [b]时段[/b] %s" % [
		String(season.get("weather_name", "未知")),
		String(season.get("time_name", "未知")),
	])
	lines.append("[b]照料进度[/b] %d ｜ [b]已完成委托[/b] %d" % [
		int(season.get("care_progress", 0)),
		completed_quests.size(),
	])
	lines.append("[b]当前委托[/b] %s" % (", ".join(active_quests) if not active_quests.is_empty() else "暂无"))
	lines.append("[b]库存摘记[/b] %s" % _format_inventory(inventory))
	summary_label.text = "\n".join(lines)

func _render_companions(panel_state: Dictionary) -> void:
	for child in monster_list.get_children():
		child.queue_free()
	for companion in panel_state.get("companions", []):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title := Label.new()
		title.text = "%s  ·  %s" % [
			String(companion.get("display_name", "未命名伙伴")),
			String(companion.get("species_name", "未知种族")),
		]
		title.add_theme_font_size_override("font_size", 18)
		card.add_child(title)

		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = "信赖 %d ｜ 驻守：%s ｜ 偏好：%s" % [
			int(companion.get("bond_level", 1)),
			String(companion.get("residence_name", "暂未安居")),
			", ".join(companion.get("resident_tags", [])),
		]
		card.add_child(detail)

		monster_list.add_child(card)
		monster_list.add_child(HSeparator.new())

func _render_habitats(panel_state: Dictionary) -> void:
	for child in building_list.get_children():
		child.queue_free()
	for summary in panel_state.get("habitats", []):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var title := Label.new()
		title.text = "%s  ·  %s" % [
			String(summary.get("name", "未知地点")),
			String(summary.get("type_name", "地点")),
		]
		title.add_theme_font_size_override("font_size", 18)
		card.add_child(title)

		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = "驻守：%s\n建设：%s\n委托：%s" % [
			String(summary.get("resident_name", "暂无")),
			String(summary.get("building_text", "尚未推进")),
			String(summary.get("quest_text", "暂无")),
		]
		card.add_child(detail)

		building_list.add_child(card)
		building_list.add_child(HSeparator.new())

func _format_inventory(inventory: Dictionary) -> String:
	var keys: Array[String] = []
	for key in inventory.keys():
		if int(inventory[key]) > 0:
			keys.append(String(key))
	keys.sort()
	var parts: Array[String] = []
	for item_id in keys.slice(0, 8):
		var item_name := String(DataRepository.items.get(item_id, {}).get("name", item_id))
		parts.append("%s x%d" % [item_name, int(inventory[item_id])])
	return " / ".join(parts)

func _on_close_pressed() -> void:
	hide()
	closed.emit()

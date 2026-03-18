class_name BasePanel
extends PanelContainer

signal closed
signal manage_requested

@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderRow/HeaderLabel
@onready var manage_button: Button = $MarginContainer/VBoxContainer/HeaderRow/ManageButton
@onready var summary_label: RichTextLabel = $MarginContainer/VBoxContainer/SummaryLabel
@onready var monster_title: Label = $MarginContainer/VBoxContainer/MonsterTitle
@onready var monster_list: VBoxContainer = $MarginContainer/VBoxContainer/MonsterScroll/MonsterList
@onready var building_title: Label = $MarginContainer/VBoxContainer/BuildingTitle
@onready var building_list: VBoxContainer = $MarginContainer/VBoxContainer/BuildingScroll/BuildingList
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

func _ready() -> void:
	hide()
	manage_button.pressed.connect(_on_manage_pressed)
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
	var battle_slots: Array = panel_state.get("battle_slots", [])
	var synergy_lines: Array = panel_state.get("synergy_lines", [])
	var nearby_synergy_lines: Array = panel_state.get("nearby_synergy_lines", [])
	var building_lines: Array = panel_state.get("building_lines", [])
	var battle_bonus_lines: Array = panel_state.get("battle_bonus_lines", [])
	var lines: Array[String] = []
	lines.append("[b]当前季节[/b] %s ｜ 第 %d / %d 日" % [
		String(season.get("season_name", "未知季节")),
		int(season.get("day_index", 1)),
		int(season.get("season_length", 1)),
	])
	if season.has("week_index") or season.has("global_turn"):
		lines.append("[b]周次[/b] 第 %d 周 ｜ [b]总回合[/b] %d / 100" % [
			int(season.get("week_index", 1)),
			int(season.get("global_turn", 1)),
		])
	lines.append("[b]天气[/b] %s ｜ [b]时段[/b] %s" % [
		String(season.get("weather_name", "未知")),
		String(season.get("time_name", "未知")),
	])
	lines.append("[b]照料进度[/b] %d ｜ [b]已完成委托[/b] %d" % [
		int(season.get("care_progress", 0)),
		completed_quests.size(),
	])
	lines.append("[b]构筑等级[/b] %d" % int(season.get("progression_rank", 1)))
	if not String(season.get("progression_summary", "")).is_empty():
		lines.append("[b]本阶焦点[/b] %s" % String(season.get("progression_summary", "")))
	lines.append("[b]徽章[/b] %d ｜ [b]季节点数[/b] %d" % [
		int(season.get("badge_count", 0)),
		int(season.get("season_points", 0)),
	])
	lines.append("[b]双打位[/b] %s" % (" / ".join(battle_slots) if not battle_slots.is_empty() else "未配置"))
	lines.append("[b]背包容量[/b] %s" % String(panel_state.get("backpack_summary", "0 / 0")))
	lines.append("[b]计数规则[/b] 同物种在上阵 / 背包 / 驻守中不重复计羁绊。")
	lines.append("[b]轮换试炼[/b] %s" % " / ".join(season.get("dojo_rotation", ["暂无"])))
	lines.append("[b]已激活羁绊[/b] %s" % " / ".join(synergy_lines))
	if not nearby_synergy_lines.is_empty():
		lines.append("[b]差 1 激活[/b] %s" % " / ".join(nearby_synergy_lines))
	if not building_lines.is_empty():
		lines.append("[b]建筑前置增益[/b] %s" % " / ".join(building_lines))
	if not battle_bonus_lines.is_empty():
		lines.append("[b]战斗加成汇总[/b] %s" % " / ".join(battle_bonus_lines))
	if not String(panel_state.get("weekly_objective_text", "")).is_empty():
		lines.append("[b]本周目标[/b] %s" % String(panel_state.get("weekly_objective_text", "")))
	if not panel_state.get("run_modifiers", []).is_empty():
		lines.append("[b]本局词缀[/b] %s" % " / ".join(panel_state.get("run_modifiers", [])))
	lines.append("[b]累计探索点[/b] %d" % int(panel_state.get("meta_points", 0)))
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
		var evolution_text := String(companion.get("evolution_name", companion.get("species_name", "未知种族")))
		var next_text := "下一阶：%s（还差 %d 只同星个体）" % [
			String(companion.get("next_evolution_name", "")),
			int(companion.get("duplicate_need", 0)),
		] if not String(companion.get("next_evolution_name", "")).is_empty() else "已到当前最高星"
		detail.text = "星级 ★%d ｜ 人口 %d ｜ 位置：%s ｜ 形态：%s\n属性：%s ｜ 职能：%s\n信赖 %d ｜ 驻守：%s ｜ 偏好：%s\n%s" % [
			int(companion.get("star_level", 1)),
			int(companion.get("population_cost", 1)),
			String(companion.get("slot_label", "待命")),
			evolution_text,
			String(companion.get("type_text", "未知")),
			String(companion.get("role_text", "未知")),
			int(companion.get("bond_level", 1)),
			String(companion.get("residence_name", "暂未安居")),
			", ".join(companion.get("resident_tags", [])),
			next_text,
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
		var dojo_text := String(summary.get("dojo_text", ""))
		var dojo_line := "\n试炼：%s" % dojo_text if not dojo_text.is_empty() else ""
		detail.text = "驻守：%s\n建设：%s\n委托：%s\n状态：%s%s" % [
			String(summary.get("resident_name", "暂无")),
			String(summary.get("building_text", "尚未推进")),
			String(summary.get("quest_text", "暂无")),
			String(summary.get("status_text", "可回访")),
			dojo_line,
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

func _on_manage_pressed() -> void:
	hide()
	manage_requested.emit()

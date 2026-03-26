class_name BasePanel
extends PanelContainer

signal closed
signal manage_requested

@onready var header_row: BoxContainer = $MarginContainer/VBoxContainer/HeaderRow
@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderRow/HeaderLabel
@onready var manage_button: Button = $MarginContainer/VBoxContainer/HeaderRow/ManageButton
@onready var summary_label: RichTextLabel = $MarginContainer/VBoxContainer/SummaryLabel
@onready var monster_title: Label = $MarginContainer/VBoxContainer/MonsterTitle
@onready var monster_scroll: ScrollContainer = $MarginContainer/VBoxContainer/MonsterScroll
@onready var monster_list: VBoxContainer = $MarginContainer/VBoxContainer/MonsterScroll/MonsterList
@onready var building_title: Label = $MarginContainer/VBoxContainer/BuildingTitle
@onready var building_scroll: ScrollContainer = $MarginContainer/VBoxContainer/BuildingScroll
@onready var building_list: VBoxContainer = $MarginContainer/VBoxContainer/BuildingScroll/BuildingList
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var _panel_tween: Tween

func _ready() -> void:
	hide()
	modulate.a = 1.0
	scale = Vector2.ONE
	manage_button.focus_mode = Control.FOCUS_ALL
	close_button.focus_mode = Control.FOCUS_ALL
	_apply_responsive_layout()
	manage_button.pressed.connect(_on_manage_pressed)
	close_button.pressed.connect(_on_close_pressed)

func open_panel(panel_state: Dictionary) -> void:
	show()
	move_to_front()
	_apply_responsive_layout()
	header_label.text = "营地总览"
	manage_button.text = "营地整备"
	monster_title.text = "同行伙伴"
	building_title.text = "驻守与委托"
	_render_summary(panel_state)
	_render_companions(panel_state)
	_render_habitats(panel_state)
	_play_open_animation()
	_wire_focus_neighbors()
	call_deferred("_focus_primary_action")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_scroll_container(monster_scroll, 120.0)
		_scroll_container(building_scroll, 120.0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_scroll_container(monster_scroll, -120.0)
		_scroll_container(building_scroll, -120.0)
		get_viewport().set_input_as_handled()

func close_panel() -> void:
	if GameState.should_skip_animations():
		hide()
		closed.emit()
		return
	_stop_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_panel_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.14)
	_panel_tween.finished.connect(func() -> void:
		hide()
		modulate.a = 1.0
		scale = Vector2.ONE
		closed.emit()
	)

func _play_open_animation() -> void:
	if GameState.should_skip_animations():
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	_stop_panel_tween()
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animate_entries(monster_list, 0.03)
	_animate_entries(building_list, 0.05)

func _stop_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null

func _animate_entries(container: VBoxContainer, base_delay: float) -> void:
	if GameState.should_skip_animations():
		return
	var index := 0
	for child in container.get_children():
		var control := child as Control
		if control == null:
			continue
		control.modulate = Color(1, 1, 1, 0)
		control.scale = Vector2(0.985, 0.985)
		var tween := create_tween()
		tween.tween_interval(base_delay * float(index))
		tween.set_parallel(true)
		tween.tween_property(control, "modulate:a", 1.0, 0.16)
		tween.tween_property(control, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1

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
	lines.append("[b]照料进展[/b] %d ｜ [b]已完成委托[/b] %d" % [
		int(season.get("care_progress", 0)),
		completed_quests.size(),
	])
	lines.append("[b]成长阶段[/b] %d" % int(season.get("progression_rank", 1)))
	if not String(season.get("progression_summary", "")).is_empty():
		lines.append("[b]这阶段适合做[/b] %s" % String(season.get("progression_summary", "")))
	lines.append("[b]徽章[/b] %d ｜ [b]季节点数[/b] %d" % [
		int(season.get("badge_count", 0)),
		int(season.get("season_points", 0)),
	])
	lines.append("[b]出战位[/b] %s" % (" / ".join(battle_slots) if not battle_slots.is_empty() else "还没安排"))
	lines.append("[b]背包容量[/b] %s" % String(panel_state.get("backpack_summary", "0 / 0")))
	lines.append("[b]小提醒[/b] 同一种伙伴不管在上阵、背包还是看守里，都只算一次羁绊。")
	lines.append("[b]轮换试炼[/b] %s" % " / ".join(season.get("dojo_rotation", ["暂无"])))
	lines.append("[b]已激活羁绊[/b] %s" % " / ".join(synergy_lines))
	if not String(season.get("annual_competition_text", "")).is_empty():
		lines.append("[b]年赛[/b] %s" % String(season.get("annual_competition_text", "")))
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
	var nursery_lines: Array = panel_state.get("nursery_lines", [])
	if not nursery_lines.is_empty():
		lines.append("[b]孵育概况[/b] %s" % " / ".join(nursery_lines))
	lines.append("[b]累计探索点[/b] %d" % int(panel_state.get("meta_points", 0)))
	lines.append("[b]当前委托[/b] %s" % (", ".join(active_quests) if not active_quests.is_empty() else "暂无"))
	lines.append("[b]库存摘记[/b] %s" % _format_inventory(inventory))
	summary_label.text = "\n".join(lines)
	summary_label.scroll_to_line(0)

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
			String(companion.get("slot_label", "休息中")),
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
		var nursery_text := String(summary.get("nursery_text", ""))
		var nursery_line := "\n孵育：%s" % nursery_text if not nursery_text.is_empty() else ""
		detail.text = "驻守：%s\n建设：%s\n委托：%s\n状态：%s%s%s" % [
			String(summary.get("resident_name", "暂无")),
			String(summary.get("building_text", "尚未推进")),
			String(summary.get("quest_text", "暂无")),
			String(summary.get("status_text", "可回访")),
			nursery_line,
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
	close_panel()

func _on_manage_pressed() -> void:
	hide()
	manage_requested.emit()

func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact_width := size.x < 680.0
	var short_height := size.y < 620.0
	header_row.vertical = compact_width and short_height
	header_row.add_theme_constant_override("separation", 6 if compact_width else 8)
	header_label.add_theme_font_size_override("font_size", 20 if short_height else 24)
	monster_title.add_theme_font_size_override("font_size", 16 if short_height else 18)
	building_title.add_theme_font_size_override("font_size", 16 if short_height else 18)
	summary_label.custom_minimum_size = Vector2(0, 60 if short_height else 72)
	summary_label.scroll_active = true
	monster_scroll.custom_minimum_size = Vector2(0, 160 if short_height else (200 if compact_width else 240))
	building_scroll.custom_minimum_size = Vector2(0, 140 if short_height else (180 if compact_width else 220))

func _wire_focus_neighbors() -> void:
	manage_button.focus_neighbor_right = close_button.get_path()
	close_button.focus_neighbor_left = manage_button.get_path()

func _focus_primary_action() -> void:
	if manage_button != null and manage_button.visible and not manage_button.disabled:
		manage_button.grab_focus()
	elif close_button != null:
		close_button.grab_focus()

func _scroll_container(target: ScrollContainer, delta: float) -> void:
	if target == null:
		return
	var scroll_bar := target.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.value = clampf(scroll_bar.value + delta, scroll_bar.min_value, scroll_bar.max_value)

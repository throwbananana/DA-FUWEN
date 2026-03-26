class_name SaveSlotPanel
extends PanelContainer

signal slot_selected(slot_id: String)
signal load_requested(slot_id: String)
signal new_requested(slot_id: String)
signal save_requested(slot_id: String)
signal delete_requested(slot_id: String)
signal close_requested

var _slots: Array[Dictionary] = []
var _selected_slot_id := "slot_01"
var _mode := "boot"

var _title_label: Label
var _subtitle_label: Label
var _slot_list: ItemList
var _summary_label: RichTextLabel
var _hint_label: RichTextLabel
var _load_button: Button
var _new_button: Button
var _save_button: Button
var _delete_button: Button
var _close_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(820, 560)
	_build_ui()
	hide()

func _build_ui() -> void:
	if _title_label != null:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.text = "旅程存档"
	_title_label.add_theme_font_size_override("font_size", 28)
	root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14)
	root.add_child(content_row)

	_slot_list = ItemList.new()
	_slot_list.focus_mode = Control.FOCUS_ALL
	_slot_list.custom_minimum_size = Vector2(220, 0)
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.item_selected.connect(_on_slot_item_selected)
	content_row.add_child(_slot_list)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	content_row.add_child(right_column)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = false
	_summary_label.scroll_active = true
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_label.custom_minimum_size = Vector2(0, 320)
	right_column.add_child(_summary_label)

	_hint_label = RichTextLabel.new()
	_hint_label.bbcode_enabled = true
	_hint_label.fit_content = true
	_hint_label.scroll_active = true
	_hint_label.custom_minimum_size = Vector2(0, 72)
	right_column.add_child(_hint_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	root.add_child(button_row)

	_load_button = Button.new()
	_load_button.focus_mode = Control.FOCUS_ALL
	_load_button.text = "继续"
	_load_button.pressed.connect(_on_load_pressed)
	button_row.add_child(_load_button)

	_new_button = Button.new()
	_new_button.focus_mode = Control.FOCUS_ALL
	_new_button.text = "新开"
	_new_button.pressed.connect(_on_new_pressed)
	button_row.add_child(_new_button)

	_save_button = Button.new()
	_save_button.focus_mode = Control.FOCUS_ALL
	_save_button.text = "保存到这里"
	_save_button.pressed.connect(_on_save_pressed)
	button_row.add_child(_save_button)

	_delete_button = Button.new()
	_delete_button.focus_mode = Control.FOCUS_ALL
	_delete_button.text = "删除"
	_delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(_delete_button)

	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.text = "返回"
	_close_button.pressed.connect(func() -> void:
		emit_signal("close_requested")
	)
	button_row.add_child(_close_button)

func open_panel(slots: Array[Dictionary], selected_slot_id: String, mode: String = "boot") -> void:
	_slots.clear()
	for slot in slots:
		_slots.append(Dictionary(slot).duplicate(true))
	_mode = mode
	_selected_slot_id = selected_slot_id if not selected_slot_id.is_empty() else "slot_01"
	_render_slots()
	_refresh_labels()
	_refresh_actions()
	_wire_focus_neighbors()
	show()
	call_deferred("_focus_slot_list")

func close_panel() -> void:
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		emit_signal("close_requested")
		get_viewport().set_input_as_handled()
		return
	if _slot_list.has_focus() and event.is_action_pressed("ui_right"):
		var action_button := _first_visible_action_button()
		if action_button != null:
			action_button.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if _is_action_button_focused() and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up")):
		_focus_slot_list()
		get_viewport().set_input_as_handled()

func _render_slots() -> void:
	_slot_list.clear()
	var selected_index := 0
	for index in range(_slots.size()):
		var slot: Dictionary = _slots[index]
		var title := String(slot.get("title", slot.get("id", "存档")))
		var exists := bool(slot.get("exists", false))
		var item_text := "%s%s" % [title, "" if exists else "（空）"]
		_slot_list.add_item(item_text)
		if String(slot.get("id", "")) == _selected_slot_id:
			selected_index = index
	if _slot_list.item_count > 0:
		_slot_list.select(selected_index)
		_apply_selected_slot_by_index(selected_index, false)

func _apply_selected_slot_by_index(index: int, notify := true) -> void:
	if index < 0 or index >= _slots.size():
		return
	_selected_slot_id = String(_slots[index].get("id", _selected_slot_id))
	_refresh_labels()
	_refresh_actions()
	if notify:
		emit_signal("slot_selected", _selected_slot_id)

func _current_slot() -> Dictionary:
	for slot in _slots:
		if String(slot.get("id", "")) == _selected_slot_id:
			return Dictionary(slot).duplicate(true)
	return {}

func _refresh_labels() -> void:
	_title_label.text = "旅程存档"
	_subtitle_label.text = "开头可以从选中的存档继续，也能在这里开新旅程；旅途中也能随时换格保存。"
	var slot := _current_slot()
	_summary_label.text = _build_slot_summary(slot)
	if _mode == "runtime":
		_hint_label.text = "[b]旅途中[/b]\n如果存到别的格子，之后的自动存档也会跟着记到那边。"
	else:
		_hint_label.text = "[b]开头这里[/b]\n空槽点“继续”就会直接从这里开始新旅程。"

func _refresh_actions() -> void:
	var slot := _current_slot()
	var exists := bool(slot.get("exists", false))
	_load_button.visible = true
	_new_button.visible = true
	_save_button.visible = _mode == "runtime"
	_delete_button.visible = true
	_load_button.text = "从这格继续"
	_load_button.disabled = not exists
	_new_button.text = "在这个槽位新开"
	_new_button.disabled = _selected_slot_id.is_empty()
	_save_button.disabled = _selected_slot_id.is_empty()
	_delete_button.disabled = not exists

func _build_slot_summary(slot: Dictionary) -> String:
	if slot.is_empty():
		return "没有可用的槽位信息。"
	if not bool(slot.get("exists", false)):
		return "[b]%s[/b]\n这格还是空的。" % String(slot.get("title", slot.get("id", "存档")))
	var summary: Dictionary = Dictionary(slot.get("summary", {})).duplicate(true)
	if summary.is_empty():
		return "[b]%s[/b]\n这格里有旧存档，不过暂时看不到摘要。" % String(slot.get("title", slot.get("id", "存档")))
	var battle_slots: Array[String] = []
	for entry in summary.get("battle_slots", []):
		battle_slots.append(String(entry))
	if battle_slots.is_empty():
		battle_slots.append("未编成")
	var lines: Array[String] = [
		"[b]%s[/b]" % String(slot.get("title", slot.get("id", "存档"))),
		"%s · 第 %d / %d 回合 · 第 %d 周 · 总回合 %d / 100" % [
			String(summary.get("season_name", "未知季节")),
			int(summary.get("season_turn", 1)),
			int(summary.get("season_length", 1)),
			int(summary.get("week_index", 1)),
			int(summary.get("global_turn", 1)),
		],
		"位置：%s" % String(summary.get("node_name", "营地")),
		"出战位：%s" % " / ".join(battle_slots),
		"周目标：%s" % String(summary.get("objective_summary", "暂无")),
	]
	return "\n".join(lines)

func _on_slot_item_selected(index: int) -> void:
	_apply_selected_slot_by_index(index)

func _on_load_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	emit_signal("load_requested", _selected_slot_id)

func _on_new_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	emit_signal("new_requested", _selected_slot_id)

func _on_save_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	emit_signal("save_requested", _selected_slot_id)

func _on_delete_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	emit_signal("delete_requested", _selected_slot_id)

func _wire_focus_neighbors() -> void:
	var buttons: Array[Button] = [_load_button, _new_button, _save_button, _delete_button, _close_button]
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		if button == null:
			continue
		button.focus_neighbor_left = _slot_list.get_path()
		button.focus_neighbor_top = buttons[maxi(0, index - 1)].get_path()
		button.focus_neighbor_bottom = buttons[mini(buttons.size() - 1, index + 1)].get_path()

func _focus_slot_list() -> void:
	if _slot_list != null:
		_slot_list.grab_focus()

func _first_visible_action_button() -> Button:
	for button: Button in [_load_button, _new_button, _save_button, _delete_button, _close_button]:
		if button != null and button.visible and not button.disabled:
			return button
	return _close_button

func _is_action_button_focused() -> bool:
	for button: Button in [_load_button, _new_button, _save_button, _delete_button, _close_button]:
		if button != null and button.has_focus():
			return true
	return false

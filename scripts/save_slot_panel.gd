class_name SaveSlotPanel
extends PanelContainer

signal slot_selected(slot_id: String)
signal load_requested(slot_id: String)
signal new_requested(slot_id: String)
signal save_requested(slot_id: String)
signal delete_requested(slot_id: String)
signal close_requested

const SaveSlotEntryScene := preload("res://scenes/ui/common/SaveSlotEntry.tscn")
const SaveSlotEntryScript := preload("res://scripts/ui/save_slot_entry.gd")

var _slots: Array[Dictionary] = []
var _selected_slot_id := "slot_01"
var _mode := "boot"
var _slot_entries: Array[SaveSlotEntryScript] = []

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _slot_scroll: ScrollContainer = $MarginContainer/VBoxContainer/ContentRow/SlotScroll
@onready var _slot_list_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentRow/SlotScroll/SlotListContainer
@onready var _summary_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentRow/RightColumn/SummaryLabel
@onready var _hint_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentRow/RightColumn/HintLabel
@onready var _load_button: Button = $MarginContainer/VBoxContainer/ButtonRow/LoadButton
@onready var _new_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NewButton
@onready var _save_button: Button = $MarginContainer/VBoxContainer/ButtonRow/SaveButton
@onready var _delete_button: Button = $MarginContainer/VBoxContainer/ButtonRow/DeleteButton
@onready var _close_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CloseButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_load_button.focus_mode = Control.FOCUS_ALL
	_new_button.focus_mode = Control.FOCUS_ALL
	_save_button.focus_mode = Control.FOCUS_ALL
	_delete_button.focus_mode = Control.FOCUS_ALL
	_close_button.focus_mode = Control.FOCUS_ALL
	_load_button.pressed.connect(_on_load_pressed)
	_new_button.pressed.connect(_on_new_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)

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
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if _is_slot_entry_focused() and event.is_action_pressed("ui_right"):
		var action_button := _first_visible_action_button()
		if action_button != null:
			action_button.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if _is_action_button_focused() and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up")):
		_focus_slot_list()
		get_viewport().set_input_as_handled()

func _render_slots() -> void:
	_slot_entries.clear()
	for child in _slot_list_container.get_children():
		child.queue_free()
	var selected_index := 0
	for index in range(_slots.size()):
		var slot: Dictionary = _slots[index]
		var entry := SaveSlotEntryScene.instantiate() as SaveSlotEntryScript
		entry.configure(slot)
		entry.set_selected(false)
		entry.pressed.connect(_on_slot_entry_pressed.bind(index))
		entry.focused.connect(_on_slot_entry_focused.bind(index))
		_slot_list_container.add_child(entry)
		_slot_entries.append(entry)
		if String(slot.get("id", "")) == _selected_slot_id:
			selected_index = index
	if not _slot_entries.is_empty():
		_apply_selected_slot_by_index(selected_index, false)

func _apply_selected_slot_by_index(index: int, notify := true) -> void:
	if index < 0 or index >= _slots.size():
		return
	var previous_slot_id := _selected_slot_id
	_selected_slot_id = String(_slots[index].get("id", _selected_slot_id))
	_refresh_slot_entry_states()
	_refresh_labels()
	_refresh_actions()
	_wire_focus_neighbors()
	if notify and previous_slot_id != _selected_slot_id:
		slot_selected.emit(_selected_slot_id)

func _current_slot() -> Dictionary:
	for slot in _slots:
		if String(slot.get("id", "")) == _selected_slot_id:
			return Dictionary(slot).duplicate(true)
	return {}

func _refresh_slot_entry_states() -> void:
	for index in range(_slot_entries.size()):
		var entry := _slot_entries[index]
		if entry == null:
			continue
		entry.set_selected(String(_slots[index].get("id", "")) == _selected_slot_id)

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

func _on_slot_entry_pressed(index: int) -> void:
	_apply_selected_slot_by_index(index)

func _on_slot_entry_focused(index: int) -> void:
	_apply_selected_slot_by_index(index)
	_scroll_slot_into_view(index)

func _on_load_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	load_requested.emit(_selected_slot_id)

func _on_new_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	new_requested.emit(_selected_slot_id)

func _on_save_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	save_requested.emit(_selected_slot_id)

func _on_delete_pressed() -> void:
	if _selected_slot_id.is_empty():
		return
	delete_requested.emit(_selected_slot_id)

func _wire_focus_neighbors() -> void:
	var primary_slot := _selected_slot_entry()
	if primary_slot == null and not _slot_entries.is_empty():
		primary_slot = _slot_entries[0]
	for index in range(_slot_entries.size()):
		var entry := _slot_entries[index]
		if entry == null:
			continue
		if index > 0:
			entry.focus_neighbor_top = _slot_entries[index - 1].get_path()
		if index + 1 < _slot_entries.size():
			entry.focus_neighbor_bottom = _slot_entries[index + 1].get_path()
		var action_button := _first_visible_action_button()
		if action_button != null:
			entry.focus_neighbor_right = action_button.get_path()
	var buttons: Array[Button] = [_load_button, _new_button, _save_button, _delete_button, _close_button]
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		if button == null:
			continue
		if primary_slot != null:
			button.focus_neighbor_left = primary_slot.get_path()
		button.focus_neighbor_top = buttons[maxi(0, index - 1)].get_path()
		button.focus_neighbor_bottom = buttons[mini(buttons.size() - 1, index + 1)].get_path()

func _focus_slot_list() -> void:
	var selected_entry := _selected_slot_entry()
	if selected_entry != null:
		selected_entry.grab_focus()
	elif not _slot_entries.is_empty():
		_slot_entries[0].grab_focus()

func _selected_slot_entry() -> SaveSlotEntryScript:
	for index in range(_slot_entries.size()):
		if String(_slots[index].get("id", "")) == _selected_slot_id:
			return _slot_entries[index]
	return null

func _scroll_slot_into_view(index: int) -> void:
	if index < 0 or index >= _slot_entries.size():
		return
	var entry := _slot_entries[index]
	if entry == null:
		return
	var target_y := maxi(0.0, entry.global_position.y - _slot_scroll.global_position.y + _slot_scroll.scroll_vertical - 40.0)
	_slot_scroll.scroll_vertical = int(target_y)

func _first_visible_action_button() -> Button:
	for button: Button in [_load_button, _new_button, _save_button, _delete_button, _close_button]:
		if button != null and button.visible and not button.disabled:
			return button
	return _close_button

func _is_slot_entry_focused() -> bool:
	for entry in _slot_entries:
		if entry != null and entry.has_focus():
			return true
	return false

func _is_action_button_focused() -> bool:
	for button: Button in [_load_button, _new_button, _save_button, _delete_button, _close_button]:
		if button != null and button.has_focus():
			return true
	return false

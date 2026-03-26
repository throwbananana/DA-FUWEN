class_name InputSettingsPanel
extends PanelContainer

signal closed

const BINDING_SLOT_COUNT := 4
const CAPTURE_TIMEOUT_MS := 5000

var localization_service := preload("res://scripts/services/localization_service.gd").new()

var _title_label: Label
var _subtitle_label: Label
var _device_label: Label
var _scroll: ScrollContainer
var _list_container: VBoxContainer
var _status_label: Label
var _reset_current_button: Button
var _reset_all_button: Button
var _close_button: Button
var _binding_buttons := {}
var _binding_order: Array[String] = []
var _focused_action_id := ""
var _focused_slot_index := 0
var _capture_action_id := ""
var _capture_slot_index := -1
var _capture_started_msec := 0
var _capture_deadline_msec := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_build_layout()
	_apply_responsive_layout()
	set_process(true)

func open_panel() -> void:
	_cancel_capture(false)
	show()
	move_to_front()
	_refresh_view()
	call_deferred("_focus_last_slot")

func close_panel() -> void:
	_cancel_capture(false)
	hide()
	closed.emit()

func _process(_delta: float) -> void:
	if not visible or not _is_capture_active():
		return
	if Time.get_ticks_msec() >= _capture_deadline_msec:
		_cancel_capture(true)

func _input(event: InputEvent) -> void:
	if not visible or not _is_capture_active():
		return
	if Time.get_ticks_msec() - _capture_started_msec < InputManager.capture_ignore_duration_ms():
		return
	if InputManager.cancel_capture_allowed(event, _capture_action_id):
		_cancel_capture(true)
		get_viewport().set_input_as_handled()
		return
	var rebound_event := InputManager.build_rebind_event(event)
	if rebound_event == null:
		return
	InputManager.set_binding(_capture_action_id, _capture_slot_index, rebound_event)
	_finish_capture()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _is_capture_active():
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _build_layout() -> void:
	if _title_label != null:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title_label = Label.new()
	root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle_label)

	_device_label = Label.new()
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_device_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 320)
	root.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list_container)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)

	_reset_current_button = Button.new()
	_reset_current_button.focus_mode = Control.FOCUS_ALL
	_reset_current_button.pressed.connect(_on_reset_current_pressed)
	footer.add_child(_reset_current_button)

	_reset_all_button = Button.new()
	_reset_all_button.focus_mode = Control.FOCUS_ALL
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	footer.add_child(_reset_all_button)

	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(close_panel)
	footer.add_child(_close_button)

func _refresh_view() -> void:
	_title_label.text = localization_service.text("settings.input.title")
	_subtitle_label.text = localization_service.text("settings.input.body")
	_device_label.text = localization_service.text("settings.input.device", {"count": InputManager.connected_joypad_count()})
	_reset_current_button.text = localization_service.text("settings.input.reset_action")
	_reset_all_button.text = localization_service.text("settings.input.reset_all")
	_close_button.text = localization_service.text("settings.input.close")
	_rebuild_action_rows()
	_refresh_status_text()
	_refresh_button_states()
	_apply_responsive_layout()

func _rebuild_action_rows() -> void:
	_binding_buttons.clear()
	_binding_order.clear()
	for child in _list_container.get_children():
		child.queue_free()

	var current_group := ""
	for row in InputManager.get_bindable_actions():
		var group_key := String(row.get("group_key", ""))
		if group_key != current_group:
			current_group = group_key
			var group_label := Label.new()
			group_label.text = localization_service.text(group_key)
			group_label.add_theme_font_size_override("font_size", 16)
			_list_container.add_child(group_label)
		var action_id := String(row.get("id", ""))
		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 8)
		_list_container.add_child(row_box)

		var name_label := Label.new()
		name_label.text = localization_service.text(String(row.get("label_key", action_id)))
		name_label.custom_minimum_size = Vector2(180, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_box.add_child(name_label)

		var slot_buttons: Array[Button] = []
		for slot_index in range(BINDING_SLOT_COUNT):
			var button := Button.new()
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size = Vector2(0, 42)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_binding_slot_pressed.bind(action_id, slot_index))
			button.focus_entered.connect(_on_binding_slot_focused.bind(action_id, slot_index))
			row_box.add_child(button)
			slot_buttons.append(button)
		_binding_buttons[action_id] = slot_buttons
		_binding_order.append(action_id)
	_wire_focus_neighbors()

func _refresh_button_states() -> void:
	for action_id in _binding_buttons.keys():
		var slot_buttons: Array = _binding_buttons[action_id]
		for slot_index in range(slot_buttons.size()):
			var button := slot_buttons[slot_index] as Button
			if button == null:
				continue
			button.disabled = _is_capture_active()
			if _capture_action_id == String(action_id) and _capture_slot_index == slot_index:
				button.text = localization_service.text("settings.input.waiting")
			else:
				var binding_label := InputManager.describe_binding_slot(String(action_id), slot_index)
				button.text = binding_label if not binding_label.is_empty() else localization_service.text("settings.input.empty")
	_reset_current_button.disabled = _is_capture_active() or _focused_action_id.is_empty()
	_reset_all_button.disabled = _is_capture_active()
	_close_button.disabled = _is_capture_active()

func _refresh_status_text() -> void:
	if _is_capture_active():
		var action_label_key := ""
		for row in InputManager.get_bindable_actions():
			if String(row.get("id", "")) == _capture_action_id:
				action_label_key = String(row.get("label_key", _capture_action_id))
				break
		_status_label.text = localization_service.text("settings.input.capture", {
			"action": localization_service.text(action_label_key if not action_label_key.is_empty() else _capture_action_id),
			"slot": str(_capture_slot_index + 1),
		})
		return
	_status_label.text = localization_service.text("settings.input.hint")

func _on_binding_slot_pressed(action_id: String, slot_index: int) -> void:
	if _is_capture_active():
		return
	_focused_action_id = action_id
	_focused_slot_index = slot_index
	_capture_action_id = action_id
	_capture_slot_index = slot_index
	_capture_started_msec = Time.get_ticks_msec()
	_capture_deadline_msec = _capture_started_msec + CAPTURE_TIMEOUT_MS
	_refresh_status_text()
	_refresh_button_states()

func _on_binding_slot_focused(action_id: String, slot_index: int) -> void:
	_focused_action_id = action_id
	_focused_slot_index = slot_index
	_scroll_focused_slot_into_view()
	_refresh_button_states()

func _on_reset_current_pressed() -> void:
	if _focused_action_id.is_empty():
		return
	InputManager.reset_action_to_default(_focused_action_id)
	_refresh_view()
	call_deferred("_focus_last_slot")

func _on_reset_all_pressed() -> void:
	InputManager.reset_all_to_defaults()
	_refresh_view()
	call_deferred("_focus_last_slot")

func _finish_capture() -> void:
	_capture_action_id = ""
	_capture_slot_index = -1
	_capture_started_msec = 0
	_capture_deadline_msec = 0
	_refresh_view()
	call_deferred("_focus_last_slot")

func _cancel_capture(restore_focus: bool) -> void:
	var had_capture := _is_capture_active()
	_capture_action_id = ""
	_capture_slot_index = -1
	_capture_started_msec = 0
	_capture_deadline_msec = 0
	if had_capture:
		_refresh_status_text()
		_refresh_button_states()
		if restore_focus:
			call_deferred("_focus_last_slot")

func _is_capture_active() -> bool:
	return not _capture_action_id.is_empty() and _capture_slot_index >= 0

func _focus_last_slot() -> void:
	if not visible:
		return
	if _binding_buttons.has(_focused_action_id):
		var slot_buttons: Array = _binding_buttons[_focused_action_id]
		if _focused_slot_index >= 0 and _focused_slot_index < slot_buttons.size():
			var button := slot_buttons[_focused_slot_index] as Button
			if button != null and not button.disabled:
				button.grab_focus()
				return
	for action_id in _binding_buttons.keys():
		var slot_buttons: Array = _binding_buttons[action_id]
		for raw_button in slot_buttons:
			var button := raw_button as Button
			if button != null and not button.disabled:
				button.grab_focus()
				return
	if not _close_button.disabled:
		_close_button.grab_focus()

func _apply_responsive_layout() -> void:
	if _title_label == null:
		return
	var short_height := size.y < 560.0
	_title_label.add_theme_font_size_override("font_size", 24 if short_height else 28)
	_subtitle_label.add_theme_font_size_override("font_size", 14 if short_height else 15)
	_device_label.add_theme_font_size_override("font_size", 13 if short_height else 14)
	_status_label.add_theme_font_size_override("font_size", 13 if short_height else 14)
	_scroll.custom_minimum_size = Vector2(0, 250 if short_height else 320)
	var button_height := 38 if short_height else 42
	for slot_buttons in _binding_buttons.values():
		for raw_button in slot_buttons:
			var button := raw_button as Button
			if button == null:
				continue
			button.custom_minimum_size = Vector2(0, button_height)
	_reset_current_button.custom_minimum_size = Vector2(0, button_height)
	_reset_all_button.custom_minimum_size = Vector2(0, button_height)
	_close_button.custom_minimum_size = Vector2(0, button_height)

func _wire_focus_neighbors() -> void:
	for row_index in range(_binding_order.size()):
		var action_id := _binding_order[row_index]
		var slot_buttons: Array = _binding_buttons.get(action_id, [])
		for slot_index in range(slot_buttons.size()):
			var button := slot_buttons[slot_index] as Button
			if button == null:
				continue
			if slot_index > 0:
				button.focus_neighbor_left = (slot_buttons[slot_index - 1] as Button).get_path()
			if slot_index + 1 < slot_buttons.size():
				button.focus_neighbor_right = (slot_buttons[slot_index + 1] as Button).get_path()
			if row_index > 0:
				var prev_action_id := _binding_order[row_index - 1]
				var prev_row: Array = _binding_buttons.get(prev_action_id, [])
				if slot_index < prev_row.size():
					button.focus_neighbor_top = (prev_row[slot_index] as Button).get_path()
			if row_index + 1 < _binding_order.size():
				var next_action_id := _binding_order[row_index + 1]
				var next_row: Array = _binding_buttons.get(next_action_id, [])
				if slot_index < next_row.size():
					button.focus_neighbor_bottom = (next_row[slot_index] as Button).get_path()
			else:
				button.focus_neighbor_bottom = _reset_current_button.get_path()
	if not _binding_order.is_empty():
		var last_row: Array = _binding_buttons.get(_binding_order[_binding_order.size() - 1], [])
		if not last_row.is_empty():
			_reset_current_button.focus_neighbor_top = (last_row[0] as Button).get_path()
	_reset_current_button.focus_neighbor_right = _reset_all_button.get_path()
	_reset_all_button.focus_neighbor_left = _reset_current_button.get_path()
	_reset_all_button.focus_neighbor_right = _close_button.get_path()
	_close_button.focus_neighbor_left = _reset_all_button.get_path()

func _scroll_focused_slot_into_view() -> void:
	if _scroll == null or not _binding_buttons.has(_focused_action_id):
		return
	var slot_buttons: Array = _binding_buttons[_focused_action_id]
	if _focused_slot_index < 0 or _focused_slot_index >= slot_buttons.size():
		return
	var button := slot_buttons[_focused_slot_index] as Button
	if button == null:
		return
	var target_y := maxi(0.0, button.global_position.y - _scroll.global_position.y + _scroll.scroll_vertical - 72.0)
	_scroll.scroll_vertical = int(target_y)

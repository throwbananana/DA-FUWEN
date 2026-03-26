class_name CutscenePanel
extends PanelContainer

signal continued
signal choice_selected(choice_id: String)
signal closed

const TYPEWRITER_CHARS_PER_SECOND := 88.0
const TYPEWRITER_MIN_DURATION := 0.18
const TYPEWRITER_MAX_DURATION := 2.80
const PANEL_FADE_IN_DURATION := 0.18
const PANEL_FADE_OUT_DURATION := 0.14

var _title_label: Label
var _speaker_label: Label
var _body_label: RichTextLabel
var _choice_container: VBoxContainer
var _continue_button: Button
var _close_button: Button
var _body_tween: Tween
var _panel_tween: Tween
var _is_typing := false
var _pending_continue_text := "继续"
var _queued_close_signal := false
var last_choice_id := ""
var _choice_buttons: Array[Button] = []

func _ready() -> void:
	_build_layout()
	hide()
	modulate.a = 1.0
	_apply_responsive_layout()
	_continue_button.pressed.connect(_on_continue_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_body_label.gui_input.connect(_on_body_label_gui_input)

func open_step(step: Dictionary) -> void:
	_stop_close_animation(false)
	_stop_typewriter(false)
	show()
	move_to_front()
	_title_label.text = String(step.get("title", "演出"))
	var speaker := String(step.get("speaker", ""))
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	_body_label.text = String(step.get("body", ""))
	_body_label.scroll_to_line(0)
	_pending_continue_text = String(step.get("continue_text", "继续"))
	last_choice_id = ""
	_continue_button.text = _pending_continue_text
	_queued_close_signal = false
	_choice_buttons.clear()

	for child in _choice_container.get_children():
		child.queue_free()
	var choices: Array = Array(step.get("choices", [])).duplicate(true)
	for choice in choices:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		var label := String(choice.get("label", "继续"))
		var summary := String(choice.get("summary", ""))
		button.text = label if summary.is_empty() else "%s\n%s" % [label, summary]
		button.tooltip_text = summary
		button.pressed.connect(_on_choice_pressed.bind(String(choice.get("id", ""))))
		_choice_container.add_child(button)
		_choice_buttons.append(button)

	_continue_button.visible = choices.is_empty()
	_close_button.visible = bool(step.get("allow_close", false))
	_continue_button.focus_mode = Control.FOCUS_ALL
	_close_button.focus_mode = Control.FOCUS_ALL
	_apply_responsive_layout()
	_wire_focus_neighbors()
	_refresh_focus_targets()
	_play_open_animation()
	_play_typewriter()

func close_panel(emit_closed: bool = true) -> void:
	_begin_close_animation(emit_closed)

func _on_continue_pressed() -> void:
	if _is_typing:
		_finish_typewriter()
		return
	continued.emit()

func _on_close_pressed() -> void:
	if _is_typing:
		_finish_typewriter()
		return
	_begin_close_animation(true)

func _on_choice_pressed(choice_id: String) -> void:
	if _is_typing:
		_finish_typewriter()
	last_choice_id = choice_id
	choice_selected.emit(choice_id)

func _on_body_label_gui_input(event: InputEvent) -> void:
	if not _is_typing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_typewriter()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _build_layout() -> void:
	if _title_label != null:
		return
	custom_minimum_size = Vector2(620, 420)
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "演出"
	vbox.add_child(_title_label)

	_speaker_label = Label.new()
	_speaker_label.name = "SpeakerLabel"
	_speaker_label.visible = false
	vbox.add_child(_speaker_label)

	_body_label = RichTextLabel.new()
	_body_label.name = "BodyLabel"
	_body_label.bbcode_enabled = true
	_body_label.fit_content = false
	_body_label.scroll_active = true
	_body_label.custom_minimum_size = Vector2(0, 150)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_body_label)

	_choice_container = VBoxContainer.new()
	_choice_container.name = "ChoiceContainer"
	_choice_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_choice_container)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "收起"
	_close_button.visible = false
	button_row.add_child(_close_button)

	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "继续"
	_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(_continue_button)

func _play_open_animation() -> void:
	_stop_close_animation(false)
	modulate.a = 0.0
	_panel_tween = create_tween()
	_panel_tween.tween_property(self, "modulate:a", 1.0, PANEL_FADE_IN_DURATION)
	_panel_tween.finished.connect(_on_open_animation_finished)

func _on_open_animation_finished() -> void:
	_panel_tween = null

func _begin_close_animation(emit_closed_when_done: bool) -> void:
	_stop_typewriter(true)
	_stop_close_animation(false)
	_queued_close_signal = emit_closed_when_done
	if not visible:
		if _queued_close_signal:
			_queued_close_signal = false
			closed.emit()
		return
	_panel_tween = create_tween()
	_panel_tween.tween_property(self, "modulate:a", 0.0, PANEL_FADE_OUT_DURATION)
	_panel_tween.finished.connect(_on_close_animation_finished)

func _on_close_animation_finished() -> void:
	_panel_tween = null
	hide()
	modulate.a = 1.0
	if _queued_close_signal:
		_queued_close_signal = false
		closed.emit()

func _stop_close_animation(reset_alpha: bool) -> void:
	if _panel_tween:
		_panel_tween.kill()
		_panel_tween = null
	if reset_alpha:
		modulate.a = 1.0
	_queued_close_signal = false

func _play_typewriter() -> void:
	_stop_typewriter(false)
	var visible_chars := _body_label.get_total_character_count()
	if visible_chars <= 0:
		_body_label.visible_ratio = 1.0
		_continue_button.text = _pending_continue_text
		_refresh_focus_targets()
		return
	_is_typing = true
	_body_label.visible_ratio = 0.0
	_continue_button.text = "跳过"
	_refresh_focus_targets()
	var duration := clampf(float(visible_chars) / TYPEWRITER_CHARS_PER_SECOND, TYPEWRITER_MIN_DURATION, TYPEWRITER_MAX_DURATION)
	_body_tween = create_tween()
	_body_tween.tween_property(_body_label, "visible_ratio", 1.0, duration)
	_body_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_finished() -> void:
	_body_tween = null
	_finish_typewriter()

func _finish_typewriter() -> void:
	if _body_tween:
		_body_tween.kill()
		_body_tween = null
	_body_label.visible_ratio = 1.0
	_is_typing = false
	_continue_button.text = _pending_continue_text
	_refresh_focus_targets()
	_focus_primary_action()

func _stop_typewriter(show_all_text: bool) -> void:
	if _body_tween:
		_body_tween.kill()
		_body_tween = null
	if show_all_text and _body_label != null:
		_body_label.visible_ratio = 1.0
	_is_typing = false
	if _continue_button != null:
		_continue_button.text = _pending_continue_text
	_refresh_focus_targets()

func _apply_responsive_layout() -> void:
	if _title_label == null:
		return
	var short_height := size.y < 360.0
	_title_label.add_theme_font_size_override("font_size", 24 if short_height else 28)
	_speaker_label.add_theme_font_size_override("font_size", 18 if short_height else 20)
	_body_label.custom_minimum_size = Vector2(0, 120 if short_height else 150)
	_continue_button.custom_minimum_size = Vector2(0, 42 if short_height else 48)
	_close_button.custom_minimum_size = Vector2(0, 42 if short_height else 48)
	for child in _choice_container.get_children():
		var button := child as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(0, 46 if short_height else 54)

func _wire_focus_neighbors() -> void:
	for index in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		if button == null:
			continue
		if index > 0:
			button.focus_neighbor_top = _choice_buttons[index - 1].get_path()
		elif _close_button.visible:
			button.focus_neighbor_top = _close_button.get_path()
		elif _continue_button.visible:
			button.focus_neighbor_top = _continue_button.get_path()
		if index + 1 < _choice_buttons.size():
			button.focus_neighbor_bottom = _choice_buttons[index + 1].get_path()
		elif _continue_button.visible:
			button.focus_neighbor_bottom = _continue_button.get_path()
		elif _close_button.visible:
			button.focus_neighbor_bottom = _close_button.get_path()
	if _continue_button.visible and not _choice_buttons.is_empty():
		_continue_button.focus_neighbor_top = _choice_buttons[_choice_buttons.size() - 1].get_path()
		_continue_button.focus_neighbor_bottom = _choice_buttons[0].get_path()
	if _close_button.visible:
		if not _choice_buttons.is_empty():
			_close_button.focus_neighbor_bottom = _choice_buttons[0].get_path()
			_close_button.focus_neighbor_top = _choice_buttons[_choice_buttons.size() - 1].get_path()
		elif _continue_button.visible:
			_close_button.focus_neighbor_right = _continue_button.get_path()
	if _continue_button.visible and _close_button.visible:
		_continue_button.focus_neighbor_left = _close_button.get_path()
		_close_button.focus_neighbor_right = _continue_button.get_path()

func _refresh_focus_targets() -> void:
	for button in _choice_buttons:
		if button != null:
			button.disabled = _is_typing
	if _continue_button != null:
		_continue_button.disabled = false

func _focus_primary_action() -> void:
	for button in _choice_buttons:
		if button != null and not button.disabled:
			button.grab_focus()
			return
	if _continue_button != null and _continue_button.visible:
		_continue_button.grab_focus()
	elif _close_button != null and _close_button.visible:
		_close_button.grab_focus()

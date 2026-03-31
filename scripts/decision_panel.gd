class_name DecisionPanel
extends PanelContainer

signal choice_selected(choice_id: String)
signal closed

const TYPEWRITER_CHARS_PER_SECOND := 72.0
const TYPEWRITER_MIN_DURATION := 0.18
const TYPEWRITER_MAX_DURATION := 2.60
const PANEL_FADE_IN_DURATION := 0.20
const PANEL_FADE_OUT_DURATION := 0.16
const DecisionChoiceButtonScene := preload("res://scenes/ui/common/DecisionChoiceButton.tscn")
const DecisionChoiceButtonScript := preload("res://scripts/ui/decision_choice_button.gd")

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var preview_rect: TextureRect = $MarginContainer/VBoxContainer/PreviewRect
@onready var preview_caption_label: Label = $MarginContainer/VBoxContainer/PreviewCaptionLabel
@onready var body_label: RichTextLabel = $MarginContainer/VBoxContainer/BodyLabel
@onready var button_container: VBoxContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton

var current_choices := []
var _body_tween: Tween
var _panel_tween: Tween
var _is_typing := false
var _is_info_popup := false
var _pending_cancel_text := "取消"
var _queued_close_signal := false
var _choice_buttons: Array[Button] = []

func _ready() -> void:
	hide()
	modulate.a = 1.0
	preview_rect.visible = false
	preview_caption_label.visible = false
	_apply_responsive_layout()
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.pressed.connect(_on_cancel_pressed)
	body_label.gui_input.connect(_on_body_label_gui_input)

func open_panel(title_text: String, body_text: String, choices: Array, cancel_text: String = "取消", preview_texture: Texture2D = null, preview_caption: String = "") -> void:
	_stop_close_animation(false)
	_stop_typewriter(false)
	show()
	move_to_front()
	current_choices = choices.duplicate(true)
	title_label.text = title_text
	preview_rect.texture = preview_texture
	preview_rect.visible = preview_texture != null
	preview_caption_label.text = preview_caption
	preview_caption_label.visible = preview_rect.visible and not preview_caption.is_empty()
	body_label.text = body_text
	body_label.scroll_to_line(0)
	_pending_cancel_text = cancel_text
	cancel_button.text = cancel_text
	_queued_close_signal = false
	_is_info_popup = not body_text.is_empty()
	_choice_buttons.clear()

	for child in button_container.get_children():
		child.queue_free()
	for choice in current_choices:
		var button := DecisionChoiceButtonScene.instantiate() as DecisionChoiceButtonScript
		button.configure(
			String(choice.get("label", "")),
			String(choice.get("summary", "")),
			String(choice.get("tooltip", choice.get("summary", "")))
		)
		button.disabled = bool(choice.get("disabled", false))
		button.pressed.connect(_on_choice_pressed.bind(String(choice.get("id", ""))))
		button_container.add_child(button)
		_choice_buttons.append(button)
	_apply_responsive_layout()
	_wire_focus_neighbors()
	_refresh_focus_targets()

	if _is_info_popup:
		_play_open_animation()
		_play_typewriter()
	else:
		modulate.a = 1.0
		body_label.visible_ratio = 1.0
		_focus_primary_action()

func close_panel() -> void:
	if _is_info_popup:
		_begin_close_animation(true)
		return
	_stop_typewriter(true)
	hide()
	closed.emit()

func _on_choice_pressed(choice_id: String) -> void:
	_stop_typewriter(true)
	_stop_close_animation(false)
	hide()
	choice_selected.emit(choice_id)

func _on_cancel_pressed() -> void:
	if _is_typing:
		_finish_typewriter()
		return
	if _is_info_popup:
		_begin_close_animation(true)
		return
	hide()
	closed.emit()

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
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

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
	var visible_chars := body_label.get_total_character_count()
	if visible_chars <= 0:
		body_label.visible_ratio = 1.0
		cancel_button.text = _pending_cancel_text
		_refresh_focus_targets()
		return
	_is_typing = true
	body_label.visible_ratio = 0.0
	cancel_button.text = "跳过"
	_refresh_focus_targets()
	var duration := clampf(float(visible_chars) / TYPEWRITER_CHARS_PER_SECOND, TYPEWRITER_MIN_DURATION, TYPEWRITER_MAX_DURATION)
	_body_tween = create_tween()
	_body_tween.tween_property(body_label, "visible_ratio", 1.0, duration)
	_body_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_finished() -> void:
	_body_tween = null
	_finish_typewriter()

func _finish_typewriter() -> void:
	if _body_tween:
		_body_tween.kill()
		_body_tween = null
	body_label.visible_ratio = 1.0
	_is_typing = false
	cancel_button.text = _pending_cancel_text
	_refresh_focus_targets()
	_focus_primary_action()

func _stop_typewriter(show_all_text: bool) -> void:
	if _body_tween:
		_body_tween.kill()
		_body_tween = null
	if show_all_text:
		body_label.visible_ratio = 1.0
	_is_typing = false
	cancel_button.text = _pending_cancel_text
	_refresh_focus_targets()

func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var short_height := size.y < 360.0
	title_label.add_theme_font_size_override("font_size", 20 if short_height else 24)
	preview_rect.custom_minimum_size = Vector2(0, 120 if short_height else 180)
	preview_caption_label.add_theme_font_size_override("font_size", 12 if short_height else 14)
	body_label.custom_minimum_size = Vector2(0, 72 if short_height else 96)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.custom_minimum_size = Vector2(0, 42 if short_height else 46)
	for child in button_container.get_children():
		var button := child as Button
		if button == null:
			continue
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 48 if short_height else 56)

func _wire_focus_neighbors() -> void:
	for index in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		if button == null:
			continue
		if index > 0:
			button.focus_neighbor_top = _choice_buttons[index - 1].get_path()
		elif _choice_buttons.size() > 0:
			button.focus_neighbor_top = cancel_button.get_path()
		if index + 1 < _choice_buttons.size():
			button.focus_neighbor_bottom = _choice_buttons[index + 1].get_path()
		else:
			button.focus_neighbor_bottom = cancel_button.get_path()
	if not _choice_buttons.is_empty():
		cancel_button.focus_neighbor_top = _choice_buttons[_choice_buttons.size() - 1].get_path()
		cancel_button.focus_neighbor_bottom = _choice_buttons[0].get_path()

func _refresh_focus_targets() -> void:
	for button in _choice_buttons:
		if button == null:
			continue
		button.disabled = _is_typing or bool(current_choices[_choice_buttons.find(button)].get("disabled", false))

func _focus_primary_action() -> void:
	for button in _choice_buttons:
		if button != null and not button.disabled:
			button.grab_focus()
			return
	cancel_button.grab_focus()

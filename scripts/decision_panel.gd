class_name DecisionPanel
extends PanelContainer

signal choice_selected(choice_id: String)
signal closed

const TYPEWRITER_CHARS_PER_SECOND := 72.0
const TYPEWRITER_MIN_DURATION := 0.18
const TYPEWRITER_MAX_DURATION := 2.60
const PANEL_FADE_IN_DURATION := 0.20
const PANEL_FADE_OUT_DURATION := 0.16

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
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

func _ready() -> void:
	hide()
	modulate.a = 1.0
	cancel_button.pressed.connect(_on_cancel_pressed)
	body_label.gui_input.connect(_on_body_label_gui_input)

func open_panel(title_text: String, body_text: String, choices: Array, cancel_text: String = "取消") -> void:
	_stop_close_animation(false)
	_stop_typewriter(false)
	show()
	move_to_front()
	current_choices = choices.duplicate(true)
	title_label.text = title_text
	body_label.text = body_text
	_pending_cancel_text = cancel_text
	cancel_button.text = cancel_text
	_queued_close_signal = false
	_is_info_popup = not body_text.is_empty()

	for child in button_container.get_children():
		child.queue_free()
	for choice in current_choices:
		var button := Button.new()
		button.custom_minimum_size = Vector2(360, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%s\n%s" % [String(choice.get("label", "")), String(choice.get("summary", ""))]
		button.tooltip_text = String(choice.get("tooltip", choice.get("summary", "")))
		button.disabled = bool(choice.get("disabled", false))
		button.pressed.connect(_on_choice_pressed.bind(String(choice.get("id", ""))))
		button_container.add_child(button)

	if _is_info_popup:
		_play_open_animation()
		_play_typewriter()
	else:
		modulate.a = 1.0
		body_label.visible_ratio = 1.0

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
		return
	_is_typing = true
	body_label.visible_ratio = 0.0
	cancel_button.text = "跳过"
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

func _stop_typewriter(show_all_text: bool) -> void:
	if _body_tween:
		_body_tween.kill()
		_body_tween = null
	if show_all_text:
		body_label.visible_ratio = 1.0
	_is_typing = false
	cancel_button.text = _pending_cancel_text

class_name DecisionPanel
extends PanelContainer

signal choice_selected(choice_id: String)
signal closed

const TYPEWRITER_CHARS_PER_SECOND := 72.0
const TYPEWRITER_MIN_DURATION := 0.18
const TYPEWRITER_MAX_DURATION := 2.60

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: RichTextLabel = $MarginContainer/VBoxContainer/BodyLabel
@onready var button_container: VBoxContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton

var current_choices := []
var _body_tween: Tween
var _is_typing := false
var _pending_cancel_text := "取消"

func _ready() -> void:
	hide()
	cancel_button.pressed.connect(_on_cancel_pressed)
	body_label.gui_input.connect(_on_body_label_gui_input)

func open_panel(title_text: String, body_text: String, choices: Array, cancel_text: String = "取消") -> void:
	show()
	current_choices = choices.duplicate(true)
	title_label.text = title_text
	body_label.text = body_text
	_pending_cancel_text = cancel_text
	cancel_button.text = cancel_text
	_stop_typewriter(false)
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
	if current_choices.is_empty() and not body_text.is_empty():
		_play_typewriter()
	else:
		body_label.visible_ratio = 1.0

func close_panel() -> void:
	_stop_typewriter(true)
	hide()
	closed.emit()

func _on_choice_pressed(choice_id: String) -> void:
	_stop_typewriter(true)
	hide()
	choice_selected.emit(choice_id)

func _on_cancel_pressed() -> void:
	if _is_typing:
		_finish_typewriter()
		return
	hide()
	closed.emit()

func _on_body_label_gui_input(event: InputEvent) -> void:
	if not _is_typing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_typewriter()

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

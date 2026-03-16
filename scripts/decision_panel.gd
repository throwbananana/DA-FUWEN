class_name DecisionPanel
extends PanelContainer

signal choice_selected(choice_id: String)
signal closed

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: RichTextLabel = $MarginContainer/VBoxContainer/BodyLabel
@onready var button_container: VBoxContainer = $MarginContainer/VBoxContainer/ButtonContainer
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton

var current_choices := []

func _ready() -> void:
	hide()
	cancel_button.pressed.connect(_on_cancel_pressed)

func open_panel(title_text: String, body_text: String, choices: Array, cancel_text: String = "取消") -> void:
	show()
	current_choices = choices.duplicate(true)
	title_label.text = title_text
	body_label.text = body_text
	cancel_button.text = cancel_text
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

func close_panel() -> void:
	hide()
	closed.emit()

func _on_choice_pressed(choice_id: String) -> void:
	hide()
	choice_selected.emit(choice_id)

func _on_cancel_pressed() -> void:
	hide()
	closed.emit()

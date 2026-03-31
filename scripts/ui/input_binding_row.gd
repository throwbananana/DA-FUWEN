class_name InputBindingRow
extends HBoxContainer

@onready var action_label: Label = $ActionLabel
@onready var slot_button_1: Button = $SlotButton1
@onready var slot_button_2: Button = $SlotButton2
@onready var slot_button_3: Button = $SlotButton3
@onready var slot_button_4: Button = $SlotButton4

func set_action_label(text: String) -> void:
	action_label.text = text

func get_slot_buttons() -> Array[Button]:
	return [slot_button_1, slot_button_2, slot_button_3, slot_button_4]

func set_button_height(height: float) -> void:
	for button in get_slot_buttons():
		button.custom_minimum_size = Vector2(0, height)

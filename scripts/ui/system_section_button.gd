class_name SystemSectionButton
extends Button

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_label(text: String) -> void:
	self.text = text

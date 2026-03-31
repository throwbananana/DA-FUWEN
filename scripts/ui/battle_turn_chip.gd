class_name BattleTurnChip
extends PanelContainer

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel

func set_content(name_text: String, state_text: String) -> void:
	name_label.text = name_text
	state_label.text = state_text

func apply_visual_state(is_active: bool, is_next: bool, is_done: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0

	if is_active:
		style.bg_color = Color(0.42, 0.28, 0.12, 0.94)
		style.border_color = Color(0.98, 0.84, 0.40, 1.0)
		state_label.modulate = Color(1.0, 0.92, 0.70, 0.92)
	elif is_next:
		style.bg_color = Color(0.14, 0.24, 0.36, 0.94)
		style.border_color = Color(0.48, 0.84, 1.0, 1.0)
		state_label.modulate = Color(0.82, 0.89, 1.0, 0.82)
	elif is_done:
		style.bg_color = Color(0.10, 0.12, 0.16, 0.88)
		style.border_color = Color(0.34, 0.40, 0.52, 0.68)
		state_label.modulate = Color(0.70, 0.76, 0.84, 0.76)
	else:
		style.bg_color = Color(0.12, 0.17, 0.24, 0.92)
		style.border_color = Color(0.40, 0.54, 0.72, 0.70)
		state_label.modulate = Color(0.82, 0.89, 1.0, 0.82)

	add_theme_stylebox_override("panel", style)

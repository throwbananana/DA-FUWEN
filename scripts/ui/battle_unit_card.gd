class_name BattleUnitCard
extends Button

@onready var name_label: Label = $MarginContainer/VBoxContainer/TopRow/NameLabel
@onready var badge_label: Label = $MarginContainer/VBoxContainer/TopRow/BadgeLabel
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HpBar
@onready var stat_label: Label = $MarginContainer/VBoxContainer/StatLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	text = ""

func set_content(data: Dictionary) -> void:
	text = ""
	name_label.text = String(data.get("name_text", ""))
	badge_label.text = String(data.get("badge_text", ""))
	badge_label.visible = not badge_label.text.is_empty()
	hp_bar.max_value = maxi(1, int(data.get("hp_max", 1)))
	hp_bar.value = int(data.get("hp_value", 0))
	stat_label.text = String(data.get("stat_text", ""))
	status_label.text = String(data.get("status_text", ""))
	status_label.visible = not status_label.text.is_empty()
	name_label.modulate = Color(data.get("text_color", Color.WHITE))
	stat_label.modulate = Color(data.get("subtle_color", Color(0.82, 0.88, 0.96, 0.9)))
	badge_label.modulate = Color(data.get("badge_color", Color.WHITE))
	status_label.modulate = Color(data.get("badge_color", Color.WHITE))

func apply_visual_state(card_state: Dictionary) -> void:
	modulate = Color(card_state.get("modulate_color", Color.WHITE))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(card_state.get("bg_color", Color(0.12, 0.16, 0.24, 0.96)))
	normal.border_color = Color(card_state.get("border_color", Color(0.42, 0.58, 0.78, 0.60)))
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(
		minf(normal.bg_color.r + 0.03, 1.0),
		minf(normal.bg_color.g + 0.03, 1.0),
		minf(normal.bg_color.b + 0.03, 1.0),
		normal.bg_color.a
	)
	add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(
		normal.bg_color.r * 0.92,
		normal.bg_color.g * 0.92,
		normal.bg_color.b * 0.92,
		normal.bg_color.a
	)
	add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.14, 0.16, 0.20, 0.64)
	disabled.border_color = Color(0.34, 0.38, 0.44, 0.60)
	add_theme_stylebox_override("disabled", disabled)

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_left = 8
	background.corner_radius_bottom_right = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(card_state.get("fill_color", Color(0.36, 0.82, 1.0, 1.0)))
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	hp_bar.add_theme_stylebox_override("background", background)
	hp_bar.add_theme_stylebox_override("fill", fill)

class_name BoardNodeButton
extends Button

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var footer_label: Label = $MarginContainer/VBoxContainer/FooterLabel

func _ready() -> void:
	text = ""

func set_content(title_text: String, footer_text: String, tooltip_text: String) -> void:
	text = ""
	title_label.text = title_text
	footer_label.text = footer_text
	footer_label.visible = not footer_text.is_empty()
	self.tooltip_text = tooltip_text

func apply_metrics(target_size: Vector2, scale_factor: float) -> void:
	size = target_size
	custom_minimum_size = target_size
	var title_size := 12 if scale_factor <= 0.72 else (13 if scale_factor < 1.0 else 14)
	var footer_size := 10 if scale_factor <= 0.72 else (11 if scale_factor < 1.0 else 12)
	title_label.add_theme_font_size_override("font_size", title_size)
	footer_label.add_theme_font_size_override("font_size", footer_size)

func apply_visual_state(accent: Color, is_selectable: bool, is_current: bool, is_locked: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.16, 0.24, 0.96)
	normal.border_color = accent.darkened(0.15)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	if is_current:
		normal.bg_color = Color(0.24, 0.19, 0.10, 0.98)
		normal.border_color = Color(1.0, 0.84, 0.42, 1.0)
	elif is_selectable:
		normal.bg_color = Color(0.14, 0.20, 0.30, 0.98)
		normal.border_color = accent.lightened(0.25)
	elif is_locked:
		normal.bg_color = Color(0.10, 0.11, 0.14, 0.88)
		normal.border_color = Color(0.33, 0.36, 0.42, 0.88)

	var hover := normal.duplicate()
	hover.bg_color = Color(
		minf(normal.bg_color.r + 0.03, 1.0),
		minf(normal.bg_color.g + 0.03, 1.0),
		minf(normal.bg_color.b + 0.03, 1.0),
		normal.bg_color.a
	)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(
		normal.bg_color.r * 0.92,
		normal.bg_color.g * 0.92,
		normal.bg_color.b * 0.92,
		normal.bg_color.a
	)
	var disabled := normal.duplicate()
	if not is_current:
		disabled.bg_color = Color(0.10, 0.11, 0.15, 0.68)
		disabled.border_color = Color(0.29, 0.33, 0.40, 0.70)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled)

	var title_color := Color(0.96, 0.97, 1.0, 1.0)
	var footer_color := Color(0.82, 0.88, 0.96, 0.94)
	if is_locked and not is_current:
		title_color = Color(0.74, 0.78, 0.84, 0.92)
		footer_color = Color(0.62, 0.66, 0.72, 0.90)

	title_label.add_theme_color_override("font_color", title_color)
	footer_label.add_theme_color_override("font_color", footer_color)

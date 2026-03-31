class_name BoardNodeActor
extends Button

@onready var selection_ring: PanelContainer = $SelectionRing
@onready var current_ring: PanelContainer = $CurrentRing
@onready var background_panel: PanelContainer = $Background
@onready var type_icon: Label = $ContentMargin/ContentVBox/TopRow/TypeIcon
@onready var title_label: Label = $ContentMargin/ContentVBox/TopRow/TitleLabel
@onready var danger_badge: Label = $ContentMargin/ContentVBox/TopRow/Badges/DangerBadge
@onready var lock_badge: Label = $ContentMargin/ContentVBox/TopRow/Badges/LockBadge
@onready var footer_label: Label = $ContentMargin/ContentVBox/MarkerRow/FooterLabel

var _node_definition: Dictionary = {}
var _type_short := "?"

func _ready() -> void:
	text = ""
	flat = true

func apply_definition(node_data: Dictionary, type_short_text: String) -> void:
	_node_definition = node_data.duplicate(true)
	_type_short = type_short_text
	type_icon.text = _type_short
	title_label.text = String(_node_definition.get("name", "节点"))

func apply_metrics(target_size: Vector2, scale_factor: float) -> void:
	size = target_size
	custom_minimum_size = target_size
	var title_size := 12 if scale_factor <= 0.72 else (13 if scale_factor < 1.0 else 14)
	var footer_size := 10 if scale_factor <= 0.72 else (11 if scale_factor < 1.0 else 12)
	var icon_size := 13 if scale_factor <= 0.72 else (14 if scale_factor < 1.0 else 16)
	title_label.add_theme_font_size_override("font_size", title_size)
	footer_label.add_theme_font_size_override("font_size", footer_size)
	type_icon.add_theme_font_size_override("font_size", icon_size)
	danger_badge.add_theme_font_size_override("font_size", footer_size)
	lock_badge.add_theme_font_size_override("font_size", footer_size)

func apply_runtime_state(runtime_state: Dictionary) -> void:
	var marker_text := String(runtime_state.get("marker_text", ""))
	var is_current := bool(runtime_state.get("is_current", false))
	var is_selectable := bool(runtime_state.get("is_selectable", false))
	var is_locked := bool(runtime_state.get("is_locked", false))
	var is_danger := bool(runtime_state.get("is_danger", false))
	var accent := Color(runtime_state.get("accent_color", Color(0.70, 0.78, 0.90, 1.0)))
	self.tooltip_text = String(runtime_state.get("tooltip_text", ""))

	title_label.text = String(_node_definition.get("name", "节点"))
	type_icon.text = _type_short
	footer_label.text = marker_text if not is_current else ("你在这里" if marker_text.is_empty() else "%s · 你在这里" % marker_text)
	footer_label.visible = not footer_label.text.is_empty()

	lock_badge.visible = is_locked and not is_selectable
	danger_badge.visible = is_danger
	selection_ring.visible = is_selectable and not is_current
	current_ring.visible = is_current

	type_icon.modulate = accent.lightened(0.25)
	danger_badge.modulate = Color(1.0, 0.78, 0.52, 1.0)
	lock_badge.modulate = Color(0.72, 0.78, 0.86, 0.96)

	var title_color := Color(0.96, 0.97, 1.0, 1.0)
	var footer_color := Color(0.82, 0.88, 0.96, 0.94)
	if is_locked and not is_current:
		title_color = Color(0.74, 0.78, 0.84, 0.92)
		footer_color = Color(0.62, 0.66, 0.72, 0.90)
	title_label.add_theme_color_override("font_color", title_color)
	footer_label.add_theme_color_override("font_color", footer_color)

	_apply_background_style(accent, is_selectable, is_current, is_locked)
	_apply_ring_style(selection_ring, Color(0.96, 0.72, 0.26, 0.92), 2)
	_apply_ring_style(current_ring, Color(1.0, 0.84, 0.42, 1.0), 3)

func set_content(title_text: String, footer_text: String, tooltip_text: String) -> void:
	title_label.text = title_text
	footer_label.text = footer_text
	footer_label.visible = not footer_text.is_empty()
	self.tooltip_text = tooltip_text

func apply_visual_state(accent: Color, is_selectable: bool, is_current: bool, is_locked: bool) -> void:
	apply_runtime_state({
		"marker_text": footer_label.text,
		"tooltip_text": tooltip_text,
		"is_selectable": is_selectable,
		"is_current": is_current,
		"is_locked": is_locked,
		"is_danger": danger_badge.visible,
		"accent_color": accent,
	})

func _apply_background_style(accent: Color, is_selectable: bool, is_current: bool, is_locked: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.bg_color = Color(0.11, 0.16, 0.24, 0.96)
	style.border_color = accent.darkened(0.15)
	if is_current:
		style.bg_color = Color(0.24, 0.19, 0.10, 0.98)
		style.border_color = Color(1.0, 0.84, 0.42, 1.0)
	elif is_selectable:
		style.bg_color = Color(0.14, 0.20, 0.30, 0.98)
		style.border_color = accent.lightened(0.25)
	elif is_locked:
		style.bg_color = Color(0.10, 0.11, 0.14, 0.88)
		style.border_color = Color(0.33, 0.36, 0.42, 0.88)
	background_panel.add_theme_stylebox_override("panel", style)

func _apply_ring_style(target: PanelContainer, color: Color, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	target.add_theme_stylebox_override("panel", style)

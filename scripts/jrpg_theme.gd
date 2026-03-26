extends RefCounted
class_name JrpgTheme

static func build(default_font: Font = null) -> Theme:
	var theme := Theme.new()
	if default_font != null:
		theme.default_font = default_font

	var panel := _box(
		Color("0D1730"),
		Color("C9A96B"),
		3,
		18,
		Color(0, 0, 0, 0.22),
		6,
		Vector2(0, 3),
		18, 14, 18, 14
	)

	var popup_panel := _box(
		Color("101D3D"),
		Color("E2C27F"),
		3,
		20,
		Color(0, 0, 0, 0.26),
		8,
		Vector2(0, 4),
		22, 18, 22, 18
	)

	var button_normal := _box(
		Color("22406E"),
		Color("D6B46A"),
		3,
		16,
		Color(0, 0, 0, 0.18),
		4,
		Vector2(0, 2),
		18, 10, 18, 10
	)

	var button_hover := _box(
		Color("2C538E"),
		Color("F0D08A"),
		3,
		16,
		Color(0, 0, 0, 0.20),
		5,
		Vector2(0, 3),
		18, 10, 18, 10
	)

	var button_pressed := _box(
		Color("173055"),
		Color("C8A25A"),
		3,
		16,
		Color(0, 0, 0, 0.10),
		2,
		Vector2(0, 1),
		18, 11, 18, 9
	)

	var button_hover_pressed := _box(
		Color("1D3A65"),
		Color("F2D58F"),
		3,
		16,
		Color(0, 0, 0, 0.12),
		2,
		Vector2(0, 1),
		18, 11, 18, 9
	)

	var button_disabled := _box(
		Color("3B465B"),
		Color("7B7F8B"),
		2,
		16,
		Color(0, 0, 0, 0.06),
		1,
		Vector2.ZERO,
		18, 10, 18, 10
	)

	var button_focus := _focus_ring(Color("FFE49A"), 4, 20)

	var popup_menu_panel := _box(
		Color("0F1B36"),
		Color("D6B46A"),
		2,
		14,
		Color(0, 0, 0, 0.24),
		6,
		Vector2(0, 3),
		10, 8, 10, 8
	)

	var popup_menu_hover := _box(
		Color("28497C"),
		Color("F0D08A"),
		2,
		10,
		Color(0, 0, 0, 0.10),
		0,
		Vector2.ZERO,
		8, 6, 8, 6
	)

	var popup_menu_separator := _line_box(Color("C9A96B"), 1, 6, 4)
	var popup_menu_labeled_separator_left := _line_box(Color("6E7B99"), 1, 6, 3)
	var popup_menu_labeled_separator_right := _line_box(Color("6E7B99"), 1, 6, 3)

	var tab_bar_background := _box(
		Color("111E39"),
		Color("8B7448"),
		1,
		14,
		Color(0, 0, 0, 0.10),
		0,
		Vector2.ZERO,
		6, 6, 6, 6
	)

	var tab_unselected := _box(
		Color("1C2D52"),
		Color("8E7A53"),
		2,
		14,
		Color(0, 0, 0, 0.10),
		0,
		Vector2.ZERO,
		14, 8, 14, 8
	)

	var tab_hovered := _box(
		Color("28497C"),
		Color("E7C67D"),
		2,
		14,
		Color(0, 0, 0, 0.10),
		0,
		Vector2.ZERO,
		14, 8, 14, 8
	)

	var tab_selected := _box(
		Color("355A93"),
		Color("F3D997"),
		3,
		14,
		Color(0, 0, 0, 0.08),
		0,
		Vector2.ZERO,
		14, 9, 14, 9
	)

	var tab_disabled := _box(
		Color("2C3342"),
		Color("5E6472"),
		2,
		14,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		14, 8, 14, 8
	)

	var tab_focus := _focus_ring(Color("FFE49A"), 3, 16)
	var tab_container_panel := panel.duplicate()

	var line_edit_normal := _box(
		Color("111E39"),
		Color("8E7A53"),
		2,
		14,
		Color(0, 0, 0, 0.08),
		0,
		Vector2.ZERO,
		14, 10, 14, 10
	)

	var line_edit_read_only := _box(
		Color("17233C"),
		Color("5E6472"),
		2,
		14,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		14, 10, 14, 10
	)

	var line_edit_focus := _focus_ring(Color("FFE49A"), 3, 16)

	var text_edit_normal := _box(
		Color("0E1931"),
		Color("8E7A53"),
		2,
		16,
		Color(0, 0, 0, 0.10),
		0,
		Vector2.ZERO,
		14, 12, 14, 12
	)

	var text_edit_read_only := _box(
		Color("15223B"),
		Color("5E6472"),
		2,
		16,
		Color(0, 0, 0, 0.05),
		0,
		Vector2.ZERO,
		14, 12, 14, 12
	)

	var text_edit_focus := _focus_ring(Color("FFE49A"), 3, 18)

	var rich_text_normal := _box(
		Color("0C1730"),
		Color("7E6B45"),
		2,
		16,
		Color(0, 0, 0, 0.06),
		0,
		Vector2.ZERO,
		14, 12, 14, 12
	)

	var rich_text_focus := _focus_ring(Color("FFE49A"), 3, 18)
	var rich_text_rule := _line_box(Color("C9A96B"), 2, 4, 6)

	var progress_background := _box(
		Color("0B1630"),
		Color("8E7A53"),
		2,
		999,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		6, 6, 6, 6
	)

	var progress_fill := _box(
		Color("3E6EB0"),
		Color("F3D997"),
		2,
		999,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		6, 6, 6, 6
	)

	var scroll_track := _box(
		Color("0B1630"),
		Color("7E6B45"),
		1,
		999,
		Color(0, 0, 0, 0.02),
		0,
		Vector2.ZERO,
		2, 2, 2, 2
	)

	var scroll_track_focus := _box(
		Color("102046"),
		Color("F0D08A"),
		1,
		999,
		Color(0, 0, 0, 0.02),
		0,
		Vector2.ZERO,
		2, 2, 2, 2
	)

	var scroll_grabber := _box(
		Color("22406E"),
		Color("D6B46A"),
		2,
		999,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		4, 4, 4, 4
	)

	var scroll_grabber_hover := _box(
		Color("2C538E"),
		Color("F0D08A"),
		2,
		999,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		4, 4, 4, 4
	)

	var scroll_grabber_pressed := _box(
		Color("173055"),
		Color("F3D997"),
		2,
		999,
		Color(0, 0, 0, 0.04),
		0,
		Vector2.ZERO,
		4, 4, 4, 4
	)

	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", popup_panel)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("hover_pressed", "Button", button_hover_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", button_focus)

	theme.set_color("font_color", "Button", Color("F7F1DE"))
	theme.set_color("font_hover_color", "Button", Color("FFF6E7"))
	theme.set_color("font_pressed_color", "Button", Color("F2E0B7"))
	theme.set_color("font_hover_pressed_color", "Button", Color("FFF7DA"))
	theme.set_color("font_disabled_color", "Button", Color("A7A7A7"))
	theme.set_color("font_focus_color", "Button", Color("FFF6E7"))
	theme.set_color("font_outline_color", "Button", Color("1A2340"))
	theme.set_constant("outline_size", "Button", 2)
	theme.set_constant("h_separation", "Button", 8)

	# OptionButton inherits Button, but its dropdown arrow is a dedicated theme item.
	theme.set_stylebox("normal", "OptionButton", button_normal.duplicate())
	theme.set_stylebox("hover", "OptionButton", button_hover.duplicate())
	theme.set_stylebox("pressed", "OptionButton", button_pressed.duplicate())
	theme.set_stylebox("hover_pressed", "OptionButton", button_hover_pressed.duplicate())
	theme.set_stylebox("disabled", "OptionButton", button_disabled.duplicate())
	theme.set_stylebox("focus", "OptionButton", button_focus.duplicate())
	theme.set_color("font_color", "OptionButton", Color("F7F1DE"))
	theme.set_color("font_hover_color", "OptionButton", Color("FFF6E7"))
	theme.set_color("font_pressed_color", "OptionButton", Color("F2E0B7"))
	theme.set_color("font_hover_pressed_color", "OptionButton", Color("FFF7DA"))
	theme.set_color("font_disabled_color", "OptionButton", Color("A7A7A7"))
	theme.set_color("font_focus_color", "OptionButton", Color("FFF6E7"))
	theme.set_color("font_outline_color", "OptionButton", Color("1A2340"))
	theme.set_constant("outline_size", "OptionButton", 2)
	theme.set_constant("h_separation", "OptionButton", 8)
	theme.set_constant("arrow_margin", "OptionButton", 10)
	theme.set_constant("modulate_arrow", "OptionButton", 1)

	# OptionButton.get_popup() returns an internal PopupMenu, so style PopupMenu globally too.
	theme.set_stylebox("panel", "PopupMenu", popup_menu_panel)
	theme.set_stylebox("hover", "PopupMenu", popup_menu_hover)
	theme.set_stylebox("separator", "PopupMenu", popup_menu_separator)
	theme.set_stylebox("labeled_separator_left", "PopupMenu", popup_menu_labeled_separator_left)
	theme.set_stylebox("labeled_separator_right", "PopupMenu", popup_menu_labeled_separator_right)
	theme.set_color("font_color", "PopupMenu", Color("F7F1DE"))
	theme.set_color("font_hover_color", "PopupMenu", Color("FFF8E6"))
	theme.set_color("font_disabled_color", "PopupMenu", Color("9A9AA3"))
	theme.set_color("font_separator_color", "PopupMenu", Color("E7C67D"))
	theme.set_color("font_outline_color", "PopupMenu", Color("0D1730"))
	theme.set_color("font_separator_outline_color", "PopupMenu", Color("0D1730"))
	theme.set_color("font_accelerator_color", "PopupMenu", Color("D7C39A"))
	theme.set_constant("outline_size", "PopupMenu", 1)
	theme.set_constant("separator_outline_size", "PopupMenu", 1)
	theme.set_constant("item_start_padding", "PopupMenu", 8)
	theme.set_constant("item_end_padding", "PopupMenu", 8)
	theme.set_constant("h_separation", "PopupMenu", 8)
	theme.set_constant("v_separation", "PopupMenu", 4)

	# Some scenes may use TabContainer directly, others may use a standalone TabBar.
	for theme_type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_unselected", theme_type, tab_unselected.duplicate())
		theme.set_stylebox("tab_hovered", theme_type, tab_hovered.duplicate())
		theme.set_stylebox("tab_selected", theme_type, tab_selected.duplicate())
		theme.set_stylebox("tab_disabled", theme_type, tab_disabled.duplicate())
		theme.set_stylebox("tab_focus", theme_type, tab_focus.duplicate())
		theme.set_color("font_unselected_color", theme_type, Color("D7DDF1"))
		theme.set_color("font_hovered_color", theme_type, Color("FFF2CF"))
		theme.set_color("font_selected_color", theme_type, Color("FFF8E6"))
		theme.set_color("font_disabled_color", theme_type, Color("8E93A3"))
		theme.set_color("font_outline_color", theme_type, Color("0D1730"))
		theme.set_constant("outline_size", theme_type, 1)
		theme.set_constant("icon_separation", theme_type, 6)
		theme.set_constant("side_margin", theme_type, 10)
		theme.set_constant("tab_separation", theme_type, 4)

	theme.set_stylebox("tabbar_background", "TabContainer", tab_bar_background)
	theme.set_stylebox("panel", "TabContainer", tab_container_panel)
	theme.set_stylebox("button_highlight", "TabBar", button_hover.duplicate())
	theme.set_stylebox("button_pressed", "TabBar", button_pressed.duplicate())

	theme.set_stylebox("normal", "LineEdit", line_edit_normal)
	theme.set_stylebox("read_only", "LineEdit", line_edit_read_only)
	theme.set_stylebox("focus", "LineEdit", line_edit_focus)
	theme.set_color("font_color", "LineEdit", Color("F7F1DE"))
	theme.set_color("font_outline_color", "LineEdit", Color("0D1730"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("A9B5CE"))
	theme.set_color("font_selected_color", "LineEdit", Color("FFF8E6"))
	theme.set_color("font_uneditable_color", "LineEdit", Color("A7A7A7"))
	theme.set_color("selection_color", "LineEdit", Color("355A93"))
	theme.set_color("caret_color", "LineEdit", Color("FFE49A"))
	theme.set_constant("outline_size", "LineEdit", 1)
	theme.set_constant("minimum_character_width", "LineEdit", 8)

	theme.set_stylebox("normal", "TextEdit", text_edit_normal)
	theme.set_stylebox("read_only", "TextEdit", text_edit_read_only)
	theme.set_stylebox("focus", "TextEdit", text_edit_focus)
	theme.set_color("background_color", "TextEdit", Color("0E1931"))
	theme.set_color("font_color", "TextEdit", Color("F7F1DE"))
	theme.set_color("font_outline_color", "TextEdit", Color("0D1730"))
	theme.set_color("font_placeholder_color", "TextEdit", Color("A9B5CE"))
	theme.set_color("font_readonly_color", "TextEdit", Color("A7A7A7"))
	theme.set_color("font_selected_color", "TextEdit", Color("FFF8E6"))
	theme.set_color("selection_color", "TextEdit", Color("355A93"))
	theme.set_color("current_line_color", "TextEdit", Color(0.17, 0.27, 0.47, 0.55))
	theme.set_color("caret_color", "TextEdit", Color("FFE49A"))
	theme.set_constant("outline_size", "TextEdit", 1)
	theme.set_constant("line_spacing", "TextEdit", 6)

	theme.set_stylebox("normal", "RichTextLabel", rich_text_normal)
	theme.set_stylebox("focus", "RichTextLabel", rich_text_focus)
	theme.set_stylebox("horizontal_rule", "RichTextLabel", rich_text_rule)
	theme.set_color("default_color", "RichTextLabel", Color("F3EBD7"))
	theme.set_color("font_outline_color", "RichTextLabel", Color("0D1730"))
	theme.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.18))
	theme.set_color("font_selected_color", "RichTextLabel", Color("FFF8E6"))
	theme.set_color("selection_color", "RichTextLabel", Color("355A93"))
	theme.set_color("table_border", "RichTextLabel", Color("8E7A53"))
	theme.set_color("table_even_row_bg", "RichTextLabel", Color(0.10, 0.16, 0.29, 0.45))
	theme.set_color("table_odd_row_bg", "RichTextLabel", Color(0.14, 0.22, 0.38, 0.35))
	theme.set_constant("outline_size", "RichTextLabel", 1)
	theme.set_constant("line_separation", "RichTextLabel", 2)
	theme.set_constant("paragraph_separation", "RichTextLabel", 6)

	theme.set_stylebox("background", "ProgressBar", progress_background)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_color("font_color", "ProgressBar", Color("FFF8E6"))
	theme.set_color("font_outline_color", "ProgressBar", Color("0D1730"))
	theme.set_constant("outline_size", "ProgressBar", 1)

	for theme_type in ["ScrollBar", "HScrollBar", "VScrollBar"]:
		theme.set_stylebox("grabber", theme_type, scroll_grabber.duplicate())
		theme.set_stylebox("grabber_highlight", theme_type, scroll_grabber_hover.duplicate())
		theme.set_stylebox("grabber_pressed", theme_type, scroll_grabber_pressed.duplicate())
		theme.set_stylebox("scroll", theme_type, scroll_track.duplicate())
		theme.set_stylebox("scroll_focus", theme_type, scroll_track_focus.duplicate())

	theme.set_color("font_color", "Label", Color("F3EBD7"))

	return theme

static func _box(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int,
	shadow_color: Color,
	shadow_size: int,
	shadow_offset: Vector2,
	margin_left: int,
	margin_top: int,
	margin_right: int,
	margin_bottom: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = shadow_color
	sb.shadow_size = shadow_size
	sb.shadow_offset = shadow_offset
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	sb.content_margin_left = margin_left
	sb.content_margin_top = margin_top
	sb.content_margin_right = margin_right
	sb.content_margin_bottom = margin_bottom
	return sb

static func _focus_ring(color: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.expand_margin_left = 2
	sb.expand_margin_top = 2
	sb.expand_margin_right = 2
	sb.expand_margin_bottom = 2
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	return sb

static func _line_box(color: Color, thickness: int, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.border_width_bottom = thickness
	sb.content_margin_left = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_right = margin_x
	sb.content_margin_bottom = margin_y
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.0
	return sb

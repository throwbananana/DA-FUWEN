class_name SystemPanel
extends PanelContainer

signal closed

@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderRow/HeaderLabel
@onready var section_row: BoxContainer = $MarginContainer/VBoxContainer/SectionRow
@onready var summary_label: RichTextLabel = $MarginContainer/VBoxContainer/SummaryLabel
@onready var detail_label: RichTextLabel = $MarginContainer/VBoxContainer/DetailLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

var current_sections: Array = []
var current_section_id := ""
var _panel_tween: Tween
var _section_tween: Tween

func _ready() -> void:
	hide()
	modulate.a = 1.0
	scale = Vector2.ONE
	_apply_responsive_layout()
	close_button.pressed.connect(close_panel)

func open_panel(title_text: String, sections: Array, initial_section_id: String = "") -> void:
	show()
	move_to_front()
	_apply_responsive_layout()
	header_label.text = title_text
	current_sections = sections.duplicate(true)
	_render_section_buttons()
	if current_sections.is_empty():
		current_section_id = ""
		summary_label.text = ""
		detail_label.text = ""
		return
	var target_id := initial_section_id
	if target_id.is_empty() or _find_section(target_id).is_empty():
		target_id = String(current_sections[0].get("id", ""))
	_select_section(target_id)
	_play_open_animation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func close_panel() -> void:
	if GameState.should_skip_animations():
		hide()
		closed.emit()
		return
	_stop_tweens()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_panel_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.14)
	_panel_tween.finished.connect(func() -> void:
		hide()
		modulate.a = 1.0
		scale = Vector2.ONE
		closed.emit()
	)

func _render_section_buttons() -> void:
	for child in section_row.get_children():
		child.queue_free()
	for section in current_sections:
		var section_id := String(section.get("id", ""))
		if section_id.is_empty():
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.text = String(section.get("label", section_id))
		button.pressed.connect(_on_section_pressed.bind(section_id))
		section_row.add_child(button)

func _on_section_pressed(section_id: String) -> void:
	_select_section(section_id)

func _select_section(section_id: String) -> void:
	var section := _find_section(section_id)
	if section.is_empty():
		return
	current_section_id = section_id
	summary_label.text = String(section.get("summary", ""))
	detail_label.text = String(section.get("body", ""))
	summary_label.scroll_to_line(0)
	detail_label.scroll_to_line(0)
	_play_section_transition()
	for child in section_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_active := button.text == String(section.get("label", section_id))
		button.button_pressed = is_active
		button.modulate = Color(1.0, 0.94, 0.78) if is_active else Color(1, 1, 1)

func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact_width := size.x < 760.0
	var short_height := size.y < 560.0
	header_label.add_theme_font_size_override("font_size", 20 if short_height else 24)
	section_row.vertical = compact_width and short_height
	section_row.add_theme_constant_override("separation", 6 if compact_width else 8)
	summary_label.custom_minimum_size = Vector2(0, 64 if short_height else 84)
	summary_label.scroll_active = true
	for child in section_row.get_children():
		var button := child as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(0, 36 if short_height else 42)

func _play_open_animation() -> void:
	if GameState.should_skip_animations():
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	_stop_tweens()
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_section_transition() -> void:
	if GameState.should_skip_animations():
		return
	if _section_tween != null:
		_section_tween.kill()
	summary_label.modulate = Color(1, 1, 1, 0)
	detail_label.modulate = Color(1, 1, 1, 0)
	summary_label.scale = Vector2(0.99, 0.99)
	detail_label.scale = Vector2(0.99, 0.99)
	_section_tween = create_tween()
	_section_tween.set_parallel(true)
	_section_tween.tween_property(summary_label, "modulate:a", 1.0, 0.12)
	_section_tween.tween_property(summary_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_section_tween.parallel().tween_property(detail_label, "modulate:a", 1.0, 0.14)
	_section_tween.parallel().tween_property(detail_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _stop_tweens() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null
	if _section_tween != null:
		_section_tween.kill()
		_section_tween = null

func _find_section(section_id: String) -> Dictionary:
	for section in current_sections:
		if String(section.get("id", "")) == section_id:
			return Dictionary(section).duplicate(true)
	return {}

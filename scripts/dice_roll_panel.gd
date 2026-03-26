class_name DiceRollPanel
extends PanelContainer

signal confirmed
signal closed
signal plus_requested
signal minus_requested
signal reroll_requested

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var value_label: Label = $MarginContainer/VBoxContainer/ValueLabel
@onready var detail_label: RichTextLabel = $MarginContainer/VBoxContainer/DetailLabel
@onready var button_row: BoxContainer = $MarginContainer/VBoxContainer/ButtonRow
@onready var minus_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MinusButton
@onready var plus_button: Button = $MarginContainer/VBoxContainer/ButtonRow/PlusButton
@onready var reroll_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RerollButton
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/ConfirmButton

var rng := RandomNumberGenerator.new()
var _panel_tween: Tween
var _value_tween: Tween

func _ready() -> void:
	hide()
	rng.randomize()
	modulate.a = 1.0
	scale = Vector2.ONE
	minus_button.focus_mode = Control.FOCUS_ALL
	plus_button.focus_mode = Control.FOCUS_ALL
	reroll_button.focus_mode = Control.FOCUS_ALL
	confirm_button.focus_mode = Control.FOCUS_ALL
	_apply_responsive_layout()
	minus_button.pressed.connect(func() -> void:
		minus_requested.emit()
	)
	plus_button.pressed.connect(func() -> void:
		plus_requested.emit()
	)
	reroll_button.pressed.connect(func() -> void:
		reroll_requested.emit()
	)
	confirm_button.pressed.connect(func() -> void:
		confirmed.emit()
		close_panel()
	)

func open_panel(roll_state: Dictionary, panel_state: Dictionary, animation_mode: String = "roll") -> void:
	show()
	move_to_front()
	_apply_responsive_layout()
	_render(roll_state, panel_state)
	_wire_focus_neighbors()
	_play_open_animation()
	_play_value_feedback(int(roll_state.get("value", 0)), animation_mode)
	call_deferred("_focus_primary_button")

func refresh_panel(roll_state: Dictionary, panel_state: Dictionary, animation_mode: String = "adjust") -> void:
	if not visible:
		open_panel(roll_state, panel_state, animation_mode)
		return
	_apply_responsive_layout()
	_render(roll_state, panel_state)
	_wire_focus_neighbors()
	_play_value_feedback(int(roll_state.get("value", 0)), animation_mode)
	call_deferred("_focus_primary_button")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func close_panel() -> void:
	if GameState.should_skip_animations():
		hide()
		closed.emit()
		return
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_panel_tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.12)
	_panel_tween.finished.connect(func() -> void:
		hide()
		modulate.a = 1.0
		scale = Vector2.ONE
		closed.emit()
	)

func _render(roll_state: Dictionary, panel_state: Dictionary) -> void:
	title_label.text = String(panel_state.get("title", "掷骰结果"))
	subtitle_label.text = String(panel_state.get("subtitle", "确认本回合步数"))
	detail_label.text = String(panel_state.get("body", ""))
	detail_label.scroll_to_line(0)
	confirm_button.text = String(panel_state.get("confirm_text", "查看落点"))
	button_row.visible = bool(panel_state.get("advanced_controls_visible", true))
	plus_button.disabled = not bool(panel_state.get("can_plus", false))
	minus_button.disabled = not bool(panel_state.get("can_minus", false))
	reroll_button.disabled = not bool(panel_state.get("can_reroll", false))
	_apply_responsive_layout()
	if GameState.should_skip_animations():
		value_label.text = str(int(roll_state.get("value", 0)))

func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact_width := size.x < 460.0
	var short_height := size.y < 380.0
	title_label.add_theme_font_size_override("font_size", 24 if short_height else 28)
	subtitle_label.add_theme_font_size_override("font_size", 16 if short_height else 18)
	value_label.add_theme_font_size_override("font_size", 72 if short_height else 96)
	var detail_height := 72 if short_height else (86 if compact_width else 100)
	if button_row.visible:
		detail_height = 80 if short_height else (96 if compact_width else 110)
	detail_label.custom_minimum_size = Vector2(0, detail_height)
	button_row.vertical = button_row.visible and compact_width and short_height
	button_row.add_theme_constant_override("separation", 6 if short_height else 8)
	var button_height := 44 if short_height else 48
	minus_button.custom_minimum_size = Vector2(0, button_height)
	plus_button.custom_minimum_size = Vector2(0, button_height)
	reroll_button.custom_minimum_size = Vector2(0, button_height)
	confirm_button.custom_minimum_size = Vector2(0, 48 if short_height else 52)

func _wire_focus_neighbors() -> void:
	minus_button.focus_neighbor_right = plus_button.get_path()
	plus_button.focus_neighbor_left = minus_button.get_path()
	plus_button.focus_neighbor_right = reroll_button.get_path()
	reroll_button.focus_neighbor_left = plus_button.get_path()
	for button in [minus_button, plus_button, reroll_button]:
		button.focus_neighbor_bottom = confirm_button.get_path()
		confirm_button.focus_neighbor_top = button.get_path()

func _focus_primary_button() -> void:
	for button in [minus_button, plus_button, reroll_button]:
		if button_row.visible and not button.disabled:
			button.grab_focus()
			return
	confirm_button.grab_focus()

func _play_open_animation() -> void:
	if GameState.should_skip_animations():
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	if _panel_tween != null:
		_panel_tween.kill()
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_panel_tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_value_feedback(final_value: int, animation_mode: String) -> void:
	if _value_tween != null:
		_value_tween.kill()
	if GameState.should_skip_animations():
		value_label.text = str(final_value)
		value_label.scale = Vector2.ONE
		return
	value_label.scale = Vector2.ONE
	if animation_mode in ["roll", "reroll"]:
		_value_tween = create_tween()
		for _i in range(8):
			var preview := rng.randi_range(1, 6)
			_value_tween.tween_callback(func() -> void:
				value_label.text = str(preview)
			)
			_value_tween.tween_interval(0.04)
		_value_tween.tween_callback(func() -> void:
			value_label.text = str(final_value)
		)
	else:
		value_label.text = str(final_value)
		_value_tween = create_tween()
	_value_tween.tween_property(value_label, "scale", Vector2(1.12, 1.12), 0.08)
	_value_tween.tween_property(value_label, "scale", Vector2.ONE, 0.12)

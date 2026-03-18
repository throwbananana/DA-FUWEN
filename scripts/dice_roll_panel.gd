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
	_render(roll_state, panel_state)
	_play_open_animation()
	_play_value_feedback(int(roll_state.get("value", 0)), animation_mode)

func refresh_panel(roll_state: Dictionary, panel_state: Dictionary, animation_mode: String = "adjust") -> void:
	if not visible:
		open_panel(roll_state, panel_state, animation_mode)
		return
	_render(roll_state, panel_state)
	_play_value_feedback(int(roll_state.get("value", 0)), animation_mode)

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
	confirm_button.text = String(panel_state.get("confirm_text", "查看落点"))
	plus_button.disabled = not bool(panel_state.get("can_plus", false))
	minus_button.disabled = not bool(panel_state.get("can_minus", false))
	reroll_button.disabled = not bool(panel_state.get("can_reroll", false))
	if GameState.should_skip_animations():
		value_label.text = str(int(roll_state.get("value", 0)))

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

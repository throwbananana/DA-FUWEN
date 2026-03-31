class_name DecisionChoiceButton
extends Button

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

func configure(title_text: String, summary_text: String, tooltip: String = "") -> void:
	title_label.text = title_text
	summary_label.text = summary_text
	summary_label.visible = not summary_text.is_empty()
	tooltip_text = tooltip if not tooltip.is_empty() else summary_text

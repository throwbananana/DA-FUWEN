class_name HabitatCard
extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var detail_label: Label = $MarginContainer/VBoxContainer/DetailLabel

func set_content(title_text: String, detail_text: String) -> void:
	title_label.text = title_text
	detail_label.text = detail_text

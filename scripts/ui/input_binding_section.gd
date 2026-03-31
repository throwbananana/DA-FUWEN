class_name InputBindingSection
extends VBoxContainer

@onready var header_label: Label = $HeaderLabel
@onready var rows_container: VBoxContainer = $RowsContainer

func set_title(text: String) -> void:
	header_label.text = text

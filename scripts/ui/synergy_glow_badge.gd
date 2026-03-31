class_name SynergyGlowBadge
extends PanelContainer

@onready var label: Label = $MarginContainer/Label

func set_unit_name(unit_name: String) -> void:
	label.text = "%s\n共鸣中" % unit_name

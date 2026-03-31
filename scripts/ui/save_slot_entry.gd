class_name SaveSlotEntry
extends Button

signal focused

var slot_id := ""

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var meta_label: Label = $MarginContainer/VBoxContainer/MetaLabel

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(func() -> void:
		focused.emit()
	)

func configure(slot: Dictionary) -> void:
	slot_id = String(slot.get("id", ""))
	title_label.text = String(slot.get("title", slot_id if not slot_id.is_empty() else "存档"))
	if bool(slot.get("exists", false)):
		state_label.text = "已有旅程"
		meta_label.text = _build_meta_text(Dictionary(slot.get("summary", {})).duplicate(true))
	else:
		state_label.text = "空槽"
		meta_label.text = "从这里开始一段新的远征。"

func set_selected(selected: bool) -> void:
	button_pressed = selected
	modulate = Color(1.0, 0.96, 0.82, 1.0) if selected else Color(1, 1, 1, 1)

func _build_meta_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "这格里有旧存档，不过暂时看不到摘要。"
	return "%s · 第 %d / %d 回合 · 第 %d 周" % [
		String(summary.get("season_name", "未知季节")),
		int(summary.get("season_turn", 1)),
		int(summary.get("season_length", 1)),
		int(summary.get("week_index", 1)),
	]

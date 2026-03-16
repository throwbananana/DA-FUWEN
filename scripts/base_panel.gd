class_name BasePanel
extends PanelContainer

const GameData = preload("res://scripts/game_data.gd")

signal assignment_changed(monster_uid: String, role_id: String)
signal upgrade_requested(building_id: String)
signal closed

@onready var summary_label: RichTextLabel = $MarginContainer/VBoxContainer/SummaryLabel
@onready var monster_list: VBoxContainer = $MarginContainer/VBoxContainer/MonsterScroll/MonsterList
@onready var building_list: VBoxContainer = $MarginContainer/VBoxContainer/BuildingScroll/BuildingList
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderRow/CloseButton

func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)

func open_panel(panel_state: Dictionary) -> void:
	show()
	_render_summary(panel_state)
	_render_monsters(panel_state)
	_render_buildings(panel_state)

func close_panel() -> void:
	hide()
	closed.emit()

func _render_summary(panel_state: Dictionary) -> void:
	var resources: Dictionary = panel_state.get("resources", {})
	var preview: Dictionary = panel_state.get("preview", {})
	var lines: Array[String] = []
	lines.append("[b]资源[/b] %d 食粮 / %d 矿石 / %d 灵知" % [
		int(resources.get("food", 0)),
		int(resources.get("ore", 0)),
		int(resources.get("knowledge", 0)),
	])
	lines.append("[b]下回合预计产出[/b] %s" % GameData.format_resource_delta(preview))
	var techs: Array = panel_state.get("techs", [])
	if not techs.is_empty():
		lines.append("[b]已解锁科技[/b] %s" % " / ".join(techs))
	summary_label.text = "\n".join(lines)

func _render_monsters(panel_state: Dictionary) -> void:
	for child in monster_list.get_children():
		child.queue_free()
	var monsters: Array = panel_state.get("monsters", [])
	for monster in monsters:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.text = "%s  HP %d/%d  前线:%d 苗圃:%d 熔炉:%d 研究:%d" % [
			monster.display_name,
			monster.current_hp,
			monster.max_hp,
			monster.get_role_bonus("frontline"),
			monster.get_role_bonus("farm"),
			monster.get_role_bonus("forge"),
			monster.get_role_bonus("lab"),
		]

		var selector := OptionButton.new()
		selector.focus_mode = Control.FOCUS_NONE
		for role_id in GameData.ROLE_ORDER:
			selector.add_item(GameData.get_role_name(role_id))
			if monster.assignment == role_id:
				selector.select(selector.item_count - 1)
		selector.item_selected.connect(_on_assignment_selected.bind(monster.uid))

		row.add_child(info)
		row.add_child(selector)
		monster_list.add_child(row)

func _render_buildings(panel_state: Dictionary) -> void:
	for child in building_list.get_children():
		child.queue_free()
	var buildings: Dictionary = panel_state.get("buildings", {})
	for building_id in GameData.BUILDINGS.keys():
		var level := int(buildings.get(building_id, 1))
		var cost := GameData.get_next_building_cost(building_id, level)

		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := Label.new()
		header.text = "%s Lv.%d" % [GameData.get_building_name(building_id), level]
		header.add_theme_font_size_override("font_size", 18)
		card.add_child(header)

		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = String(GameData.BUILDINGS[building_id].get("description", ""))
		card.add_child(desc)

		var footer := HBoxContainer.new()
		var cost_label := Label.new()
		cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cost.is_empty():
			cost_label.text = "已满级"
		else:
			cost_label.text = "升级消耗：%s" % GameData.format_resource_delta(cost)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = "升级"
		button.disabled = cost.is_empty()
		button.pressed.connect(_on_upgrade_pressed.bind(building_id))
		footer.add_child(cost_label)
		footer.add_child(button)
		card.add_child(footer)

		var separator := HSeparator.new()
		building_list.add_child(card)
		building_list.add_child(separator)

func _on_assignment_selected(index: int, monster_uid: String) -> void:
	var role_id: String = String(GameData.ROLE_ORDER[index])
	assignment_changed.emit(monster_uid, role_id)

func _on_upgrade_pressed(building_id: String) -> void:
	upgrade_requested.emit(building_id)

func _on_close_pressed() -> void:
	hide()
	closed.emit()

class_name BoardView
extends Control

const GameData = preload("res://scripts/game_data.gd")

signal node_chosen(node_id: int)

const TYPE_SHORT := {
	"camp": "营",
	"resource": "资",
	"battle": "战",
	"event": "奇",
	"market": "市",
	"control": "据",
	"research": "研",
	"boss": "王",
}

var board_nodes: Array = []
var buttons := {}
var selectable_nodes: Array[int] = []
var reachable_paths := {}
var player_position := -1
var ai_position := -1
var control_owners := {}
var boss_open := false
var boss_defeated := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func setup(nodes: Array) -> void:
	board_nodes = nodes
	for child in get_children():
		child.queue_free()
	buttons.clear()
	for node in board_nodes:
		var button := Button.new()
		var node_id := int(node.get("id", -1))
		button.name = "Node_%d" % node_id
		button.size = Vector2(120, 86)
		button.position = node.get("position", Vector2.ZERO)
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.flat = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.pressed.connect(_on_node_pressed.bind(node_id))
		add_child(button)
		buttons[node_id] = button
	queue_redraw()

func refresh_view(player_pos: int, ai_pos: int, selectable: Array[int], owners: Dictionary, paths: Dictionary, is_boss_open: bool, is_boss_defeated: bool) -> void:
	player_position = player_pos
	ai_position = ai_pos
	selectable_nodes = selectable.duplicate()
	control_owners = owners.duplicate(true)
	reachable_paths = paths.duplicate(true)
	boss_open = is_boss_open
	boss_defeated = is_boss_defeated
	for node in board_nodes:
		var node_id := int(node.get("id", -1))
		var button: Button = buttons.get(node_id)
		if button == null:
			continue
		var occupants: Array[String] = []
		if player_pos == node_id:
			occupants.append("你")
		if ai_pos == node_id:
			occupants.append("AI")
		var owner_marker := ""
		if owners.get(node_id, "") == "player":
			owner_marker = "★你"
		elif owners.get(node_id, "") == "ai":
			owner_marker = "★AI"
		var type_id := String(node.get("type", ""))
		var type_text: String = String(TYPE_SHORT.get(type_id, "?"))
		var header := "%s [%s]" % [String(node.get("name", "")), type_text]
		if type_id == "boss" and not boss_open and not boss_defeated:
			header = "%s [锁]" % String(node.get("name", ""))
		var footer := owner_marker
		if not occupants.is_empty():
			if footer != "":
				footer += " "
			footer += "·".join(occupants)
		button.text = "%s\n%s" % [header, footer]
		button.tooltip_text = _build_tooltip(node_id, node)
		var is_selectable := selectable_nodes.has(node_id)
		button.disabled = not is_selectable
		button.modulate = Color(1, 1, 1) if is_selectable else Color(0.82, 0.82, 0.86)
		if player_pos == node_id or ai_pos == node_id:
			button.modulate = Color(1.0, 0.96, 0.82)
	queue_redraw()

func _build_tooltip(node_id: int, node: Dictionary) -> String:
	var text := "%s\n%s" % [String(node.get("name", "")), String(node.get("description", ""))]
	if node.has("reward"):
		text += "\n收益：%s" % GameData.format_resource_delta(node.get("reward", {}))
	if node.has("control_reward"):
		text += "\n占领收益：%s" % GameData.format_resource_delta(node.get("control_reward", {}))
	if reachable_paths.has(node_id):
		var path: Array = reachable_paths[node_id]
		var names: Array[String] = []
		for step in path:
			var step_node := GameData.get_board_node(int(step))
			names.append(String(step_node.get("name", step)))
		text += "\n路线：%s" % " -> ".join(names)
	return text

func _draw() -> void:
	for node in board_nodes:
		var start_id := int(node.get("id", -1))
		for edge in node.get("edges", []):
			var end_id := int(edge)
			var start_button: Button = buttons.get(start_id)
			var end_button: Button = buttons.get(end_id)
			if start_button == null or end_button == null:
				continue
			var start_pos := start_button.position + start_button.size / 2.0
			var end_pos := end_button.position + end_button.size / 2.0
			draw_line(start_pos, end_pos, Color("334155"), 3.0, true)
	for node_id in selectable_nodes:
		var button: Button = buttons.get(node_id)
		if button == null:
			continue
		draw_rect(Rect2(button.position - Vector2(4, 4), button.size + Vector2(8, 8)), Color("f59e0b"), false, 3.0)

func _on_node_pressed(node_id: int) -> void:
	if selectable_nodes.has(node_id):
		node_chosen.emit(node_id)

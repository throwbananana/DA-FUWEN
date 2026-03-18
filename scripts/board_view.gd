class_name BoardView
extends Control

signal node_chosen(node_id: int)
signal travel_finished(node_id: int)

const TYPE_SHORT := {
	"camp": "营",
	"habitat": "居",
	"settlement": "聚",
	"dojo": "试",
	"anomaly": "异",
}

var board_nodes: Array = []
var buttons := {}
var selectable_nodes: Array[int] = []
var current_position := -1
var node_markers := {}
var locked_nodes: Array[int] = []

var traveler: ColorRect
var traveler_node_id := -1
var is_traveling := false
var idle_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_traveler()

func _ensure_traveler() -> void:
	if traveler != null:
		return

	traveler = ColorRect.new()
	traveler.name = "Traveler"
	traveler.size = Vector2(24, 24)
	traveler.color = Color("fde68a")
	traveler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	traveler.z_index = 30
	traveler.visible = false
	add_child(traveler)

func setup(nodes: Array) -> void:
	board_nodes = nodes

	for child in get_children():
		if child == traveler:
			continue
		child.queue_free()

	buttons.clear()

	for node in board_nodes:
		var button := Button.new()
		var node_id := int(node.get("id", -1))
		button.name = "Node_%d" % node_id
		button.size = Vector2(118, 72)
		button.position = node.get("position", Vector2.ZERO)
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.flat = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_node_pressed.bind(node_id))
		add_child(button)
		buttons[node_id] = button

	if traveler_node_id != -1 and buttons.has(traveler_node_id):
		_snap_traveler_to(traveler_node_id)

	queue_redraw()

func set_current_node(node_id: int, immediate := true) -> void:
	traveler_node_id = node_id
	current_position = node_id

	if immediate:
		_snap_traveler_to(node_id)
		_play_idle()

	queue_redraw()

func play_travel(path: Array[int]) -> void:
	if path.is_empty():
		return

	if idle_tween != null:
		idle_tween.kill()
		idle_tween = null

	_ensure_traveler()
	is_traveling = true
	traveler.visible = true

	if traveler_node_id == -1:
		traveler_node_id = int(path[0])
		_snap_traveler_to(traveler_node_id)

	for i in range(1, path.size()):
		var next_id := int(path[i])
		var to_pos := _traveler_top_left(next_id)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(traveler, "position", to_pos, 0.24) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(traveler, "scale", Vector2(1.10, 0.92), 0.12)
		tween.chain().tween_property(traveler, "scale", Vector2.ONE, 0.12)

		await tween.finished
		traveler_node_id = next_id
		current_position = next_id
		queue_redraw()

	is_traveling = false
	_play_arrival_punch()
	travel_finished.emit(traveler_node_id)

func _play_arrival_punch() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(traveler, "scale", Vector2(1.18, 0.88), 0.08)
	tween.chain().tween_property(traveler, "scale", Vector2.ONE, 0.10)
	await tween.finished
	_play_idle()

func _play_idle() -> void:
	if traveler == null:
		return
	if idle_tween != null:
		idle_tween.kill()

	idle_tween = create_tween()
	idle_tween.set_loops()
	idle_tween.tween_property(traveler, "scale", Vector2(1.04, 0.96), 0.45)
	idle_tween.tween_property(traveler, "scale", Vector2.ONE, 0.45)

func _snap_traveler_to(node_id: int) -> void:
	if not buttons.has(node_id):
		return
	traveler.visible = true
	traveler.position = _traveler_top_left(node_id)
	traveler.scale = Vector2.ONE

func _button_center(node_id: int) -> Vector2:
	var button: Button = buttons.get(node_id)
	if button == null:
		return Vector2.ZERO
	return button.position + button.size * 0.5

func _traveler_top_left(node_id: int) -> Vector2:
	return _button_center(node_id) - traveler.size * 0.5 + Vector2(0, -42)

func refresh_view(current_pos: int, selectable: Array[int], markers: Dictionary, locked: Array[int]) -> void:
	current_position = current_pos
	selectable_nodes = selectable.duplicate()
	node_markers = markers.duplicate(true)
	locked_nodes = locked.duplicate()

	for node in board_nodes:
		var node_id := int(node.get("id", -1))
		var button: Button = buttons.get(node_id)
		if button == null:
			continue

		var type_id := String(node.get("type", ""))
		var marker_text := String(node_markers.get(node_id, ""))
		var header := "%s [%s]" % [String(node.get("name", "")), String(TYPE_SHORT.get(type_id, "?"))]

		if locked_nodes.has(node_id):
			header = "%s [锁]" % String(node.get("name", ""))

		var footer := marker_text
		if current_position == node_id:
			if not footer.is_empty():
				footer += " · "
			footer += "你在这里"

		button.text = "%s\n%s" % [header, footer]
		button.tooltip_text = _build_tooltip(node_id, node)

		var is_selectable := selectable_nodes.has(node_id) and not locked_nodes.has(node_id)
		button.disabled = not is_selectable
		button.modulate = Color(1, 1, 1) if is_selectable else Color(0.82, 0.82, 0.86)

		if current_position == node_id:
			button.modulate = Color(1.0, 0.96, 0.82)

	queue_redraw()

func _build_tooltip(node_id: int, node: Dictionary) -> String:
	var text := "%s\n%s" % [String(node.get("name", "")), String(node.get("description", ""))]
	if node.has("focus"):
		text += "\n焦点：%s" % String(node.get("focus", ""))
	if node.has("reward_hint"):
		text += "\n预估收益：%s" % String(node.get("reward_hint", ""))
	if node_markers.has(node_id):
		text += "\n状态：%s" % String(node_markers[node_id])
	if node.has("travel_cost"):
		text += "\n路途：%d" % int(node.get("travel_cost", 0))
	return text

func _draw() -> void:
	for node in board_nodes:
		var start_id := int(node.get("id", -1))
		for edge in node.get("edges", []):
			var end_id := int(edge)
			if end_id <= start_id:
				continue

			var start_button: Button = buttons.get(start_id)
			var end_button: Button = buttons.get(end_id)
			if start_button == null or end_button == null:
				continue

			var start_pos := start_button.position + start_button.size / 2.0
			var end_pos := end_button.position + end_button.size / 2.0
			draw_line(start_pos, end_pos, Color("334155"), 2.0, true)

	for node_id in selectable_nodes:
		if locked_nodes.has(node_id):
			continue

		var button: Button = buttons.get(node_id)
		if button == null:
			continue

		draw_rect(
			Rect2(button.position - Vector2(4, 4), button.size + Vector2(8, 8)),
			Color("f59e0b"),
			false,
			2.0
		)

func _on_node_pressed(node_id: int) -> void:
	if is_traveling:
		return
	if selectable_nodes.has(node_id) and not locked_nodes.has(node_id):
		node_chosen.emit(node_id)

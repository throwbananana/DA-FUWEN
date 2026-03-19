class_name BoardView
extends Control

signal node_chosen(node_id: int)
signal travel_finished(node_id: int)
signal observer_travel_finished(node_id: int)

const TYPE_SHORT := {
	"camp": "营",
	"empty": "空",
	"environment": "境",
	"event": "事",
	"habitat": "居",
	"settlement": "聚",
	"dojo": "试",
	"anomaly": "异",
}

const TYPE_COLORS := {
	"camp": Color("7dd3fc"),
	"empty": Color("94a3b8"),
	"environment": Color("93c5fd"),
	"event": Color("f9a8d4"),
	"habitat": Color("86efac"),
	"settlement": Color("fcd34d"),
	"dojo": Color("fb7185"),
	"anomaly": Color("c084fc"),
}

const BUTTON_SIZE := Vector2(118, 72)
const TRAVELER_OFFSET := Vector2(0, -42)
const OBSERVER_OFFSET := Vector2(30, -42)
const CAMERA_PADDING := Vector2(220, 140)
const CAMERA_LERP_SPEED := 8.0

var board_nodes: Array = []
var node_positions := {}
var buttons := {}
var selectable_nodes: Array[int] = []
var current_position := -1
var node_markers := {}
var locked_nodes: Array[int] = []

var traveler: ColorRect
var traveler_node_id := -1
var is_traveling := false
var idle_tween: Tween
var observer_traveler: ColorRect
var observer_node_id := -1
var observer_idle_tween: Tween
var observer_focus_active := false
var board_bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
var camera_offset := Vector2.ZERO
var camera_target := Vector2.ZERO
var pulse_time := 0.0

var _traveler_world_position := Vector2.ZERO
var traveler_world_position: Vector2:
	get:
		return _traveler_world_position
	set(value):
		_traveler_world_position = value
		_refresh_camera_target()
		_apply_camera_transform()
		queue_redraw()

var _observer_world_position := Vector2.ZERO
var observer_world_position: Vector2:
	get:
		return _observer_world_position
	set(value):
		_observer_world_position = value
		_refresh_camera_target()
		_apply_camera_transform()
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_ensure_traveler()
	_ensure_observer_traveler()
	set_process(true)

func _process(delta: float) -> void:
	pulse_time += delta
	if camera_offset.distance_to(camera_target) <= 0.5:
		if camera_offset != camera_target:
			camera_offset = camera_target
			_apply_camera_transform()
	else:
		camera_offset = camera_offset.lerp(camera_target, clampf(delta * CAMERA_LERP_SPEED, 0.0, 1.0))
		_apply_camera_transform()
	_apply_dynamic_node_fx()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_camera_target(true)

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

func _ensure_observer_traveler() -> void:
	if observer_traveler != null:
		return

	observer_traveler = ColorRect.new()
	observer_traveler.name = "ObserverTraveler"
	observer_traveler.size = Vector2(20, 20)
	observer_traveler.color = Color("fb7185")
	observer_traveler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	observer_traveler.z_index = 31
	observer_traveler.visible = false
	add_child(observer_traveler)

func setup(nodes: Array) -> void:
	board_nodes = nodes
	node_positions.clear()

	for child in get_children():
		if child == traveler or child == observer_traveler:
			continue
		child.queue_free()

	buttons.clear()

	for node in board_nodes:
		var button := Button.new()
		var node_id := int(node.get("id", -1))
		var world_position := Vector2(node.get("position", Vector2.ZERO))
		node_positions[node_id] = world_position
		button.name = "Node_%d" % node_id
		button.size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_node_pressed.bind(node_id))
		add_child(button)
		buttons[node_id] = button

	_rebuild_board_bounds()
	if traveler_node_id != -1 and buttons.has(traveler_node_id):
		_snap_traveler_to(traveler_node_id)
	if observer_node_id != -1 and buttons.has(observer_node_id):
		_snap_observer_to(observer_node_id)
	_refresh_camera_target(true)
	queue_redraw()

func set_current_node(node_id: int, immediate := true) -> void:
	traveler_node_id = node_id
	current_position = node_id

	if immediate:
		_snap_traveler_to(node_id)
		_refresh_camera_target(true)
		_play_idle()
	else:
		_refresh_camera_target()

	queue_redraw()

func set_observer_node(node_id: int, immediate := true) -> void:
	if node_id < 0:
		hide_observer()
		return

	observer_focus_active = true
	observer_node_id = node_id
	_ensure_observer_traveler()

	if immediate:
		_snap_observer_to(node_id)
		_refresh_camera_target(true)
		_play_observer_idle()
	else:
		_refresh_camera_target()

	queue_redraw()

func hide_observer() -> void:
	observer_focus_active = false
	if observer_idle_tween != null:
		observer_idle_tween.kill()
		observer_idle_tween = null
	if observer_traveler != null:
		observer_traveler.visible = false
	_refresh_camera_target()
	_apply_camera_transform()
	queue_redraw()

func play_observer_travel(path: Array[int]) -> void:
	if path.is_empty():
		return

	_ensure_observer_traveler()
	observer_focus_active = true
	observer_traveler.visible = true

	if observer_idle_tween != null:
		observer_idle_tween.kill()
		observer_idle_tween = null

	if observer_node_id == -1:
		observer_node_id = int(path[0])
		_snap_observer_to(observer_node_id)

	if GameState.should_skip_animations():
		var final_id := int(path[path.size() - 1])
		observer_world_position = _observer_world_top_left(final_id)
		observer_node_id = final_id
		_refresh_camera_target(true)
		_play_observer_idle()
		observer_travel_finished.emit(observer_node_id)
		return

	for i in range(1, path.size()):
		var next_id := int(path[i])
		var to_pos := _observer_world_top_left(next_id)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "observer_world_position", to_pos, 0.24) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(observer_traveler, "scale", Vector2(1.12, 0.90), 0.12)
		tween.chain().tween_property(observer_traveler, "scale", Vector2.ONE, 0.12)

		await tween.finished
		observer_node_id = next_id
		_refresh_camera_target()
		queue_redraw()

	_play_observer_arrival_punch()
	observer_travel_finished.emit(observer_node_id)

func _play_observer_arrival_punch() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(observer_traveler, "scale", Vector2(1.18, 0.88), 0.08)
	tween.chain().tween_property(observer_traveler, "scale", Vector2.ONE, 0.10)
	await tween.finished
	_play_observer_idle()

func _play_observer_idle() -> void:
	if observer_traveler == null:
		return
	if observer_idle_tween != null:
		observer_idle_tween.kill()

	observer_idle_tween = create_tween()
	observer_idle_tween.set_loops()
	observer_idle_tween.tween_property(observer_traveler, "scale", Vector2(1.05, 0.95), 0.45)
	observer_idle_tween.tween_property(observer_traveler, "scale", Vector2.ONE, 0.45)

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

	if GameState.should_skip_animations():
		var final_id := int(path[path.size() - 1])
		traveler_world_position = _traveler_world_top_left(final_id)
		traveler_node_id = final_id
		current_position = final_id
		is_traveling = false
		_refresh_camera_target(true)
		_play_idle()
		travel_finished.emit(traveler_node_id)
		return

	for i in range(1, path.size()):
		var next_id := int(path[i])
		var to_pos := _traveler_world_top_left(next_id)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "traveler_world_position", to_pos, 0.24) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(traveler, "scale", Vector2(1.10, 0.92), 0.12)
		tween.chain().tween_property(traveler, "scale", Vector2.ONE, 0.12)

		await tween.finished
		traveler_node_id = next_id
		current_position = next_id
		_refresh_camera_target()
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
	_traveler_world_position = _traveler_world_top_left(node_id)
	traveler.scale = Vector2.ONE
	_apply_camera_transform()

func _snap_observer_to(node_id: int) -> void:
	if observer_traveler == null or not buttons.has(node_id):
		return
	observer_traveler.visible = true
	_observer_world_position = _observer_world_top_left(node_id)
	observer_traveler.scale = Vector2.ONE
	_apply_camera_transform()

func _button_world_center(node_id: int) -> Vector2:
	var world_position := Vector2(node_positions.get(node_id, Vector2.ZERO))
	return world_position + BUTTON_SIZE * 0.5

func _traveler_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - traveler.size * 0.5 + TRAVELER_OFFSET

func _observer_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - observer_traveler.size * 0.5 + OBSERVER_OFFSET

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

		if locked_nodes.has(node_id) and not selectable_nodes.has(node_id):
			header = "%s [锁]" % String(node.get("name", ""))

		var footer := marker_text
		if current_position == node_id:
			if not footer.is_empty():
				footer += " · "
			footer += "你在这里"

		button.text = "%s\n%s" % [header, footer]
		button.tooltip_text = _build_tooltip(node_id, node)

		var is_selectable := selectable_nodes.has(node_id)
		button.disabled = not is_selectable
		button.modulate = Color.WHITE
		_apply_node_button_theme(button, type_id, is_selectable, current_position == node_id, locked_nodes.has(node_id) and not is_selectable)

	_refresh_camera_target()
	_apply_dynamic_node_fx()
	queue_redraw()

func _build_tooltip(node_id: int, node: Dictionary) -> String:
	var text := "%s\n%s" % [String(node.get("name", "")), String(node.get("description", ""))]
	if node.has("focus"):
		text += "\n焦点：%s" % String(node.get("focus", ""))
	if node.has("reward_hint"):
		text += "\n预估收益：%s" % String(node.get("reward_hint", ""))
	if node_markers.has(node_id):
		text += "\n状态：%s" % String(node_markers[node_id])
	return text

func _draw() -> void:
	var drawn_edges := {}
	for node in board_nodes:
		var start_id := int(node.get("id", -1))
		for edge in node.get("edges", []):
			var end_id := int(edge)
			var edge_key := "%d_%d" % [mini(start_id, end_id), maxi(start_id, end_id)]
			if drawn_edges.has(edge_key):
				continue
			drawn_edges[edge_key] = true

			var start_pos := _button_world_center(start_id) - camera_offset
			var end_pos := _button_world_center(end_id) - camera_offset
			draw_line(start_pos, end_pos, Color(0.22, 0.31, 0.42, 0.95), 3.0, true)

	for node_id in selectable_nodes:
		var world_position := Vector2(node_positions.get(node_id, Vector2.ZERO))
		draw_rect(
			Rect2(world_position - camera_offset - Vector2(4, 4), BUTTON_SIZE + Vector2(8, 8)),
			Color(0.96, 0.72, 0.26, 0.92),
			false,
			2.0
		)

func _on_node_pressed(node_id: int) -> void:
	if is_traveling:
		return
	if selectable_nodes.has(node_id):
		node_chosen.emit(node_id)

func _rebuild_board_bounds() -> void:
	if board_nodes.is_empty():
		board_bounds = Rect2(Vector2.ZERO, size)
		return
	var first_position := Vector2(board_nodes[0].get("position", Vector2.ZERO))
	var min_point := first_position
	var max_point := first_position + BUTTON_SIZE
	for node in board_nodes:
		var world_position := Vector2(node.get("position", Vector2.ZERO))
		min_point.x = minf(min_point.x, world_position.x)
		min_point.y = minf(min_point.y, world_position.y + TRAVELER_OFFSET.y)
		max_point.x = maxf(max_point.x, world_position.x + BUTTON_SIZE.x)
		max_point.y = maxf(max_point.y, world_position.y + BUTTON_SIZE.y)
	board_bounds = Rect2(min_point, max_point - min_point)

func _refresh_camera_target(immediate := false) -> void:
	camera_target = _camera_target_for_focus(_current_focus_world_point())
	if immediate:
		camera_offset = camera_target
		_apply_camera_transform()

func _current_focus_world_point() -> Vector2:
	if observer_focus_active and observer_traveler != null and observer_traveler.visible:
		return observer_world_position + observer_traveler.size * 0.5
	if traveler != null and traveler.visible:
		return traveler_world_position + traveler.size * 0.5
	if current_position != -1:
		return _button_world_center(current_position)
	if not board_nodes.is_empty():
		return _button_world_center(int(board_nodes[0].get("id", -1)))
	return Vector2.ZERO

func _camera_target_for_focus(focus_world_point: Vector2) -> Vector2:
	var viewport_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var desired := focus_world_point - viewport_size * 0.5
	var max_corner := board_bounds.position + board_bounds.size + CAMERA_PADDING
	var max_offset := Vector2(
		maxf(0.0, max_corner.x - viewport_size.x),
		maxf(0.0, max_corner.y - viewport_size.y)
	)
	return Vector2(
		clampf(desired.x, 0.0, max_offset.x),
		clampf(desired.y, 0.0, max_offset.y)
	)

func _apply_camera_transform() -> void:
	for node_id in buttons.keys():
		var button: Button = buttons.get(node_id)
		if button == null:
			continue
		button.position = Vector2(node_positions.get(node_id, Vector2.ZERO)) - camera_offset
	if traveler != null and traveler.visible:
		traveler.position = traveler_world_position - camera_offset
	if observer_traveler != null and observer_traveler.visible:
		observer_traveler.position = observer_world_position - camera_offset
	queue_redraw()

func _apply_dynamic_node_fx() -> void:
	for node_id in buttons.keys():
		var button: Button = buttons.get(node_id)
		if button == null:
			continue
		var pulse := 1.0 if GameState.prefers_reduced_motion() else 0.5 + 0.5 * sin(pulse_time * 4.2 + float(node_id) * 0.35)
		if current_position == int(node_id):
			button.modulate = Color(1.0, lerpf(0.88, 0.96, pulse), lerpf(0.68, 0.82, pulse))
			continue
		var is_selectable := selectable_nodes.has(int(node_id))
		if is_selectable:
			button.modulate = Color(
				1.0,
				lerpf(0.92, 1.0, pulse),
				lerpf(0.82, 0.96, pulse)
			)
		else:
			button.modulate = Color(0.82, 0.82, 0.86)

func _apply_node_button_theme(button: Button, type_id: String, is_selectable: bool, is_current: bool, is_locked: bool) -> void:
	var accent: Color = TYPE_COLORS.get(type_id, Color(0.70, 0.78, 0.90, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.16, 0.24, 0.96)
	normal.border_color = accent.darkened(0.15)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	if is_current:
		normal.bg_color = Color(0.24, 0.19, 0.10, 0.98)
		normal.border_color = Color(1.0, 0.84, 0.42, 1.0)
	elif is_selectable:
		normal.bg_color = Color(0.14, 0.20, 0.30, 0.98)
		normal.border_color = accent.lightened(0.25)
	elif is_locked:
		normal.bg_color = Color(0.10, 0.11, 0.14, 0.88)
		normal.border_color = Color(0.33, 0.36, 0.42, 0.88)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(normal.bg_color.r + 0.03, normal.bg_color.g + 0.03, normal.bg_color.b + 0.03, normal.bg_color.a)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(normal.bg_color.r * 0.92, normal.bg_color.g * 0.92, normal.bg_color.b * 0.92, normal.bg_color.a)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	if not is_current:
		disabled.bg_color = Color(0.10, 0.11, 0.15, 0.68)
		disabled.border_color = Color(0.29, 0.33, 0.40, 0.70)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.66, 0.70, 0.78, 0.88))

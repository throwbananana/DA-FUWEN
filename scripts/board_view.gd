class_name BoardView
extends Control

const BoardNodeButtonScene := preload("res://scenes/ui/board/BoardNodeButton.tscn")

signal node_chosen(node_id: int)
signal travel_finished(node_id: int)
signal observer_travel_finished(node_id: int)

const TYPE_SHORT := {
	"camp": "营",
	"bulletin": "告",
	"minigame": "游",
	"infirmary": "疗",
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
	"bulletin": Color("f59e0b"),
	"minigame": Color("fb923c"),
	"infirmary": Color("34d399"),
	"empty": Color("94a3b8"),
	"environment": Color("93c5fd"),
	"event": Color("f9a8d4"),
	"habitat": Color("86efac"),
	"settlement": Color("fcd34d"),
	"dojo": Color("fb7185"),
	"anomaly": Color("c084fc"),
}

const BASE_BUTTON_SIZE := Vector2(118, 72)
const MIN_BUTTON_SCALE := 0.72
const COMPACT_BUTTON_SCALE := 0.82
const NARROW_BUTTON_SCALE := 0.90
const BASE_TRAVELER_OFFSET := Vector2(0, -42)
const BASE_OBSERVER_OFFSET := Vector2(30, -42)
const BASE_CAMERA_PADDING := Vector2(220, 140)
const CAMERA_LERP_SPEED := 8.0

var board_nodes: Array = []
var node_positions := {}
var buttons := {}
var selectable_nodes: Array[int] = []
var current_position := -1
var node_markers := {}
var locked_nodes: Array[int] = []
var controller_navigation_enabled := false
var controller_cursor_node_id := -1
var button_size := BASE_BUTTON_SIZE
var button_scale := 1.0
var camera_padding := BASE_CAMERA_PADDING

@onready var traveler: ColorRect = $Traveler
var traveler_node_id := -1
var is_traveling := false
var idle_tween: Tween
@onready var observer_traveler: ColorRect = $ObserverTraveler
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
	traveler.z_index = 30
	observer_traveler.z_index = 31
	_refresh_responsive_metrics()
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
		_refresh_responsive_metrics()
		_refresh_camera_target(true)

func _refresh_responsive_metrics() -> void:
	var viewport_size := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	if viewport_size.x < 960.0 or viewport_size.y < 540.0:
		button_scale = MIN_BUTTON_SCALE
	elif viewport_size.x < 1200.0 or viewport_size.y < 660.0:
		button_scale = COMPACT_BUTTON_SCALE
	elif viewport_size.x < 1500.0:
		button_scale = NARROW_BUTTON_SCALE
	else:
		button_scale = 1.0

	button_size = BASE_BUTTON_SIZE * button_scale
	if button_scale <= MIN_BUTTON_SCALE:
		camera_padding = BASE_CAMERA_PADDING * 0.78
	elif button_scale < 1.0:
		camera_padding = BASE_CAMERA_PADDING * 0.88
	else:
		camera_padding = BASE_CAMERA_PADDING

	for raw_button in buttons.values():
		var button := raw_button as Button
		_apply_button_metrics(button)

	if traveler != null:
		traveler.size = Vector2(24, 24) * clampf(0.88 + button_scale * 0.12, 0.92, 1.0)
	if observer_traveler != null:
		observer_traveler.size = Vector2(20, 20) * clampf(0.88 + button_scale * 0.12, 0.92, 1.0)

	_rebuild_board_bounds()
	if traveler_node_id != -1 and buttons.has(traveler_node_id) and not is_traveling:
		_snap_traveler_to(traveler_node_id)
	if observer_traveler != null and observer_traveler.visible and observer_node_id != -1 and buttons.has(observer_node_id):
		_snap_observer_to(observer_node_id)

func _apply_button_metrics(button: Button) -> void:
	if button == null:
		return
	button.call("apply_metrics", button_size, button_scale)

func setup(nodes: Array) -> void:
	board_nodes = nodes
	node_positions.clear()

	for child in get_children():
		if child == traveler or child == observer_traveler:
			continue
		child.queue_free()

	buttons.clear()
	_refresh_responsive_metrics()

	for node in board_nodes:
		var button := BoardNodeButtonScene.instantiate() as Button
		if button == null:
			continue
		var node_id := int(node.get("id", -1))
		var world_position := Vector2(node.get("position", Vector2.ZERO))
		node_positions[node_id] = world_position
		button.name = "Node_%d" % node_id
		add_child(button)
		_apply_button_metrics(button)
		button.pressed.connect(_on_node_pressed.bind(node_id))
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

func _traveler_offset() -> Vector2:
	return BASE_TRAVELER_OFFSET * button_scale

func _observer_offset() -> Vector2:
	return BASE_OBSERVER_OFFSET * button_scale

func _button_world_center(node_id: int) -> Vector2:
	var world_position := Vector2(node_positions.get(node_id, Vector2.ZERO))
	return world_position + button_size * 0.5

func _traveler_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - traveler.size * 0.5 + _traveler_offset()

func _observer_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - observer_traveler.size * 0.5 + _observer_offset()

func refresh_view(current_pos: int, selectable: Array[int], markers: Dictionary, locked: Array[int]) -> void:
	current_position = current_pos
	selectable_nodes = selectable.duplicate()
	node_markers = markers.duplicate(true)
	locked_nodes = locked.duplicate()

	for node in board_nodes:
		var node_id := int(node.get("id", -1))
		var button := buttons.get(node_id) as Button
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

		button.call("set_content", header, footer, _build_tooltip(node_id, node))

		var is_selectable := selectable_nodes.has(node_id)
		button.disabled = not is_selectable
		button.modulate = Color.WHITE
		button.call(
			"apply_visual_state",
			accent_for_type(type_id),
			is_selectable,
			current_position == node_id,
			locked_nodes.has(node_id) and not is_selectable
		)

	if controller_navigation_enabled:
		_sync_controller_cursor()
	else:
		controller_cursor_node_id = -1
	_refresh_camera_target()
	_apply_dynamic_node_fx()
	queue_redraw()

func set_controller_navigation_enabled(enabled: bool) -> void:
	controller_navigation_enabled = enabled
	if controller_navigation_enabled:
		_sync_controller_cursor()
	else:
		controller_cursor_node_id = -1
	_refresh_camera_target(true)
	_apply_dynamic_node_fx()
	queue_redraw()

func move_controller_cursor(direction: Vector2i) -> bool:
	if not controller_navigation_enabled or selectable_nodes.is_empty():
		return false
	_sync_controller_cursor()
	if controller_cursor_node_id == -1:
		return false
	var from_position := _button_world_center(controller_cursor_node_id)
	var axis := Vector2(direction).normalized()
	var side_axis := Vector2(-axis.y, axis.x)
	var best_node_id := controller_cursor_node_id
	var best_score := INF
	for node_id in selectable_nodes:
		if int(node_id) == controller_cursor_node_id:
			continue
		var delta := _button_world_center(int(node_id)) - from_position
		var forward := axis.dot(delta)
		if forward <= 8.0:
			continue
		var lateral := absf(side_axis.dot(delta))
		var score := delta.length() + lateral * 2.4
		if score < best_score:
			best_score = score
			best_node_id = int(node_id)
	if best_node_id == controller_cursor_node_id:
		for node_id in selectable_nodes:
			if int(node_id) == controller_cursor_node_id:
				continue
			var fallback_score := (_button_world_center(int(node_id)) - from_position).length()
			if fallback_score < best_score:
				best_score = fallback_score
				best_node_id = int(node_id)
	if best_node_id == controller_cursor_node_id:
		return false
	controller_cursor_node_id = best_node_id
	_refresh_camera_target()
	_apply_dynamic_node_fx()
	queue_redraw()
	return true

func activate_controller_cursor() -> void:
	if not controller_navigation_enabled or is_traveling:
		return
	if selectable_nodes.has(controller_cursor_node_id):
		node_chosen.emit(controller_cursor_node_id)

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
			Rect2(world_position - camera_offset - Vector2(4, 4), button_size + Vector2(8, 8)),
			Color(0.96, 0.72, 0.26, 0.92),
			false,
			2.0
		)
	if controller_navigation_enabled and controller_cursor_node_id != -1 and buttons.has(controller_cursor_node_id):
		var cursor_position := Vector2(node_positions.get(controller_cursor_node_id, Vector2.ZERO))
		draw_rect(
			Rect2(cursor_position - camera_offset - Vector2(9, 9), button_size + Vector2(18, 18)),
			Color(0.92, 0.98, 1.0, 0.98),
			false,
			3.0
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
	var max_point := first_position + button_size
	for node in board_nodes:
		var world_position := Vector2(node.get("position", Vector2.ZERO))
		min_point.x = minf(min_point.x, world_position.x)
		min_point.y = minf(min_point.y, world_position.y + _traveler_offset().y)
		max_point.x = maxf(max_point.x, world_position.x + button_size.x)
		max_point.y = maxf(max_point.y, world_position.y + button_size.y)
	board_bounds = Rect2(min_point, max_point - min_point)

func _refresh_camera_target(immediate := false) -> void:
	camera_target = _camera_target_for_focus(_current_focus_world_point())
	if immediate:
		camera_offset = camera_target
		_apply_camera_transform()

func _current_focus_world_point() -> Vector2:
	if controller_navigation_enabled and controller_cursor_node_id != -1 and buttons.has(controller_cursor_node_id):
		return _button_world_center(controller_cursor_node_id)
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
	var max_corner := board_bounds.position + board_bounds.size + camera_padding
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
		var button := buttons.get(node_id) as Button
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
		if controller_navigation_enabled and int(node_id) == controller_cursor_node_id:
			button.modulate = Color(0.92, lerpf(0.94, 1.0, pulse), 1.0)
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

func accent_for_type(type_id: String) -> Color:
	return TYPE_COLORS.get(type_id, Color(0.70, 0.78, 0.90, 1.0))

func _sync_controller_cursor() -> void:
	if selectable_nodes.is_empty():
		controller_cursor_node_id = -1
		return
	if selectable_nodes.has(controller_cursor_node_id):
		return
	if selectable_nodes.has(current_position):
		controller_cursor_node_id = current_position
		return
	controller_cursor_node_id = int(selectable_nodes[0])

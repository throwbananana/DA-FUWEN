class_name BoardRoot
extends Control

const BoardFactoryScript := preload("res://scripts/board/board_factory.gd")
const WorldActorFactoryScript := preload("res://scripts/world/world_actor_factory.gd")

signal node_chosen(node_id: int)
signal travel_finished(node_id: int)
signal observer_travel_finished(node_id: int)

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
const TRAVEL_STEP_DURATION := 0.24
const TRAVEL_CURVE_MIN_HEIGHT := 18.0
const TRAVEL_CURVE_MAX_HEIGHT := 42.0

var board_factory := BoardFactoryScript.new()
var world_actor_factory := WorldActorFactoryScript.new()
var board_nodes: Array = []
var node_positions := {}
var buttons := {}
var npc_presence_entries: Array = []
var npc_actors := {}
var npc_world_positions := {}
var selectable_nodes: Array[int] = []
var current_position := -1
var node_markers := {}
var locked_nodes: Array[int] = []
var controller_navigation_enabled := false
var controller_cursor_node_id := -1
var button_size := BASE_BUTTON_SIZE
var button_scale := 1.0
var camera_padding := BASE_CAMERA_PADDING
var traveler_node_id := -1
var is_traveling := false
var observer_node_id := -1
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

@onready var node_layer: Control = $NodeLayer
@onready var npc_layer: Control = $NpcLayer
@onready var traveler: Control = $TravelerLayer/Traveler
@onready var observer_traveler: Control = $TravelerLayer/ObserverTraveler

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	npc_layer.z_index = 24
	traveler.z_index = 30
	observer_traveler.z_index = 31
	traveler.call("configure_actor", Color("fde68a"), Vector2(24, 24))
	observer_traveler.call("configure_actor", Color("fb7185"), Vector2(20, 20))
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
	if not is_node_ready():
		return
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
	for raw_actor in npc_actors.values():
		var actor := raw_actor as Control
		if actor != null:
			actor.call("apply_scale_factor", button_scale)
	if traveler != null:
		traveler.call("apply_scale_factor", button_scale)
	if observer_traveler != null:
		observer_traveler.call("apply_scale_factor", button_scale)
	_refresh_npc_actor_world_positions()
	_rebuild_board_bounds()
	if traveler_node_id != -1 and buttons.has(traveler_node_id) and not is_traveling:
		_snap_traveler_to(traveler_node_id)
	if observer_traveler.visible and observer_node_id != -1 and buttons.has(observer_node_id):
		_snap_observer_to(observer_node_id)

func _apply_button_metrics(button: Button) -> void:
	if button != null:
		button.call("apply_metrics", button_size, button_scale)

func setup(nodes: Array) -> void:
	board_nodes = nodes
	node_positions.clear()
	for child in node_layer.get_children():
		child.queue_free()
	buttons.clear()
	_refresh_responsive_metrics()
	for node in board_nodes:
		var node_id := int(node.get("id", -1))
		node_positions[node_id] = Vector2(node.get("position", Vector2.ZERO))
		var button := board_factory.create_node_actor(node, node_layer)
		if button == null:
			continue
		_apply_button_metrics(button)
		button.pressed.connect(_on_node_pressed.bind(node_id))
		buttons[node_id] = button
	_refresh_npc_actor_world_positions()
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
		traveler.call("play_idle")
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
		observer_traveler.call("play_idle")
	else:
		_refresh_camera_target()
	queue_redraw()

func hide_observer() -> void:
	observer_focus_active = false
	observer_traveler.call("stop_idle", true)
	observer_traveler.visible = false
	_refresh_camera_target()
	_apply_camera_transform()
	queue_redraw()

func play_observer_travel(path: Array[int]) -> void:
	if path.is_empty():
		return
	observer_focus_active = true
	observer_traveler.call("stop_idle", true)
	observer_traveler.visible = true
	if observer_node_id == -1:
		observer_node_id = int(path[0])
		_snap_observer_to(observer_node_id)
	if GameState.should_skip_animations():
		var final_id := int(path[path.size() - 1])
		observer_world_position = _observer_world_top_left(final_id)
		observer_node_id = final_id
		_refresh_camera_target(true)
		observer_traveler.call("play_idle")
		observer_travel_finished.emit(observer_node_id)
		return
	for i in range(1, path.size()):
		var next_id := int(path[i])
		var start_position := observer_world_position
		var end_position := _observer_world_top_left(next_id)
		var control_position := _travel_curve_control_point(start_position, end_position)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_method(_set_observer_curve_position.bind(start_position, control_position, end_position), 0.0, 1.0, TRAVEL_STEP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(observer_traveler, "scale", Vector2(1.12, 0.90), 0.12)
		tween.chain().tween_property(observer_traveler, "scale", Vector2.ONE, 0.12)
		await tween.finished
		observer_world_position = end_position
		observer_node_id = next_id
		_refresh_camera_target()
		queue_redraw()
	await _play_observer_arrival_punch()
	observer_travel_finished.emit(observer_node_id)

func _play_observer_arrival_punch() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(observer_traveler, "scale", Vector2(1.18, 0.88), 0.08)
	tween.chain().tween_property(observer_traveler, "scale", Vector2.ONE, 0.10)
	await tween.finished
	observer_traveler.call("play_idle")

func play_travel(path: Array[int]) -> void:
	if path.is_empty():
		return
	traveler.call("stop_idle", true)
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
		traveler.call("play_idle")
		travel_finished.emit(traveler_node_id)
		return
	for i in range(1, path.size()):
		var next_id := int(path[i])
		var start_position := traveler_world_position
		var end_position := _traveler_world_top_left(next_id)
		var control_position := _travel_curve_control_point(start_position, end_position)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_method(_set_traveler_curve_position.bind(start_position, control_position, end_position), 0.0, 1.0, TRAVEL_STEP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(traveler, "scale", Vector2(1.10, 0.92), 0.12)
		tween.chain().tween_property(traveler, "scale", Vector2.ONE, 0.12)
		await tween.finished
		traveler_world_position = end_position
		traveler_node_id = next_id
		current_position = next_id
		_refresh_camera_target()
		queue_redraw()
	is_traveling = false
	await _play_arrival_punch()
	travel_finished.emit(traveler_node_id)

func _play_arrival_punch() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(traveler, "scale", Vector2(1.18, 0.88), 0.08)
	tween.chain().tween_property(traveler, "scale", Vector2.ONE, 0.10)
	await tween.finished
	traveler.call("play_idle")

func _snap_traveler_to(node_id: int) -> void:
	if not buttons.has(node_id):
		return
	traveler.visible = true
	_traveler_world_position = _traveler_world_top_left(node_id)
	traveler.call("reset_pose")
	_apply_camera_transform()

func _snap_observer_to(node_id: int) -> void:
	if not buttons.has(node_id):
		return
	observer_traveler.visible = true
	_observer_world_position = _observer_world_top_left(node_id)
	observer_traveler.call("reset_pose")
	_apply_camera_transform()

func _traveler_offset() -> Vector2:
	return BASE_TRAVELER_OFFSET * button_scale

func _observer_offset() -> Vector2:
	return BASE_OBSERVER_OFFSET * button_scale

func _button_world_center(node_id: int) -> Vector2:
	return Vector2(node_positions.get(node_id, Vector2.ZERO)) + button_size * 0.5

func _traveler_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - traveler.size * 0.5 + _traveler_offset()

func _observer_world_top_left(node_id: int) -> Vector2:
	return _button_world_center(node_id) - observer_traveler.size * 0.5 + _observer_offset()

func _travel_curve_control_point(start_position: Vector2, end_position: Vector2) -> Vector2:
	var delta := end_position - start_position
	var distance := delta.length()
	if distance <= 0.001:
		return start_position
	var upward := Vector2(0, -1)
	var perpendicular := Vector2(-delta.y, delta.x).normalized()
	if perpendicular.y > 0.0:
		perpendicular *= -1.0
	var arc_direction := (upward * 0.82 + perpendicular * 0.58).normalized()
	var arc_height := clampf(distance * 0.24, TRAVEL_CURVE_MIN_HEIGHT * button_scale, TRAVEL_CURVE_MAX_HEIGHT * button_scale)
	return start_position.lerp(end_position, 0.5) + arc_direction * arc_height

func _quadratic_curve_point(start_position: Vector2, control_position: Vector2, end_position: Vector2, progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * start_position + 2.0 * inverse * t * control_position + t * t * end_position

func _set_traveler_curve_position(progress: float, start_position: Vector2, control_position: Vector2, end_position: Vector2) -> void:
	traveler_world_position = _quadratic_curve_point(start_position, control_position, end_position, progress)

func _set_observer_curve_position(progress: float, start_position: Vector2, control_position: Vector2, end_position: Vector2) -> void:
	observer_world_position = _quadratic_curve_point(start_position, control_position, end_position, progress)

func set_npc_presence(entries: Array) -> void:
	var normalized_entries := _normalize_npc_entries(entries)
	var desired_ids := {}
	for entry in normalized_entries:
		var npc_id := String(entry.get("npc_id", ""))
		if npc_id.is_empty():
			continue
		desired_ids[npc_id] = true
		var definition: Dictionary = Dictionary(entry.get("definition", {})).duplicate(true)
		var runtime_state: Dictionary = Dictionary(entry.get("runtime", {})).duplicate(true)
		var actor := npc_actors.get(npc_id) as Control
		var is_new_actor := false
		if actor == null:
			actor = world_actor_factory.create_npc_actor(npc_layer, definition, runtime_state)
			if actor == null:
				continue
			actor.call("apply_scale_factor", button_scale)
			npc_actors[npc_id] = actor
			is_new_actor = true
		else:
			actor.call("apply_definition", definition)
			actor.call("apply_runtime", runtime_state)
		if is_new_actor:
			actor.call("play_arrive")
		else:
			actor.call("play_idle")
	for npc_id in npc_actors.keys():
		if desired_ids.has(String(npc_id)):
			continue
		var stale_actor := npc_actors.get(npc_id) as Node
		if stale_actor != null:
			stale_actor.queue_free()
		npc_world_positions.erase(String(npc_id))
		npc_actors.erase(npc_id)
	npc_presence_entries = normalized_entries
	_refresh_npc_actor_world_positions()
	_apply_npc_highlights()
	_rebuild_board_bounds()
	_refresh_camera_target()
	_apply_camera_transform()

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
		var is_selectable := selectable_nodes.has(node_id)
		var is_locked := locked_nodes.has(node_id) and not is_selectable
		button.disabled = not is_selectable
		button.call("apply_runtime_state", {
			"marker_text": marker_text,
			"tooltip_text": _build_tooltip(node_id, node),
			"is_selectable": is_selectable,
			"is_current": current_position == node_id,
			"is_locked": is_locked,
			"is_danger": _is_danger_node(node_id, node, marker_text),
			"accent_color": accent_for_type(type_id),
		})
		button.modulate = Color.WHITE
	if controller_navigation_enabled:
		_sync_controller_cursor()
	else:
		controller_cursor_node_id = -1
	_apply_npc_highlights()
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
	if controller_navigation_enabled and not is_traveling and selectable_nodes.has(controller_cursor_node_id):
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
			draw_line(_button_world_center(start_id) - camera_offset, _button_world_center(end_id) - camera_offset, Color(0.22, 0.31, 0.42, 0.95), 3.0, true)
	if controller_navigation_enabled and controller_cursor_node_id != -1 and buttons.has(controller_cursor_node_id):
		var cursor_position := Vector2(node_positions.get(controller_cursor_node_id, Vector2.ZERO))
		draw_rect(Rect2(cursor_position - camera_offset - Vector2(9, 9), button_size + Vector2(18, 18)), Color(0.92, 0.98, 1.0, 0.98), false, 3.0)

func _on_node_pressed(node_id: int) -> void:
	if not is_traveling and selectable_nodes.has(node_id):
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
	for npc_id in npc_world_positions.keys():
		var actor := npc_actors.get(String(npc_id)) as Control
		if actor == null:
			continue
		var actor_position := Vector2(npc_world_positions.get(String(npc_id), Vector2.ZERO))
		var actor_size := actor.size if actor.size != Vector2.ZERO else actor.custom_minimum_size
		min_point.x = minf(min_point.x, actor_position.x)
		min_point.y = minf(min_point.y, actor_position.y)
		max_point.x = maxf(max_point.x, actor_position.x + actor_size.x)
		max_point.y = maxf(max_point.y, actor_position.y + actor_size.y)
	board_bounds = Rect2(min_point, max_point - min_point)

func _refresh_camera_target(immediate := false) -> void:
	camera_target = _camera_target_for_focus(_current_focus_world_point())
	if immediate:
		camera_offset = camera_target
		_apply_camera_transform()

func _current_focus_world_point() -> Vector2:
	if controller_navigation_enabled and controller_cursor_node_id != -1 and buttons.has(controller_cursor_node_id):
		return _button_world_center(controller_cursor_node_id)
	if observer_focus_active and observer_traveler.visible:
		return observer_world_position + observer_traveler.size * 0.5
	if traveler.visible:
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
	var max_offset := Vector2(maxf(0.0, max_corner.x - viewport_size.x), maxf(0.0, max_corner.y - viewport_size.y))
	return Vector2(clampf(desired.x, 0.0, max_offset.x), clampf(desired.y, 0.0, max_offset.y))

func _apply_camera_transform() -> void:
	for node_id in buttons.keys():
		var button := buttons.get(node_id) as Button
		if button != null:
			button.position = Vector2(node_positions.get(node_id, Vector2.ZERO)) - camera_offset
	for npc_id in npc_world_positions.keys():
		var actor := npc_actors.get(String(npc_id)) as Control
		if actor != null:
			actor.position = Vector2(npc_world_positions.get(String(npc_id), Vector2.ZERO)) - camera_offset
	if traveler.visible:
		traveler.position = traveler_world_position - camera_offset
	if observer_traveler.visible:
		observer_traveler.position = observer_world_position - camera_offset
	queue_redraw()

func _apply_dynamic_node_fx() -> void:
	for node_id in buttons.keys():
		var button := buttons.get(node_id) as Button
		if button == null:
			continue
		var pulse := 1.0 if GameState.prefers_reduced_motion() else 0.5 + 0.5 * sin(pulse_time * 4.2 + float(node_id) * 0.35)
		if current_position == int(node_id):
			button.call("apply_highlight_fx", "current", pulse)
		elif controller_navigation_enabled and int(node_id) == controller_cursor_node_id:
			button.call("apply_highlight_fx", "cursor", pulse)
		elif selectable_nodes.has(int(node_id)):
			button.call("apply_highlight_fx", "selectable", pulse)
		else:
			button.call("apply_highlight_fx", "idle", pulse)

func accent_for_type(type_id: String) -> Color:
	return TYPE_COLORS.get(type_id, Color(0.70, 0.78, 0.90, 1.0))

func _sync_controller_cursor() -> void:
	if selectable_nodes.is_empty():
		controller_cursor_node_id = -1
	elif not selectable_nodes.has(controller_cursor_node_id):
		controller_cursor_node_id = current_position if selectable_nodes.has(current_position) else int(selectable_nodes[0])

func _is_danger_node(node_id: int, node: Dictionary, marker_text: String) -> bool:
	if String(node.get("type", "")) == "anomaly":
		return true
	var lower_marker := marker_text.to_lower()
	return lower_marker.contains("危险") or lower_marker.contains("高危") or lower_marker.contains("威胁") or lower_marker.contains("遭遇")

func _normalize_npc_entries(entries: Array) -> Array:
	var normalized: Array = []
	for raw_entry in entries:
		var entry := Dictionary(raw_entry).duplicate(true)
		var npc_id := String(entry.get("npc_id", ""))
		var node_id := int(entry.get("node_id", -1))
		if npc_id.is_empty() or node_id < 0 or not node_positions.has(node_id):
			continue
		entry["npc_id"] = npc_id
		entry["node_id"] = node_id
		entry["definition"] = Dictionary(entry.get("definition", {})).duplicate(true)
		entry["runtime"] = Dictionary(entry.get("runtime", {})).duplicate(true)
		normalized.append(entry)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var node_a := int(a.get("node_id", -1))
		var node_b := int(b.get("node_id", -1))
		if node_a == node_b:
			return String(a.get("npc_id", "")) < String(b.get("npc_id", ""))
		return node_a < node_b
	)
	return normalized

func _refresh_npc_actor_world_positions() -> void:
	npc_world_positions.clear()
	var grouped := {}
	for entry in npc_presence_entries:
		var node_id := int(Dictionary(entry).get("node_id", -1))
		if not grouped.has(node_id):
			grouped[node_id] = []
		grouped[node_id].append(entry)
	for node_id in grouped.keys():
		var group: Array = grouped[node_id]
		for index in range(group.size()):
			var entry: Dictionary = Dictionary(group[index])
			var npc_id := String(entry.get("npc_id", ""))
			var actor := npc_actors.get(npc_id) as Control
			if actor == null:
				continue
			var actor_size := actor.size if actor.size != Vector2.ZERO else actor.custom_minimum_size
			npc_world_positions[npc_id] = _npc_world_top_left(int(node_id), index, group.size(), actor_size)

func _npc_world_top_left(node_id: int, stack_index: int, stack_count: int, actor_size: Vector2) -> Vector2:
	var anchor := Vector2(node_positions.get(node_id, Vector2.ZERO))
	var stack_gap := maxf(4.0, 6.0 * button_scale)
	var total_height := actor_size.y * float(stack_count) + stack_gap * float(maxi(0, stack_count - 1))
	var start_y := anchor.y - actor_size.y * 0.45 - total_height * 0.5
	var start_x := anchor.x + button_size.x - actor_size.x * 0.30
	return Vector2(start_x, start_y + float(stack_index) * (actor_size.y + stack_gap))

func _apply_npc_highlights() -> void:
	for entry in npc_presence_entries:
		var data := Dictionary(entry)
		var npc_id := String(data.get("npc_id", ""))
		var actor := npc_actors.get(npc_id) as Control
		if actor == null:
			continue
		var runtime_state: Dictionary = Dictionary(data.get("runtime", {})).duplicate(true)
		var node_id := int(data.get("node_id", -1))
		runtime_state["highlighted"] = current_position == node_id or selectable_nodes.has(node_id)
		actor.call("apply_runtime", runtime_state)

extends Node

signal bindings_changed

const MAX_BINDING_SLOTS := 4
const AXIS_THRESHOLD := 0.55
const CAPTURE_IGNORE_DURATION_MS := 120

const ACTION_ORDER := [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right",
	"ui_accept",
	"ui_cancel",
	"game_roll",
	"game_support",
	"game_base",
	"game_menu",
]

const ACTION_DEFINITIONS := {
	"ui_up": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_up",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_W},
			{"type": "key", "physical_keycode": KEY_UP},
			{"type": "joy_button", "button_index": JOY_BUTTON_DPAD_UP},
			{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "direction": -1},
		],
	},
	"ui_down": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_down",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_S},
			{"type": "key", "physical_keycode": KEY_DOWN},
			{"type": "joy_button", "button_index": JOY_BUTTON_DPAD_DOWN},
			{"type": "joy_axis", "axis": JOY_AXIS_LEFT_Y, "direction": 1},
		],
	},
	"ui_left": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_left",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_A},
			{"type": "key", "physical_keycode": KEY_LEFT},
			{"type": "joy_button", "button_index": JOY_BUTTON_DPAD_LEFT},
			{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "direction": -1},
		],
	},
	"ui_right": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_right",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_D},
			{"type": "key", "physical_keycode": KEY_RIGHT},
			{"type": "joy_button", "button_index": JOY_BUTTON_DPAD_RIGHT},
			{"type": "joy_axis", "axis": JOY_AXIS_LEFT_X, "direction": 1},
		],
	},
	"ui_accept": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_accept",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_ENTER},
			{"type": "key", "physical_keycode": KEY_SPACE},
			{"type": "joy_button", "button_index": JOY_BUTTON_A},
		],
	},
	"ui_cancel": {
		"group_key": "input.group.navigation",
		"label_key": "input.action.ui_cancel",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_ESCAPE},
			{"type": "key", "physical_keycode": KEY_BACKSPACE},
			{"type": "joy_button", "button_index": JOY_BUTTON_B},
		],
	},
	"game_roll": {
		"group_key": "input.group.shortcuts",
		"label_key": "input.action.game_roll",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_R},
			{"type": "joy_button", "button_index": JOY_BUTTON_X},
		],
	},
	"game_support": {
		"group_key": "input.group.shortcuts",
		"label_key": "input.action.game_support",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_TAB},
			{"type": "joy_button", "button_index": JOY_BUTTON_Y},
		],
	},
	"game_base": {
		"group_key": "input.group.shortcuts",
		"label_key": "input.action.game_base",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_Q},
			{"type": "joy_button", "button_index": JOY_BUTTON_LEFT_SHOULDER},
		],
	},
	"game_menu": {
		"group_key": "input.group.shortcuts",
		"label_key": "input.action.game_menu",
		"defaults": [
			{"type": "key", "physical_keycode": KEY_F10},
			{"type": "key", "physical_keycode": KEY_M},
			{"type": "joy_button", "button_index": JOY_BUTTON_START},
		],
	},
}

const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

const JOY_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: {"negative": "Left Stick Left", "positive": "Left Stick Right"},
	JOY_AXIS_LEFT_Y: {"negative": "Left Stick Up", "positive": "Left Stick Down"},
	JOY_AXIS_RIGHT_X: {"negative": "Right Stick Left", "positive": "Right Stick Right"},
	JOY_AXIS_RIGHT_Y: {"negative": "Right Stick Up", "positive": "Right Stick Down"},
	JOY_AXIS_TRIGGER_LEFT: {"negative": "LT", "positive": "LT"},
	JOY_AXIS_TRIGGER_RIGHT: {"negative": "RT", "positive": "RT"},
}

func _ready() -> void:
	_apply_snapshot(_build_boot_snapshot())

func get_bindable_actions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for action_name in ACTION_ORDER:
		var definition: Dictionary = ACTION_DEFINITIONS.get(action_name, {})
		rows.append({
			"id": action_name,
			"group_key": String(definition.get("group_key", "")),
			"label_key": String(definition.get("label_key", action_name)),
		})
	return rows

func connected_joypad_count() -> int:
	return Input.get_connected_joypads().size()

func get_bindings_snapshot() -> Dictionary:
	var snapshot := {}
	for action_name in ACTION_ORDER:
		snapshot[action_name] = _serialize_current_action(action_name)
	return snapshot

func describe_binding_slot(action_name: String, slot_index: int) -> String:
	var slots := _variant_to_slots(get_bindings_snapshot().get(action_name, []))
	if slot_index < 0 or slot_index >= slots.size():
		return ""
	var binding: Dictionary = slots[slot_index]
	if binding.is_empty():
		return ""
	return describe_binding(binding)

func describe_binding(binding_value) -> String:
	var binding: Dictionary = {}
	if binding_value is Dictionary:
		binding = Dictionary(binding_value).duplicate(true)
	if binding.is_empty():
		return ""
	match String(binding.get("type", "")):
		"key":
			return _describe_key_binding(binding)
		"joy_button":
			return String(JOY_BUTTON_NAMES.get(int(binding.get("button_index", -1)), "Button %d" % int(binding.get("button_index", -1))))
		"joy_axis":
			return _describe_axis_binding(binding)
		_:
			return ""

func build_rebind_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or key_event.physical_keycode == KEY_NONE:
			return null
		var rebound_key := InputEventKey.new()
		rebound_key.physical_keycode = key_event.physical_keycode
		return rebound_key
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return null
		var rebound_button := InputEventJoypadButton.new()
		rebound_button.button_index = button_event.button_index
		return rebound_button
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) < AXIS_THRESHOLD:
			return null
		var rebound_axis := InputEventJoypadMotion.new()
		rebound_axis.axis = motion_event.axis
		rebound_axis.axis_value = 1.0 if motion_event.axis_value > 0.0 else -1.0
		return rebound_axis
	return null

func set_binding(action_name: String, slot_index: int, event: InputEvent) -> void:
	if not ACTION_DEFINITIONS.has(action_name) or event == null:
		return
	var serialized := _serialize_event(event)
	if serialized.is_empty():
		return
	var snapshot := get_bindings_snapshot()
	for managed_action in ACTION_ORDER:
		var slots := _variant_to_slots(snapshot.get(managed_action, []))
		for index in range(slots.size()):
			if managed_action == action_name and index == slot_index:
				continue
			if _binding_equals(slots[index], serialized):
				slots[index] = {}
		snapshot[managed_action] = _trim_slots(slots)
	var own_slots := _variant_to_slots(snapshot.get(action_name, []))
	if slot_index >= own_slots.size():
		return
	own_slots[slot_index] = serialized
	snapshot[action_name] = _trim_slots(own_slots)
	_apply_and_persist_snapshot(snapshot)

func reset_action_to_default(action_name: String) -> void:
	if not ACTION_DEFINITIONS.has(action_name):
		return
	var snapshot := get_bindings_snapshot()
	snapshot[action_name] = _default_slots_for_action(action_name)
	_apply_and_persist_snapshot(snapshot)

func reset_all_to_defaults() -> void:
	_apply_and_persist_snapshot(_build_default_snapshot())

func cancel_capture_allowed(event: InputEvent, action_name: String) -> bool:
	if action_name == "ui_cancel":
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if not button_event.pressed:
			return false
	return event.is_action_pressed("ui_cancel")

func capture_ignore_duration_ms() -> int:
	return CAPTURE_IGNORE_DURATION_MS

func _apply_and_persist_snapshot(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)
	GameState.set_input_bindings(snapshot)

func _build_boot_snapshot() -> Dictionary:
	var saved_bindings: Dictionary = GameState.get_input_bindings()
	var snapshot := _build_default_snapshot()
	for action_name in ACTION_ORDER:
		if not saved_bindings.has(action_name):
			continue
		var slots := _variant_to_slots(saved_bindings.get(action_name, []))
		snapshot[action_name] = _trim_slots(slots)
	return snapshot

func _build_default_snapshot() -> Dictionary:
	var snapshot := {}
	for action_name in ACTION_ORDER:
		snapshot[action_name] = _default_slots_for_action(action_name)
	return snapshot

func _default_slots_for_action(action_name: String) -> Array[Dictionary]:
	var slots := _empty_slots()
	var defaults: Array = Array(ACTION_DEFINITIONS.get(action_name, {}).get("defaults", []))
	for index in range(mini(defaults.size(), slots.size())):
		slots[index] = Dictionary(defaults[index]).duplicate(true)
	return _trim_slots(slots)

func _apply_snapshot(snapshot: Dictionary) -> void:
	for action_name in ACTION_ORDER:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_set_deadzone(action_name, AXIS_THRESHOLD)
		InputMap.action_erase_events(action_name)
		for binding in _variant_to_slots(snapshot.get(action_name, [])):
			var event := _deserialize_event(binding)
			if event != null:
				InputMap.action_add_event(action_name, event)
	bindings_changed.emit()

func _serialize_current_action(action_name: String) -> Array[Dictionary]:
	var slots := _empty_slots()
	if not InputMap.has_action(action_name):
		return slots
	var index := 0
	for event in InputMap.action_get_events(action_name):
		if index >= MAX_BINDING_SLOTS:
			break
		var serialized := _serialize_event(event)
		if serialized.is_empty():
			continue
		slots[index] = serialized
		index += 1
	return slots

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_NONE:
			return {}
		return {
			"type": "key",
			"physical_keycode": int(key_event.physical_keycode),
		}
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return {
			"type": "joy_button",
			"button_index": int(button_event.button_index),
		}
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		var direction := 1 if motion_event.axis_value >= 0.0 else -1
		return {
			"type": "joy_axis",
			"axis": int(motion_event.axis),
			"direction": direction,
		}
	return {}

func _deserialize_event(binding_value) -> InputEvent:
	if not (binding_value is Dictionary):
		return null
	var binding: Dictionary = Dictionary(binding_value).duplicate(true)
	match String(binding.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(binding.get("physical_keycode", KEY_NONE))
			return key_event if key_event.physical_keycode != KEY_NONE else null
		"joy_button":
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = int(binding.get("button_index", -1))
			return button_event if button_event.button_index >= 0 else null
		"joy_axis":
			var motion_event := InputEventJoypadMotion.new()
			motion_event.axis = int(binding.get("axis", -1))
			motion_event.axis_value = 1.0 if int(binding.get("direction", 1)) >= 0 else -1.0
			return motion_event if motion_event.axis >= 0 else null
		_:
			return null

func _variant_to_slots(raw_value) -> Array[Dictionary]:
	var slots := _empty_slots()
	if not (raw_value is Array):
		return slots
	var raw_list: Array = Array(raw_value)
	for index in range(mini(raw_list.size(), MAX_BINDING_SLOTS)):
		var raw_binding = raw_list[index]
		if raw_binding is Dictionary:
			slots[index] = Dictionary(raw_binding).duplicate(true)
	return slots

func _empty_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for _i in range(MAX_BINDING_SLOTS):
		slots.append({})
	return slots

func _trim_slots(slots: Array[Dictionary]) -> Array[Dictionary]:
	var trimmed := slots.duplicate(true)
	while not trimmed.is_empty() and Dictionary(trimmed[trimmed.size() - 1]).is_empty():
		trimmed.remove_at(trimmed.size() - 1)
	return trimmed

func _binding_equals(left_value, right_value) -> bool:
	if not (left_value is Dictionary) or not (right_value is Dictionary):
		return false
	var left: Dictionary = Dictionary(left_value)
	var right: Dictionary = Dictionary(right_value)
	if left.is_empty() or right.is_empty():
		return false
	return String(left.get("type", "")) == String(right.get("type", "")) \
		and int(left.get("physical_keycode", -1)) == int(right.get("physical_keycode", -2)) \
		and int(left.get("button_index", -1)) == int(right.get("button_index", -2)) \
		and int(left.get("axis", -1)) == int(right.get("axis", -2)) \
		and int(left.get("direction", 0)) == int(right.get("direction", 1))

func _describe_key_binding(binding: Dictionary) -> String:
	var keycode := int(binding.get("physical_keycode", KEY_NONE))
	if keycode == KEY_NONE:
		return ""
	var label := OS.get_keycode_string(keycode)
	return label if not label.is_empty() else "Key %d" % int(keycode)

func _describe_axis_binding(binding: Dictionary) -> String:
	var axis := int(binding.get("axis", -1))
	var direction := int(binding.get("direction", 1))
	var axis_labels: Dictionary = JOY_AXIS_NAMES.get(axis, {})
	if axis_labels.is_empty():
		return "Axis %d %s" % [axis, "+" if direction >= 0 else "-"]
	return String(axis_labels.get("positive" if direction >= 0 else "negative", "Axis %d" % axis))

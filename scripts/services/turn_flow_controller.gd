class_name TurnFlowController
extends RefCounted

enum TurnPhase {
	DAY_READY,
	ROUTE_PREVIEW,
	TRAVEL_EXECUTING,
	BRANCH_CHOICE,
	ARRIVAL_RESOLVE,
	VISIT_FLOW,
	POST_TRAVEL_RESOLVE,
	AI_TURN,
	SEASON_FINISHED,
}

var phase: TurnPhase = TurnPhase.DAY_READY

var pending_roll: Dictionary = {}
var reachable_paths: Dictionary = {}
var pending_travel_path: Array[int] = []
var pending_travel_target := -1
var queued_auto_travel_target := -1
var branch_choice_pending := false
var queued_roll_start := false
var pending_route_steps_remaining := 0
var pending_route_history: Array[int] = []
var pending_route_options: Array[int] = []
var pending_route_forced_path: Array[int] = []
var pending_route_forced_index := -1
var anchor_override_active := false

func reset() -> void:
	phase = TurnPhase.DAY_READY
	clear_route_state()

func clear_route_state(clear_roll: bool = true) -> void:
	branch_choice_pending = false
	queued_auto_travel_target = -1
	queued_roll_start = false
	pending_route_steps_remaining = 0
	pending_route_history.clear()
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1
	reachable_paths.clear()
	pending_travel_path.clear()
	pending_travel_target = -1
	anchor_override_active = false
	if clear_roll:
		pending_roll.clear()

func begin_roll(roll_result: Dictionary) -> void:
	pending_roll = roll_result.duplicate(true)
	clear_route_state(false)
	phase = TurnPhase.ROUTE_PREVIEW

func set_route_preview(paths: Dictionary, has_destinations: bool, anchor_used: bool) -> void:
	reachable_paths = paths.duplicate(true)
	anchor_override_active = anchor_used
	phase = TurnPhase.ROUTE_PREVIEW if has_destinations else TurnPhase.DAY_READY

func queue_roll_start() -> void:
	queued_roll_start = true

func consume_queued_roll_start() -> bool:
	var queued := queued_roll_start
	queued_roll_start = false
	return queued

func begin_travel(route_history: Array[int], steps_remaining: int, forced_path: Array[int] = [], forced_index: int = -1) -> void:
	pending_route_history = route_history.duplicate()
	pending_route_steps_remaining = steps_remaining
	pending_route_forced_path = forced_path.duplicate()
	pending_route_forced_index = forced_index
	pending_route_options.clear()
	branch_choice_pending = false
	phase = TurnPhase.TRAVEL_EXECUTING

func set_branch_options(options: Array[int]) -> void:
	pending_route_options = options.duplicate()
	branch_choice_pending = not pending_route_options.is_empty()
	if branch_choice_pending:
		phase = TurnPhase.BRANCH_CHOICE

func begin_travel_step(path: Array[int], target: int) -> void:
	pending_travel_path = path.duplicate()
	pending_travel_target = target
	branch_choice_pending = false
	pending_route_options.clear()
	phase = TurnPhase.TRAVEL_EXECUTING

func mark_arrival_resolve() -> void:
	phase = TurnPhase.ARRIVAL_RESOLVE

func enter_visit_flow() -> void:
	phase = TurnPhase.VISIT_FLOW

func enter_post_travel_resolve() -> void:
	phase = TurnPhase.POST_TRAVEL_RESOLVE

func set_phase(next_phase: TurnPhase) -> void:
	phase = next_phase

func get_phase_name() -> String:
	match phase:
		TurnPhase.DAY_READY:
			return "DAY_READY"
		TurnPhase.ROUTE_PREVIEW:
			return "ROUTE_PREVIEW"
		TurnPhase.TRAVEL_EXECUTING:
			return "TRAVEL_EXECUTING"
		TurnPhase.BRANCH_CHOICE:
			return "BRANCH_CHOICE"
		TurnPhase.ARRIVAL_RESOLVE:
			return "ARRIVAL_RESOLVE"
		TurnPhase.VISIT_FLOW:
			return "VISIT_FLOW"
		TurnPhase.POST_TRAVEL_RESOLVE:
			return "POST_TRAVEL_RESOLVE"
		TurnPhase.AI_TURN:
			return "AI_TURN"
		TurnPhase.SEASON_FINISHED:
			return "SEASON_FINISHED"
		_:
			return "UNKNOWN"

func is_input_locked() -> bool:
	return phase in [
		TurnPhase.TRAVEL_EXECUTING,
		TurnPhase.ARRIVAL_RESOLVE,
		TurnPhase.POST_TRAVEL_RESOLVE,
		TurnPhase.AI_TURN,
		TurnPhase.SEASON_FINISHED,
	]

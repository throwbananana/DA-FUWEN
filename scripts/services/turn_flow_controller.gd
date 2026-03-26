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

func reset() -> void:
	phase = TurnPhase.DAY_READY

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

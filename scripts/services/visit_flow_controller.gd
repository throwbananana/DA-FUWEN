class_name VisitFlowController
extends Node

## 管理一次“出门 -> 到点 -> 互动 -> 结算”的流程。
## 你可以把它挂到 visit 场景或主场景里。

const HabitatServiceScript = preload("res://scripts/services/habitat_service.gd")
const NpcServiceScript = preload("res://scripts/services/npc_service.gd")
const EncounterServiceScript = preload("res://scripts/services/encounter_service.gd")

signal visit_started(habitat_id: String)
signal state_changed(step_id: String, payload: Dictionary)
signal visit_finished(report: Dictionary)

var habitat_service = HabitatServiceScript.new()
var npc_service = NpcServiceScript.new()
var encounter_service = EncounterServiceScript.new()

var current_habitat_id := ""
var current_step := "idle"
var current_encounter := {}

func start_visit(habitat_id: String) -> void:
	current_habitat_id = habitat_id
	current_step = "arrival"
	var payload: Dictionary = habitat_service.get_visit_summary(habitat_id)
	visit_started.emit(habitat_id)
	state_changed.emit("arrival", payload)

func open_build_menu() -> void:
	current_step = "build_select"
	state_changed.emit("build_select", {
		"habitat_id": current_habitat_id,
		"buildings": DataRepository.get_buildings_for_habitat(current_habitat_id)
	})

func build_selected(building_id: String) -> void:
	var result: Dictionary = habitat_service.build_on_site(current_habitat_id, building_id)
	current_step = "build_result"
	state_changed.emit("build_result", result)

func open_npc_menu() -> void:
	current_step = "npc_menu"
	state_changed.emit("npc_menu", {
		"habitat_id": current_habitat_id,
		"npcs": npc_service.get_visible_npcs(current_habitat_id),
		"quests": npc_service.get_available_quests(current_habitat_id)
	})

func start_observation() -> void:
	current_encounter = encounter_service.roll_encounter(current_habitat_id)
	current_step = "encounter_preview"
	state_changed.emit("encounter_preview", current_encounter)

func choose_encounter_action(action_id: String) -> void:
	if current_encounter.is_empty():
		return
	var result: Dictionary = encounter_service.resolve_action(current_encounter, action_id)
	current_step = "encounter_result"
	state_changed.emit("encounter_result", result)

func finish_visit() -> void:
	var report := {
		"habitat_id": current_habitat_id,
		"step": current_step,
		"timestamp": Time.get_unix_time_from_system()
	}
	GameState.record_visit(report)
	current_habitat_id = ""
	current_step = "idle"
	current_encounter.clear()
	visit_finished.emit(report)

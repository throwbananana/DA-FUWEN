class_name GameSessionController
extends RefCounted

const GameConstants = preload("res://scripts/game_constants.gd")

func start_new_game(host) -> void:
	DataRepository.load_all()
	GameState.reset_for_new_season()
	GameState.set_run_modifiers(host.run_modifier_service.choose_run_modifiers(1))
	GameState.apply_system_rewards(host.run_modifier_service.apply_starting_bonus(GameState.run_modifiers))
	refresh_board_region(host, true)
	host.runtime_session_started = true
	host.season_finished = false
	host.current_node_id = GameState.current_board_node_id
	host.pending_battle_source = ""
	host.pending_environment_battle.clear()
	host.last_encounter_action_id = ""
	host.pending_context.clear()
	host.pending_roll.clear()
	host.reachable_paths.clear()
	host._queued_auto_travel_target = -1
	host.branch_choice_pending = false
	host._queued_roll_start = false
	host.pending_route_steps_remaining = 0
	host.pending_route_history.clear()
	host.pending_route_options.clear()
	host.pending_route_forced_path.clear()
	host.pending_route_forced_index = -1
	host.pending_travel_path.clear()
	host.pending_travel_target = -1
	host.anchor_override_active = false
	host.starter_choice_pending = not host._should_skip_runtime_tutorials()
	host.starter_choice_done = false
	host.starter_companion_uid = ""
	host.pending_tutorial_battle_config.clear()
	host.pending_tutorial_battle_source = ""
	host.pending_tutorial_battle_log = ""
	host._last_ai_turn_report.clear()
	host.turn_flow_controller.reset()
	host.visit_flow.reset()
	host.story_director.reset()
	host.decision_panel.hide()
	host.base_panel.hide()
	host.system_panel.hide()
	host._active_synergy_snapshot.clear()
	host._synergy_fx_ready = false
	if host._synergy_unit_glow_host != null:
		host._synergy_unit_glow_host.visible = false
	if host._stage_transition_layer != null:
		host._stage_transition_layer.visible = false
	host._assign_weekly_objective()
	host._maybe_notify_annual_competition_reminder()
	host._push_log("%s的日子开始了。先慢慢在城里走走，认识人，也给自己找个落脚的节奏。" % host._season_name())
	for modifier_line in host.run_modifier_service.format_lines(GameState.run_modifiers):
		host._push_log("本局词缀：%s" % modifier_line)
	for line in host.ai_player_service.build_status_lines(host.board_lookup, 3):
		host._push_log("其他远征队：%s" % line)
	begin_next_day(host)

func load_run_state_from_save(host, slot_id: String = "") -> void:
	var resolved_slot_id: String = slot_id if not slot_id.is_empty() else host._menu_selected_slot_id
	GameState.set_selected_run_slot_id(resolved_slot_id)
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id()
	var payload: Dictionary = GameState.load_run_payload(host._menu_selected_slot_id)
	if payload.is_empty():
		host.pending_context.clear()
		host.decision_panel.open_panel("没有存档", "这格还没有旅程记录。点“继续”就会直接从这里开始新远征。", [], "返回开始界面")
		return
	apply_run_payload(host, payload)
	host._hide_main_menu()
	host._push_log("已从 %s 接上这段旅程。" % host._slot_title(GameState.get_run_slot_meta(host._menu_selected_slot_id)))

func apply_run_payload(host, payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	DataRepository.load_all()
	GameState.apply_runtime_snapshot(payload.get("game_state", {}))
	restore_scene_runtime_state(host, payload.get("scene_state", {}))
	host.runtime_session_started = true
	refresh_board_region(host, true)
	host._maybe_notify_annual_competition_reminder()
	host.current_node_id = GameState.current_board_node_id
	host._update_ui()
	return true

func restore_scene_runtime_state(host, scene_state: Dictionary) -> void:
	host.season_finished = bool(scene_state.get("season_finished", false))
	host.pending_battle_source = ""
	host.pending_environment_battle.clear()
	host.last_encounter_action_id = ""
	host.pending_context.clear()
	host.pending_roll.clear()
	host.reachable_paths.clear()
	host.board_anim_locked = false
	host.pending_travel_path.clear()
	host.pending_travel_target = -1
	host._queued_auto_travel_target = -1
	host.branch_choice_pending = false
	host._queued_roll_start = false
	host.pending_route_steps_remaining = 0
	host.pending_route_history.clear()
	host.pending_route_options.clear()
	host.pending_route_forced_path.clear()
	host.pending_route_forced_index = -1
	host.anchor_override_active = false
	host.camp_panel_requires_finish = false
	host.starter_choice_pending = bool(scene_state.get("starter_choice_pending", false))
	host.starter_choice_done = bool(scene_state.get("starter_choice_done", false))
	host.starter_companion_uid = String(scene_state.get("starter_companion_uid", ""))
	host.pending_tutorial_battle_config.clear()
	host.pending_tutorial_battle_source = ""
	host.pending_tutorial_battle_log = ""
	host._last_ai_turn_report.clear()
	host.turn_flow_controller.reset()
	host.visit_flow.reset()
	host.awaiting_destination = bool(scene_state.get("awaiting_destination", false))
	host.current_visit_habitat_id = String(scene_state.get("current_visit_habitat_id", ""))
	host.story_director.reset()
	host.decision_panel.hide()
	host.base_panel.hide()
	host.system_panel.hide()
	host._active_synergy_snapshot.clear()
	host._synergy_fx_ready = false
	if host._synergy_unit_glow_host != null:
		host._synergy_unit_glow_host.visible = false
	if host._stage_transition_layer != null:
		host._stage_transition_layer.visible = false

func save_run_state(host) -> void:
	if DisplayServer.get_name() == "headless" or not host.runtime_session_started or host.season_finished:
		return
	GameState.save_run_payload(build_run_save_payload(host), GameState.get_selected_run_slot_id())

func build_run_save_payload(host) -> Dictionary:
	return {
		"version": 1,
		"summary": build_run_save_summary(host),
		"scene_state": {
			"season_finished": host.season_finished,
			"awaiting_destination": host.awaiting_destination,
			"current_visit_habitat_id": host.current_visit_habitat_id,
			"starter_choice_pending": host.starter_choice_pending,
			"starter_choice_done": host.starter_choice_done,
			"starter_companion_uid": host.starter_companion_uid,
		},
		"game_state": GameState.build_runtime_snapshot(),
	}

func build_run_save_summary(host) -> Dictionary:
	var node: Dictionary = host.board_lookup.get(host.current_node_id, {})
	return {
		"season_name": host._season_name(),
		"season_turn": GameState.season_turn,
		"season_length": GameState.season_length,
		"week_index": GameState.week_index,
		"global_turn": GameState.global_turn,
		"node_name": String(node.get("name", "营地")),
		"battle_slots": host._battle_slot_names(),
		"objective_summary": host.weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress),
	}

func build_world_nodes(host) -> Array:
	var nodes: Array = host.board_progression_service.get_nodes()
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var habitat_id: String = String(node.get("habitat_id", ""))
		if not habitat_id.is_empty():
			var habitat: Dictionary = DataRepository.get_habitat(habitat_id)
			if habitat.is_empty():
				continue
			if String(node.get("name", "")).is_empty():
				node["name"] = habitat.get("name", node.get("name", ""))
			if String(node.get("type", "")).is_empty():
				node["type"] = habitat.get("type", node.get("type", ""))
			if String(node.get("description", "")).is_empty():
				node["description"] = host._description_for_habitat(habitat)
			if not node.has("travel_cost"):
				node["travel_cost"] = int(habitat.get("travel_cost", 1))
		nodes[index] = node
	return nodes

func refresh_board_region(host, reset_position: bool) -> void:
	host.board_progression_service.set_region_for_season(GameState.season_id)
	host.world_nodes = build_world_nodes(host)
	host.board_lookup = host._build_board_lookup()
	host.board_view.setup(host.world_nodes)
	var region: Dictionary = host.board_progression_service.get_region()
	var start_node_id: int = host.board_progression_service.get_start_node_id()
	if reset_position:
		GameState.set_board_region(String(region.get("id", "")), start_node_id)
		GameState.reveal_board_nodes(region.get("revealed_nodes", []))
		GameState.reveal_board_nodes(host.board_progression_service.expand_reveal_from(start_node_id))
	host.current_node_id = GameState.current_board_node_id
	host.board_view.set_current_node(host.current_node_id, true)
	host.board_view.hide_observer()
	host._initialize_board_threats()

func begin_next_day(host) -> void:
	if GameState.day_index > GameState.season_length:
		if GameState.advance_to_next_season():
			refresh_board_region(host, true)
			host._assign_weekly_objective()
			host._maybe_notify_annual_competition_reminder()
			host._play_stage_transition("%s来临" % host._season_name(), "区域棋盘、周目标与路线分叉已经刷新。", host._season_fx_color(GameState.season_id))
			host._push_log("%s来临，区域棋盘、周目标与路线分叉已刷新。" % host._season_name())
		else:
			host._finish_season()
			return
	host.awaiting_destination = false
	host.current_node_id = GameState.current_board_node_id
	host.current_visit_habitat_id = ""
	host.current_encounter.clear()
	host.pending_battle_source = ""
	host.pending_environment_battle.clear()
	host.last_encounter_action_id = ""
	host.pending_roll.clear()
	host.reachable_paths.clear()
	host._queued_auto_travel_target = -1
	host.branch_choice_pending = false
	host._queued_roll_start = false
	host.pending_route_steps_remaining = 0
	host.pending_route_history.clear()
	host.pending_route_options.clear()
	host.pending_route_forced_path.clear()
	host.pending_route_forced_index = -1
	host.pending_travel_path.clear()
	host.pending_travel_target = -1
	host.anchor_override_active = false
	var weather_pool: Array = GameState.get_current_season_rule().get("weather_pool", GameConstants.WEATHER_ORDER)
	var next_weather: String = String(weather_pool[host.rng.randi_range(0, weather_pool.size() - 1)]) if not weather_pool.is_empty() else "clear"
	var next_time: String = String(GameConstants.TIME_ORDER[host.rng.randi_range(0, GameConstants.TIME_ORDER.size() - 1)])
	if GameState.day_index == 1:
		next_weather = String(weather_pool[0]) if not weather_pool.is_empty() else "clear"
		next_time = "day"
	GameState.set_daily_conditions(next_weather, next_time)
	if GameState.weekly_objective.is_empty():
		host._assign_weekly_objective()
	sync_npc_routes_for_day(host)
	host._push_log("[%s 第 %d / %d 回合 ｜ 第 %d 周] 天气：%s，时段：%s。" % [
		host._season_name(),
		GameState.season_turn,
		GameState.season_length,
		GameState.week_index,
		host._weather_name(GameState.weather_id),
		host._time_name(GameState.time_of_day),
	])
	host._update_ui()
	save_run_state(host)

func sync_npc_routes_for_day(host) -> void:
	var report: Dictionary = host.npc_route_service.sync_daily_positions()
	for line in report.get("lines", []):
		host._push_log("访客动向：%s" % String(line))

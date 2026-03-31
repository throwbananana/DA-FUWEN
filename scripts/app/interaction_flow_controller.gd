class_name InteractionFlowController
extends RefCounted

func on_visit_state_changed(host, step_id: String, payload: Dictionary) -> void:
	match step_id:
		"arrival":
			host._show_arrival_menu(payload)
		"build_select":
			host._show_build_menu(payload)
		"build_result":
			host._show_build_result(payload)
		"shop_menu":
			host._show_shop_menu(payload)
		"shop_result":
			host._show_shop_result(payload)
		"shop_npc_result":
			host._show_shop_npc_result(payload)
		"npc_menu":
			host._show_npc_menu(payload)
		"npc_duel_battle":
			host._start_npc_duel_battle(payload)
		"npc_duel_result":
			host._show_npc_duel_result(payload)
		"npc_talk_request":
			host._handle_talk_to_npc(String(payload.get("npc_id", "")))
		"talk_result":
			host._show_talk_result(payload)
		"quest_result":
			host._show_quest_result(payload)
		"resident_select":
			host._show_resident_picker(payload)
		"resident_result":
			host._show_resident_result(payload)
		"dojo_menu":
			host._show_dojo_menu(payload)
		"dojo_battle":
			host._start_dojo_battle(payload)
		"dojo_result":
			host._show_dojo_result(payload)
		"encounter_preview":
			host._show_encounter_preview(payload)
		"encounter_result":
			host._show_encounter_result(payload)
		"mail_menu":
			host._show_mail_menu(payload)
		"mail_result":
			host._show_mail_result(payload, "finish_visit")
		"fishing_menu":
			host._show_fishing_menu(payload)
		"fishing_result":
			host._show_fishing_result(payload)
		"nursery_menu":
			host._show_nursery_menu(payload)
		"nursery_species_select":
			host._show_nursery_species_picker(payload)
		"nursery_care_select":
			host._show_nursery_care_picker(payload)
		"nursery_result":
			host._show_nursery_result(payload)

func on_camp_flow_state_changed(host, step_id: String, payload: Dictionary) -> void:
	match step_id:
		"team_manage":
			host._show_team_manage_menu(payload)
		"team_battle_slot":
			host._show_team_battle_slot_picker(payload)
		"team_reserve_slot":
			host._show_team_reserve_picker(payload)
		"team_result":
			host._show_team_result(payload)
		"camp_resident_site":
			host._show_camp_resident_site_picker(payload)
		"camp_resident_select":
			host._show_camp_resident_picker(payload)
		"camp_resident_result":
			host._show_camp_resident_result(payload)
		"camp_mail_menu":
			host._show_camp_mail_menu(payload)
		"camp_mail_result":
			host._show_mail_result(payload, "reopen_base")

func on_decision_choice_selected(host, choice_id: String) -> void:
	if host.pending_context.is_empty():
		return
	var context: Dictionary = host.pending_context.duplicate(true)
	host.pending_context.clear()
	if try_handle_visit_decision_choice(host, context, choice_id):
		return
	match String(context.get("kind", "")):
		"starter_select":
			host._apply_starter_choice(choice_id)
		"minigame_menu":
			var node: Dictionary = host.board_lookup.get(int(context.get("node_id", -1)), {})
			if not node.is_empty():
				host._show_minigame_result(host.minigame_service.resolve_board_minigame(node, choice_id))
		"infirmary_menu":
			var infirmary_node: Dictionary = host.board_lookup.get(int(context.get("node_id", -1)), {})
			if not infirmary_node.is_empty() and choice_id == "rest":
				var result: Dictionary = host.infirmary_service.resolve_voluntary_rest(infirmary_node)
				host._push_log("在 %s 主动做了一轮疗养，没有花钱。" % String(infirmary_node.get("name", "疗养所")))
				host._show_infirmary_result(result, "finish_transit_stop")
		"team_manage":
			host.camp_flow.choose_team_manage_action(choice_id)
		"team_battle_slot":
			host.camp_flow.assign_team_battle_slot(int(context.get("slot_index", 0)), choice_id)
		"team_reserve_slot":
			host.camp_flow.toggle_team_reserve_slot(choice_id)
		"camp_resident_site":
			host.camp_flow.open_camp_resident_picker(choice_id)
		"camp_resident_select":
			host.camp_flow.assign_resident_to_habitat(String(context.get("habitat_id", "")), choice_id)
		"camp_mail_menu":
			host.camp_flow.send_camp_mail(choice_id)
		"menu_settings":
			host._apply_menu_setting(choice_id)
		"custom_asset_bind_menu":
			host._bind_custom_asset_slot(String(context.get("slot_id", "main_menu_bg")), choice_id)

func on_decision_closed(host) -> void:
	if host.pending_context.is_empty():
		return
	var context: Dictionary = host.pending_context.duplicate(true)
	host.pending_context.clear()
	if try_handle_visit_close_action(host, String(context.get("on_close", "none"))):
		host.story_director.try_flush_pending_quest_story_beats()
		return
	match String(context.get("on_close", "none")):
		"starter_random":
			var species_id: String = host.onboarding_flow_service.pick_random_starter_species(host.rng)
			if species_id.is_empty():
				return
			host._apply_starter_choice(species_id, true)
		"show_run_intro":
			if not GameState.has_completed_tutorial("run_intro"):
				host._show_tutorial_popup("run_intro")
			else:
				host._update_ui()
		"start_pending_battle":
			host._open_pending_tutorial_battle()
		"start_environment_battle":
			host._open_pending_environment_battle()
		"finish_visit":
			host._finish_current_visit()
		"finish_board_event":
			host._finish_board_event_visit()
		"finish_transit_stop":
			host._finish_transit_stop()
		"resume_board_stop":
			var node: Dictionary = host.board_lookup.get(host.current_node_id, {})
			if not node.is_empty():
				host._continue_board_stop_flow(node)
		"reopen_settings":
			if host.main_menu_panel.visible:
				host._refresh_main_menu()
				host._open_settings_menu()
		"team_manage":
			host._open_team_manage_menu()
		"reopen_base":
			host._on_base_pressed()
		_:
			pass
	host.story_director.try_flush_pending_quest_story_beats()

func try_handle_visit_decision_choice(host, context: Dictionary, choice_id: String) -> bool:
	match String(context.get("kind", "")):
		"visit_arrival":
			return handle_visit_arrival_choice(host, choice_id)
		"resident_select":
			host.visit_flow.assign_resident(choice_id)
			return true
		"build_select":
			host.visit_flow.build_selected(choice_id)
			return true
		"shop_menu":
			if choice_id.begins_with("buy:"):
				host.visit_flow.buy_shop_offer(choice_id.trim_prefix("buy:"))
			elif choice_id.begins_with("service:"):
				host.visit_flow.use_shop_npc_service(choice_id.trim_prefix("service:"))
			return true
		"npc_menu":
			host.visit_flow.choose_npc_action(choice_id)
			return true
		"dojo_menu":
			host.visit_flow.choose_dojo_tier(choice_id)
			return true
		"fishing_menu":
			host.visit_flow.choose_fishing_action(choice_id)
			return true
		"nursery_menu":
			match choice_id:
				"start_incubation":
					host.visit_flow.open_nursery_species_picker()
				"care_incubation":
					host.visit_flow.open_nursery_care_picker()
				"hatch_incubation":
					host.visit_flow.hatch_nursery_project()
			return true
		"nursery_species_select":
			host.visit_flow.start_nursery_project(choice_id)
			return true
		"nursery_care_select":
			host.visit_flow.care_nursery_project(choice_id)
			return true
		"encounter_preview":
			host.last_encounter_action_id = choice_id
			host.visit_flow.choose_encounter_action(choice_id)
			return true
		"mail_menu":
			host.visit_flow.send_mail(choice_id)
			return true
		_:
			return false

func handle_visit_arrival_choice(host, choice_id: String) -> bool:
	match choice_id:
		"assign_resident":
			host.visit_flow.open_resident_picker()
		"nursery_menu":
			host.visit_flow.open_nursery_menu()
		"build_menu":
			host.visit_flow.open_build_menu()
		"shop_menu":
			host.visit_flow.open_shop_menu()
		"npc_menu":
			host.visit_flow.open_npc_menu()
		"dojo_menu":
			host.visit_flow.open_dojo_menu()
		"observe":
			host.visit_flow.start_observation()
		"fishing_menu":
			host.visit_flow.open_fishing_menu()
		"mail_menu":
			host.visit_flow.open_mail_menu()
		_:
			return false
	return true

func try_handle_visit_close_action(host, on_close: String) -> bool:
	match on_close:
		"finish_visit":
			host._finish_current_visit()
			return true
		"arrival":
			reopen_current_visit_arrival(host)
			return true
		"nursery_menu":
			if not host.current_visit_habitat_id.is_empty():
				host.visit_flow.open_nursery_menu()
			return true
		"shop_menu":
			if not host.current_visit_habitat_id.is_empty():
				host.visit_flow.open_shop_menu()
			return true
		_:
			return false

func reopen_current_visit_arrival(host) -> void:
	if host.current_visit_habitat_id.is_empty():
		return
	host.visit_flow.start_visit(host.current_visit_habitat_id, host.board_lookup.get(host.current_node_id, {}))

func on_visit_finished(host, _report: Dictionary) -> void:
	host._resolve_visit_yield(host.current_visit_habitat_id)
	host.current_visit_habitat_id = ""
	host._advance_after_travel_stop()

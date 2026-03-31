class_name RuntimeFlowController
extends RefCounted

const MonsterInstance = preload("res://scripts/monster_instance.gd")

func continue_board_stop_flow(host, node: Dictionary) -> void:
	host._check_active_quests()
	if host._should_trigger_prearrival_ambush(host.current_node_id):
		host._push_log("%s 附近残留着躁动痕迹，本次需要先处理袭扰。" % String(node.get("name", "未知地点")))
		host.visit_flow.start_observation_for_habitat(host.current_visit_habitat_id, "ambush")
	else:
		host.visit_flow.start_visit(host.current_visit_habitat_id, node)
	host._update_ui()

func try_open_board_map_effect(host, node: Dictionary) -> bool:
	var report: Dictionary = host.board_map_effect_service.apply_on_arrival(
		node,
		host.current_node_id,
		GameState.board_region_id,
		host._current_boss_node_id(),
		host.board_lookup
	)
	if report.is_empty():
		return false
	var body_lines: Array[String] = []
	var description: String = String(report.get("description", ""))
	if not description.is_empty():
		body_lines.append(description)
	for line in report.get("lines", []):
		body_lines.append("- %s" % String(line))
		host._push_log("地图效果：%s。" % String(line))
	host.pending_context = {"kind": "board_map_effect", "on_close": "resume_board_stop"}
	host.decision_panel.open_panel(String(report.get("title", "地图效果")), "\n".join(body_lines), [], "继续前进")
	return true

func show_bulletin_board(host, node: Dictionary) -> void:
	var report: Dictionary = host.bulletin_service.build_board_bulletin(node)
	host._push_log("在 %s 看了一眼公告板，把本周的野群和折扣消息记下了。" % String(report.get("title", "公告板")))
	host.pending_context = {"kind": "bulletin_board", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel(String(report.get("title", "公告板")), String(report.get("body", "")), [], "继续前进")

func show_minigame_stop(host, node: Dictionary) -> void:
	var payload: Dictionary = host.minigame_service.build_board_minigame(node)
	host._push_log("路过 %s，旁边正好摆着一处能带伙伴热身的小游戏摊位。" % String(payload.get("title", "小游戏地块")))
	host.pending_context = {
		"kind": "minigame_menu",
		"node_id": int(node.get("id", -1)),
		"on_close": "finish_transit_stop",
	}
	host.decision_panel.open_panel(
		String(payload.get("title", "小游戏地块")),
		String(payload.get("body", "")),
		Array(payload.get("choices", [])).duplicate(true),
		"继续前进"
	)

func show_minigame_result(host, result: Dictionary) -> void:
	var body_lines: Array[String] = [
		String(result.get("text", "伙伴们稍微活动开了。")),
		"",
		"[b]下次战斗前[/b] %s" % String(result.get("reward_text", "会带一点小幅属性加成。")),
	]
	var combined_text: String = String(result.get("combined_text", ""))
	if not combined_text.is_empty():
		body_lines.append("[b]当前累计[/b] %s" % combined_text)
	host._push_log("%s：下次战斗前 %s。" % [
		String(result.get("title", "小游戏地块")),
		String(result.get("reward_text", "状态稍微被提起来了")),
	])
	host.pending_context = {"kind": "minigame_result", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("小游戏收尾", "\n".join(body_lines), [], "继续前进")

func show_infirmary_stop(host, node: Dictionary) -> void:
	var payload: Dictionary = host.infirmary_service.build_stop_menu(node)
	host._push_log("路过 %s，这里可以免费做一轮主动疗养。" % String(payload.get("title", "疗养所")))
	host.pending_context = {
		"kind": "infirmary_menu",
		"node_id": int(node.get("id", -1)),
		"on_close": "finish_transit_stop",
	}
	host.decision_panel.open_panel(
		String(payload.get("title", "疗养所")),
		String(payload.get("body", "")),
		Array(payload.get("choices", [])).duplicate(true),
		"先不休息"
	)

func show_infirmary_result(host, payload: Dictionary, on_close: String) -> void:
	host.pending_context = {"kind": "infirmary_result", "on_close": on_close}
	host.decision_panel.open_panel(String(payload.get("title", "疗养所")), String(payload.get("body", "")), [], "继续前进")

func apply_forced_infirmary_transfer(host, defeated_node: Dictionary) -> Dictionary:
	var infirmary_node: Dictionary = host.board_progression_service.find_best_infirmary_node(host.current_node_id)
	if infirmary_node.is_empty():
		var fallback: Dictionary = host.infirmary_service.resolve_forced_recovery({
			"name": "临时医疗点",
			"type": "infirmary",
		}, defeated_node)
		host._push_log("战败后临时做了一轮紧急疗养，扣除了 %d 金。" % int(fallback.get("paid_gold", 0)))
		return fallback

	host.current_node_id = int(infirmary_node.get("id", host.current_node_id))
	GameState.move_to_board_node(host.current_node_id)
	GameState.reveal_board_nodes(host.board_progression_service.expand_reveal_from(host.current_node_id))
	host.board_view.set_current_node(host.current_node_id, true)

	var report: Dictionary = host.infirmary_service.resolve_forced_recovery(infirmary_node, defeated_node)
	host._push_log("战败后被送往 %s 休整，疗养费扣除了 %d 金。" % [
		String(infirmary_node.get("name", "疗养所")),
		int(report.get("paid_gold", 0)),
	])
	return report

func resolve_environment_node(host, node: Dictionary) -> void:
	match String(node.get("environment_kind", "forage")):
		"wild_battle":
			prepare_environment_battle(host, node)
		"scout":
			show_environment_scout_stop(host, node)
		_:
			show_environment_forage_stop(host, node)

func show_empty_board_stop(host, node: Dictionary) -> void:
	show_environment_forage_stop(host, node)

func show_environment_forage_stop(host, node: Dictionary) -> void:
	var reward: Dictionary = host._environment_travel_reward(node)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "沿途环境")),
		String(node.get("description", "这是一段会产生沿途内容的环境路段。")),
		"",
		"这里没有固定据点，但能顺手收一波路上的资源。",
	]
	if not reward.is_empty():
		GameState.grant_items(reward)
		body_lines.append("[b]沿途收获[/b] %s" % host._format_item_cost(reward))
		host._push_log("穿过 %s，顺手带回了 %s。" % [String(node.get("name", "沿途环境")), host._format_item_cost(reward)])
	else:
		host._push_log("穿过 %s，主要是在调整队伍行进节奏。" % String(node.get("name", "沿途环境")))
	host.pending_context = {"kind": "transit_stop", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("环境路段", "\n".join(body_lines), [], "继续前进")

func show_environment_scout_stop(host, node: Dictionary) -> void:
	GameState.reveal_board_nodes(host.board_progression_service.build_scout_reveal(host.current_node_id, 4))
	var reward: Dictionary = host._environment_travel_reward(node)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "侦察路段")),
		String(node.get("description", "这是一段适合先看清地形的环境。")),
		"",
		"你在这里多停了一会儿，把前方几格的路况先看清了。",
	]
	if not reward.is_empty():
		GameState.grant_items(reward)
		body_lines.append("[b]沿途收获[/b] %s" % host._format_item_cost(reward))
	body_lines.append("[b]额外侦察[/b] 前方路线显露得更远了。")
	host._push_log("在 %s 提前看清了后续路况。" % String(node.get("name", "侦察路段")))
	host.pending_context = {"kind": "transit_stop", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("环境侦察", "\n".join(body_lines), [], "继续前进")

func prepare_environment_battle(host, node: Dictionary) -> void:
	var battle_config: Dictionary = build_environment_battle_config(host, node)
	if battle_config.is_empty():
		show_environment_forage_stop(host, node)
		return
	var enemy_names: Array[String] = []
	for enemy in battle_config.get("enemies", []):
		enemy_names.append(String(enemy.display_name))
	host.pending_environment_battle = {
		"node_id": int(node.get("id", host.current_node_id)),
		"node_name": String(node.get("name", "沿途环境")),
		"battle_config": battle_config,
		"reward": host._environment_travel_reward(node),
	}
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "野外遭遇")),
		String(node.get("description", "这里潜伏着躁动的野生个体。")),
		"",
		"你刚靠近这里，就把附近游荡的个体惊了出来。",
	]
	var special_encounter_hint: String = String(node.get("special_encounter_hint", ""))
	if not special_encounter_hint.is_empty():
		body_lines.append("[b]这一圈常见个体[/b] %s" % special_encounter_hint)
	if not enemy_names.is_empty():
		body_lines.append("[b]出现个体[/b] %s" % " / ".join(enemy_names))
	body_lines.append("这次会直接进入遭遇战，胜利后还能尝试捕缚。")
	host._push_log("%s 出现了近距离野外遭遇。" % String(node.get("name", "野外遭遇")))
	host.pending_context = {"kind": "environment_battle_intro", "on_close": "start_environment_battle"}
	host.decision_panel.open_panel("环境遭遇", "\n".join(body_lines), [], "迎战")

func open_pending_environment_battle(host) -> void:
	if host.pending_environment_battle.is_empty():
		await finish_transit_stop(host)
		return
	var battle_config: Dictionary = host.pending_environment_battle.get("battle_config", {})
	if battle_config.is_empty():
		host.pending_environment_battle.clear()
		await finish_transit_stop(host)
		return
	host.decision_panel.hide()
	host._start_battle_with_tutorial(
		battle_config,
		"environment_wild",
		"穿过 %s 时惊动了附近的野生个体。" % String(host.pending_environment_battle.get("node_name", "沿途环境"))
	)

func build_environment_battle_config(host, node: Dictionary) -> Dictionary:
	var habitat_id: String = String(node.get("source_habitat_id", ""))
	if habitat_id.is_empty() or GameState.get_party_uids().size() < 2:
		return {}
	var special_pool: Array = Array(node.get("special_encounter_pool", [])).duplicate(true)
	var using_special_pool: bool = not special_pool.is_empty()
	var first_encounter: Dictionary = host.encounter_service.roll_custom_entries(special_pool, "environment") if using_special_pool else host.encounter_service.roll_encounter(habitat_id, "environment")
	if not bool(first_encounter.get("ok", false)):
		return {}
	var second_encounter: Dictionary = host.encounter_service.roll_custom_entries(special_pool, "environment") if using_special_pool else host.encounter_service.roll_encounter(habitat_id, "environment")
	var enemy_level: int = clampi(GameState.get_progression_rank() + 1, 1, 6)
	var first_species_id: String = String(first_encounter.get("species_id", ""))
	var second_species_id: String = String(second_encounter.get("species_id", first_species_id))
	var pending_bonus: Dictionary = GameState.peek_pending_minigame_bonus()
	var pending_bonus_text: String = host.minigame_service.pending_bonus_summary()
	var subtitle_lines: Array[String] = [
		"环境：%s" % String(node.get("focus", "行进 / 缓冲")),
		"情绪：%s" % String(first_encounter.get("mood_id", "wild")),
	]
	var special_loop_name: String = String(node.get("special_loop_name", ""))
	if not special_loop_name.is_empty():
		subtitle_lines.append("环带：%s" % special_loop_name)
	var special_encounter_hint: String = String(node.get("special_encounter_hint", ""))
	if not special_encounter_hint.is_empty():
		subtitle_lines.append("群落：%s" % special_encounter_hint)
	if not pending_bonus_text.is_empty():
		subtitle_lines.append(pending_bonus_text)
	return {
		"title": "%s · 野外遭遇" % String(node.get("name", "沿途环境")),
		"subtitle": "\n".join(subtitle_lines),
		"kind": "wild",
		"allow_capture": true,
		"allow_escape": true,
		"ally_first_round_attack_bonus": false,
		"ally_attack_bonus": int(pending_bonus.get("ally_attack_bonus", 0)),
		"ally_speed_bonus": int(pending_bonus.get("ally_speed_bonus", 0)),
		"ally_hp_bonus": int(pending_bonus.get("ally_hp_bonus", 0)),
		"ally_heal_bonus": 0,
		"ally_guard_bonus": 0.0,
		"enemy_attack_penalty": 0,
		"consume_minigame_bonus": host.minigame_service.has_pending_bonus(),
		"encounter_origin": "special_loop" if using_special_pool else "habitat",
		"special_loop_id": String(node.get("special_loop_id", "")),
		"round_limit": 6,
		"allies": host.battle_roster_service.build_active_allies(),
		"ally_reserve": host.battle_roster_service.build_reserve_allies(),
		"enemies": [
			MonsterInstance.new(first_species_id, enemy_level, 1),
			MonsterInstance.new(second_species_id, enemy_level, 1),
		],
	}

func resolve_environment_battle(host, result: Dictionary) -> void:
	var payload: Dictionary = host.pending_environment_battle.duplicate(true)
	host.pending_environment_battle.clear()
	var node_name: String = String(payload.get("node_name", "沿途环境"))
	var body_lines: Array[String] = []
	var escaped: bool = bool(result.get("escaped", false))
	var codex_reveals: Array[Dictionary] = host._reveal_codex_for_battle_payload(payload)
	if bool(result.get("player_won", false)):
		body_lines.append("[b]%s[/b] 已经被稳定下来。" % node_name)
		var captured_species: String = String(result.get("captured_species", ""))
		if not captured_species.is_empty():
			var acquisition: Dictionary = host._acquire_companion(captured_species)
			body_lines.append(String(acquisition.get("body", "%s 愿意靠近。" % captured_species)))
			host._check_active_quests()
		var reward: Dictionary = Dictionary(payload.get("reward", {})).duplicate(true)
		if not reward.is_empty():
			GameState.grant_items(reward)
			body_lines.append("[b]沿途收获[/b] %s" % host._format_item_cost(reward))
			host._push_log("处理完 %s 的遭遇后，顺手带回了 %s。" % [node_name, host._format_item_cost(reward)])
		else:
			host._push_log("%s 的野外遭遇已经处理完毕。" % node_name)
	elif escaped:
		GameState.add_node_danger(host.current_node_id, 1)
		body_lines.append("[b]%s[/b] 还没稳住，你先带队撤开了。" % node_name)
		body_lines.append("这里的危险度上升到 %d / 3。" % GameState.get_node_danger(host.current_node_id))
		host._push_log("%s 的野外遭遇还没处理完，队伍先撤开了，危险度继续上升。" % node_name)
	else:
		GameState.add_node_danger(host.current_node_id, 1)
		body_lines.append("[b]%s[/b] 把你逼退了。" % node_name)
		body_lines.append("这里的危险度上升到 %d / 3。" % GameState.get_node_danger(host.current_node_id))
		host._push_log("%s 的野外遭遇把队伍逼退了，危险度继续上升。" % node_name)
		var defeated_node: Dictionary = host.board_lookup.get(int(payload.get("node_id", host.current_node_id)), {}).duplicate(true)
		var infirmary_report: Dictionary = apply_forced_infirmary_transfer(host, defeated_node if not defeated_node.is_empty() else {"ring_index": 0})
		body_lines.append("")
		body_lines.append(String(infirmary_report.get("body", "")))
	if not codex_reveals.is_empty():
		var unlocked_titles: Array[String] = []
		for entry in codex_reveals:
			unlocked_titles.append(String(Dictionary(entry).get("title", Dictionary(entry).get("id", "新条目"))))
		body_lines.append("")
		body_lines.append("[b]图鉴识别[/b] %s" % " / ".join(unlocked_titles))
	host.pending_context = {"kind": "environment_battle_result", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("环境遭遇结果", "\n".join(body_lines), [], "继续前进")

func show_locked_board_stop(host, node: Dictionary) -> void:
	var habitat_id: String = String(node.get("habitat_id", ""))
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "未开放据点")),
		String(node.get("description", "这里现在还不适合久留。")),
		"",
		"%s" % host._unlock_marker_text(habitat_id),
		"这次先从这里路过，等时机到了再回来好好看看。",
	]
	host._push_log("路过 %s，这里现在还只能先看看。" % String(node.get("name", "未开放据点")))
	host.pending_context = {"kind": "locked_stop", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("暂时只能路过", "\n".join(body_lines), [], "继续前进")

func show_ring_gate_blocked(host, node: Dictionary, message: String) -> void:
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "外环路口")),
		String(node.get("description", "这里通往更外侧的环路。")),
		"",
		message,
	]
	host._push_log("抵达 %s，但前面的路现在还没完全打开。" % String(node.get("name", "外环路口")))
	host.pending_context = {"kind": "ring_gate_locked", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("前路还没打开", "\n".join(body_lines), [], "继续前进")

func apply_ring_unlock_result(host, result: Dictionary, open_panel: bool = true) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	GameState.reveal_board_nodes(result.get("revealed_nodes", []))
	host._refresh_board_region(false)
	host._push_log(String(result.get("message", "更远的路已经露出来了。")))
	if not open_panel:
		return
	host.pending_context = {"kind": "ring_unlock", "on_close": "finish_transit_stop"}
	host.decision_panel.open_panel("前路打开了", String(result.get("message", "更远的路已经露出来了。")), [], "继续前进")

func finish_board_event_visit(host) -> void:
	host.current_visit_habitat_id = ""
	await advance_after_travel_stop(host)

func finish_transit_stop(host) -> void:
	host.current_visit_habitat_id = ""
	await advance_after_travel_stop(host)

func advance_after_travel_stop(host) -> void:
	if host._post_travel_resolution_in_progress:
		return
	host._post_travel_resolution_in_progress = true
	host.turn_flow_controller.enter_post_travel_resolve()
	resolve_season_boss_reward(host)
	host._resolve_board_threat_turn()
	if host.season_finished:
		host._post_travel_resolution_in_progress = false
		return
	var is_week_end: bool = GameState.weekly_turn >= 5
	if is_week_end:
		resolve_weekly_settlement(host)
	await run_ai_turns(host)
	var day_report: Dictionary = GameState.advance_day()
	for line in day_report.get("lines", []):
		host._push_log(line)
	host._begin_next_day()
	host._post_travel_resolution_in_progress = false

func run_ai_turns(host) -> void:
	if not host.runtime_session_started:
		return
	var ai_result: Dictionary = host.ai_player_service.simulate_turns(host.board_lookup, false)
	var reports: Array = ai_result.get("reports", [])
	if reports.is_empty():
		return
	var staged_players: Array = GameState.get_ai_players().duplicate(true)
	host.ai_turn_in_progress = true
	host._active_ai_observation_line = "你腾出片刻观察其他远征队的推进。"
	host._update_ui()
	if not GameState.should_skip_animations():
		host._play_stage_transition("对手回合", "你空出手来观察其他远征队的推进、抢点和遭遇。", Color(0.95, 0.74, 0.38, 1.0))
		await host.get_tree().create_timer(0.28).timeout
	for raw_report in reports:
		var report: Dictionary = Dictionary(raw_report).duplicate(true)
		await play_single_ai_observed_turn(host, report, staged_players)
	GameState.set_ai_players(staged_players.duplicate(true))
	host.ai_turn_in_progress = false
	host._active_ai_observation_line = ""
	host.board_view.hide_observer()
	host._update_ui()
	show_ai_turn_report(host, ai_result)

func play_single_ai_observed_turn(host, report: Dictionary, staged_players: Array) -> void:
	var player_index: int = int(report.get("index", -1))
	var line: String = String(report.get("line", "")).strip_edges()
	if player_index < 0 or player_index >= staged_players.size():
		if not line.is_empty():
			host._active_ai_observation_line = line
			host._push_log("对手回合：%s" % line)
			host._update_ui()
		return

	var before_player: Dictionary = Dictionary(staged_players[player_index]).duplicate(true)
	var after_player: Dictionary = Dictionary(report.get("player", before_player)).duplicate(true)
	var move: Dictionary = Dictionary(report.get("move", {})).duplicate(true)
	var landing: Dictionary = Dictionary(report.get("landing", {})).duplicate(true)
	var display_name: String = String(after_player.get("display_name", before_player.get("display_name", "对手")))
	var start_node_id: int = int(before_player.get("current_node_id", -1))
	var path: Array[int] = []
	for raw_node_id in Array(move.get("path", [])):
		path.append(int(raw_node_id))
	if path.is_empty() and start_node_id >= 0:
		path.append(start_node_id)

	host.board_view.set_observer_node(start_node_id, true)
	host._active_ai_observation_line = host._build_ai_observation_move_line(display_name, move, landing, after_player)
	host._update_ui()
	if not GameState.should_skip_animations():
		await host.get_tree().create_timer(host.AI_OBSERVE_PREPARE_DELAY).timeout

	if path.size() >= 2:
		await host.board_view.play_observer_travel(path)
	elif start_node_id >= 0:
		host.board_view.set_observer_node(start_node_id, true)

	staged_players[player_index] = after_player
	GameState.set_ai_players(staged_players.duplicate(true))
	host._active_ai_observation_line = host._build_ai_observation_landing_line(display_name, landing, report)
	host._update_ui()
	if not GameState.should_skip_animations():
		await host.get_tree().create_timer(host.AI_OBSERVE_LANDING_DELAY).timeout

	if line.is_empty():
		line = host._build_ai_observation_landing_line(display_name, landing, report)
	host._push_log("对手回合：%s" % line)
	host._active_ai_observation_line = "%s 的下一拍意图：%s" % [
		display_name,
		String(report.get("intent", "继续观察")),
	]
	host._update_ui()
	if not GameState.should_skip_animations():
		await host.get_tree().create_timer(host.AI_OBSERVE_TURN_FINISH_DELAY).timeout

func show_ai_turn_report(host, ai_result: Dictionary) -> void:
	host._last_ai_turn_report = Dictionary(ai_result).duplicate(true)
	var sections: Array = host._build_ai_report_sections(host._last_ai_turn_report)
	if sections.is_empty():
		return
	host.system_panel.open_panel("外头动静", sections, String(sections[0].get("id", "ai_0")))

func on_battle_finished(host, result: Dictionary) -> void:
	if is_instance_valid(host._battle_bgm_player):
		host._battle_bgm_player.stop()
		host._battle_bgm_player.stream = null
	if host.pending_battle_source == "npc_intro_duel":
		host.visit_flow.resolve_npc_intro_duel(result)
	elif host.pending_battle_source == "environment_wild":
		resolve_environment_battle(host, result)
	else:
		host.visit_flow.resolve_dojo_battle(result)
	host.pending_battle_source = ""
	host._sync_menu_bgm()
	host._update_ui()

func handle_talk_to_npc(host, npc_id: String) -> void:
	if host.npc_service.needs_intro_duel(npc_id):
		host.pending_context = {"kind": "talk_result", "on_close": "finish_visit"}
		host.decision_panel.open_panel("现在还聊不开", "第一次见面要先切磋一下，熟了之后再慢慢聊。", [], "结束偶遇")
		return

	GameState.note_talk(npc_id)
	GameState.add_weekly_progress("talk_count", 1)
	if host._can_mark_return(npc_id):
		GameState.note_return(npc_id)
	var npc: Dictionary = DataRepository.get_npc(npc_id)
	var talk_package: Dictionary = host.dialogue_service.build_talk_package(npc_id, host.current_visit_habitat_id)
	var trust_rewards: Dictionary = talk_package.get("trust_rewards", {})
	var active_npc_bonus: int = int(trust_rewards.get(npc_id, 0))
	var trust_result: Dictionary = host.npc_service.complete_trust_reward(npc_id, 1 + active_npc_bonus)
	var cutscene_played: bool = await play_talk_cutscene(host, npc_id, npc, talk_package)
	apply_talk_side_effects(host, npc_id, talk_package)
	var unlocked_lines: Array[String] = []
	for entry in trust_result.get("unlocked", []):
		unlocked_lines.append("- 信赖 %d：%s" % [int(entry.get("threshold", 0)), String(entry.get("reward", ""))])
	var body_lines: Array[String] = []
	body_lines.append("[b]%s[/b] 今天愿意多和你聊一点。" % String(npc.get("name", "某人")))
	var event_result: Dictionary = talk_package.get("event", {})
	if not cutscene_played:
		if not event_result.is_empty():
			body_lines.append("[b]今日小事：%s[/b]" % String(event_result.get("title", "临时插曲")))
			for line in event_result.get("stage_lines", []):
				body_lines.append(String(line))
			var outcome: String = String(event_result.get("outcome", ""))
			if not outcome.is_empty():
				body_lines.append("结果：%s" % outcome)
			body_lines.append("")
		for line in talk_package.get("transcript_lines", []):
			body_lines.append(String(line))
		body_lines.append("")
	elif not event_result.is_empty():
		body_lines.append("刚才那段插曲已经演完了，变化如下。")
		body_lines.append("")
	body_lines.append("当前信赖：%d" % int(trust_result.get("trust", 0)))
	var reward_lines: Array[String] = host._build_talk_reward_lines(npc_id, talk_package)
	if not reward_lines.is_empty():
		body_lines.append("")
		body_lines.append("[b]这次交谈带来的变化[/b]")
		body_lines.append("\n".join(reward_lines))
	var tags: Array = talk_package.get("tags", [])
	if not tags.is_empty():
		body_lines.append("")
		body_lines.append("[b]话题标签[/b] %s" % " / ".join(tags))
	if not unlocked_lines.is_empty():
		body_lines.append("")
		body_lines.append("[b]已达成的信赖反馈[/b]")
		body_lines.append("\n".join(unlocked_lines))
	var dialogue_id: String = String(talk_package.get("dialogue_id", ""))
	var topic: String = String(talk_package.get("topic", "daily"))
	if not dialogue_id.is_empty():
		GameState.note_dialogue_seen(npc_id, dialogue_id, topic)
	host._push_log("和 %s 聊了聊，这次谈到了%s。" % [String(npc.get("name", "某人")), host._talk_topic_label(topic)])
	host._check_active_quests()
	host.pending_context = {"kind": "talk_result", "on_close": "finish_visit"}
	host.decision_panel.open_panel(
		"交谈结果",
		"\n".join(body_lines),
		[],
		"结束偶遇",
		host._npc_portrait_texture(npc_id),
		host._npc_portrait_caption(npc_id)
	)

func play_talk_cutscene(host, npc_id: String, npc: Dictionary, talk_package: Dictionary) -> bool:
	if host._should_skip_cutscene_runtime():
		return false
	var cutscene_payload: Dictionary = host.cutscene_service.build_talk_cutscene(npc_id, npc, talk_package)
	var steps: Array = Array(cutscene_payload.get("steps", [])).duplicate(true)
	var dialogue_runtime: Dictionary = Dictionary(cutscene_payload.get("dialogue_runtime", {})).duplicate(true)
	if steps.is_empty() and dialogue_runtime.is_empty():
		return false
	for raw_step in steps:
		await present_cutscene_step(host, Dictionary(raw_step).duplicate(true))
	if not dialogue_runtime.is_empty():
		await host._play_dialogue_cutscene(dialogue_runtime)
	host.cutscene_panel.hide()
	host.cutscene_panel.modulate.a = 1.0
	return true

func present_cutscene_step(host, step: Dictionary) -> String:
	if host._should_skip_cutscene_runtime():
		return ""
	host.cutscene_panel.open_step(step)
	var choices: Array = Array(step.get("choices", [])).duplicate(true)
	if choices.is_empty():
		await host.cutscene_panel.continued
		return ""
	await host.cutscene_panel.choice_selected
	return host.cutscene_panel.last_choice_id

func apply_talk_side_effects(host, active_npc_id: String, talk_package: Dictionary) -> void:
	var story_beat: Dictionary = Dictionary(talk_package.get("story_beat", {})).duplicate(true)
	if not story_beat.is_empty():
		host.story_service.commit_story_beat(story_beat)
	var ambient_event: Dictionary = Dictionary(talk_package.get("event", {})).duplicate(true)
	var ambient_event_id: String = String(ambient_event.get("id", ""))
	if not ambient_event_id.is_empty():
		GameState.note_ambient_event_seen(
			ambient_event_id,
			Array(ambient_event.get("tags", [])).duplicate(true),
			host.current_visit_habitat_id
		)
	for event_id in talk_package.get("completed_events", []):
		if not String(event_id).is_empty():
			GameState.mark_event_completed(String(event_id))
	for dialogue_id in talk_package.get("unlocked_dialogues", []):
		if not String(dialogue_id).is_empty():
			GameState.unlock_dialogue(String(dialogue_id))
	host._apply_codex_and_encyclopedia_unlocks(talk_package)
	for raw_flag in talk_package.get("story_flags", []):
		var flag_id: String = String(raw_flag)
		if not flag_id.is_empty():
			GameState.set_story_flag(flag_id)
	for raw_delta in talk_package.get("relation_deltas", []):
		var relation_delta: Dictionary = Dictionary(raw_delta).duplicate(true)
		var actor_a: String = String(relation_delta.get("actor_a", ""))
		var actor_b: String = String(relation_delta.get("actor_b", ""))
		if actor_a.is_empty() or actor_b.is_empty():
			continue
		GameState.apply_social_relation_delta(actor_a, actor_b, relation_delta)
	var items: Dictionary = talk_package.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)
	for entry in talk_package.get("journal_entries", []):
		var text: String = String(entry)
		if not text.is_empty():
			GameState.add_journal_entry(text)
	var trust_rewards: Dictionary = talk_package.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var target_id: String = String(npc_id)
		if target_id.is_empty() or target_id == active_npc_id:
			continue
		GameState.add_trust(target_id, int(trust_rewards[npc_id]))

func finish_current_visit(host) -> void:
	if host.current_visit_habitat_id.is_empty():
		return
	host.visit_flow.finish_visit()

func finish_camp_visit(host) -> void:
	host.current_visit_habitat_id = ""
	await advance_after_travel_stop(host)

func resolve_visit_yield(host, habitat_id: String) -> void:
	var reward: Dictionary = host._base_visit_reward(habitat_id)
	var resonance: Dictionary = host.synergy_service.build_visit_resonance(habitat_id)
	var base_reward: Dictionary = host._base_visit_reward(habitat_id)
	for _roll in range(int(resonance.get("economy_rolls", 0))):
		host._merge_reward_items(reward, base_reward)
	host._merge_reward_items(reward, host._seasonal_visit_reward(habitat_id))
	reward = host.run_modifier_service.apply_visit_reward_modifiers(reward, GameState.run_modifiers)
	if not reward.is_empty():
		GameState.grant_items(reward)
		host._push_log("回营时顺手带回：%s。" % host._format_item_cost(reward))
	var growth_lines: Array[String] = host._apply_visit_growth_resonance(resonance.get("bond_gains", {}))
	for line in resonance.get("lines", []):
		host._push_log("建筑共鸣：%s" % String(line))
	for line in growth_lines:
		host._push_log(line)

func resolve_weekly_settlement(host) -> void:
	if GameState.weekly_objective.is_empty():
		return
	var objective: Dictionary = GameState.weekly_objective.duplicate(true)
	var progress: Dictionary = GameState.weekly_progress.duplicate(true)
	var hunger_after_week: int = GameState.consume_hunger(GameState.hunger_cost_per_week)
	var completed: bool = host.weekly_cycle_service.is_complete(objective, progress)
	var summary_lines: Array[String] = host.weekly_cycle_service.build_progress_lines(objective, progress)
	host._push_log("第 %d 周结算：%s。" % [GameState.week_index, String(objective.get("title", "本周目标"))])
	for line in summary_lines:
		host._push_log("周进度：%s。" % line)
	host._push_log("周结算额外消耗饥饿 %d，当前 %d / %d。" % [GameState.hunger_cost_per_week, hunger_after_week, GameState.max_hunger])
	if completed:
		var reward_bundle: Dictionary = DataRepository.get_reward_bundle(host.weekly_cycle_service.get_reward_bundle_id(objective))
		var reward_text: String = host._apply_reward_bundle(reward_bundle)
		if not reward_text.is_empty():
			host._push_log("周目标完成，获得 %s。" % reward_text)
	else:
		GameState.grant_items({"soft_moss": 1})
		host._push_log("周目标未完成，仍获得休整补给：%s。" % host._format_item_cost({"soft_moss": 1}))
	var modifier_bonus: Dictionary = host.run_modifier_service.apply_weekly_bonus(GameState.run_modifiers)
	if not modifier_bonus.is_empty():
		GameState.apply_system_rewards(modifier_bonus)
		host._push_log("词缀追加：%s。" % host._format_reward_bundle({"systems": modifier_bonus}))
	GameState.weekly_objective.clear()
	GameState.weekly_progress.clear()

func maybe_notify_annual_competition_reminder(host) -> void:
	var reminder: Dictionary = host.annual_competition_service.maybe_issue_month_reminder()
	if reminder.is_empty() or not bool(reminder.get("ok", false)):
		return
	host._push_log(String(reminder.get("log_line", "")))

func resolve_annual_competition_if_needed(host) -> Dictionary:
	var result: Dictionary = host.annual_competition_service.resolve_current_year()
	if result.is_empty() or not bool(result.get("ok", false)):
		return {}
	host._push_log(String(result.get("log_line", "")))
	for line in Array(result.get("leaderboard_lines", [])).slice(0, 3):
		host._push_log("年赛榜：%s。" % String(line))
	return result

func resolve_season_boss_reward(host) -> void:
	var boss_rule: Dictionary = DataRepository.get_season_boss_rule(GameState.season_id)
	if boss_rule.is_empty():
		return
	if GameState.claimed_season_bosses.has(GameState.season_id):
		return
	if host._current_boss_node_id() != host.current_node_id:
		return
	var reward_bundle: Dictionary = DataRepository.get_reward_bundle(String(boss_rule.get("reward_bundle_id", "")))
	var reward_text: String = host._apply_reward_bundle(reward_bundle)
	GameState.claimed_season_bosses.append(GameState.season_id)
	if not reward_text.is_empty():
		host._push_log("赛季高潮：%s 被征服，获得 %s。" % [String(boss_rule.get("name", "赛季 Boss")), reward_text])

func finish_season(host) -> void:
	var annual_competition_result: Dictionary = resolve_annual_competition_if_needed(host)
	host.season_finished = true
	host.turn_flow_controller.mark_run_summary()
	host.awaiting_destination = false
	GameState.clear_run_save(GameState.get_selected_run_slot_id())
	var run_summary: Dictionary = host.meta_progression_service.build_run_summary()
	var reward_result: Dictionary = host.meta_progression_service.commit_run_rewards(run_summary)
	var reward_lines: Array[String] = host.meta_progression_service.format_reward_summary(reward_result)
	var bonus_appendix: Array[String] = host.meta_bonus_report_service.build_run_summary_appendix({
		"points": int(reward_result.get("points", 0)),
		"total_after": int(reward_result.get("total_after", GameState.exploration_points_total)),
		"new_tracks": host._reward_track_ids(reward_result),
	})
	host.action_hint_label.text = "[b]这一年的收获[/b]\n照料进度 %d ｜ 已安居据点 %d ｜ 图鉴 %d ｜ 徽章 %d ｜ 季节点数 %d\n本局探索点 %d ｜ 累计探索点 %d" % [
		GameState.get_care_progress(),
		GameState.get_settled_habitat_count(),
		GameState.discovered_species.size(),
		GameState.badge_count,
		GameState.season_points,
		int(reward_result.get("points", 0)),
		GameState.exploration_points_total,
	]
	if not reward_lines.is_empty():
		host.action_hint_label.text += "\n" + "\n".join(reward_lines)
	if not bonus_appendix.is_empty():
		host.action_hint_label.text += "\n" + "\n".join(bonus_appendix)
	var annual_summary: String = host._annual_competition_result_summary(annual_competition_result)
	if not annual_summary.is_empty():
		host.action_hint_label.text += "\n这一年的比试：%s" % annual_summary
	host._play_stage_transition(
		"这一年的日子先告一段落",
		"本局探索点 +%d\n累计探索点 %d" % [int(reward_result.get("points", 0)), GameState.exploration_points_total],
		Color(1.0, 0.84, 0.38, 1.0)
	)
	host._push_log("这一年的日子先告一段落，结算点数 %d。" % int(reward_result.get("points", 0)))
	for line in reward_lines:
		host._push_log("年度结算：%s。" % line)
	for line in bonus_appendix:
		host._push_log("元成长来源：%s。" % line)
	host._update_ui()
	if host._should_show_boot_menu():
		host._show_main_menu()

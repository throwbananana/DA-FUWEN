class_name UIShellController
extends RefCounted

func update_ui(host) -> void:
	host._sync_turn_phase_from_flags()
	update_header(host)
	update_action_ui(host)
	apply_casual_exposure_policy(host)
	update_summaries(host)
	update_roster(host)
	update_log(host)
	update_map_hint(host)
	host.board_view.refresh_view(host.current_node_id, host._get_selectable_nodes(), host._build_board_markers(), host._get_locked_nodes())
	host.board_view.set_npc_presence(host.npc_route_service.build_node_presence_entries())
	host.board_view.set_controller_navigation_enabled(host.branch_choice_pending)
	if host.main_menu_panel.visible:
		host._refresh_main_menu()

func apply_casual_exposure_policy(host) -> void:
	var intro: bool = bool(host._is_casual_intro_phase())
	host.rival_card.visible = not intro
	host.control_card.visible = not intro
	host.roster_panel.visible = not intro
	host.board_meta_column.visible = not intro or host.awaiting_destination or host.branch_choice_pending

func update_header(host) -> void:
	var objective_name: String = String(GameState.weekly_objective.get("title", "等待周目标"))
	var objective_progress: String = " / ".join(host.weekly_cycle_service.build_progress_lines(GameState.weekly_objective, GameState.weekly_progress))
	if objective_progress.is_empty():
		objective_progress = "本周尚未结算"
	host.meta_label.text = "%s · 第 %d 周 · %s" % [
		host._season_name(),
		GameState.week_index,
		host.board_progression_service.get_region_name(),
	]
	host.round_label.text = "回合 %d / %d · 总计 %d / 100" % [
		GameState.season_turn,
		GameState.season_length,
		GameState.global_turn,
	]
	host.weather_label.text = "%s · %s · 饥饿 %d/%d" % [
		host._weather_name(GameState.weather_id),
		host._time_name(GameState.time_of_day),
		GameState.hunger,
		GameState.max_hunger,
	]
	host.objective_label.text = "%s ｜ %s" % [
		objective_name,
		objective_progress,
	]

func update_action_ui(host) -> void:
	var phase_name: String = String(host.turn_flow_controller.get_phase_name())
	var current_node: Dictionary = Dictionary(host.board_lookup.get(host.current_node_id, {}))
	var recent_roll: String = "待掷骰" if host.pending_roll.is_empty() else String(host.dice_service.describe_roll(host.pending_roll))
	var selectable_nodes: Array[int] = host._get_selectable_nodes()
	var intro_copy: bool = bool(host._is_casual_intro_phase())
	var route_preview: String = String(host._format_route_choice_preview(selectable_nodes, intro_copy and host.branch_choice_pending))
	host.dice_label.text = "步数：%s" % recent_roll
	host.dice_meta_label.tooltip_text = "Turn phase: %s" % phase_name
	host.dice_meta_label.text = "修正 %d ｜ 重掷 %d/%d ｜ 锚定 %d" % [
		GameState.season_adjust_points,
		GameState.weekly_reroll_count,
		GameState.weekly_reroll_limit,
		GameState.anchor_points,
	]
	host.board_status_label.text = "区域：%s ｜ 当前位置：%s ｜ 阶段：%s" % [
		host.board_progression_service.get_region_name(),
		String(current_node.get("name", "营地")),
		phase_name,
	]
	if host.branch_choice_pending:
		host.board_route_label.text = "分叉 %d 选 ｜ %s" % [
			selectable_nodes.size(),
			route_preview if not route_preview.is_empty() else "等待方向列表",
		]
	elif host.awaiting_destination:
		host.board_route_label.text = "可达 %d 处 ｜ %s" % [
			selectable_nodes.size(),
			route_preview if not route_preview.is_empty() else "等待路线计算",
		]
	else:
		host.board_route_label.text = "先歇一会 ｜ 今日 %s · %s" % [host._weather_name(GameState.weather_id), host._time_name(GameState.time_of_day)]
	host.roll_button.text = "掷骰"
	host.support_button.text = "背包"
	host.base_button.text = "营地"
	host.new_game_button.text = "主菜单"
	host.roll_button.disabled = host.season_finished or host._is_modal_open() or host.awaiting_destination or host.branch_choice_pending
	host.plus_button.disabled = host.season_finished or host.pending_roll.is_empty() or not host.awaiting_destination or GameState.season_adjust_points <= 0 or int(host.pending_roll.get("value", 0)) >= 6
	host.minus_button.disabled = host.season_finished or host.pending_roll.is_empty() or not host.awaiting_destination or GameState.season_adjust_points <= 0 or int(host.pending_roll.get("value", 0)) <= 1
	host.reroll_button.disabled = host.season_finished or host.pending_roll.is_empty() or not host.awaiting_destination or GameState.weekly_reroll_count >= GameState.weekly_reroll_limit
	host.support_button.disabled = host._is_modal_open() and not host.system_panel.visible
	host.base_button.disabled = host._is_modal_open() and not host.base_panel.visible
	host.new_game_button.disabled = host.ai_turn_in_progress or host.battle_panel.visible or host.decision_panel.visible or host.base_panel.visible or host.system_panel.visible or (is_instance_valid(host.cutscene_panel) and host.cutscene_panel.visible)
	if host.season_finished:
		if host.action_hint_label.text.strip_edges().is_empty():
			host.action_hint_label.text = "[b]这一年先告一段落[/b]\n回到上面看看这一年的收获，也能顺手开始下一段日子。"
		return
	if host.ai_turn_in_progress:
		host.action_hint_label.text = "[b]对手回合[/b]\n%s" % (host._active_ai_observation_line if not host._active_ai_observation_line.is_empty() else "正在结算其他远征队的掷骰、推进和落点。")
		return
	if host.branch_choice_pending:
		if intro_copy:
			host.action_hint_label.text = "[b]来到分叉口了[/b]\n这一步只选方向：%s。选完后会继续走完剩余步数。" % (route_preview if not route_preview.is_empty() else "稳着推进 / 补给打听 / 冒险深入")
		else:
			host.action_hint_label.text = "[b]来到分叉口了[/b]\n先决定接下来走哪边，剩余步数会继续自动结算。"
	elif host.awaiting_destination:
		if intro_copy:
			host.action_hint_label.text = "[b]确认这次步数[/b]\n确认后会自动前进，只有真的遇到分叉才会停下来让你选。"
		else:
			host.action_hint_label.text = "[b]确认这次步数[/b]\n确认后按路线逐步前进，不直接选终点；遇到岔路再做决定。"
	else:
		if intro_copy:
			host.action_hint_label.text = "[b]先掷骰前进[/b]\n走到岔路时再选方向；先熟悉移动和落点，其他信息会逐步展开。"
		else:
			host.action_hint_label.text = "[b]先掷骰前进[/b]\n确认步数后会沿路前进；只有遇到岔路，才需要你决定方向。"
	if GameState.is_hunger_low() and not host.season_finished and not host.ai_turn_in_progress:
		host.action_hint_label.text = "[b]需要补给了[/b]\n路过营地会顺手恢复一点；缺什么资源，直接打开背包查看。"

func update_summaries(host) -> void:
	var synergy_report: Dictionary = host.synergy_service.build_synergy_report()
	var facility_bonus: Dictionary = host.synergy_service.build_facility_bonus()
	var npc_lines: Array[String] = host.npc_route_service.build_status_lines(2)
	var threat_lines: Array[String] = host.threat_service.build_status_lines(host.board_lookup, 2)
	var treasury: Dictionary = GameState.get_treasury_snapshot()
	var ai_entries: Array = host.ai_player_service.build_summary_entries(host.board_lookup)
	host.player_summary_label.text = "\n".join([
		"眼下走到 Lv%d ｜ 照料 %d" % [GameState.get_progression_rank(), GameState.get_care_progress()],
		"徽章 %d ｜ 这季走开的节点 %d ｜ 探索点 %d" % [GameState.badge_count, GameState.season_points, GameState.exploration_points_total],
		"资金 %d 金 ｜ 银行 %d 金" % [int(treasury.get("wallet_gold", 0)), int(treasury.get("bank_gold", 0))],
		"饥饿 %d / %d ｜ 资源和补给翻背包页 / 小本" % [GameState.hunger, GameState.max_hunger],
	])
	GameState.set_trait_runtime_bonus(host.synergy_service.build_runtime_bonus(synergy_report))
	var season_goal: String = String(GameState.get_current_season_rule().get("season_goal", "维持推进感。"))
	var lead_entry: Dictionary = Dictionary(ai_entries[0]) if not ai_entries.is_empty() else {}
	var rival_lines: Array[String] = [
		"区域：%s" % host.board_progression_service.get_region_name(),
		"赛季目标：%s" % season_goal,
	]
	if not lead_entry.is_empty():
		rival_lines.append("领先对手：%s ｜ 威望 %d ｜ 控制 %d" % [
			String(lead_entry.get("name", "对手")),
			int(lead_entry.get("prestige", 0)),
			int(lead_entry.get("control", 0)),
		])
		rival_lines.append("下一拍：%s" % String(lead_entry.get("intent", "继续观察")))
	else:
		rival_lines.append("暂时没有高压对手情报。")
		rival_lines.append("今天更适合稳步推进周目标。")
	host.ai_summary_label.text = "\n".join(rival_lines)
	var active_synergies: Array[String] = host.synergy_service.format_active_lines(synergy_report, 2)
	var control_lines: Array[String] = [
		"双打：%s" % " / ".join(host._battle_slot_names()),
		"宠物栏：%d / %d ｜ 伙伴总数 %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity, GameState.get_companions().size()],
		"访客：%s" % (" / ".join(npc_lines) if not npc_lines.is_empty() else "暂无重点访客"),
		"威胁：%s" % (" / ".join(threat_lines) if not threat_lines.is_empty() else "暂无游走威胁"),
	]
	if not active_synergies.is_empty():
		control_lines.append("已激活：%s" % " / ".join(active_synergies))
	elif not Array(facility_bonus.get("lines", [])).is_empty():
		control_lines.append("建筑增益：%s" % " / ".join(Array(facility_bonus.get("lines", [])).slice(0, 1)))
	host.control_summary_label.text = "\n".join(control_lines.slice(0, 5))
	host._handle_synergy_activation_fx(synergy_report)

func update_roster(host) -> void:
	var lines: Array[String] = []
	lines.append("出战位：%s" % " / ".join(host._battle_slot_names()))
	lines.append("眼下还能照看几只伙伴：%d / %d ｜ 已安居据点 %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity, GameState.get_settled_habitat_count()])
	lines.append("生存：饥饿 %d / %d ｜ 资源和补给翻背包页 / 小本" % [GameState.hunger, GameState.max_hunger])
	if not host.starter_companion_uid.is_empty():
		lines.append("起始伙伴：%s" % GameState.get_pet_display_name(host.starter_companion_uid))
	else:
		lines.append("调双打 / 背包 / 驻守：路过营地打开营地总览。")
	host.roster_label.text = "\n".join(lines)

func update_log(host) -> void:
	var entries: Array[String] = GameState.journal_entries.duplicate()
	var visible_entries: Array[String] = entries.slice(maxi(0, entries.size() - host.CASUAL_INTRO_VISIBLE_LOG_ENTRIES), entries.size())
	if visible_entries.is_empty():
		host._render_event_log_text("等待新的记录…")
		host._event_log_snapshot = []
		return
	if host._should_render_event_log_immediately(visible_entries):
		host._render_event_log_text("\n".join(visible_entries))
		host._event_log_snapshot = visible_entries
		return
	var history_entries: Array[String] = visible_entries.slice(0, visible_entries.size() - 1)
	var full_text: String = "\n".join(visible_entries)
	var history_text: String = "\n".join(history_entries)
	var visible_count: int = history_text.length()
	if not history_text.is_empty():
		visible_count += 1
	host._stop_event_log_typewriter(false)
	host.event_log_label.text = full_text
	host.event_log_label.visible_characters = visible_count
	host.event_log_label.scroll_to_line(host.event_log_label.get_line_count())
	host._event_log_snapshot = visible_entries
	var newest_entry: String = String(visible_entries[visible_entries.size() - 1])
	var duration: float = clampf(float(newest_entry.length()) * host.EVENT_LOG_TYPEWRITER_SPEED, host.EVENT_LOG_TYPEWRITER_MIN_DURATION, host.EVENT_LOG_TYPEWRITER_MAX_DURATION)
	host._event_log_typewriter_tween = host.create_tween()
	host._event_log_typewriter_tween.set_trans(Tween.TRANS_LINEAR)
	host._event_log_typewriter_tween.set_ease(Tween.EASE_OUT)
	host._event_log_typewriter_tween.tween_property(host.event_log_label, "visible_characters", full_text.length(), duration)
	host._event_log_typewriter_tween.finished.connect(host._on_event_log_typewriter_finished)

func update_map_hint(host) -> void:
	host._update_node_detail_preview()
	var npc_markers: Dictionary = host.npc_route_service.build_node_markers()
	var threat_markers: Dictionary = host.threat_service.build_node_markers()
	var ai_markers: Dictionary = host.ai_player_service.build_node_markers()
	var threat_forecast_lines: Array[String] = host._build_threat_forecast_preview_lines(2, 4)
	if host.branch_choice_pending:
		var lines: Array[String] = ["[b]当前分叉方向[/b]"]
		for node_id in host.pending_route_options.slice(0, 4):
			var node: Dictionary = host.board_lookup[node_id]
			lines.append("%s [%s]" % [
				String(node.get("name", "未知节点")),
				host._type_name(String(node.get("type", ""))),
			])
			lines.append("  下一步：%s" % host._format_path_preview([host.current_node_id, node_id]))
		host.map_hint_label.text = "\n".join(lines)
		return
	if host.awaiting_destination:
		var lines: Array[String] = ["[b]可达节点[/b]"]
		for node_id in host._filter_blocked_selectable_nodes(host._reachable_selectable_nodes()).slice(0, 4):
			var node: Dictionary = host.board_lookup[node_id]
			var tags: Array[String] = [String(node.get("reward_hint", "查看详情"))]
			if host.board_map_effect_service.has_pending_effect(node, node_id, GameState.board_region_id):
				tags.append("效果 %s" % host.board_map_effect_service.preview_title(node))
			if GameState.get_node_danger(node_id) > 0:
				tags.append("危险 %d" % GameState.get_node_danger(node_id))
			if npc_markers.has(node_id):
				tags.append("访客 %s" % " / ".join(npc_markers.get(node_id, [])))
			if threat_markers.has(node_id):
				tags.append("敌群 %s" % " / ".join(threat_markers.get(node_id, [])))
			if ai_markers.has(node_id):
				tags.append("对手 %s" % " / ".join(ai_markers.get(node_id, [])))
			lines.append("%s [%s]" % [
				node["name"],
				host._type_name(String(node.get("type", ""))),
			])
			lines.append("  %s" % " ｜ ".join(tags.slice(0, 3)))
			lines.append("  路径：%s" % host._format_path_preview(host.reachable_paths.get(node_id, [])))
		if host._get_blocked_reachable_nodes().size() > 0:
			lines.append("")
			lines.append("[b]阻塞[/b] %d 个候选点被敌对群占据" % host._get_blocked_reachable_nodes().size())
		var projected_blocked: Array[int] = host.threat_service.get_projected_blocked_node_ids(1)
		if not projected_blocked.is_empty():
			lines.append("[b]下回合封锁[/b] %s" % host._format_node_name_list(projected_blocked))
		var risk_nodes: Array[int] = host.threat_service.get_high_risk_node_ids(2)
		if not risk_nodes.is_empty():
			lines.append("[b]两回合高压[/b] %s" % host._format_node_name_list(risk_nodes.slice(0, 4)))
		if not threat_forecast_lines.is_empty():
			lines.append("")
			lines.append("[b]威胁预告[/b]")
			lines.append_array(threat_forecast_lines)
		if host._get_locked_nodes().size() > 0:
			lines.append("[b]未开放[/b] %d 个区域待解锁" % host._get_locked_nodes().size())
		host.map_hint_label.text = "\n".join(lines)
		return
	var body: String = "[b]今日焦点[/b]\n%s\n\n[b]周目标[/b]\n%s\n\n[b]地图动向[/b]\n对手：%s\n访客：%s\n威胁：%s" % [
		host._today_focus_text(),
		host.weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress),
		" / ".join(host.ai_player_service.build_status_lines(host.board_lookup, 2)),
		" / ".join(host.npc_route_service.build_status_lines(2)),
		" / ".join(host.threat_service.build_status_lines(host.board_lookup, 2)),
	]
	if not threat_forecast_lines.is_empty():
		body += "\n\n[b]威胁预告[/b]\n%s" % "\n".join(threat_forecast_lines)
	host.map_hint_label.text = body

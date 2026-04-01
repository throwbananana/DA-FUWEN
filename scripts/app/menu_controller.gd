class_name MenuController
extends RefCounted

func show_main_menu(host) -> void:
	CustomAssetRepository.sync_external_library()
	host._refresh_custom_asset_bindings()
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id()
	refresh_main_menu(host)
	host.root_margin.hide()
	if is_instance_valid(host._menu_custom_background):
		host._menu_custom_background.visible = host._menu_custom_background.texture != null
	if is_instance_valid(host._menu_logo_rect):
		host._menu_logo_rect.visible = host._menu_logo_rect.texture != null
	if is_instance_valid(host.save_slot_panel):
		host.save_slot_panel.close_panel()
	host.menu_backdrop.show()
	host._sync_menu_backdrop_shader()
	host.menu_backdrop.move_to_front()
	host.main_menu_panel.show()
	host.main_menu_panel.move_to_front()
	host._sync_menu_bgm()
	focus_main_menu_primary_button(host)

func hide_main_menu(host) -> void:
	if is_instance_valid(host._menu_custom_background):
		host._menu_custom_background.hide()
	if is_instance_valid(host._menu_logo_rect):
		host._menu_logo_rect.hide()
	if is_instance_valid(host._menu_bgm_player):
		host._menu_bgm_player.stop()
	if is_instance_valid(host.save_slot_panel):
		host.save_slot_panel.close_panel()
	if is_instance_valid(host.input_settings_panel):
		host.input_settings_panel.hide()
	host.menu_backdrop.hide()
	host.main_menu_panel.hide()
	host.root_margin.show()
	host._update_ui()
	host._resume_onboarding_flow()
	host.story_director.try_flush_pending_quest_story_beats()

func refresh_main_menu(host) -> void:
	var slot_meta := GameState.get_run_slot_meta(host._menu_selected_slot_id)
	var slot_has_save := bool(slot_meta.get("exists", false))
	var meta_hint: String = String(host._current_meta_bonus_compact_hint())
	host.menu_title_label.text = host.localization_service.text("menu.title")
	if host.runtime_session_started:
		host.menu_subtitle_label.text = host.localization_service.text("menu.subtitle.runtime")
		host.continue_button.text = host.localization_service.text("menu.continue.season_end") if host.season_finished else host.localization_service.text("menu.continue.run")
		host.menu_new_game_button.text = "存档槽位"
		host.menu_new_game_button.disabled = false
		host.menu_action_hint_label.text = "当前槽位：%s\n继续当前旅程，或切换到别的存档槽位。" % slot_title(slot_meta)
		if not meta_hint.is_empty():
			host.menu_action_hint_label.text += "\n" + meta_hint
		host.menu_run_summary_label.text = host._build_main_menu_run_summary()
	else:
		host.menu_subtitle_label.text = host.localization_service.text("menu.subtitle.start")
		host.continue_button.text = "继续这格存档" if slot_has_save else host.localization_service.text("menu.start_game")
		host.menu_new_game_button.text = "存档槽位"
		host.menu_new_game_button.disabled = false
		host.menu_action_hint_label.text = "当前槽位：%s\n点“继续”会读取这格存档；如果还是空的，就会直接从这里开始新远征。" % slot_title(slot_meta)
		if not meta_hint.is_empty():
			host.menu_action_hint_label.text += "\n" + meta_hint
		host.menu_run_summary_label.text = build_saved_run_summary(host)
	host.settings_button.text = host.localization_service.text("menu.settings")
	host.menu_meta_summary_label.text = "%s\n\n%s" % [host._build_main_menu_meta_summary(), build_settings_summary(host)]
	refresh_main_menu_visuals(host)

func focus_main_menu_primary_button(host) -> void:
	if not host.main_menu_panel.visible:
		return
	for button in [host.continue_button, host.menu_new_game_button, host.settings_button]:
		button.focus_mode = Control.FOCUS_ALL
	host.continue_button.focus_neighbor_bottom = host.menu_new_game_button.get_path()
	host.menu_new_game_button.focus_neighbor_top = host.continue_button.get_path()
	host.menu_new_game_button.focus_neighbor_bottom = host.settings_button.get_path()
	host.settings_button.focus_neighbor_top = host.menu_new_game_button.get_path()
	if not host.continue_button.disabled:
		host.continue_button.grab_focus()
	elif not host.menu_new_game_button.disabled:
		host.menu_new_game_button.grab_focus()
	else:
		host.settings_button.grab_focus()

func build_saved_run_summary(host) -> String:
	var slot_meta := GameState.get_run_slot_meta(host._menu_selected_slot_id)
	if slot_meta.is_empty() or not bool(slot_meta.get("exists", false)):
		return "[b]%s[/b]\n这个槽位还没有存档。按“继续”会直接在这里开始一局新的远征。" % slot_title(slot_meta)
	var summary: Dictionary = slot_meta.get("summary", {})
	if summary.is_empty():
		return "[b]%s[/b]\n这个槽位里有旧版本存档，但还没有可展示的摘要。" % slot_title(slot_meta)
	var battle_slots: Array[String] = []
	for entry in summary.get("battle_slots", []):
		battle_slots.append(String(entry))
	if battle_slots.is_empty():
		battle_slots.append(host.localization_service.text("menu.summary.unassigned"))
	var lines: Array[String] = [
		"[b]%s[/b]" % slot_title(slot_meta),
		"%s · 第 %d / %d 回合 · 第 %d 周 · 总回合 %d / 100" % [
			String(summary.get("season_name", "未知季节")),
			int(summary.get("season_turn", 1)),
			int(summary.get("season_length", 1)),
			int(summary.get("week_index", 1)),
			int(summary.get("global_turn", 1)),
		],
		host.localization_service.text("menu.summary.position", {"node": String(summary.get("node_name", host.localization_service.text("menu.summary.camp")))}),
		host.localization_service.text("menu.summary.battle_slots", {"value": " / ".join(battle_slots)}),
		host.localization_service.text("menu.summary.weekly_objective", {"value": String(summary.get("objective_summary", host.localization_service.text("menu.summary.no_objective")))}),
	]
	return "\n".join(lines)

func slot_title(slot_meta: Dictionary) -> String:
	if slot_meta.is_empty():
		return "存档 1"
	return String(slot_meta.get("title", slot_meta.get("id", "存档")))

func build_settings_summary(host) -> String:
	var window_mode: String = String(host.localization_service.text("settings.window.fullscreen") if bool(GameState.settings.get("fullscreen", false)) else host.localization_service.text("settings.window.windowed"))
	var resolution_label := GameState.current_window_resolution_label()
	var motion_mode: String = String(host.localization_service.text("settings.motion.reduced") if GameState.prefers_reduced_motion() else host.localization_service.text("settings.motion.standard"))
	var tutorial_mode: String = String(host.localization_service.text("settings.tutorials.on") if GameState.tutorials_enabled() else host.localization_service.text("settings.tutorials.off"))
	var language_name: String = String(host.localization_service.language_name(GameState.current_language()))
	var accept_binding := settings_binding_label(host, "ui_accept")
	var cancel_binding := settings_binding_label(host, "ui_cancel")
	var roll_binding := settings_binding_label(host, "game_roll")
	var menu_binding := settings_binding_label(host, "game_menu")
	return "\n".join([
		host.localization_service.text("settings.summary.title"),
		host.localization_service.text("settings.summary.window", {"value": window_mode}),
		host.localization_service.text("settings.summary.resolution", {"value": resolution_label}),
		host.localization_service.text("settings.summary.motion", {"value": motion_mode}),
		host.localization_service.text("settings.summary.tutorials", {"value": tutorial_mode}),
		host.localization_service.text("settings.summary.language", {"value": language_name}),
		host.localization_service.text("settings.summary.controls", {
			"accept": accept_binding,
			"cancel": cancel_binding,
			"roll": roll_binding,
			"menu": menu_binding,
		}),
		"自己收进来的素材：%d 项 ｜ 图片 %d 张" % [CustomAssetRepository.get_asset_count(), CustomAssetRepository.get_image_count()],
		"窗口图标：%s" % custom_asset_slot_label("app_icon"),
		"主菜单背景：%s" % custom_asset_slot_label("main_menu_bg"),
		"主菜单 Logo：%s" % custom_asset_slot_label("main_menu_logo"),
		"主菜单音乐：%s" % custom_asset_slot_label("main_menu_bgm"),
		"战斗音乐：%s" % custom_asset_slot_label("battle_bgm"),
		"确认音效：%s" % custom_asset_slot_label("ui_confirm_sfx"),
		"界面字体：%s" % custom_asset_slot_label("ui_font"),
		"界面样式配置：%s" % custom_asset_slot_label("ui_style_config"),
	])

func settings_binding_label(host, action_name: String) -> String:
	var labels: Array[String] = []
	for slot_index in range(2):
		var label := InputManager.describe_binding_slot(action_name, slot_index)
		if label.is_empty():
			continue
		labels.append(label)
	if labels.is_empty():
		return host.localization_service.text("settings.input.empty")
	return " / ".join(labels)

func custom_asset_slot_label(slot_id: String) -> String:
	var asset_id := CustomAssetRepository.get_slot_binding(slot_id)
	if asset_id.is_empty():
		return "默认"
	var asset_info := CustomAssetRepository.get_asset(asset_id)
	if asset_info.is_empty():
		return "默认"
	return String(asset_info.get("label", asset_id))

func open_save_slot_panel(host, mode: String) -> void:
	if not is_instance_valid(host.save_slot_panel):
		return
	host._save_slot_panel_mode = mode
	refresh_save_slot_panel(host)
	host.save_slot_panel.show()
	host.save_slot_panel.move_to_front()

func refresh_save_slot_panel(host, mode: String = "") -> void:
	if not is_instance_valid(host.save_slot_panel):
		return
	if not mode.is_empty():
		host._save_slot_panel_mode = mode
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id() if host._menu_selected_slot_id.is_empty() else host._menu_selected_slot_id
	host.save_slot_panel.open_panel(GameState.list_run_slots(), host._menu_selected_slot_id, host._save_slot_panel_mode)

func on_save_slot_selected(host, slot_id: String) -> void:
	host._menu_selected_slot_id = slot_id
	GameState.set_selected_run_slot_id(slot_id)
	if host.main_menu_panel.visible:
		refresh_main_menu(host)
	if is_instance_valid(host.save_slot_panel) and host.save_slot_panel.visible:
		refresh_save_slot_panel(host)

func on_save_slot_load_requested(host, slot_id: String) -> void:
	host._load_run_state_from_save(slot_id)

func on_save_slot_new_requested(host, slot_id: String) -> void:
	start_new_game_in_slot(host, slot_id)

func on_save_slot_save_requested(host, slot_id: String) -> void:
	if not host.runtime_session_started:
		return
	GameState.set_selected_run_slot_id(slot_id)
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id()
	GameState.save_run_payload(host._build_run_save_payload(), host._menu_selected_slot_id)
	if is_instance_valid(host.save_slot_panel):
		host.save_slot_panel.close_panel()
	if host.main_menu_panel.visible:
		refresh_main_menu(host)
	host._push_log("已保存到 %s。" % slot_title(GameState.get_run_slot_meta(host._menu_selected_slot_id)))

func on_save_slot_delete_requested(host, slot_id: String) -> void:
	if host.runtime_session_started and not host.season_finished and slot_id == GameState.get_selected_run_slot_id():
		host.decision_panel.open_panel("无法删除当前运行槽位", "当前这局正在使用这个槽位。请先另存到别的槽位，或回到标题后再删。", [], "知道了")
		return
	GameState.clear_run_save(slot_id)
	if host.main_menu_panel.visible:
		refresh_main_menu(host)
	if is_instance_valid(host.save_slot_panel) and host.save_slot_panel.visible:
		refresh_save_slot_panel(host)

func on_save_slot_closed(host) -> void:
	if is_instance_valid(host.save_slot_panel):
		host.save_slot_panel.close_panel()
	if host.main_menu_panel.visible:
		refresh_main_menu(host)
		focus_main_menu_primary_button(host)
	else:
		host._update_ui()
	host.story_director.try_flush_pending_quest_story_beats()

func start_new_game_in_slot(host, slot_id: String) -> void:
	GameState.set_selected_run_slot_id(slot_id)
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id()
	host.start_new_game()
	host._save_run_state()
	hide_main_menu(host)

func open_settings_menu(host) -> void:
	CustomAssetRepository.sync_external_library()
	host._refresh_custom_asset_bindings()
	var window_label: String = String(host.localization_service.text("settings.window.to_windowed") if bool(GameState.settings.get("fullscreen", false)) else host.localization_service.text("settings.window.to_fullscreen"))
	var motion_label: String = String(host.localization_service.text("settings.motion.to_standard") if GameState.prefers_reduced_motion() else host.localization_service.text("settings.motion.to_reduced"))
	var tutorial_label: String = String(host.localization_service.text("settings.tutorials.enable") if not GameState.tutorials_enabled() else host.localization_service.text("settings.tutorials.disable"))
	var imported_count := CustomAssetRepository.get_image_count()
	var imported_audio_count := CustomAssetRepository.get_asset_count("audio")
	var imported_font_count := CustomAssetRepository.get_asset_count("font")
	var imported_file_count := CustomAssetRepository.get_asset_count("file")
	var resolution_choices: Array = []
	for preset in GameState.get_available_window_resolution_presets():
		var resolution_id := String(preset.get("id", ""))
		var resolution_label := String(preset.get("label", resolution_id))
		resolution_choices.append({
			"id": "set_window_resolution:%s" % resolution_id,
			"label": host.localization_service.text("settings.resolution.set", {"value": resolution_label}),
			"summary": host.localization_service.text("settings.current", {"value": resolution_label}),
			"disabled": resolution_id == GameState.current_window_resolution_id(),
		})
	var choices := [
		{
			"id": "toggle_fullscreen",
			"label": window_label,
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.text("settings.window.fullscreen") if bool(GameState.settings.get("fullscreen", false)) else host.localization_service.text("settings.window.windowed")}),
		},
	] + resolution_choices + [
		{
			"id": "toggle_motion",
			"label": motion_label,
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.text("settings.motion.reduced") if GameState.prefers_reduced_motion() else host.localization_service.text("settings.motion.standard")}),
		},
		{
			"id": "toggle_tutorials",
			"label": tutorial_label,
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.text("settings.tutorials.on") if GameState.tutorials_enabled() else host.localization_service.text("settings.tutorials.off")}),
		},
		{
			"id": "set_language_zh_cn",
			"label": host.localization_service.text("settings.language.zh_cn"),
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.language_name("zh_cn")}),
		},
		{
			"id": "set_language_ja_jp",
			"label": host.localization_service.text("settings.language.ja_jp"),
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.language_name("ja_jp")}),
		},
		{
			"id": "set_language_en_us",
			"label": host.localization_service.text("settings.language.en_us"),
			"summary": host.localization_service.text("settings.current", {"value": host.localization_service.language_name("en_us")}),
		},
		{
			"id": "open_input_settings",
			"label": host.localization_service.text("settings.input.open"),
			"summary": host.localization_service.text("settings.input.summary"),
		},
		{
			"id": "open_custom_asset_import",
			"label": "导入自定义素材",
			"summary": "把本地的图片、声音、字体这些收进来，慢慢换成你想要的样子。",
		},
		{
			"id": "select_app_icon",
			"label": "选择窗口图标",
			"summary": "当前：%s ｜ 已导入 %d 张" % [custom_asset_slot_label("app_icon"), imported_count],
			"disabled": imported_count <= 0,
		},
		{
			"id": "clear_app_icon",
			"label": "恢复默认窗口图标",
			"summary": "把窗口图标换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("app_icon").is_empty(),
		},
		{
			"id": "select_main_menu_bg",
			"label": "选择主菜单背景",
			"summary": "当前：%s ｜ 已导入 %d 张" % [custom_asset_slot_label("main_menu_bg"), imported_count],
			"disabled": imported_count <= 0,
		},
		{
			"id": "clear_main_menu_bg",
			"label": "恢复默认背景",
			"summary": "把主菜单背景换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("main_menu_bg").is_empty(),
		},
		{
			"id": "select_main_menu_logo",
			"label": "选择主菜单 Logo",
			"summary": "当前：%s ｜ 已导入 %d 张" % [custom_asset_slot_label("main_menu_logo"), imported_count],
			"disabled": imported_count <= 0,
		},
		{
			"id": "clear_main_menu_logo",
			"label": "恢复默认 Logo",
			"summary": "把主菜单名字换回原来的字样。",
			"disabled": CustomAssetRepository.get_slot_binding("main_menu_logo").is_empty(),
		},
		{
			"id": "select_main_menu_bgm",
			"label": "选择主菜单音乐",
			"summary": "当前：%s ｜ 已导入 %d 条音频" % [custom_asset_slot_label("main_menu_bgm"), imported_audio_count],
			"disabled": imported_audio_count <= 0,
		},
		{
			"id": "clear_main_menu_bgm",
			"label": "恢复默认音乐",
			"summary": "把主菜单的声音换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("main_menu_bgm").is_empty(),
		},
		{
			"id": "select_battle_bgm",
			"label": "选择战斗音乐",
			"summary": "当前：%s ｜ 已导入 %d 条音频" % [custom_asset_slot_label("battle_bgm"), imported_audio_count],
			"disabled": imported_audio_count <= 0,
		},
		{
			"id": "clear_battle_bgm",
			"label": "恢复默认战斗音乐",
			"summary": "把战斗时听见的声音换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("battle_bgm").is_empty(),
		},
		{
			"id": "select_ui_confirm_sfx",
			"label": "选择确认音效",
			"summary": "当前：%s ｜ 已导入 %d 条音频" % [custom_asset_slot_label("ui_confirm_sfx"), imported_audio_count],
			"disabled": imported_audio_count <= 0,
		},
		{
			"id": "clear_ui_confirm_sfx",
			"label": "恢复默认确认音效",
			"summary": "把确认时的声音换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("ui_confirm_sfx").is_empty(),
		},
		{
			"id": "select_ui_font",
			"label": "选择界面字体",
			"summary": "当前：%s ｜ 已导入 %d 个字体" % [custom_asset_slot_label("ui_font"), imported_font_count],
			"disabled": imported_font_count <= 0,
		},
		{
			"id": "clear_ui_font",
			"label": "恢复默认字体",
			"summary": "把字换回原来的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("ui_font").is_empty(),
		},
		{
			"id": "select_ui_style_config",
			"label": "选择界面样式配置",
			"summary": "当前：%s ｜ 已导入 %d 个 JSON 文件" % [custom_asset_slot_label("ui_style_config"), imported_file_count],
			"disabled": imported_file_count <= 0,
		},
		{
			"id": "clear_ui_style_config",
			"label": "恢复默认界面样式",
			"summary": "把界面换回原本的样子。",
			"disabled": CustomAssetRepository.get_slot_binding("ui_style_config").is_empty(),
		},
	]
	host.pending_context = {"kind": "menu_settings"}
	host.decision_panel.open_panel(host.localization_service.text("settings.title"), host.localization_service.text("settings.body"), choices, host.localization_service.text("settings.back"))

func apply_menu_setting(host, choice_id: String) -> void:
	var reopen_settings := true
	match choice_id:
		"toggle_fullscreen":
			GameState.set_setting("fullscreen", not bool(GameState.settings.get("fullscreen", false)))
		"toggle_motion":
			GameState.set_setting("reduced_motion", not GameState.prefers_reduced_motion())
		"toggle_tutorials":
			GameState.set_setting("tutorials_enabled", not GameState.tutorials_enabled())
		"set_language_zh_cn":
			GameState.set_setting("language", "zh_cn")
		"set_language_ja_jp":
			GameState.set_setting("language", "ja_jp")
		"set_language_en_us":
			GameState.set_setting("language", "en_us")
		"open_input_settings":
			reopen_settings = false
			open_input_settings_panel(host)
		"open_custom_asset_import":
			reopen_settings = false
			open_asset_import_dialog(host)
		"select_app_icon":
			reopen_settings = false
			host._open_custom_asset_slot_picker("app_icon")
		"clear_app_icon":
			reopen_settings = false
			host._clear_custom_asset_slot("app_icon")
		"select_main_menu_bg":
			reopen_settings = false
			host._open_custom_asset_slot_picker("main_menu_bg")
		"clear_main_menu_bg":
			reopen_settings = false
			host._clear_custom_asset_slot("main_menu_bg")
		"select_main_menu_logo":
			reopen_settings = false
			host._open_custom_asset_slot_picker("main_menu_logo")
		"clear_main_menu_logo":
			reopen_settings = false
			host._clear_custom_asset_slot("main_menu_logo")
		"select_main_menu_bgm":
			reopen_settings = false
			host._open_custom_asset_slot_picker("main_menu_bgm")
		"clear_main_menu_bgm":
			reopen_settings = false
			host._clear_custom_asset_slot("main_menu_bgm")
		"select_battle_bgm":
			reopen_settings = false
			host._open_custom_asset_slot_picker("battle_bgm")
		"clear_battle_bgm":
			reopen_settings = false
			host._clear_custom_asset_slot("battle_bgm")
		"select_ui_confirm_sfx":
			reopen_settings = false
			host._open_custom_asset_slot_picker("ui_confirm_sfx")
		"clear_ui_confirm_sfx":
			reopen_settings = false
			host._clear_custom_asset_slot("ui_confirm_sfx")
		"select_ui_font":
			reopen_settings = false
			host._open_custom_asset_slot_picker("ui_font")
		"clear_ui_font":
			reopen_settings = false
			host._clear_custom_asset_slot("ui_font")
		"select_ui_style_config":
			reopen_settings = false
			host._open_custom_asset_slot_picker("ui_style_config")
		"clear_ui_style_config":
			reopen_settings = false
			host._clear_custom_asset_slot("ui_style_config")
		_:
			if choice_id.begins_with("set_window_resolution:"):
				var resolution_id := choice_id.substr("set_window_resolution:".length())
				if GameState.is_valid_window_resolution_id(resolution_id):
					GameState.set_setting("window_resolution", resolution_id)
			else:
				return
	refresh_main_menu(host)
	if reopen_settings:
		open_settings_menu(host)

func open_input_settings_panel(host) -> void:
	if not is_instance_valid(host.input_settings_panel):
		return
	host.input_settings_panel.open_panel()

func on_input_settings_panel_closed(host) -> void:
	if host.main_menu_panel.visible:
		refresh_main_menu(host)
		open_settings_menu(host)

func custom_main_menu_background_label() -> String:
	return custom_asset_slot_label("main_menu_bg")

func refresh_main_menu_visuals(host) -> void:
	if not is_instance_valid(host._menu_custom_background):
		return
	var texture := CustomAssetRepository.get_bound_texture("main_menu_bg")
	host._menu_custom_background.texture = texture
	var style_config: Dictionary = Dictionary(host._resolve_custom_ui_style_config())
	var background_config := Dictionary(style_config.get("menu_custom_background", {}))
	host._menu_custom_background.modulate = Color(1, 1, 1, clamp(host._config_float(background_config, "alpha", 0.78), 0.0, 1.0))
	host._menu_custom_background.visible = texture != null and host.main_menu_panel.visible
	host._sync_menu_backdrop_shader()

func open_asset_import_dialog(host) -> void:
	if not is_instance_valid(host._asset_file_dialog):
		return
	host._asset_file_dialog.popup_centered_ratio(0.82)

func on_asset_import_canceled(host) -> void:
	if host.main_menu_panel.visible:
		open_settings_menu(host)

func custom_asset_kind_label(kind: String) -> String:
	return CustomAssetRepository.get_asset_kind_label(kind)

func custom_asset_slot_title(slot_id: String) -> String:
	return CustomAssetRepository.get_slot_label(slot_id)

func custom_asset_slot_picker_empty_text(slot_id: String) -> String:
	match slot_id:
		"app_icon":
			return "先放进来一张图，之后才能把它换成窗口图标。"
		"main_menu_bg":
			return "先放进来一张图，之后才能把它换成主菜单背景。"
		"main_menu_logo":
			return "先放进来一张图，之后才能把它换成主菜单 Logo。"
		"main_menu_bgm":
			return "先放进来一段能播的声音，之后才能换成主菜单音乐。"
		"battle_bgm":
			return "先放进来一段能播的声音，之后才能换成战斗音乐。"
		"ui_confirm_sfx":
			return "先放进来一段能播的声音，之后才能换成确认音效。"
		"ui_font":
			return "先放进来一个字体，之后才能换掉现在这套字。"
		"ui_style_config":
			return "先放进来一份样式文件，之后才能把界面换成新的样子。"
		_:
			return "眼下还没有能用在这里的素材。"

func custom_asset_slot_picker_summary(slot_id: String, assets: Array) -> String:
	match slot_id:
		"app_icon":
			return "已经收进来 %d 张图片。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"main_menu_bg":
			return "已经收进来 %d 张图片。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"main_menu_logo":
			return "已经收进来 %d 张图片。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"main_menu_bgm":
			return "已经收进来 %d 段声音。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"battle_bgm":
			return "已经收进来 %d 段声音。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"ui_confirm_sfx":
			return "已经收进来 %d 段声音。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"ui_font":
			return "已经收进来 %d 套字。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		"ui_style_config":
			return "已经收进来 %d 份样式文件。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]
		_:
			return "已经收进来 %d 个素材。\n现在用的是：%s" % [assets.size(), custom_asset_slot_label(slot_id)]

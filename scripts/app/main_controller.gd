class_name MainController
extends RefCounted

func ready(host) -> void:
	host.rng.randomize()
	var window: Window = host.get_window()
	window.min_size = GameState.minimum_window_size()
	window.size_changed.connect(host._on_window_size_changed)
	host.title_label.text = host.GAME_TITLE
	host.base_button.hide()
	host.plus_button.hide()
	host.minus_button.hide()
	host.reroll_button.hide()
	host.story_director.configure(
		host.story_service,
		host.cutscene_service,
		host.cutscene_panel,
		Callable(host, "_play_dialogue_cutscene"),
		Callable(host, "_is_modal_open"),
		Callable(host, "_should_skip_cutscene_runtime"),
		Callable(host, "_push_log")
	)
	connect_signals(host)
	configure_static_ui_nodes(host)
	host.theme = host.JrpgTheme.build(CustomAssetRepository.get_bound_font("ui_font"))
	host._apply_basic_styles()
	host._prepare_overlay_panels()
	host._configure_safe_ui_bounds()
	host._configure_text_overflow_guards()
	host._queue_responsive_layout()
	ensure_menu_bgm_player(host)
	ensure_battle_bgm_player(host)
	ensure_ui_sfx_player(host)
	configure_asset_import_dialog(host)
	host._queue_responsive_layout()
	refresh_custom_asset_bindings(host)
	install_visit_flow(host)
	install_camp_flow(host)
	GameState.ensure_save_index()
	GameState.migrate_legacy_run_save()
	host._menu_selected_slot_id = GameState.get_selected_run_slot_id()
	if host._should_show_boot_menu():
		host._show_main_menu()
	else:
		host._start_new_game_in_slot(host._menu_selected_slot_id)

func unhandled_input(host, event: InputEvent) -> void:
	if is_instance_valid(host.input_settings_panel) and host.input_settings_panel.visible:
		return
	if host.main_menu_panel.visible and not host.decision_panel.visible and not (is_instance_valid(host.save_slot_panel) and host.save_slot_panel.visible):
		if host.runtime_session_started and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
			host._hide_main_menu()
			host.get_viewport().set_input_as_handled()
		return
	if host._is_modal_open():
		return
	if handle_board_controller_input(host, event):
		host.get_viewport().set_input_as_handled()
		return
	if handle_global_shortcut_input(host, event):
		host.get_viewport().set_input_as_handled()

func handle_board_controller_input(host, event: InputEvent) -> bool:
	if not host.branch_choice_pending or host.board_anim_locked:
		return false
	if event.is_action_pressed("ui_up"):
		return host.board_view.move_controller_cursor(Vector2i.UP)
	if event.is_action_pressed("ui_down"):
		return host.board_view.move_controller_cursor(Vector2i.DOWN)
	if event.is_action_pressed("ui_left"):
		return host.board_view.move_controller_cursor(Vector2i.LEFT)
	if event.is_action_pressed("ui_right"):
		return host.board_view.move_controller_cursor(Vector2i.RIGHT)
	if event.is_action_pressed("ui_accept"):
		host.board_view.activate_controller_cursor()
		return true
	return false

func handle_global_shortcut_input(host, event: InputEvent) -> bool:
	if host.board_anim_locked or host.awaiting_destination or host.branch_choice_pending:
		return false
	if event.is_action_pressed("game_roll") and not host.roll_button.disabled:
		host._on_start_day_pressed()
		return true
	if event.is_action_pressed("game_support") and not host.support_button.disabled:
		host._on_support_pressed()
		return true
	if event.is_action_pressed("game_base") and not host.base_button.disabled:
		host._on_base_pressed()
		return true
	if (event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel")) and not host.new_game_button.disabled:
		host._on_main_menu_requested()
		return true
	return false

func install_visit_flow(host) -> void:
	host.visit_flow = host.VisitFlowController.new()
	host.add_child(host.visit_flow)
	host.visit_flow.state_changed.connect(host._on_visit_state_changed)
	host.visit_flow.visit_finished.connect(host._on_visit_finished)

func install_camp_flow(host) -> void:
	host.camp_flow = host.CampFlowController.new()
	host.add_child(host.camp_flow)
	host.camp_flow.state_changed.connect(host._on_camp_flow_state_changed)

func connect_signals(host) -> void:
	host.roll_button.pressed.connect(host._on_start_day_pressed)
	host.roll_button.pressed.connect(host._play_ui_confirm_sfx)
	host.plus_button.pressed.connect(host._on_plus_pressed)
	host.plus_button.pressed.connect(host._play_ui_confirm_sfx)
	host.minus_button.pressed.connect(host._on_minus_pressed)
	host.minus_button.pressed.connect(host._play_ui_confirm_sfx)
	host.reroll_button.pressed.connect(host._on_reroll_pressed)
	host.reroll_button.pressed.connect(host._play_ui_confirm_sfx)
	host.support_button.pressed.connect(host._on_support_pressed)
	host.support_button.pressed.connect(host._play_ui_confirm_sfx)
	host.base_button.pressed.connect(host._on_base_pressed)
	host.base_button.pressed.connect(host._play_ui_confirm_sfx)
	host.new_game_button.pressed.connect(host._on_main_menu_requested)
	host.new_game_button.pressed.connect(host._play_ui_confirm_sfx)
	host.continue_button.pressed.connect(host._on_continue_pressed)
	host.continue_button.pressed.connect(host._play_ui_confirm_sfx)
	host.menu_new_game_button.pressed.connect(host._on_menu_new_game_pressed)
	host.menu_new_game_button.pressed.connect(host._play_ui_confirm_sfx)
	host.settings_button.pressed.connect(host._on_settings_pressed)
	host.settings_button.pressed.connect(host._play_ui_confirm_sfx)
	host.dice_roll_panel.confirmed.connect(host._on_dice_roll_confirmed)
	host.dice_roll_panel.confirmed.connect(host._play_ui_confirm_sfx)
	host.dice_roll_panel.closed.connect(host._on_dice_roll_panel_closed)
	host.dice_roll_panel.plus_requested.connect(host._on_dice_roll_plus_requested)
	host.dice_roll_panel.minus_requested.connect(host._on_dice_roll_minus_requested)
	host.dice_roll_panel.reroll_requested.connect(host._on_dice_roll_reroll_requested)
	host.board_view.node_chosen.connect(host._on_board_node_chosen)
	host.board_view.travel_finished.connect(host._on_board_travel_finished)
	host.decision_panel.choice_selected.connect(host._on_decision_choice_selected)
	host.decision_panel.choice_selected.connect(func(_choice_id: String) -> void: host._play_ui_confirm_sfx())
	host.decision_panel.closed.connect(host._on_decision_closed)
	host.base_panel.manage_requested.connect(host._on_base_manage_requested)
	host.base_panel.closed.connect(host._on_base_closed)
	host.system_panel.closed.connect(host._on_system_panel_closed)
	host.battle_panel.battle_finished.connect(host._on_battle_finished)
	host.save_slot_panel.slot_selected.connect(host._on_save_slot_selected)
	host.save_slot_panel.load_requested.connect(host._on_save_slot_load_requested)
	host.save_slot_panel.new_requested.connect(host._on_save_slot_new_requested)
	host.save_slot_panel.save_requested.connect(host._on_save_slot_save_requested)
	host.save_slot_panel.delete_requested.connect(host._on_save_slot_delete_requested)
	host.save_slot_panel.close_requested.connect(host._on_save_slot_closed)
	host.input_settings_panel.closed.connect(host._on_input_settings_panel_closed)
	host._asset_file_dialog.files_selected.connect(host._on_asset_files_selected)
	host._asset_file_dialog.canceled.connect(host._on_asset_import_canceled)

func configure_static_ui_nodes(host) -> void:
	host.cutscene_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host.save_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host.input_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	host._menu_custom_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._menu_custom_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host._menu_custom_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	host._menu_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._menu_logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	host._menu_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func ensure_menu_bgm_player(host) -> void:
	if is_instance_valid(host._menu_bgm_player):
		return
	host._menu_bgm_player = AudioStreamPlayer.new()
	host._menu_bgm_player.name = "MenuBgmPlayer"
	host._menu_bgm_player.bus = "Master"
	host.add_child(host._menu_bgm_player)

func ensure_battle_bgm_player(host) -> void:
	if is_instance_valid(host._battle_bgm_player):
		return
	host._battle_bgm_player = AudioStreamPlayer.new()
	host._battle_bgm_player.name = "BattleBgmPlayer"
	host._battle_bgm_player.bus = "Master"
	host.add_child(host._battle_bgm_player)

func ensure_ui_sfx_player(host) -> void:
	if is_instance_valid(host._ui_sfx_player):
		return
	host._ui_sfx_player = AudioStreamPlayer.new()
	host._ui_sfx_player.name = "UiSfxPlayer"
	host._ui_sfx_player.bus = "Master"
	host.add_child(host._ui_sfx_player)

func refresh_custom_asset_bindings(host) -> void:
	apply_custom_app_icon(host)
	apply_custom_ui_font(host)
	refresh_main_menu_logo(host)
	host._refresh_main_menu_visuals()
	refresh_background_audio(host)
	refresh_ui_audio(host)

func apply_custom_app_icon(host) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_ICON):
		return
	var custom_texture := CustomAssetRepository.get_bound_texture("app_icon")
	if custom_texture != null:
		var custom_image := custom_texture.get_image()
		if custom_image != null and not custom_image.is_empty():
			DisplayServer.set_icon(custom_image)
			return
	var default_icon_path := String(ProjectSettings.get_setting("application/config/icon", ""))
	if default_icon_path.is_empty():
		return
	var default_icon_resource := load(default_icon_path)
	if default_icon_resource is Texture2D:
		var default_image := (default_icon_resource as Texture2D).get_image()
		if default_image != null and not default_image.is_empty():
			DisplayServer.set_icon(default_image)

func apply_custom_ui_font(host) -> void:
	var custom_font := CustomAssetRepository.get_bound_font("ui_font")
	host.theme = host.JrpgTheme.build(custom_font)
	host._apply_basic_styles()
	host.queue_redraw()

func refresh_main_menu_logo(host) -> void:
	if not is_instance_valid(host._menu_logo_rect):
		return
	var texture := CustomAssetRepository.get_bound_texture("main_menu_logo")
	host._menu_logo_rect.texture = texture
	host._menu_logo_rect.visible = texture != null and host.main_menu_panel.visible

func refresh_background_audio(host) -> void:
	sync_menu_bgm(host)
	sync_battle_bgm(host)

func sync_menu_bgm(host) -> void:
	if not is_instance_valid(host._menu_bgm_player):
		return
	var stream := CustomAssetRepository.get_bound_audio_stream("main_menu_bgm")
	if host.battle_panel.visible:
		host._menu_bgm_player.stop()
		return
	if stream == null or not host.main_menu_panel.visible:
		host._menu_bgm_player.stop()
		host._menu_bgm_player.stream = null
		return
	if host._menu_bgm_player.stream != stream:
		host._menu_bgm_player.stop()
		host._menu_bgm_player.stream = stream
	if not host._menu_bgm_player.playing:
		host._menu_bgm_player.play()

func sync_battle_bgm(host) -> void:
	if not is_instance_valid(host._battle_bgm_player):
		return
	var stream := CustomAssetRepository.get_bound_audio_stream("battle_bgm")
	if stream == null or not host.battle_panel.visible:
		host._battle_bgm_player.stop()
		host._battle_bgm_player.stream = null
		return
	if host._battle_bgm_player.stream != stream:
		host._battle_bgm_player.stop()
		host._battle_bgm_player.stream = stream
	if not host._battle_bgm_player.playing:
		host._battle_bgm_player.play()

func refresh_ui_audio(host) -> void:
	if not is_instance_valid(host._ui_sfx_player):
		return
	var stream := CustomAssetRepository.get_bound_audio_stream("ui_confirm_sfx")
	host._ui_sfx_player.stream = stream

func play_ui_confirm_sfx(host) -> void:
	if not is_instance_valid(host._ui_sfx_player):
		return
	if host._ui_sfx_player.stream == null:
		return
	host._ui_sfx_player.stop()
	host._ui_sfx_player.play()

func start_battle_panel(host, battle_config: Dictionary) -> void:
	sync_menu_bgm(host)
	host.battle_panel.start_battle(battle_config)
	sync_battle_bgm(host)

func configure_asset_import_dialog(host) -> void:
	host._asset_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	host._asset_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	host._asset_file_dialog.use_native_dialog = not OS.has_feature("web")
	host._asset_file_dialog.title = "导入自定义素材文件"
	host._asset_file_dialog.filters = CustomAssetRepository.get_import_dialog_filters()

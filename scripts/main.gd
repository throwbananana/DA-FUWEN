extends Control

const GameData = preload("res://scripts/game_data.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")
const BoardView = preload("res://scripts/board_view.gd")
const BattlePanel = preload("res://scripts/battle_panel.gd")
const DiceRollPanel = preload("res://scripts/dice_roll_panel.gd")
const DecisionPanel = preload("res://scripts/decision_panel.gd")
const BasePanel = preload("res://scripts/base_panel.gd")
const SystemPanel = preload("res://scripts/system_panel.gd")
const SaveSlotPanel = preload("res://scripts/save_slot_panel.gd")
const InputSettingsPanel = preload("res://scripts/input_settings_panel.gd")
const VisitFlowController = preload("res://scripts/services/visit_flow_controller.gd")
const HabitatService = preload("res://scripts/services/habitat_service.gd")
const NpcService = preload("res://scripts/services/npc_service.gd")
const EncounterService = preload("res://scripts/services/encounter_service.gd")
const SynergyService = preload("res://scripts/services/synergy_service.gd")
const DiceService = preload("res://scripts/services/dice_service.gd")
const BoardProgressionService = preload("res://scripts/services/board_progression_service.gd")
const BoardMapEffectService = preload("res://scripts/services/board_map_effect_service.gd")
const WeeklyCycleService = preload("res://scripts/services/weekly_cycle_service.gd")
const RunModifierService = preload("res://scripts/services/run_modifier_service.gd")
const MetaProgressionService = preload("res://scripts/services/meta_progression_service.gd")
const NpcRouteService = preload("res://scripts/services/npc_route_service.gd")
const ThreatService = preload("res://scripts/services/threat_service.gd")
const AIPlayerService = preload("res://scripts/services/ai_player_service.gd")
const DialogueService = preload("res://scripts/services/dialogue_service.gd")
const StoryService = preload("res://scripts/services/story_service.gd")
const StoryDirector = preload("res://scripts/services/story_director.gd")
const CutsceneService = preload("res://scripts/services/cutscene_service.gd")
const CutscenePanel = preload("res://scripts/cutscene_panel.gd")
const FishingService = preload("res://scripts/services/fishing_service.gd")
const LocalizationService = preload("res://scripts/services/localization_service.gd")
const NurseryService = preload("res://scripts/services/nursery_service.gd")
const BulletinService = preload("res://scripts/services/bulletin_service.gd")
const MinigameService = preload("res://scripts/services/minigame_service.gd")
const InfirmaryService = preload("res://scripts/services/infirmary_service.gd")
const AnnualCompetitionService = preload("res://scripts/services/annual_competition_service.gd")
const BattleRosterServiceScript = preload("res://scripts/services/battle_roster_service.gd")
const JrpgTheme = preload("res://scripts/jrpg_theme.gd")

const GAME_TITLE := "雾野市"
const INVENTORY_RESOURCE_TYPES: Array[String] = ["material", "rare_material"]
const INVENTORY_SUPPLY_TYPES: Array[String] = ["consumable", "tool", "quest", "trophy"]
const CODEX_RARITY_LABELS := {
	"common": "常见",
	"uncommon": "少见",
	"rare": "稀有",
	"epic": "史诗",
	"legendary": "传说",
}
const CODEX_RARITY_COLORS := {
	"common": "#7dd3fc",
	"uncommon": "#86efac",
	"rare": "#facc15",
	"epic": "#f9a8d4",
	"legendary": "#fb7185",
}

const WEATHER_ORDER := ["clear", "fog", "rain", "storm"]
const WEATHER_NAMES := {
	"clear": "晴日",
	"fog": "薄雾",
	"mist": "雾息",
	"rain": "细雨",
	"storm": "风暴",
	"drizzle": "微雨",
	"humid": "闷热",
	"windy": "劲风",
	"dry": "燥风",
	"snow": "雪幕",
}

const TIME_ORDER := ["day", "evening", "night"]
const TIME_NAMES := {
	"day": "白昼",
	"evening": "黄昏",
	"night": "夜晚",
}

const STARTER_SPECIES_IDS := ["steam_otter_1", "moss_deer_1", "spark_mouse_1"]
const TUTORIAL_ORDER := ["run_intro", "management_intro", "battle_intro"]
const EVENT_LOG_TYPEWRITER_SPEED := 0.016
const EVENT_LOG_TYPEWRITER_MIN_DURATION := 0.18
const EVENT_LOG_TYPEWRITER_MAX_DURATION := 0.82
const AI_OBSERVE_PREPARE_DELAY := 0.18
const AI_OBSERVE_LANDING_DELAY := 0.24
const AI_OBSERVE_TURN_FINISH_DELAY := 0.18
const CASUAL_INTRO_MAX_GLOBAL_TURN := 5
const CASUAL_INTRO_VISIBLE_LOG_ENTRIES := 3

const NODE_TEMPLATES := [
	{"id": 0, "name": "营地", "type": "camp", "description": "在这里歇歇脚，翻翻小本，再想想今天去见谁。", "position": Vector2(80, 280), "edges": [1, 2, 3], "travel_cost": 0, "habitat_id": ""},
	{"id": 1, "name": "雾苔窟", "type": "habitat", "description": "潮湿安静，适合慢慢待一会儿，也适合把心收下来。", "position": Vector2(280, 130), "edges": [4], "travel_cost": 1, "habitat_id": "mist_moss_cave"},
	{"id": 2, "name": "晶溪滩", "type": "habitat", "description": "浅水贴着暖石，站一会儿就会不自觉慢下来。", "position": Vector2(470, 320), "edges": [5], "travel_cost": 1, "habitat_id": "crystal_creek"},
	{"id": 3, "name": "云升驿", "type": "settlement", "description": "人来人往，风声和消息总比别处早一点。", "position": Vector2(530, 90), "edges": [4, 5], "travel_cost": 1, "habitat_id": "sky_post"},
	{"id": 4, "name": "古械平台", "type": "habitat", "description": "旧东西很多，得一点点拾掇，急不来。", "position": Vector2(830, 140), "edges": [6], "travel_cost": 2, "habitat_id": "ancient_platform"},
	{"id": 5, "name": "铜锤集", "type": "settlement", "description": "白天总是叮叮当当，想找东西时来这里最省心。", "position": Vector2(840, 330), "edges": [6, 7], "travel_cost": 1, "habitat_id": "copper_hammer_bazaar"},
	{"id": 6, "name": "裂辉尖塔", "type": "anomaly", "description": "先别急着往里走，等你更熟这座城的时候再来。", "position": Vector2(1150, 220), "edges": [9, 11], "travel_cost": 3, "habitat_id": "radiant_spire"},
	{"id": 7, "name": "鸣雷草场", "type": "habitat", "description": "雷声大的日子里会热闹些，适合来活动活动筋骨。", "position": Vector2(1040, 430), "edges": [8, 10], "travel_cost": 2, "habitat_id": "thunder_meadow"},
	{"id": 8, "name": "赤叶演武场", "type": "dojo", "description": "入秋后才开门，正适合来试试现在这套搭配顺不顺手。", "position": Vector2(1250, 430), "edges": [10], "travel_cost": 2, "habitat_id": "autumn_leaf_dojo"},
	{"id": 9, "name": "霜镜湖", "type": "habitat", "description": "天冷时才看得到它最安静的样子，值得慢慢看。", "position": Vector2(1290, 70), "edges": [11], "travel_cost": 2, "habitat_id": "frost_mirror_lake"},
	{"id": 10, "name": "回声断桥", "type": "settlement", "description": "等前面的路走顺了，这里自然会接上。", "position": Vector2(1110, 320), "edges": [11], "travel_cost": 2, "habitat_id": "echo_broken_bridge"},
	{"id": 11, "name": "裂辉观测台", "type": "anomaly", "description": "真想再往前看看，迟早会走到这里。", "position": Vector2(1440, 220), "edges": [], "travel_cost": 3, "habitat_id": "radiant_observatory"},
	{"id": 12, "name": "青栎林", "type": "habitat", "description": "风很轻，适合刚想把脚步放稳的时候走走。", "position": Vector2(1480, 470), "edges": [10, 13], "travel_cost": 1, "habitat_id": "greenbark_grove"},
	{"id": 13, "name": "烬火盆地", "type": "habitat", "description": "地方有点燥，适合想狠狠干一把的时候来。", "position": Vector2(1710, 470), "edges": [16], "travel_cost": 2, "habitat_id": "ember_crater"},
	{"id": 14, "name": "芦泽沼", "type": "habitat", "description": "湿地会把节奏拖慢一点，急的人反而不太适合。", "position": Vector2(1670, 330), "edges": [15, 16], "travel_cost": 2, "habitat_id": "reed_mire"},
	{"id": 15, "name": "盐镜海岸", "type": "habitat", "description": "潮水一来一回，这里的步子也总跟着活络起来。", "position": Vector2(1690, 110), "edges": [16], "travel_cost": 2, "habitat_id": "saltglass_coast"},
	{"id": 16, "name": "月沼遗迹", "type": "anomaly", "description": "路走到这儿，气氛就会绷起来；没准备好也可以先记住它。", "position": Vector2(1880, 230), "edges": [], "travel_cost": 3, "habitat_id": "moonfen_ruins"},
]

@onready var title_label: Label = %TitleLabel
@onready var meta_label: Label = %MetaLabel
@onready var round_label: Label = %RoundLabel
@onready var weather_label: Label = %WeatherLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var root_margin: MarginContainer = $RootMargin
@onready var main_vbox: VBoxContainer = $RootMargin/MainVBox
@onready var header_bar: BoxContainer = $RootMargin/MainVBox/HeaderBar
@onready var run_status_row: BoxContainer = $RootMargin/MainVBox/HeaderBar/HeaderLeft/RunStatusRow
@onready var content_row: BoxContainer = $RootMargin/MainVBox/ContentRow
@onready var overlay: Control = $Overlay
@onready var player_summary_label: RichTextLabel = %PlayerSummaryLabel
@onready var ai_summary_label: RichTextLabel = %AISummaryLabel
@onready var control_summary_label: RichTextLabel = %ControlSummaryLabel
@onready var dice_label: Label = %DiceLabel
@onready var dice_meta_label: Label = %DiceMetaLabel
@onready var action_hint_label: RichTextLabel = %ActionHintLabel
@onready var board_status_label: Label = %BoardStatusLabel
@onready var board_route_label: Label = %BoardRouteLabel
@onready var map_hint_label: RichTextLabel = %MapHintLabel
@onready var roster_label: RichTextLabel = %RosterLabel
@onready var event_log_label: RichTextLabel = %EventLogLabel
@onready var roll_button: Button = %RollButton
@onready var plus_button: Button = %PlusButton
@onready var minus_button: Button = %MinusButton
@onready var reroll_button: Button = %RerollButton
@onready var support_button: Button = %SupportButton
@onready var base_button: Button = %BaseButton
@onready var new_game_button: Button = %NewGameButton
@onready var board_view: BoardView = %BoardView
@onready var battle_panel: BattlePanel = %BattlePanel
@onready var dice_roll_panel: DiceRollPanel = %DiceRollPanel
@onready var decision_panel: DecisionPanel = %DecisionPanel
@onready var base_panel: BasePanel = %BasePanel
@onready var system_panel: SystemPanel = %SystemPanel
@onready var menu_backdrop: ColorRect = %MenuBackdrop
@onready var main_menu_panel: PanelContainer = %MainMenuPanel
@onready var menu_title_label: Label = $Overlay/MainMenuPanel/MarginContainer/VBoxContainer/MenuTitleLabel
@onready var menu_subtitle_label: Label = $Overlay/MainMenuPanel/MarginContainer/VBoxContainer/MenuSubtitleLabel
@onready var continue_button: Button = %ContinueButton
@onready var menu_new_game_button: Button = %MenuNewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_action_hint_label: RichTextLabel = %MenuActionHintLabel
@onready var menu_run_summary_label: RichTextLabel = %MenuRunSummaryLabel
@onready var menu_meta_summary_label: RichTextLabel = %MenuMetaSummaryLabel
@onready var menu_content_row: BoxContainer = $Overlay/MainMenuPanel/MarginContainer/VBoxContainer/MenuContentRow
@onready var menu_action_column: VBoxContainer = $Overlay/MainMenuPanel/MarginContainer/VBoxContainer/MenuContentRow/ActionColumn
var save_slot_panel: SaveSlotPanel
var input_settings_panel: InputSettingsPanel
@onready var board_panel: PanelContainer = $RootMargin/MainVBox/ContentRow/BoardPanel
@onready var board_top_strip: PanelContainer = $RootMargin/MainVBox/ContentRow/BoardPanel/BoardVBox/BoardTopStrip
@onready var board_stage_panel: PanelContainer = %BoardStagePanel
@onready var node_detail_card: PanelContainer = $RootMargin/MainVBox/ContentRow/BoardPanel/BoardVBox/NodeDetailCard
@onready var top_strip_row: BoxContainer = $RootMargin/MainVBox/ContentRow/BoardPanel/BoardVBox/BoardTopStrip/MarginContainer/TopStripRow
@onready var board_meta_column: VBoxContainer = $RootMargin/MainVBox/ContentRow/BoardPanel/BoardVBox/BoardTopStrip/MarginContainer/TopStripRow/BoardMetaColumn
@onready var side_column: VBoxContainer = $RootMargin/MainVBox/ContentRow/SideColumn
@onready var status_panel: PanelContainer = $RootMargin/MainVBox/ContentRow/SideColumn/StatusPanel
@onready var player_card: PanelContainer = %PlayerCard
@onready var rival_card: PanelContainer = %RivalCard
@onready var control_card: PanelContainer = %ControlCard
@onready var dice_panel: PanelContainer = $RootMargin/MainVBox/ContentRow/SideColumn/DicePanel
@onready var roll_row: BoxContainer = $RootMargin/MainVBox/ContentRow/SideColumn/DicePanel/MarginContainer/DiceVBox/RollRow
@onready var support_row: BoxContainer = $RootMargin/MainVBox/ContentRow/SideColumn/DicePanel/MarginContainer/DiceVBox/SupportRow
@onready var roster_panel: PanelContainer = $RootMargin/MainVBox/ContentRow/SideColumn/RosterPanel
@onready var log_panel: PanelContainer = $RootMargin/MainVBox/ContentRow/SideColumn/LogPanel

var rng := RandomNumberGenerator.new()
var world_nodes: Array = []
var board_lookup := {}

var visit_flow: VisitFlowController
var habitat_service := HabitatService.new()
var npc_service := NpcService.new()
var encounter_service := EncounterService.new()
var synergy_service := SynergyService.new()
var dice_service := DiceService.new()
var board_progression_service := BoardProgressionService.new()
var board_map_effect_service := BoardMapEffectService.new()
var weekly_cycle_service := WeeklyCycleService.new()
var run_modifier_service := RunModifierService.new()
var meta_progression_service := MetaProgressionService.new()
var npc_route_service := NpcRouteService.new()
var threat_service := ThreatService.new()
var ai_player_service := AIPlayerService.new()
var dialogue_service := DialogueService.new()
var fishing_service := FishingService.new()
var localization_service := LocalizationService.new()
var nursery_service := NurseryService.new()
var bulletin_service := BulletinService.new()
var minigame_service := MinigameService.new()
var infirmary_service := InfirmaryService.new()
var annual_competition_service := AnnualCompetitionService.new()
var battle_roster_service := BattleRosterServiceScript.new()
var story_service := StoryService.new()
var story_director = StoryDirector.new()
var cutscene_service := CutsceneService.new()
var cutscene_panel: CutscenePanel

var season_finished := false
var awaiting_destination := false
var current_node_id := 0
var current_visit_habitat_id := ""
var current_encounter := {}
var pending_npc_duel_id := ""
var pending_battle_source := ""
var pending_environment_battle := {}
var last_encounter_action_id := ""
var pending_context := {}
var pending_roll := {}
var reachable_paths := {}
var board_anim_locked := false
var pending_travel_path: Array[int] = []
var pending_travel_target := -1
var _queued_auto_travel_target := -1
var branch_choice_pending := false
var _queued_roll_start := false
var pending_route_steps_remaining := 0
var pending_route_history: Array[int] = []
var pending_route_options: Array[int] = []
var pending_route_forced_path: Array[int] = []
var pending_route_forced_index := -1
var anchor_override_active := false
var camp_panel_requires_finish := false
var starter_choice_pending := false
var starter_choice_done := false
var starter_companion_uid := ""
var pending_tutorial_battle_config := {}
var pending_tutorial_battle_source := ""
var pending_tutorial_battle_log := ""
var _active_synergy_snapshot: Array[String] = []
var _synergy_fx_ready := false
var _synergy_banner: PanelContainer
var _synergy_banner_label: RichTextLabel
var _synergy_unit_glow_host: MarginContainer
var _synergy_unit_glow_row: HBoxContainer
var _synergy_banner_tween: Tween
var _synergy_unit_glow_tween: Tween
var _stage_transition_layer: Control
var _stage_transition_backdrop: ColorRect
var _stage_transition_panel: PanelContainer
var _stage_transition_title: Label
var _stage_transition_subtitle: RichTextLabel
var _stage_transition_tween: Tween
var _event_log_typewriter_tween: Tween
var _event_log_snapshot: Array[String] = []
var runtime_session_started := false
var ai_turn_in_progress := false
var _active_ai_observation_line := ""
var _last_ai_turn_report := {}
var _post_travel_resolution_in_progress := false
var _asset_file_dialog: FileDialog
var _menu_custom_background: TextureRect
var _responsive_layout_queued := false
var _menu_selected_slot_id := "slot_01"
var _save_slot_panel_mode := "boot"

func _ready() -> void:
	rng.randomize()
	var window := get_window()
	window.min_size = GameState.minimum_window_size()
	window.size_changed.connect(_on_window_size_changed)
	title_label.text = GAME_TITLE
	base_button.hide()
	plus_button.hide()
	minus_button.hide()
	reroll_button.hide()
	_ensure_cutscene_panel()
	_ensure_input_settings_panel()
	story_director.configure(
		story_service,
		cutscene_service,
		cutscene_panel,
		Callable(self, "_play_dialogue_cutscene"),
		Callable(self, "_is_modal_open"),
		Callable(self, "_should_skip_cutscene_runtime"),
		Callable(self, "_push_log")
	)
	_ensure_save_slot_panel()
	_connect_signals()
	theme = JrpgTheme.build()
	_apply_basic_styles()
	_prepare_overlay_panels()
	_configure_safe_ui_bounds()
	_configure_text_overflow_guards()
	_queue_responsive_layout()
	_ensure_menu_custom_background()
	_setup_asset_import_dialog()
	_ensure_synergy_banner()
	_ensure_stage_transition_overlay()
	_queue_responsive_layout()
	install_visit_flow()
	GameState.ensure_save_index()
	GameState.migrate_legacy_run_save()
	_menu_selected_slot_id = GameState.get_selected_run_slot_id()
	if _should_show_boot_menu():
		_show_main_menu()
	else:
		_start_new_game_in_slot(_menu_selected_slot_id)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(input_settings_panel) and input_settings_panel.visible:
		return
	if main_menu_panel.visible and not decision_panel.visible and not (is_instance_valid(save_slot_panel) and save_slot_panel.visible):
		if runtime_session_started and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
			_hide_main_menu()
			get_viewport().set_input_as_handled()
		return
	if _is_modal_open():
		return
	if _handle_board_controller_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_global_shortcut_input(event):
		get_viewport().set_input_as_handled()

func _handle_board_controller_input(event: InputEvent) -> bool:
	if not branch_choice_pending or board_anim_locked:
		return false
	if event.is_action_pressed("ui_up"):
		return board_view.move_controller_cursor(Vector2i.UP)
	if event.is_action_pressed("ui_down"):
		return board_view.move_controller_cursor(Vector2i.DOWN)
	if event.is_action_pressed("ui_left"):
		return board_view.move_controller_cursor(Vector2i.LEFT)
	if event.is_action_pressed("ui_right"):
		return board_view.move_controller_cursor(Vector2i.RIGHT)
	if event.is_action_pressed("ui_accept"):
		board_view.activate_controller_cursor()
		return true
	return false

func _handle_global_shortcut_input(event: InputEvent) -> bool:
	if board_anim_locked or awaiting_destination or branch_choice_pending:
		return false
	if event.is_action_pressed("game_roll") and not roll_button.disabled:
		_on_start_day_pressed()
		return true
	if event.is_action_pressed("game_support") and not support_button.disabled:
		_on_support_pressed()
		return true
	if event.is_action_pressed("game_base") and not base_button.disabled:
		_on_base_pressed()
		return true
	if (event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel")) and not new_game_button.disabled:
		_on_main_menu_requested()
		return true
	return false

func install_visit_flow() -> void:
	visit_flow = VisitFlowController.new()
	add_child(visit_flow)
	visit_flow.state_changed.connect(_on_visit_state_changed)
	visit_flow.visit_finished.connect(_on_visit_finished)

func _ensure_cutscene_panel() -> void:
	if is_instance_valid(cutscene_panel):
		return
	cutscene_panel = CutscenePanel.new()
	cutscene_panel.name = "CutscenePanel"
	cutscene_panel.visible = false
	cutscene_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(cutscene_panel)

func _ensure_save_slot_panel() -> void:
	if is_instance_valid(save_slot_panel):
		return
	save_slot_panel = SaveSlotPanel.new()
	save_slot_panel.name = "SaveSlotPanel"
	save_slot_panel.visible = false
	save_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(save_slot_panel)

func _ensure_input_settings_panel() -> void:
	if is_instance_valid(input_settings_panel):
		return
	input_settings_panel = InputSettingsPanel.new()
	input_settings_panel.name = "InputSettingsPanel"
	input_settings_panel.visible = false
	input_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(input_settings_panel)

func _connect_signals() -> void:
	roll_button.pressed.connect(_on_start_day_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	minus_button.pressed.connect(_on_minus_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	support_button.pressed.connect(_on_support_pressed)
	base_button.pressed.connect(_on_base_pressed)
	new_game_button.pressed.connect(_on_main_menu_requested)
	continue_button.pressed.connect(_on_continue_pressed)
	menu_new_game_button.pressed.connect(_on_menu_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	dice_roll_panel.confirmed.connect(_on_dice_roll_confirmed)
	dice_roll_panel.closed.connect(_on_dice_roll_panel_closed)
	dice_roll_panel.plus_requested.connect(_on_dice_roll_plus_requested)
	dice_roll_panel.minus_requested.connect(_on_dice_roll_minus_requested)
	dice_roll_panel.reroll_requested.connect(_on_dice_roll_reroll_requested)
	board_view.node_chosen.connect(_on_board_node_chosen)
	board_view.travel_finished.connect(_on_board_travel_finished)
	decision_panel.choice_selected.connect(_on_decision_choice_selected)
	decision_panel.closed.connect(_on_decision_closed)
	base_panel.manage_requested.connect(_on_base_manage_requested)
	base_panel.closed.connect(_on_base_closed)
	system_panel.closed.connect(_on_system_panel_closed)
	battle_panel.battle_finished.connect(_on_battle_finished)
	if is_instance_valid(save_slot_panel):
		save_slot_panel.slot_selected.connect(_on_save_slot_selected)
		save_slot_panel.load_requested.connect(_on_save_slot_load_requested)
		save_slot_panel.new_requested.connect(_on_save_slot_new_requested)
		save_slot_panel.save_requested.connect(_on_save_slot_save_requested)
		save_slot_panel.delete_requested.connect(_on_save_slot_delete_requested)
		save_slot_panel.close_requested.connect(_on_save_slot_closed)
	if is_instance_valid(input_settings_panel):
		input_settings_panel.closed.connect(_on_input_settings_panel_closed)

func _ensure_menu_custom_background() -> void:
	if is_instance_valid(_menu_custom_background):
		return
	_menu_custom_background = TextureRect.new()
	_menu_custom_background.name = "MenuCustomBackground"
	_menu_custom_background.visible = false
	_menu_custom_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_custom_background.layout_mode = 1
	_menu_custom_background.anchors_preset = Control.PRESET_FULL_RECT
	_menu_custom_background.anchor_right = 1.0
	_menu_custom_background.anchor_bottom = 1.0
	_menu_custom_background.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_custom_background.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu_custom_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_custom_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_custom_background.modulate = Color(1, 1, 1, 0.78)
	overlay.add_child(_menu_custom_background)
	var backdrop_index := overlay.get_children().find(menu_backdrop)
	if backdrop_index >= 0:
		overlay.move_child(_menu_custom_background, backdrop_index)

func _setup_asset_import_dialog() -> void:
	_asset_file_dialog = FileDialog.new()
	_asset_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_asset_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_asset_file_dialog.use_native_dialog = not OS.has_feature("web")
	_asset_file_dialog.title = "导入自定义素材文件"
	_asset_file_dialog.filters = CustomAssetRepository.get_import_dialog_filters()
	_asset_file_dialog.files_selected.connect(_on_asset_files_selected)
	_asset_file_dialog.canceled.connect(_on_asset_import_canceled)
	add_child(_asset_file_dialog)

func _apply_basic_styles() -> void:
	battle_panel.hide()

	var overlay_panel_style := StyleBoxFlat.new()
	overlay_panel_style.bg_color = Color("0A1328")
	overlay_panel_style.border_color = Color("E3C985")
	overlay_panel_style.set_border_width_all(3)
	overlay_panel_style.set_corner_radius_all(22)
	overlay_panel_style.content_margin_left = 22
	overlay_panel_style.content_margin_top = 18
	overlay_panel_style.content_margin_right = 22
	overlay_panel_style.content_margin_bottom = 18
	overlay_panel_style.shadow_color = Color(0, 0, 0, 0.24)
	overlay_panel_style.shadow_size = 10
	overlay_panel_style.shadow_offset = Vector2(0, 5)
	overlay_panel_style.anti_aliasing = true

	var overlay_panels := [dice_roll_panel, decision_panel, base_panel, system_panel, main_menu_panel]
	if is_instance_valid(save_slot_panel):
		overlay_panels.append(save_slot_panel)
	if is_instance_valid(cutscene_panel):
		overlay_panels.append(cutscene_panel)
	if is_instance_valid(input_settings_panel):
		overlay_panels.append(input_settings_panel)
	for panel in overlay_panels:
		if panel is PanelContainer:
			panel.add_theme_stylebox_override("panel", overlay_panel_style.duplicate())

	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = Color("18315C")
	ribbon_style.border_color = Color("F0CF84")
	ribbon_style.set_border_width_all(2)
	ribbon_style.corner_radius_top_left = 18
	ribbon_style.corner_radius_top_right = 18
	ribbon_style.corner_radius_bottom_left = 12
	ribbon_style.corner_radius_bottom_right = 12
	ribbon_style.content_margin_left = 18
	ribbon_style.content_margin_top = 10
	ribbon_style.content_margin_right = 18
	ribbon_style.content_margin_bottom = 10
	ribbon_style.shadow_color = Color(0, 0, 0, 0.14)
	ribbon_style.shadow_size = 4
	ribbon_style.shadow_offset = Vector2(0, 2)
	ribbon_style.anti_aliasing = true
	board_top_strip.add_theme_stylebox_override("panel", ribbon_style)

	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color("0A152B")
	log_style.border_color = Color("8E7A53")
	log_style.set_border_width_all(2)
	log_style.set_corner_radius_all(18)
	log_style.content_margin_left = 16
	log_style.content_margin_top = 14
	log_style.content_margin_right = 16
	log_style.content_margin_bottom = 14
	log_style.shadow_color = Color(0, 0, 0, 0.12)
	log_style.shadow_size = 3
	log_style.shadow_offset = Vector2(0, 2)
	log_style.anti_aliasing = true
	log_panel.add_theme_stylebox_override("panel", log_style)

	var unit_card_style := StyleBoxFlat.new()
	unit_card_style.bg_color = Color("132241")
	unit_card_style.border_color = Color("A88B57")
	unit_card_style.set_border_width_all(2)
	unit_card_style.set_corner_radius_all(16)
	unit_card_style.content_margin_left = 14
	unit_card_style.content_margin_top = 12
	unit_card_style.content_margin_right = 14
	unit_card_style.content_margin_bottom = 12
	unit_card_style.shadow_color = Color(0, 0, 0, 0.10)
	unit_card_style.shadow_size = 3
	unit_card_style.shadow_offset = Vector2(0, 2)
	unit_card_style.anti_aliasing = true
	for panel in [player_card, rival_card, control_card]:
		panel.add_theme_stylebox_override("panel", unit_card_style.duplicate())

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("1A2C52")
	chip_style.border_color = Color("D9BC79")
	chip_style.set_border_width_all(2)
	chip_style.set_corner_radius_all(999)
	chip_style.content_margin_left = 12
	chip_style.content_margin_top = 6
	chip_style.content_margin_right = 12
	chip_style.content_margin_bottom = 6
	chip_style.shadow_color = Color(0, 0, 0, 0.10)
	chip_style.shadow_size = 3
	chip_style.shadow_offset = Vector2(0, 2)
	chip_style.anti_aliasing = true

	for path in [
		"RootMargin/MainVBox/HeaderBar/HeaderLeft/RunStatusRow/RoundChip",
		"RootMargin/MainVBox/HeaderBar/HeaderLeft/RunStatusRow/WeatherChip",
		"RootMargin/MainVBox/HeaderBar/HeaderLeft/RunStatusRow/ObjectiveChip",
	]:
		var chip := get_node_or_null(path)
		if chip is PanelContainer:
			chip.add_theme_stylebox_override("panel", chip_style.duplicate())

	var stage_highlight := StyleBoxFlat.new()
	stage_highlight.bg_color = Color("203763")
	stage_highlight.border_color = Color("F0CF84")
	stage_highlight.set_border_width_all(3)
	stage_highlight.set_corner_radius_all(20)
	stage_highlight.content_margin_left = 18
	stage_highlight.content_margin_top = 14
	stage_highlight.content_margin_right = 18
	stage_highlight.content_margin_bottom = 14
	stage_highlight.shadow_color = Color(0, 0, 0, 0.18)
	stage_highlight.shadow_size = 6
	stage_highlight.shadow_offset = Vector2(0, 3)
	stage_highlight.anti_aliasing = true
	board_stage_panel.add_theme_stylebox_override("panel", stage_highlight)

	title_label.modulate = Color("FFF7D8")
	meta_label.modulate = Color("C8D5F0")
	round_label.modulate = Color("F4E7C2")
	weather_label.modulate = Color("D7E5FF")
	objective_label.modulate = Color("FFE8A8")

func _prepare_overlay_panels() -> void:
	var centered_panels := [
		dice_roll_panel,
		battle_panel,
		decision_panel,
		base_panel,
		system_panel,
		main_menu_panel,
		save_slot_panel,
		input_settings_panel,
	]
	if is_instance_valid(cutscene_panel):
		centered_panels.append(cutscene_panel)
	for panel in centered_panels:
		if panel == null:
			continue
		panel.anchor_left = 0.5
		panel.anchor_top = 0.5
		panel.anchor_right = 0.5
		panel.anchor_bottom = 0.5
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH

func _apply_centered_panel_rect(panel: Control, panel_size: Vector2) -> void:
	if panel == null:
		return
	var half_size := panel_size * 0.5
	panel.custom_minimum_size = panel_size
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y

func _fit_overlay_panel(panel: Control, desired_size: Vector2, window_size: Vector2i, min_size: Vector2, padding: int) -> void:
	if panel == null:
		return
	var safe_width := maxf(window_size.x - float(padding), 320.0)
	var safe_height := maxf(window_size.y - float(padding), 220.0)
	var clamped_min := Vector2(minf(min_size.x, safe_width), minf(min_size.y, safe_height))
	var final_size := Vector2(clampf(desired_size.x, clamped_min.x, safe_width), clampf(desired_size.y, clamped_min.y, safe_height))
	_apply_centered_panel_rect(panel, final_size)

func _on_window_size_changed() -> void:
	_queue_responsive_layout()

func _queue_responsive_layout() -> void:
	if _responsive_layout_queued:
		return
	_responsive_layout_queued = true
	call_deferred("_flush_responsive_layout")

func _flush_responsive_layout() -> void:
	_responsive_layout_queued = false
	if not is_inside_tree():
		return
	_apply_responsive_layout()

func _configure_safe_ui_bounds() -> void:
	clip_contents = true
	root_margin.clip_contents = true
	overlay.clip_contents = true
	for control in [
		board_panel,
		board_top_strip,
		board_stage_panel,
		node_detail_card,
		status_panel,
		player_card,
		rival_card,
		control_card,
		dice_panel,
		roster_panel,
		log_panel,
		main_menu_panel,
		battle_panel,
		dice_roll_panel,
		decision_panel,
		base_panel,
		system_panel,
		save_slot_panel,
		cutscene_panel,
		input_settings_panel,
	]:
		control.clip_contents = true

func _configure_text_overflow_guards() -> void:
	for label in [
		meta_label,
		round_label,
		weather_label,
		objective_label,
		dice_meta_label,
		board_status_label,
		board_route_label,
		menu_subtitle_label,
	]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button in [
		new_game_button,
		continue_button,
		menu_new_game_button,
		settings_button,
		roll_button,
		reroll_button,
		plus_button,
		minus_button,
		support_button,
		base_button,
	]:
		button.clip_text = true
	menu_meta_summary_label.scroll_active = true

func _apply_responsive_layout() -> void:
	var window_size := get_window().size
	var compact_width := window_size.x < 1440
	var short_height := window_size.y < 820
	var tight_height := window_size.y < 760
	var narrow_width := window_size.x < 1320
	var portrait := window_size.y > window_size.x
	var stacked_content := portrait or window_size.x < 1420 or (window_size.x < 1560 and short_height)
	var outer_margin := 10 if tight_height else (12 if compact_width or short_height else 18)
	var main_separation := 8 if tight_height else (10 if compact_width or short_height else 14)
	var title_font_size := 26 if tight_height else (28 if compact_width else 32)
	var meta_font_size := 13 if tight_height else (14 if compact_width else 15)
	var chip_font_size := 13 if tight_height else (14 if compact_width else 15)

	for edge in ["left", "top", "right", "bottom"]:
		root_margin.add_theme_constant_override("margin_%s" % edge, outer_margin)

	main_vbox.add_theme_constant_override("separation", main_separation)
	header_bar.add_theme_constant_override("separation", 12 if compact_width else 18)
	header_bar.custom_minimum_size = Vector2(0, 72 if short_height else 86)
	header_bar.vertical = portrait or (compact_width and short_height)
	run_status_row.add_theme_constant_override("separation", 6 if compact_width else 8)
	run_status_row.vertical = compact_width or narrow_width or stacked_content
	content_row.add_theme_constant_override("separation", 10 if compact_width else 14)
	content_row.vertical = stacked_content
	top_strip_row.add_theme_constant_override("separation", 10 if compact_width else 12)
	top_strip_row.vertical = stacked_content or window_size.x < 1360
	roll_row.add_theme_constant_override("separation", 4 if tight_height else 6)
	support_row.add_theme_constant_override("separation", 4 if tight_height else 6)
	menu_content_row.add_theme_constant_override("separation", 12 if compact_width else 16)
	menu_content_row.vertical = portrait or compact_width or short_height

	title_label.add_theme_font_size_override("font_size", title_font_size)
	meta_label.add_theme_font_size_override("font_size", meta_font_size)
	menu_title_label.add_theme_font_size_override("font_size", 30 if tight_height else (32 if compact_width else 36))
	menu_subtitle_label.add_theme_font_size_override("font_size", 16 if tight_height else 18)
	for label in [round_label, weather_label, objective_label]:
		label.add_theme_font_size_override("font_size", chip_font_size)

	new_game_button.custom_minimum_size = Vector2(120, 40 if tight_height else 44)
	board_top_strip.custom_minimum_size = Vector2(0, 64 if tight_height else (72 if compact_width else 84))
	board_meta_column.custom_minimum_size = Vector2(0, 0) if top_strip_row.vertical else Vector2(160 if compact_width else 240, 0)
	board_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if top_strip_row.vertical else HORIZONTAL_ALIGNMENT_RIGHT
	board_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if top_strip_row.vertical else HORIZONTAL_ALIGNMENT_RIGHT
	action_hint_label.custom_minimum_size = Vector2(0, 44 if tight_height else 60)
	action_hint_label.fit_content = false
	action_hint_label.scroll_active = true

	var board_height := 360 if tight_height else (430 if short_height else 520)
	if stacked_content:
		board_height = 380 if tight_height else (440 if short_height else 500)
	board_view.custom_minimum_size = Vector2(0, board_height)
	node_detail_card.custom_minimum_size = Vector2(0, 108 if tight_height else (132 if short_height else 172))
	map_hint_label.scroll_active = true
	side_column.custom_minimum_size = Vector2(0, 0) if content_row.vertical else Vector2(280 if tight_height else (320 if compact_width else 360), 0)

	var compact_summary := short_height or stacked_content
	_configure_summary_label(player_summary_label, compact_summary, 60, 84)
	_configure_summary_label(ai_summary_label, compact_summary, 60, 84)
	_configure_summary_label(control_summary_label, compact_summary, 64, 90)
	_configure_summary_label(roster_label, compact_summary, 96, 150)
	_apply_casual_exposure_policy()

	var small_button_height := 40 if tight_height else 44
	var medium_button_height := 42 if tight_height else 48
	for button in [roll_button, reroll_button, plus_button, minus_button]:
		button.custom_minimum_size = Vector2(0, medium_button_height)
	for button in [support_button, base_button]:
		button.custom_minimum_size = Vector2(0, small_button_height)
	for button in [continue_button, menu_new_game_button, settings_button]:
		button.custom_minimum_size = Vector2(0, 48 if tight_height else 54)

	var overlay_padding := outer_margin * 6
	var main_menu_size := Vector2(680, 460) if tight_height else (Vector2(720, 500) if compact_width or short_height else Vector2(760, 520))
	_fit_overlay_panel(main_menu_panel, main_menu_size, window_size, Vector2(420, 320), overlay_padding)
	_fit_overlay_panel(dice_roll_panel, Vector2(400, 330) if tight_height else Vector2(420, 360), window_size, Vector2(320, 280), overlay_padding)
	_fit_overlay_panel(decision_panel, Vector2(400, 300) if tight_height else Vector2(420, 320), window_size, Vector2(320, 240), overlay_padding)
	if is_instance_valid(cutscene_panel):
		_fit_overlay_panel(cutscene_panel, Vector2(560, 360) if tight_height else Vector2(620, 420), window_size, Vector2(360, 260), overlay_padding)
	_fit_overlay_panel(base_panel, Vector2(560, 500) if tight_height else Vector2(600, 560), window_size, Vector2(420, 320), overlay_padding)
	_fit_overlay_panel(system_panel, Vector2(620, 460) if tight_height else Vector2(700, 520), window_size, Vector2(420, 320), overlay_padding)
	if is_instance_valid(save_slot_panel):
		_fit_overlay_panel(save_slot_panel, Vector2(760, 520) if tight_height else Vector2(840, 580), window_size, Vector2(480, 360), overlay_padding)
	if is_instance_valid(input_settings_panel):
		_fit_overlay_panel(input_settings_panel, Vector2(880, 520) if tight_height else Vector2(960, 600), window_size, Vector2(520, 360), overlay_padding)
	_fit_overlay_panel(battle_panel, Vector2(700, 500) if tight_height else Vector2(760, 560), window_size, Vector2(520, 360), overlay_padding)
	menu_action_column.custom_minimum_size = Vector2(0, 0) if menu_content_row.vertical else Vector2(200 if compact_width else 220, 0)
	menu_run_summary_label.custom_minimum_size = Vector2(0, 148 if menu_content_row.vertical else (180 if compact_width else 200))

	if is_instance_valid(_synergy_banner):
		var banner_width := minf(420.0 if compact_width else 520.0, maxf(window_size.x - outer_margin * 6.0, 280.0))
		var banner_height := 96.0 if tight_height else 120.0
		_synergy_banner.custom_minimum_size = Vector2(banner_width, banner_height)
		_synergy_banner.offset_left = -banner_width * 0.5
		_synergy_banner.offset_right = banner_width * 0.5
		_synergy_banner.offset_top = 18.0 if tight_height else 28.0
		_synergy_banner.offset_bottom = _synergy_banner.offset_top + banner_height
	if is_instance_valid(_synergy_unit_glow_host):
		var glow_width := minf(420.0 if compact_width else 520.0, maxf(window_size.x - outer_margin * 6.0, 280.0))
		_synergy_unit_glow_host.offset_left = -glow_width * 0.5
		_synergy_unit_glow_host.offset_right = glow_width * 0.5
	if is_instance_valid(_stage_transition_panel):
		var stage_panel_size := Vector2(520, 180) if tight_height else (Vector2(620, 210) if compact_width or short_height else Vector2(720, 240))
		_stage_transition_panel.custom_minimum_size = _clamp_panel_size(stage_panel_size, window_size, outer_margin * 6)

func _configure_summary_label(label: RichTextLabel, compact: bool, compact_height: int, regular_height: int) -> void:
	label.fit_content = false
	label.scroll_active = true
	label.custom_minimum_size = Vector2(0, compact_height if compact else regular_height)

func _is_casual_intro_phase() -> bool:
	if not runtime_session_started or season_finished or not GameState.tutorials_enabled():
		return false
	return GameState.global_turn <= CASUAL_INTRO_MAX_GLOBAL_TURN

func _advanced_dice_controls_visible() -> bool:
	if not awaiting_destination or pending_roll.is_empty():
		return false
	return not _is_casual_intro_phase()

func _apply_casual_exposure_policy() -> void:
	var intro := _is_casual_intro_phase()
	rival_card.visible = not intro
	control_card.visible = not intro
	roster_panel.visible = not intro
	board_meta_column.visible = not intro or awaiting_destination or branch_choice_pending

func _branch_node_intent(node: Dictionary) -> String:
	match String(node.get("type", "")):
		"camp":
			return "回营整备"
		"bulletin":
			return "先看公告"
		"minigame":
			return "带队热身"
		"infirmary":
			return "疗养收口"
		"habitat":
			return "稳着推进"
		"settlement", "shop":
			return "补给 / 打听"
		"dojo":
			return "试试身手"
		"anomaly":
			return "冒险深入"
		"event":
			return "碰碰运气"
		"environment", "empty":
			return "顺路看看"
		_:
			return "继续前进"

func _format_route_choice_preview(node_ids: Array[int], use_intent_labels := false) -> String:
	var labels: Array[String] = []
	for node_id in node_ids.slice(0, 3):
		var node: Dictionary = board_lookup.get(int(node_id), {})
		if node.is_empty():
			continue
		var node_name := String(node.get("name", "未知节点"))
		if use_intent_labels:
			labels.append("%s（%s）" % [_branch_node_intent(node), node_name])
		else:
			labels.append(node_name)
	return " / ".join(labels)

func _clamp_panel_size(desired_size: Vector2, window_size: Vector2i, padding: int) -> Vector2:
	var safe_width := maxf(window_size.x - float(padding), 320.0)
	var safe_height := maxf(window_size.y - float(padding), 220.0)
	return Vector2(minf(desired_size.x, safe_width), minf(desired_size.y, safe_height))

func _ensure_synergy_banner() -> void:
	if _synergy_banner != null:
		return
	_synergy_banner = PanelContainer.new()
	_synergy_banner.name = "SynergyBanner"
	_synergy_banner.visible = false
	_synergy_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_banner.custom_minimum_size = Vector2(520, 120)
	_synergy_banner.anchors_preset = Control.PRESET_CENTER_TOP
	_synergy_banner.anchor_left = 0.5
	_synergy_banner.anchor_top = 0.0
	_synergy_banner.anchor_right = 0.5
	_synergy_banner.anchor_bottom = 0.0
	_synergy_banner.offset_left = -260.0
	_synergy_banner.offset_top = 28.0
	_synergy_banner.offset_right = 260.0
	_synergy_banner.offset_bottom = 148.0
	_synergy_banner.modulate = Color(1, 1, 1, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.62, 0.16, 0.94)
	style.border_color = Color(1.0, 0.89, 0.62, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	_synergy_banner.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	_synergy_banner.add_child(margin)
	_synergy_banner_label = RichTextLabel.new()
	_synergy_banner_label.bbcode_enabled = true
	_synergy_banner_label.scroll_active = true
	_synergy_banner_label.fit_content = false
	_synergy_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_banner_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_synergy_banner_label)
	overlay.add_child(_synergy_banner)
	_synergy_unit_glow_host = MarginContainer.new()
	_synergy_unit_glow_host.name = "SynergyUnitGlowHost"
	_synergy_unit_glow_host.visible = false
	_synergy_unit_glow_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_unit_glow_host.anchors_preset = Control.PRESET_CENTER_TOP
	_synergy_unit_glow_host.anchor_left = 0.5
	_synergy_unit_glow_host.anchor_top = 0.0
	_synergy_unit_glow_host.anchor_right = 0.5
	_synergy_unit_glow_host.anchor_bottom = 0.0
	_synergy_unit_glow_host.offset_left = -260.0
	_synergy_unit_glow_host.offset_top = 154.0
	_synergy_unit_glow_host.offset_right = 260.0
	_synergy_unit_glow_host.offset_bottom = 246.0
	_synergy_unit_glow_host.add_theme_constant_override("margin_left", 8)
	_synergy_unit_glow_host.add_theme_constant_override("margin_right", 8)
	overlay.add_child(_synergy_unit_glow_host)
	_synergy_unit_glow_row = HBoxContainer.new()
	_synergy_unit_glow_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_unit_glow_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_synergy_unit_glow_row.add_theme_constant_override("separation", 16)
	_synergy_unit_glow_host.add_child(_synergy_unit_glow_row)

func _ensure_stage_transition_overlay() -> void:
	if _stage_transition_layer != null:
		return
	_stage_transition_layer = Control.new()
	_stage_transition_layer.name = "StageTransitionLayer"
	_stage_transition_layer.visible = false
	_stage_transition_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_transition_layer.anchors_preset = Control.PRESET_FULL_RECT
	_stage_transition_layer.anchor_right = 1.0
	_stage_transition_layer.anchor_bottom = 1.0
	overlay.add_child(_stage_transition_layer)
	_stage_transition_backdrop = ColorRect.new()
	_stage_transition_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_transition_backdrop.color = Color(0.04, 0.07, 0.12, 0.0)
	_stage_transition_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_stage_transition_backdrop.anchor_right = 1.0
	_stage_transition_backdrop.anchor_bottom = 1.0
	_stage_transition_layer.add_child(_stage_transition_backdrop)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_stage_transition_layer.add_child(center)
	_stage_transition_panel = PanelContainer.new()
	_stage_transition_panel.custom_minimum_size = Vector2(720, 240)
	center.add_child(_stage_transition_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_stage_transition_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_stage_transition_title = Label.new()
	_stage_transition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_transition_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_stage_transition_title)
	_stage_transition_subtitle = RichTextLabel.new()
	_stage_transition_subtitle.bbcode_enabled = true
	_stage_transition_subtitle.scroll_active = true
	_stage_transition_subtitle.fit_content = true
	_stage_transition_subtitle.custom_minimum_size = Vector2(0, 104)
	_stage_transition_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_transition_subtitle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_stage_transition_subtitle)

func _should_show_boot_menu() -> bool:
	return DisplayServer.get_name() != "headless"

func _should_skip_runtime_tutorials() -> bool:
	return DisplayServer.get_name() == "headless" or not GameState.tutorials_enabled()

func _show_main_menu() -> void:
	CustomAssetRepository.sync_external_library()
	_menu_selected_slot_id = GameState.get_selected_run_slot_id()
	_refresh_main_menu()
	root_margin.hide()
	if is_instance_valid(_menu_custom_background):
		_menu_custom_background.visible = _menu_custom_background.texture != null
	if is_instance_valid(save_slot_panel):
		save_slot_panel.close_panel()
	menu_backdrop.show()
	menu_backdrop.move_to_front()
	main_menu_panel.show()
	main_menu_panel.move_to_front()
	_focus_main_menu_primary_button()

func _hide_main_menu() -> void:
	if is_instance_valid(_menu_custom_background):
		_menu_custom_background.hide()
	if is_instance_valid(save_slot_panel):
		save_slot_panel.close_panel()
	if is_instance_valid(input_settings_panel):
		input_settings_panel.hide()
	menu_backdrop.hide()
	main_menu_panel.hide()
	root_margin.show()
	_update_ui()
	_resume_onboarding_flow()
	story_director.try_flush_pending_quest_story_beats()

func _refresh_main_menu() -> void:
	var slot_meta := GameState.get_run_slot_meta(_menu_selected_slot_id)
	var slot_has_save := bool(slot_meta.get("exists", false))
	menu_title_label.text = localization_service.text("menu.title")
	if runtime_session_started:
		menu_subtitle_label.text = localization_service.text("menu.subtitle.runtime")
		continue_button.text = localization_service.text("menu.continue.season_end") if season_finished else localization_service.text("menu.continue.run")
		menu_new_game_button.text = "存档槽位"
		menu_new_game_button.disabled = false
		menu_action_hint_label.text = "当前槽位：%s\n%s" % [_slot_title(slot_meta), localization_service.text("menu.hint.runtime")]
		menu_run_summary_label.text = _build_main_menu_run_summary()
	else:
		menu_subtitle_label.text = localization_service.text("menu.subtitle.start")
		continue_button.text = "继续这格存档" if slot_has_save else localization_service.text("menu.start_game")
		menu_new_game_button.text = "存档槽位"
		menu_new_game_button.disabled = false
		menu_action_hint_label.text = "当前槽位：%s\n点“继续”就从这里接着玩；如果还是空的，就会直接在这里开始新远征。" % _slot_title(slot_meta)
		menu_run_summary_label.text = _build_saved_run_summary()
	settings_button.text = localization_service.text("menu.settings")
	menu_meta_summary_label.text = "%s\n\n%s" % [_build_main_menu_meta_summary(), _build_settings_summary()]
	_refresh_main_menu_visuals()

func _focus_main_menu_primary_button() -> void:
	if not main_menu_panel.visible:
		return
	for button in [continue_button, menu_new_game_button, settings_button]:
		button.focus_mode = Control.FOCUS_ALL
	continue_button.focus_neighbor_bottom = menu_new_game_button.get_path()
	menu_new_game_button.focus_neighbor_top = continue_button.get_path()
	menu_new_game_button.focus_neighbor_bottom = settings_button.get_path()
	settings_button.focus_neighbor_top = menu_new_game_button.get_path()
	if not continue_button.disabled:
		continue_button.grab_focus()
	elif not menu_new_game_button.disabled:
		menu_new_game_button.grab_focus()
	else:
		settings_button.grab_focus()

func _build_saved_run_summary() -> String:
	var slot_meta := GameState.get_run_slot_meta(_menu_selected_slot_id)
	if slot_meta.is_empty() or not bool(slot_meta.get("exists", false)):
		return "[b]%s[/b]\n这个槽位还没有存档。按“继续”会直接在这里开始一局新的远征。" % _slot_title(slot_meta)
	var summary: Dictionary = slot_meta.get("summary", {})
	if summary.is_empty():
		return "[b]%s[/b]\n这个槽位里有旧版本存档，但还没有可展示的摘要。" % _slot_title(slot_meta)
	var battle_slots: Array[String] = []
	for entry in summary.get("battle_slots", []):
		battle_slots.append(String(entry))
	if battle_slots.is_empty():
		battle_slots.append(localization_service.text("menu.summary.unassigned"))
	var lines: Array[String] = [
		"[b]%s[/b]" % _slot_title(slot_meta),
		"%s · 第 %d / %d 回合 · 第 %d 周 · 总回合 %d / 100" % [
			String(summary.get("season_name", "未知季节")),
			int(summary.get("season_turn", 1)),
			int(summary.get("season_length", 1)),
			int(summary.get("week_index", 1)),
			int(summary.get("global_turn", 1)),
		],
		localization_service.text("menu.summary.position", {"node": String(summary.get("node_name", localization_service.text("menu.summary.camp")))}),
		localization_service.text("menu.summary.battle_slots", {"value": " / ".join(battle_slots)}),
		localization_service.text("menu.summary.weekly_objective", {"value": String(summary.get("objective_summary", localization_service.text("menu.summary.no_objective")))}),
	]
	return "\n".join(lines)

func _slot_title(slot_meta: Dictionary) -> String:
	if slot_meta.is_empty():
		return "存档 1"
	return String(slot_meta.get("title", slot_meta.get("id", "存档")))

func _build_settings_summary() -> String:
	var window_mode := localization_service.text("settings.window.fullscreen") if bool(GameState.settings.get("fullscreen", false)) else localization_service.text("settings.window.windowed")
	var resolution_label := GameState.current_window_resolution_label()
	var motion_mode := localization_service.text("settings.motion.reduced") if GameState.prefers_reduced_motion() else localization_service.text("settings.motion.standard")
	var tutorial_mode := localization_service.text("settings.tutorials.on") if GameState.tutorials_enabled() else localization_service.text("settings.tutorials.off")
	var language_name := localization_service.language_name(GameState.current_language())
	var custom_bg_label := _custom_main_menu_background_label()
	var accept_binding := _settings_binding_label("ui_accept")
	var cancel_binding := _settings_binding_label("ui_cancel")
	var roll_binding := _settings_binding_label("game_roll")
	var menu_binding := _settings_binding_label("game_menu")
	return "\n".join([
		localization_service.text("settings.summary.title"),
		localization_service.text("settings.summary.window", {"value": window_mode}),
		localization_service.text("settings.summary.resolution", {"value": resolution_label}),
		localization_service.text("settings.summary.motion", {"value": motion_mode}),
		localization_service.text("settings.summary.tutorials", {"value": tutorial_mode}),
		localization_service.text("settings.summary.language", {"value": language_name}),
		localization_service.text("settings.summary.controls", {
			"accept": accept_binding,
			"cancel": cancel_binding,
			"roll": roll_binding,
			"menu": menu_binding,
		}),
		"自定义素材：%d 项 ｜ 图片 %d 张" % [CustomAssetRepository.get_asset_count(), CustomAssetRepository.get_image_count()],
		"主菜单背景：%s" % custom_bg_label,
	])

func _settings_binding_label(action_name: String) -> String:
	var labels: Array[String] = []
	for slot_index in range(2):
		var label := InputManager.describe_binding_slot(action_name, slot_index)
		if label.is_empty():
			continue
		labels.append(label)
	if labels.is_empty():
		return localization_service.text("settings.input.empty")
	return " / ".join(labels)

func _open_save_slot_panel(mode: String) -> void:
	if not is_instance_valid(save_slot_panel):
		return
	_save_slot_panel_mode = mode
	_refresh_save_slot_panel()
	save_slot_panel.show()
	save_slot_panel.move_to_front()

func _refresh_save_slot_panel(mode: String = "") -> void:
	if not is_instance_valid(save_slot_panel):
		return
	if not mode.is_empty():
		_save_slot_panel_mode = mode
	_menu_selected_slot_id = GameState.get_selected_run_slot_id() if _menu_selected_slot_id.is_empty() else _menu_selected_slot_id
	save_slot_panel.open_panel(GameState.list_run_slots(), _menu_selected_slot_id, _save_slot_panel_mode)

func _on_save_slot_selected(slot_id: String) -> void:
	_menu_selected_slot_id = slot_id
	GameState.set_selected_run_slot_id(slot_id)
	if main_menu_panel.visible:
		_refresh_main_menu()
	if is_instance_valid(save_slot_panel) and save_slot_panel.visible:
		_refresh_save_slot_panel()

func _on_save_slot_load_requested(slot_id: String) -> void:
	_load_run_state_from_save(slot_id)

func _on_save_slot_new_requested(slot_id: String) -> void:
	_start_new_game_in_slot(slot_id)

func _on_save_slot_save_requested(slot_id: String) -> void:
	if not runtime_session_started:
		return
	GameState.set_selected_run_slot_id(slot_id)
	_menu_selected_slot_id = GameState.get_selected_run_slot_id()
	GameState.save_run_payload(_build_run_save_payload(), _menu_selected_slot_id)
	if is_instance_valid(save_slot_panel):
		save_slot_panel.close_panel()
	if main_menu_panel.visible:
		_refresh_main_menu()
	_push_log("已保存到 %s。" % _slot_title(GameState.get_run_slot_meta(_menu_selected_slot_id)))

func _on_save_slot_delete_requested(slot_id: String) -> void:
	if runtime_session_started and not season_finished and slot_id == GameState.get_selected_run_slot_id():
		decision_panel.open_panel("无法删除当前运行槽位", "当前这局正在使用这个槽位。请先另存到别的槽位，或回到标题后再删。", [], "知道了")
		return
	GameState.clear_run_save(slot_id)
	if main_menu_panel.visible:
		_refresh_main_menu()
	if is_instance_valid(save_slot_panel) and save_slot_panel.visible:
		_refresh_save_slot_panel()

func _on_save_slot_closed() -> void:
	if is_instance_valid(save_slot_panel):
		save_slot_panel.close_panel()
	if main_menu_panel.visible:
		_refresh_main_menu()
		_focus_main_menu_primary_button()
	else:
		_update_ui()
	story_director.try_flush_pending_quest_story_beats()

func _start_new_game_in_slot(slot_id: String) -> void:
	GameState.set_selected_run_slot_id(slot_id)
	_menu_selected_slot_id = GameState.get_selected_run_slot_id()
	start_new_game()
	_save_run_state()
	_hide_main_menu()

func _open_settings_menu() -> void:
	CustomAssetRepository.sync_external_library()
	var window_label := localization_service.text("settings.window.to_windowed") if bool(GameState.settings.get("fullscreen", false)) else localization_service.text("settings.window.to_fullscreen")
	var motion_label := localization_service.text("settings.motion.to_standard") if GameState.prefers_reduced_motion() else localization_service.text("settings.motion.to_reduced")
	var tutorial_label := localization_service.text("settings.tutorials.enable") if not GameState.tutorials_enabled() else localization_service.text("settings.tutorials.disable")
	var imported_count := CustomAssetRepository.get_image_count()
	var resolution_choices: Array = []
	for preset in GameState.get_available_window_resolution_presets():
		var resolution_id := String(preset.get("id", ""))
		var resolution_label := String(preset.get("label", resolution_id))
		resolution_choices.append({
			"id": "set_window_resolution:%s" % resolution_id,
			"label": localization_service.text("settings.resolution.set", {"value": resolution_label}),
			"summary": localization_service.text("settings.current", {"value": resolution_label}),
			"disabled": resolution_id == GameState.current_window_resolution_id(),
		})
	var choices := [
		{
			"id": "toggle_fullscreen",
			"label": window_label,
			"summary": localization_service.text("settings.current", {"value": localization_service.text("settings.window.fullscreen") if bool(GameState.settings.get("fullscreen", false)) else localization_service.text("settings.window.windowed")}),
		},
	] + resolution_choices + [
		{
			"id": "toggle_motion",
			"label": motion_label,
			"summary": localization_service.text("settings.current", {"value": localization_service.text("settings.motion.reduced") if GameState.prefers_reduced_motion() else localization_service.text("settings.motion.standard")}),
		},
		{
			"id": "toggle_tutorials",
			"label": tutorial_label,
			"summary": localization_service.text("settings.current", {"value": localization_service.text("settings.tutorials.on") if GameState.tutorials_enabled() else localization_service.text("settings.tutorials.off")}),
		},
		{
			"id": "set_language_zh_cn",
			"label": localization_service.text("settings.language.zh_cn"),
			"summary": localization_service.text("settings.current", {"value": localization_service.language_name("zh_cn")}),
		},
		{
			"id": "set_language_ja_jp",
			"label": localization_service.text("settings.language.ja_jp"),
			"summary": localization_service.text("settings.current", {"value": localization_service.language_name("ja_jp")}),
		},
		{
			"id": "set_language_en_us",
			"label": localization_service.text("settings.language.en_us"),
			"summary": localization_service.text("settings.current", {"value": localization_service.language_name("en_us")}),
		},
		{
			"id": "open_input_settings",
			"label": localization_service.text("settings.input.open"),
			"summary": localization_service.text("settings.input.summary"),
		},
		{
			"id": "open_custom_asset_import",
			"label": "导入自定义素材",
			"summary": "从本地导入图片 / 音频 / 字体 / 视频 / 文件到 user://custom_assets",
		},
		{
			"id": "select_main_menu_bg",
			"label": "选择主菜单背景",
			"summary": "当前：%s ｜ 已导入 %d 张" % [_custom_main_menu_background_label(), imported_count],
			"disabled": imported_count <= 0,
		},
		{
			"id": "clear_main_menu_bg",
			"label": "恢复默认背景",
			"summary": "清除主菜单背景绑定，回到默认遮罩。",
			"disabled": CustomAssetRepository.get_slot_binding("main_menu_bg").is_empty(),
		},
	]
	pending_context = {"kind": "menu_settings"}
	decision_panel.open_panel(localization_service.text("settings.title"), localization_service.text("settings.body"), choices, localization_service.text("settings.back"))

func _apply_menu_setting(choice_id: String) -> void:
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
			_open_input_settings_panel()
		"open_custom_asset_import":
			reopen_settings = false
			_open_asset_import_dialog()
		"select_main_menu_bg":
			reopen_settings = false
			_open_main_menu_background_picker()
		"clear_main_menu_bg":
			reopen_settings = false
			_clear_main_menu_background_binding()
		_:
			if choice_id.begins_with("set_window_resolution:"):
				var resolution_id := choice_id.substr("set_window_resolution:".length())
				if GameState.is_valid_window_resolution_id(resolution_id):
					GameState.set_setting("window_resolution", resolution_id)
			else:
				return
	_refresh_main_menu()
	if reopen_settings:
		_open_settings_menu()

func _open_input_settings_panel() -> void:
	if not is_instance_valid(input_settings_panel):
		return
	input_settings_panel.open_panel()

func _on_input_settings_panel_closed() -> void:
	if main_menu_panel.visible:
		_refresh_main_menu()
		_open_settings_menu()

func _custom_main_menu_background_label() -> String:
	var asset_id := CustomAssetRepository.get_slot_binding("main_menu_bg")
	if asset_id.is_empty():
		return "默认"
	var image_info := CustomAssetRepository.get_image(asset_id)
	if image_info.is_empty():
		return "默认"
	return String(image_info.get("label", asset_id))

func _refresh_main_menu_visuals() -> void:
	if not is_instance_valid(_menu_custom_background):
		return
	var texture := CustomAssetRepository.get_bound_texture("main_menu_bg")
	_menu_custom_background.texture = texture
	_menu_custom_background.visible = texture != null and main_menu_panel.visible

func _open_asset_import_dialog() -> void:
	if not is_instance_valid(_asset_file_dialog):
		return
	_asset_file_dialog.popup_centered_ratio(0.82)

func _on_asset_import_canceled() -> void:
	if main_menu_panel.visible:
		_open_settings_menu()

func _custom_asset_kind_label(kind: String) -> String:
	return CustomAssetRepository.get_asset_kind_label(kind)

func _on_asset_files_selected(paths: PackedStringArray) -> void:
	var results := CustomAssetRepository.import_assets(paths)
	var success_rows: Array = []
	var image_rows: Array = []
	var fail_lines: Array[String] = []
	var kind_counts := {}
	for row in results:
		if bool(row.get("ok", false)):
			success_rows.append(row)
			var kind := String(row.get("kind", "file"))
			kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
			if kind == "image":
				image_rows.append(row)
		else:
			fail_lines.append("- %s：%s" % [
				String(row.get("path", "")),
				String(row.get("message", "失败")),
			])
	_refresh_main_menu()
	if success_rows.is_empty():
		pending_context = {"kind": "custom_asset_result", "on_close": "reopen_settings"}
		var fail_body := "没有成功导入任何素材。"
		if not fail_lines.is_empty():
			fail_body += "\n\n%s" % "\n".join(fail_lines)
		decision_panel.open_panel("素材导入失败", fail_body, [], "返回设置")
		return
	var body_lines: Array[String] = ["成功导入 %d 个素材。" % success_rows.size()]
	var ordered_kinds := ["image", "audio", "font", "video", "file"]
	var imported_kind_lines: Array[String] = []
	for kind in ordered_kinds:
		var count := int(kind_counts.get(kind, 0))
		if count <= 0:
			continue
		imported_kind_lines.append("%s %d" % [_custom_asset_kind_label(kind), count])
	if not imported_kind_lines.is_empty():
		body_lines.append("类型分布：%s" % " / ".join(imported_kind_lines))
	if not fail_lines.is_empty():
		body_lines.append("")
		body_lines.append("失败项目：")
		for line in fail_lines:
			body_lines.append(line)
	if image_rows.is_empty():
		pending_context = {"kind": "custom_asset_result", "on_close": "reopen_settings"}
		decision_panel.open_panel("素材导入完成", "\n".join(body_lines), [], "返回设置")
		return
	body_lines.append("")
	body_lines.append("你也可以顺手把这次导入的图片绑定成主菜单背景。")
	var choices := _build_custom_background_choices(image_rows)
	pending_context = {"kind": "custom_asset_bind_menu", "on_close": "reopen_settings"}
	decision_panel.open_panel("素材导入完成", "\n".join(body_lines), choices, "返回设置")

func _open_main_menu_background_picker() -> void:
	CustomAssetRepository.sync_external_library()
	var images := CustomAssetRepository.list_images()
	if images.is_empty():
		pending_context = {"kind": "custom_asset_picker", "on_close": "reopen_settings"}
		decision_panel.open_panel("还没有可用素材", "先导入至少 1 张图片，之后才能绑定到主菜单背景。", [], "返回设置")
		return
	pending_context = {"kind": "custom_asset_bind_menu", "on_close": "reopen_settings"}
	decision_panel.open_panel(
		"选择主菜单背景",
		"已导入 %d 张图片。\n当前绑定：%s" % [images.size(), _custom_main_menu_background_label()],
		_build_custom_background_choices(images),
		"返回设置"
	)

func _build_custom_background_choices(image_rows: Array) -> Array:
	var choices: Array = []
	for row in image_rows:
		var image_info := Dictionary(row)
		var asset_id := String(image_info.get("id", ""))
		if asset_id.is_empty():
			continue
		choices.append({
			"id": asset_id,
			"label": String(image_info.get("label", asset_id)),
			"summary": "%dx%d ｜ 设为主菜单背景" % [
				int(image_info.get("width", 0)),
				int(image_info.get("height", 0)),
			],
		})
	return choices

func _bind_main_menu_background(asset_id: String) -> void:
	CustomAssetRepository.bind_slot("main_menu_bg", asset_id)
	_refresh_main_menu()
	pending_context = {"kind": "custom_asset_bound", "on_close": "reopen_settings"}
	decision_panel.open_panel(
		"主菜单背景已更新",
		"已将 %s 设为主菜单背景。" % _custom_main_menu_background_label(),
		[],
		"返回设置"
	)

func _clear_main_menu_background_binding() -> void:
	CustomAssetRepository.clear_slot("main_menu_bg")
	_refresh_main_menu()
	pending_context = {"kind": "custom_asset_cleared", "on_close": "reopen_settings"}
	decision_panel.open_panel("已恢复默认背景", "主菜单背景已清除自定义绑定。", [], "返回设置")

func _resume_onboarding_flow() -> void:
	if _should_skip_runtime_tutorials() or season_finished:
		return
	if starter_choice_pending:
		_open_starter_selection()
		return
	if not GameState.has_completed_tutorial("run_intro"):
		_show_tutorial_popup("run_intro")

func _open_starter_selection() -> void:
	var choices := []
	for species_id in STARTER_SPECIES_IDS:
		var species := DataRepository.get_species(species_id)
		if species.is_empty():
			continue
		var profile := GameData.get_species_synergy_profile(species_id)
		choices.append({
			"id": species_id,
			"label": String(species.get("name", species_id)),
			"summary": "%s ｜ %s ｜ 会直接放进 1 号出战位" % [
				_format_type_tags(profile.get("elements", [])),
				_format_role_tags(profile.get("job_tags", [])),
			],
		})
	pending_context = {"kind": "starter_select", "on_close": "starter_random"}
	decision_panel.open_panel("起始伙伴选择", "新远征开始前，从后备里再挑 1 只起始伙伴。被选中的伙伴会直接放入 1 号出战位，帮你决定这轮前期节奏。", choices, "随机分配")

func _apply_starter_choice(species_id: String, random_choice := false) -> void:
	if species_id.is_empty() or starter_choice_done:
		return
	var species := DataRepository.get_species(species_id)
	if species.is_empty():
		return
	starter_choice_pending = false
	starter_choice_done = true
	starter_companion_uid = GameState.add_companion(species_id)
	GameState.set_party_slot(0, starter_companion_uid)
	var profile := GameData.get_species_synergy_profile(species_id)
	var mode_text := "随机分配" if random_choice else "已选择"
	var body_lines: Array[String] = [
		"[b]%s[/b] %s" % [mode_text, String(species.get("name", species_id))],
		"属性：%s ｜ 职能：%s" % [
			_format_type_tags(profile.get("elements", [])),
			_format_role_tags(profile.get("job_tags", [])),
		],
		"它已经进入 1 号出战位，前期路线和第一场战斗会围绕它展开。",
	]
	_push_log("起始伙伴确定为 %s，本轮开局会更偏向它的战斗与经营节奏。" % String(species.get("name", species_id)))
	_save_run_state()
	pending_context = {"kind": "starter_result", "on_close": "show_run_intro"}
	decision_panel.open_panel("起始伙伴已定", "\n".join(body_lines), [], "开始远征")

func _show_tutorial_popup(tutorial_id: String, on_close: String = "none") -> void:
	var tutorial := _tutorial_entry(tutorial_id)
	if tutorial.is_empty():
		return
	GameState.mark_tutorial_completed(tutorial_id)
	pending_context = {"kind": "tutorial_popup", "tutorial_id": tutorial_id, "on_close": on_close}
	decision_panel.open_panel(
		String(tutorial.get("title", "教学")),
		String(tutorial.get("body", "")),
		[],
		String(tutorial.get("close_text", "知道了"))
	)

func _tutorial_entry(tutorial_id: String) -> Dictionary:
	match tutorial_id:
		"run_intro":
			return {
				"title": "初来雾野市",
				"close_text": "出门走走",
				"body": "[b]刚来雾野市时[/b]\n先出门走一走，看看今天会碰上谁、会停在哪儿。\n\n[b]平时怎么看东西[/b]\n身上的物资、手边记着的事，还有伙伴近况，都收在 [b]雾野小本[/b] 里。\n不用一次记太多，缺什么再翻就行。\n\n[b]第一天怎么过[/b]\n先掷一次骰，找个不那么紧张的地方落脚。路过落脚处时，顺手把人和东西安顿一下；到了别处，就先接住眼前发生的小事。"
			}
		"management_intro":
			return {
				"title": "先把日子安顿下来",
				"close_text": "接着收拾",
				"body": "[b]落脚处是干什么的[/b]\n路过这里时，你会顺手把伙伴、住处和手边的事理一理。别的地方更像是在外头碰见的一段段小插曲。\n\n[b]平时最重要的事[/b]\n先把身边同行的人安稳下来，再慢慢想谁适合住下、谁适合帮忙。\n\n[b]东西去哪看[/b]\n饥饿、物资、金钱，还有各地的近况，都放在 [b]雾野小本 -> 背包[/b] 里。"
			}
		"battle_intro":
			return {
				"title": "真闹起来时怎么办",
				"close_text": "去应付一下",
				"body": "[b]起冲突时[/b]\n真闹起来时，就是两边的人正面对上。轮到你出手，就先挑这一手要怎么做，再点一下对象。\n\n[b]最该先看的[/b]\n谁先动、谁还能撑、谁现在更危险，先看这三样就够了。\n\n[b]打之前能做什么[/b]\n想换同行、补状态，或者先把人安顿好，就回 [b]雾野小本[/b] 看看，或者等下次回到落脚处再慢慢收拾。"
			}
		_:
			return {}

func _open_pending_tutorial_battle() -> void:
	if pending_tutorial_battle_config.is_empty():
		return
	var battle_config := pending_tutorial_battle_config.duplicate(true)
	var battle_source := pending_tutorial_battle_source
	var battle_log := pending_tutorial_battle_log
	pending_tutorial_battle_config.clear()
	pending_tutorial_battle_source = ""
	pending_tutorial_battle_log = ""
	if not battle_log.is_empty():
		_push_log(battle_log)
	pending_battle_source = battle_source
	battle_panel.start_battle(battle_config)

func _start_battle_with_tutorial(battle_config: Dictionary, battle_source: String, battle_log: String) -> void:
	if battle_config.is_empty():
		return
	decision_panel.hide()
	if _should_skip_runtime_tutorials() or GameState.has_completed_tutorial("battle_intro"):
		if not battle_log.is_empty():
			_push_log(battle_log)
		pending_battle_source = battle_source
		battle_panel.start_battle(battle_config)
		return
	pending_tutorial_battle_config = battle_config.duplicate(true)
	pending_tutorial_battle_source = battle_source
	pending_tutorial_battle_log = battle_log
	_show_tutorial_popup("battle_intro", "start_pending_battle")

func _on_main_menu_requested() -> void:
	if _is_modal_open():
		return
	_show_main_menu()

func _on_continue_pressed() -> void:
	if runtime_session_started:
		_hide_main_menu()
		return
	if GameState.has_run_save(_menu_selected_slot_id):
		_load_run_state_from_save(_menu_selected_slot_id)
		return
	_start_new_game_in_slot(_menu_selected_slot_id)

func _on_menu_new_game_pressed() -> void:
	_open_save_slot_panel("runtime" if runtime_session_started else "boot")

func _on_settings_pressed() -> void:
	_open_settings_menu()

func start_new_game() -> void:
	DataRepository.load_all()
	GameState.reset_for_new_season()
	GameState.set_run_modifiers(run_modifier_service.choose_run_modifiers(1))
	GameState.apply_system_rewards(run_modifier_service.apply_starting_bonus(GameState.run_modifiers))
	_refresh_board_region(true)
	runtime_session_started = true
	season_finished = false
	awaiting_destination = false
	current_node_id = GameState.current_board_node_id
	current_visit_habitat_id = ""
	current_encounter.clear()
	pending_npc_duel_id = ""
	pending_battle_source = ""
	pending_environment_battle.clear()
	last_encounter_action_id = ""
	pending_context.clear()
	pending_roll.clear()
	reachable_paths.clear()
	_queued_auto_travel_target = -1
	branch_choice_pending = false
	_queued_roll_start = false
	pending_route_steps_remaining = 0
	pending_route_history.clear()
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1
	pending_travel_path.clear()
	pending_travel_target = -1
	anchor_override_active = false
	starter_choice_pending = not _should_skip_runtime_tutorials()
	starter_choice_done = false
	starter_companion_uid = ""
	pending_tutorial_battle_config.clear()
	pending_tutorial_battle_source = ""
	pending_tutorial_battle_log = ""
	_last_ai_turn_report.clear()
	story_director.reset()
	decision_panel.hide()
	base_panel.hide()
	system_panel.hide()
	_active_synergy_snapshot.clear()
	_synergy_fx_ready = false
	if _synergy_unit_glow_host != null:
		_synergy_unit_glow_host.visible = false
	if _stage_transition_layer != null:
		_stage_transition_layer.visible = false
	_assign_weekly_objective()
	_maybe_notify_annual_competition_reminder()
	_push_log("%s的日子开始了。先慢慢在城里走走，认识人，也给自己找个落脚的节奏。" % _season_name())
	for modifier_line in run_modifier_service.format_lines(GameState.run_modifiers):
		_push_log("本局词缀：%s" % modifier_line)
	for line in ai_player_service.build_status_lines(board_lookup, 3):
		_push_log("其他远征队：%s" % line)
	_begin_next_day()

func _load_run_state_from_save(slot_id: String = "") -> void:
	var resolved_slot_id := slot_id if not slot_id.is_empty() else _menu_selected_slot_id
	GameState.set_selected_run_slot_id(resolved_slot_id)
	_menu_selected_slot_id = GameState.get_selected_run_slot_id()
	var payload := GameState.load_run_payload(_menu_selected_slot_id)
	if payload.is_empty():
		pending_context.clear()
		decision_panel.open_panel("没有存档", "这格还没有旅程记录。点“继续”就会直接从这里开始新远征。", [], "返回开始界面")
		return
	_apply_run_payload(payload)
	_hide_main_menu()
	_push_log("已从 %s 接上这段旅程。" % _slot_title(GameState.get_run_slot_meta(_menu_selected_slot_id)))

func _apply_run_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	DataRepository.load_all()
	GameState.apply_runtime_snapshot(payload.get("game_state", {}))
	_restore_scene_runtime_state(payload.get("scene_state", {}))
	runtime_session_started = true
	_refresh_board_region(true)
	_maybe_notify_annual_competition_reminder()
	current_node_id = GameState.current_board_node_id
	_update_ui()
	return true

func _restore_scene_runtime_state(scene_state: Dictionary) -> void:
	season_finished = bool(scene_state.get("season_finished", false))
	awaiting_destination = bool(scene_state.get("awaiting_destination", false))
	current_visit_habitat_id = String(scene_state.get("current_visit_habitat_id", ""))
	current_encounter = {}
	pending_npc_duel_id = ""
	pending_battle_source = ""
	pending_environment_battle.clear()
	last_encounter_action_id = ""
	pending_context.clear()
	pending_roll.clear()
	reachable_paths.clear()
	board_anim_locked = false
	pending_travel_path.clear()
	pending_travel_target = -1
	_queued_auto_travel_target = -1
	branch_choice_pending = false
	_queued_roll_start = false
	pending_route_steps_remaining = 0
	pending_route_history.clear()
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1
	anchor_override_active = false
	camp_panel_requires_finish = false
	starter_choice_pending = bool(scene_state.get("starter_choice_pending", false))
	starter_choice_done = bool(scene_state.get("starter_choice_done", false))
	starter_companion_uid = String(scene_state.get("starter_companion_uid", ""))
	pending_tutorial_battle_config.clear()
	pending_tutorial_battle_source = ""
	pending_tutorial_battle_log = ""
	_last_ai_turn_report.clear()
	story_director.reset()
	decision_panel.hide()
	base_panel.hide()
	system_panel.hide()
	_active_synergy_snapshot.clear()
	_synergy_fx_ready = false
	if _synergy_unit_glow_host != null:
		_synergy_unit_glow_host.visible = false
	if _stage_transition_layer != null:
		_stage_transition_layer.visible = false

func _save_run_state() -> void:
	if DisplayServer.get_name() == "headless" or not runtime_session_started or season_finished:
		return
	GameState.save_run_payload(_build_run_save_payload(), GameState.get_selected_run_slot_id())

func _build_run_save_payload() -> Dictionary:
	return {
		"version": 1,
		"summary": _build_run_save_summary(),
		"scene_state": {
			"season_finished": season_finished,
			"awaiting_destination": awaiting_destination,
			"current_visit_habitat_id": current_visit_habitat_id,
			"starter_choice_pending": starter_choice_pending,
			"starter_choice_done": starter_choice_done,
			"starter_companion_uid": starter_companion_uid,
		},
		"game_state": GameState.build_runtime_snapshot(),
	}

func _build_run_save_summary() -> Dictionary:
	var node: Dictionary = board_lookup.get(current_node_id, {})
	return {
		"season_name": _season_name(),
		"season_turn": GameState.season_turn,
		"season_length": GameState.season_length,
		"week_index": GameState.week_index,
		"global_turn": GameState.global_turn,
		"node_name": String(node.get("name", "营地")),
		"battle_slots": _battle_slot_names(),
		"objective_summary": weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress),
	}

func _build_world_nodes() -> Array:
	var nodes := board_progression_service.get_nodes()
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var habitat_id := String(node.get("habitat_id", ""))
		if not habitat_id.is_empty():
			var habitat := DataRepository.get_habitat(habitat_id)
			if habitat.is_empty():
				continue
			if String(node.get("name", "")).is_empty():
				node["name"] = habitat.get("name", node.get("name", ""))
			if String(node.get("type", "")).is_empty():
				node["type"] = habitat.get("type", node.get("type", ""))
			if String(node.get("description", "")).is_empty():
				node["description"] = _description_for_habitat(habitat)
			if not node.has("travel_cost"):
				node["travel_cost"] = int(habitat.get("travel_cost", 1))
		nodes[index] = node
	return nodes

func _refresh_board_region(reset_position: bool) -> void:
	board_progression_service.set_region_for_season(GameState.season_id)
	world_nodes = _build_world_nodes()
	board_lookup = _build_board_lookup()
	board_view.setup(world_nodes)
	var region := board_progression_service.get_region()
	var start_node_id := board_progression_service.get_start_node_id()
	if reset_position:
		GameState.set_board_region(String(region.get("id", "")), start_node_id)
		GameState.reveal_board_nodes(region.get("revealed_nodes", []))
		GameState.reveal_board_nodes(board_progression_service.expand_reveal_from(start_node_id))
	current_node_id = GameState.current_board_node_id
	board_view.set_current_node(current_node_id, true)
	board_view.hide_observer()
	_initialize_board_threats()

func _initialize_board_threats() -> void:
	threat_service.setup_for_season(GameState.season_id)

func _resolve_board_threat_turn() -> void:
	var report := threat_service.advance_turn(GameState.season_turn, board_lookup, current_node_id)
	for line in report.get("lines", []):
		_push_log("敌方推进：%s" % String(line))

func _blocked_node_ids() -> Array[int]:
	return threat_service.get_blocked_node_ids()

func _filter_blocked_selectable_nodes(candidate_nodes: Array[int]) -> Array[int]:
	var blocked := _blocked_node_ids()
	if blocked.is_empty():
		return candidate_nodes.duplicate()
	var filtered: Array[int] = []
	for node_id in candidate_nodes:
		if blocked.has(node_id):
			continue
		filtered.append(node_id)
	return filtered

func _get_blocked_reachable_nodes() -> Array[int]:
	var blocked := _blocked_node_ids()
	if blocked.is_empty():
		return []
	var blocked_reachable: Array[int] = []
	for node_id in _reachable_selectable_nodes():
		if blocked.has(node_id):
			blocked_reachable.append(node_id)
	return blocked_reachable

func _assign_weekly_objective() -> void:
	var objective := weekly_cycle_service.pick_objective(GameState.season_id, GameState.week_index)
	GameState.set_weekly_objective(objective)
	if objective.is_empty():
		return
	_push_log("第 %d 周目标：%s。" % [GameState.week_index, String(objective.get("title", "本周目标"))])

func _build_board_lookup() -> Dictionary:
	var lookup := {}
	for node in world_nodes:
		lookup[int(node.get("id", -1))] = node
	return lookup

func _description_for_habitat(habitat: Dictionary) -> String:
	var mood_tags: Array = habitat.get("mood_tags", [])
	var actions: Array = habitat.get("visit_actions", [])
	var recommended_rank := int(habitat.get("recommended_rank", 0))
	var head := "、".join(mood_tags) if not mood_tags.is_empty() else "当前没有记录到明显气氛"
	if recommended_rank > 0:
		head += "\n推荐据点等级：%d" % recommended_rank
	return "%s\n可做的事：%s" % [head, " / ".join(actions)]

func _begin_next_day() -> void:
	if GameState.day_index > GameState.season_length:
		if GameState.advance_to_next_season():
			_refresh_board_region(true)
			_assign_weekly_objective()
			_maybe_notify_annual_competition_reminder()
			_play_stage_transition("%s来临" % _season_name(), "区域棋盘、周目标与路线分叉已经刷新。", _season_fx_color(GameState.season_id))
			_push_log("%s来临，区域棋盘、周目标与路线分叉已刷新。" % _season_name())
		else:
			_finish_season()
			return
	awaiting_destination = false
	current_node_id = GameState.current_board_node_id
	current_visit_habitat_id = ""
	current_encounter.clear()
	pending_npc_duel_id = ""
	pending_battle_source = ""
	pending_environment_battle.clear()
	last_encounter_action_id = ""
	pending_roll.clear()
	reachable_paths.clear()
	_queued_auto_travel_target = -1
	branch_choice_pending = false
	_queued_roll_start = false
	pending_route_steps_remaining = 0
	pending_route_history.clear()
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1
	pending_travel_path.clear()
	pending_travel_target = -1
	anchor_override_active = false
	var weather_pool: Array = GameState.get_current_season_rule().get("weather_pool", WEATHER_ORDER)
	var next_weather: String = String(weather_pool[rng.randi_range(0, weather_pool.size() - 1)]) if not weather_pool.is_empty() else "clear"
	var next_time: String = String(TIME_ORDER[rng.randi_range(0, TIME_ORDER.size() - 1)])
	if GameState.day_index == 1:
		next_weather = String(weather_pool[0]) if not weather_pool.is_empty() else "clear"
		next_time = "day"
	GameState.set_daily_conditions(next_weather, next_time)
	if GameState.weekly_objective.is_empty():
		_assign_weekly_objective()
	_sync_npc_routes_for_day()
	_push_log("[%s 第 %d / %d 回合 ｜ 第 %d 周] 天气：%s，时段：%s。" % [
		_season_name(),
		GameState.season_turn,
		GameState.season_length,
		GameState.week_index,
		_weather_name(GameState.weather_id),
		_time_name(GameState.time_of_day),
	])
	_update_ui()
	_save_run_state()

func _sync_npc_routes_for_day() -> void:
	var report := npc_route_service.sync_daily_positions()
	for line in report.get("lines", []):
		_push_log("访客动向：%s" % String(line))

func _on_start_day_pressed() -> void:
	if season_finished or _is_modal_open():
		return
	if awaiting_destination or branch_choice_pending:
		return
	pending_roll = dice_service.roll()
	_queued_auto_travel_target = -1
	_queued_roll_start = false
	_apply_current_roll_routes()
	_update_ui()
	if DisplayServer.get_name() != "headless":
		dice_roll_panel.open_panel(pending_roll, _build_dice_roll_panel_state(), "roll")

func _on_plus_pressed() -> void:
	if pending_roll.is_empty() or not awaiting_destination:
		return
	if not GameState.consume_adjust_point():
		return
	var result := dice_service.apply_adjust(pending_roll, 1)
	if not bool(result.get("ok", false)):
		GameState.season_adjust_points += 1
		return
	pending_roll = result.get("roll", {}).duplicate(true)
	_apply_current_roll_routes()
	_update_ui()
	if dice_roll_panel.visible:
		dice_roll_panel.refresh_panel(pending_roll, _build_dice_roll_panel_state(), "adjust")

func _on_minus_pressed() -> void:
	if pending_roll.is_empty() or not awaiting_destination:
		return
	if not GameState.consume_adjust_point():
		return
	var result := dice_service.apply_adjust(pending_roll, -1)
	if not bool(result.get("ok", false)):
		GameState.season_adjust_points += 1
		return
	pending_roll = result.get("roll", {}).duplicate(true)
	_apply_current_roll_routes()
	_update_ui()
	if dice_roll_panel.visible:
		dice_roll_panel.refresh_panel(pending_roll, _build_dice_roll_panel_state(), "adjust")

func _on_reroll_pressed() -> void:
	if pending_roll.is_empty() or not awaiting_destination:
		return
	if not GameState.consume_weekly_reroll():
		return
	pending_roll = dice_service.reroll(pending_roll)
	_apply_current_roll_routes()
	_update_ui()
	if dice_roll_panel.visible:
		dice_roll_panel.refresh_panel(pending_roll, _build_dice_roll_panel_state(), "reroll")

func _build_dice_roll_panel_state() -> Dictionary:
	var selectable_nodes := _filter_blocked_selectable_nodes(_reachable_selectable_nodes())
	var intro_copy := _is_casual_intro_phase()
	var route_preview := _format_route_choice_preview(selectable_nodes, intro_copy and awaiting_destination)
	var remaining_rerolls := maxi(0, GameState.weekly_reroll_limit - GameState.weekly_reroll_count)
	var body_lines: Array[String] = [
		"[b]当前骰面[/b] %s" % dice_service.describe_roll(pending_roll),
	]
	if intro_copy:
		body_lines.append("[b]前几步先顺着路走就好[/b]。确认后会一路往前，只有碰到岔路口才会停下来让你选。")
		if awaiting_destination and not route_preview.is_empty():
			body_lines.append("[b]这一步偏向[/b] %s" % route_preview)
		body_lines.append("修正和重掷会在熟悉几回合后再放出来。")
	else:
		body_lines.append("[b]剩余修正点[/b] %d ｜ [b]剩余周重掷[/b] %d" % [GameState.season_adjust_points, remaining_rerolls])
		if awaiting_destination and not route_preview.is_empty():
			body_lines.append("[b]可能停下的落点[/b] %s" % route_preview)
			body_lines.append("确认后会开始逐步前进，不会先选终点；只有走到真分叉时才需要决定方向。")
		elif anchor_override_active:
			body_lines.append("[b]锚定改线已触发[/b] 当前路线来自已显露节点，不是常规步数落点。")
		else:
			body_lines.append("[b]当前没有安全落点[/b] 这次结果只作为展示，你可以关掉面板后等待下一次掷骰。")
	return {
		"title": "骰子停好了",
		"subtitle": "先看看今天会走多远" if intro_copy else "这一回合会走到哪儿",
		"body": "\n".join(body_lines),
		"confirm_text": "开始前进" if awaiting_destination else "收起结果",
		"advanced_controls_visible": _advanced_dice_controls_visible(),
		"can_plus": awaiting_destination and GameState.season_adjust_points > 0 and int(pending_roll.get("value", 0)) < 6,
		"can_minus": awaiting_destination and GameState.season_adjust_points > 0 and int(pending_roll.get("value", 0)) > 1,
		"can_reroll": awaiting_destination and GameState.weekly_reroll_count < GameState.weekly_reroll_limit,
	}

func _on_dice_roll_confirmed() -> void:
	_queued_roll_start = true

func _on_dice_roll_panel_closed() -> void:
	_update_ui()
	if not _queued_roll_start or _is_modal_open():
		return
	_queued_roll_start = false
	_start_roll_travel()

func _on_dice_roll_plus_requested() -> void:
	_on_plus_pressed()

func _on_dice_roll_minus_requested() -> void:
	_on_minus_pressed()

func _on_dice_roll_reroll_requested() -> void:
	_on_reroll_pressed()

func _apply_current_roll_routes() -> void:
	_queued_auto_travel_target = -1
	_queued_roll_start = false
	branch_choice_pending = false
	pending_route_steps_remaining = 0
	pending_route_history.clear()
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1
	reachable_paths = board_progression_service.get_reachable_paths(current_node_id, int(pending_roll.get("value", 0)))
	anchor_override_active = false
	var blocked_before_anchor := _get_blocked_reachable_nodes()
	var selectable := _filter_blocked_selectable_nodes(_reachable_selectable_nodes())
	var anchor_target := -1
	if selectable.is_empty() and GameState.anchor_points > 0:
		anchor_target = _pick_anchor_override_target()
	if anchor_target >= 0 and GameState.consume_anchor_point():
		anchor_override_active = true
		reachable_paths.clear()
		reachable_paths[anchor_target] = board_progression_service.get_shortest_path(current_node_id, anchor_target)
		selectable = _filter_blocked_selectable_nodes(_reachable_selectable_nodes())
		if not reachable_paths.is_empty():
			if not blocked_before_anchor.is_empty():
				_push_log("原来的路被敌对群堵住了，顺手花掉 1 个锚定点，改走最近的安全落点。")
			else:
				_push_log("这次落不到安全点，顺手花掉 1 个锚定点，改走最近的安全落点。")
	awaiting_destination = not selectable.is_empty()
	if not awaiting_destination:
		if not _get_blocked_reachable_nodes().is_empty():
			_push_log("这次掷骰的可达节点都被敌对群占住了，先改路线或等待下一回合。")
		else:
			_push_log("这次掷骰没有形成可用路线，先调整队伍或等待下一回合。")

func _pick_anchor_override_target() -> int:
	var blocked := _blocked_node_ids()
	var candidates: Array = []
	for raw_node_id in GameState.revealed_board_nodes:
		var node_id := int(raw_node_id)
		if node_id == current_node_id or blocked.has(node_id) or board_progression_service.is_node_locked(node_id):
			continue
		var node: Dictionary = board_lookup.get(node_id, {})
		if String(node.get("type", "")) == "camp":
			var camp_path := board_progression_service.get_shortest_path(current_node_id, node_id)
			if camp_path.size() >= 2:
				candidates.append({
					"node_id": node_id,
					"path": camp_path,
				})
			continue
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty() or not GameState.is_habitat_unlocked(habitat_id):
			continue
		var path := board_progression_service.get_shortest_path(current_node_id, node_id)
		if path.size() < 2:
			continue
		candidates.append({
			"node_id": node_id,
			"path": path,
		})
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_path: Array = a.get("path", [])
		var b_path: Array = b.get("path", [])
		if a_path.size() != b_path.size():
			return a_path.size() < b_path.size()
		return int(a.get("node_id", -1)) < int(b.get("node_id", -1))
	)
	return int(candidates[0].get("node_id", -1))

func _start_roll_travel() -> void:
	if pending_roll.is_empty() or not awaiting_destination:
		return

	branch_choice_pending = false
	pending_route_history = [current_node_id]
	pending_route_options.clear()
	pending_route_forced_path.clear()
	pending_route_forced_index = -1

	if anchor_override_active and reachable_paths.size() == 1:
		var only_target := int(reachable_paths.keys()[0])
		for path_node_id in reachable_paths.get(only_target, []):
			pending_route_forced_path.append(int(path_node_id))
		pending_route_forced_index = 0
		pending_route_steps_remaining = maxi(0, pending_route_forced_path.size() - 1)
	else:
		pending_route_steps_remaining = int(pending_roll.get("value", 0))

	awaiting_destination = false
	_continue_roll_travel()

func _continue_roll_travel() -> void:
	if pending_route_steps_remaining <= 0:
		_finalize_roll_arrival()
		return

	if not pending_route_forced_path.is_empty():
		if pending_route_forced_index + 1 >= pending_route_forced_path.size():
			_finalize_roll_arrival()
			return
		var next_id := int(pending_route_forced_path[pending_route_forced_index + 1])
		pending_route_forced_index += 1
		_travel_one_step_to(next_id)
		return

	var options := board_progression_service.get_next_route_options(
		current_node_id,
		pending_route_steps_remaining,
		pending_route_history
	)
	options = _filter_blocked_selectable_nodes(options)

	if options.is_empty():
		_push_log("前方可继续推进的安全方向都被封住了，本次提前在当前节点停下。")
		pending_route_steps_remaining = 0
		_finalize_roll_arrival()
		return

	if options.size() == 1:
		_travel_one_step_to(int(options[0]))
		return

	pending_route_options = options.duplicate()
	branch_choice_pending = true
	_update_ui()

func _travel_one_step_to(node_id: int) -> void:
	if season_finished or board_anim_locked:
		return
	branch_choice_pending = false
	pending_route_options.clear()
	pending_travel_target = node_id
	pending_travel_path = [current_node_id, node_id]
	board_anim_locked = true
	_update_ui()
	board_view.play_travel(pending_travel_path)

func _finalize_roll_arrival() -> void:
	var final_node_id := current_node_id
	var node: Dictionary = board_lookup[final_node_id]

	current_visit_habitat_id = String(node.get("habitat_id", ""))
	GameState.add_weekly_progress("visit_count", 1)
	var hunger_after_move := GameState.consume_hunger(GameState.hunger_cost_per_travel)
	_push_log("掷骰后前往 %s。路径：%s。" % [
		String(node.get("name", "未知地点")),
		_format_path_preview(pending_route_history),
	])
	_push_log("移动消耗饥饿 %d，当前 %d / %d。" % [GameState.hunger_cost_per_travel, hunger_after_move, GameState.max_hunger])

	_clear_pending_route_state()

	var gate_result := board_progression_service.try_resolve_unlock_gate(final_node_id)
	if not gate_result.is_empty():
		current_visit_habitat_id = ""
		if bool(gate_result.get("ok", false)):
			_apply_ring_unlock_result(gate_result)
			_update_ui()
			return
		if String(gate_result.get("awaiting", "")) == "dojo":
			_show_ring_gate_blocked(node, String(gate_result.get("message", "还需要先通过当前道馆。")))
			_update_ui()
			return

	var type_id := String(node.get("type", ""))
	if type_id == "camp":
		_push_log("你路过营地，顺手整理队伍、驻守和留信。")
		_on_base_pressed(true)
		_update_ui()
		return
	if type_id in ["empty", "environment"]:
		_resolve_environment_node(node)
		_update_ui()
		return
	if type_id == "bulletin":
		_show_bulletin_board(node)
		_update_ui()
		return
	if type_id == "minigame":
		_show_minigame_stop(node)
		_update_ui()
		return
	if type_id == "infirmary":
		_show_infirmary_stop(node)
		_update_ui()
		return
	if not current_visit_habitat_id.is_empty() and not GameState.is_habitat_unlocked(current_visit_habitat_id) and type_id != "event":
		_show_locked_board_stop(node)
		_update_ui()
		return
	if not current_visit_habitat_id.is_empty():
		GameState.note_visit(current_visit_habitat_id)
	if type_id == "event":
		_resolve_board_event_node(node)
		_update_ui()
		return
	if _try_open_board_map_effect(node):
		_update_ui()
		return
	_continue_board_stop_flow(node)

func _clear_pending_route_state(clear_roll := true) -> void:
	awaiting_destination = false
	branch_choice_pending = false
	_queued_auto_travel_target = -1
	_queued_roll_start = false
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

func _reachable_selectable_nodes() -> Array[int]:
	var selectable: Array[int] = []
	for node_id in reachable_paths.keys():
		var target_id := int(node_id)
		if board_lookup.has(target_id) and not board_progression_service.is_node_locked(target_id):
			selectable.append(target_id)
	return selectable

func _on_support_pressed() -> void:
	var sections := _build_support_sections()
	if sections.is_empty():
		return
	var title := "雾野小本"
	var initial_section_id := "backpack"
	if not _last_ai_turn_report.is_empty() and String(sections[0].get("id", "")).begins_with("ai_"):
		title = "雾野小本 / 外头动静"
		initial_section_id = String(sections[0].get("id", "ai_0"))
	system_panel.open_panel(title, sections, initial_section_id)

func _build_support_sections() -> Array:
	if _last_ai_turn_report.is_empty():
		return _build_system_sections()
	var ai_sections := _build_ai_report_sections(_last_ai_turn_report)
	if ai_sections.is_empty():
		return _build_system_sections()
	ai_sections.append_array(_build_system_sections())
	return ai_sections

func _build_ai_report_sections(ai_result: Dictionary) -> Array:
	var sections: Array = []
	var reports: Array = ai_result.get("reports", [])
	for index in range(reports.size()):
		var report: Dictionary = Dictionary(reports[index]).duplicate(true)
		var rival: Dictionary = Dictionary(report.get("player", {})).duplicate(true)
		if rival.is_empty():
			continue
		var move: Dictionary = Dictionary(report.get("move", {})).duplicate(true)
		var landing: Dictionary = Dictionary(report.get("landing", {})).duplicate(true)
		var next_plan: Dictionary = Dictionary(report.get("next_plan", {})).duplicate(true)
		var display_name := String(rival.get("display_name", "对手 %d" % (index + 1)))
		var node_name := String(landing.get("node_name", move.get("destination_name", "")))
		if node_name.is_empty():
			node_name = String(board_lookup.get(int(rival.get("current_node_id", -1)), {}).get("name", "未知节点"))

		var summary_lines: Array[String] = [
			"[b]当前位置[/b] %s" % node_name,
			"[b]短行为[/b] %s" % String(report.get("short", "歇一会儿")),
			"[b]下回合意图[/b] %s" % String(report.get("intent", "继续观察")),
		]

		var body_lines: Array[String] = [
			"[b]完整行动[/b]",
			String(report.get("line", "暂无行动记录。")),
			"",
			"[b]移动决策[/b]",
			"首掷：%d" % int(move.get("first_roll", 0)),
			"最终骰值：%d" % int(move.get("final_roll", 0)),
			"是否改掷：%s" % ("是" if bool(move.get("reroll_used", false)) else "否"),
		]
		if bool(move.get("reroll_used", false)):
			body_lines.append("改掷值：%d" % int(move.get("reroll_value", 0)))
		body_lines.append("目标节点：%s" % String(move.get("destination_name", node_name)))
		var path_text := _format_ai_path_text(move.get("path_names", []))
		if not path_text.is_empty():
			body_lines.append("推进路径：%s" % path_text)
		body_lines.append("当前选点分数：%.2f" % float(move.get("score", 0.0)))
		if not String(move.get("ideal_plan_text", "")).is_empty():
			body_lines.append("理想计划：%s" % String(move.get("ideal_plan_text", "")))
			body_lines.append("理想计划分数：%.2f" % float(move.get("ideal_plan_score", 0.0)))
		if bool(move.get("reroll_used", false)):
			body_lines.append_array(_build_ai_candidate_lines("首掷候选", move.get("first_candidates", [])))
			body_lines.append_array(_build_ai_candidate_lines("改掷候选", move.get("reroll_candidates", [])))
		else:
			body_lines.append_array(_build_ai_candidate_lines("候选落点评分", move.get("candidates", [])))
		if bool(move.get("stayed_put", false)):
			body_lines.append("结果：这次没有精确落点，回合以整备收尾。")

		if not landing.is_empty():
			body_lines.append("")
			body_lines.append("[b]落点结果[/b]")
			if not String(landing.get("text", "")).is_empty():
				body_lines.append(String(landing.get("text", "")))
			var delta_parts: Array[String] = []
			for delta_key in [
				{"label": "金", "value": int(landing.get("gold_delta", 0))},
				{"label": "情报", "value": int(landing.get("intel_delta", 0))},
				{"label": "控制", "value": int(landing.get("control_delta", 0))},
				{"label": "威望", "value": int(landing.get("prestige_delta", 0))},
				{"label": "战术重掷", "value": int(landing.get("rerolls_delta", 0))},
			]:
				if int(delta_key.get("value", 0)) == 0:
					continue
				delta_parts.append("%s %s" % [
					String(delta_key.get("label", "")),
					_format_signed_int(int(delta_key.get("value", 0))),
				])
			if not delta_parts.is_empty():
				body_lines.append("资源变化：%s" % " ｜ ".join(delta_parts))
			body_lines.append("回合后状态：威望 %d ｜ 金 %d ｜ 情报 %d ｜ 控制 %d ｜ 战术重掷 %d" % [
				int(landing.get("prestige_after", rival.get("prestige", 0))),
				int(landing.get("gold_after", rival.get("gold", 0))),
				int(landing.get("intel_after", rival.get("intel", 0))),
				int(landing.get("control_after", rival.get("control", 0))),
				int(landing.get("rerolls_after", rival.get("tactical_rerolls", 0))),
			])

		if not next_plan.is_empty():
			body_lines.append("")
			body_lines.append("[b]后续意图[/b]")
			body_lines.append(String(next_plan.get("text", "继续观察局势")))
			if next_plan.has("score"):
				body_lines.append("计划分数：%.2f" % float(next_plan.get("score", 0.0)))

		sections.append({
			"id": "ai_%d" % index,
			"label": display_name,
			"summary": "\n".join(summary_lines),
			"body": "\n".join(body_lines),
		})
	return sections

func _format_ai_path_text(path_names_value) -> String:
	var path_names: Array = Array(path_names_value).duplicate()
	if path_names.is_empty():
		return ""
	var names: Array[String] = []
	for raw_name in path_names:
		names.append(String(raw_name))
	return " -> ".join(names)

func _build_ai_candidate_lines(title: String, candidates_value) -> Array[String]:
	var candidates: Array = Array(candidates_value).duplicate(true)
	if candidates.is_empty():
		return []
	var lines: Array[String] = [
		"",
		"[b]%s[/b]" % title,
	]
	for index in range(candidates.size()):
		var candidate: Dictionary = Dictionary(candidates[index]).duplicate(true)
		var parts: Array[String] = [
			"%d. #%d %s" % [
				index + 1,
				int(candidate.get("node_id", -1)),
				String(candidate.get("name", "未知节点")),
			],
			"%.2f" % float(candidate.get("score", 0.0)),
			_ai_candidate_type_label(String(candidate.get("legacy_type", ""))),
		]
		var danger := int(candidate.get("danger", 0))
		if danger > 0:
			parts.append("危险 %d" % danger)
		var path_text := _format_ai_path_text(candidate.get("path_names", []))
		if not path_text.is_empty():
			parts.append("路径 %s" % path_text)
		lines.append(" ｜ ".join(parts))
	return lines

func _ai_candidate_type_label(type_id: String) -> String:
	match type_id:
		"camp":
			return "营地"
		"resource":
			return "资源"
		"market":
			return "补给"
		"research":
			return "研判"
		"control":
			return "据点"
		"battle":
			return "交锋"
		"boss":
			return "高潮"
		"event":
			return "事件"
		_:
			return "未分类"

func _format_signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)

func _on_base_pressed(opened_from_travel: bool = false) -> void:
	camp_panel_requires_finish = camp_panel_requires_finish or opened_from_travel
	if opened_from_travel:
		var hunger_before := GameState.hunger
		var hunger_after := GameState.restore_hunger(GameState.camp_hunger_restore)
		if hunger_after > hunger_before:
			_push_log("营地热食让饥饿恢复到 %d / %d。" % [hunger_after, GameState.max_hunger])
	var synergy_report := synergy_service.build_synergy_report()
	var facility_bonus := synergy_service.build_facility_bonus()
	var battle_bonus := synergy_service.merge_battle_bonus([
		synergy_service.build_battle_bonus(synergy_report),
		facility_bonus.get("bonus", {}),
	])
	base_panel.open_panel({
		"season": {
			"season_name": _season_name(),
			"day_index": GameState.day_index,
			"season_length": GameState.season_length,
			"week_index": GameState.week_index,
			"global_turn": GameState.global_turn,
			"weather_name": _weather_name(GameState.weather_id),
			"time_name": _time_name(GameState.time_of_day),
			"care_progress": GameState.get_care_progress(),
			"progression_rank": GameState.get_progression_rank(),
			"progression_summary": GameState.get_progression_summary(),
			"badge_count": GameState.badge_count,
			"season_points": GameState.season_points,
			"dojo_rotation": _active_dojo_names(),
			"annual_competition_text": _annual_competition_status_text(),
		},
		"inventory": GameState.inventory,
		"companions": _build_companion_summaries(),
		"habitats": _build_habitat_summaries(),
		"active_quests": _quest_titles(GameState.active_quests),
		"completed_quests": GameState.completed_quests.duplicate(),
		"battle_slots": _battle_slot_names(),
		"reserve_summary": "%d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity],
		"backpack_summary": "%d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity],
		"run_modifiers": run_modifier_service.format_lines(GameState.run_modifiers),
		"weekly_objective_text": weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress),
		"meta_points": GameState.exploration_points_total,
		"synergy_lines": synergy_service.format_active_lines(synergy_report, 4),
		"nearby_synergy_lines": synergy_service.format_nearby_lines(synergy_report, 3),
		"building_lines": facility_bonus.get("lines", []),
		"battle_bonus_lines": synergy_service.describe_battle_bonus(battle_bonus),
		"nursery_lines": nursery_service.build_overview_lines(),
	})
	if not _should_skip_runtime_tutorials() and not GameState.has_completed_tutorial("management_intro"):
		_show_tutorial_popup("management_intro")

func _on_board_node_chosen(node_id: int) -> void:
	if not branch_choice_pending:
		return
	if not pending_route_options.has(node_id):
		return
	_travel_one_step_to(node_id)

func _on_board_travel_finished(node_id: int) -> void:
	board_anim_locked = false
	current_node_id = node_id
	GameState.move_to_board_node(node_id)
	GameState.reveal_board_nodes(board_progression_service.expand_reveal_from(node_id))
	if pending_route_history.is_empty() or int(pending_route_history[pending_route_history.size() - 1]) != node_id:
		pending_route_history.append(node_id)
	if pending_route_steps_remaining > 0:
		pending_route_steps_remaining = maxi(0, pending_route_steps_remaining - 1)
	if pending_route_steps_remaining > 0:
		_continue_roll_travel()
		return
	_finalize_roll_arrival()

func _continue_board_stop_flow(node: Dictionary) -> void:
	_check_active_quests()
	if _should_trigger_prearrival_ambush(current_node_id):
		_push_log("%s 附近残留着躁动痕迹，本次需要先处理袭扰。" % String(node.get("name", "未知地点")))
		visit_flow.start_observation_for_habitat(current_visit_habitat_id, "ambush")
	else:
		visit_flow.start_visit(current_visit_habitat_id)
	_update_ui()

func _try_open_board_map_effect(node: Dictionary) -> bool:
	var report := board_map_effect_service.apply_on_arrival(
		node,
		current_node_id,
		GameState.board_region_id,
		_current_boss_node_id(),
		board_lookup
	)
	if report.is_empty():
		return false
	var body_lines: Array[String] = []
	var description := String(report.get("description", ""))
	if not description.is_empty():
		body_lines.append(description)
	for line in report.get("lines", []):
		body_lines.append("- %s" % String(line))
		_push_log("地图效果：%s。" % String(line))
	pending_context = {"kind": "board_map_effect", "on_close": "resume_board_stop"}
	decision_panel.open_panel(String(report.get("title", "地图效果")), "\n".join(body_lines), [], "继续前进")
	return true

func _show_bulletin_board(node: Dictionary) -> void:
	var report: Dictionary = bulletin_service.build_board_bulletin(node)
	_push_log("在 %s 看了一眼公告板，把本周的野群和折扣消息记下了。" % String(report.get("title", "公告板")))
	pending_context = {"kind": "bulletin_board", "on_close": "finish_transit_stop"}
	decision_panel.open_panel(
		String(report.get("title", "公告板")),
		String(report.get("body", "")),
		[],
		"继续前进"
	)

func _show_minigame_stop(node: Dictionary) -> void:
	var payload: Dictionary = minigame_service.build_board_minigame(node)
	_push_log("路过 %s，旁边正好摆着一处能带伙伴热身的小游戏摊位。" % String(payload.get("title", "小游戏地块")))
	pending_context = {
		"kind": "minigame_menu",
		"node_id": int(node.get("id", -1)),
		"on_close": "finish_transit_stop",
	}
	decision_panel.open_panel(
		String(payload.get("title", "小游戏地块")),
		String(payload.get("body", "")),
		Array(payload.get("choices", [])).duplicate(true),
		"继续前进"
	)

func _show_minigame_result(result: Dictionary) -> void:
	var body_lines: Array[String] = [
		String(result.get("text", "伙伴们稍微活动开了。")),
		"",
		"[b]下次战斗前[/b] %s" % String(result.get("reward_text", "会带一点小幅属性加成。")),
	]
	var combined_text := String(result.get("combined_text", ""))
	if not combined_text.is_empty():
		body_lines.append("[b]当前累计[/b] %s" % combined_text)
	_push_log("%s：下次战斗前 %s。" % [
		String(result.get("title", "小游戏地块")),
		String(result.get("reward_text", "状态稍微被提起来了")),
	])
	pending_context = {"kind": "minigame_result", "on_close": "finish_transit_stop"}
	decision_panel.open_panel(
		"小游戏收尾",
		"\n".join(body_lines),
		[],
		"继续前进"
	)

func _show_infirmary_stop(node: Dictionary) -> void:
	var payload: Dictionary = infirmary_service.build_stop_menu(node)
	_push_log("路过 %s，这里可以免费做一轮主动疗养。" % String(payload.get("title", "疗养所")))
	pending_context = {
		"kind": "infirmary_menu",
		"node_id": int(node.get("id", -1)),
		"on_close": "finish_transit_stop",
	}
	decision_panel.open_panel(
		String(payload.get("title", "疗养所")),
		String(payload.get("body", "")),
		Array(payload.get("choices", [])).duplicate(true),
		"先不休息"
	)

func _show_infirmary_result(payload: Dictionary, on_close: String) -> void:
	pending_context = {"kind": "infirmary_result", "on_close": on_close}
	decision_panel.open_panel(
		String(payload.get("title", "疗养所")),
		String(payload.get("body", "")),
		[],
		"继续前进"
	)

func _apply_forced_infirmary_transfer(defeated_node: Dictionary) -> Dictionary:
	var infirmary_node := board_progression_service.find_best_infirmary_node(current_node_id)
	if infirmary_node.is_empty():
		var fallback: Dictionary = infirmary_service.resolve_forced_recovery({
			"name": "临时医疗点",
			"type": "infirmary",
		}, defeated_node)
		_push_log("战败后临时做了一轮紧急疗养，扣除了 %d 金。" % int(fallback.get("paid_gold", 0)))
		return fallback

	current_node_id = int(infirmary_node.get("id", current_node_id))
	GameState.move_to_board_node(current_node_id)
	GameState.reveal_board_nodes(board_progression_service.expand_reveal_from(current_node_id))
	board_view.set_current_node(current_node_id, true)

	var report: Dictionary = infirmary_service.resolve_forced_recovery(infirmary_node, defeated_node)
	_push_log("战败后被送往 %s 休整，疗养费扣除了 %d 金。" % [
		String(infirmary_node.get("name", "疗养所")),
		int(report.get("paid_gold", 0)),
	])
	return report

func _on_visit_state_changed(step_id: String, payload: Dictionary) -> void:
	match step_id:
		"arrival":
			_show_arrival_menu(payload)
		"build_select":
			_show_build_menu(payload)
		"build_result":
			_show_build_result(payload)
		"shop_menu":
			_show_shop_menu(payload)
		"shop_result":
			_show_shop_result(payload)
		"shop_npc_result":
			_show_shop_npc_result(payload)
		"npc_menu":
			_show_npc_menu(payload)
		"dojo_menu":
			_show_dojo_menu(payload)
		"dojo_battle":
			_start_dojo_battle(payload)
		"dojo_result":
			_show_dojo_result(payload)
		"encounter_preview":
			_show_encounter_preview(payload)
		"encounter_result":
			_show_encounter_result(payload)

func _show_arrival_menu(payload: Dictionary) -> void:
	var habitat: Dictionary = payload.get("habitat", {})
	var state: Dictionary = payload.get("state", {})
	var resident: Dictionary = payload.get("resident", {})
	var npcs: Array = payload.get("npcs", [])
	var npc_presence: Dictionary = payload.get("npc_presence", {})
	var buildings: Array = payload.get("buildings", [])
	var node: Dictionary = board_lookup.get(current_node_id, {})
	var primary_action := _primary_content_action(node, habitat, buildings, npcs)
	var lines: Array[String] = []
	lines.append("[b]地点气氛[/b] %s" % "、".join(habitat.get("mood_tags", [])))
	lines.append("[b]今日适合[/b] %s" % _seasonal_hook_text(habitat))
	lines.append("[b]当前看守[/b] %s" % String(resident.get("display_name", "暂无")))
	lines.append("[b]据点等级[/b] %d" % int(state.get("rank", 0)))
	lines.append("[b]常见人物[/b] %s" % (" / ".join(_npc_names(npcs)) if not npcs.is_empty() else "今天没有遇见谁"))
	if not npc_presence.get("window_lines", []).is_empty():
		lines.append("[b]来访窗口[/b] %s" % " / ".join(npc_presence.get("window_lines", []).slice(0, 2)))
	lines.append("[b]建设进度[/b] %s" % _format_building_levels(current_visit_habitat_id, buildings))
	var apartment_line := _apartment_visit_line(current_visit_habitat_id)
	if not apartment_line.is_empty():
		lines.append("[b]公寓近况[/b] %s" % apartment_line)
	lines.append_array(nursery_service.build_arrival_lines(current_visit_habitat_id))
	if not primary_action.is_empty():
		lines.append("[b]节点主玩法[/b] %s" % _primary_content_label(primary_action))
	var effect_title := board_map_effect_service.preview_title(node)
	if not effect_title.is_empty():
		var effect_state := "待触发" if board_map_effect_service.has_pending_effect(node, current_node_id, GameState.board_region_id) else "已触发"
		lines.append("[b]地图效果[/b] %s（%s）" % [effect_title, effect_state])
	var node_danger := GameState.get_node_danger(current_node_id)
	if node_danger > 0:
		lines.append("[b]区域危险[/b] %d / 3" % node_danger)
	if GameState.has_node_ambush(current_node_id):
		lines.append("[b]袭扰预警[/b] 这里留下了潜伏痕迹。")
	if int(habitat.get("recommended_rank", 0)) > 0:
		lines.append("[b]什么时候来更合适[/b] %d 级左右会更轻松" % int(habitat.get("recommended_rank", 0)))
	if not String(habitat.get("dojo_id", "")).is_empty():
		lines.append("[b]试炼状态[/b] %s" % _dojo_status_text(String(habitat.get("dojo_id", ""))))

	var choices := []
	if not primary_action.is_empty():
		choices.append({
			"id": primary_action,
			"label": _primary_content_label(primary_action),
			"summary": "%s\n这就是你到这儿后最值得先顾上的那件事。" % _primary_content_summary(primary_action),
		})
	elif nursery_service.supports_nursery(current_visit_habitat_id):
		choices.append({
			"id": "nursery_menu",
			"label": "照料孵育",
			"summary": "查看这里的孵育位，安排孵化或继续照看幼体。",
		})
	elif String(habitat.get("type", "")) == "habitat":
		choices.append({
			"id": "assign_resident",
			"label": "安排看守",
			"summary": "把这里交给更合适的人或伙伴看着。",
		})
	pending_context = {"kind": "visit_arrival", "on_close": "finish_visit"}
	decision_panel.open_panel(String(habitat.get("name", "地点")), "\n".join(lines), choices, "继续前进")

func _should_trigger_prearrival_ambush(node_id: int) -> bool:
	return GameState.consume_node_ambush(node_id)

func _primary_content_action(node: Dictionary, habitat: Dictionary, buildings: Array, npcs: Array) -> String:
	var requested := String(node.get("primary_content", ""))
	if requested.is_empty():
		for fallback_action in ["fishing_menu", "dojo_menu", "build_menu", "npc_menu", "observe", "mail_menu"]:
			if _is_primary_action_available(fallback_action, habitat, buildings, npcs):
				return fallback_action
		return ""
	return requested if _is_primary_action_available(requested, habitat, buildings, npcs) else ""

func _is_primary_action_available(action_id: String, habitat: Dictionary, buildings: Array, npcs: Array) -> bool:
	match action_id:
		"build_menu":
			return not buildings.is_empty()
		"shop_menu":
			return not DataRepository.get_shop(String(habitat.get("id", ""))).is_empty()
		"npc_menu":
			return not npcs.is_empty()
		"observe":
			return not habitat.get("wild_pool", []).is_empty()
		"fishing_menu":
			return fishing_service.has_fishing_spot(String(habitat.get("id", "")))
		"dojo_menu":
			return not String(habitat.get("dojo_id", "")).is_empty()
		"mail_menu":
			return String(habitat.get("type", "")) == "settlement"
		_:
			return false

func _primary_content_label(action_id: String) -> String:
	match action_id:
		"build_menu":
			return "把这里收拾一下"
		"shop_menu":
			return "去摊子上看看"
		"npc_menu":
			return "和人聊聊"
		"observe":
			return "四处看看"
		"fishing_menu":
			return "去水边坐会儿"
		"dojo_menu":
			return "去试试看"
		"mail_menu":
			return "捎个话"
		_:
			return "先做眼前这件事"

func _primary_content_summary(action_id: String) -> String:
	match action_id:
		"build_menu":
			return "这里最要紧的，是把地方慢慢收拾得更像个能落脚的去处。"
		"shop_menu":
			return "这里更适合去摊子上转转，顺手把缺的东西补一补。"
		"npc_menu":
			return "这里最值当的，通常是和人聊一聊，把关系慢慢走近。"
		"observe":
			return "这里适合先看看四周，别急着动手，先摸清气氛。"
		"fishing_menu":
			return "这里不必太赶，去水边坐会儿，常常会有意外收获。"
		"dojo_menu":
			return "这里就是来试试手感的，看看现在这套搭配顺不顺手。"
		"mail_menu":
			return "这里更像顺路帮人捎个话，也顺便听听别处的动静。"
		_:
			return "先把这里眼前最值得做的一件事接住。"

func _show_build_menu(payload: Dictionary) -> void:
	var choices := []
	for building in payload.get("buildings", []):
		var building_id := String(building.get("id", ""))
		var check := habitat_service.can_build(current_visit_habitat_id, building_id)
		choices.append({
			"id": building_id,
			"label": String(building.get("name", "未命名建筑")),
			"summary": _build_choice_summary(check),
			"tooltip": _build_choice_tooltip(check),
			"disabled": not bool(check.get("ok", false)),
		})
	pending_context = {"kind": "build_select", "on_close": "arrival"}
	decision_panel.open_panel(
		"推进建设",
		"到了地方再动手，才更像真的在把这里安顿起来。\n[b]当前据点等级[/b] %d ｜ [b]当前成长阶段[/b] %d" % [
			int(GameState.habitats.get(current_visit_habitat_id, {}).get("rank", 0)),
			GameState.get_progression_rank(),
		],
		choices,
		"返回地点"
	)

func _show_build_result(payload: Dictionary) -> void:
	if bool(payload.get("ok", false)):
		var building_name := String(DataRepository.get_building(String(payload.get("building_id", ""))).get("name", "建设"))
		var effects: Array = payload.get("effects", [])
		var effect_lines: Array[String] = []
		for entry in effects:
			effect_lines.append(String(entry))
		var body_lines: Array[String] = ["[b]%s[/b] 升到 Lv.%d" % [building_name, int(payload.get("level", 0))]]
		if not effect_lines.is_empty():
			body_lines.append("[b]本阶效果[/b] %s" % "\n".join(effect_lines))
		var interactions: Array = payload.get("interactions", [])
		if not interactions.is_empty():
			var interaction_labels: Array[String] = []
			for interaction in interactions:
				interaction_labels.append(String(interaction.get("label", interaction.get("id", "新互动"))))
			body_lines.append("[b]新增互动[/b] %s" % " / ".join(interaction_labels))
		var habitat_rank_before := int(payload.get("habitat_rank_before", 0))
		var habitat_rank_after := int(payload.get("habitat_rank_after", habitat_rank_before))
		if habitat_rank_after != habitat_rank_before:
			body_lines.append("[b]据点等级[/b] %d → %d" % [habitat_rank_before, habitat_rank_after])
		var progression_rank_before := int(payload.get("progression_rank_before", GameState.get_progression_rank()))
		var progression_rank_after := int(payload.get("progression_rank_after", progression_rank_before))
		if progression_rank_after != progression_rank_before:
			body_lines.append("[b]成长阶段[/b] %d → %d" % [progression_rank_before, progression_rank_after])
			var capacity_before := int(payload.get("capacity_before", 0))
			var capacity_after := int(payload.get("capacity_after", capacity_before))
			if capacity_after != capacity_before:
				body_lines.append("[b]宠物栏容量[/b] %d → %d" % [capacity_before, capacity_after])
			if not String(payload.get("progression_summary_after", "")).is_empty():
				body_lines.append("[b]本阶焦点[/b] %s" % String(payload.get("progression_summary_after", "")))
		GameState.add_weekly_progress("build_count", 1)
		_push_log("%s 的 %s 升到了 Lv.%d。" % [_habitat_name(current_visit_habitat_id), building_name, int(payload.get("level", 0))])
		_check_active_quests()
		var transition_text := "%s · Lv.%d" % [building_name, int(payload.get("level", 0))]
		if not effect_lines.is_empty():
			transition_text += "\n%s" % " / ".join(effect_lines.slice(0, 2))
		_play_stage_transition("建设完成", transition_text, Color(0.98, 0.74, 0.34, 1.0))
		pending_context = {"kind": "build_result", "on_close": "finish_visit"}
		decision_panel.open_panel("建设完成", "\n".join(body_lines), [], "结束偶遇")
		return
	pending_context = {"kind": "build_result", "on_close": "finish_visit"}
	decision_panel.open_panel("建设受阻", _build_fail_reason(String(payload.get("reason", "unknown"))), [], "结束偶遇")

func _show_shop_menu(payload: Dictionary) -> void:
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "shop_menu", "on_close": "arrival"}
		decision_panel.open_panel("商店未开放", "这里现在还没有能营业的摊位。", [], "返回地点")
		return
	var lines: Array[String] = []
	if not String(payload.get("description", "")).is_empty():
		lines.append(String(payload.get("description", "")))
	lines.append("[b]手头资金[/b] %d 金" % int(payload.get("wallet_gold", 0)))
	lines.append("[b]当前周次[/b] 第 %d 周" % int(payload.get("week_index", 1)))
	var active_rotations: Array = payload.get("active_rotations", [])
	if not active_rotations.is_empty():
		lines.append("[b]当期轮换[/b] %s" % " / ".join(active_rotations))
	if int(payload.get("discounted_offer_count", 0)) > 0:
		lines.append("[b]本周折扣[/b] %d 档货正在降价" % int(payload.get("discounted_offer_count", 0)))
	var choices := []
	for offer in payload.get("offers", []):
		var offer_id := String(offer.get("id", ""))
		var remaining := int(offer.get("remaining_stock", 0))
		var disabled := remaining <= 0 or int(payload.get("wallet_gold", 0)) < int(offer.get("price", 0))
		var summary := "购入 %d × %s ｜ %s ｜ 剩余 %d" % [
			int(offer.get("quantity", 1)),
			String(offer.get("item_name", offer.get("label", offer_id))),
			_shop_offer_price_text(Dictionary(offer).duplicate(true)),
			remaining,
		]
		var tags: Array = offer.get("tags", [])
		if not tags.is_empty():
			summary += " ｜ %s" % " / ".join(tags)
		if remaining <= 0:
			summary += " ｜ 已售罄"
		elif int(payload.get("wallet_gold", 0)) < int(offer.get("price", 0)):
			summary += " ｜ 金币不足"
		choices.append({
			"id": "buy:%s" % offer_id,
			"label": String(offer.get("label", offer_id)),
			"summary": summary,
			"disabled": disabled,
		})
	var npc_services: Array = payload.get("npc_services", [])
	if not npc_services.is_empty():
		lines.append("[b]摊位熟人[/b] 他们今天还能额外帮你处理些别的事。")
		for service in npc_services:
			var service_id := String(service.get("id", ""))
			choices.append({
				"id": "service:%s" % service_id,
				"label": "%s｜%s" % [String(service.get("npc_name", "熟人")), String(service.get("label", service_id))],
				"summary": _format_shop_service_summary(service),
				"disabled": not bool(service.get("available", false)),
			})
	pending_context = {"kind": "shop_menu", "on_close": "arrival"}
	decision_panel.open_panel(String(payload.get("shop_name", "商店")), "\n".join(lines), choices, "返回地点")

func _show_shop_result(payload: Dictionary) -> void:
	if not bool(payload.get("ok", false)):
		var reason := String(payload.get("reason", "shop_failed"))
		var text := "这次交易没有成功。"
		match reason:
			"insufficient_gold":
				text = "手头资金不够，先去别的节点赚点金再来。"
			"sold_out":
				text = "这一档货已经被买空了，要等下周再补。"
			"offer_missing":
				text = "今天这档货已经不在台面上了。"
		pending_context = {"kind": "shop_result", "on_close": "shop_menu"}
		decision_panel.open_panel("交易失败", text, [], "返回摊位")
		return
	var offer: Dictionary = payload.get("offer", {})
	var item_name := String(offer.get("item_name", offer.get("label", "货物")))
	var quantity := int(offer.get("quantity", 1))
	var lines := [
		"[b]购入[/b] %d × %s" % [quantity, item_name],
		"[b]花费[/b] %s" % _shop_offer_price_text(offer),
		"[b]剩余资金[/b] %d 金" % int(payload.get("wallet_gold", 0)),
		"[b]本周剩余库存[/b] %d" % int(offer.get("remaining_stock", 0)),
	]
	var codex_unlocks: Array = Array(payload.get("codex_unlocks", [])).duplicate(true)
	if not codex_unlocks.is_empty():
		var unlocked_titles: Array[String] = []
		for raw_entry in codex_unlocks:
			var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
			unlocked_titles.append(String(entry.get("title", entry.get("id", "新条目"))))
		lines.append("[b]图鉴补完[/b] %s" % " / ".join(unlocked_titles))
	_push_log("在 %s 买下了 %d × %s，花费 %d 金。" % [
		String(payload.get("shop_name", "商店")),
		quantity,
		item_name,
		int(offer.get("price", 0)),
	])
	pending_context = {"kind": "shop_result", "on_close": "shop_menu"}
	decision_panel.open_panel("交易完成", "\n".join(lines), [], "继续逛摊")

func _show_shop_npc_result(payload: Dictionary) -> void:
	if not bool(payload.get("ok", false)):
		var reason := String(payload.get("reason", "service_failed"))
		var text := "这次没能谈成。"
		match reason:
			"service_used_up":
				text = "这门额外手艺本周已经用过了，得等下一周。"
			"trust_locked":
				text = "关系还没熟到这一步，先多聊几次再来试。"
			"insufficient_gold":
				text = "手头资金不够，对方这次不肯先垫着。"
			"missing_items":
				text = "材料还没备齐：%s" % _format_item_cost(payload.get("cost_items", {}))
			"no_intel":
				text = "对方今天也探不到更具体的风声。"
			"service_missing":
				text = "今天这位没有空接这档额外活。"
		pending_context = {"kind": "shop_npc_result", "on_close": "shop_menu"}
		decision_panel.open_panel("熟人服务失败", text, [], "返回摊位")
		return
	var service: Dictionary = payload.get("service", {})
	var lines: Array[String] = []
	lines.append("[b]联系人[/b] %s" % String(service.get("npc_name", "摊位熟人")))
	if not String(service.get("description", "")).is_empty():
		lines.append(String(service.get("description", "")))
	var cost_gold := int(payload.get("cost_gold", 0))
	if cost_gold > 0:
		lines.append("[b]花费[/b] %d 金" % cost_gold)
	var cost_items: Dictionary = payload.get("cost_items", {})
	if not cost_items.is_empty():
		lines.append("[b]交付[/b] %s" % _format_item_cost(cost_items))
	var reward_items: Dictionary = payload.get("reward_items", {})
	if not reward_items.is_empty():
		lines.append("[b]获得[/b] %s" % _format_item_cost(reward_items))
	for line in payload.get("lines", []):
		lines.append(String(line))
	lines.append("[b]剩余资金[/b] %d 金" % int(payload.get("wallet_gold", 0)))
	lines.append("[b]本周剩余次数[/b] %d" % int(service.get("remaining_uses", 0)))
	_push_log("在 %s 找 %s 额外办了一件事：%s。" % [String(payload.get("shop_name", "商店")), String(service.get("npc_name", "熟人")), String(service.get("label", "额外服务"))])
	pending_context = {"kind": "shop_npc_result", "on_close": "shop_menu"}
	decision_panel.open_panel(String(service.get("label", "熟人服务完成")), "\n".join(lines), [], "继续逛摊")

func _show_npc_menu(payload: Dictionary) -> void:
	var choices := []
	for npc in payload.get("npcs", []):
		var npc_id := String(npc.get("id", ""))
		var intro_pending := npc_service.needs_intro_duel(npc_id)
		var duel_status := npc_service.get_intro_duel_status(npc_id)
		choices.append({
			"id": "duel:%s" % npc_id if intro_pending else "talk:%s" % npc_id,
			"label": "%s（先决斗）" % String(npc.get("name", "未命名 NPC")) if intro_pending else String(npc.get("name", "未命名 NPC")),
			"summary": "第一次见面先切磋一场；赢了更容易聊开，输了也还能慢慢熟起来。" if intro_pending else "今天可以好好聊聊。当前信赖 %d ｜ %s" % [npc_service.get_npc_trust(npc_id), "首战赢过" if bool(duel_status.get("won", false)) else "还在慢慢熟"],
		})
	for quest in payload.get("quests", []):
		var quest_id := String(quest.get("id", ""))
		if GameState.active_quests.has(quest_id) or GameState.completed_quests.has(quest_id):
			continue
		var giver_id := String(quest.get("giver", ""))
		var giver := DataRepository.get_npc(giver_id)
		var duel_locked := npc_service.needs_intro_duel(giver_id)
		var quest_description := String(quest.get("description", ""))
		var quest_summary := "得先和 %s 过过招，聊熟之后才能接这份委托。" % String(giver.get("name", "委托人")) if duel_locked else "先记在这季安排里，之后回来时会顺手看看进展。"
		if not duel_locked and not quest_description.is_empty():
			quest_summary = quest_description
		choices.append({
			"id": "quest:%s" % quest_id,
			"label": "接委托：%s" % String(quest.get("title", "")),
			"summary": quest_summary,
			"disabled": duel_locked,
		})
	pending_context = {"kind": "npc_menu", "on_close": "arrival"}
	decision_panel.open_panel("你在这里遇到的人", "第一次见面先过过招，熟了之后再慢慢聊。", choices, "返回地点")

func _show_dojo_menu(payload: Dictionary) -> void:
	var dojo: Dictionary = payload.get("dojo", {})
	if dojo.is_empty():
		pending_context = {"kind": "dojo_menu", "on_close": "arrival"}
		decision_panel.open_panel("试炼入口", "这里今天没有可进行的试炼。", [], "返回地点")
		return
	var lines: Array[String] = []
	lines.append("[b]什么时候来更轻松[/b] %d 级左右" % int(dojo.get("recommended_rank", 1)))
	lines.append("[b]当前成长阶段[/b] %d ｜ [b]总据点等级[/b] %d" % [
		int(payload.get("progression_rank", GameState.get_progression_rank())),
		int(payload.get("habitat_rank_total", GameState.get_habitat_rank_total())),
	])
	lines.append("[b]门票[/b] %s" % _format_item_cost(payload.get("entry_cost", {})))
	lines.append("[b]当前出战位[/b] %s" % (" / ".join(payload.get("battle_slots", [])) if not payload.get("battle_slots", []).is_empty() else "还没安排好"))
	lines.append("[b]宠物栏容量[/b] %s" % String(payload.get("backpack_summary", payload.get("reserve_summary", "0 / 0"))))
	if not bool(payload.get("battle_slots_ready", true)):
		lines.append("[b]当前限制[/b] 还没站稳两位同行，未满足的阶段会先锁住。")
	for line in payload.get("synergy_lines", []):
		lines.append("[b]已激活羁绊[/b] %s" % line)
		break
	if not payload.get("nearby_synergy_lines", []).is_empty():
		lines.append("[b]差 1 激活[/b] %s" % " / ".join(payload.get("nearby_synergy_lines", [])))
	if not payload.get("building_lines", []).is_empty():
		lines.append("[b]建筑增益[/b] %s" % " / ".join(payload.get("building_lines", []).slice(0, 2)))
	if not String(payload.get("hint", "")).is_empty():
		lines.append("[b]提示[/b] %s" % String(payload.get("hint", "")))
	pending_context = {"kind": "dojo_menu", "on_close": "arrival"}
	decision_panel.open_panel(String(dojo.get("name", "试炼")), "\n".join(lines), payload.get("choices", []), "返回地点")

func _show_dojo_result(payload: Dictionary) -> void:
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "dojo_result", "on_close": "finish_visit"}
		decision_panel.open_panel("试炼受阻", _build_fail_reason(String(payload.get("reason", "unknown"))), [], "结束偶遇")
		return
	var dojo: Dictionary = payload.get("dojo", {})
	var tier := String(payload.get("tier", "tier_1"))
	var reward_result: Dictionary = payload.get("reward_result", {})
	var unlocked_traversal_skills: Array = payload.get("unlocked_traversal_skills", []).duplicate()
	var lines: Array[String] = []
	if payload.has("challenge_score") and payload.has("required_rank"):
		lines.append("[b]当前评分[/b] %d / %d" % [int(payload.get("challenge_score", 0)), int(payload.get("required_rank", 0))])
	if not payload.get("modifiers", []).is_empty():
		lines.append("[b]规则修正[/b] %s" % " / ".join(payload.get("modifiers", [])))
	var battle_result: Dictionary = payload.get("battle_result", {})
	if bool(battle_result.get("timed_out", false)):
		lines.append("[b]结算方式[/b] 达到回合上限后按剩余战力判定")
	var reward_text := _format_reward_bundle(reward_result)
	if bool(payload.get("success", false)):
		GameState.add_weekly_progress("dojo_clear_count", 1)
		var result_line := "[b]结果[/b] 首通 %s" % _dojo_tier_name(tier) if bool(payload.get("first_clear", false)) else "[b]结果[/b] 再次通过 %s" % _dojo_tier_name(tier)
		lines.append(result_line)
		if not reward_text.is_empty():
			lines.append("[b]获得[/b] %s" % reward_text)
		if not unlocked_traversal_skills.is_empty():
			lines.append("[b]学会通行技[/b] %s" % _format_traversal_skill_names(unlocked_traversal_skills))
		var ring_result := board_progression_service.try_unlock_outer_ring_from_dojo(String(dojo.get("id", "")), tier)
		if bool(ring_result.get("ok", false)):
			_apply_ring_unlock_result(ring_result, false)
			lines.append("[b]前路变化[/b] %s" % String(ring_result.get("message", "更远的路已经露出来了。")))
		elif not ring_result.is_empty():
			lines.append("[b]前路还差一点[/b] %s" % String(ring_result.get("message", "更远的路还差一点条件。")))
		_push_log("%s 通过了 %s。" % [String(dojo.get("name", "试炼")), _dojo_tier_name(tier)])
	else:
		lines.append("[b]结果[/b] 暂未通过 %s" % _dojo_tier_name(tier))
		if payload.has("gap"):
			lines.append("还差约 %d 点准备度，建议先补据点等级、信赖或门票素材。" % int(payload.get("gap", 1)))
		else:
			lines.append("建议先补一补出战位羁绊、建筑看守或星级，再来试这一级。")
		if not reward_text.is_empty():
			lines.append("[b]安慰奖励[/b] %s" % reward_text)
		_push_log("%s 暂时没能通过 %s。" % [String(dojo.get("name", "试炼")), _dojo_tier_name(tier)])
		lines.append("")
		lines.append(String(_apply_forced_infirmary_transfer(board_lookup.get(current_node_id, {}).duplicate(true)).get("body", "")))
	pending_context = {"kind": "dojo_result", "on_close": "finish_visit"}
	decision_panel.open_panel("试炼结果", "\n".join(lines), [], "结束偶遇")

func _start_dojo_battle(payload: Dictionary) -> void:
	var battle_config: Dictionary = payload.get("battle_config", {})
	if battle_config.is_empty():
		_show_dojo_result({"ok": false, "reason": "battle_config_missing"})
		return
	_start_battle_with_tutorial(
		battle_config,
		"dojo",
		"进入 %s，准备来一场双打试炼。" % String(battle_config.get("title", "试炼"))
	)

func _show_encounter_preview(payload: Dictionary) -> void:
	current_encounter = payload.duplicate(true)
	var source := String(payload.get("source", "observe"))
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "encounter_preview", "on_close": "finish_visit"}
		var empty_text := "今天没有遇到特别愿意停留的个体。"
		if source == "ambush":
			empty_text = "你先察觉到了躁动，但这次没有真的爆发袭扰。"
		decision_panel.open_panel("今天的路遇", empty_text, [], "继续前进")
		return
	var species: Dictionary = payload.get("species", {})
	var species_id := String(payload.get("species_id", ""))
	GameState.note_encounter(species_id)
	GameState.add_weekly_progress("encounter_count", 1)
	var body_lines: Array[String] = []
	if source == "ambush":
		body_lines.append("[b]突发袭扰[/b]")
		body_lines.append("你刚进入节点就惊动了潜伏的野群，必须先稳住场面。")
	body_lines.append("[b]%s[/b]" % String(species.get("name", "未知个体")))
	body_lines.append("[b]当前情绪[/b] %s" % String(payload.get("mood_id", "curious")))
	body_lines.append("[b]结缘窗口[/b] %s" % String(payload.get("bond_window", "medium")))
	body_lines.append("[b]偏好动作[/b] %s" % " / ".join(species.get("care_actions", [])))
	var choices := []
	for action_id in encounter_service.get_available_actions(payload):
		choices.append({"id": action_id, "label": _action_name(action_id), "summary": "按当前情绪做一次温和尝试。"})
	pending_context = {"kind": "encounter_preview", "on_close": "arrival"}
	decision_panel.open_panel("突发袭扰" if source == "ambush" else "路遇野群", "\n".join(body_lines), choices, "返回地点")

func _show_encounter_result(payload: Dictionary) -> void:
	var outcome_text := _handle_encounter_result_effects(payload)
	pending_context = {"kind": "encounter_result", "on_close": "finish_visit"}
	decision_panel.open_panel("路遇结果", outcome_text, [], "继续前进")

func _show_fishing_menu() -> void:
	var payload := fishing_service.build_fishing_menu(current_visit_habitat_id)
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "fishing_menu", "on_close": "arrival"}
		decision_panel.open_panel("水边垂钓", "这里今天不适合展开钓鱼。", [], "返回地点")
		return
	pending_context = {"kind": "fishing_menu", "on_close": "arrival"}
	decision_panel.open_panel(String(payload.get("title", "水边垂钓")), String(payload.get("body", "")), payload.get("choices", []), "返回地点")

func _show_fishing_result(payload: Dictionary) -> void:
	if not bool(payload.get("ok", false)):
		pending_context = {"kind": "fishing_result", "on_close": "finish_visit"}
		decision_panel.open_panel("垂钓结果", String(payload.get("body", "今天没有钓到什么。")), [], "结束偶遇")
		return
	_apply_fishing_side_effects(payload)
	if not String(payload.get("log_line", "")).is_empty():
		_push_log(String(payload.get("log_line", "")))
	var body_lines: Array = Array(payload.get("body_lines", [])).duplicate(true)
	var leaderboard_lines: Array = Array(payload.get("leaderboard_lines", [])).duplicate(true)
	if not leaderboard_lines.is_empty():
		body_lines.append("")
		body_lines.append("[b]本季榜单[/b]")
		body_lines.append("\n".join(leaderboard_lines.slice(0, 3)))
	pending_context = {"kind": "fishing_result", "on_close": "finish_visit"}
	decision_panel.open_panel(String(payload.get("title", "垂钓结果")), "\n".join(body_lines), [], "结束偶遇")

func _show_nursery_menu() -> void:
	var payload := nursery_service.get_menu(current_visit_habitat_id)
	pending_context = {"kind": "nursery_menu", "on_close": "arrival"}
	decision_panel.open_panel(String(payload.get("title", "照料孵育")), String(payload.get("body", "")), payload.get("choices", []), "返回地点")

func _show_nursery_species_picker() -> void:
	var payload := nursery_service.get_candidate_picker(current_visit_habitat_id)
	pending_context = {"kind": "nursery_species_select", "on_close": "nursery_menu"}
	decision_panel.open_panel(String(payload.get("title", "选择孵育样本")), String(payload.get("body", "")), payload.get("choices", []), "返回孵育位")

func _show_nursery_care_picker() -> void:
	var payload := nursery_service.get_care_picker(current_visit_habitat_id)
	pending_context = {"kind": "nursery_care_select", "on_close": "nursery_menu"}
	decision_panel.open_panel(String(payload.get("title", "今天怎么照看")), String(payload.get("body", "")), payload.get("choices", []), "返回孵育位")

func _show_nursery_result(result: Dictionary) -> void:
	var title := "孵育结果" if bool(result.get("ok", false)) else "还没办成"
	pending_context = {"kind": "nursery_result", "on_close": "nursery_menu"}
	decision_panel.open_panel(title, nursery_service.format_project_result(result), [], "返回孵育位")

func _apply_fishing_side_effects(payload: Dictionary) -> void:
	var catch_species_id := String(payload.get("catch_species_id", ""))
	if not catch_species_id.is_empty():
		GameState.note_fishing_catch(current_visit_habitat_id, catch_species_id, String(payload.get("weight_class", "common")))
	for raw_marker in payload.get("observe_markers", []):
		var marker_id := String(raw_marker)
		if not marker_id.is_empty():
			GameState.note_observe_marker(marker_id)
	var release_species_id := String(payload.get("release_species_id", ""))
	if not release_species_id.is_empty():
		GameState.note_aquatic_release(release_species_id)
	var pressure_delta := int(payload.get("pressure_delta", 0))
	if pressure_delta != 0:
		GameState.add_fishing_spot_pressure(current_visit_habitat_id, pressure_delta)
	var festival_id := String(payload.get("festival_id", ""))
	var score_delta := int(payload.get("score_delta", 0))
	if not festival_id.is_empty() and score_delta != 0:
		GameState.record_festival_score(festival_id, score_delta)
	var event_id := String(payload.get("event_id", ""))
	if not event_id.is_empty():
		GameState.mark_fishing_event_seen(event_id)
	var items: Dictionary = payload.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)
	for entry in payload.get("journal_entries", []):
		var text := String(entry)
		if not text.is_empty():
			GameState.add_journal_entry(text)
	var trust_rewards: Dictionary = payload.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var target_id := String(npc_id)
		if target_id.is_empty():
			continue
		GameState.add_trust(target_id, int(trust_rewards[npc_id]))
	for raw_flag in payload.get("story_flags", []):
		var flag_id := String(raw_flag)
		if not flag_id.is_empty():
			GameState.set_story_flag(flag_id)
	for raw_delta in payload.get("relation_deltas", []):
		var relation_delta: Dictionary = Dictionary(raw_delta).duplicate(true)
		var actor_a := String(relation_delta.get("actor_a", ""))
		var actor_b := String(relation_delta.get("actor_b", ""))
		if actor_a.is_empty() or actor_b.is_empty():
			continue
		GameState.apply_social_relation_delta(actor_a, actor_b, relation_delta)
	if not current_visit_habitat_id.is_empty():
		GameState.add_weekly_progress("fish_count", 1)
	_check_active_quests()

func _on_decision_choice_selected(choice_id: String) -> void:
	if pending_context.is_empty():
		return
	var context := pending_context.duplicate(true)
	pending_context.clear()
	match String(context.get("kind", "")):
		"starter_select":
			_apply_starter_choice(choice_id)
		"visit_arrival":
			match choice_id:
				"assign_resident":
					_open_resident_picker()
				"nursery_menu":
					_show_nursery_menu()
				"build_menu":
					visit_flow.open_build_menu()
				"shop_menu":
					visit_flow.open_shop_menu()
				"npc_menu":
					visit_flow.open_npc_menu()
				"dojo_menu":
					visit_flow.open_dojo_menu()
				"observe":
					visit_flow.start_observation()
				"fishing_menu":
					_show_fishing_menu()
				"mail_menu":
					_show_mail_menu()
		"minigame_menu":
			var node: Dictionary = board_lookup.get(int(context.get("node_id", -1)), {})
			if not node.is_empty():
				_show_minigame_result(minigame_service.resolve_board_minigame(node, choice_id))
		"infirmary_menu":
			var infirmary_node: Dictionary = board_lookup.get(int(context.get("node_id", -1)), {})
			if not infirmary_node.is_empty() and choice_id == "rest":
				var result: Dictionary = infirmary_service.resolve_voluntary_rest(infirmary_node)
				_push_log("在 %s 主动做了一轮疗养，没有花钱。" % String(infirmary_node.get("name", "疗养所")))
				_show_infirmary_result(result, "finish_transit_stop")
		"resident_select":
			_assign_resident(choice_id)
		"build_select":
			visit_flow.build_selected(choice_id)
		"shop_menu":
			if choice_id.begins_with("buy:"):
				visit_flow.buy_shop_offer(choice_id.trim_prefix("buy:"))
			elif choice_id.begins_with("service:"):
				visit_flow.use_shop_npc_service(choice_id.trim_prefix("service:"))
		"npc_menu":
			if choice_id.begins_with("duel:"):
				_start_npc_intro_duel(choice_id.trim_prefix("duel:"))
			if choice_id.begins_with("talk:"):
				_handle_talk_to_npc(choice_id.trim_prefix("talk:"))
			elif choice_id.begins_with("quest:"):
				_try_accept_quest(choice_id.trim_prefix("quest:"))
		"dojo_menu":
			visit_flow.choose_dojo_tier(choice_id)
		"fishing_menu":
			_show_fishing_result(fishing_service.resolve_fishing_choice(current_visit_habitat_id, choice_id))
		"nursery_menu":
			match choice_id:
				"start_incubation":
					_show_nursery_species_picker()
				"care_incubation":
					_show_nursery_care_picker()
				"hatch_incubation":
					_show_nursery_result(GameState.hatch_nursery_project(current_visit_habitat_id))
		"nursery_species_select":
			_show_nursery_result(GameState.start_nursery_project(current_visit_habitat_id, choice_id))
		"nursery_care_select":
			_show_nursery_result(GameState.care_nursery_project(current_visit_habitat_id, choice_id))
		"team_manage":
			match choice_id:
				"battle_0":
					_open_battle_slot_picker(0)
				"battle_1":
					_open_battle_slot_picker(1)
				"backpack":
					_open_pet_roster_picker()
				"resident_sites":
					_open_camp_resident_site_picker()
				"mail_menu":
					_show_camp_mail_menu()
		"team_battle_slot":
			GameState.set_party_slot(int(context.get("slot_index", 0)), choice_id)
			pending_context = {"kind": "team_result", "on_close": "reopen_base"}
			decision_panel.open_panel("队伍已更新", "%s 已被放到出战位 %d。" % [GameState.get_pet_display_name(choice_id), int(context.get("slot_index", 0)) + 1], [], "返回营地")
		"team_reserve_slot":
			GameState.toggle_reserve_slot(choice_id)
			pending_context = {"kind": "team_result", "on_close": "reopen_base"}
			decision_panel.open_panel("宠物栏已更新", "已切换 %s 的待命状态。" % GameState.get_pet_display_name(choice_id), [], "返回营地")
		"camp_resident_site":
			_open_camp_resident_picker(choice_id)
		"camp_resident_select":
			_assign_resident_to_habitat(String(context.get("habitat_id", "")), choice_id)
		"encounter_preview":
			last_encounter_action_id = choice_id
			visit_flow.choose_encounter_action(choice_id)
		"mail_menu":
			_handle_mail_selection(choice_id)
		"camp_mail_menu":
			_handle_camp_mail_selection(choice_id)
		"menu_settings":
			_apply_menu_setting(choice_id)
		"custom_asset_bind_menu":
			_bind_main_menu_background(choice_id)

func _on_decision_closed() -> void:
	if pending_context.is_empty():
		return
	var context := pending_context.duplicate(true)
	pending_context.clear()
	match String(context.get("on_close", "none")):
		"starter_random":
			var starter_pool := STARTER_SPECIES_IDS.duplicate()
			if starter_pool.is_empty():
				return
			_apply_starter_choice(String(starter_pool[rng.randi_range(0, starter_pool.size() - 1)]), true)
		"show_run_intro":
			if not GameState.has_completed_tutorial("run_intro"):
				_show_tutorial_popup("run_intro")
			else:
				_update_ui()
		"start_pending_battle":
			_open_pending_tutorial_battle()
		"start_environment_battle":
			_open_pending_environment_battle()
		"finish_visit":
			_finish_current_visit()
		"finish_board_event":
			_finish_board_event_visit()
		"finish_transit_stop":
			_finish_transit_stop()
		"resume_board_stop":
			var node: Dictionary = board_lookup.get(current_node_id, {})
			if not node.is_empty():
				_continue_board_stop_flow(node)
		"reopen_settings":
			if main_menu_panel.visible:
				_refresh_main_menu()
				_open_settings_menu()
		"arrival":
			if not current_visit_habitat_id.is_empty():
				visit_flow.start_visit(current_visit_habitat_id)
		"nursery_menu":
			if not current_visit_habitat_id.is_empty():
				_show_nursery_menu()
		"shop_menu":
			if not current_visit_habitat_id.is_empty():
				visit_flow.open_shop_menu()
		"team_manage":
			_open_team_manage_menu()
		"reopen_base":
			_on_base_pressed()
		_:
			pass
	story_director.try_flush_pending_quest_story_beats()

func _on_visit_finished(_report: Dictionary) -> void:
	_resolve_visit_yield(current_visit_habitat_id)
	current_visit_habitat_id = ""
	_advance_after_travel_stop()

func _resolve_board_event_node(node: Dictionary) -> void:
	var event_package := dialogue_service.build_board_event_package(current_visit_habitat_id)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "事件格")),
		String(node.get("description", "沿途突然冒出了一段小插曲。")),
	]
	if event_package.is_empty():
		body_lines.append("")
		body_lines.append("这格今天没有额外剧情，只留下了一点沿途见闻。")
		_push_log("路过事件格，但今天没有触发额外插曲。")
	else:
		var event_title := String(event_package.get("title", "沿途插曲"))
		var npc_id := String(event_package.get("npc_id", ""))
		var npc_name := String(DataRepository.get_npc(npc_id).get("name", ""))
		body_lines.append("")
		body_lines.append("[b]%s[/b]" % event_title)
		if not npc_name.is_empty():
			body_lines.append("遇到：%s" % npc_name)
		for line in event_package.get("stage_lines", []):
			body_lines.append(String(line))
		if Array(event_package.get("stage_lines", [])).is_empty():
			var summary := String(event_package.get("summary", ""))
			if not summary.is_empty():
				body_lines.append(summary)
		var outcome := String(event_package.get("outcome", ""))
		if not outcome.is_empty():
			body_lines.append("结果：%s" % outcome)
		var reward_lines := _build_board_event_reward_lines(event_package)
		if not reward_lines.is_empty():
			body_lines.append("")
			body_lines.append("[b]这次插曲带来的变化[/b]")
			body_lines.append("\n".join(reward_lines))
		_apply_board_event_package(event_package)
		_push_log("沿途插曲：%s。" % event_title)
		_check_active_quests()
	pending_context = {"kind": "board_event", "on_close": "finish_board_event"}
	decision_panel.open_panel("事件格", "\n".join(body_lines), [], "继续前进")

func _apply_board_event_package(event_package: Dictionary) -> void:
	var event_id := String(event_package.get("id", ""))
	if not event_id.is_empty():
		GameState.note_ambient_event_seen(
			event_id,
			Array(event_package.get("tags", [])).duplicate(true),
			current_visit_habitat_id
		)
	for completed_event_id in event_package.get("completed_events", []):
		if not String(completed_event_id).is_empty():
			GameState.mark_event_completed(String(completed_event_id))
	for dialogue_id in event_package.get("unlocked_dialogues", []):
		if not String(dialogue_id).is_empty():
			GameState.unlock_dialogue(String(dialogue_id))
	for raw_flag in event_package.get("story_flags", []):
		var flag_id := String(raw_flag)
		if not flag_id.is_empty():
			GameState.set_story_flag(flag_id)
	for raw_delta in event_package.get("relation_deltas", []):
		var relation_delta: Dictionary = Dictionary(raw_delta).duplicate(true)
		var actor_a := String(relation_delta.get("actor_a", ""))
		var actor_b := String(relation_delta.get("actor_b", ""))
		if actor_a.is_empty() or actor_b.is_empty():
			continue
		GameState.apply_social_relation_delta(actor_a, actor_b, relation_delta)
	var items: Dictionary = event_package.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)
	for entry in event_package.get("journal_entries", []):
		var text := String(entry)
		if not text.is_empty():
			GameState.add_journal_entry(text)
	var trust_rewards: Dictionary = event_package.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var target_id := String(npc_id)
		if target_id.is_empty():
			continue
		GameState.add_trust(target_id, int(trust_rewards[npc_id]))

func _build_board_event_reward_lines(event_package: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var trust_rewards: Dictionary = event_package.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var amount := int(trust_rewards[npc_id])
		if amount <= 0:
			continue
		var npc_name := String(DataRepository.get_npc(String(npc_id)).get("name", String(npc_id)))
		lines.append("- %s 信赖 +%d" % [npc_name, amount])
	var items: Dictionary = event_package.get("items", {})
	for item_id in items.keys():
		lines.append("- 获得 %s ×%d" % [_item_name(String(item_id)), int(items[item_id])])
	for entry in event_package.get("journal_entries", []):
		var text := String(entry)
		if not text.is_empty():
			lines.append("- 笔记更新：%s" % text)
	for dialogue_id in event_package.get("unlocked_dialogues", []):
		var dialogue := DataRepository.get_dialogue(String(dialogue_id))
		var topic := String(dialogue.get("topic", "新话题"))
		lines.append("- 解锁后续话题：%s" % _talk_topic_label(topic))
	for raw_delta in event_package.get("relation_deltas", []):
		var relation_line := _format_relation_delta_line(Dictionary(raw_delta).duplicate(true))
		if not relation_line.is_empty():
			lines.append("- %s" % relation_line)
	return lines

func _resolve_environment_node(node: Dictionary) -> void:
	match String(node.get("environment_kind", "forage")):
		"wild_battle":
			_prepare_environment_battle(node)
		"scout":
			_show_environment_scout_stop(node)
		_:
			_show_environment_forage_stop(node)

func _show_empty_board_stop(node: Dictionary) -> void:
	_show_environment_forage_stop(node)

func _show_environment_forage_stop(node: Dictionary) -> void:
	var reward := _environment_travel_reward(node)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "沿途环境")),
		String(node.get("description", "这是一段会产生沿途内容的环境路段。")),
		"",
		"这里没有固定据点，但能顺手收一波路上的资源。",
	]
	if not reward.is_empty():
		GameState.grant_items(reward)
		body_lines.append("[b]沿途收获[/b] %s" % _format_item_cost(reward))
		_push_log("穿过 %s，顺手带回了 %s。" % [String(node.get("name", "沿途环境")), _format_item_cost(reward)])
	else:
		_push_log("穿过 %s，主要是在调整队伍行进节奏。" % String(node.get("name", "沿途环境")))
	pending_context = {"kind": "transit_stop", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("环境路段", "\n".join(body_lines), [], "继续前进")

func _show_environment_scout_stop(node: Dictionary) -> void:
	GameState.reveal_board_nodes(board_progression_service.build_scout_reveal(current_node_id, 4))
	var reward := _environment_travel_reward(node)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "侦察路段")),
		String(node.get("description", "这是一段适合先看清地形的环境。")),
		"",
		"你在这里多停了一会儿，把前方几格的路况先看清了。",
	]
	if not reward.is_empty():
		GameState.grant_items(reward)
		body_lines.append("[b]沿途收获[/b] %s" % _format_item_cost(reward))
	body_lines.append("[b]额外侦察[/b] 前方路线显露得更远了。")
	_push_log("在 %s 提前看清了后续路况。" % String(node.get("name", "侦察路段")))
	pending_context = {"kind": "transit_stop", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("环境侦察", "\n".join(body_lines), [], "继续前进")

func _prepare_environment_battle(node: Dictionary) -> void:
	var battle_config := _build_environment_battle_config(node)
	if battle_config.is_empty():
		_show_environment_forage_stop(node)
		return
	var enemy_names: Array[String] = []
	for enemy in battle_config.get("enemies", []):
		enemy_names.append(String(enemy.display_name))
	pending_environment_battle = {
		"node_id": int(node.get("id", current_node_id)),
		"node_name": String(node.get("name", "沿途环境")),
		"battle_config": battle_config,
		"reward": _environment_travel_reward(node),
	}
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "野外遭遇")),
		String(node.get("description", "这里潜伏着躁动的野生个体。")),
		"",
		"你刚靠近这里，就把附近游荡的个体惊了出来。",
	]
	var special_encounter_hint := String(node.get("special_encounter_hint", ""))
	if not special_encounter_hint.is_empty():
		body_lines.append("[b]这一圈常见个体[/b] %s" % special_encounter_hint)
	if not enemy_names.is_empty():
		body_lines.append("[b]出现个体[/b] %s" % " / ".join(enemy_names))
	body_lines.append("这次会直接进入遭遇战，胜利后还能尝试捕缚。")
	_push_log("%s 出现了近距离野外遭遇。" % String(node.get("name", "野外遭遇")))
	pending_context = {"kind": "environment_battle_intro", "on_close": "start_environment_battle"}
	decision_panel.open_panel("环境遭遇", "\n".join(body_lines), [], "迎战")

func _open_pending_environment_battle() -> void:
	if pending_environment_battle.is_empty():
		_finish_transit_stop()
		return
	var battle_config: Dictionary = pending_environment_battle.get("battle_config", {})
	if battle_config.is_empty():
		pending_environment_battle.clear()
		_finish_transit_stop()
		return
	decision_panel.hide()
	_start_battle_with_tutorial(
		battle_config,
		"environment_wild",
		"穿过 %s 时惊动了附近的野生个体。" % String(pending_environment_battle.get("node_name", "沿途环境"))
	)

func _build_environment_battle_config(node: Dictionary) -> Dictionary:
	var habitat_id := String(node.get("source_habitat_id", ""))
	if habitat_id.is_empty() or GameState.get_party_uids().size() < 2:
		return {}
	var special_pool: Array = Array(node.get("special_encounter_pool", [])).duplicate(true)
	var using_special_pool := not special_pool.is_empty()
	var first_encounter := encounter_service.roll_custom_entries(special_pool, "environment") if using_special_pool else encounter_service.roll_encounter(habitat_id, "environment")
	if not bool(first_encounter.get("ok", false)):
		return {}
	var second_encounter := encounter_service.roll_custom_entries(special_pool, "environment") if using_special_pool else encounter_service.roll_encounter(habitat_id, "environment")
	var enemy_level := clampi(GameState.get_progression_rank() + 1, 1, 6)
	var first_species_id := String(first_encounter.get("species_id", ""))
	var second_species_id := String(second_encounter.get("species_id", first_species_id))
	var pending_bonus: Dictionary = GameState.peek_pending_minigame_bonus()
	var pending_bonus_text := minigame_service.pending_bonus_summary()
	var subtitle_lines: Array[String] = [
		"环境：%s" % String(node.get("focus", "行进 / 缓冲")),
		"情绪：%s" % String(first_encounter.get("mood_id", "wild")),
	]
	var special_loop_name := String(node.get("special_loop_name", ""))
	if not special_loop_name.is_empty():
		subtitle_lines.append("环带：%s" % special_loop_name)
	var special_encounter_hint := String(node.get("special_encounter_hint", ""))
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
		"consume_minigame_bonus": minigame_service.has_pending_bonus(),
		"encounter_origin": "special_loop" if using_special_pool else "habitat",
		"special_loop_id": String(node.get("special_loop_id", "")),
		"round_limit": 6,
		"allies": _build_player_battle_team(),
		"ally_reserve": _build_player_battle_reserve(),
		"enemies": [
			MonsterInstance.new(first_species_id, enemy_level, 1),
			MonsterInstance.new(second_species_id, enemy_level, 1),
		],
	}

func _build_player_battle_team() -> Array:
	return battle_roster_service.build_active_allies()

func _build_player_battle_reserve() -> Array:
	return battle_roster_service.build_reserve_allies()

func _resolve_environment_battle(result: Dictionary) -> void:
	var payload := pending_environment_battle.duplicate(true)
	pending_environment_battle.clear()
	var node_name := String(payload.get("node_name", "沿途环境"))
	var body_lines: Array[String] = []
	var escaped := bool(result.get("escaped", false))
	var codex_reveals := _reveal_codex_for_battle_payload(payload)
	if bool(result.get("player_won", false)):
		body_lines.append("[b]%s[/b] 已经被稳定下来。" % node_name)
		var captured_species := String(result.get("captured_species", ""))
		if not captured_species.is_empty():
			var acquisition := _acquire_companion(captured_species)
			body_lines.append(String(acquisition.get("body", "%s 愿意靠近。" % captured_species)))
			_check_active_quests()
		var reward: Dictionary = payload.get("reward", {}).duplicate(true)
		if not reward.is_empty():
			GameState.grant_items(reward)
			body_lines.append("[b]沿途收获[/b] %s" % _format_item_cost(reward))
			_push_log("处理完 %s 的遭遇后，顺手带回了 %s。" % [node_name, _format_item_cost(reward)])
		else:
			_push_log("%s 的野外遭遇已经处理完毕。" % node_name)
	elif escaped:
		GameState.add_node_danger(current_node_id, 1)
		body_lines.append("[b]%s[/b] 还没稳住，你先带队撤开了。" % node_name)
		body_lines.append("这里的危险度上升到 %d / 3。" % GameState.get_node_danger(current_node_id))
		_push_log("%s 的野外遭遇还没处理完，队伍先撤开了，危险度继续上升。" % node_name)
	else:
		GameState.add_node_danger(current_node_id, 1)
		body_lines.append("[b]%s[/b] 把你逼退了。" % node_name)
		body_lines.append("这里的危险度上升到 %d / 3。" % GameState.get_node_danger(current_node_id))
		_push_log("%s 的野外遭遇把队伍逼退了，危险度继续上升。" % node_name)
		var defeated_node: Dictionary = board_lookup.get(int(payload.get("node_id", current_node_id)), {}).duplicate(true)
		var infirmary_report: Dictionary = _apply_forced_infirmary_transfer(defeated_node if not defeated_node.is_empty() else {"ring_index": 0})
		body_lines.append("")
		body_lines.append(String(infirmary_report.get("body", "")))
	if not codex_reveals.is_empty():
		var unlocked_titles: Array[String] = []
		for entry in codex_reveals:
			unlocked_titles.append(String(Dictionary(entry).get("title", Dictionary(entry).get("id", "新条目"))))
		body_lines.append("")
		body_lines.append("[b]图鉴识别[/b] %s" % " / ".join(unlocked_titles))
	pending_context = {"kind": "environment_battle_result", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("环境遭遇结果", "\n".join(body_lines), [], "继续前进")

func _reveal_codex_for_battle_payload(payload: Dictionary) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	var seen_species := {}
	var battle_config: Dictionary = payload.get("battle_config", {})
	for enemy_value in battle_config.get("enemies", []):
		if not (enemy_value is MonsterInstance):
			continue
		var unit: MonsterInstance = enemy_value
		var species_id := String(unit.species_id)
		if species_id.is_empty() or seen_species.has(species_id):
			continue
		seen_species[species_id] = true
		for entry in GameState.reveal_codex_for_species(species_id):
			unlocked.append(Dictionary(entry).duplicate(true))
	return unlocked

func _environment_travel_reward(node: Dictionary) -> Dictionary:
	var habitat_id := String(node.get("source_habitat_id", ""))
	if habitat_id.is_empty():
		return {}
	var base_reward := _base_visit_reward(habitat_id)
	if base_reward.is_empty():
		return {}
	var item_ids: Array[String] = []
	for item_id in base_reward.keys():
		item_ids.append(String(item_id))
	item_ids.sort()
	var chosen_id := item_ids[0]
	return {chosen_id: maxi(1, int(base_reward[chosen_id]))}

func _show_locked_board_stop(node: Dictionary) -> void:
	var habitat_id := String(node.get("habitat_id", ""))
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "未开放据点")),
		String(node.get("description", "这里现在还不适合久留。")),
		"",
		"%s" % _unlock_marker_text(habitat_id),
		"这次先从这里路过，等时机到了再回来好好看看。",
	]
	_push_log("路过 %s，这里现在还只能先看看。" % String(node.get("name", "未开放据点")))
	pending_context = {"kind": "locked_stop", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("暂时只能路过", "\n".join(body_lines), [], "继续前进")

func _show_ring_gate_blocked(node: Dictionary, message: String) -> void:
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(node.get("name", "外环路口")),
		String(node.get("description", "这里通往更外侧的环路。")),
		"",
		message,
	]
	_push_log("抵达 %s，但前面的路现在还没完全打开。" % String(node.get("name", "外环路口")))
	pending_context = {"kind": "ring_gate_locked", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("前路还没打开", "\n".join(body_lines), [], "继续前进")

func _apply_ring_unlock_result(result: Dictionary, open_panel: bool = true) -> void:
	if result.is_empty() or not bool(result.get("ok", false)):
		return
	GameState.reveal_board_nodes(result.get("revealed_nodes", []))
	_refresh_board_region(false)
	_push_log(String(result.get("message", "更远的路已经露出来了。")))
	if not open_panel:
		return
	pending_context = {"kind": "ring_unlock", "on_close": "finish_transit_stop"}
	decision_panel.open_panel("前路打开了", String(result.get("message", "更远的路已经露出来了。")), [], "继续前进")

func _finish_board_event_visit() -> void:
	current_visit_habitat_id = ""
	_advance_after_travel_stop()

func _finish_transit_stop() -> void:
	current_visit_habitat_id = ""
	_advance_after_travel_stop()

func _advance_after_travel_stop() -> void:
	if _post_travel_resolution_in_progress:
		return
	_post_travel_resolution_in_progress = true
	_resolve_season_boss_reward()
	_resolve_board_threat_turn()
	if season_finished:
		_post_travel_resolution_in_progress = false
		return
	var is_week_end := GameState.weekly_turn >= 5
	if is_week_end:
		_resolve_weekly_settlement()
	await _run_ai_turns()
	var day_report := GameState.advance_day()
	for line in day_report.get("lines", []):
		_push_log(line)
	_begin_next_day()
	_post_travel_resolution_in_progress = false

func _run_ai_turns() -> void:
	if not runtime_session_started:
		return
	var ai_result: Dictionary = ai_player_service.simulate_turns(board_lookup, false)
	var reports: Array = ai_result.get("reports", [])
	if reports.is_empty():
		return
	var staged_players: Array = GameState.get_ai_players().duplicate(true)
	ai_turn_in_progress = true
	_active_ai_observation_line = "你腾出片刻观察其他远征队的推进。"
	_update_ui()
	if not GameState.should_skip_animations():
		_play_stage_transition("对手回合", "你空出手来观察其他远征队的推进、抢点和遭遇。", Color(0.95, 0.74, 0.38, 1.0))
		await get_tree().create_timer(0.28).timeout
	for raw_report in reports:
		var report: Dictionary = Dictionary(raw_report).duplicate(true)
		await _play_single_ai_observed_turn(report, staged_players)
	GameState.set_ai_players(staged_players.duplicate(true))
	ai_turn_in_progress = false
	_active_ai_observation_line = ""
	board_view.hide_observer()
	_update_ui()
	_show_ai_turn_report(ai_result)

func _play_single_ai_observed_turn(report: Dictionary, staged_players: Array) -> void:
	var player_index := int(report.get("index", -1))
	var line := String(report.get("line", "")).strip_edges()
	if player_index < 0 or player_index >= staged_players.size():
		if not line.is_empty():
			_active_ai_observation_line = line
			_push_log("对手回合：%s" % line)
			_update_ui()
		return

	var before_player: Dictionary = Dictionary(staged_players[player_index]).duplicate(true)
	var after_player: Dictionary = Dictionary(report.get("player", before_player)).duplicate(true)
	var move: Dictionary = Dictionary(report.get("move", {})).duplicate(true)
	var landing: Dictionary = Dictionary(report.get("landing", {})).duplicate(true)
	var display_name := String(after_player.get("display_name", before_player.get("display_name", "对手")))
	var start_node_id := int(before_player.get("current_node_id", -1))
	var path: Array[int] = []
	for raw_node_id in Array(move.get("path", [])):
		path.append(int(raw_node_id))
	if path.is_empty() and start_node_id >= 0:
		path.append(start_node_id)

	board_view.set_observer_node(start_node_id, true)
	_active_ai_observation_line = _build_ai_observation_move_line(display_name, move, landing, after_player)
	_update_ui()
	if not GameState.should_skip_animations():
		await get_tree().create_timer(AI_OBSERVE_PREPARE_DELAY).timeout

	if path.size() >= 2:
		await board_view.play_observer_travel(path)
	elif start_node_id >= 0:
		board_view.set_observer_node(start_node_id, true)

	staged_players[player_index] = after_player
	GameState.set_ai_players(staged_players.duplicate(true))
	_active_ai_observation_line = _build_ai_observation_landing_line(display_name, landing, report)
	_update_ui()
	if not GameState.should_skip_animations():
		await get_tree().create_timer(AI_OBSERVE_LANDING_DELAY).timeout

	if line.is_empty():
		line = _build_ai_observation_landing_line(display_name, landing, report)
	_push_log("对手回合：%s" % line)
	_active_ai_observation_line = "%s 的下一拍意图：%s" % [
		display_name,
		String(report.get("intent", "继续观察")),
	]
	_update_ui()
	if not GameState.should_skip_animations():
		await get_tree().create_timer(AI_OBSERVE_TURN_FINISH_DELAY).timeout

func _build_ai_observation_move_line(display_name: String, move: Dictionary, landing: Dictionary, rival: Dictionary) -> String:
	var destination_name := String(move.get("destination_name", landing.get("node_name", "")))
	if destination_name.is_empty():
		destination_name = String(board_lookup.get(int(rival.get("current_node_id", -1)), {}).get("name", "未知节点"))
	var final_roll := int(move.get("final_roll", 0))
	if bool(move.get("stayed_put", false)):
		return "%s 掷出 %d，但前方没有精确落点，先原地整备。" % [display_name, final_roll]

	var reroll_text := ""
	if bool(move.get("reroll_used", false)):
		reroll_text = "，不满意首掷 %d，改掷 %d" % [
			int(move.get("first_roll", final_roll)),
			int(move.get("reroll_value", final_roll)),
		]
	var path_text := _format_ai_path_text(move.get("path_names", []))
	if not path_text.is_empty():
		return "%s 掷出 %d%s，沿 %s 推进到 %s。" % [
			display_name,
			final_roll,
			reroll_text,
			path_text,
			destination_name,
		]
	return "%s 掷出 %d%s，推进到 %s。" % [
		display_name,
		final_roll,
		reroll_text,
		destination_name,
	]

func _build_ai_observation_landing_line(display_name: String, landing: Dictionary, report: Dictionary) -> String:
	var landing_text := String(landing.get("text", "")).strip_edges()
	if not landing_text.is_empty():
		return "%s：%s" % [display_name, landing_text]
	return "%s：%s。" % [
		display_name,
		String(report.get("short", "完成行动")),
	]

func _show_ai_turn_report(ai_result: Dictionary) -> void:
	_last_ai_turn_report = Dictionary(ai_result).duplicate(true)
	var sections := _build_ai_report_sections(_last_ai_turn_report)
	if sections.is_empty():
		return
	system_panel.open_panel("外头动静", sections, String(sections[0].get("id", "ai_0")))

func _on_base_closed() -> void:
	if camp_panel_requires_finish:
		camp_panel_requires_finish = false
		_finish_camp_visit()
		return
	_update_ui()
	story_director.try_flush_pending_quest_story_beats()

func _on_system_panel_closed() -> void:
	_update_ui()
	story_director.try_flush_pending_quest_story_beats()

func _on_base_manage_requested() -> void:
	_open_team_manage_menu()

func _on_battle_finished(result: Dictionary) -> void:
	if pending_battle_source == "npc_intro_duel":
		_resolve_npc_intro_duel(result)
	elif pending_battle_source == "environment_wild":
		_resolve_environment_battle(result)
	else:
		visit_flow.resolve_dojo_battle(result)
	pending_battle_source = ""
	pending_npc_duel_id = ""
	_update_ui()

func _open_team_manage_menu() -> void:
	var choices := [
		{"id": "battle_0", "label": "出战位 1", "summary": "当前：%s" % _battle_slot_name_at(0)},
		{"id": "battle_1", "label": "出战位 2", "summary": "当前：%s" % _battle_slot_name_at(1)},
		{"id": "backpack", "label": "调整宠物栏", "summary": "当前：%d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity]},
		{"id": "resident_sites", "label": "安排看守", "summary": "在营地统一调整各据点的主看守。"},
		{"id": "mail_menu", "label": "处理留信", "summary": "当前待处理：%d 处" % _pending_mail_targets().size(), "disabled": _pending_mail_targets().is_empty()},
	]
	pending_context = {"kind": "team_manage", "on_close": "reopen_base"}
	decision_panel.open_panel("营地整备", "营地只在路过时弹出；队伍、看守和留信都改到这里统一处理。", choices, "返回营地")

func _open_battle_slot_picker(slot_index: int) -> void:
	var choices := []
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		choices.append({
			"id": pet_uid,
			"label": "%s ★%d" % [String(companion.get("display_name", "未命名伙伴")), int(companion.get("star_level", 1))],
			"summary": "%s ｜ 当前：%s" % [String(companion.get("species_id", "")), _companion_slot_label(pet_uid)],
		})
	pending_context = {"kind": "team_battle_slot", "slot_index": slot_index, "on_close": "team_manage"}
	decision_panel.open_panel("选择出战位 %d" % (slot_index + 1), "挑一只本场直接上阵的伙伴。", choices, "返回整备")

func _open_pet_roster_picker() -> void:
	var choices := []
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		var in_reserve := GameState.get_reserve_uids().has(pet_uid)
		choices.append({
			"id": pet_uid,
			"label": "%s ★%d" % [String(companion.get("display_name", "未命名伙伴")), int(companion.get("star_level", 1))],
			"summary": "%s ｜ 人口 %d ｜ %s" % [String(companion.get("species_id", "")), GameState.get_pet_population_cost(pet_uid), "当前已在休息位" if in_reserve else "当前未在休息位"],
			"disabled": GameState.get_party_uids().has(pet_uid),
		})
	pending_context = {"kind": "team_reserve_slot", "on_close": "team_manage"}
	decision_panel.open_panel("调整宠物栏", "休息位不上场，但会提供羁绊；每只会占用不同人口值。元素、生态和职能按独特物种计数，特性羁绊按实际单位计数。", choices, "返回整备")

func _open_camp_resident_site_picker() -> void:
	var choices := []
	for habitat_id in GameState.habitats.keys():
		var habitat := DataRepository.get_habitat(String(habitat_id))
		if habitat.is_empty() or String(habitat.get("type", "")) != "habitat":
			continue
		if not GameState.is_habitat_unlocked(String(habitat_id)):
			continue
		var state: Dictionary = GameState.habitats.get(String(habitat_id), {})
		var resident_actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		choices.append({
			"id": String(habitat_id),
			"label": String(habitat.get("name", habitat_id)),
			"summary": "当前看守：%s ｜ 据点等级 %d" % [
				GameState.get_actor_display_name(resident_actor_id) if not resident_actor_id.is_empty() else "暂无",
				int(state.get("rank", 0)),
			],
		})
	pending_context = {"kind": "camp_resident_site", "on_close": "team_manage"}
	decision_panel.open_panel("选择看守地点", "先挑一个要在营地里统一调整的据点。", choices, "返回整备")

func _open_camp_resident_picker(habitat_id: String) -> void:
	var choices := []
	choices.append({"id": GameState.PLAYER_ACTOR_ID, "label": "玩家", "summary": "由玩家本人临时看守这里；更适合先顶上空缺。"})
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		var home_id := String(companion.get("residence_habitat_id", ""))
		choices.append({
			"id": pet_uid,
			"label": String(companion.get("display_name", "未命名伙伴")),
			"summary": "当前安居：%s ｜ 偏好：%s" % [
				_habitat_name(home_id) if not home_id.is_empty() else "暂未安居",
				", ".join(companion.get("resident_tags", [])),
			],
		})
	pending_context = {"kind": "camp_resident_select", "habitat_id": habitat_id, "on_close": "team_manage"}
	decision_panel.open_panel("安排看守", "为 %s 挑一个更合适的看守者。" % _habitat_name(habitat_id), choices, "返回整备")

func _assign_resident_to_habitat(habitat_id: String, pet_uid: String) -> void:
	var result := habitat_service.assign_resident(habitat_id, pet_uid)
	var body := ""
	if bool(result.get("ok", false)):
		var pet_name := GameState.get_actor_display_name(pet_uid)
		var fit_text := "它对这里很有亲近感。" if bool(result.get("preference_match", false)) else "它还需要时间适应这里。"
		body = "%s 被安排去看守 %s。\n%s" % [pet_name, _habitat_name(habitat_id), fit_text]
		_push_log(body.replace("\n", " "))
		_check_active_quests()
	else:
		body = _build_fail_reason(String(result.get("reason", "unknown")))
	pending_context = {"kind": "resident_result", "on_close": "reopen_base"}
	decision_panel.open_panel("看守安排", body, [], "返回营地")

func _show_camp_mail_menu() -> void:
	var targets := _pending_mail_targets()
	if targets.is_empty():
		pending_context = {"kind": "camp_mail_menu", "on_close": "reopen_base"}
		decision_panel.open_panel("处理留信", "目前没有需要寄出的跨点消息。", [], "返回营地")
		return
	var choices := []
	for destination in targets:
		choices.append({
			"id": destination,
			"label": _habitat_name(destination),
			"summary": "把今天要转交的留信送往这里。",
		})
	pending_context = {"kind": "camp_mail_menu", "on_close": "team_manage"}
	decision_panel.open_panel("处理留信", "在营地统一处理今天的跨点消息。", choices, "返回整备")

func _handle_camp_mail_selection(destination: String) -> void:
	GameState.note_mail(destination)
	_push_log("你在营地寄出了送往 %s 的留信。" % _habitat_name(destination))
	_check_active_quests()
	pending_context = {"kind": "mail_result", "on_close": "reopen_base"}
	decision_panel.open_panel("留信已寄出", "今天处理了一封送往 %s 的消息。" % _habitat_name(destination), [], "返回营地")

func _open_resident_picker() -> void:
	var choices := []
	choices.append({"id": GameState.PLAYER_ACTOR_ID, "label": "玩家", "summary": "由玩家本人临时看守这里；适合先补上空缺。"})
	for companion in GameState.get_companions():
		var pet_uid := String(companion.get("uid", ""))
		var home_id := String(companion.get("residence_habitat_id", ""))
		choices.append({
			"id": pet_uid,
			"label": String(companion.get("display_name", "未命名伙伴")),
			"summary": "当前安居：%s ｜ 偏好：%s" % [
				_habitat_name(home_id) if not home_id.is_empty() else "暂未安居",
				", ".join(companion.get("resident_tags", [])),
			],
		})
	pending_context = {"kind": "resident_select", "on_close": "arrival"}
	decision_panel.open_panel("安排看守", "挑一个更适合看着这里的人或伙伴。", choices, "返回地点")

func _show_mail_menu() -> void:
	var targets := _pending_mail_targets()
	if targets.is_empty():
		pending_context = {"kind": "mail_menu", "on_close": "arrival"}
		decision_panel.open_panel("寄送留信", "目前没有需要寄送的跨点消息。", [], "返回地点")
		return
	var choices := []
	for destination in targets:
		choices.append({
			"id": destination,
			"label": _habitat_name(destination),
			"summary": "把今天的信件和托付送过去。",
		})
	pending_context = {"kind": "mail_menu", "on_close": "arrival"}
	decision_panel.open_panel("寄送留信", "挑一个今天要处理的目标地点。", choices, "返回地点")

func _assign_resident(pet_uid: String) -> void:
	var result := habitat_service.assign_resident(current_visit_habitat_id, pet_uid)
	var body := ""
	if bool(result.get("ok", false)):
		var pet_name := GameState.get_actor_display_name(pet_uid)
		var fit_text := "它对这里很有亲近感。" if bool(result.get("preference_match", false)) else "它还需要时间适应这里。"
		body = "%s 被安排去看守 %s。\n%s" % [pet_name, _habitat_name(current_visit_habitat_id), fit_text]
		_push_log(body.replace("\n", " "))
		_check_active_quests()
	else:
		body = _build_fail_reason(String(result.get("reason", "unknown")))
	pending_context = {"kind": "resident_result", "on_close": "finish_visit"}
	decision_panel.open_panel("看守安排", body, [], "结束偶遇")

func _start_npc_intro_duel(npc_id: String) -> void:
	var result := npc_service.prepare_intro_duel(npc_id, current_visit_habitat_id)
	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "unknown"))
		var body := "这场初见决斗暂时无法开始。"
		match reason:
			"battle_slots_missing":
				body = "先去总览安排好 2 个出战位，第一次见面才能切磋。"
			"already_resolved":
				body = "这场初见切磋已经打过了，现在可以好好聊聊了。"
			"enemy_pool_missing":
				body = "暂时找不到可用的切磋对手。"
			"npc_missing":
				body = "这个偶遇对象暂时不在记录里。"
			_:
				body = "这场初见决斗还没准备好。"
		pending_context = {"kind": "npc_duel_result", "on_close": "finish_visit"}
		decision_panel.open_panel("初见决斗", body, [], "结束偶遇")
		return

	pending_npc_duel_id = npc_id
	_start_battle_with_tutorial(
		result.get("battle_config", {}),
		"npc_intro_duel",
		"第一次偶遇 %s，先以切磋定彼此态度。" % String(result.get("npc", {}).get("name", "某人"))
	)

func _resolve_npc_intro_duel(battle_result: Dictionary) -> void:
	if pending_npc_duel_id.is_empty():
		return

	var result := npc_service.resolve_intro_duel(pending_npc_duel_id, battle_result)
	var npc: Dictionary = result.get("npc", {})
	var npc_name := String(npc.get("name", "某人"))
	var body_lines: Array[String] = []
	if bool(result.get("won", false)):
		body_lines.append("[b]%s[/b] 认可了你的实力，愿意坐下来和你好好聊。" % npc_name)
		body_lines.append("基础信赖提高到 %d。" % int(result.get("base_trust", 0)))
		_push_log("你赢下了与 %s 的初见切磋，对方明显更愿意配合。" % npc_name)
	else:
		body_lines.append("[b]%s[/b] 记住了这场败局，但仍允许你之后再来偶遇。" % npc_name)
		body_lines.append("基础信赖落在 %d。" % int(result.get("base_trust", 0)))
		_push_log("第一次切磋没能赢过 %s，后续关系需要慢慢补。" % npc_name)
		var infirmary_report: Dictionary = _apply_forced_infirmary_transfer(board_lookup.get(current_node_id, {}).duplicate(true))
		body_lines.append("")
		body_lines.append(String(infirmary_report.get("body", "")))
	body_lines.append("当前信赖：%d" % int(result.get("trust", 0)))
	var unlocked_lines: Array[String] = []
	for entry in result.get("unlocked", []):
		unlocked_lines.append("- 信赖 %d：%s" % [int(entry.get("threshold", 0)), String(entry.get("reward", ""))])
	if not unlocked_lines.is_empty():
		body_lines.append("")
		body_lines.append("[b]已达成的信赖反馈[/b]")
		body_lines.append("\n".join(unlocked_lines))
	pending_context = {"kind": "npc_duel_result", "on_close": "finish_visit"}
	decision_panel.open_panel("初见决斗", "\n".join(body_lines), [], "结束偶遇")

func _handle_talk_to_npc(npc_id: String) -> void:
	if npc_service.needs_intro_duel(npc_id):
		pending_context = {"kind": "talk_result", "on_close": "finish_visit"}
		decision_panel.open_panel("现在还聊不开", "第一次见面要先切磋一下，熟了之后再慢慢聊。", [], "结束偶遇")
		return

	GameState.note_talk(npc_id)
	GameState.add_weekly_progress("talk_count", 1)
	if _can_mark_return(npc_id):
		GameState.note_return(npc_id)
	var npc := DataRepository.get_npc(npc_id)
	var talk_package := dialogue_service.build_talk_package(npc_id, current_visit_habitat_id)
	var trust_rewards: Dictionary = talk_package.get("trust_rewards", {})
	var active_npc_bonus := int(trust_rewards.get(npc_id, 0))
	var trust_result := npc_service.complete_trust_reward(npc_id, 1 + active_npc_bonus)
	var cutscene_played := await _play_talk_cutscene(npc_id, npc, talk_package)
	_apply_talk_side_effects(npc_id, talk_package)
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
			var outcome := String(event_result.get("outcome", ""))
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
	var reward_lines := _build_talk_reward_lines(npc_id, talk_package)
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
	var dialogue_id := String(talk_package.get("dialogue_id", ""))
	var topic := String(talk_package.get("topic", "daily"))
	if not dialogue_id.is_empty():
		GameState.note_dialogue_seen(npc_id, dialogue_id, topic)
	_push_log("和 %s 聊了聊，这次谈到了%s。" % [String(npc.get("name", "某人")), _talk_topic_label(topic)])
	_check_active_quests()
	pending_context = {"kind": "talk_result", "on_close": "finish_visit"}
	decision_panel.open_panel("交谈结果", "\n".join(body_lines), [], "结束偶遇")

func _should_skip_cutscene_runtime() -> bool:
	return DisplayServer.get_name() == "headless" or not is_instance_valid(cutscene_panel)

func _play_talk_cutscene(npc_id: String, npc: Dictionary, talk_package: Dictionary) -> bool:
	if _should_skip_cutscene_runtime():
		return false
	var cutscene_payload := cutscene_service.build_talk_cutscene(npc_id, npc, talk_package)
	var steps: Array = Array(cutscene_payload.get("steps", [])).duplicate(true)
	var dialogue_runtime: Dictionary = Dictionary(cutscene_payload.get("dialogue_runtime", {})).duplicate(true)
	if steps.is_empty() and dialogue_runtime.is_empty():
		return false
	for raw_step in steps:
		await _present_cutscene_step(Dictionary(raw_step).duplicate(true))
	if not dialogue_runtime.is_empty():
		await _play_dialogue_cutscene(dialogue_runtime)
	cutscene_panel.hide()
	cutscene_panel.modulate.a = 1.0
	return true

func _present_cutscene_step(step: Dictionary) -> String:
	if _should_skip_cutscene_runtime():
		return ""
	cutscene_panel.open_step(step)
	var choices: Array = Array(step.get("choices", [])).duplicate(true)
	if choices.is_empty():
		await cutscene_panel.continued
		return ""
	await cutscene_panel.choice_selected
	return cutscene_panel.last_choice_id

func _play_dialogue_cutscene(dialogue_runtime: Dictionary) -> void:
	var current_id := String(dialogue_runtime.get("start_node_id", "start"))
	var guard := 0
	while guard < 24:
		guard += 1
		var step := cutscene_service.build_dialogue_step(dialogue_runtime, current_id)
		if step.is_empty():
			break
		var choice_id := await _present_cutscene_step(step)
		if bool(step.get("end", false)) and String(step.get("next", "")).is_empty() and choice_id.is_empty():
			break
		current_id = cutscene_service.resolve_dialogue_next(dialogue_runtime, current_id, choice_id)
		if current_id.is_empty():
			break

func _apply_talk_side_effects(active_npc_id: String, talk_package: Dictionary) -> void:
	var story_beat: Dictionary = Dictionary(talk_package.get("story_beat", {})).duplicate(true)
	if not story_beat.is_empty():
		story_service.commit_story_beat(story_beat)
	var ambient_event: Dictionary = Dictionary(talk_package.get("event", {})).duplicate(true)
	var ambient_event_id := String(ambient_event.get("id", ""))
	if not ambient_event_id.is_empty():
		GameState.note_ambient_event_seen(
			ambient_event_id,
			Array(ambient_event.get("tags", [])).duplicate(true),
			current_visit_habitat_id
		)
	for event_id in talk_package.get("completed_events", []):
		if not String(event_id).is_empty():
			GameState.mark_event_completed(String(event_id))
	for dialogue_id in talk_package.get("unlocked_dialogues", []):
		if not String(dialogue_id).is_empty():
			GameState.unlock_dialogue(String(dialogue_id))
	for raw_flag in talk_package.get("story_flags", []):
		var flag_id := String(raw_flag)
		if not flag_id.is_empty():
			GameState.set_story_flag(flag_id)
	for raw_delta in talk_package.get("relation_deltas", []):
		var relation_delta: Dictionary = Dictionary(raw_delta).duplicate(true)
		var actor_a := String(relation_delta.get("actor_a", ""))
		var actor_b := String(relation_delta.get("actor_b", ""))
		if actor_a.is_empty() or actor_b.is_empty():
			continue
		GameState.apply_social_relation_delta(actor_a, actor_b, relation_delta)
	var items: Dictionary = talk_package.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)
	for entry in talk_package.get("journal_entries", []):
		var text := String(entry)
		if not text.is_empty():
			GameState.add_journal_entry(text)
	var trust_rewards: Dictionary = talk_package.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var target_id := String(npc_id)
		if target_id.is_empty() or target_id == active_npc_id:
			continue
		GameState.add_trust(target_id, int(trust_rewards[npc_id]))

func _build_talk_reward_lines(active_npc_id: String, talk_package: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var trust_rewards: Dictionary = talk_package.get("trust_rewards", {})
	for npc_id in trust_rewards.keys():
		var amount := int(trust_rewards[npc_id])
		if amount <= 0:
			continue
		if String(npc_id) == active_npc_id:
			lines.append("- 额外信赖 +%d" % amount)
		else:
			var npc_name := String(DataRepository.get_npc(String(npc_id)).get("name", String(npc_id)))
			lines.append("- %s 信赖 +%d" % [npc_name, amount])
	var items: Dictionary = talk_package.get("items", {})
	for item_id in items.keys():
		lines.append("- 获得 %s ×%d" % [String(item_id), int(items[item_id])])
	for entry in talk_package.get("journal_entries", []):
		var text := String(entry)
		if not text.is_empty():
			lines.append("- 笔记更新：%s" % text)
	for dialogue_id in talk_package.get("unlocked_dialogues", []):
		var dialogue := DataRepository.get_dialogue(String(dialogue_id))
		var topic := String(dialogue.get("topic", "新话题"))
		lines.append("- 解锁后续话题：%s" % _talk_topic_label(topic))
	for raw_delta in talk_package.get("relation_deltas", []):
		var relation_line := _format_relation_delta_line(Dictionary(raw_delta).duplicate(true))
		if not relation_line.is_empty():
			lines.append("- %s" % relation_line)
	return lines

func _format_relation_delta_line(relation_delta: Dictionary) -> String:
	var actor_a := String(relation_delta.get("actor_a", ""))
	var actor_b := String(relation_delta.get("actor_b", ""))
	if actor_a.is_empty() or actor_b.is_empty():
		return ""
	var changes: Array[String] = []
	for stat_key in ["affinity", "familiarity", "fear", "rivalry"]:
		if not relation_delta.has(stat_key):
			continue
		var amount := int(relation_delta.get(stat_key, 0))
		if amount == 0:
			continue
		changes.append("%s %s%d" % [_relation_stat_label(stat_key), "+" if amount > 0 else "", amount])
	if changes.is_empty():
		return ""
	return "%s ↔ %s：%s" % [_social_actor_label(actor_a), _social_actor_label(actor_b), " / ".join(changes)]

func _social_actor_label(actor_id: String) -> String:
	var normalized := actor_id
	if normalized.begins_with("npc:"):
		normalized = normalized.trim_prefix("npc:")
	elif normalized.begins_with("species:"):
		normalized = normalized.trim_prefix("species:")
	var npc := DataRepository.get_npc(normalized)
	if not npc.is_empty():
		return String(npc.get("name", normalized))
	var species := DataRepository.get_species(normalized)
	if not species.is_empty():
		return String(species.get("name", normalized))
	var aquatic_species := DataRepository.get_aquatic_species(normalized)
	if not aquatic_species.is_empty():
		return String(aquatic_species.get("name", normalized))
	return normalized

func _relation_stat_label(stat_key: String) -> String:
	match stat_key:
		"affinity":
			return "亲近"
		"familiarity":
			return "熟悉"
		"fear":
			return "戒备"
		"rivalry":
			return "竞争"
		_:
			return stat_key

func _talk_topic_label(topic: String) -> String:
	if topic.is_empty():
		return "日常"
	return topic.replace("_", " / ")

func _try_accept_quest(quest_id: String) -> void:
	var quest := DataRepository.get_quest(quest_id)
	if quest.is_empty():
		return
	var giver_id := String(quest.get("giver", ""))
	if npc_service.needs_intro_duel(giver_id):
		var giver := DataRepository.get_npc(giver_id)
		pending_context = {"kind": "quest_result", "on_close": "finish_visit"}
		decision_panel.open_panel("现在还接不了委托", "第一次见面要先和 %s 切磋一下，熟了之后才能接这份委托。" % String(giver.get("name", "委托人")), [], "结束偶遇")
		return
	var cost := _accept_cost_for_quest(quest)
	if not cost.is_empty() and not GameState.can_pay(cost):
		pending_context = {"kind": "quest_result", "on_close": "finish_visit"}
		decision_panel.open_panel("暂时接不下", "还缺少交付物资：%s" % _format_item_cost(cost), [], "结束偶遇")
		return
	if not cost.is_empty():
		GameState.pay_cost(cost)
		for item_id in cost.keys():
			GameState.note_delivery(String(item_id), int(cost[item_id]))
	GameState.accept_quest(quest_id)
	_push_log("接下委托：%s。" % String(quest.get("title", "")))
	_check_active_quests()
	pending_context = {"kind": "quest_result", "on_close": "finish_visit"}
	var quest_lines: Array[String] = ["已记下这件事：%s" % String(quest.get("title", ""))]
	var quest_description := String(quest.get("description", ""))
	if not quest_description.is_empty():
		quest_lines.append("")
		quest_lines.append(quest_description)
	decision_panel.open_panel("委托记录", "\n".join(quest_lines), [], "结束偶遇")

func _accept_cost_for_quest(quest: Dictionary) -> Dictionary:
	var cost := {}
	for step in quest.get("steps", []):
		if String(step.get("type", "")) != "deliver":
			continue
		cost[String(step.get("item", ""))] = int(step.get("count", 0))
	return cost

func _handle_mail_selection(destination: String) -> void:
	GameState.note_mail(destination)
	_push_log("寄出了送往 %s 的留信。" % _habitat_name(destination))
	_check_active_quests()
	pending_context = {"kind": "mail_result", "on_close": "finish_visit"}
	decision_panel.open_panel("寄送完成", "今天处理了一封送往 %s 的消息。" % _habitat_name(destination), [], "结束偶遇")

func _handle_encounter_result_effects(payload: Dictionary) -> String:
	var outcome := String(payload.get("outcome", "unknown"))
	var species_id := String(current_encounter.get("species_id", ""))
	var species_name := String(current_encounter.get("species", {}).get("name", species_id))
	if last_encounter_action_id == "observe":
		GameState.note_observe(species_id)
		if current_visit_habitat_id == "mist_moss_cave" and not bool(GameState.quest_memory["observed_markers"].get("note_cache", false)) and rng.randf() <= 0.55:
			GameState.note_observe_marker("note_cache")
			_push_log("你在苔缝里找到了小禾落下的笔记。")
	if last_encounter_action_id == "calm" and outcome != "alert_rise":
		GameState.note_calm(species_id)
	if outcome == "bond_success":
		GameState.reduce_node_danger(current_node_id, 1)
		GameState.note_bond(species_id)
		var acquisition := _acquire_companion(species_id)
		_push_log("%s 愿意靠近，并把这里当成了新的联系点。" % species_name)
		_check_active_quests()
		return "[b]%s[/b]\n%s" % [_encounter_outcome_text(outcome), String(acquisition.get("body", "%s 愿意靠近。" % species_name))]
	elif outcome == "bond_progress":
		GameState.reduce_node_danger(current_node_id, 1)
		_push_log("%s 对你的存在不再那么戒备了。" % species_name)
	elif outcome == "safe_leave":
		GameState.reduce_node_danger(current_node_id, 1)
		_push_log("你选择先后退一步，让这次相遇停在安全距离。")
	elif outcome == "alert_rise":
		var consequence := _apply_alert_rise_consequence(int(payload.get("combat_risk", 1)))
		_push_log("%s 还是更警惕了一些，你决定改天再来。" % species_name)
		_check_active_quests()
		return "[b]%s[/b]\n%s\n%s" % [
			_encounter_outcome_text(outcome),
			species_name,
			String(consequence.get("summary", "这里变得更危险了。")),
		]
	_check_active_quests()
	return "[b]%s[/b]\n%s" % [_encounter_outcome_text(outcome), species_name]

func _apply_alert_rise_consequence(combat_risk: int) -> Dictionary:
	var danger_gain := maxi(1, combat_risk)
	GameState.add_node_danger(current_node_id, danger_gain)
	GameState.queue_node_ambush(current_node_id, 1)
	var lost_items := _take_alert_penalty_items(danger_gain)
	var parts: Array[String] = []
	parts.append("%s 的危险度上升到 %d/3" % [
		String(board_lookup.get(current_node_id, {}).get("name", "当前节点")),
		GameState.get_node_danger(current_node_id),
	])
	parts.append("下次造访前，这里会先触发一次袭扰。")
	if not lost_items.is_empty():
		parts.append("你在混乱中损失了 %s" % _format_item_cost(lost_items))
	_push_log("节点危险上升：%s。" % String(board_lookup.get(current_node_id, {}).get("name", "当前节点")))
	if not lost_items.is_empty():
		_push_log("袭扰损失：%s。" % _format_item_cost(lost_items))
	return {
		"summary": "；".join(parts),
		"lost_items": lost_items,
	}

func _take_alert_penalty_items(amount: int) -> Dictionary:
	var candidates: Array[String] = []
	for item_id in _base_visit_reward(current_visit_habitat_id).keys():
		candidates.append(String(item_id))
	for fallback_id in ["soft_moss", "stone_chip", "fiber", "parts", "tea_leaf", "wood"]:
		if not candidates.has(fallback_id):
			candidates.append(fallback_id)
	var result := {}
	var remaining := maxi(1, amount)
	for item_id in candidates:
		if remaining <= 0:
			break
		var available := int(GameState.inventory.get(item_id, 0))
		if available <= 0:
			continue
		var loss := mini(available, remaining)
		result[item_id] = loss
		remaining -= loss
	if not result.is_empty():
		GameState.pay_cost(result)
	return result

func _acquire_companion(species_id: String) -> Dictionary:
	var is_new_species := GameState.count_species_pets(species_id) == 0
	var pet_uid := GameState.add_companion(species_id)
	var pet := GameState.get_pet(pet_uid)
	var lines: Array[String] = []
	if is_new_species:
		lines.append("%s 愿意靠近，并加入了你的照料名册。" % String(pet.get("display_name", species_id)))
	else:
		lines.append("%s 的新个体加入了队伍，可用于羁绊、看守或升星。" % String(pet.get("display_name", species_id)))
	var merge_result := GameState.merge_species_duplicates(species_id)
	for upgrade in merge_result.get("upgrades", []):
		var upgrade_line := "3 合 1：%s 升到 ★%d，并进化为 %s。" % [
			String(upgrade.get("old_name", species_id)),
			int(upgrade.get("new_star", 1)),
			String(upgrade.get("new_name", species_id)),
		]
		lines.append(upgrade_line)
		_push_log(upgrade_line)
	return {
		"pet_uid": pet_uid,
		"merged": bool(merge_result.get("ok", false)),
		"body": "\n".join(lines),
	}

func _can_mark_return(npc_id: String) -> bool:
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		for step in quest.get("steps", []):
			if String(step.get("type", "")) == "return" and String(step.get("npc", "")) == npc_id:
				return true
	return false

func _pending_mail_targets() -> Array[String]:
	var targets: Array[String] = []
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		for step in quest.get("steps", []):
			if String(step.get("type", "")) != "mail":
				continue
			var destination := String(step.get("destination", ""))
			if destination.is_empty() or bool(GameState.quest_memory["mailed_destinations"].get(destination, false)):
				continue
			if not targets.has(destination):
				targets.append(destination)
	return targets

func _finish_current_visit() -> void:
	if current_visit_habitat_id.is_empty():
		return
	visit_flow.finish_visit()

func _finish_camp_visit() -> void:
	current_visit_habitat_id = ""
	_advance_after_travel_stop()

func _resolve_visit_yield(habitat_id: String) -> void:
	var reward := _base_visit_reward(habitat_id)
	var resonance: Dictionary = synergy_service.build_visit_resonance(habitat_id)
	var base_reward := _base_visit_reward(habitat_id)
	for _roll in range(int(resonance.get("economy_rolls", 0))):
		_merge_reward_items(reward, base_reward)
	_merge_reward_items(reward, _seasonal_visit_reward(habitat_id))
	reward = run_modifier_service.apply_visit_reward_modifiers(reward, GameState.run_modifiers)
	if not reward.is_empty():
		GameState.grant_items(reward)
		_push_log("回营时顺手带回：%s。" % _format_item_cost(reward))
	var growth_lines := _apply_visit_growth_resonance(resonance.get("bond_gains", {}))
	for line in resonance.get("lines", []):
		_push_log("建筑共鸣：%s" % String(line))
	for line in growth_lines:
		_push_log(line)

func _resolve_weekly_settlement() -> void:
	if GameState.weekly_objective.is_empty():
		return
	var objective := GameState.weekly_objective.duplicate(true)
	var progress := GameState.weekly_progress.duplicate(true)
	var hunger_after_week := GameState.consume_hunger(GameState.hunger_cost_per_week)
	var completed := weekly_cycle_service.is_complete(objective, progress)
	var summary_lines := weekly_cycle_service.build_progress_lines(objective, progress)
	_push_log("第 %d 周结算：%s。" % [GameState.week_index, String(objective.get("title", "本周目标"))])
	for line in summary_lines:
		_push_log("周进度：%s。" % line)
	_push_log("周结算额外消耗饥饿 %d，当前 %d / %d。" % [GameState.hunger_cost_per_week, hunger_after_week, GameState.max_hunger])
	if completed:
		var reward_bundle := DataRepository.get_reward_bundle(weekly_cycle_service.get_reward_bundle_id(objective))
		var reward_text := _apply_reward_bundle(reward_bundle)
		if not reward_text.is_empty():
			_push_log("周目标完成，获得 %s。" % reward_text)
	else:
		GameState.grant_items({"soft_moss": 1})
		_push_log("周目标未完成，仍获得休整补给：%s。" % _format_item_cost({"soft_moss": 1}))
	var modifier_bonus := run_modifier_service.apply_weekly_bonus(GameState.run_modifiers)
	if not modifier_bonus.is_empty():
		GameState.apply_system_rewards(modifier_bonus)
		_push_log("词缀追加：%s。" % _format_reward_bundle({"systems": modifier_bonus}))
	GameState.weekly_objective.clear()
	GameState.weekly_progress.clear()

func _annual_competition_status_text() -> String:
	var status := annual_competition_service.build_status_snapshot()
	return String(status.get("summary", ""))

func _maybe_notify_annual_competition_reminder() -> void:
	var reminder := annual_competition_service.maybe_issue_month_reminder()
	if reminder.is_empty() or not bool(reminder.get("ok", false)):
		return
	_push_log(String(reminder.get("log_line", "")))

func _resolve_annual_competition_if_needed() -> Dictionary:
	var result := annual_competition_service.resolve_current_year()
	if result.is_empty() or not bool(result.get("ok", false)):
		return {}
	_push_log(String(result.get("log_line", "")))
	for line in Array(result.get("leaderboard_lines", [])).slice(0, 3):
		_push_log("年赛榜：%s。" % String(line))
	return result

func _annual_competition_result_summary(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var placement := int(result.get("player_placement", 0))
	var reward_text := String(result.get("player_reward_text", ""))
	var summary := "第 %d 名" % placement
	if not reward_text.is_empty():
		summary += "，获得 %s" % reward_text
	return summary

func _resolve_season_boss_reward() -> void:
	var boss_rule := DataRepository.get_season_boss_rule(GameState.season_id)
	if boss_rule.is_empty():
		return
	if GameState.claimed_season_bosses.has(GameState.season_id):
		return
	if _current_boss_node_id() != current_node_id:
		return
	var reward_bundle := DataRepository.get_reward_bundle(String(boss_rule.get("reward_bundle_id", "")))
	var reward_text := _apply_reward_bundle(reward_bundle)
	GameState.claimed_season_bosses.append(GameState.season_id)
	if not reward_text.is_empty():
		_push_log("赛季高潮：%s 被征服，获得 %s。" % [String(boss_rule.get("name", "赛季 Boss")), reward_text])

func _apply_reward_bundle(reward_bundle: Dictionary) -> String:
	if reward_bundle.is_empty():
		return ""
	var items: Dictionary = reward_bundle.get("items", {}).duplicate(true)
	var systems: Dictionary = reward_bundle.get("systems", {}).duplicate(true)
	var unlocks: Array = reward_bundle.get("unlocks", []).duplicate()
	if not items.is_empty():
		GameState.grant_items(items)
	if not systems.is_empty():
		GameState.apply_system_rewards(systems)
	for habitat_id in unlocks:
		GameState.unlock_habitat(String(habitat_id))
	return _format_reward_bundle({
		"items": items,
		"systems": systems,
		"unlocks": unlocks,
	})

func _base_visit_reward(habitat_id: String) -> Dictionary:
	match habitat_id:
		"mist_moss_cave":
			return {"soft_moss": 1 + GameState.get_building_level(habitat_id, "moss_bed")}
		"crystal_creek":
			return {"stone_chip": 1 + GameState.get_building_level(habitat_id, "sun_drying_rack")}
		"sky_post":
			return {"tea_leaf": 1}
		"ancient_platform":
			return {"parts": 1 + GameState.get_building_level(habitat_id, "repair_bench")}
		"copper_hammer_bazaar":
			return {"fiber": 1, "parts": 1}
		"radiant_spire":
			return {"stability_shard": 1}
		"echo_broken_bridge":
			return {"parts": 1, "paper": 1}
		"radiant_observatory":
			return {"glow_dust": 1, "stability_shard": 1}
		"thunder_meadow":
			return {"spark_reed": 1}
		"autumn_leaf_dojo":
			return {"amber_resin": 1}
		"frost_mirror_lake":
			return {"ice_glass": 1}
		"greenbark_grove":
			return {"amber_resin": 1}
		"ember_crater":
			return {"warm_stone": 1}
		"reed_mire":
			return {"reed": 1}
		"saltglass_coast":
			return {"glass": 1}
		"moonfen_ruins":
			return {"glow_dust": 1}
		_:
			return {}

func _apply_visit_growth_resonance(bond_gains: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for pet_uid in bond_gains.keys():
		var result: Dictionary = GameState.add_pet_bond(String(pet_uid), int(bond_gains[pet_uid]))
		if result.is_empty() or not bool(result.get("changed", false)):
			continue
		lines.append("%s 的信赖提升到 %d。" % [
			GameState.get_pet_display_name(String(pet_uid)),
			int(result.get("new_level", 1)),
		])
	return lines

func _finish_season() -> void:
	var annual_competition_result := _resolve_annual_competition_if_needed()
	season_finished = true
	awaiting_destination = false
	GameState.clear_run_save(GameState.get_selected_run_slot_id())
	var run_summary := meta_progression_service.build_run_summary()
	var reward_result := meta_progression_service.award_run_points(run_summary)
	GameState.exploration_points_total = int(reward_result.get("total_after", GameState.exploration_points_total))
	for track in reward_result.get("new_tracks", []):
		GameState.register_meta_track(String(track.get("id", "")), track.get("unlock", {}))
	GameState.save_meta_progression()
	action_hint_label.text = "[b]这一年的收获[/b]\n照料进度 %d ｜ 已安居据点 %d ｜ 图鉴 %d ｜ 徽章 %d ｜ 季节点数 %d\n本局探索点 %d ｜ 累计探索点 %d" % [
		GameState.get_care_progress(),
		GameState.get_settled_habitat_count(),
		GameState.discovered_species.size(),
		GameState.badge_count,
		GameState.season_points,
		int(reward_result.get("points", 0)),
		GameState.exploration_points_total,
	]
	var annual_summary := _annual_competition_result_summary(annual_competition_result)
	if not annual_summary.is_empty():
		action_hint_label.text += "\n年赛：%s" % annual_summary
	_play_stage_transition(
		"这一年的日子先告一段落",
		"本局探索点 +%d\n累计探索点 %d" % [int(reward_result.get("points", 0)), GameState.exploration_points_total],
		Color(1.0, 0.84, 0.38, 1.0)
	)
	_push_log("这一年的日子先告一段落，获得探索点 %d。" % int(reward_result.get("points", 0)))
	for line in meta_progression_service.format_new_tracks(reward_result.get("new_tracks", [])):
		_push_log("元成长解锁：%s。" % line)
	_update_ui()
	if _should_show_boot_menu():
		_show_main_menu()

func _build_companion_summaries() -> Array:
	var result: Array = []
	for companion in GameState.get_companions():
		var species_id := String(companion.get("species_id", ""))
		var species := DataRepository.get_species(species_id)
		var home_id := String(companion.get("residence_habitat_id", ""))
		var entry: Dictionary = companion.duplicate(true)
		var star_level := int(entry.get("star_level", 1))
		var synergy_profile: Dictionary = GameData.get_species_synergy_profile(species_id)
		var evolution_chain: Array = synergy_profile.get("evolution_chain", [])
		entry["species_name"] = String(species.get("name", species_id))
		entry["residence_name"] = _habitat_name(home_id) if not home_id.is_empty() else "暂未安居"
		entry["slot_label"] = _companion_slot_label(String(companion.get("uid", "")))
		entry["duplicate_count"] = GameState.count_species_pets(species_id, star_level)
		entry["duplicate_need"] = 0 if star_level >= 3 else maxi(0, 3 - int(entry.get("duplicate_count", 1)))
		entry["evolution_name"] = String(evolution_chain[star_level - 1]) if evolution_chain.size() >= star_level else entry["species_name"]
		entry["next_evolution_name"] = String(evolution_chain[star_level]) if evolution_chain.size() > star_level else ""
		entry["population_cost"] = int(synergy_profile.get("population_cost", 1))
		entry["type_text"] = _format_type_tags(synergy_profile.get("elements", []))
		entry["role_text"] = _format_role_tags(synergy_profile.get("job_tags", []))
		result.append(entry)
	return result

func _format_type_tags(type_ids: Array) -> String:
	var parts: Array[String] = []
	for type_id in type_ids:
		parts.append(GameData.get_type_name(String(type_id)))
	return " / ".join(parts)

func _format_role_tags(role_ids: Array) -> String:
	var parts: Array[String] = []
	for role_id in role_ids:
		parts.append(String(GameData.JOB_NAMES.get(String(role_id), String(role_id))))
	return " / ".join(parts)

func _build_habitat_summaries() -> Array:
	var result: Array = []
	for habitat_id in DataRepository.habitats.keys():
		var habitat := DataRepository.get_habitat(habitat_id)
		if habitat.is_empty():
			continue
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_name := "暂无"
		var resident_uid := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		if not resident_uid.is_empty():
			resident_name = GameState.get_actor_display_name(resident_uid)
		result.append({
			"name": String(habitat.get("name", habitat_id)),
			"type_name": _type_name(String(habitat.get("type", ""))),
			"resident_name": resident_name,
			"building_text": _format_building_levels(habitat_id, DataRepository.get_buildings_for_habitat(habitat_id)),
			"quest_text": _quest_text_for_habitat(habitat_id),
			"status_text": _unlock_marker_text(habitat_id),
			"dojo_text": _dojo_status_text(String(habitat.get("dojo_id", ""))),
			"nursery_text": nursery_service.build_habitat_status_text(habitat_id),
		})
	return result

func _update_ui() -> void:
	_update_header()
	_update_action_ui()
	_apply_casual_exposure_policy()
	_update_summaries()
	_update_roster()
	_update_log()
	_update_map_hint()
	board_view.refresh_view(current_node_id, _get_selectable_nodes(), _build_board_markers(), _get_locked_nodes())
	board_view.set_controller_navigation_enabled(branch_choice_pending)
	if main_menu_panel.visible:
		_refresh_main_menu()

func _update_header() -> void:
	var objective_name := String(GameState.weekly_objective.get("title", "等待周目标"))
	var objective_progress := " / ".join(weekly_cycle_service.build_progress_lines(GameState.weekly_objective, GameState.weekly_progress))
	if objective_progress.is_empty():
		objective_progress = "本周尚未结算"
	meta_label.text = "%s · 第 %d 周 · %s" % [
		_season_name(),
		GameState.week_index,
		board_progression_service.get_region_name(),
	]
	round_label.text = "回合 %d / %d · 总计 %d / 100" % [
		GameState.season_turn,
		GameState.season_length,
		GameState.global_turn,
	]
	weather_label.text = "%s · %s · 饥饿 %d/%d" % [
		_weather_name(GameState.weather_id),
		_time_name(GameState.time_of_day),
		GameState.hunger,
		GameState.max_hunger,
	]
	objective_label.text = "%s ｜ %s" % [
		objective_name,
		objective_progress,
	]

func _update_action_ui() -> void:
	var current_node: Dictionary = board_lookup.get(current_node_id, {})
	var recent_roll: String = "待掷骰" if pending_roll.is_empty() else dice_service.describe_roll(pending_roll)
	var selectable_nodes: Array[int] = _get_selectable_nodes()
	var intro_copy := _is_casual_intro_phase()
	var route_preview := _format_route_choice_preview(selectable_nodes, intro_copy and branch_choice_pending)
	dice_label.text = "步数：%s" % recent_roll
	dice_meta_label.text = "修正 %d ｜ 重掷 %d/%d ｜ 锚定 %d" % [
		GameState.season_adjust_points,
		GameState.weekly_reroll_count,
		GameState.weekly_reroll_limit,
		GameState.anchor_points,
	]
	board_status_label.text = "区域：%s ｜ 当前位置：%s" % [
		board_progression_service.get_region_name(),
		String(current_node.get("name", "营地")),
	]
	if branch_choice_pending:
		board_route_label.text = "分叉 %d 选 ｜ %s" % [
			selectable_nodes.size(),
			route_preview if not route_preview.is_empty() else "等待方向列表",
		]
	elif awaiting_destination:
		board_route_label.text = "可达 %d 处 ｜ %s" % [
			selectable_nodes.size(),
			route_preview if not route_preview.is_empty() else "等待路线计算",
		]
	else:
		board_route_label.text = "先歇一会 ｜ 今日 %s · %s" % [_weather_name(GameState.weather_id), _time_name(GameState.time_of_day)]
	roll_button.text = "掷骰"
	support_button.text = "背包 / 小本"
	base_button.text = "落脚处"
	new_game_button.text = "回到开头"
	roll_button.disabled = season_finished or _is_modal_open() or awaiting_destination or branch_choice_pending
	plus_button.disabled = season_finished or pending_roll.is_empty() or not awaiting_destination or GameState.season_adjust_points <= 0 or int(pending_roll.get("value", 0)) >= 6
	minus_button.disabled = season_finished or pending_roll.is_empty() or not awaiting_destination or GameState.season_adjust_points <= 0 or int(pending_roll.get("value", 0)) <= 1
	reroll_button.disabled = season_finished or pending_roll.is_empty() or not awaiting_destination or GameState.weekly_reroll_count >= GameState.weekly_reroll_limit
	support_button.disabled = _is_modal_open() and not system_panel.visible
	base_button.disabled = _is_modal_open() and not base_panel.visible
	new_game_button.disabled = ai_turn_in_progress or battle_panel.visible or decision_panel.visible or base_panel.visible or system_panel.visible or (is_instance_valid(cutscene_panel) and cutscene_panel.visible)
	if season_finished:
		action_hint_label.text = "[b]这一年先告一段落[/b]\n回到上面看看这一年的收获，也能顺手开始下一段日子。"
		return
	if ai_turn_in_progress:
		action_hint_label.text = "[b]对手回合[/b]\n%s" % (_active_ai_observation_line if not _active_ai_observation_line.is_empty() else "正在结算其他远征队的掷骰、推进和落点。")
		return
	if branch_choice_pending:
		if intro_copy:
			action_hint_label.text = "[b]来到分叉口了[/b]\n先选一个你现在更想要的方向：%s。剩下的步数会继续自动走完。" % (route_preview if not route_preview.is_empty() else "稳着推进 / 补给打听 / 冒险深入")
		else:
			action_hint_label.text = "[b]来到分叉口了[/b]\n这一步先选方向，走完剩下的步数后才会真正落点。"
	elif awaiting_destination:
		if intro_copy:
			action_hint_label.text = "[b]先确认步数[/b]\n确认后会沿路前进，只有真遇到分叉才会停下来让你选。"
		else:
			action_hint_label.text = "[b]先看看这次会走多远[/b]\n确认后会开始逐步前进，不会直接选终点；只有遇到岔路，才需要你拿主意。"
	else:
		if intro_copy:
			action_hint_label.text = "[b]先出门，再看会停在哪儿[/b]\n先掷一次骰，今天先只看这一步；其他态势信息会随着进度慢慢展开。"
		else:
			action_hint_label.text = "[b]先出门，再看会停在哪儿[/b]\n先掷一次骰，看看今天会被带到哪里。只有遇到岔路，才需要你挑。"
	if GameState.is_hunger_low() and not season_finished and not ai_turn_in_progress:
		action_hint_label.text = "[b]肚子有点空了[/b]\n路过落脚处会顺手垫一点；更细的东西，翻背包 / 小本就行。"

func _update_summaries() -> void:
	var synergy_report := synergy_service.build_synergy_report()
	var facility_bonus := synergy_service.build_facility_bonus()
	var npc_lines := npc_route_service.build_status_lines(2)
	var threat_lines := threat_service.build_status_lines(board_lookup, 2)
	var treasury := GameState.get_treasury_snapshot()
	var ai_entries: Array = ai_player_service.build_summary_entries(board_lookup)
	player_summary_label.text = "\n".join([
		"成长阶段 Lv%d ｜ 照料 %d" % [GameState.get_progression_rank(), GameState.get_care_progress()],
		"徽章 %d ｜ 季节点 %d ｜ 探索点 %d" % [GameState.badge_count, GameState.season_points, GameState.exploration_points_total],
		"资金 %d 金 ｜ 银行 %d 金" % [int(treasury.get("wallet_gold", 0)), int(treasury.get("bank_gold", 0))],
		"饥饿 %d / %d ｜ 资源和补给翻背包页 / 小本" % [GameState.hunger, GameState.max_hunger],
	])
	GameState.set_trait_runtime_bonus(synergy_service.build_runtime_bonus(synergy_report))
	var season_goal := String(GameState.get_current_season_rule().get("season_goal", "维持推进感。"))
	var lead_entry: Dictionary = ai_entries[0] if not ai_entries.is_empty() else {}
	var rival_lines: Array[String] = [
		"区域：%s" % board_progression_service.get_region_name(),
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
	ai_summary_label.text = "\n".join(rival_lines)
	var active_synergies: Array[String] = synergy_service.format_active_lines(synergy_report, 2)
	var control_lines: Array[String] = [
		"双打：%s" % " / ".join(_battle_slot_names()),
		"宠物栏：%d / %d ｜ 伙伴总数 %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity, GameState.get_companions().size()],
		"访客：%s" % (" / ".join(npc_lines) if not npc_lines.is_empty() else "暂无重点访客"),
		"威胁：%s" % (" / ".join(threat_lines) if not threat_lines.is_empty() else "暂无游走威胁"),
	]
	if not active_synergies.is_empty():
		control_lines.append("已激活：%s" % " / ".join(active_synergies))
	elif not facility_bonus.get("lines", []).is_empty():
		control_lines.append("建筑增益：%s" % " / ".join(facility_bonus.get("lines", []).slice(0, 1)))
	control_summary_label.text = "\n".join(control_lines.slice(0, 5))
	_handle_synergy_activation_fx(synergy_report)

func _update_roster() -> void:
	var lines: Array[String] = []
	lines.append("出战位：%s" % " / ".join(_battle_slot_names()))
	lines.append("待命人口：%d / %d ｜ 已安居据点 %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity, GameState.get_settled_habitat_count()])
	lines.append("生存：饥饿 %d / %d ｜ 资源和补给翻背包页 / 小本" % [GameState.hunger, GameState.max_hunger])
	if not starter_companion_uid.is_empty():
		lines.append("起始伙伴：%s" % GameState.get_pet_display_name(starter_companion_uid))
	else:
		lines.append("调双打 / 背包 / 驻守：路过营地打开营地总览。")
	roster_label.text = "\n".join(lines)

func _update_log() -> void:
	var entries: Array[String] = GameState.journal_entries.duplicate()
	var visible_entries: Array[String] = entries.slice(maxi(0, entries.size() - CASUAL_INTRO_VISIBLE_LOG_ENTRIES), entries.size())
	if visible_entries.is_empty():
		_render_event_log_text("等待新的记录…")
		_event_log_snapshot = []
		return
	if _should_render_event_log_immediately(visible_entries):
		_render_event_log_text("\n".join(visible_entries))
		_event_log_snapshot = visible_entries
		return
	var history_entries := visible_entries.slice(0, visible_entries.size() - 1)
	var full_text := "\n".join(visible_entries)
	var history_text := "\n".join(history_entries)
	var visible_count := history_text.length()
	if not history_text.is_empty():
		visible_count += 1
	_stop_event_log_typewriter(false)
	event_log_label.text = full_text
	event_log_label.visible_characters = visible_count
	event_log_label.scroll_to_line(event_log_label.get_line_count())
	_event_log_snapshot = visible_entries
	var newest_entry := String(visible_entries[visible_entries.size() - 1])
	var duration := clampf(float(newest_entry.length()) * EVENT_LOG_TYPEWRITER_SPEED, EVENT_LOG_TYPEWRITER_MIN_DURATION, EVENT_LOG_TYPEWRITER_MAX_DURATION)
	_event_log_typewriter_tween = create_tween()
	_event_log_typewriter_tween.set_trans(Tween.TRANS_LINEAR)
	_event_log_typewriter_tween.set_ease(Tween.EASE_OUT)
	_event_log_typewriter_tween.tween_property(event_log_label, "visible_characters", full_text.length(), duration)
	_event_log_typewriter_tween.finished.connect(_on_event_log_typewriter_finished)

func _update_map_hint() -> void:
	var npc_markers := npc_route_service.build_node_markers()
	var threat_markers := threat_service.build_node_markers()
	var ai_markers := ai_player_service.build_node_markers()
	if branch_choice_pending:
		var lines: Array[String] = ["[b]当前分叉方向[/b]"]
		for node_id in pending_route_options.slice(0, 4):
			var node: Dictionary = board_lookup[node_id]
			lines.append("%s [%s]" % [
				String(node.get("name", "未知节点")),
				_type_name(String(node.get("type", ""))),
			])
			lines.append("  下一步：%s" % _format_path_preview([current_node_id, node_id]))
		map_hint_label.text = "\n".join(lines)
		return
	if awaiting_destination:
		var lines: Array[String] = ["[b]可达节点[/b]"]
		for node_id in _filter_blocked_selectable_nodes(_reachable_selectable_nodes()).slice(0, 4):
			var node: Dictionary = board_lookup[node_id]
			var tags: Array[String] = [String(node.get("reward_hint", "查看详情"))]
			if board_map_effect_service.has_pending_effect(node, node_id, GameState.board_region_id):
				tags.append("效果 %s" % board_map_effect_service.preview_title(node))
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
				_type_name(String(node.get("type", ""))),
			])
			lines.append("  %s" % " ｜ ".join(tags.slice(0, 3)))
			lines.append("  路径：%s" % _format_path_preview(reachable_paths.get(node_id, [])))
		if _get_blocked_reachable_nodes().size() > 0:
			lines.append("")
			lines.append("[b]阻塞[/b] %d 个候选点被敌对群占据" % _get_blocked_reachable_nodes().size())
		if _get_locked_nodes().size() > 0:
			lines.append("[b]未开放[/b] %d 个区域待解锁" % _get_locked_nodes().size())
		map_hint_label.text = "\n".join(lines)
		return
	map_hint_label.text = "[b]今日焦点[/b]\n%s\n\n[b]周目标[/b]\n%s\n\n[b]地图动向[/b]\n对手：%s\n访客：%s\n威胁：%s" % [
		_today_focus_text(),
		weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress),
		" / ".join(ai_player_service.build_status_lines(board_lookup, 2)),
		" / ".join(npc_route_service.build_status_lines(2)),
		" / ".join(threat_service.build_status_lines(board_lookup, 2)),
	]

func _build_board_markers() -> Dictionary:
	var markers := {}
	var npc_markers := npc_route_service.build_node_markers()
	var threat_markers := threat_service.build_node_markers()
	var ai_markers := ai_player_service.build_node_markers()
	var boss_node_id := _current_boss_node_id()
	for node in world_nodes:
		var node_id := int(node.get("id", -1))
		var habitat_id := String(node.get("habitat_id", ""))
		var type_id := String(node.get("type", ""))
		var is_threatened := threat_markers.has(node_id)
		if board_progression_service.is_node_locked(node_id) and (GameState.revealed_board_nodes.has(node_id) or _get_selectable_nodes().has(node_id)):
			var ring_locked_text := board_progression_service.get_node_lock_reason(node_id)
			if ai_markers.has(node_id):
				ring_locked_text += " · 对手 %s" % " / ".join(ai_markers[node_id])
			markers[node_id] = ring_locked_text
			continue
		if habitat_id.is_empty():
			var base_marker := ""
			match type_id:
				"camp":
					base_marker = "起点" if node_id == board_progression_service.get_start_node_id() else "营地"
				"environment":
					base_marker = "环境格"
				"empty":
					base_marker = "环境格"
				_:
					base_marker = _type_name(type_id)
			var base_parts: Array[String] = [base_marker]
			var gate_text := board_progression_service.get_active_gate_text(node_id)
			if not gate_text.is_empty():
				base_parts.append(gate_text)
			if ai_markers.has(node_id):
				base_parts.append("对手 %s" % " / ".join(ai_markers[node_id]))
			markers[node_id] = " · ".join(base_parts)
			continue
		if not GameState.revealed_board_nodes.has(node_id) and not _get_selectable_nodes().has(node_id) and not is_threatened and not ai_markers.has(node_id):
			markers[node_id] = "未显露"
			continue
		if not GameState.is_habitat_unlocked(habitat_id) and not is_threatened and type_id != "event":
			var locked_text := _unlock_marker_text(habitat_id)
			if ai_markers.has(node_id):
				locked_text += " · 对手 %s" % " / ".join(ai_markers[node_id])
			markers[node_id] = locked_text
			continue
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_actor_id := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		var resident_text := ""
		if not resident_actor_id.is_empty():
			resident_text = "看守：%s" % GameState.get_actor_display_name(resident_actor_id)
		var quest_text := _quest_text_for_habitat(habitat_id)
		var parts: Array[String] = []
		if boss_node_id == node_id:
			parts.append("赛季高潮")
		if type_id == "event":
			parts.append("事件格")
		if board_map_effect_service.has_pending_effect(node, node_id, GameState.board_region_id):
			parts.append("地图效果")
		var danger := GameState.get_node_danger(node_id)
		if danger > 0:
			parts.append("危险 %d" % danger)
		if npc_markers.has(node_id):
			parts.append("访客 %s" % " / ".join(npc_markers[node_id]))
		if threat_markers.has(node_id):
			parts.append("敌群 %s" % " / ".join(threat_markers[node_id]))
		if ai_markers.has(node_id):
			parts.append("对手 %s" % " / ".join(ai_markers[node_id]))
		if GameState.has_node_ambush(node_id):
			parts.append("伏击待命")
		if not resident_text.is_empty():
			parts.append(resident_text)
		if not quest_text.is_empty():
			parts.append(quest_text)
		var dojo_id := String(DataRepository.get_habitat(habitat_id).get("dojo_id", ""))
		if not dojo_id.is_empty():
			parts.append(_dojo_status_text(dojo_id))
		if parts.is_empty():
			parts.append("可回访")
		markers[node_id] = " · ".join(parts)
	return markers

func _get_selectable_nodes() -> Array[int]:
	var selectable: Array[int] = []
	if branch_choice_pending:
		return _filter_blocked_selectable_nodes(pending_route_options)
	if awaiting_destination:
		return _filter_blocked_selectable_nodes(_reachable_selectable_nodes())
	return selectable

func _get_locked_nodes() -> Array[int]:
	var locked: Array[int] = []
	for node in world_nodes:
		var node_id := int(node.get("id", -1))
		if board_progression_service.is_node_locked(node_id):
			locked.append(node_id)
			continue
		var type_id := String(node.get("type", ""))
		if type_id in ["camp", "empty", "environment", "event"]:
			continue
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if not GameState.is_habitat_unlocked(habitat_id):
			locked.append(node_id)
	return locked

func _today_focus_text() -> String:
	if not GameState.weekly_objective.is_empty():
		return "本周目标：%s" % String(GameState.weekly_objective.get("title", "本周目标"))
	if not GameState.active_quests.is_empty():
		return "优先推进：%s" % _quest_title(GameState.active_quests[0])
	if GameState.season_id == "summer" and GameState.is_habitat_unlocked("thunder_meadow") and not GameState.has_cleared_dojo("summer_storm_trial", "tier_1"):
		return "去鸣雷草场试试夏季一阶试炼，拿第一枚季节徽章。"
	if GameState.season_id == "autumn" and GameState.is_habitat_unlocked("autumn_leaf_dojo") and not GameState.has_cleared_dojo("autumn_leaf_dojo", "tier_1"):
		return "赤叶演武场已经开门，适合去试试现在这套搭配顺不顺手。"
	if GameState.season_id == "winter" and GameState.is_habitat_unlocked("frost_mirror_lake"):
		return "霜镜湖已开放，优先收集冬季限定素材与观察条目。"
	if GameState.get_settled_habitat_count() < 2:
		return "先替据点安排看守，让它们真正成为家。"
	if GameState.get_habitat_rank_total() < 3:
		return "该去古械平台补第一层建设了，先让据点真正运转起来。"
	if not GameState.is_habitat_unlocked("radiant_spire"):
		return "继续累积地点等级和 NPC 信赖，为异常区做准备。"
	return "季末可以考虑去裂辉尖塔做一次救助。"

func _format_path_preview(path: Array) -> String:
	if path.is_empty():
		return "未记录路线"
	var names: Array[String] = []
	for node_id in path:
		var node: Dictionary = board_lookup.get(int(node_id), {})
		names.append(String(node.get("name", node_id)))
	return " -> ".join(names)

func _location_status_lines() -> Array[String]:
	var lines: Array[String] = []
	for node in world_nodes:
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if not GameState.is_habitat_unlocked(habitat_id):
			lines.append("%s：%s" % [String(node.get("name", habitat_id)), _unlock_marker_text(habitat_id)])
			continue
		var habitat := DataRepository.get_habitat(habitat_id)
		var state: Dictionary = GameState.habitats.get(habitat_id, {})
		var resident_uid := String(state.get("resident_actor_id", state.get("resident_uid", "")))
		var resident_name := "暂无"
		if not resident_uid.is_empty():
			resident_name = GameState.get_actor_display_name(resident_uid)
		var summary := resident_name
		var dojo_id := String(habitat.get("dojo_id", ""))
		if not dojo_id.is_empty():
			summary = _dojo_status_text(dojo_id)
		var nursery_text := nursery_service.build_habitat_status_text(habitat_id)
		if not nursery_text.is_empty():
			summary += " ｜ %s" % nursery_text
		lines.append("%s：%s" % [String(habitat.get("name", habitat_id)), summary])
	return lines

func _quest_text_for_habitat(habitat_id: String) -> String:
	var count := 0
	for quest_id in GameState.active_quests:
		var quest := DataRepository.get_quest(quest_id)
		if String(quest.get("target_habitat", "")) == habitat_id:
			count += 1
	if count == 0:
		return ""
	return "委托 %d" % count

func _quest_title(quest_id: String) -> String:
	return String(DataRepository.get_quest(quest_id).get("title", quest_id))

func _quest_titles(quest_ids: Array) -> Array[String]:
	var titles: Array[String] = []
	for quest_id in quest_ids:
		titles.append(_quest_title(String(quest_id)))
	return titles

func _seasonal_hook_text(habitat: Dictionary) -> String:
	var hooks: Dictionary = habitat.get("seasonal_hooks", {})
	var candidates: Array[String] = []
	if hooks.has(GameState.season_id):
		candidates.append_array(hooks[GameState.season_id])
	if hooks.has(GameState.weather_id):
		candidates.append_array(hooks[GameState.weather_id])
	if hooks.has(GameState.time_of_day):
		candidates.append_array(hooks[GameState.time_of_day])
	return " / ".join(candidates) if not candidates.is_empty() else "今天适合慢一点地观察和照料。"

func _format_building_levels(habitat_id: String, buildings: Array) -> String:
	if buildings.is_empty():
		return "这个地点当前没有建设项目"
	var parts: Array[String] = []
	for building in buildings:
		var building_id := String(building.get("id", ""))
		var part := "%s Lv.%d" % [String(building.get("name", building_id)), GameState.get_building_level(habitat_id, building_id)]
		var status_parts: Array[String] = []
		var apartment_status := GameState.get_apartment_status(habitat_id, building_id)
		if not apartment_status.is_empty():
			status_parts.append("住客 %d/%d" % [
				int(apartment_status.get("tenant_count", 0)),
				int(apartment_status.get("tenant_capacity", 0)),
			])
		if GameState.is_building_damaged(habitat_id, building_id):
			status_parts.append("受损")
			var repair_cost: Dictionary = GameState.get_building_repair_cost(habitat_id, building_id)
			if not repair_cost.is_empty():
				status_parts.append("待修")
		if not status_parts.is_empty():
			part += "（%s）" % "，".join(status_parts)
		parts.append(part)
	return " / ".join(parts)

func _apartment_visit_line(habitat_id: String) -> String:
	var apartment_status := GameState.get_apartment_status(habitat_id)
	if apartment_status.is_empty():
		return ""
	var parts: Array[String] = []
	var tenant_names: Array = Array(apartment_status.get("tenant_names", [])).duplicate(true)
	if tenant_names.is_empty():
		parts.append("暂时空着")
	else:
		parts.append("住客：%s" % " / ".join(tenant_names))
	if int(apartment_status.get("damage_days", 0)) > 0:
		parts.append("房屋受损")
	var incident_note := String(apartment_status.get("incident_note", "")).strip_edges()
	if not incident_note.is_empty():
		parts.append(incident_note)
	var repair_cost: Dictionary = Dictionary(apartment_status.get("repair_cost", {})).duplicate(true)
	if not repair_cost.is_empty():
		parts.append("修缮需求：%s" % _format_item_cost(repair_cost))
	return " ｜ ".join(parts)

func _format_item_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var keys: Array[String] = []
	for item_id in cost.keys():
		keys.append(String(item_id))
	keys.sort()
	var parts: Array[String] = []
	for item_id in keys:
		parts.append("%s x%d" % [_item_name(item_id), int(cost[item_id])])
	return " / ".join(parts)

func _build_choice_summary(check: Dictionary) -> String:
	var current_level := int(check.get("current_level", 0))
	var max_level := int(check.get("max_level", current_level))
	var parts: Array[String] = ["Lv.%d/%d" % [current_level, max_level]]
	if bool(check.get("ok", false)):
		var cost_text := _format_item_cost(check.get("cost", {}))
		if not cost_text.is_empty():
			parts.append("消耗 %s" % cost_text)
		var progression_rank_before := int(check.get("progression_rank_before", GameState.get_progression_rank()))
		var progression_rank_after := int(check.get("progression_rank_after", progression_rank_before))
		if progression_rank_after > progression_rank_before:
			parts.append("成长 Lv%d→%d" % [progression_rank_before, progression_rank_after])
		var effects: Array = check.get("effects", [])
		if not effects.is_empty():
			parts.append("下一阶 %s" % String(effects[0]))
	else:
		var reason := String(check.get("reason", "unknown"))
		if reason == "insufficient_items":
			var missing_text := _format_item_cost(check.get("missing_cost", {}))
			if not missing_text.is_empty():
				parts.append("还差 %s" % missing_text)
			else:
				parts.append(_build_fail_reason(reason))
		else:
			parts.append(_build_fail_reason(reason))
	return " ｜ ".join(parts)

func _build_choice_tooltip(check: Dictionary) -> String:
	var lines: Array[String] = []
	var current_effects: Array = check.get("current_effects", [])
	if current_effects.is_empty():
		lines.append("当前效果：尚未建成。")
	else:
		lines.append("当前效果：%s" % " / ".join(_stringify_array(current_effects)))
	if bool(check.get("ok", false)):
		lines.append("下一阶效果：%s" % " / ".join(_stringify_array(check.get("effects", []))))
		var interactions: Array = check.get("interactions", [])
		if not interactions.is_empty():
			var labels: Array[String] = []
			for interaction in interactions:
				labels.append(String(interaction.get("label", interaction.get("id", "新互动"))))
			lines.append("新增互动：%s" % " / ".join(labels))
		lines.append("据点等级：%d → %d" % [
			int(check.get("habitat_rank_before", 0)),
			int(check.get("habitat_rank_after", 0)),
		])
		var progression_rank_before := int(check.get("progression_rank_before", GameState.get_progression_rank()))
		var progression_rank_after := int(check.get("progression_rank_after", progression_rank_before))
		if progression_rank_after != progression_rank_before:
			lines.append("成长阶段：%d → %d" % [progression_rank_before, progression_rank_after])
			lines.append("宠物栏容量：%d → %d" % [
				int(check.get("capacity_before", 0)),
				int(check.get("capacity_after", 0)),
			])
			if not String(check.get("progression_summary_after", "")).is_empty():
				lines.append("本阶焦点：%s" % String(check.get("progression_summary_after", "")))
	else:
		lines.append("当前状态：%s" % _build_fail_reason(String(check.get("reason", "unknown"))))
	return "\n".join(lines)

func _stringify_array(values: Array) -> Array[String]:
	var lines: Array[String] = []
	for value in values:
		lines.append(String(value))
	return lines

func _format_shop_service_summary(service: Dictionary) -> String:
	var parts: Array[String] = []
	var description := String(service.get("description", ""))
	if not description.is_empty():
		parts.append(description)
	var cost_chunks: Array[String] = []
	var cost_gold := int(service.get("cost_gold", 0))
	if cost_gold > 0:
		cost_chunks.append("%d 金" % cost_gold)
	var cost_items: Dictionary = service.get("cost_items", {})
	if not cost_items.is_empty():
		cost_chunks.append(_format_item_cost(cost_items))
	if not cost_chunks.is_empty():
		parts.append("消耗：%s" % " / ".join(cost_chunks))
	var reward_items: Dictionary = service.get("reward_items", {})
	if not reward_items.is_empty():
		parts.append("产出：%s" % _format_item_cost(reward_items))
	var tags: Array = service.get("tags", [])
	if not tags.is_empty():
		parts.append("标签：%s" % " / ".join(tags))
	parts.append("本周剩余：%d 次" % int(service.get("remaining_uses", 0)))
	var required_trust := int(service.get("required_trust", 0))
	if required_trust > 0:
		parts.append("信赖要求：%d（当前 %d）" % [required_trust, int(service.get("trust_now", 0))])
	var disabled_reason := String(service.get("disabled_reason", ""))
	if not disabled_reason.is_empty():
		parts.append(_shop_service_disabled_text(disabled_reason))
	return " ｜ ".join(parts)

func _shop_offer_price_text(offer: Dictionary) -> String:
	var price := int(offer.get("price", 0))
	if not bool(offer.get("is_discounted", false)):
		return "%d 金" % price
	return "%d 金（原价 %d 金，-%d%%）" % [
		price,
		int(offer.get("base_price", price)),
		int(offer.get("discount_percent", 0)),
	]

func _shop_service_disabled_text(reason: String) -> String:
	match reason:
		"service_used_up":
			return "本周已办过"
		"trust_locked":
			return "关系还不够熟"
		"insufficient_gold":
			return "金币不足"
		"missing_items":
			return "材料不足"
		"no_intel":
			return "今天没有新风声"
		_:
			return "暂时不可用"

func _npc_names(npcs: Array) -> Array[String]:
	var names: Array[String] = []
	for npc in npcs:
		names.append(String(npc.get("name", "")))
	return names

func _battle_slot_names() -> Array[String]:
	var names: Array[String] = []
	for pet_uid in GameState.get_party_uids():
		names.append(GameState.get_pet_display_name(pet_uid))
	if names.is_empty():
		names.append("还没安排")
	return names

func _battle_slot_name_at(slot_index: int) -> String:
	var battle_uids := GameState.get_party_uids()
	if slot_index < 0 or slot_index >= battle_uids.size():
		return "还没安排"
	return GameState.get_pet_display_name(String(battle_uids[slot_index]))

func _companion_slot_label(pet_uid: String) -> String:
	if GameState.get_party_uids().has(pet_uid):
		return "上阵"
	if GameState.get_reserve_uids().has(pet_uid):
		return "休息中"
	for habitat_state in GameState.habitats.values():
		if String(habitat_state.get("resident_uid", "")) == pet_uid or String(habitat_state.get("assistant_uid", "")) == pet_uid:
			return "看守"
	return "休息中"

func _action_name(action_id: String) -> String:
	match action_id:
		"feed": return "投喂"
		"calm": return "安抚"
		"observe": return "观察"
		"guide": return "引导"
		"retreat": return "后退"
		"hum": return "轻声哼唱"
		"shelter": return "提供遮蔽"
		"brush": return "梳理茸毛"
		"soak": return "浅水浸润"
		"pat": return "轻拍安定"
		"play": return "陪它活动"
		"track": return "顺着痕迹观察"
		_: return action_id

func _encounter_outcome_text(outcome: String) -> String:
	match outcome:
		"bond_success": return "愿意靠近"
		"bond_progress": return "情绪平复"
		"safe_leave": return "平静结束"
		"alert_rise": return "仍然戒备"
		_: return outcome

func _build_fail_reason(reason: String) -> String:
	match reason:
		"resident_required": return "这里还没有人看守，先安排一个更合适的看守者。"
		"insufficient_items": return "手头东西还差一点，改天再来会更稳。"
		"max_level": return "这里已经收拾到眼下能做到的头了。"
		"site_mismatch": return "这事不该在这儿做，换个地方更合适。"
		"building_missing": return "这一步还没想好怎么搭，先放一放。"
		"pet_missing": return "这位伙伴这会儿不在身边。"
		"tier_locked": return "前面的路还得先走顺，再来试这一步。"
		"entry_cost_missing": return "还差点进门要用的东西，先去别处转转。"
		"payment_failed": return "刚才没扣成，再试一次看看。"
		"battle_slots_missing": return "现在身边还没站稳两位同行，进去会太吃力。"
		"battle_config_missing": return "这里今天还闹不起来，先去别处看看。"
		"dojo_missing": return "这里暂时还没准备好让你试手。"
		"tier_missing": return "这一步今天还轮不到。"
		"nursery_locked": return "幼护角还没收拾好，先把这里安顿成能孵育的样子。"
		"nursery_missing": return "这里眼下还没有能展开孵育的设施。"
		"incubation_active": return "这里已经有一个在孵的项目了。"
		"species_not_recorded": return "先把目标个体记录下来，再来建立孵育项目。"
		"species_missing": return "这条样本记录今天没法继续用了。"
		"no_incubation": return "这里现在还没有正在孵育的项目。"
		"care_already_done": return "这回合已经照看过一次了，先让它静一静。"
		"building_damaged": return "这栋楼刚被人折腾坏，先缓两天再用会更稳。"
		"invalid_care_action": return "这一步不太对路，换个更合适的照料方式。"
		"incubation_not_ready": return "还没到能破壳的时候，再照看几轮。"
		"incubation_ready": return "它已经准备破壳，不用再重复照料。"
		_: return "这一步今天还做不了。"

func _format_inventory_highlights() -> String:
	var rows := _collect_inventory_rows(INVENTORY_RESOURCE_TYPES)
	if rows.is_empty():
		return ""
	var parts: Array[String] = []
	for row in rows.slice(0, 4):
		parts.append(String(row).trim_prefix("- "))
	return " / ".join(parts)

func _collect_inventory_rows(types: Array[String]) -> Array[String]:
	var rows: Array[String] = []
	for item_data in DataRepository.get_items_by_types(types):
		var item_id := String(item_data.get("id", ""))
		if item_id.is_empty():
			continue
		var amount := GameState.get_item_count(item_id)
		if amount <= 0:
			continue
		rows.append("- %s x%d" % [String(item_data.get("name", item_id)), amount])
	return rows

func _build_backpack_section_lines() -> Array[String]:
	var lines: Array[String] = [
		"[b]饥饿[/b] %d / %d ｜ %s" % [GameState.hunger, GameState.max_hunger, _hunger_status_text()],
		"移动 -%d ｜ 周结算 -%d ｜ 路过营地 +%d" % [GameState.hunger_cost_per_travel, GameState.hunger_cost_per_week, GameState.camp_hunger_restore],
		"",
		"[b]资源材料[/b]",
	]
	var resource_rows := _collect_inventory_rows(INVENTORY_RESOURCE_TYPES)
	if resource_rows.is_empty():
		lines.append("- 暂无资源")
	else:
		lines.append_array(resource_rows)
	lines.append("")
	lines.append("[b]消耗 / 工具 / 纪念[/b]")
	var supply_rows := _collect_inventory_rows(INVENTORY_SUPPLY_TYPES)
	if supply_rows.is_empty():
		lines.append("- 暂无补给")
	else:
		lines.append_array(supply_rows)
	lines.append("")
	lines.append("[b]钱包[/b] %d 金 ｜ [b]银行[/b] %d 金" % [GameState.wallet_gold, GameState.bank_gold])
	lines.append("[b]地点状态[/b]")
	lines.append_array(_location_status_lines())
	var fishing_records: Dictionary = Dictionary(GameState.quest_memory.get("fishing_records", {})).duplicate(true)
	var released_aquatics: Dictionary = Dictionary(GameState.quest_memory.get("released_aquatic_species", {})).duplicate(true)
	if not fishing_records.is_empty() or not released_aquatics.is_empty():
		var released_total := GameState.get_total_aquatic_release_count()
		var catches_total := GameState.get_total_fishing_catch_count()
		lines.append("")
		lines.append("[b]垂钓记录[/b] 已记录 %d 种水域生物 ｜ 累计起鱼 %d ｜ 放流 %d 次" % [fishing_records.size(), catches_total, released_total])
		lines.append("[b]钓手声望[/b] %d" % GameState.get_fishing_reputation())
		for festival_id in GameState.get_all_festival_scores().keys():
			lines.append("- %s：%d 分" % [festival_id, GameState.get_festival_score(String(festival_id))])
	var nursery_lines := nursery_service.build_overview_lines()
	if not nursery_lines.is_empty():
		lines.append("")
		lines.append("[b]孵育记录[/b]")
		for line in nursery_lines:
			lines.append("- %s" % line)
	lines.append("")
	lines.append("[b]生物图鉴[/b] 已识别 %d / %d ｜ 已补完 %d / %d" % [
		_count_unlocked_codex_entries(),
		DataRepository.codex_entries.size(),
		_count_fully_unlocked_codex_entries(),
		DataRepository.codex_entries.size(),
	])
	lines.append("图鉴入口已经收进背包 / 小本；想看同行和编成，就去宠物栏那一页。切到 [b]生物图鉴[/b] 就能翻。")
	lines.append("")
	lines.append("平时缺什么、手上还剩多少，都来这一页翻一眼就行。")
	return lines

func _count_unlocked_codex_entries() -> int:
	var count := 0
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if GameState.is_codex_entry_unlocked(entry):
			count += 1
	return count

func _count_fully_unlocked_codex_entries() -> int:
	var count := 0
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if GameState.is_codex_entry_fully_unlocked(entry):
			count += 1
	return count

func _is_codex_entry_unlocked(entry: Dictionary) -> bool:
	return GameState.is_codex_entry_unlocked(entry)

func _is_codex_unlock_rule_met(rule: Dictionary) -> bool:
	return GameState.is_codex_unlock_rule_met(rule)

func _codex_rarity_label(rarity: String) -> String:
	return String(CODEX_RARITY_LABELS.get(rarity, rarity))

func _codex_rarity_color(rarity: String) -> String:
	return String(CODEX_RARITY_COLORS.get(rarity, "#d4d4d8"))

func _codex_entry_icon(entry: Dictionary, reveal_level: int) -> String:
	if reveal_level <= GameState.CODEX_REVEAL_LOCKED:
		return "[color=#111111]●[/color]"
	if reveal_level == GameState.CODEX_REVEAL_BASIC:
		return "[color=#6b7280]●[/color]"
	return "[color=%s]●[/color]" % _codex_rarity_color(String(entry.get("rarity", "common")))

func _species_display_name(species_id: String) -> String:
	var species: Dictionary = DataRepository.get_species(species_id)
	if species.is_empty():
		var aquatic_species: Dictionary = DataRepository.get_aquatic_species(species_id)
		if aquatic_species.is_empty():
			return species_id
		return String(aquatic_species.get("name", species_id))
	return String(species.get("name", species_id))

func _codex_unlock_hint(rule: Dictionary) -> String:
	match String(rule.get("type", "")):
		"observe_species":
			return "观察对应生物后解锁"
		"encounter_species":
			return "遭遇对应生物后解锁"
		"bond_species":
			return "与对应生物结缘后解锁"
		"calm_species":
			return "安抚对应生物后解锁"
		"observe_marker":
			return "完成对应钓鱼记录或生态节点后解锁"
		_:
			return "推进相关内容后解锁"

func _append_codex_note_lines(lines: Array[String], label: String, values: Array) -> void:
	if values.is_empty():
		return
	var chunks: Array[String] = []
	for value in values:
		var text := String(value).strip_edges()
		if text.is_empty():
			continue
		chunks.append(text)
	if chunks.is_empty():
		return
	lines.append("%s：%s" % [label, " / ".join(chunks)])

func _build_codex_section_lines() -> Array[String]:
	var lines: Array[String] = []
	var total := DataRepository.codex_entries.size()
	var unlocked := _count_unlocked_codex_entries()
	var completed := _count_fully_unlocked_codex_entries()

	lines.append("[b]图鉴进度[/b] 识别 %d / %d ｜ 补完 %d / %d" % [unlocked, total, completed, total])
	lines.append("战斗记录、观察和生态事件会先识别条目；图鉴手册会补完详细资料。")

	if total <= 0:
		lines.append("")
		lines.append("当前没有可用的图鉴数据。")
		return lines

	var entries: Array[Dictionary] = []
	for raw_entry in DataRepository.codex_entries.values():
		entries.append(Dictionary(raw_entry).duplicate(true))

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var reveal_a := GameState.get_codex_entry_reveal_level(a)
		var reveal_b := GameState.get_codex_entry_reveal_level(b)
		if reveal_a != reveal_b:
			return reveal_a > reveal_b
		return String(a.get("title", a.get("id", ""))) < String(b.get("title", b.get("id", "")))
	)

	for index in range(entries.size()):
		var entry := entries[index]
		var rarity_label := _codex_rarity_label(String(entry.get("rarity", "common")))
		var reveal_level := GameState.get_codex_entry_reveal_level(entry)
		var is_unlocked := reveal_level >= GameState.CODEX_REVEAL_BASIC
		var fully_unlocked := reveal_level >= GameState.CODEX_REVEAL_FULL
		var icon := _codex_entry_icon(entry, reveal_level)
		lines.append("")

		if not is_unlocked:
			lines.append("%s [b]%02d. ???[/b] ｜ ???" % [icon, index + 1])
			lines.append("资料未录入。可通过战斗、观察或图鉴手册补全。")
			continue

		var species_id := String(entry.get("species_id", ""))
		var species_name := _species_display_name(species_id)
		lines.append("%s [b]%02d. %s[/b] ｜ %s ｜ %s" % [
			icon,
			index + 1,
			String(entry.get("title", "未命名条目")),
			species_name,
			rarity_label,
		])

		var portrait_hint := String(entry.get("portrait_hint", "")).strip_edges()
		if not portrait_hint.is_empty():
			lines.append("外观：%s" % portrait_hint)

		if not fully_unlocked:
			lines.append("详细资料未补完。可用图鉴手册补全。")
			continue

		_append_codex_note_lines(lines, "栖地", Array(entry.get("habitat_notes", [])))
		_append_codex_note_lines(lines, "行为", Array(entry.get("behavior_notes", [])))
		_append_codex_note_lines(lines, "照料", Array(entry.get("care_notes", [])))

		var tags: Array = entry.get("research_tags", [])
		if not tags.is_empty():
			var tag_lines: Array[String] = []
			for tag in tags:
				tag_lines.append(String(tag))
			lines.append("标签：%s" % " / ".join(tag_lines))

	return lines

func _hunger_status_text() -> String:
	if GameState.hunger <= 0:
		return "见底"
	if GameState.is_hunger_low():
		return "偏低"
	if GameState.hunger >= int(round(float(GameState.max_hunger) * 0.75)):
		return "充足"
	return "平稳"

func _item_name(item_id: String) -> String:
	return String(DataRepository.items.get(item_id, {}).get("name", item_id))

func _weather_name(weather_id: String) -> String:
	return String(WEATHER_NAMES.get(weather_id, weather_id))

func _time_name(time_id: String) -> String:
	return String(TIME_NAMES.get(time_id, time_id))

func _type_name(type_id: String) -> String:
	match type_id:
		"camp": return "营地"
		"bulletin": return "公告板"
		"minigame": return "小游戏格"
		"infirmary": return "疗养所"
		"empty": return "环境格"
		"environment": return "环境格"
		"event": return "事件格"
		"habitat": return "栖居据点"
		"settlement": return "聚落节点"
		"shop": return "商店节点"
		"dojo": return "试炼场"
		"anomaly": return "异常区域"
		_: return type_id

func _habitat_name(habitat_id: String) -> String:
	if habitat_id.is_empty():
		return "营地"
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

func _push_log(text: String) -> void:
	GameState.add_journal_entry(text)
	if is_node_ready():
		_update_log()

func _should_render_event_log_immediately(entries: Array[String]) -> bool:
	if GameState.should_skip_animations():
		return true
	if _event_log_snapshot.is_empty():
		return true
	if entries.size() <= _event_log_snapshot.size():
		return true
	if entries.size() - _event_log_snapshot.size() > 1:
		return true
	for index in range(_event_log_snapshot.size()):
		if entries[index] != _event_log_snapshot[index]:
			return true
	return false

func _render_event_log_text(text: String) -> void:
	_stop_event_log_typewriter(false)
	event_log_label.text = text
	event_log_label.visible_characters = -1
	event_log_label.scroll_to_line(event_log_label.get_line_count())

func _stop_event_log_typewriter(reveal_all: bool = true) -> void:
	if _event_log_typewriter_tween != null:
		_event_log_typewriter_tween.kill()
		_event_log_typewriter_tween = null
	if reveal_all and is_instance_valid(event_log_label):
		event_log_label.visible_characters = -1

func _on_event_log_typewriter_finished() -> void:
	_event_log_typewriter_tween = null
	event_log_label.visible_characters = -1
	event_log_label.scroll_to_line(event_log_label.get_line_count())

func _season_name() -> String:
	return String(GameState.get_current_season_rule().get("name", GameState.season_id))

func _current_boss_node_id() -> int:
	return board_progression_service.get_boss_node_id()

func _active_dojo_names() -> Array[String]:
	var names: Array[String] = []
	for dojo_id in GameState.get_current_dojo_rotation():
		var dojo := DataRepository.get_dojo(String(dojo_id))
		if dojo.is_empty():
			continue
		names.append(String(dojo.get("name", dojo_id)))
	if names.is_empty():
		names.append("暂无")
	return names

func _dojo_status_text(dojo_id: String) -> String:
	if dojo_id.is_empty():
		return ""
	var dojo := DataRepository.get_dojo(dojo_id)
	if dojo.is_empty():
		return "试炼暂时还没准备好"
	for tier in ["tier_3", "tier_2", "tier_1"]:
		if GameState.has_cleared_dojo(dojo_id, tier):
			return "%s已通过" % _dojo_tier_name(tier)
	return "可试炼"

func _unlock_marker_text(habitat_id: String) -> String:
	var status := GameState.get_habitat_unlock_status(habitat_id)
	if bool(status.get("open", false)):
		return "可回访"
	var reasons: Array = status.get("reasons", [])
	if reasons.is_empty():
		return "尚未开放"
	return String(reasons[0])

func _dojo_tier_name(tier: String) -> String:
	match tier:
		"tier_1":
			return "试炼一阶"
		"tier_2":
			return "试炼二阶"
		"tier_3":
			return "试炼三阶"
		_:
			return tier

func _format_traversal_skill_names(skill_ids: Array) -> String:
	var labels: Array[String] = []
	for raw_skill_id in skill_ids:
		var skill_id := String(raw_skill_id)
		if skill_id.is_empty():
			continue
		var label := GameState.get_traversal_skill_name(skill_id)
		if not labels.has(label):
			labels.append(label)
	if labels.is_empty():
		return "尚未掌握"
	return " / ".join(labels)

func _format_reward_bundle(reward_result: Dictionary) -> String:
	var parts: Array[String] = []
	var items := _format_item_cost(reward_result.get("items", {}))
	if not items.is_empty():
		parts.append(items)
	var systems: Dictionary = reward_result.get("systems", {})
	if int(systems.get("badge_count", 0)) > 0:
		parts.append("徽章 +%d" % int(systems.get("badge_count", 0)))
	if int(systems.get("season_points", 0)) > 0:
		parts.append("季节点数 +%d" % int(systems.get("season_points", 0)))
	if int(systems.get("season_adjust_points", 0)) > 0:
		parts.append("修正点 +%d" % int(systems.get("season_adjust_points", 0)))
	if int(systems.get("weekly_reroll_limit", 0)) > 0:
		parts.append("周重掷 +%d" % int(systems.get("weekly_reroll_limit", 0)))
	if int(systems.get("anchor_points", 0)) > 0:
		parts.append("锚定点 +%d" % int(systems.get("anchor_points", 0)))
	if int(systems.get("exploration_points", 0)) > 0:
		parts.append("探索点 +%d" % int(systems.get("exploration_points", 0)))
	var unlocks: Array = reward_result.get("unlocks", [])
	for habitat_id in unlocks:
		parts.append("开放 %s" % _habitat_name(String(habitat_id)))
	return " / ".join(parts)

func _build_main_menu_run_summary() -> String:
	var lines: Array[String] = ["[b]这阵子的日子[/b]"]
	if season_finished:
		lines.append("这一年的账已经算完了，歇口气后就能开始下一段日子。")
	else:
		lines.append("%s · 第 %d / %d 回合 · 第 %d 周 · 总回合 %d / 100" % [
			_season_name(),
			GameState.season_turn,
			GameState.season_length,
			GameState.week_index,
			GameState.global_turn,
		])
	lines.append("周目标：%s" % weekly_cycle_service.build_summary(GameState.weekly_objective, GameState.weekly_progress))
	lines.append("出战位：%s" % " / ".join(_battle_slot_names()))
	lines.append("待命人口：%d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity])
	lines.append("通行技：%s" % _format_traversal_skill_names(GameState.get_traversal_skill_ids()))
	lines.append("饥饿：%d / %d" % [GameState.hunger, GameState.max_hunger])
	lines.append("徽章：%d ｜ 季节点数：%d ｜ 照料进度：%d" % [
		GameState.badge_count,
		GameState.season_points,
		GameState.get_care_progress(),
	])
	lines.append("资源与补给：打开背包页 / 手册查看")
	var annual_competition_text := _annual_competition_status_text()
	if not annual_competition_text.is_empty():
		lines.append("年赛：%s" % annual_competition_text)
	if not GameState.run_modifiers.is_empty():
		lines.append("")
		lines.append("[b]本局词缀[/b]")
		for line in run_modifier_service.format_lines(GameState.run_modifiers):
			lines.append("- %s" % line)
	return "\n".join(lines)

func _build_main_menu_meta_summary() -> String:
	var lines: Array[String] = [
		"[b]旅途积累[/b]",
		"累计探索点：%d" % GameState.exploration_points_total,
	]
	var modules: Array[String] = []
	for module_id in GameState.meta_unlocks.get("dice_modules", []):
		var module := DataRepository.get_dice_module(String(module_id))
		modules.append(String(module.get("name", module_id)))
	lines.append("已收集的骰子花样：%s" % (" / ".join(modules) if not modules.is_empty() else "暂无"))
	lines.append("")
	lines.append("[b]成长轨道[/b]")
	for track in DataRepository.get_meta_progression_tracks():
		var track_id := String(track.get("id", ""))
		var label := String(track.get("label", track_id))
		var description := String(track.get("description", ""))
		var threshold := int(track.get("threshold", 0))
		if GameState.has_meta_track(track_id):
			lines.append("已解锁｜%s" % label)
			lines.append(description)
			continue
		lines.append("待解锁｜%s ｜ 还差 %d 点" % [label, maxi(0, threshold - GameState.exploration_points_total)])
		lines.append(description)
	return "\n".join(lines)

func _build_system_sections() -> Array:
	var synergy_report := synergy_service.build_synergy_report()
	var facility_bonus := synergy_service.build_facility_bonus()
	var battle_bonus := synergy_service.merge_battle_bonus([
		synergy_service.build_battle_bonus(synergy_report),
		facility_bonus.get("bonus", {}),
	])
	var quest_lines: Array[String] = []
	if not GameState.weekly_objective.is_empty():
		quest_lines.append("[b]本周目标[/b] %s" % String(GameState.weekly_objective.get("title", "本周目标")))
		quest_lines.append(String(GameState.weekly_objective.get("description", "")))
		for line in weekly_cycle_service.build_progress_lines(GameState.weekly_objective, GameState.weekly_progress):
			quest_lines.append("- %s" % line)
	if GameState.active_quests.is_empty():
		quest_lines.append("")
		quest_lines.append("今天没有挂在手边的生活委托。")
	else:
		quest_lines.append("")
		quest_lines.append("[b]当前委托[/b]")
		for quest_id in GameState.active_quests:
			quest_lines.append("- %s" % _quest_title(quest_id))
	if not GameState.run_modifiers.is_empty():
		quest_lines.append("")
		quest_lines.append("[b]本局词缀[/b]")
		for line in run_modifier_service.format_lines(GameState.run_modifiers):
			quest_lines.append("- %s" % line)

	var annual_competition_text := _annual_competition_status_text()
	if not annual_competition_text.is_empty():
		quest_lines.append("")
		quest_lines.append("[b]年赛[/b] %s" % annual_competition_text)

	var battle_lines: Array[String] = [
		"[b]出战位[/b] %s" % " / ".join(_battle_slot_names()),
		"[b]宠物栏容量[/b] %d / %d" % [GameState.get_reserve_population_used(), GameState.pet_capacity],
		"[b]通行技[/b] %s" % _format_traversal_skill_names(GameState.get_traversal_skill_ids()),
		"[b]已激活羁绊[/b] %s" % " / ".join(synergy_service.format_active_lines(synergy_report, 4)),
	]
	if not synergy_service.format_nearby_lines(synergy_report, 3).is_empty():
		battle_lines.append("[b]差 1 激活[/b] %s" % " / ".join(synergy_service.format_nearby_lines(synergy_report, 3)))
	var trait_lines := synergy_service.format_trait_effect_lines(synergy_report, 4)
	if not trait_lines.is_empty():
		battle_lines.append("[b]特性梯度[/b] %s" % " / ".join(trait_lines))
	if not facility_bonus.get("lines", []).is_empty():
		battle_lines.append("[b]建筑前置增益[/b] %s" % " / ".join(facility_bonus.get("lines", [])))
	if not synergy_service.describe_battle_bonus(battle_bonus).is_empty():
		battle_lines.append("[b]战斗汇总[/b] %s" % " / ".join(synergy_service.describe_battle_bonus(battle_bonus)))

	var backpack_lines := _build_backpack_section_lines()
	var codex_lines := _build_codex_section_lines()

	var completed_count := 0
	for tutorial_id in TUTORIAL_ORDER:
		if GameState.has_completed_tutorial(tutorial_id):
			completed_count += 1
	var tutorial_lines: Array[String] = [
		"[b]已读教程[/b] %d / %d" % [completed_count, TUTORIAL_ORDER.size()],
	]
	for tutorial_id in TUTORIAL_ORDER:
		var entry := _tutorial_entry(tutorial_id)
		var status := "已读" if GameState.has_completed_tutorial(tutorial_id) else "未读"
		tutorial_lines.append("[b]%s[/b] %s" % [status, String(entry.get("title", tutorial_id))])
		tutorial_lines.append(String(entry.get("body", "")))
		tutorial_lines.append("")
	tutorial_lines.append("如果刚开新局，起始伙伴选择会在进入远征时自动触发。")

	return [
		{
			"id": "quest",
			"label": "手边的事",
			"summary": "[b]手边惦记的事[/b]\n今天想顾上的、答应过的，还有这一阵子的变化，都记在这里。",
			"body": "\n".join(quest_lines),
		},
		{
			"id": "battle",
			"label": "同行",
			"summary": "[b]现在和谁一起[/b]\n谁在身边、谁在待命、彼此合不合拍，都在这里看。",
			"body": "\n".join(battle_lines),
		},
		{
			"id": "backpack",
			"label": "背包",
			"summary": "[b]背包与日常[/b]\n饥饿、物资、钱，还有图鉴入口，都收在这里。",
			"body": "\n".join(backpack_lines),
		},
		{
			"id": "codex",
			"label": "生物图鉴",
			"summary": "[b]看过的那些生灵[/b]\n一路记下来的观察，都慢慢收在这里。",
			"body": "\n".join(codex_lines),
		},
		{
			"id": "tutorial",
			"label": "刚来时的提醒",
			"summary": "[b]刚来时的提醒[/b]\n第一次遇到的说明都留在这里，想翻随时翻。",
			"body": "\n".join(tutorial_lines),
		},
	]

func _handle_synergy_activation_fx(report: Dictionary) -> void:
	var snapshot := _active_synergy_keys(report)
	if not _synergy_fx_ready:
		_active_synergy_snapshot = snapshot
		_synergy_fx_ready = true
		return
	var added: Array[String] = []
	for key in snapshot:
		if not _active_synergy_snapshot.has(key):
			added.append(key)
	_active_synergy_snapshot = snapshot
	if added.is_empty() or GameState.should_skip_animations():
		return
	var lines: Array[String] = []
	for entry in report.get("active", []):
		var key := "%s:%s:%d" % [
			String(entry.get("category", "")),
			String(entry.get("id", "")),
			int(entry.get("tier", 0)),
		]
		if not added.has(key):
			continue
		lines.append("%s %d层" % [String(entry.get("name", "")), int(entry.get("tier", 0))])
		if lines.size() >= 2:
			break
	if lines.is_empty():
		return
	_show_synergy_banner(lines)
	_show_synergy_unit_glow(_activated_battle_source_names(report, added))
	_pulse_summary_feedback()

func _active_synergy_keys(report: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for entry in report.get("active", []):
		result.append("%s:%s:%d" % [
			String(entry.get("category", "")),
			String(entry.get("id", "")),
			int(entry.get("tier", 0)),
		])
	return result

func _show_synergy_banner(lines: Array[String]) -> void:
	if _synergy_banner == null or _synergy_banner_label == null:
		return
	if _synergy_banner_tween != null:
		_synergy_banner_tween.kill()
	_synergy_banner_label.text = "[center][b]羁绊共鸣启动[/b]\n%s[/center]" % "\n".join(lines)
	_synergy_banner.visible = true
	_synergy_banner.modulate = Color(1, 1, 1, 0)
	_synergy_banner.scale = Vector2(0.92, 0.92)
	_synergy_banner.position = Vector2(0, -18)
	_synergy_banner_tween = create_tween()
	_synergy_banner_tween.set_parallel(true)
	_synergy_banner_tween.tween_property(_synergy_banner, "modulate:a", 1.0, 0.16)
	_synergy_banner_tween.tween_property(_synergy_banner, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_synergy_banner_tween.tween_property(_synergy_banner, "position", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_synergy_banner_tween.chain().tween_interval(1.05)
	_synergy_banner_tween.chain().tween_property(_synergy_banner, "modulate:a", 0.0, 0.24)
	_synergy_banner_tween.finished.connect(func() -> void:
		_synergy_banner.visible = false
	)

func _activated_battle_source_names(report: Dictionary, added: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for entry in report.get("active", []):
		var key := "%s:%s:%d" % [
			String(entry.get("category", "")),
			String(entry.get("id", "")),
			int(entry.get("tier", 0)),
		]
		if not added.has(key):
			continue
		for source in entry.get("sources", []):
			if String(source.get("scope", "")) != "battle":
				continue
			var name := String(source.get("name", ""))
			if name.is_empty() or names.has(name):
				continue
			names.append(name)
			if names.size() >= 2:
				return names
	if not names.is_empty():
		return names
	for pet_uid in GameState.get_party_uids():
		var display_name := GameState.get_pet_display_name(String(pet_uid))
		if display_name.is_empty() or names.has(display_name):
			continue
		names.append(display_name)
		if names.size() >= 2:
			break
	return names

func _show_synergy_unit_glow(unit_names: Array[String]) -> void:
	if GameState.should_skip_animations() or _synergy_unit_glow_row == null or unit_names.is_empty():
		return
	if _synergy_unit_glow_tween != null:
		_synergy_unit_glow_tween.kill()
	for child in _synergy_unit_glow_row.get_children():
		child.queue_free()
	for unit_name in unit_names.slice(0, 2):
		var badge := PanelContainer.new()
		badge.modulate = Color(1, 1, 1, 0)
		badge.scale = Vector2(0.88, 0.88)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.11, 0.05, 0.94)
		style.border_color = Color(1.0, 0.88, 0.52, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 22
		style.corner_radius_top_right = 22
		style.corner_radius_bottom_left = 22
		style.corner_radius_bottom_right = 22
		badge.add_theme_stylebox_override("panel", style)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 12)
		badge.add_child(margin)
		var label := Label.new()
		label.text = "%s\n共鸣中" % String(unit_name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		margin.add_child(label)
		_synergy_unit_glow_row.add_child(badge)
	_synergy_unit_glow_host.visible = true
	for index in range(_synergy_unit_glow_row.get_child_count()):
		var badge := _synergy_unit_glow_row.get_child(index) as Control
		if badge == null:
			continue
		var badge_tween := create_tween()
		badge_tween.tween_interval(0.04 * float(index))
		badge_tween.set_parallel(true)
		badge_tween.tween_property(badge, "modulate:a", 1.0, 0.14)
		badge_tween.tween_property(badge, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		badge_tween.chain().tween_interval(0.72)
		badge_tween.chain().tween_property(badge, "modulate:a", 0.0, 0.20)
	_synergy_unit_glow_tween = create_tween()
	_synergy_unit_glow_tween.tween_interval(1.02)
	_synergy_unit_glow_tween.finished.connect(func() -> void:
		_synergy_unit_glow_host.visible = false
		_synergy_unit_glow_tween = null
	)

func _pulse_summary_feedback() -> void:
	for node in [player_summary_label, control_summary_label, roster_label]:
		node.modulate = Color(1.0, 0.95, 0.82, 1.0)
		node.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_summary_label, "scale", Vector2(1.02, 1.02), 0.10)
	tween.tween_property(control_summary_label, "scale", Vector2(1.02, 1.02), 0.10)
	tween.tween_property(roster_label, "scale", Vector2(1.02, 1.02), 0.10)
	tween.chain().tween_property(player_summary_label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(control_summary_label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(roster_label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(player_summary_label, "modulate", Color(1, 1, 1, 1), 0.24)
	tween.parallel().tween_property(control_summary_label, "modulate", Color(1, 1, 1, 1), 0.24)
	tween.parallel().tween_property(roster_label, "modulate", Color(1, 1, 1, 1), 0.24)

func _play_stage_transition(title: String, subtitle: String, accent: Color) -> void:
	if GameState.should_skip_animations():
		return
	_ensure_stage_transition_overlay()
	if _stage_transition_tween != null:
		_stage_transition_tween.kill()
	_stage_transition_layer.visible = true
	_stage_transition_backdrop.color = Color(0.04, 0.07, 0.12, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.16, 0.95)
	style.border_color = accent
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.corner_radius_bottom_left = 26
	style.corner_radius_bottom_right = 26
	_stage_transition_panel.add_theme_stylebox_override("panel", style)
	_stage_transition_panel.modulate = Color(1, 1, 1, 0)
	_stage_transition_panel.scale = Vector2(0.94, 0.94)
	_stage_transition_title.text = title
	_stage_transition_title.modulate = accent
	_stage_transition_subtitle.text = "[center]%s[/center]" % subtitle
	_stage_transition_subtitle.modulate = Color(1, 1, 1, 0.0)
	_stage_transition_tween = create_tween()
	_stage_transition_tween.set_parallel(true)
	_stage_transition_tween.tween_property(_stage_transition_backdrop, "color:a", 0.78, 0.18)
	_stage_transition_tween.tween_property(_stage_transition_panel, "modulate:a", 1.0, 0.16)
	_stage_transition_tween.tween_property(_stage_transition_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stage_transition_tween.tween_property(_stage_transition_subtitle, "modulate:a", 1.0, 0.18)
	_stage_transition_tween.chain().tween_interval(0.56)
	_stage_transition_tween.chain().set_parallel(true)
	_stage_transition_tween.tween_property(_stage_transition_panel, "modulate:a", 0.0, 0.22)
	_stage_transition_tween.tween_property(_stage_transition_backdrop, "color:a", 0.0, 0.24)
	_stage_transition_tween.finished.connect(func() -> void:
		_stage_transition_layer.visible = false
		_stage_transition_tween = null
	)

func _season_fx_color(season_id: String) -> Color:
	match season_id:
		"spring":
			return Color(0.54, 0.86, 0.53, 1.0)
		"summer":
			return Color(0.48, 0.82, 1.0, 1.0)
		"autumn":
			return Color(1.0, 0.72, 0.34, 1.0)
		"winter":
			return Color(0.76, 0.88, 1.0, 1.0)
		_:
			return Color(0.95, 0.80, 0.48, 1.0)

func _seasonal_visit_reward(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return {}
	var reward := {}
	var seasonal_resources: Array = habitat.get("seasonal_resources", [])
	if not seasonal_resources.is_empty():
		var base_item := String(seasonal_resources[0])
		reward[base_item] = int(reward.get(base_item, 0)) + 1
	var season_bonus: Dictionary = GameState.get_current_season_rule().get("resource_bonus", {})
	for item_id in seasonal_resources:
		var key := String(item_id)
		if season_bonus.has(key):
			reward[key] = int(reward.get(key, 0)) + int(season_bonus[key])
	return reward

func _merge_reward_items(target: Dictionary, extra: Dictionary) -> void:
	for item_id in extra.keys():
		target[item_id] = int(target.get(item_id, 0)) + int(extra[item_id])

func _check_active_quests() -> void:
	for quest_id in GameState.active_quests.duplicate():
		var quest := DataRepository.get_quest(quest_id)
		if quest.is_empty() or not _quest_is_complete(quest):
			continue
		var result := npc_service.finish_quest(quest_id)
		if not bool(result.get("ok", false)):
			continue
		var reward_items: Dictionary = result.get("items", {})
		var reward_text := _format_item_cost(reward_items)
		var line := "委托完成：%s。" % String(quest.get("title", quest_id))
		var completion_text := String(quest.get("completion_text", ""))
		if not completion_text.is_empty():
			line += " %s" % completion_text
		if not reward_text.is_empty():
			line += " 收到 %s。" % reward_text
		_push_log(line)
		if not String(result.get("journal_entry", "")).is_empty():
			_push_log("记录新增：%s。" % String(result.get("journal_entry", "")))
		var pending_story: Dictionary = Dictionary(result.get("pending_story", {})).duplicate(true)
		if not pending_story.is_empty():
			story_director.queue_quest_story_beat(pending_story)

func _quest_is_complete(quest: Dictionary) -> bool:
	for step in quest.get("steps", []):
		if not _step_is_complete(step):
			return false
	return true

func _step_is_complete(step: Dictionary) -> bool:
	match String(step.get("type", "")):
		"deliver":
			return int(GameState.quest_memory["delivered_items"].get(String(step.get("item", "")), 0)) >= int(step.get("count", 0))
		"visit":
			var habitat_id := String(step.get("habitat_id", ""))
			if habitat_id.is_empty():
				return false
			if step.has("time"):
				return bool(GameState.quest_memory["visited_moments"].get("%s@%s" % [habitat_id, String(step.get("time", ""))], false))
			return int(GameState.quest_memory["visited_habitats"].get(habitat_id, 0)) > 0
		"build":
			return int(GameState.quest_memory["built_levels"].get(String(step.get("building_id", "")), 0)) >= int(step.get("level", 0))
		"encounter":
			return bool(GameState.quest_memory["encounter_species"].get(String(step.get("species_id", "")), false))
		"observe":
			if step.has("species_id"):
				return bool(GameState.quest_memory["observed_species"].get(String(step.get("species_id", "")), false))
			if step.has("marker"):
				return bool(GameState.quest_memory["observed_markers"].get(String(step.get("marker", "")), false))
			return false
		"bond":
			return bool(GameState.quest_memory["bonded_species"].get(String(step.get("species_id", "")), false))
		"talk":
			return bool(GameState.quest_memory["talked_npcs"].get(String(step.get("npc", "")), false))
		"mail":
			return bool(GameState.quest_memory["mailed_destinations"].get(String(step.get("destination", "")), false))
		"return":
			return bool(GameState.quest_memory["returned_npcs"].get(String(step.get("npc", "")), false))
		"calm":
			return bool(GameState.quest_memory["calmed_species"].get(String(step.get("species_id", "")), false))
		_:
			return false

func _is_modal_open() -> bool:
	return ai_turn_in_progress or battle_panel.visible or dice_roll_panel.visible or decision_panel.visible or base_panel.visible or system_panel.visible or main_menu_panel.visible or (is_instance_valid(save_slot_panel) and save_slot_panel.visible) or (is_instance_valid(cutscene_panel) and cutscene_panel.visible) or (is_instance_valid(input_settings_panel) and input_settings_panel.visible)

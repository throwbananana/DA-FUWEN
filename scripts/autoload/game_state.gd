extends Node

const GameData = preload("res://scripts/game_data.gd")

const DEFAULT_SEASON_ID := "spring"
const DEFAULT_SEASON_LENGTH := 6
const SEASON_ORDER := ["spring", "summer", "autumn", "winter"]
const META_SAVE_PATH := "user://meta_progression.save"
const RUN_SAVE_PATH := "user://run_state.save"
const SAVE_DIR := "user://save_slots"
const SAVE_INDEX_PATH := "user://save_slots/index.json"
const SAVE_SLOT_COUNT := 6
const SETTINGS_SAVE_PATH := "user://settings.save"
const BASE_VIEWPORT_SIZE := Vector2i(1280, 720)
const MIN_WINDOW_SIZE := Vector2i(1280, 720)
const WINDOWED_RESOLUTION_PRESETS := [
	{"id": "1280x720", "size": Vector2i(1280, 720), "label": "720p (1280 x 720)"},
	{"id": "1366x768", "size": Vector2i(1366, 768), "label": "WXGA (1366 x 768)"},
	{"id": "1536x864", "size": Vector2i(1536, 864), "label": "HD+ (1536 x 864)"},
	{"id": "1600x900", "size": Vector2i(1600, 900), "label": "900p (1600 x 900)"},
	{"id": "1680x1050", "size": Vector2i(1680, 1050), "label": "WSXGA+ (1680 x 1050)"},
	{"id": "1920x1080", "size": Vector2i(1920, 1080), "label": "1080p (1920 x 1080)"},
	{"id": "1920x1200", "size": Vector2i(1920, 1200), "label": "WUXGA (1920 x 1200)"},
	{"id": "2560x1440", "size": Vector2i(2560, 1440), "label": "1440p (2560 x 1440)"},
	{"id": "2560x1600", "size": Vector2i(2560, 1600), "label": "WQXGA (2560 x 1600)"},
	{"id": "3440x1440", "size": Vector2i(3440, 1440), "label": "UWQHD (3440 x 1440)"},
]
const DEFAULT_WINDOWED_RESOLUTION_ID := "1280x720"
const PLAYER_ACTOR_ID := "player_main"
const PLAYER_ACTOR_NAME := "玩家"
const NURSERY_PRIMARY_BUILDING_ID := "nursery_corner"
const NURSERY_SUPPORT_BUILDING_ID := "warm_nest"
const MAX_PET_SKILL_SLOTS := 4
const CODEX_REVEAL_LOCKED := 0
const CODEX_REVEAL_BASIC := 1
const CODEX_REVEAL_FULL := 2
const TRAVERSAL_SKILL_NAMES := {
	"sky_glide": "腾空翼",
	"bog_stride": "涉泽步",
	"tide_surf": "踏潮鳍",
}
const DOJO_TRAVERSAL_SKILL_AWARDS := {
	"summer_storm_trial:tier_1": ["sky_glide"],
	"autumn_leaf_dojo:tier_1": ["bog_stride"],
	"autumn_leaf_dojo:tier_2": ["tide_surf"],
}

var season_id := DEFAULT_SEASON_ID
var weather_id := "clear"
var time_of_day := "day"
var day_index := 1
var season_length := DEFAULT_SEASON_LENGTH
var global_turn := 1
var season_turn := 1
var week_index := 1
var weekly_turn := 1
var weekly_reroll_count := 0
var weekly_reroll_limit := 1
var season_adjust_points := 0
var anchor_points := 0
var board_region_id := ""
var current_board_node_id := 0
var revealed_board_nodes: Array[int] = []
var node_danger: Dictionary = {}
var pending_node_ambushes: Dictionary = {}
var active_board_threats: Array = []
var npc_positions: Dictionary = {}
var run_modifiers: Array = []
var pending_minigame_bonus: Dictionary = {}
var pending_minigame_bonus_notes: Array[String] = []
var traversal_skills: Array[String] = []
var weekly_objective: Dictionary = {}
var weekly_progress: Dictionary = {}
var completed_seasons := 0
var exploration_points := 0
var exploration_points_total := 0
var annual_competition_history: Array = []
var annual_competition_reminder_years: Array[int] = []
var latest_annual_competition_result: Dictionary = {}
var completed_tutorials: Array[String] = []
var claimed_season_bosses: Array[String] = []
var board_loop_progress: Dictionary = {}
var meta_unlocks: Dictionary = {
	"tracks": [],
	"dice_modules": [],
}
var settings: Dictionary = {}
var _selected_run_slot_id := "slot_01"

var inventory: Dictionary = {}
var habitats: Dictionary = {}
var pet_states: Dictionary = {}
var npc_trust: Dictionary = {}
var npc_duel_records: Dictionary = {}
var active_quests: Array[String] = []
var completed_quests: Array[String] = []
var discovered_species: Array[String] = []
var revealed_codex_entries: Array[String] = []
var manual_codex_unlocks: Array[String] = []
var unlocked_encyclopedia_entries: Array[String] = []
var bonded_species: Array[String] = []
var observed_species: Array[String] = []
var journal_entries: Array[String] = []
var visit_history: Array = []
var quest_memory: Dictionary = {}
var dojo_clear_flags: Dictionary = {}
var season_unlock_history: Dictionary = {}
var season_points := 0
var badge_count := 0
var failed_dojo_streak := 0
var current_available_habitats_cache: Array[String] = []
var party_slots: Array[String] = []
var reserve_slots: Array[String] = []
var pet_capacity := 4
var backpack_capacity: int:
	get:
		return pet_capacity
	set(value):
		pet_capacity = maxi(0, value)
		_sync_roster_slots()
var wallet_gold := 12
var bank_gold := 0
var shop_purchase_counts: Dictionary = {}
var max_hunger := 100
var hunger := 100
var hunger_warning_threshold := 30
var hunger_cost_per_travel := 6
var hunger_cost_per_week := 10
var camp_hunger_restore := 18
var rival_wallets: Dictionary = {}
var ai_players: Array = []
var active_trait_runtime_bonus: Dictionary = {}
var active_trait_runtime_report: Dictionary = {"active": [], "nearby": []}
var trait_runtime_dirty := true
var _trait_synergy_service: RefCounted = null

var _pet_serial := 1

func _ready() -> void:
	load_meta_progression()
	load_settings()
	apply_settings()
	reset_for_new_season()

func reset_for_new_season() -> void:
	_ensure_meta_progression_defaults()
	season_id = DEFAULT_SEASON_ID
	weather_id = "clear"
	time_of_day = "day"
	day_index = 1
	season_length = DEFAULT_SEASON_LENGTH
	global_turn = 1
	season_turn = 1
	week_index = 1
	weekly_turn = 1
	weekly_reroll_count = 0
	weekly_reroll_limit = 1
	season_adjust_points = 0
	anchor_points = 0
	board_region_id = ""
	current_board_node_id = 0
	revealed_board_nodes.clear()
	node_danger.clear()
	pending_node_ambushes.clear()
	active_board_threats.clear()
	npc_positions.clear()
	run_modifiers.clear()
	pending_minigame_bonus.clear()
	pending_minigame_bonus_notes.clear()
	traversal_skills.clear()
	weekly_objective.clear()
	weekly_progress.clear()
	completed_seasons = 0
	exploration_points = 0
	annual_competition_history.clear()
	annual_competition_reminder_years.clear()
	latest_annual_competition_result.clear()
	claimed_season_bosses.clear()
	board_loop_progress.clear()
	inventory = _default_inventory()
	habitats = _default_habitats()
	pet_states.clear()
	npc_trust.clear()
	npc_duel_records.clear()
	active_quests.clear()
	completed_quests.clear()
	discovered_species.clear()
	revealed_codex_entries.clear()
	manual_codex_unlocks.clear()
	unlocked_encyclopedia_entries.clear()
	bonded_species.clear()
	observed_species.clear()
	journal_entries.clear()
	visit_history.clear()
	dojo_clear_flags.clear()
	season_unlock_history.clear()
	season_points = 0
	badge_count = 0
	failed_dojo_streak = 0
	current_available_habitats_cache.clear()
	party_slots.clear()
	reserve_slots.clear()
	pet_capacity = 4
	wallet_gold = 12
	bank_gold = 0
	shop_purchase_counts.clear()
	hunger = max_hunger
	rival_wallets = {}
	ai_players = _build_default_ai_players()
	active_trait_runtime_bonus = {}
	active_trait_runtime_report = {"active": [], "nearby": []}
	trait_runtime_dirty = true
	quest_memory = _default_quest_memory()
	_pet_serial = 1
	_seed_companions()
	_recalculate_pet_capacity()
	_sync_roster_slots()
	_sync_current_season_rule()
	refresh_season_unlocks()
	_sync_rival_wallets_from_ai_players()

func _ensure_meta_progression_defaults() -> void:
	if meta_unlocks.is_empty():
		meta_unlocks = {
			"tracks": [],
			"dice_modules": [],
		}

func _default_quest_memory() -> Dictionary:
	return {
		"visited_habitats": {},
		"visited_moments": {},
		"built_levels": {},
		"encounter_species": {},
		"observed_species": {},
		"observed_markers": {},
		"bonded_species": {},
		"calmed_species": {},
		"talked_npcs": {},
		"mailed_destinations": {},
		"returned_npcs": {},
		"delivered_items": {},
		"completed_events": {},
		"event_last_turn": {},
		"unlocked_dialogues": {},
		"dialogue_seen_counts": {},
		"dialogue_last_seen": {},
		"last_dialogue_by_npc": {},
		"npc_topic_counts": {},
		"active_story_arcs": {},
		"completed_story_arcs": {},
		"story_flags": {},
		"story_beat_history": {},
		"map_effect_flags": {},
		"recent_ambient_events": [],
		"social_relations": {},
		"fishing_records": {},
		"fishing_spot_pressure": {},
		"released_aquatic_species": {},
		"festival_scores": {},
		"fishing_event_history": {},
	}

func _ensure_quest_memory_defaults() -> void:
	var defaults := _default_quest_memory()
	if quest_memory.is_empty():
		quest_memory = defaults
		return
	for key in defaults.keys():
		if quest_memory.has(key):
			continue
		var value = defaults[key]
		if typeof(value) == TYPE_DICTIONARY:
			quest_memory[key] = Dictionary(value).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			quest_memory[key] = Array(value).duplicate(true)
		else:
			quest_memory[key] = value

func _default_settings() -> Dictionary:
	return {
		"fullscreen": false,
		"window_resolution": _best_fit_window_resolution_id(),
		"reduced_motion": false,
		"tutorials_enabled": true,
		"language": "zh_cn",
		"input_bindings": {},
	}

func _ensure_settings_defaults() -> void:
	if settings.is_empty():
		settings = _default_settings()
	settings["fullscreen"] = bool(settings.get("fullscreen", false))
	var resolution_id := String(settings.get("window_resolution", _best_fit_window_resolution_id()))
	settings["window_resolution"] = resolution_id if is_valid_window_resolution_id(resolution_id) else _best_fit_window_resolution_id()
	settings["reduced_motion"] = bool(settings.get("reduced_motion", false))
	settings["tutorials_enabled"] = bool(settings.get("tutorials_enabled", true))
	var language_id := String(settings.get("language", "zh_cn"))
	settings["language"] = language_id if language_id in ["zh_cn", "ja_jp", "en_us"] else "zh_cn"
	var input_bindings_value = settings.get("input_bindings", {})
	settings["input_bindings"] = Dictionary(input_bindings_value).duplicate(true) if typeof(input_bindings_value) == TYPE_DICTIONARY else {}

func load_meta_progression() -> void:
	_ensure_meta_progression_defaults()
	exploration_points_total = 0
	meta_unlocks = {
		"tracks": [],
		"dice_modules": [],
	}
	completed_tutorials.clear()
	if not FileAccess.file_exists(META_SAVE_PATH):
		return
	var raw := FileAccess.get_file_as_string(META_SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid meta progression save, ignoring %s" % META_SAVE_PATH)
		return
	exploration_points_total = maxi(0, int(parsed.get("exploration_points_total", 0)))
	var saved_unlocks = parsed.get("meta_unlocks", {})
	if typeof(saved_unlocks) != TYPE_DICTIONARY:
		return
	meta_unlocks = {
		"tracks": _coerce_string_array(saved_unlocks.get("tracks", [])),
		"dice_modules": _coerce_string_array(saved_unlocks.get("dice_modules", [])),
	}
	completed_tutorials = _coerce_string_array(parsed.get("completed_tutorials", []))

func save_meta_progression() -> void:
	_ensure_meta_progression_defaults()
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: failed to open meta progression save -> %s" % META_SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"exploration_points_total": exploration_points_total,
		"completed_tutorials": completed_tutorials.duplicate(),
		"meta_unlocks": {
			"tracks": meta_unlocks.get("tracks", []).duplicate(),
			"dice_modules": meta_unlocks.get("dice_modules", []).duplicate(),
		},
	}, "\t"))

func load_settings() -> void:
	settings = _default_settings()
	if not FileAccess.file_exists(SETTINGS_SAVE_PATH):
		return
	var raw := FileAccess.get_file_as_string(SETTINGS_SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid settings save, ignoring %s" % SETTINGS_SAVE_PATH)
		return
	settings["fullscreen"] = bool(parsed.get("fullscreen", settings.get("fullscreen", false)))
	settings["window_resolution"] = String(parsed.get("window_resolution", settings.get("window_resolution", _best_fit_window_resolution_id())))
	settings["reduced_motion"] = bool(parsed.get("reduced_motion", settings.get("reduced_motion", false)))
	settings["tutorials_enabled"] = bool(parsed.get("tutorials_enabled", settings.get("tutorials_enabled", true)))
	settings["language"] = String(parsed.get("language", settings.get("language", "zh_cn")))
	var input_bindings_value = parsed.get("input_bindings", settings.get("input_bindings", {}))
	settings["input_bindings"] = Dictionary(input_bindings_value).duplicate(true) if typeof(input_bindings_value) == TYPE_DICTIONARY else {}
	_ensure_settings_defaults()

func save_settings() -> void:
	_ensure_settings_defaults()
	var file := FileAccess.open(SETTINGS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: failed to open settings save -> %s" % SETTINGS_SAVE_PATH)
		return
	file.store_string(JSON.stringify(settings.duplicate(true), "\t"))

func apply_settings() -> void:
	_ensure_settings_defaults()
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	window.min_size = minimum_window_size()
	if bool(settings.get("fullscreen", false)):
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var target_size := _clamp_windowed_resolution(current_window_resolution_size())
	if window.size != target_size:
		window.size = target_size
	_center_window(window, target_size)

func set_setting(key: String, value: Variant) -> void:
	_ensure_settings_defaults()
	settings[key] = value
	_ensure_settings_defaults()
	apply_settings()
	save_settings()

func prefers_reduced_motion() -> bool:
	_ensure_settings_defaults()
	return bool(settings.get("reduced_motion", false))

func tutorials_enabled() -> bool:
	_ensure_settings_defaults()
	return bool(settings.get("tutorials_enabled", true))

func current_language() -> String:
	_ensure_settings_defaults()
	return String(settings.get("language", "zh_cn"))

func get_input_bindings() -> Dictionary:
	_ensure_settings_defaults()
	return Dictionary(settings.get("input_bindings", {})).duplicate(true)

func set_input_bindings(bindings: Dictionary) -> void:
	_ensure_settings_defaults()
	settings["input_bindings"] = Dictionary(bindings).duplicate(true)
	save_settings()

func minimum_window_size() -> Vector2i:
	return MIN_WINDOW_SIZE

func get_window_resolution_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var current_screen_preset := _dynamic_native_window_resolution_preset()
	if not current_screen_preset.is_empty():
		presets.append(current_screen_preset)
	for preset in WINDOWED_RESOLUTION_PRESETS:
		presets.append(Dictionary(preset).duplicate(true))
	return presets

func get_available_window_resolution_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var usable_size := _current_screen_usable_size()
	for preset in get_window_resolution_presets():
		var preset_size := Vector2i(preset.get("size", Vector2i(0, 0)))
		if usable_size == Vector2i.ZERO or (preset_size.x <= usable_size.x and preset_size.y <= usable_size.y):
			presets.append(Dictionary(preset).duplicate(true))
	if presets.is_empty():
		var fallback := _window_resolution_preset_from_id(DEFAULT_WINDOWED_RESOLUTION_ID)
		if not fallback.is_empty():
			presets.append(fallback)
	return presets

func is_valid_window_resolution_id(resolution_id: String) -> bool:
	return not _window_resolution_preset_from_id(resolution_id).is_empty()

func current_window_resolution_id() -> String:
	_ensure_settings_defaults()
	return String(settings.get("window_resolution", DEFAULT_WINDOWED_RESOLUTION_ID))

func current_window_resolution_size() -> Vector2i:
	var preset := _window_resolution_preset_from_id(current_window_resolution_id())
	return Vector2i(preset.get("size", BASE_VIEWPORT_SIZE))

func current_window_resolution_label() -> String:
	var preset := _window_resolution_preset_from_id(current_window_resolution_id())
	if not preset.is_empty():
		return String(preset.get("label", current_window_resolution_id()))
	var size := current_window_resolution_size()
	return "%d x %d" % [size.x, size.y]

func should_skip_animations() -> bool:
	return DisplayServer.get_name() == "headless" or prefers_reduced_motion()

func _slot_id_from_index(index: int) -> String:
	return "slot_%02d" % index

func _slot_path(slot_id: String) -> String:
	return "%s/%s.save" % [SAVE_DIR, slot_id]

func _default_slot_meta(slot_id: String, index: int) -> Dictionary:
	return {
		"id": slot_id,
		"title": "存档 %d" % index,
		"exists": false,
		"updated_at_unix": 0,
		"summary": {},
	}

func ensure_save_index() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if FileAccess.file_exists(SAVE_INDEX_PATH):
		var existing := _load_save_index()
		if not existing.is_empty():
			return
	var slots: Array = []
	for index in range(SAVE_SLOT_COUNT):
		slots.append(_default_slot_meta(_slot_id_from_index(index + 1), index + 1))
	_save_save_index({
		"version": 2,
		"selected_slot_id": "slot_01",
		"slots": slots,
	})

func _load_save_index() -> Dictionary:
	if not FileAccess.file_exists(SAVE_INDEX_PATH):
		return {}
	var raw := FileAccess.get_file_as_string(SAVE_INDEX_PATH)
	if raw.strip_edges().is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var normalized := {
		"version": 2,
		"selected_slot_id": String(parsed.get("selected_slot_id", "slot_01")),
		"slots": [],
	}
	var saved_slots: Array = Array(parsed.get("slots", [])).duplicate(true)
	for index in range(SAVE_SLOT_COUNT):
		var slot_id := _slot_id_from_index(index + 1)
		var meta := _default_slot_meta(slot_id, index + 1)
		for raw_slot in saved_slots:
			var saved_meta: Dictionary = Dictionary(raw_slot).duplicate(true)
			if String(saved_meta.get("id", "")) != slot_id:
				continue
			meta["title"] = String(saved_meta.get("title", meta.get("title", slot_id)))
			meta["exists"] = bool(saved_meta.get("exists", false)) or FileAccess.file_exists(_slot_path(slot_id))
			meta["updated_at_unix"] = int(saved_meta.get("updated_at_unix", 0))
			meta["summary"] = _duplicate_dictionary(saved_meta.get("summary", {}))
			break
		normalized["slots"].append(meta)
	if not _slot_id_exists(String(normalized.get("selected_slot_id", "slot_01"))):
		normalized["selected_slot_id"] = "slot_01"
	return normalized

func _save_save_index(index_payload: Dictionary) -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(SAVE_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: failed to open save index -> %s" % SAVE_INDEX_PATH)
		return
	file.store_string(JSON.stringify(index_payload, "	"))

func _slot_id_exists(slot_id: String) -> bool:
	for index in range(SAVE_SLOT_COUNT):
		if _slot_id_from_index(index + 1) == slot_id:
			return true
	return false

func _resolve_run_slot_id(slot_id: String = "") -> String:
	var resolved := slot_id if not slot_id.is_empty() else get_selected_run_slot_id()
	return resolved if _slot_id_exists(resolved) else "slot_01"

func _has_any_slot_save() -> bool:
	for slot in list_run_slots():
		if bool(Dictionary(slot).get("exists", false)):
			return true
	return false

func load_legacy_run_payload() -> Dictionary:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return {}
	var raw := FileAccess.get_file_as_string(RUN_SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid legacy run save, ignoring %s" % RUN_SAVE_PATH)
		return {}
	return Dictionary(parsed).duplicate(true)

func migrate_legacy_run_save() -> void:
	ensure_save_index()
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	if _has_any_slot_save():
		return
	var payload := load_legacy_run_payload()
	if payload.is_empty():
		return
	save_run_payload(payload, "slot_01")
	set_selected_run_slot_id("slot_01")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))

func list_run_slots() -> Array[Dictionary]:
	ensure_save_index()
	var index_payload := _load_save_index()
	var slots: Array[Dictionary] = []
	for slot in index_payload.get("slots", []):
		slots.append(Dictionary(slot).duplicate(true))
	return slots

func get_run_slot_meta(slot_id: String = "") -> Dictionary:
	var resolved := _resolve_run_slot_id(slot_id)
	for slot in list_run_slots():
		if String(slot.get("id", "")) == resolved:
			return Dictionary(slot).duplicate(true)
	return {}

func get_selected_run_slot_id() -> String:
	ensure_save_index()
	var index_payload := _load_save_index()
	_selected_run_slot_id = _resolve_run_slot_id(String(index_payload.get("selected_slot_id", _selected_run_slot_id)))
	return _selected_run_slot_id

func set_selected_run_slot_id(slot_id: String) -> void:
	ensure_save_index()
	var resolved := _resolve_run_slot_id(slot_id)
	var index_payload := _load_save_index()
	index_payload["selected_slot_id"] = resolved
	_selected_run_slot_id = resolved
	_save_save_index(index_payload)

func has_run_save(slot_id: String = "") -> bool:
	return bool(get_run_slot_meta(slot_id).get("exists", false))

func has_any_run_save() -> bool:
	return _has_any_slot_save()

func save_run_payload(payload: Dictionary, slot_id: String = "") -> void:
	ensure_save_index()
	var resolved := _resolve_run_slot_id(slot_id)
	var file := FileAccess.open(_slot_path(resolved), FileAccess.WRITE)
	if file == null:
		push_error("GameState: failed to open run save slot -> %s" % resolved)
		return
	file.store_string(JSON.stringify(payload, "	"))
	var index_payload := _load_save_index()
	var slots: Array = Array(index_payload.get("slots", [])).duplicate(true)
	for index in range(slots.size()):
		var meta: Dictionary = Dictionary(slots[index]).duplicate(true)
		if String(meta.get("id", "")) != resolved:
			continue
		meta["exists"] = true
		meta["updated_at_unix"] = Time.get_unix_time_from_system()
		meta["summary"] = _duplicate_dictionary(payload.get("summary", {}))
		slots[index] = meta
		break
	index_payload["slots"] = slots
	index_payload["selected_slot_id"] = resolved
	_selected_run_slot_id = resolved
	_save_save_index(index_payload)

func load_run_payload(slot_id: String = "") -> Dictionary:
	ensure_save_index()
	var resolved := _resolve_run_slot_id(slot_id)
	var save_path := _slot_path(resolved)
	if not FileAccess.file_exists(save_path):
		return {}
	var raw := FileAccess.get_file_as_string(save_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid run save, ignoring %s" % save_path)
		return {}
	return Dictionary(parsed).duplicate(true)

func clear_run_save(slot_id: String = "") -> void:
	ensure_save_index()
	var resolved := _resolve_run_slot_id(slot_id)
	var save_path := _slot_path(resolved)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var index_payload := _load_save_index()
	var slots: Array = Array(index_payload.get("slots", [])).duplicate(true)
	for index in range(slots.size()):
		var meta: Dictionary = Dictionary(slots[index]).duplicate(true)
		if String(meta.get("id", "")) != resolved:
			continue
		meta["exists"] = false
		meta["updated_at_unix"] = 0
		meta["summary"] = {}
		slots[index] = meta
		break
	index_payload["slots"] = slots
	_save_save_index(index_payload)

func _coerce_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var text := String(value)
		if text.is_empty() or result.has(text):
			continue
		result.append(text)
	return result

func _coerce_int_array(values: Variant) -> Array[int]:
	var result: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(int(value))
	return result

func _duplicate_dictionary(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return Dictionary(value).duplicate(true)

func _duplicate_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return Array(value).duplicate(true)

func _static_window_resolution_preset_from_id(resolution_id: String) -> Dictionary:
	for preset in WINDOWED_RESOLUTION_PRESETS:
		if String(preset.get("id", "")) == resolution_id:
			return Dictionary(preset).duplicate(true)
	return {}

func _window_resolution_preset_from_id(resolution_id: String) -> Dictionary:
	var dynamic_preset := _dynamic_native_window_resolution_preset()
	if not dynamic_preset.is_empty() and String(dynamic_preset.get("id", "")) == resolution_id:
		return dynamic_preset
	return _static_window_resolution_preset_from_id(resolution_id)

func _best_fit_window_resolution_id() -> String:
	var screen_size := _current_screen_usable_size()
	if screen_size == Vector2i.ZERO:
		return DEFAULT_WINDOWED_RESOLUTION_ID
	var best_id := DEFAULT_WINDOWED_RESOLUTION_ID
	var best_area := 0
	for preset in get_window_resolution_presets():
		var preset_size := Vector2i(preset.get("size", Vector2i(0, 0)))
		if preset_size.x > screen_size.x or preset_size.y > screen_size.y:
			continue
		var area := preset_size.x * preset_size.y
		if area > best_area:
			best_area = area
			best_id = String(preset.get("id", DEFAULT_WINDOWED_RESOLUTION_ID))
	return best_id

func _current_screen_usable_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	var usable_rect := DisplayServer.screen_get_usable_rect()
	return usable_rect.size

func _dynamic_native_window_resolution_preset() -> Dictionary:
	var usable_size := _current_screen_usable_size()
	if usable_size == Vector2i.ZERO:
		return {}
	if usable_size.x < MIN_WINDOW_SIZE.x or usable_size.y < MIN_WINDOW_SIZE.y:
		return {}
	var preset_id := "%dx%d" % [usable_size.x, usable_size.y]
	if not _static_window_resolution_preset_from_id(preset_id).is_empty():
		return {}
	return {
		"id": preset_id,
		"size": usable_size,
		"label": "当前屏幕可用区 (%d x %d)" % [usable_size.x, usable_size.y],
	}

func _clamp_windowed_resolution(size: Vector2i) -> Vector2i:
	var usable_size := _current_screen_usable_size()
	if usable_size == Vector2i.ZERO:
		return Vector2i(maxi(size.x, MIN_WINDOW_SIZE.x), maxi(size.y, MIN_WINDOW_SIZE.y))
	var min_width := MIN_WINDOW_SIZE.x if usable_size.x >= MIN_WINDOW_SIZE.x else usable_size.x
	var min_height := MIN_WINDOW_SIZE.y if usable_size.y >= MIN_WINDOW_SIZE.y else usable_size.y
	return Vector2i(
		clampi(size.x, min_width, usable_size.x),
		clampi(size.y, min_height, usable_size.y)
	)

func _center_window(window: Window, size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var usable_rect := DisplayServer.screen_get_usable_rect()
	if usable_rect.size == Vector2i.ZERO:
		return
	window.position = usable_rect.position + Vector2i(
		maxi((usable_rect.size.x - size.x) / 2, 0),
		maxi((usable_rect.size.y - size.y) / 2, 0)
	)

func build_runtime_snapshot() -> Dictionary:
	return {
		"season_id": season_id,
		"weather_id": weather_id,
		"time_of_day": time_of_day,
		"day_index": day_index,
		"season_length": season_length,
		"global_turn": global_turn,
		"season_turn": season_turn,
		"week_index": week_index,
		"weekly_turn": weekly_turn,
		"weekly_reroll_count": weekly_reroll_count,
		"weekly_reroll_limit": weekly_reroll_limit,
		"season_adjust_points": season_adjust_points,
		"anchor_points": anchor_points,
		"board_region_id": board_region_id,
		"current_board_node_id": current_board_node_id,
		"revealed_board_nodes": revealed_board_nodes.duplicate(),
		"node_danger": node_danger.duplicate(true),
		"pending_node_ambushes": pending_node_ambushes.duplicate(true),
		"active_board_threats": active_board_threats.duplicate(true),
		"npc_positions": npc_positions.duplicate(true),
		"run_modifiers": run_modifiers.duplicate(true),
		"pending_minigame_bonus": pending_minigame_bonus.duplicate(true),
		"pending_minigame_bonus_notes": pending_minigame_bonus_notes.duplicate(),
		"traversal_skills": traversal_skills.duplicate(),
		"weekly_objective": weekly_objective.duplicate(true),
		"weekly_progress": weekly_progress.duplicate(true),
		"completed_seasons": completed_seasons,
		"exploration_points": exploration_points,
		"annual_competition_history": annual_competition_history.duplicate(true),
		"annual_competition_reminder_years": annual_competition_reminder_years.duplicate(),
		"latest_annual_competition_result": latest_annual_competition_result.duplicate(true),
		"claimed_season_bosses": claimed_season_bosses.duplicate(),
		"board_loop_progress": board_loop_progress.duplicate(true),
		"inventory": inventory.duplicate(true),
		"habitats": habitats.duplicate(true),
		"pet_states": pet_states.duplicate(true),
		"npc_trust": npc_trust.duplicate(true),
		"npc_duel_records": npc_duel_records.duplicate(true),
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"discovered_species": discovered_species.duplicate(),
		"revealed_codex_entries": revealed_codex_entries.duplicate(),
		"manual_codex_unlocks": manual_codex_unlocks.duplicate(),
		"unlocked_encyclopedia_entries": unlocked_encyclopedia_entries.duplicate(),
		"bonded_species": bonded_species.duplicate(),
		"observed_species": observed_species.duplicate(),
		"journal_entries": journal_entries.duplicate(),
		"visit_history": visit_history.duplicate(true),
		"quest_memory": quest_memory.duplicate(true),
		"dojo_clear_flags": dojo_clear_flags.duplicate(true),
		"season_unlock_history": season_unlock_history.duplicate(true),
		"season_points": season_points,
		"badge_count": badge_count,
		"failed_dojo_streak": failed_dojo_streak,
		"party_slots": party_slots.duplicate(),
		"reserve_slots": reserve_slots.duplicate(),
		"pet_capacity": pet_capacity,
		"battle_slots": party_slots.duplicate(),
		"backpack_slots": reserve_slots.duplicate(),
		"backpack_capacity": pet_capacity,
		"wallet_gold": wallet_gold,
		"bank_gold": bank_gold,
		"shop_purchase_counts": shop_purchase_counts.duplicate(true),
		"max_hunger": max_hunger,
		"hunger": hunger,
		"rival_wallets": rival_wallets.duplicate(true),
		"ai_players": ai_players.duplicate(true),
		"pet_serial": _pet_serial,
	}

func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	season_id = String(snapshot.get("season_id", DEFAULT_SEASON_ID))
	weather_id = String(snapshot.get("weather_id", "clear"))
	time_of_day = String(snapshot.get("time_of_day", "day"))
	day_index = int(snapshot.get("day_index", 1))
	season_length = int(snapshot.get("season_length", DEFAULT_SEASON_LENGTH))
	global_turn = int(snapshot.get("global_turn", 1))
	season_turn = int(snapshot.get("season_turn", 1))
	week_index = int(snapshot.get("week_index", 1))
	weekly_turn = int(snapshot.get("weekly_turn", 1))
	weekly_reroll_count = int(snapshot.get("weekly_reroll_count", 0))
	weekly_reroll_limit = int(snapshot.get("weekly_reroll_limit", 1))
	season_adjust_points = int(snapshot.get("season_adjust_points", 0))
	anchor_points = int(snapshot.get("anchor_points", 0))
	board_region_id = String(snapshot.get("board_region_id", ""))
	current_board_node_id = int(snapshot.get("current_board_node_id", 0))
	revealed_board_nodes = _coerce_int_array(snapshot.get("revealed_board_nodes", []))
	node_danger = _duplicate_dictionary(snapshot.get("node_danger", {}))
	pending_node_ambushes = _duplicate_dictionary(snapshot.get("pending_node_ambushes", {}))
	active_board_threats = _duplicate_array(snapshot.get("active_board_threats", []))
	npc_positions = _duplicate_dictionary(snapshot.get("npc_positions", {}))
	run_modifiers = _duplicate_array(snapshot.get("run_modifiers", []))
	pending_minigame_bonus = _duplicate_dictionary(snapshot.get("pending_minigame_bonus", {}))
	pending_minigame_bonus_notes = _coerce_string_array(snapshot.get("pending_minigame_bonus_notes", []))
	traversal_skills = _coerce_string_array(snapshot.get("traversal_skills", []))
	weekly_objective = _duplicate_dictionary(snapshot.get("weekly_objective", {}))
	weekly_progress = _duplicate_dictionary(snapshot.get("weekly_progress", {}))
	completed_seasons = int(snapshot.get("completed_seasons", 0))
	exploration_points = int(snapshot.get("exploration_points", 0))
	annual_competition_history = _duplicate_array(snapshot.get("annual_competition_history", []))
	annual_competition_reminder_years = _coerce_int_array(snapshot.get("annual_competition_reminder_years", []))
	latest_annual_competition_result = _duplicate_dictionary(snapshot.get("latest_annual_competition_result", {}))
	claimed_season_bosses = _coerce_string_array(snapshot.get("claimed_season_bosses", []))
	board_loop_progress = _duplicate_dictionary(snapshot.get("board_loop_progress", {}))
	inventory = _duplicate_dictionary(snapshot.get("inventory", {}))
	habitats = _duplicate_dictionary(snapshot.get("habitats", {}))
	_normalize_habitats_state()
	pet_states = _duplicate_dictionary(snapshot.get("pet_states", {}))
	_normalize_pet_states()
	npc_trust = _duplicate_dictionary(snapshot.get("npc_trust", {}))
	npc_duel_records = _duplicate_dictionary(snapshot.get("npc_duel_records", {}))
	active_quests = _coerce_string_array(snapshot.get("active_quests", []))
	completed_quests = _coerce_string_array(snapshot.get("completed_quests", []))
	discovered_species = _coerce_string_array(snapshot.get("discovered_species", []))
	revealed_codex_entries = _coerce_string_array(snapshot.get("revealed_codex_entries", []))
	manual_codex_unlocks = _coerce_string_array(snapshot.get("manual_codex_unlocks", []))
	unlocked_encyclopedia_entries = _coerce_string_array(snapshot.get("unlocked_encyclopedia_entries", []))
	bonded_species = _coerce_string_array(snapshot.get("bonded_species", []))
	observed_species = _coerce_string_array(snapshot.get("observed_species", []))
	journal_entries = _coerce_string_array(snapshot.get("journal_entries", []))
	visit_history = _duplicate_array(snapshot.get("visit_history", []))
	quest_memory = _duplicate_dictionary(snapshot.get("quest_memory", {}))
	_ensure_quest_memory_defaults()
	dojo_clear_flags = _duplicate_dictionary(snapshot.get("dojo_clear_flags", {}))
	season_unlock_history = _duplicate_dictionary(snapshot.get("season_unlock_history", {}))
	season_points = int(snapshot.get("season_points", 0))
	badge_count = int(snapshot.get("badge_count", 0))
	failed_dojo_streak = int(snapshot.get("failed_dojo_streak", 0))
	party_slots = _coerce_string_array(snapshot.get("party_slots", snapshot.get("battle_slots", [])))
	reserve_slots = _coerce_string_array(snapshot.get("reserve_slots", snapshot.get("backpack_slots", [])))
	pet_capacity = int(snapshot.get("pet_capacity", snapshot.get("backpack_capacity", 4)))
	wallet_gold = int(snapshot.get("wallet_gold", 12))
	bank_gold = int(snapshot.get("bank_gold", 0))
	shop_purchase_counts = _duplicate_dictionary(snapshot.get("shop_purchase_counts", {}))
	max_hunger = maxi(1, int(snapshot.get("max_hunger", 100)))
	hunger = clampi(int(snapshot.get("hunger", max_hunger)), 0, max_hunger)
	rival_wallets = _duplicate_dictionary(snapshot.get("rival_wallets", {}))
	ai_players = _duplicate_array(snapshot.get("ai_players", []))
	if ai_players.is_empty():
		ai_players = _build_default_ai_players()
	_pet_serial = int(snapshot.get("pet_serial", 1))
	current_available_habitats_cache.clear()
	active_trait_runtime_bonus = {}
	active_trait_runtime_report = {"active": [], "nearby": []}
	trait_runtime_dirty = true
	_sync_current_season_rule()
	refresh_season_unlocks()
	_recalculate_pet_capacity()
	_sync_roster_slots()
	_sync_rival_wallets_from_ai_players()

func has_completed_tutorial(tutorial_id: String) -> bool:
	return completed_tutorials.has(tutorial_id)

func mark_tutorial_completed(tutorial_id: String) -> void:
	if tutorial_id.is_empty() or has_completed_tutorial(tutorial_id):
		return
	completed_tutorials.append(tutorial_id)
	save_meta_progression()

func _default_inventory() -> Dictionary:
	return {
		"soft_moss": 10,
		"fiber": 7,
		"wood": 12,
		"stone_chip": 10,
		"water_drop": 8,
		"parts": 8,
		"reed": 6,
		"rope": 4,
		"warm_stone": 3,
		"glass": 3,
		"glow_dust": 3,
		"oil": 2,
		"metal": 3,
		"tea_leaf": 4,
		"capture_ball": 2,
		"healing_potion": 2,
		"cloth": 3,
		"ink": 2,
		"paper": 3,
	}

func _default_habitats() -> Dictionary:
	var result := {
		"mist_moss_cave": {
			"resident_uid": "",
			"assistant_uid": "",
			"resident_actor_type": "",
			"resident_actor_id": "",
			"building_levels": {
				"warm_nest": 0,
				"moss_bed": 0,
				"nursery_corner": 0,
			},
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": true,
		},
		"crystal_creek": {
			"resident_uid": "",
			"assistant_uid": "",
			"resident_actor_type": "",
			"resident_actor_id": "",
			"building_levels": {
				"shallow_pool": 0,
				"sun_drying_rack": 0,
				"reed_shed": 0,
			},
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": true,
		},
		"sky_post": {
			"service_levels": {
				"tea_shed": 0,
				"boarding_pen": 0,
				"message_board": 0,
			},
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": true,
		},
		"ancient_platform": {
			"resident_uid": "",
			"assistant_uid": "",
			"resident_actor_type": "",
			"resident_actor_id": "",
			"building_levels": {
				"watch_tower": 0,
				"repair_bench": 0,
				"echo_room": 0,
			},
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": true,
		},
		"copper_hammer_bazaar": {
			"service_levels": {},
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": true,
		},
		"radiant_spire": {
			"rank": 0,
			"last_visit_day": -1,
			"is_unlocked": false,
		},
	}
	for habitat_id in DataRepository.habitats.keys():
		var habitat := DataRepository.get_habitat(habitat_id)
		if result.has(habitat_id):
			result[habitat_id] = _merge_habitat_state(result[habitat_id], habitat_id, habitat)
			continue
		result[habitat_id] = _build_default_habitat_state(habitat_id, habitat)
	return result

func _merge_habitat_state(state: Dictionary, habitat_id: String, habitat: Dictionary) -> Dictionary:
	var merged: Dictionary = state.duplicate(true)
	if _uses_resident_slots(habitat):
		if not merged.has("resident_uid"):
			merged["resident_uid"] = ""
		if not merged.has("assistant_uid"):
			merged["assistant_uid"] = ""
		if not merged.has("resident_actor_type"):
			merged["resident_actor_type"] = ""
		if not merged.has("resident_actor_id"):
			merged["resident_actor_id"] = ""
	var level_key := "service_levels" if _uses_service_levels(habitat) else "building_levels"
	var building_ids: Array = habitat.get("buildings", [])
	var runtime_states: Dictionary = _duplicate_dictionary(merged.get("building_runtime_states", {}))
	if not building_ids.is_empty():
		var levels: Dictionary = merged.get(level_key, {})
		for building_id in building_ids:
			var id := String(building_id)
			if not levels.has(id):
				levels[id] = 0
			runtime_states[id] = _normalize_building_runtime_state(Dictionary(runtime_states.get(id, {})).duplicate(true))
		merged[level_key] = levels
	merged["building_runtime_states"] = runtime_states
	var stored_unlock := bool(merged.get("is_unlocked", _default_unlock_state(habitat_id, habitat)))
	merged["is_unlocked"] = stored_unlock
	merged["rank"] = _rank_from_state(merged)
	if not merged.has("last_visit_day"):
		merged["last_visit_day"] = -1
	if _supports_nursery_projects(habitat):
		merged["nursery_state"] = _normalize_nursery_state(merged.get("nursery_state", {}))
	return merged

func _build_default_habitat_state(habitat_id: String, habitat: Dictionary) -> Dictionary:
	var state := {
		"rank": 0,
		"last_visit_day": -1,
		"is_unlocked": _default_unlock_state(habitat_id, habitat),
		"building_runtime_states": {},
	}
	if _uses_resident_slots(habitat):
		state["resident_uid"] = ""
		state["assistant_uid"] = ""
		state["resident_actor_type"] = ""
		state["resident_actor_id"] = ""
	var building_ids: Array = habitat.get("buildings", [])
	if not building_ids.is_empty():
		var levels := {}
		var runtime_states := {}
		for building_id in building_ids:
			var id := String(building_id)
			levels[id] = 0
			runtime_states[id] = _normalize_building_runtime_state({})
		state["building_runtime_states"] = runtime_states
		if _uses_service_levels(habitat):
			state["service_levels"] = levels
		else:
			state["building_levels"] = levels
	if _supports_nursery_projects(habitat):
		state["nursery_state"] = _default_nursery_state()
	return state

func _supports_nursery_projects(habitat: Dictionary) -> bool:
	return Array(habitat.get("buildings", [])).has(NURSERY_PRIMARY_BUILDING_ID)

func _default_nursery_state() -> Dictionary:
	return {
		"active_project": {},
		"history": [],
		"last_hatch_turn": -1,
	}

func _normalize_nursery_state(value: Variant) -> Dictionary:
	var normalized := _default_nursery_state()
	var raw := _duplicate_dictionary(value)
	normalized["active_project"] = _normalize_nursery_project(raw.get("active_project", {}))
	normalized["history"] = _coerce_string_array(raw.get("history", []))
	normalized["last_hatch_turn"] = int(raw.get("last_hatch_turn", -1))
	return normalized

func _normalize_nursery_project(value: Variant) -> Dictionary:
	var raw := _duplicate_dictionary(value)
	if raw.is_empty():
		return {}
	var actions := _coerce_string_array(raw.get("preferred_actions", []))
	if actions.is_empty():
		actions = ["observe", "calm", "feed"]
	var current_need := String(raw.get("current_need_action", actions[0]))
	if current_need.is_empty() or not actions.has(current_need):
		current_need = String(actions[0])
	return {
		"species_id": String(raw.get("species_id", "")),
		"progress": maxi(0, int(raw.get("progress", 0))),
		"required_progress": maxi(1, int(raw.get("required_progress", 5))),
		"care_points": maxi(0, int(raw.get("care_points", 0))),
		"preferred_actions": actions,
		"current_need_action": current_need,
		"started_turn": int(raw.get("started_turn", global_turn)),
		"last_care_turn": int(raw.get("last_care_turn", -1)),
		"ready_to_hatch": bool(raw.get("ready_to_hatch", false)),
	}

func _normalize_habitats_state() -> void:
	var normalized := {}
	for habitat_id in DataRepository.habitats.keys():
		var habitat := DataRepository.get_habitat(habitat_id)
		var state: Dictionary = _duplicate_dictionary(habitats.get(habitat_id, {}))
		if state.is_empty():
			normalized[habitat_id] = _build_default_habitat_state(habitat_id, habitat)
			continue
		normalized[habitat_id] = _merge_habitat_state(state, habitat_id, habitat)
	habitats = normalized

func _default_unlock_state(habitat_id: String, habitat: Dictionary) -> bool:
	if habitat_id in ["mist_moss_cave", "crystal_creek", "sky_post", "ancient_platform", "copper_hammer_bazaar"]:
		return true
	if habitat.has("unlock_rule_id"):
		return false
	if not Array(habitat.get("season_availability", [])).is_empty():
		return false
	var unlock_rule: Dictionary = habitat.get("unlock_rule", {})
	return String(unlock_rule.get("type", "default")) == "default"

func _uses_resident_slots(habitat: Dictionary) -> bool:
	return int(habitat.get("resident_slots", 0)) > 0 or String(habitat.get("type", "")) == "habitat"

func _uses_service_levels(habitat: Dictionary) -> bool:
	return String(habitat.get("type", "")) == "settlement"

func _rank_from_state(habitat_state: Dictionary) -> int:
	var levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
	var total := 0
	for value in levels.values():
		total += int(value)
	return total

func _default_building_runtime_state() -> Dictionary:
	return {
		"cooldowns": {},
		"stored_output": {},
		"visit_flags": {},
		"weekly_flags": {},
		"last_used_turn": -1,
		"last_action_id": "",
		"tenant_npc_ids": [],
		"damage_days": 0,
		"incident_kind": "",
		"incident_note": "",
		"incident_cost": {},
		"last_income_turn": -1,
		"last_incident_turn": -1,
		"last_move_in_turn": -1,
		"last_social_turn": -1,
	}

func _normalize_building_runtime_state(raw_state: Dictionary) -> Dictionary:
	var defaults := _default_building_runtime_state()
	var normalized: Dictionary = defaults.duplicate(true)
	for key in raw_state.keys():
		normalized[String(key)] = raw_state[key]
	normalized["cooldowns"] = _duplicate_dictionary(normalized.get("cooldowns", {}))
	normalized["stored_output"] = _duplicate_dictionary(normalized.get("stored_output", {}))
	normalized["visit_flags"] = _duplicate_dictionary(normalized.get("visit_flags", {}))
	normalized["weekly_flags"] = _duplicate_dictionary(normalized.get("weekly_flags", {}))
	normalized["tenant_npc_ids"] = _coerce_string_array(normalized.get("tenant_npc_ids", []))
	normalized["damage_days"] = maxi(0, int(normalized.get("damage_days", 0)))
	normalized["incident_kind"] = String(normalized.get("incident_kind", ""))
	normalized["incident_note"] = String(normalized.get("incident_note", ""))
	normalized["incident_cost"] = _duplicate_dictionary(normalized.get("incident_cost", {}))
	normalized["last_income_turn"] = int(normalized.get("last_income_turn", -1))
	normalized["last_incident_turn"] = int(normalized.get("last_incident_turn", -1))
	normalized["last_move_in_turn"] = int(normalized.get("last_move_in_turn", -1))
	normalized["last_social_turn"] = int(normalized.get("last_social_turn", -1))
	return normalized

func _seed_companions() -> void:
	add_companion("steam_otter_1", "汐牙")
	add_companion("moss_deer_1", "苔角")
	add_companion("spark_mouse_1", "火花")

func add_companion(species_id: String, nickname: String = "", extra_state: Dictionary = {}) -> String:
	var profile := DataRepository.get_species(species_id)
	var uid := "pet_%03d" % _pet_serial
	_pet_serial += 1
	var display_name := nickname if not nickname.is_empty() else String(profile.get("name", species_id))
	var pet_state := {
		"uid": uid,
		"species_id": species_id,
		"display_name": display_name,
		"nickname_locked": not nickname.is_empty(),
		"bond_level": 1,
		"star_level": 1,
		"residence_habitat_id": "",
		"temperament": String(profile.get("temperament", "")),
		"known_skill_ids": _build_initial_pet_skill_ids(species_id),
		"pending_skill_id": "",
		"pending_skill_context": {},
		"resident_tags": profile.get("resident_tags", []).duplicate(),
	}
	for key in extra_state.keys():
		if String(key) == "uid":
			continue
		pet_state[key] = extra_state[key]
	pet_state = _normalize_pet_state(pet_state)
	pet_states[uid] = pet_state
	register_species_seen(species_id)
	add_journal_entry("新伙伴加入照料名册：%s。" % display_name)
	_sync_roster_slots()
	return uid

func get_companions() -> Array:
	var result: Array = []
	for pet_uid in pet_states.keys():
		result.append(get_pet(String(pet_uid)))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("uid", "")) < String(b.get("uid", ""))
	)
	return result

func get_pet(pet_uid: String) -> Dictionary:
	if not pet_states.has(pet_uid):
		return {}
	var normalized := _normalize_pet_state(Dictionary(pet_states.get(pet_uid, {})).duplicate(true))
	pet_states[pet_uid] = normalized
	return normalized

func get_pet_skill_ids(pet_uid: String) -> Array[String]:
	return _coerce_string_array(get_pet(pet_uid).get("known_skill_ids", []))

func get_pet_pending_skill_id(pet_uid: String) -> String:
	return String(get_pet(pet_uid).get("pending_skill_id", ""))

func pet_has_pending_skill(pet_uid: String) -> bool:
	return not get_pet_pending_skill_id(pet_uid).is_empty()

func discard_pet_pending_skill(pet_uid: String) -> bool:
	if not pet_states.has(pet_uid):
		return false
	var pet := get_pet(pet_uid)
	if String(pet.get("pending_skill_id", "")).is_empty():
		return false
	pet["pending_skill_id"] = ""
	pet["pending_skill_context"] = {}
	pet_states[pet_uid] = pet
	return true

func replace_pet_skill_with_pending(pet_uid: String, forget_skill_id: String) -> Dictionary:
	if not pet_states.has(pet_uid):
		return {"ok": false, "reason": "pet_missing", "pet_uid": pet_uid}
	var pet := get_pet(pet_uid)
	var pending_skill_id := String(pet.get("pending_skill_id", ""))
	if pending_skill_id.is_empty():
		return {"ok": false, "reason": "no_pending_skill", "pet_uid": pet_uid}
	var skill_ids := _coerce_string_array(pet.get("known_skill_ids", []))
	var forget_index := skill_ids.find(forget_skill_id)
	if forget_index == -1:
		return {"ok": false, "reason": "skill_not_known", "pet_uid": pet_uid, "forget_skill_id": forget_skill_id}
	skill_ids[forget_index] = pending_skill_id
	pet["known_skill_ids"] = _prune_pet_skill_ids(skill_ids, String(pet.get("species_id", "")))
	pet["pending_skill_id"] = ""
	pet["pending_skill_context"] = {}
	pet_states[pet_uid] = pet
	return {
		"ok": true,
		"pet_uid": pet_uid,
		"forgot_skill_id": forget_skill_id,
		"learned_skill_id": pending_skill_id,
		"known_skill_ids": get_pet_skill_ids(pet_uid),
	}

func _normalize_pet_states() -> void:
	var normalized := {}
	for pet_uid in pet_states.keys():
		var pet: Dictionary = Dictionary(pet_states[pet_uid]).duplicate(true)
		normalized[String(pet_uid)] = _normalize_pet_state(pet)
	pet_states = normalized

func _normalize_pet_state(pet: Dictionary) -> Dictionary:
	if pet.is_empty():
		return {}
	var species_id := String(pet.get("species_id", ""))
	var default_skill_ids := _build_initial_pet_skill_ids(species_id)
	var known_skill_ids := _coerce_string_array(pet.get("known_skill_ids", pet.get("skills", default_skill_ids)))
	if known_skill_ids.is_empty():
		known_skill_ids = default_skill_ids
	pet["known_skill_ids"] = _prune_pet_skill_ids(known_skill_ids, species_id)
	var pending_skill_id := String(pet.get("pending_skill_id", pet.get("pending_skill", "")))
	if pending_skill_id.is_empty() \
	or DataRepository.get_skill(pending_skill_id).is_empty() \
	or Array(pet.get("known_skill_ids", [])).has(pending_skill_id):
		pending_skill_id = ""
	pet["pending_skill_id"] = pending_skill_id
	pet["pending_skill_context"] = _duplicate_dictionary(pet.get("pending_skill_context", {}))
	pet.erase("pending_skill")
	pet["bond_level"] = maxi(1, int(pet.get("bond_level", 1)))
	pet["star_level"] = clampi(int(pet.get("star_level", 1)), 1, 3)
	return pet

func _build_initial_pet_skill_ids(species_id: String) -> Array[String]:
	var known_skill_ids: Array[String] = []
	var capacity := _max_skill_slots_for_species(species_id)
	var starting_count := mini(DataRepository.get_pet_starting_skill_count(species_id), capacity)
	for skill_id in DataRepository.get_pet_species_skill_ids(species_id):
		if DataRepository.get_skill(skill_id).is_empty():
			continue
		if known_skill_ids.has(skill_id):
			continue
		known_skill_ids.append(skill_id)
		if known_skill_ids.size() >= starting_count:
			break
	return known_skill_ids

func _prune_pet_skill_ids(raw_skill_ids: Array[String], species_id: String) -> Array[String]:
	var result: Array[String] = []
	var capacity := _max_skill_slots_for_species(species_id)
	for skill_id in raw_skill_ids:
		if skill_id.is_empty() or result.has(skill_id):
			continue
		if DataRepository.get_skill(skill_id).is_empty():
			continue
		result.append(skill_id)
		if result.size() >= capacity:
			break
	return result

func _max_skill_slots_for_species(species_id: String) -> int:
	return mini(MAX_PET_SKILL_SLOTS, DataRepository.get_pet_skill_capacity(species_id))

func _resolve_pet_stage_growth_events(pet_uid: String, stage: int = -1) -> Dictionary:
	if not pet_states.has(pet_uid):
		return {}
	var pet := get_pet(pet_uid)
	var current_stage := stage if stage > 0 else int(pet.get("star_level", 1))
	var applied_events: Array = []
	var learned_skill_ids: Array[String] = []
	var pending_skill_id := ""
	var evolved_to := ""
	for raw_event in DataRepository.get_pet_stage_events(String(pet.get("species_id", "")), current_stage):
		var event: Dictionary = Dictionary(raw_event).duplicate(true)
		var event_type := String(event.get("type", ""))
		if event_type.is_empty():
			continue
		var event_report := _apply_pet_growth_event(pet, event, current_stage)
		if event_report.is_empty():
			continue
		applied_events.append(event_report)
		if event_report.has("learned_skill_id"):
			learned_skill_ids.append(String(event_report.get("learned_skill_id", "")))
		if not String(event_report.get("pending_skill_id", "")).is_empty():
			pending_skill_id = String(event_report.get("pending_skill_id", ""))
		if not String(event_report.get("evolved_to", "")).is_empty():
			evolved_to = String(event_report.get("evolved_to", ""))
		if not String(pet.get("pending_skill_id", "")).is_empty():
			break
	pet_states[pet_uid] = _normalize_pet_state(pet)
	return {
		"pet_uid": pet_uid,
		"stage": current_stage,
		"species_id": String(pet.get("species_id", "")),
		"applied_events": applied_events,
		"learned_skill_ids": learned_skill_ids,
		"pending_skill_id": pending_skill_id,
		"evolved_to": evolved_to,
	}

func _apply_pet_growth_event(pet: Dictionary, event: Dictionary, stage: int) -> Dictionary:
	var event_type := String(event.get("type", ""))
	match event_type:
		"learn_species_skill", "learn_skill":
			var skill_id := _resolve_growth_event_skill_id(pet, event)
			if skill_id.is_empty():
				return {}
			var learn_result := _try_pet_learn_skill(pet, skill_id, {
				"stage": stage,
				"event_type": event_type,
				"species_id": String(pet.get("species_id", "")),
			})
			if String(learn_result.get("status", "")) == "already_known":
				return {}
			return learn_result
		"evolve_to":
			var target_species_id := String(event.get("target_species_id", ""))
			if target_species_id.is_empty() or DataRepository.get_species(target_species_id).is_empty():
				return {}
			if target_species_id == String(pet.get("species_id", "")):
				return {}
			pet["species_id"] = target_species_id
			pet["known_skill_ids"] = _prune_pet_skill_ids(_coerce_string_array(pet.get("known_skill_ids", [])), target_species_id)
			if not bool(pet.get("nickname_locked", false)):
				pet["display_name"] = String(DataRepository.get_species(target_species_id).get("name", pet.get("display_name", target_species_id)))
			return {
				"status": "evolved",
				"event_type": event_type,
				"evolved_to": target_species_id,
			}
		_:
			return {}

func _resolve_growth_event_skill_id(pet: Dictionary, event: Dictionary) -> String:
	if String(event.get("type", "")) == "learn_skill":
		return String(event.get("skill_id", ""))
	var skill_slot := int(event.get("skill_slot", 0))
	if skill_slot <= 0:
		return ""
	var skill_pool := DataRepository.get_pet_species_skill_ids(String(pet.get("species_id", "")))
	var index := skill_slot - 1
	if index < 0 or index >= skill_pool.size():
		return ""
	return String(skill_pool[index])

func _try_pet_learn_skill(pet: Dictionary, skill_id: String, pending_context: Dictionary = {}) -> Dictionary:
	if skill_id.is_empty() or DataRepository.get_skill(skill_id).is_empty():
		return {"status": "invalid_skill", "skill_id": skill_id}
	var known_skill_ids := _coerce_string_array(pet.get("known_skill_ids", []))
	if known_skill_ids.has(skill_id):
		return {"status": "already_known", "skill_id": skill_id}
	var capacity := _max_skill_slots_for_species(String(pet.get("species_id", "")))
	if known_skill_ids.size() < capacity:
		known_skill_ids.append(skill_id)
		pet["known_skill_ids"] = _prune_pet_skill_ids(known_skill_ids, String(pet.get("species_id", "")))
		return {
			"status": "learned",
			"learned_skill_id": skill_id,
			"event_type": String(pending_context.get("event_type", "")),
		}
	pet["pending_skill_id"] = skill_id
	pet["pending_skill_context"] = pending_context.duplicate(true)
	return {
		"status": "pending_replace",
		"pending_skill_id": skill_id,
		"current_skill_ids": known_skill_ids.duplicate(),
		"event_type": String(pending_context.get("event_type", "")),
	}

func is_player_actor_id(actor_id: String) -> bool:
	return actor_id == PLAYER_ACTOR_ID

func get_player_profile() -> Dictionary:
	return {
		"uid": PLAYER_ACTOR_ID,
		"display_name": PLAYER_ACTOR_NAME,
		"actor_type": "player",
		"resident_tags": ["human", "caretaker", "builder", "watch"],
	}

func get_actor_display_name(actor_id: String) -> String:
	if is_player_actor_id(actor_id):
		return PLAYER_ACTOR_NAME
	return get_pet_display_name(actor_id)

func get_habitat_resident_actor(habitat_id: String) -> Dictionary:
	var habitat_state: Dictionary = habitats.get(habitat_id, {})
	var actor_id := String(habitat_state.get("resident_actor_id", habitat_state.get("resident_uid", "")))
	if actor_id.is_empty():
		return {}
	return get_player_profile() if is_player_actor_id(actor_id) else get_pet(actor_id)

func add_pet_bond(pet_uid: String, amount: int) -> Dictionary:
	if not pet_states.has(pet_uid) or amount == 0:
		return {}
	var pet: Dictionary = pet_states[pet_uid].duplicate(true)
	var old_level := int(pet.get("bond_level", 1))
	pet["bond_level"] = clampi(old_level + amount, 1, 6)
	pet_states[pet_uid] = pet
	return {
		"pet_uid": pet_uid,
		"old_level": old_level,
		"new_level": int(pet.get("bond_level", old_level)),
		"changed": old_level != int(pet.get("bond_level", old_level)),
	}

func set_pet_residence(pet_uid: String, habitat_id: String) -> void:
	if not pet_states.has(pet_uid):
		return
	var pet: Dictionary = pet_states[pet_uid]
	pet["residence_habitat_id"] = habitat_id
	pet_states[pet_uid] = pet

func clear_pet_residence(pet_uid: String) -> void:
	set_pet_residence(pet_uid, "")

func get_pet_display_name(pet_uid: String) -> String:
	return String(get_pet(pet_uid).get("display_name", "未命名伙伴"))

func get_building_level(habitat_id: String, building_id: String) -> int:
	var habitat_state: Dictionary = habitats.get(habitat_id, {})
	var building_levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
	return int(building_levels.get(building_id, 0))

func set_building_level(habitat_id: String, building_id: String, level: int) -> void:
	if not habitats.has(habitat_id):
		return
	var habitat_state: Dictionary = habitats[habitat_id]
	var building_levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
	building_levels[building_id] = level
	if habitat_state.has("building_levels"):
		habitat_state["building_levels"] = building_levels
	else:
		habitat_state["service_levels"] = building_levels
	var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
	if not runtime_states.has(building_id):
		runtime_states[building_id] = _default_building_runtime_state()
	habitat_state["building_runtime_states"] = runtime_states
	habitat_state["rank"] = _rank_from_state(habitat_state)
	habitats[habitat_id] = habitat_state
	_recalculate_pet_capacity()
	_sync_roster_slots()
	refresh_season_unlocks()

func note_visit(habitat_id: String) -> void:
	var visits: Dictionary = quest_memory["visited_habitats"]
	visits[habitat_id] = int(visits.get(habitat_id, 0)) + 1
	quest_memory["visited_habitats"] = visits
	var visit_moments: Dictionary = quest_memory["visited_moments"]
	visit_moments["%s@%s" % [habitat_id, time_of_day]] = true
	quest_memory["visited_moments"] = visit_moments
	if habitats.has(habitat_id):
		var state: Dictionary = habitats[habitat_id]
		state["last_visit_day"] = day_index
		habitats[habitat_id] = state

func note_build(building_id: String, level: int) -> void:
	var builds: Dictionary = quest_memory["built_levels"]
	builds[building_id] = maxi(int(builds.get(building_id, 0)), level)
	quest_memory["built_levels"] = builds
	refresh_season_unlocks()

func get_building_runtime_state(habitat_id: String, building_id: String) -> Dictionary:
	if not habitats.has(habitat_id):
		return {}
	var habitat_state: Dictionary = habitats[habitat_id]
	var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
	return _normalize_building_runtime_state(Dictionary(runtime_states.get(building_id, {})).duplicate(true))

func ensure_building_runtime_state(habitat_id: String, building_id: String) -> Dictionary:
	if not habitats.has(habitat_id):
		return {}
	var habitat_state: Dictionary = habitats[habitat_id]
	var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
	var runtime_state := _normalize_building_runtime_state(Dictionary(runtime_states.get(building_id, {})).duplicate(true))
	if not runtime_states.has(building_id) or Dictionary(runtime_states.get(building_id, {})).duplicate(true) != runtime_state:
		runtime_states[building_id] = runtime_state
		habitat_state["building_runtime_states"] = runtime_states
		habitats[habitat_id] = habitat_state
	return runtime_state.duplicate(true)

func set_building_runtime_state(habitat_id: String, building_id: String, runtime_state: Dictionary) -> void:
	if not habitats.has(habitat_id):
		return
	var habitat_state: Dictionary = habitats[habitat_id]
	var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
	runtime_states[building_id] = _normalize_building_runtime_state(runtime_state)
	habitat_state["building_runtime_states"] = runtime_states
	habitats[habitat_id] = habitat_state

func is_building_damaged(habitat_id: String, building_id: String) -> bool:
	return int(get_building_runtime_state(habitat_id, building_id).get("damage_days", 0)) > 0

func get_building_repair_cost(habitat_id: String, building_id: String) -> Dictionary:
	var runtime_state := get_building_runtime_state(habitat_id, building_id)
	var configured_cost := _duplicate_dictionary(runtime_state.get("incident_cost", {}))
	if not configured_cost.is_empty():
		return configured_cost
	var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
	if damage_days <= 0:
		return {}
	return _default_damage_repair_cost(building_id, damage_days)

func repair_building_damage(habitat_id: String, building_id: String, consume_cost: bool = true) -> Dictionary:
	var runtime_state := ensure_building_runtime_state(habitat_id, building_id)
	var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
	if damage_days <= 0:
		return {
			"ok": false,
			"reason": "building_not_damaged",
			"habitat_id": habitat_id,
			"building_id": building_id,
		}
	var repair_cost := get_building_repair_cost(habitat_id, building_id)
	if consume_cost and not repair_cost.is_empty() and not can_pay(repair_cost):
		return {
			"ok": false,
			"reason": "insufficient_items",
			"habitat_id": habitat_id,
			"building_id": building_id,
			"cost": repair_cost,
		}
	if consume_cost and not repair_cost.is_empty() and not pay_cost(repair_cost):
		return {
			"ok": false,
			"reason": "payment_failed",
			"habitat_id": habitat_id,
			"building_id": building_id,
			"cost": repair_cost,
		}
	runtime_state["damage_days"] = 0
	runtime_state["incident_kind"] = ""
	runtime_state["incident_note"] = ""
	runtime_state["incident_cost"] = {}
	set_building_runtime_state(habitat_id, building_id, runtime_state)
	add_journal_entry("%s 的 %s 修缮完毕。" % [_habitat_name(habitat_id), String(DataRepository.get_building(building_id).get("name", building_id))])
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"building_id": building_id,
		"cost": repair_cost,
		"repaired_damage_days": damage_days,
	}

func get_apartment_status(habitat_id: String, building_id: String = "settlement_apartment") -> Dictionary:
	var level := get_building_level(habitat_id, building_id)
	var building := DataRepository.get_building(building_id)
	if level <= 0 or not _is_apartment_building(building):
		return {}
	var runtime_state := get_building_runtime_state(habitat_id, building_id)
	var apartment_config := _get_apartment_config(building_id, level)
	var tenant_names: Array[String] = []
	for npc_id in _coerce_string_array(runtime_state.get("tenant_npc_ids", [])):
		var npc := DataRepository.get_npc(npc_id)
		if npc.is_empty():
			continue
		tenant_names.append(String(npc.get("name", npc_id)))
	return {
		"building_id": building_id,
		"level": level,
		"tenant_ids": _coerce_string_array(runtime_state.get("tenant_npc_ids", [])),
		"tenant_names": tenant_names,
		"tenant_count": tenant_names.size(),
		"tenant_capacity": maxi(0, int(apartment_config.get("tenant_capacity", 0))),
		"damage_days": maxi(0, int(runtime_state.get("damage_days", 0))),
		"incident_kind": String(runtime_state.get("incident_kind", "")),
		"incident_note": String(runtime_state.get("incident_note", "")),
		"repair_cost": get_building_repair_cost(habitat_id, building_id),
		"rent_interval_days": maxi(1, int(apartment_config.get("rent_interval_days", 1))),
		"last_income_turn": int(runtime_state.get("last_income_turn", -1)),
		"last_incident_turn": int(runtime_state.get("last_incident_turn", -1)),
		"last_social_turn": int(runtime_state.get("last_social_turn", -1)),
	}

func get_nursery_state(habitat_id: String) -> Dictionary:
	if not habitats.has(habitat_id):
		return _default_nursery_state()
	var habitat_state: Dictionary = habitats[habitat_id]
	if not habitat_state.has("nursery_state"):
		return _default_nursery_state()
	return _normalize_nursery_state(habitat_state.get("nursery_state", {}))

func get_nursery_project(habitat_id: String) -> Dictionary:
	return Dictionary(get_nursery_state(habitat_id).get("active_project", {})).duplicate(true)

func set_nursery_state(habitat_id: String, nursery_state: Dictionary) -> void:
	if not habitats.has(habitat_id):
		return
	var habitat_state: Dictionary = habitats[habitat_id]
	habitat_state["nursery_state"] = _normalize_nursery_state(nursery_state)
	habitats[habitat_id] = habitat_state

func set_nursery_project(habitat_id: String, project: Dictionary) -> void:
	var nursery_state := get_nursery_state(habitat_id)
	nursery_state["active_project"] = _normalize_nursery_project(project)
	set_nursery_state(habitat_id, nursery_state)

func get_nursery_access_report(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return {"ok": false, "reason": "habitat_missing", "habitat_id": habitat_id}
	if not _supports_nursery_projects(habitat):
		return {"ok": false, "reason": "nursery_missing", "habitat_id": habitat_id}
	var primary_level := get_building_level(habitat_id, NURSERY_PRIMARY_BUILDING_ID)
	var support_level := get_building_level(habitat_id, NURSERY_SUPPORT_BUILDING_ID)
	if primary_level <= 0 and support_level < 3:
		return {
			"ok": false,
			"reason": "nursery_locked",
			"habitat_id": habitat_id,
			"primary_level": primary_level,
			"support_level": support_level,
		}
	var resident := get_habitat_resident_actor(habitat_id)
	if resident.is_empty():
		return {
			"ok": false,
			"reason": "resident_required",
			"habitat_id": habitat_id,
			"primary_level": primary_level,
			"support_level": support_level,
		}
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"primary_level": primary_level,
		"support_level": support_level,
		"resident": resident,
	}

func get_nursery_candidate_species(habitat_id: String) -> Array[String]:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return []
	var encounter_flags: Dictionary = _duplicate_dictionary(quest_memory.get("encounter_species", {}))
	var observe_flags: Dictionary = _duplicate_dictionary(quest_memory.get("observed_species", {}))
	var bond_flags: Dictionary = _duplicate_dictionary(quest_memory.get("bonded_species", {}))
	var result: Array[String] = []
	for raw_species_id in habitat.get("wild_pool", []):
		var species_id := String(raw_species_id)
		if species_id.is_empty():
			continue
		if not encounter_flags.has(species_id) and not observe_flags.has(species_id) and not bond_flags.has(species_id):
			continue
		result.append(species_id)
	return result

func start_nursery_project(habitat_id: String, species_id: String) -> Dictionary:
	var access := get_nursery_access_report(habitat_id)
	if not bool(access.get("ok", false)):
		return access
	var project := get_nursery_project(habitat_id)
	if not project.is_empty():
		return {"ok": false, "reason": "incubation_active", "habitat_id": habitat_id, "project": project}
	if not get_nursery_candidate_species(habitat_id).has(species_id):
		return {"ok": false, "reason": "species_not_recorded", "habitat_id": habitat_id, "species_id": species_id}
	var species := DataRepository.get_species(species_id)
	if species.is_empty():
		return {"ok": false, "reason": "species_missing", "habitat_id": habitat_id, "species_id": species_id}
	var actions := _coerce_string_array(species.get("care_actions", []))
	if actions.is_empty():
		actions = ["observe", "calm", "feed"]
	var next_project := {
		"species_id": species_id,
		"progress": 0,
		"required_progress": _nursery_required_progress_for_species(species_id),
		"care_points": 0,
		"preferred_actions": actions,
		"current_need_action": String(actions[0]),
		"started_turn": global_turn,
		"last_care_turn": -1,
		"ready_to_hatch": false,
	}
	set_nursery_project(habitat_id, next_project)
	add_journal_entry("%s 的孵育记录已经在 %s 建档。" % [String(species.get("name", species_id)), String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))])
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"species_id": species_id,
		"project": get_nursery_project(habitat_id),
	}

func care_nursery_project(habitat_id: String, action_id: String) -> Dictionary:
	var access := get_nursery_access_report(habitat_id)
	if not bool(access.get("ok", false)):
		return access
	var project := get_nursery_project(habitat_id)
	if project.is_empty():
		return {"ok": false, "reason": "no_incubation", "habitat_id": habitat_id}
	if bool(project.get("ready_to_hatch", false)):
		return {"ok": false, "reason": "incubation_ready", "habitat_id": habitat_id, "project": project}
	var actions := _coerce_string_array(project.get("preferred_actions", []))
	if not actions.has(action_id):
		return {"ok": false, "reason": "invalid_care_action", "habitat_id": habitat_id, "action_id": action_id, "project": project}
	if int(project.get("last_care_turn", -1)) == global_turn:
		return {"ok": false, "reason": "care_already_done", "habitat_id": habitat_id, "project": project}
	var progress_delta := 2 if String(project.get("current_need_action", "")) == action_id else 1
	if get_building_level(habitat_id, NURSERY_PRIMARY_BUILDING_ID) >= 2 and String(project.get("current_need_action", "")) == action_id:
		progress_delta += 1
	project["progress"] = int(project.get("progress", 0)) + progress_delta
	project["care_points"] = int(project.get("care_points", 0)) + progress_delta
	project["last_care_turn"] = global_turn
	project["current_need_action"] = _next_nursery_need_action(actions, action_id)
	var hatched_ready := _finalize_nursery_progress(habitat_id, project)
	if hatched_ready:
		project = get_nursery_project(habitat_id)
	var resident := get_habitat_resident_actor(habitat_id)
	if not resident.is_empty() and not is_player_actor_id(String(resident.get("uid", ""))) and progress_delta >= 2:
		add_pet_bond(String(resident.get("uid", "")), 1)
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"action_id": action_id,
		"progress_delta": progress_delta,
		"project": get_nursery_project(habitat_id),
		"ready_to_hatch": hatched_ready,
	}

func hatch_nursery_project(habitat_id: String) -> Dictionary:
	var access := get_nursery_access_report(habitat_id)
	if not bool(access.get("ok", false)):
		return access
	var nursery_state := get_nursery_state(habitat_id)
	var project: Dictionary = nursery_state.get("active_project", {})
	if project.is_empty():
		return {"ok": false, "reason": "no_incubation", "habitat_id": habitat_id}
	if not bool(project.get("ready_to_hatch", false)):
		return {"ok": false, "reason": "incubation_not_ready", "habitat_id": habitat_id, "project": project}
	var species_id := String(project.get("species_id", ""))
	var species := DataRepository.get_species(species_id)
	var starting_bond := 2 if int(project.get("care_points", 0)) >= int(project.get("required_progress", 1)) else 1
	var pet_uid := add_companion(species_id, "", {
		"bond_level": starting_bond,
		"hatched_from_habitat_id": habitat_id,
		"origin": "nursery",
	})
	nursery_state["active_project"] = {}
	var history := _coerce_string_array(nursery_state.get("history", []))
	history.append(species_id)
	while history.size() > 6:
		history.pop_front()
	nursery_state["history"] = history
	nursery_state["last_hatch_turn"] = global_turn
	set_nursery_state(habitat_id, nursery_state)
	var resident := get_habitat_resident_actor(habitat_id)
	if not resident.is_empty() and not is_player_actor_id(String(resident.get("uid", ""))):
		add_pet_bond(String(resident.get("uid", "")), 1)
	add_journal_entry("%s 在 %s 完成了破壳。" % [String(species.get("name", species_id)), String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))])
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"species_id": species_id,
		"pet_uid": pet_uid,
		"pet": get_pet(pet_uid),
		"starting_bond": starting_bond,
	}

func _nursery_required_progress_for_species(species_id: String) -> int:
	var rarity := String(DataRepository.get_species(species_id).get("rarity", "common"))
	match rarity:
		"uncommon":
			return 6
		"rare":
			return 8
		"epic":
			return 10
		"legendary":
			return 12
		_:
			return 5

func _next_nursery_need_action(actions: Array[String], current_action: String) -> String:
	if actions.is_empty():
		return "observe"
	var index := actions.find(current_action)
	if index == -1:
		return String(actions[0])
	return String(actions[(index + 1) % actions.size()])

func _tick_nursery_projects() -> Array[String]:
	var lines: Array[String] = []
	for habitat_id in habitats.keys():
		var habitat_state: Dictionary = habitats[habitat_id]
		if not habitat_state.has("nursery_state"):
			continue
		var nursery_state := _normalize_nursery_state(habitat_state.get("nursery_state", {}))
		var project: Dictionary = nursery_state.get("active_project", {})
		if project.is_empty() or bool(project.get("ready_to_hatch", false)):
			continue
		var progress_delta := _passive_nursery_progress(habitat_id)
		if progress_delta <= 0:
			continue
		project["progress"] = int(project.get("progress", 0)) + progress_delta
		var actions := _coerce_string_array(project.get("preferred_actions", []))
		project["current_need_action"] = _next_nursery_need_action(actions, String(project.get("current_need_action", "")))
		nursery_state["active_project"] = project
		habitat_state["nursery_state"] = nursery_state
		habitats[habitat_id] = habitat_state
		if _finalize_nursery_progress(habitat_id, project):
			var species_id := String(project.get("species_id", ""))
			lines.append("%s 的 %s 已经能听见壳内回应，随时可以迎接破壳。" % [
				String(DataRepository.get_habitat(habitat_id).get("name", habitat_id)),
				String(DataRepository.get_species(species_id).get("name", species_id)),
			])
	return lines

func _passive_nursery_progress(habitat_id: String) -> int:
	var project := get_nursery_project(habitat_id)
	if project.is_empty():
		return 0
	var delta := 1
	if not get_habitat_resident_actor(habitat_id).is_empty():
		delta += 1
	if get_building_level(habitat_id, NURSERY_PRIMARY_BUILDING_ID) >= 2 or get_building_level(habitat_id, NURSERY_SUPPORT_BUILDING_ID) >= 3:
		delta += 1
	if season_id == "spring":
		delta += 1
	return delta

func _finalize_nursery_progress(habitat_id: String, project: Dictionary) -> bool:
	var normalized := _normalize_nursery_project(project)
	var ready := int(normalized.get("progress", 0)) >= int(normalized.get("required_progress", 1))
	normalized["ready_to_hatch"] = ready
	set_nursery_project(habitat_id, normalized)
	return ready

func consume_next_observation_source(habitat_id: String) -> String:
	if not habitats.has(habitat_id):
		return "observe"
	var habitat_state: Dictionary = habitats[habitat_id]
	var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
	for building_id in runtime_states.keys():
		var runtime_state: Dictionary = Dictionary(runtime_states[building_id]).duplicate(true)
		var visit_flags: Dictionary = runtime_state.get("visit_flags", {})
		var source := String(visit_flags.get("next_observation_source", ""))
		if source.is_empty():
			continue
		visit_flags.erase("next_observation_source")
		runtime_state["visit_flags"] = visit_flags
		runtime_states[building_id] = runtime_state
		habitat_state["building_runtime_states"] = runtime_states
		habitats[habitat_id] = habitat_state
		return source
	return "observe"

func _tick_building_runtime_states() -> Array[String]:
	var lines: Array[String] = []
	for habitat_id in habitats.keys():
		var habitat_state: Dictionary = habitats[habitat_id]
		var runtime_states: Dictionary = habitat_state.get("building_runtime_states", {})
		if runtime_states.is_empty():
			continue
		var dirty := false
		for building_id in runtime_states.keys():
			var runtime_state := _normalize_building_runtime_state(Dictionary(runtime_states[building_id]).duplicate(true))
			var cooldowns: Dictionary = Dictionary(runtime_state.get("cooldowns", {})).duplicate(true)
			var updated_cooldowns := {}
			for action_id in cooldowns.keys():
				var remaining := maxi(0, int(cooldowns[action_id]) - 1)
				if remaining > 0:
					updated_cooldowns[action_id] = remaining
			runtime_state["cooldowns"] = updated_cooldowns
			var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
			if damage_days > 0:
				damage_days -= 1
				runtime_state["damage_days"] = damage_days
				if damage_days <= 0:
					runtime_state["incident_cost"] = {}
					lines.append("%s 的 %s 已经修整妥当，可以照常使用了。" % [
						_habitat_name(String(habitat_id)),
						String(DataRepository.get_building(String(building_id)).get("name", String(building_id))),
					])
			runtime_state["visit_flags"] = {}
			runtime_states[building_id] = runtime_state
			dirty = true
		if dirty:
			habitat_state["building_runtime_states"] = runtime_states
			habitats[habitat_id] = habitat_state
	return lines

func _process_apartment_daily_updates() -> Array[String]:
	var lines: Array[String] = []
	var apartment_id := "settlement_apartment"
	var building := DataRepository.get_building(apartment_id)
	if not _is_apartment_building(building):
		return lines
	var reserved_tenants := {}
	for raw_habitat_id in habitats.keys():
		var habitat_id := String(raw_habitat_id)
		if get_building_level(habitat_id, apartment_id) <= 0:
			continue
		var preview_state := get_building_runtime_state(habitat_id, apartment_id)
		for npc_id in _coerce_string_array(preview_state.get("tenant_npc_ids", [])):
			if npc_id.is_empty() or DataRepository.get_npc(npc_id).is_empty():
				continue
			if not reserved_tenants.has(npc_id):
				reserved_tenants[npc_id] = habitat_id
	var claimed_tenants := {}
	for raw_habitat_id in habitats.keys():
		var habitat_id := String(raw_habitat_id)
		var level := get_building_level(habitat_id, apartment_id)
		if level <= 0:
			continue
		var runtime_state := ensure_building_runtime_state(habitat_id, apartment_id)
		var apartment_config := _get_apartment_config(apartment_id, level)
		var tenant_capacity := maxi(0, int(apartment_config.get("tenant_capacity", 0)))
		var tenant_ids: Array[String] = []
		for npc_id in _coerce_string_array(runtime_state.get("tenant_npc_ids", [])):
			if npc_id.is_empty() or tenant_ids.has(npc_id) or claimed_tenants.has(npc_id):
				continue
			if DataRepository.get_npc(npc_id).is_empty():
				continue
			tenant_ids.append(npc_id)
			claimed_tenants[npc_id] = habitat_id
			if tenant_ids.size() >= tenant_capacity:
				break
		runtime_state["tenant_npc_ids"] = tenant_ids.duplicate()

		var damage_days := maxi(0, int(runtime_state.get("damage_days", 0)))
		var rent_interval := maxi(1, int(apartment_config.get("rent_interval_days", 1)))
		if not tenant_ids.is_empty() and global_turn - int(runtime_state.get("last_income_turn", -1)) >= rent_interval:
			var rent_total := 0
			var rent_names: Array[String] = []
			var gifts := {}
			for npc_id in tenant_ids:
				rent_total += _apartment_rent_for_npc(npc_id, habitat_id, apartment_id, level, damage_days)
				rent_names.append(String(DataRepository.get_npc(npc_id).get("name", npc_id)))
				_merge_item_totals(gifts, _apartment_gift_items_for_npc(npc_id, habitat_id, apartment_id, level))
			if rent_total > 0:
				add_wallet_gold(rent_total)
				lines.append("%s 的旅居公寓结租 %d 金：%s。" % [_habitat_name(habitat_id), rent_total, " / ".join(rent_names)])
			if not gifts.is_empty():
				grant_items(gifts)
				lines.append("%s 的住客顺手留下了 %s。" % [_habitat_name(habitat_id), _format_item_bundle(gifts)])
			runtime_state["last_income_turn"] = global_turn

		damage_days = maxi(0, int(runtime_state.get("damage_days", 0)))
		var repair_interval := maxi(1, int(apartment_config.get("repair_interval_days", 3)))
		if damage_days > 0 and global_turn % repair_interval == 0:
			var repair_rows: Array = []
			for npc_id in tenant_ids:
				var profile := _apartment_profile_for_npc(npc_id)
				var care := int(profile.get("care", 0))
				var trust := int(npc_trust.get(npc_id, 0))
				if care < 2 or trust < 4:
					continue
				repair_rows.append({
					"id": npc_id,
					"npc": DataRepository.get_npc(npc_id),
					"weight": care + trust,
				})
			var repair_choice := _pick_weighted_row(repair_rows, "%s|repair|%d" % [habitat_id, global_turn])
			if not repair_choice.is_empty():
				var repaired_damage := maxi(0, damage_days - 1)
				runtime_state["damage_days"] = repaired_damage
				if repaired_damage <= 0:
					runtime_state["incident_kind"] = ""
					runtime_state["incident_note"] = ""
					runtime_state["incident_cost"] = {}
				lines.append("%s 的住客 %s 顺手把公寓收拾了一遍。" % [
					_habitat_name(habitat_id),
					String(Dictionary(repair_choice.get("npc", {})).get("name", repair_choice.get("id", "住客"))),
				])

		tenant_ids = _coerce_string_array(runtime_state.get("tenant_npc_ids", []))
		var social_gap := 5
		if tenant_ids.size() < tenant_capacity and global_turn - int(runtime_state.get("last_social_turn", -999)) >= social_gap:
			var host_rows := _apartment_story_host_rows(tenant_ids)
			var blocked_tenants: Dictionary = reserved_tenants.duplicate(true)
			var referral_rows := _apartment_candidate_rows(habitat_id, blocked_tenants)
			var host_choice := _pick_weighted_row(host_rows, "%s|tenant_story_host|%d" % [habitat_id, global_turn])
			var referral_choice := _pick_weighted_row(referral_rows, "%s|tenant_story_guest|%d" % [habitat_id, global_turn])
			if not host_choice.is_empty() and not referral_choice.is_empty():
				var host_name := String(Dictionary(host_choice.get("npc", {})).get("name", host_choice.get("id", "住客")))
				var guest_id := String(referral_choice.get("id", ""))
				if not guest_id.is_empty() and not tenant_ids.has(guest_id):
					var guest_name := String(Dictionary(referral_choice.get("npc", {})).get("name", guest_id))
					tenant_ids.append(guest_id)
					claimed_tenants[guest_id] = habitat_id
					reserved_tenants[guest_id] = habitat_id
					runtime_state["tenant_npc_ids"] = tenant_ids.duplicate()
					runtime_state["last_move_in_turn"] = global_turn
					runtime_state["last_social_turn"] = global_turn
					lines.append("%s 的住客 %s 介绍了熟人 %s，空房当晚就住满了一间。" % [
						_habitat_name(habitat_id),
						host_name,
						guest_name,
					])
					add_journal_entry("%s 在 %s 的旅居公寓替你牵线，把 %s 也介绍来住下。" % [host_name, _habitat_name(habitat_id), guest_name])
					note_ambient_event_seen("apartment_referral_move_in", ["apartment", "social", "move_in"], habitat_id)

		var move_in_interval := maxi(1, int(apartment_config.get("move_in_interval_days", 2)))
		if tenant_ids.size() < tenant_capacity and global_turn - int(runtime_state.get("last_move_in_turn", -1)) >= move_in_interval:
			var blocked_tenants: Dictionary = reserved_tenants.duplicate(true)
			var move_in_rows := _apartment_candidate_rows(habitat_id, blocked_tenants)
			var move_in_choice := _pick_weighted_row(move_in_rows, "%s|move_in|%d" % [habitat_id, global_turn])
			if not move_in_choice.is_empty():
				var tenant_id := String(move_in_choice.get("id", ""))
				if not tenant_id.is_empty() and not tenant_ids.has(tenant_id):
					tenant_ids.append(tenant_id)
					claimed_tenants[tenant_id] = habitat_id
					reserved_tenants[tenant_id] = habitat_id
					runtime_state["tenant_npc_ids"] = tenant_ids.duplicate()
					runtime_state["last_move_in_turn"] = global_turn
					var npc_name := String(Dictionary(move_in_choice.get("npc", {})).get("name", tenant_id))
					lines.append("%s 的旅居公寓迎来了新住客：%s。" % [_habitat_name(habitat_id), npc_name])
					add_journal_entry("%s 搬进了 %s 的旅居公寓。" % [npc_name, _habitat_name(habitat_id)])

		var incident_gap := maxi(4, 6 - level)
		if global_turn - int(runtime_state.get("last_incident_turn", -999)) >= incident_gap:
			var grudge_rows := _apartment_grudge_rows(habitat_id)
			var grudge_choice := _pick_weighted_row(grudge_rows, "%s|grudge|%d" % [habitat_id, global_turn])
			if not grudge_choice.is_empty():
				var incident_result := _resolve_apartment_grudge_incident(habitat_id, apartment_id, grudge_choice)
				if not incident_result.is_empty():
					runtime_state["last_incident_turn"] = global_turn
					lines.append(String(incident_result.get("line", "")))
					var apartment_damage_days := int(incident_result.get("apartment_damage_days", -1))
					if apartment_damage_days >= 0:
						runtime_state["damage_days"] = apartment_damage_days
					var apartment_incident_kind := String(incident_result.get("apartment_incident_kind", ""))
					if not apartment_incident_kind.is_empty():
						runtime_state["incident_kind"] = apartment_incident_kind
					if incident_result.has("apartment_incident_note"):
						runtime_state["incident_note"] = String(incident_result.get("apartment_incident_note", ""))
					if incident_result.has("apartment_incident_cost"):
						runtime_state["incident_cost"] = _duplicate_dictionary(incident_result.get("apartment_incident_cost", {}))
					var journal_line := String(incident_result.get("journal", ""))
					if not journal_line.is_empty():
						add_journal_entry(journal_line)

		set_building_runtime_state(habitat_id, apartment_id, runtime_state)
	return lines

func _apartment_candidate_rows(habitat_id: String, claimed_tenants: Dictionary) -> Array:
	var result: Array = []
	for raw_npc in DataRepository.get_habitat_npcs(habitat_id):
		var npc: Dictionary = Dictionary(raw_npc).duplicate(true)
		var npc_id := String(npc.get("id", ""))
		if npc_id.is_empty() or claimed_tenants.has(npc_id):
			continue
		var profile := _apartment_profile_for_npc(npc_id)
		if profile.is_empty() or not has_completed_npc_intro_duel(npc_id):
			continue
		var trust := int(npc_trust.get(npc_id, 0))
		if trust < int(profile.get("move_in_trust", 3)):
			continue
		if not _npc_prefers_settlement(npc, profile, habitat_id):
			continue
		result.append({
			"id": npc_id,
			"npc": npc,
			"profile": profile,
			"weight": maxi(1, trust * 2 + int(profile.get("rent", 1)) + int(profile.get("care", 0)) + (2 if String(npc.get("home", "")) == habitat_id else 0)),
		})
	return result

func _apartment_grudge_rows(habitat_id: String) -> Array:
	var result: Array = []
	for raw_npc in DataRepository.get_habitat_npcs(habitat_id):
		var npc: Dictionary = Dictionary(raw_npc).duplicate(true)
		var npc_id := String(npc.get("id", ""))
		if npc_id.is_empty():
			continue
		var profile := _apartment_profile_for_npc(npc_id)
		var mischief := int(profile.get("mischief", 0))
		if profile.is_empty() or mischief <= 0 or not has_completed_npc_intro_duel(npc_id):
			continue
		var trust := int(npc_trust.get(npc_id, 0))
		if trust > 1:
			continue
		result.append({
			"id": npc_id,
			"npc": npc,
			"profile": profile,
			"weight": maxi(1, mischief * 2 + maxi(0, 2 - trust)),
		})
	return result

func _apartment_story_host_rows(tenant_ids: Array[String]) -> Array:
	var result: Array = []
	for npc_id in tenant_ids:
		var profile := _apartment_profile_for_npc(npc_id)
		if profile.is_empty():
			continue
		var trust := int(npc_trust.get(npc_id, 0))
		var care := int(profile.get("care", 0))
		if trust < 5 or care < 1:
			continue
		result.append({
			"id": npc_id,
			"npc": DataRepository.get_npc(npc_id),
			"profile": profile,
			"weight": maxi(1, trust + care + int(profile.get("rent", 0))),
		})
	return result

func _pick_damage_target_building(habitat_id: String, apartment_id: String, token: String) -> Dictionary:
	var rows: Array = []
	for raw_building in DataRepository.get_buildings_for_habitat(habitat_id):
		var building: Dictionary = Dictionary(raw_building).duplicate(true)
		var building_id := String(building.get("id", ""))
		if building_id.is_empty() or get_building_level(habitat_id, building_id) <= 0:
			continue
		rows.append({
			"id": building_id,
			"building": building,
			"weight": maxi(1, int(get_building_level(habitat_id, building_id)) + (2 if building_id != apartment_id else 1)),
		})
	return _pick_weighted_row(rows, token)

func _resolve_apartment_grudge_incident(habitat_id: String, apartment_id: String, grudge_choice: Dictionary) -> Dictionary:
	var culprit_id := String(grudge_choice.get("id", ""))
	var culprit_name := String(Dictionary(grudge_choice.get("npc", {})).get("name", culprit_id if not culprit_id.is_empty() else "某人"))
	var culprit_profile := Dictionary(grudge_choice.get("profile", {})).duplicate(true)
	var mischief := maxi(1, int(culprit_profile.get("mischief", 1)))
	var trust := int(npc_trust.get(culprit_id, 0))
	var event_options: Array[String] = []
	var theft_bundle := _pick_apartment_theft_bundle(mischief, "%s|nuisance_items|%s|%d" % [habitat_id, culprit_id, global_turn])
	var gold_loss := mini(wallet_gold, maxi(1, mischief + (1 if trust <= 0 else 0)))
	var damage_target := _pick_damage_target_building(habitat_id, apartment_id, "%s|damage_target|%d" % [habitat_id, global_turn])
	if not theft_bundle.is_empty():
		event_options.append("steal_items")
	if gold_loss > 0:
		event_options.append("steal_gold")
	if not damage_target.is_empty():
		event_options.append("damage")
		if mischief >= 2:
			event_options.append("repair_prank")
	if event_options.is_empty():
		return {}

	var kind := String(event_options[int(abs(hash("%s|nuisance_kind|%s|%d" % [habitat_id, culprit_id, global_turn]))) % event_options.size()])
	match kind:
		"steal_items":
			if theft_bundle.is_empty() or not remove_items(theft_bundle):
				return {}
			note_ambient_event_seen("apartment_nuisance_items", ["apartment", "nuisance", "theft"], habitat_id)
			return {
				"line": "%s 趁夜在 %s 顺走了备料：%s。" % [culprit_name, _habitat_name(habitat_id), _format_item_bundle(theft_bundle)],
				"journal": "%s 对你还有怨气，夜里摸走了 %s 的备料。" % [culprit_name, _habitat_name(habitat_id)],
			}
		"steal_gold":
			if not spend_wallet_gold(gold_loss):
				return {}
			note_ambient_event_seen("apartment_nuisance_gold", ["apartment", "nuisance", "gold"], habitat_id)
			return {
				"line": "%s 在 %s 借机掏走了 %d 金的杂项开销。" % [culprit_name, _habitat_name(habitat_id), gold_loss],
				"journal": "%s 把你留在 %s 的零钱顺走了 %d 金。" % [culprit_name, _habitat_name(habitat_id), gold_loss],
			}
		"repair_prank", "damage":
			if damage_target.is_empty():
				return {}
			var target_id := String(damage_target.get("id", ""))
			var target_name := String(Dictionary(damage_target.get("building", {})).get("name", target_id))
			var applied_damage := 1 + mischief + (1 if kind == "repair_prank" else 0)
			var repair_cost := _default_damage_repair_cost(target_id, applied_damage)
			var incident_note := "%s 留下了一堆手尾，想早点修好得补上 %s。" % [culprit_name, _format_item_bundle(repair_cost)]
			_apply_building_damage(habitat_id, target_id, applied_damage, incident_note, kind, repair_cost)
			note_ambient_event_seen("apartment_nuisance_damage", ["apartment", "nuisance", "damage"], habitat_id)
			return {
				"line": "%s 对你心存芥蒂，夜里把 %s 的 %s 折腾坏了。" % [culprit_name, _habitat_name(habitat_id), target_name],
				"journal": "%s 在 %s 留下了人为破坏痕迹，%s 暂时受损。" % [culprit_name, _habitat_name(habitat_id), target_name],
				"apartment_damage_days": maxi(0, int(get_building_runtime_state(habitat_id, apartment_id).get("damage_days", 0))) if target_id == apartment_id else -1,
				"apartment_incident_kind": kind if target_id == apartment_id else "",
				"apartment_incident_note": incident_note if target_id == apartment_id else "",
				"apartment_incident_cost": repair_cost if target_id == apartment_id else {},
			}
		_:
			return {}

func _apply_building_damage(habitat_id: String, building_id: String, damage_days: int, incident_note: String = "", incident_kind: String = "", incident_cost: Dictionary = {}) -> void:
	if damage_days <= 0:
		return
	var runtime_state := ensure_building_runtime_state(habitat_id, building_id)
	runtime_state["damage_days"] = maxi(int(runtime_state.get("damage_days", 0)), damage_days)
	if not incident_kind.is_empty():
		runtime_state["incident_kind"] = incident_kind
	if not incident_note.is_empty():
		runtime_state["incident_note"] = incident_note
	if not incident_cost.is_empty():
		runtime_state["incident_cost"] = _duplicate_dictionary(incident_cost)
	set_building_runtime_state(habitat_id, building_id, runtime_state)

func _apartment_rent_for_npc(npc_id: String, habitat_id: String, building_id: String, building_level: int, damage_days: int) -> int:
	var npc := DataRepository.get_npc(npc_id)
	var profile := _apartment_profile_for_npc(npc_id)
	if npc.is_empty() or profile.is_empty():
		return 0
	var apartment_config := _get_apartment_config(building_id, building_level)
	var rent := maxi(1, int(profile.get("rent", 1)))
	rent += maxi(0, int(floor(float(int(npc_trust.get(npc_id, 0))) / 2.0)))
	rent += maxi(0, int(apartment_config.get("rent_bonus", 0)))
	if String(npc.get("home", "")) == habitat_id:
		rent += 1
	if String(npc.get("role", "")) == "traveler":
		rent += 1
	if damage_days > 0:
		rent = maxi(1, rent - mini(damage_days, rent - 1))
	return rent

func _apartment_gift_items_for_npc(npc_id: String, habitat_id: String, building_id: String, building_level: int) -> Dictionary:
	var profile := _apartment_profile_for_npc(npc_id)
	if profile.is_empty():
		return {}
	if int(npc_trust.get(npc_id, 0)) < int(_get_apartment_config(building_id, building_level).get("gift_threshold", 5)):
		return {}
	var token := "%s|gift|%s|%s|%d" % [habitat_id, building_id, npc_id, global_turn]
	if int(abs(hash(token))) % 3 != 0:
		return {}
	return _duplicate_dictionary(profile.get("gift_items", {}))

func _apartment_profile_for_npc(npc_id: String) -> Dictionary:
	return _duplicate_dictionary(DataRepository.get_npc(npc_id).get("apartment", {}))

func _npc_prefers_settlement(npc: Dictionary, profile: Dictionary, habitat_id: String) -> bool:
	for raw_habitat_id in Array(profile.get("preferred_settlements", [])).duplicate(true):
		if String(raw_habitat_id) == habitat_id:
			return true
	if String(npc.get("home", "")) == habitat_id:
		return true
	for raw_habitat_id in Array(npc.get("route", [])).duplicate(true):
		if String(raw_habitat_id) == habitat_id:
			return true
	return Array(profile.get("preferred_settlements", [])).is_empty()

func _pick_apartment_theft_bundle(mischief: int, token: String) -> Dictionary:
	var rows: Array = []
	for raw_item_id in inventory.keys():
		var item_id := String(raw_item_id)
		var count := int(inventory.get(item_id, 0))
		if item_id.is_empty() or count <= 0:
			continue
		var item := DataRepository.get_item(item_id)
		var item_type := String(item.get("type", ""))
		if item.is_empty() or ["material", "rare_material", "consumable"].find(item_type) == -1:
			continue
		rows.append({
			"id": item_id,
			"count": count,
			"weight": maxi(1, count + (2 if item_type == "material" else 1)),
		})
	var choice := _pick_weighted_row(rows, token)
	var chosen_id := String(choice.get("id", ""))
	if chosen_id.is_empty():
		return {}
	return {
		chosen_id: mini(int(choice.get("count", 1)), 1 + maxi(0, mischief - 1)),
	}

func _default_damage_repair_cost(building_id: String, damage_days: int) -> Dictionary:
	var building := DataRepository.get_building(building_id)
	var category := String(building.get("category", "utility"))
	var cost := {}
	match category:
		"comfort", "service", "housing":
			cost = {"wood": 1, "cloth": 1}
		"workshop", "industry":
			cost = {"wood": 1, "parts": 1}
		"research":
			cost = {"glass": 1, "parts": 1}
		_:
			cost = {"wood": 1, "stone_chip": 1}
	if damage_days >= 3:
		var bonus_item := "parts" if category in ["workshop", "industry", "research"] else "rope"
		cost[bonus_item] = int(cost.get(bonus_item, 0)) + 1
	return cost

func _pick_weighted_row(rows: Array, token: String) -> Dictionary:
	if rows.is_empty():
		return {}
	var total := 0
	var buckets: Array = []
	for raw_row in rows:
		var row: Dictionary = Dictionary(raw_row).duplicate(true)
		var weight := maxi(1, int(row.get("weight", 1)))
		total += weight
		buckets.append({"threshold": total, "row": row})
	var roll := (int(abs(hash(token))) % maxi(1, total)) + 1
	for bucket in buckets:
		if roll <= int(bucket.get("threshold", 0)):
			return Dictionary(bucket.get("row", {})).duplicate(true)
	return Dictionary(rows[0]).duplicate(true)

func _merge_item_totals(target: Dictionary, addition: Dictionary) -> void:
	for item_id in addition.keys():
		target[String(item_id)] = int(target.get(String(item_id), 0)) + int(addition[item_id])

func _format_item_bundle(bundle: Dictionary) -> String:
	var keys: Array[String] = []
	for item_id in bundle.keys():
		keys.append(String(item_id))
	keys.sort()
	var parts: Array[String] = []
	for item_id in keys:
		parts.append("%s ×%d" % [String(DataRepository.get_item(item_id).get("name", item_id)), int(bundle[item_id])])
	return " / ".join(parts)

func _get_building_level_row(building_id: String, level: int) -> Dictionary:
	if level <= 0:
		return {}
	var levels: Array = Array(DataRepository.get_building(building_id).get("levels", [])).duplicate(true)
	if level - 1 < 0 or level - 1 >= levels.size():
		return {}
	return Dictionary(levels[level - 1]).duplicate(true)

func _get_apartment_config(building_id: String, level: int) -> Dictionary:
	return _duplicate_dictionary(_get_building_level_row(building_id, level).get("apartment", {}))

func _is_apartment_building(building: Dictionary) -> bool:
	return bool(building.get("apartment_enabled", false))

func _habitat_name(habitat_id: String) -> String:
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

func note_encounter(species_id: String) -> void:
	var encounters: Dictionary = quest_memory["encounter_species"]
	encounters[species_id] = true
	quest_memory["encounter_species"] = encounters
	register_species_seen(species_id)
	refresh_season_unlocks()

func note_observe(species_id: String) -> void:
	var seen: Dictionary = quest_memory["observed_species"]
	seen[species_id] = true
	quest_memory["observed_species"] = seen
	if not observed_species.has(species_id):
		observed_species.append(species_id)
	register_species_seen(species_id)
	refresh_season_unlocks()

func note_observe_marker(marker_id: String) -> void:
	var markers: Dictionary = quest_memory["observed_markers"]
	markers[marker_id] = true
	quest_memory["observed_markers"] = markers

func note_fishing_catch(habitat_id: String, species_id: String, weight_class: String = "common") -> Dictionary:
	if species_id.is_empty():
		return {}
	var records: Dictionary = _duplicate_dictionary(quest_memory.get("fishing_records", {}))
	var entry: Dictionary = Dictionary(records.get(species_id, {})).duplicate(true)
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["last_habitat_id"] = habitat_id
	entry["last_turn"] = global_turn
	entry["best_weight_class"] = _better_fishing_weight_class(String(entry.get("best_weight_class", "")), weight_class)
	records[species_id] = entry
	quest_memory["fishing_records"] = records
	return entry

func note_aquatic_release(species_id: String) -> void:
	if species_id.is_empty():
		return
	var released: Dictionary = _duplicate_dictionary(quest_memory.get("released_aquatic_species", {}))
	released[species_id] = int(released.get(species_id, 0)) + 1
	quest_memory["released_aquatic_species"] = released

func get_fishing_spot_pressure(habitat_id: String) -> int:
	return int(_duplicate_dictionary(quest_memory.get("fishing_spot_pressure", {})).get(habitat_id, 0))

func add_fishing_spot_pressure(habitat_id: String, amount: int) -> int:
	if habitat_id.is_empty() or amount == 0:
		return get_fishing_spot_pressure(habitat_id)
	var pressure: Dictionary = _duplicate_dictionary(quest_memory.get("fishing_spot_pressure", {}))
	var next_value := clampi(int(pressure.get(habitat_id, 0)) + amount, 0, 6)
	if next_value <= 0:
		pressure.erase(habitat_id)
	else:
		pressure[habitat_id] = next_value
	quest_memory["fishing_spot_pressure"] = pressure
	return next_value

func record_festival_score(festival_id: String, amount: int) -> int:
	if festival_id.is_empty() or amount == 0:
		return int(_duplicate_dictionary(quest_memory.get("festival_scores", {})).get(festival_id, 0))
	var scores: Dictionary = _duplicate_dictionary(quest_memory.get("festival_scores", {}))
	scores[festival_id] = int(scores.get(festival_id, 0)) + amount
	quest_memory["festival_scores"] = scores
	return int(scores.get(festival_id, 0))

func has_seen_fishing_event(event_id: String) -> bool:
	if event_id.is_empty():
		return false
	return _duplicate_dictionary(quest_memory.get("fishing_event_history", {})).has(event_id)

func mark_fishing_event_seen(event_id: String) -> void:
	if event_id.is_empty():
		return
	var history: Dictionary = _duplicate_dictionary(quest_memory.get("fishing_event_history", {}))
	history[event_id] = global_turn
	quest_memory["fishing_event_history"] = history

func get_fishing_record(species_id: String) -> Dictionary:
	if species_id.is_empty():
		return {}
	return Dictionary(_duplicate_dictionary(quest_memory.get("fishing_records", {})).get(species_id, {})).duplicate(true)

func get_total_fishing_catch_count() -> int:
	var total := 0
	for record in _duplicate_dictionary(quest_memory.get("fishing_records", {})).values():
		total += int(Dictionary(record).get("count", 0))
	return total

func get_total_aquatic_release_count() -> int:
	var total := 0
	for count in _duplicate_dictionary(quest_memory.get("released_aquatic_species", {})).values():
		total += int(count)
	return total

func get_festival_score(festival_id: String) -> int:
	if festival_id.is_empty():
		return 0
	return int(_duplicate_dictionary(quest_memory.get("festival_scores", {})).get(festival_id, 0))

func get_all_festival_scores() -> Dictionary:
	return _duplicate_dictionary(quest_memory.get("festival_scores", {}))

func get_fishing_reputation() -> int:
	var total := get_total_fishing_catch_count() + get_total_aquatic_release_count() * 2
	for value in get_all_festival_scores().values():
		total += int(value)
	return total

func _better_fishing_weight_class(current_weight: String, next_weight: String) -> String:
	var order := {
		"common": 0,
		"uncommon": 1,
		"rare": 2,
		"epic": 3,
	}
	if next_weight.is_empty():
		return current_weight
	if current_weight.is_empty():
		return next_weight
	return next_weight if int(order.get(next_weight, 0)) > int(order.get(current_weight, 0)) else current_weight

func has_map_effect_trigger(effect_key: String) -> bool:
	return bool(quest_memory["map_effect_flags"].get(effect_key, false))

func mark_map_effect_trigger(effect_key: String) -> void:
	if effect_key.is_empty():
		return
	var flags: Dictionary = quest_memory["map_effect_flags"]
	flags[effect_key] = true
	quest_memory["map_effect_flags"] = flags

func note_bond(species_id: String) -> void:
	var bonded: Dictionary = quest_memory["bonded_species"]
	bonded[species_id] = true
	quest_memory["bonded_species"] = bonded
	if not bonded_species.has(species_id):
		bonded_species.append(species_id)
	register_species_seen(species_id)

func note_calm(species_id: String) -> void:
	var calmed: Dictionary = quest_memory["calmed_species"]
	calmed[species_id] = true
	quest_memory["calmed_species"] = calmed
	register_species_seen(species_id)

func note_talk(npc_id: String) -> void:
	var talked: Dictionary = quest_memory["talked_npcs"]
	talked[npc_id] = true
	quest_memory["talked_npcs"] = talked

func note_mail(destination: String) -> void:
	var mailed: Dictionary = quest_memory["mailed_destinations"]
	mailed[destination] = true
	quest_memory["mailed_destinations"] = mailed

func note_return(npc_id: String) -> void:
	var returned: Dictionary = quest_memory["returned_npcs"]
	returned[npc_id] = true
	quest_memory["returned_npcs"] = returned

func note_delivery(item_id: String, count: int) -> void:
	var delivered: Dictionary = quest_memory["delivered_items"]
	delivered[item_id] = int(delivered.get(item_id, 0)) + count
	quest_memory["delivered_items"] = delivered

func has_completed_event(event_id: String) -> bool:
	return bool(quest_memory["completed_events"].get(event_id, false))

func mark_event_completed(event_id: String) -> void:
	var completed: Dictionary = quest_memory["completed_events"]
	completed[event_id] = true
	quest_memory["completed_events"] = completed
	var turns: Dictionary = quest_memory["event_last_turn"]
	turns[event_id] = global_turn
	quest_memory["event_last_turn"] = turns

func get_event_last_turn(event_id: String) -> int:
	return int(quest_memory["event_last_turn"].get(event_id, -999))

func note_ambient_event_seen(event_id: String, tags: Array = [], habitat_id: String = "") -> void:
	if event_id.is_empty():
		return
	var history: Array = _duplicate_array(quest_memory.get("recent_ambient_events", []))
	history.append({
		"id": event_id,
		"tags": Array(tags).duplicate(true),
		"habitat_id": habitat_id,
		"turn": global_turn,
	})
	while history.size() > 8:
		history.pop_front()
	quest_memory["recent_ambient_events"] = history

func get_recent_ambient_event_ids(window_size: int = 6, habitat_id: String = "") -> Array:
	var result: Array = []
	var history: Array = _duplicate_array(quest_memory.get("recent_ambient_events", []))
	var start_index := maxi(0, history.size() - window_size)
	for index in range(start_index, history.size()):
		var entry: Dictionary = Dictionary(history[index])
		if not habitat_id.is_empty() and String(entry.get("habitat_id", "")) != habitat_id:
			continue
		var event_id := String(entry.get("id", ""))
		if event_id.is_empty():
			continue
		result.append(event_id)
	return result

func get_recent_ambient_event_tags(window_size: int = 6, habitat_id: String = "") -> Array:
	var result: Array = []
	var history: Array = _duplicate_array(quest_memory.get("recent_ambient_events", []))
	var start_index := maxi(0, history.size() - window_size)
	for index in range(start_index, history.size()):
		var entry: Dictionary = Dictionary(history[index])
		if not habitat_id.is_empty() and String(entry.get("habitat_id", "")) != habitat_id:
			continue
		for raw_tag in Array(entry.get("tags", [])):
			var tag := String(raw_tag)
			if tag.is_empty() or result.has(tag):
				continue
			result.append(tag)
	return result

func unlock_dialogue(dialogue_id: String) -> void:
	var unlocked: Dictionary = quest_memory["unlocked_dialogues"]
	unlocked[dialogue_id] = true
	quest_memory["unlocked_dialogues"] = unlocked

func is_dialogue_unlocked(dialogue_id: String) -> bool:
	return bool(quest_memory["unlocked_dialogues"].get(dialogue_id, false))


func activate_story_arc(arc_id: String) -> void:
	if arc_id.is_empty():
		return
	var active: Dictionary = quest_memory["active_story_arcs"]
	active[arc_id] = true
	quest_memory["active_story_arcs"] = active

func is_story_arc_active(arc_id: String) -> bool:
	return bool(quest_memory["active_story_arcs"].get(arc_id, false))

func complete_story_arc(arc_id: String) -> void:
	if arc_id.is_empty():
		return
	var active: Dictionary = quest_memory["active_story_arcs"]
	active.erase(arc_id)
	quest_memory["active_story_arcs"] = active
	var completed: Dictionary = quest_memory["completed_story_arcs"]
	completed[arc_id] = true
	quest_memory["completed_story_arcs"] = completed

func has_completed_story_arc(arc_id: String) -> bool:
	return bool(quest_memory["completed_story_arcs"].get(arc_id, false))

func set_story_flag(flag_id: String, enabled: bool = true) -> void:
	if flag_id.is_empty():
		return
	var flags: Dictionary = quest_memory["story_flags"]
	flags[flag_id] = enabled
	quest_memory["story_flags"] = flags

func has_story_flag(flag_id: String) -> bool:
	return bool(quest_memory["story_flags"].get(flag_id, false))

func mark_story_beat_seen(arc_id: String, beat_id: String) -> void:
	if arc_id.is_empty() or beat_id.is_empty():
		return
	var history: Dictionary = quest_memory["story_beat_history"]
	history["%s:%s" % [arc_id, beat_id]] = true
	quest_memory["story_beat_history"] = history

func has_story_beat_seen(arc_id: String, beat_id: String) -> bool:
	return bool(quest_memory["story_beat_history"].get("%s:%s" % [arc_id, beat_id], false))

func note_dialogue_seen(npc_id: String, dialogue_id: String, topic: String = "") -> void:
	if dialogue_id.is_empty():
		return
	var counts: Dictionary = quest_memory["dialogue_seen_counts"]
	counts[dialogue_id] = int(counts.get(dialogue_id, 0)) + 1
	quest_memory["dialogue_seen_counts"] = counts
	var last_seen: Dictionary = quest_memory["dialogue_last_seen"]
	last_seen[dialogue_id] = global_turn
	quest_memory["dialogue_last_seen"] = last_seen
	var last_by_npc: Dictionary = quest_memory["last_dialogue_by_npc"]
	last_by_npc[npc_id] = dialogue_id
	quest_memory["last_dialogue_by_npc"] = last_by_npc
	if topic.is_empty():
		return
	var topic_counts: Dictionary = quest_memory["npc_topic_counts"]
	var npc_topics: Dictionary = Dictionary(topic_counts.get(npc_id, {}))
	npc_topics[topic] = int(npc_topics.get(topic, 0)) + 1
	topic_counts[npc_id] = npc_topics
	quest_memory["npc_topic_counts"] = topic_counts

func get_dialogue_seen_count(dialogue_id: String) -> int:
	return int(quest_memory["dialogue_seen_counts"].get(dialogue_id, 0))

func get_dialogue_last_seen(dialogue_id: String) -> int:
	return int(quest_memory["dialogue_last_seen"].get(dialogue_id, -999))

func get_last_dialogue_for_npc(npc_id: String) -> String:
	return String(quest_memory["last_dialogue_by_npc"].get(npc_id, ""))

func get_npc_topic_seen_count(npc_id: String, topic: String) -> int:
	var topic_counts: Dictionary = quest_memory["npc_topic_counts"]
	var npc_topics: Dictionary = Dictionary(topic_counts.get(npc_id, {}))
	return int(npc_topics.get(topic, 0))

func _default_social_relation_state() -> Dictionary:
	return {
		"affinity": 0,
		"familiarity": 0,
		"fear": 0,
		"rivalry": 0,
		"last_event_turn": -999,
	}

func _normalize_social_actor_id(actor_id: String) -> String:
	var normalized := actor_id.strip_edges()
	if normalized.is_empty():
		return ""
	if normalized.contains(":"):
		return normalized
	if DataRepository.npcs.has(normalized):
		return "npc:%s" % normalized
	if DataRepository.species.has(normalized):
		return "species:%s" % normalized
	return normalized

func _social_relation_key(actor_a: String, actor_b: String) -> String:
	var normalized_a := _normalize_social_actor_id(actor_a)
	var normalized_b := _normalize_social_actor_id(actor_b)
	if normalized_a.is_empty() or normalized_b.is_empty():
		return ""
	var pair := [normalized_a, normalized_b]
	pair.sort()
	return "%s|%s" % [String(pair[0]), String(pair[1])]

func get_social_relation(actor_a: String, actor_b: String) -> Dictionary:
	var key := _social_relation_key(actor_a, actor_b)
	var relation := _default_social_relation_state()
	if key.is_empty():
		return relation
	var relations: Dictionary = _duplicate_dictionary(quest_memory.get("social_relations", {}))
	var stored: Dictionary = Dictionary(relations.get(key, {})).duplicate(true)
	for stat_key in relation.keys():
		if stat_key == "last_event_turn":
			relation[stat_key] = int(stored.get(stat_key, relation[stat_key]))
		else:
			relation[stat_key] = int(stored.get(stat_key, 0))
	relation["actor_a"] = _normalize_social_actor_id(actor_a)
	relation["actor_b"] = _normalize_social_actor_id(actor_b)
	return relation

func get_social_relation_value(actor_a: String, actor_b: String, stat_key: String) -> int:
	return int(get_social_relation(actor_a, actor_b).get(stat_key, 0))

func apply_social_relation_delta(actor_a: String, actor_b: String, delta: Dictionary) -> Dictionary:
	var key := _social_relation_key(actor_a, actor_b)
	if key.is_empty():
		return {}
	var relations: Dictionary = _duplicate_dictionary(quest_memory.get("social_relations", {}))
	var next_state := _default_social_relation_state()
	var current_state: Dictionary = Dictionary(relations.get(key, {}))
	for stat_key in next_state.keys():
		if stat_key == "last_event_turn":
			next_state[stat_key] = int(current_state.get(stat_key, next_state[stat_key]))
		else:
			next_state[stat_key] = int(current_state.get(stat_key, 0))
	for stat_key in ["affinity", "familiarity", "fear", "rivalry"]:
		if not delta.has(stat_key):
			continue
		next_state[stat_key] = int(next_state.get(stat_key, 0)) + int(delta.get(stat_key, 0))
	next_state["last_event_turn"] = global_turn
	relations[key] = next_state
	quest_memory["social_relations"] = relations
	var result := next_state.duplicate(true)
	result["actor_a"] = _normalize_social_actor_id(actor_a)
	result["actor_b"] = _normalize_social_actor_id(actor_b)
	return result

func add_trust(npc_id: String, amount: int) -> void:
	npc_trust[npc_id] = int(npc_trust.get(npc_id, 0)) + amount
	refresh_season_unlocks()

func get_npc_duel_record(npc_id: String) -> Dictionary:
	return Dictionary(npc_duel_records.get(npc_id, {})).duplicate(true)

func has_completed_npc_intro_duel(npc_id: String) -> bool:
	return bool(npc_duel_records.get(npc_id, {}).get("resolved", false))

func get_npc_intro_duel_won(npc_id: String) -> bool:
	return bool(npc_duel_records.get(npc_id, {}).get("won", false))

func record_npc_intro_duel(npc_id: String, won: bool, base_trust: int) -> Dictionary:
	if has_completed_npc_intro_duel(npc_id):
		return get_npc_duel_record(npc_id)

	var record := {
		"resolved": true,
		"won": won,
		"base_trust": base_trust,
		"timestamp": Time.get_unix_time_from_system()
	}
	npc_duel_records[npc_id] = record
	npc_trust[npc_id] = maxi(int(npc_trust.get(npc_id, 0)), base_trust)
	refresh_season_unlocks()
	return record.duplicate(true)

func has_items(cost: Dictionary) -> bool:
	for item_id in cost.keys():
		if int(inventory.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true

func can_pay(cost: Dictionary) -> bool:
	return has_items(cost)

func remove_items(cost: Dictionary) -> bool:
	if not has_items(cost):
		return false
	for item_id in cost.keys():
		var remaining := int(inventory.get(item_id, 0)) - int(cost[item_id])
		if remaining <= 0:
			inventory.erase(item_id)
		else:
			inventory[item_id] = remaining
	return true

func pay_cost(cost: Dictionary) -> bool:
	return remove_items(cost)

func add_items(reward_items: Dictionary) -> void:
	for item_id in reward_items.keys():
		inventory[item_id] = int(inventory.get(item_id, 0)) + int(reward_items[item_id])

func grant_items(reward_items: Dictionary) -> void:
	add_items(reward_items)

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func use_item(item_id: String, target: Dictionary = {}) -> Dictionary:
	var item := DataRepository.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "missing_item", "item_id": item_id}
	if get_item_count(item_id) <= 0:
		return {"ok": false, "reason": "insufficient_count", "item_id": item_id}
	var use_mode := String(item.get("use_mode", "passive"))
	if use_mode != "active":
		return {"ok": false, "reason": "not_usable", "item_id": item_id, "use_mode": use_mode}
	var effect_id := String(item.get("effect_id", "none"))
	var result := {"ok": false, "reason": "effect_unimplemented", "item_id": item_id, "effect_id": effect_id}
	match effect_id:
		"restore_hunger_small":
			result = {
				"ok": true,
				"item_id": item_id,
				"effect_id": effect_id,
				"kind": "hunger",
				"new_hunger": restore_hunger(8),
			}
		"restore_hunger_medium":
			result = {
				"ok": true,
				"item_id": item_id,
				"effect_id": effect_id,
				"kind": "hunger",
				"new_hunger": restore_hunger(16),
			}
		"add_bond_small":
			var pet_uid := String(target.get("pet_uid", ""))
			if pet_uid.is_empty():
				return {"ok": false, "reason": "missing_target", "item_id": item_id, "effect_id": effect_id}
			var bond_result := add_pet_bond(pet_uid, 1)
			if bond_result.is_empty():
				return {"ok": false, "reason": "invalid_target", "item_id": item_id, "effect_id": effect_id, "pet_uid": pet_uid}
			result = {
				"ok": true,
				"item_id": item_id,
				"effect_id": effect_id,
				"kind": "bond",
				"pet_uid": pet_uid,
				"bond_result": bond_result,
			}
		_:
			return result
	remove_items({item_id: 1})
	return result

func consume_hunger(amount: int) -> int:
	hunger = maxi(0, hunger - maxi(amount, 0))
	return hunger

func restore_hunger(amount: int) -> int:
	hunger = mini(max_hunger, hunger + maxi(amount, 0))
	return hunger

func is_hunger_low() -> bool:
	return hunger <= hunger_warning_threshold

func get_hunger_snapshot() -> Dictionary:
	return {
		"value": hunger,
		"max": max_hunger,
		"warning_threshold": hunger_warning_threshold,
		"ratio": float(hunger) / float(max_hunger),
	}

func apply_system_rewards(system_rewards: Dictionary) -> void:
	for reward_id in system_rewards.keys():
		match String(reward_id):
			"badge_count":
				badge_count += int(system_rewards[reward_id])
			"season_points":
				season_points += int(system_rewards[reward_id])
			"failed_dojo_streak_relief":
				failed_dojo_streak = maxi(0, failed_dojo_streak - int(system_rewards[reward_id]))
			"season_adjust_points":
				season_adjust_points += int(system_rewards[reward_id])
			"weekly_reroll_limit":
				weekly_reroll_limit += int(system_rewards[reward_id])
			"anchor_points":
				anchor_points += int(system_rewards[reward_id])
			"exploration_points":
				exploration_points += int(system_rewards[reward_id])
	_recalculate_pet_capacity()
	_sync_roster_slots()

func accept_quest(quest_id: String) -> void:
	if completed_quests.has(quest_id) or active_quests.has(quest_id):
		return
	active_quests.append(quest_id)

func complete_quest(quest_id: String) -> void:
	active_quests.erase(quest_id)
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)
	refresh_season_unlocks()

func register_species_seen(species_id: String) -> void:
	if not discovered_species.has(species_id):
		discovered_species.append(species_id)

func is_codex_unlock_rule_met(rule: Dictionary) -> bool:
	match String(rule.get("type", "")):
		"observe_species":
			return bool(quest_memory["observed_species"].get(String(rule.get("species_id", "")), false))
		"encounter_species":
			return bool(quest_memory["encounter_species"].get(String(rule.get("species_id", "")), false))
		"bond_species":
			return bool(quest_memory["bonded_species"].get(String(rule.get("species_id", "")), false))
		"calm_species":
			return bool(quest_memory["calmed_species"].get(String(rule.get("species_id", "")), false))
		"observe_marker":
			return bool(quest_memory["observed_markers"].get(String(rule.get("marker", "")), false))
		_:
			return false

func get_codex_entry_reveal_level(entry: Dictionary) -> int:
	var entry_id := String(entry.get("id", ""))
	if entry_id.is_empty():
		return CODEX_REVEAL_LOCKED
	if manual_codex_unlocks.has(entry_id):
		return CODEX_REVEAL_FULL
	if revealed_codex_entries.has(entry_id):
		return CODEX_REVEAL_BASIC
	if is_codex_unlock_rule_met(Dictionary(entry.get("unlock_rule", {})).duplicate(true)):
		return CODEX_REVEAL_BASIC
	return CODEX_REVEAL_LOCKED

func is_codex_entry_unlocked(entry: Dictionary) -> bool:
	return get_codex_entry_reveal_level(entry) >= CODEX_REVEAL_BASIC

func is_codex_entry_fully_unlocked(entry: Dictionary) -> bool:
	return get_codex_entry_reveal_level(entry) >= CODEX_REVEAL_FULL

func is_codex_entry_id_unlocked(entry_id: String) -> bool:
	var entry := DataRepository.get_codex_entry(entry_id)
	if entry.is_empty():
		return false
	return is_codex_entry_unlocked(entry)

func is_codex_entry_id_fully_unlocked(entry_id: String) -> bool:
	var entry := DataRepository.get_codex_entry(entry_id)
	if entry.is_empty():
		return false
	return is_codex_entry_fully_unlocked(entry)

func is_species_codex_unlocked(species_id: String) -> bool:
	if species_id.is_empty():
		return true
	var found_entry := false
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if String(entry.get("species_id", "")) != species_id:
			continue
		found_entry = true
		if is_codex_entry_unlocked(entry):
			return true
	return not found_entry

func reveal_codex_entry(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	var entry := DataRepository.get_codex_entry(entry_id)
	if entry.is_empty() or is_codex_entry_unlocked(entry):
		return false
	revealed_codex_entries.append(entry_id)
	revealed_codex_entries.sort()
	return true

func reveal_codex_for_species(species_id: String) -> Array[Dictionary]:
	var revealed: Array[Dictionary] = []
	if species_id.is_empty():
		return revealed
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if String(entry.get("species_id", "")) != species_id:
			continue
		var entry_id := String(entry.get("id", ""))
		if entry_id.is_empty() or not reveal_codex_entry(entry_id):
			continue
		revealed.append(entry)
	return revealed

func unlock_codex_entry(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	var entry := DataRepository.get_codex_entry(entry_id)
	if entry.is_empty() or is_codex_entry_fully_unlocked(entry):
		return false
	if not revealed_codex_entries.has(entry_id):
		revealed_codex_entries.append(entry_id)
		revealed_codex_entries.sort()
	manual_codex_unlocks.append(entry_id)
	manual_codex_unlocks.sort()
	return true

func unlock_codex_for_species(species_id: String) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	if species_id.is_empty():
		return unlocked
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if String(entry.get("species_id", "")) != species_id:
			continue
		var entry_id := String(entry.get("id", ""))
		if entry_id.is_empty() or not unlock_codex_entry(entry_id):
			continue
		unlocked.append(entry)
	return unlocked

func unlock_next_locked_codex_entries(count: int) -> Array[Dictionary]:
	var remaining := maxi(0, count)
	var locked_entries: Array[Dictionary] = []
	for raw_entry in DataRepository.codex_entries.values():
		var entry: Dictionary = Dictionary(raw_entry).duplicate(true)
		if is_codex_entry_fully_unlocked(entry):
			continue
		locked_entries.append(entry)
	locked_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var reveal_a := get_codex_entry_reveal_level(a)
		var reveal_b := get_codex_entry_reveal_level(b)
		if reveal_a != reveal_b:
			return reveal_a > reveal_b
		return String(a.get("title", a.get("id", ""))) < String(b.get("title", b.get("id", "")))
	)
	var unlocked: Array[Dictionary] = []
	for entry in locked_entries:
		if remaining <= 0:
			break
		var entry_id := String(entry.get("id", ""))
		if entry_id.is_empty() or not unlock_codex_entry(entry_id):
			continue
		unlocked.append(entry)
		remaining -= 1
	return unlocked

func is_encyclopedia_unlock_rule_met(rule: Dictionary) -> bool:
	match String(rule.get("type", "")):
		"visit_habitat":
			return int(quest_memory["visited_habitats"].get(String(rule.get("habitat_id", "")), 0)) > 0
		"unlock_habitat":
			return is_habitat_unlocked(String(rule.get("habitat_id", "")))
		"talk_to_npc":
			return bool(quest_memory["talked_npcs"].get(String(rule.get("npc", "")), false))
		"encounter_species":
			return bool(quest_memory["encounter_species"].get(String(rule.get("species_id", "")), false))
		"build":
			var building_id := String(rule.get("building_id", ""))
			var required_level := maxi(1, int(rule.get("level", 1)))
			return int(quest_memory["built_levels"].get(building_id, 0)) >= required_level
		_:
			return false

func is_encyclopedia_entry_unlocked(entry: Dictionary) -> bool:
	var entry_id := String(entry.get("id", ""))
	if entry_id.is_empty():
		return false
	if unlocked_encyclopedia_entries.has(entry_id):
		return true
	return is_encyclopedia_unlock_rule_met(Dictionary(entry.get("unlock_rule", {})).duplicate(true))

func is_encyclopedia_entry_id_unlocked(entry_id: String) -> bool:
	var entry := DataRepository.get_encyclopedia_entry(entry_id)
	if entry.is_empty():
		return false
	return is_encyclopedia_entry_unlocked(entry)

func unlock_encyclopedia_entry(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	var entry := DataRepository.get_encyclopedia_entry(entry_id)
	if entry.is_empty() or unlocked_encyclopedia_entries.has(entry_id):
		return false
	unlocked_encyclopedia_entries.append(entry_id)
	unlocked_encyclopedia_entries.sort()
	return true

func unlock_encyclopedia_entries(entry_ids: Array) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	for raw_entry_id in entry_ids:
		var entry_id := String(raw_entry_id)
		if entry_id.is_empty() or not unlock_encyclopedia_entry(entry_id):
			continue
		unlocked.append(DataRepository.get_encyclopedia_entry(entry_id))
	return unlocked

func add_journal_entry(entry: String) -> void:
	journal_entries.append(entry)
	while journal_entries.size() > 24:
		journal_entries.pop_front()

func set_daily_conditions(next_weather: String, next_time: String) -> void:
	weather_id = next_weather
	time_of_day = next_time

func advance_day() -> Dictionary:
	var trait_report := _apply_trait_daily_economy()
	day_index += 1
	season_turn = day_index
	global_turn += 1
	weekly_turn += 1
	var building_lines := _tick_building_runtime_states()
	var apartment_lines := _process_apartment_daily_updates()
	var day_lines: Array = Array(trait_report.get("lines", [])).duplicate(true)
	day_lines.append_array(building_lines)
	day_lines.append_array(apartment_lines)
	day_lines.append_array(_tick_nursery_projects())
	trait_report["lines"] = day_lines
	if weekly_turn > 5:
		weekly_turn = 1
		week_index += 1
		weekly_reroll_count = 0
		clear_pending_minigame_bonus()
	if global_turn % 10 == 0:
		anchor_points += 1
	return trait_report

func advance_to_next_season() -> bool:
	var current_index := SEASON_ORDER.find(season_id)
	if current_index == -1 or current_index >= SEASON_ORDER.size() - 1:
		return false
	completed_seasons += 1
	season_id = String(SEASON_ORDER[current_index + 1])
	day_index = 1
	season_turn = 1
	week_index = 1
	weekly_turn = 1
	weekly_reroll_count = 0
	weather_id = "clear"
	time_of_day = "day"
	failed_dojo_streak = 0
	weekly_objective.clear()
	weekly_progress.clear()
	current_board_node_id = 0
	revealed_board_nodes.clear()
	node_danger.clear()
	pending_node_ambushes.clear()
	active_board_threats.clear()
	npc_positions.clear()
	clear_pending_minigame_bonus()
	_reset_ai_players_for_new_season()
	_sync_current_season_rule()
	_sync_roster_slots()
	refresh_season_unlocks()
	return true

func _sync_current_season_rule() -> void:
	var season_rule := DataRepository.get_season_rule(season_id)
	season_length = int(season_rule.get("days", DEFAULT_SEASON_LENGTH))
	weekly_reroll_limit = int(season_rule.get("weekly_reroll_limit", 1))
	season_adjust_points = int(season_rule.get("season_adjust_points", 0))
	board_region_id = String(season_rule.get("region_id", ""))
	_apply_meta_dice_modules()

func _apply_meta_dice_modules() -> void:
	for module_id in meta_unlocks.get("dice_modules", []):
		var module: Dictionary = DataRepository.get_dice_module(String(module_id))
		var effects: Dictionary = module.get("effects", {})
		weekly_reroll_limit += int(effects.get("weekly_reroll_bonus", 0))
		season_adjust_points += int(effects.get("season_adjust_bonus", 0))
		anchor_points += int(effects.get("anchor_bonus", 0))

func get_current_season_rule() -> Dictionary:
	return DataRepository.get_season_rule(season_id)

func get_current_year_index() -> int:
	return int(completed_seasons / maxi(1, SEASON_ORDER.size())) + 1

func get_annual_competition_history() -> Array:
	return _duplicate_array(annual_competition_history)

func get_latest_annual_competition_result() -> Dictionary:
	return _duplicate_dictionary(latest_annual_competition_result)

func get_annual_competition_result(year_index: int = -1) -> Dictionary:
	var target_year := year_index if year_index > 0 else get_current_year_index()
	for raw_result in annual_competition_history:
		var result: Dictionary = _duplicate_dictionary(raw_result)
		if int(result.get("year_index", 0)) == target_year:
			return result
	return {}

func has_annual_competition_result(year_index: int = -1) -> bool:
	return not get_annual_competition_result(year_index).is_empty()

func has_annual_competition_reminder(year_index: int = -1) -> bool:
	var target_year := year_index if year_index > 0 else get_current_year_index()
	return annual_competition_reminder_years.has(target_year)

func mark_annual_competition_reminder(year_index: int = -1) -> void:
	var target_year := year_index if year_index > 0 else get_current_year_index()
	if target_year <= 0 or annual_competition_reminder_years.has(target_year):
		return
	annual_competition_reminder_years.append(target_year)
	annual_competition_reminder_years.sort()

func record_annual_competition_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var stored := _duplicate_dictionary(result)
	var target_year := int(stored.get("year_index", get_current_year_index()))
	stored["year_index"] = target_year
	for index in range(annual_competition_history.size()):
		var existing: Dictionary = _duplicate_dictionary(annual_competition_history[index])
		if int(existing.get("year_index", 0)) != target_year:
			continue
		annual_competition_history[index] = stored
		latest_annual_competition_result = stored.duplicate(true)
		return
	annual_competition_history.append(stored)
	annual_competition_history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("year_index", 0)) < int(b.get("year_index", 0))
	)
	latest_annual_competition_result = stored.duplicate(true)

func set_trait_runtime_bonus(bonus: Dictionary) -> void:
	active_trait_runtime_bonus = bonus.duplicate(true)
	trait_runtime_dirty = false

func get_trait_runtime_bonus() -> Dictionary:
	refresh_trait_runtime_bonus()
	return active_trait_runtime_bonus.duplicate(true)

func refresh_trait_runtime_bonus(force := false) -> Dictionary:
	if not force and not trait_runtime_dirty:
		return active_trait_runtime_bonus.duplicate(true)
	if _trait_synergy_service == null:
		_trait_synergy_service = load("res://scripts/services/synergy_service.gd").new()
	active_trait_runtime_report = _trait_synergy_service.build_synergy_report()
	active_trait_runtime_bonus = _trait_synergy_service.build_runtime_bonus(active_trait_runtime_report)
	trait_runtime_dirty = false
	return active_trait_runtime_bonus.duplicate(true)

func get_trait_runtime_report() -> Dictionary:
	refresh_trait_runtime_bonus()
	return active_trait_runtime_report.duplicate(true)

func mark_trait_runtime_dirty() -> void:
	trait_runtime_dirty = true

func get_treasury_snapshot() -> Dictionary:
	return {
		"wallet_gold": wallet_gold,
		"bank_gold": bank_gold,
		"rival_wallets": rival_wallets.duplicate(true),
	}

func get_ai_players() -> Array:
	return _duplicate_array(ai_players)

func set_ai_players(players: Array) -> void:
	ai_players = _duplicate_array(players)
	_sync_rival_wallets_from_ai_players()

func add_wallet_gold(amount: int) -> void:
	if amount <= 0:
		return
	wallet_gold += amount

func can_afford_wallet_gold(amount: int) -> bool:
	return wallet_gold >= maxi(amount, 0)

func spend_wallet_gold(amount: int) -> bool:
	var cost := maxi(amount, 0)
	if cost <= 0:
		return true
	if wallet_gold < cost:
		return false
	wallet_gold -= cost
	return true

func get_shop_purchase_count(shop_id: String, offer_id: String) -> int:
	return int(shop_purchase_counts.get(_shop_purchase_key(shop_id, offer_id), 0))

func record_shop_purchase(shop_id: String, offer_id: String, amount: int = 1) -> void:
	var count := maxi(amount, 0)
	if shop_id.is_empty() or offer_id.is_empty() or count <= 0:
		return
	var key := _shop_purchase_key(shop_id, offer_id)
	shop_purchase_counts[key] = int(shop_purchase_counts.get(key, 0)) + count

func _shop_purchase_key(shop_id: String, offer_id: String) -> String:
	return "%s|%d|%s|%s" % [season_id, week_index, shop_id, offer_id]

func deposit_bank_gold(amount: int) -> int:
	var moved := mini(maxi(amount, 0), wallet_gold)
	if moved <= 0:
		return 0
	wallet_gold -= moved
	bank_gold += moved
	return moved

func withdraw_bank_gold(amount: int) -> int:
	var moved := mini(maxi(amount, 0), bank_gold)
	if moved <= 0:
		return 0
	bank_gold -= moved
	wallet_gold += moved
	return moved

func _apply_trait_daily_economy() -> Dictionary:
	refresh_trait_runtime_bonus()
	var lines: Array[String] = []
	var passive_wallet_gold := int(active_trait_runtime_bonus.get("wallet_gold_per_day", 0))
	if passive_wallet_gold > 0:
		wallet_gold += passive_wallet_gold
		lines.append("拾荒羁绊：日结额外摸到 %d 金。" % passive_wallet_gold)
	var deposit_ratio := clampf(float(active_trait_runtime_bonus.get("auto_bank_deposit_ratio", 0.0)), 0.0, 1.0)
	if deposit_ratio > 0.0 and wallet_gold > 0:
		var moved := mini(wallet_gold, maxi(1, int(ceil(float(wallet_gold) * deposit_ratio))))
		wallet_gold -= moved
		bank_gold += moved
		lines.append("守财奴：自动存入银行 %d 金。" % moved)
	var interest_ratio := 0.0 + float(active_trait_runtime_bonus.get("bank_interest_bonus_ratio", 0.0))
	if bank_gold > 0 and interest_ratio > 0.0:
		var interest := maxi(1, int(floor(float(bank_gold) * interest_ratio)))
		bank_gold += interest
		lines.append("守财奴：银行结算利息 +%d 金。" % interest)
	var rival_tax_ratio := clampf(float(active_trait_runtime_bonus.get("rival_tax_ratio", 0.0)), 0.0, 0.9)
	if rival_tax_ratio > 0.0 and not ai_players.is_empty():
		var total_tax := 0
		for index in range(ai_players.size()):
			var rival: Dictionary = Dictionary(ai_players[index]).duplicate(true)
			var current_gold := int(rival.get("gold", 0))
			if current_gold <= 0:
				continue
			var tax := mini(current_gold, maxi(1, int(floor(float(current_gold) * rival_tax_ratio))))
			rival["gold"] = current_gold - tax
			ai_players[index] = rival
			total_tax += tax
		_sync_rival_wallets_from_ai_players()
		if total_tax > 0:
			wallet_gold += total_tax
			lines.append("守财奴：向全部对手征税，共收取 %d 金。" % total_tax)
	elif rival_tax_ratio > 0.0 and not rival_wallets.is_empty():
		var total_tax := 0
		for rival_id in rival_wallets.keys():
			var current_gold := int(rival_wallets.get(rival_id, 0))
			if current_gold <= 0:
				continue
			var tax := mini(current_gold, maxi(1, int(floor(float(current_gold) * rival_tax_ratio))))
			rival_wallets[rival_id] = current_gold - tax
			total_tax += tax
		if total_tax > 0:
			wallet_gold += total_tax
			lines.append("守财奴：向全部对手征税，共收取 %d 金。" % total_tax)
	return {
		"lines": lines,
		"wallet_gold": wallet_gold,
		"bank_gold": bank_gold,
	}

func set_run_modifiers(modifiers: Array) -> void:
	run_modifiers = modifiers.duplicate(true)

func peek_pending_minigame_bonus() -> Dictionary:
	return pending_minigame_bonus.duplicate(true)

func add_pending_minigame_bonus(delta: Dictionary, note: String = "") -> Dictionary:
	var caps := {
		"ally_attack_bonus": 2,
		"ally_speed_bonus": 2,
		"ally_hp_bonus": 8,
	}
	for stat_key in caps.keys():
		var current_value := int(pending_minigame_bonus.get(stat_key, 0))
		var next_value := current_value + int(delta.get(stat_key, 0))
		pending_minigame_bonus[stat_key] = mini(int(caps.get(stat_key, 0)), next_value)
	if not note.is_empty():
		if not pending_minigame_bonus_notes.has(note):
			pending_minigame_bonus_notes.append(note)
		if pending_minigame_bonus_notes.size() > 4:
			pending_minigame_bonus_notes = pending_minigame_bonus_notes.slice(pending_minigame_bonus_notes.size() - 4, pending_minigame_bonus_notes.size())
	return {
		"bonus": pending_minigame_bonus.duplicate(true),
		"notes": pending_minigame_bonus_notes.duplicate(),
	}

func consume_pending_minigame_bonus() -> Dictionary:
	var result := {
		"bonus": pending_minigame_bonus.duplicate(true),
		"notes": pending_minigame_bonus_notes.duplicate(),
	}
	clear_pending_minigame_bonus()
	return result

func clear_pending_minigame_bonus() -> void:
	pending_minigame_bonus.clear()
	pending_minigame_bonus_notes.clear()

func set_board_region(region_id: String, start_node_id: int = 0) -> void:
	board_region_id = region_id
	current_board_node_id = start_node_id

func move_to_board_node(node_id: int) -> void:
	current_board_node_id = node_id

func _build_default_ai_players() -> Array:
	var players: Array = []
	var personality_ids: Array[String] = []
	for personality_id in GameData.AI_PERSONALITIES.keys():
		personality_ids.append(String(personality_id))
	personality_ids.sort()
	for index in range(personality_ids.size()):
		var personality_id := personality_ids[index]
		var personality: Dictionary = GameData.AI_PERSONALITIES.get(personality_id, {})
		players.append({
			"id": "rival_%s" % personality_id,
			"display_name": String(personality.get("name", personality_id)),
			"personality_id": personality_id,
			"description": String(personality.get("description", "")),
			"lineup": _coerce_string_array(personality.get("lineup", [])),
			"current_node_id": 0,
			"gold": 10 + index * 2,
			"prestige": 0,
			"intel": 0,
			"control": 0,
			"battle_wins": 0,
			"season_distance": 0,
			"turns_taken": 0,
			"last_roll": 0,
			"tactical_rerolls": 1,
			"latest_action": "正在营地观察本季路线。",
			"latest_action_short": "营地观察",
			"intent": "准备切入主线",
		})
	return players

func _reset_ai_players_for_new_season() -> void:
	if ai_players.is_empty():
		ai_players = _build_default_ai_players()
	else:
		for index in range(ai_players.size()):
			var rival: Dictionary = Dictionary(ai_players[index]).duplicate(true)
			rival["current_node_id"] = 0
			rival["season_distance"] = 0
			rival["turns_taken"] = 0
			rival["last_roll"] = 0
			rival["tactical_rerolls"] = 1
			rival["gold"] = int(rival.get("gold", 0)) + 2
			rival["latest_action"] = "%s 正在为 %s 重整队伍。" % [
				String(rival.get("display_name", "对手")),
				String(get_current_season_rule().get("name", season_id)),
			]
			rival["latest_action_short"] = "重整队伍"
			rival["intent"] = "准备切入新赛季"
			ai_players[index] = rival
	_sync_rival_wallets_from_ai_players()

func _sync_rival_wallets_from_ai_players() -> void:
	rival_wallets.clear()
	for rival in ai_players:
		var state := Dictionary(rival)
		var rival_id := String(state.get("id", ""))
		if rival_id.is_empty():
			continue
		rival_wallets[rival_id] = int(state.get("gold", 0))

func reveal_board_nodes(node_ids: Array) -> void:
	for node_id in node_ids:
		var int_id := int(node_id)
		if not revealed_board_nodes.has(int_id):
			revealed_board_nodes.append(int_id)

func get_board_loop_progress(season_override: String = "") -> Dictionary:
	var key := season_id if season_override.is_empty() else season_override
	if key.is_empty():
		return {}
	return _duplicate_dictionary(board_loop_progress.get(key, {}))

func set_board_loop_progress(progress: Dictionary, season_override: String = "") -> void:
	var key := season_id if season_override.is_empty() else season_override
	if key.is_empty():
		return
	board_loop_progress[key] = _duplicate_dictionary(progress)

func clear_board_loop_progress(season_override: String = "") -> void:
	var key := season_id if season_override.is_empty() else season_override
	if key.is_empty():
		return
	board_loop_progress.erase(key)

func get_node_danger(node_id: int) -> int:
	return int(node_danger.get(node_id, 0))

func add_node_danger(node_id: int, amount: int) -> void:
	if node_id < 0 or amount == 0:
		return
	node_danger[node_id] = clampi(get_node_danger(node_id) + amount, 0, 3)

func reduce_node_danger(node_id: int, amount: int = 1) -> void:
	if node_id < 0 or amount <= 0:
		return
	var next_value := maxi(0, get_node_danger(node_id) - amount)
	if next_value == 0:
		node_danger.erase(node_id)
		return
	node_danger[node_id] = next_value

func queue_node_ambush(node_id: int, amount: int = 1) -> void:
	if node_id < 0 or amount <= 0:
		return
	pending_node_ambushes[node_id] = int(pending_node_ambushes.get(node_id, 0)) + amount

func has_node_ambush(node_id: int) -> bool:
	return int(pending_node_ambushes.get(node_id, 0)) > 0

func clear_node_ambush(node_id: int) -> void:
	if node_id < 0:
		return
	pending_node_ambushes.erase(node_id)

func consume_node_ambush(node_id: int) -> bool:
	if not has_node_ambush(node_id):
		return false
	var next_value := int(pending_node_ambushes.get(node_id, 0)) - 1
	if next_value <= 0:
		pending_node_ambushes.erase(node_id)
	else:
		pending_node_ambushes[node_id] = next_value
	return true

func set_active_board_threats(threats: Array) -> void:
	active_board_threats = threats.duplicate(true)

func get_active_board_threats() -> Array:
	return active_board_threats.duplicate(true)

func set_npc_positions(positions: Dictionary) -> void:
	npc_positions = positions.duplicate(true)

func get_npc_positions() -> Dictionary:
	return npc_positions.duplicate(true)

func set_weekly_objective(objective: Dictionary) -> void:
	weekly_objective = objective.duplicate(true)
	weekly_progress.clear()

func add_weekly_progress(metric: String, amount: int = 1) -> void:
	if metric.is_empty() or amount == 0:
		return
	weekly_progress[metric] = int(weekly_progress.get(metric, 0)) + amount

func consume_weekly_reroll() -> bool:
	if weekly_reroll_count >= weekly_reroll_limit:
		return false
	weekly_reroll_count += 1
	return true

func consume_adjust_point() -> bool:
	if season_adjust_points <= 0:
		return false
	season_adjust_points -= 1
	return true

func consume_anchor_point() -> bool:
	if anchor_points <= 0:
		return false
	anchor_points -= 1
	return true

func has_meta_track(track_id: String) -> bool:
	return meta_unlocks.get("tracks", []).has(track_id)

func register_meta_track(track_id: String, unlock: Dictionary) -> void:
	if track_id.is_empty() or has_meta_track(track_id):
		return
	var tracks: Array = meta_unlocks.get("tracks", []).duplicate()
	tracks.append(track_id)
	meta_unlocks["tracks"] = tracks
	var module_id := String(unlock.get("dice_module_id", ""))
	if not module_id.is_empty():
		var modules: Array = meta_unlocks.get("dice_modules", []).duplicate()
		if not modules.has(module_id):
			modules.append(module_id)
			meta_unlocks["dice_modules"] = modules

func register_meta_tracks(tracks: Array) -> Array[String]:
	var unlocked_ids: Array[String] = []
	for raw_track in tracks:
		var track: Dictionary = Dictionary(raw_track).duplicate(true)
		var track_id := String(track.get("id", ""))
		if track_id.is_empty() or has_meta_track(track_id):
			continue
		register_meta_track(track_id, Dictionary(track.get("unlock", {})).duplicate(true))
		unlocked_ids.append(track_id)
	return unlocked_ids

func add_meta_progression_total(amount: int) -> int:
	var delta := maxi(0, amount)
	if delta <= 0:
		return exploration_points_total
	exploration_points_total += delta
	return exploration_points_total

func add_exploration_points(amount: int) -> void:
	exploration_points += amount
	exploration_points_total += amount

func get_total_trust() -> int:
	var total := 0
	for value in npc_trust.values():
		total += int(value)
	return total

func get_habitat_rank_total() -> int:
	var total := 0
	for state in habitats.values():
		total += int(state.get("rank", 0))
	return total

func get_settled_habitat_count() -> int:
	var total := 0
	for habitat_id in habitats.keys():
		var profile := DataRepository.get_habitat(habitat_id)
		if String(profile.get("type", "")) != "habitat":
			continue
		var actor_id := String(habitats[habitat_id].get("resident_actor_id", habitats[habitat_id].get("resident_uid", "")))
		if actor_id != "":
			total += 1
	return total

func get_care_progress() -> int:
	var nursery_score := 0
	for habitat_state in habitats.values():
		var nursery_state: Dictionary = _duplicate_dictionary(Dictionary(habitat_state).get("nursery_state", {}))
		if nursery_state.is_empty():
			continue
		if not Dictionary(nursery_state.get("active_project", {})).is_empty():
			nursery_score += 2
		nursery_score += _coerce_string_array(nursery_state.get("history", [])).size()
	return get_settled_habitat_count() * 2 + bonded_species.size() * 2 + completed_quests.size() + get_habitat_rank_total() + badge_count + nursery_score

func refresh_season_unlocks() -> Array[String]:
	var unlocked_now: Array[String] = []
	current_available_habitats_cache.clear()
	for habitat_id in habitats.keys():
		var open := can_unlock_habitat(habitat_id)
		var state: Dictionary = habitats[habitat_id]
		var was_open := bool(state.get("is_unlocked", false))
		state["is_unlocked"] = open
		habitats[habitat_id] = state
		if open:
			current_available_habitats_cache.append(habitat_id)
			if not was_open:
				unlocked_now.append(habitat_id)
	return unlocked_now

func can_unlock_habitat(habitat_id: String) -> bool:
	return bool(get_habitat_unlock_status(habitat_id).get("open", false))

func get_habitat_unlock_status(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return {"open": false, "reasons": ["地点数据缺失"], "unlock_text": ""}
	if _is_season_blocked(habitat_id, habitat):
		return {"open": false, "reasons": ["当前季节未开放"], "unlock_text": ""}
	if not _matches_season_availability(habitat):
		var seasons := Array(habitat.get("season_availability", []))
		return {"open": false, "reasons": ["仅在 %s 开放" % " / ".join(seasons)], "unlock_text": ""}

	var rules := DataRepository.get_unlock_rules_for_habitat(habitat_id)
	if not rules.is_empty():
		var rule: Dictionary = rules[0]
		var reasons := _missing_reasons_for_conditions(rule.get("conditions", []))
		if reasons.is_empty() or season_unlock_history.has(habitat_id):
			return {
				"open": true,
				"reasons": [],
				"unlock_text": String(rule.get("unlock_text", "")),
				"rule_id": String(rule.get("id", "")),
			}
		return {
			"open": false,
			"reasons": reasons,
			"unlock_text": String(rule.get("unlock_text", "")),
			"rule_id": String(rule.get("id", "")),
		}

	var season_rule := get_current_season_rule()
	if Array(season_rule.get("unlock_habitats", [])).has(habitat_id):
		return {"open": true, "reasons": [], "unlock_text": ""}
	if season_unlock_history.has(habitat_id):
		return {"open": true, "reasons": [], "unlock_text": ""}
	return _legacy_unlock_status(habitat_id, habitat)

func _legacy_unlock_status(habitat_id: String, habitat: Dictionary) -> Dictionary:
	var unlock_rule: Dictionary = habitat.get("unlock_rule", {})
	match String(unlock_rule.get("type", "default")):
		"default":
			return {"open": true, "reasons": [], "unlock_text": ""}
		"quest":
			var is_open := bool(habitats.get(habitat_id, {}).get("is_unlocked", false))
			if is_open:
				return {"open": true, "reasons": [], "unlock_text": ""}
			var quest_id := String(unlock_rule.get("quest_id", ""))
			if not quest_id.is_empty() and DataRepository.get_quest(quest_id).is_empty():
				var rank_gate := maxi(1, int(habitat.get("recommended_rank", 1)))
				if get_habitat_rank_total() >= rank_gate:
					return {"open": true, "reasons": [], "unlock_text": ""}
				return {
					"open": false,
					"reasons": ["总据点等级达到 %d" % rank_gate],
					"unlock_text": "",
				}
			return {
				"open": false,
				"reasons": ["完成委托 %s" % quest_id],
				"unlock_text": "",
			}
		"season_progress":
			var reasons: Array[String] = []
			var required_rank := int(unlock_rule.get("required_habitat_rank", 0))
			if get_habitat_rank_total() < required_rank:
				reasons.append("总据点等级达到 %d" % required_rank)
			var required_trust := int(unlock_rule.get("required_trust_total", 0))
			if get_total_trust() < required_trust:
				reasons.append("总信赖达到 %d" % required_trust)
			return {"open": reasons.is_empty(), "reasons": reasons, "unlock_text": ""}
		_:
			return {"open": bool(habitats.get(habitat_id, {}).get("is_unlocked", false)), "reasons": [], "unlock_text": ""}

func _is_season_blocked(habitat_id: String, _habitat: Dictionary) -> bool:
	return Array(get_current_season_rule().get("lock_habitats", [])).has(habitat_id)

func _matches_season_availability(habitat: Dictionary) -> bool:
	var availability: Array = habitat.get("season_availability", [])
	return availability.is_empty() or availability.has(season_id)

func _missing_reasons_for_conditions(conditions: Array) -> Array[String]:
	var reasons: Array[String] = []
	for condition in conditions:
		match String(condition.get("type", "")):
			"season_is":
				var expected := String(condition.get("value", ""))
				if season_id != expected:
					reasons.append("当前季节需为 %s" % expected)
			"season_in":
				var valid_seasons: Array = condition.get("value", [])
				if not valid_seasons.has(season_id):
					reasons.append("需处于 %s" % " / ".join(valid_seasons))
			"trust_at_least":
				var trust_required := int(condition.get("value", 0))
				if get_total_trust() < trust_required:
					reasons.append("总信赖达到 %d" % trust_required)
			"habitat_rank_total_at_least":
				var rank_required := int(condition.get("value", 0))
				if get_habitat_rank_total() < rank_required:
					reasons.append("总据点等级达到 %d" % rank_required)
			"built_level_at_least":
				var building_id := String(condition.get("building_id", ""))
				var level_required := int(condition.get("value", 0))
				if int(quest_memory["built_levels"].get(building_id, 0)) < level_required:
					reasons.append("%s 升到 Lv.%d" % [building_id, level_required])
			"quest_completed":
				var quest_id := String(condition.get("value", ""))
				if not completed_quests.has(quest_id):
					reasons.append("完成委托 %s" % quest_id)
			"dojo_cleared":
				var clear_id := String(condition.get("value", ""))
				if not dojo_clear_flags.get(clear_id, false):
					reasons.append("完成试炼 %s" % clear_id)
			"species_seen":
				var species_id := String(condition.get("value", ""))
				if not discovered_species.has(species_id):
					reasons.append("见过 %s" % species_id)
			"weather_is":
				var weather_required := String(condition.get("value", ""))
				if weather_id != weather_required:
					reasons.append("天气需为 %s" % weather_required)
	return reasons

func unlock_habitat(habitat_id: String) -> void:
	if not habitats.has(habitat_id):
		return
	season_unlock_history[habitat_id] = season_id
	var state: Dictionary = habitats[habitat_id]
	state["is_unlocked"] = true
	habitats[habitat_id] = state
	refresh_season_unlocks()

func has_cleared_dojo(dojo_id: String, tier: String) -> bool:
	return bool(dojo_clear_flags.get("%s:%s" % [dojo_id, tier], false))

func mark_dojo_clear(dojo_id: String, tier: String, first_clear: bool) -> Array[String]:
	dojo_clear_flags["%s:%s" % [dojo_id, tier]] = true
	failed_dojo_streak = 0
	var unlocked_skills := _grant_dojo_traversal_skill_awards(dojo_id, tier)
	if first_clear:
		var dojo := DataRepository.get_dojo(dojo_id)
		var unlocks: Array = dojo.get("unlock_on_clear", {}).get(tier, [])
		for habitat_id in unlocks:
			unlock_habitat(String(habitat_id))
	refresh_season_unlocks()
	return unlocked_skills

func note_dojo_failure() -> void:
	failed_dojo_streak += 1

func get_traversal_skill_name(skill_id: String) -> String:
	return String(TRAVERSAL_SKILL_NAMES.get(skill_id, skill_id))

func get_traversal_skill_ids() -> Array[String]:
	return traversal_skills.duplicate()

func has_traversal_skill(skill_id: String) -> bool:
	return traversal_skills.has(skill_id)

func learn_traversal_skill(skill_id: String) -> bool:
	if skill_id.is_empty() or has_traversal_skill(skill_id):
		return false
	traversal_skills.append(skill_id)
	traversal_skills.sort()
	return true

func preview_dojo_traversal_skill_awards(dojo_id: String, tier: String) -> Array[String]:
	var key := "%s:%s" % [dojo_id, tier]
	var skill_ids: Array[String] = []
	for raw_skill_id in Array(DOJO_TRAVERSAL_SKILL_AWARDS.get(key, [])):
		var skill_id := String(raw_skill_id)
		if skill_id.is_empty() or skill_ids.has(skill_id):
			continue
		skill_ids.append(skill_id)
	return skill_ids

func _grant_dojo_traversal_skill_awards(dojo_id: String, tier: String) -> Array[String]:
	var unlocked: Array[String] = []
	for skill_id in preview_dojo_traversal_skill_awards(dojo_id, tier):
		if learn_traversal_skill(skill_id):
			unlocked.append(skill_id)
	return unlocked

func get_current_dojo_rotation() -> Array:
	return get_current_season_rule().get("dojo_rotation", []).duplicate()

func is_habitat_unlocked(habitat_id: String) -> bool:
	if not habitats.has(habitat_id):
		return false
	return bool(habitats[habitat_id].get("is_unlocked", false))

func record_visit(payload: Dictionary) -> void:
	visit_history.append(payload)

func get_progression_rank() -> int:
	return maxi(1, 1 + badge_count + int(get_habitat_rank_total() / 2))

func get_progression_summary() -> String:
	var entry := DataRepository.get_population_curve_entry(get_progression_rank())
	if entry.is_empty():
		return ""
	var parts: Array[String] = []
	var new_system := String(entry.get("new_system", ""))
	var flow_goal := String(entry.get("flow_goal", ""))
	if not new_system.is_empty():
		parts.append(new_system)
	if not flow_goal.is_empty():
		parts.append(flow_goal)
	return " ｜ ".join(parts)

func _recalculate_pet_capacity() -> void:
	var curve_entry := DataRepository.get_population_curve_entry(get_progression_rank())
	pet_capacity = int(curve_entry.get("pet_capacity", curve_entry.get("backpack_capacity", 4)))

func _recalculate_backpack_capacity() -> void:
	_recalculate_pet_capacity()

func _sync_roster_slots() -> void:
	trait_runtime_dirty = true
	var valid_uids := {}
	for companion in get_companions():
		valid_uids[String(companion.get("uid", ""))] = true
	var clean_party: Array[String] = []
	for pet_uid in party_slots:
		if valid_uids.has(pet_uid) and not clean_party.has(pet_uid):
			clean_party.append(pet_uid)
	var clean_reserve: Array[String] = []
	for pet_uid in reserve_slots:
		if valid_uids.has(pet_uid) and not clean_party.has(pet_uid) and not clean_reserve.has(pet_uid):
			if _population_used_for_uids(clean_reserve) + _population_cost_for_uid(String(pet_uid)) <= pet_capacity:
				clean_reserve.append(pet_uid)
	for companion in get_companions():
		var pet_uid := String(companion.get("uid", ""))
		if clean_party.size() < 2 and not clean_party.has(pet_uid):
			clean_party.append(pet_uid)
			continue
		if not clean_party.has(pet_uid) and not clean_reserve.has(pet_uid) and _population_used_for_uids(clean_reserve) + _population_cost_for_uid(pet_uid) <= pet_capacity:
			clean_reserve.append(pet_uid)
	party_slots = clean_party
	reserve_slots = clean_reserve

func get_party_uids() -> Array[String]:
	_sync_roster_slots()
	return party_slots.duplicate()

func get_battle_party_uids() -> Array[String]:
	return get_party_uids()

func get_reserve_uids() -> Array[String]:
	_sync_roster_slots()
	return reserve_slots.duplicate()

func get_backpack_uids() -> Array[String]:
	return get_reserve_uids()

func get_reserve_population_used() -> int:
	_sync_roster_slots()
	return _population_used_for_uids(reserve_slots)

func get_backpack_population_used() -> int:
	return get_reserve_population_used()

func get_building_slot_uids() -> Array[String]:
	var result: Array[String] = []
	for habitat_state in habitats.values():
		for slot_key in ["resident_uid", "assistant_uid"]:
			var pet_uid := String(habitat_state.get(slot_key, ""))
			if pet_uid.is_empty() or result.has(pet_uid):
				continue
			result.append(pet_uid)
	return result

func set_party_slot(slot_index: int, pet_uid: String) -> void:
	if not pet_states.has(pet_uid):
		return
	_sync_roster_slots()
	while party_slots.size() <= slot_index:
		party_slots.append("")
	var displaced_uid := String(party_slots[slot_index])
	party_slots[slot_index] = pet_uid
	for index in range(party_slots.size()):
		if index == slot_index:
			continue
		if party_slots[index] == pet_uid:
			party_slots[index] = displaced_uid
			break
	_sync_roster_slots()

func set_battle_slot(slot_index: int, pet_uid: String) -> void:
	set_party_slot(slot_index, pet_uid)

func toggle_reserve_slot(pet_uid: String) -> void:
	if not pet_states.has(pet_uid):
		return
	_sync_roster_slots()
	if party_slots.has(pet_uid):
		return
	if reserve_slots.has(pet_uid):
		reserve_slots.erase(pet_uid)
	else:
		while not reserve_slots.is_empty() and get_reserve_population_used() + _population_cost_for_uid(pet_uid) > pet_capacity:
			reserve_slots.pop_back()
		if get_reserve_population_used() + _population_cost_for_uid(pet_uid) <= pet_capacity:
			reserve_slots.append(pet_uid)
	_sync_roster_slots()

func toggle_backpack_slot(pet_uid: String) -> void:
	toggle_reserve_slot(pet_uid)

func get_pet_population_cost(pet_uid: String) -> int:
	return _population_cost_for_uid(pet_uid)

func _population_cost_for_uid(pet_uid: String) -> int:
	var pet := get_pet(pet_uid)
	if pet.is_empty():
		return 0
	var profile := GameData.get_species_synergy_profile(String(pet.get("species_id", "")))
	return maxi(1, int(profile.get("population_cost", 1)))

func _population_used_for_uids(pet_uids: Array) -> int:
	var total := 0
	for pet_uid in pet_uids:
		total += _population_cost_for_uid(String(pet_uid))
	return total

func count_species_pets(species_id: String, star_level: int = -1) -> int:
	var total := 0
	for pet in pet_states.values():
		if String(pet.get("species_id", "")) != species_id:
			continue
		if star_level > 0 and int(pet.get("star_level", 1)) != star_level:
			continue
		total += 1
	return total

func merge_species_duplicates(species_id: String) -> Dictionary:
	var upgrades: Array = []
	var keep_merging := true
	while keep_merging:
		keep_merging = false
		for star_level in [1, 2]:
			var result := _merge_species_star(species_id, star_level)
			if bool(result.get("ok", false)):
				upgrades.append(result)
				keep_merging = true
				break
	return {
		"ok": not upgrades.is_empty(),
		"upgrades": upgrades,
	}

func _merge_species_star(species_id: String, star_level: int) -> Dictionary:
	if star_level >= 3:
		return {"ok": false, "reason": "max_star"}
	var candidates: Array[String] = []
	for pet_uid in pet_states.keys():
		var pet: Dictionary = pet_states[pet_uid]
		if String(pet.get("species_id", "")) != species_id:
			continue
		if int(pet.get("star_level", 1)) != star_level:
			continue
		candidates.append(String(pet_uid))
	if candidates.size() < 3:
		return {"ok": false, "reason": "not_enough_duplicates"}
	candidates.sort()
	var base_uid := String(candidates[0])
	var consume_uids: Array[String] = [String(candidates[1]), String(candidates[2])]
	var base_pet: Dictionary = pet_states.get(base_uid, {}).duplicate(true)
	if base_pet.is_empty():
		return {"ok": false, "reason": "base_missing"}
	var profile := GameData.get_species_synergy_profile(species_id)
	var evolution_chain: Array = profile.get("evolution_chain", [])
	var species_profile: Dictionary = DataRepository.get_species(species_id)
	var next_requirements := _get_next_evolution_requirements(species_id, species_profile)
	var next_star := star_level + 1
	var previous_name := String(base_pet.get("display_name", species_id))
	base_pet["star_level"] = next_star
	base_pet["bond_level"] = mini(6, int(base_pet.get("bond_level", 1)) + 1)
	var next_species_id := String(species_profile.get("evolution", {}).get("next_species_id", ""))
	if not next_species_id.is_empty() and _can_apply_species_evolution(base_pet, species_profile, next_requirements):
		base_pet["species_id"] = next_species_id
		if not bool(base_pet.get("nickname_locked", false)):
			base_pet["display_name"] = String(DataRepository.get_species(next_species_id).get("name", previous_name))
	if not bool(base_pet.get("nickname_locked", false)) and evolution_chain.size() >= next_star:
		base_pet["display_name"] = String(evolution_chain[next_star - 1])
	pet_states[base_uid] = _normalize_pet_state(base_pet)
	var growth_result := _resolve_pet_stage_growth_events(base_uid, next_star)
	for consume_uid in consume_uids:
		_erase_pet(consume_uid)
	_sync_roster_slots()
	var final_pet := get_pet(base_uid)
	register_species_seen(String(final_pet.get("species_id", species_id)))
	return {
		"ok": true,
		"species_id": species_id,
		"new_species_id": String(final_pet.get("species_id", species_id)),
		"pet_uid": base_uid,
		"old_star": star_level,
		"new_star": next_star,
		"old_name": previous_name,
		"new_name": String(final_pet.get("display_name", previous_name)),
		"known_skill_ids": get_pet_skill_ids(base_uid),
		"pending_skill_id": get_pet_pending_skill_id(base_uid),
		"growth_result": growth_result,
	}

func _get_next_evolution_requirements(species_id: String, species_profile: Dictionary) -> Dictionary:
	var evolution_info := DataRepository.get_evolution_by_species(species_id)
	var current_entry: Dictionary = evolution_info.get("entry", {})
	var family: Dictionary = evolution_info.get("family", {})
	var current_stage := int(current_entry.get("stage", species_profile.get("stage", 0)))
	for entry in family.get("entries", []):
		if int(entry.get("stage", 0)) == current_stage + 1:
			return entry.get("requirements", {}).duplicate(true)
	return {}

func _can_apply_species_evolution(pet: Dictionary, species_profile: Dictionary, next_requirements: Dictionary = {}) -> bool:
	var extra_condition_value = species_profile.get("evolution", {}).get("extra_condition", {})
	var extra_condition: Dictionary = extra_condition_value if typeof(extra_condition_value) == TYPE_DICTIONARY else {}
	var required_site := String(next_requirements.get("site", extra_condition.get("site", "")))
	var required_building := String(next_requirements.get("building", extra_condition.get("building", "")))
	var synergy_requirement := String(next_requirements.get("condition", extra_condition.get("synergy_requirement", "")))
	var bond_requirement := int(next_requirements.get("bond", extra_condition.get("bond_requirement", 0)))
	var home_id := String(pet.get("residence_habitat_id", ""))
	if not required_site.is_empty() and home_id != required_site:
		return false
	var building_site := required_site if not required_site.is_empty() else home_id
	if not required_building.is_empty():
		if building_site.is_empty():
			return false
		if get_building_level(building_site, required_building) <= 0:
			return false
	if bond_requirement > 0 and _bond_score_for_pet(pet) < bond_requirement:
		return false
	if not synergy_requirement.is_empty() and not _matches_evolution_synergy_requirement(synergy_requirement):
		return false
	return true

func _bond_score_for_pet(pet: Dictionary) -> int:
	return maxi(25, int(pet.get("bond_level", 1)) * 25)

func _matches_evolution_synergy_requirement(requirement_text: String) -> bool:
	var normalized := requirement_text.replace(" ", "")
	if normalized.is_empty():
		return true
	var counts := _build_active_species_tag_counts()
	for clause in normalized.split("且"):
		var clause_text := String(clause)
		if clause_text.is_empty():
			continue
		if not _matches_evolution_clause(clause_text, counts):
			return false
	return true

func _matches_evolution_clause(clause_text: String, counts: Dictionary) -> bool:
	if not clause_text.contains("≥"):
		return false
	var parts := clause_text.split("≥")
	if parts.size() < 2:
		return false
	var required_count := int(parts[1])
	for option in String(parts[0]).split("或"):
		if _evolution_requirement_count(String(option), counts) >= required_count:
			return true
	return false

func _build_active_species_tag_counts() -> Dictionary:
	var counts := {
		"types": {},
		"ecologies": {},
		"roles": {},
		"tags": {},
	}
	var seen_species := {}
	var source_uids: Array[String] = []
	for pet_uid in get_party_uids():
		source_uids.append(String(pet_uid))
	for pet_uid in get_reserve_uids():
		source_uids.append(String(pet_uid))
	for pet_uid in get_building_slot_uids():
		source_uids.append(String(pet_uid))
	for pet_uid in source_uids:
		var pet := get_pet(pet_uid)
		if pet.is_empty():
			continue
		var species_id := String(pet.get("species_id", ""))
		if species_id.is_empty() or seen_species.has(species_id):
			continue
		seen_species[species_id] = true
		var species_row := DataRepository.get_species(species_id)
		if species_row.is_empty():
			continue
		_increment_requirement_counts(counts["types"], species_row.get("types", []))
		_increment_requirement_counts(counts["ecologies"], species_row.get("ecology_tags", []))
		_increment_requirement_counts(counts["roles"], species_row.get("roles", []))
		var trait_tags: Array = []
		trait_tags.append_array(species_row.get("resident_tags", []))
		trait_tags.append_array(species_row.get("signature_tags", []))
		_increment_requirement_counts(counts["tags"], trait_tags)
	return counts

func _increment_requirement_counts(bucket: Dictionary, values: Array) -> void:
	var local_seen := {}
	for value in values:
		var tag_id := String(value)
		if tag_id.is_empty() or local_seen.has(tag_id):
			continue
		local_seen[tag_id] = true
		bucket[tag_id] = int(bucket.get(tag_id, 0)) + 1

func _evolution_requirement_count(token: String, counts: Dictionary) -> int:
	var mapped := _map_requirement_token(token)
	if mapped.is_empty():
		return 0
	var bucket_id := String(mapped.get("bucket", ""))
	var value_id := String(mapped.get("id", ""))
	return int(counts.get(bucket_id, {}).get(value_id, 0))

func _map_requirement_token(token: String) -> Dictionary:
	match token:
		"火系":
			return {"bucket": "types", "id": "fire"}
		"水系":
			return {"bucket": "types", "id": "water"}
		"电系":
			return {"bucket": "types", "id": "electric"}
		"草系":
			return {"bucket": "types", "id": "grass"}
		"岩系":
			return {"bucket": "types", "id": "rock"}
		"风系":
			return {"bucket": "types", "id": "wind"}
		"雾系":
			return {"bucket": "types", "id": "mist"}
		"念系":
			return {"bucket": "types", "id": "psychic"}
		"金属":
			return {"bucket": "types", "id": "metal"}
		"暗影":
			return {"bucket": "types", "id": "shadow"}
		"光系":
			return {"bucket": "types", "id": "light"}
		"岸线":
			return {"bucket": "ecologies", "id": "shore"}
		"森林":
			return {"bucket": "ecologies", "id": "forest"}
		"洞窟":
			return {"bucket": "ecologies", "id": "cave"}
		"异常":
			return {"bucket": "ecologies", "id": "anomaly"}
		"湿地":
			return {"bucket": "ecologies", "id": "wetland"}
		"风暴":
			return {"bucket": "ecologies", "id": "storm"}
		"火山":
			return {"bucket": "ecologies", "id": "volcanic"}
		"霜境":
			return {"bucket": "ecologies", "id": "frost"}
		"侦查", "scout":
			return {"bucket": "roles", "id": "scout"}
		"控制", "controller":
			return {"bucket": "roles", "id": "controller"}
		"修造", "builder":
			return {"bucket": "roles", "id": "builder"}
		"治疗", "healer":
			return {"bucket": "roles", "id": "healer"}
		"守护", "guardian":
			return {"bucket": "roles", "id": "guardian"}
		"先锋", "vanguard":
			return {"bucket": "roles", "id": "vanguard"}
		"输出", "striker":
			return {"bucket": "roles", "id": "striker"}
		"充能", "charger":
			return {"bucket": "roles", "id": "charger"}
		"净化", "purify":
			return {"bucket": "tags", "id": "purify"}
		_:
			return {}

func _erase_pet(pet_uid: String) -> void:
	if not pet_states.has(pet_uid):
		return
	for habitat_id in habitats.keys():
		var habitat_state: Dictionary = habitats[habitat_id]
		var changed := false
		for slot_key in ["resident_uid", "assistant_uid"]:
			if String(habitat_state.get(slot_key, "")) == pet_uid:
				habitat_state[slot_key] = ""
				changed = true
		if String(habitat_state.get("resident_actor_id", "")) == pet_uid:
			habitat_state["resident_actor_id"] = ""
			habitat_state["resident_actor_type"] = ""
		if changed:
			habitats[habitat_id] = habitat_state
	party_slots.erase(pet_uid)
	reserve_slots.erase(pet_uid)
	pet_states.erase(pet_uid)

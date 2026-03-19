extends Node

const GameData = preload("res://scripts/game_data.gd")

const DEFAULT_SEASON_ID := "spring"
const DEFAULT_SEASON_LENGTH := 6
const SEASON_ORDER := ["spring", "summer", "autumn", "winter"]
const META_SAVE_PATH := "user://meta_progression.save"
const RUN_SAVE_PATH := "user://run_state.save"
const SETTINGS_SAVE_PATH := "user://settings.save"
const WINDOWED_RESOLUTION_PRESETS := [
	{"id": "1280x720", "size": Vector2i(1280, 720), "label": "720p (1280 x 720)"},
	{"id": "1600x900", "size": Vector2i(1600, 900), "label": "900p (1600 x 900)"},
	{"id": "1920x1080", "size": Vector2i(1920, 1080), "label": "1080p (1920 x 1080)"},
	{"id": "2560x1440", "size": Vector2i(2560, 1440), "label": "1440p (2560 x 1440)"},
]
const DEFAULT_WINDOWED_RESOLUTION_ID := "1600x900"

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
var weekly_objective: Dictionary = {}
var weekly_progress: Dictionary = {}
var completed_seasons := 0
var exploration_points := 0
var exploration_points_total := 0
var completed_tutorials: Array[String] = []
var claimed_season_bosses: Array[String] = []
var meta_unlocks: Dictionary = {
	"tracks": [],
	"dice_modules": [],
}
var settings: Dictionary = {}

var inventory: Dictionary = {}
var habitats: Dictionary = {}
var pet_states: Dictionary = {}
var npc_trust: Dictionary = {}
var npc_duel_records: Dictionary = {}
var active_quests: Array[String] = []
var completed_quests: Array[String] = []
var discovered_species: Array[String] = []
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
var battle_slots: Array[String] = []
var backpack_slots: Array[String] = []
var backpack_capacity := 4
var wallet_gold := 12
var bank_gold := 0
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
	weekly_objective.clear()
	weekly_progress.clear()
	completed_seasons = 0
	exploration_points = 0
	claimed_season_bosses.clear()
	inventory = _default_inventory()
	habitats = _default_habitats()
	pet_states.clear()
	npc_trust.clear()
	npc_duel_records.clear()
	active_quests.clear()
	completed_quests.clear()
	discovered_species.clear()
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
	battle_slots.clear()
	backpack_slots.clear()
	backpack_capacity = 4
	wallet_gold = 12
	bank_gold = 0
	rival_wallets = {}
	ai_players = _build_default_ai_players()
	active_trait_runtime_bonus = {}
	active_trait_runtime_report = {"active": [], "nearby": []}
	trait_runtime_dirty = true
	quest_memory = _default_quest_memory()
	_pet_serial = 1
	_seed_companions()
	_recalculate_backpack_capacity()
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
	if bool(settings.get("fullscreen", false)):
		window.mode = Window.MODE_FULLSCREEN
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

func get_window_resolution_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	for preset in WINDOWED_RESOLUTION_PRESETS:
		presets.append(Dictionary(preset).duplicate(true))
	return presets

func get_available_window_resolution_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var usable_size := _current_screen_usable_size()
	for preset in WINDOWED_RESOLUTION_PRESETS:
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
	return Vector2i(preset.get("size", Vector2i(1600, 900)))

func current_window_resolution_label() -> String:
	var preset := _window_resolution_preset_from_id(current_window_resolution_id())
	if not preset.is_empty():
		return String(preset.get("label", current_window_resolution_id()))
	var size := current_window_resolution_size()
	return "%d x %d" % [size.x, size.y]

func should_skip_animations() -> bool:
	return DisplayServer.get_name() == "headless" or prefers_reduced_motion()

func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)

func save_run_payload(payload: Dictionary) -> void:
	var file := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: failed to open run save -> %s" % RUN_SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func load_run_payload() -> Dictionary:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return {}
	var raw := FileAccess.get_file_as_string(RUN_SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid run save, ignoring %s" % RUN_SAVE_PATH)
		return {}
	return Dictionary(parsed).duplicate(true)

func clear_run_save() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))

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

func _window_resolution_preset_from_id(resolution_id: String) -> Dictionary:
	for preset in WINDOWED_RESOLUTION_PRESETS:
		if String(preset.get("id", "")) == resolution_id:
			return Dictionary(preset).duplicate(true)
	return {}

func _best_fit_window_resolution_id() -> String:
	var screen_size := _current_screen_usable_size()
	if screen_size == Vector2i.ZERO:
		return DEFAULT_WINDOWED_RESOLUTION_ID
	var best_id := DEFAULT_WINDOWED_RESOLUTION_ID
	var best_area := 0
	for preset in WINDOWED_RESOLUTION_PRESETS:
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

func _clamp_windowed_resolution(size: Vector2i) -> Vector2i:
	var usable_size := _current_screen_usable_size()
	if usable_size == Vector2i.ZERO:
		return size
	return Vector2i(mini(size.x, usable_size.x), mini(size.y, usable_size.y))

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
		"weekly_objective": weekly_objective.duplicate(true),
		"weekly_progress": weekly_progress.duplicate(true),
		"completed_seasons": completed_seasons,
		"exploration_points": exploration_points,
		"claimed_season_bosses": claimed_season_bosses.duplicate(),
		"inventory": inventory.duplicate(true),
		"habitats": habitats.duplicate(true),
		"pet_states": pet_states.duplicate(true),
		"npc_trust": npc_trust.duplicate(true),
		"npc_duel_records": npc_duel_records.duplicate(true),
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"discovered_species": discovered_species.duplicate(),
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
		"battle_slots": battle_slots.duplicate(),
		"backpack_slots": backpack_slots.duplicate(),
		"backpack_capacity": backpack_capacity,
		"wallet_gold": wallet_gold,
		"bank_gold": bank_gold,
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
	weekly_objective = _duplicate_dictionary(snapshot.get("weekly_objective", {}))
	weekly_progress = _duplicate_dictionary(snapshot.get("weekly_progress", {}))
	completed_seasons = int(snapshot.get("completed_seasons", 0))
	exploration_points = int(snapshot.get("exploration_points", 0))
	claimed_season_bosses = _coerce_string_array(snapshot.get("claimed_season_bosses", []))
	inventory = _duplicate_dictionary(snapshot.get("inventory", {}))
	habitats = _duplicate_dictionary(snapshot.get("habitats", {}))
	pet_states = _duplicate_dictionary(snapshot.get("pet_states", {}))
	npc_trust = _duplicate_dictionary(snapshot.get("npc_trust", {}))
	npc_duel_records = _duplicate_dictionary(snapshot.get("npc_duel_records", {}))
	active_quests = _coerce_string_array(snapshot.get("active_quests", []))
	completed_quests = _coerce_string_array(snapshot.get("completed_quests", []))
	discovered_species = _coerce_string_array(snapshot.get("discovered_species", []))
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
	battle_slots = _coerce_string_array(snapshot.get("battle_slots", []))
	backpack_slots = _coerce_string_array(snapshot.get("backpack_slots", []))
	backpack_capacity = int(snapshot.get("backpack_capacity", 4))
	wallet_gold = int(snapshot.get("wallet_gold", 12))
	bank_gold = int(snapshot.get("bank_gold", 0))
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
	_recalculate_backpack_capacity()
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
		"cloth": 3,
		"ink": 2,
		"paper": 3,
	}

func _default_habitats() -> Dictionary:
	var result := {
		"mist_moss_cave": {
			"resident_uid": "",
			"assistant_uid": "",
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
	var level_key := "service_levels" if _uses_service_levels(habitat) else "building_levels"
	var building_ids: Array = habitat.get("buildings", [])
	if not building_ids.is_empty():
		var levels: Dictionary = merged.get(level_key, {})
		for building_id in building_ids:
			var id := String(building_id)
			if not levels.has(id):
				levels[id] = 0
		merged[level_key] = levels
	var stored_unlock := bool(merged.get("is_unlocked", _default_unlock_state(habitat_id, habitat)))
	merged["is_unlocked"] = stored_unlock
	merged["rank"] = _rank_from_state(merged)
	if not merged.has("last_visit_day"):
		merged["last_visit_day"] = -1
	return merged

func _build_default_habitat_state(habitat_id: String, habitat: Dictionary) -> Dictionary:
	var state := {
		"rank": 0,
		"last_visit_day": -1,
		"is_unlocked": _default_unlock_state(habitat_id, habitat),
	}
	if _uses_resident_slots(habitat):
		state["resident_uid"] = ""
		state["assistant_uid"] = ""
	var building_ids: Array = habitat.get("buildings", [])
	if not building_ids.is_empty():
		var levels := {}
		for building_id in building_ids:
			levels[String(building_id)] = 0
		if _uses_service_levels(habitat):
			state["service_levels"] = levels
		else:
			state["building_levels"] = levels
	return state

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

func _seed_companions() -> void:
	add_companion("steam_otter_1", "汐牙")
	add_companion("moss_deer_1", "苔角")
	add_companion("spark_mouse_1", "火花")

func add_companion(species_id: String, nickname: String = "") -> String:
	var profile := DataRepository.get_species(species_id)
	var uid := "pet_%03d" % _pet_serial
	_pet_serial += 1
	var display_name := nickname if not nickname.is_empty() else String(profile.get("name", species_id))
	pet_states[uid] = {
		"uid": uid,
		"species_id": species_id,
		"display_name": display_name,
		"nickname_locked": not nickname.is_empty(),
		"bond_level": 1,
		"star_level": 1,
		"residence_habitat_id": "",
		"temperament": String(profile.get("temperament", "")),
		"resident_tags": profile.get("resident_tags", []).duplicate(),
	}
	register_species_seen(species_id)
	add_journal_entry("新伙伴加入照料名册：%s。" % display_name)
	_sync_roster_slots()
	return uid

func get_companions() -> Array:
	var result: Array = []
	for pet in pet_states.values():
		result.append(pet)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("uid", "")) < String(b.get("uid", ""))
	)
	return result

func get_pet(pet_uid: String) -> Dictionary:
	return pet_states.get(pet_uid, {})

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
	habitat_state["rank"] = _rank_from_state(habitat_state)
	habitats[habitat_id] = habitat_state
	_recalculate_backpack_capacity()
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

func can_pay(cost: Dictionary) -> bool:
	for item_id in cost.keys():
		if int(inventory.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true

func pay_cost(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for item_id in cost.keys():
		inventory[item_id] = int(inventory.get(item_id, 0)) - int(cost[item_id])
	return true

func grant_items(reward_items: Dictionary) -> void:
	for item_id in reward_items.keys():
		inventory[item_id] = int(inventory.get(item_id, 0)) + int(reward_items[item_id])

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
	_recalculate_backpack_capacity()
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
	if weekly_turn > 5:
		weekly_turn = 1
		week_index += 1
		weekly_reroll_count = 0
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
		if String(habitats[habitat_id].get("resident_uid", "")) != "":
			total += 1
	return total

func get_care_progress() -> int:
	return get_settled_habitat_count() * 2 + bonded_species.size() * 2 + completed_quests.size() + get_habitat_rank_total() + badge_count

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

func mark_dojo_clear(dojo_id: String, tier: String, first_clear: bool) -> void:
	dojo_clear_flags["%s:%s" % [dojo_id, tier]] = true
	failed_dojo_streak = 0
	if first_clear:
		var dojo := DataRepository.get_dojo(dojo_id)
		var unlocks: Array = dojo.get("unlock_on_clear", {}).get(tier, [])
		for habitat_id in unlocks:
			unlock_habitat(String(habitat_id))
	refresh_season_unlocks()

func note_dojo_failure() -> void:
	failed_dojo_streak += 1

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

func _recalculate_backpack_capacity() -> void:
	var curve_entry := DataRepository.get_population_curve_entry(get_progression_rank())
	backpack_capacity = int(curve_entry.get("backpack_capacity", 4))

func _sync_roster_slots() -> void:
	trait_runtime_dirty = true
	var valid_uids := {}
	for companion in get_companions():
		valid_uids[String(companion.get("uid", ""))] = true
	var clean_battle: Array[String] = []
	for pet_uid in battle_slots:
		if valid_uids.has(pet_uid) and not clean_battle.has(pet_uid):
			clean_battle.append(pet_uid)
	var clean_backpack: Array[String] = []
	for pet_uid in backpack_slots:
		if valid_uids.has(pet_uid) and not clean_battle.has(pet_uid) and not clean_backpack.has(pet_uid):
			if _population_used_for_uids(clean_backpack) + _population_cost_for_uid(String(pet_uid)) <= backpack_capacity:
				clean_backpack.append(pet_uid)
	for companion in get_companions():
		var pet_uid := String(companion.get("uid", ""))
		if clean_battle.size() < 2 and not clean_battle.has(pet_uid):
			clean_battle.append(pet_uid)
			continue
		if not clean_battle.has(pet_uid) and not clean_backpack.has(pet_uid) and _population_used_for_uids(clean_backpack) + _population_cost_for_uid(pet_uid) <= backpack_capacity:
			clean_backpack.append(pet_uid)
	battle_slots = clean_battle
	backpack_slots = clean_backpack

func get_battle_party_uids() -> Array[String]:
	_sync_roster_slots()
	return battle_slots.duplicate()

func get_backpack_uids() -> Array[String]:
	_sync_roster_slots()
	return backpack_slots.duplicate()

func get_backpack_population_used() -> int:
	_sync_roster_slots()
	return _population_used_for_uids(backpack_slots)

func get_building_slot_uids() -> Array[String]:
	var result: Array[String] = []
	for habitat_state in habitats.values():
		for slot_key in ["resident_uid", "assistant_uid"]:
			var pet_uid := String(habitat_state.get(slot_key, ""))
			if pet_uid.is_empty() or result.has(pet_uid):
				continue
			result.append(pet_uid)
	return result

func set_battle_slot(slot_index: int, pet_uid: String) -> void:
	if not pet_states.has(pet_uid):
		return
	_sync_roster_slots()
	while battle_slots.size() <= slot_index:
		battle_slots.append("")
	var displaced_uid := String(battle_slots[slot_index])
	battle_slots[slot_index] = pet_uid
	for index in range(battle_slots.size()):
		if index == slot_index:
			continue
		if battle_slots[index] == pet_uid:
			battle_slots[index] = displaced_uid
			break
	_sync_roster_slots()

func toggle_backpack_slot(pet_uid: String) -> void:
	if not pet_states.has(pet_uid):
		return
	_sync_roster_slots()
	if battle_slots.has(pet_uid):
		return
	if backpack_slots.has(pet_uid):
		backpack_slots.erase(pet_uid)
	else:
		while not backpack_slots.is_empty() and get_backpack_population_used() + _population_cost_for_uid(pet_uid) > backpack_capacity:
			backpack_slots.pop_back()
		if get_backpack_population_used() + _population_cost_for_uid(pet_uid) <= backpack_capacity:
			backpack_slots.append(pet_uid)
	_sync_roster_slots()

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
	pet_states[base_uid] = base_pet
	for consume_uid in consume_uids:
		_erase_pet(consume_uid)
	_sync_roster_slots()
	register_species_seen(String(base_pet.get("species_id", species_id)))
	return {
		"ok": true,
		"species_id": species_id,
		"new_species_id": String(base_pet.get("species_id", species_id)),
		"pet_uid": base_uid,
		"old_star": star_level,
		"new_star": next_star,
		"old_name": previous_name,
		"new_name": String(base_pet.get("display_name", previous_name)),
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
	for pet_uid in get_battle_party_uids():
		source_uids.append(String(pet_uid))
	for pet_uid in get_backpack_uids():
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
		if changed:
			habitats[habitat_id] = habitat_state
	battle_slots.erase(pet_uid)
	backpack_slots.erase(pet_uid)
	pet_states.erase(pet_uid)

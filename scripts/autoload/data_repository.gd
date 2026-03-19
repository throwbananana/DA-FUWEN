extends Node

## 负责从 res://data/*.json 读取静态表。
## 使用 Godot 4 的 FileAccess 与 JSON.parse_string。
## 这个脚本适合作为 AutoLoad 单例：DataRepository

const DATA_ROOT := "res://data"

var habitats: Dictionary = {}
var species: Dictionary = {}
var npcs: Dictionary = {}
var buildings: Dictionary = {}
var encounters: Dictionary = {}
var quests: Dictionary = {}
var items: Dictionary = {}
var shop_definitions: Dictionary = {}
var season_rules: Dictionary = {}
var unlock_rules_by_habitat: Dictionary = {}
var dojos: Dictionary = {}
var reward_bundles: Dictionary = {}
var synergy_definitions: Dictionary = {}
var skill_library: Dictionary = {}
var evolution_families: Dictionary = {}
var evolution_by_species: Dictionary = {}
var progression_curves: Dictionary = {}
var events: Dictionary = {}
var dialogues: Dictionary = {}
var story_arcs: Dictionary = {}
var codex_entries: Dictionary = {}
var encyclopedia_entries: Dictionary = {}
var npc_routes: Array = []
var npc_routes_by_season: Dictionary = {}
var board_regions: Dictionary = {}
var board_regions_by_season: Dictionary = {}
var board_map_effects: Dictionary = {}
var node_decks_by_season: Dictionary = {}
var board_threats: Array = []
var board_threats_by_season: Dictionary = {}
var dice_modules: Dictionary = {}
var run_modifiers: Array = []
var weekly_objectives: Array = []
var weekly_objectives_by_season: Dictionary = {}
var season_boss_rules_by_season: Dictionary = {}
var meta_progression_tracks: Array = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	habitats = _index_by_id(_read_json("%s/habitats.json" % DATA_ROOT).get("habitats", []))
	habitats = _merge_indexed_rows(habitats, _read_json("%s/habitats_mda_expanded.json" % DATA_ROOT).get("habitats", []))
	species = _index_by_id(_read_json("%s/species.json" % DATA_ROOT).get("species", []))
	species = _merge_indexed_rows(species, _read_json("%s/species_mda120.json" % DATA_ROOT).get("species", []))
	npcs = _index_by_id(_read_json("%s/npc_profiles.json" % DATA_ROOT).get("npcs", []))
	buildings = _index_by_id(_read_json("%s/building_blueprints.json" % DATA_ROOT).get("buildings", []))
	buildings = _merge_indexed_rows(buildings, _read_json("%s/building_blueprints_mda.json" % DATA_ROOT).get("buildings", []))
	quests = _index_by_id(_read_json("%s/quest_templates.json" % DATA_ROOT).get("quests", []))
	items = _index_by_id(_read_json("%s/items.json" % DATA_ROOT).get("items", []))
	shop_definitions = _index_by_id(_read_json("%s/shop_rules.json" % DATA_ROOT).get("shops", []))
	events = _index_by_id(_read_json("%s/events.json" % DATA_ROOT).get("events", []))
	dialogues = _index_by_id(_read_json("%s/dialogues.json" % DATA_ROOT).get("dialogues", []))
	dialogues = _merge_indexed_rows(dialogues, _read_json("%s/story_dialogues.json" % DATA_ROOT).get("dialogues", []))
	story_arcs = _index_by_id(_read_json("%s/story_arcs.json" % DATA_ROOT).get("story_arcs", []))
	codex_entries = _index_by_id(_read_json("%s/codex_entries.json" % DATA_ROOT).get("codex_entries", []))
	encyclopedia_entries = _index_by_id(_read_json("%s/encyclopedia_entries.json" % DATA_ROOT).get("encyclopedia_entries", []))
	_load_npc_routes(_read_json("%s/npc_routes.json" % DATA_ROOT).get("routes", []))
	season_rules = _index_by_id(_read_json("%s/season_rules.json" % DATA_ROOT).get("seasons", []))
	_load_board_regions(_read_json("%s/board_regions.json" % DATA_ROOT).get("regions", []))
	board_map_effects = _index_by_id(_read_json("%s/board_map_effects.json" % DATA_ROOT).get("effects", []))
	_load_node_decks(_read_json("%s/node_decks.json" % DATA_ROOT).get("decks", []))
	_load_board_threats(_read_json("%s/board_threats.json" % DATA_ROOT).get("threats", []))
	dice_modules = _index_by_id(_read_json("%s/dice_modules.json" % DATA_ROOT).get("modules", []))
	run_modifiers = _read_json("%s/run_modifiers.json" % DATA_ROOT).get("modifiers", []).duplicate(true)
	_load_weekly_objectives(_read_json("%s/weekly_objectives.json" % DATA_ROOT).get("objectives", []))
	_load_season_boss_rules(_read_json("%s/season_boss_rules.json" % DATA_ROOT).get("bosses", []))
	meta_progression_tracks = _read_json("%s/meta_progression.json" % DATA_ROOT).get("tracks", []).duplicate(true)
	unlock_rules_by_habitat = _group_unlock_rules(_read_json("%s/habitat_unlock_rules.json" % DATA_ROOT).get("rules", []))
	dojos = _index_by_id(_read_json("%s/dojo_definitions.json" % DATA_ROOT).get("dojos", []))
	reward_bundles = _read_json("%s/reward_tables.json" % DATA_ROOT).get("reward_bundles", {})
	synergy_definitions = _read_json("%s/synergy_definitions_mda.json" % DATA_ROOT)
	skill_library = _index_by_id(_read_json("%s/skill_library_mda.json" % DATA_ROOT).get("skills", []))
	_build_evolution_indexes(_read_json("%s/evolution_chains_mda.json" % DATA_ROOT).get("families", []))
	progression_curves = _read_json("%s/progression_curves_mda.json" % DATA_ROOT)
	encounters.clear()
	for row in _read_json("%s/encounter_tables.json" % DATA_ROOT).get("encounters", []):
		encounters[String(row.get("habitat_id", ""))] = row
	for row in _read_json("%s/encounter_tables_mda.json" % DATA_ROOT).get("encounters", []):
		var habitat_id := String(row.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if encounters.has(habitat_id):
			encounters[habitat_id] = _deep_merge_dicts(encounters[habitat_id], row)
		else:
			encounters[habitat_id] = row

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataRepository: file not found -> %s" % path)
		return {}

	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataRepository: invalid json object -> %s" % path)
		return {}
	return parsed

func _index_by_id(rows: Array) -> Dictionary:
	var result := {}
	for row in rows:
		var id := String(row.get("id", ""))
		if id.is_empty():
			continue
		result[id] = row
	return result

func _group_unlock_rules(rows: Array) -> Dictionary:
	var result := {}
	for row in rows:
		var habitat_id := String(row.get("habitat_id", ""))
		if habitat_id.is_empty():
			continue
		if not result.has(habitat_id):
			result[habitat_id] = []
		result[habitat_id].append(row)
	for habitat_id in result.keys():
		result[habitat_id].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("priority", 0)) < int(b.get("priority", 0))
		)
	return result

func _load_board_regions(rows: Array) -> void:
	board_regions.clear()
	board_regions_by_season.clear()
	for row in rows:
		var region_id := String(row.get("id", ""))
		var season_id := String(row.get("season_id", ""))
		if region_id.is_empty():
			continue
		board_regions[region_id] = row
		if not season_id.is_empty():
			board_regions_by_season[season_id] = row

func _load_npc_routes(rows: Array) -> void:
	npc_routes = rows.duplicate(true)
	npc_routes_by_season.clear()
	for row in npc_routes:
		for season_id in row.get("season_ids", []):
			var key := String(season_id)
			if key.is_empty():
				continue
			if not npc_routes_by_season.has(key):
				npc_routes_by_season[key] = []
			npc_routes_by_season[key].append(row)

func _load_node_decks(rows: Array) -> void:
	node_decks_by_season.clear()
	for row in rows:
		var season_id := String(row.get("season_id", ""))
		if season_id.is_empty():
			continue
		node_decks_by_season[season_id] = row

func _load_board_threats(rows: Array) -> void:
	board_threats = rows.duplicate(true)
	board_threats_by_season.clear()
	for row in board_threats:
		var season_id := String(row.get("season_id", ""))
		if season_id.is_empty():
			continue
		if not board_threats_by_season.has(season_id):
			board_threats_by_season[season_id] = []
		board_threats_by_season[season_id].append(row)

func _load_weekly_objectives(rows: Array) -> void:
	weekly_objectives = rows.duplicate(true)
	weekly_objectives_by_season.clear()
	for row in weekly_objectives:
		for season_id in row.get("season_ids", []):
			var key := String(season_id)
			if key.is_empty():
				continue
			if not weekly_objectives_by_season.has(key):
				weekly_objectives_by_season[key] = []
			weekly_objectives_by_season[key].append(row)

func _load_season_boss_rules(rows: Array) -> void:
	season_boss_rules_by_season.clear()
	for row in rows:
		var season_id := String(row.get("season_id", ""))
		if season_id.is_empty():
			continue
		season_boss_rules_by_season[season_id] = row

func _merge_indexed_rows(base_index: Dictionary, rows: Array) -> Dictionary:
	var result: Dictionary = base_index.duplicate(true)
	for row in rows:
		var row_id := String(row.get("id", ""))
		if row_id.is_empty():
			continue
		if result.has(row_id):
			result[row_id] = _deep_merge_dicts(result[row_id], row)
		else:
			result[row_id] = row
	return result

func _deep_merge_dicts(base: Variant, extra: Variant) -> Variant:
	if typeof(base) != TYPE_DICTIONARY or typeof(extra) != TYPE_DICTIONARY:
		return extra
	var merged: Dictionary = Dictionary(base).duplicate(true)
	for key in Dictionary(extra).keys():
		if merged.has(key) and typeof(merged[key]) == TYPE_DICTIONARY and typeof(extra[key]) == TYPE_DICTIONARY:
			merged[key] = _deep_merge_dicts(merged[key], extra[key])
		else:
			merged[key] = extra[key]
	return merged

func _build_evolution_indexes(rows: Array) -> void:
	evolution_families.clear()
	evolution_by_species.clear()
	for family in rows:
		var family_id := String(family.get("family_id", ""))
		if family_id.is_empty():
			continue
		evolution_families[family_id] = family
		for entry in family.get("entries", []):
			var species_id := String(entry.get("species_id", ""))
			if species_id.is_empty():
				continue
			evolution_by_species[species_id] = {
				"family_id": family_id,
				"family": family,
				"entry": entry,
			}

func get_habitat(habitat_id: String) -> Dictionary:
	return habitats.get(habitat_id, {})

func get_species(species_id: String) -> Dictionary:
	return species.get(species_id, {})

func get_npc(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})

func get_building(building_id: String) -> Dictionary:
	return buildings.get(building_id, {})

func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})

func get_item(item_id: String) -> Dictionary:
	return Dictionary(items.get(item_id, {})).duplicate(true)

func get_shop(shop_id: String) -> Dictionary:
	return Dictionary(shop_definitions.get(shop_id, {})).duplicate(true)

func get_event(event_id: String) -> Dictionary:
	return events.get(event_id, {})

func get_dialogue(dialogue_id: String) -> Dictionary:
	return dialogues.get(dialogue_id, {})

func get_dialogues_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for dialogue in dialogues.values():
		if String(dialogue.get("npc", "")) != npc_id:
			continue
		result.append(Dictionary(dialogue).duplicate(true))
	return result

func get_events_for_habitat(habitat_id: String) -> Array:
	var result: Array = []
	for event_row in events.values():
		if String(event_row.get("habitat_id", "")) != habitat_id:
			continue
		result.append(Dictionary(event_row).duplicate(true))
	return result


func get_story_arc(story_arc_id: String) -> Dictionary:
	return Dictionary(story_arcs.get(story_arc_id, {})).duplicate(true)

func get_story_arcs() -> Array:
	var result: Array = []
	for arc in story_arcs.values():
		result.append(Dictionary(arc).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 1000))
		var priority_b := int(b.get("priority", 1000))
		if priority_a == priority_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return priority_a < priority_b
	)
	return result

func get_codex_entry(entry_id: String) -> Dictionary:
	return codex_entries.get(entry_id, {})

func get_encyclopedia_entry(entry_id: String) -> Dictionary:
	return encyclopedia_entries.get(entry_id, {})

func get_npc_routes_for_season(season_id: String) -> Array:
	return npc_routes_by_season.get(season_id, []).duplicate(true)

func get_season_rule(season_id: String) -> Dictionary:
	return season_rules.get(season_id, {})

func get_board_region(region_id: String) -> Dictionary:
	return board_regions.get(region_id, {})

func get_board_region_for_season(season_id: String) -> Dictionary:
	return board_regions_by_season.get(season_id, {})

func get_board_map_effect(effect_id: String) -> Dictionary:
	return board_map_effects.get(effect_id, {}).duplicate(true)

func get_node_deck_for_season(season_id: String) -> Dictionary:
	return node_decks_by_season.get(season_id, {})

func get_board_threats_for_season(season_id: String) -> Array:
	return board_threats_by_season.get(season_id, []).duplicate(true)

func get_unlock_rules_for_habitat(habitat_id: String) -> Array:
	return unlock_rules_by_habitat.get(habitat_id, []).duplicate(true)

func get_dojo(dojo_id: String) -> Dictionary:
	return dojos.get(dojo_id, {})

func get_reward_bundle(bundle_id: String) -> Dictionary:
	return reward_bundles.get(bundle_id, {})

func get_dice_module(module_id: String) -> Dictionary:
	return dice_modules.get(module_id, {})

func get_run_modifiers() -> Array:
	return run_modifiers.duplicate(true)

func get_weekly_objectives_for_season(season_id: String) -> Array:
	return weekly_objectives_by_season.get(season_id, []).duplicate(true)

func get_season_boss_rule(season_id: String) -> Dictionary:
	return season_boss_rules_by_season.get(season_id, {}).duplicate(true)

func get_meta_progression_tracks() -> Array:
	return meta_progression_tracks.duplicate(true)

func get_skill(skill_id: String) -> Dictionary:
	return skill_library.get(skill_id, {})

func get_evolution_family(family_id: String) -> Dictionary:
	return evolution_families.get(family_id, {})

func get_evolution_by_species(species_id: String) -> Dictionary:
	return evolution_by_species.get(species_id, {})

func get_population_curve() -> Array:
	return progression_curves.get("population_curve", []).duplicate(true)

func get_population_curve_entry(rank: int) -> Dictionary:
	var best_match: Dictionary = {}
	var best_rank := -1
	for row in progression_curves.get("population_curve", []):
		var row_rank := int(row.get("rank", 0))
		if row_rank == rank:
			return row
		if row_rank <= rank and row_rank > best_rank:
			best_match = row
			best_rank = row_rank
	return best_match

func get_shop_odds_entry(rank: int) -> Dictionary:
	var best_match: Dictionary = {}
	var best_rank := -1
	for row in progression_curves.get("shop_odds", []):
		var row_rank := int(row.get("rank", 0))
		if row_rank == rank:
			return row
		if row_rank <= rank and row_rank > best_rank:
			best_match = row
			best_rank = row_rank
	return best_match

func get_synergy_bucket(bucket_id: String) -> Dictionary:
	return synergy_definitions.get(bucket_id, {})

func get_habitat_npcs(habitat_id: String) -> Array:
	var result: Array = []
	for npc in npcs.values():
		if String(npc.get("home", "")) == habitat_id:
			result.append(npc)
		elif habitat_id in npc.get("route", []):
			result.append(npc)
	return result

func get_buildings_for_habitat(habitat_id: String) -> Array:
	var result: Array = []
	for building in buildings.values():
		if String(building.get("site", "")) == habitat_id:
			result.append(building)
	return result

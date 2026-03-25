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
var social_events: Dictionary = {}
var fishing_spots: Dictionary = {}
var aquatic_species: Dictionary = {}
var fishing_events: Dictionary = {}
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
var annual_competition_event: Dictionary = {}
var pet_growth_defaults: Dictionary = {}
var pet_growth_rules: Dictionary = {}

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
	quests = _merge_indexed_rows(quests, _read_json("%s/fishing_quest_templates.json" % DATA_ROOT).get("quests", []))
	items = _normalize_items(_index_by_id(_read_json("%s/items.json" % DATA_ROOT).get("items", [])))
	shop_definitions = _index_by_id(_read_json("%s/shop_rules.json" % DATA_ROOT).get("shops", []))
	events = _index_by_id(_read_json("%s/events.json" % DATA_ROOT).get("events", []))
	dialogues = _index_by_id(_read_json("%s/dialogues.json" % DATA_ROOT).get("dialogues", []))
	dialogues = _merge_indexed_rows(dialogues, _read_json("%s/story_dialogues.json" % DATA_ROOT).get("dialogues", []))
	story_arcs = _index_by_id(_read_json("%s/story_arcs.json" % DATA_ROOT).get("story_arcs", []))
	social_events = _index_by_id(_read_json("%s/social_events.json" % DATA_ROOT).get("social_events", []))
	fishing_spots = _index_by_id(_read_json("%s/fishing_spots.json" % DATA_ROOT).get("fishing_spots", []))
	aquatic_species = _index_by_id(_read_json("%s/aquatic_species.json" % DATA_ROOT).get("aquatic_species", []))
	fishing_events = _index_by_id(_read_json("%s/fishing_events.json" % DATA_ROOT).get("fishing_events", []))
	codex_entries = _index_by_id(_read_json("%s/codex_entries.json" % DATA_ROOT).get("codex_entries", []))
	codex_entries = _merge_indexed_rows(codex_entries, _read_json("%s/fishing_codex_entries.json" % DATA_ROOT).get("codex_entries", []))
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
	annual_competition_event = Dictionary(_read_json("%s/annual_competition_rules.json" % DATA_ROOT).get("event", {})).duplicate(true)
	unlock_rules_by_habitat = _group_unlock_rules(_read_json("%s/habitat_unlock_rules.json" % DATA_ROOT).get("rules", []))
	dojos = _index_by_id(_read_json("%s/dojo_definitions.json" % DATA_ROOT).get("dojos", []))
	reward_bundles = _read_json("%s/reward_tables.json" % DATA_ROOT).get("reward_bundles", {})
	synergy_definitions = _read_json("%s/synergy_definitions_mda.json" % DATA_ROOT)
	skill_library = _index_by_id(_read_json("%s/skill_library_mda.json" % DATA_ROOT).get("skills", []))
	var pet_growth_payload := _read_json("%s/pet_growth_rules.json" % DATA_ROOT)
	pet_growth_defaults = Dictionary(_deep_merge_dicts(_default_pet_growth_rule(), Dictionary(pet_growth_payload.get("defaults", {})).duplicate(true)))
	pet_growth_rules = _index_by_id(Array(pet_growth_payload.get("species_rules", [])))
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

func _normalize_items(source: Dictionary) -> Dictionary:
	var result := {}
	for item_id in source.keys():
		result[String(item_id)] = _normalize_item_row(Dictionary(source[item_id]).duplicate(true))
	return result

func _normalize_item_row(row: Dictionary) -> Dictionary:
	var normalized: Dictionary = Dictionary(row).duplicate(true)
	var item_type := String(normalized.get("type", "material"))
	if not normalized.has("stack_limit"):
		normalized["stack_limit"] = 99
	if not normalized.has("effect_id"):
		normalized["effect_id"] = "none"
	if not normalized.has("use_mode"):
		match item_type:
			"consumable":
				normalized["use_mode"] = "active"
			"tool":
				normalized["use_mode"] = "manual"
			_:
				normalized["use_mode"] = "passive"
	if not normalized.has("target_rule"):
		match String(normalized.get("effect_id", "none")):
			"add_bond_small":
				normalized["target_rule"] = "pet_single"
			"restore_hunger_small", "restore_hunger_medium":
				normalized["target_rule"] = "self_run"
			_:
				normalized["target_rule"] = "none"
	if not normalized.has("sell_price"):
		match item_type:
			"rare_material":
				normalized["sell_price"] = 12
			"material":
				normalized["sell_price"] = 4
			"consumable":
				normalized["sell_price"] = 8
			"tool":
				normalized["sell_price"] = 10
			"trophy":
				normalized["sell_price"] = 0
			_:
				normalized["sell_price"] = 0
	if not normalized.has("tags"):
		normalized["tags"] = []
	return normalized

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

func building_matches_habitat(building: Dictionary, habitat_id: String) -> bool:
	if building.is_empty() or habitat_id.is_empty():
		return false
	var direct_site := String(building.get("site", ""))
	if not direct_site.is_empty():
		return direct_site == habitat_id
	for raw_habitat_id in Array(building.get("sites", [])).duplicate(true):
		if String(raw_habitat_id) == habitat_id:
			return true
	var site_type := String(building.get("site_type", ""))
	if site_type.is_empty():
		return false
	return String(get_habitat(habitat_id).get("type", "")) == site_type

func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})

func get_item(item_id: String) -> Dictionary:
	return _normalize_item_row(Dictionary(items.get(item_id, {})).duplicate(true))

func get_items_by_types(types: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var item_ids: Array[String] = []
	for item_id in items.keys():
		item_ids.append(String(item_id))
	item_ids.sort()
	for item_id in item_ids:
		var item := get_item(item_id)
		if item.is_empty():
			continue
		if not types.has(String(item.get("type", ""))):
			continue
		rows.append(item)
	return rows

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

func get_social_event(social_event_id: String) -> Dictionary:
	return Dictionary(social_events.get(social_event_id, {})).duplicate(true)

func get_social_events_for_habitat(habitat_id: String) -> Array:
	var result: Array = []
	for social_event in social_events.values():
		if String(social_event.get("habitat_id", "")) != habitat_id:
			continue
		result.append(Dictionary(social_event).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var weight_a := int(a.get("weight", 1))
		var weight_b := int(b.get("weight", 1))
		if weight_a == weight_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return weight_a > weight_b
	)
	return result

func get_fishing_spot(habitat_id: String) -> Dictionary:
	return Dictionary(fishing_spots.get(habitat_id, {})).duplicate(true)

func get_aquatic_species(aquatic_species_id: String) -> Dictionary:
	return Dictionary(aquatic_species.get(aquatic_species_id, {})).duplicate(true)

func get_fishing_events_for_habitat(habitat_id: String) -> Array:
	var result: Array = []
	for fishing_event in fishing_events.values():
		var row: Dictionary = Dictionary(fishing_event).duplicate(true)
		var habitat_ids: Array = Array(row.get("habitat_ids", []))
		if not habitat_ids.is_empty() and not habitat_ids.has(habitat_id):
			continue
		if habitat_ids.is_empty() and String(row.get("habitat_id", "")) != habitat_id:
			continue
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var weight_a := int(a.get("weight", 1))
		var weight_b := int(b.get("weight", 1))
		if weight_a == weight_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return weight_a > weight_b
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

func get_annual_competition_event() -> Dictionary:
	return annual_competition_event.duplicate(true)

func get_skill(skill_id: String) -> Dictionary:
	return skill_library.get(skill_id, {})

func _default_pet_growth_rule() -> Dictionary:
	return {
		"starting_skill_count": 2,
		"max_skill_slots": 4,
		"stage_events": [
			{
				"stage": 2,
				"type": "learn_species_skill",
				"skill_slot": 3,
			},
			{
				"stage": 3,
				"type": "learn_species_skill",
				"skill_slot": 4,
			},
		],
	}

func get_pet_growth_rule(species_id: String) -> Dictionary:
	var rule: Dictionary = _default_pet_growth_rule().duplicate(true)
	rule = Dictionary(_deep_merge_dicts(rule, pet_growth_defaults))
	var override_rule: Dictionary = Dictionary(pet_growth_rules.get(species_id, {})).duplicate(true)
	var merged_events: Array = Array(rule.get("stage_events", [])).duplicate(true)
	merged_events.append_array(Array(override_rule.get("stage_events", [])))
	override_rule.erase("stage_events")
	rule = Dictionary(_deep_merge_dicts(rule, override_rule))
	rule["stage_events"] = merged_events
	return rule

func get_pet_skill_capacity(species_id: String) -> int:
	var rule := get_pet_growth_rule(species_id)
	return clampi(int(rule.get("max_skill_slots", 4)), 1, 4)

func get_pet_starting_skill_count(species_id: String) -> int:
	var rule := get_pet_growth_rule(species_id)
	return clampi(int(rule.get("starting_skill_count", 2)), 1, get_pet_skill_capacity(species_id))

func get_pet_species_skill_ids(species_id: String) -> Array[String]:
	var result: Array[String] = []
	for raw_skill_id in Array(get_species(species_id).get("skill_ids", [])):
		var skill_id := String(raw_skill_id)
		if skill_id.is_empty() or result.has(skill_id):
			continue
		result.append(skill_id)
	return result

func get_pet_stage_events(species_id: String, stage: int) -> Array:
	var result: Array = []
	for raw_event in Array(get_pet_growth_rule(species_id).get("stage_events", [])):
		var event: Dictionary = Dictionary(raw_event).duplicate(true)
		if int(event.get("stage", 0)) != stage:
			continue
		result.append(event)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(a.get("order", 0))
		var order_b := int(b.get("order", 0))
		if order_a == order_b:
			var type_a := String(a.get("type", ""))
			var type_b := String(b.get("type", ""))
			if type_a == type_b:
				return String(a.get("skill_id", a.get("target_species_id", ""))) < String(b.get("skill_id", b.get("target_species_id", "")))
			return type_a < type_b
		return order_a < order_b
	)
	return result

func get_evolution_family(family_id: String) -> Dictionary:
	return evolution_families.get(family_id, {})

func get_evolution_by_species(species_id: String) -> Dictionary:
	return evolution_by_species.get(species_id, {})

func get_population_curve() -> Array:
	var rows: Array = progression_curves.get("population_curve", []).duplicate(true)
	for index in range(rows.size()):
		var row: Dictionary = Dictionary(rows[index]).duplicate(true)
		if not row.has("pet_capacity"):
			row["pet_capacity"] = int(row.get("backpack_capacity", 4))
		rows[index] = row
	return rows

func get_population_curve_entry(rank: int) -> Dictionary:
	var best_match: Dictionary = {}
	var best_rank := -1
	for row in get_population_curve():
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
	var appended := {}
	var habitat := get_habitat(habitat_id)
	for raw_building_id in habitat.get("buildings", []):
		var building_id := String(raw_building_id)
		var building := get_building(building_id)
		if building.is_empty():
			continue
		if not building_matches_habitat(building, habitat_id):
			continue
		result.append(building)
		appended[building_id] = true
	var overflow_ids: Array[String] = []
	for building_id in buildings.keys():
		var id := String(building_id)
		if appended.has(id):
			continue
		if not building_matches_habitat(Dictionary(buildings[id]).duplicate(true), habitat_id):
			continue
		overflow_ids.append(id)
	overflow_ids.sort()
	for building_id in overflow_ids:
		result.append(get_building(building_id))
	return result

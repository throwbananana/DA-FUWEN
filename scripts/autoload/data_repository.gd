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
var codex_entries: Dictionary = {}
var encyclopedia_entries: Dictionary = {}

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
	events = _index_by_id(_read_json("%s/events.json" % DATA_ROOT).get("events", []))
	dialogues = _index_by_id(_read_json("%s/dialogues.json" % DATA_ROOT).get("dialogues", []))
	codex_entries = _index_by_id(_read_json("%s/codex_entries.json" % DATA_ROOT).get("codex_entries", []))
	encyclopedia_entries = _index_by_id(_read_json("%s/encyclopedia_entries.json" % DATA_ROOT).get("encyclopedia_entries", []))
	season_rules = _index_by_id(_read_json("%s/season_rules.json" % DATA_ROOT).get("seasons", []))
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

func get_event(event_id: String) -> Dictionary:
	return events.get(event_id, {})

func get_dialogue(dialogue_id: String) -> Dictionary:
	return dialogues.get(dialogue_id, {})

func get_codex_entry(entry_id: String) -> Dictionary:
	return codex_entries.get(entry_id, {})

func get_encyclopedia_entry(entry_id: String) -> Dictionary:
	return encyclopedia_entries.get(entry_id, {})

func get_season_rule(season_id: String) -> Dictionary:
	return season_rules.get(season_id, {})

func get_unlock_rules_for_habitat(habitat_id: String) -> Array:
	return unlock_rules_by_habitat.get(habitat_id, []).duplicate(true)

func get_dojo(dojo_id: String) -> Dictionary:
	return dojos.get(dojo_id, {})

func get_reward_bundle(bundle_id: String) -> Dictionary:
	return reward_bundles.get(bundle_id, {})

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

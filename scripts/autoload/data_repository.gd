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

func _ready() -> void:
	load_all()

func load_all() -> void:
	habitats = _index_by_id(_read_json("%s/habitats.json" % DATA_ROOT).get("habitats", []))
	species = _index_by_id(_read_json("%s/species.json" % DATA_ROOT).get("species", []))
	npcs = _index_by_id(_read_json("%s/npc_profiles.json" % DATA_ROOT).get("npcs", []))
	buildings = _index_by_id(_read_json("%s/building_blueprints.json" % DATA_ROOT).get("buildings", []))
	quests = _index_by_id(_read_json("%s/quest_templates.json" % DATA_ROOT).get("quests", []))
	items = _index_by_id(_read_json("%s/items.json" % DATA_ROOT).get("items", []))
	encounters.clear()
	for row in _read_json("%s/encounter_tables.json" % DATA_ROOT).get("encounters", []):
		encounters[String(row.get("habitat_id", ""))] = row

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

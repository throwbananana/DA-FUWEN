extends Node

const DEFAULT_SEASON_ID := "spring"
const DEFAULT_SEASON_LENGTH := 6

var season_id := DEFAULT_SEASON_ID
var weather_id := "clear"
var time_of_day := "day"
var day_index := 1
var season_length := DEFAULT_SEASON_LENGTH

var inventory: Dictionary = {}
var habitats: Dictionary = {}
var pet_states: Dictionary = {}
var npc_trust: Dictionary = {}
var active_quests: Array[String] = []
var completed_quests: Array[String] = []
var discovered_species: Array[String] = []
var bonded_species: Array[String] = []
var observed_species: Array[String] = []
var journal_entries: Array[String] = []
var visit_history: Array = []
var quest_memory: Dictionary = {}

var _pet_serial := 1

func _ready() -> void:
	reset_for_new_season()

func reset_for_new_season() -> void:
	season_id = DEFAULT_SEASON_ID
	weather_id = "clear"
	time_of_day = "day"
	day_index = 1
	season_length = DEFAULT_SEASON_LENGTH
	inventory = _default_inventory()
	habitats = _default_habitats()
	pet_states.clear()
	npc_trust.clear()
	active_quests.clear()
	completed_quests.clear()
	discovered_species.clear()
	bonded_species.clear()
	observed_species.clear()
	journal_entries.clear()
	visit_history.clear()
	quest_memory = {
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
	}
	_pet_serial = 1
	_seed_companions()

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
	return {
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

func _seed_companions() -> void:
	add_companion("shell_pup", "小壳")
	add_companion("moss_puff", "霜团")
	add_companion("gear_finch", "灰爪")

func add_companion(species_id: String, nickname: String = "") -> String:
	var profile := DataRepository.get_species(species_id)
	var uid := "pet_%03d" % _pet_serial
	_pet_serial += 1
	var display_name := nickname if not nickname.is_empty() else String(profile.get("name", species_id))
	pet_states[uid] = {
		"uid": uid,
		"species_id": species_id,
		"display_name": display_name,
		"bond_level": 1,
		"residence_habitat_id": "",
		"temperament": String(profile.get("temperament", "")),
		"resident_tags": profile.get("resident_tags", []).duplicate(),
	}
	register_species_seen(species_id)
	add_journal_entry("新伙伴加入照料名册：%s。" % display_name)
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
	var total := 0
	for value in building_levels.values():
		total += int(value)
	habitat_state["rank"] = total
	habitats[habitat_id] = habitat_state

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

func note_encounter(species_id: String) -> void:
	var encounters: Dictionary = quest_memory["encounter_species"]
	encounters[species_id] = true
	quest_memory["encounter_species"] = encounters
	register_species_seen(species_id)

func note_observe(species_id: String) -> void:
	var seen: Dictionary = quest_memory["observed_species"]
	seen[species_id] = true
	quest_memory["observed_species"] = seen
	if not observed_species.has(species_id):
		observed_species.append(species_id)
	register_species_seen(species_id)

func note_observe_marker(marker_id: String) -> void:
	var markers: Dictionary = quest_memory["observed_markers"]
	markers[marker_id] = true
	quest_memory["observed_markers"] = markers

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

func add_trust(npc_id: String, amount: int) -> void:
	npc_trust[npc_id] = int(npc_trust.get(npc_id, 0)) + amount

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

func accept_quest(quest_id: String) -> void:
	if completed_quests.has(quest_id) or active_quests.has(quest_id):
		return
	active_quests.append(quest_id)

func complete_quest(quest_id: String) -> void:
	active_quests.erase(quest_id)
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)

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

func advance_day() -> void:
	day_index += 1

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
	return get_settled_habitat_count() * 2 + bonded_species.size() * 2 + completed_quests.size() + get_habitat_rank_total()

func is_habitat_unlocked(habitat_id: String) -> bool:
	var habitat := DataRepository.get_habitat(habitat_id)
	if habitat.is_empty():
		return false
	var unlock_rule: Dictionary = habitat.get("unlock_rule", {})
	match String(unlock_rule.get("type", "default")):
		"default":
			return true
		"quest":
			return bool(habitats.get(habitat_id, {}).get("is_unlocked", false))
		"season_progress":
			return get_habitat_rank_total() >= int(unlock_rule.get("required_habitat_rank", 0)) \
				and get_total_trust() >= int(unlock_rule.get("required_trust_total", 0))
		_:
			return bool(habitats.get(habitat_id, {}).get("is_unlocked", false))

func record_visit(payload: Dictionary) -> void:
	visit_history.append(payload)

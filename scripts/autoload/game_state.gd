extends Node

const DEFAULT_SEASON_ID := "spring"
const DEFAULT_SEASON_LENGTH := 6
const SEASON_ORDER := ["spring", "summer", "autumn", "winter"]

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
var dojo_clear_flags: Dictionary = {}
var season_unlock_history: Dictionary = {}
var season_points := 0
var badge_count := 0
var failed_dojo_streak := 0
var current_available_habitats_cache: Array[String] = []

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
	dojo_clear_flags.clear()
	season_unlock_history.clear()
	season_points = 0
	badge_count = 0
	failed_dojo_streak = 0
	current_available_habitats_cache.clear()
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
	_sync_current_season_rule()
	refresh_season_unlocks()

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
	habitat_state["rank"] = _rank_from_state(habitat_state)
	habitats[habitat_id] = habitat_state
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
	refresh_season_unlocks()

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

func advance_day() -> void:
	day_index += 1

func advance_to_next_season() -> bool:
	var current_index := SEASON_ORDER.find(season_id)
	if current_index == -1 or current_index >= SEASON_ORDER.size() - 1:
		return false
	season_id = String(SEASON_ORDER[current_index + 1])
	day_index = 1
	weather_id = "clear"
	time_of_day = "day"
	failed_dojo_streak = 0
	_sync_current_season_rule()
	refresh_season_unlocks()
	return true

func _sync_current_season_rule() -> void:
	var season_rule := DataRepository.get_season_rule(season_id)
	season_length = int(season_rule.get("days", DEFAULT_SEASON_LENGTH))

func get_current_season_rule() -> Dictionary:
	return DataRepository.get_season_rule(season_id)

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
			return {
				"open": false,
				"reasons": ["完成委托 %s" % String(unlock_rule.get("quest_id", "未命名任务"))],
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

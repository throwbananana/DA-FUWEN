class_name NpcService
extends RefCounted

## 负责 NPC 好感、委托刷新与奖励发放。

const NpcRouteServiceScript = preload("res://scripts/services/npc_route_service.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")

const INTRO_DUEL_BASE_TRUST_WIN := 2
const INTRO_DUEL_BASE_TRUST_LOSE := 0
const INTRO_DUEL_ROUND_LIMIT := 5

var npc_route_service = NpcRouteServiceScript.new()

func get_visible_npcs(habitat_id: String) -> Array:
	return npc_route_service.get_visible_npcs(habitat_id)

func get_npc_trust(npc_id: String) -> int:
	return int(GameState.npc_trust.get(npc_id, 0))

func needs_intro_duel(npc_id: String) -> bool:
	return not GameState.has_completed_npc_intro_duel(npc_id)

func get_intro_duel_status(npc_id: String) -> Dictionary:
	var record := GameState.get_npc_duel_record(npc_id)
	return {
		"resolved": not record.is_empty(),
		"won": bool(record.get("won", false)),
		"base_trust": int(record.get("base_trust", 0))
	}

func prepare_intro_duel(npc_id: String, habitat_id: String) -> Dictionary:
	var npc := DataRepository.get_npc(npc_id)
	if npc.is_empty():
		return {"ok": false, "reason": "npc_missing"}

	if not needs_intro_duel(npc_id):
		return {"ok": false, "reason": "already_resolved", "status": get_intro_duel_status(npc_id)}

	if GameState.get_battle_party_uids().size() < 2:
		return {"ok": false, "reason": "battle_slots_missing"}

	var habitat := DataRepository.get_habitat(habitat_id)
	var enemy_species_ids := _pick_intro_duel_species_ids(habitat)
	if enemy_species_ids.is_empty():
		return {"ok": false, "reason": "enemy_pool_missing"}

	return {
		"ok": true,
		"npc_id": npc_id,
		"npc": npc,
		"habitat_id": habitat_id,
		"battle_config": {
			"title": "%s · 初见切磋" % String(npc.get("name", "初见者")),
			"subtitle": "第一次拜访前必须先决斗。\n胜利：基础信赖 %d ｜ 失败：基础信赖 %d" % [
				INTRO_DUEL_BASE_TRUST_WIN,
				INTRO_DUEL_BASE_TRUST_LOSE
			],
			"kind": "dojo",
			"allow_capture": false,
			"ally_first_round_attack_bonus": false,
			"ally_attack_bonus": 0,
			"ally_speed_bonus": 0,
			"ally_hp_bonus": 0,
			"ally_heal_bonus": 0,
			"ally_guard_bonus": 0.0,
			"enemy_attack_penalty": 0,
			"round_limit": INTRO_DUEL_ROUND_LIMIT,
			"allies": _build_allies(),
			"enemies": _build_intro_duel_enemies(npc, enemy_species_ids)
		}
	}

func resolve_intro_duel(npc_id: String, battle_result: Dictionary) -> Dictionary:
	var npc := DataRepository.get_npc(npc_id)
	if npc.is_empty():
		return {"ok": false, "reason": "npc_missing"}

	var player_won := bool(battle_result.get("player_won", false))
	var base_trust := INTRO_DUEL_BASE_TRUST_WIN if player_won else INTRO_DUEL_BASE_TRUST_LOSE
	var record := GameState.record_npc_intro_duel(npc_id, player_won, base_trust)
	var trust_now := get_npc_trust(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"npc": npc,
		"won": player_won,
		"base_trust": int(record.get("base_trust", base_trust)),
		"trust": trust_now,
		"unlocked": _collect_unlocked_rewards(npc, trust_now),
		"battle_result": battle_result
	}

func complete_trust_reward(npc_id: String, trust_gain: int) -> Dictionary:
	GameState.add_trust(npc_id, trust_gain)
	var npc := DataRepository.get_npc(npc_id)
	var trust_now := get_npc_trust(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"trust": trust_now,
		"unlocked": _collect_unlocked_rewards(npc, trust_now)
	}

func get_available_quests(habitat_id: String) -> Array:
	var result: Array = []
	var visible_givers := {}
	for npc in get_visible_npcs(habitat_id):
		visible_givers[String(npc.get("id", ""))] = true
	for quest in DataRepository.quests.values():
		var quest_id := String(quest.get("id", ""))
		if GameState.completed_quests.has(quest_id):
			continue
		if not visible_givers.has(String(quest.get("giver", ""))):
			continue
		result.append(quest)
	return result

func finish_quest(quest_id: String) -> Dictionary:
	var quest := DataRepository.get_quest(quest_id)
	if quest.is_empty():
		return {"ok": false, "reason": "quest_missing"}
	if GameState.completed_quests.has(quest_id):
		return {"ok": false, "reason": "already_completed"}

	var rewards: Dictionary = quest.get("rewards", {})
	var items: Dictionary = rewards.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)

	var trust_gain := int(rewards.get("trust", 0))
	var giver_id := String(quest.get("giver", ""))
	var trust_result := {}
	if trust_gain > 0 and not giver_id.is_empty():
		trust_result = complete_trust_reward(giver_id, trust_gain)

	if rewards.has("unlock_habitat"):
		var habitat_id := String(rewards["unlock_habitat"])
		GameState.unlock_habitat(habitat_id)

	GameState.complete_quest(quest_id)

	return {
		"ok": true,
		"quest_id": quest_id,
		"trust_result": trust_result,
		"items": items,
		"journal_entry": rewards.get("journal_entry", "")
	}

func _collect_unlocked_rewards(npc: Dictionary, trust_now: int) -> Array:
	var unlocked: Array = []
	var reward_map: Dictionary = npc.get("trust_rewards", {})
	for threshold in reward_map.keys():
		var threshold_value := int(threshold)
		if trust_now >= threshold_value:
			unlocked.append({
				"threshold": threshold_value,
				"reward": reward_map[threshold]
			})
	return unlocked

func _build_allies() -> Array:
	var allies: Array = []
	for pet_uid in GameState.get_battle_party_uids():
		var pet := GameState.get_pet(pet_uid)
		if pet.is_empty():
			continue
		var star_level := int(pet.get("star_level", 1))
		var level := _pet_level_for_battle(pet)
		var unit := MonsterInstance.new(String(pet.get("species_id", "")), level, star_level)
		unit.display_name = String(pet.get("display_name", unit.display_name))
		allies.append(unit)
	return allies

func _build_intro_duel_enemies(npc: Dictionary, enemy_species_ids: Array[String]) -> Array:
	var enemies: Array = []
	var duel_rank := maxi(1, GameState.get_progression_rank())
	var enemy_level := duel_rank + 1 if String(npc.get("role", "resident")) == "resident" else duel_rank
	var enemy_star := 2 if String(npc.get("role", "resident")) == "resident" else 1
	for species_id in enemy_species_ids:
		enemies.append(MonsterInstance.new(species_id, enemy_level, enemy_star))
		if enemies.size() >= 2:
			break
	if enemies.size() == 1:
		enemies.append(MonsterInstance.new(String(enemy_species_ids[0]), maxi(1, enemy_level - 1), enemy_star))
	return enemies

func _pick_intro_duel_species_ids(habitat: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for species_id in habitat.get("wild_pool", []):
		var species_key := String(species_id)
		if species_key.is_empty() or result.has(species_key):
			continue
		result.append(species_key)
		if result.size() >= 2:
			return result
	for pet_uid in GameState.get_battle_party_uids():
		var pet := GameState.get_pet(pet_uid)
		var species_key := String(pet.get("species_id", ""))
		if species_key.is_empty() or result.has(species_key):
			continue
		result.append(species_key)
		if result.size() >= 2:
			return result
	for species_id in DataRepository.species.keys():
		var species_key := String(species_id)
		if species_key.is_empty() or result.has(species_key):
			continue
		result.append(species_key)
		if result.size() >= 2:
			break
	return result

func _pet_level_for_battle(pet: Dictionary) -> int:
	var base_level := 1 + int(GameState.get_habitat_rank_total() / 2)
	base_level += int(pet.get("bond_level", 1)) - 1
	return clampi(base_level, 1, 6)

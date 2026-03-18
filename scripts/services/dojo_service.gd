class_name DojoService
extends RefCounted

const MonsterInstance = preload("res://scripts/monster_instance.gd")
const SynergyService = preload("res://scripts/services/synergy_service.gd")
const LocalizationService = preload("res://scripts/services/localization_service.gd")

var synergy_service := SynergyService.new()
var localization_service := LocalizationService.new()

func get_dojo_for_habitat(habitat_id: String) -> Dictionary:
	var habitat := DataRepository.get_habitat(habitat_id)
	var dojo_id := String(habitat.get("dojo_id", ""))
	if dojo_id.is_empty():
		return {}
	return DataRepository.get_dojo(dojo_id)

func get_dojo_menu(habitat_id: String) -> Dictionary:
	var dojo := get_dojo_for_habitat(habitat_id)
	if dojo.is_empty():
		return {}
	var synergy_report := synergy_service.build_synergy_report()
	var rounds: Array = []
	var round_defs: Array = dojo.get("rounds", [])
	var previous_cleared := true
	for round_def in round_defs:
		var tier := String(round_def.get("tier", ""))
		var already_cleared := GameState.has_cleared_dojo(String(dojo.get("id", "")), tier)
		var required_rank := _required_rank(dojo, tier)
		var affordable := GameState.can_pay(dojo.get("entry_cost", {}))
		var locked_by_progress := not previous_cleared
		var summary_parts := [
			localization_service.text("dojo.summary.recommended_rank", {"value": required_rank}),
			localization_service.text("dojo.summary.opponents", {"value": " / ".join(_enemy_names(round_def.get("enemy_pool", [])))}),
		]
		if already_cleared:
			summary_parts.append(localization_service.text("dojo.summary.first_clear"))
		elif locked_by_progress:
			summary_parts.append(localization_service.text("dojo.summary.require_previous"))
		elif not affordable:
			summary_parts.append(localization_service.text("dojo.summary.ticket_missing"))
		rounds.append({
			"id": tier,
			"label": _tier_name(tier),
			"summary": " ｜ ".join(summary_parts),
			"tooltip": localization_service.text("dojo.summary.modifiers", {"value": " / ".join(round_def.get("modifiers", []))}),
			"disabled": locked_by_progress,
		})
		previous_cleared = already_cleared
	return {
		"dojo": dojo,
		"choices": rounds,
		"entry_cost": dojo.get("entry_cost", {}),
		"hint": String(dojo.get("ui_hint", "")),
		"battle_slots": _battle_slot_names(),
		"backpack_summary": "%d / %d" % [GameState.get_backpack_population_used(), GameState.backpack_capacity],
		"synergy_lines": synergy_service.format_active_lines(synergy_report, 4),
		"nearby_synergy_lines": synergy_service.format_nearby_lines(synergy_report, 2),
		"building_lines": synergy_service.build_facility_bonus().get("lines", []),
	}

func attempt_dojo(dojo_id: String, tier: String) -> Dictionary:
	var dojo := DataRepository.get_dojo(dojo_id)
	if dojo.is_empty():
		return {"ok": false, "reason": "dojo_missing"}
	var round := _get_round(dojo, tier)
	if round.is_empty():
		return {"ok": false, "reason": "tier_missing"}
	if _is_locked_by_previous_tier(dojo, tier):
		return {"ok": false, "reason": "tier_locked"}
	var entry_cost: Dictionary = dojo.get("entry_cost", {})
	if not GameState.can_pay(entry_cost):
		return {"ok": false, "reason": "entry_cost_missing", "cost": entry_cost}
	if not GameState.pay_cost(entry_cost):
		return {"ok": false, "reason": "payment_failed", "cost": entry_cost}

	var challenge_score := _player_challenge_score(dojo, tier)
	var required_rank := _required_rank(dojo, tier)
	var success := challenge_score >= required_rank
	var first_clear := not GameState.has_cleared_dojo(dojo_id, tier)
	if success:
		var bundle_id := _reward_bundle_id(dojo, tier, first_clear)
		var reward_result := _apply_bundle(bundle_id)
		GameState.mark_dojo_clear(dojo_id, tier, first_clear)
		return {
			"ok": true,
			"success": true,
			"dojo": dojo,
			"tier": tier,
			"first_clear": first_clear,
			"challenge_score": challenge_score,
			"required_rank": required_rank,
			"reward_result": reward_result,
			"modifiers": round.get("modifiers", []),
		}

	GameState.note_dojo_failure()
	var consolation_bundle := String(dojo.get("failure_consolation", {}).get("bundle_id", ""))
	var consolation_result := _apply_bundle(consolation_bundle)
	return {
		"ok": true,
		"success": false,
		"dojo": dojo,
		"tier": tier,
		"first_clear": false,
		"challenge_score": challenge_score,
		"required_rank": required_rank,
		"reward_result": consolation_result,
		"modifiers": round.get("modifiers", []),
		"gap": maxi(required_rank - challenge_score, 1),
	}

func prepare_dojo_battle(dojo_id: String, tier: String) -> Dictionary:
	var dojo := DataRepository.get_dojo(dojo_id)
	if dojo.is_empty():
		return {"ok": false, "reason": "dojo_missing"}
	var round := _get_round(dojo, tier)
	if round.is_empty():
		return {"ok": false, "reason": "tier_missing"}
	if _is_locked_by_previous_tier(dojo, tier):
		return {"ok": false, "reason": "tier_locked"}
	var battle_uids := GameState.get_battle_party_uids()
	if battle_uids.size() < 2:
		return {"ok": false, "reason": "battle_slots_missing"}
	var entry_cost: Dictionary = dojo.get("entry_cost", {})
	if not GameState.can_pay(entry_cost):
		return {"ok": false, "reason": "entry_cost_missing", "cost": entry_cost}
	if not GameState.pay_cost(entry_cost):
		return {"ok": false, "reason": "payment_failed", "cost": entry_cost}
	var synergy_report := synergy_service.build_synergy_report()
	var facility_bonus := synergy_service.build_facility_bonus()
	var battle_bonus := synergy_service.merge_battle_bonus([
		synergy_service.build_battle_bonus(synergy_report),
		facility_bonus.get("bonus", {}),
	])
	var battle_bonus_lines := synergy_service.describe_battle_bonus(battle_bonus)
	var subtitle_lines: Array[String] = []
	subtitle_lines.append(localization_service.text("battle.subtitle.slots", {"value": " / ".join(_battle_slot_names())}))
	var active_lines := synergy_service.format_active_lines(synergy_report, 3)
	if not active_lines.is_empty():
		subtitle_lines.append(localization_service.text("battle.subtitle.synergy", {"value": " / ".join(active_lines)}))
	var facility_lines: Array = facility_bonus.get("lines", [])
	if not facility_lines.is_empty():
		subtitle_lines.append(localization_service.text("battle.subtitle.buildings", {"value": " / ".join(facility_lines.slice(0, 2))}))
	if not battle_bonus_lines.is_empty():
		subtitle_lines.append(localization_service.text("battle.subtitle.prebattle", {"value": " / ".join(battle_bonus_lines)}))
	return {
		"ok": true,
		"dojo": dojo,
		"tier": tier,
		"round": round,
		"synergy_report": synergy_report,
		"facility_bonus": facility_bonus,
		"battle_bonus": battle_bonus,
		"battle_config": {
			"title": "%s · %s" % [String(dojo.get("name", "试炼")), _tier_name(tier)],
			"subtitle": "\n".join(subtitle_lines),
			"kind": "dojo",
			"allow_capture": false,
			"ally_first_round_attack_bonus": int(battle_bonus.get("ally_attack_bonus", 0)) > 0,
			"ally_attack_bonus": int(battle_bonus.get("ally_attack_bonus", 0)),
			"ally_speed_bonus": int(battle_bonus.get("ally_speed_bonus", 0)),
			"ally_hp_bonus": int(battle_bonus.get("ally_hp_bonus", 0)),
			"ally_heal_bonus": int(battle_bonus.get("ally_heal_bonus", 0)),
			"ally_guard_bonus": float(battle_bonus.get("ally_guard_bonus", 0.0)),
			"enemy_attack_penalty": int(battle_bonus.get("enemy_attack_penalty", 0)),
			"round_limit": 7,
			"allies": _build_allies(),
			"enemies": _build_enemies(dojo, round, tier),
		},
	}

func resolve_dojo_battle(dojo_id: String, tier: String, battle_result: Dictionary) -> Dictionary:
	var dojo := DataRepository.get_dojo(dojo_id)
	if dojo.is_empty():
		return {"ok": false, "reason": "dojo_missing"}
	if bool(battle_result.get("player_won", false)):
		var first_clear := not GameState.has_cleared_dojo(dojo_id, tier)
		var bundle_id := _reward_bundle_id(dojo, tier, first_clear)
		var reward_result := _apply_bundle(bundle_id)
		GameState.mark_dojo_clear(dojo_id, tier, first_clear)
		return {
			"ok": true,
			"success": true,
			"dojo": dojo,
			"tier": tier,
			"first_clear": first_clear,
			"reward_result": reward_result,
			"battle_result": battle_result,
		}
	GameState.note_dojo_failure()
	var consolation_bundle := String(dojo.get("failure_consolation", {}).get("bundle_id", ""))
	var consolation_result := _apply_bundle(consolation_bundle)
	return {
		"ok": true,
		"success": false,
		"dojo": dojo,
		"tier": tier,
		"first_clear": false,
		"reward_result": consolation_result,
		"battle_result": battle_result,
	}

func _apply_bundle(bundle_id: String) -> Dictionary:
	if bundle_id.is_empty():
		return {"bundle_id": "", "items": {}, "systems": {}, "unlocks": []}
	var bundle := DataRepository.get_reward_bundle(bundle_id)
	if bundle.is_empty():
		return {"bundle_id": bundle_id, "items": {}, "systems": {}, "unlocks": []}
	var items: Dictionary = bundle.get("items", {})
	var systems: Dictionary = bundle.get("systems", {})
	var unlocks: Array = bundle.get("unlocks", [])
	if not items.is_empty():
		GameState.grant_items(items)
	if not systems.is_empty():
		GameState.apply_system_rewards(systems)
	for habitat_id in unlocks:
		GameState.unlock_habitat(String(habitat_id))
	return {
		"bundle_id": bundle_id,
		"items": items.duplicate(true),
		"systems": systems.duplicate(true),
		"unlocks": unlocks.duplicate(),
	}

func _player_challenge_score(dojo: Dictionary, tier: String) -> int:
	var synergy_report := synergy_service.build_synergy_report()
	var synergy_bonus := 0
	for entry in synergy_report.get("active", []):
		if String(entry.get("category", "")) == "elements":
			synergy_bonus += 1
	var location_id := String(dojo.get("location_id", ""))
	var local_rank := int(GameState.habitats.get(location_id, {}).get("rank", 0))
	var trust_bonus := mini(3, int(GameState.get_total_trust() / 2))
	var settle_bonus := mini(2, GameState.get_settled_habitat_count())
	var badge_bonus := mini(3, GameState.badge_count)
	var season_bonus := 1 if Array(dojo.get("season_tags", [])).has(GameState.season_id) else 0
	var tier_bonus := _tier_index(tier) - 1
	return maxi(1, GameState.get_habitat_rank_total() + local_rank + trust_bonus + settle_bonus + badge_bonus + season_bonus + synergy_bonus - tier_bonus)

func _reward_bundle_id(dojo: Dictionary, tier: String, first_clear: bool) -> String:
	var reward_key := "first_clear_rewards" if first_clear else "repeat_rewards"
	return String(dojo.get(reward_key, {}).get(tier, {}).get("bundle_id", ""))

func _get_round(dojo: Dictionary, tier: String) -> Dictionary:
	for round_def in dojo.get("rounds", []):
		if String(round_def.get("tier", "")) == tier:
			return round_def
	return {}

func _required_rank(dojo: Dictionary, tier: String) -> int:
	return int(dojo.get("recommended_rank", 1)) + _tier_index(tier) - 1

func _tier_index(tier: String) -> int:
	match tier:
		"tier_1":
			return 1
		"tier_2":
			return 2
		"tier_3":
			return 3
		_:
			return 1

func _tier_name(tier: String) -> String:
	match tier:
		"tier_1":
			return localization_service.text("dojo.tier_1")
		"tier_2":
			return localization_service.text("dojo.tier_2")
		"tier_3":
			return localization_service.text("dojo.tier_3")
		_:
			return tier

func _enemy_names(enemy_pool: Array) -> Array[String]:
	var result: Array[String] = []
	for species_id in enemy_pool:
		var profile := DataRepository.get_species(String(species_id))
		result.append(String(profile.get("name", species_id)))
	return result

func _battle_slot_names() -> Array[String]:
	var names: Array[String] = []
	for pet_uid in GameState.get_battle_party_uids():
		names.append(GameState.get_pet_display_name(pet_uid))
	return names

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

func _build_enemies(dojo: Dictionary, round: Dictionary, tier: String) -> Array:
	var enemies: Array = []
	var enemy_pool: Array = round.get("enemy_pool", [])
	for species_id in enemy_pool:
		var unit := MonsterInstance.new(String(species_id), _required_rank(dojo, tier) + 1, _tier_index(tier))
		enemies.append(unit)
		if enemies.size() >= 2:
			break
	if enemies.size() == 1 and not enemy_pool.is_empty():
		enemies.append(MonsterInstance.new(String(enemy_pool[0]), _required_rank(dojo, tier), _tier_index(tier)))
	return enemies

func _pet_level_for_battle(pet: Dictionary) -> int:
	var base_level := 1 + int(GameState.get_habitat_rank_total() / 2)
	base_level += int(pet.get("bond_level", 1)) - 1
	return clampi(base_level, 1, 6)

func _is_locked_by_previous_tier(dojo: Dictionary, tier: String) -> bool:
	var tier_index := _tier_index(tier)
	if tier_index <= 1:
		return false
	var previous_tier := "tier_%d" % (tier_index - 1)
	return not GameState.has_cleared_dojo(String(dojo.get("id", "")), previous_tier)

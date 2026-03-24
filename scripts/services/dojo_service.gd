class_name DojoService
extends RefCounted

const MonsterInstance = preload("res://scripts/monster_instance.gd")
const SynergyService = preload("res://scripts/services/synergy_service.gd")
const LocalizationService = preload("res://scripts/services/localization_service.gd")
const MinigameServiceScript = preload("res://scripts/services/minigame_service.gd")
const BattleRosterServiceScript = preload("res://scripts/services/battle_roster_service.gd")

var synergy_service := SynergyService.new()
var localization_service := LocalizationService.new()
var minigame_service := MinigameServiceScript.new()
var battle_roster_service := BattleRosterServiceScript.new()

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
	var battle_slots_ready := GameState.get_battle_party_uids().size() >= 2
	var backpack_summary := "%d / %d" % [GameState.get_backpack_population_used(), GameState.backpack_capacity]
	var rounds: Array = []
	var round_defs: Array = dojo.get("rounds", [])
	var previous_cleared := true
	for round_def in round_defs:
		var tier := String(round_def.get("tier", ""))
		var modifiers: Array = round_def.get("modifiers", [])
		var already_cleared := GameState.has_cleared_dojo(String(dojo.get("id", "")), tier)
		var required_rank := _required_rank(dojo, tier)
		var challenge_score := _player_challenge_score(dojo, tier)
		var score_gap := maxi(required_rank - challenge_score, 0)
		var affordable := GameState.can_pay(dojo.get("entry_cost", {}))
		var locked_by_progress := not previous_cleared
		var summary_parts := ["准备 %d / %d" % [challenge_score, required_rank]]
		if locked_by_progress:
			summary_parts.append(localization_service.text("dojo.summary.require_previous"))
		elif not battle_slots_ready:
			summary_parts.append("双打位未齐")
		elif not affordable:
			summary_parts.append(localization_service.text("dojo.summary.ticket_missing"))
		elif score_gap > 0:
			summary_parts.append("建议再补 %d 点" % score_gap)
		else:
			summary_parts.append("可以开打")
		summary_parts.append("已首通" if already_cleared else "首通未过")
		summary_parts.append(localization_service.text("dojo.summary.opponents", {"value": " / ".join(_enemy_names(round_def.get("enemy_pool", [])))}))
		var tooltip_lines: Array[String] = []
		tooltip_lines.append(localization_service.text("dojo.summary.recommended_rank", {"value": required_rank}))
		tooltip_lines.append("当前准备度 %d" % challenge_score)
		tooltip_lines.append("门票：%s" % _format_cost(dojo.get("entry_cost", {})))
		if not modifiers.is_empty():
			tooltip_lines.append(localization_service.text("dojo.summary.modifiers", {"value": " / ".join(modifiers)}))
		var first_reward_text := _preview_reward_bundle(_reward_bundle_id(dojo, tier, true))
		if not first_reward_text.is_empty():
			tooltip_lines.append("首通奖励：%s" % first_reward_text)
		var repeat_reward_text := _preview_reward_bundle(_reward_bundle_id(dojo, tier, false))
		if not repeat_reward_text.is_empty():
			tooltip_lines.append("复刷奖励：%s" % repeat_reward_text)
		var unlock_text := _preview_unlocks(dojo, tier)
		if not unlock_text.is_empty():
			tooltip_lines.append("通关开放：%s" % unlock_text)
		if score_gap > 0 and not locked_by_progress:
			tooltip_lines.append("还差约 %d 点准备度，建议先补据点等级、信赖或徽章。" % score_gap)
		rounds.append({
			"id": tier,
			"label": _tier_name(tier),
			"summary": " ｜ ".join(summary_parts),
			"tooltip": "\n".join(tooltip_lines),
			"disabled": locked_by_progress or not battle_slots_ready or not affordable,
			"challenge_score": challenge_score,
			"required_rank": required_rank,
			"gap": score_gap,
			"already_cleared": already_cleared,
		})
		previous_cleared = already_cleared
	return {
		"dojo": dojo,
		"choices": rounds,
		"entry_cost": dojo.get("entry_cost", {}),
		"hint": String(dojo.get("ui_hint", "")),
		"battle_slots": _battle_slot_names(),
		"battle_slots_ready": battle_slots_ready,
		"backpack_summary": backpack_summary,
		"reserve_summary": backpack_summary,
		"progression_rank": GameState.get_progression_rank(),
		"habitat_rank_total": GameState.get_habitat_rank_total(),
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
		var unlocked_traversal_skills := GameState.mark_dojo_clear(dojo_id, tier, first_clear)
		return {
			"ok": true,
			"success": true,
			"dojo": dojo,
			"tier": tier,
			"first_clear": first_clear,
			"challenge_score": challenge_score,
			"required_rank": required_rank,
			"reward_result": reward_result,
			"unlocked_traversal_skills": unlocked_traversal_skills,
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
	var base_battle_bonus := synergy_service.merge_battle_bonus([
		synergy_service.build_battle_bonus(synergy_report),
		facility_bonus.get("bonus", {}),
	])
	var battle_bonus := minigame_service.merge_with_pending_battle_bonus(base_battle_bonus)
	var battle_bonus_lines := synergy_service.describe_battle_bonus(battle_bonus)
	var subtitle_lines: Array[String] = []
	subtitle_lines.append(localization_service.text("battle.subtitle.slots", {"value": " / ".join(_battle_slot_names())}))
	var active_lines := synergy_service.format_active_lines(synergy_report, 3)
	if not active_lines.is_empty():
		subtitle_lines.append(localization_service.text("battle.subtitle.synergy", {"value": " / ".join(active_lines)}))
	var facility_lines: Array = facility_bonus.get("lines", [])
	if not facility_lines.is_empty():
		subtitle_lines.append(localization_service.text("battle.subtitle.buildings", {"value": " / ".join(facility_lines.slice(0, 2))}))
	var minigame_text := minigame_service.pending_bonus_summary()
	if not minigame_text.is_empty():
		subtitle_lines.append(minigame_text)
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
			"ally_first_round_attack_bonus": int(base_battle_bonus.get("ally_attack_bonus", 0)) > 0,
			"ally_attack_bonus": int(battle_bonus.get("ally_attack_bonus", 0)),
			"ally_speed_bonus": int(battle_bonus.get("ally_speed_bonus", 0)),
			"ally_hp_bonus": int(battle_bonus.get("ally_hp_bonus", 0)),
			"ally_heal_bonus": int(battle_bonus.get("ally_heal_bonus", 0)),
			"ally_guard_bonus": float(battle_bonus.get("ally_guard_bonus", 0.0)),
			"enemy_attack_penalty": int(battle_bonus.get("enemy_attack_penalty", 0)),
			"consume_minigame_bonus": minigame_service.has_pending_bonus(),
			"round_limit": 7,
			"allow_escape": false,
			"allies": _build_allies(),
			"ally_reserve": battle_roster_service.build_reserve_allies(),
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
		var unlocked_traversal_skills := GameState.mark_dojo_clear(dojo_id, tier, first_clear)
		return {
			"ok": true,
			"success": true,
			"dojo": dojo,
			"tier": tier,
			"first_clear": first_clear,
			"reward_result": reward_result,
			"unlocked_traversal_skills": unlocked_traversal_skills,
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

func _format_cost(cost: Dictionary) -> String:
	if Dictionary(cost).is_empty():
		return "无"
	var item_ids: Array[String] = []
	for item_id in cost.keys():
		item_ids.append(String(item_id))
	item_ids.sort()
	var parts: Array[String] = []
	for item_id in item_ids:
		var item := DataRepository.get_item(item_id)
		parts.append("%s x%d" % [String(item.get("name", item_id)), int(cost[item_id])])
	return " / ".join(parts)

func _preview_reward_bundle(bundle_id: String) -> String:
	if bundle_id.is_empty():
		return ""
	var bundle := DataRepository.get_reward_bundle(bundle_id)
	if bundle.is_empty():
		return ""
	var parts: Array[String] = []
	var items: Dictionary = bundle.get("items", {})
	if not items.is_empty():
		parts.append(_format_cost(items))
	var systems: Dictionary = bundle.get("systems", {})
	if int(systems.get("badge_count", 0)) > 0:
		parts.append("徽章 +%d" % int(systems.get("badge_count", 0)))
	if int(systems.get("season_points", 0)) > 0:
		parts.append("季节点 +%d" % int(systems.get("season_points", 0)))
	if int(systems.get("exploration_points", 0)) > 0:
		parts.append("探索点 +%d" % int(systems.get("exploration_points", 0)))
	return " / ".join(parts)

func _preview_unlocks(dojo: Dictionary, tier: String) -> String:
	var names: Array[String] = []
	for habitat_id in dojo.get("unlock_on_clear", {}).get(tier, []):
		var habitat := DataRepository.get_habitat(String(habitat_id))
		var habitat_name := String(habitat.get("name", habitat_id))
		if not habitat_name.is_empty() and not names.has(habitat_name):
			names.append(habitat_name)
	var reward_bundle := DataRepository.get_reward_bundle(_reward_bundle_id(dojo, tier, true))
	for habitat_id in reward_bundle.get("unlocks", []):
		var habitat := DataRepository.get_habitat(String(habitat_id))
		var habitat_name := String(habitat.get("name", habitat_id))
		if not habitat_name.is_empty() and not names.has(habitat_name):
			names.append(habitat_name)
	for skill_id in GameState.preview_dojo_traversal_skill_awards(String(dojo.get("id", "")), tier):
		var label := "通行技 %s" % GameState.get_traversal_skill_name(skill_id)
		if not names.has(label):
			names.append(label)
	return " / ".join(names)

func _battle_slot_names() -> Array[String]:
	var names: Array[String] = []
	for pet_uid in GameState.get_battle_party_uids():
		names.append(GameState.get_pet_display_name(pet_uid))
	return names

func _build_allies() -> Array:
	return battle_roster_service.build_active_allies()

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

class_name DojoService
extends RefCounted

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
	var rounds: Array = []
	var round_defs: Array = dojo.get("rounds", [])
	var previous_cleared := true
	for round_def in round_defs:
		var tier := String(round_def.get("tier", ""))
		var already_cleared := GameState.has_cleared_dojo(String(dojo.get("id", "")), tier)
		var required_rank := _required_rank(dojo, tier)
		var affordable := GameState.can_pay(dojo.get("entry_cost", {}))
		var locked_by_progress := not previous_cleared
		var summary := "推荐据点等级 %d ｜ 对手：%s" % [
			required_rank,
			" / ".join(_enemy_names(round_def.get("enemy_pool", []))),
		]
		if already_cleared:
			summary += " ｜ 已首通"
		elif locked_by_progress:
			summary += " ｜ 需先通过前一阶"
		elif not affordable:
			summary += " ｜ 缺少门票材料"
		rounds.append({
			"id": tier,
			"label": _tier_name(tier),
			"summary": summary,
			"tooltip": "修正：%s" % " / ".join(round_def.get("modifiers", [])),
			"disabled": locked_by_progress,
		})
		previous_cleared = already_cleared
	return {
		"dojo": dojo,
		"choices": rounds,
		"entry_cost": dojo.get("entry_cost", {}),
		"hint": String(dojo.get("ui_hint", "")),
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
	var location_id := String(dojo.get("location_id", ""))
	var local_rank := int(GameState.habitats.get(location_id, {}).get("rank", 0))
	var trust_bonus := mini(3, int(GameState.get_total_trust() / 2))
	var settle_bonus := mini(2, GameState.get_settled_habitat_count())
	var badge_bonus := mini(2, GameState.badge_count)
	var season_bonus := 1 if Array(dojo.get("season_tags", [])).has(GameState.season_id) else 0
	var tier_bonus := _tier_index(tier) - 1
	return maxi(1, GameState.get_habitat_rank_total() + local_rank + trust_bonus + settle_bonus + badge_bonus + season_bonus - tier_bonus)

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
			return "试炼一阶"
		"tier_2":
			return "试炼二阶"
		"tier_3":
			return "试炼三阶"
		_:
			return tier

func _enemy_names(enemy_pool: Array) -> Array[String]:
	var result: Array[String] = []
	for species_id in enemy_pool:
		var profile := DataRepository.get_species(String(species_id))
		result.append(String(profile.get("name", species_id)))
	return result

func _is_locked_by_previous_tier(dojo: Dictionary, tier: String) -> bool:
	var tier_index := _tier_index(tier)
	if tier_index <= 1:
		return false
	var previous_tier := "tier_%d" % (tier_index - 1)
	return not GameState.has_cleared_dojo(String(dojo.get("id", "")), previous_tier)

class_name AnnualCompetitionService
extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")

func get_event() -> Dictionary:
	return DataRepository.get_annual_competition_event()

func build_status_snapshot() -> Dictionary:
	var event := get_event()
	if event.is_empty():
		return {}
	var event_name := String(event.get("name", "岁末年赛"))
	var year_index := GameState.get_current_year_index()
	var current_result := GameState.get_annual_competition_result(year_index)
	if not current_result.is_empty():
		var placement := int(current_result.get("player_placement", 0))
		var reward_text := String(current_result.get("player_reward_text", ""))
		var summary := "本年%s：第 %d 名" % [event_name, placement]
		if not reward_text.is_empty():
			summary += "，获得 %s" % reward_text
		return {
			"state": "resolved",
			"summary": summary,
			"year_index": year_index,
			"event_name": event_name,
			"placement": placement,
		}
	if _is_reminder_active(event):
		var preview_text := _preview_roster_text(_build_player_units())
		var summary := "还有一个月，%s就会开赛；会自动征召当前出战与背包里的宠物参赛。" % event_name
		if not preview_text.is_empty():
			summary += " 当前预选：%s。" % preview_text
		return {
			"state": "reminder",
			"summary": summary,
			"year_index": year_index,
			"event_name": event_name,
		}
	return {
		"state": "upcoming",
		"summary": "本年结束时将举行 %s。" % event_name,
		"year_index": year_index,
		"event_name": event_name,
	}

func maybe_issue_month_reminder() -> Dictionary:
	var event := get_event()
	if event.is_empty() or not _is_reminder_active(event):
		return {}
	var year_index := GameState.get_current_year_index()
	if GameState.has_annual_competition_reminder(year_index):
		return {}
	GameState.mark_annual_competition_reminder(year_index)
	var event_name := String(event.get("name", "岁末年赛"))
	var preview_text := _preview_roster_text(_build_player_units())
	var lines: Array[String] = [
		"[b]%s 预告[/b]" % event_name,
		"还有一个月，所有远征队都会参加这场年终轮战。",
		"到时会自动从当前出战与背包里选出宠物，不需要手动报名。",
	]
	if not preview_text.is_empty():
		lines.append("当前预选：%s" % preview_text)
	lines.append("前三名会拿到更高奖金和奖品。")
	return {
		"ok": true,
		"year_index": year_index,
		"title": "%s 预告" % event_name,
		"body_lines": lines,
		"log_line": "年赛预告：还有一个月就会举行 %s，届时会自动征召当前出战与背包里的宠物参赛。" % event_name,
	}

func resolve_current_year() -> Dictionary:
	var event := get_event()
	if event.is_empty():
		return {"ok": false, "reason": "event_missing"}
	var year_index := GameState.get_current_year_index()
	var existing := GameState.get_annual_competition_result(year_index)
	if not existing.is_empty():
		existing["ok"] = true
		existing["reason"] = "already_resolved"
		return existing
	var player_units := _build_player_units()
	var entrants := _build_entrants(event, player_units)
	if entrants.size() < 2:
		return {"ok": false, "reason": "not_enough_entrants", "entrants": entrants}
	var scoreboard := _run_round_robin(entrants, year_index, event)
	var standings: Array = Array(scoreboard.get("standings", [])).duplicate(true)
	var player_placement := 0
	for standing in standings:
		var row: Dictionary = Dictionary(standing)
		if bool(row.get("is_player", false)):
			player_placement = int(row.get("placement", 0))
			break
	var reward := _reward_for_placement(event, player_placement)
	_apply_player_reward(reward)
	_apply_ai_rewards(standings, event)
	var result := {
		"ok": true,
		"year_index": year_index,
		"event_id": String(event.get("id", "grand_year_cup")),
		"event_name": String(event.get("name", "岁末年赛")),
		"player_placement": player_placement,
		"player_reward": reward.duplicate(true),
		"player_reward_text": _format_reward_text(reward),
		"leaderboard_lines": _build_leaderboard_lines(standings),
		"match_lines": Array(scoreboard.get("match_lines", [])).duplicate(),
		"standings": standings,
		"player_roster_text": _preview_roster_text(player_units),
		"player_unit_count": player_units.size(),
	}
	result["log_line"] = "岁末年赛落幕，你拿到第 %d 名%s。" % [
		player_placement,
		"，收下 %s" % String(result.get("player_reward_text", "")) if not String(result.get("player_reward_text", "")).is_empty() else "",
	]
	GameState.record_annual_competition_result(result)
	GameState.add_journal_entry("第 %d 年的 %s落幕，你拿到第 %d 名。" % [year_index, String(result.get("event_name", "岁末年赛")), player_placement])
	return result

func _is_reminder_active(event: Dictionary) -> bool:
	var reminder_season := String(event.get("reminder_season", "winter"))
	var year_index := GameState.get_current_year_index()
	return GameState.season_id == reminder_season and not GameState.has_annual_competition_result(year_index)

func _build_entrants(event: Dictionary, player_units: Array = []) -> Array:
	var entrants: Array = []
	if not player_units.is_empty():
		entrants.append(_build_player_entrant(player_units))
	entrants.append_array(_build_ai_entrants(event))
	return entrants

func _build_player_entrant(units: Array) -> Dictionary:
	var roster_power := 0
	for unit in units:
		roster_power += int(Dictionary(unit).get("power_score", 0))
	return {
		"id": "player",
		"name": "玩家",
		"is_player": true,
		"units": units.duplicate(true),
		"roster_power": roster_power,
	}

func _build_ai_entrants(event: Dictionary) -> Array:
	var entrants: Array = []
	var configured_rosters: Dictionary = Dictionary(event.get("ai_rosters", {})).duplicate(true)
	for rival_value in GameState.get_ai_players():
		var rival: Dictionary = Dictionary(rival_value).duplicate(true)
		var rival_id := String(rival.get("id", ""))
		if rival_id.is_empty():
			continue
		var personality_id := String(rival.get("personality_id", ""))
		var species_ids := _coerce_string_array(configured_rosters.get(personality_id, []))
		if species_ids.is_empty():
			continue
		var units: Array = []
		for index in range(species_ids.size()):
			var unit := _build_ai_unit(String(species_ids[index]), rival, index)
			if unit.is_empty():
				continue
			units.append(unit)
		if units.is_empty():
			continue
		var roster_power := 0
		for unit in units:
			roster_power += int(Dictionary(unit).get("power_score", 0))
		entrants.append({
			"id": rival_id,
			"name": String(rival.get("display_name", rival_id)),
			"is_player": false,
			"units": units,
			"roster_power": roster_power,
		})
	return entrants

func _build_player_units() -> Array:
	var units: Array = []
	var seen := {}
	for pet_uid in GameState.get_party_uids():
		var uid := String(pet_uid)
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		var unit := _build_player_unit(uid)
		if not unit.is_empty():
			units.append(unit)
	for pet_uid in GameState.get_reserve_uids():
		var uid := String(pet_uid)
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		var unit := _build_player_unit(uid)
		if not unit.is_empty():
			units.append(unit)
	return units

func _build_player_unit(pet_uid: String) -> Dictionary:
	var pet := GameState.get_pet(pet_uid)
	if pet.is_empty():
		return {}
	var species_id := String(pet.get("species_id", ""))
	var species := DataRepository.get_species(species_id)
	if species.is_empty():
		return {}
	var star_level := clampi(int(pet.get("star_level", 1)), 1, 3)
	var bond_level := maxi(1, int(pet.get("bond_level", 1)))
	var skill_count := maxi(1, GameState.get_pet_skill_ids(pet_uid).size())
	var level := maxi(2, GameState.get_progression_rank() + star_level - 1 + int(bond_level / 2))
	var instance := MonsterInstance.new(species_id, level, star_level)
	return {
		"id": pet_uid,
		"display_name": String(pet.get("display_name", species.get("name", species_id))),
		"species_id": species_id,
		"level": level,
		"star_level": star_level,
		"bond_level": bond_level,
		"skill_count": skill_count,
		"max_hp": instance.max_hp,
		"attack": instance.attack,
		"speed": instance.speed,
		"power_score": _power_score(instance, bond_level, skill_count),
	}

func _build_ai_unit(species_id: String, rival: Dictionary, slot_index: int) -> Dictionary:
	var species := DataRepository.get_species(species_id)
	if species.is_empty():
		return {}
	var personality_id := String(rival.get("personality_id", ""))
	var stage := clampi(int(species.get("stage", 1)), 1, 3)
	var bond_level := 3 + mini(2, int(GameData.get_ai_weight(personality_id, "battle") / 3))
	var level := maxi(2, GameState.get_progression_rank() + 1 + slot_index / 2 + int(rival.get("prestige", 0)) / 3)
	var skill_count := maxi(2, mini(4, DataRepository.get_pet_species_skill_ids(species_id).size()))
	var instance := MonsterInstance.new(species_id, level, stage)
	return {
		"id": "%s:%s:%d" % [String(rival.get("id", "rival")), species_id, slot_index],
		"display_name": String(species.get("name", species_id)),
		"species_id": species_id,
		"level": level,
		"star_level": stage,
		"bond_level": bond_level,
		"skill_count": skill_count,
		"max_hp": instance.max_hp,
		"attack": instance.attack,
		"speed": instance.speed,
		"power_score": _power_score(instance, bond_level, skill_count),
	}

func _power_score(instance: MonsterInstance, bond_level: int, skill_count: int) -> int:
	return int(instance.max_hp * 2 + instance.attack * 6 + instance.speed * 4 + bond_level * 3 + skill_count * 5)

func _run_round_robin(entrants: Array, year_index: int, event: Dictionary) -> Dictionary:
	var standings_by_id := {}
	for entrant_value in entrants:
		var entrant: Dictionary = Dictionary(entrant_value).duplicate(true)
		standings_by_id[String(entrant.get("id", ""))] = {
			"entrant_id": String(entrant.get("id", "")),
			"name": String(entrant.get("name", "")),
			"is_player": bool(entrant.get("is_player", false)),
			"wins": 0,
			"losses": 0,
			"match_points": 0,
			"unit_diff": 0,
			"hp_left": 0,
			"roster_power": int(entrant.get("roster_power", 0)),
		}
	var match_lines: Array[String] = []
	var pair_index := 0
	for left_index in range(entrants.size()):
		for right_index in range(left_index + 1, entrants.size()):
			var left_entrant: Dictionary = Dictionary(entrants[left_index]).duplicate(true)
			var right_entrant: Dictionary = Dictionary(entrants[right_index]).duplicate(true)
			var match_result := _simulate_match(left_entrant, right_entrant, year_index, pair_index, event)
			pair_index += 1
			match_lines.append(String(match_result.get("summary_line", "")))
			var winner_id := String(match_result.get("winner_id", ""))
			var loser_id := String(match_result.get("loser_id", ""))
			if standings_by_id.has(winner_id):
				var winner_row: Dictionary = Dictionary(standings_by_id[winner_id]).duplicate(true)
				winner_row["wins"] = int(winner_row.get("wins", 0)) + 1
				winner_row["match_points"] = int(winner_row.get("match_points", 0)) + 3
				winner_row["unit_diff"] = int(winner_row.get("unit_diff", 0)) + int(match_result.get("winner_unit_diff", 0))
				winner_row["hp_left"] = int(winner_row.get("hp_left", 0)) + int(match_result.get("winner_hp_left", 0))
				standings_by_id[winner_id] = winner_row
			if standings_by_id.has(loser_id):
				var loser_row: Dictionary = Dictionary(standings_by_id[loser_id]).duplicate(true)
				loser_row["losses"] = int(loser_row.get("losses", 0)) + 1
				loser_row["unit_diff"] = int(loser_row.get("unit_diff", 0)) - int(match_result.get("winner_unit_diff", 0))
				standings_by_id[loser_id] = loser_row
	var standings: Array = []
	for row in standings_by_id.values():
		standings.append(Dictionary(row).duplicate(true))
	standings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("wins", 0)) != int(b.get("wins", 0)):
			return int(a.get("wins", 0)) > int(b.get("wins", 0))
		if int(a.get("unit_diff", 0)) != int(b.get("unit_diff", 0)):
			return int(a.get("unit_diff", 0)) > int(b.get("unit_diff", 0))
		if int(a.get("hp_left", 0)) != int(b.get("hp_left", 0)):
			return int(a.get("hp_left", 0)) > int(b.get("hp_left", 0))
		if int(a.get("roster_power", 0)) != int(b.get("roster_power", 0)):
			return int(a.get("roster_power", 0)) > int(b.get("roster_power", 0))
		if bool(a.get("is_player", false)) != bool(b.get("is_player", false)):
			return bool(a.get("is_player", false))
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	for index in range(standings.size()):
		var standing: Dictionary = Dictionary(standings[index]).duplicate(true)
		standing["placement"] = index + 1
		standings[index] = standing
	return {
		"standings": standings,
		"match_lines": match_lines,
	}

func _simulate_match(left_entrant: Dictionary, right_entrant: Dictionary, year_index: int, pair_index: int, event: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var seed_text := "%d|%d|%s|%s" % [year_index, pair_index, String(left_entrant.get("id", "")), String(right_entrant.get("id", ""))]
	rng.seed = int(seed_text.hash())
	var left_units := _instantiate_competition_units(Array(left_entrant.get("units", [])).duplicate(true))
	var right_units := _instantiate_competition_units(Array(right_entrant.get("units", [])).duplicate(true))
	var left_index := 0
	var right_index := 0
	var duel_turn_limit := maxi(6, int(event.get("duel_turn_limit", 14)))
	while left_index < left_units.size() and right_index < right_units.size():
		var left_instance: MonsterInstance = left_units[left_index]
		var right_instance: MonsterInstance = right_units[right_index]
		var left_info: Dictionary = Dictionary(left_entrant.get("units", [])[left_index]).duplicate(true)
		var right_info: Dictionary = Dictionary(right_entrant.get("units", [])[right_index]).duplicate(true)
		_resolve_unit_duel(left_instance, left_info, right_instance, right_info, rng, duel_turn_limit)
		if left_instance.is_alive() and not right_instance.is_alive():
			left_instance.heal(2 + mini(2, int(left_info.get("bond_level", 1)) / 3))
		elif right_instance.is_alive() and not left_instance.is_alive():
			right_instance.heal(2 + mini(2, int(right_info.get("bond_level", 1)) / 3))
		if not left_instance.is_alive():
			left_index += 1
		if not right_instance.is_alive():
			right_index += 1
	var left_remaining_units := _count_alive_units(left_units)
	var right_remaining_units := _count_alive_units(right_units)
	var left_hp_left := _total_hp_left(left_units)
	var right_hp_left := _total_hp_left(right_units)
	var left_wins := left_remaining_units > right_remaining_units or (left_remaining_units == right_remaining_units and left_hp_left >= right_hp_left)
	var winner_id := String(left_entrant.get("id", "")) if left_wins else String(right_entrant.get("id", ""))
	var loser_id := String(right_entrant.get("id", "")) if left_wins else String(left_entrant.get("id", ""))
	var winner_name := String(left_entrant.get("name", "")) if left_wins else String(right_entrant.get("name", ""))
	var loser_name := String(right_entrant.get("name", "")) if left_wins else String(left_entrant.get("name", ""))
	var winner_units := left_remaining_units if left_wins else right_remaining_units
	var loser_units := right_remaining_units if left_wins else left_remaining_units
	var winner_hp_left := left_hp_left if left_wins else right_hp_left
	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"winner_unit_diff": maxi(1, winner_units - loser_units),
		"winner_hp_left": winner_hp_left,
		"summary_line": "%s 击败 %s（剩余 %d 只，余血 %d）" % [winner_name, loser_name, winner_units, winner_hp_left],
	}

func _instantiate_competition_units(unit_infos: Array) -> Array:
	var instances: Array = []
	for unit_info_value in unit_infos:
		var unit_info: Dictionary = Dictionary(unit_info_value).duplicate(true)
		instances.append(MonsterInstance.new(
			String(unit_info.get("species_id", "")),
			int(unit_info.get("level", 1)),
			int(unit_info.get("star_level", 1))
		))
	return instances

func _resolve_unit_duel(left_instance: MonsterInstance, left_info: Dictionary, right_instance: MonsterInstance, right_info: Dictionary, rng: RandomNumberGenerator, duel_turn_limit: int) -> void:
	var turn_index := 0
	while left_instance.is_alive() and right_instance.is_alive() and turn_index < duel_turn_limit:
		var left_initiative := left_instance.speed + int(left_info.get("bond_level", 1)) / 2 + rng.randi_range(0, 2)
		var right_initiative := right_instance.speed + int(right_info.get("bond_level", 1)) / 2 + rng.randi_range(0, 2)
		if left_initiative >= right_initiative:
			_apply_duel_strike(left_instance, left_info, right_instance, rng)
			if right_instance.is_alive():
				_apply_duel_strike(right_instance, right_info, left_instance, rng)
		else:
			_apply_duel_strike(right_instance, right_info, left_instance, rng)
			if left_instance.is_alive():
				_apply_duel_strike(left_instance, left_info, right_instance, rng)
		turn_index += 1
	if left_instance.is_alive() and right_instance.is_alive():
		var left_score := left_instance.current_hp + left_instance.speed + int(left_info.get("power_score", 0)) / 10
		var right_score := right_instance.current_hp + right_instance.speed + int(right_info.get("power_score", 0)) / 10
		if left_score >= right_score:
			right_instance.take_damage(right_instance.current_hp)
		else:
			left_instance.take_damage(left_instance.current_hp)

func _apply_duel_strike(attacker: MonsterInstance, attacker_info: Dictionary, defender: MonsterInstance, rng: RandomNumberGenerator) -> void:
	var skill_bonus := maxi(0, int(attacker_info.get("skill_count", 2)) - 2)
	var bond_bonus := maxi(0, int(attacker_info.get("bond_level", 1)) - 1)
	var type_multiplier := GameData.type_multiplier(String(attacker.type), String(defender.type))
	var variance := 0.92 + rng.randf() * 0.16
	var raw_damage := (float(attacker.attack) * 1.35 + float(attacker.speed) * 0.45 + float(skill_bonus) * 1.6 + float(bond_bonus) * 0.55) * type_multiplier * variance
	var damage := maxi(1, int(round(raw_damage)))
	defender.take_damage(damage)

func _count_alive_units(instances: Array) -> int:
	var total := 0
	for instance_value in instances:
		var instance: MonsterInstance = instance_value
		if instance.is_alive():
			total += 1
	return total

func _total_hp_left(instances: Array) -> int:
	var total := 0
	for instance_value in instances:
		var instance: MonsterInstance = instance_value
		total += maxi(0, instance.current_hp)
	return total

func _reward_for_placement(event: Dictionary, placement: int) -> Dictionary:
	var rewards: Dictionary = Dictionary(event.get("placement_rewards", {})).duplicate(true)
	var reward: Dictionary = Dictionary(rewards.get(str(placement), rewards.get("default", {}))).duplicate(true)
	if not reward.has("gold"):
		reward["gold"] = 0
	if not reward.has("items"):
		reward["items"] = {}
	return reward

func _apply_player_reward(reward: Dictionary) -> void:
	var items: Dictionary = Dictionary(reward.get("items", {})).duplicate(true)
	if not items.is_empty():
		GameState.grant_items(items)
	var gold := int(reward.get("gold", 0))
	if gold > 0:
		GameState.add_wallet_gold(gold)

func _apply_ai_rewards(standings: Array, event: Dictionary) -> void:
	var players := GameState.get_ai_players()
	if players.is_empty():
		return
	var placements := {}
	for row_value in standings:
		var row: Dictionary = Dictionary(row_value).duplicate(true)
		placements[String(row.get("entrant_id", ""))] = int(row.get("placement", 0))
	var updated_players: Array = players.duplicate(true)
	for index in range(updated_players.size()):
		var rival: Dictionary = Dictionary(updated_players[index]).duplicate(true)
		var rival_id := String(rival.get("id", ""))
		var placement := int(placements.get(rival_id, 0))
		if placement <= 0:
			continue
		var reward := _reward_for_placement(event, placement)
		rival["gold"] = int(rival.get("gold", 0)) + maxi(2, int(reward.get("gold", 0)) / 2)
		rival["prestige"] = int(rival.get("prestige", 0)) + maxi(1, 5 - placement)
		rival["latest_action_short"] = "年赛第 %d" % placement
		rival["latest_action"] = "%s 在 %s 里拿到第 %d 名。" % [
			String(rival.get("display_name", rival_id)),
			String(event.get("name", "岁末年赛")),
			placement,
		]
		updated_players[index] = rival
	GameState.set_ai_players(updated_players)

func _build_leaderboard_lines(standings: Array) -> Array[String]:
	var lines: Array[String] = []
	for row_value in standings:
		var row: Dictionary = Dictionary(row_value).duplicate(true)
		lines.append("%d.%s %d胜%d负" % [
			int(row.get("placement", 0)),
			String(row.get("name", "")),
			int(row.get("wins", 0)),
			int(row.get("losses", 0)),
		])
	return lines

func _format_reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	var title := String(reward.get("title", ""))
	if not title.is_empty():
		parts.append(title)
	var gold := int(reward.get("gold", 0))
	if gold > 0:
		parts.append("%d 金" % gold)
	var item_text := _format_items(Dictionary(reward.get("items", {})).duplicate(true))
	if not item_text.is_empty():
		parts.append(item_text)
	return " / ".join(parts)

func _format_items(items: Dictionary) -> String:
	var item_ids: Array[String] = []
	for item_id in items.keys():
		if int(items[item_id]) <= 0:
			continue
		item_ids.append(String(item_id))
	item_ids.sort()
	var parts: Array[String] = []
	for item_id in item_ids:
		var item := DataRepository.get_item(item_id)
		parts.append("%s x%d" % [String(item.get("name", item_id)), int(items[item_id])])
	return " / ".join(parts)

func _preview_roster_text(units: Array) -> String:
	var names: Array[String] = []
	for index in range(mini(units.size(), 4)):
		var unit: Dictionary = Dictionary(units[index]).duplicate(true)
		names.append(String(unit.get("display_name", unit.get("species_id", ""))))
	return " / ".join(names)

func _coerce_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var text := String(value)
		if text.is_empty() or result.has(text):
			continue
		result.append(text)
	return result

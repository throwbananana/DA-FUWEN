class_name SynergyService
extends RefCounted

func build_synergy_report() -> Dictionary:
	var scopes := {
		"battle": GameState.get_battle_party_uids(),
		"backpack": GameState.get_backpack_uids(),
		"building": GameState.get_building_slot_uids(),
	}
	var buckets := {
		"elements": {},
		"biomes": {},
		"jobs": {},
		"traits": {},
	}
	var seen_species := {}
	for scope_id in scopes.keys():
		for pet_uid in scopes[scope_id]:
			var pet := GameState.get_pet(String(pet_uid))
			if pet.is_empty():
				continue
			var species_id := String(pet.get("species_id", ""))
			if species_id.is_empty():
				continue
			var profile := GameData.get_species_synergy_profile(species_id)
			if not seen_species.has(species_id):
				seen_species[species_id] = true
				_record_tags(buckets["elements"], profile.get("elements", []), pet, scope_id)
				_record_tags(buckets["biomes"], profile.get("biome_tags", []), pet, scope_id)
				_record_tags(buckets["jobs"], profile.get("job_tags", []), pet, scope_id)
			_record_tags(buckets["traits"], profile.get("trait_tags", []), pet, scope_id)
	return {
		"active": _build_entries(buckets, true),
		"nearby": _build_entries(buckets, false),
		"buckets": buckets,
		"scopes": scopes,
	}

func build_battle_bonus(report: Dictionary) -> Dictionary:
	var bonus := _empty_battle_bonus()
	for entry in report.get("active", []):
		var category := String(entry.get("category", ""))
		var tier := int(entry.get("tier", 0))
		if category == "elements":
			match String(entry.get("id", "")):
				"fire", "blaze", "shadow":
					bonus["ally_attack_bonus"] += 1 if tier >= 2 else 0
					bonus["ally_attack_bonus"] += 1 if tier >= 4 else 0
				"water", "tide", "light":
					bonus["ally_hp_bonus"] += 4 if tier >= 2 else 0
					bonus["ally_hp_bonus"] += 3 if tier >= 4 else 0
					bonus["ally_heal_bonus"] += 1 if tier >= 4 else 0
				"electric", "wind", "spark":
					bonus["ally_speed_bonus"] += 1 if tier >= 2 else 0
					bonus["ally_speed_bonus"] += 1 if tier >= 4 else 0
				"grass", "grove":
					bonus["ally_heal_bonus"] += 2 if tier >= 2 else 0
					bonus["ally_heal_bonus"] += 1 if tier >= 4 else 0
				"rock", "metal", "stone":
					bonus["ally_guard_bonus"] += 0.15 if tier >= 2 else 0.0
					bonus["ally_guard_bonus"] += 0.10 if tier >= 4 else 0.0
					bonus["ally_hp_bonus"] += 2 if tier >= 4 else 0
				"mist", "psychic":
					bonus["enemy_attack_penalty"] += 1 if tier >= 2 else 0
					bonus["enemy_attack_penalty"] += 1 if tier >= 4 else 0
		elif category == "traits":
			for threshold_entry in _active_threshold_entries(category, String(entry.get("id", "")), tier):
				_merge_battle_bonus_dict(bonus, threshold_entry.get("battle_bonus", {}))
	return bonus

func build_facility_bonus() -> Dictionary:
	var bonus := _empty_battle_bonus()
	var lines: Array[String] = []
	for habitat_id in GameState.habitats.keys():
		var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
		var levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
		for building_id in levels.keys():
			var level := int(levels.get(building_id, 0))
			if level <= 0:
				continue
			var building: Dictionary = DataRepository.get_building(String(building_id))
			if building.is_empty():
				continue
			if not _has_building_match(habitat_state, String(building_id)):
				continue
			var rule: Dictionary = _building_bonus_rule(String(building_id), building)
			if rule.is_empty():
				continue
			var stat_key := String(rule.get("stat", ""))
			var value := level * int(rule.get("per_level", 1))
			if stat_key == "ally_guard_bonus":
				var guard_value := float(rule.get("guard_ratio", 0.1)) * float(level)
				bonus[stat_key] = float(bonus.get(stat_key, 0.0)) + guard_value
				lines.append("%s Lv.%d：%s +%d%%" % [
					String(rule.get("label", building_id)),
					level,
					String(rule.get("effect", stat_key)),
					int(round(guard_value * 100.0)),
				])
			else:
				bonus[stat_key] = int(bonus.get(stat_key, 0)) + value
				lines.append("%s Lv.%d：%s +%d" % [
					String(rule.get("label", building_id)),
					level,
					String(rule.get("effect", stat_key)),
					value,
				])
	return {
		"bonus": bonus,
		"lines": lines,
	}

func build_visit_resonance(habitat_id: String) -> Dictionary:
	var habitat_state: Dictionary = GameState.habitats.get(habitat_id, {})
	if habitat_state.is_empty():
		return {
			"economy_rolls": 0,
			"bond_gains": {},
			"lines": [],
		}
	var levels: Dictionary = habitat_state.get("building_levels", habitat_state.get("service_levels", {}))
	var economy_rolls := 0
	var bond_gains := {}
	var lines: Array[String] = []
	for building_id in levels.keys():
		var level := int(levels.get(building_id, 0))
		if level <= 0:
			continue
		var building: Dictionary = DataRepository.get_building(String(building_id))
		if building.is_empty():
			continue
		var matched_uids := _matching_building_pet_uids(habitat_state, String(building_id))
		if matched_uids.is_empty():
			continue
		var effects: Dictionary = building.get("resonance_effects", {})
		if not Array(effects.get("economy", [])).is_empty():
			economy_rolls += level
			lines.append("%s：回营时额外整理了地点素材。" % String(building.get("name", building_id)))
		if not Array(effects.get("growth", [])).is_empty():
			for pet_uid in matched_uids:
				bond_gains[String(pet_uid)] = maxi(int(bond_gains.get(String(pet_uid), 0)), 1)
			lines.append("%s：驻守伙伴的亲密度增长更快。" % String(building.get("name", building_id)))
	return {
		"economy_rolls": economy_rolls,
		"bond_gains": bond_gains,
		"lines": lines,
	}

func merge_battle_bonus(parts: Array) -> Dictionary:
	var merged := _empty_battle_bonus()
	for entry in parts:
		for stat_key in merged.keys():
			if stat_key == "ally_guard_bonus":
				merged[stat_key] = float(merged.get(stat_key, 0.0)) + float(entry.get(stat_key, 0.0))
			else:
				merged[stat_key] = int(merged.get(stat_key, 0)) + int(entry.get(stat_key, 0))
	return merged

func describe_battle_bonus(bonus: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var labels := {
		"ally_attack_bonus": "攻击",
		"ally_speed_bonus": "速度",
		"ally_hp_bonus": "体力",
		"ally_heal_bonus": "治疗",
		"ally_guard_bonus": "护盾减伤",
		"enemy_attack_penalty": "敌方攻击压制",
	}
	for stat_key in ["ally_attack_bonus", "ally_speed_bonus", "ally_hp_bonus", "ally_heal_bonus", "enemy_attack_penalty", "ally_guard_bonus"]:
		if stat_key == "ally_guard_bonus":
			var ratio := float(bonus.get(stat_key, 0.0))
			if ratio > 0.0:
				lines.append("%s +%d%%" % [String(labels.get(stat_key, stat_key)), int(round(ratio * 100.0))])
			continue
		var value := int(bonus.get(stat_key, 0))
		if value > 0:
			lines.append("%s +%d" % [String(labels.get(stat_key, stat_key)), value])
	return lines

func build_runtime_bonus(report: Dictionary) -> Dictionary:
	var bonus := _empty_runtime_bonus()
	for entry in report.get("active", []):
		if String(entry.get("category", "")) != "traits":
			continue
		for threshold_entry in _active_threshold_entries("traits", String(entry.get("id", "")), int(entry.get("tier", 0))):
			_merge_runtime_bonus_dict(bonus, threshold_entry.get("runtime_bonus", {}))
	return bonus

func format_trait_effect_lines(report: Dictionary, limit: int = 4) -> Array[String]:
	var lines: Array[String] = []
	for entry in report.get("active", []):
		if String(entry.get("category", "")) != "traits":
			continue
		var effects: Array[String] = []
		for threshold_entry in _active_threshold_entries("traits", String(entry.get("id", "")), int(entry.get("tier", 0))):
			var effect_text := String(threshold_entry.get("effect", ""))
			if not effect_text.is_empty():
				effects.append(effect_text)
		if effects.is_empty():
			continue
		lines.append("%s：%s" % [String(entry.get("name", "")), "；".join(effects)])
		if lines.size() >= limit:
			break
	return lines

func _empty_battle_bonus() -> Dictionary:
	return {
		"ally_attack_bonus": 0,
		"ally_speed_bonus": 0,
		"ally_hp_bonus": 0,
		"ally_heal_bonus": 0,
		"ally_guard_bonus": 0.0,
		"enemy_attack_penalty": 0,
	}

func _empty_runtime_bonus() -> Dictionary:
	return {
		"auto_bank_deposit_ratio": 0.0,
		"bank_interest_bonus_ratio": 0.0,
		"free_withdraw": false,
		"rival_tax_ratio": 0.0,
		"wallet_gold_per_day": 0,
		"salvage_bonus": 0,
		"rare_drop_bonus": 0,
		"board_reveal_bonus": 0,
		"free_move_charge": 0,
		"building_yield_bonus_ratio": 0.0,
		"post_battle_steal_gold": 0,
	}

func format_active_lines(report: Dictionary, limit: int = 6) -> Array[String]:
	var lines: Array[String] = []
	for entry in report.get("active", []):
		var sources: Array[String] = []
		for source in entry.get("sources", []):
			sources.append("%s:%s" % [_scope_name(String(source.get("scope", ""))), String(source.get("name", ""))])
		lines.append("%s %d层 ｜ %s" % [
			String(entry.get("name", "")),
			int(entry.get("tier", 0)),
			", ".join(sources),
		])
		if lines.size() >= limit:
			break
	if lines.is_empty():
		lines.append("当前还没有达到激活阈值的羁绊。")
	return lines

func format_nearby_lines(report: Dictionary, limit: int = 4) -> Array[String]:
	var lines: Array[String] = []
	for entry in report.get("nearby", []):
		lines.append("%s 还差 %d %s" % [
			String(entry.get("name", "")),
			int(entry.get("need", 1)),
			_count_unit_label(String(entry.get("category", ""))),
		])
		if lines.size() >= limit:
			break
	return lines

func _record_tags(bucket: Dictionary, tags: Array, pet: Dictionary, scope_id: String) -> void:
	for tag in tags:
		var tag_id := String(tag)
		if not bucket.has(tag_id):
			bucket[tag_id] = {
				"count": 0,
				"sources": [],
			}
		bucket[tag_id]["count"] = int(bucket[tag_id]["count"]) + 1
		bucket[tag_id]["sources"].append({
			"scope": scope_id,
			"name": String(pet.get("display_name", tag_id)),
			"species_id": String(pet.get("species_id", "")),
		})

func _build_entries(buckets: Dictionary, active_only: bool) -> Array:
	var entries: Array = []
	for category in buckets.keys():
		for tag_id in buckets[category].keys():
			var count := int(buckets[category][tag_id].get("count", 0))
			var tier := 0
			var next_threshold := 0
			for threshold_entry in GameData.get_synergy_thresholds(String(category), String(tag_id)):
				var threshold := 0
				if typeof(threshold_entry) == TYPE_DICTIONARY:
					threshold = int(threshold_entry.get("count", 0))
				else:
					threshold = int(threshold_entry)
				if count >= threshold:
					tier = threshold
				elif next_threshold == 0:
					next_threshold = threshold
			if active_only:
				if tier <= 0:
					continue
			else:
				if tier > 0 or next_threshold <= 0 or next_threshold - count > 1:
					continue
			entries.append({
				"category": category,
				"id": tag_id,
				"name": _tag_name(String(category), String(tag_id)),
				"count": count,
				"tier": tier,
				"next_threshold": next_threshold,
				"need": maxi(next_threshold - count, 0),
				"sources": buckets[category][tag_id].get("sources", []).duplicate(true),
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("tier", 0)) == int(b.get("tier", 0)):
			return String(a.get("name", "")) < String(b.get("name", ""))
		return int(a.get("tier", 0)) > int(b.get("tier", 0))
	)
	return entries

func _tag_name(category: String, tag_id: String) -> String:
	match category:
		"elements":
			return "%s系" % GameData.get_type_name(tag_id)
		"biomes":
			return "%s生态" % String(GameData.BIOME_NAMES.get(tag_id, tag_id))
		"jobs":
			return "%s职能" % String(GameData.JOB_NAMES.get(tag_id, tag_id))
		"traits":
			var entry := GameData.get_synergy_definition("traits", tag_id)
			return String(entry.get("label", tag_id))
		_:
			return tag_id

func _count_unit_label(category: String) -> String:
	match category:
		"traits":
			return "只同羁绊单位"
		_:
			return "只独特物种"

func _active_threshold_entries(category: String, tag_id: String, tier: int) -> Array:
	var result: Array = []
	for threshold_entry in GameData.get_synergy_thresholds(category, tag_id):
		if typeof(threshold_entry) != TYPE_DICTIONARY:
			if tier >= int(threshold_entry):
				result.append({"count": int(threshold_entry)})
			continue
		if tier >= int(threshold_entry.get("count", 0)):
			result.append(threshold_entry)
	return result

func _merge_battle_bonus_dict(target: Dictionary, delta: Dictionary) -> void:
	for stat_key in delta.keys():
		if stat_key == "ally_guard_bonus":
			target[stat_key] = float(target.get(stat_key, 0.0)) + float(delta.get(stat_key, 0.0))
		else:
			target[stat_key] = int(target.get(stat_key, 0)) + int(delta.get(stat_key, 0))

func _merge_runtime_bonus_dict(target: Dictionary, delta: Dictionary) -> void:
	for stat_key in delta.keys():
		var value = delta.get(stat_key)
		if typeof(value) == TYPE_BOOL:
			target[stat_key] = bool(target.get(stat_key, false)) or bool(value)
		elif typeof(value) == TYPE_FLOAT:
			target[stat_key] = float(target.get(stat_key, 0.0)) + float(value)
		else:
			target[stat_key] = int(target.get(stat_key, 0)) + int(value)

func _scope_name(scope_id: String) -> String:
	match scope_id:
		"battle":
			return "上阵"
		"backpack":
			return "背包"
		"building":
			return "驻守"
		_:
			return scope_id

func _has_building_match(habitat_state: Dictionary, building_id: String) -> bool:
	return not _matching_building_pet_uids(habitat_state, building_id).is_empty()

func _matching_building_pet_uids(habitat_state: Dictionary, building_id: String) -> Array[String]:
	var result: Array[String] = []
	for slot_key in ["resident_uid", "assistant_uid"]:
		var pet_uid := String(habitat_state.get(slot_key, ""))
		if pet_uid.is_empty():
			continue
		var pet := GameState.get_pet(pet_uid)
		if pet.is_empty():
			continue
		var profile := GameData.get_species_synergy_profile(String(pet.get("species_id", "")))
		if Array(profile.get("building_tags", [])).has(building_id) and not result.has(pet_uid):
			result.append(pet_uid)
	return result

func _building_bonus_rule(building_id: String, building: Dictionary) -> Dictionary:
	var fixed_rules := {
		"warm_nest": {"stat": "ally_hp_bonus", "per_level": 1, "label": "温巢台", "effect": "开场体力"},
		"moss_bed": {"stat": "ally_heal_bonus", "per_level": 1, "label": "苔绒床", "effect": "治疗强化"},
		"shallow_pool": {"stat": "ally_heal_bonus", "per_level": 1, "label": "浅池", "effect": "续航强化"},
		"sun_drying_rack": {"stat": "ally_attack_bonus", "per_level": 1, "label": "晒石台", "effect": "攻击强化"},
		"watch_tower": {"stat": "ally_speed_bonus", "per_level": 1, "label": "观测台", "effect": "先手强化"},
		"repair_bench": {"stat": "ally_attack_bonus", "per_level": 1, "label": "修理间", "effect": "攻击强化"},
		"echo_room": {"stat": "enemy_attack_penalty", "per_level": 1, "label": "回响室", "effect": "压制敌方攻击"},
	}
	if fixed_rules.has(building_id):
		return fixed_rules[building_id]
	var slot_rules: Dictionary = building.get("resident_slot_rules", {})
	var accepted_types: Array = slot_rules.get("accepted_types", [])
	var accepted_roles: Array = slot_rules.get("accepted_roles", [])
	var pre_battle: Array = building.get("resonance_effects", {}).get("pre_battle", [])
	var label := String(building.get("name", building_id))
	if accepted_types.has("water") or accepted_types.has("grass") or accepted_types.has("light") or accepted_roles.has("healer"):
		return {"stat": "ally_heal_bonus", "per_level": 1, "label": label, "effect": _pre_battle_label(pre_battle, "续航/治疗")}
	if accepted_types.has("fire") or accepted_types.has("shadow") or accepted_roles.has("striker") or accepted_roles.has("vanguard"):
		return {"stat": "ally_attack_bonus", "per_level": 1, "label": label, "effect": _pre_battle_label(pre_battle, "输出强化")}
	if accepted_types.has("electric") or accepted_types.has("wind") or accepted_roles.has("scout") or accepted_roles.has("charger"):
		return {"stat": "ally_speed_bonus", "per_level": 1, "label": label, "effect": _pre_battle_label(pre_battle, "先手强化")}
	if accepted_types.has("rock") or accepted_types.has("metal") or accepted_roles.has("guardian") or accepted_roles.has("builder"):
		return {"stat": "ally_guard_bonus", "per_level": 1, "guard_ratio": 0.10, "label": label, "effect": _pre_battle_label(pre_battle, "护盾减伤")}
	if accepted_types.has("mist") or accepted_types.has("psychic") or accepted_roles.has("controller"):
		return {"stat": "enemy_attack_penalty", "per_level": 1, "label": label, "effect": _pre_battle_label(pre_battle, "压制敌方")}
	return {}

func _pre_battle_label(pre_battle: Array, fallback: String) -> String:
	if pre_battle.is_empty():
		return fallback
	return String(pre_battle[0])

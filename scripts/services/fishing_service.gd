extends RefCounted

var rng := RandomNumberGenerator.new()

const RARITY_SCORE := {
	"common": 1,
	"uncommon": 2,
	"rare": 4,
	"epic": 7,
}

const BAIT_PROFILES := [
	{
		"id": "reed",
		"label": "芦尖软饵",
		"summary": "最稳的基础挂饵，适合浅滩与湿地。",
		"catch_bonus": 0.05,
		"rare_bonus": 0,
		"actions": ["cast_line", "join_competition"],
		"habitat_ids": ["crystal_creek", "reed_mire"],
	},
	{
		"id": "soft_moss",
		"label": "苔团漂饵",
		"summary": "更偏向观察与引鱼，不急着爆口。",
		"catch_bonus": 0.03,
		"rare_bonus": 1,
		"actions": ["cast_line", "watch_tide"],
		"habitat_ids": ["crystal_creek", "frost_mirror_lake"],
	},
	{
		"id": "tea_leaf",
		"label": "茶香窝料",
		"summary": "适合节庆和夜场，会把鱼路留得更久。",
		"catch_bonus": 0.04,
		"rare_bonus": 1,
		"actions": ["watch_tide", "join_competition"],
		"season_ids": ["summer", "autumn"],
	},
]

func _init() -> void:
	rng.randomize()

func has_fishing_spot(habitat_id: String) -> bool:
	return not DataRepository.get_fishing_spot(habitat_id).is_empty()

func build_fishing_menu(habitat_id: String) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	if spot.is_empty():
		return {"ok": false}
	var pressure := GameState.get_fishing_spot_pressure(habitat_id)
	var seasonal_event := _get_seasonal_festival_event(spot)
	var rig := _build_rig_snapshot(habitat_id, "cast_line")
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(spot.get("name", _habitat_name(habitat_id))),
		"本次垂钓会直接消耗当前回合。",
		"[b]天气 / 时段[/b] %s / %s" % [_weather_name(GameState.weather_id), _time_name(GameState.time_of_day)],
		"[b]水域压力[/b] %d / 6" % pressure,
		"[b]当前线组[/b] %s" % String(rig.get("rod_label", "临时手线")),
		"[b]挂饵[/b] %s" % String(rig.get("bait_label", "空钩试水")),
	]
	var bonus_lines: Array = Array(rig.get("bonus_lines", [])).duplicate(true)
	if not bonus_lines.is_empty():
		body_lines.append("[b]线组 / 建筑加成[/b] %s" % " / ".join(bonus_lines.slice(0, 3)))
	var choices := [
		{
			"id": "cast_line",
			"label": "下竿试钓",
			"summary": "直接尝试鱼讯，稀有度会吃线组、挂饵和建筑加成。",
		},
		{
			"id": "watch_tide",
			"label": "观水记纹",
			"summary": "更偏向认鱼路、做记录，也更容易顺手接到生态型事件。",
		},
		{
			"id": "release_watch",
			"label": "放流护幼",
			"summary": "优先处理抱卵个体、幼体和旧线组，降低水域压力并推放流线。",
		},
	]
	if not seasonal_event.is_empty():
		body_lines.append("[b]季节活动[/b] %s" % String(seasonal_event.get("title", "水域节庆")))
		var preview := _build_competition_preview_lines(seasonal_event)
		if not preview.is_empty():
			body_lines.append("[b]当前榜单[/b] %s" % " / ".join(preview))
		choices.append({
			"id": "join_competition",
			"label": "参加节庆比赛",
			"summary": String(seasonal_event.get("menu_summary", "把本回合拿来参加当地的钓鱼活动。")),
		})
	return {
		"ok": true,
		"title": "水边垂钓",
		"body": "\n".join(body_lines),
		"choices": choices,
	}

func resolve_fishing_choice(habitat_id: String, choice_id: String) -> Dictionary:
	var rig := _build_rig_snapshot(habitat_id, choice_id)
	match choice_id:
		"cast_line":
			return _resolve_cast_line(habitat_id, rig)
		"watch_tide":
			return _resolve_watch_tide(habitat_id, rig)
		"release_watch":
			return _resolve_release_watch(habitat_id, rig)
		"join_competition":
			return _resolve_competition(habitat_id, rig)
		_:
			return {"ok": false, "body": "今天没有合适的钓鱼动作。"}

func _resolve_cast_line(habitat_id: String, rig: Dictionary) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	if spot.is_empty():
		return {"ok": false, "body": "这片水域今天没有鱼讯。"}
	var bait_result := _consume_bait_if_needed(rig, "cast_line")
	var roll := rng.randf()
	var incident_event := _pick_incident_event(habitat_id, "cast_line")
	var event_threshold := 0.18 + float(rig.get("incident_bonus", 0.0))
	if not incident_event.is_empty() and roll <= event_threshold:
		var event_payload := _build_event_payload(incident_event)
		return _merge_payloads(event_payload, bait_result)
	var pressure := GameState.get_fishing_spot_pressure(habitat_id)
	var failure_threshold := clampf(0.18 + float(pressure) * 0.05 - float(rig.get("catch_bonus", 0.0)), 0.05, 0.55)
	if roll <= failure_threshold:
		var empty_payload := {
			"ok": true,
			"title": "垂钓结果",
			"body_lines": [
				"[b]空军而返[/b]",
				"你刚把线抛进水面，附近就炸开了一圈受惊的水纹。",
				"今天这片水域的警戒又高了一点。",
			],
			"pressure_delta": maxi(0, 1 - int(rig.get("pressure_relief", 0))),
			"items": {"water_drop": 1},
			"journal_entries": ["今天的鱼讯偏散，水面警戒明显升高。"],
			"log_line": "在 %s 试钓了一轮，但水面一下子静了。" % _habitat_name(habitat_id),
			"observe_markers": ["fish_empty:%s" % habitat_id],
		}
		return _merge_payloads(empty_payload, bait_result)
	var aquatic_species := _pick_species(habitat_id, ["cast_line"], rig)
	if aquatic_species.is_empty():
		var miss_payload := {
			"ok": true,
			"title": "垂钓结果",
			"body_lines": ["[b]没有起鱼[/b]", "水面只是轻轻动了一下，今天更像是在试水。"],
			"log_line": "在 %s 下竿了一次，但今天更像是在试水。" % _habitat_name(habitat_id),
		}
		return _merge_payloads(miss_payload, bait_result)
	var rarity := String(aquatic_species.get("rarity", "common"))
	var species_id := String(aquatic_species.get("id", ""))
	var items := _catch_reward_for_rarity(rarity)
	var body_lines: Array[String] = [
		"[b]鱼讯上钩[/b]",
		"你拉起了 [b]%s[/b]，它在水面下绕了一个漂亮的弧。" % String(aquatic_species.get("name", species_id)),
		String(aquatic_species.get("catch_text", "这次手感不错，算是一次干净的中鱼。")),
	]
	if not String(bait_result.get("bait_line", "")).is_empty():
		body_lines.append(String(bait_result.get("bait_line", "")))
	if not items.is_empty():
		body_lines.append("[b]顺手带回[/b] %s" % _format_item_cost(items))
	var payload := {
		"ok": true,
		"title": "垂钓结果",
		"body_lines": body_lines,
		"items": items,
		"catch_species_id": species_id,
		"weight_class": rarity,
		"pressure_delta": maxi(0, (1 if rarity in ["rare", "epic"] else 0) - int(rig.get("pressure_relief", 0))),
		"journal_entries": [String(aquatic_species.get("journal_text", "%s 的游动方式被你记进了笔记。" % String(aquatic_species.get("name", species_id))))],
		"log_line": "在 %s 钓到了 %s。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
		"observe_markers": [
			"fish_catch:%s" % species_id,
			"fish_rarity:%s:%s" % [rarity, species_id],
		],
	}
	return _merge_payloads(payload, bait_result)

func _resolve_watch_tide(habitat_id: String, rig: Dictionary) -> Dictionary:
	var local_event := _pick_incident_event(habitat_id, "watch_tide")
	var aquatic_species := _pick_species(habitat_id, ["watch_tide", "cast_line"], rig)
	var payload: Dictionary
	if aquatic_species.is_empty():
		payload = {
			"ok": true,
			"title": "观水记纹",
			"body_lines": [
				"[b]水面很安静[/b]",
				"你花了一个回合看水、看风和岸边留下的线痕，今天像是在为下一次鱼讯做准备。",
			],
			"items": {"paper": 1},
			"journal_entries": ["今天先记了水纹和岸边脚印，还没急着起鱼。"],
			"log_line": "在 %s 没急着下竿，而是先把水情记了下来。" % _habitat_name(habitat_id),
			"observe_markers": ["fish_watch:%s" % habitat_id],
		}
	else:
		var species_id := String(aquatic_species.get("id", ""))
		var body_lines: Array[String] = [
			"[b]你先看清了鱼路[/b]",
			"你没有急着起竿，而是顺着 [b]%s[/b] 的回游轨迹，把今天的水情记了下来。" % String(aquatic_species.get("name", species_id)),
			"这次没有直接带走什么，但之后遇到它会更从容。",
		]
		if not String(rig.get("bait_label", "")).is_empty() and String(rig.get("bait_label", "")) != "空钩试水":
			body_lines.append("你先拿 %s 试了一下水口和回线节奏。" % String(rig.get("bait_label", "")))
		payload = {
			"ok": true,
			"title": "观水记纹",
			"body_lines": body_lines,
			"items": {"paper": 1, "water_drop": 1},
			"journal_entries": [String(aquatic_species.get("watch_text", "%s 的回游路线被你单独记成了一页。" % String(aquatic_species.get("name", species_id))))],
			"log_line": "你在 %s 先记住了 %s 的鱼路。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
			"observe_markers": ["fish_watch:%s" % species_id],
		}
	if not local_event.is_empty():
		payload = _merge_payloads(payload, _build_event_payload(local_event, false))
	return payload

func _resolve_release_watch(habitat_id: String, rig: Dictionary) -> Dictionary:
	var local_event := _pick_incident_event(habitat_id, "release_watch")
	var aquatic_species := _pick_species(habitat_id, ["release_watch", "cast_line"], rig)
	var payload: Dictionary
	if aquatic_species.is_empty():
		payload = {
			"ok": true,
			"title": "放流护幼",
			"body_lines": [
				"[b]这次没有发现需要处理的个体[/b]",
				"你顺手理了理岸边的旧线组，水域压力略微回落。",
			],
			"pressure_delta": -1 - int(rig.get("release_bonus", 0)),
			"items": {"reed": 1},
			"log_line": "你在 %s 清掉了一些旧线组。" % _habitat_name(habitat_id),
			"observe_markers": ["fish_release:cleanup"],
		}
	else:
		var species_id := String(aquatic_species.get("id", ""))
		var relation_deltas: Array = []
		var trust_rewards := {}
		if habitat_id == "crystal_creek":
			relation_deltas.append({
				"actor_a": "npc:washer_grandma",
				"actor_b": "species:%s" % species_id,
				"affinity": 1,
				"familiarity": 1,
			})
			trust_rewards["washer_grandma"] = 1
		payload = {
			"ok": true,
			"title": "放流护幼",
			"body_lines": [
				"[b]你先放了它回去[/b]",
				"你发现 [b]%s[/b] 正处在护幼 / 抱卵窗口，于是没有把这次相遇变成战利品。" % String(aquatic_species.get("name", species_id)),
				"这片水域的警戒随之回落了一些。",
			],
			"release_species_id": species_id,
			"pressure_delta": -1 - int(rig.get("release_bonus", 0)),
			"items": {"water_drop": 1, "reed": 1},
			"journal_entries": [String(aquatic_species.get("release_text", "%s 的护幼行为被你单独记了一页。" % String(aquatic_species.get("name", species_id))))],
			"relation_deltas": relation_deltas,
			"trust_rewards": trust_rewards,
			"log_line": "你在 %s 放流了 %s。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
			"observe_markers": ["fish_release:%s" % species_id],
		}
	if not local_event.is_empty():
		payload = _merge_payloads(payload, _build_event_payload(local_event, false))
	return payload

func _resolve_competition(habitat_id: String, rig: Dictionary) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	var event_row := _get_seasonal_festival_event(spot)
	if event_row.is_empty():
		return {"ok": true, "title": "今日没有比赛", "body_lines": ["[b]水边今天很安静[/b]", "这片水域今天没有对外开放的节庆活动。"], "log_line": "你赶到水边时，今天并没有比赛。"}
	var bait_result := _consume_bait_if_needed(rig, "join_competition")
	var aquatic_species := _pick_species(habitat_id, ["festival", "cast_line"], rig)
	var species_name := String(aquatic_species.get("name", "临时鱼获"))
	var rarity := String(aquatic_species.get("rarity", "common"))
	var score_delta := int(event_row.get("base_score", 2)) + int(RARITY_SCORE.get(rarity, 1)) + int(rig.get("score_bonus", 0))
	var items: Dictionary = Dictionary(event_row.get("items", {})).duplicate(true)
	var bonus_items := _competition_bonus_reward(rarity)
	for item_id in bonus_items.keys():
		items[item_id] = int(items.get(item_id, 0)) + int(bonus_items[item_id])
	var projected_total := GameState.get_festival_score(String(event_row.get("id", "festival"))) + score_delta
	var standings := _build_competition_rows(event_row, projected_total)
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(event_row.get("title", "水域比赛")),
		String(event_row.get("description", "你把这一回合拿来参加岸边的临时比赛。")),
		"本轮记分鱼获：%s ｜ 分数 +%d" % [species_name, score_delta],
		"当前预计排名：%s" % _placement_text(standings),
	]
	var preview_lines := _standings_lines(standings)
	if not preview_lines.is_empty():
		body_lines.append("[b]本季榜单[/b] %s" % " / ".join(preview_lines.slice(0, 3)))
	var payload := {
		"ok": true,
		"title": String(event_row.get("title", "水域比赛")),
		"body_lines": body_lines,
		"festival_id": String(event_row.get("id", "festival")),
		"score_delta": score_delta,
		"items": items,
		"trust_rewards": Dictionary(event_row.get("trust_rewards", {})).duplicate(true),
		"journal_entries": [String(event_row.get("journal_entry", "%s 的成绩被写进了本季水域记录。" % String(event_row.get("title", "比赛"))))],
		"story_flags": Array(event_row.get("story_flags", [])).duplicate(true),
		"log_line": "你在 %s 参加了 %s，靠 %s 拿到 %d 分。" % [_habitat_name(habitat_id), String(event_row.get("title", "水域比赛")), species_name, score_delta],
		"event_id": String(event_row.get("id", "")),
		"observe_markers": _festival_score_markers(String(event_row.get("id", "festival")), projected_total),
		"leaderboard_lines": _standings_lines(standings),
		"catch_species_id": String(aquatic_species.get("id", "")) if not aquatic_species.is_empty() else "",
		"weight_class": rarity,
	}
	return _merge_payloads(payload, bait_result)

func _build_rig_snapshot(habitat_id: String, choice_id: String) -> Dictionary:
	var snapshot := {
		"rod_label": "临时手线",
		"bait_id": "",
		"bait_label": "空钩试水",
		"catch_bonus": 0.0,
		"rare_bonus": 0,
		"incident_bonus": 0.0,
		"release_bonus": 0,
		"pressure_relief": 0,
		"score_bonus": 0,
		"bonus_lines": [],
	}
	if GameState.get_item_count("rope") > 0:
		snapshot["rod_label"] = "编绳手线"
		snapshot["catch_bonus"] = float(snapshot.get("catch_bonus", 0.0)) + 0.04
		snapshot["bonus_lines"].append("绳索：抛投更稳")
	if GameState.get_item_count("repair_kit") > 0:
		snapshot["rod_label"] = "加固卷轮"
		snapshot["catch_bonus"] = float(snapshot.get("catch_bonus", 0.0)) + 0.03
		snapshot["rare_bonus"] = int(snapshot.get("rare_bonus", 0)) + 1
		snapshot["pressure_relief"] = int(snapshot.get("pressure_relief", 0)) + 1
		snapshot["bonus_lines"].append("修理包：回线容错更高")
	var selected_bait := _pick_bait_profile(habitat_id, choice_id)
	if not selected_bait.is_empty():
		snapshot["bait_id"] = String(selected_bait.get("id", ""))
		snapshot["bait_label"] = String(selected_bait.get("label", "挂饵"))
		snapshot["catch_bonus"] = float(snapshot.get("catch_bonus", 0.0)) + float(selected_bait.get("catch_bonus", 0.0))
		snapshot["rare_bonus"] = int(snapshot.get("rare_bonus", 0)) + int(selected_bait.get("rare_bonus", 0))
		snapshot["bonus_lines"].append("挂饵：%s" % String(selected_bait.get("summary", "")))
	var shallow_pool_level := GameState.get_building_level(habitat_id, "shallow_pool")
	if shallow_pool_level > 0:
		snapshot["release_bonus"] = int(snapshot.get("release_bonus", 0)) + 1
		snapshot["bonus_lines"].append("浅池 Lv.%d：放流更稳" % shallow_pool_level)
	var drying_rack_level := GameState.get_building_level(habitat_id, "sun_drying_rack")
	if drying_rack_level > 0 and GameState.time_of_day != "night":
		snapshot["catch_bonus"] = float(snapshot.get("catch_bonus", 0.0)) + 0.03
		snapshot["score_bonus"] = int(snapshot.get("score_bonus", 0)) + 1
		snapshot["bonus_lines"].append("晾架 Lv.%d：白天判断更稳" % drying_rack_level)
	var reed_shed_level := GameState.get_building_level(habitat_id, "reed_shed")
	if reed_shed_level > 0:
		snapshot["incident_bonus"] = float(snapshot.get("incident_bonus", 0.0)) + 0.04
		snapshot["pressure_relief"] = int(snapshot.get("pressure_relief", 0)) + 1
		snapshot["bonus_lines"].append("芦棚 Lv.%d：换钩和收线更从容" % reed_shed_level)
	return snapshot

func _pick_bait_profile(habitat_id: String, choice_id: String) -> Dictionary:
	var best_profile := {}
	var best_score := -999
	for bait_profile in BAIT_PROFILES:
		var bait_id := String(bait_profile.get("id", ""))
		if bait_id.is_empty() or GameState.get_item_count(bait_id) <= 0:
			continue
		var actions: Array = Array(bait_profile.get("actions", []))
		if not actions.is_empty() and not actions.has(choice_id):
			continue
		var score := 0
		if Array(bait_profile.get("habitat_ids", [])).has(habitat_id):
			score += 2
		if Array(bait_profile.get("season_ids", [])).has(GameState.season_id):
			score += 1
		if String(bait_profile.get("id", "")) == "tea_leaf" and choice_id == "join_competition":
			score += 2
		if score > best_score:
			best_profile = Dictionary(bait_profile).duplicate(true)
			best_score = score
	return best_profile

func _consume_bait_if_needed(rig: Dictionary, choice_id: String) -> Dictionary:
	var bait_id := String(rig.get("bait_id", ""))
	if bait_id.is_empty() or not ["cast_line", "join_competition"].has(choice_id):
		return {}
	if GameState.get_item_count(bait_id) <= 0:
		return {}
	if not GameState.remove_items({bait_id: 1}):
		return {}
	return {
		"body_lines": ["[b]挂饵消耗[/b] %s x1" % _item_name(bait_id)],
		"bait_line": "%s 让这次鱼讯更好判断。" % String(rig.get("bait_label", "挂饵")),
	}

func _pick_species(habitat_id: String, action_tags: Array, rig: Dictionary) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	if spot.is_empty():
		return {}
	var candidates: Array = []
	for species_id in Array(spot.get("species_pool", [])):
		var aquatic_species := DataRepository.get_aquatic_species(String(species_id))
		if aquatic_species.is_empty():
			continue
		if not _species_matches_now(aquatic_species, action_tags):
			continue
		var weight := int(aquatic_species.get("weight", 1))
		var weather_bonus: Dictionary = Dictionary(aquatic_species.get("weather_bonus", {}))
		weight += int(weather_bonus.get(GameState.weather_id, 0))
		var time_bonus: Dictionary = Dictionary(aquatic_species.get("time_bonus", {}))
		weight += int(time_bonus.get(GameState.time_of_day, 0))
		var rarity := String(aquatic_species.get("rarity", "common"))
		if rarity in ["rare", "epic"]:
			weight += int(rig.get("rare_bonus", 0))
		weight = maxi(1, weight - maxi(0, GameState.get_fishing_spot_pressure(habitat_id) - int(aquatic_species.get("pressure_tolerance", 1))))
		candidates.append({
			"row": aquatic_species,
			"weight": weight,
		})
	if candidates.is_empty():
		return {}
	return Dictionary(_weighted_pick(candidates).get("row", {})).duplicate(true)

func _species_matches_now(aquatic_species: Dictionary, action_tags: Array) -> bool:
	var seasons: Array = Array(aquatic_species.get("seasons", []))
	if not seasons.is_empty() and not seasons.has(GameState.season_id):
		return false
	var times: Array = Array(aquatic_species.get("times", []))
	if not times.is_empty() and not times.has(GameState.time_of_day):
		return false
	var weathers: Array = Array(aquatic_species.get("weathers", []))
	if not weathers.is_empty() and not weathers.has(GameState.weather_id):
		return false
	var required_tags: Array = Array(aquatic_species.get("action_tags", []))
	if required_tags.is_empty():
		return true
	for action_tag in action_tags:
		if required_tags.has(action_tag):
			return true
	return false

func _pick_incident_event(habitat_id: String, choice_id: String) -> Dictionary:
	var candidates: Array = []
	for event_row in DataRepository.get_fishing_events_for_habitat(habitat_id):
		if String(event_row.get("mode", "")) == "festival":
			continue
		if GameState.has_seen_fishing_event(String(event_row.get("id", ""))) and not bool(event_row.get("repeatable", false)):
			continue
		var choice_ids: Array = Array(event_row.get("choice_ids", []))
		if not choice_ids.is_empty() and not choice_ids.has(choice_id):
			continue
		if not _event_matches_now(event_row):
			continue
		candidates.append({
			"row": event_row,
			"weight": int(event_row.get("weight", 1)),
		})
	if candidates.is_empty():
		return {}
	return Dictionary(_weighted_pick(candidates).get("row", {})).duplicate(true)

func _get_seasonal_festival_event(spot: Dictionary) -> Dictionary:
	if spot.is_empty():
		return {}
	var by_season: Dictionary = Dictionary(spot.get("festival_by_season", {})).duplicate(true)
	var event_id := String(by_season.get(GameState.season_id, ""))
	if event_id.is_empty():
		return {}
	for event_row in DataRepository.get_fishing_events_for_habitat(String(spot.get("habitat_id", ""))):
		if String(event_row.get("id", "")) == event_id and _event_matches_now(event_row):
			return Dictionary(event_row).duplicate(true)
	return {}

func _event_matches_now(event_row: Dictionary) -> bool:
	var seasons: Array = Array(event_row.get("seasons", []))
	if not seasons.is_empty() and not seasons.has(GameState.season_id):
		return false
	var times: Array = Array(event_row.get("times", []))
	if not times.is_empty() and not times.has(GameState.time_of_day):
		return false
	var weathers: Array = Array(event_row.get("weathers", []))
	if not weathers.is_empty() and not weathers.has(GameState.weather_id):
		return false
	var habitat_id := String(event_row.get("habitat_id", ""))
	if habitat_id.is_empty():
		var habitat_ids: Array = Array(event_row.get("habitat_ids", []))
		if not habitat_ids.is_empty():
			habitat_id = String(habitat_ids[0])
	var max_pressure := int(event_row.get("max_pressure", 99))
	if not habitat_id.is_empty() and GameState.get_fishing_spot_pressure(habitat_id) > max_pressure and max_pressure < 99:
		return false
	var min_reputation := int(event_row.get("min_fishing_reputation", 0))
	if min_reputation > 0 and GameState.get_fishing_reputation() < min_reputation:
		return false
	for raw_flag in Array(event_row.get("required_story_flags", [])):
		if not GameState.has_story_flag(String(raw_flag)):
			return false
	return true

func _build_event_payload(event_row: Dictionary, include_title_line := true) -> Dictionary:
	var body_lines: Array[String] = []
	if include_title_line:
		body_lines.append("[b]%s[/b]" % String(event_row.get("title", "水边插曲")))
	for line in Array(event_row.get("body_lines", [])):
		body_lines.append(String(line))
	return {
		"ok": true,
		"title": String(event_row.get("title", "水边插曲")),
		"body_lines": body_lines,
		"items": Dictionary(event_row.get("items", {})).duplicate(true),
		"journal_entries": [String(event_row.get("journal_entry", ""))] if not String(event_row.get("journal_entry", "")).is_empty() else [],
		"trust_rewards": Dictionary(event_row.get("trust_rewards", {})).duplicate(true),
		"relation_deltas": Array(event_row.get("relation_deltas", [])).duplicate(true),
		"story_flags": Array(event_row.get("story_flags", [])).duplicate(true),
		"pressure_delta": int(event_row.get("pressure_delta", 0)),
		"event_id": String(event_row.get("id", "")),
		"log_line": String(event_row.get("log_line", "你在水边遇到了一点额外状况。")),
		"observe_markers": _event_observe_markers(event_row),
	}

func _merge_payloads(base_payload: Dictionary, extra_payload: Dictionary) -> Dictionary:
	if extra_payload.is_empty():
		return base_payload.duplicate(true)
	var merged: Dictionary = base_payload.duplicate(true)
	for key in ["items", "trust_rewards"]:
		var current: Dictionary = Dictionary(merged.get(key, {})).duplicate(true)
		for item_id in Dictionary(extra_payload.get(key, {})).keys():
			current[item_id] = int(current.get(item_id, 0)) + int(extra_payload.get(key, {}).get(item_id, 0))
		merged[key] = current
	for key in ["journal_entries", "relation_deltas", "story_flags", "body_lines", "observe_markers", "leaderboard_lines"]:
		var current_array: Array = Array(merged.get(key, [])).duplicate(true)
		current_array.append_array(Array(extra_payload.get(key, [])).duplicate(true))
		merged[key] = current_array
	merged["pressure_delta"] = int(merged.get("pressure_delta", 0)) + int(extra_payload.get("pressure_delta", 0))
	if String(merged.get("event_id", "")).is_empty():
		merged["event_id"] = String(extra_payload.get("event_id", ""))
	if String(merged.get("log_line", "")).is_empty():
		merged["log_line"] = String(extra_payload.get("log_line", ""))
	if String(merged.get("bait_line", "")).is_empty():
		merged["bait_line"] = String(extra_payload.get("bait_line", ""))
	return merged

func _build_competition_preview_lines(event_row: Dictionary) -> Array[String]:
	var current_total := GameState.get_festival_score(String(event_row.get("id", "festival")))
	var rows := _build_competition_rows(event_row, current_total)
	return _standings_lines(rows)

func _build_competition_rows(event_row: Dictionary, player_total: int) -> Array:
	var rows: Array = [
		{"name": "你", "score": player_total, "is_player": true},
	]
	var rival_names: Array = Array(event_row.get("rival_names", [])).duplicate(true)
	if rival_names.is_empty():
		rival_names = _default_festival_rivals(event_row)
	for index in range(rival_names.size()):
		rows.append({
			"name": String(rival_names[index]),
			"score": _festival_rival_score(event_row, index),
			"is_player": false,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", 0))
		var score_b := int(b.get("score", 0))
		if score_a == score_b:
			if bool(a.get("is_player", false)) != bool(b.get("is_player", false)):
				return bool(a.get("is_player", false))
			return String(a.get("name", "")) < String(b.get("name", ""))
		return score_a > score_b
	)
	return rows

func _festival_rival_score(event_row: Dictionary, index: int) -> int:
	var base_score := int(event_row.get("base_score", 2))
	var season_offset := 0
	match GameState.season_id:
		"summer":
			season_offset = 1
		"autumn":
			season_offset = 2
		"winter":
			season_offset = 3
		_:
			season_offset = 0
	return base_score * 2 + season_offset + GameState.week_index + index * 2 + int(GameState.get_total_trust() / 6)

func _default_festival_rivals(event_row: Dictionary) -> Array:
	var rows: Array = []
	for npc_id in Array(event_row.get("host_npcs", [])):
		var npc_name := String(DataRepository.get_npc(String(npc_id)).get("name", String(npc_id)))
		if npc_name.is_empty() or rows.has(npc_name):
			continue
		rows.append(npc_name)
	for rival in GameState.get_ai_players():
		var display_name := String(Dictionary(rival).get("display_name", ""))
		if display_name.is_empty() or rows.has(display_name):
			continue
		rows.append(display_name)
		if rows.size() >= 3:
			break
	if rows.is_empty():
		rows = ["河岸常客", "隔壁营地", "巡路钓手"]
	return rows.slice(0, 3)

func _placement_text(rows: Array) -> String:
	for index in range(rows.size()):
		if bool(Dictionary(rows[index]).get("is_player", false)):
			return "第 %d 名" % (index + 1)
	return "榜外"

func _standings_lines(rows: Array) -> Array[String]:
	var lines: Array[String] = []
	for index in range(rows.size()):
		var row := Dictionary(rows[index]).duplicate(true)
		lines.append("%d.%s %d" % [index + 1, String(row.get("name", "钓手")), int(row.get("score", 0))])
	return lines

func _event_observe_markers(event_row: Dictionary) -> Array:
	var markers: Array = Array(event_row.get("observe_markers", [])).duplicate(true)
	var event_id := String(event_row.get("id", ""))
	if not event_id.is_empty() and not markers.has("fish_event:%s" % event_id):
		markers.append("fish_event:%s" % event_id)
	return markers

func _festival_score_markers(festival_id: String, projected_total: int) -> Array:
	var markers: Array = []
	for threshold in [4, 6, 8, 12]:
		if projected_total >= threshold:
			markers.append("festival_score:%s:%d" % [festival_id, threshold])
	return markers

func _weighted_pick(candidates: Array) -> Dictionary:
	var total := 0
	for entry in candidates:
		total += maxi(1, int(entry.get("weight", 1)))
	var roll := rng.randi_range(1, maxi(1, total))
	var running := 0
	for entry in candidates:
		running += maxi(1, int(entry.get("weight", 1)))
		if roll <= running:
			return Dictionary(entry).duplicate(true)
	return Dictionary(candidates[0]).duplicate(true)

func _catch_reward_for_rarity(rarity: String) -> Dictionary:
	match rarity:
		"epic":
			return {"glow_dust": 1, "glass": 1}
		"rare":
			return {"glass": 1, "water_drop": 1}
		"uncommon":
			return {"reed": 1, "water_drop": 1}
		_:
			return {"water_drop": 1}

func _competition_bonus_reward(rarity: String) -> Dictionary:
	match rarity:
		"epic":
			return {"glow_dust": 1, "paper": 1}
		"rare":
			return {"glass": 1, "paper": 1}
		"uncommon":
			return {"reed": 1, "paper": 1}
		_:
			return {"paper": 1}

func _format_item_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var keys: Array[String] = []
	for item_id in cost.keys():
		keys.append(String(item_id))
	keys.sort()
	var parts: Array[String] = []
	for item_id in keys:
		parts.append("%s x%d" % [_item_name(item_id), int(cost[item_id])])
	return " / ".join(parts)

func _item_name(item_id: String) -> String:
	return String(DataRepository.items.get(item_id, {}).get("name", item_id))

func _habitat_name(habitat_id: String) -> String:
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

func _weather_name(weather_id: String) -> String:
	return String({"clear": "晴日", "fog": "薄雾", "rain": "细雨", "storm": "风暴", "snow": "雪幕"}.get(weather_id, weather_id))

func _time_name(time_id: String) -> String:
	return String({"day": "白昼", "evening": "黄昏", "night": "夜晚"}.get(time_id, time_id))

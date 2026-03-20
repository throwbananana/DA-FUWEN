extends RefCounted

var rng := RandomNumberGenerator.new()

const RARITY_SCORE := {
	"common": 1,
	"uncommon": 2,
	"rare": 4,
	"epic": 7,
}

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
	var body_lines: Array[String] = [
		"[b]%s[/b]" % String(spot.get("name", _habitat_name(habitat_id))),
		"本次垂钓会直接消耗当前回合。",
		"[b]天气 / 时段[/b] %s / %s" % [_weather_name(GameState.weather_id), _time_name(GameState.time_of_day)],
		"[b]水域压力[/b] %d / 6" % pressure,
	]
	var choices := [
		{
			"id": "cast_line",
			"label": "下竿试钓",
			"summary": "直接尝试鱼讯，可能钓上常规鱼获，也可能触发稀有水系互动。",
		},
		{
			"id": "watch_tide",
			"label": "观水记纹",
			"summary": "不急着起鱼，更偏向观察水面动静、记录生态和传闻。",
		},
		{
			"id": "release_watch",
			"label": "放流护幼",
			"summary": "优先处理抱卵个体、幼体和纠缠线组，降低水域压力。",
		},
	]
	if not seasonal_event.is_empty():
		body_lines.append("[b]季节活动[/b] %s" % String(seasonal_event.get("title", "水域节庆")))
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
	match choice_id:
		"cast_line":
			return _resolve_cast_line(habitat_id)
		"watch_tide":
			return _resolve_watch_tide(habitat_id)
		"release_watch":
			return _resolve_release_watch(habitat_id)
		"join_competition":
			return _resolve_competition(habitat_id)
		_:
			return {"ok": false, "body": "今天没有合适的钓鱼动作。"}

func _resolve_cast_line(habitat_id: String) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	if spot.is_empty():
		return {"ok": false, "body": "这片水域今天没有鱼讯。"}
	var pressure := GameState.get_fishing_spot_pressure(habitat_id)
	var roll := rng.randf()
	var event_row := _pick_incident_event(habitat_id, "cast_line")
	if not event_row.is_empty() and roll <= 0.26:
		return _build_event_payload(event_row)
	if roll <= 0.18 + float(pressure) * 0.05:
		return {
			"ok": true,
			"title": "垂钓结果",
			"body_lines": [
				"[b]空军而返[/b]",
				"你刚把线抛进水面，附近就炸开了一圈受惊的水纹。",
				"今天这片水域的警戒又高了一点。",
			],
			"pressure_delta": 1,
			"items": {"water_drop": 1},
			"journal_entries": ["今天的鱼讯偏散，水面警戒明显升高。"],
			"log_line": "在 %s 试钓了一轮，但水面一下子静了。" % _habitat_name(habitat_id),
		}
	var aquatic_species := _pick_species(habitat_id, ["cast_line"])
	if aquatic_species.is_empty():
		return {"ok": true, "title": "垂钓结果", "body_lines": ["[b]没有起鱼[/b]", "水面只是轻轻动了一下，今天更适合先做观察。"], "log_line": "在 %s 下竿了一次，但今天更像是在试水。" % _habitat_name(habitat_id)}
	var rarity := String(aquatic_species.get("rarity", "common"))
	var species_id := String(aquatic_species.get("id", ""))
	var items := _catch_reward_for_rarity(rarity)
	var body_lines: Array[String] = [
		"[b]鱼讯上钩[/b]",
		"你拉起了 [b]%s[/b]，它在水面下绕了一个漂亮的弧。" % String(aquatic_species.get("name", species_id)),
		String(aquatic_species.get("catch_text", "这次手感不错，算是一次干净的中鱼。")),
	]
	if not items.is_empty():
		body_lines.append("[b]顺手带回[/b] %s" % _format_item_cost(items))
	return {
		"ok": true,
		"title": "垂钓结果",
		"body_lines": body_lines,
		"items": items,
		"catch_species_id": species_id,
		"weight_class": rarity,
		"pressure_delta": 1 if rarity in ["rare", "epic"] else 0,
		"journal_entries": [String(aquatic_species.get("journal_text", "%s 的游动方式被你记进了笔记。" % String(aquatic_species.get("name", species_id))))],
		"log_line": "在 %s 钓到了 %s。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
	}

func _resolve_watch_tide(habitat_id: String) -> Dictionary:
	var aquatic_species := _pick_species(habitat_id, ["watch_tide", "cast_line"])
	if aquatic_species.is_empty():
		return {
			"ok": true,
			"title": "观水记纹",
			"body_lines": [
				"[b]水面很安静[/b]",
				"你花了一个回合看水、看风和岸边留下的线痕，今天像是在为下一次鱼讯做准备。",
			],
			"items": {"paper": 1},
			"journal_entries": ["今天先记了水纹和岸边脚印，还没急着起鱼。"],
			"log_line": "在 %s 没急着下竿，而是先把水情记了下来。" % _habitat_name(habitat_id),
		}
	var species_id := String(aquatic_species.get("id", ""))
	var local_event := _pick_incident_event(habitat_id, "watch_tide")
	var body_lines: Array[String] = [
		"[b]你先看清了鱼路[/b]",
		"你没有急着起竿，而是顺着 [b]%s[/b] 的回游轨迹，把今天的水情记了下来。" % String(aquatic_species.get("name", species_id)),
		"这次没有直接带走什么，但之后遇到它会更从容。",
	]
	var payload := {
		"ok": true,
		"title": "观水记纹",
		"body_lines": body_lines,
		"items": {"paper": 1, "water_drop": 1},
		"journal_entries": [String(aquatic_species.get("watch_text", "%s 的回游路线被你单独记成了一页。" % String(aquatic_species.get("name", species_id))))],
		"log_line": "你在 %s 先记住了 %s 的鱼路。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
	}
	if not local_event.is_empty():
		payload = _merge_payloads(payload, _build_event_payload(local_event, false))
	return payload

func _resolve_release_watch(habitat_id: String) -> Dictionary:
	var aquatic_species := _pick_species(habitat_id, ["release_watch", "cast_line"])
	if aquatic_species.is_empty():
		return {"ok": true, "title": "放流护幼", "body_lines": ["[b]这次没有发现需要处理的个体[/b]", "你顺手理了理岸边的旧线组，水域压力略微回落。"], "pressure_delta": -1, "items": {"reed": 1}, "log_line": "你在 %s 清掉了一些旧线组。" % _habitat_name(habitat_id)}
	var species_id := String(aquatic_species.get("id", ""))
	return {
		"ok": true,
		"title": "放流护幼",
		"body_lines": [
			"[b]你先放了它回去[/b]",
			"你发现 [b]%s[/b] 正处在护幼 / 抱卵窗口，于是没有把这次相遇变成战利品。" % String(aquatic_species.get("name", species_id)),
			"这片水域的警戒随之回落了一些。",
		],
		"release_species_id": species_id,
		"pressure_delta": -1,
		"items": {"water_drop": 1, "reed": 1},
		"journal_entries": [String(aquatic_species.get("release_text", "%s 的护幼行为被你单独记了一页。" % String(aquatic_species.get("name", species_id))))],
		"relation_deltas": [{
			"actor_a": "npc:washer_grandma",
			"actor_b": "species:%s" % species_id,
			"affinity": 1,
			"familiarity": 1,
		}] if habitat_id == "crystal_creek" else [],
		"trust_rewards": {"washer_grandma": 1} if habitat_id == "crystal_creek" else {},
		"log_line": "你在 %s 放流了 %s。" % [_habitat_name(habitat_id), String(aquatic_species.get("name", species_id))],
	}

func _resolve_competition(habitat_id: String) -> Dictionary:
	var spot := DataRepository.get_fishing_spot(habitat_id)
	var event_row := _get_seasonal_festival_event(spot)
	if event_row.is_empty():
		return {"ok": true, "title": "今日没有比赛", "body_lines": ["[b]水边今天很安静[/b]", "这片水域今天没有对外开放的节庆活动。"], "log_line": "你赶到水边时，今天并没有比赛。"}
	var aquatic_species := _pick_species(habitat_id, ["festival", "cast_line"])
	var species_name := String(aquatic_species.get("name", "临时鱼获"))
	var rarity := String(aquatic_species.get("rarity", "common"))
	var score_delta := int(event_row.get("base_score", 2)) + int(RARITY_SCORE.get(rarity, 1))
	var items: Dictionary = Dictionary(event_row.get("items", {})).duplicate(true)
	for item_id in _competition_bonus_reward(rarity).keys():
		items[item_id] = int(items.get(item_id, 0)) + int(_competition_bonus_reward(rarity)[item_id])
	return {
		"ok": true,
		"title": String(event_row.get("title", "水域比赛")),
		"body_lines": [
			"[b]%s[/b]" % String(event_row.get("title", "水域比赛")),
			String(event_row.get("description", "你把这一回合拿来参加岸边的临时比赛。")),
			"本轮记分鱼获：%s ｜ 分数 +%d" % [species_name, score_delta],
			"你的成绩会沉淀到这个赛季的水域榜单里。",
		],
		"festival_id": String(event_row.get("id", "festival")),
		"score_delta": score_delta,
		"items": items,
		"trust_rewards": Dictionary(event_row.get("trust_rewards", {})).duplicate(true),
		"journal_entries": [String(event_row.get("journal_entry", "%s 的成绩被写进了本季水域记录。" % String(event_row.get("title", "比赛"))))],
		"story_flags": Array(event_row.get("story_flags", [])).duplicate(true),
		"log_line": "你在 %s 参加了 %s，靠 %s 拿到 %d 分。" % [_habitat_name(habitat_id), String(event_row.get("title", "水域比赛")), species_name, score_delta],
		"event_id": String(event_row.get("id", "")),
	}

func _pick_species(habitat_id: String, action_tags: Array = []) -> Dictionary:
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
	var max_pressure := int(event_row.get("max_pressure", 99))
	if GameState.get_fishing_spot_pressure(String(event_row.get("habitat_id", ""))) > max_pressure and max_pressure < 99:
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
	}

func _merge_payloads(base_payload: Dictionary, extra_payload: Dictionary) -> Dictionary:
	var merged: Dictionary = base_payload.duplicate(true)
	for key in ["items", "trust_rewards"]:
		var current: Dictionary = Dictionary(merged.get(key, {})).duplicate(true)
		for item_id in Dictionary(extra_payload.get(key, {})).keys():
			current[item_id] = int(current.get(item_id, 0)) + int(extra_payload.get(key, {}).get(item_id, 0))
		merged[key] = current
	for key in ["journal_entries", "relation_deltas", "story_flags", "body_lines"]:
		var current_array: Array = Array(merged.get(key, [])).duplicate(true)
		current_array.append_array(Array(extra_payload.get(key, [])).duplicate(true))
		merged[key] = current_array
	merged["pressure_delta"] = int(merged.get("pressure_delta", 0)) + int(extra_payload.get("pressure_delta", 0))
	if String(merged.get("event_id", "")).is_empty():
		merged["event_id"] = String(extra_payload.get("event_id", ""))
	if String(merged.get("log_line", "")).is_empty():
		merged["log_line"] = String(extra_payload.get("log_line", ""))
	return merged

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

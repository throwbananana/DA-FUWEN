class_name MetaBonusReportService
extends RefCounted

const EFFECT_LABELS := {
	"weekly_reroll_bonus": "每周重掷 +%d",
	"season_adjust_bonus": "赛季修正 +%d",
	"anchor_bonus": "开局锚定 +%d",
}

const EFFECT_TIMINGS := {
	"weekly_reroll_bonus": "season_baseline",
	"season_adjust_bonus": "season_baseline",
	"anchor_bonus": "run_start",
}

func build_module_rows(module_ids: Array = []) -> Array[Dictionary]:
	var data_repository := _data_repository()
	var resolved_ids: Array[String] = _resolve_module_ids(module_ids)
	var rows: Array[Dictionary] = []
	if data_repository == null:
		return rows
	for module_id in resolved_ids:
		var module: Dictionary = data_repository.get_dice_module(module_id)
		if module.is_empty():
			continue
		var effects: Dictionary = Dictionary(module.get("effects", {})).duplicate(true)
		var effect_lines: Array[String] = []
		var timings: Array[String] = []
		for effect_key in effects.keys():
			var key := String(effect_key)
			var amount := int(effects.get(key, 0))
			if amount == 0:
				continue
			var pattern := String(EFFECT_LABELS.get(key, "%s %+d"))
			if pattern.contains("%d"):
				effect_lines.append(pattern % amount)
			else:
				effect_lines.append("%s %+d" % [key, amount])
			var timing := String(EFFECT_TIMINGS.get(key, "runtime"))
			if not timings.has(timing):
				timings.append(timing)
		rows.append({
			"id": module_id,
			"name": String(module.get("name", module_id)),
			"description": String(module.get("description", "")),
			"effects": effects,
			"effect_lines": effect_lines,
			"timings": timings,
		})
	return rows

func build_active_bonus_report(module_ids: Array = []) -> Dictionary:
	var game_state := _game_state()
	var rows := build_module_rows(module_ids)
	var totals := {
		"weekly_reroll_bonus": 0,
		"season_adjust_bonus": 0,
		"anchor_bonus": 0,
	}
	for raw_row in rows:
		var row: Dictionary = Dictionary(raw_row).duplicate(true)
		var effects: Dictionary = Dictionary(row.get("effects", {})).duplicate(true)
		for effect_key in totals.keys():
			totals[effect_key] = int(totals.get(effect_key, 0)) + int(effects.get(effect_key, 0))

	var module_bits: Array[String] = []
	for raw_row in rows:
		var row: Dictionary = Dictionary(raw_row).duplicate(true)
		var effect_lines: Array[String] = []
		for raw_line in Array(row.get("effect_lines", [])).duplicate(true):
			effect_lines.append(String(raw_line))
		var joined_effects := " / ".join(effect_lines)
		if joined_effects.is_empty():
			module_bits.append(String(row.get("name", row.get("id", "模组"))))
		else:
			module_bits.append("%s（%s）" % [String(row.get("name", row.get("id", "模组"))), joined_effects])

	var lines: Array[String] = []
	if not module_bits.is_empty():
		lines.append("元成长模组：%s。" % "；".join(module_bits))
	if int(totals.get("weekly_reroll_bonus", 0)) > 0:
		lines.append("本赛季额外周重掷：+%d。" % int(totals.get("weekly_reroll_bonus", 0)))
	if int(totals.get("season_adjust_bonus", 0)) > 0:
		lines.append("本赛季额外修正点：+%d。" % int(totals.get("season_adjust_bonus", 0)))
	if int(totals.get("anchor_bonus", 0)) > 0:
		lines.append("本局开局额外锚定：+%d。" % int(totals.get("anchor_bonus", 0)))

	return {
		"rows": rows,
		"totals": totals,
		"lines": lines,
		"resource_snapshot": {
			"weekly_reroll_limit": 0 if game_state == null else int(game_state.weekly_reroll_limit),
			"season_adjust_points": 0 if game_state == null else int(game_state.season_adjust_points),
			"anchor_points": 0 if game_state == null else int(game_state.anchor_points),
		},
	}

func build_run_summary_appendix(summary: Dictionary = {}) -> Array[String]:
	var report := build_active_bonus_report()
	var appendix: Array[String] = []
	for raw_line in Array(report.get("lines", [])).duplicate(true):
		appendix.append(String(raw_line))
	if not summary.is_empty():
		var points := int(summary.get("points", 0))
		var total_after := int(summary.get("total_after", 0))
		appendix.append("本次远征结算点数：%d，累计探索点：%d。" % [points, total_after])
		var new_tracks: Array[String] = _coerce_string_array(summary.get("new_tracks", []))
		if not new_tracks.is_empty():
			appendix.append("新解锁轨道：%s。" % "、".join(new_tracks))
	return appendix

func build_compact_hint() -> String:
	var rows := build_module_rows()
	if rows.is_empty():
		return ""
	var bits: Array[String] = []
	for raw_row in rows:
		var row: Dictionary = Dictionary(raw_row).duplicate(true)
		var effect_lines: Array[String] = []
		for raw_line in Array(row.get("effect_lines", [])).duplicate(true):
			effect_lines.append(String(raw_line))
		if effect_lines.is_empty():
			continue
		bits.append("%s:%s" % [String(row.get("name", row.get("id", "模组"))), ", ".join(effect_lines)])
	if bits.is_empty():
		return ""
	return "元成长加成｜%s" % "；".join(bits)

func _resolve_module_ids(module_ids: Array) -> Array[String]:
	var game_state := _game_state()
	var source := module_ids
	if source.is_empty() and game_state != null:
		source = Array(game_state.meta_unlocks.get("dice_modules", [])).duplicate(true)
	return _coerce_string_array(source)

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

func _data_repository() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("DataRepository")

func _game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")

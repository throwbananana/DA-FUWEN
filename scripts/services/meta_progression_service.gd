class_name MetaProgressionService
extends RefCounted

func build_run_summary() -> Dictionary:
	return {
		"weeks_completed": maxi(0, GameState.week_index - 1),
		"seasons_completed": GameState.completed_seasons,
		"badges": GameState.badge_count,
		"discovered_species": GameState.discovered_species.size(),
		"exploration_points": GameState.exploration_points,
	}

func calculate_point_breakdown(summary: Dictionary) -> Dictionary:
	var points := int(summary.get("weeks_completed", 0))
	points += int(summary.get("seasons_completed", 0)) * 3
	points += int(summary.get("badges", 0)) * 2
	points += int(summary.get("discovered_species", 0))
	points += int(summary.get("exploration_points", 0))
	return {
		"weeks_completed": int(summary.get("weeks_completed", 0)),
		"seasons_completed": int(summary.get("seasons_completed", 0)),
		"badges": int(summary.get("badges", 0)),
		"discovered_species": int(summary.get("discovered_species", 0)),
		"exploration_points": int(summary.get("exploration_points", 0)),
		"points": points,
	}

func preview_run_rewards(summary: Dictionary) -> Dictionary:
	var breakdown := calculate_point_breakdown(summary)
	var exploration_points := int(breakdown.get("exploration_points", 0))
	var total_before := int(GameState.exploration_points_total)
	var pending_bonus_points := maxi(0, int(breakdown.get("points", 0)) - exploration_points)
	var total_after := total_before + pending_bonus_points
	var new_tracks := _collect_new_tracks(total_after)
	return {
		"points": int(breakdown.get("points", 0)),
		"bonus_points": pending_bonus_points,
		"already_banked_points": exploration_points,
		"total_before": total_before,
		"total_after": total_after,
		"new_tracks": new_tracks,
		"breakdown": breakdown,
	}

func commit_run_rewards(summary: Dictionary, auto_save: bool = true) -> Dictionary:
	var preview := preview_run_rewards(summary)
	var bonus_points := int(preview.get("bonus_points", 0))
	if bonus_points > 0:
		GameState.add_meta_progression_total(bonus_points)
	var unlocked_track_ids := GameState.register_meta_tracks(Array(preview.get("new_tracks", [])).duplicate(true))
	if auto_save:
		GameState.save_meta_progression()
	return {
		"points": int(preview.get("points", 0)),
		"bonus_points": bonus_points,
		"already_banked_points": int(preview.get("already_banked_points", 0)),
		"total_before": int(preview.get("total_before", 0)),
		"total_after": int(GameState.exploration_points_total),
		"new_tracks": Array(preview.get("new_tracks", [])).duplicate(true),
		"unlocked_track_ids": unlocked_track_ids,
		"saved": auto_save,
		"breakdown": Dictionary(preview.get("breakdown", {})).duplicate(true),
	}

func award_run_points(summary: Dictionary) -> Dictionary:
	return commit_run_rewards(summary)

func format_reward_summary(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("本局结算点数：%d" % int(result.get("points", 0)))
	if int(result.get("already_banked_points", 0)) > 0:
		lines.append("局内已累计探索点：%d" % int(result.get("already_banked_points", 0)))
	if int(result.get("bonus_points", 0)) > 0:
		lines.append("额外计入元成长：%d" % int(result.get("bonus_points", 0)))
	lines.append_array(format_new_tracks(Array(result.get("new_tracks", []))))
	return lines

func format_new_tracks(tracks: Array) -> Array[String]:
	var lines: Array[String] = []
	for track in tracks:
		lines.append("%s：%s" % [String(track.get("label", "新解锁")), String(track.get("description", ""))])
	return lines

func _collect_new_tracks(total_after: int) -> Array:
	var result: Array = []
	for track in DataRepository.get_meta_progression_tracks():
		var track_id := String(track.get("id", ""))
		if track_id.is_empty() or GameState.has_meta_track(track_id):
			continue
		if total_after >= int(track.get("threshold", 0)):
			result.append(track)
	return result

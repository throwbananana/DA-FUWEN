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

func award_run_points(summary: Dictionary) -> Dictionary:
	var points := int(summary.get("weeks_completed", 0))
	points += int(summary.get("seasons_completed", 0)) * 3
	points += int(summary.get("badges", 0)) * 2
	points += int(summary.get("discovered_species", 0))
	points += int(summary.get("exploration_points", 0))
	var total_after := GameState.exploration_points_total + points
	var new_tracks := _collect_new_tracks(total_after)
	return {
		"points": points,
		"total_after": total_after,
		"new_tracks": new_tracks,
	}

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

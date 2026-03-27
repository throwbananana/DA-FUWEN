extends SceneTree

const META_BONUS_REPORT_SERVICE := preload("res://scripts/services/meta_bonus_report_service.gd")
var _finished := false

func _initialize() -> void:
	create_timer(5.0).timeout.connect(_on_watchdog_timeout)
	var data_repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	data_repository.load_all()
	var previous_unlocks: Dictionary = Dictionary(game_state.meta_unlocks).duplicate(true)
	game_state.meta_unlocks = {
		"tracks": ["meta_path_alpha"],
		"dice_modules": ["steady_core", "trim_edge", "anchor_thread"],
	}

	var service = META_BONUS_REPORT_SERVICE.new()
	var report: Dictionary = service.build_active_bonus_report()
	var totals: Dictionary = Dictionary(report.get("totals", {})).duplicate(true)
	_assert(int(totals.get("weekly_reroll_bonus", 0)) == 1, "weekly_reroll_bonus total mismatch")
	_assert(int(totals.get("season_adjust_bonus", 0)) == 1, "season_adjust_bonus total mismatch")
	_assert(int(totals.get("anchor_bonus", 0)) == 1, "anchor_bonus total mismatch")

	var lines: Array = Array(report.get("lines", [])).duplicate(true)
	_assert(not lines.is_empty(), "report lines should not be empty")
	_assert(String(lines[0]).contains("元成长模组"), "first line should summarize module sources")

	var hint := service.build_compact_hint()
	_assert(hint.contains("稳态芯片"), "compact hint should include steady_core name")
	_assert(hint.contains("校准棱片"), "compact hint should include trim_edge name")
	_assert(hint.contains("锚定丝线"), "compact hint should include anchor_thread name")

	var appendix := service.build_run_summary_appendix({
		"points": 9,
		"total_after": 27,
		"new_tracks": ["path_beta"],
	})
	_assert(appendix.size() >= 3, "appendix should include report lines and settlement summary")
	_assert(String(appendix[appendix.size() - 1]).contains("path_beta"), "appendix should mention unlocked tracks")

	game_state.meta_unlocks = previous_unlocks
	_finished = true
	await create_timer(0.02).timeout
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	push_error("meta_bonus_report_smoke_test failed: %s" % message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

func _on_watchdog_timeout() -> void:
	if _finished:
		return
	_fail("timed out before completing checks.")

extends SceneTree

const SynergyService = preload("res://scripts/services/synergy_service.gd")

func _initialize() -> void:
	DataRepository.load_all()
	GameState.reset_for_new_season()
	var service := SynergyService.new()
	var report := service.build_synergy_report()
	var runtime_bonus := service.build_runtime_bonus(report)
	print("traits=", service.format_trait_effect_lines(report, 8))
	print("runtime=", runtime_bonus)
	quit()

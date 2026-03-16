extends SceneTree

const MonsterInstance = preload("res://scripts/monster_instance.gd")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	scene._on_roll_pressed()
	if scene.reachable_paths.is_empty():
		push_error("Smoke test failed: no reachable paths after roll.")
		quit(1)
		return
	var first_target := int(scene.reachable_paths.keys()[0])
	scene._on_board_node_chosen(first_target)

	var allies := [MonsterInstance.new("ember_lynx"), MonsterInstance.new("mossback")]
	var enemies := [MonsterInstance.new("stonehorn")]
	scene.battle_panel.start_battle({
		"title": "Smoke",
		"subtitle": "Battle entry check",
		"kind": "wild",
		"allow_capture": false,
		"allies": allies,
		"enemies": enemies,
		"ally_first_round_attack_bonus": false,
	})
	await process_frame
	scene.battle_panel._on_enemy_selected(enemies[0].uid)
	scene.battle_panel._on_skill_pressed(allies[0].uid, String(allies[0].skills[0]))
	await create_timer(0.2).timeout
	quit()

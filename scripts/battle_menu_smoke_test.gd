extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()

	var reserve_uid: String = game_state.add_companion("reed_frog_1", "后备雀")
	if not game_state.get_reserve_uids().has(reserve_uid):
		_fail("Battle menu smoke test failed: extra companion should enter the reserve roster.")
		return

	var battle_roster_service = load("res://scripts/services/battle_roster_service.gd").new()
	var battle_panel = scene.battle_panel

	battle_panel.start_battle(_build_battle_config(battle_roster_service))
	await process_frame
	if not _has_button_text(battle_panel.action_box, "状态") or not _has_button_text(battle_panel.action_box, "战斗") or not _has_button_text(battle_panel.action_box, "逃跑") or not _has_button_text(battle_panel.action_box, "背包"):
		_fail("Battle menu smoke test failed: root battle menu should expose 状态 / 战斗 / 逃跑 / 背包.")
		return

	_press_button_with_prefix(battle_panel.action_box, "背包")
	await process_frame
	if not _has_button_prefix(battle_panel.action_box, "换上 后备雀"):
		_fail("Battle menu smoke test failed: bag menu should expose reserve pet swapping.")
		return
	if not _has_button_prefix(battle_panel.action_box, "捕捉球 x"):
		_fail("Battle menu smoke test failed: bag menu should expose capture items.")
		return
	if not _has_button_prefix(battle_panel.action_box, "疗伤药 x"):
		_fail("Battle menu smoke test failed: bag menu should expose healing items.")
		return

	var active_actor = battle_panel._get_unit_by_uid(String(battle_panel.active_actor_uid))
	active_actor.take_damage(4)
	battle_panel.selected_ally_uid = active_actor.uid
	var hp_before: int = active_actor.current_hp
	var potion_before: int = game_state.get_item_count("healing_potion")
	await battle_panel._use_battle_item(active_actor, "healing_potion")
	if active_actor.current_hp <= hp_before:
		_fail("Battle menu smoke test failed: healing item should restore HP to the selected ally.")
		return
	if game_state.get_item_count("healing_potion") != potion_before - 1:
		_fail("Battle menu smoke test failed: using a healing item should consume inventory.")
		return
	battle_panel._finish_battle({"player_won": true, "captured_species": "", "battle_kind": "wild"})
	await process_frame

	battle_panel.start_battle(_build_battle_config(battle_roster_service))
	await process_frame
	_press_button_with_prefix(battle_panel.action_box, "背包")
	await process_frame
	active_actor = battle_panel._get_unit_by_uid(String(battle_panel.active_actor_uid))
	await battle_panel._swap_in_reserve_pet(active_actor, reserve_uid)
	if not game_state.get_battle_party_uids().has(reserve_uid):
		_fail("Battle menu smoke test failed: swapping from the bag should update the live battle slots.")
		return
	var found_swapped_unit := false
	for ally_value in battle_panel.allies:
		var ally = ally_value
		if ally.uid == reserve_uid:
			found_swapped_unit = true
			break
	if not found_swapped_unit:
		_fail("Battle menu smoke test failed: swapped reserve pet should enter the allied roster immediately.")
		return

	await create_timer(0.05).timeout
	quit()

func _build_battle_config(battle_roster_service) -> Dictionary:
	var monster_script = load("res://scripts/monster_instance.gd")
	var enemy_a = monster_script.new("moss_puff", 1, 1)
	enemy_a.speed = 1
	enemy_a.attack = 1
	var enemy_b = monster_script.new("dew_slug", 1, 1)
	enemy_b.speed = 1
	enemy_b.attack = 1
	return {
		"title": "战斗菜单冒烟",
		"subtitle": "验证四段式入口、背包换宠和战斗道具。",
		"kind": "wild",
		"allow_capture": true,
		"allow_escape": true,
		"ally_first_round_attack_bonus": false,
		"ally_attack_bonus": 0,
		"ally_speed_bonus": 0,
		"ally_hp_bonus": 0,
		"ally_heal_bonus": 0,
		"ally_guard_bonus": 0.0,
		"enemy_attack_penalty": 0,
		"consume_minigame_bonus": false,
		"round_limit": 6,
		"allies": battle_roster_service.build_active_allies(),
		"ally_reserve": battle_roster_service.build_reserve_allies(),
		"enemies": [enemy_a, enemy_b],
	}

func _has_button_text(parent: Node, expected: String) -> bool:
	for child in parent.get_children():
		if child is Button and String(child.text) == expected:
			return true
	return false

func _has_button_prefix(parent: Node, prefix: String) -> bool:
	for child in parent.get_children():
		if child is Button and String(child.text).begins_with(prefix):
			return true
	return false

func _press_button_with_prefix(parent: Node, prefix: String) -> void:
	for child in parent.get_children():
		if child is Button and String(child.text).begins_with(prefix):
			child.emit_signal("pressed")
			return
	_fail("Battle menu smoke test failed: could not find button with prefix %s." % prefix)

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

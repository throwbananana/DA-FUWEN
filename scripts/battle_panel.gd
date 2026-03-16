class_name BattlePanel
extends PanelContainer

const GameData = preload("res://scripts/game_data.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")

signal battle_finished(result: Dictionary)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var turn_label: Label = $MarginContainer/VBoxContainer/TurnLabel
@onready var ally_list: VBoxContainer = $MarginContainer/VBoxContainer/TeamsRow/AllyList
@onready var enemy_list: VBoxContainer = $MarginContainer/VBoxContainer/TeamsRow/EnemyList
@onready var battle_log: RichTextLabel = $MarginContainer/VBoxContainer/BattleLog
@onready var action_box: VBoxContainer = $MarginContainer/VBoxContainer/ActionBox

var rng := RandomNumberGenerator.new()
var battle_config := {}
var allies: Array = []
var enemies: Array = []
var temp_state := {}
var turn_queue: Array = []
var round_index := 1
var selected_enemy_uid := ""
var selected_ally_uid := ""
var active_actor_uid := ""
var result_sent := false

func _ready() -> void:
	hide()
	rng.randomize()

func start_battle(config: Dictionary) -> void:
	battle_config = config.duplicate(true)
	allies = config.get("allies", [])
	enemies = config.get("enemies", [])
	temp_state.clear()
	turn_queue.clear()
	round_index = 1
	selected_enemy_uid = ""
	selected_ally_uid = ""
	active_actor_uid = ""
	result_sent = false
	for unit in allies + enemies:
		temp_state[unit.uid] = {
			"cooldowns": {},
			"statuses": {},
			"guard": 0.0,
		}
	title_label.text = "%s" % String(config.get("title", "遭遇战"))
	subtitle_label.text = String(config.get("subtitle", ""))
	battle_log.text = "[b]战斗开始[/b]\n"
	show()
	_render_rosters()
	_begin_round()

func _begin_round() -> void:
	if _try_finish_battle():
		return
	turn_label.text = "第 %d 轮" % round_index
	turn_queue.clear()
	for uid in temp_state.keys():
		temp_state[uid]["guard"] = 0.0
	for unit in allies + enemies:
		if unit.is_alive():
			turn_queue.append(unit)
	turn_queue.sort_custom(_sort_turn_order)
	_advance_turn()

func _sort_turn_order(a: MonsterInstance, b: MonsterInstance) -> bool:
	var a_speed := _get_effective_speed(a)
	var b_speed := _get_effective_speed(b)
	if a_speed == b_speed:
		return a.current_hp > b.current_hp
	return a_speed > b_speed

func _advance_turn() -> void:
	if result_sent:
		return
	while not turn_queue.is_empty():
		var actor: MonsterInstance = turn_queue.pop_front()
		if not actor.is_alive():
			continue
		active_actor_uid = actor.uid
		_render_rosters()
		if _is_ally(actor):
			_prompt_player_action(actor)
		else:
			_schedule_enemy_action(actor)
		return
	_end_round()

func _prompt_player_action(actor: MonsterInstance) -> void:
	_clear_action_buttons()
	var alive_enemies := _alive_enemies()
	var alive_allies := _alive_allies()
	if selected_enemy_uid == "" or _get_unit_by_uid(selected_enemy_uid) == null or not _get_unit_by_uid(selected_enemy_uid).is_alive():
		selected_enemy_uid = alive_enemies[0].uid if not alive_enemies.is_empty() else ""
	if selected_ally_uid == "" or _get_unit_by_uid(selected_ally_uid) == null or not _get_unit_by_uid(selected_ally_uid).is_alive():
		selected_ally_uid = actor.uid if not alive_allies.is_empty() else ""

	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "轮到 %s 行动。先点击敌人/友军头像选目标，再选择技能。" % actor.display_name
	action_box.add_child(intro)

	for skill_id in actor.skills:
		var skill: Dictionary = GameData.SKILLS.get(skill_id, {})
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(300, 48)
		var cooldown_left := int(temp_state[actor.uid]["cooldowns"].get(skill_id, 0))
		button.text = "%s  %s" % [String(skill.get("name", skill_id)), _skill_detail_text(skill)]
		button.disabled = cooldown_left > 0 or not _has_valid_target(skill)
		if cooldown_left > 0:
			button.text += "  CD:%d" % cooldown_left
		button.pressed.connect(_on_skill_pressed.bind(actor.uid, skill_id))
		action_box.add_child(button)

	if bool(battle_config.get("allow_capture", false)):
		var capture_button := Button.new()
		capture_button.focus_mode = Control.FOCUS_NONE
		capture_button.custom_minimum_size = Vector2(300, 48)
		capture_button.text = "尝试捕缚  对低生命野怪成功率更高"
		capture_button.disabled = alive_enemies.is_empty()
		capture_button.pressed.connect(_on_capture_pressed.bind(actor.uid))
		action_box.add_child(capture_button)

func _schedule_enemy_action(actor: MonsterInstance) -> void:
	_clear_action_buttons()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s 正在评估局势…" % actor.display_name
	action_box.add_child(info)
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(_on_enemy_timer_timeout.bind(actor), CONNECT_ONE_SHOT)

func _on_enemy_timer_timeout(actor: MonsterInstance) -> void:
	if result_sent or not actor.is_alive():
		return
	var skill_id := _choose_enemy_skill(actor)
	_perform_skill(actor, skill_id)

func _choose_enemy_skill(actor: MonsterInstance) -> String:
	var available: Array[String] = []
	for skill_id in actor.skills:
		if int(temp_state[actor.uid]["cooldowns"].get(skill_id, 0)) <= 0:
			available.append(skill_id)
	if available.is_empty():
		return actor.skills[0]
	available.sort_custom(func(a: String, b: String) -> bool:
		return int(GameData.SKILLS[a].get("power", 0)) > int(GameData.SKILLS[b].get("power", 0))
	)
	var wounded_allies := _team_lowest_health(_get_team_for(actor))
	if not wounded_allies.is_empty():
		for skill_id in available:
			if GameData.SKILLS[skill_id].get("effect", "") == "heal":
				var target: MonsterInstance = wounded_allies[0]
				if target.current_hp < target.max_hp / 2:
					selected_ally_uid = target.uid
					return skill_id
	for skill_id in available:
		if GameData.SKILLS[skill_id].get("effect", "") == "guard" and actor.current_hp < actor.max_hp / 2:
			return skill_id
	return available[0]

func _on_skill_pressed(actor_uid: String, skill_id: String) -> void:
	var actor := _get_unit_by_uid(actor_uid)
	if actor == null or actor.uid != active_actor_uid:
		return
	_perform_skill(actor, skill_id)

func _perform_skill(actor: MonsterInstance, skill_id: String) -> void:
	var skill: Dictionary = GameData.SKILLS.get(skill_id, {})
	temp_state[actor.uid]["cooldowns"][skill_id] = int(skill.get("cooldown", 0))
	var target_mode := String(skill.get("target", "enemy"))
	if target_mode == "enemy_all":
		for foe in _get_opponents(actor):
			if foe.is_alive():
				var aoe_damage := int(skill.get("effect_value", 0)) + int(round(actor.attack * 0.4))
				_apply_damage(actor, foe, aoe_damage, String(skill.get("type", actor.type)), String(skill.get("name", skill_id)))
		_log("%s 释放了 %s，对全体敌人造成压制。" % [actor.display_name, skill.get("name", skill_id)])
	else:
		var target := _resolve_target(actor, skill)
		if target == null:
			_log("%s 的 %s 没有合法目标。" % [actor.display_name, skill.get("name", skill_id)])
			_end_actor_turn()
			return
		match String(skill.get("effect", "")):
			"heal":
				var heal_value := int(skill.get("effect_value", 0)) + actor.get_role_bonus("lab")
				target.heal(heal_value)
				_log("%s 对 %s 施放 %s，回复 %d 点生命。" % [actor.display_name, target.display_name, skill.get("name", skill_id), heal_value])
			"guard":
				temp_state[target.uid]["guard"] = float(skill.get("effect_value", 0.5))
				_log("%s 进入防御姿态：%s。" % [actor.display_name, skill.get("name", skill_id)])
			_:
				var damage := _calculate_damage(actor, target, skill)
				_apply_damage(actor, target, damage, String(skill.get("type", actor.type)), String(skill.get("name", skill_id)))
				_apply_status_if_needed(target, skill)
	_end_actor_turn()

func _on_capture_pressed(actor_uid: String) -> void:
	var actor := _get_unit_by_uid(actor_uid)
	if actor == null or actor.uid != active_actor_uid:
		return
	var target := _get_unit_by_uid(selected_enemy_uid)
	if target == null or not target.is_alive():
		target = _alive_enemies()[0] if not _alive_enemies().is_empty() else null
	if target == null:
		return
	var chance := 0.2 + float(target.max_hp - target.current_hp) / float(target.max_hp) * 0.55
	if target.current_hp <= target.max_hp / 3:
		chance += 0.15
	if rng.randf() <= chance:
		target.current_hp = 0
		_log("%s 成功捕缚了 %s。" % [actor.display_name, target.display_name])
		_finish_battle({
			"player_won": true,
			"captured_species": target.species_id,
			"battle_kind": battle_config.get("kind", "wild"),
		})
		return
	_log("%s 的捕缚失败了，%s 仍在挣扎。" % [actor.display_name, target.display_name])
	_end_actor_turn()

func _calculate_damage(actor: MonsterInstance, target: MonsterInstance, skill: Dictionary) -> int:
	var attack_value := actor.attack
	var weaken: Dictionary = temp_state[actor.uid]["statuses"].get("weaken", {})
	if not weaken.is_empty():
		attack_value -= int(weaken.get("value", 0))
	if round_index == 1 and _is_ally(actor) and bool(battle_config.get("ally_first_round_attack_bonus", false)):
		attack_value += 2
	var power := int(skill.get("power", 0))
	var raw_damage := attack_value + power
	var multiplier := GameData.type_multiplier(String(skill.get("type", actor.type)), target.type)
	var vulnerable: Dictionary = temp_state[target.uid]["statuses"].get("vulnerable", {})
	if not vulnerable.is_empty():
		multiplier += 0.25
	var damage := int(round(raw_damage * 0.55 * multiplier))
	damage += rng.randi_range(-1, 2)
	damage = maxi(1, damage)
	var guard_ratio := float(temp_state[target.uid].get("guard", 0.0))
	if guard_ratio > 0.0:
		damage = int(round(damage * (1.0 - guard_ratio)))
	return maxi(1, damage)

func _apply_damage(actor: MonsterInstance, target: MonsterInstance, damage: int, skill_type: String, skill_name: String) -> void:
	target.take_damage(damage)
	var multiplier := GameData.type_multiplier(skill_type, target.type)
	var suffix := ""
	if multiplier > 1.0:
		suffix = " 克制"
	elif multiplier < 1.0:
		suffix = " 被抗"
	_log("%s 对 %s 使用 %s，造成 %d 点伤害。%s%s" % [
		actor.display_name,
		target.display_name,
		skill_name,
		damage,
		"%s HP %d/%d" % [target.display_name, target.current_hp, target.max_hp],
		suffix,
	])

func _apply_status_if_needed(target: MonsterInstance, skill: Dictionary) -> void:
	var effect := String(skill.get("effect", ""))
	if effect in ["slow", "weaken", "vulnerable", "haste"]:
		var recipient := target
		if String(skill.get("effect_target", "target")) == "self":
			recipient = _get_unit_by_uid(active_actor_uid)
		temp_state[recipient.uid]["statuses"][effect] = {
			"turns": int(skill.get("effect_turns", 1)),
			"value": int(skill.get("effect_value", 3)),
		}
		_log("%s 获得状态：%s。" % [recipient.display_name, effect])

func _resolve_target(actor: MonsterInstance, skill: Dictionary) -> MonsterInstance:
	match String(skill.get("target", "enemy")):
		"self":
			return actor
		"ally":
			var selected_ally := _get_unit_by_uid(selected_ally_uid)
			if selected_ally != null and _get_team_for(selected_ally) == _get_team_for(actor) and selected_ally.is_alive():
				return selected_ally
			var wounded := _team_lowest_health(_get_team_for(actor))
			return wounded[0] if not wounded.is_empty() else actor
		_:
			var selected_enemy := _get_unit_by_uid(selected_enemy_uid)
			if selected_enemy != null and _get_team_for(selected_enemy) != _get_team_for(actor) and selected_enemy.is_alive():
				return selected_enemy
			var foes := _get_opponents(actor)
			return foes[0] if not foes.is_empty() else null

func _has_valid_target(skill: Dictionary) -> bool:
	match String(skill.get("target", "enemy")):
		"ally":
			return not _alive_allies().is_empty()
		"self":
			return true
		"enemy_all":
			return not _alive_enemies().is_empty()
		_:
			return not _alive_enemies().is_empty()

func _end_actor_turn() -> void:
	var actor := _get_unit_by_uid(active_actor_uid)
	if actor != null:
		for skill_id in temp_state[actor.uid]["cooldowns"].keys():
			var value := int(temp_state[actor.uid]["cooldowns"][skill_id])
			if value > 0:
				temp_state[actor.uid]["cooldowns"][skill_id] = value
		_render_rosters()
	if _try_finish_battle():
		return
	active_actor_uid = ""
	_advance_turn()

func _end_round() -> void:
	for uid in temp_state.keys():
		for skill_id in temp_state[uid]["cooldowns"].keys():
			var left := int(temp_state[uid]["cooldowns"][skill_id])
			if left > 0:
				temp_state[uid]["cooldowns"][skill_id] = left - 1
		var statuses: Dictionary = temp_state[uid]["statuses"]
		for status_id in statuses.keys().duplicate():
			statuses[status_id]["turns"] = int(statuses[status_id].get("turns", 0)) - 1
			if int(statuses[status_id]["turns"]) <= 0:
				statuses.erase(status_id)
	round_index += 1
	_begin_round()

func _try_finish_battle() -> bool:
	if _alive_allies().is_empty():
		_finish_battle({
			"player_won": false,
			"captured_species": "",
			"battle_kind": battle_config.get("kind", "wild"),
		})
		return true
	if _alive_enemies().is_empty():
		_finish_battle({
			"player_won": true,
			"captured_species": "",
			"battle_kind": battle_config.get("kind", "wild"),
		})
		return true
	return false

func _finish_battle(result: Dictionary) -> void:
	if result_sent:
		return
	result_sent = true
	hide()
	battle_finished.emit(result)

func _render_rosters() -> void:
	for child in ally_list.get_children():
		child.queue_free()
	for child in enemy_list.get_children():
		child.queue_free()
	for ally in allies:
		ally_list.add_child(_make_unit_button(ally, true))
	for enemy in enemies:
		enemy_list.add_child(_make_unit_button(enemy, false))

func _make_unit_button(unit: MonsterInstance, is_ally: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(250, 72)
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not unit.is_alive()
	var marker := ""
	if active_actor_uid == unit.uid:
		marker = ">> "
	elif selected_enemy_uid == unit.uid or selected_ally_uid == unit.uid:
		marker = "◆ "
	var status_text := _status_text(unit.uid)
	button.text = "%s%s  %s\nATK %d SPD %d  HP %d/%d%s" % [
		marker,
		unit.display_name,
		GameData.get_type_name(unit.type),
		unit.attack,
		_get_effective_speed(unit),
		unit.current_hp,
		unit.max_hp,
		status_text,
	]
	if is_ally:
		button.pressed.connect(_on_ally_selected.bind(unit.uid))
	else:
		button.pressed.connect(_on_enemy_selected.bind(unit.uid))
	return button

func _status_text(uid: String) -> String:
	var statuses: Dictionary = temp_state.get(uid, {}).get("statuses", {})
	var parts: Array[String] = []
	for status_id in statuses.keys():
		parts.append("%s(%d)" % [status_id, int(statuses[status_id].get("turns", 0))])
	if float(temp_state.get(uid, {}).get("guard", 0.0)) > 0.0:
		parts.append("guard")
	if parts.is_empty():
		return ""
	return "  [%s]" % ",".join(parts)

func _on_enemy_selected(uid: String) -> void:
	selected_enemy_uid = uid
	_render_rosters()

func _on_ally_selected(uid: String) -> void:
	selected_ally_uid = uid
	_render_rosters()

func _skill_detail_text(skill: Dictionary) -> String:
	var power := int(skill.get("power", 0))
	var detail := "威力 %d" % power if power > 0 else String(skill.get("text", ""))
	if power > 0 and String(skill.get("effect", "")) != "":
		detail += " / %s" % String(skill.get("effect", ""))
	return detail

func _clear_action_buttons() -> void:
	for child in action_box.get_children():
		child.queue_free()

func _log(message: String) -> void:
	battle_log.text += "%s\n" % message
	battle_log.scroll_to_line(battle_log.get_line_count())

func _alive_allies() -> Array:
	var alive := []
	for ally in allies:
		if ally.is_alive():
			alive.append(ally)
	return alive

func _alive_enemies() -> Array:
	var alive := []
	for enemy in enemies:
		if enemy.is_alive():
			alive.append(enemy)
	return alive

func _get_unit_by_uid(uid: String) -> MonsterInstance:
	for unit in allies + enemies:
		if unit.uid == uid:
			return unit
	return null

func _is_ally(unit: MonsterInstance) -> bool:
	return allies.has(unit)

func _get_team_for(unit: MonsterInstance) -> Array:
	return allies if _is_ally(unit) else enemies

func _get_opponents(unit: MonsterInstance) -> Array:
	return _alive_enemies() if _is_ally(unit) else _alive_allies()

func _team_lowest_health(team: Array) -> Array:
	var alive := []
	for unit in team:
		if unit.is_alive():
			alive.append(unit)
	alive.sort_custom(func(a: MonsterInstance, b: MonsterInstance) -> bool:
		return a.current_hp < b.current_hp
	)
	return alive

func _get_effective_speed(unit: MonsterInstance) -> int:
	var speed := unit.speed
	var statuses: Dictionary = temp_state.get(unit.uid, {}).get("statuses", {})
	if statuses.has("slow"):
		speed -= 3
	if statuses.has("haste"):
		speed += 3
	return speed

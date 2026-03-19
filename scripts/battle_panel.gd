class_name BattlePanel
extends PanelContainer

const GameData = preload("res://scripts/game_data.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")
const LocalizationService = preload("res://scripts/services/localization_service.gd")
const ENEMY_THINK_DELAY := 1.15
const PLAYER_COMMIT_DELAY := 0.42
const TURN_ADVANCE_DELAY := 0.62
const BATTLE_LOG_TYPEWRITER_SPEED := 0.020
const BATTLE_LOG_TYPEWRITER_MIN_DURATION := 0.18
const BATTLE_LOG_TYPEWRITER_MAX_DURATION := 1.20

signal battle_finished(result: Dictionary)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var turn_label: Label = $MarginContainer/VBoxContainer/TurnLabel
@onready var turn_order_bar: BoxContainer = $MarginContainer/VBoxContainer/TurnOrderBar
@onready var teams_row: BoxContainer = $MarginContainer/VBoxContainer/TeamsRow
@onready var ally_list: VBoxContainer = $MarginContainer/VBoxContainer/TeamsRow/AllyList
@onready var enemy_list: VBoxContainer = $MarginContainer/VBoxContainer/TeamsRow/EnemyList
@onready var action_preview_panel: PanelContainer = $MarginContainer/VBoxContainer/ActionPreviewPanel
@onready var action_preview_label: Label = $MarginContainer/VBoxContainer/ActionPreviewPanel/MarginContainer/VBoxContainer/ActionPreviewLabel
@onready var action_preview_detail_label: Label = $MarginContainer/VBoxContainer/ActionPreviewPanel/MarginContainer/VBoxContainer/ActionPreviewDetailLabel
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
var pending_action := {}
var preview_actor_uid := ""
var preview_skill_id := ""
var preview_target_uid := ""
var preview_target_mode := ""
var recent_actor_uid := ""
var recent_target_uid := ""
var round_order_uids: Array[String] = []
var acted_actor_uids: Array[String] = []
var action_locked := false
var result_sent := false
var _fx_layer: Control
var _fx_flash: ColorRect
var _fx_banner: Label
var _fx_banner_tween: Tween
var _fx_panel_tween: Tween
var _fx_shake_tween: Tween
var _fx_flash_tween: Tween
var _turn_label_tween: Tween
var _finish_tween: Tween
var _battle_log_tween: Tween
var _base_position := Vector2.ZERO
var _selection_label: Label
var _battle_log_lines: Array[String] = []
var _unit_card_nodes := {}
var localization_service := LocalizationService.new()

func _ready() -> void:
	hide()
	rng.randomize()
	modulate.a = 1.0
	scale = Vector2.ONE
	_base_position = position
	_ensure_fx_layer()
	_ensure_selection_label()
	_apply_responsive_layout()

func start_battle(config: Dictionary) -> void:
	if _finish_tween != null:
		_finish_tween.kill()
		_finish_tween = null
	battle_config = config.duplicate(true)
	allies = config.get("allies", [])
	enemies = config.get("enemies", [])
	temp_state.clear()
	turn_queue.clear()
	round_index = 1
	selected_enemy_uid = ""
	selected_ally_uid = ""
	active_actor_uid = ""
	pending_action.clear()
	preview_actor_uid = ""
	preview_skill_id = ""
	preview_target_uid = ""
	preview_target_mode = ""
	recent_actor_uid = ""
	recent_target_uid = ""
	round_order_uids.clear()
	acted_actor_uids.clear()
	action_locked = false
	result_sent = false
	for unit in allies + enemies:
		temp_state[unit.uid] = {
			"cooldowns": {},
			"statuses": {},
			"guard": 0.0,
		}
	_apply_prebattle_modifiers()
	title_label.text = "%s" % String(config.get("title", _tr("battle.default_title")))
	subtitle_label.text = String(config.get("subtitle", ""))
	_reset_battle_log([_tr("battle.start")])
	for line in _build_bonus_log_lines():
		_log(line)
	show()
	move_to_front()
	_apply_responsive_layout()
	_base_position = position
	_play_open_animation()
	_render_rosters()
	_update_selection_summary()
	_show_battle_banner(_tr("battle.start"), String(config.get("title", _tr("battle.default_title"))), Color(0.98, 0.79, 0.36, 1.0))
	_begin_round()

func _begin_round() -> void:
	if _try_finish_battle():
		return
	turn_label.text = _tr("battle.round", {"round": round_index})
	turn_queue.clear()
	round_order_uids.clear()
	acted_actor_uids.clear()
	_clear_action_preview()
	for uid in temp_state.keys():
		temp_state[uid]["guard"] = 0.0
	for unit in allies + enemies:
		if _is_ally(unit):
			temp_state[unit.uid]["guard"] = float(battle_config.get("ally_guard_bonus", 0.0))
		if unit.is_alive():
			turn_queue.append(unit)
	turn_queue.sort_custom(_sort_turn_order)
	for unit in turn_queue:
		round_order_uids.append(unit.uid)
	_render_turn_order_bar()
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
		recent_actor_uid = ""
		recent_target_uid = ""
		active_actor_uid = actor.uid
		action_locked = false
		_set_action_preview(actor.uid)
		_render_rosters()
		_render_turn_order_bar()
		_pulse_turn_label(actor.display_name)
		if _is_ally(actor):
			_prompt_player_action(actor)
		else:
			_schedule_enemy_action(actor)
		return
	_end_round()

func _prompt_player_action(actor: MonsterInstance) -> void:
	pending_action.clear()
	_prompt_player_action_with_feedback(actor, true)

func _prompt_player_action_with_feedback(actor: MonsterInstance, show_banner: bool) -> void:
	_clear_action_buttons()
	var alive_enemies := _alive_enemies()
	var alive_allies := _alive_allies()
	if selected_enemy_uid == "" or _get_unit_by_uid(selected_enemy_uid) == null or not _get_unit_by_uid(selected_enemy_uid).is_alive():
		selected_enemy_uid = alive_enemies[0].uid if not alive_enemies.is_empty() else ""
	if selected_ally_uid == "" or _get_unit_by_uid(selected_ally_uid) == null or not _get_unit_by_uid(selected_ally_uid).is_alive():
		selected_ally_uid = actor.uid if not alive_allies.is_empty() else ""

	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pending_action.is_empty():
		intro.text = _tr("battle.prompt.player", {"actor": actor.display_name})
	else:
		intro.text = _tr("battle.prompt.choose_target", {
			"actor": actor.display_name,
			"skill": _skill_name(String(pending_action.get("skill_id", "")), GameData.get_skill(String(pending_action.get("skill_id", "")))),
		})
	action_box.add_child(intro)
	_update_selection_summary(actor)
	if show_banner:
		_show_battle_banner(_tr("battle.turn.player"), actor.display_name, Color(0.50, 0.84, 1.0, 1.0))

	for skill_id in actor.skills:
		var skill: Dictionary = GameData.get_skill(String(skill_id))
		var skill_name := _skill_name(String(skill_id), skill)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, _action_button_height())
		var cooldown_left := int(temp_state[actor.uid]["cooldowns"].get(skill_id, 0))
		var prefix := "▶ " if String(pending_action.get("skill_id", "")) == String(skill_id) else ""
		button.text = "%s%s  %s" % [prefix, skill_name, _skill_detail_text(skill_id, skill)]
		button.disabled = cooldown_left > 0 or not _has_valid_target(skill)
		if cooldown_left > 0:
			button.text += "  CD:%d" % cooldown_left
		button.pressed.connect(_on_skill_pressed.bind(actor.uid, skill_id))
		action_box.add_child(button)

	if bool(battle_config.get("allow_capture", false)):
		var capture_button := Button.new()
		capture_button.focus_mode = Control.FOCUS_NONE
		capture_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		capture_button.custom_minimum_size = Vector2(0, _action_button_height())
		capture_button.text = "%s  %s" % [_tr("battle.capture"), _tr("battle.capture_hint")]
		capture_button.disabled = alive_enemies.is_empty()
		capture_button.pressed.connect(_on_capture_pressed.bind(actor.uid))
		action_box.add_child(capture_button)

	if not pending_action.is_empty():
		var cancel_button := Button.new()
		cancel_button.focus_mode = Control.FOCUS_NONE
		cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel_button.custom_minimum_size = Vector2(0, _secondary_action_button_height())
		cancel_button.text = _tr("battle.preview.cancel")
		cancel_button.pressed.connect(_cancel_pending_action.bind(actor.uid))
		action_box.add_child(cancel_button)

func _schedule_enemy_action(actor: MonsterInstance) -> void:
	_clear_action_buttons()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skill_id := _choose_enemy_skill(actor)
	if skill_id.is_empty():
		info.text = _tr("battle.prompt.enemy_thinking", {"actor": actor.display_name})
		action_box.add_child(info)
		_set_action_preview(actor.uid)
		_render_rosters()
		_update_selection_summary(actor)
		_show_battle_banner(_tr("battle.turn.enemy"), actor.display_name, Color(1.0, 0.55, 0.47, 1.0))
		var wait_timer := get_tree().create_timer(0.05 if GameState.should_skip_animations() else ENEMY_THINK_DELAY)
		wait_timer.timeout.connect(_on_enemy_wait_timeout.bind(actor), CONNECT_ONE_SHOT)
		return
	var skill := GameData.get_skill(skill_id)
	var skill_name := _skill_name(skill_id, skill)
	var target_uid := _choose_target_uid(actor, skill)
	var target := _get_unit_by_uid(target_uid)
	info.text = _tr("battle.prompt.enemy_thinking", {"actor": actor.display_name}) if target == null else _tr("battle.prompt.enemy_intent", {
		"actor": actor.display_name,
		"target": target.display_name,
		"skill": skill_name,
	})
	action_box.add_child(info)
	_set_action_preview(actor.uid, skill_id, target_uid)
	_render_rosters()
	_update_selection_summary(actor, target, skill_name)
	_show_battle_banner(_tr("battle.turn.enemy"), actor.display_name, Color(1.0, 0.55, 0.47, 1.0))
	var timer := get_tree().create_timer(0.05 if GameState.should_skip_animations() else ENEMY_THINK_DELAY)
	timer.timeout.connect(_on_enemy_timer_timeout.bind(actor, skill_id, target_uid), CONNECT_ONE_SHOT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _on_enemy_wait_timeout(actor: MonsterInstance) -> void:
	if result_sent or not actor.is_alive() or actor.uid != active_actor_uid:
		return
	_end_actor_turn()

func _on_enemy_timer_timeout(actor: MonsterInstance, skill_id: String, target_uid: String) -> void:
	if result_sent or not actor.is_alive():
		return
	_perform_skill(actor, skill_id, target_uid)

func _choose_enemy_skill(actor: MonsterInstance) -> String:
	var available: Array[String] = []
	for skill_id in actor.skills:
		if int(temp_state[actor.uid]["cooldowns"].get(skill_id, 0)) <= 0:
			available.append(skill_id)
	if available.is_empty():
		return ""
	var best_skill_id := available[0]
	var best_score := _score_enemy_skill(actor, best_skill_id)
	for skill_id in available:
		var score := _score_enemy_skill(actor, skill_id)
		if score > best_score:
			best_score = score
			best_skill_id = skill_id
	var chosen_skill := GameData.get_skill(best_skill_id)
	if String(chosen_skill.get("effect", "")) == "heal":
		var wounded_allies := _team_lowest_health(_get_team_for(actor))
		if not wounded_allies.is_empty():
			selected_ally_uid = wounded_allies[0].uid
	return best_skill_id

func _score_enemy_skill(actor: MonsterInstance, skill_id: String) -> float:
	var skill := GameData.get_skill(skill_id)
	var effect := String(skill.get("effect", ""))
	var target_mode := String(skill.get("target", "enemy"))
	var score := float(int(skill.get("power", 0)) + int(skill.get("effect_value", 0)))
	if effect == "heal":
		var wounded_allies := _team_lowest_health(_get_team_for(actor))
		if wounded_allies.is_empty():
			return -1.0
		var target: MonsterInstance = wounded_allies[0]
		var missing_ratio := 1.0 - (float(target.current_hp) / max(1.0, float(target.max_hp)))
		score += 14.0 * missing_ratio
		if target.current_hp < target.max_hp / 2:
			score += 8.0
		return score
	if effect == "guard":
		var hp_ratio := float(actor.current_hp) / max(1.0, float(actor.max_hp))
		if hp_ratio < 0.45:
			score += 11.0
		if float(temp_state[actor.uid].get("guard", 0.0)) > 0.0:
			score -= 6.0
		return score
	if effect == "haste":
		if temp_state[actor.uid]["statuses"].has("haste"):
			score -= 6.0
		else:
			score += 3.0
	if target_mode == "enemy_all":
		score += float(_get_opponents(actor).size()) * 4.0
	var best_multiplier := 1.0
	for foe in _get_opponents(actor):
		if not foe.is_alive():
			continue
		best_multiplier = max(best_multiplier, GameData.type_multiplier(String(skill.get("type", actor.type)), foe.type))
		if effect in ["slow", "weaken", "vulnerable"] and not temp_state[foe.uid]["statuses"].has(effect):
			score += 1.5
	score += (best_multiplier - 1.0) * 10.0
	return score

func _on_skill_pressed(actor_uid: String, skill_id: String) -> void:
	var actor := _get_unit_by_uid(actor_uid)
	if actor == null or actor.uid != active_actor_uid or action_locked:
		return
	_queue_player_skill(actor, skill_id)

func _queue_player_skill(actor: MonsterInstance, skill_id: String) -> void:
	var skill: Dictionary = GameData.get_skill(skill_id)
	if not _has_valid_target(skill):
		return
	var target_mode := String(skill.get("target", "enemy"))
	var initial_target := _resolve_target(actor, skill)
	var target_uid := actor.uid if target_mode == "self" else (initial_target.uid if initial_target != null else "")
	pending_action = {
		"actor_uid": actor.uid,
		"skill_id": skill_id,
		"target_uid": target_uid,
	}
	_set_action_preview(actor.uid, skill_id, target_uid)
	_render_rosters()
	_update_selection_summary(actor, initial_target, _skill_name(skill_id, skill))
	if _requires_manual_target(target_mode):
		_prompt_player_action_with_feedback(actor, false)
		return
	await _commit_pending_action(actor, target_uid)

func _commit_pending_action(actor: MonsterInstance, chosen_target_uid: String = "") -> void:
	if pending_action.is_empty() or action_locked or actor == null or actor.uid != String(pending_action.get("actor_uid", "")):
		return
	var skill_id := String(pending_action.get("skill_id", ""))
	var skill: Dictionary = GameData.get_skill(skill_id)
	var target_mode := String(skill.get("target", "enemy"))
	var forced_target_uid := chosen_target_uid if not chosen_target_uid.is_empty() else String(pending_action.get("target_uid", ""))
	var target := _resolve_target(actor, skill, forced_target_uid)
	if target == null and target_mode != "enemy_all":
		return
	if target != null:
		forced_target_uid = target.uid
	pending_action["target_uid"] = forced_target_uid
	_set_action_preview(actor.uid, skill_id, forced_target_uid)
	action_locked = true
	_clear_action_buttons()
	_update_selection_summary(actor, target, _skill_name(skill_id, skill))
	if target != null and _selection_label != null:
		_selection_label.text = _tr("battle.prompt.action_locked", {
			"actor": actor.display_name,
			"target": target.display_name,
			"skill": _skill_name(skill_id, skill),
		})
	if not GameState.should_skip_animations():
		await get_tree().create_timer(PLAYER_COMMIT_DELAY).timeout
	if result_sent or actor.uid != active_actor_uid or not actor.is_alive():
		pending_action.clear()
		return
	pending_action.clear()
	_perform_skill(actor, skill_id, forced_target_uid)

func _cancel_pending_action(actor_uid: String) -> void:
	var actor := _get_unit_by_uid(actor_uid)
	if actor == null or actor.uid != active_actor_uid or action_locked:
		return
	pending_action.clear()
	_set_action_preview(actor.uid)
	_render_rosters()
	_prompt_player_action_with_feedback(actor, false)

func _perform_skill(actor: MonsterInstance, skill_id: String, forced_target_uid: String = "") -> void:
	var skill: Dictionary = GameData.get_skill(skill_id)
	var skill_name := _skill_name(skill_id, skill)
	recent_actor_uid = actor.uid
	_set_action_preview(actor.uid, skill_id, forced_target_uid)
	_render_rosters()
	_show_battle_banner(actor.display_name, skill_name, _skill_fx_color(skill))
	temp_state[actor.uid]["cooldowns"][skill_id] = int(skill.get("cooldown", 0))
	var target_mode := String(skill.get("target", "enemy"))
	if not GameState.should_skip_animations():
		await get_tree().create_timer(0.10).timeout
	if target_mode == "enemy_all":
		for foe in _get_opponents(actor):
			if foe.is_alive():
				var aoe_damage := _calculate_damage(actor, foe, skill)
				_apply_damage(actor, foe, aoe_damage, String(skill.get("type", actor.type)), skill_name)
				_apply_status_if_needed(foe, skill)
		_log(_tr("battle.log.enemy_all", {"actor": actor.display_name, "skill": skill_name}))
		_end_actor_turn()
		return
	else:
		var target := _resolve_target(actor, skill, forced_target_uid)
		if target == null:
			_log(_tr("battle.log.no_target", {"actor": actor.display_name, "skill": skill_name}))
			_end_actor_turn()
			return
		_apply_target_focus(actor, target)
		match String(skill.get("effect", "")):
			"heal":
				var heal_value := int(skill.get("effect_value", 0)) + actor.get_role_bonus("lab")
				if _is_ally(actor):
					heal_value += int(battle_config.get("ally_heal_bonus", 0))
				target.heal(heal_value)
				_show_unit_feedback(target.uid, "+%d" % heal_value, Color(0.32, 0.98, 0.70, 1.0))
				_flash_feedback(Color(0.30, 0.94, 0.62, 0.12), 5.0)
				_show_battle_banner(target.display_name, "+%d" % heal_value, Color(0.32, 0.98, 0.70, 1.0))
				_render_rosters()
				_log(_tr("battle.log.heal", {
					"actor": actor.display_name,
					"target": target.display_name,
					"skill": skill_name,
					"value": heal_value,
				}))
			"guard":
				temp_state[target.uid]["guard"] = float(skill.get("effect_value", 0.5))
				_show_unit_feedback(target.uid, _status_label("guard"), Color(0.56, 0.78, 1.0, 1.0), 26.0, 0.70)
				_flash_feedback(Color(0.45, 0.70, 1.0, 0.10), 3.0)
				_render_rosters()
				_log(_tr("battle.log.guard", {"actor": actor.display_name, "skill": skill_name}))
			_:
				var damage := _calculate_damage(actor, target, skill)
				_apply_damage(actor, target, damage, String(skill.get("type", actor.type)), skill_name)
				_apply_status_if_needed(target, skill)
	_end_actor_turn()

func _on_capture_pressed(actor_uid: String) -> void:
	var actor := _get_unit_by_uid(actor_uid)
	if actor == null or actor.uid != active_actor_uid or action_locked:
		return
	pending_action.clear()
	var target := _get_unit_by_uid(selected_enemy_uid)
	if target == null or not target.is_alive():
		target = _alive_enemies()[0] if not _alive_enemies().is_empty() else null
	if target == null:
		return
	_set_action_preview(actor.uid, "", target.uid)
	action_locked = true
	_clear_action_buttons()
	_selection_label.text = _tr("battle.prompt.capture_locked", {
		"actor": actor.display_name,
		"target": target.display_name,
	})
	if not GameState.should_skip_animations():
		await get_tree().create_timer(PLAYER_COMMIT_DELAY).timeout
	if result_sent or actor.uid != active_actor_uid or not actor.is_alive() or not target.is_alive():
		return
	var chance := 0.2 + float(target.max_hp - target.current_hp) / float(target.max_hp) * 0.55
	if target.current_hp <= target.max_hp / 3:
		chance += 0.15
	if rng.randf() <= chance:
		target.current_hp = 0
		_flash_feedback(Color(1.0, 0.88, 0.30, 0.14), 6.0)
		_show_unit_feedback(target.uid, _tr("battle.capture"), Color(1.0, 0.88, 0.30, 1.0), 28.0, 0.74)
		_show_battle_banner(_tr("battle.capture_success_title"), target.display_name, Color(1.0, 0.88, 0.30, 1.0))
		_log(_tr("battle.log.capture_success", {"actor": actor.display_name, "target": target.display_name}))
		_finish_battle({
			"player_won": true,
			"captured_species": target.species_id,
			"battle_kind": battle_config.get("kind", "wild"),
		})
		return
	_log(_tr("battle.log.capture_fail", {"actor": actor.display_name, "target": target.display_name}))
	_flash_feedback(Color(1.0, 0.58, 0.42, 0.10), 4.0)
	_end_actor_turn()

func _calculate_damage(actor: MonsterInstance, target: MonsterInstance, skill: Dictionary) -> int:
	var attack_value := actor.attack
	var weaken: Dictionary = temp_state[actor.uid]["statuses"].get("weaken", {})
	if not weaken.is_empty():
		attack_value -= int(weaken.get("value", 0))
	if round_index == 1 and _is_ally(actor) and bool(battle_config.get("ally_first_round_attack_bonus", false)):
		attack_value += 2
	var power := int(skill.get("power", 0))
	if String(skill.get("effect", "")) == "damage_all":
		power += int(skill.get("effect_value", 0))
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
	recent_actor_uid = actor.uid
	recent_target_uid = target.uid
	var multiplier := GameData.type_multiplier(skill_type, target.type)
	var suffix := ""
	if multiplier > 1.0:
		suffix = _tr("battle.suffix.super")
	elif multiplier < 1.0:
		suffix = _tr("battle.suffix.resist")
	_show_unit_feedback(target.uid, "-%d" % damage, _damage_text_color(multiplier))
	if not suffix.is_empty():
		_show_unit_feedback(target.uid, suffix.strip_edges(), Color(1.0, 0.92, 0.62, 1.0) if multiplier > 1.0 else Color(0.86, 0.74, 1.0, 1.0), 48.0, 0.68, 0.08)
	_log(_tr("battle.log.damage", {
		"actor": actor.display_name,
		"target": target.display_name,
		"skill": skill_name,
		"value": damage,
		"hp": target.current_hp,
		"max_hp": target.max_hp,
		"suffix": suffix,
	}))
	_flash_feedback(_damage_fx_color(multiplier), 7.0 if multiplier > 1.0 else 5.0)
	_show_battle_banner(target.display_name, "-%d" % damage, _damage_text_color(multiplier))
	_render_rosters()

func _apply_status_if_needed(target: MonsterInstance, skill: Dictionary) -> void:
	var effect := String(skill.get("effect", ""))
	if effect in ["slow", "weaken", "vulnerable", "haste"]:
		var recipient := target
		if String(skill.get("effect_target", "target")) == "self":
			recipient = _get_unit_by_uid(active_actor_uid)
		var status_payload := {
			"turns": int(skill.get("effect_turns", 1)),
			"value": int(skill.get("effect_value", 3)),
		}
		if effect == "haste":
			status_payload["rounds_before_decay"] = 1
		temp_state[recipient.uid]["statuses"][effect] = status_payload
		recent_target_uid = recipient.uid
		_show_unit_feedback(recipient.uid, _status_label(effect), Color(0.86, 0.70, 1.0, 1.0), 26.0, 0.74)
		_flash_feedback(Color(0.76, 0.52, 1.0, 0.10), 3.0)
		_show_battle_banner(recipient.display_name, _status_label(effect), Color(0.86, 0.70, 1.0, 1.0))
		_render_rosters()
		_log(_tr("battle.log.status", {"target": recipient.display_name, "status": _status_label(effect)}))

func _resolve_target(actor: MonsterInstance, skill: Dictionary, forced_target_uid: String = "") -> MonsterInstance:
	if not forced_target_uid.is_empty():
		var forced_target := _get_unit_by_uid(forced_target_uid)
		if _target_matches_mode(actor, forced_target, String(skill.get("target", "enemy"))):
			return forced_target
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
		if not acted_actor_uids.has(actor.uid):
			acted_actor_uids.append(actor.uid)
		pending_action.clear()
		_clear_action_preview()
		_render_rosters()
		_render_turn_order_bar()
	if _try_finish_battle():
		return
	active_actor_uid = ""
	action_locked = false
	_update_selection_summary()
	if not GameState.should_skip_animations():
		await get_tree().create_timer(TURN_ADVANCE_DELAY).timeout
	_advance_turn()

func _end_round() -> void:
	for uid in temp_state.keys():
		for skill_id in temp_state[uid]["cooldowns"].keys():
			var left := int(temp_state[uid]["cooldowns"][skill_id])
			if left > 0:
				temp_state[uid]["cooldowns"][skill_id] = left - 1
		var statuses: Dictionary = temp_state[uid]["statuses"]
		for status_id in statuses.keys().duplicate():
			var rounds_before_decay := int(statuses[status_id].get("rounds_before_decay", 0))
			if rounds_before_decay > 0:
				statuses[status_id]["rounds_before_decay"] = rounds_before_decay - 1
				continue
			statuses[status_id]["turns"] = int(statuses[status_id].get("turns", 0)) - 1
			if int(statuses[status_id]["turns"]) <= 0:
				statuses.erase(status_id)
	var round_limit := int(battle_config.get("round_limit", GameData.MAX_ROUNDS))
	if round_index >= round_limit:
		_log(_tr("battle.log.round_limit", {"value": round_limit}))
		_finish_battle(_resolve_timeout_result())
		return
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
	var won := bool(result.get("player_won", false))
	var end_color := Color(0.96, 0.84, 0.34, 1.0) if won else Color(1.0, 0.48, 0.42, 1.0)
	_clear_action_buttons()
	active_actor_uid = ""
	pending_action.clear()
	_clear_action_preview()
	round_order_uids.clear()
	acted_actor_uids.clear()
	action_locked = false
	_flash_feedback(Color(end_color.r, end_color.g, end_color.b, 0.12), 5.0 if won else 7.0)
	_update_selection_summary()
	_render_turn_order_bar()
	_render_rosters()
	_show_battle_banner(_tr("battle.end"), _tr("battle.end.win") if won else _tr("battle.end.lose"), end_color)
	if GameState.should_skip_animations():
		hide()
		battle_finished.emit(result)
		return
	if _finish_tween != null:
		_finish_tween.kill()
	_finish_tween = create_tween()
	_finish_tween.tween_interval(0.42)
	_finish_tween.finished.connect(func() -> void:
		hide()
		position = _base_position
		battle_finished.emit(result)
		_finish_tween = null
	)

func _render_rosters() -> void:
	_unit_card_nodes.clear()
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
	button.custom_minimum_size = Vector2(250, 108)
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.disabled = not unit.is_alive() or (_pending_target_selection_active() and not _is_unit_valid_pending_target(unit))
	button.clip_contents = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_state := _describe_unit_card(unit, is_ally)
	_apply_unit_button_style(button, card_state)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_left = 12.0
	margin.offset_top = 10.0
	margin.offset_right = -12.0
	margin.offset_bottom = -10.0
	button.add_child(margin)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.theme_override_constants.separation = 6
	margin.add_child(root)
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_row)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = "%s  %s" % [unit.display_name, _type_name(unit.type)]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = card_state["text_color"]
	top_row.add_child(name_label)
	var badge_label := Label.new()
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.text = String(card_state["badge_text"])
	badge_label.visible = not badge_label.text.is_empty()
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.modulate = card_state["badge_color"]
	top_row.add_child(badge_label)
	var hp_bar := ProgressBar.new()
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.min_value = 0
	hp_bar.max_value = maxi(1, unit.max_hp)
	hp_bar.value = unit.current_hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 18)
	_apply_progressbar_style(hp_bar, card_state)
	root.add_child(hp_bar)
	var stat_row := HBoxContainer.new()
	stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_row.theme_override_constants.separation = 12
	root.add_child(stat_row)
	for stat_text in [
		"%s %d/%d" % [_tr("battle.stat.hp"), unit.current_hp, unit.max_hp],
		"%s %d" % [_tr("battle.stat.attack"), unit.attack],
		"%s %d" % [_tr("battle.stat.speed"), _get_effective_speed(unit)],
	]:
		var stat_label := Label.new()
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_label.text = stat_text
		stat_label.add_theme_font_size_override("font_size", 13)
		stat_label.modulate = card_state["subtle_color"]
		stat_row.add_child(stat_label)
	var status_label := Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = _status_text(unit.uid)
	status_label.visible = not status_label.text.is_empty()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.modulate = card_state["badge_color"]
	root.add_child(status_label)
	if is_ally:
		button.pressed.connect(_on_ally_selected.bind(unit.uid))
	else:
		button.pressed.connect(_on_enemy_selected.bind(unit.uid))
	_unit_card_nodes[unit.uid] = button
	return button

func _status_text(uid: String) -> String:
	var statuses: Dictionary = temp_state.get(uid, {}).get("statuses", {})
	var parts: Array[String] = []
	for status_id in statuses.keys():
		parts.append("%s(%d)" % [_status_label(String(status_id)), int(statuses[status_id].get("turns", 0))])
	if float(temp_state.get(uid, {}).get("guard", 0.0)) > 0.0:
		parts.append(_status_label("guard"))
	if parts.is_empty():
		return ""
	return " · ".join(parts)

func _on_enemy_selected(uid: String) -> void:
	var actor := _get_unit_by_uid(active_actor_uid)
	if actor != null and _is_ally(actor) and not pending_action.is_empty():
		var skill := GameData.get_skill(String(pending_action.get("skill_id", "")))
		if _target_matches_mode(actor, _get_unit_by_uid(uid), String(skill.get("target", "enemy"))):
			selected_enemy_uid = uid
			await _commit_pending_action(actor, uid)
			return
	selected_enemy_uid = uid
	if _pending_target_selection_active():
		_set_action_preview(preview_actor_uid, preview_skill_id, uid)
	_render_rosters()
	if actor != null and _is_ally(actor):
		_prompt_player_action_with_feedback(actor, false)
	else:
		_update_selection_summary()

func _on_ally_selected(uid: String) -> void:
	var actor := _get_unit_by_uid(active_actor_uid)
	if actor != null and _is_ally(actor) and not pending_action.is_empty():
		var skill := GameData.get_skill(String(pending_action.get("skill_id", "")))
		if _target_matches_mode(actor, _get_unit_by_uid(uid), String(skill.get("target", "enemy"))):
			selected_ally_uid = uid
			await _commit_pending_action(actor, uid)
			return
	selected_ally_uid = uid
	if _pending_target_selection_active():
		_set_action_preview(preview_actor_uid, preview_skill_id, uid)
	_render_rosters()
	if actor != null and _is_ally(actor):
		_prompt_player_action_with_feedback(actor, false)
	else:
		_update_selection_summary()

func _skill_detail_text(skill_id: String, skill: Dictionary) -> String:
	var power := int(skill.get("power", 0))
	var details: Array[String] = []
	if power > 0:
		details.append(_tr("battle.skill.power", {"value": power}))
	var target_mode := String(skill.get("target", "enemy"))
	if not target_mode.is_empty():
		details.append(_tr("battle.skill.target", {"value": localization_service.target_name(target_mode)}))
	var effect_id := String(skill.get("effect", ""))
	if not effect_id.is_empty():
		details.append(_tr("battle.skill.effect", {"value": localization_service.effect_name(effect_id)}))
	if details.is_empty():
		var fallback := String(skill.get("text", ""))
		return fallback if not fallback.is_empty() else _skill_name(skill_id, skill)
	return " / ".join(details)

func _requires_manual_target(target_mode: String) -> bool:
	return target_mode in ["enemy", "ally"]

func _pending_target_selection_active() -> bool:
	if pending_action.is_empty():
		return false
	var skill := GameData.get_skill(String(pending_action.get("skill_id", "")))
	return _requires_manual_target(String(skill.get("target", "enemy"))) and not action_locked

func _is_unit_valid_pending_target(unit: MonsterInstance) -> bool:
	if not _pending_target_selection_active():
		return true
	if unit == null or not unit.is_alive():
		return false
	var actor := _get_unit_by_uid(String(pending_action.get("actor_uid", "")))
	var skill := GameData.get_skill(String(pending_action.get("skill_id", "")))
	return _target_matches_mode(actor, unit, String(skill.get("target", "enemy")))

func _set_action_preview(actor_uid: String = "", skill_id: String = "", target_uid: String = "") -> void:
	preview_actor_uid = actor_uid
	preview_skill_id = skill_id
	preview_target_uid = target_uid
	preview_target_mode = ""
	if not skill_id.is_empty():
		preview_target_mode = String(GameData.get_skill(skill_id).get("target", "enemy"))
	_update_action_preview()

func _clear_action_preview() -> void:
	preview_actor_uid = ""
	preview_skill_id = ""
	preview_target_uid = ""
	preview_target_mode = ""
	_update_action_preview()

func _render_turn_order_bar() -> void:
	if turn_order_bar == null:
		return
	for child in turn_order_bar.get_children():
		child.queue_free()
	for uid in round_order_uids:
		var unit := _get_unit_by_uid(uid)
		if unit == null:
			continue
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(0, 50)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_stylebox_override("panel", _turn_order_style(uid))
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 6)
		chip.add_child(margin)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.theme_override_constants.separation = 1
		margin.add_child(column)
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = unit.display_name
		name_label.add_theme_font_size_override("font_size", 14)
		column.add_child(name_label)
		var state_label := Label.new()
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_label.text = _turn_order_state_text(uid)
		state_label.add_theme_font_size_override("font_size", 11)
		state_label.modulate = Color(0.82, 0.89, 1.0, 0.82)
		column.add_child(state_label)
		turn_order_bar.add_child(chip)

func _turn_order_state_text(uid: String) -> String:
	if uid == active_actor_uid:
		return _tr("battle.turn_order.now")
	if not turn_queue.is_empty() and uid == turn_queue[0].uid:
		return _tr("battle.turn_order.next")
	if acted_actor_uids.has(uid):
		return _tr("battle.turn_order.done")
	return _tr("battle.turn_order.ready")

func _turn_order_style(uid: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	if uid == active_actor_uid:
		style.bg_color = Color(0.42, 0.28, 0.12, 0.94)
		style.border_color = Color(0.98, 0.84, 0.40, 1.0)
	elif not turn_queue.is_empty() and uid == turn_queue[0].uid:
		style.bg_color = Color(0.14, 0.24, 0.36, 0.94)
		style.border_color = Color(0.48, 0.84, 1.0, 1.0)
	elif acted_actor_uids.has(uid):
		style.bg_color = Color(0.14, 0.16, 0.22, 0.64)
		style.border_color = Color(0.36, 0.41, 0.52, 0.72)
	else:
		style.bg_color = Color(0.12, 0.16, 0.24, 0.88)
		style.border_color = Color(0.40, 0.50, 0.64, 0.88)
	return style

func _describe_unit_card(unit: MonsterInstance, is_ally: bool) -> Dictionary:
	var badge_text := ""
	var badge_color := Color(0.88, 0.92, 0.98, 0.92)
	var border_color := Color(0.42, 0.58, 0.78, 0.60) if is_ally else Color(0.78, 0.42, 0.40, 0.60)
	var bg_color := Color(0.10, 0.16, 0.24, 0.96) if is_ally else Color(0.24, 0.12, 0.14, 0.96)
	var subtle_color := Color(0.78, 0.84, 0.94, 0.86)
	var text_color := Color(0.97, 0.98, 1.0, 1.0)
	var fill_color := Color(0.36, 0.82, 1.0, 1.0) if is_ally else Color(0.98, 0.52, 0.46, 1.0)
	var modulate_color := Color(1.0, 1.0, 1.0, 1.0)
	if not unit.is_alive():
		badge_text = _tr("battle.card.ko")
		badge_color = Color(0.76, 0.80, 0.88, 0.70)
		border_color = Color(0.36, 0.40, 0.48, 0.54)
		bg_color = Color(0.12, 0.14, 0.18, 0.84)
		fill_color = Color(0.46, 0.50, 0.58, 0.72)
		modulate_color = Color(1.0, 1.0, 1.0, 0.66)
	elif unit.uid == active_actor_uid:
		badge_text = _tr("battle.card.acting")
		badge_color = Color(1.0, 0.88, 0.52, 1.0)
		border_color = Color(0.98, 0.84, 0.40, 1.0)
		bg_color = Color(0.22, 0.17, 0.08, 0.98)
	elif _unit_is_preview_target(unit):
		badge_text = _tr("battle.card.targeted")
		badge_color = Color(1.0, 0.74, 0.58, 1.0)
		border_color = Color(1.0, 0.54, 0.44, 1.0)
		bg_color = Color(0.28, 0.12, 0.14, 0.98) if not is_ally else Color(0.16, 0.24, 0.30, 0.98)
	elif unit.uid == recent_target_uid:
		badge_text = _tr("battle.card.hit")
		badge_color = Color(1.0, 0.88, 0.54, 1.0)
		border_color = Color(0.98, 0.76, 0.34, 0.96)
	elif unit.uid == selected_enemy_uid or unit.uid == selected_ally_uid:
		badge_text = _tr("battle.card.selected")
		badge_color = Color(0.70, 0.90, 1.0, 1.0)
		border_color = Color(0.54, 0.80, 1.0, 0.94)
	elif _pending_target_selection_active() and _is_unit_valid_pending_target(unit):
		badge_text = _tr("battle.card.confirm")
		badge_color = Color(0.70, 0.95, 0.76, 1.0)
		border_color = Color(0.54, 0.92, 0.72, 0.92)
	return {
		"badge_text": badge_text,
		"badge_color": badge_color,
		"border_color": border_color,
		"bg_color": bg_color,
		"subtle_color": subtle_color,
		"text_color": text_color,
		"fill_color": fill_color,
		"modulate_color": modulate_color,
	}

func _unit_is_preview_target(unit: MonsterInstance) -> bool:
	if unit == null or preview_actor_uid.is_empty() or preview_skill_id.is_empty() or not unit.is_alive():
		return false
	var actor := _get_unit_by_uid(preview_actor_uid)
	if actor == null:
		return false
	match preview_target_mode:
		"self":
			return unit.uid == actor.uid
		"enemy_all":
			return _get_team_for(unit) != _get_team_for(actor)
		"ally":
			return unit.uid == preview_target_uid
		_:
			return unit.uid == preview_target_uid

func _apply_unit_button_style(button: Button, card_state: Dictionary) -> void:
	button.modulate = card_state["modulate_color"]
	var normal := StyleBoxFlat.new()
	normal.bg_color = card_state["bg_color"]
	normal.border_color = card_state["border_color"]
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_right = 14
	normal.corner_radius_bottom_left = 14
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(normal.bg_color.r + 0.03, normal.bg_color.g + 0.03, normal.bg_color.b + 0.03, normal.bg_color.a)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(normal.bg_color.r * 0.92, normal.bg_color.g * 0.92, normal.bg_color.b * 0.92, normal.bg_color.a)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.14, 0.16, 0.20, 0.64)
	disabled.border_color = Color(0.34, 0.38, 0.44, 0.60)
	button.add_theme_stylebox_override("disabled", disabled)

func _apply_progressbar_style(bar: ProgressBar, card_state: Dictionary) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_right = 8
	background.corner_radius_bottom_left = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = card_state["fill_color"]
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_right = 8
	fill.corner_radius_bottom_left = 8
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _show_unit_feedback(unit_uid: String, text: String, color: Color, rise: float = 34.0, duration: float = 0.62, delay: float = 0.0) -> void:
	if GameState.should_skip_animations() or _fx_layer == null or text.is_empty():
		return
	var target_node: Control = _unit_card_nodes.get(unit_uid, null)
	if target_node == null or not is_instance_valid(target_node):
		return
	var panel_rect := get_global_rect()
	var card_rect := target_node.get_global_rect()
	var float_label := Label.new()
	float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_label.text = text
	float_label.position = card_rect.position + card_rect.size * Vector2(0.5, 0.28) - panel_rect.position
	float_label.pivot_offset = Vector2(0, 0)
	float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_label.add_theme_font_size_override("font_size", 24)
	float_label.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.10, 0.95))
	float_label.add_theme_constant_override("outline_size", 8)
	float_label.modulate = color
	_fx_layer.add_child(float_label)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(float_label, "position:y", float_label.position.y - rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(float_label):
			float_label.queue_free()
	)

func _clear_action_buttons() -> void:
	for child in action_box.get_children():
		child.queue_free()

func _log(message: String) -> void:
	var history_lines := _battle_log_lines.duplicate()
	_battle_log_lines.append(message)
	var full_text := "\n".join(_battle_log_lines)
	if GameState.should_skip_animations() or history_lines.is_empty():
		_render_battle_log_text(full_text)
		return
	var history_text := "\n".join(history_lines)
	var visible_count := history_text.length()
	if not history_text.is_empty():
		visible_count += 1
	_stop_battle_log_typewriter(false)
	battle_log.text = full_text
	battle_log.visible_characters = visible_count
	battle_log.scroll_to_line(battle_log.get_line_count())
	var duration := clampf(float(message.length()) * BATTLE_LOG_TYPEWRITER_SPEED, BATTLE_LOG_TYPEWRITER_MIN_DURATION, BATTLE_LOG_TYPEWRITER_MAX_DURATION)
	_battle_log_tween = create_tween()
	_battle_log_tween.set_trans(Tween.TRANS_LINEAR)
	_battle_log_tween.set_ease(Tween.EASE_OUT)
	_battle_log_tween.tween_property(battle_log, "visible_characters", full_text.length(), duration)
	_battle_log_tween.finished.connect(_on_battle_log_typewriter_finished)

func _ensure_fx_layer() -> void:
	if _fx_layer != null:
		return
	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.anchors_preset = Control.PRESET_FULL_RECT
	_fx_layer.anchor_right = 1.0
	_fx_layer.anchor_bottom = 1.0
	add_child(_fx_layer)
	_fx_flash = ColorRect.new()
	_fx_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_flash.color = Color(1, 1, 1, 0)
	_fx_flash.anchors_preset = Control.PRESET_FULL_RECT
	_fx_flash.anchor_right = 1.0
	_fx_flash.anchor_bottom = 1.0
	_fx_layer.add_child(_fx_flash)
	_fx_banner = Label.new()
	_fx_banner.visible = false
	_fx_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fx_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fx_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fx_banner.add_theme_font_size_override("font_size", 28)
	_fx_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.15, 0.95))
	_fx_banner.add_theme_constant_override("outline_size", 8)
	_fx_banner.anchors_preset = Control.PRESET_TOP_WIDE
	_fx_banner.anchor_left = 0.18
	_fx_banner.anchor_right = 0.82
	_fx_banner.offset_top = 18.0
	_fx_banner.offset_bottom = 92.0
	_fx_layer.add_child(_fx_banner)

func _play_open_animation() -> void:
	if GameState.should_skip_animations():
		modulate.a = 1.0
		scale = Vector2.ONE
		position = _base_position
		return
	if _fx_panel_tween != null:
		_fx_panel_tween.kill()
	if _fx_shake_tween != null:
		_fx_shake_tween.kill()
		_fx_shake_tween = null
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	position = _base_position + Vector2(0, 12)
	_fx_panel_tween = create_tween()
	_fx_panel_tween.set_parallel(true)
	_fx_panel_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_fx_panel_tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx_panel_tween.tween_property(self, "position", _base_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_battle_banner(title: String, subtitle: String, color: Color) -> void:
	if GameState.should_skip_animations() or _fx_banner == null:
		return
	if _fx_banner_tween != null:
		_fx_banner_tween.kill()
	_fx_banner.text = "%s\n%s" % [title, subtitle]
	_fx_banner.modulate = color
	_fx_banner.visible = true
	_fx_banner.scale = Vector2(0.9, 0.9)
	_fx_banner.position = Vector2(0, -10)
	_fx_banner_tween = create_tween()
	_fx_banner_tween.set_parallel(true)
	_fx_banner_tween.tween_property(_fx_banner, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx_banner_tween.tween_property(_fx_banner, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fx_banner_tween.chain().tween_interval(0.28)
	_fx_banner_tween.chain().tween_property(_fx_banner, "modulate:a", 0.0, 0.18)
	_fx_banner_tween.finished.connect(func() -> void:
		_fx_banner.visible = false
		_fx_banner.modulate.a = 1.0
	)

func _flash_feedback(color: Color, shake_strength: float) -> void:
	if GameState.should_skip_animations() or _fx_flash == null:
		return
	if _fx_flash_tween != null:
		_fx_flash_tween.kill()
	_fx_flash.color = Color(color.r, color.g, color.b, 0.0)
	_fx_flash_tween = create_tween()
	_fx_flash_tween.tween_property(_fx_flash, "color:a", color.a, 0.04)
	_fx_flash_tween.chain().tween_property(_fx_flash, "color:a", 0.0, 0.16)
	_fx_flash_tween.finished.connect(func() -> void:
		_fx_flash_tween = null
	)
	_play_panel_shake(shake_strength)

func _play_panel_shake(strength: float) -> void:
	if GameState.should_skip_animations() or strength <= 0.0:
		return
	if _fx_shake_tween != null:
		_fx_shake_tween.kill()
	position = _base_position
	_fx_shake_tween = create_tween()
	_fx_shake_tween.tween_property(self, "position", _base_position + Vector2(strength, 0), 0.04)
	_fx_shake_tween.tween_property(self, "position", _base_position + Vector2(-strength * 0.8, 0), 0.05)
	_fx_shake_tween.tween_property(self, "position", _base_position + Vector2(strength * 0.45, 0), 0.05)
	_fx_shake_tween.tween_property(self, "position", _base_position, 0.05)

func _pulse_turn_label(actor_name: String) -> void:
	turn_label.text = _tr("battle.round_actor", {"round": round_index, "actor": actor_name})
	if GameState.should_skip_animations():
		return
	if _turn_label_tween != null:
		_turn_label_tween.kill()
	turn_label.scale = Vector2.ONE
	_turn_label_tween = create_tween()
	_turn_label_tween.tween_property(turn_label, "scale", Vector2(1.04, 1.04), 0.08)
	_turn_label_tween.tween_property(turn_label, "scale", Vector2.ONE, 0.12)
	_turn_label_tween.finished.connect(func() -> void:
		_turn_label_tween = null
	)

func _skill_fx_color(skill: Dictionary) -> Color:
	match String(skill.get("effect", "")):
		"heal":
			return Color(0.32, 0.98, 0.70, 1.0)
		"guard":
			return Color(0.50, 0.74, 1.0, 1.0)
		_:
			return Color(1.0, 0.76, 0.36, 1.0)

func _damage_fx_color(multiplier: float) -> Color:
	if multiplier > 1.0:
		return Color(1.0, 0.42, 0.34, 0.16)
	if multiplier < 1.0:
		return Color(0.84, 0.66, 1.0, 0.11)
	return Color(1.0, 0.60, 0.46, 0.12)

func _damage_text_color(multiplier: float) -> Color:
	if multiplier > 1.0:
		return Color(1.0, 0.48, 0.36, 1.0)
	if multiplier < 1.0:
		return Color(0.86, 0.74, 1.0, 1.0)
	return Color(1.0, 0.82, 0.52, 1.0)

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

func _apply_prebattle_modifiers() -> void:
	for ally in allies:
		ally.max_hp += int(battle_config.get("ally_hp_bonus", 0))
		ally.current_hp = ally.max_hp
		ally.attack += int(battle_config.get("ally_attack_bonus", 0))
		ally.speed += int(battle_config.get("ally_speed_bonus", 0))
	for enemy in enemies:
		enemy.attack = maxi(1, enemy.attack - int(battle_config.get("enemy_attack_penalty", 0)))

func _build_bonus_log_lines() -> Array[String]:
	var lines: Array[String] = []
	if int(battle_config.get("ally_attack_bonus", 0)) > 0:
		lines.append(_tr("battle.log.bonus.attack", {"value": int(battle_config.get("ally_attack_bonus", 0))}))
	if int(battle_config.get("ally_speed_bonus", 0)) > 0:
		lines.append(_tr("battle.log.bonus.speed", {"value": int(battle_config.get("ally_speed_bonus", 0))}))
	if int(battle_config.get("ally_hp_bonus", 0)) > 0:
		lines.append(_tr("battle.log.bonus.hp", {"value": int(battle_config.get("ally_hp_bonus", 0))}))
	if int(battle_config.get("ally_heal_bonus", 0)) > 0:
		lines.append(_tr("battle.log.bonus.heal", {"value": int(battle_config.get("ally_heal_bonus", 0))}))
	if float(battle_config.get("ally_guard_bonus", 0.0)) > 0.0:
		lines.append(_tr("battle.log.bonus.guard", {"value": int(round(float(battle_config.get("ally_guard_bonus", 0.0)) * 100.0))}))
	if int(battle_config.get("enemy_attack_penalty", 0)) > 0:
		lines.append(_tr("battle.log.bonus.enemy_penalty", {"value": int(battle_config.get("enemy_attack_penalty", 0))}))
	return lines

func _ensure_selection_label() -> void:
	if _selection_label != null:
		return
	var container := turn_label.get_parent()
	if container == null:
		return
	_selection_label = Label.new()
	_selection_label.name = "SelectionLabel"
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.add_theme_font_size_override("font_size", 14)
	_selection_label.modulate = Color(0.86, 0.91, 1.0, 0.95)
	container.add_child(_selection_label)
	container.move_child(_selection_label, turn_label.get_index() + 1)

func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact_width := size.x < 860.0
	var short_height := size.y < 620.0
	title_label.add_theme_font_size_override("font_size", 22 if short_height else 26)
	turn_label.add_theme_font_size_override("font_size", 16 if short_height else 18)
	action_preview_label.add_theme_font_size_override("font_size", 16 if compact_width or short_height else 18)
	action_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_preview_detail_label.add_theme_font_size_override("font_size", 13 if compact_width or short_height else 14)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_order_bar.vertical = size.x < 720.0
	turn_order_bar.add_theme_constant_override("separation", 6 if compact_width else 8)
	teams_row.add_theme_constant_override("separation", 8 if compact_width else 12)
	action_preview_panel.custom_minimum_size = Vector2(0, 56 if short_height else 72)
	battle_log.custom_minimum_size = Vector2(0, 120 if short_height else (150 if compact_width else 190))
	action_box.add_theme_constant_override("separation", 4 if compact_width else 6)

func _action_button_height() -> float:
	return 40.0 if size.y < 620.0 else 48.0

func _secondary_action_button_height() -> float:
	return 36.0 if size.y < 620.0 else 40.0

func _update_selection_summary(actor: MonsterInstance = null, target: MonsterInstance = null, skill_name: String = "") -> void:
	_update_action_preview(actor, target, skill_name)
	if _selection_label == null:
		return
	if actor == null:
		_selection_label.text = ""
		return
	if not pending_action.is_empty() and actor.uid == String(pending_action.get("actor_uid", "")):
		var pending_skill_id := String(pending_action.get("skill_id", ""))
		var pending_skill := GameData.get_skill(pending_skill_id)
		var pending_skill_name := _skill_name(pending_skill_id, pending_skill)
		var pending_target := _get_unit_by_uid(String(pending_action.get("target_uid", "")))
		if _pending_target_selection_active():
			var target_label := pending_target.display_name if pending_target != null else localization_service.target_name(String(pending_skill.get("target", "enemy")))
			_selection_label.text = _tr("battle.prompt.choose_target", {
				"actor": actor.display_name,
				"skill": pending_skill_name,
			}) + "\n" + _tr("battle.prompt.target", {"target": target_label})
			return
		if pending_target != null:
			_selection_label.text = _tr("battle.prompt.action_locked", {
				"actor": actor.display_name,
				"target": pending_target.display_name,
				"skill": pending_skill_name,
			})
			return
	if skill_name != "" and target != null and not _is_ally(actor):
		_selection_label.text = _tr("battle.prompt.enemy_intent", {
			"actor": actor.display_name,
			"target": target.display_name,
			"skill": skill_name,
		})
		return
	var enemy_target_name := _tr("battle.prompt.none")
	var ally_target_name := _tr("battle.prompt.none")
	var enemy_target := _get_unit_by_uid(selected_enemy_uid)
	if enemy_target != null and enemy_target.is_alive():
		enemy_target_name = enemy_target.display_name
	var ally_target := _get_unit_by_uid(selected_ally_uid)
	if ally_target != null and ally_target.is_alive():
		ally_target_name = ally_target.display_name
	_selection_label.text = "%s\n%s ｜ %s" % [
		_tr("battle.prompt.player", {"actor": actor.display_name}),
		_tr("battle.prompt.enemy_target", {"target": enemy_target_name}),
		_tr("battle.prompt.ally_target", {"target": ally_target_name}),
	]

func _update_action_preview(actor: MonsterInstance = null, target: MonsterInstance = null, skill_name: String = "") -> void:
	if action_preview_label == null or action_preview_detail_label == null:
		return
	var preview_actor := actor
	if preview_actor == null and not preview_actor_uid.is_empty():
		preview_actor = _get_unit_by_uid(preview_actor_uid)
	var preview_skill := {}
	var preview_skill_name := skill_name
	if not preview_skill_id.is_empty():
		preview_skill = GameData.get_skill(preview_skill_id)
	if preview_skill_name.is_empty() and not preview_skill.is_empty():
		preview_skill_name = _skill_name(preview_skill_id, preview_skill)
	var preview_target := target
	if preview_target == null and not preview_target_uid.is_empty():
		preview_target = _get_unit_by_uid(preview_target_uid)
	if preview_actor == null:
		action_preview_label.text = _tr("battle.preview.idle")
		action_preview_detail_label.text = _tr("battle.preview.idle_detail")
		return
	if preview_skill_name.is_empty():
		action_preview_label.text = _tr("battle.preview.await_actor", {"actor": preview_actor.display_name})
		action_preview_detail_label.text = _tr("battle.preview.await_detail")
		return
	var target_label := _preview_target_name(preview_actor, preview_skill, preview_target)
	action_preview_label.text = "%s  ->  %s  ->  %s" % [preview_actor.display_name, target_label, preview_skill_name]
	action_preview_detail_label.text = _build_preview_detail(preview_actor, preview_skill, preview_target)

func _preview_target_name(actor: MonsterInstance, skill: Dictionary, target: MonsterInstance) -> String:
	if actor == null:
		return _tr("battle.prompt.none")
	match String(skill.get("target", "enemy")):
		"self":
			return actor.display_name
		"enemy_all":
			return localization_service.target_name("enemy_all")
		"ally":
			return target.display_name if target != null else localization_service.target_name("ally")
		_:
			return target.display_name if target != null else localization_service.target_name("enemy")

func _build_preview_detail(actor: MonsterInstance, skill: Dictionary, target: MonsterInstance) -> String:
	if actor == null:
		return _tr("battle.preview.idle_detail")
	if skill.is_empty():
		return _tr("battle.preview.await_detail")
	var target_mode := String(skill.get("target", "enemy"))
	var details: Array[String] = [
		_tr("battle.skill.target", {"value": localization_service.target_name(target_mode)}),
	]
	match String(skill.get("effect", "")):
		"heal":
			details.append(_tr("battle.preview.estimate_heal", {"value": _estimate_heal_value(actor, skill)}))
		"guard":
			details.append(_tr("battle.preview.guard"))
		"slow", "weaken", "vulnerable", "haste":
			details.append(_tr("battle.preview.status_apply", {"status": _status_label(String(skill.get("effect", "")))}))
			if target != null:
				var damage_range := _estimate_damage_range(actor, target, skill)
				details.append(_tr("battle.preview.estimate_damage", {"min": damage_range["min"], "max": damage_range["max"]}))
		_:
			if target_mode == "enemy_all":
				details.append(_tr("battle.preview.enemy_all_damage", {"value": _estimate_enemy_all_damage(actor, skill)}))
			elif target != null:
				var damage_range := _estimate_damage_range(actor, target, skill)
				details.append(_tr("battle.preview.estimate_damage", {"min": damage_range["min"], "max": damage_range["max"]}))
	if _pending_target_selection_active():
		details.append(_tr("battle.preview.click_target"))
	return " · ".join(details)

func _estimate_heal_value(actor: MonsterInstance, skill: Dictionary) -> int:
	var heal_value := int(skill.get("effect_value", 0)) + actor.get_role_bonus("lab")
	if _is_ally(actor):
		heal_value += int(battle_config.get("ally_heal_bonus", 0))
	return heal_value

func _estimate_enemy_all_damage(actor: MonsterInstance, skill: Dictionary) -> int:
	return int(skill.get("effect_value", 0)) + int(round(actor.attack * 0.4))

func _estimate_damage_range(actor: MonsterInstance, target: MonsterInstance, skill: Dictionary) -> Dictionary:
	var attack_value := actor.attack
	var weaken: Dictionary = temp_state[actor.uid]["statuses"].get("weaken", {})
	if not weaken.is_empty():
		attack_value -= int(weaken.get("value", 0))
	if round_index == 1 and _is_ally(actor) and bool(battle_config.get("ally_first_round_attack_bonus", false)):
		attack_value += 2
	var power := int(skill.get("power", 0))
	if String(skill.get("effect", "")) == "damage_all":
		power += int(skill.get("effect_value", 0))
	var raw_damage := attack_value + power
	var multiplier := GameData.type_multiplier(String(skill.get("type", actor.type)), target.type)
	var vulnerable: Dictionary = temp_state[target.uid]["statuses"].get("vulnerable", {})
	if not vulnerable.is_empty():
		multiplier += 0.25
	var base_damage := int(round(raw_damage * 0.55 * multiplier))
	var guard_ratio := float(temp_state[target.uid].get("guard", 0.0))
	var min_damage := maxi(1, base_damage - 1)
	var max_damage := maxi(1, base_damage + 2)
	if guard_ratio > 0.0:
		min_damage = maxi(1, int(round(min_damage * (1.0 - guard_ratio))))
		max_damage = maxi(1, int(round(max_damage * (1.0 - guard_ratio))))
	return {
		"min": min_damage,
		"max": max_damage,
	}

func _choose_target_uid(actor: MonsterInstance, skill: Dictionary) -> String:
	match String(skill.get("target", "enemy")):
		"self":
			return actor.uid
		"ally":
			var allies_by_need := _team_lowest_health(_get_team_for(actor))
			return allies_by_need[0].uid if not allies_by_need.is_empty() else actor.uid
		"enemy_all":
			var foes := _get_opponents(actor)
			return foes[0].uid if not foes.is_empty() else ""
		_:
			var foes := _get_opponents(actor)
			if foes.is_empty():
				return ""
			foes.sort_custom(func(a: MonsterInstance, b: MonsterInstance) -> bool:
				if a.current_hp == b.current_hp:
					return a.attack > b.attack
				return a.current_hp < b.current_hp
			)
			return foes[0].uid

func _target_matches_mode(actor: MonsterInstance, target: MonsterInstance, target_mode: String) -> bool:
	if target == null or not target.is_alive():
		return false
	match target_mode:
		"self":
			return target.uid == actor.uid
		"ally":
			return _get_team_for(target) == _get_team_for(actor)
		"enemy_all":
			return _get_team_for(target) != _get_team_for(actor)
		_:
			return _get_team_for(target) != _get_team_for(actor)

func _apply_target_focus(actor: MonsterInstance, target: MonsterInstance) -> void:
	if target == null:
		return
	recent_actor_uid = actor.uid
	recent_target_uid = target.uid
	if _is_ally(target):
		selected_ally_uid = target.uid
	else:
		selected_enemy_uid = target.uid
	preview_target_uid = target.uid
	_render_rosters()
	if _is_ally(actor):
		_update_selection_summary(actor, target)

func _status_label(status_id: String) -> String:
	return localization_service.status_name(status_id)

func _type_name(type_id: String) -> String:
	return localization_service.type_name(type_id)

func _skill_name(skill_id: String, skill: Dictionary = {}) -> String:
	return localization_service.skill_name(skill_id, String(skill.get("name", skill_id)))

func _tr(key: String, params: Dictionary = {}) -> String:
	return localization_service.text(key, params)

func _reset_battle_log(lines: Array[String]) -> void:
	_battle_log_lines = []
	for line in lines:
		_battle_log_lines.append(String(line))
	_render_battle_log_text("\n".join(_battle_log_lines))

func _render_battle_log_text(text: String) -> void:
	_stop_battle_log_typewriter(false)
	battle_log.text = text
	battle_log.visible_characters = -1
	battle_log.scroll_to_line(battle_log.get_line_count())

func _stop_battle_log_typewriter(reveal_all: bool = true) -> void:
	if _battle_log_tween != null:
		_battle_log_tween.kill()
		_battle_log_tween = null
	if reveal_all and is_instance_valid(battle_log):
		battle_log.visible_characters = -1

func _on_battle_log_typewriter_finished() -> void:
	_battle_log_tween = null
	if is_instance_valid(battle_log):
		battle_log.visible_characters = -1
		battle_log.scroll_to_line(battle_log.get_line_count())

func _resolve_timeout_result() -> Dictionary:
	var ally_hp := 0
	for ally in _alive_allies():
		ally_hp += ally.current_hp
	var enemy_hp := 0
	for enemy in _alive_enemies():
		enemy_hp += enemy.current_hp
	return {
		"player_won": ally_hp >= enemy_hp,
		"captured_species": "",
		"battle_kind": battle_config.get("kind", "wild"),
		"timed_out": true,
	}

extends Control

const GameData = preload("res://scripts/game_data.gd")
const MonsterInstance = preload("res://scripts/monster_instance.gd")
const BoardView = preload("res://scripts/board_view.gd")
const BattlePanel = preload("res://scripts/battle_panel.gd")
const DecisionPanel = preload("res://scripts/decision_panel.gd")
const BasePanel = preload("res://scripts/base_panel.gd")

@onready var title_label: Label = %TitleLabel
@onready var round_label: Label = %RoundLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var player_summary_label: RichTextLabel = %PlayerSummaryLabel
@onready var ai_summary_label: RichTextLabel = %AISummaryLabel
@onready var control_summary_label: RichTextLabel = %ControlSummaryLabel
@onready var dice_label: Label = %DiceLabel
@onready var action_hint_label: RichTextLabel = %ActionHintLabel
@onready var map_hint_label: RichTextLabel = %MapHintLabel
@onready var roster_label: RichTextLabel = %RosterLabel
@onready var event_log_label: RichTextLabel = %EventLogLabel
@onready var roll_button: Button = %RollButton
@onready var plus_button: Button = %PlusButton
@onready var minus_button: Button = %MinusButton
@onready var reroll_button: Button = %RerollButton
@onready var support_button: Button = %SupportButton
@onready var base_button: Button = %BaseButton
@onready var new_game_button: Button = %NewGameButton
@onready var board_view: BoardView = %BoardView
@onready var battle_panel: BattlePanel = %BattlePanel
@onready var decision_panel: DecisionPanel = %DecisionPanel
@onready var base_panel: BasePanel = %BasePanel

var rng := RandomNumberGenerator.new()
var board_lookup := GameData.get_board_lookup()
var player := {}
var ai := {}
var current_round := 1
var game_over := false
var boss_defeated_by := ""
var control_owners := {}
var log_lines: Array[String] = []

var current_focus := 0
var dice_value := 0
var awaiting_destination := false
var reroll_used := false
var support_used := false
var free_adjust_remaining := 0
var reachable_paths := {}

var pending_decision_context := {}
var pending_battle_context := {}

func _ready() -> void:
	rng.randomize()
	title_label.text = GameData.GAME_TITLE
	board_view.setup(GameData.BOARD_NODES)
	_connect_signals()
	_apply_basic_styles()
	start_new_game()

func _connect_signals() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	minus_button.pressed.connect(_on_minus_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	support_button.pressed.connect(_on_support_pressed)
	base_button.pressed.connect(_on_base_pressed)
	new_game_button.pressed.connect(start_new_game)
	board_view.node_chosen.connect(_on_board_node_chosen)
	battle_panel.battle_finished.connect(_on_battle_finished)
	decision_panel.choice_selected.connect(_on_decision_choice_selected)
	decision_panel.closed.connect(_on_decision_closed)
	base_panel.assignment_changed.connect(_on_assignment_changed)
	base_panel.upgrade_requested.connect(_on_upgrade_requested)
	base_panel.closed.connect(_on_base_closed)

func _apply_basic_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101826")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("334155")
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	for panel in [battle_panel, decision_panel, base_panel]:
		panel.add_theme_stylebox_override("panel", panel_style)

func start_new_game() -> void:
	current_round = 1
	game_over = false
	boss_defeated_by = ""
	control_owners = {
		8: "",
		9: "",
		11: "",
	}
	log_lines.clear()
	pending_decision_context.clear()
	pending_battle_context.clear()

	player = {
		"position": 0,
		"resources": {"food": 3, "ore": 2, "knowledge": 2},
		"prestige": 0,
		"monsters": [],
		"buildings": {"farm": 1, "forge": 1, "lab": 1},
		"techs": [],
		"tech_tier": 0,
		"next_turn_focus_bonus": 0,
		"round_bonus": {"forge": 0},
	}
	for species_id in GameData.START_PLAYER_SPECIES:
		player["monsters"].append(MonsterInstance.new(species_id))
	player["monsters"][0].set_assignment("frontline")
	player["monsters"][1].set_assignment("frontline")
	player["monsters"][2].set_assignment("lab")

	var personalities := GameData.AI_PERSONALITIES.keys()
	var chosen_personality := String(personalities[rng.randi_range(0, personalities.size() - 1)])
	ai = {
		"position": 0,
		"resources": {"food": 2, "ore": 2, "knowledge": 1},
		"prestige": 0,
		"monsters": [],
		"personality": chosen_personality,
		"intent": "等待开局",
	}
	for species_id in GameData.AI_PERSONALITIES[chosen_personality]["lineup"]:
		ai["monsters"].append(MonsterInstance.new(species_id))

	_push_log("新的局势生成。对手为 %s：%s" % [
		GameData.AI_PERSONALITIES[chosen_personality]["name"],
		GameData.AI_PERSONALITIES[chosen_personality]["description"],
	])
	_push_log("目标：在 %d 回合内先达到 %d 点威望，或在回合结束时领先 AI。" % [GameData.MAX_ROUNDS, GameData.TARGET_PRESTIGE])
	_start_player_turn()

func _start_player_turn() -> void:
	if game_over:
		return
	dice_value = 0
	awaiting_destination = false
	reachable_paths.clear()
	reroll_used = false
	support_used = false
	current_focus = 2 + int(player["next_turn_focus_bonus"])
	player["next_turn_focus_bonus"] = 0
	free_adjust_remaining = 1 if player["techs"].has("survey_maps") else 0
	_push_log("[第 %d 回合] 你的回合开始。先在基地调整，然后掷骰选路。" % current_round)
	_update_ui()

func _on_roll_pressed() -> void:
	if game_over or _is_modal_open():
		return
	if awaiting_destination:
		return
	dice_value = rng.randi_range(1, 4)
	awaiting_destination = true
	_recompute_paths()
	action_hint_label.text = "[b]已掷出 %d 步。[/b] 可用专注修正步数，或直接点亮起的终点落子。" % dice_value
	_update_ui()

func _on_plus_pressed() -> void:
	_adjust_dice(1)

func _on_minus_pressed() -> void:
	_adjust_dice(-1)

func _adjust_dice(delta: int) -> void:
	if game_over or _is_modal_open():
		return
	if not awaiting_destination:
		return
	var next_value := clampi(dice_value + delta, 1, 6)
	if next_value == dice_value:
		return
	if free_adjust_remaining > 0:
		free_adjust_remaining -= 1
		_push_log("测绘图卷生效，本次步数修正免费。")
	elif current_focus <= 0:
		_push_log("专注不足，无法继续修正步数。")
		return
	else:
		current_focus -= 1
	dice_value = next_value
	_recompute_paths()
	action_hint_label.text = "[b]步数修正为 %d。[/b] 继续选择终点。" % dice_value
	_update_ui()

func _on_reroll_pressed() -> void:
	if game_over or _is_modal_open():
		return
	if not awaiting_destination or reroll_used:
		return
	if current_focus <= 0:
		_push_log("专注不足，无法重掷。")
		return
	current_focus -= 1
	reroll_used = true
	dice_value = rng.randi_range(1, 4)
	_recompute_paths()
	_push_log("你消耗 1 点专注重掷，结果为 %d。" % dice_value)
	_update_ui()

func _on_support_pressed() -> void:
	if game_over or _is_modal_open():
		return
	if support_used:
		_push_log("本回合的基地支援已经用过。")
		return
	if current_focus <= 0:
		_push_log("专注不足，无法请求支援。")
		return
	current_focus -= 1
	support_used = true
	var choices := [
		{"id": "med_tent", "label": "医疗支援", "summary": "前线全体回复 6 点生命。"},
		{"id": "supply_drop", "label": "物资空投", "summary": "食粮 +1，矿石 +1。"},
		{"id": "survey_team", "label": "侦察班", "summary": "立即获得 1 点专注。"},
	]
	pending_decision_context = {
		"kind": "support",
		"choices": _index_choices(choices),
		"resume": "player_continue",
	}
	decision_panel.open_panel("基地支援", "消耗的专注已经结算，选择当前回合的战术支援。", choices, "关闭")

func _on_base_pressed() -> void:
	if game_over or _is_modal_open():
		return
	base_panel.open_panel({
		"resources": player["resources"],
		"monsters": player["monsters"],
		"buildings": player["buildings"],
		"preview": _compute_player_production(),
		"techs": _get_player_tech_names(),
	})

func _on_board_node_chosen(node_id: int) -> void:
	if game_over or _is_modal_open():
		return
	if not awaiting_destination or not reachable_paths.has(node_id):
		return
	var node: Dictionary = board_lookup[node_id]
	var path: Array = reachable_paths[node_id]
	player["position"] = node_id
	awaiting_destination = false
	var path_names: Array[String] = []
	for step_id in path:
		path_names.append(String(board_lookup[int(step_id)]["name"]))
	_push_log("你前进 %d 步，路线：%s。" % [dice_value, " -> ".join(path_names)])
	_update_ui()
	_resolve_player_landing(node)

func _resolve_player_landing(node: Dictionary) -> void:
	if int(node["id"]) == ai["position"] and String(node["type"]) != "camp":
		_start_duel_battle("player", int(node["id"]), "player_turn_done")
		return
	match String(node["type"]):
		"resource", "research", "control", "camp":
			_apply_player_direct_node(node)
			_after_player_resolution()
		"event":
			_open_event_choice("player_turn_done")
		"market":
			_open_market_choice("player_turn_done")
		"battle":
			_start_wild_battle(int(node["id"]), "player_turn_done")
		"boss":
			if _is_boss_open() and boss_defeated_by == "":
				_start_boss_battle("player", "player_turn_done")
			else:
				_push_log("尖塔尚未开启或已经被击破，你在残骸间搜得 1 点灵知。")
				_adjust_player({"knowledge": 1})
				_after_player_resolution()

func _apply_player_direct_node(node: Dictionary) -> void:
	if node.has("reward"):
		_adjust_player(node["reward"])
		_push_log("%s 结算：%s。" % [node["name"], GameData.format_resource_delta(node["reward"])])
	if node.has("control_reward"):
		_claim_control(int(node["id"]), "player")
		_push_log("你夺下了 %s，本回合起开始提供持续收益。" % node["name"])
	if String(node["type"]) == "camp":
		_heal_team(_get_player_frontline(), 5)
		_push_log("营地补给使你的前线回复 5 点生命。")

func _after_player_resolution() -> void:
	if _check_for_tech_unlock("player_turn_done"):
		return
	_finish_player_turn()

func _finish_player_turn() -> void:
	if _check_game_over(true):
		return
	_update_ui()
	var timer := get_tree().create_timer(0.4)
	timer.timeout.connect(_run_ai_turn, CONNECT_ONE_SHOT)

func _run_ai_turn() -> void:
	if game_over:
		return
	var roll := rng.randi_range(1, 4)
	var paths := _find_reachable_paths(int(ai["position"]), roll)
	if paths.is_empty():
		_push_log("AI 因路线封闭暂时滞留原地。")
		_finish_round()
		return
	var destination_id := _choose_ai_destination(paths)
	var destination: Dictionary = board_lookup[destination_id]
	ai["position"] = destination_id
	ai["intent"] = "目标：%s" % destination["name"]
	_push_log("AI 掷出 %d，前往 %s。" % [roll, destination["name"]])
	_update_ui()
	if destination_id == player["position"] and String(destination["type"]) != "camp":
		_start_duel_battle("ai", destination_id, "ai_turn_done")
		return
	_resolve_ai_landing(destination)

func _choose_ai_destination(paths: Dictionary) -> int:
	var best_id := -1
	var best_score := -100000
	for node_id in paths.keys():
		var node: Dictionary = board_lookup[int(node_id)]
		var score := _score_ai_node(node)
		if control_owners.get(int(node_id), "") == "player":
			score += 3
		if int(node_id) == player["position"]:
			score += 2
		if score > best_score:
			best_score = score
			best_id = int(node_id)
	return best_id

func _score_ai_node(node: Dictionary) -> int:
	var score := GameData.get_ai_weight(String(ai["personality"]), String(node["type"]))
	if node.has("reward"):
		score += int(node["reward"].get("knowledge", 0)) * 2
		score += int(node["reward"].get("ore", 0))
		score += int(node["reward"].get("food", 0))
	if node.has("control_reward"):
		score += 2
	if String(node["type"]) == "boss" and _is_boss_open() and boss_defeated_by == "":
		score += 5
	if String(node["type"]) == "battle":
		score += _get_ai_frontline().size()
	return score

func _resolve_ai_landing(node: Dictionary) -> void:
	match String(node["type"]):
		"resource", "research", "control", "camp":
			_apply_ai_direct_node(node)
			if _check_game_over(true):
				return
			_finish_round()
		"event":
			_apply_ai_event()
			if _check_game_over(true):
				return
			_finish_round()
		"market":
			_apply_ai_market()
			if _check_game_over(true):
				return
			_finish_round()
		"battle":
			_simulate_ai_battle(int(node["id"]))
			if _check_game_over(true):
				return
			_finish_round()
		"boss":
			if _is_boss_open() and boss_defeated_by == "":
				_simulate_ai_boss()
			else:
				_adjust_ai({"knowledge": 1})
			if _check_game_over(true):
				return
			_finish_round()

func _apply_ai_direct_node(node: Dictionary) -> void:
	if node.has("reward"):
		_adjust_ai(node["reward"])
		_push_log("AI 在 %s 获得 %s。" % [node["name"], GameData.format_resource_delta(node["reward"])])
	if node.has("control_reward"):
		_claim_control(int(node["id"]), "ai")
		_push_log("AI 占领了 %s。" % node["name"])
	if String(node["type"]) == "camp":
		_heal_team(ai["monsters"], 5)

func _apply_ai_event() -> void:
	var card: Dictionary = GameData.EVENT_CARDS[rng.randi_range(0, GameData.EVENT_CARDS.size() - 1)]
	var best_choice: Dictionary = card["choices"][0]
	var best_score := -1000
	for choice in card["choices"]:
		if not _effects_affordable(choice.get("effects", {}), ai["resources"]):
			continue
		var score := int(choice["effects"].get("prestige", 0)) * 3
		score += int(choice["effects"].get("knowledge", 0)) * 2
		score += int(choice["effects"].get("ore", 0))
		score += int(choice["effects"].get("food", 0))
		if score > best_score:
			best_score = score
			best_choice = choice
	_apply_effects(best_choice["effects"], "ai")
	_push_log("AI 在事件【%s】中选择了 %s。" % [card["title"], best_choice["label"]])

func _apply_ai_market() -> void:
	if int(ai["resources"]["food"]) > 0 and _average_hp_ratio(ai["monsters"]) < 0.7:
		_adjust_ai({"food": -1})
		_heal_team(ai["monsters"], 8)
		_push_log("AI 在铜锤集补给，消耗 1 食粮恢复队伍。")
	elif int(ai["resources"]["knowledge"]) > 0:
		_adjust_ai({"knowledge": -1, "ore": 2})
		_push_log("AI 在铜锤集以灵知换取矿石。")
	else:
		_adjust_ai({"food": 1})
		_push_log("AI 在铜锤集获得临时补给。")

func _simulate_ai_battle(node_id: int) -> void:
	var alive := _get_ai_frontline()
	var success_chance := 0.45 + float(alive.size()) * 0.18 + _average_hp_ratio(alive) * 0.2
	if rng.randf() <= success_chance:
		var reward := {"prestige": 1}
		if node_id == 6:
			reward["ore"] = 1
		else:
			reward["food"] = 1
			reward["knowledge"] = 1
		_adjust_ai(reward)
		_heal_team(alive, 2)
		_push_log("AI 在野外战中取胜，获得 %s。" % GameData.format_resource_delta(reward))
	else:
		_damage_team(alive, 5)
		_push_log("AI 在野外战中受挫，队伍状态被削弱。")

func _simulate_ai_boss() -> void:
	var alive := _get_ai_frontline()
	var success_chance := 0.3 + float(alive.size()) * 0.15 + _average_hp_ratio(alive) * 0.25
	if rng.randf() <= success_chance:
		boss_defeated_by = "ai"
		var reward := {"prestige": 4, "knowledge": 2}
		if int(ai["resources"]["food"]) > 0:
			reward["food"] = 1
		_adjust_ai(reward)
		_push_log("AI 击破了裂辉尖塔，获得 %s。" % GameData.format_resource_delta(reward))
	else:
		_damage_team(alive, 8)
		_push_log("AI 挑战裂辉尖塔失败，前线遭到重创。")

func _finish_round() -> void:
	_apply_end_of_round()
	if _check_game_over(true):
		return
	if current_round >= GameData.MAX_ROUNDS:
		_show_game_over("达到回合上限，按威望结算本局。")
		return
	current_round += 1
	_start_player_turn()

func _apply_end_of_round() -> void:
	var production := _compute_player_production()
	_adjust_player(production)
	if not production.is_empty():
		_push_log("基地回合结算：%s。" % GameData.format_resource_delta(production))
	for node_id in control_owners.keys():
		var owner := String(control_owners[node_id])
		if owner == "":
			continue
		var reward: Dictionary = board_lookup[int(node_id)].get("control_reward", {})
		if owner == "player":
			_adjust_player(reward)
		else:
			_adjust_ai(reward)
		_push_log("%s 从 %s 获得 %s。" % [
			"你" if owner == "player" else "AI",
			board_lookup[int(node_id)]["name"],
			GameData.format_resource_delta(reward),
		])
	var extra_rest := 4 if player["techs"].has("field_hospital") else 0
	for monster in player["monsters"]:
		monster.restore_after_round(extra_rest)
	for monster in ai["monsters"]:
		monster.heal(6)
	player["round_bonus"]["forge"] = 0
	_update_ui()

func _compute_player_production() -> Dictionary:
	var result := {"food": 0, "ore": 0, "knowledge": 0}
	for monster in player["monsters"]:
		match String(monster.assignment):
			"farm":
				result["food"] += 1 + monster.get_role_bonus("farm") + int(player["buildings"]["farm"]) - 1
			"forge":
				result["ore"] += 1 + monster.get_role_bonus("forge") + int(player["buildings"]["forge"]) - 1
			"lab":
				result["knowledge"] += 1 + monster.get_role_bonus("lab") + int(player["buildings"]["lab"]) - 1
	if player["techs"].has("auto_haulers"):
		result["food"] += 1
		result["ore"] += 1
	result["ore"] += int(player["round_bonus"]["forge"])
	for key in GameData.RESOURCE_ORDER.duplicate():
		if int(result[key]) <= 0:
			result.erase(key)
	return result

func _recompute_paths() -> void:
	reachable_paths = _find_reachable_paths(int(player["position"]), dice_value)
	if reachable_paths.is_empty():
		action_hint_label.text = "[b]当前步数没有合法终点。[/b] 试着修正步数或重掷。"
	_update_ui()

func _find_reachable_paths(start_id: int, steps: int) -> Dictionary:
	var results := {}
	if steps <= 0:
		return results
	_dfs_reachable(start_id, steps, [], results)
	return results

func _dfs_reachable(current_id: int, steps_left: int, path: Array, results: Dictionary) -> void:
	if steps_left == 0:
		results[current_id] = path.duplicate()
		return
	var node: Dictionary = board_lookup[current_id]
	for edge in node.get("edges", []):
		var next_id := int(edge)
		if next_id == 12 and not _is_boss_open():
			continue
		var next_path := path.duplicate()
		next_path.append(next_id)
		_dfs_reachable(next_id, steps_left - 1, next_path, results)

func _is_boss_open() -> bool:
	return current_round >= GameData.BOSS_UNLOCK_ROUND

func _open_event_choice(resume: String) -> void:
	var card: Dictionary = GameData.EVENT_CARDS[rng.randi_range(0, GameData.EVENT_CARDS.size() - 1)]
	var choices := []
	for choice in card["choices"]:
		var enriched: Dictionary = choice.duplicate(true)
		enriched["disabled"] = not _effects_affordable(choice["effects"], player["resources"])
		choices.append(enriched)
	pending_decision_context = {
		"kind": "event",
		"choices": _index_choices(choices),
		"resume": resume,
	}
	decision_panel.open_panel(card["title"], card["text"], choices, "跳过")

func _open_market_choice(resume: String) -> void:
	var choices := [
		{
			"id": "market_heal",
			"label": "整备队伍",
			"summary": "支付 1 食粮，前线全体回复 8 点生命。",
			"effects": {"food": -1, "heal_frontline": 8},
			"disabled": int(player["resources"]["food"]) < 1,
		},
		{
			"id": "market_ore",
			"label": "购买矿箱",
			"summary": "支付 1 灵知，矿石 +2。",
			"effects": {"knowledge": -1, "ore": 2},
			"disabled": int(player["resources"]["knowledge"]) < 1,
		},
		{
			"id": "market_info",
			"label": "雇佣向导",
			"summary": "支付 1 矿石，下回合专注 +1，威望 +1。",
			"effects": {"ore": -1, "next_turn_focus": 1, "prestige": 1},
			"disabled": int(player["resources"]["ore"]) < 1,
		},
	]
	pending_decision_context = {
		"kind": "market",
		"choices": _index_choices(choices),
		"resume": resume,
	}
	decision_panel.open_panel("铜锤集", "市场里有几项务实的交易。", choices, "离开")

func _open_tech_choice(tier: int, resume: String) -> void:
	var tier_data: Dictionary = GameData.TECH_TIERS[tier]
	var raw_choices: Array = tier_data["choices"]
	var choices := []
	for choice in raw_choices:
		var entry := {
			"id": choice["id"],
			"label": choice["name"],
			"summary": choice["description"],
		}
		choices.append(entry)
	pending_decision_context = {
		"kind": "tech",
		"choices": _index_choices(choices),
		"resume": resume,
		"tier": tier,
	}
	decision_panel.open_panel("研究突破", "你的研究所积累达到阈值，选择一项长期科技。", choices, "稍后")

func _on_decision_choice_selected(choice_id: String) -> void:
	if pending_decision_context.is_empty():
		return
	var context := pending_decision_context.duplicate(true)
	var choice: Dictionary = context["choices"].get(choice_id, {})
	pending_decision_context.clear()
	match String(context["kind"]):
		"support":
			if choice_id == "med_tent":
				_apply_effects({"heal_frontline": 6}, "player")
			if choice_id == "supply_drop":
				_apply_effects({"food": 1, "ore": 1}, "player")
			if choice_id == "survey_team":
				_apply_effects({"focus_now": 1}, "player")
			_push_log("你调用了基地支援：%s。" % String(choice.get("label", choice_id)))
			_resume_flow(String(context["resume"]))
		"event", "market":
			_apply_effects(choice.get("effects", {}), "player")
			_push_log("你在【%s】中选择了 %s。" % [_decision_source_name(String(context["kind"])), String(choice.get("label", choice_id))])
			if _check_for_tech_unlock(String(context["resume"])):
				return
			_resume_flow(String(context["resume"]))
		"tech":
			player["techs"].append(choice_id)
			player["tech_tier"] = int(context["tier"])
			_push_log("你解锁了科技：%s。" % String(choice.get("label", choice_id)))
			_resume_flow(String(context["resume"]))

func _on_decision_closed() -> void:
	if pending_decision_context.is_empty():
		return
	var context := pending_decision_context.duplicate(true)
	pending_decision_context.clear()
	_resume_flow(String(context.get("resume", "player_continue")))

func _resume_flow(token: String) -> void:
	match token:
		"player_turn_done":
			_finish_player_turn()
		"ai_turn_done":
			if _check_game_over(true):
				return
			_finish_round()
		_:
			_update_ui()

func _apply_effects(effects: Dictionary, owner: String) -> void:
	if effects.is_empty():
		return
	if owner == "player":
		_adjust_player(effects)
	else:
		_adjust_ai(effects)
	if effects.has("heal_frontline"):
		var team := _get_player_frontline() if owner == "player" else _get_ai_frontline()
		_heal_team(team, int(effects["heal_frontline"]))
	if owner == "player":
		if effects.has("next_turn_focus"):
			player["next_turn_focus_bonus"] += int(effects["next_turn_focus"])
		if effects.has("focus_now"):
			current_focus += int(effects["focus_now"])
		if effects.has("forge_bonus_this_round"):
			player["round_bonus"]["forge"] += int(effects["forge_bonus_this_round"])

func _effects_affordable(effects: Dictionary, resource_pool: Dictionary) -> bool:
	for key in GameData.RESOURCE_ORDER:
		var delta := int(effects.get(key, 0))
		if delta < 0 and int(resource_pool.get(key, 0)) + delta < 0:
			return false
	return true

func _index_choices(choices: Array) -> Dictionary:
	var map := {}
	for choice in choices:
		map[String(choice["id"])] = choice
	return map

func _decision_source_name(kind: String) -> String:
	if kind == "market":
		return "铜锤集"
	if kind == "event":
		return "奇遇"
	return kind

func _start_wild_battle(node_id: int, resume: String) -> void:
	var enemies := _make_wild_enemy_team(node_id)
	pending_battle_context = {
		"kind": "wild",
		"resume": resume,
		"node_id": node_id,
	}
	battle_panel.start_battle({
		"title": "野外遭遇",
		"subtitle": "压低敌方生命后可尝试捕缚。",
		"kind": "wild",
		"allow_capture": true,
		"allies": _get_player_frontline(),
		"enemies": enemies,
		"ally_first_round_attack_bonus": player["techs"].has("battle_drills"),
	})

func _start_duel_battle(source: String, node_id: int, resume: String) -> void:
	pending_battle_context = {
		"kind": "duel",
		"resume": resume,
		"node_id": node_id,
		"source": source,
	}
	battle_panel.start_battle({
		"title": "领主交锋",
		"subtitle": "击败对手即可夺回节点主导权。",
		"kind": "duel",
		"allow_capture": false,
		"allies": _get_player_frontline(),
		"enemies": _get_ai_frontline(),
		"ally_first_round_attack_bonus": player["techs"].has("battle_drills"),
	})

func _start_boss_battle(source: String, resume: String) -> void:
	pending_battle_context = {
		"kind": "boss",
		"resume": resume,
		"source": source,
		"node_id": 12,
	}
	var guardian := MonsterInstance.new("spire_guardian", 2)
	var escort := MonsterInstance.new("stonehorn", 2)
	battle_panel.start_battle({
		"title": "裂辉尖塔",
		"subtitle": "Boss 战。胜利可直接改写威望差距。",
		"kind": "boss",
		"allow_capture": false,
		"allies": _get_player_frontline(),
		"enemies": [guardian, escort],
		"ally_first_round_attack_bonus": player["techs"].has("battle_drills"),
	})

func _make_wild_enemy_team(node_id: int) -> Array:
	var pool: Array = GameData.WILD_POOLS.get(node_id, ["mist_owl"])
	var team := []
	var first := String(pool[rng.randi_range(0, pool.size() - 1)])
	team.append(MonsterInstance.new(first))
	if node_id == 6:
		var second := String(pool[rng.randi_range(0, pool.size() - 1)])
		team.append(MonsterInstance.new(second))
	return team

func _on_battle_finished(result: Dictionary) -> void:
	if pending_battle_context.is_empty():
		return
	var context := pending_battle_context.duplicate(true)
	pending_battle_context.clear()
	match String(context["kind"]):
		"wild":
			if bool(result["player_won"]):
				var reward := {"prestige": 1}
				if int(context["node_id"]) == 6:
					reward["ore"] = 1
				else:
					reward["food"] = 1
					reward["knowledge"] = 1
				_adjust_player(reward)
				_push_log("你赢下野外战，获得 %s。" % GameData.format_resource_delta(reward))
				if String(result.get("captured_species", "")) != "":
					_add_captured_monster(String(result["captured_species"]))
			else:
				_push_log("你在野外战中败退，只能先稳住阵线。")
			if _check_for_tech_unlock(String(context["resume"])):
				return
			_resume_flow(String(context["resume"]))
		"duel":
			if bool(result["player_won"]):
				var duel_reward := {"prestige": 2}
				if player["techs"].has("pressure_core"):
					duel_reward["prestige"] += 1
				_adjust_player(duel_reward)
				_claim_control(int(context["node_id"]), "player")
				_push_log("你击退了 AI，拿下节点主导权并获得 %s。" % GameData.format_resource_delta(duel_reward))
			else:
				var ai_reward := {"prestige": 2}
				_adjust_ai(ai_reward)
				_claim_control(int(context["node_id"]), "ai")
				_push_log("AI 赢下了正面对决，局势被它扳回。")
			if _check_for_tech_unlock(String(context["resume"])):
				return
			_resume_flow(String(context["resume"]))
		"boss":
			if bool(result["player_won"]):
				boss_defeated_by = "player"
				var boss_reward := {"prestige": 4, "knowledge": 2}
				if player["techs"].has("pressure_core"):
					boss_reward["prestige"] += 1
				_adjust_player(boss_reward)
				_push_log("你击破了裂辉尖塔，获得 %s。" % GameData.format_resource_delta(boss_reward))
			else:
				_push_log("你在裂辉尖塔前折戟，Boss 仍在等待下一次挑战。")
			if _check_for_tech_unlock(String(context["resume"])):
				return
			_resume_flow(String(context["resume"]))

func _add_captured_monster(species_id: String) -> void:
	var monster := MonsterInstance.new(species_id)
	monster.set_assignment("rest")
	player["monsters"].append(monster)
	_adjust_player({"prestige": 1, "knowledge": 1})
	_push_log("新伙伴加入：%s。捕缚奖励 +1 威望、+1 灵知。" % monster.display_name)

func _on_assignment_changed(monster_uid: String, role_id: String) -> void:
	var frontline_count := 0
	var target_monster: MonsterInstance = null
	for monster in player["monsters"]:
		if monster.uid == monster_uid:
			target_monster = monster
		if monster.assignment == "frontline":
			frontline_count += 1
	if target_monster == null:
		return
	if role_id == "frontline" and frontline_count >= GameData.FRONTLINE_SLOTS and target_monster.assignment != "frontline":
		_push_log("前线最多只能安排 %d 只伙伴。" % GameData.FRONTLINE_SLOTS)
	elif role_id != "frontline" and frontline_count <= 1 and target_monster.assignment == "frontline":
		_push_log("至少保留 1 只前线伙伴。")
	else:
		target_monster.set_assignment(role_id)
		_push_log("%s 被调整到岗位：%s。" % [target_monster.display_name, GameData.get_role_name(role_id)])
	base_panel.open_panel({
		"resources": player["resources"],
		"monsters": player["monsters"],
		"buildings": player["buildings"],
		"preview": _compute_player_production(),
		"techs": _get_player_tech_names(),
	})
	_update_ui()

func _on_upgrade_requested(building_id: String) -> void:
	var level := int(player["buildings"][building_id])
	var cost := GameData.get_next_building_cost(building_id, level)
	if cost.is_empty():
		return
	if not _effects_affordable(_negative_cost(cost), player["resources"]):
		_push_log("资源不足，无法升级 %s。" % GameData.get_building_name(building_id))
		return
	_adjust_player(_negative_cost(cost))
	player["buildings"][building_id] = level + 1
	_push_log("%s 升至 Lv.%d。" % [GameData.get_building_name(building_id), int(player["buildings"][building_id])])
	base_panel.open_panel({
		"resources": player["resources"],
		"monsters": player["monsters"],
		"buildings": player["buildings"],
		"preview": _compute_player_production(),
		"techs": _get_player_tech_names(),
	})
	_update_ui()

func _negative_cost(cost: Dictionary) -> Dictionary:
	var out := {}
	for key in cost.keys():
		out[key] = -int(cost[key])
	return out

func _on_base_closed() -> void:
	_update_ui()

func _claim_control(node_id: int, owner: String) -> void:
	if not board_lookup[node_id].has("control_reward"):
		return
	control_owners[node_id] = owner

func _check_for_tech_unlock(resume: String) -> bool:
	var next_tier := int(player["tech_tier"]) + 1
	if not GameData.TECH_TIERS.has(next_tier):
		return false
	var threshold := int(GameData.TECH_TIERS[next_tier]["threshold"])
	if int(player["resources"]["knowledge"]) >= threshold:
		_open_tech_choice(next_tier, resume)
		return true
	return false

func _get_player_frontline() -> Array:
	var frontline := []
	for monster in player["monsters"]:
		if monster.assignment == "frontline" and monster.is_alive():
			frontline.append(monster)
	if frontline.is_empty():
		var reserves: Array = player["monsters"].duplicate()
		reserves.sort_custom(func(a: MonsterInstance, b: MonsterInstance) -> bool:
			return a.current_hp > b.current_hp
		)
		for monster in reserves:
			if monster.is_alive():
				monster.set_assignment("frontline")
				frontline.append(monster)
			if frontline.size() >= 1:
				break
	return frontline.slice(0, GameData.FRONTLINE_SLOTS)

func _get_ai_frontline() -> Array:
	var frontline := []
	for monster in ai["monsters"]:
		if monster.is_alive():
			frontline.append(monster)
	return frontline.slice(0, GameData.FRONTLINE_SLOTS)

func _heal_team(team: Array, amount: int) -> void:
	for monster in team:
		monster.heal(amount)

func _damage_team(team: Array, amount: int) -> void:
	for monster in team:
		monster.take_damage(amount)

func _average_hp_ratio(team: Array) -> float:
	if team.is_empty():
		return 0.0
	var total := 0.0
	for monster in team:
		total += float(monster.current_hp) / float(monster.max_hp)
	return total / float(team.size())

func _adjust_player(delta: Dictionary) -> void:
	_apply_delta(player, delta)

func _adjust_ai(delta: Dictionary) -> void:
	_apply_delta(ai, delta)

func _apply_delta(holder: Dictionary, delta: Dictionary) -> void:
	for key in GameData.RESOURCE_ORDER:
		if delta.has(key):
			holder["resources"][key] = maxi(0, int(holder["resources"][key]) + int(delta[key]))
	if delta.has("prestige"):
		holder["prestige"] = maxi(0, int(holder["prestige"]) + int(delta["prestige"]))

func _check_game_over(include_threshold: bool) -> bool:
	if not include_threshold:
		return false
	if int(player["prestige"]) >= GameData.TARGET_PRESTIGE:
		_show_game_over("你先达到目标威望，赢下了这局原型对抗。")
		return true
	if int(ai["prestige"]) >= GameData.TARGET_PRESTIGE:
		_show_game_over("AI 先达到目标威望，本局失利。")
		return true
	return false

func _show_game_over(reason: String) -> void:
	game_over = true
	awaiting_destination = false
	var result_text := "平局"
	if int(player["prestige"]) > int(ai["prestige"]):
		result_text = "玩家胜利"
	elif int(player["prestige"]) < int(ai["prestige"]):
		result_text = "AI 胜利"
	action_hint_label.text = "[b]对局结束：%s[/b]\n%s" % [result_text, reason]
	_push_log("对局结束：%s。" % reason)
	_update_ui()

func _update_ui() -> void:
	_update_header()
	_update_action_ui()
	_update_summaries()
	_update_roster()
	_update_log()
	_update_map_hint()
	var selectable_nodes: Array[int] = []
	if awaiting_destination:
		for key in reachable_paths.keys():
			selectable_nodes.append(int(key))
	board_view.refresh_view(
		int(player["position"]),
		int(ai["position"]),
		selectable_nodes,
		control_owners,
		reachable_paths,
		_is_boss_open(),
		boss_defeated_by != ""
	)

func _update_header() -> void:
	round_label.text = "第 %d / %d 回合" % [current_round, GameData.MAX_ROUNDS]
	var boss_text := "已开启" if _is_boss_open() else "第 %d 回合开启" % GameData.BOSS_UNLOCK_ROUND
	if boss_defeated_by != "":
		boss_text = "已被 %s 击破" % ("你" if boss_defeated_by == "player" else "AI")
	objective_label.text = "目标威望 %d ｜ 裂辉尖塔：%s" % [GameData.TARGET_PRESTIGE, boss_text]

func _update_summaries() -> void:
	player_summary_label.text = "[b]玩家[/b]\n威望：%d\n资源：%d 食粮 / %d 矿石 / %d 灵知\n专注：%d" % [
		int(player["prestige"]),
		int(player["resources"]["food"]),
		int(player["resources"]["ore"]),
		int(player["resources"]["knowledge"]),
		current_focus,
	]
	var ai_name := String(GameData.AI_PERSONALITIES[String(ai["personality"])]["name"])
	ai_summary_label.text = "[b]%s[/b]\n威望：%d\n资源：%d 食粮 / %d 矿石 / %d 灵知\n意图：%s" % [
		ai_name,
		int(ai["prestige"]),
		int(ai["resources"]["food"]),
		int(ai["resources"]["ore"]),
		int(ai["resources"]["knowledge"]),
		String(ai["intent"]),
	]
	var lines: Array[String] = []
	for node_id in [8, 9, 11]:
		var owner := String(control_owners[node_id])
		var owner_text := "无主"
		if owner == "player":
			owner_text = "你"
		elif owner == "ai":
			owner_text = "AI"
		lines.append("%s：%s" % [board_lookup[node_id]["name"], owner_text])
	control_summary_label.text = "[b]关键据点[/b]\n%s" % "\n".join(lines)

func _update_action_ui() -> void:
	dice_label.text = "当前步数：%s" % ("未掷骰" if dice_value == 0 else str(dice_value))
	roll_button.disabled = game_over or _is_modal_open() or awaiting_destination
	plus_button.disabled = game_over or _is_modal_open() or not awaiting_destination or (current_focus <= 0 and free_adjust_remaining <= 0)
	minus_button.disabled = plus_button.disabled
	reroll_button.disabled = game_over or _is_modal_open() or not awaiting_destination or reroll_used or current_focus <= 0
	support_button.disabled = game_over or _is_modal_open() or support_used or current_focus <= 0
	base_button.disabled = game_over or _is_modal_open()
	if game_over:
		return
	if awaiting_destination:
		action_hint_label.text = "[b]请选择地图上的亮起终点。[/b]\n可继续用 +1/-1 或重掷调整结果。"
	elif dice_value == 0:
		action_hint_label.text = "[b]先管理基地，再掷骰开路。[/b]\n核心闭环：走格 -> 战斗/事件 -> 基地产出 -> AI 反制。"

func _update_roster() -> void:
	var lines: Array[String] = ["[b]伙伴与岗位[/b]"]
	for monster in player["monsters"]:
		lines.append("%s  %d/%d  [%s]" % [
			monster.display_name,
			monster.current_hp,
			monster.max_hp,
			GameData.get_role_name(monster.assignment),
		])
	roster_label.text = "\n".join(lines)

func _update_log() -> void:
	event_log_label.text = "\n".join(log_lines)
	event_log_label.scroll_to_line(event_log_label.get_line_count())

func _update_map_hint() -> void:
	if awaiting_destination and not reachable_paths.is_empty():
		var lines: Array[String] = ["[b]可达终点[/b]"]
		for node_id in reachable_paths.keys():
			var node: Dictionary = board_lookup[int(node_id)]
			lines.append("%s [%s]" % [node["name"], node["type"]])
		map_hint_label.text = "\n".join(lines)
	else:
		map_hint_label.text = "[b]提示[/b]\n优先体验：步数修正、抢据点、抓到新怪后在基地切换岗位。"

func _push_log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 16:
		log_lines.pop_front()

func _get_player_tech_names() -> Array:
	var names := []
	for tech_id in player["techs"]:
		for tier in GameData.TECH_TIERS.values():
			for choice in tier["choices"]:
				if String(choice["id"]) == String(tech_id):
					names.append(String(choice["name"]))
	return names

func _is_modal_open() -> bool:
	return battle_panel.visible or decision_panel.visible or base_panel.visible

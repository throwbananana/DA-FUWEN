class_name MonsterInstance
extends RefCounted

const GameData = preload("res://scripts/game_data.gd")

static var _serial := 1

var uid := ""
var species_id := ""
var display_name := ""
var type := ""
var level := 1
var max_hp := 1
var current_hp := 1
var attack := 1
var speed := 1
var skills: Array = []
var roles := {}
var assignment := "rest"

func _init(species: String = "", monster_level: int = 1) -> void:
	if species == "":
		return
	var template: Dictionary = GameData.MONSTERS.get(species, {})
	species_id = species
	display_name = template.get("name", species)
	type = template.get("type", "mist")
	level = monster_level
	max_hp = int(template.get("max_hp", 10)) + (monster_level - 1) * 2
	current_hp = max_hp
	attack = int(template.get("attack", 4)) + (monster_level - 1)
	speed = int(template.get("speed", 4))
	skills = template.get("skills", []).duplicate()
	roles = template.get("roles", {}).duplicate(true)
	uid = "m_%s" % str(_serial)
	_serial += 1

func is_alive() -> bool:
	return current_hp > 0

func heal(amount: int) -> void:
	current_hp = clampi(current_hp + amount, 0, max_hp)

func take_damage(amount: int) -> void:
	current_hp = clampi(current_hp - amount, 0, max_hp)

func get_role_bonus(role_id: String) -> int:
	return int(roles.get(role_id, 0))

func get_summary() -> String:
	return "%s [%s] %d/%d" % [display_name, GameData.get_type_name(type), current_hp, max_hp]

func duplicate_for_battle() -> MonsterInstance:
	var dupe = get_script().new(species_id, level)
	dupe.current_hp = current_hp
	dupe.assignment = assignment
	return dupe

func restore_after_round(rest_bonus: int = 0) -> void:
	var base_heal := 4
	if assignment == "rest":
		base_heal += 4
	heal(base_heal + rest_bonus)

func set_assignment(role_id: String) -> void:
	assignment = role_id

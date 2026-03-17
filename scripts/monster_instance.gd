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
var star_level := 1
var skills: Array = []
var roles := {}
var assignment := "rest"
var elements: Array = []
var biome_tags: Array = []
var job_tags: Array = []
var building_tags: Array = []

func _init(species: String = "", monster_level: int = 1, monster_star: int = 1) -> void:
	if species == "":
		return
	var template: Dictionary = GameData.get_monster_template(species)
	species_id = species
	display_name = template.get("name", species)
	type = template.get("type", "mist")
	level = monster_level
	star_level = monster_star
	max_hp = int(template.get("max_hp", 10)) + (monster_level - 1) * 2 + (star_level - 1) * 5
	current_hp = max_hp
	attack = int(template.get("attack", 4)) + (monster_level - 1) + (star_level - 1) * 2
	speed = int(template.get("speed", 4)) + (star_level - 1)
	skills = template.get("skills", []).duplicate()
	roles = template.get("roles", {}).duplicate(true)
	elements = template.get("elements", [type]).duplicate()
	biome_tags = template.get("biome_tags", []).duplicate()
	job_tags = template.get("job_tags", []).duplicate()
	building_tags = template.get("building_tags", []).duplicate()
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
	return "%s ★%d [%s] %d/%d" % [display_name, star_level, GameData.get_type_name(type), current_hp, max_hp]

func duplicate_for_battle() -> MonsterInstance:
	var dupe = get_script().new(species_id, level, star_level)
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

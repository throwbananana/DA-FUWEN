class_name BattleRosterService
extends RefCounted

const MonsterInstance = preload("res://scripts/monster_instance.gd")

func build_active_allies() -> Array:
	return _build_units(GameState.get_battle_party_uids())

func build_reserve_allies() -> Array:
	return _build_units(GameState.get_reserve_uids())

func pet_level_for_battle(pet: Dictionary) -> int:
	var base_level := 1 + int(GameState.get_habitat_rank_total() / 2)
	base_level += int(pet.get("bond_level", 1)) - 1
	return clampi(base_level, 1, 6)

func _build_units(pet_uids: Array[String]) -> Array:
	var units: Array = []
	for raw_pet_uid in pet_uids:
		var pet_uid := String(raw_pet_uid)
		var pet := GameState.get_pet(pet_uid)
		if pet.is_empty():
			continue
		var star_level := int(pet.get("star_level", 1))
		var level := pet_level_for_battle(pet)
		var unit := MonsterInstance.new(String(pet.get("species_id", "")), level, star_level)
		unit.display_name = String(pet.get("display_name", unit.display_name))
		unit.uid = String(pet.get("uid", pet_uid))
		units.append(unit)
	return units

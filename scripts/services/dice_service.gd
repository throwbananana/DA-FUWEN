class_name DiceService
extends RefCounted

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func roll() -> Dictionary:
	var value := rng.randi_range(1, 6)
	return {
		"base_roll": value,
		"value": value,
		"adjustment": 0,
		"rerolled": false,
	}

func reroll(_current_roll: Dictionary = {}) -> Dictionary:
	var value := rng.randi_range(1, 6)
	return {
		"base_roll": value,
		"value": value,
		"adjustment": 0,
		"rerolled": true,
	}

func apply_adjust(roll_state: Dictionary, delta: int) -> Dictionary:
	if roll_state.is_empty():
		return {"ok": false, "reason": "roll_missing"}
	var next_value := clampi(int(roll_state.get("value", 0)) + delta, 1, 6)
	if next_value == int(roll_state.get("value", 0)):
		return {"ok": false, "reason": "roll_limit"}
	var next_roll: Dictionary = roll_state.duplicate(true)
	next_roll["value"] = next_value
	next_roll["adjustment"] = int(next_roll.get("adjustment", 0)) + delta
	return {"ok": true, "roll": next_roll}

func describe_roll(roll_state: Dictionary) -> String:
	if roll_state.is_empty():
		return "未掷骰"
	var parts: Array[String] = ["d6=%d" % int(roll_state.get("base_roll", 0))]
	var adjustment := int(roll_state.get("adjustment", 0))
	if adjustment != 0:
		parts.append("修正 %+d" % adjustment)
	parts.append("结果 %d" % int(roll_state.get("value", 0)))
	if bool(roll_state.get("rerolled", false)):
		parts.append("本周已重掷")
	return " ｜ ".join(parts)

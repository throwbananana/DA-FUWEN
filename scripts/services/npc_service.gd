class_name NpcService
extends RefCounted

## 负责 NPC 好感、委托刷新与奖励发放。

func get_visible_npcs(habitat_id: String) -> Array:
	return DataRepository.get_habitat_npcs(habitat_id)

func get_npc_trust(npc_id: String) -> int:
	return int(GameState.npc_trust.get(npc_id, 0))

func complete_trust_reward(npc_id: String, trust_gain: int) -> Dictionary:
	GameState.add_trust(npc_id, trust_gain)
	var npc := DataRepository.get_npc(npc_id)
	var trust_now := get_npc_trust(npc_id)

	var unlocked: Array = []
	var reward_map: Dictionary = npc.get("trust_rewards", {})
	for threshold in reward_map.keys():
		var threshold_value := int(threshold)
		if trust_now >= threshold_value:
			unlocked.append({
				"threshold": threshold_value,
				"reward": reward_map[threshold]
			})
	return {
		"ok": true,
		"npc_id": npc_id,
		"trust": trust_now,
		"unlocked": unlocked
	}

func get_available_quests(habitat_id: String) -> Array:
	var result: Array = []
	for quest in DataRepository.quests.values():
		var quest_id := String(quest.get("id", ""))
		if String(quest.get("target_habitat", "")) == habitat_id and not GameState.completed_quests.has(quest_id):
			result.append(quest)
	return result

func finish_quest(quest_id: String) -> Dictionary:
	var quest := DataRepository.get_quest(quest_id)
	if quest.is_empty():
		return {"ok": false, "reason": "quest_missing"}
	if GameState.completed_quests.has(quest_id):
		return {"ok": false, "reason": "already_completed"}

	var rewards: Dictionary = quest.get("rewards", {})
	var items: Dictionary = rewards.get("items", {})
	if not items.is_empty():
		GameState.grant_items(items)

	var trust_gain := int(rewards.get("trust", 0))
	var giver_id := String(quest.get("giver", ""))
	var trust_result := {}
	if trust_gain > 0 and not giver_id.is_empty():
		trust_result = complete_trust_reward(giver_id, trust_gain)

	if rewards.has("unlock_habitat"):
		var habitat_id := String(rewards["unlock_habitat"])
		GameState.unlock_habitat(habitat_id)

	GameState.complete_quest(quest_id)

	return {
		"ok": true,
		"quest_id": quest_id,
		"trust_result": trust_result,
		"items": items,
		"journal_entry": rewards.get("journal_entry", "")
	}

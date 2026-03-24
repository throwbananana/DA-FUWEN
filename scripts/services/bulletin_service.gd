class_name BulletinService
extends RefCounted

const EncounterServiceScript = preload("res://scripts/services/encounter_service.gd")
const ShopServiceScript = preload("res://scripts/services/shop_service.gd")

var encounter_service = EncounterServiceScript.new()
var shop_service = ShopServiceScript.new()

func build_board_bulletin(node: Dictionary = {}) -> Dictionary:
	var title := String(node.get("name", "公告板"))
	var description := String(node.get("description", "路牌上贴着最近整理过的野群动向和集市折扣。"))
	var wild_hints: Array = _build_wild_hints()
	var discount_hints: Array = _build_discount_hints()
	var lines: Array[String] = []
	lines.append(description)
	lines.append("[b]线索时间[/b] %s ｜ 第 %d 周" % [_season_name(GameState.season_id), GameState.week_index])
	lines.append("")
	lines.append("[b]野生宠物动向[/b]")
	if wild_hints.is_empty():
		lines.append("暂时没人贴出新的野群消息。")
	else:
		for hint in wild_hints:
			lines.append("• %s" % String(hint.get("line", "")))
	lines.append("")
	lines.append("[b]摊位折扣[/b]")
	if discount_hints.is_empty():
		lines.append("今天还没人把折扣货单贴出来。")
	else:
		for hint in discount_hints:
			lines.append("• %s" % String(hint.get("line", "")))
	return {
		"ok": true,
		"title": title,
		"description": description,
		"season_name": _season_name(GameState.season_id),
		"week_index": GameState.week_index,
		"wild_hints": wild_hints,
		"discount_hints": discount_hints,
		"body_lines": lines,
		"body": "\n".join(lines),
	}

func _build_wild_hints(limit: int = 5) -> Array:
	var result: Array = []
	for habitat_id in _collect_bulletin_habitats(limit):
		var entries := encounter_service.build_weighted_entries(habitat_id, "observe")
		if entries.is_empty():
			continue
		var species_names := _top_species_names(entries, 3)
		if species_names.is_empty():
			continue
		result.append({
			"habitat_id": habitat_id,
			"habitat_name": _habitat_display_name(habitat_id),
			"species_names": species_names,
			"line": "%s：%s" % [_habitat_display_name(habitat_id), " / ".join(species_names)],
		})
	return result

func _build_discount_hints(limit: int = 4) -> Array:
	var result: Array = []
	for shop_id in _collect_bulletin_shops():
		var menu: Dictionary = shop_service.get_shop_menu(shop_id)
		if not bool(menu.get("ok", false)):
			continue
		var discounted: Array = []
		for raw_offer in menu.get("offers", []):
			var offer := Dictionary(raw_offer).duplicate(true)
			if not bool(offer.get("is_discounted", false)):
				continue
			discounted.append(offer)
		if discounted.is_empty():
			continue
		var offer_chunks: Array[String] = []
		for raw_offer in discounted.slice(0, 3):
			var offer := Dictionary(raw_offer).duplicate(true)
			offer_chunks.append("%s %d→%d 金" % [
				String(offer.get("item_name", offer.get("label", "货物"))),
				int(offer.get("base_price", offer.get("price", 0))),
				int(offer.get("price", 0)),
			])
		result.append({
			"shop_id": shop_id,
			"shop_name": String(menu.get("shop_name", _habitat_display_name(shop_id))),
			"offers": discounted,
			"line": "%s：%s" % [String(menu.get("shop_name", _habitat_display_name(shop_id))), " / ".join(offer_chunks)],
		})
		if result.size() >= limit:
			break
	return result

func _collect_bulletin_habitats(limit: int) -> Array[String]:
	var region: Dictionary = DataRepository.get_board_region(GameState.board_region_id)
	var habitat_ids: Array[String] = []
	var seen := {}
	for raw_node in Array(region.get("nodes", [])):
		var node := Dictionary(raw_node).duplicate(true)
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty() or seen.has(habitat_id):
			continue
		if encounter_service.build_weighted_entries(habitat_id, "observe").is_empty():
			continue
		seen[habitat_id] = true
		habitat_ids.append(habitat_id)
		if habitat_ids.size() >= limit:
			break
	if not habitat_ids.is_empty():
		return habitat_ids
	for raw_habitat_id in DataRepository.habitats.keys():
		var habitat_id := String(raw_habitat_id)
		if encounter_service.build_weighted_entries(habitat_id, "observe").is_empty():
			continue
		habitat_ids.append(habitat_id)
		if habitat_ids.size() >= limit:
			break
	return habitat_ids

func _collect_bulletin_shops() -> Array[String]:
	var region: Dictionary = DataRepository.get_board_region(GameState.board_region_id)
	var shop_ids: Array[String] = []
	var seen := {}
	for raw_node in Array(region.get("nodes", [])):
		var node := Dictionary(raw_node).duplicate(true)
		var habitat_id := String(node.get("habitat_id", ""))
		if habitat_id.is_empty() or seen.has(habitat_id):
			continue
		if DataRepository.get_shop(habitat_id).is_empty():
			continue
		seen[habitat_id] = true
		shop_ids.append(habitat_id)
	return shop_ids

func _top_species_names(entries: Array, limit: int) -> Array[String]:
	var weights := {}
	for raw_entry in entries:
		var entry := Dictionary(raw_entry).duplicate(true)
		var species_id := String(entry.get("species_id", ""))
		if species_id.is_empty():
			continue
		var current_weight := int(weights.get(species_id, 0))
		weights[species_id] = current_weight + int(entry.get("effective_weight", entry.get("weight", 0)))
	var rows: Array = []
	for species_id in weights.keys():
		var species := DataRepository.get_species(String(species_id))
		rows.append({
			"id": String(species_id),
			"name": String(species.get("name", species_id)),
			"weight": int(weights.get(species_id, 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var weight_a := int(a.get("weight", 0))
		var weight_b := int(b.get("weight", 0))
		if weight_a == weight_b:
			return String(a.get("name", "")) < String(b.get("name", ""))
		return weight_a > weight_b
	)
	var names: Array[String] = []
	for row in rows.slice(0, maxi(1, limit)):
		names.append(String(row.get("name", "")))
	return names

func _habitat_display_name(habitat_id: String) -> String:
	return String(DataRepository.get_habitat(habitat_id).get("name", habitat_id))

func _season_name(season_id: String) -> String:
	match season_id:
		"spring":
			return "春季"
		"summer":
			return "夏季"
		"autumn":
			return "秋季"
		"winter":
			return "冬季"
		_:
			return season_id

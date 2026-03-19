class_name ShopService
extends RefCounted

## 管理商店库存生成、事件/节日轮换与购买结算。

func get_shop_menu(habitat_id: String) -> Dictionary:
	var shop := DataRepository.get_shop(habitat_id)
	if shop.is_empty():
		return {
			"ok": false,
			"reason": "shop_missing",
			"habitat_id": habitat_id,
		}
	var offers := _build_offers(shop)
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"shop_id": String(shop.get("id", habitat_id)),
		"shop_name": String(shop.get("name", DataRepository.get_habitat(habitat_id).get("name", "商店"))),
		"description": String(shop.get("description", "")),
		"wallet_gold": GameState.wallet_gold,
		"week_index": GameState.week_index,
		"season_id": GameState.season_id,
		"offers": offers,
		"active_rotations": _build_active_rotation_titles(shop),
	}

func buy_offer(habitat_id: String, offer_id: String) -> Dictionary:
	var shop := DataRepository.get_shop(habitat_id)
	if shop.is_empty():
		return {"ok": false, "reason": "shop_missing", "habitat_id": habitat_id}
	var offer := _find_offer(_build_offers(shop), offer_id)
	if offer.is_empty():
		return {"ok": false, "reason": "offer_missing", "habitat_id": habitat_id, "offer_id": offer_id}
	var remaining := int(offer.get("remaining_stock", 0))
	if remaining <= 0:
		return {"ok": false, "reason": "sold_out", "habitat_id": habitat_id, "offer": offer}
	var price := int(offer.get("price", 0))
	if not GameState.spend_wallet_gold(price):
		return {"ok": false, "reason": "insufficient_gold", "habitat_id": habitat_id, "offer": offer}
	var item_id := String(offer.get("item_id", ""))
	var quantity := maxi(1, int(offer.get("quantity", 1)))
	GameState.grant_items({item_id: quantity})
	GameState.record_shop_purchase(String(shop.get("id", habitat_id)), offer_id)
	var updated_remaining := maxi(0, remaining - 1)
	var result_offer := Dictionary(offer).duplicate(true)
	result_offer["remaining_stock"] = updated_remaining
	result_offer["purchased"] = int(result_offer.get("purchased", 0)) + 1
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"shop_id": String(shop.get("id", habitat_id)),
		"shop_name": String(shop.get("name", DataRepository.get_habitat(habitat_id).get("name", "商店"))),
		"wallet_gold": GameState.wallet_gold,
		"offer": result_offer,
	}

func _build_offers(shop: Dictionary) -> Array:
	var offers_by_id: Dictionary = {}
	var order: Array[String] = []
	for offer in shop.get("offers", []):
		if not _conditions_match(offer):
			continue
		_register_offer(offers_by_id, order, shop, offer, "base")
	for rotation in shop.get("rotations", []):
		if not _conditions_match(rotation):
			continue
		if bool(rotation.get("replace_base", false)):
			offers_by_id.clear()
			order.clear()
		for offer in rotation.get("offers", []):
			if not _conditions_match(offer):
				continue
			_register_offer(offers_by_id, order, shop, offer, String(rotation.get("id", "rotation")))
	var result: Array = []
	for offer_id in order:
		if offers_by_id.has(offer_id):
			result.append(offers_by_id[offer_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return String(a.get("label", "")) < String(b.get("label", ""))
		return priority_a > priority_b
	)
	return result

func _register_offer(offers_by_id: Dictionary, order: Array, shop: Dictionary, offer: Dictionary, rotation_id: String) -> void:
	var offer_id := String(offer.get("id", ""))
	if offer_id.is_empty():
		return
	if not order.has(offer_id):
		order.append(offer_id)
	offers_by_id[offer_id] = _enrich_offer(shop, offer, rotation_id)

func _enrich_offer(shop: Dictionary, offer: Dictionary, rotation_id: String) -> Dictionary:
	var item_id := String(offer.get("item_id", ""))
	var item := DataRepository.get_item(item_id)
	var shop_id := String(shop.get("id", ""))
	var stock := maxi(1, int(offer.get("stock", 1)))
	var purchased := GameState.get_shop_purchase_count(shop_id, String(offer.get("id", "")))
	var label := String(offer.get("label", item.get("name", item_id)))
	return {
		"id": String(offer.get("id", "")),
		"item_id": item_id,
		"label": label,
		"item_name": String(item.get("name", label)),
		"item_type": String(item.get("type", "material")),
		"price": maxi(0, int(offer.get("price", 0))),
		"quantity": maxi(1, int(offer.get("quantity", 1))),
		"stock": stock,
		"purchased": purchased,
		"remaining_stock": maxi(0, stock - purchased),
		"priority": int(offer.get("priority", 0)),
		"rotation_id": rotation_id,
		"tags": Array(offer.get("tags", [])).duplicate(),
	}

func _build_active_rotation_titles(shop: Dictionary) -> Array:
	var titles: Array = []
	for rotation in shop.get("rotations", []):
		if not _conditions_match(rotation):
			continue
		var title := String(rotation.get("title", rotation.get("id", "")))
		if not title.is_empty():
			titles.append(title)
	return titles

func _find_offer(offers: Array, offer_id: String) -> Dictionary:
	for offer in offers:
		if String(offer.get("id", "")) == offer_id:
			return Dictionary(offer).duplicate(true)
	return {}

func _conditions_match(source: Dictionary) -> bool:
	var season_ids: Array = source.get("season_ids", [])
	if not season_ids.is_empty() and not season_ids.has(GameState.season_id):
		return false
	var week_range: Array = source.get("week_range", [])
	if week_range.size() >= 2:
		var week_min := int(week_range[0])
		var week_max := int(week_range[1])
		if GameState.week_index < week_min or GameState.week_index > week_max:
			return false
	for event_id in source.get("required_event_ids", []):
		if not GameState.has_completed_event(String(event_id)):
			return false
	for event_id in source.get("blocked_event_ids", []):
		if GameState.has_completed_event(String(event_id)):
			return false
	for flag_id in source.get("required_story_flags", []):
		if not GameState.has_story_flag(String(flag_id)):
			return false
	for flag_id in source.get("blocked_story_flags", []):
		if GameState.has_story_flag(String(flag_id)):
			return false
	return true

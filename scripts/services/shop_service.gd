class_name ShopService
extends RefCounted

## 管理商店库存生成、事件/节日轮换、摊位 NPC 服务与购买结算。

const NpcRouteServiceScript = preload("res://scripts/services/npc_route_service.gd")

var npc_route_service = NpcRouteServiceScript.new()

func get_shop_menu(habitat_id: String) -> Dictionary:
	var shop := DataRepository.get_shop(habitat_id)
	if shop.is_empty():
		return {
			"ok": false,
			"reason": "shop_missing",
			"habitat_id": habitat_id,
		}
	var offers := _build_offers(shop)
	var npc_services := _build_npc_services(shop)
	var discounted_offer_count := 0
	for offer in offers:
		if bool(Dictionary(offer).get("is_discounted", false)):
			discounted_offer_count += 1
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
		"discounted_offer_count": discounted_offer_count,
		"npc_services": npc_services,
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

func use_npc_service(habitat_id: String, service_id: String) -> Dictionary:
	var shop := DataRepository.get_shop(habitat_id)
	if shop.is_empty():
		return {"ok": false, "reason": "shop_missing", "habitat_id": habitat_id}
	var service := _find_npc_service(_build_npc_services(shop), service_id)
	if service.is_empty():
		return {"ok": false, "reason": "service_missing", "habitat_id": habitat_id, "service_id": service_id}
	if not bool(service.get("available", false)):
		return {
			"ok": false,
			"reason": String(service.get("disabled_reason", "service_unavailable")),
			"habitat_id": habitat_id,
			"shop_id": String(shop.get("id", habitat_id)),
			"shop_name": String(shop.get("name", DataRepository.get_habitat(habitat_id).get("name", "商店"))),
			"service": service,
			"cost_items": Dictionary(service.get("cost_items", {})).duplicate(true),
			"cost_gold": int(service.get("cost_gold", 0)),
		}
	var preview := _preview_npc_service(shop, service)
	if not bool(preview.get("ok", false)):
		var failed_preview := Dictionary(preview).duplicate(true)
		failed_preview["shop_id"] = String(shop.get("id", habitat_id))
		failed_preview["shop_name"] = String(shop.get("name", DataRepository.get_habitat(habitat_id).get("name", "商店")))
		failed_preview["habitat_id"] = habitat_id
		failed_preview["service"] = service
		failed_preview["cost_items"] = Dictionary(service.get("cost_items", {})).duplicate(true)
		failed_preview["cost_gold"] = int(service.get("cost_gold", 0))
		return failed_preview
	var cost_gold := int(service.get("cost_gold", 0))
	var cost_items := Dictionary(service.get("cost_items", {})).duplicate(true)
	if cost_gold > 0 and not GameState.spend_wallet_gold(cost_gold):
		return {"ok": false, "reason": "insufficient_gold", "habitat_id": habitat_id, "service": service, "cost_gold": cost_gold, "cost_items": cost_items}
	if not cost_items.is_empty() and not GameState.pay_cost(cost_items):
		if cost_gold > 0:
			GameState.add_wallet_gold(cost_gold)
		return {"ok": false, "reason": "missing_items", "habitat_id": habitat_id, "service": service, "cost_gold": cost_gold, "cost_items": cost_items}
	var reward_items := Dictionary(service.get("reward_items", {})).duplicate(true)
	if not reward_items.is_empty():
		GameState.grant_items(reward_items)
	var trust_gain := int(service.get("trust_gain", 0))
	var npc_id := String(service.get("npc_id", ""))
	if trust_gain > 0 and not npc_id.is_empty():
		GameState.add_trust(npc_id, trust_gain)
	GameState.record_shop_purchase(String(shop.get("id", habitat_id)), _npc_service_purchase_key(service_id))
	var result_service := Dictionary(service).duplicate(true)
	result_service["used_count"] = int(result_service.get("used_count", 0)) + 1
	result_service["remaining_uses"] = maxi(0, int(result_service.get("remaining_uses", 0)) - 1)
	result_service["available"] = int(result_service.get("remaining_uses", 0)) > 0
	result_service["disabled_reason"] = "service_used_up" if int(result_service.get("remaining_uses", 0)) <= 0 else ""
	return {
		"ok": true,
		"habitat_id": habitat_id,
		"shop_id": String(shop.get("id", habitat_id)),
		"shop_name": String(shop.get("name", DataRepository.get_habitat(habitat_id).get("name", "商店"))),
		"wallet_gold": GameState.wallet_gold,
		"service": result_service,
		"cost_gold": cost_gold,
		"cost_items": cost_items,
		"reward_items": reward_items,
		"trust_now": int(GameState.npc_trust.get(npc_id, 0)),
		"lines": Array(preview.get("lines", [])).duplicate(),
	}

func _build_offers(shop: Dictionary, context: Dictionary = {}) -> Array:
	var offers_by_id: Dictionary = {}
	var order: Array[String] = []
	for offer in shop.get("offers", []):
		if not _conditions_match(offer, context):
			continue
		_register_offer(offers_by_id, order, shop, offer, "base", context)
	for rotation in shop.get("rotations", []):
		if not _conditions_match(rotation, context):
			continue
		if bool(rotation.get("replace_base", false)):
			offers_by_id.clear()
			order.clear()
		for offer in rotation.get("offers", []):
			if not _conditions_match(offer, context):
				continue
			_register_offer(offers_by_id, order, shop, offer, String(rotation.get("id", "rotation")), context)
	var result: Array = []
	for offer_id in order:
		if offers_by_id.has(offer_id):
			result.append(offers_by_id[offer_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return priority_a > priority_b
	)
	var discount_lookup := _build_discount_lookup(shop, result, context)
	var enriched: Array = []
	for raw_offer in result:
		var offer := Dictionary(raw_offer).duplicate(true)
		var offer_id := String(offer.get("id", ""))
		enriched.append(
			_enrich_offer(
				shop,
				offer,
				String(offer.get("_rotation_id", "base")),
				context,
				Dictionary(discount_lookup.get(offer_id, {})).duplicate(true)
			)
		)
	enriched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return String(a.get("label", "")) < String(b.get("label", ""))
		return priority_a > priority_b
	)
	return enriched

func _build_npc_services(shop: Dictionary, context: Dictionary = {}) -> Array:
	var result: Array = []
	var visible_npc_ids := {}
	for npc in npc_route_service.get_visible_npcs(String(shop.get("id", ""))):
		var npc_id := String(npc.get("id", ""))
		if not npc_id.is_empty():
			visible_npc_ids[npc_id] = true
	for service in shop.get("npc_services", []):
		if not _conditions_match(service, context):
			continue
		var npc_id := String(service.get("npc_id", ""))
		if not npc_id.is_empty() and not visible_npc_ids.has(npc_id):
			continue
		result.append(_enrich_npc_service(shop, service, context))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return String(a.get("label", "")) < String(b.get("label", ""))
		return priority_a > priority_b
	)
	return result

func _register_offer(offers_by_id: Dictionary, order: Array, shop: Dictionary, offer: Dictionary, rotation_id: String, context: Dictionary = {}) -> void:
	var offer_id := String(offer.get("id", ""))
	if offer_id.is_empty():
		return
	if not order.has(offer_id):
		order.append(offer_id)
	var staged_offer := Dictionary(offer).duplicate(true)
	staged_offer["_rotation_id"] = rotation_id
	offers_by_id[offer_id] = staged_offer

func _enrich_offer(shop: Dictionary, offer: Dictionary, rotation_id: String, context: Dictionary = {}, discount_data: Dictionary = {}) -> Dictionary:
	var item_id := String(offer.get("item_id", ""))
	var item := DataRepository.get_item(item_id)
	var shop_id := String(shop.get("id", ""))
	var stock := maxi(1, int(offer.get("stock", 1)))
	var purchased := 0
	if _is_current_context(context):
		purchased = GameState.get_shop_purchase_count(shop_id, String(offer.get("id", "")))
	var label := String(offer.get("label", item.get("name", item_id)))
	var base_price := maxi(0, int(offer.get("price", 0)))
	var discount_percent := maxi(0, int(discount_data.get("percent", 0)))
	var price := _discounted_price(base_price, discount_percent)
	var tags: Array = Array(offer.get("tags", [])).duplicate()
	if discount_percent > 0 and not tags.has("本周折扣"):
		tags.append("本周折扣")
	return {
		"id": String(offer.get("id", "")),
		"item_id": item_id,
		"label": label,
		"item_name": String(item.get("name", label)),
		"item_type": String(item.get("type", "material")),
		"price": price,
		"base_price": base_price,
		"is_discounted": discount_percent > 0,
		"discount_percent": discount_percent,
		"discount_reason": String(discount_data.get("reason", "")),
		"quantity": maxi(1, int(offer.get("quantity", 1))),
		"stock": stock,
		"purchased": purchased,
		"remaining_stock": maxi(0, stock - purchased),
		"priority": int(offer.get("priority", 0)),
		"rotation_id": rotation_id,
		"tags": tags,
	}

func get_discounted_offers(habitat_id: String, context: Dictionary = {}) -> Array:
	var shop := DataRepository.get_shop(habitat_id)
	if shop.is_empty():
		return []
	var discounted: Array = []
	for raw_offer in _build_offers(shop, context):
		var offer := Dictionary(raw_offer).duplicate(true)
		if bool(offer.get("is_discounted", false)):
			discounted.append(offer)
	return discounted

func _enrich_npc_service(shop: Dictionary, service: Dictionary, context: Dictionary = {}) -> Dictionary:
	var service_id := String(service.get("id", ""))
	var npc_id := String(service.get("npc_id", ""))
	var npc := DataRepository.get_npc(npc_id)
	var uses_per_week := maxi(1, int(service.get("uses_per_week", 1)))
	var used_count := 0
	if _is_current_context(context):
		used_count = GameState.get_shop_purchase_count(String(shop.get("id", "")), _npc_service_purchase_key(service_id))
	var remaining_uses := maxi(0, uses_per_week - used_count)
	var required_trust := maxi(0, int(service.get("required_trust", 0)))
	var trust_now := int(GameState.npc_trust.get(npc_id, 0))
	var cost_gold := maxi(0, int(service.get("cost_gold", 0)))
	var cost_items := Dictionary(service.get("cost_items", {})).duplicate(true)
	var disabled_reason := ""
	if remaining_uses <= 0:
		disabled_reason = "service_used_up"
	elif trust_now < required_trust:
		disabled_reason = "trust_locked"
	elif cost_gold > 0 and not GameState.can_afford_wallet_gold(cost_gold):
		disabled_reason = "insufficient_gold"
	elif not cost_items.is_empty() and not GameState.can_pay(cost_items):
		disabled_reason = "missing_items"
	elif String(service.get("type", "")) == "intel" and _build_future_shop_preview(shop, int(service.get("preview_week_offset", 1)), int(service.get("preview_offer_count", 3))).is_empty():
		disabled_reason = "no_intel"
	return {
		"id": service_id,
		"npc_id": npc_id,
		"npc_name": String(npc.get("name", service.get("npc_name", npc_id))),
		"label": String(service.get("label", service_id)),
		"description": String(service.get("description", "")),
		"type": String(service.get("type", "trade_in")),
		"cost_gold": cost_gold,
		"cost_items": cost_items,
		"reward_items": Dictionary(service.get("reward_items", {})).duplicate(true),
		"required_trust": required_trust,
		"trust_now": trust_now,
		"trust_gain": maxi(0, int(service.get("trust_gain", 0))),
		"uses_per_week": uses_per_week,
		"used_count": used_count,
		"remaining_uses": remaining_uses,
		"priority": int(service.get("priority", 0)),
		"preview_week_offset": int(service.get("preview_week_offset", 1)),
		"preview_offer_count": int(service.get("preview_offer_count", 3)),
		"tags": Array(service.get("tags", [])).duplicate(),
		"success_text": String(service.get("success_text", "")),
		"available": disabled_reason.is_empty(),
		"disabled_reason": disabled_reason,
	}

func _build_active_rotation_titles(shop: Dictionary, context: Dictionary = {}) -> Array:
	var titles: Array = []
	for rotation in shop.get("rotations", []):
		if not _conditions_match(rotation, context):
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

func _find_npc_service(services: Array, service_id: String) -> Dictionary:
	for service in services:
		if String(service.get("id", "")) == service_id:
			return Dictionary(service).duplicate(true)
	return {}

func _preview_npc_service(shop: Dictionary, service: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var success_text := String(service.get("success_text", ""))
	if not success_text.is_empty():
		lines.append(success_text)
	match String(service.get("type", "trade_in")):
		"trade_in":
			return {"ok": true, "lines": lines}
		"intel":
			var intel_lines := _build_future_shop_preview(shop, int(service.get("preview_week_offset", 1)), int(service.get("preview_offer_count", 3)))
			if intel_lines.is_empty():
				return {"ok": false, "reason": "no_intel", "lines": []}
			lines.append_array(intel_lines)
			return {"ok": true, "lines": lines}
		_:
			return {"ok": false, "reason": "service_type_unknown", "lines": []}

func _build_future_shop_preview(shop: Dictionary, week_offset: int, offer_count: int) -> Array[String]:
	var preview_context := _make_eval_context(week_offset)
	var future_offers := _build_offers(shop, preview_context)
	var future_rotations := _build_active_rotation_titles(shop, preview_context)
	var lines: Array[String] = []
	if future_offers.is_empty() and future_rotations.is_empty():
		return lines
	lines.append("[b]预测周次[/b] 第 %d 周" % int(preview_context.get("week_index", GameState.week_index)))
	if not future_rotations.is_empty():
		lines.append("[b]可能轮换[/b] %s" % " / ".join(future_rotations))
	var preview_labels: Array[String] = []
	for offer in future_offers.slice(0, maxi(1, offer_count)):
		preview_labels.append("%s（%s）" % [
			String(offer.get("item_name", offer.get("label", "货物"))),
			_format_offer_price_text(Dictionary(offer).duplicate(true)),
		])
	if not preview_labels.is_empty():
		lines.append("[b]先看到的货单[/b] %s" % " / ".join(preview_labels))
	return lines

func _build_discount_lookup(shop: Dictionary, offers: Array, context: Dictionary = {}) -> Dictionary:
	var result := {}
	if offers.is_empty():
		return result
	var ranked: Array = []
	var shop_id := String(shop.get("id", ""))
	var season_id := String(context.get("season_id", GameState.season_id))
	var week_index := int(context.get("week_index", GameState.week_index))
	for raw_offer in offers:
		var offer := Dictionary(raw_offer).duplicate(true)
		var offer_id := String(offer.get("id", ""))
		var base_price := maxi(0, int(offer.get("price", 0)))
		if offer_id.is_empty() or base_price <= 1:
			continue
		var score: int = int(abs(hash("%s|%s|%s|%d" % [shop_id, offer_id, season_id, week_index])))
		ranked.append({
			"id": offer_id,
			"score": score,
			"base_price": base_price,
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("score", 0))
		var score_b := int(b.get("score", 0))
		if score_a == score_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return score_a < score_b
	)
	for row in ranked.slice(0, mini(ranked.size(), _discount_slot_count(context))):
		var offer_id := String(row.get("id", ""))
		var percent := _discount_percent_for_score(int(row.get("score", 0)))
		if _discounted_price(int(row.get("base_price", 0)), percent) >= int(row.get("base_price", 0)):
			continue
		result[offer_id] = {
			"percent": percent,
			"reason": "weekly_bulletin",
		}
	return result
	
func _discount_slot_count(context: Dictionary = {}) -> int:
	var week_index := int(context.get("week_index", GameState.week_index))
	if week_index >= 4:
		return 3
	if week_index >= 2:
		return 2
	return 1

func _discount_percent_for_score(score: int) -> int:
	match posmod(score, 3):
		0:
			return 25
		1:
			return 30
		_:
			return 35

func _discounted_price(base_price: int, discount_percent: int) -> int:
	if base_price <= 0 or discount_percent <= 0:
		return maxi(0, base_price)
	var reduced := int(floor(float(base_price) * float(100 - discount_percent) / 100.0))
	if base_price > 1:
		reduced = mini(base_price - 1, maxi(1, reduced))
	return maxi(1, reduced)

func _format_offer_price_text(offer: Dictionary) -> String:
	var price := int(offer.get("price", 0))
	if not bool(offer.get("is_discounted", false)):
		return "%d 金" % price
	return "%d→%d 金" % [int(offer.get("base_price", price)), price]

func _conditions_match(source: Dictionary, context: Dictionary = {}) -> bool:
	var season_id := String(context.get("season_id", GameState.season_id))
	var week_index := int(context.get("week_index", GameState.week_index))
	var season_ids: Array = source.get("season_ids", [])
	if not season_ids.is_empty() and not season_ids.has(season_id):
		return false
	var week_range: Array = source.get("week_range", [])
	if week_range.size() >= 2:
		var week_min := int(week_range[0])
		var week_max := int(week_range[1])
		if week_index < week_min or week_index > week_max:
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

func _npc_service_purchase_key(service_id: String) -> String:
	return "npc_service:%s" % service_id

func _make_eval_context(week_offset: int = 0) -> Dictionary:
	return {
		"season_id": GameState.season_id,
		"week_index": maxi(1, GameState.week_index + maxi(week_offset, 0)),
	}

func _is_current_context(context: Dictionary) -> bool:
	if context.is_empty():
		return true
	return String(context.get("season_id", GameState.season_id)) == GameState.season_id and int(context.get("week_index", GameState.week_index)) == GameState.week_index

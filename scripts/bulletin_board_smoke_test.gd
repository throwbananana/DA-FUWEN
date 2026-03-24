extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	_run_checks.call_deferred(scene)

func _run_checks(scene: Node) -> void:
	var data_repository := root.get_node("DataRepository")
	var game_state := root.get_node("GameState")
	data_repository.load_all()
	game_state.reset_for_new_season()
	var board_progression_service = load("res://scripts/services/board_progression_service.gd").new()

	for season_id in ["spring", "summer", "autumn", "winter"]:
		game_state.season_id = String(season_id)
		board_progression_service.set_region_for_season(String(season_id))
		var region: Dictionary = board_progression_service.get_region()
		if region.is_empty():
			_fail("Bulletin smoke test failed: board region missing for %s." % season_id)
			return
		var bulletin_node := _find_bulletin_node(Array(region.get("nodes", [])))
		if bulletin_node.is_empty():
			_fail("Bulletin smoke test failed: %s board is missing a bulletin node." % season_id)
			return
		if not _revealed_nodes_have(Array(region.get("revealed_nodes", [])), int(bulletin_node.get("id", -1))):
			_fail("Bulletin smoke test failed: %s bulletin node should start revealed." % season_id)
			return

	game_state.season_id = "spring"
	board_progression_service.set_region_for_season("spring")
	game_state.board_region_id = String(board_progression_service.get_region_id())
	var bulletin_service = load("res://scripts/services/bulletin_service.gd").new()
	var spring_region: Dictionary = board_progression_service.get_region()
	var spring_bulletin := _find_bulletin_node(Array(spring_region.get("nodes", [])))
	var report: Dictionary = bulletin_service.build_board_bulletin(spring_bulletin)
	if Array(report.get("wild_hints", [])).is_empty():
		_fail("Bulletin smoke test failed: bulletin should preview wild-pet hotspots.")
		return
	if Array(report.get("discount_hints", [])).is_empty():
		_fail("Bulletin smoke test failed: bulletin should preview discounted shop offers.")
		return

	var shop_service = load("res://scripts/services/shop_service.gd").new()
	var shop_menu: Dictionary = shop_service.get_shop_menu("copper_hammer_bazaar")
	if not bool(shop_menu.get("ok", false)):
		_fail("Bulletin smoke test failed: copper_hammer_bazaar shop menu did not load.")
		return
	var discounted_offers: Array = []
	for raw_offer in shop_menu.get("offers", []):
		var offer := Dictionary(raw_offer).duplicate(true)
		if bool(offer.get("is_discounted", false)):
			discounted_offers.append(offer)
	if discounted_offers.is_empty():
		_fail("Bulletin smoke test failed: shop menu should expose at least one discounted offer.")
		return
	if int(shop_menu.get("discounted_offer_count", 0)) != discounted_offers.size():
		_fail("Bulletin smoke test failed: discounted_offer_count should match the discounted offers in the menu.")
		return
	var matched_discount := false
	var discount_lines: Array = report.get("discount_hints", [])
	for raw_offer in discounted_offers:
		var offer := Dictionary(raw_offer).duplicate(true)
		if int(offer.get("price", 0)) >= int(offer.get("base_price", 0)):
			_fail("Bulletin smoke test failed: discounted offer price should be below base price.")
			return
		for raw_hint in discount_lines:
			var hint := Dictionary(raw_hint).duplicate(true)
			if String(hint.get("line", "")).contains(String(offer.get("item_name", ""))):
				matched_discount = true
				break
		if matched_discount:
			break
	if not matched_discount:
		_fail("Bulletin smoke test failed: bulletin discount lines should mention an actually discounted offer.")
		return

	scene._show_bulletin_board(spring_bulletin)
	await process_frame
	if not scene.decision_panel.visible:
		_fail("Bulletin smoke test failed: bulletin node did not open a decision panel.")
		return
	if String(scene.pending_context.get("kind", "")) != "bulletin_board":
		_fail("Bulletin smoke test failed: bulletin node should set the bulletin_board context.")
		return

	await create_timer(0.05).timeout
	quit()

func _find_bulletin_node(nodes: Array) -> Dictionary:
	for raw_node in nodes:
		var node := Dictionary(raw_node).duplicate(true)
		if String(node.get("type", "")) == "bulletin":
			return node
	return {}

func _revealed_nodes_have(values: Array, expected_node_id: int) -> bool:
	for raw_value in values:
		if int(raw_value) == expected_node_id:
			return true
	return false

func _fail(message: String) -> void:
	push_error(message)
	call_deferred("_quit_with_error")

func _quit_with_error() -> void:
	quit(1)

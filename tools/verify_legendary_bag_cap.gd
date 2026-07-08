extends SceneTree

## godot --headless --path "<project>" --script res://tools/verify_legendary_bag_cap.gd

const _DefaultContent := preload("res://scripts/data/default_content.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_bag_rejects_duplicate_legendary(failures)
	_test_shop_excludes_owned_legendary(failures)

	if failures.is_empty():
		print("PASS: legendary bag cap verification")
		quit(0)
	else:
		for message in failures:
			print("FAIL: %s" % message)
		quit(1)


func _test_bag_rejects_duplicate_legendary(failures: Array[String]) -> void:
	var bag := BagModel.new()
	var grail := _legendary("holy_grail")
	if not bag.add_to_master_bag(grail):
		failures.append("bag: first legendary add failed")
		return
	if bag.add_to_master_bag(grail):
		failures.append("bag: allowed duplicate legendary")
	if not bag.can_add_to_master_bag(grail):
		return
	failures.append("bag: can_add_to_master_bag true for duplicate legendary")


func _test_shop_excludes_owned_legendary(failures: Array[String]) -> void:
	var content := _DefaultContent.create()
	var bag := BagModel.new()
	var grail := content.find_ingredient("holy_grail")
	if grail == null:
		failures.append("shop: holy_grail missing from content")
		return
	bag.add_to_master_bag(grail)

	var shop := ShopService.new(content)
	var offers := shop.generate_offers(1, 9999, 6, [], bag)
	for offer in offers:
		if offer == null or offer.ingredient == null:
			continue
		if offer.ingredient.id == "holy_grail":
			failures.append("shop: offered owned legendary holy_grail")


func _legendary(id: String) -> IngredientData:
	return IngredientData.new(id, id, "", 1, 0, 1, IngredientData.Rarity.LEGENDARY)
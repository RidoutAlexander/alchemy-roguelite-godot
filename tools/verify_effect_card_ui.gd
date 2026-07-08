extends SceneTree

## Run with:
## godot --headless --path "<project>" --script res://tools/verify_effect_card_ui.gd

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _TrinketEffects := preload("res://scripts/brewing/trinket_effects.gd")

var _failures: Array[String] = []
var _card_scene: PackedScene
var _stage := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if _card_scene == null:
		_card_scene = load("res://scenes/ui/ingredient_card.tscn") as PackedScene
		if _card_scene == null:
			print("FAIL: could not load ingredient_card scene")
			quit(1)
			return

	match _stage:
		0:
			_test_hand_card_effect_visibility()
			_stage = 1
			call_deferred("_run_tests")
		1:
			_test_picker_card_effect_visibility()
			_stage = 2
			call_deferred("_run_tests")
		2:
			_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: effect card UI visibility checks passed")
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(1)


func _test_hand_card_effect_visibility() -> void:
	var card := _card_scene.instantiate() as IngredientCard
	if card == null:
		_failures.append("could not instantiate hand card")
		return
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 600)
	root.size = Vector2(800, 600)
	root.add_child(card)
	get_root().add_child(root)

	var ingredient := IngredientData.new(
		"boom_berry_2",
		"Boom Berry",
		"",
		2,
		2,
		0,
		IngredientData.Rarity.COMMON
	)
	var effect_entries: Array = [
		{"ingredient_id": _IngredientEffects.HONEY_ID, "overlay_text": ""},
		{"trinket_id": _TrinketEffects.GECKO_ASSISTANT_ID, "overlay_text": ""},
		{"ingredient_id": _IngredientEffects.UNICORN_HORN_ID, "overlay_text": ""},
		{"ingredient_id": _IngredientEffects.COBBLER_ID, "overlay_text": ""},
	]
	card.bind_hand_card(ingredient, 0, false, 12, 4, effect_entries)

	_assert_visible(card, "HandSlotEffectIcons")
	_assert_visible(card, "GeckoHandOverlay")
	_assert_visible(card, "HoneySplatterOverlay")
	_assert_visible(card, "UnicornSparkleFX")

	var icons := card.get_node_or_null("HandSlotEffectIcons") as Control
	if icons != null and icons.visible:
		var icon_count := _count_visible_icon_children(icons)
		if icon_count < 1:
			_failures.append(
				"hand card should show at least one effect icon, got %d" % icon_count
			)
	elif icons == null or not icons.visible:
		_failures.append("hand HandSlotEffectIcons should be visible")

	root.queue_free()


func _test_picker_card_effect_visibility() -> void:
	var card := _card_scene.instantiate() as IngredientCard
	if card == null:
		_failures.append("could not instantiate picker card")
		return
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 600)
	root.size = Vector2(800, 600)
	root.add_child(card)
	get_root().add_child(root)

	var ingredient := IngredientData.new(
		"boom_berry_2",
		"Boom Berry",
		"",
		2,
		2,
		0,
		IngredientData.Rarity.COMMON
	)
	card.bind_picker_card(ingredient)
	var preview := {
		"point_value": 12,
		"explosive_value": 4,
		"effect_entries": [
			{"ingredient_id": _IngredientEffects.COBBLER_ID, "overlay_text": ""},
			{"trinket_id": _TrinketEffects.POCKET_WATCH_ID, "overlay_text": ""},
		],
		"shake": false,
	}
	card.apply_picker_preview(preview)

	_assert_visible(card, "HandSlotEffectIcons")
	var icons := card.get_node_or_null("HandSlotEffectIcons") as Control
	if icons != null and icons.visible:
		var icon_count := _count_visible_icon_children(icons)
		if icon_count < 1:
			_failures.append(
				"picker card should show at least one effect icon, got %d" % icon_count
			)
	elif icons == null or not icons.visible:
		_failures.append("picker HandSlotEffectIcons should be visible")

	root.queue_free()


func _count_visible_icon_children(icons: Control) -> int:
	var icon_row := icons.get_node_or_null("IconRow")
	if icon_row == null:
		return 0
	var icon_count := 0
	for child in icon_row.get_children():
		if child.visible:
			icon_count += 1
	return icon_count


func _assert_visible(card: Node, node_name: String) -> void:
	var node := card.get_node_or_null(node_name) as CanvasItem
	if node == null:
		_failures.append("%s node missing" % node_name)
		return
	if not node.visible:
		_failures.append("%s should be visible" % node_name)
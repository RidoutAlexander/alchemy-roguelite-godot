extends Node

## Attached to effect_ui_test.tscn — run:
## godot --headless --path "<project>" res://tools/effect_ui_test.tscn

const _CardScene := preload("res://scenes/ui/ingredient_card.tscn")
const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _TrinketEffects := preload("res://scripts/brewing/trinket_effects.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_test_hand_honey_overlay()
	_test_hand_cobbler_icon()
	_test_picker_cobbler_icon()
	_finish()


func _test_hand_honey_overlay() -> void:
	var card := _mount_card()
	var boom := IngredientData.new(
		"boom_berry_2", "Boom", "", 2, 2, 0, IngredientData.Rarity.COMMON
	)
	var effects: Array = [{"ingredient_id": _IngredientEffects.HONEY_ID, "overlay_text": ""}]
	card.bind_hand_card(boom, 0, false, 2, 2, effects)
	await get_tree().process_frame
	_assert_node_visible(card, "VisualRoot/HoneySplatterOverlay", "hand honey splatter")
	card.queue_free()


func _test_hand_cobbler_icon() -> void:
	var card := _mount_card()
	var boom := IngredientData.new(
		"boom_berry_2", "Boom", "", 2, 2, 0, IngredientData.Rarity.COMMON
	)
	var effects: Array = [{"ingredient_id": _IngredientEffects.COBBLER_ID, "overlay_text": ""}]
	card.bind_hand_card(boom, 0, false, 12, 4, effects)
	await get_tree().process_frame
	var icons := card.get_node_or_null("VisualRoot/HandSlotEffectIcons") as Control
	if icons == null:
		icons = card.get_node_or_null("HandSlotEffectIcons") as Control
	if icons == null:
		_failures.append("hand cobbler: HandSlotEffectIcons node missing")
		return
	if not icons.visible:
		_failures.append("hand cobbler: HandSlotEffectIcons not visible")
		return
	var icon_count := _visible_icon_children(icons)
	if icon_count < 1:
		_failures.append("hand cobbler: expected >=1 icon, got %d" % icon_count)
	var icon_rect := icons.get_global_rect()
	if icon_rect.size.x < 8.0 or icon_rect.size.y < 8.0:
		_failures.append("hand cobbler: icon strip zero-size rect %s" % str(icon_rect))
	card.queue_free()


func _test_picker_cobbler_icon() -> void:
	var card := _mount_card()
	var boom := IngredientData.new(
		"boom_berry_2", "Boom", "", 2, 2, 0, IngredientData.Rarity.COMMON
	)
	card.bind_picker_card(boom)
	card.apply_picker_preview({
		"point_value": 12,
		"explosive_value": 4,
		"effect_entries": [
			{"ingredient_id": _IngredientEffects.COBBLER_ID, "overlay_text": ""},
		],
		"shake": false,
	})
	await get_tree().process_frame
	var icons := card.get_node_or_null("VisualRoot/HandSlotEffectIcons") as Control
	if icons == null:
		icons = card.get_node_or_null("HandSlotEffectIcons") as Control
	if icons == null:
		_failures.append("picker cobbler: HandSlotEffectIcons node missing")
		return
	if not icons.visible:
		_failures.append("picker cobbler: HandSlotEffectIcons not visible")
		return
	var icon_count := _visible_icon_children(icons)
	if icon_count < 1:
		_failures.append("picker cobbler: expected >=1 icon, got %d" % icon_count)
	card.queue_free()


func _mount_card() -> IngredientCard:
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 600)
	root.size = Vector2(800, 600)
	add_child(root)
	var card := _CardScene.instantiate() as IngredientCard
	root.add_child(card)
	return card


func _assert_node_visible(card: Node, node_path: String, label: String) -> void:
	var node := card.get_node_or_null(node_path) as CanvasItem
	if node == null:
		_failures.append("%s: node missing at %s" % [label, node_path])
		return
	if not node.visible:
		_failures.append("%s: node not visible" % label)


func _visible_icon_children(icons: Control) -> int:
	var row := icons.get_node_or_null("IconRow")
	if row == null:
		return 0
	var count := 0
	for child in row.get_children():
		if child.visible:
			count += 1
	return count


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: effect UI integration test")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		get_tree().quit(1)
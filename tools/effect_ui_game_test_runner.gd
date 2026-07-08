extends Node

## godot --headless --path "<project>" res://tools/effect_ui_game_test.tscn

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _test_brew_panel_sync_hand_honey()
	await _test_eyeball_picker_overlay_flow()
	_finish()


func _test_brew_panel_sync_hand_honey() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game_root := game_scene.instantiate()
	add_child(game_root)
	await get_tree().process_frame

	var brew_panel := game_root.get_node_or_null("PhaseSwipeHost/BrewPanel") as BrewPanel
	if brew_panel == null:
		_failures.append("game: BrewPanel missing")
		game_root.queue_free()
		return

	var session := GameManager.run.brew_session
	session._hand_phase = BrewSession.HandPhase.HAND
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)
	session._hand_slots = [boom, honey, null, null, null]
	session._refresh_hand_preview_locks()

	brew_panel.visible = true
	brew_panel._sync_hand_ui()
	await get_tree().process_frame

	var hand_row := brew_panel.get_node_or_null("PlayerHandRow") as PlayerHandRow
	if hand_row == null or not hand_row.visible:
		_failures.append("game: PlayerHandRow not visible after sync")
		game_root.queue_free()
		return

	var card := hand_row.get_node_or_null("SlotRow/SlotAnchor1/HandCard1") as IngredientCard
	if card == null or not card.visible:
		_failures.append("game: slot0 hand card not visible")
		game_root.queue_free()
		return

	var honey_overlay := _find_effect_node(card, "HoneySplatterOverlay") as CanvasItem
	if honey_overlay == null or not honey_overlay.visible:
		_failures.append("game: slot0 honey overlay not visible after _sync_hand_ui")

	var overlay_rect: Rect2 = honey_overlay.get_global_rect() if honey_overlay != null else Rect2()
	if overlay_rect.size.x < 1.0 or overlay_rect.size.y < 1.0:
		_failures.append("game: honey overlay zero-size rect %s" % str(overlay_rect))

	game_root.queue_free()


func _test_eyeball_picker_overlay_flow() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game_root := game_scene.instantiate()
	add_child(game_root)
	await get_tree().process_frame

	var overlay := game_root.get_node_or_null("EyeballPuzzleOverlay") as EyeballPuzzleOverlay
	if overlay == null:
		_failures.append("game: EyeballPuzzleOverlay missing")
		game_root.queue_free()
		return

	var session := GameManager.run.brew_session
	_setup_cobbler_bat_wing_picker(session)
	var boom := _make_ingredient("boom_berry_2", 99, 2, 2)
	var choices: Array = session.get_bat_wing_choices()
	if choices.is_empty():
		choices = [boom]
	elif not _choices_contain_id(choices, "boom_berry_2"):
		choices[0] = boom

	overlay.show_picker(choices)
	await get_tree().process_frame
	await get_tree().process_frame

	var slot := overlay.get_node_or_null(
		"Layout/PanelOffset/Panel/Content/OrderSlotsRow/OrderSlot1"
	)
	if slot == null:
		_failures.append("game picker: slot1 missing")
		overlay.hide_puzzle()
		game_root.queue_free()
		return

	var boom_card := _find_picker_card_for_id(overlay, "boom_berry_2")
	if boom_card == null:
		boom_card = _find_picker_card_with_effect_icons(overlay)
	if boom_card == null:
		_failures.append("game picker: no choice card with effect icons found")
	else:
		if not boom_card.is_picker_mode():
			_failures.append("game picker: choice card not in picker mode after show_picker")
		var ingredient := boom_card.get_ingredient()
		var preview: Dictionary = (
			session.get_bat_wing_choice_preview(ingredient)
			if ingredient != null
			else {}
		)
		if preview.get("effect_entries", []).is_empty():
			_failures.append(
				"game picker: preview missing effect_entries for %s"
				% str(ingredient.id if ingredient != null else "null")
			)
		var icons := _find_effect_node(boom_card, "HandSlotEffectIcons") as Control
		if icons == null or not icons.visible or _visible_icon_children(icons) < 1:
			_failures.append(
				"game picker: effect icons not visible on %s"
				% str(ingredient.id if ingredient != null else "null")
			)

	overlay.hide_puzzle()
	game_root.queue_free()


func _setup_cobbler_bat_wing_picker(session: BrewSession) -> void:
	var cobbler := _make_ingredient(_IngredientEffects.COBBLER_ID, 1, 2, 0)
	var bat_wing := _make_ingredient(_IngredientEffects.BAT_WING_ID, 2, 0, 0)
	var filler := _make_ingredient("rat", 3, 1, 0)
	var bag: BagModel = BagModel.new()
	bag.set_master_bag([filler, _filler_copy(4), _filler_copy(5), _filler_copy(6)])
	session.start_brew(1, _neutral_aura(), bag)
	session._hand_phase = BrewSession.HandPhase.PLAYING
	session._hand_slots = [cobbler, bat_wing, null, null, null]
	session._hand_start_slots = session._hand_slots.duplicate()
	session._play_slot_cursor = 0
	session._hand_locked_slots = {}
	session._apply_ingredient(cobbler, true, true, 0)
	session._hand_slots[0] = null
	session._play_slot_cursor = 1
	session._apply_ingredient(bat_wing, true, true, 1)
	session._hand_slots[1] = null
	session._play_slot_cursor = 2
	session._bat_wing_source_slot_index = 1
	session.begin_bat_wing_picker()


func _find_picker_card_for_id(overlay: EyeballPuzzleOverlay, ingredient_id: String) -> IngredientCard:
	for slot_index in 3:
		var slot := overlay.get_node_or_null(
			"Layout/PanelOffset/Panel/Content/OrderSlotsRow/OrderSlot%d" % (slot_index + 1)
		)
		if slot == null or not slot.has_method("get_card"):
			continue
		var card: IngredientCard = slot.get_card()
		if card == null:
			continue
		var ingredient := card.get_ingredient()
		if ingredient != null and ingredient.id == ingredient_id:
			return card
	return null


func _find_picker_card_with_effect_icons(overlay: EyeballPuzzleOverlay) -> IngredientCard:
	for slot_index in 3:
		var slot := overlay.get_node_or_null(
			"Layout/PanelOffset/Panel/Content/OrderSlotsRow/OrderSlot%d" % (slot_index + 1)
		)
		if slot == null or not slot.has_method("get_card"):
			continue
		var card: IngredientCard = slot.get_card()
		if card == null:
			continue
		var icons := _find_effect_node(card, "HandSlotEffectIcons") as Control
		if icons != null and icons.visible and _visible_icon_children(icons) > 0:
			return card
	return null


func _find_effect_node(card: IngredientCard, node_name: String) -> Node:
	var node := card.get_node_or_null(node_name)
	if node == null:
		node = card.get_node_or_null("VisualRoot/%s" % node_name)
	return node


func _choices_contain_id(choices: Array, ingredient_id: String) -> bool:
	for choice in choices:
		if choice is IngredientData and choice.id == ingredient_id:
			return true
	return false


func _visible_icon_children(icons: Control) -> int:
	var row := icons.get_node_or_null("IconRow")
	if row == null:
		return 0
	var count := 0
	for child in row.get_children():
		if child.visible:
			count += 1
	return count


func _filler_copy(copy: int) -> IngredientData:
	return _make_ingredient("rat", copy, 1, 0)


func _neutral_aura() -> AuraData:
	return AuraData.new("test", "Test", "", AuraData.Pool.NORMAL, 1, 0, 100, 100)


func _make_ingredient(
	id: String,
	copy: int = 1,
	points: int = 1,
	explosive: int = 0
) -> IngredientData:
	return IngredientData.new(
		id, id, "", points, explosive, 0, IngredientData.Rarity.COMMON
	)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: effect UI game integration test")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		get_tree().quit(1)
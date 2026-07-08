extends Node

## godot --headless --path "<project>" res://tools/effect_ui_e2e_test.tscn

const _CardScene := preload("res://scenes/ui/ingredient_card.tscn")
const _PlayerHandScene := preload("res://scenes/ui/player_hand_row.tscn")
const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _AuraData := preload("res://scripts/data/aura_data.gd")
const _BrewSession := preload("res://scripts/brewing/brew_session.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _test_session_to_hand_row_honey()
	await _test_hand_row_icon_layer_cobbler()
	await _test_reveal_slot_during_draw()
	await _test_bat_wing_picker_preview_icons()
	await _test_picker_bind_before_place_flow()
	_finish()


func _test_session_to_hand_row_honey() -> void:
	var session: BrewSession = _BrewSession.new()
	session._hand_phase = BrewSession.HandPhase.HAND
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)
	session._hand_slots = [boom, honey, null, null, null]
	session._refresh_hand_preview_locks()

	var effects: Array = session.get_hand_slot_effect_entries()
	var slot0: Array = effects[0] if effects.size() > 0 else []
	if slot0.is_empty():
		_failures.append("e2e: session slot0 effect entries empty: %s" % str(effects))
		return

	var hand_row := _PlayerHandScene.instantiate() as PlayerHandRow
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 400)
	root.size = Vector2(800, 400)
	add_child(root)
	root.add_child(hand_row)
	hand_row.position = Vector2(40.0, 40.0)
	await get_tree().process_frame

	hand_row.refresh_hand(
		session.get_hand_slots(),
		true,
		true,
		[],
		session.get_hand_display_stats(),
		effects
	)
	await get_tree().process_frame

	var card := hand_row.get_node("SlotRow/SlotAnchor1/HandCard1") as IngredientCard
	if card == null:
		_failures.append("e2e: hand card 1 missing")
		return
	var honey_overlay := _find_effect_node(card, "HoneySplatterOverlay") as CanvasItem
	if honey_overlay == null or not honey_overlay.visible:
		_failures.append("e2e: hand row slot0 honey overlay not visible")
	_assert_canvas_in_row(hand_row, honey_overlay, "e2e hand honey overlay")
	hand_row.queue_free()


func _test_hand_row_icon_layer_cobbler() -> void:
	var hand_row := _PlayerHandScene.instantiate() as PlayerHandRow
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 400)
	root.size = Vector2(800, 400)
	add_child(root)
	root.add_child(hand_row)
	hand_row.position = Vector2(40.0, 40.0)
	await get_tree().process_frame

	var boom := _make_ingredient("boom_berry_2", 2, 2)
	var effects: Array = [[
		{"ingredient_id": _IngredientEffects.COBBLER_ID, "overlay_text": ""},
	]]
	hand_row.refresh_hand([boom, null, null, null, null], true, true, [], [], effects)
	await get_tree().process_frame

	var icons := hand_row.get_node_or_null(
		"HandEffectIconRow/SlotEffectIcons1"
	) as HandSlotEffectIcons
	if icons == null or not icons.visible:
		_failures.append("e2e icon layer: slot0 strip not visible")
		return
	if _visible_icon_children(icons) < 1:
		_failures.append("e2e icon layer: slot0 has no bound icons")
	var rect := icons.get_global_rect()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		_failures.append("e2e icon layer: slot0 zero-size rect %s" % str(rect))
	var parent := icons.get_parent()
	if parent == null or parent.name != "HandEffectIconRow":
		_failures.append("e2e icon layer: expected HandEffectIconRow parent")
	hand_row.queue_free()


func _test_reveal_slot_during_draw() -> void:
	var session: BrewSession = _BrewSession.new()
	session._hand_phase = BrewSession.HandPhase.DRAWING
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)

	var hand_row := _PlayerHandScene.instantiate() as PlayerHandRow
	var root := get_child(0) as Control
	if root == null:
		root = Control.new()
		root.custom_minimum_size = Vector2(800, 400)
		add_child(root)
	root.add_child(hand_row)
	hand_row.position = Vector2(40.0, 40.0)
	await get_tree().process_frame

	hand_row.prepare_for_draw([])
	hand_row.reveal_slot(0, boom, null, [])
	await get_tree().process_frame
	var drawing_slots: Array = [boom, honey, null, null, null]
	var effects: Array = session.get_hand_slot_effect_entries(drawing_slots)
	hand_row.cache_slot_effect_entries(effects)
	for slot_index in 2:
		hand_row.reveal_slot(
			slot_index,
			drawing_slots[slot_index],
			null,
			effects[slot_index] if slot_index < effects.size() else []
		)
	await get_tree().process_frame

	var card := hand_row.get_node("SlotRow/SlotAnchor1/HandCard1") as IngredientCard
	if card == null:
		_failures.append("e2e draw: hand card 1 missing")
		return
	var honey_overlay := _find_effect_node(card, "HoneySplatterOverlay") as CanvasItem
	if honey_overlay == null or not honey_overlay.visible:
		_failures.append("e2e draw: slot0 honey overlay not visible after reveal with effects")
	_assert_canvas_in_row(hand_row, honey_overlay, "e2e draw honey overlay")
	hand_row.queue_free()


func _test_picker_bind_before_place_flow() -> void:
	var session := _make_cobbler_bat_wing_session()
	_simulate_bat_wing_played(session)
	session.begin_bat_wing_picker()
	var boom := _make_ingredient("boom_berry_2", 99, 2, 2)
	var preview: Dictionary = session.get_bat_wing_choice_preview(boom)
	if preview.get("effect_entries", []).is_empty():
		_failures.append("picker flow: preview effect_entries empty")
		return

	var slot_scene := load("res://scenes/ui/eyeball_puzzle_slot.tscn") as PackedScene
	var slot := slot_scene.instantiate()
	var host := Control.new()
	host.custom_minimum_size = Vector2(400, 500)
	host.size = Vector2(400, 500)
	add_child(host)
	host.add_child(slot)
	await get_tree().process_frame

	var card := _CardScene.instantiate() as IngredientCard
	card.bind_picker_card(boom)
	slot.place_card(card)
	card.apply_picker_preview(preview)
	await get_tree().process_frame

	if not card.is_picker_mode():
		_failures.append("picker flow: bind-before-place lost picker mode")
	var icons := _find_effect_node(card, "HandSlotEffectIcons") as Control
	if icons == null or not icons.visible or _visible_icon_children(icons) < 1:
		_failures.append("picker flow: bind-before-place did not show effect icons")
	host.queue_free()


func _test_bat_wing_picker_preview_icons() -> void:
	var session := _make_cobbler_bat_wing_session()
	_simulate_bat_wing_played(session)
	session.begin_bat_wing_picker()

	var boom := _make_ingredient("boom_berry_2", 99, 2, 2)
	var preview: Dictionary = session.get_bat_wing_choice_preview(boom)
	var effect_entries: Array = preview.get("effect_entries", [])
	if effect_entries.is_empty():
		_failures.append("e2e picker: preview effect_entries empty: %s" % str(preview))
		return
	var card := _mount_card()
	card.bind_picker_card(boom)
	card.apply_picker_preview(preview)
	if card.has_method("reapply_picker_effect_layout"):
		card.reapply_picker_effect_layout()
	await get_tree().process_frame

	var icons := _find_effect_node(card, "HandSlotEffectIcons") as Control
	if icons == null or not icons.visible:
		_failures.append("e2e picker: effect icons not visible")
		return
	if _visible_icon_children(icons) < 1:
		_failures.append("e2e picker: expected cobbler icon on choice card")
	var icon_rect: Rect2 = icons.get_global_rect()
	if icon_rect.size.y < 1.0 or icon_rect.size.x < 1.0:
		_failures.append("e2e picker: icon strip has zero size rect %s" % str(icon_rect))
	card.queue_free()


func _find_effect_node(card: IngredientCard, node_name: String) -> Node:
	var node := card.get_node_or_null(node_name)
	if node == null:
		node = card.get_node_or_null("VisualRoot/%s" % node_name)
	return node


func _assert_canvas_in_row(hand_row: PlayerHandRow, item: CanvasItem, label: String) -> void:
	if item == null:
		return
	var row_rect: Rect2 = hand_row.get_global_rect()
	var item_rect: Rect2 = item.get_global_rect()
	if item_rect.size.y < 1.0 or item_rect.size.x < 1.0:
		_failures.append("%s: zero-size global rect %s" % [label, str(item_rect)])
		return
	var expanded := row_rect.grow_individual(0.0, 96.0, 0.0, 16.0)
	if not expanded.intersects(item_rect):
		_failures.append(
			"%s: rect %s does not intersect hand row %s"
			% [label, str(item_rect), str(row_rect)]
		)


func _mount_card() -> IngredientCard:
	var root := Control.new()
	root.custom_minimum_size = Vector2(800, 600)
	root.size = Vector2(800, 600)
	add_child(root)
	var card := _CardScene.instantiate() as IngredientCard
	root.add_child(card)
	return card


func _visible_icon_children(icons: Control) -> int:
	var row := icons.get_node_or_null("IconRow")
	if row == null:
		return 0
	var count := 0
	for child in row.get_children():
		if child.visible:
			count += 1
	return count


func _make_cobbler_bat_wing_session() -> BrewSession:
	var cobbler := _make_ingredient(_IngredientEffects.COBBLER_ID, 1, 2, 0)
	var bat_wing := _make_ingredient(_IngredientEffects.BAT_WING_ID, 2, 0, 0)
	var filler := _make_ingredient("rat", 3, 1, 0)
	var bag: BagModel = BagModel.new()
	bag.set_master_bag([filler, _filler_copy(4), _filler_copy(5), _filler_copy(6)])

	var session: BrewSession = _BrewSession.new()
	session.start_brew(1, _neutral_aura(), bag)
	session._hand_phase = _BrewSession.HandPhase.PLAYING
	session._hand_slots = [cobbler, bat_wing, null, null, null]
	session._hand_start_slots = session._hand_slots.duplicate()
	session._play_slot_cursor = 0
	session._hand_locked_slots = {}
	session._last_hand_play_slot = -1
	session._last_hand_play_ingredient = null
	return session


func _filler_copy(copy: int) -> IngredientData:
	return _make_ingredient("rat", copy, 1, 0)


func _neutral_aura() -> AuraData:
	return AuraData.new("test", "Test", "", AuraData.Pool.NORMAL, 1, 0, 100, 100)


func _simulate_bat_wing_played(session: BrewSession) -> void:
	var cobbler: IngredientData = session._hand_start_slots[0]
	var bat_wing: IngredientData = session._hand_start_slots[1]
	session._apply_ingredient(cobbler, true, true, 0)
	session._hand_slots[0] = null
	session._play_slot_cursor = 1
	session._apply_ingredient(bat_wing, true, true, 1)
	session._hand_slots[1] = null
	session._play_slot_cursor = 2
	session._bat_wing_source_slot_index = 1


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
		print("PASS: effect UI e2e test")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		get_tree().quit(1)
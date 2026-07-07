class_name PlayerHandRow
extends Control

signal swap_requested(from_slot: int, to_slot: int)
signal selection_changed(slot_index: int)

const _CARD_SCENE := preload("res://scenes/ui/ingredient_card.tscn")
const _EFFECT_ICONS_SCENE := preload("res://scenes/ui/hand_slot_effect_icons.tscn")

const HAND_SLOT_COUNT := 5
const CARD_SCALE := 0.34
const CARD_BASE_SIZE := Vector2(300.0, 420.0)
const CARD_DISPLAY_SIZE := CARD_BASE_SIZE * CARD_SCALE
const SLOT_OVERLAP := 118.0
const DRAG_START_DISTANCE := 8.0
const HOVER_Z_BOOST := 20
const HAND_HOVER_RISE := 28.0
const HAND_HOVER_SCALE := 1.12
const HAND_HOVER_PAD_BOTTOM := 16.0
const MIDDLE_SLOT_INDEX := 2
const PLAY_BUTTON_GAP := 12.0
const RHYTHM_SHAKE_OFFSET := Vector2(5.0, 2.0)
const RHYTHM_SHAKE_STEP := 0.07
const SLOT_TOP_MARGIN := 26.0
const EFFECT_STRIP_GAP := 2.0

@onready var _slot_row: Control = $SlotRow
@onready var _drag_layer: Control = $DragLayer

var _slot_cards: Array[IngredientCard] = []
var _slot_anchors: Array[Control] = []
var _slot_effect_icons: Array[HandSlotEffectIcons] = []
var _dragging_card: IngredientCard = null
var _drag_source_slot: int = -1
var _drag_grab_offset: Vector2 = Vector2.ZERO
var _interaction_enabled: bool = false
var _swap_enabled: bool = false
var _hover_slot: int = -1
var _press_slot: int = -1
var _press_position: Vector2 = Vector2.INF
var _drag_started: bool = false
var _selected_slot: int = -1
var _suppressed_slots: Dictionary = {}
var _anchor_rest_positions: Array[Vector2] = []
var _rhythm_shake_slot_tweens: Dictionary = {}
var _active_rhythm_shake_slots: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slots()
	set_process(false)
	set_process_input(false)


func _build_slots() -> void:
	_slot_cards.clear()
	_slot_anchors.clear()
	_slot_effect_icons.clear()
	if _slot_row == null:
		return

	for child in _slot_row.get_children():
		child.queue_free()

	var total_width := CARD_DISPLAY_SIZE.x + SLOT_OVERLAP * float(HAND_SLOT_COUNT - 1)
	var start_x := (size.x - total_width) * 0.5

	for slot_index in HAND_SLOT_COUNT:
		var anchor := Control.new()
		anchor.name = "SlotAnchor%d" % (slot_index + 1)
		anchor.custom_minimum_size = CARD_DISPLAY_SIZE
		anchor.size = CARD_DISPLAY_SIZE
		anchor.position = Vector2(start_x + SLOT_OVERLAP * slot_index, 0.0)
		anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_row.add_child(anchor)
		_slot_anchors.append(anchor)

		var effect_icons := _EFFECT_ICONS_SCENE.instantiate() as HandSlotEffectIcons
		if effect_icons != null:
			effect_icons.name = "SlotEffects%d" % (slot_index + 1)
			effect_icons.visible = false
			effect_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
			anchor.add_child(effect_icons)
			_slot_effect_icons.append(effect_icons)

		var card := _CARD_SCENE.instantiate() as IngredientCard
		if card == null:
			continue
		card.name = "HandCard%d" % (slot_index + 1)
		card.visible = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor.add_child(card)
		_slot_cards.append(card)


func get_selected_slot() -> int:
	return _selected_slot


func get_current_hand_slots() -> Array:
	var slots: Array = []
	for _slot_index in HAND_SLOT_COUNT:
		slots.append(null)
	for slot_index in _slot_cards.size():
		var card := _slot_cards[slot_index]
		if card == null or not card.visible:
			continue
		slots[slot_index] = card.get_ingredient()
	return slots


func clear_selection() -> void:
	_set_selected_slot(-1)


func prepare_for_draw(persisted_slots: Array = []) -> void:
	_interaction_enabled = false
	_suppressed_slots.clear()
	_stop_all_rhythm_shakes()
	_set_selected_slot(-1)
	_cancel_drag()
	_press_slot = -1
	_press_position = Vector2.INF
	for slot_index in HAND_SLOT_COUNT:
		var card := _slot_cards[slot_index]
		if card == null:
			continue
		var persisted_ingredient = null
		if slot_index < persisted_slots.size():
			persisted_ingredient = persisted_slots[slot_index]
		if persisted_ingredient != null:
			continue
		card.visible = false
		card.clear_hand_card()
		_clear_slot_effect_icons(slot_index)
	_update_hover_process()


func get_play_button_global_position(button_size: Vector2) -> Vector2:
	if MIDDLE_SLOT_INDEX < 0 or MIDDLE_SLOT_INDEX >= _slot_anchors.size():
		return global_position
	var anchor := _slot_anchors[MIDDLE_SLOT_INDEX]
	if anchor == null:
		return global_position
	var anchor_rect := anchor.get_global_rect()
	return Vector2(
		anchor_rect.get_center().x - button_size.x * 0.5,
		anchor_rect.position.y - PLAY_BUTTON_GAP - button_size.y
	)


func refresh_hand(
	slots: Array,
	interaction_enabled: bool,
	swap_enabled: bool = true,
	in_rhythm_shake_slots: Array = [],
	hand_display_stats: Array = [],
	slot_effect_entries: Array = []
) -> void:
	_interaction_enabled = interaction_enabled
	_swap_enabled = swap_enabled and interaction_enabled
	_cancel_drag()
	var click_in_progress := (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _press_slot >= 0
	)
	var saved_press_slot := _press_slot
	var saved_press_position := _press_position
	if not click_in_progress:
		_press_slot = -1
		_press_position = Vector2.INF
	for slot_index in HAND_SLOT_COUNT:
		var ingredient = slots[slot_index] if slot_index < slots.size() else null
		var display_stats = (
			hand_display_stats[slot_index]
			if slot_index < hand_display_stats.size()
			else null
		)
		_bind_slot(slot_index, ingredient, display_stats)
		var effect_entries = (
			slot_effect_entries[slot_index]
			if slot_index < slot_effect_entries.size()
			else []
		)
		_bind_slot_effect_icons(slot_index, effect_entries)
	if (
		_selected_slot >= 0
		and (
			_selected_slot >= slots.size()
			or slots[_selected_slot] == null
		)
	):
		_set_selected_slot(-1)
	else:
		_apply_selection_visuals()
	if click_in_progress:
		_press_slot = saved_press_slot
		_press_position = saved_press_position
	_layout_slots()
	_update_hover_process()
	set_in_rhythm_shake_slots(in_rhythm_shake_slots)


func get_slot_global_center(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= _slot_anchors.size():
		return global_position
	var anchor := _slot_anchors[slot_index]
	if anchor == null:
		return global_position
	return anchor.get_global_rect().get_center()


func get_slot_fly_data(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return {}
	var card := _slot_cards[slot_index]
	if card == null or not card.visible:
		return {"start_center": get_slot_global_center(slot_index)}
	if card.has_method("capture_fly_data"):
		var data := card.capture_fly_data()
		if not data.is_empty():
			return data
	return {"start_center": get_slot_global_center(slot_index)}


func hide_slot_for_fly(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card != null:
		card.visible = false
	_clear_slot_effect_icons(slot_index)


func suppress_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HAND_SLOT_COUNT:
		return
	_suppressed_slots[slot_index] = true
	hide_slot_for_fly(slot_index)


func is_slot_suppressed(slot_index: int) -> bool:
	return _suppressed_slots.has(slot_index)


func reveal_slot(
	slot_index: int,
	ingredient: IngredientData,
	display_stats: Variant = null
) -> void:
	_suppressed_slots.erase(slot_index)
	_bind_slot(slot_index, ingredient, display_stats)


func _bind_slot(slot_index: int, ingredient: IngredientData, display_stats: Variant = null) -> void:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card == null:
		return
	if ingredient == null:
		card.visible = false
		card.clear_hand_card()
		_clear_slot_effect_icons(slot_index)
		return
	if display_stats is Dictionary:
		card.bind_hand_card(
			ingredient,
			slot_index,
			false,
			int(display_stats.get("point_value", ingredient.point_value)),
			int(display_stats.get("explosive_value", ingredient.explosive_value))
		)
	else:
		card.bind_hand_card(ingredient, slot_index, false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = not _suppressed_slots.has(slot_index)
	_apply_slot_z_index(slot_index)


func set_in_rhythm_shake_slots(slot_indices: Array) -> void:
	_active_rhythm_shake_slots = slot_indices.duplicate()
	var active_slots: Dictionary = {}
	for slot_index in _active_rhythm_shake_slots:
		active_slots[int(slot_index)] = true

	for slot_index in HAND_SLOT_COUNT:
		if active_slots.has(slot_index) and _slot_has_visible_card(slot_index):
			_ensure_rhythm_shake(slot_index)
		else:
			_stop_rhythm_shake(slot_index)


func _slot_has_visible_card(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return false
	var card := _slot_cards[slot_index]
	return card != null and card.visible


func _ensure_rhythm_shake(slot_index: int) -> void:
	var tween: Tween = _rhythm_shake_slot_tweens.get(slot_index)
	if tween != null and tween.is_valid():
		return
	_start_rhythm_shake(slot_index)


func _start_rhythm_shake(slot_index: int) -> void:
	_stop_rhythm_shake(slot_index)
	if slot_index < 0 or slot_index >= _slot_anchors.size():
		return
	var anchor := _slot_anchors[slot_index]
	if anchor == null:
		return

	var rest := _anchor_rest_position(slot_index)
	anchor.position = rest
	var shake_tween := create_tween().set_loops()
	shake_tween.tween_property(
		anchor,
		"position",
		rest + Vector2(RHYTHM_SHAKE_OFFSET.x, 0.0),
		RHYTHM_SHAKE_STEP
	)
	shake_tween.tween_property(
		anchor,
		"position",
		rest + Vector2(-RHYTHM_SHAKE_OFFSET.x, RHYTHM_SHAKE_OFFSET.y),
		RHYTHM_SHAKE_STEP
	)
	shake_tween.tween_property(
		anchor,
		"position",
		rest + Vector2(0.0, -RHYTHM_SHAKE_OFFSET.y),
		RHYTHM_SHAKE_STEP
	)
	shake_tween.tween_property(anchor, "position", rest, RHYTHM_SHAKE_STEP)
	_rhythm_shake_slot_tweens[slot_index] = shake_tween


func _stop_rhythm_shake(slot_index: int) -> void:
	var tween: Tween = _rhythm_shake_slot_tweens.get(slot_index)
	if tween != null and tween.is_valid():
		tween.kill()
	_rhythm_shake_slot_tweens.erase(slot_index)
	if slot_index < 0 or slot_index >= _slot_anchors.size():
		return
	var anchor := _slot_anchors[slot_index]
	if anchor != null:
		anchor.position = _anchor_rest_position(slot_index)


func _stop_all_rhythm_shakes() -> void:
	for slot_index in _rhythm_shake_slot_tweens.keys():
		_stop_rhythm_shake(int(slot_index))


func _anchor_rest_position(slot_index: int) -> Vector2:
	if slot_index >= 0 and slot_index < _anchor_rest_positions.size():
		return _anchor_rest_positions[slot_index]
	return Vector2.ZERO


func _layout_slots() -> void:
	if _slot_row == null:
		return
	var total_width := CARD_DISPLAY_SIZE.x + SLOT_OVERLAP * float(HAND_SLOT_COUNT - 1)
	var start_x := (size.x - total_width) * 0.5
	_anchor_rest_positions.clear()
	for slot_index in _slot_anchors.size():
		var anchor := _slot_anchors[slot_index]
		if anchor == null:
			continue
		var rest := Vector2(start_x + SLOT_OVERLAP * slot_index, SLOT_TOP_MARGIN)
		anchor.position = rest
		_anchor_rest_positions.append(rest)
		_update_slot_effect_icon_position(slot_index)
		_apply_slot_z_index(slot_index)


func _apply_slot_z_index(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card == null or not card.visible:
		if slot_index < _slot_effect_icons.size():
			var hidden_strip := _slot_effect_icons[slot_index]
			if hidden_strip != null:
				hidden_strip.z_index = slot_index
		return
	var card_z := slot_index
	if _selected_slot == slot_index:
		card_z = HAND_SLOT_COUNT + HOVER_Z_BOOST + slot_index + 10
	elif _hover_slot == slot_index:
		card_z = HAND_SLOT_COUNT + HOVER_Z_BOOST + slot_index
	card.z_index = card_z
	if slot_index < _slot_effect_icons.size():
		var strip := _slot_effect_icons[slot_index]
		if strip != null and strip.visible:
			strip.z_index = card_z + 1


func _update_hover_process() -> void:
	set_process(_interaction_enabled)
	set_process_input(_interaction_enabled)


func _process(delta: float) -> void:
	if _dragging_card != null:
		_dragging_card.global_position = _mouse_global_position() + _drag_grab_offset
		if _dragging_card.has_method("update_hand_hover"):
			_dragging_card.update_hand_hover(true, delta)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_card_drag()
			return
		_update_hand_hover_states(delta)
		return

	_update_hand_hover_states(delta)


func _update_hand_hover_states(delta: float) -> void:
	var exclude_slot := _drag_source_slot if _dragging_card != null else -1
	var mouse_point := _mouse_global_position()
	var hovered_slot := (
		_topmost_slot_at(mouse_point, exclude_slot) if _interaction_enabled else -1
	)
	if hovered_slot != _hover_slot:
		var previous := _hover_slot
		_hover_slot = hovered_slot
		if previous >= 0:
			_apply_slot_z_index(previous)
		if _hover_slot >= 0:
			_apply_slot_z_index(_hover_slot)
		if _selected_slot >= 0:
			_apply_slot_z_index(_selected_slot)

	for slot_index in _slot_cards.size():
		if _dragging_card != null and slot_index == _drag_source_slot:
			continue
		var card := _slot_cards[slot_index]
		if card == null or not card.visible:
			continue
		card.update_hand_hover(slot_index == _hover_slot, delta)
		_update_slot_effect_icon_position(slot_index)


func _gui_input(event: InputEvent) -> void:
	if not _interaction_enabled or _dragging_card != null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_slot = _topmost_slot_at(event.global_position)
			_press_position = event.global_position
			_drag_started = false
			accept_event()
		else:
			if not _drag_started:
				if _press_slot >= 0:
					if _press_slot == _selected_slot:
						_set_selected_slot(-1)
					else:
						_set_selected_slot(_press_slot)
				else:
					_set_selected_slot(-1)
			_press_slot = -1
			_press_position = Vector2.INF
			_drag_started = false
		return

	if event is InputEventMouseMotion and _press_slot >= 0 and _swap_enabled:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		if event.global_position.distance_to(_press_position) < DRAG_START_DISTANCE:
			return
		_drag_started = true
		_set_selected_slot(-1)
		_begin_drag_from_slot(_press_slot)
		_press_slot = -1
		_press_position = Vector2.INF
		accept_event()


func _input(event: InputEvent) -> void:
	if _dragging_card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_card_drag()
		get_viewport().set_input_as_handled()


func _begin_drag_from_slot(slot_index: int) -> void:
	if not _swap_enabled:
		return
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card == null or not card.visible:
		return

	_drag_source_slot = slot_index
	var global_pos := card.global_position
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	_drag_layer.add_child(card)
	card.global_position = global_pos
	card.z_index = 50
	_drag_grab_offset = global_pos - _mouse_global_position()
	_dragging_card = card
	_hover_slot = -1
	for other_slot in _slot_cards.size():
		if other_slot == slot_index:
			continue
		var slot_card := _slot_cards[other_slot]
		if slot_card == null:
			continue
		if slot_card.has_method("update_hand_hover"):
			slot_card.update_hand_hover(false, 1.0)
	_stop_rhythm_shake(slot_index)
	set_process(true)
	set_process_input(true)


func _finish_card_drag() -> void:
	if _dragging_card == null:
		return

	var card := _dragging_card
	var source_slot := _drag_source_slot
	var target_slot := _best_slot_for_card(card)

	_return_card_to_slot(card, source_slot)
	card.z_index = source_slot
	_dragging_card = null
	_drag_source_slot = -1
	_press_slot = -1
	_press_position = Vector2.INF
	set_process_input(_interaction_enabled)

	if target_slot >= 0 and target_slot != source_slot:
		swap_requested.emit(source_slot, target_slot)

	_update_hover_process()
	set_in_rhythm_shake_slots(_active_rhythm_shake_slots)


func _return_card_to_slot(card: IngredientCard, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_anchors.size():
		card.queue_free()
		return
	var anchor := _slot_anchors[slot_index]
	if anchor == null:
		card.queue_free()
		return
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	anchor.add_child(card)
	card.position = Vector2.ZERO
	if slot_index < _slot_cards.size():
		_slot_cards[slot_index] = card


func _slot_hover_hit_rect(slot_index: int, card: IngredientCard) -> Rect2:
	if card == null:
		return Rect2()

	var hit_rect := (
		card.get_hand_hit_rect() if card.has_method("get_hand_hit_rect") else card.get_global_rect()
	)
	if slot_index >= 0 and slot_index < _slot_anchors.size():
		var anchor := _slot_anchors[slot_index]
		if anchor != null:
			hit_rect = hit_rect.merge(anchor.get_global_rect())

	var pad_top := HAND_HOVER_RISE * CARD_SCALE * HAND_HOVER_SCALE
	hit_rect.position.y -= pad_top
	hit_rect.size.y += pad_top + HAND_HOVER_PAD_BOTTOM
	return hit_rect


func _topmost_slot_at(global_point: Vector2, exclude_slot: int = -1) -> int:
	var best_slot := -1
	var best_z := -1

	for slot_index in HAND_SLOT_COUNT:
		if slot_index == exclude_slot:
			continue
		if slot_index >= _slot_cards.size():
			continue
		var card := _slot_cards[slot_index]
		if card == null or not card.visible:
			continue
		if _dragging_card != null and slot_index == _drag_source_slot:
			continue
		var hit_rect := _slot_hover_hit_rect(slot_index, card)
		if not hit_rect.has_point(global_point):
			continue
		var card_z := card.z_index
		if card_z > best_z or (card_z == best_z and slot_index > best_slot):
			best_z = card_z
			best_slot = slot_index

	return best_slot


func _best_slot_for_card(card: IngredientCard) -> int:
	if card == null:
		return -1

	var card_rect := card.get_global_rect()
	var card_center := card_rect.get_center()
	var mouse_point := _mouse_global_position()

	var best_slot := -1
	var best_score := -1.0

	for slot_index in _slot_anchors.size():
		var anchor := _slot_anchors[slot_index]
		if anchor == null:
			continue
		var zone := anchor.get_global_rect()
		var score := -1.0
		if zone.has_point(card_center):
			score = 100000.0 - card_center.distance_squared_to(zone.get_center())
		elif zone.has_point(mouse_point):
			score = 50000.0 - mouse_point.distance_squared_to(zone.get_center())
		else:
			var overlap := card_rect.intersection(zone)
			if overlap.size.x > 0.0 and overlap.size.y > 0.0:
				score = overlap.size.x * overlap.size.y
		if score > best_score:
			best_score = score
			best_slot = slot_index

	if best_slot < 0:
		var nearest_dist := 220.0 * 220.0
		for slot_index in _slot_anchors.size():
			var anchor := _slot_anchors[slot_index]
			if anchor == null:
				continue
			var dist := card_center.distance_squared_to(anchor.get_global_rect().get_center())
			if dist < nearest_dist:
				nearest_dist = dist
				best_slot = slot_index

	return best_slot


func _cancel_drag() -> void:
	if _dragging_card == null:
		_press_slot = -1
		_press_position = Vector2.INF
		return
	_return_card_to_slot(_dragging_card, _drag_source_slot)
	_dragging_card.z_index = _drag_source_slot
	_dragging_card = null
	_drag_source_slot = -1
	_press_slot = -1
	_press_position = Vector2.INF
	set_process_input(_interaction_enabled)
	_update_hover_process()


func _set_selected_slot(slot_index: int) -> void:
	if _selected_slot == slot_index:
		_apply_selection_visuals()
		return
	_selected_slot = slot_index
	_apply_selection_visuals()
	selection_changed.emit(_selected_slot)


func _apply_selection_visuals() -> void:
	for slot_index in _slot_cards.size():
		var card := _slot_cards[slot_index]
		if card == null:
			continue
		if card.has_method("set_hand_selected"):
			card.set_hand_selected(slot_index == _selected_slot)
		_apply_slot_z_index(slot_index)
		_update_slot_effect_icon_position(slot_index)


func _mouse_global_position() -> Vector2:
	return get_global_mouse_position()


func _bind_slot_effect_icons(slot_index: int, entries: Variant) -> void:
	if slot_index < 0 or slot_index >= _slot_effect_icons.size():
		return
	var strip := _slot_effect_icons[slot_index]
	if strip == null:
		return
	if entries is Array and not entries.is_empty():
		strip.bind_entries(entries, _lookup_ingredient_for_effect_icon)
		_update_slot_effect_icon_position(slot_index)
	else:
		strip.clear_icons()


func _clear_slot_effect_icons(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_effect_icons.size():
		return
	var strip := _slot_effect_icons[slot_index]
	if strip != null:
		strip.clear_icons()


func _update_slot_effect_icon_position(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_effect_icons.size():
		return
	var strip := _slot_effect_icons[slot_index]
	if strip == null or not strip.visible:
		return
	var card := _slot_cards[slot_index] if slot_index < _slot_cards.size() else null
	var hover_offset := 0.0
	if card != null and card.visible and card.has_method("get_hand_effect_icon_y_offset"):
		hover_offset = card.get_hand_effect_icon_y_offset()
	var strip_size := strip.size
	if strip_size == Vector2.ZERO:
		strip_size = strip.custom_minimum_size
	strip.position = Vector2(
		(CARD_DISPLAY_SIZE.x - strip_size.x) * 0.5,
		-strip_size.y - EFFECT_STRIP_GAP + hover_offset
	)


func _lookup_ingredient_for_effect_icon(ingredient_id: String) -> IngredientData:
	if GameManager.run == null:
		return null
	return GameManager.run.find_ingredient(ingredient_id)

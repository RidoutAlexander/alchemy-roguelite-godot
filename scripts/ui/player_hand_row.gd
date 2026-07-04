class_name PlayerHandRow
extends Control

signal swap_requested(from_slot: int, to_slot: int)
signal selection_changed(slot_index: int)

const _CARD_SCENE := preload("res://scenes/ui/ingredient_card.tscn")

const HAND_SLOT_COUNT := 5
const CARD_SCALE := 0.34
const CARD_BASE_SIZE := Vector2(300.0, 420.0)
const CARD_DISPLAY_SIZE := CARD_BASE_SIZE * CARD_SCALE
const SLOT_OVERLAP := 118.0
const DRAG_START_DISTANCE := 8.0
const HOVER_Z_BOOST := 20
const HAND_HOVER_RISE := 28.0
const HAND_HOVER_SCALE := 1.12
const MIDDLE_SLOT_INDEX := 2
const PLAY_BUTTON_GAP := 12.0

@onready var _slot_row: Control = $SlotRow
@onready var _drag_layer: Control = $DragLayer

var _slot_cards: Array[IngredientCard] = []
var _slot_anchors: Array[Control] = []
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_slots()
	set_process(false)
	set_process_input(false)


func _build_slots() -> void:
	_slot_cards.clear()
	_slot_anchors.clear()
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


func clear_selection() -> void:
	_set_selected_slot(-1)


func prepare_for_draw() -> void:
	_interaction_enabled = false
	_suppressed_slots.clear()
	_set_selected_slot(-1)
	_cancel_drag()
	_press_slot = -1
	_press_position = Vector2.INF
	for slot_index in HAND_SLOT_COUNT:
		var card := _slot_cards[slot_index]
		if card == null:
			continue
		card.visible = false
		card.clear_hand_card()
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


func refresh_hand(slots: Array, interaction_enabled: bool, swap_enabled: bool = true) -> void:
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
		_bind_slot(slot_index, ingredient)
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


func suppress_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= HAND_SLOT_COUNT:
		return
	_suppressed_slots[slot_index] = true
	hide_slot_for_fly(slot_index)


func is_slot_suppressed(slot_index: int) -> bool:
	return _suppressed_slots.has(slot_index)


func reveal_slot(slot_index: int, ingredient: IngredientData) -> void:
	_suppressed_slots.erase(slot_index)
	_bind_slot(slot_index, ingredient)


func _bind_slot(slot_index: int, ingredient: IngredientData) -> void:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card == null:
		return
	if ingredient == null:
		card.visible = false
		card.clear_hand_card()
		return
	card.bind_hand_card(ingredient, slot_index, false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = not _suppressed_slots.has(slot_index)
	_apply_slot_z_index(slot_index)


func _layout_slots() -> void:
	if _slot_row == null:
		return
	var total_width := CARD_DISPLAY_SIZE.x + SLOT_OVERLAP * float(HAND_SLOT_COUNT - 1)
	var start_x := (size.x - total_width) * 0.5
	for slot_index in _slot_anchors.size():
		var anchor := _slot_anchors[slot_index]
		if anchor == null:
			continue
		anchor.position = Vector2(start_x + SLOT_OVERLAP * slot_index, 0.0)
		_apply_slot_z_index(slot_index)


func _apply_slot_z_index(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_cards.size():
		return
	var card := _slot_cards[slot_index]
	if card == null or not card.visible:
		return
	if _selected_slot == slot_index:
		card.z_index = HAND_SLOT_COUNT + HOVER_Z_BOOST + slot_index + 10
	elif _hover_slot == slot_index and _dragging_card == null:
		card.z_index = HAND_SLOT_COUNT + HOVER_Z_BOOST + slot_index
	else:
		card.z_index = slot_index


func _update_hover_process() -> void:
	var should_process := _interaction_enabled and _dragging_card == null
	set_process(should_process)
	set_process_input(_interaction_enabled)


func _process(delta: float) -> void:
	if _dragging_card != null:
		_dragging_card.global_position = _mouse_global_position() + _drag_grab_offset
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_card_drag()
		return

	var mouse_point := _mouse_global_position()
	var hovered_slot := _topmost_slot_at(mouse_point) if _interaction_enabled else -1
	if _selected_slot >= 0:
		hovered_slot = -1
	if hovered_slot != _hover_slot:
		var previous := _hover_slot
		_hover_slot = hovered_slot
		if previous >= 0:
			_apply_slot_z_index(previous)
		if _hover_slot >= 0:
			_apply_slot_z_index(_hover_slot)

	for slot_index in _slot_cards.size():
		var card := _slot_cards[slot_index]
		if card == null or not card.visible:
			continue
		card.update_hand_hover(slot_index == _hover_slot or slot_index == _selected_slot, delta)


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


func _topmost_slot_at(global_point: Vector2) -> int:
	for slot_index in range(HAND_SLOT_COUNT - 1, -1, -1):
		if slot_index >= _slot_cards.size():
			continue
		var card := _slot_cards[slot_index]
		if card == null or not card.visible:
			continue
		if card.get_global_rect().has_point(global_point):
			return slot_index
	return -1


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


func _mouse_global_position() -> Vector2:
	return get_global_mouse_position()

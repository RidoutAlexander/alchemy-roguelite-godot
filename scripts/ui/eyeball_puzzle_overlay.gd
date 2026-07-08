class_name EyeballPuzzleOverlay
extends CanvasLayer

signal completed(ordered: Array)
signal picker_completed(selected: IngredientData)

const _CARD_SCENE := preload("res://scenes/ui/ingredient_card.tscn")

enum Mode { PUZZLE, PREVIEW, PICKER }

@onready var _dimmer: ColorRect = $Dimmer
@onready var _layout: CenterContainer = $Layout
@onready var _title_label: Label = $Layout/PanelOffset/Panel/Content/TitleRow/Title
@onready var _hint_label: Label = $Layout/PanelOffset/Panel/Content/HintLabel
@onready var _title_row: HBoxContainer = $Layout/PanelOffset/Panel/Content/TitleRow
@onready var _picker_toggle_button: WoodenButton = (
	$Layout/PanelOffset/Panel/Content/TitleRow/PickerToggleButton
)
@onready var _order_slots_row: HBoxContainer = $Layout/PanelOffset/Panel/Content/OrderSlotsRow
@onready var _done_button: WoodenButton = $Layout/PanelOffset/Panel/Content/DoneButton
@onready var _reroll_row: HBoxContainer = $Layout/PanelOffset/Panel/Content/RerollRow
@onready var _reroll_button: ShopRerollButton = $Layout/PanelOffset/Panel/Content/RerollRow/RerollButton
@onready var _drag_layer: Control = $DragLayer

var _mode: Mode = Mode.PUZZLE
var _order_slots: Array[EyeballPuzzleSlot] = []
var _dragging_card: IngredientCard = null
var _drag_source_slot: EyeballPuzzleSlot = null
var _drag_source_slot_index: int = -1
var _drag_grab_offset: Vector2 = Vector2.ZERO
var _selected_picker_card: IngredientCard = null
var _picker_panel_hidden: bool = false
var _picker_toggle_saved_parent: Node = null
var _picker_toggle_saved_index: int = -1


func _ready() -> void:
	visible = false
	if _done_button != null:
		if not _done_button.pressed.is_connected(_on_done_pressed):
			_done_button.pressed.connect(_on_done_pressed)
		_done_button.custom_minimum_size = Vector2(280.0, 72.0)
		_done_button.size = _done_button.custom_minimum_size
		_done_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _reroll_button != null:
		if not _reroll_button.pressed.is_connected(_on_reroll_pressed):
			_reroll_button.pressed.connect(_on_reroll_pressed)
		_reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _picker_toggle_button != null:
		_picker_toggle_button.custom_minimum_size = Vector2(140.0, 56.0)
		_picker_toggle_button.size = _picker_toggle_button.custom_minimum_size
		if not _picker_toggle_button.pressed.is_connected(_on_picker_toggle_pressed):
			_picker_toggle_button.pressed.connect(_on_picker_toggle_pressed)
	if not GameManager.brew_updated.is_connected(_on_brew_updated):
		GameManager.brew_updated.connect(_on_brew_updated)
	_gather_slots()
	set_process(false)
	set_process_input(false)


func _gather_slots() -> void:
	_order_slots.clear()
	if _order_slots_row == null:
		return
	for child in _order_slots_row.get_children():
		if child is EyeballPuzzleSlot:
			_order_slots.append(child)


func show_preview(ingredients: Array) -> void:
	_mode = Mode.PREVIEW
	_reset_picker_chrome()
	_selected_picker_card = null
	if _done_button != null:
		_done_button.visible = true
		_done_button.disabled = false
	var preview_count := ingredients.size()
	match preview_count:
		0:
			_set_overlay_copy("No upcoming draws", "")
		1:
			_set_overlay_copy(
				"Next draw",
				"Press Done to continue"
			)
		2:
			_set_overlay_copy(
				"Next 2 draws",
				"Press Done to continue"
			)
		_:
			_set_overlay_copy(
				"Next 3 of 5 draws",
				"Press Done to continue"
			)
	_configure_slots_for_puzzle(preview_count)
	_populate_slots(ingredients, false)


func show_puzzle(ingredients: Array) -> void:
	_mode = Mode.PUZZLE
	_reset_picker_chrome()
	_selected_picker_card = null
	if _done_button != null:
		_done_button.visible = true
		_done_button.disabled = false
	var draw_count := ingredients.size()
	match draw_count:
		0:
			_set_overlay_copy("No draws left in bag", "")
		1:
			_set_overlay_copy(
				"Confirm the next draw",
				"Press Done to draw this ingredient next"
			)
		2:
			_set_overlay_copy(
				"Arrange the next 2 draws",
				"Drag cards between slots to set draw order"
			)
		_:
			_set_overlay_copy(
				"Arrange the next 3 draws",
				"Drag cards between slots to set draw order"
			)
	_configure_slots_for_puzzle(draw_count)
	_populate_slots(ingredients, false)


func show_picker(ingredients: Array) -> void:
	_mode = Mode.PICKER
	_picker_panel_hidden = false
	_selected_picker_card = null
	_set_overlay_copy(
		"Choose an ingredient",
		"Tap a card to select it, then tap again or press Done"
	)
	_configure_slots_for_picker(ingredients.size())
	_populate_slots(ingredients, false)
	_reset_picker_card_states()
	_ensure_picker_cards_interactive()
	call_deferred("_refresh_picker_choice_previews")
	if _done_button != null:
		_done_button.visible = true
		_done_button.disabled = true
	_refresh_reroll_button()
	_configure_picker_toggle_button()
	GameManager.clear_bat_wing_pick_preview()


func hide_puzzle() -> void:
	_cancel_drag()
	_selected_picker_card = null
	_mode = Mode.PUZZLE
	_reset_picker_chrome()
	if _done_button != null:
		_done_button.visible = true
	if _reroll_row != null:
		_reroll_row.visible = false
	visible = false
	_clear_cards()
	_reset_slot_visibility()
	GameManager.clear_bat_wing_pick_preview()


func _reset_picker_chrome() -> void:
	_picker_panel_hidden = false
	if _picker_toggle_button != null:
		_picker_toggle_button.visible = false
		_restore_picker_toggle_parent()
	if _layout != null:
		_layout.visible = true
	if _dimmer != null:
		_dimmer.visible = true


func _configure_picker_toggle_button() -> void:
	if _picker_toggle_button == null:
		return
	_restore_picker_toggle_parent()
	_picker_toggle_button.visible = true
	_picker_toggle_button.label_text = "Hide"
	_picker_toggle_button.disabled = false


func _on_picker_toggle_pressed() -> void:
	if _mode != Mode.PICKER or _picker_toggle_button == null:
		return
	if _picker_panel_hidden:
		_show_picker_panel()
	else:
		_hide_picker_panel()


func _hide_picker_panel() -> void:
	if _picker_panel_hidden:
		return
	_picker_panel_hidden = true
	_store_picker_toggle_position()
	_reparent_picker_toggle_to_overlay()
	if _layout != null:
		_layout.visible = false
	if _dimmer != null:
		_dimmer.visible = false
	_picker_toggle_button.label_text = "Show"
	_refresh_reroll_button()


func _show_picker_panel() -> void:
	if not _picker_panel_hidden:
		return
	_picker_panel_hidden = false
	if _layout != null:
		_layout.visible = true
	if _dimmer != null:
		_dimmer.visible = true
	_restore_picker_toggle_parent()
	_picker_toggle_button.label_text = "Hide"
	_refresh_reroll_button()


func _store_picker_toggle_position() -> void:
	if _picker_toggle_button == null:
		return
	_picker_toggle_saved_parent = _picker_toggle_button.get_parent()
	_picker_toggle_saved_index = _picker_toggle_button.get_index()


func _reparent_picker_toggle_to_overlay() -> void:
	if _picker_toggle_button == null:
		return
	var global_pos := _picker_toggle_button.global_position
	if _picker_toggle_button.get_parent() != self:
		_picker_toggle_button.get_parent().remove_child(_picker_toggle_button)
		add_child(_picker_toggle_button)
	_picker_toggle_button.global_position = global_pos
	_picker_toggle_button.z_index = 20


func _restore_picker_toggle_parent() -> void:
	if _picker_toggle_button == null or _picker_toggle_saved_parent == null:
		return
	if not is_instance_valid(_picker_toggle_saved_parent):
		_picker_toggle_saved_parent = _title_row
	var global_pos := _picker_toggle_button.global_position
	if _picker_toggle_button.get_parent() != _picker_toggle_saved_parent:
		_picker_toggle_button.get_parent().remove_child(_picker_toggle_button)
	_picker_toggle_saved_parent.add_child(_picker_toggle_button)
	_picker_toggle_saved_parent.move_child(
		_picker_toggle_button,
		clampi(_picker_toggle_saved_index, 0, _picker_toggle_saved_parent.get_child_count())
	)
	_picker_toggle_button.global_position = global_pos
	_picker_toggle_button.z_index = 0


func _set_overlay_copy(title: String, hint: String) -> void:
	if _title_label != null:
		_title_label.text = title
	if _hint_label != null:
		_hint_label.text = hint
		_hint_label.visible = not hint.is_empty()


func _configure_slots_for_puzzle(active_slot_count: int) -> void:
	for i in _order_slots.size():
		var slot := _order_slots[i]
		slot.visible = i < active_slot_count
		slot.set_number_visible(active_slot_count > 1)


func _configure_slots_for_picker(choice_count: int) -> void:
	for i in _order_slots.size():
		var slot := _order_slots[i]
		slot.visible = i < choice_count
		slot.set_number_visible(false)


func _reset_slot_visibility() -> void:
	for slot in _order_slots:
		slot.visible = true
		slot.set_number_visible(true)


func _populate_slots(ingredients: Array, enable_drag: bool) -> void:
	_clear_cards()
	_gather_slots()
	visible = true

	for i in ingredients.size():
		if i >= _order_slots.size():
			break
		var ingredient = ingredients[i]
		if ingredient == null:
			continue
		var card := _CARD_SCENE.instantiate() as IngredientCard
		if card == null:
			continue
		if enable_drag:
			_wire_puzzle_card(card)
		else:
			_wire_picker_card(card, ingredient)
		_order_slots[i].place_card(card)
		if enable_drag:
			card.bind_puzzle_card(ingredient)
		else:
			card.bind_picker_card(ingredient)
			_apply_picker_choice_preview(card, ingredient)


func _wire_puzzle_card(card: IngredientCard) -> void:
	if not card.puzzle_drag_began.is_connected(_on_puzzle_drag_began):
		card.puzzle_drag_began.connect(_on_puzzle_drag_began)


func _wire_picker_card(card: IngredientCard, ingredient: IngredientData) -> void:
	if not card.picker_card_pressed.is_connected(_on_picker_card_pressed):
		card.picker_card_pressed.connect(_on_picker_card_pressed)
	if not card.mouse_entered.is_connected(_on_picker_card_hovered):
		card.mouse_entered.connect(_on_picker_card_hovered.bind(ingredient))
	if not card.mouse_exited.is_connected(_on_picker_card_unhovered):
		card.mouse_exited.connect(_on_picker_card_unhovered)


func _on_picker_card_hovered(ingredient: IngredientData) -> void:
	if _mode != Mode.PICKER or ingredient == null:
		return
	GameManager.set_bat_wing_pick_preview(ingredient)


func _on_picker_card_unhovered() -> void:
	if _mode != Mode.PICKER:
		return
	if _selected_picker_card != null:
		var selected := _selected_picker_card.get_ingredient()
		if selected != null:
			GameManager.set_bat_wing_pick_preview(selected)
		return
	GameManager.clear_bat_wing_pick_preview()


func _apply_picker_choice_preview(card: IngredientCard, ingredient: IngredientData) -> void:
	if card == null or ingredient == null or GameManager.run == null:
		return
	var preview: Dictionary = GameManager.run.brew_session.get_bat_wing_choice_preview(
		ingredient
	)
	card.apply_picker_preview(preview)
	if card.has_method("reapply_picker_effect_layout"):
		card.reapply_picker_effect_layout()


func _refresh_picker_choice_previews() -> void:
	if _mode != Mode.PICKER or GameManager.run == null:
		return
	for slot in _order_slots:
		if not slot.visible:
			continue
		var card := slot.get_card()
		if card == null:
			continue
		_apply_picker_choice_preview(card, card.get_ingredient())


func _on_brew_updated(_ctx: BrewContext) -> void:
	if _mode != Mode.PICKER or not visible:
		return
	_refresh_picker_choice_previews()


func _reset_picker_card_states() -> void:
	for slot in _order_slots:
		if not slot.visible:
			continue
		var card := slot.get_card()
		if card == null:
			continue
		card.set_picker_selected(false)
		if card.has_method("sync_picker_input"):
			card.sync_picker_input()


func _on_picker_card_pressed(card: IngredientCard) -> void:
	if _mode != Mode.PICKER or card == null:
		return
	if card.get_ingredient() == null:
		return
	if _selected_picker_card == card:
		_confirm_picker_selection()
		return
	_set_picker_selection(card)


func _set_picker_selection(card: IngredientCard) -> void:
	if _selected_picker_card != null and _selected_picker_card != card:
		_selected_picker_card.set_picker_selected(false)
	_selected_picker_card = card
	card.set_picker_selected(true)
	var ingredient := card.get_ingredient()
	if ingredient != null:
		GameManager.set_bat_wing_pick_preview(ingredient)
	_update_done_button_state()


func _confirm_picker_selection() -> void:
	if _selected_picker_card == null:
		return
	var selected := _selected_picker_card.get_ingredient()
	if selected == null:
		return
	hide_puzzle()
	picker_completed.emit(selected)


func _update_done_button_state() -> void:
	if _done_button == null or _mode != Mode.PICKER:
		return
	_done_button.disabled = _selected_picker_card == null


func _refresh_reroll_button() -> void:
	if _reroll_row == null:
		return
	var show_reroll := _mode == Mode.PICKER and GameManager.can_reroll_bat_wing_choices()
	_reroll_row.visible = show_reroll and not _picker_panel_hidden
	if _reroll_button != null:
		_reroll_button.visible = show_reroll
		_reroll_button.disabled = not show_reroll


func _on_reroll_pressed() -> void:
	if _mode != Mode.PICKER:
		return
	_cancel_drag()
	if not GameManager.try_reroll_bat_wing_choices():
		if _reroll_button != null:
			_reroll_button.shake()
		return
	GameManager.notify_bag_display_changed()
	_refresh_picker_choices(GameManager.run.brew_session.get_bat_wing_choices())


func _refresh_picker_choices(ingredients: Array) -> void:
	if _mode != Mode.PICKER:
		return
	_selected_picker_card = null
	GameManager.clear_bat_wing_pick_preview()
	_configure_slots_for_picker(ingredients.size())
	_populate_slots(ingredients, false)
	_reset_picker_card_states()
	_ensure_picker_cards_interactive()
	call_deferred("_refresh_picker_choice_previews")
	if _done_button != null:
		_done_button.disabled = true
	_refresh_reroll_button()


func _ensure_picker_cards_interactive() -> void:
	if _mode != Mode.PICKER:
		return
	for slot in _order_slots:
		if not slot.visible:
			continue
		var card := slot.get_card()
		if card == null:
			continue
		if card.has_method("sync_picker_input"):
			card.sync_picker_input()


func _on_puzzle_drag_began(card: IngredientCard) -> void:
	if _dragging_card != null or card == null:
		return

	_drag_source_slot = _find_slot_for_card(card)
	_drag_source_slot_index = _order_slots.find(_drag_source_slot)
	var global_pos := card.global_position
	var parent := card.get_parent()
	if parent != null:
		parent.remove_child(card)

	_drag_layer.add_child(card)
	card.global_position = global_pos
	card.z_index = 50
	_drag_grab_offset = global_pos - _mouse_global_position()
	_dragging_card = card
	set_process(true)
	set_process_input(true)


func _process(_delta: float) -> void:
	if _dragging_card == null:
		return
	_dragging_card.global_position = _mouse_global_position() + _drag_grab_offset
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_card_drag()


func _input(event: InputEvent) -> void:
	if _dragging_card == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_card_drag()
		get_viewport().set_input_as_handled()


func _finish_card_drag() -> void:
	if _dragging_card == null:
		return

	var card := _dragging_card
	var source_slot := _resolve_drag_source_slot()
	var target_slot := _best_slot_for_card(card)
	if target_slot != null:
		target_slot.place_card(card, source_slot)
	elif source_slot != null:
		source_slot.place_card(card)

	card.z_index = 0
	_dragging_card = null
	_drag_source_slot = null
	_drag_source_slot_index = -1
	set_process(false)
	set_process_input(false)


func _cancel_drag() -> void:
	if _dragging_card == null:
		return
	if _drag_source_slot != null:
		_drag_source_slot.place_card(_dragging_card)
	else:
		_dragging_card.queue_free()
	_dragging_card.z_index = 0
	_dragging_card = null
	_drag_source_slot = null
	_drag_source_slot_index = -1
	set_process(false)
	set_process_input(false)


func _mouse_global_position() -> Vector2:
	return _drag_layer.get_global_mouse_position()


func _resolve_drag_source_slot() -> EyeballPuzzleSlot:
	if _drag_source_slot != null:
		return _drag_source_slot
	if _drag_source_slot_index >= 0 and _drag_source_slot_index < _order_slots.size():
		return _order_slots[_drag_source_slot_index]
	return null


func _find_slot_for_card(card: IngredientCard) -> EyeballPuzzleSlot:
	for slot in _order_slots:
		if slot.get_card() == card:
			return slot
	return null


func _best_slot_for_card(card: IngredientCard) -> EyeballPuzzleSlot:
	if card == null:
		return null

	var card_rect := card.get_global_rect()
	var card_center := card_rect.get_center()
	var mouse_point := _mouse_global_position()

	var best_slot: EyeballPuzzleSlot = null
	var best_score := -1.0

	for slot in _order_slots:
		var zone := slot.get_drop_global_rect()
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
			best_slot = slot

	if best_slot == null:
		var nearest_slot: EyeballPuzzleSlot = null
		var nearest_dist := 220.0 * 220.0
		for slot in _order_slots:
			var dist := card_center.distance_squared_to(slot.get_drop_global_rect().get_center())
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_slot = slot
		best_slot = nearest_slot

	return best_slot


func _clear_cards() -> void:
	for slot in _order_slots:
		slot.clear_hosted_card()


func _on_done_pressed() -> void:
	if _mode == Mode.PREVIEW:
		hide_puzzle()
		completed.emit([])
		return
	if _mode == Mode.PICKER:
		_confirm_picker_selection()
		return

	var ordered: Array[IngredientData] = []
	for slot in _order_slots:
		if not slot.visible:
			continue
		var card := slot.get_card()
		if card == null or card.get_ingredient() == null:
			return
		ordered.append(card.get_ingredient())
	if ordered.is_empty():
		return
	hide_puzzle()
	completed.emit(ordered)

class_name EyeballPuzzleSlot
extends VBoxContainer

signal card_dropped(card: IngredientCard)

@export var slot_number: int = 1

@onready var _number_label: Label = $NumberOffset/NumberLabel
@onready var _drop_zone: PanelContainer = $DropZone
@onready var _card_host: Control = $DropZone/CardHost


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	if _number_label != null:
		_number_label.text = str(slot_number)
		_number_label.visible = slot_number > 0
	if _drop_zone != null:
		_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.1, 0.11, 0.16, 0.95)
		frame.border_color = Color(0.92, 0.78, 0.42, 0.9)
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(10)
		frame.set_content_margin_all(6)
		_drop_zone.add_theme_stylebox_override("panel", frame)
	_apply_host_size()


func _apply_host_size() -> void:
	if _card_host == null:
		return
	var display_size := EyeballPuzzleLayout.card_display_size()
	_card_host.custom_minimum_size = display_size
	_card_host.size = display_size
	if _drop_zone != null:
		_drop_zone.custom_minimum_size = display_size + Vector2(12.0, 12.0)
	custom_minimum_size.x = display_size.x + 16.0


func set_number_visible(show_number: bool) -> void:
	if _number_label != null:
		_number_label.visible = show_number


func get_drop_global_rect() -> Rect2:
	var display_size := EyeballPuzzleLayout.card_display_size()
	var pad := Vector2(48.0, 56.0)
	if _drop_zone != null:
		var zone := _drop_zone.get_global_rect()
		if zone.size.x > 8.0 and zone.size.y > 8.0:
			return zone.grow_individual(pad.x, pad.y, pad.x, pad.y)
	var anchor := get_global_rect().get_center() + Vector2(0.0, 24.0)
	return Rect2(anchor - display_size * 0.5 - pad, display_size + pad * 2.0)


func get_card() -> IngredientCard:
	if _card_host == null:
		return null
	for child in _card_host.get_children():
		if child is IngredientCard and not child.is_queued_for_deletion():
			return child
	return null


func clear_hosted_card() -> void:
	var card := get_card()
	if card == null:
		return
	_detach_card(card)
	card.queue_free()


func place_card(card: IngredientCard, swap_to_slot: EyeballPuzzleSlot = null) -> void:
	if card == null or _card_host == null:
		return

	var occupant := get_card()
	_detach_card(card)

	if occupant != null and occupant != card:
		var return_slot := swap_to_slot
		if return_slot == self:
			return_slot = null
		if return_slot == null:
			return_slot = _find_empty_slot_excluding_self()
		if return_slot != null:
			return_slot._attach_card(occupant)
		else:
			_attach_card(occupant)
			return

	_attach_card(card)
	if card.has_method("is_picker_mode") and card.is_picker_mode():
		if card.has_method("reapply_picker_effect_layout"):
			card.reapply_picker_effect_layout()
	card_dropped.emit(card)


func _detach_card(card: IngredientCard) -> void:
	if card == null or card.get_parent() == null:
		return
	card.get_parent().remove_child(card)


func _find_empty_slot_excluding_self() -> EyeballPuzzleSlot:
	var parent_row := get_parent()
	if parent_row == null:
		return null
	for child in parent_row.get_children():
		if child == self or not child is EyeballPuzzleSlot:
			continue
		var slot := child as EyeballPuzzleSlot
		if slot.get_card() == null:
			return slot
	return null


func _attach_card(card: IngredientCard) -> void:
	if card == null or _card_host == null:
		return
	_detach_card(card)
	_card_host.add_child(card)
	EyeballPuzzleLayout.configure_card(card)
	card.position = Vector2.ZERO
	card.visible = true
	if card.has_method("is_picker_mode") and card.is_picker_mode():
		if card.has_method("sync_picker_input"):
			card.sync_picker_input()
	elif card.has_method("set_puzzle_drag_enabled"):
		card.set_puzzle_drag_enabled(true)
	card.z_index = 0
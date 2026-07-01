class_name BagContentsOverlay
extends Control

const _SLOT_SCENE := preload("res://scenes/ui/bag_inventory_slot.tscn")
const PREVIEW_SCALE := 0.38
const GRID_COLUMNS := 5

@onready var _input_blocker: ColorRect = $InputBlocker
@onready var _empty_label: Label = $Panel/Content/EmptyLabel
@onready var _scroll: ScrollContainer = $Panel/Content/Scroll
@onready var _grid: GridContainer = $Panel/Content/Scroll/Grid
@onready var _preview_layer: CanvasLayer = $PreviewLayer
@onready var _preview_card: IngredientCard = $PreviewLayer/PreviewCard

var _bag: BagModel
var _hovered_ingredient: IngredientData
var _preview_rest_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _input_blocker != null:
		_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	if _grid != null:
		_grid.columns = GRID_COLUMNS
	if _preview_layer != null:
		_preview_layer.visible = false
	if _preview_card != null:
		_preview_card.scale = Vector2.ONE * PREVIEW_SCALE
		_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_rest_position = _preview_card.position
	if _scroll != null:
		var vbar := _scroll.get_v_scroll_bar()
		if vbar != null and not vbar.value_changed.is_connected(_on_scroll_changed):
			vbar.value_changed.connect(_on_scroll_changed)
	set_process(false)
	_hide_preview()


func _process(_delta: float) -> void:
	if not visible or _grid == null:
		return

	var hovered_slot := _find_hovered_slot()
	if hovered_slot == null:
		_hide_preview()
		return

	var ingredient := hovered_slot.get_ingredient()
	if ingredient == null:
		_hide_preview()
		return

	var needs_bind := (
		not _preview_layer.visible
		or _hovered_ingredient == null
		or _hovered_ingredient.id != ingredient.id
	)
	_hovered_ingredient = ingredient

	if needs_bind:
		_preview_card.bind_preview(ingredient)
		_preview_layer.visible = true
		_preview_card.visible = true

	_align_preview_to_slot(hovered_slot)


func _find_hovered_slot() -> BagInventorySlot:
	var mouse_pos := get_global_mouse_position()
	for child in _grid.get_children():
		var slot := child as BagInventorySlot
		if slot != null and slot.get_global_rect().has_point(mouse_pos):
			return slot
	return null


func _align_preview_to_slot(slot: BagInventorySlot) -> void:
	if _preview_card == null or slot == null:
		return
	_preview_card.position = _preview_rest_position
	var slot_art_center := slot.get_art_center_global()
	var preview_art_center := _preview_card.get_art_global_center()
	_preview_card.global_position += slot_art_center - preview_art_center


func _on_scroll_changed(_value: float) -> void:
	_hovered_ingredient = null
	_hide_preview()


func is_open() -> bool:
	return visible


func toggle(bag: BagModel) -> void:
	if visible:
		hide_overlay()
	else:
		show_inventory(bag)


func show_inventory(bag: BagModel) -> void:
	_bag = bag
	_rebuild_grid()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _input_blocker != null:
		_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_hide_preview()


func hide_overlay() -> void:
	visible = false
	set_process(false)
	_hide_preview()


func refresh_if_open() -> void:
	if not visible or _bag == null:
		return
	_rebuild_grid()


func _rebuild_grid() -> void:
	if _grid == null:
		return
	_hovered_ingredient = null
	_hide_preview()
	for child in _grid.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = []
	if _bag != null:
		entries = _bag.get_master_inventory()

	var has_entries := not entries.is_empty()
	if _empty_label != null:
		_empty_label.visible = not has_entries
	if _scroll != null:
		_scroll.visible = has_entries

	for entry in entries:
		var ingredient: IngredientData = entry.get("ingredient")
		var count: int = int(entry.get("count", 0))
		if ingredient == null or count <= 0:
			continue
		var slot := _SLOT_SCENE.instantiate() as BagInventorySlot
		if slot == null:
			continue
		_grid.add_child(slot)
		slot.bind_entry(ingredient, count)


func _hide_preview() -> void:
	_hovered_ingredient = null
	if _preview_layer != null:
		_preview_layer.visible = false
	if _preview_card != null:
		_preview_card.visible = false
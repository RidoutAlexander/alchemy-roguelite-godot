class_name BagContentsOverlay
extends Control

signal overlay_closed

enum DisplayMode { BAG_STACKS, CAULDRON_SEQUENCE }

const _SLOT_SCENE := preload("res://scenes/ui/bag_inventory_slot.tscn")
const PREVIEW_SCALE := 0.38
const GRID_COLUMNS := 5

@onready var _input_blocker: ColorRect = $InputBlocker
@onready var _title_label: Label = $Panel/Content/Title
@onready var _empty_label: Label = $Panel/Content/EmptyLabel
@onready var _scroll: ScrollContainer = $Panel/Content/Scroll
@onready var _grid: GridContainer = $Panel/Content/Scroll/Grid
@onready var _preview_layer: CanvasLayer = $PreviewLayer
@onready var _preview_card: IngredientCard = $PreviewLayer/PreviewCard

var _mode: DisplayMode = DisplayMode.BAG_STACKS
var _bag: BagModel
var _cauldron_contents: Array = []
var _hovered_ingredient: IngredientData
var _preview_rest_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _input_blocker != null:
		_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _input_blocker.gui_input.is_connected(_on_blocker_gui_input):
			_input_blocker.gui_input.connect(_on_blocker_gui_input)
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


func _on_blocker_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			hide_overlay()


func is_open() -> bool:
	return visible


func toggle(bag: BagModel) -> void:
	if visible and _mode == DisplayMode.BAG_STACKS:
		hide_overlay()
	else:
		show_inventory(bag)


func toggle_cauldron(contents: Array) -> void:
	if visible and _mode == DisplayMode.CAULDRON_SEQUENCE:
		hide_overlay()
	else:
		show_cauldron_contents(contents)


func show_inventory(bag: BagModel) -> void:
	_mode = DisplayMode.BAG_STACKS
	_bag = bag
	_cauldron_contents.clear()
	_set_copy("Your Bag", "Your bag is empty.")
	_open()


func show_cauldron_contents(contents: Array) -> void:
	_mode = DisplayMode.CAULDRON_SEQUENCE
	_bag = null
	_cauldron_contents = contents.duplicate()
	_set_copy("Your Cauldron", "Your cauldron is empty.")
	_open()


func hide_overlay() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_hide_preview()
	overlay_closed.emit()


func refresh_if_open() -> void:
	if not visible:
		return
	_rebuild_grid()


func _open() -> void:
	_rebuild_grid()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_hide_preview()


func _set_copy(title: String, empty_message: String) -> void:
	if _title_label != null:
		_title_label.text = title
	if _empty_label != null:
		_empty_label.text = empty_message


func _rebuild_grid() -> void:
	if _grid == null:
		return
	_hovered_ingredient = null
	_hide_preview()
	for child in _grid.get_children():
		child.queue_free()

	match _mode:
		DisplayMode.BAG_STACKS:
			_rebuild_bag_grid()
		DisplayMode.CAULDRON_SEQUENCE:
			_rebuild_cauldron_grid()


func _rebuild_bag_grid() -> void:
	var entries: Array[Dictionary] = []
	if _bag != null:
		entries = _bag.get_master_inventory()

	var has_entries := not entries.is_empty()
	_set_scroll_visible(has_entries, not has_entries)

	for entry in entries:
		var ingredient: IngredientData = entry.get("ingredient")
		var count: int = int(entry.get("count", 0))
		if ingredient == null or count <= 0:
			continue
		_add_slot(ingredient, count, true)


func _rebuild_cauldron_grid() -> void:
	var has_entries := not _cauldron_contents.is_empty()
	_set_scroll_visible(has_entries, not has_entries)

	for i in range(_cauldron_contents.size() - 1, -1, -1):
		var ingredient = _cauldron_contents[i]
		if ingredient == null:
			continue
		_add_slot(ingredient, 1, false)


func _set_scroll_visible(show_scroll: bool, show_empty: bool) -> void:
	if _empty_label != null:
		_empty_label.visible = show_empty
	if _scroll != null:
		_scroll.visible = show_scroll


func _add_slot(ingredient: IngredientData, count: int, show_count: bool) -> void:
	var slot := _SLOT_SCENE.instantiate() as BagInventorySlot
	if slot == null:
		return
	_grid.add_child(slot)
	slot.bind_entry(ingredient, count, show_count)


func _hide_preview() -> void:
	_hovered_ingredient = null
	if _preview_layer != null:
		_preview_layer.visible = false
	if _preview_card != null:
		_preview_card.visible = false
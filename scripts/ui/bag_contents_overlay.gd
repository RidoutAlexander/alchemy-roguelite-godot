class_name BagContentsOverlay
extends Control

signal overlay_closed
signal dev_hand_picker_completed(selection: Array)
signal dev_trinket_picker_completed(trinket_ids: Array)

enum DisplayMode { BAG_STACKS, CAULDRON_SEQUENCE, DEV_HAND_PICKER, DEV_TRINKET_PICKER }

const DEV_HAND_PICK_COUNT := 5

const _SLOT_SCENE := preload("res://scenes/ui/bag_inventory_slot.tscn")
const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"
const PREVIEW_SCALE := 0.38
const GRID_COLUMNS := 5
const _PANEL_DEFAULT_ANCHOR_RIGHT := 0.58
const _PANEL_DEV_TRINKET_ANCHOR_LEFT := 0.22
const _PANEL_DEV_TRINKET_ANCHOR_RIGHT := 0.78

@onready var _input_blocker: ColorRect = $InputBlocker
@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Content/Title
@onready var _empty_label: Label = $Panel/Content/EmptyLabel
@onready var _scroll: ScrollContainer = $Panel/Content/Scroll
@onready var _grid: GridContainer = $Panel/Content/Scroll/Grid
@onready var _preview_layer: CanvasLayer = $PreviewLayer
@onready var _preview_card: IngredientCard = $PreviewLayer/PreviewCard
@onready var _count_overlay_layer: CanvasLayer = $CountOverlayLayer
@onready var _hover_count_label: Label = $CountOverlayLayer/HoverCountLabel
@onready var _footer: HBoxContainer = $Panel/Content/Footer
@onready var _selection_label: Label = $Panel/Content/Footer/SelectionLabel
@onready var _done_button: Button = $Panel/Content/Footer/DoneButton

var _mode: DisplayMode = DisplayMode.BAG_STACKS
var _bag: BagModel
var _cauldron_contents: Array = []
var _dev_catalog: Array[IngredientData] = []
var _dev_selection_counts: Dictionary = {}
var _dev_selection_order: Array[IngredientData] = []
var _dev_slot_by_id: Dictionary = {}
var _dev_trinket_catalog: Array[TrinketData] = []
var _dev_trinket_selection: Dictionary = {}
var _dev_trinket_slot_by_id: Dictionary = {}
var _hovered_ingredient: IngredientData
var _hovered_slot: BagInventorySlot
var _active_hover_rect: Rect2 = Rect2()
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
	if _count_overlay_layer != null:
		_count_overlay_layer.visible = false
	if _preview_card != null:
		_preview_card.scale = Vector2.ONE * PREVIEW_SCALE
		_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_rest_position = _preview_card.position
	if _scroll != null:
		var vbar := _scroll.get_v_scroll_bar()
		if vbar != null and not vbar.value_changed.is_connected(_on_scroll_changed):
			vbar.value_changed.connect(_on_scroll_changed)
	if _done_button != null and not _done_button.pressed.is_connected(_on_done_button_pressed):
		_done_button.pressed.connect(_on_done_button_pressed)
	_set_footer_visible(false)
	set_process(false)
	_hide_preview()


func _process(_delta: float) -> void:
	if not visible or _grid == null:
		return
	if _mode in [DisplayMode.DEV_HAND_PICKER, DisplayMode.DEV_TRINKET_PICKER]:
		return

	var hovered_slot := _find_hovered_slot()
	if hovered_slot == null:
		_hide_preview()
		return

	var ingredient := hovered_slot.get_ingredient()
	if ingredient == null:
		_hide_preview()
		return

	if _hovered_slot != null and _hovered_slot != hovered_slot:
		_hovered_slot.set_count_visible(true)

	var needs_bind := (
		not _preview_layer.visible
		or _hovered_ingredient == null
		or _hovered_ingredient.id != ingredient.id
		or _hovered_slot != hovered_slot
	)
	_hovered_ingredient = ingredient
	_hovered_slot = hovered_slot

	if needs_bind:
		_preview_card.bind_preview(ingredient)
		_preview_layer.visible = true
		_preview_card.visible = true

	_align_preview_to_slot(hovered_slot)
	_update_hover_count(hovered_slot)
	_update_active_hover_rect()


func _find_hovered_slot() -> BagInventorySlot:
	var mouse_pos := get_global_mouse_position()
	for child in _grid.get_children():
		var slot := child as BagInventorySlot
		if slot != null and slot.get_global_rect().has_point(mouse_pos):
			return slot
	if _is_mouse_over_active_hover(mouse_pos):
		return _hovered_slot
	return null


func _is_mouse_over_active_hover(mouse_pos: Vector2) -> bool:
	if _hovered_slot == null or _preview_layer == null or not _preview_layer.visible:
		return false
	if not _active_hover_rect.has_point(mouse_pos):
		return false
	return true


func _update_active_hover_rect() -> void:
	if _hovered_slot == null:
		_active_hover_rect = Rect2()
		return
	var hover_rect := _hovered_slot.get_global_rect()
	if _preview_card != null and _preview_card.visible:
		hover_rect = hover_rect.merge(_preview_card.get_global_rect())
	if _hover_count_label != null and _hover_count_label.visible:
		hover_rect = hover_rect.merge(_hover_count_label.get_global_rect())
	_active_hover_rect = hover_rect


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
	if _mode in [DisplayMode.DEV_HAND_PICKER, DisplayMode.DEV_TRINKET_PICKER]:
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
	_set_footer_visible(false)
	_open()


func show_cauldron_contents(contents: Array) -> void:
	_mode = DisplayMode.CAULDRON_SEQUENCE
	_bag = null
	_cauldron_contents = contents.duplicate()
	_set_copy("Your Cauldron", "Your cauldron is empty.")
	_set_footer_visible(false)
	_open()


func show_dev_hand_picker(ingredients: Array) -> void:
	_mode = DisplayMode.DEV_HAND_PICKER
	_bag = null
	_cauldron_contents.clear()
	_dev_catalog.clear()
	_dev_selection_counts.clear()
	_dev_selection_order.clear()
	_dev_slot_by_id.clear()
	for item in ingredients:
		if item is IngredientData:
			_dev_catalog.append(item)
	_dev_catalog.sort_custom(
		func(a: IngredientData, b: IngredientData) -> bool:
			return a.display_name < b.display_name
	)
	_set_copy("Developer Hand", "")
	_set_footer_visible(true)
	_update_dev_selection_ui()
	_open()


func show_dev_trinket_picker(trinkets: Array) -> void:
	_mode = DisplayMode.DEV_TRINKET_PICKER
	_bag = null
	_cauldron_contents.clear()
	_dev_catalog.clear()
	_dev_selection_counts.clear()
	_dev_selection_order.clear()
	_dev_slot_by_id.clear()
	_dev_trinket_catalog.clear()
	_dev_trinket_selection.clear()
	_dev_trinket_slot_by_id.clear()
	for item in trinkets:
		if item is TrinketData and _trinket_has_art(item):
			_dev_trinket_catalog.append(item)
	_dev_trinket_catalog.sort_custom(
		func(a: TrinketData, b: TrinketData) -> bool:
			return a.display_name < b.display_name
	)
	_set_copy("Developer Trinkets", "")
	_set_footer_visible(true)
	_update_dev_trinket_selection_ui()
	_open()


func hide_overlay() -> void:
	if not visible:
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_input(false)
	_configure_mode_input()
	_hide_preview()
	_clear_grid()
	_hide_canvas_layers()
	_set_footer_visible(false)
	_dev_catalog.clear()
	_dev_selection_counts.clear()
	_dev_selection_order.clear()
	_dev_slot_by_id.clear()
	_dev_trinket_catalog.clear()
	_dev_trinket_selection.clear()
	_dev_trinket_slot_by_id.clear()
	_restore_default_panel_layout()
	overlay_closed.emit()


func refresh_if_open() -> void:
	if not visible:
		return
	_rebuild_grid()


func _open() -> void:
	_apply_panel_layout_for_mode()
	_rebuild_grid()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_configure_mode_input()
	_hide_preview()


func _configure_mode_input() -> void:
	if _mode in [DisplayMode.DEV_HAND_PICKER, DisplayMode.DEV_TRINKET_PICKER]:
		if _input_blocker != null:
			_input_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _panel != null:
			_panel.z_index = 1
			_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		set_process_input(true)
	else:
		if _input_blocker != null:
			_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		if _panel != null:
			_panel.z_index = 0
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _mode == DisplayMode.DEV_HAND_PICKER:
		_handle_dev_hand_input(event)
	elif _mode == DisplayMode.DEV_TRINKET_PICKER:
		_handle_dev_trinket_input(event)


func _handle_dev_hand_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var mouse_pos := mouse_event.global_position
	if _is_dev_ui_control_at(mouse_pos):
		return

	var ingredient := _find_dev_ingredient_at(mouse_pos)
	if ingredient == null:
		return

	_on_dev_slot_gui_input(ingredient, event)
	get_viewport().set_input_as_handled()


func _handle_dev_trinket_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos := mouse_event.global_position
	if _is_dev_ui_control_at(mouse_pos):
		return

	var trinket := _find_dev_trinket_at(mouse_pos)
	if trinket == null:
		return

	_on_dev_trinket_slot_gui_input(trinket)
	get_viewport().set_input_as_handled()


func _is_dev_ui_control_at(mouse_pos: Vector2) -> bool:
	if _done_button != null and _done_button.visible:
		if _done_button.get_global_rect().has_point(mouse_pos):
			return true
	if _scroll != null:
		var vbar := _scroll.get_v_scroll_bar()
		if vbar != null and vbar.get_global_rect().has_point(mouse_pos):
			return true
	return false


func _find_dev_ingredient_at(mouse_pos: Vector2) -> IngredientData:
	if _grid == null:
		return null
	for child in _grid.get_children():
		var slot := child as BagInventorySlot
		if slot == null:
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			return slot.get_ingredient()
	return null


func _find_dev_trinket_at(mouse_pos: Vector2) -> TrinketData:
	if _grid == null:
		return null
	for child in _grid.get_children():
		var slot := child as BagInventorySlot
		if slot == null:
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			return slot.get_trinket()
	return null


func _set_copy(title: String, empty_message: String) -> void:
	if _title_label != null:
		_title_label.text = title
	if _empty_label != null:
		_empty_label.text = empty_message


func _rebuild_grid() -> void:
	if _grid == null:
		return
	_hovered_ingredient = null
	_hovered_slot = null
	_hide_preview()
	_clear_grid()

	match _mode:
		DisplayMode.BAG_STACKS:
			_rebuild_bag_grid()
		DisplayMode.CAULDRON_SEQUENCE:
			_rebuild_cauldron_grid()
		DisplayMode.DEV_HAND_PICKER:
			_rebuild_dev_hand_picker_grid()
		DisplayMode.DEV_TRINKET_PICKER:
			_rebuild_dev_trinket_picker_grid()


func _rebuild_bag_grid() -> void:
	if _grid != null:
		_grid.columns = GRID_COLUMNS
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
	if _grid != null:
		_grid.columns = GRID_COLUMNS
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


func _rebuild_dev_hand_picker_grid() -> void:
	if _grid != null:
		_grid.columns = GRID_COLUMNS
	var has_entries := not _dev_catalog.is_empty()
	_set_scroll_visible(has_entries, not has_entries)
	for ingredient in _dev_catalog:
		if ingredient == null:
			continue
		var selected_count := int(_dev_selection_counts.get(ingredient.id, 0))
		_add_slot(ingredient, selected_count, selected_count > 0, true)


func _rebuild_dev_trinket_picker_grid() -> void:
	if _grid != null:
		_grid.columns = GRID_COLUMNS
	var has_entries := not _dev_trinket_catalog.is_empty()
	_set_scroll_visible(has_entries, not has_entries)
	for trinket in _dev_trinket_catalog:
		if trinket == null:
			continue
		var selected := bool(_dev_trinket_selection.get(trinket.id, false))
		_add_trinket_slot(trinket, selected)


func _add_slot(
	ingredient: IngredientData,
	count: int,
	show_count: bool,
	interactive: bool = false
) -> void:
	var slot := _SLOT_SCENE.instantiate() as BagInventorySlot
	if slot == null:
		return
	_grid.add_child(slot)
	slot.bind_entry(ingredient, count, show_count)
	slot.set_interactive(false)
	if interactive:
		_dev_slot_by_id[ingredient.id] = slot


func _add_trinket_slot(trinket: TrinketData, selected: bool) -> void:
	var slot := _SLOT_SCENE.instantiate() as BagInventorySlot
	if slot == null or _grid == null:
		return
	_grid.add_child(slot)
	slot.bind_trinket(trinket, selected, selected)
	slot.set_interactive(false)
	_dev_trinket_slot_by_id[trinket.id] = slot


func _clear_grid() -> void:
	if _grid == null:
		return
	_dev_slot_by_id.clear()
	_dev_trinket_slot_by_id.clear()
	for child in _grid.get_children():
		child.queue_free()


func _hide_canvas_layers() -> void:
	if _preview_layer != null:
		_preview_layer.visible = false
	if _count_overlay_layer != null:
		_count_overlay_layer.visible = false
	if _preview_card != null:
		_preview_card.visible = false
		_preview_card.position = _preview_rest_position


func _update_hover_count(slot: BagInventorySlot) -> void:
	if _count_overlay_layer == null or _hover_count_label == null or slot == null:
		return
	if _mode != DisplayMode.BAG_STACKS:
		_hide_hover_count()
		return
	var count := slot.get_count()
	if count <= 0:
		_hide_hover_count()
		return
	slot.set_count_visible(false)
	_hover_count_label.text = str(count)
	var label_size := _hover_count_label.get_minimum_size()
	label_size.x = maxf(label_size.x, 20.0)
	label_size.y = maxf(label_size.y, 20.0)
	_hover_count_label.custom_minimum_size = label_size
	_hover_count_label.size = label_size
	var art_center := _preview_card.get_art_global_center()
	_hover_count_label.global_position = Vector2(
		art_center.x - label_size.x * 0.5,
		art_center.y - _preview_card.get_global_rect().size.y * 0.5 - label_size.y - 6.0
	)
	_hover_count_label.visible = true
	_count_overlay_layer.visible = true


func _hide_hover_count() -> void:
	if _hover_count_label != null:
		_hover_count_label.visible = false
	if _count_overlay_layer != null:
		_count_overlay_layer.visible = false
	if _hovered_slot != null:
		_hovered_slot.set_count_visible(true)


func _hide_preview() -> void:
	_hovered_ingredient = null
	_hide_hover_count()
	_hovered_slot = null
	_active_hover_rect = Rect2()
	_hide_canvas_layers()


func _set_footer_visible(visible_footer: bool) -> void:
	if _footer != null:
		_footer.visible = visible_footer


func _dev_selection_total() -> int:
	var total := 0
	for count in _dev_selection_counts.values():
		total += int(count)
	return total


func _update_dev_selection_ui() -> void:
	var total := _dev_selection_total()
	if _title_label != null:
		_title_label.text = "Developer Hand (%d/%d)" % [total, DEV_HAND_PICK_COUNT]
	if _selection_label != null:
		_selection_label.text = (
			"Left click to add, right click to remove."
			if total < DEV_HAND_PICK_COUNT
			else "Hand ready. Click Done."
		)
	if _done_button != null:
		_done_button.disabled = total != DEV_HAND_PICK_COUNT
	for ingredient_id in _dev_slot_by_id.keys():
		var slot: BagInventorySlot = _dev_slot_by_id[ingredient_id]
		if slot == null:
			continue
		var count := int(_dev_selection_counts.get(ingredient_id, 0))
		slot.bind_entry(slot.get_ingredient(), count, count > 0)


func _on_dev_slot_gui_input(ingredient: IngredientData, event: InputEvent) -> void:
	if _mode != DisplayMode.DEV_HAND_PICKER or ingredient == null:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var ingredient_id := ingredient.id
	var current := int(_dev_selection_counts.get(ingredient_id, 0))
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if _dev_selection_total() >= DEV_HAND_PICK_COUNT:
			return
		_dev_selection_counts[ingredient_id] = current + 1
		_dev_selection_order.append(ingredient)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if current <= 0:
			return
		if current == 1:
			_dev_selection_counts.erase(ingredient_id)
		else:
			_dev_selection_counts[ingredient_id] = current - 1
		_remove_last_dev_selection(ingredient)
	else:
		return

	_update_dev_selection_ui()


func _on_done_button_pressed() -> void:
	if _mode == DisplayMode.DEV_HAND_PICKER:
		if _dev_selection_total() != DEV_HAND_PICK_COUNT:
			return
		if _dev_selection_order.size() != DEV_HAND_PICK_COUNT:
			return
		var selection := _dev_selection_order.duplicate()
		hide_overlay()
		dev_hand_picker_completed.emit(selection)
		return
	if _mode != DisplayMode.DEV_TRINKET_PICKER:
		return
	var trinket_ids: Array[String] = []
	for trinket_id in _dev_trinket_selection.keys():
		if bool(_dev_trinket_selection[trinket_id]):
			trinket_ids.append(str(trinket_id))
	hide_overlay()
	dev_trinket_picker_completed.emit(trinket_ids)


func _update_dev_trinket_selection_ui() -> void:
	var selected_count := 0
	for trinket_id in _dev_trinket_selection.keys():
		if bool(_dev_trinket_selection[trinket_id]):
			selected_count += 1
	if _title_label != null:
		_title_label.text = "Developer Trinkets (%d selected)" % selected_count
	if _selection_label != null:
		_selection_label.text = "Click to select. Click again to deselect."
	if _done_button != null:
		_done_button.disabled = false
	for trinket_id in _dev_trinket_slot_by_id.keys():
		var slot: BagInventorySlot = _dev_trinket_slot_by_id[trinket_id]
		if slot == null:
			continue
		var selected := bool(_dev_trinket_selection.get(trinket_id, false))
		slot.bind_trinket(slot.get_trinket(), selected, selected)


func _on_dev_trinket_slot_gui_input(trinket: TrinketData) -> void:
	if _mode != DisplayMode.DEV_TRINKET_PICKER or trinket == null:
		return
	var trinket_id := trinket.id
	var is_selected := bool(_dev_trinket_selection.get(trinket_id, false))
	if is_selected:
		_dev_trinket_selection.erase(trinket_id)
	else:
		_dev_trinket_selection[trinket_id] = true
	_update_dev_trinket_selection_ui()


static func _trinket_has_art(trinket: TrinketData) -> bool:
	if trinket == null:
		return false
	var art_path := _TRINKET_ART_PATH_TEMPLATE % trinket.get_art_filename()
	return ResourceLoader.exists(art_path)


func _apply_panel_layout_for_mode() -> void:
	if _panel == null:
		return
	match _mode:
		DisplayMode.DEV_TRINKET_PICKER:
			_panel.anchor_left = _PANEL_DEV_TRINKET_ANCHOR_LEFT
			_panel.anchor_right = _PANEL_DEV_TRINKET_ANCHOR_RIGHT
			_panel.offset_left = 0.0
			_panel.offset_right = 0.0
		_:
			_restore_default_panel_layout()


func _restore_default_panel_layout() -> void:
	if _panel == null:
		return
	_panel.anchor_left = 0.0
	_panel.anchor_right = _PANEL_DEFAULT_ANCHOR_RIGHT
	_panel.offset_left = 12.0
	_panel.offset_right = -12.0


func _remove_last_dev_selection(ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	for i in range(_dev_selection_order.size() - 1, -1, -1):
		var entry: IngredientData = _dev_selection_order[i]
		if entry != null and entry.id == ingredient.id:
			_dev_selection_order.remove_at(i)
			return
class_name BagInventorySlot
extends Control

const ART_SIZE := Vector2(72.0, 72.0)

@onready var _art: TextureRect = $Art
@onready var _count_label: Label = $CountLabel

signal slot_gui_input(event: InputEvent)

const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

var _pending_ingredient: IngredientData
var _pending_trinket: TrinketData
var _pending_count: int = 0
var _show_count: bool = true
var _interactive: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_sync_art_layout)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_refresh_display()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _on_gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	slot_gui_input.emit(event)
	accept_event()


func bind_entry(ingredient: IngredientData, count: int, show_count: bool = true) -> void:
	_pending_trinket = null
	_clear_trinket_meta()
	_pending_ingredient = ingredient
	_pending_count = count
	_show_count = show_count
	_store_ingredient(ingredient)
	_refresh_display()


func bind_trinket(trinket: TrinketData, selected: bool, show_selection: bool = true) -> void:
	_pending_ingredient = null
	_clear_ingredient_meta()
	_pending_trinket = trinket
	_pending_count = 1 if selected else 0
	_show_count = show_selection
	_store_trinket(trinket)
	_refresh_display()


func _refresh_display() -> void:
	_resolve_nodes()
	if _pending_trinket != null:
		if _count_label != null:
			_count_label.visible = _show_count and _pending_count > 0
			_count_label.text = str(_pending_count)
		_apply_trinket_art(_pending_trinket)
		call_deferred("_sync_art_layout")
		return
	if _pending_ingredient == null:
		return
	if _count_label != null:
		_count_label.visible = _show_count
		_count_label.text = str(maxi(1, _pending_count))
	_apply_art(_pending_ingredient)
	call_deferred("_sync_art_layout")


func _resolve_nodes() -> void:
	if _art == null:
		_art = get_node_or_null("Art") as TextureRect
	if _count_label == null:
		_count_label = get_node_or_null("CountLabel") as Label


func get_art_center_global() -> Vector2:
	if _art != null:
		return _art.get_global_rect().get_center()
	return get_global_rect().get_center()


func _apply_art(ingredient: IngredientData) -> void:
	if _art == null or ingredient == null:
		return
	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art.modulate = Color.WHITE
		_art.visible = true
	else:
		_art.texture = null
		_art.modulate = Color(0.35, 0.38, 0.45, 1.0)
		_art.visible = false


func _apply_trinket_art(trinket: TrinketData) -> void:
	if _art == null or trinket == null:
		return
	var art_path := _TRINKET_ART_PATH_TEMPLATE % trinket.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art.modulate = Color.WHITE
		_art.visible = true
	else:
		_art.texture = null
		_art.modulate = Color(0.35, 0.38, 0.45, 1.0)
		_art.visible = false


func _sync_art_layout() -> void:
	if _art == null:
		return
	var host_size := size
	var art_pos := (host_size - ART_SIZE) * 0.5
	_art.position = art_pos
	_art.size = ART_SIZE


func get_ingredient() -> IngredientData:
	if not has_meta("ingredient"):
		return null
	return get_meta("ingredient") as IngredientData


func get_trinket() -> TrinketData:
	if not has_meta("trinket"):
		return null
	return get_meta("trinket") as TrinketData


func get_count() -> int:
	return _pending_count


func set_count_visible(show_count: bool) -> void:
	_resolve_nodes()
	if _count_label != null:
		_count_label.visible = show_count and _show_count


func _store_ingredient(ingredient: IngredientData) -> void:
	set_meta("ingredient", ingredient)


func _store_trinket(trinket: TrinketData) -> void:
	set_meta("trinket", trinket)


func _clear_ingredient_meta() -> void:
	if has_meta("ingredient"):
		remove_meta("ingredient")


func _clear_trinket_meta() -> void:
	if has_meta("trinket"):
		remove_meta("trinket")
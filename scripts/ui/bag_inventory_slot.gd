class_name BagInventorySlot
extends Control

const ART_SIZE := Vector2(72.0, 72.0)

@onready var _art: TextureRect = $Art
@onready var _count_label: Label = $CountLabel

var _pending_ingredient: IngredientData
var _pending_count: int = 0
var _show_count: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_sync_art_layout)
	_refresh_display()


func bind_entry(ingredient: IngredientData, count: int, show_count: bool = true) -> void:
	_pending_ingredient = ingredient
	_pending_count = count
	_show_count = show_count
	_store_ingredient(ingredient)
	_refresh_display()


func _refresh_display() -> void:
	if _pending_ingredient == null:
		return
	_resolve_nodes()
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


func get_count() -> int:
	return _pending_count


func set_count_visible(show_count: bool) -> void:
	_resolve_nodes()
	if _count_label != null:
		_count_label.visible = show_count and _show_count


func _store_ingredient(ingredient: IngredientData) -> void:
	set_meta("ingredient", ingredient)
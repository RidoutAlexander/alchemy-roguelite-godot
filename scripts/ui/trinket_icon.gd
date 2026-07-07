class_name TrinketIcon
extends Control

signal hover_started(trinket: TrinketData)
signal hover_ended

const _ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

@onready var _icon: TextureRect = $Icon
@onready var _fallback: Panel = $Fallback

var _trinket: TrinketData


func bind(trinket: TrinketData, icon_size: Vector2) -> void:
	_trinket = trinket
	custom_minimum_size = icon_size
	size = icon_size
	var texture := _load_art(trinket)
	if _icon != null:
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
		_icon.texture = texture
		_icon.visible = texture != null
	if _fallback != null:
		_fallback.visible = texture == null
		_fallback.custom_minimum_size = icon_size
		_fallback.size = icon_size


func get_trinket() -> TrinketData:
	return _trinket


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _trinket != null:
		hover_started.emit(_trinket)


func _on_mouse_exited() -> void:
	hover_ended.emit()


func _load_art(trinket: TrinketData) -> Texture2D:
	if trinket == null:
		return null
	var art_path := _ART_PATH_TEMPLATE % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D
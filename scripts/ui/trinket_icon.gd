class_name TrinketIcon
extends Control

signal hover_started(trinket: TrinketData)
signal hover_ended
signal activated(trinket: TrinketData, icon_center: Vector2, texture: Texture2D)

const _ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

@onready var _icon: TextureRect = $Icon
@onready var _fallback: Panel = $Fallback
@onready var _countdown: Label = $Countdown

var _trinket: TrinketData
var _clickable: bool = false


func bind(
	trinket: TrinketData,
	icon_size: Vector2,
	countdown_text: String = "",
	clickable: bool = false
) -> void:
	_trinket = trinket
	_clickable = clickable
	custom_minimum_size = icon_size
	size = icon_size
	mouse_default_cursor_shape = (
		CURSOR_POINTING_HAND if clickable else CURSOR_ARROW
	)
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
	_set_countdown(countdown_text, icon_size)


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


func _gui_input(event: InputEvent) -> void:
	if not _clickable or _trinket == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			activated.emit(_trinket, get_global_rect().get_center(), _load_art(_trinket))
			accept_event()


func _set_countdown(countdown_text: String, icon_size: Vector2) -> void:
	if _countdown == null:
		return
	_countdown.text = countdown_text
	_countdown.visible = countdown_text != ""
	if countdown_text == "":
		return
	var font_size := clampi(int(icon_size.y * 0.42), 12, 24)
	_countdown.add_theme_font_size_override("font_size", font_size)


func _load_art(trinket: TrinketData) -> Texture2D:
	if trinket == null:
		return null
	var art_path := _ART_PATH_TEMPLATE % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D
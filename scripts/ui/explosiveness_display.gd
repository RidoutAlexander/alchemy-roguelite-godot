class_name ExplosivenessDisplay
extends Control

@export var icon_texture: Texture2D = preload("res://assets/cards/icons/explosive_icon.png")
@export var icon_size: Vector2 = Vector2(48, 48)
@export var font_size: int = 40

@onready var _hbox: HBoxContainer = $HBox
@onready var _icon: TextureRect = $HBox/Icon
@onready var _label: Label = $HBox/AmountLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		if icon_texture != null:
			_icon.texture = icon_texture
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
	if _label != null:
		_label.add_theme_font_size_override("font_size", font_size)


func set_values(current: int, limit: int) -> void:
	if _label == null:
		return
	_label.text = "%d/%d" % [maxi(0, current), maxi(1, limit)]
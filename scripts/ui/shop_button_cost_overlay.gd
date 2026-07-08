class_name ShopButtonCostOverlay
extends Control

const _BOLD_TEXT_COLOR := Color(0, 0, 0, 1)

@export var cost: int = 5
@export var icon_size: Vector2 = Vector2(40, 36)
@export var font_size: int = 26
@export var outline_size: int = 2

@onready var _icon: TextureRect = $CoinIcon
@onready var _label: Label = $AmountLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = icon_size
	size = icon_size
	if _icon != null:
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
	if _label != null:
		_label.add_theme_color_override("font_color", _BOLD_TEXT_COLOR)
		_label.add_theme_color_override("font_outline_color", _BOLD_TEXT_COLOR)
		_label.add_theme_constant_override("outline_size", outline_size)
		_label.add_theme_font_size_override("font_size", font_size)
	set_cost(cost)


func set_cost(amount: int) -> void:
	cost = amount
	if _label != null:
		_label.text = str(maxi(0, amount))


func configure(new_icon_size: Vector2, new_font_size: int = -1) -> void:
	icon_size = new_icon_size
	custom_minimum_size = new_icon_size
	size = new_icon_size
	if _icon != null:
		_icon.custom_minimum_size = new_icon_size
		_icon.size = new_icon_size
	if new_font_size > 0:
		font_size = new_font_size
		if _label != null:
			_label.add_theme_font_size_override("font_size", font_size)
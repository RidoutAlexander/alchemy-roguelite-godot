class_name GoldCostBadge
extends Control

@export var cost: int = 1
@export var icon_size: Vector2 = Vector2(36, 36)
@export var font_size: int = 34

@onready var _icon: TextureRect = $HBox/Icon
@onready var _label: Label = $HBox/AmountLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
	if _label != null:
		_label.add_theme_font_size_override("font_size", font_size)
	set_cost(cost)


func set_cost(amount: int) -> void:
	cost = amount
	if _label != null:
		_label.text = str(maxi(0, amount))
class_name GoldDisplay
extends Control

@export var show_plus_prefix: bool = false
@export var icon_size: Vector2 = Vector2(48, 48)
@export var font_size: int = 40

@onready var _hbox: HBoxContainer = $HBox
@onready var _icon: TextureRect = $HBox/Icon
@onready var _label: Label = $HBox/AmountLabel

var _shake_tween: Tween
var _hbox_rest_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
	if _label != null:
		_label.add_theme_font_size_override("font_size", font_size)
	if _hbox != null:
		_hbox_rest_position = _hbox.position


func shake() -> void:
	if _hbox == null:
		return
	if _shake_tween:
		_shake_tween.kill()
		_hbox.position = _hbox_rest_position
	_shake_tween = create_tween()
	const SHAKE_OFFSET := 10.0
	const SHAKE_STEP := 0.045
	for i in 6:
		var direction := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(
			_hbox,
			"position:x",
			_hbox_rest_position.x + direction * SHAKE_OFFSET,
			SHAKE_STEP
		)
	_shake_tween.tween_property(_hbox, "position:x", _hbox_rest_position.x, SHAKE_STEP)


func set_amount(amount: int) -> void:
	if _label == null:
		return
	if show_plus_prefix:
		_label.text = "+%d" % amount
	else:
		_label.text = "%d" % amount
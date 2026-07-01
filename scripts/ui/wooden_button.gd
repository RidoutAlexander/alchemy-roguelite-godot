class_name WoodenButton
extends TextureButton

@export var label_text: String = "Button":
	set(value):
		label_text = value
		_update_label()

@onready var _label: Label = $Label

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0
const LONG_LABEL_CHARS := 12
const REFERENCE_SIZE := Vector2(505.0, 260.0)
const SHORT_FONT_SIZE := 140
const LONG_FONT_SIZE := 110
const LABEL_ANCHOR_LEFT := 0.04
const LABEL_ANCHOR_TOP := 0.10
const LABEL_ANCHOR_RIGHT := 0.96
const LABEL_ANCHOR_BOTTOM := 0.90
const LABEL_Y_OFFSET := -15.0

var _base_scale := Vector2.ONE


func _ready() -> void:
	if custom_minimum_size.length_squared() < 1.0:
		custom_minimum_size = size
	_update_pivot()
	_base_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	resized.connect(_on_resized)
	_apply_label_layout()
	_update_label()


func _on_resized() -> void:
	_update_pivot()
	_update_label()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _apply_label_layout() -> void:
	if _label == null:
		return
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.anchor_left = LABEL_ANCHOR_LEFT
	_label.anchor_top = LABEL_ANCHOR_TOP
	_label.anchor_right = LABEL_ANCHOR_RIGHT
	_label.anchor_bottom = LABEL_ANCHOR_BOTTOM
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_top = LABEL_Y_OFFSET
	_label.offset_bottom = LABEL_Y_OFFSET
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _update_label() -> void:
	if _label == null:
		return
	_label.text = label_text
	_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
		if label_text.length() > LONG_LABEL_CHARS
		else TextServer.AUTOWRAP_OFF
	)
	var base_size := LONG_FONT_SIZE if label_text.length() > LONG_LABEL_CHARS else SHORT_FONT_SIZE
	var scale_factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_label.add_theme_font_size_override("font_size", maxi(24, int(base_size * scale_factor)))


func _on_mouse_entered() -> void:
	_tween_scale(_base_scale * HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_scale(_base_scale)


func _on_pressed() -> void:
	scale = _base_scale


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
class_name ShopRerollButton
extends TextureButton

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0

var _base_scale := Vector2.ONE


func _ready() -> void:
	_update_pivot()
	_base_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	resized.connect(_on_resized)


func _on_resized() -> void:
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	if disabled:
		return
	_tween_scale(_base_scale * HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_scale(_base_scale)


func _on_pressed() -> void:
	scale = _base_scale


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
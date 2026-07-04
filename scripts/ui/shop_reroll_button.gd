class_name ShopRerollButton
extends TextureButton

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0

var _base_scale := Vector2.ONE
var _shake_tween: Tween
var _shake_rest_position := Vector2.ZERO


func _ready() -> void:
	_update_pivot()
	_base_scale = scale
	_shake_rest_position = global_position
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


func shake() -> void:
	_shake_rest_position = global_position
	if _shake_tween:
		_shake_tween.kill()
	global_position = _shake_rest_position
	_shake_tween = create_tween()
	const SHAKE_OFFSET := 10.0
	const SHAKE_STEP := 0.045
	for i in 6:
		var direction := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(
			self,
			"global_position:x",
			_shake_rest_position.x + direction * SHAKE_OFFSET,
			SHAKE_STEP
		)
	_shake_tween.tween_property(self, "global_position:x", _shake_rest_position.x, SHAKE_STEP)


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
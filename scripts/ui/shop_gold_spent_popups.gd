class_name ShopGoldSpentPopups
extends Node

const _FONT := preload("res://assets/fonts/ChildHood.otf")
const GOLD_COLOR := Color(1.0, 0.82, 0.18, 1.0)
const FONT_SIZE := 36
const OUTLINE_SIZE := 5
const POP_IN_DURATION := 0.14
const HOLD_DURATION := 0.3
const FADE_DURATION := 0.5
const FADE_DRIFT := Vector2(0.0, -28.0)
const SIDE_GAP := 10.0

var _active_labels: Array[Label] = []
var _active_tweens: Array[Tween] = []


func show_spent(amount: int, gold_display: Control) -> void:
	if amount <= 0 or gold_display == null:
		return
	_clear_active_popups()
	_show_popup(amount, gold_display)


func _popup_center(gold_display: Control, label_size: Vector2) -> Vector2:
	var rect := gold_display.get_global_rect()
	return Vector2(
		rect.position.x - SIDE_GAP - label_size.x * 0.5,
		rect.position.y + rect.size.y * 0.5
	)


func _show_popup(amount: int, gold_display: Control) -> void:
	var label := _make_label("-%d" % amount)
	add_child(label)
	_active_labels.append(label)

	label.reset_size()
	var label_size := label.get_minimum_size()
	label.custom_minimum_size = label_size
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.global_position = _popup_center(gold_display, label_size) - label_size * 0.5
	label.scale = Vector2(0.55, 0.55)
	label.modulate.a = 0.0

	var end_pos := label.global_position + FADE_DRIFT
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, POP_IN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, POP_IN_DURATION * 0.75)
	tween.set_parallel(false)
	tween.tween_interval(HOLD_DURATION)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, FADE_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "global_position", end_pos, FADE_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tween.finished.connect(
		func() -> void:
			_active_labels.erase(label)
			if is_instance_valid(label):
				label.queue_free()
	)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", GOLD_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	return label


func _clear_active_popups() -> void:
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for label in _active_labels:
		if is_instance_valid(label):
			label.queue_free()
	_active_labels.clear()
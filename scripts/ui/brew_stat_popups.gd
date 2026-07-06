class_name BrewStatPopups
extends Node

const _FONT := preload("res://assets/fonts/ChildHood.otf")

const SCORE_COLOR := Color(0.28, 0.95, 0.38, 1.0)
const EXPLOSIVE_COLOR := Color(1.0, 0.28, 0.24, 1.0)
const GOLD_COLOR := Color(1.0, 0.82, 0.18, 1.0)

const FONT_SIZE := 36
const OUTLINE_SIZE := 5
const POP_IN_DURATION := 0.14
const HOLD_DURATION := 0.3
const FADE_DURATION := 0.5
const FADE_DRIFT := Vector2(0.0, -28.0)
const SCORE_LIFT := 18.0
const SIDE_GAP := 10.0

var _score_flask: Control
var _explosiveness_counter: Control
var _gold_reward_display: Control

var _active_labels: Array[Label] = []
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	GameManager.brew_stats_presented.connect(_on_brew_stats_presented)


func configure(
	score_flask: Control,
	explosiveness_counter: Control,
	gold_reward_display: Control
) -> void:
	_score_flask = score_flask
	_explosiveness_counter = explosiveness_counter
	_gold_reward_display = gold_reward_display


func _on_brew_stats_presented(_ctx: BrewContext) -> void:
	if GameManager.run == null:
		return
	_clear_active_popups()

	var deltas := GameManager.run.brew_session.get_last_presented_stat_deltas()
	var score_delta := int(deltas.get("score", 0))
	var explosive_delta := int(deltas.get("explosiveness", 0))
	var gold_delta := int(deltas.get("gold_reward", 0))

	if score_delta > 0 and _score_flask != null:
		_show_popup(
			func(label_size: Vector2) -> Vector2: return _score_popup_center(label_size),
			"+%d" % score_delta,
			SCORE_COLOR
		)
	if explosive_delta > 0 and _explosiveness_counter != null:
		_show_popup(
			func(label_size: Vector2) -> Vector2: return _side_popup_center(
				_explosiveness_counter,
				label_size
			),
			"+%d" % explosive_delta,
			EXPLOSIVE_COLOR
		)
	if gold_delta > 0 and _gold_reward_display != null:
		_show_popup(
			func(label_size: Vector2) -> Vector2: return _side_popup_center(
				_gold_reward_display,
				label_size
			),
			"+%d" % gold_delta,
			GOLD_COLOR
		)


func _score_popup_center(label_size: Vector2) -> Vector2:
	var rect := _score_flask.get_global_rect()
	return Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.position.y - SCORE_LIFT - label_size.y * 0.5
	)


func _side_popup_center(anchor: Control, label_size: Vector2) -> Vector2:
	var rect := anchor.get_global_rect()
	return Vector2(
		rect.end.x + SIDE_GAP + label_size.x * 0.5,
		rect.position.y + rect.size.y * 0.5
	)


func _show_popup(position_fn: Callable, text: String, color: Color) -> void:
	var label := _make_label(text, color)
	add_child(label)
	_active_labels.append(label)

	label.reset_size()
	var label_size := label.get_minimum_size()
	label.custom_minimum_size = label_size
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.global_position = position_fn.call(label_size)
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
	tween.finished.connect(func() -> void:
		_active_labels.erase(label)
		if is_instance_valid(label):
			label.queue_free()
	)


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
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
extends CanvasLayer

const DEFAULT_FADE_OUT := 0.55
const DEFAULT_FADE_IN := 0.65
const DEFAULT_HOLD_DARK := 0.12

var _overlay: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 128
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_overlay)
	visible = true


func go_to(
	scene_path: String,
	fade_out: float = DEFAULT_FADE_OUT,
	fade_in: float = DEFAULT_FADE_IN,
	hold_dark: float = DEFAULT_HOLD_DARK
) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_out_tween := create_tween()
	fade_out_tween.tween_method(_set_alpha, 0.0, 1.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_out_tween.finished

	if hold_dark > 0.0:
		await get_tree().create_timer(hold_dark).timeout

	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame

	var fade_in_tween := create_tween()
	fade_in_tween.tween_method(_set_alpha, 1.0, 0.0, fade_in).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await fade_in_tween.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


func _set_alpha(alpha: float) -> void:
	_overlay.color.a = clampf(alpha, 0.0, 1.0)
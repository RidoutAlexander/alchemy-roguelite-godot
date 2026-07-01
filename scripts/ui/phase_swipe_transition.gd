class_name PhaseSwipeTransition
extends RefCounted

const SWIPE_DURATION := 0.5


static func should_swipe(from_phase: int, to_phase: int) -> bool:
	var brewing := GamePhase.Phase.BREWING
	var shop := GamePhase.Phase.SHOP
	return (from_phase == brewing and to_phase == shop) or (from_phase == shop and to_phase == brewing)


static func play(
	host: Control,
	outgoing: Control,
	incoming: Control,
	on_complete: Callable
) -> void:
	if outgoing == null or incoming == null or host == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var width := host.size.x
	if width <= 0.0:
		width = 1024.0

	outgoing.visible = true
	incoming.visible = true
	_set_horizontal_offset(outgoing, 0.0)
	_set_horizontal_offset(incoming, width)

	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(offset: float) -> void:
			_set_horizontal_offset(outgoing, offset),
		0.0,
		-width,
		SWIPE_DURATION
	)
	tween.tween_method(
		func(offset: float) -> void:
			_set_horizontal_offset(incoming, offset),
		width,
		0.0,
		SWIPE_DURATION
	)
	tween.finished.connect(
		func() -> void:
			_set_horizontal_offset(outgoing, 0.0)
			_set_horizontal_offset(incoming, 0.0)
			outgoing.visible = false
			if on_complete.is_valid():
				on_complete.call()
	)


static func _set_horizontal_offset(panel: Control, offset: float) -> void:
	panel.offset_left = offset
	panel.offset_right = offset
class_name IngredientFlyUtil
extends RefCounted

const DURATION := 0.8
const ARRIVAL_FRACTION := 1.0
const HOP_HEIGHT := 140.0
const FLY_Z_INDEX := 100


static func global_control_center(node: CanvasItem) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node is Control:
		return (node as Control).get_global_rect().get_center()
	return node.get_global_transform_with_canvas().origin


static func to_layer_position(layer: CanvasLayer, global_pos: Vector2) -> Vector2:
	if layer == null:
		return global_pos
	var viewport := layer.get_viewport()
	if viewport == null:
		return global_pos
	return viewport.get_canvas_transform().affine_inverse() * global_pos


static func play(
	layer: CanvasLayer,
	texture: Texture2D,
	start_center: Vector2,
	target_center: Vector2,
	display_size: Vector2,
	on_complete: Callable = Callable(),
	on_arrival: Callable = Callable()
) -> void:
	if texture == null or layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var layer_start := to_layer_position(layer, start_center)
	var layer_target := to_layer_position(layer, target_center)

	var flyer := Sprite2D.new()
	flyer.texture = texture
	flyer.centered = true
	flyer.z_index = FLY_Z_INDEX
	var tex_size := texture.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		flyer.scale = Vector2(display_size.x / tex_size.x, display_size.y / tex_size.y)
	else:
		flyer.scale = Vector2.ONE

	layer.add_child(flyer)
	flyer.position = layer_start

	var start_scale := flyer.scale
	var tween := flyer.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_update_flyer(flyer, layer_start, layer_target, start_scale, t),
		0.0,
		1.0,
		DURATION
	).set_trans(Tween.TRANS_LINEAR)

	if on_arrival.is_valid():
		var arrival := flyer.create_tween()
		arrival.tween_callback(on_arrival).set_delay(DURATION * ARRIVAL_FRACTION)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(flyer):
				flyer.queue_free()
			if on_complete.is_valid():
				on_complete.call()
	)


static func _update_flyer(
	flyer: Sprite2D,
	start_center: Vector2,
	target_center: Vector2,
	start_scale: Vector2,
	t: float
) -> void:
	if not is_instance_valid(flyer):
		return
	var center := start_center.lerp(target_center, t)
	center.y -= 4.0 * HOP_HEIGHT * t * (1.0 - t)
	var shrink := 1.0 - pow(t, 1.35)
	flyer.position = center
	flyer.scale = start_scale * shrink


static func play_escape_right(
	layer: CanvasLayer,
	texture: Texture2D,
	start_center: Vector2,
	display_size: Vector2,
	on_complete: Callable = Callable()
) -> void:
	if texture == null or layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var viewport := layer.get_viewport()
	var screen_width := viewport.get_visible_rect().size.x if viewport != null else 1920.0
	var layer_start := to_layer_position(layer, start_center)
	var layer_end := to_layer_position(
		layer,
		Vector2(screen_width + display_size.x * 0.75, start_center.y)
	)

	var flyer := Sprite2D.new()
	flyer.texture = texture
	flyer.centered = true
	flyer.z_index = FLY_Z_INDEX
	var tex_size := texture.get_size()
	var full_scale := Vector2.ONE
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		full_scale = Vector2(display_size.x / tex_size.x, display_size.y / tex_size.y)

	layer.add_child(flyer)
	flyer.position = layer_start
	flyer.scale = Vector2.ZERO

	var tween := flyer.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_update_escape_flyer(flyer, layer_start, layer_end, full_scale, t),
		0.0,
		1.0,
		DURATION
	).set_trans(Tween.TRANS_LINEAR)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(flyer):
				flyer.queue_free()
			if on_complete.is_valid():
				on_complete.call()
	)


static func _update_escape_flyer(
	flyer: Sprite2D,
	start_center: Vector2,
	target_center: Vector2,
	full_scale: Vector2,
	t: float
) -> void:
	if not is_instance_valid(flyer):
		return
	var center := start_center.lerp(target_center, t)
	center.y -= 4.0 * HOP_HEIGHT * t * (1.0 - t)
	var grow := pow(t, 1.35)
	flyer.position = center
	flyer.scale = full_scale * grow
class_name IngredientFlyUtil
extends RefCounted

const DURATION := 0.8
const BREW_INGREDIENT_FLY_SPEED_MULTIPLIER := 1.5
const BREW_INGREDIENT_FLY_DURATION := DURATION / BREW_INGREDIENT_FLY_SPEED_MULTIPLIER
const ARRIVAL_FRACTION := 1.0
const HOP_HEIGHT := 140.0
const FLY_Z_INDEX := 100
const POOF_POP_IN_DURATION := DURATION * 0.25
const POOF_HOLD_DURATION := DURATION * 0.2
const POOF_FADE_DURATION := DURATION - POOF_POP_IN_DURATION - POOF_HOLD_DURATION
const POOF_TEXT := "Poof!"
const _POOF_FONT := preload("res://assets/fonts/ChildHood.otf")
const _POOF_PUFF_TEXTURE := preload("res://assets/brew/bubble_dot.png")
const _POOF_PUFF_LAYOUT := [
	{"offset": Vector2.ZERO, "scale": 2.8},
	{"offset": Vector2(-34.0, -10.0), "scale": 1.9},
	{"offset": Vector2(36.0, -8.0), "scale": 2.1},
	{"offset": Vector2(-18.0, 22.0), "scale": 1.7},
	{"offset": Vector2(24.0, 20.0), "scale": 1.8},
]


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
	on_arrival: Callable = Callable(),
	duration: float = DURATION
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
		duration
	).set_trans(Tween.TRANS_LINEAR)

	if on_arrival.is_valid():
		var arrival := flyer.create_tween()
		arrival.tween_callback(on_arrival).set_delay(duration * ARRIVAL_FRACTION)

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


static func play_poof(
	layer: CanvasLayer,
	texture: Texture2D,
	start_center: Vector2,
	display_size: Vector2,
	on_complete: Callable = Callable()
) -> void:
	if layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var layer_center := to_layer_position(layer, start_center)
	var root := Node2D.new()
	root.z_index = FLY_Z_INDEX
	root.position = layer_center
	layer.add_child(root)

	var ingredient := Sprite2D.new()
	if texture != null:
		ingredient.texture = texture
		ingredient.centered = true
		var tex_size := texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			ingredient.scale = Vector2(
				display_size.x / tex_size.x,
				display_size.y / tex_size.y
			)
	root.add_child(ingredient)

	var cloud := Node2D.new()
	cloud.modulate = Color(0.94, 0.96, 1.0, 0.92)
	root.add_child(cloud)

	var puff_sprites: Array[Sprite2D] = []
	for puff in _POOF_PUFF_LAYOUT:
		var puff_sprite := Sprite2D.new()
		puff_sprite.texture = _POOF_PUFF_TEXTURE
		puff_sprite.centered = true
		puff_sprite.position = puff["offset"]
		puff_sprite.scale = Vector2.ZERO
		cloud.add_child(puff_sprite)
		puff_sprites.append(puff_sprite)

	var label := Label.new()
	label.text = POOF_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(140.0, 48.0)
	label.position = Vector2(-70.0, -24.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _POOF_FONT)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.18, 1.0))
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.modulate.a = 0.0
	root.add_child(label)

	var tween := root.create_tween()
	tween.set_parallel(true)
	for i in puff_sprites.size():
		var puff_sprite := puff_sprites[i]
		var target_scale := Vector2.ONE * float(_POOF_PUFF_LAYOUT[i]["scale"])
		tween.tween_property(puff_sprite, "scale", target_scale, POOF_POP_IN_DURATION).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	tween.tween_property(ingredient, "scale", ingredient.scale * 0.2, POOF_POP_IN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_IN)
	tween.tween_property(ingredient, "modulate:a", 0.0, POOF_POP_IN_DURATION)
	tween.tween_property(label, "modulate:a", 1.0, POOF_POP_IN_DURATION * 0.85).set_delay(
		POOF_POP_IN_DURATION * 0.2
	)

	tween.set_parallel(false)
	tween.tween_interval(POOF_HOLD_DURATION)
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, POOF_FADE_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	tween.tween_property(root, "scale", Vector2(1.08, 1.08), POOF_FADE_DURATION)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(root):
				root.queue_free()
			if on_complete.is_valid():
				on_complete.call()
	)


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
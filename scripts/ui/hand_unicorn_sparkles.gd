class_name HandUnicornSparkles
extends Control

var _layers: Array[CPUParticles2D] = []
var _pending_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	var star_tex := _create_star_texture(64)
	var glow_tex := _create_soft_glow_texture(20)

	_layers.append(_make_sparkle_layer(
		"Twinkles",
		glow_tex,
		60,
		0.35,
		0.75,
		1.05,
		0.0,
		0.0
	))
	_layers.append(_make_sparkle_layer(
		"Stars",
		star_tex,
		22,
		0.55,
		1.15,
		1.35,
		-90.0,
		90.0
	))
	_layers.append(_make_sparkle_layer(
		"BigStars",
		star_tex,
		8,
		0.95,
		1.75,
		1.8,
		-45.0,
		45.0
	))

	for layer in _layers:
		add_child(layer)
	_apply_pending_active()


func set_active(active: bool) -> void:
	_pending_active = active
	_apply_pending_active()


func _apply_pending_active() -> void:
	for layer in _layers:
		if layer != null:
			layer.emitting = _pending_active and visible


func configure_for_card(card_size: Vector2, _card_scale: float) -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	custom_minimum_size = card_size
	size = card_size
	for layer in _layers:
		if layer == null:
			continue
		layer.position = card_size * 0.5
		layer.emission_rect_extents = card_size * 0.5


func _make_sparkle_layer(
	layer_name: String,
	texture: Texture2D,
	amount: int,
	scale_min: float,
	scale_max: float,
	lifetime: float,
	spin_min: float,
	spin_max: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = layer_name
	particles.texture = texture
	particles.emitting = false
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.85
	particles.amount = amount
	particles.lifetime = lifetime
	particles.lifetime_randomness = 0.35
	particles.preprocess = lifetime
	particles.speed_scale = 1.0
	particles.local_coords = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.direction = Vector2.ZERO
	particles.spread = 0.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 0.0
	particles.initial_velocity_max = 0.0
	particles.orbit_velocity_min = 0.0
	particles.orbit_velocity_max = 0.0
	particles.angular_velocity_min = spin_min
	particles.angular_velocity_max = spin_max
	particles.scale_amount_min = scale_min
	particles.scale_amount_max = scale_max
	particles.color = Color(1.0, 1.0, 0.95, 1.0)
	particles.color_ramp = _make_twinkle_ramp()

	var sparkle_material := CanvasItemMaterial.new()
	sparkle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = sparkle_material

	return particles


func _make_twinkle_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 0.95, 0.0))
	ramp.add_point(0.08, Color(1.0, 1.0, 0.95, 1.0))
	ramp.add_point(0.42, Color(1.0, 1.0, 1.0, 1.0))
	ramp.add_point(0.78, Color(1.0, 1.0, 0.95, 0.65))
	ramp.set_color(1, Color(1.0, 1.0, 0.95, 0.0))
	return ramp


static func _create_star_texture(tex_size: int) -> ImageTexture:
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := float(tex_size) * 0.5
	var arm_reach := float(tex_size) * 0.46
	var arm_thickness := maxf(2.0, float(tex_size) * 0.07)
	var core_radius := maxf(3.0, float(tex_size) * 0.1)

	for y in tex_size:
		for x in tex_size:
			var dx := absf(float(x) - center)
			var dy := absf(float(y) - center)
			var alpha := 0.0

			if dy <= arm_thickness:
				alpha = maxf(alpha, 1.0 - clampf((dx - arm_thickness) / (arm_reach - arm_thickness), 0.0, 1.0))
			if dx <= arm_thickness:
				alpha = maxf(alpha, 1.0 - clampf((dy - arm_thickness) / (arm_reach - arm_thickness), 0.0, 1.0))

			var diamond_dist := (dx + dy) / core_radius
			if diamond_dist <= 1.0:
				alpha = maxf(alpha, 1.0 - diamond_dist)

			if alpha > 0.02:
				var brightness := lerpf(0.82, 1.0, alpha)
				image.set_pixel(x, y, Color(brightness, brightness, 0.94, alpha))

	return ImageTexture.create_from_image(image)


static func _create_soft_glow_texture(tex_size: int) -> ImageTexture:
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := float(tex_size) * 0.5
	var radius := float(tex_size) * 0.5

	for y in tex_size:
		for x in tex_size:
			var dist := Vector2(float(x), float(y)).distance_to(Vector2(center, center))
			var alpha := 1.0 - clampf(dist / radius, 0.0, 1.0)
			alpha = pow(alpha, 1.35)
			if alpha > 0.03:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)

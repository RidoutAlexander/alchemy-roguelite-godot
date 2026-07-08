class_name HandUnicornSparkles
extends Control

const _SPARKLE_TEXTURE := preload("res://assets/brew/bubble_dot.png")

var _particles: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_particles = CPUParticles2D.new()
	_particles.name = "SparkleParticles"
	_particles.texture = _SPARKLE_TEXTURE
	_particles.emitting = false
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.7
	_particles.lifetime = 1.6
	_particles.preprocess = 1.4
	_particles.amount = 96
	_particles.speed_scale = 0.35
	_particles.local_coords = true
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2.ZERO
	_particles.spread = 0.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 0.0
	_particles.initial_velocity_max = 0.0
	_particles.angular_velocity_min = 0.0
	_particles.angular_velocity_max = 0.0
	_particles.orbit_velocity_min = 0.0
	_particles.orbit_velocity_max = 0.0
	_particles.scale_amount_min = 0.025
	_particles.scale_amount_max = 0.11
	_particles.color = Color(1.0, 1.0, 1.0, 0.88)

	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.1, Color(1.0, 1.0, 1.0, 1.0))
	fade.add_point(0.55, Color(1.0, 1.0, 1.0, 0.85))
	fade.add_point(0.85, Color(1.0, 1.0, 1.0, 0.35))
	_particles.color_ramp = fade

	var sparkle_material := CanvasItemMaterial.new()
	sparkle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_particles.material = sparkle_material

	add_child(_particles)


func set_active(active: bool) -> void:
	if _particles == null:
		return
	_particles.emitting = active and visible


func configure_for_card(card_size: Vector2, _card_scale: float) -> void:
	position = Vector2.ZERO
	scale = Vector2.ONE
	custom_minimum_size = card_size
	size = card_size
	if _particles == null:
		return
	_particles.position = card_size * 0.5
	_particles.emission_rect_extents = card_size * 0.5
class_name HandUnicornSparkles
extends Node2D

const _SPARKLE_TEXTURE := preload("res://assets/brew/bubble_dot.png")

var _particles: CPUParticles2D


func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "SparkleParticles"
	_particles.texture = _SPARKLE_TEXTURE
	_particles.emitting = false
	_particles.one_shot = false
	_particles.explosiveness = 0.0
	_particles.randomness = 0.4
	_particles.lifetime = 0.85
	_particles.preprocess = 0.6
	_particles.amount = 28
	_particles.speed_scale = 1.15
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(92.0, 118.0)
	_particles.direction = Vector2(0.0, -1.0)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0.0, -10.0)
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 28.0
	_particles.angular_velocity_min = -180.0
	_particles.angular_velocity_max = 180.0
	_particles.orbit_velocity_min = 0.0
	_particles.orbit_velocity_max = 0.15
	_particles.scale_amount_min = 0.06
	_particles.scale_amount_max = 0.18
	_particles.color = Color(1.0, 1.0, 1.0, 0.92)

	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.12, Color(1.0, 1.0, 1.0, 1.0))
	fade.add_point(0.72, Color(1.0, 1.0, 1.0, 0.55))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_particles.color_ramp = fade_texture

	var sparkle_material := CanvasItemMaterial.new()
	sparkle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_particles.material = sparkle_material

	add_child(_particles)


func set_active(active: bool) -> void:
	if _particles == null:
		return
	_particles.emitting = active and visible


func configure_for_card(card_size: Vector2, card_scale: float) -> void:
	position = Vector2(card_size.x * 0.5, card_size.y * 0.46)
	scale = Vector2.ONE / card_scale
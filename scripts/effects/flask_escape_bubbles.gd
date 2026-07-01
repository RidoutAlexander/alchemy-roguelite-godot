extends Node2D

@export var spawn_rate: float = 10.0
@export var rise_strength: float = 36.0

const _POOL_SIZE := 96
const _TEXTURE_PATH := "res://assets/brew/bubble_dot.png"

var _pool: Array[Sprite2D] = []
var _active: Array[Dictionary] = []
var _spawn_accum: float = 0.0
var _texture: Texture2D
var _effects_enabled: bool = false
var _center_x: float = 0.0
var _half_width: float = 28.0
var _fill_top_y: float = 0.0
var _fill_bottom_y: float = 1.0
var _liquid_height: float = 1.0


func _ready() -> void:
	_texture = load(_TEXTURE_PATH) as Texture2D
	for i in _POOL_SIZE:
		var sprite := Sprite2D.new()
		sprite.texture = _texture
		sprite.visible = false
		sprite.z_index = 1
		sprite.centered = true
		add_child(sprite)
		_pool.append(sprite)


func set_meniscus(center: Vector2, radius: Vector2) -> void:
	set_fill_region(center.x, radius.x, center.y, _fill_bottom_y)


func set_fill_region(center_x: float, half_width: float, meniscus_y: float, bottom_y: float) -> void:
	_center_x = center_x
	_half_width = maxf(4.0, half_width)
	_fill_top_y = meniscus_y
	_fill_bottom_y = bottom_y
	_liquid_height = maxf(8.0, bottom_y - meniscus_y)


func set_effects_enabled(enabled: bool) -> void:
	if _effects_enabled == enabled:
		return
	_effects_enabled = enabled
	if not enabled:
		_spawn_accum = 0.0
		_clear_active()


func _clear_active() -> void:
	for bubble in _active:
		var sprite: Sprite2D = bubble.sprite
		sprite.visible = false
		sprite.modulate.a = 1.0
		_pool.append(sprite)
	_active.clear()


func _width_scale_at_y(y: float) -> float:
	if _liquid_height <= 1.0:
		return 1.0
	var depth := clampf((y - _fill_top_y) / _liquid_height, 0.0, 1.0)
	return lerpf(0.5, 1.0, sqrt(depth))


func _random_fill_point() -> Vector2:
	if _liquid_height <= 8.0:
		return Vector2(_center_x, _fill_bottom_y)

	var y := randf_range(_fill_top_y + 8.0, _fill_bottom_y - 8.0)
	var width_scale := _width_scale_at_y(y)
	var x := _center_x + randf_range(-_half_width * width_scale, _half_width * width_scale)
	return Vector2(x, y)


func _scale_from_roll(size_roll: float) -> float:
	if size_roll > 0.86:
		return randf_range(0.22, 0.36)
	if size_roll > 0.52:
		return randf_range(0.14, 0.24)
	return randf_range(0.06, 0.14)


func spawn_at_pop(origin: Vector2, size_roll: float) -> void:
	_launch_bubble(origin, _scale_from_roll(size_roll))


func _launch_bubble(origin: Vector2, bubble_scale: float) -> void:
	if _pool.is_empty():
		return

	var sprite: Sprite2D = _pool.pop_back()
	sprite.position = origin
	sprite.scale = Vector2.ONE * bubble_scale

	var brightness := randf_range(0.85, 1.0)
	sprite.modulate = Color(0.45 * brightness, 0.9 * brightness, 0.5 * brightness, 1.0)
	sprite.visible = true

	var velocity := Vector2(randf_range(-6.0, 6.0), -randf_range(16.0, 34.0))
	var lifetime := randf_range(0.8, 1.6)
	var sway_phase := randf_range(0.0, TAU)
	var sway_strength := randf_range(14.0, 30.0)

	_active.append({
		"sprite": sprite,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"sway_phase": sway_phase,
		"sway_strength": sway_strength,
	})


func _process(delta: float) -> void:
	if not _effects_enabled or _liquid_height <= 8.0:
		return

	var fill_spawn_rate := spawn_rate * clampf(_liquid_height / 120.0, 0.35, 2.5)
	_spawn_accum += delta * fill_spawn_rate
	while _spawn_accum >= 1.0:
		_spawn_accum -= 1.0
		_launch_bubble(_random_fill_point(), _scale_from_roll(randf()))

	var i := 0
	while i < _active.size():
		var bubble: Dictionary = _active[i]
		bubble.age = bubble.age + delta

		bubble.velocity.y -= rise_strength * delta
		bubble.velocity.x += sin(bubble.age * 6.5 + bubble.sway_phase) * bubble.sway_strength * delta

		var sprite: Sprite2D = bubble.sprite
		sprite.position += bubble.velocity * delta

		var progress: float = bubble.age / bubble.lifetime
		sprite.modulate.a = 1.0 - smoothstep(0.55, 1.0, progress)

		var above_surface: bool = sprite.position.y < _fill_top_y - 4.0
		var expired: bool = float(bubble.age) >= float(bubble.lifetime)
		if above_surface or expired:
			sprite.visible = false
			sprite.modulate.a = 1.0
			_pool.append(sprite)
			_active.remove_at(i)
		else:
			i += 1

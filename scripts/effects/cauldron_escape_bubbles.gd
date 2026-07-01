extends Node2D

@export var spawn_rate: float = 10.0
@export var ellipse_center: Vector2 = Vector2(136.5, 37.0)
@export var ellipse_radius: Vector2 = Vector2(131.0, 33.0)
@export var gravity_strength: float = 85.0

const _POOL_SIZE := 140
const _BASE_SPAWN_RATE := 2.5
const _MAX_SPAWN_RATE := 42.0
const _BASE_LAUNCH_SPEED := 24.0
const _MAX_LAUNCH_SPEED := 92.0
const _TEXTURE_PATH := "res://assets/brew/bubble_dot.png"

var _pool: Array[Sprite2D] = []
var _active: Array[Dictionary] = []
var _spawn_accum: float = 0.0
var _texture: Texture2D
var _activity_level: float = 0.0


func set_activity_level(level: float) -> void:
	_activity_level = clampf(level, 0.0, 1.0)
	spawn_rate = lerpf(_BASE_SPAWN_RATE, _MAX_SPAWN_RATE, _activity_level)


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


func _random_ellipse_point() -> Vector2:
	for _attempt in 24:
		var offset := Vector2(
			randf_range(-ellipse_radius.x, ellipse_radius.x),
			randf_range(-ellipse_radius.y, ellipse_radius.y)
		)
		var normalized := offset / ellipse_radius
		if normalized.length_squared() <= 1.0:
			return ellipse_center + offset
	return ellipse_center


func _scale_from_roll(size_roll: float) -> float:
	if size_roll > 0.86:
		return randf_range(0.4, 0.58)
	if size_roll > 0.52:
		return randf_range(0.24, 0.4)
	return randf_range(0.1, 0.22)


func spawn_at_pop(origin: Vector2, size_roll: float, activity: float = 0.0) -> void:
	_launch_bubble(origin, _scale_from_roll(size_roll), activity)


func _launch_bubble(origin: Vector2, bubble_scale: float, activity: float = -1.0) -> void:
	if activity < 0.0:
		activity = _activity_level
	if _pool.is_empty():
		return

	var sprite: Sprite2D = _pool.pop_back()
	sprite.position = origin
	sprite.scale = Vector2.ONE * bubble_scale

	var brightness := randf_range(0.85, 1.0)
	sprite.modulate = Color(0.72 * brightness, 0.4 * brightness, 0.94 * brightness, 1.0)
	sprite.visible = true

	var launch_angle := randf_range(-PI * 0.92, -PI * 0.08)
	var speed_min := lerpf(_BASE_LAUNCH_SPEED, 48.0, activity)
	var speed_max := lerpf(52.0, _MAX_LAUNCH_SPEED, activity)
	var launch_speed := randf_range(speed_min, speed_max)
	launch_speed *= lerpf(1.0, 0.78, clampf((bubble_scale - 0.1) / 0.48, 0.0, 1.0))
	var velocity := Vector2(cos(launch_angle), sin(launch_angle)) * launch_speed
	var lifetime := randf_range(0.55, 1.0) * lerpf(1.0, 1.35, clampf((bubble_scale - 0.1) / 0.48, 0.0, 1.0))
	var sway_phase := randf_range(0.0, TAU)
	var sway_strength := randf_range(18.0, 42.0) * lerpf(1.0, 1.55, activity)

	_active.append({
		"sprite": sprite,
		"velocity": velocity,
		"age": 0.0,
		"lifetime": lifetime,
		"sway_phase": sway_phase,
		"sway_strength": sway_strength,
	})


func _process(delta: float) -> void:
	_spawn_accum += delta * spawn_rate
	while _spawn_accum >= 1.0:
		_spawn_accum -= 1.0
		_launch_bubble(_random_ellipse_point(), _scale_from_roll(randf()), _activity_level)

	var i := 0
	while i < _active.size():
		var bubble: Dictionary = _active[i]
		bubble.age = bubble.age + delta

		bubble.velocity.y += gravity_strength * delta
		bubble.velocity.x += sin(bubble.age * 6.5 + bubble.sway_phase) * bubble.sway_strength * delta

		var sprite: Sprite2D = bubble.sprite
		sprite.position += bubble.velocity * delta

		var progress: float = bubble.age / bubble.lifetime
		sprite.modulate.a = 1.0 - smoothstep(0.55, 1.0, progress)

		if bubble.age >= bubble.lifetime:
			sprite.visible = false
			sprite.modulate.a = 1.0
			_pool.append(sprite)
			_active.remove_at(i)
		else:
			i += 1
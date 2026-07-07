class_name BossVictoryConfettiEffect
extends Node2D

const BEAT_BEFORE_BURST := 0.45
const EFFECT_DURATION := 2.0
const Z_INDEX := 250

const COLORS := [
	Color(0.96, 0.78, 0.14, 1.0),
	Color(0.18, 0.74, 0.42, 1.0),
	Color(0.84, 0.24, 0.58, 1.0),
	Color(0.28, 0.64, 0.96, 1.0),
	Color(0.96, 0.44, 0.16, 1.0),
	Color(0.74, 0.54, 0.96, 1.0),
	Color(0.96, 0.92, 0.34, 1.0),
	Color(0.42, 0.88, 0.82, 1.0),
]

const CONFETTI_COUNT := 140

var _pieces: Array[Dictionary] = []
var _elapsed := 0.0
var _flash_overlay: ColorRect
var _on_complete := Callable()
var _viewport_size := Vector2(1024.0, 576.0)


static func play(layer: CanvasLayer, on_complete: Callable = Callable()) -> void:
	if layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var effect := BossVictoryConfettiEffect.new()
	layer.add_child(effect)
	effect.z_index = Z_INDEX
	effect._on_complete = on_complete
	effect.set_process(true)


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		_viewport_size = Vector2(1024.0, 576.0)
	_spawn_flash_overlay()


func _spawn_flash_overlay() -> void:
	_flash_overlay = ColorRect.new()
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(1.0, 0.94, 0.72, 0.0)
	_flash_overlay.size = _viewport_size
	add_child(_flash_overlay)


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed < BEAT_BEFORE_BURST:
		_update_flash_overlay()
		return

	if _pieces.is_empty():
		_spawn_confetti_burst()

	_update_confetti(delta)
	_update_flash_overlay()

	if _elapsed >= BEAT_BEFORE_BURST + EFFECT_DURATION:
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()


func _update_flash_overlay() -> void:
	if _flash_overlay == null:
		return
	var beat_t := clampf(_elapsed / BEAT_BEFORE_BURST, 0.0, 1.0)
	var flash_alpha := 0.0
	if _elapsed < 0.12:
		flash_alpha = lerpf(0.0, 0.22, _elapsed / 0.12)
	elif _elapsed < BEAT_BEFORE_BURST:
		flash_alpha = lerpf(0.22, 0.0, beat_t)
	_flash_overlay.color = Color(1.0, 0.94, 0.72, flash_alpha)


func _spawn_confetti_burst() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for burst_index in 3:
		var origin_x := _viewport_size.x * (0.2 + 0.3 * burst_index)
		var origin_y := _viewport_size.y * rng.randf_range(0.08, 0.22)
		var burst_count := CONFETTI_COUNT / 3
		for _i in burst_count:
			_spawn_piece(rng, Vector2(origin_x, origin_y))

	# A few celebratory streamers from the sides.
	for _i in 12:
		var from_left := rng.randf() < 0.5
		var origin := Vector2(
			-20.0 if from_left else _viewport_size.x + 20.0,
			rng.randf_range(0.05, 0.35) * _viewport_size.y
		)
		_spawn_streamer(rng, origin, from_left)


func _spawn_piece(rng: RandomNumberGenerator, origin: Vector2) -> void:
	var piece_type := rng.randi_range(0, 3)
	var polygon := Polygon2D.new()
	polygon.color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	polygon.polygon = _shape_for_type(piece_type, rng)
	polygon.rotation = deg_to_rad(rng.randf_range(0.0, 360.0))
	add_child(polygon)

	var speed := rng.randf_range(260.0, 520.0)
	var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	velocity.x += rng.randf_range(-180.0, 180.0)

	_pieces.append(
		{
			"node": polygon,
			"velocity": velocity,
			"spin": deg_to_rad(rng.randf_range(-420.0, 420.0)),
			"flutter_phase": rng.randf_range(0.0, TAU),
			"flutter_speed": rng.randf_range(5.0, 9.0),
			"drag": rng.randf_range(0.35, 0.55),
			"gravity": rng.randf_range(520.0, 760.0),
			"lifetime": rng.randf_range(1.35, EFFECT_DURATION),
			"age": 0.0,
			"base_color": polygon.color,
			"origin": origin,
		}
	)
	polygon.position = origin


func _spawn_streamer(rng: RandomNumberGenerator, origin: Vector2, from_left: bool) -> void:
	var polygon := Polygon2D.new()
	polygon.color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	var length := rng.randf_range(28.0, 52.0)
	var width := rng.randf_range(3.0, 5.5)
	polygon.polygon = PackedVector2Array(
		[
			Vector2(0.0, -width * 0.5),
			Vector2(length, -width * 0.25),
			Vector2(length, width * 0.25),
			Vector2(0.0, width * 0.5),
		]
	)
	add_child(polygon)

	var direction := 1.0 if from_left else -1.0
	var velocity := Vector2(
		direction * rng.randf_range(320.0, 500.0),
		rng.randf_range(120.0, 280.0)
	)

	_pieces.append(
		{
			"node": polygon,
			"velocity": velocity,
			"spin": deg_to_rad(rng.randf_range(-240.0, 240.0)),
			"flutter_phase": rng.randf_range(0.0, TAU),
			"flutter_speed": rng.randf_range(7.0, 11.0),
			"drag": 0.42,
			"gravity": rng.randf_range(380.0, 540.0),
			"lifetime": rng.randf_range(1.5, EFFECT_DURATION + 0.2),
			"age": 0.0,
			"base_color": polygon.color,
			"origin": origin,
		}
	)
	polygon.position = origin


func _shape_for_type(piece_type: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	match piece_type:
		0:
			var length := rng.randf_range(10.0, 16.0)
			var width := rng.randf_range(2.5, 4.5)
			return PackedVector2Array(
				[
					Vector2(-length * 0.5, -width * 0.5),
					Vector2(length * 0.5, -width * 0.5),
					Vector2(length * 0.5, width * 0.5),
					Vector2(-length * 0.5, width * 0.5),
				]
			)
		1:
			var radius := rng.randf_range(3.5, 6.0)
			var points := PackedVector2Array()
			var sides := 8
			for side_index in sides:
				var angle := TAU * float(side_index) / float(sides)
				points.append(Vector2(cos(angle), sin(angle)) * radius)
			return points
		2:
			var size := rng.randf_range(7.0, 12.0)
			return PackedVector2Array(
				[
					Vector2(0.0, -size),
					Vector2(size * 0.72, 0.0),
					Vector2(0.0, size),
					Vector2(-size * 0.72, 0.0),
				]
			)
		_:
			var width := rng.randf_range(5.0, 8.0)
			var height := rng.randf_range(11.0, 17.0)
			return PackedVector2Array(
				[
					Vector2(0.0, -height * 0.5),
					Vector2(width * 0.5, -height * 0.15),
					Vector2(width * 0.35, height * 0.5),
					Vector2(-width * 0.35, height * 0.5),
					Vector2(-width * 0.5, -height * 0.15),
				]
			)


func _update_confetti(delta: float) -> void:
	var local_elapsed := _elapsed - BEAT_BEFORE_BURST
	for piece in _pieces:
		piece["age"] = float(piece.get("age", 0.0)) + delta
		var age := float(piece["age"])
		var lifetime := float(piece["lifetime"])
		if age > lifetime:
			var node: Node = piece["node"]
			if is_instance_valid(node):
				node.queue_free()
			piece["node"] = null
			continue

		var node2d := piece["node"] as Node2D
		if node2d == null or not is_instance_valid(node2d):
			continue

		var velocity: Vector2 = piece["velocity"]
		velocity.y += float(piece["gravity"]) * delta
		var drag := float(piece["drag"])
		velocity *= 1.0 - drag * delta
		var flutter := sin(
			local_elapsed * float(piece["flutter_speed"]) + float(piece["flutter_phase"])
		)
		velocity.x += flutter * 42.0 * delta
		piece["velocity"] = velocity
		node2d.position += velocity * delta
		node2d.rotation += float(piece["spin"]) * delta

		var fade_start := lifetime * 0.62
		var alpha := 1.0
		if age > fade_start:
			alpha = 1.0 - clampf((age - fade_start) / (lifetime - fade_start), 0.0, 1.0)
		var base_color: Color = piece["base_color"]
		if node2d is Polygon2D:
			(node2d as Polygon2D).color = Color(base_color.r, base_color.g, base_color.b, alpha)
extends ColorRect

const BOWL_CENTER := Vector2(0.5, 0.52)
const BOWL_RADIUS := Vector2(0.48, 0.46)
const RECT_SIZE := Vector2(273.0, 72.0)

var _spawner: Node2D
var _last_life: Dictionary = {}
var _activity_level: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spawner = get_node_or_null("EscapeBubbleSpawner") as Node2D
	set_process(true)


func set_activity_level(level: float) -> void:
	_activity_level = clampf(level, 0.0, 1.0)
	var shader_material := material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("activity_level", _activity_level)
	if _spawner != null and _spawner.has_method("set_activity_level"):
		_spawner.set_activity_level(_activity_level)


func _hash11(p: float) -> float:
	return fposmod(sin(p * 127.1) * 43758.5453, 1.0)


func _bubble_life(time: float, seed: float) -> float:
	var cycle_len := 2.8 + _hash11(seed * 11.3) * 4.8
	var cycle := fmod(time / cycle_len + _hash11(seed * 9.73), 1.0)
	var pop_len := 0.24 + _hash11(seed * 14.2) * 0.26
	if cycle > pop_len:
		return 0.0
	var t := cycle / pop_len
	return sin(t * PI)


func _home_pixel(seed: float) -> Vector2:
	var anchor_x := _hash11(seed * 2.11) - 0.5
	var anchor_y := _hash11(seed * 3.07) - 0.5
	var home := BOWL_CENTER + Vector2(anchor_x, anchor_y) * BOWL_RADIUS * 1.85
	return Vector2(home.x * RECT_SIZE.x, home.y * RECT_SIZE.y)


func _bubble_life_scaled(time: float, seed: float, activity: float) -> float:
	var time_scale := lerpf(1.0, 2.8, activity)
	return _bubble_life(time * time_scale, seed)


func _process(_delta: float) -> void:
	if _spawner == null or not _spawner.has_method("spawn_at_pop"):
		return

	var activity := _activity_level
	var bubble_count := int(lerpf(28.0, 96.0, activity))
	var spawn_threshold := lerpf(0.48, 0.02, activity)
	var time := Time.get_ticks_msec() * 0.001

	for layer in 3:
		for i in bubble_count:
			var seed := float(i + layer * 97)
			var life := _bubble_life_scaled(time, seed, activity)
			var key := str(seed)
			var prev: float = _last_life.get(key, 0.0)
			if prev < 0.12 and life >= 0.12:
				var size_roll := _hash11(seed * 4.19)
				if size_roll > spawn_threshold:
					_spawner.spawn_at_pop(_home_pixel(seed), size_roll, activity)
			_last_life[key] = life
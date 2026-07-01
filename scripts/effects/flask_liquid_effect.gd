extends TextureRect

const FLASK_TEXTURE_PATH := "res://assets/sprites/score_flask.png"
const FLASK_MASK_PATH := "res://assets/sprites/score_flask_cavity_mask.png"

var _spawner: Node2D
var _last_life: Dictionary = {}
var _rect_size := Vector2.ONE
var _texture_size := Vector2(576.0, 1024.0)
var _cavity_mask_tex: Texture2D
var _metrics: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spawner = get_node_or_null("EscapeBubbleSpawner") as Node2D
	_rect_size = size
	_measure_interior()
	resized.connect(_on_resized)
	set_process(true)


func _on_resized() -> void:
	_rect_size = size
	_apply_metrics_to_shader()


func _measure_interior() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material:
		var existing_mask := shader_material.get_shader_parameter("cavity_mask") as Texture2D
		if existing_mask != null:
			_cavity_mask_tex = existing_mask
			var mask_image := existing_mask.get_image()
			if mask_image != null and not mask_image.is_empty():
				_metrics = FlaskInteriorMetrics.measure_from_mask(mask_image)
				_texture_size = Vector2(float(mask_image.get_width()), float(mask_image.get_height()))
				_apply_metrics_to_shader()
				return

	var flask_texture := load(FLASK_TEXTURE_PATH) as Texture2D
	if flask_texture != null:
		_texture_size = flask_texture.get_size()
		var flask_image := flask_texture.get_image()
		if flask_image != null and not flask_image.is_empty():
			var mask_image := FlaskInteriorMetrics.build_cavity_mask(flask_image)
			_cavity_mask_tex = ImageTexture.create_from_image(mask_image)
			_metrics = FlaskInteriorMetrics.measure_from_mask(mask_image)
			_apply_metrics_to_shader()
			return

	_metrics = FlaskInteriorMetrics.defaults()
	var mask_texture := load(FLASK_MASK_PATH) as Texture2D
	if mask_texture != null:
		_cavity_mask_tex = mask_texture
		var fallback_mask := mask_texture.get_image()
		if fallback_mask != null and not fallback_mask.is_empty():
			_metrics = FlaskInteriorMetrics.measure_from_mask(fallback_mask)
			_texture_size = Vector2(float(fallback_mask.get_width()), float(fallback_mask.get_height()))
	_apply_metrics_to_shader()


func _apply_metrics_to_shader() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	var aspect := _rect_size.x / maxf(_rect_size.y, 1.0)
	FlaskInteriorMetrics.apply_to_material(shader_material, _metrics, aspect, _texture_size)
	var uv_scale := Vector2.ONE
	var uv_offset := Vector2.ZERO
	if _uses_letterbox_fit():
		var fit := FlaskInteriorMetrics.texture_fit_rect(_texture_size, _rect_size)
		uv_scale = fit["uv_scale"]
		uv_offset = fit["uv_offset"]
	shader_material.set_shader_parameter("uv_scale", uv_scale)
	shader_material.set_shader_parameter("uv_offset", uv_offset)
	if _cavity_mask_tex != null:
		shader_material.set_shader_parameter("cavity_mask", _cavity_mask_tex)


func set_fill_level(level: float) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fill_level", clampf(level, 0.0, 1.0))


func get_metrics() -> Dictionary:
	return _metrics


func get_texture_size() -> Vector2:
	return _texture_size


func _meniscus_uv(fill_level: float) -> float:
	var top := float(_metrics.get("interior_top", 0.118))
	var bottom := float(_metrics.get("interior_bottom", 0.947))
	return top + (1.0 - fill_level) * (bottom - top)


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


func _uses_letterbox_fit() -> bool:
	return get_parent() is not AspectRatioContainer


func _texture_to_control_uv(texture_uv_coord: Vector2) -> Vector2:
	if not _uses_letterbox_fit():
		return texture_uv_coord
	var fit := FlaskInteriorMetrics.texture_fit_rect(_texture_size, _rect_size)
	var uv_scale: Vector2 = fit["uv_scale"]
	var uv_offset: Vector2 = fit["uv_offset"]
	return Vector2(
		uv_offset.x + texture_uv_coord.x * uv_scale.x,
		uv_offset.y + texture_uv_coord.y * uv_scale.y
	)


func _home_pixel(seed: float, fill_level: float) -> Vector2:
	var anchor_x := _hash11(seed * 2.11) - 0.5
	var meniscus_y := _meniscus_uv(fill_level)
	var bottom := float(_metrics.get("interior_bottom", 0.947))
	var fill_span := maxf(0.001, bottom - meniscus_y)
	var depth_roll := _hash11(seed * 3.07)
	var center_x := float(_metrics.get("center_x", 0.5))
	var half_w := float(_metrics.get("half_width", 0.109))
	var width_scale := lerpf(0.5, 1.0, sqrt(depth_roll))
	var home_texture := Vector2(
		center_x + anchor_x * half_w * 1.3 * width_scale,
		meniscus_y + depth_roll * fill_span * 0.92 + fill_span * 0.04
	)
	var home_control := _texture_to_control_uv(home_texture)
	return Vector2(home_control.x * _rect_size.x, home_control.y * _rect_size.y)


func _process(_delta: float) -> void:
	if _spawner == null or not _spawner.has_method("spawn_at_pop"):
		return

	var shader_material := material as ShaderMaterial
	var fill_level := 0.0
	if shader_material:
		fill_level = float(shader_material.get_shader_parameter("fill_level"))

	if fill_level < 0.02:
		_last_life.clear()
		return

	var time := Time.get_ticks_msec() * 0.001
	for layer in 3:
		for i in 22:
			var seed := float(i + layer * 97)
			var life := _bubble_life(time, seed)
			var key := str(seed)
			var prev: float = _last_life.get(key, 0.0)
			if prev < 0.12 and life >= 0.12:
				var size_roll := _hash11(seed * 4.19)
				if size_roll > 0.35:
					_spawner.spawn_at_pop(_home_pixel(seed, fill_level), size_roll)
			_last_life[key] = life

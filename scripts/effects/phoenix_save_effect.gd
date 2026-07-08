class_name PhoenixSaveEffect
extends Node2D

const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")

const BEAM_COUNT := 20
const DURATION := 1.35
const PEAK_TIME := 0.5
const Z_INDEX := 215

var _elapsed := 0.0
var _origin := Vector2.ZERO
var _viewport_size := Vector2(1024.0, 576.0)
var _beams: Array[Dictionary] = []
var _wash: ColorRect
var _core: Polygon2D
var _ring: Polygon2D
var _on_complete := Callable()


static func play(
	layer: CanvasLayer,
	origin_global: Vector2,
	on_complete: Callable = Callable()
) -> void:
	if layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var effect := PhoenixSaveEffect.new()
	layer.add_child(effect)
	effect.z_index = Z_INDEX
	effect._on_complete = on_complete
	effect._origin = _IngredientFlyUtil.to_layer_position(layer, origin_global)
	effect.set_process(true)


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		_viewport_size = Vector2(1024.0, 576.0)
	_spawn_wash()
	_spawn_core()
	_spawn_ring()
	_spawn_beams()


func _spawn_wash() -> void:
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.position = Vector2.ZERO
	_wash.size = _viewport_size
	_wash.color = Color(1.0, 0.94, 0.72, 0.0)
	add_child(_wash)


func _spawn_core() -> void:
	_core = Polygon2D.new()
	_core.color = Color(1.0, 0.98, 0.82, 0.95)
	_core.polygon = PackedVector2Array(
		[
			Vector2(0.0, -18.0),
			Vector2(16.0, 0.0),
			Vector2(0.0, 18.0),
			Vector2(-16.0, 0.0),
		]
	)
	_core.position = _origin
	add_child(_core)


func _spawn_ring() -> void:
	_ring = Polygon2D.new()
	_ring.color = Color(1.0, 0.86, 0.42, 0.55)
	var points := PackedVector2Array()
	var sides := 24
	for side_index in sides:
		var angle := TAU * float(side_index) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * 28.0)
	_ring.polygon = points
	_ring.position = _origin
	add_child(_ring)


func _spawn_beams() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reach := _viewport_size.length() * 0.92

	for beam_index in BEAM_COUNT:
		var angle := TAU * float(beam_index) / float(BEAM_COUNT)
		angle += rng.randf_range(-0.07, 0.07)
		var width := rng.randf_range(16.0, 34.0)
		var length := reach * rng.randf_range(0.82, 1.08)
		var tint := Color(
			1.0,
			rng.randf_range(0.86, 0.98),
			rng.randf_range(0.42, 0.72),
			rng.randf_range(0.55, 0.9)
		)

		var beam := Polygon2D.new()
		beam.color = tint
		beam.polygon = _beam_polygon(width, length)
		beam.position = _origin
		beam.rotation = angle
		add_child(beam)

		_beams.append(
			{
				"node": beam,
				"length": length,
				"width": width,
				"wobble_speed": rng.randf_range(2.5, 4.5),
				"wobble_phase": rng.randf_range(0.0, TAU),
				"peak_alpha": tint.a,
			}
		)


func _beam_polygon(width: float, length: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(-width * 0.5, -length),
			Vector2(width * 0.5, -length),
		]
	)


func _process(delta: float) -> void:
	_elapsed += delta
	var rise := clampf(_elapsed / PEAK_TIME, 0.0, 1.0)
	var rise_eased := _ease_out_cubic(rise)
	var falloff := 1.0
	if _elapsed > PEAK_TIME:
		falloff = 1.0 - clampf(
			(_elapsed - PEAK_TIME) / maxf(DURATION - PEAK_TIME, 0.001),
			0.0,
			1.0
		)
	var intensity := rise_eased * falloff

	if _wash != null:
		_wash.color = Color(1.0, 0.94, 0.72, intensity * 0.48)

	if _core != null:
		var core_scale := lerpf(0.35, 2.4, rise_eased) * lerpf(1.0, 0.65, 1.0 - falloff)
		_core.scale = Vector2(core_scale, core_scale)
		_core.modulate.a = intensity

	if _ring != null:
		var ring_scale := lerpf(0.2, 5.5, rise_eased)
		_ring.scale = Vector2(ring_scale, ring_scale)
		_ring.modulate.a = intensity * 0.7

	for beam in _beams:
		var node := beam["node"] as Polygon2D
		if node == null or not is_instance_valid(node):
			continue
		var length := float(beam["length"]) * rise_eased
		var width := float(beam["width"])
		var wobble := sin(
			_elapsed * float(beam["wobble_speed"]) + float(beam["wobble_phase"])
		)
		width *= 1.0 + wobble * 0.18
		node.polygon = _beam_polygon(width, length)
		node.modulate.a = float(beam["peak_alpha"]) * intensity

	if _elapsed >= DURATION:
		set_process(false)
		if _on_complete.is_valid():
			_on_complete.call()
		queue_free()


static func _ease_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
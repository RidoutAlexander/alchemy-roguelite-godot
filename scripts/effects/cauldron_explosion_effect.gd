class_name CauldronExplosionEffect
extends Node2D

const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")
const EFFECT_SCENE := preload("res://scenes/effects/cauldron_explosion.tscn")

const EXPAND_DURATION := 1.2
const SPLATTER_FIT := 0.54
const HOLD_DURATION := 0.35
const Z_INDEX := 200

var _wave_overlay: ColorRect
var _shader_material: ShaderMaterial
var _shake_strength := 0.0


static func play(
	layer: CanvasLayer,
	origin_global: Vector2,
	on_complete: Callable = Callable()
) -> void:
	if layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return

	var effect := EFFECT_SCENE.instantiate() as CauldronExplosionEffect
	layer.add_child(effect)
	effect.z_index = Z_INDEX
	effect._run(origin_global, on_complete)


func _ready() -> void:
	_wave_overlay = $WaveOverlay
	_shader_material = _wave_overlay.material as ShaderMaterial


func _run(origin_global: Vector2, on_complete: Callable) -> void:
	await get_tree().process_frame

	var layer := get_parent() as CanvasLayer
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1024.0, 576.0)

	_fit_wave_overlay(viewport_size)

	var layer_origin := _IngredientFlyUtil.to_layer_position(layer, origin_global)
	var origin_uv := Vector2(
		layer_origin.x / viewport_size.x,
		layer_origin.y / viewport_size.y
	)
	var max_scale := _compute_max_scale(origin_uv, viewport_size)

	if _shader_material:
		_shader_material.set_shader_parameter("burst_origin", origin_uv)
		_shader_material.set_shader_parameter("max_scale", max_scale)
		_shader_material.set_shader_parameter("expand_t", 0.0)

	_play_phases(on_complete)


func _fit_wave_overlay(viewport_size: Vector2) -> void:
	_wave_overlay.position = Vector2.ZERO
	_wave_overlay.size = viewport_size


func _compute_max_scale(origin_uv: Vector2, viewport_size: Vector2) -> float:
	var aspect := viewport_size.x / viewport_size.y
	var corners := [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	]
	var max_radius := 0.0
	for corner in corners:
		var delta := Vector2(
			(corner.x - origin_uv.x) * aspect,
			corner.y - origin_uv.y
		)
		max_radius = maxf(max_radius, delta.length())
	return max_radius * SPLATTER_FIT


func _play_phases(on_complete: Callable) -> void:
	var sequence := create_tween()
	sequence.set_parallel(false)

	sequence.tween_method(
		func(t: float) -> void:
			_set_shader_phase("expand_t", t)
			_shake_strength = (1.0 - t * 0.65) * 4.5,
		0.0,
		1.0,
		EXPAND_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	sequence.tween_callback(func() -> void:
		_shake_strength = 0.0
	)

	sequence.tween_interval(HOLD_DURATION)
	sequence.finished.connect(
		func() -> void:
			if on_complete.is_valid():
				on_complete.call()
			queue_free()
	)

	set_process(true)


func _set_shader_phase(param: StringName, value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter(param, clampf(value, 0.0, 1.0))


func _process(_delta: float) -> void:
	if _shake_strength <= 0.01:
		position = Vector2.ZERO
		return
	position = Vector2(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength)
	)
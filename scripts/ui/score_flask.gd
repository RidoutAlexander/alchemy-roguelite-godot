class_name ScoreFlask
extends Control

const FILL_SPEED := 0.45
const PULSE_SCALE_MIN := 1.0
const PULSE_SCALE_MAX := 1.07
const PULSE_DURATION := 0.85

@onready var _pulse_container: Control = $PulseContainer
@onready var _liquid: TextureRect = $PulseContainer/FlaskAspect/FlaskLiquid
@onready var _frame: TextureRect = $PulseContainer/FlaskAspect/FlaskFrame
@onready var _score_label: Label = $PulseContainer/ScoreLabel
@onready var _complete_label: Label = $PulseContainer/CompleteLabel
@onready var _spawner: Node2D = $PulseContainer/FlaskAspect/FlaskLiquid/EscapeBubbleSpawner

var _display_fill: float = 0.0
var _is_complete: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _complete_label != null:
		_complete_label.visible = false
	_pulse_container.scale = Vector2.ONE
	_pulse_container.pivot_offset = _pulse_container.size * 0.5
	resized.connect(_on_resized)
	GameManager.brew_stats_presented.connect(_on_brew_stats_presented)
	_on_resized()
	set_process(true)


func _on_brew_stats_presented(_ctx: BrewContext) -> void:
	_force_refresh()


func _on_resized() -> void:
	if _pulse_container == null:
		return
	_pulse_container.pivot_offset = _pulse_container.size * 0.5
	_update_meniscus_spawner()


func _process(delta: float) -> void:
	if _liquid == null or _pulse_container == null:
		return
	var session := GameManager.run.brew_session
	var ctx := session.context
	if ctx == null or ctx.current_aura == null:
		return

	var target_fill := _target_fill_for_session(session, ctx)
	if target_fill <= 0.0:
		_display_fill = 0.0
	elif target_fill > _display_fill:
		_display_fill = move_toward(_display_fill, target_fill, delta * FILL_SPEED)
	else:
		_display_fill = target_fill

	_apply_fill_visuals(session, ctx)


func _force_refresh() -> void:
	if _liquid == null or _pulse_container == null:
		return
	var session := GameManager.run.brew_session
	var ctx := session.context
	if ctx == null or ctx.current_aura == null:
		return
	_apply_fill_visuals(session, ctx)


func _target_fill_for_session(session: BrewSession, ctx: BrewContext) -> float:
	if ctx.threshold <= 0:
		return 0.0
	return clampf(
		float(session.presented_score) / float(ctx.threshold),
		0.0,
		1.0
	)


func _apply_fill_visuals(session: BrewSession, ctx: BrewContext) -> void:
	var is_boss := ctx.is_boss_level()
	var display_score := session.presented_score
	_update_score_label(display_score, ctx.threshold, is_boss, session)

	if display_score <= 0 and _is_complete:
		_is_complete = false

	_set_particle_effects_enabled(display_score > 0)
	if _liquid.has_method("set_fill_level"):
		_liquid.set_fill_level(_display_fill)
	else:
		var shader_material := _liquid.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("fill_level", _display_fill)

	_update_meniscus_spawner()

	var should_complete := false
	if not is_boss:
		should_complete = display_score > 0
	if should_complete != _is_complete:
		_is_complete = should_complete
	_refresh_complete_presentation(is_boss)


func _update_score_label(
	score: int,
	threshold: int,
	is_boss: bool,
	session: BrewSession
) -> void:
	if _score_label == null:
		return
	var display_score := maxi(0, score)
	var display_threshold := maxi(0, threshold)
	if is_boss:
		_score_label.text = "%d/%d" % [display_score, display_threshold]
		return

	var modifier_suffix := ""
	var run := GameManager.run
	if run != null:
		var boss_penalty := run.boss_threshold_penalty
		var boss_discount := run.boss_threshold_discount
		if session != null:
			boss_discount += session.presented_boss_threshold_discount_gained
		modifier_suffix = _format_boss_threshold_modifier_suffix(boss_penalty, boss_discount)

	_score_label.text = "%d/%d%s" % [display_score, display_threshold, modifier_suffix]


func _format_boss_threshold_modifier_suffix(penalty: int, discount: int) -> String:
	var net_adjustment := penalty - discount
	if net_adjustment == 0:
		return ""
	if net_adjustment > 0:
		return " (+%d boss)" % net_adjustment
	return " (%d boss)" % net_adjustment


func _set_particle_effects_enabled(enabled: bool) -> void:
	if _spawner == null:
		return
	if _spawner.has_method("set_effects_enabled"):
		_spawner.set_effects_enabled(enabled)


func _update_meniscus_spawner() -> void:
	if _spawner == null or not _spawner.has_method("set_fill_region"):
		return

	var metrics: Dictionary = {}
	if _liquid.has_method("get_metrics"):
		metrics = _liquid.get_metrics()

	var liquid_size := _liquid.size
	var top := float(metrics.get("interior_top", 0.130))
	var bottom := float(metrics.get("interior_bottom", 0.877))
	var center_x := float(metrics.get("center_x", 0.498))
	var half_w := float(metrics.get("half_width", 0.086))
	var meniscus_uv := top + (1.0 - _display_fill) * (bottom - top)
	_spawner.set_fill_region(
		liquid_size.x * center_x,
		liquid_size.x * half_w * 0.82,
		liquid_size.y * meniscus_uv,
		liquid_size.y * bottom
	)


func _is_hand_phase_blocking_stop() -> bool:
	var run := GameManager.run
	if run == null:
		return false
	return run.brew_session.is_hand_interaction_blocked()


func _refresh_complete_presentation(is_boss: bool) -> void:
	if is_boss:
		if _complete_label != null:
			_complete_label.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_stop_pulse()
		return

	var show_cta := _is_complete and not _is_hand_phase_blocking_stop()
	if _complete_label != null:
		_complete_label.visible = show_cta
		if show_cta:
			_complete_label.text = "Stop Brewing"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if show_cta else Control.CURSOR_ARROW
	if show_cta:
		if _pulse_tween == null or not _pulse_tween.is_valid():
			_start_pulse()
	else:
		_stop_pulse()


func _start_pulse() -> void:
	if _pulse_container == null:
		return
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(
		_pulse_container,
		"scale",
		Vector2.ONE * PULSE_SCALE_MAX,
		PULSE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(
		_pulse_container,
		"scale",
		Vector2.ONE * PULSE_SCALE_MIN,
		PULSE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _pulse_container != null:
		_pulse_container.scale = Vector2.ONE


func _gui_input(event: InputEvent) -> void:
	if GameManager.run != null and GameManager.run.brew_session.context.is_boss_level():
		return
	if not _is_complete:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.can_end_brew():
			GameManager.try_end_brew()
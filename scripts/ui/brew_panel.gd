class_name BrewPanel
extends Control

const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")
const _CauldronExplosionEffect := preload("res://scripts/effects/cauldron_explosion_effect.gd")
const PREVIEW_SCALE := 0.38
const FLY_ART_SIZE := Vector2(96.0, 96.0)
const POST_PLOP_EXPLOSION_DELAY := 0.2
const BOILING_BASE_PITCH := 0.9
const BOILING_MAX_PITCH_MULT := 2.0
const BOILING_FILL_SPEED := 0.45
const BOILING_MAX_VOLUME_MULT := 1.5
const PLOP_PITCH_MIN := 0.7
const PLOP_PITCH_MAX := 1.3

@onready var _fly_layer: CanvasLayer = $DrawFlyLayer
@onready var _explosion_layer: CanvasLayer = $ExplosionLayer
@onready var _bag_anchor: Control = $BagDrawAnchor
@onready var _cauldron_target: Control = $CauldronDrawTarget
@onready var _cauldron_liquid: Control = $CauldronLiquid
@onready var _preview_host: Control = $DrawnCardPreviewHost
@onready var _preview_card: IngredientCard = $DrawnCardPreviewHost/DrawnCardPreview
@onready var _cauldron_plop_player: AudioStreamPlayer = $CauldronPlopPlayer
@onready var _boiling_water_player: AudioStreamPlayer = $BoilingWaterPlayer
@onready var _cauldron_explosion_player: AudioStreamPlayer = $CauldronExplosionPlayer
@onready var _eyeball_puzzle: EyeballPuzzleOverlay = $"../../EyeballPuzzleOverlay"

var _brew_exit_animations_pending: int = 0
var _pending_frog_escape: IngredientData = null
var _brew_ambience_suppressed: bool = false
var _pending_brew_exit_outcome: int = -1
var _cauldron_base_scale: Vector2 = Vector2.ONE
var _cauldron_base_modulate: Color = Color.WHITE
var _boiling_fill_display: float = 0.0
var _boiling_base_volume_db: float = 0.0


func _ready() -> void:
	if _cauldron_liquid != null:
		_cauldron_base_scale = _cauldron_liquid.scale
		_cauldron_base_modulate = _cauldron_liquid.modulate
	if _boiling_water_player != null:
		_boiling_base_volume_db = _boiling_water_player.volume_db
	_clear_preview()
	GameManager.ingredient_drawn.connect(_on_ingredient_drawn)
	GameManager.frog_leg_escaped.connect(_on_frog_leg_escaped)
	GameManager.brew_updated.connect(_on_brew_updated)
	GameManager.brew_completion_requested.connect(_on_brew_completion_requested)
	GameManager.eyeball_puzzle_requested.connect(_on_eyeball_puzzle_requested)
	GameManager.bat_wing_picker_requested.connect(_on_bat_wing_picker_requested)
	if _eyeball_puzzle != null:
		_eyeball_puzzle.completed.connect(_on_eyeball_puzzle_completed)
		_eyeball_puzzle.picker_completed.connect(_on_bat_wing_picker_completed)
	visibility_changed.connect(_sync_brew_ambience)
	_sync_brew_ambience()
	set_process(true)


func _on_brew_updated(ctx: BrewContext) -> void:
	if ctx.outcome == BrewOutcome.Outcome.IN_PROGRESS:
		_brew_ambience_suppressed = false
		if ctx.score <= 0:
			_boiling_fill_display = 0.0
			if _cauldron_liquid != null:
				_reset_cauldron_liquid()
		_sync_brew_ambience()
	if ctx.drawn_this_brew.is_empty() and ctx.outcome == BrewOutcome.Outcome.IN_PROGRESS:
		_clear_preview()
		if (
			ctx.score == 0
			and ctx.explosiveness == 0
			and _eyeball_puzzle != null
			and _eyeball_puzzle.visible
		):
			_eyeball_puzzle.hide_puzzle()


func _on_ingredient_drawn(ctx: BrewContext, ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	GameManager.set_presentation_in_progress(true)
	_show_preview(ingredient)
	var brew_ended := ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS
	_play_draw_fly(ingredient, brew_ended)


func _on_eyeball_puzzle_requested(reserved: Array) -> void:
	_clear_preview()
	if _eyeball_puzzle == null:
		GameManager.complete_eyeball_puzzle(reserved)
		return
	_eyeball_puzzle.show_puzzle(reserved)


func _on_eyeball_puzzle_completed(ordered: Array) -> void:
	GameManager.complete_eyeball_puzzle(ordered)


func _on_bat_wing_picker_requested(choices: Array) -> void:
	_clear_preview()
	if _eyeball_puzzle == null:
		if not choices.is_empty():
			GameManager.complete_bat_wing_picker(choices[0])
		return
	_eyeball_puzzle.show_picker(choices)


func _on_frog_leg_escaped(ingredient: IngredientData) -> void:
	_pending_frog_escape = ingredient


func _on_bat_wing_picker_completed(selected: IngredientData) -> void:
	GameManager.complete_bat_wing_picker(selected)


func _on_brew_completion_requested(outcome: int) -> void:
	if outcome == BrewOutcome.Outcome.EXPLODED:
		_pending_brew_exit_outcome = outcome
		_try_play_pending_brew_exit_effects()
	else:
		_play_brew_exit_effects(outcome)
	call_deferred("_try_finalize_brew_transition")


func _try_play_pending_brew_exit_effects_after_plop() -> void:
	var timer := get_tree().create_timer(POST_PLOP_EXPLOSION_DELAY)
	timer.timeout.connect(
		func() -> void:
			_try_play_pending_brew_exit_effects(),
		CONNECT_ONE_SHOT
	)


func _try_play_pending_brew_exit_effects() -> void:
	if _pending_brew_exit_outcome != BrewOutcome.Outcome.EXPLODED:
		return
	if _brew_exit_animations_pending > 0:
		return
	_pending_brew_exit_outcome = -1
	_play_brew_exit_effects(BrewOutcome.Outcome.EXPLODED)


func _play_brew_exit_effects(outcome: int) -> void:
	if outcome != BrewOutcome.Outcome.EXPLODED:
		return

	_brew_exit_animations_pending += 1
	_play_cauldron_explosion()
	var origin := _rupture_cauldron_then_explode()
	_CauldronExplosionEffect.play(
		_explosion_layer,
		origin,
		func() -> void:
			_on_brew_exit_animation_finished()
	)


func _rupture_cauldron_then_explode() -> Vector2:
	if _cauldron_liquid == null:
		if _cauldron_target != null:
			return _cauldron_target.get_global_rect().get_center()
		return Vector2.ZERO

	var origin := _cauldron_liquid.get_global_rect().get_center()
	if _cauldron_liquid.has_method("set_activity_level"):
		_cauldron_liquid.set_activity_level(1.0)

	var rupture := create_tween()
	rupture.tween_property(
		_cauldron_liquid,
		"scale",
		_cauldron_base_scale * Vector2(1.12, 1.38),
		0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rupture.parallel().tween_property(
		_cauldron_liquid,
		"modulate",
		Color(1.45, 1.15, 1.65, 1.0),
		0.1
	)
	rupture.tween_callback(
		func() -> void:
			if _cauldron_liquid != null:
				_cauldron_liquid.visible = false
	)
	return origin


func _reset_cauldron_liquid() -> void:
	if _cauldron_liquid == null:
		return
	_cauldron_liquid.visible = true
	_cauldron_liquid.scale = _cauldron_base_scale
	_cauldron_liquid.modulate = _cauldron_base_modulate
	if _cauldron_liquid.has_method("set_activity_level"):
		_cauldron_liquid.set_activity_level(0.0)


func _show_preview(ingredient: IngredientData) -> void:
	if _preview_card == null or _preview_host == null:
		return
	_preview_host.visible = true
	_preview_host.z_index = 20
	_preview_card.bind_preview(ingredient)


func _clear_preview() -> void:
	if _preview_host != null:
		_preview_host.visible = false


func _process(delta: float) -> void:
	_update_score_fill_display(delta)

	if (
		_boiling_water_player == null
		or not _boiling_water_player.playing
		or _brew_ambience_suppressed
		or GameManager.run == null
	):
		return

	var ctx := GameManager.run.brew_session.context
	if ctx == null or ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return

	_apply_boiling_pitch(_boiling_fill_display)


func _update_score_fill_display(delta: float) -> void:
	if GameManager.run == null:
		_set_cauldron_activity(0.0)
		return

	var ctx := GameManager.run.brew_session.context
	if ctx == null or ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_set_cauldron_activity(0.0)
		return

	var target_fill := _score_fill_ratio(ctx)
	if target_fill <= 0.0:
		_boiling_fill_display = 0.0
	elif target_fill > _boiling_fill_display:
		_boiling_fill_display = move_toward(
			_boiling_fill_display,
			target_fill,
			delta * BOILING_FILL_SPEED
		)
	else:
		_boiling_fill_display = target_fill

	_set_cauldron_activity(_boiling_fill_display)


func _set_cauldron_activity(level: float) -> void:
	if _cauldron_liquid == null or not _cauldron_liquid.has_method("set_activity_level"):
		return
	_cauldron_liquid.set_activity_level(level)


func _score_fill_ratio(ctx: BrewContext) -> float:
	if ctx.threshold <= 0:
		return 0.0
	return clampf(float(ctx.score) / float(ctx.threshold), 0.0, 1.0)


func _apply_boiling_pitch(fill_ratio: float) -> void:
	if _boiling_water_player == null:
		return
	var max_pitch := BOILING_BASE_PITCH * BOILING_MAX_PITCH_MULT
	_boiling_water_player.pitch_scale = lerpf(BOILING_BASE_PITCH, max_pitch, fill_ratio)
	var volume_mult := lerpf(1.0, BOILING_MAX_VOLUME_MULT, fill_ratio)
	_boiling_water_player.volume_db = _boiling_base_volume_db + linear_to_db(volume_mult)


func _sync_brew_ambience() -> void:
	if _boiling_water_player == null:
		return
	if not visible or _brew_ambience_suppressed:
		_boiling_water_player.stop()
		return
	if not _boiling_water_player.playing:
		_apply_boiling_pitch(_boiling_fill_display)
		_boiling_water_player.play()


func _play_cauldron_explosion() -> void:
	_brew_ambience_suppressed = true
	if _boiling_water_player != null:
		_boiling_water_player.stop()
	if _cauldron_explosion_player == null:
		return
	_cauldron_explosion_player.stop()
	_cauldron_explosion_player.play()


func _play_cauldron_plop() -> void:
	if _cauldron_plop_player == null:
		return
	_cauldron_plop_player.pitch_scale = randf_range(PLOP_PITCH_MIN, PLOP_PITCH_MAX)
	_cauldron_plop_player.stop()
	_cauldron_plop_player.play()


func _play_draw_fly(ingredient: IngredientData, track_for_exit: bool) -> void:
	var fly_data := _fly_data_for(ingredient)
	if fly_data.is_empty():
		if track_for_exit:
			_on_brew_exit_animation_finished()
			_try_play_pending_brew_exit_effects()
		GameManager.notify_ingredient_presentation_finished()
		return

	if track_for_exit:
		_brew_exit_animations_pending += 1

	_IngredientFlyUtil.play(
		_fly_layer,
		fly_data["texture"],
		fly_data["start_center"],
		fly_data["target_center"],
		fly_data["size"],
		func() -> void:
			_finish_ingredient_presentation(ingredient, track_for_exit),
		func() -> void:
			_play_cauldron_plop()
			if track_for_exit:
				_try_play_pending_brew_exit_effects_after_plop()
	)


func _finish_ingredient_presentation(ingredient: IngredientData, track_for_exit: bool) -> void:
	if _pending_frog_escape == ingredient:
		_pending_frog_escape = null
		_play_frog_escape(
			ingredient,
			func() -> void:
				if track_for_exit:
					_on_brew_exit_animation_finished()
				GameManager.notify_ingredient_presentation_finished()
		)
		return
	if track_for_exit:
		_on_brew_exit_animation_finished()
	GameManager.notify_ingredient_presentation_finished()


func _play_frog_escape(ingredient: IngredientData, on_complete: Callable) -> void:
	if ingredient == null:
		on_complete.call()
		return
	var fly_data := _escape_fly_data_for(ingredient)
	if fly_data.is_empty():
		on_complete.call()
		return
	_IngredientFlyUtil.play_escape_right(
		_fly_layer,
		fly_data["texture"],
		fly_data["start_center"],
		fly_data["size"],
		on_complete
	)


func _escape_fly_data_for(ingredient: IngredientData) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _cauldron_target == null:
		return {}
	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": _cauldron_target.get_global_rect().get_center(),
	}


func _on_brew_exit_animation_finished() -> void:
	_brew_exit_animations_pending = maxi(0, _brew_exit_animations_pending - 1)
	_try_finalize_brew_transition()


func _try_finalize_brew_transition() -> void:
	if not GameManager.is_brew_transition_pending():
		return
	if _pending_brew_exit_outcome != -1:
		return
	if _brew_exit_animations_pending > 0:
		return
	GameManager.finalize_brew_transition()


func _fly_data_for(ingredient: IngredientData) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _bag_anchor == null or _cauldron_target == null:
		return {}
	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": _bag_anchor.get_global_rect().get_center(),
		"target_center": _cauldron_target.get_global_rect().get_center(),
	}


func _load_ingredient_texture(ingredient: IngredientData) -> Texture2D:
	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		return load(art_path)
	return null
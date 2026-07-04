class_name BrewPanel
extends Control

const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")
const _CauldronExplosionEffect := preload("res://scripts/effects/cauldron_explosion_effect.gd")
const FLY_ART_SIZE := Vector2(96.0, 96.0)
const POST_PLOP_EXPLOSION_DELAY := 0.2
const BOILING_BASE_PITCH := 0.9
const BOILING_MAX_PITCH_MULT := 2.0
const BOILING_FILL_SPEED := 0.45
const BOILING_MAX_VOLUME_MULT := 1.5
const PLOP_PITCH_MIN := 0.7
const PLOP_PITCH_MAX := 1.3
const PLAY_HAND_BUTTON_SCALE := 1.1
const HAND_ACTION_LEFT_GAP := 30.0
const HAND_ACTION_EXTRA_OFFSET := 100.0
const HAND_ACTION_BUTTON_SIZE := Vector2(88.0, 88.0)
const HAND_ACTION_LABEL_SIZE := Vector2(88.0, 24.0)
const HAND_ACTION_LABEL_GAP := 4.0
const HAND_ACTION_GROUP_GAP := 8.0

@onready var _fly_layer: CanvasLayer = $DrawFlyLayer
@onready var _explosion_layer: CanvasLayer = $ExplosionLayer
@onready var _bag_anchor: Control = $BagDrawAnchor
@onready var _cauldron_target: Control = $CauldronDrawTarget
@onready var _cauldron_liquid: Control = $CauldronLiquid
@onready var _cauldron_plop_player: AudioStreamPlayer = $CauldronPlopPlayer
@onready var _boiling_water_player: AudioStreamPlayer = $BoilingWaterPlayer
@onready var _cauldron_explosion_player: AudioStreamPlayer = $CauldronExplosionPlayer
@onready var _cauldron_button: BaseButton = $CauldronTarget/CauldronButton
@onready var _cauldron_contents: BagContentsOverlay = $CauldronContentsOverlay
@onready var _player_hand: PlayerHandRow = $PlayerHandRow
@onready var _play_hand_button: WoodenButton = $PlayHandButton
@onready var _hand_undo_button: ShopRerollButton = $HandUndoButton
@onready var _hand_undo_label: Label = $HandUndoLabel
@onready var _hand_mulligan_button: ShopRerollButton = $HandMulliganButton
@onready var _hand_mulligan_label: Label = $HandMulliganLabel
@onready var _eyeball_puzzle: EyeballPuzzleOverlay = $"../../EyeballPuzzleOverlay"

var _brew_exit_animations_pending: int = 0
var _pending_frog_escape: IngredientData = null
var _brew_ambience_suppressed: bool = false
var _pending_brew_exit_outcome: int = -1
var _cauldron_base_scale: Vector2 = Vector2.ONE
var _cauldron_base_modulate: Color = Color.WHITE
var _boiling_fill_display: float = 0.0
var _boiling_base_volume_db: float = 0.0
var _pending_hand_draw: Array = []
var _pending_hand_draw_index: int = 0


func _ready() -> void:
	if _cauldron_liquid != null:
		_cauldron_base_scale = _cauldron_liquid.scale
		_cauldron_base_modulate = _cauldron_liquid.modulate
	if _boiling_water_player != null:
		_boiling_base_volume_db = _boiling_water_player.volume_db

	GameManager.hand_draw_batch_started.connect(_on_hand_draw_batch_started)
	GameManager.hand_mulligan_started.connect(_on_hand_mulligan_started)
	GameManager.hand_card_played.connect(_on_hand_card_played)
	GameManager.ingredient_drawn.connect(_on_ingredient_drawn)
	GameManager.frog_leg_escaped.connect(_on_frog_leg_escaped)
	GameManager.brew_updated.connect(_on_brew_updated)
	GameManager.brew_completion_requested.connect(_on_brew_completion_requested)
	GameManager.eyeball_puzzle_requested.connect(_on_eyeball_puzzle_requested)
	GameManager.bat_wing_picker_requested.connect(_on_bat_wing_picker_requested)

	if _eyeball_puzzle != null:
		_eyeball_puzzle.completed.connect(_on_eyeball_puzzle_completed)
		_eyeball_puzzle.picker_completed.connect(_on_bat_wing_picker_completed)
	if _cauldron_button != null and not _cauldron_button.pressed.is_connected(_on_cauldron_button_pressed):
		_cauldron_button.pressed.connect(_on_cauldron_button_pressed)
	if _play_hand_button != null and not _play_hand_button.pressed.is_connected(_on_play_hand_pressed):
		_play_hand_button.pressed.connect(_on_play_hand_pressed)
	if _hand_undo_button != null and not _hand_undo_button.pressed.is_connected(_on_hand_undo_pressed):
		_hand_undo_button.pressed.connect(_on_hand_undo_pressed)
	if _hand_mulligan_button != null and not _hand_mulligan_button.pressed.is_connected(
		_on_hand_mulligan_pressed
	):
		_hand_mulligan_button.pressed.connect(_on_hand_mulligan_pressed)
	if _player_hand != null:
		_player_hand.swap_requested.connect(_on_hand_swap_requested)
		if not _player_hand.selection_changed.is_connected(_on_hand_selection_changed):
			_player_hand.selection_changed.connect(_on_hand_selection_changed)
	if _play_hand_button != null:
		_play_hand_button.scale = Vector2.ONE * PLAY_HAND_BUTTON_SCALE

	visibility_changed.connect(_on_visibility_changed)
	visibility_changed.connect(_sync_brew_ambience)
	_sync_hand_ui()
	_sync_brew_ambience()
	set_process(true)


func _on_visibility_changed() -> void:
	if not visible:
		_hide_cauldron_contents()


func _on_cauldron_button_pressed() -> void:
	if _cauldron_contents == null or GameManager.run == null:
		return
	var ctx := GameManager.run.brew_session.context
	_cauldron_contents.toggle_cauldron(ctx.cauldron_contents)


func _hide_cauldron_contents() -> void:
	if _cauldron_contents != null:
		_cauldron_contents.hide_overlay()


func _refresh_cauldron_contents_if_open() -> void:
	if _cauldron_contents == null or GameManager.run == null:
		return
	if not _cauldron_contents.is_open():
		return
	var ctx := GameManager.run.brew_session.context
	_cauldron_contents.show_cauldron_contents(ctx.cauldron_contents)


func _on_brew_updated(_ctx: BrewContext) -> void:
	_refresh_cauldron_contents_if_open()
	_sync_hand_ui()
	if _ctx.outcome == BrewOutcome.Outcome.IN_PROGRESS:
		_brew_ambience_suppressed = false
		if _ctx.score <= 0:
			_boiling_fill_display = 0.0
			if _cauldron_liquid != null:
				_reset_cauldron_liquid()
		_sync_brew_ambience()


func _on_hand_draw_batch_started(drawn: Array) -> void:
	_pending_hand_draw = drawn.duplicate()
	_pending_hand_draw_index = 0
	GameManager.set_presentation_in_progress(true)
	if _player_hand != null:
		_player_hand.visible = true
		_player_hand.prepare_for_draw()
	_set_play_undo_visible(false)
	_play_next_hand_draw_animation()


func _play_next_hand_draw_animation() -> void:
	if _pending_hand_draw_index >= _pending_hand_draw.size():
		_pending_hand_draw.clear()
		_pending_hand_draw_index = 0
		GameManager.notify_hand_draw_batch_finished()
		return

	var ingredient: IngredientData = _pending_hand_draw[_pending_hand_draw_index]
	var slot_index := _pending_hand_draw.size() - 1 - _pending_hand_draw_index
	_play_hand_draw_fly(ingredient, slot_index)


func _play_hand_draw_fly(ingredient: IngredientData, slot_index: int) -> void:
	if GameManager.run != null:
		GameManager.run.brew_session.consume_hand_draw_display_reserve()
		GameManager.notify_bag_display_changed()
	var fly_data := _hand_draw_fly_data_for(ingredient, slot_index)
	if fly_data.is_empty():
		_on_hand_draw_landed(ingredient, slot_index)
		return

	_IngredientFlyUtil.play(
		_fly_layer,
		fly_data["texture"],
		fly_data["start_center"],
		fly_data["target_center"],
		fly_data["size"],
		func() -> void:
			_on_hand_draw_landed(ingredient, slot_index)
	)


func _on_hand_draw_landed(ingredient: IngredientData, slot_index: int) -> void:
	if _player_hand != null:
		_player_hand.reveal_slot(slot_index, ingredient)
	_pending_hand_draw_index += 1
	_play_next_hand_draw_animation()


func _on_hand_card_played(_ctx: BrewContext, ingredient: IngredientData, slot_index: int) -> void:
	if ingredient == null:
		return
	_refresh_cauldron_contents_if_open()
	GameManager.set_presentation_in_progress(true)
	if _player_hand != null:
		_player_hand.hide_slot_for_fly(slot_index)
	var brew_ended := _ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS
	_play_hand_card_fly(ingredient, slot_index, brew_ended)


func _on_ingredient_drawn(ctx: BrewContext, ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	_refresh_cauldron_contents_if_open()
	GameManager.set_presentation_in_progress(true)
	var brew_ended := ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS
	_play_cauldron_fly(ingredient, brew_ended)


func _on_eyeball_puzzle_requested(reserved: Array) -> void:
	if _eyeball_puzzle == null:
		GameManager.complete_eyeball_puzzle()
		return
	_eyeball_puzzle.show_preview(reserved)


func _on_eyeball_puzzle_completed(_ordered: Array) -> void:
	GameManager.complete_eyeball_puzzle()


func _on_bat_wing_picker_requested(choices: Array) -> void:
	if _eyeball_puzzle == null:
		if not choices.is_empty():
			GameManager.complete_bat_wing_picker(choices[0])
		return
	_eyeball_puzzle.show_picker(choices)


func _on_frog_leg_escaped(ingredient: IngredientData) -> void:
	_pending_frog_escape = ingredient


func _on_bat_wing_picker_completed(selected: IngredientData) -> void:
	GameManager.complete_bat_wing_picker(selected)


func _on_play_hand_pressed() -> void:
	GameManager.try_play_hand()


func _on_hand_undo_pressed() -> void:
	if GameManager.run == null:
		return
	if not GameManager.run.brew_session.can_undo_hand_swap():
		_shake_hand_action_button(_hand_undo_button)
		return
	GameManager.try_undo_hand_swap()


func _on_hand_mulligan_pressed() -> void:
	if _player_hand == null:
		return
	if not _can_use_mulligan_now():
		_shake_hand_action_button(_hand_mulligan_button)
		return
	GameManager.try_mulligan(_player_hand.get_selected_slot())


func _on_hand_selection_changed(_slot_index: int) -> void:
	_sync_hand_ui()


func _on_hand_mulligan_started(
	old_ingredient: IngredientData,
	new_ingredient: IngredientData,
	slot_index: int
) -> void:
	_play_mulligan_animation(old_ingredient, new_ingredient, slot_index)


func _on_hand_swap_requested(from_slot: int, to_slot: int) -> void:
	if GameManager.run == null:
		return
	if GameManager.run.brew_session.get_hand_swaps_remaining() <= 0:
		_shake_hand_action_button(_hand_undo_button)
		return
	GameManager.try_swap_hand_slots(from_slot, to_slot)


func _on_brew_completion_requested(outcome: int) -> void:
	_sync_hand_ui()
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


func _sync_hand_ui() -> void:
	if GameManager.run == null:
		return
	var session := GameManager.run.brew_session
	var hand_phase := session.get_hand_phase()
	var can_interact := hand_phase == BrewSession.HandPhase.HAND
	var show_mulligan := _should_show_brew_mulligan()

	_set_mulligan_visible(show_mulligan)
	if show_mulligan:
		_refresh_mulligan_label(session)

	if hand_phase == BrewSession.HandPhase.DRAWING:
		if _player_hand != null:
			_player_hand.visible = true
		_set_play_undo_visible(false)
		if show_mulligan:
			call_deferred("_align_mulligan_control")
		return

	if _player_hand != null:
		var show_hand := (
			hand_phase != BrewSession.HandPhase.BAG
			or _hand_has_any_card(session.get_hand_slots())
		)
		_player_hand.visible = show_hand
		_player_hand.refresh_hand(
			session.get_hand_slots(),
			can_interact,
			can_interact
		)

	_set_play_undo_visible(can_interact)
	if _play_hand_button != null:
		_play_hand_button.disabled = not GameManager.can_play_hand()
	if can_interact:
		_refresh_undo_label(session)
	if can_interact:
		call_deferred("_align_hand_controls")
	elif show_mulligan:
		call_deferred("_align_mulligan_control")


func _align_hand_controls() -> void:
	_align_play_hand_button()
	_align_hand_action_buttons()


func _align_mulligan_control() -> void:
	if _hand_mulligan_button == null or not _hand_mulligan_button.visible:
		return
	var origin := _get_hand_action_column_origin()
	_position_hand_action_control(
		origin.x,
		origin.y,
		_hand_mulligan_button,
		_hand_mulligan_label
	)


func _get_hand_action_column_origin() -> Vector2:
	var button_size := Vector2(160.0, 70.0) * PLAY_HAND_BUTTON_SCALE
	if _play_hand_button != null and _play_hand_button.visible:
		button_size = _play_hand_button.get_global_rect().size
	if _player_hand != null:
		var play_anchor := _player_hand.get_play_button_global_position(button_size)
		return Vector2(
			play_anchor.x + button_size.x + HAND_ACTION_LEFT_GAP + HAND_ACTION_EXTRA_OFFSET,
			play_anchor.y
		)
	if _hand_mulligan_button != null:
		return _hand_mulligan_button.global_position
	return Vector2.ZERO


func _align_play_hand_button() -> void:
	if _play_hand_button == null or _player_hand == null:
		return
	if not _play_hand_button.visible:
		return
	var button_size := _play_hand_button.get_global_rect().size
	_play_hand_button.global_position = _player_hand.get_play_button_global_position(button_size)


func _align_hand_action_buttons() -> void:
	var show_undo := _hand_undo_button != null and _hand_undo_button.visible
	var show_mulligan := _hand_mulligan_button != null and _hand_mulligan_button.visible
	if not show_undo and not show_mulligan:
		return

	var origin := _get_hand_action_column_origin()
	var base_y := origin.y
	var action_left := origin.x

	if _hand_mulligan_button != null and _hand_mulligan_button.visible:
		_position_hand_action_control(action_left, base_y, _hand_mulligan_button, _hand_mulligan_label)
		action_left += _hand_action_control_width(_hand_mulligan_label) + HAND_ACTION_GROUP_GAP

	if _hand_undo_button != null and _hand_undo_button.visible:
		_position_hand_action_control(action_left, base_y, _hand_undo_button, _hand_undo_label)


func _position_hand_action_control(
	left: float,
	top: float,
	button: ShopRerollButton,
	label: Label
) -> void:
	var label_size := HAND_ACTION_LABEL_SIZE
	if label != null:
		label_size = label.get_minimum_size()
		label_size.x = maxf(label_size.x, HAND_ACTION_LABEL_SIZE.x)
		label_size.y = maxf(label_size.y, HAND_ACTION_LABEL_SIZE.y)
		label.size = label_size
	var column_width := maxf(HAND_ACTION_BUTTON_SIZE.x, label_size.x)
	if label != null:
		label.global_position = Vector2(
			left + (column_width - label_size.x) * 0.5,
			top
		)
	var button_top := top + label_size.y + HAND_ACTION_LABEL_GAP
	if button != null:
		button.global_position = Vector2(
			left + (column_width - HAND_ACTION_BUTTON_SIZE.x) * 0.5,
			button_top
		)


func _hand_action_control_width(label: Label) -> float:
	var label_width := HAND_ACTION_LABEL_SIZE.x
	if label != null:
		label_width = maxf(label.get_minimum_size().x, HAND_ACTION_LABEL_SIZE.x)
	return maxf(HAND_ACTION_BUTTON_SIZE.x, label_width)


func _should_show_brew_mulligan() -> bool:
	if not visible or GameManager.run == null:
		return false
	return (
		GameManager.run.brew_session.context.outcome == BrewOutcome.Outcome.IN_PROGRESS
	)


func _set_play_undo_visible(show_controls: bool) -> void:
	if _play_hand_button != null:
		_play_hand_button.visible = show_controls
	if _hand_undo_button != null:
		_hand_undo_button.visible = show_controls
	if _hand_undo_label != null:
		_hand_undo_label.visible = show_controls


func _set_mulligan_visible(show_controls: bool) -> void:
	if _hand_mulligan_button != null:
		_hand_mulligan_button.visible = show_controls
	if _hand_mulligan_label != null:
		_hand_mulligan_label.visible = show_controls


func _set_hand_action_buttons_visible(visible_buttons: bool) -> void:
	_set_play_undo_visible(visible_buttons)
	_set_mulligan_visible(visible_buttons)


func _refresh_undo_label(session: BrewSession) -> void:
	var swaps_remaining := session.get_hand_swaps_remaining()
	if _hand_undo_label != null:
		_hand_undo_label.text = _format_undo_label(swaps_remaining)
		_hand_undo_label.custom_minimum_size.x = maxf(
			_hand_undo_label.get_minimum_size().x,
			HAND_ACTION_LABEL_SIZE.x
		)
	if _hand_undo_button != null:
		_hand_undo_button.disabled = false


func _refresh_mulligan_label(session: BrewSession) -> void:
	if _hand_mulligan_label != null:
		_hand_mulligan_label.text = _format_mulligan_label(session.get_mulligans_remaining())
	if _hand_mulligan_button != null:
		_hand_mulligan_button.disabled = false


func _format_mulligan_label(mulligans_remaining: int) -> String:
	var noun := "mulligan" if mulligans_remaining == 1 else "mulligans"
	return "Mulligan (%d %s left)" % [mulligans_remaining, noun]


func _format_undo_label(swaps_remaining: int) -> String:
	var swap_word := "swap" if swaps_remaining == 1 else "swaps"
	return "Undo (%d %s left)" % [swaps_remaining, swap_word]


func _can_use_mulligan_now() -> bool:
	if GameManager.run == null or _player_hand == null:
		return false
	var session := GameManager.run.brew_session
	if session.get_mulligans_remaining() <= 0:
		return false
	var selected_slot := _player_hand.get_selected_slot()
	if selected_slot < 0:
		return false
	if session.get_hand_slot(selected_slot) == null:
		return false
	return GameManager.can_mulligan()


func _shake_hand_action_button(button: ShopRerollButton) -> void:
	if button != null:
		button.shake()


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


func _play_hand_card_fly(ingredient: IngredientData, slot_index: int, track_for_exit: bool) -> void:
	var fly_data := _hand_play_fly_data_for(ingredient, slot_index)
	_play_cauldron_fly_with_data(fly_data, ingredient, track_for_exit)


func _play_cauldron_fly(ingredient: IngredientData, track_for_exit: bool) -> void:
	var fly_data := _bag_to_cauldron_fly_data(ingredient)
	_play_cauldron_fly_with_data(fly_data, ingredient, track_for_exit)


func _play_cauldron_fly_with_data(
	fly_data: Dictionary,
	ingredient: IngredientData,
	track_for_exit: bool
) -> void:
	if fly_data.is_empty():
		if track_for_exit:
			_on_brew_exit_animation_finished()
			_try_play_pending_brew_exit_effects()
		_finish_card_presentation(ingredient, track_for_exit)
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
			_finish_card_presentation(ingredient, track_for_exit),
		func() -> void:
			_play_cauldron_plop()
			if track_for_exit:
				_try_play_pending_brew_exit_effects_after_plop()
	)


func _finish_card_presentation(ingredient: IngredientData, track_for_exit: bool) -> void:
	if _pending_frog_escape != null:
		var escaping_frog := _pending_frog_escape
		_pending_frog_escape = null
		_play_frog_escape(
			escaping_frog,
			func() -> void:
				GameManager.complete_frog_leg_save()
		)
		return
	if track_for_exit:
		_on_brew_exit_animation_finished()
	GameManager.notify_card_presentation_finished()


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


func _hand_draw_fly_data_for(ingredient: IngredientData, slot_index: int) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _bag_anchor == null:
		return {}
	var target_center := (
		_player_hand.get_slot_global_center(slot_index)
		if _player_hand != null
		else global_position
	)
	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": _bag_anchor.get_global_rect().get_center(),
		"target_center": target_center,
	}


func _hand_play_fly_data_for(ingredient: IngredientData, slot_index: int) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _cauldron_target == null:
		return {}

	var start_center := (
		_player_hand.get_slot_global_center(slot_index)
		if _player_hand != null
		else global_position
	)
	var fly_data := (
		_player_hand.get_slot_fly_data(slot_index)
		if _player_hand != null
		else {}
	)
	if not fly_data.is_empty() and fly_data.has("start_center"):
		start_center = fly_data["start_center"]
	if not fly_data.is_empty() and fly_data.has("texture"):
		texture = fly_data["texture"]
	if not fly_data.is_empty() and fly_data.has("size"):
		return {
			"texture": texture,
			"size": fly_data["size"],
			"start_center": start_center,
			"target_center": _cauldron_target.get_global_rect().get_center(),
		}

	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": start_center,
		"target_center": _cauldron_target.get_global_rect().get_center(),
	}


func _bag_to_cauldron_fly_data(ingredient: IngredientData) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _bag_anchor == null or _cauldron_target == null:
		return {}
	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": _bag_anchor.get_global_rect().get_center(),
		"target_center": _cauldron_target.get_global_rect().get_center(),
	}


func _play_mulligan_animation(
	old_ingredient: IngredientData,
	new_ingredient: IngredientData,
	slot_index: int
) -> void:
	if old_ingredient == null or new_ingredient == null:
		GameManager.notify_mulligan_presentation_finished()
		return

	GameManager.set_presentation_in_progress(true)
	if _player_hand != null:
		_player_hand.suppress_slot(slot_index)
		_player_hand.clear_selection()
	_sync_hand_ui()

	var return_fly := _hand_to_bag_fly_data(old_ingredient, slot_index)
	if return_fly.is_empty():
		_play_mulligan_draw_in(new_ingredient, slot_index)
		return

	_IngredientFlyUtil.play(
		_fly_layer,
		return_fly["texture"],
		return_fly["start_center"],
		return_fly["target_center"],
		return_fly["size"],
		func() -> void:
			GameManager.complete_mulligan(slot_index, old_ingredient, new_ingredient)
			_play_mulligan_draw_in(new_ingredient, slot_index)
	)


func _play_mulligan_draw_in(new_ingredient: IngredientData, slot_index: int) -> void:
	if _player_hand != null:
		_player_hand.hide_slot_for_fly(slot_index)

	var draw_fly := _hand_draw_fly_data_for(new_ingredient, slot_index)
	if draw_fly.is_empty():
		if _player_hand != null:
			_player_hand.reveal_slot(slot_index, new_ingredient)
		GameManager.notify_mulligan_presentation_finished()
		_sync_hand_ui()
		return

	_IngredientFlyUtil.play(
		_fly_layer,
		draw_fly["texture"],
		draw_fly["start_center"],
		draw_fly["target_center"],
		draw_fly["size"],
		func() -> void:
			if _player_hand != null:
				_player_hand.reveal_slot(slot_index, new_ingredient)
			GameManager.notify_mulligan_presentation_finished()
			_sync_hand_ui()
	)


func _hand_to_bag_fly_data(ingredient: IngredientData, slot_index: int) -> Dictionary:
	var texture := _load_ingredient_texture(ingredient)
	if texture == null or _bag_anchor == null:
		return {}
	var start_center := (
		_player_hand.get_slot_global_center(slot_index)
		if _player_hand != null
		else global_position
	)
	var fly_data := (
		_player_hand.get_slot_fly_data(slot_index)
		if _player_hand != null
		else {}
	)
	if not fly_data.is_empty():
		if fly_data.has("start_center"):
			start_center = fly_data["start_center"]
		if fly_data.has("texture"):
			texture = fly_data["texture"]
		if fly_data.has("size"):
			return {
				"texture": texture,
				"size": fly_data["size"],
				"start_center": start_center,
				"target_center": _bag_anchor.get_global_rect().get_center(),
			}
	return {
		"texture": texture,
		"size": FLY_ART_SIZE,
		"start_center": start_center,
		"target_center": _bag_anchor.get_global_rect().get_center(),
	}


func _hand_has_any_card(slots: Array) -> bool:
	for slot in slots:
		if slot != null:
			return true
	return false


func _load_ingredient_texture(ingredient: IngredientData) -> Texture2D:
	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		return load(art_path)
	return null
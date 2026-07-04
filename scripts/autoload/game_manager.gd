extends Node

signal phase_changed(phase: int)
signal run_changed
signal brew_updated(context: BrewContext)
signal hand_draw_batch_started(drawn: Array)
signal hand_card_played(
	context: BrewContext,
	ingredient: IngredientData,
	slot_index: int,
	parrot_doubled: bool
)
signal hand_mulligan_started(
	old_ingredient: IngredientData,
	new_ingredient: IngredientData,
	slot_index: int
)
signal ingredient_drawn(
	context: BrewContext,
	ingredient: IngredientData,
	parrot_doubled: bool
)
signal frog_leg_escaped(ingredient: IngredientData)
signal brew_completion_requested(outcome: int)
signal eyeball_puzzle_requested(reserved: Array)
signal bat_wing_picker_requested(choices: Array)
signal bag_display_changed
signal brew_resolved(resolution: Dictionary)
signal game_over(comparison: Dictionary)

var current_phase: int = GamePhase.Phase.MAIN_MENU
var last_brew_cleared: bool = false
var last_high_score_comparison: Dictionary = {}

var _content := DefaultContent.create()
var run: RunManager = RunManager.new(_content)
var _brew_transition_pending: bool = false
var _presentation_in_progress: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.is_editor_hint():
		randomize()
		call_deferred("_apply_exclusive_fullscreen")
	run.brew_session.brew_updated.connect(_on_brew_updated)
	run.brew_session.hand_draw_batch_started.connect(_on_hand_draw_batch_started)
	run.brew_session.hand_card_played.connect(_on_hand_card_played)
	run.brew_session.ingredient_drawn.connect(_on_ingredient_drawn)
	run.brew_session.frog_leg_escaped.connect(_on_frog_leg_escaped)
	run.brew_session.eyeball_puzzle_requested.connect(_on_eyeball_puzzle_requested)
	run.brew_session.bat_wing_picker_requested.connect(_on_bat_wing_picker_requested)
	run.brew_session.hand_mulligan_started.connect(_on_hand_mulligan_started)


func has_save() -> bool:
	return SaveService.has_save()


func start_new_run(difficulty: int = GameDifficulty.Mode.HARD) -> void:
	SaveService.delete_save()
	run.start_new_run(difficulty)
	last_brew_cleared = false
	run_changed.emit()
	_enter_brewing()


func continue_run() -> void:
	var data := SaveService.load_run()
	if data.is_empty():
		start_new_run()
		return
	run.load_from_save(data)
	last_brew_cleared = false
	_set_phase(GamePhase.Phase.SHOP)
	run_changed.emit()


func enter_brewing() -> void:
	_enter_brewing()


func can_press_bag() -> bool:
	return (
		current_phase == GamePhase.Phase.BREWING
		and not _brew_transition_pending
		and not _presentation_in_progress
		and run.brew_session.can_press_bag()
	)


func can_player_draw() -> bool:
	return can_press_bag()


func can_play_hand() -> bool:
	return (
		current_phase == GamePhase.Phase.BREWING
		and not _brew_transition_pending
		and not _presentation_in_progress
		and run.brew_session.can_play_hand()
	)


func can_end_brew() -> bool:
	return (
		current_phase == GamePhase.Phase.BREWING
		and not _brew_transition_pending
		and not _presentation_in_progress
		and run.brew_session.can_player_end_brew()
	)


func set_presentation_in_progress(active: bool) -> void:
	_presentation_in_progress = active


func notify_bag_display_changed() -> void:
	bag_display_changed.emit()


func try_draw_ingredient() -> void:
	if not can_press_bag():
		return
	run.brew_session.try_draw_to_hand()
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func try_play_hand() -> void:
	if not can_play_hand():
		return
	run.brew_session.try_play_hand()
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func try_swap_hand_slots(from_slot: int, to_slot: int) -> void:
	if (
		current_phase != GamePhase.Phase.BREWING
		or _brew_transition_pending
		or _presentation_in_progress
	):
		return
	if not run.brew_session.can_swap_hand():
		return
	run.brew_session.swap_hand_slots(from_slot, to_slot)


func try_undo_hand_swap() -> void:
	if not run.brew_session.can_undo_hand_swap():
		return
	run.brew_session.undo_hand_swap()


func can_mulligan() -> bool:
	return (
		current_phase == GamePhase.Phase.BREWING
		and not _brew_transition_pending
		and not _presentation_in_progress
		and run.brew_session.can_mulligan()
	)


func try_mulligan(slot_index: int) -> void:
	if not can_mulligan():
		return
	if slot_index < 0:
		return
	if run.brew_session.try_mulligan(slot_index):
		_presentation_in_progress = true


func complete_mulligan(
	slot_index: int,
	old_ingredient: IngredientData,
	new_ingredient: IngredientData
) -> void:
	run.brew_session.complete_mulligan(slot_index, old_ingredient, new_ingredient)


func notify_mulligan_presentation_finished() -> void:
	_presentation_in_progress = false


func notify_hand_draw_batch_finished() -> void:
	_presentation_in_progress = false
	run.brew_session.on_hand_draw_batch_finished()
	_sync_hand_completion()


func notify_card_presentation_finished() -> void:
	_presentation_in_progress = false
	var session := run.brew_session
	if session.get_hand_phase() == BrewSession.HandPhase.PLAYING:
		session.on_hand_play_presentation_finished()
		_sync_hand_completion()
		return
	if session.try_advance_chain_draw():
		return
	_sync_hand_completion()


func _sync_hand_completion() -> void:
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func complete_eyeball_puzzle(ordered: Array = []) -> void:
	run.brew_session.complete_eyeball_puzzle(ordered)
	_sync_hand_completion()


func complete_bat_wing_picker(selected: IngredientData) -> void:
	run.brew_session.complete_bat_wing_picker(selected)
	_sync_hand_completion()


func complete_frog_leg_save() -> void:
	_presentation_in_progress = false
	run.brew_session.complete_frog_leg_save()
	_request_brew_completion()


func try_end_brew() -> void:
	if not can_end_brew():
		return
	if run.brew_session.try_end_brew():
		_request_brew_completion()


func try_practice_restart() -> bool:
	if _brew_transition_pending:
		return false
	if current_phase != GamePhase.Phase.BREWING:
		return false
	if not run.brew_session.try_practice_restart():
		return false
	_presentation_in_progress = false
	return true


func is_brew_transition_pending() -> bool:
	return _brew_transition_pending


func finalize_brew_transition() -> void:
	if not _brew_transition_pending:
		return
	_brew_transition_pending = false
	_complete_brew()


func leave_shop() -> void:
	if last_brew_cleared:
		run.leave_shop_after_clear()
	_save_at_shop()
	_enter_brewing()


func try_reroll_shop() -> bool:
	var rerolled := run.try_reroll_shop()
	if rerolled:
		run_changed.emit()
		_save_at_shop()
	return rerolled


func try_purchase_offer(index: int) -> bool:
	var purchased := run.try_purchase_offer(index)
	if purchased:
		run_changed.emit()
		_save_at_shop()
	return purchased


func save_and_quit() -> void:
	if current_phase not in [GamePhase.Phase.BREWING, GamePhase.Phase.SHOP]:
		return
	SaveService.save_run(run.to_save_data())
	run_changed.emit()
	return_to_main_menu()


func return_to_main_menu() -> void:
	_set_phase(GamePhase.Phase.MAIN_MENU)


func _enter_brewing() -> void:
	run.begin_brew()
	run_changed.emit()
	_set_phase(GamePhase.Phase.BREWING)


func _request_brew_completion() -> void:
	if _brew_transition_pending:
		return
	_brew_transition_pending = true
	brew_completion_requested.emit(run.brew_session.context.outcome)


func _complete_brew() -> void:
	var resolution := run.resolve_brew()
	last_brew_cleared = resolution["cleared"]
	brew_resolved.emit(resolution)
	if int(resolution["lives_remaining"]) <= 0:
		_end_run()
		return
	_save_at_shop()
	_set_phase(GamePhase.Phase.SHOP)


func _end_run() -> void:
	last_high_score_comparison = HighScoreService.apply_run_results(
		run.deepest_level_reached,
		run.best_single_brew_this_run,
		run.total_run_score
	)
	SaveService.delete_save()
	_set_phase(GamePhase.Phase.GAME_OVER)
	game_over.emit(last_high_score_comparison)


func _save_at_shop() -> void:
	SaveService.save_run(run.to_save_data())
	run_changed.emit()


func _set_phase(phase: int) -> void:
	current_phase = phase
	phase_changed.emit(phase)


func _on_brew_updated(context: BrewContext) -> void:
	brew_updated.emit(context)


func _on_hand_draw_batch_started(drawn: Array) -> void:
	hand_draw_batch_started.emit(drawn)


func _on_hand_card_played(
	context: BrewContext,
	ingredient: IngredientData,
	slot_index: int,
	parrot_doubled: bool
) -> void:
	hand_card_played.emit(context, ingredient, slot_index, parrot_doubled)


func _on_ingredient_drawn(
	context: BrewContext,
	ingredient: IngredientData,
	parrot_doubled: bool
) -> void:
	ingredient_drawn.emit(context, ingredient, parrot_doubled)


func _on_frog_leg_escaped(ingredient: IngredientData) -> void:
	frog_leg_escaped.emit(ingredient)


func _on_eyeball_puzzle_requested(reserved: Array) -> void:
	eyeball_puzzle_requested.emit(reserved)


func _on_bat_wing_picker_requested(choices: Array) -> void:
	bat_wing_picker_requested.emit(choices)


func _on_hand_mulligan_started(
	old_ingredient: IngredientData,
	new_ingredient: IngredientData,
	slot_index: int
) -> void:
	hand_mulligan_started.emit(old_ingredient, new_ingredient, slot_index)


func _apply_exclusive_fullscreen() -> void:
	var window := get_window()
	if window != null:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

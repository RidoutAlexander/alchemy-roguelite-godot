extends Node

signal phase_changed(phase: int)
signal run_changed
signal brew_updated(context: BrewContext)
signal ingredient_drawn(context: BrewContext, ingredient: IngredientData)
signal frog_leg_escaped(ingredient: IngredientData)
signal brew_completion_requested(outcome: int)
signal eyeball_puzzle_requested(reserved: Array)
signal bat_wing_picker_requested(choices: Array)
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
	run.brew_session.ingredient_drawn.connect(_on_ingredient_drawn)
	run.brew_session.frog_leg_escaped.connect(_on_frog_leg_escaped)
	run.brew_session.eyeball_puzzle_requested.connect(_on_eyeball_puzzle_requested)
	run.brew_session.bat_wing_picker_requested.connect(_on_bat_wing_picker_requested)


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


func can_player_draw() -> bool:
	return (
		current_phase == GamePhase.Phase.BREWING
		and not _brew_transition_pending
		and not _presentation_in_progress
		and run.brew_session.can_player_draw()
	)


func set_presentation_in_progress(active: bool) -> void:
	_presentation_in_progress = active


func try_draw_ingredient() -> void:
	if not can_player_draw():
		return
	run.brew_session.try_draw_ingredient()
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func notify_ingredient_presentation_finished() -> void:
	_presentation_in_progress = false
	if run.brew_session.try_advance_chain_draw():
		return
	run.brew_session.on_ingredient_presentation_finished()
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func complete_eyeball_puzzle(ordered: Array) -> void:
	run.brew_session.complete_eyeball_puzzle(ordered)


func complete_bat_wing_picker(selected: IngredientData) -> void:
	run.brew_session.complete_bat_wing_picker(selected)
	if run.brew_session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_request_brew_completion()


func try_end_brew() -> void:
	if not can_player_draw():
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


func _on_ingredient_drawn(context: BrewContext, ingredient: IngredientData) -> void:
	ingredient_drawn.emit(context, ingredient)


func _on_frog_leg_escaped(ingredient: IngredientData) -> void:
	frog_leg_escaped.emit(ingredient)


func _on_eyeball_puzzle_requested(reserved: Array) -> void:
	eyeball_puzzle_requested.emit(reserved)


func _on_bat_wing_picker_requested(choices: Array) -> void:
	bat_wing_picker_requested.emit(choices)


func _apply_exclusive_fullscreen() -> void:
	var window := get_window()
	if window != null:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

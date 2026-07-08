class_name LevelAuraBanner
extends Control

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

@onready var _countdown_label: Label = $AuraCountdownLabel
@onready var _countdown_caption: Label = $AuraCountdownCaption


func _ready() -> void:
	_connect_refresh_signals()
	call_deferred("refresh_interval_countdown")


func _connect_refresh_signals() -> void:
	if not GameManager.run_changed.is_connected(_on_run_changed):
		GameManager.run_changed.connect(_on_run_changed)
	if not GameManager.brew_updated.is_connected(_on_brew_updated):
		GameManager.brew_updated.connect(_on_brew_updated)
	if not GameManager.brew_stats_presented.is_connected(_on_brew_stats_presented):
		GameManager.brew_stats_presented.connect(_on_brew_stats_presented)
	if not GameManager.ingredient_drawn.is_connected(_on_ingredient_drawn):
		GameManager.ingredient_drawn.connect(_on_ingredient_drawn)
	if not GameManager.hand_card_played.is_connected(_on_hand_card_played):
		GameManager.hand_card_played.connect(_on_hand_card_played)


func _on_run_changed() -> void:
	refresh_interval_countdown()


func _on_brew_updated(_ctx: BrewContext) -> void:
	refresh_interval_countdown()


func _on_brew_stats_presented(_ctx: BrewContext) -> void:
	refresh_interval_countdown()


func _on_ingredient_drawn(_ctx: BrewContext, _ingredient: IngredientData, _parrot_doubled: bool) -> void:
	refresh_interval_countdown()


func _on_hand_card_played(
	_ctx: BrewContext,
	_ingredient: IngredientData,
	_slot_index: int,
	_parrot_doubled: bool
) -> void:
	refresh_interval_countdown()


func refresh_interval_countdown() -> void:
	var show_countdown := false
	var countdown := 0
	if GameManager.run != null and GameManager.run.brew_session != null:
		var session := GameManager.run.brew_session
		var aura: AuraData = session.context.current_aura
		if (
			session.context.outcome == BrewOutcome.Outcome.IN_PROGRESS
			and _AuraEffects.uses_interval_countdown(aura)
		):
			countdown = session.get_aura_interval_countdown()
			show_countdown = countdown > 0
	if _countdown_label != null:
		_countdown_label.visible = show_countdown
		if show_countdown:
			_countdown_label.text = str(countdown)
	if _countdown_caption != null:
		_countdown_caption.visible = show_countdown
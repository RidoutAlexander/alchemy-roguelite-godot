class_name LevelAuraBanner
extends Control

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

@onready var _level_label: Label = $LevelLabel
@onready var _aura_name_label: Label = $AuraNameLabel
@onready var _aura_description_label: Label = $AuraDescriptionLabel
@onready var _countdown_label: Label = $AuraCountdownLabel
@onready var _countdown_caption: Label = $AuraCountdownCaption
@onready var _practice_restart_button: Control = $PracticeRestartButton

var _preview_mode: bool = false


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


func bind_preview(level: int, aura: AuraData) -> void:
	_preview_mode = true
	_layout_description_label()
	if _level_label != null:
		_level_label.text = "Level %d" % level
	if aura == null:
		if _aura_name_label != null:
			_aura_name_label.text = ""
		if _aura_description_label != null:
			_aura_description_label.text = ""
		modulate = Color.WHITE
	else:
		if _aura_name_label != null:
			_aura_name_label.text = aura.display_name
		var is_boss := GameConstants.is_boss_level(level)
		if _aura_description_label != null:
			if is_boss:
				_aura_description_label.text = (
					"%s\n%s" % [aura.description, GameConstants.BOSS_AURA_WARNING]
				)
			else:
				_aura_description_label.text = aura.description
		modulate = Color(1.0, 0.58, 0.58, 1.0) if is_boss else Color.WHITE
	if _countdown_label != null:
		_countdown_label.visible = false
	if _countdown_caption != null:
		_countdown_caption.visible = false
	if _practice_restart_button != null:
		_practice_restart_button.visible = false


func refresh_interval_countdown() -> void:
	if _preview_mode:
		return
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
	_layout_description_label()


func _layout_description_label() -> void:
	if _aura_description_label == null:
		return
	var reserve_countdown := (
		not _preview_mode
		and _countdown_label != null
		and _countdown_label.visible
	)
	if reserve_countdown:
		_aura_description_label.offset_left = 18.0
		_aura_description_label.offset_right = 236.0
	else:
		_aura_description_label.offset_left = 14.0
		_aura_description_label.offset_right = 292.0

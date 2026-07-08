extends Control

const _PhaseSwipeTransition := preload("res://scripts/ui/phase_swipe_transition.gd")

@onready var _phase_swipe_host: Control = $PhaseSwipeHost
@onready var _brew_panel: Control = $PhaseSwipeHost/BrewPanel
@onready var _shop_panel: ShopPanel = $PhaseSwipeHost/ShopPanel
@onready var _game_over_panel: Control = $GameOverPanel
@onready var _trinket_reward_overlay: TrinketRewardOverlay = $TrinketRewardOverlay
@onready var _brew_gold_counter: GoldDisplay = $PhaseSwipeHost/BrewPanel/GoldCounter
@onready var _brew_explosiveness_counter: ExplosivenessDisplay = (
	$PhaseSwipeHost/BrewPanel/ExplosivenessCounter
)
@onready var _brew_score_flask: Control = $PhaseSwipeHost/BrewPanel/ScoreFlask
@onready var _brew_gold_reward_display: Control = $PhaseSwipeHost/BrewPanel/GoldRewardDisplay
@onready var _brew_stat_popups: BrewStatPopups = $HudOverlayLayer/BrewStatPopups
@onready var _level_aura_banner: Control = $PhaseSwipeHost/BrewPanel/LevelAuraBanner
@onready var _level_label: Label = $PhaseSwipeHost/BrewPanel/LevelAuraBanner/LevelLabel
@onready var _aura_name_label: Label = $PhaseSwipeHost/BrewPanel/LevelAuraBanner/AuraNameLabel
@onready var _aura_description_label: Label = $PhaseSwipeHost/BrewPanel/LevelAuraBanner/AuraDescriptionLabel
@onready var _aura_countdown_label: Label = $PhaseSwipeHost/BrewPanel/LevelAuraBanner/AuraCountdownLabel
@onready var _aura_countdown_caption: Label = $PhaseSwipeHost/BrewPanel/LevelAuraBanner/AuraCountdownCaption
@onready var _practice_restart_button: ShopRerollButton = (
	$PhaseSwipeHost/BrewPanel/LevelAuraBanner/PracticeRestartButton
)
@onready var _game_over_stats: Label = $GameOverPanel/StatsLabel
@onready var _add_ingredient_button: IngredientBagButton = $PhaseSwipeHost/BrewPanel/AddIngredientButton
@onready var _bag_remaining_count_label: Label = $HudOverlayLayer/BagRemainingCountLabel

const BAG_REMAINING_COUNT_INSET := Vector2(0.0, 6.0)
@onready var _save_and_quit_button: BaseButton = $PhaseSwipeHost/BrewPanel/SaveAndQuitButton
@onready var _dev_mode_checkbox: CheckBox = $PhaseSwipeHost/BrewPanel/DevModeCheckbox
@onready var _dev_hand_picker: BagContentsOverlay = $DevHandPickerLayer/DevHandPickerOverlay
@onready var _dev_trinket_picker: BagContentsOverlay = $DevTrinketPickerLayer/DevTrinketPickerOverlay
@onready var _main_menu_button: BaseButton = $GameOverPanel/MainMenuButton
@onready var _gameplay_music_player: AudioStreamPlayer = $GameplayMusicPlayer

const RHYTHM_SHAKE_OFFSET := Vector2(5.0, 2.0)
const RHYTHM_SHAKE_STEP := 0.07
const GAMEPLAY_MUSIC_VOLUME_DB := 1.5
const GAMEPLAY_MUSIC_SONG_5_INDEX := 4
const _GAMEPLAY_MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/game_soundtrack.ogg"),
	preload("res://assets/audio/game_soundtrack_2.ogg"),
	preload("res://assets/audio/game_soundtrack_3.ogg"),
	preload("res://assets/audio/game_soundtrack_4.ogg"),
	preload("res://assets/audio/game_soundtrack_5.ogg"),
]

var _active_phase: int = -1
var _gameplay_music_track_index: int = 0
var _is_swiping: bool = false
var _rhythm_shake_tween: Tween
var _aura_description_rest_position := Vector2.ZERO
var _rhythm_shake_active: bool = false


func _ready() -> void:
	_connect_button(_add_ingredient_button, GameManager.try_draw_ingredient)
	if _add_ingredient_button != null:
		if not _add_ingredient_button.mouse_entered.is_connected(_align_bag_remaining_count_label):
			_add_ingredient_button.mouse_entered.connect(_align_bag_remaining_count_label)
		if not _add_ingredient_button.mouse_exited.is_connected(_align_bag_remaining_count_label):
			_add_ingredient_button.mouse_exited.connect(_align_bag_remaining_count_label)
	_connect_button(_save_and_quit_button, _save_and_quit)
	_connect_button(_main_menu_button, _return_to_main_menu)
	if _practice_restart_button != null and not _practice_restart_button.pressed.is_connected(
		_on_practice_restart_pressed
	):
		_practice_restart_button.pressed.connect(_on_practice_restart_pressed)
	if _dev_mode_checkbox != null:
		_configure_dev_mode_checkbox()
	if _dev_hand_picker != null:
		if not _dev_hand_picker.dev_hand_picker_completed.is_connected(
			_on_dev_hand_picker_completed
		):
			_dev_hand_picker.dev_hand_picker_completed.connect(_on_dev_hand_picker_completed)
	if _dev_trinket_picker != null:
		if not _dev_trinket_picker.dev_trinket_picker_completed.is_connected(
			_on_dev_trinket_picker_completed
		):
			_dev_trinket_picker.dev_trinket_picker_completed.connect(
				_on_dev_trinket_picker_completed
			)

	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.dev_hand_picker_requested.connect(_on_dev_hand_picker_requested)
	GameManager.dev_trinket_picker_requested.connect(_on_dev_trinket_picker_requested)
	GameManager.run_changed.connect(_on_run_changed)
	GameManager.brew_updated.connect(func(_ctx): _refresh_brew())
	GameManager.brew_stats_presented.connect(func(_ctx): _refresh_brew())
	GameManager.brew_updated.connect(func(_ctx): _refresh_brew_input_state())
	GameManager.brew_updated.connect(func(_ctx): _refresh_bag_remaining_count())
	GameManager.ingredient_drawn.connect(
		func(_ctx, _ingredient, _parrot_doubled): _refresh_bag_remaining_count()
	)
	GameManager.hand_draw_batch_started.connect(func(_drawn): _refresh_bag_remaining_count())
	GameManager.bag_display_changed.connect(_refresh_bag_remaining_count)
	GameManager.brew_resolved.connect(func(_resolution): _refresh_brew())
	GameManager.brew_completion_requested.connect(_on_brew_completion_requested)
	GameManager.game_over.connect(_refresh_game_over)

	if _brew_stat_popups != null:
		_brew_stat_popups.configure(
			_brew_score_flask,
			_brew_explosiveness_counter,
			_brew_gold_reward_display
		)

	call_deferred("_initialize_hud")
	_start_gameplay_music()
	if _aura_description_label != null:
		_aura_description_rest_position = _aura_description_label.position


func _initialize_hud() -> void:
	_ensure_active_run()
	_on_phase_changed(GameManager.current_phase)
	_refresh_brew()
	_refresh_bag_remaining_count()


func _on_run_changed() -> void:
	_refresh_brew()
	_refresh_bag_remaining_count()


func _ensure_active_run() -> void:
	if GameManager.current_phase == GamePhase.Phase.MAIN_MENU:
		GameManager.start_new_run()
		return
	if (
		GameManager.current_phase == GamePhase.Phase.BREWING
		and GameManager.run.brew_session.context.current_aura == null
	):
		GameManager.enter_brewing()


func _start_gameplay_music() -> void:
	if _gameplay_music_player == null or _GAMEPLAY_MUSIC_TRACKS.is_empty():
		return
	if not _gameplay_music_player.finished.is_connected(_on_gameplay_music_finished):
		_gameplay_music_player.finished.connect(_on_gameplay_music_finished)
	if not _gameplay_music_player.playing:
		_play_gameplay_music_track(0)


func _gameplay_music_volume_db(track_index: int) -> float:
	if track_index == GAMEPLAY_MUSIC_SONG_5_INDEX:
		return GAMEPLAY_MUSIC_VOLUME_DB + linear_to_db(0.5)
	return GAMEPLAY_MUSIC_VOLUME_DB


func _play_gameplay_music_track(index: int) -> void:
	if _gameplay_music_player == null or _GAMEPLAY_MUSIC_TRACKS.is_empty():
		return
	_gameplay_music_track_index = index % _GAMEPLAY_MUSIC_TRACKS.size()
	var stream := _GAMEPLAY_MUSIC_TRACKS[_gameplay_music_track_index]
	if stream != null:
		stream.loop = false
	_gameplay_music_player.stream = stream
	_gameplay_music_player.volume_db = _gameplay_music_volume_db(_gameplay_music_track_index)
	_gameplay_music_player.play()


func _on_gameplay_music_finished() -> void:
	_play_gameplay_music_track(_gameplay_music_track_index + 1)


func _connect_button(button: BaseButton, handler: Callable) -> void:
	if button == null:
		push_error("GameHUD: missing button for %s" % handler)
		return
	if button.pressed.is_connected(handler):
		return
	button.pressed.connect(handler)


func _save_and_quit() -> void:
	GameManager.save_and_quit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _return_to_main_menu() -> void:
	GameManager.return_to_main_menu()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_brew_completion_requested(_outcome: int) -> void:
	_refresh_brew_input_state()


func _refresh_brew_input_state() -> void:
	if _add_ingredient_button != null:
		_add_ingredient_button.disabled = not GameManager.can_press_bag()


func _on_phase_changed(phase: int) -> void:
	if _is_swiping:
		return

	if _PhaseSwipeTransition.should_swipe(_active_phase, phase):
		_play_phase_swipe(phase)
		return

	_apply_phase_visibility(phase)
	_active_phase = phase
	if phase == GamePhase.Phase.BREWING:
		_refresh_brew_input_state()
		_refresh_brew()
	elif phase == GamePhase.Phase.SHOP and _shop_panel != null:
		_shop_panel.refresh_stats_only()


func _play_phase_swipe(phase: int) -> void:
	if _phase_swipe_host == null or _brew_panel == null or _shop_panel == null:
		_apply_phase_visibility(phase)
		_active_phase = phase
		if phase == GamePhase.Phase.BREWING:
			_refresh_brew()
		return

	_is_swiping = true
	_game_over_panel.visible = false

	var incoming: Control = _shop_panel if phase == GamePhase.Phase.SHOP else _brew_panel
	var outgoing: Control = _brew_panel if phase == GamePhase.Phase.SHOP else _shop_panel

	_PhaseSwipeTransition.play(
		_phase_swipe_host,
		outgoing,
		incoming,
		func() -> void:
			_is_swiping = false
			_active_phase = phase
			_apply_phase_visibility(phase)
			if phase == GamePhase.Phase.BREWING:
				_refresh_brew_input_state()
				_refresh_brew()
			elif phase == GamePhase.Phase.SHOP and _shop_panel != null:
				_shop_panel.refresh_stats_only()
			elif phase == GamePhase.Phase.TRINKET_REWARD and _trinket_reward_overlay != null:
				_trinket_reward_overlay.show_offers(GameManager.get_pending_trinket_rewards())
	)


func _apply_phase_visibility(phase: int) -> void:
	if _brew_panel:
		_brew_panel.visible = (
			phase == GamePhase.Phase.BREWING
			or phase == GamePhase.Phase.TRINKET_REWARD
		)
	if _shop_panel:
		_shop_panel.visible = phase == GamePhase.Phase.SHOP
	if _game_over_panel:
		_game_over_panel.visible = phase == GamePhase.Phase.GAME_OVER
	if _trinket_reward_overlay != null:
		if phase == GamePhase.Phase.TRINKET_REWARD:
			_trinket_reward_overlay.show_offers(GameManager.get_pending_trinket_rewards())
		else:
			_trinket_reward_overlay.hide_overlay()
	if _bag_remaining_count_label != null:
		var show_count := phase == GamePhase.Phase.BREWING
		_bag_remaining_count_label.visible = show_count
		if show_count:
			call_deferred("_align_bag_remaining_count_label")


func _refresh_brew() -> void:
	if _level_label == null:
		return
	var ctx := GameManager.run.brew_session.context
	var run := GameManager.run
	_refresh_bag_remaining_count()
	if ctx.current_aura == null:
		return
	var is_boss := ctx.is_boss_level()
	_level_label.text = "Level %d" % ctx.level
	_aura_name_label.text = ctx.current_aura.display_name
	if is_boss:
		_aura_description_label.text = (
			"%s\n%s" % [ctx.current_aura.description, GameConstants.BOSS_AURA_WARNING]
		)
	else:
		_aura_description_label.text = ctx.current_aura.description
	_apply_boss_banner_style(is_boss)
	if _brew_gold_counter != null:
		_brew_gold_counter.set_amount(run.gold)
	if _brew_explosiveness_counter != null:
		var session := GameManager.run.brew_session
		_brew_explosiveness_counter.set_values(
			session.get_explosiveness_for_hud(GameManager.is_presentation_in_progress()),
			session.get_explosion_limit_for_hud()
		)
	_refresh_practice_restart_button()
	_refresh_aura_interval_countdown()
	_refresh_rhythm_aura_shake(ctx)


func _refresh_bag_remaining_count() -> void:
	if _bag_remaining_count_label == null or GameManager.run == null:
		return
	if GameManager.current_phase != GamePhase.Phase.BREWING:
		return
	_bag_remaining_count_label.text = str(GameManager.run.brew_session.get_bag_display_count())
	call_deferred("_align_bag_remaining_count_label")


func _align_bag_remaining_count_label() -> void:
	if (
		_bag_remaining_count_label == null
		or _add_ingredient_button == null
		or not _bag_remaining_count_label.visible
	):
		return
	var label_size := _bag_remaining_count_label.get_minimum_size()
	label_size.x = maxf(label_size.x, 28.0)
	label_size.y = maxf(label_size.y, 24.0)
	_bag_remaining_count_label.custom_minimum_size = label_size
	_bag_remaining_count_label.size = label_size
	var bag_rect := _add_ingredient_button.get_global_rect()
	_bag_remaining_count_label.position = Vector2(
		bag_rect.position.x + (bag_rect.size.x - label_size.x) * 0.5,
		bag_rect.end.y + BAG_REMAINING_COUNT_INSET.y
	)


func _refresh_aura_interval_countdown() -> void:
	var show_countdown := false
	var countdown := 0
	if GameManager.run != null and GameManager.run.brew_session != null:
		var session := GameManager.run.brew_session
		countdown = session.get_aura_interval_countdown()
		show_countdown = (
			session.context.outcome == BrewOutcome.Outcome.IN_PROGRESS
			and countdown > 0
		)
	if _aura_countdown_label != null:
		_aura_countdown_label.visible = show_countdown
		if show_countdown:
			_aura_countdown_label.text = str(countdown)
	if _aura_countdown_caption != null:
		_aura_countdown_caption.visible = show_countdown


func _should_shake_rhythm_aura(ctx: BrewContext) -> bool:
	if ctx.current_aura == null:
		return false
	if ctx.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return false
	if GameManager.run == null or GameManager.run.brew_session == null:
		return false
	return GameManager.run.brew_session.get_aura_interval_countdown() == 1


func _refresh_rhythm_aura_shake(ctx: BrewContext) -> void:
	if _should_shake_rhythm_aura(ctx):
		_start_rhythm_aura_shake()
	else:
		_stop_rhythm_aura_shake()


func _start_rhythm_aura_shake() -> void:
	if _aura_description_label == null or _rhythm_shake_active:
		return
	_rhythm_shake_active = true
	_aura_description_rest_position = _aura_description_label.position
	if _rhythm_shake_tween != null and _rhythm_shake_tween.is_valid():
		_rhythm_shake_tween.kill()
	_rhythm_shake_tween = create_tween().set_loops()
	_rhythm_shake_tween.tween_property(
		_aura_description_label,
		"position",
		_aura_description_rest_position + Vector2(RHYTHM_SHAKE_OFFSET.x, 0.0),
		RHYTHM_SHAKE_STEP
	)
	_rhythm_shake_tween.tween_property(
		_aura_description_label,
		"position",
		_aura_description_rest_position + Vector2(-RHYTHM_SHAKE_OFFSET.x, RHYTHM_SHAKE_OFFSET.y),
		RHYTHM_SHAKE_STEP
	)
	_rhythm_shake_tween.tween_property(
		_aura_description_label,
		"position",
		_aura_description_rest_position + Vector2(0.0, -RHYTHM_SHAKE_OFFSET.y),
		RHYTHM_SHAKE_STEP
	)
	_rhythm_shake_tween.tween_property(
		_aura_description_label,
		"position",
		_aura_description_rest_position,
		RHYTHM_SHAKE_STEP
	)


func _stop_rhythm_aura_shake() -> void:
	_rhythm_shake_active = false
	if _rhythm_shake_tween != null and _rhythm_shake_tween.is_valid():
		_rhythm_shake_tween.kill()
		_rhythm_shake_tween = null
	if _aura_description_label != null:
		_aura_description_label.position = _aura_description_rest_position


func _on_practice_restart_pressed() -> void:
	GameManager.try_practice_restart()


func _configure_dev_mode_checkbox() -> void:
	_dev_mode_checkbox.focus_mode = Control.FOCUS_NONE
	_dev_mode_checkbox.flat = true
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		_dev_mode_checkbox.add_theme_stylebox_override(style_name, empty)
	var blank_icon := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		_dev_mode_checkbox.add_theme_icon_override(icon_name, blank_icon)
	_dev_mode_checkbox.button_pressed = GameManager.is_dev_mode_enabled()
	_refresh_dev_mode_checkbox_text()
	if not _dev_mode_checkbox.toggled.is_connected(_on_dev_mode_toggled):
		_dev_mode_checkbox.toggled.connect(_on_dev_mode_toggled)


func _refresh_dev_mode_checkbox_text() -> void:
	if _dev_mode_checkbox.button_pressed:
		_dev_mode_checkbox.text = "✓ Developer Mode"
	else:
		_dev_mode_checkbox.text = "Developer Mode"


func _on_dev_mode_toggled(enabled: bool) -> void:
	GameManager.set_dev_mode_enabled(enabled)
	_refresh_dev_mode_checkbox_text()


func _on_dev_hand_picker_requested() -> void:
	if _dev_hand_picker == null or _dev_hand_picker.is_open():
		return
	_dev_hand_picker.show_dev_hand_picker(GameManager.get_all_ingredients())


func _on_dev_hand_picker_completed(selection: Array) -> void:
	GameManager.try_draw_dev_hand(selection)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_dev_mode_enabled():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_T:
		return
	GameManager.request_dev_trinket_picker()
	get_viewport().set_input_as_handled()


func _on_dev_trinket_picker_requested() -> void:
	_open_dev_trinket_picker()


func _open_dev_trinket_picker() -> void:
	if _dev_trinket_picker == null or _dev_trinket_picker.is_open():
		return
	if GameManager.run == null:
		return
	_dev_trinket_picker.show_dev_trinket_picker(GameManager.get_trinkets_with_art())


func _on_dev_trinket_picker_completed(trinket_ids: Array) -> void:
	GameManager.grant_dev_trinkets(trinket_ids)


func _refresh_practice_restart_button() -> void:
	if _practice_restart_button == null:
		return
	var can_restart := GameManager.run.brew_session.can_practice_restart()
	_practice_restart_button.visible = can_restart
	_practice_restart_button.disabled = not can_restart


func _apply_boss_banner_style(is_boss: bool) -> void:
	if _level_aura_banner == null:
		return
	_level_aura_banner.modulate = Color(1.0, 0.58, 0.58, 1.0) if is_boss else Color.WHITE


func _refresh_game_over(comparison: Dictionary) -> void:
	var run := GameManager.run
	var records := ""
	if comparison.get("deepest_level_improved", false):
		records += "New depth record!\n"
	if comparison.get("single_brew_improved", false):
		records += "New best brew!\n"
	if comparison.get("run_total_improved", false):
		records += "New total score record!\n"
	_game_over_stats.text = (
		"Run Over\n\nDepth %d\nBest Brew %d\nTotal Score %d\n\n%s"
		% [
			run.deepest_level_reached,
			run.best_single_brew_this_run,
			run.total_run_score,
			records,
		]
	)

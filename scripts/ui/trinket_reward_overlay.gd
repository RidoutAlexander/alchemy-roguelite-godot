class_name TrinketRewardOverlay
extends CanvasLayer

const _OPTION_SCENE := preload("res://scenes/ui/trinket_reward_option.tscn")
const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")
const FLY_ART_SIZE := Vector2(96.0, 96.0)

@onready var _overlay_root: Control = $OverlayRoot
@onready var _input_blocker: ColorRect = $OverlayRoot/InputBlocker
@onready var _title_label: Label = $OverlayRoot/Panel/Content/Title
@onready var _options_row: HBoxContainer = $OverlayRoot/Panel/Content/OptionsRow
@onready var _fly_layer: CanvasLayer = $FlyLayer

var _option_nodes: Array[TrinketRewardOption] = []
var _selection_locked := false


func _ready() -> void:
	visible = false
	_set_input_enabled(false)
	_build_option_slots()


func show_offers(trinkets: Array) -> void:
	_selection_locked = false
	if _title_label != null:
		_title_label.text = "Choose a Trinket"
	_bind_offers(trinkets)
	visible = true
	_set_input_enabled(true)


func hide_overlay() -> void:
	visible = false
	_set_input_enabled(false)
	_selection_locked = false
	for option in _option_nodes:
		if option != null:
			option.set_selectable(true)
			option.modulate = Color.WHITE


func _set_input_enabled(enabled: bool) -> void:
	var filter := (
		Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	)
	if _overlay_root != null:
		_overlay_root.mouse_filter = filter
	if _input_blocker != null:
		_input_blocker.mouse_filter = filter


func _build_option_slots() -> void:
	if _options_row == null:
		return
	for child in _options_row.get_children():
		child.queue_free()
	_option_nodes.clear()
	for _i in 3:
		var option := _OPTION_SCENE.instantiate() as TrinketRewardOption
		if option == null:
			continue
		_options_row.add_child(option)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not option.selected.is_connected(_on_option_selected):
			option.selected.connect(_on_option_selected)
		_option_nodes.append(option)


func _bind_offers(trinkets: Array) -> void:
	for index in _option_nodes.size():
		var option := _option_nodes[index]
		if option == null:
			continue
		if index < trinkets.size() and trinkets[index] is TrinketData:
			option.visible = true
			option.bind(trinkets[index])
			option.set_selectable(true)
			option.modulate = Color.WHITE
		else:
			option.visible = false
			option.bind(null)


func _on_option_selected(trinket: TrinketData) -> void:
	if _selection_locked or trinket == null:
		return
	_selection_locked = true
	_set_input_enabled(false)
	for option in _option_nodes:
		if option == null:
			continue
		option.set_selectable(false)
		if option.get_trinket() == trinket:
			option.modulate = Color(1.15, 1.15, 1.05, 1.0)
		else:
			option.modulate = Color(0.55, 0.55, 0.55, 0.85)

	if trinket.id == TrinketEffects.BEATING_HEART_ID:
		_play_beating_heart_reward(_find_selected_option(trinket))
		return

	if not GameManager.complete_trinket_reward(trinket.id):
		_unlock_selection()
		return

	hide_overlay()


func _find_selected_option(trinket: TrinketData) -> TrinketRewardOption:
	for option in _option_nodes:
		if option != null and option.get_trinket() == trinket:
			return option
	return null


func _play_beating_heart_reward(option: TrinketRewardOption) -> void:
	if option == null or GameManager.run == null:
		_unlock_selection()
		return

	var lives_before := GameManager.run.lives
	var boom_berry_start := option.get_icon_global_center()
	if not GameManager.complete_trinket_reward(TrinketEffects.BEATING_HEART_ID):
		_unlock_selection()
		return

	var lives_after := GameManager.run.lives
	_play_beating_heart_life_gain(lives_before, lives_after, boom_berry_start)


func _play_beating_heart_life_gain(
	lives_before: int,
	lives_after: int,
	boom_berry_start: Vector2
) -> void:
	var lives_display := _find_brew_lives_display()
	if (
		lives_display == null
		or lives_after <= lives_before
		or lives_after <= GameConstants.STARTING_LIVES
	):
		_play_beating_heart_boom_berry_fly(boom_berry_start)
		return

	lives_display.play_bonus_life_gain(
		lives_before,
		lives_after,
		func() -> void:
			_play_beating_heart_boom_berry_fly(boom_berry_start)
	)


func _play_beating_heart_boom_berry_fly(start_center: Vector2) -> void:
	var texture := _load_boom_berry_texture()
	var target_center := _find_brew_bag_center()
	if texture == null or target_center == Vector2.ZERO:
		_finish_beating_heart_reward()
		return

	_IngredientFlyUtil.play(
		_fly_layer,
		texture,
		start_center,
		target_center,
		FLY_ART_SIZE,
		func() -> void:
			_finish_beating_heart_reward()
	)


func _finish_beating_heart_reward() -> void:
	hide_overlay()
	GameManager.finalize_trinket_reward_to_shop()


func _unlock_selection() -> void:
	_selection_locked = false
	_set_input_enabled(true)
	for option in _option_nodes:
		if option != null:
			option.set_selectable(true)
			option.modulate = Color.WHITE


func _find_brew_lives_display() -> LivesDisplay:
	var hud := get_parent()
	if hud == null:
		return null
	var lives_node := hud.get_node_or_null("PhaseSwipeHost/BrewPanel/LivesDisplay")
	return lives_node as LivesDisplay


func _find_brew_bag_center() -> Vector2:
	var hud := get_parent()
	if hud == null:
		return Vector2.ZERO
	var bag_button := hud.get_node_or_null("PhaseSwipeHost/BrewPanel/AddIngredientButton")
	return _IngredientFlyUtil.global_control_center(bag_button as CanvasItem)


func _load_boom_berry_texture() -> Texture2D:
	if GameManager.run == null:
		return null
	var boom_berry := GameManager.run.find_ingredient(TrinketEffects.BEATING_HEART_BOOM_BERRY_ID)
	if boom_berry == null:
		return null
	var art_path := "res://assets/cards/ingredients/%s.png" % boom_berry.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D
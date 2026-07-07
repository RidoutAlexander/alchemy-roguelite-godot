class_name TrinketRewardOverlay
extends CanvasLayer

const _OPTION_SCENE := preload("res://scenes/ui/trinket_reward_option.tscn")

@onready var _overlay_root: Control = $OverlayRoot
@onready var _input_blocker: ColorRect = $OverlayRoot/InputBlocker
@onready var _title_label: Label = $OverlayRoot/Panel/Content/Title
@onready var _options_row: HBoxContainer = $OverlayRoot/Panel/Content/OptionsRow

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
	for option in _option_nodes:
		if option == null:
			continue
		option.set_selectable(false)
		if option.get_trinket() == trinket:
			option.modulate = Color(1.15, 1.15, 1.05, 1.0)
		else:
			option.modulate = Color(0.55, 0.55, 0.55, 0.85)
	if not GameManager.complete_trinket_reward(trinket.id):
		_selection_locked = false
		for option in _option_nodes:
			if option != null:
				option.set_selectable(true)
				option.modulate = Color.WHITE